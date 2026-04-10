# CLAUDE.md — Néméton Development Reference

## Identité du projet

Néméton est une plateforme d’analyse forestière systémique développée
par Pascal Obstetar à titre personnel. Elle calcule 31 indicateurs
organisés en 12 familles, les affiche sur un radar, et génère des
perspectives IA adaptées à 15 profils d’acteurs de la filière
forêt-bois. Le nom vient du gaulois *nemeton* (sanctuaire en forêt).

Le package R `nemeton` (v0.14.1.9000) est le cœur du projet. Il contient
à la fois la logique métier (indicateurs, familles, radar) et
l’application Shiny/golem (nemetonApp).

## Convention NMT (Néméton Naming Convention)

Toutes les clés techniques du projet suivent cette norme :

- **snake_case français sans accent** : `famille_biodiversite`,
  `ndp_decouverte`
- **Translittération** : é→e, è→e, ê→e, à→a, ô→o, î→i, ù→u, ç→c
- **Codes courts en majuscules** : B, C, W, A, F, L, T, R, S, P, E, N,
  B1, C2
- **Maximum 30 caractères** par clé
- **Pas d’abréviation** sauf codes établis

Cette convention s’applique aux nouveaux fichiers et fonctions. Le code
existant (noms anglais comme `create_family_index`,
`indicator_carbon_biomass`) reste en l’état — on ne renomme pas ce qui
fonctionne.

## Architecture (4 packages, ADR-009)

    nemeton (ce repo)          → Package cœur + app Shiny. 31 indicateurs, 12 familles, radar, i18n, LLM. MIT.
    tree_sat_nemeton            → Classification d'essences par Sentinel-1/2. NDP 0. MIT.
    maestro_nemeton             → Classification d'essences par MAESTRO ViT (ortho+MNT). NDP 1+. MIT.
    platform_nemeton            → Documentation plateforme, ADR, glossaire. EUPL v1.2.

Règle : les dépendances vont toujours vers nemeton (cœur). Jamais
d’inverse.

## Les 12 familles d’indicateurs

| Code | Famille               | Indicateurs                                                  |
|------|-----------------------|--------------------------------------------------------------|
| B    | Biodiversité          | B1 (protection), B2 (structure), B3 (connectivité)           |
| C    | Carbone & Vitalité    | C1 (biomasse), C2 (NDVI)                                     |
| W    | Eau & Régulation      | W1 (réseau hydro), W2 (zones humides), W3 (TWI)              |
| A    | Air & Microclimat     | A1 (couverture arborée), A2 (qualité air)                    |
| F    | Fertilité des sols    | F1 (fertilité), F2 (érosion)                                 |
| L    | Paysage               | L1 (sylvosphère), L2 (fragmentation)                         |
| T    | Dynamique temporelle  | T1 (ancienneté), T2 (changement)                             |
| R    | Risques & Résilience  | R1 (feu), R2 (tempête), R3 (sécheresse), R4 (abroutissement) |
| S    | Social & Usages       | S1 (routes), S2 (bâti), S3 (population)                      |
| P    | Production & Économie | P1 (volume bois), P2 (station), P3 (qualité bois)            |
| E    | Énergie & Climat      | E1 (bois-énergie), E2 (évitement carbone)                    |
| N    | Naturalité            | N1 (distance infra), N2 (continuité), N3 (composite)         |

## Système NDP (Niveau De Précision) — ADR-011

Le NDP mesure la QUALITÉ des données d’entrée, PAS le nombre de familles
calculées. Les 12 familles sont toujours calculées, mais avec une
précision croissante.

| NDP | Clé             | Nom         | Fibonacci | Confiance φ | Sources                                 |
|-----|-----------------|-------------|-----------|-------------|-----------------------------------------|
| 0   | ndp_decouverte  | Découverte  | 1         | 8.3%        | Sentinel-2, WorldClim, BD TOPO, MNT 25m |
| 1   | ndp_observation | Observation | 1         | 16.7%       | \+ IGN RGE ALTI, BD ORTHO, LiDAR HD     |
| 2   | ndp_exploration | Exploration | 2         | 33.3%       | \+ Drone RGB, LiDAR drone               |
| 3   | ndp_diagnostic  | Diagnostic  | 3         | 58.3%       | \+ Inventaire terrain complet           |
| 4   | ndp_jumeau      | Jumeau      | 5         | 100%        | \+ Scanner terrestre, modèle 3D         |

**Pondération Fibonacci** : l’indice général est une moyenne pondérée
des familles, où le poids est le nombre de Fibonacci associé au NDP.
Plus le NDP est élevé, plus les indicateurs comptent dans l’indice.

**Confiance φ** : ratio du poids cumulé sur le poids total Fibonacci.
Affichée dans l’interface sous le score global.

**Détection automatique** : le NDP est déterminé par les sources de
données présentes (attributs du jeu de données), pas par le nombre
d’indicateurs calculés. L’app actuelle est toujours en NDP 0 (données
publiques uniquement).

### Implémentation NDP

Le fichier `R/ndp.R` contient : - `NDP_LEVELS` : configuration des 5
niveaux -
[`get_ndp_level()`](https://pobsteta.github.io/nemeton/reference/get_ndp_level.md),
[`get_ndp_name()`](https://pobsteta.github.io/nemeton/reference/get_ndp_name.md),
[`get_ndp_weight()`](https://pobsteta.github.io/nemeton/reference/get_ndp_weight.md),
[`get_ndp_confidence()`](https://pobsteta.github.io/nemeton/reference/get_ndp_confidence.md)
: accesseurs -
[`ndp_table()`](https://pobsteta.github.io/nemeton/reference/ndp_table.md)
: data.frame des 5 niveaux -
[`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
: détection du NDP depuis les données -
[`compute_general_index()`](https://pobsteta.github.io/nemeton/reference/compute_general_index.md)
: indice pondéré Fibonacci -
[`compute_general_index_mixed()`](https://pobsteta.github.io/nemeton/reference/compute_general_index_mixed.md)
: indice avec NDP mixte par indicateur - `ndp_badge()`,
`ndp_progress_bar()` : widgets HTML pour Shiny

Le score global dans `mod_synthesis.R` utilise
[`compute_general_index()`](https://pobsteta.github.io/nemeton/reference/compute_general_index.md)
au lieu d’un simple [`mean()`](https://rdrr.io/r/base/mean.html).

## Les 15 profils d’acteurs

| Profil                   | Clé                        | Familles prioritaires |
|--------------------------|----------------------------|-----------------------|
| Propriétaire privé       | profil_proprietaire_prive  | P, E, R               |
| Propriétaire public      | profil_proprietaire_public | B, N, S               |
| Gestionnaire ONF         | profil_gestionnaire_onf    | P, B, C, R            |
| Gestionnaire coopérative | profil_gestionnaire_coop   | P, E, L               |
| Gestionnaire expert      | profil_gestionnaire_expert | Toutes                |
| Technicien terrain       | profil_technicien          | C, W, F, B            |
| Naturaliste              | profil_naturaliste         | B, N, W, R            |
| Élu local                | profil_elu_local           | S, L, R               |
| Élu régional             | profil_elu_regional        | P, E, C, S            |
| Chasseur                 | profil_chasseur            | R4, B, N              |
| Industrie bois           | profil_industrie_bois      | P, E                  |
| Bûcheron / ETF           | profil_bucheron            | P, S, F               |
| Chercheur                | profil_chercheur           | Toutes                |
| Citoyen                  | profil_citoyen             | S, L, A               |
| Investisseur             | profil_investisseur        | C, P, E               |

Les profils experts sont définis dans `inst/experts/*.yml` avec des
prompts bilingues FR/EN.

## 6 Bounded Contexts (DDD)

1.  **Inventaire** (contexte_inventaire) : collecte et validation des
    données terrain et satellite
2.  **Analyse systémique** (contexte_analyse) : calcul des 31
    indicateurs, 12 familles, radar, Fibonacci
3.  **Cartographie** (contexte_cartographie) : classification
    d’essences, cartes, LiDAR, satellite
4.  **Aide à la décision** (contexte_aide_decision) : perspectives IA,
    interprétation par profil
5.  **Utilisateurs** (contexte_utilisateurs) : authentification,
    profils, droits, partage
6.  **Interopérabilité** (contexte_interoperabilite) : export IFN,
    GroundForest, QField, OGC

## ADR (Architecture Decision Records)

11 ADR documentés dans
`platform_nemeton/docs/ADR-001-010_Nemeton_i18n.odt` :

| ADR | Décision                                                                                  |
|-----|-------------------------------------------------------------------------------------------|
| 001 | R/Shiny (golem), migration Plumber+Vue.js si \>50 users simultanés                        |
| 002 | GeoPackage (terrain) + PostGIS (plateforme) + S3 (rasters/LiDAR en COPC)                  |
| 003 | OVHcloud (principal) + Scaleway GPU L4 (ponctuel)                                         |
| 004 | Mistral API (souveraineté FR), migration self-hosted possible                             |
| 005 | OAuth2/OIDC via AgentConnect → Keycloak fédéré pour l’Europe                              |
| 006 | EUPL v1.2 (plateforme) + MIT (packages R) + CC-BY 4.0 (données)                           |
| 007 | Pipeline NDP : TreeSatAI (NDP 0) → PureForest (NDP 1) → local (NDP 2+)                    |
| 008 | OGC, ETRS89/EPSG:3035 paneuropéen, INSPIRE, sources par pays                              |
| 009 | 4 packages (nemeton, tree_sat, maestro, nemeton.app)                                      |
| 010 | Docker Compose + GitHub Actions CI/CD, 12-factor app                                      |
| 011 | Nombre d’or : pondération Fibonacci, confiance φ, suite 1-1-2-3-5                         |
| 012 | Extensions PG futures : TimescaleDB (monitoring continu) + pgvector (RAG perspectives IA) |

## Walking Skeleton — Épaississements

Le squelette initial est DÉJÀ DEBOUT (l’app fonctionne de bout en bout).
L’état actuel est entre l’épaississement 2 et 3 :

    ✅ Squelette initial     : CSV/cadastre → indicateurs → radar → perspective IA
    ✅ Épaississement 1      : 12 familles complètes, 31 indicateurs
    ✅ Épaississement 2      : Cartographie (Leaflet, parcelles cadastrales)
    ⬜ Épaississement 3      : Multi-acteurs (5+ profils, perspectives différenciées)
    ⬜ Épaississement 4      : Authentification (OAuth2/OIDC, ADR-005)
    ⬜ Épaississement 5      : Intégrations et NDP (tree_sat, maestro, QField)
    ⬜ Épaississement 6      : Monitoring forestier continu (TimescaleDB + alertes Sentinel-2, ADR-012)
    ⬜ Épaississement 7      : RAG perspectives IA (pgvector + base de connaissances forestière, ADR-012)

## Internationalisation (i18n)

- L’interface utilise `shiny.i18n` via le système `get_i18n(lang)` /
  `i18n$t("clé")`
- Fichiers de traduction : `inst/app/i18n/fr.json` (274+ clés) et
  `en.json`
- Les textes affichés passent TOUJOURS par i18n, jamais en littéral
  français
- Les prompts LLM sont bilingues (inst/experts/\*.yml contiennent FR et
  EN)
- Prévu pour l’extension européenne : DE, ES, IT à ajouter
  ultérieurement

## Stack technique

- **R \>= 4.1.0** avec golem pour la structuration Shiny
- **bslib** (Bootstrap 5) pour le layout
- **leaflet** pour la cartographie
- **plotly** (optionnel) / **fmsb** pour le radar
- **ellmer** pour l’intégration LLM multi-provider (Anthropic, Mistral,
  OpenAI)
- **sf**, **terra** pour les données spatiales
- **shiny.i18n** pour l’internationalisation
- **testthat** (edition 3) + **shinytest2** pour les tests

## Commandes de référence

``` bash
# Lancer l'application
Rscript -e 'nemeton::run_app()'

# Lancer tous les tests
Rscript -e 'devtools::test()'

# Lancer un test spécifique
Rscript -e 'testthat::test_file("tests/testthat/test-ndp.R")'

# Regénérer la documentation
Rscript -e 'devtools::document()'

# Vérifier le package
Rscript -e 'devtools::check()'

# Couverture de code
Rscript -e 'cat(covr::percent_coverage(covr::package_coverage(quiet=TRUE)))'
```

## Conventions de code

### Fonctions R

- Nouvelles fonctions : snake_case NMT (`calculer_famille`,
  `afficher_radar`)
- Fonctions existantes : garder le nom actuel (ne pas renommer
  `create_family_index`)
- Documentation roxygen : en anglais (cohérence avec l’existant)
- Commentaires inline : en français

### Tests

- Framework : testthat edition 3
- Nommage : `test-{module}.R`
- `testServer()` pour les modules Shiny (contribue à covr)
- [`shinytest2::AppDriver`](https://rstudio.github.io/shinytest2/reference/AppDriver.html)
  pour les tests E2E (ne contribue pas à covr)
- `on.exit(app$stop())` obligatoire après chaque AppDriver\$new()

### Données de test

- `data(massif_demo_units)` : 20 unités forestières avec 12 familles
- [`withr::with_tempdir()`](https://withr.r-lib.org/reference/with_tempfile.html)
  pour les fichiers temporaires
- [`testthat::local_mocked_bindings()`](https://testthat.r-lib.org/reference/local_mocked_bindings.html)
  pour mocker les dépendances

## Fichiers clés

    R/ndp.R                   → Système NDP, Fibonacci, confiance φ
    R/family-system.R         → Agrégation des indicateurs en familles
    R/mod_synthesis.R         → Synthèse : score global, radar, AI
    R/mod_home.R              → Sélection cadastrale, carte
    R/mod_family.R            → Vue détaillée par famille
    R/indicators-*.R          → Calcul des 31 indicateurs
    R/service_compute.R       → Calcul asynchrone (ExtendedTask + future)
    R/llm_prompts.R           → Gestion des profils experts et prompts LLM
    R/i18n.R + R/utils_i18n.R → Système d'internationalisation
    R/app_ui.R                → UI principale (page_navbar bslib)
    R/app_server.R            → Server principal
    R/run_app.R               → Point d'entrée de l'application
    inst/experts/*.yml        → Profils experts pour les perspectives IA
    inst/app/i18n/*.json      → Traductions FR/EN

## Règles strictes

1.  Le code métier (indicateurs, familles, NDP) est dans les fichiers R
    du package, JAMAIS dans les modules Shiny
2.  Les modules Shiny (mod\_\*.R) sont de la présentation : ils
    appellent les fonctions du package
3.  Aucune logique métier dans server.R ou ui.R
4.  Les textes passent par i18n\$t(“clé”), jamais en littéral
5.  Chaque nouvelle fonction exportée a un test dans tests/testthat/
6.  Les rasters et le LiDAR ne sont JAMAIS stockés dans PostgreSQL
    (ADR-002)
7.  Le NDP mesure la qualité des données, pas la complétude de l’analyse
