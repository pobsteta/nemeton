# Spécification: Tutorial 08 - Coregistration LiDAR/Terrain

**Version**: 1.0.0
**Date**: 2025-01-18
**Statut**: Draft
**Source**: https://lidar.pages-forge.inrae.fr/lidaRtRee/articles/coregistration.html

## Résumé

Tutorial interactif pour apprendre à recaler (coregistrer) les positions des placettes d'inventaire forestier sur les données LiDAR aéroporté (ALS). Ce tutoriel reproduit exactement le workflow de l'article lidaRtRee "Coregistration" en français, avec optimisations lasR et parallélisation.

## Objectifs pédagogiques

À la fin de ce tutoriel, l'apprenant sera capable de :

1. Comprendre le problème du recalage placettes/LiDAR
2. Générer un MNH (CHM) optimisé avec lasR
3. Créer des masques de placettes à partir des données terrain
4. Calculer la corrélation entre MNH et positions des arbres
5. Appliquer le recalage à un lot de placettes en parallèle
6. Analyser la qualité du recalage (statistiques, visualisation)

## Prérequis

- Tutorial 01 (Acquisition) - pattern cache
- Tutorial 07 (LiDAR avancé) - lasR, lidaRtRee, parallélisation

## Données

### Données terrain (lidaRtRee)

Source : Package lidaRtRee (`system.file("extdata", package = "lidaRtRee")`)

- **44 placettes** d'inventaire (forêt du Lac des Rouges Truites, Jura, France)
- **15 placettes** disponibles pour le tutoriel
- **Rayon placette** : 14.10 m (circulaire)
- **Contenu placettes** :
  - Coordonnées théoriques (Xtheo, Ytheo)
  - Coordonnées GPS (XGPS, YGPS)
  - Précision GPS
  - Distance entre position échantillonnée et enregistrée

- **Inventaire arbres** : 5 arbres par placette
  - Diamètre
  - Distance inclinée
  - Azimut
  - Pente
  - Coordonnées calculées

### Données LiDAR (lidaRtRee)

Source : Package lidaRtRee (objets LAS inclus)

- Acquisition 2016, capteur RIEGL LMS Q680i
- Format : objets LAS normalisés
- Emprise : buffers autour des placettes

## Structure du tutoriel

### Section 1 : Introduction (10 min)

#### 1.1 Contexte et problématique

```markdown
Le positionnement précis des placettes d'inventaire forestier est crucial pour :
- Calibrer les modèles ABA (Area-Based Approach)
- Valider les estimations LiDAR
- Assurer la reproductibilité des mesures

**Problème** : Les coordonnées GPS sous couvert forestier peuvent avoir une erreur de plusieurs mètres.

**Solution** : Utiliser la corrélation entre le MNH LiDAR et les positions des arbres mesurés pour recaler les placettes.
```

#### 1.2 Principe du recalage

- Corrélation croisée MNH / masque placette
- Recherche de la translation optimale (dx, dy)
- Référence : Monnet & Mermin (2014)

#### Quiz 1 : Introduction (3 questions)

```r
quiz(
  question("Pourquoi les coordonnées GPS sous forêt sont-elles imprécises ?",
    answer("Le couvert forestier atténue le signal GPS", correct = TRUE),
    answer("Le GPS ne fonctionne pas en forêt"),
    answer("Les arbres déplacent les satellites"),
    answer("La pente fausse les mesures")
  ),
  question("Quelle donnée LiDAR est utilisée pour le recalage ?",
    answer("Le nuage de points brut"),
    answer("Le MNT (Modèle Numérique de Terrain)"),
    answer("Le MNH (Modèle Numérique de Hauteur)", correct = TRUE),
    answer("L'intensité du signal")
  ),
  question("Que représente la corrélation dans ce contexte ?",
    answer("La similarité entre MNH et positions des arbres", correct = TRUE),
    answer("La distance entre deux placettes"),
    answer("La précision du GPS"),
    answer("La hauteur moyenne des arbres")
  )
)
```

---

### Section 2 : Chargement des données (15 min)

#### 2.1 Paramètres de configuration

```r
# Paramètres du recalage
params <- list(
  h_max = 50,        # Hauteur végétation maximale (m)
  radius = 14.105,   # Rayon placette (m)
  res = 0.5,         # Résolution raster (m)
  buffer = 5,        # Buffer de recherche (m)
  step = 0.5         # Pas de recherche (m)
)
```

#### 2.2 Chargement données terrain

```r
# Charger les données de placettes
data_dir <- system.file("extdata", package = "lidaRtRee")
plots <- read.csv(file.path(data_dir, "coregistration", "plots.csv"))
trees <- read.csv(file.path(data_dir, "coregistration", "trees.csv"))

# Afficher structure
str(plots)
str(trees)
```

#### 2.3 Chargement données LiDAR

```r
# Charger les nuages de points (objets LAS du package)
las_files <- list.files(file.path(data_dir, "coregistration", "las"),
                        pattern = "\\.las$", full.names = TRUE)
```

#### Exercice 2.1 : Explorer les données

```r
# Exercice : Combien de placettes et d'arbres ?
n_plots <- ___
n_trees <- ___
n_trees_per_plot <- ___
```

---

### Section 3 : Génération du MNH avec lasR (20 min)

#### 3.1 Pipeline lasR optimisé

```r
library(lasR)

# Pipeline CHM avec lasR (optimisé C++)
pipeline_chm <- function(las_file, res = 0.5, h_max = 50) {
  reader_las() +
    rasterize(res = res, operators = "max") +
    # Post-traitement dans R
    callback(function(r) {
      # Seuillage hauteurs extrêmes
      r[r > h_max] <- h_max
      r[r < 0] <- 0
      # Remplir NA avec 0
      r[is.na(r)] <- 0
      r
    })
}
```
#### 3.2 Alternative lidR classique

```r
library(lidR)

# Génération CHM avec lidR
create_chm_lidr <- function(las, res = 0.5, h_max = 50) {
  # CHM brut
  chm <- rasterize_canopy(las, res = res, algorithm = p2r())

  # Post-traitement
  chm[chm > h_max] <- h_max
  chm[chm < 0] <- 0
  chm[is.na(chm)] <- 0

  # Filtre médian 3x3
  chm_filtered <- terra::focal(chm, w = matrix(1, 3, 3), fun = median, na.rm = TRUE)

  return(chm_filtered)
}
```

#### 3.3 Comparaison lasR vs lidR

```r
# Benchmark sur une placette
system.time({ chm_lasr <- exec(pipeline_chm(las_file), ...) })
system.time({ chm_lidr <- create_chm_lidr(las, ...) })
```

#### Quiz 2 : Génération MNH (3 questions)

```r
quiz(
  question("Pourquoi filtrer les hauteurs > 50m ?",
    answer("Pour éliminer les valeurs aberrantes (bruit)", correct = TRUE),
    answer("Pour réduire la taille du fichier"),
    answer("Les arbres ne dépassent jamais 50m"),
    answer("C'est une convention internationale")
  ),
  question("Quel est l'avantage de lasR sur lidR pour le CHM ?",
    answer("Plus de fonctionnalités"),
    answer("Traitement C++ plus rapide", correct = TRUE),
    answer("Meilleure qualité"),
    answer("Compatible avec plus de formats")
  ),
  question("Pourquoi appliquer un filtre médian 3x3 ?",
    answer("Pour lisser le bruit tout en préservant les contours", correct = TRUE),
    answer("Pour augmenter la résolution"),
    answer("Pour compresser les données"),
    answer("Pour convertir en entiers")
  )
)
```

---

### Section 4 : Création du masque placette (15 min)

#### 4.1 Extraction des arbres d'une placette

```r
# Extraire les arbres d'une placette
extract_plot_trees <- function(trees, plot_id) {
  plot_trees <- trees[trees$idp == plot_id, ]

  # Filtrer arbres avec diamètre mesuré
  plot_trees <- plot_trees[!is.na(plot_trees$diameter), ]

  return(plot_trees)
}
```

#### 4.2 Génération du masque circulaire

```r
# Créer masque raster de la placette
create_plot_mask <- function(plot_trees, chm, radius = 14.105) {
  # Créer raster vide aligné sur CHM
  mask <- terra::rast(chm)
  terra::values(mask) <- 0

  # Pour chaque arbre, marquer les pixels
  for (i in seq_len(nrow(plot_trees))) {
    x <- plot_trees$x[i]
    y <- plot_trees$y[i]
    d <- plot_trees$diameter[i]

    # Pondération par le diamètre
    cell <- terra::cellFromXY(mask, cbind(x, y))
    if (!is.na(cell)) {
      mask[cell] <- d
    }
  }

  return(mask)
}
```

#### 4.3 Visualisation

```r
# Superposer CHM et positions arbres
plot(chm, main = "CHM et arbres inventoriés")
points(plot_trees$x, plot_trees$y, pch = 19, cex = plot_trees$diameter/50)
```

#### Exercice 4.1 : Créer un masque

```r
# Exercice : Créer le masque pour la placette 1
plot_trees_1 <- extract_plot_trees(trees, plot_id = ___)
mask_1 <- create_plot_mask(plot_trees_1, chm, radius = ___)

# Visualiser
plot(___)
```

---

### Section 5 : Calcul de corrélation (20 min)

#### 5.1 Fonction de coregistration lidaRtRee

```r
library(lidaRtRee)

# Coregistration d'une placette
result <- coregistration(
  chm = chm,
  mask = mask,
  buffer = 5,    # Rayon de recherche (m)
  step = 0.5     # Pas de recherche (m)
)
```

#### 5.2 Interprétation des résultats

```r
# Résultats de la coregistration
str(result)

# dx1, dy1 : translation optimale (corrélation max)
# cor1 : valeur de corrélation au maximum
# dx2, dy2 : second maximum local
# cor2 : corrélation au second maximum
# ratio : cor1/cor2 (qualité du recalage)
```

#### 5.3 Visualisation de la corrélation

```r
# Carte de corrélation
plot(result$correlation_raster, main = "Surface de corrélation")
points(result$dx1, result$dy1, pch = 4, col = "red", cex = 2)
```

#### Quiz 3 : Corrélation (3 questions)

```r
quiz(
  question("Que représente dx1, dy1 ?",
    answer("La translation pour atteindre la corrélation maximale", correct = TRUE),
    answer("Les coordonnées GPS corrigées"),
    answer("L'erreur du GPS"),
    answer("La position du plus grand arbre")
  ),
  question("Un ratio cor1/cor2 élevé indique :",
    answer("Un recalage fiable avec un maximum bien défini", correct = TRUE),
    answer("Une mauvaise corrélation"),
    answer("Plusieurs positions possibles"),
    answer("Des données de mauvaise qualité")
  ),
  question("Pourquoi utiliser un buffer de 5m ?",
    answer("Pour limiter la zone de recherche à l'erreur GPS probable", correct = TRUE),
    answer("C'est la taille standard des placettes"),
    answer("Pour accélérer le calcul"),
    answer("Pour éviter les effets de bord")
  )
)
```

---

### Section 6 : Traitement par lot parallélisé (25 min)

#### 6.1 Configuration parallèle

```r
library(future)
library(future.apply)

# Activer parallélisation
plan(multisession, workers = parallel::detectCores() - 1)
```

#### 6.2 Pipeline complet parallélisé

```r
# Fonction de traitement d'une placette
process_plot <- function(plot_id, plots, trees, las_dir, params) {

  # 1. Charger données placette
  plot_info <- plots[plots$idp == plot_id, ]
  plot_trees <- trees[trees$idp == plot_id, ]

  # 2. Charger et traiter LAS
  las_file <- file.path(las_dir, paste0("plot_", plot_id, ".las"))
  las <- readLAS(las_file)

  # 3. Générer CHM
  chm <- create_chm_lidr(las, res = params$res, h_max = params$h_max)


  # 4. Créer masque
  mask <- create_plot_mask(plot_trees, chm, radius = params$radius)

  # 5. Coregistration
  result <- coregistration(chm, mask, buffer = params$buffer, step = params$step)

  # 6. Retourner résultats
  data.frame(
    idp = plot_id,
    x_ini = plot_info$XGPS,
    y_ini = plot_info$YGPS,
    dx = result$dx1,
    dy = result$dy1,
    x_cor = plot_info$XGPS + result$dx1,
    y_cor = plot_info$YGPS + result$dy1,
    cor1 = result$cor1,
    cor2 = result$cor2,
    ratio = result$cor1 / result$cor2
  )
}
```

#### 6.3 Exécution parallèle

```r
# Liste des placettes à traiter
plot_ids <- unique(plots$idp)

# Traitement parallèle avec barre de progression
results <- future_lapply(plot_ids, function(id) {
  tryCatch(
    process_plot(id, plots, trees, las_dir, params),
    error = function(e) {
      warning(paste("Erreur placette", id, ":", e$message))
      NULL
    }
  )
}, future.seed = TRUE)

# Consolider résultats
results_df <- do.call(rbind, Filter(Negate(is.null), results))
```

#### 6.4 Cache incrémental

```r
# Sauvegarder résultats intermédiaires
cache_file <- file.path(data_dir, "coregistration_results.rds")

if (file.exists(cache_file)) {
  results_df <- readRDS(cache_file)
  cat("Résultats chargés depuis le cache\n")
} else {
  # ... traitement ...
  saveRDS(results_df, cache_file)
  cat("Résultats sauvegardés dans le cache\n")
}
```

#### Exercice 6.1 : Traitement parallèle

```r
# Exercice : Traiter les 5 premières placettes en parallèle
plot_ids_subset <- plot_ids[1:___]

results_subset <- future_lapply(___, function(id) {
  process_plot(id, plots, trees, las_dir, params)
})

# Combien de placettes traitées avec succès ?
n_success <- sum(!sapply(results_subset, is.null))
```

---

### Section 7 : Analyse des résultats (15 min)

#### 7.1 Statistiques de recalage

```r
# Statistiques descriptives
summary(results_df[, c("dx", "dy", "cor1", "ratio")])

# Décalage moyen
mean_dx <- mean(results_df$dx, na.rm = TRUE)
mean_dy <- mean(results_df$dy, na.rm = TRUE)
cat("Décalage moyen: dx =", round(mean_dx, 2), "m, dy =", round(mean_dy, 2), "m\n")

# Distance de correction moyenne
results_df$dist_cor <- sqrt(results_df$dx^2 + results_df$dy^2)
cat("Distance correction moyenne:", round(mean(results_df$dist_cor), 2), "m\n")
cat("Écart-type:", round(sd(results_df$dist_cor), 2), "m\n")
```

#### 7.2 Tests statistiques

```r
# Test de significativité du décalage
t_test_x <- t.test(results_df$dx, mu = 0)
t_test_y <- t.test(results_df$dy, mu = 0)

cat("Test dx: p-value =", round(t_test_x$p.value, 3), "\n")
cat("Test dy: p-value =", round(t_test_y$p.value, 3), "\n")
```

#### 7.3 Visualisation des corrections

```r
library(ggplot2)

# Graphique des vecteurs de correction
ggplot(results_df, aes(x = dx, y = dy)) +
  geom_point(aes(color = cor1), size = 3) +
  geom_segment(aes(xend = 0, yend = 0), arrow = arrow(length = unit(0.2, "cm"))) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_vline(xintercept = 0, linetype = "dashed") +
  scale_color_viridis_c(name = "Corrélation") +
  labs(title = "Vecteurs de correction par placette",
       x = "dx (m)", y = "dy (m)") +
  coord_fixed() +
  theme_minimal()
```

#### 7.4 Export des résultats

```r
# Export CSV
write.csv(results_df, file.path(data_dir, "placettes_coregistrees.csv"), row.names = FALSE)

# Export GeoPackage
library(sf)
results_sf <- st_as_sf(results_df, coords = c("x_cor", "y_cor"), crs = 2154)
st_write(results_sf, file.path(data_dir, "placettes_coregistrees.gpkg"), delete_dsn = TRUE)
```

#### Quiz 4 : Analyse (3 questions)

```r
quiz(
  question("Une distance de correction moyenne de 2.1 m est-elle normale ?",
    answer("Oui, c'est cohérent avec la précision GPS sous couvert", correct = TRUE),
    answer("Non, c'est beaucoup trop élevé"),
    answer("Non, c'est trop faible"),
    answer("Impossible à dire sans plus d'informations")
  ),
  question("Un p-value de 0.03 pour dx signifie :",
    answer("Le décalage en X est statistiquement significatif", correct = TRUE),
    answer("Le recalage a échoué"),
    answer("La corrélation est faible"),
    answer("Il n'y a pas de biais systématique")
  ),
  question("Pourquoi exporter en GeoPackage ?",
    answer("Pour visualiser et utiliser les résultats dans un SIG", correct = TRUE),
    answer("Pour réduire la taille du fichier"),
    answer("C'est obligatoire pour le recalage"),
    answer("Pour compatibilité avec Excel")
  )
)
```

---

### Section 8 : Synthèse (10 min)

#### 8.1 Workflow complet

```
┌─────────────────────────────────────────────────────────────┐
│              WORKFLOW COREGISTRATION                        │
└─────────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────┐
  │ 1. DONNÉES D'ENTRÉE                                     │
  │   - Coordonnées GPS placettes (imprécises)              │
  │   - Inventaire arbres (diamètre, azimut, distance)      │
  │   - Nuages LiDAR normalisés                             │
  └─────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────┐
  │ 2. GÉNÉRATION MNH                                       │
  │   - lasR ou lidR : rasterize_canopy()                   │
  │   - Seuillage 0-50m, filtre médian 3x3                  │
  │   - Résolution 0.5m                                     │
  └─────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────┐
  │ 3. MASQUE PLACETTE                                      │
  │   - Positions arbres calculées (polaire → cartésien)    │
  │   - Pondération par diamètre                            │
  │   - Raster aligné sur MNH                               │
  └─────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────┐
  │ 4. CORRÉLATION                                          │
  │   - coregistration() : recherche translation optimale   │
  │   - Buffer 5m, pas 0.5m                                 │
  │   - Sortie : dx, dy, corrélation, ratio                 │
  └─────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────┐
  │ 5. VALIDATION                                           │
  │   - Statistiques (moyenne, écart-type)                  │
  │   - Tests de significativité                            │
  │   - Visualisation vecteurs de correction                │
  └─────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────┐
  │ 6. EXPORT                                               │
  │   - placettes_coregistrees.csv                          │
  │   - placettes_coregistrees.gpkg                         │
  └─────────────────────────────────────────────────────────┘
```

#### 8.2 Produits générés

| Produit | Description | Usage |
|---------|-------------|-------|
| `coregistration_results.rds` | Cache résultats | Reprise traitement |
| `placettes_coregistrees.csv` | Coordonnées corrigées | Tableau |
| `placettes_coregistrees.gpkg` | Placettes géoréférencées | SIG/QGIS |
| `correlation_plots.pdf` | Visualisations | Rapport |

#### 8.3 Indicateurs nemeton concernés

| Indicateur | Lien avec coregistration |
|------------|--------------------------|
| P1, C1 | Calibration ABA précise (surface terrière, biomasse) |
| B2 | Structure forestière (diversité strates) |
| E1, E2 | Estimation volume bois-énergie |

#### 8.4 Bonnes pratiques

1. **Toujours vérifier** le ratio cor1/cor2 (> 1.5 recommandé)
2. **Exclure** les placettes avec faible corrélation (< 0.5)
3. **Visualiser** les vecteurs de correction (détecter outliers)
4. **Documenter** les paramètres utilisés
5. **Conserver** les coordonnées originales (traçabilité)

#### 8.5 Ressources

- [Article lidaRtRee Coregistration](https://lidar.pages-forge.inrae.fr/lidaRtRee/articles/coregistration.html)
- [Monnet & Mermin (2014)](https://doi.org/10.3390/rs6087628) - Cross-correlation of diameter
- [lasR documentation](https://r-lidar.github.io/lasR/)
- [lidR book](https://r-lidar.github.io/lidRbook/)

---

## Durée estimée

| Section | Durée |
|---------|-------|
| 1. Introduction | 10 min |
| 2. Chargement données | 15 min |
| 3. Génération MNH | 20 min |
| 4. Masque placette | 15 min |
| 5. Corrélation | 20 min |
| 6. Traitement parallèle | 25 min |
| 7. Analyse résultats | 15 min |
| 8. Synthèse | 10 min |
| **Total** | **~130 min (2h10)** |

## Dépendances packages

```r
# Obligatoires
library(lidR)
library(lidaRtRee)
library(terra)
library(sf)

# Optimisation (recommandés)
library(lasR)
library(future)
library(future.apply)

# Visualisation
library(ggplot2)
library(learnr)
library(gradethis)
```

## Critères d'acceptance

- [ ] Toutes les sections de l'article original sont couvertes
- [ ] Code traduit et commenté en français
- [ ] Optimisation lasR pour génération CHM
- [ ] Parallélisation avec future_lapply
- [ ] 4 quiz (12 questions total)
- [ ] Synthèse avec workflow et tableau produits
- [ ] Exercices avec validation gradethis
- [ ] Cache incrémental pour résultats
- [ ] Export CSV et GeoPackage
