# Brief → nemetonshiny : sous-onglets « Contexte climatique » de reGénération (spec 063)

- **Émetteur** : session `nemeton` (2026-10-18), réponse au brief
  `vers-nemeton/2026-10-18-contexte-climatique-cercle-projet.md` (§ 6).
- **Plancher** : `nemeton (>= 2026.10.15)`.
- **Référence cœur** : `specs/063-contexte-climatique-cercle/spec.md`.
- **Code de l'app lu (lecture seule, `nemetonshiny@a328585a`)** :
  `R/mod_regeneration.R` (UI `nav_panel(i18n$t("regen_map_context"))` l. 809-863,
  `context_task` l. 1439, observer lazy l. 1775-1813, `recompute_context`
  l. 1821, `.context_add_layer()` l. 2737, `output$context_map` l. 2802, clic
  spec 036 l. 2901), `R/service_regeneration.R`
  (`run_regeneration_context_raster()` l. 285, `regeneration_context_cached()`
  l. 321, `.REGEN_BIVARIATE_N` l. 344, `.regen_eobs_progress_cb()` l. 1518),
  `R/utils_bivariate_legend.R` (`bivariate_legend_html()`).

---

## 1. Ce que le cœur fournit

```r
s <- nemeton::climat_ete_series(units, source = "eobs" | "chelsa" | "safran",
                                rayon_km = 25, mois = 5:9,
                                cache_dir = file.path(project_path, "cache", "regeneration"),
                                progress_callback = cb)
b <- nemeton::climat_tendance_bivariee(s, periode = "complete" | "if49" | c(deb, fin),
                                       cache_path = <voir § 4>)
n <- nemeton::climat_nuages_annuels(s, mode = "anomalie" | "tendance_cumulee")
```

- `meta$status` ∈ `ok`, `hors_couverture`, `indisponible`,
  `donnees_insuffisantes` (+ `reason`, `message`). Aucune erreur réseau ne
  remonte : on affiche le statut, on ne `tryCatch` que par prudence.
- Sorties sur disque : séries `s$meta$fichiers$tx|rr|meta`, carte
  `b$meta$fichiers$raster|tendances|meta`. Le `SpatRaster` ne traverse pas le
  worker `future` : le worker renvoie les `meta`, la session relit les `.tif`.
- Coûts au **premier** calcul : **E-OBS = 8 Go** à télécharger depuis KNMI
  (tx 5,0 Go + rr 3,2 Go) dans le cache **machine** (`~/.local/share/nemeton/
  nemeton/cache/eobs/`, ou `NEMETON_CACHE_DIR`), puis mensualisation France
  une fois (~76 années) : **29,5 min mesurées** le 2026-10-18 ; tous les projets
  suivants : quelques secondes. Sur la machine de Pascal, ce cache est **déjà
  prêt** (essai réel du 2026-10-18).
  CHELSA ≈ 430 lectures distantes (≈ 1-3 min sur 25 km ; 11 s pour 2 ans
  mesurés). SAFRAN ≈ 335 requêtes (16 s pour 2 ans mesurés). Ensuite tout
  vient du cache projet.

## 2. Structure de l'onglet

Le `nav_panel(i18n$t("regen_map_context"))` actuel est **remplacé** (même
position, même icône `cloud-sun`) par un panneau `nav_panel(i18n$t("regen_climat"))`
contenant un `bslib::layout_sidebar()` dont le corps est un
`bslib::navset_card_underline(id = ns("climat_onglet"))` à quatre sous-onglets :

| `value` | Titre (clé i18n) | Contenu |
|---|---|---|
| `eobs` | `regen_climat_onglet_eobs` « Tendances E-OBS (0,1°) » | carte leaflet `ns("climat_carte_eobs")` |
| `chelsa` | `regen_climat_onglet_chelsa` « Tendances CHELSA (1 km) » | carte `ns("climat_carte_chelsa")` |
| `safran` | `regen_climat_onglet_safran` « Tendances SAFRAN (8 km) » | carte `ns("climat_carte_safran")` |
| `nuages` | `regen_climat_onglet_nuages` « Nuages annuels » | plotly `ns("climat_nuages")` + grille `ns("climat_nuages_grille")` |

**Sidebar droite commune** (`position = "right", open = "always", width = 260`,
comme aujourd'hui) :

1. `sliderInput(ns("climat_rayon_km"))` — 10 à 100 km, pas 5, défaut 25
   (remplace `buffer_km` pour ce panneau ; `buffer_km` reste ailleurs s'il sert).
2. `radioButtons(ns("climat_periode"))` — `complete` (« Complète »), `if49`
   (« 2006-2020 (L'IF n° 49) »), `libre` (« Libre ») ; si `libre`,
   `sliderInput(ns("climat_periode_libre"))` de 1950 à l'année courante − 1,
   `sep = ""`, défaut c(1991, 2020). Le cœur borne lui-même à la couverture de
   la source (`b$meta$periode` = période réellement utilisée : l'afficher).
   Masqués sur le sous-onglet `nuages`.
3. Sur `nuages` seulement : `radioButtons(ns("climat_nuages_source"))`
   (`chelsa`, `safran`, `eobs`) et `radioButtons(ns("climat_nuages_mode"))`
   (`anomalie` « Écart à 1981-2010 », `tendance_cumulee` « Tendance cumulée »).
   Utiliser `shiny::conditionalPanel(sprintf("input['%s'] == 'nuages'",
   ns("climat_onglet")), ...)` et son inverse.
4. `sliderInput(ns("climat_opacite"))` 0-1, défaut 0,8 (cartes seulement).
5. `bslib::input_task_button(ns("climat_calculer"), i18n$t("regen_climat_calculer"))`
   — lance le calcul du sous-onglet courant (§ 3).
6. `actionButton(ns("climat_recalculer"))` (outline-warning) — purge le cache
   **projet** du couple (source, rayon, période) courant et relance ; ne
   touche jamais le cache machine E-OBS.
7. Sous la carte : attribution `b$meta$attribution` (une ligne `text-muted
   small`, icône `c-circle` comme aujourd'hui) ; pour E-OBS ajouter la mention
   « usage non commercial » existante (`regen_eobs_attribution`).

## 3. Déclenchement et tâches (règle 9 : toast + bouton désactivé)

- **Chargement paresseux depuis le cache seulement** : à l'activation d'un
  sous-onglet ou au changement de rayon / période, si la carte de ce couple
  est en cache (`regeneration_climat_cached()`, § 4), l'afficher sans calcul.
  Sinon afficher un encart `regen_climat_a_calculer` (avec, pour E-OBS sans
  cache machine, l'avertissement `regen_climat_eobs_premier_usage` : « premier
  usage : téléchargement de 8 Go, puis quelques minutes de préparation ») et
  attendre le clic sur `climat_calculer`. **Jamais** de téléchargement E-OBS
  déclenché sans clic (aujourd'hui `context_task` part tout seul : ce n'est
  plus acceptable avec 8 Go).
- Deux `ExtendedTask` sur le modèle de `context_task` (worker persistant,
  `.release_worker_memory()`, `pkgload::load_all(dev_path)` en dev) :
  - `climat_task(units, project_path, source, rayon_km, periode)` →
    `run_regeneration_climat()` (§ 4) → `list(meta_series, meta_carte)` ;
  - `nuages_task(units, project_path, source, rayon_km, mode)` →
    `run_regeneration_nuages()` → `list(points, moyennes, limites, meta)`
    (data.frames, sérialisables).
  `bslib::bind_task_button(climat_task, "climat_calculer")` ; les deux tâches
  entrent dans `busy()` et `TASK_BTNS` (calculs lancés par l'utilisateur,
  contrairement à l'ancien `context_task`), et dans `observeEvent(list(...))`
  du `click_tick`. Garde `deny_if_busy()` et `deny_if_readonly()` en tête.
  Garde « autre projet » (`.est_projet_courant()`) comme `context_task`.
- **Progression** : `progress_callback` écrit
  `cache/regeneration/climat/climat_status.json` (`phase`, `annee`, `i`, `n`,
  `var`, `ts`), même canal que `.regen_eobs_progress_cb()` ; le module le lit
  chaque seconde et met à jour le toast :
  | `phase` | clé i18n | texte |
  |---|---|---|
  | `climat:telechargement` | `regen_climat_etape_telechargement` | « Téléchargement E-OBS (%s)… » (`var`) |
  | `climat:mensualisation` | `regen_climat_etape_mensualisation` | « Préparation E-OBS : année %d (%d/%d) » |
  | `climat:annee` | `regen_climat_etape_annee` | « %s : année %d (%d/%d) » (source) |
  | `climat:cache_hit` | `regen_climat_etape_cache` | « Lecture du cache » |
  | `climat:complete` | — | toast retiré |
- Statuts affichés (encart au-dessus de la carte, `uiOutput(ns("climat_statut"))`) :
  `hors_couverture` → `regen_climat_hors_couverture` (« SAFRAN ne couvre que
  la France métropolitaine »), `indisponible` → `regen_climat_indisponible` +
  `meta$message`, `donnees_insuffisantes` → `regen_climat_donnees_insuffisantes`
  + `meta$reason`.

## 4. Service (`R/service_regeneration.R`, présentation uniquement)

```r
run_regeneration_climat <- function(units, project_path, source, rayon_km, periode) {
  dir <- file.path(project_path, "cache", "regeneration")
  s <- nemeton::climat_ete_series(units, source = source, rayon_km = rayon_km,
         cache_dir = dir, progress_callback = .regen_climat_progress_cb(dir))
  b <- nemeton::climat_tendance_bivariee(s, periode = periode,
         cache_path = .regen_climat_paths(project_path, source, rayon_km, periode)$tif)
  list(series = s$meta, carte = b$meta)
}
```

- `.regen_climat_paths(project_path, source, rayon_km, periode)` :
  `cache/regeneration/climat/carte_<source>_r<rayon>_<p>.tif` avec `<p>` =
  `complete`, `if49` ou `AAAA-AAAA` ; le cœur écrit à côté
  `_tendances.tif` et `.meta.json`.
- `regeneration_climat_cached(...)` : relit `.tif` + `.meta.json` ; **cache
  périmé** si `meta$palette$ncol != 10` ou `meta$statistique !=
  "variation_totale"`.
- `run_regeneration_nuages(units, project_path, source, rayon_km, mode)` :
  `climat_ete_series()` (cache) puis `climat_nuages_annuels()` ; mémoïser le
  résultat en `.rds` à côté (`nuages_<source>_r<rayon>_<mode>.rds`).
- Pour le clic : la série relue est
  `list(tx = terra::rast(f$tx), rr = terra::rast(f$rr), meta = <json>)`.

## 5. Rendu des cartes

- Patron actuel conservé : fond stable `renderLeaflet` + `leafletProxy`,
  map-pane `contexteRaster` (zIndex 250), groupes OSM / Satellite, UGF.
- Raster : `terra::round(r)` puis `leaflet::addRasterImage(r, colors =
  leaflet::colorFactor(meta$palette$colors, domain = meta$palette$classes,
  na.color = "transparent"), opacity = op, project = TRUE, method = "ngb")`.
  **Jamais bilinéaire.** Grille native : E-OBS / CHELSA en EPSG:4326, SAFRAN en
  EPSG:2154 ; aucune autre reprojection. Les mailles du bord restent entières.
- **Cercle** : le cœur l'écrit avec les séries
  (`s$meta$fichiers$cercle`, GeoPackage EPSG:4326) ; la session le relit
  (`sf::st_read()`) et le trace par-dessus le raster : trait noir 1,5 px, sans
  remplissage, groupe `Cercle`. Ne pas le recalculer côté app (centroïde et
  tampon métrique = logique du cœur).
- **Légende** : réutiliser `bivariate_legend_html()` tel quel (sa convention
  `classe = (rang_tx - 1) * n + rang_rr`, tx en lignes, rr en colonnes, est
  celle du cœur) avec
  `palette = setNames(meta$palette$colors, meta$palette$classes)`,
  `ncol = meta$palette$ncol` (10), `zero = meta$palette$zero`,
  `x_range = meta$bornes$precip`, `y_range = meta$bornes$tmax`,
  `axis_x = i18n$t("regen_climat_axe_precip")` (« Δ précipitations (mm) »),
  `axis_y = i18n$t("regen_climat_axe_tmax")` (« Δ T°max (°C) »),
  `title = i18n$t("regen_climat_legende_titre")` (« Tendances estivales mai-sept. »),
  `subtitle = sprintf("%d-%d · %s", meta$periode[1], meta$periode[2], <mode>)`
  avec `<mode>` = `regen_climat_bornes_if49` / `_france` / `_emprise`. Si
  `meta$bornes$reason == "france_eobs_cache_missing"`, ajouter sous la légende
  `regen_climat_bornes_relatives` (« Couleurs relatives au cercle : préparer
  d'abord E-OBS pour des couleurs comparables entre projets »). À 22 px/cellule
  la grille 10 × 10 fait 220 px : passer `px` à 14 quand `n >= 10` dans
  `bivariate_legend_html()`.
- Infobulle au survol d'une maille (facultatif) : valeurs de
  `_tendances.tif` (Δ T°max, Δ précipitations).

## 6. Clic sur une maille (spec 036 conservée)

Sur les trois sous-onglets cartes, le panneau des 4 graphes reste, alimenté
par la **série du sous-onglet** (et non plus par les `.nc` CDS du projet) :

- graphes 1-2 : `nemeton::eobs_summer_series(serie$tx|rr, pt)` +
  `nemeton::eobs_trend_fit()` — les séries du cœur ont une couche par année
  nommée par l'année, `eobs_summer_series()` les lit telles quelles (vérifié
  dans le code cœur). Attention : `eobs_trend_fit()` exprime la pente **par
  décennie**, la carte une **variation totale** ; libeller les deux unités ;
- graphe 3 : distribution des valeurs de `_tendances.tif` sur le cercle +
  valeur de la maille cliquée (couche `tendance_tmax` puis `tendance_precip`) ;
- graphe 4 (ombrothermique) : inchangé, seulement si les `.nc` E-OBS du
  projet existent (sinon message actuel).

## 7. Nuages annuels (plotly)

- Graphe principal : `plotly::plot_ly(points, x = ~x, y = ~y, frame = ~annee,
  type = "scattergl", mode = "markers", marker = list(size = 4, opacity = 0.3,
  color = "#A3195B"))` + trace `moyennes` (point blanc bordé de noir, `frame =
  ~annee`), lignes x = 0 et y = 0 grises, axes fixés à `limites$x` / `limites$y`
  (`range`, sinon plotly réajuste à chaque image), `animation_opts(frame = 600,
  redraw = FALSE)`, `animation_slider(currentvalue = list(prefix = ""))`.
- Grille des années : `plotly::subplot()` de petits graphes (6 colonnes,
  axes partagés, `limites` communes), ou `ggplot2::facet_wrap(~annee)` passé
  par `ggplotly()` — au choix de l'app ; pas de PNG ni de GIF.
- Titres d'axes : anomalie → `regen_climat_nuages_x_anomalie` (« Écart des
  précipitations d'été à 1981-2010 (mm) ») / `_y_anomalie` ; tendance
  cumulée → `_x_tendance` (« Tendance des précipitations d'été depuis %d
  (mm) ») / `_y_tendance`.
- Légende : source (`meta$attribution`), `n_cellules`, « jusqu'à 4 000 mailles
  tirées par année ».

## 8. Retraits et invalidations

- `context_task`, `run_regeneration_context_raster()`, les vues `tx` / `rr` /
  `bivariate`, `context_view`, `fetch_eobs_rr` / `fetch_eobs_tg` **pour ce
  panneau** : retirés de l'UI de la carte de contexte. `fetch_eobs_tg` reste
  utile au graphe ombrothermique : le garder dans la sidebar de l'onglet E-OBS
  si l'app veut conserver le graphe 4. `eobs_task` (années de référence) n'est
  pas concerné.
- `.REGEN_BIVARIATE_N` (5) et `.regen_bivariate_cache_current()` ne servent
  plus à cette carte ; les anciens fichiers `context_*.tif` peuvent être
  ignorés (pas besoin de migration : ce sont des caches).
- Le cœur garde `eobs_downscale*()` et `tendances_estivales_eobs()` (autres
  usages) ; leur dépréciation sera proposée à Pascal séparément.

## 9. i18n (convention NMT, FR/EN)

Nouvelles clés (préfixe `regen_climat_`) : `regen_climat`, `_onglet_eobs`,
`_onglet_chelsa`, `_onglet_safran`, `_onglet_nuages`, `_rayon`, `_periode`,
`_periode_complete`, `_periode_if49`, `_periode_libre`, `_nuages_source`,
`_nuages_mode`, `_mode_anomalie`, `_mode_tendance`, `_opacite`, `_calculer`,
`_recalculer`, `_a_calculer`, `_eobs_premier_usage`, `_etape_telechargement`,
`_etape_mensualisation`, `_etape_annee`, `_etape_cache`, `_hors_couverture`,
`_indisponible`, `_donnees_insuffisantes`, `_axe_precip`, `_axe_tmax`,
`_legende_titre`, `_bornes_if49`, `_bornes_france`, `_bornes_emprise`,
`_bornes_relatives`, `_nuages_x_anomalie`, `_nuages_y_anomalie`,
`_nuages_x_tendance`, `_nuages_y_tendance`. (Toutes ≤ 30 caractères.)

## 10. Tests (`tests/testthat/`)

- `testServer(mod_regeneration_server)` avec `local_mocked_bindings` de
  `nemeton::climat_ete_series` / `climat_tendance_bivariee` /
  `climat_nuages_annuels` (petits rasters synthétiques) : cache absent →
  encart `a_calculer` sans tâche lancée ; clic → tâche lancée, bouton busy ;
  `hors_couverture` → encart ; cache `ncol = 5` → considéré périmé.
- `bivariate_legend_html(ncol = 10)` : 100 cellules, pointillés aux positions
  `zero`.
- Aucun test réseau.
