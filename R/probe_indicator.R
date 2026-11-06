#' What foundation models see: probe indicators with an embedding
#'
#' For each indicator already computed on the project's units, fits a ridge
#' regression from the unit's mean embedding to the indicator and reads its
#' R² in **spatial block cross-validation**. A high R² means the embedding
#' carries the indicator's information; a low one is a documented blind spot
#' (spec 066). The table is a diagnostic: it does not replace any indicator.
#'
#' @param units sf polygons of the project's units, with the indicator
#'   columns already computed (short codes `C1`, `B2`, ... as in
#'   [list_indicators()]).
#' @param embedding SpatRaster, one band per embedding dimension (AlphaEarth,
#'   MAESTRO or ForPT), or a list named by year (latest used).
#' @param indicateurs Short codes to probe. `NULL`: every indicator of
#'   [list_indicators()] present as a column of `units`.
#' @param normalise Logical. Probe the 0-100 normalised value
#'   ([normalize_indicator()], with the indicator's status column) rather
#'   than the raw one, so that RMSE compare across indicators. Default `TRUE`.
#' @param taille_bloc_m Side of the cross-validation blocks, in metres.
#'   Default 2000 (units of a few hectares).
#' @param n_plis Number of folds. Default 5.
#' @param min_unites Minimum number of usable units for a probe. Default 50:
#'   below that, the cross-validated R² is too noisy to be read.
#' @param source Label of the embedding source in the output. Default: the
#'   raster's `embedding_source` attribute, else `"aef"`.
#' @param graine Random seed of the fold assignment.
#'
#' @return A data frame, one row per indicator, sorted by decreasing R²:
#'   \describe{
#'     \item{code, famille}{indicator and family codes.}
#'     \item{n}{units used.}
#'     \item{r2, rmse}{cross-validated R² and RMSE (`NA` without probe).}
#'     \item{lecture}{`"voit"` (R² >= 0.5), `"partiel"` (0.2 to 0.5),
#'       `"angle_mort"` (< 0.2): conventions, not test thresholds.}
#'     \item{statut}{`"ok"`, `"trop_peu_unites"`, `"variance_nulle"` or
#'       `"indicateur_absent"`.}
#'     \item{source_commune}{`TRUE` for indicators computed (depending on
#'       their source) from Sentinel-2, like AlphaEarth: a high R² may then
#'       come from the shared input rather than from what the model
#'       understands of the forest.}
#'     \item{source_embedding}{embedding source.}
#'   }
#'
#' @details
#' **Pitfalls.** (1) Shared input is not vision: see `source_commune`.
#' (2) A probe is project-specific: an indicator with no variance in the
#' project gets no probe, without the model being blind. (3) A probe is not
#' an estimator: an R² of 0.6 does not allow replacing the indicator by its
#' prediction; use [embedding_regress()] with a field-measured target for
#' that. (4) Below `min_unites` units, no probe.
#'
#' @section Lifecycle:
#' Experimental (spec 066): may change in any release.
#'
#' @seealso [embedding_summary()], [embedding_regress()]
#' @export
probe_indicator <- function(units, embedding, indicateurs = NULL,
                            normalise = TRUE, taille_bloc_m = 2000,
                            n_plis = 5L, min_unites = 50L, source = NULL,
                            graine = 1L) {
  if (!inherits(units, "sf")) cli::cli_abort("{.arg units} must be an sf object.")
  embedding <- .embedding_resolu(embedding, NULL)
  if (is.null(embedding)) cli::cli_abort("{.arg embedding} is required.")
  source <- source %||% attr(embedding, "embedding_source") %||% "aef"

  lab <- indicator_labels(lang = "en")
  if (is.null(indicateurs)) indicateurs <- intersect(lab$code, names(units))
  if (!length(indicateurs)) {
    cli::cli_abort("No indicator column found in {.arg units}.")
  }

  x <- embedding_summary(units, embedding, stats = "mean")$mean
  xy <- sf::st_coordinates(suppressWarnings(sf::st_centroid(sf::st_geometry(units))))
  emb_ok <- stats::complete.cases(x)

  lignes <- lapply(indicateurs, function(code) {
    ligne <- data.frame(
      code = code,
      famille = lab$family[match(code, lab$code)],
      n = 0L, r2 = NA_real_, rmse = NA_real_, lecture = NA_character_,
      statut = "ok", source_commune = code %in% .INDICATEURS_SOURCE_S2,
      source_embedding = source, stringsAsFactors = FALSE
    )
    if (!code %in% names(units)) {
      ligne$statut <- "indicateur_absent"
      return(ligne)
    }
    y <- as.numeric(units[[code]])
    if (isTRUE(normalise)) {
      st_col <- paste0(tolower(code), "_status")
      st <- if (st_col %in% names(units)) as.character(units[[st_col]]) else NULL
      y <- as.numeric(normalize_indicator(code, y, statut = st))
    }
    ok <- emb_ok & is.finite(y)
    ligne$n <- sum(ok)
    if (sum(ok) < min_unites) {
      ligne$statut <- "trop_peu_unites"
      return(ligne)
    }
    if (stats::var(y[ok]) <= .Machine$double.eps) {
      ligne$statut <- "variance_nulle"
      return(ligne)
    }
    cv <- .cv_blocs_spatiaux(
      x[ok, , drop = FALSE], y[ok], xy[ok, , drop = FALSE],
      ajuste = function(xa, ya) .ridge_ajuste(xa, ya),
      predit = .ridge_predit,
      taille_bloc_m = taille_bloc_m, n_plis = n_plis, graine = graine
    )
    ligne$r2 <- cv$r2
    ligne$rmse <- cv$rmse
    ligne$lecture <- .lecture_sonde(cv$r2)
    ligne
  })
  out <- do.call(rbind, lignes)
  out <- out[order(-ifelse(is.na(out$r2), -Inf, out$r2)), , drop = FALSE]
  rownames(out) <- NULL
  n_ok <- sum(out$statut == "ok")
  cli::cli_alert_success(
    "probe_indicator ({source}): {n_ok} indicator{?s} probed, {sum(out$lecture %in% 'voit')} seen (R2 >= 0.5)"
  )
  out
}

# Seuils de lecture (spec 066, D-1) : conventions, affichees comme telles.
.lecture_sonde <- function(r2) {
  ifelse(is.na(r2), NA_character_,
         ifelse(r2 >= 0.5, "voit", ifelse(r2 >= 0.2, "partiel", "angle_mort")))
}

# Indicateurs calcules, selon leur source, a partir de Sentinel-2 comme
# AlphaEarth (spec 066, piege 1) : C2 (NDVI), B4 et L3 (diversite spectrale),
# A1 (couvert, via OSO ou NDVI), R5 (FORDEAD / RECONFORT), T2 (FORMS-T).
.INDICATEURS_SOURCE_S2 <- c("C2", "B4", "L3", "A1", "R5", "T2")
