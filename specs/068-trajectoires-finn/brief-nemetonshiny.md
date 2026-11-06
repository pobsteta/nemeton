# Brief `nemetonshiny` — effets de la gestion (spec 068)

> **Statut** : livré en cœur **2026.11.8**. Écart n° 27 de `PLAN.md`.

## Ce que l'app reçoit

`effet_gestion(units, traitement = "type_sylviculture", reference = ...)`
rend :

- `$resume` : par type de gestion comparé à la référence et par famille,
  `effet_moyen`, `ic_bas`, `ic_haut` (90 %), `n_traite`, `n_reference`,
  `part_support`, `statut` (`calcule`, `recouvrement_insuffisant`,
  `trop_peu_unites`) ;
- `$unites` : l'effet estimé UGF par UGF (`support` logique, `NA` hors
  support).

## Proposé

- Dans la synthèse, un tableau « ce que la gestion a produit sur ce massif »,
  une ligne par famille, l'intervalle **avant** le chiffre, et le statut
  traduit quand le calcul est refusé (ne rien afficher d'autre dans ce cas).
- Mention fixe sous le tableau : association ajustée sur la station, pas une
  preuve causale.
- Pour `aigora` : ces résultats sont des **résultats du projet** que le skill
  `sylviculteur` peut citer, jamais quand le statut n'est pas `calcule`.
- Calcul à la demande (quelques dizaines de secondes avec ranger), pas à
  chaque affichage. Il faut une colonne de type de gestion déclaré sur les
  UGF : l'app doit la proposer à la saisie si elle n'existe pas.
