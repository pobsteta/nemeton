# Retour `nemetonshiny` — prewarm FAST 6 combos livré (nemeton v0.65.1) + audit cache

> **Statut** : hand-off de retour vers la session `nemetonshiny`. Réponse
> au brief « étendre `.prewarm_fast_alerts()` aux 6 cartes ». À retirer de
> ce repo une fois transféré (convention hand-off).

## 1. Livré côté cœur — `nemeton` v0.65.1 (PATCH)

Le correctif demandé est **fait, testé, taggé, publié** :
<https://github.com/pobsteta/nemeton/releases/tag/v0.65.1>

- `.prewarm_fast_alerts()` (`R/monitoring.R`) : la boucle `expand.grid`
  passe de **4 → 6 combos** :
  `index = c("NDVI", "NBR", "NDMI") × mode = c("count", "rolling")`.
- **Aucun changement d'API**, aucune signature modifiée. Le worker émet
  toujours `fast_prewarm:<idx>_<mode>` / `_done` / `_failed`, désormais
  pour 6 combinaisons (jusqu'à 12 events début+fin au lieu de 8).
- **Garde-fou NDMI sans B11** : confirmé. Une scène sans B11 emprunte le
  chemin de skip best-effort existant — `read_fast_alert_raster()`
  renvoie `NULL`, capturé par le `tryCatch`, `cli::cli_warn("FAST prewarm
  NDMI/<mode> skipped: …")`, et l'event `fast_prewarm:NDMI_<mode>_failed`
  est émis. Exactement comme NBR sans B12. Pas d'exception, le prewarm
  continue.
- Tests : `test-prewarm-fast-alerts.R` **24 PASS** (fixture étendue à B11,
  assertions 4→6 combos, échec partiel couvre maintenant NBR **et** NDMI).
- Doc roxygen + `man/ingest_sentinel2_timeseries.Rd` : « four → six ».

### Action côté app

Bump le plancher : `Imports: nemeton (>= 0.65.1)` (et
`Remotes: pobsteta/nemeton@*release` tirera v0.65.1 au prochain install).
Aucune autre modif requise : l'app passe déjà
`prewarm_alerts = TRUE` + `prewarm_mask_cache_dir = .fast_alert_cache_dir()`,
et le cœur enchaîne désormais les 6 cartes tout seul.

**Effet UX** : après une ingestion S2, la 1re sélection **NDMI** dans
l'onglet Alertes/Carte FAST est un **hit cache D6 instantané** au lieu
d'un calcul à froid (1-5 s).

### À vérifier côté app (mineur)

- Le feed de progression (`mod_monitoring.R`) doit encaisser **jusqu'à 12
  events** prewarm sans rate-limit ni toast tronqué (était 8).
- Les libellés NDMI count/rolling existent bien en i18n
  (`fast_index_ndmi`, etc.) pour les toasts `_done`/`_failed`.

## 2. Audit des dossiers de cache FAST — RAS, c'est propre

J'ai audité tous les call-sites FAST de `nemetonshiny`. **Aucun correctif
nécessaire côté app.** Disposition actuelle sous `<projet>/cache/layers/` :

| Dossier | Helper / origine | Contenu | Module |
|---------|------------------|---------|--------|
| `sentinel2/` | `cache_dir` | bandes brutes S2 | ingestion |
| `fast_alert/` | `.fast_alert_cache_dir()` (v0.55.0) | raster **continu** (cache D6) | Monitoring + **prewarm** |
| `fast_alert_mask/` | `.fast_alert_mask_cache_dir()` (v0.57.0) | masques **0-4** | Monitoring |
| `fast_sampling/` | littéral (v0.69.0) | continu **+** masques 0-4 ensemble | Validation Sampling |
| `fordead/` | littéral | masques FORDEAD | FORDEAD |

Points vérifiés (tous ✅) :

- **Prewarm ↔ affichage cohérents** : le prewarm écrit le continu dans
  `fast_alert/` (`prewarm_mask_cache_dir = .fast_alert_cache_dir()`),
  l'onglet Monitoring lit le continu depuis ce même `fast_alert/` (via
  `compute_fast_alert_mask(result_cache_dir = .fast_alert_cache_dir())`).
  Donc le prewarm bénéficie bien à l'affichage — y compris NDMI depuis
  v0.65.1.
- **Sampling auto-cohérent** : écrit (`mask_cache_dir = result_cache_dir =
  fast_sampling`) et relit (`read_fast_alert_mask(cache_dir =
  fast_sampling)`) au même endroit. Pas de collision (noms distincts
  `fast_alert_*.tif` vs `fast_<index>_<mode>_<hash>.tif`).
- **Pas de mismatch écriture/lecture** : l'onglet Monitoring consomme la
  valeur de retour de `compute_fast_alert_mask()` directement ;
  `read_fast_alert_mask()` n'est utilisé que par le sampling, sur le bon
  dossier `fast_sampling`.
- **Plus aucun appel n'omet les dossiers** → le cœur ne recrée plus ni
  `fast/` ni `fast_raster/`.

### Le renommage v0.69.0 (`fast/` → `fast_sampling/`) était la bonne décision

`fast/` était l'ancien **défaut du cœur** (`dirname(cache_dir)/fast`)
qu'utilisait le sampling quand il ne passait pas `mask_cache_dir`
explicitement. Le rendre explicite (`fast_sampling/`) lève l'ambiguïté
avec le défaut cœur. RAS.

### Recommandations (facultatives)

1. **`fast/` sur disque est orphelin** depuis v0.69.0 (plus rien ne
   l'écrit) → suppression sûre si un résidu traîne encore.
2. **Deux conventions cohabitent** (Monitoring = 2 dossiers ; Sampling =
   1) — pas un bug. Unifier mutualiserait les caches entre les deux
   onglets (effet de bord à peser) ; **garder séparé est plus sûr**.
3. Le prewarm ne réchauffe **pas** `fast_sampling/` (dossier distinct) →
   la 1re prévisualisation sampling reste « à froid ». Compromis assumé.

## Références

- `nemeton@v0.65.1` — `.prewarm_fast_alerts()` 6 combos
  (`R/monitoring.R`), NEWS/CHANGELOG 0.65.1.
- `nemeton@v0.65.0` — `read_fast_alert_rasters()` + fix
  `.enumerate_cache_scenes()` NDMI.
- `nemetonshiny` call-sites audités : `mod_monitoring.R` (helpers
  `.fast_alert_cache_dir` / `.fast_alert_mask_cache_dir`, prewarm wiring
  L1860+), `mod_monitoring_fast_alerts.R` (L290-330), `mod_/service_
  validation_sampling.R` (`fast_sampling`, v0.69.0).
- Session source : `nemeton` dev session du 2026-06-03.
