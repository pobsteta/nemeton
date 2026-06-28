# ============================================================
# reconfort_pipeline.R — RECONFORT dieback orchestration (L2b.3)
# ------------------------------------------------------------
# `run_reconfort_dieback()` ties the L1/L2a/L2b.1/L2b.2 pieces into a
# single end-to-end run: locate the conda/IOTA2 env, fetch the RF model
# and the broadleaf mask, resolve the AOI to MGRS tile(s), ingest the
# Sentinel-2 archives, then drive the vendored IOTA2 map-production
# (sampling + classification subprocess x2 + OSO masking + continuous
# score). It returns the result raster paths and a `run_meta.json`.
#
# The post-process -> `alert` table (patch centroids, confidence_class,
# stress_index = continuous score) stays in lot L3, NOT here.
#
# Staging note: the upstream `run_map_production_reconfort.py` chdir's
# to its own directory and writes `results/` + `generated_config_files/`
# there. To keep the installed package read-only, every run stages a
# self-contained working copy of the vendored glue (scripts + `iota2/`
# subtree + model + mask + a year-partitioned S2 view) under
# `cache_dir`, and runs from there.
#
# Real IOTA2 execution needs the conda env + a GEODES account + tens of
# GB of S2 + OTB/Shark (batch-heavy) — opt-in, never in CI.
# ============================================================


# Stage a self-contained working copy of the vendored glue into workdir.
.reconfort_stage_workdir <- function(workdir, glue_dir) {
  dir.create(workdir, recursive = TRUE, showWarnings = FALSE)
  # Copy the whole vendored tree (scripts, utils/, iota2/) into workdir
  # so relative paths in the cfg (`iota2/...`, `masks/...`) resolve and
  # outputs land under workdir, not the installed package.
  entries <- list.files(glue_dir, full.names = TRUE, include.dirs = TRUE)
  ok <- file.copy(entries, workdir, recursive = TRUE, overwrite = TRUE)
  if (!all(ok)) {
    cli::cli_abort("Failed to stage the RECONFORT glue into {.path {workdir}}.")
  }
  # The vendored `run_map_production_reconfort.py` / `generate_cfg_*` open
  # `generated_config_files/<name>.cfg` for writing and IOTA2 lands its
  # outputs under `results/`, but neither script `makedirs` first — the
  # upstream repo simply shipped those folders. `file.copy()` does not
  # recreate empty dirs, so create them here (the function's contract).
  for (d in c("generated_config_files", "results")) {
    dir.create(file.path(workdir, d), recursive = TRUE, showWarnings = FALSE)
  }
  invisible(workdir)
}


# Place the RF model where run_map_production_reconfort.py expects it
# (`<workdir>/models/<v_model>/model_1_seed_0.txt`).
.reconfort_stage_model <- function(workdir, model_path, v_model) {
  dest_dir <- file.path(workdir, "models", v_model)
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(dest_dir, "model_1_seed_0.txt")
  if (!file.copy(model_path, dest, overwrite = TRUE)) {
    cli::cli_abort("Failed to stage the RECONFORT model into {.path {dest_dir}}.")
  }
  dest
}


# Place the broadleaf mask at the path the vendored masking step globs
# (`<workdir>/masks/<RECONFORT_OSO_MASK$file>`). Used for both the
# classification and probability masks (path_to_binary_mask left empty).
.reconfort_stage_mask <- function(workdir, mask_path) {
  dest_dir <- file.path(workdir, "masks")
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(dest_dir, RECONFORT_OSO_MASK$file)
  if (!file.copy(mask_path, dest, overwrite = TRUE)) {
    cli::cli_abort("Failed to stage the RECONFORT mask into {.path {dest_dir}}.")
  }
  dest
}


# Build the year-partitioned S2 view IOTA2 wants
# (`<S2_path>/<S2_year>/<tile>/`) from the flat per-tile extraction dirs
# produced by reconfort_ingest_s2 (`<s2_root>/extracted/<tile>/`). Uses
# symlinks (cheap; falls back to copy where symlinks are unavailable).
# Returns the S2_path root the cfg passes to IOTA2.
.reconfort_stage_s2_layout <- function(workdir, s2_year, tiles, extracted_dirs) {
  s2_root  <- file.path(workdir, "S2_data")
  year_dir <- file.path(s2_root, as.character(s2_year))
  dir.create(year_dir, recursive = TRUE, showWarnings = FALSE)
  for (i in seq_along(tiles)) {
    link <- file.path(year_dir, tiles[[i]])
    src  <- normalizePath(extracted_dirs[[i]], mustWork = FALSE)
    # Clear a pre-existing entry (real dir or live/broken symlink) so a
    # re-run restages cleanly.
    if (file.exists(link) || isTRUE(nzchar(Sys.readlink(link)))) {
      unlink(link, recursive = TRUE, force = TRUE)
    }
    linked <- suppressWarnings(file.symlink(src, link))
    if (!isTRUE(linked)) {
      dir.create(link, recursive = TRUE, showWarnings = FALSE)
      file.copy(list.files(src, full.names = TRUE), link, recursive = TRUE)
    }
  }
  s2_root
}


# Collect the IOTA2 final rasters from the results dir. Missing files
# come back as NA (the masked/score files only exist when masking ran).
.reconfort_collect_outputs <- function(workdir, label, s2_year) {
  final <- file.path(
    workdir, "results",
    sprintf("iota2_results_classif_labels-%s-S2_%s", label, s2_year),
    "final"
  )
  pick <- function(name) {
    p <- file.path(final, name)
    if (file.exists(p)) normalizePath(p) else NA_character_
  }
  list(
    final_dir          = final,
    classif            = pick("Classif_Seed_0.tif"),
    classif_masked     = pick(sprintf("Final_Classif_masked_%s.tif", s2_year)),
    probability        = pick("ProbabilityMap_seed_0.tif"),
    probability_masked = pick(sprintf("Final_Proba_map_masked%s.tif", s2_year)),
    continuous_score   = pick(sprintf("Final_continuous_score_masked%s.tif", s2_year))
  )
}


# Write run_meta.json next to the results (parity with FORDEAD's run
# metadata). Best-effort: never aborts the run on a write failure.
.reconfort_write_run_meta <- function(path, meta) {
  tryCatch(
    jsonlite::write_json(meta, path, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    error = function(e) invisible(NULL)
  )
  path
}


#' Run the RECONFORT broadleaf-dieback map production end-to-end
#'
#' Orchestrates a full RECONFORT run for one monitoring zone: validate
#' the conda/IOTA2 environment, fetch the Random-Forest model
#' ([ensure_reconfort_model()]) and the broadleaf mask
#' ([ensure_reconfort_oso_mask()]), resolve the AOI to Sentinel-2 MGRS
#' tile(s) ([reconfort_aoi_tiles()]), ingest the S2 archives
#' ([reconfort_ingest_s2()]), then drive the vendored IOTA2
#' map-production (sampling + classification + OSO masking + continuous
#' score). Produces the classification, probability and continuous-score
#' rasters (EPSG:2154) plus a `run_meta.json`.
#'
#' The downstream conversion of these rasters into `alert` rows (patch
#' centroids, `confidence_class`, `stress_index`) is lot L3 and is **not**
#' performed here.
#'
#' **Heavy and opt-in.** A real run needs the `nemeton-reconfort` conda
#' environment, a GEODES account, tens of GB of Sentinel-2 and an
#' OTB/Shark batch execution. It is never exercised in CI; unit tests
#' mock every external step.
#'
#' @param con A `DBIConnection` to the monitoring database.
#' @param zone_id Scalar monitoring-zone id (see
#'   [`.get_zone_aoi`][nemeton] resolution via `monitoring_zone`).
#' @param cache_dir Project cache root. The per-run working directory is
#'   created under `<cache_dir>/reconfort/` (same caller-supplied
#'   convention as FORDEAD's `cache_dir`).
#' @param s2_year Integer, the **last** year of the two-year Sentinel-2
#'   series — the single temporal control of a run (the app exposes only
#'   this, as a year picker). Default the current year. The download
#'   window, the analysis window and the output names all derive from it;
#'   see *Temporal window* below.
#' @param date_from,date_to Sentinel-2 **download** window
#'   (`"YYYY-MM-DD"`). `NULL` (default) derives a two-calendar-year window
#'   from `s2_year`: `date_from = (s2_year-1)-01-01`,
#'   `date_to = s2_year-12-31`. This only bounds what is fetched from
#'   Theia; IOTA2 then re-clips to the model's seasonal *analysis* window
#'   (`S2_start`/`S2_end`), so a custom download window cannot widen the
#'   analysis beyond what the pre-trained model expects. See
#'   *Temporal window*.
#' @param v_model RF model version (see [RECONFORT_MODELS]). Default
#'   `"v3"` (oak, 2-year series).
#' @param binary_mask Broadleaf mask control. `NULL` (default) fetches
#'   and uses the OSO 2021 deciduous mask; a path uses a custom mask;
#'   `FALSE` disables masking (continuous score from the raw probability
#'   map only). When `aoi_crop = TRUE` and `binary_mask = NULL`, the mask is
#'   cut from the national OSO (`oso_national`) for the AOI instead.
#' @param aoi_crop Logical. When `TRUE` (default) the Sentinel-2 scenes are
#'   streamed and clipped + reprojected to the zone AOI (+ buffer) in the
#'   output projection during ingestion (spec 021) — each archive is
#'   downloaded, extracted, cropped and deleted in turn. This turns a
#'   multi-hour full-tile run into minutes, fixes IOTA2's reference-grid
#'   handling, makes the broadleaf mask + ground truth AOI-local, and caps
#'   peak disk near a single archive. All operations are per-pixel, so
#'   clipping does not change the result for the kept pixels.
#' @param oso_national Character or `NULL`. National OSO land-cover raster
#'   used to cut the AOI broadleaf mask (default
#'   `<global cache>/oso/oso.tif`, overridable via
#'   `options(nemeton.reconfort_oso_national)`).
#' @param number_of_chunks IOTA2 RAM-saving chunk count. Default `200`
#'   (forced to `1` when `aoi_crop` shrinks the raster to a single block).
#' @param scheduler_type IOTA2 scheduler. Default `"localCluster"`.
#'   IOTA2's `Iota2.py` only accepts `debug`, `cluster`, `PBS`, `Slurm`,
#'   `localCluster` (note the lower-case `l`) — `"LocalCluster"` 400s.
#'   When `aoi_crop = TRUE` the default `"localCluster"` is overridden to
#'   `"debug"` (sequential): the cropped raster is tiny, so the Dask
#'   cluster only adds memory pressure (it tripped systemd-oomd and killed
#'   the R session mid-classification on 2026-06-28). An explicit non-default
#'   value is respected.
#'   PENDING : à confirmer après alignement de la version d'iota2.
#' @param nb_parallel_tasks IOTA2 parallel-task count. Default `1`.
#' @param output_dir Explicit per-run working directory. Default
#'   `<cache_dir>/reconfort/run_z<zone_id>_S2<s2_year>`.
#' @param geodes_config Path to `pygeodes-config.json` (see
#'   [reconfort_ingest_s2()]). Default resolves the option / user dir.
#' @param model_cache_dir,mask_cache_dir Override caches for the model /
#'   mask fetches. Default per-user nemeton caches.
#' @param tiles Explicit MGRS tile code(s); resolved from the zone AOI
#'   when `NULL`.
#' @param skip_ingest Reuse an already-ingested S2 layout under the
#'   working dir instead of downloading. Default `FALSE`.
#' @param keep_workdir Keep the staged working directory after the run.
#'   Default `TRUE` (the rasters live there).
#' @param quiet Suppress progress + subprocess output. Default `FALSE`.
#' @param progress_callback Optional function called with a named list
#'   at each phase (`current = "reconfort:phase"` / `"reconfort:..."`),
#'   for wiring into an app progress bar.
#'
#' @section Temporal window (`s2_year` -> analysis dates):
#' RECONFORT does not diff two dates: it classifies a pixel's ~2-year
#' index trajectory with a pre-trained model. One run is driven entirely
#' by `s2_year` (the last year of the series). The dates flow as:
#'
#' \enumerate{
#'   \item \strong{Download window} (this function): from `s2_year`,
#'     `date_from = (s2_year-1)-01-01` and `date_to = s2_year-12-31`
#'     unless overridden -- two calendar years fetched from Theia.
#'   \item \strong{Analysis window} (IOTA2 cfg, derived from `s2_year` +
#'     `v_model`, \emph{not} from `date_from`/`date_to`):
#'     `S2_start = (s2_year-1)<sdate>`, `S2_end = s2_year<edate>` with
#'     `sdate`/`edate` fixed by the model --
#'     \code{v3}/\code{v3_chestnut}/\code{v3_pine}: `0101` -> `1029`
#'     (Jan of `s2_year-1` to 29 Oct of `s2_year`, ~22 months, the
#'     "2y_nov" calibration); \code{v3_early_may}: `0101` -> `0531`
#'     (~1.5 year).
#'   \item \strong{Features}: IOTA2 gap-fills the cloud-masked S2
#'     acquisitions of the analysis window onto a regular date grid, then
#'     computes CRswir + CRre per date. The per-pixel feature vector is
#'     the full two-year trajectory of both indices.
#'   \item \strong{Classification}: the SharkRF `v_model` labels each
#'     pixel `{1 healthy, 2 declining, 3 severely declining}` (2 classes
#'     for pine) plus a continuous score.
#' }
#'
#' Because the analysis window is model-bound, a custom
#' `date_from`/`date_to` only changes \emph{what is downloaded}, never the
#' window the model sees. To cover several years, call once per `s2_year`
#' (each run = a 2-year window ending end-October of its `s2_year`); the
#' app stacks the resulting yearly maps.
#'
#' @return Invisibly, a list: `status`, `zone_id`, `tiles`, `s2_year`,
#'   `v_model`, `species`, `workdir`, `rasters` (the collected output
#'   paths), `meta` (path to `run_meta.json`) and `elapsed_sec`.
#' @export
run_reconfort_dieback <- function(con, zone_id, cache_dir,
                                  s2_year           = as.integer(format(Sys.Date(), "%Y")),
                                  date_from         = NULL,
                                  date_to           = NULL,
                                  v_model           = "v3",
                                  binary_mask       = NULL,
                                  aoi_crop          = TRUE,
                                  oso_national      = NULL,
                                  number_of_chunks  = 200L,
                                  scheduler_type    = "localCluster",
                                  nb_parallel_tasks = 1L,
                                  output_dir        = NULL,
                                  geodes_config     = NULL,
                                  model_cache_dir   = NULL,
                                  mask_cache_dir    = NULL,
                                  tiles             = NULL,
                                  skip_ingest       = FALSE,
                                  keep_workdir      = TRUE,
                                  quiet             = FALSE,
                                  progress_callback = NULL) {
  t0 <- Sys.time()

  # --- argument validation ----------------------------------------
  if (!inherits(con, "DBIConnection")) {
    cli::cli_abort("{.arg con} must be a {.cls DBIConnection}.")
  }
  if (length(zone_id) != 1L || is.na(zone_id)) {
    cli::cli_abort("{.arg zone_id} must be a scalar non-NA identifier.")
  }
  if (missing(cache_dir) || !is.character(cache_dir) || length(cache_dir) != 1L) {
    cli::cli_abort("{.arg cache_dir} must be a single directory path.")
  }
  info    <- reconfort_model_info(v_model)            # validates v_model
  s2_year <- as.integer(s2_year)
  if (is.na(s2_year)) cli::cli_abort("{.arg s2_year} must be an integer year.")
  if (is.null(date_from)) date_from <- sprintf("%d-01-01", s2_year - 1L)
  if (is.null(date_to))   date_to   <- sprintf("%d-12-31", s2_year)

  label   <- paste0("z", zone_id)
  workdir <- output_dir %||%
    file.path(cache_dir, "reconfort", sprintf("run_z%s_S2%s", zone_id, s2_year))
  run_id  <- format(Sys.time(), "%Y%m%dT%H%M%S")

  # --- progress plumbing ------------------------------------------
  phases <- c("env", "model", "mask", "tiles", "ingest", "stage", "mapprod",
              "collect", "postprocess", "persist")
  emit <- function(payload) {
    if (is.null(progress_callback)) return(invisible(NULL))
    tryCatch(progress_callback(payload), error = function(e) invisible(NULL))
  }
  idx <- 0L
  begin <- function(name) {
    idx <<- idx + 1L
    if (!quiet) cli::cli_alert_info("RECONFORT [{idx}/{length(phases)}] {name} ...")
    emit(list(current = "reconfort:phase", phase_name = name,
              completed = as.integer(idx - 1L), total = length(phases)))
  }
  emit(list(current = "reconfort:start", zone_id = zone_id,
            v_model = v_model, s2_year = s2_year))

  result <- tryCatch({
    # PHASE 1 — env (locate + validate conda/IOTA2) -----------------
    begin("env")
    env <- .ensure_reconfort_python(require_pygeodes = !skip_ingest, quiet = quiet)
    conda_bin <- .reconfort_conda_binary()

    # PHASE 2 — model fetch ----------------------------------------
    begin("model")
    model_path <- ensure_reconfort_model(v_model, cache_dir = model_cache_dir,
                                         quiet = quiet)

    # AOI resolved once, up front: it drives the broadleaf mask, the scene
    # clip and the ground-truth points (all AOI-local — spec 021 prod).
    aoi <- if (!is.null(con) && !is.null(zone_id)) {
      tryCatch(.get_zone_aoi(con, zone_id), error = function(e) NULL)
    } else NULL
    do_crop <- isTRUE(aoi_crop) && !is.null(aoi)

    # PHASE 3 — mask resolution ------------------------------------
    begin("mask")
    do_mask <- !isFALSE(binary_mask)
    oso_nat <- oso_national %||% .reconfort_oso_national_path()
    mask_path <- if (!do_mask) {
      NA_character_
    } else if (is.character(binary_mask)) {
      ensure_reconfort_oso_mask(local_path = binary_mask, verify = FALSE,
                                quiet = quiet)
    } else if (do_crop && !is.null(oso_nat) && file.exists(oso_nat)) {
      # Broadleaf mask cut from the national OSO for this AOI (the upstream
      # partial mask does not cover most of France — incl. the Jura).
      p <- file.path(cache_dir, sprintf("oso_broadleaf_zone_%s.tif", zone_id))
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      .reconfort_oso_broadleaf_mask(oso_nat, aoi, p)
    } else {
      ensure_reconfort_oso_mask(cache_dir = mask_cache_dir, quiet = quiet)
    }

    # PHASE 4 — AOI -> tiles ---------------------------------------
    begin("tiles")
    if (is.null(tiles)) {
      if (is.null(aoi)) {
        cli::cli_abort("Cannot resolve AOI for zone {.val {zone_id}}.")
      }
      tiles <- reconfort_aoi_tiles(aoi, prefix = TRUE)
      if (length(tiles) == 0L) {
        cli::cli_abort("Zone {.val {zone_id}} resolved to no Sentinel-2 tile.")
      }
    }

    # PHASE 5 — ingest S2 ------------------------------------------
    # When cropping (AOI available), the ingestion streams each archive and
    # clips it to the AOI window in-flight — download+extract+crop+delete one
    # scene at a time. This turns a multi-hour full-tile run into minutes,
    # fixes IOTA2's reference-grid bug AND caps peak disk near a single
    # archive (~GB) instead of whole-tile archives + extracted (~460 GB).
    begin("ingest")
    s2_dl_root <- file.path(workdir, "s2_download")
    if (skip_ingest) {
      # Streaming ingest writes the AOI-cropped scenes straight into
      # extracted/<tile>/, so a resumed run reads them as-is.
      extracted <- file.path(s2_dl_root, "extracted", tiles)
    } else {
      ing <- reconfort_ingest_s2(aoi = if (do_crop) aoi else NULL,
                                 tiles = tiles, date_from = date_from,
                                 date_to = date_to, s2_root = s2_dl_root,
                                 geodes_config = geodes_config, quiet = quiet,
                                 progress_callback = progress_callback)
      extracted <- ing$extracted
    }
    if (do_crop) {
      # cropped raster is tiny → one IOTA2 block (avoids the per-chunk
      # mask-vs-fulltile BandMath dimension mismatch).
      if (isTRUE(number_of_chunks == 200L)) number_of_chunks <- 1L
      # ...and IOTA2's localCluster (a Dask cluster of ~nb_cpus workers,
      # each loading the multi-date feature stack) only adds memory
      # pressure on a tiny AOI — enough to trip systemd-oomd and kill the
      # R session mid-classification (observed 2026-06-28). Sequential
      # "debug" keeps memory flat at no real runtime cost here. Only the
      # default is overridden; an explicit scheduler choice is respected.
      if (identical(scheduler_type, "localCluster")) scheduler_type <- "debug"
    }

    # PHASE 6 — stage the working dir ------------------------------
    begin("stage")
    glue <- .reconfort_glue_dir()
    .reconfort_stage_workdir(workdir, glue)
    .reconfort_stage_model(workdir, model_path, v_model)
    if (do_mask) .reconfort_stage_mask(workdir, mask_path)
    s2_path <- .reconfort_stage_s2_layout(workdir, s2_year, tiles, extracted)
    # AOI-local ground truth so IOTA2's part-1 sampling has points inside the
    # clipped envelope (the global random_points.shp would not intersect).
    if (do_crop) {
      tryCatch(
        .reconfort_write_aoi_ground_truth(
          file.path(workdir, "iota2", "vector_db", "random_points.shp"),
          aoi, n_classes = info$n_classes),
        error = function(e) cli::cli_alert_warning(
          "AOI ground-truth generation failed: {conditionMessage(e)}"))
    }

    cfg <- file.path(workdir, "config_file_map_production_nemeton.cfg")
    .reconfort_write_cfg(cfg, list(
      label               = label,
      S2_year             = as.character(s2_year),
      S2_path             = normalizePath(s2_path, mustWork = FALSE),
      number_of_chunks    = as.character(number_of_chunks),
      list_tiles          = paste(tiles, collapse = " "),
      v_model             = v_model,
      mask_final_maps     = if (do_mask) "True" else "False",
      path_to_binary_mask = "",
      scheduler_type      = scheduler_type,
      nb_parallel_tasks   = as.character(nb_parallel_tasks)
    ))

    # PHASE 7 — map production (IOTA2 x2 + mask + score) -----------
    begin("mapprod")
    st <- .reconfort_run_py(conda_bin, env,
                            file.path(workdir, "run_map_production_reconfort.py"),
                            cfg, workdir, quiet = quiet)
    if (!identical(as.integer(st), 0L)) {
      cli::cli_abort("RECONFORT map production failed for zone {.val {zone_id}} (exit {st}).")
    }

    # PHASE 8 — collect outputs ------------------------------------
    begin("collect")
    rasters <- .reconfort_collect_outputs(workdir, label, s2_year)
    # The upstream driver does not check the IOTA2 subprocess return
    # code; verify the continuous score actually landed.
    if (is.na(rasters$continuous_score)) {
      cli::cli_abort(c(
        "RECONFORT produced no continuous-score raster for zone {.val {zone_id}}.",
        i = "Expected under {.path {rasters$final_dir}} — the IOTA2 run may have failed silently (RAM/scheduler/data)."
      ))
    }

    # PHASE 9 — postprocess: rasters → centroïdes de cluster → table `alert`
    # (L3, spec 021). Best-effort : un run réel peut légitimement ne produire
    # aucun patch, et on ne veut jamais qu'un accroc de post-process jette un
    # run IOTA2 de plusieurs heures. Échecs → warn.
    #
    # Phase B (spec 008 §15 / ADR-013 A5) — re-persistance pixel. Les
    # centroïdes (`alerts_sf`) sont RENVOYÉS dans le résultat (consommés en
    # mémoire par `indicateur_r5_deperissement()`, parité FORDEAD) ET
    # ré-insérés dans `alert` comme entités raster/cluster géoréférencées
    # (sans placette), stratégie replace-by-window sur la fenêtre du run.
    begin("postprocess")
    classif_for_alerts <- if (!is.na(rasters$classif_masked))
      rasters$classif_masked else rasters$classif
    trigger_date <- tryCatch(as.Date(date_to), error = function(e) Sys.Date())
    alerts_sf <- tryCatch(
      .postprocess_reconfort_rasters(
        list(classif = classif_for_alerts,
             continuous_score = rasters$continuous_score),
        species = info$species, trigger_date = trigger_date),
      error = function(e) {
        cli::cli_warn("RECONFORT post-process (clustering) failed: {conditionMessage(e)}")
        NULL
      })
    n_alerts <- tryCatch(
      # Idempotent : un re-run efface les alertes reconfort_dieback
      # antérieures de la zone avant ré-insertion (replace = TRUE).
      .insert_reconfort_alerts(con, alerts_sf, zone_id = zone_id,
                               replace = TRUE),
      error = function(e) {
        cli::cli_warn("RECONFORT alert insertion failed: {conditionMessage(e)}")
        NA_integer_
      })

    # PHASE 10 — persist CRswir/CRre features for the pixel diagnostic
    # (L5, spec 021). Best-effort, recomputed from the ingested S2
    # (option B). Skips quietly if no scene is enumerable so a heavy run
    # is never discarded over a diagnostic detail. Bundle lands at
    # <cache_dir>/zone_<id>/run_<run_id>/ for read_reconfort_pixel_series().
    begin("persist")
    # Persist the classified raster as the flat zone mask consumed by
    # read_reconfort_alert_mask() / create_validation_sampling_plan()
    # (source = "RECONFORT") — the RECONFORT mirror of FORDEAD's
    # dieback_mask. Best-effort.
    tryCatch({
      if (!is.na(classif_for_alerts) && file.exists(classif_for_alerts)) {
        zdir <- file.path(cache_dir, sprintf("zone_%s", zone_id))
        if (!dir.exists(zdir)) dir.create(zdir, recursive = TRUE, showWarnings = FALSE)
        file.copy(classif_for_alerts,
                  file.path(zdir, sprintf("reconfort_mask_%s.tif", run_id)),
                  overwrite = TRUE)
      }
    }, error = function(e)
      cli::cli_warn("RECONFORT persist (class mask) failed: {conditionMessage(e)}"))

    features_bundle <- tryCatch({
      scenes <- .enumerate_reconfort_s2_scenes(file.path(workdir, "S2_data"))
      if (!length(scenes)) {
        cli::cli_warn("RECONFORT persist: no S2 scene enumerable under {.path {file.path(workdir, 'S2_data')}} — pixel diagnostic skipped.")
        NA_character_
      } else {
        stacks <- .build_reconfort_feature_stacks(scenes)
        bdir <- file.path(cache_dir, sprintf("zone_%s", zone_id),
                          sprintf("run_%s", run_id))
        .write_reconfort_features_bundle(bdir, stacks, run_meta = list(
          zone_id = zone_id, run_id = run_id, species = info$species,
          v_model = v_model, n_classes = info$n_classes,
          date_from = date_from, date_to = date_to))
        bdir
      }
    }, error = function(e) {
      cli::cli_warn("RECONFORT persist (features bundle) failed: {conditionMessage(e)}")
      NA_character_
    })

    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    meta <- list(
      tool = "reconfort", status = "completed",
      zone_id = zone_id, run_id = run_id, tiles = tiles, s2_year = s2_year,
      date_from = date_from, date_to = date_to,
      v_model = v_model, species = info$species, n_classes = info$n_classes,
      masked = do_mask, mask = if (do_mask) mask_path else NA_character_,
      env = env, scheduler_type = scheduler_type,
      rasters = rasters, n_alerts = n_alerts,
      features_bundle = features_bundle, elapsed_sec = elapsed,
      generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    )
    meta_path <- .reconfort_write_run_meta(
      file.path(rasters$final_dir, "run_meta.json"), meta)

    if (!quiet) cli::cli_alert_success(
      "RECONFORT: zone {.val {zone_id}} done ({length(tiles)} tile{?s}, model {.val {v_model}}).")
    emit(list(current = "reconfort:complete", zone_id = zone_id,
              completed = length(phases), total = length(phases)))

    list(status = "completed", zone_id = zone_id, run_id = run_id,
         tiles = tiles, s2_year = s2_year, v_model = v_model,
         species = info$species, workdir = workdir, rasters = rasters,
         n_alerts = n_alerts, alerts_sf = alerts_sf,
         features_bundle = features_bundle,
         meta = meta_path, elapsed_sec = elapsed)
  },
  error = function(e) {
    emit(list(current = "reconfort:error", zone_id = zone_id,
              error_message = conditionMessage(e)))
    if (!keep_workdir && dir.exists(workdir)) unlink(workdir, recursive = TRUE)
    cli::cli_abort(c("RECONFORT dieback run failed.", x = conditionMessage(e)),
                   parent = e)
  })

  if (!keep_workdir && dir.exists(workdir)) unlink(workdir, recursive = TRUE)
  invisible(result)
}
