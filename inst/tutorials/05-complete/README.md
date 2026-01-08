# Tutorial 05 : Assemblage — Famille E (E2) + Indice Composite I_nemeton

## Description

Ce tutoriel assemble les **31 indicateurs** calculés dans les tutoriels précédents, calcule **E2** (évitement carbone), normalise les valeurs, et produit l'**indice composite I_nemeton**.

## Indicateur Calculé

| Famille | Code | Indicateur | Formule | Description |
|---------|------|------------|---------|-------------|
| **E** (Énergie) | E2 | Évitement carbone | E1 × 2.5 × η | tCO₂ évitées par substitution bois-énergie |

**Formule E2** : `E2 = E1 × facteur_substitution × rendement_conversion`
- E1 : Potentiel bois-énergie (tep/ha/an) - calculé en T02
- Facteur substitution : 2.5 tCO₂/tep (remplacement fossiles)
- Rendement : 0.82-0.88 selon essence

## Prérequis

- Tutorials 01-04 complétés (données en cache)
- Packages: sf, terra, rappdirs

### Fichiers requis des Tutorials précédents

```
~/nemeton_tutorial_data/
├── parcelles.gpkg              # T01: Base géométrique
├── metriques_lidar.gpkg        # T02: C1, P1, P3, B2, E1, A1
├── indicateurs_terrain.gpkg    # T03: W1-3, R1-3, S1-3, P2, F1
└── indicateurs_ecologiques.gpkg # T04: B1-3, L1-3, C2, T1-2, A2, F2, N1-3
```

## Concepts Clés

### Normalisation Min-Max

Transformation des indicateurs sur l'échelle [0, 1] :

```
x_norm = (x - x_min) / (x_max) - x_min)
```

### Inversion des Indicateurs Négatifs

Indicateurs où une valeur élevée est défavorable :
- R1, R2, R3 (risques)
- F1 (érosion)
- L1 (fragmentation)

### Pondération des 12 Familles

| Famille | Poids | % Relatif |
|---------|-------|-----------|
| B (Biodiversité) | 12 | 13.3% |
| C (Carbone) | 10 | 11.1% |
| R (Risques) | 10 | 11.1% |
| W (Eau) | 8 | 8.9% |
| S (Social) | 8 | 8.9% |
| P (Production) | 8 | 8.9% |
| N (Naturalité) | 8 | 8.9% |
| A (Air) | 6 | 6.7% |
| F (Sol) | 6 | 6.7% |
| L (Paysage) | 5 | 5.6% |
| E (Énergie) | 5 | 5.6% |
| T (Temporel) | 4 | 4.4% |

### Formule Indice Composite

$$I_{nemeton} = \sum_{f=1}^{12} w_f \cdot \bar{I}_f$$

## Données de Sortie

```
~/nemeton_tutorial_data/
└── indicateurs_complets.gpkg
    ├── 31 indicateurs bruts (C1, C2, C3, B1, ...)
    ├── 31 indicateurs normalisés (*_norm)
    ├── 12 moyennes par famille (moy_C, moy_B, ...)
    ├── Indice composite (I_nemeton)
    └── Classification (classe: Faible/Moyen/Bon/Excellent)
```

## Sections

1. Introduction et prérequis
2. Chargement des données
3. Assemblage des indicateurs
4. Normalisation Min-Max
5. Inversion des indicateurs négatifs
6. Indicateur E2 (Évitement carbone)
7. Calcul de l'indice composite
8. Export des résultats
9. Quiz final

## Lancement

```r
learnr::run_tutorial("05-complete", package = "nemeton")
```

## Connexion avec nemeton

Fonctions principales utilisées :
- `indicator_energy_avoidance()` → E2
- `normalize_indicators()` → Normalisation Min-Max
- `create_composite_index()` → Calcul de I_nemeton

## Tutoriel Suivant

→ **Tutorial 06** : Analyse Multi-Critères — 12 Familles + Export
