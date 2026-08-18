# load_onf_parcelles.R — acquisition du parcellaire forestier public ONF (spec 046)
# ---------------------------------------------------------------------------
# Récupère les parcelles forestières des forêts publiques (domaniales et des
# collectivités) relevant du régime forestier, depuis le WFS ONF « Forêts
# publiques » servi par Carmen (producteur ONF, diffusion publique). Objectif :
# créer des UGF prêtes à l'emploi sans tracé cadastral manuel, la parcelle
# forestière étant le cadre de gestion matérialisé sur le terrain.
#
# L'acquisition métier vit dans le cœur (règle #1) ; l'app orchestre, cache et
# présente (même pattern que load_foret_ancienne_source / load_theia_source).
#
# Limites du service, relevées en direct le 2026-08-18 :
#   - grain = PARCELLE, pas sous-parcelle (l'unité de gestion fine de
#     l'aménagement n'est pas ouverte) : une parcelle peut mélanger plusieurs
#     peuplements. C'est une approximation NDP 0 de l'UGF, à assumer ;
#   - le paramètre WFS `FILTER` est REJETÉ par le pare-feu applicatif devant
#     Carmen (« Request Rejected », HTTP 200 avec une page HTML) : pas de
#     requête attributaire côté serveur. Seul `BBOX` passe — d'où la sélection
#     par emprise ici, et le filtre domanialité appliqué localement ;
#   - GML seulement (ni GeoJSON ni sortie JSON) ;
#   - HTTP uniquement : https://ws.carmencarto.fr ne répond pas. Sans
#     conséquence côté serveur R ; bloquant depuis un navigateur en HTTPS.
#   - licence non déclarée sur data.gouv.fr (« License Not Specified »),
#     l'ONF annonce une diffusion « libre et gratuite » : citer le producteur.

# Racine du WFS ONF (métropole) ; les territoires ultramarins ont leur endpoint.
.ONF_WFS_BASE <- "http://ws.carmencarto.fr/WFS/105/ONF_Forets"

# Territoires servis : suffixe d'endpoint, suffixe de couche et CRS natif
# (relevés sur les GetCapabilities de chaque service, 2026-08-18).
.ONF_TERRITOIRES <- list(
  FR  = list(endpoint = "",     suffixe = "FR",  epsg = 2154L),
  GLP = list(endpoint = "_glp", suffixe = "GLP", epsg = 32620L),
  MTQ = list(endpoint = "_mtq", suffixe = "MTQ", epsg = 32620L),
  GUF = list(endpoint = "_guf", suffixe = "GUF", epsg = 2972L),
  REU = list(endpoint = "_reu", suffixe = "REU", epsg = 2975L),
  MYT = list(endpoint = "_myt", suffixe = "MYT", epsg = 4471L)
)

.onf_parcelles_empty <- function(crs) {
  sf::st_sf(
    id = character(0), foret_id = character(0), foret_nom = character(0),
    parcelle = character(0), domaniale = logical(0), nom_ugf = character(0),
    contenance = numeric(0), surface_ha = numeric(0),
    geometry = sf::st_sfc(crs = crs)
  )
}

# Construit une URL GetFeature WFS 2.0. `couche` vaut "PARC_PUBL" ou "FOR_PUBL",
# le suffixe territorial est ajouté ici.
.onf_wfs_url <- function(terr, couche, bbox, count = NULL) {
  urn <- paste0("urn:ogc:def:crs:EPSG::", terr$epsg)
  parts <- c(
    "SERVICE=WFS", "VERSION=2.0.0", "REQUEST=GetFeature",
    paste0("TYPENAMES=ms:", couche, "_", terr$suffixe),
    paste0("SRSNAME=", urn),
    paste0("BBOX=", paste(c(format(bbox, scientific = FALSE, trim = TRUE), urn),
                          collapse = ","))
  )
  if (!is.null(count)) parts <- c(parts, paste0("COUNT=", as.integer(count)))
  paste0(.ONF_WFS_BASE, terr$endpoint, "?", paste(parts, collapse = "&"))
}

# Télécharge et lit une réponse GML. Retourne un sf (avec l'attribut
# "numberMatched" quand le serveur l'annonce) ou NULL en cas d'échec —
# y compris les échecs qui arrivent en HTTP 200 (page HTML du pare-feu,
# ExceptionReport OWS).
.onf_wfs_read <- function(url) {
  dest <- tempfile(fileext = ".gml")
  on.exit(unlink(c(dest, paste0(tools::file_path_sans_ext(dest), ".gfs"))),
          add = TRUE)

  status <- tryCatch(
    suppressWarnings(utils::download.file(url, dest, mode = "wb", quiet = TRUE)),
    error = function(e) {
      cli::cli_warn(c("ONF WFS request failed.", i = conditionMessage(e)))
      -1L
    }
  )
  if (!identical(as.integer(status), 0L) || !file.exists(dest) ||
      file.size(dest) == 0) {
    return(NULL)
  }

  entete <- paste(readLines(dest, n = 4L, warn = FALSE), collapse = " ")
  if (grepl("<html", entete, ignore.case = TRUE)) {
    cli::cli_warn("ONF WFS request was rejected by the service firewall.")
    return(NULL)
  }
  if (grepl("ExceptionReport", entete, fixed = TRUE)) {
    cli::cli_warn("ONF WFS returned an exception report.")
    return(NULL)
  }

  x <- tryCatch(sf::st_read(dest, quiet = TRUE), error = function(e) {
    cli::cli_warn(c("ONF WFS response could not be parsed.",
                    i = conditionMessage(e)))
    NULL
  })
  if (is.null(x) || !inherits(x, c("sf", "sfc"))) return(NULL)
  x <- sf::st_as_sf(x)

  m <- regmatches(entete, regexpr('numberMatched="[0-9]+"', entete))
  if (length(m) == 1L) {
    attr(x, "numberMatched") <- as.integer(gsub("\\D", "", m))
  }
  x
}

# Une parcelle forestière peut arriver en plusieurs entités (multipartie
# éclatée). On refusionne par (forêt, n° de parcelle) pour garantir
# « une ligne = une parcelle = une UGF ».
.onf_fusionner_parcelles <- function(x) {
  cle <- paste0(x$foret_id, "\r", x$parcelle)
  if (!anyDuplicated(cle)) return(x)
  geo <- sf::st_geometry(x)
  groupes <- split(seq_along(cle), factor(cle, levels = unique(cle)))
  premiers <- vapply(groupes, function(i) i[1L], integer(1))
  fusion <- do.call(c, lapply(groupes, function(i) {
    if (length(i) == 1L) geo[i] else sf::st_union(geo[i])
  }))
  out <- x[premiers, , drop = FALSE]
  sf::st_geometry(out) <- sf::st_cast(fusion, "MULTIPOLYGON")
  out
}

#' Acquire the ONF public-forest parcel layer for an AOI
#'
#' @description
#' Fetch the **forest parcels of French public forests** (state-owned
#' *domaniales* and local-authority forests under the *régime forestier*) over
#' `aoi` from the ONF "Forêts publiques" WFS (Carmen, ONF as producer, public
#' diffusion), and return them ready to be turned into forest management units
#' (UGF): one row per parcel, with a stable id, a display label, the owning
#' forest and its ownership status.
#'
#' The forest parcel is the reference frame ONF uses on the ground for
#' management, so it is a far better UGF seed than a cadastral parcel. Note the
#' grain is the **parcel**, not the sub-parcel: the finer management unit of the
#' *aménagement* is not published, so a parcel may still mix stands.
#'
#' Degrades gracefully — returns `NULL` on any failure (no network, service
#' firewall rejection, OWS exception, unknown territory) so the caller can fall
#' back to cadastral selection. A 0-row `sf` is returned when the AOI simply
#' holds no public forest.
#'
#' @param aoi An `sf`/`sfc` project extent (must have a defined CRS).
#' @param crs Target EPSG of the returned layer. Default `2154`.
#' @param domanialite Ownership filter: `"toutes"` (default), `"domaniale"`
#'   (state forests only) or `"autre"` (local-authority and other public
#'   forests). Parcels whose ownership could not be resolved are dropped by the
#'   two filtering modes.
#' @param territoire Territory served by the WFS: `"FR"` (metropolitan,
#'   default), `"GLP"`, `"MTQ"`, `"GUF"`, `"REU"` or `"MYT"`.
#' @param max_parcelles Maximum number of parcels requested (`COUNT`). Guards
#'   against pulling a whole region; a warning is emitted when the service
#'   announces more matches than returned. Default `5000`.
#' @param clip Clip parcels to `aoi` instead of keeping whole parcels that
#'   intersect it. Default `FALSE` — a UGF is normally the entire parcel.
#'
#' @return An `sf` of forest parcels in `crs` with columns `id`
#'   (`<forêt>-<parcelle>`), `foret_id`, `foret_nom`, `parcelle`, `domaniale`,
#'   `nom_ugf`, `contenance` (m², computed in the territory's projected CRS) and
#'   `surface_ha`; a 0-row `sf` if none; `NULL` on failure.
#' @seealso [load_foret_ancienne_source()], [get_layer_service()]
#' @export
load_onf_parcelles_source <- function(aoi, crs = 2154,
                                      domanialite = c("toutes", "domaniale",
                                                      "autre"),
                                      territoire = "FR",
                                      max_parcelles = 5000L,
                                      clip = FALSE) {
  domanialite <- match.arg(domanialite)

  if (!inherits(aoi, c("sf", "sfc"))) {
    cli::cli_warn("load_onf_parcelles_source(): {.arg aoi} must be an sf/sfc; returning NULL.")
    return(NULL)
  }
  if (is.na(sf::st_crs(aoi))) {
    cli::cli_warn("load_onf_parcelles_source(): {.arg aoi} has no CRS; returning NULL.")
    return(NULL)
  }
  terr <- .ONF_TERRITOIRES[[toupper(as.character(territoire)[1])]]
  if (is.null(terr)) {
    cli::cli_warn(c(
      "load_onf_parcelles_source(): unknown {.arg territoire}; returning NULL.",
      i = "Known territories: {names(.ONF_TERRITOIRES)}."))
    return(NULL)
  }

  aoi_geom <- sf::st_geometry(aoi)
  bb <- sf::st_bbox(sf::st_transform(aoi_geom, terr$epsg))
  bbox <- c(bb[["xmin"]], bb[["ymin"]], bb[["xmax"]], bb[["ymax"]])

  parc <- .onf_wfs_read(.onf_wfs_url(terr, "PARC_PUBL", bbox,
                                     count = max_parcelles))
  if (is.null(parc)) return(NULL)
  if (nrow(parc) == 0L) return(.onf_parcelles_empty(crs))

  attendus <- c("iidtn_frt", "llib_frt", "ccod_prf")
  if (!all(attendus %in% names(parc))) {
    cli::cli_warn("ONF WFS returned an unexpected schema; returning NULL.")
    return(NULL)
  }
  n_total <- attr(parc, "numberMatched")
  if (!is.null(n_total) && n_total > nrow(parc)) {
    cli::cli_warn(c(
      "ONF WFS matched {n_total} parcels but only {nrow(parc)} were returned.",
      i = "Raise {.arg max_parcelles} or narrow the AOI."))
  }

  # Domanialité : portée par la couche des forêts, jointe par identifiant de
  # forêt. Repli sur le libellé (« Forêt domaniale de … ») si la couche échoue.
  forets <- .onf_wfs_read(.onf_wfs_url(terr, "FOR_PUBL", bbox,
                                       count = max_parcelles))
  dom <- rep(NA, nrow(parc))
  if (!is.null(forets) && nrow(forets) > 0L &&
      all(c("iidtn_frt", "cdom_frt") %in% names(forets))) {
    ref <- stats::setNames(toupper(forets$cdom_frt) == "OUI", forets$iidtn_frt)
    dom <- unname(ref[parc$iidtn_frt])
  }
  manquants <- is.na(dom)
  if (any(manquants)) {
    dom[manquants] <- grepl("domaniale", parc$llib_frt[manquants],
                            ignore.case = TRUE)
  }

  garde <- switch(domanialite,
                  toutes    = seq_len(nrow(parc)),
                  domaniale = which(dom),
                  autre     = which(!dom))
  parc <- parc[garde, , drop = FALSE]
  dom  <- dom[garde]
  if (nrow(parc) == 0L) return(.onf_parcelles_empty(crs))

  # Le WFS ne filtre que par bbox : on restreint aux parcelles qui touchent
  # réellement l'emprise, sans les découper (une UGF = une parcelle entière).
  parc <- sf::st_make_valid(parc)
  aoi_u <- sf::st_union(sf::st_transform(aoi_geom, sf::st_crs(parc)))
  touche <- lengths(sf::st_intersects(parc, aoi_u)) > 0L
  parc <- parc[touche, , drop = FALSE]
  dom <- dom[touche]
  if (nrow(parc) == 0L) return(.onf_parcelles_empty(crs))
  if (isTRUE(clip)) {
    parc <- suppressWarnings(sf::st_intersection(parc, aoi_u))
    if (nrow(parc) == 0L) return(.onf_parcelles_empty(crs))
    dom <- dom[seq_len(nrow(parc))]
  }

  out <- sf::st_sf(
    id         = paste0(parc$iidtn_frt, "-", parc$ccod_prf),
    foret_id   = as.character(parc$iidtn_frt),
    foret_nom  = as.character(parc$llib_frt),
    parcelle   = as.character(parc$ccod_prf),
    domaniale  = as.logical(dom),
    nom_ugf    = paste0(parc$llib_frt, " \u2014 parcelle ", parc$ccod_prf),
    geometry   = sf::st_geometry(parc)
  )
  out <- .onf_fusionner_parcelles(out)

  # Surfaces mesurées après fusion, dans le CRS projeté du territoire.
  aire <- as.numeric(sf::st_area(sf::st_geometry(out)))
  out$contenance <- aire
  out$surface_ha <- aire / 1e4
  out <- out[order(out$foret_nom,
                   suppressWarnings(as.numeric(out$parcelle)),
                   out$parcelle), , drop = FALSE]
  out <- out[, c("id", "foret_id", "foret_nom", "parcelle", "domaniale",
                 "nom_ugf", "contenance", "surface_ha",
                 attr(out, "sf_column"))]
  row.names(out) <- NULL
  sf::st_transform(out, crs)
}
