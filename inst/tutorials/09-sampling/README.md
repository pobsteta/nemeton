# Tutorial 09 : Échantillonnage de Calibration LiDAR HD + TSP

## Description

Ce tutoriel enseigne la conception d'un plan d'échantillonnage optimal de placettes de calibration pour les modèles LiDAR, avec calcul du parcours terrain le plus efficace via le problème du voyageur de commerce (TSP).

**Objectif** : Maximiser la représentativité statistique tout en minimisant le temps de déplacement sur le terrain.

## Durée estimée

**120 minutes (2h)**

## Prérequis

- Tutorial 01 (Acquisition) - zone d'étude et données IGN
- Tutorial 02 (LiDAR) - métriques LiDAR de base
- Tutorial 07 (LiDAR avancé) - CHM et métriques de structure

## Packages requis

```r
# Spatial
install.packages(c("sf", "terra"))

# Échantillonnage
install.packages("spsurvey")           # GRTS sampling
install.packages("BalancedSampling")   # Cube method

# Réseau et TSP
install.packages("sfnetworks")
install.packages("TSP")
install.packages("tidygraph")
install.packages("igraph")

# Visualisation
install.packages(c("ggplot2", "patchwork", "leaflet"))

# Tutoriel
install.packages(c("learnr", "gradethis"))
```

## Structure

| Section | Durée | Contenu |
|---------|-------|---------|
| Bienvenue | 10 min | Objectifs, workflow, formule échantillonnage |
| 1 | 20 min | Chargement des données (zone, CHM, routes) |
| 2 | 25 min | Sampling frame - grille de candidats |
| 3 | 30 min | Stratification et GRTS |
| 4 | 20 min | Réseau routier et TSP |
| 5 | 10 min | Export des résultats |
| 6 | 10 min | Projet QField prêt pour la saisie terrain |
| Synthèse | 5 min | Récapitulatif et checklist terrain |

## Données utilisées

**Cache nemeton (Tutorials 01-07)** :
- `zone_etude.gpkg` : Périmètre de la zone d'étude
- `chm_complet.tif` : CHM pour stratification par hauteur
- Réseau routier IGN BD TOPO

**Générées** :
- Grille de candidats avec contraintes (pente, couvert)
- Strates basées sur la hauteur dominante

## Lancer le tutoriel

```r
learnr::run_tutorial("09-sampling", package = "nemeton")
```

## Produits générés

| Fichier | Description |
|---------|-------------|
| `sampling_frame.gpkg` | Grille des candidats valides |
| `strates.gpkg` | Polygones de stratification |
| `placettes_grts.gpkg` | Placettes sélectionnées (principales + remplacement) |
| `parcours_tsp.gpkg` | Itinéraire optimisé |
| `fiche_terrain.csv` | Fiche de navigation terrain |
| `sampling_report.html` | Rapport de synthèse |
| `echantillon.qgz` | Projet QField (placettes + arbres vide + formulaires) |

## Quiz

5 quiz avec 15 questions au total :

1. **Dimensionnement** (3 questions) - Formule n, CV, erreur admissible
2. **Stratification** (3 questions) - GRTS, allocation, représentativité
3. **Contraintes** (3 questions) - Pente, couvert, accessibilité
4. **TSP** (3 questions) - Graphe, heuristiques, temps de parcours
5. **QField** (3 questions) - Format .qgz, contraintes formulaire, domaine des espèces

## Concepts clés

### Formule de dimensionnement

```
n = t² × CV² / E²
```

Avec :
- `t` : valeur de Student (1.96 pour 95%)
- `CV` : coefficient de variation attendu (%)
- `E` : erreur admissible (%)

### Méthodes d'échantillonnage

| Méthode | Package | Avantage |
|---------|---------|----------|
| GRTS | spsurvey | Équilibre spatial garanti |
| Cube | BalancedSampling | Contraintes d'inclusion |
| Aléatoire stratifié | base R | Simple, reproductible |

## Lien avec les autres tutoriels

- **Tutorial 07** : Fournit le CHM pour stratification
- **Tutorial 08** : Placettes utilisées pour coregistration
- **Tutorial 10** : Labels terrain pour classification

## Ressources

- [spsurvey - GRTS sampling](https://usepa.github.io/spsurvey/)
- [TSP package](https://cran.r-project.org/package=TSP)
- [sfnetworks](https://luukvdmeer.github.io/sfnetworks/)
- [Cochran (1977) - Sampling Techniques](https://www.wiley.com/en-us/Sampling+Techniques%2C+3rd+Edition-p-9780471162407)
