# Démarrage rapide avec nemeton

## Introduction

Le package `nemeton` implémente la méthode Nemeton pour l’analyse
systémique de territoires forestiers. Il fournit des outils pour :

- Calculer des indicateurs biophysiques multi-famille (carbone, eau,
  sols, paysage, etc.)
- Normaliser les valeurs d’indicateurs selon plusieurs méthodes
- Créer des indices composites pour une évaluation holistique
- Visualiser les résultats avec des cartes et graphiques

Cette vignette démontre le workflow complet avec le jeu de données
`massif_demo`.

## Installation

``` r
# Depuis GitHub
remotes::install_github("pobsteta/nemeton")
```

``` r
library(nemeton)
library(ggplot2)
```

## Charger les données de démonstration

Le package inclut un jeu de données synthétique (`massif_demo`)
représentant une zone de 5km × 5km avec 20 parcelles forestières.

``` r
# Charger les parcelles forestières
data(massif_demo_units)

# Inspecter les parcelles
print(massif_demo_units)
#>    parcel_id      forest_type age_class   management surface_ha
#> 1        P01     Futaie mixte    Mature        Mixte   4.989211
#> 2        P02 Futaie résineuse     Moyen   Production   5.867935
#> 3        P03  Futaie feuillue  Surannée Conservation   6.557777
#> 4        P04  Futaie feuillue  Surannée   Production   9.989553
#> 5        P05 Futaie résineuse     Moyen   Production   5.906395
#> 6        P06 Futaie résineuse    Mature   Production   1.048296
#> 7        P07  Futaie feuillue    Mature        Mixte  17.079363
#> 8        P08  Futaie feuillue    Mature   Production  11.414577
#> 9        P09     Futaie mixte     Moyen   Production  16.105209
#> 10       P10          Taillis  Surannée   Production  10.733433
#> 11       P11  Futaie feuillue    Mature Conservation   6.694706
#> 12       P12  Futaie feuillue     Jeune   Production   4.955189
#> 13       P13  Futaie feuillue     Jeune Conservation   1.996715
#> 14       P14  Futaie feuillue     Jeune Conservation   4.248090
#> 15       P15  Futaie feuillue  Surannée   Production   6.040390
#> 16       P16          Taillis    Mature        Mixte   2.797925
#> 17       P17 Futaie résineuse    Mature   Production   4.193206
#> 18       P18  Futaie feuillue    Mature   Production  10.627101
#> 19       P19  Futaie feuillue     Moyen        Mixte   3.606795
#> 20       P20          Taillis     Moyen   Production   1.170633
#>                                                                                                                                             geometry
#> 1  698299.9, 698307.5, 698178.8, 698041.8, 698102.3, 698233.7, 698299.9, 6499928.5, 6500052.6, 6500088.1, 6500018.3, 6499875.5, 6499800.4, 6499928.5
#> 2  701702.2, 701545.6, 701524.5, 701618.0, 701728.6, 701835.0, 701702.2, 6500418.0, 6500353.8, 6500209.5, 6500109.1, 6500169.3, 6500291.3, 6500418.0
#> 3  702240.4, 702137.6, 702277.7, 702435.0, 702507.7, 702383.6, 702240.4, 6500270.5, 6500128.7, 6500037.9, 6499990.8, 6500159.9, 6500263.2, 6500270.5
#> 4  700641.3, 700417.2, 700340.3, 700507.4, 700668.4, 700737.6, 700641.3, 6504129.1, 6504158.6, 6503926.2, 6503794.3, 6503839.4, 6503983.5, 6504129.1
#> 5  699268.2, 699169.9, 699042.1, 698949.3, 699026.1, 699190.4, 699268.2, 6500307.1, 6500408.9, 6500423.2, 6500304.0, 6500154.1, 6500172.1, 6500307.1
#> 6  699943.5, 699930.6, 699871.2, 699822.8, 699822.3, 699883.0, 699943.5, 6499420.5, 6499489.5, 6499502.7, 6499474.5, 6499411.2, 6499388.2, 6499420.5
#> 7  698500.5, 698670.1, 698772.3, 698559.2, 698293.5, 698304.2, 698500.5, 6499359.7, 6499511.4, 6499724.0, 6499915.7, 6499785.4, 6499515.9, 6499359.7
#> 8  699061.9, 699052.8, 699220.0, 699377.1, 699436.1, 699237.1, 699061.9, 6499649.3, 6499452.3, 6499332.1, 6499451.0, 6499654.6, 6499784.8, 6499649.3
#> 9  702258.5, 702529.0, 702793.8, 702781.1, 702538.0, 702365.3, 702258.5, 6500665.5, 6500614.4, 6500658.2, 6500952.0, 6501023.7, 6500918.4, 6500665.5
#> 10 699897.1, 699700.4, 699547.4, 699663.0, 699853.9, 699990.2, 699897.1, 6500738.8, 6500721.2, 6500589.3, 6500420.6, 6500371.0, 6500540.1, 6500738.8
#> 11 700602.0, 700444.1, 700366.3, 700487.6, 700633.2, 700686.8, 700602.0, 6501157.6, 6501092.7, 6500947.3, 6500826.9, 6500874.4, 6501009.1, 6501157.6
#> 12 700647.0, 700779.4, 700912.0, 700899.6, 700764.8, 700674.8, 700647.0, 6499737.2, 6499672.3, 6499747.5, 6499902.7, 6499930.6, 6499867.1, 6499737.2
#> 13 699704.0, 699767.0, 699746.1, 699668.9, 699579.7, 699623.8, 699704.0, 6500411.7, 6500469.0, 6500549.6, 6500573.1, 6500528.8, 6500438.4, 6500411.7
#> 14 699496.1, 699550.1, 699663.5, 699746.8, 699746.0, 699624.4, 699496.1, 6499932.1, 6499796.5, 6499769.7, 6499837.1, 6499956.5, 6500010.1, 6499932.1
#> 15 699827.3, 699823.0, 699734.7, 699563.5, 699588.8, 699685.2, 699827.3, 6500557.2, 6500693.0, 6500800.3, 6500768.0, 6500601.4, 6500474.2, 6500557.2
#> 16 700359.0, 700279.7, 700190.1, 700115.3, 700193.1, 700288.4, 700359.0, 6499321.4, 6499412.9, 6499366.4, 6499294.4, 6499215.5, 6499232.8, 6499321.4
#> 17 702256.8, 702113.7, 702063.7, 702117.8, 702225.4, 702311.8, 702256.8, 6500070.0, 6500115.4, 6499977.7, 6499879.8, 6499862.7, 6499950.9, 6500070.0
#> 18 699952.4, 699758.3, 699625.6, 699708.5, 699884.8, 699984.9, 699952.4, 6500047.7, 6500172.0, 6499975.8, 6499808.9, 6499678.6, 6499875.4, 6500047.7
#> 19 701856.9, 701794.6, 701855.2, 701978.8, 702043.9, 701962.5, 701856.9, 6500589.3, 6500487.7, 6500378.0, 6500388.1, 6500493.0, 6500573.3, 6500589.3
#> 20 702317.2, 702260.4, 702194.3, 702171.1, 702213.8, 702268.3, 702317.2, 6501522.7, 6501581.3, 6501553.7, 6501495.2, 6501448.5, 6501467.6, 6501522.7

# Statistiques sommaires
cat("\nSurface totale:", sum(massif_demo_units$surface_ha), "ha\n")
#> 
#> Surface totale: 136.0225 ha
table(massif_demo_units$forest_type)
#> 
#>  Futaie feuillue     Futaie mixte Futaie résineuse          Taillis 
#>               11                2                4                3
```

``` r
ggplot(massif_demo_units) +
  geom_sf(aes(fill = forest_type)) +
  theme_minimal() +
  labs(title = "Massif Demo - Types forestiers",
       fill = "Type de forêt")
```

![Parcelles forestières par
type](getting-started_fr_files/figure-html/unnamed-chunk-4-1.png)

Parcelles forestières par type

## Charger les couches spatiales

Utilisez
[`massif_demo_layers()`](https://pobsteta.github.io/nemeton/reference/massif_demo_layers.md)
pour charger tous les rasters et vecteurs associés :

``` r
layers <- massif_demo_layers()
print(layers)
#> 
#> ── nemeton_layers object ───────
#> 
#> ── Rasters (4) ──
#> 
#> • biomass : massif_demo_biomass.tif [not loaded] 
#> • dem : massif_demo_dem.tif [not loaded] 
#> • landcover : massif_demo_landcover.tif [not loaded] 
#> • species_richness : massif_demo_species_richness.tif [not loaded] 
#> 
#> ── Vectors (2) ──
#> 
#> • roads : massif_demo_roads.gpkg [not loaded] 
#> • water : massif_demo_water.gpkg [not loaded]
```

Le jeu de données inclut : - **Rasters** : biomasse, MNT, occupation du
sol, richesse spécifique - **Vecteurs** : réseau routier, cours d’eau

## Calculer les indicateurs

### Indicateurs individuels

``` r
# Carbone (stock de biomasse)
carbon <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "carbon"
)

# Eau (régulation hydrique)
water <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "water"
)

# Afficher les résultats
head(carbon[, c("parcel_id", "forest_type", "carbon")])
#> Simple feature collection with 6 features and 3 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 698041.8 ymin: 6499388 xmax: 702507.7 ymax: 6504159
#> Projected CRS: RGF93 v1 / Lambert-93
#>   parcel_id      forest_type    carbon                       geometry
#> 1       P01     Futaie mixte  81.00371 POLYGON ((698299.9 6499928,...
#> 2       P02 Futaie résineuse  49.14001 POLYGON ((701702.2 6500418,...
#> 3       P03  Futaie feuillue  58.76237 POLYGON ((702240.4 6500270,...
#> 4       P04  Futaie feuillue 101.49214 POLYGON ((700641.3 6504129,...
#> 5       P05 Futaie résineuse  77.54757 POLYGON ((699268.2 6500307,...
#> 6       P06 Futaie résineuse  68.04375 POLYGON ((699943.5 6499421,...
```

### Indicateurs multiples simultanés

``` r
# Calculer 5 indicateurs en une fois
results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = c("carbon", "biodiversity", "water",
                 "fragmentation", "accessibility")
)

# Vue d'ensemble
summary(results[, c("carbon", "biodiversity", "water")])
#>      carbon        biodiversity       water                 geometry 
#>  Min.   : 48.56   Min.   :20.58   Min.   :0.0000   POLYGON      :20  
#>  1st Qu.: 59.51   1st Qu.:24.29   1st Qu.:0.1925   epsg:2154    : 0  
#>  Median : 70.53   Median :27.03   Median :0.3200   +proj=lcc ...: 0  
#>  Mean   : 69.05   Mean   :26.17   Mean   :0.3277                     
#>  3rd Qu.: 76.58   3rd Qu.:27.81   3rd Qu.:0.4685                     
#>  Max.   :101.49   Max.   :34.39   Max.   :0.7323
```

## Normalisation

Normalisez les indicateurs pour les rendre comparables (échelle 0-100) :

``` r
# Normalisation min-max
normalized <- normalize_indicators(
  results,
  indicators = c("carbon", "biodiversity", "water"),
  method = "minmax"
)

# Comparer avant/après
cat("\nAvant normalisation (carbone):\n")
#> 
#> Avant normalisation (carbone):
summary(results$carbon)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   48.56   59.51   70.53   69.05   76.58  101.49

cat("\nAprès normalisation (carbone):\n")
#> 
#> Après normalisation (carbone):
summary(normalized$carbon_norm)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>    0.00   20.68   41.52   38.71   52.93  100.00
```

### Méthodes de normalisation

``` r
# z-score (distribution normale centrée-réduite)
norm_zscore <- normalize_indicators(
  results,
  indicators = "carbon",
  method = "zscore"
)

# Quantiles (distribution uniforme)
norm_quantile <- normalize_indicators(
  results,
  indicators = "carbon",
  method = "quantile"
)
```

## Agrégation en indices composites

Combinez plusieurs indicateurs en un indice unique :

``` r
# Indice composite avec poids égaux
composite <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  name = "ecosystem_health"
)

# Afficher les résultats
head(composite[, c("parcel_id", "forest_type", "ecosystem_health")])
#> Simple feature collection with 6 features and 3 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 698041.8 ymin: 6499388 xmax: 702507.7 ymax: 6504159
#> Projected CRS: RGF93 v1 / Lambert-93
#>   parcel_id      forest_type ecosystem_health                       geometry
#> 1       P01     Futaie mixte         52.55174 POLYGON ((698299.9 6499928,...
#> 2       P02 Futaie résineuse         27.25092 POLYGON ((701702.2 6500418,...
#> 3       P03  Futaie feuillue         21.79275 POLYGON ((702240.4 6500270,...
#> 4       P04  Futaie feuillue         98.75381 POLYGON ((700641.3 6504129,...
#> 5       P05 Futaie résineuse         54.39274 POLYGON ((699268.2 6500307,...
#> 6       P06 Futaie résineuse         35.04001 POLYGON ((699943.5 6499421,...
```

### Agrégation pondérée

``` r
# Poids personnalisés (carbone 50%, biodiversité 30%, eau 20%)
composite_weighted <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  weights = c(0.5, 0.3, 0.2),
  name = "conservation_index"
)
```

### Méthodes d’agrégation

``` r
# Moyenne géométrique (effets multiplicatifs)
composite_geom <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "water_norm"),
  aggregation = "geometric_mean",
  name = "water_carbon_index"
)

# Minimum (approche conservatrice, facteur limitant)
composite_min <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm"),
  aggregation = "min",
  name = "minimum_performance"
)
```

## Visualisation

### Cartes thématiques

``` r
plot_indicators_map(
  composite,
  indicators = "ecosystem_health",
  title = "Indice de santé écosystémique",
  legend_title = "Score (0-100)"
)
```

![Carte de l'indice de santé
écosystémique](getting-started_fr_files/figure-html/unnamed-chunk-13-1.png)

Carte de l’indice de santé écosystémique

### Cartes multiples (facettes)

``` r
plot_indicators_map(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm"),
  palette = "viridis",
  facet = TRUE,
  ncol = 2,
  title = "Comparaison carbone vs biodiversité"
)
```

![Comparaison carbone vs
biodiversité](getting-started_fr_files/figure-html/unnamed-chunk-14-1.png)

Comparaison carbone vs biodiversité

### Graphique radar

``` r
nemeton_radar(
  normalized,
  unit_id = "P01",
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  title = "Profil multi-indicateurs - Parcelle P01"
)
```

![Profil écosystémique - Parcelle
P01](getting-started_fr_files/figure-html/unnamed-chunk-15-1.png)

Profil écosystémique - Parcelle P01

## Workflow complet

Voici un exemple de workflow complet de bout en bout :

``` r
# 1. Charger les données
data(massif_demo_units)
layers <- massif_demo_layers()

# 2. Calculer les indicateurs
results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = c("carbon", "biodiversity", "water",
                 "fragmentation", "accessibility")
)

# 3. Normaliser (0-100)
normalized <- normalize_indicators(
  results,
  indicators = c("carbon", "biodiversity", "water",
                 "fragmentation", "accessibility"),
  method = "minmax"
)

# 4. Créer un indice composite
composite <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  weights = c(0.4, 0.4, 0.2),
  name = "forest_quality"
)

# 5. Visualiser
plot_indicators_map(
  composite,
  indicators = "forest_quality",
  title = "Indice de qualité forestière",
  legend_title = "Score (0-100)"
)
```

![](getting-started_fr_files/figure-html/unnamed-chunk-16-1.png)

## Analyses avancées

### Inverser un indicateur

Pour les indicateurs où une valeur faible est souhaitable :

``` r
# Exemple: inverser un indicateur
# (Utilisé pour les indicateurs où une valeur faible est souhaitable)
normalized_inv <- invert_indicator(
  normalized,
  indicators = "water_norm",
  suffix = "_inv"
)

# L'indicateur inversé
head(normalized_inv[, c("parcel_id", "water_norm", "water_norm_inv")])
```

### Filtrage et sous-ensembles

``` r
# Sélectionner uniquement les futaies feuillues
broadleaf <- normalized[normalized$forest_type == "Futaie feuillue", ]

# Créer un indice spécifique
broadleaf_index <- create_composite_index(
  broadleaf,
  indicators = c("carbon_norm", "biodiversity_norm"),
  name = "broadleaf_quality"
)
```

## Internationalisation

Le package supporte le français et l’anglais :

``` r
# Définir la langue
nemeton_set_language("fr")  # Français
# nemeton_set_language("en")  # English

# Les messages d'erreur/information seront dans la langue choisie
```

## Export des résultats

``` r
# Export en GeoPackage
sf::st_write(composite, "results/forest_quality.gpkg")

# Export en CSV (sans géométrie)
results_table <- composite %>%
  sf::st_drop_geometry()
write.csv(results_table, "results/forest_quality.csv", row.names = FALSE)
```

## Prochaines étapes

- **Analyse temporelle** :
  [`vignette("temporal-analysis_fr")`](https://pobsteta.github.io/nemeton/articles/temporal-analysis_fr.md) -
  Analyse multi-périodes
- **Familles d’indicateurs** :
  [`vignette("indicator-families_fr")`](https://pobsteta.github.io/nemeton/articles/indicator-families_fr.md) -
  Système 12 familles
- **Internationalisation** :
  [`vignette("internationalization")`](https://pobsteta.github.io/nemeton/articles/internationalization.md) -
  Système i18n

## Références

- Méthode Nemeton : Développée par Vivre en Forêt
- Documentation complète :
  [`help(package = "nemeton")`](https://rdrr.io/pkg/nemeton/man)
- Site web : <https://pobsteta.github.io/nemeton/>

## Session Info

``` r
sessionInfo()
#> R version 4.5.2 (2025-10-31)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 24.04.3 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/blas/libblas.so.3.12.0 
#> LAPACK: /usr/lib/x86_64-linux-gnu/lapack/liblapack.so.3.12.0  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=fr_FR.UTF-8       LC_NUMERIC=C              
#>  [3] LC_TIME=fr_FR.UTF-8        LC_COLLATE=fr_FR.UTF-8    
#>  [5] LC_MONETARY=fr_FR.UTF-8    LC_MESSAGES=fr_FR.UTF-8   
#>  [7] LC_PAPER=fr_FR.UTF-8       LC_NAME=C                 
#>  [9] LC_ADDRESS=C               LC_TELEPHONE=C            
#> [11] LC_MEASUREMENT=fr_FR.UTF-8 LC_IDENTIFICATION=C       
#> 
#> time zone: Europe/Paris
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] ggplot2_4.0.1 nemeton_0.2.0
#> 
#> loaded via a namespace (and not attached):
#>  [1] tidyr_1.3.2          sass_0.4.10          generics_0.1.4      
#>  [4] class_7.3-23         KernSmooth_2.23-26   lattice_0.22-7      
#>  [7] digest_0.6.39        magrittr_2.0.4       evaluate_1.0.5      
#> [10] grid_4.5.2           RColorBrewer_1.1-3   fastmap_1.2.0       
#> [13] jsonlite_2.0.0       e1071_1.7-17         DBI_1.2.3           
#> [16] purrr_1.2.0          viridisLite_0.4.2    scales_1.4.0        
#> [19] codetools_0.2-20     textshaping_1.0.4    jquerylib_0.1.4     
#> [22] cli_3.6.5            rlang_1.1.6          units_1.0-0         
#> [25] withr_3.0.2          cachem_1.1.0         yaml_2.3.12         
#> [28] otel_0.2.0           raster_3.6-32        tools_4.5.2         
#> [31] dplyr_1.1.4          exactextractr_0.10.1 vctrs_0.6.5         
#> [34] R6_2.6.1             proxy_0.4-29         lifecycle_1.0.4     
#> [37] classInt_0.4-11      fs_1.6.6             htmlwidgets_1.6.4   
#> [40] ragg_1.5.0           pkgconfig_2.0.3      desc_1.4.3          
#> [43] pkgdown_2.2.0        terra_1.8-86         pillar_1.11.1       
#> [46] bslib_0.9.0          gtable_0.3.6         glue_1.8.0          
#> [49] Rcpp_1.1.0           sf_1.0-23            systemfonts_1.3.1   
#> [52] xfun_0.55            tibble_3.3.0         tidyselect_1.2.1    
#> [55] knitr_1.51           dichromat_2.0-0.1    farver_2.1.2        
#> [58] htmltools_0.5.9      labeling_0.4.3       rmarkdown_2.30      
#> [61] compiler_4.5.2       S7_0.2.1             sp_2.2-0
```
