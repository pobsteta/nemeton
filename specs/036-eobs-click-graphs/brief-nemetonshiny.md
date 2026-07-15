# Brief `nemetonshiny` — Graphiques au clic sur la carte « Contexte régional (E-OBS) »

**Date** : 2026-07-15
**Spec** : [036](spec.md) — cœur livré en **`nemeton` v0.160.0**.
**Repo cible** : `nemetonshiny` (app pur — aucune logique métier à ajouter).
**Fichiers app** : `R/mod_regeneration.R` (onglet reGénération, sortie
`context_map`), `R/service_regeneration.R` (accès aux `.nc` / stacks cachés).
**Résumé** : la carte de contexte n'affiche qu'**une couleur par maille** (la
pente estivale). Au **clic**, ouvrir un panneau de **4 graphiques** qui rendent la
donnée sous la couleur, à la maille cliquée. Tout le calcul est côté cœur (3
accesseurs déjà exportés) ; l'app fait le **clic → point → accesseur → tracé**.

---

## 1. Prérequis cœur — DÉJÀ LIVRÉ (`nemeton` v0.160.0)

Trois fonctions exportées, chemin pur (extraction `terra` au point, aucune
acquisition). Rien à faire côté cœur pour les câbler.

| Fonction | Signature | Retour | Sert |
|---|---|---|---|
| `nemeton::eobs_summer_series()` | `(stack, point)` | `data.frame(year, value)` | graphes 1-3 |
| `nemeton::eobs_monthly_climatology()` | `(daily, point, var, years = NULL)` | `data.frame(month = 1:12, value)` | graphe 4 |
| `nemeton::eobs_trend_fit()` | `(series)` | `list(slope_decade, intercept, r2, p_value, n)` | droite du graphe 1 |

- `point` accepte **`c(lon, lat)` en EPSG:4326** (le clic leaflet, directement) ou
  un `sf`/`sfc` POINT. **Pas de reprojection manuelle** : les accesseurs
  reprojettent vers le CRS du raster en interne.
- Tous **NA-safe** hors emprise (série de `NA` → l'app affiche « hors couverture »).
- `eobs_trend_fit()$slope_decade == 10 × pente OLS annuelle` = **exactement** la
  pente cartographiée (`eobs_downscale`/`tendances_estivales_eobs`) → le chiffre du
  graphe 1 et la couleur de la maille coïncident par construction.

## 2. Ce qui est DÉJÀ en place côté app (à réutiliser)

- **Clic leaflet** : la carte est `output$context_map` (`renderLeaflet`,
  `mod_regeneration.R` ≈ 1718). Le clic est donc **`input$context_map_click`**
  (`$lng`, `$lat` en 4326). Aucun `addPolygons`/`addRasterImage` ne capte déjà le
  clic → l'événement est libre.
- **Stack estival par année** (graphes 1-3) : `.regen_load_eobs_buffered(units,
  project_path, var, buffer_m)` (`service_regeneration.R` ≈ 253) renvoie déjà le
  `SpatRaster` **une couche/an** via `nemeton::load_eobs_source(aoi, var, nc)`. Le
  raster est à la **résolution E-OBS native (~11 km, non downscalée)** — c'est
  exactement la maille brute qu'on veut extraire (cf. §5, honnêteté spatiale).
- **`.nc` quotidien plein-année** (graphe 4) : `regen_eobs_cached_nc(project_path,
  var)` (≈ 213) renvoie le chemin du `.nc` **déjà téléchargé** pour `tx`/`rr`. Le
  bloc CDS est le **quotidien complet** (tous les jours de l'année) — la réduction
  estivale se fait en aval. Donc `eobs_monthly_climatology()` lit ce `.nc`
  **sans nouvelle acquisition** pour `rr` (précip) et `tx`.

## 3. Le seul ajout d'acquisition : `tg` (température moyenne) pour le graphe 4

Le diagramme de Gaussen exige la **T° moyenne** (`tg`). Or seuls `tx`/`rr` sont
cachés. Deux voies (cf. spec §5.4) :

- **Option A (recommandée)** — acquérir `tg`. Ajouter, sur le modèle exact de
  `regen_fetch_eobs_rr()` (`service_regeneration.R` ≈ 332), un
  **`regen_fetch_eobs_tg()`** appelant `nemeton::load_eobs_source(aoi, var = "tg",
  years, cache_dir)`. `load_eobs_source` mappe déjà `tg → mean_temperature` ; c'est
  la **même clé CDS** que `tx`/`rr`. Puis étendre `regen_eobs_cached_nc()` :
  ```r
  regen_eobs_cached_nc <- function(project_path, var = c("tx", "rr", "tg")) {
    ...
    pat <- switch(var,
      tx = "^eobs_maximum-temperature.*\\.nc$",
      rr = "^eobs_precipitation-amount.*\\.nc$",
      tg = "^eobs_mean-temperature.*\\.nc$")   # <-- ajout
    ...
  }
  ```
  Bouton opt-in « Diagramme ombrothermique (Gaussen) » qui lance `regen_fetch_eobs_tg`
  dans un `future` (~800 Mo, jamais depuis un render), comme le bouton précip.
- **Option B (repli tolérable)** — si `tg` n'est pas encore acquise, tracer avec
  `tx` (déjà là) **explicitement étiqueté** « basé sur T°max — saison sèche
  majorée ». **Jamais un Gaussen faux présenté comme exact** : `Tmax > Tmean`
  déclenche `P < 2T` trop tôt et surestime la sécheresse.

> Les graphes 1-3 sont **estivaux** (JJA) ; le graphe 4 est **mensuel sur 12
> mois**. Le `.nc` caché couvrant déjà l'année entière, aucune fenêtre
> supplémentaire n'est requise pour `rr`/`tx` — seulement le bloc `tg`.

## 4. Câblage du clic → panneau

Dans le server de `mod_regeneration.R`, ajouter un observeur du clic et un panneau.
Toute la donnée vient des accesseurs cœur ; **aucun calcul métier dans l'app**.

```r
# Série estivale au point, mémoïsée par coordonnées (évite de re-extraire au
# ré-affichage). units_sf() et le project_path sont déjà disponibles dans le module.
click_series <- shiny::reactiveVal(NULL)

shiny::observeEvent(input$context_map_click, {
  ev <- input$context_map_click
  shiny::req(ev$lng, ev$lat)
  pt <- c(ev$lng, ev$lat)                      # EPSG:4326 -> accepté tel quel
  pp <- project_path(); units <- units_sf()
  buf <- (input$buffer_km %||% 25) * 1000

  # Graphes 1-3 : stacks estivaux tx & rr (réutilise le helper existant).
  stk_tx <- .regen_load_eobs_buffered(units, pp, "tx", buf)
  stk_rr <- .regen_load_eobs_buffered(units, pp, "rr", buf)
  ser_tx <- if (!is.null(stk_tx)) nemeton::eobs_summer_series(stk_tx, pt)
  ser_rr <- if (!is.null(stk_rr)) nemeton::eobs_summer_series(stk_rr, pt)

  # Graphe 4 : climatologie mensuelle. tg si acquise (option A), sinon tx (B).
  nc_t   <- regen_eobs_cached_nc(pp, "tg") %||% regen_eobs_cached_nc(pp, "tx")
  temp_is_tg <- !is.null(regen_eobs_cached_nc(pp, "tg"))
  nc_rr  <- regen_eobs_cached_nc(pp, "rr")
  clim_t  <- if (!is.null(nc_t))  nemeton::eobs_monthly_climatology(nc_t,  pt,
               var = if (temp_is_tg) "tg" else "tx")
  clim_rr <- if (!is.null(nc_rr)) nemeton::eobs_monthly_climatology(nc_rr, pt, var = "rr")

  click_series(list(pt = pt, tx = ser_tx, rr = ser_rr,
                    clim_t = clim_t, clim_rr = clim_rr, temp_is_tg = temp_is_tg))
  shiny::showModal(shiny::modalDialog(
    title = sprintf("Maille E-OBS — %.4f, %.4f", ev$lat, ev$lng),
    size = "l", easyClose = TRUE, footer = shiny::modalButton(i18n$t("close")),
    shiny::tabsetPanel(
      shiny::tabPanel(i18n$t("regen_ctx_series"),  plotly::plotlyOutput(ns("ctx_g1"))),
      shiny::tabPanel(i18n$t("regen_ctx_anomaly"), plotly::plotlyOutput(ns("ctx_g2"))),
      shiny::tabPanel(i18n$t("regen_ctx_distrib"), plotly::plotlyOutput(ns("ctx_g3"))),
      shiny::tabPanel(i18n$t("regen_ctx_ombro"),   plotly::plotlyOutput(ns("ctx_g4"))))))
})
```

- **Vue active** (`rv$context_view` / `input$context_view`) : sur `tx` ou `rr`,
  centrer les graphes 1-2 sur la variable de la vue ; sur **bivariée**, afficher
  les graphes 1-2 **des deux** variables côte à côte (c'est le sens du croisement).
- **Robustesse** : si la série cliquée est tout `NA` (hors couverture E-OBS),
  afficher un message plutôt qu'un graphe vide. Si `tg` **et** `tx` manquent, griser
  l'onglet ombrothermique avec l'invite « acquérir la température E-OBS ».
- `plotly` et `ggplot2` sont **déjà** des dépendances de l'app (utilisés par
  `mod_action_plan`, `mod_monitoring_*`, `fct_plot_pixel_dieback`) — rien à ajouter
  au DESCRIPTION.

## 5. Les 4 tracés (tous app-side, plotly)

1. **Série + tendance** (`ctx_g1`) : points `ser$value ~ ser$year` + droite depuis
   `fit <- nemeton::eobs_trend_fit(ser)` (`intercept + (year) * slope_decade/10`).
   Annoter `slope_decade` (°C/déc ou mm/déc), `r2`, `p_value`. **La pente affichée
   doit être `fit$slope_decade`** (= la couleur de la maille), pas un `lm` app-side
   ré-estimé.
2. **Anomalies** (`ctx_g2`) : barres `ser$value - mean(ser$value)` par année,
   colorées +/- (chaud/sec en rouge). Révèle les étés qui portent la tendance.
3. **Distribution régionale** (`ctx_g3`) : histogramme/densité des pentes du buffer
   (`terra::values(rv$context_raster)`, déjà en mémoire) + **trait vertical** à la
   valeur du point (pente de la maille cliquée). Situe le point : chaud/sec local
   ou dans la moyenne ? **Aucun nouvel appel cœur.**
4. **Ombrothermique / Gaussen-Bagnouls** (`ctx_g4`) : depuis `clim_rr` (précip,
   mm/mois) et `clim_t` (température, °C) —
   - barres bleues = précip mensuelle ; courbe rouge = température ;
   - **deux axes Y couplés `P = 2T`** (axe précip gradué 2× l'axe °C) ;
   - hachurer les mois où **la courbe P passe sous la courbe T** (P < 2T = mois
     secs de Gaussen) ;
   - annoter le nombre de mois secs et l'indice de De Martonne
     `sum(clim_rr$value) / (mean(clim_t$value) + 10)` ;
   - **titre honnête** : « T° moyenne (tg) » si `temp_is_tg`, sinon « basé sur
     T°max (tg indisponible) — saison sèche majorée ».

## 6. Cache (clic instantané)

- **Graphes 1-3** : `.regen_load_eobs_buffered()` relit un `.nc` déjà présent et
  réduit — quelques secondes au premier clic. Option : mémoïser le stack estival en
  session (`reactiveVal` par vue/projet) pour que les clics suivants soient
  instantanés ; ou cacher le stack en `.tif` multi-couches à côté de
  `context_<view>.tif` au moment du calcul du contexte.
- **Graphe 4** : la climatologie mensuelle relit le `.nc` quotidien et agrège 12
  valeurs — idem, mémoïsable en session par maille. Empreinte disque nulle si on
  reste sur le `.nc` déjà là.

## 7. Honnêteté spatiale (important)

Extraire la **maille E-OBS brute (~11 km)** — c'est l'observation réelle — et
**non** le pixel downscalé à ~200 m. Le downscaling (`eobs_downscale`) n'ajoute que
du détail orographique **spatial** ; le signal **temporel** (série, tendance,
climatologie) est celui de la maille. Le stack de `.regen_load_eobs_buffered()`
étant déjà à la résolution native, `eobs_summer_series()` extrait bien la maille.
Bonus UX : surligner sur la carte la maille E-OBS concernée par le clic.

## 8. i18n

Nouvelles clés `TRANSLATIONS` (FR/EN) à ajouter dans `nemetonshiny/R/utils_i18n.R` :
`regen_ctx_series`, `regen_ctx_anomaly`, `regen_ctx_distrib`, `regen_ctx_ombro`,
`regen_ctx_dry_months`, `regen_ctx_demartonne`, `regen_ctx_out_of_coverage`,
`regen_ctx_ombro_proxy_tx` (l'étiquette « saison sèche majorée »),
`regen_fetch_tg` (libellé du bouton d'acquisition). Textes **toujours** via
`i18n$t()`, jamais en littéral.

## 9. Tests app

- `testServer()` : simuler `input$context_map_click` (`list(lng=, lat=)`), vérifier
  l'appel de `eobs_summer_series` **et** `eobs_monthly_climatology` (mock des
  stacks/`.nc`) et l'ouverture de la modale. Clic hors couverture (série `NA`) →
  message, pas de crash.
- Repli option B : sans `.nc` `tg`, l'onglet ombrothermique utilise `tx` et affiche
  l'étiquette proxy ; sans `tx` **ni** `tg`, onglet grisé + invite d'acquisition.

## 10. Hors-scope v1 (cf. spec §8)

- Trajectoire jointe T×P dans le plan anomalie (placement dans le quinconce 5×5) → v2.
- Extrêmes journaliers (jours > seuil, vagues de chaleur) → hors périmètre agrégé v1.
- Aucun changement au **rendu de la carte** (couleurs/légende/tendance) : cette
  livraison n'ajoute qu'une **interaction au clic** + un panneau.
