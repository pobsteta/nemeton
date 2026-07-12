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

## 7. Checklist app

- [ ] Appeler `eobs_downscale(var="tx", eobs=…, dem=NULL, aoi=units, statistic=…, buffer_m=25000)`.
- [ ] `addRasterImage` + `colorNumeric(reverse=TRUE)` + légende `meta$palette`/`value_label`, groupe `contexte_eobs`, piloté par le curseur d'opacité.
- [ ] Bandeau statut : mapper `meta$reason` (4 clés i18n FR/EN + `value_label`).
- [ ] (Option) `cache_path` pour éviter le retéléchargement.
- [ ] (Option) tooltip debug : `meta$dem_source` / `n_points` / `method`.
