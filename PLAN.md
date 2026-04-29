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
| 🟨 | **E6** | **Suivi sanitaire** — surveillance rapide (NDVI/NBR rolling-window) **+ diagnostic FORDEAD** (CRSWIR + harmonique). Spec 008, ADR-013. Indicateur **R5 dépérissement**. | E6.a livré v0.20.0 + hardening v0.20.1 ; **E6.b phase 1 livré** (`nemetonshiny@2909b8f`) ; reste E6.b phases 2-6, E6.c (FORDEAD), E6.d (R5), E6.f (smoke + release v0.21.0) |
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
- [ ] **E6.c.2** — `R/fordead_postprocess.R` (rasters → POINT clusters → `alert`), `FORDEAD_CONFIDENCE_WEIGHTS`, `classify_disturbance()`, migration `0002_fordead.sql`
- [ ] **E6.c.3** — `R/fordead_validity.R`, construction `inst/extdata/fordead_validity_zones.geojson` via geo.api.gouv.fr, script `data-raw/`
- [ ] **E6.c.4** — `R/health_validation.R` : schéma QField sanitaire (DSF-aligned), `generate_health_validation_plots()`, `ingest_health_validation()`
- [ ] **E6.c.5** — Mode sanitaire dans `mod_monitoring` (côté app) : toggle, bannières G3, génération QField, sous-onglet validation dans `mod_field_ingest`

### E6.d — Indicateur R5 dépérissement (côté cœur `nemeton`) — **à faire**

Spec 008 §7.

- [ ] `R/indicators-deperissement.R` : `indicateur_r5_deperissement(units, fordead_results, weights, min_resineux = 0.3)`
- [ ] Intégration radar via `compute_family_index(family = "R")` étendu R1-R5
- [ ] Tests : 18-20 assertions (cas vide, mono-classe, multi-classes, hors validité, plafonnement)

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

- **2026-04-24** — E6 démarré. Spec 007 rédigée (spec.md, plan.md, tasks.md). Décisions 1-5 tranchées. Démarrage Phase 1.
- **2026-04-25** — E6.a phases 1 à 5 livrées dans le commit `28570d4`. Release **v0.20.0** publiée (NEWS.md, tag, GitHub release). Cycle dev `0.20.0.9000` ouvert (`8df05a8`). Working tree propre. Prochain chantier : E6.b (UI `mod_monitoring` côté `nemetonshiny`).
- **2026-04-25** — E6.a hardening : ajout de `tests/testthat/test-monitoring.R` (12 test_that, 49 assertions, dont 9 d'intégration sur TimescaleDB éphémère). Les integration tests ont surfacé **deux vrais bugs** dans le code v0.20.0 : (1) `db_migrate()` plantait sur la migration multi-statements (RPostgres prepared statement vs PostgreSQL multi-commands) → fix `immediate = TRUE` dans `R/db.R` ; (2) `.insert_obs_pixel()` créait une `TEMP TABLE ON COMMIT DROP` hors transaction → table dropée immédiatement → fix : `CREATE TEMP TABLE` dans la même `dbWithTransaction` que les inserts. Aucun de ces bugs n'avait été détecté parce que la couverture intégration sur la DB était à zéro. Release **v0.20.1** publiée. Suite complète : 5760 PASS / 0 FAIL.
- **2026-04-25** — E5.b follow-up livré côté `nemetonshiny` (`c05962e`) : `.apply_field_data_if_present()` dans `service_compute.R` re-applique le GPKG terrain au compute time pour que les indicateurs P1/P2/B2/C1/R2 voient bien les mesures terrain entre deux runs.
- **2026-04-25** — E6.b phase 1 livrée côté `nemetonshiny` (`2909b8f`) : `mod_monitoring` scaffold + `service_monitoring_db.R` (adapter env-var → URL pour `nemeton::db_connect`) + zones reactive + status card + 19 i18n keys + navbar tab. 822 insertions, 5316 PASS / 0 FAIL.
- **2026-04-29** — **E6.c.1 livré** sur la branche `feat/008-fordead-pipeline` (pas encore mergée vers `main`, pas de release — cible E6.f). Trois nouveaux fichiers côté cœur : `R/fordead_python.R` (helpers reticulate idempotents : `.ensure_fordead_python`, `.use_fordead_env`, `.assert_fordead_system` avec garde Python ≥ 3.10, cache de session), `R/fordead_pipeline.R` (orchestrateur `run_fordead_dieback()` exporté, 5 phases FORDEAD via reticulate, validation arguments AOI/EPSG:2154/dates/threshold/VI, retour structuré, tryCatch global, calibration figée CRSWIR + 0.16 conformément à ADR-013), et `inst/python/requirements.txt` (versions pinnées : fordead 2.1.4, xarray, dask, rasterio, eodag, etc.). Suite de tests mockés : 8 tests reticulate (`test-fordead-python.R`) + 12 tests d'orchestration (`test-fordead-pipeline.R`) — 44 PASS, tous offline. Suite globale : **5700 PASS / 0 FAIL**. Dépendance `reticulate (>= 1.34.0)` ajoutée en `Suggests` (chargée à la 1ère utilisation seulement). Le helper `.download_or_use_cached_bd_foret()` est laissé en stub jusqu'à E6.c.3, et le post-process raster→clusters→DB attend E6.c.2. Cycle dev `0.20.1.9000` inchangé.
- **2026-04-26** — **Reframing du chantier E6** après lecture du rapport ONF/DSF *« Méthode FORDEAD — analyse de la validité des détections d'anomalies de végétation par contrôle terrain »* (Bernard & Doridant, mai 2024, 397 relevés sur Vosges/Jura/Alpes/Massif Central). Findings durs intégrés : faux positifs 50% / 1/3 sur classes 1-faible / 2-moyenne, détection précoce médiocre (60% des stades précoces ratés), confusion dépérissement / perturbation mécanique (25-41% selon altération). Décision : adopter FORDEAD comme méthode officielle de **suivi sanitaire** avec 5 garde-fous applicatifs (G1-G5) traduisant chaque limite du rapport en mécanisme code/UI. Conservation du rolling-window en mode complémentaire « Surveillance rapide ». Indicateur R5 dépérissement créé. Spec 008 (`specs/008-suivi-sanitaire/`) et ADR-013 draft rédigés. Découpage E6 actualisé : E6.b phases 2-6 (app rapide) + E6.c.1-5 (cœur FORDEAD + validation QField) + E6.d (R5) + E6.f (release v0.21.0).
