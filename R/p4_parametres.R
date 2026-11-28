# P4 -- parametres et validateur (spec 072, M0). P4 est un indicateur conditionnel de la
# famille P : calcule seulement si ses sources (vocation, prix ou capital et
# gain fournis) sont presentes. Les grandeurs de taux sont des proportions/an.

.P4_ALEAS <- c("incendie", "tempete", "secheresse_sanitaire", "abroutissement")
.P4_VOCATIONS <- c("production", "mixte", "protection", "accueil", "naturalite")

# --- Parametres ------------------------------------------------------------

#' Read and validate the P4 parameter file
#'
#' Reads `inst/extdata/p4_parametres.yml` (spec 072, section 5), optionally
#' replaced by a project file and/or patched by a list, then validates it.
#' Every value of the shipped file is provisional (`provisoire: true`).
#'
#' @param fichier Path of a project parameter file, or `NULL` for the shipped
#'   one.
#' @param surcharge Optional named list merged recursively over the file
#'   (project override).
#'
#' @return A validated named list of parameters.
#' @examples
#' p <- p4_parametres()
#' p$vocations$production$taux_exige
#' @md
#' @export
p4_parametres <- function(fichier = NULL, surcharge = NULL) {
  if (is.null(fichier)) {
    fichier <- system.file("extdata", "p4_parametres.yml", package = "nemeton")
  }
  if (!nzchar(fichier) || !file.exists(fichier)) {
    cli::cli_abort("P4 parameter file not found: {.file {fichier}}.",
                   class = "nemeton_p4_parametres_invalides")
  }
  p <- yaml::read_yaml(fichier)
  if (!is.null(surcharge)) p <- .p4_fusionner(p, surcharge)
  p4_valider_parametres(p)
}

.p4_fusionner <- function(base, patch) {
  for (nm in names(patch)) {
    if (is.list(base[[nm]]) && is.list(patch[[nm]]) && !is.null(names(patch[[nm]]))) {
      base[[nm]] <- .p4_fusionner(base[[nm]], patch[[nm]])
    } else {
      base[[nm]] <- patch[[nm]]
    }
  }
  base
}

#' Validate a P4 parameter list
#'
#' Aborts with class `nemeton_p4_parametres_invalides` when a vocation, a
#' hazard or a field is missing, or when a value is out of its domain.
#'
#' @param p Named list, as read by [p4_parametres()].
#' @return `p`, invisibly valid.
#' @examples
#' p4_valider_parametres(p4_parametres())
#' @md
#' @export
p4_valider_parametres <- function(p) {
  err <- character()
  num <- function(x, lo, hi, incl_lo = TRUE, incl_hi = TRUE) {
    is.numeric(x) && length(x) == 1L && !is.na(x) &&
      (if (incl_lo) x >= lo else x > lo) && (if (incl_hi) x <= hi else x < hi)
  }
  if (!is.list(p)) err <- c(err, "parameters must be a list")
  else {
    if (!num(p$plafond_score, 0, 1, FALSE)) err <- c(err, "`plafond_score` must be in ]0, 1]")
    if (!num(p$seuil_decision, 0, 1, TRUE, FALSE)) err <- c(err, "`seuil_decision` must be in [0, 1[")
    if (!(num(p$horizon_ans, 1, Inf) && p$horizon_ans == round(p$horizon_ans)))
      err <- c(err, "`horizon_ans` must be an integer >= 1")
    if (!num(p$plafond_exposition, 0, 1, FALSE)) err <- c(err, "`plafond_exposition` must be in ]0, 1]")
    if (!is.logical(p$provisoire) || length(p$provisoire) != 1L)
      err <- c(err, "`provisoire` must be TRUE or FALSE")
    manq <- setdiff(.P4_ALEAS, names(p$aleas))
    if (length(manq)) err <- c(err, paste0("missing hazard(s): ", paste(manq, collapse = ", ")))
    for (a in intersect(names(p$aleas), .P4_ALEAS)) {
      x <- p$aleas[[a]]
      sc <- unlist(x$score)
      if (!is.character(sc) || !length(sc) || !all(grepl("^R[0-9]+$", sc)))
        err <- c(err, paste0("hazard `", a, "`: `score` must be R-codes such as R1"))
      if (!num(x$p_max, 0, 1)) err <- c(err, paste0("hazard `", a, "`: `p_max` must be in [0, 1]"))
      if (!num(x$part_perdue, 0, 1)) err <- c(err, paste0("hazard `", a, "`: `part_perdue` must be in [0, 1]"))
      if (!(is.character(x$portee) && length(x$portee) == 1L && x$portee %in% c("localisee", "systemique")))
        err <- c(err, paste0("hazard `", a, "`: `portee` must be localisee or systemique"))
    }
    manq <- setdiff(.P4_VOCATIONS, names(p$vocations))
    if (length(manq)) err <- c(err, paste0("missing vocation(s): ", paste(manq, collapse = ", ")))
    for (v in names(p$vocations)) {
      x <- p$vocations[[v]]
      if (!num(x$taux_exige, 0, 1, TRUE, FALSE))
        err <- c(err, paste0("vocation `", v, "`: `taux_exige` must be in [0, 1["))
      if (!(is.character(x$si_ecart_negatif) && length(x$si_ecart_negatif) == 1L &&
            x$si_ecart_negatif %in% c("recolter", "surveiller")))
        err <- c(err, paste0("vocation `", v, "`: `si_ecart_negatif` must be recolter or surveiller"))
    }
    if (!is.list(p$prix)) err <- c(err, "`prix` section is missing")
    else for (e in names(p$prix$par_essence)) {
      if (!num(p$prix$par_essence[[e]], 0, Inf))
        err <- c(err, paste0("price of `", e, "` must be a number >= 0"))
    }
  }
  if (length(err)) {
    cli::cli_abort(c("Invalid P4 parameters.", stats::setNames(err, rep("x", length(err)))),
                   class = "nemeton_p4_parametres_invalides")
  }
  p
}

.p4_params <- function(parametres) {
  if (is.null(parametres)) p4_parametres() else p4_valider_parametres(parametres)
}

# Plafond du score pour la regle de normalisation dediee (fichier par defaut).
.p4_plafond_score <- function() p4_parametres()$plafond_score

