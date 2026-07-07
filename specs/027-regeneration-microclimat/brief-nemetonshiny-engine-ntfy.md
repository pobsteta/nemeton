# Brief `nemetonshiny` — Notifications ntfy du moteur reGénération (microclimf + BILJOU)

**Priorité : MOYENNE** (confort/observabilité, pas bloquant). **Aucun changement
cœur requis** pour le niveau *stage* (`nemeton >= 0.140.0` suffit). Une option
*fine* (ERA5 mois par mois) nécessiterait un petit brief cœur — voir §4.

## Objectif

Le bouton « Lancer le moteur réel » (microclimf + BILJOU) est **long**
(acquisition ERA5 + microclimf + bilan hydrique, minutes→heures) et tourne dans
un worker `future` : l'utilisateur n'a aucun retour intermédiaire. On veut, **au
fur et à mesure**, des pushes ntfy — exactement comme FAST/FORDEAD/RECONFORT
(`service_monitoring.R`).

## Mécanisme existant à réutiliser (déjà app, opt-in)

- `.ntfy_config()` (`service_monitoring.R:808`) : lit `NEMETON_NTFY_TOPIC` /
  `_URL` / `_TOKEN`. Retourne `NULL` si non configuré → tout devient **no-op
  silencieux** (opt-in strict, dégradation propre).
- `.ntfy_send(cfg, message, priority, tags, title)` (`:842`) : POST best-effort,
  `tryCatch` + timeout 10 s (jamais fatal). **Body UTF-8** (accents/emoji OK) ;
  **`title` = ASCII uniquement** (les en-têtes ntfy ne sont pas UTF-8 safe → ne
  PAS mettre « reGénération » dans `title`, utiliser p.ex. `"Nemeton Regen"`).
- Convention `title` par flux (FAST → `"Nemeton FAST"`, FORDEAD →
  `"Nemeton FORDEAD"`) pour que l'appareil groupe les notifications.

## Où câbler (dans le worker, pas dans `mod_regeneration.R`)

Tout se passe dans **`run_regeneration_engine()`** (`service_regeneration.R:446`),
qui EST le corps du worker (`getFromNamespace(...)` dans `future_promise`, cf.
`mod_regeneration.R:375-382`). Les variables d'environnement se propagent aux
workers `multisession`, donc `.ntfy_config()` fonctionne côté worker. `.ntfy_send`
/ `.ntfy_config` étant dans le namespace `nemetonshiny` (chargé dans le worker),
appel direct OK.

### 1. En tête de `run_regeneration_engine()` (après `i18n`/`out_dir`, ~l.453)

```r
ntfy  <- .ntfy_config()
tags0 <- c(default = "evergreen_tree", ok = "white_check_mark",
           skip = "fast_forward", warn = "warning", done = "checkered_flag")
.ntfy_send(ntfy, i18n$t("regen_ntfy_start"), title = "Nemeton Regen",
           tags = tags0[["default"]])
```

### 2. Bloc microclimf — début et fin (autour de `regen_sensibilite`, ~l.464-514)

- **Juste avant** l'appel `do.call(nemeton::regen_sensibilite, …)** (dans la
  branche `length(veg_args)`), pousser le début (c'est la phase ERA5, la plus
  longue) :
  ```r
  .ntfy_send(ntfy, i18n$t("regen_ntfy_micro_start"), title = "Nemeton Regen",
             tags = tags0[["default"]])
  ```
- **Après succès** (`if (inherits(sens, "sf"))`, après l'écriture de
  `sensibilite.gpkg`) :
  ```r
  .ntfy_send(ntfy, i18n$t("regen_ntfy_micro_done"), title = "Nemeton Regen",
             tags = tags0[["ok"]])
  ```
- **Si sauté / échec** (branches `else` : pas de structure de végétation, ou
  `sens` non-`sf`) — un push `skip`/`warn` avec la raison déjà dans `warnings` :
  ```r
  .ntfy_send(ntfy, i18n$t("regen_ntfy_micro_skip"), title = "Nemeton Regen",
             priority = "low", tags = tags0[["skip"]])
  ```

### 3. Bloc BILJOU — début et fin (autour de `regen_bilan_hydrique`, ~l.522-560)

- **Avant** `nemeton::load_biljou_forcing(...)` :
  ```r
  .ntfy_send(ntfy, i18n$t("regen_ntfy_biljou_start"), title = "Nemeton Regen",
             tags = tags0[["default"]])
  ```
- **Après succès** (`if (inherits(bil, "sf"))`, après `biljou.gpkg`) :
  ```r
  .ntfy_send(ntfy, i18n$t("regen_ntfy_biljou_done"), title = "Nemeton Regen",
             tags = tags0[["ok"]])
  ```

### 4. Fin — résumé (juste avant `list(units = res, …)`, ~l.563)

```r
done_msg <- if (length(cached))
  sprintf(i18n$t("regen_ntfy_done"), paste(cached, collapse = ", "))
else i18n$t("regen_ntfy_done_empty")
.ntfy_send(ntfy, done_msg, title = "Nemeton Regen",
           priority = if (length(cached)) "default" else "low",
           tags = if (length(cached)) tags0[["done"]] else tags0[["warn"]])
if (length(warnings)) {
  .ntfy_send(ntfy, paste(warnings, collapse = " — "), title = "Nemeton Regen",
             priority = "low", tags = tags0[["warn"]])
}
```

## Clés i18n à ajouter (`utils_i18n.R`, FR/EN)

| Clé | FR | EN |
|-----|----|----|
| `regen_ntfy_start` | « Moteur reGénération lancé (microclimf + BILJOU)… » | "Regeneration engine started (microclimf + BILJOU)…" |
| `regen_ntfy_micro_start` | « microclimf : acquisition ERA5 + exposition en cours… » | "microclimf: ERA5 acquisition + exposure running…" |
| `regen_ntfy_micro_done` | « microclimf : sensibilité microclimatique calculée ✓ » | "microclimf: microclimatic sensitivity computed ✓" |
| `regen_ntfy_micro_skip` | « microclimf : non calculé (structure de végétation ou CDS manquants) » | "microclimf: not computed (missing vegetation structure or CDS)" |
| `regen_ntfy_biljou_start` | « BILJOU : bilan hydrique en cours… » | "BILJOU: water balance running…" |
| `regen_ntfy_biljou_done` | « BILJOU : bilan hydrique calculé ✓ » | "BILJOU: water balance computed ✓" |
| `regen_ntfy_done` | « Moteur reGénération terminé : %s » | "Regeneration engine finished: %s" |
| `regen_ntfy_done_empty` | « Moteur reGénération terminé : aucune sortie produite » | "Regeneration engine finished: no output produced" |

(`%s` = liste `cached`, ex. « sensibilite, biljou ».)

## Réserves / options

1. **Granularité *stage* seulement (app-only).** Ce brief pousse aux frontières
   microclimf/BILJOU. C'est déjà « au fur et à mesure » au niveau des deux gros
   blocs. Suffisant pour la plupart des cas.
2. **Granularité *fine* (ERA5 mois k/12, BILJOU point k/N) = brief cœur.**
   `regen_sensibilite()` (ERA5 mensuel via mcera5) et `regen_bilan_hydrique()`
   (« point 1/N… ») **n'exposent pas** de callback de progression. Pour pousser
   « ERA5 4/12 », il faudrait un argument `progress = function(event) …` côté
   cœur (comme `ingest_sentinel2_timeseries(progress_callback=)` pour FAST).
   → **petit brief cœur `nemeton` à demander si Pascal veut ce niveau** ; sinon
   le stage-level suffit. Ne PAS bricoler un scraping du stdout côté app.
3. **Rate-limit ERA5 (cf. brief microclimf).** Si microclimf s'arrête sur un
   throttle CDS, le push `micro_skip`/`warn` + le résumé `warnings` le
   signalent — cohérent avec la reprise depuis `micro_cache`.
4. **Dédup.** Les pushes sont uniques par run (une frontière de stage traversée
   une fois), pas besoin d'un state env de dédup comme le callback FORDEAD
   `fordead:phase`.

## Validation

Configurer `NEMETON_NTFY_TOPIC` (+ éventuellement `_URL`/`_TOKEN`), lancer « le
moteur réel » sur un projet LiDAR : recevoir sur l'appareil, dans l'ordre —
*start* → *micro_start* → *micro_done* → *biljou_start* → *biljou_done* → *done
(sensibilite, biljou)*. Sans `NEMETON_NTFY_TOPIC` : aucun envoi, aucun impact
(no-op). Un throttle CDS → *micro_skip* + résumé warnings.
