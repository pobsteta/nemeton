# ICD : chaine de calcul par zone de suivi (spec 071). Les calculs purs sont
# dans icd_calcul.R ; ici : cache de scenes, composites mensuels, z, ICD,
# classes annuelles, sorties sur disque (ADR-002), alertes, evenements.

# --- Chemins -----------------------------------------------------------------

.icd_dossier_zone <- function(result_dir, zone_id) {
  file.path(result_dir, sprintf("zone_%d", as.integer(zone_id)))
}

.icd_resoudre_result_dir <- function(result_dir, cache_dir = NULL) {
  if (!is.null(result_dir) && nzchar(result_dir)) return(result_dir)
  if (!is.null(cache_dir) && nzchar(cache_dir)) {
    return(file.path(dirname(cache_dir), "icd"))
  }
  cli::cli_abort("{.arg result_dir} (or {.arg cache_dir}) is required.")
}

# Ecriture atomique : fichier temporaire du meme dossier puis renommage. Le
# point initial soustrait le temporaire aux lecteurs.
.icd_ecrire_atomique <- function(r, chemin) {
  dir.create(dirname(chemin), recursive = TRUE, showWarnings = FALSE)
  tmp <- file.path(dirname(chemin), paste0(".tmp_", basename(chemin)))
  terra::writeRaster(r, tmp, overwrite = TRUE)
  ok <- file.rename(tmp, chemin)
  if (!ok) {
    unlink(tmp)
    cli::cli_abort("Cannot move {.path {tmp}} to {.path {chemin}}.")
  }
  invisible(chemin)
}

# Un composite illisible (coupure reseau, disque plein) est detecte ici : le
# fichier se rouvre, porte les 5 couches et ses valeurs se lisent.
.icd_composite_lisible <- function(chemin) {
  if (!file.exists(chemin)) return(FALSE)
  tryCatch({
    r <- terra::rast(chemin)
    terra::nlyr(r) == length(.ICD_INDICES) &&
      is.matrix(terra::values(r, nrows = 1L, mat = TRUE))
  }, error = function(e) FALSE, warning = function(w) FALSE)
}

# --- Grille et couches d'entree ---------------------------------------------

# Grille commune : Lambert-93, 20 m, emprise de la zone calee sur 20 m.
.icd_grille <- function(aoi) {
  bb <- sf::st_bbox(sf::st_transform(aoi, 2154))
  terra::rast(xmin = floor(bb[["xmin"]] / 20) * 20,
              xmax = ceiling(bb[["xmax"]] / 20) * 20,
              ymin = floor(bb[["ymin"]] / 20) * 20,
              ymax = ceiling(bb[["ymax"]] / 20) * 20,
              resolution = 20, crs = "EPSG:2154")
}

# Essence par pixel : 1..4 (ordre de .ICD_ESSENCES), NA ailleurs. `bdforet` :
# sf BD Foret V2 (colonne du code TFV) ou SpatRaster deja code 1..4. Les
# peuplements purs sont reduits de `buffer_interieur` m (lisiere retiree).
.icd_raster_essence <- function(bdforet, grille, buffer_interieur = 10) {
  if (inherits(bdforet, "SpatRaster")) {
    r <- terra::resample(bdforet[[1L]], grille, method = "near")
    names(r) <- "essence"
    return(r)
  }
  if (!inherits(bdforet, "sf")) {
    cli::cli_abort("{.arg bdforet} must be an sf (BD Foret V2) or a SpatRaster of codes 1..4.")
  }
  col <- intersect(c("code_tfv", "CODE_TFV", "tfv", "TFV"), names(bdforet))
  if (!length(col)) {
    cli::cli_abort("{.arg bdforet} needs a TFV code column ({.field code_tfv}).")
  }
  bd <- sf::st_transform(bdforet, 2154)
  code <- match(as.character(bd[[col[1L]]]), .ICD_TFV)
  bd <- bd[!is.na(code), , drop = FALSE]
  code <- code[!is.na(code)]
  out <- terra::rast(grille, nlyrs = 1L)
  names(out) <- "essence"
  if (!nrow(bd)) return(out)
  geom <- sf::st_buffer(sf::st_geometry(bd), -abs(buffer_interieur))
  garde <- !sf::st_is_empty(geom)
  if (!any(garde)) return(out)
  v <- terra::vect(sf::st_sf(code = code[garde], geometry = geom[garde]))
  r <- terra::rasterize(v, out, field = "code", touches = FALSE)
  names(r) <- "essence"
  r
}

# Date de coupe par pixel de 20 m (jours depuis 1970-01-01) : un pixel est
# coupe si au moins 2 de ses 4 sous-pixels de 10 m le sont (note, section 9) ;
# il prend la date la plus precoce. `proba` (en %) : coupe retenue si >= 90.
.icd_date_coupe <- function(sufosat_dates, sufosat_proba = NULL, grille) {
  d <- sufosat_dates[[1L]]
  if (!is.null(sufosat_proba)) {
    d <- terra::ifel(sufosat_proba[[1L]] >= 90, d, NA)
  }
  j <- terra::setValues(d, as.numeric(.icd_yyddd_vers_date(terra::values(d, mat = FALSE))))
  if (all(abs(terra::res(j) - 10) < 1e-6)) {
    n <- terra::aggregate(!is.na(j), fact = 2, fun = "sum", na.rm = TRUE)
    mn <- terra::aggregate(j, fact = 2, fun = "min", na.rm = TRUE)
    j <- terra::ifel(n >= 2, mn, NA)
  }
  r <- terra::project(j, grille, method = "near")
  names(r) <- "date_coupe"
  r
}

# --- Scenes du cache ---------------------------------------------------------

# Scenes du cache commun portant les 10 couches de l'ICD, dans [from, to].
.icd_scenes_cache <- function(cache_dir, from, to) {
  vide <- data.frame(scene_id = character(0), obs_date = as.Date(character(0)),
                     stringsAsFactors = FALSE)
  dirs <- list.dirs(cache_dir, recursive = FALSE)
  if (!length(dirs)) return(vide)
  complet <- vapply(dirs, function(d)
    all(file.exists(file.path(d, paste0(.ICD_BANDES, ".tif")))), logical(1))
  dirs <- dirs[complet]
  if (!length(dirs)) return(vide)
  sid <- basename(dirs)
  od <- .s2_scene_date(sid)
  garde <- !is.na(od) & od >= as.Date(from) & od <= as.Date(to)
  out <- data.frame(scene_id = sid[garde], obs_date = od[garde],
                    stringsAsFactors = FALSE)
  out[order(out$obs_date), , drop = FALSE]
}

# Lit une bande du cache et la ramene sur la grille de reference `ref`
# (agregation 10 m -> 20 m, sinon reechantillonnage).
.icd_lire_bande <- function(chemin, ref, methode = "bilinear") {
  r <- terra::rast(chemin)
  if (terra::compareGeom(r, ref, stopOnError = FALSE)) return(r)
  rr <- terra::res(r); rf <- terra::res(ref)
  if (identical(methode, "bilinear") && all(abs(rr * 2 - rf) < 1e-6) &&
      terra::same.crs(r, ref)) {
    r <- terra::aggregate(r, fact = 2, fun = "mean", na.rm = TRUE)
    if (terra::compareGeom(r, ref, stopOnError = FALSE)) return(r)
  }
  terra::resample(r, ref, method = methode)
}

# Les 5 indices d'une scene, masques par la SCL (classes .ICD_SCL_MASQUE),
# sur la grille commune. La reflectance retire l'offset de la scene
# (.s2_harmonize_band, spec 055) puis divise par 10 000.
.icd_indices_scene <- function(dossier, scene_id, grille) {
  chemin <- function(b) file.path(dossier, paste0(b, ".tif"))
  ref <- terra::rast(chemin("B11"))
  bandes <- lapply(setdiff(.ICD_BANDES, "SCL"), function(b) {
    r <- .icd_lire_bande(chemin(b), ref)
    r <- .s2_harmonize_band(r, scene_id)
    r <- terra::ifel(r == 0, NA, r) / 10000
    names(r) <- b
    r
  })
  bandes <- terra::rast(bandes)
  idx <- icd_indices(bandes)
  scl <- .icd_lire_bande(chemin("SCL"), ref, methode = "near")
  scl <- terra::ifel(is.na(scl), 0, scl)
  idx <- terra::mask(idx, scl, maskvalues = .ICD_SCL_MASQUE)
  terra::project(idx, grille, method = "bilinear")
}

# Composite d'un mois : mediane, par indice, des images valides du mois.
.icd_composite_mois <- function(scenes, cache_dir, grille, cancelled = function() FALSE) {
  pile <- list()
  for (i in seq_len(nrow(scenes))) {
    if (cancelled()) .icd_signal_cancel("composite")
    sid <- scenes$scene_id[i]
    r <- tryCatch(.icd_indices_scene(file.path(cache_dir, sid), sid, grille),
                  error = function(e) {
                    cli::cli_warn("ICD: scene {.val {sid}} skipped: {conditionMessage(e)}")
                    NULL
                  })
    if (!is.null(r)) pile[[length(pile) + 1L]] <- r
  }
  if (!length(pile)) return(NULL)
  pile <- terra::rast(pile)
  noms <- names(pile)
  comp <- lapply(.ICD_INDICES, function(ix) {
    terra::app(pile[[which(noms == ix)]], "median", na.rm = TRUE)
  })
  comp <- terra::rast(comp)
  names(comp) <- .ICD_INDICES
  comp
}

.icd_signal_cancel <- function(phase) {
  rlang::abort(sprintf("ICD run cancelled at phase '%s'.", phase),
               class = "nemeton_cancelled", phase = phase)
}

# Fenetres de telechargement : par annee, d'avril au dernier mois utile. Avec
# "garder", un mois non termine depuis 5 jours n'est ni telecharge ni refait ;
# avec "refaire", on va jusqu'a aujourd'hui. Annee sans mois utile : omise.
.icd_fenetres_ingestion <- function(annees, today, mois_en_cours = "garder") {
  today <- as.Date(today)
  out <- list()
  for (y in annees) {
    ms <- .ICD_MOIS_SAISON[as.Date(sprintf("%04d-%02d-01", y, .ICD_MOIS_SAISON)) <= today]
    if (identical(mois_en_cours, "garder")) {
      ms <- ms[!vapply(ms, function(m) .icd_mois_en_cours(y, m, today), logical(1))]
    }
    if (!length(ms)) next
    dernier <- max(ms)
    fin <- as.Date(sprintf("%04d-%02d-01", y + (dernier == 12L),
                           if (dernier == 12L) 1L else dernier + 1L)) - 1
    out[[length(out) + 1L]] <- data.frame(
      start = sprintf("%04d-04-01", y), end = as.character(min(fin, today)),
      stringsAsFactors = FALSE)
  }
  if (length(out)) do.call(rbind, out)
  else data.frame(start = character(0), end = character(0))
}

# --- Chaine ------------------------------------------------------------------

#' Composite discoloration indicator (ICD) for a monitoring zone
#'
#' Runs the ICD chain of the method note "Suivi de la decoloration anormale du
#' feuillage" (v2, 2026-10-29, sections 3 to 8) on one monitoring zone, as
#' FAST, FORDEAD and RECONFORT do (spec 071):
#' \enumerate{
#'   \item **Ingest** (`ingest = TRUE`): Sentinel-2 L2A bands B03, B04, B05,
#'     B06, B07, B08, B8A, B11, B12 and the SCL layer, into the shared COG
#'     cache (`ingest_s2_raw_bands_to_cache()`, events `s2:*`).
#'   \item **Indices** per scene at 20 m ([icd_indices()]), after the L2A
#'     offset correction and the SCL mask (classes 0, 1, 3, 8, 9, 10, 11).
#'   \item **Monthly composite**, April to October, since 2017: the median of
#'     the valid images of the month; a month without valid image stays
#'     empty. A composite is written atomically; an unreadable one is deleted
#'     and rebuilt at the next run. With `mois_en_cours = "garder"` the month
#'     under way is left as it is until it has ended for 5 days.
#'   \item **Standardised anomaly** `z = (x - median of the other years) /
#'     max(1.4826 MAD, floor)`, same pixel, same month; at least 4 reference
#'     years, otherwise `NA`. Floors: 0.01 (GRVI, CRre, NDVI), 0.05 (CIre),
#'     0.02 (CRSWIR). A pixel is removed from its clear-cut month onward when
#'     `sufosat_dates` is given.
#'   \item **ICD** `w1 z(GRVI) + w2 z(CIre) - w3 z(CRSWIR) - w4 z(CRre) + w5
#'     z(NDVI)` on the sensitive months of the species group, with the
#'     weights `poids`.
#'   \item **Class and level** of each year: Alert (ICD < -2 for at least 2
#'     consecutive valid months, alert date = first month), Watch (ICD < -1.5
#'     once), Normal; levels 0 to 4 (3 = alert with minimum ICD < -3, 4 =
#'     alert this year and over the whole previous season). A second set,
#'     "to date", reads every year on the months already available this
#'     year.
#' }
#' Only pixels of the four pure stands (BD Foret V2, TFV FF1G01-01, FF1-09-09,
#' FF2G61-61, FF2-64-64; 10 m edge removed) get an ICD; the others have none
#' (no value is invented). Only the weights are parameters; thresholds,
#' persistence and months are those of the note.
#'
#' Outputs are rasters under `<result_dir>/zone_<id>/`: `composites/`,
#' `z/`, `icd/` (one file per year and month), `annuel/` and `annuel_a_date/`
#' (layers `classe`, `niveau`, `icd_min`, `mois_alerte`, `n_mois_valides`),
#' `essence.tif` and `meta.json`. They are read back with [read_icd_raster()]
#' and [read_icd_pixel_series()].
#'
#' Progress events (`progress_callback`, same channel as `s2:*`):
#' `icd:start`, `icd:composite` (`completed`, `total`), `icd:anomalies`,
#' `icd:annuel`, `icd:alertes`, then exactly one terminal event:
#' `icd:complete`, `icd:cancelled` or `icd:error`. Cancellation is
#' cooperative: the `cancel_path` flag file is polled before each scene and
#' each month; what is already on disk stays valid.
#'
#' @param con A `DBIConnection` (zone geometry, alerts), or `NULL` when `aoi`
#'   is given.
#' @param zone_id Integer. Monitoring zone.
#' @param cache_dir Character. Root of the Sentinel-2 COG cache.
#' @param result_dir Character. Root of the ICD results; default
#'   `<dirname(cache_dir)>/icd`.
#' @param poids Weights table, see [icd_poids_defaut()] and
#'   [icd_poids_valider()]; a row whose sum is not 1 is rescaled to 1 and the
#'   run says so.
#' @param bdforet BD Foret V2 polygons (`sf` with a `code_tfv` column) or a
#'   `SpatRaster` already coded 1..4 (`chene`, `hetre`, `sapin_epicea`,
#'   `douglas`). Required: without species there is no ICD.
#' @param sufosat_dates,sufosat_proba Optional `SpatRaster`s of SUFOSAT
#'   clear-cut dates (`YYDDD`) and probability (percent, kept when >= 90).
#'   Without them clear-cuts are not removed, and the result says so.
#' @param annees_reference Optional integer vector of healthy years used as
#'   reference; default: all other years.
#' @param buffer_interieur Edge removed from the pure stands, in metres.
#' @param start_year,end_year First and last year; `end_year` defaults to the
#'   year of `today`.
#' @param ingest Logical. Fetch the bands first (needs `con` and the network).
#' @param max_cloud Scene cloud cover ceiling for the STAC search (percent).
#' @param mois_en_cours `"garder"` (default) or `"refaire"`.
#' @param apply_zone_mask Logical. Mask pixels outside the UGF zone.
#' @param write_alerts Logical. Write the yearly alerts of the last year in
#'   the `alert` table (`alert_type = "icd_decoloration"`) when `con` is a
#'   database connection.
#' @param progress_callback Optional `function(payload)`.
#' @param cancel_path Optional cancellation flag file.
#' @param today Date; for tests.
#' @param aoi Optional `sf` zone polygon, instead of reading it from `con`.
#' @return A list with `status` (`"success"`, `"cancelled"`, `"error"`),
#'   `zone_dir`, `annees`, `poids` (the weights actually used, with the
#'   attributes of [icd_poids_valider()]), `coupes_retirees` (logical),
#'   `n_pixels_zone`, `n_pixels_icd`, `n_pixels_sans_icd`, `alertes` (rows
#'   inserted) and `message`.
#' @seealso [read_icd_raster()], [read_icd_pixel_series()],
#'   [comparer_fast_icd()], [icd_poids_defaut()].
#' @param source_s2 Sentinel-2 reflectance source (mission 096): `NULL` (the
#'   method's default: Sen2Cor; THEIA results go to `<result_dir>_theia`), `"theia"` (MAJA, THEIA STAC catalogue, cache
#'   `<cache_dir>_theia`) or `"sen2cor"` (Planetary Computer). A method running
#'   off its calibration source warns (class `nemeton_s2_source_non_calee`) and
#'   records `calee_sur` and `validee = FALSE`; THEIA unavailable switches the
#'   WHOLE series to Sen2Cor (class `nemeton_s2_repli_sen2cor`); a 401/403 or
#'   missing keys is an error. The effective source is written in the outputs
#'   as `source_s2`. See [s2_source_resoudre()].
#' @export
run_icd_decoloration <- function(con = NULL, zone_id, cache_dir,
                                 result_dir = NULL,
                                 poids = icd_poids_defaut(),
                                 bdforet = NULL,
                                 sufosat_dates = NULL, sufosat_proba = NULL,
                                 annees_reference = NULL,
                                 buffer_interieur = 10,
                                 start_year = .ICD_ANNEE_DEBUT,
                                 end_year = NULL,
                                 ingest = TRUE, max_cloud = .ICD_NUAGES_MAX,
                                 mois_en_cours = c("garder", "refaire"),
                                 apply_zone_mask = TRUE,
                                 write_alerts = TRUE,
                                 progress_callback = NULL,
                                 cancel_path = NULL,
                                 today = Sys.Date(),
                                 aoi = NULL,
                                 source_s2 = NULL) {
  mois_en_cours <- match.arg(mois_en_cours)
  source_s2 <- .s2_source_valider(source_s2)
  # Sans `source_s2` : Sen2Cor (source de calage de l'ICD), aucune sonde.
  if (is.null(source_s2) || !isTRUE(ingest) || is.null(con)) {
    src0 <- source_s2 %||% "sen2cor"
    sel <- list(demandee = src0, effective = src0, repli = FALSE,
                cause = NA_character_)
  } else {
    sel <- .s2_choisir_source("icd", source_s2)
  }
  .s2_avertir_non_calee("icd", sel$effective)
  r <- .s2_avec_repli("icd", sel$effective, function(src) {
    .run_icd_decoloration_src(
      con = con, zone_id = zone_id, cache_dir = .s2_cache_dir_source(cache_dir, src),
      result_dir = if (!is.null(result_dir) && nzchar(result_dir))
        .s2_cache_dir_source(result_dir, src) else NULL,
      poids = poids, bdforet = bdforet, sufosat_dates = sufosat_dates,
      sufosat_proba = sufosat_proba, annees_reference = annees_reference,
      buffer_interieur = buffer_interieur, start_year = start_year,
      end_year = end_year, ingest = ingest, max_cloud = max_cloud,
      mois_en_cours = mois_en_cours, apply_zone_mask = apply_zone_mask,
      write_alerts = write_alerts, progress_callback = progress_callback,
      cancel_path = cancel_path, today = today, aoi = aoi,
      source_effective = src)
  })
  res <- r$valeur
  # Un cache THEIA donne un dossier de resultats THEIA : jamais de melange.
  if (!is.null(source_s2)) {
    res$source_s2 <- r$source
    res$repli_sen2cor <- isTRUE(sel$repli) || isTRUE(r$repli)
  }
  res
}

.run_icd_decoloration_src <- function(con, zone_id, cache_dir, result_dir,
                                      poids, bdforet, sufosat_dates,
                                      sufosat_proba, annees_reference,
                                      buffer_interieur, start_year, end_year,
                                      ingest, max_cloud, mois_en_cours,
                                      apply_zone_mask, write_alerts,
                                      progress_callback, cancel_path, today,
                                      aoi, source_effective = "sen2cor") {
  emit <- function(payload) {
    if (!is.null(progress_callback)) {
      tryCatch(progress_callback(payload), error = function(e) invisible(NULL))
    }
  }
  if (length(zone_id) != 1L || is.na(zone_id) ||
      !is.finite(suppressWarnings(as.numeric(zone_id)))) {
    cli::cli_abort("{.arg zone_id} must be a single non-NA integer.")
  }
  zid <- as.integer(zone_id)
  if (missing(cache_dir) || !is.character(cache_dir) || !nzchar(cache_dir)) {
    cli::cli_abort("{.arg cache_dir} is required.")
  }
  today <- as.Date(today)
  if (is.null(end_year)) end_year <- as.integer(format(today, "%Y"))
  annees <- seq.int(as.integer(start_year), as.integer(end_year))
  cancelled <- .make_cancel_checker(cancel_path)
  res <- list(status = "error", zone_id = zid, annees = annees,
              message = NA_character_)

  tryCatch({
    pw <- icd_poids_valider(poids)       # dit s'il renormalise
    res$poids <- pw
    if (is.null(bdforet)) {
      cli::cli_abort(c("{.arg bdforet} is required.",
                       i = "Without the species (BD Foret V2 pure stands) there is no ICD."))
    }
    zone <- aoi %||% .get_zone_aoi(con, zid)
    zone <- sf::st_transform(zone, 2154)
    grille <- .icd_grille(zone)
    zdir <- .icd_dossier_zone(
      .s2_cache_dir_source(.icd_resoudre_result_dir(result_dir, cache_dir),
                           source_effective), zid)
    dir.create(zdir, recursive = TRUE, showWarnings = FALSE)
    res$zone_dir <- zdir
    emit(list(current = "icd:start", zone_id = zid,
              start_year = as.integer(start_year), end_year = as.integer(end_year)))

    # Zone modifiee depuis le dernier calcul : les composites sont masques
    # a l'UGF, on repart de zero.
    zhash <- if (isTRUE(apply_zone_mask)) {
      substr(rlang::hash(sf::st_as_text(sf::st_union(sf::st_geometry(zone)))), 1L, 16L)
    } else "sans_masque"
    meta_av <- .icd_lire_meta(zdir)
    if (!is.null(meta_av) && !identical(meta_av$zone_hash, zhash)) {
      unlink(file.path(zdir, c("composites", "z", "icd", "annuel", "annuel_a_date")),
             recursive = TRUE)
    }

    # 1. Ingestion
    if (isTRUE(ingest)) {
      if (is.null(con)) {
        cli::cli_warn("{.arg ingest} needs {.arg con}; skipped.")
      } else {
        # Avril a octobre de chaque annee seulement, et pas le mois en cours
        # (note, section 5) ; une fenetre par annee.
        fen <- .icd_fenetres_ingestion(annees, today, mois_en_cours)
        for (i in seq_len(nrow(fen))) {
          if (cancelled()) .icd_signal_cancel("ingest")
          args <- list(
            con, zid, bands = .ICD_BANDES,
            start = fen$start[i], end = fen$end[i],
            cache_dir = cache_dir, max_cloud = max_cloud,
            progress_callback = progress_callback, cancel_path = cancel_path)
          # Sen2Cor : appel strictement celui d'avant.
          if (!identical(source_effective, "sen2cor")) {
            args$source_effective <- source_effective
          }
          ing <- do.call(ingest_s2_raw_bands_to_cache, args)
          if (isTRUE(ing$cancelled)) .icd_signal_cancel("ingest")
        }
      }
    }

    # 2. Essence, coupes
    ess <- .icd_raster_essence(bdforet, grille, buffer_interieur)
    poly <- if (isTRUE(apply_zone_mask)) zone else NULL
    if (!is.null(poly)) ess <- .apply_zone_mask(ess, poly)
    .icd_ecrire_atomique(ess, file.path(zdir, "essence.tif"))
    ess_v <- terra::values(ess, mat = FALSE)
    zone_masque <- if (!is.null(poly)) {
      terra::values(.apply_zone_mask(terra::setValues(terra::rast(grille), 1), poly),
                    mat = FALSE)
    } else rep(1, length(ess_v))
    res$n_pixels_zone    <- sum(!is.na(zone_masque))
    res$n_pixels_icd     <- sum(!is.na(ess_v))
    res$n_pixels_sans_icd <- res$n_pixels_zone - res$n_pixels_icd
    res$par_essence <- stats::setNames(
      vapply(seq_along(.ICD_ESSENCES), function(k) sum(ess_v == k, na.rm = TRUE), numeric(1)),
      .ICD_ESSENCES)
    date_coupe <- NULL
    res$coupes_retirees <- !is.null(sufosat_dates)
    if (!is.null(sufosat_dates)) {
      date_coupe <- as.Date(terra::values(
        .icd_date_coupe(sufosat_dates, sufosat_proba, grille), mat = FALSE),
        origin = "1970-01-01")
    } else {
      cli::cli_inform(c("i" = "No SUFOSAT clear-cut layer: clear-cut pixels are not removed from the ICD."))
    }

    # 3. Composites mensuels
    todo <- expand.grid(mois = .ICD_MOIS_SAISON, annee = annees)
    todo <- todo[as.Date(sprintf("%04d-%02d-01", todo$annee, todo$mois)) <= today, ]
    todo <- todo[order(todo$annee, todo$mois), ]
    scenes <- .icd_scenes_cache(cache_dir, sprintf("%d-04-01", min(annees)),
                                sprintf("%d-12-31", max(annees)))
    scenes$cle <- format(scenes$obs_date, "%Y-%m")
    for (k in seq_len(nrow(todo))) {
      if (cancelled()) .icd_signal_cancel("composite")
      y <- todo$annee[k]; m <- todo$mois[k]
      emit(list(current = "icd:composite", completed = as.integer(k - 1L),
                total = as.integer(nrow(todo)), annee = y, mois = m))
      f <- file.path(zdir, "composites", sprintf("%04d-%02d.tif", y, m))
      fm <- sub("\\.tif$", ".json", f)
      if (file.exists(f) && !.icd_composite_lisible(f)) {
        cli::cli_inform(c("!" = "Unreadable ICD composite {.file {basename(f)}} removed, rebuilt."))
        unlink(c(f, fm))
      }
      if (file.exists(f)) {
        final <- tryCatch(isTRUE(jsonlite::read_json(fm)$final), error = function(e) FALSE)
        en_cours <- .icd_mois_en_cours(y, m, today)
        # Mois termine : un composite ecrit avant la fin du mois est refait
        # une derniere fois ; "garder" laisse tel quel le mois en cours.
        if (final || (mois_en_cours == "garder" && en_cours)) next
      }
      sc <- scenes[scenes$cle == sprintf("%04d-%02d", y, m), , drop = FALSE]
      if (!nrow(sc)) next
      comp <- .icd_composite_mois(sc, cache_dir, grille, cancelled)
      if (is.null(comp)) next
      if (!is.null(poly)) comp <- .apply_zone_mask(comp, poly)
      .icd_ecrire_atomique(comp, f)
      writeLines(jsonlite::toJSON(list(
        ecrit_le = as.character(today), n_scenes = nrow(sc),
        final = !.icd_mois_en_cours(y, m, today)), auto_unbox = TRUE), fm)
    }

    # 4. Anomalies z et ICD par mois
    w_ess <- lapply(.ICD_ESSENCES, function(e) {
      unlist(pw[pw$essence == e, .ICD_INDICES])
    })
    names(w_ess) <- .ICD_ESSENCES
    n_cell <- terra::ncell(grille)
    for (m in .ICD_MOIS_SAISON) {
      if (cancelled()) .icd_signal_cancel("anomalies")
      emit(list(current = "icd:anomalies", mois = m))
      fich <- file.path(zdir, "composites", sprintf("%04d-%02d.tif", annees, m))
      dispo <- file.exists(fich)
      if (!any(dispo)) next
      X <- lapply(.ICD_INDICES, function(ix) matrix(NA_real_, n_cell, length(annees)))
      names(X) <- .ICD_INDICES
      for (j in which(dispo)) {
        vals <- terra::values(terra::rast(fich[j]), mat = TRUE)
        for (ix in .ICD_INDICES) X[[ix]][, j] <- vals[, ix]
      }
      X <- lapply(X, .icd_retirer_coupes, annees = annees, mois = m,
                  date_coupe = date_coupe)
      Z <- lapply(.ICD_INDICES, function(ix) {
        .icd_z(X[[ix]], annees, .ICD_PLANCHERS[[ix]], annees_reference)
      })
      names(Z) <- .ICD_INDICES
      for (j in which(dispo)) {
        zr <- terra::rast(grille, nlyrs = length(.ICD_INDICES))
        terra::values(zr) <- vapply(Z, function(M) M[, j], numeric(n_cell))
        names(zr) <- .ICD_INDICES
        .icd_ecrire_atomique(zr, file.path(zdir, "z", sprintf("%04d-%02d.tif", annees[j], m)))
        zj <- lapply(Z, function(M) M[, j]); names(zj) <- .ICD_INDICES
        v <- rep(NA_real_, n_cell)
        for (k in seq_along(.ICD_ESSENCES)) {
          e <- .ICD_ESSENCES[k]
          if (!m %in% .ICD_MOIS[[e]]) next
          sel <- which(ess_v == k)
          if (!length(sel)) next
          v[sel] <- .icd_icd(lapply(zj, function(x) x[sel]), w_ess[[e]])
        }
        ir <- terra::setValues(terra::rast(grille, nlyrs = 1L), v)
        names(ir) <- "ICD"
        .icd_ecrire_atomique(ir, file.path(zdir, "icd", sprintf("%04d-%02d.tif", annees[j], m)))
      }
    }

    # 5. Classes et niveaux annuels (saison complete, puis "a date")
    mois_date <- .icd_mois_utilisables(today)
    prec_complet <- NULL
    for (y in annees) {
      if (cancelled()) .icd_signal_cancel("annuel")
      emit(list(current = "icd:annuel", annee = y))
      M <- matrix(NA_real_, n_cell, length(.ICD_MOIS_SAISON))
      for (jm in seq_along(.ICD_MOIS_SAISON)) {
        f <- file.path(zdir, "icd", sprintf("%04d-%02d.tif", y, .ICD_MOIS_SAISON[jm]))
        if (file.exists(f)) M[, jm] <- terra::values(terra::rast(f), mat = FALSE)
      }
      comp <- .icd_annuel(M, ess_v, prec_complet, NULL)
      adate <- .icd_annuel(M, ess_v, prec_complet, mois_date)
      for (nm in c("annuel", "annuel_a_date")) {
        a <- if (nm == "annuel") comp else adate
        r <- terra::rast(grille, nlyrs = 5L)
        terra::values(r) <- cbind(a$classe, a$niveau, a$icd_min,
                                  as.numeric(a$mois_alerte), as.numeric(a$n_mois_valides))
        names(r) <- c("classe", "niveau", "icd_min", "mois_alerte", "n_mois_valides")
        .icd_ecrire_atomique(r, file.path(zdir, nm, sprintf("%04d.tif", y)))
      }
      prec_complet <- comp$classe
    }

    # 6. Alertes (derniere annee) dans la table `alert`
    res$alertes <- 0L
    if (isTRUE(write_alerts) && inherits(con, "DBIConnection")) {
      emit(list(current = "icd:alertes"))
      al <- .icd_alertes_sf(zdir, max(annees), grille)
      res$alertes <- .insert_health_alerts(con, al, zid, .ICD_ALERT_TYPE)
    }

    .icd_ecrire_meta(zdir, list(
      zone_hash = zhash, annees = annees, annee_provisoire = as.integer(format(today, "%Y")),
      calcule_le = as.character(today), coupes_retirees = res$coupes_retirees,
      buffer_interieur = buffer_interieur,
      annees_reference = annees_reference,
      n_pixels_zone = res$n_pixels_zone, n_pixels_icd = res$n_pixels_icd,
      n_pixels_sans_icd = res$n_pixels_sans_icd,
      par_essence = as.list(res$par_essence),
      mois_utilisables_a_date = mois_date,
      poids = pw[, c("essence", .ICD_INDICES)],
      somme_saisie = as.list(attr(pw, "somme_saisie")),
      renormalise = attr(pw, "renormalise"),
      source_s2 = .s2_meta_source("icd", source_effective)))
    res$status <- "success"
    emit(list(current = "icd:complete", zone_id = zid,
              annees = annees, n_pixels_icd = res$n_pixels_icd,
              n_pixels_sans_icd = res$n_pixels_sans_icd))
  }, nemeton_s2_theia_panne = function(e) {
    stop(e)   # remonte : la serie entiere sera refaite sur Sen2Cor
  }, nemeton_cancelled = function(cnd) {
    res$status <<- "cancelled"
    res$phase  <<- cnd$phase
    res$message <<- conditionMessage(cnd)
    emit(list(current = "icd:cancelled", phase = cnd$phase))
  }, error = function(e) {
    res$status <<- "error"
    res$message <<- conditionMessage(e)
    emit(list(current = "icd:error", error_message = conditionMessage(e)))
  })
  res
}

# Classe / niveau d'une annee a partir de la matrice ICD cellules x mois
# (colonnes = .ICD_MOIS_SAISON). `mois_ok` : mois lisibles ("a date") ou NULL.
.icd_annuel <- function(M, ess_v, classe_prec, mois_ok = NULL) {
  n <- nrow(M)
  classe <- rep(NA_real_, n); icd_min <- rep(NA_real_, n)
  mois_alerte <- rep(NA_integer_, n); nv <- rep(NA_integer_, n)
  for (k in seq_along(.ICD_ESSENCES)) {
    e <- .ICD_ESSENCES[k]
    ms <- .ICD_MOIS[[e]]
    if (!is.null(mois_ok)) ms <- intersect(ms, mois_ok)
    sel <- which(ess_v == k)
    if (!length(sel) || !length(ms)) next
    cols <- match(ms, .ICD_MOIS_SAISON)
    a <- .icd_classe_annuelle(M[sel, cols, drop = FALSE], ms)
    classe[sel] <- a$classe; icd_min[sel] <- a$icd_min
    mois_alerte[sel] <- a$mois_alerte; nv[sel] <- a$n_mois_valides
  }
  niveau <- .icd_niveaux(classe, icd_min,
                         if (is.null(classe_prec)) rep(NA_real_, n) else classe_prec)
  list(classe = classe, niveau = niveau, icd_min = icd_min,
       mois_alerte = mois_alerte, n_mois_valides = nv)
}

# Alertes d'une annee en centroides (classes alerte / alerte forte / alerte
# repetee), via .cluster_to_centroids() ; date = 1er jour du mois d'alerte.
.icd_alertes_sf <- function(zdir, annee, grille) {
  f <- file.path(zdir, "annuel", sprintf("%04d.tif", annee))
  if (!file.exists(f)) return(NULL)
  r <- terra::rast(f)
  niv <- r[["niveau"]]
  mo <- terra::values(r[["mois_alerte"]], mat = FALSE)
  dv <- rep(NA_real_, length(mo))
  dv[!is.na(mo)] <- as.numeric(as.Date(sprintf("%04d-%02d-01", annee,
                                              as.integer(mo[!is.na(mo)]))))
  date <- terra::setValues(r[["mois_alerte"]], dv)
  clusters <- list()
  for (cl in list(c("alerte", 2), c("alerte_forte", 3), c("alerte_repetee", 4))) {
    msk <- terra::ifel(niv == as.numeric(cl[2]), 1, NA)
    if (.raster_is_empty(msk)) next
    clusters[[cl[1]]] <- terra::patches(msk, directions = 8, zeroAsNA = TRUE)
  }
  .cluster_to_centroids(clusters, stress_index_raster = r[["icd_min"]],
                        first_dieback_date_raster = date)
}

.icd_ecrire_meta <- function(zdir, meta) {
  writeLines(jsonlite::toJSON(meta, auto_unbox = TRUE, digits = NA, null = "null"),
             file.path(zdir, "meta.json"))
}

.icd_lire_meta <- function(zdir) {
  f <- file.path(zdir, "meta.json")
  if (!file.exists(f)) return(NULL)
  tryCatch(jsonlite::read_json(f, simplifyVector = TRUE), error = function(e) NULL)
}
