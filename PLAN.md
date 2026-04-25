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
| ✅ | E5 | Intégrations & NDP — Open-Canopy CHM (spec 005) + QField export/ingest (spec ad hoc) + sizing échantillon + flag `height_lidar` | `nemeton` v0.16.0 → v0.19.12 + `nemetonshiny` (clôture `0a1eb63` le 2026-04-24) |
| 🟨 | **E6** | **Monitoring forestier continu** (TimescaleDB + Sentinel-2 NDVI/NBR + alertes, ADR-012) | E6.a livré v0.20.0 le 2026-04-25 ; **E6.b en cours** (UI `mod_monitoring`) ; E6.c reporté |
| ⬜ | E7 | RAG perspectives IA (pgvector + base de connaissances forestière, ADR-012) | non démarré |

Légende : ✅ livré · 🟨 en cours · ⬜ à venir.

---

# Chantier en cours — Épaississement 6 : monitoring forestier continu

**Démarré**  : 2026-04-24
**E6.a clôturé** : 2026-04-25 (release v0.20.0, commit `28570d4`)
**Spec**     : `specs/007-monitoring-continu/` (spec.md, plan.md, tasks.md)
**État**     : E6.a **livré côté cœur `nemeton`**. Prochain chantier = **E6.b** (UI dans `nemetonshiny`).
**Branche**  : `nemeton@main = 8df05a8` (cycle dev `0.20.0.9000`)

## Rappel — E5 (QField) clôturé le 2026-04-24

Pour mémoire, E5 est **bouclé des deux côtés** (`0a1eb63`) :
- E5.a — export `.qgz` QField (commits `9df1484` + `f074105`)
- E5.a bis — `create_sampling_plan()` GRTS/LPM2/random côté cœur (`a8ff2cf` + `66e6613`)
- E5.b — réingestion QField + bump NDP 2/3 (`a8ff2cf` + `4df5ad8`)
- E5.c — sizing automatique de `n_base` (`b02f924`)
- E5.d phase 2 — flag `height_lidar` augmenté (v0.19.5, `c1625da`)
- Fixes : v0.19.6 vectorisation `forest_cover` 40-80×, v0.19.7-v0.19.11 robustesse, **v0.19.12** fix `.qgz` QGIS 3.x

## Contexte E6

E6 introduit la **dimension temporelle persistée** dans `nemeton` :

- **TimescaleDB** comme store de série temporelle (hypertable chunkée 7 jours)
- **Sentinel-2** NDVI + NBR ingérés à la demande via STAC
- **CDSE prioritaire** (souveraineté UE, ADR-008), fallback **Planetary Computer**
- **Par placette** (buffer 15 m, `exactextractr`), pas de stockage raster
- **Déclenchement à la demande** (pas de cron worker en E6.a)

Bounded Contexts :
- **Inventaire** (ingestion Sentinel-2 dans un store persistant)
- **Analyse systémique** (alertes basées sur fenêtre roulante 30 j)
- **Interopérabilité** (adapters STAC CDSE + PC)

## Découpage

### E6.a — Walking skeleton monitoring (côté cœur `nemeton`) — **livré v0.20.0**

Cinq phases, toutes livrées dans le commit `28570d4` (release `f1489b2`-style mais minor bump 0.19.12 → 0.20.0).

- [x] **Phase 1 — Fondations** : `docker-compose.yml` + `.env.example` (service `timescale/timescaledb:latest-pg16`, volume `nemeton_pg_data`, healthcheck `pg_isready`) ; `R/db.R` (`db_connect`, `db_disconnect`, `db_migrate` via `NEMETON_DB_URL`, table `schema_migration` idempotente) ; migrations `inst/db/migrations/0001_init.sql` — 4 tables (`monitoring_zone`, `plot`, `obs_pixel`, `alert`), `obs_pixel` promue hypertable chunkée 7 jours.
- [x] **Phase 2 — Client STAC** : `R/sentinel2.R` — façade `stac_search_s2()` avec **CDSE prioritaire + PC fallback** (ADR-008). Helpers per-backend exportés : `stac_search_s2_cdse()`, `stac_search_s2_pc()`. Signature SAS automatique des hrefs PC pour que `terra::rast()` fonctionne sans auth supplémentaire.
- [x] **Phase 3 — Ingestion on-demand** : `R/monitoring.R` — `register_monitoring_zone(con, name, polygon, placettes)` upsert idempotent sur `(zone_id, plot_id)` ; `ingest_sentinel2_timeseries(con, zone_id, start, end, bands = c("NDVI","NBR"))` — fetch STAC, calcul NDVI (B04/B08) + NBR (B08/B12) en mémoire, extraction par-placette buffer 15 m via `exactextractr`, bulk INSERT via TEMP staging + `ON CONFLICT DO NOTHING`.
- [x] **Phase 4 — Alertes** : `R/alerts.R` — `detect_alerts(con, zone_id, threshold_ndvi_drop = 0.15, threshold_nbr_drop = 0.25, window_days = 30)`. SQL window function compare chaque obs à la moyenne roulante du fenêtrage précédent ; les drops > seuil sont persistés dans `alert` (idempotent sur `(plot_id, alert_type, trigger_date)`) et retournés en sf POINT.
- [x] **Phase 5 — Tests + release** : `test-db.R`, `test-sentinel2.R`, `test-alerts.R` + `helper-monitoring.R` (URL parsing, parsing features STAC, fenêtre alertes). Release v0.20.0 du **2026-04-25**, NEWS.md à jour, tag `v0.20.0` poussé, GitHub release générée.

### E6.b — App (côté `nemetonshiny`) — **prochain chantier**

Cible : v0.20.1+ côté cœur (si retours nécessaires) et bump correspondant côté `nemetonshiny`.

- [ ] `R/mod_monitoring.R` — onglet « Monitoring » : sélection zone + plage de dates + bandes
- [ ] Time series plotly multi-placettes (NDVI / NBR), bande de seuil colorée
- [ ] Carte leaflet des alertes (POINT, popup type/date/drop)
- [ ] Bouton « Lancer ingestion » → `ingest_sentinel2_timeseries()` async (`ExtendedTask` + `future`)
- [ ] Configuration seuils (`threshold_ndvi_drop`, `threshold_nbr_drop`, `window_days`) depuis l'UI
- [ ] Persistance config dans les métadonnées projet (`update_project_metadata`)
- [ ] Clés i18n FR/EN (`tab_monitoring`, `monitoring_*`, `alert_*`)
- [ ] Tests `testServer()` sur `mod_monitoring` + smoke `shinytest2`

### E6.c — Automatisation — **reporté**

- [ ] Cron worker (`cronR` ou GitHub Actions `schedule`) déclenchant `ingest_sentinel2_timeseries()` sur toutes les zones actives
- [ ] Intégration alertes dans `compute_all_indicators()` : modulation R1 (feu, drops NBR), R2 (tempête, drops NDVI brutaux), T2 (changement temporel)
- [ ] Notifications : `blastula` email, webhook Mattermost
- [ ] Tableau de bord sysadmin (queue d'ingestion, latence STAC, échecs)

### E7 — RAG perspectives IA — **non démarré**

Spec à rédiger (`specs/008-rag-perspectives-ia/`). pgvector + base de connaissances forestière (ADR-012). Probablement v0.21.0+.

## Décisions validées E6 (2026-04-24)

1. STAC : **CDSE prioritaire + PC fallback**
2. Bandes : **NDVI + NBR** (B04, B08, B12)
3. Déploiement : **docker-compose service TimescaleDB**
4. Déclenchement : **à la demande** (pas de cron en E6.a)
5. Granularité : **par placette** (buffer 15 m)

## Journal

- **2026-04-24** — E6 démarré. Spec 007 rédigée (spec.md, plan.md, tasks.md). Décisions 1-5 tranchées. Démarrage Phase 1.
- **2026-04-25** — E6.a phases 1 à 5 livrées dans le commit `28570d4`. Release **v0.20.0** publiée (NEWS.md, tag, GitHub release). Cycle dev `0.20.0.9000` ouvert (`8df05a8`). Working tree propre. Prochain chantier : E6.b (UI `mod_monitoring` côté `nemetonshiny`).
