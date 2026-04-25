# Tâches d'Implémentation : Monitoring forestier continu

**Version** : 0.1.0
**Date** : 2026-04-24
**Spec** : `spec.md` v0.1.0 · **Plan** : `plan.md`
**Cible** : nemeton v0.20.0
**Total estimé** : 18 tâches
**Progression** : 0/18

`[P]` = parallélisable avec les autres `[P]` de la même phase.

---

## Phase 1 — Fondations

- [ ] **T1.1** `docker-compose.yml` : ajouter service `timescaledb`
  - Image `timescale/timescaledb:latest-pg16`
  - Volume persistant `nemeton_pg_data`
  - ENV `POSTGRES_PASSWORD` requis, `POSTGRES_USER=nemeton`, `POSTGRES_DB=nemeton`
  - Ports `127.0.0.1:5432:5432` (bind localhost only)
  - Healthcheck `pg_isready`

- [ ] **T1.2** `inst/db/migrations/0001_init.sql`
  - Tables `monitoring_zone`, `plot`, `obs_pixel`, `alert`
  - `CREATE EXTENSION IF NOT EXISTS timescaledb;`
  - `SELECT create_hypertable('obs_pixel', 'obs_date', chunk_time_interval => INTERVAL '7 days');`
  - Table `schema_migration(version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ DEFAULT NOW())`

- [ ] **T1.3** `R/db.R`
  - `db_connect(url = Sys.getenv("NEMETON_DB_URL"))` : retourne un `DBIConnection`
  - `db_migrate(con, migrations_dir = system.file("db/migrations", package = "nemeton"))` : applique migrations dans l'ordre lex, skip ce qui est dans `schema_migration`
  - `db_disconnect(con)` : wrapper `DBI::dbDisconnect`
  - Tests : 3 fonctions exportées documentées roxygen

---

## Phase 2 — Client STAC

- [ ] **T2.1** `R/sentinel2.R` : `stac_search_s2_cdse(bbox, start, end, max_cloud = 20)`
  - Endpoint `https://catalogue.dataspace.copernicus.eu/stac/search`
  - POST body JSON : collections=SENTINEL-2-L2A (ou nom exact CDSE), bbox, datetime, filter cloud_cover<=max_cloud, limit=100
  - Parse réponse FeatureCollection → tibble(scene_id, obs_date, cloud_pct, href_B04, href_B08, href_B12)

- [ ] **T2.2** [P] `R/sentinel2.R` : `stac_search_s2_pc(bbox, start, end, max_cloud = 20)`
  - Endpoint `https://planetarycomputer.microsoft.com/api/stac/v1/search`
  - collection=sentinel-2-l2a, filter via `eo:cloud_cover`
  - Signer les hrefs via `planetary-computer` signing endpoint (`/api/sas/v1/sign?href=...`) avant retour

- [ ] **T2.3** `R/sentinel2.R` : `stac_search_s2(zone, start, end, ..., source = c("cdse","pc"))`
  - Façade qui essaye CDSE, fallback sur PC si erreur ou résultat vide
  - Normalise bbox : `sf::st_bbox(sf::st_transform(zone, 4326))`
  - Retour uniforme : même schéma de tibble quelle que soit la source, colonne `source` en tag

---

## Phase 3 — Ingestion

- [ ] **T3.1** `R/monitoring.R` : squelette `ingest_sentinel2_timeseries()`
  - Signature : `ingest_sentinel2_timeseries(con, zone_id, placettes, start, end, bands = c("NDVI","NBR"), radius_m = 15, max_cloud = 20)`
  - Validation inputs : `con` ouverte, `zone_id` existe dans `monitoring_zone`, `placettes` est sf POINT
  - Appelle `stac_search_s2()` sur la bbox des placettes élargie de `radius_m`

- [ ] **T3.2** `R/monitoring.R` : calcul NDVI/NBR per scene
  - Pour chaque scène : `terra::rast(href_B04)`, `rast(href_B08)`, `rast(href_B12)`
  - Crop au bbox des placettes (windowed read via `terra::crop` ou `win=` sur le GDAL VSI)
  - NDVI = (B08 - B04) / (B08 + B04), NBR = (B08 - B12) / (B08 + B12)
  - Attention aux /0 (masquer NA)

- [ ] **T3.3** `R/monitoring.R` : extraction par placette
  - Buffer placettes de `radius_m` : `sf::st_buffer(placettes, radius_m)`
  - `exactextractr::exact_extract(ndvi, buf, "mean")` → vecteur
  - Idem NBR
  - Construire tibble long : plot_id × band × obs_date × value × cloud_pct × source × scene_id

- [ ] **T3.4** `R/monitoring.R` : INSERT bulk dans `obs_pixel`
  - D'abord s'assurer que les placettes sont dans `plot` (INSERT ... ON CONFLICT DO NOTHING)
  - Puis INSERT bulk dans `obs_pixel` via `DBI::dbAppendTable()` ou `glue_sql` VALUES (...), ON CONFLICT DO NOTHING
  - Retour : tibble summary (n_scenes, n_obs_inserted, n_placettes, bands)

---

## Phase 4 — Détection d'alertes

- [ ] **T4.1** `R/alerts.R` : `detect_alerts()`
  - Signature : `detect_alerts(con, zone_id, threshold_ndvi_drop = 0.15, threshold_nbr_drop = 0.25, window_days = 30)`
  - SQL window function (voir spec §3.3)
  - INSERT ... ON CONFLICT DO NOTHING dans `alert`

- [ ] **T4.2** `R/alerts.R` : retour enrichi
  - SELECT alert JOIN plot : géometries recomposées via `sf::st_as_sfc(geom_wkt)`
  - sf POINT avec colonnes plot_id, alert_type, trigger_date, value_before, value_after, delta

---

## Phase 5 — Tests et release

- [ ] **T5.1** `tests/testthat/helper-db.R` + `test-db.R`
  - Helper `skip_if_no_timescaledb()` : `tryCatch(DBI::dbConnect(RPostgres::Postgres(), ...), error = function(e) skip(...))`
  - Tests `db_connect`/`db_migrate` idempotence, `db_migrate` applique les 4 tables, `schema_migration` tracking

- [ ] **T5.2** [P] `tests/testthat/test-sentinel2.R`
  - `local_mocked_bindings(req_perform = ...)` avec fixtures JSON
  - Vérifier fallback CDSE→PC quand premier renvoie erreur / 0 features

- [ ] **T5.3** [P] `tests/testthat/test-monitoring.R`
  - Mock `stac_search_s2()`, mock `terra::rast()` via fixture raster local
  - Vérifier bulk INSERT, retour summary, idempotence (2 appels = pas de doublons)

- [ ] **T5.4** [P] `tests/testthat/test-alerts.R`
  - Fixture : INSERT 30 jours de NDVI stable + 1 jour avec drop
  - Vérifier `detect_alerts()` retourne 1 alerte, pas de doublon au 2e appel

- [ ] **T5.5** `DESCRIPTION` : ajouter Suggests `DBI`, `RPostgres`

- [ ] **T5.6** `NEWS.md` : section `v0.20.0` avec résumé des 4 modules + migrations

- [ ] **T5.7** Release v0.20.0
  - `devtools::document()` + `devtools::test()`
  - Bump `Version: 0.20.0` dans DESCRIPTION, `version: "0.20.0"` dans CITATION.cff
  - Commit conventional `feat(monitoring): E6.a walking skeleton`
  - Tag `v0.20.0`, push, `gh release create`
  - Re-bump à `0.20.0.9000` en dev
