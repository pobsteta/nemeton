# Spec 034 — Acquisition E-OBS : `load_eobs_source()`

**Version** : 0.1.0
**Date**    : 2026-07-04
**Statut**  : **En implémentation (v0.130.0).**
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` (feat mineur, API rétro-compatible).
**Cible app**  : brief pour brancher le bouton « Auto (E-OBS) » de l'onglet
reGénération (`brief-nemetonshiny` spec 027).
**Liens** : consommé par [`microclimate_detect_years()`](../../R/microclimate_years.R)
(années de référence moyenne/canicule) et
[`tendances_estivales_eobs()`](../../R/tendances_eobs.R) (contexte régional,
branche A). Patron d'acquisition : `load_foret_ancienne_source()` (spec 031).

## 1. Problème

Le bouton **« Auto (E-OBS) »** de l'onglet reGénération appelle
`microclimate_detect_years()` **sans données E-OBS** → le cœur s'arrête (il
n'auto-télécharge pas E-OBS) → l'app affiche *« Détection E-OBS indisponible —
saisir les années manuellement »*.

Cause de fond : **il manque un loader E-OBS côté cœur**. Les deux consommateurs
(`microclimate_detect_years`, `tendances_estivales_eobs`) attendent un
**SpatRaster estival par année** (une couche/an, nommée par l'année), mais
personne ne le produit. E-OBS (jeu européen quadrillé quotidien ECA&D /
Copernicus) doit être acquis puis réduit au T°max / précip **estival (JJA) par
an**.

## 2. Objectif

`load_eobs_source(aoi, var, years, months, source, reducer, nc, cache_dir, …)`
qui renvoie un **SpatRaster estival par année** prêt pour les deux consommateurs
(couches nommées par l'année), ou **`NULL`** en dégradation propre.

```r
tx <- load_eobs_source(aoi = ugf, var = "tx", years = 2014:2023)   # T°max estivale/an
microclimate_detect_years(eobs = tx, aoi = ugf)                    # -> années moy/canicule
rr <- load_eobs_source(aoi = ugf, var = "rr", years = 2014:2023)   # précip estivale/an
tendances_estivales_eobs(ugf, tx = tx, rr = rr)                    # -> carte bivariée
```

## 3. Décisions (D1–D6)

- **D1 — Deux chemins, comme les moteurs reGénération.**
  - *Chemin pur (injection `nc`, TESTABLE)* : l'utilisateur fournit un netCDF
    E-OBS quotidien (téléchargé depuis le CDS ou ECA&D) ou un `SpatRaster`
    daté ; le cœur le réduit en estival/an. C'est le **contrat de référence**,
    couvert en CI.
  - *Chemin CDS (voie A, best-effort)* : téléchargement automatique via
    `ecmwfr` (dataset **`insitu-gridded-observations-europe`**), **non jouable en
    CI** (réseau + clé CDS), **validé sur données réelles** par Pascal. Dégrade
    en `NULL`.
- **D2 — Format de sortie** : `SpatRaster`, une couche par année, `names()` =
  année, `time()` = 15 juillet de l'année. C'est exactement ce que
  `.eobs_summer_heat()` (detect_years) et `tendances_estivales_eobs()` (tx/rr)
  consomment déjà.
- **D3 — Variables** : `var ∈ {"tx","tg","rr"}` → variable CDS
  (`maximum_temperature`, `mean_temperature`, `precipitation_amount`).
  Réducteur estival par défaut : **`mean`** pour tx/tg (T°max/moy estivale
  moyenne), **`sum`** pour rr (cumul estival) ; surchargeable via `reducer`.
- **D4 — Fenêtre estivale** : `months = 6:8` (JJA) par défaut, paramétrable.
- **D5 — Réutilise l'infra CDS existante** : `ecmwfr` est déjà en Suggests
  (mcera5). La **même clé** `ecmwfr::wf_set_key()` que ERA5 donne accès à E-OBS.
  Pas de nouvelle dépendance. `version`/`resolution`/`period` du produit E-OBS
  exposés en paramètres (défauts raisonnables), car ils évoluent à chaque
  release ECA&D.
- **D6 — Dégradation propre** : `NULL` si `terra`/`sf` absents, `ecmwfr` absent,
  pas de clé, réseau KO, ou AOI hors Europe. Le caller (app) retombe alors sur
  la saisie manuelle des années — comportement actuel préservé.

## 4. API

```r
load_eobs_source(aoi, var = "tx", years = NULL, months = 6:8,
                 source = "cds", reducer = NULL, nc = NULL,
                 cache_dir = NULL, version = "30.0e",
                 resolution = "0.1deg", period = NULL, ...)
```

> **Correctif CDS (v0.134.2, 2026-07-05)** — validation sur clé réelle : le CDS
> attend les valeurs d'enum en **underscore** (`30_0e`, `0_1deg`), pas en point,
> et la version par défaut `28.0e` ne couvre pas la période `2011_2024` (→ 400
> « invalid combination », qui masquait le vrai blocage licence). Corrigé :
> normalisation point→underscore de `version`/`resolution` + défaut `30.0e`
> (combinaison `30_0e` + `2011_2024` + `0_1deg` **acceptée** par le CDS). Reste :
> accepter la **licence E-OBS** sur la page du dataset (403 sinon).

Helpers internes :
- `.eobs_var_spec(var)` — mappe var → (variable CDS, réducteur défaut).
- `.eobs_summer_by_year(daily, aoi, years, months, reducer)` — **pur** :
  raster quotidien daté → une couche estivale par année (crop+mask AOI, sélection
  des mois, réduction). Cœur testable.
- `.eobs_cds_fetch(cds_var, years, cache_dir, version, resolution, period)` —
  best-effort `ecmwfr::wf_request` + dézippage → chemin netCDF, ou `NULL`.

## 5. Tests (CI)

- `.eobs_summer_by_year` sur un raster quotidien synthétique daté : sélection
  JJA, une couche/an nommée par l'année, réducteurs mean/sum/max, crop AOI.
- `load_eobs_source(nc = <raster synthétique>)` : bout en bout chemin pur.
- Dégradation `NULL` : `nc` illisible, var inconnue → erreur ; source non-cds
  sans `nc` → `NULL`.
- Intégration : la sortie alimente `microclimate_detect_years()` et
  `tendances_estivales_eobs()` sans adaptation.

## 6. Hors périmètre

- Validation Pascal du **chemin CDS réel** (clé + téléchargement + `period`
  exact de la version E-OBS courante).
- Câblage du bouton « Auto » côté app (brief séparé).
- Autres sources historiques (SAFRAN, Copernicus ERA5-Land — couverts ailleurs).
