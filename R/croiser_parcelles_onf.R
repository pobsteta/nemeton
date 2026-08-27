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
#   - `min_surface_ha` : une écharde est absorbée par le tènement de la MÊME
#     parcelle cadastrale avec lequel elle partage la plus longue frontière,
#     jamais supprimée — la parcelle reste pavée exactement, ce qu'exige
#     `validate_tiling()` côté app. Le seuil s'applique aux PARTIES et non aux
#     lignes (v0.190.0) : `ten` et `reste` étant fondus en multipolygones, il
#     comparait auparavant un seuil conçu pour des échardes au total d'un
#     multipolygone, et ne voyait donc jamais les échardes qu'il visait.
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

.croiser_vide <- function(crs, concernees = 0L, total = 0L) {
  x <- sf::st_sf(
    ugf_id = character(0), nom_ugf = character(0), foret_id = character(0),
    foret_nom = character(0), parcelle = character(0), domaniale = logical(0),
    tenement_id = character(0), parcelle_cadastrale = character(0),
    hors_ugf = logical(0), surface_ha = numeric(0), part_ugf = numeric(0),
    part_cadastrale = numeric(0), n_tenements = integer(0),
    geometry = sf::st_sfc(crs = crs)
  )
  attr(x, "parcelles_concernees") <-
    c(concernees = as.integer(concernees), total = as.integer(total))
  x
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
#' * `min_surface_ha` — a sliver is **absorbed** by the tenement of the same
#'   cadastral parcel it shares the longest boundary with, never dropped, so
#'   each cadastral parcel stays exactly tiled (the application's tiling
#'   invariant).
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
#' @param min_surface_ha Parts strictly smaller than this are treated as
#'   slivers and absorbed. Default `0.05` (500 m²) — inside the natural gap
#'   measured between slivers (≤ 0.035 ha) and real tenements (≥ 0.12 ha). Use
#'   `0` to keep every sliver.
#'
#'   Since v0.190.0 the threshold is compared against each **simple part**, not
#'   against the row: both `ten` and the remainder are merged into
#'   multipolygons, so a 10 ha remainder made of eight pieces — several under
#'   100 m² — sailed over the threshold and shed its slivers as soon as a
#'   consumer normalised the output to single parts. Measured on the 21 real
#'   parcels of Couchey: 255 parts, 96 under the threshold and 57 under 100 m²
#'   survived absorption; none does now, and the cadastral tiling is unchanged
#'   to the square metre.
#'
#'   A sliver joins the part it shares the **longest boundary** with, not the
#'   largest one: the union of two touching polygons is a single polygon, which
#'   is what makes the sliver disappear for good. When nothing touches it, the
#'   historical fallback applies (largest fragment of the parcel) — the sliver
#'   then only changes label, since the union stays multipart.
#' @param caler_sur_cadastre Snap UGF boundaries onto cadastral boundaries by
#'   giving each nearly-covered cadastral parcel whole to its dominant UGF.
#'   Default `FALSE`.
#' @param seuil_calage Share of a cadastral parcel above which its dominant UGF
#'   takes it whole. Only used when `caler_sur_cadastre` is `TRUE`. Default
#'   `0.9`.
#' @param rattacher_reste When `TRUE`, each piece of the remainder
#'   joins the forest parcel it shares its **longest common boundary** with,
#'   instead of piling up in a "hors forêt" catch-all. Length, not area nor
#'   distance: a ride running 400 m along parcel 3 and touching parcel 4 at a
#'   corner belongs to 3, and a point contact is not a neighbourhood. A piece
#'   with no forest neighbour makes its cadastral parcel **its own unit**, named
#'   after its reference. Measured at Couchey: the catch-all held 72 tenements
#'   and 49.68 ha on a project whose parcels are *all* in forest; attaching
#'   spreads one parcel's 10.89 ha of strips across **six** units instead of
#'   inflating the dominant one by 77% with ground it does not touch.
#'   Only meaningful with `inclure_reste = TRUE`.
#'
#'   **Default `FALSE`, deliberately.** `inclure_reste` promises rows carrying
#'   `ugf_id = NA` and `hors_ugf = TRUE`; flipping this default would void that
#'   promise without a word for every existing caller. The rule is available,
#'   the contract holds — the caller opts in, and can then drop its own copy of
#'   the logic.
#' @param inclure_reste Also return, with `ugf_id` `NA` and `hors_ugf` `TRUE`,
#'   the parts of cadastral parcels no forest parcel covers. Default `FALSE` —
#'   the UGF-first view does not need them, and the application's
#'   `tenement_split_by_import()` recreates that remainder itself.
#' @param id_col Name of the identifier column of `parcelles`. Default `NULL`
#'   (auto-detect).
#'
#' Cadastral parcels that meet **no** forest parcel are detected up front and
#' never crossed: they can only produce one row — themselves, whole, outside any
#' UGF — so that row is emitted directly, from the untouched geometry. On a real
#' commune (La-Vieille-Loye, 39) only 181 of 1 271 parcels meet the public
#' forest; skipping the rest takes the crossing from 19.1 s to 7.3 s with
#' `inclure_reste = FALSE`, and from 20.6 s to 14.0 s with it. The result is
#' unchanged, geometry for geometry.
#'
#' @return An `sf` of tenements in the CRS of `parcelles_onf`, ordered by UGF
#'   then by decreasing area, with columns `ugf_id`, `nom_ugf`, `foret_id`,
#'   `foret_nom`, `parcelle`, `domaniale`, `tenement_id`
#'   (`<ugf_id>~<cadastral id>`), `parcelle_cadastrale`, `hors_ugf`,
#'   `surface_ha`, `part_ugf` (share of the UGF this tenement represents),
#'   `part_cadastrale` (share of the cadastral parcel) and `n_tenements`
#'   (tenements of that UGF). A 0-row `sf` when nothing intersects.
#'
#'   The result carries a `parcelles_concernees` attribute, a named integer
#'   vector `c(concernees =, total =)`: how many cadastral parcels actually meet
#'   the forest layer, out of how many were given. It saves the caller an
#'   `st_intersects()` just to report "N parcels out of M".
#' @seealso [load_onf_parcelles_source()]
#' @export
croiser_parcelles_onf <- function(parcelles_onf, parcelles,
                                  min_surface_ha = 0.05,
                                  caler_sur_cadastre = FALSE,
                                  seuil_calage = 0.9,
                                  inclure_reste = FALSE,
                                  rattacher_reste = FALSE,
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
  if (nrow(onf) == 0L || nrow(cad) == 0L) {
    return(.croiser_vide(crs_sortie, 0L, nrow(cad)))
  }

  cad_id <- as.character(cad[[col]])
  aire_cad <- stats::setNames(as.numeric(sf::st_area(cad)), cad_id)
  aire_onf <- stats::setNames(as.numeric(sf::st_area(onf)), onf$id)

  gauche <- sf::st_sf(
    ugf_id = onf$id, nom_ugf = onf$nom_ugf, foret_id = onf$foret_id,
    foret_nom = onf$foret_nom, parcelle = onf$parcelle,
    domaniale = onf$domaniale, geometry = sf::st_geometry(onf))
  droite <- sf::st_sf(parcelle_cadastrale = cad_id,
                      geometry = sf::st_geometry(cad))

  # Une parcelle cadastrale qu'aucune UGF ne rencontre ne peut produire qu'une
  # ligne : elle-même, entière, hors UGF. La croiser, c'est demander une
  # intersection dont le vide est connu d'avance. Sur une commune réelle
  # (La-Vieille-Loye, 39) seules 181 des 1 271 parcelles — 14 % — rencontrent
  # la forêt publique ; les écarter fait passer le croisement de 24,9 s à
  # 11,5 s, le test d'intersection coûtant 0,2 s.
  onf_u <- sf::st_union(sf::st_geometry(onf))
  concernee <- lengths(sf::st_intersects(sf::st_geometry(cad), onf_u)) > 0L
  n_concernees <- sum(concernee)

  gauche_c <- gauche
  droite_c <- droite[concernee, , drop = FALSE]
  cad_c <- cad[concernee, , drop = FALSE]

  if (n_concernees == 0L) {
    ten <- .croiser_vide_interne(droite)
    reste <- .croiser_vide_interne(droite)
  } else {
    ten <- suppressWarnings(sf::st_intersection(gauche_c, droite_c))
    ten <- .croiser_polygones_seuls(ten)
    ten$hors_ugf <- rep(FALSE, nrow(ten))
    # Un tènement par (UGF x parcelle cadastrale), même si l'intersection est
    # multipartie.
    ten <- .croiser_fusionner(ten, c("ugf_id", "parcelle_cadastrale"))
    reste <- .croiser_reste(cad_c, droite_c, onf_u)
  }

  # Les parcelles écartées reviennent telles quelles — aucune reprojection,
  # donc leur pavage reste exact. Elles ne servent qu'au `reste` : sans lui,
  # le pré-filtrage est un gain sec.
  if (isTRUE(inclure_reste) && any(!concernee)) {
    entieres <- sf::st_sf(
      ugf_id = NA_character_, nom_ugf = NA_character_, foret_id = NA_character_,
      foret_nom = NA_character_, parcelle = NA_character_, domaniale = NA,
      parcelle_cadastrale = droite$parcelle_cadastrale[!concernee],
      hors_ugf = TRUE, geometry = sf::st_geometry(cad)[!concernee])
    reste <- if (nrow(reste) == 0L) entieres else
      rbind(reste, entieres[, names(reste)])
  }
  frags <- if (nrow(ten) == 0L) reste else if (nrow(reste) == 0L) ten else
    rbind(ten, reste[, names(ten)])
  if (nrow(frags) == 0L) return(.croiser_vide(crs_sortie, n_concernees, nrow(cad)))
  frags$surface_ha <- as.numeric(sf::st_area(frags)) / 1e4
  frags <- frags[frags$surface_ha > 0, , drop = FALSE]
  if (nrow(frags) == 0L) return(.croiser_vide(crs_sortie, n_concernees, nrow(cad)))

  if (isTRUE(caler_sur_cadastre)) {
    frags <- .croiser_caler(frags, cad, droite, aire_cad, seuil_calage)
    frags$surface_ha <- as.numeric(sf::st_area(frags)) / 1e4
  }
  # Le reliquat rejoint son VOISIN, il ne s'entasse plus dans un fourre-tout.
  #
  # Regle enoncee par Pascal (2026-08-26) : le parcellaire ONF n'est pas un
  # filtre mais une SOURCE D'ETIQUETTES. Ce qui fait foi, c'est le cadastre, et
  # rien d'une parcelle cadastrale n'est jamais ecarte. Les bouts que le
  # parcellaire ne couvre pas — layons, routes, interstices entre parcelles
  # adjacentes, jeu de numerisation le long des limites — ne sont pas « hors
  # foret » : ils appartiennent aux peuplements qui les bordent.
  #
  # Mesure a Couchey : le receptacle « hors foret publique » totalisait 72
  # tenements et 49,68 ha sur un projet dont TOUTES les parcelles sont en foret.
  if (isTRUE(inclure_reste) && isTRUE(rattacher_reste) && any(frags$hors_ugf)) {
    frags <- .croiser_rattacher(frags, gauche)
    frags$surface_ha <- as.numeric(sf::st_area(frags)) / 1e4
  }

  if (min_surface_ha > 0) {
    frags <- .croiser_absorber(frags, min_surface_ha)
    frags$surface_ha <- as.numeric(sf::st_area(frags)) / 1e4
  }

  if (!isTRUE(inclure_reste)) {
    frags <- frags[!frags$hors_ugf, , drop = FALSE]
    if (nrow(frags) == 0L) return(.croiser_vide(crs_sortie, n_concernees, nrow(cad)))
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
  out <- sf::st_transform(frags, crs_sortie)
  # Le pré-filtrage connaît déjà le compte : le rendre évite au consommateur
  # de refaire un st_intersects() pour la seule information « N sur M ».
  attr(out, "parcelles_concernees") <-
    c(concernees = as.integer(n_concernees), total = nrow(cad))
  out
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

# Squelette 0 ligne aux colonnes internes (avant mise en forme finale).
.croiser_vide_interne <- function(droite) {
  vide <- droite[0, , drop = FALSE]
  vide$ugf_id <- character(0); vide$nom_ugf <- character(0)
  vide$foret_id <- character(0); vide$foret_nom <- character(0)
  vide$parcelle <- character(0); vide$domaniale <- logical(0)
  vide$hors_ugf <- logical(0)
  vide
}

# Part de chaque parcelle cadastrale qu'aucune UGF ne couvre.
.croiser_reste <- function(cad, droite, onf_u) {
  vide <- .croiser_vide_interne(droite)
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
# Rattache chaque morceau de reliquat a la parcelle forestiere avec laquelle il
# partage la PLUS LONGUE FRONTIERE commune.
#
# Trois choix de conception, chacun mesure a Couchey (spec 046, brief du
# 2026-08-26) :
#
#  1. ECLATER d'abord. `.croiser_reste()` rend une ligne par parcelle
#     cadastrale (un `st_difference`), donc multipartie : a cette granularite
#     « le voisin » n'a pas de sens — A0036 borde VINGT-HUIT parcelles
#     forestieres, et son reliquat de 10,89 ha se disperse en 8 bandes.
#
#  2. La LONGUEUR de frontiere, pas la surface ni la distance. Un layon qui
#     longe la parcelle 3 sur 400 m et effleure la parcelle 4 par un coin
#     appartient a la 3. Un contact PONCTUEL (longueur nulle) n'est pas un
#     voisinage.
#
#  3. Sans voisin forestier, la parcelle reste SA PROPRE UGF, nommee par sa
#     reference cadastrale — jamais versee dans un fourre-tout, qui ferait une
#     unite de gestion qui n'en est pas une.
#
# L'alternative « tout a l'UGF dominante » a ete ecartee sur mesure : sur A0036
# elle absorberait 10,89 ha de bandes dont plusieurs qu'elle ne touche pas,
# grossissant de 77 % sur des terrains situes a l'autre bout de la parcelle.
# La plus longue frontiere les repartit entre SIX UGF.
.croiser_rattacher <- function(frags, gauche) {
  i_hors <- which(frags$hors_ugf)
  if (!length(i_hors)) return(frags)

  hors <- frags[i_hors, , drop = FALSE]
  garde <- frags[-i_hors, , drop = FALSE]

  # 1. Parties simples — en DEUX temps, et ce n'est pas un detail.
  #
  # Sur un melange POLYGON/MULTIPOLYGON, `st_cast("POLYGON")` ne garde que le
  # PREMIER polygone de chaque multipartie, sans erreur ni avertissement :
  # mesure sur le parcellaire reel de Couchey, 20 lignes en entree, 20 en
  # sortie, et 13,74 ha des 50,34 evapores. Passer par MULTIPOLYGON d'abord
  # force l'eclatement (75 lignes, 50,34 ha conserves au metre carre).
  hors <- suppressWarnings(sf::st_cast(hors, "MULTIPOLYGON"))
  hors <- suppressWarnings(sf::st_cast(hors, "POLYGON", warn = FALSE))
  hors <- hors[!sf::st_is_empty(sf::st_geometry(hors)), , drop = FALSE]
  if (nrow(hors) == 0L) return(garde)

  # 2. Plus longue frontiere partagee avec une parcelle forestiere.
  # `gauche` porte les parcelles FORESTIERES et leurs attributs ; c'est bien
  # d'elles qu'on cherche le voisin, pas des parcelles cadastrales.
  voisins <- sf::st_intersects(hors, gauche)
  attrs <- c("ugf_id", "nom_ugf", "foret_id", "foret_nom", "parcelle",
             "domaniale")
  for (i in seq_len(nrow(hors))) {
    cand <- voisins[[i]]
    if (!length(cand)) next
    # Frontiere COMMUNE : on intersecte les BORDS, pas les surfaces. Deux
    # polygones adjacents ont une intersection surfacique vide mais un bord
    # partage bien reel — et l'intersection de deux polygones rend une
    # GEOMETRYCOLLECTION (lignes ET points) que `st_cast()` refuse en bloc,
    # defaut apparu sur le parcellaire reel de Couchey.
    lg <- vapply(cand, function(j) {
      inter <- suppressWarnings(sf::st_intersection(
        sf::st_boundary(sf::st_geometry(gauche)[j]),
        sf::st_boundary(sf::st_geometry(hors)[i])))
      if (!length(inter)) return(0)
      lin <- suppressWarnings(tryCatch(
        sf::st_collection_extract(inter, "LINESTRING"),
        error = function(e) inter))
      if (!length(lin)) return(0)
      v <- suppressWarnings(as.numeric(sum(sf::st_length(lin))))
      if (!is.finite(v)) 0 else v
    }, numeric(1))
    # Un contact PONCTUEL a une longueur nulle : ce n'est pas un voisinage.
    if (max(lg) <= 0) next
    j <- cand[which.max(lg)]
    for (a in intersect(attrs, names(gauche))) hors[[a]][i] <- gauche[[a]][j]
    hors$hors_ugf[i] <- FALSE
  }

  # 3. Sans voisin : la parcelle cadastrale devient sa propre UGF.
  orphelin <- hors$hors_ugf
  if (any(orphelin)) {
    ref <- hors$parcelle_cadastrale[orphelin]
    hors$ugf_id[orphelin]  <- paste0("cad~", ref)
    hors$nom_ugf[orphelin] <- ref
    hors$hors_ugf[orphelin] <- FALSE
  }

  out <- if (nrow(garde) == 0L) hors else rbind(garde, hors[, names(garde)])
  out
}


# Eclate une geometrie en parties simples. En DEUX temps, et ce n'est pas un
# detail : sur un melange POLYGON/MULTIPOLYGON, `st_cast("POLYGON")` ne garde
# que le PREMIER polygone de chaque multipartie, sans erreur ni avertissement
# (mesure sur le parcellaire reel de Couchey, v0.189.0 : 13,74 ha des 50,34
# evapores). Passer par MULTIPOLYGON d'abord force l'eclatement.
.croiser_parties <- function(geo) {
  g <- suppressWarnings(sf::st_cast(geo, "MULTIPOLYGON"))
  g <- suppressWarnings(sf::st_cast(g, "POLYGON", warn = FALSE))
  g[!sf::st_is_empty(g)]
}

# Longueur de frontiere COMMUNE entre deux polygones, a partir de leurs BORDS
# deja calcules -- ce sont les bords qu'on intersecte, pas les surfaces. Deux
# polygones adjacents ont une intersection surfacique vide et un bord partage
# bien reel ; l'intersection de deux bords rend une GEOMETRYCOLLECTION (lignes
# ET points) dont il faut extraire les lignes, sans quoi un contact PONCTUEL
# compterait comme un voisinage.
#
# Les bords arrivent precalcules : `st_boundary()` sur toutes les parties d'un
# groupe en un appel vectorise coute une fraction de ce que coutait un appel
# par paire, ou le bord d'une meme echarde etait recalcule pour chaque
# candidate.
.croiser_longueur_commune <- function(bord_a, bord_b) {
  inter <- suppressWarnings(sf::st_intersection(bord_a, bord_b))
  if (!length(inter)) return(0)
  lin <- suppressWarnings(tryCatch(
    sf::st_collection_extract(inter, "LINESTRING"), error = function(e) inter))
  if (!length(lin)) return(0)
  .croiser_longueur_euclidienne(lin)
}

# Longueur d'un jeu de lignes, en euclidien et sans passer par `st_length()`.
#
# Ce n'est pas une micro-optimisation gratuite : `st_length()` interroge les
# parametres du CRS a CHAQUE appel pour attacher son unite, et le profil de
# l'absorption sur Couchey y passait 6,1 s des 6,4 s mesurees
# (`CPL_crs_parameters`). Le CRS de travail est toujours PROJETE
# (`.croiser_crs_travail()` bascule en 2154 des que l'entree est en
# longitude/latitude), donc la somme euclidienne des segments EST la longueur,
# au metre pres et sans conversion.
.croiser_longueur_euclidienne <- function(lignes) {
  xy <- sf::st_coordinates(lignes)
  if (!nrow(xy)) return(0)
  # Les colonnes de regroupement (L1, L2...) separent les parties : un segment
  # ne relie deux points que s'ils appartiennent a la meme ligne.
  grp <- setdiff(colnames(xy), c("X", "Y", "Z", "M"))
  cle <- if (length(grp)) do.call(paste, c(as.data.frame(xy[, grp, drop = FALSE]),
                                           sep = "\r"))
         else rep("1", nrow(xy))
  meme <- cle[-1L] == cle[-length(cle)]
  d <- sqrt(diff(xy[, "X"])^2 + diff(xy[, "Y"])^2)
  v <- sum(d[meme])
  if (is.finite(v)) v else 0
}

# Absorption des echardes, AU NIVEAU DE LA PARTIE et non de la ligne.
#
# Pourquoi ce niveau. Un fragment est frequemment MULTIPARTIE : `ten` est fondu
# a une ligne par (UGF x parcelle cadastrale) et `reste` a une ligne par
# parcelle cadastrale. Comparer `min_surface_ha` a la surface de la ligne
# revient donc a comparer un seuil concu pour des echardes au total d'un
# multipolygone : a Couchey, le reliquat de `212000000A0036` pese 10,89 ha en
# une ligne, n'est jamais une echarde, et se disloque en 8 morceaux -- dont
# plusieurs sous 100 m2 -- des que le consommateur normalise en parties
# simples. Mesure sur les 21 parcelles reelles : 20 lignes de reliquat
# donnaient 78 morceaux dont 40 sous le seuil de 0,05 ha, et les tenements
# 117 lignes -> 158 morceaux dont 36 sous le seuil. L'absorption ne voyait
# aucun des deux.
#
# Ou va l'echarde. Au fragment avec lequel elle partage la PLUS LONGUE
# FRONTIERE -- pas au plus gros. C'est ce qui la fait vraiment disparaitre :
# l'union de deux polygones qui se touchent est UN polygone, qui survit a une
# normalisation en parties simples en aval. Le repli sur « le plus gros de la
# parcelle » est conserve quand rien ne touche l'echarde (comportement
# historique), mais il produit alors un multipolygone : le morceau reste
# separable, il change seulement d'etiquette.
#
# Ce que l'absorption ne fait jamais : jeter de la surface. Chaque partie
# retiree d'un fragment est ajoutee a un autre — le pavage cadastral reste
# exact au metre carre.
.croiser_absorber <- function(frags, min_surface_ha) {
  if (nrow(frags) == 0L) return(frags)
  geo <- sf::st_geometry(frags)

  # Toutes les parties de tous les fragments, en UN seul jeu. Les mesures
  # (`st_area`, `st_boundary`) sont ensuite vectorisees sur l'ensemble : elles
  # interrogent les parametres du CRS a chaque appel, et les faire par groupe
  # coutait 2,1 s des 10,4 s de l'absorption sur les 21 parcelles de Couchey.
  morceaux <- lapply(seq_len(nrow(frags)), function(i) .croiser_parties(geo[i]))
  proprio <- rep(seq_len(nrow(frags)), vapply(morceaux, length, integer(1)))
  if (!length(proprio)) return(frags)
  parts <- do.call(c, morceaux)
  aires <- as.numeric(sf::st_area(parts)) / 1e4
  bords <- sf::st_boundary(parts)

  groupes <- split(seq_along(parts), frags$parcelle_cadastrale[proprio])
  a_refaire <- integer(0)

  for (g in groupes) {
    # Un seul fragment dans la parcelle : ses parties sont disjointes par
    # construction (`.croiser_fusionner` a deja fondu ce qui se touchait), une
    # echarde n'a nulle part ou aller.
    if (length(unique(proprio[g])) <= 1L) next
    petites <- g[aires[g] < min_surface_ha]
    if (!length(petites)) next
    grosses <- setdiff(g, petites)
    # Aucune partie au-dessus du seuil : la plus grande sert de receptacle.
    if (!length(grosses)) grosses <- g[which.max(aires[g])]
    petites <- setdiff(petites, grosses)
    if (!length(petites)) next

    # Pre-selection par predicat spatial : `st_intersects` est indexe (STRtree)
    # et coute une fraction d'une intersection de bords. Sans elle, chaque
    # echarde etait mesuree contre TOUTES les parties du groupe -- 28 tenements
    # pour la seule parcelle 212000000A0036 de Couchey.
    touche <- sf::st_intersects(parts[petites], parts[grosses])

    for (n in seq_along(petites)) {
      k <- petites[n]
      # Candidates : les parties d'un AUTRE fragment. Deplacer une echarde a
      # l'interieur de son propre fragment ne changerait rien.
      cand <- grosses[proprio[grosses] != proprio[k]]
      if (!length(cand)) next
      proches <- intersect(cand, grosses[touche[[n]]])
      cible <- if (length(proches) == 1L) {
        # Une seule voisine : rien a departager, et l'intersection de bords
        # -- le poste de cout de cette boucle -- n'a pas lieu d'etre.
        proches
      } else if (length(proches) > 1L) {
        lg <- vapply(proches,
                     function(j) .croiser_longueur_commune(bords[j], bords[k]),
                     numeric(1))
        if (max(lg) > 0) proches[which.max(lg)] else cand[which.max(aires[cand])]
      } else {
        cand[which.max(aires[cand])]
      }
      a_refaire <- c(a_refaire, proprio[k], proprio[cible])
      proprio[k] <- proprio[cible]
    }
  }

  if (!length(a_refaire)) return(frags)

  # Reassemblage : seuls les fragments dont la composition a change sont
  # reconstruits ; les autres gardent leur geometrie d'origine au bit pres.
  a_jeter <- integer(0)
  for (i in unique(a_refaire)) {
    mien <- which(proprio == i)
    if (!length(mien)) { a_jeter <- c(a_jeter, i); next }
    geo[i] <- sf::st_cast(sf::st_union(parts[mien]), "MULTIPOLYGON")
  }

  sf::st_geometry(frags) <- geo
  if (length(a_jeter) > 0L) frags <- frags[-a_jeter, , drop = FALSE]
  frags
}
