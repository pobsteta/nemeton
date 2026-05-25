# Spec 014 — Validation sampling plan (phase A, cœur)

**Statut** : livrée cœur v0.47.0 (2026-05-25).
**Démarré** : 2026-05-24.
**Cible release** : v0.47.0 (minor — 4 nouvelles fonctions exportées).
**Lien** : implémente la phase A du chantier app cadré dans
`/home/pascal/dev/nemetonshiny/design/validation-sampling.md`
(décisions §13) et le brief de session
`/home/pascal/dev/nemetonshiny/design/nemeton-phase-a-brief.md`.

## 1. Problème

Aujourd'hui les alertes FAST/FORDEAD sont **projetées sur les placettes
systémiques** (`list_fast_alerts_for_zone()` agrège par placette via
`exactextractr::exact_extract`). Un foyer de dépérissement détecté par
le `dieback_mask` FORDEAD peut donc passer inaperçu si aucune placette
GRTS ne tombe à proximité (« 0 alertes » alors que le masque montre
plusieurs ha de classe 4).

Spec 013 (v0.46.0) a fourni le raster d'alerte FAST pixel-par-pixel
(continu). Spec 014 ferme la boucle en générant un **plan
d'échantillonnage de validation** terrain ciblé sur les zones d'alerte.

## 2. Vision cible

Une fonction `create_validation_sampling_plan()` qui :

1. Lit un raster d'alerte 0-4 (`dieback_mask` FORDEAD ou
   `fast_alert_mask` FAST).
2. Sélectionne les cellules d'alerte (classes 3-4 par défaut, garde-fou
   G1 de spec 008).
3. Tire **N_validation** placettes via GRTS pondéré (proba d'inclusion
   ∝ valeur de classe — classe 4 plus dense que classe 3).
4. Tire **N_control** placettes témoin via GRTS équiprobable dans la
   zone saine (classe 0).
5. Retourne un `sf` POINT EPSG:2154 unifié avec ordre de tournée TSP.

L'app `nemetonshiny` ajoute la provenance applicative
(`zone_id`, `fordead_run_id`, `generated_at`) et persiste dans la couche
`validation_plots` de `samples.gpkg`.

## 3. Décisions actées

### 3.1 Naming — pas de breaking change avec v0.46.0

`read_fast_alert_raster()` (v0.46.0) reste **la fonction live continue**
pour l'UI (heatmap interactive avec sliders). Une nouvelle fonction
`read_fast_alert_mask()` est ajoutée, **strict miroir de
`read_fordead_dieback_mask()`**, qui lit un **0-4 catégoriel persisté**.

Le naming parallélise FORDEAD :
- `dieback_mask` (FORDEAD) ↔ `fast_alert_mask` (FAST)
- `read_fordead_dieback_mask()` ↔ `read_fast_alert_mask()`

### 3.2 Discrétisation FAST 0-4 (vs scale continue)

`compute_fast_alert_mask()` discrétise la sortie de
`read_fast_alert_raster()` en 0-4. Bins par défaut (mode `"count"`) :

| Pixel value (alert days) | Classe |
|---|---|
| 0           | 0 — pas d'alerte |
| 1-2         | 1 — trace |
| 3-5         | 2 — moyenne |
| 6-10        | 3 — forte |
| > 10        | 4 — très forte |

Pour le mode `"rolling"` (deficit magnitude continu) : bins fixes par
défaut `c(0, 0.05, 0.10, 0.20, Inf)`. Argument `breaks` permet de
surcharger.

### 3.3 GRTS pondéré — choix d'implémentation

Brief §A2 autorise deux voies : étendre `create_sampling_plan()` ou
implémenter la pondération directement dans
`create_validation_sampling_plan()`. **Choix : implémentation interne**
via le helper privé `.draw_grts_weighted(priority_raster, n)`.

Raisons :
- `create_sampling_plan()` est complexe (200+ lignes, stratification
  CHM/MNT/BD Forêt) — un paramètre `priority_raster` parallèle aurait
  doublé la surface d'API à tester sans bénéfice (le code de
  validation n'a pas besoin de la stratification systémique).
- Le helper privé reste promotable dans `create_sampling_plan()` plus
  tard si un 2e appelant émerge.

### 3.4 GRTS unequal-probability — API `caty_var` / `caty_n`

`spsurvey::grts()` 5.x. Les classes d'alerte (3, 4...) deviennent
les catégories, et l'allocation N par catégorie est proportionnelle
à la valeur (largest-remainder rounding pour totaliser exactement N).
Plafonné par les candidats disponibles dans chaque catégorie.

**Important** : `caty_n` doit être un **vecteur nommé**, pas une liste
(`as.list()` casse `spsurvey::grts` avec une erreur vide).

### 3.5 Cas limite « masque vide »

Lever une erreur typée **`nemeton_empty_alert_mask`** (cf.
`cli::cli_abort(..., class = ...)`) quand `classes` ne match aucune
cellule, pour que l'app affiche un message propre (« Zone saine, rien
à valider ») au lieu de produire un plan dégénéré.

### 3.6 Témoins zones saines — générés ici, pas côté app

Décision 5 du brief. `create_validation_sampling_plan()` génère
**les deux populations** (validation + témoins) en un appel ; pas de
chaînage app-side.

### 3.7 `visit_order` unique sur l'union

Un seul TSP tour sur l'union validation + témoins (et non deux
tournées séparées). Minimise le déplacement total du crew terrain.

## 4. Livrables cœur (v0.47.0)

| Livrable | Fichier | Statut |
|---|---|---|
| `fordead_alert_mask()` (A1) | `R/alert_mask.R` | ✅ livré |
| `compute_fast_alert_mask()` (A4 write) | `R/fast_alert_mask.R` | ✅ livré |
| `read_fast_alert_mask()` (A4 read) | `R/fast_alert_mask.R` | ✅ livré |
| `create_validation_sampling_plan()` (A3) | `R/validation_sampling.R` | ✅ livré |
| Helpers `.draw_grts_weighted()`, `.draw_grts_equiprobable()`, `.compute_visit_order()` | `R/validation_sampling.R` | ✅ livré |
| Tests : 49 ✔ (13 alert-mask + 18 fast-alert-mask + 18 validation-sampling) | `tests/testthat/test-{alert,fast-alert,validation}*.R` | ✅ livré |
| Roxygen + NAMESPACE | auto | ✅ livré |

## 5. Contrat consommé par l'app (phase B, `nemetonshiny`)

```r
# FORDEAD path
mask <- nemeton::read_fordead_dieback_mask(con, zone_id,
                                            cache_dir = "<...>/fordead")
plan <- nemeton::create_validation_sampling_plan(
  zone, alert_raster = mask,
  n_validation = 30L, n_control = 8L,
  classes = c(3L, 4L), source = "FORDEAD", seed = 42L)

# FAST path (after compute_fast_alert_mask has persisted)
mask <- nemeton::read_fast_alert_mask(con, zone_id,
                                        cache_dir = "<...>/fast")
plan <- nemeton::create_validation_sampling_plan(
  zone, alert_raster = mask,
  n_validation = 30L, n_control = 8L,
  source = "FAST", seed = 42L)
```

L'app ajoute ses colonnes de provenance (`zone_id`, `mask_timestamp`,
`generated_at`) et persiste dans `samples.gpkg`.

## 6. Hors scope (à reporter en spec 015+ si besoin)

- **`priority_raster` argument sur `create_sampling_plan()` public** :
  reporté, voir §3.3 ci-dessus. Le helper privé peut être promu si un
  autre caller en a besoin.
- **Wire `compute_fast_alert_mask()` dans `ingest_sentinel2_timeseries()`
  comme phase finale** : pas fait V1 — le mask reste un opt-in explicite
  côté app (qui contrôle quand persister et avec quels seuils).
- **Phase B app `nemetonshiny`** : module UI + bouton « Générer plan de
  validation » + persistance dans `samples.gpkg` — séparée par
  construction.

## 7. Tests

- **Offline / unit** (input validation, raster arithmetic sur fixtures
  synthétiques 4×4 et 10×10) — couvrent 13 + ~6 tests.
- **Intégration `with_clean_db`** — round-trip
  `compute_fast_alert_mask()` → `read_fast_alert_mask()` sur la vraie
  DB villards (`zone_id = 1`, 155 plots, cache `<project>/cache/layers/
  sentinel2`).
- **GRTS pondéré** — assertion statistique : sur un raster avec
  populations égales en classe 3 et 4, classe 4 reçoit plus de
  placettes (allocation proportionnelle au poids).
- **Reproductibilité `seed`** — deux appels avec le même seed
  produisent les mêmes géométries.

Total : 49 ✔ / 0 FAIL.
