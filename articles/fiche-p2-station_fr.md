# Fiche indicateur P2 - Indice de station

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `P2` |
| Nom long / colonne | `indicateur_p2_station` |
| Famille | **P — Production & Économie** |
| Grandeur mesurée | **Indice de station** — hauteur dominante à l’âge de référence |
| Unité brute | **mètres** (H₀ à l’âge de référence) |
| Sens | Haut = favorable |
| Normalisation | `ref_max = 15` → `score = min(100, H₀ / 15 × 100)` |
| Fonction | [`indicateur_p2_station()`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md) — `R/indicators-productive.R:334` |

## 2. Le calcul

    H_dom = extract_h_dom(chm, percentile = 0,9)        ou colonne fournie
    H_0   = compute_site_index(H_dom, age, essence, reference_age)

[`compute_site_index()`](https://pobsteta.github.io/nemeton/reference/compute_site_index.md)
applique les **courbes de hauteur dominante de Duplat & Tran-Ha
(1997)**, embarquées dans `inst/extdata/site_index_curves.csv` avec
l’autorisation explicite de M. Tran-Ha (avril 2026). Elles couvrent les
principales essences françaises ;
[`list_site_index_species()`](https://pobsteta.github.io/nemeton/reference/list_site_index_species.md)
en donne la liste.

**Exemples chiffrés** :

| Essence       | H_dom | Âge    | H₀ à l’âge de référence | Score    |
|---------------|-------|--------|-------------------------|----------|
| Hêtre         | 24 m  | 80 ans | ~11,5 m                 | **76,7** |
| Chêne sessile | 18 m  | 90 ans | ~8,0 m                  | **53,3** |
| Douglas       | 30 m  | 45 ans | ~14,5 m                 | **96,7** |

## 3. Le calcul par niveau NDP

| NDP | Entrées | Ce qui change |
|----|----|----|
| **0** | pas de hauteur → P2 peu fiable |  |
| **0 augmenté** `height_ml` | **CHM ML** | H_dom prédite — le cas nominal de la spec 005 |
| **1** | MNH LiDAR HD | H_dom mesurée |
| **3** | H_dom relevée au dendromètre + âge par sondage | la mesure de référence |
| **4** | TLS | — |

P2 est **l’indicateur pour lequel la spec 005 a été écrite** : sans
hauteur dominante, il n’existe pas.

## 4. Trois pièges

1.  **L’âge est aussi critique que la hauteur, et souvent moins bien
    connu.** L’indice de station est une hauteur *ramenée à un âge de
    référence* : une erreur de 20 ans sur l’âge déplace H₀ autant qu’une
    erreur de plusieurs mètres sur H_dom. Or l’âge vient souvent de T1,
    c’est-à-dire d’une typologie BD Forêt (cf. la fiche T1).
2.  **Les courbes ne valent que pour des peuplements réguliers purs.**
    Sur une futaie jardinée ou un mélange, H_dom au 90ᵉ percentile
    mesure les dominants d’une strate parmi d’autres, et l’indice de
    station perd son sens.
3.  **`ref_max = 15` est une hauteur, pas un score.** Un H₀ de 15 m à
    l’âge de référence sature l’échelle : les très bonnes stations de
    Douglas y arrivent.

## 5. Aval

    indicateur_p2_station()  ->  colonne indicateur_p2_station (m)
          |
          +- normalize_indicator()     -> min(100, H0 / 15 x 100)
          +- create_family_index("P")  -> famille_production

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBQMiA6IGxhIGhhdXRldXIgZG9taW5hbnRlLCBtZXN1cmVlIGF1IENITSBvdSBmb3VybmllLCBlc3QgcmFtZW5lZSBhIGwmIzM5O2FnZSBkZSByZWZlcmVuY2UgcGFyIGxlcyBjb3VyYmVzIGRlIER1cGxhdCBldCBUcmFuLUhhIDsgbCYjMzk7YWdlLCBzb3V2ZW50IG1vaW5zIGJpZW4gY29ubnUgcXVlIGxhIGhhdXRldXIsIHBlc2UgZG9uYyBhdXRhbnQgcXUmIzM5O2VsbGUgc3VyIGxlIHJlc3VsdGF0LiI+PGRlZnM+PG1hcmtlciBpZD0iZmQiIHZpZXdib3g9IjAgMCAxMCAxMCIgcmVmeD0iOSIgcmVmeT0iNSIgbWFya2Vyd2lkdGg9IjYiIG1hcmtlcmhlaWdodD0iNiIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPjxwYXRoIGQ9Ik0wLDAgTDEwLDUgTDAsMTAgeiIgZmlsbD0iY3VycmVudENvbG9yIiAvPjwvbWFya2VyPjwvZGVmcz48ZyBmaWxsPSJjdXJyZW50Q29sb3IiIGZvbnQtc2l6ZT0iMTAiIGxldHRlci1zcGFjaW5nPSIxLjMiIG9wYWNpdHk9Ii41NSI+PHRleHQgeD0iMTAiIHk9IjE2Ij5FTlRSw4lFUzwvdGV4dD48dGV4dCB4PSIyOTAiIHk9IjE2Ij5DQUxDVUwg4oCUIMOJVEFQRVMKU1VDQ0VTU0lWRVM8L3RleHQ+PHRleHQgeD0iNTg4IiB5PSIxNiI+QVZBTDwvdGV4dD48L2c+PHJlY3QgeD0iOCIgeT0iMzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5DSE0KTUwgb3UgTU5IIExpREFSPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmV4dHJhY3RfaF9kb20oY2htLApwOTApPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjkwIiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEwOSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPsOCZ2UKZHUgcGV1cGxlbWVudDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTI1IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y29sb25uZQpk4oCZaW52ZW50YWlyZTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTQxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+b3UKZMOpZHVpdCBkZSBCRCBGb3LDqnQ8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTYyIiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkVzc2VuY2U8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmxpc3Rfc2l0ZV9pbmRleF9zcGVjaWVzKCk8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5IYXV0ZXVyCmRvbWluYW50ZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkhfZG9tCj0gcDkwIGRlcyBoYXV0ZXVyczwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjExMCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI3NCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTI5IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q291cmJlcwpEdXBsYXQgJmFtcDsgVHJhbi1IYTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE0NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jb21wdXRlX3NpdGVfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zaXRlX2luZGV4X2N1cnZlcy5jc3Y8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+SOKCgArDoCBs4oCZw6JnZSBkZSByw6lmw6lyZW5jZTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjM0IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0iIzJDNkI2MDBGIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuOTUiIC8+PHRleHQgeD0iNTk4IiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjMkM2QjYwIj5pbmRpY2F0ZXVyX3AyX3N0YXRpb248L3RleHQ+PHRleHQgeD0iNTk4IiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5I4oKACmVuIG3DqHRyZXM8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1pbigxMDAsCkjigoAgLyAxNSDDlyAxMDApPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMTYyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnFDigJ0pPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZhbWlsbGVfcHJvZHVjdGlvbjwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIFAxIMOgIFAzPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxsaW5lIHgxPSIyNjAiIHkxPSI1NSIgeDI9IjI4MiIgeTI9IjU1IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48cGF0aCBkPSJNMjYwIDExOSBIMjcxIFYxNDcgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTgzIEgyNzEgVjE0NyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijc4IiB4Mj0iMzA2IiB5Mj0iMTA0IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9Ijk0IiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI1NSIgeDI9IjU2NiIgeTI9IjU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxNDciIHgyPSI1NjYiIHkyPSIxNDciIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjU1IiB4Mj0iNTY2IiB5Mj0iMTQ3IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI1NSIgeDI9IjU4MCIgeTI9IjU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNDIiIHgyPSI2OTkiIHkyPSIxNTYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMjIiIHgyPSI2OTkiIHkyPSIyMzYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMTAiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkzigJnDomdlCnDDqHNlIGF1dGFudCBxdWUgbGEgaGF1dGV1ciwgZXQgaWwgZXN0IHNvdXZlbnQgZXN0aW3DqSDigJQgdW4gw6JnZSBmYXV4CmTDqXBsYWNlIEjigoAgZOKAmWF1dGFudC48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGVzCmNvdXJiZXMgbmUgdmFsZW50IHF1ZSBwb3VyIGRlcyBwZXVwbGVtZW50cyByw6lndWxpZXJzIHB1cnMgOyBlbiBmdXRhaWUKaXJyw6lndWxpw6hyZSwgSOKCgCBu4oCZYSBwYXMgZGUgc2Vucy48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM0MiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+cmVmX21heAo9IDE1IGVzdCB1bmUgaGF1dGV1ciA6IHVuIEjigoAgZGUgMTUgbSDDoCBs4oCZw6JnZSBkZSByw6lmw6lyZW5jZSBzYXR1cmUgbGUKc2NvcmUuPC90ZXh0Pjwvc3ZnPg==)

Deux entrées de qualité très inégale. La hauteur vient d’une mesure
métrique, l’âge d’une déduction — et les courbes de station amplifient
l’erreur sur l’âge, surtout aux âges jeunes.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction P2 | `R/indicators-productive.R:334-500` |
| Indice de station | [`compute_site_index()`](https://pobsteta.github.io/nemeton/reference/compute_site_index.md) — `R/site_index.R` |
| Courbes | `inst/extdata/site_index_curves.csv` (Duplat & Tran-Ha 1997) |
| Essences couvertes | [`list_site_index_species()`](https://pobsteta.github.io/nemeton/reference/list_site_index_species.md), [`site_index_reference_points()`](https://pobsteta.github.io/nemeton/reference/site_index_reference_points.md) |
| Spécification | `specs/005-opencanopy-integration/` |
