# Fiche indicateur L2 - Morcellement du paysage

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `L2` |
| Nom long / colonne | `indicateur_l2_morcellement` |
| Famille | **L — Paysage** |
| Grandeur mesurée | Continuité du couvert forestier autour de l’unité |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable (peu morcelé) |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_l2_morcellement()`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_morcellement.md) — `R/indicators-families.R:1865` |
| Ancien nom | [`indicateur_l2_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_fragmentation.md) — alias conservé (spec 045) |

## 2. Deux chemins

| Ordre | Chemin | Condition | Formule |
|----|----|----|----|
| 1 | **Métriques de paysage** | `landscapemetrics` installé **et** couche `landcover` | `(COHESION + AI) / 2` |
| 2 | **Indice de forme** | sinon, ou si le chemin 1 échoue | `min(100, 100 / SI)` avec `SI = P / (2√(πA))` |

Chemin 1 : un masque forêt binaire est construit sur l’union des unités
tamponnée de **1 000 m**, puis `calculate_lsm()` en tire la cohésion et
l’indice d’agrégation, tous deux déjà sur 0–100.

**Exemples chiffrés** :

| Situation                        | Chemin    | Mesure             | L2       |
|----------------------------------|-----------|--------------------|----------|
| Massif continu                   | métriques | COHESION 97, AI 91 | **94,0** |
| Mosaïque bois/cultures           | métriques | COHESION 72, AI 60 | **66,0** |
| Parcelle compacte, sans couche   | forme     | SI = 1,15          | **87,0** |
| Parcelle en lanière, sans couche | forme     | SI = 2,60          | **38,5** |

## 3. Le calcul par niveau NDP

| NDP     | Ce qui change                                              |
|---------|------------------------------------------------------------|
| **0**   | OSO 30 m — cohésion et agrégation à la maille du satellite |
| **1**   | BD TOPO / BD Forêt : contours de massif justes             |
| **2**   | ortho drone : haies et bosquets comptent enfin             |
| **3–4** | emprise vérifiée au sol                                    |

## 4. Trois pièges

1.  **Le chemin 1 rend la même valeur pour toutes les unités du
    projet.** La cohésion et l’agrégation sont calculées **une fois**,
    sur le paysage entier tamponné, puis recopiées :
    `return(rep(l2_score, nrow(units)))`. L2 ne discrimine donc rien à
    l’intérieur d’un projet quand `landscapemetrics` est disponible —
    c’est une **propriété du paysage**, pas de la parcelle. Un radar où
    toutes les unités partagent le même L2 est le comportement normal.
2.  **Les deux chemins mesurent des choses différentes, et basculent
    silencieusement.** Le chemin 2 (indice de forme) mesure la
    **compacité de l’UGF** ; le chemin 1 mesure la **continuité du
    massif**. Le passage de l’un à l’autre dépend uniquement de la
    présence de `landscapemetrics` (un `Suggests`) et d’une couche
    d’occupation du sol. Un simple `cli_alert_warning` le signale.
    **Deux exécutions sur deux postes peuvent donc mesurer deux
    grandeurs différentes sous le même nom de colonne.**
3.  **Le nom a changé** (spec 045) :
    [`indicateur_l2_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_fragmentation.md)
    reste un alias, et le slug historique reste reconnu par la
    normalisation. Attention au sens : « fragmentation » suggère « haut
    = fragmenté », alors qu’un L2 élevé signifie **peu** morcelé. C’est
    précisément la raison du renommage.

## 5. Aval

    indicateur_l2_morcellement()  ->  colonne indicateur_l2_morcellement
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("L")  -> famille_paysage = moy(L1, L2, L3)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBMMiA6IHNpIGxhbmRzY2FwZW1ldHJpY3MgZXQgdW5lIGNvdWNoZSBkJiMzOTtvY2N1cGF0aW9uIGR1IHNvbCBzb250IGxhLCBsYSBjb250aW51aXRlIGVzdCBtZXN1cmVlIHN1ciB1biBtYXNxdWUgZm9yZXQgdGFtcG9ubmUgZGUgMSBrbSBldCByZW5kIGxhIG1lbWUgdmFsZXVyIHBvdXIgdG91dGVzIGxlcyB1bml0ZXMgZHUgcHJvamV0IDsgc2lub24gbGUgY2FsY3VsIGJhc2N1bGUgc3VyIHVuIGluZGljZSBkZSBmb3JtZSwgcHJvcHJlIGEgY2hhcXVlIHVuaXRlIOKAlCBkZXV4IGdyYW5kZXVycyBzb3VzIHVuIHNldWwgbm9tLiI+PGRlZnM+PG1hcmtlciBpZD0iZmQiIHZpZXdib3g9IjAgMCAxMCAxMCIgcmVmeD0iOSIgcmVmeT0iNSIgbWFya2Vyd2lkdGg9IjYiIG1hcmtlcmhlaWdodD0iNiIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPjxwYXRoIGQ9Ik0wLDAgTDEwLDUgTDAsMTAgeiIgZmlsbD0iY3VycmVudENvbG9yIiAvPjwvbWFya2VyPjwvZGVmcz48ZyBmaWxsPSJjdXJyZW50Q29sb3IiIGZvbnQtc2l6ZT0iMTAiIGxldHRlci1zcGFjaW5nPSIxLjMiIG9wYWNpdHk9Ii41NSI+PHRleHQgeD0iMTAiIHk9IjE2Ij5FTlRSw4lFUzwvdGV4dD48dGV4dCB4PSIyOTAiIHk9IjE2Ij5DQUxDVUwg4oCUIFBSRU1JRVIKQ0hFTUlOIFNFUlZJPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bGFuZGNvdmVyCisgbGFuZHNjYXBlbWV0cmljczwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tYXNxdWUKZm9yw6p0IGJpbmFpcmU8L3RleHQ+PHRleHQgeD0iMjAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+dW5pb24KZGVzIHVuaXTDqXMgKyAxIDAwMCBtPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjEwNiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Hw6lvbcOpdHJpZQpkZSBs4oCZdW5pdMOpIHNldWxlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxNDEiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5ww6lyaW3DqHRyZQpldCBhaXJlPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMzQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+TcOpdHJpcXVlcwpkZSBwYXlzYWdlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+KENPSEVTSU9OCisgQUkpIC8gMjwvdGV4dD48dGV4dCB4PSIzMDAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmNhbGN1bGF0ZV9sc20oKSwKZMOpasOgIDDigJMxMDA8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIxMjYiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjE0NSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkluZGljZQpkZSBmb3JtZSAocmVwbGkpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlNJCj0gUCAvICgy4oiaKM+AwrdBKSk8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bWluKDEwMCwKMTAwIC8gU0kpPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfbDJfbW9yY2VsbGVtZW50PC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2NvcmUKMOKAkzEwMCwgbmF0aWY8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOpY3LDqnRhZ2UKbmF0aWYgMOKAkzEwMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE2MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxM4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX3BheXNhZ2U8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpkZSBMMSDDoCBMMzwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjI0MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMjYxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y29tcHV0ZV9nZW5lcmFsX2luZGV4KCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Rmlib25hY2NpCsK3IGNvbmZpYW5jZSDPhjwvdGV4dD48bGluZSB4MT0iMjYwIiB5MT0iNjMiIHgyPSIyODIiIHkyPSI2MyIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHBhdGggZD0iTTI2MCAxMjcgSDI3MSBWMTU1IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48bGluZSB4MT0iMzA2IiB5MT0iOTQiIHgyPSIzMDYiIHkyPSIxMjAiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSIzIDMiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIxMTAiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnNpbm9uPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxNTUiIHgyPSI1NjYiIHkyPSIxNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iMTU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU4MCIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNDIiIHgyPSI2OTkiIHkyPSIxNTYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMjIiIHgyPSI2OTkiIHkyPSIyMzYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMTAiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkNoZW1pbgoxIDogdW5lIHNldWxlIHZhbGV1ciBkZSBwYXlzYWdlLCByZWNvcGnDqWUgc3VyIHRvdXRlcyBsZXMgdW5pdMOpcyBkdQpwcm9qZXQuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlcwpkZXV4IGNoZW1pbnMgbWVzdXJlbnQgZGVzIGNob3NlcyBkaWZmw6lyZW50ZXMgZXQgYmFzY3VsZW50IHN1ciBsYSBzZXVsZQpwcsOpc2VuY2UgZOKAmXVuIHBhcXVldC48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM0MiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+aW5kaWNhdGV1cl9sMl9mcmFnbWVudGF0aW9uKCkKcmVzdGUgdW4gYWxpYXMgYWNjZXB0w6kgKHNwZWMgMDQ1KS48L3RleHQ+PC9zdmc+)

Le basculement ne dépend pas du terrain mais de l’installation : avec
`landscapemetrics`, L2 décrit le massif ; sans lui, il décrit la forme
du polygone. Deux lectures opposées de la même colonne.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction L2 | `R/indicators-families.R:1865-1960` |
| Alias historique | [`indicateur_l2_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_fragmentation.md) — `:1962` |
| Migration des colonnes | [`migrer_colonnes_l()`](https://pobsteta.github.io/nemeton/reference/migrer_colonnes_l.md) — `R/migration-famille-l.R` |
| Renommage | `specs/045-renommage-famille-L/` |
