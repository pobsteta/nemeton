# Fiche indicateur R1 - Risque d'incendie

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
| Code | `R1` |
| Nom long / colonne | `indicateur_r1_feu` |
| Famille | **R — Risques & Résilience** (7 indicateurs) |
| Grandeur mesurée | Aléa d’incendie |
| Unité brute | **0–100, haut = beaucoup de risque** |
| Sens | **inversé** : `score = 100 − valeur` |
| Fonction | [`indicateur_r1_feu()`](https://pobsteta.github.io/nemeton/reference/indicateur_r1_feu.md) — `R/indicators-risk.R:174` |
| Entrée obligatoire | un **MNT** — sans lui, `NA` |

## 2. Deux modes

| Mode | Condition | Composantes |
|----|----|----|
| **`fireexposuR`** | paquet installé (`Suggests`) **et** couche `bdforet` | exposition 0,50 · pente 0,25 · reste 0,25 |
| **Pondéré** (défaut) | sinon | pente 1/3 · essence 1/3 · climat 1/3 |

Mode `fireexposuR` : un masque d’aléa est rasterisé depuis la BD Forêt,
puis `fire_exp(hazard, t_dist = 500)` calcule l’exposition, ramenée sur
0–100.

Mode pondéré : la **pente** vient du MNT, l’**essence** de
`get_species_flammability()`, le **climat** d’un proxy NDVI ou
climatique. Les poids sont renormalisés pour sommer à 1.

## 3. Le calcul par niveau NDP

| NDP   | Ce qui change                                              |
|-------|------------------------------------------------------------|
| **0** | MNT 25 m + BD Forêt : pente grossière, essence typologique |
| **1** | MNT LiDAR HD : pente et exposition topographique réelles   |
| **2** | \+ structure du sous-étage au drone (combustible)          |
| **3** | inventaire du combustible sur placette                     |
| **4** | —                                                          |

## 4. Trois pièges

1.  **La pente retombe sur 50 si son calcul échoue**, sans avertissement
    — soit un tiers du score en mode pondéré. Même motif que B3, L1 et
    A2.
2.  **Les deux modes ne mesurent pas la même chose.** `fireexposuR`
    calcule une **exposition au front de feu** (voisinage combustible
    dans 500 m) ; le mode pondéré agrège pente, essence et climat. Le
    basculement dépend de la présence d’un `Suggests` — deux postes
    peuvent produire deux grandeurs sous le même nom.
3.  **Le combustible de surface n’entre nulle part.** Ni la strate
    herbacée, ni les rémanents, ni la continuité verticale — qui
    gouvernent le passage au feu de cime — ne sont représentés. R1 est
    un aléa **de contexte**, pas un diagnostic de combustibilité.

## 5. Aval

    indicateur_r1_feu()  ->  colonne R1 (0-100, haut = risque)
          |
          +- normalize_indicator()     -> 100 - valeur        (inversion)
          +- create_family_index("R")  -> famille_risque = moy(R1..R7, na.rm = TRUE)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R1 | `R/indicators-risk.R:174-390` |
| Inflammabilité par essence | `get_species_flammability()` — `R/species-config.R` |
| Inversion | `R/normalization.R`, bloc R1–R5 |
| Correction du sens | `NEWS.md` 0.181.0, spec 048 |
