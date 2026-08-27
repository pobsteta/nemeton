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

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R2 | `R/indicators-risk.R:395-560` |
| Vent | `get_nasapower_wind()` |
| Interface CHM | [`extract_h_dom()`](https://pobsteta.github.io/nemeton/reference/extract_h_dom.md) — partagée avec C1, P1, P2, B2 |
| Correction du sens | `NEWS.md` 0.181.0, spec 048 |
