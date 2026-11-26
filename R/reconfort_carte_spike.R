# Carte de classes du spike RECONFORT (mission 076 de nemetonplateforme) :
# applique un `reconfort_modele` (mission 060) pixel par pixel sur les scenes
# MUSCATE deja decoupees, et ecrit un GeoTIFF aligne sur la carte IOTA2 de la
# meme zone, pour la comparaison de la mission 071 (data-raw/comparaison_reconfort/).

# Plafond de pixels par bloc : la table longue (pixel x date) passe par
# `.reconfort_caracteristiques()`, bien plus gourmande que le chunk IOTA2.
.RECONFORT_CARTE_PX_MAX <- 2e5

#' Class map of the RECONFORT spike model on the grid of a template map
#'
#' Applies a model trained by [reconfort_entrainer()] to every pixel of a zone
#' and writes a GeoTIFF of classes (1 healthy, 2 declining, 3 severely
#' declining) **aligned to the pixel** on `gabarit` (in practice the IOTA2 map of
#' the same zone and year), so that the two methods can be compared pixel by
#' pixel (`data-raw/comparaison_reconfort/comparer_cartes.R`).
#'
#' Order of operations, as in IOTA2: MAJA masks (`CLM` clouds, shadows and
#' cirrus, plus `SAT` saturation and `EDG` edge when present; any non-zero value
#' is masked) then the indices [reconfort_indices()] (CRswir, CRre), then the
#' 36 ten-day steps and the gap rules of the training table (the very code of
#' [reconfort_predire()], not a copy), then the class. Pixels are processed by
#' blocks of rows so that memory stays bounded; a map made of several blocks is
#' identical to a one-block map.
#'
#' A pixel is `NA` in the map when its series is unusable (no valid value of an
#' index in the year), when it lies outside the oak stand (`chenaie`) or when it
#' was clear-cut in or before `annee` (`coupes`), see [reconfort_masquer()].
#'
#' **What the agreement with IOTA2 means.** While the model is trained only on
#' `synth_` or propagated labels, agreement with the IOTA2 map measures a
#' **resemblance**, not an **accuracy**: only field plots kept aside can say
#' which map is right (spec 070, criterion to amend spec 021).
#'
#' @param modele A `reconfort_modele` from [reconfort_entrainer()].
#' @param scenes_dir Directory of the already clipped MUSCATE scenes
#'   (`extracted/<tile>/<scene>/*_FRE_B*.tif` and `MASKS/`), searched
#'   recursively.
#' @param annee Observation year (the 36 steps are those of this year).
#' @param gabarit Template map (a [terra::SpatRaster] or a path): its CRS, origin,
#'   resolution and extent are those of the output. When it has the CRS of the
#'   scenes, its grid must be aligned on the grid of the scenes (offset a multiple
#'   of the pixel); a template shifted by a fraction of a pixel is refused.
#' @param sortie Path of the GeoTIFF to write.
#' @param chenaie,coupes Masks of [reconfort_masquer()] (`NULL` for none).
#' @param px_par_bloc Maximum pixels per block (default: the RECONFORT memory
#'   budget, capped).
#' @param memory_max Memory ceiling in the format of the RECONFORT chain
#'   (default: the session ceiling).
#' @param quiet Silence progress messages.
#' @return The path `sortie`, invisibly. The map has one layer of classes
#'   (`INT1U`, `NA` flag 255).
#' @export
reconfort_carte_spike <- function(modele, scenes_dir, annee, gabarit, sortie,
                                  chenaie = NULL, coupes = NULL,
                                  px_par_bloc = NULL, memory_max = .memory_ceiling(),
                                  quiet = FALSE) {
  if (!inherits(modele, "reconfort_modele")) {
    cli::cli_abort("{.arg modele} must be a {.cls reconfort_modele} (see {.fn reconfort_entrainer}).")
  }
  if (!is.numeric(annee) || length(annee) != 1L || is.na(annee)) {
    cli::cli_abort("{.arg annee} must be a single year.")
  }
  annee <- as.integer(annee)
  if (is.character(gabarit)) {
    if (!file.exists(gabarit)) cli::cli_abort("{.arg gabarit} {.path {gabarit}} does not exist.")
    gabarit <- terra::rast(gabarit)
  }
  if (!inherits(gabarit, "SpatRaster")) {
    cli::cli_abort("{.arg gabarit} must be a SpatRaster or a path.")
  }
  gabarit <- terra::rast(gabarit[[1L]])  # grille seule, sans valeurs

  scenes <- .enumerate_reconfort_s2_scenes(scenes_dir)
  an_s <- vapply(scenes, function(s) as.integer(format(s$obs_date, "%Y")), integer(1))
  scenes <- scenes[an_s == annee]
  if (!length(scenes)) {
    cli::cli_abort("No complete scene (six FRE bands) of {annee} under {.path {scenes_dir}}.")
  }
  .reconfort_carte_verifier_grille(gabarit, scenes[[1L]]$B04)

  nr <- terra::nrow(gabarit)
  nc <- terra::ncol(gabarit)
  px_max <- px_par_bloc
  if (is.null(px_max)) {
    budget <- .reconfort_chunk_px_budget(memory_max)
    px_max <- min(.RECONFORT_CARTE_PX_MAX, if (is.na(budget)) Inf else budget)
  }
  lignes <- max(1L, as.integer(floor(px_max / nc)))
  debuts <- seq.int(1L, nr, by = lignes)
  if (!quiet) {
    cli::cli_inform("RECONFORT spike map {annee}: {length(scenes)} scene{?s}, {length(debuts)} block{?s} of {lignes} row{?s}.")
  }

  dir.create(dirname(sortie), recursive = TRUE, showWarnings = FALSE)
  out <- terra::rast(gabarit)
  terra::writeStart(out, sortie, overwrite = TRUE, datatype = "INT1U",
                    NAflag = 255, names = "classe")
  fini <- FALSE
  on.exit(if (!fini) try(terra::writeStop(out), silent = TRUE), add = TRUE)
  for (d in debuts) {
    n <- min(lignes, nr - d + 1L)
    cl <- .reconfort_carte_bloc(modele, scenes, annee, gabarit, d, n, chenaie, coupes)
    terra::writeValues(out, as.numeric(cl), d, n)
  }
  out <- terra::writeStop(out)
  fini <- TRUE

  if (!isTRUE(terra::compareGeom(out, gabarit, crs = TRUE, ext = TRUE, rowcol = TRUE,
                                 res = TRUE, stopOnError = FALSE))) {
    cli::cli_abort("The written map is not aligned on {.arg gabarit}; this is a bug.")
  }
  invisible(sortie)
}

# La grille du gabarit doit tomber sur celle des scenes (meme CRS) : sinon la
# serie de chaque pixel serait un melange interpole de pixels voisins, et la
# comparaison pixel a pixel avec IOTA2 ne porterait plus sur les memes pixels.
.reconfort_carte_verifier_grille <- function(gabarit, chemin_b04) {
  ref <- terra::rast(chemin_b04)
  if (!terra::same.crs(ref, gabarit)) return(invisible(TRUE))
  r <- terra::res(ref)
  tol <- 1e-3 * min(r)
  dec <- function(a, b, p) {
    d <- (a - b) %% p
    min(d, p - d)
  }
  e1 <- terra::ext(gabarit)
  e0 <- terra::ext(ref)
  dx <- dec(e1$xmin, e0$xmin, r[1L])
  dy <- dec(e1$ymax, e0$ymax, r[2L])
  rapport <- terra::res(gabarit) / r
  if (dx > tol || dy > tol) {
    cli::cli_abort(c(
      "{.arg gabarit} is not aligned on the pixel grid of the scenes.",
      "x" = "Offset of {signif(dx, 4)} (x) and {signif(dy, 4)} (y) from the scene grid, pixel {r[1L]} x {r[2L]}.",
      "i" = "Use the IOTA2 map of the same zone as template, or resample it on the scene grid first."
    ))
  }
  if (any(abs(rapport - round(rapport)) > 1e-6 & abs(1 / rapport - round(1 / rapport)) > 1e-6)) {
    cli::cli_abort("Resolution of {.arg gabarit} ({paste(terra::res(gabarit), collapse = ' x ')}) is not a multiple or a divisor of the scene resolution.")
  }
  invisible(TRUE)
}

# Une bande lue sur la grille `tpl` (bloc du gabarit). Meme grille alignee :
# decoupe exacte, sans interpolation ; sinon reechantillonnage (bilinear pour
# une reflectance, near pour un masque).
.reconfort_carte_lire <- function(chemin, tpl, methode) {
  r <- terra::rast(chemin)
  meme <- terra::same.crs(r, tpl) && all(abs(terra::res(r) - terra::res(tpl)) < 1e-9)
  if (meme) {
    e <- terra::ext(tpl)
    ox <- ((terra::xmin(r) - e$xmin) / terra::res(r)[1L]) %% 1
    oy <- ((terra::ymax(r) - e$ymax) / terra::res(r)[2L]) %% 1
    meme <- min(ox, 1 - ox) < 1e-6 && min(oy, 1 - oy) < 1e-6
  }
  if (meme) {
    inter <- terra::intersect(terra::ext(r), terra::ext(tpl))
    if (is.null(inter)) return(rep(NA_real_, terra::ncell(tpl)))
    return(terra::values(terra::extend(terra::crop(r, tpl), tpl), mat = FALSE))
  }
  tryCatch({
    marge <- 3 * max(terra::res(r))
    p <- terra::project(terra::ext(tpl), terra::crs(tpl), terra::crs(r))
    rc <- terra::crop(r, terra::ext(p) + marge)
    terra::values(terra::project(rc, tpl, method = methode), mat = FALSE)
  }, error = function(e) rep(NA_real_, terra::ncell(tpl)))
}

# Serie longue (pixel x date) d'un bloc : masques MAJA, puis indices.
.reconfort_carte_serie <- function(scenes, tpl, ids) {
  bandes <- c("B04", "B05", "B06", "B8A", "B11", "B12")
  morceaux <- vector("list", length(scenes))
  for (i in seq_along(scenes)) {
    s <- scenes[[i]]
    b <- lapply(s[bandes], .reconfort_carte_lire, tpl = tpl, methode = "bilinear")
    names(b) <- c("B4", "B5", "B6", "B8A", "B11", "B12")
    idx <- reconfort_indices(b)
    mauvais <- rep(FALSE, terra::ncell(tpl))
    for (m in .reconfort_carte_masques(s)) {
      v <- .reconfort_carte_lire(m, tpl, "near")
      mauvais <- mauvais | is.na(v) | v != 0
    }
    idx$CRswir[mauvais] <- NA_real_
    idx$CRre[mauvais] <- NA_real_
    morceaux[[i]] <- data.frame(id_unique = ids, date = s$obs_date,
                                CRswir = idx$CRswir, CRre = idx$CRre,
                                stringsAsFactors = FALSE)
  }
  do.call(rbind, morceaux)
}

# Masques MAJA d'une scene : CLM (retenu par l'enumeration), plus SAT et EDG de
# meme resolution s'ils sont a cote. Un masque absent est ignore.
.reconfort_carte_masques <- function(scene) {
  out <- character()
  if (!is.null(scene$clm)) {
    out <- scene$clm
    for (k in c("SAT", "EDG")) {
      f <- sub("_CLM_(R[12])\\.tif$", paste0("_", k, "_\\1.tif"), scene$clm,
               ignore.case = TRUE)
      if (!identical(f, scene$clm) && file.exists(f)) out <- c(out, f)
    }
  } else if (!is.null(scene$scl)) {
    cli::cli_warn("Scene of {scene$obs_date} has a Sen2Cor SCL mask, not MAJA CLM: classes 3, 8, 9, 10, 11 are not masked here.")
  }
  out
}

# Classes (entiers, NA) des `n` lignes du gabarit a partir de la ligne `debut`.
.reconfort_carte_bloc <- function(modele, scenes, annee, gabarit, debut, n,
                                  chenaie, coupes) {
  e <- terra::ext(gabarit)
  r <- terra::res(gabarit)
  nc <- terra::ncol(gabarit)
  tpl <- terra::rast(nrows = n, ncols = nc, xmin = e$xmin, xmax = e$xmax,
                     ymin = e$ymax - (debut - 1L + n) * r[2L],
                     ymax = e$ymax - (debut - 1L) * r[2L], crs = terra::crs(gabarit))
  cellules <- (debut - 1L) * nc + seq_len(n * nc)
  ids <- as.character(cellules)
  serie <- .reconfort_carte_serie(scenes, tpl, ids)
  utile <- !(is.na(serie$CRswir) & is.na(serie$CRre))
  serie <- serie[utile, , drop = FALSE]
  classes <- rep(NA_integer_, n * nc)
  if (!nrow(serie)) return(classes)

  xy <- terra::xyFromCell(tpl, seq_len(n * nc))
  px <- data.frame(id_unique = ids, annee = annee, x = xy[, 1L], y = xy[, 2L],
                   stringsAsFactors = FALSE)
  px <- px[px$id_unique %in% unique(serie$id_unique), , drop = FALSE]
  if (!is.null(chenaie) || !is.null(coupes)) {
    px <- reconfort_masquer(px, chenaie = chenaie, coupes = coupes,
                            crs = terra::crs(gabarit))
  }
  if (!nrow(px)) return(classes)
  pred <- reconfort_predire(modele, serie[serie$id_unique %in% px$id_unique, , drop = FALSE],
                            px[c("id_unique", "annee")])
  classes[match(pred$id_unique, ids)] <- pred$classe
  classes
}
