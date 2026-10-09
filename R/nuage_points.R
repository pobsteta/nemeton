# nuage_points.R — MNT, MNS et MNH depuis un nuage de points (spec 059)
# ------------------------------------------------------------------
# Trois sources, un seul point d'entrée :
#   * lidar_ign       : nuage IGN LiDAR HD livré sans ses rasters dérivés ;
#   * lidar_drone     : LiDAR drone, en général non classé ;
#   * photogrammetrie : nuage SfM d'un drone RGB, sans sol sous couvert.
# Décisions de Pascal (2026-10-09) : on reclasse toujours par défaut, IGN
# compris ; l'eau (9) compte comme sol ; le recalage vertical de la
# photogrammétrie s'appuie sur le MNH IGN ; les produits drone font passer le
# projet en NDP 2 et passent avant ceux de l'IGN dans resolve_project_*().

# Classes LAS de bruit (ASPRS 7 bas, 18 haut) : celles que posent
# classify_with_ivf() / classify_with_sor(). Les classes exclues des MNx
# (bruit + IGN 65/66) sont dans `.LAS_CLASSES_EXCLUES` (lidar_processing.R).
.NUAGE_BRUIT <- c(7L, 18L)
# Classes IGN supprimées avant tout traitement : artefacts (65) et points
# virtuels sous les ponts (66). Reclassés, ils redeviendraient du sol ou du
# sursol.
.NUAGE_IGN_A_SUPPRIMER <- c(65L, 66L)
# Classes du TIN de sol : sol (2) et eau (9).
.NUAGE_SOL <- c(2L, 9L)
# Seuil de sol nu pour le recalage vertical : MNH de référence < 0,5 m.
.NUAGE_SOL_NU_M <- 0.5
# Nombre minimal de pixels de sol nu pour estimer un décalage.
.NUAGE_MIN_SOL_NU <- 100L


#' Derive DTM, DSM and CHM rasters from a point cloud
#'
#' @description
#' Builds the three elevation models from a point cloud, whatever its source
#' (spec 059):
#'
#' * `"lidar_ign"`: IGN LiDAR HD tiles delivered without their derived MNT /
#'   MNS / MNH rasters;
#' * `"lidar_drone"`: drone LiDAR, usually unclassified;
#' * `"photogrammetrie"`: a structure-from-motion cloud from an RGB drone. It
#'   only sees the canopy surface, so the terrain comes from `mnt_externe`.
#'
#' The **DTM** (MNT) is the ground surface, the **DSM** (MNS) the highest
#' surface (canopy, buildings) and the **CHM** (MNH) the height above ground.
#'
#' @details
#' **LiDAR sources** (`"lidar_ign"`, `"lidar_drone"`) run one
#' [lasR](https://r-lidar.github.io/lasR/) pass:
#' 1. With `classifier = TRUE` (default), every class is reset, isolated
#'    points are flagged as noise (`classify_with_ivf()`, class 18) and the
#'    ground is classified again (`classify_with_csf()`, or
#'    `classify_with_ptd()`). IGN classes are thus not trusted as delivered.
#' 2. A TIN of ground and water points (classes 2 and 9) gives the DTM.
#' 3. The DSM is the highest non-noise point of each cell.
#' 4. Points are normalised against the TIN and the CHM is the highest
#'    normalised point, which is more accurate on slopes than DSM - DTM.
#'    Negative heights are set to 0.
#'
#' **Photogrammetry** keeps the drone DSM (noise removed with
#' `classify_with_sor()`) and never derives a terrain from it. `mnt_externe`,
#' typically the IGN LiDAR HD DTM, is resampled onto the DSM grid (bilinear).
#' A SfM cloud is often shifted vertically (no ground control points,
#' ellipsoidal heights): with `recalage_vertical = TRUE`, the shift is the
#' median of DSM - DTM over bare-ground cells, i.e. cells where `mnh_reference`
#' (the IGN CHM) is below 0.5 m, and it is removed from the DSM. The CHM is
#' DSM - DTM, negative heights set to 0.
#'
#' On the IGN tile `LHD_FXX_0633_6767` (20.7 M points), the reclassified DTM
#' matches the published IGN DTM within 1.1 cm (median, 95th percentile
#' 7.7 cm) and the CHM within 0 m (median); a 2.30 m shift added to the DSM is
#' recovered within 3 mm.
#'
#' **Outputs** are written as `mnt.tif`, `mns.tif` and `mnh.tif` in three
#' sub-directories of `dossier`: `ign_mnt/`, `ign_mns/`, `ign_mnh/` for
#' `"lidar_ign"`, `drone_mnt/`, `drone_mns/`, `drone_mnh/` otherwise. In a
#' project (`dossier` = `<project>/cache/layers`), [resolve_project_dem()] and
#' [resolve_project_chm()] pick the drone products first, then the published
#' IGN rasters, then the `ign_*` ones, and the drone products raise the
#' project to NDP 2. The LiDAR pass is cached: it is re-run only when the
#' tiles, the resolution or the classification settings change.
#'
#' @param nuage Character. A directory of `.las` / `.laz` / `.copc.laz` files,
#'   or a vector of such files.
#' @param type One of `"lidar_ign"`, `"lidar_drone"`, `"photogrammetrie"`.
#' @param res Numeric. Output resolution in metres. `NULL` (default): 0.5 for
#'   `"lidar_ign"` (as the published IGN rasters), 0.25 for drone sources.
#' @param classifier Logical. Reset and reclassify noise and ground before
#'   building the models. Default `TRUE`. With `FALSE`, the classes of the
#'   file are used as they are (ground and water must be present for the
#'   LiDAR types). For `"photogrammetrie"`, only noise is classified.
#' @param methode_sol Ground classification: `"csf"` (cloth simulation,
#'   default) or `"ptd"` (progressive TIN densification).
#' @param csf Named list of arguments passed to `lasR::classify_with_csf()`,
#'   overriding the defaults (`slope_smooth = TRUE`, `cloth_resolution = 0.5`,
#'   `rigidness = 1`, `class_threshold = 0.5`).
#' @param mnt_externe `SpatRaster` or path. Terrain for `"photogrammetrie"`
#'   (required there, ignored otherwise).
#' @param mnh_reference `SpatRaster` or path. Reference CHM (IGN LiDAR HD MNH)
#'   used to find bare ground for the vertical shift of `"photogrammetrie"`.
#' @param recalage_vertical Logical. Estimate and remove the vertical shift of
#'   a photogrammetric DSM. Default `TRUE`; skipped with a warning when
#'   `mnh_reference` is missing or holds fewer than 100 bare-ground cells.
#' @param aoi Optional `sf` / `sfc`. When supplied, cropped and masked copies
#'   are returned (written under `aoi/` in each output directory); the
#'   full-extent rasters stay in place.
#' @param dossier Character. Parent directory of the outputs. `NULL`
#'   (default): the parent of the cloud's directory, i.e.
#'   `<project>/cache/layers` for a cloud under
#'   `<project>/cache/layers/<name>/`.
#' @param ncores Integer. Number of files processed concurrently by lasR.
#'   Default 1.
#' @param overwrite Logical. Re-run the LiDAR pass even if a cache with the
#'   same key exists. Default `FALSE`.
#' @param verbose Logical. Progress messages. Default `TRUE`.
#'
#' @return A list:
#' * `mnt`, `mns`, `mnh`: paths of the GeoTIFFs;
#' * `classes`: number of points per class after processing;
#' * `qualite`: list with `n_points`, `densite` (points per m²), `part_sol`
#'   (share of non-noise points classified as ground, `NA` for
#'   photogrammetry), `part_bruit`, `part_mnh_negatif` (share of CHM cells
#'   below -0.5 m before clamping), `decalage_vertical`, `decalage_iqr` and
#'   `n_sol_nu` (photogrammetry);
#' * `elapsed`: duration of the LiDAR pass (0 when served from cache).
#'
#' A warning is issued when less than 5 \% of the points are ground, or when
#' the bare-ground differences are too spread (interquartile range above
#' 0.5 m) for the vertical shift to be trusted.
#'
#' @section Lifecycle:
#' Experimental (spec 059): may change in any release.
#'
#' @seealso [compute_dtm_chm_from_laz()], [resolve_project_dem()],
#'   [resolve_project_chm()]
#'
#' @examples
#' \dontrun{
#' couches <- file.path(projet, "cache", "layers")
#' # IGN cloud delivered alone
#' ign <- traiter_nuage_points(file.path(couches, "lidar_nuage"),
#'                             type = "lidar_ign", ncores = 4)
#' # Photogrammetric drone flight, terrain from IGN
#' sfm <- traiter_nuage_points(file.path(couches, "drone_nuage"),
#'                             type = "photogrammetrie",
#'                             mnt_externe = ign$mnt,
#'                             mnh_reference = ign$mnh)
#' sfm$qualite$decalage_vertical
#' }
#' @export
traiter_nuage_points <- function(nuage,
                                 type              = c("lidar_ign", "lidar_drone",
                                                       "photogrammetrie"),
                                 res               = NULL,
                                 classifier        = TRUE,
                                 methode_sol       = c("csf", "ptd"),
                                 csf               = list(),
                                 mnt_externe       = NULL,
                                 mnh_reference     = NULL,
                                 recalage_vertical = TRUE,
                                 aoi               = NULL,
                                 dossier           = NULL,
                                 ncores            = 1L,
                                 overwrite         = FALSE,
                                 verbose           = TRUE) {
  type        <- match.arg(type)
  methode_sol <- match.arg(methode_sol)
  for (pkg in c("lasR", "terra")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      cli::cli_abort(c(
        "{.pkg {pkg}} is required by {.fn traiter_nuage_points}.",
        i = if (pkg == "lasR") "Install it from r-universe: {.code install.packages('lasR', repos = 'https://r-lidar.r-universe.dev')}"
      ))
    }
  }
  if (!is.list(csf) || (length(csf) && is.null(names(csf)))) {
    cli::cli_abort("{.arg csf} must be a named list.")
  }
  if (!isTRUE(classifier) && !isFALSE(classifier)) {
    cli::cli_abort("{.arg classifier} must be {.code TRUE} or {.code FALSE}.")
  }
  photo <- identical(type, "photogrammetrie")
  if (photo && is.null(mnt_externe)) {
    cli::cli_abort(c(
      "A photogrammetric cloud has no ground under canopy: {.arg mnt_externe} is required.",
      i = "Use the IGN LiDAR HD DTM ({.fn resolve_project_dem}), or derive it with {.code traiter_nuage_points(type = \"lidar_ign\")}."
    ))
  }

  fichiers <- .nuage_fichiers(nuage)
  if (is.null(res)) res <- if (identical(type, "lidar_ign")) 0.5 else 0.25
  if (!is.numeric(res) || length(res) != 1L || !is.finite(res) || res <= 0) {
    cli::cli_abort("{.arg res} must be a single positive number of metres.")
  }
  if (is.null(dossier)) dossier <- dirname(dirname(fichiers[1]))
  prefixe <- if (identical(type, "lidar_ign")) "ign" else "drone"
  chemins <- c(
    mnt = file.path(dossier, paste0(prefixe, "_mnt"), "mnt.tif"),
    mns = file.path(dossier, paste0(prefixe, "_mns"), "mns.tif"),
    mnh = file.path(dossier, paste0(prefixe, "_mnh"), "mnh.tif")
  )
  for (d in unique(dirname(chemins))) dir.create(d, recursive = TRUE, showWarnings = FALSE)

  # Le passage lasR est mis en cache ; pour la photogrammétrie il ne produit
  # que le MNS brut (non recalé), gardé à part, le reste se refait en terra.
  csf_args <- utils::modifyList(
    list(slope_smooth = TRUE, class_threshold = 0.5, cloth_resolution = 0.5,
         rigidness = 1L), csf)
  cle <- rlang::hash(list(.lasr_cache_key(fichiers, res), type, classifier,
                          methode_sol, csf_args))
  sorties_lasr <- if (photo) {
    c(mns = file.path(dirname(chemins[["mns"]]), ".mns_brut.tif"))
  } else {
    chemins
  }
  stats_path <- file.path(dirname(chemins[["mns"]]), ".nuage_stats.rds")
  reuse <- !overwrite && file.exists(stats_path) &&
    all(vapply(sorties_lasr, .nuage_cache_valide, logical(1), cle = cle))

  if (reuse) {
    if (verbose) cli::cli_alert_info("Point-cloud products already up to date (use {.code overwrite = TRUE} to rebuild).")
    stats <- readRDS(stats_path)
    elapsed <- as.difftime(0, units = "secs")
  } else {
    if (verbose) {
      cli::cli_alert_info("lasR pass on {length(fichiers)} file{?s} ({type}, res = {res} m, classifier = {classifier}) ...")
    }
    tmp <- vapply(sorties_lasr, .atomic_tmp_path, character(1))
    on.exit(unlink(tmp, force = TRUE), add = TRUE)
    unlink(paste0(sorties_lasr, ".key"), force = TRUE)
    t0 <- Sys.time()
    ans <- tryCatch(
      .nuage_lasr(fichiers, type, res, classifier, methode_sol, csf_args,
                  tmp, ncores),
      error = function(e) {
        cli::cli_abort(c("lasR pass failed: {conditionMessage(e)}",
                         i = "No partial output was kept."), call = NULL)
      })
    elapsed <- difftime(Sys.time(), t0, units = "secs")
    stats <- .nuage_stats(ans)
    if (!photo && !(stats$part_sol > 0)) {
      cli::cli_abort(c(
        "The cloud has no ground (class 2) or water (class 9) point.",
        i = "Run with {.code classifier = TRUE} to classify the ground."
      ))
    }
    lisibles <- vapply(tmp, .raster_lisible, logical(1))
    if (!all(lisibles)) {
      cli::cli_abort("lasR output unreadable ({.val {names(tmp)[!lisibles]}}); nothing cached.")
    }
    if (!photo) {
      # MNH : hauteurs négatives (sol interpolé au-dessus d'un point) à 0.
      stats$part_mnh_negatif <- .nuage_ecreter(tmp[["mnh"]])
    }
    for (n in names(tmp)) .atomic_promote(tmp[[n]], sorties_lasr[[n]])
    .atomic_write(stats_path, function(f) saveRDS(stats, f))
    # Clés écrites en dernier : un cache sans clé n'est jamais resservi.
    for (p in sorties_lasr) .atomic_write(paste0(p, ".key"), function(f) writeLines(cle, f))
  }

  qualite <- list(
    n_points = stats$n_points,
    densite  = NA_real_,
    part_sol = if (photo) NA_real_ else stats$part_sol,
    part_bruit = stats$part_bruit,
    part_mnh_negatif = stats$part_mnh_negatif %||% NA_real_,
    decalage_vertical = NA_real_,
    decalage_iqr = NA_real_,
    n_sol_nu = NA_integer_
  )
  if (photo) {
    recal <- .nuage_photogrammetrie(sorties_lasr[["mns"]], mnt_externe,
                                    mnh_reference, recalage_vertical, chemins,
                                    verbose)
    qualite[names(recal)] <- recal
  }
  mns_r <- terra::rast(chemins[["mns"]])
  n_cell <- terra::global(!is.na(mns_r), "sum")[[1]]
  if (is.finite(n_cell) && n_cell > 0) {
    qualite$densite <- stats$n_points / (n_cell * prod(terra::res(mns_r)))
  }
  if (!photo && is.finite(qualite$part_sol) && qualite$part_sol < 0.05) {
    cli::cli_warn(c(
      "Only {round(100 * qualite$part_sol, 1)} % of the points were classified as ground.",
      i = "The DTM is interpolated over large gaps; check {.arg methode_sol} and {.arg csf}."
    ))
  }

  sorties <- as.list(chemins)
  if (!is.null(aoi)) {
    cle_aoi <- .lasr_aoi_key(aoi, cle)
    sorties <- Map(function(p, n) .lasr_crop_copy(p, aoi, cle_aoi, n),
                   chemins, names(chemins))
  }
  if (verbose && !reuse) {
    cli::cli_alert_success("Point cloud processed in {format_duration(as.numeric(elapsed))}: MNT, MNS and MNH under {.path {dossier}}.")
  }
  list(mnt = sorties[["mnt"]], mns = sorties[["mns"]], mnh = sorties[["mnh"]],
       classes = stats$classes, qualite = qualite, elapsed = elapsed)
}


# ---- helpers ------------------------------------------------------

.nuage_fichiers <- function(nuage) {
  if (!is.character(nuage) || !length(nuage) || anyNA(nuage) || !all(nzchar(nuage))) {
    cli::cli_abort("{.arg nuage} must be a directory or a vector of .las/.laz files.")
  }
  motif <- "\\.(copc\\.laz|laz|las)$"
  if (length(nuage) == 1L && dir.exists(nuage)) {
    f <- list.files(nuage, pattern = motif, full.names = TRUE, ignore.case = TRUE)
    if (!length(f)) cli::cli_abort("No .las / .laz file under {.path {nuage}}.")
    return(f)
  }
  absents <- nuage[!file.exists(nuage)]
  if (length(absents)) cli::cli_abort("File{?s} not found: {.path {absents}}.")
  if (!all(grepl(motif, nuage, ignore.case = TRUE))) {
    cli::cli_abort("{.arg nuage} must only contain .las / .laz / .copc.laz files.")
  }
  nuage
}

.nuage_cache_valide <- function(p, cle) {
  k <- paste0(p, ".key")
  file.exists(k) &&
    identical(tryCatch(readLines(k, warn = FALSE)[1], error = function(e) NA), cle) &&
    .raster_lisible(p)
}

# Pipeline lasR (substituable dans les tests). `tmp` : chemins des rasters à
# écrire, nommés mnt/mns/mnh (mns seul pour la photogrammétrie).
.nuage_lasr <- function(fichiers, type, res, classifier, methode_sol, csf_args,
                        tmp, ncores) {
  photo <- identical(type, "photogrammetrie")
  pipeline <- lasR::reader_las() +
    lasR::delete_points(lasR::keep_class(.NUAGE_IGN_A_SUPPRIMER))
  if (classifier) {
    pipeline <- pipeline +
      lasR::edit_attribute(attribute = "Classification", value = 1L) +
      if (photo) lasR::classify_with_sor(class = 18L) else lasR::classify_with_ivf(class = 18L)
    if (!photo) {
      sol <- if (identical(methode_sol, "csf")) {
        do.call(lasR::classify_with_csf,
                c(csf_args, list(class = 2L, filter = lasR::drop_noise())))
      } else {
        lasR::classify_with_ptd(class = 2L)
      }
      pipeline <- pipeline + sol
    }
  }
  pipeline <- pipeline + lasR::summarise()
  mns <- lasR::rasterize(res, "max", filter = lasR::drop_class(.LAS_CLASSES_EXCLUES),
                         ofile = tmp[["mns"]])
  if (photo) {
    pipeline <- pipeline + mns
  } else {
    tri <- lasR::triangulate(filter = lasR::keep_class(.NUAGE_SOL))
    pipeline <- pipeline + tri +
      lasR::rasterize(res, tri, ofile = tmp[["mnt"]]) +
      mns +
      lasR::transform_with(tri) +
      lasR::rasterize(res, "max", filter = lasR::drop_class(.LAS_CLASSES_EXCLUES),
                      ofile = tmp[["mnh"]])
  }
  lasR::exec(pipeline, on = fichiers,
             with = list(ncores = lasR::concurrent_files(ncores)))
}

# Comptages tirés de l'étape summarise() de lasR.
.nuage_stats <- function(ans) {
  s <- if (is.list(ans) && !is.null(ans$npoints)) ans else
    Filter(function(x) is.list(x) && !is.null(x$npoints), ans)[[1]]
  classes <- s$npoints_per_class
  classes <- stats::setNames(as.numeric(classes), names(classes))
  n <- as.numeric(s$npoints)
  bruit <- sum(classes[names(classes) %in% as.character(.NUAGE_BRUIT)])
  sol <- sum(classes[names(classes) %in% as.character(.NUAGE_SOL)])
  list(n_points = n, classes = classes,
       part_bruit = if (n > 0) bruit / n else NA_real_,
       part_sol = if (n - bruit > 0) sol / (n - bruit) else NA_real_)
}

# Met à 0 les hauteurs négatives d'un MNH écrit en place ; rend la part des
# pixels sous -0,5 m avant écrêtage.
.nuage_ecreter <- function(path) {
  r <- terra::rast(path)
  neg <- terra::global(r < -0.5, "mean", na.rm = TRUE)[[1]]
  out <- .atomic_tmp_path(path)
  terra::writeRaster(terra::clamp(r, lower = 0, values = TRUE), out,
                     overwrite = TRUE, gdal = c("TILED=YES", "COMPRESS=DEFLATE"))
  .atomic_promote(out, path)
  neg
}

.nuage_raster <- function(x, nom) {
  if (inherits(x, "SpatRaster")) return(x)
  if (is.character(x) && length(x) == 1L && file.exists(x)) return(terra::rast(x))
  cli::cli_abort("{.arg {nom}} must be a {.cls SpatRaster} or the path of a raster.")
}

.nuage_aligner <- function(x, gabarit) {
  if (!terra::same.crs(x, gabarit)) x <- terra::project(x, terra::crs(gabarit))
  terra::resample(x, gabarit, method = "bilinear")
}

# Photogrammétrie : MNT externe sur la grille du MNS, recalage vertical sur le
# sol nu (MNH de référence < 0,5 m), MNH = MNS - MNT écrêté à 0.
.nuage_photogrammetrie <- function(mns_brut, mnt_externe, mnh_reference,
                                   recalage, chemins, verbose) {
  mns <- terra::rast(mns_brut)
  if (!nzchar(terra::crs(mns))) {
    cli::cli_abort(c(
      "The point cloud has no CRS: the external DTM cannot be aligned on it.",
      i = "Assign one to the cloud (e.g. {.code lasR::set_crs()}) and run again."
    ))
  }
  mnt <- .nuage_aligner(.nuage_raster(mnt_externe, "mnt_externe"), mns)
  decalage <- 0
  iqr <- NA_real_
  n_sol <- NA_integer_
  if (isTRUE(recalage)) {
    if (is.null(mnh_reference)) {
      cli::cli_warn("No {.arg mnh_reference}: the vertical shift of the drone DSM is not corrected.")
    } else {
      ref <- .nuage_aligner(.nuage_raster(mnh_reference, "mnh_reference"), mns)
      ecart <- terra::mask(mns - mnt, ref < .NUAGE_SOL_NU_M, maskvalues = c(FALSE, NA))
      v <- terra::spatSample(ecart, size = 1e6, method = "regular", na.rm = TRUE,
                             values = TRUE)[[1]]
      v <- v[is.finite(v)]
      n_sol <- length(v)
      if (n_sol < .NUAGE_MIN_SOL_NU) {
        cli::cli_warn("Only {n_sol} bare-ground cell{?s} under the drone DSM: the vertical shift is not corrected.")
      } else {
        decalage <- stats::median(v)
        iqr <- stats::IQR(v)
        if (verbose) cli::cli_alert_info("Vertical shift of the drone DSM: {round(decalage, 3)} m (IQR {round(iqr, 3)} m), removed.")
        if (iqr > 0.5) {
          cli::cli_warn(c(
            "Bare-ground differences are spread (IQR {round(iqr, 2)} m): the vertical shift is uncertain.",
            i = "The drone DSM may be tilted or the reference CHM outdated."
          ))
        }
      }
    }
  }
  mns_c <- mns - decalage
  brut <- mns_c - mnt
  neg <- terra::global(brut < -0.5, "mean", na.rm = TRUE)[[1]]
  rasters <- list(mnt = mnt, mns = mns_c,
                  mnh = terra::clamp(brut, lower = 0, values = TRUE))
  for (n in names(rasters)) {
    r <- rasters[[n]]
    .atomic_write(chemins[[n]], function(f) {
      terra::writeRaster(r, f, overwrite = TRUE,
                         gdal = c("TILED=YES", "COMPRESS=DEFLATE"))
    }, validate = .raster_lisible)
  }
  list(part_mnh_negatif = neg, decalage_vertical = decalage,
       decalage_iqr = iqr, n_sol_nu = n_sol)
}
