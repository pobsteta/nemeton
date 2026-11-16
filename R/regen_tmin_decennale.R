# regen_tmin_decennale.R — froid d'hiver de la station pour le classement des
# essences (regen_rank_species(), filtre éliminatoire « froid d'hiver »).
# ------------------------------------------------------------------
# Brief nemetonmcp 2026-11-15 (Pin d'Alep en tête à Couchey). Grandeur retenue
# par Pascal le 2026-11-16 : le MINIMUM DÉCENNAL, 10e percentile des minimums
# absolus annuels de E-OBS TN sur 1991-2020 (« un hiver sur dix descend à »),
# à comparer à `frost_winter_min_c` de european_species_tolerances(). La
# moyenne (grandeur USDA, d'abord retenue) effaçait les hivers rares qui tuent
# une plantation : à Couchey -10,1 °C, Pin d'Alep (-12) gardé ; décennal -13,2.

#' Station winter cold (ten-year minimum) from E-OBS
#'
#' @description
#' Adds to `units` the ten-year minimum temperature (`tmin_decennale`, °C):
#' the `prob` quantile (default 0.1, a winter that comes back once in ten
#' years) of the annual absolute minimum temperatures over `years` (default
#' 1991-2020), read from the E-OBS daily minimum temperature (`tn`, via
#' [load_eobs_source()]), and the number of complete years behind it
#' (`tmin_decennale_n_annees`). This is the station
#' input of the winter-cold filter of [regen_rank_species()]: a species whose
#' `frost_winter_min_c` is warmer than `tmin_decennale` is excluded.
#'
#' Each unit takes the E-OBS cell (0.1°, about 11 km) under a point on its
#' surface: the value describes the local climate, not the unit itself
#' (frost hollows can be colder).
#'
#' @param units An `sf` of management units.
#' @param tn Optional daily E-OBS `tn` netCDF path (for instance the full-period
#'   ECA&D file `tn_ens_mean_0.1deg_reg_v<version>.nc`) or a dated
#'   `SpatRaster`, used instead of the CDS download.
#' @param years Integer years used (default `1991:2020`). A year with less
#'   than 90% of its days is dropped.
#' @param prob Quantile of the annual minima (default `0.1`, the ten-year
#'   minimum; `0` gives the absolute minimum of the period, `0.5` the median).
#' @param source `"knmi"` (default) downloads once the full-period daily file
#'   from the public KNMI (ECA&D) store into `cache_dir`, as for the E-OBS
#'   climate context; `"cds"` downloads the Copernicus CDS blocks covering
#'   `years` through [load_eobs_source()]. Ignored when `tn` is given.
#' @param cache_dir Directory of the downloaded files (default: the shared
#'   machine cache, `file.path(get_global_cache_dir(), "eobs")`).
#' @param version E-OBS version (default `"33.0e"` for KNMI, `"30.0e"` for the
#'   CDS).
#' @param progress_callback Optional progress callback (see
#'   [load_eobs_source()]).
#'
#' @return `units` with `tmin_decennale` (°C, rounded to 0.1) and
#'   `tmin_decennale_n_annees`. When E-OBS is unavailable (warning from
#'   [load_eobs_source()]), both are `NA` / `0`, and the filter of
#'   [regen_rank_species()] is skipped.
#' @section Lifecycle:
#' Experimental: may change in any release, without deprecation (spec 057).
#'
#' @seealso [regen_rank_species()], [load_eobs_source()],
#'   [european_species_tolerances()]
#' @examples
#' \dontrun{
#'   units <- regen_tmin_decennale(units, tn = "tn_ens_mean_0.1deg_reg_v33.0e.nc")
#'   regen_rank_species(units)
#' }
#' @export
regen_tmin_decennale <- function(units, tn = NULL, years = 1991:2020,
                                 prob = 0.1, source = "knmi", cache_dir = NULL,
                                 version = NULL, progress_callback = NULL) {
  validate_sf(units)
  if (!is.numeric(prob) || length(prob) != 1L || is.na(prob) ||
      prob < 0 || prob > 1) {
    cli::cli_abort("{.arg prob} must be a single number in [0, 1].")
  }
  n <- nrow(units)
  units$tmin_decennale <- rep(NA_real_, n)
  units$tmin_decennale_n_annees <- rep(0L, n)
  if (!n) return(units)

  # Zone élargie de 15 km (plus d'une maille E-OBS) : une petite UGF n'a sinon
  # aucun centre de maille dedans, et le masque la viderait.
  geom <- sf::st_transform(sf::st_geometry(units), 3035)
  zone <- sf::st_buffer(sf::st_union(geom), 15000)

  if (is.null(version)) version <- if (identical(source, "cds")) "30.0e" else "33.0e"
  if (is.null(tn) && identical(source, "knmi")) {
    emit <- function(payload) {
      if (!is.null(progress_callback)) progress_callback(payload)
    }
    dir <- .climat_eobs_dir(cache_dir)
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    tn <- tryCatch(terra::rast(.eobs_knmi_fetch("tn", version, dir, emit),
                               subds = "tn"),
                   error = function(e) {
                     cli::cli_warn(c("E-OBS {.val tn} unavailable (knmi).",
                                     x = conditionMessage(e)))
                     NULL
                   })
    if (is.null(tn)) return(units)
  }
  annuel <- load_eobs_source(zone, var = "tn", years = years, months = 1:12,
                             source = source, reducer = "min", nc = tn,
                             cache_dir = cache_dir, version = version,
                             progress_callback = progress_callback)
  if (is.null(annuel)) return(units)

  # Quantile type 7 (défaut de R) des minimums annuels, maille par maille.
  q10 <- terra::app(annuel, function(v) {
    v <- v[!is.na(v)]
    if (!length(v)) NA_real_ else stats::quantile(v, prob, names = FALSE)
  })
  nb <- terra::app(!is.na(annuel), "sum")
  pts <- terra::vect(sf::st_transform(sf::st_point_on_surface(geom),
                                      terra::crs(q10)))
  units$tmin_decennale <- round(terra::extract(q10, pts)[, 2], 1)
  units$tmin_decennale_n_annees <- as.integer(terra::extract(nb, pts)[, 2])
  units$tmin_decennale_n_annees[is.na(units$tmin_decennale)] <- 0L
  units
}
