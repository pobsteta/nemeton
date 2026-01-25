# Tasks: Tutorial 10 - Classification d'Essences au Niveau Couronne

## Phase 1: Infrastructure (Priorité Haute) ✓

### T1.1 Créer la structure du tutoriel learnr ✓
- [x] Créer `inst/tutorials/10-species-classification/10-species-classification.Rmd`
- [x] Configurer le header YAML (learnr, timeouts, css)
- [x] Ajouter les métadonnées (titre, description, prérequis)
- [x] Importer le CSS custom depuis Tutorial 09

### T1.2 Implémenter les fonctions utilitaires ✓
- [x] `check_crs()` - Vérification du système de coordonnées
- [x] `assert_columns()` - Vérification des colonnes requises
- [x] `safe_read_las()` - Lecture LAS sécurisée avec gestion d'erreurs
- [x] `save_checkpoint()` / `load_checkpoint()` - Gestion des checkpoints RDS

### T1.3 Configurer le cache Tutorial 10 ✓
- [x] Définir le répertoire `result_classification/`
- [x] Créer les sous-répertoires nécessaires
- [x] Documenter la structure de cache

## Phase 2: Données d'entrée (Priorité Haute) ✓

### T2.1 Chargement des données existantes ✓
- [x] Charger les couronnes depuis Tutorial 07 (`crowns_complet.gpkg`)
- [x] Charger les métriques LiDAR depuis Tutorial 02/07
- [x] Implémenter le fallback vers données synthétiques
- [x] Vérifier les CRS et cohérence spatiale

### T2.2 Chargement des labels terrain ✓
- [x] Créer labels par cluster spatial (simulation Quatre Montagnes)
- [x] Créer la table de correspondance codes essences (`get_species_lookup()`)
- [x] Gérer les codes manquants ou inconnus
- [x] Documenter les essences disponibles (PIAB, ABAL, FASY, TABA)

### T2.3 Téléchargement/génération IRC ✓
- [x] Implémenter le téléchargement via happign (mode online)
- [x] Implémenter la génération synthétique (mode offline)
- [x] Calculer le NDVI
- [x] Sauvegarder dans le cache

## Phase 3: Feature Engineering (Priorité Haute) ✓

### T3.1 Features LiDAR ✓
- [x] Implémenter extraction métriques hauteur (z_mean, z_sd, z_p25, z_p50, z_p75, z_p95)
- [x] Utiliser exactextractr pour extraction par couronne
- [x] Gérer l'option sans CHM (données synthétiques)
- [x] Documenter chaque métrique

### T3.2 Features géométriques couronne ✓
- [x] Calculer surface (area_m2), périmètre (vectorisé)
- [x] Calculer compacité, rayon équivalent
- [x] Calculer ratio hauteur/rayon
- [x] Gérer les géométries invalides (filtrage polygones)

### T3.3 Features IRC ✓
- [x] Calculer NDVI
- [x] Extraire statistiques par couronne (exactextractr optimisé - 1 appel)
- [x] Calculer ratios spectraux (NIR/Red, NIR/Green, Red/Green)
- [x] Documenter les indices spectraux

## Phase 4: Dataset d'apprentissage (Priorité Moyenne) ✓

### T4.1 Assemblage du dataset ✓
- [x] Joindre features LiDAR + IRC + labels
- [x] Gérer les colonnes dupliquées (nom_fr.x/nom_fr.y)
- [x] Vérifier les doublons et conflits

### T4.2 Nettoyage des données ✓
- [x] Filtrer les NA dans les labels
- [x] Filtrer les lignes avec trop de NA features (max 30%)
- [x] Calculer les statistiques par classe
- [x] Implémenter le regroupement/suppression classes rares

### T4.3 Sélection des features ✓
- [x] Définir la liste des features finales (18 features)
- [x] Sauvegarder le checkpoint dataset (training_data.rds, feature_cols.rds)

## Phase 5: Validation Spatiale (Priorité Haute) ✓

### T5.1 Analyse d'autocorrélation
- [x] Documenter l'importance de la validation spatiale
- [ ] Utiliser `cv_spatial_autocor()` de blockCV (optionnel)

### T5.2 Création des folds spatiaux ✓
- [x] Configurer blockCV avec paramètres adaptés
- [x] Créer les k folds (k=5)
- [x] Ajouter sous-échantillonnage de sécurité (max 2000 lignes)
- [x] Fallback vers folds aléatoires si blockCV échoue

### T5.3 Comparaison CV méthodes
- [x] Documenter la différence CV random vs spatial
- [ ] Implémenter comparaison formelle (optionnel)

## Phase 6: Modélisation (Priorité Haute) ✓

### T6.1 Random Forest (ranger) ✓
- [x] Implémenter le modèle avec ranger
- [x] Configurer hyperparamètres (num.trees, mtry)
- [x] Extraire l'importance des variables
- [x] Corriger split train/test (80/20)

### T6.2 XGBoost ✓
- [x] Préparer les données (DMatrix, encoding numérique)
- [x] Configurer les paramètres multi:softprob
- [x] Corriger alignement matrice
- [x] Extraire l'importance des variables

### T6.3 Évaluation ✓
- [x] Calculer accuracy
- [x] Générer la matrice de confusion
- [x] Comparer RF vs XGBoost

### T6.4 Gestion de l'incertitude ✓
- [x] Implémenter le seuil de probabilité (config$prob_threshold)
- [x] Ajouter le flag "incertain"

## Phase 7: Cartographie (Priorité Moyenne) ✓

### T7.1 Prédiction globale ✓
- [x] Prédire sur TOUTES les couronnes (pas juste training_data)
- [x] Ajouter classes et probabilités
- [x] Gérer les couronnes sans features complètes

### T7.2 Visualisations ✓
- [x] Carte des classes prédites (palette essences)
- [x] Carte des probabilités (viridis)
- [x] Carte des zones incertaines
- [x] Zoom cohérent sur zone d'étude (100m x 100m)
- [x] Supprimer coordonnées X/Y des graphiques

### T7.3 Export ✓
- [x] Sauvegarder modèle RF (.rds)
- [x] Générer statistiques de résumé

## Phase 8: Quiz et Exercices (Priorité Moyenne) ✓

### T8.1 Quiz ✓
- [x] Quiz 1: Environnement et prérequis
- [x] Quiz 2: Données d'entrée
- [x] Quiz 3: Features LiDAR
- [x] Quiz 4: Features spectrales IRC
- [x] Quiz 5: Dataset d'apprentissage
- [x] Quiz 6: Validation spatiale
- [x] Quiz 7: Modélisation

### T8.2 Exercices interactifs ✓
- [x] Exercice 2.1: Charger couronnes (zoom 100m x 100m)
- [x] Exercice 2.2: Créer labels par cluster
- [x] Exercice 2.3: Charger/télécharger IRC
- [x] Exercice 3.1: Extraire métriques hauteur
- [x] Exercice 3.2: Calculer métriques forme
- [x] Exercice 4.1: Extraire features IRC (optimisé)
- [x] Exercice 5.1: Assembler dataset
- [x] Exercice 5.2: Nettoyer et sélectionner features
- [x] Exercice 6.1: Créer blocs spatiaux blockCV
- [x] Exercice 7.1: Entraîner Random Forest
- [x] Exercice 7.2: Entraîner XGBoost
- [x] Exercice 8.1: Cartographier prédictions

## Phase 9: Documentation (Priorité Basse)

### T9.1 Synthèse du tutoriel
- [x] Workflow complet documenté dans le tutoriel
- [ ] Tableau des produits générés
- [ ] Lien avec indicateurs nemeton
- [ ] Recommandations "aller plus loin"

### T9.2 Documentation technique
- [x] Documenter les paramètres par défaut (config)
- [ ] Documenter les formats de sortie

## Phase 10: Tests et Validation (Priorité Haute) ✓

### T10.1 Tests fonctionnels ✓
- [x] Tester le tutoriel complet (exercices 2.1 → 8.1)
- [x] Vérifier tous les checkpoints
- [x] Vérifier les exports

### T10.2 Tests de régression
- [ ] Créer `tests/testthat/test-tutorial-10.R`

### T10.3 Validation utilisateur
- [x] Test avec utilisateur (confirmé fonctionnel)

---

## Résumé

| Phase | Statut | Notes |
|-------|--------|-------|
| 1. Infrastructure | ✓ Terminé | Structure learnr complète |
| 2. Données entrée | ✓ Terminé | Zone 100m x 100m, labels clusters |
| 3. Feature Engineering | ✓ Terminé | LiDAR + IRC optimisé |
| 4. Dataset | ✓ Terminé | Gestion colonnes dupliquées |
| 5. Validation spatiale | ✓ Terminé | blockCV + fallback |
| 6. Modélisation | ✓ Terminé | RF + XGBoost fonctionnels |
| 7. Cartographie | ✓ Terminé | Prédiction toutes couronnes |
| 8. Quiz/Exercices | ✓ Terminé | 12 exercices, 7 quiz |
| 9. Documentation | Partiel | À compléter |
| 10. Tests | ✓ Terminé | Validé utilisateur |

**Statut global: FONCTIONNEL** - Tutorial 10 opérationnel de bout en bout.

## Commits récents (session actuelle)

- `c0fcef8` fix(T10): filtrer les géométries polygonales après st_intersection
- `a67aebb` fix(T10): limiter zone_etude à 100m x 100m pour cohérence du pipeline
- `f38cb39` fix(T10): ajouter sous-échantillonnage de sécurité dans exo 6.1
- `0ab7cd0` fix(T10): corriger exercice 5.1 pour colonnes dupliquées
- `12fb1c3` perf(T10): optimiser extraction IRC avec stack unique (exo 4.1)
- `c3ed67f` perf(T10): vectoriser le calcul du périmètre (exo 3.2)
