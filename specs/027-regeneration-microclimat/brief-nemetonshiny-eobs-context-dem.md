# Brief nemetonshiny — Carte « Contexte régional E-OBS » en raster (débloquée)

- **Repo cible : `nemetonshiny` (app).** Session dev dédiée app.
- **Dépend de `nemeton` (cœur) ≥ v0.152.0.** Répond au brief app d'entrée
  `brief-nemeton-eobs-downscaling-dem`.
- **Statut :** cœur **livré et validé en réel**. L'app peut brancher le rendu
  raster en une passe — **aucune logique métier à écrire**.

## 0. TL;DR

`eobs_downscale()` renvoyait `status = "insufficient_data"` (`n_points = 1`) sur
projet réel parce que le MNT fourni était à l'échelle **parcelle** (~4–5 km) alors
que le KED a besoin de mailles E-OBS (~11 km) sur tout le **buffer 25 km**. Corrigé
côté cœur : **`dem` est désormais optionnel** et un MNT de contexte grossier est
**auto-sourcé** sur le buffer (WMS IGN). Résultat réel : `n_points` **1 → 33**,
`status = "ok"`. **Le contrat `list(raster, meta)` est inchangé** — l'app rend le
raster dès `status == "ok"`.

## 1. Le seul changement d'appel : ne plus passer le MNT parcellaire

Aujourd'hui l'app passe le MNT projet (`.resolve_regen_dem` : `lidar_mnt_mosaic`
0,5 m / 5 km ou `dem.tif` BD ALTI ~22 m / 4 km). **C'est ce MNT qui bloquait.**

**Recommandé — laisser le cœur auto-sourcer** :

```r
res <- nemeton::eobs_downscale(
  var        = "tx",
  eobs       = tx,                 # load_eobs_source(aoi = st_buffer(units, 25000), ...)
  dem        = NULL,               # <-- ne PAS passer le MNT parcellaire
  aoi        = units,
  engine     = "ked",
  statistic  = "trend",
  buffer_m   = 25000
)
```

Avec `dem = NULL`, `eobs_downscale()` télécharge une élévation **grossière** sur
`st_buffer(aoi, 25 km)` depuis le **WMS IGN Géoplateforme**
(`ELEVATION.ELEVATIONGRIDCOVERAGE`, France, **sans auth**), à `context_res_m`
(défaut **250 m** — un contexte régional n'a pas besoin de plus). Le MNT parcellaire
reste réservé à microclimf (parcelle), il n'a rien à faire dans le contexte
régional.

> Variante : on **peut** continuer à passer `dem = <MNT projet>`. S'il est trop
> petit pour couvrir le buffer, le cœur **auto-source quand même** (avec un
> avertissement) et met `meta$dem_source = "autoscaled_small_dem"`. Mais autant
> passer `NULL` directement : plus clair, pas d'objet inutile.

## 2. Rendu Leaflet dès `status == "ok"` (le vrai livrable app)

```r
if (identical(res$meta$status, "ok") && !is.null(res$raster)) {
  p <- res$meta$palette                     # low / high / sense = "hot_unfavorable"
  pal <- leaflet::colorNumeric(
    "RdYlBu", domain = c(p$low, p$high), reverse = TRUE, na.color = "transparent")
  # sense = "hot_unfavorable" -> chaud = rouge (reverse sur RdYlBu). Cohérent avec
  # la règle rouge = critique de l'app.
  leafletProxy("map") |>
    clearGroup("contexte_eobs") |>
    addRasterImage(res$raster, colors = pal,
                   opacity = input$context_opacity, group = "contexte_eobs") |>
    addLegend(pal = pal, values = c(p$low, p$high),
              title = res$meta$value_label, group = "contexte_eobs")
}
```

- Le raster est **mono-couche, dans le CRS du contexte** (2154 en auto-source ;
  `addRasterImage` reprojette en 3857 tout seul).
- Le **curseur d'opacité** (déjà en place) pilote enfin un vrai raster.
- `res$meta$value_label` = « Tendance T°max estivale » / « T°max estivale moyenne »
  selon `statistic`. `res$meta$unit` = `"°C/decade"` / `"°C"`.

## 3. Gestion des statuts (bandeau lisible)

`meta$status` ∈ `ok` / `out_of_scope` / `insufficient_data`. En dégradé,
`meta$reason` est une **clé i18n** à afficher :

| `meta$reason` | Sens | Message utilisateur suggéré |
|---|---|---|
| `eobs_downscale_no_dem` | aucun MNT et WMS IGN indisponible | « Élévation de contexte indisponible (service IGN). Réessayez plus tard. » |
| `eobs_downscale_dem_too_small` | MNT fourni trop petit **et** WMS KO | « MNT de contexte indisponible ; passez `dem = NULL`. » |
| `eobs_downscale_too_few_cells` | trop peu de mailles E-OBS dans le buffer | « Zone trop petite pour un contexte régional E-OBS (élargissez le buffer). » |
| `eobs_downscale_rr_out_of_scope` | `var = "rr"` non couvert (v1) | « Contexte pluie non disponible (v1). » |

Ajouter ces 4 clés (+ `value_label`) dans `utils_i18n.R` FR/EN.

## 4. Observabilité (facultatif mais utile)

`meta$dem_source` ∈ `"provided"` / `"autoscaled"` / `"autoscaled_small_dem"` : d'où
vient l'élévation. `meta$n_points` : nb de mailles E-OBS utilisées ;
`meta$method` : `"ked"` (krigeage) ou `"trend_only"` (dérive seule, si gstat
absent). À exposer en info de debug / tooltip « qualité », pas en bandeau
principal.

## 5. Cache (recommandé)

L'auto-source = 1 requête WMS (~200 Ko) + 1 krigeage. Peu coûteux mais réseau. Si
l'onglet recalcule souvent, passer `cache_path = "cache/regeneration/eobs_tx_<emprise>_<stat>.tif"`
à `eobs_downscale()` : le raster est écrit puis rechargeable via `terra::rast()`.
Clé = emprise UGF + var + statistic (+ années E-OBS).

## 6. Ce qu'il ne faut PAS faire

- **Ne pas** reprojeter/aligner `eobs` ou le MNT à la main : le cœur gère le CRS
  (E-OBS sans CRS → supposé 4326 ; MNT reprojeté au besoin).
- **Ne pas** viser un MNT fin sur 25 km (plusieurs Go) : inutile, le cœur agrège.
- **Ne pas** confondre ce contexte régional (NDP 0/1, plein champ) avec le
  microclimat sous couvert de `microclimate_run()` (parcelle, NDP 2+).

## 7. 2ᵉ couche : précipitations `var = "rr"` (cœur ≥ v0.153.0)

`eobs_downscale(var = "rr")` **n'est plus `out_of_scope`** — même appel que `tx`,
seul `var` change :

```r
rr_res <- nemeton::eobs_downscale(
  var = "rr", eobs = rr, dem = NULL, aoi = units,
  statistic = "trend", buffer_m = 25000)          # rr force KED (meteoland = T° seule)
```

Spécificités à respecter au rendu :
- `meta$palette$sense == "dry_unfavorable"` → **BAS = rouge** (une tendance
  négative = assèchement = défavorable). Donc `colorNumeric(..., reverse = FALSE)`
  (l'inverse de `tx` qui est `hot_unfavorable`, `reverse = TRUE`). **Piloter la
  palette par `meta$palette$sense`**, pas en dur.
- `meta$unit == "mm/decade"`, `meta$value_label == "Tendance précipitations estivales"`.
- `meta$reliability == "low"` → à surfacer en tooltip « fiabilité » (le downscaling
  pluie est bruité/orographique — contexte régional seulement).
- **Ré-exposer le bouton de téléchargement rr** (~800 Mo, flux `regen_fetch_eobs_rr`
  déjà côté app) : le contexte `tx` seul ne le déclenchait plus.

**Sélecteur de couche** sur la carte contexte : radio/onglets « Tendance T°max » /
« Tendance précipitations » — 2 rasters mono-couche, un seul visible via le
contrôle de couches Leaflet. Même code de rendu que §2, palette pilotée par
`sense`.

## 8. 3ᵉ vue : carte BIVARIÉE fine (la figure « L'IF n°49 » à l'échelle UGF)

`eobs_downscale_bivariate(tx, rr, …)` croise les deux tendances **downscalées** en
un raster de classes **1-25** (grille **5×5**, couleurs échantillonnées sur la
figure « L'IF n°49 » — cœur ≥ **v0.154.0** ; c'était 1-9 en v0.153.x), mais **à la
résolution du contexte** (pas le semis E-OBS grossier de `tendances_estivales_eobs`).
La classification est en **bornes absolues fixes ancrées sur 0** (comme L'IF, pas
en quantiles) : les couleurs sont comparables d'un projet à l'autre. Un massif
uniformément chaud & sec ressort donc quasi unicolore — c'est voulu.

```r
biv <- nemeton::eobs_downscale_bivariate(
  tx = tx, rr = rr, dem = NULL, aoi = units, buffer_m = 25000,
  cache_path = "cache/regeneration/context_bivariate.tif")

if (identical(biv$meta$status, "ok")) {
  pal <- biv$meta$palette                 # classes 1:25, colors (25 hex), labels (25 FR), ncol = 5
  cmap <- leaflet::colorFactor(pal$colors, domain = pal$classes, na.color = "transparent")
  leafletProxy("map") |>
    clearGroup("contexte_bivariee") |>
    addRasterImage(biv$raster, colors = cmap, opacity = input$context_opacity,
                   group = "contexte_bivariee")
}
```

- Le raster est **entier 1-25** (`classe_bivariee`) : rendu en **`colorFactor`**
  (25 couleurs/libellés fournis dans `meta$palette`), pas `colorNumeric`. **Ne pas
  câbler `addLegend(colors=…)` en liste verticale de 25 entrées** : illisible.
- **Légende = carré bivarié 5×5** comme la figure de référence. `pal$ncol` (= 5)
  donne le côté ; l'ordre est `(classe_tmax-1)*ncol + classe_precip`, donc
  `matrix(pal$colors, nrow = ncol, byrow = TRUE)` a **T°max en lignes (bas→haut :
  frais→chaud)** et **précip en colonnes (gauche→droite : sec→humide)**. Rends-la
  en petit `<table>`/HTML 5×5 avec les deux axes légendés (« Tendance T°max » à la
  verticale, « Tendance précipitations » à l'horizontale). Chaud & sec = coin
  haut-gauche = rouge ; frais & humide = bas-droite = violet.
- **Pointillés blancs 0/0** (comme la figure) : `pal$zero` = `list(tmax, precip)`,
  chacun une **fraction [0,1]** (ou `NA` si 0 est hors de l'étendue des tendances
  → ne pas tracer). Sur le carré de côté `S` px (origine coin **bas-gauche**) :
  - ligne **horizontale** (tendance T°max nulle) à `y = (1 - pal$zero$tmax) * S`
    depuis le haut, i.e. `pal$zero$tmax` mesuré depuis le bas ;
  - ligne **verticale** (tendance précip nulle) à `x = pal$zero$precip * S` depuis
    la gauche.
  En CSS/SVG : un trait `stroke:#fff; stroke-dasharray:3 2` par-dessus la grille.
  Ces positions sont **data-dépendantes** (quintiles) : toujours lire `pal$zero`,
  ne pas figer à 40 %/60 %.
- `biv$meta$breaks` (bornes absolues tmax/precip utilisées, **4 bornes chacun**),
  `biv$meta$tx` / `biv$meta$rr` (métas composantes) pour debug/tooltip.
  `reliability = "low"`.
- **La palette est pilotée par les données** : lis toujours `pal$colors`/`labels`/
  `ncol`, ne code pas les 25 couleurs en dur côté app (elles peuvent réévoluer).
- **Une seule carte** débloque le besoin : proposer le **3ᵉ choix** dans le
  sélecteur (« Bivariée T°max × précip ») à côté des deux couches simples.

## 9. Checklist app

- [ ] Couche tx : `eobs_downscale(var="tx", dem=NULL, …)` + `addRasterImage`/`colorNumeric(reverse=TRUE)` (sense `hot_unfavorable`).
- [ ] Couche rr : `eobs_downscale(var="rr", dem=NULL, …)` + palette pilotée par `sense="dry_unfavorable"` (reverse=FALSE) ; ré-exposer le bouton download rr.
- [ ] Carte bivariée : `eobs_downscale_bivariate(tx, rr, …)` + `colorFactor(meta$palette$colors)` + légende 9 classes.
- [ ] Sélecteur 3 vues (T°max / précip / bivariée), un raster visible à la fois, curseur d'opacité commun.
- [ ] Bandeau statut : mapper `meta$reason` (clés i18n FR/EN + `value_label`). `eobs_downscale_rr_out_of_scope` **supprimée**.
- [ ] Tooltip fiabilité : `meta$reliability` (tx=high, rr/bivariée=low).
- [ ] (Option) `cache_path` par variable (`context_tx.tif` / `context_rr.tif` / `context_bivariate.tif`).
