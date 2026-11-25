# Apprentissage RECONFORT (spike, mission 060 de nemetonplateforme) : Random
# Forest `ranger` sur les series CRswir/CRre, validation croisee spatiale par
# blocs, comparaison avec la carte du modele amont.

.RECONFORT_NB_PAS <- 36L  # une image tous les 10 jours (README amont)

# Table de caracteristiques : une ligne par (id_unique, annee), 36 pas de 10
# jours pour CRswir et CRre. Les trous sont interpoles lineairement ; une serie
# sans aucune valeur sur un indice ecarte la ligne (comptee dans l'avertissement).
.reconfort_caracteristiques <- function(serie, cibles) {
  if (!all(c("id_unique", "date") %in% names(serie))) {
    cli::cli_abort("{.arg serie} needs the columns {.field id_unique} and {.field date}.")
  }
  if (!inherits(serie$date, "Date")) {
    cli::cli_abort("{.field date} of {.arg serie} must be a Date.")
  }
  if (!all(c("CRswir", "CRre") %in% names(serie))) {
    serie <- cbind(serie, reconfort_indices(serie))
  }
  serie$annee_s <- as.integer(format(serie$date, "%Y"))
  serie$pas <- pmin(.RECONFORT_NB_PAS,
                    (as.integer(format(serie$date, "%j")) - 1L) %/% 10L + 1L)
  cle_s <- paste(serie$id_unique, serie$annee_s)
  noms <- c(sprintf("CRswir_%02d", seq_len(.RECONFORT_NB_PAS)),
            sprintf("CRre_%02d", seq_len(.RECONFORT_NB_PAS)))
  mat <- matrix(NA_real_, nrow(cibles), length(noms), dimnames = list(NULL, noms))
  ordre_s <- split(seq_len(nrow(serie)), cle_s)
  for (i in seq_len(nrow(cibles))) {
    idx <- ordre_s[[paste(cibles$id_unique[i], cibles$annee[i])]]
    if (is.null(idx)) next
    for (ind in c("CRswir", "CRre")) {
      v <- tapply(serie[[ind]][idx], factor(serie$pas[idx], levels = seq_len(.RECONFORT_NB_PAS)),
                  function(z) if (all(is.na(z))) NA_real_ else mean(z, na.rm = TRUE))
      v <- as.numeric(v)
      if (all(is.na(v))) next
      if (anyNA(v)) {
        v <- stats::approx(seq_along(v), v, xout = seq_along(v), rule = 2)$y
      }
      mat[i, grep(paste0("^", ind, "_"), noms)] <- v
    }
  }
  as.data.frame(mat)
}

# Blocs spatiaux -> plis. Un bloc entier est dans un seul pli ; une placette (et
# toutes ses annees) est dans le pli de son bloc.
.reconfort_plis <- function(id, x, y, taille_bloc, k, seed) {
  premier <- !duplicated(id)
  bloc_p <- paste(floor(x[premier] / taille_bloc), floor(y[premier] / taille_bloc))
  blocs <- unique(bloc_p)
  if (length(blocs) < 2L) {
    cli::cli_abort("Spatial cross-validation needs at least 2 blocks; got {length(blocs)}. Reduce {.arg taille_bloc}.")
  }
  if (k > length(blocs)) {
    cli::cli_warn("Only {length(blocs)} spatial blocks: {.arg k} reduced from {k} to {length(blocs)}.")
    k <- length(blocs)
  }
  ordre <- withr::with_seed(seed, sample(blocs))
  pli_bloc <- stats::setNames(rep_len(seq_len(k), length(ordre)), ordre)
  bloc_de_id <- stats::setNames(bloc_p, id[premier])
  list(
    pli = unname(pli_bloc[bloc_de_id[as.character(id)]]),
    bloc = unname(bloc_de_id[as.character(id)]),
    k = k
  )
}

#' Train the RECONFORT-style dieback classifier (spike)
#'
#' Fits a `ranger` Random Forest on the CRswir/CRre time series (36 ten-day
#' steps of the observation year per index) of labelled plots, and scores it by
#' **spatial block cross-validation**: plots are grouped into square blocks of
#' `taille_bloc` metres, whole blocks are assigned to folds, and a fold is
#' predicted by a model that never saw a plot of the same block.
#'
#' @param serie A `data.frame` time series with `id_unique`, `date` (`Date`) and
#'   either `CRswir` and `CRre`, or the Sentinel-2 bands accepted by
#'   [reconfort_indices()].
#' @param etiquettes Labels from [reconfort_etiquettes()], with plot
#'   coordinates `x` and `y` (metres) used to build the blocks.
#' @param k Number of cross-validation folds.
#' @param taille_bloc Block size in the unit of `x`/`y` (metres).
#' @param seed Integer seed (blocks, folds and forest); fixed for reproducibility.
#' @param num_arbres Number of trees.
#' @return An object of class `reconfort_modele`: `modele` (the final `ranger`
#'   fit on all rows), `confusion` (out-of-fold confusion matrix, rows observed,
#'   columns predicted, classes 1 to 3), `precision` (overall accuracy
#'   out-of-fold), `precision_observations` (same, on real observations only),
#'   `plis` (per row: `id_unique`, `annee`, `source`, `bloc`, `pli`, `observe`,
#'   `predit`), `variables`, `seed`, `k`, `taille_bloc`.
#' @export
#' @examples
#' \donttest{
#' # voir tests/testthat/test-reconfort-apprentissage.R pour un jeu `synth_`
#' }
reconfort_entrainer <- function(serie, etiquettes, k = 5L, taille_bloc = 1000,
                                seed = 42L, num_arbres = 300L) {
  if (!is.data.frame(etiquettes) ||
      !all(c("id_unique", "annee", "dep_cor", "x", "y") %in% names(etiquettes))) {
    cli::cli_abort("{.arg etiquettes} must come from {.fn reconfort_etiquettes} and carry {.field x} and {.field y}.")
  }
  et <- as.data.frame(etiquettes)
  car <- .reconfort_caracteristiques(serie, et)
  ok <- stats::complete.cases(car)
  if (any(!ok)) {
    cli::cli_warn("{sum(!ok)} labelled row{?s} dropped: no usable series.")
  }
  et <- et[ok, , drop = FALSE]
  car <- car[ok, , drop = FALSE]
  if (nrow(et) < 4L) cli::cli_abort("Not enough labelled rows with a series ({nrow(et)}).")
  if (anyNA(et$x) || anyNA(et$y)) cli::cli_abort("{.field x}/{.field y} contain NA.")

  plis <- .reconfort_plis(et$id_unique, et$x, et$y, taille_bloc, as.integer(k), seed)
  classes <- factor(et$dep_cor, levels = 1:3)
  dat <- cbind(classe = classes, car)

  ajuster <- function(d) {
    ranger::ranger(classe ~ ., data = droplevels(d), num.trees = num_arbres,
                   seed = seed, num.threads = 1L, classification = TRUE)
  }
  predit <- factor(rep(NA_character_, nrow(dat)), levels = 1:3)
  for (f in seq_len(plis$k)) {
    test <- plis$pli == f
    if (!any(test) || all(test)) next
    m <- ajuster(dat[!test, , drop = FALSE])
    p <- stats::predict(m, data = dat[test, , drop = FALSE], num.threads = 1L)$predictions
    predit[test] <- factor(as.character(p), levels = 1:3)
  }
  confusion <- table(observe = classes, predit = predit)
  evalue <- !is.na(predit)
  prec <- function(sel) {
    sel <- sel & evalue
    if (!any(sel)) NA_real_ else mean(as.character(classes[sel]) == as.character(predit[sel]))
  }
  structure(list(
    modele = ajuster(dat),
    confusion = confusion,
    precision = prec(rep(TRUE, nrow(dat))),
    precision_observations = prec(et$source == "observation"),
    plis = data.frame(id_unique = et$id_unique, annee = et$annee, source = et$source,
                      bloc = plis$bloc, pli = plis$pli,
                      observe = as.integer(as.character(classes)),
                      predit = as.integer(as.character(predit)),
                      stringsAsFactors = FALSE),
    variables = names(car), seed = seed, k = plis$k, taille_bloc = taille_bloc
  ), class = "reconfort_modele")
}

#' @export
print.reconfort_modele <- function(x, ...) {
  cat("<reconfort_modele> ranger,", x$modele$num.trees, "arbres,",
      length(x$variables), "variables, seed", x$seed, "\n")
  cat("Validation croisee spatiale :", x$k, "plis, blocs de", x$taille_bloc, "m\n")
  cat("Precision globale :", format(round(x$precision, 4)),
      "| observations seules :", format(round(x$precision_observations, 4)), "\n")
  print(x$confusion)
  invisible(x)
}

#' Predict RECONFORT classes with a trained spike model
#'
#' @param modele A `reconfort_modele` from [reconfort_entrainer()].
#' @param serie Time series, as for [reconfort_entrainer()].
#' @param cibles A `data.frame` with `id_unique` and `annee` (rows to predict).
#' @return `cibles` with a `classe` column (1, 2 or 3; `NA` without a usable series).
#' @export
reconfort_predire <- function(modele, serie, cibles) {
  if (!inherits(modele, "reconfort_modele")) {
    cli::cli_abort("{.arg modele} must be a {.cls reconfort_modele}.")
  }
  if (!all(c("id_unique", "annee") %in% names(cibles))) {
    cli::cli_abort("{.arg cibles} needs {.field id_unique} and {.field annee}.")
  }
  car <- .reconfort_caracteristiques(serie, cibles)
  ok <- stats::complete.cases(car)
  out <- cibles
  out$classe <- NA_integer_
  if (any(ok)) {
    p <- stats::predict(modele$modele, data = car[ok, , drop = FALSE], num.threads = 1L)$predictions
    out$classe[ok] <- as.integer(as.character(p))
  }
  out
}

#' Pixel-by-pixel agreement of a class map with the upstream RECONFORT map
#'
#' Compares two classification rasters (classes 1, 2, 3; e.g. the map of the
#' spike model and the map of the upstream v3 model). The upstream map is
#' resampled (nearest neighbour) onto the grid of `carte` when the grids differ.
#' With `placettes`, the agreement of each map with held-out field plots is
#' also returned: this is the criterion to amend spec 021 (the upstream model
#' must agree with field plots kept aside).
#'
#' @param carte,amont [terra::SpatRaster] objects or file paths of class maps.
#' @param placettes Optional `data.frame` with `x`, `y` (CRS of `carte`) and
#'   `dep_cor` (1 to 3) of plots kept aside.
#' @return A list: `n` (pixels compared, both non-`NA`), `accord` (share of
#'   identical pixels), `confusion` (rows `carte`, columns `amont`) and, with
#'   `placettes`, `terrain` (`n`, `accord_carte`, `accord_amont`).
#' @export
reconfort_comparer_amont <- function(carte, amont, placettes = NULL) {
  if (is.character(carte)) carte <- terra::rast(carte)
  if (is.character(amont)) amont <- terra::rast(amont)
  if (!inherits(carte, "SpatRaster") || !inherits(amont, "SpatRaster")) {
    cli::cli_abort("{.arg carte} and {.arg amont} must be SpatRaster objects or file paths.")
  }
  if (!terra::compareGeom(carte[[1]], amont[[1]], stopOnError = FALSE)) {
    if (!terra::same.crs(carte, amont)) amont <- terra::project(amont, carte, method = "near")
    else amont <- terra::resample(amont, carte, method = "near")
  }
  a <- terra::values(carte[[1]], mat = FALSE)
  b <- terra::values(amont[[1]], mat = FALSE)
  ok <- !is.na(a) & !is.na(b)
  confusion <- table(carte = factor(a[ok], levels = 1:3), amont = factor(b[ok], levels = 1:3))
  out <- list(n = sum(ok), accord = if (any(ok)) mean(a[ok] == b[ok]) else NA_real_,
              confusion = confusion)
  if (!is.null(placettes)) {
    if (!all(c("x", "y", "dep_cor") %in% names(placettes))) {
      cli::cli_abort("{.arg placettes} needs {.field x}, {.field y} and {.field dep_cor}.")
    }
    pts <- terra::vect(cbind(placettes$x, placettes$y), type = "points", crs = terra::crs(carte))
    pc <- terra::extract(carte[[1]], pts)[[2]]
    pa <- terra::extract(amont[[1]], pts)[[2]]
    t_c <- !is.na(pc)
    t_a <- !is.na(pa)
    out$terrain <- list(
      n = nrow(placettes),
      accord_carte = if (any(t_c)) mean(pc[t_c] == placettes$dep_cor[t_c]) else NA_real_,
      accord_amont = if (any(t_a)) mean(pa[t_a] == placettes$dep_cor[t_a]) else NA_real_
    )
  }
  out
}
