#' ICD spectral indices (GRVI, CIre, CRSWIR, CRre, NDVI)
#'
#' Computes the five indices of the composite discoloration indicator (ICD,
#' spec 071) from Sentinel-2 surface reflectances:
#' \deqn{GRVI = (B03 - B04) / (B03 + B04)}
#' \deqn{CIre = B07 / B05 - 1}
#' \deqn{CRSWIR = B11 / (B8A + (B12 - B8A) \times 0.56)}
#' \deqn{CRre = B05 / (B04 + (B06 - B04) \times 0.51)}
#' \deqn{NDVI = (B08 - B04) / (B08 + B04)}
#' CRSWIR and CRre are not recomputed here: they call the kernels of
#' [reconfort_indices()] (Rust core with R fallback), whose coefficients are
#' `(1610 - 865) / (2190 - 865)` = 0.5623 and `(704 - 665) / (741 - 665)` =
#' 0.5132, the "about 0.56 and 0.51" of the method note. A zero denominator
#' gives `NA` for GRVI, CIre and NDVI (and 1 for the two continuum-removal
#' indices, as in [reconfort_indices()]).
#'
#' @param bands Surface reflectances (offset already removed), with the band
#'   names `B03`, `B04`, `B05`, `B06`, `B07`, `B08`, `B8A`, `B11`, `B12`
#'   (case-insensitive, `B3` and `B03` are the same band): a
#'   [terra::SpatRaster] (one named layer per band), or a `data.frame`,
#'   matrix or named list of equal-length numeric vectors. Only the bands of
#'   the requested indices are needed.
#' @param indices Which indices to compute, among `"GRVI"`, `"CIre"`,
#'   `"CRSWIR"`, `"CRre"`, `"NDVI"`. Default: all five.
#' @return A [terra::SpatRaster] (one layer per index) when `bands` is a
#'   `SpatRaster`, otherwise a `data.frame` with one column per index.
#' @seealso [reconfort_indices()], [run_icd_decoloration()].
#' @export
#' @examples
#' b <- data.frame(B03 = 0.06, B04 = 0.04, B05 = 0.08, B06 = 0.2, B07 = 0.3,
#'                 B08 = 0.4, B8A = 0.42, B11 = 0.25, B12 = 0.15)
#' icd_indices(b)
icd_indices <- function(bands, indices = .ICD_INDICES) {
  indices <- match.arg(indices, .ICD_INDICES, several.ok = TRUE)
  est_raster <- inherits(bands, "SpatRaster")

  if (est_raster) {
    noms <- names(bands)
    cols <- lapply(seq_along(noms),
                   function(i) terra::values(bands[[i]], mat = FALSE))
    names(cols) <- noms
  } else if (is.matrix(bands)) {
    cols <- as.list(as.data.frame(bands))
  } else if (is.list(bands)) {
    cols <- as.list(bands)
  } else {
    cli::cli_abort("{.arg bands} must be a SpatRaster, data.frame, matrix or named list.")
  }
  if (is.null(names(cols)) || anyNA(names(cols))) {
    cli::cli_abort("{.arg bands} must carry the band names (B03 ... B12).")
  }
  # B03 et B3 designent la meme bande.
  names(cols) <- sub("^B0", "B", toupper(names(cols)))

  besoin <- list(GRVI = c("B3", "B4"), CIre = c("B5", "B7"),
                 CRSWIR = c("B8A", "B11", "B12"), CRre = c("B4", "B5", "B6"),
                 NDVI = c("B4", "B8"))
  for (i in indices) {
    manque <- setdiff(besoin[[i]], names(cols))
    if (length(manque)) {
      cli::cli_abort("{i} needs the band{?s} {.val {manque}}, absent from {.arg bands}.")
    }
  }
  num <- function(nm) as.numeric(cols[[nm]])
  # Rapport normalise (a - b) / (a + b) ; denominateur nul -> NA.
  nd <- function(a, b) {
    d <- a + b
    d[!is.na(d) & d == 0] <- NA_real_
    (a - b) / d
  }
  sortie <- lapply(indices, function(i) {
    switch(i,
      GRVI   = nd(num("B3"), num("B4")),
      CIre   = { b5 <- num("B5"); b5[!is.na(b5) & b5 == 0] <- NA_real_
                 num("B7") / b5 - 1 },
      CRSWIR = .reconfort_cr_swir(num("B8A"), num("B11"), num("B12")),
      CRre   = .reconfort_cr_re(num("B4"), num("B5"), num("B6")),
      NDVI   = nd(num("B8"), num("B4")))
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
