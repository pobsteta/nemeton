# Fiche indicateur S2 - Distance au bati

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `S2` |
| Nom long / colonne | `indicateur_s2_bati` |
| Famille | **S — Social & Usages** |
| Grandeur mesurée | **Distance moyenne au bâti**, en mètres |
| Unité brute | **mètres** |
| Sens | Haut = favorable (proche = accessible) |
| Normalisation | `score = min(100, max(0, 100 × (1 − d / 2000)))` — identique à S1 |
| Fonction | [`indicateur_s2_bati()`](https://pobsteta.github.io/nemeton/reference/indicateur_s2_bati.md) — `R/indicators-social.R:155` |

## 2. Le calcul

Même mécanique que S1, sur la couche `buildings` au lieu de `roads` :
rasterisation sur la grille du MNT,
[`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html),
moyenne zonale.

**Exemples chiffrés** : identiques à S1 (même règle de normalisation).

| Distance moyenne | Score    |
|------------------|----------|
| 200 m            | **90,0** |
| 800 m            | **60,0** |
| ≥ 2 000 m        | **0,0**  |

## 3. Le calcul par niveau NDP

| NDP     | Ce qui change                                          |
|---------|--------------------------------------------------------|
| **0**   | BD TOPO bâti + MNT 25 m                                |
| **1**   | grille fine ; bâti agricole et cabanes mieux localisés |
| **2**   | ortho drone                                            |
| **3–4** | —                                                      |

## 4. Deux pièges

1.  **S1 et S2 sont fortement corrélés.** Routes et bâti sont
    co-localisés : les deux indicateurs mesurent, en pratique, le même
    gradient d’anthropisation. Ils comptent pourtant chacun pour un
    tiers de `famille_social` — le gradient y pèse donc deux tiers.
2.  **Même plafond de 2 000 m, mêmes effets de saturation** qu’en S1.

## 5. Aval

    indicateur_s2_bati()  ->  colonne indicateur_s2_bati (metres)
          |
          +- normalize_indicator()     -> 100 x (1 - d / 2000)
          +- create_family_index("S")  -> famille_social

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction S2 | `R/indicators-social.R:155-250` |
| Indicateur jumeau | [`vignette("fiche-s1-routes_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-s1-routes_fr.md) |
