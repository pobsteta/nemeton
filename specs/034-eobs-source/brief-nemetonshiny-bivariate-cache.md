# Brief `nemetonshiny` — Invalider le cache bivarié E-OBS quand le schéma change (3×3 → 5×5)

**Date** : 2026-07-15
**Repos** : micro-prérequis `nemeton` (§1) + correctif `nemetonshiny` (§2).
**Fichiers app** : `R/service_regeneration.R` (`regeneration_context_cached`),
éventuellement `R/mod_regeneration.R` (garde de rendu du contexte).
**Origine** : sur le projet Reconfort, la carte bivariée E-OBS (« Contexte
régional » → « Bivariée T°max × précip ») affiche **3×3 = 9 classes** alors que le
cœur produit désormais **5×5 = 25 classes** (`.EOBS_BIVARIATE_N = 5`, « quinconce
L'IF n°49 »). Diagnostic vérifié 2026-07-15.

## 1. Diagnostic (mécanisme confirmé)

* Cœur installé = `nemeton 0.158.0`, `eobs_downscale_bivariate()` produit **1-25**
  (`N=5`) et **réécrit** toujours le cache (`terra::writeRaster(overwrite=TRUE)`).
* Mais l'app **sert le cache sans le recalculer** dès qu'il existe
  (`mod_regeneration.R` ≈ 1183) :
  ```r
  cached <- regeneration_context_cached(project_path, view)
  if (!is.null(cached)) return(set_state(cached$raster, cached$meta))
  ```
  Le recompute (`context_task` → `run_regeneration_context_raster`) n'est déclenché
  que si le `.tif` est **absent**.
* Le `context_bivariate.tif` en cache datait d'avant le passage 5×5 → il est resté
  **3×3 pour toujours**. La clé de cache est le **chemin fixe par vue**
  (`context_bivariate.tif`), sans marqueur de version/schéma → une évolution du
  cœur n'invalide rien.

Vérifié sur disque : `context_bivariate.tif` = classes 1-9, `meta.breaks` à 2
coupures par axe (3 classes). Suppression manuelle du `.tif` → recompute → 5×5 OK,
mais **ne pas exiger une purge manuelle par projet**.

## 2. Ce qui rend le correctif simple

La meta écrite par le cœur porte **déjà** le N du schéma :
`meta$palette$ncol` (`R/eobs_downscale.R` ≈ 1160, `ncol = N`). Un cache 3×3 a donc
`ncol = 3` (ou champ absent pour les tout premiers caches), un cache 5×5 a
`ncol = 5`. Il ne manque qu'un moyen, côté app, de connaître le **N courant du
cœur** sans le coder en dur.

## 3. Prérequis cœur `nemeton` (micro — à faire en session nemeton)

Exporter un accesseur du N courant. `.EOBS_BIVARIATE_N` est interne :

```r
#' Number of classes per axis of the E-OBS bivariate map (N×N = N² classes)
#' @return Integer scalar (currently 5 → 5×5 = 25 classes).
#' @export
eobs_bivariate_n <- function() .EOBS_BIVARIATE_N
```

+ NAMESPACE (`export(eobs_bivariate_n)`) et un `man/*.Rd` à la main (convention
repo, pas de `document()`). C'est tout — la meta expose déjà `palette$ncol`.

## 4. Correctif app `nemetonshiny`

Dans `regeneration_context_cached()` (`R/service_regeneration.R` ≈ 313), après
lecture de la meta, **invalider le cache bivarié si son schéma ne correspond plus**
au N courant du cœur :

```r
regeneration_context_cached <- function(project_path, view = "tx") {
  if (is.null(project_path)) return(NULL)
  paths <- .regen_context_raster_paths(project_path, view)
  if (!file.exists(paths$tif) || !file.exists(paths$meta)) return(NULL)
  meta <- tryCatch(jsonlite::read_json(paths$meta, simplifyVector = TRUE),
                   error = function(e) list(status = "ok"))

  # Invalidation de schéma : un cache bivarié écrit sous un N différent (3×3
  # hérité vs 5×5 courant) doit être recalculé, pas servi. `ncol` absent = cache
  # antérieur au champ → considéré périmé. Robuste à tout futur changement de N.
  if (identical(view, "bivariate")) {
    n_now <- tryCatch(nemeton::eobs_bivariate_n(), error = function(e) NA_integer_)
    n_cache <- suppressWarnings(as.integer(meta$palette$ncol %||% NA))
    if (is.na(n_cache) || (!is.na(n_now) && !identical(n_cache, as.integer(n_now)))) {
      return(NULL)   # → traité comme absent → run_regeneration_context_raster recalcule
    }
  }

  r <- tryCatch(terra::rast(paths$tif), error = function(e) NULL)
  if (is.null(r)) return(NULL)
  list(raster = r, meta = meta)
}
```

Effet : sur un projet dont le `context_bivariate.tif` est 3×3, le prochain
affichage de la vue « Bivariée » voit `cached == NULL` → `context_task` recalcule
en 5×5 → le `.tif` est réécrit → 25 classes. **Régénération automatique, sans purge
manuelle.**

### 4.1 Le rafraîchissement en mémoire

Le reactive de rendu (`mod_regeneration.R` ≈ 1169) court-circuite si la vue est
« déjà chargée » (`rv$context_loaded_view == view` et raster en mémoire). Après ce
correctif, un utilisateur **déjà** sur la vue Bivariée avec l'ancien raster en
mémoire ne verra pas la MAJ tant qu'il ne change pas de vue (ou via
`rv$context_refresh`). Deux options :
* **Suffisant** : au prochain changement de vue / rechargement, l'invalidation
  joue. Acceptable.
* **Mieux** : au démarrage de session (ou changement de projet), forcer un
  `rv$context_refresh` pour la vue bivariée si le cache est périmé, afin que la
  correction soit visible sans manip.

### 4.2 Non-objectifs

* Ne PAS toucher aux caches `context_tx.tif` / `context_rr.tif` : ce sont des
  tendances **continues** (colorNumeric), insensibles au N. Seul le bivarié est
  concerné.
* Ne pas changer le rendu de la légende : elle lit déjà `meta$palette`
  (`colors`/`ncol`) — une fois le `.tif` régénéré en 5×5, la légende suit. Si la
  légende restait 3×3 après régénération, ce serait un bug distinct à traiter à
  part (vérifier qu'elle n'est pas câblée en dur sur 3×3).

## 5. Test

* Cœur : `expect_identical(eobs_bivariate_n(), 5L)`.
* App : `testServer()` — écrire un `context_bivariate.meta.json` avec
  `palette$ncol = 3`, appeler `regeneration_context_cached(view="bivariate")` →
  doit renvoyer `NULL` (périmé) ; avec `ncol = 5` → renvoie le raster. Cache `tx`
  avec un `ncol` absent → **non** invalidé (garde limitée à `view=="bivariate"`).
