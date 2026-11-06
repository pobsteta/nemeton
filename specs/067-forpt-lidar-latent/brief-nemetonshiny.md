# Brief `nemetonshiny` — B5, stratification verticale (spec 067)

> **Statut** : livré en cœur **2026.11.5**. Écart n° 26 de `PLAN.md`.

## Ce que l'app reçoit

1. **B5** (famille B, conditionnel, source `lidar`). Colonnes `B5` (0-100,
   haut = profil vertical équilibré) et `b5_status` : `calculated`,
   `skipped_no_lidar`, `skipped_no_coverage`, `skipped_low_density`.
   Libellés, infobulle, `doc_url` (fiche B5) et sens viennent de
   `indicator_labels()` / `indicator_families()` : **aucune table à toucher**.
   À prévoir : traduction des quatre statuts, couche B5 sur la carte.
2. **Profil vertical** : `b5_s1` à `b5_s5`, part des strates 0,5-2, 2-5, 5-10,
   10-20 et > 20 m (somme 1). Proposé : un petit histogramme horizontal dans la
   fiche de l'UGF. `b5_densite` (retours par m²) à afficher à côté : sous
   ~10 retours/m², les sous-étages des peuplements fermés sont sous-estimés.
3. **Activation** : passer `nuage =` à `nemeton_compute()` (dossier
   `<projet>/cache/layers/lidar_nuage`, avec `normaliser = TRUE` pour les
   dalles brutes de l'IGN ; lidR doit être installé). Sans nuage, B5 est `NA`
   et la famille B est inchangée.
4. **Recalcul** : un projet qui reçoit un nuage voit sa famille B compter un
   indicateur de plus. Pas de palier `INDICATOR_SENSE_VERSION`.

## Plus tard (même spec)

Badge de dimensionnement drone dans l'onglet terrain
(`simulate_density_sensitivity()`), N5 structurel (`n5_source = "forpt"`), N4.
