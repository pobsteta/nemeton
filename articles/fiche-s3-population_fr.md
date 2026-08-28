# Fiche indicateur S3 - Population accessible

> **Document de référence** — Néméton (package cœur), 2026-08-27. Deux
> correctifs importants sont documentés ici (§4).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `S3` |
| Nom long / colonne | `indicateur_s3_population` |
| Famille | **S — Social & Usages** |
| Grandeur mesurée | **Densité de population** dans la couronne d’accessibilité |
| Unité brute | **hab/km²** |
| Sens | Haut = favorable |
| Normalisation | **logarithmique** : `100 × log10(1 + d) / log10(1001)` |
| Fonction | [`indicateur_s3_population()`](https://pobsteta.github.io/nemeton/reference/indicateur_s3_population.md) — `R/indicators-social.R:251` |
| Colonnes annexes | `S3_5km`, `S3_10km`, `S3_20km` |

## 2. Le calcul

La population est sommée dans des couronnes de 5, 10 et 20 km autour de
l’unité (grille de population INSEE ou équivalent), puis ramenée à une
densité.

    score = 100 x log10(1 + densite) / log10(1 + 1000)     plafond 1 000 hab/km2 = 100

**Pourquoi une échelle logarithmique** : la grandeur couvre trois ordres
de grandeur en France — 5 hab/km² dans un massif alpin isolé, 40–80 en
rural ordinaire, 300–1 000 en périurbain. Une échelle linéaire
écraserait tout le domaine forestier dans les premiers points.

| Densité         | Score     |
|-----------------|-----------|
| 10 hab/km²      | **33,3**  |
| 50 hab/km²      | **56,7**  |
| 100 hab/km²     | **66,7**  |
| 300 hab/km²     | **82,7**  |
| ≥ 1 000 hab/km² | **100,0** |

Au-delà de 300 hab/km², la forêt est périurbaine : que le chiffre exact
soit 400 ou 900 cesse d’être informatif, et la compression logarithmique
le reflète.

## 3. Le calcul par niveau NDP

| NDP     | Ce qui change                                   |
|---------|-------------------------------------------------|
| **0**   | grille de population INSEE (200 m ou 1 km)      |
| **1–2** | inchangé — la population n’est pas télédétectée |
| **3–4** | enquête de fréquentation                        |

## 4. Trois pièges, dont deux correctifs

1.  **Sans grille de population, S3 vaut `NA`** — et c’est un correctif.
    La méthode antérieure rendait `surface_du_tampon × 100 hab/km²`
    **sans jamais lire de grille** : un nombre qui variait avec la
    taille du tampon et ressemblait à une mesure. Elle a été retirée,
    avec un message explicite.
2.  **`ref_max` a disparu au profit de l’échelle log** — second
    correctif. L’ancien plafond de 10 000 bornait un **effectif brut**
    et saturait dès qu’une vraie source était branchée : mesuré sur
    Couchey, 46 110 habitants dans 5 km donnaient **100/100 pour une
    commune rurale de Bourgogne**. L’indicateur porte désormais une
    **densité**, pas un effectif.
3.  **Les trois colonnes de rayon ne sont pas agrégées dans la
    famille.** `S3_5km`, `S3_10km`, `S3_20km` sont des colonnes de
    diagnostic. Un motif `^S[0-9]` non ancré les avait un temps fait
    entrer dans `famille_social`, qui comptait alors **quatre fois la
    même population** — corrigé en ancrant le motif en fin de nom.

## 5. Aval

    indicateur_s3_population()  ->  colonnes S3 (hab/km2) + S3_5km / S3_10km / S3_20km
          |
          +- normalize_indicator()     -> echelle logarithmique
          +- create_family_index("S")  -> famille_social = moy(S1, S2, S3)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBTMyA6IGxhIHBvcHVsYXRpb24gZXN0IHNvbW1lZSBkYW5zIGRlcyBjb3Vyb25uZXMgZGUgNSwgMTAgZXQgMjAga20sIHJhbWVuZWUgYSB1bmUgZGVuc2l0ZSwgcHVpcyBwb3J0ZWUgc3VyIHVuZSBlY2hlbGxlIGxvZ2FyaXRobWlxdWUgcXVpIHNhdHVyZSBhIDEgMDAwIGhhYml0YW50cyBhdSBraWxvbWV0cmUgY2FycmUgOyBzYW5zIGdyaWxsZSBkZSBwb3B1bGF0aW9uLCBTMyB2YXV0IE5BLiI+PGRlZnM+PG1hcmtlciBpZD0iZmQiIHZpZXdib3g9IjAgMCAxMCAxMCIgcmVmeD0iOSIgcmVmeT0iNSIgbWFya2Vyd2lkdGg9IjYiIG1hcmtlcmhlaWdodD0iNiIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPjxwYXRoIGQ9Ik0wLDAgTDEwLDUgTDAsMTAgeiIgZmlsbD0iY3VycmVudENvbG9yIiAvPjwvbWFya2VyPjwvZGVmcz48ZyBmaWxsPSJjdXJyZW50Q29sb3IiIGZvbnQtc2l6ZT0iMTAiIGxldHRlci1zcGFjaW5nPSIxLjMiIG9wYWNpdHk9Ii41NSI+PHRleHQgeD0iMTAiIHk9IjE2Ij5FTlRSw4lFUzwvdGV4dD48dGV4dCB4PSIyOTAiIHk9IjE2Ij5DQUxDVUwg4oCUIMOJVEFQRVMKU1VDQ0VTU0lWRVM8L3RleHQ+PHRleHQgeD0iNTg4IiB5PSIxNiI+QVZBTDwvdGV4dD48L2c+PHJlY3QgeD0iOCIgeT0iMzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5HcmlsbGUKZGUgcG9wdWxhdGlvbiBJTlNFRTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5vdQrDqXF1aXZhbGVudCBsb2NhbDwvdGV4dD48cmVjdCB4PSI4IiB5PSI5MCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxMDkiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Db3Vyb25uZXMKNSwgMTAgZXQgMjAga208L3RleHQ+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmNvbG9ubmVzClMzXzVrbSwgUzNfMTBrbSwgUzNfMjBrbTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxNDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIxNjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5BdWN1bmUKZ3JpbGxlIGZvdXJuaWU8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlMzCj0gTkE8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Tb21tZQpwYXIgY291cm9ubmU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5wb3B1bGF0aW9uCmRhbnMgY2hhcXVlIHJheW9uPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTEwIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxMjkiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5EZW5zaXTDqSwKcHVpcyDDqWNoZWxsZSBsb2c8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+MTAwCsOXIGxvZzEwKDErZCkgLyBsb2cxMCgxMDAxKTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij4xCjAwMCBoYWIva23CsiAtJmd0OyAxMDA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl9zM19wb3B1bGF0aW9uPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZGVuc2l0w6ksCmhhYi9rbcKyPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5sb2cxMArigJQgcGxhZm9uZCAxIDAwMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE2MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxT4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX3NvY2lhbDwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIFMxIMOgIFMzPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxsaW5lIHgxPSIyNjAiIHkxPSI1NSIgeDI9IjI4MiIgeTI9IjU1IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48cGF0aCBkPSJNMjYwIDExMSBIMjcxIFYxMzkgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTY3IEgyNzEgVjEzOSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijc4IiB4Mj0iMzA2IiB5Mj0iMTA0IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9Ijk0IiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI1NSIgeDI9IjU2NiIgeTI9IjU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxMzkiIHgyPSI1NjYiIHkyPSIxMzkiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjU1IiB4Mj0iNTY2IiB5Mj0iMTM5IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI1NSIgeDI9IjU4MCIgeTI9IjU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNDIiIHgyPSI2OTkiIHkyPSIxNTYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMjIiIHgyPSI2OTkiIHkyPSIyMzYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMTAiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkzigJnDqWNoZWxsZQpsb2cgZXN0IHVuIGNob2l4IDogbGEgZ3JhbmRldXIgY291dnJlIHRyb2lzIG9yZHJlcyBkZSBncmFuZGV1ciwgZHUKbWFzc2lmIGlzb2zDqSBhdSBww6lyaXVyYmFpbi48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+QXUtZGVsw6AKZGUgMzAwIGhhYi9rbcKyLCBsYSBmb3LDqnQgZXN0IHDDqXJpdXJiYWluZSDigJQgNDAwIG91IDkwMCBjZXNzZSBk4oCZw6p0cmUKaW5mb3JtYXRpZi48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM0MiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGVzCnRyb2lzIGNvbG9ubmVzIGRlIHJheW9uIG5lIHNvbnQgcGFzIGFncsOpZ8OpZXMgZGFucyBsYSBmYW1pbGxlIDogc2V1bGUgbGEKcHJpbmNpcGFsZSB5IGVudHJlLjwvdGV4dD48L3N2Zz4=)

Trois couronnes mesurées, une seule dans le score. Les colonnes annexes
distinguent une forêt de proximité d’une forêt de bassin de vie — une
nuance que le score agrégé, lui, ne porte pas.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction S3 | `R/indicators-social.R:251-400` |
| Source population | [`load_insee_population_source()`](https://pobsteta.github.io/nemeton/reference/load_insee_population_source.md) — `R/load_insee_population.R`, spec 050 |
| Normalisation logarithmique | `R/normalization.R`, branche `indicateur_s3_population` |
| Correctif du motif de famille | `R/family-system.R`, stratégie 1 |
