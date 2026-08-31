#' Discover the best available DEM / CHM raster in a Nemeton project
#'
#' @description
#' Néméton projects accumulate digital terrain models (MNT / DEM /
#' DTM) and canopy height models (MNH / CHM) from several sources —
#' IGN RGE ALTI downloaded by tutorials, LiDAR HD MNT produced by
#' `lidR`, `opencanopy`'s `dtm.tif`, Open-Canopy CHM tiles —
#' each landing under its own naming convention. These helpers walk
#' a list of well-known locations in **priority order** (highest
#' quality first) and return the first match, so callers don't have
#' to hard-code paths.
#'
#' When multiple tiles sit in the same directory (e.g. several
#' `BD ALTI` tiles), the raster returned is a virtual mosaic
#' (`terra::vrt()`), so downstream `terra::extract` / `terra::crop`
#' calls transparently cover the full footprint.
#'
#' @section Search order (DEM):
#' \enumerate{
#'   \item `<project>/cache/layers/lidar_mnt/*.tif`  — LiDAR HD (1 m)
#'   \item `<project>/cache/layers/dem/*.tif`        — generic DEM cache
#'   \item `<project>/cache/layers/bd_alti/*.tif`    — IGN BD ALTI (25 m)
#'   \item `<project>/cache/layers/rge_alti/*.tif`   — IGN RGE ALTI (5 m)
#'   \item `<project>/cache/layers/dtm/*.tif`        — generic DTM cache
#'   \item `<project>/cache/layers/mnt/*.tif`        — generic MNT cache
#'   \item `<project>/cache/layers/dem.tif`          — direct file (v0.25.5)
#'   \item `<project>/cache/layers/dtm.tif`          — direct file (v0.25.5)
#'   \item `<project>/cache/layers/mnt.tif`          — direct file (v0.25.5)
#'   \item `<project>/dtm.tif`                        — `opencanopy` convention
#'   \item `<project>/dem.tif`                        — project root (v0.25.5)
#'   \item `<project>/mnt.tif`                        — tutorial convention
#'   \item `<project>/data/dtm.tif`                   — alt project layout
#'   \item `<project>/data/dem.tif`                   — alt project layout (v0.25.5)
#'   \item `<project>/data/mnt.tif`                   — alt project layout
#' }
#'
#' @section Search order (CHM):
#' \enumerate{
#'   \item `<project>/cache/layers/lidar_mnh/*.tif`  — LiDAR HD MNH
#'   \item `<project>/cache/layers/mnh/*.tif`        — generic MNH cache
#'   \item `<project>/cache/layers/opencanopy/chm_predicted_0_2m.tif`
#'         — Open-Canopy CHM 0.2 m (v0.192.2)
#'   \item `<project>/cache/layers/opencanopy/chm_predicted_1_5m.tif`
#'         — Open-Canopy CHM 1.5 m (v0.192.2)
#'   \item `<project>/cache/layers/opencanopy/chm_1_5m.tif`
#'         — Open-Canopy CHM, completion witness (v0.192.2)
#'   \item `<project>/cache/layers/chm/*.tif`        — generic CHM cache
#'   \item `<project>/cache/layers/chm.tif`          — direct file (v0.25.5)
#'   \item `<project>/cache/layers/mnh.tif`          — direct file (v0.25.5)
#'   \item `<project>/chm.tif`                        — single-file convention
#'   \item `<project>/mnh.tif`                        — tutorial convention
#'   \item `<project>/data/chm.tif`                   — alt project layout
#'   \item `<project>/data/mnh.tif`                   — alt project layout
#' }
#'
#' The Open-Canopy entries are named file by file on purpose:
#' `cache/layers/opencanopy/` also holds orthophotos (`ortho_rvb.tif`,
#' `ortho_irc.tif`) and spectral indices (`ndvi.tif`, `ndwi.tif`, ...),
#' which a directory-wide candidate would mosaic together with the
#' height models. `chm_vegetation_0_2m.tif` is excluded as well: it is
#' a masked derivative, not the reference height model.
#'
#' @param project_path Character. Root of the Nemeton project tree.
#' @param load Logical. When `TRUE` (default), open the raster via
#'   `terra::rast()` (or `terra::vrt()` for multi-tile dirs) and
#'   return the `SpatRaster`. When `FALSE`, return the matching
#'   path(s) as a character vector — useful for diagnostics and for
#'   callers that want to control how the raster is loaded.
#' @param verbose Logical. When `TRUE`, log every probed location
#'   via `cli::cli_alert_info()`. Default `FALSE`.
#' @param try_compute_from_laz Logical. When no pre-rasterized MNT /
#'   MNH is found *and* `<project>/cache/layers/lidar_nuage/*.laz`
#'   tiles are present, attempt to derive them on the fly with
#'   [`compute_dtm_chm_from_laz()`] (via `lasR`) and re-probe. Default
#'   `TRUE`. The fallback is opportunistic: missing `lasR` simply skips
#'   it without erroring.
#' @param validate Function or `NULL` (default). A predicate taking the
#'   candidate `SpatRaster` and returning a single `TRUE` / `FALSE`.
#'   A candidate turned down is **skipped, and the search continues
#'   with the next source** — which is the point: existence is not
#'   usability, and a height model with no height above the ground is
#'   not a height model. Callers used to re-probe by hand to work
#'   around this; they no longer have to (v0.193.0). The predicate is
#'   *theirs*, not the resolver's: a 5 m canopy threshold belongs to
#'   whoever segments crowns, not to a path resolver. Note that
#'   `validate` opens every probed candidate, and applies even when
#'   `load = FALSE` (the paths are returned, but the raster is read to
#'   judge it). Errors raised inside the predicate propagate: wrap it
#'   yourself if a broken file should mean "skip" rather than "stop".
#'
#' @return When `load = TRUE`: a `SpatRaster`, or `NULL` if no
#'   matching raster exists. When `load = FALSE`: a character vector
#'   of file paths (length 1 for single-file matches, longer for
#'   tile directories), or `NULL`. The returned object also carries
#'   the matched layer label as attribute `"nemeton_dem_layer"` /
#'   `"nemeton_chm_layer"`.
#'
#' @name resolve_project_layers
NULL


# Probe one candidate location. Returns:
#   - NULL when nothing matches
#   - A character vector of file paths otherwise (length >= 1)
.probe_raster_candidate <- function(cand, verbose) {
  if (!dir.exists(cand$dir)) {
    if (verbose) {
      cli::cli_alert_info("Skip {.val {cand$label}}: directory does not exist.")
    }
    return(NULL)
  }
  hits <- if (!is.null(cand$file)) {
    list.files(cand$dir,
               pattern     = sprintf("^%s$", cand$file),
               full.names  = TRUE,
               ignore.case = TRUE)
  } else {
    list.files(cand$dir,
               pattern     = "\\.tif$",
               full.names  = TRUE,
               ignore.case = TRUE,
               recursive   = isTRUE(cand$recursive))
  }
  if (!length(hits)) {
    if (verbose) {
      cli::cli_alert_info("Skip {.val {cand$label}}: no matching file in {.path {cand$dir}}.")
    }
    return(NULL)
  }
  if (verbose) {
    cli::cli_alert_success(
      "Found {.val {cand$label}}: {length(hits)} file{?s} at {.path {cand$dir}}."
    )
  }
  hits
}


.open_raster <- function(paths) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required to load the resolved raster.")
  }
  if (length(paths) == 1L) {
    terra::rast(paths)
  } else {
    # Virtual mosaic — zero-copy, all downstream terra ops work.
    terra::vrt(paths)
  }
}


.materialise_raster <- function(paths, load, layer_label, attr_name) {
  if (!load) {
    attr(paths, attr_name) <- layer_label
    return(paths)
  }
  r <- .open_raster(paths)
  attr(r, attr_name) <- layer_label
  r
}


.check_validate_arg <- function(validate) {
  if (is.null(validate) || is.function(validate)) return(invisible(validate))
  cli::cli_abort("{.arg validate} must be a function or {.code NULL}.")
}


# Walk the candidates in priority order and return the first match.
# When `validate` is supplied, a candidate whose raster fails the
# predicate is *skipped* and the search continues with the next source
# — that is the whole point: a height model with no height is not a
# height model, and the caller shouldn't have to re-probe by hand
# (v0.193.0).
.resolve_first_candidate <- function(candidates, load, attr_name,
                                     validate, verbose) {
  for (cand in candidates) {
    hits <- .probe_raster_candidate(cand, verbose = verbose)
    if (is.null(hits)) next
    if (is.null(validate)) {
      return(.materialise_raster(hits, load, cand$label, attr_name = attr_name))
    }
    r  <- .open_raster(hits)
    ok <- validate(r)
    if (!is.logical(ok) || length(ok) != 1L || is.na(ok)) {
      cli::cli_abort(c(
        "{.arg validate} must return a single {.code TRUE} or {.code FALSE}.",
        i = "Candidate {.val {cand$label}} returned {.obj_type_friendly {ok}}."
      ))
    }
    if (!ok) {
      if (verbose) {
        cli::cli_alert_info(
          "Reject {.val {cand$label}}: turned down by {.arg validate}."
        )
      }
      next
    }
    if (!load) {
      attr(hits, attr_name) <- cand$label
      return(hits)
    }
    attr(r, attr_name) <- cand$label
    return(r)
  }
  NULL
}


.validate_project_path <- function(project_path) {
  if (!is.character(project_path) || length(project_path) != 1L ||
      !nzchar(project_path)) {
    cli::cli_abort("{.arg project_path} must be a single non-empty path.")
  }
  if (!dir.exists(project_path)) {
    cli::cli_abort("{.arg project_path} does not exist: {.path {project_path}}")
  }
  invisible(project_path)
}


#' @rdname resolve_project_layers
#' @examples
#' \dontrun{
#' dem <- resolve_project_dem("C:/.../projects/20260416_112240_gomv",
#'                            verbose = TRUE)
#' if (is.null(dem)) {
#'   stop("No DEM found — download one with opencanopy or happign.")
#' }
#' attr(dem, "nemeton_dem_layer")  # "opencanopy DTM"
#' plan <- create_sampling_plan(zone, mnt = dem, ...)
#' }
#' @export
resolve_project_dem <- function(project_path,
                                load                 = TRUE,
                                verbose              = FALSE,
                                try_compute_from_laz = TRUE,
                                validate             = NULL) {
  .validate_project_path(project_path)
  .check_validate_arg(validate)

  candidates <- list(
    list(label = "LiDAR HD MNT",
         dir   = file.path(project_path, "cache", "layers", "lidar_mnt")),
    list(label = "generic DEM cache",
         dir   = file.path(project_path, "cache", "layers", "dem")),
    list(label = "IGN BD ALTI",
         dir   = file.path(project_path, "cache", "layers", "bd_alti")),
    list(label = "IGN RGE ALTI",
         dir   = file.path(project_path, "cache", "layers", "rge_alti")),
    list(label = "generic DTM cache",
         dir   = file.path(project_path, "cache", "layers", "dtm")),
    list(label = "generic MNT cache",
         dir   = file.path(project_path, "cache", "layers", "mnt")),
    # v0.25.5 — files placed *directly* under cache/layers/ (no
    # sub-directory). Some downloaders (opencanopy's recent
    # convention, manual pulls) drop the raster as
    # <project>/cache/layers/{dem,dtm,mnt}.tif rather than under a
    # named sub-directory. Probed before the project-root fallbacks
    # because cache/ is the more discoverable convention.
    list(label = "cache/layers/dem.tif",
         dir   = file.path(project_path, "cache", "layers"),
         file  = "dem.tif"),
    list(label = "cache/layers/dtm.tif",
         dir   = file.path(project_path, "cache", "layers"),
         file  = "dtm.tif"),
    list(label = "cache/layers/mnt.tif",
         dir   = file.path(project_path, "cache", "layers"),
         file  = "mnt.tif"),
    list(label = "opencanopy DTM",
         dir   = project_path,
         file  = "dtm.tif"),
    list(label = "project DEM",
         dir   = project_path,
         file  = "dem.tif"),
    list(label = "tutorial MNT",
         dir   = project_path,
         file  = "mnt.tif"),
    list(label = "data/dtm.tif",
         dir   = file.path(project_path, "data"),
         file  = "dtm.tif"),
    list(label = "data/dem.tif",
         dir   = file.path(project_path, "data"),
         file  = "dem.tif"),
    list(label = "data/mnt.tif",
         dir   = file.path(project_path, "data"),
         file  = "mnt.tif")
  )

  found <- .resolve_first_candidate(candidates, load, "nemeton_dem_layer",
                                   validate = validate, verbose = verbose)
  if (!is.null(found)) return(found)

  # Fallback: derive MNT from <project>/cache/layers/lidar_nuage via lasR.
  if (isTRUE(try_compute_from_laz) &&
      .maybe_compute_lidar_rasters(project_path, target = "dtm",
                                   verbose = verbose)) {
    found <- .resolve_first_candidate(candidates, load, "nemeton_dem_layer",
                                     validate = validate, verbose = verbose)
    if (!is.null(found)) return(found)
  }

  if (verbose) {
    cli::cli_alert_warning("No DEM found anywhere under {.path {project_path}}.")
  }
  NULL
}


#' @rdname resolve_project_layers
#' @examples
#' \dontrun{
#' chm <- resolve_project_chm("C:/.../projects/20260416_112240_gomv")
#' plan <- create_sampling_plan(zone, mnt = dem, chm = chm, ...)
#' }
#' @export
resolve_project_chm <- function(project_path,
                                load                 = TRUE,
                                verbose              = FALSE,
                                try_compute_from_laz = TRUE,
                                validate             = NULL) {
  .validate_project_path(project_path)
  .check_validate_arg(validate)

  # ADR-007 : le LiDAR local prime sur un produit ML — il porte un NDP
  # superieur. Les entrees Open-Canopy sont nommees fichier par fichier :
  # `cache/layers/opencanopy/` contient aussi des orthophotos et des
  # indices spectraux, qu'un candidat sans `file` mosaiquerait avec les
  # modeles de hauteur (v0.192.2).
  candidates <- list(
    list(label = "LiDAR HD MNH",
         dir   = file.path(project_path, "cache", "layers", "lidar_mnh")),
    list(label = "generic MNH cache",
         dir   = file.path(project_path, "cache", "layers", "mnh")),
    list(label = "Open-Canopy CHM 0,2 m",
         dir   = file.path(project_path, "cache", "layers", "opencanopy"),
         file  = "chm_predicted_0_2m.tif"),
    list(label = "Open-Canopy CHM 1,5 m",
         dir   = file.path(project_path, "cache", "layers", "opencanopy"),
         file  = "chm_predicted_1_5m.tif"),
    list(label = "Open-Canopy CHM (temoin)",
         dir   = file.path(project_path, "cache", "layers", "opencanopy"),
         file  = "chm_1_5m.tif"),
    # Repertoire sans producteur connu : le libelle ne dit plus
    # « Open-Canopy », qui n'ecrit pas la (v0.192.2).
    list(label = "cache/layers/chm/",
         dir   = file.path(project_path, "cache", "layers", "chm")),
    # v0.25.5 — direct files under cache/layers/ (same rationale as
    # the DEM version above).
    list(label = "cache/layers/chm.tif",
         dir   = file.path(project_path, "cache", "layers"),
         file  = "chm.tif"),
    list(label = "cache/layers/mnh.tif",
         dir   = file.path(project_path, "cache", "layers"),
         file  = "mnh.tif"),
    list(label = "single-file CHM",
         dir   = project_path,
         file  = "chm.tif"),
    list(label = "tutorial MNH",
         dir   = project_path,
         file  = "mnh.tif"),
    list(label = "data/chm.tif",
         dir   = file.path(project_path, "data"),
         file  = "chm.tif"),
    list(label = "data/mnh.tif",
         dir   = file.path(project_path, "data"),
         file  = "mnh.tif")
  )

  found <- .resolve_first_candidate(candidates, load, "nemeton_chm_layer",
                                   validate = validate, verbose = verbose)
  if (!is.null(found)) return(found)

  # Fallback: derive MNH from <project>/cache/layers/lidar_nuage via lasR.
  if (isTRUE(try_compute_from_laz) &&
      .maybe_compute_lidar_rasters(project_path, target = "chm",
                                   verbose = verbose)) {
    found <- .resolve_first_candidate(candidates, load, "nemeton_chm_layer",
                                     validate = validate, verbose = verbose)
    if (!is.null(found)) return(found)
  }

  if (verbose) {
    cli::cli_alert_warning("No CHM found anywhere under {.path {project_path}}.")
  }
  NULL
}
