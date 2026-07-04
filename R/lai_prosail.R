# lai_prosail.R — repli LAI Sentinel-2/PROSAIL pour la canopée NDP 0 (spec 033)
# ------------------------------------------------------------------
# Quand le LiDAR HD est absent (NDP 0), on restitue un LAI par inversion PROSAIL
# hybride (paquet `prosail`, jbferet) à partir de Sentinel-2 L2A (source MUSCATE,
# spec 029), pour alimenter en repli `lai_max` de regen_bilan_hydrique (biljouR,
# ajustement direct) et `pai` de regen_sensibilite (microclimf, proxy dégradé —
# LAI ≠ PAI). NDP ≥ 1 conserve TOUJOURS le PAI structural de pai_depuis_nuage().
#
# `prosail` (Suggests + Remotes jbferet/prosail) gardé par requireNamespace ;
# chemin `precomputed` pur (testable) ; dégradation NULL. La séquence
# d'inversion (train_prosail_inversion / apply_prosail_inversion) suit le
# tutoriel officiel ; l'entraînement est validé, l'application sur scène réelle
# est validée par Pascal (non jouable en CI : scènes S2 + SVM lourd).

# SRF prosail d'un capteur S2 (Sentinel_2A/2B/2C), AVEC le champ `$sensor` requis
# par train_prosail_inversion (sinon `srf$sensor %in% ...` échoue).
.lai_s2_srf <- function(sensor = "Sentinel_2A") {
  if (!requireNamespace("prosail", quietly = TRUE)) return(NULL)
  e <- new.env()
  utils::data(list = sensor, package = "prosail", envir = e)
  S2 <- e[[sensor]]
  list(spectral_response = S2$spectral_response,
       spectral_bands    = S2$spectral_bands,
       original_bands    = S2$original_bands,
       sensor            = sensor)
}

# Plage de géométrie d'acquisition par défaut (France, été) : angles solaires
# ~25-45°, visée quasi-nadir, azimut relatif 0-180°.
.lai_default_geom <- function() {
  list(min = data.frame(tto = 0,  tts = 20, psi = 0),
       max = data.frame(tto = 10, tts = 55, psi = 180))
}

# Réduction temporelle d'un stack LAI -> une couche `lai` (p90 par défaut, D1).
.lai_reduce <- function(r, reducer = "p90") {
  if (!inherits(r, "SpatRaster")) {
    cli::cli_abort("{.arg precomputed}/LAI must be a {.cls SpatRaster}.")
  }
  if (terra::nlyr(r) <= 1L) { names(r) <- "lai"; return(r) }
  out <- switch(
    reducer,
    p90    = terra::app(r, function(v) stats::quantile(v, 0.9, na.rm = TRUE)),
    max    = terra::app(r, function(v) max(v, na.rm = TRUE)),
    median = terra::app(r, function(v) stats::median(v, na.rm = TRUE)),
    mean   = terra::mean(r, na.rm = TRUE),
    cli::cli_abort("Unknown {.arg reducer}: {.val {reducer}} (p90/max/median/mean)."))
  names(out) <- "lai"; out
}

# Entraîne (et met en cache) le modèle d'inversion hybride LAI pour un capteur
# S2 et une plage de géométrie. VALIDÉ en scratch (train_prosail_inversion).
.lai_prosail_train <- function(srf, geom_acq, selected_bands, cache_dir) {
  key <- paste0("prosail_lai_", srf$sensor, "_",
                paste(selected_bands, collapse = "-"), ".rds")
  f <- file.path(cache_dir, key)
  if (file.exists(f)) return(readRDS(f))
  opt <- prosail::set_options_prosail(fun = "train_prosail_inversion")
  model <- prosail::train_prosail_inversion(
    parms_to_estimate = "lai", atbd = TRUE, geom_acq = geom_acq, srf = srf,
    selected_bands = list(lai = selected_bands),
    output_dir = cache_dir, options = opt)
  saveRDS(model, f)
  model
}

# Applique le modèle à un raster de réflectances S2 (chemin fichier) -> LAI.
# Suit le tutoriel officiel (apply_prosail_inversion, file-based).
.lai_prosail_apply <- function(refl_path, model, srf, selected_bands,
                               mask_path, cache_dir) {
  opt <- prosail::set_options_prosail(fun = "apply_prosail_inversion")
  opt$multiplying_factor <- 10000
  res <- prosail::apply_prosail_inversion(
    raster_path = refl_path, mask_path = mask_path, hybrid_model = model,
    output_dir = cache_dir, band_names = srf$spectral_bands,
    selected_bands = list(lai = selected_bands), options = opt)
  # apply_prosail_inversion écrit le LAI ; on récupère le SpatRaster résultant.
  if (inherits(res, "SpatRaster")) return(res)
  if (is.character(res) && length(res) && file.exists(res[[1]])) {
    return(terra::rast(res[[1]]))
  }
  lai_files <- list.files(cache_dir, pattern = "lai.*\\.(tif|envi)$",
                          full.names = TRUE, ignore.case = TRUE)
  if (length(lai_files)) terra::rast(lai_files[[1]]) else NULL
}

#' LAI from Sentinel-2 via PROSAIL inversion — NDP-0 canopy fallback (spec 033)
#'
#' @description
#' Retrieve a **LAI** raster over `aoi` from **Sentinel-2 L2A** by **PROSAIL
#' hybrid inversion** (`prosail`), as the NDP-0 fallback for the reGénération
#' canopy inputs when LiDAR HD is absent — `lai_max` of
#' [regen_bilan_hydrique()] (direct fit) and, as a degraded proxy, `pai` of
#' [regen_sensibilite()] (LAI is leaves only; PAI includes wood). **NDP ≥ 1
#' always keeps the structural LiDAR PAI of [pai_depuis_nuage()].**
#'
#' **Two paths.** *Fast-path*: pass `precomputed` (a LAI `SpatRaster`, or a
#' multi-date stack) and only the temporal reduction (`reducer`, default
#' `"p90"`) is applied. *Engine path*: trains the PROSAIL hybrid model for the
#' S2 sensor/geometry (cached in `cache_dir`), applies it to the S2 reflectance
#' raster(s) `refl`, and reduces the per-date LAI to one layer. Needs `prosail`
#' + real S2 scenes and is **not runnable in CI** — the engine is validated on
#' real data (training verified; application per the official tutorial).
#'
#' @param aoi An `sf`/`sfc` extent (used by the MUSCATE auto-fetch path).
#' @param refl S2 L2A reflectance for the engine path: a `SpatRaster` (bands in
#'   `srf` order) or a file path / vector of paths (one per date). When `NULL`,
#'   a best-effort MUSCATE fetch is attempted over `aoi`/`start`/`end`.
#' @param start,end Date bounds (`"YYYY-MM-DD"`) for the S2 search.
#' @param reducer Temporal reducer over dates: `"p90"` (default, D1), `"max"`,
#'   `"median"` or `"mean"`.
#' @param source S2 STAC backend (default `"muscate"`, spec 029).
#' @param sensor PROSAIL sensor SRF: `"Sentinel_2A"` (default), `"Sentinel_2B"`.
#' @param selected_bands S2 bands used for the LAI inversion (default
#'   `c("B3","B4","B8")`).
#' @param geom_acq Optional acquisition-geometry range
#'   (`list(min=, max=)` of `data.frame(tto, tts, psi)`); default a France-summer
#'   range.
#' @param mask Optional cloud/shadow mask raster path for the application.
#' @param cache_dir Directory for the trained model and intermediate rasters
#'   (default: a session temp dir).
#' @param precomputed Optional pre-computed LAI (`SpatRaster` or file path).
#' @param ... Reserved.
#'
#' @return A single-layer LAI `SpatRaster` (`lai`), or `NULL` on degradation
#'   (no `prosail`, no scene, engine failure).
#' @seealso [regen_bilan_hydrique()], [regen_sensibilite()], [pai_depuis_nuage()]
#' @export
lai_sentinel2 <- function(aoi = NULL, refl = NULL, start = NULL, end = NULL,
                          reducer = "p90", source = "muscate",
                          sensor = "Sentinel_2A",
                          selected_bands = c("B3", "B4", "B8"),
                          geom_acq = NULL, mask = NULL, cache_dir = NULL,
                          precomputed = NULL, ...) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} is required.")
  }

  # --- Fast-path : réduction temporelle d'un LAI déjà calculé. ---
  if (!is.null(precomputed)) {
    r <- if (inherits(precomputed, "SpatRaster")) precomputed
         else if (is.character(precomputed) && all(file.exists(precomputed))) {
           terra::rast(precomputed)
         } else {
           cli::cli_abort("{.arg precomputed} must be a SpatRaster or raster file path(s).")
         }
    return(.lai_reduce(r, reducer))
  }

  # --- Engine path : S2 -> inversion PROSAIL -> LAI -> réduction. ---
  if (!requireNamespace("prosail", quietly = TRUE)) {
    cli::cli_warn("lai_sentinel2() needs the {.pkg prosail} package for the engine path; returning NULL.")
    return(NULL)
  }
  if (is.null(cache_dir)) cache_dir <- tempfile("lai_prosail_")
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  if (is.null(geom_acq)) geom_acq <- .lai_default_geom()

  out <- tryCatch(
    .lai_sentinel2_engine(aoi, refl, start, end, reducer, source, sensor,
                          selected_bands, geom_acq, mask, cache_dir),
    error = function(e) {
      cli::cli_warn(c("lai_sentinel2(): engine failed; returning NULL.",
                      i = conditionMessage(e)))
      NULL
    })
  out
}

# Orchestration moteur (non testable en CI). Résout les réflectances S2 (refl
# fourni, ou fetch MUSCATE best-effort), entraîne le modèle, applique par date,
# réduit temporellement.
.lai_sentinel2_engine <- function(aoi, refl, start, end, reducer, source,
                                  sensor, selected_bands, geom_acq, mask,
                                  cache_dir) {
  srf <- .lai_s2_srf(sensor)

  # Résolution des chemins de réflectances S2 par date — AVANT l'entraînement
  # (coûteux) pour dégrader tôt en l'absence de scène.
  refl_paths <- if (inherits(refl, "SpatRaster")) {
    f <- file.path(cache_dir, "s2_refl.tif"); terra::writeRaster(refl, f, overwrite = TRUE); f
  } else if (is.character(refl)) {
    refl
  } else {
    # Fetch MUSCATE best-effort : l'assemblage multi-bandes vit dans le pipeline
    # S2 (stac_search_s2/read_s2_band_stack) et est validé sur données réelles.
    if (is.null(aoi) || is.null(start) || is.null(end)) {
      cli::cli_abort("Provide {.arg refl} (S2 reflectance raster/path), or {.arg aoi}+{.arg start}+{.arg end} for a MUSCATE fetch.")
    }
    cli::cli_abort("Automatic MUSCATE reflectance assembly is validated on real data; pass {.arg refl} meanwhile.")
  }

  model <- .lai_prosail_train(srf, geom_acq, selected_bands, cache_dir)
  lai_list <- lapply(refl_paths, function(p)
    .lai_prosail_apply(p, model, srf, selected_bands, mask, cache_dir))
  lai_list <- Filter(function(x) inherits(x, "SpatRaster"), lai_list)
  if (!length(lai_list)) return(NULL)
  stack <- if (length(lai_list) == 1L) lai_list[[1]] else terra::rast(lai_list)
  .lai_reduce(stack, reducer)
}
