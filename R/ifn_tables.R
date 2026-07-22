# ifn_tables.R — tables de référence IFN par essence x SER (spec 040, lots 2-3)
# -----------------------------------------------------------------------------
# Deux tables, même schéma de clés (niveau / ser / greco / espar) et même
# cascade de repli SER -> GRECO -> national, sur l'idiome déjà en place dans P1
# (espèce -> genre -> feuillu/résineux, cf. indicateur_p1_volume()) :
#
#   ifn_volume_essence_ser.csv       volume SUR PIED (m3/ha)     -> stock
#   ifn_prelevement_essence_ser.csv  PRÉLÈVEMENT  (m3/ha/an)     -> flux
#
# Construites par data-raw/build_ifn_tables.R depuis les données brutes de
# l'IGN (Licence Ouverte Etalab v2.0). La méthode d'agrégation du volume suit
# PPtools::CarteEssenceSer() de Max Bruciamacchie (GPL-2, reprise sous GPL-3
# avec son autorisation, courriel du 22 juillet 2026).
#
# ATTENTION — le prélèvement décrit ce qui A ÉTÉ récolté, pas une prescription.

.ifn_table <- function(fichier) {
  path <- system.file("extdata", fichier, package = "nemeton")
  if (!nzchar(path) || !file.exists(path)) {
    cli::cli_abort("{fichier} not found in the installed package.")
  }
  # `na.strings` explicite : les tables sont ecrites avec des champs vides pour
  # les NA (data-raw/build_ifn_tables.R, `na = ""`). Sans cela, `ser`/`greco`
  # des lignes nationales reviennent en "" et non en NA, et tous les tests
  # d'appartenance a un echelon echouent silencieusement.
  utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8",
                  na.strings = c("NA", ""))
}

.ifn_vol_table <- function() .ifn_table("ifn_volume_essence_ser.csv")
.ifn_prelev_table <- function() .ifn_table("ifn_prelevement_essence_ser.csv")

# Filtre commun aux deux accesseurs (meme schema de cles).
.ifn_filtrer <- function(d, espar, ser, greco, niveau) {
  if (!is.null(niveau)) {
    niveau <- match.arg(niveau, c("ser", "greco", "national"), several.ok = TRUE)
    d <- d[d$niveau %in% niveau, , drop = FALSE]
  }
  if (!is.null(espar)) d <- d[d$espar %in% as.character(espar), , drop = FALSE]
  if (!is.null(ser))   d <- d[!is.na(d$ser) & d$ser %in% ser, , drop = FALSE]
  if (!is.null(greco)) d <- d[!is.na(d$greco) & d$greco %in% greco, , drop = FALSE]
  rownames(d) <- NULL
  d
}

# Cascade SER -> GRECO -> national, commune au volume et au prelevement.
# Rend NA plutot qu'un chiffre quand aucun echelon ne qualifie.
.ifn_cascade <- function(d, espar, ser, min_plac, col, nom_sortie) {
  if (!is.character(espar) || length(espar) == 0L) {
    cli::cli_abort("{.arg espar} must be a non-empty character vector.")
  }
  if (!is.null(ser) && (length(ser) != 1L || is.na(ser))) {
    cli::cli_abort("{.arg ser} must be a single SER code, or NULL.")
  }
  if (!is.numeric(min_plac) || length(min_plac) != 1L || is.na(min_plac) ||
      min_plac < 0) {
    cli::cli_abort("{.arg min_plac} must be a single non-negative number.")
  }
  greco <- if (is.null(ser)) NULL else substr(as.character(ser), 1L, 1L)
  echelons <- Filter(Negate(is.null), list(
    if (!is.null(ser))   list(niveau = "ser",
                              sel = function(x) !is.na(x$ser) & x$ser == ser),
    if (!is.null(greco)) list(niveau = "greco",
                              sel = function(x) !is.na(x$greco) & x$greco == greco),
    list(niveau = "national", sel = function(x) TRUE)
  ))
  vide <- function(e) {
    out <- data.frame(espar = e, libelle_essence = NA_character_,
                      val = NA_real_, niveau_utilise = NA_character_,
                      n_plac_presence = NA_integer_,
                      ser = if (is.null(ser)) NA_character_ else ser,
                      greco = if (is.null(greco)) NA_character_ else greco,
                      stringsAsFactors = FALSE)
    names(out)[names(out) == "val"] <- nom_sortie
    out
  }
  une <- function(e) {
    for (ech in echelons) {
      cand <- d[d$niveau == ech$niveau & d$espar == e, , drop = FALSE]
      if (nrow(cand) > 0L) cand <- cand[ech$sel(cand), , drop = FALSE]
      if (nrow(cand) == 1L && cand$n_plac_presence >= min_plac) {
        out <- data.frame(espar = e, libelle_essence = cand$libelle_essence,
                          val = cand[[col]], niveau_utilise = ech$niveau,
                          n_plac_presence = cand$n_plac_presence,
                          ser = if (is.null(ser)) NA_character_ else ser,
                          greco = if (is.null(greco)) NA_character_ else greco,
                          stringsAsFactors = FALSE)
        names(out)[names(out) == "val"] <- nom_sortie
        return(out)
      }
    }
    vide(e)
  }
  out <- do.call(rbind, lapply(as.character(espar), une))
  rownames(out) <- NULL
  out
}

#' IFN standing volume by species and sylvoecoregion
#'
#' @description
#' Reference table of standing timber volume per hectare, by IFN species code
#' and by sylvoecoregion (SER), derived from the raw IFN tree and plot data
#' (campaigns 2005-2024).
#'
#' Three nested levels live in the same table, selected by `niveau`:
#' `"ser"` (86 sylvoecoregions), `"greco"` (the SER code's first letter — the
#' greater ecological region) and `"national"`. Use
#' [ifn_volume_reference()] to walk them as a fallback ladder.
#'
#' Two volume columns, deliberately both kept:
#' \itemize{
#'   \item `vol_ha_present` — mean volume per hectare **over the plots where
#'     the species occurs**. This is a stand-level figure, the one comparable
#'     to a P1 computed on a forest unit of that species.
#'   \item `vol_ha_maille` — the species' contribution to the mesh's mean
#'     volume per hectare, averaged over **all** its plots. This is a regional
#'     resource figure; it is much lower for a scattered species.
#' }
#'
#' @section Standing volume, not harvest:
#' These figures are **standing stock**. For the harvest flux that
#' [volume_mobilisable()] needs, see [ifn_prelevement_essence_ser()] and
#' [ifn_taux_prelevement()].
#'
#' @section Sampling depth:
#' `n_plac_presence` (plots carrying the species) grades reliability and is
#' not decorative: many species x SER cells rest on a handful of plots.
#' Filter on it, or use [ifn_volume_reference()], which does.
#'
#' @param espar Optional IFN species code filter (character, e.g. `"09"` for
#'   beech). Note these are the IFN's own codes, not the four-letter codes of
#'   [indicateur_p1_volume()].
#' @param ser Optional SER code filter (e.g. `"C20"`).
#' @param greco Optional GRECO code filter (single letter, e.g. `"C"`).
#' @param niveau Optional level filter: `"ser"`, `"greco"` or `"national"`.
#'
#' @return A data.frame with `niveau`, `ser`, `greco`, `espar`,
#'   `n_plac_presence`, `n_plac_maille`, `vol_ha_present`, `vol_ha_maille`,
#'   `taux_presence`, `libelle_essence`, `millesime`, `source`.
#'
#' @references
#' Data and aggregation method from the `DataForet` and `PPtools` packages by
#' Max Bruciamacchie (AgroParisTech Nancy), GPL-2, reused under GPL-3 with
#' explicit permission. Method after `PPtools::CarteEssenceSer()`.
#'
#' @seealso [ifn_volume_reference()] for the fallback ladder.
#' @export
#' @examples
#' \dontrun{
#' # Beech across all sylvoecoregions, best-sampled first.
#' b <- ifn_volume_essence_ser(espar = "09", niveau = "ser")
#' head(b[order(-b$n_plac_presence), c("ser", "n_plac_presence", "vol_ha_present")])
#' }
ifn_volume_essence_ser <- function(espar = NULL, ser = NULL, greco = NULL,
                                   niveau = NULL) {
  .ifn_filtrer(.ifn_vol_table(), espar, ser, greco, niveau)
}

#' Reference standing volume, with a SER -> GRECO -> national fallback
#'
#' @description
#' Returns one reference volume per requested species, walking down the mesh
#' until the cell rests on enough plots: sylvoecoregion, then greater
#' ecological region, then national. The level actually used is reported, so
#' a caller can tell a regional figure from a national one — never silently.
#'
#' This mirrors the fallback already used by [indicateur_p1_volume()]
#' (species -> genus -> conifer/broadleaf): degrade the resolution rather than
#' return a figure resting on three plots.
#'
#' @param espar IFN species code(s), character.
#' @param ser SER code, a single string (e.g. `"C20"`). Its first letter gives
#'   the GRECO. `NULL` starts the ladder at the national level.
#' @param min_plac Minimum number of plots carrying the species for a level to
#'   be accepted. Default `30`.
#' @param mesure Which volume column to return: `"present"` (default, the
#'   stand-level figure) or `"maille"` (the regional resource figure). See
#'   [ifn_volume_essence_ser()].
#'
#' @return A data.frame with one row per `espar`: `espar`, `libelle_essence`,
#'   `vol_ha`, `niveau_utilise` (`"ser"`/`"greco"`/`"national"`, or `NA` when
#'   no level qualified), `n_plac_presence`, `ser`, `greco`.
#'
#' @seealso [ifn_volume_essence_ser()] for the raw table.
#' @export
#' @examples
#' \dontrun{
#' # Beech and silver fir in sylvoecoregion C20.
#' ifn_volume_reference(c("09", "61"), ser = "C20")
#' }
ifn_volume_reference <- function(espar, ser = NULL, min_plac = 30,
                                 mesure = c("present", "maille")) {
  mesure <- match.arg(mesure)
  col <- if (identical(mesure, "present")) "vol_ha_present" else "vol_ha_maille"
  .ifn_cascade(.ifn_vol_table(), espar, ser, min_plac, col, "vol_ha")
}

#' IFN harvest by species and sylvoecoregion
#'
#' @description
#' Reference table of **harvested** timber per hectare and per year, by IFN
#' species code and sylvoecoregion, derived from the five-year revisit of the
#' raw IFN data (campaigns 2005-2024).
#'
#' Same key schema and same three nested levels as
#' [ifn_volume_essence_ser()]: `"ser"`, `"greco"`, `"national"`.
#'
#' @section What counts as harvested:
#' Only `VEGET5 == "6"` — *arbre coupé vidangé*, felled **and extracted**.
#' Code `7` (*coupé non vidangé*) is deliberately excluded: that wood stays in
#' the forest and never travels the road network, which is what this table is
#' meant to size.
#'
#' @section Two approximations, stated:
#' \enumerate{
#'   \item The revisit row carries only the tree's fate — neither its volume
#'     nor its species. Both are taken from the tree's **first-visit** row
#'     (key `IDP`, `A`), so the harvested volume is the volume at first
#'     measurement: the tree grew somewhat before being felled. 92% of felled
#'     trees carry such a measurement.
#'   \item Harvest observed over the five-year interval is divided by five to
#'     give a yearly flux. It is an average, not a schedule.
#' }
#'
#' As a sanity check, summing `prelev_ha_an_maille` over all species at the
#' national level gives **2.84 m3/ha/year**, consistent with the published
#' order of magnitude for French forest harvest.
#'
#' @section Harvest is not prescription:
#' These figures describe what **has been** removed, not what **should** be.
#' Sizing a road network on them assumes management carries on unchanged.
#'
#' @param espar Optional IFN species code filter (character, e.g. `"09"`).
#' @param ser Optional SER code filter (e.g. `"C20"`).
#' @param greco Optional GRECO code filter (single letter).
#' @param niveau Optional level filter: `"ser"`, `"greco"` or `"national"`.
#'
#' @return A data.frame with `niveau`, `ser`, `greco`, `espar`,
#'   `n_plac_presence`, `n_plac_maille`, `prelev_ha_an_present`,
#'   `prelev_ha_an_maille`, `taux_presence`, `libelle_essence`, `millesime`,
#'   `source`.
#'
#' @seealso [ifn_taux_prelevement()] for the fallback ladder,
#'   [ifn_volume_essence_ser()] for standing volume.
#' @export
#' @examples
#' \dontrun{
#' ifn_prelevement_essence_ser(espar = "62", niveau = "national")
#' }
ifn_prelevement_essence_ser <- function(espar = NULL, ser = NULL, greco = NULL,
                                        niveau = NULL) {
  .ifn_filtrer(.ifn_prelev_table(), espar, ser, greco, niveau)
}

#' Reference harvest rate, with a SER -> GRECO -> national fallback
#'
#' @description
#' Returns one harvest rate per requested species, in **m3/ha/year**, walking
#' the mesh down until the cell rests on enough plots and reporting the level
#' actually used. This is the rate [volume_mobilisable()] consumes.
#'
#' @param espar IFN species code(s), character.
#' @param ser SER code, a single string. `NULL` starts at the national level.
#' @param min_plac Minimum plots carrying the species for a level to qualify.
#'   Default `30`.
#' @param mesure `"maille"` (default) returns the rate per hectare of forest in
#'   the mesh — the figure whose national sum matches published harvest.
#'   `"present"` returns the rate over the plots where the species occurs,
#'   which is much higher for a clear-felled species such as poplar.
#'
#' @return A data.frame with one row per `espar`: `espar`, `libelle_essence`,
#'   `taux_m3_ha_an`, `niveau_utilise`, `n_plac_presence`, `ser`, `greco`.
#'
#' @seealso [ifn_prelevement_essence_ser()], [volume_mobilisable()].
#' @export
#' @examples
#' \dontrun{
#' ifn_taux_prelevement(c("62", "09"), ser = "C20")
#' }
ifn_taux_prelevement <- function(espar, ser = NULL, min_plac = 30,
                                 mesure = c("maille", "present")) {
  mesure <- match.arg(mesure)
  col <- if (identical(mesure, "maille")) "prelev_ha_an_maille" else "prelev_ha_an_present"
  .ifn_cascade(.ifn_prelev_table(), espar, ser, min_plac, col, "taux_m3_ha_an")
}
