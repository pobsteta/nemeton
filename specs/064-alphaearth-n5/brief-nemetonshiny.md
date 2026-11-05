# Brief `nemetonshiny` — modèles de fondation (specs 064 et 065)

> **Statut** : **préavis**. Specs 064 et 065 validées le 2026-11-05, code non livré.
> Aucune fonction cœur n'existe encore ; ce brief annonce ce qui viendra pour
> que l'app puisse préparer ses écrans, et ouvre les écarts n° 20 à 24 de
> `PLAN.md` **avant** la première release (leçon des écarts n° 10 et 11).
> Rien à coder tant que la release cœur n'est pas publiée. Un brief définitif suivra chaque release.

## Ce que l'app recevra (spec 064, chantier A)

1. **N5 — distance à la référence** (famille N, conditionnel).
   Colonnes `N5`, `n5_status` (`no_embedding`, `no_reference`,
   `reference_too_small`, `ok`), `n5_source`, `n5_reference`, `n5_annee`.
   Libellés, `doc_url` et sens viendront de `indicator_labels()` /
   `indicator_families()` comme pour tout indicateur (dé-fork de l'écart n° 1) :
   **aucune table à toucher**. À prévoir : traduction des quatre statuts, et la
   couche N5 sur la carte. **Écart n° 20.**
2. **B4 / L3 en mode embedding.** Nouvelle colonne `b4_methode` /
   `l3_methode` (`biodivmapr`, `embedding`). Les deux méthodes ne se comparent
   pas : la fiche de l'UGF doit afficher la méthode à côté de la valeur.
   L'interdit de l'écart n° 6 (pas de comparaison inter-projets) tombe
   **seulement** pour la méthode `embedding`. **Écart n° 21.**
3. **Flag NDP `embedding_ml`** dans `detect_ndp()$augmented`, au même titre
   que `height_ml`. Le badge NDP doit le connaître. **Écart n° 22.**
4. **Recalcul** : un projet existant qui reçoit un embedding verra sa famille
   N changer (un indicateur de plus dans la moyenne). Pas de palier
   `INDICATOR_SENSE_VERSION` (aucun sens ne change), mais un message à
   l'utilisateur serait utile.

## Ce que l'app recevra (spec 065, étape 4)

5. **Itinéraires admissibles** par UGF, avec la raison de chaque exclusion
   (codes fermés : `station_insuffisante`, `hors_ser`, `essence_absente`,
   `pente`, `desserte`, `statut_protection`, `source_manquante`,
   `donnee_manquante`). Vue proposée : onglet plan d'actions. **Écart n° 23.**
6. **Comparaison pondérée** des itinéraires sous un profil. Selon la
   décision D-1 de la spec 065, les **poids par famille** des profils
   pourraient migrer dans le cœur (`inst/extdata/profils_poids.json`) ; les
   prompts et libellés resteraient dans `inst/experts/`. Question à l'app :
   les poids actuels des 13 profils sont-ils écrits quelque part sous forme
   numérique, ou seulement dans le texte des prompts ? **Écart n° 24.**
   `score_global` est un **rang** (effets qualitatifs) : à ne pas afficher
   comme une note sur 100.

## Plus tard (chantiers B, C, D : specs à venir)

Vue « Ce que les modèles voient » (table des sondes), trajectoires FINN dans
le plan d'actions, badge de dimensionnement drone dans l'onglet terrain.
Aucun écart ouvert pour eux tant que leurs specs n'existent pas.
