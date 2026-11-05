#' Foundation-model embeddings: generic per-unit tools (spec 064)
#'
#' Model-agnostic helpers for pixel embeddings produced upstream by
#' foundation models (AlphaEarth Foundations via `alphaearthnemeton`, and
#' later MAESTRO or ForPT). The core never downloads nor computes an
#' embedding: it only reads a multi-band SpatRaster (one band per dimension).
#'
#' @name embeddings
#' @keywords internal
NULL


#' Summarise a pixel-embedding raster per spatial unit
#'
#' Coverage-weighted mean and standard deviation of every embedding dimension
#' inside each unit. Generic: the raster may come from any foundation model
#' (AlphaEarth, MAESTRO, ForPT), one band per dimension.
#'
#' @param units sf polygon layer (spatial units / UGF).
#' @param layer SpatRaster, one band per embedding dimension (e.g. 64 for
#'   AlphaEarth Foundations).
#' @param stats Character. Statistics to return among `"mean"` and `"sd"`.
#' @param min_pixels Numeric. Minimum covered area, in pixels (sum of the
#'   coverage fractions of the valid pixels), below which the unit's row is
#'   `NA`.
#'
#' @return A list with
#'   \describe{
#'     \item{mean}{`n_units x d` matrix of coverage-weighted means (if requested).}
#'     \item{sd}{`n_units x d` matrix of coverage-weighted standard deviations
#'       (if requested).}
#'     \item{n_pixels}{numeric vector, covered area in pixels.}
#'     \item{meta}{list: `dimension`, `source` (the raster's
#'       `embedding_source` attribute, or `NA`), `min_pixels`.}
#'   }
#'
#' @details
#' AlphaEarth embeddings have unit norm. The mean of unit vectors does not:
#' its norm (between 0 and 1) measures how homogeneous the unit is. The mean
#' is returned as is, not renormalised (spec 064, D-3).
#'
#' A pixel counts only if all its dimensions are finite.
#'
#' @section Lifecycle:
#' Experimental (spec 064): may change in any release.
#'
#' @seealso [distance_reference()], [indicateur_n5_distance_reference()]
#' @export
embedding_summary <- function(units, layer, stats = c("mean", "sd"),
                              min_pixels = 10) {
  if (!inherits(units, "sf")) cli::cli_abort("{.arg units} must be an sf object.")
  if (!inherits(layer, "SpatRaster")) {
    cli::cli_abort("{.arg layer} must be a SpatRaster (one band per dimension).")
  }
  stats <- match.arg(stats, c("mean", "sd"), several.ok = TRUE)
  d <- terra::nlyr(layer)
  n <- nrow(units)

  u <- sf::st_transform(units, sf::st_crs(terra::crs(layer)))
  morceaux <- exactextractr::exact_extract(layer, u, progress = FALSE)

  moy <- matrix(NA_real_, n, d)
  ect <- matrix(NA_real_, n, d)
  n_pix <- numeric(n)
  for (i in seq_len(n)) {
    df <- morceaux[[i]]
    if (is.null(df) || !nrow(df)) next
    w <- df$coverage_fraction
    m <- as.matrix(df[, seq_len(d), drop = FALSE])
    ok <- w > 0 & apply(is.finite(m), 1L, all)
    n_pix[i] <- sum(w[ok])
    if (n_pix[i] < min_pixels) next
    m <- m[ok, , drop = FALSE]
    w <- w[ok] / sum(w[ok])
    mu <- colSums(m * w)
    moy[i, ] <- mu
    ect[i, ] <- sqrt(pmax(0, colSums(sweep(m, 2L, mu)^2 * w)))
  }
  noms <- names(layer)
  colnames(moy) <- noms
  colnames(ect) <- noms

  out <- list()
  if ("mean" %in% stats) out$mean <- moy
  if ("sd" %in% stats) out$sd <- ect
  out$n_pixels <- n_pix
  out$meta <- list(
    dimension = d,
    source = attr(layer, "embedding_source") %||% NA_character_,
    min_pixels = min_pixels
  )
  out
}


#' Distance of embeddings to a reference set
#'
#' Mahalanobis distance of each row of `x` to the centroid of `reference`,
#' with the reference covariance shrunk towards a scaled identity by the
#' Ledoit-Wolf (2004) estimator. With few reference rows and many dimensions
#' (15 units, 64 dimensions) the sample covariance is singular; shrinkage
#' keeps it invertible, at the price of a distance that tends to the
#' Euclidean one as the reference shrinks.
#'
#' @param x Numeric matrix (`n x d`), rows to score (e.g. the `mean` of
#'   [embedding_summary()]).
#' @param reference Numeric matrix (`m x d`), the reference rows. Rows with a
#'   non-finite value are dropped.
#' @param method `"mahalanobis_lw"` (default) or `"euclidean"`.
#'
#' @return A list with
#'   \describe{
#'     \item{distance}{numeric, distance of each row of `x` (NA for a row with
#'       a non-finite value).}
#'     \item{distance_loo}{numeric, leave-one-out distance of each reference
#'       row to the reference built without it: the reference's own spread,
#'       used to turn a distance into a score.}
#'     \item{shrinkage}{Ledoit-Wolf intensity in `[0, 1]` (1 = identity),
#'       `NA` for `"euclidean"`.}
#'     \item{n_reference}{number of reference rows used.}
#'     \item{method}{the method.}
#'   }
#'
#' @section Lifecycle:
#' Experimental (spec 064): may change in any release.
#'
#' @references Ledoit O., Wolf M. (2004). A well-conditioned estimator for
#'   large-dimensional covariance matrices. *Journal of Multivariate
#'   Analysis* 88(2), 365-411.
#'
#' @seealso [embedding_summary()], [indicateur_n5_distance_reference()]
#' @export
distance_reference <- function(x, reference,
                               method = c("mahalanobis_lw", "euclidean")) {
  method <- match.arg(method)
  x <- as.matrix(x)
  reference <- as.matrix(reference)
  if (ncol(x) != ncol(reference)) {
    cli::cli_abort("{.arg x} and {.arg reference} must have the same number of columns.")
  }
  reference <- reference[apply(is.finite(reference), 1L, all), , drop = FALSE]
  m <- nrow(reference)
  if (m < 3L) {
    cli::cli_abort("At least 3 complete reference rows are needed, got {m}.")
  }

  ajuste <- function(ref) {
    mu <- colMeans(ref)
    if (method == "euclidean") {
      return(list(mu = mu, inv = NULL, shrinkage = NA_real_))
    }
    lw <- .ledoit_wolf(ref)
    list(mu = mu, inv = chol2inv(chol(lw$sigma)), shrinkage = lw$shrinkage)
  }
  dist_a <- function(xx, fit) {
    out <- rep(NA_real_, nrow(xx))
    ok <- apply(is.finite(xx), 1L, all)
    if (!any(ok)) return(out)
    dc <- sweep(xx[ok, , drop = FALSE], 2L, fit$mu)
    q <- if (is.null(fit$inv)) rowSums(dc^2) else rowSums((dc %*% fit$inv) * dc)
    out[ok] <- sqrt(pmax(0, q))
    out
  }

  fit <- ajuste(reference)
  loo <- vapply(seq_len(m), function(i) {
    dist_a(reference[i, , drop = FALSE], ajuste(reference[-i, , drop = FALSE]))
  }, numeric(1))

  list(
    distance = dist_a(x, fit),
    distance_loo = loo,
    shrinkage = fit$shrinkage,
    n_reference = m,
    method = method
  )
}

# Ledoit-Wolf (2004) : covariance retrecie vers m * I, m = trace(S) / p.
# S est la covariance au sens du maximum de vraisemblance (division par n),
# comme dans l'article. Intensite = min(b2, d2) / d2, avec
#   d2 = ||S - m I||_F^2,
#   b2 = (1 / n^2) * sum_k ||x_k x_k' - S||_F^2,
# et ||x x' - S||_F^2 = (x'x)^2 - 2 x'S x + ||S||_F^2 (pas de matrice p x p
# par observation).
.ledoit_wolf <- function(ref) {
  n <- nrow(ref)
  p <- ncol(ref)
  xc <- sweep(ref, 2L, colMeans(ref))
  s <- crossprod(xc) / n
  mu <- sum(diag(s)) / p
  cible <- diag(mu, p)
  d2 <- sum((s - cible)^2)
  if (d2 <= .Machine$double.eps || mu <= 0) {
    # Reference sans dispersion (ou dispersion isotrope exacte) : la cible
    # est l'estimateur. Plancher pour rester inversible.
    plancher <- max(mu, 1e-12)
    return(list(sigma = diag(plancher, p), shrinkage = 1))
  }
  xx <- rowSums(xc^2)
  xsx <- rowSums((xc %*% s) * xc)
  b2_bar <- sum(xx^2 - 2 * xsx + sum(s^2)) / n^2
  intensite <- min(max(b2_bar, 0), d2) / d2
  list(sigma = intensite * cible + (1 - intensite) * s, shrinkage = intensite)
}
