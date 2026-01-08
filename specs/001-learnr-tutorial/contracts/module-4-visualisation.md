# Module 4 API Contract: Visualisation et Analyse Multi-Critères

**Module**: Tutorial Module 4 - Visualisation et Analyse Multi-Critères
**Feature**: 001-learnr-tutorial
**User Story**: US4 (P2)

## Overview

Ce module enseigne la visualisation et l'interprétation des résultats multi-familles pour identifier des stratégies de gestion équilibrées :
- Cartes thématiques par famille
- Radar charts 12-axes pour profils parcellaires
- Analyse de corrélations inter-familles
- Identification hotspots multi-critères
- Trade-off analysis (synergies/compromis)
- Cas d'usage : priorisation conservation vs production

**Pédagogie** : Exploration visuelle interactive avec exercices d'interprétation et décision.

---

## Exercice 4.1 : Cartes Thématiques par Famille

### Objectif Pédagogique
L'utilisateur apprend à créer des cartes thématiques pour visualiser la distribution spatiale de chaque famille.

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles (Module 3)

### Code attendu de l'utilisateur
```r
# Créer grille 3x4 de cartes thématiques
library(ggplot2)
library(patchwork)

families <- c("C", "B", "W", "F", "L", "A", "T", "R", "S", "P", "E", "N")
family_names <- c("Climat", "Biodiv", "Eau", "Fertilité", "Paysage",
                  "Air", "Temporel", "Risques", "Social", "Production",
                  "Énergie", "Naturalité")

# Créer liste de ggplots
plots <- lapply(seq_along(families), function(i) {
  col <- paste0("family_index_", families[i])

  ggplot(parcelles_complet) +
    geom_sf(aes(fill = .data[[col]]), color = NA) +
    scale_fill_viridis_c(option = "viridis", limits = c(0, 1)) +
    labs(title = paste(families[i], "-", family_names[i]),
         fill = "Indice") +
    theme_minimal() +
    theme(legend.position = "bottom")
})

# Arranger en grille
wrap_plots(plots, ncol = 4)
```

### Outputs attendus
- Grille 3x4 de cartes thématiques (une par famille)
- Échelle commune 0-1 pour toutes les cartes
- Palette couleur cohérente (viridis)
- Titres explicites par famille

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "list") && length(.result) == 12,
          "Excellent ! 12 cartes thématiques créées."),
  fail_if(~ !inherits(.result, "list"),
          "Le résultat doit être une liste de ggplots."),
  pass_if(~ all(sapply(.result, function(p) inherits(p, "gg"))),
          "Tous les éléments sont des objets ggplot.")
)
```

### Concepts enseignés
- Visualisation spatiale multi-critères
- Package ggplot2 + geom_sf
- Palette viridis (colorblind-friendly)
- Package patchwork (composition plots)

---

## Exercice 4.2 : Radar Charts pour Profils Parcellaires

### Objectif Pédagogique
L'utilisateur apprend à générer des radar charts 12-axes pour comparer les profils de plusieurs parcelles.

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles

### Code attendu de l'utilisateur
```r
# Sélectionner 3 parcelles contrastées
# (ex: haute production, haute naturalité, équilibrée)
selected_ids <- c(
  parcelles_complet$id_parcel[which.max(parcelles_complet$family_index_P)],  # Max production
  parcelles_complet$id_parcel[which.max(parcelles_complet$family_index_N)],  # Max naturalité
  parcelles_complet$id_parcel[which.min(abs(rowMeans(st_drop_geometry(parcelles_complet[, paste0("family_index_", c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N"))]), na.rm = TRUE) - 0.5))]  # Équilibrée
)

parcelles_selected <- parcelles_complet |> filter(id_parcel %in% selected_ids)

# Extraire indices pour radar chart
indices_matrix <- parcelles_selected |>
  st_drop_geometry() |>
  select(starts_with("family_index_")) |>
  as.matrix()

colnames(indices_matrix) <- c("C", "B", "W", "F", "L", "A", "T", "R", "S", "P", "E", "N")

# Créer radar chart comparatif
library(fmsb)
radar_data <- rbind(
  max = rep(1, 12),
  min = rep(0, 12),
  indices_matrix[1, ],
  indices_matrix[2, ],
  indices_matrix[3, ]
)

radarchart(radar_data, axistype = 1,
           pcol = c("red", "blue", "green"),
           pfcol = scales::alpha(c("red", "blue", "green"), 0.2),
           plwd = 2, cglcol = "grey", cglty = 1, cglwd = 0.8,
           axislabcol = "black", vlcex = 0.8,
           title = "Comparaison 3 profils parcellaires")
legend("topright", legend = c("Max Prod", "Max Naturalité", "Équilibré"),
       col = c("red", "blue", "green"), lwd = 2, bty = "n")
```

### Outputs attendus
- Radar chart avec 3 parcelles superposées
- Couleurs différentes par parcelle
- Légende explicite
- 12 axes bien visibles

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "matrix") && ncol(.result) == 12,
          "Super ! Matrice radar chart créée."),
  pass_if(~ nrow(.result) >= 3,
          "Au moins 3 parcelles pour comparaison."),
  pass_if(~ all(.result[3:nrow(.result), ] >= 0 & .result[3:nrow(.result), ] <= 1, na.rm = TRUE),
          "Indices normalisés correctement.")
)
```

### Concepts enseignés
- Radar chart multi-parcelles
- Profils contrastés (production vs conservation)
- Visualisation comparative
- Package fmsb

---

## Exercice 4.3 : Analyse de Corrélations Inter-Familles

### Objectif Pédagogique
L'utilisateur apprend à identifier les synergies et compromis entre familles via une matrice de corrélations.

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles

### Code attendu de l'utilisateur
```r
# Extraire matrice des indices de famille
family_cols <- paste0("family_index_", c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N"))
indices_df <- parcelles_complet |>
  st_drop_geometry() |>
  select(all_of(family_cols))

# Calculer matrice de corrélations
cor_matrix <- cor(indices_df, use = "complete.obs")
colnames(cor_matrix) <- rownames(cor_matrix) <- c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N")

# Visualiser avec corrplot
library(corrplot)
corrplot(cor_matrix, method = "color", type = "upper",
         addCoef.col = "black", number.cex = 0.7,
         tl.col = "black", tl.srt = 45,
         title = "Corrélations entre familles d'indicateurs",
         mar = c(0, 0, 2, 0))

# Identifier synergies (cor > 0.7) et compromis (cor < -0.5)
synergies <- which(cor_matrix > 0.7 & upper.tri(cor_matrix), arr.ind = TRUE)
compromis <- which(cor_matrix < -0.5 & upper.tri(cor_matrix), arr.ind = TRUE)

print("Synergies détectées:")
print(synergies)
print("Compromis détectés:")
print(compromis)
```

### Outputs attendus
- `cor_matrix` : matrice 11x11 de corrélations (famille T optionnelle)
- Plot corrplot avec coefficients de corrélation
- Liste des synergies (corrélations positives fortes)
- Liste des compromis (corrélations négatives)

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "matrix") && nrow(.result) >= 11,
          "Parfait ! Matrice de corrélations calculée."),
  pass_if(~ all(diag(.result) == 1),
          "Diagonale = 1 (autocorrélations)."),
  pass_if(~ all(.result >= -1 & .result <= 1),
          "Coefficients de corrélation valides (-1 à 1).")
)
```

### Concepts enseignés
- Matrice de corrélations (Pearson)
- Package corrplot
- Synergies vs compromis (trade-offs)
- Interprétation écologique (ex: production vs naturalité)

---

## Exercice 4.4 : Identification Hotspots Multi-Critères

### Objectif Pédagogique
L'utilisateur apprend à identifier les parcelles "hotspots" pour plusieurs familles simultanément.

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles
- `families_of_interest` : vecteur de familles à considérer (ex: c("B", "N") pour biodiversité + naturalité)

### Code attendu de l'utilisateur
```r
# Identifier hotspots biodiversité + naturalité (seuil 75ème percentile)
hotspots <- nemeton::identify_hotspots(
  parcels = parcelles_complet,
  families = c("B", "N"),
  threshold = 75,  # 75ème percentile
  method = "all"   # Toutes les familles doivent dépasser le seuil
)

# Visualiser hotspots
ggplot(parcelles_complet) +
  geom_sf(aes(fill = hotspots$is_hotspot), color = "grey50") +
  scale_fill_manual(values = c("FALSE" = "grey90", "TRUE" = "darkgreen"),
                    labels = c("Non", "Hotspot B+N")) +
  labs(title = "Hotspots Biodiversité + Naturalité (P75)",
       fill = "Statut") +
  theme_minimal()

# Statistiques hotspots
cat("Nombre de hotspots:", sum(hotspots$is_hotspot), "/", nrow(parcelles_complet), "\n")
cat("Pourcentage:", round(100 * sum(hotspots$is_hotspot) / nrow(parcelles_complet), 1), "%\n")
```

### Outputs attendus
- `hotspots` : data.frame avec colonne `is_hotspot` (TRUE/FALSE)
- Carte binaire hotspots vs non-hotspots
- Statistiques (nombre, pourcentage)

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "data.frame") && "is_hotspot" %in% names(.result),
          "Excellent ! Hotspots identifiés."),
  pass_if(~ is.logical(.result$is_hotspot),
          "Colonne is_hotspot est bien logique (TRUE/FALSE)."),
  pass_if(~ sum(.result$is_hotspot) > 0,
          "Au moins un hotspot identifié.")
)
```

### Concepts enseignés
- Hotspot analysis multi-critères
- Percentile thresholding
- Méthodes "all" vs "any" (intersection vs union)
- Priorisation conservation

---

## Exercice 4.5 : Trade-off Analysis (Synergies/Compromis)

### Objectif Pédagogique
L'utilisateur apprend à visualiser les compromis entre deux familles antagonistes (ex: production vs naturalité).

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles

### Code attendu de l'utilisateur
```r
# Trade-off Production (P) vs Naturalité (N)
ggplot(parcelles_complet, aes(x = family_index_P, y = family_index_N)) +
  geom_point(aes(color = family_index_B), size = 3, alpha = 0.7) +
  scale_color_viridis_c(option = "plasma") +
  geom_smooth(method = "lm", se = TRUE, color = "red", linetype = "dashed") +
  labs(title = "Trade-off Production vs Naturalité",
       x = "Indice Production (P)",
       y = "Indice Naturalité (N)",
       color = "Biodiversité (B)") +
  theme_minimal() +
  theme(legend.position = "right")

# Calculer corrélation P-N
cor_PN <- cor(parcelles_complet$family_index_P, parcelles_complet$family_index_N, use = "complete.obs")
cat("Corrélation Production-Naturalité:", round(cor_PN, 2), "\n")

# Identifier parcelles "gagnant-gagnant" (P > 0.6 ET N > 0.6)
win_win <- parcelles_complet |>
  filter(family_index_P > 0.6 & family_index_N > 0.6)

cat("Parcelles 'gagnant-gagnant' (P>0.6, N>0.6):", nrow(win_win), "/", nrow(parcelles_complet), "\n")
```

### Outputs attendus
- Scatterplot P vs N avec régression linéaire
- Points colorés par une 3ème famille (biodiversité)
- Coefficient de corrélation P-N
- Identification parcelles "gagnant-gagnant"

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "gg"),
          "Super ! Trade-off plot créé."),
  pass_if(~ "GeomPoint" %in% sapply(.result$layers, function(l) class(l$geom)[1]),
          "Plot contient des points."),
  pass_if(~ "GeomSmooth" %in% sapply(.result$layers, function(l) class(l$geom)[1]),
          "Régression linéaire ajoutée.")
)
```

### Concepts enseignés
- Trade-off analysis (analyse compromis)
- Scatterplot avec 3ème dimension (couleur)
- Parcelles "gagnant-gagnant" vs "compromis nécessaires"
- Stratégies de gestion équilibrées

---

## Exercice 4.6 : Cas d'Usage - Priorisation Conservation vs Production

### Objectif Pédagogique
L'utilisateur apprend à utiliser les résultats multi-familles pour prendre des décisions de gestion.

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles

### Code attendu de l'utilisateur
```r
# Cas d'usage: Identifier parcelles pour 3 stratégies de gestion
# 1. Conservation prioritaire (B+N élevés, P faible acceptable)
# 2. Production prioritaire (P élevé, autres acceptables)
# 3. Multifonctionnalité (toutes familles équilibrées)

parcelles_complet <- parcelles_complet |>
  mutate(
    strategie = case_when(
      family_index_B > 0.7 & family_index_N > 0.7 ~ "Conservation",
      family_index_P > 0.7 ~ "Production",
      family_index_B > 0.5 & family_index_P > 0.5 & family_index_N > 0.5 ~ "Multifonctionnalité",
      TRUE ~ "Non classé"
    )
  )

# Visualiser stratégies
ggplot(parcelles_complet) +
  geom_sf(aes(fill = strategie), color = "grey50") +
  scale_fill_manual(values = c(
    "Conservation" = "darkgreen",
    "Production" = "orange",
    "Multifonctionnalité" = "purple",
    "Non classé" = "grey80"
  )) +
  labs(title = "Stratégies de gestion recommandées - CIRON",
       fill = "Stratégie") +
  theme_minimal()

# Statistiques stratégies
table(parcelles_complet$strategie)
```

### Outputs attendus
- Nouvelle colonne `strategie` dans `parcelles_complet`
- Carte avec 4 catégories (Conservation, Production, Multifonctionnalité, Non classé)
- Tableau statistique des stratégies

### Validation gradethis
```r
grade_result(
  pass_if(~ "strategie" %in% names(.result),
          "Bravo ! Stratégies de gestion identifiées."),
  pass_if(~ all(.result$strategie %in% c("Conservation", "Production", "Multifonctionnalité", "Non classé")),
          "Catégories de stratégie correctes."),
  pass_if(~ sum(.result$strategie != "Non classé") > 0,
          "Au moins une parcelle classée.")
)
```

### Concepts enseignés
- Décision multi-critères
- Stratégies de gestion forestière
- Multifonctionnalité
- Aide à la décision spatiale

---

## Quiz de Validation Module 4

### Question 1 : Visualisation Multi-Critères
**Question** : Quel est l'avantage principal du radar chart pour visualiser les 12 familles ?

- A) Il prend moins de place que 12 cartes
- B) Il permet de voir simultanément le profil complet d'une parcelle ✓
- C) Il est plus facile à créer qu'une carte
- D) Il calcule automatiquement les indicateurs

**Feedback** : Le radar chart offre une vue synthétique du profil multi-critères en un seul graphique.

### Question 2 : Trade-offs
**Question** : Que signifie un coefficient de corrélation négatif entre Production (P) et Naturalité (N) ?

- A) Les deux familles augmentent ensemble
- B) Il y a une erreur de calcul
- C) Il existe un compromis : augmenter P diminue N ✓
- D) Les deux familles sont indépendantes

**Feedback** : Une corrélation négative indique un trade-off : privilégier la production se fait au détriment de la naturalité.

### Question 3 : Hotspots
**Question** : Quel seuil percentile est recommandé pour identifier des hotspots de conservation ?

- A) 50ème percentile (médiane)
- B) 75ème percentile (quartile supérieur) ✓
- C) 95ème percentile (extrêmes)
- D) 25ème percentile (quartile inférieur)

**Feedback** : Le 75ème percentile (top 25%) est un compromis entre sélectivité et nombre de hotspots.

---

## Résumé des Fonctions Utilisées

### Fonctions nemeton
- `identify_hotspots(parcels, families, threshold, method)`
- `visualize_families(parcels, families, type = "map")`

### Fonctions ggplot2
- `geom_sf()`, `aes()`, `scale_fill_viridis_c()`, `scale_fill_manual()`
- `geom_point()`, `geom_smooth()`
- `labs()`, `theme_minimal()`

### Packages auxiliaires
- **patchwork** : `wrap_plots()` (composer grilles de plots)
- **fmsb** : `radarchart()` (radar charts)
- **corrplot** : `corrplot()` (matrices de corrélations)

### Fonctions R standard
- `cor()`, `table()`, `case_when()`
- `filter()`, `mutate()`, `select()`

---

## Tests Attendus (Post-Exercices)

### Test 1 : Cartes thématiques créées
```r
testthat::test_that("12 cartes thématiques générées", {
  parcelles_complet <- readRDS("data/parcelles_12_familles.rds")

  families <- c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N")
  plots <- lapply(families, function(f) {
    col <- paste0("family_index_", f)
    ggplot(parcelles_complet) + geom_sf(aes(fill = .data[[col]]))
  })

  expect_equal(length(plots), 11)  # T optionnel
  expect_true(all(sapply(plots, function(p) inherits(p, "gg"))))
})
```

### Test 2 : Corrélations calculées
```r
testthat::test_that("Matrice de corrélations correcte", {
  parcelles_complet <- readRDS("data/parcelles_12_familles.rds")
  family_cols <- paste0("family_index_", c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N"))

  cor_matrix <- cor(st_drop_geometry(parcelles_complet[, family_cols]), use = "complete.obs")

  expect_true(is.matrix(cor_matrix))
  expect_equal(nrow(cor_matrix), 11)
  expect_true(all(diag(cor_matrix) == 1))
})
```

### Test 3 : Hotspots identifiés
```r
testthat::test_that("Hotspots biodiversité détectés", {
  parcelles_complet <- readRDS("data/parcelles_12_familles.rds")

  hotspots <- nemeton::identify_hotspots(parcelles_complet, families = c("B", "N"), threshold = 75)

  expect_s3_class(hotspots, "data.frame")
  expect_true("is_hotspot" %in% names(hotspots))
  expect_true(is.logical(hotspots$is_hotspot))
})
```

---

## Dépendances

### Packages R requis
- **nemeton** (identify_hotspots, visualize_families)
- **ggplot2** >= 3.4.0 (cartes thématiques)
- **sf** >= 1.0-0 (geom_sf)
- **patchwork** >= 1.1.0 (composition plots)
- **fmsb** (radar charts)
- **corrplot** (matrices corrélations)
- **scales** (transparence couleurs)
- **learnr** >= 0.11.0, **gradethis** >= 0.2.0

### Données
- `parcelles_complet` avec 12 familles (Module 3)

### Modules précédents
- **Module 3** : Fournit `parcelles_complet` (sf avec 12 familles)

### Modules suivants
- **Module 5** (Export) exportera les visualisations et résultats d'analyse
