# Référentiel Complet 12 Familles

## Introduction

Le package `nemeton` propose un référentiel complet de **12 familles
d’indicateurs** pour l’évaluation multi-critères des services
écosystémiques forestiers. Cette vignette démontre l’utilisation de
l’ensemble du référentiel avec le jeu de données `massif_demo_units`.

### Les 12 Familles

| Code  | Famille                 | Indicateurs                                           | Nb     |
|-------|-------------------------|-------------------------------------------------------|--------|
| **C** | Carbone & Vitalité      | C1 (biomasse), C2 (NDVI)                              | 2      |
| **B** | Biodiversité            | B1 (protection), B2 (structure), B3 (connectivité)    | 3      |
| **W** | Eau                     | W1 (réseau hydro), W2 (zones humides), W3 (TWI)       | 3      |
| **A** | Air & Microclimat       | A1 (couverture), A2 (qualité air)                     | 2      |
| **F** | Fertilité des Sols      | F1 (fertilité), F2 (érosion)                          | 2      |
| **L** | Paysage                 | L1 (fragmentation), L2 (lisière), L3 (TVB)            | 3      |
| **T** | Temps & Dynamique       | T1 (ancienneté), T2 (changements)                     | 2      |
| **R** | Risques & Résilience    | R1 (incendie), R2 (tempête), R3 (stress), R4 (gibier) | 4      |
| **S** | Social & Usages         | S1 (sentiers), S2 (accessibilité), S3 (proximité)     | 3      |
| **P** | Production & Économie   | P1 (volume), P2 (productivité), P3 (qualité)          | 3      |
| **E** | Énergie & Climat        | E1 (bois-énergie), E2 (évitement CO2)                 | 2      |
| **N** | Naturalité & Wilderness | N1 (distance infra), N2 (continuité), N3 (composite)  | 3      |
|       | **Total**               |                                                       | **32** |

## Chargement des Données

``` r
library(nemeton)
library(ggplot2)
library(dplyr)
```

``` r
# Le jeu de données de démonstration
data(massif_demo_units)

# Aperçu des données de base
head(massif_demo_units)
#> Simple feature collection with 6 features and 88 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 698041.8 ymin: 6499388 xmax: 702507.7 ymax: 6504159
#> Projected CRS: RGF93 v1 / Lambert-93
#>   parcel_id      forest_type age_class   management species age
#> 1       P01     Futaie mixte    Mature        Mixte    FASY  68
#> 2       P02 Futaie résineuse     Moyen   Production    PIAB  33
#> 3       P03  Futaie feuillue  Surannée Conservation    QUPE 104
#> 4       P04  Futaie feuillue  Surannée   Production    ABAL 166
#> 5       P05 Futaie résineuse     Moyen   Production    PISY  47
#> 6       P06 Futaie résineuse    Mature   Production    QURO  79
#>   establishment_year density height  dbh volume strata fertility     climate
#> 1               1958     266   30.3 45.8  557.7      4         1 continental
#> 2               1993     465   30.4 57.5 1541.7      1         3  atlantique
#> 3               1922     128   31.7 41.7  232.7      2         2  atlantique
#> 4               1860     104   29.9 42.6  186.1      2         1  atlantique
#> 5               1979     324   27.5 51.5  779.5      2         2  atlantique
#> 6               1947     281   38.6 76.1 2072.1      2         1  atlantique
#>   surface_ha  area_ha        A1   A1_norm       A2   A2_norm B1  B1_norm
#> 1   4.989211 4.989211 0.5293842  32.76917 41.31477 15.769170  0  0.00000
#> 2   5.867935 5.867935 0.6934514  56.20735 54.25911 83.462924  0  0.00000
#> 3   6.557777 6.557777 1.0000000 100.00000 40.10522  9.443733  2 66.66667
#> 4   9.989553 9.989553 0.8866660  83.80943 47.07552 45.895638  0  0.00000
#> 5   5.906395 5.906395 0.5849180  40.70258 48.98128 55.861977  1 33.33333
#> 6   1.048296 1.048296 0.3000000   0.00000 56.56038 95.497643  2 66.66667
#>         B2  B2_norm        B3  B3_norm       C1   C1_norm          C2  C2_norm
#> 1 2.556369 41.55096 0.8262637 90.87085 258.9182  91.81550  0.03279953 98.02844
#> 2 2.387431 35.94171 0.3583569 17.21558 228.1229  78.28157  0.01631406 72.74375
#> 3 2.482645 39.10309 0.6591732 64.56840 193.5217  63.07502  0.03085372 95.04404
#> 4 2.177975 28.98713 0.6150537 57.62336 187.2273  60.30875  0.00574035 56.52626
#> 5 2.455282 38.19456 0.6392320 61.42937 269.4859  96.45981  0.01794201 75.24062
#> 6 1.853111 18.20065 0.5374482 45.40713 277.5413 100.00000 -0.02087305 15.70780
#>          E1    E1_norm       E2  E2_norm F1 F1_norm        F2  F2_norm family_A
#> 1 0.6332431 48.4520928 1.286294 37.35401  3      50 15.017516 63.53406 24.26917
#> 2 0.5003880  0.1410856 1.135298 30.18071  3      50 18.802915 79.54881 69.83514
#> 3 0.5000000  0.0000000 1.037217 25.52125  3      50  8.778060 37.13702 54.72187
#> 4 0.5000000  0.0000000 1.679691 56.04287  4      75 16.643021 70.41103 64.85253
#> 5 0.5239562  8.7113699 0.500000  0.00000  4      75 23.180358 98.06830 48.28228
#> 6 0.5000000  0.0000000 0.500000  0.00000  2      25  6.919386 29.27359 47.74882
#>   family_B family_C  family_E family_F family_L family_N family_P family_R
#> 1 44.14061 94.92197 42.903050 56.76703 31.33202 50.88637 47.68739 32.09087
#> 2 17.71910 75.51266 15.160900 64.77440 88.45910 23.50773 86.78162 24.35791
#> 3 56.77938 79.05953 12.760627 43.56851 64.18903 29.82359 46.78139 42.35100
#> 4 28.87016 58.41750 28.021436 72.70551 56.54965 82.49126 48.20880 26.49766
#> 5 44.31909 85.85022  4.355685 86.53415 29.12421 24.91877 75.19072 66.66667
#> 6 43.42482 57.85390  0.000000 27.13680 73.96207 18.79035 14.75698 13.46698
#>   family_S family_T  family_W        L1   L1_norm        L2   L2_norm        N1
#> 1 24.30425 54.11307  9.825682 0.2521898  10.97026 0.3017459  51.69377 1823.0542
#> 2 24.18268 46.60595 50.880574 0.5743217 100.00000 0.3891689  76.91820  670.1452
#> 3 37.86009 77.38554 23.501831 0.3701597  43.57440 0.4164985  84.80367 1365.9276
#> 4 17.50914 38.82146 49.612081 0.3389725  34.95499 0.3934184  78.14431 2734.2239
#> 5 81.17865 24.74926 61.265609 0.3539412  39.09197 0.1889777  19.15645  628.5385
#> 6 61.86987 55.77872  4.498593 0.3858981  47.92413 0.4691661 100.00000 1259.2921
#>     N1_norm        N2   N2_norm        N3   N3_norm       P1  P1_norm        P2
#> 1  66.05463 200.27051 24.049640  73.73125  62.55485 383.7837 79.52972  2.000000
#> 2  23.10333 125.83536 14.560032  52.89941  32.85982 303.2654 60.34486 10.150362
#> 3  49.02451 101.35012 11.438453  50.19713  29.00781 268.2949 52.01252  4.796243
#> 4 100.00000 384.00619 47.473781 100.00000 100.00000 250.9696 47.88446  6.134844
#> 5  21.55329 238.93704 28.979168  46.84107  24.22387 317.5492 63.74822  8.705667
#> 6  45.05183  20.07441  1.076754  37.03275  10.24246  50.0000  0.00000  4.414458
#>     P2_norm       P3   P3_norm R1 R1_norm R2 R2_norm        R3   R3_norm
#> 1   0.00000 65.29495  63.53244  1       0  4      75 0.3397302  21.27261
#> 2 100.00000 84.57162 100.00000  1       0  2      25 0.5299777  48.07374
#> 3  34.30821 60.26851  54.02344  2      25  3      50 0.5582243  52.05299
#> 4  50.73203 56.03258  46.00991  1       0  3      50 0.3980824  29.49298
#> 5  82.27447 73.76151  79.54946  3      50  3      50 0.8985756 100.00000
#> 6  29.62394 39.45421  14.64700  1       0  1       0 0.4755124  40.40094
#>            S1     S1_norm       S2  S2_norm        S3    S3_norm        T1
#> 1 0.473262981  30.4048558 49.06710 36.33387  1904.090   6.174013  88.06364
#> 2 0.004570495   0.2936322 77.80352 72.25440  1000.000   0.000000  82.82317
#> 3 0.963719475  61.9143116 51.13707 38.92133  2866.255  12.744614 126.47324
#> 4 0.817609054  52.5274243 20.00000  0.00000  1000.000   0.000000  62.19125
#> 5 1.162277601  74.6707102 75.09220 68.86525 15643.478 100.000000  10.00000
#> 6 1.556537495 100.0000000 70.17784 62.72230  4351.499  22.887318 130.42042
#>    T1_norm        T2  T2_norm        W1   W1_norm       W2  W2_norm        W3
#> 1 57.29425 11.324896 50.93189 0.1862923  9.782561 1.119890 10.45221  5.089475
#> 2 53.44804  9.198844 39.76386 0.5393849 28.324119 8.374436 78.16072  8.400556
#> 3 85.48470 14.819030 69.28638 0.4476438 23.506618 2.896998 27.03841  6.050851
#> 4 38.30539  9.117684 39.33753 1.1437187 60.058825 4.913373 45.85774  8.110192
#> 5  0.00000 11.052026 49.49852 1.0737964 56.387074 3.125075 29.16711 13.072421
#> 6 88.38171  6.040972 23.17574 0.0000000  0.000000 0.000000  0.00000  5.470996
#>     W3_norm                       geometry
#> 1  9.242271 POLYGON ((698299.9 6499928,...
#> 2 46.156887 POLYGON ((701702.2 6500418,...
#> 3 19.960465 POLYGON ((702240.4 6500270,...
#> 4 42.919675 POLYGON ((700641.3 6504129,...
#> 5 98.242638 POLYGON ((699268.2 6500307,...
#> 6 13.495779 POLYGON ((699943.5 6499421,...

# Calculer les indicateurs pour la démonstration
# Les indicateurs sont générés de manière synthétique pour les besoins de cette vignette
set.seed(42)
n <- nrow(massif_demo_units)

# Générer des valeurs synthétiques pour tous les indicateurs
massif_demo_units$C1 <- runif(n, 50, 300)  # Biomasse t/ha
massif_demo_units$C2 <- runif(n, 0.3, 0.9)  # NDVI
massif_demo_units$B1 <- runif(n, 0, 100)    # Protection %
massif_demo_units$B2 <- runif(n, 20, 80)    # Structure diversity
massif_demo_units$B3 <- runif(n, 100, 3000) # Distance corridor m
massif_demo_units$W1 <- runif(n, 0, 500)    # Distance hydro m
massif_demo_units$W2 <- runif(n, 0, 50)     # Zones humides %
massif_demo_units$W3 <- runif(n, 2, 15)     # TWI
massif_demo_units$A1 <- runif(n, 40, 95)    # Couverture %
massif_demo_units$A2 <- runif(n, 1, 5)      # Qualité air (ATMO)
massif_demo_units$F1 <- runif(n, 30, 90)    # Fertilité
massif_demo_units$F2 <- runif(n, 0, 50)     # Érosion
massif_demo_units$L1 <- runif(n, 0.1, 0.9)  # Fragmentation
massif_demo_units$L2 <- runif(n, 0, 200)    # Lisière m
massif_demo_units$T1 <- runif(n, 20, 150)   # Ancienneté ans
massif_demo_units$T2 <- runif(n, -20, 20)   # Changement %
massif_demo_units$R1 <- runif(n, 10, 90)    # Risque incendie
massif_demo_units$R2 <- runif(n, 10, 80)    # Risque tempête
massif_demo_units$R3 <- runif(n, 0, 100)    # Stress
massif_demo_units$S1 <- runif(n, 0, 5)      # Accessibilité
massif_demo_units$S2 <- runif(n, 0, 100)    # Sentiers
massif_demo_units$S3 <- runif(n, 0, 50000)  # Proximité m
massif_demo_units$P1 <- runif(n, 50, 500)   # Volume m³/ha
massif_demo_units$P2 <- runif(n, 2, 15)     # Productivité
massif_demo_units$P3 <- runif(n, 30, 90)    # Qualité
massif_demo_units$E1 <- runif(n, 1, 12)     # Bois-énergie
massif_demo_units$E2 <- runif(n, 5, 25)     # Évitement CO2
massif_demo_units$N1 <- runif(n, 100, 5000) # Distance infra m
massif_demo_units$N2 <- runif(n, 0, 100)    # Continuité
massif_demo_units$N3 <- runif(n, 20, 80)    # Naturalité composite
```

## Créer les Indices de Famille

Le système de famille permet d’agréger les indicateurs individuels en
indices synthétiques par famille :

``` r
# Créer tous les indices de famille (12 familles)
# create_family_index() détecte automatiquement toutes les familles par préfixe
result <- create_family_index(massif_demo_units)

# Afficher les indices de famille
result |>
  sf::st_drop_geometry() |>
  select(parcel_id, starts_with("family_")) |>
  head()
#>   parcel_id family_A family_B family_C  family_E family_F family_L family_N
#> 1       P01 24.26917 44.14061 94.92197 42.903050 56.76703 31.33202 50.88637
#> 2       P02 69.83514 17.71910 75.51266 15.160900 64.77440 88.45910 23.50773
#> 3       P03 54.72187 56.77938 79.05953 12.760627 43.56851 64.18903 29.82359
#> 4       P04 64.85253 28.87016 58.41750 28.021436 72.70551 56.54965 82.49126
#> 5       P05 48.28228 44.31909 85.85022  4.355685 86.53415 29.12421 24.91877
#> 6       P06 47.74882 43.42482 57.85390  0.000000 27.13680 73.96207 18.79035
#>   family_P family_R family_S family_T  family_W
#> 1 47.68739 32.09087 24.30425 54.11307  9.825682
#> 2 86.78162 24.35791 24.18268 46.60595 50.880574
#> 3 46.78139 42.35100 37.86009 77.38554 23.501831
#> 4 48.20880 26.49766 17.50914 38.82146 49.612081
#> 5 75.19072 66.66667 81.17865 24.74926 61.265609
#> 6 14.75698 13.46698 61.86987 55.77872  4.498593
```

## Visualisation Radar 12-Axes

Le radar 12-axes permet de visualiser le profil complet d’une parcelle
sur l’ensemble des 12 familles :

``` r
# Radar pour la parcelle 1 (toutes les 12 familles)
nemeton_radar(
  result,
  unit_id = 1,
  mode = "family"
)
```

![](complete-referential_fr_files/figure-html/unnamed-chunk-4-1.png)

## Analyse Croisée Inter-Familles

### Matrice de Corrélation

``` r
# Calculer les corrélations entre toutes les familles
families_all <- c(
  "family_C", "family_B", "family_W", "family_A",
  "family_F", "family_L", "family_T", "family_R",
  "family_S", "family_P", "family_E", "family_N"
)

correlations <- compute_family_correlations(result, families = families_all)

# Visualiser la matrice de corrélation
plot_correlation_matrix(correlations)
```

![](complete-referential_fr_files/figure-html/unnamed-chunk-5-1.png)

### Hotspots Multi-Critères

Identifier les parcelles qui excellent simultanément sur plusieurs
familles :

``` r
# Hotspots pour conservation (C, B, N)
hotspots_conservation <- identify_hotspots(
  result,
  families = c("family_C", "family_B", "family_N"),
  threshold = 0.7,
  min_families = 2
)

# Hotspots pour production durable (P, C, E)
hotspots_production <- identify_hotspots(
  result,
  families = c("family_P", "family_C", "family_E"),
  threshold = 0.7,
  min_families = 2
)

# Hotspots pour services sociaux (S, A, L)
hotspots_social <- identify_hotspots(
  result,
  families = c("family_S", "family_A", "family_L"),
  threshold = 0.7,
  min_families = 2
)

# Afficher les hotspots
table(hotspots_conservation$is_hotspot)
#> 
#> TRUE 
#>   20
table(hotspots_production$is_hotspot)
#> 
#> TRUE 
#>   20
table(hotspots_social$is_hotspot)
#> 
#> FALSE  TRUE 
#>     1    19
```

## Cartographie Multi-Familles

### Familles S, P, E, N

``` r
# Visualiser les nouvelles familles S, P, E, N
library(patchwork)

p_social <- ggplot(result) +
  geom_sf(aes(fill = family_S)) +
  scale_fill_viridis_c(name = "Social") +
  labs(title = "Famille S - Social & Usages") +
  theme_minimal()

p_production <- ggplot(result) +
  geom_sf(aes(fill = family_P)) +
  scale_fill_viridis_c(name = "Production") +
  labs(title = "Famille P - Production & Économie") +
  theme_minimal()

p_energy <- ggplot(result) +
  geom_sf(aes(fill = family_E)) +
  scale_fill_viridis_c(name = "Énergie") +
  labs(title = "Famille E - Énergie & Climat") +
  theme_minimal()

p_naturalness <- ggplot(result) +
  geom_sf(aes(fill = family_N)) +
  scale_fill_viridis_c(name = "Naturalité") +
  labs(title = "Famille N - Naturalité & Wilderness") +
  theme_minimal()

(p_social + p_production) / (p_energy + p_naturalness)
```

![](complete-referential_fr_files/figure-html/unnamed-chunk-7-1.png)

### Toutes les Familles

``` r
# Créer une facette pour toutes les 12 familles
result_long <- result |>
  sf::st_drop_geometry() |>
  tidyr::pivot_longer(
    cols = starts_with("family_"),
    names_to = "famille",
    values_to = "valeur"
  ) |>
  left_join(
    result |> select(parcel_id, geometry),
    by = "parcel_id"
  ) |>
  sf::st_as_sf()

# Labels des familles pour la facette
family_labels <- c(
  family_C = "C - Carbone",
  family_B = "B - Biodiversité",
  family_W = "W - Eau",
  family_A = "A - Air",
  family_F = "F - Fertilité",
  family_L = "L - Paysage",
  family_T = "T - Temps",
  family_R = "R - Risques",
  family_S = "S - Social",
  family_P = "P - Production",
  family_E = "E - Énergie",
  family_N = "N - Naturalité"
)

ggplot(result_long) +
  geom_sf(aes(fill = valeur)) +
  facet_wrap(~famille, ncol = 4, labeller = labeller(famille = family_labels)) +
  scale_fill_viridis_c(name = "Score") +
  labs(title = "Référentiel Complet 12 Familles") +
  theme_minimal() +
  theme(
    strip.text = element_text(face = "bold"),
    axis.text = element_blank(),
    axis.ticks = element_blank()
  )
```

![](complete-referential_fr_files/figure-html/unnamed-chunk-8-1.png)

## Normalisation et Indice Composite

``` r
# Normaliser tous les indicateurs
result_norm <- normalize_indicators(
  result,
  indicators = c(
    paste0("C", 1:2), paste0("B", 1:3), paste0("W", 1:3),
    paste0("A", 1:2), paste0("F", 1:2), paste0("L", 1:2),
    paste0("T", 1:2), paste0("R", 1:3), paste0("S", 1:3),
    paste0("P", 1:3), paste0("E", 1:2), paste0("N", 1:3)
  ),
  method = "minmax"
)

# Créer un indice composite global (toutes familles)
result_composite <- create_composite_index(
  result_norm,
  indicators = families_all,
  weights = rep(1, 12), # Poids égaux pour toutes les familles
  name = "nemeton_index_12"
)

# Visualiser l'indice composite
ggplot(result_composite) +
  geom_sf(aes(fill = nemeton_index_12)) +
  scale_fill_viridis_c(name = "Score", limits = c(0, 100)) +
  labs(title = "Indice Composite Nemeton (12 Familles)") +
  theme_minimal()
```

![](complete-referential_fr_files/figure-html/unnamed-chunk-9-1.png)

## Comparaison de Scénarios

``` r
# Créer différents indices pour différents objectifs de gestion

# Scénario 1: Conservation intégrale
composite_conservation <- create_composite_index(
  result_norm,
  indicators = c("family_C", "family_B", "family_W", "family_N"),
  weights = c(0.3, 0.4, 0.15, 0.15),
  name = "conservation"
)

# Scénario 2: Production durable
composite_production <- create_composite_index(
  result_norm,
  indicators = c("family_P", "family_E", "family_F", "family_C"),
  weights = c(0.4, 0.25, 0.2, 0.15),
  name = "production"
)

# Scénario 3: Services sociaux
composite_social <- create_composite_index(
  result_norm,
  indicators = c("family_S", "family_A", "family_L", "family_R"),
  weights = c(0.35, 0.25, 0.2, 0.2),
  name = "social"
)

# Comparer les scénarios
comparison <- result |>
  mutate(
    conservation = composite_conservation$conservation,
    production = composite_production$production,
    social = composite_social$social
  ) |>
  sf::st_drop_geometry() |>
  select(parcel_id, conservation, production, social) |>
  tidyr::pivot_longer(cols = -parcel_id, names_to = "scenario", values_to = "score")

# Visualiser le classement des parcelles selon les scénarios
ggplot(comparison, aes(x = reorder(parcel_id, score), y = score, fill = scenario)) +
  geom_col(position = "dodge") +
  coord_flip() +
  scale_fill_viridis_d() +
  labs(
    title = "Classement des Parcelles selon 3 Scénarios de Gestion",
    x = "Parcelle",
    y = "Score",
    fill = "Scénario"
  ) +
  theme_minimal()
```

![](complete-referential_fr_files/figure-html/unnamed-chunk-10-1.png)

## Conclusion

Cette vignette a démontré l’utilisation complète du référentiel 12
familles de nemeton. Le package permet :

1.  **Évaluation holistique** : Couvre l’ensemble des dimensions des
    services écosystémiques (biophysiques, écologiques, sociaux,
    économiques)
2.  **Flexibilité** : Possibilité de créer des indices composites
    adaptés à différents objectifs de gestion
3.  **Analyse croisée** : Identification des synergies et trade-offs
    entre familles
4.  **Visualisation** : Radars 12-axes, cartes multi-familles, matrices
    de corrélation

Pour aller plus loin, consultez la vignette **“Multi-Criteria
Optimization”** qui présente les outils d’analyse Pareto, de clustering
et de trade-off analysis.

## Références

- Obstétar, P. (2025). *nemeton: Ecosystem Services Assessment for
  Forest Management*. R package.
- MEA (2005). *Millennium Ecosystem Assessment*. Island Press.
- Boitani, L., et al. (2008). *Wilderness: Earth’s Last Wild Places*.
  Conservation International.
