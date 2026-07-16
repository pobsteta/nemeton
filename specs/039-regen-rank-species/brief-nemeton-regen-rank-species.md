# Brief cœur `nemeton` — `regen_rank_species()` : top‑N essences par UGF

**Date** : 2026-07-16
**Repo cible** : `nemeton` (cœur métier — adéquation écologique = logique métier).
**Origine** : demande app `nemetonshiny` — dans reGénération, proposer par UGF les
**3 essences les plus pertinentes** pour la régénération. Décision produit :
approche **hybride** = classement DÉTERMINISTE au cœur + narratif IA en surcouche
(app, phase 2). Ce brief ne couvre que la **brique cœur déterministe**.

## 1. Ce qui existe déjà (à réutiliser, pas réinventer)

- `regen_species_choices(units, level, region, include_atlas, …)` → pool d'essences
  candidates avec traits : `code`, `label`, `species_sci`, `type`, `species_class`,
  `tmax_tol_c`, `vpd_tol_kpa`, `shade_tol`, `drought_tol`, `confidence`, `invasif`,
  `present`, `statut`, `groupe`.
- `regeneration_tolerances()` → tolérances par classe d'essence.
- `indice_priorite_regen(units, species = …, tolerances = …)` → score **une** essence
  par UGF : `.regen_resolve_tol(species)` puis pénalité sur
  `tmax_abs = tmax_moyenne + d_tmax` vs `tmax_tol_c` et `vpd_canicule` vs `vpd_tol_kpa`
  (spans `.REGEN_TOL_SPAN`). C'est le **cœur du scoring** à généraliser.
- Conditions de station par UGF (colonnes produites par le moteur reGénération) :
  `tmax_moyenne`, `d_tmax`, `vpd_canicule`, `rew_min`, `njstress`, `r7_gel_days`,
  `R7`, `couverture_pct`, `ug_id`.

## 2. Fonction demandée

```r
regen_rank_species(units,
                   species_pool = NULL,   # défaut : regen_species_choices(units, ...)
                   top_n        = 3,
                   weights      = NULL,   # pondération des 4 axes (cf. §3)
                   exclude_invasive = TRUE,
                   region       = "BFC",
                   tolerances   = NULL,
                   ...)
```

**Sortie** (recommandé : data.frame **long**, une ligne par (UGF × rang), + helper
de pivot) :

| ug_id | rank | species_code | label | type | suitability | limiting_factor | confidence | invasif |
|-------|------|--------------|-------|------|-------------|-----------------|------------|---------|

- `suitability` : 0-100 (haut = mieux adapté), agrégé des 4 axes.
- `limiting_factor` : l'axe qui plafonne l'essence sur cette UGF
  (`chaleur` | `secheresse` | `gel` | `ombre`), pour l'affichage app (badge) et le
  prompt IA.
- Prévoir un helper `regen_rank_to_wide(ranked, top_n)` → colonnes
  `essence_1/score_1/…` jointes sur `ug_id` (pratique pour la table app).

## 3. Les 4 axes d'adéquation (décision produit — les 4 retenus)

Score par (UGF × essence) = agrégation pondérable de 4 sous-scores 0-100 (haut = bon) :

**3.a — Chaleur & sécheresse** (réutilise `indice_priorite_regen`)
- Chaleur : pénalité `clamp01((tmax_abs - tmax_tol_c)/span_tmax)`,
  `tmax_abs = tmax_moyenne + d_tmax`.
- VPD : `clamp01((vpd_canicule - vpd_tol_kpa)/span_vpd)`.
- Sécheresse édaphique : croiser `rew_min` (réserve en eau minimale) avec
  `drought_tol` de l'essence — définir un mapping (p.ex. déficit = `rew_min` bas +
  `drought_tol` faible → pénalité). **À spécifier au cœur** (échelle de `rew_min`).
- Sous-score = `100 * (1 - max(pénalités))`.

**3.b — Gel tardif (R7)** — ⚠️ **lacune data à trancher**
- La station fournit `r7_gel_days` (jours de gel post-débourrement). Mais **pour
  différencier les essences**, il faut un **trait de phénologie/sensibilité au gel**
  par essence (débourrement précoce vs tardif) — **absent** de
  `regen_species_choices()` aujourd'hui.
- Deux options :
  - **(préféré)** ajouter une colonne `budburst_doy` (ou `frost_sensitivity`) à la
    table des tolérances → pénalité gel = fonction de `r7_gel_days` × sensibilité
    de l'essence.
  - **(repli P1)** appliquer `r7_gel_days` comme **modificateur de station uniforme**
    (pénalise toutes les essences pareil sur UGF gélive) → n'ordonne pas les essences
    entre elles sur le gel mais baisse leur adéquation globale. Documenter la limite.

**3.c — Tolérance à l'ombre** — ⚠️ **entrée station à préciser**
- `shade_tol` existe par essence. Il faut un **proxy de couvert résiduel** par UGF
  (régénération sous couvert vs en plein). `couverture_pct` du moteur = complétude
  microclim, **pas** la densité de canopée → ne convient pas tel quel.
- Option P1 : exposer `shade_tol` comme **critère secondaire / départage** (tie-break)
  plutôt que pondération dure, tant qu'un indice de densité de couvert par UGF n'est
  pas disponible. Sinon, définir l'entrée densité (LAI/CHM déjà dans le pipeline ?).

**3.d — Confiance & exclusions**
- `exclude_invasive = TRUE` : retirer `invasif == TRUE` du pool.
- Filtrer optionnellement sur `present`/atlas régional (`include_atlas`).
- **Porter `confidence`** dans la sortie (ne pas fondre dans le score) : l'app et l'IA
  doivent pouvoir signaler une reco « à confiance faible ». Cohérent avec la
  philosophie φ/NDP (ADR-011).

`weights` par défaut : proposer un jeu documenté (p.ex. chaleur/sécheresse 0.5,
gel 0.25, ombre 0.15, confiance en pénalité douce 0.10), ajustable.

## 4. Garde-fous

- UGF sans données de station (`d_tmax`/`vpd` NA) → `suitability = NA`, `rank = NA`
  (pas de reco fabriquée) — best-effort, NA-safe.
- Pool vide après exclusions → retour vide propre (0 ligne), pas d'erreur.
- Déterminisme total (aucun aléa) — reproductibilité (publication scientifique).

## 5. Tests cœur

- Scoring monotone : une essence dont `tmax_tol_c` < `tmax_abs` de l'UGF est pénalisée ;
  au-dessus du seuil, non.
- `top_n` respecté ; tri par `suitability` décroissante ; `limiting_factor` correct.
- `exclude_invasive` retire bien les invasives ; `confidence` propagée.
- NA-safe (station manquante), pool vide, `region` sans essence.

## 6. Livrables cœur

- `regen_rank_species()` + `regen_rank_to_wide()` exportées, roxygen EN.
- Le cas échéant, colonne `budburst_doy`/`frost_sensitivity` dans la table tolérances
  (§3.b option préférée) + éventuel proxy densité de couvert (§3.c).
- NEWS + bump cœur, `PLAN.md` cœur (nouveau sous-chantier), release `nemeton@vX.Y.Z`.
- **Ordre cœur → app** (règle 11).

## 7. Suivi app `nemetonshiny` (après release cœur — hors de ce brief)

- **P1 (déterministe)** : `R/service_regeneration.R` appelle `regen_rank_species()` ;
  affichage du top-3 par UGF dans la fiche parcelle (badges facteur limitant +
  confiance/invasif) ; couche carte « meilleure essence » (catégorielle).
- **P2 (IA, opt-in)** : « Conseil de régénération IA » — prompt = top-3 déterministe
  + profil de station + profil expert sélectionné → reco justifiée courte (pourquoi
  ces essences, risques, mélange, réserves). Réutilise ellmer/profils experts.
- i18n, tests testServer, versioning app selon règles.
