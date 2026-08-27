# Fiche indicateur N2 - Continuite ecologique

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `N2` |
| Nom long / colonne | `indicateur_n2_continuite` |
| Famille | **N — Naturalité** |
| Grandeur mesurée | Continuité forestière dans le temps (ancienneté du couvert) |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md) — `R/indicators-naturalness.R:115` |
| Entrées | `bdforet` **et/ou** `foret_ancienne` — sans aucune des deux, `NA` |

## 2. Le calcul

N2 croise le couvert forestier **actuel** (BD Forêt) avec le couvert
**historique** (`foret_ancienne`). Une forêt présente aux deux époques
est continue ; une forêt récente sur ancienne terre agricole ne l’est
pas.

La couche historique peut être :

- **mono-époque** — un simple masque de forêt ancienne ;
- **multi-époques** — produite par
  [`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)
  (spec 031, à partir des images **Corona** et des cartes d’état-major),
  et portant alors une colonne `anciennete`. L’argument
  `weight_anciennete` permet de pondérer par le nombre d’époques où le
  couvert était présent.

## 3. Le calcul par niveau NDP

| NDP | Sources historiques | Ce qui change |
|----|----|----|
| **0** | carte d’état-major (~1850) | une seule époque |
| **0 +** | **+ Corona (~1965)** via [`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md) | deux époques : la continuité devient graduée |
| **1–2** | — | la continuité est une donnée historique, pas un capteur |
| **3** | archives locales, cadastre napoléonien | — |
| **4** | — | — |

Comme B1 et T1, N2 dépend d’une donnée **d’archive**, que la résolution
moderne n’améliore pas.

## 4. Trois pièges

1.  **`NA` quand ni `bdforet` ni `foret_ancienne` ne sont fournis** — le
    code refuse de produire une continuité par défaut.
2.  **La continuité n’est pas la naturalité.** Une plantation d’épicéa
    installée en 1850 sur un site forestier ancien obtient un N2 élevé.
    N2 mesure la **permanence du couvert**, pas son caractère spontané.
3.  **N2 alimente T2 en proxy de stabilité.** Quand la colonne `N2` est
    présente,
    [`indicateur_t2_changement()`](https://pobsteta.github.io/nemeton/reference/indicateur_t2_changement.md)
    la recopie telle quelle. La même grandeur pèse alors dans
    `famille_naturalite` **et** dans `famille_temporelle`.

## 5. Aval

    indicateur_n2_continuite()  ->  colonne N2 (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("N")  -> famille_naturalite
          +- alimente N3 (poids 0,35) et T2 (proxy)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction N2 | `R/indicators-naturalness.R:115-224` |
| Masque de forêt ancienne | [`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md), [`load_foret_ancienne_source()`](https://pobsteta.github.io/nemeton/reference/load_foret_ancienne_source.md) |
| Spécification | `specs/031-foret-ancienne-corona/` |
