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
- **Option `harmonic`** (amendement v0.91.0) : régression **harmonique
  robuste** — modélise le **cycle saisonnier annuel** (Fourier) + une
  tendance linéaire, donc **continue** même sur les trous hiver/été (≠ les
  deux dénoiseurs locaux, qui ne disent rien là où il n'y a pas de points).
  C'est la famille adaptée aux séries optiques à trous saisonniers (HANTS /
  BFAST / CCDC), et cohérente avec FORDEAD (déjà harmonique, ADR-013).

  > **Caveat « modèle ≠ donnée »** : `harmonic` *interpole l'hiver* à partir
  > de la forme du cycle — c'est une courbe **modélisée**, pas de la donnée
  > brute. À présenter comme telle côté app (ligne « modèle saisonnier »).

## 3. API

```r
smooth_pixel_series(
  ts,                                   # sortie de extract_pixel_timeseries()
  window_days = 45,                     # rolling_median / loess seulement
  method      = c("rolling_median", "loess", "harmonic"),
  min_obs     = 3L,                     # mini de points clairs dans la fenêtre
  n_harmonics = 2L)                     # harmonic seulement (1-3)
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
- **harmonic** (amendement v0.91.0) : moindres carrés sur le modèle
  `y = b0 + b1·(t−t̄)/P + Σ_{k=1}^{K}[a_k·sin(2πk·t/P) + c_k·cos(2πk·t/P)]`,
  `P = 365.25 j`, `K = n_harmonics`, `t` en jours. Ajustement **robuste IRLS**
  (3 itérations, poids **biweight de Tukey** `c = 4.685`, échelle = MAD des
  résidus) → rejette les chutes nuageuses. Prédit à **toutes** les dates →
  courbe continue. Base R uniquement (`stats::lm.wfit`, `stats::median`).

## 5. Garde-fous

- `ts` doit porter `obs_date` / `index` / `value` (sinon abort explicite).
- `window_days > 0`, `min_obs >= 1`, `n_harmonics ∈ 1:3`.
- Groupe tout-`NA` ou trop court → `smoothed` `NA` (jamais d'erreur).
- **harmonic** : exige `>= 2·K + 4` points non-`NA` **et** une étendue
  temporelle `>= 0.75·P` (~9 mois, pour estimer le cycle annuel) ; sinon
  `NA`. Ajustement rang-déficient (singularité, trop de poids nuls) → `NA`
  via `tryCatch` (jamais d'erreur).
- Aucune dépendance nouvelle (stats base `median` / `loess` / `lm.wfit`).

## 6. Non-objectifs

- Pas de lissage saisonnier annuel **pour le diagnostic de déclin** : le mode
  `trend` (composite estival + Theil-Sen) reste la référence pluriannuelle.
  Le terme de tendance de `harmonic` sert l'**affichage** continu, pas la
  décision d'alerte.
- Pas de ré-échantillonnage à pas régulier : on garde les dates d'acquisition
  (la prédiction harmonique reste évaluée aux dates observées).
