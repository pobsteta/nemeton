# Feature Specification: MVP Package nemeton v0.1.0

**Feature Branch**: `001-mvp-v0.1.0`
**Created**: 2026-01-04
**Status**: Draft
**Input**: Package R nemeton - Minimum Viable Product pour analyse forestière systémique

## User Scenarios & Testing

### User Story 1 - Analyse simple d'une forêt (Priority: P1)

Un forestier ou écologue souhaite évaluer rapidement un massif forestier en calculant des indicateurs clés (carbone, biodiversité, eau, fragmentation, accessibilité) à partir de données spatiales standard.

**Why this priority**: C'est le coeur de valeur du package - permettre une analyse Néméton basique sans avoir à coder chaque indicateur manuellement.

**Independent Test**: Peut être testé en fournissant des polygones de parcelles et des rasters/vecteurs basiques. Doit retourner un objet sf avec les 5 indicateurs calculés.

**Acceptance Scenarios**:

1. **Given** des polygones de parcelles forestières (sf) et des rasters (NDVI, MNT), **When** l'utilisateur appelle `nemeton_compute(units, layers, indicators = c("carbon", "biodiversity", "water"))`, **Then** un objet sf est retourné avec 3 colonnes d'indicateurs numériques
2. **Given** des données avec CRS différents, **When** `nemeton_compute()` est appelé avec `preprocess = TRUE`, **Then** les données sont automatiquement reprojetées dans le CRS des unités avec un message informatif
3. **Given** une couche manquante pour un indicateur, **When** le calcul est lancé, **Then** un warning est émis pour cet indicateur mais les autres sont calculés

---

### User Story 2 - Normalisation et indice composite (Priority: P2)

L'utilisateur souhaite normaliser les indicateurs bruts (0-100) et calculer un indice Néméton global pondéré pour comparer les unités forestières.

**Why this priority**: Permet de passer de valeurs brutes hétérogènes à un score comparable et interprétable. Essentiel pour la prise de décision.

**Independent Test**: Prend un sf avec indicateurs bruts, applique normalisation et agrégation, retourne un sf avec colonnes normalisées + indice global.

**Acceptance Scenarios**:

1. **Given** un sf avec 5 indicateurs calculés, **When** `nemeton_index(data, method = "weighted", weights = c(0.2, 0.2, 0.2, 0.2, 0.2))` est appelé, **Then** une colonne `nemeton_index` est ajoutée avec valeurs entre 0 et 100
2. **Given** un indicateur avec polarité inversée (fragmentation = mauvais), **When** normalisation avec `polarity = c(fragmentation = -1)`, **Then** les valeurs sont inversées avant agrégation
3. **Given** des indicateurs non normalisés, **When** `normalize = TRUE` dans `nemeton_index()`, **Then** normalisation min-max automatique avant agrégation

---

### User Story 3 - Visualisation cartographique (Priority: P2)

L'utilisateur veut visualiser spatialement un indicateur sur ses unités forestières avec une carte thématique prête à l'emploi.

**Why this priority**: Visualisation essentielle pour communication et exploration des résultats. Doit être simple (1 ligne de code).

**Independent Test**: Appelle `nemeton_map(data, "carbon")`, vérifie qu'un ggplot valide est retourné et sauvegardable.

**Acceptance Scenarios**:

1. **Given** un sf avec indicateur `carbon`, **When** `nemeton_map(data, "carbon")` est appelé, **Then** un ggplot avec géométries colorées par valeur est retourné
2. **Given** un ggplot généré, **When** l'utilisateur ajoute `+ labs(title = "Mon titre")`, **Then** le titre est modifié (ggplot customisable)
3. **Given** un indicateur inexistant, **When** `nemeton_map(data, "indicateur_fictif")`, **Then** une erreur explicite est levée

---

### User Story 4 - Profil radar d'une unité (Priority: P3)

L'utilisateur souhaite visualiser le profil multi-dimensionnel d'une parcelle spécifique sous forme de radar chart.

**Why this priority**: Utile pour comparer visuellement le profil d'une unité, mais moins critique que la carte. Peut être implémenté après le reste.

**Independent Test**: Appelle `nemeton_radar(data, unit_id = 5)`, vérifie qu'un radar chart ggplot est retourné.

**Acceptance Scenarios**:

1. **Given** un sf avec 5 indicateurs et 10 unités, **When** `nemeton_radar(data, unit_id = 5)` est appelé, **Then** un radar chart avec 5 axes est généré pour l'unité 5
2. **Given** aucun unit_id spécifié, **When** `nemeton_radar(data)`, **Then** le radar affiche la moyenne de toutes les unités
3. **Given** des indicateurs non normalisés, **When** `normalize = TRUE`, **Then** normalisation 0-100 avant affichage du radar

---

### Edge Cases

- Que se passe-t-il si toutes les valeurs d'un indicateur sont identiques (pas de variance) ?
  → Normalisation doit gérer ce cas (retourner 50 ou NA documenté)

- Que se passe-t-il si les géométries sont invalides ?
  → Validation avec `sf::st_is_valid()` et message d'erreur clair

- Que se passe-t-il si un raster est énorme (> 1GB) ?
  → Découpage automatique sur l'extent des unités si `preprocess = TRUE`

- Que se passe-t-il si l'utilisateur passe un chemin invalide pour une couche ?
  → Erreur claire lors de `nemeton_layers()` avec validation des fichiers

- Que se passe-t-il si aucun indicateur n'est spécifié ?
  → `indicators = "all"` par défaut calcule tous les indicateurs disponibles

## Requirements

### Functional Requirements

**Structure du package R**:
- **FR-001**: Le package DOIT suivre la structure standard R (`R/`, `man/`, `tests/`, `vignettes/`, `data/`, `DESCRIPTION`, `NAMESPACE`)
- **FR-002**: Le package DOIT être installable via `devtools::install()` et `devtools::check()` sans erreurs/warnings

**Gestion des unités spatiales**:
- **FR-003**: Le système DOIT permettre de créer des unités Néméton via `nemeton_units(sf_object, metadata = list())`
- **FR-004**: Les unités DOIVENT être des objets `sf` avec géométries POLYGON ou MULTIPOLYGON valides
- **FR-005**: Le système DOIT valider les géométries (CRS défini, non vides, valides) et ajouter un ID unique si absent
- **FR-006**: Les métadonnées (site, année, source) DOIVENT être stockées en attribut de l'objet

**Gestion des couches spatiales**:
- **FR-007**: Le système DOIT permettre de cataloguer des rasters et vecteurs via `nemeton_layers(rasters = list(), vectors = list())`
- **FR-008**: Le système DOIT valider l'existence des fichiers lors de la création du catalogue
- **FR-009**: Le chargement des couches DOIT être lazy (pas chargé en mémoire tant que non utilisé)

**Prétraitement**:
- **FR-010**: Le système DOIT reprojecter automatiquement les couches dans le CRS des unités si `preprocess = TRUE`
- **FR-011**: Le système DOIT découper les rasters sur l'extent des unités pour réduire la charge mémoire
- **FR-012**: Le système DOIT émettre des messages informatifs (via `cli`) pour chaque opération de prétraitement

**Calcul d'indicateurs**:
- **FR-013**: Le système DOIT fournir une fonction `nemeton_compute(units, layers, indicators)` pour calculer les indicateurs
- **FR-014**: Le système DOIT supporter au minimum 5 indicateurs pour le MVP:
  - `indicator_carbon()`: stock de carbone (biomasse)
  - `indicator_biodiversity()`: indice de biodiversité (Shannon, richesse)
  - `indicator_water()`: régulation hydrique (TWI, proximité réseau hydro)
  - `indicator_fragmentation()`: fragmentation forestière (nb patches, connectivité)
  - `indicator_accessibility()`: accessibilité (distance routes/sentiers)
- **FR-015**: Chaque indicateur DOIT retourner un vecteur numérique de même longueur que `nrow(units)`
- **FR-016**: Le système DOIT gérer les erreurs par indicateur (warning + continue) plutôt que tout stopper
- **FR-017**: Le résultat DOIT être un objet `sf` enrichi avec colonnes d'indicateurs

**Normalisation et indices**:
- **FR-018**: Le système DOIT fournir `nemeton_index()` pour normaliser et agréger les indicateurs
- **FR-019**: Le système DOIT supporter min-max (0-100), z-score, et normalisation par quantiles
- **FR-020**: Le système DOIT supporter l'agrégation pondérée (poids paramétrables par l'utilisateur)
- **FR-021**: Le système DOIT gérer la polarité des indicateurs (plus = mieux ou moins = mieux)

**Visualisations**:
- **FR-022**: Le système DOIT fournir `nemeton_map(data, indicator)` pour générer une carte thématique
- **FR-023**: Le système DOIT fournir `nemeton_radar(data, unit_id)` pour générer un diagramme radar
- **FR-024**: Les visualisations DOIVENT retourner des objets `ggplot` modifiables
- **FR-025**: Les visualisations DOIVENT utiliser des palettes accessibles (viridis par défaut)

**Documentation**:
- **FR-026**: Toutes les fonctions exportées DOIVENT avoir une documentation roxygen2 complète (`@param`, `@return`, `@examples`)
- **FR-027**: Le package DOIT inclure au minimum 2 vignettes: introduction + workflow basique
- **FR-028**: Le package DOIT inclure un README avec exemple de démarrage rapide
- **FR-029**: Le package DOIT inclure un dataset d'exemple `massif_demo` (50 parcelles + rasters fictifs)

**Tests**:
- **FR-030**: Le package DOIT atteindre >= 70% de couverture de tests (objectif MVP)
- **FR-031**: Chaque fonction exportée DOIT avoir au moins un test unitaire
- **FR-032**: Le package DOIT inclure des tests d'intégration (workflow complet de bout en bout)
- **FR-033**: Le package DOIT inclure des fixtures de test (données synthétiques dans `tests/testthat/fixtures/`)

### Key Entities

- **nemeton_units**: Objet S3 héritant de `sf`, représente les unités spatiales d'analyse avec métadonnées
- **nemeton_layers**: Liste S3 cataloguant les couches rasters et vecteurs avec chemins et métadonnées
- **Indicateurs**: Fonctions retournant vecteurs numériques (carbon, biodiversity, water, fragmentation, accessibility)
- **Indices**: Scores normalisés et agrégés (0-100) calculés à partir des indicateurs bruts

## Success Criteria

### Measurable Outcomes

- **SC-001**: Un utilisateur peut créer des unités, charger des couches, calculer 5 indicateurs et visualiser les résultats en moins de 10 lignes de code R
- **SC-002**: `nemeton_compute()` doit supporter au minimum 100 unités avec 5 indicateurs sur un laptop standard (<2 min)
- **SC-003**: `devtools::check()` doit passer sans erreurs ni warnings
- **SC-004**: La couverture de tests doit être >= 70% (mesurée avec `covr::package_coverage()`)
- **SC-005**: Les 2 vignettes (intro + workflow) doivent compiler sans erreurs et être lisibles en < 10 minutes
- **SC-006**: Le dataset d'exemple `massif_demo` doit être < 5 Mo et permettre de reproduire tous les exemples des vignettes
- **SC-007**: Toutes les fonctions exportées (au moins 10) doivent avoir des exemples exécutables dans leur documentation
