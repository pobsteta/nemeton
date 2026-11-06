#' B5: Vertical stratification from the LiDAR point cloud
#'
#' Vertical structure of each unit read in the LiDAR point cloud itself, not
#' in a canopy height model: Shannon entropy of the distribution of returns
#' (or of foliage density) between five height strata, on 0-100
#' (100 = even distribution between the strata). B2 reads the canopy surface
#' seen from above; B5 reads what lies under it (spec 067, chantier C, first
#' step, without ForPT). Source-conditional: without a point cloud, B5 is `NA`
#' with its status and the B family is unchanged.
#'
#' @param units sf polygon layer (spatial units / UGF).
#' @param nuage The point cloud, one of:
#'   \itemize{
#'     \item a `data.frame` (or matrix) with columns `X`, `Y`, `Z`, and
#'       optionally `Classification`, in the CRS of `units`;
#'     \item a `LAS` object of \pkg{lidR};
#'     \item a character vector of `.laz` / `.las` files, or a directory
#'       holding them (e.g. `<project>/cache/layers/lidar_nuage`), read tile
#'       by tile with \pkg{lidR} (in Suggests) and clipped to the units.
#'   }
#'   `NULL`: B5 is `NA` with status `skipped_no_lidar`.
#' @param layers Unused, accepted for [nemeton_compute()].
#' @param strates Numeric. Lower bounds of the strata in metres, starting at
#'   0. Default `c(0, 2, 5, 10, 20)`: strata 0-2, 2-5, 5-10, 10-20 and
#'   > 20 m (spec 067).
#' @param profil `"points"` (default, spec 067 D-3): share of vegetation
#'   returns in each stratum. `"densite_foliaire"`: share of foliage density
#'   in each stratum, from the gap fraction (MacArthur & Horn 1969), which
#'   corrects part of the occlusion of the lower strata by the upper ones.
#' @param normaliser Logical. Are `Z` values altitudes that must first be
#'   turned into heights above ground? `TRUE` needs \pkg{lidR} and ground
#'   returns (class 2): heights are taken above a TIN of the ground returns,
#'   tile by tile. Default `FALSE` (heights already normalised). A cloud
#'   whose median `Z` exceeds `hauteur_max` is refused rather than read as
#'   heights.
#' @param hauteur_sol Numeric. Returns below this height (m) are ground: they
#'   count in no stratum, but they enter the gap fraction of
#'   `"densite_foliaire"`. Default 0.5.
#' @param hauteur_max Numeric. Returns above this height (m) are noise and
#'   dropped, as are returns below -1 m. Default 60.
#' @param classes Integer. Classification codes kept when the cloud has a
#'   `Classification` column. Default `c(1:5, 9)`: unclassified, ground, the
#'   three vegetation classes and water of IGN LiDAR HD; buildings (6),
#'   noise (7, 18), bridges (17) and the IGN classes 64-67 are dropped.
#' @param min_points Integer. Minimum number of returns in a unit (ground
#'   included); below it, B5 is `NA` with status `skipped_low_density`.
#'   Default 100.
#' @param resolution Numeric. Size (m) of the grid used to assign returns to
#'   units (a return belongs to the unit holding the centre of its cell).
#'   Default 1.
#'
#' @return `units` with
#'   \describe{
#'     \item{B5}{score 0-100, 100 = returns (or foliage) evenly spread over
#'       the strata; 0 = a single stratum, or no vegetation above
#'       `hauteur_sol`.}
#'     \item{b5_status}{`calculated`, `skipped_no_lidar`,
#'       `skipped_no_coverage` (no return in the unit) or
#'       `skipped_low_density` (fewer than `min_points`).}
#'     \item{b5_profil}{`profil` used.}
#'     \item{b5_points}{number of returns in the unit (ground included).}
#'     \item{b5_densite}{returns per square metre.}
#'     \item{b5_s1, ..., b5_sK}{share of each stratum (sums to 1), from the
#'       lowest to the highest.}
#'   }
#'
#' @details
#' **Score.** With `p_k` the share of stratum `k` among `K` strata,
#' `B5 = 100 * (-sum(p_k * log(p_k)) / log(K))`: the Shannon entropy
#' normalised by its maximum, i.e. the evenness of the vertical profile. It
#' is the LiDAR form of the foliage height diversity of MacArthur &
#' MacArthur (1961). It needs no ForPT (spec 067, D-3); ForPT will be used
#' later to separate wood from foliage.
#'
#' **`"densite_foliaire"`.** With `P(h)` the share of returns below height
#' `h` (ground included), the foliage of stratum `[a, b)` is proportional to
#' `log(P(b) / P(a))` (MacArthur & Horn 1969; the extinction coefficient
#' cancels out in the shares). A unit without ground return gets a floor of
#' half a return at `hauteur_sol`.
#'
#' **Pitfalls** (fiche B5): at about 10 returns per square metre (LiDAR HD),
#' the lower strata of closed stands are under-sampled, so `"points"`
#' underestimates the stratification of closed stands (measured by the
#' dimensioning of spec 067); a leaf-on and a leaf-off flight do not give the
#' same profile; B5 measures evenness, not height: a 2 m thicket split
#' between two strata can score as high as a high forest.
#'
#' @section Lifecycle:
#' Experimental (spec 067): may change in any release.
#'
#' @references
#' MacArthur, R. H. & MacArthur, J. W. (1961). On bird species diversity.
#' *Ecology* 42(3), 594-598.
#'
#' MacArthur, R. H. & Horn, H. S. (1969). Foliage profile by vertical
#' measurements. *Ecology* 50(5), 802-804.
#'
#' @seealso [indicateur_b2_structure()], [compute_dtm_chm_from_laz()]
#' @export
#' @examples
#' units <- sf::st_sf(
#'   id = 1:2,
#'   geometry = sf::st_sfc(
#'     sf::st_polygon(list(rbind(c(0, 0), c(20, 0), c(20, 20), c(0, 20), c(0, 0)))),
#'     sf::st_polygon(list(rbind(c(20, 0), c(40, 0), c(40, 20), c(20, 20), c(20, 0)))),
#'     crs = 2154
#'   )
#' )
#' set.seed(1)
#' n <- 4000
#' nuage <- data.frame(X = runif(n, 0, 40), Y = runif(n, 0, 20))
#' # unit 1: one high layer; unit 2: returns spread over the whole height
#' nuage$Z <- ifelse(nuage$X < 20, runif(n, 22, 28), runif(n, 0, 30))
#' indicateur_b5_stratification(units, nuage)$B5
indicateur_b5_stratification <- function(units,
                                         nuage = NULL,
                                         layers = NULL,
                                         strates = c(0, 2, 5, 10, 20),
                                         profil = c("points", "densite_foliaire"),
                                         normaliser = FALSE,
                                         hauteur_sol = 0.5,
                                         hauteur_max = 60,
                                         classes = c(1:5, 9),
                                         min_points = 100L,
                                         resolution = 1) {
  if (!inherits(units, "sf")) cli::cli_abort("units must be an sf object")
  profil <- match.arg(profil)
  if (!is.numeric(strates) || length(strates) < 2L || strates[1] != 0 ||
      is.unsorted(strates, strictly = TRUE)) {
    cli::cli_abort("{.arg strates} must be increasing lower bounds starting at 0.")
  }
  if (hauteur_sol >= strates[2]) {
    cli::cli_abort("{.arg hauteur_sol} must be below the second stratum ({strates[2]} m).")
  }
  n <- nrow(units)
  K <- length(strates)

  sortie <- function(valeur, statut, points = rep(NA_real_, n),
                     densite = rep(NA_real_, n),
                     parts = matrix(NA_real_, n, K)) {
    units$B5 <- as.numeric(valeur)
    units$b5_status <- rep_len(as.character(statut), n)
    units$b5_profil <- rep_len(profil, n)
    units$b5_points <- as.numeric(points)
    units$b5_densite <- as.numeric(densite)
    for (k in seq_len(K)) units[[paste0("b5_s", k)]] <- parts[, k]
    units
  }

  if (is.null(nuage)) {
    cli::cli_alert_info("B5: no point cloud, returning NA (no measurement made)")
    return(sortie(NA_real_, "skipped_no_lidar"))
  }
  if (n == 0L) return(sortie(numeric(0), character(0)))

  # 1. Grille d'affectation des retours aux UGF
  grille <- .b5_grille(units, resolution)

  # 2. Comptes par UGF : colonne 1 = sol, colonnes 2..K+1 = strates
  bornes <- c(hauteur_sol, strates[-1])
  compter <- function(xyz) {
    .b5_tabuler(.b5_codes(xyz, grille, bornes, hauteur_max, classes)$code, n, K)
  }
  comptes <- .b5_lire_et_compter(nuage, units, compter, normaliser, hauteur_max)

  # 3. Parts, entropie et statuts
  sc <- .b5_scores(comptes, profil, min_points)
  aire <- as.numeric(sf::st_area(units))
  sortie(sc$valeur, sc$statut, points = sc$total,
         densite = ifelse(aire > 0, sc$total / aire, NA_real_), parts = sc$parts)
}

# Score B5, statut et parts a partir des comptes (n x (K+1)).
.b5_scores <- function(comptes, profil, min_points) {
  total <- rowSums(comptes)
  parts <- .b5_parts(comptes, profil)
  H <- apply(parts, 1L, .b5_equitabilite)
  statut <- ifelse(total == 0, "skipped_no_coverage",
                   ifelse(total < min_points, "skipped_low_density", "calculated"))
  ok <- statut == "calculated"
  parts[!ok, ] <- NA_real_
  list(valeur = ifelse(ok, round(100 * H, 2), NA_real_), statut = statut,
       total = total, parts = parts)
}

# Grille de l'emprise des UGF, chaque cellule portant l'indice de son UGF.
.b5_grille <- function(units, resolution) {
  v <- terra::vect(units)
  v$.b5_idx <- seq_len(nrow(units))
  modele <- terra::rast(terra::ext(v), resolution = resolution, crs = terra::crs(v))
  terra::rasterize(v, modele, field = ".b5_idx")
}

# Code de chaque retour retenu : (UGF - 1) * (K + 1) + classe + 1, ou la
# classe 0 est le sol (z < hauteur_sol) et 1..K les strates. Rend aussi
# l'identifiant d'impulsion (gpstime) quand le nuage le porte.
.b5_codes <- function(xyz, grille, bornes, hauteur_max, classes) {
  K <- length(bornes)
  vide <- list(code = integer(0), impulsion = NULL)
  if (!NROW(xyz)) return(vide)
  garde <- is.finite(xyz$Z) & xyz$Z >= -1 & xyz$Z <= hauteur_max
  if (!is.null(xyz$Classification) && length(classes)) {
    garde <- garde & xyz$Classification %in% classes
  }
  if (!any(garde)) return(vide)
  cellule <- terra::cellFromXY(grille, cbind(xyz$X[garde], xyz$Y[garde]))
  ugf <- rep(NA_integer_, length(cellule))
  dedans <- !is.na(cellule)
  ugf[dedans] <- as.integer(terra::values(grille, mat = FALSE)[cellule[dedans]])
  ok <- !is.na(ugf)
  if (!any(ok)) return(vide)
  classe <- findInterval(xyz$Z[garde][ok], bornes)
  impulsion <- if (!is.null(xyz$gpstime)) xyz$gpstime[garde][ok]
  list(code = (ugf[ok] - 1L) * (K + 1L) + classe + 1L, impulsion = impulsion)
}

# Matrice des comptes (n x (K+1)) a partir des codes.
.b5_tabuler <- function(code, n, K) {
  matrix(tabulate(code, nbins = n * (K + 1L)), n, K + 1L, byrow = TRUE)
}

# Lit le nuage sous l'une de ses formes et cumule les comptes.
.b5_lire_et_compter <- function(nuage, units, compter, normaliser, hauteur_max,
                                combiner = `+`) {
  verifier <- function(z) {
    if (length(z) && stats::median(z, na.rm = TRUE) > hauteur_max) {
      cli::cli_abort(c(
        "B5: the median Z of the cloud is above {.arg hauteur_max}: these look like altitudes, not heights.",
        i = "Set {.code normaliser = TRUE} to take heights above the ground returns."
      ))
    }
  }

  if (inherits(nuage, "LAS")) {
    if (isTRUE(normaliser)) nuage <- .b5_normaliser(nuage)
    d <- as.data.frame(nuage@data)
    verifier(d$Z)
    return(compter(d))
  }

  if (is.data.frame(nuage) || is.matrix(nuage)) {
    d <- as.data.frame(nuage)
    if (!all(c("X", "Y", "Z") %in% names(d))) {
      cli::cli_abort("A point table needs columns {.field X}, {.field Y} and {.field Z}.")
    }
    if (isTRUE(normaliser)) {
      cli::cli_abort("{.code normaliser = TRUE} needs a LAS object or LAZ files, not a table.")
    }
    verifier(d$Z)
    return(compter(d))
  }

  if (is.character(nuage)) {
    fichiers <- unlist(lapply(nuage, function(p) {
      if (dir.exists(p)) {
        list.files(p, pattern = "\\.la[sz]$", full.names = TRUE, ignore.case = TRUE)
      } else p
    }))
    fichiers <- fichiers[file.exists(fichiers)]
    if (!length(fichiers)) {
      cli::cli_abort("No {.file .laz} / {.file .las} file found in {.arg nuage}.")
    }
    if (!.b5_lidr_ok()) {
      cli::cli_abort(c(
        "{.pkg lidR} is required to read LAZ files for B5.",
        i = "Install it: {.code install.packages('lidR')}, or pass a point table."
      ))
    }
    bb <- sf::st_bbox(units)
    filtre <- sprintf("-keep_xy %f %f %f %f", bb[["xmin"]], bb[["ymin"]],
                      bb[["xmax"]], bb[["ymax"]])
    total <- NULL
    for (f in fichiers) {
      d <- .b5_lire_dalle(f, filtre, normaliser)
      if (is.null(d)) next
      verifier(d$Z)
      m <- compter(d)
      total <- if (is.null(total)) m else combiner(total, m)
    }
    if (is.null(total)) total <- compter(data.frame(X = numeric(0), Y = numeric(0), Z = numeric(0)))
    return(total)
  }

  cli::cli_abort("{.arg nuage} must be a point table, a LAS object, or LAZ files.")
}

# lidR est-il installe ? (fonction a part pour pouvoir la simuler en test)
.b5_lidr_ok <- function() requireNamespace("lidR", quietly = TRUE)

# Une dalle lue par lidR, rognee a l'emprise, normalisee si demande ; NULL
# si elle ne contient aucun point dans l'emprise.
.b5_lire_dalle <- function(fichier, filtre, normaliser) {
  las <- lidR::readLAS(fichier, select = "xyztc", filter = filtre)
  if (lidR::is.empty(las)) return(NULL)
  if (isTRUE(normaliser)) las <- .b5_normaliser(las)
  as.data.frame(las@data)
}

# Hauteurs au-dessus d'un TIN des retours sol (classe 2), par lidR.
.b5_normaliser <- function(las) {
  if (!.b5_lidr_ok()) {
    cli::cli_abort("{.pkg lidR} is required for {.code normaliser = TRUE}.")
  }
  lidR::normalize_height(las, lidR::tin())
}

# Parts de chaque strate (matrice n x K) a partir des comptes (n x (K+1)).
.b5_parts <- function(comptes, profil) {
  veg <- comptes[, -1L, drop = FALSE]
  if (profil == "points") {
    s <- rowSums(veg)
    parts <- veg / ifelse(s > 0, s, 1)
    parts[s == 0, ] <- 0
    return(parts)
  }
  # MacArthur & Horn : P(h) = part des retours sous h ; feuillage de [a, b)
  # proportionnel a log(P(b) / P(a)).
  N <- rowSums(comptes)
  dessous <- t(apply(comptes, 1L, cumsum))     # retours sous la borne haute de chaque classe
  P <- dessous / ifelse(N > 0, N, 1)           # P a hauteur_sol, puis aux bornes hautes
  P[, 1] <- pmax(P[, 1], 0.5 / pmax(N, 1))      # plancher sans retour sol
  K <- ncol(veg)
  lai <- log(P[, 2:(K + 1L), drop = FALSE] / P[, 1:K, drop = FALSE])
  lai[!is.finite(lai)] <- 0
  s <- rowSums(lai)
  parts <- lai / ifelse(s > 0, s, 1)
  parts[s == 0, ] <- 0
  parts
}

# Entropie de Shannon normalisee (equitabilite de Pielou) d'un vecteur de parts.
.b5_equitabilite <- function(p) {
  K <- length(p)
  if (sum(p) <= 0) return(0)
  p <- p[p > 0]
  -sum(p * log(p)) / log(K)
}
