# Tasks: Tutoriels Interactifs nemeton

**Input**: Design documents from `/specs/001-learnr-tutorial/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Tests inclus via gradethis pour validation des exercices dans chaque tutoriel.

**Organization**: Tasks are grouped by tutorial (user story equivalent) to enable independent implementation and testing of each tutorial.

**Progress**: 195/195 tasks complete (100%) - All phases complete

## Format: `[ID] [P?] [Tutorial] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Tutorial]**: Which tutorial this task belongs to (T01, T02, T03, T04, T05, T06, T07)
- Include exact file paths in descriptions

## Path Conventions

```text
nemeton/
├── R/                           # R source files
├── inst/tutorials/              # learnr tutorials
│   ├── 01-acquisition/          # Tutorial 01
│   ├── 02-lidar/                # Tutorial 02
│   ├── 03-terrain/              # Tutorial 03
│   ├── 04-ecological/           # Tutorial 04
│   ├── 05-complete/             # Tutorial 05
│   └── 06-analysis/             # Tutorial 06
├── tests/testthat/              # testthat tests
└── vignettes/                   # Package vignettes
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and verification of existing structure

- [x] T001 Vérifier structure inst/tutorials/ existante dans le package nemeton
- [x] T002 [P] Vérifier que tous les packages requis sont dans DESCRIPTION Suggests
- [x] T003 [P] Créer répertoires pour tutoriels manquants (02-06) dans inst/tutorials/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before creating new tutorials

**⚠️ CRITICAL**: Tutorial 01 doit être finalisé car il produit les données utilisées par tous les autres

- [x] T004 [T01] Réviser et valider toutes les sections de inst/tutorials/01-acquisition/01-acquisition.Rmd
- [x] T005 [T01] Vérifier cohérence du pattern cache dans tous les exercices de 01-acquisition.Rmd
- [x] T006 [T01] Ajouter validation gradethis manquante aux exercices sans check dans 01-acquisition.Rmd
- [x] T007 [T01] Tester le tutoriel 01 end-to-end avec learnr::run_tutorial()
- [x] T008 [T01] Documenter les données de sortie dans inst/tutorials/01-acquisition/README.md

**Checkpoint**: ✅ Tutorial 01 prêt - les tutoriels suivants peuvent maintenant être créés

---

## Phase 3: Tutorial 02 - Traitement LiDAR (Priority: P1) 🎯 MVP

**Goal**: Apprendre à traiter les données LiDAR et calculer les métriques forestières

**Independent Test**: L'apprenant peut charger un nuage LiDAR, le normaliser, et extraire des métriques par parcelle

### Structure Tutorial 02

- [x] T009 [P] [T02] Créer répertoire inst/tutorials/02-lidar/ avec structure standard
- [x] T010 [T02] Créer en-tête YAML et setup chunk dans inst/tutorials/02-lidar/02-lidar.Rmd

### Section 1: Introduction LiDAR

- [x] T011 [T02] Écrire section Introduction LiDAR (principes, classification) dans 02-lidar.Rmd
- [x] T012 [T02] Ajouter quiz introduction LiDAR avec 3 questions dans 02-lidar.Rmd

### Section 2: Chargement nuage de points

- [x] T013 [T02] Écrire exercice chargement LiDAR avec lidR::readLAS() dans 02-lidar.Rmd
- [x] T014 [T02] Ajouter exercice visualisation 3D avec lidR::plot() dans 02-lidar.Rmd
- [x] T015 [T02] Ajouter validation gradethis pour exercices section 2 dans 02-lidar.Rmd

### Section 3: Normalisation hauteurs

- [x] T016 [T02] Écrire exercice normalisation avec lidR::normalize_height() dans 02-lidar.Rmd
- [x] T017 [T02] Ajouter exercice filtrage points négatifs dans 02-lidar.Rmd
- [x] T018 [T02] Ajouter validation gradethis pour exercices section 3 dans 02-lidar.Rmd

### Section 4: Génération MNH

- [x] T019 [T02] Écrire exercice génération MNH avec lidR::rasterize_canopy() dans 02-lidar.Rmd
- [x] T020 [T02] Ajouter exercice sauvegarde MNH en GeoTIFF dans 02-lidar.Rmd
- [x] T021 [T02] Ajouter validation gradethis pour exercices section 4 dans 02-lidar.Rmd

### Section 5: Métriques par parcelle

- [x] T022 [T02] Écrire exercice calcul métriques avec lidR::pixel_metrics() dans 02-lidar.Rmd
- [x] T023 [T02] Ajouter exercice extraction par parcelle avec exactextractr dans 02-lidar.Rmd
- [x] T024 [T02] Ajouter validation gradethis pour exercices section 5 dans 02-lidar.Rmd

### Section 6: Export et synthèse

- [x] T025 [T02] Écrire exercice export métriques en GeoPackage dans 02-lidar.Rmd
- [x] T026 [T02] Ajouter quiz final LiDAR avec 5 questions dans 02-lidar.Rmd

### Tests Tutorial 02

- [x] T027 [T02] Créer tests/testthat/test-tutorial-02.R pour validation structure
- [x] T028 [T02] Tester tutorial 02 end-to-end avec learnr::run_tutorial()

**Checkpoint**: ✅ Tutorial 02 complet - métriques LiDAR disponibles pour tutoriels suivants

---

## Phase 4: Tutorial 03 - Indicateurs Terrain (Priority: P1)

**Goal**: Calculer les indicateurs dérivés du MNT et de la BD TOPO (W, R, S, P2, F1)

**Independent Test**: L'apprenant peut calculer TWI, risques, et accessibilité pour ses parcelles

### Structure Tutorial 03

- [x] T029 [P] [T03] Créer répertoire inst/tutorials/03-terrain/ avec structure standard
- [x] T030 [T03] Créer en-tête YAML et setup chunk dans inst/tutorials/03-terrain/03-terrain.Rmd

### Section 1: Dérivés topographiques

- [x] T031 [T03] Écrire exercice calcul pente/exposition avec terra::terrain() dans 03-terrain.Rmd
- [x] T032 [T03] Ajouter validation gradethis pour section 1 dans 03-terrain.Rmd

### Section 2: TWI (W1)

- [x] T033 [T03] Écrire exercice calcul TWI avec indicator_water_twi() dans 03-terrain.Rmd
- [x] T034 [T03] Ajouter validation gradethis pour section 2 dans 03-terrain.Rmd

### Section 3: Réseau hydrographique (W2, W3)

- [x] T035 [T03] Écrire exercice distance cours d'eau avec indicator_water_network() dans 03-terrain.Rmd
- [x] T036 [T03] Écrire exercice zones humides avec indicator_water_wetlands() dans 03-terrain.Rmd
- [x] T037 [T03] Ajouter validation gradethis pour section 3 dans 03-terrain.Rmd

### Section 4: Risques terrain (R1, R2, R3, R4)

- [x] T038 [T03] Écrire exercice risque feu avec indicator_risk_fire() dans 03-terrain.Rmd
- [x] T039 [T03] Écrire exercice risque tempête avec indicator_risk_storm() dans 03-terrain.Rmd
- [x] T040 [T03] Écrire exercice risque sécheresse avec indicator_risk_drought() dans 03-terrain.Rmd
- [x] T041 [T03] Ajouter validation gradethis pour section 4 dans 03-terrain.Rmd
- [x] T041b [T03] Écrire exercice pression gibier R4 avec données chasse data.gouv.fr (8 espèces)

### Section 5: Accessibilité (S1, S2, S3)

- [x] T042 [T03] Écrire exercice accessibilité routes avec indicator_social_accessibility() dans 03-terrain.Rmd
- [x] T043 [T03] Écrire exercice proximité bâtiments avec indicator_social_proximity() dans 03-terrain.Rmd
- [x] T044 [T03] Écrire exercice sentiers avec indicator_social_trails() dans 03-terrain.Rmd
- [x] T045 [T03] Ajouter validation gradethis pour section 5 dans 03-terrain.Rmd

### Section 6: Station forestière (P2, F1)

- [x] T046 [T03] Écrire exercice fertilité station avec indicator_productive_station() dans 03-terrain.Rmd
- [x] T047 [T03] Écrire exercice érosion sol avec indicator_soil_erosion() dans 03-terrain.Rmd
- [x] T048 [T03] Ajouter validation gradethis pour section 6 dans 03-terrain.Rmd

### Section 7: Synthèse et quiz

- [x] T049 [T03] Écrire exercice export indicateurs terrain en GeoPackage dans 03-terrain.Rmd
- [x] T050 [T03] Ajouter quiz final terrain avec 5 questions dans 03-terrain.Rmd

### Tests Tutorial 03

- [x] T051 [T03] Créer tests/testthat/test-tutorial-03.R pour validation structure
- [x] T052 [T03] Tester tutorial 03 end-to-end avec learnr::run_tutorial()

**Checkpoint**: ✅ Tutorial 03 complet - 12 indicateurs terrain (W1-3, R1-4, S1-3, P2, F1) calculés

---

## Phase 5: Tutorial 04 - Indicateurs Écologiques (Priority: P1)

**Goal**: Calculer les indicateurs biodiversité, paysage, temporel et naturalité (B, L, T, A, F, N)

**Independent Test**: L'apprenant peut calculer protection, connectivité, et naturalité pour ses parcelles

### Structure Tutorial 04

- [x] T053 [P] [T04] Créer répertoire inst/tutorials/04-ecological/ avec structure standard
- [x] T054 [T04] Créer en-tête YAML et setup chunk dans inst/tutorials/04-ecological/04-ecological.Rmd

### Section 1: BD Forêt V2

- [x] T055 [T04] Écrire exercice exploration BD Forêt (types, essences) dans 04-ecological.Rmd
- [x] T056 [T04] Ajouter validation gradethis pour section 1 dans 04-ecological.Rmd

### Section 2: Zonages protection (B1)

- [x] T057 [T04] Écrire exercice téléchargement INPN WFS dans 04-ecological.Rmd
- [x] T058 [T04] Écrire exercice calcul B1 avec indicator_biodiversity_protection() dans 04-ecological.Rmd
- [x] T059 [T04] Ajouter validation gradethis pour section 2 dans 04-ecological.Rmd

### Section 3: Structure et connectivité (B2, B3)

- [x] T060 [T04] Écrire exercice structure B2 avec indicator_biodiversity_structure() dans 04-ecological.Rmd
- [x] T061 [T04] Écrire exercice connectivité B3 avec indicator_biodiversity_connectivity() dans 04-ecological.Rmd
- [x] T062 [T04] Ajouter validation gradethis pour section 3 dans 04-ecological.Rmd

### Section 4: Paysage et Vitalité (L1, L2, L3, C2)

- [x] T063 [T04] Écrire exercice lisière L1 avec indicator_landscape_edge() dans 04-ecological.Rmd
- [x] T064 [T04] Écrire exercice fragmentation L2 avec indicator_landscape_fragmentation() dans 04-ecological.Rmd
- [x] T064b [T04] Écrire exercice TVB L3 (Trame Verte et Bleue) dans 04-ecological.Rmd
- [x] T064c [T04] Écrire exercice NDVI C2 (vitalité végétation) dans 04-ecological.Rmd
- [x] T065 [T04] Ajouter validation gradethis pour section 4 dans 04-ecological.Rmd

### Section 5: Temporel (T1, T2)

- [x] T066 [T04] Écrire exercice âge T1 avec indicator_temporal_age() dans 04-ecological.Rmd
- [x] T067 [T04] Écrire exercice changement T2 avec indicator_temporal_change() dans 04-ecological.Rmd
- [x] T068 [T04] Ajouter validation gradethis pour section 5 dans 04-ecological.Rmd

### Section 6: Air et fertilité (A2, F2)

- [x] T069 [T04] Écrire exercice qualité air A2 avec indicator_air_quality() dans 04-ecological.Rmd
- [x] T070 [T04] Écrire exercice fertilité sol F2 avec indicator_soil_fertility() dans 04-ecological.Rmd
- [x] T071 [T04] Ajouter validation gradethis pour section 6 dans 04-ecological.Rmd

### Section 7: Naturalité (N1, N2, N3)

- [x] T072 [T04] Écrire exercice continuité N1 avec indicator_naturalness_continuity() dans 04-ecological.Rmd
- [x] T073 [T04] Écrire exercice distance N2 avec indicator_naturalness_distance() dans 04-ecological.Rmd
- [x] T074 [T04] Écrire exercice composite N3 avec indicator_naturalness_composite() dans 04-ecological.Rmd
- [x] T075 [T04] Ajouter validation gradethis pour section 7 dans 04-ecological.Rmd

### Section 8: Synthèse et quiz

- [x] T076 [T04] Écrire exercice export indicateurs écologiques en GeoPackage dans 04-ecological.Rmd
- [x] T077 [T04] Ajouter quiz final écologique avec 5 questions dans 04-ecological.Rmd

### Tests Tutorial 04

- [x] T078 [T04] Créer tests/testthat/test-tutorial-04.R pour validation structure
- [x] T079 [T04] Tester tutorial 04 end-to-end avec learnr::run_tutorial()

**Checkpoint**: ✅ Tutorial 04 complet - 14 indicateurs écologiques (B1-3, L1-3, C2, T1-2, A2, F2, N1-3) calculés

---

## Phase 6: Tutorial 05 - Calcul Complet et Normalisation (Priority: P2)

**Goal**: Assembler tous les indicateurs, calculer E2, normaliser et créer l'indice composite I_nemeton

**Independent Test**: L'apprenant obtient un GeoPackage avec 32 indicateurs normalisés et l'indice composite

### Structure Tutorial 05

- [x] T080 [P] [T05] Créer répertoire inst/tutorials/05-complete/ avec structure standard
- [x] T081 [T05] Créer en-tête YAML et setup chunk dans inst/tutorials/05-complete/05-complete.Rmd

### Section 1: Assemblage indicateurs

- [x] T082 [T05] Écrire exercice chargement et jointure tous indicateurs dans 05-complete.Rmd
- [x] T082b [T05] Calculer C1, P1, P3, E1, A1 depuis métriques LiDAR brutes
- [x] T082c [T05] Joindre indicateurs terrain (W1-3, R1-4, S1-3, P2, F1)
- [x] T082d [T05] Joindre indicateurs écologiques (B1-3, L1-3, C2, T1-2, A2, F2, N1-3)
- [x] T083 [T05] Ajouter validation gradethis pour section 1 dans 05-complete.Rmd

### Section 2: Indicateur Énergie (E2)

- [x] T090 [T05] Écrire exercice bois-énergie E1 (calculé depuis LiDAR) dans 05-complete.Rmd
- [x] T091 [T05] Écrire exercice évitement E2 avec indicator_energy_avoidance() dans 05-complete.Rmd
- [x] T092 [T05] Ajouter validation gradethis pour section 2 dans 05-complete.Rmd

### Section 3: Normalisation Min-Max

- [x] T093 [T05] Écrire exercice normalisation avec normalize_indicators() dans 05-complete.Rmd
- [x] T094 [T05] Écrire exercice inversion indicateurs négatifs (R1-4, F1, L1) dans 05-complete.Rmd
- [x] T095 [T05] Ajouter validation gradethis pour section 3 dans 05-complete.Rmd

### Section 4: Indice Composite I_nemeton

- [x] T096 [T05] Écrire exercice création moyennes par famille dans 05-complete.Rmd
- [x] T097 [T05] Écrire exercice indice composite avec create_composite_index() dans 05-complete.Rmd
- [x] T098 [T05] Ajouter validation gradethis pour section 4 dans 05-complete.Rmd

### Section 5: Export et quiz

- [x] T100 [T05] Écrire exercice export indicateurs_complets.gpkg dans 05-complete.Rmd
- [x] T101 [T05] Ajouter quiz final calcul complet avec 5 questions dans 05-complete.Rmd

### Tests Tutorial 05

- [x] T102 [T05] Créer tests/testthat/test-tutorial-05.R pour validation structure
- [x] T103 [T05] Tester tutorial 05 end-to-end avec learnr::run_tutorial()

**Checkpoint**: ✅ Tutorial 05 complet - 32 indicateurs assemblés + E2 + I_nemeton

---

## Phase 7: Tutorial 06 - Analyse Multi-Critères et Export (Priority: P2)

**Goal**: Visualiser, analyser et exporter les résultats multi-familles

**Independent Test**: L'apprenant peut générer un radar, identifier hotspots, et exporter rapport HTML

### Structure Tutorial 06

- [x] T104 [P] [T06] Créer répertoire inst/tutorials/06-analysis/ avec structure standard
- [x] T105 [T06] Créer en-tête YAML et setup chunk dans inst/tutorials/06-analysis/06-analysis.Rmd

### Section 1: Cartes thématiques

- [x] T106 [T06] Écrire exercice cartes par famille avec plot_indicators_map() dans 06-analysis.Rmd
- [x] T107 [T06] Ajouter validation gradethis pour section 1 dans 06-analysis.Rmd

### Section 2: Profils radar

- [x] T108 [T06] Écrire exercice radar 12-axes avec nemeton_radar() dans 06-analysis.Rmd
- [x] T109 [T06] Ajouter exercice comparaison parcelles avec radar dans 06-analysis.Rmd
- [x] T110 [T06] Ajouter validation gradethis pour section 2 dans 06-analysis.Rmd

### Section 3: Matrice corrélation

- [x] T111 [T06] Écrire exercice corrélation avec compute_family_correlations() dans 06-analysis.Rmd
- [x] T112 [T06] Ajouter exercice interprétation synergies/compromis dans 06-analysis.Rmd
- [x] T113 [T06] Ajouter validation gradethis pour section 3 dans 06-analysis.Rmd

### Section 4: Hotspots

- [x] T114 [T06] Écrire exercice identification hotspots avec identify_hotspots() dans 06-analysis.Rmd
- [x] T115 [T06] Ajouter exercice carte hotspots dans 06-analysis.Rmd
- [x] T116 [T06] Ajouter validation gradethis pour section 4 dans 06-analysis.Rmd

### Section 5: Trade-offs et Pareto

- [x] T117 [T06] Écrire exercice trade-offs 2D avec plot_tradeoff() dans 06-analysis.Rmd
- [x] T118 [T06] Écrire exercice front Pareto avec identify_pareto_optimal() dans 06-analysis.Rmd
- [x] T119 [T06] Ajouter validation gradethis pour section 5 dans 06-analysis.Rmd

### Section 6: Clustering

- [x] T120 [T06] Écrire exercice clustering avec cluster_parcels() dans 06-analysis.Rmd
- [x] T121 [T06] Ajouter exercice interprétation clusters dans 06-analysis.Rmd
- [x] T122 [T06] Ajouter validation gradethis pour section 6 dans 06-analysis.Rmd

### Section 7: Export GeoPackage et CSV

- [x] T123 [T06] Écrire exercice export GeoPackage final dans 06-analysis.Rmd
- [x] T124 [T06] Écrire exercice export CSV attributs dans 06-analysis.Rmd
- [x] T125 [T06] Ajouter validation gradethis pour section 7 dans 06-analysis.Rmd

### Section 8: Carte interactive Leaflet

- [x] T126 [T06] Écrire exercice carte Leaflet interactive dans 06-analysis.Rmd
- [x] T127 [T06] Ajouter exercice popups avec indicateurs dans 06-analysis.Rmd (intégré dans 8.1)
- [x] T128 [T06] Ajouter validation gradethis pour section 8 dans 06-analysis.Rmd

### Section 9: Quiz Final

- [x] T129 [T06] Quiz final analyse avec 5 questions dans 06-analysis.Rmd (Section 9 = Quiz)
- [x] T130 [T06] Quiz final couvre les concepts clés des 6 tutoriels

### Tests Tutorial 06

- [x] T131 [T06] Créer tests/testthat/test-tutorial-06.R pour validation structure
- [x] T132 [T06] Tester tutorial 06 end-to-end avec learnr::run_tutorial()

**Checkpoint**: ✅ Tutorial 06 complet - série tutoriels terminée (1591 lignes, 9 sections)

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Améliorations transversales affectant tous les tutoriels

- [x] T133 [P] Mettre à jour vignettes/tutorial-guide.Rmd avec instructions complètes
- [x] T134 [P] Mettre à jour TUTORIAL_INSTALL.md avec prérequis actualisés
- [x] T135 Vérifier cohérence du pattern cache entre tous les tutoriels
- [x] T136 [P] Ajouter screenshots/images dans chaque tutoriel si nécessaire (N/A pour learnr)
- [x] T137 Exécuter R CMD check pour valider le package complet (0 errors, 1 warning non-ASCII attendu)
- [x] T138 [P] Mettre à jour man/ avec documentation roxygen2 si nouvelles fonctions
- [x] T139 Valider quickstart.md avec installation fraîche (URLs corrigées)
- [x] T140 Créer issue GitHub pour chaque tutoriel à implémenter si souhaité (N/A - tous terminés)

---

## Phase 9: Tutorial 07 - LiDAR Avancé avec lidR, lasR et LAScatalog (Priority: P2)

**Goal**: Maîtriser le traitement LiDAR avancé avec LAScatalog, pipelines lasR, et lidaRtRee pour produire toutes les métriques nécessaires aux indicateurs nemeton

**Independent Test**: L'apprenant peut traiter un jeu de données LiDAR multi-tuiles, segmenter les arbres, détecter les trouées, et exporter les métriques pour T05-T06

**Note**: La structure finale du tutoriel (10 sections) diffère légèrement du plan initial (9 sections) pour mieux suivre les vignettes lidaRtRee et séparer ABA/BABA.

### Structure Tutorial 07

- [x] T141 [P] [T07] Créer répertoire inst/tutorials/07-lidar-advanced/ avec structure standard
- [x] T142 [T07] Créer en-tête YAML et setup chunk dans inst/tutorials/07-lidar-advanced/07-lidar-advanced.Rmd

### Section 1: Introduction LAScatalog

- [x] T143 [T07] Écrire section Introduction LAScatalog (concept, avantages, structure) dans 07-lidar-advanced.Rmd
- [x] T144 [T07] Ajouter exercice création LAScatalog avec lidR::readLAScatalog() dans 07-lidar-advanced.Rmd
- [x] T145 [T07] Ajouter exercice configuration options (chunk_size, buffer, parallel) dans 07-lidar-advanced.Rmd
- [x] T146 [T07] Ajouter validation quiz pour exercices section 1 dans 07-lidar-advanced.Rmd

### Section 2: Pipelines lasR

- [x] T147 [T07] Écrire section Introduction lasR (vs lidR, performance, cas d'usage) dans 07-lidar-advanced.Rmd
- [x] T148 [T07] Ajouter exercice pipeline basique lasR (lecture → rasterisation) dans 07-lidar-advanced.Rmd
- [x] T149 [T07] Ajouter exercice pipeline complexe lasR (MNT + MNH + métriques) dans 07-lidar-advanced.Rmd
- [x] T150 [T07] Ajouter validation quiz pour exercices section 2 dans 07-lidar-advanced.Rmd

### Section 3: Segmentation Arbres Individuels

- [x] T151 [T07] Écrire section Introduction segmentation arbres (méthodes, algorithmes) dans 07-lidar-advanced.Rmd
- [x] T152 [T07] Ajouter exercice détection cimes avec lidR::locate_trees() dans 07-lidar-advanced.Rmd
- [x] T153 [T07] Ajouter exercice segmentation couronnes avec lidR::segment_trees() dans 07-lidar-advanced.Rmd
- [x] T154 [T07] Ajouter exercice segmentation lidaRtRee::tree_segmentation() dans 07-lidar-advanced.Rmd
- [x] T155 [T07] Ajouter exercice extraction attributs arbres avec crown_metrics() dans 07-lidar-advanced.Rmd
- [x] T156 [T07] Ajouter validation quiz pour exercices section 3 dans 07-lidar-advanced.Rmd

### Section 4: Trouées et Lisières

- [x] T157 [T07] Écrire section Introduction trouées/lisières (écologie, indicateurs) dans 07-lidar-advanced.Rmd
- [x] T158 [T07] Ajouter exercice détection trouées avec lidaRtRee::gap_detection() dans 07-lidar-advanced.Rmd
- [x] T159 [T07] Ajouter exercice caractérisation lisières avec lidaRtRee::edge_detection() dans 07-lidar-advanced.Rmd
- [x] T160 [T07] Ajouter exercice calcul métriques gaps/edges par parcelle dans 07-lidar-advanced.Rmd
- [x] T161 [T07] Ajouter validation quiz pour exercices section 4 dans 07-lidar-advanced.Rmd

### Section 5: Métriques de Structure Forestière

- [x] T162 [T07] Écrire section Introduction métriques structure (hauteurs, strates, densité) dans 07-lidar-advanced.Rmd
- [x] T163 [T07] Ajouter exercice calcul métriques avancées avec aba_metrics() dans 07-lidar-advanced.Rmd
- [x] T164 [T07] Ajouter exercice métriques par strates verticales dans 07-lidar-advanced.Rmd
- [x] T165 [T07] Ajouter exercice génération raster multi-bandes métriques dans 07-lidar-advanced.Rmd
- [x] T166 [T07] Ajouter validation quiz pour exercices section 5 dans 07-lidar-advanced.Rmd

### Section 6: Approche ABA - Préparation des Données (anciennement BABA)

- [x] T167 [T07] Écrire section Introduction ABA (concept, workflow, données terrain) dans 07-lidar-advanced.Rmd
- [x] T168 [T07] Ajouter exercice chargement placettes terrain lidaRtRee dans 07-lidar-advanced.Rmd
- [x] T169 [T07] Ajouter exercice extraction métriques sur placettes avec clouds_metrics() dans 07-lidar-advanced.Rmd
- [x] T170 [T07] Ajouter exercice préparation données pour calibration dans 07-lidar-advanced.Rmd
- [x] T171 [T07] Ajouter exercice coregistration placettes avec lidaRtRee::coregistration() dans 07-lidar-advanced.Rmd
- [x] T172 [T07] Ajouter validation quiz pour exercices section 6 dans 07-lidar-advanced.Rmd

### Section 7: Approche ABA - Calibration des Modèles (anciennement Coregistration)

- [x] T173 [T07] Écrire section Introduction calibration (Box-Cox, stepwise, validation) dans 07-lidar-advanced.Rmd
- [x] T174 [T07] Ajouter exercice calibration modèle G avec aba_build_model() dans 07-lidar-advanced.Rmd
- [x] T175 [T07] Ajouter exercice calibration modèles N, D, V dans 07-lidar-advanced.Rmd
- [x] T176 [T07] Ajouter validation quiz pour exercices section 7 dans 07-lidar-advanced.Rmd

### Section 8: Cartographie et Prédiction (anciennement Produits Dérivés)

- [x] T177 [T07] Écrire section Introduction cartographie wall-to-wall dans 07-lidar-advanced.Rmd
- [x] T178 [T07] Ajouter exercice prédiction spatiale avec aba_predict() dans 07-lidar-advanced.Rmd
- [x] T179 [T07] Ajouter exercice nettoyage raster avec clean_raster() dans 07-lidar-advanced.Rmd
- [x] T180 [T07] Ajouter exercice export produits pour indicateurs nemeton dans 07-lidar-advanced.Rmd
- [x] T181 [T07] Ajouter validation quiz pour exercices section 8 dans 07-lidar-advanced.Rmd

### Section 9: Approche BABA - Alternative sans Placettes (NOUVELLE)

- [x] T181b [T07] Écrire section Introduction BABA vs ABA (moving window, sans calibration) dans 07-lidar-advanced.Rmd
- [x] T181c [T07] Ajouter exercice génération métriques BABA avec lasR::rasterize(c(10,30)) dans 07-lidar-advanced.Rmd
- [x] T181d [T07] Ajouter validation quiz pour section 9 dans 07-lidar-advanced.Rmd

### Section 10: Quiz Final et Synthèse

- [x] T182 [T07] Ajouter quiz final LiDAR avancé avec 8 questions dans 07-lidar-advanced.Rmd
- [x] T183 [T07] Écrire section Synthèse (récapitulatif produits, mapping indicateurs) dans 07-lidar-advanced.Rmd

### Tests Tutorial 07

- [x] T184 [T07] Créer tests/testthat/test-tutorial-07.R pour validation structure (14 tests)
- [x] T185 [T07] Tester tutorial 07 end-to-end avec learnr::run_tutorial()

**Checkpoint**: ✅ Tutorial 07 complet (3790 lignes, 10 sections) - métriques LiDAR avancées disponibles pour T05-T06

---

## Phase 10: Polish Tutorial 07

**Purpose**: Finalisation et intégration du Tutorial 07

- [x] T186 [P] Mettre à jour vignettes/tutorial-guide.Rmd avec Tutorial 07
- [x] T187 [P] Mettre à jour TUTORIAL_INSTALL.md avec packages lasR et lidaRtRee
- [x] T188 Vérifier cohérence pattern data_dir dans Tutorial 07
- [x] T189 [P] Mettre à jour quickstart.md avec instructions Tutorial 07
- [x] T190 Exécuter R CMD check après ajout Tutorial 07
- [x] T191 [P] Mettre à jour DESCRIPTION Suggests avec lasR
- [x] T192 Valider intégration T07 → T05 → T06 workflow complet

**Checkpoint**: ✅ Phase 10 complete - all tutorials finalized

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - peut commencer immédiatement
- **Foundational (Phase 2)**: Dépend de Setup - BLOQUE tous les tutoriels suivants
- **Tutorials 02-06 (Phases 3-7)**: Dépendent de Phase 2 (Tutorial 01 finalisé)
  - Tutorial 02 dépend de données Tutorial 01
  - Tutorial 03 dépend de MNT (Tutorial 01) et métriques (Tutorial 02)
  - Tutorial 04 dépend de BD Forêt (Tutorial 01)
  - Tutorial 05 dépend de tous indicateurs (Tutorials 02-04)
  - Tutorial 06 dépend d'indicateurs complets (Tutorial 05)
- **Polish (Phase 8)**: Dépend de Tutorials 01-06 terminés
- **Tutorial 07 (Phase 9)**: Dépend de Tutorial 01 (données LiDAR téléchargées)
  - Alternative avancée à Tutorial 02
  - Peut être fait en parallèle ou après Tutorial 02
  - Produit des métriques compatibles avec T05-T06
- **Polish T07 (Phase 10)**: Dépend de Tutorial 07 terminé

### Tutorial Dependencies (Données)

```
Tutorial 01 (Acquisition)
    │
    ├──► Tutorial 02 (LiDAR basique) ─────────────┐
    │    [lidR simple, métriques de base]          │
    │                                               │
    ├──► Tutorial 07 (LiDAR avancé) ──────────────┤  ALTERNATIVE
    │    [LAScatalog, lasR, lidaRtRee]             │  ou COMPLÉMENT
    │    [ABA, segmentation, trouées]              │
    │                                               │
    ├──► Tutorial 03 (Terrain) ───────────────────┤
    │                                               │
    └──► Tutorial 04 (Écologique) ────────────────┤
                                                   │
                                                   ▼
                                Tutorial 05 (Complet)
                                          │
                                          ▼
                                Tutorial 06 (Analyse)
```

### Within Each Tutorial

- Setup chunk en premier
- Sections séquentielles (1, 2, 3...)
- Dans chaque section: Exercice → Solution → Check
- Quiz en fin de section ou de tutoriel

### Parallel Opportunities

- Tasks [P] dans Setup peuvent s'exécuter en parallèle
- Création des répertoires (T003, T009, T029, T053, T080, T104) en parallèle
- Tests de chaque tutoriel peuvent s'exécuter en parallèle après création
- Tutorials 02, 03, 04 peuvent être développés en parallèle (données indépendantes)

---

## Parallel Example: Création Répertoires

```bash
# Ces tâches peuvent s'exécuter en parallèle:
Task T003: "Créer répertoires pour tutoriels 02-06"
Task T009: "Créer répertoire inst/tutorials/02-lidar/"
Task T029: "Créer répertoire inst/tutorials/03-terrain/"
Task T053: "Créer répertoire inst/tutorials/04-ecological/"
Task T080: "Créer répertoire inst/tutorials/05-complete/"
Task T104: "Créer répertoire inst/tutorials/06-analysis/"
```

---

## Implementation Strategy

### MVP First (Tutorial 01 + 02 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (Tutorial 01 finalisé)
3. Complete Phase 3: Tutorial 02 (LiDAR)
4. **STOP and VALIDATE**: Tester Tutorials 01 + 02 ensemble
5. Deploy/demo si prêt

### Incremental Delivery

1. Setup + Foundational → Tutorial 01 prêt
2. Add Tutorial 02 → Test → MVP LiDAR!
3. Add Tutorials 03 + 04 (parallèle) → Test → Indicateurs terrain + écolo
4. Add Tutorial 05 → Test → Calcul complet
5. Add Tutorial 06 → Test → Analyse complète
6. Chaque tutoriel ajoute de la valeur sans casser les précédents

### Parallel Team Strategy

Avec plusieurs développeurs:

1. Tous: Setup + Foundational (Tutorial 01)
2. Une fois Tutorial 01 terminé:
   - Dev A: Tutorial 02 (LiDAR)
   - Dev B: Tutorial 03 (Terrain)
   - Dev C: Tutorial 04 (Écologique)
3. Après 02-04:
   - Dev A: Tutorial 05 (Complet)
4. Après 05:
   - Dev A: Tutorial 06 (Analyse)

---

## Summary

| Phase | Tutorial | Tasks | Priorité | Status |
|-------|----------|-------|----------|--------|
| 1 | Setup | T001-T003 (3) | - | ✅ |
| 2 | Foundational (T01) | T004-T008 (5) | P1 | ✅ |
| 3 | Tutorial 02 (LiDAR basique) | T009-T028 (20) | P1 | ✅ |
| 4 | Tutorial 03 (Terrain) | T029-T052 (24) | P1 | ✅ |
| 5 | Tutorial 04 (Écologique) | T053-T079 (27) | P1 | ✅ |
| 6 | Tutorial 05 (Complet) | T080-T103 (24) | P2 | ✅ |
| 7 | Tutorial 06 (Analyse) | T104-T132 (29) | P2 | ✅ |
| 8 | Polish T01-T06 | T133-T140 (8) | P3 | ✅ |
| 9 | Tutorial 07 (LiDAR avancé) | T141-T185 (48) | P2 | ✅ |
| 10 | Polish T07 | T186-T192 (7) | P3 | ✅ |

**Total**: 195 tâches
**Progression**: 195/195 (100%) - TOUS LES TUTORIELS TERMINÉS

---

## Notes

- [P] tasks = fichiers différents, pas de dépendances
- [Tutorial] label = associe la tâche au tutoriel pour traçabilité
- Chaque tutoriel doit être indépendamment complétable et testable
- Vérifier que gradethis valide correctement avant de passer à la section suivante
- Commit après chaque section ou groupe logique
- Stopper à chaque checkpoint pour valider le tutoriel indépendamment
- Éviter: tâches vagues, conflits sur même fichier, dépendances croisées qui cassent l'indépendance
