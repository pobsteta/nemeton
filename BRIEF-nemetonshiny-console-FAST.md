# Hand-off `nemetonshiny` — console d'ingestion FAST (logs propres + compteur 1-based)

> **Statut** : à corriger côté app `nemetonshiny`. Aucune modif cœur
> `nemeton` requise pour l'une ni l'autre partie. À retirer une fois
> intégré (convention hand-off).

Deux points liés, tous deux sur le rendu console/toast de l'ingestion S2
(`mod_monitoring.R`). **Le cœur émet déjà un flux séquentiel, ordonné,
complet** — tout se règle côté app.

---

## Partie A — Logs `Tuile 1/120 → 120/120`, groupés, sans entrelacement

> ⚠️ **Semble déjà livré en `nemetonshiny@v0.70.0`** (cf. commentaire
> `mod_monitoring.R:1676` : « `.log_ingest_event` déménage dans l'observer
> NDJSON drain »). Section conservée pour **vérification** ; si le drain
> NDJSON est en place, Partie A est close.

### Cause historique

Deux transports coexistaient :
1. `ingest_progress` (`reactivePoll` 500 ms sur `ingest_progress.json`) —
   fichier **réécrit à chaque event** (`service_monitoring.R:344-365`) →
   seul le **dernier** event survit au poll → sauts (1, 3, 23, 51…) et
   faux entrelacement (bande d'une scène sous l'en-tête d'une autre).
2. `ingest_log_tick` (`mod_monitoring.R:1346`) — tail par **offset
   d'octets**, complet et ordonné (le bon pattern).

### Correctif (le pattern à confirmer en place)

Faire passer le flux d'events métier en **journal append-only NDJSON**,
**drainé intégralement** en FIFO (comme `ingest_log_tick`) :
- worker : **append** 1 ligne JSON/event (au lieu de réécrire le `.json`) ;
- lecteur : à chaque tick, lire **toutes** les nouvelles lignes depuis
  l'offset, rendre **chaque** event dans l'ordre (`s2:scene` puis ses
  `s2:band_cached`, scène par scène) ;
- garder le **toast** coalescé (dernier event), seul le **mirror console**
  rend chaque ligne ; tronquer le `.ndjson` au début de chaque ingestion.

Pourquoi sans changement cœur : l'ingestion boucle séquentiellement
(`for i in 1..total`) et émet en ordre `s2:scene[_cached]` puis les
`s2:band_*` de la scène ; le prewarm tourne `parallel = FALSE` et lit les
COG via `terra` (pas d'events bande). Le flux EST déjà « 1→120 groupé ».

---

## Partie B — Compteur de tuile **1-based** (`(1/120)` au lieu de `(0/120)`)

### Cause (pas un bug cœur — sémantique de `completed`)

Le cœur émet, pour `s2:scene` / `s2:scene_cached` / `s2:scene_skipped`,
**`completed = i - 1`** = « scènes **terminées avant** celle-ci »
(`R/monitoring.R`). Volontaire : `completed/total` est une **fraction de
progression** (0 au départ, `total` à la fin via `s2:complete`). L'app
l'affiche tel quel comme libellé de tuile → `(0/120)` sur la 1ʳᵉ scène.

**Décision** : ne PAS changer `completed` côté cœur (consommé comme
fraction). Afficher `completed + 1` **uniquement dans le libellé** « tuile
en cours » (1..total). Garder les **gardes « entre STAC et 1ʳᵉ tuile »**
(`!nzchar(scene) && i_val == 0L`) sur le `completed` **brut** — elles
dépendent du 0.

### Correctif (app, là où le libellé « Tuile (X/N) » est construit)

> Post-v0.70.0, ce libellé vit dans l'observer NDJSON drain (Partie A) et
> dans `.log_ingest_event()` (`mod_monitoring.R:2745`) et/ou le toast
> (`mod_monitoring.R:1643-1675`). Appliquer le `+1` à **chaque** site qui
> rend « Tuile {scene} (X/N) ».

Mirror console — `.log_ingest_event()` (après la garde STAC, L2753) :
```r
  tile_no <- i_val + 1L      # completed (0-based) -> tuile en cours (1-based)
  ...
  cli::cli_alert_info("Tuile Sentinel-2 {scene} ({tile_no}/{n_val}){suffix}")
  # idem pour la variante scene_error
```

Toast — observer (L1656-1674), garde STAC L1651 inchangée :
```r
        htmltools::HTML(sprintf(
          i18n$t("monitoring_ingest_progress_named_fmt"),
          scene_html, i_val + 1L, n_val))     # <- + 1L
        ...
        sprintf(i18n$t("monitoring_ingest_progress_fmt"),
                i_val + 1L, n_val)            # <- + 1L
```

### Vérification

- `s2:scene` émis au **début** de chaque scène (`i = 1..total`) →
  `completed = 0..(total-1)` → `tile_no = 1..total` → `1/120 … 120/120`.
- `s2:complete` (`completed = total`) n'est pas rendu comme une tuile →
  pas de `121/120`.
- Gardes STAC justes (testées sur `completed == 0` brut, état sans scène).

### (Optionnel) variante cœur

Émettre un `tile_index = as.integer(i)` 1-based dans les payloads
`s2:scene*` (non-breaking) et afficher `ev$tile_index %||% (completed+1)`.
Plus propre sémantiquement, mais nécessite quand même une retouche app →
le `+1` app-only suffit et est plus léger.

---

## Bump & côté cœur

- App `nemetonshiny` : PATCH (fix d'affichage). NEWS : « Console
  d'ingestion FAST : compteur de tuile 1-based (`Tuile (1/N)`) ; (rappel)
  flux NDJSON drain pour des logs `1→N` ordonnés sans entrelacement. »
- **Aucun changement `nemeton`**, aucun bump plancher requis.

## Références

- Cœur : `nemeton::ingest_sentinel2_timeseries()` — payloads `s2:scene*`
  (`completed = i - 1`), `s2:band_cached`/`s2:band_fetched`, séquentiels
  (`R/monitoring.R`).
- App : `mod_monitoring.R` — transports `ingest_progress` (L1322) /
  `ingest_log_tick` (L1346) ; toast (L1643-1675, garde STAC L1651) ;
  `.log_ingest_event` (L2745-2780, garde STAC L2753) ; note NDJSON drain
  v0.70.0 (L1676). Writer `service_monitoring.R:344-365`.
- Session source : `nemeton` dev session du 2026-06-03.
