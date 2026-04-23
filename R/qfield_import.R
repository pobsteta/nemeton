#' QField Project Import and Aggregation
#'
#' @description
#' Read a GeoPackage produced by a QField field session back into R,
#' validate its contents against the placette/arbre schema, and
#' compute per-plot aggregates that can be consumed by the core
#' indicators (P1 volume, P2 site index, B2 structure, etc.).
#'
#' Companion of \code{\link{create_qfield_project}} — the same schemas
#' (\code{\link{get_placette_schema}}, \code{\link{get_arbre_schema}})
#' define both the outbound form and the inbound validation rules.
#'
#' @name qfield_import
NULL


# ---- Import ----------------------------------------------------------

#' Read placettes + arbres layers from a QField-returned GPKG
#'
#' @param path Character. Path to the GeoPackage.
#'
#' @return A list with \code{placettes} (an sf POINT) and \code{arbres}
#'   (an sf POINT; an empty data.frame if the layer is absent).
#'
#' @export
import_qfield_gpkg <- function(path) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}")
  }

  layers <- sf::st_layers(path)$name
  if (!"placettes" %in% layers) {
    cli::cli_abort("GPKG {.path {path}} has no {.val placettes} layer.")
  }

  placettes <- sf::st_read(path, layer = "placettes", quiet = TRUE)
  if (!"plot_id" %in% names(placettes)) {
    cli::cli_abort("{.val placettes} layer must contain a {.val plot_id} column.")
  }

  arbres <- if ("arbres" %in% layers) {
    sf::st_read(path, layer = "arbres", quiet = TRUE)
  } else {
    NULL
  }

  list(placettes = placettes, arbres = arbres)
}


# ---- Validation ------------------------------------------------------

.mk_issue <- function(plot_id = NA_character_, tree_id = NA_character_,
                      field = NA_character_, issue = NA_character_,
                      severity = "error") {
  data.frame(
    plot_id  = plot_id,
    tree_id  = tree_id,
    field    = field,
    issue    = issue,
    severity = severity,
    stringsAsFactors = FALSE
  )
}

.empty_issues <- function() .mk_issue()[0, , drop = FALSE]


#' Validate field data against placette + arbre schemas
#'
#' Checks referential integrity (tree \code{plot_id} exists in
#' placettes), required fields (NOT NULL), physical ranges (DBH in
#' [0, 300], height in [0, 80]), species in the controlled domain, and
#' tree-id uniqueness within a plot.
#'
#' @param placettes sf POINT data-frame of placettes.
#' @param arbres sf POINT (or NULL) data-frame of tree records.
#' @param region Character. Species region used to populate the
#'   \code{espece} domain. Default \code{"BFC"}.
#' @param lang Character. Language for species labels. Default
#'   \code{"fr"}.
#'
#' @return A list with:
#'   \itemize{
#'     \item \code{ok}: logical, \code{TRUE} if no errors were found.
#'     \item \code{errors}: data.frame of error-level issues.
#'     \item \code{warnings}: data.frame of warning-level issues.
#'   }
#'
#' @export
validate_field_data <- function(placettes, arbres = NULL,
                                region = "BFC", lang = "fr") {
  issues <- list()

  # --- Placettes --------------------------------------------------------
  if (!inherits(placettes, "sf")) {
    return(list(ok = FALSE,
                errors = .mk_issue(issue = "`placettes` must be an sf object."),
                warnings = .empty_issues()))
  }
  if (!"plot_id" %in% names(placettes)) {
    return(list(ok = FALSE,
                errors = .mk_issue(issue = "`placettes` is missing `plot_id`."),
                warnings = .empty_issues()))
  }

  # Missing plot_id
  miss <- which(is.na(placettes$plot_id) | !nzchar(as.character(placettes$plot_id)))
  if (length(miss)) {
    issues <- c(issues, list(.mk_issue(issue = "plot_id is missing.",
                                       field = "plot_id",
                                       plot_id = as.character(seq_along(miss)))))
  }

  # Duplicate plot_id
  dup <- placettes$plot_id[duplicated(placettes$plot_id)]
  if (length(dup)) {
    issues <- c(issues, list(.mk_issue(plot_id = as.character(unique(dup)),
                                       field = "plot_id",
                                       issue = "Duplicate plot_id in placettes.")))
  }

  # --- Arbres -----------------------------------------------------------
  if (!is.null(arbres) && (inherits(arbres, "data.frame")) && nrow(arbres) > 0) {
    req <- c("plot_id", "tree_id", "dbh_cm")
    miss_cols <- setdiff(req, names(arbres))
    if (length(miss_cols)) {
      issues <- c(issues, list(.mk_issue(
        field = paste(miss_cols, collapse = ", "),
        issue = sprintf("`arbres` is missing column(s): %s.",
                        paste(miss_cols, collapse = ", "))
      )))
    } else {
      # Orphan plot_id (tree refers to a plot that doesn't exist)
      orphans <- !arbres$plot_id %in% placettes$plot_id
      if (any(orphans)) {
        issues <- c(issues, list(.mk_issue(
          plot_id = as.character(arbres$plot_id[orphans]),
          tree_id = as.character(arbres$tree_id[orphans]),
          field = "plot_id",
          issue = "Orphan plot_id (no matching placette)."
        )))
      }

      # Duplicate (plot_id, tree_id)
      key <- paste(arbres$plot_id, arbres$tree_id, sep = "/")
      dup <- which(duplicated(key) & !orphans)
      if (length(dup)) {
        issues <- c(issues, list(.mk_issue(
          plot_id = as.character(arbres$plot_id[dup]),
          tree_id = as.character(arbres$tree_id[dup]),
          field = "tree_id",
          issue = "Duplicate tree_id within the same plot."
        )))
      }

      # DBH checks
      bad_dbh <- which(is.na(arbres$dbh_cm) | arbres$dbh_cm <= 0 | arbres$dbh_cm > 300)
      if (length(bad_dbh)) {
        issues <- c(issues, list(.mk_issue(
          plot_id = as.character(arbres$plot_id[bad_dbh]),
          tree_id = as.character(arbres$tree_id[bad_dbh]),
          field = "dbh_cm",
          issue = "DBH out of range (expected > 0 and <= 300 cm)."
        )))
      }

      # Height checks (warning level; height is not required)
      if ("h_m" %in% names(arbres)) {
        bad_h <- which(!is.na(arbres$h_m) & (arbres$h_m < 0 | arbres$h_m > 80))
        if (length(bad_h)) {
          issues <- c(issues, list(.mk_issue(
            plot_id = as.character(arbres$plot_id[bad_h]),
            tree_id = as.character(arbres$tree_id[bad_h]),
            field = "h_m",
            issue = "Height out of range (expected in [0, 80] m).",
            severity = "warning"
          )))
        }
      }

      # Species domain
      if ("espece" %in% names(arbres)) {
        domain <- tryCatch(list_species_classes(region = region, lang = lang)$code,
                           error = function(e) NULL)
        if (!is.null(domain)) {
          bad_sp <- which(!is.na(arbres$espece) &
                          nzchar(as.character(arbres$espece)) &
                          !arbres$espece %in% domain)
          if (length(bad_sp)) {
            issues <- c(issues, list(.mk_issue(
              plot_id = as.character(arbres$plot_id[bad_sp]),
              tree_id = as.character(arbres$tree_id[bad_sp]),
              field = "espece",
              issue = sprintf("Species not in domain (region %s).", region),
              severity = "warning"
            )))
          }
        }
      }
    }
  }

  all_issues <- if (length(issues)) do.call(rbind, issues) else .empty_issues()
  errors   <- all_issues[all_issues$severity == "error",   , drop = FALSE]
  warnings <- all_issues[all_issues$severity == "warning", , drop = FALSE]

  list(ok = nrow(errors) == 0, errors = errors, warnings = warnings)
}


# ---- Aggregation -----------------------------------------------------

#' Compute per-plot aggregates from field data
#'
#' For each placette, summarises the trees it contains into a set of
#' dendrometric aggregates that downstream indicators can consume:
#' \itemize{
#'   \item \code{n_trees}: total tree records.
#'   \item \code{n_trees_alive}: trees whose \code{statut == "vivant"}.
#'   \item \code{dbh_mean_cm}: arithmetic mean DBH.
#'   \item \code{dg_cm}: quadratic mean diameter (sqrt(mean(DBH^2))).
#'   \item \code{h_mean_m}: mean height of measured trees.
#'   \item \code{h_dom_m}: top height as the mean of the 5 tallest (or
#'     fewer if fewer trees have a measured height).
#'   \item \code{g_ha}: basal area (m^2/ha) assuming a circular plot of
#'     \code{plot_radius} metres.
#'   \item \code{cv_dbh}, \code{cv_h}: coefficients of variation (sd /
#'     mean) used by the B2 structural diversity component.
#' }
#'
#' Placettes with no trees receive NA for every aggregate and
#' \code{n_trees = 0L}.
#'
#' @param placettes sf POINT of placettes (with a \code{plot_id}
#'   column).
#' @param arbres sf POINT or data.frame of trees (plot_id, tree_id,
#'   dbh_cm, h_m, statut).
#' @param plot_radius Numeric. Plot radius (m) used to compute basal
#'   area per hectare. Default 15.
#'
#' @return An sf object identical to \code{placettes} plus the
#'   aggregate columns (prefixed \code{field_} to make them easy to
#'   keep separate from remote-sensing metrics downstream).
#'
#' @export
aggregate_plot_metrics <- function(placettes, arbres = NULL,
                                   plot_radius = 15) {
  if (!inherits(placettes, "sf")) {
    cli::cli_abort("{.arg placettes} must be an sf object.")
  }

  plot_area_ha <- (pi * plot_radius^2) / 10000

  agg_cols <- c("field_n_trees", "field_n_trees_alive",
                "field_dbh_mean_cm", "field_dg_cm",
                "field_h_mean_m", "field_h_dom_m",
                "field_g_ha", "field_cv_dbh", "field_cv_h")

  # Default: zeros / NAs
  out <- placettes
  out$field_n_trees       <- 0L
  out$field_n_trees_alive <- 0L
  for (col in setdiff(agg_cols, c("field_n_trees", "field_n_trees_alive"))) {
    out[[col]] <- NA_real_
  }

  if (is.null(arbres) || nrow(arbres) == 0) {
    return(out)
  }

  # Work on a plain data.frame to avoid sf overhead per group.
  trees <- if (inherits(arbres, "sf")) sf::st_drop_geometry(arbres) else as.data.frame(arbres)
  keep <- !is.na(trees$plot_id) & !is.na(trees$dbh_cm) & trees$dbh_cm > 0
  trees <- trees[keep, , drop = FALSE]
  if (nrow(trees) == 0) return(out)

  plot_ids <- unique(trees$plot_id)
  for (pid in plot_ids) {
    rows <- trees$plot_id == pid
    sub <- trees[rows, , drop = FALSE]

    n_trees <- nrow(sub)
    n_alive <- if ("statut" %in% names(sub)) sum(sub$statut == "vivant", na.rm = TRUE) else n_trees

    dbh <- sub$dbh_cm
    dbh_mean <- mean(dbh, na.rm = TRUE)
    dg <- sqrt(mean(dbh^2, na.rm = TRUE))
    cv_dbh <- if (length(dbh) > 1 && dbh_mean > 0) sd(dbh, na.rm = TRUE) / dbh_mean else NA_real_

    h <- if ("h_m" %in% names(sub)) sub$h_m[!is.na(sub$h_m)] else numeric(0)
    h_mean <- if (length(h)) mean(h) else NA_real_
    h_dom  <- if (length(h)) mean(sort(h, decreasing = TRUE)[seq_len(min(5L, length(h)))]) else NA_real_
    cv_h   <- if (length(h) > 1 && h_mean > 0) stats::sd(h) / h_mean else NA_real_

    # Basal area: G = sum(pi * (DBH/2)^2) in m^2 / plot_area_ha
    g_ha <- sum(pi * (dbh / 200)^2) / plot_area_ha  # DBH in cm → m via /200

    idx <- which(out$plot_id == pid)
    if (length(idx)) {
      out$field_n_trees[idx]       <- n_trees
      out$field_n_trees_alive[idx] <- n_alive
      out$field_dbh_mean_cm[idx]   <- dbh_mean
      out$field_dg_cm[idx]         <- dg
      out$field_h_mean_m[idx]      <- h_mean
      out$field_h_dom_m[idx]       <- h_dom
      out$field_g_ha[idx]          <- g_ha
      out$field_cv_dbh[idx]        <- cv_dbh
      out$field_cv_h[idx]          <- cv_h
    }
  }

  out
}


# ---- Attach to units -------------------------------------------------

#' Tag an sf object with field-data NDP attributes
#'
#' Sets the attributes \code{field_plots_count} and
#' \code{field_trees_count} that \code{\link{detect_ndp}} reads to bump
#' the NDP to 2 (with plots only) or 3 (with >= 10 trees/plot on
#' average) along the alternative QField path.
#'
#' @param data An sf / data.frame to tag.
#' @param placettes sf or data.frame of placettes.
#' @param arbres sf or data.frame of trees (may be NULL).
#'
#' @return \code{data} with the added attributes.
#'
#' @examples
#' df <- data.frame(x = 1)
#' placettes <- data.frame(plot_id = c("P1", "P2"))
#' arbres    <- data.frame(plot_id = rep(c("P1", "P2"), each = 15))
#' tagged <- tag_field_data_sources(df, placettes, arbres)
#' detect_ndp(tagged)$level  # 3
#'
#' @export
tag_field_data_sources <- function(data, placettes, arbres = NULL) {
  n_plots <- if (inherits(placettes, "data.frame")) nrow(placettes) else 0L
  n_trees <- if (!is.null(arbres) && inherits(arbres, "data.frame")) {
    nrow(arbres)
  } else {
    0L
  }
  attr(data, "field_plots_count") <- as.integer(n_plots)
  attr(data, "field_trees_count") <- as.integer(n_trees)
  data
}


#' Attach per-plot field aggregates to a units sf
#'
#' Spatial-joins a sf of forest units (polygons) with the sf of
#' aggregated placettes (points). For each unit, the aggregates are
#' averaged across the placettes it contains; units with no placettes
#' get NAs (and \code{field_n_trees = 0}).
#'
#' This gives indicators a uniform \code{field_*} set of columns to
#' read, regardless of whether field data is available or not.
#'
#' @param units sf POLYGON. Forest management units.
#' @param field_agg sf POINT. Output of
#'   \code{\link{aggregate_plot_metrics}}.
#'
#' @return \code{units} enriched with \code{field_*} columns.
#'
#' @export
attach_field_data_to_units <- function(units, field_agg) {
  if (!inherits(units, "sf")) cli::cli_abort("{.arg units} must be an sf object.")
  if (!inherits(field_agg, "sf")) cli::cli_abort("{.arg field_agg} must be an sf object.")

  units <- sf::st_transform(units, sf::st_crs(field_agg))
  field_cols <- grep("^field_", names(field_agg), value = TRUE)
  if (!length(field_cols)) {
    cli::cli_warn("{.arg field_agg} carries no {.val field_*} columns; nothing to attach.")
    return(units)
  }

  joined <- sf::st_join(units, field_agg[, field_cols], join = sf::st_intersects,
                        left = TRUE)
  # The st_join may explode rows if a unit contains several plots; aggregate back.
  id_col <- if ("ug_id" %in% names(units)) "ug_id" else names(units)[1]
  joined_df <- sf::st_drop_geometry(joined)

  agg <- lapply(field_cols, function(col) {
    tapply(joined_df[[col]], joined_df[[id_col]],
           function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE))
  })
  names(agg) <- field_cols

  out <- units
  for (col in field_cols) {
    out[[col]] <- as.numeric(agg[[col]])[match(out[[id_col]], names(agg[[col]]))]
  }
  # field_n_trees: zero (not NA) when nothing landed in the unit
  if ("field_n_trees" %in% field_cols) {
    out$field_n_trees[is.na(out$field_n_trees)] <- 0L
  }
  out
}
