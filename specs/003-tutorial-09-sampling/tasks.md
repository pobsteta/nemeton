# Tasks: Tutorial 09 - Échantillonnage LiDAR + TSP

**Feature**: Tutorial 09 - Échantillonnage de calibration LiDAR HD + optimisation TSP
**Created**: 2026-01-23
**Status**: Terminé

**Progress**: 50/50 tasks complete (100%)

---

## Phase 1: Données

**Purpose**: Utiliser les données existantes des tutoriels précédents

- [x] T001 Utiliser zone_etude.gpkg (T01)
- [x] T002 Utiliser bd_foret.gpkg avec tfv (T01)
- [x] T003 Utiliser mnt.tif et slope.tif (T01/T03)
- [x] T004 Utiliser chm_complet.tif (T07)
- [x] T005 Utiliser routes.gpkg BD TOPO (T01)
- [x] T006 Calculer TPI depuis MNT (focal)

---

## Phase 2: Structure tutoriel

- [x] T007 Créer inst/tutorials/09-sampling/
- [x] T008 Créer 09-sampling.Rmd avec header YAML
- [x] T009 Setup chunk avec packages et config
- [x] T010 Structure 5 sections + synthèse

---

## Phase 3: Section 1 - Configuration (exercices 1.x)

- [x] T011 Introduction et objectifs
- [x] T012 Schéma workflow (diagramme ASCII)
- [x] T013 Configuration éditable (config list)
- [x] T014 Calcul taille échantillon optimale (CV, formule)
- [x] T015 Quiz Section 1 (3 questions)

---

## Phase 4: Section 2 - Chargement données (exercices 1.x)

- [x] T016 Exercice 1.1 : Charger zone d'étude
- [x] T017 Exercice 1.2 : Charger BD Forêt v2
- [x] T018 Exercice 1.3 : Charger MNT et pente + CHM
- [x] T019 Exercice 1.4 : Charger routes BD TOPO
- [x] T020 Visualisation des données

---

## Phase 5: Section 3 - Sampling frame (exercices 2.x)

- [x] T021 Exercice 2.1 : Générer grille candidats
- [x] T022 Fonction calc_forest_cover_all()
- [x] T023 Contrainte forêt (min_forest_cover)
- [x] T024 Contrainte pente (max_slope)
- [x] T025 Visualisation candidats valides/invalides
- [x] T026 Quiz Section 2

---

## Phase 6: Section 4 - Stratification et GRTS (exercices 3.x)

- [x] T027 Exercice 3.1 : Créer les strates
- [x] T028 Strate hauteur CHM (4 classes H1-H4)
- [x] T029 Strate type peuplement BD Forêt tfv (FEU/CON/MIX/POP/AUT)
- [x] T030 Strate position TPI (BAS/MIL/HAU)
- [x] T031 Visualisation 3 panneaux (patchwork)
- [x] T032 Exercice 3.2 : Tirage GRTS stratifié
- [x] T033 Fallback BalancedSampling::lpm2
- [x] T034 Correction n_over par strate
- [x] T035 Sauvegarde sample_plots.gpkg
- [x] T036 Quiz Section 3 (avec question TPI)

---

## Phase 7: Section 5 - Réseau et TSP (exercices 4.x)

- [x] T037 Exercice 4.1 : Construire réseau sfnetworks
- [x] T038 Correction edge_length()
- [x] T039 Exercice 4.2 : Résoudre TSP
- [x] T040 Utilisation vraies placettes (40)
- [x] T041 Visualisation parcours avec types Base/Remplacement
- [x] T042 Quiz Section 4

---

## Phase 8: Section 6 - Export (exercice 5.x)

- [x] T043 Exercice 5.1 : Export résultats
- [x] T044 Export GeoPackage
- [x] T045 Export GPX
- [x] T046 Export CSV avec coordonnées
- [x] T047 Correction st_coordinates()

---

## Phase 9: Synthèse et finalisation

- [x] T048 Synthèse complète (9 points)
- [x] T049 Tableau packages utilisés
- [x] T050 Quiz final

---

## Phase 10: Harmonisation et qualité

- [x] T051 Harmonisation data_dir (tous tutoriels T01-T09)
- [x] T052 Suppression cache_dir dans T08
- [x] T053 Chemin fallback correct (~/.local/share/nemeton/tutorial_data)

---

## Phase 11: Finalisation

- [x] T054 Mettre à jour NEWS.md avec détails T09
- [x] T055 Test complet du tutoriel
- [x] T056 Vérifier tous les exercices s'exécutent
- [x] T057 Vérifier tous les quiz fonctionnent
- [x] T058 Documentation utilisateur (TUTORIAL_INSTALL.md mis à jour)

---

## Commits effectués

1. `ec200e7` feat(T09): add Tutorial 09
2. `eb93eff` fix(T09): centralize config and fix ggplot display
3. `39eff45` fix(T09): remove parallel processing and optimize setup with cache
4. `dac10e2` fix(T09): use CHM LiDAR for stratification and fix TSP sample size
5. `977380c` fix(tutorials): harmonize data_dir paths and improve T09 stratification
6. `a324ade` fix(T09): correct GRTS n_over to be per-stratum not total
7. `ccab600` fix(T09): improve stratification plot readability
