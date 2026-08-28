# Fiche indicateur B1 - Protection reglementaire

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `B1` |
| Nom long / colonne | `indicateur_b1_protection` |
| Famille | **B — Biodiversité** (avec B2, B3, B4) |
| Grandeur mesurée | Couverture de l’unité par des statuts de protection, **pondérée par la force du statut** |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, simple écrêtage (`.NORMALIZE_NATIVE_0_100`) |
| Fonction | [`indicateur_b1_protection()`](https://pobsteta.github.io/nemeton/reference/indicateur_b1_protection.md) — `R/indicators-biodiversity.R:68` |
| Colonnes annexes | `B1_pct` (couverture brute), `B1_nb` (nombre de statuts croisés) |

## 2. Le calcul

Pour chaque unité, et pour **chaque type de protection présent** :

    couverture_type = min(1, aire(intersection) / aire(unité))
    B1 = somme(couverture_type x poids_type) / somme(poids_type)  x 100

Autrement dit une **moyenne des couvertures pondérée par la force du
statut**, et non une simple somme de surfaces.

| Force | Poids | Statuts reconnus (sous-chaîne, insensible à la casse) |
|----|----|----|
| Forte | **1,0** | `rnn`, `rnr`, `apb`, `rb`, `rncfs`, `pn`, `coeur` |
| Moyenne | **0,6** | `sic`, `zps`, `zsc`, `natura`, `znieff1` |
| Faible / informative | **0,3** | `pnr`, `ramsar`, `pnm`, `znieff2` |
| Inconnue | **0,5** | tout type non reconnu |

Le type est lu dans la première colonne trouvée parmi `type_protection`,
`zone_type`, `type`, `statut`.

**Exemples chiffrés** :

| Situation | Calcul | B1 |
|----|----|----|
| 100 % en réserve naturelle (poids 1,0) | (1,0 × 1,0) / 1,0 × 100 | **100,0** |
| 100 % en ZNIEFF 2 (poids 0,3) | (1,0 × 0,3) / 0,3 × 100 | **100,0** |
| 50 % en Natura 2000 seul | (0,5 × 0,6) / 0,6 × 100 | **50,0** |
| 100 % ZNIEFF 2 + 40 % Natura 2000 | (1,0 × 0,3 + 0,4 × 0,6) / (0,3 + 0,6) × 100 | **60,0** |
| Aucun recoupement | — | **0,0** |

> **Le poids ne hiérarchise pas les statuts entre eux, il les pondère
> dans la moyenne.** Une unité entièrement en ZNIEFF 2 obtient **100**,
> exactement comme une unité entièrement en réserve naturelle intégrale
> : le dénominateur normalise par la somme des poids. La force du statut
> ne joue que lorsque **plusieurs statuts se croisent** avec des taux de
> couverture différents. C’est un choix défendable — « cette unité est
> intégralement protégée, à la hauteur de ce que son statut permet » —
> mais ce n’est pas ce que le mot « pondéré » laisse spontanément
> entendre. À dire avant toute comparaison entre unités de statuts
> différents.

## 3. Le calcul par niveau NDP

| NDP | Source | Ce qui change |
|----|----|----|
| **0** | INPN (WFS) — **non implémenté**, cf. §4 | `NA` en pratique, sauf couche fournie à la main |
| **1** | idem NDP 0 | inchangé : B1 dépend d’un zonage réglementaire, pas d’un capteur |
| **2** | \+ vérification drone des limites | correction des contours litigieux |
| **3** | \+ relevé terrain des statuts | statuts constatés sur place |
| **4** | jumeau numérique complet | — |

**B1 est l’indicateur le moins sensible au NDP des 41.** Un statut de
protection est une donnée juridique : ni le LiDAR, ni le drone, ni le
scanner terrestre ne la produisent. Ce qui progresse avec le NDP, c’est
la **précision géométrique des contours**, pas la connaissance du
statut.

## 4. Trois pièges

1.  **Le mode `source = "wfs"` n’interroge rien.** L’appel émet
    `biodiversity_wfs_fetching` puis immédiatement
    `biodiversity_wfs_failed`, et rend `NA`. Le connecteur INPN n’est
    pas implémenté. **En pratique, B1 n’est calculé que si l’on fournit
    soi-même `protected_areas`.**
2.  **`NA` et `0` ne disent pas la même chose, et le code y tient.**
    Absence de donnée → `NA` (« on n’a pas pu regarder ») ; couche
    fournie mais vide → `0` (« on a regardé, rien ne protège »).
    [`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
    moyennant avec `na.rm = TRUE`, un `0` fabriqué tirerait
    `famille_biodiversite` vers le bas tandis qu’un `NA` honnête
    s’efface. Ne jamais « corriger » un `NA` de B1 en `0` en amont.
3.  **Sans colonne de type, le score est divisé par deux.** Quand aucune
    des colonnes `type_protection` / `zone_type` / `type` / `statut`
    n’est présente, le code applique `B1 = pct × 0.5` — le poids par
    défaut, **sans le dénominateur normalisateur** du chemin principal.
    Une unité couverte à 100 % obtient alors **50**, pas 100. Deux jeux
    de données identiques au nom d’une colonne près donnent donc des
    scores du simple au double. **Toujours fournir une colonne de
    type**, quitte à la remplir d’une constante.

## 5. Aval

    indicateur_b1_protection()  ->  colonnes B1, B1_pct, B1_nb
          |
          +- normalize_indicator()     -> passthrough clamp [0, 100]
          +- create_family_index("B")  -> famille_biodiversite = moy(B1, B2, B3, B4)

`B1_pct` (couverture brute non pondérée) et `B1_nb` (nombre de statuts
croisés) ne sont **pas** agrégées dans la famille : ce sont des colonnes
de diagnostic, utiles pour expliquer un score à un propriétaire.

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBCMSA6IGxlcyB6b25hZ2VzIGRlIHByb3RlY3Rpb24gcXVpIHJlY291cGVudCBsJiMzOTt1bml0ZSBkb25uZW50IGNoYWN1biB1biB0YXV4IGRlIGNvdXZlcnR1cmUsIG1veWVubmUgcG9uZGVyZSBwYXIgbGEgZm9yY2UgZHUgc3RhdHV0IDsgbGUgZGVub21pbmF0ZXVyIGV0YW50IGxhIHNvbW1lIGRlcyBwb2lkcywgdW5lIHVuaXRlIGVudGllcmVtZW50IGNvdXZlcnRlIG9idGllbnQgMTAwIHF1ZWwgcXVlIHNvaXQgbGUgc3RhdHV0LCBldCBsZSBtb2RlIFdGUyBuZSByYXBhdHJpZSBhdWpvdXJkJiMzOTtodWkgYXVjdW5lIGRvbm5lZS4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCDDiVRBUEVTClNVQ0NFU1NJVkVTPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q291Y2hlCmRlIHpvbmFnZXMgZm91cm5pZTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij50eXBlCmx1IGRhbnMgdHlwZV9wcm90ZWN0aW9uLDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij56b25lX3R5cGUsCnR5cGUgb3Ugc3RhdHV0PC90ZXh0PjxyZWN0IHg9IjgiIHk9IjEwNiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPnNvdXJjZQo9IOKAnHdmc+KAnSAoSU5QTik8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE0MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm7igJlpbnRlcnJvZ2UKcmllbiDigJQgTkEgZW4gcHJhdGlxdWU8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Db3V2ZXJ0dXJlCnBhciB0eXBlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bWluKDEsCmFpcmUoaW50ZXIpIC8gYWlyZSh1KSk8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIxMTAiIHdpZHRoPSIyNjIiIGhlaWdodD0iNzQiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjEyOSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPk1veWVubmUKcG9uZMOpcsOpZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE0NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij7Ooyhjb3V2CsOXIHBvaWRzKS/Ooyhwb2lkcykgw5cgMTAwPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZvcnRlCjEsMCDCtyBtb3llbm5lIDAsNjwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYWlibGUKMCwzIMK3IGluY29ubnVlIDAsNTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjM0IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0iIzJDNkI2MDBGIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuOTUiIC8+PHRleHQgeD0iNTk4IiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjMkM2QjYwIj5pbmRpY2F0ZXVyX2IxX3Byb3RlY3Rpb248L3RleHQ+PHRleHQgeD0iNTk4IiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zY29yZQow4oCTMTAwLCBuYXRpZjwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+w6ljcsOqdGFnZQpuYXRpZiAw4oCTMTAwPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMTYyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnELigJ0pPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZhbWlsbGVfYmlvZGl2ZXJzaXRlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgQjEgw6AgQjQ8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNDIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI2MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PHBhdGggZD0iTTI2MCA2MyBIMjcxIFY1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxMjcgSDI3MSBWMTQ3IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48bGluZSB4MT0iMzA2IiB5MT0iNzgiIHgyPSIzMDYiIHkyPSIxMDQiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iOTQiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnB1aXM8L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjU1IiB4Mj0iNTY2IiB5Mj0iNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE0NyIgeDI9IjU2NiIgeTI9IjE0NyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNTUiIHgyPSI1NjYiIHkyPSIxNDciIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjU1IiB4Mj0iNTgwIiB5Mj0iNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE0MiIgeDI9IjY5OSIgeTI9IjE1NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIyMiIgeDI9IjY5OSIgeTI9IjIzNiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjMxMCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGUKcG9pZHMgbmUgaGnDqXJhcmNoaXNlIHBhcyA6IDEwMCAlIGVuIFpOSUVGRiAyIHJlbmQgMTAwLCBjb21tZSAxMDAgJSBlbgpyw6lzZXJ2ZSBpbnTDqWdyYWxlLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzI2IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5JbApuZSBqb3VlIHF14oCZZW50cmUgc3RhdHV0cyBjcm9pc8OpcyDDoCBjb3V2ZXJ0dXJlcyBkaWZmw6lyZW50ZXMuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkluZGljYXRldXIKbGUgbW9pbnMgc2Vuc2libGUgYXUgTkRQIDogdW4gc3RhdHV0IGVzdCBqdXJpZGlxdWUsIGF1Y3VuIGNhcHRldXIgbmUgbGUKcHJvZHVpdC48L3RleHQ+PC9zdmc+)

Une moyenne, pas une somme. Le dénominateur `Σ(poids)` est ce qui fait
que la force du statut disparaît dès qu’un seul statut couvre l’unité —
le point à énoncer avant toute comparaison entre unités de statuts
différents.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction B1 et table des poids | `R/indicators-biodiversity.R:68-200` |
| Déclaration « native 0-100 » | `R/normalization.R`, `.NORMALIZE_NATIVE_0_100` |
| Source essences (composition) | `inst/datasources/FR.json` — `theia_species` |
