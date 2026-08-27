# Fiche indicateur R5 - Deperissement (FORDEAD / RECONFORT)

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** : calculé seulement si un pipeline
> sanitaire a tourné (spec 008, ADR-013).

> ### Le sens de la famille R, corrigé en 0.181.0
>
> **R1 à R5 sont orientés « haut = mauvais » à l’état brut** et sont
> **inversés** à la normalisation (`score = 100 − valeur`). **R6 et R7
> ne le sont pas** — ils sont déjà « haut = bon » à la source. Jusqu’à
> 0.181.0, seul R5 était inversé, si bien qu’il pointait à l’opposé des
> quatre autres dans sa propre famille et qu’une UGF très exposée
> obtenait un `famille_risque` flatteur (spec 048).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `R5` |
| Nom long / colonne | `indicateur_r5_deperissement` |
| Famille | **R — Risques & Résilience** |
| Grandeur mesurée | Intensité du dépérissement détecté sur l’unité |
| Unité brute | **0–100, haut = fort dépérissement** |
| Sens | **inversé** |
| Fonction | [`indicateur_r5_deperissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md) — `R/indicators-deperissement.R:72` |
| Colonne annexe | `r5_status` |
| Applicabilité | [`r5_applicabilite()`](https://pobsteta.github.io/nemeton/reference/r5_applicabilite.md) |

## 2. Le calcul

    Pour chaque UGF :
      fraction_resineux (ou feuillus) >= min_*  ?  sinon  R5 = NA, status = skipped_no_resineux
      intersection des centroides de clusters d'alerte avec l'UGF
      R5 = somme( poids[classe] x aire_cluster / surface_UGF )  plafonnee a 1, x 100

Deux pipelines alimentent R5 :

| Pipeline | Cible | Poids de confiance |
|----|----|----|
| **FORDEAD** (CRSWIR + harmonique) | résineux — épicéa, sapin pectiné | `FORDEAD_CONFIDENCE_WEIGHTS` = 0,10 / 0,30 / **0,82** / 0,70 |
| **RECONFORT** | feuillus (chêne…) | `RECONFORT_CONFIDENCE_WEIGHTS` |

Seuils par défaut : `min_resineux = min_feuillus = 0,3`.

### Le garde-fou G1, activé par défaut

`include_low_classes = FALSE` : **seules les classes `3-forte` et
`4-sol-nu` sont comptées**. Les classes `1-faible` et `2-moyenne` sont
écartées parce que le rapport ONF/DSF 2024 (Bernard & Doridant, 397
relevés terrain) y mesure **50 % et un tiers de faux positifs**. Les
pondérations 0,10 / 0,30 / 0,82 / 0,70 sont directement calibrées sur ce
rapport.

**Statuts possibles** : `calculated`, `skipped_no_resineux`,
`skipped_no_fordead`.

## 3. Le calcul par niveau NDP

| NDP | Ce qui existe | R5 |
|----|----|----|
| **0** sans pipeline | rien | **`NA`** |
| **0** + FORDEAD / RECONFORT | Sentinel-2, séries temporelles | **calculé** |
| **1–2** | — | inchangé : le signal est spectral |
| **3** | **validation QField** (garde-fou G4) | les alertes sont confirmées ou infirmées sur le terrain |
| **4** | — | — |

## 4. Quatre pièges

1.  **Détection précoce médiocre**, mesurée : **60 % des stades précoces
    sont ratés** (rapport ONF/DSF 2024). Un R5 favorable ne dit pas
    qu’il n’y a pas de dépérissement — il dit qu’aucune anomalie franche
    n’a été détectée.
2.  **Confusion avec la perturbation mécanique** : 25 à 41 % selon
    l’altération.
    [`classify_disturbance()`](https://pobsteta.github.io/nemeton/reference/classify_disturbance.md)
    (garde-fou G2) croise FORDEAD et la fenêtre rolling-window pour
    trancher `mechanical` / `progressive` / `recent_event`.
3.  **`NA` ne veut pas dire « sain ».** Trois causes distinctes se
    cachent derrière : pas de pipeline, pas assez de résineux (ou de
    feuillus), pas d’alertes. **Toujours lire `r5_status` avant de
    conclure.**
4.  **Le seuil de 30 % d’essence cible exclut les peuplements
    mélangés.** Une futaie à 25 % d’épicéa dépérissant sort
    `skipped_no_resineux`, donc `NA`.

## 5. Aval

    indicateur_r5_deperissement()  ->  colonnes R5 (0-100, haut = deperissement) et r5_status
          |
          +- normalize_indicator()     -> 100 - valeur
          +- create_family_index("R")  -> famille_risque

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R5 | `R/indicators-deperissement.R:72` |
| Pipelines | [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md), [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md) |
| Garde-fous G1/G2 | [`list_alerts()`](https://pobsteta.github.io/nemeton/reference/list_alerts.md), [`classify_disturbance()`](https://pobsteta.github.io/nemeton/reference/classify_disturbance.md) |
| Validation terrain G4 | [`generate_health_validation_plots()`](https://pobsteta.github.io/nemeton/reference/generate_health_validation_plots.md), [`ingest_health_validation()`](https://pobsteta.github.io/nemeton/reference/ingest_health_validation.md) |
| Validité géographique | [`check_fordead_validity()`](https://pobsteta.github.io/nemeton/reference/check_fordead_validity.md), [`check_reconfort_validity()`](https://pobsteta.github.io/nemeton/reference/check_reconfort_validity.md) |
| Spécification | `specs/008-suivi-sanitaire/`, ADR-013 |
