# PLAN — Épaississement 6 : monitoring forestier continu

**Démarré** : 2026-04-24
**Cible**   : v0.20.0 (feat: minor bump depuis 0.19.12)
**Spec**    : `specs/007-monitoring-continu/` (spec.md, plan.md, tasks.md)
**État**    : Phase 1 en cours

## Contexte

E5 (QField) bouclé le 2026-04-24 avec le fix QGIS 3.x (v0.19.12). E6 introduit la **dimension temporelle persistée** :

- **TimescaleDB** comme store de série temporelle (hypertable chunkée 7 jours)
- **Sentinel-2** NDVI + NBR ingérés à la demande via STAC
- **CDSE prioritaire** (souveraineté UE, ADR-008), fallback **Planetary Computer**
- **Par placette** (buffer 15 m, exactextractr), pas de stockage raster
- **Déclenchement à la demande** (pas de cron worker en E6.a)

Bounded Contexts :
- **Inventaire** (ingestion Sentinel-2 dans un store persistant)
- **Analyse systémique** (alertes basées sur fenêtre roulante 30 j)
- **Interopérabilité** (adapters STAC CDSE + PC)

## Découpage

### E6.a — Walking skeleton monitoring (côté cœur `nemeton`) — **en cours**

**Cinq phases**, voir `specs/007-monitoring-continu/tasks.md` (18 tâches).

1. Fondations : docker-compose TimescaleDB + migrations SQL + `db.R`
2. Client STAC : CDSE prioritaire + PC fallback
3. Ingestion : `ingest_sentinel2_timeseries()` on-demand
4. Alertes : `detect_alerts()` avec SQL window
5. Tests + release v0.20.0

### E6.b — App (côté `nemetonshiny`, **reporté à v0.20.1+**)

- Module `mod_monitoring` : time series plotly, carte leaflet alertes
- Configuration seuils depuis UI
- Déclenchement ingestion depuis le projet ouvert

### E6.c — Automatisation (**reporté, E6.c ou plus tard**)

- Cron worker (cronR, GitHub Actions schedule)
- Intégration alertes dans `compute_all_indicators()` (modulation R1/R2/T2)
- Notifications (blastula email, webhook Mattermost)

## Décisions validées (2026-04-24)

1. STAC : **CDSE priorité + PC fallback**
2. Bandes : **NDVI + NBR** (B04, B08, B12)
3. Déploiement : **docker-compose service TimescaleDB**
4. Déclenchement : **à la demande** (pas de cron)
5. Granularité : **par placette** (buffer 15 m)

## Journal

- **2026-04-24** — E6 démarré. Spec 007 rédigée (spec.md, plan.md, tasks.md). Décisions 1-5 tranchées. Démarrage Phase 1.
