# Spécification Fonctionnelle : nemetonApp v0.7.0

**Version** : 1.0.0
**Date** : 2026-01-25
**Statut** : Draft
**Auteur** : Claude (spec-kit)

---

## 1. Résumé Exécutif

### 1.1 Vision

nemetonApp est une application Shiny intégrée au package nemeton permettant aux forestiers et gestionnaires de :
- Sélectionner des parcelles cadastrales sur une carte interactive
- Calculer automatiquement les 29 indicateurs nemeton (12 familles)
- Analyser les résultats via des onglets dédiés par famille
- Exporter un rapport PDF complet et les données en GeoPackage

### 1.2 Objectifs Métier

| Objectif | Métrique de Succès |
|----------|-------------------|
| Simplifier l'accès aux indicateurs nemeton | Aucune ligne de code R requise pour l'utilisateur final |
| Accélérer les diagnostics forestiers | Calcul complet < 5 min pour 20 parcelles |
| Standardiser les rapports | PDF reproductible avec toutes les analyses |
| Permettre le travail terrain | Interface responsive tablette |

### 1.3 Utilisateurs Cibles

- **Forestiers** : Diagnostic de parcelles, planification d'interventions
- **Gestionnaires** : Suivi patrimonial, reporting, comparaison de zones

---

## 2. Périmètre Fonctionnel

### 2.1 Dans le Périmètre (In Scope)

- Recherche de commune (autocomplétion, code postal, filtre département)
- Affichage carte avec parcelles cadastrales (fond OSM ou satellite)
- Sélection/désélection par clic simple (max 20 parcelles)
- Création de projet avec métadonnées
- Calcul asynchrone et parallélisé des 29 indicateurs
- 12 onglets d'analyse par famille d'indicateurs
- Onglet synthèse avec radar global et récapitulatif
- Export PDF (Quarto) et GeoPackage
- Cache local des données (GeoParquet)
- Internationalisation FR/EN
- Interface responsive (tablette)
- Tour guidé au premier lancement

### 2.2 Hors Périmètre (Out of Scope)

- Comparaison multi-projets
- Authentification utilisateur
- Déploiement serveur (shinyapps.io, Shiny Server)
- Modification des parcelles après lancement des calculs
- Export CSV ou images individuelles
- Indicateurs personnalisés

---

## 3. User Stories

### US1 [P1] - Recherche et Sélection de Commune

**En tant que** forestier,
**Je veux** rechercher une commune française facilement,
**Afin de** localiser la zone d'étude.

#### Critères d'Acceptation

- [ ] AC1.1 : Autocomplétion du nom de commune après 3 caractères
- [ ] AC1.2 : Recherche par code postal (5 chiffres)
- [ ] AC1.3 : Filtre préalable par département (liste déroulante)
- [ ] AC1.4 : Affichage du nombre de résultats trouvés
- [ ] AC1.5 : Zoom automatique sur la commune sélectionnée

---

### US2 [P1] - Affichage Carte et Parcelles Cadastrales

**En tant que** forestier,
**Je veux** visualiser les parcelles cadastrales sur une carte,
**Afin de** identifier les zones d'intérêt.

#### Critères d'Acceptation

- [ ] AC2.1 : Carte centrée sur la commune sélectionnée
- [ ] AC2.2 : Parcelles cadastrales affichées avec contours
- [ ] AC2.3 : Choix du fond de carte (OSM / Satellite) via bouton switch
- [ ] AC2.4 : Source cadastre : API Cadastre avec fallback happign si indisponible
- [ ] AC2.5 : Indicateur de chargement pendant récupération des parcelles
- [ ] AC2.6 : Message d'erreur explicite si API indisponible

---

### US3 [P1] - Sélection des Parcelles

**En tant que** forestier,
**Je veux** sélectionner des parcelles en cliquant dessus,
**Afin de** définir le périmètre d'étude.

#### Critères d'Acceptation

- [ ] AC3.1 : Clic simple = sélection (parcelle surlignée)
- [ ] AC3.2 : Clic sur parcelle sélectionnée = désélection
- [ ] AC3.3 : Limite à 20 parcelles maximum
- [ ] AC3.4 : Compteur de parcelles sélectionnées affiché
- [ ] AC3.5 : Message d'avertissement si limite atteinte
- [ ] AC3.6 : Liste des parcelles sélectionnées (références cadastrales)
- [ ] AC3.7 : Bouton "Tout désélectionner"

---

### US4 [P1] - Création de Projet

**En tant que** gestionnaire,
**Je veux** créer un projet avec des métadonnées,
**Afin de** organiser mes études.

#### Critères d'Acceptation

- [ ] AC4.1 : Formulaire avec champs :
  - Nom du projet (obligatoire, max 100 caractères)
  - Description (optionnel, max 500 caractères)
  - Propriétaire/Gestionnaire (optionnel, max 100 caractères)
  - Date d'étude (automatique avec horodatage, modifiable)
- [ ] AC4.2 : Validation des champs obligatoires
- [ ] AC4.3 : Création du répertoire projet dans le dossier utilisateur
- [ ] AC4.4 : Sauvegarde des métadonnées en JSON
- [ ] AC4.5 : Liste des projets récents au lancement

---

### US5 [P1] - Lancement des Calculs

**En tant que** forestier,
**Je veux** lancer le calcul des indicateurs,
**Afin d'** obtenir l'analyse de mes parcelles.

#### Critères d'Acceptation

- [ ] AC5.1 : Bouton "Lancer les calculs" actif si ≥1 parcelle sélectionnée
- [ ] AC5.2 : Confirmation avant lancement (modal)
- [ ] AC5.3 : **Phase 1 - Téléchargement préventif** : Récupération de toutes les données externes avant calcul
- [ ] AC5.4 : Progression téléchargement visible (données X/Y téléchargées)
- [ ] AC5.5 : Si téléchargement échoue → message explicatif, annulation possible
- [ ] AC5.6 : **Phase 2 - Calculs** : Exécutés en background (async) sur données locales
- [ ] AC5.7 : Barre de progression globale visible
- [ ] AC5.8 : Détail des jobs en cours (indicateur X/29)
- [ ] AC5.9 : Parallélisation maximale des calculs
- [ ] AC5.10 : État du projet : Brouillon → Téléchargement → En cours → Terminé
- [ ] AC5.11 : Modification des parcelles impossible après lancement

---

### US6 [P2] - Gestion des Données Manquantes

**En tant que** utilisateur,
**Je veux** être informé des données non disponibles,
**Afin de** comprendre les indicateurs incomplets.

#### Critères d'Acceptation

- [ ] AC6.1 : Indicateurs sans données = grisés dans l'interface
- [ ] AC6.2 : Message explicatif au survol (tooltip)
- [ ] AC6.3 : Causes identifiées : données LiDAR absentes, connexion KO, source indisponible
- [ ] AC6.4 : Récapitulatif des indicateurs manquants dans synthèse
- [ ] AC6.5 : Calcul des autres indicateurs non bloqué

---

### US7 [P1] - Onglet Synthèse

**En tant que** gestionnaire,
**Je veux** avoir une vue globale des résultats,
**Afin de** comprendre rapidement le diagnostic.

#### Critères d'Acceptation

- [ ] AC7.1 : Accessible uniquement si projet "Terminé"
- [ ] AC7.2 : Radar plot 12 axes (une par famille)
- [ ] AC7.3 : Tableau récapitulatif des scores par famille
- [ ] AC7.4 : Carte thématique des parcelles (score global)
- [ ] AC7.5 : Bouton téléchargement PDF
- [ ] AC7.6 : Bouton téléchargement GeoPackage
- [ ] AC7.7 : Statistiques globales (surface, nb parcelles, scores min/max/moy)

---

### US8 [P1] - Onglets Familles d'Indicateurs (×12)

**En tant que** forestier,
**Je veux** analyser chaque famille en détail,
**Afin de** comprendre les forces/faiblesses de la zone.

#### Critères d'Acceptation

- [ ] AC8.1 : 12 onglets : C, B, W, A, F, L, T, R, S, P, E, N
- [ ] AC8.2 : Accessibles uniquement si projet "Terminé"
- [ ] AC8.3 : Graphiques spécifiques à chaque famille :
  - Carbone (C) : graphique biomasse, NDVI
  - Biodiversité (B) : carte protection, diversité structurale
  - Eau (W) : réseau hydrographique, zones humides
  - Air (A) : couverture forestière, qualité
  - Fertilité (F) : classes sol, risque érosion
  - Paysage (L) : fragmentation, ratio bordure
  - Temporel (T) : ancienneté, taux de changement
  - Risques (R) : feu, tempête, sécheresse, abroutissement
  - Social (S) : sentiers, accessibilité, proximité population
  - Production (P) : volume, productivité, qualité
  - Énergie (E) : potentiel bois-énergie, évitement CO2
  - Naturalité (N) : distance infrastructures, continuité, score
- [ ] AC8.4 : Tableau des valeurs par parcelle
- [ ] AC8.5 : Tooltips d'aide sur chaque indicateur
- [ ] AC8.6 : Indicateurs manquants grisés avec explication

---

### US9 [P2] - Export PDF

**En tant que** gestionnaire,
**Je veux** télécharger un rapport PDF complet,
**Afin de** partager les résultats.

#### Critères d'Acceptation

- [ ] AC9.1 : Format Quarto (.qmd → .pdf)
- [ ] AC9.2 : Contenu : métadonnées projet, synthèse, 12 analyses familles
- [ ] AC9.3 : Cartes en version statique (non interactives)
- [ ] AC9.4 : Graphiques vectoriels (qualité impression)
- [ ] AC9.5 : Génération asynchrone avec indicateur de progression
- [ ] AC9.6 : Téléchargement automatique à la fin

---

### US10 [P2] - Export GeoPackage

**En tant que** utilisateur technique,
**Je veux** exporter les données géospatiales,
**Afin de** les utiliser dans un SIG.

#### Critères d'Acceptation

- [ ] AC10.1 : Format GeoPackage (.gpkg)
- [ ] AC10.2 : Contenu : géométries parcelles + tous les indicateurs calculés
- [ ] AC10.3 : Métadonnées incluses (projet, date, CRS)
- [ ] AC10.4 : CRS : EPSG:2154 (Lambert 93)
- [ ] AC10.5 : Téléchargement direct

---

### US11 [P2] - Cache et Persistance

**En tant que** utilisateur,
**Je veux** que les données soient sauvegardées localement,
**Afin de** ne pas recharger inutilement.

#### Critères d'Acceptation

- [ ] AC11.1 : Format de cache : GeoParquet
- [ ] AC11.2 : Répertoire projet unique par étude
- [ ] AC11.3 : Structure : `~/.nemeton/projects/{nom_projet}/`
- [ ] AC11.4 : Fichiers : métadonnées.json, parcelles.parquet, indicateurs.parquet
- [ ] AC11.5 : Réouverture du projet = chargement depuis cache
- [ ] AC11.6 : Liste des projets récents au lancement

---

### US11b [P2] - Gestion des Projets Corrompus

**En tant que** utilisateur,
**Je veux** être informé si un projet est corrompu ou incomplet,
**Afin de** pouvoir le supprimer et recommencer.

#### Critères d'Acceptation

- [ ] AC11b.1 : Détection automatique à l'ouverture d'un projet corrompu
- [ ] AC11b.2 : Fichiers corrompus = parquet illisible, JSON invalide
- [ ] AC11b.3 : Projet incomplet = calcul interrompu (état "En cours" mais pas de résultats)
- [ ] AC11b.4 : Modal de confirmation : "Ce projet est corrompu/incomplet. Voulez-vous le supprimer ?"
- [ ] AC11b.5 : Option "Supprimer" → suppression du répertoire projet
- [ ] AC11b.6 : Option "Annuler" → retour à la liste des projets
- [ ] AC11b.7 : Projets corrompus marqués visuellement dans la liste (icône warning)

---

### US12 [P2] - Internationalisation

**En tant que** utilisateur anglophone,
**Je veux** utiliser l'interface en anglais,
**Afin de** comprendre les fonctionnalités.

#### Critères d'Acceptation

- [ ] AC12.1 : Langues supportées : français (fr), anglais (en)
- [ ] AC12.2 : Sélecteur de langue dans l'interface
- [ ] AC12.3 : Détection automatique de la langue système
- [ ] AC12.4 : Persistance du choix de langue
- [ ] AC12.5 : Tous les textes UI traduits
- [ ] AC12.6 : Tooltips et aide traduits
- [ ] AC12.7 : Rapport PDF dans la langue sélectionnée

---

### US13 [P3] - Tour Guidé

**En tant que** nouvel utilisateur,
**Je veux** être guidé au premier lancement,
**Afin de** comprendre l'interface.

#### Critères d'Acceptation

- [ ] AC13.1 : Tour automatique au premier lancement
- [ ] AC13.2 : Bouton "Passer le tour" visible
- [ ] AC13.3 : Étapes : recherche commune → sélection parcelles → création projet → lancement → résultats
- [ ] AC13.4 : Bulles explicatives sur chaque élément clé
- [ ] AC13.5 : Possibilité de relancer le tour depuis l'aide
- [ ] AC13.6 : Préférence "ne plus afficher" sauvegardée

---

### US14 [P3] - Aide et Documentation

**En tant que** utilisateur,
**Je veux** accéder à l'aide contextuelle,
**Afin de** comprendre les indicateurs.

#### Critères d'Acceptation

- [ ] AC14.1 : Tooltips sur tous les indicateurs et familles
- [ ] AC14.2 : Lien vers documentation nemeton (pkgdown)
- [ ] AC14.3 : Icône aide (?) dans l'en-tête
- [ ] AC14.4 : Description des familles dans chaque onglet
- [ ] AC14.5 : Explication des méthodes de calcul

---

### US15 [P3] - Interface Responsive

**En tant que** forestier terrain,
**Je veux** utiliser l'app sur tablette,
**Afin de** faire des diagnostics sur le terrain.

#### Critères d'Acceptation

- [ ] AC15.1 : Layout adaptatif (mobile-first)
- [ ] AC15.2 : Navigation par onglets accessible sur petit écran
- [ ] AC15.3 : Carte utilisable en tactile (zoom, pan)
- [ ] AC15.4 : Boutons suffisamment grands (min 44px)
- [ ] AC15.5 : Test sur tablette 10" minimum

---

## 4. Exigences Non-Fonctionnelles

### 4.1 Performance

| Exigence | Seuil |
|----------|-------|
| Temps de chargement initial | < 3 secondes |
| Récupération parcelles cadastrales | < 5 secondes par commune |
| Calcul complet 20 parcelles | < 10 minutes |
| Génération PDF | < 30 secondes |
| Mémoire maximale | < 4 Go RAM |

### 4.2 Fiabilité

- Fallback API Cadastre → happign si indisponible
- Timeout configurable sur les appels WFS/API
- Retry automatique (3 tentatives) sur erreurs réseau
- Sauvegarde automatique de l'état du projet

### 4.3 Utilisabilité

- Interface en français par défaut
- Messages d'erreur explicites et actionnables
- Progression visible pour toutes les opérations longues
- Confirmation avant actions destructives

### 4.4 Compatibilité

- R >= 4.1.0
- Navigateurs : Chrome, Firefox, Safari, Edge (dernières versions)
- Résolution minimum : 768×1024 (tablette portrait)

### 4.5 Accessibilité

| Exigence | Spécification |
|----------|---------------|
| Standard | WCAG 2.1 niveau AA |
| Contraste texte | Ratio minimum 4.5:1 |
| Contraste éléments UI | Ratio minimum 3:1 |
| Navigation clavier | Tous les éléments interactifs accessibles au clavier |
| Daltonisme | Palettes viridis exclusivement (colorblind-friendly) |
| Symboles | Utiliser des symboles/formes en complément des couleurs |
| Labels | Tous les graphiques avec légendes textuelles |
| Focus visible | Indicateur de focus clairement visible |
| Taille tactile | Zones cliquables minimum 44×44 px |

---

## 5. Dépendances Externes

### 5.1 APIs et Services

| Service | Usage | Fallback |
|---------|-------|----------|
| API Cadastre (data.gouv.fr) | Parcelles cadastrales | happign WFS |
| INPN WFS | Zones protégées | Données locales si cache |
| IGN BD Forêt | Données forestières | Proxy nemeton |
| Corine Land Cover | Occupation du sol | Données locales |

### 5.2 Packages R Requis

- **golem** : Framework Shiny
- **shiny** : Interface web
- **bslib** : Thème Bootstrap
- **leaflet** : Carte interactive
- **sf** : Données spatiales
- **arrow** : GeoParquet
- **future** / **promises** : Calculs asynchrones
- **quarto** : Génération PDF
- **cicerone** : Tour guidé
- **shiny.i18n** : Internationalisation

---

## 6. Contraintes et Hypothèses

### 6.1 Contraintes

- Intégration dans le package nemeton existant (pas de package séparé)
- Point d'entrée : `nemeton::run_app()`
- Compatibilité avec l'API nemeton existante (`nemeton_compute()`, etc.)
- Déploiement local uniquement (pas de serveur)

### 6.2 Hypothèses

- L'utilisateur dispose d'une connexion Internet pour les données externes
- Les calculs LiDAR ne sont pas disponibles (indicateurs grisés si absents)
- **Quarto** : Installation automatique via `quarto::quarto_install()` si absent
- Le répertoire utilisateur est accessible en écriture
- Toutes les données externes sont téléchargées **avant** le lancement des calculs (cache préventif)

---

## 7. Glossaire

| Terme | Définition |
|-------|------------|
| Parcelle cadastrale | Unité foncière identifiée par une référence unique (section + numéro) |
| Famille d'indicateurs | Groupe thématique d'indicateurs (ex: Carbone, Biodiversité) |
| GeoParquet | Format de stockage géospatial columnar haute performance |
| Radar plot | Graphique en étoile montrant plusieurs dimensions |
| WFS | Web Feature Service - protocole d'accès aux données géographiques |

---

## 8. Annexes

### A. Familles d'Indicateurs

| Code | Famille | Indicateurs |
|------|---------|-------------|
| C | Carbone & Vitalité | C1 (biomasse), C2 (NDVI) |
| B | Biodiversité | B1 (protection), B2 (structure), B3 (connectivité) |
| W | Eau | W1 (réseau), W2 (zones humides), W3 (TWI) |
| A | Air & Microclimat | A1 (couverture), A2 (qualité) |
| F | Fertilité | F1 (classe sol), F2 (érosion) |
| L | Paysage | L1 (fragmentation), L2 (ratio bordure) |
| T | Temporel | T1 (ancienneté), T2 (changement) |
| R | Risques | R1 (feu), R2 (tempête), R3 (sécheresse), R4 (abroutissement) |
| S | Social | S1 (sentiers), S2 (accessibilité), S3 (proximité) |
| P | Production | P1 (volume), P2 (productivité), P3 (qualité) |
| E | Énergie | E1 (bois-énergie), E2 (évitement CO2) |
| N | Naturalité | N1 (distance), N2 (continuité), N3 (score) |

### B. Structure du Répertoire Projet

```
~/.nemeton/projects/{nom_projet}/
├── metadata.json           # Métadonnées projet
├── parcelles.parquet       # Géométries sélectionnées
├── indicateurs.parquet     # Résultats des calculs
├── layers/                 # Cache des couches de données
│   ├── cadastre.parquet
│   ├── bdforet.parquet
│   └── ...
├── report.pdf              # Rapport généré
└── export.gpkg             # Export GeoPackage
```
