# Fiche indicateur B4 - Diversite spectrale alpha

> **Document de référence** — Néméton (package cœur), 2026-08-27. **Un
> interdit d’usage est attaché à cet indicateur** (§4). Il fait l’objet
> de l’écart n° 7 du `PLAN.md` vers l’application.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `B4` |
| Nom long / colonne | `indicateur_b4_div_spectrale` |
| Famille | **B — Biodiversité** |
| Grandeur mesurée | Diversité spectrale **α** : indice de Shannon des « spectral species » |
| Unité brute | **indice de Shannon**, sans unité, ≈ \[0 ; 2,5\] |
| Sens | Haut = favorable |
| Normalisation | `score = min(100, max(0, H / log(10) × 100))` — `R/normalization.R:707` |
| Fonction | [`indicateur_b4_div_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_b4_div_spectrale.md) — `R/spectral_diversity.R:312` |
| Spécification | spec 028 |

## 2. Le calcul

    1. biodivMapR classe les pixels Sentinel-2 en « spectral species » (k-means)
    2. Shannon H de leur distribution, par fenetre de 100 m
    3. B4 = moyenne des fenetres couvrant l'unite            .aggregate_diversity()
    4. score = H / log(10) x 100                             plafond = 10 especes equi-abondantes

Le plafond `.B4_MAX_SPECTRAL_SPECIES = 10` s’interprète sur le **nombre
effectif d’espèces spectrales**, `exp(H)` — la quantité qu’un forestier
peut se représenter : dix communautés spectrales distinguables dans un
hectare est un peuplement réellement hétérogène.

**Exemples chiffrés** (jeu de référence : meilleure fenêtre 11,7 espèces
effectives, unité typique 2,2) :

| Situation                         | `exp(H)` | H    | Score              |
|-----------------------------------|----------|------|--------------------|
| Futaie régulière monospécifique   | 1,6      | 0,47 | **20,4**           |
| Unité typique du jeu de référence | 2,2      | 0,79 | **34,3**           |
| Mosaïque feuillus/résineux        | 4,5      | 1,50 | **65,3**           |
| Meilleure fenêtre mesurée         | 11,7     | 2,46 | **100,0** (saturé) |

## 3. Le calcul par niveau NDP

| NDP | Ce qui change |
|----|----|
| **0** | Sentinel-2 10 m — le cas nominal, B4 est un indicateur NDP 0 par nature |
| **1** | **inchangé** : le LiDAR HD ne porte aucun signal spectral |
| **2** | ortho drone multispectrale : les espèces spectrales cessent de mélanger houppier et trouée |
| **3** | relevé floristique de validation — B4 reste un proxy, le relevé le calibre |
| **4** | scan spectral par houppier |

Comme C2, B4 ne progresse pas entre NDP 0 et NDP 1.

## 4. L’interdit d’usage, et deux autres pièges

1.  **B4 ne se compare ni entre projets, ni dans le temps — c’est un
    interdit, pas une réserve.** Les « spectral species » sont un
    **k-means réajusté à chaque exécution** sur la scène traitée (spec
    028 §10.6). La classe n° 3 d’un projet n’a aucun rapport avec la
    classe n° 3 d’un autre, et deux runs sur le même massif à deux dates
    produisent deux partitions différentes. **Ne jamais classer,
    moyenner ou suivre B4 entre projets.** L’indicateur répond à « cette
    unité est-elle plus hétérogène que sa voisine, dans ce run ? » —
    rien d’autre. C’est l’objet de l’écart n° 7 du `PLAN.md`.

2.  **Un peuplement monospécifique légitime obtient un score bas**, et
    ce n’est pas un défaut : une futaie régulière de hêtre *est*
    spectralement homogène. B4 mesure une hétérogénéité, qui n’est pas
    une valeur de gestion en soi. Le tooltip de l’application le dit ;
    une lecture « B4 bas = mauvaise sylviculture » est une erreur
    d’interprétation.

3.  **Le plafond de 10 espèces effectives est provisoire.** Il remplace
    le `log(nbclusters) = log(50)` de la spec 028 D3 et est calibré sur
    **un seul massif de référence**. Il est explicitement à revoir dès
    qu’un deuxième massif est mesuré. Un score de 100 signifie « au
    plafond du calibrage actuel », pas « diversité maximale ».

4.  **Sans entrée spectrale, B4 vaut `NA`** — pas 0. Ni `spectral` ni
    `reflectance` fournis : la colonne est remplie de `NA` sans erreur.

## 5. Aval

    indicateur_b4_div_spectrale()  ->  colonne B4 (Shannon)
          |
          +- normalize_indicator()     -> H / log(10) x 100
          +- create_family_index("B")  -> famille_biodiversite = moy(B1, B2, B3, B4)

> B4 pesant un quart de `famille_biodiversite`, l’interdit de
> comparaison **remonte à la famille** : un `famille_biodiversite` n’est
> pas plus comparable entre projets que le B4 qu’il contient.

Le calcul partage son objet `spectral` avec **L3** (diversité β) :
appeler
[`compute_spectral_diversity()`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
une fois et passer le résultat aux deux indicateurs, plutôt que de le
recalculer.

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBCNCA6IGJpb2Rpdk1hcFIgY2xhc3NlIGxlcyBwaXhlbHMgU2VudGluZWwtMiBlbiBlc3BlY2VzIHNwZWN0cmFsZXMsIGxldXIgZGl2ZXJzaXRlIGRlIFNoYW5ub24gZXN0IGNhbGN1bGVlIHBhciBmZW5ldHJlIGRlIDEwMCBtIHB1aXMgbW95ZW5uZWUgc3VyIGwmIzM5O3VuaXRlLCBldCBub3JtYWxpc2VlIHBhciB1biBwbGFmb25kIGNvbnZlbnRpb25uZWwgZGUgZGl4IGVzcGVjZXMgZWZmZWN0aXZlcyA7IHNhbnMgZW50cmVlIHNwZWN0cmFsZSwgQjQgdmF1dCBOQSBldCBub24gMC4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCDDiVRBUEVTClNVQ0NFU1NJVkVTPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+U2VudGluZWwtMgrigJQgb2JqZXQgc3BlY3RyYWw8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y29tcHV0ZV9zcGVjdHJhbF9kaXZlcnNpdHkoKTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5wYXJ0YWfDqQphdmVjIEwzIChkaXZlcnNpdMOpIM6yKTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxMDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5BdWN1bmUKZW50csOpZSBzcGVjdHJhbGU8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE0MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkI0Cj0gTkEsIGphbWFpcyAwPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMzQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+RXNww6hjZXMKc3BlY3RyYWxlczwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmJpb2Rpdk1hcFIsCmstbWVhbnM8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zdXIKbGVzIHBpeGVscyBTMjwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjEyNiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+U2hhbm5vbgpwYXIgZmVuw6p0cmUgMTAwIG08L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNjEiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+SApkZSBsZXVyIGRpc3RyaWJ1dGlvbjwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjIwMiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMjIxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+TW95ZW5uZQpkZXMgZmVuw6p0cmVzPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjM3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPi5hZ2dyZWdhdGVfZGl2ZXJzaXR5KCk8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl9iNF9kaXZfc3BlY3RyYWxlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+aW5kaWNlCmRlIFNoYW5ub248L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkgKLyBsb2coMTApIMOXIDEwMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE2MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxC4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX2Jpb2RpdmVyc2l0ZTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIEIxIMOgIEI0PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxsaW5lIHgxPSIyNjAiIHkxPSI2MyIgeDI9IjI4MiIgeTI9IjYzIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48cGF0aCBkPSJNMjYwIDEyNyBIMjcxIFYxNDcgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI5NCIgeDI9IjMwNiIgeTI9IjEyMCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIxMTAiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnB1aXM8L3RleHQ+PGxpbmUgeDE9IjMwNiIgeTE9IjE3MCIgeDI9IjMwNiIgeTI9IjE5NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIxODYiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnB1aXM8L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE0NyIgeDI9IjU2NiIgeTI9IjE0NyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMjIzIiB4Mj0iNTY2IiB5Mj0iMjIzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjIyMyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTQyIiB4Mj0iNjk5IiB5Mj0iMTU2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjIyIiB4Mj0iNjk5IiB5Mj0iMjM2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzEwIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5QbGFmb25kCj0gMTAgZXNww6hjZXMgc3BlY3RyYWxlcyBlZmZlY3RpdmVzLCBleHAoSCkg4oCUIHZhbGV1ciBwcm92aXNvaXJlLCBzcGVjCjAyOC48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TmkKY29tcGFyYWJsZSBlbnRyZSBwcm9qZXRzLCBuaSBkYW5zIGxlIHRlbXBzIDsgbOKAmWludGVyZGl0IHJlbW9udGUgw6AKZmFtaWxsZV9iaW9kaXZlcnNpdGUuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlVuCnBldXBsZW1lbnQgbW9ub3Nww6ljaWZpcXVlIGzDqWdpdGltZSBvYnRpZW50IHVuIHNjb3JlIGJhcyA6IGNlIG7igJllc3QgcGFzCnVuIGTDqWZhdXQuPC90ZXh0Pjwvc3ZnPg==)

Une chaîne à trois étages dont la dernière marche est conventionnelle.
Le plafond de dix espèces effectives fixe l’échelle du score : c’est
lui, et non la mesure, qui rend deux projets incomparables.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction B4 | `R/spectral_diversity.R:312` |
| Plafond de normalisation | `.B4_MAX_SPECTRAL_SPECIES` — `R/spectral_diversity.R:23` |
| Règle de normalisation | `R/normalization.R:694-707` |
| Indicateur jumeau (β) | [`indicateur_l3_het_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_l3_het_spectrale.md) |
| Spécification | `specs/028-diversite-spectrale/` |
| Écart ouvert vers l’app | `PLAN.md`, table des écarts, ligne 7 |
