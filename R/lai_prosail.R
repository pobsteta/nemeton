# lai_prosail.R — variables biophysiques Sentinel-2/PROSAIL, NDP 0 (spec 033, 042)
# ------------------------------------------------------------------
# Restitution de variables biophysiques par inversion PROSAIL hybride (paquet
# `prosail`, jbferet) depuis Sentinel-2 L2A (source MUSCATE, spec 029), en NDP 0
# (LiDAR HD absent). `lai_sentinel2()` (spec 033) est le cas historique ; la
# spec 042 généralise en `biophysique_sentinel2(variable=)` : les mêmes train/
# apply produisent **lai**, **fapar** et **fvc** (fcover) — cibles d'inversion
# directes de `train_prosail_inversion`, vérifiées dans le code prosail. Le
# **CCC** est un composé (Cab × LAI), PAS une cible directe : différé (spec 042
# lot 4). Le LAI reste l'entrée reGénération : `lai_max` de regen_bilan_hydrique
# et `pai` de regen_sensibilite (proxy dégradé — LAI ≠ PAI). NDP ≥ 1 conserve
# TOUJOURS le PAI structural de pai_depuis_nuage().
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

# Réduction temporelle d'un stack -> une couche nommée `name` (p90 défaut, D1).
# `name` défaut "lai" : rétrocompatibilité stricte du chemin LAI historique.
.lai_reduce <- function(r, reducer = "p90", name = "lai") {
  if (!inherits(r, "SpatRaster")) {
    cli::cli_abort("{.arg precomputed}/biophysical raster must be a {.cls SpatRaster}.")
  }
  if (terra::nlyr(r) <= 1L) { names(r) <- name; return(r) }
  out <- switch(
    reducer,
    p90    = terra::app(r, function(v) stats::quantile(v, 0.9, na.rm = TRUE)),
    max    = terra::app(r, function(v) max(v, na.rm = TRUE)),
    median = terra::app(r, function(v) stats::median(v, na.rm = TRUE)),
    mean   = terra::mean(r, na.rm = TRUE),
    cli::cli_abort("Unknown {.arg reducer}: {.val {reducer}} (p90/max/median/mean)."))
  names(out) <- name; out
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
# `parm` = nom de variable PROSAIL ("lai"/"fapar"/"fcover"). Défaut "lai" :
# clé et parms_to_estimate identiques à l'historique -> modèle LAI livré trouvé.
.lai_prosail_train <- function(srf, geom_acq, selected_bands, cache_dir,
                               parm = "lai") {
  key <- paste0("prosail_", parm, "_", srf$sensor, "_",
                paste(selected_bands, collapse = "-"), ".rds")
  shipped <- system.file("extdata", key, package = "nemeton")
  if (nzchar(shipped) && file.exists(shipped)) return(readRDS(shipped))
  f <- file.path(cache_dir, key)
  if (file.exists(f)) return(readRDS(f))
  opt <- prosail::set_options_prosail(fun = "train_prosail_inversion")
  model <- prosail::train_prosail_inversion(
    parms_to_estimate = parm, atbd = TRUE, geom_acq = geom_acq, srf = srf,
    selected_bands = stats::setNames(list(selected_bands), parm),
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
  # Les COG MUSCATE (magasin S3 THEIA/MESO@UM) ne se lisent PAS en /vsis3/
  # direct : ils exigent des URLs pré-signées par la gateway teledetection
  # (theia_sign_urls, modèle SAS). Dégrader en NULL (message explicite) si les
  # identifiants TLD_ACCESS_KEY/TLD_SECRET_KEY manquent.
  if (!nzchar(Sys.getenv("TLD_ACCESS_KEY")) ||
      !nzchar(Sys.getenv("TLD_SECRET_KEY"))) {
    cli::cli_warn(c(
      "LAI PROSAIL MUSCATE fallback needs THEIA credentials to sign the reflectance COGs.",
      i = "Set {.envvar TLD_ACCESS_KEY} / {.envvar TLD_SECRET_KEY} (create an API key at {.url https://gate.stac.teledetection.fr})."))
    return(NULL)
  }
  nem_bands <- vapply(selected_bands, .lai_band_to_nemeton, character(1))
  href_cols <- paste0("href_", nem_bands)
  # .get_s2_band_raster() attend un objet sf/sfc (il fait sf::st_transform) —
  # pas un SpatVector terra.
  aoi_v <- sf::st_transform(sf::st_union(sf::st_geometry(aoi)), 4326)
  paths <- character(0)
  for (i in seq_len(nrow(scenes))) {
    sc <- scenes[i, , drop = FALSE]
    layers <- tryCatch({
      # Pré-signer les hrefs des bandes voulues -> /vsicurl/ lisible par GDAL.
      raw <- vapply(href_cols, function(cc) as.character(sc[[cc]][[1]]),
                    character(1))
      signed <- .theia_signed_read(raw, country = "FR")
      if (is.null(signed)) stop("THEIA signing failed")
      for (j in seq_along(href_cols)) sc[[href_cols[j]]] <- signed[j]
      # .get_s2_band_raster() renvoie directement un SpatRaster (croppé à
      # l'AOI). Les bandes n'ont pas la même résolution (B05 à 20 m, B04/B08
      # à 10 m) : on rééchantillonne toutes sur la grille de la première.
      rs <- lapply(nem_bands, function(b) .get_s2_band_raster(sc, b, aoi_v, cache_dir))
      ref <- rs[[1]]
      rs <- lapply(seq_along(rs), function(k) {
        if (k == 1L) return(rs[[k]])
        r <- rs[[k]]
        if (all(terra::res(r) == terra::res(ref)) &&
            terra::compareGeom(r, ref, stopOnError = FALSE)) r
        else terra::resample(r, ref, method = "bilinear")
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
                               mask_path, cache_dir, parm = "lai") {
  opt <- prosail::set_options_prosail(fun = "apply_prosail_inversion")
  opt$multiplying_factor <- 10000
  # apply_prosail_inversion ÉCRIT la variable sur disque (`<base>_<parm>.tif[f]`)
  # mais peut lever une erreur en post-traitement (ex. « subscript out of
  # bounds ») ou renvoyer un objet inexploitable — on tolère et on récupère le
  # fichier. band_names doit décrire les bandes RÉELLEMENT présentes dans le
  # raster (le repli MUSCATE n'assemble que `selected_bands`, pas les 10 bandes
  # S2) — sinon apply_prosail_inversion mal-mappe et écrit une sortie corrompue.
  band_names <- names(terra::rast(refl_path))
  res <- tryCatch(prosail::apply_prosail_inversion(
    raster_path = refl_path, mask_path = mask_path, hybrid_model = model,
    output_dir = cache_dir, band_names = band_names,
    selected_bands = stats::setNames(list(selected_bands), parm), options = opt),
    error = function(e) e)
  if (inherits(res, "SpatRaster")) return(res)
  if (is.character(res) && length(res) && file.exists(res[[1]])) {
    return(terra::rast(res[[1]]))
  }
  # Fichier ciblé sur cette scène (`<base>_<parm>.<ext>`), en excluant le
  # `_<parm>_STD` (incertitude) ; le pattern couvre .tif ET .tiff.
  base <- tools::file_path_sans_ext(basename(refl_path))
  out_files <- list.files(
    cache_dir, pattern = sprintf("^%s_%s\\.(tif|tiff|envi)$", base, parm),
    full.names = TRUE, ignore.case = TRUE, recursive = TRUE)
  if (length(out_files)) return(terra::rast(out_files[[1]]))
  if (inherits(res, "error")) {
    cli::cli_warn(c("PROSAIL {parm} inversion produced no output.",
                    i = conditionMessage(res)))
  }
  NULL
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
  biophysique_sentinel2(
    variable = "lai", aoi = aoi, refl = refl, start = start, end = end,
    reducer = reducer, source = source, sensor = sensor,
    selected_bands = selected_bands, geom_acq = geom_acq, mask = mask,
    cache_dir = cache_dir, precomputed = precomputed, ...)
}

# Notre nom de variable -> cible PROSAIL de train_prosail_inversion (vérifié :
# "lai"/"fapar"/"fcover" sont des cibles directes ; "ccc" ne l'est pas).
.biophys_parm <- function(variable) {
  variable <- match.arg(variable, c("lai", "fapar", "fvc", "ccc"))
  if (identical(variable, "ccc")) {
    cli::cli_abort(c(
      "CCC is not a direct PROSAIL inversion target (it is Cab x LAI).",
      i = "Deferred to spec 042 lot 4; use \"lai\", \"fapar\" or \"fvc\"."))
  }
  c(lai = "lai", fapar = "fapar", fvc = "fcover")[[variable]]
}

#' Biophysical variable from Sentinel-2 via PROSAIL inversion (spec 042)
#'
#' @description
#' Generalises [lai_sentinel2()] to any of the directly-invertible PROSAIL
#' biophysical variables — **LAI**, **fAPAR** or **FVC** (fCover) — over `aoi`
#' from Sentinel-2 L2A, by the same hybrid inversion machinery. `lai_sentinel2()`
#' is a thin alias (`variable = "lai"`), kept for backward compatibility.
#'
#' Same two paths as [lai_sentinel2()]: *fast-path* (`precomputed`, temporal
#' reduction only) and *engine path* (train/apply a hybrid model, needs
#' `prosail` + real S2 scenes — not runnable in CI).
#'
#' @section Scope (spec 042 lot 1):
#' Only the three **direct** inversion targets are supported. **CCC** (canopy
#' chlorophyll content) is a compound (Cab x LAI), not a direct target — it errors
#' and is deferred (lot 4). Per-variable band selection (`selected_bands`) is
#' **provisional**: the LAI default `c("B4","B5","B8")` is validated (spec 033);
#' for fAPAR/FVC the red-edge-optimal set is still open (spec 042 D3), and their
#' inversion is unvalidated pending the GEODES cross-check (lot 3).
#'
#' @param variable One of `"lai"` (default), `"fapar"`, `"fvc"`.
#' @param selected_bands S2 bands for the inversion. `NULL` picks a per-variable
#'   default (currently `c("B4","B5","B8")` for all three — provisional, D3).
#' @inheritParams lai_sentinel2
#'
#' @return A single-layer `SpatRaster` named after `variable`, or `NULL` on
#'   degradation (no `prosail`, no scene, engine failure).
#' @seealso [lai_sentinel2()]
#' @export
biophysique_sentinel2 <- function(variable = c("lai", "fapar", "fvc", "ccc"),
                                  aoi = NULL, refl = NULL, start = NULL,
                                  end = NULL, reducer = "p90",
                                  source = "muscate", sensor = "Sentinel_2A",
                                  selected_bands = NULL, geom_acq = NULL,
                                  mask = NULL, cache_dir = NULL,
                                  precomputed = NULL, ...) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} is required.")
  }
  variable <- match.arg(variable)
  parm <- .biophys_parm(variable)
  if (is.null(selected_bands)) selected_bands <- c("B4", "B5", "B8")

  # --- Fast-path : réduction temporelle d'une variable déjà calculée. ---
  if (!is.null(precomputed)) {
    r <- if (inherits(precomputed, "SpatRaster")) precomputed
         else if (is.character(precomputed) && all(file.exists(precomputed))) {
           terra::rast(precomputed)
         } else {
           cli::cli_abort("{.arg precomputed} must be a SpatRaster or raster file path(s).")
         }
    return(.lai_reduce(r, reducer, name = variable))
  }

  # --- Engine path : S2 -> inversion PROSAIL -> variable -> réduction. ---
  if (!requireNamespace("prosail", quietly = TRUE)) {
    cli::cli_warn("biophysique_sentinel2() needs the {.pkg prosail} package for the engine path; returning NULL.")
    return(NULL)
  }
  if (is.null(cache_dir)) cache_dir <- tempfile("biophys_prosail_")
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  if (is.null(geom_acq)) geom_acq <- .lai_default_geom()

  tryCatch(
    .lai_sentinel2_engine(aoi, refl, start, end, reducer, source, sensor,
                          selected_bands, geom_acq, mask, cache_dir,
                          variable = variable, parm = parm),
    error = function(e) {
      cli::cli_warn(c("biophysique_sentinel2(): engine failed; returning NULL.",
                      i = conditionMessage(e)))
      NULL
    })
}

# Orchestration moteur (non testable en CI). Résout les réflectances S2 (refl
# fourni, ou fetch MUSCATE best-effort), entraîne le modèle, applique par date,
# réduit temporellement.
.lai_sentinel2_engine <- function(aoi, refl, start, end, reducer, source,
                                  sensor, selected_bands, geom_acq, mask,
                                  cache_dir, variable = "lai", parm = "lai") {
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

  model <- .lai_prosail_train(srf, geom_acq, selected_bands, cache_dir, parm = parm)
  var_list <- lapply(refl_paths, function(p)
    .lai_prosail_apply(p, model, srf, selected_bands, mask, cache_dir, parm = parm))
  var_list <- Filter(function(x) inherits(x, "SpatRaster"), var_list)
  if (!length(var_list)) return(NULL)
  stack <- if (length(var_list) == 1L) var_list[[1]] else terra::rast(var_list)
  .lai_reduce(stack, reducer, name = variable)
}
