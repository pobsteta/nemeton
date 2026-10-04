# Fiche indicateur T2 - Stabilite temporelle

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `T2` |
| Nom long / colonne | `indicateur_t2_changement` |
| Famille | **T — Dynamique temporelle** |
| Grandeur mesurée | Stabilité du couvert dans le temps |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable (stable) |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_t2_changement()`](https://pobsteta.github.io/nemeton/reference/indicateur_t2_changement.md) — `R/indicators-temporal.R:230` |

## 2. Deux chemins, tous deux empruntés à un autre indicateur

| Ordre | Chemin | Condition | Valeur |
|----|----|----|----|
| 1 | **N2 comme proxy** | colonne `N2`, `N2_anciennete` ou `N2_anciennet` présente | `N2`, écrêté `[0, 100]` |
| 2 | **T1 plafonné** | `t1_values` fourni | `min(100, âge)`, les `NA` restent `NA` |

> **T2 ne mesure rien en propre.** Il recopie N2 (continuité écologique)
> ou T1 (âge). C’est un indicateur **dérivé**, et il faut le savoir
> avant de lire un radar : dans la famille T, T1 et T2 peuvent porter la
> même information sous deux noms, et `famille_temporelle` la compte
> alors deux fois.

**Exemples chiffrés** :

| Situation | Chemin | Entrée | T2 |
|----|----|----|----|
| N2 disponible, continuité forte | 1 | N2 = 82 | **82,0** |
| N2 disponible, forêt récente | 1 | N2 = 25 | **25,0** |
| Pas de N2, peuplement de 70 ans | 2 | T1 = 70 | **70,0** |
| Pas de N2, peuplement de 150 ans | 2 | T1 = 150 | **100,0** |
| Pas de N2, âge inconnu | 2 | T1 = `NA` | **`NA`** (50 fabriqué jusqu’à la 0.211.0) |

## 3. Le calcul par niveau NDP

T2 hérite du NDP de la source qu’il recopie : celui de **N2** si N2 est
présent, celui de **T1** sinon. Il n’a pas de progression propre. Le
chemin réellement temporel — une détection de changement sur séries
Sentinel-2 — **n’est pas implémenté** dans T2 ; il vit ailleurs, dans la
chaîne de suivi sanitaire
([`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md),
[`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md))
et dans **T3**.

## 4. Trois pièges

1.  **`NA` devenait 50 — corrigé à l’audit 1.0.** `t2[is.na(t2)] <- 50`
    sur le chemin 2 attribuait une stabilité moyenne à une unité d’âge
    inconnu, et le dernier recours rendait 50 partout. T2 vaut désormais
    `NA` dans ces deux cas.
2.  **Double comptage dans la famille T.** Quand T2 recopie T1, la même
    grandeur pèse deux tiers de `famille_temporelle` (T1 et T2) au lieu
    d’un tiers.
3.  **Le nom annonce un changement, la valeur mesure une stabilité.** «
    T2 changement » avec « haut = stable » : le sens est inverse de ce
    que le nom suggère, comme pour L2 avant son renommage.

## 5. Aval

    indicateur_t2_changement()  ->  colonne indicateur_t2_changement (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("T")  -> famille_temporelle = moy(T1, T2, T3)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBUMiA6IGwmIzM5O2luZGljYXRldXIgbmUgbWVzdXJlIHJpZW4gZW4gcHJvcHJlLCBpbCByZWNvcGllIGxhIGNvbnRpbnVpdGUgTjIgcXVhbmQgZWxsZSBleGlzdGUsIHNpbm9uIGwmIzM5O2FnZSBUMSBwbGFmb25uZSBhIDEwMCAoYWdlIGluY29ubnUgOiBOQSkg4oCUIGQmIzM5O291IHVuIGRvdWJsZSBjb21wdGFnZSBwb3NzaWJsZSBkYW5zIGxhIGZhbWlsbGUgdGVtcG9yZWxsZS4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCBQUkVNSUVSCkNIRU1JTiBTRVJWSTwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNvbG9ubmUKTjIg4oCUIGNvbnRpbnVpdMOpPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm91Ck4yX2FuY2llbm5ldGUgLyBOMl9hbmNpZW5uZXQ8L3RleHQ+PHJlY3QgeD0iOCIgeT0iOTAiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTA5IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+dDFfdmFsdWVzCuKAlCDDomdlIFQxPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij51dGlsaXPDqQpzZXVsZW1lbnQgc2FucyBOMjwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPk4yCmNvbW1lIHByb3h5PC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+VDIKPSBOMiwgw6ljcsOqdMOpIFswLCAxMDBdPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTEwIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxMjkiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5UMQpwbGFmb25uw6k8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+VDIKPSBtaW4oMTAwLCDDomdlKTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5OQQpjb25zZXJ2w6lzIChwbHVzIGRlIDUwKTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjM0IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0iIzJDNkI2MDBGIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuOTUiIC8+PHRleHQgeD0iNTk4IiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjMkM2QjYwIj5pbmRpY2F0ZXVyX3QyX2NoYW5nZW1lbnQ8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zY29yZQow4oCTMTAwLCBuYXRpZjwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+w6ljcsOqdGFnZQpuYXRpZiAw4oCTMTAwPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMTYyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnFTigJ0pPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZhbWlsbGVfdGVtcG9yZWw8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpkZSBUMSDDoCBUMzwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjI0MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMjYxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y29tcHV0ZV9nZW5lcmFsX2luZGV4KCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Rmlib25hY2NpCsK3IGNvbmZpYW5jZSDPhjwvdGV4dD48bGluZSB4MT0iMjYwIiB5MT0iNTUiIHgyPSIyODIiIHkyPSI1NSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHBhdGggZD0iTTI2MCAxMTEgSDI3MSBWMTM5IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48bGluZSB4MT0iMzA2IiB5MT0iNzgiIHgyPSIzMDYiIHkyPSIxMDQiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSIzIDMiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSI5NCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+c2lub248L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjU1IiB4Mj0iNTY2IiB5Mj0iNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjEzOSIgeDI9IjU2NiIgeTI9IjEzOSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNTUiIHgyPSI1NjYiIHkyPSIxMzkiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjU1IiB4Mj0iNTgwIiB5Mj0iNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE0MiIgeDI9IjY5OSIgeTI9IjE1NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIyMiIgeDI9IjY5OSIgeTI9IjIzNiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjMxMCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+VW4Kw6JnZSBpbmNvbm51IHJlc3RlIE5BIHN1ciBsZSBjaGVtaW4gMiAoaWwgZGV2ZW5haXQgNTAganVzcXXigJnDoCBsYQowLjIxMS4wKS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+UXVhbmQKVDIgcmVjb3BpZSBUMSwgZmFtaWxsZV90ZW1wb3JlbCBjb21wdGUgZGV1eCBmb2lzIGxhIG3Dqm1lCmdyYW5kZXVyLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzQyIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5MZQpub20gYW5ub25jZSB1biBjaGFuZ2VtZW50LCBsYSB2YWxldXIgbWVzdXJlIHVuZSBzdGFiaWxpdMOpIOKAlCBoYXV0ID0Kc3RhYmxlLjwvdGV4dD48L3N2Zz4=)

Un indicateur dérivé, pas mesuré. Avant de lire une famille T, vérifier
lequel des deux chemins a servi : sur le second, T1 et T2 portent la
même information sous deux noms.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction T2 | `R/indicators-temporal.R:230-330` |
| Source amont possible | [`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md) |
| Vraie détection de changement | [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md), [`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md), **T3** |
