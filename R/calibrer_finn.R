#' Calibrate FINN on revisited plots
#'
#' Fits the mechanistic processes of FINN (Forest Informed Neural Networks,
#' Kaber et al.; growth, mortality, regeneration, competition) on plots
#' measured twice, so that the model can then simulate stand trajectories
#' (spec 068, chantier D, step 3). One FINN site is one plot, one FINN step is
#' the interval between the two visits.
#'
#' @param arbres data.frame, one row per tree and pair of visits, with
#'   columns:
#'   \describe{
#'     \item{placette}{plot identifier.}
#'     \item{essence}{species code (character).}
#'     \item{d1, d2}{diameter at breast height (cm) at the first and second
#'       visit; `d1` is `NA` for recruits, `d2` for dead or cut trees.}
#'     \item{poids}{stems per hectare represented by the tree (the IFN `W`):
#'       the weight of the first visit for a tree followed, the theoretical
#'       weight of its circle for a recruit.}
#'     \item{statut}{`"vivant"` (alive at both visits), `"mort"` (died or
#'       left the stand), `"coupe"` (cut) or `"recrute"` (new at the second
#'       visit).}
#'   }
#'   Cut trees are removed from the initial state: the cut is assumed to
#'   happen at the start of the interval, so that FINN learns the natural
#'   dynamics only (interventions are applied between steps, D-2).
#' @param environnement data.frame, one row per plot: `placette` and the
#'   numeric environmental variables (e.g. summer maximum temperature, annual
#'   rainfall, soil depth), in natural units (FINN standardises them). Plots
#'   with a missing value are dropped.
#' @param processus Character. `"mecaniste"` (default) is the only value for
#'   now: neural components come only once a cross-validation shows a gain on
#'   revisited plots (D-3).
#' @param surface_placette Numeric. Area of the FINN patch, in hectares.
#'   Default 0.7. FINN rounds cohort sizes to integers: with the 15 m circle
#'   of the IFN (0.0707 ha) a tree of the 6 m circle counts 6.25 stems rounded
#'   to 6, which adds noise of 1.4 m2/ha (SD) on the initial basal area and a
#'   bias on recruitment; at 0.7 ha both vanish (spec 068, section 9).
#' @param epoques Integer. Number of training epochs. Default 600.
#' @param taux_apprentissage Numeric. Learning rate. Default 0.003 (better
#'   held-out error than 0.01 on BFC, spec 068).
#' @param part_essences Numeric in `(0, 1]`. Species kept by decreasing
#'   initial basal area until they cover this share; the others are pooled
#'   in `"other"`. Default 0.9.
#' @param min_arbres_essence Integer. Minimum number of initial trees (alive
#'   or dead at the first visit) for a species to get its own parameters;
#'   below it the species goes to `"other"`, even within `part_essences`.
#'   Default 300: on BFC, species with 130 to 140 trees gave unstable
#'   parameters (predictions of several hundred m2/ha on a few plots in two
#'   bootstrap calibrations out of four, spec 068).
#' @param pas_annees Numeric. Years between the two visits, kept as metadata
#'   for the simulations. Default 5.
#' @param graine Integer. Random seed (R and torch). Default 42.
#' @param dossier Character or `NULL`. Folder where FINN writes checkpoints
#'   every 100 epochs. Default `NULL` (none).
#' @param poids_perte `"auto"` (default) or a numeric vector of six weights
#'   named `dbh`, `ba`, `trees`, `growth`, `mortality`, `regeneration`, the
#'   weights of the loss terms passed to FINN. `"auto"` lets FINN scale each
#'   term by its intercept-only baseline (it prints the values).
#'
#' @return A list of class `"finn_calibration"`: `modele` (the fitted FINN
#'   model, a torch object: save it with `torch::torch_save()`, not
#'   `saveRDS()`), `essences`, `variables_env`, `surface_placette`,
#'   `pas_annees`, `recruits_dbh`, `n_placettes`, `epoques`,
#'   `taux_apprentissage`, `processus`, `placettes` (identifiers of the
#'   calibration plots, checked by [conformer_finn()]).
#'
#' @details
#' Requires the suggested packages \pkg{FINN}, \pkg{torch} (with libtorch,
#' `torch::install_torch()`) and \pkg{data.table}; the function stops with a
#' clear message when they are missing.
#'
#' On 1000 IFN plots of Bourgogne-Franche-Comte revisited after 5 years, with
#' summer maximum temperature, annual rainfall (E-OBS) and soil depth, the
#' error on the basal area at 5 years of 1000 other plots was 3.36 m2/ha
#' (bias +0.37, 40 minutes of CPU), against 3.58 for a linear regression and
#' 4.24 for persistence (`data-raw/prototype_finn_calibration.R`).
#'
#' @seealso [predire_finn()]
#' @references Kaber Y., Hartig F. et al. FINN: Forest Informed Neural
#'   Networks. R package version 0.1.0, CRAN.
#' @export
calibrer_finn <- function(arbres, environnement, processus = "mecaniste",
                          surface_placette = 0.7, epoques = 600L,
                          taux_apprentissage = 0.003, part_essences = 0.9,
                          min_arbres_essence = 300L,
                          pas_annees = 5, graine = 42L, dossier = NULL,
                          poids_perte = "auto") {
  processus <- match.arg(processus, c("mecaniste", "neuronal"))
  termes <- c("dbh", "ba", "trees", "growth", "mortality", "regeneration")
  if (!identical(poids_perte, "auto")) {
    if (!is.numeric(poids_perte) || !setequal(names(poids_perte), termes) ||
        length(poids_perte) != 6L || any(!is.finite(poids_perte)) || any(poids_perte < 0)) {
      cli::cli_abort(c(
        "{.arg poids_perte} must be {.val auto} or six non-negative weights.",
        "i" = "Names: {.val {termes}}."
      ))
    }
    poids_perte <- poids_perte[termes]
  }
  if (processus == "neuronal") {
    cli::cli_abort(c(
      "Neural processes are not available yet.",
      "i" = "They wait for a cross-validation showing a gain over the mechanistic processes (spec 068, D-3)."
    ))
  }
  .finn_verifier_installation()
  prep <- .finn_preparer(arbres, environnement, surface_placette, part_essences,
                         min_arbres_essence = min_arbres_essence)

  set.seed(graine)
  FINN::FINN.seed(graine)
  dt <- function(x) data.table::as.data.table(x)
  # createProcess evalue sa formule dans l'espace de noms de FINN : on lui
  # passe l'objet formule lui-meme (do.call), pas un symbole local
  f_env <- stats::reformulate(prep$variables_env)
  processus_env <- function(f) {
    do.call(FINN::createProcess, list(formula = f_env, func = f,
                                      optimizeSpecies = TRUE, optimizeEnv = TRUE))
  }
  m <- FINN::finn(
    N_species = length(prep$essences),
    recruits_dbh = prep$recruits_dbh,
    competition_process = do.call(FINN::createProcess,
                                  list(formula = ~0, func = FINN::competition,
                                       optimizeSpecies = TRUE)),
    growth_process = processus_env(FINN::growth),
    regeneration_process = processus_env(FINN::regeneration),
    mortality_process = processus_env(FINN::mortality)
  )
  FINN::fit(
    m, env = dt(prep$env), data = dt(prep$obs),
    init_cohort = FINN::makeInitCohorts(dt(prep$init), Nspecies = length(prep$essences)),
    device = "cpu", epochs = as.integer(epoques),
    # FINN jette le dernier lot incomplet : jamais plus grand que les placettes
    batchsize = min(50L, nrow(prep$sites)),
    patches = 1L, patch_size = surface_placette, lr = taux_apprentissage,
    weights = poids_perte, plot_progress = FALSE, folder = dossier,
    checkpoints = min(100L, max(as.integer(epoques), 1L))
  )
  structure(list(
    modele = m, essences = prep$essences, variables_env = prep$variables_env,
    surface_placette = surface_placette, pas_annees = pas_annees,
    recruits_dbh = prep$recruits_dbh, n_placettes = nrow(prep$sites),
    placettes = prep$sites$placette,
    epoques = as.integer(epoques), taux_apprentissage = taux_apprentissage,
    processus = processus
  ), class = "finn_calibration")
}

#' Predict basal area with a calibrated FINN model
#'
#' Simulates, from the initial state of each plot, the basal area after a
#' number of FINN steps, averaged over several draws (FINN is stochastic).
#'
#' @param calibration A `"finn_calibration"` object from [calibrer_finn()].
#' @param arbres data.frame of the initial trees: `placette`, `essence`, `d1`
#'   (cm), `poids` (stems/ha). If a `statut` column is present, only
#'   `"vivant"` and `"mort"` rows are kept (the initial state, as in
#'   [calibrer_finn()]). Species unknown to the calibration go to `"other"`.
#' @param environnement data.frame, one row per plot: `placette` and the
#'   variables of the calibration.
#' @param n_tirages Integer. Number of draws averaged. Default 10.
#' @param pas Integer. Number of FINN steps (each of
#'   `calibration$pas_annees` years). Default 1.
#' @param correction Logical. Apply the growth correction of
#'   [corriger_finn()] when the calibration carries one. Default `TRUE`.
#'
#' @return data.frame, one row per plot: `placette`, `g_initiale`,
#'   `g_predite` (mean of the draws), `g_q05`, `g_q95` (5 and 95 % quantiles
#'   of the draws), in m2/ha. The quantiles only show the demographic
#'   stochasticity of FINN, not the uncertainty of its parameters: they are
#'   not a prediction interval (on BFC they held 19 % of the observed
#'   values).
#' @seealso [calibrer_finn()]
#' @export
predire_finn <- function(calibration, arbres, environnement, n_tirages = 10L, pas = 1L,
                         correction = TRUE) {
  if (!inherits(calibration, "finn_calibration")) {
    cli::cli_abort("{.arg calibration} must come from {.fn calibrer_finn}.")
  }
  .finn_verifier_installation()
  if (!"statut" %in% names(arbres)) arbres$statut <- "vivant"
  arbres$d2 <- NA_real_
  prep <- .finn_preparer(arbres, environnement, calibration$surface_placette,
                         essences = calibration$essences,
                         variables_env = calibration$variables_env,
                         observations = FALSE)
  dt <- function(x) data.table::as.data.table(x)
  env <- do.call(rbind, lapply(0:pas, function(a) {
    e <- prep$env[prep$env$year == 0L, , drop = FALSE]
    e$year <- a
    e
  }))
  init <- FINN::makeInitCohorts(dt(prep$init), Nspecies = length(prep$essences))
  m <- calibration$modele
  m$eval()
  sp <- calibration$surface_placette
  corr <- if (isTRUE(correction)) calibration$correction else NULL
  n_s <- nrow(prep$sites)
  un_tirage <- if (is.null(corr)) function() {
    sim <- stats::predict(m, env = dt(env), init_cohort = init, patches = 1L,
                         patch_size = sp, device = "cpu")
    s <- as.data.frame(sim$long$site)
    s <- s[s$variable == "ba" & s$year == pas, , drop = FALSE]
    g <- tapply(s$value, s$siteID, sum) / sp
    out <- numeric(nrow(prep$sites))
    out[as.integer(names(g))] <- g
    out
  } else function() {
    # pas a pas par cohortes, pour corriger l'accroissement des survivants
    env1 <- prep$env[prep$env$year == 0L, , drop = FALSE]
    coh <- prep$init[, c("siteID", "species", "dbh", "trees")]
    coh$trees <- round(coh$trees)
    for (k in seq_len(pas)) {
      coh <- .itin_pas_corrige(m, coh, env1, sp, length(prep$essences), corr)
    }
    .itin_etat(coh, n_s, sp)$g
  }
  tirages <- vapply(seq_len(n_tirages), function(i) un_tirage(), numeric(n_s))
  tirages <- matrix(tirages, nrow = nrow(prep$sites))
  data.frame(
    placette = prep$sites$placette,
    g_initiale = prep$sites$g0,
    g_predite = rowMeans(tirages),
    g_q05 = apply(tirages, 1, stats::quantile, 0.05, names = FALSE),
    g_q95 = apply(tirages, 1, stats::quantile, 0.95, names = FALSE),
    stringsAsFactors = FALSE
  )
}

#' @export
print.finn_calibration <- function(x, ...) {
  cat(sprintf(
    "<finn_calibration> %s, %d plots, %d species (%s)\n  environment: %s\n  patch %.3g ha, step %g years, %d epochs, lr %g\n",
    x$processus, x$n_placettes, length(x$essences),
    paste(x$essences, collapse = ", "), paste(x$variables_env, collapse = ", "),
    x$surface_placette, x$pas_annees, x$epoques, x$taux_apprentissage
  ))
  invisible(x)
}

# --- interne ------------------------------------------------------------------

.finn_verifier_installation <- function() {
  rlang::check_installed(c("FINN", "torch", "data.table"),
                         reason = "to calibrate and run FINN (spec 068).")
  if (!torch::torch_is_installed()) {
    cli::cli_abort(c(
      "libtorch is not installed.",
      "i" = "Run {.code torch::install_torch()} once."
    ))
  }
  invisible(TRUE)
}

.g_arbre <- function(d) pi * (d / 200)^2

# Construit les tables FINN (sites, init, obs, env) en R de base, sans FINN :
# testable seul. `essences` / `variables_env` imposes en prediction.
.finn_preparer <- function(arbres, environnement, surface_placette,
                           part_essences = 0.9, min_arbres_essence = 300L,
                           essences = NULL,
                           variables_env = NULL, observations = TRUE) {
  arbres <- as.data.frame(arbres)
  environnement <- as.data.frame(environnement)
  req <- c("placette", "essence", "d1", "d2", "poids", "statut")
  manq <- setdiff(req, names(arbres))
  if (length(manq)) cli::cli_abort("{.arg arbres} lacks column{?s} {.field {manq}}.")
  if (!"placette" %in% names(environnement)) {
    cli::cli_abort("{.arg environnement} lacks column {.field placette}.")
  }
  if (!is.numeric(surface_placette) || length(surface_placette) != 1L || surface_placette <= 0) {
    cli::cli_abort("{.arg surface_placette} must be a positive number (hectares).")
  }
  statuts <- c("vivant", "mort", "coupe", "recrute")
  inconnus <- setdiff(unique(arbres$statut), statuts)
  if (length(inconnus)) {
    cli::cli_abort("Unknown {.field statut}: {.val {inconnus}}; expected {.val {statuts}}.")
  }
  arbres$placette <- as.character(arbres$placette)
  arbres$essence <- as.character(arbres$essence)
  environnement$placette <- as.character(environnement$placette)

  if (is.null(variables_env)) {
    variables_env <- setdiff(names(environnement)[vapply(environnement, is.numeric, logical(1))],
                             "placette")
    if (!length(variables_env)) {
      cli::cli_abort("{.arg environnement} has no numeric variable.")
    }
  } else {
    manq <- setdiff(variables_env, names(environnement))
    if (length(manq)) cli::cli_abort("{.arg environnement} lacks {.field {manq}}.")
  }
  environnement <- environnement[stats::complete.cases(environnement[, variables_env, drop = FALSE]),
                                 c("placette", variables_env), drop = FALSE]

  depart <- arbres$statut %in% c("vivant", "mort")
  ok_init <- depart & is.finite(arbres$d1) & is.finite(arbres$poids)
  # placettes : au moins un arbre vivant au depart et un environnement
  ids <- sort(intersect(unique(arbres$placette[ok_init]), environnement$placette))
  if (!length(ids)) cli::cli_abort("No plot with initial trees and environment.")
  arbres <- arbres[arbres$placette %in% ids, , drop = FALSE]
  depart <- arbres$statut %in% c("vivant", "mort")
  ok_init <- depart & is.finite(arbres$d1) & is.finite(arbres$poids)

  if (is.null(essences)) {
    g <- tapply(arbres$poids[ok_init] * .g_arbre(arbres$d1[ok_init]), arbres$essence[ok_init], sum)
    g <- sort(g, decreasing = TRUE)
    n <- which(cumsum(g) / sum(g) >= part_essences)[1]
    # une essence trop rare a des parametres instables : elle va dans "other"
    n_arbres <- table(arbres$essence[ok_init])
    gardees <- names(g)[seq_len(n)]
    gardees <- gardees[n_arbres[gardees] >= min_arbres_essence]
    essences <- c(setdiff(gardees, "other"), "other")
  }
  arbres$species <- match(ifelse(arbres$essence %in% essences, arbres$essence, "other"), essences)

  sites <- data.frame(placette = ids, siteID = seq_along(ids), stringsAsFactors = FALSE)
  arbres$siteID <- match(arbres$placette, ids)

  # etat initial : vivants au depart (morts compris), coupes et recrues exclus
  a0 <- arbres[ok_init, , drop = FALSE]
  init <- data.frame(siteID = a0$siteID, patchID = 1L, year = 0L, species = a0$species,
                     dbh = a0$d1, trees = a0$poids * surface_placette,
                     treeName = paste0("t", seq_len(nrow(a0))), living = TRUE)
  # G initiale apres l'arrondi des effectifs par FINN (CohortMat)
  sites$g0 <- as.numeric(tapply(round(init$trees) * .g_arbre(init$dbh),
                                factor(init$siteID, levels = sites$siteID), sum)) / surface_placette
  sites$g0[is.na(sites$g0)] <- 0

  env0 <- environnement[match(ids, environnement$placette), variables_env, drop = FALSE]
  env <- rbind(cbind(siteID = sites$siteID, env0, year = 0L),
               cbind(siteID = sites$siteID, env0, year = 1L))
  rownames(env) <- NULL

  recrues <- arbres$statut == "recrute" & is.finite(arbres$d2)
  recruits_dbh <- if (any(recrues)) mean(arbres$d2[recrues]) else NA_real_

  obs <- NULL
  if (observations) {
    if (!any(recrues)) cli::cli_abort("No recruit with a diameter: FINN needs {.field recruits_dbh}.")
    obs <- .finn_observations(arbres, sites, length(essences), surface_placette)
  }
  list(sites = sites, init = init, obs = obs, env = env, essences = essences,
       variables_env = variables_env, recruits_dbh = recruits_dbh)
}

# Observations a la revisite par site x essence (grille complete), au format
# attendu par FINN::fit (ba, trees, dbh, growth, mort, reg et effectifs).
.finn_observations <- function(arbres, sites, n_sp, surface_placette) {
  grille <- expand.grid(species = seq_len(n_sp), siteID = sites$siteID)
  cle <- paste(arbres$siteID, arbres$species)
  vit <- arbres$statut %in% c("vivant", "recrute") & is.finite(arbres$d2)
  suivi <- arbres$statut == "vivant" & is.finite(arbres$d1) & is.finite(arbres$d2)
  risque <- arbres$statut %in% c("vivant", "mort") & is.finite(arbres$d1)
  rows <- lapply(split(seq_len(nrow(arbres)), cle), function(i) {
    v <- i[vit[i]]; s <- i[suivi[i]]; r <- i[risque[i]]
    w <- arbres$poids; d1 <- arbres$d1; d2 <- arbres$d2
    c(ba = sum(w[v] * .g_arbre(d2[v])) * surface_placette,
      trees = sum(w[v]) * surface_placette,
      dbh = if (length(v)) stats::weighted.mean(d2[v], w[v]) else NA_real_,
      growth = if (length(s)) stats::weighted.mean(d2[s] / d1[s] - 1, w[s]) else NA_real_,
      growth_n = length(s),
      n_at_risk = length(r),
      n_died = sum(arbres$statut[r] == "mort"),
      reg = sum(w[i][arbres$statut[i] == "recrute"]))
  })
  m <- do.call(rbind, rows)
  k <- match(paste(grille$siteID, grille$species), names(rows))
  obs <- cbind(grille[, c("siteID", "species")], m[k, , drop = FALSE])
  for (j in c("ba", "trees", "reg", "growth_n", "n_at_risk", "n_died")) {
    obs[[j]][is.na(obs[[j]])] <- 0
  }
  for (j in c("growth_n", "n_at_risk", "n_died")) obs[[j]] <- as.integer(obs[[j]])
  obs$mort <- ifelse(obs$n_at_risk > 0, obs$n_died / obs$n_at_risk, NA_real_)
  obs$year <- 1L
  rownames(obs) <- NULL
  obs[, c("siteID", "year", "species", "ba", "dbh", "trees", "growth", "growth_n",
          "mort", "n_at_risk", "n_died", "reg")]
}
