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
#> Simple feature collection with 20 features and 89 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 698041.8 ymin: 6499215 xmax: 702793.8 ymax: 6504159
#> Projected CRS: RGF93 v1 / Lambert-93
#> First 10 features:
#>    parcel_id      forest_type age_class   management species age
#> 1        P01     Futaie mixte    Mature        Mixte      09  68
#> 2        P02 Futaie résineuse     Moyen   Production      64  33
#> 3        P03  Futaie feuillue  Surannée Conservation      03 104
#> 4        P04  Futaie feuillue  Surannée   Production      03 166
#> 5        P05 Futaie résineuse     Moyen   Production      61  47
#> 6        P06 Futaie résineuse    Mature   Production      61  79
#> 7        P07  Futaie feuillue    Mature        Mixte      03  75
#> 8        P08  Futaie feuillue    Mature   Production      52  71
#> 9        P09     Futaie mixte     Moyen   Production      03  48
#> 10       P10          Taillis  Surannée   Production      52 165
#>    establishment_year density height  dbh volume strata fertility     climate
#> 1                1958     266   30.3 45.8  557.7      4         1 continental
#> 2                1993     465   30.4 57.5 1541.7      1         3  atlantique
#> 3                1922     128   31.7 41.7  232.7      2         2  atlantique
#> 4                1860     104   29.9 42.6  186.1      2         1  atlantique
#> 5                1979     324   27.5 51.5  779.5      2         2  atlantique
#> 6                1947     281   38.6 76.1 2072.1      2         1  atlantique
#> 7                1951     184   33.9 47.1  456.5      2         3 continental
#> 8                1955     169   27.2 38.8  228.3      3         2  montagnard
#> 9                1978     369   24.8 34.0  349.0      4         3  atlantique
#> 10               1861     632   25.7 34.0  619.4      2         2  montagnard
#>    surface_ha                       geometry        C1        C2       B1
#> 1    4.989211 POLYGON ((698299.9 6499928,... 271.52938 0.6447576 67.56073
#> 2    5.867935 POLYGON ((701702.2 6500418,... 300.00000 0.6056744 98.28172
#> 3    6.557777 POLYGON ((702240.4 6500270,... 110.16193 0.5285871 75.95443
#> 4    9.989553 POLYGON ((700641.3 6504129,...  93.23794 1.1674470 56.64884
#> 5    5.906395 POLYGON ((699268.2 6500307,... 300.00000 0.6314632 84.96897
#> 6    1.048296 POLYGON ((699943.5 6499421,... 300.00000 0.9846671 18.94739
#> 7   17.079363 POLYGON ((698500.5 6499360,... 228.09783 0.9382652 27.12866
#> 8   11.414577 POLYGON ((699061.9 6499649,... 101.31511 0.7939883 82.81585
#> 9   16.105209 POLYGON ((702258.5 6500666,... 187.32636 0.9300316 69.32048
#> 10  10.733433 POLYGON ((699897.1 6500739,... 277.78929 0.9703610 24.05447
#>          B2       B3        W1        W2        W3        A1       A2 F1
#> 1  48.05999 46.75415 1.1875729 37.392918 11.262508 100.00000 48.38184  1
#> 2  30.72276 50.79763 0.6421157 22.019763 10.763668 100.00000 73.07190  3
#> 3  65.58163 63.01069 3.7125564 24.070649  5.852777  68.22187 48.53609  2
#> 4  71.39962 64.22587 6.2349453  7.879780  5.333345 100.00000 55.56960  1
#> 5  25.31719 73.97430 5.8682237 21.409464  9.680398 100.00000 72.48102  2
#> 6  53.99485 49.62298 6.5378436  7.182230  9.726250 100.00000 69.09907  1
#> 7  40.21940 88.94029 1.3612999 18.075460 11.261136  99.31616 52.97349  3
#> 8  61.44101 92.19277 7.5577626 12.682134 10.138721  80.99475 52.47895  2
#> 9  35.01887 37.51426 2.3489907  4.646987  4.199967  97.72290 69.96364  3
#> 10 84.88981 74.33732 1.1925764  7.444086  5.589748 100.00000 92.02824  2
#>           F2       L1       L2  T1        T2        R1       R2        R3
#> 1  25.019879 57.94143 49.02609  68  7.745998 35.404437 63.67438 10.975559
#> 2   4.315520 32.99353 46.67417  33  7.087985 56.732381 55.62368 75.739443
#> 3  10.886737 41.24140 23.62314 104  2.554360  5.098883 67.18918 37.155495
#> 4  33.100871 88.95956 39.65036 166  5.036521 73.789178 40.38996 33.317838
#> 5  17.500878 49.69644 72.70574  47 10.166800 57.295560 40.61244 44.912393
#> 6   4.733067 40.25978 75.83629  79 16.832511 36.984480 93.48662 35.748304
#> 7  30.424024 59.29529 43.53071  75  6.451203 11.019857 73.85662 32.358239
#> 8   7.176736 31.12124 29.53081  71 15.156129 52.860174 63.19731 64.535748
#> 9  32.376606 50.36911 39.19686  48 13.003366 49.663877 76.82843 30.659396
#> 10 31.036376 31.77980 38.41794 165 13.513248 39.872887 53.33232  9.327956
#>           R4        S1       S2       S3        P1       P2       P3        E1
#> 1  24.564726 0.6142734 80.64513 57354.57  582.4222 4.990758 60.95405 11.132573
#> 2  48.959040 0.7971139 89.99527 76907.49 1000.0000 9.520484 79.39129 15.000000
#> 3   5.968351 2.3380220 82.53975 41461.33  215.6208 6.577982 62.21006  4.219383
#> 4  20.677678 3.6500435 29.52521 13962.24  205.1654 6.470144 62.59759  2.608120
#> 5  24.612972 0.5191291 68.70905 45003.21  780.8117 6.207055 89.59382 15.000000
#> 6  22.180692 4.0203980 71.77637 60740.65 1000.0000 4.884225 87.84672 15.000000
#> 7  56.974140 2.5890880 22.40336 53357.71  530.2878 8.964739 78.55470 10.287347
#> 8  29.544706 0.6595758 89.03669 17989.83  203.7486 8.485887 59.11573  2.883519
#> 9  34.884517 4.0626261 55.88517 27667.98  285.6040 5.507209 45.64794  7.067319
#> 10 11.152566 1.1385111 39.98904 25586.54  627.6109 6.433025 53.31236 13.741362
#>           E2       N1        N2          N3   C1_norm   C2_norm   B1_norm
#> 1  24.491660 1961.124 9009.2192  70.3324503  89.83192  18.18404  68.69188
#> 2  30.000000 5976.014 5456.9475   0.3475665 100.00000  12.06639 100.00000
#> 3   9.282643 1398.919 5089.7033  59.2891167  32.20069   0.00000  77.24599
#> 4   5.737864 3606.938 8946.6803 100.0000000  26.15641 100.00000  57.57144
#> 5  30.000000 3052.444 8478.4504  20.5651477 100.00000  16.10308  86.43282
#> 6  30.000000 7762.738 3903.8072  36.2273780 100.00000  71.38969  19.14945
#> 7  22.632164 3562.190  484.7918  32.9283307  74.32065  64.12644  27.48708
#> 8   6.343742 4232.655 7395.7756  44.4674909  29.04111  41.54295  84.23855
#> 9  15.548102 4227.145 8797.3736  44.9614412  59.75941  62.83765  70.48526
#> 10 30.000000 5757.186 3592.2587  92.8142964  92.06760  69.15037  24.35414
#>      B2_norm   B3_norm    W1_norm    W2_norm    W3_norm   A1_norm    A2_norm
#> 1   50.33336  28.62731  13.035855 100.000000 100.000000 100.00000   5.025117
#> 2   26.95334  34.97861   5.589419  53.053237  93.591755 100.00000  58.750856
#> 3   73.96207  54.16226  47.506263  59.316263  30.504976  30.98201   5.360775
#> 4   81.80788  56.07101  81.941248   9.872349  23.832197 100.00000  20.665725
#> 5   19.66369  71.38334  76.934862  51.189497  79.675744 100.00000  57.465104
#> 6   58.33678  33.13352  86.076335   7.742161  80.264772 100.00000  50.105960
#> 7   39.75998  94.89117  15.407530  41.008065  99.982382  98.51479  15.016584
#> 8   68.37826 100.00000 100.000000  24.537849  85.563496  58.72305  13.940455
#> 9   32.74684  14.11376  28.891225   0.000000   9.272475  95.05442  51.987274
#> 10 100.00000  71.95356  13.104162   8.541823  27.126022 100.00000 100.000000
#>    F1_norm    F2_norm    L1_norm  L2_norm  T1_norm   T2_norm    R1_norm
#> 1        0  71.926722  46.370969 45.50493 35.66879  45.88045  44.119121
#> 2      100   0.000000   3.237100 41.29189 13.37580  41.96130  75.168549
#> 3       50  22.828336  17.497324  0.00000 58.59873  14.95889   0.000000
#> 4        0 100.000000 100.000000 28.70996 98.08917  29.74272 100.000000
#> 5       50  45.805793  32.115731 87.92288 22.29299  60.29882  75.988429
#> 6        0   1.450555  15.800145 93.53071 42.67516 100.00000  46.419363
#> 7      100  90.700662  48.711735 35.66092 40.12739  38.16861   8.619812
#> 8       50   9.939834   0.000000 10.58256 37.57962  90.01542  69.531352
#> 9      100  97.483913  33.278733 27.89759 22.92994  77.19349  64.878152
#> 10      50  92.827967   1.138619 26.50229 97.45223  80.23037  50.624334
#>      R2_norm    R3_norm   R4_norm    S1_norm    S2_norm    S3_norm   P1_norm
#> 1   55.33710   2.480901 32.323036   2.685042  86.591937  71.857692  58.23268
#> 2   43.27603 100.000000 67.877065   7.844928 100.000000 100.000000 100.00000
#> 3   60.60275  41.901695  5.219342  51.330450  89.308809  48.982723  21.54416
#> 4   20.45379  36.123091 26.657773  88.356628  13.286161   9.403583  20.49838
#> 5   20.78710  53.581750 32.393354   0.000000  69.475633  54.080517  78.07616
#> 6  100.00000  39.782798 28.848373  98.808295  73.874169  76.731251 100.00000
#> 7   70.59152  34.678162 79.558849  58.415709   3.073461  66.105055  53.01805
#> 8   54.62239  83.129884 39.581217   3.963506  98.625389  15.200453  20.35666
#> 9   75.04370  32.120106 47.363842 100.000000  51.086239  29.130106  28.54407
#> 10  39.84325   0.000000 12.775189  17.479401  28.291260  26.134312  62.75258
#>      P2_norm   P3_norm   E1_norm   E2_norm   N1_norm  N2_norm     N3_norm
#> 1   17.55010  53.89207  74.21715  81.63887 12.965307 98.39928  70.3324503
#> 2  100.00000  83.57467 100.00000 100.00000 61.069681 57.39465   0.3475665
#> 3   46.44068  55.91417  28.12922  30.94214  6.229248 53.15548  59.2891167
#> 4   44.47782  56.53806  17.38747  19.12621 32.684614 97.67738 100.0000000
#> 5   39.68908 100.00000 100.00000 100.00000 26.040953 92.27251  20.5651477
#> 6   15.61098  97.18730 100.00000 100.00000 82.477298 39.46642  36.2273780
#> 7   89.88434  82.22784  68.58231  75.44055 32.148467  0.00000  32.9283307
#> 8   81.16830  50.93252  19.22346  21.14581 40.181634 79.77496  44.4674909
#> 9   26.95051  29.25037  47.11546  51.82701 40.115624 95.95390  44.9614412
#> 10  43.80218  41.58953  91.60908 100.00000 58.447791 35.87015  92.8142964
#>    famille_carbone famille_biodiversite famille_eau famille_air famille_sol
#> 1         54.00798             49.21751    71.01195    52.51256  35.9633611
#> 2         56.03319             53.97732    50.74480    79.37543  50.0000000
#> 3         16.10034             68.45678    45.77583    18.17139  36.4141678
#> 4         63.07820             65.15011    38.54860    60.33286  50.0000000
#> 5         58.05154             59.15995    69.26670    78.73255  47.9028964
#> 6         85.69484             36.87325    58.02776    75.05298   0.7252773
#> 7         69.22355             54.04608    52.13266    56.76569  95.3503311
#> 8         35.29203             84.20560    70.03378    36.33175  29.9699172
#> 9         61.29853             39.11529    12.72123    73.52085  98.7419564
#> 10        80.60898             65.43590    16.25734   100.00000  71.4139836
#>    famille_paysage famille_temporel famille_risque famille_social
#> 1        45.937952         40.77462       33.56504       53.71156
#> 2        22.264494         27.66855       71.58041       69.28164
#> 3         8.748662         36.77881       26.93095       63.20733
#> 4        64.354982         63.91594       45.80866       37.01546
#> 5        60.019306         41.29591       45.68766       41.18538
#> 6        54.665429         71.33758       53.76263       83.13790
#> 7        42.186329         39.14800       48.36209       42.53141
#> 8         5.291278         63.79752       61.71621       39.26312
#> 9        30.588161         50.06171       54.85145       60.07212
#> 10       13.820455         88.84130       25.81069       23.96832
#>    famille_production famille_energie famille_naturalite
#> 1            43.22495        77.92801           60.56568
#> 2            94.52489       100.00000           39.60397
#> 3            41.29967        29.53568           39.55795
#> 4            40.50475        18.25684           76.78733
#> 5            72.58841       100.00000           46.29287
#> 6            70.93276       100.00000           52.72370
#> 7            75.04341        72.01143           21.69227
#> 8            50.81916        20.18463           54.80803
#> 9            28.24832        49.47123           60.34366
#> 10           49.38143        95.80454           62.37741

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
  labs(
    title = "Massif Demo - Types forestiers",
    fill = "Type de forêt"
  )
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

# Carbone (via NDVI)
carbon <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "indicateur_c2_ndvi"
)

# Eau (TWI - Topographic Wetness Index)
water <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "indicateur_w3_humidite"
)

# Afficher les résultats
head(carbon[, c("parcel_id", "forest_type", "indicateur_c2_ndvi")])
#> Simple feature collection with 6 features and 3 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 698041.8 ymin: 6499388 xmax: 702507.7 ymax: 6504159
#> Projected CRS: RGF93 v1 / Lambert-93
#>   parcel_id      forest_type indicateur_c2_ndvi                       geometry
#> 1       P01     Futaie mixte                 NA POLYGON ((698299.9 6499928,...
#> 2       P02 Futaie résineuse                 NA POLYGON ((701702.2 6500418,...
#> 3       P03  Futaie feuillue                 NA POLYGON ((702240.4 6500270,...
#> 4       P04  Futaie feuillue                 NA POLYGON ((700641.3 6504129,...
#> 5       P05 Futaie résineuse                 NA POLYGON ((699268.2 6500307,...
#> 6       P06 Futaie résineuse                 NA POLYGON ((699943.5 6499421,...
```

### Indicateurs multiples simultanés

``` r

# Calculer 3 indicateurs en une fois
results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = c("indicateur_c2_ndvi", "indicateur_w3_humidite", "indicateur_l2_fragmentation")
)
#> Error:
#> ! no valid constructor available for the argument list

# Vue d'ensemble
summary(results[, c("indicateur_c2_ndvi", "indicateur_w3_humidite", "indicateur_l2_fragmentation")])
#> Error:
#> ! object 'results' not found
```

## Normalisation

Normalisez les indicateurs pour les rendre comparables (échelle 0-100) :

``` r

# Normalisation min-max
normalized <- normalize_indicators(
  results,
  indicators = c("indicateur_c2_ndvi", "indicateur_w3_humidite", "indicateur_l2_fragmentation"),
  method = "minmax"
)
#> Error:
#> ! object 'results' not found

# Comparer avant/après
cat("\nAvant normalisation (carbone NDVI):\n")
#> 
#> Avant normalisation (carbone NDVI):
summary(results$indicateur_c2_ndvi)
#> Error:
#> ! object 'results' not found

cat("\nAprès normalisation (carbone NDVI):\n")
#> 
#> Après normalisation (carbone NDVI):
summary(normalized$indicateur_c2_ndvi_norm)
#> Error:
#> ! object 'normalized' not found
```

### Méthodes de normalisation

``` r

# z-score (distribution normale centrée-réduite)
norm_zscore <- normalize_indicators(
  results,
  indicators = "indicateur_c2_ndvi",
  method = "zscore"
)
#> Error:
#> ! object 'results' not found

# Quantiles (distribution uniforme)
norm_quantile <- normalize_indicators(
  results,
  indicators = "indicateur_c2_ndvi",
  method = "quantile"
)
#> Error:
#> ! object 'results' not found
```

## Agrégation en indices composites

Combinez plusieurs indicateurs en un indice unique :

``` r

# Indice composite avec poids égaux
composite <- create_composite_index(
  normalized,
  indicators = c("indicateur_c2_ndvi_norm", "indicateur_w3_humidite_norm", "indicateur_l2_fragmentation_norm"),
  name = "ecosystem_health"
)
#> Error:
#> ! object 'normalized' not found

# Afficher les résultats
head(composite[, c("parcel_id", "forest_type", "ecosystem_health")])
#> Error:
#> ! object 'composite' not found
```

### Agrégation pondérée

``` r

# Poids personnalisés (carbone 50%, paysage 30%, eau 20%)
composite_weighted <- create_composite_index(
  normalized,
  indicators = c("indicateur_c2_ndvi_norm", "indicateur_l2_fragmentation_norm", "indicateur_w3_humidite_norm"),
  weights = c(0.5, 0.3, 0.2),
  name = "conservation_index"
)
#> Error:
#> ! object 'normalized' not found
```

### Méthodes d’agrégation

``` r

# Moyenne géométrique (effets multiplicatifs)
composite_geom <- create_composite_index(
  normalized,
  indicators = c("indicateur_c2_ndvi_norm", "indicateur_w3_humidite_norm"),
  aggregation = "geometric_mean",
  name = "water_carbon_index"
)
#> Error:
#> ! object 'normalized' not found

# Minimum (approche conservatrice, facteur limitant)
composite_min <- create_composite_index(
  normalized,
  indicators = c("indicateur_c2_ndvi_norm", "indicateur_w3_humidite_norm"),
  aggregation = "min",
  name = "minimum_performance"
)
#> Error:
#> ! object 'normalized' not found
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
#> Error:
#> ! object 'composite' not found
```

### Cartes multiples (facettes)

``` r

plot_indicators_map(
  normalized,
  indicators = c("indicateur_c2_ndvi_norm", "indicateur_w3_humidite_norm"),
  palette = "viridis",
  facet = TRUE,
  ncol = 2,
  title = "Comparaison carbone vs eau"
)
#> Error:
#> ! object 'normalized' not found
```

### Graphique radar

``` r

nemeton_radar(
  normalized,
  unit_id = "P01",
  indicators = c("indicateur_c2_ndvi_norm", "indicateur_w3_humidite_norm", "indicateur_l2_fragmentation_norm"),
  title = "Profil multi-indicateurs - Parcelle P01"
)
#> Error:
#> ! object 'normalized' not found
```

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
  indicators = c(
    "indicateur_c2_ndvi", "indicateur_w3_humidite", "indicateur_l2_fragmentation"
  )
)
#> Error:
#> ! no valid constructor available for the argument list

# 3. Normaliser (0-100)
normalized <- normalize_indicators(
  results,
  indicators = c(
    "indicateur_c2_ndvi", "indicateur_w3_humidite", "indicateur_l2_fragmentation"
  ),
  method = "minmax"
)
#> Error:
#> ! object 'results' not found

# 4. Créer un indice composite
composite <- create_composite_index(
  normalized,
  indicators = c("indicateur_c2_ndvi_norm", "indicateur_w3_humidite_norm", "indicateur_l2_fragmentation_norm"),
  weights = c(0.4, 0.4, 0.2),
  name = "forest_quality"
)
#> Error:
#> ! object 'normalized' not found

# 5. Visualiser
plot_indicators_map(
  composite,
  indicators = "forest_quality",
  title = "Indice de qualité forestière",
  legend_title = "Score (0-100)"
)
#> Error:
#> ! object 'composite' not found
```

## Analyses avancées

### Inverser un indicateur

Pour les indicateurs où une valeur faible est souhaitable :

``` r

# Exemple: inverser un indicateur
# (Utilisé pour les indicateurs où une valeur faible est souhaitable)
normalized_inv <- invert_indicator(
  normalized,
  indicators = "indicateur_w3_humidite_norm",
  suffix = "_inv"
)

# L'indicateur inversé
head(normalized_inv[, c("parcel_id", "indicateur_w3_humidite_norm", "indicateur_w3_humidite_norm_inv")])
```

### Filtrage et sous-ensembles

``` r

# Sélectionner uniquement les futaies feuillues
broadleaf <- normalized[normalized$forest_type == "Futaie feuillue", ]
#> Error:
#> ! object 'normalized' not found

# Créer un indice spécifique
broadleaf_index <- create_composite_index(
  broadleaf,
  indicators = c("indicateur_c2_ndvi_norm", "indicateur_w3_humidite_norm"),
  name = "broadleaf_quality"
)
#> Error:
#> ! object 'broadleaf' not found
```

## Internationalisation

Le package supporte le français et l’anglais :

``` r

# Définir la langue
nemeton_set_language("fr") # Français
# nemeton_set_language("en")  # English

# Les messages d'erreur/information seront dans la langue choisie
```

## Export des résultats

``` r

# Export en GeoPackage
sf::st_write(composite, "results/forest_quality.gpkg")

# Export en CSV (sans géométrie)
results_table <- composite |>
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
  [`help(package = "nemeton")`](https://pobsteta.github.io/nemeton/reference)
- Site web : <https://pobsteta.github.io/nemeton/>

## Session Info

``` r

sessionInfo()
#> R version 4.6.0 (2026-04-24)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 24.04.4 LTS
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
#> [1] ggplot2_4.0.3       nemeton_0.90.0.9000
#> 
#> loaded via a namespace (and not attached):
#>  [1] omnibus_1.2.15       rappdirs_0.3.4       sass_0.4.10         
#>  [4] generics_0.1.4       xml2_1.5.2           class_7.3-23        
#>  [7] KernSmooth_2.23-26   lattice_0.22-9       digest_0.6.39       
#> [10] magrittr_2.0.5       evaluate_1.0.5       grid_4.6.0          
#> [13] RColorBrewer_1.1-3   fastmap_1.2.0        jsonlite_2.0.0      
#> [16] e1071_1.7-17         DBI_1.3.0            fasterRaster_8.4.1.2
#> [19] scales_1.4.0         codetools_0.2-20     textshaping_1.0.5   
#> [22] jquerylib_0.1.4      cli_3.6.6            rgrass_0.5-3        
#> [25] rlang_1.2.0          units_1.0-1          withr_3.0.2         
#> [28] cachem_1.1.0         yaml_2.3.12          otel_0.2.0          
#> [31] raster_3.6-32        tools_4.6.0          dplyr_1.2.1         
#> [34] exactextractr_0.10.1 vctrs_0.7.3          R6_2.6.1            
#> [37] proxy_0.4-29         lifecycle_1.0.5      classInt_0.4-11     
#> [40] fs_2.1.0             htmlwidgets_1.6.4    ragg_1.5.2          
#> [43] pkgconfig_2.0.3      desc_1.4.3           pkgdown_2.2.0       
#> [46] terra_1.9-27         bslib_0.11.0         pillar_1.11.1       
#> [49] gtable_0.3.6         data.table_1.18.4    glue_1.8.1          
#> [52] Rcpp_1.1.1-1.1       sf_1.1-1             systemfonts_1.3.2   
#> [55] xfun_0.58            tibble_3.3.1         tidyselect_1.2.1    
#> [58] knitr_1.51           farver_2.1.2         htmltools_0.5.9     
#> [61] rmarkdown_2.31       compiler_4.6.0       S7_0.2.2            
#> [64] sp_2.2-1
```
