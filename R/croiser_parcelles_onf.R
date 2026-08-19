# croiser_parcelles_onf.R — croisement parcellaire ONF x parcelles cadastrales
# ---------------------------------------------------------------------------
# Croise les parcelles forestières publiques (spec 046, load_onf_parcelles_source)
# avec une sélection de parcelles CADASTRALES, pour produire les fragments qui
# serviront de tenements : une ligne = (parcelle cadastrale x parcelle ONF),
# plus un « reste » par parcelle cadastrale non couverte.
#
# Pourquoi côté cœur (règle #1) : le croisement n'est pas de l'affichage. Les
# deux découpages ne coïncident pas — mesuré sur la forêt communale de
# La-Vieille-Loye (39), 56 parcelles cadastrales x 33 parcelles ONF donnent
# 92 fragments, dont **51 sous 0,05 ha** qui ne portent ensemble que 0,13 % de
# la surface. Ce sont des échardes de désalignement, pas des objets de gestion.
# Les laisser passer noierait l'app sous des tenements fantômes.
#
# Les échardes sont **absorbées** par le plus gros fragment de la même parcelle
# cadastrale, jamais supprimées : le pavage de chaque parcelle reste exact, ce
# qu'exige l'invariant de tuilage côté app (`validate_tiling()`).

.croiser_id_col <- function(x, id_col = NULL) {
  if (!is.null(id_col)) {
    if (!id_col %in% names(x)) return(NULL)
    return(id_col)
  }
  candidats <- intersect(c("id", "nemeton_id", "geo_parcelle", "idu"), names(x))
  if (length(candidats) == 0L) NULL else candidats[1L]
}

# CRS de travail : celui des parcelles s'il est projeté, sinon Lambert-93 (les
# surfaces et les seuils d'échardes n'ont de sens qu'en mètres).
.croiser_crs_travail <- function(crs) {
  if (isTRUE(sf::st_is_longlat(crs))) 2154L else crs
}

.croiser_vide <- function(crs) {
  sf::st_sf(
    parcelle_cadastrale = character(0), id_onf = character(0),
    nom_ugf = character(0), foret_id = character(0), foret_nom = character(0),
    parcelle = character(0), domaniale = logical(0), reste = logical(0),
    surface_ha = numeric(0), part_cadastrale = numeric(0),
    part_onf = numeric(0), geometry = sf::st_sfc(crs = crs)
  )
}

#' Cross ONF forest parcels with selected cadastral parcels
#'
#' @description
#' Intersect the ONF public-forest parcels returned by
#' [load_onf_parcelles_source()] with a selection of **cadastral** parcels, and
#' return the fragments that the application turns into tenements: one row per
#' (cadastral parcel × forest parcel) pair, plus one `reste` row per cadastral
#' parcel whose area is not covered by any forest parcel.
#'
#' The two subdivisions do not coincide, and their misalignment is the whole
#' difficulty. Measured on the *forêt communale de La-Vieille-Loye* (39):
#' 56 cadastral parcels × 33 forest parcels produce 92 fragments, of which
#' **51 fall under 0.05 ha** while carrying together **0.13 %** of the area —
#' digitising slivers, not management objects.
#'
#' Slivers below `min_surface_ha` are therefore **absorbed** into the largest
#' fragment of the same cadastral parcel (the `reste` included), never dropped:
#' each cadastral parcel stays exactly tiled, which is what the application's
#' tiling invariant requires.
#'
#' @param parcelles An `sf` of selected cadastral parcels. Its identifier column
#'   is taken from `id_col`, or auto-detected among `id`, `nemeton_id`,
#'   `geo_parcelle`, `idu`.
#' @param parcelles_onf An `sf` of forest parcels, as returned by
#'   [load_onf_parcelles_source()].
#' @param min_surface_ha Fragments strictly smaller than this are treated as
#'   slivers. Default `0.05` (500 m²) — inside the natural gap measured between
#'   slivers (≤ 0.035 ha) and real fragments (≥ 0.12 ha).
#' @param absorber_echardes Absorb slivers into the largest fragment of the same
#'   cadastral parcel. Default `TRUE`. Set `FALSE` to inspect them.
#' @param id_col Name of the identifier column of `parcelles`. Default `NULL`
#'   (auto-detect).
#'
#' @return An `sf` of fragments in the CRS of `parcelles`, with columns
#'   `parcelle_cadastrale`, `id_onf`, `nom_ugf`, `foret_id`, `foret_nom`,
#'   `parcelle`, `domaniale`, `reste`, `surface_ha`, `part_cadastrale` (share of
#'   the cadastral parcel) and `part_onf` (share of the forest parcel — how much
#'   of it the selection actually holds). A 0-row `sf` when nothing intersects.
#' @seealso [load_onf_parcelles_source()]
#' @export
croiser_parcelles_onf <- function(parcelles, parcelles_onf,
                                  min_surface_ha = 0.05,
                                  absorber_echardes = TRUE,
                                  id_col = NULL) {
  if (!inherits(parcelles, "sf")) {
    cli::cli_abort("{.arg parcelles} must be an sf of cadastral parcels.")
  }
  if (!inherits(parcelles_onf, "sf")) {
    cli::cli_abort("{.arg parcelles_onf} must be an sf of ONF forest parcels.")
  }
  if (is.na(sf::st_crs(parcelles)) || is.na(sf::st_crs(parcelles_onf))) {
    cli::cli_abort("Both layers must have a defined CRS.")
  }
  col <- .croiser_id_col(parcelles, id_col)
  if (is.null(col)) {
    cli::cli_abort(c(
      "{.arg parcelles} needs an identifier column.",
      i = "Looked for {.val id}, {.val nemeton_id}, {.val geo_parcelle}, {.val idu}."))
  }
  attendus <- c("id", "nom_ugf", "foret_id", "foret_nom", "parcelle", "domaniale")
  if (!all(attendus %in% names(parcelles_onf))) {
    cli::cli_abort(c(
      "{.arg parcelles_onf} does not look like a {.fn load_onf_parcelles_source} result.",
      i = "Missing: {setdiff(attendus, names(parcelles_onf))}."))
  }

  crs_sortie <- sf::st_crs(parcelles)
  crs_travail <- .croiser_crs_travail(crs_sortie)
  cad <- sf::st_transform(sf::st_make_valid(parcelles), crs_travail)
  onf <- sf::st_transform(sf::st_make_valid(parcelles_onf), crs_travail)
  if (nrow(cad) == 0L || nrow(onf) == 0L) return(.croiser_vide(crs_sortie))

  cad_id <- as.character(cad[[col]])
  aire_cad <- stats::setNames(as.numeric(sf::st_area(cad)), cad_id)
  aire_onf <- stats::setNames(as.numeric(sf::st_area(onf)), onf$id)

  # Fragments (parcelle cadastrale x parcelle ONF).
  gauche <- sf::st_sf(parcelle_cadastrale = cad_id,
                      geometry = sf::st_geometry(cad))
  droite <- sf::st_sf(
    id_onf = onf$id, nom_ugf = onf$nom_ugf, foret_id = onf$foret_id,
    foret_nom = onf$foret_nom, parcelle = onf$parcelle,
    domaniale = onf$domaniale, geometry = sf::st_geometry(onf))
  fr <- suppressWarnings(sf::st_intersection(gauche, droite))
  fr <- .croiser_polygones_seuls(fr)
  fr$reste <- rep(FALSE, nrow(fr))

  # Reste : part de chaque parcelle cadastrale qu'aucune parcelle ONF ne couvre.
  restes <- .croiser_restes(cad, gauche, onf)
  frags <- if (nrow(fr) == 0L) restes else if (nrow(restes) == 0L) fr else
    rbind(fr[, names(restes)], restes)
  if (nrow(frags) == 0L) return(.croiser_vide(crs_sortie))

  frags$surface_ha <- as.numeric(sf::st_area(frags)) / 1e4
  frags <- frags[frags$surface_ha > 0, , drop = FALSE]
  if (nrow(frags) == 0L) return(.croiser_vide(crs_sortie))

  if (isTRUE(absorber_echardes)) {
    frags <- .croiser_absorber(frags, min_surface_ha)
    frags$surface_ha <- as.numeric(sf::st_area(frags)) / 1e4
  }

  frags$part_cadastrale <- frags$surface_ha * 1e4 /
    aire_cad[frags$parcelle_cadastrale]
  frags$part_onf <- ifelse(
    is.na(frags$id_onf), NA_real_,
    frags$surface_ha * 1e4 / aire_onf[frags$id_onf])

  frags <- frags[order(frags$parcelle_cadastrale, frags$reste,
                       -frags$surface_ha), , drop = FALSE]
  frags <- frags[, c("parcelle_cadastrale", "id_onf", "nom_ugf", "foret_id",
                     "foret_nom", "parcelle", "domaniale", "reste",
                     "surface_ha", "part_cadastrale", "part_onf",
                     attr(frags, "sf_column"))]
  row.names(frags) <- NULL
  sf::st_transform(frags, crs_sortie)
}

# st_intersection rend aussi des points/lignes sur les contacts de bord : ce
# ne sont pas des fragments de surface.
.croiser_polygones_seuls <- function(x) {
  if (nrow(x) == 0L) return(x)
  types <- as.character(sf::st_geometry_type(x))
  garde <- types %in% c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION")
  x <- x[garde, , drop = FALSE]
  if (nrow(x) == 0L) return(x)
  if (any(as.character(sf::st_geometry_type(x)) == "GEOMETRYCOLLECTION")) {
    x <- suppressWarnings(sf::st_collection_extract(x, "POLYGON"))
  }
  x
}

.croiser_restes <- function(cad, gauche, onf) {
  vide <- gauche[0, , drop = FALSE]
  vide$id_onf <- character(0); vide$nom_ugf <- character(0)
  vide$foret_id <- character(0); vide$foret_nom <- character(0)
  vide$parcelle <- character(0); vide$domaniale <- logical(0)
  vide$reste <- logical(0)

  onf_u <- sf::st_union(sf::st_geometry(onf))
  reste_geom <- suppressWarnings(
    sf::st_difference(sf::st_geometry(cad), onf_u))
  if (length(reste_geom) == 0L) return(vide)
  # st_difference conserve l'ordre et laisse tomber les géométries vides ;
  # l'attribut "idx" (ou les noms) rattache chaque reste à sa parcelle.
  idx <- attr(reste_geom, "idx")
  lignes <- if (!is.null(idx)) idx[, 1] else seq_along(reste_geom)
  out <- sf::st_sf(
    parcelle_cadastrale = gauche$parcelle_cadastrale[lignes],
    id_onf = NA_character_, nom_ugf = NA_character_, foret_id = NA_character_,
    foret_nom = NA_character_, parcelle = NA_character_, domaniale = NA,
    reste = TRUE, geometry = reste_geom)
  .croiser_polygones_seuls(out)
}

# Absorbe chaque écharde dans le plus gros fragment de la même parcelle
# cadastrale : le pavage reste exact, seule l'attribution change.
.croiser_absorber <- function(frags, min_surface_ha) {
  if (nrow(frags) == 0L) return(frags)
  groupes <- split(seq_len(nrow(frags)), frags$parcelle_cadastrale)
  geo <- sf::st_geometry(frags)
  a_jeter <- integer(0)

  for (g in groupes) {
    if (length(g) <= 1L) next
    petites <- g[frags$surface_ha[g] < min_surface_ha]
    if (length(petites) == 0L) next
    grosses <- setdiff(g, petites)
    # Tout le groupe sous le seuil : on garde le plus gros comme cible.
    cible <- if (length(grosses) > 0L) grosses[which.max(frags$surface_ha[grosses])]
             else g[which.max(frags$surface_ha[g])]
    petites <- setdiff(petites, cible)
    if (length(petites) == 0L) next
    geo[cible] <- sf::st_union(sf::st_union(geo[c(cible, petites)]))
    a_jeter <- c(a_jeter, petites)
  }

  sf::st_geometry(frags) <- geo
  if (length(a_jeter) > 0L) frags <- frags[-a_jeter, , drop = FALSE]
  frags
}
