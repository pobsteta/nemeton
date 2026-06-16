# Spec 025 — Plan de **placettes sanitaires** sur le `trend` (GRTS à probabilité continue)

- **Statut** : Proposé → implémenté (v0.88.0)
- **Contexte** : 4 (santé) — suivi sanitaire dédié
- **Dépend de** : spec 014 (GRTS, helpers réutilisés), spec 023 (mode `trend`),
  v0.85.1 (fix mosaïque multi-tuiles), v0.87.0 (`extract_*_trend`)

## 0. Périmètre — placettes SANITAIRES, indépendantes du terrain

Ce plan crée des **placettes sanitaires** : un jeu de points **autonome**,
sans **aucun rapport** avec les placettes terrain / d'inventaire (`plot`,
`create_sampling_plan`, `create_validation_sampling_plan`). La fonction :

- ne lit **jamais** la table `plot` ni un plan d'inventaire ;
- ne réutilise **pas** la tournée TSP (logistique de campagne terrain) — il
  n'y a **pas** d'`visit_order` ;
- produit des placettes ordonnées par **sévérité de déclin décroissante**
  (priorité sanitaire), pas par un parcours de marche.

C'est une fonction **distincte** de `create_validation_sampling_plan()`
(spec 014, terrain), même si elle en réutilise les briques GRTS internes.

## 1. Problème

`create_validation_sampling_plan()` (spec 014) tire un plan terrain sur un
**masque catégoriel 0-4** (`alert_raster`), avec un GRTS pondéré par la
**classe** (3 ou 4) via `caty_var`/`caty_n`. C'est adapté au mode `count` /
`rolling` (nombre de jours d'alerte → classes).

Le mode `trend` (spec 023) produit un raster **continu** : `|pente|` Theil-Sen
(NDRE/an) si déclin pluriannuel significatif (Mann-Kendall `p < alpha`), `0`
sinon, `NA` si < `min_years` années valides. Discrétiser cette pente continue
en 4 quartiles **avant** de pondérer perd de l'information : un pixel à
`|pente| = 0.04` et un à `0.012` peuvent tomber dans la même classe alors que
le premier mérite une priorité terrain bien plus forte.

## 2. Décision

Ajouter une voie de tirage **dédiée au `trend`**, qui pondère l'inclusion GRTS
par la **magnitude continue du déclin** plutôt que par une classe discrète.

- **Tirage à probabilité inégale continue** : `spsurvey::grts(..., aux_var)`
  où `aux_var = |pente|` → la probabilité d'inclusion d'un pixel est
  **proportionnelle à la sévérité réelle du déclin**. Spatialement équilibré
  (GRTS), reproductible (`seed`).
- **Cellules candidates (validation)** : `value > 0` (déclins significatifs).
- **Cellules témoins** : `value == 0` (testées mais **stables** : pente non
  significative ou positive) → GRTS **équiprobable** (réutilise
  `.draw_grts_equiprobable()`). `NA` (années insuffisantes) est **exclu** des
  deux (on ne peut rien conclure).
- Le raster `trend` est obtenu via `read_fast_alert_raster(mode = "trend")`,
  qui lit la série **scène par scène par tuile puis mosaïque sur grille
  commune** (v0.85.1) → pas de plantage multi-tuiles, et le masque UGF est
  déjà appliqué.

## 3. API

```r
create_trend_sanitary_plan(
  con, zone_id,
  date_from, date_to, cache_dir,
  index            = c("NDRE", "NDMI", "NDVI", "NBR"),  # défaut NDRE
  n_plots          = 20L,    # placettes sanitaires sur les déclins
  n_control        = 5L,     # placettes témoins (zones stables)
  months           = 6:9,
  min_years        = 4L,
  min_obs_per_year = 2L,
  alpha            = 0.05,
  apply_zone_mask  = TRUE,
  mask_polygon     = NULL,
  seed             = NULL)
```

### Sortie — `sf` POINT (EPSG:2154), **sans** `visit_order`

| Colonne | Type | Sens |
|---|---|---|
| `plot_id` | chr | `S01…` (sanitaire), `T01…` (témoin) |
| `type` | chr | `"Sanitaire"` / `"Temoin"` |
| `alert_value` | num | `|pente|` au pixel (sanitaire) ; `0` (témoin) |
| `index` | chr | indice trend (`"NDRE"`…) |
| `source` | chr | `"FAST_TREND"` |
| `seed` | int/NA | reproductibilité |
| `geometry` | sfc_POINT | EPSG:2154 |

Les placettes sanitaires sont ordonnées par `alert_value` **décroissant**
(`S01` = déclin le plus sévère), puis les témoins. **Pas de TSP.**

## 4. Algorithme

1. `cont <- read_fast_alert_raster(con, zone_id, index, date_from, date_to,
   mode = "trend", months, min_years, min_obs_per_year, alpha, cache_dir,
   apply_zone_mask, mask_polygon, cache_result = FALSE)`.
   `NULL` → erreur typée `nemeton_empty_alert_mask`.
2. **Priorité** = `cont` masqué à `value > 0` (NA ailleurs). Si 0 cellule →
   erreur typée `nemeton_empty_alert_mask` (« aucun déclin significatif »).
3. **Sanitaires** : `.draw_grts_continuous(priority, n_plots, seed)` —
   `spsurvey::grts(sframe, n_base, aux_var = "alert_value")`.
4. **Témoins** (si `n_control > 0`) : cellules `value == 0` → `.draw_grts_
   equiprobable()`. Aucune cellule `== 0` → warning, témoins sautés.
5. **Assemblage** : tags `S##` (tri `alert_value` décroissant) / `T##`,
   `type`, `alert_value` (témoins = 0 via `terra::extract`), `index`,
   `source = "FAST_TREND"`, `seed`. **Aucune tournée TSP** — les placettes
   sanitaires sont indépendantes de la logistique de campagne terrain.

## 5. Garde-fous

- `read_fast_alert_raster` renvoie `NULL` (aucune scène / hors saison) →
  erreur typée `nemeton_empty_alert_mask` (l'app affiche « rien à valider »).
- Aucun déclin significatif (`value > 0` vide) → même erreur typée.
- Aucune cellule témoin (`value == 0` vide) → warning, plan sans témoins.
- `spsurvey` absent → `cli_abort` explicite (comme spec 014).
- `n_validation >= 1`, `n_control >= 0`, `seed` scalaire ou `NULL`.
- `aux_var` strictement positif par construction (`value > 0`).

## 6. Non-objectifs

- **Classe 0-4** : pas dans la sortie (bornes quartiles zone-wide) — l'app la
  lit dans le masque `compute_fast_alert_mask(mode = "trend")` au pixel.
- Pas de calcul de taille d'échantillon (Cochran) : `n_validation`/`n_control`
  restent des cibles fixées (cohérent avec spec 014).

## 7. Cohérence

`alert_value` au point de validation = la valeur pré-quartile du raster trend
au même pixel = `extract_pixel_trend(xy)$alert_value` (v0.87.0). Le plan, la
carte et le graphe pixel sont donc tous adossés au **même** `|pente|`.
