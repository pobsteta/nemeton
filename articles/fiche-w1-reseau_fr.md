# Fiche indicateur W1 - Reseau hydrographique

> **Document de référence** — Néméton (package cœur), 2026-08-27. Cette
> fiche documente une saturation systématique (§4, piège n° 1).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `W1` |
| Nom long / colonne | `indicateur_w1_reseau` |
| Famille | **W — Eau & Régulation** (avec W2, W3, W4) |
| Grandeur mesurée | Densité du réseau hydrographique, majorée d’un bonus de proximité |
| Unité brute | **m/ha + bonus** (grandeur composite, cf. §4) |
| Sens | Haut = favorable |
| Normalisation | `ref_max = 50` → `score = min(100, valeur / 50 × 100)` |
| Fonction | [`indicateur_w1_reseau()`](https://pobsteta.github.io/nemeton/reference/indicateur_w1_reseau.md) — `R/indicators-families.R:603` |

## 2. Le calcul

    densite_directe = longueur des cours d'eau dans l'unite (m) / surface (ha)

    bonus = proximity_ref                             si l'unite est traversee
          = (1 - d_min / proximity_m) x proximity_ref si d_min < proximity_m
          = 0                                          sinon

    W1 = densite_directe + bonus

Défauts : `proximity_m = 500` m, `proximity_ref = 50`, `buffer = 0`.

**Exemples chiffrés** :

| Situation                          | Densité directe | Bonus | W1 brut | Score     |
|------------------------------------|-----------------|-------|---------|-----------|
| Traversée par un ruisseau, 40 m/ha | 40              | 50    | 90      | **100,0** |
| Traversée par un ruisseau, 5 m/ha  | 5               | 50    | 55      | **100,0** |
| Non traversée, cours d’eau à 100 m | 0               | 40    | 40      | **80,0**  |
| Non traversée, cours d’eau à 400 m | 0               | 10    | 10      | **20,0**  |
| Cours d’eau à plus de 500 m        | 0               | 0     | 0       | **0,0**   |

## 3. Le calcul par niveau NDP

| NDP | Source | Ce qui change |
|----|----|----|
| **0** | BD TOPO — réseau hydrographique | le cas nominal |
| **1** | idem | **inchangé** : le réseau vient d’un référentiel vecteur, pas d’un capteur |
| **2** | \+ drainage détecté au LiDAR drone | les écoulements temporaires apparaissent |
| **3** | relevé terrain des cours d’eau | fossés, sources et écoulements non cartographiés |
| **4** | hydrologie complète modélisée | — |

Le saut utile est **NDP 2**, pas NDP 1 : la BD TOPO ne porte pas les
écoulements temporaires ni les fossés d’assainissement forestier, qui
sont précisément ce qui manque à une lecture hydrologique de parcelle.

## 4. Trois pièges

1.  **Toute unité traversée par un cours d’eau score exactement 100.**
    Le bonus plein vaut `proximity_ref = 50`, soit exactement le
    `ref_max` de normalisation. `min(100, (densité + 50) / 50 × 100)`
    vaut donc **100 dès que la densité est positive**, et la densité
    elle-même n’a plus aucun effet. Un fond de vallon parcouru par 120
    m/ha de ruisseaux et une parcelle effleurée par 3 m/ha rendent le
    **même score**. W1 se comporte, en pratique, comme un indicateur à
    trois états : traversée (100), proche (0–100 selon la distance),
    éloignée (0).
2.  **Sans donnée, W1 rend `0`, pas `NA`.** L’absence de couche produit
    un avertissement puis `rep(0, nrow(units))`. C’est l’inverse de la
    politique suivie par B1 et B3, où l’absence rend `NA` avec ce
    commentaire — « absent input is NOT a measurement ». Ici, un projet
    sans couche hydrographique voit `famille_eau` tirée vers le bas par
    des zéros fabriqués, sans que rien ne distingue « aucun cours d’eau
    » de « on n’a pas regardé ».
3.  **La grandeur brute n’a pas d’unité interprétable.**
    `densité + bonus` additionne des m/ha et un score sans dimension. La
    colonne brute ne se lit donc pas comme une densité : elle ne sert
    qu’à produire le score.

## 5. Aval

    indicateur_w1_reseau()  ->  colonne indicateur_w1_reseau
          |
          +- normalize_indicator()     -> min(100, valeur / 50 x 100)
          +- create_family_index("W")  -> famille_eau = moy(W1, W2, W3, W4)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBXMSA6IHVuZSBkZW5zaXRlIGRlIGNvdXJzIGQmIzM5O2VhdSBldCB1biBib251cyBkZSBwcm94aW1pdGUgcyYjMzk7YWRkaXRpb25uZW50LCBwdWlzIGxhIHNvbW1lIGVzdCBub3JtYWxpc2VlIGEgcmVmX21heCA9IDUwIDsgbGUgYm9udXMgcGxlaW4gdmFsYW50IGx1aS1tZW1lIDUwLCB0b3V0ZSB1bml0ZSB0cmF2ZXJzZWUgc2F0dXJlIGEgMTAwIHF1ZWxsZSBxdWUgc29pdCBzYSBkZW5zaXRlLiI+PGRlZnM+PG1hcmtlciBpZD0iZmQiIHZpZXdib3g9IjAgMCAxMCAxMCIgcmVmeD0iOSIgcmVmeT0iNSIgbWFya2Vyd2lkdGg9IjYiIG1hcmtlcmhlaWdodD0iNiIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPjxwYXRoIGQ9Ik0wLDAgTDEwLDUgTDAsMTAgeiIgZmlsbD0iY3VycmVudENvbG9yIiAvPjwvbWFya2VyPjwvZGVmcz48ZyBmaWxsPSJjdXJyZW50Q29sb3IiIGZvbnQtc2l6ZT0iMTAiIGxldHRlci1zcGFjaW5nPSIxLjMiIG9wYWNpdHk9Ii41NSI+PHRleHQgeD0iMTAiIHk9IjE2Ij5FTlRSw4lFUzwvdGV4dD48dGV4dCB4PSIyOTAiIHk9IjE2Ij5DQUxDVUwg4oCUIFRFUk1FUwpDVU1VTMOJUzwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkJEClRPUE8g4oCUIHLDqXNlYXUgaHlkcm88L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y291Y2hlCnZlY3RldXIgd2F0ZXJfbmV0d29yazwvdGV4dD48dGV4dCB4PSIyMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jb3Vycwpk4oCZZWF1IHBlcm1hbmVudHM8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTA2IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkfDqW9tw6l0cmllCmRlIGzigJl1bml0w6k8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE0MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnN1cmZhY2UKKGhhKSwgZGlzdGFuY2UgYXUgcsOpc2VhdTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxNjIiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5BdWN1bmUKY291Y2hlIGZvdXJuaWU8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmF2ZXJ0aXNzZW1lbnQsCnB1aXMgMCBwYXJ0b3V0PC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMzQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+RGVuc2l0w6kKZGlyZWN0ZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmxvbmd1ZXVyCihtKSAvIHN1cmZhY2UgKGhhKTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjExMCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI3NCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTI5IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Qm9udXMKZGUgcHJveGltaXTDqTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE0NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij50cmF2ZXJzw6llCi0mZ3Q7IDUwPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmQKJmx0OyA1MDAgbSAtJmd0OyAoMS1kLzUwMCkgw5cgNTA8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2lub24KLSZndDsgMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjM0IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0iIzJDNkI2MDBGIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuOTUiIC8+PHRleHQgeD0iNTk4IiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjMkM2QjYwIj5pbmRpY2F0ZXVyX3cxX3Jlc2VhdTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm0vaGEKKyBib251cyAoY29tcG9zaXRlKTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bWluKDEwMCwKdiAvIDUwIMOXIDEwMCk8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcV+KAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9lYXU8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpkZSBXMSDDoCBXNDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjI0MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMjYxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y29tcHV0ZV9nZW5lcmFsX2luZGV4KCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Rmlib25hY2NpCsK3IGNvbmZpYW5jZSDPhjwvdGV4dD48cGF0aCBkPSJNMjYwIDYzIEgyNzEgVjU1IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDEyNyBIMjcxIFYxNDcgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTgzIEgyNzEgVjE0NyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijc4IiB4Mj0iMzA2IiB5Mj0iMTA0IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9Ijk0IiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij4rPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI1NSIgeDI9IjU2NiIgeTI9IjU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxNDciIHgyPSI1NjYiIHkyPSIxNDciIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjU1IiB4Mj0iNTY2IiB5Mj0iMTQ3IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI1NSIgeDI9IjU4MCIgeTI9IjU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNDIiIHgyPSI2OTkiIHkyPSIxNTYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMjIiIHgyPSI2OTkiIHkyPSIyMzYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMTAiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlCmJvbnVzIHBsZWluICg1MCkgdmF1dCBleGFjdGVtZW50IGxlIHJlZl9tYXggKDUwKSA6IHRyYXZlcnPDqWUgPSAxMDAsCmRlbnNpdMOpIHNhbnMgZWZmZXQuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlNhbnMKY291Y2hlLCBXMSByZW5kIDAgZXQgbm9uIE5BIOKAlCB1biB6w6lybyBmYWJyaXF1w6kgdGlyZSBmYW1pbGxlX2VhdSB2ZXJzIGxlCmJhcy48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM0MiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGEKY29sb25uZSBicnV0ZSBhZGRpdGlvbm5lIGRlcyBtL2hhIGV0IHVuIHNjb3JlIDogZWxsZSBuZSBzZSBsaXQgcGFzIGNvbW1lCnVuZSBkZW5zaXTDqS48L3RleHQ+PC9zdmc+)

Deux termes cumulés, un seul plafond. Comme le bonus de traversée égale
le `ref_max` de normalisation, W1 se comporte en pratique comme un
indicateur à trois états : traversée, proche, éloignée.

## 7. Références internes

| Sujet                          | Fichier                           |
|--------------------------------|-----------------------------------|
| Fonction W1                    | `R/indicators-families.R:603-680` |
| Normalisation (`ref_max = 50`) | `R/normalization.R:588`           |
| Source                         | BD TOPO, couche `water_network`   |
