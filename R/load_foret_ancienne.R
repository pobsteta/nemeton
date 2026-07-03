# load_foret_ancienne.R — acquisition forêt ancienne (~1850) pour N2 (spec 031/027)
# ------------------------------------------------------------------
# Récupère la couverture forestière ~1850 depuis la carte de l'état-major IGN
# (BD Carto État-Major, WFS via happign), comme couche `foret_ancienne` de
# indicateur_n2_continuite(). L'acquisition métier vit dans le cœur (rule #1) ;
# l'app orchestre/cache (pattern SUFOSAT : nemeton::load_theia_source).
#
# Choix (arbitré 2026-07-03) : le produit officiel « BD Forêts anciennes »
# (Nature=ancienne, état-major × BD Forêt v2) est download-only (GeoPackage
# départemental .7z, pas de WFS). On utilise ici l'INGRÉDIENT état-major ~1850
# (forêt d'alors), atteignable en WFS ; N2 le recroise avec les UGF actuelles,
# donc la CONTINUITÉ (« forêt hier et aujourd'hui ») émerge de N2 lui-même.

# Couche WFS IGN de la forêt ~1850 (carte de l'état-major, EM9.1 = bois/forêt).
.FORET_ANCIENNE_WFS_LAYER <- "BDCARTO_ETAT-MAJOR.NIVEAU3:c_1_1_ocs_ancien"

.foret_ancienne_empty <- function(crs) {
  sf::st_sf(foret_ancienne = logical(0), geometry = sf::st_sfc(crs = crs))
}

#' Acquire the IGN historical-forest (~1850 état-major) layer for an AOI
#'
#' @description
#' Fetch the ~1850 forest cover from the IGN *carte de l'état-major* land-cover
#' layer (BD Carto État-Major, `BDCARTO_ETAT-MAJOR.NIVEAU3:c_1_1_ocs_ancien`,
#' Licence Ouverte / Etalab 2.0) over `aoi` via WFS (`happign`), and return it
#' as the `foret_ancienne` polygon layer consumed by
#' [indicateur_n2_continuite()].
#'
#' This is the **historical forest cover** ingredient (forested ~1850): N2
#' intersects it with the current units, so forest **continuity** ("forest then
#' *and* now") emerges from the indicator itself. It is **not** the finished IGN
#' *BD Forêts anciennes* product (état-major × BD Forêt v2, `Nature`
#' classification), which is download-only (departmental GeoPackage) and not
#' exposed via WFS.
#'
#' Degrades gracefully — returns `NULL` on any failure (no network, `happign`
#' absent, WFS error, AOI outside metropolitan France) so the caller can fall
#' back to current-cover N2. A 0-row `sf` is returned when the AOI simply has no
#' ~1850 forest.
#'
#' @param aoi An `sf`/`sfc` project extent (must have a defined CRS).
#' @param crs Target EPSG of the returned layer. Default `2154`.
#' @param layer WFS layer id. Defaults to the état-major forest layer.
#' @param ... Passed to [happign::get_wfs()].
#'
#' @return An `sf` of ancient-forest polygons (`foret_ancienne = TRUE`), clipped
#'   to `aoi`, in `crs`; a 0-row `sf` if none; `NULL` on failure.
#' @seealso [indicateur_n2_continuite()], [build_foret_ancienne_mask()]
#' @export
load_foret_ancienne_source <- function(aoi, crs = 2154,
                                       layer = .FORET_ANCIENNE_WFS_LAYER, ...) {
  if (!inherits(aoi, c("sf", "sfc"))) {
    cli::cli_warn("load_foret_ancienne_source(): {.arg aoi} must be an sf/sfc; returning NULL.")
    return(NULL)
  }
  if (is.na(sf::st_crs(aoi))) {
    cli::cli_warn("load_foret_ancienne_source(): {.arg aoi} has no CRS; returning NULL.")
    return(NULL)
  }
  if (!requireNamespace("happign", quietly = TRUE)) {
    cli::cli_warn("load_foret_ancienne_source() needs the {.pkg happign} package; returning NULL.")
    return(NULL)
  }

  aoi_geom <- sf::st_geometry(aoi)
  fa <- tryCatch(
    happign::get_wfs(aoi_geom, layer, ...),
    error = function(e) {
      cli::cli_warn(c(
        "load_foret_ancienne_source(): WFS fetch failed; returning NULL.",
        i = conditionMessage(e)))
      NA
    }
  )
  if (isTRUE(is.na(fa)[1])) return(NULL)

  # Aucune entité (hors métropole, ou pas de forêt ~1850 sur l'emprise).
  if (is.null(fa) || !inherits(fa, c("sf", "sfc"))) return(.foret_ancienne_empty(crs))
  fa <- sf::st_as_sf(fa)
  if (nrow(fa) == 0L) return(.foret_ancienne_empty(crs))

  fa <- sf::st_make_valid(fa)
  # Clip précis sur l'AOI (get_wfs ne filtre que par bbox).
  aoi_w <- sf::st_union(sf::st_transform(aoi_geom, sf::st_crs(fa)))
  fa <- suppressWarnings(sf::st_intersection(fa, aoi_w))
  build_foret_ancienne_mask(fa, crs = crs)
}
