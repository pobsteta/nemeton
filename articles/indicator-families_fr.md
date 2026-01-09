# Familles d'indicateurs - Référentiel complet

## Introduction

Le package `nemeton` structure l’évaluation des services écosystémiques
forestiers autour de **12 familles d’indicateurs** couvrant les
dimensions biophysiques, écologiques et socio-économiques. Cette
vignette présente le référentiel complet et démontre l’utilisation du
système de familles.

**Version actuelle : v0.3.0** - **9 familles sur 12 implémentées** avec
23 indicateurs opérationnels.

``` r
library(nemeton)
library(ggplot2)
```

## Référentiel des 12 familles

### Vue d’ensemble

| Code  | Famille             | Description                               | Nb indicateurs |
|-------|---------------------|-------------------------------------------|----------------|
| **C** | Carbone & Vitalité  | Stock carbone et santé végétation         | 2              |
| **B** | Biodiversité        | Diversité structurelle et habitats        | 3              |
| **W** | Eau                 | Régulation hydrique                       | 3              |
| **A** | Air & Microclimat   | Qualité de l’air et régulation climatique | 2              |
| **F** | Fertilité des sols  | Qualité pédologique et érosion            | 2              |
| **L** | Landscape (Paysage) | Structure et connectivité paysagère       | 3              |
| **T** | Temps & Dynamique   | Ancienneté et trajectoires                | 2              |
| **R** | Risques             | Vulnérabilité aux perturbations           | 3              |
| **S** | Social & Usages     | Accessibilité et services récréatifs      | 3              |
| **P** | Production          | Productivité forestière                   | 3              |
| **E** | Énergie             | Potentiel énergétique et climat           | 2              |
| **N** | Naturalité          | Degré de naturalité                       | 3              |

### Famille C : Carbone & Vitalité

``` r
# C1 - Stock de biomasse aérienne (tC/ha)
carbon_biomass <- nemeton_compute(
  units,
  layers,
  indicators = "carbon_biomass"
)

# C2 - NDVI et tendance vitalité
carbon_ndvi <- nemeton_compute(
  units,
  layers,
  indicators = "carbon_ndvi"
)
```

**Interprétation** : - C1 \> 100 tC/ha : Fort stock de carbone - C2
(NDVI) \> 0.7 : Végétation très active

### Famille W : Eau

``` r
# W1 - Densité réseau hydrographique (m/ha)
water_network <- nemeton_compute(
  units,
  layers,
  indicators = "water_network"
)

# W2 - Surface en zones humides (%)
water_wetlands <- nemeton_compute(
  units,
  layers,
  indicators = "water_wetlands"
)

# W3 - Topographic Wetness Index
water_twi <- nemeton_compute(
  units,
  layers,
  indicators = "water_twi"
)
```

**Interprétation** : - W1 \> 50 m/ha : Dense réseau hydrographique - W2
\> 20% : Zone humide significative - W3 \> 10 : Fort potentiel
d’accumulation d’eau

### Famille F : Fertilité des sols

``` r
# F1 - Classe de fertilité (BD Sol)
soil_fertility <- nemeton_compute(
  units,
  layers,
  indicators = "soil_fertility"
)

# F2 - Risque d'érosion (pente × couverture)
soil_erosion <- nemeton_compute(
  units,
  layers,
  indicators = "soil_erosion"
)
```

**Interprétation** : - F1 : 1 (très fertile) à 5 (très pauvre) - F2 \> 5
: Risque d’érosion élevé

### Famille L : Landscape (Paysage)

``` r
# L1 - Fragmentation (nb patches / surface moyenne)
landscape_frag <- nemeton_compute(
  units,
  layers,
  indicators = "landscape_fragmentation"
)

# L2 - Ratio lisière / surface
landscape_edge <- nemeton_compute(
  units,
  layers,
  indicators = "landscape_edge"
)
```

**Interprétation** : - L1 faible : Continuité forestière - L2 élevé :
Forte proportion de lisière (effet de bord)

### Famille B : Biodiversité (v0.3.0)

``` r
# B1 - Protection réglementaire (% surface en zones protégées)
biodiversity_protection <- indicator_biodiversity_protection(
  units,
  protected_areas = protected_areas,  # sf object ZNIEFF, Natura2000
  source = "local"  # ou "wfs" pour téléchargement automatique
)

# B2 - Diversité structurelle (Shannon)
biodiversity_structure <- indicator_biodiversity_structure(
  units,
  strata_field = "strata",          # Strates (Emergent, Dominant, etc.)
  age_class_field = "age_class",    # Classes d'âge
  species_field = "species",        # Essences
  method = "shannon",               # ou "simpson"
  weights = c(strata = 0.4, age = 0.3, species = 0.3)
)

# B3 - Connectivité écologique (distance corridors)
biodiversity_connectivity <- indicator_biodiversity_connectivity(
  units,
  corridors = corridors_sf,  # Trames vertes et bleues
  distance_method = "edge",  # ou "centroid"
  max_distance = 3000        # Distance max en mètres
)
```

**Interprétation** : - B1 \> 50% : Protection significative - B2
(Shannon) \> 1.5 : Diversité structurelle élevée - B3 \< 500m :
Excellente connectivité écologique

### Famille R : Risques & Résilience (v0.3.0)

``` r
# R1 - Risque incendie (pente + essence + climat)
risk_fire <- indicator_risk_fire(
  units,
  dem = dem_raster,              # Modèle numérique de terrain
  species_field = "species",     # Champ essence
  climate = climate_data         # Température, précipitations
)

# R2 - Vulnérabilité tempête (hauteur + densité + exposition)
risk_storm <- indicator_risk_storm(
  units,
  dem = dem_raster,
  height_field = "height",       # Hauteur dominante (m)
  density_field = "density"      # Densité (0-1)
)

# R3 - Stress hydrique (TWI + climat + essences)
risk_drought <- indicator_risk_drought(
  units,
  twi_field = "W3",              # Topographic Wetness Index
  climate = climate_data,
  species_field = "species"
)
```

**Interprétation** : - R1, R2, R3 \> 60 : Vulnérabilité élevée - Risques
cumulés (≥2 indicateurs élevés) : Priorité gestion préventive

### Famille T : Trame Temporelle (v0.3.0)

``` r
# T1 - Ancienneté des peuplements (années)
temporal_age <- indicator_temporal_age(
  units,
  age_field = "age",                    # Âge actuel
  establishment_year_field = "planted"  # Année plantation (optionnel)
)

# T2 - Changements d'occupation du sol (%/an)
temporal_change <- indicator_temporal_change(
  units,
  land_cover_early = lc_1990_raster,
  land_cover_late = lc_2020_raster,
  years_elapsed = 30,
  interpretation = "stability"  # ou "dynamism"
)
```

**Interprétation** : - T1 \> 150 ans : Forêt ancienne (haute valeur
patrimoniale) - T2 \< 1%/an : Stabilité de l’occupation - T2 \> 3%/an :
Dynamique forte (urbanisation, déprise agricole)

### Famille A : Air & Microclimat (v0.3.0)

``` r
# A1 - Couverture arborée dans buffer 1km (%)
air_coverage <- indicator_air_coverage(
  units,
  land_cover = land_cover_raster,
  buffer_radius = 1000  # Rayon en mètres
)

# A2 - Qualité de l'air (indice ou proxy distance)
air_quality <- indicator_air_quality(
  units,
  roads = roads_sf,           # Réseau routier (optionnel)
  urban_areas = urban_sf,     # Zones urbaines (optionnel)
  atmo_data = NULL,           # Données ATMO si disponibles
  method = "proxy"            # "atmo" si données disponibles
)
```

**Interprétation** : - A1 \> 70% : Couverture arborée dense (forte
régulation climatique) - A2 \> 70 : Bonne qualité de l’air

## Système de préfixes et détection automatique

Le package utilise un système de **préfixes de famille** pour organiser
les indicateurs :

``` r
# Les indicateurs bruts suivent le pattern : famille_nom
# Exemples :
carbon_biomass    # Famille C
water_network     # Famille W
soil_fertility    # Famille F

# Les indicateurs normalisés ajoutent le suffixe _norm :
carbon_biomass_norm
water_network_norm
```

### Détection automatique de famille

``` r
# Détecter la famille d'un indicateur
detect_indicator_family("carbon_biomass")
# [1] "C"

detect_indicator_family("water_twi_norm")
# [1] "W"

# Obtenir le nom complet de la famille
get_family_name("C")
# [1] "Carbone & Vitalité"

get_family_name("W", lang = "en")
# [1] "Water Regulation"
```

## Normalisation par famille

Normalisez tous les indicateurs d’une ou plusieurs familles :

``` r
# Charger les données
data(massif_demo_units)
layers <- massif_demo_layers()

# Calculer indicateurs des familles C et W
results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = c("carbon", "water", "biodiversity")
)

# Normaliser tous les indicateurs
normalized <- normalize_indicators(
  results,
  indicators = c("carbon", "water", "biodiversity"),
  method = "minmax"
)

# Les colonnes normalisées ont le suffixe _norm
names(normalized)
```

## Indices composites par famille

Créez des indices agrégés par famille avec
[`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
:

``` r
# Exemple fictif (nécessite indicateurs C1 et C2)
# Indice famille C (Carbone)
score_carbon <- create_family_index(
  normalized,
  family = "C",
  name = "score_carbon"
)

# Indice famille W (Eau)
score_water <- create_family_index(
  normalized,
  family = "W",
  name = "score_water"
)
```

**Fonctionnement** : - Détecte automatiquement les indicateurs de la
famille (préfixe) - Agrège par moyenne arithmétique (par défaut) - Crée
une nouvelle colonne avec le nom spécifié

## Visualisation multi-famille

### Radar chart 12 familles

``` r
# Créer scores pour chaque famille
families <- c("C", "W", "F", "L")
for (fam in families) {
  normalized <- create_family_index(
    normalized,
    family = fam,
    name = paste0("score_", tolower(fam))
  )
}

# Radar avec 4 familles
nemeton_radar(
  normalized,
  unit_id = "P01",
  indicators = c("score_c", "score_w", "score_f", "score_l"),
  title = "Profil multi-famille - Parcelle P01"
)
```

### Cartes par famille

``` r
# Visualiser les scores de famille
plot_indicators_map(
  normalized,
  indicators = c("score_c", "score_w", "score_f"),
  palette = "viridis",
  facet = TRUE,
  ncol = 3,
  title = "Scores par famille"
)
```

## Analyse croisée inter-familles (v0.3.0)

La v0.3.0 introduit des outils d’**analyse croisée** pour identifier
synergies et conflits entre familles.

### Matrice de corrélations

``` r
# Calculer les corrélations entre indices de familles
corr_matrix <- compute_family_correlations(
  units,
  families = NULL,      # Auto-détection des family_*
  method = "pearson"    # ou "spearman", "kendall"
)

# Visualiser les corrélations
plot_correlation_matrix(
  corr_matrix,
  method = "circle",    # ou "square", "number", "color"
  palette = "RdBu",     # Rouge=synergies, Bleu=conflits
  title = "Synergies et conflits entre services écosystémiques"
)
```

**Interprétation** : - **Corrélation positive (rouge)** : Synergies (ex:
Biodiversité × Ancienneté) - **Corrélation négative (bleu)** :
Conflits/trade-offs (ex: Protection × Risques) - **Corrélation faible
(blanc)** : Indépendance

### Identification de hotspots multi-critères

``` r
# Identifier parcelles excellentes sur plusieurs familles
hotspots <- identify_hotspots(
  units,
  threshold = 80,      # Top 20% pour chaque famille
  min_families = 3     # Au moins 3 familles élevées
)

# Filtrer les hotspots
hotspot_parcels <- hotspots[hotspots$is_hotspot, ]

# Afficher détails
hotspot_parcels[, c("parcel_id", "hotspot_count", "hotspot_families")]

# Cartographier
plot_indicators_map(
  hotspots,
  indicator = "hotspot_count",
  palette = "YlOrRd",
  title = "Nombre de familles à haute valeur"
)
```

**Cas d’usage** : - **Conservation** : Parcelles à haute biodiversité +
ancienneté + connectivité - **Gestion des risques** : Parcelles cumulant
fire + storm + drought - **Optimisation multi-objectif** : Équilibre
production/protection

## Exemple complet : Workflow multi-famille

``` r
# 1. Charger données
data(massif_demo_units)
layers <- massif_demo_layers()

# 2. Calculer indicateurs de 3 familles
results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = c(
    "carbon",        # Famille C
    "water",         # Famille W
    "biodiversity"   # Famille B
  )
)

# 3. Normaliser
normalized <- normalize_indicators(
  results,
  indicators = c("carbon", "water", "biodiversity"),
  method = "minmax"
)

# 4. Créer indices par famille
normalized <- create_family_index(normalized, family = "C", name = "score_carbon")
normalized <- create_family_index(normalized, family = "W", name = "score_water")
normalized <- create_family_index(normalized, family = "B", name = "score_bio")

# 5. Indice global multi-famille
global_index <- create_composite_index(
  normalized,
  indicators = c("score_carbon", "score_water", "score_bio"),
  weights = c(0.4, 0.3, 0.3),
  name = "ecosystem_services_index"
)

# 6. Visualisation
plot_indicators_map(
  global_index,
  indicators = "ecosystem_services_index",
  palette = "RdYlGn",
  title = "Indice global de services écosystémiques",
  legend_title = "Score (0-100)"
)
```

## Liste des indicateurs disponibles

Consultez la liste complète des indicateurs implémentés :

``` r
# Lister tous les indicateurs disponibles
list_indicators()

# Filtrer par famille
list_indicators(family = "C")
list_indicators(family = "W")
```

## Roadmap v0.3.0 → v1.0.0

**Version actuelle (v0.3.0)** : **9 familles sur 12 implémentées** (C,
B, W, A, F, L, T, R + partiel S)

**Indicateurs opérationnels** : - ✅ **23 indicateurs** pleinement
fonctionnels - ✅ **Analyse croisée inter-familles** (corrélations,
hotspots multi-critères) - ✅ **Infrastructure temporelle complète**
(analyse multi-périodes, détection de changements) - ✅ **Support
bilingue FR/EN** - ✅ **845+ tests** avec 87% de couverture

**Versions futures** : - **v0.4.0** : Familles S, P complètes (usages
sociaux, production) - **v0.5.0** : Familles E, N + Dashboard Shiny
interactif - **v1.0.0** : Référentiel complet 12 familles (36
indicateurs) + analyses avancées

## Références

- Référentiel Nemeton : Documentation technique Vivre en Forêt
- Guide méthodologique :
  [`vignette("getting-started_fr")`](https://pobsteta.github.io/nemeton/articles/getting-started_fr.md)
- Analyse temporelle :
  [`vignette("temporal-analysis_fr")`](https://pobsteta.github.io/nemeton/articles/temporal-analysis_fr.md)
- **Nouveautés v0.3.0** :
  [`vignette("biodiversity-resilience-v030_fr")`](https://pobsteta.github.io/nemeton/articles/biodiversity-resilience-v030_fr.md) -
  Familles B, R, T, A + Analyse croisée

## Session Info

``` r
sessionInfo()
#> R version 4.5.2 (2025-10-31)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 24.04.3 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.26.so;  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=C.UTF-8       LC_NUMERIC=C           LC_TIME=C.UTF-8       
#>  [4] LC_COLLATE=C.UTF-8     LC_MONETARY=C.UTF-8    LC_MESSAGES=C.UTF-8   
#>  [7] LC_PAPER=C.UTF-8       LC_NAME=C              LC_ADDRESS=C          
#> [10] LC_TELEPHONE=C         LC_MEASUREMENT=C.UTF-8 LC_IDENTIFICATION=C   
#> 
#> time zone: UTC
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] ggplot2_4.0.1  nemeton_0.4.21
#> 
#> loaded via a namespace (and not attached):
#>  [1] gtable_0.3.6       jsonlite_2.0.0     dplyr_1.1.4        compiler_4.5.2    
#>  [5] tidyselect_1.2.1   Rcpp_1.1.0         jquerylib_0.1.4    systemfonts_1.3.1 
#>  [9] scales_1.4.0       textshaping_1.0.4  yaml_2.3.12        fastmap_1.2.0     
#> [13] R6_2.6.1           generics_0.1.4     classInt_0.4-11    sf_1.0-23         
#> [17] knitr_1.51         htmlwidgets_1.6.4  tibble_3.3.0       desc_1.4.3        
#> [21] units_1.0-0        DBI_1.2.3          pillar_1.11.1      RColorBrewer_1.1-3
#> [25] bslib_0.9.0        rlang_1.1.6        cachem_1.1.0       terra_1.8-86      
#> [29] xfun_0.55          S7_0.2.1           fs_1.6.6           sass_0.4.10       
#> [33] otel_0.2.0         cli_3.6.5          withr_3.0.2        pkgdown_2.2.0     
#> [37] magrittr_2.0.4     class_7.3-23       digest_0.6.39      grid_4.5.2        
#> [41] lifecycle_1.0.5    vctrs_0.6.5        KernSmooth_2.23-26 proxy_0.4-29      
#> [45] evaluate_1.0.5     glue_1.8.0         farver_2.1.2       codetools_0.2-20  
#> [49] ragg_1.5.0         e1071_1.7-17       rmarkdown_2.30     pkgconfig_2.0.3   
#> [53] tools_4.5.2        htmltools_0.5.9
```
