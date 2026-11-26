#' Default weights of the ICD formula
#'
#' The starting weights of the composite discoloration indicator (ICD, spec
#' 071), set by expert judgement in the method note (section 7) and meant to
#' be recalibrated on field observations. One row per species group, one
#' column per index, plus the sensitive months. CRre is nil for conifers.
#'
#' Only the weights are adjustable ([run_icd_decoloration()] argument
#' `poids`); the months and the thresholds stay those of the note.
#'
#' @return A `data.frame` with columns `essence` (`chene`, `hetre`,
#'   `sapin_epicea`, `douglas`), `GRVI`, `CIre`, `CRSWIR`, `CRre`, `NDVI`,
#'   `mois_debut` and `mois_fin`. Each row sums to 1.
#' @seealso [icd_poids_valider()], [run_icd_decoloration()].
#' @export
#' @examples
#' icd_poids_defaut()
icd_poids_defaut <- function() {
  data.frame(
    essence = .ICD_ESSENCES,
    GRVI    = c(0.15, 0.30, 0.35, 0.45),
    CIre    = c(0.25, 0.25, 0.15, 0.15),
    CRSWIR  = c(0.15, 0.15, 0.35, 0.25),
    CRre    = c(0.20, 0.15, 0.00, 0.00),
    NDVI    = c(0.25, 0.15, 0.15, 0.15),
    mois_debut = vapply(.ICD_MOIS, min, integer(1), USE.NAMES = FALSE),
    mois_fin   = vapply(.ICD_MOIS, max, integer(1), USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
}

#' Validate and normalise the ICD weights
#'
#' Checks a weights table (same shape as [icd_poids_defaut()]) and returns
#' the weights actually used. Rules: the four species groups are all present
#' (and no other); the five index columns are numeric, finite and
#' non-negative; CRre is nil for conifers (`sapin_epicea`, `douglas`; the
#' method note uses CRre for broadleaves only); the sum of a row is positive.
#' A row whose sum is not 1 is **rescaled to 1** (decision of Pascal,
#' 2026-11-26) and the function says so. The month columns, if present, are
#' ignored: the months are those of the note.
#'
#' @param poids A `data.frame` as returned by [icd_poids_defaut()].
#' @return A `data.frame` like [icd_poids_defaut()], rows summing to 1, with
#'   attribute `somme_saisie` (named numeric: the sum of each row as given)
#'   and attribute `renormalise` (character: the species groups that were
#'   rescaled, empty if none).
#' @seealso [icd_poids_defaut()], [run_icd_decoloration()].
#' @export
#' @examples
#' p <- icd_poids_defaut()
#' p$GRVI[1] <- 0.30            # row sums to 1.15: rescaled
#' attr(icd_poids_valider(p), "renormalise")
icd_poids_valider <- function(poids = icd_poids_defaut()) {
  if (!is.data.frame(poids)) {
    cli::cli_abort("{.arg poids} must be a data.frame (see {.fn icd_poids_defaut}).")
  }
  manque <- setdiff(c("essence", .ICD_INDICES), names(poids))
  if (length(manque)) {
    cli::cli_abort("{.arg poids} lacks the column{?s} {.val {manque}}.")
  }
  ess <- as.character(poids$essence)
  if (anyDuplicated(ess)) {
    cli::cli_abort("{.arg poids}: duplicated species group {.val {unique(ess[duplicated(ess)])}}.")
  }
  absentes <- setdiff(.ICD_ESSENCES, ess)
  if (length(absentes)) {
    cli::cli_abort("{.arg poids}: missing species group{?s} {.val {absentes}}.")
  }
  inconnues <- setdiff(ess, .ICD_ESSENCES)
  attendues <- .ICD_ESSENCES
  if (length(inconnues)) {
    cli::cli_abort("{.arg poids}: unknown species group(s) {.val {inconnues}} (expected {.val {attendues}}).")
  }
  poids <- poids[match(.ICD_ESSENCES, ess), , drop = FALSE]
  rownames(poids) <- NULL

  m <- matrix(NA_real_, nrow = length(.ICD_ESSENCES), ncol = length(.ICD_INDICES),
              dimnames = list(.ICD_ESSENCES, .ICD_INDICES))
  for (i in .ICD_INDICES) {
    v <- poids[[i]]
    if (!is.numeric(v)) {
      cli::cli_abort("{.arg poids}: column {.field {i}} must be numeric.")
    }
    m[, i] <- v
  }
  # CRre : nul (ou absent) pour les resineux, seule exception a NA.
  res <- .ICD_RESINEUX
  m[res, "CRre"][is.na(m[res, "CRre"])] <- 0
  if (anyNA(m) || any(!is.finite(m))) {
    cli::cli_abort("{.arg poids} must hold finite values, without {.val NA}.")
  }
  if (any(m < 0)) {
    quoi <- rownames(m)[apply(m < 0, 1L, any)]
    cli::cli_abort("{.arg poids}: negative weight for {.val {quoi}}; weights must be >= 0.")
  }
  if (any(m[res, "CRre"] != 0)) {
    quoi <- res[m[res, "CRre"] != 0]
    cli::cli_abort(c(
      "{.arg poids}: CRre must be 0 for conifers ({.val {quoi}}).",
      i = "The method note uses CRre for broadleaves only."))
  }
  somme <- rowSums(m)
  if (any(somme <= 0)) {
    quoi <- rownames(m)[somme <= 0]
    cli::cli_abort("{.arg poids}: the weights of {.val {quoi}} sum to 0.")
  }
  a_ajuster <- abs(somme - 1) > 1e-8
  if (any(a_ajuster)) {
    quoi <- rownames(m)[a_ajuster]
    detail <- sprintf("%s: %s -> 1", quoi, format(round(somme[a_ajuster], 4L)))
    cli::cli_inform(c(
      "i" = "ICD weights rescaled to sum to 1 ({length(quoi)} species group{?s}).",
      stats::setNames(detail, rep("*", length(detail)))))
    m <- m / somme
  }

  out <- data.frame(essence = .ICD_ESSENCES, as.data.frame(m, row.names = NULL),
                    mois_debut = vapply(.ICD_MOIS, min, integer(1), USE.NAMES = FALSE),
                    mois_fin   = vapply(.ICD_MOIS, max, integer(1), USE.NAMES = FALSE),
                    stringsAsFactors = FALSE)
  attr(out, "somme_saisie") <- stats::setNames(somme, .ICD_ESSENCES)
  attr(out, "renormalise")  <- .ICD_ESSENCES[a_ajuster]
  out
}
