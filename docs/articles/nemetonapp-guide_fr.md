# Guide de l'Application nemetonApp

## Introduction

**nemetonApp** est l’interface graphique interactive du package
`nemeton`. Elle permet d’analyser des territoires forestiers sans écrire
de code R, directement depuis un navigateur web.

## Lancement de l’application

``` r
library(nemeton)
run_app()
```

L’application s’ouvre dans votre navigateur par défaut.

## Fonctionnalités principales

### 1. Recherche de parcelles

- **Recherche par commune** : Tapez le nom d’une commune française pour
  afficher ses parcelles cadastrales
- **Sélection interactive** : Cliquez sur les parcelles sur la carte
  pour les sélectionner
- **Import GeoPackage** : Importez vos propres fichiers .gpkg

### 2. Gestion de projets

- **Création** : Donnez un nom et une description à votre projet
- **Sauvegarde** : Les projets sont automatiquement sauvegardés
  localement
- **Reprise** : Retrouvez vos projets précédents au prochain lancement

### 3. Calcul des indicateurs

Une fois les parcelles sélectionnées :

1.  Cliquez sur **“Calculer les indicateurs”**
2.  L’application télécharge automatiquement les données nécessaires
    (IGN BD TOPO, Corine Land Cover, etc.)
3.  Les 29 indicateurs des 12 familles sont calculés
4.  Une barre de progression indique l’avancement

### 4. Visualisation des résultats

#### Onglet Synthèse

- **Score global** : Note sur 100 représentant la performance
  écosystémique moyenne
- **Radar 12 axes** : Visualisation des scores par famille d’indicateurs
- **Tableau récapitulatif** : Scores moyens, min, max par famille
- **Analyse IA** : Génération automatique d’une synthèse par
  intelligence artificielle (nécessite une clé API)

#### Onglets Familles (12)

Chaque famille d’indicateurs dispose d’un onglet dédié avec :

- Description de la famille et de ses indicateurs
- Carte interactive des valeurs par parcelle
- Histogramme de distribution
- Statistiques descriptives

### 5. Export des résultats

#### Rapport PDF

Génère un rapport complet incluant :

- Informations du projet
- Score global et radar
- Tableau des scores par famille
- Commentaires de synthèse (si renseignés)

Le rapport utilise Quarto si disponible, sinon un PDF simplifié est
généré.

#### GeoPackage

Export des résultats au format GeoPackage (.gpkg) pour utilisation dans
un SIG (QGIS, ArcGIS).

## Configuration

### Langue

L’application est disponible en français et anglais. Utilisez le
sélecteur de langue dans la barre de navigation.

### Analyse IA

Pour utiliser l’analyse IA, configurez une clé API :

``` r
# Anthropic (Claude)
Sys.setenv(ANTHROPIC_API_KEY = "votre-clé")

# OpenAI
Sys.setenv(OPENAI_API_KEY = "votre-clé")

# Ollama (local, pas de clé requise)
```

### Thème

L’application utilise un thème sombre adapté à la cartographie
forestière avec des couleurs accessibles (palette viridis).

## Raccourcis clavier

| Action                            | Raccourci      |
|-----------------------------------|----------------|
| Sélectionner toutes les parcelles | `Ctrl + A`     |
| Désélectionner                    | `Ctrl + D`     |
| Calculer                          | `Ctrl + Enter` |

## Résolution des problèmes

### L’application ne démarre pas

``` r
# Vérifier les dépendances
install.packages(c("shiny", "bslib", "leaflet", "sf"))
```

### Les données ne se téléchargent pas

Vérifiez votre connexion internet. Les données proviennent de services
WFS de l’IGN et de l’INPN.

### Le PDF ne se génère pas

``` r
# Installer Quarto pour des rapports de qualité
# https://quarto.org/docs/get-started/

# Ou utiliser le fallback sans Quarto
generate_report_pdf(..., use_quarto = FALSE)
```

## Voir aussi

- [`?run_app`](https://pobsteta.github.io/nemeton/reference/run_app.md) -
  Documentation de la fonction de lancement
- [`?generate_report_pdf`](https://pobsteta.github.io/nemeton/reference/generate_report_pdf.md) -
  Documentation de l’export PDF
- [Site pkgdown](https://pobsteta.github.io/nemeton/) - Documentation
  complète
