# Fiche indicateur R7 - Gel tardif

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** à une série de températures minimales
> journalières. **Non inversé**, comme R6.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `R7` |
| Nom long / colonne | `indicateur_r7_gel` |
| Famille | **R — Risques & Résilience** |
| Grandeur mesurée | Exposition au **gel tardif** après débourrement |
| Unité brute | **0–100, haut = peu de gel = favorable** |
| Sens | **non inversé** |
| Fonction | [`indicateur_r7_gel()`](https://pobsteta.github.io/nemeton/reference/indicateur_r7_gel.md) — `R/indicators-frost.R:69` |
| Colonnes annexes | `r7_gel_days` (jours/an), `r7_status` |

## 2. Le calcul

    fenetre = [budburst_doy ; window_end_doy]        defaut [100 ; 180], soit ~10 avril - 29 juin
    gel_days = nombre moyen de jours par an ou Tmin < frost_threshold_c   defaut 0 °C
    R7 = 100 quand gel_days = 0 ; 0 quand gel_days >= max_frost_days      defaut 8

Le `SpatRaster` `tmin` doit porter ses dates via
[`terra::time()`](https://rspatial.github.io/terra/reference/time.html)
— sans elles, la fonction **abandonne avec un message explicite** plutôt
que de placer les gelées au hasard dans la saison.

**Exemples chiffrés** :

| Situation                     | Jours de gel tardif / an | R7       |
|-------------------------------|--------------------------|----------|
| Plateau abrité                | 0,5                      | **93,8** |
| Station ordinaire             | 2,0                      | **75,0** |
| Fond de vallon froid          | 5,0                      | **37,5** |
| Cuvette à inversion thermique | 9,0                      | **0,0**  |

## 3. Le calcul par niveau NDP

| NDP | Source de `tmin` | R7 |
|----|----|----|
| **0** sans série | rien | **`NA`**, `r7_status = "skipped_no_tmin"` |
| **0** | E-OBS / SAFRAN descendus en résolution | **calculé**, maille kilométrique |
| **1** | \+ descente d’échelle sur MNT LiDAR HD | les cuvettes froides apparaissent |
| **2** | — | — |
| **3** | **capteurs de température au sol** | seule mesure directe |
| **4** | — | — |

R7 relève du chantier microclimat P4 (`meteoland`/SAFRAN) et n’est pas
encore alimenté par défaut dans le pipeline.

## 4. Trois pièges

1.  **Le débourrement est une constante, pas une phénologie.**
    `budburst_doy = 100` (≈ 10 avril) s’applique à toutes les unités et
    à toutes les essences. Or le chêne débourre trois semaines après le
    hêtre, et l’altitude décale encore la date. Le paramètre est exposé
    — le régler par essence est à la charge de l’appelant.
2.  **Le gel tardif est un phénomène de fond de vallon, donc de
    micro-relief.** À la maille kilométrique d’E-OBS, les inversions
    thermiques nocturnes — précisément ce qui cause le dégât — sont
    invisibles. R7 à NDP 0 mesure un climat régional, pas un risque de
    station.
3.  **Le seuil de 0 °C sous-estime le dégât.** Les jeunes pousses sont
    endommagées avant le gel de l’air, par rayonnement.
    `frost_threshold_c` est réglable : le relever (par exemple à +2 °C)
    est souvent plus réaliste.

## 5. Aval

    indicateur_r7_gel()  ->  colonnes R7, r7_gel_days, r7_status
          |
          +- normalize_indicator()     -> ecretage [0, 100], PAS d'inversion
          +- create_family_index("R")  -> famille_risque = moy(R1..R7, na.rm = TRUE)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM3NiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBSNyA6IGRhbnMgdW5lIGZlbmV0cmUgZGUgZGVib3VycmVtZW50IGZpeGVlIHBhciBjb252ZW50aW9uIGVudHJlIGxlcyBqb3VycyAxMDAgZXQgMTgwLCBsZXMgam91cnMgb3UgbGEgdGVtcGVyYXR1cmUgbWluaW1hbGUgcGFzc2Ugc291cyB6ZXJvIHNvbnQgY29tcHRlcywgcHVpcyByYXBwb3J0ZXMgYSB1biBwbGFmb25kIGRlIGh1aXQgam91cnMgOyBzYW5zIGRhdGVzIHBvcnRlZXMgcGFyIGxlIHJhc3RlciwgbGEgZm9uY3Rpb24gYWJhbmRvbm5lIGF1IGxpZXUgZGUgZGV2aW5lci4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCDDiVRBUEVTClNVQ0NFU1NJVkVTPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+UmFzdGVyCnRtaW4gKFNBRlJBTiwgbWV0ZW9sYW5kKTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5kYXRlcwp2aWEgdGVycmE6OnRpbWUoKTwvdGV4dD48cmVjdCB4PSI4IiB5PSI5MCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxMDkiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5GZW7DqnRyZQpkZSBkw6lib3VycmVtZW50PC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5idWRidXJzdF9kb3kKPSAxMDA8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE0MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPndpbmRvd19lbmRfZG95Cj0gMTgwPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE2MiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlJhc3RlcgpzYW5zIGRhdGVzPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5hYmFuZG9uCmV4cGxpY2l0ZSwgcGFzIGRlIHZhbGV1cjwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNvbXB0YWdlCmRlcyBnZWzDqWVzPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+VG1pbgombHQ7IGZyb3N0X3RocmVzaG9sZF9jPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZMOpZmF1dAowIMKwQywgbW95ZW5uZSBwYXIgYW48L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIxMjYiIHdpZHRoPSIyNjIiIGhlaWdodD0iNzQiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjE0NSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPk1pc2UKw6AgbOKAmcOpY2hlbGxlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPjAKam91ciAtJmd0OyAxMDA8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bWF4X2Zyb3N0X2RheXMKLSZndDsgMDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE5MyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5kw6lmYXV0Cjggam91cnM8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl9yN19nZWw8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5oYXV0Cj0gcGV1IGRlIGdlbDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+cGFzc3Rocm91Z2gKw6ljcsOqdMOpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTQ5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlBBUwpk4oCZaW52ZXJzaW9uPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMTc4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnFLigJ0pPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZhbWlsbGVfcmlzcXVlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjI5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgUjEgw6AgUjc8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjkzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PHBhdGggZD0iTTI2MCA1NSBIMjcxIFY2MyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxMTkgSDI3MSBWMTYzIEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDE4MyBIMjcxIFYxNjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI5NCIgeDI9IjMwNiIgeTI9IjEyMCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIxMTAiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnB1aXM8L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE2MyIgeDI9IjU2NiIgeTI9IjE2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1NjYiIHkyPSIxNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTgwIiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE1OCIgeDI9IjY5OSIgeTI9IjE3MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIzOCIgeDI9IjY5OSIgeTI9IjI1MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGUKZMOpYm91cnJlbWVudCBlc3QgdW5lIGNvbnN0YW50ZSwgcGFzIHVuZSBwaMOpbm9sb2dpZSA6IGxhIG3Dqm1lIGZlbsOqdHJlCnBvdXIgdG91dGVzIGxlcyBlc3NlbmNlcyBldCB0b3V0ZXMgbGVzIGFsdGl0dWRlcy48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM0MiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGUKZ2VsIHRhcmRpZiBlc3QgdW4gcGjDqW5vbcOobmUgZGUgZm9uZCBkZSB2YWxsb24g4oCUIHNhIG1haWxsZSB1dGlsZSBlc3QgbGUKbWljcm8tcmVsaWVmLCBwYXMgbGEgbWFpbGxlIFNBRlJBTi48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM1OCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGUKc2V1aWwgZGUgMCDCsEMgc291cy1lc3RpbWUgbGUgZMOpZ8OidCA6IGxlcyBqZXVuZXMgcG91c3NlcyBnw6hsZW50IGF2YW50IHF1ZQps4oCZYWlyIG7igJlhdHRlaWduZSB6w6lyby48L3RleHQ+PC9zdmc+)

Un comptage de jours dans une fenêtre conventionnelle. Les deux bornes —
la fenêtre et le seuil de 0 °C — sont des conventions : elles fixent ce
que R7 appelle « gel tardif » bien plus que le climat local.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R7 | `R/indicators-frost.R:69` |
| Comptage des gelées | `.frost_late_days()` |
| Forçage climatique | [`meteoland_daily_grid()`](https://pobsteta.github.io/nemeton/reference/meteoland_daily_grid.md), [`build_safran_stations()`](https://pobsteta.github.io/nemeton/reference/build_safran_stations.md), [`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md) |
| Chantier | `specs/brief-meteoland-safran-p4.md` |
