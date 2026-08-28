# Fiche indicateur R3 - Risque de secheresse

> **Document de référence** — Néméton (package cœur), 2026-08-27.

> ### Le sens de la famille R, corrigé en 0.181.0
>
> **R1 à R5 sont tous orientés « haut = mauvais » à l’état brut** et
> sont donc **inversés** à la normalisation : `score = 100 − valeur`.
> **R6 et R7 ne le sont pas** — ils sont déjà « haut = bon » à la
> source.
>
> Jusqu’à la version 0.181.0, **seul R5 était inversé**, et le
> commentaire qui le justifiait affirmait que c’était « pour rester high
> = good comme R1-R4 ». La prémisse était fausse : R1-R4 passaient tels
> quels. R5 pointait donc à l’opposé des quatre autres **dans sa propre
> famille**, et une UGF très exposée obtenait un `famille_risque` élevé,
> c’est-à-dire flatteur. Les fonctions d’indicateur et leurs appelants
> sont inchangés — **seule la valeur normalisée a basculé** (spec 048).
> Tout `famille_risque` calculé avant 0.181.0 est à refaire.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `R3` |
| Nom long / colonne | `indicateur_r3_secheresse` |
| Famille | **R — Risques & Résilience** |
| Grandeur mesurée | Risque de stress hydrique |
| Unité brute | **0–100, haut = risque élevé** |
| Sens | **inversé** |
| Fonction | [`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md) — `R/indicators-risk.R:666` |

## 2. Trois chemins

| Ordre | Chemin | Condition | Formule |
|----|----|----|----|
| 1 | **Bilan hydrique BILJOU** | `biljou` fourni | `.r3_biljou_stress()`, écrêté `[0, 100]` |
| 2 | **Climat + topographie** | MNT disponible | `(0,6 × climat + 0,4 × topo) × 100` |
| — | *aucun* | — | `NA` |

    topo = 0,4 x aspect_risk + 0,3 x slope_risk + 0,3 x twi_risk
    climat = f(SPEI-3)   avec  climat = max(0, min(1, (-SPEI + 2) / 4))

Une modulation par l’enneigement (`snow`, `snow_relief_strength = 0,3`)
est appliquée quand le produit neige est fourni.

## 3. Le calcul par niveau NDP

| NDP | Ce qui change |
|----|----|
| **0** | SPEI depuis WorldClim + topographie sur MNT 25 m |
| **1** | topographie LiDAR HD : exposition et TWI fins |
| **2** | — |
| **3** | **BILJOU** alimenté par un sol décrit sur placette : vrai bilan hydrique |
| **4** | — |

## 4. Trois pièges

1.  **La composante climatique retombe sur `0,5` en dur**
    (`r3_climat <- 0.5`, « Default scalar fallback ») quand la série
    SPEI n’est pas calculable. Comme elle pèse **60 %**, un projet sans
    climat exploitable a un R3 dominé par une constante — et rien ne le
    distingue d’un risque réellement moyen.
2.  **Le chemin BILJOU court-circuite tout le reste.** Quand un bilan
    hydrique est fourni, R3 vaut son score et ne mélange plus climat ni
    topographie. Deux projets, l’un avec BILJOU, l’autre sans, mesurent
    deux grandeurs différentes.
3.  **Le SPEI est calculé au centroïde de l’union des unités**, donc
    **une seule valeur climatique pour tout le projet**. Sur une emprise
    étendue ou à cheval sur un gradient, la composante climatique ne
    discrimine rien.

## 5. Aval

    indicateur_r3_secheresse()  ->  colonne R3 (0-100, haut = risque)
          |
          +- normalize_indicator()     -> 100 - valeur
          +- create_family_index("R")  -> famille_risque

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM3NiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBSMyA6IHVuIGJpbGFuIGh5ZHJpcXVlIEJJTEpPVSBjb3VydC1jaXJjdWl0ZSB0b3V0IGxlIHJlc3RlIHF1YW5kIGlsIGVzdCBmb3VybmkgOyBzaW5vbiBsZSByaXNxdWUgbWVsYW5nZSB1biB0ZXJtZSBjbGltYXRpcXVlIHRpcmUgZHUgU1BFSSDigJQgY2FsY3VsZSBlbiB1biBzZXVsIHBvaW50IHBvdXIgdG91dCBsZSBwcm9qZXQsIGV0IHJlbXBsYWNlIHBhciAwLDUgcyYjMzk7aWwgZWNob3VlIOKAlCBldCB1biB0ZXJtZSB0b3BvZ3JhcGhpcXVlIGQmIzM5O2V4cG9zaXRpb24sIHBlbnRlIGV0IFRXSS4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCBQUkVNSUVSCkNIRU1JTiBTRVJWSTwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkJpbGFuCmh5ZHJpcXVlIEJJTEpPVTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5hcmd1bWVudApiaWxqb3U8L3RleHQ+PHJlY3QgeD0iOCIgeT0iOTAiIHdpZHRoPSIyNTIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTA5IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+U1BFSS0zPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij51bgpzZXVsIHBvaW50IDogY2VudHJvw69kZTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTQxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZGUKbOKAmXVuaW9uIGRlcyB1bml0w6lzPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE2MiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5NTlQK4oCUIGV4cG9zaXRpb24sIHBlbnRlLCBUV0k8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnRlcm1lCnRvcG9ncmFwaGlxdWU8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMjE4IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgLz48dGV4dCB4PSIyMCIgeT0iMjM3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+UHJvZHVpdApuZWlnZSAob3B0aW9ubmVsKTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMjUzIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c25vd19yZWxpZWZfc3RyZW5ndGgKPSAwLDM8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5DaGVtaW4KQklMSk9VPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+LnIzX2JpbGpvdV9zdHJlc3MoKTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOpY3LDqnTDqQpbMCwgMTAwXTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjEyNiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI5MCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q2xpbWF0CisgdG9wb2dyYXBoaWU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNjEiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y2xpbWF0Cj0gKC1TUEVJICsgMikvNDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij50b3BvCj0gMCw0IGFzcCArIDAsMyBwZW50ZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE5MyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij4KKyAwLDMgdHdpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjA5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPigwLDYKY2xpbSArIDAsNCB0b3BvKSDDlyAxMDA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl9yM19zZWNoZXJlc3NlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YnJ1dAo6IGhhdXQgPSByaXNxdWUgw6lsZXbDqTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2NvcmUKPSAxMDAgLSB2YWxldXI8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxNDkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+UjEKw6AgUjUgKHNwZWMgMDQ4KTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE3OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTk3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxS4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX3Jpc3F1ZTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIyOSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIFIxIMOgIFI3PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjU4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNzciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI5MyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxwYXRoIGQ9Ik0yNjAgNTUgSDI3MSBWNjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTE5IEgyNzEgVjE3MSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxODMgSDI3MSBWMTcxIEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDIzOSBIMjcxIFYxNzEgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI5NCIgeDI9IjMwNiIgeTI9IjEyMCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjExMCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+c2lub248L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE3MSIgeDI9IjU2NiIgeTI9IjE3MSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1NjYiIHkyPSIxNzEiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTgwIiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE1OCIgeDI9IjY5OSIgeTI9IjE3MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIzOCIgeDI9IjY5OSIgeTI9IjI1MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGEKY29tcG9zYW50ZSBjbGltYXRpcXVlIHJldG9tYmUgc3VyIDAsNSBlbiBkdXIgcXVhbmQgbGUgU1BFSSDDqWNob3VlIDogNjAgJQpkdSBzY29yZSBkZXZpZW50IHVuZSBjb25zdGFudGUuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlClNQRUkgZXN0IGNhbGN1bMOpIGF1IGNlbnRyb8OvZGUgZGUgbOKAmXVuaW9uIDogdG91dGVzIGxlcyB1bml0w6lzIHBhcnRhZ2VudApsZSBtw6ptZSBjbGltYXQuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNTgiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlCmNoZW1pbiBCSUxKT1UgY291cnQtY2lyY3VpdGUgbGUgcmVzdGUg4oCUIGRldXggcHJvamV0cyBuZSBzZSBjb21wYXJlbnQgcGFzCnPigJlpbHMgbuKAmW9udCBwYXMgcHJpcyBsZSBtw6ptZS48L3RleHQ+PC9zdmc+)

Deux chemins, deux natures. BILJOU produit un bilan hydrique par unité ;
le chemin par défaut mélange un climat unique pour tout le projet et une
topographie locale — seul le second terme distingue les unités.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R3 | `R/indicators-risk.R:666-910` |
| Bilan hydrique | [`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md), [`load_biljou_forcing()`](https://pobsteta.github.io/nemeton/reference/load_biljou_forcing.md), [`build_biljou_soil()`](https://pobsteta.github.io/nemeton/reference/build_biljou_soil.md) |
| TWI partagé | `get_or_compute_twi()` — cache W2/W3/F2/R3 |
| Neige | `inst/datasources/FR.json` — `theia_snow` |
