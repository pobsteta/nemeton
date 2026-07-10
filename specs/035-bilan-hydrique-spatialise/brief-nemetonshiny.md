# Brief `nemetonshiny` — spec 035 : bilan hydrique spatialisé + restauration de l'onglet reGénération

- **Date** : 2026-07-10
- **Cœur requis** : `nemeton (>= 0.147.0)` — relever le plancher `Imports`
  (actuellement `>= 0.146.2`).
- **Repo cible** : `nemetonshiny` (app). **Aucun changement cœur.**
- **Fichiers touchés** : `R/service_regeneration.R`, `R/mod_regeneration.R`,
  `R/utils_i18n.R`, `DESCRIPTION`.

Deux chantiers indépendants, livrables ensemble parce qu'ils touchent les mêmes
deux fichiers. **B1** rend le bilan hydrique réellement spatialisé. **B2** restaure
les résultats de reGénération à l'ouverture d'un projet récent.

---

## B1 — Brancher `ewm` par UGF et `lai_max` par UGF

### Le problème

`regen_bilan_hydrique()` renvoyait la même valeur pour toutes les UGF. Sur le
projet réel `20260701_204501_ltcp` (30 UGF, `cache/regeneration/biljou.gpkg`) :
`njstress` = 142,5 j et `deb_stress` = 122 **partout** ; `istress` et `rew_min`
ne prennent que 2 valeurs.

BILJOU n'a aucun terme spatial : `biljou_run_grid()` ne recopie `lon`/`lat` qu'en
métadonnées, et `biljou_run()` est une fonction pure de `(meteo, soil, lai_max,
forest_type, budburst, leaf_fall)`. Or l'app passe un **sol uniforme**, un
**`lai_max` scalaire**, et le forçage SAFRAN a une maille de **8 km** (les 30
centroïdes tombent dans 2 mailles, d'où les 2 valeurs distinctes).

Le cœur v0.147.0 (spec 035) livre les deux briques manquantes. Il reste à les
appeler.

### B1.a — Le PAI calculé n'est jamais consommé par BILJOU

`R/service_regeneration.R`, autour de la ligne 626 :

```r
lai_max <- cfg$lai_max
if (is.null(lai_max) && is.null(grid)) {          # <-- le garde-fou
  lai_r <- .regen_lai_fallback(res, out_dir, cfg)
  ...
}
```

Le repli LAI satellite ne se déclenche **que si aucune grille LiDAR n'est
résolue**. Quand le LiDAR HD est présent — c'est-à-dire précisément quand
`pai_depuis_nuage()` a tourné et écrit `cache/regeneration/pai.tif` — `grid` est
non-`NULL`, la branche est sautée, `lai_max` reste `NULL`, et le cœur retombe sur
son défaut par type de peuplement (5 pour du feuillu, 4,5 pour du résineux).

Autrement dit : le PAI est calculé (57 min sur le run réel), caché, **et jamais
utilisé par le bilan hydrique**. Il ne sert qu'à `regen_sensibilite()` / microclimf.

**Changement demandé.** Priorité au PAI LiDAR, repli satellite inchangé :

```r
lai_max <- cfg$lai_max
if (is.null(lai_max)) {
  pai_tif <- file.path(out_dir, "pai.tif")            # même chemin que le cache PAI
  if (file.exists(pai_tif)) {
    lai_max <- tryCatch(nemeton::lai_max_depuis_pai(res, pai_tif),
                        error = function(e) NULL)
    if (!is.null(lai_max)) {
      canopy <- "lidar"
      attr(res, "lai_source") <- "pai_lidar"
    }
  }
  if (is.null(lai_max) && is.null(grid)) {            # repli satellite : inchangé
    lai_r <- .regen_lai_fallback(res, out_dir, cfg)
    ...
  }
}
```

### B1.b — `.regen_lai_per_unit()` prend la moyenne, pas le plateau

`R/service_regeneration.R:773` :

```r
.regen_lai_per_unit <- function(units, lai_r) {
  ex <- terra::extract(lai_r, v, fun = mean, na.rm = TRUE, ID = FALSE)   # <-- mean
  as.numeric(ex[[1]])
}
```

`biljouR::biljou_lai()` traite `lai_max` comme le **plateau** de la phénologie
(résineux : constant toute l'année ; feuillu : le sommet plat du trapèze entre
`budburst + ramp` et `leaf_fall - ramp`). Une moyenne zonale le **sous-estime**,
d'autant plus que l'UGF contient des trouées.

**Changement demandé.** Remplacer le corps par un appel au cœur, qui prend un
percentile haut (P90 par défaut) après exclusion des pixels non-canopée
(`min_pai = 0.1`) :

```r
.regen_lai_per_unit <- function(units, lai_r) {
  nemeton::lai_max_depuis_pai(units, lai_r)
}
```

La fonction accepte un `SpatRaster` **ou** un chemin, donc elle sert aux deux
branches (PAI LiDAR et LAI satellite).

### B1.c — Le sol est uniforme

`R/service_regeneration.R:643` :

```r
sol <- nemeton::build_biljou_soil(res, ewm = cfg$ewm)
```

`build_biljou_soil()` retourne **un seul** objet `biljou_soil`, partagé par tous
les points. Le champ « Eau extractible (mm) » de la sidebar
(`mod_regeneration.R:151`, `input$ewm`) est donc une constante pour tout le massif.

**Changement demandé.** Passer en mode SoilGrids quand l'utilisateur n'a pas forcé
d'`ewm` :

```r
sol <- if (is.null(cfg$ewm)) {
  nemeton::build_biljou_soil(res, source = "soilgrids",
                             rooting_depth_cm = cfg$rooting_depth_cm %||% 100,
                             progress_callback = on_prog)
} else {
  nemeton::build_biljou_soil(res, ewm = cfg$ewm)      # override manuel : uniforme
}
```

`build_biljou_soil(source = "soilgrids")` retourne une **liste nommée par id
d'UGF** d'objets `biljou_soil`, dérivée de SoilGrids 250 m via la fonction de
pédotransfert de Saxton & Rawls. Elle dégrade proprement (avertissement + sol
uniforme) si `files.isric.org` est injoignable. `regen_bilan_hydrique()` la
consomme telle quelle.

### B1.d — UI

- Le champ « Eau extractible (mm) » devient un **override optionnel**. Vidé
  (`na_null` → `NULL`), il déclenche SoilGrids. Ajuster le libellé/`placeholder` et
  l'infobulle : *« Laisser vide pour dériver la réserve utile par UGF depuis
  SoilGrids (250 m). »*
- Nouveau `numericInput("rooting_depth_cm")`, défaut 100, plage 20–200.
- Le badge « Canopée » gagne une valeur `pai_lidar` (l'attribut `lai_source` est
  déjà posé sur `res`) — aujourd'hui seul `prosail_s2` existe.
- Nouvelles clés i18n FR/EN dans `utils_i18n.R` : `regen_ewm_hint`,
  `regen_rooting_depth`, `regen_rooting_depth_hint`, `regen_canopy_pai_lidar`,
  `regen_phase_ewm` (« Réserve utile (SoilGrids) »).

### B1.e — Phases

`ewm_depuis_soilgrids()` émet un `progress_callback` au patron monitoring :
`list(current = "ewm:layer", interval = , i = , n = )` par horizon de profondeur,
puis `"ewm:complete"` (ou `"ewm:unavailable"`). Les câbler sur le canal
`engine_status.json` existant, comme les phases microclimf.

### Piège à ne pas reproduire

**Ne jamais passer un vecteur numérique** en `lai_max` ou `sol` à
`regen_bilan_hydrique()` en croyant qu'il sera indexé par point.
`biljou_run_grid()` n'indexe que les **listes** :

```r
if (is.list(x) && !is.data.frame(x) && !inherits(x, "biljou_soil"))
  return(function(id) x[[as.character(id)]])
function(id) x     # sinon : la valeur ENTIÈRE, pour chaque point
```

Un vecteur tombe dans la seconde branche. Sur résineux, `biljou_lai()` fait
`rep(lai_max, ndays)` → série de `n × ndays` valeurs, et `biljou_run()` lit
`lai_series[t]` → **le LAI des UGF défile jour après jour**, sans erreur ni
warning. Corruption silencieuse.

Le cœur v0.147.0 protège l'app : `regen_bilan_hydrique()` convertit tout vecteur
de longueur `nrow(units)` en liste nommée par id, et **refuse** toute autre
longueur. Un `lai_max` issu de `lai_max_depuis_pai()` (vecteur de longueur
`nrow(units)`) est donc sûr. Mais ne construisez pas la liste à la main côté app :
laissez le cœur le faire.

### Critère d'acceptation B1

Sur le projet `20260701_204501_ltcp`, après un run avec cache PAI présent :

- `biljou.gpkg` a **plus de 2 valeurs distinctes** de `njstress` sur 30 UGF ;
- `attr(res, "lai_source")` vaut `"pai_lidar"` ;
- forcer `input$ewm = 150` reproduit exactement le comportement v0.146.x
  (rétrocompatibilité).

---

## B2 — Restaurer la reGénération à l'ouverture d'un projet récent

### Le problème

Quand on rouvre un projet récent, l'onglet reGénération affiche les contours
d'UGF **sans choroplèthe, sans indice de priorité, sans table**. Il faut cliquer
« Lancer l'analyse » pour les revoir.

`rv$result` est la variable réactive dont dépendent le choroplèthe
(`mod_regeneration.R:714`) et la table. Elle est initialisée à `NULL`
(ligne 239) et n'est écrite qu'à **deux** endroits : ligne 402 (gestionnaire
`input$run`) et ligne 573 (fin de `engine_task`). Le module a sept observateurs,
tous accrochés à un `input$*` ou à un statut de tâche ; **aucun n'écoute
`app_state$current_project`**.

La carte de contexte E-OBS échappe à la règle : c'est un `renderLeaflet` qui
appelle directement `load_regeneration_precomputed()` (ligne 756), donc elle se
réaffiche seule. C'est la preuve que le cache disque suffit.

### Le coût du rechargement est nul

`input$run` fait déjà :

```r
precomputed <- load_regeneration_precomputed(project_path)
out <- run_regeneration(units, cfg = cfg, precomputed = precomputed)
```

`load_regeneration_precomputed()` lit `sensibilite.gpkg`, `biljou.gpkg`,
`micro*.tif`, `eobs_*.tif` sous `cache/regeneration/` et n'y met que les entrées
présentes. `run_regeneration()` consomme ces sorties en **fast-path** : aucun
moteur (microclimf, biljouR, lasR) n'est relancé. Ce n'est pas un recalcul, c'est
un rechargement — il faut juste le déclencher.

### Changement demandé

Ajouter dans `mod_regeneration.R` un observateur sur le projet courant, qui
restaure **uniquement si le cache contient de quoi le faire** :

```r
shiny::observeEvent(app_state$current_project, {
  project_path <- tryCatch(app_state$current_project$path, error = function(e) NULL)
  if (is.null(project_path)) return()
  rv$result <- NULL                                  # purge du projet précédent
  app_state$regeneration_result <- NULL

  pc <- load_regeneration_precomputed(project_path)
  # Ne restaurer que si une sortie de moteur existe : `dem`/`eobs_*` seuls ne
  # produisent pas d'indice et un run à vide poserait des warnings trompeurs.
  if (is.null(pc$biljou) && is.null(pc$sensibilite)) return()

  units <- units_sf()
  if (is.null(units)) return()

  # cfg minimal : surtout, fournir les années pour NE PAS déclencher
  # microclimate_detect_years() (cf. piège 5 ci-dessous).
  cfg <- list(
    year_moyenne  = na_null(input$year_moyenne),
    year_canicule = na_null(input$year_canicule),
    forest_type   = input$forest_type %||% "feuillu",
    lai_max       = na_null(input$lai_max)
  )
  res <- tryCatch(run_regeneration(units, cfg = cfg, precomputed = pc),
                  error = function(e) NULL)
  if (!is.null(res)) {
    rv$result <- res$units
    rv$years  <- res$years                 # `run_regeneration()` renvoie aussi `years`
    rv$warnings <- character(0)            # restauration != analyse : cf. piège 5
    app_state$regeneration_result <- res$units
  }
}, ignoreNULL = TRUE, ignoreInit = FALSE)
```

Points d'attention :

1. **Purger d'abord.** Sans le `rv$result <- NULL`, passer d'un projet analysé à
   un projet vierge laisserait le choroplèthe du précédent à l'écran.
2. **Le garde `is.null(pc$biljou) && is.null(pc$sensibilite)`** évite un
   `run_regeneration()` à vide qui empilerait les avertissements
   `regen_guard_hydrique` / `regen_guard_sensibilite` dès l'ouverture.
3. **Aucun moteur ne démarre.** `run_regeneration()` *appelle* bien
   `regen_sensibilite()` et `regen_bilan_hydrique()`, mais uniquement dans les
   branches `if (!is.null(pc$sensibilite))` / `if (!is.null(pc$biljou))`, et
   toujours avec `precomputed =`. Le cœur retourne alors par le fast-path pur
   (`.regen_attach_precomputed()`, simple rattachement de colonnes) sans jamais
   charger microclimf, biljouR ni lasR.
4. **`units_sf()` peut être `NULL`** à la première invalidation (le projet est
   posé avant les géométries). Si ça se produit en pratique, déclencher plutôt sur
   un `reactive({ list(app_state$current_project, units_sf()) })` et sortir tant que
   `units` est `NULL`.
5. **Piège — la détection d'années.** `run_regeneration()` (ligne 93) fait :

   ```r
   years <- if (!is.null(cfg$year_moyenne) && !is.null(cfg$year_canicule)) { ... }
            else tryCatch(nemeton::microclimate_detect_years(eobs = pc$eobs, ...), ...)
   ```

   Avec un `cfg = list()` vide, la branche `else` part, et
   `microclimate_detect_years()` **abort immédiatement** quand `eobs` est `NULL`
   (« needs an E-OBS summer series »). Pas d'appel réseau, mais le `tryCatch`
   empile un avertissement `detect_years: ...` visible dès l'ouverture du projet.

   Pire : `load_regeneration_precomputed()` peuple `eobs_tx` et `eobs_rr`, **jamais
   `eobs`** (cf. `service_regeneration.R:291-300`). Donc `pc$eobs` est *toujours*
   `NULL`, et cette branche échoue systématiquement — y compris sur le chemin
   `input$run` actuel, dès que l'utilisateur n'a pas fixé les deux années.
   **C'est un bug latent, indépendant de ce brief** : soit `pc` doit exposer un
   `eobs` dérivé de `eobs_tx`, soit l'appel doit passer `eobs = pc$eobs_tx`. À
   traiter à part ; ici, on le contourne en fournissant les années et en ne
   remontant pas les avertissements d'une restauration.
6. **Alimenter `app_state$regeneration_result`** : `mod_synthesis.R:1036` le
   consomme (`regen_units =`) pour la perspective IA. Aujourd'hui il est absent
   tant qu'on n'a pas cliqué, donc la synthèse d'un projet rouvert ignore
   silencieusement la reGénération.

### Persistance en base : constat, hors périmètre

`db_save_regeneration()` (`service_db.R:545`, appelé depuis `input$persist_db`)
insère dans `nemeton.regeneration_states` avec versionnement. **Aucun `SELECT` sur
`payload` n'existe dans le repo.** La table est en écriture seule : les états
s'accumulent et ne sont jamais relus.

Ce n'est pas bloquant — le cache disque suffit à la restauration proposée ci-dessus
— mais soit la table sert (et il manque un `db_load_regeneration()`), soit elle ne
sert pas (et il faut assumer que c'est un journal d'archive). À trancher
séparément ; ne rien changer dans ce brief.

### Critère d'acceptation B2

- Ouvrir un projet récent dont `cache/regeneration/biljou.gpkg` existe →
  choroplèthe, indice de priorité et table s'affichent **sans clic**.
- Ouvrir un projet sans cache reGénération → contours d'UGF seuls, **aucun
  avertissement** (en particulier pas de `detect_years:`, cf. piège 5).
- Passer d'un projet analysé à un projet vierge → l'ancien choroplèthe disparaît.
- Aucun moteur ne démarre à l'ouverture (vérifier qu'aucun `engine_status.json`
  n'est écrit).
- La perspective IA d'un projet rouvert reçoit bien `regen_units`.

---

## Ordre de livraison suggéré

1. **B2** d'abord : indépendant du cœur v0.147.0, testable tout de suite, et il
   rend B1 beaucoup plus facile à valider (on voit le résultat sans re-cliquer).
2. **B1** ensuite, après avoir relevé le plancher `Imports: nemeton (>= 0.147.0)`.

Bump app : `feat` → mineur (`v0.101.0`), les deux changements étant additifs.

## Référence cœur

- `specs/035-bilan-hydrique-spatialise/spec.md` — décisions D1 (le TWI ne dérive
  pas l'`ewm`), D3 (PTF Saxton & Rawls), D5 (P90 et non moyenne), D6 (listes
  nommées, jamais de vecteurs).
- `nemeton` v0.147.0 : `awc_saxton_rawls()`, `ewm_depuis_soilgrids()`,
  `lai_max_depuis_pai()`, `build_biljou_soil(source =)`.
