# Fiche indicateur B2 - Diversite structurale

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `B2` |
| Nom long / colonne | `indicateur_b2_structure` |
| Famille | **B — Biodiversité** |
| Grandeur mesurée | Hétérogénéité verticale et horizontale du peuplement |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable (plus hétérogène) |
| Normalisation | **native 0–100**, simple écrêtage |
| Fonction | [`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md) — `R/indicators-biodiversity.R:302` |

## 2. Quatre chemins, servis en cascade

Comme C1, B2 essaie ses entrées dans un ordre fixe ; le premier chemin
servi gagne. Le déclencheur du chemin principal est la présence
**simultanée** des colonnes `strata` et `age_class`.

| Ordre | Chemin | Condition | Formule |
|----|----|----|----|
| — | **Shannon terrain** | colonnes `strata` **et** `age_class` | Shannon pondéré strates 0,4 / âges 0,3 / essences 0,3 |
| 0 | **CHM direct** | argument `chm` fourni | `min(CV / 0,4 ; 1) × 100` |
| 1 | **MNH LiDAR** | couche `lidar_mnh` | `min(σ_hauteur / 10 ; 1) × 100` |
| 2 | **NDVI** | couche `ndvi` | `min(CV_NDVI / 0,4 ; 1) × 100` |
| — | *aucun* | — | `NA` + avertissement |

**Composante CHM additive.** Quand `chm` est fourni **et** que le chemin
Shannon terrain s’applique, le CV du CHM entre comme composante additive
de poids `cv_chm_weight` (défaut **0,20**) — il ne remplace pas le
Shannon, il le corrige.

### Les trois proxys, et ce qu’ils mesurent vraiment

    CV(CHM)   = ecart-type(hauteurs) / moyenne(hauteurs)     >= 10 pixels valides
    score     = min(CV / 0,4 ; 1) x 100                      CV 0,4 = plafond « futaie melangee mure »

    sigma(MNH) = ecart-type des hauteurs sur l'unite
    score      = min(sigma / 10 ; 1) x 100                   futaie reguliere ~ 2-4 m, melangee mure ~ 8-12 m

    CV(NDVI)  = ecart-type(NDVI) / moyenne(NDVI)
    score     = min(CV / 0,4 ; 1) x 100

**Exemples chiffrés** :

| Peuplement                    | Chemin     | Mesure    | B2       |
|-------------------------------|------------|-----------|----------|
| Plantation régulière d’épicéa | MNH LiDAR  | σ = 2,5 m | **25,0** |
| Futaie feuillue irrégulière   | MNH LiDAR  | σ = 9,0 m | **90,0** |
| Futaie jardinée, CHM FORMS-T  | CHM direct | CV = 0,34 | **85,0** |
| Taillis homogène              | NDVI       | CV = 0,08 | **20,0** |

## 3. Le calcul par niveau NDP

| NDP | Chemin servi | Ce qui change |
|----|----|----|
| **0** | 2 (CV du NDVI) | proxy indirect : le NDVI ne voit pas la **verticale** |
| **0 augmenté** `height_ml` | 0 (CHM FORMS-T / FORMSpoT / Open-Canopy) | première mesure réelle de la structure verticale |
| **1** | 1 (MNH LiDAR HD) | même grandeur, mesurée au lieu d’être prédite |
| **2** | 1 (MNH drone) | résolution centimétrique : les sous-étages apparaissent |
| **3** | Shannon terrain | strates et classes d’âge **relevées**, plus déduites |
| **4** | Shannon + scan 3D | structure complète |

> **La rupture est entre NDP 0 nu et NDP 0 augmenté**, pas entre NDP 0
> et NDP 1. Le CV du NDVI mesure une hétérogénéité **spectrale
> horizontale** et l’appelle structure ; le CHM mesure la **hauteur**.
> Ce sont deux grandeurs différentes portant le même nom de colonne.
> Brancher un CHM public change la nature de B2, pas seulement sa
> précision.

## 4. Quatre pièges

1.  **Deux échelles pour le CHM, deux plafonds différents.** Le chemin
    CHM normalise par `CV = 0,4` et le chemin MNH LiDAR par `σ = 10 m`.
    Ce sont des grandeurs distinctes (l’une sans dimension, l’autre en
    mètres) : **les scores B2 d’un projet CHM et d’un projet LiDAR ne
    sont pas directement comparables**, même à structure identique.
2.  **Le CV exige au moins 10 pixels valides** par unité, sinon `NA`.
    Sur des unités petites croisées avec un CHM à 30 m, une part des
    unités sort `NA` sans que rien de visible ne le signale au niveau de
    la famille.
3.  **Le CV du NDVI plafonne aussi à 0,4**, valeur reprise du chemin
    CHM. Rien n’indique qu’un CV de NDVI de 0,4 corresponde à la même
    richesse structurale qu’un CV de hauteurs de 0,4. C’est un plafond
    emprunté, pas calibré.
4.  **`species_field` est optionnel et vaut `NULL` par défaut.** Le
    poids 0,3 nominalement dévolu aux essences ne s’applique donc que si
    l’appelant nomme explicitement la colonne. Sans cela, le Shannon ne
    porte que sur strates et âges — et les poids ne sont pas
    renormalisés.

## 5. Aval

    indicateur_b2_structure()  ->  colonne B2 (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("B")  -> famille_biodiversite = moy(B1, B2, B3, B4)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDQ3MiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBCMiA6IHF1YXRyZSBjaGVtaW5zIGVzc2F5ZXMgZW4gY2FzY2FkZSDigJQgU2hhbm5vbiB0ZXJyYWluLCBDSE0sIE1OSCBMaURBUiwgTkRWSSDigJQgcHJvZHVpc2VudCBsYSBtZW1lIGNvbG9ubmUgZGUgc3RydWN0dXJlLCBhbG9ycyBxdSYjMzk7aWxzIG1lc3VyZW50IGRlcyBncmFuZGV1cnMgZGlmZmVyZW50ZXMgYXZlYyBkZXMgcGxhZm9uZHMgZGlmZmVyZW50cyA7IHNhbnMgYXVjdW5lIGVudHJlZSwgQjIgcmVuZCBOQSBldCB1biBhdmVydGlzc2VtZW50LiI+PGRlZnM+PG1hcmtlciBpZD0iZmQiIHZpZXdib3g9IjAgMCAxMCAxMCIgcmVmeD0iOSIgcmVmeT0iNSIgbWFya2Vyd2lkdGg9IjYiIG1hcmtlcmhlaWdodD0iNiIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPjxwYXRoIGQ9Ik0wLDAgTDEwLDUgTDAsMTAgeiIgZmlsbD0iY3VycmVudENvbG9yIiAvPjwvbWFya2VyPjwvZGVmcz48ZyBmaWxsPSJjdXJyZW50Q29sb3IiIGZvbnQtc2l6ZT0iMTAiIGxldHRlci1zcGFjaW5nPSIxLjMiIG9wYWNpdHk9Ii41NSI+PHRleHQgeD0iMTAiIHk9IjE2Ij5FTlRSw4lFUzwvdGV4dD48dGV4dCB4PSIyOTAiIHk9IjE2Ij5DQUxDVUwg4oCUIFBSRU1JRVIKQ0hFTUlOIFNFUlZJPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q29sb25uZXMKc3RyYXRhICsgYWdlX2NsYXNzPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnJlbGV2w6kKdGVycmFpbiAoTkRQIDMrKTwvdGV4dD48cmVjdCB4PSI4IiB5PSI5MCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxMDkiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5DSE0KTUwgKGFyZ3VtZW50IGNobSk8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZPUk1TLVQsCkZPUk1TcG9ULCBPcGVuLUNhbm9weTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxNDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTY1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q291Y2hlCmxpZGFyX21uaDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTgxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+TGlEQVIKSEQgb3UgZHJvbmU8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMjAyIiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjIyMSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNvdWNoZQpuZHZpPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIyMzciIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5TZW50aW5lbC0yLAoxMCBtPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjI1OCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMjAiIHk9IjI3NyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkF1Y3VuZQpkZXMgcXVhdHJlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIyOTMiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5OQQorIGF2ZXJ0aXNzZW1lbnQ8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5TaGFubm9uCnRlcnJhaW48L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zdHJhdGVzCjAsNCDCtyDDomdlcyAwLDM8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5lc3NlbmNlcwowLDM8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIxMjYiIHdpZHRoPSIyNjIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjE0NSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNITQpkaXJlY3Q8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNjEiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bWluKENWCi8gMCw0IDsgMSkgw5cgMTAwPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMjAyIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIyMjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5NTkgKTGlEQVI8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIyMzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bWluKM+DX2gKLyAxMCA7IDEpIMOXIDEwMDwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjI3OCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMjk3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q1YKZHUgTkRWSTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjMxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5taW4oQ1YKLyAwLDQgOyAxKSDDlyAxMDA8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNTQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjMwMCIgeT0iMzczIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+TkE8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIzODkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YXVjdW5lCnZhbGV1ciBmYWJyaXF1w6llPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfYjJfc3RydWN0dXJlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2NvcmUKMOKAkzEwMCwgbmF0aWY8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOpY3LDqnRhZ2UKbmF0aWYgMOKAkzEwMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE2MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxC4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX2Jpb2RpdmVyc2l0ZTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIEIxIMOgIEI0PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxwYXRoIGQ9Ik0yNjAgNTUgSDI3MSBWNjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTExIEgyNzEgVjE0NyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxNjcgSDI3MSBWMjIzIEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDIyMyBIMjcxIFYyOTkgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMjc5IEgyNzEgVjM3NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijk0IiB4Mj0iMzA2IiB5Mj0iMTIwIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iMyAzIiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMTEwIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5zaW5vbjwvdGV4dD48bGluZSB4MT0iMzA2IiB5MT0iMTcwIiB4Mj0iMzA2IiB5Mj0iMTk2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iMyAzIiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMTg2IiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5zaW5vbjwvdGV4dD48bGluZSB4MT0iMzA2IiB5MT0iMjQ2IiB4Mj0iMzA2IiB5Mj0iMjcyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iMyAzIiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMjYyIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5zaW5vbjwvdGV4dD48bGluZSB4MT0iMzA2IiB5MT0iMzIyIiB4Mj0iMzA2IiB5Mj0iMzQ4IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iMyAzIiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMzM4IiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5zaW5vbjwvdGV4dD48bGluZSB4MT0iNTUwIiB5MT0iNjMiIHgyPSI1NjYiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMTQ3IiB4Mj0iNTY2IiB5Mj0iMTQ3IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIyMjMiIHgyPSI1NjYiIHkyPSIyMjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjI5OSIgeDI9IjU2NiIgeTI9IjI5OSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMzc1IiB4Mj0iNTY2IiB5Mj0iMzc1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjM3NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTQyIiB4Mj0iNjk5IiB5Mj0iMTU2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjIyIiB4Mj0iNjk5IiB5Mj0iMjM2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iNDIyIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5jaG0KZm91cm5pIEVUIFNoYW5ub24gc2VydmkgOiBsZSBDViBkdSBDSE0gZW50cmUgZW4gY29tcG9zYW50ZSBhZGRpdGl2ZQooY3ZfY2htX3dlaWdodCA9IDAsMjApLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iNDM4IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5EZXV4CnBsYWZvbmRzIGRpc3RpbmN0cyDigJQgQ1YgMCw0IHNhbnMgZGltZW5zaW9uLCDPgyAxMCBtIGVuIG3DqHRyZXMgOiBsZXMKc2NvcmVzIG5lIHNlIGNvbXBhcmVudCBwYXMuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSI0NTQiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlCmNoZW1pbiBORFZJIG1lc3VyZSB1bmUgaMOpdMOpcm9nw6luw6lpdMOpIGhvcml6b250YWxlIGV0IGzigJlhcHBlbGxlIHN0cnVjdHVyZQp2ZXJ0aWNhbGUuPC90ZXh0Pjwvc3ZnPg==)

Une colonne, quatre grandeurs. La rupture utile n’est pas NDP 0 → 1 mais
NDP 0 nu → NDP 0 augmenté : brancher un CHM public fait passer B2 d’un
proxy spectral horizontal à une mesure de hauteur.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction B2 | `R/indicators-biodiversity.R:302-460` |
| Sources CHM déclarées | `inst/datasources/FR.json` — `forms_t`, `formspot`, `s2_biophysical` (CV du LAI) |
| Nettoyage du CHM | [`sanitize_chm()`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md) — `R/utils-chm.R:109` |
| Fiche de l’autre consommateur du CHM | [`vignette("fiche-c1-biomasse_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.md) |
