# croiser_parcelles_onf.R — pour chaque UGF (parcelle forestière ONF), les
# tènements de parcelles cadastrales qu'elle rencontre.
# ---------------------------------------------------------------------------
# On part de la parcelle FORESTIÈRE — c'est elle l'unité de gestion, donc
# l'UGF — et on rend, pour chacune, le ou les tènements découpés dans les
# parcelles CADASTRALES qu'elle traverse. Un tènement = (UGF x parcelle
# cadastrale), toujours un seul par parcelle rencontrée.
#
# Pourquoi côté cœur (règle #1) : les deux découpages ne coïncident pas, et le
# désalignement est invisible à l'échelle de l'UGF. Mesuré sur la forêt
# communale de La-Vieille-Loye (39) : recouvrement minimum 98,1 %, médiane
# 100 % — impeccable. Au niveau du fragment, 33 UGF x 56 parcelles cadastrales
# donnent 92 fragments dont **51 sous 0,05 ha**, qui ne portent ensemble que
# 0,13 % de la surface. Ce sont des écarts de numérisation, pas des objets de
# gestion ; les laisser passer noierait l'app sous des tènements fantômes.
#
# Deux traitements, du plus doux au plus franc :
#   - `min_surface_ha` : une écharde est absorbée par le plus gros tènement de
#     la MÊME parcelle cadastrale, jamais supprimée — la parcelle reste pavée
#     exactement, ce qu'exige `validate_tiling()` côté app.
#   - `caler_sur_cadastre` : quand une UGF couvre déjà l'essentiel d'une
#     parcelle cadastrale (>= `seuil_calage`), la parcelle lui est attribuée
#     ENTIÈRE. Le bord de l'UGF vient alors se coller au bord cadastral. Les
#     parcelles réellement partagées entre deux UGF restent coupées.

.croiser_id_col <- function(x, id_col = NULL) {
  if (!is.null(id_col)) {
    if (!id_col %in% names(x)) return(NULL)
    return(id_col)
  }
  candidats <- intersect(c("id", "nemeton_id", "geo_parcelle", "idu"), names(x))
  if (length(candidats) == 0L) NULL else candidats[1L]
}

# Surfaces et seuils n'ont de sens qu'en mètres.
.croiser_crs_travail <- function(crs) {
  if (isTRUE(sf::st_is_longlat(crs))) 2154L else crs
}

.croiser_vide <- function(crs) {
  sf::st_sf(
    ugf_id = character(0), nom_ugf = character(0), foret_id = character(0),
    foret_nom = character(0), parcelle = character(0), domaniale = logical(0),
    tenement_id = character(0), parcelle_cadastrale = character(0),
    hors_ugf = logical(0), surface_ha = numeric(0), part_ugf = numeric(0),
    part_cadastrale = numeric(0), n_tenements = integer(0),
    geometry = sf::st_sfc(crs = crs)
  )
}

#' Tenements met by each ONF forest parcel (UGF)
#'
#' @description
#' Start from the **forest parcels** returned by [load_onf_parcelles_source()]
#' — they are the management units, hence the UGF — and return, for each of
#' them, the tenement(s) cut out of the **cadastral** parcels it meets. One
#' tenement per cadastral parcel met, so the result reads as: *this UGF is made
#' of these pieces of these cadastral parcels*.
#'
#' The two subdivisions do not coincide, and the misalignment is invisible at
#' UGF scale. Measured on the *forêt communale de La-Vieille-Loye* (39):
#' coverage of each forest parcel by the cadastre is 98.1 % at worst, 100 % at
#' the median — yet cutting 33 forest parcels against 56 cadastral parcels
#' yields 92 fragments, **51 of them under 0.05 ha**, carrying together
#' **0.13 %** of the area. Digitising slivers, not management objects.
#'
#' Two corrections, mildest first:
#' * `min_surface_ha` — a sliver is **absorbed** by the largest tenement of the
#'   same cadastral parcel, never dropped, so each cadastral parcel stays
#'   exactly tiled (the application's tiling invariant).
#' * `caler_sur_cadastre` — when one UGF already holds at least
#'   `seuil_calage` of a cadastral parcel, that parcel is given to it **whole**:
#'   the UGF boundary snaps onto the cadastral boundary. Parcels genuinely
#'   shared between two UGF stay cut.
#'
#' @param parcelles_onf An `sf` of forest parcels, as returned by
#'   [load_onf_parcelles_source()]. These are the UGF.
#' @param parcelles An `sf` of cadastral parcels. Its identifier column is taken
#'   from `id_col`, or auto-detected among `id`, `nemeton_id`, `geo_parcelle`,
#'   `idu`.
#' @param min_surface_ha Tenements strictly smaller than this are treated as
#'   slivers and absorbed. Default `0.05` (500 m²) — inside the natural gap
#'   measured between slivers (≤ 0.035 ha) and real tenements (≥ 0.12 ha). Use
#'   `0` to keep every sliver.
#' @param caler_sur_cadastre Snap UGF boundaries onto cadastral boundaries by
#'   giving each nearly-covered cadastral parcel whole to its dominant UGF.
#'   Default `FALSE`.
#' @param seuil_calage Share of a cadastral parcel above which its dominant UGF
#'   takes it whole. Only used when `caler_sur_cadastre` is `TRUE`. Default
#'   `0.9`.
#' @param inclure_reste Also return, with `ugf_id` `NA` and `hors_ugf` `TRUE`,
#'   the parts of cadastral parcels no forest parcel covers. Default `FALSE` —
#'   the UGF-first view does not need them, and the application's
#'   `tenement_split_by_import()` recreates that remainder itself.
#' @param id_col Name of the identifier column of `parcelles`. Default `NULL`
#'   (auto-detect).
#'
#' @return An `sf` of tenements in the CRS of `parcelles_onf`, ordered by UGF
#'   then by decreasing area, with columns `ugf_id`, `nom_ugf`, `foret_id`,
#'   `foret_nom`, `parcelle`, `domaniale`, `tenement_id`
#'   (`<ugf_id>~<cadastral id>`), `parcelle_cadastrale`, `hors_ugf`,
#'   `surface_ha`, `part_ugf` (share of the UGF this tenement represents),
#'   `part_cadastrale` (share of the cadastral parcel) and `n_tenements`
#'   (tenements of that UGF). A 0-row `sf` when nothing intersects.
#' @seealso [load_onf_parcelles_source()]
#' @export
croiser_parcelles_onf <- function(parcelles_onf, parcelles,
                                  min_surface_ha = 0.05,
                                  caler_sur_cadastre = FALSE,
                                  seuil_calage = 0.9,
                                  inclure_reste = FALSE,
                                  id_col = NULL) {
  if (!inherits(parcelles_onf, "sf")) {
    cli::cli_abort("{.arg parcelles_onf} must be an sf of ONF forest parcels.")
  }
  if (!inherits(parcelles, "sf")) {
    cli::cli_abort("{.arg parcelles} must be an sf of cadastral parcels.")
  }
  if (is.na(sf::st_crs(parcelles_onf)) || is.na(sf::st_crs(parcelles))) {
    cli::cli_abort("Both layers must have a defined CRS.")
  }
  attendus <- c("id", "nom_ugf", "foret_id", "foret_nom", "parcelle", "domaniale")
  if (!all(attendus %in% names(parcelles_onf))) {
    cli::cli_abort(c(
      "{.arg parcelles_onf} does not look like a {.fn load_onf_parcelles_source} result.",
      i = "Missing: {setdiff(attendus, names(parcelles_onf))}."))
  }
  col <- .croiser_id_col(parcelles, id_col)
  if (is.null(col)) {
    cli::cli_abort(c(
      "{.arg parcelles} needs an identifier column.",
      i = "Looked for {.val id}, {.val nemeton_id}, {.val geo_parcelle}, {.val idu}."))
  }
  if (!is.numeric(seuil_calage) || seuil_calage <= 0 || seuil_calage > 1) {
    cli::cli_abort("{.arg seuil_calage} must be a share in (0, 1].")
  }

  crs_sortie <- sf::st_crs(parcelles_onf)
  crs_travail <- .croiser_crs_travail(crs_sortie)
  onf <- sf::st_transform(sf::st_make_valid(parcelles_onf), crs_travail)
  cad <- sf::st_transform(sf::st_make_valid(parcelles), crs_travail)
  if (nrow(onf) == 0L || nrow(cad) == 0L) return(.croiser_vide(crs_sortie))

  cad_id <- as.character(cad[[col]])
  aire_cad <- stats::setNames(as.numeric(sf::st_area(cad)), cad_id)
  aire_onf <- stats::setNames(as.numeric(sf::st_area(onf)), onf$id)

  gauche <- sf::st_sf(
    ugf_id = onf$id, nom_ugf = onf$nom_ugf, foret_id = onf$foret_id,
    foret_nom = onf$foret_nom, parcelle = onf$parcelle,
    domaniale = onf$domaniale, geometry = sf::st_geometry(onf))
  droite <- sf::st_sf(parcelle_cadastrale = cad_id,
                      geometry = sf::st_geometry(cad))

  ten <- suppressWarnings(sf::st_intersection(gauche, droite))
  ten <- .croiser_polygones_seuls(ten)
  ten$hors_ugf <- rep(FALSE, nrow(ten))
  # Un tènement par (UGF x parcelle cadastrale), même si l'intersection est
  # multipartie.
  ten <- .croiser_fusionner(ten, c("ugf_id", "parcelle_cadastrale"))

  reste <- .croiser_reste(cad, droite, onf)
  frags <- if (nrow(ten) == 0L) reste else if (nrow(reste) == 0L) ten else
    rbind(ten, reste[, names(ten)])
  if (nrow(frags) == 0L) return(.croiser_vide(crs_sortie))
  frags$surface_ha <- as.numeric(sf::st_area(frags)) / 1e4
  frags <- frags[frags$surface_ha > 0, , drop = FALSE]
  if (nrow(frags) == 0L) return(.croiser_vide(crs_sortie))

  if (isTRUE(caler_sur_cadastre)) {
    frags <- .croiser_caler(frags, cad, droite, aire_cad, seuil_calage)
    frags$surface_ha <- as.numeric(sf::st_area(frags)) / 1e4
  }
  if (min_surface_ha > 0) {
    frags <- .croiser_absorber(frags, min_surface_ha)
    frags$surface_ha <- as.numeric(sf::st_area(frags)) / 1e4
  }

  if (!isTRUE(inclure_reste)) {
    frags <- frags[!frags$hors_ugf, , drop = FALSE]
    if (nrow(frags) == 0L) return(.croiser_vide(crs_sortie))
  }

  frags$part_cadastrale <- frags$surface_ha * 1e4 /
    aire_cad[frags$parcelle_cadastrale]
  frags$part_ugf <- ifelse(frags$hors_ugf, NA_real_,
                           frags$surface_ha * 1e4 / aire_onf[frags$ugf_id])
  frags$tenement_id <- ifelse(
    frags$hors_ugf, paste0("hors_ugf~", frags$parcelle_cadastrale),
    paste0(frags$ugf_id, "~", frags$parcelle_cadastrale))

  cle <- ifelse(frags$hors_ugf, "", frags$ugf_id)
  frags$n_tenements <- as.integer(table(cle)[cle])
  frags$n_tenements[frags$hors_ugf] <- NA_integer_

  frags <- frags[order(frags$hors_ugf, frags$nom_ugf, frags$ugf_id,
                       -frags$surface_ha), , drop = FALSE]
  frags <- frags[, c("ugf_id", "nom_ugf", "foret_id", "foret_nom", "parcelle",
                     "domaniale", "tenement_id", "parcelle_cadastrale",
                     "hors_ugf", "surface_ha", "part_ugf", "part_cadastrale",
                     "n_tenements", attr(frags, "sf_column"))]
  row.names(frags) <- NULL
  sf::st_transform(frags, crs_sortie)
}

# st_intersection rend aussi des points/lignes sur les contacts de bord.
.croiser_polygones_seuls <- function(x) {
  if (nrow(x) == 0L) return(x)
  types <- as.character(sf::st_geometry_type(x))
  x <- x[types %in% c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION"), ,
         drop = FALSE]
  if (nrow(x) == 0L) return(x)
  if (any(as.character(sf::st_geometry_type(x)) == "GEOMETRYCOLLECTION")) {
    x <- suppressWarnings(sf::st_collection_extract(x, "POLYGON"))
  }
  x
}

# Regroupe les lignes partageant la même clé en une seule géométrie.
.croiser_fusionner <- function(x, cles) {
  if (nrow(x) == 0L) return(x)
  cle <- do.call(paste, c(lapply(cles, function(k) x[[k]]), sep = "\r"))
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

# Part de chaque parcelle cadastrale qu'aucune UGF ne couvre.
.croiser_reste <- function(cad, droite, onf) {
  vide <- droite[0, , drop = FALSE]
  vide$ugf_id <- character(0); vide$nom_ugf <- character(0)
  vide$foret_id <- character(0); vide$foret_nom <- character(0)
  vide$parcelle <- character(0); vide$domaniale <- logical(0)
  vide$hors_ugf <- logical(0)

  onf_u <- sf::st_union(sf::st_geometry(onf))
  geom <- suppressWarnings(sf::st_difference(sf::st_geometry(cad), onf_u))
  if (length(geom) == 0L) return(vide)
  idx <- attr(geom, "idx")
  lignes <- if (!is.null(idx)) idx[, 1] else seq_along(geom)
  out <- sf::st_sf(
    ugf_id = NA_character_, nom_ugf = NA_character_, foret_id = NA_character_,
    foret_nom = NA_character_, parcelle = NA_character_, domaniale = NA,
    parcelle_cadastrale = droite$parcelle_cadastrale[lignes],
    hors_ugf = TRUE, geometry = geom)
  .croiser_polygones_seuls(out)
}

# Calage : une parcelle cadastrale dont une UGF détient déjà `seuil` est
# attribuée ENTIÈRE à cette UGF — le bord de l'UGF se cale sur le bord
# cadastral. Les parcelles réellement partagées restent découpées.
.croiser_caler <- function(frags, cad, droite, aire_cad, seuil) {
  if (nrow(frags) == 0L) return(frags)
  geo_cad <- stats::setNames(sf::st_geometry(cad), droite$parcelle_cadastrale)
  groupes <- split(seq_len(nrow(frags)), frags$parcelle_cadastrale)
  geo <- sf::st_geometry(frags)
  a_jeter <- integer(0)

  for (nom in names(groupes)) {
    g <- groupes[[nom]]
    # Seule une UGF peut prendre une parcelle : laisser le « hors UGF » gagner
    # reviendrait à SUPPRIMER de la forêt, ce qui n'est pas une correction.
    cand <- g[!frags$hors_ugf[g]]
    if (length(cand) == 0L) next
    parts <- frags$surface_ha[cand] * 1e4 / aire_cad[[nom]]
    if (max(parts) < seuil) next            # parcelle réellement partagée
    dominant <- cand[which.max(parts)]
    if (length(g) == 1L && isTRUE(all.equal(max(parts), 1))) next
    geo[dominant] <- geo_cad[[nom]]         # la parcelle entière
    a_jeter <- c(a_jeter, setdiff(g, dominant))
  }

  sf::st_geometry(frags) <- geo
  if (length(a_jeter) > 0L) frags <- frags[-a_jeter, , drop = FALSE]
  frags
}

# Absorbe chaque écharde dans le plus gros tènement de la même parcelle
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
