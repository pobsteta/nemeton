# Installation des Tutoriels nemeton

Ce guide détaille l'installation complète pour exécuter les 6 tutoriels interactifs nemeton.

## Prérequis Système

- **R** >= 4.1.0 (recommandé : 4.3.0+)
- **RStudio** >= 2023.06 (recommandé pour les tutoriels learnr)
- **Connexion internet** (pour télécharger les données IGN)
- **Espace disque** : ~2 Go pour les données de tutoriel

## Installation Rapide

```r
# 1. Packages de base
install.packages(c("sf", "terra", "ggplot2", "dplyr", "tidyr"))

# 2. Packages tutoriels
install.packages(c("learnr", "gradethis", "rappdirs"))

# 3. Package nemeton
install.packages("remotes")
remotes::install_github("pobsteta/nemeton")

# 4. Vérifier l'installation
learnr::available_tutorials("nemeton")
```

## Installation Détaillée

### 1. Packages de Base (Obligatoires)

```r
install.packages(c(
  "sf",        # Données spatiales vectorielles

"terra",     # Données spatiales raster
  "ggplot2",   # Visualisation
  "dplyr",     # Manipulation de données
  "tidyr",     # Transformation de données
  "purrr"      # Programmation fonctionnelle
))
```

### 2. Packages Tutoriels (Obligatoires)

```r
install.packages(c(
  "learnr",    # Tutoriels interactifs
  "gradethis", # Validation des exercices
  "rappdirs"   # Gestion du cache
))
```

### 3. Packages Acquisition IGN (Tutorial 01)

```r
install.packages("happign")  # API IGN
```

### 4. Packages LiDAR (Tutorial 02)

```r
install.packages(c(
  "lidR",          # Traitement LiDAR
  "future"         # Traitement parallèle
))
```

### 5. Packages Analyse (Tutorial 06)

```r
install.packages(c(
  "leaflet",    # Cartes interactives
  "corrplot",   # Matrices de corrélation
  "patchwork",  # Assemblage de graphiques
  "fmsb"        # Diagrammes radar
))
```

### 6. Package nemeton

```r
# Depuis GitHub (dernière version)
remotes::install_github("pobsteta/nemeton")

# Avec toutes les dépendances suggérées
remotes::install_github("pobsteta/nemeton", dependencies = TRUE)
```

## Vérification de l'Installation

```r
# Script de vérification complet
check_nemeton_tutorials <- function() {

  # Packages requis par tutoriel
  packages <- list(
    base = c("sf", "terra", "ggplot2", "dplyr"),
    tutorials = c("learnr", "gradethis", "rappdirs"),
    ign = c("happign"),
    lidar = c("lidR"),
    analysis = c("leaflet", "corrplot", "patchwork", "fmsb")
  )

  all_ok <- TRUE

  for (group in names(packages)) {
    cat(sprintf("\n=== %s ===\n", toupper(group)))
    for (pkg in packages[[group]]) {
      if (requireNamespace(pkg, quietly = TRUE)) {
        version <- as.character(packageVersion(pkg))
        cat(sprintf("  [OK] %s (%s)\n", pkg, version))
      } else {
        cat(sprintf("  [X]  %s - MANQUANT\n", pkg))
        all_ok <- FALSE
      }
    }
  }

  # Vérifier nemeton
  cat("\n=== NEMETON ===\n")
  if (requireNamespace("nemeton", quietly = TRUE)) {
    version <- as.character(packageVersion("nemeton"))
    cat(sprintf("  [OK] nemeton (%s)\n", version))

    # Lister les tutoriels
    tutorials <- learnr::available_tutorials("nemeton")
    cat(sprintf("\n  Tutoriels disponibles: %d\n", nrow(tutorials)))
    for (i in seq_len(nrow(tutorials))) {
      cat(sprintf("    - %s\n", tutorials$name[i]))
    }
  } else {
    cat("  [X]  nemeton - MANQUANT\n")
    all_ok <- FALSE
  }

  # Résumé
  cat("\n" , rep("=", 40), "\n", sep = "")
  if (all_ok) {
    cat("INSTALLATION COMPLETE !\n")
    cat("Lancez: learnr::run_tutorial('01-acquisition', 'nemeton')\n")
  } else {
    cat("INSTALLATION INCOMPLETE\n")
    cat("Installez les packages manquants avant de continuer.\n")
  }

  return(invisible(all_ok))
}

# Exécuter la vérification
check_nemeton_tutorials()
```

## Lancer les Tutoriels

### Méthode 1 : Depuis RStudio

```r
# Lister les tutoriels
learnr::available_tutorials("nemeton")

# Lancer un tutoriel
learnr::run_tutorial("01-acquisition", package = "nemeton")
```

### Méthode 2 : Ordre recommandé

```r
# Suivre l'ordre pour une progression logique
learnr::run_tutorial("01-acquisition", package = "nemeton")  # 45 min
learnr::run_tutorial("02-lidar", package = "nemeton")        # 60 min
learnr::run_tutorial("03-terrain", package = "nemeton")      # 40 min
learnr::run_tutorial("04-ecological", package = "nemeton")   # 40 min
learnr::run_tutorial("05-complete", package = "nemeton")     # 40 min
learnr::run_tutorial("06-analysis", package = "nemeton")     # 50 min
```

## Structure du Cache

Les données téléchargées sont stockées dans :

| OS | Chemin |
|----|--------|
| Linux | `~/.local/share/nemeton/tutorial_data/` |
| macOS | `~/Library/Application Support/nemeton/tutorial_data/` |
| Windows | `%LOCALAPPDATA%/nemeton/nemeton/tutorial_data/` |

```r
# Afficher le chemin du cache
rappdirs::user_data_dir("nemeton")

# Nettoyer le cache
cache_dir <- rappdirs::user_data_dir("nemeton")
unlink(file.path(cache_dir, "tutorial_data"), recursive = TRUE)
```

## Dépannage

### Erreur : "Tutorial not found"

```r
# Réinstaller nemeton
remotes::install_github("pobsteta/nemeton", force = TRUE)
```

### Erreur : "Cannot download data"

- Vérifiez votre connexion internet
- Les APIs IGN peuvent être temporairement indisponibles
- Réessayez plus tard ou utilisez les données de démonstration

### Erreur : "Out of memory" (LiDAR)

```r
# Augmenter la limite mémoire
options(future.globals.maxSize = +Inf)

# Ou réduire la zone d'étude dans le tutoriel
```

### Erreur : "Exercise timeout"

Les exercices LiDAR ont un timeout de 10 minutes. Relancez l'exercice si nécessaire (les données sont en cache après le premier téléchargement).

### Erreur : "Package 'xxx' not available"

```r
# Mettre à jour les dépôts CRAN
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Réessayer l'installation
install.packages("xxx")
```

## Ressources

- **Documentation** : https://pobsteta.github.io/nemeton/
- **GitHub** : https://github.com/pobsteta/nemeton
- **Issues** : https://github.com/pobsteta/nemeton/issues
- **API IGN** : https://geoservices.ign.fr/
- **lidR** : https://r-lidar.github.io/lidRbook/
