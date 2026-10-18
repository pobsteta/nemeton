# deprecation.R — avertissement de dépréciation, une fois par session et par
# fonction (spec 057 : dépréciation préalable avant tout retrait).
# L'option `nemeton.deprecation_silencieuse = TRUE` le coupe : tests des
# fonctions dépréciées, appels internes d'une fonction dépréciée à une autre.

.DEPRECIATIONS_SIGNALEES <- new.env(parent = emptyenv())

.avertir_depreciation <- function(fn, depuis, remplacement, details = NULL) {
  if (isTRUE(getOption("nemeton.deprecation_silencieuse"))) return(invisible(FALSE))
  if (exists(fn, envir = .DEPRECIATIONS_SIGNALEES, inherits = FALSE)) {
    return(invisible(FALSE))
  }
  assign(fn, TRUE, envir = .DEPRECIATIONS_SIGNALEES)
  rlang::warn(
    c(sprintf("`%s()` is deprecated since nemeton %s.", fn, depuis),
      i = sprintf("Use %s instead.", remplacement),
      details,
      i = "This warning is shown once per session."),
    class = c("nemeton_deprecated", "deprecatedWarning"))
  invisible(TRUE)
}
