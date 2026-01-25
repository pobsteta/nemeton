# Research: Tutorial 09 - Échantillonnage LiDAR + TSP

**Date**: 2026-01-23

## 1. Échantillonnage spatial

### 1.1 GRTS (Generalized Random Tessellation Stratified)

**Package**: `spsurvey`

**Référence**: Stevens, D. L., & Olsen, A. R. (2004). Spatially balanced sampling of natural resources. *Journal of the American Statistical Association*, 99(465), 262-278.

**Avantages**:
- Équilibre spatial garanti
- Échantillon ordonné (oversample intégré)
- Gestion native de la stratification

**Exemple minimal**:
```r
library(spsurvey)

# Frame avec stratum
sample <- grts(
  sframe = frame_sf,
  n_base = c(stratum1 = 10, stratum2 = 15),
  stratum_var = "stratum",
  n_over = 10  # Remplacements
)
```

**Documentation**: https://usepa.github.io/spsurvey/

### 1.2 Cube Sampling (Alternative)

**Package**: `BalancedSampling`

**Référence**: Tillé, Y. (2006). *Sampling Algorithms*. Springer.

**Avantages**:
- Équilibrage sur variables auxiliaires
- Local Cube pour équilibre spatial

**Exemple**:
```r
library(BalancedSampling)

# Matrice de variables d'équilibrage
X <- as.matrix(frame[, c("mnh_p95", "slope", "x", "y")])

# Tirage cube
sample_idx <- samplecube(X, pik = rep(n/N, N), order = 2)
```

### 1.3 Stratification optimale

**Package**: `SamplingStrata`

**Utilité**: Déterminer les strates optimales automatiquement

```r
library(SamplingStrata)

# Optimisation des strates
solution <- optimStrata(
  errors = cv_target,
  framesamp = frame,
  model = NULL,
  nStrata = 16
)
```

---

## 2. Extraction de variables zonales

### 2.1 exactextractr

**Package**: `exactextractr`

**Avantages**:
- Très rapide (C++)
- Pondération fractionnelle des pixels
- Multiples statistiques en un appel

**Fonctions clés**:
```r
# Statistiques simples
exact_extract(raster, polygons, "mean")
exact_extract(raster, polygons, c("mean", "sd", "quantile"), quantiles = 0.95)

# Fonction personnalisée
exact_extract(raster, polygons, function(values, coverage) {
  weighted.mean(values, coverage, na.rm = TRUE)
})

# Stack complet
exact_extract(raster_stack, polygons, "mean", append_cols = TRUE)
```

**Performance**: ~100x plus rapide que `terra::extract()` pour polygones complexes

### 2.2 Codage de l'exposition (aspect)

L'exposition est une variable circulaire (0° = 360°). Solution : décomposition sin/cos.

```r
# Codage circulaire
aspect_rad <- aspect_degrees * pi / 180
aspect_sin <- sin(aspect_rad)
aspect_cos <- cos(aspect_rad)

# Interprétation :
# aspect_sin > 0 : versant Est
# aspect_sin < 0 : versant Ouest
# aspect_cos > 0 : versant Nord
# aspect_cos < 0 : versant Sud
```

---

## 3. Réseau de chemins

### 3.1 sfnetworks

**Package**: `sfnetworks`

**Référence**: https://luukvdmeer.github.io/sfnetworks/

**Création du réseau**:
```r
library(sfnetworks)
library(tidygraph)

# Depuis des lignes sf
network <- as_sfnetwork(paths_sf, directed = FALSE)

# Calcul des poids (longueur)
network <- network |>
  activate("edges") |>
  mutate(weight = edge_length())

# Simplification
network <- network |>
  convert(to_spatial_subdivision) |>  # Subdivision aux intersections
  convert(to_spatial_smooth)          # Lissage
```

**Calcul de distances**:
```r
library(igraph)

# Matrice de distances
dist_matrix <- distances(
  network,
  v = node_ids,
  to = node_ids,
  weights = E(network)$weight
)
```

### 3.2 osmdata

**Package**: `osmdata`

**Téléchargement chemins**:
```r
library(osmdata)

paths <- opq(bbox = st_bbox(study_area)) |>
  add_osm_feature(
    key = "highway",
    value = c("track", "path", "footway", "cycleway", "bridleway")
  ) |>
  osmdata_sf()

paths_lines <- paths$osm_lines
```

**Tags OSM pertinents**:
| Tag | Description |
|-----|-------------|
| track | Chemin agricole/forestier |
| path | Sentier |
| footway | Chemin piéton |
| cycleway | Piste cyclable |
| bridleway | Chemin cavalier |

### 3.3 Alternative: dodgr

**Package**: `dodgr`

**Avantages**:
- Plus rapide pour gros réseaux
- Support natif des données OSM
- Calcul parallèle

```r
library(dodgr)

# Charger le réseau
graph <- weight_streetnet(paths_sf, wt_profile = "foot")

# Matrice de distances
dist_matrix <- dodgr_dists(graph, from = points, to = points)
```

---

## 4. Problème du voyageur de commerce (TSP)

### 4.1 Package TSP

**Package**: `TSP`

**Référence**: Hahsler, M., & Hornik, K. (2007). TSP—Infrastructure for the traveling salesperson problem. *Journal of Statistical Software*, 23(2).

**Création et résolution**:
```r
library(TSP)

# Créer l'objet TSP
tsp <- TSP(cost_matrix)

# Méthodes disponibles
# - "nearest_insertion" : rapide, bonne qualité
# - "farthest_insertion" : similaire
# - "cheapest_insertion" : légèrement meilleur
# - "arbitrary_insertion" : variable
# - "nn" : nearest neighbor, très rapide
# - "2-opt" : amélioration locale
# - "concorde" : optimal (nécessite solver externe)

tour <- solve_TSP(tsp, method = "nearest_insertion")

# Amélioration locale
tour <- solve_TSP(tsp, method = "2-opt", control = list(tour = tour))

# Résultats
order <- as.integer(tour)
length <- tour_length(tour)
```

### 4.2 Matrice de coûts avec pénalité hors-chemin

**Formule**:
```
cost(i,j) = time_on_network(i,j) + penalty * time_off_network(i,j)

où:
- time_on_network = distance_réseau / vitesse_chemin
- time_off_network = (dist_i_to_path + dist_j_to_path) / vitesse_hors_chemin
- penalty = multiplicateur (ex: 3x plus lent hors chemin)
```

**Implémentation**:
```r
calculate_cost <- function(i, j, network_dist, offpath_dist_i, offpath_dist_j,
                            speed_path = 4, speed_offpath = 2, penalty = 1) {
  # Temps sur chemin (heures)
  time_path <- network_dist / 1000 / speed_path

  # Temps hors chemin avec pénalité
  time_offpath <- (offpath_dist_i + offpath_dist_j) / 1000 / speed_offpath * penalty

  # Total en minutes
  (time_path + time_offpath) * 60
}
```

### 4.3 Heuristiques de construction vs amélioration

| Type | Méthode | Complexité | Qualité |
|------|---------|------------|---------|
| Construction | Nearest Neighbor | O(n²) | 80-85% optimal |
| Construction | Nearest Insertion | O(n²) | 90-95% optimal |
| Amélioration | 2-opt | O(n²) par itération | +5-10% |
| Amélioration | 3-opt | O(n³) par itération | +2-5% |
| Exact | Branch & Bound | Exponentiel | Optimal |
| Exact | Concorde | Variable | Optimal |

**Recommandation**: `nearest_insertion` + `2-opt` pour n ≤ 100

---

## 5. Export GPX

### 5.1 Format GPX

Structure simplifiée:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <wpt lat="45.123" lon="6.456">
    <name>Placette 01</name>
    <desc>Visite ordre: 1</desc>
  </wpt>
  <rte>
    <name>Parcours TSP</name>
    <rtept lat="45.123" lon="6.456"/>
    <rtept lat="45.124" lon="6.457"/>
  </rte>
</gpx>
```

### 5.2 Export avec sf

```r
# Conversion WGS84
points_wgs84 <- sample |>
  st_transform(4326) |>
  select(name = id, desc = visit_order)

# Export GPX
st_write(points_wgs84, "route.gpx", driver = "GPX",
         dataset_options = c("GPX_USE_EXTENSIONS=YES"),
         delete_dsn = TRUE)
```

### 5.3 Limitations sf/GPX

- Pas de support natif des routes (`<rte>`)
- Uniquement waypoints (`<wpt>`) et tracks (`<trk>`)
- Pour routes, utiliser `xml2` ou template

---

## 6. Références bibliographiques

### Échantillonnage spatial

1. Stevens, D. L., & Olsen, A. R. (2004). Spatially balanced sampling of natural resources. *JASA*, 99(465), 262-278.

2. Grafström, A., & Tillé, Y. (2013). Doubly balanced spatial sampling with spreading and restitution of auxiliary totals. *Environmetrics*, 24(2), 120-131.

### LiDAR forestier

3. White, J. C., et al. (2016). Remote sensing technologies for enhancing forest inventories: A review. *Canadian Journal of Remote Sensing*, 42(5), 619-641.

4. Næsset, E. (2002). Predicting forest stand characteristics with airborne scanning laser using a practical two-stage procedure and field data. *Remote Sensing of Environment*, 80(1), 88-99.

### TSP

5. Applegate, D. L., et al. (2006). *The Traveling Salesman Problem: A Computational Study*. Princeton University Press.

---

## 7. Décisions techniques

### Decision 1: Package échantillonnage

**Décision**: `spsurvey` (GRTS) comme méthode principale

**Rationale**:
- Standard EPA/USGS pour échantillonnage environnemental
- Gestion native oversample
- Documentation excellente
- Maintenance active

**Alternative**: `BalancedSampling` en fallback si déséquilibre marqué

### Decision 2: Extraction zonale

**Décision**: `exactextractr` exclusivement

**Rationale**:
- Performance (100x vs terra::extract)
- Pondération fractionnelle correcte
- API simple et cohérente

### Decision 3: Réseau de chemins

**Décision**: `sfnetworks` + données locales fournies

**Rationale**:
- Intégration tidyverse/tidygraph
- Plus simple que dodgr pour ce cas d'usage
- Données préchargées évitent dépendance OSM

### Decision 4: Résolution TSP

**Décision**: `TSP::solve_TSP()` avec nearest_insertion + 2-opt

**Rationale**:
- Qualité ~95% optimal pour n ≤ 100
- Temps de calcul < 1 seconde
- Pas de dépendance externe (Concorde)

### Decision 5: Stratification

**Décision**: 16 strates (4 × 2 × 2) par défaut

**Rationale**:
- Compromis couverture/complexité
- ~2-3 candidats minimum par strate avec 40 placettes
- Variables choisies couvrent gradients structurels majeurs
