# ugf_onf.R — UGF d'une forêt publique construites depuis le parcellaire ONF
# calé sur le cadastre (spec 058).
# ---------------------------------------------------------------------------
# Règle de Pascal (2026-10-07/08) : les parcelles forestières ne sont qu'une
# partition des parcelles cadastrales. On part TOUJOURS du cadastre, qu'on
# agrège et qu'on coupe ; le cadastre n'est jamais déformé, c'est la couche ONF,
# qui déborde, qu'on ajuste.
#
# Chaîne (brief 2026-10-08, § 3) :
#   3.1 parcelles cadastrales candidates : PCI touchant l'union ONF, commune ;
#   3.2 calage élastique de l'ONF sur toutes les limites des candidates ;
#   3.3 sélection : propriétaire public (DGFiP) ET couverture ONF calée >= 50 % ;
#   3.4 découpage par accrochage (ouverture morphologique) dans chaque parcelle ;
#   3.5 rattachements finaux des petits morceaux et des petites UGF.
#
# Tout se fait en mètres, au centimètre (`.ugf_prec`) : sans grille commune, deux
# morceaux voisins ne partagent pas exactement leurs sommets et les tests de
# voisinage échouent.

# Groupes DGFiP des personnes publiques (`groupe_personne_code`) : 1 État,
# 2 région, 3 département, 4 commune, 9 établissements publics ou organismes
# associés. Les offices HLM (5), SEM (6), copropriétaires (7), associés (8) et
# personnes morales non remarquables (0) n'en sont pas.
.DGFIP_GROUPES_PUBLICS <- c("1", "2", "3", "4", "9")

# Jeu data.gouv.fr « Fichiers des locaux et des parcelles des personnes morales
# (version unifiée) » et sa ressource nationale la plus récente.
.DGFIP_DATASET_ID <- "6900772ca5c4fa6c5687b3bd"
.DGFIP_RESSOURCE <- "parcelles_personnes_morales_latest.parquet"

.ugf_prec <- function(x) sf::st_make_valid(sf::st_set_precision(x, 100))

# Surfaces et seuils n'ont de sens qu'en mètres.
.ugf_crs_travail <- function(crs) {
  if (isTRUE(sf::st_is_longlat(crs))) sf::st_crs(2154) else sf::st_crs(crs)
}

# Parties simples d'un sf ; ne garde que les polygones non vides. En DEUX
# temps, et ce n'est pas un détail : sur un mélange POLYGON/MULTIPOLYGON,
# `st_cast("POLYGON")` ne garde que le PREMIER polygone de chaque
# multipartie, sans erreur ni avertissement (Couchey, v0.189.0 : 13,74 ha des
# 50,34 évaporés). Passer par MULTIPOLYGON d'abord force l'éclatement.
.ugf_polygones <- function(x) {
  if (!nrow(x)) return(x)
  x <- x[!sf::st_is_empty(sf::st_geometry(x)), , drop = FALSE]
  if (!nrow(x)) return(x)
  types <- as.character(sf::st_geometry_type(x))
  if (!all(types %in% c("POLYGON", "MULTIPOLYGON"))) {
    x <- suppressWarnings(sf::st_collection_extract(x, "POLYGON", warn = FALSE))
  }
  x <- suppressWarnings(sf::st_cast(sf::st_cast(x, "MULTIPOLYGON"), "POLYGON",
                                    warn = FALSE))
  x[!sf::st_is_empty(sf::st_geometry(x)), , drop = FALSE]
}

# Fond les lignes de même clé (une ou plusieurs colonnes) en une géométrie ;
# les autres attributs sont ceux de la première ligne du groupe.
.ugf_fondre <- function(x, cles) {
  if (!nrow(x)) return(x)
  cle <- do.call(paste, c(lapply(cles, function(k) x[[k]]), sep = "\r"))
  groupes <- split(seq_along(cle), factor(cle, levels = unique(cle)))
  geo <- sf::st_geometry(x)
  fusion <- do.call(c, lapply(groupes, function(i) {
    if (length(i) == 1L) geo[i] else sf::st_union(geo[i])
  }))
  out <- x[vapply(groupes, `[`, integer(1), 1L), , drop = FALSE]
  sf::st_geometry(out) <- suppressWarnings(sf::st_cast(fusion, "MULTIPOLYGON"))
  row.names(out) <- NULL
  out
}

# Longueur de limite commune entre les géométries de `a` et de `b`, mesurée à
# `tol` près : longueur du bord de a(i) qui passe à moins de `tol` de b(j).
# Les morceaux issus de découpes différentes ne partagent pas exactement leurs
# sommets ; `st_relate("F***1****")` ne trouvait presque aucun voisin à
# Couchey. Une seule intersection vectorisée pour toutes les paires.
# Rend un data.frame (i, j, l) des paires de longueur > 0, i != j si `a` est `b`.
.ugf_longueurs <- function(a, b = NULL, tol = 0.1) {
  meme <- is.null(b)
  if (meme) b <- a
  vide <- data.frame(i = integer(0), j = integer(0), l = numeric(0))
  if (!length(a) || !length(b)) return(vide)
  inter <- suppressWarnings(sf::st_intersection(sf::st_boundary(a),
                                                sf::st_buffer(b, tol)))
  idx <- attr(inter, "idx")
  if (!length(inter) || is.null(idx)) return(vide)
  out <- data.frame(i = idx[, 1], j = idx[, 2],
                    l = as.numeric(sf::st_length(inter)))
  if (meme) out <- out[out$i != out$j, , drop = FALSE]
  out[out$l > 0, , drop = FALSE]
}

# ---------------------------------------------------------------------------
# 3.2 Calage élastique (rubber-sheeting)
# ---------------------------------------------------------------------------

# Déplacement en chaque point de `xy` : moyenne pondérée en 1/d² des `k`
# vecteurs de contrôle les plus proches, amortie par un poids nul 1/rayon².
# Les k voisins viennent de FNN (arbre kd) quand il est installé : à Couchey,
# 25 000 sommets x 7 700 points de contrôle, le tri en R coûtait 25 s des 37 s
# de la chaîne. Sinon, repli en R pur, par blocs pour borner la mémoire.
.ugf_champ <- function(xy, P, V, k, rayon, bloc = 2000L) {
  out <- matrix(0, nrow(xy), 2L)
  if (!nrow(xy) || !nrow(P)) return(out)
  k <- min(k, nrow(P))
  w0 <- 1 / rayon^2
  if (requireNamespace("FNN", quietly = TRUE)) {
    nn <- FNN::get.knnx(P, xy[, 1:2, drop = FALSE], k = k)
    w <- 1 / pmax(nn$nn.dist^2, 1)
    s <- rowSums(w) + w0
    out[, 1] <- rowSums(w * matrix(V[nn$nn.index, 1], ncol = k)) / s
    out[, 2] <- rowSums(w * matrix(V[nn$nn.index, 2], ncol = k)) / s
    return(out)
  }
  for (debut in seq(1L, nrow(xy), by = bloc)) {
    lignes <- debut:min(debut + bloc - 1L, nrow(xy))
    d2 <- outer(xy[lignes, 1], P[, 1], "-")^2 + outer(xy[lignes, 2], P[, 2], "-")^2
    for (r in seq_along(lignes)) {
      o <- if (k < ncol(d2)) sort.int(d2[r, ], index.return = TRUE,
                                       method = "radix")$ix[seq_len(k)]
           else seq_len(ncol(d2))
      w <- 1 / pmax(d2[r, o], 1)
      out[lignes[r], ] <- colSums(V[o, , drop = FALSE] * w) / (sum(w) + w0)
    }
  }
  out
}

# Applique un champ de déplacement à tous les sommets d'un sfc, limites
# intérieures comprises. Deux parcelles voisines partagent leurs sommets : la
# partition ONF reste cohérente.
.ugf_deformer <- function(g, P, V, k, rayon) {
  mats <- function(x) if (is.matrix(x)) list(x) else do.call(c, lapply(x, mats))
  tout <- do.call(c, lapply(g, mats))
  xy <- do.call(rbind, lapply(tout, function(m) m[, 1:2, drop = FALSE]))
  d <- .ugf_champ(xy, P, V, k, rayon)
  pos <- 0L
  refaire <- function(x) {
    if (is.matrix(x)) {
      n <- nrow(x)
      x[, 1:2] <- x[, 1:2] + d[pos + seq_len(n), , drop = FALSE]
      pos <<- pos + n
      return(x)
    }
    structure(lapply(x, refaire), class = class(x))
  }
  sf::st_sfc(lapply(g, refaire), crs = sf::st_crs(g))
}

#' Rubber-sheet the ONF forest parcels onto cadastral boundaries
#'
#' @description
#' Warp the ONF forest-parcel layer so that its outline lands on the cadastral
#' boundaries, **without ever moving the cadastre**. The ONF contour and the
#' cadastral limits are digitised independently: at Couchey (21) they are
#' about 10 m apart at the median, 40 m at the 90th percentile, and no global
#' translation helps (the best one gains 1 ha) — the offset is local.
#'
#' Method (spec 058, § 3.2):
#' 1. **Control points.** The outer contour of the union of the ONF parcels is
#'    sampled every `pas` metres; each point is paired with the nearest point
#'    of **any** boundary of `cadastre` when closer than `dmax`.
#' 2. **Displacement field.** At any vertex, the displacement is the
#'    inverse-square-distance weighted mean of the `k` nearest control
#'    vectors, damped far from them by a null weight of `1 / rayon^2`. The
#'    nearest neighbours come from \pkg{FNN} when it is installed (a pure-R
#'    fallback gives the same result, more slowly).
#' 3. **Application.** The ONF parcels are densified every `pas` metres and
#'    **every** vertex moves, inner limits included, so neighbouring parcels
#'    stay a partition. The result is then simplified (`simplification`
#'    metres) — without it the layer grows tenfold and downstream cutting
#'    slows down by an order of magnitude — and residual overlaps are removed,
#'    largest parcel first.
#'
#' @param onf An `sf` of forest parcels, e.g. from
#'   [load_onf_parcelles_source()]. All attributes are kept.
#' @param cadastre An `sf`/`sfc` of cadastral parcels. Never modified.
#' @param pas Sampling step of the contour and densification step, in metres.
#'   Default `5`.
#' @param dmax Maximum distance between a contour point and the cadastre for
#'   the pair to be a control point, in metres. Default `80`.
#' @param rayon Damping radius, in metres. Default `200`.
#' @param k Number of control vectors averaged at each vertex. Default `12`.
#' @param simplification Simplification tolerance applied after warping, in
#'   metres. Default `1`; `0` to skip.
#' @return `onf` restricted to the parcels within `dmax` of the cadastre,
#'   warped, in the CRS of `onf`. It carries a `calage` attribute: a named
#'   numeric vector with the number of control points (`n_controle`) and the
#'   median and 90th-percentile gap (`ecart_median_m`, `ecart_p90_m`). With no
#'   control point, `onf` is returned unwarped with a warning.
#' @section Lifecycle:
#' Experimental (spec 058): may change in any release.
#' @seealso [construire_ugf_onf()]
#' @export
caler_onf_sur_cadastre <- function(onf, cadastre, pas = 5, dmax = 80,
                                   rayon = 200, k = 12, simplification = 1) {
  if (!inherits(onf, "sf")) cli::cli_abort("{.arg onf} must be an sf.")
  if (!inherits(cadastre, c("sf", "sfc"))) {
    cli::cli_abort("{.arg cadastre} must be an sf or sfc.")
  }
  if (is.na(sf::st_crs(onf)) || is.na(sf::st_crs(cadastre))) {
    cli::cli_abort("Both layers must have a defined CRS.")
  }
  for (a in c("pas", "dmax", "rayon", "k")) {
    v <- get(a)
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v <= 0) {
      cli::cli_abort("{.arg {a}} must be a positive number.")
    }
  }
  crs_sortie <- sf::st_crs(onf)
  crs_travail <- .ugf_crs_travail(crs_sortie)
  onf <- sf::st_make_valid(sf::st_transform(onf, crs_travail))
  cad <- sf::st_transform(sf::st_geometry(cadastre), crs_travail)

  U <- sf::st_union(cad)
  onf <- onf[lengths(sf::st_intersects(onf, sf::st_buffer(U, dmax))) > 0L, ,
             drop = FALSE]
  if (!nrow(onf)) {
    attr(onf, "calage") <- c(n_controle = 0, ecart_median_m = NA_real_,
                             ecart_p90_m = NA_real_)
    return(sf::st_transform(onf, crs_sortie))
  }

  # 1. Points de contrôle : contour ONF -> toutes les limites cadastrales.
  contour <- sf::st_boundary(sf::st_union(sf::st_geometry(onf)))
  limites <- sf::st_union(sf::st_boundary(cad))
  p <- suppressWarnings(sf::st_cast(sf::st_cast(
    sf::st_segmentize(contour, pas), "MULTIPOINT"), "POINT"))
  d <- as.numeric(sf::st_distance(p, limites))
  p <- p[d < dmax]
  if (!length(p)) {
    cli::cli_warn("No ONF contour point lies within {dmax} m of the cadastre; ONF left unwarped.")
    attr(onf, "calage") <- c(n_controle = 0, ecart_median_m = NA_real_,
                             ecart_p90_m = NA_real_)
    return(sf::st_transform(onf, crs_sortie))
  }
  segs <- sf::st_coordinates(sf::st_nearest_points(p, limites))
  # Chaque segment a deux sommets : le point ONF puis sa cible cadastrale.
  P <- segs[c(TRUE, FALSE), c("X", "Y"), drop = FALSE]
  Q <- segs[c(FALSE, TRUE), c("X", "Y"), drop = FALSE]
  V <- Q - P
  ecart <- sqrt(rowSums(V^2))

  # 2-3. Champ appliqué à tous les sommets densifiés, puis simplification.
  g <- sf::st_segmentize(sf::st_geometry(onf), pas)
  g <- .ugf_deformer(g, P, V, k, rayon)
  if (simplification > 0) g <- sf::st_simplify(g, dTolerance = simplification)
  sf::st_geometry(onf) <- g
  onf <- .ugf_prec(onf)
  onf <- .ugf_polygones_fondus(onf)

  # 4. Chevauchements résiduels : la plus grande parcelle d'abord.
  onf <- onf[order(-as.numeric(sf::st_area(onf))), , drop = FALSE]
  sf::st_agr(onf) <- "constant"
  attrs <- setdiff(names(onf), c(attr(onf, "sf_column"), "origins", "n.overlaps"))
  onf <- suppressWarnings(sf::st_difference(onf))
  onf <- onf[, attrs, drop = FALSE]
  onf <- .ugf_polygones_fondus(.ugf_prec(onf))

  attr(onf, "calage") <- c(n_controle = length(ecart),
                           ecart_median_m = stats::median(ecart),
                           ecart_p90_m = unname(stats::quantile(ecart, 0.9)))
  out <- sf::st_transform(onf, crs_sortie)
  attr(out, "calage") <- attr(onf, "calage")
  out
}

# Après `st_make_valid` une ligne peut devenir GEOMETRYCOLLECTION ou se
# scinder : on n'en garde que les polygones, une ligne MULTIPOLYGON par entrée,
# attributs conservés.
.ugf_polygones_fondus <- function(x) {
  if (!nrow(x)) return(x)
  x$.ligne <- seq_len(nrow(x))
  x <- .ugf_fondre(.ugf_polygones(x), ".ligne")
  x$.ligne <- NULL
  x
}

# ---------------------------------------------------------------------------
# Source DGFiP : parcelles des personnes morales
# ---------------------------------------------------------------------------

# IDU cadastral (14 caractères) : code INSEE (5) + préfixe (3, `000` si vide)
# + section complétée à 2 caractères par un `0` à gauche (`A` -> `0A`) +
# numéro de parcelle sur 4 chiffres.
.dgfip_idu <- function(code_insee, prefixe, section, numero) {
  prefixe <- ifelse(is.na(prefixe) | !nzchar(trimws(prefixe)), "000",
                    formatC(trimws(as.character(prefixe)), width = 3, flag = "0"))
  section <- trimws(as.character(section))
  section <- ifelse(nchar(section) == 1L, paste0("0", section), section)
  numero <- formatC(as.integer(numero), width = 4, flag = "0")
  paste0(code_insee, prefixe, section, numero)
}

.dgfip_departement <- function(insee) {
  ifelse(substr(insee, 1, 2) == "97", substr(insee, 1, 3), substr(insee, 1, 2))
}

# URL et horodatage de la ressource nationale, par l'API data.gouv.fr.
.dgfip_resoudre_url <- function(timeout = 30L) {
  api <- paste0("https://www.data.gouv.fr/api/1/datasets/", .DGFIP_DATASET_ID, "/")
  dest <- tempfile(fileext = ".json")
  on.exit(unlink(dest), add = TRUE)
  ancien <- options(timeout = timeout)
  on.exit(options(ancien), add = TRUE)
  ok <- tryCatch(
    identical(suppressWarnings(utils::download.file(api, dest, quiet = TRUE)), 0L),
    error = function(e) FALSE)
  if (!ok) return(NULL)
  meta <- tryCatch(jsonlite::fromJSON(dest, simplifyVector = FALSE),
                   error = function(e) NULL)
  if (is.null(meta)) return(NULL)
  for (r in meta$resources) {
    if (identical(r$title, .DGFIP_RESSOURCE)) {
      stamp <- regmatches(r$url, regexpr("[0-9]{8}-[0-9]{6}", r$url))
      if (!length(stamp)) stamp <- "inconnu"
      return(list(url = r$url, stamp = stamp))
    }
  }
  NULL
}

# Chemin du fichier national en cache, téléchargé si besoin. Un nouveau
# millésime se télécharge à côté ; les anciens fichiers et extraits sont
# supprimés une fois le nouveau en place.
.dgfip_fichier_national <- function(cache_dir) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  presents <- list.files(cache_dir, "^parcelles-pm-[0-9-]+\\.parquet$",
                         full.names = TRUE)
  res <- .dgfip_resoudre_url()
  if (is.null(res)) {
    if (length(presents)) return(sort(presents, decreasing = TRUE)[1L])
    cli::cli_warn("DGFiP legal-entity parcels: data.gouv.fr unreachable and no cached copy.")
    return(NULL)
  }
  cible <- file.path(cache_dir, paste0("parcelles-pm-", res$stamp, ".parquet"))
  if (!file.exists(cible)) {
    cli::cli_inform("Downloading the national DGFiP legal-entity parcel file (~380 MB), once.")
    tmp <- paste0(cible, ".part")
    ancien <- options(timeout = 3600L)
    on.exit(options(ancien), add = TRUE)
    ok <- tryCatch(
      identical(suppressWarnings(utils::download.file(res$url, tmp, mode = "wb",
                                                      quiet = TRUE)), 0L),
      error = function(e) FALSE)
    if (!ok || !file.exists(tmp)) {
      unlink(tmp)
      if (length(presents)) return(sort(presents, decreasing = TRUE)[1L])
      cli::cli_warn("DGFiP legal-entity parcels: download failed.")
      return(NULL)
    }
    file.rename(tmp, cible)
    perimes <- setdiff(presents, cible)
    stamps <- sub("^parcelles-pm-([0-9-]+)\\.parquet$", "\\1", basename(perimes))
    unlink(c(perimes, list.files(cache_dir, paste0("^dep-.*-(",
                                                   paste(stamps, collapse = "|"),
                                                   ")\\.parquet$"),
                                 full.names = TRUE)[length(stamps) > 0L]))
  }
  cible
}

# Lit les lignes d'un département (ou toutes) d'un parquet DGFiP.
.dgfip_lire <- function(fichier, departement = NULL) {
  ds <- arrow::open_dataset(fichier)
  filtre <- if (is.null(departement)) NULL else
    arrow::Expression$field_ref("departement") == departement
  sc <- if (is.null(filtre)) arrow::Scanner$create(ds) else
    arrow::Scanner$create(ds, filter = filtre)
  as.data.frame(sc$ToTable())
}

#' Parcels owned by legal entities (DGFiP), for one or more communes
#'
#' @description
#' Read, for the communes `insee`, the DGFiP file of **parcels owned by legal
#' entities** (*Fichiers des locaux et des parcelles des personnes morales*,
#' data.gouv.fr, Licence Ouverte) and return one row per cadastral parcel with
#' its owner and whether that owner is a **public person** (State, region,
#' département, commune, public establishment: DGFiP groups 1, 2, 3, 4 and 9).
#'
#' A parcel **absent** from the file belongs to a natural person, hence is
#' private.
#'
#' The national file (~380 MB, Parquet) is downloaded **once** into
#' `cache_dir`; its URL is resolved through the data.gouv.fr API, so a new
#' release is fetched alongside and the old one removed. Each département read
#' is then kept as a small extract next to it.
#'
#' @param insee One or more commune INSEE codes (5 characters). Communes may
#'   lie in several départements (one extract is read per département).
#' @param fichier Optional path to a DGFiP parcel Parquet file (national file or
#'   extract) to read instead of the cache. Nothing is downloaded.
#' @param cache_dir Cache directory. Default
#'   `tools::R_user_dir("nemeton", "cache")/dgfip_personnes_morales`.
#' @return A `data.frame` with columns `idu` (14-character cadastral
#'   identifier), `code_insee`, `publique` (logical), `groupe` (owner group
#'   label), `proprietaire` (owner names, `" | "`-separated), `natures`
#'   (distinct land-use labels of its fiscal subdivisions, `", "`-separated) and
#'   `contenance_m2`. A 0-row `data.frame` when the communes hold no
#'   legal-entity parcel; `NULL` on failure (missing `arrow`, no network and no
#'   cache), with a warning.
#' @section Lifecycle:
#' Experimental (spec 058): may change in any release.
#' @seealso [construire_ugf_onf()]
#' @export
load_parcelles_personnes_morales <- function(insee, fichier = NULL,
                                             cache_dir = NULL) {
  insee <- unique(as.character(insee))
  if (!length(insee) || anyNA(insee) ||
      !all(grepl("^[0-9][0-9AB][0-9]{3}$", insee))) {
    cli::cli_abort("{.arg insee} must hold 5-character INSEE commune codes.")
  }
  if (!requireNamespace("arrow", quietly = TRUE)) {
    cli::cli_warn("load_parcelles_personnes_morales() needs the {.pkg arrow} package; returning NULL.")
    return(NULL)
  }
  deps <- unique(.dgfip_departement(insee))

  if (!is.null(fichier)) {
    if (!file.exists(fichier)) cli::cli_abort("File {.file {fichier}} not found.")
    lire_dep <- function(dep) .dgfip_lire(fichier, dep)
  } else {
    if (is.null(cache_dir)) {
      cache_dir <- file.path(tools::R_user_dir("nemeton", "cache"),
                             "dgfip_personnes_morales")
    }
    national <- .dgfip_fichier_national(cache_dir)
    if (is.null(national)) return(NULL)
    stamp <- sub("^parcelles-pm-([0-9-]+)\\.parquet$", "\\1", basename(national))
    lire_dep <- function(dep) {
      extrait <- file.path(cache_dir, paste0("dep-", dep, "-", stamp, ".parquet"))
      if (file.exists(extrait)) return(.dgfip_lire(extrait))
      brut <- .dgfip_lire(national, dep)
      tryCatch(arrow::write_parquet(brut, extrait), error = function(e) NULL)
      brut
    }
  }
  # Un projet peut s'étendre sur plusieurs communes, voire plusieurs
  # départements : un extrait par département, filtré ensuite par commune.
  brut <- do.call(rbind, lapply(deps, lire_dep))
  .dgfip_par_parcelle(brut, insee)
}

# Une ligne par subdivision fiscale et par droit -> une ligne par parcelle.
.dgfip_par_parcelle <- function(brut, insee) {
  vide <- data.frame(idu = character(0), code_insee = character(0),
                     publique = logical(0), groupe = character(0),
                     proprietaire = character(0), natures = character(0),
                     contenance_m2 = numeric(0))
  if (is.null(brut) || !nrow(brut)) return(vide)
  ci <- if ("code_insee" %in% names(brut)) brut$code_insee else
    paste0(brut$departement, brut$code_commune)
  garde <- !is.na(ci) & ci %in% insee
  brut <- brut[garde, , drop = FALSE]
  ci <- ci[garde]
  if (!nrow(brut)) return(vide)
  brut$code_insee <- ci
  brut$idu <- .dgfip_idu(ci, brut$prefixe, brut$section, brut$numero_parcelle)
  groupes <- split(seq_len(nrow(brut)), brut$idu)
  colle <- function(v, sep) {
    v <- unique(v[!is.na(v) & nzchar(v)])
    if (length(v)) paste(v, collapse = sep) else NA_character_
  }
  out <- do.call(rbind, lapply(names(groupes), function(id) {
    i <- groupes[[id]]
    codes <- as.character(brut$groupe_personne_code[i])
    pub <- codes %in% .DGFIP_GROUPES_PUBLICS
    data.frame(
      idu = id, code_insee = brut$code_insee[i[1L]], publique = any(pub),
      groupe = colle(brut$groupe_personne_libelle[i][order(!pub)], ", "),
      proprietaire = colle(brut$denomination[i], " | "),
      natures = colle(brut$nature_culture_libelle[i], ", "),
      contenance_m2 = suppressWarnings(max(brut$contenance_parcelle_centiare[i],
                                           na.rm = TRUE)),
      stringsAsFactors = FALSE)
  }))
  out$contenance_m2[!is.finite(out$contenance_m2)] <- NA_real_
  row.names(out) <- NULL
  out
}

# Codes INSEE de commune : uniques, au format à 5 caractères.
.ugf_valider_insee <- function(insee) {
  insee <- unique(as.character(insee))
  if (!length(insee) || anyNA(insee) ||
      !all(grepl("^[0-9][0-9AB][0-9]{3}$", insee))) {
    cli::cli_abort("{.arg insee} must hold 5-character INSEE commune codes.")
  }
  insee
}

# ---------------------------------------------------------------------------
# 3.1 Parcelles cadastrales candidates (PCI IGN)
# ---------------------------------------------------------------------------

.ugf_cadastre_candidats <- function(onf_union, insee) {
  if (!requireNamespace("happign", quietly = TRUE)) {
    cli::cli_warn("construire_ugf_onf() needs the {.pkg happign} package to fetch the cadastre.")
    return(NULL)
  }
  pci <- tryCatch(
    happign::get_wfs(onf_union, "CADASTRALPARCELS.PARCELLAIRE_EXPRESS:parcelle",
                     predicate = happign::intersects(), verbose = FALSE),
    error = function(e) {
      cli::cli_warn(c("Cadastral WFS fetch failed.", i = conditionMessage(e)))
      NULL
    })
  if (is.null(pci) || !inherits(pci, "sf")) return(NULL)
  if (!all(c("idu", "code_insee") %in% names(pci))) {
    cli::cli_warn("Cadastral WFS returned an unexpected schema.")
    return(NULL)
  }
  pci[pci$code_insee %in% insee, c("idu", "code_insee"), drop = FALSE]
}

# ---------------------------------------------------------------------------
# 3.4 Découpage d'une parcelle par accrochage
# ---------------------------------------------------------------------------

.ugf_decouper_parcelle <- function(ci, idu, onf, O, tol, larg_hors, ha_hors,
                                   min_part_m2) {
  crs <- sf::st_crs(ci)
  # 1. Morceaux bruts : un par parcelle ONF, plus la partie non couverte.
  touche <- which(lengths(sf::st_intersects(sf::st_geometry(onf), ci)) > 0L)
  m <- if (length(touche)) {
    inter <- suppressWarnings(sf::st_intersection(sf::st_geometry(onf)[touche], ci))
    sf::st_sf(ugf = onf$ugf_id[touche][attr(inter, "idx")[, 1]], geometry = inter)
  } else sf::st_sf(ugf = character(0), geometry = sf::st_sfc(crs = crs))
  hors <- suppressWarnings(sf::st_difference(ci, O))
  if (length(hors) && !all(sf::st_is_empty(hors))) {
    m <- rbind(m, sf::st_sf(ugf = paste0("cad~", idu), geometry = hors))
  }
  m <- .ugf_polygones(.ugf_prec(m))
  m <- m[as.numeric(sf::st_area(m)) > 0.01, , drop = FALSE]
  if (!nrow(m)) {
    return(sf::st_sf(ugf = paste0("cad~", idu), geometry = ci))
  }

  # 2. Cœur de chaque morceau : ouverture de rayon tol/2 (larg_hors/2 hors ONF).
  hors_onf <- startsWith(m$ugf, "cad~")
  r <- ifelse(hors_onf, larg_hors / 2, tol / 2)
  g <- sf::st_buffer(sf::st_buffer(sf::st_geometry(m), -r), r)
  coeurs <- .ugf_polygones(.ugf_prec(sf::st_sf(ugf = m$ugf, geometry = g)))
  if (nrow(coeurs)) {
    inter <- suppressWarnings(sf::st_intersection(sf::st_geometry(coeurs), ci))
    coeurs <- sf::st_sf(ugf = coeurs$ugf[attr(inter, "idx")[, 1]], geometry = inter)
    coeurs <- .ugf_polygones(.ugf_prec(coeurs))
  }
  if (nrow(coeurs)) {
    a <- as.numeric(sf::st_area(coeurs))
    coeurs <- coeurs[a > 0.01 & !(startsWith(coeurs$ugf, "cad~") &
                                    a < ha_hors * 1e4), , drop = FALSE]
  }
  if (!nrow(coeurs)) {
    # Parcelle entièrement étroite : au morceau brut le plus grand.
    return(sf::st_sf(ugf = m$ugf[which.max(as.numeric(sf::st_area(m)))],
                     geometry = ci))
  }
  coeurs <- .ugf_fondre(coeurs, "ugf")

  # 3. Bandes : chacune au cœur de plus longue limite commune.
  bandes <- suppressWarnings(sf::st_difference(ci, sf::st_union(sf::st_geometry(coeurs))))
  bandes <- .ugf_polygones(.ugf_prec(sf::st_sf(geometry = bandes)))
  bandes <- bandes[as.numeric(sf::st_area(bandes)) > 0, , drop = FALSE]
  if (nrow(bandes)) {
    lg <- .ugf_longueurs(sf::st_geometry(bandes), sf::st_geometry(coeurs))
    bandes$ugf <- NA_character_
    if (nrow(lg)) {
      lg <- lg[order(lg$i, -lg$l), , drop = FALSE]
      lg <- lg[!duplicated(lg$i), , drop = FALSE]
      bandes$ugf[lg$i] <- coeurs$ugf[lg$j]
    }
    isolees <- which(is.na(bandes$ugf))
    if (length(isolees)) {
      # Repli : le morceau brut qui recouvre le plus la bande.
      inter <- suppressWarnings(sf::st_intersection(
        sf::st_geometry(bandes)[isolees], sf::st_geometry(m)))
      idx <- attr(inter, "idx")
      plus_gros <- m$ugf[which.max(as.numeric(sf::st_area(m)))]
      bandes$ugf[isolees] <- plus_gros
      if (length(inter)) {
        rec <- data.frame(i = idx[, 1], j = idx[, 2],
                          a = as.numeric(sf::st_area(inter)))
        rec <- rec[rec$a > 0, , drop = FALSE]
        rec <- rec[order(rec$i, -rec$a), , drop = FALSE]
        rec <- rec[!duplicated(rec$i), , drop = FALSE]
        bandes$ugf[isolees[rec$i]] <- m$ugf[rec$j]
      }
    }
    pieces <- rbind(coeurs[, "ugf"],
                    suppressWarnings(sf::st_cast(bandes[, "ugf"], "MULTIPOLYGON")))
  } else {
    pieces <- coeurs
  }

  # 4. Parties détachées < min_part_m2 : au voisin de plus longue limite.
  parts <- .ugf_polygones(.ugf_prec(.ugf_fondre(pieces, "ugf")))
  for (passe in 1:3) {
    a <- as.numeric(sf::st_area(parts))
    petits <- which(a < min_part_m2)
    if (!length(petits) || nrow(parts) < 2L) break
    lg <- .ugf_longueurs(sf::st_geometry(parts))
    lg <- lg[lg$i %in% petits, , drop = FALSE]
    if (!nrow(lg)) break
    lg <- lg[order(lg$i, -lg$l), , drop = FALSE]
    lg <- lg[!duplicated(lg$i), , drop = FALSE]
    change <- parts$ugf[lg$i] != parts$ugf[lg$j]
    if (!any(change)) break
    parts$ugf[lg$i] <- parts$ugf[lg$j]
    parts <- .ugf_polygones(.ugf_prec(.ugf_fondre(parts, "ugf")))
  }
  out <- .ugf_fondre(parts, "ugf")
  sf::st_geometry(out) <- .ugf_prec(sf::st_geometry(out))
  out
}

# ---------------------------------------------------------------------------
# 3.5 Rattachements finaux
# ---------------------------------------------------------------------------

.ugf_regrouper <- function(ten) {
  out <- .ugf_fondre(ten, c("idu", "ugf"))
  sf::st_agr(out) <- "constant"
  out
}

# Voisins : au moins `min_l` mètres de limite commune (un contact ponctuel
# n'est pas un voisinage).
.ugf_voisins <- function(ten, min_l = 1) {
  lg <- .ugf_longueurs(sf::st_geometry(ten))
  lg[lg$l >= min_l, , drop = FALSE]
}

.ugf_rattacher <- function(ten, seuil, seuil_hors, passes = 5L) {
  for (passe in seq_len(passes)) {
    h <- as.numeric(sf::st_area(ten)) / 1e4
    vois <- .ugf_voisins(ten)
    n <- 0L
    # Morceau hors ONF < seuil_hors : au voisin d'une autre UGF de plus longue
    # limite.
    for (k in which(startsWith(ten$ugf, "cad~") & h < seuil_hors)) {
      v <- vois[vois$i == k & ten$ugf[vois$j] != ten$ugf[k], , drop = FALSE]
      if (!nrow(v)) next
      ten$ugf[k] <- ten$ugf[v$j[which.max(v$l)]]
      n <- n + 1L
    }
    # Morceau ONF < seuil entouré d'une seule autre UGF, sans contact avec la
    # sienne : il passe dans cette UGF.
    for (k in which(!startsWith(ten$ugf, "cad~") & h < seuil)) {
      uv <- unique(ten$ugf[vois$j[vois$i == k]])
      autres <- setdiff(uv, ten$ugf[k])
      if (length(autres) == 1L && !(ten$ugf[k] %in% uv)) {
        ten$ugf[k] <- autres
        n <- n + 1L
      }
    }
    if (!n) break
    ten <- .ugf_regrouper(ten)
  }

  # UGF entière < seuil : chacun de ses morceaux au voisin, d'une autre UGF, de
  # plus longue limite.
  tot <- tapply(as.numeric(sf::st_area(ten)) / 1e4, ten$ugf, sum)
  petites <- names(tot)[tot < seuil]
  for (u in petites) {
    vois <- .ugf_voisins(ten)
    for (k in which(ten$ugf == u)) {
      v <- vois[vois$i == k & ten$ugf[vois$j] != u, , drop = FALSE]
      if (!nrow(v)) next
      ten$ugf[k] <- ten$ugf[v$j[which.max(v$l)]]
    }
  }
  if (length(petites)) ten <- .ugf_regrouper(ten)
  ten
}

# Re-pavage exact de chaque parcelle sur sa géométrie D'ORIGINE.
#
# Le découpage travaille au centimètre (`.ugf_prec`) : sans grille commune, les
# morceaux voisins ne partagent pas leurs sommets. Mais l'arrondi déplace chaque
# sommet cadastral de quelques millimètres, et laissait jusqu'à 15 m² de
# chevauchement interne sur A 36 à Couchey. Le cadastre ne doit pas bouger, même d'un
# millimètre : chaque tènement est redécoupé dans la parcelle exacte, sans
# grille de précision, du plus grand au plus petit ; ce qui reste (interstices
# de l'arrondi) rejoint le tènement de plus longue limite commune.
.ugf_repaver <- function(ten, cad) {
  geo_cad <- stats::setNames(sf::st_geometry(cad), cad$idu)
  morceaux <- lapply(split(seq_len(nrow(ten)), ten$idu), function(lignes) {
    idu <- ten$idu[lignes[1L]]
    ci <- sf::st_set_precision(geo_cad[idu], 0)
    lignes <- lignes[order(-as.numeric(sf::st_area(ten[lignes, ])))]
    if (length(lignes) == 1L) {
      return(sf::st_sf(idu = idu, ugf = ten$ugf[lignes],
                       geometry = sf::st_cast(ci, "MULTIPOLYGON")))
    }
    g <- sf::st_set_precision(sf::st_geometry(ten)[lignes], 0)
    pris <- NULL
    out <- vector("list", length(lignes))
    for (n in seq_along(lignes)) {
      x <- suppressWarnings(sf::st_intersection(g[n], ci))
      if (!is.null(pris) && length(x)) x <- suppressWarnings(sf::st_difference(x, pris))
      x <- if (length(x)) .ugf_polygones(sf::st_sf(geometry = x)) else
        sf::st_sf(geometry = sf::st_sfc(crs = sf::st_crs(ci)))
      out[[n]] <- if (nrow(x)) sf::st_sf(ugf = ten$ugf[lignes[n]],
                                          geometry = sf::st_geometry(x)) else NULL
      if (nrow(x)) {
        u <- sf::st_union(sf::st_geometry(x))
        pris <- if (is.null(pris)) u else sf::st_union(pris, u)
      }
    }
    parts <- .ugf_polygones(do.call(rbind, out))
    reste <- suppressWarnings(sf::st_difference(ci, pris))
    reste <- if (length(reste)) .ugf_polygones(sf::st_sf(geometry = reste)) else NULL
    # Les éclats d'arrondi (< 1 m²) restés détachés dans un tènement sont
    # traités comme le reste : sinon ils survivent en parties isolées des
    # multipolygones (59 à Couchey).
    eclat <- as.numeric(sf::st_area(parts)) < 1
    if (any(eclat) && !all(eclat)) {
      e <- parts[eclat, "geometry"]
      reste <- if (is.null(reste) || !nrow(reste)) e else rbind(reste, e)
      parts <- parts[!eclat, , drop = FALSE]
    }
    if (!is.null(reste) && nrow(reste)) {
      lg <- .ugf_longueurs(sf::st_geometry(reste), sf::st_geometry(parts), tol = 1e-4)
      reste$ugf <- parts$ugf[which.max(as.numeric(sf::st_area(parts)))]
      if (nrow(lg)) {
        lg <- lg[order(lg$i, -lg$l), , drop = FALSE]
        lg <- lg[!duplicated(lg$i), , drop = FALSE]
        reste$ugf[lg$i] <- parts$ugf[lg$j]
      }
      parts <- rbind(parts, reste[, c("ugf", attr(reste, "sf_column"))])
    }
    parts$idu <- idu
    .ugf_absorber_eclats(.ugf_fondre(parts, c("idu", "ugf"))[, c("idu", "ugf")])
  })
  out <- do.call(rbind, morceaux)
  row.names(out) <- NULL
  sf::st_agr(out) <- "constant"
  out
}

# Éclats d'arrondi (< `seuil_m2`) restés en parties isolées d'un tènement.
#
# Le redécoupage dans la parcelle exacte laisse des triangles de quelques
# millimètres de large le long des limites internes : à Couchey, 53 parties
# sous 1 m² (0,33 m² au plus). Leur limite commune avec le voisin n'est alignée
# qu'à 0,1 mm près, si bien que l'union seule les laisse séparés. On accroche
# donc le VOISIN sur l'éclat (`st_snap`, 1 mm : il gagne les sommets de
# l'éclat, rien ne bouge de plus d'un millimètre), puis on les unit.
.ugf_absorber_eclats <- function(ten, seuil_m2 = 1, tol = 1e-3) {
  if (nrow(ten) < 2L) return(ten)
  parts <- .ugf_polygones(ten)
  a <- as.numeric(sf::st_area(parts))
  eclats <- which(a < seuil_m2)
  if (!length(eclats) || length(eclats) == nrow(parts)) return(ten)
  geo <- sf::st_geometry(parts)
  lg <- .ugf_longueurs(geo[eclats], geo[-eclats], tol = tol)
  if (!nrow(lg)) return(ten)
  lg <- lg[order(lg$i, -lg$l), , drop = FALSE]
  lg <- lg[!duplicated(lg$i), , drop = FALSE]
  gros <- seq_len(nrow(parts))[-eclats]
  garde <- rep(TRUE, nrow(parts))
  for (r in seq_len(nrow(lg))) {
    e <- eclats[lg$i[r]]
    cible <- gros[lg$j[r]]
    g <- sf::st_snap(geo[cible], geo[e], tolerance = tol)
    geo[cible] <- suppressWarnings(sf::st_cast(sf::st_union(g, geo[e]), "MULTIPOLYGON"))
    garde[e] <- FALSE
  }
  parts <- parts[garde, , drop = FALSE]
  sf::st_geometry(parts) <- suppressWarnings(sf::st_cast(geo[garde], "MULTIPOLYGON"))
  .ugf_fondre(parts, c("idu", "ugf"))[, c("idu", "ugf")]
}

# ---------------------------------------------------------------------------
# Fonction exportée
# ---------------------------------------------------------------------------

#' Build the management units (UGF) of a public forest from the cadastre
#'
#' @description
#' Build the UGF of a public forest **from the cadastral parcels**, each UGF
#' carrying the number of its ONF forest parcel. Rule (Pascal, 2026-10-08):
#' forest parcels are only a partition of cadastral parcels; UGF are always
#' obtained by grouping and cutting **cadastral** parcels, the cadastre is
#' never warped, and it is the ONF layer, which overflows, that is adjusted.
#'
#' By default this function starts from the forest and **finds** the cadastral
#' parcels that belong to it (spec 058):
#' 1. **Candidates**: cadastral parcels (PCI, IGN) touching the union of the
#'    ONF parcels, restricted to the commune `insee`.
#' 2. **Calage**: the ONF layer is rubber-sheeted onto the candidates'
#'    boundaries ([caler_onf_sur_cadastre()]).
#' 3. **Selection**: a candidate belongs to the forest when its owner is a
#'    **public person** according to the DGFiP legal-entity file
#'    ([load_parcelles_personnes_morales()]) **and** the warped ONF covers at
#'    least `seuil_couverture` of it. Neither condition is enough alone: at
#'    Couchey (21), three communal parcels of 22 to 57 ha are covered at 2–3 %
#'    (moorland outside the *régime forestier*), and a 0.04 ha private parcel
#'    is covered at 56 % by an ONF overflow.
#' 4. **Cutting by snapping**: within each selected parcel, the pieces cut by
#'    the ONF parcels are reduced to their core by a morphological opening of
#'    radius `tol / 2` (`larg_hors / 2` for the uncovered remainder, whose
#'    cores under `ha_hors` are dropped). The strips left over join the core
#'    they share the longest boundary with; detached parts under `min_part_m2`
#'    join their longest-boundary neighbour. An ONF limit closer than `tol` to a
#'    cadastral limit thus **snaps** onto it: a parcel is cut only where the
#'    ONF limit really departs from it.
#' 5. **Final attachments**, over all tenements (neighbours share at least
#'    1 m of boundary, measured within 10 cm): an ONF piece under `seuil` ha
#'    whose neighbours all belong to one other UGF, and which does not touch its
#'    own, moves to that UGF (up to 5 passes); an uncovered piece (`cad~`)
#'    under `seuil_hors` ha joins its longest-boundary neighbour; a whole UGF
#'    under `seuil` ha is shared out among its longest-boundary neighbours.
#'
#' The cutting works on a centimetre grid; each parcel is finally re-tiled on
#' its **original** geometry, so the cadastre does not move even by a
#' millimetre.
#'
#' Measured at Couchey (21200): 63 candidates, 19 parcels kept (493.79 ha), 63
#' UGF, none uncovered, 85 tenements, smallest UGF 2.11 ha, in about 15 s once
#' the sources are loaded.
#'
#' @section Approximation of the régime forestier:
#' Neither the PCI nor the Etalab cadastre records whether a parcel is under
#' the *régime forestier*. The authoritative source is the prefectoral order of
#' application, which is not published parcel by parcel. The "public owner ×
#' ONF coverage" test is an **approximation** of it, to be checked against the
#' management plan.
#'
#' @param aoi An `sf`/`sfc` extent used to fetch the ONF parcels when
#'   `parcelles_onf` is `NULL`.
#' @param insee INSEE code(s) of the communes whose cadastral parcels are
#'   fetched and whose DGFiP owners are read. Several communes, even in several
#'   départements, are processed **together**: calage, cutting and attachments
#'   run once over all of them, so limits between communes are handled on both
#'   sides. Optional when `cadastre` is given: then deduced from its
#'   `code_insee` column, or from the first five characters of `idu`.
#' @param parcelles_onf Optional `sf` of ONF parcels, as returned by
#'   [load_onf_parcelles_source()]; fetched over `aoi` when `NULL`.
#' @param cadastre Optional `sf` of candidate cadastral parcels with an `idu`
#'   column; fetched from the IGN WFS (PCI,
#'   `CADASTRALPARCELS.PARCELLAIRE_EXPRESS:parcelle`) for `insee` when `NULL`.
#'   A given `cadastre` is taken as is, whatever its communes (since 1.2.0;
#'   1.1.x kept only the rows of `insee`).
#' @param proprietaires Optional `data.frame` as returned by
#'   [load_parcelles_personnes_morales()]; read for `insee` when `NULL`.
#' @param pas,dmax,rayon,k Calage parameters, see [caler_onf_sur_cadastre()].
#'   Defaults `5`, `80`, `200`, `12`.
#' @param seuil_couverture Minimum share of a cadastral parcel covered by the
#'   warped ONF for it to belong to the forest. Default `0.5`.
#' @param tol Snapping tolerance, in metres. Default `15`.
#' @param larg_hors Minimum width of an uncovered block kept as its own unit,
#'   in metres. Default `50`.
#' @param ha_hors Minimum area of an uncovered core, in hectares. Default `0.5`.
#' @param seuil Minimum area of an ONF piece and of a UGF, in hectares. Default
#'   `0.5`.
#' @param seuil_hors Minimum area of an uncovered piece, in hectares. Default
#'   `1`.
#' @param min_part_m2 Minimum area of a detached part within a parcel, in
#'   square metres. Default `500`.
#' @param crs CRS of the result. Default `2154`.
#' @param selection `"foret"` (default) selects the cadastral parcels of the
#'   forest as described above. `"toutes"` keeps **every** parcel of
#'   `cadastre` that touches the ONF layer — the caller's own selection — and
#'   applies the same calage, cutting and
#'   attachments; DGFiP owners are then not read unless `proprietaires` is
#'   given. A kept parcel that is not under the *régime forestier* becomes its
#'   own `cad~<idu>` unit when its uncovered part is at least `larg_hors` wide
#'   and `seuil_hors` ha, and is attached to its neighbours otherwise; a
#'   parcel that does not touch the ONF layer at all is kept the same way.
#'   Measured on the 23 parcels of the Couchey project: 67 UGF, of which four
#'   `cad~` (A 283, A 9, A 286, AO 212: communal, outside the *régime
#'   forestier*).
#' @return An `sf` of tenements (one row per cadastral parcel × UGF) with
#'   columns `idu`, `tenement_id` (`<ugf_id>~<idu>`), `ugf_id`
#'   (`<forêt>-<parcelle>`, or `cad~<idu>` for an uncovered block), `nom_ugf`,
#'   `foret_id`, `foret_nom`, `parcelle`, `domaniale`, `surface_m2` and
#'   `part_onf` (share of the tenement covered by its warped ONF parcel, a
#'   confidence measure; `NA` for `cad~`). The tenements of a parcel tile it
#'   exactly, on its original vertices.
#'
#'   Attributes: `parcelles`, a `data.frame` of every candidate with `idu`,
#'   `retenue`, `raison` (`NA` when kept, `"hors ONF"` for a parcel of
#'   `cadastre` that does not touch the ONF layer, `"privee"` or
#'   `"couverture < 50 %"`),
#'   `publique`, `proprietaire`, `groupe`, `natures`, `couverture_onf` and
#'   `surface_ha`; `calage`, as in [caler_onf_sur_cadastre()]. `NULL` with a
#'   warning when a source cannot be fetched.
#' @section Lifecycle:
#' Experimental (spec 058): may change in any release.
#' @seealso [caler_onf_sur_cadastre()],
#'   [load_parcelles_personnes_morales()], [load_onf_parcelles_source()]
#' @export
construire_ugf_onf <- function(aoi = NULL, insee = NULL, parcelles_onf = NULL,
                               cadastre = NULL, proprietaires = NULL,
                               pas = 5, dmax = 80, rayon = 200, k = 12,
                               seuil_couverture = 0.5, tol = 15,
                               larg_hors = 50, ha_hors = 0.5, seuil = 0.5,
                               seuil_hors = 1, min_part_m2 = 500,
                               crs = 2154,
                               selection = c("foret", "toutes")) {
  selection <- match.arg(selection)
  if (is.null(insee) && is.null(cadastre)) {
    cli::cli_abort("{.arg insee} (INSEE code(s) of the communes) is required when {.arg cadastre} is not given.")
  }
  if (!is.null(insee)) insee <- .ugf_valider_insee(insee)
  if (!is.numeric(seuil_couverture) || seuil_couverture <= 0 ||
      seuil_couverture > 1) {
    cli::cli_abort("{.arg seuil_couverture} must be a share in (0, 1].")
  }

  # Sources ----------------------------------------------------------------
  if (is.null(parcelles_onf)) {
    if (is.null(aoi)) cli::cli_abort("Give {.arg aoi} or {.arg parcelles_onf}.")
    parcelles_onf <- load_onf_parcelles_source(aoi)
    if (is.null(parcelles_onf)) {
      cli::cli_warn("ONF parcels could not be fetched; returning NULL.")
      return(NULL)
    }
  }
  if (!inherits(parcelles_onf, "sf") ||
      !all(c("id", "foret_id", "parcelle") %in% names(parcelles_onf))) {
    cli::cli_abort("{.arg parcelles_onf} does not look like a {.fn load_onf_parcelles_source} result.")
  }
  crs_travail <- .ugf_crs_travail(sf::st_crs(parcelles_onf))
  onf <- sf::st_make_valid(sf::st_transform(parcelles_onf, crs_travail))
  if (!nrow(onf)) {
    cli::cli_warn("No ONF parcel; returning NULL.")
    return(NULL)
  }

  if (is.null(cadastre)) {
    onf_u <- sf::st_union(sf::st_geometry(onf))
    cadastre <- .ugf_cadastre_candidats(onf_u, insee)
    if (is.null(cadastre)) {
      cli::cli_warn("Cadastral parcels could not be fetched; returning NULL.")
      return(NULL)
    }
  }
  if (!inherits(cadastre, "sf") || !"idu" %in% names(cadastre)) {
    cli::cli_abort("{.arg cadastre} must be an sf with an {.field idu} column.")
  }
  # Un cadastre fourni est pris tel quel, toutes communes confondues : c'est la
  # sélection de l'appelant (un projet peut chevaucher deux communes). Les
  # communes, si on ne les donne pas, s'en déduisent.
  if (is.null(insee)) {
    insee <- if ("code_insee" %in% names(cadastre)) cadastre$code_insee else
      substr(as.character(cadastre$idu), 1L, 5L)
    insee <- .ugf_valider_insee(insee[!is.na(insee)])
  }
  cad <- sf::st_make_valid(sf::st_transform(cadastre, crs_travail))
  cad <- .ugf_fondre(sf::st_sf(idu = as.character(cad$idu),
                               geometry = sf::st_geometry(cad)), "idu")
  # En mode « foret », une parcelle qui ne touche pas l'ONF n'entre ni dans le
  # calage ni dans la sélection, mais elle est rendue dans l'attribut
  # `parcelles` (raison « hors ONF ») : l'app la liste parmi les écartées. En
  # mode « toutes », elle reste et devient sa propre unité `cad~<idu>`.
  hors_onf <- NULL
  if (selection == "foret") {
    touche <- lengths(sf::st_intersects(cad, sf::st_union(sf::st_geometry(onf)))) > 0L
    if (any(!touche)) {
      hors_onf <- data.frame(
        idu = cad$idu[!touche], retenue = FALSE, raison = "hors ONF",
        publique = NA, proprietaire = NA_character_, groupe = NA_character_,
        natures = NA_character_, couverture_onf = 0,
        surface_ha = as.numeric(sf::st_area(cad[!touche, ])) / 1e4,
        stringsAsFactors = FALSE)
    }
    cad <- cad[touche, , drop = FALSE]
  }
  if (!nrow(cad)) {
    cli::cli_warn("No cadastral parcel of {.val {insee}} touches the ONF parcels; returning NULL.")
    return(NULL)
  }

  # « toutes » : la sélection est celle de l'appelant, on ne la refait pas.
  if (is.null(proprietaires) && selection == "toutes") {
    proprietaires <- data.frame(idu = character(0), publique = logical(0))
  }
  if (is.null(proprietaires)) {
    proprietaires <- load_parcelles_personnes_morales(insee)
    if (is.null(proprietaires)) {
      cli::cli_warn("DGFiP owners could not be read; returning NULL.")
      return(NULL)
    }
  }
  if (!all(c("idu", "publique") %in% names(proprietaires))) {
    cli::cli_abort("{.arg proprietaires} must have {.field idu} and {.field publique} columns.")
  }

  # 3.2 Calage ---------------------------------------------------------------
  onf_c <- caler_onf_sur_cadastre(onf, cad, pas = pas, dmax = dmax,
                                  rayon = rayon, k = k)
  calage <- attr(onf_c, "calage")
  onf_c$ugf_id <- onf_c$id
  O <- sf::st_union(sf::st_geometry(onf_c))

  # 3.3 Sélection ------------------------------------------------------------
  aire <- as.numeric(sf::st_area(cad))
  couv <- numeric(nrow(cad))
  inter <- suppressWarnings(sf::st_intersection(sf::st_geometry(cad), O))
  if (length(inter)) {
    idx <- attr(inter, "idx")[, 1]
    couv[idx] <- as.numeric(sf::st_area(inter)) / aire[idx]
  }
  m <- match(cad$idu, proprietaires$idu)
  publique <- !is.na(m) & proprietaires$publique[m] %in% TRUE
  retenue <- if (selection == "toutes") rep(TRUE, nrow(cad)) else
    publique & couv >= seuil_couverture
  raison <- ifelse(retenue, NA_character_,
                   ifelse(!publique, "privee",
                          sprintf("couverture < %g %%", 100 * seuil_couverture)))
  champ <- function(col) {
    if (col %in% names(proprietaires)) as.character(proprietaires[[col]][m])
    else rep(NA_character_, nrow(cad))
  }
  if (selection == "toutes" && !nrow(proprietaires)) publique <- rep(NA, nrow(cad))
  parcelles <- data.frame(
    idu = cad$idu, retenue = retenue, raison = raison, publique = publique,
    proprietaire = champ("proprietaire"), groupe = champ("groupe"),
    natures = champ("natures"), couverture_onf = round(couv, 4),
    surface_ha = aire / 1e4, stringsAsFactors = FALSE)
  if (!is.null(hors_onf)) {
    # Propriétaire DGFiP connu pour les parcelles hors ONF aussi.
    mh <- match(hors_onf$idu, proprietaires$idu)
    hors_onf$publique <- !is.na(mh) & proprietaires$publique[mh] %in% TRUE
    for (col in c("proprietaire", "groupe", "natures")) {
      if (col %in% names(proprietaires)) hors_onf[[col]] <- as.character(proprietaires[[col]][mh])
    }
    parcelles <- rbind(parcelles, hors_onf)
  }
  parcelles <- parcelles[order(!parcelles$retenue, -parcelles$couverture_onf), ,
                         drop = FALSE]
  row.names(parcelles) <- NULL

  if (!any(retenue)) {
    cli::cli_warn("No cadastral parcel of {.val {insee}} qualifies as public forest.")
    out <- .ugf_sortie_vide(sf::st_crs(crs))
    attr(out, "parcelles") <- parcelles
    attr(out, "calage") <- calage
    return(out)
  }

  # 3.4 Découpage ------------------------------------------------------------
  cad_r <- .ugf_prec(cad[retenue, , drop = FALSE])
  onf_r <- onf_c[lengths(sf::st_intersects(onf_c, sf::st_union(
    sf::st_geometry(cad_r)))) > 0L, , drop = FALSE]
  onf_r <- .ugf_prec(onf_r)
  ten <- do.call(rbind, lapply(seq_len(nrow(cad_r)), function(i) {
    t <- .ugf_decouper_parcelle(sf::st_geometry(cad_r)[i], cad_r$idu[i], onf_r,
                                O, tol, larg_hors, ha_hors, min_part_m2)
    sf::st_sf(idu = cad_r$idu[i], ugf = t$ugf,
              geometry = suppressWarnings(sf::st_cast(sf::st_geometry(t),
                                                      "MULTIPOLYGON")))
  }))
  sf::st_agr(ten) <- "constant"

  # 3.5 Rattachements --------------------------------------------------------
  ten <- .ugf_rattacher(ten, seuil = seuil, seuil_hors = seuil_hors)
  ten <- .ugf_repaver(ten, cad[retenue, , drop = FALSE])

  # Mise en forme ------------------------------------------------------------
  hors <- startsWith(ten$ugf, "cad~")
  j <- match(ten$ugf, onf_c$ugf_id)
  attr_onf <- function(col, na) {
    if (col %in% names(onf_c)) onf_c[[col]][j] else rep(na, nrow(ten))
  }
  surface <- as.numeric(sf::st_area(ten))
  part <- rep(NA_real_, nrow(ten))
  if (any(!hors)) {
    inter <- suppressWarnings(sf::st_intersection(sf::st_geometry(ten),
                                                  sf::st_geometry(onf_c)))
    idx <- attr(inter, "idx")
    if (length(inter)) {
      bon <- onf_c$ugf_id[idx[, 2]] == ten$ugf[idx[, 1]]
      a <- tapply(as.numeric(sf::st_area(inter))[bon], idx[bon, 1], sum)
      part[!hors] <- 0
      part[as.integer(names(a))] <- pmin(1, as.numeric(a) / surface[as.integer(names(a))])
    }
  }
  out <- sf::st_sf(
    idu = ten$idu,
    tenement_id = paste0(ten$ugf, "~", ten$idu),
    ugf_id = ten$ugf,
    nom_ugf = ifelse(hors, ten$idu, as.character(attr_onf("nom_ugf", NA_character_))),
    foret_id = as.character(attr_onf("foret_id", NA_character_)),
    foret_nom = as.character(attr_onf("foret_nom", NA_character_)),
    parcelle = as.character(attr_onf("parcelle", NA_character_)),
    domaniale = as.logical(attr_onf("domaniale", NA)),
    surface_m2 = surface,
    part_onf = round(part, 4),
    geometry = sf::st_geometry(ten))
  out <- out[order(hors, out$ugf_id, -out$surface_m2), , drop = FALSE]
  row.names(out) <- NULL
  out <- sf::st_transform(out, sf::st_crs(crs))
  attr(out, "parcelles") <- parcelles
  attr(out, "calage") <- calage
  out
}

.ugf_sortie_vide <- function(crs) {
  sf::st_sf(
    idu = character(0), tenement_id = character(0), ugf_id = character(0),
    nom_ugf = character(0), foret_id = character(0), foret_nom = character(0),
    parcelle = character(0), domaniale = logical(0), surface_m2 = numeric(0),
    part_onf = numeric(0), geometry = sf::st_sfc(crs = crs))
}
