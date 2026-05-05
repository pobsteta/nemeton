# PLAN — Walking Skeleton & chantier en cours

**Source unique de vérité** pour la séquence des épaississements (E1, E2, …) et leur état d'avancement. CLAUDE.md ne duplique plus cette table (règle introduite le 2026-04-25). À chaque release, mettre à jour la table ci-dessous + le journal du chantier en cours (cf. *Consignes de release* étape 8 dans CLAUDE.md).

## Avancement Walking Skeleton

| État | Vague | Description | Livré dans |
|------|-------|-------------|------------|
| ✅ | Squelette initial | CSV/cadastre → indicateurs → radar → perspective IA | — |
| ✅ | E1 | 12 familles complètes, 31 indicateurs | `nemeton` |
| ✅ | E2 | Cartographie (Leaflet, parcelles cadastrales) | `nemetonshiny` |
| ✅ | E3 | Multi-acteurs — 13 profils experts YAML | `nemetonshiny` (commit `1b32943`) |
| ✅ | E4 | Authentification OAuth2/OIDC via shinyOAuth | `nemetonshiny` (commit `3e07c60`) |
| ✅ | E5 | Intégrations & NDP — Open-Canopy CHM (spec 005) + QField export/ingest + sizing échantillon + flag `height_lidar` | `nemeton` v0.16.0 → v0.19.12 + `nemetonshiny` (clôture `0a1eb63` le 2026-04-24) |
| 🟨 | **E6** | **Suivi sanitaire** — surveillance rapide (NDVI/NBR rolling-window) **+ diagnostic FORDEAD** (CRSWIR + harmonique). Spec 008, ADR-013. Indicateur **R5 dépérissement**. | E6.a livré v0.20.0 + hardening v0.20.1 ; **E6.b phase 1 livré** (`nemetonshiny@2909b8f`) ; **E6.c.1/.2/.3/.4 + E6.d livrés** (cœur — chantier cœur de v0.21.0 complet) ; reste E6.b phases 2-6, E6.c.5 (mode sanitaire UI), E6.f (smoke + release v0.21.0) |
| ⬜ | E7 | RAG perspectives IA (pgvector + base de connaissances forestière, ADR-012) | non démarré |

Légende : ✅ livré · 🟨 en cours · ⬜ à venir.

---

# Chantier en cours — Épaississement 6 : Suivi sanitaire

**Démarré**     : 2026-04-24 (initialement « monitoring continu »)
**Reframing**   : 2026-04-26 — chantier reciblé en **« suivi sanitaire »** après lecture du rapport ONF/DSF (Bernard & Doridant 2024). Spec 008 + ADR-013 rédigés. Voir `specs/008-suivi-sanitaire/`.
**Cible release** : `nemeton` v0.21.0 + `nemetonshiny` v0.21.0
**Branche actuelle** : `nemeton@main = 29491d8` (cycle dev `0.20.1.9000`), `nemetonshiny@main = 2909b8f` (cycle dev `0.21.0.9000`)

## Stratégie hybride (validée 2026-04-26)

Deux pipelines complémentaires alimentent la même table `alert` :

| Pipeline | Méthode | Question répondue | Coût | Cas d'usage |
|----------|---------|-------------------|------|-------------|
| **Surveillance rapide** | rolling-window NDVI/NBR (E6.a, déjà livré) | « Choc récent ? » | secondes | coupes, chablis, incendies |
| **Diagnostic sanitaire** | FORDEAD via reticulate (CRSWIR + harmonique, GPL-3) | « Mes peuplements dépérissent-ils ? » | minutes-heures | scolyte / sécheresse / dépérissement progressif |
| **Fusion** | join SQL (window ±30 j) | « Dépérissement ou perturbation mécanique ? » | ms | discrimination des causes |

## Garde-fous applicatifs (issus du rapport ONF/DSF 2024)

- **G1** — filtrage par défaut classes 3-forte + 4-sol-nu (les classes 1-2 ont 50% / 1/3 de faux positifs)
- **G2** — fusion rolling-window × FORDEAD pour distinguer dépérissement / perturbation mécanique
- **G3** — bannières UI géographique (`fordead_validity_zones.geojson` : 88, 39, 01, 73, 74) et essences (≥70% épicéa+sapin)
- **G4** — workflow QField de validation terrain (réutilise E5.b, schéma DSF-aligné)
- **G5** — indicateur R5 pondéré par les taux de bonne détection observés terrain (`FORDEAD_CONFIDENCE_WEIGHTS` = 0.10 / 0.30 / 0.82 / 0.70)

## Découpage actualisé

### E6.a — Squelette TimescaleDB + ingestion S2 + rolling-window — **livré v0.20.0 / v0.20.1**

Voir spec 007 (devient la couche « Surveillance rapide » de spec 008).

- [x] Phase 1-5 livrées dans le commit `28570d4` (release v0.20.0 du 2026-04-25)
- [x] Hardening v0.20.1 (commit `a7ea8d3`) : 2 bugs DB corrigés via tests d'intégration

### E6.b — UI `mod_monitoring` (côté `nemetonshiny`) — **phase 1 livré, phases 2-6 à faire**

Cible : `nemetonshiny` v0.21.0.

- [x] **Phase 1 — Scaffolding + DB adapter + zones reactive** (commit `2909b8f`, 2026-04-25)
- [ ] Phase 2 — Ingestion async (ExtendedTask + future_promise) + toasts
- [ ] Phase 3 — Time series plotly NDVI/NBR
- [ ] Phase 4 — Carte leaflet alertes (POINT, popup, validation buttons)
- [ ] Phase 5 — Persistance config (seuils, mode, validity flags) dans `metadata.json`
- [ ] Phase 6 — Smoke shinytest2 + finitions UX

### E6.c — Pipeline FORDEAD (côté cœur `nemeton`) — **en cours**

Spec 008 §3, plan.md §2, tasks.md chantiers E6.c.1 à E6.c.5.

- [x] **E6.c.1** — `R/fordead_python.R` (helpers reticulate) + `R/fordead_pipeline.R` (orchestrateur `run_fordead_dieback`) + `inst/python/requirements.txt` + tests mockés (`test-fordead-python.R` 8 tests, `test-fordead-pipeline.R` 12 tests, 44 PASS) — branche `feat/008-fordead-pipeline` (2026-04-29)
- [x] **E6.c.2** — `R/fordead_postprocess.R` (constants + raster→POINT clusters via `terra::patches`, snap-to-plot INSERT, `classify_disturbance()` G2, `list_alerts()` G1) + migration `0002_fordead.sql` + branchement de `run_fordead_dieback` — branche `feat/008-fordead-postprocess` (2026-04-29). 45 nouveaux tests offline, 5 d'intégration TimescaleDB. Suite : 5745 PASS.
- [x] **E6.c.3** — `R/fordead_validity.R` (`load_fordead_validity_zones`, `check_fordead_validity`, constantes `FORDEAD_VALIDITY_DEPARTMENTS`/`FORDEAD_VALIDITY_SPECIES`) + `inst/extdata/fordead_validity_zones.geojson` (5 départements 88/39/01/73/74, ~27 500 km², 80 ko, simplifié 100 m, EPSG:4326) + script reproductible `data-raw/build_fordead_validity_zones.R` (source : `gregoiredavid/france-geojson` car `geo.api.gouv.fr/format=geojson` retourne désormais des attributs sans contour). 16 tests offline (zones + validity, helpers `.is_epicea` / `.is_sapin_pectine` corrects sur la collision Picea abies / Abies alba / Pseudotsuga). Suite : **5866 PASS / 0 FAIL**.
- [x] **E6.c.4** — `R/health_validation.R` : `get_health_validation_schema()` (11 `.field()` DSF-aligned, ValueMap stades + causes, fallback `essence_dominante`), `generate_health_validation_plots()` (stratifié `confidence_class`, GRTS via `spsurvey` ou repli random, `.allocate_health_strata()` largest-remainder, NA typés pour les colonnes éditables, sortie `sf` POINT EPSG:2154 prête pour `create_qfield_project()`), `ingest_health_validation()` (snap par plus-proche-voisin Lambert-93, mapping `stade → (validation_status, validation_cause)` avec règle `coupe_rase × confidence_class` du rapport ONF/DSF, précédence `validated_by`, écrasement par `cause` libre, `details` data.frame avec `reason ∈ {ok, no_alert_within_snap, missing_stade}`). Constantes exportées `HEALTH_VALIDATION_STADES` (7 codes DSF), `HEALTH_VALIDATION_CAUSES` (7 causes). 31 tests : 10 schema, 11 generate (offline + mock du fallback GRTS via `local_mocked_bindings(requireNamespace)`), 10 ingest (intégration TimescaleDB via `with_clean_db`). Suite : **5957 PASS / 0 FAIL**.
- [ ] **E6.c.5** — Mode sanitaire dans `mod_monitoring` (côté app) : toggle, bannières G3, génération QField, sous-onglet validation dans `mod_field_ingest`

### E6.d — Indicateur R5 dépérissement (côté cœur `nemeton`) — **livré 2026-04-30**

Spec 008 §7.

- [x] `R/indicators-deperissement.R` : `indicateur_r5_deperissement(units, fordead_results, weights, min_resineux, include_low_classes, resineux_col)`. Sortie : colonnes `R5` (0-100) et `r5_status` (`calculated / skipped_no_resineux / skipped_no_fordead`).
- [x] Intégration radar : `INDICATOR_FAMILIES$R` étendu à 5 indicateurs (`R1..R5`) — `create_family_index()` détecte R5 via la regex `^R[0-9]` existante.
- [x] 18 tests : cas vide, mono-classe (50% × 3-forte → R5 = 41), multi-classes, Quercus skipped, G1 (exclusion 1-faible/2-moyenne par défaut), `include_low_classes = TRUE`, plafonnement, clusters hors UGF, `resineux_col` custom, `min_resineux`, `weights` custom, sf vide, erreurs typées, intégration radar.

### E6.f — Release v0.21.0 — **à faire**

- [ ] Smoke shinytest2 E2E
- [ ] NEWS, DESCRIPTION, CITATION cœur + app à jour
- [ ] Tag `v0.21.0`, GitHub release, bump cycles dev

### E7 — RAG perspectives IA — **non démarré**

Spec à rédiger (`specs/009-rag-perspectives-ia/`). pgvector + base de connaissances forestière (ADR-012). Probablement v0.22.0+.

---

## Documents de référence du chantier

- `specs/008-suivi-sanitaire/spec.md` — Spec fonctionnelle (vision, scope, garde-fous, R5, validation)
- `specs/008-suivi-sanitaire/plan.md` — Plan technique (stack, pipeline, fusion, performance, risques)
- `specs/008-suivi-sanitaire/tasks.md` — 71 tâches détaillées (53 cœur + 18 app)
- `specs/008-suivi-sanitaire/ADR-013-suivi-sanitaire-fordead.md` — ADR draft (à porter dans `platform_nemeton/docs/`)
- Spec 007 (`specs/007-monitoring-continu/`) — devient la couche « Surveillance rapide » de spec 008, conservée en référence
- Rapport ONF/DSF Bernard & Doridant 2024 — référence de calibration et de limites

---

## Décisions validées 2026-04-26 (fordead)

1. **Reframing** E6 « monitoring continu » → « **suivi sanitaire** »
2. **Stratégie hybride** : rolling-window (rapide) + FORDEAD (diagnostic) ; pas de throwaway de v0.20.0
3. **Cinq garde-fous** G1-G5 obligatoires (filtrage classes / fusion / bannières / validation QField / R5 pondéré)
4. **Workflow validation QField** intégré dans le même chantier E6.c (pas de release séparée)
5. **Zones de validité géographique** construites depuis IGN ADMIN-EXPRESS via geo.api.gouv.fr (5 départements : 88 Vosges, 39 Jura, 01 Ain, 73 Savoie, 74 Haute-Savoie)
6. **Calibration figée** v0.21.0 sur les paramètres ONF/DSF (CRSWIR, 0.16, 2 ans entraînement, 3 anomalies consécutives) — pas exposée à l'utilisateur final
7. **Paperwork avant code** : spec 008 + ADR-013 publiés avant E6.c

## Décisions validées E6.a (2026-04-24)

1. STAC : **CDSE prioritaire + PC fallback**
2. Bandes rapides : **NDVI + NBR** (B04, B08, B12)
3. Déploiement : **docker-compose service TimescaleDB**
4. Déclenchement : **à la demande** (pas de cron en E6.a / E6.c — reporté E6.f)
5. Granularité rapide : **par placette** (buffer 15 m)

---

## Journal

- **2026-05-05** — Stack DB enrichie : `docker-compose.yml` bascule sur `timescale/timescaledb-ha:pg16` (Debian, embarque PostGIS 3 + pgvector — anticipe ADR-012/E7) et `inst/db/migrations/0001_init.sql` active désormais `postgis` à côté de `timescaledb` dès l'initialisation. Le PGDATA de l'image `-ha` étant à `/home/postgres/pgdata` (vs `/var/lib/postgresql/data` sur l'image Alpine de base), le volume `nemeton_pg_data` doit être recréé : `docker compose down && docker volume rm nemeton_pg_data && docker compose up -d timescaledb`. Aucune colonne du schéma n'est encore typée `geometry` — les colonnes `*_wkt TEXT` restent en place et le travail spatial se fait côté R/sf. La migration vers `geometry(Point, 2154)` + index GiST pourra se faire dans une migration ultérieure quand le volume justifie de pousser le snap-to-plot et les filtres `ST_DWithin` côté SQL.
- **2026-04-24** — E6 démarré. Spec 007 rédigée (spec.md, plan.md, tasks.md). Décisions 1-5 tranchées. Démarrage Phase 1.
- **2026-04-25** — E6.a phases 1 à 5 livrées dans le commit `28570d4`. Release **v0.20.0** publiée (NEWS.md, tag, GitHub release). Cycle dev `0.20.0.9000` ouvert (`8df05a8`). Working tree propre. Prochain chantier : E6.b (UI `mod_monitoring` côté `nemetonshiny`).
- **2026-04-25** — E6.a hardening : ajout de `tests/testthat/test-monitoring.R` (12 test_that, 49 assertions, dont 9 d'intégration sur TimescaleDB éphémère). Les integration tests ont surfacé **deux vrais bugs** dans le code v0.20.0 : (1) `db_migrate()` plantait sur la migration multi-statements (RPostgres prepared statement vs PostgreSQL multi-commands) → fix `immediate = TRUE` dans `R/db.R` ; (2) `.insert_obs_pixel()` créait une `TEMP TABLE ON COMMIT DROP` hors transaction → table dropée immédiatement → fix : `CREATE TEMP TABLE` dans la même `dbWithTransaction` que les inserts. Aucun de ces bugs n'avait été détecté parce que la couverture intégration sur la DB était à zéro. Release **v0.20.1** publiée. Suite complète : 5760 PASS / 0 FAIL.
- **2026-04-25** — E5.b follow-up livré côté `nemetonshiny` (`c05962e`) : `.apply_field_data_if_present()` dans `service_compute.R` re-applique le GPKG terrain au compute time pour que les indicateurs P1/P2/B2/C1/R2 voient bien les mesures terrain entre deux runs.
- **2026-04-25** — E6.b phase 1 livrée côté `nemetonshiny` (`2909b8f`) : `mod_monitoring` scaffold + `service_monitoring_db.R` (adapter env-var → URL pour `nemeton::db_connect`) + zones reactive + status card + 19 i18n keys + navbar tab. 822 insertions, 5316 PASS / 0 FAIL.
- **2026-04-30** — **E6.d livré** (cœur). Indicateur R5 (dépérissement FORDEAD) implémenté dans `R/indicators-deperissement.R`. Public : `indicateur_r5_deperissement(units, fordead_results = NULL, weights = FORDEAD_CONFIDENCE_WEIGHTS, min_resineux = 0.3, include_low_classes = FALSE, resineux_col = NULL)`. Sortie : sf augmenté de `R5` (numeric 0-100, NA si skip) et `r5_status` (character ∈ `{calculated, skipped_no_resineux, skipped_no_fordead}`). Logique : pour chaque UGF, calcul de la fraction résineux (binaire 0/1 dérivée du dominant species via `.is_epicea` / `.is_sapin_pectine`, ou colonne explicite `resineux_col` clampée [0,1]). Si `fraction < min_resineux` → R5=NA / skipped_no_resineux ; si pas de FORDEAD results ou alerts vide → R5=NA / skipped_no_fordead. Sinon : intersection POINT-in-polygon entre les centroïdes de clusters et l'UGF, somme pondérée `weights[class] × area_m2 / surface_UGF` (Lambert-93), plafonnée à 1, rescalée en 0-100 pour cohérence radar. Garde-fou G1 par défaut : seules les classes `3-forte` et `4-sol-nu` sont incluses (les classes 1-faible / 2-moyenne ont 50%/33% de faux positifs selon le rapport ONF/DSF 2024). `include_low_classes = TRUE` les rajoute si l'utilisateur l'active explicitement. Pondérations issues de `FORDEAD_CONFIDENCE_WEIGHTS` (0.10 / 0.30 / 0.82 / 0.70 calibrées sur le rapport ONF/DSF). Intégration radar : `INDICATOR_FAMILIES$R` étendu de 4 à 5 indicateurs (`R1..R5`) avec labels et tooltips FR/EN ; aucune modif requise dans `R/family-system.R::create_family_index()` car la regex `^R[0-9]` détecte automatiquement `R5`. Vérifié : `famille_risque` reste finie quand R5 est NA (R1..R4 prennent le relais). 18 nouveaux tests offline (`test-indicators-deperissement.R`) : cas vide, mono-classe 50% × 3-forte → 41, multi-classes additif, Quercus → skipped, G1 (exclusion 1-faible/2-moyenne), `include_low_classes`, plafonnement à 100, clusters hors UGF, `resineux_col` custom (override + clamp), `min_resineux` honoré, `weights` custom, sf vide, erreurs typées, intégration `create_family_index`. **Le chantier cœur de la release v0.21.0 est désormais complet** (E6.c.1/.2/.3/.4 + E6.d). Reste l'app (E6.b phases 2-6, E6.c.5) et le smoke E2E (E6.f) pour boucler v0.21.0. Suite : **5988 PASS / 0 FAIL** (vs 5957). Cycle dev `0.20.1.9003` → `0.20.1.9004`.
- **2026-04-30** — **E6.c.4 livré** (cœur). Module `R/health_validation.R` (~430 lignes) qui implémente le garde-fou G4 de la spec 008. Trois fonctions exportées + deux constantes. (1) `get_health_validation_schema(region, lang)` : 11 descripteurs `.field()` DSF-aligned, vocabulaire `HEALTH_VALIDATION_STADES` (7 codes : sain, sain_scolyte_vert_indif, scolyte_vert/rouge/gris, scolyte_rouge_gris_indif, coupe_rase) et `HEALTH_VALIDATION_CAUSES` (7 causes : scolyte / sécheresse / casse_cime / coupe / chablis / phenologie / autre). Réutilise le constructeur `.field()` de `R/field_schema.R` et le mapping species de `list_species_classes()` (avec fallback texte si la config régionale est absente). (2) `generate_health_validation_plots(alerts_sf, n, method, crs)` : tirage stratifié par `confidence_class`, GRTS via `spsurvey::grts()` quand le package est disponible (repli silencieux sur tirage aléatoire intra-strate sinon, taggé dans `sampling_method`), helper `.allocate_health_strata()` qui distribue le budget `n` à la largest-remainder method en respectant la capacité par strate et garantit ≥1 placette par classe présente. Sortie sf POINT EPSG:2154 prête à passer dans `create_qfield_project()`. (3) `ingest_health_validation(con, gpkg_path, zone_id, snap_distance_m, validated_by, layer)` : lecture du GPKG, snap par plus-proche-voisin en Lambert-93 (par défaut 50 m, `reason = "no_alert_within_snap"` au-delà), mapping `stade_deperissement → (validation_status, validation_cause)` via le helper privé `.health_stade_to_status()` qui matérialise la règle ONF/DSF du rapport 2024 sur `coupe_rase × confidence_class` (1-faible / 2-moyenne → false_positive ; 3-forte / 4-sol-nu → confirmed). UPDATE atomique par alerte. Précédence `validated_by` : argument > champ `obs_by` du GPKG > `Sys.info()`. La cause libre saisie sur le terrain écrase la cause auto-mappée. Retour `list(n_updated, n_confirmed, n_false_positive, n_unmatched, n_skipped, details)` avec `details` un data.frame qui trace chaque placette (ok / no_alert_within_snap / missing_stade). Trois nouveaux test files : `test-health-validation-schema.R` (10 tests offline), `test-generate-health-validation-plots.R` (11 tests offline + mock `local_mocked_bindings(requireNamespace)` du fallback GRTS), `test-ingest-health-validation.R` (10 tests d'intégration TimescaleDB via `with_clean_db`, exécutés grâce à `NEMETON_DB_URL_TEST`). Suite : **5957 PASS / 0 FAIL** (vs 5866). Cycle dev `0.20.1.9002` → `0.20.1.9003`.
- **2026-04-30** — **E6.c.3 livré** (cœur). Trois livrables : (1) `data-raw/build_fordead_validity_zones.R` — script reproductible qui fetch les contours départementaux des 5 départements de la calibration FORDEAD (88, 39, 01, 73, 74) depuis le mirror static `gregoiredavid/france-geojson` (snapshot IGN ADMIN-EXPRESS, Etalab 2.0). Pivot par rapport au plan initial : `geo.api.gouv.fr/format=geojson&geometry=contour` ne renvoie plus le contour depuis 2025 (uniquement les attributs `nom`/`code`/`codeRegion`), donc on s'appuie sur le mirror GitHub stable. Simplification 100 m en Lambert-93 puis reprojection EPSG:4326. (2) `inst/extdata/fordead_validity_zones.geojson` — 5 features MULTIPOLYGON, ~27 500 km², 80 ko, attributs `code_dept / nom_dept / source / reference`. (3) `R/fordead_validity.R` — constantes exportées `FORDEAD_VALIDITY_DEPARTMENTS` et `FORDEAD_VALIDITY_SPECIES`, `load_fordead_validity_zones()` (cache de session), `check_fordead_validity(aoi, units, threshold_geo, threshold_species, min_resineux)` qui retourne un dict `geo_valid / geo_intersection_pct / geo_dept_codes / species_valid / species_resineux_pct / species_epc_pct / species_sap_pct / overall_valid / thresholds`. Helpers privés `.is_epicea()` et `.is_sapin_pectine()` qui résolvent proprement la collision `Picea abies` (épicéa) vs `Abies alba` (sapin pectiné) — l'épithète latin "abies" se trouve dans les deux espèces et il a fallu cabler une exclusion explicite. Le sapin de Douglas (Pseudotsuga menziesii) est aussi exclu côté SAP, conformément à la calibration ONF/DSF. 16 tests offline (`test-fordead-validity-zones.R` 4, `test-fordead-validity.R` 12). Suite : **5866 PASS / 0 FAIL** (vs 5815). Cycle dev `0.20.1.9001` → `0.20.1.9002`.
- **2026-04-30** — Hardening DB intégration : activation de `NEMETON_DB_URL_TEST` dans `.Renviron` (gitignore) → 19 tests TimescaleDB précédemment skippés se rejouent désormais à chaque `devtools::test()`. Trois échecs réels surfacés sur `list_alerts()` (`Parameter 2 does not have length 1` côté RPostgres) parce que le helper interne `add_param()` poussait des vecteurs R bruts au binding alors que RPostgres exige des paramètres scalaires. Fix `ee045f0` : nouveau helper privé `.pg_text_array()` qui sérialise un vecteur R en littéral `text[]` Postgres, et placeholder `$n::text[]` dans `WHERE x = ANY(...)`. Suite globale **5815 PASS / 0 FAIL** (vs 5745 avant — +70 PASS issus des intégrations). Cycle dev `0.20.1.9000` → `0.20.1.9001`.
- **2026-04-29** — **E6.c.2 livré** sur la branche `feat/008-fordead-postprocess` (basée sur `feat/008-fordead-pipeline`, pas mergée vers `main`, pas de release — cible E6.f). Trois grosses livraisons côté cœur. (1) Migration SQL `inst/db/migrations/0002_fordead.sql` : ajoute six colonnes au `alert` (`confidence_class`, `stress_index`, `validation_status DEFAULT 'pending'`, `validation_cause`, `validated_by`, `validated_at`) et deux index (`alert_validation_status_idx`, `alert_plot_date_type_idx`) en pleine idempotence. (2) Nouveau module `R/fordead_postprocess.R` : pipeline complet raster → centroïdes en 3 helpers (`.classify_pixels_to_classes` → `.cluster_anomaly_pixels` via `terra::patches` 8-neighbour avec `min_pixels = 5` → `.cluster_to_centroids`), enrichissement `confidence_class / stress_index / trigger_date / n_pixels / area_m2 / cluster_id`, INSERT bulk via `.insert_fordead_alerts` (TEMP staging + ON CONFLICT DO NOTHING, snap au plot le plus proche dans 200 m). (3) Garde-fous G1 et G2 implémentés et exportés : `list_alerts()` (filtre par défaut `c("3-forte", "4-sol-nu")` + filtres `validation_status` / `period` optionnels) et `classify_disturbance()` (cross-référence FORDEAD × rolling-window dans une fenêtre `± window_days`, retourne `mechanical / progressive / recent_event / NA`). Constantes exportées : `FORDEAD_CLASSES` et `FORDEAD_CONFIDENCE_WEIGHTS = c(0.10, 0.30, 0.82, 0.70)` calibrés sur le rapport ONF/DSF 2024. `run_fordead_dieback()` est maintenant câblé : `alerts_sf` est rempli avec les centroïdes ; `n_alerts_inserted` reflète l'INSERT réel quand `con` et `zone_id` sont fournis. Trois nouveaux tests d'intégration TimescaleDB skippés en l'absence de DB. Suite globale : **5745 PASS / 0 FAIL** (vs 5700 avant E6.c.2). Cycle dev `0.20.1.9000` inchangé.
- **2026-04-29** — **E6.c.1 livré** sur la branche `feat/008-fordead-pipeline` (pas encore mergée vers `main`, pas de release — cible E6.f). Trois nouveaux fichiers côté cœur : `R/fordead_python.R` (helpers reticulate idempotents : `.ensure_fordead_python`, `.use_fordead_env`, `.assert_fordead_system` avec garde Python ≥ 3.10, cache de session), `R/fordead_pipeline.R` (orchestrateur `run_fordead_dieback()` exporté, 5 phases FORDEAD via reticulate, validation arguments AOI/EPSG:2154/dates/threshold/VI, retour structuré, tryCatch global, calibration figée CRSWIR + 0.16 conformément à ADR-013), et `inst/python/requirements.txt` (versions pinnées : fordead 2.1.4, xarray, dask, rasterio, eodag, etc.). Suite de tests mockés : 8 tests reticulate (`test-fordead-python.R`) + 12 tests d'orchestration (`test-fordead-pipeline.R`) — 44 PASS, tous offline. Suite globale : **5700 PASS / 0 FAIL**. Dépendance `reticulate (>= 1.34.0)` ajoutée en `Suggests` (chargée à la 1ère utilisation seulement). Le helper `.download_or_use_cached_bd_foret()` est laissé en stub jusqu'à E6.c.3, et le post-process raster→clusters→DB attend E6.c.2. Cycle dev `0.20.1.9000` inchangé.
- **2026-04-26** — **Reframing du chantier E6** après lecture du rapport ONF/DSF *« Méthode FORDEAD — analyse de la validité des détections d'anomalies de végétation par contrôle terrain »* (Bernard & Doridant, mai 2024, 397 relevés sur Vosges/Jura/Alpes/Massif Central). Findings durs intégrés : faux positifs 50% / 1/3 sur classes 1-faible / 2-moyenne, détection précoce médiocre (60% des stades précoces ratés), confusion dépérissement / perturbation mécanique (25-41% selon altération). Décision : adopter FORDEAD comme méthode officielle de **suivi sanitaire** avec 5 garde-fous applicatifs (G1-G5) traduisant chaque limite du rapport en mécanisme code/UI. Conservation du rolling-window en mode complémentaire « Surveillance rapide ». Indicateur R5 dépérissement créé. Spec 008 (`specs/008-suivi-sanitaire/`) et ADR-013 draft rédigés. Découpage E6 actualisé : E6.b phases 2-6 (app rapide) + E6.c.1-5 (cœur FORDEAD + validation QField) + E6.d (R5) + E6.f (release v0.21.0).
