# Fiche indicateur S1 - Distance aux routes

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `S1` |
| Nom long / colonne | `indicateur_s1_routes` |
| Famille | **S — Social & Usages** (avec S2, S3) |
| Grandeur mesurée | **Distance moyenne aux routes**, en mètres |
| Unité brute | **mètres** |
| Sens | Haut = favorable (**proche = accessible = bon**) |
| Normalisation | `score = min(100, max(0, 100 × (1 − d / 2000)))` |
| Fonction | [`indicateur_s1_routes()`](https://pobsteta.github.io/nemeton/reference/indicateur_s1_routes.md) — `R/indicators-social.R:55` |

## 2. Le calcul

    raster_routes = rasterisation des routes sur la grille du MNT
    d = moyenne zonale de terra::distance(raster_routes)     metres
    S1 = d
    score = 100 x (1 - d / 2000), ecrete [0, 100]

Le calcul passe par un **raster de distance** sur la grille du MNT, pas
par une distance vectorielle : la résolution du MNT est donc la
granularité de S1.

**Exemples chiffrés** :

| Distance moyenne     | Score    |
|----------------------|----------|
| 50 m (bord de route) | **97,5** |
| 400 m                | **80,0** |
| 1 200 m              | **40,0** |
| ≥ 2 000 m            | **0,0**  |

## 3. Le calcul par niveau NDP

| NDP   | Ce qui change                             |
|-------|-------------------------------------------|
| **0** | BD TOPO + MNT 25 m — distance à 25 m près |
| **1** | grille LiDAR HD : distance métrique       |
| **2** | pistes et cloisonnements relevés au drone |
| **3** | desserte relevée sur le terrain           |
| **4** | —                                         |

## 4. Trois pièges

1.  **Le sens est inversé par rapport au nom.** « Distance aux routes »
    avec « haut = bon » signifie **proche**, pas loin. C’est cohérent
    pour un indicateur d’accessibilité — mais l’exact opposé de **N1**
    (distance aux infrastructures), où l’éloignement est la qualité
    recherchée. Les deux indicateurs mesurent la même distance et la
    notent en sens contraire.
2.  **`NA` sans MNT ou sans routes.** S1 a besoin des deux : le raster
    de distance se construit sur la grille du MNT.
3.  **Le plafond de 2 000 m écrase le domaine forestier profond.**
    Toutes les unités à plus de 2 km d’une route obtiennent 0, qu’elles
    soient à 2,1 km ou à 12 km. En massif de montagne, S1 est souvent
    saturé à 0.

## 5. Aval

    indicateur_s1_routes()  ->  colonne indicateur_s1_routes (metres)
          |
          +- normalize_indicator()     -> 100 x (1 - d / 2000)
          +- create_family_index("S")  -> famille_social = moy(S1, S2, S3)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction S1 | `R/indicators-social.R:55-150` |
| Normalisation | `R/normalization.R`, branche `indicateur_s1_routes` |
| Indicateur de sens inverse | [`vignette("fiche-n1-distance_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-n1-distance_fr.md) |
