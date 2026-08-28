# Fiche indicateur A1 - Couverture arboree

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `A1` |
| Nom long / colonne | `indicateur_a1_couverture` |
| Famille | **A — Air & Microclimat** (avec A2, A3, A4, A5) |
| Grandeur mesurée | Part boisée **dans un rayon autour de l’unité**, pas dans l’unité |
| Unité brute | **pourcentage 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_a1_couverture()`](https://pobsteta.github.io/nemeton/reference/indicateur_a1_couverture.md) — `R/indicators-air.R:75` |

## 2. Deux modes

| Mode | Déclencheur | Calcul |
|----|----|----|
| **FVC** | argument `fvc` (`SpatRaster`) | `moyenne(FVC sur le buffer) × 100` |
| **Occupation du sol** | défaut, `land_cover` obligatoire | `pixels forêt / pixels valides × 100` |

    buffer = st_buffer(unite, buffer_radius)         defaut 1 000 m
    A1     = part boisee dans ce buffer, en %

Classes forestières par défaut : `c(16, 17, 18)` — la nomenclature
**OSO** (feuillus, conifères, forêt mélangée). Un raster d’une autre
nomenclature exige de passer `forest_classes` explicitement, sans quoi
le compte est faux silencieusement.

**Exemples chiffrés** (rayon 1 km) :

| Contexte                             | A1       |
|--------------------------------------|----------|
| Parcelle au cœur d’un massif continu | **95,0** |
| Lisière de massif                    | **55,0** |
| Bosquet en plaine agricole           | **12,0** |
| Parcelle périurbaine isolée          | **6,0**  |

## 3. Le calcul par niveau NDP

| NDP | Source | Ce qui change |
|----|----|----|
| **0** | OSO 30 m | le cas nominal ; un bosquet de 20 m disparaît |
| **0 augmenté** | Theia `s2_biophysical` → **FVC** 10 m | grandeur continue au lieu d’une classe : les couverts partiels comptent |
| **1** | BD TOPO + OSO | contours de massif justes |
| **2** | ortho drone | le couvert réel, arbre par arbre |
| **3** | relevé terrain | — |
| **4** | ortho précision scanner | — |

> **Le mode FVC change la nature de la mesure.** En occupation du sol,
> un pixel est boisé ou ne l’est pas ; en FVC, il porte une **fraction
> de couvert végétal** continue. Une haie, une lisière progressive ou un
> peuplement clair valent 0,4 en FVC et « 0 ou 1 » en OSO. Les deux
> modes ne sont donc pas comparables entre eux, même sur la même
> parcelle.

## 4. Trois pièges

1.  **A1 ne décrit pas l’unité, mais son voisinage.** Le buffer de 1 km
    domine largement une parcelle forestière ordinaire (quelques
    hectares). Deux parcelles voisines ont donc des A1 presque
    identiques, quel que soit leur propre boisement. C’est voulu — A1
    mesure un **effet de contexte** sur le microclimat et la qualité de
    l’air — mais interdit de le lire comme « cette parcelle est boisée à
    X % ».
2.  **Le buffer n’est pas soustrait de l’unité.** Le calcul porte sur
    `st_buffer(unité)`, qui **contient** l’unité. Une parcelle boisée
    gonfle donc son propre score, d’autant plus qu’elle est grande par
    rapport au rayon.
3.  **Les classes 16/17/18 sont celles d’OSO, et rien ne le vérifie.**
    Passer un raster d’une autre nomenclature ne produit aucune erreur :
    simplement un comptage de pixels qui ne veut rien dire. Vérifier la
    légende avant.

## 5. Aval

    indicateur_a1_couverture()  ->  colonne A1 (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("A")  -> famille_air = moy(A1, A2, A3, A4, A5)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBBMSA6IGwmIzM5O3VuaXRlIGVzdCBkJiMzOTthYm9yZCB0YW1wb25uZWUgZGUgMSBrbSwgcHVpcyBsYSBwYXJ0IGJvaXNlZSBkZSBjZSB2b2lzaW5hZ2UgZXN0IGx1ZSBzb2l0IGRhbnMgdW4gcmFzdGVyIGRlIGNvdXZlcnQgdmVnZXRhbCwgc29pdCBkYW5zIHVuZSBvY2N1cGF0aW9uIGR1IHNvbCBkb250IGxlcyBjbGFzc2VzIGZvcmVzdGllcmVzIHNvbnQgY2VsbGVzIGQmIzM5O09TTyDigJQgY2UgcXVpIGZhaXQgZGUgQTEgdW5lIG1lc3VyZSBkdSB2b2lzaW5hZ2UsIHBhcyBkZSBsJiMzOTt1bml0ZS4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCBNT0RFUwpFWENMVVNJRlM8L3RleHQ+PHRleHQgeD0iNTg4IiB5PSIxNiI+QVZBTDwvdGV4dD48L2c+PHJlY3QgeD0iOCIgeT0iMzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Vbml0w6kKdGFtcG9ubsOpZTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zdF9idWZmZXIodW5pdMOpLApidWZmZXJfcmFkaXVzKTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5yYXlvbgoxIDAwMCBtIHBhciBkw6lmYXV0PC90ZXh0PjxyZWN0IHg9IjgiIHk9IjEwNiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5SYXN0ZXIKRlZDIChhcmd1bWVudCBmdmMpPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxNDEiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mcmFjdGlvbgpkZSBjb3V2ZXJ0IHbDqWfDqXRhbDwvdGV4dD48cmVjdCB4PSI4IiB5PSIxNjIiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+T2NjdXBhdGlvbgpkdSBzb2wgKE9TTyk8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmxhbmRfY292ZXIsCmNsYXNzZXMgMTYvMTcvMTg8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Nb2RlCkZWQzwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veShGVkMKc3VyIGJ1ZmZlcikgw5cgMTAwPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTEwIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxMjkiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Nb2RlCm9jY3VwYXRpb24gZHUgc29sPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnBpeGVscwpmb3LDqnQgLyBwaXhlbHMgdmFsaWRlczwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij7DlwoxMDA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl9hMV9jb3V2ZXJ0dXJlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+cG91cmNlbnRhZ2UKMOKAkzEwMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+w6ljcsOqdGFnZQpuYXRpZiAw4oCTMTAwPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMTYyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnEHigJ0pPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZhbWlsbGVfYWlyPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgQTEgw6AgQTU8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNDIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI2MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PHBhdGggZD0iTTI2MCA2MyBIMjcxIFY1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxMjcgSDI3MSBWNTUgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTgzIEgyNzEgVjEzOSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijc4IiB4Mj0iMzA2IiB5Mj0iMTA0IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iMyAzIiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iOTQiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPm91PC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI1NSIgeDI9IjU2NiIgeTI9IjU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxMzkiIHgyPSI1NjYiIHkyPSIxMzkiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjU1IiB4Mj0iNTY2IiB5Mj0iMTM5IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI1NSIgeDI9IjU4MCIgeTI9IjU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNDIiIHgyPSI2OTkiIHkyPSIxNTYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMjIiIHgyPSI2OTkiIHkyPSIyMzYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMTAiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkExCmTDqWNyaXQgbGUgdm9pc2luYWdlIDogw6AgMSBrbSBkZSByYXlvbiwgZGV1eCBwYXJjZWxsZXMgdm9pc2luZXMgcmVuZGVudApwcmVzcXVlIGxhIG3Dqm1lIHZhbGV1ci48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGUKYnVmZmVyIG7igJllc3QgcGFzIHNvdXN0cmFpdCBkZSBs4oCZdW5pdMOpIOKAlCBzb24gcHJvcHJlIGJvaXNlbWVudCBjb21wdGUgZGFucwpzb24gdm9pc2luYWdlLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzQyIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5MZXMKY2xhc3NlcyAxNi8xNy8xOCBzb250IGNlbGxlcyBk4oCZT1NPIDsgdW5lIGF1dHJlIG5vbWVuY2xhdHVyZSBmYXVzc2UgbGUKY29tcHRlIGVuIHNpbGVuY2UuPC90ZXh0Pjwvc3ZnPg==)

Le buffer est le vrai sujet du calcul. Changer `buffer_radius` change ce
que A1 mesure — contexte de massif à 1 km, situation de lisière à 200 m
— sans que rien dans la colonne ne le dise.

## 7. Références internes

| Sujet                    | Fichier                                       |
|--------------------------|-----------------------------------------------|
| Fonction A1              | `R/indicators-air.R:75-175`                   |
| Source FVC               | `inst/datasources/FR.json` — `s2_biophysical` |
| Source occupation du sol | `oso`                                         |
