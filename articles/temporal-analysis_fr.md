# Analyse temporelle - Suivi multi-périodes

## Introduction

L’analyse temporelle permet de suivre l’évolution des services
écosystémiques forestiers sur plusieurs périodes. Cette vignette
démontre comment utiliser le système
[`nemeton_temporal()`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md)
pour :

- Comparer les indicateurs à différentes dates
- Calculer les taux de changement
- Visualiser les tendances temporelles
- Détecter les ruptures et transitions

``` r
library(nemeton)
library(ggplot2)
```

## Principe de l’analyse temporelle

Le framework temporel repose sur :

1.  **Datasets multi-dates** : Plusieurs jeux de données spatiales pour
    différentes périodes
2.  **Alignement spatial** : Correspondance des unités spatiales entre
    périodes
3.  **Calcul de changements** : Taux de variation, différences absolues
4.  **Visualisation** : Graphiques temporels, heatmaps, cartes de
    différence

## Créer un dataset temporel

### Structure de données

``` r
# Exemple de structure pour 3 périodes
temporal_data <- nemeton_temporal(
  periods = list(
    "2015" = list(
      units = units_2015,
      layers = layers_2015
    ),
    "2020" = list(
      units = units_2020,
      layers = layers_2020
    ),
    "2025" = list(
      units = units_2025,
      layers = layers_2025
    )
  ),
  unit_id = "parcel_id"  # Colonne identifiant les parcelles
)
```

### Exemple avec données de démonstration

``` r
# Charger les données de base
data(massif_demo_units)
layers_2020 <- massif_demo_layers()

# Simuler des données pour 2015 et 2025 (pour la démo)
# En pratique, vous chargerez vos vrais datasets historiques

# Créer le dataset temporel
temporal <- nemeton_temporal(
  periods = list(
    "2015" = list(units = massif_demo_units, layers = layers_2020),
    "2020" = list(units = massif_demo_units, layers = layers_2020),
    "2025" = list(units = massif_demo_units, layers = layers_2020)
  ),
  unit_id = "parcel_id"
)

print(temporal)
```

## Calculer les indicateurs pour chaque période

``` r
# Calculer automatiquement pour toutes les périodes
temporal_results <- nemeton_compute(
  temporal,
  indicators = c("carbon", "biodiversity", "water")
)

# Afficher la structure
summary(temporal_results)
```

**Résultat** : Un objet `nemeton_temporal` contenant les indicateurs
calculés pour chaque période.

## Analyse des changements

### Taux de changement

``` r
# Calculer le taux de changement annuel (%)
change_rates <- calculate_change_rate(
  temporal_results,
  indicators = c("carbon", "biodiversity", "water"),
  period_start = "2015",
  period_end = "2025"
)

# Afficher les taux de changement
head(change_rates[, c("parcel_id", "carbon_rate", "biodiversity_rate", "water_rate")])
```

**Interprétation** : - Taux \> 0 : Augmentation - Taux \< 0 :
Diminution - Taux en %/an

### Différences absolues

``` r
# Calculer les différences entre 2020 et 2025
differences <- calculate_change_rate(
  temporal_results,
  indicators = "carbon",
  period_start = "2020",
  period_end = "2025",
  method = "absolute"  # Différence absolue au lieu de taux
)
```

## Visualisation temporelle

### Graphiques de tendances

``` r
# Tendance pour une parcelle spécifique
plot_temporal_trend(
  temporal_results,
  unit_id = "P01",
  indicators = c("carbon", "biodiversity", "water"),
  title = "Évolution des indicateurs - Parcelle P01"
)
```

### Heatmap temporelle

``` r
# Heatmap de tous les indicateurs sur toutes les périodes
plot_temporal_heatmap(
  temporal_results,
  indicators = c("carbon", "biodiversity", "water", "fragmentation"),
  title = "Heatmap temporelle - Tous indicateurs"
)
```

**Visualisation** : Matrice colorée montrant l’intensité de chaque
indicateur par période et parcelle.

### Cartes de différence

``` r
# Carte montrant les changements de carbone 2015→2025
plot_difference_map(
  temporal_results,
  indicator = "carbon",
  period_start = "2015",
  period_end = "2025",
  title = "Changement de stock carbone (2015-2025)",
  legend_title = "Δ tC/ha"
)
```

**Palette** : Rouge (perte) → Blanc (stable) → Vert (gain)

## Cas d’usage : Suivi post-intervention

### Scénario : Évaluation d’une coupe

``` r
# 1. Définir les périodes
# - Avant intervention (2018)
# - Après intervention (2020)
# - Suivi à 5 ans (2025)

temporal_intervention <- nemeton_temporal(
  periods = list(
    "avant_2018" = list(units = units_avant, layers = layers_avant),
    "apres_2020" = list(units = units_apres, layers = layers_apres),
    "suivi_2025" = list(units = units_suivi, layers = layers_suivi)
  ),
  unit_id = "parcel_id"
)

# 2. Calculer indicateurs
results <- nemeton_compute(
  temporal_intervention,
  indicators = c("carbon", "biodiversity", "water", "fragmentation")
)

# 3. Analyser les impacts
impact_2020 <- calculate_change_rate(
  results,
  period_start = "avant_2018",
  period_end = "apres_2020",
  indicators = c("carbon", "biodiversity")
)

recovery_2025 <- calculate_change_rate(
  results,
  period_start = "apres_2020",
  period_end = "suivi_2025",
  indicators = c("carbon", "biodiversity")
)

# 4. Visualiser trajectoire
plot_temporal_trend(
  results,
  unit_id = "PARCEL_INTERV_01",
  indicators = c("carbon", "biodiversity"),
  title = "Trajectoire post-intervention"
)
```

## Détection de tendances

### Identifier les parcelles en changement rapide

``` r
# Calculer taux de changement
rates <- calculate_change_rate(
  temporal_results,
  indicators = "carbon",
  period_start = "2015",
  period_end = "2025"
)

# Filtrer les parcelles avec forte dynamique
high_change <- rates %>%
  filter(abs(carbon_rate) > 2.0)  # > ±2% par an

# Visualiser sur carte
plot_indicators_map(
  high_change,
  indicators = "carbon_rate",
  palette = "RdBu",
  title = "Parcelles à forte dynamique carbone",
  legend_title = "Taux (%/an)"
)
```

### Classification des trajectoires

``` r
# Classer les trajectoires
rates <- rates %>%
  mutate(
    trajectory = case_when(
      carbon_rate > 1.0 ~ "Forte augmentation",
      carbon_rate > 0.2 ~ "Augmentation modérée",
      abs(carbon_rate) <= 0.2 ~ "Stable",
      carbon_rate > -1.0 ~ "Diminution modérée",
      TRUE ~ "Forte diminution"
    )
  )

# Compter les trajectoires
table(rates$trajectory)
```

## Normalisation temporelle

### Normaliser par période

``` r
# Normaliser les indicateurs de chaque période séparément
temporal_norm <- normalize_indicators(
  temporal_results,
  indicators = c("carbon", "biodiversity", "water"),
  method = "minmax",
  by_period = TRUE  # Normalisation intra-période
)
```

**Avantage** : Permet de comparer les rangs relatifs entre périodes.

### Normalisation globale

``` r
# Normaliser sur toutes les périodes ensemble
temporal_norm_global <- normalize_indicators(
  temporal_results,
  indicators = c("carbon", "biodiversity", "water"),
  method = "minmax",
  by_period = FALSE  # Normalisation sur toutes les données
)
```

**Avantage** : Échelle commune pour toutes les périodes.

## Indices composites temporels

``` r
# Créer indice composite pour chaque période
composite_temporal <- create_composite_index(
  temporal_norm,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  weights = c(0.4, 0.3, 0.3),
  name = "ecosystem_quality"
)

# Analyser l'évolution de l'indice
plot_temporal_trend(
  composite_temporal,
  unit_id = "P01",
  indicators = "ecosystem_quality",
  title = "Évolution de la qualité écosystémique"
)
```

## Export et reporting

### Tableau de synthèse

``` r
# Créer tableau récapitulatif
summary_table <- temporal_results %>%
  group_by(period) %>%
  summarise(
    carbon_mean = mean(carbon, na.rm = TRUE),
    carbon_sd = sd(carbon, na.rm = TRUE),
    biodiv_mean = mean(biodiversity, na.rm = TRUE),
    biodiv_sd = sd(biodiversity, na.rm = TRUE)
  )

print(summary_table)
```

### Export des résultats

``` r
# Export des taux de changement
write.csv(
  change_rates,
  "results/temporal_change_rates.csv",
  row.names = FALSE
)

# Export cartes temporelles
for (period in c("2015", "2020", "2025")) {
  p <- plot_indicators_map(
    temporal_results[[period]],
    indicators = "carbon",
    title = paste("Stock carbone -", period)
  )
  ggsave(
    paste0("results/carbon_map_", period, ".png"),
    p,
    width = 8,
    height = 6
  )
}
```

## Bonnes pratiques

### Alignement spatial

- Assurer la **correspondance spatiale** entre périodes (même emprise,
  mêmes parcelles)
- Utiliser un identifiant unique (`unit_id`) stable dans le temps
- Vérifier les CRS (systèmes de coordonnées) identiques

### Choix des périodes

- Intervalle minimum : 3-5 ans (détecter changements significatifs)
- Cohérence saisonnière : mêmes dates d’acquisition (éviter biais
  phénologiques)
- Documentation des événements : interventions, perturbations naturelles

### Interprétation des taux

- Taux \< 0.5%/an : Changement faible (potentiellement bruit)
- Taux 0.5-2%/an : Changement modéré (trajectoire naturelle)
- Taux \> 2%/an : Changement rapide (intervention ou perturbation)

## Limitations et perspectives

**Version actuelle (v0.2.0)** : - Framework de base pour 2-3 périodes -
Taux de changement linéaires - Visualisations standard

**Développements futurs (v0.3.0+)** : - Modèles de tendances
non-linéaires - Détection automatique de ruptures (breakpoints) -
Analyse d’incertitude temporelle - Projections et scénarios

## Références

- Guide de démarrage :
  [`vignette("getting-started_fr")`](https://pobsteta.github.io/nemeton/articles/getting-started_fr.md)
- Familles d’indicateurs :
  [`vignette("indicator-families_fr")`](https://pobsteta.github.io/nemeton/articles/indicator-families_fr.md)
- Documentation API :
  [`?nemeton_temporal`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md)

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
#> [1] ggplot2_4.0.1 nemeton_0.4.0
#> 
#> loaded via a namespace (and not attached):
#>  [1] gtable_0.3.6       jsonlite_2.0.0     dplyr_1.1.4        compiler_4.5.2    
#>  [5] tidyselect_1.2.1   Rcpp_1.1.0         jquerylib_0.1.4    systemfonts_1.3.1 
#>  [9] scales_1.4.0       textshaping_1.0.4  yaml_2.3.12        fastmap_1.2.0     
#> [13] R6_2.6.1           generics_0.1.4     classInt_0.4-11    sf_1.0-23         
#> [17] knitr_1.51         tibble_3.3.0       desc_1.4.3         units_1.0-0       
#> [21] DBI_1.2.3          pillar_1.11.1      bslib_0.9.0        RColorBrewer_1.1-3
#> [25] rlang_1.1.6        cachem_1.1.0       terra_1.8-86       xfun_0.55         
#> [29] fs_1.6.6           sass_0.4.10        S7_0.2.1           cli_3.6.5         
#> [33] withr_3.0.2        pkgdown_2.2.0      magrittr_2.0.4     class_7.3-23      
#> [37] digest_0.6.39      grid_4.5.2         lifecycle_1.0.4    vctrs_0.6.5       
#> [41] KernSmooth_2.23-26 proxy_0.4-29       evaluate_1.0.5     glue_1.8.0        
#> [45] farver_2.1.2       codetools_0.2-20   ragg_1.5.0         e1071_1.7-17      
#> [49] rmarkdown_2.30     pkgconfig_2.0.3    tools_4.5.2        htmltools_0.5.9
```
