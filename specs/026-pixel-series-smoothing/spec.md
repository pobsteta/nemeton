# Spec 026 — Lissage robuste de la série pixel multi-indices

- **Statut** : Proposé → implémenté (v0.90.0)
- **Contexte** : 4 (santé) — visualisation série pixel
- **Dépend de** : spec 010 (`extract_pixel_timeseries`)

## 1. Problème

Le graphe « série pixel » (`extract_pixel_timeseries()` : NDVI/NBR/NDMI/NDRE
par scène) relie chaque acquisition par des segments → **dents de scie**
illisibles. La variabilité vient surtout du **bruit résiduel** (nuages,
ombres, neige non masqués, angles de vue), pas du signal forestier. Une
**courbe lissée + points bruts** est la pratique standard pour les séries
optiques Sentinel-2.

## 2. Décision

Helper cœur **`smooth_pixel_series()`** qui prend la sortie longue de
`extract_pixel_timeseries()` et ajoute une colonne `smoothed` par indice.
L'app affiche alors **points bruts estompés + ligne lissée** (présentation),
la logique de lissage (NA-aware, robustesse aux outliers) reste **dans le
cœur** (règle 12), testable et réutilisable.

- **Défaut `rolling_median`** : médiane glissante sur une **fenêtre temporelle**
  (`window_days`, défaut 45) centrée sur chaque date — robuste aux chutes
  nuageuses isolées (≠ moyenne mobile / LOESS standard, sensibles aux
  outliers). Fenêtre **temporelle** (jours), pas un nombre fixe de points
  (échantillonnage irrégulier).
- **Option `loess`** : régression locale `family = "symmetric"` (robuste,
  IRLS) `degree = 1`, span ≈ `window_days` / étendue temporelle.

## 3. API

```r
smooth_pixel_series(
  ts,                                   # sortie de extract_pixel_timeseries()
  window_days = 45,
  method      = c("rolling_median", "loess"),
  min_obs     = 3L)                     # mini de points clairs dans la fenêtre
```

### Sortie

Le `data.frame` d'entrée (`obs_date`, `index`, `value`) **trié par
`(index, obs_date)`** + une colonne **`smoothed`** (numérique, `NA` quand
la fenêtre contient moins de `min_obs` observations claires).

## 4. Algorithme

Par groupe `index` :
- **rolling_median** : pour chaque date `i`, `median(value[j])` sur les `j`
  tels que `|date_j − date_i| <= window_days/2` et `value_j` non-`NA` ; `NA`
  si moins de `min_obs` voisins clairs.
- **loess** : `loess(value ~ t, span, degree = 1, family = "symmetric")` sur
  les points non-`NA` (si `>= max(min_obs, 4)`), `t` = jours **centrés**
  (évite l'instabilité numérique des jours-époque), prédit à **toutes** les
  dates ; `span = clamp(window_days / étendue, 0.3, 0.75)` (plancher 0.3 :
  span trop petit → sur-ajustement, un spike résiduel tire la courbe).

## 5. Garde-fous

- `ts` doit porter `obs_date` / `index` / `value` (sinon abort explicite).
- `window_days > 0`, `min_obs >= 1`.
- Groupe tout-`NA` ou trop court → `smoothed` `NA` (jamais d'erreur).
- Aucune dépendance nouvelle (stats base `median` / `loess`).

## 6. Non-objectifs

- Pas de lissage saisonnier annuel ici (c'est le rôle du `trend` /
  `.trend_yearly_composite`). `smooth_pixel_series` opère à l'échelle scène.
- Pas de ré-échantillonnage à pas régulier : on garde les dates d'acquisition.
