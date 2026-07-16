# Spec 038 — Normaliser tous les indicateurs à 0-100 (focus R6)

**Version** : 1.0.0
**Date**    : 2026-07-16
**Statut**  : **Cœur implémenté** (v0.161.0).
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` — `regen_sensibilite()` + `normalize_indicator()`.
**Cible app**  : `nemetonshiny` — injecter la colonne 0-100 + intégrer R6/R7 au score
(voir `brief-nemeton-normalisation-r6.md`, §5, à faire après release cœur).
**Origine** : brief app `brief-nemeton-normalisation-r6.md` (session `nemetonshiny`).

## 1. Problème

La famille R affiche/décompte R1-R7, mais seuls R1-R5 entrent dans le **score de
famille** (`create_family_index`). R6 (sensibilité microclimatique) et R7 (gel
tardif) manquent au score. Objectif utilisateur : **intégrer tous les indicateurs
au score, donc normaliser chaque indicateur dès qu'il est calculé**.

Cause racine identifiée : `normalize_indicator()` a un **repli naïf** `clamp(0,100)`
pour tout nom non traité. La reGénération persiste `sensibilite` = un **z-score
projet-relatif non borné** (~[-4,4]), que l'app injecte dans
`indicateur_r6_sensibilite` ; le clamp le mutile (négatifs → 0, positifs → 0-4 ≈
quasi-nul). R7 (`indicateur_r7_gel`, déjà 0-100) passait, mais **par accident** via
le même repli.

## 2. Décision — normaliser à la source (2.a)

Plutôt que de rafistoler le z-score au moment du scoring, on **normalise dès le
calcul** : `regen_sensibilite()` persiste une colonne 0-100 **`sensibilite_score`**
réutilisant la formule bornée déjà en place dans `indicateur_r6_sensibilite()` sur
les mêmes ΔT°max/ΔVPD, avec les **mêmes échelles** `.MICRO_BOUNDS$r6` (source
unique). Le z-score `sensibilite` reste conservé pour le **rang**
(`rang_sensibilite`, `parcelle_sensible`, `priorite`).

- Sémantique famille : *haut = favorable* (peu sensible) —
  `sensibilite_score = 100 * (1 - clamp01(0.5·sT + 0.5·sV))`,
  `sT = clamp01(ΔT°max / scale_t)`, `sV = clamp01(ΔVPD / scale_v)`,
  `(scale_t, scale_v) = (8, 2)`.
- Valeur **absolue** (bornes fixes), pas projet-relative → consommable directement
  par le score de famille.

## 3. Livrables cœur (v0.161.0)

### 3.a — R6 à la source
- `R/regen_engines.R` : helper interne `.regen_sensibilite_score(d_tmax, d_vpd,
  bounds = .MICRO_BOUNDS$r6)` (NA-safe). Colonne `sensibilite_score` ajoutée au
  contrat `.REGEN_COLS_EXPO`, calculée dans le **chemin engine** (après le z-score)
  et dérivée dans le **chemin precomputed** (si `d_tmax`/`d_vpd` présents et colonne
  absente ; portée verbatim si fournie).

### 3.b — R6/R7 explicites dans `normalize_indicator()`
- `R/normalization.R` : cases explicites
  `c("indicateur_r6_sensibilite", "R6", "sensibilite_score")` et
  `c("indicateur_r7_gel", "R7")` → passthrough `clamp(0,100)` (pas d'inversion,
  ≠ R5/T3). Ne dépendent plus du repli naïf.

### 3.c — Filet de sécurité « aucun indicateur non normalisé »
- Registre `.NORMALIZE_NATIVE_0_100` : liste blanche explicite des indicateurs
  produisant nativement 0-100 (repli légitime). Tout **indicateur connu** (colonne
  de `INDICATOR_FAMILIES` via `get_all_column_names()`) qui atteint le repli sans y
  être déclaré déclenche un `cli::cli_warn()` → détecte les futurs oublis. Un nom
  non-indicateur reste silencieux.

## 4. Tests
- `regen_sensibilite()` : `sensibilite_score` borné [0,100], monotone décroissant
  avec la sensibilité, NA-safe, clamp des deltas négatifs, portée verbatim.
- `normalize_indicator()` R6/R7 : bornes + direction (pas d'inversion).
- Couverture 2.c : aucun des 31+ indicateurs de `INDICATOR_FAMILIES` ne déclenche
  l'avertissement ; un indicateur connu non déclaré avertit ; un non-indicateur non.

## 5. Suivi app (après release cœur — hors ce repo)
Voir `brief-nemeton-normalisation-r6.md` §5 : injecter `sensibilite_score` dans
`indicateur_r6_sensibilite` (au lieu du z-score), câbler `add_regen_r_indicators`
après `add_r5_to_indicators` dans `family_scores()` pour que R6/R7 entrent dans
`create_family_index`, vérifier le décompte récap / radar (famille R : R1-R5 →
R1-R7).

## 6. Hors-scope
- Aucun changement au **rang** de sensibilité (`rang_sensibilite`, `priorite`) : le
  z-score reste la base du classement ; on n'ajoute qu'une vue 0-100.
- Aucune modification de la pondération Fibonacci / φ ni du NDP.
