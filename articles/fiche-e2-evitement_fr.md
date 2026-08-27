# Fiche indicateur E2 - Evitement carbone

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `E2` |
| Nom long / colonne | `indicateur_e2_evitement` |
| Famille | **E — Énergie & Climat** |
| Grandeur mesurée | Émissions fossiles évitées par substitution |
| Unité brute | **tonnes CO₂eq / ha / an** |
| Sens | Haut = favorable |
| Normalisation | `ref_max = 0,75` → `score = min(100, t / 0,75 × 100)` |
| Fonction | [`indicateur_e2_evitement()`](https://pobsteta.github.io/nemeton/reference/indicateur_e2_evitement.md) — `R/indicators-energy.R:130` |
| Colonnes annexes | `E2_energy`, `E2_material` |

## 2. Le calcul — deux voies de substitution

    Substitution ENERGIE :
      kWh          = t_MS_bois_energie x 4 500                  pouvoir calorifique
      CO2 evite    = kWh x facteur_ADEME / 1000                 defaut 0,222 kgCO2eq/kWh

    Substitution MATERIAU :
      a partir du volume de bois d'oeuvre, facteur ADEME correspondant

    E2 = E2_energy + E2_material

Les facteurs viennent de `inst/extdata/ademe_emission_factors.csv` via
`lookup_ademe_factor()`, avec un scénario énergétique paramétrable. Le
repli **0,222 kgCO₂eq/kWh** est appliqué si la table ne répond pas.

**Exemples chiffrés** :

| E1 (t MS/ha/an) | kWh/ha/an | CO₂ évité  | Score    |
|-----------------|-----------|------------|----------|
| 0,12            | 540       | **0,12 t** | **16,0** |
| 0,24            | 1 080     | **0,24 t** | **32,0** |
| 0,41            | 1 845     | **0,41 t** | **54,6** |

## 3. Le calcul par niveau NDP

E2 hérite du NDP d’**E1**, donc de **P1**. La chaîne complète est
`CHM → P1 → E1 → E2` : la qualité de l’estimation de hauteur se propage
jusqu’au bilan carbone évité.

## 4. Trois pièges

1.  **La chaîne d’hypothèses est longue et multiplicative.** Taux de
    récolte (2 %), fraction de rémanents (30 %), matière sèche (50 %),
    pouvoir calorifique (4 500 kWh/t), facteur d’émission (0,222) : cinq
    constantes en cascade. Une erreur de 20 % sur chacune donne un
    facteur 2,5 sur E2.
2.  **Le facteur de substitution énergétique dépend de l’énergie
    remplacée.** 0,222 kgCO₂eq/kWh correspond à un mix ; remplacer du
    fioul ou de l’électricité française donne des valeurs très
    différentes. Le scénario est paramétrable — le laisser par défaut
    est un choix, pas une neutralité.
3.  **E2 est un flux évité, pas un stock.** Il ne se cumule pas avec C1
    (stock de carbone aérien) : additionner les deux serait un double
    comptage.

## 5. Aval

    indicateur_e2_evitement()  ->  colonnes E2, E2_energy, E2_material
          |
          +- normalize_indicator()     -> min(100, t / 0,75 x 100)
          +- create_family_index("E")  -> famille_energie = moy(E1, E2)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction E2 | `R/indicators-energy.R:130-260` |
| Facteurs d’émission | `inst/extdata/ademe_emission_factors.csv` |
| Gisement amont | [`vignette("fiche-e1-bois-energie_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-e1-bois-energie_fr.md) |
