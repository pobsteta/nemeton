# Fiche indicateur R6 - Sensibilite microclimatique

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** à la chaîne microclimat (spec 027 L2,
> ADR-014). **Non inversé**, contrairement à R1–R5.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `R6` |
| Nom long / colonne | `indicateur_r6_sensibilite` |
| Famille | **R — Risques & Résilience** |
| Grandeur mesurée | Écart de stress thermique entre une année **caniculaire** et une année **moyenne**, canopée figée |
| Unité brute | **0–100, haut = peu sensible = résilient** |
| Sens | **non inversé** — passthrough écrêté |
| Fonction | [`indicateur_r6_sensibilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_r6_sensibilite.md) — `R/indicators-microclimate.R:217` |
| Bornes | `.MICRO_BOUNDS$r6 = c(scale_t = 8, scale_v = 2)` |
| Colonnes annexes | `R6_dtmax` (°C), `R6_dvpd` (kPa), `R6_couverture_pct` |

## 2. Le calcul

    dT   = Tmax_sous_couvert(canicule) - Tmax_sous_couvert(moyenne)     °C
    dVPD = VPD(canicule) - VPD(moyenne)                                  kPa
    R6   = 100 - standardisation(dT / 8, dVPD / 2)                       0-100, decroissant en sensibilite

**La canopée est tenue fixe entre les deux années** : ce qui varie est
le forçage climatique seul. R6 isole donc l’effet du climat, pas celui
d’une coupe.

Les deux années sont choisies par l’appelant — typiquement détectées
automatiquement sur la série estivale E-OBS via
[`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md).

**Exemples chiffrés** :

| Situation                    | ΔT°max | ΔVPD    | R6      |
|------------------------------|--------|---------|---------|
| Couvert fermé, forte inertie | 1,6 °C | 0,3 kPa | **~80** |
| Futaie ordinaire             | 3,2 °C | 0,8 kPa | **~55** |
| Peuplement clair, sol exposé | 5,6 °C | 1,5 kPa | **~27** |

## 3. Le calcul par niveau NDP

Comme A3, A4 et W4 : `NA` sans chaîne microclimat ; calculé dès qu’un
[`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
a tourné **sur deux années**. Le drapeau `microclimate_model` ne relève
pas le niveau NDP.

> **R6 exige deux exécutions du moteur**, une par année. C’est le plus
> coûteux des quatre indicateurs microclimatiques.

## 4. Trois pièges

1.  **R6 n’est pas inversé, et c’est facile à manquer.** Dans une
    famille où R1 à R5 le sont, R6 (et R7) passent en écrêtage simple
    parce qu’ils sont **déjà** orientés « haut = bon ». Le code le
    déclare explicitement dans `.NORMALIZE_RULED` pour que R6 ne retombe
    jamais sur la branche naïve.
2.  **Le piège historique du z-score.** Le score de sensibilité de la
    chaîne reGénération existe en deux versions : `sensibilite` (z-score
    non borné, ≈ \[−4, 4\]) et `sensibilite_score` (0–100). **Injecter
    le z-score dans la normalisation le mutile** — c’est le défaut
    corrigé par la spec 038. Toujours passer `sensibilite_score`.
3.  **Le choix des deux années détermine tout.** Une « année caniculaire
    » mal choisie (été chaud mais pas extrême) écrase l’écart et fait
    paraître toutes les unités résilientes.
    [`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md)
    documente son critère ; le vérifier avant d’interpréter.

## 5. Aval

    indicateur_r6_sensibilite()  ->  colonnes R6, R6_dtmax, R6_dvpd, R6_couverture_pct
          |
          +- normalize_indicator()     -> ecretage [0, 100], PAS d'inversion
          +- create_family_index("R")  -> famille_risque

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R6 | `R/indicators-microclimate.R:217` |
| Détection des années | [`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md), [`tendances_estivales_eobs()`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md) |
| Normalisation | `R/normalization.R`, branche R6 (spec 038) |
| Spécification | `specs/027-regeneration-microclimat/` L2, ADR-014 |
