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

# Mappe un nom de bande prosail (B4, B8, B8A) vers le nom nemeton du pipeline S2
# (.S2_STAC_BANDS : zéro-padding à 2 chiffres, suffixe lettre conservé).
.lai_band_to_nemeton <- function(b) {
  m <- regmatches(b, regexec("^B([0-9]+)([A-Z]?)$", b))[[1]]
  if (length(m) != 3L) return(b)
  if (nzchar(m[3])) return(b)                 # suffixe lettre (B8A) -> inchangé
  sprintf("B%02d", as.integer(m[2]))          # numérique -> zéro-padding (B4->B04)
}

# Entraîne (ou charge) le modèle d'inversion hybride LAI pour un capteur S2 et
# une plage de géométrie. Priorité : modèle pré-entraîné versionné
# (inst/extdata, spec 033 D3) -> cache disque -> entraînement (train validé).
.lai_prosail_train <- function(srf, geom_acq, selected_bands, cache_dir) {
  key <- paste0("prosail_lai_", srf$sensor, "_",
                paste(selected_bands, collapse = "-"), ".rds")
  shipped <- system.file("extdata", key, package = "nemeton")
  if (nzchar(shipped) && file.exists(shipped)) return(readRDS(shipped))
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

# Assemblage MUSCATE stateless (spec 033 D4) : cherche les scènes S2 L2A
# (source MUSCATE, spec 029), récupère par scène les bandes nécessaires via
# `.get_s2_band_raster` (crop AOI, cache), assemble un raster multi-bandes par
# date (couches nommées selon prosail). Non jouable en CI (réseau + scènes) ;
# validé sur données réelles. Renvoie un vecteur de chemins, ou NULL.
.lai_s2_reflectance_muscate <- function(aoi, start, end, selected_bands,
                                        max_cloud, cache_dir) {
  scenes <- stac_search_s2(aoi, start, end, max_cloud = max_cloud,
                           source = "muscate")
  if (is.null(scenes) || !nrow(scenes)) return(NULL)
  nem_bands <- vapply(selected_bands, .lai_band_to_nemeton, character(1))
  aoi_v <- terra::vect(sf::st_transform(sf::st_union(sf::st_geometry(aoi)), 4326))
  paths <- character(0)
  for (i in seq_len(nrow(scenes))) {
    sc <- scenes[i, , drop = FALSE]
    layers <- tryCatch({
      rs <- lapply(nem_bands, function(b) {
        g <- .get_s2_band_raster(sc, b, aoi_v, cache_dir)
        terra::rast(g$path)
      })
      st <- terra::rast(rs)
      names(st) <- selected_bands
      f <- file.path(cache_dir, sprintf("s2_refl_%s.tif",
                                        as.character(sc$scene_id[[1]])))
      terra::writeRaster(st, f, overwrite = TRUE)
      f
    }, error = function(e) NULL)
    if (!is.null(layers)) paths <- c(paths, layers)
  }
  if (length(paths)) paths else NULL
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
#' `"p90"`) is applied. *Engine path*: loads the shipped pre-trained model
#' (`inst/extdata`, spec 033 D3) — or trains + caches one —, applies it to the S2
#' reflectance raster(s) `refl` (auto-assembled from MUSCATE when `refl` is
#' `NULL`, spec 033 D4), and reduces the per-date LAI to one layer. Needs
#' `prosail` + real S2 scenes and is **not runnable in CI** — the engine is
#' validated on real data (training verified; application per the official
#' tutorial).
#'
#' @param aoi An `sf`/`sfc` extent (used by the MUSCATE auto-fetch path).
#' @param refl S2 L2A reflectance for the engine path: a `SpatRaster` (layers
#'   named as `selected_bands`) or a file path / vector of paths (one per date).
#'   When `NULL`, the reflectance is **assembled automatically** from MUSCATE
#'   over `aoi`/`start`/`end` (spec 033 D4, reuses the S2 STAC pipeline).
#' @param start,end Date bounds (`"YYYY-MM-DD"`) for the S2 search.
#' @param reducer Temporal reducer over dates: `"p90"` (default, D1), `"max"`,
#'   `"median"` or `"mean"`.
#' @param source S2 STAC backend (default `"muscate"`, spec 029).
#' @param sensor PROSAIL sensor SRF: `"Sentinel_2A"` (default), `"Sentinel_2B"`.
#' @param selected_bands S2 bands used for the LAI inversion (default
#'   `c("B4","B5","B8")` — red, red-edge, NIR; all exposed by the S2 pipeline).
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
                          selected_bands = c("B4", "B5", "B8"),
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
    # Assemblage automatique MUSCATE (spec 033 D4), stateless, best-effort.
    if (is.null(aoi) || is.null(start) || is.null(end)) {
      cli::cli_abort("Provide {.arg refl} (S2 reflectance raster/path), or {.arg aoi}+{.arg start}+{.arg end} for a MUSCATE fetch.")
    }
    p <- .lai_s2_reflectance_muscate(aoi, start, end, selected_bands,
                                     max_cloud = 20, cache_dir = cache_dir)
    if (is.null(p)) cli::cli_abort("No usable MUSCATE Sentinel-2 reflectance over the AOI for the period.")
    p
  }

  model <- .lai_prosail_train(srf, geom_acq, selected_bands, cache_dir)
  lai_list <- lapply(refl_paths, function(p)
    .lai_prosail_apply(p, model, srf, selected_bands, mask, cache_dir))
  lai_list <- Filter(function(x) inherits(x, "SpatRaster"), lai_list)
  if (!length(lai_list)) return(NULL)
  stack <- if (length(lai_list) == 1L) lai_list[[1]] else terra::rast(lai_list)
  .lai_reduce(stack, reducer)
}
