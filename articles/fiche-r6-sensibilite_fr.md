# Fiche indicateur R6 - Sensibilite microclimatique

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** à la chaîne microclimat (spec 027 L2,
> ADR-014). **Non inversé**, contrairement à R1–R5.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `R6` |
| Nom long / colonne | `indicateur_r6_sensibilite` |
| Famille | **R — Risques & Résilience** |
| Grandeur mesurée | Écart de stress thermique entre une année **caniculaire** et une année **moyenne**, canopée figée |
| Unité brute | **0–100, haut = peu sensible = résilient** |
| Sens | **non inversé** — passthrough écrêté |
| Fonction | [`indicateur_r6_sensibilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_r6_sensibilite.md) — `R/indicators-microclimate.R:217` |
| Bornes | `.MICRO_BOUNDS$r6 = c(scale_t = 8, scale_v = 2)` |
| Colonnes annexes | `R6_dtmax` (°C), `R6_dvpd` (kPa), `R6_couverture_pct` |

## 2. Le calcul

    dT   = Tmax_sous_couvert(canicule) - Tmax_sous_couvert(moyenne)     °C
    dVPD = VPD(canicule) - VPD(moyenne)                                  kPa
    R6   = 100 - standardisation(dT / 8, dVPD / 2)                       0-100, decroissant en sensibilite

**La canopée est tenue fixe entre les deux années** : ce qui varie est
le forçage climatique seul. R6 isole donc l’effet du climat, pas celui
d’une coupe.

Les deux années sont choisies par l’appelant — typiquement détectées
automatiquement sur la série estivale E-OBS via
[`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md).

**Exemples chiffrés** :

| Situation                    | ΔT°max | ΔVPD    | R6      |
|------------------------------|--------|---------|---------|
| Couvert fermé, forte inertie | 1,6 °C | 0,3 kPa | **~80** |
| Futaie ordinaire             | 3,2 °C | 0,8 kPa | **~55** |
| Peuplement clair, sol exposé | 5,6 °C | 1,5 kPa | **~27** |

## 3. Le calcul par niveau NDP

Comme A3, A4 et W4 : `NA` sans chaîne microclimat ; calculé dès qu’un
[`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
a tourné **sur deux années**. Le drapeau `microclimate_model` ne relève
pas le niveau NDP.

> **R6 exige deux exécutions du moteur**, une par année. C’est le plus
> coûteux des quatre indicateurs microclimatiques.

## 4. Trois pièges

1.  **R6 n’est pas inversé, et c’est facile à manquer.** Dans une
    famille où R1 à R5 le sont, R6 (et R7) passent en écrêtage simple
    parce qu’ils sont **déjà** orientés « haut = bon ». Le code le
    déclare explicitement dans `.NORMALIZE_RULED` pour que R6 ne retombe
    jamais sur la branche naïve.
2.  **Le piège historique du z-score.** Le score de sensibilité de la
    chaîne reGénération existe en deux versions : `sensibilite` (z-score
    non borné, ≈ \[−4, 4\]) et `sensibilite_score` (0–100). **Injecter
    le z-score dans la normalisation le mutile** — c’est le défaut
    corrigé par la spec 038. Toujours passer `sensibilite_score`.
3.  **Le choix des deux années détermine tout.** Une « année caniculaire
    » mal choisie (été chaud mais pas extrême) écrase l’écart et fait
    paraître toutes les unités résilientes.
    [`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md)
    documente son critère ; le vérifier avant d’interpréter.

## 5. Aval

    indicateur_r6_sensibilite()  ->  colonnes R6, R6_dtmax, R6_dvpd, R6_couverture_pct
          |
          +- normalize_indicator()     -> ecretage [0, 100], PAS d'inversion
          +- create_family_index("R")  -> famille_risque

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM3NiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBSNiA6IGxlIG1lbWUgcGV1cGxlbWVudCBlc3Qgc2ltdWxlIHNvdXMgdW5lIGFubmVlIGNhbmljdWxhaXJlIGV0IHNvdXMgdW5lIGFubmVlIG1veWVubmUsIGNhbm9wZWUgdGVudWUgZml4ZSwgZXQgbCYjMzk7ZWNhcnQgZGUgdGVtcGVyYXR1cmUgZXQgZGUgZGVmaWNpdCBkZSB2YXBldXIgbWVzdXJlIHNhIHNlbnNpYmlsaXRlIDsgY29udHJhaXJlbWVudCBhIFIxLVI1LCBsZSBzY29yZSBuJiMzOTtlc3QgcGFzIGludmVyc2UuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgw4lUQVBFUwpTVUNDRVNTSVZFUzwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm1pY3JvY2xpbWF0ZV9ydW4oKQrDlzI8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YW5uw6llCmNhbmljdWxhaXJlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmFubsOpZQptb3llbm5lLCBjYW5vcMOpZSBmaWfDqWU8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTA2IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm1pY3JvY2xpbWF0ZV9kZXRlY3RfeWVhcnMoKTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTQxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YW5uw6llcwpjaG9pc2llcyBzdXIgbGEgc8OpcmllIEUtT0JTPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE2MiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNoYcOubmUKbWljcm9jbGltYXQgbm9uIGxhbmPDqWU8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlI2Cj0gTkE8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5EZXV4CsOpY2FydHM8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5kVAo9IFRtYXgoY2FuLikgLSBUbWF4KG1veS4pPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZFZQRAo9IFZQRChjYW4uKSAtIFZQRChtb3kuKTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjEyNiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+U3RhbmRhcmRpc2F0aW9uPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmRUCi8gOCBldCBkVlBEIC8gMjwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5SNgo9IDEwMCAtIHN0YW5kYXJkaXNhdGlvbjwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjM0IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0iIzJDNkI2MDBGIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuOTUiIC8+PHRleHQgeD0iNTk4IiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjMkM2QjYwIj5pbmRpY2F0ZXVyX3I2X3NlbnNpYmlsaXRlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+aGF1dAo9IHBldSBzZW5zaWJsZTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+cGFzc3Rocm91Z2gKw6ljcsOqdMOpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTQ5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlBBUwpk4oCZaW52ZXJzaW9uLCBjb250cmEgUjHigJNSNTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE3OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTk3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxS4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX3Jpc3F1ZTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIyOSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIFIxIMOgIFI3PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjU4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNzciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI5MyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxsaW5lIHgxPSIyNjAiIHkxPSI2MyIgeDI9IjI4MiIgeTI9IjYzIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48cGF0aCBkPSJNMjYwIDEyNyBIMjcxIFYxNTUgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTgzIEgyNzEgVjE1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijk0IiB4Mj0iMzA2IiB5Mj0iMTIwIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjExMCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+cHVpczwvdGV4dD48bGluZSB4MT0iNTUwIiB5MT0iNjMiIHgyPSI1NjYiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMTU1IiB4Mj0iNTY2IiB5Mj0iMTU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjE1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTU4IiB4Mj0iNjk5IiB5Mj0iMTcyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjM4IiB4Mj0iNjk5IiB5Mj0iMjUyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzI2IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5SNgpu4oCZZXN0IHBhcyBpbnZlcnPDqSBhbG9ycyBxdWUgUjEgw6AgUjUgbGUgc29udCA6IGlsIGVzdCBkw6lqw6Agb3JpZW50w6kgwqsgaGF1dAo9IGJvbiDCuyDDoCBsYSBzb3VyY2UuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlBpw6hnZQpoaXN0b3JpcXVlIDogY+KAmWVzdCBsZSBzZW5zaWJpbGl0ZV9zY29yZSAw4oCTMTAwIHF14oCZaWwgZmF1dCBpbmplY3RlciwKamFtYWlzIGxlIHotc2NvcmUgZGUgcmVHw6luw6lyYXRpb24gKHNwZWMgMDM4KS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM1OCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGUKY2hvaXggZGVzIGRldXggYW5uw6llcyBkw6l0ZXJtaW5lIHRvdXQgOiB1bmUgwqsgY2FuaWN1bGFpcmUgwrsgbWFsIGNob2lzaWUKYXBsYXRpdCBs4oCZw6ljYXJ0LjwvdGV4dD48L3N2Zz4=)

Une différence entre deux simulations, pas un état. La canopée est tenue
fixe pour que l’écart mesure le climat seul — ce que R6 dit, c’est ce
que le peuplement encaisserait, pas ce qu’il a subi.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R6 | `R/indicators-microclimate.R:217` |
| Détection des années | [`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md), [`tendances_estivales_eobs()`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md) |
| Normalisation | `R/normalization.R`, branche R6 (spec 038) |
| Spécification | `specs/027-regeneration-microclimat/` L2, ADR-014 |
