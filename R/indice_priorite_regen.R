# indice_priorite_regen.R — priorité de régénération (spec 027 v2.1, L3)
# ------------------------------------------------------------------
# Indice de tête d'onglet « reGénération » : croise l'EXPOSITION
# microclimatique (moteur microclimf) et le STRESS HYDRIQUE du sol (moteur
# biljouR) en une priorité 0-100 d'intervention (haut = parcelle la plus
# vulnérable, à prioriser). Décision d'arbitrage §10.1 : indice GÉNÉRIQUE par
# défaut ; affinage par essence cible en OPTION (désactivé par défaut).
#
# Cette fonction ne calcule pas les moteurs (GPL, lourds) : elle CONSOMME leurs
# colonnes de sortie déjà posées sur `units` (contrat §7). Pure logique R,
# testable sur `sf` synthétique.
#
# Contrat d'entrée (au moins une colonne par volet) :
#   exposition : `sensibilite` (0-100, haut = plus exposé) — sinon dérivée de
#                `d_tmax` / `d_vpd` (aggravation canicule vs moyenne).
#   hydrique   : `njstress` (jours), `istress` (intensité), `rew_min` (réserve
#                en eau relative 0-1, bas = plus sec).

# Bornes de normalisation stress → 0-100. DOCUMENTÉES, révisables sur
# validation terrain / calage BILJOU (spec 027 §9.2). NON calibrées.
.REGEN_STRESS_BOUNDS <- list(
  njstress = c(lo = 0,  hi = 60),   # jours de stress hydrique estival
  istress  = c(lo = 0,  hi = 50),   # indice d'intensité de sécheresse (révisable)
  d_tmax   = c(lo = 0,  hi = 6),    # °C aggravation canicule − moyenne
  d_vpd    = c(lo = 0,  hi = 2)     # kPa aggravation
)

# Écart de tolérance → pénalité 1 (option essence). Cf. regeneration_tolerances().
.REGEN_TOL_SPAN <- c(tmax_c = 5.0, vpd_kpa = 1.5)

# Seuils de flag (§7). Révisables (arguments).
.REGEN_FLAG_BREAKS <- c(sensible = 50, priorite = 50)

# Normalise croissant 0-100, borné.
.regen_norm_up <- function(v, lo, hi) 100 * pmin(1, pmax(0, (v - lo) / (hi - lo)))

# Moyenne par ligne sur les composantes présentes & finies (poids renormalisés).
.regen_row_mean <- function(mat, weights) {
  vapply(seq_len(nrow(mat)), function(i) {
    v <- mat[i, ]; ok <- is.finite(v)
    if (!any(ok)) return(NA_real_)
    w <- weights[ok]; sum(v[ok] * w) / sum(w)
  }, numeric(1))
}


#' Regeneration tolerance table (per species)
#'
#' @description
#' Per-species heat / dryness tolerance thresholds used by the **optional**
#' species tuning of [indice_priorite_regen()] (spec 027 §10.1). Read from
#' `inst/extdata/regeneration_tolerances.csv`. Values are **indicative**
#' (they order species sensitivity), keyed on [list_species_classes()];
#' documented, not field-calibrated (spec 027 §9.2).
#'
#' @return A `data.frame` with columns `code`, `label`, `tmax_tol_c`
#'   (max tolerated under-canopy summer T°max, °C) and `vpd_tol_kpa`
#'   (max tolerated summer VPD, kPa).
#' @seealso [indice_priorite_regen()], [list_species_classes()]
#' @export
regeneration_tolerances <- function() {
  path <- system.file("extdata", "regeneration_tolerances.csv",
                      package = "nemeton")
  if (!nzchar(path) || !file.exists(path)) {
    stop("regeneration_tolerances.csv not found in the installed package",
         call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
}

# Détecte la colonne portant les codes de classe d'essence sur `units`.
.regen_detect_species_col <- function(units) {
  cand <- c("essence_dominante", "essence", "species_class",
            "classe_essence", "species")
  hit <- cand[cand %in% names(units)]
  if (length(hit)) hit[[1]] else NULL
}

# Classes NMT présentes sur `units` : via TFV (map_tfv_to_species_class) OU une
# colonne de codes de classe. Retourne un vecteur de codes de classe.
.regen_present_classes <- function(units, species_col, tfv_col, region) {
  if (is.null(units)) return(character(0))
  if (!is.null(tfv_col) && tfv_col %in% names(units)) {
    return(unique(stats::na.omit(map_tfv_to_species_class(units[[tfv_col]]))))
  }
  col <- if (!is.null(species_col)) species_col else .regen_detect_species_col(units)
  if (is.null(col) || !col %in% names(units)) return(character(0))
  vals <- unique(stats::na.omit(as.character(units[[col]])))
  class_codes <- tryCatch(list_species_classes(region = region)$code,
                          error = function(e) character(0))
  hit <- vals[vals %in% class_codes]
  # Repli : la colonne porte peut-être des codes TFV plutôt que des classes.
  if (!length(hit)) hit <- unique(stats::na.omit(map_tfv_to_species_class(vals)))
  hit
}

#' Species choices for the reGénération target-species selector
#'
#' @description
#' Build the option list for the app's "target species" dropdown, ready to
#' render. Two levels:
#'
#' * `level = "species"` (default): the **FRM** European species
#'   ([european_species_tolerances()], `statut = "frm"`) — the regulatory set
#'   you may plant. With `include_atlas = TRUE`, the JRC-Atlas species follow in
#'   a folded `"atlas"` group.
#' * `level = "class"`: the 11 broad species classes
#'   ([regeneration_tolerances()] ∩ [list_species_classes()]).
#'
#' Either way the options are **scorable** by [indice_priorite_regen()]
#' (`species =` resolves both tables). When `units` are given, the entries whose
#' species class is present on the parcels are flagged (`present = TRUE`,
#' `groupe = "present"`) and listed first; presence is read from a TFV column
#' (`tfv_col`, via [map_tfv_to_species_class()]) or a species-class column.
#' Remaining FRM entries form `groupe = "adaptation"`. Within each group,
#' options are ordered by increasing heat tolerance (`tmax_tol_c`) — the
#' adaptation group reads as "more heat-tolerant alternatives". The generic
#' "no species" default is added by the app (it maps to `species = NULL`).
#'
#' @param units Optional `sf`/data.frame of units, to flag present species.
#' @param species_col Optional column holding species-class codes
#'   ([list_species_classes()] codes). Auto-detected among `essence_dominante`,
#'   `essence`, `species_class`, `classe_essence`, `species` when `NULL`.
#' @param tfv_col Optional column holding BD Forêt v2 TFV codes; mapped to
#'   classes via [map_tfv_to_species_class()] (takes precedence over
#'   `species_col`).
#' @param level `"species"` (FRM European species, default) or `"class"` (11
#'   broad classes).
#' @param include_atlas Logical; in `"species"` level, also list the JRC-Atlas
#'   species (folded `"atlas"` group). Default `FALSE`.
#' @param region,lang Passed to [list_species_classes()] for the class level and
#'   presence detection.
#'
#' @return A data.frame of options, ordered present-first then by increasing
#'   `tmax_tol_c`. Level `"species"` columns: `code`, `label`, `species_sci`,
#'   `type`, `statut`, `species_class`, `tmax_tol_c`, `vpd_tol_kpa`,
#'   `shade_tol`, `drought_tol`, `confidence`, `invasif`, `present`, `groupe`.
#'   Level `"class"` columns: `code`, `label`, `tmax_tol_c`, `vpd_tol_kpa`,
#'   `present`, `groupe`.
#' @seealso [indice_priorite_regen()], [european_species_tolerances()],
#'   [regeneration_tolerances()], [map_tfv_to_species_class()]
#' @export
regen_species_choices <- function(units = NULL, species_col = NULL,
                                  tfv_col = NULL,
                                  level = c("species", "class"),
                                  include_atlas = FALSE,
                                  region = "BFC", lang = "fr") {
  level <- match.arg(level)
  present_classes <- .regen_present_classes(units, species_col, tfv_col, region)

  if (level == "class") {
    tol <- regeneration_tolerances()
    base <- tol[, c("code", "label", "tmax_tol_c", "vpd_tol_kpa"), drop = FALSE]
    cls <- tryCatch(list_species_classes(region = region, lang = lang),
                    error = function(e) NULL)
    if (!is.null(cls) && all(c("code", "label") %in% names(cls))) {
      loc <- cls$label[match(base$code, cls$code)]
      base$label <- ifelse(is.na(loc), base$label, loc)
    }
    base$present <- base$code %in% present_classes
    base$groupe <- ifelse(base$present, "present", "adaptation")
    base <- base[order(!base$present, base$tmax_tol_c), , drop = FALSE]
    rownames(base) <- NULL
    return(base)
  }

  # level == "species" : essences FRM (+ Atlas replié en option).
  base <- european_species_tolerances(statut = if (include_atlas) NULL else "frm")
  base$label <- base$species_fr
  base$present <- base$species_class %in% present_classes
  base$groupe <- ifelse(base$present, "present",
                        ifelse(grepl("^frm", base$statut), "adaptation", "atlas"))
  grp_rank <- match(base$groupe, c("present", "adaptation", "atlas"))
  base <- base[order(grp_rank, base$tmax_tol_c), , drop = FALSE]
  base <- base[, c("code", "label", "species_sci", "type", "statut",
                   "species_class", "tmax_tol_c", "vpd_tol_kpa", "shade_tol",
                   "drought_tol", "confidence", "invasif", "present", "groupe")]
  rownames(base) <- NULL
  base
}

# Résout (tmax_tol_c, vpd_tol_kpa) pour une essence — override explicite ou table.
.regen_resolve_tol <- function(species, tolerances) {
  if (is.null(species) || !nzchar(species)) return(NULL)
  if (is.list(tolerances) && !is.data.frame(tolerances) &&
      all(c("tmax_tol_c", "vpd_tol_kpa") %in% names(tolerances))) {
    return(list(tmax_tol_c = as.numeric(tolerances$tmax_tol_c),
                vpd_tol_kpa = as.numeric(tolerances$vpd_tol_kpa)))
  }
  if (is.data.frame(tolerances)) {
    hit <- tolerances[tolerances$code == species, , drop = FALSE]
  } else {
    # Défaut : classe (regeneration_tolerances) PUIS espèce UE
    # (european_species_tolerances) — permet species = "fagus_sylvatica".
    tbl <- regeneration_tolerances()
    hit <- tbl[tbl$code == species, , drop = FALSE]
    if (nrow(hit) == 0L) {
      eu <- tryCatch(european_species_tolerances(), error = function(e) NULL)
      if (!is.null(eu)) hit <- eu[eu$code == species, , drop = FALSE]
    }
  }
  if (nrow(hit) == 0L) return(NULL)
  list(tmax_tol_c = as.numeric(hit$tmax_tol_c[1]),
       vpd_tol_kpa = as.numeric(hit$vpd_tol_kpa[1]))
}

# Sous-score d'EXPOSITION (0-100, haut = plus exposé).
.regen_exposition <- function(units) {
  if ("sensibilite" %in% names(units)) {
    return(pmin(100, pmax(0, as.numeric(units$sensibilite))))
  }
  comps <- list()
  if ("d_tmax" %in% names(units)) {
    b <- .REGEN_STRESS_BOUNDS$d_tmax
    comps$d_tmax <- .regen_norm_up(as.numeric(units$d_tmax), b[["lo"]], b[["hi"]])
  }
  if ("d_vpd" %in% names(units)) {
    b <- .REGEN_STRESS_BOUNDS$d_vpd
    comps$d_vpd <- .regen_norm_up(as.numeric(units$d_vpd), b[["lo"]], b[["hi"]])
  }
  if (!length(comps)) return(rep(NA_real_, nrow(units)))
  mat <- matrix(unlist(comps), ncol = length(comps))
  .regen_row_mean(mat, rep(1, length(comps)))
}

# Sous-score de STRESS HYDRIQUE (0-100, haut = plus sec).
.regen_hydrique <- function(units) {
  comps <- list()
  if ("njstress" %in% names(units)) {
    b <- .REGEN_STRESS_BOUNDS$njstress
    comps$njstress <- .regen_norm_up(as.numeric(units$njstress), b[["lo"]], b[["hi"]])
  }
  if ("istress" %in% names(units)) {
    b <- .REGEN_STRESS_BOUNDS$istress
    comps$istress <- .regen_norm_up(as.numeric(units$istress), b[["lo"]], b[["hi"]])
  }
  if ("rew_min" %in% names(units)) {
    rew <- as.numeric(units$rew_min)
    # REW attendu en fraction 0-1 ; si l'échelle semble 0-100, ramener.
    if (any(rew > 1.5, na.rm = TRUE)) rew <- rew / 100
    comps$rew <- 100 * pmin(1, pmax(0, 1 - rew))   # sec = réserve basse
  }
  if (!length(comps)) return(rep(NA_real_, nrow(units)))
  mat <- matrix(unlist(comps), ncol = length(comps))
  .regen_row_mean(mat, rep(1, length(comps)))
}


#' Regeneration priority index (spec 027 L3)
#'
#' @description
#' Cross the **microclimate exposure** (microclimf engine) and the **soil
#' water stress** (biljouR engine) of each management unit into a single
#' 0-100 **regeneration priority** — high = the most vulnerable parcels, to
#' prioritise for adaptation / regeneration (ADR-014, spec 027 v2.1). This is
#' a head-of-tab score, **not** a radar axis.
#'
#' The function **consumes** the engine output columns already on `units`
#' (the §7 contract): exposure from `sensibilite` (0-100) — or derived from
#' `d_tmax`/`d_vpd` — and water stress from `njstress` / `istress` /
#' `rew_min`. Each volet is a renormalised mean over the columns present, so a
#' partially populated `units` still yields a score.
#'
#' By default the index is **generic** (no species). Passing `species`
#' enables the **optional** per-species tuning (decision §10.1): where the raw
#' summer heat / dryness (`d_tmax` mapped to absolute, or supplied thresholds)
#' exceeds the species tolerance ([regeneration_tolerances()]), the priority is
#' pushed up (an intolerant species on a hot, dry microsite is more urgent).
#'
#' @param units An `sf` carrying the exposure and/or water-stress columns.
#' @param species Optional target-species code ([list_species_classes()]).
#'   `NULL` (default) → generic index, no species tuning.
#' @param weights Optional named numeric `c(exposition=, hydrique=)` to
#'   override the equal weighting of the two volets.
#' @param tolerances Optional override of the tolerance thresholds (a
#'   `data.frame` like [regeneration_tolerances()], or a single-species list
#'   `list(tmax_tol_c=, vpd_tol_kpa=)`).
#' @param flag_breaks Numeric `c(sensible=, priorite=)` thresholds for the
#'   boolean flags (default `c(50, 50)`).
#' @param ... Unused.
#'
#' @return `units` with `indice_priorite_regen` (0-100), `regen_exposition`
#'   and `regen_hydrique` (the two 0-100 sub-scores), `parcelle_sensible` and
#'   `priorite` (logical flags, §7), and `regen_essence` (species used or
#'   `"generique"`). `couverture_pct`, if present, is preserved.
#' @seealso [regeneration_tolerances()], [indicateur_r6_sensibilite()]
#' @examples
#' \dontrun{
#'   units <- regen_sensibilite(units, ...)      # microclimf -> sensibilite
#'   units <- regen_bilan_hydrique(units, ...)   # biljouR   -> njstress, rew_min
#'   units <- indice_priorite_regen(units)
#' }
#' @export
indice_priorite_regen <- function(units, species = NULL, weights = NULL,
                                  tolerances = NULL,
                                  flag_breaks = .REGEN_FLAG_BREAKS, ...) {
  validate_sf(units)
  n <- nrow(units)

  E <- .regen_exposition(units)
  H <- .regen_hydrique(units)
  if (all(is.na(E)) && all(is.na(H))) {
    cli::cli_warn(c(
      "indice_priorite_regen(): no exposure nor water-stress column on {.arg units}.",
      i = "Run the microclimate / water-balance engines first; index set to NA."
    ))
  }

  w <- c(exposition = 1, hydrique = 1)
  if (!is.null(weights)) w[names(weights)] <- as.numeric(weights)
  mat <- cbind(E, H)
  indice <- .regen_row_mean(mat, c(w[["exposition"]], w[["hydrique"]]))

  # Option essence (OFF par défaut) : pousse la priorité vers le haut quand la
  # T°max/VPD brute dépasse la tolérance de l'essence.
  tol <- .regen_resolve_tol(species, tolerances)
  if (!is.null(tol)) {
    penalty <- rep(0, n)
    if ("d_tmax" %in% names(units) && "tmax_moyenne" %in% names(units)) {
      tmax_abs <- as.numeric(units$tmax_moyenne) + as.numeric(units$d_tmax)
      penalty <- pmax(penalty,
        pmin(1, pmax(0, tmax_abs - tol$tmax_tol_c) / .REGEN_TOL_SPAN[["tmax_c"]]))
    }
    if ("vpd_canicule" %in% names(units)) {
      penalty <- pmax(penalty,
        pmin(1, pmax(0, as.numeric(units$vpd_canicule) - tol$vpd_tol_kpa) /
               .REGEN_TOL_SPAN[["vpd_kpa"]]))
    }
    penalty[is.na(penalty)] <- 0
    indice <- indice + (100 - indice) * penalty
  }

  indice <- pmin(100, pmax(0, indice))
  units$regen_exposition <- round(E, 1)
  units$regen_hydrique   <- round(H, 1)
  units$indice_priorite_regen <- round(indice, 1)
  units$parcelle_sensible <- E >= flag_breaks[["sensible"]]
  units$priorite <- indice >= flag_breaks[["priorite"]]
  units$regen_essence <- if (is.null(species) || is.null(tol)) "generique" else species
  units
}
