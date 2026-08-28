# Fiche indicateur F2 - Resistance a l'erosion

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `F2` |
| Nom long / colonne | `indicateur_f2_erosion` |
| Famille | **F — Fertilité des sols** |
| Grandeur mesurée | **Résistance** à l’érosion (haut = risque plus faible) |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_f2_erosion()`](https://pobsteta.github.io/nemeton/reference/indicateur_f2_erosion.md) — `R/indicators-families.R:1583` |

> **Le nom trompe, et la doc l’a longtemps fait aussi.** L’indicateur
> s’appelle « érosion » mais **un score élevé est bon** : il mesure une
> résistance, pas un risque. Jusqu’au correctif de la spec 049, sa
> documentation annonçait rendre des « fertility scores (higher = more
> fertile) » et journalisait « Computing fertility from TWI + slope » —
> copié-collé depuis F1.

## 2. Le calcul

    TWI       = moyenne zonale du TWI                    cache partage W2/W3/F2/R3
    pente     = moyenne zonale de terrain(dem, "slope")  degres

    twi_norm   = ecrete((TWI - 2,5) / 7,5 x 100, 0, 100)
    slope_norm = ecrete(100 - pente / 45 x 100, 0, 100)

    F2 = moyenne(twi_norm, slope_norm)   [+ composante texturale si `texture` fourni]

Les ingrédients sont **topographiques** — TWI et pente — plus une
résistance texturale optionnelle issue de Theia
([`texture_to_erosion_resistance()`](https://pobsteta.github.io/nemeton/reference/texture_to_erosion_resistance.md)).
La couverture végétale **n’entre pas** dans le calcul, contrairement à
ce que l’ancienne infobulle laissait croire.

**Exemples chiffrés** :

| Situation                          | TWI | Pente | twi_norm | slope_norm | F2       |
|------------------------------------|-----|-------|----------|------------|----------|
| Plateau, sol drainant              | 4,0 | 3°    | 20,0     | 93,3       | **56,7** |
| Bas de versant humide, pente douce | 7,0 | 8°    | 60,0     | 82,2       | **71,1** |
| Versant raide                      | 3,2 | 30°   | 9,3      | 33,3       | **21,3** |
| Ravin très pentu                   | 2,8 | 42°   | 4,0      | 6,7        | **5,4**  |

## 3. Le calcul par niveau NDP

| NDP | MNT | Ce qui change |
|----|----|----|
| **0** | MNT 25 m | pente moyennée sur 25 m : les ruptures disparaissent |
| **1** | **LiDAR HD** | pente et TWI à l’échelle du micro-relief — la vraie rupture |
| **2** | LiDAR drone | ravines et ornières de débardage visibles |
| **3** | observation terrain | signes d’érosion constatés |
| **4** | — | — |

Comme W3, F2 est **très sensible à la résolution du MNT** : la pente
moyenne d’une unité augmente mécaniquement quand le MNT s’affine. Un
projet qui passe au LiDAR HD verra F2 baisser sans qu’aucun sol n’ait
bougé.

## 4. Trois pièges

1.  **Deux fenêtres de TWI coexistent dans le paquet.** F2 normalise le
    TWI sur `[2,5 ; 10]` alors que **W3 le normalise sur `[2,5 ; 4,5]`**
    et que W2 le seuille à 12. Trois conventions pour le même raster. Un
    TWI de 5 vaut 33 dans F2 et 100 dans W3 : ne jamais transposer une
    lecture de l’un à l’autre.
2.  **Un TWI élevé améliore la résistance à l’érosion dans ce calcul.**
    Le commentaire du code dit « higher TWI = more fertile » — hérité de
    F1. Un TWI élevé signale une zone d’accumulation, ce qui est
    cohérent avec « peu érodable » (le matériau s’y dépose plutôt qu’il
    n’en part), mais le raisonnement n’est pas explicité et mérite
    validation terrain.
3.  **La pente moyenne d’une unité masque les ruptures.** Une parcelle
    plate coupée d’un talus de 20 m rend une pente moyenne faible et un
    F2 flatteur, alors que tout le risque est concentré sur le talus.

## 5. Aval

    indicateur_f2_erosion()  ->  colonne indicateur_f2_erosion (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("F")  -> famille_fertilite = moy(F1, F2)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBGMiA6IGRldXggaW5ncmVkaWVudHMgdG9wb2dyYXBoaXF1ZXMg4oCUIFRXSSBldCBwZW50ZSBtb3llbm5lIOKAlCBzb250IG5vcm1hbGlzZXMgc2VwYXJlbWVudCBwdWlzIG1veWVubmVzIHBvdXIgcHJvZHVpcmUgdW5lIHJlc2lzdGFuY2UgYSBsJiMzOTtlcm9zaW9uLCBvdSB1biBzY29yZSBoYXV0IGVzdCBib24gOyBsYSBjb3V2ZXJ0dXJlIHZlZ2V0YWxlIG4mIzM5O2VudHJlIHBhcyBkYW5zIGxlIGNhbGN1bC4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCDDiVRBUEVTClNVQ0NFU1NJVkVTPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+VFdJCihjYWNoZSBwYXJ0YWfDqSk8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y29tbXVuCsOgIFcyLCBXMywgRjIgZXQgUjM8L3RleHQ+PHJlY3QgeD0iOCIgeT0iOTAiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTA5IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+TU5UCuKAlCBwZW50ZTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTI1IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+dGVycmFpbihkZW0sCuKAnHNsb3Bl4oCdKSwgZW4gZGVncsOpczwvdGV4dD48cmVjdCB4PSI4IiB5PSIxNDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIxNjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5UZXh0dXJlcwpUaGVpYSAob3B0aW9ubmVsKTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTgxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+dGV4dHVyZV90b19lcm9zaW9uX3Jlc2lzdGFuY2UoKTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkRldXgKbm9ybWFsaXNhdGlvbnM8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij50d2lfbm9ybQo9IChUV0ktMiw1KS83LDUgw5cgMTAwPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2xvcGVfbm9ybQo9IDEwMCAtIHBlbnRlLzQ1IMOXIDEwMDwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjEyNiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+TW95ZW5uZQpkZXMgY29tcG9zYW50ZXM8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNjEiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+RjIKPSBtb3kodHdpX25vcm0sIHNsb3BlX25vcm0pPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPisKcsOpc2lzdGFuY2UgdGV4dHVyYWxlIHNpIGZvdXJuaWU8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl9mMl9lcm9zaW9uPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2NvcmUKMOKAkzEwMCwgbmF0aWY8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOpY3LDqnRhZ2UKbmF0aWYgMOKAkzEwMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE2MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxG4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX3NvbDwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIEYxIGV0IEYyPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxwYXRoIGQ9Ik0yNjAgNTUgSDI3MSBWNjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTExIEgyNzEgVjE1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxNjcgSDI3MSBWMTU1IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48bGluZSB4MT0iMzA2IiB5MT0iOTQiIHgyPSIzMDYiIHkyPSIxMjAiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMTEwIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxNTUiIHgyPSI1NjYiIHkyPSIxNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iMTU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU4MCIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNDIiIHgyPSI2OTkiIHkyPSIxNTYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMjIiIHgyPSI2OTkiIHkyPSIyMzYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMTAiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlCm5vbSB0cm9tcGUgOiBGMiBtZXN1cmUgdW5lIHLDqXNpc3RhbmNlLCB1biBzY29yZSBoYXV0IGVzdCBib24uPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkRldXgKZmVuw6p0cmVzIGRlIFRXSSBjb2V4aXN0ZW50IGRhbnMgbGUgcGFxdWV0IOKAlCBGMiBub3JtYWxpc2Ugc3VyIFsyLDUgOyAxMF0sClczIHN1ciBbMiw1IDsgNCw1XS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM0MiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGEKcGVudGUgbW95ZW5uZSBtYXNxdWUgbGVzIHJ1cHR1cmVzIDogdW5lIHBhcmNlbGxlIHBsYXRlIMOgIHRhbHVzIHJhaWRlCnJlbmQgdW4gRjIgcmFzc3VyYW50LjwvdGV4dD48L3N2Zz4=)

Deux ingrédients, aucun couvert. F2 est un score de terrain, pas de
peuplement : la même topographie donne la même valeur sous futaie fermée
et après coupe rase.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction F2 | `R/indicators-families.R:1583-1680` |
| TWI partagé | `get_or_compute_twi()` — cache W2/W3/F2/R3 |
| Composante texturale | [`texture_to_erosion_resistance()`](https://pobsteta.github.io/nemeton/reference/texture_to_erosion_resistance.md) |
| Correction du sens et de la doc | `NEWS.md`, spec 049 |
