# Spec 036 — Graphiques au clic sur la carte « Contexte régional (E-OBS) »

**Version** : 0.1.0
**Date**    : 2026-07-15
**Statut**  : **Cadrage (non implémenté).**
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` — 1 accesseur exporté (feat mineur, rétro-compatible).
**Cible app**  : `nemetonshiny` — clic leaflet + panneau de graphiques (brief §6).
**Liens** : prolonge [spec 034](../034-eobs-source/spec.md) (`load_eobs_source()`,
stack estival par année) et le contexte régional de
[`tendances_estivales_eobs()`](../../R/tendances_eobs.R) /
[`eobs_downscale()`](../../R/eobs_downscale.R). Voir aussi
`specs/034-eobs-source/brief-nemetonshiny-bivariate-cache.md` (même carte).

## 1. Problème

La carte « Contexte régional (E-OBS) » (onglet reGénération) affiche **une couleur
par maille** — la *pente* de la tendance estivale (T°max °C/déc, précip mm/déc, ou
la classe bivariée 5×5). Mais elle est **muette au clic** : l'utilisateur voit un
résultat agrégé (une pente) sans pouvoir en inspecter la trajectoire sous-jacente,
juger de sa robustesse, ni situer le point dans son contexte régional. Or toute
l'information temporelle qui a produit la couleur est disponible (série estivale
2011-2024 par maille).

## 2. Objectif

Au **clic sur la carte**, ouvrir un panneau de **3 graphiques** qui révèlent la
donnée derrière la couleur, à la maille cliquée :

1. **Série estivale annuelle + droite de tendance** (T°max et précip).
2. **Anomalies annuelles** (barres) par rapport à la moyenne 2011-2024.
3. **Position dans le contexte régional** (distribution des pentes du buffer +
   marqueur du point cliqué).

Décision-cible (régénération) : *« à quelle vitesse cette station se
réchauffe/assèche, quels étés portent la tendance, et est-ce un point chaud/sec
local ou dans la moyenne ? »*.

## 3. Données disponibles (rien à acquérir)

- **Stack estival par année** : `load_eobs_source(aoi, var, years, nc=<.nc caché>)`
  renvoie déjà un `SpatRaster` **une couche/an** (JJA, `mean` pour tx, `sum` pour
  rr), nommée par l'année. Les `.nc` E-OBS 2011-2024 sont cachés par projet.
- **Rasters de tendance** : `context_tx.tif` / `context_rr.tif` = **pente OLS par
  pixel** (°C/déc, mm/déc) — déjà en cache. La distribution régionale (graphe 3)
  s'en déduit directement (`terra::values()`), **sans nouveau calcul cœur**.

## 4. Livrable cœur `nemeton`

Un seul accesseur exporté — le reste est déjà là.

```r
#' Summer E-OBS series at a point (year → value)
#'
#' Extracts the per-year summer (JJA) E-OBS value at a location, for charts 1-2
#' of the regional-context click panel. Reduction and acquisition already live in
#' `load_eobs_source()`; this only extracts the per-year stack at `point`.
#'
#' @param stack A per-year summer `SpatRaster` (one layer/year, named by year), as
#'   returned by [load_eobs_source()]. Passing the already-loaded stack avoids
#'   re-reducing the daily `.nc` on every click.
#' @param point An `sf`/`sfc` POINT, or `c(lon, lat)` in EPSG:4326.
#' @return A `data.frame(year, value)`, one row per layer, NA-safe. Attributes:
#'   `var`, `unit`, `reducer`.
#' @export
eobs_summer_series <- function(stack, point) { ... }
```

Notes :
- **Pas de re-réduction au clic.** L'app charge le stack estival **une fois** par
  vue/projet (idéalement caché en `.tif` multi-couches, cf. §6.1) et le réutilise.
- La **pente et son incertitude** (graphe 1) se calculent app-side par un simple
  `lm(value ~ year)` sur la série ; inutile de dupliquer côté cœur. Optionnel :
  exposer un helper `eobs_trend_fit(series)` renvoyant `list(slope_decade, r2,
  p_value)` si on veut la statistique côté cœur (recommandé pour la cohérence avec
  la pente cartographiée = `.eobs_ds_slope`).

## 5. Les 3 graphiques (détail)

### 5.1 Série estivale + tendance (le graphe fondamental)

- Deux panneaux (ou deux mini-graphes) : **T°max estivale** (points + droite lm) et
  **précip estivale** (idem). Axe X = années 2011-2024.
- Annoter la **pente** (°C/déc, mm/déc) = la valeur exacte cartographiée, + R²/p.
- Vertu clé : rend **visible la « fiabilité faible »** des précipitations — un
  nuage dispersé à pente molle est plus honnête qu'un pixel lissé coloré.

### 5.2 Anomalies annuelles (barres)

- Barres = `valeur_année − moyenne(2011-2024)`, colorées chaud/froid (T°max) et
  sec/humide (précip). Ligne 0 = climatologie de la période.
- Montre **quels étés portent la tendance** (2018, 2022 chaud & sec) — ancre
  l'abstraction dans des années vécues. Peu coûteux (dérivé de la même série).

### 5.3 Position dans le contexte régional

- Histogramme / densité de la **distribution des pentes** sur tout le buffer 25 km
  (valeurs de `context_tx.tif` / `context_rr.tif`), + **marqueur vertical** sur la
  pente de la maille cliquée, + percentile (« ce point est plus chaud que X % du
  massif »).
- Répond à la question que la carte seule ne chiffre pas. **Aucun calcul cœur** :
  `terra::values(trend_raster)` + la valeur au point cliqué.

## 6. Livrable app `nemetonshiny` (brief à écrire à l'implémentation)

- **Clic leaflet** sur `context_map` → `input$context_map_click$lat/lng` →
  reprojection → `eobs_summer_series(stack, point)` pour tx **et** rr.
- **Panneau** (modale `showModal` ou `absolutePanel` latéral) avec les 3 graphes
  (plotly, cohérent avec le reste de l'app). Titre = coordonnées + commune.
- **Honnêteté spatiale** : extraire la **maille E-OBS brute** (~9 km, l'observation
  réelle), pas le pixel downscalé à 197 m — le downscaling n'ajoute que du détail
  orographique *spatial*, le signal *temporel* est celui de la maille. Le clic peut
  d'ailleurs surligner la maille E-OBS concernée sur la carte.

### 6.1 Cache du stack estival

Pour un clic instantané, cacher le stack estival par année en `.tif` multi-couches
par vue/projet (`context_tx_years.tif`, `context_rr_years.tif`), écrit lors du
calcul du contexte (le daily→summer est déjà fait à ce moment). Sinon, premier
clic = une réduction (quelques secondes), puis mémoïsé en session.

### 6.2 Portée

- Vues **tx** et **rr** : graphes 1-2 sur la variable concernée + graphe 3 sur sa
  distribution.
- Vue **bivariée** : afficher les graphes 1-2 **des deux** variables (T°max ET
  précip) côte à côte — c'est le sens du croisement. (La *trajectoire jointe T×P*
  proposée initialement est **hors-scope v1**, cf. §8.)

## 7. Tests

- Cœur : `eobs_summer_series(stack, point)` sur un stack de test 3 couches
  (2011-2013) → `data.frame` 3 lignes, valeurs = extraction attendue, NA hors
  emprise. `eobs_trend_fit()` (si retenu) → pente == `.eobs_ds_slope` sur la même
  série (cohérence carte ↔ graphe).
- App : `testServer()` — simuler `context_map_click`, vérifier l'appel de
  `eobs_summer_series` et l'ouverture du panneau ; mock du stack.

## 8. Hors-scope v1

- **Trajectoire jointe T×P** (chemin annuel dans le plan anomalie T × anomalie P) et
  placement dans le quinconce 5×5 : intéressant mais secondaire → **v2**.
- **Extrêmes journaliers** (jours > seuil, vagues de chaleur) : nécessiterait de
  garder le pas de temps journalier au point ; hors périmètre estival-agrégé v1.
- Aucun changement au **rendu de la carte** elle-même (couleurs/légende/tendance) :
  cette spec n'ajoute qu'une **interaction au clic**.
