# Fiche indicateur N3 - Naturalite composite

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> **Cette fiche documente une incohérence de sens active** (§4, piège n°
> 1).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `N3` |
| Nom long / colonne | `indicateur_n3_naturalite` |
| Famille | **N — Naturalité** |
| Grandeur mesurée | Indice composite de naturalité |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_n3_naturalite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n3_naturalite.md) — `R/indicators-naturalness.R:226` |
| Entrées obligatoires | colonnes **N1, N2, L1 et B3** — l’une manque → `NA` |

## 2. Le calcul

    anti_frag = 100 - L1

    N3 = 0,35 x N1 + 0,35 x N2 + 0,15 x anti_frag + 0,15 x B3

Pondération issue du tutoriel 04. **N3 est un composite de quatre autres
indicateurs** — dont deux appartiennent à d’autres familles (L1 pour
Paysage, B3 pour Biodiversité).

**Exemple chiffré** :

| Entrée              | Valeur | Contribution |
|---------------------|--------|--------------|
| N1 (éloignement)    | 70     | 24,5         |
| N2 (continuité)     | 80     | 28,0         |
| L1 = 30 → anti_frag | 70     | 10,5         |
| B3 (connectivité)   | 60     | 9,0          |
| **N3**              |        | **72,0**     |

## 3. Le calcul par niveau NDP

N3 hérite du NDP le plus faible de ses quatre entrées. En pratique,
c’est **B3** qui le plafonne, puisqu’il exige la BD Forêt et trois
paquets optionnels (cf. sa fiche).

## 4. Trois pièges, dont une incohérence de sens

1.  **L1 est lu en sens inverse par N3 et par la normalisation.** N3
    calcule `anti_frag = 100 − L1`, ce qui suppose **L1 élevé = beaucoup
    de lisière = défavorable**. C’est cohérent avec le calcul de L1
    (indice de forme élevé + matrice contrastée + exposition → score
    élevé) et avec son infobulle (« Proportion de la parcelle sous
    influence des lisières \[…\] fragmentent l’habitat intérieur »).

    Mais `indicateur_l1_effet_lisiere` est déclaré dans
    `.NORMALIZE_NATIVE_0_100` : la normalisation le laisse passer tel
    quel, **comme si un L1 élevé était favorable**. Le radar et
    `famille_paysage` lisent donc L1 à l’endroit où N3, le calcul et
    l’infobulle le lisent à l’envers.

    > Conséquence : une parcelle en lanière bordée de bâti obtient un
    > **L1 élevé**, que le radar affiche comme un bon score de paysage —
    > alors que le même chiffre, injecté dans N3, la pénalise. C’est
    > exactement le défaut corrigé pour R5 en 0.181.0 (spec 048) et pour
    > les noms de la famille L en 0.176.0 (spec 045), à un endroit qui
    > n’a pas été revu.

2.  **N3 est un composite, donc il double-compte.** N1 et N2 pèsent 35 %
    chacun dans N3 **et** un tiers chacun dans `famille_naturalite`, où
    N3 pèse aussi un tiers. N1 et N2 comptent donc environ **45 %**
    chacun dans le score de famille, au lieu d’un tiers.

3.  **`NA` dès qu’une des quatre entrées manque**, sans calcul partiel.
    C’est voulu (« returning NA — no measurement made »), mais cela rend
    N3 fragile : il suffit que B3 soit `NA` faute de BD Forêt pour que
    N3 le soit aussi.

## 5. Aval

    indicateur_n3_naturalite()  ->  colonne N3 (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("N")  -> famille_naturalite = moy(N1, N2, N3)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBOMyA6IHVuIGNvbXBvc2l0ZSBkZSBxdWF0cmUgY29sb25uZXMgZGVqYSBjYWxjdWxlZXMg4oCUIE4xLCBOMiwgTDEgcmV0b3VybmUgZW4gYW50aS1mcmFnbWVudGF0aW9uLCBldCBCMyDigJQgZG9udCBkZXV4IGFwcGFydGllbm5lbnQgYSBkJiMzOTthdXRyZXMgZmFtaWxsZXMgOyBsJiMzOTthYnNlbmNlIGQmIzM5O3VuZSBzZXVsZSBkZXMgcXVhdHJlIHJlbmQgTkEsIHNhbnMgY2FsY3VsIHBhcnRpZWwuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgw4lUQVBFUwpTVUNDRVNTSVZFUzwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNvbG9ubmUKTjEg4oCUIMOpbG9pZ25lbWVudDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5wb2lkcwowLDM1PC90ZXh0PjxyZWN0IHg9IjgiIHk9IjkwIiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEwOSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNvbG9ubmUKTjIg4oCUIGNvbnRpbnVpdMOpPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5wb2lkcwowLDM1PC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE0NiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxNjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Db2xvbm5lCkwxIOKAlCBlZmZldCBkZSBsaXNpw6hyZTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTgxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZW50cmUKaW52ZXJzw6llLCBwb2lkcyAwLDE1PC90ZXh0PjxyZWN0IHg9IjgiIHk9IjIwMiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIyMjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Db2xvbm5lCkIzIOKAlCBjb25uZWN0aXZpdMOpPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIyMzciIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5wb2lkcwowLDE1PC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMzQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+SW52ZXJzaW9uCmRlIEwxPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YW50aV9mcmFnCj0gMTAwIC0gTDE8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIxMTAiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjEyOSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNvbXBvc2l0ZQpwb25kw6lyw6k8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+MCwzNcK3TjEKKyAwLDM1wrdOMjwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij4rCjAsMTXCt2FudGlfZnJhZyArIDAsMTXCt0IzPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfbjNfbmF0dXJhbGl0ZTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNjb3JlCjDigJMxMDAsIG5hdGlmPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij7DqWNyw6p0YWdlCm5hdGlmIDDigJMxMDA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcTuKAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9uYXR1cmFsaXRlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgTjEgw6AgTjM8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNDIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI2MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PGxpbmUgeDE9IjI2MCIgeTE9IjU1IiB4Mj0iMjgyIiB5Mj0iNTUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxwYXRoIGQ9Ik0yNjAgMTExIEgyNzEgVjEzOSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxNjcgSDI3MSBWMTM5IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDIyMyBIMjcxIFYxMzkgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI3OCIgeDI9IjMwNiIgeTI9IjEwNCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSI5NCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+cHVpczwvdGV4dD48bGluZSB4MT0iNTUwIiB5MT0iNTUiIHgyPSI1NjYiIHkyPSI1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMTM5IiB4Mj0iNTY2IiB5Mj0iMTM5IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI1NSIgeDI9IjU2NiIgeTI9IjEzOSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNTUiIHgyPSI1ODAiIHkyPSI1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTQyIiB4Mj0iNjk5IiB5Mj0iMTU2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjIyIiB4Mj0iNjk5IiB5Mj0iMjM2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzEwIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5OQQpkw6hzIHF14oCZdW5lIGRlcyBxdWF0cmUgZW50csOpZXMgbWFucXVlIDogcGFzIGRlIGNhbGN1bCBwYXJ0aWVsLCBwYXMgZGUKdmFsZXVyIGTDqWdyYWTDqWUuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkNvbXBvc2l0ZQo6IE4xIGV0IE4yIHDDqHNlbnQgNzAgJSwgZXQgTjEgcG9ydGUgZMOpasOgIHNvbiB0ZXJtZSB1cmJhaW4KY29uc3RhbnQuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkwxCmVudHJlIGludmVyc8OpICgxMDAgLSBMMSkgYWxvcnMgcXVlIGxhIG5vcm1hbGlzYXRpb24sIGVsbGUsIGxlIGxpdCDDoAps4oCZZW5kcm9pdC48L3RleHQ+PC9zdmc+)

Un indicateur qui ne lit aucune donnée : ses quatre entrées sont des
colonnes. Les défauts de N1, L1 et B3 se propagent donc dans N3, avec
leurs poids — dont le +25 constant de N1.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction N3 | `R/indicators-naturalness.R:226-256` |
| Entrées | [`indicateur_n1_distance()`](https://pobsteta.github.io/nemeton/reference/indicateur_n1_distance.md), [`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md), [`indicateur_l1_effet_lisiere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_effet_lisiere.md), [`indicateur_b3_connectivite()`](https://pobsteta.github.io/nemeton/reference/indicateur_b3_connectivite.md) |
| Déclaration de L1 en « natif 0-100 » | `R/normalization.R:521` |
| Précédents comparables | spec 048 (sens de R5), spec 045 (noms de la famille L) |
