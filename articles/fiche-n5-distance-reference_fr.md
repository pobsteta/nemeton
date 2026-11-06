# Fiche indicateur N5 - Distance a la reference

> **Document de référence** — Néméton (package cœur), 2026-11-05. Spec
> 064. Fonction **expérimentale** : elle peut changer à toute version.
> Voir aussi la fiche commune [Modèles de
> fondation](https://pobsteta.github.io/nemeton/articles/fiche-modeles-de-fondation_fr.md).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `N5` |
| Nom long / colonne | `indicateur_n5_distance_reference` |
| Famille | **N — Naturalité** |
| Grandeur mesurée | Proximité de l’UGF à des forêts de référence peu perturbées, dans l’espace d’un modèle de fondation |
| Unité brute | **score 0–100** (100 = indiscernable de la référence) |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_n5_distance_reference()`](https://pobsteta.github.io/nemeton/reference/indicateur_n5_distance_reference.md) — `R/indicateur_n5_distance_reference.R` |
| Entrées | un **embedding** (SpatRaster, une bande par dimension) **et** une **référence** d’au moins 15 unités |
| Conditionnel | oui : sans embedding, `NA` et `n5_status = "skipped_no_embedding"` |

Colonnes rendues : `N5`, `n5_status`, `n5_source` (`"aef"`),
`n5_reference` (`"defaut"` ou `"utilisateur"`), `n5_annee`,
`n5_distance` (distance brute).

## 2. Le calcul

N1, N2 et N3 mesurent une naturalité **administrative** : éloignement
des routes et du bâti, continuité cartographique. N5 regarde la forêt
elle-même, telle que la voit un modèle de fondation.

1.  **L’embedding.** AlphaEarth Foundations (Google DeepMind, 2025)
    publie chaque année un vecteur de 64 dimensions par pixel de 10 m,
    appris sur Sentinel-1, Sentinel-2, Landsat, GEDI et ERA5. Le paquet
    amont `alphaearthnemeton` le rapatrie (fichiers COG publics, CC-BY
    4.0) ; le cœur ne fait que le lire.
2.  **Le résumé par UGF.**
    [`embedding_summary()`](https://pobsteta.github.io/nemeton/reference/embedding_summary.md)
    calcule la moyenne de chaque dimension, pondérée par la fraction de
    pixel couverte. Une UGF de moins de 10 pixels valides reste `NA`
    (`skipped_no_coverage`).
3.  **La référence.** Par défaut, les UGF couvertes à 50 % au moins par
    le **palier le plus ancien** de `foret_ancienne` **et** dont
    `N1 ≥ 80`. L’utilisateur peut fournir la sienne : réserves
    intégrales, îlots de sénescence, placettes de référence.
4.  **La distance.**
    [`distance_reference()`](https://pobsteta.github.io/nemeton/reference/distance_reference.md)
    : distance de Mahalanobis au centroïde de la référence, avec une
    covariance régularisée par Ledoit-Wolf (2004). Sans régularisation,
    15 unités en 64 dimensions donneraient une covariance non
    inversible.
5.  **Le score.** `N5 = 100 × (1 − F(d))`, où `F` est la distribution
    des distances de chaque unité de référence à la référence construite
    sans elle (*leave-one-out*). Une UGF aussi proche qu’une unité de
    référence typique vaut environ 50 ; une UGF plus lointaine que toute
    la référence vaut 0. Le score dépend de la référence seule, pas des
    autres UGF du projet. L’option `score = "projet"` rend plutôt le
    rang dans le projet, au prix de la comparabilité entre projets.

## 3. Le calcul par niveau NDP

| NDP | Source | Ce qui change |
|----|----|----|
| **0** | AlphaEarth (10 m, annuel) | flag `augmented = "embedding_ml"`, niveau inchangé |
| **1** | \+ LiDAR HD → embedding ForPT (chantier C, à venir) | N5 structurel, `n5_source = "forpt"` |
| **2–4** | — | une référence locale mesurée (placettes) remplace la référence par défaut |

## 4. Cinq pièges

1.  **La référence n’est pas un échantillon aléatoire.** Les forêts
    anciennes et éloignées sont sur-représentées en pente, en altitude
    et sur sols pauvres. N5 mesure donc aussi une distance de
    **station**. Une stratification de la référence par sylvoécorégion
    n’est pas implémentée.
2.  **Circularité avec N1 et N2.** La référence par défaut est choisie
    par N1 et par `foret_ancienne` (la couche de N2) : N5 leur est
    corrélé par construction. Une forte corrélation N1–N5 sur un projet
    ne confirme rien.
3.  **Une distance, pas une cause.** Une UGF loin de la référence n’est
    pas « dégradée » : elle peut être jeune, résineuse, ou sur une autre
    station.
4.  **Une petite référence rend la distance presque euclidienne.** Avec
    15 unités et 64 dimensions, la covariance est dominée par la
    régularisation. Le seuil de 15 est un plancher, pas un confort.
5.  **AlphaEarth est annuel.** Une coupe de l’année *n* n’apparaît que
    dans l’embedding *n* ou *n + 1* ; N5 ne remplace ni FAST, ni
    FORDEAD, ni T2.

N5 n’entre pas dans N3 (spec 064, décision D-5) : la formule de N3 est
stable.

## 5. Aval

    indicateur_n5_distance_reference()  ->  colonne N5 (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("N")  -> famille_naturalite (si N5 non NA)

Sans embedding, N5 vaut `NA` et la famille N est inchangée. Avec un
embedding, la famille N d’un projet recalculé compte un indicateur de
plus.

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBONSA6IGNoYXF1ZSBVR0YgZXN0IHJlc3VtZWUgcGFyIHNvbiBlbWJlZGRpbmcgbW95ZW4gKG1vZGVsZSBkZSBmb25kYXRpb24sIDY0IGRpbWVuc2lvbnMpLCBjb21wYXJlZSBhIHVuZSByZWZlcmVuY2UgZGUgZm9yZXRzIHBldSBwZXJ0dXJiZWVzIHBhciB1bmUgZGlzdGFuY2UgZGUgTWFoYWxhbm9iaXMgcmVndWxhcmlzZWUsIHB1aXMgbm90ZWUgcGFyIHJhcHBvcnQgYSBsYSBkaXNwZXJzaW9uIGRlIGxhIHJlZmVyZW5jZSBlbGxlLW1lbWUgOyBzYW5zIGVtYmVkZGluZyBvdSBzYW5zIHJlZmVyZW5jZSBzdWZmaXNhbnRlLCBOQSBldCB1biBzdGF0dXQuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgw4lUQVBFUwpTVUNDRVNTSVZFUzwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkVtYmVkZGluZwpBbHBoYUVhcnRoPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPjY0CmJhbmRlcywgMTAgbSwgYW5udWVsPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmFscGhhZWFydGhuZW1ldG9uPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjEwNiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Sw6lmw6lyZW5jZQpwYXIgZMOpZmF1dDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTQxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Zm9yZXRfYW5jaWVubmUKcGFsaWVyIG1heDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTU3IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZXQKTjEgJmd0Oz0gODA8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTc4IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgLz48dGV4dCB4PSIyMCIgeT0iMTk3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+UsOpZsOpcmVuY2UKdXRpbGlzYXRldXI8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnLDqXNlcnZlcywKw65sb3RzIChzZik8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgLz48dGV4dCB4PSIyMCIgeT0iMjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Jmx0OwoxNSB1bml0w6lzIG91IHJpZW48L3RleHQ+PHRleHQgeD0iMjAiIHk9IjI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPk41Cj0gTkEgKyBzdGF0dXQ8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5lbWJlZGRpbmdfc3VtbWFyeSgpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpwb25kw6lyw6llIHBhciBVR0Y8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5taW5fcGl4ZWxzCj0gMTA8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIxMjYiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjE0NSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmRpc3RhbmNlX3JlZmVyZW5jZSgpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPk1haGFsYW5vYmlzLApMZWRvaXQtV29sZjwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5MT08KcG91ciBsYSByw6lmw6lyZW5jZTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjIxOCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMzAwIiB5PSIyMzciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5TY29yZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjI1MyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij4xMDAKw5cgKDEg4oiSIEZfcmVmKGQpKTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij7igJxwcm9qZXTigJ0KOiByYW5nLCBlbiBvcHRpb248L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+TjUK4oCUIGRpc3RhbmNlX3JlZmVyZW5jZTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNjb3JlCjDigJMxMDAsIG5hdGlmPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij7DqWNyw6p0YWdlCm5hdGlmIDDigJMxMDA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcTuKAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9uYXR1cmFsaXRlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgTjEgw6AgTjMsIE41PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxsaW5lIHgxPSIyNjAiIHkxPSI2MyIgeDI9IjI4MiIgeTI9IjYzIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48cGF0aCBkPSJNMjYwIDEzNSBIMjcxIFYxNTUgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTk5IEgyNzEgVjI0NyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAyNTUgSDI3MSBWMjQ3IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48bGluZSB4MT0iMzA2IiB5MT0iOTQiIHgyPSIzMDYiIHkyPSIxMjAiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMTEwIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSIzMDYiIHkxPSIxODYiIHgyPSIzMDYiIHkyPSIyMTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMjAyIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxNTUiIHgyPSI1NjYiIHkyPSIxNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjI0NyIgeDI9IjU2NiIgeTI9IjI0NyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1NjYiIHkyPSIyNDciIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTgwIiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE0MiIgeDI9IjY5OSIgeTI9IjE1NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIyMiIgeDI9IjY5OSIgeTI9IjIzNiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjMxMCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGEKcsOpZsOpcmVuY2UgbuKAmWVzdCBwYXMgdW4gdGlyYWdlIGFsw6lhdG9pcmUgOiBwZW50ZSwgYWNjw6hzIGV0IHNvbHMgcGF1dnJlcyB5CnNvbnQgc3VyLXJlcHLDqXNlbnTDqXMuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlLDqWbDqXJlbmNlCnBhciBkw6lmYXV0IGNob2lzaWUgcGFyIE4xIGV0IE4yIDogTjUgbGV1ciBlc3QgY29ycsOpbMOpIHBhcgpjb25zdHJ1Y3Rpb24uPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlVuZQpkaXN0YW5jZSwgcGFzIHVuZSBjYXVzZSA6IHVuZSBVR0YgamV1bmUgb3Ugc3VyIHVuZSBhdXRyZSBzdGF0aW9uIHBldXQKw6p0cmUgbG9pbiBzYW5zIMOqdHJlIGTDqWdyYWTDqWUuPC90ZXh0Pjwvc3ZnPg==)

Une distance dans l’espace d’un modèle, pas une mesure de terrain. N5
dit à quel point une UGF ressemble à la référence — pas pourquoi.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction N5 | `R/indicateur_n5_distance_reference.R` |
| Fonctions génériques | `R/embeddings.R` : [`embedding_summary()`](https://pobsteta.github.io/nemeton/reference/embedding_summary.md), [`distance_reference()`](https://pobsteta.github.io/nemeton/reference/distance_reference.md) |
| Spécification | `specs/064-alphaearth-n5/spec.md` |
| Forêt ancienne | [`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md), fiche N2 |
| Données | Source Cooperative `tge-labs/aef` (index `aef_index.gpkg`), CC-BY 4.0 |

Ledoit O., Wolf M. (2004). *A well-conditioned estimator for
large-dimensional covariance matrices.* Journal of Multivariate Analysis
88(2), 365-411.
