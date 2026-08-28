# Fiche indicateur F1 - Fertilite des sols

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `F1` |
| Nom long / colonne | `indicateur_f1_fertilite` |
| Famille | **F — Fertilité des sols** (avec F2) |
| Grandeur mesurée | Fertilité du sol |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_f1_fertilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_f1_fertilite.md) — `R/indicators-families.R:1147` |

> **Rappel de la correction 0.18x (spec 049)** : la table
> `INDICATOR_FAMILIES` portait le créneau **F1 avec le libellé « Risque
> d’érosion »** et la colonne `indicateur_f2_erosion`, et inversement
> pour F2. Trois sources sur quatre disaient pourtant F1 = fertilité.
> Les deux erreurs s’annulaient à l’affichage, mais un appelant
> normalisant par code court obtenait la règle de la fertilité pour une
> colonne d’érosion. **Aucune valeur persistée n’était fausse**, aucun
> recalcul n’a été nécessaire — mais si vous lisez un code antérieur à
> ce correctif, méfiez-vous du sens de `F1`.

## 2. Quatre sources, choisies par `source`

Contrairement à C1, F1 **ne devine pas** : la source est un argument
explicite.

| `source` | Entrée | Chaîne de calcul |
|----|----|----|
| `"layer"` (défaut) | couche `soil` raster **ou** vecteur | moyenne zonale de `fertility_col`, ramenée à 0–100 |
| `"soilgrids"` | SoilGrids 2.0 (CEC) | `extract_fertility_from_soilgrids()` → [`cec_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/cec_to_fertility_score.md) |
| `"gissol"` | GIS Sol / RPF | `extract_fertility_from_gissol()` via `rpf_code_col` |
| `"theia_soil"` | textures Theia (argile, limon, sable) | [`texture_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/texture_to_fertility_score.md) |

Une source demandée sans son entrée lève une **erreur** — F1 ne se rabat
pas silencieusement sur une autre.

**Exemples chiffrés** (voie texture) :

| Texture dominante      | Lecture                      | F1        |
|------------------------|------------------------------|-----------|
| Limon argileux profond | réserve utile et CEC élevées | **80–90** |
| Limon moyen            | station ordinaire            | **55–65** |
| Sable dominant         | réserve utile faible         | **25–35** |
| Sol squelettique       | —                            | **\< 20** |

Les valeurs exactes viennent des tables :
`inst/extdata/uts_fertilite_fr.csv` et sa calibration RMQS
(`uts_fertilite_rmqs_calibration.csv`).

## 3. Le calcul par niveau NDP

| NDP | Source réaliste | Ce qui change |
|----|----|----|
| **0** | SoilGrids 2.0 (250 m) ou textures Theia | modèle global, pas d’observation locale |
| **1** | GIS Sol / RPF si disponible | typologie régionale |
| **2** | sondages à la tarière au drone d’accès | — |
| **3** | **analyses de sol** sur placettes | seule vraie mesure : CEC, pH, granulométrie |
| **4** | profils pédologiques complets | — |

F1 est l’un des rares indicateurs où **le NDP 3 change réellement la
nature de la donnée** : jusque-là, la fertilité est déduite d’un modèle
spatialisé ; au NDP 3, elle est analysée en laboratoire.

## 4. Trois pièges

1.  **Quatre sources, quatre échelles implicites.** Un F1 issu de
    SoilGrids (CEC) et un F1 issu des textures Theia ne sont pas la même
    grandeur ramenée sur 0–100 : ce sont deux modèles distincts.
    Comparer deux projets suppose la **même** `source`.
2.  **SoilGrids est un modèle global à 250 m.** Sur une parcelle
    forestière de quelques hectares, la valeur extraite est souvent
    celle d’un ou deux pixels interpolés à l’échelle du continent.
    Utilisable pour classer des unités entre elles, pas pour décider
    d’un amendement.
3.  **La profondeur n’est pas dans la valeur.** SoilGrids et Theia
    fournissent des horizons (0-5, 5-15, … cm) que la chaîne agrège ; un
    sol superficiel sur dalle calcaire et un limon profond de même
    composition de surface rendent des F1 voisins. C’est la limite
    structurelle de la voie satellitaire/modélisée.

## 5. Aval

    indicateur_f1_fertilite()  ->  colonne indicateur_f1_fertilite (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("F")  -> famille_fertilite = moy(F1, F2)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDQxMiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBGMSA6IHF1YXRyZSBzb3VyY2VzIGRlIGZlcnRpbGl0ZSDigJQgY291Y2hlIGZvdXJuaWUsIFNvaWxHcmlkcywgR0lTIFNvbCwgdGV4dHVyZXMgVGhlaWEg4oCUIHNvbnQgc2VsZWN0aW9ubmVlcyBwYXIgdW4gYXJndW1lbnQgZXhwbGljaXRlIGV0IG5vbiBwYXIgdW5lIGNhc2NhZGUsIGNoYWN1bmUgYXZlYyBzYSBwcm9wcmUgZWNoZWxsZSBpbXBsaWNpdGUgOyB1bmUgc291cmNlIGRlbWFuZGVlIHNhbnMgc29uIGVudHJlZSBsZXZlIHVuZSBlcnJldXIgYXUgbGlldSBkZSBzZSByYWJhdHRyZS4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCBNT0RFUwpFWENMVVNJRlM8L3RleHQ+PHRleHQgeD0iNTg4IiB5PSIxNiI+QVZBTDwvdGV4dD48L2c+PHJlY3QgeD0iOCIgeT0iMzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Db3VjaGUKc29pbCAocmFzdGVyIG91IHNmKTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jb2xvbm5lCmZlcnRpbGl0eV9jb2w8L3RleHQ+PHJlY3QgeD0iOCIgeT0iOTAiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTA5IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+U29pbEdyaWRzCjIuMCDigJQgQ0VDPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb2TDqGxlCmdsb2JhbCwgbWFpbGxlIDI1MCBtPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE0NiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxNjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5HSVMKU29sIC8gUlBGPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxODEiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij52aWEKcnBmX2NvZGVfY29sPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjIwMiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIyMjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5UZXh0dXJlcwpUaGVpYTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMjM3IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YXJnaWxlLApsaW1vbiwgc2FibGU8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5zb3VyY2UKPSDigJxsYXllcuKAnSAoZMOpZmF1dCk8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCnpvbmFsZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnJhbWVuw6llCnN1ciAw4oCTMTAwPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTI2IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5zb3VyY2UKPSDigJxzb2lsZ3JpZHPigJ08L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNjEiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y2VjX3RvX2ZlcnRpbGl0eV9zY29yZSgpPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMjAyIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIyMjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5zb3VyY2UKPSDigJxnaXNzb2zigJ08L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIyMzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZXh0cmFjdF9mZXJ0aWxpdHlfZnJvbV9naXNzb2woKTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjI3OCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMjk3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+c291cmNlCj0g4oCcdGhlaWFfc29pbOKAnTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjMxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij50ZXh0dXJlX3RvX2ZlcnRpbGl0eV9zY29yZSgpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMzI5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnRhYmxlcwp1dHNfZmVydGlsaXRlX2ZyPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfZjFfZmVydGlsaXRlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2NvcmUKMOKAkzEwMCwgbmF0aWY8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOpY3LDqnRhZ2UKbmF0aWYgMOKAkzEwMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE2MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxG4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX3NvbDwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIEYxIGV0IEYyPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxwYXRoIGQ9Ik0yNjAgNTUgSDI3MSBWNjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTExIEgyNzEgVjE0NyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxNjcgSDI3MSBWMjIzIEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDIyMyBIMjcxIFYzMDcgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI5NCIgeDI9IjMwNiIgeTI9IjEyMCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjExMCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+b3U8L3RleHQ+PGxpbmUgeDE9IjMwNiIgeTE9IjE3MCIgeDI9IjMwNiIgeTI9IjE5NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjE4NiIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+b3U8L3RleHQ+PGxpbmUgeDE9IjMwNiIgeTE9IjI0NiIgeDI9IjMwNiIgeTI9IjI3MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjI2MiIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+b3U8L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE0NyIgeDI9IjU2NiIgeTI9IjE0NyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMjIzIiB4Mj0iNTY2IiB5Mj0iMjIzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIzMDciIHgyPSI1NjYiIHkyPSIzMDciIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iMzA3IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU4MCIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNDIiIHgyPSI2OTkiIHkyPSIxNTYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMjIiIHgyPSI2OTkiIHkyPSIyMzYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzNjIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlF1YXRyZQpzb3VyY2VzLCBxdWF0cmUgw6ljaGVsbGVzIGltcGxpY2l0ZXMgOiB1biBGMSBTb2lsR3JpZHMgZXQgdW4gRjEgdGV4dHVyZQpuZSBzZSBjb21wYXJlbnQgcGFzLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzc4IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5Tb2lsR3JpZHMKZXN0IHVuIG1vZMOobGUgZ2xvYmFsIMOgIDI1MCBtIOKAlCB1bmUgcGFyY2VsbGUgeSB0aWVudCBkYW5zIHF1ZWxxdWVzIHBpeGVscwpsaXNzw6lzLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzk0IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5MYQpwcm9mb25kZXVyIGRlIHNvbCBu4oCZZXN0IHBhcyBkYW5zIGxhIHZhbGV1ciA6IGRldXggc3RhdGlvbnMgZGUgcsOpc2VydmUKdXRpbGUgb3Bwb3PDqWUgcGV1dmVudCByZW5kcmUgbGUgbcOqbWUgRjEuPC90ZXh0Pjwvc3ZnPg==)

Un aiguillage explicite, pas une cascade. `source` est un argument :
l’indicateur ne se rabat jamais tout seul, il échoue — c’est ce qui rend
la provenance lisible, à condition de la consigner avec la valeur.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction F1 et ses quatre sources | `R/indicators-families.R:1147-1310` |
| CEC → score | [`cec_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/cec_to_fertility_score.md) — `:1311` |
| Texture → score | [`texture_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/texture_to_fertility_score.md) — `:1362` |
| Tables | `inst/extdata/uts_fertilite_fr.csv`, `uts_fertilite_rmqs_calibration.csv` |
| Sources déclarées | `soilgrids_*`, `theia_soil` — `inst/datasources/FR.json` |
| Correction du croisement F1/F2 | `NEWS.md`, spec 049 |
