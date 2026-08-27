# Fiche indicateur N1 - Distance aux infrastructures

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `N1` |
| Nom long / colonne | `indicateur_n1_distance` |
| Famille | **N — Naturalité** (avec N2, N3) |
| Grandeur mesurée | Éloignement aux infrastructures humaines |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable (**loin = naturel = bon**) |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_n1_distance()`](https://pobsteta.github.io/nemeton/reference/indicateur_n1_distance.md) — `R/indicators-naturalness.R:30` |

## 2. Le calcul

Depuis le **centroïde** de chaque unité, distance à l’union des routes
et à l’union du bâti, combinées en un score de naturalité croissant avec
l’éloignement.

> **N1 et S1/S2 mesurent la même géométrie et la notent en sens
> contraire.** S1 « distance aux routes » est favorable quand elle est
> **courte** (accessibilité) ; N1 est favorable quand elle est
> **longue** (naturalité). Ce n’est pas une incohérence : ce sont deux
> points de vue légitimes, portés par des familles différentes et des
> profils d’acteurs différents. Mais un radar qui monte simultanément en
> S et en N est, pour cette composante, arithmétiquement impossible.

## 3. Le calcul par niveau NDP

| NDP     | Ce qui change                                             |
|---------|-----------------------------------------------------------|
| **0**   | BD TOPO routes + bâti                                     |
| **1**   | contours plus précis ; pistes forestières mieux recensées |
| **2**   | dessertes relevées au drone                               |
| **3–4** | —                                                         |

## 4. Trois pièges

1.  **Sans couche, `NA` — et c’est un correctif.** Le code antérieur
    reprenait une « distance par défaut » du tutoriel 04, qui produisait
    un N1 d’apparence normale à partir d’une distance inventée. Le
    commentaire est resté : « une distance inventée, qui produit un N1
    d’apparence normale. Sans couche, la distance n’est pas connue. »
2.  **Le calcul part du centroïde, pas de l’unité entière.** Une
    parcelle en lanière dont un bout touche une route et l’autre
    s’enfonce dans le massif est notée sur son milieu. Contrairement à
    S1, qui moyenne un raster de distance sur toute la surface.
3.  **Les pistes forestières comptent comme des routes.** Selon la
    couche fournie, un cloisonnement d’exploitation peut faire chuter N1
    autant qu’une départementale.

## 5. Aval

    indicateur_n1_distance()  ->  colonne N1 (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("N")  -> famille_naturalite = moy(N1, N2, N3)
          +- alimente N3 (poids 0,35)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction N1 | `R/indicators-naturalness.R:30-113` |
| Indicateur de sens inverse | [`vignette("fiche-s1-routes_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-s1-routes_fr.md) |
