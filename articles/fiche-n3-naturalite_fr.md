# Fiche indicateur N3 - Naturalite composite

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> **Cette fiche documente une incohérence de sens active** (§4, piège n°
> 1).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `N3` |
| Nom long / colonne | `indicateur_n3_naturalite` |
| Famille | **N — Naturalité** |
| Grandeur mesurée | Indice composite de naturalité |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_n3_naturalite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n3_naturalite.md) — `R/indicators-naturalness.R:226` |
| Entrées obligatoires | colonnes **N1, N2, L1 et B3** — l’une manque → `NA` |

## 2. Le calcul

    anti_frag = 100 - L1

    N3 = 0,35 x N1 + 0,35 x N2 + 0,15 x anti_frag + 0,15 x B3

Pondération issue du tutoriel 04. **N3 est un composite de quatre autres
indicateurs** — dont deux appartiennent à d’autres familles (L1 pour
Paysage, B3 pour Biodiversité).

**Exemple chiffré** :

| Entrée              | Valeur | Contribution |
|---------------------|--------|--------------|
| N1 (éloignement)    | 70     | 24,5         |
| N2 (continuité)     | 80     | 28,0         |
| L1 = 30 → anti_frag | 70     | 10,5         |
| B3 (connectivité)   | 60     | 9,0          |
| **N3**              |        | **72,0**     |

## 3. Le calcul par niveau NDP

N3 hérite du NDP le plus faible de ses quatre entrées. En pratique,
c’est **B3** qui le plafonne, puisqu’il exige la BD Forêt et trois
paquets optionnels (cf. sa fiche).

## 4. Trois pièges, dont une incohérence de sens

1.  **L1 est lu en sens inverse par N3 et par la normalisation.** N3
    calcule `anti_frag = 100 − L1`, ce qui suppose **L1 élevé = beaucoup
    de lisière = défavorable**. C’est cohérent avec le calcul de L1
    (indice de forme élevé + matrice contrastée + exposition → score
    élevé) et avec son infobulle (« Proportion de la parcelle sous
    influence des lisières \[…\] fragmentent l’habitat intérieur »).

    Mais `indicateur_l1_effet_lisiere` est déclaré dans
    `.NORMALIZE_NATIVE_0_100` : la normalisation le laisse passer tel
    quel, **comme si un L1 élevé était favorable**. Le radar et
    `famille_paysage` lisent donc L1 à l’endroit où N3, le calcul et
    l’infobulle le lisent à l’envers.

    > Conséquence : une parcelle en lanière bordée de bâti obtient un
    > **L1 élevé**, que le radar affiche comme un bon score de paysage —
    > alors que le même chiffre, injecté dans N3, la pénalise. C’est
    > exactement le défaut corrigé pour R5 en 0.181.0 (spec 048) et pour
    > les noms de la famille L en 0.176.0 (spec 045), à un endroit qui
    > n’a pas été revu.

2.  **N3 est un composite, donc il double-compte.** N1 et N2 pèsent 35 %
    chacun dans N3 **et** un tiers chacun dans `famille_naturalite`, où
    N3 pèse aussi un tiers. N1 et N2 comptent donc environ **45 %**
    chacun dans le score de famille, au lieu d’un tiers.

3.  **`NA` dès qu’une des quatre entrées manque**, sans calcul partiel.
    C’est voulu (« returning NA — no measurement made »), mais cela rend
    N3 fragile : il suffit que B3 soit `NA` faute de BD Forêt pour que
    N3 le soit aussi.

## 5. Aval

    indicateur_n3_naturalite()  ->  colonne N3 (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("N")  -> famille_naturalite = moy(N1, N2, N3)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction N3 | `R/indicators-naturalness.R:226-256` |
| Entrées | [`indicateur_n1_distance()`](https://pobsteta.github.io/nemeton/reference/indicateur_n1_distance.md), [`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md), [`indicateur_l1_effet_lisiere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_effet_lisiere.md), [`indicateur_b3_connectivite()`](https://pobsteta.github.io/nemeton/reference/indicateur_b3_connectivite.md) |
| Déclaration de L1 en « natif 0-100 » | `R/normalization.R:521` |
| Précédents comparables | spec 048 (sens de R5), spec 045 (noms de la famille L) |
