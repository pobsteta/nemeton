# Fiche indicateur W2 - Zones humides

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `W2` |
| Nom long / colonne | `indicateur_w2_zones_humides` |
| Famille | **W — Eau & Régulation** |
| Grandeur mesurée | Part de l’unité en zone humide ou riparienne |
| Unité brute | **pourcentage cumulé** (cf. §4) |
| Sens | Haut = favorable |
| Normalisation | `ref_max = 5` → `score = min(100, valeur / 5 × 100)` |
| Fonction | [`indicateur_w2_zones_humides()`](https://pobsteta.github.io/nemeton/reference/indicateur_w2_zones_humides.md) — `R/indicators-families.R:719` |

## 2. Le calcul — une somme de sources, pas un maximum

W2 **additionne** la contribution de chaque source disponible :

| Source | Contribution |
|----|----|
| BD TOPO, surfaces en eau | `aire(intersection) / aire(unité) × 100` |
| TWI | part surfacique des pixels de **TWI \> 12** |
| OSO, codes d’occupation « zone humide » | part surfacique des pixels concernés |
| Theia `theia_water` (occurrence d’eau) | part des pixels dont l’occurrence atteint `occurrence_threshold` |

    W2 = somme des contributions disponibles      puis min(...) au plafond

**Exemples chiffrés** :

| Situation | Contributions | W2 brut | Score |
|----|----|----|----|
| 1 % de mare en BD TOPO, rien d’autre | 1,0 | 1,0 | **20,0** |
| 3 % de TWI \> 12 | 3,0 | 3,0 | **60,0** |
| 2 % BD TOPO + 4 % TWI | 2 + 4 | 6,0 | **100,0** (saturé) |
| Aucune source | 0 | 0,0 | **0,0** |

## 3. Le calcul par niveau NDP

| NDP | Sources effectives | Ce qui change |
|----|----|----|
| **0** | OSO 30 m + TWI calculé sur MNT 25 m | le TWI grossier domine |
| **1** | BD TOPO surfaces en eau + **TWI sur LiDAR HD** | le TWI change d’échelle : les micro-dépressions apparaissent |
| **2** | \+ détection drone | zones humides visibles au sol |
| **3** | cartographie terrain | seule source qui distingue une vraie zone humide d’un simple creux |
| **4** | inventaire complet modélisé | — |

**C’est l’indicateur le plus sensible au passage NDP 0 → 1 de la famille
W**, parce que le TWI y change de résolution, et que le TWI y pèse le
plus lourd.

## 4. Trois pièges

1.  **Le plafond de 5 % sature très vite.** `ref_max = 5` signifie
    qu’**une unité à 5 % de zone humide obtient déjà 100**. Le choix se
    défend — 5 % de zone humide dans une parcelle forestière est une
    proportion notable — mais toute la variabilité au-dessus de 5 % est
    écrasée. Une ripisylve à 30 % et une parcelle à 5 % sont
    indistinguables sur le score.
2.  **Les sources s’additionnent, elles ne s’unissent pas
    géométriquement.** Une mare cartographiée en BD TOPO, située dans
    une dépression de TWI \> 12 et classée « zone humide » par OSO est
    comptée **trois fois**. Avec trois sources concordantes, 1,7 % de
    surface réelle suffit à saturer le score. Plus il y a de sources
    branchées, plus W2 monte — même à réalité constante.
3.  **Le seuil TWI \> 12 est un seuil de convention.** Il ne signifie
    pas « zone humide » au sens réglementaire (sol, flore, hydromorphie)
    ; c’est un proxy topographique d’accumulation. Ne pas s’en servir
    pour un enjeu réglementaire.

## 5. Aval

    indicateur_w2_zones_humides()  ->  colonne indicateur_w2_zones_humides
          |
          +- normalize_indicator()     -> min(100, valeur / 5 x 100)
          +- create_family_index("W")  -> famille_eau

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBXMiA6IHF1YXRyZSBzb3VyY2VzIGRlIHpvbmUgaHVtaWRlIGFwcG9ydGVudCBjaGFjdW5lIHVuIHBvdXJjZW50YWdlIGRlIHN1cmZhY2UsIGNlcyBwb3VyY2VudGFnZXMgc29udCBhZGRpdGlvbm5lcyBzYW5zIHVuaW9uIGdlb21ldHJpcXVlLCBwdWlzIG5vcm1hbGlzZXMgYSByZWZfbWF4ID0gNSDigJQgc2kgYmllbiBxdWUgdHJvaXMgc291cmNlcyBjb25jb3JkYW50ZXMgc2F0dXJlbnQgbGUgc2NvcmUgc3VyIG1vaW5zIGRlIDIgJSBkZSBzdXJmYWNlIHJlZWxsZS4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+QkQKVE9QTyDigJQgc3VyZmFjZXMgZW4gZWF1PC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmFpcmUoaW50ZXJzZWN0aW9uKQovIGFpcmUodW5pdMOpKTwvdGV4dD48cmVjdCB4PSI4IiB5PSI5MCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxMDkiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5UV0kKKE1OVCBvdSBMaURBUiBIRCk8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnBhcnQKZGVzIHBpeGVscyBkZSBUV0kgJmd0OyAxMjwvdGV4dD48cmVjdCB4PSI4IiB5PSIxNDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTY1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+T1NPCuKAlCBvY2N1cGF0aW9uIGR1IHNvbDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTgxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+cGFydApkZXMgcGl4ZWxzIMKrIHpvbmUgaHVtaWRlIMK7PC90ZXh0PjxyZWN0IHg9IjgiIHk9IjIwMiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIyMjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5UaGVpYQp0aGVpYV93YXRlcjwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMjM3IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+cGFydAphdS1kZXNzdXMgZHUgc2V1aWwgZOKAmW9jY3VycmVuY2U8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI3NCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Tb21tZQpkZXMgY29udHJpYnV0aW9uczwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlcyCj0gzqMgZGVzIHNvdXJjZXMgcHLDqXNlbnRlczwvdGV4dD48dGV4dCB4PSIzMDAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmF1Y3VuZQp1bmlvbiBnw6lvbcOpdHJpcXVlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTAxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnVuZQptw6ptZSBtYXJlIHBldXQgY29tcHRlciAzw5c8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl93Ml96b25lc19odW1pZGVzPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+JQpkZSBzdXJmYWNlLCBjdW11bMOpPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5taW4oMTAwLAp2IC8gNSDDlyAxMDApPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMTYyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnFfigJ0pPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZhbWlsbGVfZWF1PC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgVzEgw6AgVzQ8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNDIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI2MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PHBhdGggZD0iTTI2MCA1NSBIMjcxIFY3MSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxMTEgSDI3MSBWNzEgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTY3IEgyNzEgVjcxIEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDIyMyBIMjcxIFY3MSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjU1MCIgeTE9IjcxIiB4Mj0iNTY2IiB5Mj0iNzEiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjcxIiB4Mj0iNTgwIiB5Mj0iNzEiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE0MiIgeDI9IjY5OSIgeTI9IjE1NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIyMiIgeDI9IjY5OSIgeTI9IjIzNiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjMxMCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+cmVmX21heAo9IDUgOiB1bmUgcmlwaXN5bHZlIMOgIDMwICUgZXQgdW5lIHBhcmNlbGxlIMOgIDUgJSByZW5kZW50IGxlIG3Dqm1lCnNjb3JlLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzI2IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5QbHVzCmlsIHkgYSBkZSBzb3VyY2VzIGJyYW5jaMOpZXMsIHBsdXMgVzIgbW9udGUg4oCUIMOgIHLDqWFsaXTDqSBjb25zdGFudGUuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlRXSQomZ3Q7IDEyIGVzdCB1biBzZXVpbCBkZSBjb252ZW50aW9uIHRvcG9ncmFwaGlxdWUsIHBhcyB1bmUgem9uZSBodW1pZGUKcsOpZ2xlbWVudGFpcmUuPC90ZXh0Pjwvc3ZnPg==)

Quatre sources qui s’additionnent au lieu de s’unir. Le double comptage
n’est pas un défaut d’implémentation isolé : c’est le mécanisme même de
l’indicateur, et il explique la saturation précoce du score.

## 7. Références internes

| Sujet               | Fichier                                           |
|---------------------|---------------------------------------------------|
| Fonction W2         | `R/indicators-families.R:719-880`                 |
| TWI partagé avec W3 | `get_or_compute_twi()` — cache de fichier         |
| Sources déclarées   | `inst/datasources/FR.json` — `theia_water`, `oso` |
