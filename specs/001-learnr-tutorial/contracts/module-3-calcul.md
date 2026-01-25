# Module 3 API Contract: Calcul des 12 Familles d'Indicateurs

**Module**: Tutorial Module 3 - Calcul des 12 Familles d'Indicateurs
**Feature**: 001-learnr-tutorial
**User Story**: US3 (P1)

## Overview

Ce module enseigne le calcul progressif des 12 familles d'indicateurs écosystémiques sur les parcelles forestières :
- **C** : Régulation climatique (biomasse, NDVI)
- **B** : Biodiversité (protection, diversité, connectivité)
- **W** : Régulation eau
- **F** : Fertilité sols
- **L** : Valeur paysagère
- **A** : Qualité air
- **T** : Analyse temporelle
- **R** : Régulation risques
- **S** : Fonction sociale
- **P** : Production bois
- **E** : Potentiel énergétique
- **N** : Naturalité

**Pédagogie** : Workflow complet du calcul d'indicateurs avec validation automatique et dashboard interactif.

---

## Exercice 3.1 : Calcul Famille C (Régulation Climatique)

### Objectif Pédagogique
L'utilisateur apprend à calculer les indicateurs de régulation climatique (stockage carbone, productivité).

### Inputs de l'exercice
- `parcelles` : objet sf avec métriques LiDAR (Module 2)
  - Colonnes requises : `id_parcel`, `mean.P95` (hauteur), `mean.cover` (couvert), `geometry`

### Code attendu de l'utilisateur
```r
# Calculer famille C (Régulation climatique)
famille_C <- nemeton::calculate_family_C(
  parcels = parcelles,
  include_ndvi = FALSE  # NDVI optionnel pour ce tutorial
)

# Visualiser résultats
print(famille_C)
summary(famille_C$family_index_C)

# Carte thématique
plot(famille_C["family_index_C"], main = "Indice Régulation Climatique (C)")
```

### Outputs attendus
- `famille_C` : objet sf avec indicateurs famille C
- Colonnes ajoutées :
  - `ind_C_biomass` : Biomasse estimée (t/ha)
  - `ind_C_carbon` : Carbone stocké (tC/ha)
  - `ind_C_productivity` : Productivité (m³/ha/an)
  - `family_index_C` : Indice normalisé famille C (0-1)

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "sf"),
          "Excellent ! Famille C calculée."),
  pass_if(~ "family_index_C" %in% names(.result),
          "Indice famille C présent."),
  fail_if(~ !"family_index_C" %in% names(.result),
          "Indice famille C manquant. Vérifiez calculate_family_C()."),
  pass_if(~ all(.result$family_index_C >= 0 & .result$family_index_C <= 1),
          "Indice normalisé correctement (0-1)."),
  pass_if(~ mean(.result$family_index_C, na.rm = TRUE) > 0.1,
          "Valeurs réalistes pour CIRON.")
)
```

### Concepts enseignés
- Équations allométriques (hauteur → biomasse)
- Stockage carbone forestier
- Normalisation indicateurs (min-max scaling)
- Indice de famille

---

## Exercice 3.2 : Calcul Famille B (Biodiversité)

### Objectif Pédagogique
L'utilisateur apprend à calculer les indicateurs de biodiversité (protection, diversité structurale, connectivité).

### Inputs de l'exercice
- `parcelles` : objet sf avec métriques LiDAR
- `zones_protegees` : optionnel (sf des zones Natura 2000, PNR, etc.)

### Code attendu de l'utilisateur
```r
# Calculer famille B (Biodiversité)
famille_B <- nemeton::calculate_family_B(
  parcels = parcelles,
  protected_areas = NULL,  # Optionnel
  calculate_connectivity = TRUE
)

# Visualiser résultats
print(famille_B)
summary(famille_B$family_index_B)

# Carte thématique
plot(famille_B["family_index_B"], main = "Indice Biodiversité (B)")
```

### Outputs attendus
- `famille_B` : objet sf avec indicateurs famille B
- Colonnes ajoutées :
  - `ind_B_protection` : Statut protection (0-1)
  - `ind_B_structural_diversity` : Diversité structurale (Shannon)
  - `ind_B_connectivity` : Connectivité forestière (0-1)
  - `family_index_B` : Indice normalisé famille B (0-1)

### Validation gradethis
```r
grade_result(
  pass_if(~ "family_index_B" %in% names(.result),
          "Super ! Famille B calculée."),
  pass_if(~ all(.result$family_index_B >= 0 & .result$family_index_B <= 1),
          "Indice normalisé correctement."),
  pass_if(~ all(!is.na(.result$ind_B_structural_diversity)),
          "Diversité structurale calculée pour toutes les parcelles.")
)
```

### Concepts enseignés
- Diversité structurale (hauteurs, densités)
- Connectivité écologique (distance zones boisées)
- Aires protégées (optionnel)
- Indice de Shannon

---

## Exercice 3.3 : Calcul Familles W, F, L (Eau, Fertilité, Paysage)

### Objectif Pédagogique
L'utilisateur apprend à calculer les familles W (eau), F (fertilité), L (paysage) en un seul bloc.

### Inputs de l'exercice
- `parcelles` : objet sf avec métriques LiDAR
- `mnt` : SpatRaster MNT (Module 1)
- `cours_eau` : optionnel (sf des cours d'eau OSM)

### Code attendu de l'utilisateur
```r
# Calculer familles W, F, L
famille_WFL <- nemeton::calculate_families_batch(
  parcels = parcelles,
  dem = mnt,
  families = c("W", "F", "L"),
  water_courses = NULL  # Optionnel
)

# Visualiser résultats
print(famille_WFL)
summary(famille_WFL$family_index_W)
summary(famille_WFL$family_index_F)
summary(famille_WFL$family_index_L)

# Cartes multiples
par(mfrow = c(1, 3))
plot(famille_WFL["family_index_W"], main = "Eau (W)")
plot(famille_WFL["family_index_F"], main = "Fertilité (F)")
plot(famille_WFL["family_index_L"], main = "Paysage (L)")
par(mfrow = c(1, 1))
```

### Outputs attendus
- `famille_WFL` : objet sf avec indicateurs familles W, F, L
- Colonnes ajoutées :
  - Famille W : `ind_W_water_regulation`, `family_index_W`
  - Famille F : `ind_F_soil_fertility`, `family_index_F`
  - Famille L : `ind_L_landscape_value`, `family_index_L`

### Validation gradethis
```r
grade_result(
  pass_if(~ all(c("family_index_W", "family_index_F", "family_index_L") %in% names(.result)),
          "Parfait ! Familles W, F, L calculées."),
  pass_if(~ all(.result$family_index_W >= 0 & .result$family_index_W <= 1),
          "Famille W normalisée."),
  pass_if(~ all(.result$family_index_F >= 0 & .result$family_index_F <= 1),
          "Famille F normalisée."),
  pass_if(~ all(.result$family_index_L >= 0 & .result$family_index_L <= 1),
          "Famille L normalisée.")
)
```

### Concepts enseignés
- Régulation hydrique (pente, proximité eau)
- Fertilité sols (topographie, végétation)
- Valeur paysagère (diversité, accessibilité)
- Calcul batch multi-familles

---

## Exercice 3.4 : Calcul Familles A, T, R (Air, Temporel, Risques)

### Objectif Pédagogique
L'utilisateur apprend à calculer les familles A (air), T (temporel), R (risques).

### Inputs de l'exercice
- `parcelles` : objet sf avec métriques LiDAR
- `population_data` : optionnel (raster densité population INSEE)
- `historical_data` : optionnel (séries temporelles Sentinel-2)

### Code attendu de l'utilisateur
```r
# Calculer familles A, T, R
famille_ATR <- nemeton::calculate_families_batch(
  parcels = parcelles,
  families = c("A", "T", "R"),
  population_raster = NULL,  # Optionnel
  temporal_data = NULL        # Optionnel
)

# Visualiser résultats
print(famille_ATR)
summary(famille_ATR$family_index_A)
summary(famille_ATR$family_index_T)
summary(famille_ATR$family_index_R)

# Cartes multiples
par(mfrow = c(1, 3))
plot(famille_ATR["family_index_A"], main = "Air (A)")
plot(famille_ATR["family_index_T"], main = "Temporel (T)")
plot(famille_ATR["family_index_R"], main = "Risques (R)")
par(mfrow = c(1, 1))
```

### Outputs attendus
- `famille_ATR` : objet sf avec indicateurs familles A, T, R
- Colonnes ajoutées :
  - Famille A : `ind_A_air_quality`, `family_index_A`
  - Famille T : `ind_T_temporal_stability`, `family_index_T` (si données temporelles)
  - Famille R : `ind_R_risk_regulation`, `family_index_R`

### Validation gradethis
```r
grade_result(
  pass_if(~ all(c("family_index_A", "family_index_R") %in% names(.result)),
          "Excellent ! Familles A, R calculées."),
  pass_if(~ all(.result$family_index_A >= 0 & .result$family_index_A <= 1),
          "Famille A normalisée."),
  pass_if(~ all(.result$family_index_R >= 0 & .result$family_index_R <= 1),
          "Famille R normalisée.")
)
```

### Concepts enseignés
- Qualité air (surface foliaire, proximité zones habitées)
- Analyse temporelle (stabilité NDVI si données disponibles)
- Régulation risques (érosion, incendie)

---

## Exercice 3.5 : Calcul Familles S, P, E, N (Social, Production, Énergie, Naturalité)

### Objectif Pédagogique
L'utilisateur apprend à calculer les 4 dernières familles : S (social), P (production), E (énergie), N (naturalité).

### Inputs de l'exercice
- `parcelles` : objet sf avec métriques LiDAR
- `roads` : optionnel (sf des routes OSM)
- `population_data` : optionnel (raster densité population)

### Code attendu de l'utilisateur
```r
# Calculer familles S, P, E, N
famille_SPEN <- nemeton::calculate_families_batch(
  parcels = parcelles,
  families = c("S", "P", "E", "N"),
  roads = NULL,              # Optionnel
  population_raster = NULL   # Optionnel
)

# Visualiser résultats
print(famille_SPEN)
summary(famille_SPEN$family_index_S)
summary(famille_SPEN$family_index_P)
summary(famille_SPEN$family_index_E)
summary(famille_SPEN$family_index_N)

# Cartes multiples
par(mfrow = c(2, 2))
plot(famille_SPEN["family_index_S"], main = "Social (S)")
plot(famille_SPEN["family_index_P"], main = "Production (P)")
plot(famille_SPEN["family_index_E"], main = "Énergie (E)")
plot(famille_SPEN["family_index_N"], main = "Naturalité (N)")
par(mfrow = c(1, 1))
```

### Outputs attendus
- `famille_SPEN` : objet sf avec indicateurs familles S, P, E, N
- Colonnes ajoutées :
  - Famille S : `ind_S_social_value`, `family_index_S`
  - Famille P : `ind_P_wood_production`, `family_index_P`
  - Famille E : `ind_E_energy_potential`, `family_index_E`
  - Famille N : `ind_N_naturalness`, `family_index_N`

### Validation gradethis
```r
grade_result(
  pass_if(~ all(c("family_index_S", "family_index_P", "family_index_E", "family_index_N") %in% names(.result)),
          "Bravo ! Les 4 dernières familles calculées."),
  pass_if(~ all(.result$family_index_P >= 0 & .result$family_index_P <= 1),
          "Famille P (production) normalisée."),
  pass_if(~ all(.result$family_index_N >= 0 & .result$family_index_N <= 1),
          "Famille N (naturalité) normalisée.")
)
```

### Concepts enseignés
- Fonction sociale (accessibilité, récréation)
- Production bois (volume, croissance)
- Potentiel énergétique (biomasse, accessibilité)
- Naturalité (maturité, structure)

---

## Exercice 3.6 : Agrégation et Normalisation Globale

### Objectif Pédagogique
L'utilisateur apprend à agréger toutes les familles en un dataset complet et à vérifier la normalisation.

### Inputs de l'exercice
- `parcelles` : objet sf initial
- `famille_C`, `famille_B`, ..., `famille_SPEN` : objets sf des exercices précédents

### Code attendu de l'utilisateur
```r
# Fusionner toutes les familles
parcelles_complet <- parcelles |>
  left_join(st_drop_geometry(famille_C), by = "id_parcel") |>
  left_join(st_drop_geometry(famille_B), by = "id_parcel") |>
  left_join(st_drop_geometry(famille_WFL), by = "id_parcel") |>
  left_join(st_drop_geometry(famille_ATR), by = "id_parcel") |>
  left_join(st_drop_geometry(famille_SPEN), by = "id_parcel")

# Vérifier présence des 12 familles
family_cols <- paste0("family_index_", c("C", "B", "W", "F", "L", "A", "T", "R", "S", "P", "E", "N"))
all(family_cols %in% names(parcelles_complet))

# Statistiques globales
summary(parcelles_complet[, family_cols])

# Sauvegarder
saveRDS(parcelles_complet, "data/parcelles_12_familles.rds")
```

### Outputs attendus
- `parcelles_complet` : objet sf avec TOUTES les 12 familles
- Colonnes : `id_parcel`, `geometry`, `family_index_C`, ..., `family_index_N`
- Tous les indices normalisés (0-1)
- Pas de valeurs NA (sauf famille T si pas de données temporelles)

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "sf"),
          "Parfait ! Dataset complet des 12 familles."),
  pass_if(~ all(paste0("family_index_", c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N")) %in% names(.result)),
          "Les 12 familles sont présentes (T optionnel)."),
  pass_if(~ nrow(.result) == nrow(parcelles),
          "Nombre de parcelles conservé."),
  pass_if(~ all(sapply(.result[, paste0("family_index_", c("C", "B", "W"))], function(x) all(x >= 0 & x <= 1, na.rm = TRUE))),
          "Indices normalisés correctement.")
)
```

### Concepts enseignés
- Jointure spatiale (left_join)
- Agrégation multi-sources
- Validation dataset complet
- Sauvegarde RDS pour réutilisation

---

## Exercice 3.7 : Dashboard Interactif de Résultats

### Objectif Pédagogique
L'utilisateur apprend à créer un dashboard interactif pour explorer les résultats des 12 familles.

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles (exercice 3.6)

### Code attendu de l'utilisateur
```r
# Sélectionner une parcelle pour visualisation détaillée
parcelle_id <- parcelles_complet$id_parcel[1]
parcelle_selected <- parcelles_complet |> filter(id_parcel == parcelle_id)

# Extraire indices pour radar chart
indices_12 <- parcelle_selected |>
  st_drop_geometry() |>
  select(starts_with("family_index_")) |>
  as.numeric()

names(indices_12) <- c("C", "B", "W", "F", "L", "A", "T", "R", "S", "P", "E", "N")

# Créer radar chart 12-axes
library(fmsb)
radar_data <- rbind(
  max = rep(1, 12),
  min = rep(0, 12),
  indices_12
)
radarchart(radar_data, axistype = 1, pcol = "forestgreen", pfcol = scales::alpha("forestgreen", 0.3),
           plwd = 2, cglcol = "grey", cglty = 1, cglwd = 0.8,
           axislabcol = "black", vlcex = 0.8,
           title = paste("Profil 12-axes - Parcelle", parcelle_id))
```

### Outputs attendus
- Radar chart 12-axes pour une parcelle
- Tous les indices visibles simultanément
- Comparaison visuelle facile entre familles

### Validation gradethis
```r
grade_result(
  pass_if(~ length(.result) == 12,
          "Excellent ! 12 indices extraits pour le radar chart."),
  pass_if(~ all(.result >= 0 & .result <= 1),
          "Tous les indices normalisés."),
  pass_if(~ !any(is.na(.result[names(.result) != "T"])),
          "Pas de valeurs NA (sauf T si optionnel).")
)
```

### Concepts enseignés
- Radar chart (diagramme araignée)
- Visualisation multi-critères
- Profil parcellaire
- Package fmsb

---

## Quiz de Validation Module 3

### Question 1 : Normalisation
**Question** : Pourquoi normaliser les indices de famille entre 0 et 1 ?

- A) Pour accélérer les calculs
- B) Pour permettre la comparaison entre familles hétérogènes ✓
- C) Pour réduire la taille des fichiers
- D) Pour éviter les erreurs de calcul

**Feedback** : La normalisation min-max permet de comparer des indicateurs de nature différente (biomasse, diversité, etc.).

### Question 2 : Famille C
**Question** : Que mesure principalement la famille C (Régulation climatique) ?

- A) La biodiversité forestière
- B) Le stockage de carbone et la productivité ✓
- C) La qualité de l'air
- D) La valeur paysagère

**Feedback** : La famille C évalue le service de régulation climatique via le stockage carbone et la productivité.

### Question 3 : Radar Chart
**Question** : À quoi sert un radar chart 12-axes dans ce contexte ?

- A) À calculer les indicateurs
- B) À visualiser simultanément les 12 familles pour une parcelle ✓
- C) À normaliser les données
- D) À exporter les résultats

**Feedback** : Le radar chart permet une visualisation synthétique du profil multi-critères d'une parcelle.

---

## Résumé des Fonctions Utilisées

### Fonctions nemeton principales
- `calculate_family_C(parcels, include_ndvi)`
- `calculate_family_B(parcels, protected_areas, calculate_connectivity)`
- `calculate_families_batch(parcels, families, dem, ...)`
- `normalize_indicators(data, method = "minmax")`

### Fonctions R standard
- `dplyr::left_join()`, `filter()`, `select()`
- `sf::st_drop_geometry()`, `st_buffer()`
- `summary()`, `print()`

### Visualisation
- `plot.sf()` (cartes thématiques)
- `fmsb::radarchart()` (radar chart 12-axes)
- `par(mfrow = c(2, 2))` (grilles de plots)

---

## Tests Attendus (Post-Exercices)

### Test 1 : Famille C calculée
```r
testthat::test_that("Famille C calculée correctement", {
  parcelles <- load_demo_cadastre()
  famille_C <- nemeton::calculate_family_C(parcelles)

  expect_s3_class(famille_C, "sf")
  expect_true("family_index_C" %in% names(famille_C))
  expect_true(all(famille_C$family_index_C >= 0 & famille_C$family_index_C <= 1))
})
```

### Test 2 : Toutes les familles présentes
```r
testthat::test_that("12 familles calculées et agrégées", {
  parcelles_complet <- readRDS("data/parcelles_12_familles.rds")

  family_cols <- paste0("family_index_", c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N"))

  expect_s3_class(parcelles_complet, "sf")
  expect_true(all(family_cols %in% names(parcelles_complet)))
})
```

### Test 3 : Normalisation correcte
```r
testthat::test_that("Indices normalisés entre 0 et 1", {
  parcelles_complet <- readRDS("data/parcelles_12_familles.rds")
  family_cols <- paste0("family_index_", c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N"))

  for (col in family_cols) {
    expect_true(all(parcelles_complet[[col]] >= 0 & parcelles_complet[[col]] <= 1, na.rm = TRUE))
  }
})
```

---

## Dépendances

### Packages R requis
- **nemeton** (package principal avec fonctions calculate_family_*)
- **sf** >= 1.0-0 (vecteurs)
- **dplyr** >= 1.1.0 (manipulation données)
- **fmsb** (radar charts)
- **learnr** >= 0.11.0, **gradethis** >= 0.2.0

### Données
- `parcelles` avec métriques LiDAR (Module 2)
- `mnt` (Module 1)
- Données optionnelles : routes OSM, cours d'eau, population INSEE

### Modules précédents
- **Module 1** : Fournit `parcelles` (sf) et `mnt` (SpatRaster)
- **Module 2** : Enrichit `parcelles` avec métriques dendrométriques LiDAR

### Modules suivants
- **Module 4** (Visualisation) utilisera `parcelles_complet` (12 familles)
- **Module 5** (Export) exportera `parcelles_complet`
