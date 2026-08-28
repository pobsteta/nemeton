# Fiche indicateur B3 - Connectivite ecologique

> **Document de référence** — Néméton (package cœur), 2026-08-27. Cette
> fiche documente un défaut de conception actif (§4, piège n° 1). À lire
> avant d’interpréter un score B3.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `B3` |
| Nom long / colonne | `indicateur_b3_connectivite` |
| Famille | **B — Biodiversité** |
| Grandeur mesurée | Capacité de l’unité à fonctionner comme corridor écologique |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, simple écrêtage |
| Fonction | [`indicateur_b3_connectivite()`](https://pobsteta.github.io/nemeton/reference/indicateur_b3_connectivite.md) — `R/indicators-biodiversity.R:559` |
| Entrée obligatoire | `bdforet` (sf) — sans elle, `NA` |

## 2. Le calcul

B3 mêle un score **de paysage** (identique pour toutes les unités du
projet) et un score **local** (propre à chaque unité) :

    B3_global = 0,25 x structural + 0,25 x cost + 0,25 x graph + 0,25 x kernel
    B3        = min(100, max(0, 0,7 x B3_global + 0,3 x local))

| Composante | Outil | Ce qu’elle mesure | Paquet |
|----|----|----|----|
| `structural` | [`landscapemetrics::lsm_c_cohesion()`](https://r-spatialecology.github.io/landscapemetrics/reference/lsm_c_cohesion.html) + ENN | cohésion des taches forestières | **Suggests** |
| `cost` | `terra` | distance-coût sur le MNT (`dem`) | Imports |
| `graph` | `igraph` | graphe des taches reliées à moins de **500 m** | **Suggests** |
| `kernel` | `adehabitatHR` (+ `sp`) | noyau de dispersion | **Suggests** |
| `local` | [`sf::st_distance`](https://r-spatial.github.io/sf/reference/geos_measures.html) | proximité forestière dans `max_distance` (défaut **5 000 m**) | Imports |

L’emprise d’analyse est la bbox des unités **tamponnée de 2 km**, pour
que les massifs voisins comptent dans la connectivité.

## 3. Le calcul par niveau NDP

| NDP | Ce qui change |
|----|----|
| **0** | BD Forêt + distance euclidienne ; MNT 25 m pour la distance-coût |
| **1** | MNT LiDAR HD → distance-coût sur un relief réel, graphe et noyau inchangés |
| **2** | emprise forestière corrigée au drone : les taches sont justes |
| **3** | emprise vérifiée au sol |
| **4** | réseau complet modélisé |

B3 est, avec B1, l’un des indicateurs où le NDP joue **peu** : la
connectivité se calcule sur un **zonage forestier** (BD Forêt) et une
**topographie**, pas sur un capteur haute résolution. Le gain réel du
NDP 1 porte sur la seule composante `cost`, soit un quart du score de
paysage, soit **17,5 %** du B3 final.

## 4. Trois pièges, dont un sérieux

1.  **Chaque composante absente est remplacée par un 50 silencieux.**
    Les trois paquets `landscapemetrics`, `igraph` et `adehabitatHR`
    sont en **`Suggests`**, donc absents d’une installation minimale.
    Chaque `tryCatch` retombe alors sur la constante **50** — sans
    avertissement, sans colonne de diagnostic, sans trace dans la valeur
    rendue.

    Conséquence chiffrée : sans aucun des trois paquets,
    `structural = cost = graph = kernel = 50` (la distance-coût
    elle-même retombe à 50 si le `dem` est `NULL`), donc
    `B3_global = 50` **exactement**, et `B3 = 35 + 0,3 × local` — un
    score qui **paraît mesuré** alors que 70 % en est une constante. Un
    projet installé sans les Suggests et un projet complet produiront
    des B3 différents sur les mêmes données, sans que rien ne le dise.

    > Le même fichier, quinze lignes plus haut, refuse explicitement ce
    > procédé : l’absence de `bdforet` rend `NA` et non 50, avec ce
    > commentaire — « la connectivité des massifs n’est pas mesurable :
    > elle est inconnue, pas moyenne. Le 50 d’origine entrait dans la
    > moyenne de famille comme s’il avait été constaté. » Le
    > raisonnement est juste ; il n’a simplement pas été appliqué aux
    > quatre composantes internes.

    **Contournement en attendant** : installer les trois Suggests,
    fournir un `dem`, et vérifier le message
    `biodiversity_b3_components` émis en fin de calcul — il affiche la
    moyenne de chaque composante. Quatre valeurs à exactement 50 sont le
    symptôme.

2.  **Le score de paysage est identique pour toutes les unités.** 70 %
    de B3 ne varie pas d’une unité à l’autre à l’intérieur d’un projet ;
    seuls les 30 % locaux discriminent. L’écart-type de B3 dans un
    projet est donc, par construction, **trois fois plus faible** que
    celui de sa composante locale. Un radar B3 « plat » entre unités
    n’est pas une anomalie de mesure.

3.  **B3 n’est pas comparable entre projets.** La bbox tamponnée de 2 km
    et le seuil de graphe de 500 m sont ancrés sur l’emprise du projet :
    deux projets d’étendues différentes ne calculent pas la même chose.

## 5. Aval

    indicateur_b3_connectivite()  ->  colonne B3 (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("B")  -> famille_biodiversite

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBCMyA6IHF1YXRyZSBjb21wb3NhbnRlcyBkZSBwYXlzYWdlIGNhbGN1bGVlcyBzdXIgbGEgYmJveCBkdSBwcm9qZXQgdGFtcG9ubmVlIGRlIDIga20sIG1veWVubmVlcyBhIHBhcnRzIGVnYWxlcywgcHVpcyBtZWxhbmdlZXMgNzAvMzAgYXZlYyB1bmUgY29tcG9zYW50ZSBsb2NhbGUgOyB0b3V0ZSBjb21wb3NhbnRlIGRvbnQgbGUgcGFxdWV0IFN1Z2dlc3RzIG1hbnF1ZSBlc3QgcmVtcGxhY2VlIHBhciA1MC4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCDDiVRBUEVTClNVQ0NFU1NJVkVTPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+YmRmb3JldAooc2YpIOKAlCBvYmxpZ2F0b2lyZTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zYW5zCmVsbGUsIEIzIHJlbmQgTkE8L3RleHQ+PHJlY3QgeD0iOCIgeT0iOTAiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTA5IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+TU5UCihkZW0pPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zdXBwb3J0CmRlIGxhIGRpc3RhbmNlLWNvw7t0PC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE0NiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMjAiIHk9IjE2NSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlBhcXVldHMKU3VnZ2VzdHMgYWJzZW50czwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTgxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y29tcG9zYW50ZQpyZW1wbGFjw6llIHBhciA1MDwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlF1YXRyZQpjb21wb3NhbnRlcyBwYXlzYWdlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c3RydWN0dXJhbArCtyBjb3N0IMK3IGdyYXBoIMK3IGtlcm5lbDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPjAsMjUKY2hhY3VuZSwgYmJveCArIDIga208L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIxMjYiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjE0NSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNvbXBvc2FudGUKbG9jYWxlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnByb3hpbWl0w6kKZm9yZXN0acOocmU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bWF4X2Rpc3RhbmNlCj0gNSAwMDAgbTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjIxOCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMjM3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+TcOpbGFuZ2UKNzAgLyAzMDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjI1MyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij4wLDcKw5cgZ2xvYmFsICsgMCwzIMOXIGxvY2FsPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfYjNfY29ubmVjdGl2aXRlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2NvcmUKMOKAkzEwMCwgbmF0aWY8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOpY3LDqnRhZ2UKbmF0aWYgMOKAkzEwMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE2MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxC4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX2Jpb2RpdmVyc2l0ZTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIEIxIMOgIEI0PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxwYXRoIGQ9Ik0yNjAgNTUgSDI3MSBWNjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTExIEgyNzEgVjE1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxNjcgSDI3MSBWMjM5IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48bGluZSB4MT0iMzA2IiB5MT0iOTQiIHgyPSIzMDYiIHkyPSIxMjAiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMTEwIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSIzMDYiIHkxPSIxODYiIHgyPSIzMDYiIHkyPSIyMTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMjAyIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxNTUiIHgyPSI1NjYiIHkyPSIxNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjIzOSIgeDI9IjU2NiIgeTI9IjIzOSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1NjYiIHkyPSIyMzkiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTgwIiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE0MiIgeDI9IjY5OSIgeTI9IjE1NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIyMiIgeDI9IjY5OSIgeTI9IjIzNiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjMxMCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+VW5lCmNvbXBvc2FudGUgYWJzZW50ZSB2YXV0IDUwIGVuIHNpbGVuY2UgOiBsZSBzY29yZSByZXN0ZSBwbGF1c2libGUgc2Fucwphdm9pciDDqXTDqSBjYWxjdWzDqS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+NzAKJSBkdSBzY29yZSBlc3QgdW4gc2NvcmUgZGUgcGF5c2FnZSBpZGVudGlxdWUgcG91ciB0b3V0ZXMgbGVzIHVuaXTDqXMgZHUKcHJvamV0LjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzQyIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5MYQpiYm94IHRhbXBvbm7DqWUgZMOpcGVuZCBkdSBww6lyaW3DqHRyZSBkZW1hbmTDqSA6IEIzIG5lIHNlIGNvbXBhcmUgcGFzIGTigJl1bgpwcm9qZXQgw6AgbOKAmWF1dHJlLjwvdGV4dD48L3N2Zz4=)

Trois quarts de paysage, un quart de local — et un 50 par défaut à
chaque composante manquante. Vérifier quels paquets Suggests sont
installés avant de lire un B3 : c’est la variable cachée du score.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction B3 et ses quatre composantes | `R/indicators-biodiversity.R:559-680` |
| Helpers | `.b3_structural`, `.b3_cost_distance`, `.b3_graph`, `.b3_kernel`, `.b3_local` |
| Paquets optionnels | `DESCRIPTION`, section `Suggests` |
