#' Conformal residuals of a FINN calibration
#'
#' Measures the error of a calibrated FINN model on plots that took no part
#' in the calibration, so that [simuler_itineraire()] can give a prediction
#' interval (split conformal prediction, Lei et al. 2018). The half-width is
#' the quantile of the absolute residuals of the basal area after one FINN
#' step, at level `niveau * (1 + 1 / n)`: if the new plots are exchangeable
#' with these ones, the interval holds the observed value with probability at
#' least `niveau` on average.
#'
#' @param calibration A `"finn_calibration"` object from [calibrer_finn()].
#' @param arbres data.frame of trees measured twice on plots **not** used in
#'   the calibration, with the columns of [calibrer_finn()] (`placette`,
#'   `essence`, `d1`, `d2`, `poids`, `statut`).
#' @param environnement data.frame, one row per plot: `placette` and the
#'   variables of the calibration.
#' @param niveau Numeric in `(0, 1)`. Target coverage. Default 0.9.
#' @param n_tirages Integer. Draws averaged per plot. Default 10.
#' @param coordonnees data.frame or `NULL`. `placette`, `x`, `y` in a
#'   projected CRS (metres), for the interval of units of several plots in
#'   [simuler_itineraire()]: residuals are then averaged over groups of
#'   **neighbouring** plots. Without coordinates the groups are random, which
#'   ignores the spatial correlation of the errors and gives a narrower
#'   interval.
#'
#' @return The calibration, with an element `conforme`: a list with
#'   `niveau`, `demi_largeur` (m2/ha, for one step and one plot),
#'   `n_placettes`, `pas_annees`, and the signed residuals `residus` (with
#'   `x`, `y` when `coordonnees` is given) for the units.
#'
#' @details
#' Stops if some plots were used in the calibration (their residuals are
#' too small). The residuals are measured for **one step** only (the
#' interval between two visits): beyond, [simuler_itineraire()] widens the
#' interval under an explicit hypothesis. On BFC (1000 plots, 5 years, model
#' calibrated with `min_arbres_essence = 300`), the half-width at 90 % was
#' 4.70 m2/ha and the interval held 91 % of the basal areas of 1000 other
#' plots (spec 068).
#'
#' For a unit of `k` plots, the half-width is the conformal quantile of the
#' mean residual of groups of `k` held-out plots. On BFC the residuals of
#' two plots are barely correlated (0.02 to 0.04 between 1.5 and 20 km), but
#' the mean error does not shrink as `1 / sqrt(k)`: the shared bias stays.
#' At 90 %, measured on 1000 held-out plots: 4.57 m2/ha for one plot, 2.93
#' for 4 neighbouring plots, 1.79 for 16; on groups of 1000 other plots they
#' held 91, 93 and 91 % of the errors, against 88 and 77 % for
#' `1 / sqrt(k)` (2.28 and 1.14) and 94 and 86 % for random groups
#' (`data-raw/prototype_finn_unites.R`). IFN plots are kilometres apart
#' and their coordinates are blurred: a correlation within a stand, at a few
#' hundred metres, is not measured.
#'
#' @references Lei J., G'Sell M., Rinaldo A., Tibshirani R.J., Wasserman L.
#'   (2018). Distribution-free predictive inference for regression. Journal
#'   of the American Statistical Association 113(523), 1094-1111.
#' @seealso [calibrer_finn()], [simuler_itineraire()]
#' @export
conformer_finn <- function(calibration, arbres, environnement, niveau = 0.9,
                           n_tirages = 10L, coordonnees = NULL) {
  if (!inherits(calibration, "finn_calibration")) {
    cli::cli_abort("{.arg calibration} must come from {.fn calibrer_finn}.")
  }
  if (!is.numeric(niveau) || length(niveau) != 1L || niveau <= 0 || niveau >= 1) {
    cli::cli_abort("{.arg niveau} must be a number in (0, 1).")
  }
  arbres <- as.data.frame(arbres)
  communes <- intersect(unique(as.character(arbres$placette)), calibration$placettes)
  if (length(communes)) {
    cli::cli_abort(c(
      "{length(communes)} plot{?s} of {.arg arbres} {?was/were} used in the calibration.",
      "i" = "Conformal residuals need plots the model has not seen."
    ))
  }
  pred <- predire_finn(calibration, arbres, environnement, n_tirages = n_tirages)
  obs <- .finn_g_observee(arbres)
  r <- pred$g_predite - obs[match(pred$placette, names(obs))]
  ok <- is.finite(r)
  r <- as.numeric(r[ok]); pla <- pred$placette[ok]
  if (length(r) < 30L) {
    cli::cli_abort("Only {length(r)} plot{?s} with an observed basal area: at least 30 needed.")
  }
  q <- stats::quantile(abs(r), min(1, niveau * (1 + 1 / length(r))), names = FALSE)
  conf <- list(niveau = niveau, demi_largeur = q, n_placettes = length(r),
               pas_annees = calibration$pas_annees, residus = r, x = NULL, y = NULL)
  if (!is.null(coordonnees)) {
    coordonnees <- as.data.frame(coordonnees)
    manq <- setdiff(c("placette", "x", "y"), names(coordonnees))
    if (length(manq)) cli::cli_abort("{.arg coordonnees} lacks {.field {manq}}.")
    k <- match(pla, as.character(coordonnees$placette))
    if (anyNA(k) || any(!is.finite(coordonnees$x[k]) | !is.finite(coordonnees$y[k]))) {
      cli::cli_abort("{.arg coordonnees} must give finite {.field x}, {.field y} for every plot.")
    }
    conf$x <- coordonnees$x[k]; conf$y <- coordonnees$y[k]
  }
  calibration$conforme <- conf
  calibration
}

#' Simulate stand trajectories under a silvicultural itinerary
#'
#' Runs a calibrated FINN model step by step from the initial state of each
#' plot, and applies the rules of an itinerary **between the steps** by
#' removing stems from the cohorts (spec 068, D-2): FINN learns the natural
#' dynamics only, the cuts are imposed from outside.
#'
#' @param calibration A `"finn_calibration"` object from [calibrer_finn()],
#'   with conformal residuals from [conformer_finn()] for an interval.
#' @param arbres data.frame of the initial trees: `placette`, `essence`,
#'   `d1` (cm), `poids` (stems/ha); with a `statut` column, only `"vivant"`
#'   and `"mort"` rows are kept, as in [predire_finn()].
#' @param environnement data.frame, one row per plot: `placette` and the
#'   variables of the calibration. Held constant over the horizon.
#' @param itineraire `NULL` (no management) or one entry of
#'   [itineraires_catalogue()] with `statut_source = "source"`. Rules used
#'   (`regles`), all optional except the rotation:
#'   \describe{
#'     \item{rotation_ans}{years between two interventions; a multiple of
#'       `calibration$pas_annees`.}
#'     \item{diametre_exploitabilite_cm}{every stem at or above this
#'       diameter is harvested.}
#'     \item{surface_terriere_cible_m2ha}{if the basal area is above the
#'       target, a share `(G - cible) / G` of the stems of every cohort is
#'       removed (thinning across all sizes).}
#'     \item{intensite_prelevement_pct}{maximum share of the stems removed
#'       by the thinning; alone (no target), the share removed at every
#'       intervention.}
#'   }
#'   Stems removed are drawn (binomial per cohort): rounding would never cut
#'   a cohort of a single large stem.
#' @param horizon Numeric. Years simulated, a multiple of
#'   `calibration$pas_annees`. Default 50.
#' @param n_tirages Integer. Trajectories per plot (FINN is stochastic).
#'   Default 20.
#' @param elargissement Character. How the conformal half-width `q`
#'   (measured for one step) grows with the number of steps `k`:
#'   `"racine"` (default, `q * sqrt(k)`, independent errors from step to
#'   step) or `"lineaire"` (`q * k`, errors that add up). Both are
#'   **hypotheses**: no plot is revisited over 50 years.
#' @param unites data.frame or `NULL`. `placette`, `unite`: the plots of each
#'   management unit (UGF). The output is then one row per unit, the mean of
#'   its plots (equal weights), with the half-width of a unit of `k` plots
#'   measured by [conformer_finn()] on groups of `k` held-out plots.
#'
#' @return data.frame in long format, one row per plot, year and variable:
#'   `placette`, `itineraire`, `annee` (years from the start, 0 = initial
#'   state), `variable` (`"g"`: basal area before the cut, m2/ha;
#'   `"tiges"`: stems/ha before the cut; `"g_prelevee"`: basal area
#'   removed at that date, m2/ha), `moyenne` (mean of the trajectories),
#'   `bas`, `haut` (interval, for `"g"` only) and `intervalle`
#'   (`"conforme"` at one step, `"conforme_racine"` or
#'   `"conforme_lineaire"` beyond, `"aucun"` without conformal residuals or
#'   at year 0). With `unites`: `unite` instead of `placette`, plus
#'   `n_placettes` and `groupes_conformes` (`"voisins"`, `"hasard"` or
#'   `"placette"` for a unit of one plot).
#'
#' @details
#' The climate is the one of `environnement`, held constant: without an
#' explicit scenario a 50-year trajectory assumes the recent climate. The
#' response of the stand to a thinning (faster growth) comes only from the
#' competition FINN learnt on unthinned plots. The conformal interval is
#' measured on the natural dynamics over one step; after a cut it is kept as
#' is, which is another hypothesis.
#'
#' @seealso [calibrer_finn()], [conformer_finn()], [itineraires_catalogue()]
#' @export
simuler_itineraire <- function(calibration, arbres, environnement, itineraire = NULL,
                               horizon = 50, n_tirages = 20L,
                               elargissement = c("racine", "lineaire"), unites = NULL) {
  if (!inherits(calibration, "finn_calibration")) {
    cli::cli_abort("{.arg calibration} must come from {.fn calibrer_finn}.")
  }
  elargissement <- match.arg(elargissement)
  pas_a <- calibration$pas_annees
  n_pas <- .itin_nombre_pas(horizon, pas_a, "horizon")
  regles <- .itin_regles(itineraire, pas_a)
  code <- if (is.null(itineraire)) "sans_gestion" else itineraire$code
  if (!is.null(unites)) {
    unites <- as.data.frame(unites)
    manq <- setdiff(c("placette", "unite"), names(unites))
    if (length(manq)) cli::cli_abort("{.arg unites} lacks {.field {manq}}.")
    if (anyDuplicated(unites$placette)) cli::cli_abort("A plot belongs to one unit only in {.arg unites}.")
  }
  .finn_verifier_installation()

  if (!"statut" %in% names(arbres)) arbres$statut <- "vivant"
  arbres$d2 <- NA_real_
  prep <- .finn_preparer(arbres, environnement, calibration$surface_placette,
                         essences = calibration$essences,
                         variables_env = calibration$variables_env,
                         observations = FALSE)
  sp <- calibration$surface_placette
  n_sites <- nrow(prep$sites)
  env1 <- prep$env[prep$env$year == 0L, , drop = FALSE]
  m <- calibration$modele
  m$eval()

  # une trajectoire : matrices site x pas (g, tiges, g prelevee)
  une_trajectoire <- function() {
    g <- tiges <- prel <- matrix(0, n_sites, n_pas + 1L)
    coh <- prep$init[, c("siteID", "species", "dbh", "trees")]
    coh$trees <- round(coh$trees)
    etat <- .itin_etat(coh, n_sites, sp)
    g[, 1] <- etat$g; tiges[, 1] <- etat$tiges
    for (k in seq_len(n_pas)) {
      sim <- .itin_un_pas(m, coh, env1, sp, length(calibration$essences))
      coh <- sim
      etat <- .itin_etat(coh, n_sites, sp)
      g[, k + 1L] <- etat$g; tiges[, k + 1L] <- etat$tiges
      if (!is.null(regles) && (k * pas_a) %% regles$rotation_ans == 0 && k < n_pas) {
        coupe <- .itin_couper(coh, regles, n_sites, sp)
        prel[, k + 1L] <- etat$g - .itin_etat(coupe, n_sites, sp)$g
        coh <- coupe
      }
    }
    list(g = g, tiges = tiges, prel = prel)
  }
  traj <- lapply(seq_len(n_tirages), function(i) une_trajectoire())
  moy <- function(v) Reduce(`+`, lapply(traj, `[[`, v)) / n_tirages

  annees <- (0:n_pas) * pas_a
  long <- function(mat, variable) {
    data.frame(placette = rep(prep$sites$placette, times = n_pas + 1L),
               itineraire = code, annee = rep(annees, each = n_sites),
               variable = variable, moyenne = as.vector(mat), stringsAsFactors = FALSE)
  }
  out <- rbind(long(moy("g"), "g"), long(moy("tiges"), "tiges"),
               long(moy("prel"), "g_prelevee"))
  conf <- calibration$conforme
  if (is.null(unites)) {
    k_unite <- rep(1L, nrow(out))
  } else {
    out$unite <- as.character(unites$unite)[match(out$placette, as.character(unites$placette))]
    sans <- unique(out$placette[is.na(out$unite)])
    if (length(sans)) {
      cli::cli_abort("{length(sans)} simulated plot{?s} without a unit in {.arg unites}.")
    }
    out <- stats::aggregate(moyenne ~ unite + itineraire + annee + variable, data = out,
                            FUN = mean)
    n_pla <- table(unites$unite[unites$placette %in% prep$sites$placette])
    out$n_placettes <- as.integer(n_pla[out$unite])
    out <- out[order(match(out$variable, c("g", "tiges", "g_prelevee")), out$annee, out$unite), ]
    out <- out[, c("unite", "n_placettes", "itineraire", "annee", "variable", "moyenne")]
    k_unite <- out$n_placettes
    out$groupes_conformes <- NA_character_
  }
  out$bas <- NA_real_; out$haut <- NA_real_; out$intervalle <- "aucun"
  if (!is.null(conf)) {
    k <- out$annee / pas_a
    sel <- out$variable == "g" & k > 0
    q <- numeric(nrow(out))
    for (n in unique(k_unite[sel])) {
      dl <- .finn_demi_largeur(conf, n)
      q[sel & k_unite == n] <- dl$q
      if (!is.null(unites)) out$groupes_conformes[sel & k_unite == n] <- dl$groupes
    }
    h <- q[sel] * if (elargissement == "racine") sqrt(k[sel]) else k[sel]
    out$bas[sel] <- pmax(0, out$moyenne[sel] - h)
    out$haut[sel] <- out$moyenne[sel] + h
    out$intervalle[sel] <- ifelse(k[sel] == 1, "conforme", paste0("conforme_", elargissement))
  }
  rownames(out) <- NULL
  out
}

# --- interne ------------------------------------------------------------------

# Demi-largeur conforme d'une unite de k placettes : quantile de |residu moyen|
# sur des groupes disjoints de k placettes tenues a l'ecart, voisines si les
# coordonnees sont connues (glouton, depuis l'ouest), au hasard sinon.
.finn_demi_largeur <- function(conf, k) {
  if (k <= 1L) return(list(q = conf$demi_largeur, groupes = "placette"))
  r <- conf$residus
  if (is.null(r)) {
    cli::cli_abort("The conformal residuals were not kept: run {.fn conformer_finn} again.")
  }
  n_g <- length(r) %/% k
  if (n_g < 30L) {
    cli::cli_abort(c(
      "A unit of {k} plots needs at least {30 * k} held-out plots in {.fn conformer_finn}.",
      "i" = "{length(r)} were used: {n_g} group{?s} of {k}, 30 needed."
    ))
  }
  g <- integer(length(r))
  if (!is.null(conf$x)) {
    reste <- order(conf$x, conf$y)
    for (id in seq_len(n_g)) {
      i <- reste[1L]
      d2 <- (conf$x[reste] - conf$x[i])^2 + (conf$y[reste] - conf$y[i])^2
      j <- reste[order(d2)[seq_len(k)]]
      g[j] <- id
      reste <- setdiff(reste, j)
    }
    groupes <- "voisins"
  } else {
    o <- withr::with_seed(k, sample.int(length(r)))
    g[o[seq_len(n_g * k)]] <- rep(seq_len(n_g), each = k)
    groupes <- "hasard"
  }
  m <- tapply(r[g > 0], g[g > 0], mean)
  q <- stats::quantile(abs(m), min(1, conf$niveau * (1 + 1 / n_g)), names = FALSE)
  list(q = q, groupes = groupes)
}

# G observee a la seconde visite (vivants + recrutes), m2/ha, par placette.
.finn_g_observee <- function(arbres) {
  v <- arbres$statut %in% c("vivant", "recrute") & is.finite(arbres$d2)
  g <- tapply(ifelse(v, arbres$poids * .g_arbre(arbres$d2), 0),
              as.character(arbres$placette), sum)
  g[] <- as.numeric(g)
  g
}

.itin_nombre_pas <- function(annees, pas_a, nom) {
  if (!is.numeric(annees) || length(annees) != 1L || !is.finite(annees) || annees <= 0 ||
      abs(annees / pas_a - round(annees / pas_a)) > 1e-8) {
    cli::cli_abort("{.arg {nom}} must be a positive multiple of the FINN step ({pas_a} years).")
  }
  as.integer(round(annees / pas_a))
}

# Regles d'un itineraire du catalogue, verifiees. NULL = sans gestion.
.itin_regles <- function(itineraire, pas_a) {
  if (is.null(itineraire)) return(NULL)
  if (!is.list(itineraire) || is.null(itineraire$code) || is.null(itineraire$regles)) {
    cli::cli_abort("{.arg itineraire} must be one entry of {.fn itineraires_catalogue}.")
  }
  if (!identical(itineraire$statut_source, "source")) {
    cli::cli_abort(c(
      "Itinerary {.val {itineraire$code}} is not sourced ({.field statut_source} = {.val {itineraire$statut_source %||% NA}}).",
      "i" = "Its rules must come from a cited silvicultural guide before any simulation."
    ))
  }
  r <- itineraire$regles
  num <- function(x) if (is.null(x)) NULL else as.numeric(x)
  regles <- list(
    rotation_ans = num(r$rotation_ans),
    diametre = num(r$diametre_exploitabilite_cm),
    cible = num(r$surface_terriere_cible_m2ha),
    intensite = num(r$intensite_prelevement_pct)
  )
  if (is.null(regles$diametre) && is.null(regles$cible) && is.null(regles$intensite)) {
    cli::cli_abort("Itinerary {.val {itineraire$code}} has no cutting rule to apply.")
  }
  if (is.null(regles$rotation_ans)) {
    cli::cli_abort("Itinerary {.val {itineraire$code}} has no {.field rotation_ans}.")
  }
  .itin_nombre_pas(regles$rotation_ans, pas_a, "rotation_ans")
  if (!is.null(regles$intensite) && (regles$intensite <= 0 || regles$intensite > 100)) {
    cli::cli_abort("{.field intensite_prelevement_pct} must be in (0, 100].")
  }
  regles
}

# G (m2/ha) et tiges/ha par site depuis une table de cohortes.
.itin_etat <- function(coh, n_sites, sp) {
  f <- factor(coh$siteID, levels = seq_len(n_sites))
  g <- tapply(coh$trees * .g_arbre(coh$dbh), f, sum)
  n <- tapply(coh$trees, f, sum)
  g[is.na(g)] <- 0; n[is.na(n)] <- 0
  list(g = as.numeric(g) / sp, tiges = as.numeric(n) / sp)
}

# Coupe entre deux pas : exploitabilite puis eclaircie, tiges tirees.
.itin_couper <- function(coh, regles, n_sites, sp) {
  if (!nrow(coh)) return(coh)
  if (!is.null(regles$diametre)) {
    coh$trees[coh$dbh >= regles$diametre] <- 0
  }
  p <- NULL
  g <- .itin_etat(coh, n_sites, sp)$g
  if (!is.null(regles$cible)) {
    p <- ifelse(g > regles$cible & g > 0, (g - regles$cible) / g, 0)
    if (!is.null(regles$intensite)) p <- pmin(p, regles$intensite / 100)
  } else if (!is.null(regles$intensite)) {
    p <- rep(regles$intensite / 100, n_sites)
  }
  if (!is.null(p)) {
    ps <- p[coh$siteID]
    coh$trees <- stats::rbinom(nrow(coh), size = as.integer(coh$trees), prob = 1 - ps)
  }
  coh[coh$trees > 0, , drop = FALSE]
}

# Un pas FINN depuis une table de cohortes (siteID, species, dbh, trees).
.itin_un_pas <- function(m, coh, env1, sp, n_sp) {
  dt <- data.table::as.data.table
  coh <- coh[coh$trees > 0, , drop = FALSE]
  init <- if (nrow(coh)) {
    FINN::makeInitCohorts(dt(data.frame(siteID = coh$siteID, patchID = 1L,
                                        species = coh$species, dbh = coh$dbh,
                                        trees = coh$trees)), Nspecies = n_sp)
  } else NULL
  sim <- stats::predict(m, env = dt(env1), init_cohort = init, patches = 1L,
                        patch_size = sp, device = "cpu", return_cohorts = "last")
  l <- as.data.frame(sim$long$cohort)
  l <- l[l$variable %in% c("trees", "dbh"), , drop = FALSE]
  if (!nrow(l)) return(data.frame(siteID = integer(), species = integer(),
                                  dbh = numeric(), trees = numeric()))
  cle <- paste(l$siteID, l$patchID, l$cohortID)
  n <- l[l$variable == "trees", , drop = FALSE]
  d <- l[l$variable == "dbh", , drop = FALSE]
  out <- data.frame(siteID = n$siteID, species = n$species,
                    dbh = d$value[match(cle[l$variable == "trees"], cle[l$variable == "dbh"])],
                    trees = n$value)
  out[is.finite(out$trees) & out$trees > 0, , drop = FALSE]
}
