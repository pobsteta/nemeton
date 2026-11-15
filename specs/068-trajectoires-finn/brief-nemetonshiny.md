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

---

# Brief `nemetonshiny` — T4, vitalité dynamique (spec 068)

> **Statut** : livré en cœur **2026.11.28**. 44 indicateurs, dont 13
> conditionnels.

## Ce que l'app reçoit

`indicateur_t4_vitalite(units, forms_t, essence, ser)` rend `T4` (0-100,
50 = croissance attendue, haut = bon, **pas d'inversion**) et
`t4_status`, `t4_accroissement_obs`, `t4_accroissement_att` (m / 5 ans),
`t4_h_dom` (m), `t4_n_analogues`. T4 apparaît dans
`list_indicators()` / `indicator_families()` / `indicator_labels()`
(libellé, info-bulle, lien vers la fiche `fiche-t4-vitalite_fr`).

## Ce qui marche déjà

`service_compute.R` passe `forms_t` à toute fonction qui a ce formel (bloc
« Série FORMS-T », vers la ligne 5233) : T4 reçoit la série que
`start_computation()` met dans `layers$rasters$forms_t` pour T2.

## À faire côté app

1. **Essence dominante en codes IFN `ESPAR`** (`"03"` chêne sessile,
   `"09"` hêtre, `"61"` sapin, `"62"` épicéa, `"52"` pin sylvestre...),
   dans une colonne `essence` des unités ou passée en argument. Sans elle,
   T4 vaut `NA` (`skipped_no_essence`). Le TFV « Sapin, épicéa » de la
   BD Forêt est ambigu : à Dabo, le coder 61 ou 62 change peu la médiane
   (57 ou 56), mais une classification d'essences fera mieux.
2. **SER** dans une colonne `ser` (déjà calculée pour P2 en mode IFN).
   Sans elle, les analogues sont pris dans toutes les SER.
3. **Coupes** : si T3 est calculé avant T4, sa colonne `T3` suffit (T4 lit
   `units$T3 > 0`). Sinon passer `coupes =`.
4. **Statuts à traduire** : `skipped_no_forms_t`, `skipped_no_coverage`,
   `skipped_cut`, `skipped_drop` (chute de plus de 3 m),
   `skipped_no_essence`, `skipped_no_analogues` (surtout les peuplements de
   plus de 33 m).
5. **Affichage** : à côté du score, l'accroissement observé et l'attendu
   (`t4_accroissement_obs` / `t4_accroissement_att`, en m sur 5 ans). Mention
   fixe : référence construite en Bourgogne-Franche-Comté, climat
   2019-2023 ; à Dabo (Vosges), T4 se centre vers 57.
6. **NDP 3** : avec un inventaire de l'UGF, `accroissement_hdom_finn()`
   (FINN, libtorch) puis l'argument `attendu` remplace les analogues. Hors
   NDP 0 de l'app pour l'instant.
