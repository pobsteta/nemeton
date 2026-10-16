#' Video Inventory (Groma)
#'
#' @description
#' Platform side of the Groma video inventory: a smartphone video replaces the
#' manual measurement of a circular plot (calliper, compass, tape). The Groma
#' Android application computes a **provisional** inventory in the field, the
#' Groma server a **definitive** one. nemeton carries every platform step:
#' \itemize{
#'   \item \code{\link{creer_projet_inventaire_video}}: the field GeoPackage
#'     (\code{inventaire_video.gpkg}), the per-plot DTM/CHM GeoTIFFs and the
#'     QField project;
#'   \item \code{\link{numeroter_arbres}}: the Groma numbering rule;
#'   \item \code{\link{affecter_hauteur_houppier}}: tree height from the
#'     segmented crowns;
#'   \item \code{\link{rapprocher_arbres}}: provisional to definitive
#'     reconciliation, without losing any field attribute;
#'   \item \code{\link{valider_inventaire_video}} and
#'     \code{\link{importer_inventaire_video}}: validation, aggregation, NDP
#'     tagging and merge into the project field data;
#'   \item \code{\link{renvoyer_inventaire_video}}: new QField project with
#'     the trees still to complete or to check;
#'   \item \code{\link{groma_etat_placettes}} and
#'     \code{\link{groma_telecharger_resultats}}: client of the Groma server.
#' }
#'
#' The GeoPackage schema has a single source, shared with the Groma Python and
#' Kotlin code: \code{inst/inventaire_video/inventaire_video.schema.json}
#' (see \code{\link{schema_inventaire_video}}). Spec 061.
#'
#' @name inventaire_video
NULL


# ---- Référentiels (inst/inventaire_video) -----------------------------

.iv_fichier <- function(nom) {
  chemin <- system.file("inventaire_video", nom, package = "nemeton")
  if (!nzchar(chemin)) {
    cli::cli_abort("File {.file inventaire_video/{nom}} not found in the nemeton installation.")
  }
  chemin
}

.iv_schema_brut <- function() {
  jsonlite::read_json(.iv_fichier("inventaire_video.schema.json"),
                      simplifyVector = FALSE)
}

# Référentiel des essences d'arbre (code, libellé, libellé BD Forêt V2).
.iv_essences <- function() {
  jsonlite::fromJSON(.iv_fichier("essences_bdforet_v2.json"))$essences
}

# Type de peuplement nemeton déduit d'un code d'essence d'arbre (décision 1).
.iv_espece_depuis_essence <- function(essence_arbre, region = "BFC") {
  ess <- .iv_essences()
  lib <- ess$bdforet[match(essence_arbre, ess$code)]
  vapply(lib, function(l) {
    if (is.na(l)) NA_character_ else map_bdforet_essence(l, region = region)
  }, character(1), USE.NAMES = FALSE)
}

# Colonne d'une table, NA si elle est absente.
.iv_col <- function(df, nom, defaut = NA) {
  if (nom %in% names(df)) df[[nom]] else rep(defaut, nrow(df))
}

.iv_vide <- function(x) is.na(x) | !nzchar(trimws(as.character(x)))


#' Video inventory GeoPackage schema
#'
#' Reads the schema of \code{inventaire_video.gpkg}, shared with the Groma
#' Python and Kotlin code, and returns it as field descriptors in the format of
#' \code{\link{get_placette_schema}} (\code{name}, \code{type}, \code{widget},
#' \code{qgis_widget}, \code{label}, \code{domain}, \code{required},
#' \code{min}, \code{max}, \code{default}), plus \code{readonly},
#' \code{hidden} and, for \code{essence_arbre}, \code{labels} (code to label).
#'
#' @param couche Character or \code{NULL}. A layer name (\code{"placettes"},
#'   \code{"centres_mesures"}, \code{"cibles"}, \code{"arbres"},
#'   \code{"detections"}, \code{"houppiers"}, and the read-only
#'   \code{"parcelles"}, \code{"ugf"} and \code{"projet"} of schema 1.2.0;
#'   \code{"projet"} has no geometry). \code{NULL} (default) returns every
#'   layer.
#'
#' @return For one layer, a list of field descriptors with the attributes
#'   \code{geometrie}, \code{index_spatial} and \code{lecture_seule}. Without
#'   \code{couche}, a named list of those, with the attributes
#'   \code{version}, \code{crs}, \code{domaines} and \code{rasters}.
#'
#' @section Lifecycle:
#' Experimental (spec 061).
#'
#' @examples
#' arbres <- schema_inventaire_video("arbres")
#' vapply(arbres, `[[`, character(1), "name")
#' attr(arbres, "index_spatial")  # FALSE
#'
#' @export
schema_inventaire_video <- function(couche = NULL) {
  brut <- .iv_schema_brut()
  noms <- vapply(brut$couches, `[[`, character(1), "nom")
  if (!is.null(couche)) {
    couche <- match.arg(couche, noms)
    return(.iv_couche_descripteurs(brut$couches[[match(couche, noms)]], brut$domaines))
  }
  out <- lapply(brut$couches, .iv_couche_descripteurs, domaines = brut$domaines)
  names(out) <- noms
  attr(out, "version") <- brut$version
  attr(out, "crs") <- as.integer(brut$crs)
  attr(out, "domaines") <- lapply(brut$domaines, unlist)
  attr(out, "rasters") <- brut$rasters
  out
}

.iv_couche_descripteurs <- function(couche, domaines) {
  types <- c(TEXT = "character", REAL = "double", INTEGER = "integer",
             DATETIME = "datetime")
  champs <- lapply(couche$colonnes, function(col) {
    type <- unname(types[col$type]) %||% "character"
    domaine <- if (!is.null(col$domaine)) unlist(domaines[[col$domaine]]) else NULL
    etiquettes <- NULL
    if (identical(col$domaine_externe, "essences_bdforet_v2")) {
      ess <- .iv_essences()
      domaine <- ess$code
      etiquettes <- stats::setNames(ess$libelle, ess$code)
    }
    widget <- if (isTRUE(col$cache)) {
      "hidden"
    } else if (!is.null(domaine)) {
      "value_map"
    } else if (identical(col$widget, "photo")) {
      "photo"
    } else if (identical(type, "datetime")) {
      "datetime"
    } else if (type %in% c("double", "integer") && (!is.null(col$min) || !is.null(col$max))) {
      "range"
    } else {
      "text"
    }
    f <- if (identical(widget, "hidden")) {
      list(name = col$nom, type = type, widget = "hidden", qgis_widget = "Hidden",
           label = col$nom, domain = domaine, required = isTRUE(col$requis),
           min = NA_real_, max = NA_real_, default = col$defaut)
    } else {
      .field(col$nom, type, widget, label = col$nom, domain = domaine,
             required = isTRUE(col$requis),
             min = col$min %||% NA_real_, max = col$max %||% NA_real_,
             default = col$defaut)
    }
    f$readonly <- isTRUE(col$lecture_seule) || isTRUE(couche$lecture_seule)
    f$hidden <- isTRUE(col$cache)
    f$labels <- etiquettes
    f
  })
  attr(champs, "geometrie") <- couche$geometrie
  attr(champs, "index_spatial") <- isTRUE(couche$index_spatial)
  attr(champs, "lecture_seule") <- isTRUE(couche$lecture_seule)
  champs
}


# ---- Numérotation -----------------------------------------------------

#' Number the trees of a circular plot (Groma rule)
#'
#' Applies the Groma numbering rule, shared with the Python and Kotlin
#' implementations (common cases: \code{tests/testthat/fixtures/numerotation}).
#' Trees are retained within \code{rayon_m} and from \code{seuil_diam_cm}
#' (bounds included). Number 1 is the closest of the visible trees whose
#' azimuth is within \code{tolerance_deg} of the smallest visible azimuth
#' (a trunk is hidden when a closer trunk crosses the line of sight). The
#' others follow clockwise; trees whose relative azimuth is within the
#' tolerance form a group, numbered from the closest.
#'
#' @param x,y Numeric. Horizontal offsets from the plot centre (m), \code{x}
#'   towards east, \code{y} towards **geographic** north (rotate Lambert-93
#'   offsets by the meridian convergence first).
#' @param dbh_cm Numeric. Diameter at 1.30 m (cm).
#' @param id Character. Stable tree identifiers (uuid), compared byte-wise.
#' @param rayon_m Plot radius (m). Default 20.
#' @param seuil_diam_cm Minimal diameter (cm). Default 7.5.
#' @param unite_azimut \code{"deg"} or \code{"gr"}: unit of the returned
#'   azimuth.
#' @param tolerance_deg Azimuth tie tolerance, always in degrees. Default 1.
#'
#' @return A data.frame with \code{id}, \code{tree_id} (character, \code{NA}
#'   when excluded), \code{exclusion} (\code{NA}, \code{"hors_rayon"},
#'   \code{"sous_seuil"}), \code{visible}, \code{azimut} (plot unit) and
#'   \code{distance_m}, in the input order.
#'
#' @section Lifecycle:
#' Experimental (spec 061).
#'
#' @examples
#' numeroter_arbres(x = c(1, 0, -3), y = c(5, 8, 2), dbh_cm = c(30, 25, 40),
#'                  id = c("a", "b", "c"))
#'
#' @export
numeroter_arbres <- function(x, y, dbh_cm, id,
                             rayon_m = 20, seuil_diam_cm = 7.5,
                             unite_azimut = c("deg", "gr"),
                             tolerance_deg = 1) {
  unite_azimut <- match.arg(unite_azimut)
  n <- length(id)
  stopifnot(length(x) == n, length(y) == n, length(dbh_cm) == n)
  if (anyDuplicated(id)) cli::cli_abort("Duplicated tree identifiers.")
  eps <- 1e-9
  id <- as.character(id)
  d <- sqrt(x^2 + y^2)
  az <- (atan2(x, y) * 180 / pi) %% 360
  exclusion <- ifelse(d > rayon_m + eps, "hors_rayon",
                      ifelse(dbh_cm < seuil_diam_cm - eps, "sous_seuil", NA_character_))
  eligible <- is.na(exclusion)

  # Visibilité : un tronc plus proche, traversé par la ligne de vue, masque.
  masque <- function(i) {
    for (j in which(eligible)) {
      if (j == i) next
      r_j <- dbh_cm[j] / 200
      if (d[j] >= d[i] || d[j] <= r_j) next
      l2 <- x[i]^2 + y[i]^2
      t <- if (l2 == 0) 0 else max(0, min(1, (x[j] * x[i] + y[j] * y[i]) / l2))
      if (sqrt((x[j] - t * x[i])^2 + (y[j] - t * y[i])^2) < r_j) return(TRUE)
    }
    FALSE
  }
  visible <- rep(FALSE, n)
  for (i in which(eligible)) visible[i] <- !masque(i)

  tree_id <- rep(NA_character_, n)
  if (any(visible)) {
    # Comparaisons d'identifiants en octets (même ordre que Python et Kotlin).
    rang_id <- .rang_octets(id)
    vis <- which(visible)
    az_min <- min(az[vis])
    cand <- vis[az[vis] - az_min < tolerance_deg]
    premier <- cand[order(d[cand], az[cand], rang_id[cand])][1]
    rel <- (az - az[premier]) %% 360
    rel[cand] <- 0
    autres <- setdiff(which(eligible), premier)
    autres <- autres[order(rel[autres], d[autres], rang_id[autres])]
    ordre <- premier
    k <- 1
    while (k <= length(autres)) {
      ancre <- rel[autres[k]]
      j <- k
      while (j <= length(autres) && rel[autres[j]] - ancre < tolerance_deg) j <- j + 1
      groupe <- autres[k:(j - 1)]
      ordre <- c(ordre, groupe[order(d[groupe], rel[groupe], rang_id[groupe])])
      k <- j
    }
    tree_id[ordre] <- as.character(seq_along(ordre))
  }

  azimut <- if (unite_azimut == "gr") az / 0.9 else az
  data.frame(id = id, tree_id = tree_id, exclusion = exclusion,
             visible = visible, azimut = azimut, distance_m = d,
             stringsAsFactors = FALSE)
}

# Rang des chaînes dans l'ordre de leurs octets UTF-8 (indépendant de la
# locale, comme les comparaisons Python et Kotlin).
.rang_octets <- function(s) {
  cle <- vapply(s, function(v) {
    paste(sprintf("%03d", as.integer(charToRaw(enc2utf8(v)))), collapse = "")
  }, character(1), USE.NAMES = FALSE)
  rank(cle, ties.method = "first")
}

# Décalage Lambert-93 -> repère du nord géographique : un vecteur d'azimut
# quadrillage `a` a pour azimut géographique `a + convergence`.
.offsets_geographiques <- function(dx, dy, convergence_deg) {
  g <- convergence_deg * pi / 180
  list(x = dx * cos(g) + dy * sin(g), y = -dx * sin(g) + dy * cos(g))
}

# Convergence des méridiens Lambert-93, gamma = n (lon - 3°).
.convergence_lambert93 <- function(points) {
  lon <- sf::st_coordinates(sf::st_transform(sf::st_geometry(points), 4326))[, 1]
  0.7256077650532670 * (lon - 3)
}


# ---- Hauteurs par houppier --------------------------------------------

#' Assign tree heights from segmented crowns
#'
#' Point-in-polygon on the trunk position: a tree takes the apex height
#' (\code{h_max}) of the crown that contains it, the highest one when crowns
#' overlap. A trunk on a crown boundary is inside. Nothing is assigned outside
#' any crown (no fallback on the nearest crown), crowns whose height is outside
#' \code{[h_min, h_max]} are ignored, and a measured height
#' (\code{h_source = "mesuree"}) is never overwritten. A CHM-derived height
#' (\code{"mnh"}) is recomputed: a tree that no longer falls in a valid crown
#' gets \code{h_m = NA}, \code{h_source = "aucune"}.
#'
#' @param arbres sf POINT of trees, optionally with \code{h_m},
#'   \code{h_source} and \code{houppier_id}.
#' @param houppiers sf POLYGON of crowns with \code{houppier_id} and
#'   \code{h_max}, as returned by \code{\link{segment_houppiers}}.
#' @param h_min,h_max Admissible crown heights (m). Defaults 1 and 70.
#'
#' @return \code{arbres} with \code{h_m}, \code{h_source} and
#'   \code{houppier_id} filled in.
#'
#' @section Lifecycle:
#' Experimental (spec 061).
#'
#' @examples
#' library(sf)
#' crowns <- st_sf(houppier_id = 1:2, h_max = c(24.5, 31),
#'                 geometry = st_sfc(st_buffer(st_point(c(0, 0)), 3),
#'                                   st_buffer(st_point(c(4, 0)), 3)))
#' trees <- st_sf(tree_id = c("1", "2"),
#'                geometry = st_sfc(st_point(c(2, 0)), st_point(c(10, 0))))
#' affecter_hauteur_houppier(trees, crowns)
#'
#' @export
affecter_hauteur_houppier <- function(arbres, houppiers, h_min = 1, h_max = 70) {
  if (!inherits(arbres, "sf")) cli::cli_abort("{.arg arbres} must be an sf object.")
  if (!inherits(houppiers, "sf")) cli::cli_abort("{.arg houppiers} must be an sf object.")
  manquantes <- setdiff(c("houppier_id", "h_max"), names(houppiers))
  if (length(manquantes)) {
    cli::cli_abort("{.arg houppiers} is missing column{?s} {.val {manquantes}}.")
  }
  n <- nrow(arbres)
  h_m <- as.numeric(.iv_col(arbres, "h_m", NA_real_))
  h_source <- as.character(.iv_col(arbres, "h_source", NA_character_))
  houppier_id <- as.integer(.iv_col(arbres, "houppier_id", NA_integer_))

  valides <- houppiers[!is.na(houppiers$h_max) & houppiers$h_max >= h_min &
                         houppiers$h_max <= h_max, ]
  if (!is.na(sf::st_crs(arbres)) && !is.na(sf::st_crs(valides)) &&
      sf::st_crs(arbres) != sf::st_crs(valides)) {
    valides <- sf::st_transform(valides, sf::st_crs(arbres))
  }
  a_traiter <- which(is.na(h_source) | h_source != "mesuree")
  if (length(a_traiter)) {
    # st_intersects : un tronc sur le bord est dedans (st_within l'exclurait).
    contient <- if (nrow(valides)) {
      sf::st_intersects(sf::st_geometry(arbres)[a_traiter], sf::st_geometry(valides))
    } else {
      replicate(length(a_traiter), integer(0), simplify = FALSE)
    }
    for (k in seq_along(a_traiter)) {
      i <- a_traiter[k]
      cand <- contient[[k]]
      if (length(cand)) {
        meilleur <- cand[which.max(valides$h_max[cand])]
        h_m[i] <- valides$h_max[meilleur]
        h_source[i] <- "mnh"
        houppier_id[i] <- as.integer(valides$houppier_id[meilleur])
      } else {
        h_m[i] <- NA_real_
        h_source[i] <- "aucune"
        houppier_id[i] <- NA_integer_
      }
    }
  }
  arbres$h_m <- h_m
  arbres$h_source <- h_source
  arbres$houppier_id <- houppier_id
  arbres
}


# ---- Rapprochement provisoire -> définitif ----------------------------

# Affectation de coût minimal (méthode hongroise, potentiels), matrice
# rectangulaire complétée au carré par le coût `interdit`. Renvoie, pour
# chaque ligne, la colonne affectée (NA pour une colonne fictive).
.affectation_optimale <- function(cout, interdit) {
  n <- nrow(cout)
  m <- ncol(cout)
  k <- max(n, m)
  if (k == 0) return(integer(0))
  a <- matrix(interdit, k, k)
  a[seq_len(n), seq_len(m)] <- cout
  u <- numeric(k + 1)
  v <- numeric(k + 1)
  p <- integer(k + 1)   # p[j + 1] : ligne affectée à la colonne j (0 = libre)
  way <- integer(k + 1)
  for (i in seq_len(k)) {
    p[1] <- i
    j0 <- 0L
    minv <- rep(Inf, k + 1)
    used <- rep(FALSE, k + 1)
    repeat {
      used[j0 + 1] <- TRUE
      i0 <- p[j0 + 1]
      delta <- Inf
      j1 <- 0L
      for (j in seq_len(k)) {
        if (!used[j + 1]) {
          cur <- a[i0, j] - u[i0 + 1] - v[j + 1]
          if (cur < minv[j + 1]) {
            minv[j + 1] <- cur
            way[j + 1] <- j0
          }
          if (minv[j + 1] < delta) {
            delta <- minv[j + 1]
            j1 <- j
          }
        }
      }
      for (j in 0:k) {
        if (used[j + 1]) {
          u[p[j + 1] + 1] <- u[p[j + 1] + 1] + delta
          v[j + 1] <- v[j + 1] - delta
        } else {
          minv[j + 1] <- minv[j + 1] - delta
        }
      }
      j0 <- j1
      if (p[j0 + 1] == 0L) break
    }
    repeat {
      j1 <- way[j0 + 1]
      p[j0 + 1] <- p[j1 + 1]
      j0 <- j1
      if (j0 == 0L) break
    }
  }
  colonne <- rep(NA_integer_, k)
  for (j in seq_len(k)) if (p[j + 1] > 0) colonne[p[j + 1]] <- j
  colonne <- colonne[seq_len(n)]
  colonne[!is.na(colonne) & colonne > m] <- NA_integer_
  colonne
}

# uuid version 4 (RFC 4122), sans dépendance.
.uuid_v4 <- function() {
  b <- sample(0:255, 16, replace = TRUE)
  b[7] <- bitwOr(bitwAnd(b[7], 0x0f), 0x40)
  b[9] <- bitwOr(bitwAnd(b[9], 0x3f), 0x80)
  h <- sprintf("%02x", b)
  paste0(paste(h[1:4], collapse = ""), "-", paste(h[5:6], collapse = ""), "-",
         paste(h[7:8], collapse = ""), "-", paste(h[9:10], collapse = ""), "-",
         paste(h[11:16], collapse = ""))
}

# Arbres porteurs d'au moins un attribut saisi sur le terrain.
.iv_a_attributs_terrain <- function(df) {
  saisi <- Reduce(`|`, lapply(c("essence_arbre", "qualite", "notes", "photos"),
                              function(k) !.iv_vide(.iv_col(df, k, NA_character_))))
  statut <- as.character(.iv_col(df, "statut", NA_character_))
  saisi | (!.iv_vide(statut) & statut != "vivant")
}

# Table en x/y : un sf POINT perd sa géométrie au profit de colonnes x, y.
.iv_en_xy <- function(df, nom) {
  if (inherits(df, "sf")) {
    xy <- sf::st_coordinates(sf::st_geometry(df))
    df <- sf::st_drop_geometry(df)
    df$x <- xy[, 1]
    df$y <- xy[, 2]
  }
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  if (!all(c("x", "y") %in% names(df))) {
    cli::cli_abort("{.arg {nom}} must be an sf POINT or carry {.val x} and {.val y} columns.")
  }
  df
}

#' Reconcile provisional and definitive trees of one plot
#'
#' Matches the provisional trees (phone, layer \code{arbres}) with the
#' definitive detections of the Groma server, for **one** plot, by an optimal
#' assignment (Hungarian method) on the horizontal position. Pairs farther
#' than \code{tolerance_m} are forbidden; the cost is the distance plus
#' \code{poids_dbh_m_par_cm} per cm of diameter difference, which breaks ties
#' between close candidates (a greedy match would lose trees).
#'
#' \itemize{
#'   \item Matched: field attributes kept (\code{essence_arbre}, \code{espece},
#'     \code{statut}, \code{qualite}, \code{notes}, \code{photos}, measured
#'     \code{h_m}); position, \code{dbh_cm}, \code{methode} and CHM height
#'     updated; \code{definitif} if \code{essence_arbre} is filled in, else
#'     \code{a_completer}. A \code{faux_positif} stays so (alert
#'     \code{faux_positif_retrouve}). Alert \code{ecart_dbh} when the diameter
#'     gap exceeds \code{ecart_dbh_alerte_cm} \emph{and}
#'     \code{ecart_dbh_alerte_rel} of the smaller diameter.
#'   \item New (definitive without provisional): new \code{uuid},
#'     \code{statut = "vivant"}, \code{a_completer}.
#'   \item Provisional not found: \code{a_verifier}, attributes and position
#'     kept.
#'   \item Numbering recomputed with \code{\link{numeroter_arbres}} on the
#'     trees that are neither \code{a_verifier} nor \code{faux_positif}; the
#'     former number goes to \code{num_provisoire}. \code{a_verifier} trees
#'     get \code{V1, V2...}, \code{faux_positif} trees \code{F1, F2...} (by
#'     azimuth), so \code{tree_id} stays unique and non-empty.
#'   \item A tree that leaves the inventory once measured (outside the radius
#'     or under the threshold) is kept as \code{a_verifier} when it carries
#'     field attributes or was provisional, and dropped otherwise.
#' }
#' No field attribute is ever lost.
#'
#' @param provisoires sf POINT, or data.frame with \code{x}, \code{y}
#'   (Lambert-93): rows of the \code{arbres} layer of the plot (\code{uuid},
#'   \code{dbh_cm}, \code{tree_id} and field attributes).
#' @param definitifs sf POINT, or data.frame with \code{x}, \code{y}:
#'   definitive detections (\code{dbh_cm}, optional \code{h_m},
#'   \code{h_source}, \code{houppier_id}, \code{methode}).
#' @param centre Numeric \code{c(x, y)}: measured plot centre (Lambert-93).
#'   Or the \code{centres_mesures} rows of the plot (sf POINT, or data.frame
#'   with \code{x}, \code{y}): Groma adds a row at each measurement and never
#'   rewrites one, so the most recent (largest \code{fid}, else last row)
#'   is used.
#' @param convergence_deg Meridian convergence at the plot (degrees).
#' @param tolerance_m Maximal matching distance (m). Default 0.5.
#' @param rayon_m,seuil_diam_cm,unite_azimut,tolerance_deg Numbering
#'   parameters, see \code{\link{numeroter_arbres}}.
#' @param poids_dbh_m_par_cm Cost of 1 cm of diameter gap, in metres.
#'   Default 0.01.
#' @param ecart_dbh_alerte_cm,ecart_dbh_alerte_rel Diameter gap alert
#'   thresholds. Defaults 10 cm and 0.5.
#' @param generer_uuid Function returning a new uuid (for the new trees).
#'
#' @return A list with \code{arbres} (same class as \code{provisoires}),
#'   \code{apparies} (data.frame \code{uuid}, \code{definitif} = row of
#'   \code{definitifs}, \code{distance_m}), \code{nouveaux} and
#'   \code{non_retrouves} (uuids), \code{numeros_modifies} (data.frame
#'   \code{uuid}, \code{ancien}, \code{nouveau}) and \code{alertes}
#'   (data.frame \code{uuid}, \code{motif}, \code{dbh_provisoire},
#'   \code{dbh_definitif}).
#'
#' @section Lifecycle:
#' Experimental (spec 061).
#'
#' @examples
#' prov <- data.frame(uuid = c("u1", "u2"), plot_id = "P1", tree_id = c("1", "2"),
#'                    dbh_cm = c(30, 25), essence_arbre = c("hetre", NA),
#'                    etat_detection = "provisoire",
#'                    x = c(1000, 1003), y = c(2005, 2004))
#' def <- data.frame(x = c(1000.2, 1003.1), y = c(2005, 2004), dbh_cm = c(31, 24),
#'                   methode = "classique")
#' rapprocher_arbres(prov, def, centre = c(1000, 2000))$arbres
#'
#' @export
rapprocher_arbres <- function(provisoires, definitifs, centre,
                              convergence_deg = 0, tolerance_m = 0.5,
                              rayon_m = 20, seuil_diam_cm = 7.5,
                              unite_azimut = c("deg", "gr"), tolerance_deg = 1,
                              poids_dbh_m_par_cm = 0.01,
                              ecart_dbh_alerte_cm = 10, ecart_dbh_alerte_rel = 0.5,
                              generer_uuid = .uuid_v4) {
  unite_azimut <- match.arg(unite_azimut)
  if (is.data.frame(centre)) {
    if (!nrow(centre)) cli::cli_abort("{.arg centre} has no row.")
    if (inherits(centre, "sf") && inherits(provisoires, "sf")) {
      centre <- sf::st_transform(centre, sf::st_crs(provisoires))
    }
    rang <- if ("fid" %in% names(centre)) as.numeric(centre$fid) else seq_len(nrow(centre))
    rang[is.na(rang)] <- -Inf
    dernier <- .iv_en_xy(centre, "centre")[order(rang, seq_len(nrow(centre)))[nrow(centre)], ]
    centre <- c(dernier$x, dernier$y)
  }
  if (!is.numeric(centre) || length(centre) < 2L) {
    cli::cli_abort("{.arg centre} must be {.code c(x, y)} or the measured-centre rows of the plot.")
  }
  crs <- if (inherits(provisoires, "sf")) sf::st_crs(provisoires) else
    if (inherits(definitifs, "sf")) sf::st_crs(definitifs) else NULL
  rendre_sf <- inherits(provisoires, "sf")
  prov <- .iv_en_xy(provisoires, "provisoires")
  def <- .iv_en_xy(definitifs, "definitifs")
  if (nrow(prov) && (!"uuid" %in% names(prov) || any(.iv_vide(prov$uuid)) ||
                     anyDuplicated(prov$uuid))) {
    cli::cli_abort("{.arg provisoires} must carry a unique, non-empty {.val uuid}.")
  }
  interdit <- 1e9
  n_p <- nrow(prov)
  n_d <- nrow(def)
  dbh_p <- as.numeric(.iv_col(prov, "dbh_cm", NA_real_))
  dbh_d <- as.numeric(.iv_col(def, "dbh_cm", NA_real_))

  cout <- matrix(interdit, n_p, n_d)
  dist <- matrix(Inf, n_p, n_d)
  for (i in seq_len(n_p)) {
    dist[i, ] <- sqrt((prov$x[i] - def$x)^2 + (prov$y[i] - def$y)^2)
    ok <- dist[i, ] <= tolerance_m
    ddbh <- abs(ifelse(is.na(dbh_p[i]), 0, dbh_p[i]) - ifelse(is.na(dbh_d), 0, dbh_d))
    cout[i, ok] <- dist[i, ok] + poids_dbh_m_par_cm * ddbh[ok]
  }
  colonne <- if (n_p && n_d) .affectation_optimale(cout, interdit) else rep(NA_integer_, n_p)
  for (i in seq_len(n_p)) {
    if (!is.na(colonne[i]) && cout[i, colonne[i]] >= interdit) colonne[i] <- NA_integer_
  }

  alertes <- list()
  alerte <- function(uuid, motif, dp = NA_real_, dd = NA_real_) {
    alertes[[length(alertes) + 1L]] <<- data.frame(
      uuid = uuid, motif = motif, dbh_provisoire = dp, dbh_definitif = dd,
      stringsAsFactors = FALSE)
  }

  # Colonnes de sortie : celles des provisoires + celles produites ici.
  sortie <- prov
  for (col in c("num_provisoire", "methode", "h_m", "h_source", "houppier_id",
                "etat_detection", "statut", "plot_id", "tree_id")) {
    if (!col %in% names(sortie)) {
      sortie[[col]] <- if (col %in% c("h_m")) NA_real_ else
        if (col == "houppier_id") NA_integer_ else NA_character_
    }
  }
  tid <- as.character(sortie$tree_id)
  sortie$num_provisoire <- ifelse(!.iv_vide(tid), tid, as.character(sortie$num_provisoire))
  etat <- as.character(sortie$etat_detection)
  faux <- !is.na(etat) & etat == "faux_positif"
  a_essence <- !.iv_vide(.iv_col(sortie, "essence_arbre", NA_character_))
  mesuree <- !is.na(sortie$h_source) & sortie$h_source == "mesuree"

  apparies <- data.frame(uuid = character(0), definitif = integer(0),
                         distance_m = numeric(0), stringsAsFactors = FALSE)
  for (i in which(!is.na(colonne))) {
    j <- colonne[i]
    sortie$x[i] <- def$x[j]
    sortie$y[i] <- def$y[j]
    sortie$dbh_cm[i] <- dbh_d[j]
    if ("methode" %in% names(def) && !is.na(def$methode[j])) sortie$methode[i] <- def$methode[j]
    if ("houppier_id" %in% names(def) && !is.na(def$houppier_id[j])) {
      sortie$houppier_id[i] <- as.integer(def$houppier_id[j])
    }
    # Hauteur MNH du serveur, jamais par-dessus une hauteur mesurée. Une
    # valeur absente (NA) laisse la hauteur provisoire en place.
    if (!mesuree[i] && "h_m" %in% names(def) && !is.na(def$h_m[j])) {
      sortie$h_m[i] <- def$h_m[j]
      hs <- if ("h_source" %in% names(def)) def$h_source[j] else NA_character_
      sortie$h_source[i] <- if (.iv_vide(hs)) "mnh" else hs
    }
    if (faux[i]) {
      alerte(prov$uuid[i], "faux_positif_retrouve")
    } else {
      sortie$etat_detection[i] <- if (a_essence[i]) "definitif" else "a_completer"
    }
    apparies <- rbind(apparies, data.frame(uuid = prov$uuid[i], definitif = j,
                                           distance_m = round(dist[i, j], 3),
                                           stringsAsFactors = FALSE))
    dp <- dbh_p[i]
    dd <- dbh_d[j]
    if (!is.na(dp) && !is.na(dd) && dp > 0 && dd > 0) {
      ecart <- abs(dp - dd)
      if (ecart > ecart_dbh_alerte_cm && ecart > ecart_dbh_alerte_rel * min(dp, dd)) {
        alerte(prov$uuid[i], "ecart_dbh", dp, dd)
      }
    }
  }
  non_retrouves <- prov$uuid[is.na(colonne)]
  sortie$etat_detection[is.na(colonne) & !faux] <- "a_verifier"

  # Nouveaux arbres : détections définitives sans provisoire.
  libres <- setdiff(seq_len(n_d), colonne)
  nouveaux <- character(0)
  if (length(libres)) {
    plot_def <- .iv_col(def, "plot_id", NA_character_)
    plot_defaut <- if (n_p) as.character(prov$plot_id[1] %||% NA) else NA_character_
    nv <- sortie[rep(NA_integer_, length(libres)), , drop = FALSE]
    rownames(nv) <- NULL
    nv$uuid <- vapply(seq_along(libres), function(k) as.character(generer_uuid()), "")
    nv$plot_id <- ifelse(is.na(plot_def[libres]), plot_defaut, plot_def[libres])
    nv$x <- def$x[libres]
    nv$y <- def$y[libres]
    nv$dbh_cm <- dbh_d[libres]
    h_def <- as.numeric(.iv_col(def, "h_m", NA_real_))[libres]
    nv$h_m <- h_def
    hs <- as.character(.iv_col(def, "h_source", NA_character_))[libres]
    nv$h_source <- ifelse(.iv_vide(hs), ifelse(is.na(h_def), "aucune", "mnh"), hs)
    nv$houppier_id <- as.integer(.iv_col(def, "houppier_id", NA_integer_))[libres]
    nv$statut <- "vivant"
    nv$methode <- as.character(.iv_col(def, "methode", NA_character_))[libres]
    nv$num_provisoire <- NA_character_
    nv$etat_detection <- "a_completer"
    nouveaux <- nv$uuid
    sortie <- rbind(sortie, nv)
  }

  # Renumérotation dans le repère du nord géographique.
  geo <- .offsets_geographiques(sortie$x - centre[1], sortie$y - centre[2], convergence_deg)
  sortie$distance_m <- round(sqrt(geo$x^2 + geo$y^2), 3)
  az <- (atan2(geo$x, geo$y) * 180 / pi) %% 360
  sortie$azimut <- round(if (unite_azimut == "gr") az / 0.9 else az, 4)

  cand <- which(!sortie$etat_detection %in% c("a_verifier", "faux_positif"))
  num <- numeroter_arbres(geo$x[cand], geo$y[cand], sortie$dbh_cm[cand], sortie$uuid[cand],
                          rayon_m = rayon_m, seuil_diam_cm = seuil_diam_cm,
                          unite_azimut = unite_azimut, tolerance_deg = tolerance_deg)
  retenu <- !is.na(num$tree_id)
  sortie$tree_id[cand[retenu]] <- num$tree_id[retenu]
  hors <- cand[!retenu]
  for (k in which(!retenu)) alerte(num$id[k], num$exclusion[k])
  sortie$etat_detection[hors] <- "a_verifier"
  # Un arbre qui sort de l'inventaire sans attribut terrain et sans passé
  # provisoire ne porte aucune information : il est abandonné.
  abandon <- hors[!.iv_a_attributs_terrain(sortie[hors, , drop = FALSE]) &
                    .iv_vide(sortie$num_provisoire[hors])]
  if (length(abandon)) {
    nouveaux <- setdiff(nouveaux, sortie$uuid[abandon])
    sortie <- sortie[-abandon, , drop = FALSE]
  }

  for (etat_suffixe in list(c("a_verifier", "V"), c("faux_positif", "F"))) {
    g <- which(sortie$etat_detection == etat_suffixe[1])
    g <- g[order(sortie$azimut[g], .rang_octets(sortie$uuid[g]))]
    sortie$tree_id[g] <- paste0(etat_suffixe[2], seq_along(g))
  }

  ancien <- sortie$num_provisoire
  modifie <- !.iv_vide(ancien) & ancien != sortie$tree_id
  numeros_modifies <- data.frame(uuid = sortie$uuid[modifie], ancien = ancien[modifie],
                                 nouveau = sortie$tree_id[modifie],
                                 stringsAsFactors = FALSE)
  rownames(sortie) <- NULL
  alertes <- if (length(alertes)) do.call(rbind, alertes) else
    data.frame(uuid = character(0), motif = character(0), dbh_provisoire = numeric(0),
               dbh_definitif = numeric(0), stringsAsFactors = FALSE)

  if (rendre_sf) {
    sortie <- sf::st_as_sf(sortie, coords = c("x", "y"), crs = crs, remove = FALSE)
  }
  list(arbres = sortie, apparies = apparies, nouveaux = nouveaux,
       non_retrouves = non_retrouves, numeros_modifies = numeros_modifies,
       alertes = alertes)
}


# ---- Validation -------------------------------------------------------

# Lecture d'un GeoPackage d'inventaire vidéo, ou passage d'une liste déjà lue.
.iv_lire <- function(gpkg) {
  if (is.list(gpkg) && !inherits(gpkg, "data.frame") && !is.null(gpkg$placettes)) {
    return(gpkg)
  }
  g <- import_qgis_gpkg(gpkg)
  couches <- sf::st_layers(gpkg)$name
  for (l in c("centres_mesures", "detections")) {
    # fid lu : un centre n'est jamais réécrit, la plus grande valeur compte.
    g[[l]] <- if (l %in% couches) {
      sf::st_read(gpkg, layer = l, quiet = TRUE, fid_column_name = "fid")
    } else NULL
  }
  g
}

# Centre mesuré le plus récent de chaque placette : Groma ajoute une ligne à
# chaque mesure (plus grand fid, sinon dernière ligne). Renvoie les lignes
# retenues, une par plot_id.
.iv_derniers_centres <- function(centres) {
  if (is.null(centres) || !nrow(centres) || !"plot_id" %in% names(centres)) return(centres)
  rang <- if ("fid" %in% names(centres)) as.numeric(centres$fid) else seq_len(nrow(centres))
  rang[is.na(rang)] <- -Inf
  ordre <- order(as.character(centres$plot_id), rang, seq_len(nrow(centres)))
  ordre <- ordre[!duplicated(as.character(centres$plot_id[ordre]), fromLast = TRUE)]
  centres[sort(ordre), ]
}

#' Validate a video inventory
#'
#' Runs \code{\link{validate_field_data}} with \code{dbh_max_cm = Inf} and
#' \code{dbh_alerte_cm = 200} (any diameter accepted, flagged above 2 m), on
#' the trees that are not \code{faux_positif}, then the video-specific checks:
#' \code{tree_id} unique and non-empty, \code{uuid} unique and non-empty,
#' domains of \code{etat_detection}, \code{h_source}, \code{methode} and
#' \code{essence_arbre}, and, when \code{plan} is given, sampling-design
#' columns and plot positions identical to the original plan.
#'
#' The read-only layers \code{parcelles}, \code{ugf} and \code{projet}
#' (schema 1.2.0) are not checked. A plot may have several rows in
#' \code{centres_mesures} (Groma never rewrites a centre): this is reported
#' as an information (\code{severity = "info"} in \code{warnings}), the most
#' recent centre being the one used.
#'
#' @param gpkg Path to \code{inventaire_video.gpkg}, or a list with
#'   \code{placettes} and \code{arbres} (as returned by
#'   \code{\link{import_qgis_gpkg}}).
#' @param plan Optional sf of the original placettes (sampling plan).
#' @param region Character. Species region. Default \code{"BFC"}.
#'
#' @return A list with \code{ok}, \code{errors} and \code{warnings}, as
#'   \code{\link{validate_field_data}}.
#'
#' @section Lifecycle:
#' Experimental (spec 061).
#'
#' @export
valider_inventaire_video <- function(gpkg, plan = NULL, region = "BFC") {
  g <- .iv_lire(gpkg)
  placettes <- g$placettes
  arbres <- g$arbres
  if (!is.null(arbres) && nrow(arbres) && "etat_detection" %in% names(arbres)) {
    arbres <- arbres[is.na(arbres$etat_detection) | arbres$etat_detection != "faux_positif", ]
  }
  v <- validate_field_data(placettes, arbres, region = region,
                           dbh_max_cm = Inf, dbh_alerte_cm = 200)
  issues <- list()
  dom <- attr(schema_inventaire_video(), "domaines")

  if (!is.null(arbres) && nrow(arbres)) {
    df <- sf::st_drop_geometry(arbres)
    pid <- as.character(.iv_col(df, "plot_id", NA_character_))
    tid <- as.character(.iv_col(df, "tree_id", NA_character_))
    uuid <- as.character(.iv_col(df, "uuid", NA_character_))
    sans_uuid <- which(.iv_vide(uuid))
    if (length(sans_uuid)) {
      issues <- c(issues, list(.mk_issue(plot_id = pid[sans_uuid], tree_id = tid[sans_uuid],
                                         field = "uuid", issue = "uuid is missing.")))
    }
    dup <- which(duplicated(uuid) & !.iv_vide(uuid))
    if (length(dup)) {
      issues <- c(issues, list(.mk_issue(plot_id = pid[dup], tree_id = tid[dup],
                                         field = "uuid", issue = "Duplicate uuid.")))
    }
    domaines <- list(etat_detection = dom$etat_detection, h_source = dom$h_source,
                     methode = dom$methode, essence_arbre = .iv_essences()$code)
    for (col in names(domaines)) {
      val <- as.character(.iv_col(df, col, NA_character_))
      bad <- which(!.iv_vide(val) & !val %in% domaines[[col]])
      if (length(bad)) {
        issues <- c(issues, list(.mk_issue(plot_id = pid[bad], tree_id = tid[bad], field = col,
                                           issue = sprintf("Value not in the %s domain.", col))))
      }
    }
  }

  if (!is.null(plan)) {
    plan <- sf::st_transform(plan, sf::st_crs(placettes))
    idx <- match(placettes$plot_id, plan$plot_id)
    absents <- which(is.na(idx))
    if (length(absents)) {
      issues <- c(issues, list(.mk_issue(plot_id = as.character(placettes$plot_id[absents]),
                                         field = "plot_id",
                                         issue = "Plot not in the sampling plan.")))
    }
    ok <- which(!is.na(idx))
    for (col in intersect(.placette_design_columns, names(plan))) {
      a <- .iv_col(placettes, col)[ok]
      b <- plan[[col]][idx[ok]]
      diff <- if (is.numeric(a) && is.numeric(b)) {
        !(is.na(a) & is.na(b)) & (is.na(a) | is.na(b) | abs(a - b) > 1e-9)
      } else {
        !(is.na(a) & is.na(b)) & (is.na(a) | is.na(b) | as.character(a) != as.character(b))
      }
      if (any(diff)) {
        issues <- c(issues, list(.mk_issue(plot_id = as.character(placettes$plot_id[ok][diff]),
                                           field = col,
                                           issue = "Sampling-design column modified.")))
      }
    }
    if (length(ok)) {
      ecart <- sqrt(rowSums((sf::st_coordinates(placettes)[ok, 1:2, drop = FALSE] -
                               sf::st_coordinates(plan)[idx[ok], 1:2, drop = FALSE])^2))
      bouge <- ecart > 0.01
      if (any(bouge)) {
        issues <- c(issues, list(.mk_issue(plot_id = as.character(placettes$plot_id[ok][bouge]),
                                           field = "geom",
                                           issue = "Planned plot position modified.")))
      }
    }
  }

  warnings <- v$warnings
  centres <- g$centres_mesures
  if (!is.null(centres) && nrow(centres) && "plot_id" %in% names(centres)) {
    n <- table(as.character(centres$plot_id))
    multi <- names(n)[n > 1]
    if (length(multi)) {
      warnings <- rbind(warnings, .mk_issue(
        plot_id = multi, field = "centres_mesures",
        issue = sprintf("%d measured centres; the most recent is used.", as.integer(n[multi])),
        severity = "info"))
    }
  }

  errors <- if (length(issues)) rbind(v$errors, do.call(rbind, issues)) else v$errors
  list(ok = nrow(errors) == 0, errors = errors, warnings = warnings)
}


# ---- Création du projet de terrain ------------------------------------

# Pente (%) et exposition par plan ajusté sur le MNT dans le rayon ;
# recouvrement = part des cellules du MNH au-dessus de 2 m.
.iv_topographie <- function(mnt, mnh, centre, rayon_m) {
  res <- list(pente_pct = NA_real_, exposition = NA_character_, recouvrement_pct = NA_real_)
  dans_rayon <- function(r) {
    xyz <- terra::as.data.frame(r, xy = TRUE, na.rm = TRUE)
    names(xyz)[3] <- "z"
    xyz[sqrt((xyz$x - centre[1])^2 + (xyz$y - centre[2])^2) <= rayon_m, , drop = FALSE]
  }
  if (!is.null(mnt)) {
    xyz <- dans_rayon(mnt)
    if (nrow(xyz) >= 3) {
      cf <- stats::coef(stats::lm(z ~ x + y, data = xyz))
      a <- unname(cf["x"])
      b <- unname(cf["y"])
      res$pente_pct <- 100 * sqrt(a^2 + b^2)
      res$exposition <- if (res$pente_pct < 5) "flat" else {
        # Exposition = direction de la plus grande pente descendante.
        az <- (atan2(-a, -b) * 180 / pi) %% 360
        c("N", "NE", "E", "SE", "S", "SW", "W", "NW")[(floor((az + 22.5) / 45) %% 8) + 1]
      }
    }
  }
  if (!is.null(mnh)) {
    xyz <- dans_rayon(mnh)
    if (nrow(xyz)) res$recouvrement_pct <- 100 * mean(xyz$z > 2)
  }
  res
}

# Découpe d'un raster sur l'emprise de la placette, rééchantillonné à 0,5 m.
.iv_decouper <- function(r, zone, resolution = 0.5) {
  if (!inherits(r, "SpatRaster")) r <- terra::rast(r)
  if (!terra::same.crs(r, "EPSG:2154")) {
    r <- terra::project(r, "EPSG:2154")
  }
  e <- terra::ext(terra::vect(zone))
  gabarit <- terra::rast(e, resolution = resolution, crs = "EPSG:2154")
  terra::resample(terra::crop(r[[1]], e, snap = "out"), gabarit, method = "bilinear")
}

.iv_ecrire_tif <- function(r, chemin) {
  names(r) <- tools::file_path_sans_ext(basename(chemin))
  terra::writeRaster(r, chemin, overwrite = TRUE, datatype = "FLT4S", NAflag = -9999,
                     gdal = c("COMPRESS=DEFLATE", "PREDICTOR=1", "TILED=NO"))
}

# Couche sf (éventuellement vide) conforme aux descripteurs du schéma ;
# data.frame pour une table sans géométrie (`projet`), dont les dates restent
# en texte comme chez Groma.
.iv_conformer <- function(x, champs, geometrie, crs = 2154) {
  if (is.null(geometrie)) {
    noms <- vapply(champs, `[[`, character(1), "name")
    df <- if (is.null(x)) list() else as.list(x)
    n <- if (is.null(x)) 0L else nrow(as.data.frame(x))
    out <- lapply(champs, function(f) {
      v <- df[[f$name]] %||% rep(NA, n)
      switch(f$type, integer = as.integer(v), double = as.numeric(v), as.character(v))
    })
    names(out) <- noms
    return(as.data.frame(out, stringsAsFactors = FALSE))
  }
  if (is.null(x) || !nrow(x)) {
    return(empty_sf_from_schema(champs, crs = crs, geometry_type = geometrie))
  }
  if (identical(geometrie, "MULTIPOLYGON")) {
    x <- sf::st_cast(sf::st_transform(x, crs), "MULTIPOLYGON", warn = FALSE)
  }
  typer <- function(v, type) {
    switch(type,
      character = as.character(v),
      integer = as.integer(v),
      double = as.numeric(v),
      datetime = if (inherits(v, "POSIXct")) v else as.POSIXct(v, tz = "UTC"),
      v)
  }
  df <- sf::st_drop_geometry(x)
  out <- lapply(champs, function(f) {
    v <- if (f$name %in% names(df)) df[[f$name]] else rep(NA, nrow(df))
    if (all(is.na(v)) && !is.null(f$default)) v <- rep(f$default, nrow(df))
    typer(v, f$type)
  })
  names(out) <- vapply(champs, `[[`, character(1), "name")
  out <- as.data.frame(out, stringsAsFactors = FALSE)
  out$geometry <- sf::st_geometry(x)
  sf::st_sf(out, sf_column_name = "geometry", crs = crs)
}

.iv_ecrire_couche <- function(x, gpkg, couche, index_spatial) {
  if (!inherits(x, "sf")) {
    # Table GeoPackage « attributes » (non spatiale).
    sf::st_write(x, gpkg, layer = couche, layer_options = "FID=fid",
                 quiet = TRUE, append = FALSE, delete_layer = TRUE)
    return(invisible(gpkg))
  }
  opts <- c(paste0("SPATIAL_INDEX=", if (index_spatial) "YES" else "NO"),
            "GEOMETRY_NAME=geom", "FID=fid")
  sf::st_write(x, gpkg, layer = couche, layer_options = opts,
               quiet = TRUE, append = FALSE, delete_layer = TRUE)
}

# ---- Projet nemetonshiny -> tables projet, parcelles, ugf (schéma 1.2.0) --

# Lecture d'une source facultative : une erreur n'empêche jamais la création.
.iv_essayer <- function(quoi, expr) {
  tryCatch(expr, error = function(e) {
    cli::cli_warn("{quoi} not read from the project: {conditionMessage(e)}")
    NULL
  })
}

# Couche `parcelles` : copie de data/parcels.gpkg.
.iv_parcelles_projet <- function(data) {
  f <- file.path(data, "parcels.gpkg")
  if (!file.exists(f)) return(NULL)
  p <- sf::st_read(f, quiet = TRUE)
  if (!nrow(p) || is.na(sf::st_crs(p)) || !"id" %in% names(p)) return(NULL)
  p <- sf::st_transform(p, 2154)
  out <- data.frame(idu = as.character(p$id),
                    commune = as.character(.iv_col(p, "commune", NA_character_)),
                    section = as.character(.iv_col(p, "section", NA_character_)),
                    numero = as.character(.iv_col(p, "numero", NA_character_)),
                    contenance_m2 = as.numeric(.iv_col(p, "contenance", NA_real_)),
                    stringsAsFactors = FALSE)
  sf::st_sf(out, geometry = sf::st_geometry(p))
}

# Couche `ugf` : ténements fusionnés par ug_id, attributs de data/ugs.json.
.iv_ugf_projet <- function(data) {
  f <- file.path(data, "tenements.gpkg")
  if (!file.exists(f)) return(NULL)
  t <- sf::st_read(f, quiet = TRUE)
  if (!nrow(t) || is.na(sf::st_crs(t)) || !"ug_id" %in% names(t)) return(NULL)
  t <- t[!is.na(t$ug_id), ]
  # Reprojection puis make_valid (make_valid sur 4326 déplace les sommets).
  t <- sf::st_make_valid(sf::st_transform(t, 2154))
  ids <- unique(as.character(t$ug_id))
  surf <- as.numeric(.iv_col(t, "surface_m2", NA_real_))
  geom <- do.call(c, lapply(ids, function(id) {
    sf::st_union(sf::st_geometry(t)[as.character(t$ug_id) == id])
  }))
  ug <- data.frame(ug_id = ids, stringsAsFactors = FALSE)
  ug$surface_m2 <- vapply(ids, function(id) {
    v <- surf[as.character(t$ug_id) == id]
    if (all(is.na(v))) NA_real_ else sum(v, na.rm = TRUE)
  }, numeric(1), USE.NAMES = FALSE)
  fj <- file.path(data, "ugs.json")
  a <- if (file.exists(fj)) as.data.frame(jsonlite::fromJSON(fj), stringsAsFactors = FALSE) else NULL
  noms <- c(label = "libelle", groupe = "groupe", onf_foret_nom = "foret",
            onf_parcelle = "parcelle_onf")
  idx <- if (!is.null(a) && "ug_id" %in% names(a)) match(ug$ug_id, as.character(a$ug_id)) else NA
  for (k in names(noms)) {
    ug[[noms[[k]]]] <- if (!is.null(a) && k %in% names(a)) as.character(a[[k]])[idx] else NA_character_
  }
  # Ordre naturel des numéros ONF, sinon du suffixe numérique de ug_id.
  onf <- suppressWarnings(as.numeric(ug$parcelle_onf))
  rang <- suppressWarnings(as.numeric(sub(".*?(\\d+)$", "\\1",
                                          ifelse(grepl("\\d$", ug$ug_id), ug$ug_id, NA))))
  ordre <- order(onf, rang, ug$ug_id, na.last = TRUE)
  sf::st_sf(ug[ordre, , drop = FALSE], geometry = sf::st_sfc(geom[ordre], crs = 2154))
}

# Ligne de la table `projet`.
.iv_ligne_projet <- function(project_path, placettes, parcelles) {
  data <- file.path(project_path, "data")
  fm <- file.path(project_path, "metadata.json")
  m <- if (file.exists(fm)) jsonlite::fromJSON(fm, simplifyVector = TRUE) else list()
  texte <- function(v) if (is.null(v) || !length(v) || is.na(v[1]) || !nzchar(v[1])) NA_character_ else as.character(v[1])
  entier <- function(v) if (is.null(v) || !length(v)) NA_integer_ else as.integer(v[1])
  type <- as.character(.iv_col(placettes, "type", NA_character_))
  rempl <- sum(!is.na(type) & type == "Over")
  bb <- sf::st_bbox(sf::st_transform(placettes, 4326))
  nb <- function(v) as.character(round(unname(v), 6))
  coin <- function(x, y) paste(nb(x), nb(y))
  emprise <- sprintf("POLYGON ((%s, %s, %s, %s, %s))",
                     coin(bb["xmax"], bb["ymin"]), coin(bb["xmax"], bb["ymax"]),
                     coin(bb["xmin"], bb["ymax"]), coin(bb["xmin"], bb["ymin"]),
                     coin(bb["xmax"], bb["ymin"]))
  ligne <- list(
    projet_id = texte(m$id),
    projet_nom = texte(m$name),
    description = texte(m$description),
    proprietaire = texte(m$owner),
    communes = NA_character_,
    surface_zone_ha = NA_real_,
    surface_cadastre_ha = NA_real_,
    nb_parcelles = entier(m$parcels_count),
    nb_ug = entier(m$ug_count),
    nb_placettes_base = nrow(placettes) - rempl,
    nb_placettes_rempl = rempl,
    plan_genere_le = texte(m$samples_generated_at),
    prepare_le = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    prepare_par = paste("nemeton", as.character(utils::packageVersion("nemeton"))),
    emprise = emprise
  )
  if (is.na(ligne$projet_id)) ligne$projet_id <- basename(normalizePath(project_path, mustWork = FALSE))
  if (is.na(ligne$projet_nom)) ligne$projet_nom <- ligne$projet_id
  if (!is.null(parcelles) && nrow(parcelles)) {
    ligne$surface_zone_ha <- round(sum(as.numeric(sf::st_area(parcelles))) / 1e4, 2)
    if (any(!is.na(parcelles$contenance_m2))) {
      ligne$surface_cadastre_ha <- round(sum(parcelles$contenance_m2, na.rm = TRUE) / 1e4, 2)
    }
    codes <- sort(unique(stats::na.omit(parcelles$commune)))
    if (length(codes)) {
      fc <- file.path(data, "commune.gpkg")
      noms <- if (file.exists(fc)) .iv_essayer("Commune names", {
        cm <- sf::st_drop_geometry(sf::st_read(fc, quiet = TRUE))
        if (all(c("code", "nom") %in% names(cm))) stats::setNames(as.character(cm$nom), as.character(cm$code))
      }) else NULL
      lib <- ifelse(codes %in% names(noms), sprintf("%s (%s)", noms[codes], codes), codes)
      ligne$communes <- paste(lib, collapse = ", ")
    }
  }
  as.data.frame(ligne, stringsAsFactors = FALSE)
}

# Les trois tables de la carte et de la liste des projets de Groma, depuis le
# dossier d'un projet nemetonshiny ; NULL (tables vides) sans dossier.
.iv_sources_projet <- function(project_path, placettes) {
  if (is.null(project_path) || !dir.exists(project_path)) {
    return(list(projet = NULL, parcelles = NULL, ugf = NULL))
  }
  data <- file.path(project_path, "data")
  parcelles <- .iv_essayer("Parcels (data/parcels.gpkg)", .iv_parcelles_projet(data))
  ugf <- .iv_essayer("Management units (data/tenements.gpkg)", .iv_ugf_projet(data))
  projet <- .iv_essayer("Project row (metadata.json)",
                        .iv_ligne_projet(project_path, placettes, parcelles))
  list(projet = projet, parcelles = parcelles, ugf = ugf)
}

# Instructions de declencheurs.sql, une à la fois (les corps BEGIN ... END
# contiennent eux-mêmes des points-virgules).
.iv_instructions_sql <- function(chemin = .iv_fichier("declencheurs.sql")) {
  lignes <- readLines(chemin, encoding = "UTF-8", warn = FALSE)
  lignes <- lignes[!grepl("^\\s*--", lignes)]
  sql <- paste(lignes, collapse = "\n")
  morceaux <- trimws(strsplit(sql, "(?<=END;)", perl = TRUE)[[1]])
  morceaux[nzchar(morceaux)]
}

.iv_poser_declencheurs <- function(gpkg) {
  con <- DBI::dbConnect(RSQLite::SQLite(), gpkg)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  for (instr in .iv_instructions_sql()) DBI::dbExecute(con, instr)
  invisible(gpkg)
}

# Projet QGIS / QField écrit dans `stage`, puis zippé en `.qgz` avec le
# GeoPackage et les rasters. `subset_arbres` filtre l'affichage de la couche
# `arbres` (expression QGIS), sans toucher aux données du GeoPackage.
.iv_empaqueter <- function(stage, gpkg_rel, rasters, schema, bbox, project_name,
                           qgz_path, subset_arbres = NULL, projet_nom = NA_character_) {
  geoms <- c(POINT = "Point", POLYGON = "Polygon", MULTIPOLYGON = "Polygon")
  # Le plugin Groma trouve les couches par leur nom : nom de couche QGIS =
  # nom de table. Il ajoute des entités à `detections` et `centres_mesures`
  # et lit `projet` : aucune n'est verrouillée au niveau du projet (les
  # champs de `detections` restent en lecture seule dans les formulaires).
  ajout_plugin <- c("projet", "detections", "centres_mesures", "arbres")
  # Symbologie Marculus (R/inventaire_video_symbologie.R) : une couleur par
  # forêt de `ugf`, lue dans le GeoPackage.
  forets <- tryCatch({
    u <- sf::st_read(file.path(stage, gpkg_rel), layer = "ugf", quiet = TRUE)
    sort(unique(stats::na.omit(as.character(u$foret))))
  }, error = function(e) character(0))
  # Ordre d'affichage, du haut vers le bas (celui de la carte de Groma).
  ordre <- c("detections", "arbres", "cibles", "centres_mesures", "placettes",
             "houppiers", "parcelles", "ugf", "projet")
  noms <- c(intersect(ordre, names(schema)), setdiff(names(schema), ordre))
  couches <- lapply(noms, function(couche) {
    champs <- schema[[couche]]
    g <- attr(champs, "geometrie")
    style <- .iv_style_couche(couche, forets)
    list(id = paste0(couche, "_01"), name = couche,
         gpkg_rel = gpkg_rel, layername = couche,
         geometry = if (is.null(g)) "No geometry" else unname(geoms[g]), schema = champs,
         bbox = bbox, renderer = style$renderer, labeling = style$labeling,
         readonly = attr(champs, "lecture_seule") && !couche %in% ajout_plugin,
         subset = if (couche == "arbres") subset_arbres else NULL,
         checked = !couche %in% .IV_MASQUEES)
  })
  couches <- c(couches, lapply(rasters, function(f) {
    list(type = "raster", id = gsub("[^A-Za-z0-9_]", "_", tools::file_path_sans_ext(basename(f))),
         name = tools::file_path_sans_ext(basename(f)), source = f, bbox = bbox)
  }))
  # Fonds de carte sous toutes les couches : Plan IGN seul affiché.
  couches <- c(couches, lapply(.iv_fonds(), function(f) {
    list(type = "raster", provider = "wms", id = gsub("[^A-Za-z0-9]", "_", f$nom),
         name = f$nom, source = f$source, checked = f$visible, attribution = f$attribution)
  }))
  qgs_rel <- paste0(project_name, ".qgs")
  titre <- if (is.na(projet_nom) || !nzchar(projet_nom)) "Inventaire vid\u00e9o" else
    paste("Inventaire vid\u00e9o \u2014", projet_nom)
  writeLines(enc2utf8(.build_qgs_xml(couches, crs = 2154, project_name = project_name,
                                     title = titre)),
             file.path(stage, qgs_rel), useBytes = TRUE)

  fichiers <- c(qgs_rel, gpkg_rel, rasters)
  zip_rc <- NA_integer_
  tryCatch(
    .atomic_write(qgz_path, function(tmp) {
      withr::with_dir(stage, {
        zip_rc <<- utils::zip(zipfile = tmp, files = fichiers, flags = "-q -X",
                              zip = Sys.getenv("R_ZIPCMD", "zip"))
      })
      if (!identical(as.integer(zip_rc), 0L)) unlink(tmp)
    }),
    error = function(e) {
      cli::cli_abort("Failed to build {.path {qgz_path}} (zip return code {zip_rc}).",
                     parent = e)
    }
  )
  # Plugin de projet Groma : à côté du .qgz, jamais dedans (QField le cherche
  # sur le disque sous le nom du projet). Copie conforme, propriété de groma.
  plugin <- sub("\\.qgz$", ".qml", qgz_path)
  if (!file.copy(.iv_fichier("inventaire_video.qml"), plugin, overwrite = TRUE)) {
    cli::cli_abort("Failed to write the QField plugin {.path {plugin}}.")
  }
  invisible(qgz_path)
}

#' Create the video inventory field project
#'
#' Builds \code{inventaire_video.gpkg} (layers \code{placettes},
#' \code{centres_mesures}, \code{cibles}, \code{arbres}, \code{detections},
#' \code{houppiers}, and the read-only \code{parcelles}, \code{ugf} and
#' \code{projet} of schema 1.2.0, see \code{\link{schema_inventaire_video}}),
#' the per-plot
#' DTM and CHM GeoTIFFs (\code{rasters/<plot_id>_mnt.tif},
#' \code{rasters/<plot_id>_mnh.tif}: Float32, 0.5 m, strips, DEFLATE without
#' predictor, nodata -9999) and the QField project, packaged as a \code{.qgz}
#' like \code{\link{create_qgis_project}}.
#'
#' \code{placettes}, \code{arbres} and \code{detections} are written
#' \strong{without spatial index}: the GDAL R*Tree triggers call
#' \code{ST_IsEmpty} on every \code{UPDATE}, a function the Android SQLite used
#' by Groma does not know. The triggers of \code{declencheurs.sql} then link
#' \code{detections} (written by Groma only) to \code{arbres} by \code{uuid},
#' without any spatial function.
#'
#' The planned position and the sampling-design columns of \code{placettes}
#' are never modified. \code{convergence_deg} (meridian convergence at the
#' planned point) is computed; \code{pente_pct}, \code{exposition} and
#' \code{recouvrement_pct} are filled from the DTM/CHM when empty. Crowns come
#' from \code{\link{segment_houppiers}} over the plot plus \code{marge_m}.
#'
#' @param placettes sf POINT of the sampling plan (\code{plot_id} required).
#' @param plot_ids Optional character vector: plots to include.
#' @param rayon_m Plot radius (m). Default 20.
#' @param seuil_diam_cm Minimal diameter (cm). Default 7.5.
#' @param unite_azimut \code{"deg"} or \code{"gr"}.
#' @param declinaison_deg Magnetic declination (degrees, positive towards
#'   east). \code{NULL} (default) leaves it empty (\code{NA}, never 0):
#'   Groma then computes it with WMM2025 at the plot; a value given here
#'   takes precedence.
#' @param avec_lidar Logical. Clip DTM/CHM and segment crowns. Default
#'   \code{TRUE}; without any DTM/CHM available, a warning is raised and the
#'   project is built without rasters.
#' @param dem,chm \code{SpatRaster} or path. When \code{NULL}, resolved from
#'   \code{project_path} with \code{\link{resolve_project_dem}} and
#'   \code{\link{resolve_project_chm}}.
#' @param project_path Optional nemetonshiny project directory, used to
#'   resolve \code{dem} and \code{chm}, and read (never written) to fill the
#'   tables shown by the Groma map and project list: \code{projet} (one row,
#'   from \code{metadata.json}, \code{data/parcels.gpkg},
#'   \code{data/commune.gpkg} and the written plots; \code{emprise} is the
#'   plots' envelope in EPSG:4326 WKT), \code{parcelles} (copy of
#'   \code{data/parcels.gpkg}) and \code{ugf} (\code{data/tenements.gpkg}
#'   merged by \code{ug_id}, attributes from \code{data/ugs.json}). Without
#'   it, or when a source cannot be read (warning), those tables are created
#'   empty.
#' @param marge_m Margin around the plot for rasters and crowns (m). Default
#'   10.
#' @param output_dir Destination directory.
#' @param project_name File name of the \code{.qgz} (\code{^[A-Za-z0-9_-]+$}).
#'   Default \code{"inventaire_video"}.
#' @param region,lang Unused for the species list (the tree species list is
#'   the BD Foret V2 reference); kept for symmetry with
#'   \code{\link{create_qgis_project}}.
#' @param overwrite Logical. Overwrite an existing \code{.qgz}. Default
#'   \code{TRUE}.
#'
#' @return Absolute path to the \code{.qgz} (invisibly). The Groma QField
#'   project plugin is written next to it as \code{<project_name>.qml}
#'   (copy of \code{inst/inventaire_video/inventaire_video.qml}, not inside the
#'   archive): ship both files to the phone.
#'
#' @section Lifecycle:
#' Experimental (spec 061).
#'
#' @export
creer_projet_inventaire_video <- function(placettes, plot_ids = NULL,
                                          rayon_m = 20, seuil_diam_cm = 7.5,
                                          unite_azimut = c("deg", "gr"),
                                          declinaison_deg = NULL,
                                          avec_lidar = TRUE, dem = NULL, chm = NULL,
                                          project_path = NULL, marge_m = 10,
                                          output_dir, project_name = "inventaire_video",
                                          region = "BFC", lang = "fr", overwrite = TRUE) {
  unite_azimut <- match.arg(unite_azimut)
  if (!inherits(placettes, "sf")) cli::cli_abort("{.arg placettes} must be an sf object.")
  if (!"plot_id" %in% names(placettes)) {
    cli::cli_abort("{.arg placettes} must contain a {.val plot_id} column.")
  }
  if (!is.character(project_name) || length(project_name) != 1L ||
      is.na(project_name) || !grepl("^[A-Za-z0-9_-]+$", project_name)) {
    cli::cli_abort(c(
      "{.arg project_name} must be a single name made of letters, digits, {.val _} or {.val -}.",
      "x" = "Got {.val {project_name}}."
    ))
  }
  if (is.na(sf::st_crs(placettes))) {
    cli::cli_abort("{.arg placettes} has no CRS; set it with {.fn sf::st_set_crs} first.")
  }
  rlang::check_installed(c("DBI", "RSQLite"), reason = "to install the GeoPackage triggers.")
  placettes <- sf::st_transform(placettes, 2154)
  if (!is.null(plot_ids)) {
    inconnus <- setdiff(plot_ids, placettes$plot_id)
    if (length(inconnus)) cli::cli_abort("Unknown plot_id{?s}: {.val {inconnus}}.")
    placettes <- placettes[placettes$plot_id %in% plot_ids, ]
  }
  if (!nrow(placettes)) cli::cli_abort("No plot to include.")

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  qgz_path <- file.path(output_dir, paste0(project_name, ".qgz"))
  if (file.exists(qgz_path) && !overwrite) {
    cli::cli_abort("File {.path {qgz_path}} already exists (overwrite = FALSE).")
  }
  stage <- tempfile("inventaire_video_")
  dir.create(file.path(stage, "rasters"), recursive = TRUE)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  gpkg_rel <- "inventaire_video.gpkg"
  gpkg <- file.path(stage, gpkg_rel)
  schema <- schema_inventaire_video()

  # Paramètres Groma de la placette (le point prévu et le plan restent intacts).
  placettes$rayon_m <- rayon_m
  placettes$seuil_diam_cm <- seuil_diam_cm
  placettes$unite_azimut <- unite_azimut
  placettes$declinaison_deg <- if (is.null(declinaison_deg)) NA_real_ else declinaison_deg
  placettes$convergence_deg <- .convergence_lambert93(placettes)
  placettes$etat_traitement <- "a_faire"

  # MNT / MNH : découpe par placette, houppiers, topographie.
  houppiers <- NULL
  rasters <- character(0)
  if (isTRUE(avec_lidar)) {
    if (is.null(dem) && !is.null(project_path)) dem <- resolve_project_dem(project_path)
    if (is.null(chm) && !is.null(project_path)) chm <- resolve_project_chm(project_path)
    if (is.null(dem) && is.null(chm)) {
      cli::cli_warn("No DTM nor CHM available: project built without rasters nor crowns.")
    }
    for (k in seq_len(nrow(placettes))) {
      pid <- as.character(placettes$plot_id[k])
      centre <- sf::st_coordinates(placettes[k, ])[1, 1:2]
      zone <- sf::st_buffer(sf::st_geometry(placettes[k, ]), rayon_m + marge_m)
      mnt_k <- mnh_k <- NULL
      if (!is.null(dem)) {
        mnt_k <- .iv_decouper(dem, zone)
        f <- file.path("rasters", paste0(pid, "_mnt.tif"))
        .iv_ecrire_tif(mnt_k, file.path(stage, f))
        rasters <- c(rasters, f)
      }
      if (!is.null(chm)) {
        mnh_k <- .iv_decouper(chm, zone)
        f <- file.path("rasters", paste0(pid, "_mnh.tif"))
        .iv_ecrire_tif(mnh_k, file.path(stage, f))
        rasters <- c(rasters, f)
        h <- tryCatch(segment_houppiers(mnh_k, aoi = sf::st_sf(geometry = zone)),
                      error = function(e) {
                        cli::cli_warn("Crown segmentation failed for {.val {pid}}: {conditionMessage(e)}")
                        NULL
                      })
        if (!is.null(h) && nrow(h)) {
          h$plot_id <- pid
          houppiers <- rbind(houppiers, h[, c("plot_id", "houppier_id", "h_max", "surface_m2")])
        }
      }
      topo <- .iv_topographie(mnt_k, mnh_k, centre, rayon_m)
      for (col in names(topo)) {
        if (!col %in% names(placettes)) placettes[[col]] <- rep(NA, nrow(placettes))
        if (is.na(placettes[[col]][k])) placettes[[col]][k] <- topo[[col]]
      }
    }
  }

  # Tables de la carte et de la liste des projets de Groma (schéma 1.2.0).
  sources <- .iv_sources_projet(project_path, placettes)

  # Écriture des couches (géométrie `geom`, fid `fid`, index selon schéma).
  for (couche in names(schema)) {
    champs <- schema[[couche]]
    x <- switch(couche,
      placettes = placettes,
      houppiers = if (!is.null(houppiers)) sf::st_transform(houppiers, 2154) else NULL,
      projet = sources$projet, parcelles = sources$parcelles, ugf = sources$ugf,
      NULL)
    x <- .iv_conformer(x, champs, attr(champs, "geometrie"))
    .iv_ecrire_couche(x, gpkg, couche, attr(champs, "index_spatial"))
  }
  .iv_poser_declencheurs(gpkg)

  bbox <- tryCatch(sf::st_bbox(sf::st_buffer(placettes, rayon_m + marge_m)),
                   error = function(e) NULL)
  .iv_empaqueter(stage, gpkg_rel, rasters, schema, bbox, project_name, qgz_path,
                 projet_nom = sources$projet$projet_nom[1] %||% NA_character_)
  cli::cli_alert_success("Video inventory project created: {.path {qgz_path}}")
  invisible(qgz_path)
}


# ---- Intégration ------------------------------------------------------

# Détections définitives du serveur, rangées par plot_id.
.iv_lire_resultats <- function(resultats) {
  if (is.null(resultats)) return(list())
  fichiers <- unlist(lapply(resultats, function(r) {
    if (dir.exists(r)) list.files(r, pattern = "\\.gpkg$", full.names = TRUE, recursive = TRUE) else r
  }))
  det <- lapply(fichiers, function(f) {
    if (!"detections" %in% sf::st_layers(f)$name) {
      cli::cli_warn("{.path {f}} has no {.val detections} layer; ignored.")
      return(NULL)
    }
    sf::st_transform(sf::st_read(f, layer = "detections", quiet = TRUE), 2154)
  })
  det <- Filter(Negate(is.null), det)
  if (!length(det)) return(list())
  tout <- do.call(rbind, lapply(det, function(d) d[, intersect(
    c("plot_id", "dbh_cm", "h_m", "h_source", "houppier_id", "methode", "score"), names(d))]))
  split(tout, tout$plot_id)
}

#' Import a video inventory into the project field data
#'
#' The \dQuote{Integrate} step: reads \code{inventaire_video.gpkg}
#' (\code{\link{import_qgis_gpkg}}), reconciles each plot for which the Groma
#' server returned a definitive result (\code{\link{rapprocher_arbres}}),
#' derives \code{espece} from \code{essence_arbre}
#' (\code{\link{map_bdforet_essence}}), drops the \code{faux_positif} trees,
#' validates (\code{\link{valider_inventaire_video}}), aggregates per plot
#' (\code{\link{aggregate_plot_metrics}}, one call per plot radius) and tags
#' the NDP source (\code{\link{tag_field_data_sources}},
#' \code{source = "inventaire_video"}).
#'
#' With \code{field_data_gpkg}, the video plots are merged into the project
#' field data by \code{plot_id}, without overwriting: absent plots are added to
#' the \code{placettes} / \code{arbres} layers; for a plot already inventoried,
#' the version chosen by \code{priorite} stays in the main layers (the ones
#' aggregated downstream) and the other goes to
#' \code{placettes_alternatives} / \code{arbres_alternatives}. Every row
#' carries a \code{source} column (\code{"inventaire_terrain"} or
#' \code{"inventaire_video"}).
#'
#' @param gpkg Path to the \code{inventaire_video.gpkg} returned from the
#'   field.
#' @param resultats Optional paths (files or directories) of the definitive
#'   GeoPackages of the Groma server (layer \code{detections}), e.g. from
#'   \code{\link{groma_telecharger_resultats}}.
#' @param field_data_gpkg Optional path of the project field data
#'   (\code{data/field_data.gpkg}), created when absent.
#' @param plan Optional sf of the original sampling plan (checked by
#'   \code{\link{valider_inventaire_video}}).
#' @param priorite \code{"classique"} (default) or \code{"video"}: which
#'   version of a plot inventoried both ways enters the main layers.
#' @param region Character. Species region. Default \code{"BFC"}.
#'
#' @return A list with \code{placettes}, \code{arbres} (video inventory after
#'   reconciliation, without \code{faux_positif}), \code{agregats} (tagged
#'   \code{\link{aggregate_plot_metrics}} output), \code{validation},
#'   \code{a_completer} and \code{a_verifier} (subsets of \code{arbres} by
#'   \code{etat_detection}), \code{classique_conserve} (plots whose classical
#'   inventory stayed in the main layers), \code{ndp} (integer, NDP level of
#'   \code{agregats}), \code{alertes} and \code{numeros_modifies}
#'   (reconciliation) and \code{field_data_gpkg} (path or \code{NULL}).
#'
#' @section Lifecycle:
#' Experimental (spec 061).
#'
#' @export
importer_inventaire_video <- function(gpkg, resultats = NULL, field_data_gpkg = NULL,
                                      plan = NULL, priorite = c("classique", "video"),
                                      region = "BFC") {
  priorite <- match.arg(priorite)
  g <- .iv_lire(gpkg)
  placettes <- sf::st_transform(g$placettes, 2154)
  arbres <- g$arbres
  if (is.null(arbres)) arbres <- .iv_conformer(NULL, schema_inventaire_video("arbres"), "POINT")
  arbres <- sf::st_transform(arbres, 2154)
  alertes <- list()
  modifies <- list()

  # Rapprochement provisoire -> définitif, placette par placette.
  par_plot <- .iv_lire_resultats(resultats)
  centres <- g$centres_mesures
  for (pid in intersect(names(par_plot), placettes$plot_id)) {
    p <- placettes[placettes$plot_id == pid, ][1, ]
    centre <- if (!is.null(centres) && pid %in% centres$plot_id) {
      centres[centres$plot_id == pid, ]   # le plus récent : rapprocher_arbres()
    } else {
      sf::st_coordinates(p)[1, 1:2]
    }
    num <- function(col, defaut) {
      v <- if (col %in% names(p)) p[[col]] else NA
      if (is.na(v)) defaut else v
    }
    prov <- arbres[arbres$plot_id == pid, ]
    r <- rapprocher_arbres(prov, par_plot[[pid]], centre = centre,
                           convergence_deg = num("convergence_deg", 0),
                           rayon_m = num("rayon_m", 20),
                           seuil_diam_cm = num("seuil_diam_cm", 7.5),
                           unite_azimut = num("unite_azimut", "deg"))
    r$arbres$plot_id <- pid
    garde <- intersect(names(arbres), names(r$arbres))
    reste <- arbres[arbres$plot_id != pid, ]
    nouveau <- r$arbres[, garde]
    sf::st_geometry(nouveau) <- "geom_tmp"
    names(nouveau)[names(nouveau) == "geom_tmp"] <- attr(arbres, "sf_column")
    sf::st_geometry(nouveau) <- attr(arbres, "sf_column")
    arbres <- rbind(reste, nouveau[, names(reste)])
    placettes$etat_traitement[placettes$plot_id == pid] <- "definitif"
    if (nrow(r$alertes)) alertes[[pid]] <- cbind(plot_id = pid, r$alertes)
    if (nrow(r$numeros_modifies)) modifies[[pid]] <- cbind(plot_id = pid, r$numeros_modifies)
  }

  # Essence d'arbre -> type de peuplement nemeton (décision 1).
  if ("essence_arbre" %in% names(arbres)) {
    a_essence <- !.iv_vide(arbres$essence_arbre)
    arbres$espece[a_essence] <- .iv_espece_depuis_essence(arbres$essence_arbre[a_essence], region)
  }
  if ("etat_detection" %in% names(arbres)) {
    arbres <- arbres[is.na(arbres$etat_detection) | arbres$etat_detection != "faux_positif", ]
  }

  validation <- valider_inventaire_video(list(placettes = placettes, arbres = arbres),
                                         plan = plan, region = region)
  if (!validation$ok) {
    cli::cli_warn("The video inventory has {nrow(validation$errors)} validation error{?s}.")
  }

  # Agrégats par groupe de rayon.
  rayon <- as.numeric(.iv_col(placettes, "rayon_m", NA_real_))
  rayon[is.na(rayon)] <- 20
  agregats <- do.call(rbind, lapply(sort(unique(rayon)), function(r) {
    aggregate_plot_metrics(placettes[rayon == r, ],
                           arbres[arbres$plot_id %in% placettes$plot_id[rayon == r], ],
                           plot_radius = r)
  }))
  agregats <- tag_field_data_sources(agregats, placettes, arbres, source = "inventaire_video")

  classique_conserve <- character(0)
  if (!is.null(field_data_gpkg)) {
    classique_conserve <- .iv_fusionner(field_data_gpkg, placettes, arbres, priorite)
  }
  etat <- as.character(.iv_col(arbres, "etat_detection", NA_character_))

  vide_alertes <- data.frame(plot_id = character(0), uuid = character(0), motif = character(0),
                             dbh_provisoire = numeric(0), dbh_definitif = numeric(0))
  vide_modifies <- data.frame(plot_id = character(0), uuid = character(0),
                              ancien = character(0), nouveau = character(0))
  list(placettes = placettes, arbres = arbres, agregats = agregats,
       validation = validation,
       a_completer = arbres[!is.na(etat) & etat == "a_completer", ],
       a_verifier = arbres[!is.na(etat) & etat == "a_verifier", ],
       classique_conserve = classique_conserve,
       ndp = as.integer(detect_ndp(agregats)$level),
       alertes = if (length(alertes)) do.call(rbind, unname(alertes)) else vide_alertes,
       numeros_modifies = if (length(modifies)) do.call(rbind, unname(modifies)) else vide_modifies,
       field_data_gpkg = field_data_gpkg)
}

#' Send video-inventory trees back to the field
#'
#' Builds a new QField project (\code{.qgz}) for the plots that still hold
#' trees to complete or to check after \code{\link{importer_inventaire_video}}
#' (groma brief, section 4, option). The GeoPackage
#' \code{inventaire_video.gpkg} keeps \strong{all} the reconciled trees of
#' those plots, so that importing it again replaces the plots without losing
#' any tree; only the display of the \code{arbres} layer is filtered on
#' \code{etat_detection} (QGIS \code{subset}), and it can be turned off with
#' \code{filtrer = FALSE}.
#'
#' The other layers (\code{centres_mesures}, \code{cibles},
#' \code{detections}, \code{houppiers}) are copied for the same plots from
#' \code{gpkg} when given, and left empty otherwise. Layers are written as by
#' \code{\link{creer_projet_inventaire_video}} (no spatial index on
#' \code{placettes}, \code{arbres}, \code{detections}; SQLite triggers).
#'
#' @param import Result of \code{\link{importer_inventaire_video}} (list with
#'   \code{placettes} and \code{arbres}).
#' @param gpkg Optional path of the \code{inventaire_video.gpkg} returned from
#'   the field, for the other layers.
#' @param rasters Optional directory holding the per-plot GeoTIFFs
#'   (\code{<plot_id>_mnt.tif}, \code{<plot_id>_mnh.tif}), e.g. the
#'   \code{rasters/} folder of the original \code{.qgz}; the files of the
#'   selected plots are copied.
#' @param etats States of \code{etat_detection} to send back. Default
#'   \code{c("a_completer", "a_verifier")}.
#' @param filtrer Logical. Filter the display of \code{arbres} on
#'   \code{etats}. Default \code{TRUE}.
#' @param output_dir Destination directory.
#' @param project_name File name of the \code{.qgz} (\code{^[A-Za-z0-9_-]+$}).
#'   Default \code{"inventaire_video_retour"}.
#' @param overwrite Logical. Overwrite an existing \code{.qgz}. Default
#'   \code{TRUE}.
#'
#' @return Absolute path to the \code{.qgz} (invisibly), with attribute
#'   \code{plot_ids} (plots sent back) and \code{n_arbres} (trees in
#'   \code{etats}).
#'
#' @section Lifecycle:
#' Experimental (spec 061).
#'
#' @export
renvoyer_inventaire_video <- function(import, gpkg = NULL, rasters = NULL,
                                      etats = c("a_completer", "a_verifier"),
                                      filtrer = TRUE, output_dir,
                                      project_name = "inventaire_video_retour",
                                      overwrite = TRUE) {
  if (!is.list(import) || is.null(import$placettes) || is.null(import$arbres)) {
    cli::cli_abort("{.arg import} must be the result of {.fn importer_inventaire_video}.")
  }
  dom <- attr(schema_inventaire_video(), "domaines")$etat_detection
  inconnus <- setdiff(etats, dom)
  if (!length(etats) || length(inconnus)) {
    cli::cli_abort(c("{.arg etats} must be values of {.val etat_detection}.",
                     i = "Allowed: {.val {dom}}."))
  }
  if (!is.character(project_name) || length(project_name) != 1L ||
      is.na(project_name) || !grepl("^[A-Za-z0-9_-]+$", project_name)) {
    cli::cli_abort(c(
      "{.arg project_name} must be a single name made of letters, digits, {.val _} or {.val -}.",
      "x" = "Got {.val {project_name}}."
    ))
  }
  rlang::check_installed(c("DBI", "RSQLite"), reason = "to install the GeoPackage triggers.")

  arbres <- sf::st_transform(import$arbres, 2154)
  etat <- as.character(.iv_col(arbres, "etat_detection", NA_character_))
  cibles <- !is.na(etat) & etat %in% etats
  if (!any(cibles)) {
    cli::cli_abort("No tree in state {.val {etats}}: nothing to send back.")
  }
  plot_ids <- sort(unique(as.character(arbres$plot_id[cibles])))
  placettes <- sf::st_transform(import$placettes, 2154)
  placettes <- placettes[placettes$plot_id %in% plot_ids, ]
  arbres <- arbres[arbres$plot_id %in% plot_ids, ]

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  qgz_path <- file.path(output_dir, paste0(project_name, ".qgz"))
  if (file.exists(qgz_path) && !overwrite) {
    cli::cli_abort("File {.path {qgz_path}} already exists (overwrite = FALSE).")
  }
  stage <- tempfile("inventaire_video_retour_")
  dir.create(file.path(stage, "rasters"), recursive = TRUE)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  gpkg_rel <- "inventaire_video.gpkg"
  sortie <- file.path(stage, gpkg_rel)
  schema <- schema_inventaire_video()

  # Couches annexes des mêmes placettes, depuis le GeoPackage de terrain.
  annexe <- function(couche) {
    if (is.null(gpkg) || !couche %in% sf::st_layers(gpkg)$name) return(NULL)
    # Table `projet` sans géométrie : st_read prévient qu'il rend un data.frame.
    x <- suppressWarnings(sf::st_read(gpkg, layer = couche, quiet = TRUE))
    # projet, parcelles, ugf : copiées telles quelles (carte de Groma).
    if (couche %in% c("projet", "parcelles", "ugf")) return(if (nrow(x)) x)
    if (!nrow(x) || !"plot_id" %in% names(x)) return(NULL)
    sf::st_transform(x[x$plot_id %in% plot_ids, ], 2154)
  }
  projet_nom <- NA_character_
  for (couche in names(schema)) {
    champs <- schema[[couche]]
    x <- switch(couche, placettes = placettes, arbres = arbres, annexe(couche))
    if (couche == "projet" && !is.null(x) && nrow(x)) projet_nom <- as.character(x$projet_nom[1])
    x <- .iv_conformer(x, champs, attr(champs, "geometrie"))
    .iv_ecrire_couche(x, sortie, couche, attr(champs, "index_spatial"))
  }
  .iv_poser_declencheurs(sortie)

  fichiers_r <- character(0)
  if (!is.null(rasters)) {
    candidats <- file.path("rasters", c(paste0(plot_ids, "_mnt.tif"),
                                        paste0(plot_ids, "_mnh.tif")))
    for (f in candidats) {
      src <- file.path(rasters, basename(f))
      if (file.exists(src) && file.copy(src, file.path(stage, f))) {
        fichiers_r <- c(fichiers_r, f)
      }
    }
  }

  subset <- if (isTRUE(filtrer)) {
    sprintf('"etat_detection" IN (%s)', paste0("'", etats, "'", collapse = ", "))
  }
  rayon <- as.numeric(.iv_col(placettes, "rayon_m", NA_real_))
  rayon[is.na(rayon)] <- 20
  bbox <- tryCatch(sf::st_bbox(sf::st_buffer(placettes, rayon + 10)),
                   error = function(e) NULL)
  .iv_empaqueter(stage, gpkg_rel, fichiers_r, schema, bbox, project_name,
                 qgz_path, subset_arbres = subset, projet_nom = projet_nom)
  cli::cli_alert_success(
    "Field return project created: {.path {qgz_path}} ({sum(cibles)} tree{?s}, {length(plot_ids)} plot{?s})"
  )
  attr(qgz_path, "plot_ids") <- plot_ids
  attr(qgz_path, "n_arbres") <- sum(cibles)
  invisible(qgz_path)
}

# Empile deux sf aux colonnes différentes (colonnes manquantes à NA).
.iv_empiler <- function(a, b) {
  if (is.null(a) || !nrow(a)) return(b)
  if (is.null(b) || !nrow(b)) return(a)
  b <- sf::st_transform(b, sf::st_crs(a))
  geo_a <- attr(a, "sf_column")
  sf::st_geometry(b) <- sf::st_geometry(b)
  names(b)[names(b) == attr(b, "sf_column")] <- geo_a
  sf::st_geometry(b) <- geo_a
  cols <- union(setdiff(names(a), geo_a), setdiff(names(b), geo_a))
  for (col in setdiff(cols, names(a))) a[[col]] <- NA
  for (col in setdiff(cols, names(b))) b[[col]] <- NA
  rbind(a[, c(cols, geo_a)], b[, c(cols, geo_a)])
}

# Fusion par plot_id dans data/field_data.gpkg, sans rien écraser.
.iv_fusionner <- function(chemin, placettes, arbres, priorite) {
  lire <- function(couche) {
    if (file.exists(chemin) && couche %in% sf::st_layers(chemin)$name) {
      sf::st_read(chemin, layer = couche, quiet = TRUE)
    } else NULL
  }
  marquer <- function(x, source) {
    if (is.null(x)) return(NULL)
    if (!"source" %in% names(x)) x$source <- source
    x$source[is.na(x$source)] <- source
    x
  }
  p_ex <- marquer(lire("placettes"), "inventaire_terrain")
  a_ex <- marquer(lire("arbres"), "inventaire_terrain")
  p_alt <- lire("placettes_alternatives")
  a_alt <- lire("arbres_alternatives")
  placettes$source <- "inventaire_video"
  arbres$source <- "inventaire_video"

  communs <- if (is.null(p_ex)) character(0) else intersect(placettes$plot_id, p_ex$plot_id)
  if (priorite == "video" && length(communs)) {
    # La version vidéo prend la place principale, l'ancienne va à côté.
    p_alt <- .iv_empiler(p_alt, p_ex[p_ex$plot_id %in% communs, ])
    if (!is.null(a_ex)) a_alt <- .iv_empiler(a_alt, a_ex[a_ex$plot_id %in% communs, ])
    p_ex <- p_ex[!p_ex$plot_id %in% communs, ]
    if (!is.null(a_ex)) a_ex <- a_ex[!a_ex$plot_id %in% communs, ]
    p_main <- .iv_empiler(p_ex, placettes)
    a_main <- .iv_empiler(a_ex, arbres)
  } else {
    p_alt <- .iv_empiler(p_alt, placettes[placettes$plot_id %in% communs, ])
    a_alt <- .iv_empiler(a_alt, arbres[arbres$plot_id %in% communs, ])
    p_main <- .iv_empiler(p_ex, placettes[!placettes$plot_id %in% communs, ])
    a_main <- .iv_empiler(a_ex, arbres[!arbres$plot_id %in% communs, ])
  }

  conserve <- if (priorite == "classique") communs else character(0)
  .atomic_write(chemin, function(tmp) {
    if (file.exists(chemin)) file.copy(chemin, tmp)
    for (couche in c("placettes", "arbres", "placettes_alternatives", "arbres_alternatives")) {
      x <- switch(couche, placettes = p_main, arbres = a_main,
                  placettes_alternatives = p_alt, arbres_alternatives = a_alt)
      if (!is.null(x)) {
        sf::st_write(x, tmp, layer = couche, quiet = TRUE, append = FALSE, delete_layer = TRUE)
      }
    }
  })
  # Placettes dont l'inventaire classique reste dans les couches principales.
  conserve
}


# ---- Client du serveur Groma ------------------------------------------

.groma_requete <- function(url, jeton, chemin) {
  rlang::check_installed("httr2", reason = "to talk to the Groma server.")
  req <- httr2::request(sub("/+$", "", url))
  req <- httr2::req_url_path_append(req, chemin)
  if (!is.null(jeton) && nzchar(jeton)) req <- httr2::req_auth_bearer_token(req, jeton)
  httr2::req_timeout(req, 60)
}

#' Groma server client
#'
#' \code{groma_etat_placettes()} lists the plots known to the Groma server
#' (\code{GET /placettes}) and their processing state.
#' \code{groma_telecharger_resultats()} downloads, for each plot, the
#' definitive result (\code{GET /placettes/{plot_id}/resultat.gpkg}) and the
#' reports (\code{rapport.json}, \code{rapport.html}). Requires \pkg{httr2}.
#'
#' @param url Base URL of the Groma server.
#' @param jeton Bearer token (\code{NULL} for none).
#' @param plot_ids Character vector of plots to download.
#' @param dossier Destination directory (created if needed).
#' @param fichiers Files to download per plot. Default all three.
#'
#' @return \code{groma_etat_placettes()}: a data.frame, one row per plot.
#'   \code{groma_telecharger_resultats()}: character vector of the downloaded
#'   files (\code{<plot_id>_<fichier>}), with the attribute \code{detail}, a
#'   data.frame \code{plot_id}, \code{fichier}, \code{chemin} (\code{NA} when
#'   the download failed), \code{statut} (HTTP status).
#'
#' @section Lifecycle:
#' Experimental (spec 061).
#'
#' @export
groma_etat_placettes <- function(url, jeton = NULL) {
  resp <- httr2::req_perform(.groma_requete(url, jeton, "placettes"))
  corps <- httr2::resp_body_json(resp, simplifyVector = TRUE)
  if (is.list(corps) && !is.data.frame(corps) && !is.null(corps$placettes)) {
    corps <- corps$placettes
  }
  as.data.frame(corps, stringsAsFactors = FALSE)
}

#' @rdname groma_etat_placettes
#' @export
groma_telecharger_resultats <- function(url, jeton = NULL, plot_ids, dossier,
                                        fichiers = c("resultat.gpkg", "rapport.json",
                                                     "rapport.html")) {
  if (any(!grepl("^[A-Za-z0-9_.-]+$", plot_ids))) {
    cli::cli_abort("{.arg plot_ids} must be made of letters, digits, {.val _}, {.val .} or {.val -}.")
  }
  fichiers <- match.arg(fichiers, several.ok = TRUE)
  dir.create(dossier, showWarnings = FALSE, recursive = TRUE)
  lignes <- list()
  for (pid in plot_ids) {
    for (f in fichiers) {
      cible <- file.path(dossier, paste0(pid, "_", f))
      req <- httr2::req_error(.groma_requete(url, jeton, c("placettes", pid, f)),
                              is_error = function(resp) FALSE)
      resp <- httr2::req_perform(req)
      statut <- httr2::resp_status(resp)
      chemin <- NA_character_
      if (statut < 300) {
        writeBin(httr2::resp_body_raw(resp), cible)
        chemin <- cible
      } else {
        cli::cli_warn("Groma: {.val {pid}}/{f} unavailable (HTTP {statut}).")
      }
      lignes[[length(lignes) + 1L]] <- data.frame(plot_id = pid, fichier = f, chemin = chemin,
                                                  statut = statut, stringsAsFactors = FALSE)
    }
  }
  detail <- do.call(rbind, lignes)
  chemins <- detail$chemin[!is.na(detail$chemin)]
  attr(chemins, "detail") <- detail
  chemins
}

# Empreinte SHA-256 d'un fichier (openssl, installé avec httr2).
.groma_sha256 <- function(chemin) {
  con <- file(chemin, "rb")
  on.exit(close(con), add = TRUE)
  as.character(openssl::sha256(con))
}

# Erreur HTTP du serveur Groma, message selon le statut.
.groma_verifier <- function(resp, quoi) {
  statut <- httr2::resp_status(resp)
  if (statut < 300) return(invisible(resp))
  msg <- switch(as.character(statut),
    "401" = "Groma server refused the token (HTTP 401).",
    "403" = "Groma server refused the token (HTTP 403).",
    "413" = "Project too large for the Groma server (HTTP 413).",
    "422" = "A file was altered during the upload: the server's checksum differs (HTTP 422).",
    sprintf("Groma server error on %s (HTTP %d).", quoi, statut))
  cli::cli_abort(msg)
}

#' Publish the video inventory QField project on the Groma server
#'
#' Sends the \code{.qgz} built by \code{\link{creer_projet_inventaire_video}}
#' (and its plugin \code{<same name>.qml} when present next to it) to the
#' Groma server, which offers it to the phone (\dQuote{Projets du
#' serveur}). The project is identified by \code{projet_id}, read from the
#' \code{projet} table of the GeoPackage inside the \code{.qgz}.
#'
#' Calls, with the bearer token: \code{PUT
#' {url}/projets/{projet_id}/qfield/fichiers/{nom}} (raw body) for the
#' \code{.qgz}, then the \code{.qml}; then \code{POST
#' {url}/projets/{projet_id}/qfield/publier} with \code{projet_nom},
#' \code{fichiers} (\code{nom}, \code{sha256}, \code{taille}),
#' \code{genere_le} and \code{nemeton_version}. Requires \pkg{httr2} and
#' \pkg{openssl}.
#'
#' @param qgz Path to the \code{.qgz}.
#' @param url Base URL of the Groma server.
#' @param jeton Bearer token (\code{NULL} for none).
#' @param projet_nom Optional display name; default \code{projet_nom} of the
#'   \code{projet} table.
#'
#' @return Invisibly, a list \code{projet_id}, \code{version} (as returned by
#'   the server, \code{NA} when absent) and \code{taille} (bytes sent).
#'
#' @section Lifecycle:
#' Experimental (spec 061).
#'
#' @export
groma_envoyer_projet <- function(qgz, url, jeton = NULL, projet_nom = NULL) {
  rlang::check_installed(c("httr2", "openssl"), reason = "to publish on the Groma server.")
  if (!is.character(qgz) || length(qgz) != 1L || !file.exists(qgz)) {
    cli::cli_abort("{.arg qgz} must be the path of an existing {.file .qgz}.")
  }
  # projet_id / projet_nom : table `projet` du GeoPackage du .qgz.
  tmp <- tempfile("groma_envoi_")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  contenu <- utils::unzip(qgz, list = TRUE)$Name
  gpkg <- grep("\\.gpkg$", contenu, value = TRUE)[1]
  projet <- if (!is.na(gpkg)) tryCatch({
    utils::unzip(qgz, files = gpkg, exdir = tmp)
    suppressWarnings(sf::st_read(file.path(tmp, gpkg), layer = "projet", quiet = TRUE))
  }, error = function(e) NULL)
  pid <- if (!is.null(projet) && nrow(projet)) as.character(projet$projet_id[1]) else NA_character_
  if (is.na(pid) || !grepl("^[A-Za-z0-9_.-]{1,64}$", pid)) {
    cli::cli_abort(c(
      "No valid {.field projet_id} in the {.val projet} table of {.path {basename(qgz)}}.",
      i = "Build the project with {.fn creer_projet_inventaire_video} and {.arg project_path}."
    ))
  }
  if (is.null(projet_nom)) projet_nom <- as.character(projet$projet_nom[1])

  qml <- sub("\\.qgz$", ".qml", qgz)
  fichiers <- c(qgz, if (file.exists(qml)) qml)
  decrit <- lapply(fichiers, function(f) {
    list(nom = basename(f), sha256 = .groma_sha256(f), taille = unname(file.size(f)))
  })
  for (f in fichiers) {
    req <- .groma_requete(url, jeton, c("projets", pid, "qfield", "fichiers", basename(f)))
    req <- httr2::req_method(req, "PUT")
    req <- httr2::req_body_file(req, f, type = "application/octet-stream")
    req <- httr2::req_error(req, is_error = function(resp) FALSE)
    resp <- tryCatch(httr2::req_perform(req), error = function(e) {
      cli::cli_abort("Groma server unreachable at {.url {url}}.", parent = e)
    })
    .groma_verifier(resp, basename(f))
  }
  req <- .groma_requete(url, jeton, c("projets", pid, "qfield", "publier"))
  req <- httr2::req_method(req, "POST")
  req <- httr2::req_body_json(req, list(
    projet_nom = projet_nom, fichiers = decrit,
    genere_le = format(as.POSIXct(file.mtime(qgz)), "%Y-%m-%dT%H:%M:%S%z"),
    nemeton_version = as.character(utils::packageVersion("nemeton"))
  ), auto_unbox = TRUE)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req), error = function(e) {
    cli::cli_abort("Groma server unreachable at {.url {url}}.", parent = e)
  })
  .groma_verifier(resp, "publier")
  corps <- tryCatch(httr2::resp_body_json(resp), error = function(e) list())
  cli::cli_alert_success("Project {.val {pid}} published on the Groma server.")
  invisible(list(projet_id = pid, version = corps$version %||% NA,
                 taille = sum(vapply(decrit, `[[`, numeric(1), "taille"))))
}
