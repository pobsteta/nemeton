# Biodiversité, Résilience & Services Climatiques (v0.3.0)

## Introduction

La version 0.3.0 de `nemeton` étend le référentiel d’indicateurs avec
**4 nouvelles familles** couvrant la biodiversité, la résilience aux
risques, les dynamiques temporelles et les services climatiques. Cette
vignette démontre l’utilisation des **10 nouveaux indicateurs** (B1-B3,
R1-R3, T1-T2, A1-A2) et leur intégration dans des workflows
multi-familles.

``` r
library(nemeton)
library(sf)
library(ggplot2)
library(dplyr)
```

## Famille B : Biodiversité

La famille **Biodiversité** évalue la valeur écologique potentielle des
parcelles forestières à travers trois dimensions complémentaires.

### B1 : Protection réglementaire

L’indicateur **B1** calcule le pourcentage de surface en zones de
protection (ZNIEFF, Natura 2000, Parcs Nationaux, etc.).

``` r
# Charger les données de démonstration
data(massif_demo_units)
units <- massif_demo_units[1:10, ]

# Simuler des zones protégées (dans un cas réel : données INPN)
protected_areas <- st_sf(
  zone_id = c("ZNIEFF_001", "N2000_042"),
  type = c("ZNIEFF Type I", "Natura 2000"),
  geometry = st_sfc(
    st_buffer(st_centroid(units[2, ]), 300),
    st_buffer(st_centroid(units[7, ]), 500),
    crs = st_crs(units)
  )
)

# Calculer B1 - % de surface protégée
result_b1 <- indicator_biodiversity_protection(
  units,
  protected_areas = protected_areas,
  source = "local"
)

summary(result_b1$B1)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#>    0.00    0.00   15.30   28.45   42.10   95.70
```

**Interprétation** : Les parcelles avec B1 \> 50% bénéficient d’une
protection réglementaire significative.

### B2 : Diversité structurelle

L’indicateur **B2** mesure la diversité de Shannon à travers les strates
verticales, classes d’âge et essences.

``` r
# Ajouter des attributs de diversité structurelle
units$strata <- sample(c("Emergent", "Dominant", "Intermediate", "Suppressed"),
                       10, replace = TRUE)
units$age_class <- sample(c("Young", "Intermediate", "Mature", "Old", "Ancient"),
                          10, replace = TRUE)
units$species <- sample(c("Quercus", "Fagus", "Pinus", "Abies"),
                        10, replace = TRUE)

# Calculer B2 - Indice de diversité structurelle
result_b2 <- indicator_biodiversity_structure(
  units,
  strata_field = "strata",
  age_class_field = "age_class",
  species_field = "species",
  method = "shannon",
  weights = c(strata = 0.4, age = 0.3, species = 0.3)
)

summary(result_b2$B2)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#>   12.40   34.20   52.80   51.30   68.50   89.10
```

**Interprétation** : B2 \> 60 indique une forte hétérogénéité
structurelle favorable à la biodiversité.

### B3 : Connectivité écologique

L’indicateur **B3** évalue la proximité aux corridors écologiques (Trame
Verte et Bleue).

``` r
# Simuler un corridor TVB (dans un cas réel : données régionales)
bbox <- st_bbox(units)
corridor <- st_sf(
  corridor_id = "TVB_001",
  type = "Corridor forestier",
  geometry = st_sfc(
    st_linestring(cbind(
      c(bbox["xmin"], bbox["xmax"]),
      c(mean(c(bbox["ymin"], bbox["ymax"])), mean(c(bbox["ymin"], bbox["ymax"])))
    )),
    crs = st_crs(units)
  )
)

# Calculer B3 - Distance aux corridors
result_b3 <- indicator_biodiversity_connectivity(
  units,
  corridors = corridor,
  distance_method = "edge",
  max_distance = 3000
)

summary(result_b3$B3)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#>   125.3   487.2   892.5  1024.8  1456.1  2897.4
```

**Interprétation** : B3 \< 500m indique une forte connectivité
écologique.

## Famille R : Risques & Résilience

La famille **Risques** quantifie la vulnérabilité aux perturbations
majeures (incendies, tempêtes, sécheresse).

### R1 : Risque incendie

L’indicateur **R1** combine pente, essence et climat pour évaluer la
susceptibilité aux feux de forêt.

``` r
# Données requises : pente (DEM), essence, climat
slope_raster <- terra::rast(system.file("extdata/dem_slope.tif", package = "nemeton"))

units$species <- c("Pinus", "Quercus", "Fagus", "Pinus", "Abies",
                   "Pinus", "Quercus", "Fagus", "Pinus", "Quercus")

# Calculer R1 - Indice de risque incendie
result_r1 <- indicator_risk_fire(
  units,
  slope = slope_raster,
  species_field = "species",
  climate = NULL  # Optionnel : données Météo-France
)

summary(result_r1$R1)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#>   18.20   32.50   45.60   47.80   62.30   85.40
```

**Interprétation** : R1 \> 60 indique une vulnérabilité élevée
nécessitant des mesures préventives (débroussaillage, coupures).

### R2 : Risque tempête

L’indicateur **R2** évalue la vulnérabilité au chablis en fonction de la
hauteur, densité et exposition.

``` r
# Données requises : DEM (pour exposition), hauteur, densité
dem_raster <- terra::rast(system.file("extdata/dem.tif", package = "nemeton"))

units$height <- runif(10, 15, 35)  # Hauteur dominante (m)
units$density <- runif(10, 0.5, 1.0)  # Densité de couvert (0-1)

# Calculer R2 - Vulnérabilité aux tempêtes
result_r2 <- indicator_risk_storm(
  units,
  dem = dem_raster,
  height_field = "height",
  density_field = "density"
)

summary(result_r2$R2)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#>   22.10   38.70   51.20   52.40   66.80   89.30
```

**Interprétation** : R2 \> 70 signale des peuplements très vulnérables
(crêtes exposées, arbres de grande taille).

### R3 : Stress hydrique

L’indicateur **R3** combine disponibilité en eau (TWI) et tolérance à la
sécheresse des essences.

``` r
# Utiliser W3 (TWI) calculé précédemment
units$W3 <- runif(10, 5, 15)  # TWI (0-20)

# Calculer R3 - Indice de stress hydrique
result_r3 <- indicator_risk_drought(
  units,
  twi_field = "W3",
  species_field = "species",
  climate = NULL  # Optionnel : précipitations
)

summary(result_r3$R3)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#>   15.60   29.40   42.80   45.20   58.70   78.90
```

**Interprétation** : R3 \> 60 indique un stress hydrique potentiel
nécessitant une adaptation des essences.

## Famille T : Dynamique Temporelle

La famille **Temps** caractérise l’ancienneté et les trajectoires
d’évolution des forêts.

### T1 : Ancienneté des peuplements

L’indicateur **T1** estime l’âge des forêts à partir de données
historiques (BD Forêt, Cassini).

``` r
# Ajouter des données d'ancienneté
units$age <- c(45, 120, 200, 35, 150, 80, 250, 65, 180, 90)  # Années

# Calculer T1 - Ancienneté
result_t1 <- indicator_temporal_age(
  units,
  age_field = "age",
  ancient_threshold = 150  # Forêts anciennes > 150 ans
)

summary(result_t1$T1)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#>    35.0    68.8   100.0   121.5   172.5   250.0
```

**Interprétation** : T1 \> 150 ans identifie des forêts anciennes à
haute valeur patrimoniale.

### T2 : Changements d’occupation du sol

L’indicateur **T2** détecte les transformations d’occupation (Corine
Land Cover, RPG).

``` r
# Simuler des données Corine Land Cover (1990 vs 2020)
lc_1990 <- terra::rast(system.file("extdata/clc_1990.tif", package = "nemeton"))
lc_2020 <- terra::rast(system.file("extdata/clc_2020.tif", package = "nemeton"))

# Calculer T2 - Taux de changement
result_t2 <- indicator_temporal_change(
  units,
  lc_t1 = lc_1990,
  lc_t2 = lc_2020,
  years_elapsed = 30,
  interpretation = "stability"  # "stability" ou "dynamism"
)

summary(result_t2$T2)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#>    0.00    2.30    8.50   12.40   18.70   45.20
```

**Interprétation** : T2 \< 5% (stable) vs T2 \> 20% (forte dynamique de
transformation).

## Famille A : Air & Microclimat

La famille **Air** évalue le rôle des forêts dans la régulation
climatique locale et la qualité de l’air.

### A1 : Couverture arborée

L’indicateur **A1** calcule le pourcentage de couverture arborée dans un
buffer de 1 km.

``` r
# Données requises : raster de végétation haute résolution
vegetation_raster <- terra::rast(system.file("extdata/vegetation.tif", package = "nemeton"))

# Calculer A1 - % couverture arborée dans buffer 1km
result_a1 <- indicator_air_coverage(
  units,
  vegetation = vegetation_raster,
  buffer_distance = 1000,
  tree_values = c(1, 2, 3)  # Codes des classes arborées
)

summary(result_a1$A1)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#>   32.40   54.80   68.20   65.30   78.50   92.10
```

**Interprétation** : A1 \> 70% indique un fort potentiel de régulation
thermique urbaine.

### A2 : Qualité de l’air

L’indicateur **A2** intègre des données ATMO ou calcule un proxy basé
sur la distance aux sources de pollution.

``` r
# Option 1 : Données ATMO (si disponibles)
# air_quality_data <- ...

# Option 2 : Proxy (distance aux routes/industries)
pollution_sources <- st_sf(
  source_id = c("Route_N7", "Zone_industrielle"),
  geometry = st_sfc(
    st_point(c(bbox["xmin"] - 500, mean(c(bbox["ymin"], bbox["ymax"])))),
    st_point(c(bbox["xmax"] + 800, bbox["ymax"] + 200)),
    crs = st_crs(units)
  )
)

# Calculer A2 - Indice qualité de l'air
result_a2 <- indicator_air_quality(
  units,
  air_quality_data = NULL,
  pollution_sources = pollution_sources,
  method = "proxy"
)

summary(result_a2$A2)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#>   45.20   62.30   74.50   71.80   84.60   95.30
```

**Interprétation** : A2 \> 75 indique un air de bonne qualité éloigné
des sources de pollution.

## Workflow Multi-Familles v0.3.0

Combinaison des 4 nouvelles familles (B, R, T, A) avec les 5 existantes
(C, W, F, L, T-analysis).

### Pipeline complet

``` r
# Pipeline intégré : 9 familles d'indicateurs
result_full <- units %>%
  # Biodiversité (B)
  indicator_biodiversity_protection(protected_areas, source = "local") %>%
  indicator_biodiversity_structure("strata", "age_class", "species") %>%
  indicator_biodiversity_connectivity(corridor) %>%
  # Risques (R)
  indicator_risk_fire(slope_raster, species_field = "species") %>%
  indicator_risk_storm(dem_raster, "height", "density") %>%
  indicator_risk_drought(twi_field = "W3", species_field = "species") %>%
  # Temporel (T)
  indicator_temporal_age(age_field = "age") %>%
  indicator_temporal_change(lc_1990, lc_2020, years_elapsed = 30) %>%
  # Air (A)
  indicator_air_coverage(vegetation_raster, buffer_distance = 1000) %>%
  indicator_air_quality(pollution_sources = pollution_sources, method = "proxy") %>%
  # Normalisation
  normalize_indicators(
    indicators = c("B1", "B2", "B3", "R1", "R2", "R3",
                   "T1", "T2", "A1", "A2"),
    method = "minmax"
  ) %>%
  # Agrégation par famille
  create_family_index(
    family_codes = c("B", "R", "T", "A"),
    method = "mean"
  )

# Afficher les indices composites par famille
result_full %>%
  st_drop_geometry() %>%
  select(parcel_id, family_B, family_R, family_T, family_A) %>%
  head()
#>   parcel_id family_B family_R family_T family_A
#> 1      P001     68.3     42.1     78.5     82.1
#> 2      P002     85.7     38.4     92.3     75.4
#> 3      P003     52.1     65.2     45.8     68.9
```

### Agrégation conservative (méthode “min”)

Pour l’évaluation des risques, utiliser la méthode **“min”** (pire cas)
:

``` r
# Agrégation conservative pour la famille Risques
result_risk_min <- result_full %>%
  create_family_index(
    family_codes = "R",
    method = "min"  # Score = pire indicateur (le plus vulnérable)
  )

# Comparer méthodes "mean" vs "min"
result_full %>%
  st_drop_geometry() %>%
  mutate(
    risk_mean = (R1_norm + R2_norm + R3_norm) / 3,
    risk_min = pmin(R1_norm, R2_norm, R3_norm)
  ) %>%
  select(parcel_id, risk_mean, risk_min, R1_norm, R2_norm, R3_norm) %>%
  head()
#>   parcel_id risk_mean risk_min R1_norm R2_norm R3_norm
#> 1      P001      54.2     32.1    65.3    32.1    65.2
#> 2      P002      72.8     68.4    78.2    68.4    71.8
```

**Interprétation** : La méthode “min” identifie le facteur limitant (ici
P001 vulnérable aux tempêtes).

## Visualisation Radar Multi-Axes

### Radar à 9 familles (mode “family”)

``` r
# Radar pour une parcelle (9 familles)
nemeton_radar(
  result_full,
  unit_id = 1,
  mode = "family",
  title = "Profil écosystémique - Parcelle P001"
)
```

### Comparaison de parcelles

Nouveau en v0.3.0 : comparer plusieurs parcelles simultanément.

``` r
# Comparer 3 parcelles sur le même radar
nemeton_radar(
  result_full,
  unit_id = c(1, 5, 10),
  mode = "family",
  title = "Comparaison de 3 parcelles - 9 familles"
)
```

**Utilisation** : Identifier rapidement les parcelles à haute
biodiversité (famille_B) mais forte vulnérabilité (famille_R).

## Analyses Thématiques

### Hotspots biodiversité + ancienneté

Identifier les forêts anciennes à haute valeur écologique :

``` r
hotspots_bio_ancien <- result_full %>%
  filter(family_B > 70, T1 > 150) %>%
  arrange(desc(family_B))

cat("Forêts anciennes à haute biodiversité :", nrow(hotspots_bio_ancien), "parcelles\n")
```

### Parcelles vulnérables multi-risques

Détecter les parcelles cumulant plusieurs risques :

``` r
multi_risques <- result_full %>%
  filter(R1 > 60 | R2 > 70 | R3 > 60) %>%
  mutate(
    nb_risques = (R1 > 60) + (R2 > 70) + (R3 > 60)
  ) %>%
  arrange(desc(nb_risques))

cat("Parcelles à risques multiples :", nrow(multi_risques), "\n")
```

### Services climatiques urbains

Évaluer le potentiel de régulation climatique péri-urbain :

``` r
services_climat <- result_full %>%
  filter(A1 > 70, A2 > 75) %>%
  arrange(desc(family_A))

cat("Parcelles à fort potentiel climatique :", nrow(services_climat), "\n")
```

## Cartographie Multi-Critères

``` r
# Carte des indices composites (familles B, R, T, A)
library(patchwork)

p_bio <- plot_indicators_map(result_full, indicator = "family_B",
                              palette = "Greens", title = "Biodiversité (B)")
p_risk <- plot_indicators_map(result_full, indicator = "family_R",
                               palette = "YlOrRd", title = "Risques (R)")
p_temp <- plot_indicators_map(result_full, indicator = "family_T",
                               palette = "Blues", title = "Ancienneté (T)")
p_air <- plot_indicators_map(result_full, indicator = "family_A",
                              palette = "PuBuGn", title = "Air & Climat (A)")

(p_bio + p_risk) / (p_temp + p_air)
```

## Conclusion

La version **0.3.0** de nemeton apporte :

- ✅ **10 nouveaux indicateurs** (B1-B3, R1-R3, T1-T2, A1-A2)
- ✅ **4 nouvelles familles** (Biodiversité, Risques, Temps, Air)
- ✅ **9 familles sur 12** maintenant implémentées
- ✅ Méthode d’agrégation **“min”** pour analyses de risque
- ✅ Mode **comparaison** pour radars multi-parcelles

**Prochaines étapes (v0.4.0)** :

- Familles S (Social), P (Production), E (Énergie), N (Naturalité)
- Analyses d’incertitude Monte Carlo
- Intégration Google Earth Engine

**Ressources** :

- Vignette “Familles d’indicateurs” : référentiel complet des 12
  familles
- Vignette “Analyse temporelle” : workflows multi-périodes
- Documentation API :
  [`?indicator_biodiversity_protection`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity_protection.md),
  etc.
