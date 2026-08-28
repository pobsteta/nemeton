# Fiche indicateur R5 - Deperissement (FORDEAD / RECONFORT)

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** : calculé seulement si un pipeline
> sanitaire a tourné (spec 008, ADR-013).

> ### Le sens de la famille R, corrigé en 0.181.0
>
> **R1 à R5 sont orientés « haut = mauvais » à l’état brut** et sont
> **inversés** à la normalisation (`score = 100 − valeur`). **R6 et R7
> ne le sont pas** — ils sont déjà « haut = bon » à la source. Jusqu’à
> 0.181.0, seul R5 était inversé, si bien qu’il pointait à l’opposé des
> quatre autres dans sa propre famille et qu’une UGF très exposée
> obtenait un `famille_risque` flatteur (spec 048).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `R5` |
| Nom long / colonne | `indicateur_r5_deperissement` |
| Famille | **R — Risques & Résilience** |
| Grandeur mesurée | Intensité du dépérissement détecté sur l’unité |
| Unité brute | **0–100, haut = fort dépérissement** |
| Sens | **inversé** |
| Fonction | [`indicateur_r5_deperissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md) — `R/indicators-deperissement.R:72` |
| Colonne annexe | `r5_status` |
| Applicabilité | [`r5_applicabilite()`](https://pobsteta.github.io/nemeton/reference/r5_applicabilite.md) |

## 2. Le calcul

    Pour chaque UGF :
      fraction_resineux (ou feuillus) >= min_*  ?  sinon  R5 = NA, status = skipped_no_resineux
      intersection des centroides de clusters d'alerte avec l'UGF
      R5 = somme( poids[classe] x aire_cluster / surface_UGF )  plafonnee a 1, x 100

Deux pipelines alimentent R5 :

| Pipeline | Cible | Poids de confiance |
|----|----|----|
| **FORDEAD** (CRSWIR + harmonique) | résineux — épicéa, sapin pectiné | `FORDEAD_CONFIDENCE_WEIGHTS` = 0,10 / 0,30 / **0,82** / 0,70 |
| **RECONFORT** | feuillus (chêne…) | `RECONFORT_CONFIDENCE_WEIGHTS` |

Seuils par défaut : `min_resineux = min_feuillus = 0,3`.

### Le garde-fou G1, activé par défaut

`include_low_classes = FALSE` : **seules les classes `3-forte` et
`4-sol-nu` sont comptées**. Les classes `1-faible` et `2-moyenne` sont
écartées parce que le rapport ONF/DSF 2024 (Bernard & Doridant, 397
relevés terrain) y mesure **50 % et un tiers de faux positifs**. Les
pondérations 0,10 / 0,30 / 0,82 / 0,70 sont directement calibrées sur ce
rapport.

**Statuts possibles** : `calculated`, `skipped_no_resineux`,
`skipped_no_fordead`.

## 3. Le calcul par niveau NDP

| NDP | Ce qui existe | R5 |
|----|----|----|
| **0** sans pipeline | rien | **`NA`** |
| **0** + FORDEAD / RECONFORT | Sentinel-2, séries temporelles | **calculé** |
| **1–2** | — | inchangé : le signal est spectral |
| **3** | **validation QField** (garde-fou G4) | les alertes sont confirmées ou infirmées sur le terrain |
| **4** | — | — |

## 4. Quatre pièges

1.  **Détection précoce médiocre**, mesurée : **60 % des stades précoces
    sont ratés** (rapport ONF/DSF 2024). Un R5 favorable ne dit pas
    qu’il n’y a pas de dépérissement — il dit qu’aucune anomalie franche
    n’a été détectée.
2.  **Confusion avec la perturbation mécanique** : 25 à 41 % selon
    l’altération.
    [`classify_disturbance()`](https://pobsteta.github.io/nemeton/reference/classify_disturbance.md)
    (garde-fou G2) croise FORDEAD et la fenêtre rolling-window pour
    trancher `mechanical` / `progressive` / `recent_event`.
3.  **`NA` ne veut pas dire « sain ».** Trois causes distinctes se
    cachent derrière : pas de pipeline, pas assez de résineux (ou de
    feuillus), pas d’alertes. **Toujours lire `r5_status` avant de
    conclure.**
4.  **Le seuil de 30 % d’essence cible exclut les peuplements
    mélangés.** Une futaie à 25 % d’épicéa dépérissant sort
    `skipped_no_resineux`, donc `NA`.

## 5. Aval

    indicateur_r5_deperissement()  ->  colonnes R5 (0-100, haut = deperissement) et r5_status
          |
          +- normalize_indicator()     -> 100 - valeur
          +- create_family_index("R")  -> famille_risque

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM5MiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBSNSA6IGRldXggcGlwZWxpbmVzIGRlIGRldGVjdGlvbiDigJQgRk9SREVBRCBwb3VyIGxlcyByZXNpbmV1eCwgUkVDT05GT1JUIHBvdXIgbGVzIGZldWlsbHVzIOKAlCBsaXZyZW50IGRlcyBjbHVzdGVycyBkJiMzOTthbGVydGUgZG9udCBzZXVsZXMgbGVzIGNsYXNzZXMgZm9ydGVzIHNvbnQgcmV0ZW51ZXMsIHBvbmRlcmVlcyBwYXIgbGEgY29uZmlhbmNlIGNhbGlicmVlIHN1ciBsZSByYXBwb3J0IE9ORi9EU0YgMjAyNCwgcHVpcyByYXBwb3J0ZWVzIGEgbGEgc3VyZmFjZSBkZSBsJiMzOTtVR0YuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgw4lUQVBFUwpTVUNDRVNTSVZFUzwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkZPUkRFQUQK4oCUIHLDqXNpbmV1eDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5DUlNXSVIKKyBtb2TDqGxlIGhhcm1vbmlxdWU8L3RleHQ+PHRleHQgeD0iMjAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+w6lwaWPDqWEsCnNhcGluIHBlY3RpbsOpPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjEwNiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5SRUNPTkZPUlQK4oCUIGZldWlsbHVzPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxNDEiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jaMOqbmUKZXQgYXV0cmVzIGZldWlsbHVzPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE2MiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkZyYWN0aW9uCmTigJllc3NlbmNlIGNpYmxlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5taW5fcmVzaW5ldXgKPSBtaW5fZmV1aWxsdXMgPSAwLDM8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNpbm9uCnNraXBwZWRfbm9fcmVzaW5ldXg8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5HYXJkZS1mb3UKRzE8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5pbmNsdWRlX2xvd19jbGFzc2VzCj0gRkFMU0U8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zZXVsZXMKMy1mb3J0ZSBldCA0LXNvbC1udTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjEyNiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+SW50ZXJzZWN0aW9uCmRlcyBjbHVzdGVyczwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jZW50cm/Dr2RlcwrDlyBVR0Y8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIyMDIiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjIyMSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlNvbW1lCnBvbmTDqXLDqWU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIyMzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+zqMKcG9pZHMgw5cgYWlyZSAvIHN1cmZhY2UgVUdGPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjUzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnBsYWZvbm7DqQrDoCAxLCDDlyAxMDA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl9yNV9kZXBlcmlzc2VtZW50PC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YnJ1dAo6IGhhdXQgPSBkw6lww6lyaXNzZW1lbnQ8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNjb3JlCj0gMTAwIC0gdmFsZXVyPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTQ5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlIxCsOgIFI1IChzcGVjIDA0OCk8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNzgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcUuKAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9yaXNxdWU8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpkZSBSMSDDoCBSNzwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjI1OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMjc3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y29tcHV0ZV9nZW5lcmFsX2luZGV4KCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyOTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Rmlib25hY2NpCsK3IGNvbmZpYW5jZSDPhjwvdGV4dD48bGluZSB4MT0iMjYwIiB5MT0iNjMiIHgyPSIyODIiIHkyPSI2MyIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHBhdGggZD0iTTI2MCAxMjcgSDI3MSBWMTQ3IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDE5MSBIMjcxIFYyMzEgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI5NCIgeDI9IjMwNiIgeTI9IjEyMCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIxMTAiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnB1aXM8L3RleHQ+PGxpbmUgeDE9IjMwNiIgeTE9IjE3MCIgeDI9IjMwNiIgeTI9IjE5NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIxODYiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnB1aXM8L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE0NyIgeDI9IjU2NiIgeTI9IjE0NyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMjMxIiB4Mj0iNTY2IiB5Mj0iMjMxIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjIzMSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTU4IiB4Mj0iNjk5IiB5Mj0iMTcyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjM4IiB4Mj0iNjk5IiB5Mj0iMjUyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzI2IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5Qb2lkcwowLDEwIC8gMCwzMCAvIDAsODIgLyAwLDcwIDogY2FsaWJyw6lzIHN1ciAzOTcgcmVsZXbDqXMgdGVycmFpbiAoT05GL0RTRgoyMDI0KSwgcGFzIGNob2lzaXMuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkTDqXRlY3Rpb24KcHLDqWNvY2UgbcOpZGlvY3JlIOKAlCA2MCAlIGRlcyBzdGFkZXMgcHLDqWNvY2VzIG1hbnF1w6lzIDsgY29uZnVzaW9uCm3DqWNhbmlxdWUgZGUgMjUgw6AgNDEgJS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM1OCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TkEKbmUgdmV1dCBwYXMgZGlyZSBzYWluIDogdHJvaXMgY2F1c2VzIGRpc3RpbmN0ZXMgc2UgY2FjaGVudCBkZXJyacOocmUKKHI1X3N0YXR1cyBsZXMgZGlzdGluZ3VlKS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM3NCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGUKc2V1aWwgZGUgMzAgJSBk4oCZZXNzZW5jZSBjaWJsZSBleGNsdXQgbGVzIHBldXBsZW1lbnRzIG3DqWxhbmfDqXMgZHUKY2FsY3VsLjwvdGV4dD48L3N2Zz4=)

Une chaîne dont chaque maille est calibrée sur du terrain. Le garde-fou
G1 écarte les deux classes faibles parce qu’elles portent la moitié des
faux positifs — c’est un choix de justesse, payé en sensibilité.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R5 | `R/indicators-deperissement.R:72` |
| Pipelines | [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md), [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md) |
| Garde-fous G1/G2 | [`list_alerts()`](https://pobsteta.github.io/nemeton/reference/list_alerts.md), [`classify_disturbance()`](https://pobsteta.github.io/nemeton/reference/classify_disturbance.md) |
| Validation terrain G4 | [`generate_health_validation_plots()`](https://pobsteta.github.io/nemeton/reference/generate_health_validation_plots.md), [`ingest_health_validation()`](https://pobsteta.github.io/nemeton/reference/ingest_health_validation.md) |
| Validité géographique | [`check_fordead_validity()`](https://pobsteta.github.io/nemeton/reference/check_fordead_validity.md), [`check_reconfort_validity()`](https://pobsteta.github.io/nemeton/reference/check_reconfort_validity.md) |
| Spécification | `specs/008-suivi-sanitaire/`, ADR-013 |
