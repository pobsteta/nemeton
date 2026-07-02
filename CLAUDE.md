# CLAUDE.md — Néméton Development Reference

## Identité du projet

Néméton est une plateforme d’analyse forestière systémique développée
par Pascal Obstetar à titre personnel. Elle calcule **31 indicateurs de
base** (33 avec les indicateurs conditionnels R5 dépérissement quand
FORDEAD a tourné — spec 008 — et T3 coupes rases quand SUFOSAT est
fourni — spec 030) organisés en **12 familles**, les affiche sur un
radar, et génère des perspectives IA adaptées à 15 profils d’acteurs de
la filière forêt-bois. Le nom vient du gaulois *nemeton* (sanctuaire en
forêt).

Le package R `nemeton` (v0.15.1.9000) est le **cœur métier** :
indicateurs, familles, NDP, normalisation, visualisation. Depuis v0.15.0
(ADR-009), l’application Shiny/golem a été extraite dans un package
séparé `nemetonshiny` (repo distinct). Ce repo-ci ne contient donc PLUS
de modules Shiny, profils experts ni fichiers i18n — ils vivent dans
`nemetonshiny`.

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

## Architecture (packages, ADR-009)

    nemeton (ce repo)     → Package cœur. 31 indicateurs, 12 familles, NDP, normalisation, viz.
    nemetonshiny          → App Shiny/golem : UI, modules, i18n, profils experts, LLM, OAuth2.
    tree_sat_nemeton      → Classification d'essences par Sentinel-1/2. NDP 0.
    maestro_nemeton       → Classification d'essences par MAESTRO ViT (ortho+MNT). NDP 1+.
    platform_nemeton      → Documentation plateforme, ADR, glossaire.

La licence de chaque repo est portée par son propre fichier `LICENSE`
(la règle de CLAUDE.md n’est pas la source de vérité pour les licences —
chaque package a la sienne, potentiellement différente).

Règle : les dépendances vont toujours vers nemeton (cœur). Jamais
d’inverse. `nemetonshiny` dépend de `nemeton` (120+ fonctions exportées,
commit `720a433`).

## Les 12 familles d’indicateurs

| Code | Famille | Indicateurs |
|----|----|----|
| B | Biodiversité | B1 (protection), B2 (structure), B3 (connectivité) |
| C | Carbone & Vitalité | C1 (biomasse), C2 (NDVI) |
| W | Eau & Régulation | W1 (réseau hydro), W2 (zones humides), W3 (TWI) |
| A | Air & Microclimat | A1 (couverture arborée), A2 (qualité air), A3 (microclimat sous couvert, spec 027), A4 (tamponnement canopée, spec 027), A5 (rafraîchissement urbain, LST-conditionné — spec 032) |
| F | Fertilité des sols | F1 (fertilité), F2 (érosion) |
| L | Paysage | L1 (sylvosphère), L2 (fragmentation) |
| T | Dynamique temporelle | T1 (ancienneté), T2 (changement), T3 (coupes rases, SUFOSAT-conditionné — spec 030) |
| R | Risques & Résilience | R1 (feu), R2 (tempête), R3 (sécheresse), R4 (abroutissement), R5 (dépérissement, FORDEAD-conditionné — spec 008) |
| S | Social & Usages | S1 (routes), S2 (bâti), S3 (population) |
| P | Production & Économie | P1 (volume bois), P2 (station), P3 (qualité bois) |
| E | Énergie & Climat | E1 (bois-énergie), E2 (évitement carbone) |
| N | Naturalité | N1 (distance infra), N2 (continuité), N3 (composite) |

## Système NDP (Niveau De Précision) — ADR-011

Le NDP mesure la QUALITÉ des données d’entrée, PAS le nombre de familles
calculées. Les 12 familles sont toujours calculées, mais avec une
précision croissante.

| NDP | Clé | Nom | Fibonacci | Confiance φ | Sources |
|----|----|----|----|----|----|
| 0 | ndp_decouverte | Découverte | 1 | 8.3% | Sentinel-2, WorldClim, BD TOPO, MNT 25m |
| 1 | ndp_observation | Observation | 1 | 16.7% | \+ IGN RGE ALTI, BD ORTHO, LiDAR HD |
| 2 | ndp_exploration | Exploration | 2 | 33.3% | \+ Drone RGB, LiDAR drone |
| 3 | ndp_diagnostic | Diagnostic | 3 | 58.3% | \+ Inventaire terrain complet |
| 4 | ndp_jumeau | Jumeau | 5 | 100% | \+ Scanner terrestre, modèle 3D |

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
`ndp_progress_bar()` : widgets HTML — **déplacés dans `nemetonshiny`**
(commit 64ba7b1)

Le score global, calculé côté cœur via
[`compute_general_index()`](https://pobsteta.github.io/nemeton/reference/compute_general_index.md),
est consommé par `mod_synthesis.R` dans `nemetonshiny` (au lieu d’un
simple [`mean()`](https://rdrr.io/r/base/mean.html)).

## Les profils d’acteurs (cible : 15, livrés : 13)

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

Les profils experts sont définis dans `nemetonshiny/inst/experts/*.yml`
avec des prompts bilingues FR/EN (E3 livré, commit 1b32943 — 13 profils
sur les 15 listés ci-dessus).

## 7 Bounded Contexts (DDD)

1.  **Inventaire** (contexte_inventaire) : collecte et validation des
    données terrain et satellite
2.  **Analyse systémique** (contexte_analyse) : calcul des 31
    indicateurs, 12 familles, radar, Fibonacci
3.  **Cartographie** (contexte_cartographie) : classification
    d’essences, cartes, LiDAR, satellite
4.  **Santé** (contexte_sante) : pipelines de détection sanitaire —
    rolling-window NDVI/NBR (surveillance rapide) et FORDEAD via
    reticulate (diagnostic), fusion des deux signaux, indicateur R5,
    workflow QField de validation. Voir spec 008 et ADR-013.
5.  **Aide à la décision** (contexte_aide_decision) : perspectives IA,
    interprétation par profil
6.  **Utilisateurs** (contexte_utilisateurs) : authentification,
    profils, droits, partage
7.  **Interopérabilité** (contexte_interoperabilite) : export IFN,
    GroundForest, QField, OGC

## ADR (Architecture Decision Records)

ADR documentés dans `platform_nemeton/docs/` :

| ADR | Décision |
|----|----|
| 001 | R/Shiny (golem), migration Plumber+Vue.js si \>50 users simultanés |
| 002 | GeoPackage (terrain) + PostGIS (plateforme) + S3 (rasters/LiDAR en COPC) |
| 003 | OVHcloud (principal) + Scaleway GPU L4 (ponctuel) |
| 004 | Mistral API (souveraineté FR), migration self-hosted possible |
| 005 | OAuth2/OIDC via AgentConnect → Keycloak fédéré pour l’Europe |
| 006 | EUPL v1.2 (plateforme) + MIT (packages R) + CC-BY 4.0 (données) |
| 007 | Pipeline NDP : TreeSatAI (NDP 0) → PureForest (NDP 1) → local (NDP 2+) |
| 008 | OGC, ETRS89/EPSG:3035 paneuropéen, INSPIRE, sources par pays |
| 009 | 4 packages (nemeton, tree_sat, maestro, nemeton.app) |
| 010 | Docker Compose + GitHub Actions CI/CD, 12-factor app |
| 011 | Nombre d’or : pondération Fibonacci, confiance φ, suite 1-1-2-3-5 |
| 012 | Extensions PG futures : TimescaleDB (monitoring continu) + pgvector (RAG perspectives IA) |
| 013 | **Suivi sanitaire** : FORDEAD via reticulate (CRSWIR + harmonique, GPL-3) en méthode officielle, hybridé avec rolling-window E6.a, 5 garde-fous applicatifs G1-G5 issus du rapport ONF/DSF 2024 |

## Walking Skeleton — Épaississements

Le squelette initial est DÉJÀ DEBOUT (l’app fonctionne de bout en bout)
et s’épaissit par vagues numérotées (E1, E2, …). La séquence des
épaississements et leur état d’avancement courant vivent dans
**`PLAN.md`** à la racine — c’est la *single source of truth*. Cette
section ne reproduit plus la table pour éviter la dérive (cf. *Consignes
de release*, étape 8).

Note : certains épaississements sont implémentés côté `nemetonshiny`
(profils experts, OAuth2, modules UI) et ne sont pas visibles depuis ce
repo. `PLAN.md` indique chaque fois quel package porte la livraison.

## NDP augmenté et intégration Open-Canopy (spec 005, v0.16.0)

Depuis la v0.16.0 (spec 005), `nemeton` consomme des Canopy Height
Models (CHM) produits par le package amont `opencanopy`
(pobsteta/opencanopynemeton). L’intégration suit l’ADR-011 amendé :

- **Flag vectoriel `augmented`** dans le résultat de
  [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md).
  Valeurs reconnues : `"height_ml"` (CHM ML d’Open-Canopy),
  `"species_ml"`, `"texture_ml"`. Le niveau NDP et la confiance φ
  Fibonacci globale restent inchangés : la granularité ML est exploitée
  par
  [`compute_general_index_mixed()`](https://pobsteta.github.io/nemeton/reference/compute_general_index_mixed.md).
- **Pipeline de nettoyage**
  `sanitize_chm(chm, forest_mask, buildings, water, ndvi, slope, max_height, ndvi_threshold)`
  en 5 étapes, retourne `list(chm_clean, pct_masked, steps_applied)`.
- **Extraction H_dom** : `extract_h_dom(chm, units, percentile = 0.9)`.
- **Indice de station** :
  `compute_site_index(H_dom, age, species, reference_age)` via courbes
  Duplat & Tran-Ha 1997 dans `inst/extdata/site_index_curves.csv`
  (autorisation explicite de M. Tran-Ha, avril 2026).
- **Indicateurs compatibles CHM** (argument `chm = NULL` sur chacun) :
  - [`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
    — tarif IFN avec H du CHM.
  - [`indicateur_p2_station()`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md)
    — site index H₀ via courbes Duplat.
  - [`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md)
    — biomasse via V(D, H) × ρ × BEF × C_frac.
  - [`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md)
    — composante CV(CHM) (poids 0.2 par défaut).
  - [`indicateur_r2_tempete()`](https://pobsteta.github.io/nemeton/reference/indicateur_r2_tempete.md)
    — modulation par vulnérabilité f(H, espèce).
- **Source de données** `chm_opencanopy` déclarée dans
  `inst/datasources/FR.json` (format COG, CRS EPSG:2154, licence double
  IGN BD ORTHO + Open-Canopy).

Tous les indicateurs restent strictement rétrocompatibles : quand `chm`
est `NULL`, le comportement v0.15.x est préservé.

## Internationalisation (i18n)

L’i18n vit dans `nemetonshiny` depuis v0.15.0. Pour mémoire :

- L’interface utilise `get_i18n(lang)` / `i18n$t("clé")` (implémentation
  maison, pas `shiny.i18n`)
- Source unique des traductions : liste `TRANSLATIONS` dans
  `nemetonshiny/R/utils_i18n.R` (358+ clés, FR/EN). Une helper
  `export_translations_json()` permet un export JSON ponctuel pour les
  traducteurs.
- Les textes affichés passent TOUJOURS par i18n, jamais en littéral
  français
- Les prompts LLM sont bilingues (`nemetonshiny/inst/experts/*.yml`
  contiennent FR et EN)
- Prévu pour l’extension européenne : DE, ES, IT à ajouter
  ultérieurement

Dans ce repo (cœur), les messages utilisateur éventuels (avertissements
[`cli::cli_warn`](https://cli.r-lib.org/reference/cli_abort.html), etc.)
sont en anglais par cohérence avec la roxygen doc.

## Stack technique

Cœur (ce repo) : - **R \>= 4.1.0** - **sf**, **terra**,
**exactextractr** pour les données spatiales - **ggplot2**, **cluster**,
**tidyr**, **glue**, **cli**, **rlang** - **testthat** (edition 3) pour
les tests

App Shiny (`nemetonshiny`) — pour mémoire : - **golem** pour la
structuration Shiny - **bslib** (Bootstrap 5) pour le layout -
**leaflet** pour la cartographie - **plotly** (optionnel) / **fmsb**
pour le radar - **ellmer** pour l’intégration LLM multi-provider
(Anthropic, Mistral, OpenAI) - **shinyOAuth** pour l’authentification
(ADR-005) - **i18n maison** (`utils_i18n.R`, liste `TRANSLATIONS`
FR/EN) - **shinytest2** pour les tests E2E

## Commandes de référence

``` bash
# Lancer l'application (nécessite le package nemetonshiny installé)
Rscript -e 'nemetonshiny::run_app()'

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
- `shinytest2::AppDriver` pour les tests E2E (ne contribue pas à covr)
- `on.exit(app$stop())` obligatoire après chaque AppDriver\$new()

### DB de test isolée — `NEMETON_DB_URL_TEST` (v0.54.0)

Les tests d’intégration (`tests/testthat/test-monitoring.R`,
`test-read_obs_pixel.R`, `test-project-zone-binding.R`, etc.)
**DROP-CASCADE** les tables monitoring entre chaque cas via
`helper-monitoring.R::with_clean_db()`. Pour éviter l’écrasement d’une
DB de production (incidents villards 2026-05-25 et 2026-05-31), tout
accès DB d’intégration passe par `.guard_test_db()` +
`.test_db_connect()`, qui **exigent** `NEMETON_DB_URL_TEST` :

1.  non défini → tests d’intégration **skip** (pas fail) ;
2.  égal à `NEMETON_DB_URL` → **skip** (copier-coller de la prod) ;
3.  base contenant des tables applicatives
    (`projects`/`users`/`parcels`) → **skip** (c’est la vraie base, pas
    une base jetable — seule couche qui rattrape le cas « TEST pointe
    sur la prod alors que `NEMETON_DB_URL` est vide »).

Override (CI sur base jetable uniquement) :
`NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE`.

Setup local (`.Renviron`, cf. `.Renviron.example`) :

``` bash
NEMETON_DB_URL=postgresql://nemeton@127.0.0.1:5432/nemeton          # prod / app
NEMETON_DB_URL_TEST=postgresql://nemeton@127.0.0.1:5432/nemeton_test # dédiée, jetable
```

Création de la base jetable :

``` bash
createdb -U nemeton -h 127.0.0.1 nemeton_test
psql -U nemeton -h 127.0.0.1 -d nemeton_test \
  -c "CREATE EXTENSION IF NOT EXISTS timescaledb; CREATE EXTENSION IF NOT EXISTS postgis;"
```

Sans `NEMETON_DB_URL_TEST`,
[`devtools::test()`](https://devtools.r-lib.org/reference/test.html)
reste **vert** (les tests d’intégration sont *skipped*, comptés dans la
sortie testthat).

### Données de test

- `data(massif_demo_units)` : 20 unités forestières avec 12 familles
- [`withr::with_tempdir()`](https://withr.r-lib.org/reference/with_tempfile.html)
  pour les fichiers temporaires
- [`testthat::local_mocked_bindings()`](https://testthat.r-lib.org/reference/local_mocked_bindings.html)
  pour mocker les dépendances

## Fichiers clés (cœur, ce repo)

    R/ndp.R                       → Système NDP, Fibonacci, confiance φ, flag `augmented`
    R/utils-chm.R                 → sanitize_chm(), extract_h_dom() (spec 005)
    R/site_index.R                → compute_site_index() + courbes Duplat & Tran-Ha (spec 005)
    R/family-system.R             → Agrégation des indicateurs en familles
    R/indicators-*.R              → Calcul des 31 indicateurs (air, biodiversity, energy,
                                     naturalness, productive, risk, social, temporal, core, families)
    R/normalization.R             → Normalisation des indicateurs en indices [0..1]
    R/indicator-config.R          → Configuration des indicateurs (sens, bornes, unité)
    R/analysis-*.R                → Clustering, corrélation, Pareto, trade-off
    R/datasources.R               → Déclaration des sources de données par NDP
    R/species-config.R            → Configuration des essences (maestro, tree_sat)
    R/temporal.R                  → Analyse temporelle (T1, T2)
    R/visualization.R             → Helpers de visualisation (radar, etc.)
    R/data-massif_demo.R + data/  → Fixture massif_demo_units (20 unités, 29 indicateurs)
    R/i18n.R                      → Squelette i18n côté cœur (messages R uniquement)
    inst/tutorials/               → Tutoriels pédagogiques (acquisition, LiDAR, ABA, etc.)
    inst/extdata/aba.model/       → Modèle ABA (Area-Based Approach) + données LiDAR d'exemple
    inst/extdata/site_index_curves.csv → Courbes de hauteur dominante par essence/classe (spec 005)
    inst/datasources/             → Définitions des sources de données (NDP)

## Fichiers clés (app, repo `nemetonshiny`)

    R/mod_synthesis.R             → Synthèse : score global, radar, AI
    R/mod_home.R                  → Sélection cadastrale, carte
    R/mod_family.R                → Vue détaillée par famille
    R/service_compute.R           → Calcul asynchrone (ExtendedTask + future)
    R/llm_prompts.R               → Gestion des profils experts et prompts LLM
    R/mod_auth.R (ou équiv.)      → OAuth2/OIDC via shinyOAuth (E4)
    R/app_ui.R / R/app_server.R   → UI + server principaux
    R/run_app.R                   → Point d'entrée de l'application
    inst/experts/*.yml            → 13 profils experts pour les perspectives IA (E3)
    R/utils_i18n.R                → Traductions FR/EN (liste TRANSLATIONS, source unique)

# Consignes de release pour ce projet

**Le tag et la release GitHub sont AUTOMATISÉS** par
`.github/workflows/release.yml` : au push sur `main`, il lit `Version:`
dans DESCRIPTION et, si c’est une version **stable `X.Y.Z`** dont le tag
`vX.Y.Z` n’existe pas encore, crée le tag annoté + la release GitHub
(`--generate-notes`). **Ne plus faire `git tag` /
`git push origin vX.Y.Z` / `gh release create` à la main.**

À chaque push qui modifie le code fonctionnel (hors doc pure, hors CI),
Claude doit :

1.  Déterminer le type de changement selon Conventional Commits (feat: /
    fix: / BREAKING CHANGE:) → bump semver correspondant (minor / patch
    / major).

2.  Mettre à jour la version, de façon **cohérente** dans les trois
    fichiers (le job CI `version-consistency` de `r.yml` échoue sinon) :

    - DESCRIPTION (champ Version) → la version stable `X.Y.Z` de la
      release
    - NEWS.md (entrée datée `# nemeton X.Y.Z (YYYY-MM-DD)`)
    - CITATION.cff (`version:` + `date-released:`)

3.  Si CHANGELOG.md existe, ajouter la section `[X.Y.Z] - YYYY-MM-DD`
    (Added / Changed / Fixed / Removed).

4.  Mettre à jour `PLAN.md` (journal daté ; table d’avancement si l’état
    change). Source unique de vérité du walking skeleton. Ne jamais
    clore un chantier sans release correspondante.

5.  Ouvrir une PR vers `main` et la merger → `release.yml` pose le tag +
    la release. **Rien d’autre à faire** : le badge version du README
    est dynamique (`img.shields.io/github/v/release`) et se met à jour
    seul.

6.  **Repasser en cycle dev** : juste après la release, bumper
    DESCRIPTION en version de dev `X.Y.Z.9000` (cf. *Cycle de
    développement* ci-dessous).

## Cycle de développement (versions `.9000`)

Entre deux releases, `DESCRIPTION` porte une version de **dév**
`X.Y.Z.9000` (4 composantes). Convention :

- **État publié sur `main`** : DESCRIPTION = `X.Y.Z` stable, tag
  `vX.Y.Z` posé par le CI.
- **Démarrage du cycle dev** : bumper DESCRIPTION → `X.Y.Z.9000`.
  NEWS.md et CITATION.cff **restent** sur `X.Y.Z` (la dernière release).
- **Pendant le dev** : DESCRIPTION reste `X.Y.Z.9000`.
- **Release suivante** : poser une version stable `X.Y.(Z+1)` (ou
  `X.(Y+1).0`, etc.) dans DESCRIPTION **et** NEWS **et** CITATION,
  merger.

`release.yml` **ignore** les versions `.9000+` (gate « stable only »),
et le garde-fou `version-consistency` **saute** quand DESCRIPTION est en
cycle dev (il ne compare DESCRIPTION = NEWS = CITATION que pour une
version stable `X.Y.Z`). Un push de cycle dev ne déclenche donc ni
release ni échec CI.

## Règles de cohérence

- Pour une version **stable**, DESCRIPTION = tête de NEWS.md =
  CITATION.cff (vérifié en CI par `version-consistency`). Le tag et la
  release sont ensuite posés automatiquement et donc identiques par
  construction.
- Vérifier que la page de documentation (pkgdown) est à jour — elle rend
  le README (badge dynamique) et lit la version de DESCRIPTION.
- Toujours demander confirmation avant un bump majeur.

## Règles strictes

1.  Le code métier (indicateurs, familles, NDP) reste dans le package
    `nemeton` (ce repo), JAMAIS dans `nemetonshiny`
2.  `nemetonshiny` est de la présentation : il appelle les fonctions
    exportées par `nemeton`
3.  Aucune logique métier dans `server.R` / `ui.R` / `mod_*.R` de
    `nemetonshiny`
4.  Dans `nemetonshiny`, les textes UI passent par `i18n$t("clé")`,
    jamais en littéral
5.  Chaque nouvelle fonction exportée (côté cœur) a un test dans
    `tests/testthat/`
6.  Les rasters et le LiDAR ne sont JAMAIS stockés dans PostgreSQL
    (ADR-002)
7.  Le NDP mesure la qualité des données, pas la complétude de l’analyse
8.  Pas de dépendance inverse : `nemeton` n’importe JAMAIS
    `nemetonshiny`
9.  Quand je travaille sur une tâche longue, maintiens un fichier
    PLAN.md à la racine avec l’état actuel, les décisions prises, et la
    prochaine étape
10. Mets-le à jour à chaque étape terminée
11. **Ne JAMAIS modifier le répertoire de travail de `nemetonshiny`**
    (ni d’aucun repo frère : `tree_sat_nemeton`, `maestro_nemeton`,
    `platform_nemeton`, etc.) depuis une session `nemeton`. Interdits :
    `git checkout` / `commit` / `branch` / `stash` / `push`, création de
    branches, édition de fichiers dans `../nemetonshiny`. Pascal gère
    `nemetonshiny` depuis ses propres sessions dédiées. La **lecture
    seule** (inspecter le code de l’app pour écrire un brief juste) est
    permise ; toute opération git **mutante** y risque d’écraser le WIP
    d’une session parallèle (incident 2026-07-02 : un `git checkout` de
    cette session a déplacé le WIP T3 entre branches, puis commité
    par-dessus du travail édité en direct). **Livrer côté app = fournir
    un brief** dans `specs/<NNN>-*/brief-nemetonshiny.md` (côté cœur),
    jamais éditer l’app.
