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

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction F1 et ses quatre sources | `R/indicators-families.R:1147-1310` |
| CEC → score | [`cec_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/cec_to_fertility_score.md) — `:1311` |
| Texture → score | [`texture_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/texture_to_fertility_score.md) — `:1362` |
| Tables | `inst/extdata/uts_fertilite_fr.csv`, `uts_fertilite_rmqs_calibration.csv` |
| Sources déclarées | `soilgrids_*`, `theia_soil` — `inst/datasources/FR.json` |
| Correction du croisement F1/F2 | `NEWS.md`, spec 049 |
