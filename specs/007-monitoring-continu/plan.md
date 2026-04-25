# Plan d'Implémentation : Monitoring forestier continu

**Spec associée** : `spec.md` (v0.1.0, validé le 2026-04-24)
**Cible** : nemeton v0.20.0
**Statut** : Draft
**Auteur** : Pascal Obstétar (via Claude)

---

## 1. Vue d'ensemble

### 1.1 Scope technique

| Couche | Impact |
|--------|--------|
| **R/** (cœur) | 4 nouveaux fichiers (`db.R`, `sentinel2.R`, `monitoring.R`, `alerts.R`) |
| **DESCRIPTION** | +3 Suggests (`DBI`, `RPostgres`, `rstac` optionnel) |
| **inst/db/migrations/** | 1 nouveau fichier `0001_init.sql` |
| **docker-compose.yml** | +1 service `timescaledb` |
| **tests/testthat/** | 4 nouveaux fichiers, tous `skip_if_no_timescaledb()` ou mocks |
| **NEWS.md** | Section v0.20.0 |

### 1.2 Architecture cible

```
nemeton/
├── R/
│   ├── db.R                        [NEW]  db_connect, db_migrate, db_disconnect
│   ├── sentinel2.R                 [NEW]  stac_search_s2 (CDSE + PC fallback)
│   ├── monitoring.R                [NEW]  ingest_sentinel2_timeseries
│   └── alerts.R                    [NEW]  detect_alerts
├── inst/
│   └── db/
│       └── migrations/
│           └── 0001_init.sql       [NEW]  monitoring_zone, plot, obs_pixel, alert
├── docker-compose.yml              [NEW]  TimescaleDB service
├── tests/testthat/
│   ├── test-db.R                   [NEW]  connect, migrate, idempotence
│   ├── test-sentinel2.R            [NEW]  mocks STAC, fallback logic
│   ├── test-monitoring.R           [NEW]  ingest avec con en-mémoire SQLite (fallback test-only) ou TimescaleDB
│   └── test-alerts.R               [NEW]  detect_alerts sur données fixture
└── NEWS.md                         [MODIF]
```

### 1.3 Stratégie de tests

Trois niveaux :

1. **Tests unitaires purs** (pas de DB, pas de réseau) : mocks via `testthat::local_mocked_bindings()` pour les fonctions HTTP et la couche DB. Couverture : logique de fallback CDSE→PC, parsing STAC response, calcul NDVI/NBR à partir de rasters en mémoire, SQL de détection d'alertes sur fixture.
2. **Tests intégration DB** (skip si pas de TimescaleDB local) : helper `skip_if_no_timescaledb()` qui pingue `127.0.0.1:5432`. Créé/détruit un schéma `nemeton_test` par run.
3. **Tests réseau** (skip si offline) : un seul test `test-sentinel2.R::test_that("CDSE STAC responds")` qui fait une vraie requête, toujours skippé en CI sans secret.

---

## 2. Découpage en tâches (voir `tasks.md`)

**Phase 1 — Fondations (docker-compose, DB, migrations)**
- T1.1 docker-compose.yml TimescaleDB service
- T1.2 `inst/db/migrations/0001_init.sql`
- T1.3 `R/db.R` : connect / migrate / disconnect

**Phase 2 — STAC client**
- T2.1 `R/sentinel2.R` : `stac_search_s2()` CDSE
- T2.2 `R/sentinel2.R` : fallback Planetary Computer
- T2.3 Helper `parse_scene_assets()` pour normaliser les hrefs

**Phase 3 — Ingestion**
- T3.1 `R/monitoring.R` : `ingest_sentinel2_timeseries()` skeleton
- T3.2 Calcul NDVI/NBR in-memory via `terra`
- T3.3 Extraction par placette via `exactextractr`
- T3.4 INSERT bulk dans `obs_pixel` avec ON CONFLICT DO NOTHING

**Phase 4 — Détection d'alertes**
- T4.1 `R/alerts.R` : `detect_alerts()` avec SQL window
- T4.2 Retour sf enrichi (join `plot` + `alert`)

**Phase 5 — Tests + release**
- T5.1 Tests unitaires mocks
- T5.2 Tests intégration TimescaleDB (skip_if_no_timescaledb)
- T5.3 Release v0.20.0

---

## 3. Décisions techniques (hors spec)

- **Pas de `rstac`** : on utilise `httr2` direct pour éviter une dépendance Suggests de plus et avoir un contrôle fin sur le fallback CDSE → PC.
- **Chunks hypertable** : 7 jours. Compromise entre volumétrie et granularité de requête (une scène S2 tous les 2-5 jours par zone).
- **`ON CONFLICT DO NOTHING`** sur `obs_pixel` : idempotence ingestion, on peut relancer sans dupliquer.
- **`db_migrate()`** : migrations versionnées par nom de fichier (tri lex), avec table `schema_migration(version, applied_at)` qui trace ce qui a été passé.
- **Pas de `R/db_pool.R`** : on ouvre/ferme une connexion à chaque appel public. Pooling éventuel plus tard via `pool::dbPool` si perf l'exige.

---

## 4. Ordre d'exécution

1. Phase 1 (fondations) — **bloquant pour tout le reste**
2. Phase 2 (STAC) — parallélisable avec Phase 3 partie rasters (pas avec partie DB)
3. Phase 3 (ingestion) — dépend de Phases 1 et 2
4. Phase 4 (alertes) — dépend de Phase 1 et Phase 3 (besoin de données dans `obs_pixel` pour tester)
5. Phase 5 (tests + release) — en fin

---

## 5. Risques identifiés

| Risque | Mitigation |
|--------|------------|
| CDSE STAC API change/downtime | Fallback PC automatique |
| Volumétrie : 100 placettes × 40 scènes/an × 2 bandes = 8000 lignes/an × N zones | Hypertable chunked, rétention à définir en v0.20.1+ |
| Latence réseau lecture COG via terra | Windowed read par zone bbox, pas le raster complet (terra::rast(url, win=ext)) |
| Tests dépendants DB lourds | `skip_if_no_timescaledb()`, mocks pour l'essentiel |
| Token CDSE requis pour téléchargement | En lecture publique les hrefs COG sont signés côté serveur ; sinon documenter ENV `CDSE_USER` / `CDSE_PASS` (phase suivante) |
