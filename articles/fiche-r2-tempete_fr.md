# Fiche indicateur R2 - Vulnerabilite aux tempetes

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
| Code | `R2` |
| Nom long / colonne | `indicateur_r2_tempete` |
| Famille | **R — Risques & Résilience** |
| Grandeur mesurée | Vulnérabilité au chablis |
| Unité brute | **0–100, haut = vulnérable** |
| Sens | **inversé** |
| Fonction | [`indicateur_r2_tempete()`](https://pobsteta.github.io/nemeton/reference/indicateur_r2_tempete.md) — `R/indicators-risk.R:395` |
| Entrée obligatoire | un **MNT** — sans lui, `NA` |

## 2. Le calcul

    R2 = exposition_vent x (0,6 x pente_norm + 0,4 x TRI_norm) x 100

- **exposition au vent** : direction dominante via
  `get_nasapower_wind()` (défaut **270°**, ouest, si l’API n’est pas
  jointe), affinée par
  [`microclima::windcoef()`](https://rdrr.io/pkg/microclima/man/windcoef.html)
  quand le paquet est présent ;
- **pente** et **TRI** (Terrain Ruggedness Index) issus du MNT.

### Modulation par la canopée (spec 005, argument `chm`)

    f = (H_dom / h_reference) x facteur_essence      resineux 1,2 | feuillus 0,8

Un peuplement haut et résineux est plus vulnérable : c’est la relation
hauteur × essence qui pilote le facteur. Sans `chm`, la modulation ne
s’applique pas (`f = 1`).

## 3. Le calcul par niveau NDP

| NDP | Ce qui change |
|----|----|
| **0** | MNT 25 m, pas de hauteur — la vulnérabilité est purement topographique |
| **0 augmenté** `height_ml` | CHM ML → **modulation par la hauteur réelle** |
| **1** | MNT + MNH LiDAR HD : topographie *et* canopée mesurées |
| **2** | MNH drone |
| **3** | \+ hauteurs et essences relevées |
| **4** | — |

> **C’est l’un des indicateurs où le CHM public change le plus la
> lecture** : sans hauteur, deux peuplements sur le même versant sont
> identiquement vulnérables, qu’il s’agisse d’un semis ou d’une futaie
> d’épicéa de 35 m.

## 4. Trois pièges

1.  **La direction du vent par défaut est 270° en dur.** Si NASA POWER
    n’est pas joignable, tout le projet est calculé « vent d’ouest ».
    Sur un massif où les tempêtes dommageables viennent du nord-ouest ou
    du sud, l’exposition est fausse — sans message d’erreur.
2.  **`microclima` est optionnel**, et son absence change le coefficient
    d’abri. Même motif de bascule silencieuse que R1 et L2.
3.  **La modulation canopée est multiplicative et non bornée par le
    bas.** Un `H_dom` faible réduit fortement `f`, si bien qu’une coupe
    rase ressort « peu vulnérable » — ce qui est exact pour le chablis,
    mais peut se lire à tort comme une qualité.

## 5. Aval

    indicateur_r2_tempete()  ->  colonne R2 (0-100, haut = vulnerable)
          |
          +- normalize_indicator()     -> 100 - valeur
          +- create_family_index("R")  -> famille_risque

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM3NiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBSMiA6IHVuZSBleHBvc2l0aW9uIGF1IHZlbnQsIHByaXNlIGEgbCYjMzk7b3Vlc3QgcGFyIGRlZmF1dCBxdWFuZCBsJiMzOTtBUEkgTkFTQSBQT1dFUiBuZSByZXBvbmQgcGFzLCBtdWx0aXBsaWUgdW4gdGVybWUgZGUgcmVsaWVmIG1lbGFudCBwZW50ZSBldCBydWdvc2l0ZSwgbGUgdG91dCBtb2R1bGUgcGFyIGxhIGhhdXRldXIgZG9taW5hbnRlIGV0IGwmIzM5O2Vzc2VuY2UgcXVhbmQgdW4gQ0hNIGVzdCBmb3VybmkuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgw4lUQVBFUwpTVUNDRVNTSVZFUzwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPk1OVArigJQgb2JsaWdhdG9pcmU8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+cGVudGUKZXQgVFJJIDsgc2FucyBsdWksIE5BPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjkwIiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEwOSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmdldF9uYXNhcG93ZXJfd2luZCgpPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5kaXJlY3Rpb24KZG9taW5hbnRlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxNDEiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5kw6lmYXV0CjI3MMKwIChvdWVzdCkgZW4gZHVyPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE2MiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNITQpNTCAob3B0aW9ubmVsKTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+SF9kb20KZXQgZXNzZW5jZSBkb21pbmFudGU8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5UZXJtZQpkZSByZWxpZWY8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij4wLDYKw5cgcGVudGUgKyAwLDQgw5cgVFJJPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTEwIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxMjkiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5FeHBvc2l0aW9uCmF1IHZlbnQ8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+w5cKZXhwb3NpdGlvbl92ZW50IMOXIDEwMDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5taWNyb2NsaW1hOjp3aW5kY29lZigpCnNpIHByw6lzZW50PC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMjAyIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgLz48dGV4dCB4PSIzMDAiIHk9IjIyMSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPk1vZHVsYXRpb24KY2Fub3DDqWU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIyMzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Zgo9IChIX2RvbSAvIGhfcmVmKSDDlyBlc3NlbmNlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjUzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnLDqXNpbmV1eAoxLDIgwrcgZmV1aWxsdXMgMCw4PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfcjJfdGVtcGV0ZTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmJydXQKOiBoYXV0ID0gdnVsbsOpcmFibGU8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNjb3JlCj0gMTAwIC0gdmFsZXVyPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTQ5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlIxCsOgIFI1IChzcGVjIDA0OCk8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNzgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcUuKAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9yaXNxdWU8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpkZSBSMSDDoCBSNzwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjI1OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMjc3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y29tcHV0ZV9nZW5lcmFsX2luZGV4KCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyOTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Rmlib25hY2NpCsK3IGNvbmZpYW5jZSDPhjwvdGV4dD48bGluZSB4MT0iMjYwIiB5MT0iNTUiIHgyPSIyODIiIHkyPSI1NSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHBhdGggZD0iTTI2MCAxMTkgSDI3MSBWMTM5IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDE4MyBIMjcxIFYyMzEgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI3OCIgeDI9IjMwNiIgeTI9IjEwNCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSI5NCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+cHVpczwvdGV4dD48bGluZSB4MT0iMzA2IiB5MT0iMTcwIiB4Mj0iMzA2IiB5Mj0iMTk2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjE4NiIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+cHVpczwvdGV4dD48bGluZSB4MT0iNTUwIiB5MT0iNTUiIHgyPSI1NjYiIHkyPSI1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMTM5IiB4Mj0iNTY2IiB5Mj0iMTM5IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIyMzEiIHgyPSI1NjYiIHkyPSIyMzEiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjU1IiB4Mj0iNTY2IiB5Mj0iMjMxIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI1NSIgeDI9IjU4MCIgeTI9IjU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNTgiIHgyPSI2OTkiIHkyPSIxNzIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMzgiIHgyPSI2OTkiIHkyPSIyNTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPjI3MMKwCmVuIGR1ciA6IHNhbnMgcsOpcG9uc2UgZGUgTkFTQSBQT1dFUiwgdG91dCBsZSBtYXNzaWYgZXN0IHLDqXB1dMOpIGV4cG9zw6kgw6AKbOKAmW91ZXN0LjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzQyIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5taWNyb2NsaW1hCmVzdCBvcHRpb25uZWwsIGV0IHNvbiBhYnNlbmNlIGNoYW5nZSBsZSBjb2VmZmljaWVudCBk4oCZYWJyaSBzYW5zIGxlCmRpcmUuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNTgiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxhCm1vZHVsYXRpb24gY2Fub3DDqWUgZXN0IG11bHRpcGxpY2F0aXZlIGV0IG5vbiBib3Juw6llIHBhciBsZSBiYXMgOiB1biBDSE0KYmFzIGVmZmFjZSBsYSB2dWxuw6lyYWJpbGl0w6kuPC90ZXh0Pjwvc3ZnPg==)

Un produit, pas une somme : chaque facteur peut annuler les autres.
C’est ce qui rend R2 sensible à des entrées optionnelles — direction du
vent, coefficient d’abri, hauteur de canopée.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R2 | `R/indicators-risk.R:395-560` |
| Vent | `get_nasapower_wind()` |
| Interface CHM | [`extract_h_dom()`](https://pobsteta.github.io/nemeton/reference/extract_h_dom.md) — partagée avec C1, P1, P2, B2 |
| Correction du sens | `NEWS.md` 0.181.0, spec 048 |
