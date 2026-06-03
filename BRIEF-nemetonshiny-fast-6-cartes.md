# Hand-off `nemetonshiny` — afficher les 6 cartes d'alerte FAST (nemeton ≥ v0.65.0)

> **Statut** : à câbler côté app. Ce fichier est un brief de transfert ;
> à retirer de ce repo une fois intégré côté `nemetonshiny` (convention
> hand-off, cf. commits `d722e27` / `65496b7`).

## Contexte

`nemeton` v0.65.0 corrige un bug qui rendait les cartes **NDMI**
systématiquement vides, et ajoute un orchestrateur qui produit en un
appel **les 6 cartes du diagnostic FAST** = 3 indices × 2 modes :

|        | `count`           | `rolling`           |
|--------|-------------------|---------------------|
| NDVI   | `NDVI_count`      | `NDVI_rolling`      |
| NBR    | `NBR_count`       | `NBR_rolling`       |
| NDMI   | `NDMI_count`      | `NDMI_rolling`      |

- **NDVI** = (B08−B04)/(B08+B04) — vigueur ; seuil défaut 0.40
- **NBR**  = (B08−B12)/(B08+B12) — brûlé/cassé ; seuil défaut 0.30
- **NDMI** = (B08−B11)/(B08+B11) — humidité végétation ; seuil défaut 0.30
- mode **`count`** = nb de dates en alerte sur la fenêtre (entier) ;
  mode **`rolling`** = magnitude du déficit sur la fenêtre glissante.

Rappel règle CLAUDE.md : **aucune logique métier dans l'app**. L'app
appelle les fonctions cœur exportées, met en forme, traduit (`i18n$t`).

## API cœur à consommer

### Option A — raster continu (les 6 cartes brutes)

```r
maps <- nemeton::read_fast_alert_rasters(
  con, zone_id   = <id>,
  date_from      = "2025-05-23",
  date_to        = "2026-05-23",
  cache_dir      = <chemin cache S2>,    # <project>/cache/layers/sentinel2
  indices        = c("NDVI", "NBR", "NDMI"),  # défaut : les 3
  modes          = c("count", "rolling"),     # défaut : les 2
  threshold      = NULL,                  # NULL = défaut par indice (recommandé)
  window_days    = 30L,                   # utilisé en mode "rolling"
  apply_zone_mask = TRUE,                 # NA hors UGF
  parallel       = FALSE)
# -> list nommée. maps$NDMI_rolling, maps[["NBR_count"]], ...
# Chaque élément : terra::SpatRaster EPSG:2154, OU NULL si aucune scène
#   cachée ne porte les bandes de cet indice dans la fenêtre.
```

Chaque carte est **content-addressée** (cache résultat, spec 017 D6) :
la 1re génération calcule, les revisites sont instantanées. Tant que le
cache S2 ne change pas, rappeler la fonction est quasi gratuit.

### Option B — masque 0-4 par quartiles (pour l'affichage leaflet)

Si l'UI affiche des classes 0-4 (et non le continu), boucler sur
`compute_fast_alert_mask()` — **même signature** (`index`, `mode`,
`threshold`, `window_days`, `cache_dir`, `apply_zone_mask`, …) :

```r
keys <- expand.grid(index = c("NDVI","NBR","NDMI"),
                    mode  = c("count","rolling"),
                    stringsAsFactors = FALSE)
masks <- Map(function(idx, md) nemeton::compute_fast_alert_mask(
               con, zone_id = <id>, index = idx, mode = md,
               date_from = ..., date_to = ..., cache_dir = ...),
             keys$index, keys$mode)
```

> Il n'existe pas (encore) d'orchestrateur « 6 masques » côté cœur, seul
> le continu en a un (`read_fast_alert_rasters()`). Si l'app veut les 6
> masques en un appel, demander l'ajout d'un `compute_fast_alert_masks()`
> au repo cœur plutôt que de boucler dans l'app (garder la boucle dans
> l'app reste acceptable : c'est de la présentation, pas du métier).

## Prérequis données (ingestion)

Les bandes nécessaires sont remplies par
`nemeton::ingest_sentinel2_timeseries()`. **B11 (NDMI) est déjà cachée
systématiquement en best-effort** (spec 019 D3) — pas besoin de passer
`bands = "NDMI"` à l'ingestion : si la scène expose B11, NDMI sera
disponible. Une scène sans B11 ne bloque pas NDVI/NBR (elle donnera juste
`NULL` pour les cartes NDMI sur cette période).

## Points UI à traiter

1. **Gérer le `NULL`** : une carte d'indice peut être `NULL` (aucune
   scène). Afficher un état vide propre (i18n), pas une erreur.
2. **i18n** : libellés indices/modes + légende via `i18n$t(...)`, jamais
   de littéral FR. Clés suggérées : `fast_index_ndvi/nbr/ndmi`,
   `fast_mode_count/rolling`, `fast_no_scene`.
3. **Sélecteur** : indice (3) × mode (2), ou petite grille de 6 vignettes.
   La carte NDMI partage la machinerie d'alerte (sous seuil = alerte).
4. **Cache** : la 1re carte d'une combinaison est lente (calcul), les
   suivantes instantanées — penser à un spinner sur le premier rendu.
5. **CRS** : sorties en EPSG:2154 ; reprojeter pour leaflet (3857) côté
   app comme pour les autres rasters.

## Vérif rapide après câblage

- Sélectionner NDMI / rolling sur une zone avec cache S2 → une carte
  s'affiche (avant v0.65.0 : toujours vide — c'était le bug corrigé).
- Les 6 combinaisons rendent une carte (ou un état vide explicite).

## Références cœur

- `R/fast_alert_raster.R` : `read_fast_alert_raster()` (1 carte),
  `read_fast_alert_rasters()` (les 6), `.enumerate_cache_scenes()` (fix).
- `R/fast_alert_mask.R` : `compute_fast_alert_mask()` (masque 0-4).
- NEWS.md / CHANGELOG.md : entrée **0.65.0**.
- spec 019 (`specs/019-ndmi-fast-index/spec.md`) pour NDMI.
