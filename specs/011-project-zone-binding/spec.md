# Spec 011 — Project ↔ MonitoringZone binding stable

**Statut** : draft, à valider.
**Démarré** : 2026-05-23.
**Cible cœur** : `nemeton` migration `0003_project_uuid` + `find_zone_by_project()` exporté.
**Cible app** : `nemetonshiny` mod_home hook au chargement de projet récent (chantier séparé).

## 1. Problème observé

Au rechargement d'un projet récent (ex. « villards ») depuis la
sélection « projets récents » de `nemetonshiny`, l'onglet *Suivi
sanitaire* (`mod_monitoring`) **n'a pas de `zone_id` pré-sélectionné**.
Conséquence : les sous-modules `mod_monitoring_fast_alerts` et
`mod_monitoring_fordead_map` reçoivent un `zone_id_r()` vide, aucune
alerte / aucun masque n'est rendu, alors que la zone existe en DB
(table `monitoring_zone`, id 1 pour villards, 155 placettes, masque
FORDEAD persisté sous `cache/layers/fordead/zone_1/`).

**Cause racine** :

- L'app lit `app_state$current_project$metadata$monitoring_zone_id`
  (`nemetonshiny/R/mod_monitoring.R:940`).
- Ce champ n'est posé **qu'une seule fois**, par le bouton
  « Enregistrer le projet comme zone » (`mod_monitoring.R:1022-1078`)
  qui persiste l'id retourné par `register_monitoring_zone()` dans
  `metadata.json`.
- Au rechargement d'un projet, si ce champ est absent du metadata —
  parce que le projet a été créé sur une autre machine, parce que
  l'utilisateur a effacé `metadata.json`, ou tout simplement parce que
  la zone a été créée avant que ce champ existe — l'app ne tente
  **aucun lookup DB** pour le retrouver.

Côté cœur, `monitoring_zone` (`inst/db/migrations/pg/0001_init.sql:24`)
n'a **aucun lien stable** vers le projet — seulement un `name TEXT NOT
NULL` qui se rejoue par convention à partir du nom du projet. Cette
clé est fragile (doublons possibles, renommage de projet).

## 2. Décision

Introduire un **lien stable** projet ↔ zone, porté par l'UUID du
projet (déjà présent dans `nemetonshiny` au champ `metadata.id` du
projet, format `<timestamp>_<random>` ou UUID v4 selon la version).

**Choix d'identité** : `project_uuid TEXT` (pas `INTEGER`) — la valeur
est opaque côté cœur, l'app la définit. `TEXT` accommode `UUID v4`
comme le format historique `20260520_212017_btfe`.

**Choix de cardinalité** : 1 projet = au plus 1 zone (UNIQUE), mais 1
zone peut exister sans projet (NULL autorisé) — préserve la
rétrocompat avec les zones registered avant migration.

## 3. Livrables cœur (`nemeton`)

### 3.1 Migration `0003_project_uuid.sql` (PG + DuckDB)

```sql
ALTER TABLE monitoring_zone
  ADD COLUMN IF NOT EXISTS project_uuid TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS monitoring_zone_project_uuid_uq
  ON monitoring_zone (project_uuid)
  WHERE project_uuid IS NOT NULL;
```

`WHERE project_uuid IS NOT NULL` (index partiel PG) garantit l'unicité
sans bloquer les zones legacy à NULL. La forme DuckDB sera adaptée si
l'index partiel n'est pas supporté (fallback : check applicatif).

### 3.2 `register_monitoring_zone()` — argument optionnel

Ajouter `project_uuid = NULL` à la signature (`R/monitoring.R:38`),
écrit en DB si non NULL. Rétrocompat totale.

### 3.3 Nouvelle fonction exportée `find_zone_by_project()`

```r
find_zone_by_project(con, project_uuid)
#> integer(1) | integer(0)
```

Sémantique :

- renvoie l'`id` de la zone liée à ce `project_uuid`, ou `integer(0)`
  si aucune correspondance ;
- ne lit **jamais** par `name` (intentionnel : on documente la fin de
  cette convention fragile dans NEWS).

### 3.4 Tests

- `tests/testthat/test-project-zone-binding.R` :
  - migration apply idempotent ;
  - `register_monitoring_zone(project_uuid = "abc")` round-trips ;
  - `find_zone_by_project("abc")` renvoie l'id ;
  - `find_zone_by_project("inconnu")` renvoie `integer(0)` ;
  - 2 appels avec le même `project_uuid` → erreur `UNIQUE` ;
  - `project_uuid = NULL` (legacy) → pas d'index, pas de collision.

## 4. Hors scope (à traiter côté `nemetonshiny`, chantier séparé)

- Hook dans `mod_home.R` après `load_project()` : si
  `metadata$monitoring_zone_id` absent, appeler
  `nemeton::find_zone_by_project(con, project$id)` ; si trouvé,
  hydrater `metadata$monitoring_zone_id` (et optionnellement réécrire
  `metadata.json`).
- Hook dans `register_project_as_zone()` côté app pour passer
  `project_uuid = project$id` à `register_monitoring_zone()`.
- Migration de données ponctuelle : pour les zones registered avant
  spec 011, l'utilisateur peut soit re-cliquer « Enregistrer le projet
  comme zone » (sans-effet sauf qu'il pose maintenant le lien), soit
  un `UPDATE` manuel.

## 5. Risques

| Risque | Mitigation |
|---|---|
| `project_uuid` collision entre 2 utilisateurs sur DB partagée | UUID v4 reste statistiquement sûr ; format `<timestamp>_<rand>` actuel l'est aussi en pratique mono-utilisateur |
| Index partiel non supporté en DuckDB | Fallback : index simple + check applicatif côté `register_monitoring_zone()` |
| Zones legacy sans `project_uuid` invisibles au lookup | Documenté : `find_zone_by_project()` ne fait PAS de fallback sur `name`. L'utilisateur re-clique « Enregistrer » une fois pour poser le lien. |

## 6. Suite

Si la spec est validée :

- côté cœur : migration + fonction + tests → 1 release patch ou minor
  (préférence : **minor v0.44.0** car nouvelle fonction exportée) ;
- côté app : chantier `nemetonshiny` séparé (mod_home hook +
  register hook).
