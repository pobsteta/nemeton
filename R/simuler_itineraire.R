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
#'     \item{aucune_coupe}{`TRUE`: no cut at all (free development,
#'       senescence island); FINN's dynamics alone, reported under the
#'       itinerary's code. Excludes every other rule, the rotation
#'       included.}
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
#'     \item{norme_g_selon_dg}{a thinning norm by quadratic mean diameter:
#'       `dg_cm` (increasing) and `g_m2ha`, the basal area left after
#'       thinning at that mean diameter. The target is interpolated on the
#'       plot's Dg (all stems); below the first `dg_cm` there is no thinning,
#'       beyond the last one its value holds. Replaces
#'       `surface_terriere_cible_m2ha` (not both).}
#'     \item{rapport_g_tiges}{nature of the thinning: share of the basal
#'       area removed divided by share of the stems removed, i.e. the mean
#'       basal area of a removed stem over that of the stand before the cut
#'       (the Ve/V of the guides, on basal area). `1` (the default when
#'       absent) removes the same share of every cohort; below 1 the
#'       thinning takes smaller stems (from below), above 1 larger ones.
#'       Each cohort is removed with probability `min(1, c (g / gmean)^b)`,
#'       `c` and `b` solved per plot so that the basal area removed is the
#'       one of the target and the ratio the one given (as close as the
#'       sizes present allow). Needs a thinning rule.}
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
#' @param volume Logical. Also compute the merchantable volume (`"volume"`
#'   and `"volume_preleve"`, m3/ha) with the one-entry Schaeffer tariffs of
#'   the IFN ([ifn_tarif_schaeffer_reference()]: number and advised type of
#'   each species, cascade SER -> GRECO -> France with the SER of the
#'   `ser` column of `environnement` when present). Stems below 7.5 cm (the
#'   IFN threshold) have no volume. The `"other"` group takes the tariff of
#'   the dominant `"other"` species (basal area) of the plot at the start
#'   that has a tariff, or of all plots. Default `FALSE`.
#' @param unites data.frame or `NULL`. `placette`, `unite`: the plots of each
#'   management unit (UGF). The output is then one row per unit, the mean of
#'   its plots (equal weights), with the half-width of a unit of `k` plots
#'   measured by [conformer_finn()] on groups of `k` held-out plots.
#' @param carbone Logical. Also compute the carbon of the merchantable stem
#'   wood (`"carbone"` and `"carbone_preleve"`, tC/ha): the volume of the
#'   same tariffs as `volume` (needed, computed even when `volume = FALSE`)
#'   times the basic wood density of the species ([infradensite_espar()],
#'   that of the tariff species for `"other"`), `bef` and
#'   `fraction_carbone`. Default `FALSE`.
#' @param bef Numeric. Biomass expansion factor from stem volume to total
#'   aboveground biomass. Default 1.30, as [indicateur_c1_biomasse()].
#' @param fraction_carbone Numeric. Carbon fraction of the dry biomass.
#'   Default 0.50, the value of `inst/extdata/wood_density.csv` used by
#'   [indicateur_c1_biomasse()].
#' @param densite_max data.frame or `NULL`. Self-thinning ceiling applied
#'   after every FINN step: `essence` and `rdi_max`, the maximum stand
#'   density index of plots dominated (basal area) by that species, and
#'   optionally `g_max`, their maximum basal area (m2/ha), with a row
#'   `essence = "toutes"` used for the other species and for the `"other"`
#'   group; usually [densite_max_ifn()]. Above a ceiling of its dominant
#'   species, a plot loses its smallest stems until it is back under both
#'   (natural mortality, not counted as harvest). Default `NULL`: FINN's
#'   mortality alone, which does not stop the basal area (spec 068, section
#'   on the density ceiling).
#' @param produits Logical. Also follow the harvested wood outside the
#'   forest (needs `carbone = TRUE`): every stem cut is split into sawlog,
#'   industry and energy wood with `filiere`, the products feed two pools
#'   with first-order decay, and the emissions avoided by material and
#'   energy substitution are counted. Adds `"carbone_produits"` (stock,
#'   tC/ha), `"carbone_total"` (`"carbone"` + `"carbone_produits"`, tC/ha),
#'   `"substitution"` (tCO2/ha avoided at that date) and
#'   `"volume_preleve_bo"` (sawlog volume removed, m3/ha). The products of
#'   cuts made before year 0 are not counted. Default `FALSE`.
#' @param filiere List of the wood-chain parameters, as
#'   [parametres_filiere_bois()] (the default) returns them.
#' @param biodiversite Logical. Also follow two biodiversity variables that
#'   FINN can carry without heights (spec 068, family B): the deadwood
#'   produced by natural mortality (FINN and the density ceiling) and the
#'   very large living trees. Adds `"volume_mort"` (stem volume of the
#'   trees dead during the step, m3/ha, same tariffs as `volume`),
#'   `"bois_mort"` (stock of that deadwood, m3/ha, first-order decay with
#'   `decomposition`) and `"tiges_tgb"` (living stems/ha with a diameter of
#'   at least `seuil_tgb`). The deadwood present at year 0 and the felling
#'   residues are not counted. Default `FALSE`.
#' @param seuil_tgb Numeric. Diameter (cm) of a very large tree. Default
#'   67.5, the lower bound of the IFN "TGB" class and of the IBP factor E.
#' @param decomposition Named numeric, `feuillus` and `resineux`: annual
#'   decay rate of the deadwood. Default 0.023 and 0.069 (half-lives of 30
#'   and 10 years; INRA-IGN 2017, table 13.1, after Zell et al. 2009).
#' @param correction Logical. Apply the growth correction of
#'   [corriger_finn()] after every FINN step when the calibration carries
#'   one. Default `TRUE`.
#'
#' @return data.frame in long format, one row per plot, year and variable:
#'   `placette`, `itineraire`, `annee` (years from the start, 0 = initial
#'   state), `variable` (`"g"`: basal area before the cut, m2/ha;
#'   `"tiges"`: stems/ha before the cut; `"g_prelevee"`: basal area
#'   removed at that date, m2/ha; with `volume = TRUE`, `"volume"` and
#'   `"volume_preleve"`, m3/ha; with `carbone = TRUE`, `"carbone"` and
#'   `"carbone_preleve"`, tC/ha; with `produits = TRUE` and
#'   `biodiversite = TRUE`, see those arguments), `moyenne` (mean of the trajectories),
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
#' The volume comes from the diameter only (FINN carries no height). On
#' 12 974 trees of 1000 IFN plots of BFC, the tariffs of the exact species
#' give 1.8 % more than the IFN volumes in total, 9.6 % less between 7.5 and
#' 20 cm and 18.6 % more above 70 cm (`data-raw/prototype_finn_volume.R`).
#' The carbon inherits this volume (stems below 7.5 cm carry none) and holds
#' the same `bef` and `fraction_carbone` as C1, so that year 0 compares with
#' C1.
#'
#' With `produits = TRUE`, the carbon of the products is that of the stem
#' only (volume x basic density x `fraction_carbone`, no `bef`): branches,
#' small wood and logging losses leave the account at the cut. The sawlog
#' share is an upper bound (quality presumed on the standing tree) and the
#' substitution factors a mean of the literature (see
#' [parametres_filiere_bois()]).
#'
#' @seealso [calibrer_finn()], [conformer_finn()], [itineraires_catalogue()],
#'   [parametres_filiere_bois()]
#' @export
simuler_itineraire <- function(calibration, arbres, environnement, itineraire = NULL,
                               horizon = 50, n_tirages = 20L,
                               elargissement = c("racine", "lineaire"), volume = FALSE,
                               unites = NULL, carbone = FALSE, bef = 1.30,
                               fraction_carbone = 0.50, densite_max = NULL,
                               produits = FALSE, filiere = parametres_filiere_bois(),
                               biodiversite = FALSE, seuil_tgb = 67.5,
                               decomposition = c(feuillus = 0.023, resineux = 0.069),
                               correction = TRUE) {
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
  rdi_max <- .itin_rdi_max(densite_max, calibration$essences)
  if (isTRUE(produits)) {
    if (!isTRUE(carbone)) {
      cli::cli_abort("{.code produits = TRUE} needs {.code carbone = TRUE}: the stock is read with the standing carbon.")
    }
    filiere <- .filiere_verifier(filiere)
  }
  if (isTRUE(biodiversite)) {
    if (!is.numeric(seuil_tgb) || length(seuil_tgb) != 1L || !is.finite(seuil_tgb) ||
        seuil_tgb <= 0) {
      cli::cli_abort("{.arg seuil_tgb} must be a single positive diameter (cm).")
    }
    if (!is.numeric(decomposition) || !all(c("feuillus", "resineux") %in% names(decomposition)) ||
        any(!is.finite(decomposition[c("feuillus", "resineux")])) ||
        any(decomposition[c("feuillus", "resineux")] < 0)) {
      cli::cli_abort("{.arg decomposition} must give non-negative rates {.field feuillus} and {.field resineux}.")
    }
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
  tarif <- if (isTRUE(volume) || isTRUE(carbone) || isTRUE(biodiversite)) {
    .itin_tarifs(arbres, environnement, prep, calibration$essences)
  } else NULL
  m <- calibration$modele
  m$eval()
  corr <- if (isTRUE(correction)) calibration$correction else NULL
  if (isTRUE(produits)) {
    # par site x essence FINN : taux de bois d'oeuvre (groupe), part du BIBE
    # allant a l'industrie (feuillus / resineux)
    res_mat <- matrix(is_conifer(as.vector(tarif$espar)), nrow(tarif$espar))
    grp_mat <- matrix(.filiere_groupe(as.vector(tarif$espar)), nrow(tarif$espar))
    bi_mat <- ifelse(res_mat, filiere$part_bi[["resineux"]], filiere$part_bi[["feuillus"]])
    decroit <- exp(-log(2) / filiere$demi_vie[c("bo", "bi")] * pas_a)
  }
  if (isTRUE(biodiversite)) {
    # bois mort : un pool feuillus, un pool resineux (site x essence FINN)
    res_bm <- matrix(is_conifer(as.vector(tarif$espar)), nrow(tarif$espar))
    garde_bm <- exp(-decomposition[c("feuillus", "resineux")] * pas_a)
  }

  # une trajectoire : matrices site x pas (g, tiges, g prelevee, volumes)
  une_trajectoire <- function() {
    g <- tiges <- prel <- vol <- vprel <- carb <- cprel <- matrix(0, n_sites, n_pas + 1L)
    cprod <- subst <- vbo <- vmort <- bmort <- tgb <- matrix(0, n_sites, n_pas + 1L)
    pool_bo <- pool_bi <- bm_f <- bm_r <- numeric(n_sites)
    coh <- prep$init[, c("siteID", "species", "dbh", "trees")]
    coh$trees <- round(coh$trees)
    etat <- .itin_etat(coh, n_sites, sp, tarif)
    g[, 1] <- etat$g; tiges[, 1] <- etat$tiges; vol[, 1] <- etat$v; carb[, 1] <- etat$c
    if (isTRUE(biodiversite)) tgb[, 1] <- .itin_tiges_tgb(coh, n_sites, sp, seuil_tgb)
    for (k in seq_len(n_pas)) {
      coh <- .itin_pas_corrige(m, coh, env1, sp, length(calibration$essences), corr)
      morts <- list(attr(coh, "morts"))
      if (!is.null(rdi_max)) {
        coh <- .itin_auto_eclaircie(coh, rdi_max, n_sites, sp)
        morts[[2]] <- attr(coh, "morts")
      }
      etat <- .itin_etat(coh, n_sites, sp, tarif)
      g[, k + 1L] <- etat$g; tiges[, k + 1L] <- etat$tiges; vol[, k + 1L] <- etat$v
      carb[, k + 1L] <- etat$c
      if (isTRUE(biodiversite)) {
        vm <- .itin_volume_morts(morts, tarif, res_bm, n_sites, sp)
        bm_f <- bm_f * garde_bm[[1]] + vm$feuillus
        bm_r <- bm_r * garde_bm[[2]] + vm$resineux
        vmort[, k + 1L] <- vm$feuillus + vm$resineux
        bmort[, k + 1L] <- bm_f + bm_r
        tgb[, k + 1L] <- .itin_tiges_tgb(coh, n_sites, sp, seuil_tgb)
      }
      if (isTRUE(produits)) {
        pool_bo <- pool_bo * decroit[[1]]
        pool_bi <- pool_bi * decroit[[2]]
      }
      if (!is.null(regles) && (k * pas_a) %% regles$rotation_ans == 0 && k < n_pas) {
        coh$.id <- seq_len(nrow(coh))
        coupe <- .itin_couper(coh, regles, n_sites, sp)
        apres <- .itin_etat(coupe, n_sites, sp, tarif)
        prel[, k + 1L] <- etat$g - apres$g
        vprel[, k + 1L] <- etat$v - apres$v
        cprel[, k + 1L] <- etat$c - apres$c
        if (isTRUE(produits)) {
          reste <- numeric(nrow(coh)); reste[coupe$.id] <- coupe$trees
          fl <- .itin_flux_produits(coh, coh$trees - reste, tarif, filiere, grp_mat, res_mat,
                                    bi_mat, n_sites, sp)
          # carbone des produits (tC/ha) : masse anhydre x fraction de carbone,
          # tige seule (pas de BEF : FINN ne porte pas le houppier)
          pool_bo <- pool_bo + filiere$rendement[["bo"]] * fl$m_bo * fraction_carbone
          pool_bi <- pool_bi + filiere$rendement[["bi"]] * fl$m_bi * fraction_carbone
          subst[, k + 1L] <- filiere$substitution_materiau *
            (filiere$rendement[["bo"]] * fl$v_bo + filiere$rendement[["bi"]] * fl$v_bi) +
            filiere$substitution_energie * fl$m_be
          vbo[, k + 1L] <- fl$v_bo
        }
        coupe$.id <- NULL
        coh <- coupe
      }
      if (isTRUE(produits)) cprod[, k + 1L] <- pool_bo + pool_bi
    }
    list(g = g, tiges = tiges, prel = prel, vol = vol, vprel = vprel, carb = carb, cprel = cprel,
         cprod = cprod, subst = subst, vbo = vbo, vmort = vmort, bmort = bmort, tgb = tgb)
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
  if (isTRUE(volume)) {
    out <- rbind(out, long(moy("vol"), "volume"), long(moy("vprel"), "volume_preleve"))
  }
  if (isTRUE(carbone)) {
    # tC/ha = V (m3/ha) x infradensite (t/m3) x BEF x fraction de carbone
    k_c <- bef * fraction_carbone
    out <- rbind(out, long(moy("carb") * k_c, "carbone"), long(moy("cprel") * k_c, "carbone_preleve"))
  }
  if (isTRUE(produits)) {
    out <- rbind(out, long(moy("cprod"), "carbone_produits"),
                 long(moy("carb") * k_c + moy("cprod"), "carbone_total"),
                 long(moy("subst"), "substitution"), long(moy("vbo"), "volume_preleve_bo"))
  }
  if (isTRUE(biodiversite)) {
    out <- rbind(out, long(moy("vmort"), "volume_mort"), long(moy("bmort"), "bois_mort"),
                 long(moy("tgb"), "tiges_tgb"))
  }
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
    out <- out[order(match(out$variable, c("g", "tiges", "g_prelevee", "volume", "volume_preleve",
                                            "carbone", "carbone_preleve", "carbone_produits",
                                            "carbone_total", "substitution",
                                            "volume_preleve_bo", "volume_mort", "bois_mort",
                                            "tiges_tgb")),
                      out$annee, out$unite), ]
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
  # libre evolution, ilot de senescence : aucune coupe, la dynamique de FINN
  # seule, sous le code de l'itineraire
  if (isTRUE(r$aucune_coupe)) {
    autres <- c("rotation_ans", "diametre_exploitabilite_cm", "surface_terriere_cible_m2ha",
                "intensite_prelevement_pct", "norme_g_selon_dg", "rapport_g_tiges")
    donnees <- autres[!vapply(r[autres], is.null, TRUE)]
    if (length(donnees)) {
      cli::cli_abort(c(
        "Itinerary {.val {itineraire$code}} sets {.field aucune_coupe} and cutting rules: {.field {donnees}}.",
        "i" = "An itinerary without cuts carries no other rule."
      ))
    }
    return(NULL)
  }
  regles <- list(
    rotation_ans = num(r$rotation_ans),
    diametre = num(r$diametre_exploitabilite_cm),
    cible = num(r$surface_terriere_cible_m2ha),
    intensite = num(r$intensite_prelevement_pct),
    norme = .itin_norme(r$norme_g_selon_dg, itineraire$code),
    rapport = num(r$rapport_g_tiges)
  )
  if (!is.null(regles$cible) && !is.null(regles$norme)) {
    cli::cli_abort(c(
      "Itinerary {.val {itineraire$code}} gives both {.field surface_terriere_cible_m2ha} and {.field norme_g_selon_dg}.",
      "i" = "Keep one target: a constant basal area or a norm by mean diameter."
    ))
  }
  if (is.null(regles$diametre) && is.null(regles$cible) && is.null(regles$intensite) &&
      is.null(regles$norme)) {
    cli::cli_abort("Itinerary {.val {itineraire$code}} has no cutting rule to apply.")
  }
  if (is.null(regles$rotation_ans)) {
    cli::cli_abort("Itinerary {.val {itineraire$code}} has no {.field rotation_ans}.")
  }
  .itin_nombre_pas(regles$rotation_ans, pas_a, "rotation_ans")
  if (!is.null(regles$rapport)) {
    if (length(regles$rapport) != 1L || !is.finite(regles$rapport) || regles$rapport <= 0 ||
        regles$rapport > 3) {
      cli::cli_abort("Itinerary {.val {itineraire$code}}: {.field rapport_g_tiges} must be one number in (0, 3].")
    }
    if (is.null(regles$cible) && is.null(regles$intensite) && is.null(regles$norme)) {
      cli::cli_abort("Itinerary {.val {itineraire$code}} sets {.field rapport_g_tiges} without a thinning rule.")
    }
  }
  if (!is.null(regles$intensite) && (regles$intensite <= 0 || regles$intensite > 100)) {
    cli::cli_abort("{.field intensite_prelevement_pct} must be in (0, 100].")
  }
  regles
}

# Norme d'eclaircie par diametre quadratique moyen (spec 065, D-10) : table
# Dg (cm) -> G apres eclaircie (m2/ha), tiree des referentiels des guides
# (N et G apres eclaircie en fonction de Ho, convertis en Dg).
.itin_norme <- function(n, code) {
  if (is.null(n)) return(NULL)
  dg <- suppressWarnings(as.numeric(unlist(n$dg_cm)))
  g <- suppressWarnings(as.numeric(unlist(n$g_m2ha)))
  if (length(dg) < 2L || length(dg) != length(g) || anyNA(dg) || anyNA(g) ||
      any(diff(dg) <= 0) || any(g <= 0)) {
    cli::cli_abort(c(
      "Itinerary {.val {code}}: {.field norme_g_selon_dg} is malformed.",
      "i" = "It needs {.field dg_cm} (at least 2, increasing) and {.field g_m2ha} (positive), of the same length."
    ))
  }
  list(dg = dg, g = g)
}

# G cible par site selon la norme : pas d'eclaircie sous le premier Dg de la
# table (le guide n'eclaircit pas avant), derniere valeur au-dela.
.itin_cible_norme <- function(norme, g, tiges) {
  dg <- ifelse(tiges > 0, 100 * sqrt(4 * g / (pi * tiges)), NA_real_)
  cible <- stats::approx(norme$dg, norme$g, xout = dg, rule = 2)$y
  cible[is.na(dg) | dg < min(norme$dg)] <- Inf
  cible
}

# G (m2/ha), tiges/ha et volume (m3/ha, si tarif) par site depuis une table de
# cohortes.
.itin_etat <- function(coh, n_sites, sp, tarif = NULL) {
  f <- factor(coh$siteID, levels = seq_len(n_sites))
  vide <- !seq_len(n_sites) %in% coh$siteID
  som <- function(x) {
    v <- as.numeric(tapply(x, f, sum))
    v[vide] <- 0
    v
  }
  out <- list(g = som(coh$trees * .g_arbre(coh$dbh)) / sp, tiges = som(coh$trees) / sp,
              v = 0, c = 0)
  if (!is.null(tarif) && nrow(coh)) {
    ij <- cbind(coh$siteID, coh$species)
    vu <- volume_tarif_schaeffer(tarif$numero[ij], coh$dbh, tarif$type[ij])
    vu[coh$dbh < 7.5] <- 0
    out$v <- som(coh$trees * vu) / sp
    # masse anhydre de bois fort (t/ha) : volume x infradensite (g/cm3 = t/m3)
    if (!is.null(tarif$rho)) out$c <- som(coh$trees * vu * tarif$rho[ij]) / sp
  }
  out
}

# Tarif Schaeffer (numero, type conseille) par site x essence FINN. "other" :
# essence "other" dominante (G initiale) de la placette, sinon de l'ensemble.
.itin_tarifs <- function(arbres, environnement, prep, essences) {
  environnement <- as.data.frame(environnement)
  ser <- if ("ser" %in% names(environnement)) {
    as.character(environnement$ser)[match(prep$sites$placette,
                                          as.character(environnement$placette))]
  } else rep(NA_character_, nrow(prep$sites))
  a <- as.data.frame(arbres)
  a <- a[a$statut %in% c("vivant", "mort") & is.finite(a$d1) & is.finite(a$poids) &
           as.character(a$placette) %in% prep$sites$placette, , drop = FALSE]
  a$g <- a$poids * .g_arbre(a$d1)
  autres <- a[!as.character(a$essence) %in% setdiff(essences, "other"), , drop = FALSE]
  # essence dominante en G parmi celles qui ont un tarif (au moins France)
  a_tarif <- function(e) !is.na(ifn_tarif_schaeffer_reference(e)$type_conseille[1])
  avec <- Filter(a_tarif, unique(as.character(a$essence)))
  dominante <- function(x) {
    x <- x[as.character(x$essence) %in% avec, , drop = FALSE]
    if (!nrow(x)) return(NA_character_)
    g <- tapply(x$g, as.character(x$essence), sum)
    names(g)[which.max(g)]
  }
  # sans aucune essence "other" au depart, ses recrues prennent le tarif de
  # l'essence dominante de l'ensemble
  autre_global <- dominante(autres)
  if (is.na(autre_global)) autre_global <- dominante(a)
  autre_site <- vapply(prep$sites$placette, function(p) {
    dominante(autres[as.character(autres$placette) == p, , drop = FALSE])
  }, character(1))
  autre_site[is.na(autre_site)] <- autre_global
  n_s <- nrow(prep$sites); n_sp <- length(essences)
  espar <- matrix(rep(essences, each = n_s), n_s, n_sp)
  espar[, essences == "other"] <- autre_site
  cache <- new.env()
  un_tarif <- function(e, s) {
    cle <- paste(e, s)
    if (is.null(cache[[cle]])) {
      r <- if (is.na(e)) NULL else
        ifn_tarif_schaeffer_reference(e, ser = if (is.na(s)) NULL else s)
      cache[[cle]] <- if (is.null(r) || is.na(r$type_conseille[1])) c(NA, NA) else
        c(r$numero[r$type == r$type_conseille[1]], r$type_conseille[1])
    }
    cache[[cle]]
  }
  numero <- matrix(NA_real_, n_s, n_sp); type <- matrix("SCHL", n_s, n_sp)
  for (i in seq_len(n_s)) for (j in seq_len(n_sp)) {
    t <- un_tarif(espar[i, j], ser[i])
    numero[i, j] <- as.numeric(t[1]); if (!is.na(t[2])) type[i, j] <- t[2]
  }
  manque <- setdiff(unique(espar[is.na(numero)]), NA)
  if (length(manque)) {
    cli::cli_warn(c(
      "No IFN Schaeffer tariff for species {.val {manque}}: volume is {.val NA} where they grow.",
      "i" = "Check the species codes of {.arg arbres} (IFN ESPAR)."
    ))
  }
  # infradensite de l'essence (celle du tarif pour "other"), repli
  # feuillus / resineux dans infradensite_espar()
  rho <- matrix(infradensite_espar(as.vector(espar))$infradensite_g_cm3, n_s, n_sp)
  list(numero = numero, type = type, rho = rho, espar = espar)
}

# Flux d'une coupe vers la filiere, par site : volumes (m3/ha) et masses
# anhydres (t/ha) de bois d'oeuvre, d'industrie et d'energie, depuis les
# tiges coupees `n_coupe` de chaque cohorte (volume bois fort tige du tarif).
.itin_flux_produits <- function(coh, n_coupe, tarif, filiere, grp_mat, res_mat, bi_mat,
                                n_sites, sp) {
  zero <- numeric(n_sites)
  out <- list(v_bo = zero, v_bi = zero, v_be = zero, m_bo = zero, m_bi = zero, m_be = zero)
  i <- which(n_coupe > 0)
  if (!length(i)) return(out)
  ij <- cbind(coh$siteID[i], coh$species[i])
  vu <- volume_tarif_schaeffer(tarif$numero[ij], coh$dbh[i], tarif$type[ij])
  vu[coh$dbh[i] < 7.5 | !is.finite(vu)] <- 0
  v <- n_coupe[i] * vu / sp
  tau <- .filiere_taux(filiere$taux_bo, grp_mat[ij], coh$dbh[i], res_mat[ij])
  rho <- tarif$rho[ij]; rho[!is.finite(rho)] <- 0
  bi <- bi_mat[ij]
  f <- factor(coh$siteID[i], levels = seq_len(n_sites))
  som <- function(x) { r <- as.numeric(tapply(x, f, sum)); r[is.na(r)] <- 0; r }
  parts <- list(bo = tau, bi = (1 - tau) * bi, be = (1 - tau) * (1 - bi))
  for (u in names(parts)) {
    out[[paste0("v_", u)]] <- som(v * parts[[u]])
    out[[paste0("m_", u)]] <- som(v * parts[[u]] * rho)
  }
  out
}

# Tiges vivantes/ha d'au moins `seuil` cm par site.
.itin_tiges_tgb <- function(coh, n_sites, sp, seuil) {
  out <- numeric(n_sites)
  i <- which(coh$dbh >= seuil & coh$trees > 0)
  if (length(i)) {
    s <- tapply(coh$trees[i], factor(coh$siteID[i], levels = seq_len(n_sites)), sum)
    s[is.na(s)] <- 0
    out <- as.numeric(s) / sp
  }
  out
}

# Volume bois fort tige (m3/ha) des tiges mortes pendant un pas, par site,
# separe feuillus / resineux ; `morts` : liste de tables de cohortes (FINN,
# auto-eclaircie). Tiges < 7,5 cm sans volume, comme `volume`.
.itin_volume_morts <- function(morts, tarif, res_mat, n_sites, sp) {
  out <- list(feuillus = numeric(n_sites), resineux = numeric(n_sites))
  morts <- do.call(rbind, Filter(function(x) !is.null(x) && nrow(x), morts))
  if (is.null(morts) || !nrow(morts)) return(out)
  ij <- cbind(morts$siteID, morts$species)
  vu <- volume_tarif_schaeffer(tarif$numero[ij], morts$dbh, tarif$type[ij])
  vu[morts$dbh < 7.5 | !is.finite(vu)] <- 0
  v <- morts$trees * vu / sp
  res <- res_mat[ij]; res[is.na(res)] <- FALSE
  f <- factor(morts$siteID, levels = seq_len(n_sites))
  som <- function(x) { r <- as.numeric(tapply(x, f, sum)); r[is.na(r)] <- 0; r }
  out$feuillus <- som(v * !res)
  out$resineux <- som(v * res)
  out
}

# Coupe entre deux pas : exploitabilite puis eclaircie, tiges tirees.
.itin_couper <- function(coh, regles, n_sites, sp) {
  if (!nrow(coh)) return(coh)
  if (!is.null(regles$diametre)) {
    coh$trees[coh$dbh >= regles$diametre] <- 0
  }
  p <- NULL
  etat <- .itin_etat(coh, n_sites, sp)
  g <- etat$g
  cible <- if (!is.null(regles$norme)) {
    .itin_cible_norme(regles$norme, g, etat$tiges)
  } else regles$cible
  if (!is.null(cible)) {
    p <- ifelse(g > cible & g > 0, (g - cible) / g, 0)
    if (!is.null(regles$intensite)) p <- pmin(p, regles$intensite / 100)
  } else if (!is.null(regles$intensite)) {
    p <- rep(regles$intensite / 100, n_sites)
  }
  if (!is.null(p)) {
    if (is.null(regles$rapport) || regles$rapport == 1) {
      ps <- p[coh$siteID]
    } else {
      ps <- numeric(nrow(coh))
      g_i <- .g_arbre(coh$dbh)
      for (s in which(p > 0)) {
        i <- which(coh$siteID == s)
        if (length(i)) ps[i] <- .itin_probas_rapport(coh$trees[i], g_i[i], p[s], regles$rapport)
      }
    }
    coh$trees <- stats::rbinom(nrow(coh), size = as.integer(coh$trees), prob = 1 - ps)
  }
  coh[coh$trees > 0, , drop = FALSE]
}

# Probabilites de coupe par cohorte d'un site pour une eclaircie qui enleve
# la part `p` de G avec le rapport `r` (part de G / part des tiges) :
# q = min(1, c (g / g moyen)^b), c pour la part de G, b pour le rapport. Si
# les grosseurs presentes ne permettent pas d'atteindre r, b reste a la borne.
.itin_probas_rapport <- function(n, g, p, r) {
  if (p >= 1) return(rep(1, length(n)))
  tot_g <- sum(n * g); tot_n <- sum(n)
  if (tot_g <= 0 || tot_n <= 0) return(rep(0, length(n)))
  x <- g / (tot_g / tot_n)
  q_de <- function(b) {
    xb <- x^b
    f <- function(lc) sum(n * g * pmin(1, exp(lc) * xb)) / tot_g - p
    lc <- stats::uniroot(f, c(-200, 200), tol = 1e-10)$root
    pmin(1, exp(lc) * xb)
  }
  cible_n <- min(1, p / r)
  h <- function(b) sum(n * q_de(b)) / tot_n - cible_n
  if (h(-8) <= 0) return(q_de(-8))
  if (h(8) >= 0) return(q_de(8))
  q_de(stats::uniroot(h, c(-8, 8), tol = 1e-6)$root)
}

# Plafonds par groupe FINN (indice dans calibration$essences) depuis la table
# de densite_max : rdi (obligatoire) et g (colonne g_max, facultative) ;
# "other" et les essences absentes prennent la ligne "toutes".
.itin_rdi_max <- function(densite_max, essences) {
  if (is.null(densite_max)) return(NULL)
  densite_max <- as.data.frame(densite_max)
  manq <- setdiff(c("essence", "rdi_max"), names(densite_max))
  if (length(manq)) cli::cli_abort("{.arg densite_max} lacks {.field {manq}}.")
  e <- as.character(densite_max$essence)
  if (!"toutes" %in% e) {
    cli::cli_abort("{.arg densite_max} needs a row {.code essence = \"toutes\"} for the other species.")
  }
  par_groupe <- function(v) {
    if (anyNA(v) || any(v <= 0)) cli::cli_abort("The ceilings of {.arg densite_max} must be positive.")
    out <- v[match(essences, e)]
    out[is.na(out) | essences == "other"] <- v[e == "toutes"][1]
    out
  }
  list(rdi = par_groupe(as.numeric(densite_max$rdi_max)),
       g = if ("g_max" %in% names(densite_max)) par_groupe(as.numeric(densite_max$g_max)) else NULL)
}

# Auto-eclaircie : un site au-dessus d'un plafond de son essence dominante (G)
# perd ses plus petites tiges jusqu'a revenir sous les plafonds. RDI additif
# (Reineke 1933, forme sommee) : somme des tiges/ha x (d / 25)^1,605 ; G en
# m2/ha, plafond facultatif qui tient lieu de la courbure de la limite chez
# les gros bois (Charru et al. 2012).
.itin_auto_eclaircie <- function(coh, plafonds, n_sites, sp) {
  if (!nrow(coh)) return(coh)
  avant <- coh$trees
  r_i <- (coh$dbh / 25)^1.605 / sp
  gt_i <- .g_arbre(coh$dbh) / sp
  for (s in unique(coh$siteID)) {
    i <- which(coh$siteID == s)
    gs <- tapply(coh$trees[i] * gt_i[i], coh$species[i], sum)
    k <- as.integer(names(gs)[which.max(gs)])
    # chaque plafond : contribution par tige, plafond ; tolerance flottante
    crit <- list(list(u = r_i, max = plafonds$rdi[k]))
    if (!is.null(plafonds$g)) crit[[2]] <- list(u = gt_i, max = plafonds$g[k])
    for (cr in crit) {
      tol <- 1e-9 * cr$max
      exces <- sum(coh$trees[i] * cr$u[i]) - cr$max
      if (exces <= tol) next
      for (j in i[order(coh$dbh[i])]) {
        if (exces <= tol) break
        n_ote <- min(coh$trees[j], ceiling(exces / cr$u[j] - 1e-9))
        coh$trees[j] <- coh$trees[j] - n_ote
        exces <- exces - n_ote * cr$u[j]
      }
    }
  }
  # tiges retirees (mortalite naturelle, au diametre de fin de pas)
  morts <- coh
  morts$trees <- avant - coh$trees
  out <- coh[coh$trees > 0, , drop = FALSE]
  attr(out, "morts") <- morts[morts$trees > 0, , drop = FALSE]
  out
}

# Un pas FINN depuis une table de cohortes (siteID, species, dbh, trees).
# Attribut "morts" : tiges mortes pendant le pas par cohorte d'entree (siteID,
# species, dbh d'entree, trees). FINN 0.1.0 garde l'identite des cohortes : la
# cohorte de rang k d'un site s (S sites) ressort avec cohortID = (k - 1) S + s,
# les recrues au-dela (data-raw/diagnostic_finn_processus.R) ; une cohorte
# absente de la sortie est morte.
# Par paquets de `paquet` sites : le cout d'un appel FINN croit plus vite que
# le nombre de sites (2 479 placettes en un appel : 46 min ; 780 par paquets
# de 250 : 1,7 min, data-raw/diagnostic_biais_croissance.R). Les sites d'un
# paquet sont renumerotes 1..n, puis decales au retour.
.itin_un_pas <- function(m, coh, env1, sp, n_sp, paquet = 250L) {
  n_sites <- nrow(env1)
  if (n_sites <= paquet) return(.itin_un_pas_bloc(m, coh, env1, sp, n_sp))
  debuts <- seq(1L, n_sites, by = paquet)
  res <- lapply(debuts, function(d) {
    f <- min(n_sites, d + paquet - 1L)
    e <- env1[env1$siteID >= d & env1$siteID <= f, , drop = FALSE]
    e$siteID <- e$siteID - (d - 1L)
    ci <- coh[coh$siteID >= d & coh$siteID <= f, , drop = FALSE]
    ci$siteID <- ci$siteID - (d - 1L)
    r <- .itin_un_pas_bloc(m, ci, e, sp, n_sp)
    mo <- attr(r, "morts")
    d0 <- attr(r, "dbh_entree")
    r$siteID <- r$siteID + (d - 1L)
    mo$siteID <- mo$siteID + (d - 1L)
    list(out = r, morts = mo, dbh0 = d0)
  })
  out <- do.call(rbind, lapply(res, `[[`, "out"))
  attr(out, "morts") <- do.call(rbind, lapply(res, `[[`, "morts"))
  d0 <- lapply(res, `[[`, "dbh0")
  if (!any(vapply(d0, is.null, logical(1)))) attr(out, "dbh_entree") <- unlist(d0)
  rownames(out) <- NULL
  out
}

.itin_un_pas_bloc <- function(m, coh, env1, sp, n_sp) {
  dt <- data.table::as.data.table
  vide_df <- data.frame(siteID = integer(), species = integer(), dbh = numeric(),
                        trees = numeric())
  coh <- coh[coh$trees > 0, , drop = FALSE]
  n_sites <- nrow(env1)
  # un site sans tige (coupe rase) : FINN renumerote les sites et echoue ; une
  # cohorte vide le garde dans la grille (il peut recevoir des recrues)
  vides <- setdiff(seq_len(n_sites), coh$siteID)
  entree <- rbind(coh, data.frame(siteID = vides, species = rep(1L, length(vides)),
                                  dbh = rep(1, length(vides)), trees = rep(0, length(vides))))
  entree <- entree[order(entree$siteID), , drop = FALSE]
  init <- FINN::makeInitCohorts(dt(data.frame(siteID = entree$siteID, patchID = 1L,
                                              species = entree$species, dbh = entree$dbh,
                                              trees = entree$trees)), Nspecies = n_sp)
  sim <- stats::predict(m, env = dt(env1), init_cohort = init, patches = 1L,
                        patch_size = sp, device = "cpu", return_cohorts = "last")
  l <- as.data.frame(sim$long$cohort)
  l <- l[l$variable %in% c("trees", "dbh"), , drop = FALSE]
  cle <- paste(l$siteID, l$patchID, l$cohortID)
  n <- l[l$variable == "trees", , drop = FALSE]
  d <- l[l$variable == "dbh", , drop = FALSE]
  out <- data.frame(siteID = n$siteID, species = n$species,
                    dbh = d$value[match(cle[l$variable == "trees"], cle[l$variable == "dbh"])],
                    trees = n$value)
  # mortalite par cohorte d'entree
  rang <- stats::ave(seq_len(nrow(entree)), entree$siteID, FUN = seq_along)
  id_entree <- (rang - 1L) * n_sites + entree$siteID
  t1 <- n$value[match(paste(entree$siteID, id_entree), paste(n$siteID, n$cohortID))]
  t1[!is.finite(t1)] <- 0
  morts <- entree
  morts$trees <- pmax(0, entree$trees - t1)
  morts <- morts[morts$trees > 0, , drop = FALSE]
  # diametre d'entree des survivants (NA : recrue), pour la correction
  k <- match(paste(n$siteID, n$cohortID), paste(entree$siteID, id_entree))
  dbh0 <- entree$dbh[k]
  if (nrow(out)) {
    garde <- is.finite(out$trees) & out$trees > 0
    out <- out[garde, , drop = FALSE]
    dbh0 <- dbh0[garde]
  } else {
    out <- vide_df
    dbh0 <- numeric()
  }
  attr(out, "morts") <- morts
  attr(out, "dbh_entree") <- dbh0
  out
}

# Un pas FINN puis, si `correction` (corriger_finn()) n'est pas NULL, la
# correction de l'accroissement en diametre des survivants : dbh0 + f x
# (dbh1 - dbh0), f par classe de G du site au debut du pas x groupe
# (feuillus, resineux) de l'essence. Les recrues ne sont pas corrigees.
.itin_pas_corrige <- function(m, coh, env1, sp, n_sp, correction = NULL) {
  if (is.null(correction)) return(.itin_un_pas(m, coh, env1, sp, n_sp))
  g0 <- .itin_etat(coh[coh$trees > 0, , drop = FALSE], nrow(env1), sp)$g
  out <- .itin_un_pas(m, coh, env1, sp, n_sp)
  .itin_corriger(out, g0, correction)
}

.itin_corriger <- function(out, g0, correction) {
  dbh0 <- attr(out, "dbh_entree")
  if (is.null(dbh0) || !nrow(out)) return(out)
  i <- which(is.finite(dbh0))
  if (!length(i)) return(out)
  cl <- findInterval(g0[out$siteID[i]], correction$bornes, rightmost.closed = TRUE)
  cl <- pmin(pmax(cl, 1L), nrow(correction$facteurs))
  grp <- 1L + as.integer(correction$resineux[out$species[i]])
  f <- correction$facteurs[cbind(cl, grp)]
  out$dbh[i] <- pmax(dbh0[i], dbh0[i] + f * (out$dbh[i] - dbh0[i]))
  out
}
