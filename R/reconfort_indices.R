# Indices spectraux RECONFORT (CRswir, CRre) : noyau Rust + repli R pur
# (spike de re-entrainement, mission 060 de nemetonplateforme, ADR 0003).
#
# Formules : iota2/external_features/custom_index.py du depot amont RECONFORT
# (framagit.org/fl.mouret/reconfort, Apache-2.0), reprises sous GPL-3 :
#   CRswir = B11 / (B8A + (1610 - 865) * (B12 - B8A) / (2190 - 865))
#   CRre   = B5  / (B4  + (704  - 665) * (B6  - B4 ) / (741  - 665))
# Un denominateur nul est remplace par 1 ; un NA en entree donne un NA.

# Bandes requises par indice.
.RECONFORT_BANDES <- list(
  CRswir = c("B8A", "B11", "B12"),
  CRre   = c("B4", "B5", "B6")
)

#' RECONFORT spectral indices CRswir and CRre
#'
#' Computes, per pixel, the two red-edge/SWIR "chlorophyll-red-edge" indices
#' used by the RECONFORT dieback model (Sentinel-2 bands B4, B5, B6, B8A, B11,
#' B12):
#' \deqn{CRswir = B11 / (B8A + (1610 - 865) (B12 - B8A) / (2190 - 865))}
#' \deqn{CRre = B5 / (B4 + (704 - 665) (B6 - B4) / (741 - 665))}
#' A zero denominator is replaced by 1 and `NA` inputs give `NA` (same rules as
#' the upstream iota2 `custom_index.py`, Apache-2.0).
#'
#' The computation runs in the Rust core of the package when it is compiled and
#' the option `nemeton.rust` is not `FALSE`; otherwise a pure-R fallback returns
#' the same values (to 1e-12). See [nemeton_rust_disponible()].
#'
#' @param bands Surface reflectances, with the band names `B4`, `B5`, `B6`,
#'   `B8A`, `B11`, `B12` (case-insensitive): a [terra::SpatRaster] (one layer
#'   per band, named), or a `data.frame`, matrix or named list of equal-length
#'   numeric vectors. Only the bands of the requested indices are needed.
#' @param indices Which indices to compute: `"CRswir"`, `"CRre"` or both.
#' @return A [terra::SpatRaster] (layers `CRswir`, `CRre`) when `bands` is a
#'   `SpatRaster`, otherwise a `data.frame` with the same columns.
#' @references Upstream RECONFORT: <https://framagit.org/fl.mouret/reconfort>
#'   (Apache-2.0).
#' @export
#' @examples
#' b <- data.frame(B4 = 0.05, B5 = 0.08, B6 = 0.2, B8A = 0.4, B11 = 0.25, B12 = 0.15)
#' reconfort_indices(b)
reconfort_indices <- function(bands, indices = c("CRswir", "CRre")) {
  indices <- match.arg(indices, c("CRswir", "CRre"), several.ok = TRUE)
  est_raster <- inherits(bands, "SpatRaster")

  if (est_raster) {
    noms <- names(bands)
    cols <- lapply(seq_along(noms), function(i) terra::values(bands[[i]], mat = FALSE))
    names(cols) <- noms
  } else if (is.matrix(bands)) {
    cols <- as.list(as.data.frame(bands))
  } else if (is.list(bands)) {
    cols <- as.list(bands)
  } else {
    cli::cli_abort("{.arg bands} must be a SpatRaster, data.frame, matrix or named list.")
  }
  if (is.null(names(cols)) || anyNA(names(cols))) {
    cli::cli_abort("{.arg bands} must carry the band names (B4, B5, B6, B8A, B11, B12).")
  }
  names(cols) <- toupper(names(cols))

  manquantes <- lapply(indices, function(i) setdiff(.RECONFORT_BANDES[[i]], names(cols)))
  names(manquantes) <- indices
  for (i in indices) {
    if (length(manquantes[[i]])) {
      cli::cli_abort("{i} needs the band{?s} {.val {manquantes[[i]]}}, absent from {.arg bands}.")
    }
  }

  sortie <- lapply(indices, function(i) {
    b <- lapply(cols[.RECONFORT_BANDES[[i]]], as.numeric)
    n <- unique(lengths(b))
    if (length(n) != 1L) {
      cli::cli_abort("The bands of {i} must have the same length.")
    }
    if (i == "CRswir") {
      .reconfort_cr_swir(b$B8A, b$B11, b$B12)
    } else {
      .reconfort_cr_re(b$B4, b$B5, b$B6)
    }
  })
  names(sortie) <- indices

  if (est_raster) {
    r <- terra::rast(bands, nlyrs = length(indices))
    for (j in seq_along(indices)) terra::values(r[[j]]) <- sortie[[j]]
    names(r) <- indices
    return(r)
  }
  as.data.frame(sortie, optional = TRUE)
}

# --- Noyau : Rust s'il est compile et autorise, repli R pur sinon ------------

.reconfort_cr_swir <- function(b8a, b11, b12) {
  if (nemeton_rust_disponible()) {
    return(.Call(.rust_routine("rust_cr_swir"), b8a, b11, b12))
  }
  .reconfort_cr_swir_r(b8a, b11, b12)
}

.reconfort_cr_re <- function(b4, b5, b6) {
  if (nemeton_rust_disponible()) {
    return(.Call(.rust_routine("rust_cr_re"), b4, b5, b6))
  }
  .reconfort_cr_re_r(b4, b5, b6)
}

# Repli R pur (memes formules que src/rust/src/indices.rs).
.reconfort_denominateur <- function(d) {
  d[!is.na(d) & d == 0] <- 1
  d
}

.reconfort_cr_swir_r <- function(b8a, b11, b12) {
  b11 / .reconfort_denominateur(b8a + (1610 - 865) * (b12 - b8a) / (2190 - 865))
}

.reconfort_cr_re_r <- function(b4, b5, b6) {
  b5 / .reconfort_denominateur(b4 + (704 - 665) * (b6 - b4) / (741 - 665))
}
