# Fiche indicateur R4 - Pression d'abroutissement

> **Document de référence** — Néméton (package cœur), 2026-08-27.

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
| Code | `R4` |
| Nom long / colonne | `indicateur_r4_abroutissement` |
| Famille | **R — Risques & Résilience** |
| Grandeur mesurée | Pression du grand gibier sur la régénération |
| Unité brute | **0–100, haut = forte pression** |
| Sens | **inversé** |
| Fonction | [`indicateur_r4_abroutissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r4_abroutissement.md) — `R/indicators-risk.R:920` |

## 2. Le calcul — quatre composantes à poids fixes

Les poids viennent du tutoriel 03 et ne sont **pas** paramétrables :

| Composante | Poids | Source |
|----|----|----|
| **Appétence** de l’essence | **0,35** | `get_species_palatability()` sur l’essence dominante BD Forêt |
| **Vulnérabilité** du peuplement | **0,30** | stade et structure |
| **Effet de lisière** | **0,20** | géométrie et voisinage |
| **Densité de gibier** | **0,15** | tableaux de chasse départementaux (`hunting`) |

Colonnes annexes : `R4_palatability`, et les composantes intermédiaires.

## 3. Le calcul par niveau NDP

| NDP | Ce qui change |
|----|----|
| **0** | BD Forêt + tableaux de chasse départementaux |
| **1** | contours de massif justes → lisière mieux calculée |
| **2** | — |
| **3** | **enclos-exclos et relevés d’abroutissement** sur placette : la seule mesure directe |
| **4** | — |

R4 est le seul indicateur de la famille R dont la vérité terrain est un
**dispositif expérimental** (enclos-exclos), pas une observation
ponctuelle.

## 4. Trois pièges

1.  **La densité de gibier est départementale.** Les tableaux de chasse
    sont agrégés à l’échelle du département : toutes les unités d’un
    même département partagent cette composante (15 % du score). La
    pression réelle varie fortement d’un massif à l’autre à l’intérieur
    d’un département.
2.  **L’appétence porte sur l’essence *dominante* du peuplement
    adulte**, pas sur la régénération présente. Or c’est le semis qui
    est abrouti. Une futaie de hêtre régénérée en sapin sera notée sur
    le hêtre.
3.  **Les poids sont figés dans le code.** Aucun argument ne les expose
    : un utilisateur qui juge la densité de gibier plus déterminante que
    l’appétence ne peut pas le refléter sans modifier le paquet.

## 5. Aval

    indicateur_r4_abroutissement()  ->  colonne R4 (0-100, haut = pression)
          |
          +- normalize_indicator()     -> 100 - valeur
          +- create_family_index("R")  -> famille_risque

R4 est l’indicateur prioritaire du profil **chasseur**
(`profil_chasseur` : R4, B, N).

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R4 | `R/indicators-risk.R:920-1060` |
| Appétence par essence | `get_species_palatability()` — `R/species-config.R` |
| Densité de gibier | [`download_hunting_data()`](https://pobsteta.github.io/nemeton/reference/download_hunting_data.md), [`compute_game_pressure_index()`](https://pobsteta.github.io/nemeton/reference/compute_game_pressure_index.md), [`get_game_pressure_raster()`](https://pobsteta.github.io/nemeton/reference/get_game_pressure_raster.md) |
