# Spécification Fonctionnelle : Monitoring forestier continu

**Version** : 0.1.0 (draft validé)
**Date** : 2026-04-24
**Statut** : Draft — décisions validées, prêt pour plan.md
**Auteur** : Pascal Obstétar (via Claude)
**Cible nemeton** : v0.20.0

---

## 1. Résumé Exécutif

### 1.1 Vision

Permettre à `nemeton` de **monitorer en continu** l'état d'un massif forestier à partir de la série temporelle **Sentinel-2** (NDVI, NBR), avec détection d'**alertes** sur dégradation brutale (défoliation, chablis, feu). Les observations sont stockées dans **TimescaleDB** (hypertable chunkée par date), rattachées aux placettes GRTS issues du plan d'échantillonnage (spec 003).

### 1.2 Principe

Complément aux specs 001-006 qui opèrent « à l'instant T » (snapshot). Spec 007 introduit la **dimension temporelle persistée** : au lieu de recalculer tous les indicateurs au compute, on **ingère** des observations satellites datées et on **interroge** la série pour trancher si C2 (NDVI) ou T2 (changement) sont en dégradation.

Implémentation E6 walking skeleton : déclencheur **à la demande** (pas de cron worker), ingestion **par placette** (exactextractr buffer 15 m), source **CDSE prioritaire** (ADR-008, souveraineté UE) avec **fallback Planetary Computer** pour résilience.

### 1.3 Objectifs métier

| Objectif | Métrique de succès |
|----------|-------------------|
| Stocker une série NDVI+NBR pour un jeu de placettes | Hypertable `obs_pixel` peuplée, chunks visibles |
| Détecter une chute brutale de NDVI (défoliation / coupe) | `detect_alerts()` retourne ≥ 1 alerte sur AOI test |
| Détecter une chute brutale de NBR (feu) | Idem, seuil séparé |
| Souveraineté des données | CDSE utilisé en priorité, PC seulement en fallback |
| Pas de worker cron, pas de GPU | Ingestion déclenchée par l'UI / R session |

---

## 2. Scope

### 2.1 Inclus dans v0.20.0 (E6.a — walking skeleton)

- Schéma SQL TimescaleDB : `monitoring_zone`, `plot`, `obs_pixel` (hypertable), `alert`
- Migrations SQL versionnées dans `inst/db/migrations/`
- Helpers `db_connect()`, `db_migrate()`, `db_disconnect()` (DBI + RPostgres en Suggests)
- Client STAC unifié CDSE (priorité) → Planetary Computer (fallback)
  - `stac_search_s2(zone_sf, start, end, max_cloud = 20)` retourne un tibble des scènes avec hrefs B04/B08/B12
- Ingestion par placette :
  - `ingest_sentinel2_timeseries(con, zone_id, placettes, start, end, bands = c("NDVI","NBR"), radius_m = 15)`
  - Lit les COGs via `terra::rast()` + windowed read, extrait par placette via `exactextractr::exact_extract(mean)`, INSERT dans `obs_pixel`
- Détection d'alertes :
  - `detect_alerts(con, zone_id, threshold_ndvi_drop = 0.15, threshold_nbr_drop = 0.25, window_days = 30)`
  - SQL window function : valeur courante vs moyenne roulante fenêtre précédente
  - INSERT dans table `alert`, retourne sf des placettes en alerte
- Docker Compose : service `timescaledb` (image `timescale/timescaledb:latest-pg16`), volume persistant, auth via ENV
- Tests d'intégration avec pattern `skip_if_no_timescaledb()` + mocks STAC locaux

### 2.2 Reporté à v0.20.1+ (E6.b et suivants, hors de ce spec)

- Module Shiny `mod_monitoring` dans `nemetonshiny` (time series plot plotly, carte leaflet alertes)
- Cron worker (ex. via `cronR` ou GitHub Actions schedule) pour ingestion automatique
- Intégration des alertes dans `compute_all_indicators()` pour modulation dynamique de R1/R2/T2
- Notifications (email via `blastula`, webhook Mattermost)
- Sentinel-1 (SAR, C-band) pour complément radar sous nuages

### 2.3 Hors scope définitif

- Stockage des rasters bruts en base : on ne garde que les extractions par placette. Les rasters restent en S3 (ADR-002).
- Entraînement de modèles ML : on consomme des indices spectraux standards (NDVI = (B08-B04)/(B08+B04), NBR = (B08-B12)/(B08+B12)), pas d'apprentissage.
- Alertes en temps réel (< 1h latence) : on opère à J+3 à J+5 après passage Sentinel-2.

---

## 3. Architecture

### 3.1 Modèle de données (TimescaleDB)

```sql
-- Zones d'intérêt enregistrées
monitoring_zone (
  id           SERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  zone_wkt     TEXT NOT NULL,      -- polygon WGS84
  crs_epsg     INTEGER NOT NULL DEFAULT 2154,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  created_by   TEXT
);

-- Placettes suivies (points GRTS, typiquement)
plot (
  id           SERIAL PRIMARY KEY,
  zone_id      INTEGER REFERENCES monitoring_zone(id) ON DELETE CASCADE,
  plot_id      TEXT NOT NULL,      -- P01, P02... (clé métier)
  plot_type    TEXT,               -- Base / Over
  geom_wkt     TEXT NOT NULL,      -- point WGS84
  radius_m     NUMERIC DEFAULT 15,
  UNIQUE (zone_id, plot_id)
);

-- Observations (hypertable, chunk par semaine)
obs_pixel (
  plot_id      INTEGER REFERENCES plot(id) ON DELETE CASCADE,
  obs_date     DATE NOT NULL,
  band         TEXT NOT NULL,      -- 'NDVI' | 'NBR'
  value        DOUBLE PRECISION,   -- NULL si trop nuageux
  cloud_pct    NUMERIC,
  source       TEXT NOT NULL,      -- 'cdse' | 'pc'
  scene_id     TEXT,               -- S2A_MSIL2A_...
  PRIMARY KEY (plot_id, obs_date, band)
);
SELECT create_hypertable('obs_pixel', 'obs_date', chunk_time_interval => INTERVAL '7 days');

-- Alertes détectées
alert (
  id             SERIAL PRIMARY KEY,
  plot_id        INTEGER REFERENCES plot(id) ON DELETE CASCADE,
  alert_type     TEXT NOT NULL,    -- 'ndvi_drop' | 'nbr_drop'
  trigger_date   DATE NOT NULL,
  value_before   DOUBLE PRECISION,
  value_after    DOUBLE PRECISION,
  delta          DOUBLE PRECISION,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (plot_id, alert_type, trigger_date)
);
```

### 3.2 Flux d'ingestion (on-demand)

```
User (R / Shiny)
  │
  ▼
ingest_sentinel2_timeseries(con, zone_id, placettes, start, end)
  │
  ├── stac_search_s2(zone_bbox, start, end)
  │     ├── try CDSE catalogue
  │     └── fallback Planetary Computer
  │
  ├── for each scene matching period × zone:
  │     ├── terra::rast(href_B04), rast(href_B08), rast(href_B12)
  │     ├── crop to zone bbox + buffer
  │     ├── compute NDVI, NBR rasters in-memory
  │     └── exactextractr::exact_extract(raster, placettes_buffer_15m, 'mean')
  │
  ├── INSERT ... ON CONFLICT DO NOTHING dans obs_pixel
  │
  └── return tibble(plot_id, obs_date, band, value, cloud_pct, source, scene_id)
```

### 3.3 Détection d'alertes (SQL)

```sql
WITH rolling AS (
  SELECT plot_id, band, obs_date, value,
         AVG(value) OVER (
           PARTITION BY plot_id, band
           ORDER BY obs_date
           RANGE BETWEEN INTERVAL '30 days' PRECEDING
                     AND INTERVAL '1 day'  PRECEDING
         ) AS avg_prev
  FROM obs_pixel
  WHERE zone_id = $1
),
flagged AS (
  SELECT plot_id, band, obs_date, value, avg_prev,
         (avg_prev - value) AS drop_val
  FROM rolling
  WHERE value IS NOT NULL AND avg_prev IS NOT NULL
    AND (
      (band = 'NDVI' AND (avg_prev - value) > $2 /* threshold_ndvi_drop */)
      OR
      (band = 'NBR'  AND (avg_prev - value) > $3 /* threshold_nbr_drop */)
    )
)
INSERT INTO alert (plot_id, alert_type, trigger_date, value_before, value_after, delta)
SELECT plot_id,
       CASE WHEN band = 'NDVI' THEN 'ndvi_drop' ELSE 'nbr_drop' END,
       obs_date, avg_prev, value, drop_val
FROM flagged
ON CONFLICT DO NOTHING;
```

---

## 4. Décisions validées

1. **Sources STAC** : CDSE priorité + Planetary Computer fallback
2. **Bandes** : NDVI + NBR (B04, B08, B12) dès E6.a
3. **Déploiement** : ajout service TimescaleDB au `docker-compose.yml` racine
4. **Déclenchement** : à la demande (pas de cron)
5. **Granularité** : par placette, buffer 15 m (cercle inventaire forestier standard)

---

## 5. Dépendances (ajoutées en Suggests)

| Package | Usage |
|---------|-------|
| `DBI` | Interface DB générique |
| `RPostgres` | Driver PostgreSQL |
| `httr2` | Client HTTP pour STAC (déjà présent pour spec 006) |
| `exactextractr` | Déjà présent |
| `terra` | Déjà présent |

Aucune dépendance Python. Aucune inférence ML. Aucun GPU.

---

## 6. Licences et souveraineté

- **Sentinel-2** : Copernicus open licence (libre usage commercial avec attribution ESA)
- **CDSE** : pas de token requis pour search STAC ; téléchargement COG via href signé (pas de Keycloak nécessaire en lecture)
- **Planetary Computer** : pas de token pour search ; SAS tokens générés à la volée pour lecture raster

Attribution ESA + Copernicus dans `inst/NOTICE` à la publication.
