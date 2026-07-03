# regen_engines.R — moteurs reGénération : scaffolds L1/L2 (spec 027 v2.1)
# ------------------------------------------------------------------
# Ces moteurs orchestrent des dépendances LOURDES (GPL, hors CRAN pour
# certaines) : microclimf, mcera5, lidR, lasR (exposition microclimatique) et
# biljouR (bilan hydrique). Elles sont en `Suggests` (hygiène d'installation,
# pas licence : tout est GPL-3 — cf. spec 027 §2). Chaque fonction :
#   * valide ses entrées (testable) ;
#   * OFFRE un chemin `precomputed` PUR : quand les sorties du moteur sont déjà
#     calculées (prototypes /Documents/reGénération, ou cache projet), la
#     fonction les rattache aux unités en colonnes standard §7 — sans le moteur ;
#   * sinon, tente le moteur si présent, ou ÉCHOUE PROPREMENT (message
#     actionnable) — jamais d'erreur de chargement de package.
#
# biljouR est déclaré en `Suggests` + `Remotes` (pobsteta/biljouR) ; il reste
# chargé via requireNamespace() (dépendance optionnelle, dégradation propre).

# Colonnes de sortie §7 par moteur (contrat).
.REGEN_COLS_HYDRIQUE <- c("njstress", "istress", "rew_min", "deb_stress")
.REGEN_COLS_EXPO <- c("tmax_moyenne", "tmax_canicule", "vpd_moyenne",
                      "vpd_canicule", "d_tmax", "d_vpd", "sensibilite",
                      "rang_sensibilite", "robustesse", "signal_robuste",
                      "couverture_pct")

# Rattache des colonnes per-unité `precomputed` (data.frame / liste nommée) à
# `units`, restreintes à `allowed`. Longueur = nrow(units) ou 1 (recyclé).
.regen_attach_precomputed <- function(units, precomputed, allowed) {
  if (!is.data.frame(precomputed) && !is.list(precomputed)) {
    stop("`precomputed` must be a data.frame or a named list", call. = FALSE)
  }
  n <- nrow(units)
  nms <- intersect(names(precomputed), allowed)
  if (!length(nms)) {
    stop("`precomputed` has none of the expected columns: ",
         paste(allowed, collapse = ", "), call. = FALSE)
  }
  unknown <- setdiff(names(precomputed), allowed)
  if (length(unknown)) {
    cli::cli_warn("Ignoring unexpected `precomputed` column{?s}: {.val {unknown}}.")
  }
  for (nm in nms) {
    v <- precomputed[[nm]]
    if (length(v) != n && length(v) != 1L) {
      stop("`precomputed$", nm, "` has length ", length(v),
           "; expected ", n, " (or 1).", call. = FALSE)
    }
    units[[nm]] <- rep(as.numeric(v), length.out = n)
  }
  units
}


#' Soil water balance per unit — BILJOU engine (spec 027 L2)
#'
#' @description
#' Per-unit soil water-balance metrics (relative extractable water, days of
#' hydric stress, drought intensity / onset) from the **BILJOU** model
#' (`biljouR`, INRAE lineage), forced by SAFRAN (primary) or ERA5-Land
#' (fallback) — decision §10.2. Feeds [indicateur_r3_secheresse()] (via its
#' `biljou` argument) and [indice_priorite_regen()].
#'
#' **Scaffold with a pure fast-path**: pass `precomputed` (the per-unit output
#' of a BILJOU run — e.g. the reGénération prototype `biljou_run_grid()`) and
#' the metrics are attached to `units` as the §7 columns, **without** the GPL
#' engine. Without `precomputed`, the full `biljouR` orchestration is not yet
#' wired (it requires SAFRAN download + soil parameters); the function fails
#' cleanly with an actionable message.
#'
#' @param units An `sf` of management units (UGF).
#' @param meteo Optional SAFRAN/ERA5 forcing (for the engine path).
#' @param sol Optional soil description (`biljou_soil()` inputs: extractable
#'   water `ewm`, root fractions `roots`).
#' @param lai_max Optional per-unit maximum LAI (from `pai_depuis_nuage()`).
#' @param forest_type Character, `"feuillu"` / `"resineux"` (phenology).
#' @param precomputed Optional per-unit BILJOU output (`data.frame`/list with
#'   any of `njstress`, `istress`, `rew_min`, `deb_stress`). Pure fast-path.
#' @param ... Reserved (engine parameters).
#'
#' @return `units` with the water-balance columns present in `precomputed`
#'   (`njstress`, `istress`, `rew_min`, `deb_stress`).
#' @seealso [indicateur_r3_secheresse()], [indice_priorite_regen()]
#' @export
regen_bilan_hydrique <- function(units, meteo = NULL, sol = NULL,
                                 lai_max = NULL, forest_type = "feuillu",
                                 precomputed = NULL, ...) {
  validate_sf(units)
  if (!is.null(precomputed)) {
    return(.regen_attach_precomputed(units, precomputed, .REGEN_COLS_HYDRIQUE))
  }
  if (!requireNamespace("biljouR", quietly = TRUE)) {
    cli::cli_abort(c(
      "regen_bilan_hydrique() needs the {.pkg biljouR} package for the engine path.",
      i = "Install it with {.code remotes::install_github(\"pobsteta/biljouR\")}, or pass a precomputed BILJOU output via {.arg precomputed}."
    ))
  }
  cli::cli_abort(c(
    "regen_bilan_hydrique(): the {.pkg biljouR} orchestration is not yet wired (spec 027 L2).",
    i = "Run the reGénération prototype (SAFRAN + biljou_run_grid) and pass its per-unit output via {.arg precomputed}."
  ))
}


#' Microclimate exposure per unit — microclimf engine (spec 027 L1)
#'
#' @description
#' Per-unit summer under-canopy exposure (T°max, VPD, canopy buffering,
#' heatwave-vs-average sensitivity, robustness) from the mechanistic
#' **microclimf** model driven by LiDAR-HD structure and ERA5-Land forcing.
#' Produces the §7 exposure columns consumed by [indice_priorite_regen()].
#'
#' **Scaffold with a pure fast-path**: pass `precomputed` (the per-unit output
#' of a microclimf run — e.g. the prototype `microclimat_parcelles_robuste.R`)
#' and the metrics are attached as §7 columns without the GPL engine. When
#' `d_tmax`/`d_vpd` are absent they are derived from
#' `tmax_canicule - tmax_moyenne` / `vpd_canicule - vpd_moyenne`, and
#' `rang_sensibilite` from `sensibilite` (1 = most sensitive). Without
#' `precomputed`, the microclimf orchestration is not yet wired; the function
#' fails cleanly.
#'
#' @param units An `sf` of UGF.
#' @param mnt,mnh,las Optional LiDAR-HD inputs (DTM raster, canopy-height
#'   raster, classified point cloud) for the engine path.
#' @param annees_moy,annees_canic Integer years for the average / heatwave
#'   summers (engine path). See [microclimate_detect_years()].
#' @param mois_ete Integer months of the summer window (default `6:8`).
#' @param precomputed Optional per-unit microclimf output (`data.frame`/list).
#' @param ... Reserved (engine parameters).
#'
#' @return `units` with the exposure columns (subset of §7), plus derived
#'   `d_tmax`/`d_vpd`/`rang_sensibilite` where computable.
#' @seealso [indice_priorite_regen()], [microclimate_detect_years()]
#' @export
regen_sensibilite <- function(units, mnt = NULL, mnh = NULL, las = NULL,
                              annees_moy = NULL, annees_canic = NULL,
                              mois_ete = 6:8, precomputed = NULL, ...) {
  validate_sf(units)
  if (!is.null(precomputed)) {
    units <- .regen_attach_precomputed(units, precomputed, .REGEN_COLS_EXPO)
    if (all(c("tmax_moyenne", "tmax_canicule") %in% names(units)) &&
        !"d_tmax" %in% names(units)) {
      units$d_tmax <- units$tmax_canicule - units$tmax_moyenne
    }
    if (all(c("vpd_moyenne", "vpd_canicule") %in% names(units)) &&
        !"d_vpd" %in% names(units)) {
      units$d_vpd <- units$vpd_canicule - units$vpd_moyenne
    }
    if ("sensibilite" %in% names(units) && !"rang_sensibilite" %in% names(units)) {
      units$rang_sensibilite <- rank(-units$sensibilite, ties.method = "min")
    }
    return(units)
  }
  if (!requireNamespace("microclimf", quietly = TRUE)) {
    cli::cli_abort(c(
      "regen_sensibilite() needs the {.pkg microclimf} package for the engine path.",
      i = "Install microclimf, or pass a precomputed microclimf output via {.arg precomputed}."
    ))
  }
  cli::cli_abort(c(
    "regen_sensibilite(): the {.pkg microclimf} orchestration is not yet wired (spec 027 L1).",
    i = "Run the reGénération prototype (microclimat_parcelles_robuste) and pass its per-unit output via {.arg precomputed}."
  ))
}


#' Plant Area Index from a LiDAR-HD point cloud (spec 027 L1)
#'
#' @description
#' Wall-to-wall **PAI** raster from a classified LiDAR-HD point cloud
#' (`.las`/`.laz`), via per-pixel gap fraction + Beer-Lambert:
#' `P_gap = N_ground / (N_ground + N_veg)` then `PAI = -(1/k) * ln(P_gap)`. The
#' PAI feeds the `lai_max` of [regen_bilan_hydrique()] and the canopy of
#' [regen_sensibilite()] (⚠️ PAI ≈ LAI only for a leaves-on acquisition, spec
#' 027 §9.3).
#'
#' The point-cloud path uses the **`lasR`** pipeline (single read, two
#' class-filtered rasterizations) and is resampled onto `grille` (the working
#' DTM). Heavy dependency in `Suggests`, guarded by `requireNamespace`. When
#' `precomputed` is a `SpatRaster` (or raster file path) it is returned as-is,
#' so the pipeline can run on a pre-built PAI without `lasR`.
#'
#' @param dossier_las Directory of classified `.las`/`.laz` tiles covering the
#'   parcels plus a buffer.
#' @param grille Target grid (`SpatRaster`, typically the working DTM) — the PAI
#'   is resampled onto it.
#' @param res Numeric working resolution in metres (default 2).
#' @param k Beer-Lambert extinction coefficient (default 0.5).
#' @param parcelle Optional `SpatVector`/`sf` mask applied at the end.
#' @param fenetre Optional smoothing window in metres (`NA` = none).
#' @param cl_sol,cl_veg ASPRS classes counted as ground / vegetation
#'   (defaults `2` and `c(3, 4, 5)`).
#' @param epsg CRS forced on the tiles when absent (LiDAR HD = `2154`).
#' @param pai_max Upper clamp on PAI (default 8).
#' @param precomputed Optional pre-built PAI `SpatRaster` or raster path.
#' @param ... Reserved.
#'
#' @return A `terra::SpatRaster` of PAI (layer `pai`).
#' @seealso [regen_bilan_hydrique()], [regen_sensibilite()]
#' @export
pai_depuis_nuage <- function(dossier_las = NULL, grille = NULL, res = 2,
                             k = 0.5, parcelle = NULL, fenetre = NA,
                             cl_sol = 2L, cl_veg = c(3L, 4L, 5L), epsg = 2154,
                             pai_max = 8, precomputed = NULL, ...) {
  if (!is.null(precomputed)) {
    if (inherits(precomputed, "SpatRaster")) return(precomputed)
    if (is.character(precomputed) && length(precomputed) == 1L &&
        file.exists(precomputed)) {
      return(terra::rast(precomputed))
    }
    stop("`precomputed` must be a SpatRaster or an existing raster file path",
         call. = FALSE)
  }
  if (is.null(dossier_las) || is.null(grille)) {
    cli::cli_abort(c(
      "pai_depuis_nuage() needs a LiDAR tile directory and a target grid.",
      i = "Provide {.arg dossier_las} + {.arg grille}, or a pre-built PAI via {.arg precomputed}."
    ))
  }
  if (!inherits(grille, "SpatRaster")) {
    stop("`grille` must be a terra SpatRaster", call. = FALSE)
  }
  if (!requireNamespace("lasR", quietly = TRUE)) {
    cli::cli_abort(c(
      "pai_depuis_nuage() needs the {.pkg lasR} package for the point-cloud path.",
      i = "Install it with {.code install.packages(\"lasR\", repos = \"https://r-lidar.r-universe.dev\")}, or pass a pre-built PAI via {.arg precomputed}."
    ))
  }

  dalles <- list.files(dossier_las, pattern = "\\.(las|laz)$",
                       full.names = TRUE, ignore.case = TRUE)
  if (!length(dalles)) {
    cli::cli_abort("No .las/.laz tiles found in {.path {dossier_las}}.")
  }

  # rasterize tamponnée si fenêtre fournie.
  res_arg <- if (is.na(fenetre)) res else c(res, fenetre)
  f_sol <- tempfile(fileext = ".tif")
  f_veg <- tempfile(fileext = ".tif")

  # Un seul passage de lecture, deux rastérisations filtrées par classe.
  # default_value = 0 : pixel couvert mais sans point de la classe -> 0 (pas NA),
  # indispensable sous canopée dense où N_sol peut être nul.
  pipe <- lasR::reader_las() + lasR::set_crs(epsg) +
    lasR::rasterize(res_arg, "count", filter = lasR::keep_class(cl_sol),
                    default_value = 0, ofile = f_sol) +
    lasR::rasterize(res_arg, "count", filter = lasR::keep_class(cl_veg),
                    default_value = 0, ofile = f_veg)
  lasR::exec(pipe, on = dalles, progress = TRUE)

  n_sol <- terra::rast(f_sol)
  n_veg <- terra::rast(f_veg)

  # Fraction de trouée puis Beer-Lambert.
  ntot  <- n_sol + n_veg
  p_gap <- n_sol / ntot
  p_gap <- terra::clamp(p_gap, 1e-3, 1 - 1e-3)          # évite log(0)
  pai   <- -(cos(0) / k) * log(p_gap)
  pai   <- terra::clamp(pai, 0, pai_max)
  pai[ntot == 0] <- NA                                  # hors couverture LiDAR
  names(pai) <- "pai"

  # Aligne sur la grille de travail puis masque éventuellement.
  pai <- terra::resample(pai, grille, method = "bilinear")
  if (!is.null(parcelle)) {
    pv <- if (inherits(parcelle, "SpatVector")) parcelle else terra::vect(parcelle)
    pai <- terra::mask(terra::crop(pai, pv), pv)
  }
  pai
}
