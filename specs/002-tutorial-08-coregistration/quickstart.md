# Quickstart: Tutorial 08 - Coregistration

## Source

Article original : https://lidar.pages-forge.inrae.fr/lidaRtRee/articles/coregistration.html

## Objectif

Traduire et adapter l'article lidaRtRee "Coregistration" en tutoriel interactif français avec :
- Optimisation lasR pour génération CHM
- Parallélisation avec future/future.apply
- Quiz et exercices gradethis
- Synthèse finale

## Prérequis packages

```r
# Tutoriel 08 nécessite
install.packages(c("lidR", "terra", "sf", "ggplot2"))
install.packages("lidaRtRee")
install.packages("lasR", repos = "https://r-lidar.r-universe.dev")
install.packages(c("future", "future.apply"))
install.packages(c("learnr", "gradethis"))
```

## Données

Les données sont incluses dans le package lidaRtRee :

```r
data_dir <- system.file("extdata", package = "lidaRtRee")
list.files(file.path(data_dir, "coregistration"))
```

- 15 placettes d'inventaire (Jura, France)
- Nuages LiDAR normalisés (buffers autour placettes)

## Structure tutoriel

| Section | Durée | Contenu |
|---------|-------|---------|
| 1 | 10 min | Introduction, contexte |
| 2 | 15 min | Chargement données |
| 3 | 20 min | Génération MNH (lasR + lidR) |
| 4 | 15 min | Masque placette |
| 5 | 20 min | Calcul corrélation |
| 6 | 25 min | Traitement parallèle |
| 7 | 15 min | Analyse résultats |
| 8 | 10 min | Synthèse |

**Total : ~130 min (2h10)**

## Lancer le tutoriel

```r
learnr::run_tutorial("08-coregistration", package = "nemeton")
```

## Points clés

1. **Problème** : GPS imprécis sous couvert forestier
2. **Solution** : Corrélation MNH LiDAR / positions arbres terrain
3. **Méthode** : coregistration() de lidaRtRee
4. **Optimisation** : lasR pour CHM, future pour parallélisation
5. **Sortie** : Coordonnées corrigées (CSV, GeoPackage)
