# Nemeton Package Constitution

## Core Principles

### I. Open Data First
Priorité absolue aux données ouvertes et accessibles pour garantir la reproductibilité et l'adoption large :
- Toutes les fonctions doivent supporter des sources de données open data (IGN, Copernicus, OpenStreetMap, etc.)
- Les exemples et vignettes utilisent exclusivement des données ouvertes ou synthétiques
- Les API propriétaires ou payantes sont supportées uniquement en extension optionnelle
- Documentation claire des sources de données recommandées pour chaque indicateur

### II. Interopérabilité R Spatial (NON-NÉGOCIABLE)
Compatible avec l'écosystème R spatial standard pour maximiser l'adoption :
- Support obligatoire des objets `sf` pour les vecteurs
- Support obligatoire des objets `SpatRaster` (terra) pour les rasters
- Compatibilité avec le tidyverse (pipe `%>%` et `|>`)
- Pas de réinvention : utiliser `exactextractr` pour l'extraction zonale, `sf` pour les opérations vectorielles
- Interopérabilité avec QGIS/ArcGIS via exports standard (GeoPackage, shapefile, GeoTIFF)

### III. Modularité et Séparation des Responsabilités
Architecture modulaire stricte pour maintenabilité et extensibilité :
- Chaque module R a une responsabilité unique et claire (unités, couches, indicateurs, visualisation, etc.)
- Séparation acquisition / calcul / agrégation / visualisation
- Pas de couplage fort entre modules (injection de dépendances via arguments)
- Fonctions composables : les fonctions de haut niveau composent des fonctions de bas niveau
- Maximum 300 lignes par fonction ; au-delà, refactoriser

### IV. Test-First avec Fixtures (NON-NÉGOCIABLE)
TDD strict avec tests de régression pour garantir la stabilité scientifique :
- Écriture des tests AVANT l'implémentation (cycle Red-Green-Refactor)
- Couverture minimale : 80% (objectif : 90% pour v1.0)
- Fixtures obligatoires pour tests de régression des indicateurs (valeurs attendues stockées en `.rds`)
- Toute fonction exportée doit avoir au moins un test unitaire
- Tests d'intégration pour workflows complets (création unités → calcul → visualisation)
- Tests de performance pour scalabilité (minimum 1000 unités)

### V. Transparence et Traçabilité
Calculs scientifiques auditables et reproductibles :
- Tous les paramètres de calcul doivent être explicites (pas de valeurs magiques cachées)
- Métadonnées obligatoires : sources de données, date de calcul, paramètres utilisés
- Messages informatifs (`cli`) pour opérations majeures (reprojection, découpage, calculs longs)
- Warnings clairs en cas de données manquantes ou problématiques
- Support de reproductibilité via `targets`/`drake` dès la conception

### VI. Extensibilité par Design
Système ouvert permettant l'ajout d'indicateurs personnalisés sans modifier le package :
- API claire pour enregistrer de nouveaux indicateurs (`nemeton_indicator()`, `register_indicator()`)
- Support de fonctions custom inline dans `nemeton_compute()`
- Pas de liste fermée d'indicateurs : tous les indicateurs built-in utilisent la même API publique
- Paramètres de normalisation et d'agrégation entièrement configurables par l'utilisateur
- Hooks optionnels pour callbacks avancés

### VII. Simplicité et YAGNI
Éviter la sur-ingénierie, implémenter uniquement ce qui est nécessaire :
- Commencer simple : MVP fonctionnel avant optimisations prématurées
- Pas de fonctionnalités "au cas où" : chaque feature doit résoudre un besoin réel documenté
- Préférer la clarté à la performance (sauf goulots identifiés par profiling)
- Éviter les abstractions prématurées : 3 occurrences similaires avant factorisation
- Code auto-documenté : noms explicites > commentaires

## Contraintes Architecturales

### Stack Technique
**Obligatoire** :
- **Langage** : R >= 4.1.0
- **Vecteurs** : `sf` >= 1.0-0
- **Rasters** : `terra` >= 1.7-0 (pas `raster` legacy)
- **Extraction zonale** : `exactextractr` >= 0.9.0
- **Manipulation de données** : `dplyr` >= 1.1.0
- **Visualisation** : `ggplot2` >= 3.4.0
- **Métaprogrammation** : `rlang` >= 1.1.0
- **Messages** : `cli` >= 3.6.0

**Interdit** :
- Package `raster` (déprécié, remplacé par `terra`)
- Package `sp` (déprécié, remplacé par `sf`)
- Dépendances propriétaires ou fermées

### Paradigme de Programmation
- **Programmation fonctionnelle** : fonctions pures autant que possible (pas d'effets de bord cachés)
- **Classes S3** : simplicité et compatibilité tidyverse (pas S4 ni R6 sauf justification forte)
- **Tidy evaluation** : utiliser `rlang` pour NSE quand nécessaire, sinon éviter
- **Pipe-friendly** : toutes les fonctions principales compatibles `%>%` et `|>`

### Nommage (NON-NÉGOCIABLE)
- **Fonctions exportées** : préfixe `nemeton_` (ex: `nemeton_compute()`)
- **Indicateurs** : préfixe `indicator_` (ex: `indicator_carbon()`)
- **Arguments** : `snake_case` strict
- **Classes S3** : `nemeton_*` (ex: `nemeton_units`, `nemeton_project`)
- **Fichiers** : `nom-module.R` (tirets, pas underscores)
- **Tests** : `test-nom-module.R`

### Gestion des Erreurs
- Validation précoce : vérifier les inputs dès l'entrée de fonction
- Messages explicites via `cli::cli_abort()`, `cli::cli_warn()`
- Pas d'erreurs silencieuses : toujours informer l'utilisateur
- Pour calculs d'indicateurs : warnings par indicateur mais ne pas stopper les autres

## Standards de Qualité

### Documentation (NON-NÉGOCIABLE)
- **roxygen2** obligatoire pour toute fonction exportée
- Documentation minimale : `@param`, `@return`, `@examples`, `@seealso`
- Exemples reproductibles (`\dontrun{}` uniquement si dépendance externe)
- Vignettes obligatoires : 1 intro + 1 workflow basique minimum pour v0.1.0
- Site pkgdown configuré et déployé automatiquement

### Style de Code
- **Linter** : `lintr::lint_package()` sans erreurs
- **Formatter** : `styler::style_pkg()` (Tidyverse style guide)
- Longueur de ligne : <= 80 caractères
- Indentation : 2 espaces (pas de tabs)
- Pas de code commenté dans les commits (utiliser git pour l'historique)

### Performance
- Fonction `nemeton_compute()` doit supporter >= 1000 unités sans crash
- Extraction zonale via `exactextractr` (> 10x plus rapide que `raster::extract`)
- Chargement lazy des couches (ne pas tout charger en mémoire)
- Support optionnel de calcul parallèle (`future` backend) pour v0.4.0+

### Versioning Sémantique
Format : `MAJOR.MINOR.PATCH`
- **MAJOR** : changements incompatibles de l'API
- **MINOR** : nouvelles fonctionnalités rétrocompatibles
- **PATCH** : corrections de bugs rétrocompatibles
- Pre-release : `0.x.y` (API peut changer sans MAJOR bump)
- Stable : `>= 1.0.0` (API publique gelée, breaking changes = MAJOR)

## Workflow de Développement

### Cycle de Développement
1. **Issue** : créer une issue décrivant la feature/bug
2. **Branche** : `git checkout -b <numero-issue>-nom-feature`
3. **Tests** : écrire les tests AVANT le code (TDD)
4. **Implémentation** : coder jusqu'à ce que les tests passent
5. **Documentation** : roxygen2 + vignette si nouvelle feature majeure
6. **Check** : `devtools::check()` doit passer sans erreurs ni warnings
7. **PR** : pull request avec description claire, référence à l'issue
8. **Revue** : au moins 1 approbation requise
9. **Merge** : squash ou rebase, pas de merge commits sauf multi-commits logiques

### Tests Requis Avant Merge
- `devtools::test()` : tous les tests passent
- `devtools::check()` : 0 erreurs, 0 warnings, 0 notes
- `lintr::lint_package()` : 0 erreurs de style
- Couverture >= 80% : `covr::package_coverage()`

### Revue de Code
**Checklist du reviewer** :
- [ ] Tests présents et pertinents
- [ ] Documentation roxygen2 complète
- [ ] Pas de duplication de code
- [ ] Respect des principes de la constitution
- [ ] Nommage cohérent avec conventions
- [ ] Pas de warnings lors de `devtools::check()`
- [ ] Exemples reproductibles

### Données de Test
- Toutes les fixtures dans `tests/testthat/fixtures/`
- Données d'exemple du package dans `data/` (documentées avec `data-raw/`)
- Taille maximale : 5 Mo pour `data/`, 1 Mo pour fixtures
- Données synthétiques préférées aux données réelles pour tests

## Gouvernance

### Autorité de la Constitution
- Cette constitution supersède toute autre documentation en cas de conflit
- Les principes NON-NÉGOCIABLES ne peuvent être violés sans consensus unanime
- Toute PR doit être conforme à la constitution
- Le reviewer doit vérifier la conformité constitutionnelle

### Amendements
Modifications de la constitution requièrent :
1. Proposition documentée avec justification
2. Discussion ouverte (issue dédiée)
3. Approbation des mainteneurs principaux
4. Mise à jour du numéro de version de la constitution
5. Plan de migration si impact sur code existant

### Non-Conformité
- Code non-conforme peut être rejeté en PR même s'il fonctionne
- Exceptions temporaires possibles si documentées et issue de suivi créée
- Pas d'exceptions pour principes NON-NÉGOCIABLES

### Ressources de Référence
- **Spécification technique** : `SPECIFICATION_TECHNIQUE.md` (détails d'implémentation)
- **Style guide** : Tidyverse style guide (https://style.tidyverse.org/)
- **R Packages book** : https://r-pkgs.org/

**Version** : 1.0.0 | **Ratified** : 2026-01-04 | **Last Amended** : 2026-01-04
