# Tasks: Tutorial 08 - Coregistration LiDAR/Terrain

**Input**: spec.md
**Source**: https://lidar.pages-forge.inrae.fr/lidaRtRee/articles/coregistration.html

**Progress**: 43/43 tasks (100%)

---

## Phase 1: Setup

- [x] T001 Créer répertoire inst/tutorials/08-coregistration/
- [x] T002 Créer en-tête YAML et setup chunk dans 08-coregistration.Rmd
- [x] T003 Vérifier disponibilité données lidaRtRee (extdata/coregistration)
- [x] T004 Ajouter 08-coregistration à la liste des tutoriels

---

## Phase 2: Section 1 - Introduction

- [x] T005 Écrire section contexte et problématique
- [x] T006 Écrire section principe du recalage (corrélation croisée)
- [x] T007 Ajouter schéma explicatif du workflow
- [x] T008 Créer Quiz 1 : Introduction (3 questions)

---

## Phase 3: Section 2 - Chargement données

- [x] T009 Écrire section paramètres de configuration
- [x] T010 Écrire section chargement données terrain (plots, trees)
- [x] T011 Écrire section chargement données LiDAR
- [x] T012 Ajouter exercice exploration données avec gradethis

---

## Phase 4: Section 3 - Génération MNH

- [x] T013 Écrire pipeline lasR optimisé pour CHM
- [x] T014 Écrire alternative lidR classique (rasterize_canopy)
- [x] T015 Ajouter comparaison benchmark lasR vs lidR
- [x] T016 Créer Quiz 2 : Génération MNH (3 questions)

---

## Phase 5: Section 4 - Masque placette

- [x] T017 Écrire fonction extraction arbres d'une placette
- [x] T018 Écrire fonction génération masque raster (circle2Raster + raster_xy_mask)
- [x] T019 Ajouter visualisation CHM + arbres
- [x] T020 Créer exercice création masque avec gradethis

---

## Phase 6: Section 5 - Corrélation

- [x] T021 Écrire utilisation coregistration() de lidaRtRee
- [x] T022 Documenter interprétation des résultats (dx, dy, ratio)
- [x] T023 Ajouter visualisation surface de corrélation (3 graphiques côte à côte)
- [x] T024 Créer Quiz 3 : Corrélation (3 questions)

---

## Phase 7: Section 6 - Traitement parallèle

- [x] T025 Écrire configuration future/future.apply
- [x] T026 Écrire fonction process_plot() complète
- [x] T027 Implémenter traitement parallèle avec future_lapply
- [x] T028 Ajouter cache incrémental (RDS) avec réutilisation dans setups suivants
- [x] T029 Créer exercice traitement parallèle avec gradethis

---

## Phase 8: Section 7 - Analyse résultats

- [x] T030 Écrire calcul statistiques de recalage
- [x] T031 Ajouter tests statistiques (t.test) avec interprétation
- [x] T032 Écrire visualisation ggplot2 vecteurs correction + histogramme distances
- [x] T033 Ajouter export CSV et GeoPackage
- [x] T034 Créer Quiz 4 : Analyse (3 questions)

---

## Phase 9: Section 8 - Synthèse

- [x] T035 Écrire synthèse workflow complet (diagramme ASCII)
- [x] T036 Créer tableau produits générés
- [x] T037 Lister indicateurs nemeton concernés
- [x] T038 Ajouter bonnes pratiques et ressources

---

## Phase 10: Polish

- [x] T039 Tester tutoriel end-to-end avec learnr::run_tutorial()
- [x] T040 Vérifier tous les exercices gradethis (utilise quiz learnr - 4 quiz, 12 questions)
- [x] T041 Mettre à jour vignettes/tutorial-guide.Rmd (déjà fait)
- [x] T042 Mettre à jour TUTORIAL_INSTALL.md (corrigé "7 → 8 tutoriels")
- [x] T043 Exécuter R CMD check (0 errors, warnings attendus)

---

## Résumé

| Phase | Tâches | Description | Status |
|-------|--------|-------------|--------|
| 1 | T001-T004 (4) | Setup | ✅ |
| 2 | T005-T008 (4) | Introduction | ✅ |
| 3 | T009-T012 (4) | Chargement données | ✅ |
| 4 | T013-T016 (4) | Génération MNH | ✅ |
| 5 | T017-T020 (4) | Masque placette | ✅ |
| 6 | T021-T024 (4) | Corrélation | ✅ |
| 7 | T025-T029 (5) | Traitement parallèle | ✅ |
| 8 | T030-T034 (5) | Analyse résultats | ✅ |
| 9 | T035-T038 (4) | Synthèse | ✅ |
| 10 | T039-T043 (5) | Polish | ✅ |

**Total**: 43 tâches
**Progression**: 43/43 (100%)

---

## Notes de session

### 2026-01-19
- Correction paramètres `lidaRtRee::coregistration()` (trees, mask)
- Correction accès résultats `result$local_max$dx1`, etc.
- Ajout visualisation 3 graphiques côte à côte (avant/corrélation/après)
- Suppression section 6.4 redondante
- Implémentation cache centralisé : calcul en 6.3, réutilisation en 7.x
- Ajout interprétation t-test
- Ajout légende croix rouge + histogramme distances
