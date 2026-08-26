# ============================================================
# load_insee_population.R — carroyage de population INSEE (spec 050)
# ------------------------------------------------------------
# Alimente S3. Le fichier ne change qu'une fois par an et pese 52 Mo zippe :
# il est mis en cache PAR MACHINE, pas par projet — un recalcul ne doit rien
# re-telecharger.
#
# Ce qui a ete verifie sur le fichier reel (2026-08-26), et qui contredit sa
# notice : la geometrie est en EPSG:2154 (Lambert-93), pas en 3035. C'est
# l'IDENTIFIANT du carreau qui porte la reference INSPIRE
# (`idcar_1km = "CRS3035RES1000mN2029000E4252000"`) — une chaine, pas une
# projection.
# ============================================================

.INSEE_FILOSOFI <- list(
  "1km" = list(
    url = "https://www.insee.fr/fr/statistiques/fichier/8735171/Filosofi2021_carreaux_1km_gpkg.zip",
    couches = c(FR = "carreaux_1km_met", MTQ = "carreaux_1km_mart",
                REU = "carreaux_1km_reun"),
    flag = "i_est_1km"
  ),
  "200m" = list(
    url = "https://www.insee.fr/fr/statistiques/fichier/8735162/Filosofi2021_carreaux_200m_gpkg.zip",
    couches = c(FR = "carreaux_200m_met", MTQ = "carreaux_200m_mart",
                REU = "carreaux_200m_reun"),
    flag = "i_est_200m"
  )
)


# Dossier de cache partage. Le millesime est dans le nom : deux millesimes
# cohabitent, et une annee nouvelle ne rend pas l'ancienne illisible.
.insee_cache_dir <- function(cache_dir = NULL, millesime = 2021, maille = "1km") {
  base <- cache_dir %||% file.path(
    Sys.getenv("XDG_CACHE_HOME", file.path(Sys.getenv("HOME"), ".cache")),
    "nemeton", "insee")
  file.path(base, sprintf("filosofi%d_%s", millesime, maille))
}


#' French population grid (INSEE Filosofi)
#'
#' @description
#' Downloads (once per machine) and reads the INSEE *Filosofi* population grid,
#' clipped to `aoi`. Feeds [indicateur_s3_population()].
#'
#' @details
#' **The clip happens at read time, not after.** Measured on the Couchey
#' massif: 1 024 cells read instead of the 374 511 the metropolitan layer
#' holds. Reading the whole of France to keep 0.3% of it would cost memory for
#' nothing.
#'
#' **Imputed cells are kept.** `i_est_1km == 1` marks a cell holding fewer than
#' 11 fiscal households, whose count INSEE *models* rather than observes.
#' Dropping them would remove real people — the imputation exists precisely so
#' totals stay right — and it would bite hardest where forests are: 42% of the
#' cells around Couchey are imputed, 53% within 20 km. They are kept, and the
#' share is reported back so the caller can say so
#' (see the `part_imputee` attribute).
#'
#' Licence Ouverte / Open Licence 2.0 (INSEE). Attribution required.
#'
#' @param aoi `sf`/`sfc` extent. Cells are read within its bounding box grown by
#'   `buffer_m`.
#' @param buffer_m Metres added around `aoi` before clipping. Default `21000`,
#'   enough for the 20 km ring S3 uses.
#' @param maille `"1km"` (default) or `"200m"`. 200 m is six times heavier and
#'   pointless for 5-20 km rings.
#' @param millesime Filosofi vintage. Only `2021` is wired.
#' @param crs Output CRS. Default `2154`.
#' @param territoire `"FR"` (metropolitan), `"MTQ"` or `"REU"`.
#' @param cache_dir Override the shared cache directory.
#'
#' @return An `sf` of grid cells with `ind` (individuals) and the imputation
#'   flag, or `NULL` when the source cannot be reached — **never a fabricated
#'   fallback** (spec 050, and the rule of v0.187.0).
#'   Carries a `part_imputee` attribute: share of cells that are imputed.
#'
#' @export
load_insee_population_source <- function(aoi,
                                         buffer_m = 21000,
                                         maille = c("1km", "200m"),
                                         millesime = 2021,
                                         crs = 2154,
                                         territoire = c("FR", "MTQ", "REU"),
                                         cache_dir = NULL) {
  maille <- match.arg(maille)
  territoire <- match.arg(territoire)

  if (!inherits(aoi, c("sf", "sfc"))) {
    cli::cli_warn("load_insee_population_source(): {.arg aoi} must be an sf/sfc; returning NULL.")
    return(NULL)
  }
  if (!identical(as.integer(millesime), 2021L)) {
    cli::cli_warn("Only the 2021 Filosofi vintage is wired; returning NULL.")
    return(NULL)
  }

  cfg <- .INSEE_FILOSOFI[[maille]]
  couche <- unname(cfg$couches[territoire])
  dir <- .insee_cache_dir(cache_dir, millesime, maille)
  gpkg <- file.path(dir, paste0(couche, ".gpkg"))

  if (!file.exists(gpkg)) {
    ok <- .insee_telecharger(cfg$url, dir)
    if (!isTRUE(ok) || !file.exists(gpkg)) {
      cli::cli_warn(c(
        "INSEE population grid unavailable; returning NULL.",
        i = "S3 will be {.val NA} — no fabricated fallback (spec 050)."
      ))
      return(NULL)
    }
  }

  emprise <- sf::st_as_sfc(sf::st_bbox(
    sf::st_buffer(sf::st_transform(sf::st_as_sf(aoi), 2154), buffer_m)))
  g <- tryCatch(
    sf::st_read(gpkg, query = sprintf('SELECT * FROM "%s"', couche),
                wkt_filter = sf::st_as_text(emprise), quiet = TRUE),
    error = function(e) {
      cli::cli_warn("Reading the INSEE grid failed: {conditionMessage(e)}")
      NULL
    })
  if (is.null(g) || nrow(g) == 0L) return(NULL)

  flag <- cfg$flag
  part <- if (flag %in% names(g)) mean(as.numeric(g[[flag]]) == 1, na.rm = TRUE) else NA_real_
  g <- sf::st_transform(g, crs)
  attr(g, "part_imputee") <- part
  attr(g, "millesime") <- as.integer(millesime)
  cli::cli_alert_success(
    "INSEE Filosofi {millesime} ({maille}) : {nrow(g)} carreau{?x}, \\
     {round(100 * part)}% impute{?s}."
  )
  g
}


# Telechargement + decompression, best-effort. Retourne TRUE/FALSE.
.insee_telecharger <- function(url, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  zip <- file.path(dir, "download.zip")
  cli::cli_alert_info("Downloading the INSEE population grid (~52 MB, once per machine)...")
  ok <- tryCatch({
    utils::download.file(url, zip, mode = "wb", quiet = TRUE)
    utils::unzip(zip, exdir = dir)
    TRUE
  }, error = function(e) {
    cli::cli_warn("INSEE download failed: {conditionMessage(e)}")
    FALSE
  })
  unlink(zip)
  isTRUE(ok) && length(list.files(dir, pattern = "\\.gpkg$")) > 0L
}
