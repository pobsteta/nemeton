# Tasks: Tutoriels Interactifs nemeton

**Input**: Design documents from `/specs/001-learnr-tutorial/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Tests inclus via gradethis pour validation des exercices dans chaque tutoriel.

**Organization**: Tasks are grouped by tutorial (user story equivalent) to enable independent implementation and testing of each tutorial.

## Format: `[ID] [P?] [Tutorial] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Tutorial]**: Which tutorial this task belongs to (T01, T02, T03, T04, T05, T06)
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
- [ ] T006 [T01] Ajouter validation gradethis manquante aux exercices sans check dans 01-acquisition.Rmd
- [ ] T007 [T01] Tester le tutoriel 01 end-to-end avec learnr::run_tutorial()
- [x] T008 [T01] Documenter les données de sortie dans inst/tutorials/01-acquisition/README.md

**Checkpoint**: Tutorial 01 prêt - les tutoriels suivants peuvent maintenant être créés

---

## Phase 3: Tutorial 02 - Traitement LiDAR (Priority: P1) 🎯 MVP

**Goal**: Apprendre à traiter les données LiDAR et calculer les métriques forestières

**Independent Test**: L'apprenant peut charger un nuage LiDAR, le normaliser, et extraire des métriques par parcelle

### Structure Tutorial 02

- [ ] T009 [P] [T02] Créer répertoire inst/tutorials/02-lidar/ avec structure standard
- [ ] T010 [T02] Créer en-tête YAML et setup chunk dans inst/tutorials/02-lidar/02-lidar.Rmd

### Section 1: Introduction LiDAR

- [ ] T011 [T02] Écrire section Introduction LiDAR (principes, classification) dans 02-lidar.Rmd
- [ ] T012 [T02] Ajouter quiz introduction LiDAR avec 3 questions dans 02-lidar.Rmd

### Section 2: Chargement nuage de points

- [ ] T013 [T02] Écrire exercice chargement LiDAR avec lidR::readLAS() dans 02-lidar.Rmd
- [ ] T014 [T02] Ajouter exercice visualisation 3D avec lidR::plot() dans 02-lidar.Rmd
- [ ] T015 [T02] Ajouter validation gradethis pour exercices section 2 dans 02-lidar.Rmd

### Section 3: Normalisation hauteurs

- [ ] T016 [T02] Écrire exercice normalisation avec lidR::normalize_height() dans 02-lidar.Rmd
- [ ] T017 [T02] Ajouter exercice filtrage points négatifs dans 02-lidar.Rmd
- [ ] T018 [T02] Ajouter validation gradethis pour exercices section 3 dans 02-lidar.Rmd

### Section 4: Génération MNH

- [ ] T019 [T02] Écrire exercice génération MNH avec lidR::rasterize_canopy() dans 02-lidar.Rmd
- [ ] T020 [T02] Ajouter exercice sauvegarde MNH en GeoTIFF dans 02-lidar.Rmd
- [ ] T021 [T02] Ajouter validation gradethis pour exercices section 4 dans 02-lidar.Rmd

### Section 5: Métriques par parcelle

- [ ] T022 [T02] Écrire exercice calcul métriques avec lidR::pixel_metrics() dans 02-lidar.Rmd
- [ ] T023 [T02] Ajouter exercice extraction par parcelle avec exactextractr dans 02-lidar.Rmd
- [ ] T024 [T02] Ajouter validation gradethis pour exercices section 5 dans 02-lidar.Rmd

### Section 6: Export et synthèse

- [ ] T025 [T02] Écrire exercice export métriques en GeoPackage dans 02-lidar.Rmd
- [ ] T026 [T02] Ajouter quiz final LiDAR avec 5 questions dans 02-lidar.Rmd

### Tests Tutorial 02

- [ ] T027 [T02] Créer tests/testthat/test-tutorial-02.R pour validation structure
- [ ] T028 [T02] Tester tutorial 02 end-to-end avec learnr::run_tutorial()

**Checkpoint**: Tutorial 02 complet - métriques LiDAR disponibles pour tutoriels suivants

---

## Phase 4: Tutorial 03 - Indicateurs Terrain (Priority: P1)

**Goal**: Calculer les indicateurs dérivés du MNT et de la BD TOPO (W, R, S, P2, F1)

**Independent Test**: L'apprenant peut calculer TWI, risques, et accessibilité pour ses parcelles

### Structure Tutorial 03

- [ ] T029 [P] [T03] Créer répertoire inst/tutorials/03-terrain/ avec structure standard
- [ ] T030 [T03] Créer en-tête YAML et setup chunk dans inst/tutorials/03-terrain/03-terrain.Rmd

### Section 1: Dérivés topographiques

- [ ] T031 [T03] Écrire exercice calcul pente/exposition avec terra::terrain() dans 03-terrain.Rmd
- [ ] T032 [T03] Ajouter validation gradethis pour section 1 dans 03-terrain.Rmd

### Section 2: TWI (W1)

- [ ] T033 [T03] Écrire exercice calcul TWI avec indicator_water_twi() dans 03-terrain.Rmd
- [ ] T034 [T03] Ajouter validation gradethis pour section 2 dans 03-terrain.Rmd

### Section 3: Réseau hydrographique (W2, W3)

- [ ] T035 [T03] Écrire exercice distance cours d'eau avec indicator_water_network() dans 03-terrain.Rmd
- [ ] T036 [T03] Écrire exercice zones humides avec indicator_water_wetlands() dans 03-terrain.Rmd
- [ ] T037 [T03] Ajouter validation gradethis pour section 3 dans 03-terrain.Rmd

### Section 4: Risques terrain (R1, R2, R3)

- [ ] T038 [T03] Écrire exercice risque feu avec indicator_risk_fire() dans 03-terrain.Rmd
- [ ] T039 [T03] Écrire exercice risque tempête avec indicator_risk_storm() dans 03-terrain.Rmd
- [ ] T040 [T03] Écrire exercice risque sécheresse avec indicator_risk_drought() dans 03-terrain.Rmd
- [ ] T041 [T03] Ajouter validation gradethis pour section 4 dans 03-terrain.Rmd

### Section 5: Accessibilité (S1, S2, S3)

- [ ] T042 [T03] Écrire exercice accessibilité routes avec indicator_social_accessibility() dans 03-terrain.Rmd
- [ ] T043 [T03] Écrire exercice proximité bâtiments avec indicator_social_proximity() dans 03-terrain.Rmd
- [ ] T044 [T03] Écrire exercice sentiers avec indicator_social_trails() dans 03-terrain.Rmd
- [ ] T045 [T03] Ajouter validation gradethis pour section 5 dans 03-terrain.Rmd

### Section 6: Station forestière (P2, F1)

- [ ] T046 [T03] Écrire exercice fertilité station avec indicator_productive_station() dans 03-terrain.Rmd
- [ ] T047 [T03] Écrire exercice érosion sol avec indicator_soil_erosion() dans 03-terrain.Rmd
- [ ] T048 [T03] Ajouter validation gradethis pour section 6 dans 03-terrain.Rmd

### Section 7: Synthèse et quiz

- [ ] T049 [T03] Écrire exercice export indicateurs terrain en GeoPackage dans 03-terrain.Rmd
- [ ] T050 [T03] Ajouter quiz final terrain avec 5 questions dans 03-terrain.Rmd

### Tests Tutorial 03

- [ ] T051 [T03] Créer tests/testthat/test-tutorial-03.R pour validation structure
- [ ] T052 [T03] Tester tutorial 03 end-to-end avec learnr::run_tutorial()

**Checkpoint**: Tutorial 03 complet - indicateurs terrain (W, R, S, P2, F1) calculés

---

## Phase 5: Tutorial 04 - Indicateurs Écologiques (Priority: P1)

**Goal**: Calculer les indicateurs biodiversité, paysage, temporel et naturalité (B, L, T, A, F, N)

**Independent Test**: L'apprenant peut calculer protection, connectivité, et naturalité pour ses parcelles

### Structure Tutorial 04

- [ ] T053 [P] [T04] Créer répertoire inst/tutorials/04-ecological/ avec structure standard
- [ ] T054 [T04] Créer en-tête YAML et setup chunk dans inst/tutorials/04-ecological/04-ecological.Rmd

### Section 1: BD Forêt V2

- [ ] T055 [T04] Écrire exercice exploration BD Forêt (types, essences) dans 04-ecological.Rmd
- [ ] T056 [T04] Ajouter validation gradethis pour section 1 dans 04-ecological.Rmd

### Section 2: Zonages protection (B1)

- [ ] T057 [T04] Écrire exercice téléchargement INPN WFS dans 04-ecological.Rmd
- [ ] T058 [T04] Écrire exercice calcul B1 avec indicator_biodiversity_protection() dans 04-ecological.Rmd
- [ ] T059 [T04] Ajouter validation gradethis pour section 2 dans 04-ecological.Rmd

### Section 3: Structure et connectivité (B2, B3)

- [ ] T060 [T04] Écrire exercice structure B2 avec indicator_biodiversity_structure() dans 04-ecological.Rmd
- [ ] T061 [T04] Écrire exercice connectivité B3 avec indicator_biodiversity_connectivity() dans 04-ecological.Rmd
- [ ] T062 [T04] Ajouter validation gradethis pour section 3 dans 04-ecological.Rmd

### Section 4: Paysage (L1, L2)

- [ ] T063 [T04] Écrire exercice lisière L1 avec indicator_landscape_edge() dans 04-ecological.Rmd
- [ ] T064 [T04] Écrire exercice fragmentation L2 avec indicator_landscape_fragmentation() dans 04-ecological.Rmd
- [ ] T065 [T04] Ajouter validation gradethis pour section 4 dans 04-ecological.Rmd

### Section 5: Temporel (T1, T2)

- [ ] T066 [T04] Écrire exercice âge T1 avec indicator_temporal_age() dans 04-ecological.Rmd
- [ ] T067 [T04] Écrire exercice changement T2 avec indicator_temporal_change() dans 04-ecological.Rmd
- [ ] T068 [T04] Ajouter validation gradethis pour section 5 dans 04-ecological.Rmd

### Section 6: Air et fertilité (A2, F2)

- [ ] T069 [T04] Écrire exercice qualité air A2 avec indicator_air_quality() dans 04-ecological.Rmd
- [ ] T070 [T04] Écrire exercice fertilité sol F2 avec indicator_soil_fertility() dans 04-ecological.Rmd
- [ ] T071 [T04] Ajouter validation gradethis pour section 6 dans 04-ecological.Rmd

### Section 7: Naturalité (N1, N2, N3)

- [ ] T072 [T04] Écrire exercice continuité N1 avec indicator_naturalness_continuity() dans 04-ecological.Rmd
- [ ] T073 [T04] Écrire exercice distance N2 avec indicator_naturalness_distance() dans 04-ecological.Rmd
- [ ] T074 [T04] Écrire exercice composite N3 avec indicator_naturalness_composite() dans 04-ecological.Rmd
- [ ] T075 [T04] Ajouter validation gradethis pour section 7 dans 04-ecological.Rmd

### Section 8: Synthèse et quiz

- [ ] T076 [T04] Écrire exercice export indicateurs écologiques en GeoPackage dans 04-ecological.Rmd
- [ ] T077 [T04] Ajouter quiz final écologique avec 5 questions dans 04-ecological.Rmd

### Tests Tutorial 04

- [ ] T078 [T04] Créer tests/testthat/test-tutorial-04.R pour validation structure
- [ ] T079 [T04] Tester tutorial 04 end-to-end avec learnr::run_tutorial()

**Checkpoint**: Tutorial 04 complet - indicateurs écologiques (B, L, T, A, F, N) calculés

---

## Phase 6: Tutorial 05 - Calcul Complet et Normalisation (Priority: P2)

**Goal**: Assembler tous les indicateurs, calculer C et E, normaliser et créer les indices

**Independent Test**: L'apprenant obtient un GeoPackage avec 40+ indicateurs normalisés et 12 indices famille

### Structure Tutorial 05

- [ ] T080 [P] [T05] Créer répertoire inst/tutorials/05-complete/ avec structure standard
- [ ] T081 [T05] Créer en-tête YAML et setup chunk dans inst/tutorials/05-complete/05-complete.Rmd

### Section 1: Assemblage indicateurs

- [ ] T082 [T05] Écrire exercice chargement et jointure tous indicateurs dans 05-complete.Rmd
- [ ] T083 [T05] Ajouter validation gradethis pour section 1 dans 05-complete.Rmd

### Section 2: Indicateurs Carbone (C1, C2)

- [ ] T084 [T05] Écrire exercice biomasse C1 avec indicator_carbon_biomass() dans 05-complete.Rmd
- [ ] T085 [T05] Écrire exercice NDVI C2 avec indicator_carbon_ndvi() dans 05-complete.Rmd
- [ ] T086 [T05] Ajouter validation gradethis pour section 2 dans 05-complete.Rmd

### Section 3: Indicateurs Production (P1, P3)

- [ ] T087 [T05] Écrire exercice volume P1 avec indicator_productive_volume() dans 05-complete.Rmd
- [ ] T088 [T05] Écrire exercice qualité P3 avec indicator_productive_quality() dans 05-complete.Rmd
- [ ] T089 [T05] Ajouter validation gradethis pour section 3 dans 05-complete.Rmd

### Section 4: Indicateurs Énergie (E1, E2)

- [ ] T090 [T05] Écrire exercice bois-énergie E1 avec indicator_energy_fuelwood() dans 05-complete.Rmd
- [ ] T091 [T05] Écrire exercice évitement E2 avec indicator_energy_avoidance() dans 05-complete.Rmd
- [ ] T092 [T05] Ajouter validation gradethis pour section 4 dans 05-complete.Rmd

### Section 5: Normalisation 0-100

- [ ] T093 [T05] Écrire exercice normalisation avec normalize_indicators() dans 05-complete.Rmd
- [ ] T094 [T05] Ajouter exercice comparaison méthodes (minmax, quantile) dans 05-complete.Rmd
- [ ] T095 [T05] Ajouter validation gradethis pour section 5 dans 05-complete.Rmd

### Section 6: Indices de famille

- [ ] T096 [T05] Écrire exercice création indices avec create_family_index() dans 05-complete.Rmd
- [ ] T097 [T05] Écrire exercice indice composite avec create_composite_index() dans 05-complete.Rmd
- [ ] T098 [T05] Ajouter validation gradethis pour section 6 dans 05-complete.Rmd

### Section 7: Validation et export

- [ ] T099 [T05] Écrire exercice validation cohérence (plages, corrélations) dans 05-complete.Rmd
- [ ] T100 [T05] Écrire exercice export indicateurs_complets.gpkg dans 05-complete.Rmd
- [ ] T101 [T05] Ajouter quiz final calcul complet avec 5 questions dans 05-complete.Rmd

### Tests Tutorial 05

- [ ] T102 [T05] Créer tests/testthat/test-tutorial-05.R pour validation structure
- [ ] T103 [T05] Tester tutorial 05 end-to-end avec learnr::run_tutorial()

**Checkpoint**: Tutorial 05 complet - tous indicateurs calculés et normalisés

---

## Phase 7: Tutorial 06 - Analyse Multi-Critères et Export (Priority: P2)

**Goal**: Visualiser, analyser et exporter les résultats multi-familles

**Independent Test**: L'apprenant peut générer un radar, identifier hotspots, et exporter rapport HTML

### Structure Tutorial 06

- [ ] T104 [P] [T06] Créer répertoire inst/tutorials/06-analysis/ avec structure standard
- [ ] T105 [T06] Créer en-tête YAML et setup chunk dans inst/tutorials/06-analysis/06-analysis.Rmd

### Section 1: Cartes thématiques

- [ ] T106 [T06] Écrire exercice cartes par famille avec plot_indicators_map() dans 06-analysis.Rmd
- [ ] T107 [T06] Ajouter validation gradethis pour section 1 dans 06-analysis.Rmd

### Section 2: Profils radar

- [ ] T108 [T06] Écrire exercice radar 12-axes avec nemeton_radar() dans 06-analysis.Rmd
- [ ] T109 [T06] Ajouter exercice comparaison parcelles avec radar dans 06-analysis.Rmd
- [ ] T110 [T06] Ajouter validation gradethis pour section 2 dans 06-analysis.Rmd

### Section 3: Matrice corrélation

- [ ] T111 [T06] Écrire exercice corrélation avec compute_family_correlations() dans 06-analysis.Rmd
- [ ] T112 [T06] Ajouter exercice interprétation synergies/compromis dans 06-analysis.Rmd
- [ ] T113 [T06] Ajouter validation gradethis pour section 3 dans 06-analysis.Rmd

### Section 4: Hotspots

- [ ] T114 [T06] Écrire exercice identification hotspots avec identify_hotspots() dans 06-analysis.Rmd
- [ ] T115 [T06] Ajouter exercice carte hotspots dans 06-analysis.Rmd
- [ ] T116 [T06] Ajouter validation gradethis pour section 4 dans 06-analysis.Rmd

### Section 5: Trade-offs et Pareto

- [ ] T117 [T06] Écrire exercice trade-offs 2D avec plot_tradeoff() dans 06-analysis.Rmd
- [ ] T118 [T06] Écrire exercice front Pareto avec identify_pareto_optimal() dans 06-analysis.Rmd
- [ ] T119 [T06] Ajouter validation gradethis pour section 5 dans 06-analysis.Rmd

### Section 6: Clustering

- [ ] T120 [T06] Écrire exercice clustering avec cluster_parcels() dans 06-analysis.Rmd
- [ ] T121 [T06] Ajouter exercice interprétation clusters dans 06-analysis.Rmd
- [ ] T122 [T06] Ajouter validation gradethis pour section 6 dans 06-analysis.Rmd

### Section 7: Export GeoPackage et CSV

- [ ] T123 [T06] Écrire exercice export GeoPackage final dans 06-analysis.Rmd
- [ ] T124 [T06] Écrire exercice export CSV attributs dans 06-analysis.Rmd
- [ ] T125 [T06] Ajouter validation gradethis pour section 7 dans 06-analysis.Rmd

### Section 8: Carte interactive Leaflet

- [ ] T126 [T06] Écrire exercice carte Leaflet interactive dans 06-analysis.Rmd
- [ ] T127 [T06] Ajouter exercice popups avec indicateurs dans 06-analysis.Rmd
- [ ] T128 [T06] Ajouter validation gradethis pour section 8 dans 06-analysis.Rmd

### Section 9: Rapport HTML

- [ ] T129 [T06] Écrire exercice génération rapport HTML dans 06-analysis.Rmd
- [ ] T130 [T06] Ajouter quiz final analyse avec 5 questions dans 06-analysis.Rmd

### Tests Tutorial 06

- [ ] T131 [T06] Créer tests/testthat/test-tutorial-06.R pour validation structure
- [ ] T132 [T06] Tester tutorial 06 end-to-end avec learnr::run_tutorial()

**Checkpoint**: Tutorial 06 complet - série tutoriels terminée

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Améliorations transversales affectant tous les tutoriels

- [ ] T133 [P] Mettre à jour vignettes/tutorial-guide.Rmd avec instructions complètes
- [ ] T134 [P] Mettre à jour TUTORIAL_INSTALL.md avec prérequis actualisés
- [ ] T135 Vérifier cohérence du pattern cache entre tous les tutoriels
- [ ] T136 [P] Ajouter screenshots/images dans chaque tutoriel si nécessaire
- [ ] T137 Exécuter R CMD check pour valider le package complet
- [ ] T138 [P] Mettre à jour man/ avec documentation roxygen2 si nouvelles fonctions
- [ ] T139 Valider quickstart.md avec installation fraîche
- [ ] T140 Créer issue GitHub pour chaque tutoriel à implémenter si souhaité

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
- **Polish (Phase 8)**: Dépend de tous les tutoriels terminés

### Tutorial Dependencies (Données)

```
Tutorial 01 (Acquisition)
    │
    ├──► Tutorial 02 (LiDAR) ──────────────────────┐
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

| Phase | Tutorial | Tasks | Priorité |
|-------|----------|-------|----------|
| 1 | Setup | T001-T003 (3) | - |
| 2 | Foundational (T01) | T004-T008 (5) | P1 |
| 3 | Tutorial 02 (LiDAR) | T009-T028 (20) | P1 |
| 4 | Tutorial 03 (Terrain) | T029-T052 (24) | P1 |
| 5 | Tutorial 04 (Écologique) | T053-T079 (27) | P1 |
| 6 | Tutorial 05 (Complet) | T080-T103 (24) | P2 |
| 7 | Tutorial 06 (Analyse) | T104-T132 (29) | P2 |
| 8 | Polish | T133-T140 (8) | P3 |

**Total**: 140 tâches

---

## Notes

- [P] tasks = fichiers différents, pas de dépendances
- [Tutorial] label = associe la tâche au tutoriel pour traçabilité
- Chaque tutoriel doit être indépendamment complétable et testable
- Vérifier que gradethis valide correctement avant de passer à la section suivante
- Commit après chaque section ou groupe logique
- Stopper à chaque checkpoint pour valider le tutoriel indépendamment
- Éviter: tâches vagues, conflits sur même fichier, dépendances croisées qui cassent l'indépendance
