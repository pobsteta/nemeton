#' N5: Distance to a low-disturbance reference (foundation-model embedding)
#'
#' Functional naturalness of each unit, read in a foundation-model embedding
#' space: how close the unit's mean embedding is to that of a reference set of
#' low-disturbance forests. N1-N3 measure an administrative naturalness
#' (remoteness, cartographic continuity); N5 looks at the forest itself, as
#' seen by the model (spec 064). Source-conditional: without an embedding,
#' N5 is `NA` with its status and the N family is unchanged.
#'
#' @param units sf polygon layer (spatial units / UGF).
#' @param embedding SpatRaster, one band per embedding dimension (e.g. the 64
#'   bands of AlphaEarth Foundations from `alphaearthnemeton::aef_fetch()`),
#'   or a list of such rasters named by year. `NULL`: taken from
#'   `layers$aef_embedding`.
#' @param reference Optional sf polygons of the user's own reference
#'   (strict reserves, senescence islands, reference plots). `NULL`: default
#'   reference, see Details.
#' @param layers nemeton_layers object, used to resolve `embedding`
#'   (`aef_embedding`) and `foret_ancienne` when not given.
#' @param foret_ancienne Optional ancient-forest layer
#'   ([build_foret_ancienne_mask()]), used by the default reference.
#' @param annee Year to use when `embedding` is a list named by year.
#'   `NULL`: the most recent.
#' @param min_reference Integer. Minimum number of reference units (or
#'   polygons) with an embedding; below it, N5 is `NA` with status
#'   `skipped_reference_too_small`. Default 15.
#' @param n1_min Numeric. N1 threshold of the default reference. Default 80.
#' @param couverture_min Numeric in `[0, 1]`. Share of a unit's area that the
#'   top ancient-forest tier must cover for the unit to enter the default
#'   reference. Default 0.5.
#' @param score `"reference"` (default) or `"projet"`, see Details.
#' @param min_pixels Passed to [embedding_summary()].
#' @param source Label stored in `n5_source` (`"aef"`; `"forpt"` and
#'   `"fused"` are reserved for spec 064 chantier C). Default: the
#'   `embedding_source` attribute of the raster, else `"aef"`.
#'
#' @return `units` with
#'   \describe{
#'     \item{N5}{score 0-100, 100 = indistinguishable from the reference.}
#'     \item{n5_status}{`calculated`, `skipped_no_embedding`,
#'       `skipped_no_reference`, `skipped_reference_too_small` or
#'       `skipped_no_coverage` (fewer than `min_pixels` valid pixels in the
#'       unit).}
#'     \item{n5_source}{embedding source.}
#'     \item{n5_reference}{`"defaut"` or `"utilisateur"`.}
#'     \item{n5_annee}{year of the embedding used (`NA` if unknown).}
#'     \item{n5_distance}{raw distance (Mahalanobis, Ledoit-Wolf).}
#'   }
#'
#' @details
#' **Default reference**: units covered (share >= `couverture_min`) by the
#' top tier of `foret_ancienne` (its `anciennete` column when present, else
#' every polygon) **and** with `N1 >= n1_min`. It therefore needs the `N1`
#' column, which is why N5 is computed after N1 by [nemeton_compute()].
#'
#' **Distance**: [distance_reference()] on the mean embeddings of
#' [embedding_summary()].
#'
#' **Score** (spec 064, D-4):
#' \itemize{
#'   \item `"reference"` (default): `N5 = 100 * (1 - F(d))`, where `F` is the
#'     empirical distribution of the reference's own leave-one-out distances.
#'     A unit as close as a typical reference unit scores about 50; a unit
#'     farther than every reference unit scores 0. The score depends on the
#'     reference only, not on the other units being scored. With the default
#'     reference, a unit that belongs to it is scored on its leave-one-out
#'     distance.
#'   \item `"projet"`: percentile rank of the distance among the project's
#'     units (100 = closest). Spreads every project over 0-100 whatever its
#'     content: values are not comparable between projects.
#' }
#'
#' **Pitfalls** (fiche N5): the reference is not a random sample (slope,
#' access, poor soils); the default reference is chosen by N1 and N2, so N5
#' correlates with them by construction; a distance is not a cause; with 15
#' reference units in 64 dimensions the shrinkage dominates and the distance
#' is close to Euclidean; AlphaEarth is annual.
#'
#' @section Lifecycle:
#' Experimental (spec 064): may change in any release.
#'
#' @seealso [embedding_summary()], [distance_reference()],
#'   [indicateur_n1_distance()], [build_foret_ancienne_mask()]
#' @export
indicateur_n5_distance_reference <- function(units,
                                             embedding = NULL,
                                             reference = NULL,
                                             layers = NULL,
                                             foret_ancienne = NULL,
                                             annee = NULL,
                                             min_reference = 15L,
                                             n1_min = 80,
                                             couverture_min = 0.5,
                                             score = c("reference", "projet"),
                                             min_pixels = 10,
                                             source = NULL) {
  if (!inherits(units, "sf")) cli::cli_abort("units must be an sf object")
  score <- match.arg(score)
  n <- nrow(units)

  sortie <- function(valeur, statut, distance = rep(NA_real_, n),
                     source_lbl = NA_character_, ref_lbl = NA_character_,
                     an = NA_integer_) {
    units$N5 <- as.numeric(valeur)
    units$n5_status <- rep_len(as.character(statut), n)
    units$n5_source <- rep_len(source_lbl, n)
    units$n5_reference <- rep_len(ref_lbl, n)
    units$n5_annee <- rep_len(as.integer(an), n)
    units$n5_distance <- as.numeric(distance)
    units
  }

  # 1. L'embedding : argument, liste par annee, ou couche du projet
  if (is.null(embedding) && inherits(layers, "nemeton_layers")) {
    embedding <- resolve_raster_layer(layers, "aef_embedding")
  }
  an <- NA_integer_
  if (is.list(embedding) && !inherits(embedding, "SpatRaster")) {
    if (!length(embedding)) {
      embedding <- NULL
    } else {
      annees <- names(embedding)
      if (is.null(annees) || any(!nzchar(annees))) {
        cli::cli_abort("A list {.arg embedding} must be named by year.")
      }
      choix <- if (is.null(annee)) annees[which.max(as.integer(annees))]
               else as.character(annee)
      if (!choix %in% annees) {
        cli::cli_abort("Year {.val {choix}} not in {.arg embedding} ({.val {annees}}).")
      }
      embedding <- embedding[[choix]]
      an <- as.integer(choix)
    }
  }
  if (is.null(embedding)) {
    cli::cli_alert_info("N5: no embedding, returning NA (no measurement made)")
    return(sortie(NA_real_, "skipped_no_embedding"))
  }
  if (!inherits(embedding, "SpatRaster")) {
    cli::cli_abort("{.arg embedding} must be a SpatRaster or a list of SpatRaster.")
  }
  if (is.na(an) && !is.null(attr(embedding, "annee"))) {
    an <- as.integer(attr(embedding, "annee"))
  }
  source_lbl <- source %||% attr(embedding, "embedding_source") %||% "aef"

  resume <- embedding_summary(units, embedding, stats = "mean",
                              min_pixels = min_pixels)
  x <- resume$mean
  couvert <- apply(is.finite(x), 1L, all)

  # 2. La reference
  dans_ref <- rep(FALSE, n)
  if (!is.null(reference)) {
    if (!inherits(reference, c("sf", "sfc"))) {
      cli::cli_abort("{.arg reference} must be an sf/sfc polygon layer.")
    }
    if (inherits(reference, "sfc")) reference <- sf::st_sf(geometry = reference)
    ref_lbl <- "utilisateur"
    ref_x <- embedding_summary(reference, embedding, stats = "mean",
                               min_pixels = min_pixels)$mean
  } else {
    ref_lbl <- "defaut"
    if (is.null(foret_ancienne) && inherits(layers, "nemeton_layers")) {
      foret_ancienne <- resolve_vector_layer(layers, "foret_ancienne")
    }
    if (is.null(foret_ancienne) || !inherits(foret_ancienne, "sf") ||
        !nrow(foret_ancienne) || !"N1" %in% names(units)) {
      cli::cli_alert_info(
        "N5: no reference (needs {.arg reference}, or {.field foret_ancienne} and {.field N1}), returning NA"
      )
      return(sortie(NA_real_, "skipped_no_reference", source_lbl = source_lbl,
                    ref_lbl = ref_lbl, an = an))
    }
    dans_ref <- .n5_reference_defaut(units, foret_ancienne, n1_min,
                                     couverture_min)
    ref_x <- x[dans_ref, , drop = FALSE]
  }
  ref_ok <- apply(is.finite(ref_x), 1L, all)
  if (sum(ref_ok) < max(3L, min_reference)) {
    cli::cli_alert_info(
      "N5: reference too small ({sum(ref_ok)} < {min_reference}), returning NA"
    )
    return(sortie(NA_real_, "skipped_reference_too_small", source_lbl = source_lbl,
                  ref_lbl = ref_lbl, an = an))
  }

  # 3. Distances ; une unite de la reference est notee sur sa distance
  # leave-one-out (sinon elle se compare a un centroide qui la contient).
  dr <- distance_reference(x, ref_x)
  d <- dr$distance
  if (any(dans_ref)) {
    idx_ref <- which(dans_ref)[ref_ok]
    d[idx_ref] <- dr$distance_loo
  }

  # 4. Score
  valeur <- rep(NA_real_, n)
  if (score == "reference") {
    f <- stats::ecdf(dr$distance_loo)
    valeur[couvert] <- 100 * (1 - f(d[couvert]))
  } else {
    k <- sum(couvert)
    if (k == 1L) {
      valeur[couvert] <- 100
    } else if (k > 1L) {
      rg <- rank(d[couvert], ties.method = "average")
      valeur[couvert] <- 100 * (k - rg) / (k - 1)
    }
  }
  statut <- ifelse(couvert, "calculated", "skipped_no_coverage")

  if (any(!is.na(valeur))) {
    cli::cli_alert_success(
      "Calculated N5: distance to reference ({ref_lbl}, {sum(ref_ok)} units)"
    )
  }
  sortie(valeur, statut, distance = d, source_lbl = source_lbl,
         ref_lbl = ref_lbl, an = an)
}

# Reference par defaut : part de l'unite couverte par le palier maximal de
# `foret_ancienne` >= couverture_min, et N1 >= n1_min.
.n5_reference_defaut <- function(units, foret_ancienne, n1_min, couverture_min) {
  fa <- sf::st_make_valid(sf::st_transform(foret_ancienne, sf::st_crs(units)))
  if ("anciennete" %in% names(fa) && any(is.finite(fa$anciennete))) {
    fa <- fa[!is.na(fa$anciennete) &
               fa$anciennete == max(fa$anciennete, na.rm = TRUE), ]
  }
  palier <- sf::st_union(sf::st_geometry(fa))
  aire <- as.numeric(sf::st_area(units))
  geom <- sf::st_make_valid(sf::st_geometry(units))
  touche <- lengths(sf::st_intersects(geom, palier)) > 0
  part <- rep(0, nrow(units))
  for (i in which(touche)) {
    inter <- suppressWarnings(sf::st_intersection(geom[i], palier))
    part[i] <- sum(as.numeric(sf::st_area(inter)))
  }
  part <- ifelse(aire > 0, part / aire, 0)
  n1 <- units$N1
  part >= couverture_min & !is.na(n1) & n1 >= n1_min
}
