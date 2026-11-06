#' Sensitivity of B5 to the density of the LiDAR point cloud
#'
#' Thins the point cloud down to lower densities and measures how much B5
#' moves for each unit: if B5 hardly changes when half the returns are
#' removed, a denser acquisition (drone LiDAR, NDP 2) is unlikely to change
#' the diagnosis; if it moves a lot, the current density is a limit
#' (spec 067, dimensioning). The cloud is read once; each thinning only
#' redraws which returns are kept.
#'
#' @param units sf polygon layer (spatial units / UGF).
#' @param nuage Point cloud, as in [indicateur_b5_stratification()]: a
#'   table `X, Y, Z` (optionally `Classification`, `gpstime`), a `LAS` object,
#'   or LAZ files (read with \pkg{lidR}, clipped to the units: keep the study
#'   area small, the returns are held in memory).
#' @param densites Numeric. Target densities, in returns per square metre
#'   over the units. Densities at or above the current one are not
#'   simulated. Default `c(10, 5, 2)` (spec 067).
#' @param indicateurs Character. Indicators to test. Only `"B5"` for now;
#'   N4 and the structural N5 will join when they exist (spec 067).
#' @param repetitions Integer. Random thinnings per density. Default 5.
#' @param tolerance Numeric. Change of B5 (points on 0-100) below which a
#'   unit is called stable. Default 5.
#' @param graine Integer. Random seed. Default 1.
#' @param strates,profil,normaliser,hauteur_sol,hauteur_max,classes,min_points,resolution
#'   Passed to the B5 computation, see [indicateur_b5_stratification()].
#'
#' @return A list of class `"sensibilite_densite"`:
#'   \describe{
#'     \item{reference}{data.frame `unite`, `B5`, `b5_status` at the current
#'       density.}
#'     \item{detail}{data.frame `densite`, `repetition`, `unite`, `B5`,
#'       `b5_status`, `ecart` (absolute change from the reference, `NA` if
#'       either value is `NA`).}
#'     \item{resume}{one row per simulated density: `densite`,
#'       `proportion` (share of returns or pulses kept), `n_unites` (units
#'       with a reference value), `ecart_median`, `ecart_p90` (over units and
#'       repetitions), `part_stable` (share of unit-repetitions within
#'       `tolerance`), `part_perdue` (share that fell below `min_points`),
#'       `stable` (`ecart_p90 <= tolerance`).}
#'     \item{densite_actuelle}{returns per square metre over the units.}
#'     \item{eclaircie}{`"impulsions"` when the cloud carries `gpstime`
#'       (all returns of a kept pulse are kept, as with a lower pulse
#'       density), else `"retours"` (returns drawn one by one, which keeps
#'       too many lower returns under a canopy).}
#'     \item{conclusion}{`"densite_suffisante"` if B5 is stable at the
#'       highest simulated density below the current one,
#'       `"densite_limite"` if not, `"non_simule"` if no density was below
#'       the current one.}
#'   }
#'
#' @details The conclusion reads a convergence: thinning cannot show what a
#' denser cloud would see, only whether the score has stopped moving at the
#' current density. A stable B5 at half the density supports keeping the
#' LiDAR HD; an unstable one says a drone campaign would be worth testing,
#' not that it would change the score.
#'
#' @section Lifecycle:
#' Experimental (spec 067): may change in any release.
#'
#' @seealso [indicateur_b5_stratification()]
#' @export
#' @examples
#' units <- sf::st_sf(id = 1, geometry = sf::st_sfc(
#'   sf::st_polygon(list(rbind(c(0, 0), c(30, 0), c(30, 30), c(0, 30), c(0, 0)))),
#'   crs = 2154))
#' set.seed(1)
#' nuage <- data.frame(X = runif(9000, 0, 30), Y = runif(9000, 0, 30),
#'                     Z = c(runif(6000, 15, 25), runif(3000, 0, 8)))
#' s <- simulate_density_sensitivity(units, nuage, densites = c(5, 2, 0.5))
#' s$resume
simulate_density_sensitivity <- function(units,
                                         nuage,
                                         densites = c(10, 5, 2),
                                         indicateurs = "B5",
                                         repetitions = 5L,
                                         tolerance = 5,
                                         graine = 1L,
                                         strates = c(0, 2, 5, 10, 20),
                                         profil = c("points", "densite_foliaire"),
                                         normaliser = FALSE,
                                         hauteur_sol = 0.5,
                                         hauteur_max = 60,
                                         classes = c(1:5, 9),
                                         min_points = 100L,
                                         resolution = 1) {
  if (!inherits(units, "sf")) cli::cli_abort("units must be an sf object")
  profil <- match.arg(profil)
  inconnus <- setdiff(indicateurs, "B5")
  if (length(inconnus)) {
    cli::cli_abort(c(
      "Only {.val B5} can be simulated for now, not {.val {inconnus}}.",
      i = "N4 and the structural N5 will join when they exist (spec 067)."
    ))
  }
  if (missing(nuage) || is.null(nuage)) cli::cli_abort("{.arg nuage} is required.")
  if (!is.numeric(densites) || !length(densites) || any(!is.finite(densites) | densites <= 0)) {
    cli::cli_abort("{.arg densites} must be positive numbers.")
  }
  repetitions <- as.integer(repetitions)
  if (repetitions < 1L) cli::cli_abort("{.arg repetitions} must be at least 1.")
  if (!is.numeric(strates) || length(strates) < 2L || strates[1] != 0 ||
      is.unsorted(strates, strictly = TRUE)) {
    cli::cli_abort("{.arg strates} must be increasing lower bounds starting at 0.")
  }

  n <- nrow(units)
  K <- length(strates)
  bornes <- c(hauteur_sol, strates[-1])
  grille <- .b5_grille(units, resolution)

  # 1. Lecture unique : code (UGF, classe) et impulsion de chaque retour
  coder <- function(xyz) .b5_codes(xyz, grille, bornes, hauteur_max, classes)
  joindre <- function(a, b) {
    list(code = c(a$code, b$code),
         impulsion = if (!is.null(a$impulsion) && !is.null(b$impulsion)) c(a$impulsion, b$impulsion))
  }
  pts <- .b5_lire_et_compter(nuage, units, coder, normaliser, hauteur_max,
                             combiner = joindre)
  code <- pts$code
  impulsion <- pts$impulsion
  aire <- sum(as.numeric(sf::st_area(units)))
  actuelle <- if (aire > 0) length(code) / aire else NA_real_
  eclaircie <- if (is.null(impulsion)) "retours" else "impulsions"

  # 2. Reference a la densite actuelle
  ref <- .b5_scores(.b5_tabuler(code, n, K), profil, min_points)
  reference <- data.frame(unite = seq_len(n), B5 = ref$valeur, b5_status = ref$statut)

  # 3. Eclaircies
  densites <- sort(unique(densites), decreasing = TRUE)
  simulees <- densites[is.finite(actuelle) & densites < actuelle]
  ecartees <- setdiff(densites, simulees)
  if (length(ecartees)) {
    cli::cli_alert_info(
      "Density {.val {ecartees}} not below the current {round(actuelle, 2)} returns/m2: not simulated.")
  }
  if (!is.null(impulsion)) {
    cles <- unique(impulsion)
    rang <- match(impulsion, cles)
  }
  detail <- list()
  resume <- list()
  ancienne_graine <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (!is.null(ancienne_graine)) assign(".Random.seed", ancienne_graine, envir = globalenv()),
          add = TRUE)
  set.seed(graine)
  for (d in simulees) {
    p <- d / actuelle
    lignes <- list()
    for (r in seq_len(repetitions)) {
      garde <- if (is.null(impulsion)) stats::runif(length(code)) < p
               else (stats::runif(length(cles)) < p)[rang]
      sc <- .b5_scores(.b5_tabuler(code[garde], n, K), profil, min_points)
      lignes[[r]] <- data.frame(densite = d, repetition = r, unite = seq_len(n),
                                B5 = sc$valeur, b5_status = sc$statut,
                                ecart = abs(sc$valeur - ref$valeur))
    }
    tab <- do.call(rbind, lignes)
    detail[[length(detail) + 1L]] <- tab
    avec_ref <- tab[!is.na(ref$valeur[tab$unite]), , drop = FALSE]
    e <- avec_ref$ecart
    p90 <- if (any(!is.na(e))) unname(stats::quantile(e, 0.9, na.rm = TRUE)) else NA_real_
    resume[[length(resume) + 1L]] <- data.frame(
      densite = d,
      proportion = round(p, 4),
      n_unites = sum(!is.na(ref$valeur)),
      ecart_median = if (any(!is.na(e))) stats::median(e, na.rm = TRUE) else NA_real_,
      ecart_p90 = p90,
      part_stable = if (nrow(avec_ref)) mean(!is.na(e) & e <= tolerance) else NA_real_,
      part_perdue = if (nrow(avec_ref)) mean(is.na(e)) else NA_real_,
      stable = !is.na(p90) && p90 <= tolerance
    )
  }
  vide_detail <- data.frame(densite = numeric(0), repetition = integer(0), unite = integer(0),
                            B5 = numeric(0), b5_status = character(0), ecart = numeric(0))
  vide_resume <- data.frame(densite = numeric(0), proportion = numeric(0), n_unites = integer(0),
                            ecart_median = numeric(0), ecart_p90 = numeric(0),
                            part_stable = numeric(0), part_perdue = numeric(0),
                            stable = logical(0))
  resume <- if (length(resume)) do.call(rbind, resume) else vide_resume
  conclusion <- if (!nrow(resume)) "non_simule"
                else if (isTRUE(resume$stable[1])) "densite_suffisante"
                else "densite_limite"

  structure(list(
    reference = reference,
    detail = if (length(detail)) do.call(rbind, detail) else vide_detail,
    resume = resume,
    densite_actuelle = actuelle,
    eclaircie = eclaircie,
    tolerance = tolerance,
    conclusion = conclusion
  ), class = "sensibilite_densite")
}

#' @export
print.sensibilite_densite <- function(x, ...) {
  cat(sprintf("B5 density sensitivity: current %.2f returns/m2, thinning by %s, tolerance %g points\n",
              x$densite_actuelle, x$eclaircie, x$tolerance))
  if (nrow(x$resume)) print(x$resume, row.names = FALSE)
  cat("Conclusion:", x$conclusion, "\n")
  invisible(x)
}
