# Hand-off `nemetonshiny` — logs FAST propres (Tuile 1/120 → 120/120, sans saut ni entrelacement)

> **Statut** : à implémenter côté app `nemetonshiny`. Aucune modif requise
> côté cœur `nemeton`. À retirer une fois transféré (convention hand-off).

## Réponse courte : OUI, c'est possible — et uniquement côté app

Le cœur `nemeton` émet **déjà** un flux d'événements **parfaitement ordonné
et séquentiel**. Les sauts (`1/120, 3, 23, 51, 93…`) et le faux
« entrelacement » (la bande affichée appartient à une autre scène que
l'en-tête) viennent **uniquement de la façon dont l'app consomme ce flux**.
Donc le rendu « 1→120, chaque scène suivie de ses bandes, sans saut, sans
entrelacement » est atteignable **sans toucher à `nemeton`**.

## Cause racine (vérifiée, `file:ligne`)

Il y a **deux** transports de progression dans `mod_monitoring.R` :

1. **`ingest_progress`** (`mod_monitoring.R:1322`) — `reactivePoll` toutes
   les 500 ms sur `ingest_progress.json`. Ce fichier est **réécrit à
   chaque événement** par le worker (`service_monitoring.R:344-365` :
   `writeLines(toJSON(event))` + rename atomique → **un seul objet =
   le dernier event**). Le `valueFunc` fait `jsonlite::read_json()` →
   il ne récupère que **le dernier** événement présent au moment du poll.
   - L'observer (`mod_monitoring.R:1397`) reconstruit les lignes
     `Tuile Sentinel-2 (X/120)` et `⤷ Bande … (cache)` (`.log_band_event`,
     `mod_monitoring.R:2699-2705`) **à partir de ce dernier event**.
   - Le worker pousse plusieurs events par scène (1 `s2:scene` + 2-4
     `s2:band_cached`) en bien moins de 500 ms → **la quasi-totalité des
     events est écrasée avant le poll suivant**. D'où :
     - **les sauts** : seules les scènes « survivantes » au poll sont
       affichées (1, 3, 23, 51, 93…) ;
     - **le faux entrelacement** : la ligne `⤷ Bande` lue à un poll
       correspond à une scène dont l'en-tête `Tuile` a été écrasé à un
       poll précédent → en-tête et bande désynchronisés.

2. **`ingest_log_tick`** (`mod_monitoring.R:1346`) — celui-ci, lui, tail
   le fichier de log du worker **par offset d'octets** (`seek` +
   `readBin` du delta), donc **complet et ordonné**. Mais il ne véhicule
   que le `sink()` stdout du worker (cli **anglais** du cœur : `S2 band
   cache: enabled`, `Sentinel-2 STAC search done`), pas les lignes
   `Tuile/Bande` formatées en FR par l'app.

**En résumé** : le bon mécanisme (tail par offset, complet, ordonné)
existe déjà pour le flux brut ; le flux « métier » (Tuile/Bande FR) passe
par le mauvais mécanisme (JSON dernier-event, lossy).

## Le correctif (app uniquement)

Faire passer le flux d'événements métier d'un **« dernier event,
réécrit »** à un **« journal append-only, drainé intégralement »** —
exactement le pattern déjà utilisé par `ingest_log_tick`.

### 1. Côté worker — `service_monitoring.R:344-365`

Au lieu de réécrire `ingest_progress.json`, **append** une ligne NDJSON
par event dans `ingest_progress.ndjson` :

```r
function(event) {
  tryCatch(suppressWarnings({
    line <- jsonlite::toJSON(event, auto_unbox = TRUE, null = "null",
                             na = "null", POSIXt = "ISO8601")
    cat(line, "\n", sep = "", file = progress_ndjson_path, append = TRUE)
  }), error = function(e) invisible(NULL))
}
```

L'append d'une ligne unique est sûr (écriture séquentielle, un seul
worker). Garder le `.json` « dernier event » en parallèle si le toast
s'appuie dessus, ou le dériver de la dernière ligne NDJSON.

### 2. Côté lecteur — remplacer `ingest_progress` (1322) + son observer (1397)

Calquer `ingest_log_tick` (`mod_monitoring.R:1346-1370`) : à chaque tick,
lire **toutes les nouvelles lignes** depuis l'offset, parser chaque ligne
en event, et **rendre chaque event dans l'ordre** :

```r
ndjson_offset <- shiny::reactiveVal(0L)
ingest_events <- shiny::reactivePoll(
  intervalMillis = 300L, session,
  checkFunc = function() { p <- ndjson_path(); if (is.null(p)||!file.exists(p)) "0" else as.character(file.info(p)$size) },
  valueFunc = function() {
    p <- ndjson_path(); if (is.null(p)||!file.exists(p)) return(NULL)
    sz <- file.info(p)$size; off <- ndjson_offset()
    if (sz <= off) return(NULL)
    con <- file(p, "rb"); on.exit(close(con))
    if (off > 0) seek(con, off, "start")
    txt <- rawToChar(readBin(con, "raw", n = sz - off))
    ndjson_offset(as.integer(sz))
    # renvoyer TOUTES les nouvelles lignes, dans l'ordre
    Filter(nzchar, strsplit(txt, "\n", fixed = TRUE)[[1]])
  }
)

shiny::observe({
  lines <- ingest_events(); if (is.null(lines)) return()
  for (ln in lines) {                 # ordre d'arrivée = ordre worker
    ev <- tryCatch(jsonlite::fromJSON(ln), error = function(e) NULL)
    if (!is.null(ev)) .render_ingest_event(ev)   # ré-utilise la logique de l'observer actuel
  }
})
```

`.render_ingest_event()` = la logique de l'observer actuel
(`mod_monitoring.R:1397+`), mais appelée **une fois par event** au lieu de
sur « le dernier ». Résultat : `s2:scene` (en-tête `Tuile X/120`) puis
immédiatement ses `s2:band_cached` (`⤷ Bande …`), pour les 120 scènes,
**sans perte, sans saut, sans désynchro**.

### Garde-fous

- **Toast** : ne PAS rendre 120 toasts. Garder le toast coalescé (afficher
  le dernier event / un compteur), seul le **mirror console** rend chaque
  ligne. C'est précisément la raison pour laquelle l'observer actuel
  « écrase » — légitime pour le toast, pas pour le log.
- **Reset** : tronquer/supprimer le `.ndjson` au début de chaque ingestion
  (comme la suppression actuelle de `progress.json`, `mod_monitoring.R:2607`),
  et remettre `ndjson_offset(0L)`.
- **Intervalle** : 300 ms suffit ; le tail rattrape tout le retard à
  chaque tick (on lit le delta complet, pas un seul event).

## Pourquoi aucun changement côté `nemeton`

- L'ingestion (`ingest_sentinel2_timeseries`) boucle les scènes
  **séquentiellement** (`for (i in seq_len(total_scenes))`) et émet, dans
  l'ordre, `s2:scene`/`s2:scene_cached` puis les `s2:band_cached`/
  `s2:band_fetched` de la scène (`R/monitoring.R`, events documentés dans
  la roxygen `@param progress_callback`).
- Le prewarm (`.prewarm_fast_alerts`) tourne en `parallel = FALSE` et lit
  les COG cachés via `terra` (pas via `.get_s2_band_raster`) → il n'émet
  pas d'events bande. Le flux reste mono-thread, séquentiel.
- Donc le flux d'events EST déjà « 1→120 groupé ». Seul le transport app
  le dégrade.

## (Optionnel, complémentaire) Éviter la recherche STAC en relecture pure

Rappel de l'échange précédent : « Diagnostic FAST » lance **l'ingestion
complète** (STAC + scan) puis le prewarm — d'où les lignes Tuile, même
quand tout est en cache. Si l'objectif est *revoir* un diagnostic sans
rafraîchir :

- Depuis la **spec 017**, `read_fast_alert_rasters()` /
  `read_fast_alert_raster()` lisent **purement le cache COG** (aucun STAC,
  aucune DB). Un bouton « Afficher (cache) » distinct de « Rafraîchir »
  pourrait appeler directement ces readers → **aucune ligne Tuile, aucun
  STAC, instantané**. Aucun changement cœur (tout est déjà exposé).
- Les deux gestes :
  - **Rafraîchir** = ingestion (STAC + nouvelles scènes) + prewarm — avec,
    désormais, des logs propres grâce au correctif ci-dessus.
  - **Afficher** = `read_fast_alert_rasters()` sur le cache, sans worker.

## Références

- App : `mod_monitoring.R` (transports `ingest_progress` L1322 /
  `ingest_log_tick` L1346 ; observer L1397 ; `.log_band_event` L2699 ;
  reset progress L2607) ; `service_monitoring.R` (writer L344-365 ;
  ingestion `prewarm_alerts=TRUE` L213).
- Cœur : `nemeton::ingest_sentinel2_timeseries()` (events `s2:scene`,
  `s2:scene_cached`, `s2:band_cached`, `s2:band_fetched`, séquentiels),
  `read_fast_alert_rasters()` (lecture pure cache, spec 017/019).
- Session source : `nemeton` dev session du 2026-06-03.
