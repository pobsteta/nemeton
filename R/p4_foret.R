# P4 -- synthese foret, risque de ruine, Pareto et axes (spec 072, M2).

# --- Synthese forêt (sect. 7) ---------------------------------------------------

#' P4 summary at forest scale (spec 072, section 7)
#'
#' @param units Output of [indicateur_p4_rendement_net()].
#' @param capital_field,surface_field Capital (EUR/ha) and area (ha) columns;
#'   without `surface_field`, the area of an `sf` object is used.
#' @param parametres Parameter list; default [p4_parametres()].
#'
#' @return A list: `rendement_net_foret`, `part_capital_ecart_negatif`,
#'   `pertes_attendues_eur_an`, `alea_dominant_foret`, `capital_total_eur`
#'   and `gain_net_eur_an`. Units with a missing P4 are left out of every sum
#'   (with a warning).
#' @examples
#' u <- data.frame(vocation = "production", capital = 14000, gain_valeur = 750,
#'                 surface_ha = 12, R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
#' p4_synthese_foret(indicateur_p4_rendement_net(u))$rendement_net_foret
#' @md
#' @export
p4_synthese_foret <- function(units, capital_field = "capital",
                              surface_field = "surface_ha", parametres = NULL) {
  p <- .p4_params(parametres)
  ha <- .p4_surface(units, surface_field)
  k <- as.numeric(units[[capital_field]])
  ok <- !is.na(units$P4) & !is.na(k) & !is.na(ha)
  if (any(!ok)) {
    cli::cli_warn("{sum(!ok)} unit(s) without P4 left out of the forest summary.",
                  class = "nemeton_p4_ugf_exclue")
  }
  w <- (ha * k)[ok]
  cap_tot <- sum(w)
  net <- units$P4[ok]
  pertes_a <- vapply(.P4_ALEAS, function(a) {
    sum(w * units[[paste0("p4_perte_", a)]][ok], na.rm = TRUE)
  }, numeric(1))
  dom <- if (all(pertes_a == 0)) NA_character_ else .P4_ALEAS[which.max(pertes_a)]
  neg <- units$p4_ecart[ok] < -p$seuil_decision
  list(
    rendement_net_foret = sum(w * net) / cap_tot,
    part_capital_ecart_negatif = sum(w[neg]) / cap_tot,
    pertes_attendues_eur_an = sum(w * units$p4_pertes_attendues[ok]),
    alea_dominant_foret = dom,
    capital_total_eur = cap_tot,
    gain_net_eur_an = sum(w * net)
  )
}

# --- Risque de ruine (sect. 7 bis) ----------------------------------------------

#' Ruin risk at forest scale (spec 072, section 7 bis)
#'
#' Four measures that complete the expected net yield without entering `P4`:
#' loss in case of a major disaster (sum over units for a `systemique` hazard,
#' maximum for a `localisee` one), probability over the horizon, concentration
#' (share of the first unit and effective number of units `1 / sum(part^2)`),
#' and the geometric yield (column `p4_rendement_geometrique` of
#' [indicateur_p4_rendement_net()]).
#'
#' @param units Output of [indicateur_p4_rendement_net()] (needs the `R*_norm`
#'   columns).
#' @param capital_field,surface_field Capital (EUR/ha) and area (ha) columns.
#' @param id_field Optional unit identifier column (default: row position).
#' @param parametres Parameter list; default [p4_parametres()].
#'
#' @return A list: `aleas` (data frame, one row per hazard with
#'   `perte_sinistre_eur`, `part_capital`, `annees_gain_net`,
#'   `probabilite_horizon`, `premiere_ugf`, `part_premiere_ugf`,
#'   `nombre_effectif`, `exposition_depassee`, `ugf_concentrante`),
#'   `gain_net_eur_an`, `capital_total_eur`, `ugf_concentrantes`.
#' @examples
#' u <- data.frame(vocation = "production", capital = 14000, gain_valeur = 750,
#'                 surface_ha = 12, R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
#' p4_ruine_foret(indicateur_p4_rendement_net(u))$aleas$perte_sinistre_eur
#' @md
#' @export
p4_ruine_foret <- function(units, capital_field = "capital",
                           surface_field = "surface_ha", id_field = NULL,
                           parametres = NULL) {
  p <- .p4_params(parametres)
  ha <- .p4_surface(units, surface_field)
  k <- as.numeric(units[[capital_field]])
  ids <- if (is.null(id_field)) as.character(seq_len(nrow(units))) else as.character(units[[id_field]])
  dom <- .p4_dommages(units, p)
  w <- ha * k
  ok <- !is.na(w) & !is.na(units$P4)
  cap_tot <- sum(w[ok])
  gain_net <- sum(w[ok] * units$P4[ok])

  lignes <- lapply(.P4_ALEAS, function(a) {
    x <- p$aleas[[a]]
    s <- w * dom[[a]]
    s[!ok] <- NA_real_
    sinistre <- if (x$portee == "systemique") sum(s, na.rm = TRUE) else max(s, na.rm = TRUE)
    tot <- sum(s, na.rm = TRUE)
    part <- s / tot
    i1 <- which.max(s)
    data.frame(
      alea = a, portee = x$portee,
      perte_sinistre_eur = sinistre,
      part_capital = sinistre / cap_tot,
      annees_gain_net = if (gain_net > 0) sinistre / gain_net else NA_real_,
      probabilite_horizon = 1 - (1 - x$p_max)^p$horizon_ans,
      premiere_ugf = ids[i1], part_premiere_ugf = part[i1],
      nombre_effectif = 1 / sum(part^2, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  al <- do.call(rbind, lignes)
  al$exposition_depassee <- al$part_capital > p$plafond_exposition
  al$ugf_concentrante <- ifelse(al$exposition_depassee, al$premiere_ugf, NA_character_)
  list(aleas = al, gain_net_eur_an = gain_net, capital_total_eur = cap_tot,
       ugf_concentrantes = unique(stats::na.omit(al$ugf_concentrante)))
}

# --- Pareto (sect. 8) -----------------------------------------------------------

#' Pareto status of units on P4 and chosen axes (spec 072, section 8)
#'
#' Calls [identify_pareto_optimal()] with the **raw** `P4` (never `P4_norm` nor
#' the decision) and at most three axes, all maximised. With
#' `perte_sinistre`, builds the yield-risk front instead: `P4` is maximised
#' and the disaster loss minimised.
#'
#' @param units Output of [indicateur_p4_rendement_net()] with the axis columns.
#' @param axes Character vector of up to three columns to cross with `P4`
#'   (e.g. from [p4_selectionner_axes()]).
#' @param perte_sinistre Optional numeric vector (one per unit) of the disaster
#'   loss to minimise, e.g. of the dominant hazard.
#'
#' @return `units` with `p4_pareto_statut` (`domine` / `non_domine`; `NA` when
#'   P4 or an axis is missing) and the attribute `prix_implicite`: P4 points
#'   given up per score point between neighbouring units of the front, on the
#'   first axis.
#' @examples
#' u <- data.frame(P4 = c(.04, .03, .01), B = c(35, 65, 30))
#' p4_pareto(u, "B")$p4_pareto_statut
#' @md
#' @export
p4_pareto <- function(units, axes = NULL, perte_sinistre = NULL) {
  if (length(axes) > 3L) {
    cli::cli_abort("At most three axes can be crossed with P4.", class = "nemeton_p4_trop_d_axes")
  }
  d <- units
  obj <- "P4"
  maxi <- TRUE
  if (!is.null(perte_sinistre)) {
    d$p4_perte_sinistre <- as.numeric(perte_sinistre)
    obj <- c(obj, "p4_perte_sinistre"); maxi <- c(maxi, FALSE)
  }
  if (length(axes)) { obj <- c(obj, axes); maxi <- c(maxi, rep(TRUE, length(axes))) }
  if (length(obj) < 2L) {
    cli::cli_abort("Give at least one axis or {.arg perte_sinistre}.", class = "nemeton_p4_pas_d_axe")
  }
  plein <- stats::complete.cases(as.data.frame(d)[, obj, drop = FALSE])
  statut <- rep(NA_character_, nrow(units))
  if (sum(plein) > 0L) {
    sous <- as.data.frame(d)[plein, , drop = FALSE]
    res <- suppressMessages(identify_pareto_optimal(sous, obj, maxi))
    statut[plein] <- ifelse(res$is_optimal, "non_domine", "domine")
  }
  units$p4_pareto_statut <- statut
  # Prix implicite sur le 1er axe (ou la perte) entre voisines du front
  x2 <- obj[2L]
  fr <- which(statut == "non_domine")
  px <- NULL
  if (length(fr) > 1L) {
    f <- fr[order(as.numeric(d[[x2]])[fr])]
    xv <- as.numeric(d[[x2]])[f]; yv <- as.numeric(d$P4)[f]
    px <- data.frame(de = f[-length(f)], vers = f[-1L],
                     prix_implicite = -(diff(yv)) / diff(xv))
  }
  attr(units, "prix_implicite") <- px
  units
}

.p4_a_factominer <- function() requireNamespace("FactoMineR", quietly = TRUE)

# Axes de repli par vocation : PROVISOIRES, a arreter par Pascal (spec 072 sect. 13).
.P4_AXES_VOCATION <- list(
  production = c("famille_production", "famille_risque", "famille_energie"),
  mixte = c("famille_production", "famille_biodiversite", "famille_risque"),
  protection = c("famille_biodiversite", "famille_eau", "famille_naturalite"),
  accueil = c("famille_social", "famille_paysage", "famille_biodiversite"),
  naturalite = c("famille_naturalite", "famille_biodiversite", "famille_temporel")
)

#' Choose the axes to cross with P4 (spec 072, section 8)
#'
#' PCA of the family scores with `P4` as supplementary variable (FactoMineR,
#' in Suggests): on each of the first `n_axes` dimensions, the family with the
#' highest contribution is kept, preferring the one opposed to P4 on ties
#' (contributions within 5 percent of the best). An imposed axis replaces the
#' least contributing one. Below `effectif_min` units, or when FactoMineR is
#' missing, no factorial analysis is run: the axes of the vocation are
#' returned with a warning.
#'
#' @param units Data frame with `P4` and `famille_*` columns.
#' @param familles Family columns; default all `famille_*` columns.
#' @param n_axes Number of axes (at most 3).
#' @param axe_impose Optional family column imposed by the vocation.
#' @param vocation Vocation used for the fallback axes (default: the most
#'   frequent one in `units`).
#' @param effectif_min Minimum number of complete units (default 30).
#'
#' @return A list: `axes` (character), `methode` (`"acp"` or `"repli_vocation"`),
#'   `contributions` (matrix or `NULL`).
#' @examples
#' u <- data.frame(P4 = c(.04, .03, .01), famille_production = c(1, 2, 3))
#' suppressWarnings(p4_selectionner_axes(u))$methode
#' @md
#' @export
p4_selectionner_axes <- function(units, familles = NULL, n_axes = 3L,
                                 axe_impose = NULL, vocation = NULL,
                                 effectif_min = 30L) {
  n_axes <- min(3L, n_axes)
  d <- as.data.frame(units)
  if (is.null(familles)) familles <- grep("^famille_", names(d), value = TRUE)
  familles <- intersect(familles, names(d))
  if (is.null(vocation) && "vocation" %in% names(d)) {
    vocation <- names(sort(table(d$vocation), decreasing = TRUE))[1L]
  }
  repli <- function(raison) {
    cli::cli_warn("No factorial analysis ({raison}): falling back to the axes of the vocation.",
                  class = "nemeton_p4_repli_axes")
    base <- .P4_AXES_VOCATION[[if (!is.null(vocation) && vocation %in% names(.P4_AXES_VOCATION)) vocation else "production"]]
    ax <- unique(c(axe_impose, base))
    ax <- ax[ax %in% names(d)]
    list(axes = utils::head(ax, n_axes), methode = "repli_vocation", contributions = NULL)
  }
  if (!"P4" %in% names(d)) cli::cli_abort("Column {.field P4} is required.", class = "nemeton_p4_pas_d_axe")
  cc <- stats::complete.cases(d[, c("P4", familles), drop = FALSE])
  if (sum(cc) < effectif_min) return(repli(sprintf("%d complete units, minimum %d", sum(cc), effectif_min)))
  if (!.p4_a_factominer()) return(repli("package FactoMineR not installed"))
  m <- d[cc, c(familles, "P4"), drop = FALSE]
  constantes <- vapply(m, function(x) stats::sd(x) == 0, logical(1))
  m <- m[, !constantes, drop = FALSE]
  fam <- setdiff(names(m), "P4")
  if (!"P4" %in% names(m) || length(fam) < n_axes) return(repli("not enough varying columns"))
  res <- FactoMineR::PCA(m, quanti.sup = which(names(m) == "P4"), ncp = n_axes, graph = FALSE)
  contrib <- res$var$contrib[, seq_len(n_axes), drop = FALSE]
  cor_p4 <- res$quanti.sup$coord[1L, seq_len(n_axes)]
  coord <- res$var$coord[, seq_len(n_axes), drop = FALSE]
  choisis <- character()
  for (j in seq_len(n_axes)) {
    c_j <- contrib[, j]; c_j[rownames(contrib) %in% choisis] <- -Inf
    proches <- which(c_j >= max(c_j) * 0.95)
    if (length(proches) > 1L) {
      oppose <- proches[sign(coord[proches, j]) != sign(cor_p4[j])]
      if (length(oppose)) proches <- oppose
    }
    choisis <- c(choisis, rownames(contrib)[proches[which.max(c_j[proches])]])
  }
  if (!is.null(axe_impose) && !axe_impose %in% choisis) {
    pire <- which.min(vapply(seq_along(choisis), function(j) contrib[choisis[j], j], numeric(1)))
    choisis[pire] <- axe_impose
  }
  list(axes = choisis, methode = "acp", contributions = contrib)
}
