# Brief `nemetonshiny` — brancher « Auto (E-OBS) » sur `load_eobs_source()` (spec 034)

**Cœur requis** : `nemeton (>= 0.130.0)`.
**Objectif** : rendre le bouton **« Auto (E-OBS) »** de l'onglet reGénération
fonctionnel. Aujourd'hui il affiche toujours *« Détection E-OBS indisponible —
saisir les années manuellement »*. Portée : présentation/câblage seulement
(règles #1/#3).

---

## 1. Cause actuelle

`mod_regeneration.R`, observer `input$auto_years` (~ligne 186) appelle :

```r
nemeton::microclimate_detect_years(aoi = units, year_window = 10)   # PAS de `eobs`
```

Or `microclimate_detect_years()` **s'arrête** sans `eobs` (le cœur
n'auto-télécharge pas E-OBS). → toujours « indisponible ». Le maillon manquant
est désormais fourni par le cœur : **`load_eobs_source()`** (v0.130.0).

## 2. Correctif — récupérer E-OBS puis détecter

```r
shiny::observeEvent(input$auto_years, {
  units <- units_sf()
  if (is.null(units)) { shiny::showNotification(i18n$t("regen_need_project"), type = "warning"); return() }

  # 1) E-OBS T°max estivale par année (cache disque -> CDS best-effort).
  tx <- tryCatch(
    nemeton::load_eobs_source(
      aoi = units, var = "tx",
      years = seq(as.integer(format(Sys.Date(), "%Y")) - 10,
                  as.integer(format(Sys.Date(), "%Y")) - 1),
      cache_dir = <project>/cache/regeneration),
    error = function(e) NULL)

  # 2) Détection des années de référence à partir d'E-OBS.
  yrs <- if (!is.null(tx)) tryCatch(
    nemeton::microclimate_detect_years(eobs = tx, aoi = units, year_window = 10),
    error = function(e) NULL) else NULL

  if (!is.null(yrs) && !is.null(yrs$year_moyenne)) {
    shiny::updateNumericInput(session, "year_moyenne",  value = yrs$year_moyenne)
    shiny::updateNumericInput(session, "year_canicule", value = yrs$year_canicule)
    rv$eobs <- yrs
    shiny::showNotification(sprintf(i18n$t("regen_auto_done"),
      yrs$year_moyenne, yrs$year_canicule), type = "message", duration = 6)
  } else {
    # Dégradation propre conservée (pas de clé CDS / réseau / hors Europe).
    shiny::showNotification(i18n$t("regen_auto_none"), type = "warning", duration = 6)
  }
})
```

### 2.1 Notifications de progression (bas-droite) — `progress_callback`

`load_eobs_source()` publie un payload `list(current = <clé>, …)` à chaque étape
(v0.131.0). Brancher un `progress_callback` qui affiche une notification Shiny
(coin bas-droite par défaut) et **remplacer** la précédente via un `id` fixe :

```r
tx <- nemeton::load_eobs_source(
  aoi = units, var = "tx", years = <…>, cache_dir = <cache>,
  progress_callback = function(p) {
    msg <- switch(p$current,
      "eobs:cds_request"       = i18n$t("regen_eobs_dl_request"),   # « Requête E-OBS au CDS… »
      "eobs:cds_download_done" = i18n$t("regen_eobs_dl_done"),      # « Téléchargement E-OBS terminé »
      "eobs:unzip"             = i18n$t("regen_eobs_unzip"),        # « Décompression… »
      "eobs:read"              = i18n$t("regen_eobs_read"),         # « Lecture du netCDF… »
      "eobs:reduce"            = i18n$t("regen_eobs_reduce"),       # « Réduction estivale par année… »
      "eobs:complete"          = sprintf(i18n$t("regen_eobs_complete"), p$n_years),
      "eobs:unavailable"       = i18n$t("regen_auto_none"),
      NULL)
    if (!is.null(msg)) shiny::showNotification(
      msg, id = ns("eobs_progress"),                 # id fixe -> messages se remplacent
      duration = if (identical(p$current, "eobs:complete")) 6 else NULL,
      type = if (identical(p$current, "eobs:unavailable")) "warning" else "message")
  })
```

Comme l'appel CDS est bloquant, les payloads arrivent au fil des étapes
(`cds_request` → `cds_download_done` → `unzip` → `read` → `reduce` → `complete`).
En mode async (ci-dessous), router ces messages via un reactiveVal lu côté session.

Clés i18n à ajouter (FR/EN) : `regen_eobs_dl_request`, `regen_eobs_dl_done`,
`regen_eobs_unzip`, `regen_eobs_read`, `regen_eobs_reduce`, `regen_eobs_complete`
(`%s` = nombre d'années). `regen_auto_none` existe déjà.

Points clés :

- **Async** : `load_eobs_source(source = "cds")` télécharge (lent la 1ʳᵉ fois).
  Passer par un `ExtendedTask`/`future` + un spinner, comme les autres calculs
  reGénération, plutôt que bloquer l'UI dans l'observer. Le `progress_callback`
  écrit alors dans un `reactiveVal` que la session relaie en `showNotification`.
- **Cache** : écrire la sortie sous `<project>/cache/regeneration/eobs_tx.tif`
  (et `eobs_rr.tif` pour la branche A). `load_regeneration_precomputed()` lit
  déjà `pc$eobs` / `pc$eobs_tx` / `pc$eobs_rr` — alimenter ce cache une fois
  suffit ; les runs suivants (et le calcul complet) le réutilisent sans
  re-télécharger.
- **Réutiliser le cache si présent** : avant l'appel CDS, si
  `eobs_tx.tif` existe, `load_eobs_source(aoi = units, nc = <ce .tif>, source = "nc")`
  (chemin pur, pas de réseau).

## 3. Prérequis — clé Copernicus CDS

`load_eobs_source(source = "cds")` utilise `ecmwfr` (**la même clé que ERA5**) :

```r
ecmwfr::wf_set_key(key = "<TOKEN_CDS>")   # niveau utilisateur, pas dans un .Renviron de repo
```

Dataset E-OBS = `insitu-gridded-observations-europe` ; accepter ses conditions
sur le site CDS. Sans clé/réseau → `load_eobs_source()` renvoie `NULL` → le
bouton retombe proprement sur la saisie manuelle (message `regen_auto_none`).

## 4. Alternative sans clé (voie ECA&D)

Si Pascal préfère éviter le CDS : télécharger une fois le netCDF E-OBS `TX`
(https://www.ecad.eu/download/ensembles/download.php), le déposer dans le cache
projet, et appeler `load_eobs_source(aoi, nc = <chemin .nc>, source = "nc")`.
Aucun identifiant requis.

## 5. Contexte régional (branche A) — même source

`regeneration_context_eobs()` / `tendances_estivales_eobs()` consomment
`pc$eobs_tx` + `pc$eobs_rr`. Alimenter ces deux caches avec
`load_eobs_source(var = "tx")` et `load_eobs_source(var = "rr")` rend aussi la
carte bivariée disponible sans saisie.

---

### Voir aussi (retour carte, déjà diagnostiqué)
Sur la même carte reGénération, les **UGF ne s'affichent pas tant qu'aucun
résultat n'existe** : `output$map` ne fait que `fitBounds` ; les polygones
(groupe « UGF ») ne sont tracés que par l'observer `leafletProxy`, qui
`return()` si `rv$result` est `NULL`. Fix : ajouter un `addPolygons(units,
group = "UGF", color = "#3388ff", weight = 1, fillOpacity = 0.1)` dans le
`renderLeaflet` de base pour montrer les UGF (contour bleu) avant tout calcul.
