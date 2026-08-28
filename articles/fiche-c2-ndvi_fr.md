# Fiche indicateur C2 - NDVI - Vitalite

> **Document de référence** — Néméton (package cœur), 2026-08-27. Fiche
> jumelle de celle de C1 : les deux composent à parts égales le score
> `famille_carbone`.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `C2` |
| Nom long / colonne | `indicateur_c2_ndvi` |
| Famille | **C — Carbone & Vitalité** (avec `C1` biomasse) |
| Grandeur mesurée | Vitalité photosynthétique de la végétation |
| Unité brute | **sans unité, \[0, 1\]** |
| Sens | Haut = favorable |
| Normalisation | `score = min(100, max(0, valeur × 100))` — `R/normalization.R:588` |
| Fonction | [`indicateur_c2_ndvi()`](https://pobsteta.github.io/nemeton/reference/indicateur_c2_ndvi.md) — `R/indicators-families.R` |

C2 est l’indicateur le plus simple des 41 : une **moyenne zonale** d’un
raster déjà calculé. Toute la difficulté est en amont, dans la façon
dont ce raster est produit — et c’est là que le NDP se joue.

## 2. Deux modes, pas une cascade

Contrairement à C1, C2 n’a pas de repli en cascade. Il a **deux modes
exclusifs**, choisis par la présence de l’argument `fapar` :

| Mode | Déclencheur | Grandeur rendue |
|----|----|----|
| **FAPAR** | argument `fapar` fourni (`SpatRaster`) | fraction du rayonnement photosynthétiquement actif absorbé |
| **NDVI** | défaut | `(NIR − Rouge) / (NIR + Rouge)` moyenné sur l’unité |

    C2 = moyenne zonale du raster sur l'unité      safe_extract(fun = "mean")

Les deux grandeurs vivent sur la même échelle `[0, 1]` et « haut = plus
de vitalité », si bien que la normalisation aval est **identique**.
C’est la raison assumée du choix de conception : le mode FAPAR remplace
la valeur sans rien changer en aval.

> **FAPAR est physiquement fondé, NDVI ne l’est pas.** Le NDVI est un
> rapport de réflectances ; FAPAR est une **variable biophysique
> restituée** (produit Theia `s2_biophysical`, chaîne SL2P). Sur couvert
> dense, le NDVI sature vers 0,85–0,9 quand FAPAR continue de
> discriminer. À NDP 0, brancher FAPAR est le gain le plus rentable sur
> C2 — sans changer une ligne d’aval.

## 3. Le calcul par niveau NDP

| NDP | Source du raster | Résolution | Ce qui change |
|----|----|----|----|
| **0** | Sentinel-2 (MUSCATE L2A, `s2_l2a_muscate`) → NDVI | 10 m | le cas de base |
| **0 augmenté** | Theia `s2_biophysical` → **FAPAR** | 10 m | grandeur physique, ne sature pas comme le NDVI |
| **1** | Sentinel-2 (idem) | 10 m | **inchangé** — le LiDAR HD n’apporte rien au signal spectral |
| **2** | ortho drone multispectrale | cm | vraie rupture : le NDVI cesse de mélanger houppier, trouée et sol |
| **3** | \+ notation de vigueur terrain | placette | validation, pas remplacement : C2 reste le raster |
| **4** | \+ scan spectral détaillé | arbre | signal par houppier |

**Le point à retenir** : entre NDP 0 et NDP 1, **C2 ne bouge pas**. Le
NDP mesure la qualité des données d’entrée (ADR-011), et pour C2 cette
qualité est gouvernée par le capteur spectral, que le LiDAR HD
n’améliore pas. Une hausse du NDP due au LiDAR augmente le **poids
Fibonacci** de la famille C sans que C2 ait gagné en précision — c’est
correct au sens de l’ADR (la famille dans son ensemble est mieux connue
via C1), mais il ne faut pas lire une amélioration de C2 là où il n’y en
a pas.

**Exemples chiffrés** :

| Situation                                | Valeur brute | Score normalisé |
|------------------------------------------|--------------|-----------------|
| Sol nu / coupe rase                      | 0,15         | 15,0            |
| Peuplement stressé, houppiers clairsemés | 0,45         | 45,0            |
| Futaie feuillue en pleine saison         | 0,72         | 72,0            |
| Couvert dense, NDVI saturé               | 0,88         | 88,0            |

La normalisation étant `× 100`, **la valeur brute et le score sont le
même nombre à un facteur 100 près**. C2 est le seul indicateur où lire
le score revient exactement à lire la mesure.

## 4. Trois pièges

1.  **`trend = TRUE` ne calcule rien.** L’argument existe, est
    documenté, et produit un
    `warning("NDVI trend calculation not yet implemented in v0.2.0 — returning single-date mean only")`
    puis **retourne la moyenne mono-date**. Ce n’est pas une erreur :
    c’est un no-op annoncé. Pour une vraie tendance temporelle, passer
    par
    [`extract_pixel_trend()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_trend.md)
    /
    [`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md),
    pas par C2.
2.  **C2 lève une erreur, il ne rend pas `NA`.** Si la couche `ndvi` est
    absente de l’objet `layers`, la fonction
    [`stop()`](https://rdrr.io/r/base/stop.html). C’est le seul
    comportement de ce type parmi les indicateurs de la famille C — C1,
    lui, rend `NA` avec un avertissement. Un pipeline qui calcule les 41
    indicateurs doit donc protéger l’appel de C2, ou garantir la couche.
3.  **La date compte, et n’est pas dans la valeur.** Un NDVI de juillet
    et un NDVI de mars sur le même peuplement diffèrent de 0,2 à 0,4. La
    colonne ne porte aucune trace de la date d’acquisition : c’est le
    raster fourni qui la détermine, en amont. Comparer deux projets
    suppose de comparer deux fenêtres phénologiques équivalentes.

## 5. Aval

    indicateur_c2_ndvi()  ->  colonne `indicateur_c2_ndvi` ([0, 1])
          |
          +- normalize_indicator()     -> C2_norm = min(100, valeur x 100)
          +- create_family_index("C")  -> famille_carbone = moyenne(C1_norm, C2_norm)
          +- compute_general_index()   -> axe C du radar, pondere Fibonacci

Poids par défaut : **50 / 50 avec C1**. Surchargeable par
`create_family_index(..., weights = list(C = c(C1 = 0.7, C2 = 0.3)))`.

> Conséquence directe : sur un projet où C1 sature (chemin CHM, cf. sa
> fiche), `famille_carbone` devient pour moitié un simple NDVI remis à
> l’échelle. Lire les deux colonnes brutes avant de conclure sur la
> famille.

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBDMiA6IGRldXggbW9kZXMgZXhjbHVzaWZzIOKAlCBGQVBBUiBzaSBsZSByYXN0ZXIgYmlvcGh5c2lxdWUgZXN0IGZvdXJuaSwgTkRWSSBzaW5vbiDigJQgcHJvZHVpc2VudCBsYSBtZW1lIG1veWVubmUgem9uYWxlIHN1ciBbMCwxXSwgbm9ybWFsaXNlZSBwYXIgdW4gc2ltcGxlIGZhY3RldXIgMTAwIHB1aXMgbW95ZW5uZWUgYXZlYyBDMSBkYW5zIGxhIGZhbWlsbGUgQ2FyYm9uZSA7IGwmIzM5O2Fic2VuY2UgZGUgY291Y2hlIE5EVkkgbmUgcmVuZCBwYXMgTkEgbWFpcyBsZXZlIHVuZSBlcnJldXIuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgTU9ERVMKRVhDTFVTSUZTPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+VGhlaWEKczJfYmlvcGh5c2ljYWw8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+RkFQQVIKcmVzdGl0dcOpIChjaGHDrm5lIFNMMlApLCAxMCBtPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjkwIiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEwOSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlNlbnRpbmVsLTIKTVVTQ0FURSBMMkE8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmJhbmRlcwpyb3VnZSBldCBwcm9jaGUgaW5mcmFyb3VnZTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxNDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIxNjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Db3VjaGUKbmR2aSBhYnNlbnRlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxODEiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5hdWN1bgpyYXN0ZXIgZGFucyBsYXllcnM8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Nb2RlCkZBUEFSPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YXJndW1lbnQKZmFwYXIgZm91cm5pPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQp6b25hbGUgZHUgcmFzdGVyPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTI2IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Nb2RlCk5EVkkgKGTDqWZhdXQpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPihOSVIKLSBSb3VnZSkvKE5JUiArIFJvdWdlKTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zYWZlX2V4dHJhY3QoZnVuCj0g4oCcbWVhbuKAnSk8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIyMTgiIHdpZHRoPSIyNjIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjMwMCIgeT0iMjM3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+c3RvcCgpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjUzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmVycmV1ciwKcGFzIGRlIE5BIHJlbmR1PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfYzJfbmR2aTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnZhbGV1cgpkYW5zIFswLCAxXTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bWluKDEwMCwKbWF4KDAsIHYgw5cgMTAwKSk8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcQ+KAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9jYXJib25lPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgQzEgZXQgQzI8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNDIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI2MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PHBhdGggZD0iTTI2MCA1NSBIMjcxIFY2MyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxMTEgSDI3MSBWMTU1IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDE2NyBIMjcxIFYyMzkgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI5NCIgeDI9IjMwNiIgeTI9IjEyMCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjExMCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+b3U8L3RleHQ+PGxpbmUgeDE9IjMwNiIgeTE9IjE4NiIgeDI9IjMwNiIgeTI9IjIxMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjIwMiIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+b3U8L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE1NSIgeDI9IjU2NiIgeTI9IjE1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMjM5IiB4Mj0iNTY2IiB5Mj0iMjM5IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjIzOSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTQyIiB4Mj0iNjk5IiB5Mj0iMTU2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjIyIiB4Mj0iNjk5IiB5Mj0iMjM2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzEwIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5MZXMKZGV1eCBtb2RlcyB2aXZlbnQgc3VyIGxhIG3Dqm1lIMOpY2hlbGxlIDogYnJhbmNoZXIgRkFQQVIgbmUgY2hhbmdlIGF1Y3VuZQpsaWduZSBk4oCZYXZhbC48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+dHJlbmQKPSBUUlVFIG5lIGNhbGN1bGUgcmllbiDigJQgYXZlcnRpc3NlbWVudCwgcHVpcyBtb3llbm5lIG1vbm8tZGF0ZS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM0MiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGUKc2NvcmUgdmF1dCBsYSBtZXN1cmUgw5cgMTAwIDogQzIgZXN0IGxlIHNldWwgaW5kaWNhdGV1ciBvw7kgbGlyZSBsZSBzY29yZSwKY+KAmWVzdCBsaXJlIGxhIG1lc3VyZS48L3RleHQ+PC9zdmc+)

Deux modes exclusifs pour une seule sortie. Le choix se fait sur la
présence de l’argument `fapar`, pas sur le NDP — et le NDP, lui, ne
bouge pas entre 0 et 1 puisque le LiDAR n’améliore rien du signal
spectral.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction C2 | `R/indicators-families.R` |
| Normalisation | `R/normalization.R:588` (branche `indicateur_c2_ndvi`) |
| Sources déclarées | `inst/datasources/FR.json` — `s2_l2a_muscate`, `s2_biophysical` |
| Tendance temporelle (le vrai outil) | [`extract_pixel_trend()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_trend.md), [`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md) |
| Fiche jumelle | [`vignette("fiche-c1-biomasse_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.md) |
