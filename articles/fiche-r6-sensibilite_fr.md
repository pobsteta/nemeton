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
run `microclimf` est fourni **sur deux années**. Le drapeau
`microclimate_model` ne relève pas le niveau NDP.

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

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM3NiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBSNiA6IGxlIG1lbWUgcGV1cGxlbWVudCBlc3Qgc2ltdWxlIHNvdXMgdW5lIGFubmVlIGNhbmljdWxhaXJlIGV0IHNvdXMgdW5lIGFubmVlIG1veWVubmUsIGNhbm9wZWUgdGVudWUgZml4ZSwgZXQgbCYjMzk7ZWNhcnQgZGUgdGVtcGVyYXR1cmUgZXQgZGUgZGVmaWNpdCBkZSB2YXBldXIgbWVzdXJlIHNhIHNlbnNpYmlsaXRlIDsgY29udHJhaXJlbWVudCBhIFIxLVI1LCBsZSBzY29yZSBuJiMzOTtlc3QgcGFzIGludmVyc2UuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgw4lUQVBFUwpTVUNDRVNTSVZFUzwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPnJ1bgptaWNyb2NsaW1mIMOXMjwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5hbm7DqWUKY2FuaWN1bGFpcmU8L3RleHQ+PHRleHQgeD0iMjAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YW5uw6llCm1veWVubmUsIGNhbm9ww6llIGZpZ8OpZTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxMDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTI1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bWljcm9jbGltYXRlX2RldGVjdF95ZWFycygpPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxNDEiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5hbm7DqWVzCmNob2lzaWVzIHN1ciBsYSBzw6lyaWUgRS1PQlM8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTYyIiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgLz48dGV4dCB4PSIyMCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q2hhw65uZQptaWNyb2NsaW1hdCBub24gbGFuY8OpZTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+UjYKPSBOQTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkRldXgKw6ljYXJ0czwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmRUCj0gVG1heChjYW4uKSAtIFRtYXgobW95Lik8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5kVlBECj0gVlBEKGNhbi4pIC0gVlBEKG1veS4pPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTI2IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5TdGFuZGFyZGlzYXRpb248L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNjEiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZFQKLyA4IGV0IGRWUEQgLyAyPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlI2Cj0gMTAwIC0gc3RhbmRhcmRpc2F0aW9uPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfcjZfc2Vuc2liaWxpdGU8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5oYXV0Cj0gcGV1IHNlbnNpYmxlPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5wYXNzdGhyb3VnaArDqWNyw6p0w6k8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxNDkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+UEFTCmTigJlpbnZlcnNpb24sIGNvbnRyYSBSMeKAk1I1PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMTc4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnFLigJ0pPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZhbWlsbGVfcmlzcXVlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjI5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgUjEgw6AgUjc8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjkzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PGxpbmUgeDE9IjI2MCIgeTE9IjYzIiB4Mj0iMjgyIiB5Mj0iNjMiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxwYXRoIGQ9Ik0yNjAgMTI3IEgyNzEgVjE1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxODMgSDI3MSBWMTU1IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48bGluZSB4MT0iMzA2IiB5MT0iOTQiIHgyPSIzMDYiIHkyPSIxMjAiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMTEwIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxNTUiIHgyPSI1NjYiIHkyPSIxNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iMTU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU4MCIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNTgiIHgyPSI2OTkiIHkyPSIxNzIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMzgiIHgyPSI2OTkiIHkyPSIyNTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlI2Cm7igJllc3QgcGFzIGludmVyc8OpIGFsb3JzIHF1ZSBSMSDDoCBSNSBsZSBzb250IDogaWwgZXN0IGTDqWrDoCBvcmllbnTDqSDCqyBoYXV0Cj0gYm9uIMK7IMOgIGxhIHNvdXJjZS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM0MiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+UGnDqGdlCmhpc3RvcmlxdWUgOiBj4oCZZXN0IGxlIHNlbnNpYmlsaXRlX3Njb3JlIDDigJMxMDAgcXXigJlpbCBmYXV0IGluamVjdGVyLApqYW1haXMgbGUgei1zY29yZSBkZSByZUfDqW7DqXJhdGlvbiAoc3BlYyAwMzgpLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzU4IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5MZQpjaG9peCBkZXMgZGV1eCBhbm7DqWVzIGTDqXRlcm1pbmUgdG91dCA6IHVuZSDCqyBjYW5pY3VsYWlyZSDCuyBtYWwgY2hvaXNpZQphcGxhdGl0IGzigJnDqWNhcnQuPC90ZXh0Pjwvc3ZnPg==)

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
