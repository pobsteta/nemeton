# Spec 039 — `regen_rank_species()` : top-N essences par UGF

**Version** : 1.0.0
**Date**    : 2026-07-16
**Statut**  : **Cœur implémenté** (v0.162.0).
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` — `regen_rank_species()` + `regen_rank_to_wide()`.
**Cible app**  : `nemetonshiny` — top-3 par UGF (P1 déterministe) + conseil IA (P2).
**Origine** : brief `brief-nemeton-regen-rank-species.md` (demande app reGénération).

## 1. Objectif

Proposer, par UGF, les **N essences les plus pertinentes** pour la régénération.
Approche **hybride** : classement **déterministe** au cœur (cette spec) + narratif
IA en surcouche app (phase 2, hors cœur).

## 2. Fonctions

- `regen_rank_species(units, species_pool, top_n, weights, exclude_invasive,
  region, cover_col, lai_col, extinction_k, id_col, include_atlas, ...)` → data.frame
  **long** (une ligne par UGF × rang) : `ug_id, rank, species_code, label, type,
  suitability (0-100), limiting_factor, confidence, invasif`.
- `regen_rank_to_wide(ranked, top_n)` → une ligne par UGF, colonnes
  `essence_r / score_r / label_r / facteur_r`.

## 3. Modèle de scoring (3 axes 0-100, haut = bon)

Suitability (UGF × essence) = moyenne **pondérée renormalisée sur les axes
présents** (poids défaut `chaleur_secheresse = 0.5, gel = 0.3, ombre = 0.2`).

### 3.a — Chaleur & sécheresse (toujours)
Réutilise les seuils de `indice_priorite_regen()` (`.REGEN_TOL_SPAN`), **loi du
minimum de Liebig** (l'axe est plafonné par le pire stress) :
- chaleur : `p_heat = clamp01((tmax_moyenne + d_tmax − tmax_tol_c) / span_tmax)` ;
- VPD atm. : `p_vpd = clamp01((vpd_canicule − vpd_tol_kpa) / span_vpd)` ;
- sécheresse édaphique : `p_drought = clamp01(1 − rew_min) × (1 − cap(drought_tol))`
  (REW bas × essence peu tolérante) ;
- `axisA = 100 × (1 − max(p_heat, p_vpd, p_drought))`.

### 3.b — Gel tardif (si `R7` ou `r7_gel_days`) — **différencie les essences**
Décision : le trait **`frost_late`** existe déjà par essence dans
`european_species_tolerances.csv` (contrairement à ce que supposait le brief) et
différencie bien (hêtre `frost_late=1` sensible, chêne `4` résistant). L'axe
croise la pression gel de la station avec la sensibilité de l'essence :
- `frost_press = clamp01(1 − R7/100)` (repli `r7_gel_days / 15`) ;
- `p_frost = frost_press × (1 − cap(frost_late))` ; `axisB = 100 × (1 − p_frost)`.

### 3.c — Ombre (OPTIONNELLE) — densité de couvert par UGF
Décision : pas de densité de canopée fiable par UGF dans le contrat station
(`couverture_pct` = complétude microclim, pas densité). L'axe n'est calculé que si
`units` porte une densité :
- `cover_col` (fraction 0-1, ou 0-100 auto-rééchelonnée), **ou**
- `lai_col` (LAI/PAI — **déjà produit par le pipeline**, `pai_depuis_nuage` /
  `lai_sentinel2`) converti par **Beer-Lambert** `cover = 1 − exp(−k·LAI)` (k=0.5) ;
- `p_shade = cover × (1 − cap(shade_tol))` ; `axisC = 100 × (1 − p_shade)`.

Sans entrée de densité, l'axe est **omis** (moyenne renormalisée sur A+B) et
`shade_tol` sert de **départage déterministe** du classement.

### 3.d — Confiance & exclusions
- `exclude_invasive = TRUE` retire les `invasif`.
- `confidence` **propagée** en sortie (jamais fondue dans le score — l'app/IA doit
  pouvoir signaler une reco à confiance faible, cohérent φ/NDP ADR-011).

`cap(trait)` = `clamp01((clamp(trait, 1, 5) − 1) / 4)` (échelle Niinemets &
Valladares 1-5, haut = plus tolérant ; clampe un éventuel outlier de saisie).

## 4. Facteur limitant
`limiting_factor` = l'axe à la plus forte pénalité (`chaleur` | `secheresse` |
`gel` | `ombre`) — pour le badge app et le prompt IA. Toutes pénalités nulles → `NA`
(aucune contrainte). Départage : `suitability` desc, puis `confidence`, puis
`shade_tol`, puis `code` (déterminisme total, reproductibilité scientifique).

## 5. Garde-fous
- UGF sans données station → `suitability = NA`, `rank = NA` (pas de reco
  fabriquée), une ligne par UGF.
- Pool vide après exclusions → 0 ligne, pas d'erreur.
- Déterministe (aucun aléa).

## 6. Tests (`test-regen-rank-species.R`)
Pool explicite + UGF contrastées, valeurs calculées à la main : classement
thermophile-first sur UGF chaude/sèche, `exclude_invasive`, NA-safe, pool vide,
gel qui différencie par `frost_late`, ombre via `lai_col`, override des poids,
pivot wide, résolution `frost_late` depuis la table UE pour un pool de codes.

## 7. Suivi app `nemetonshiny` (après release cœur — hors ce repo, brief §7)
- **P1 déterministe** : `service_regeneration.R` appelle `regen_rank_species()`
  (passer `lai_col` = colonne LAI/PAI par UGF pour activer l'axe ombre) ; top-3 par
  UGF dans la fiche parcelle (badges facteur limitant + confiance/invasif) ; couche
  carte « meilleure essence ».
- **P2 IA (opt-in)** : « Conseil de régénération IA » — prompt = top-3 déterministe
  + profil de station + profil expert → reco justifiée courte.

## 8. Hors-scope
- Le narratif IA (P2, app).
- Toute nouvelle acquisition de données (l'axe ombre consomme un LAI **déjà**
  produit par le pipeline ; il n'est pas acquis ici).
