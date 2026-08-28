# Fiche indicateur T3 - Coupes rases (SUFOSAT)

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** : calculé seulement si un raster SUFOSAT
> est fourni (spec 030).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `T3` |
| Nom long / colonne | `indicateur_t3_coupes_rases` |
| Famille | **T — Dynamique temporelle** |
| Grandeur mesurée | Pression de coupe rase récente sur l’unité |
| Unité brute | **0–100, orienté « haut = beaucoup de coupes »** |
| Sens | **Inversé à la normalisation** : `score = 100 − valeur` |
| Fonction | [`indicateur_t3_coupes_rases()`](https://pobsteta.github.io/nemeton/reference/indicateur_t3_coupes_rases.md) — `R/indicators-temporal.R:335` |
| Source | SUFOSAT (CNES/CESBIO), suivi submensuel des coupes |

## 2. Le calcul

    T3_brut = part de l'unite touchee par une coupe rase detectee
              dans les `window_years` dernieres annees (defaut 5)
              en ne gardant que les pixels de probabilite >= `min_proba` (defaut 0,9)

    score = 100 - T3_brut          inversion, cf. R/normalization.R

Les deux rasters (dates et probabilité) sont empilés pour **une seule
extraction**, ce qui garantit l’alignement pixel à pixel des valeurs et
des fractions de couverture.

**Exemples chiffrés** :

| Situation                      | T3 brut | Score     |
|--------------------------------|---------|-----------|
| Aucune coupe détectée en 5 ans | 0       | **100,0** |
| 15 % de l’unité coupée         | 15      | **85,0**  |
| 60 % coupé                     | 60      | **40,0**  |
| Coupe rase totale récente      | 100     | **0,0**   |

## 3. Le calcul par niveau NDP

| NDP | Ce qui existe | T3 |
|----|----|----|
| **0** sans SUFOSAT | rien | **`NA`** — indicateur non applicable |
| **0** + SUFOSAT | Sentinel-1/2, submensuel | **calculé** |
| **1–2** | — | inchangé : SUFOSAT est un produit national, pas un capteur local |
| **3** | registre de coupes de l’aménagement | vérité terrain |
| **4** | — | — |

T3 est un **indicateur de source**, pas de résolution : il existe ou
n’existe pas, selon que le produit SUFOSAT a été fourni. Comme R5
(dépérissement FORDEAD), il porte le nombre d’indicateurs de 31 à 33
dans le décompte historique du `CLAUDE.md`.

## 4. Trois pièges

1.  **Le sens brut est inversé par rapport au score.** La colonne brute
    vaut *haut = beaucoup de coupes* ; le radar affiche *haut = bon*.
    L’inversion est faite par
    [`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md),
    pas par la fonction. Lire la colonne brute comme un score est un
    contresens complet.
2.  **Une coupe rase n’est pas nécessairement une anomalie.** T3
    pénalise uniformément, alors qu’une coupe rase peut être un acte de
    gestion planifié et régulier (futaie régulière arrivée à terme).
    L’indicateur mesure une **pression**, pas une faute. C’est au profil
    expert d’en faire la lecture.
3.  **`min_proba = 0,9` est strict, et c’est délibéré.** Abaisser le
    seuil fait entrer des détections douteuses ; le laisser haut
    sous-estime les coupes partielles. Le même arbitrage que les
    garde-fous G1 de FORDEAD sur les classes de faible confiance.

## 5. Aval

    indicateur_t3_coupes_rases()  ->  colonne indicateur_t3_coupes_rases (0-100, haut = coupes)
          |
          +- normalize_indicator()     -> 100 - valeur    (inversion)
          +- create_family_index("T")  -> famille_temporelle = moy(T1, T2, T3)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM3NiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBUMyA6IGxlcyBkYXRlcyBldCBsZXMgcHJvYmFiaWxpdGVzIFNVRk9TQVQgc29udCBlbXBpbGVlcyBwb3VyIHVuZSBleHRyYWN0aW9uIHVuaXF1ZSwgbGEgcGFydCBkZSBsJiMzOTt1bml0ZSBjb3VwZWUgZGFucyBsZXMgY2lucSBkZXJuaWVyZXMgYW5uZWVzIGF1LWRlbGEgZGUgMCw5IGRlIHByb2JhYmlsaXRlIGVzdCByZXRlbnVlLCBwdWlzIGxlIHNlbnMgZXN0IGludmVyc2UgYSBsYSBub3JtYWxpc2F0aW9uIOKAlCBzY29yZSA9IDEwMCBtb2lucyBsYSB2YWxldXIgYnJ1dGUuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgw4lUQVBFUwpTVUNDRVNTSVZFUzwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlNVRk9TQVQK4oCUIGRhdGVzIGRlIGNvdXBlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkNORVMvQ0VTQklPLApzdWl2aSBzdWJtZW5zdWVsPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZlbsOqdHJlCndpbmRvd195ZWFycyA9IDU8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTA2IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlNVRk9TQVQK4oCUIHByb2JhYmlsaXTDqTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTQxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2V1aWwKbWluX3Byb2JhID0gMCw5PC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE2MiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlNVRk9TQVQKbm9uIGZvdXJuaTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+VDMKbm9uIGNhbGN1bMOpIChjb25kaXRpb25uZWwpPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMzQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+RW1waWxlbWVudApkZXMgZGV1eCByYXN0ZXJzPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+dW5lCnNldWxlIGV4dHJhY3Rpb248L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5hbGlnbmVtZW50CnBpeGVsIMOgIHBpeGVsPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTI2IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5QYXJ0CmRlIGzigJl1bml0w6kgY291cMOpZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5waXhlbHMKcmV0ZW51cyAvIHVuaXTDqSDDlyAxMDA8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+VDMKYnJ1dCA6IGhhdXQgPSBjb3Vww6k8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl90M19jb3VwZXNfcmFzZXM8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5icnV0CjogaGF1dCA9IGJlYXVjb3VwIGNvdXDDqTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2NvcmUKPSAxMDAgLSB2YWxldXI8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxNDkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y29tbWUKUjEgw6AgUjUgKHNwZWMgMDQ4KTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE3OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTk3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxU4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX3RlbXBvcmVsPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjI5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgVDEgw6AgVDM8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjkzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PGxpbmUgeDE9IjI2MCIgeTE9IjYzIiB4Mj0iMjgyIiB5Mj0iNjMiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxwYXRoIGQ9Ik0yNjAgMTI3IEgyNzEgVjE1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxODMgSDI3MSBWMTU1IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48bGluZSB4MT0iMzA2IiB5MT0iOTQiIHgyPSIzMDYiIHkyPSIxMjAiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMTEwIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxNTUiIHgyPSI1NjYiIHkyPSIxNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iMTU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU4MCIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNTgiIHgyPSI2OTkiIHkyPSIxNzIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMzgiIHgyPSI2OTkiIHkyPSIyNTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlCnNlbnMgYnJ1dCBlc3QgaW52ZXJzw6kgcGFyIHJhcHBvcnQgYXUgc2NvcmUgOiBuZSBqYW1haXMgbGlyZSBsYSBjb2xvbm5lCmJydXRlIGNvbW1lIHVuIHNjb3JlLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzQyIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5VbmUKY291cGUgcmFzZSBu4oCZZXN0IHBhcyBuw6ljZXNzYWlyZW1lbnQgdW5lIGFub21hbGllIOKAlCBUMyBww6luYWxpc2UgdW5lCnByYXRpcXVlIHN5bHZpY29sZSBsw6lnaXRpbWUuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNTgiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPm1pbl9wcm9iYQo9IDAsOSBlc3Qgc3RyaWN0IGV0IGTDqWxpYsOpcsOpIDogYWJhaXNzZXIgbGUgc2V1aWwgZmVyYWl0IGVudHJlciBkZXMKZMOpdGVjdGlvbnMgZG91dGV1c2VzLjwvdGV4dD48L3N2Zz4=)

Un des six indicateurs — R1 à R5 et lui — dont la normalisation retourne
le sens. La colonne brute mesure une pression de coupe ; le score, lui,
mesure son absence — deux lectures opposées du même nombre.

## 7. Références internes

| Sujet           | Fichier                                                   |
|-----------------|-----------------------------------------------------------|
| Fonction T3     | `R/indicators-temporal.R:335-430`                         |
| Inversion       | `R/normalization.R`, branche `indicateur_t3_coupes_rases` |
| Source déclarée | `inst/datasources/FR.json` — `sufosat`                    |
| Spécification   | `specs/030-coupes-rases-sufosat/`                         |
