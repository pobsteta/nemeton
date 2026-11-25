# Enveloppes du noyau Rust (crate `src/rust`, extendr), ecrites a la main : le
# crate est optionnel (ADR 0003 de nemetonplateforme), donc rien ici ne doit
# echouer au chargement du paquet quand il n'est pas compile.
# nolint start

#' @usage NULL
#' @useDynLib nemeton, .registration = TRUE
NULL

# Routine enregistree par le crate, ou NULL si le paquet a ete installe sans
# Rust. `.registration = TRUE` pose une variable `wrap__<fn>` dans l'espace de
# noms pour chaque routine enregistree.
.rust_routine <- function(nom) {
  get0(paste0("wrap__", nom), envir = asNamespace("nemeton"), inherits = FALSE)
}

#' Is the Rust core of nemeton available?
#'
#' `TRUE` when the package was installed with its Rust crate compiled **and**
#' the option `nemeton.rust` is not set to `FALSE`. When `FALSE`, functions that
#' have a Rust implementation (currently [reconfort_indices()]) use their pure-R
#' fallback, which returns the same values.
#'
#' @return A single logical.
#' @export
#' @examples
#' nemeton_rust_disponible()
#' withr::with_options(list(nemeton.rust = FALSE), nemeton_rust_disponible())
nemeton_rust_disponible <- function() {
  isTRUE(getOption("nemeton.rust", TRUE)) &&
    !is.null(.rust_routine("rust_cr_swir"))
}

# nolint end
