# Quickstart: Tutoriels nemeton

## Prérequis

### Installation R et RStudio

1. Installer R >= 4.1.0: https://cran.r-project.org/
2. Installer RStudio: https://posit.co/download/rstudio-desktop/

### Installation des packages

```r
# Packages de base (obligatoires)
install.packages(c("sf", "terra", "ggplot2", "dplyr"))

# Packages tutoriels
install.packages(c("learnr", "gradethis", "rappdirs"))

# Packages acquisition IGN
install.packages("happign")
remotes::install_github("Jean-Roc/lidarHD")

# Packages LiDAR (pour Tutorial 02)
install.packages("lidR")

# Packages LiDAR avancé (pour Tutorial 07)
install.packages("lasR", repos = "https://r-lidar.r-universe.dev")
install.packages("lidaRtRee")
install.packages(c("future", "future.apply"))

# Packages visualisation (pour Tutorial 06)
install.packages(c("leaflet", "corrplot", "patchwork"))
```

### Installation nemeton

```r
# Depuis GitHub
remotes::install_github("pobsteta/nemeton")
```

---

## Lancer un tutoriel

### Méthode 1: Depuis RStudio

```r
# Lister les tutoriels disponibles
learnr::available_tutorials("nemeton")

# Lancer un tutoriel spécifique
learnr::run_tutorial("01-acquisition", package = "nemeton")
```

### Méthode 2: Depuis la console

```r
# Directement
nemeton::run_tutorial("01-acquisition")
```

---

## Ordre recommandé

| # | Tutoriel | Durée | Description |
|---|----------|-------|-------------|
| 1 | `01-acquisition` | 45 min | Acquisition des données géographiques |
| 2 | `02-lidar` | 60 min | Traitement LiDAR et métriques forestières |
| 3 | `03-terrain` | 40 min | Indicateurs terrain (W, R, S) |
| 4 | `04-ecological` | 40 min | Indicateurs écologiques (B, L, T, N) |
| 5 | `05-complete` | 40 min | Calcul complet et normalisation |
| 6 | `06-analysis` | 50 min | Analyse multi-critères et export |
| 7 | `07-lidar-advanced` | 90 min | LiDAR avancé (lasR, ITD, ABA, BABA) |

**Durée totale estimée**: 6-7 heures (5-6h sans Tutorial 07)

---

## Structure du cache

Les données sont sauvegardées dans un répertoire persistant :

- **Linux**: `~/.local/share/nemeton/tutorial_data/`
- **macOS**: `~/Library/Application Support/nemeton/tutorial_data/`
- **Windows**: `%LOCALAPPDATA%/nemeton/nemeton/tutorial_data/`

Vous pouvez vérifier l'emplacement :

```r
if (requireNamespace("rappdirs", quietly = TRUE)) {
  cat(rappdirs::user_data_dir("nemeton"))
}
```

### Nettoyer le cache

```r
# Supprimer toutes les données téléchargées
cache_dir <- rappdirs::user_data_dir("nemeton")
unlink(file.path(cache_dir, "tutorial_data"), recursive = TRUE)
```

---

## Vérifier l'installation

```r
# Script de vérification
check_tutorial_ready <- function() {
  # Packages de base (Tutorials 01-06)
  packages_base <- c("sf", "terra", "learnr", "gradethis", "happign", "rappdirs", "lidR")
  # Packages avancés (Tutorial 07)
  packages_t07 <- c("lasR", "lidaRtRee", "future", "future.apply")

  missing_base <- packages_base[!sapply(packages_base, requireNamespace, quietly = TRUE)]
  missing_t07 <- packages_t07[!sapply(packages_t07, requireNamespace, quietly = TRUE)]

  if (length(missing_base) > 0) {
    cat("Packages manquants (Tutorials 01-06):\n")
    cat(paste(" -", missing_base, collapse = "\n"), "\n")
    return(FALSE)
  }

  cat("✅ Packages de base installés (Tutorials 01-06)\n")

  if (length(missing_t07) > 0) {
    cat("⚠️  Packages Tutorial 07 manquants (optionnel):\n")
    cat(paste(" -", missing_t07, collapse = "\n"), "\n")
  } else {
    cat("✅ Packages Tutorial 07 installés\n")
  }

  cat("\nLancez: learnr::run_tutorial('01-acquisition', 'nemeton')\n")
  return(TRUE)
}

check_tutorial_ready()
```

---

## Dépannage

### "Tutorial not found"

```r
# Vérifier que nemeton est installé
packageVersion("nemeton")

# Réinstaller si nécessaire
remotes::install_github("pobsteta/nemeton", force = TRUE)
```

### "Cannot download data"

1. Vérifiez votre connexion internet
2. Les APIs IGN peuvent être temporairement indisponibles
3. Le tutoriel basculera sur des données de démonstration si disponibles

### "Out of memory" (LiDAR)

```r
# Réduire la zone d'étude ou traiter par tuiles
# Augmenter la mémoire disponible
options(java.parameters = "-Xmx4g")
```

### "Exercise timeout"

Les exercices LiDAR ont un timeout de 10 minutes. Si le téléchargement est plus long, relancez l'exercice (les données seront en cache).

---

## Ressources

- Documentation nemeton: https://pobsteta.github.io/nemeton/
- Issues GitHub: https://github.com/pobsteta/nemeton/issues
- API IGN (happign): https://happign.fr/
- lidR documentation: https://r-lidar.github.io/lidRbook/
- lasR documentation: https://r-lidar.github.io/lasR/
- lidaRtRee documentation: https://lidar.pages-forge.inrae.fr/lidaRtRee/
