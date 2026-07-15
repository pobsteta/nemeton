# Spec 036 — Graphiques au clic sur la carte « Contexte régional (E-OBS) »

**Version** : 0.1.0
**Date**    : 2026-07-15
**Statut**  : **Cœur implémenté** (v0.160.0) — accesseurs `eobs_summer_series()`,
`eobs_monthly_climatology()`, `eobs_trend_fit()`. Câblage app : brief à écrire.
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

Au **clic sur la carte**, ouvrir un panneau de **4 graphiques** qui révèlent la
donnée derrière la couleur, à la maille cliquée :

1. **Série estivale annuelle + droite de tendance** (T°max et précip).
2. **Anomalies annuelles** (barres) par rapport à la moyenne 2011-2024.
3. **Position dans le contexte régional** (distribution des pentes du buffer +
   marqueur du point cliqué).
4. **Diagramme ombrothermique** (Gaussen-Bagnouls) — climatologie mensuelle
   P/T sur 2011-2024, saison sèche mise en évidence.

Décision-cible (régénération) : *« à quelle vitesse cette station se
réchauffe/assèche, quels étés portent la tendance, est-ce un point chaud/sec
local ou dans la moyenne, et quelle est l'intensité/durée de sa saison sèche ? »*.

## 3. Données disponibles

- **Stack estival par année** : `load_eobs_source(aoi, var, years, nc=<.nc caché>)`
  renvoie déjà un `SpatRaster` **une couche/an** (JJA, `mean` pour tx, `sum` pour
  rr), nommée par l'année. Les `.nc` E-OBS 2011-2024 sont cachés par projet.
- **Rasters de tendance** : `context_tx.tif` / `context_rr.tif` = **pente OLS par
  pixel** (°C/déc, mm/déc) — déjà en cache. La distribution régionale (graphe 3)
  s'en déduit directement (`terra::values()`), **sans nouveau calcul cœur**.
- **Climatologie mensuelle (graphe 4)** : les `.nc` cachés sont les séries
  **journalières pleine année** 2011-2024 (la réduction estivale est appliquée en
  aval) → la moyenne mensuelle des précip (rr) et de la température est
  **calculable sans nouvelle acquisition**. **Nuance importante** : le diagramme de
  Gaussen utilise la **température moyenne** (`tg`), alors que le `.nc` température
  caché est le **maximum** (`tx`). Voir §5.4 pour l'option retenue (acquérir `tg`,
  ou `tx` comme proxy documenté).

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

Un second accesseur pour le graphe 4 (climatologie mensuelle) :

```r
#' Monthly E-OBS climatology at a point (month → mean value)
#'
#' Twelve-month climatology (mean over `years`) of an E-OBS variable at a
#' location, for the ombrothermic diagram (chart 4). Precipitation is summed
#' within each month then averaged across years (mm/month); temperature is the
#' monthly mean. Reads the full-year daily `.nc` (cached), so no new acquisition
#' for tx/rr; `tg` (mean temperature) needs its own `.nc` (see §5.4).
#'
#' @param daily A daily E-OBS `SpatRaster` (full year, `terra::time` set), or the
#'   cached `.nc` path.
#' @param point An `sf`/`sfc` POINT, or `c(lon, lat)` in EPSG:4326.
#' @param var `"rr"` (monthly precip sum, mm) | `"tg"`/`"tx"` (monthly mean, °C).
#' @param years Years to average over (default: all present).
#' @return A `data.frame(month = 1:12, value)`. Attributes: `var`, `unit`, `reducer`.
#' @export
eobs_monthly_climatology <- function(daily, point, var, years = NULL) { ... }
```

Notes :
- **Pas de re-réduction au clic.** L'app charge le stack estival **une fois** par
  vue/projet (idéalement caché en `.tif` multi-couches, cf. §6.1) et le réutilise.
  Idem pour la climatologie mensuelle (12 couches, cachée par point ou par maille).
- La **pente et son incertitude** (graphe 1) se calculent app-side par un simple
  `lm(value ~ year)` sur la série ; inutile de dupliquer côté cœur. Optionnel :
  exposer un helper `eobs_trend_fit(series)` renvoyant `list(slope_decade, r2,
  p_value)` si on veut la statistique côté cœur (recommandé pour la cohérence avec
  la pente cartographiée = `.eobs_ds_slope`).

## 5. Les 4 graphiques (détail)

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

### 5.4 Diagramme ombrothermique (Gaussen-Bagnouls)

Le climatogramme de référence du forestier : il révèle en un coup d'œil
**l'intensité et la durée de la saison sèche** de la station.

- **Axe X** : 12 mois (jan→déc). **Deux axes Y couplés par la convention de
  Gaussen `P = 2T`** : axe précip (mm, à gauche) gradué **2×** l'axe température
  (°C, à droite).
- **Précipitations** : barres bleues, cumul mensuel moyen 2011-2024 (mm/mois).
- **Température** : courbe rouge, moyenne mensuelle 2011-2024 (°C).
- **Saison sèche** : les mois où la **courbe P passe sous la courbe T** (aire
  hachurée) sont *secs* au sens de Gaussen (P < 2T). C'est l'information
  décisionnelle : nombre et intensité des mois secs conditionnent le choix
  d'essences en régénération.
- Optionnel : annoter le nombre de mois secs et l'indice de De Martonne
  (`P_an / (T_an + 10)`), classiques et parlants.

**Donnée & nuance (importante).** Le diagramme de Gaussen se base sur la
**température moyenne** (`tg`). Or le `.nc` température caché pour la carte de
contexte est le **maximum** (`tx`). Deux options :

| Option | Correction | Coût |
|---|---|---|
| **A — acquérir `tg`** (recommandée) | diagramme exact (T moyenne) | +1 `.nc` E-OBS `mean_temperature` (~800 Mo CDS, même clé) via `load_eobs_source(var="tg")` |
| **B — `tx` en proxy** | approché : Tmax > Tmean → **surestime** la saison sèche (P<2·Tmax déclenche trop tôt) | nul (donnée déjà là) |

**Recommandation** : viser l'option A (correction climatique). Si l'acquisition
`tg` est différée, livrer B **explicitement étiqueté** « basé sur T°max — saison
sèche majorée », jamais un Gaussen faux présenté comme exact. `load_eobs_source`
supporte déjà `var = "tg"` (mapping `mean_temperature`), donc A n'ajoute qu'un
téléchargement, pas de code d'acquisition.

**Cœur** : `eobs_monthly_climatology(daily, point, var, years)` (§4) fournit les 12
valeurs par variable ; le tracé (double axe, aire sèche, De Martonne) est app-side.

## 6. Livrable app `nemetonshiny` (brief à écrire à l'implémentation)

- **Clic leaflet** sur `context_map` → `input$context_map_click$lat/lng` →
  reprojection → `eobs_summer_series(stack, point)` pour tx **et** rr (graphes 1-3),
  et `eobs_monthly_climatology(daily, point, var)` pour tg + rr (graphe 4).
- **Panneau** (modale `showModal` ou `absolutePanel` latéral) avec les 4 graphes
  (plotly, cohérent avec le reste de l'app). Titre = coordonnées + commune.
- **Honnêteté spatiale** : extraire la **maille E-OBS brute** (~9 km, l'observation
  réelle), pas le pixel downscalé à 197 m — le downscaling n'ajoute que du détail
  orographique *spatial*, le signal *temporel* est celui de la maille. Le clic peut
  d'ailleurs surligner la maille E-OBS concernée sur la carte.
- **Acquisition `tg` (graphe 4)** : le diagramme de Gaussen exige la T **moyenne**
  (`tg`), alors que le contexte n'a caché que la T **max** (`tx`). Prévoir un
  téléchargement `load_eobs_source(aoi, var = "tg", years, months = 1:12)` (E-OBS
  `mean_temperature`, même clé CDS). **Nuance annuelle vs estivale** : les graphes
  1-3 restent **estivaux** (JJA) ; le graphe 4 est **mensuel sur les 12 mois** — il
  faut donc, pour l'ombrothermique, un `.nc` couvrant l'année entière (`months =
  1:12`), pas seulement l'été. Si `tg` n'est pas encore acquise, livrer le graphe 4
  en proxy `tx` **explicitement étiqueté** (cf. §5.4 option B), jamais un Gaussen
  faux présenté comme exact.

### 6.1 Cache du stack estival + du daily 12 mois

Pour un clic instantané, cacher le stack estival par année en `.tif` multi-couches
par vue/projet (`context_tx_years.tif`, `context_rr_years.tif`), écrit lors du
calcul du contexte (le daily→summer est déjà fait à ce moment). Sinon, premier
clic = une réduction (quelques secondes), puis mémoïsé en session.

Le graphe 4 (ombrothermique) a besoin du **daily 12 mois** (tg + rr), pas de
l'agrégat estival. Deux stratégies : (a) cacher les climatologies mensuelles
pré-agrégées par maille (`context_climato_tg.tif` / `context_climato_rr.tif`, 12
couches chacune) au moment du calcul du contexte — clic instantané, empreinte
disque modeste ; (b) garder le `.nc` daily et agréger au clic — plus lent mais
zéro cache supplémentaire. **(a) recommandée** (cohérente avec le cache estival
déjà prévu).

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
- Cœur : `eobs_monthly_climatology(daily, point, var)` sur un daily de test
  couvrant ≥ 1 an → `data.frame(month = 1:12, value)` 12 lignes ; réduction
  correcte (moyenne pour tg, somme mensuelle moyennée sur les années pour rr) ;
  NA hors emprise ; `years = NULL` = toutes les années présentes.
- App : `testServer()` — simuler `context_map_click`, vérifier l'appel de
  `eobs_summer_series` **et** `eobs_monthly_climatology`, et l'ouverture du
  panneau ; mock du stack et du daily.

## 8. Hors-scope v1

- **Trajectoire jointe T×P** (chemin annuel dans le plan anomalie T × anomalie P) et
  placement dans le quinconce 5×5 : intéressant mais secondaire → **v2**.
- **Extrêmes journaliers** (jours > seuil, vagues de chaleur) : nécessiterait de
  garder le pas de temps journalier au point ; hors périmètre estival-agrégé v1.
- Aucun changement au **rendu de la carte** elle-même (couleurs/légende/tendance) :
  cette spec n'ajoute qu'une **interaction au clic**.
