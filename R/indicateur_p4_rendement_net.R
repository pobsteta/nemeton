# P4 -- rendement net du risque (spec 072, M1 et M3). Les parametres sont dans R/p4_parametres.R.

# --- Entrees ---------------------------------------------------------------

# Colonnes `_norm` d'un aleat : liste des colonnes lues, vecteur 0-100 par
# ligne (min des colonnes presentes), NA si aucune valeur.
.p4_score_alea <- function(units, codes) {
  cols <- paste0(codes, "_norm")
  # Garde contre la colonne brute (haut = risque) : refus net
  brutes <- codes[!cols %in% names(units) & codes %in% names(units)]
  # R5 est optionnel (min seulement s'il est present) : on ne garde que le 1er code obligatoire
  brutes <- intersect(brutes, codes[1L])
  if (length(brutes)) {
    cli::cli_abort(c(
      "Column {.field {brutes}} found without {.field {paste0(brutes, '_norm')}}.",
      "i" = "Raw R scores are 'high = risk'; P4 only reads the normalised 'high = good' columns (spec 048)."
    ), class = "nemeton_p4_colonne_brute")
  }
  if (!cols[1L] %in% names(units)) return(NULL)
  m <- vapply(intersect(cols, names(units)), function(cl) as.numeric(units[[cl]]), numeric(nrow(units)))
  m <- matrix(m, nrow = nrow(units))
  out <- suppressWarnings(apply(m, 1L, function(r) if (all(is.na(r))) NA_real_ else min(r, na.rm = TRUE)))
  # R obligatoire manquant (NA) => NA meme si R5 est la
  out[is.na(m[, 1L])] <- NA_real_
  out
}

.p4_dommages <- function(units, p) {
  d <- lapply(.P4_ALEAS, function(a) {
    x <- p$aleas[[a]]
    s <- .p4_score_alea(units, unlist(x$score))
    if (is.null(s)) rep(NA_real_, nrow(units)) else x$part_perdue * (1 - s / 100)
  })
  names(d) <- .P4_ALEAS
  as.data.frame(d)
}

.p4_surface <- function(units, surface_field) {
  if (surface_field %in% names(units)) return(as.numeric(units[[surface_field]]))
  if (inherits(units, "sf")) return(as.numeric(sf::st_area(units)) / 1e4)
  cli::cli_abort("Column {.field {surface_field}} (hectares) is required.",
                 class = "nemeton_p4_surface_absente")
}

# Prix par essence -> vecteur par ligne (NA si absent)
.p4_prix <- function(units, species_field, p) {
  par <- unlist(p$prix$par_essence)
  if (is.null(par) || !species_field %in% names(units)) return(rep(NA_real_, nrow(units)))
  unname(par[as.character(units[[species_field]])])
}

# --- Indicateur ------------------------------------------------------------

#' P4 - net yield after hazards (spec 072)
#'
#' Computes, per management unit (UGF), the yearly yield of the standing
#' capital net of the expected losses due to hazards, and compares it with the
#' yield required by the unit's vocation. It is a **source-conditional**
#' indicator of family P (like B4, R5, T3): without a `vocation` column, or
#' without capital and gain (given, or computable from `P1`, `P2` and the
#' prices of the parameter file), it returns `NA` with
#' `p4_status = "skipped_no_p4_source"` and existing projects keep their
#' family P score unchanged.
#'
#' ```
#' rendement_brut   = gain_valeur / capital
#' perte_i          = p_max_i * (1 - Ri_norm / 100) * part_perdue_i
#' pertes_attendues = perte_saisie, or sum(perte_i)
#' rendement_net    = rendement_brut - pertes_attendues
#' ecart            = rendement_net - taux_exige[vocation]
#' ```
#'
#' The R scores are read in their **normalised** form (`R1_norm` ... `R4_norm`,
#' 0-100, high = good, spec 048). A raw column `R1` without `R1_norm` is
#' refused (class `nemeton_p4_colonne_brute`). The drought and health hazard
#' reads `min(R3_norm, R5_norm)` when `R5_norm` is present.
#'
#' @param units Data frame or `sf` of management units.
#' @param layers Ignored (dispatcher compatibility).
#' @param vocation_field Name of the declared vocation column.
#' @param capital_field,gain_field Columns holding the capital (EUR/ha) and the
#'   yearly value gain (EUR/ha/yr). When absent, computed from `P1` and `P2`
#'   with the prices of `parametres` (`p4_capital_gain` rules: no price gives
#'   `NA` and a warning; a `P2` that is a site index in metres is refused).
#' @param perte_saisie_field Optional column of entered expected loss
#'   (proportion/yr); replaces the computed losses.
#' @param species_field Species column used to look prices up.
#' @param parametres Parameter list; default [p4_parametres()].
#' @param ndp Numeric vector, NDP of each input (the weakest is inherited);
#'   a `ndp` column of `units` is also honoured. Unknown means signal only.
#'
#' @return `units` with `P4`, `P4_norm`, `p4_rendement_brut`,
#'   `p4_perte_<alea>`, `p4_pertes_attendues`, `p4_rendement_geometrique`,
#'   `p4_taux_exige`, `p4_ecart`, `p4_decision`, `p4_alea_dominant`,
#'   `p4_signal_seulement`, `p4_ndp` and `p4_status`.
#'
#' @section Lifecycle:
#' Experimental: all economic parameters are provisional (spec 072).
#'
#' @examples
#' u <- data.frame(vocation = "production", capital = 14000, gain_valeur = 750,
#'                 R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
#' indicateur_p4_rendement_net(u)$P4
#' @md
#' @export
indicateur_p4_rendement_net <- function(units,
                                        layers = NULL,
                                        vocation_field = "vocation",
                                        capital_field = "capital",
                                        gain_field = "gain_valeur",
                                        perte_saisie_field = "perte_saisie",
                                        species_field = "species",
                                        parametres = NULL,
                                        ndp = NULL) {
  p <- .p4_params(parametres)
  n <- nrow(units)
  na <- rep(NA_real_, n)

  cols_sortie <- c("P4", "P4_norm", "p4_rendement_brut",
                   paste0("p4_perte_", .P4_ALEAS), "p4_pertes_attendues",
                   "p4_rendement_geometrique", "p4_taux_exige", "p4_ecart")
  vide <- function(statut) {
    for (cl in cols_sortie) units[[cl]] <- na
    units$p4_decision <- NA_character_
    units$p4_alea_dominant <- NA_character_
    units$p4_signal_seulement <- NA
    units$p4_ndp <- NA_real_
    units$p4_status <- statut
    units
  }

  # Source absente : indicateur conditionnel, pas d'erreur
  if (!vocation_field %in% names(units)) return(vide("skipped_no_p4_source"))

  # Capital et gain : fournis, ou calcules depuis P1, P2 et les prix (M3)
  fournis <- capital_field %in% names(units) && gain_field %in% names(units)
  if (fournis) {
    capital <- as.numeric(units[[capital_field]])
    gain <- as.numeric(units[[gain_field]])
  } else if (all(c("P1", "P2") %in% names(units))) {
    cg <- .p4_capital_gain(units, species_field, p)
    capital <- cg$capital
    gain <- cg$gain
  } else {
    return(vide("skipped_no_p4_source"))
  }

  # Vocation : inconnue du fichier => erreur explicite
  voc <- as.character(units[[vocation_field]])
  inconnue <- setdiff(unique(voc[!is.na(voc)]), names(p$vocations))
  if (length(inconnue)) {
    cli::cli_abort(c("Unknown vocation {.val {inconnue}}.",
                     "i" = "Known: {.val {names(p$vocations)}}."),
                   class = "nemeton_p4_vocation_inconnue")
  }
  taux <- vapply(voc, function(v) if (is.na(v)) NA_real_ else p$vocations[[v]]$taux_exige, numeric(1))
  lecture <- vapply(voc, function(v) if (is.na(v)) NA_character_ else p$vocations[[v]]$si_ecart_negatif, character(1))

  # Capital nul ou manquant
  mauvais <- is.na(capital) | capital <= 0
  if (any(mauvais)) {
    cli::cli_warn("{sum(mauvais)} unit(s) with a missing, zero or negative capital: P4 set to {.val NA}.",
                  class = "nemeton_p4_capital_invalide")
  }
  capital[mauvais] <- NA_real_
  brut <- gain / capital

  saisie <- if (perte_saisie_field %in% names(units)) as.numeric(units[[perte_saisie_field]]) else na
  utilise_saisie <- !is.na(saisie)

  # Perte par aleat
  pertes <- lapply(.P4_ALEAS, function(a) {
    x <- p$aleas[[a]]
    s <- if (all(utilise_saisie)) na else .p4_score_alea(units, unlist(x$score))
    if (is.null(s)) na else x$p_max * (1 - s / 100) * x$part_perdue
  })
  names(pertes) <- .P4_ALEAS
  pm <- do.call(cbind, pertes)
  pm[utilise_saisie, ] <- NA_real_
  attendues <- ifelse(utilise_saisie, saisie, rowSums(pm))
  manque_r <- !utilise_saisie & is.na(attendues) & !is.na(capital)
  if (any(manque_r)) {
    cli::cli_warn("{sum(manque_r)} unit(s) without normalised R scores and without {.field {perte_saisie_field}}: P4 set to {.val NA}.",
                  class = "nemeton_p4_score_manquant")
  }

  net <- brut - attendues
  ecart <- net - taux
  seuil <- p$seuil_decision
  decision <- ifelse(is.na(ecart), NA_character_,
              ifelse(ecart > seuil, "capitaliser",
              ifelse(ecart >= -seuil, "equilibre", lecture)))

  # Rendement geometrique (7 bis) : seulement si les dommages sont calculables
  dom <- .p4_dommages(units, p)
  pmax_a <- vapply(.P4_ALEAS, function(a) p$aleas[[a]]$p_max, numeric(1))
  geo <- exp(log(1 + brut) + as.vector(as.matrix(log(1 - dom)) %*% pmax_a)) - 1
  geo[utilise_saisie] <- NA_real_

  dominant <- apply(pm, 1L, function(r) if (all(is.na(r))) NA_character_ else .P4_ALEAS[which.max(r)])

  # NDP et drapeau de precision
  ndp_h <- if (length(ndp) && !anyNA(ndp)) min(ndp) else NA_real_
  col_ndp <- if ("ndp" %in% names(units)) as.numeric(units[["ndp"]]) else rep(NA_real_, n)
  ndp_ligne <- pmin(rep(ndp_h, n), col_ndp, na.rm = TRUE)
  ndp_ligne[is.na(ndp_ligne)] <- NA_real_
  signal <- is.na(ndp_ligne) | ndp_ligne < 3
  if (anyNA(ndp_ligne)) {
    cli::cli_inform("NDP of the P4 inputs unknown: {.field p4_signal_seulement} set to {.val TRUE}.")
  }

  units$P4 <- net
  units$P4_norm <- .p4_norme(net, p$plafond_score)
  units$p4_rendement_brut <- brut
  for (a in .P4_ALEAS) units[[paste0("p4_perte_", a)]] <- unname(pm[, a])
  units$p4_pertes_attendues <- attendues
  units$p4_rendement_geometrique <- geo
  units$p4_taux_exige <- taux
  units$p4_ecart <- ecart
  units$p4_decision <- unname(decision)
  units$p4_alea_dominant <- dominant
  units$p4_signal_seulement <- signal
  units$p4_ndp <- ndp_ligne
  units$p4_status <- ifelse(is.na(net), "na_input", "calculated")
  units
}

.p4_norme <- function(net, plafond) {
  pmin(100, pmax(0, round(100 * net / plafond)))
}

# Capital et gain depuis P1 (m3/ha) et P2 (m3/ha/an) x prix (EUR/m3).
.p4_capital_gain <- function(units, species_field, p) {
  prix <- .p4_prix(units, species_field, p)
  if (anyNA(prix)) {
    cli::cli_warn("No price available for {sum(is.na(prix))} unit(s) ({.field prix$par_essence} of the P4 parameters): capital and gain set to {.val NA}.",
                  class = "nemeton_p4_prix_absent")
  }
  p2_metres <- "p2_status" %in% names(units) & units[["p2_status"]] %in% "indice_station_m"
  if (any(p2_metres)) {
    cli::cli_warn("P2 is a site index in metres for {sum(p2_metres)} unit(s), not a yearly increment: gain set to {.val NA}.",
                  class = "nemeton_p4_p2_indice")
  }
  gain <- as.numeric(units[["P2"]]) * prix
  gain[p2_metres] <- NA_real_
  list(capital = as.numeric(units[["P1"]]) * prix, gain = gain)
}

