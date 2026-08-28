# Fiche indicateur R1 - Risque d'incendie

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
| Code | `R1` |
| Nom long / colonne | `indicateur_r1_feu` |
| Famille | **R — Risques & Résilience** (7 indicateurs) |
| Grandeur mesurée | Aléa d’incendie |
| Unité brute | **0–100, haut = beaucoup de risque** |
| Sens | **inversé** : `score = 100 − valeur` |
| Fonction | [`indicateur_r1_feu()`](https://pobsteta.github.io/nemeton/reference/indicateur_r1_feu.md) — `R/indicators-risk.R:174` |
| Entrée obligatoire | un **MNT** — sans lui, `NA` |

## 2. Deux modes

| Mode | Condition | Composantes |
|----|----|----|
| **`fireexposuR`** | paquet installé (`Suggests`) **et** couche `bdforet` | exposition 0,50 · pente 0,25 · reste 0,25 |
| **Pondéré** (défaut) | sinon | pente 1/3 · essence 1/3 · climat 1/3 |

Mode `fireexposuR` : un masque d’aléa est rasterisé depuis la BD Forêt,
puis `fire_exp(hazard, t_dist = 500)` calcule l’exposition, ramenée sur
0–100.

Mode pondéré : la **pente** vient du MNT, l’**essence** de
`get_species_flammability()`, le **climat** d’un proxy NDVI ou
climatique. Les poids sont renormalisés pour sommer à 1.

## 3. Le calcul par niveau NDP

| NDP   | Ce qui change                                              |
|-------|------------------------------------------------------------|
| **0** | MNT 25 m + BD Forêt : pente grossière, essence typologique |
| **1** | MNT LiDAR HD : pente et exposition topographique réelles   |
| **2** | \+ structure du sous-étage au drone (combustible)          |
| **3** | inventaire du combustible sur placette                     |
| **4** | —                                                          |

## 4. Trois pièges

1.  **La pente retombe sur 50 si son calcul échoue**, sans avertissement
    — soit un tiers du score en mode pondéré. Même motif que B3, L1 et
    A2.
2.  **Les deux modes ne mesurent pas la même chose.** `fireexposuR`
    calcule une **exposition au front de feu** (voisinage combustible
    dans 500 m) ; le mode pondéré agrège pente, essence et climat. Le
    basculement dépend de la présence d’un `Suggests` — deux postes
    peuvent produire deux grandeurs sous le même nom.
3.  **Le combustible de surface n’entre nulle part.** Ni la strate
    herbacée, ni les rémanents, ni la continuité verticale — qui
    gouvernent le passage au feu de cime — ne sont représentés. R1 est
    un aléa **de contexte**, pas un diagnostic de combustibilité.

## 5. Aval

    indicateur_r1_feu()  ->  colonne R1 (0-100, haut = risque)
          |
          +- normalize_indicator()     -> 100 - valeur        (inversion)
          +- create_family_index("R")  -> famille_risque = moy(R1..R7, na.rm = TRUE)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM3NiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBSMSA6IGRldXggbW9kZXMgc2Vsb24gcXUmIzM5O3VuIHBhcXVldCBvcHRpb25uZWwgZXN0IGluc3RhbGxlIOKAlCB1bmUgZXhwb3NpdGlvbiBjYWxjdWxlZSBwYXIgZmlyZWV4cG9zdVIsIG91IHVuZSBtb3llbm5lIHBvbmRlcmVlIGRlIHBlbnRlLCBlc3NlbmNlIGV0IGNsaW1hdCA7IGxhIHZhbGV1ciBicnV0ZSBtb250ZSBhdmVjIGxlIHJpc3F1ZSBldCBjJiMzOTtlc3QgbGEgbm9ybWFsaXNhdGlvbiBxdWkgbGEgcmV0b3VybmUuIExlIGNvbWJ1c3RpYmxlIGRlIHN1cmZhY2UgbiYjMzk7ZW50cmUgZGFucyBhdWN1biBkZXMgZGV1eC4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCBNT0RFUwpFWENMVVNJRlM8L3RleHQ+PHRleHQgeD0iNTg4IiB5PSIxNiI+QVZBTDwvdGV4dD48L2c+PHJlY3QgeD0iOCIgeT0iMzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5NTlQK4oCUIG9ibGlnYXRvaXJlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNhbnMKbHVpLCBSMSA9IE5BPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjkwIiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEwOSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmZpcmVleHBvc3VSCisgYmRmb3JldDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTI1IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+cGFxdWV0ClN1Z2dlc3RzIGluc3RhbGzDqTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxNDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTY1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+RXNzZW5jZQpldCBwcm94eSBjbGltYXRpcXVlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxODEiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5nZXRfc3BlY2llc19mbGFtbWFiaWxpdHkoKTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPk1vZGUKZmlyZWV4cG9zdVI8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5maXJlX2V4cChoYXphcmQsCnRfZGlzdCA9IDUwMCk8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5leHBvCjAsNTAgwrcgcGVudGUgMCwyNSDCtyByZXN0ZSAwLDI1PC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTI2IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Nb2RlCnBvbmTDqXLDqSAoZMOpZmF1dCk8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNjEiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+cGVudGUKMS8zIMK3IGVzc2VuY2UgMS8zPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmNsaW1hdAoxLzMsIHBvaWRzIHJlbm9ybWFsaXPDqXM8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl9yMV9mZXU8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5icnV0CjogaGF1dCA9IHJpc3F1ZSDDqWxldsOpPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zY29yZQo9IDEwMCAtIHZhbGV1cjwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE0OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5SMQrDoCBSNSAoc3BlYyAwNDgpPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMTc4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnFLigJ0pPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZhbWlsbGVfcmlzcXVlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjI5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgUjEgw6AgUjc8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjkzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PHBhdGggZD0iTTI2MCA1NSBIMjcxIFY2MyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxMTEgSDI3MSBWNjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTY3IEgyNzEgVjE1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijk0IiB4Mj0iMzA2IiB5Mj0iMTIwIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iMyAzIiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMTEwIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5vdTwvdGV4dD48bGluZSB4MT0iNTUwIiB5MT0iNjMiIHgyPSI1NjYiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMTU1IiB4Mj0iNTY2IiB5Mj0iMTU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjE1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTU4IiB4Mj0iNjk5IiB5Mj0iMTcyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjM4IiB4Mj0iNjk5IiB5Mj0iMjUyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzI2IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5MYQpwZW50ZSByZXRvbWJlIHN1ciA1MCBzaSBzb24gY2FsY3VsIMOpY2hvdWUsIHNhbnMgYXZlcnRpc3NlbWVudCDigJQgdW4gdGllcnMKZHUgc2NvcmUgZmlnw6kuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlcwpkZXV4IG1vZGVzIG5lIG1lc3VyZW50IHBhcyBsYSBtw6ptZSBjaG9zZSA6IHVuZSBleHBvc2l0aW9uIHNwYXRpYWxlIGTigJl1bgpjw7R0w6ksIHVuIGFsw6lhIGNvbXBvc2l0ZSBkZSBs4oCZYXV0cmUuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNTgiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlCmNvbWJ1c3RpYmxlIGRlIHN1cmZhY2Ug4oCUIGhlcmJhY8OpZSwgbGl0acOocmUsIHLDqW1hbmVudHMg4oCUIG7igJllbnRyZSBudWxsZQpwYXJ0LjwvdGV4dD48L3N2Zz4=)

Le mode dépend de l’installation, pas du terrain. Deux postes différents
rendent deux R1 différents sur le même massif : consigner le mode servi
avec la valeur.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R1 | `R/indicators-risk.R:174-390` |
| Inflammabilité par essence | `get_species_flammability()` — `R/species-config.R` |
| Inversion | `R/normalization.R`, bloc R1–R5 |
| Correction du sens | `NEWS.md` 0.181.0, spec 048 |
