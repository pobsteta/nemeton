# ============================================================
# houppiers.R — crown segmentation on a Canopy Height Model
# ------------------------------------------------------------
# Produces the `houppier` layer of the Marculus GeoPackage: one polygon per
# tree crown, carrying the apex height, so that a stem marked in the field
# gets its height pre-filled by a point-in-polygon on the GNSS position.
#
# The contract is set downstream (`marculus/docs/specs/couche-houppier-mnh.md`)
# and three of its rules shape the code rather than the documentation:
#
#   * heights outside 1-70 m are REJECTED by the phone, so they are not
#     produced here — an empty crown scoring 0 m would silently write nothing
#     into a marking log;
#   * overlapping crowns are FINE — the phone keeps the tallest, the one whose
#     apex physically dominates the operator. The segmentation therefore does
#     not have to partition space, and no gap-filling is attempted: a position
#     inside no crown (gap, stand edge, suppressed stem) writes nothing rather
#     than guessing the neighbouring tree;
#   * the layer must be named `houppier` by the caller — that name is a
#     contract, not a convention.
# ============================================================


# Square aggregation factor bounding a raster under `max_cells`. Same idiom as
# `.eobs_ds_agg_factor()`; kept separate because THIS one aggregates by max.
.houppier_agg_factor <- function(r, resolution, max_cells) {
  res_in <- mean(terra::res(r))
  fac <- if (is.finite(resolution) && resolution > res_in) {
    max(1L, as.integer(round(resolution / res_in)))
  } else {
    1L
  }
  nc <- terra::ncell(r) / fac^2
  if (is.finite(max_cells) && max_cells > 0 && nc > max_cells) {
    fac <- max(fac, as.integer(ceiling(sqrt(terra::ncell(r) / max_cells))))
  }
  fac
}


# Garde-fou « CHM degenere », porte ici depuis `synthetic_inventory.R` (v0.109.0).
#
# Pourquoi il manquait, et pourquoi ca compte. Un CHM mort ne fait pas echouer la
# segmentation : il rend simplement zero houppier. Une clairiere legitime et une
# prediction Open-Canopy en panne produisaient donc LE MEME OBJET VIDE, sans un
# mot. Mesure sur le projet Fordead : `chm_predicted_0_2m.tif` plafonne a
# 0,1879 m sur ses 292 millions de cellules, et `segment_houppiers()` rendait
# `0 houppiers` sans rien signaler.
#
# C'est la confusion « 0 n'est pas NA » soldee ailleurs en v0.186/v0.187.
#
# La regle est celle de `synthetic_inventory.R` transposee au raster, mais
# RESSERREE sur un point : la version d'origine exige un maximum « sous le
# plancher », ce qui signale aussi un gaulis uniforme a 4 m sous un plancher de
# 5 m -- un peuplement parfaitement legitime, pas un CHM mort. Le CHM mesure sur
# Fordead plafonne a 0,19 m, soit TROIS ORDRES DE GRANDEUR sous le plancher.
#
# On exige donc un maximum quasi nul : `max_frac` fois le plancher (0,5 m pour
# un plancher de 5 m). Une coupe rase reelle la declenche encore -- c'est voulu,
# le message invite a verifier et « zero houppier » reste alors la bonne reponse.
.houppier_chm_degenere <- function(chm, hmin, suspect_frac = 0.95,
                                   max_frac = 0.1) {
  vide <- list(suspect = FALSE, frac_low = NA_real_, chm_max = NA_real_)
  if (is.null(chm)) return(vide)
  chm_max <- suppressWarnings(
    as.numeric(terra::global(chm, "max", na.rm = TRUE)[1L, 1L]))
  if (!is.finite(chm_max)) return(vide)
  n_ok <- suppressWarnings(
    as.numeric(terra::global(!is.na(chm), "sum", na.rm = TRUE)[1L, 1L]))
  if (!is.finite(n_ok) || n_ok <= 0) return(vide)
  n_low <- suppressWarnings(
    as.numeric(terra::global(chm < hmin, "sum", na.rm = TRUE)[1L, 1L]))
  frac_low <- if (is.finite(n_low)) n_low / n_ok else NA_real_

  suspect <- isTRUE(frac_low >= suspect_frac) && chm_max < hmin * max_frac
  if (suspect) {
    cli::cli_warn(c(
      "!" = "CHM appears degenerate: {round(100 * frac_low)}% of valid cells are \\
             below {hmin} m and the CHM maximum is only {round(chm_max, 3)} m \\
             \u2014 {round(100 * max_frac)}% of that floor or less.",
      "i" = "An all-zero or failed height prediction returns the SAME empty crown \\
             layer as a genuine clearing \u2014 hence this warning.",
      "i" = "Check the height model before reading {.val 0 crowns} as {.val no trees}."
    ))
  }
  list(suspect = suspect, frac_low = frac_low, chm_max = chm_max)
}


# Estampille le verdict sur la sortie, quelle qu'elle soit (vide comprise) :
# c'est le cas VIDE qui a le plus besoin de porter le diagnostic.
.houppier_flag <- function(x, degenere) {
  attr(x, "chm_suspect") <- isTRUE(degenere$suspect)
  if (isTRUE(degenere$suspect)) {
    attr(x, "chm_max") <- degenere$chm_max
    attr(x, "chm_frac_low") <- degenere$frac_low
  }
  x
}


#' Segment tree crowns on a Canopy Height Model
#'
#' @description
#' Delineates individual tree crowns from a CHM and returns one polygon per
#' crown with its apex height. This is the `houppier` layer consumed by the
#' Marculus marking application, where a stem's height is pre-filled by a
#' point-in-polygon on the GNSS position.
#'
#' @details
#' **Working resolution is decided here, not by the caller.** A crown is 3 to
#' 10 m across; segmenting a 0.20 m CHM neither adds silvicultural information
#' nor fits in memory — the Couchey CHM is 418 million cells. The CHM is
#' therefore aggregated to `resolution` (default 0.5 m) before anything else,
#' which divides the cost by 6 to 25, and further if the result would still
#' exceed `max_cells`.
#'
#' The aggregation uses **`max`, not `mean`**: the apexes are precisely what
#' local-maximum detection looks for, and a smoothing statistic would flatten
#' them away. This costs a slight upward bias on `h_max` (the tallest cell of
#' each aggregate wins) — deliberate, and preferable to losing a tree.
#'
#' Heights are read back with a zonal statistic on the raster
#' ([terra::zonal()]), never with a global `values()` or `extract()`: the same
#' innocent-looking call cost a 3 h 20 pipeline run on 2026-08-22.
#'
#' Crowns may overlap, and that is not a defect — see the file header.
#'
#' @param chm Canopy Height Model: a `SpatRaster` or a path readable by
#'   [terra::rast()]. Heights in **metres**, in a projected CRS.
#' @param aoi Optional `sf`/`sfc` clipping extent (typically the stand being
#'   marked). Reprojected to the CHM's CRS, then used to crop **and** mask.
#'   Cropping first is what bounds the memory of everything below.
#' @param ws Local-maximum search window, in metres. Roughly the crown radius
#'   of the dominant trees: too small splits a crown into several, too large
#'   merges neighbours.
#' @param hmin Minimum apex height, in metres. Below it, no tree is located.
#' @param algorithme `"dalponte"` (default), `"silva"` or `"watershed"`. The
#'   first two grow regions from located apexes; `"watershed"` ignores them and
#'   floods the inverted surface.
#' @param emprise How `aoi` is honoured. `"intersecte"` (default) segments on
#'   the AOI grown by `marge_m`, then keeps **whole** every crown that meets the
#'   AOI: a tree on the boundary is a tree, not a fraction of one. `"decoupe"`
#'   lets the AOI cut the raster, so boundary crowns are truncated — measured on
#'   Couchey, 4.7% of them, losing 29% of their area and 1.6 m of height.
#'   Use it only when a strict geometric clip is what you want.
#' @param marge_m Metres by which the AOI is grown before segmentation, so a
#'   crown standing on the boundary is complete. `NULL` (default) means
#'   `3 * ws`. Ignored when `emprise = "decoupe"`.
#' @param resolution Working resolution in metres (default `0.5`). Ignored when
#'   the CHM is already coarser.
#' @param max_cells Backstop cell cap for the working raster (default `2e7`).
#'   A CHM that is still too large after `resolution` is aggregated further.
#' @param h_range Admissible apex heights, in metres (default `c(1, 70)`).
#'   Crowns outside are dropped rather than shipped — the phone rejects them.
#'
#' @return An `sf` of POLYGON, one row per crown, with:
#'   \describe{
#'     \item{`houppier_id`}{integer, 1..n, ordered by decreasing `h_max`.}
#'     \item{`h_max`}{apex height in metres — the canonical Marculus name.}
#'     \item{`surface_m2`}{crown area in square metres.}
#'   }
#'   Zero crowns yields a zero-row `sf` with those columns, not `NULL`: the
#'   caller writes an empty layer rather than a missing one.
#'
#' @examples
#' \dontrun{
#' crowns <- segment_houppiers(
#'   "cache/layers/opencanopy/chm_predicted_0_2m.tif",
#'   aoi = ugf, ws = 5, hmin = 5
#' )
#' sf::st_write(crowns, "marculus.gpkg", layer = "houppier", append = FALSE)
#' }
#'
#' @seealso [extract_h_dom()] for the stand-level dominant height, which
#'   answers a different question on the same raster.
#' @export
segment_houppiers <- function(chm        = NULL,
                              aoi        = NULL,
                              ws         = 5,
                              hmin       = 5,
                              algorithme = c("dalponte", "silva", "watershed",
                                             "lsms"),
                              emprise    = c("intersecte", "decoupe"),
                              marge_m    = NULL,
                              resolution = 0.5,
                              max_cells  = 2e7,
                              h_range    = c(1, 70),
                              image      = NULL,
                              usage      = c("martelage", "couvert"),
                              lsms       = list(),
                              resolution_image = NULL,
                              budget_s   = 600) {
  algorithme <- match.arg(algorithme)
  emprise    <- match.arg(emprise)
  usage      <- match.arg(usage)

  # `usage` ne concerne que LSMS : la voie CHM produit toujours une hauteur,
  # c'est son objet. Le dire plutot que de l'ignorer en silence.
  if (!identical(algorithme, "lsms") && !identical(usage, "martelage")) {
    cli::cli_abort(c(
      "{.arg usage} only applies to {.code algorithme = \"lsms\"}.",
      i = "The CHM route always measures a height \u2014 that is what it is for."
    ))
  }
  if (identical(algorithme, "lsms")) {
    lsms <- utils::modifyList(.LSMS_DEFAUTS, if (is.null(lsms)) list() else lsms)
    if (is.null(image)) {
      cli::cli_abort(c(
        "{.code algorithme = \"lsms\"} segments an IMAGE, not the CHM.",
        i = "Pass {.arg image}: an orthophoto (IRC or RGB) covering the {.arg aoi}."
      ))
    }
    # D2 \u2014 deux usages separes, aucun entre-deux silencieux. Sans CHM il n'y a
    # pas de hauteur, et une couche sans hauteur est ignoree SANS UN MOT par
    # Marculus : la refuser vaut mieux que la livrer.
    if (identical(usage, "martelage") && is.null(chm)) {
      cli::cli_abort(c(
        "{.code usage = \"martelage\"} requires a CHM: LSMS delineates, it does not measure height.",
        i = "Marculus ignores any feature without a readable height, silently.",
        i = "Pass {.arg chm}, or use {.code usage = \"couvert\"} \u2014 which owns up to producing none."
      ))
    }
  } else if (is.null(chm)) {
    cli::cli_abort("{.arg chm} is required for {.code algorithme = \"{algorithme}\"}.")
  }
  if (is.null(marge_m)) marge_m <- 3 * ws
  if (!is.numeric(marge_m) || length(marge_m) != 1L || !is.finite(marge_m) ||
      marge_m < 0) {
    cli::cli_abort("{.arg marge_m} must be a single non-negative number of metres.")
  }

  if (!identical(algorithme, "lsms") && !requireNamespace("lidR", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg lidR} is required to segment crowns on a CHM.",
      i = "Install it: {.code install.packages('lidR')}."
    ))
  }
  if (!is.numeric(ws) || length(ws) != 1L || !is.finite(ws) || ws <= 0) {
    cli::cli_abort("{.arg ws} must be a single positive number of metres.")
  }
  if (!is.numeric(hmin) || length(hmin) != 1L || !is.finite(hmin)) {
    cli::cli_abort("{.arg hmin} must be a single number of metres.")
  }
  if (!is.numeric(h_range) || length(h_range) != 2L || h_range[1] >= h_range[2]) {
    cli::cli_abort("{.arg h_range} must be two increasing numbers, in metres.")
  }

  if (!is.null(chm)) {
    if (is.character(chm)) {
      if (!file.exists(chm)) cli::cli_abort("CHM not found: {.path {chm}}.")
      chm <- terra::rast(chm)
    }
    if (!inherits(chm, "SpatRaster")) {
      cli::cli_abort("{.arg chm} must be a {.cls SpatRaster} or a path to one.")
    }
    if (terra::nlyr(chm) > 1L) chm <- chm[[1L]]
  }

  # Re-stamp a degenerate WKT with its authority code. The Couchey CHM carries
  # the NAME "EPSG:2154" but no authority, so `sf::st_crs(x)$epsg` reads NA and
  # the GeoPackage would ship a CRS the phone cannot match to a known system.
  # Same class of defect as the cached WMS/LiDAR rasters — recoverable, and
  # cheaper to fix here than to explain downstream.
  if (!is.null(chm)) {
    chm <- .normalize_crs(chm)

    # `ws` and `hmin` are metres; a geographic CRS would silently read them as
    # degrees and locate one tree per stand.
    if (isTRUE(terra::is.lonlat(chm))) {
      cli::cli_abort(c(
        "The CHM is in a geographic CRS (degrees).",
        i = "{.arg ws} and {.arg hmin} are metres — reproject to a metric CRS first."
      ))
    }
  }

  # LSMS a sa propre geometrie de travail : il segmente l'IMAGE, pas le CHM.
  # L'AOI est donc interpretee ici (meme semantique `intersecte`/`decoupe`) puis
  # passee telle quelle, sans toucher au CHM qui ne sert plus qu'a la hauteur.
  if (identical(algorithme, "lsms")) {
    aoi_sel <- NULL
    aoi_v   <- NULL
    if (!is.null(aoi)) {
      ref <- if (!is.null(chm)) terra::crs(chm) else NULL
      aoi_sf <- sf::st_as_sf(aoi)
      if (!is.null(ref)) aoi_sf <- sf::st_transform(aoi_sf, ref)
      if (identical(emprise, "intersecte")) {
        aoi_sel <- aoi_sf
        aoi_v   <- terra::vect(sf::st_buffer(aoi_sf, marge_m))
      } else {
        aoi_v <- terra::vect(aoi_sf)
      }
    }
    return(.houppier_lsms(chm, image, aoi_sel, aoi_v, usage, lsms,
                          resolution_image, budget_s, h_range))
  }

  # 1. Clip FIRST. Everything below is sized by what survives here.
  #
  # Two ways to honour an `aoi`, and they are NOT interchangeable:
  #   * "decoupe"    — the AOI cuts the raster, so a crown straddling the edge
  #                    is cut with it. Measured on Couchey: 1 047 crowns (4.7 %)
  #                    touch the boundary, with a median area of 75 m² against
  #                    106 m² inside and a median `h_max` of 16.1 m against
  #                    17.7 m. A cut crown is a *smaller* crown AND a *shorter*
  #                    one — its apex may well be on the other side.
  #   * "intersecte" — segment on the AOI GROWN by `marge_m`, then KEEP WHOLE
  #                    every crown that meets the AOI. A tree on the boundary is
  #                    a tree, not a fraction of one, and the stem marked under
  #                    it deserves its real height.
  aoi_sel <- NULL
  if (!is.null(aoi)) {
    aoi_sf <- sf::st_transform(sf::st_as_sf(aoi), terra::crs(chm))
    aoi_v  <- terra::vect(aoi_sf)
    # Check the overlap BEFORE cropping: `terra::crop()` aborts on disjoint
    # extents with "[crop] extents do not overlap", which names neither the
    # argument at fault nor what the caller should do about it.
    if (!terra::relate(terra::ext(chm), terra::ext(aoi_v), "intersects")) {
      cli::cli_abort(c(
        "The {.arg aoi} does not intersect the CHM.",
        i = "Check they describe the same site: the CHM covers {.val {as.character(terra::ext(chm))}}."
      ))
    }
    if (identical(emprise, "intersecte")) {
      aoi_sel <- aoi_sf                      # kept for the final selection
      aoi_v   <- terra::vect(sf::st_buffer(aoi_sf, marge_m))
    }
    chm <- terra::crop(chm, aoi_v, mask = TRUE)
    if (terra::ncell(chm) == 0L) {
      cli::cli_abort("The {.arg aoi} does not intersect the CHM.")
    }
  }

  # 2. Working resolution — by max, to keep the apexes (see @details).
  fac <- .houppier_agg_factor(chm, resolution, max_cells)
  if (fac > 1L) {
    chm <- terra::aggregate(chm, fact = fac, fun = "max", na.rm = TRUE)
  }

  # 2ter. Le CHM est-il exploitable ? Verdict AVANT la segmentation, sur le CHM
  # effectivement utilise (rogne puis agrege), et estampille sur la sortie.
  degenere <- .houppier_chm_degenere(chm, hmin)

  # 2bis. lidR ne segmente QUE depuis la memoire.
  #
  #   dalponte2016() : if (raster_is_proxy(chm) & missing(bbox))
  #                      stop("Cannot segment the trees from a raster stored on disk...")
  #
  # C'est la cause reelle des echecs poursuivis par deux rapports (2026-08-23
  # et 2026-08-26), et elle explique pourquoi ils paraissaient capricieux :
  # `terra::aggregate()` rend son resultat EN MEMOIRE, si bien que tout raster
  # assez fin pour etre agrege passait, et qu'un raster deja a la bonne
  # resolution — facteur 1, donc pas d'agregation — restait sur disque et
  # echouait. Une dalle LiDAR HD de 4 M cellules echouait la ou un MNH de
  # 11,9 M reussissait : ce n'etait pas une question de taille.
  #
  # Le cout est deja borne par `max_cells` : a 2e7, ~160 Mo, du meme ordre que
  # ce que `locate_trees()` alloue ensuite.
  if (!terra::inMemory(chm)) {
    terra::set.values(chm)
  }

  # 3. Apexes, then crowns around them.
  seg <- if (identical(algorithme, "watershed")) {
    lidR::watershed(chm, th_tree = hmin)()
  } else {
    tops <- lidR::locate_trees(chm, lidR::lmf(ws = ws, hmin = hmin))
    if (is.null(tops) || nrow(tops) == 0L)
      return(.houppier_flag(.houppier_empty(chm), degenere))
    # Garde suggeree par le rapport du 2026-08-23 : la segmentation echouait
    # sur « st_crs(x) == st_crs(y) is not TRUE », leve par un stopifnot() de
    # `sf` DEPUIS lidR — un message qui decrit un symptome, pas une cause.
    # L'hypothese du rapport : a grande echelle, `locate_trees()` peut rendre
    # un objet non vide mais SANS CRS ; le garde ci-dessus ne couvre que le cas
    # vide, et la comparaison suivante echoue alors avec ce message.
    #
    # Non reproduit ici (46 158 houppiers sur le raster incrimine de 418 M
    # cellules, en 71 s) et le diff montre que le code n'avait pas change entre
    # la version qui passait et celle qui echouait — mais le mode de defaillance
    # est reel et sa parade coute deux lignes. Un CRS absent est REPARE depuis
    # le raster, un CRS *different* est une anomalie qu'on nomme plutot que de
    # la laisser sortir en langage `sf`.
    if (is.na(sf::st_crs(tops))) {
      sf::st_crs(tops) <- sf::st_crs(terra::crs(chm))
    } else if (sf::st_crs(tops) != sf::st_crs(terra::crs(chm))) {
      cli::cli_abort(c(
        "Crown apexes came back in a different CRS than the CHM.",
        i = "CHM: {.val {sf::st_crs(terra::crs(chm))$input}}; apexes: {.val {sf::st_crs(tops)$input}}.",
        i = "This is a {.pkg lidR} anomaly, not a CHM defect — report it with the raster size."
      ))
    }
    if (identical(algorithme, "dalponte")) {
      lidR::dalponte2016(chm, tops, th_tree = hmin)()
    } else {
      lidR::silva2016(chm, tops, ID = "treeID")()
    }
  }
  if (is.null(seg) || all(is.na(terra::minmax(seg)))) {
    return(.houppier_flag(.houppier_empty(chm), degenere))
  }

  # 4. Apex height per crown — zonal, never a global read.
  h <- terra::zonal(chm, seg, fun = "max", na.rm = TRUE)
  names(h) <- c("zone", "h_max")

  polys <- sf::st_as_sf(terra::as.polygons(seg, dissolve = TRUE))
  names(polys)[1L] <- "zone"
  polys <- merge(polys, h, by = "zone", all.x = TRUE)

  # 5. The downstream contract: nothing outside 1-70 m leaves this function.
  keep <- !is.na(polys$h_max) &
    polys$h_max >= h_range[1] & polys$h_max <= h_range[2]
  polys <- polys[keep, , drop = FALSE]
  if (nrow(polys) == 0L) return(.houppier_flag(.houppier_empty(chm), degenere))

  # 5b. Keep the crowns that MEET the AOI, whole. Selection, never clipping:
  # `st_filter()` returns the geometry untouched, `st_intersection()` would cut
  # it — which is the very thing this mode exists to avoid.
  if (!is.null(aoi_sel)) {
    polys <- sf::st_filter(polys, sf::st_union(sf::st_geometry(aoi_sel)),
                           .predicate = sf::st_intersects)
    if (nrow(polys) == 0L) return(.houppier_flag(.houppier_empty(chm), degenere))
  }

  polys <- polys[order(-polys$h_max), , drop = FALSE]
  out <- sf::st_sf(
    houppier_id = seq_len(nrow(polys)),
    h_max       = as.numeric(polys$h_max),
    surface_m2  = as.numeric(sf::st_area(polys)),
    geometry    = sf::st_geometry(polys)
  )
  sf::st_agr(out) <- "constant"
  .houppier_flag(out, degenere)
}


# Zero crowns is a legitimate answer (a clearing, a stand under `hmin`): give
# the caller the same columns so it writes an EMPTY layer, not a missing one.
.houppier_empty <- function(chm) {
  sf::st_sf(
    houppier_id = integer(0),
    h_max       = numeric(0),
    surface_m2  = numeric(0),
    geometry    = sf::st_sfc(crs = sf::st_crs(terra::crs(chm)))
  )
}
