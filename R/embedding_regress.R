#' Predict a stand variable from foundation-model embeddings (NDP 0)
#'
#' Fits a regression from the embedding around field plots (typically IFN
#' plots of the project area) to a measured variable (default: dominant
#' height `H0`), evaluates it by **spatial block cross-validation**, and
#' predicts a raster of that variable over the embedding's extent. It gives
#' the height-based indicators a NDP 0 height when there is neither a CHM
#' nor LiDAR (spec 064, chantier A): pass the prediction to their `chm =`
#' argument.
#'
#' @param train sf points (or polygons) of the training plots, with the
#'   `target` column.
#' @param embedding SpatRaster, one band per embedding dimension (e.g.
#'   `alphaearthnemeton::aef_fetch()`), or a list named by year (latest used).
#' @param target Name of the column to predict. Default `"H0"`.
#' @param methode `"auto"` (ranger when installed, else ridge), `"ranger"`
#'   or `"ridge"` (base R, penalty chosen by generalised cross-validation).
#' @param rayon_m Plot radius in metres: the plot's embedding is the
#'   coverage-weighted mean within this radius. Default 15 (IFN plot).
#' @param taille_bloc_m Side of the square blocks of the spatial
#'   cross-validation, in metres. Default 5000: plots closer than that tend
#'   to share their errors, and a random split would flatter the model.
#' @param n_plis Number of cross-validation folds (blocks are dealt to
#'   folds). Default 5.
#' @param min_train Minimum number of usable plots. Below it, no model is
#'   fitted and the status is `"train_too_small"`. Default 30.
#' @param predire Logical. Predict the raster. Default `TRUE`.
#' @param graine Random seed for the fold assignment and ranger.
#'
#' @return An object of class `embedding_regression`, a list with
#'   \describe{
#'     \item{status}{`"ok"` or `"train_too_small"`.}
#'     \item{prediction}{SpatRaster named after `target` (`NULL` when no
#'       model), with `attr(, "chm_source") = "aef_regression"`.}
#'     \item{cv}{list: `rmse`, `r2`, `biais` (mean prediction minus
#'       observation), `n`, `n_plis`, `taille_bloc_m`, and `observations`
#'       (data frame of out-of-fold predictions).}
#'     \item{methode}{the method used.}
#'     \item{n_train}{number of usable plots.}
#'     \item{modele}{the fitted model (ridge coefficients or ranger object).}
#'   }
#'
#' @details
#' **Pitfalls.** The prediction is smooth: it carries the mean height of a
#' 10 m pixel's neighbourhood as the embedding sees it, not the within-stand
#' variability of a CHM. It suits indicators that read a level (P1, P2, C1)
#' and **not** B2, whose structural component is the coefficient of
#' variation of the CHM: a CV of predicted heights measures the model, not
#' the stand. The cross-validated RMSE is the error to quote with any value
#' derived from the prediction; with fewer than `min_train` plots nothing is
#' fitted rather than a model that would mostly fit noise.
#'
#' @section Lifecycle:
#' Experimental (spec 064): may change in any release.
#'
#' @seealso [embedding_summary()], [indicateur_p2_station()]
#' @export
embedding_regress <- function(train, embedding, target = "H0",
                              methode = c("auto", "ranger", "ridge"),
                              rayon_m = 15, taille_bloc_m = 5000, n_plis = 5L,
                              min_train = 30L, predire = TRUE, graine = 1L) {
  methode <- match.arg(methode)
  if (!inherits(train, "sf")) cli::cli_abort("{.arg train} must be an sf object.")
  if (!target %in% names(train)) {
    cli::cli_abort("Column {.field {target}} not found in {.arg train}.")
  }
  embedding <- .embedding_resolu(embedding, NULL)
  if (is.null(embedding)) cli::cli_abort("{.arg embedding} is required.")
  if (methode == "auto") {
    methode <- if (requireNamespace("ranger", quietly = TRUE)) "ranger" else "ridge"
  }
  if (methode == "ranger" && !requireNamespace("ranger", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ranger} is required for {.code methode = \"ranger\"}.")
  }

  # Embedding moyen dans le rayon de chaque placette
  geom <- sf::st_geometry(train)
  if (all(sf::st_geometry_type(geom) %in% c("POINT", "MULTIPOINT"))) {
    zones <- sf::st_buffer(train, rayon_m)
  } else {
    zones <- train
  }
  # Une placette (15 m de rayon, ~7 pixels de 10 m) n'a besoin que d'une
  # couverture non nulle : pas de seuil en pixels entiers.
  x <- embedding_summary(zones, embedding, stats = "mean", min_pixels = 1e-6)$mean
  y <- as.numeric(train[[target]])
  ok <- stats::complete.cases(x) & is.finite(y)
  n <- sum(ok)
  out <- structure(list(
    status = "ok", prediction = NULL, cv = NULL, methode = methode,
    n_train = n, modele = NULL, target = target
  ), class = "embedding_regression")
  if (n < min_train) {
    cli::cli_alert_info(
      "embedding_regress: {n} usable plot{?s} (< {min_train}), no model fitted."
    )
    out$status <- "train_too_small"
    return(out)
  }
  x <- x[ok, , drop = FALSE]
  y <- y[ok]
  xy <- sf::st_coordinates(suppressWarnings(sf::st_centroid(sf::st_geometry(train)[ok])))

  # Validation croisee par blocs spatiaux : les placettes d'un meme bloc
  # tombent dans le meme pli.
  bloc <- paste(floor(xy[, 1] / taille_bloc_m), floor(xy[, 2] / taille_bloc_m))
  blocs <- unique(bloc)
  n_plis <- max(2L, min(as.integer(n_plis), length(blocs)))
  if (length(blocs) < 2L) {
    cli::cli_abort(c(
      "All plots fall in one {taille_bloc_m} m block: spatial cross-validation is impossible.",
      "i" = "Lower {.arg taille_bloc_m}."
    ))
  }
  withr::with_seed(graine, {
    pli_bloc <- sample(rep_len(seq_len(n_plis), length(blocs)))
  })
  pli <- pli_bloc[match(bloc, blocs)]

  ajuste <- function(xa, ya) {
    if (methode == "ridge") .ridge_ajuste(xa, ya)
    else withr::with_seed(graine, ranger::ranger(
      x = as.data.frame(xa), y = ya, num.trees = 500, seed = graine
    ))
  }
  predit <- function(m, xp) {
    if (methode == "ridge") .ridge_predit(m, xp)
    else stats::predict(m, data = as.data.frame(xp))$predictions
  }
  hors_pli <- rep(NA_real_, n)
  for (k in seq_len(n_plis)) {
    test <- pli == k
    if (!any(test) || all(test)) next
    m <- ajuste(x[!test, , drop = FALSE], y[!test])
    hors_pli[test] <- predit(m, x[test, , drop = FALSE])
  }
  v <- is.finite(hors_pli)
  out$cv <- list(
    rmse = sqrt(mean((hors_pli[v] - y[v])^2)),
    r2 = 1 - sum((hors_pli[v] - y[v])^2) / sum((y[v] - mean(y[v]))^2),
    biais = mean(hors_pli[v] - y[v]),
    n = sum(v), n_plis = n_plis, taille_bloc_m = taille_bloc_m,
    observations = data.frame(observe = y, predit = hors_pli, pli = pli)
  )

  out$modele <- ajuste(x, y)
  if (isTRUE(predire)) {
    noms <- colnames(x)
    pred <- terra::app(embedding, function(v) {
      res <- rep(NA_real_, nrow(v))
      okp <- stats::complete.cases(v)
      if (any(okp)) {
        xv <- v[okp, , drop = FALSE]
        colnames(xv) <- noms
        res[okp] <- predit(out$modele, xv)
      }
      res
    })
    names(pred) <- target
    attr(pred, "chm_source") <- "aef_regression"
    out$prediction <- pred
  }
  cli::cli_alert_success(
    "embedding_regress ({methode}): {target} on {n} plots, spatial CV RMSE {format(out$cv$rmse, digits = 3)}, R2 {format(out$cv$r2, digits = 2)}"
  )
  out
}

#' @export
print.embedding_regression <- function(x, ...) {
  cat(sprintf("<embedding_regression> %s, method %s, status %s, %d plots\n",
              x$target, x$methode, x$status, x$n_train))
  if (!is.null(x$cv)) {
    cat(sprintf("  spatial CV (%d folds, %g m blocks): RMSE %.3g, R2 %.2f, bias %.3g\n",
                x$cv$n_plis, x$cv$taille_bloc_m, x$cv$rmse, x$cv$r2, x$cv$biais))
  }
  invisible(x)
}

# Ridge en base R. Variables centrees-reduites ; penalite choisie par
# validation croisee generalisee (GCV) sur une grille, via la SVD :
#   GCV(l) = n * RSS(l) / (n - df(l))^2, df(l) = sum(d^2 / (d^2 + l)).
# Reutilisable par les sondes du chantier B (probe_indicator()).
.ridge_ajuste <- function(x, y, lambdas = 10^seq(-4, 4, length.out = 41)) {
  mu <- colMeans(x)
  s <- apply(x, 2L, stats::sd)
  s[!is.finite(s) | s == 0] <- 1
  z <- sweep(sweep(x, 2L, mu), 2L, s, "/")
  y0 <- mean(y)
  yc <- y - y0
  sv <- svd(z)
  uty <- crossprod(sv$u, yc)
  n <- nrow(z)
  gcv <- vapply(lambdas, function(l) {
    f <- sv$d^2 / (sv$d^2 + l)
    ajuste <- sv$u %*% (f * uty)
    rss <- sum((yc - ajuste)^2)
    n * rss / (n - sum(f))^2
  }, numeric(1))
  l <- lambdas[which.min(gcv)]
  beta <- sv$v %*% ((sv$d / (sv$d^2 + l)) * uty)
  list(mu = mu, s = s, beta = as.numeric(beta), intercept = y0, lambda = l)
}

.ridge_predit <- function(m, x) {
  z <- sweep(sweep(as.matrix(x), 2L, m$mu), 2L, m$s, "/")
  as.numeric(z %*% m$beta) + m$intercept
}
