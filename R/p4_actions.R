# P4 -- actions candidates, options, priorisation et contexte (spec 072, extension actions.md, brief B2 a B7).
# Etage 2 du plan d'actions : un moteur de regles deterministe, sans LLM. Les regles sont dans
# inst/extdata/p4_regles_actions.yml (provisoires). Le garde-fou 3 (seuils d'alerte des profils) vit cote
# application : il est expose ici comme un parametre (`garde_profil`).

.P4_DECISIONS <- c("capitaliser", "equilibre", "recolter", "surveiller")
.P4_OPTIONS <- c("conserver", "intervenir", "convertir")
# Invariants du code, non surchargeables par le YAML ni par projet (decision de l'orchestrateur, prudence) :
# plancher NDP de decision, vocations ou une recolte motivee par P4 est possible.
.P4_NDP_PLANCHER <- 3
.P4_VOCATIONS_RECOLTE <- c("production", "mixte")
.P4_TABLEAUX <- c("coupes", "travaux", "aucun")
.P4_LETTRES <- c("P", "C", "B", "W", "A", "F", "L", "T", "R", "S", "E", "N")
.P4_FAMILLE_LETTRE <- c(
  famille_production = "P", famille_carbone = "C", famille_biodiversite = "B", famille_eau = "W",
  famille_air = "A", famille_sol = "F", famille_paysage = "L", famille_temporel = "T",
  famille_risque = "R", famille_social = "S", famille_energie = "E", famille_naturalite = "N"
)

# --- Regles ----------------------------------------------------------------

#' Read and validate the P4 action rules
#'
#' Reads `inst/extdata/p4_regles_actions.yml` (spec 072, `actions.md`): the
#' signal-action matrix, the hazard threshold, the qualitative effects of the
#' options and the bounds of the guard rails. Every value of the shipped file is
#' provisional (`provisoire: true`) and must be reviewed by a forester before
#' use.
#'
#' @param fichier Path of a project rules file, or `NULL` for the shipped one.
#' @param surcharge Optional named list merged recursively over the file.
#'
#' @return A validated named list of rules.
#' @examples
#' r <- p4_regles_actions()
#' r$seuil_alea
#' @md
#' @export
p4_regles_actions <- function(fichier = NULL, surcharge = NULL) {
  if (is.null(fichier)) {
    fichier <- system.file("extdata", "p4_regles_actions.yml", package = "nemeton")
  }
  if (!nzchar(fichier) || !file.exists(fichier)) {
    cli::cli_abort("P4 rules file not found: {.file {fichier}}.",
                   class = "nemeton_p4_regles_invalides")
  }
  r <- yaml::read_yaml(fichier)
  if (!is.null(surcharge)) r <- .p4_fusionner(r, surcharge)
  p4_valider_regles_actions(r)
}

#' Validate a P4 rules list
#'
#' Aborts with class `nemeton_p4_regles_invalides` when a rule is malformed, a
#' decision/Pareto case is not covered exactly once, an action id is repeated,
#' the status quo option is not neutral, a harvest bound is out of range or
#' `coupe_rase` is not `FALSE`.
#'
#' @param r Named list, as read by [p4_regles_actions()].
#' @return `r`, invisibly valid.
#' @examples
#' p4_valider_regles_actions(p4_regles_actions())
#' @md
#' @export
p4_valider_regles_actions <- function(r) {
  err <- character()
  add <- function(...) err <<- c(err, paste0(...))
  num <- function(x, lo, hi, incl_lo = TRUE, incl_hi = TRUE) {
    is.numeric(x) && length(x) == 1L && !is.na(x) &&
      (if (incl_lo) x >= lo else x > lo) && (if (incl_hi) x <= hi else x < hi)
  }
  ids <- character()
  verifier_actions <- function(acts, ou) {
    if (!is.list(acts) || !length(acts)) { add(ou, ": `actions` must be a non-empty list"); return(invisible()) }
    for (a in acts) {
      if (!(is.character(a$id) && length(a$id) == 1L && grepl("^[a-z0-9_]+$", a$id))) {
        add(ou, ": an action has no valid `id` (snake_case ASCII)"); next
      }
      ids <<- c(ids, a$id)
      if (!(is.character(a$tableau) && length(a$tableau) == 1L && a$tableau %in% .P4_TABLEAUX))
        add(ou, ": action `", a$id, "`: `tableau` must be one of coupes, travaux, aucun")
      if (!(is.logical(a$recolte) && length(a$recolte) == 1L && !is.na(a$recolte)))
        add(ou, ": action `", a$id, "`: `recolte` must be TRUE or FALSE")
      else if (isTRUE(a$recolte) != identical(a$tableau, "coupes"))
        add(ou, ": action `", a$id, "`: `recolte` must be TRUE exactly when the tableau is `coupes`")
      if (!(is.character(a$libelle) && length(a$libelle) == 1L && nzchar(a$libelle)))
        add(ou, ": action `", a$id, "`: `libelle` is missing")
    }
  }
  if (!is.list(r)) add("rules must be a list")
  else {
    if (!num(r$version, 0, Inf)) add("`version` must be a number")
    if (!(is.logical(r$provisoire) && length(r$provisoire) == 1L)) add("`provisoire` must be TRUE or FALSE")
    if (!num(r$seuil_alea, 0, 1, TRUE, FALSE)) add("`seuil_alea` must be in [0, 1[")
    if (!(num(r$ndp_min_decision, .P4_NDP_PLANCHER, 4) && r$ndp_min_decision == round(r$ndp_min_decision)))
      add("`ndp_min_decision` must be an integer in 3..4 (the floor of 3 cannot be lowered)")
    if (!(is.character(unlist(r$vocations_recolte)) && length(unlist(r$vocations_recolte)) > 0L &&
          all(unlist(r$vocations_recolte) %in% .P4_VOCATIONS_RECOLTE)))
      add("`vocations_recolte` can only contain production and mixte")
    b <- r$bornes_prelevement
    if (!(is.list(b) && identical(b$coupe_rase, FALSE)))
      add("`bornes_prelevement$coupe_rase` must be FALSE (no clear-cut from P4 rules)")
    if (!num(b$prelevement_max_part_capital, 0, 1, FALSE, FALSE))
      add("`prelevement_max_part_capital` must be in ]0, 1[")
    ax <- r$axes_proteges_vocation
    if (!is.list(ax) || !all(.P4_VOCATIONS %in% names(ax))) add("`axes_proteges_vocation` must cover every vocation")
    else for (v in names(ax)) {
      if (!all(unlist(ax[[v]]) %in% .P4_LETTRES)) add("`axes_proteges_vocation$", v, "`: unknown family letter")
    }
    if (!(is.character(r$axes_proteges_mode) && length(r$axes_proteges_mode) == 1L &&
          r$axes_proteges_mode %in% c("ecarter", "arbitrage")))
      add("`axes_proteges_mode` must be ecarter or arbitrage")

    rd <- r$regles_decision
    if (!is.list(rd) || !length(rd)) add("`regles_decision` must be a non-empty list")
    else {
      couv <- matrix(0L, length(.P4_DECISIONS), 2L, dimnames = list(.P4_DECISIONS, c("domine", "non_domine")))
      for (x in rd) {
        if (!(is.list(x) && is.character(x$id) && length(x$id) == 1L)) { add("a decision rule has no `id`"); next }
        if (!(is.character(x$decision) && length(x$decision) == 1L && x$decision %in% .P4_DECISIONS)) {
          add("rule `", x$id, "`: missing or unknown `decision`"); next
        }
        if (!(is.character(x$pareto) && length(x$pareto) == 1L && x$pareto %in% c("domine", "non_domine", "indifferent"))) {
          add("rule `", x$id, "`: missing or unknown `pareto`"); next
        }
        cols <- if (identical(x$pareto, "indifferent")) c("domine", "non_domine") else x$pareto
        couv[x$decision, cols] <- couv[x$decision, cols] + 1L
        verifier_actions(x$actions, paste0("rule `", x$id, "`"))
      }
      if (any(couv != 1L)) {
        w <- which(couv != 1L, arr.ind = TRUE)
        add("decision/Pareto case(s) not covered exactly once: ",
            paste0(rownames(couv)[w[, 1L]], "/", colnames(couv)[w[, 2L]], collapse = ", "))
      }
    }
    for (nm in c("acquisition", "concentrante")) {
      if (!is.list(r[[nm]])) add("`", nm, "` section is missing") else verifier_actions(r[[nm]]$actions, paste0("`", nm, "`"))
    }
    ra <- r$regles_alea
    if (!is.list(ra) || !setequal(names(ra), .P4_ALEAS)) add("`regles_alea` must cover exactly the four hazards")
    else for (a in names(ra)) verifier_actions(ra[[a]]$actions, paste0("hazard `", a, "`"))
    if (anyDuplicated(ids)) add("action ids must be unique: ", paste(unique(ids[duplicated(ids)]), collapse = ", "))

    o <- r$options
    if (!is.list(o) || !all(.P4_OPTIONS %in% names(o))) add("`options` must define ", paste(.P4_OPTIONS, collapse = ", "))
    else {
      d <- o$declencheurs
      if (!(is.list(d) && all(unlist(d$decisions) %in% .P4_DECISIONS) && is.logical(d$alea) && is.logical(d$concentrante)))
        add("`options$declencheurs` is malformed")
      pmax_ <- b$prelevement_max_part_capital
      ent <- function(e, ou) {
        if (!num(e$delta_score_alea_dominant, 0, 100)) add(ou, ": `delta_score_alea_dominant` must be in [0, 100]")
        if (!(num(e$prelevement_capital, 0, 1) && (!is.numeric(pmax_) || e$prelevement_capital <= pmax_)))
          add(ou, ": `prelevement_capital` must be in [0, prelevement_max_part_capital]")
        if (!num(e$facteur_gain, 0, 2, FALSE, TRUE)) add(ou, ": `facteur_gain` must be in ]0, 2]")
      }
      for (id in .P4_OPTIONS) {
        x <- o[[id]]
        ou <- paste0("option `", id, "`")
        ent(x$entrees, ou)
        ef <- unlist(x$effets)
        if (!(is.list(x$effets) && setequal(names(x$effets), .P4_LETTRES) &&
              all(as.character(ef) %in% c("+", "0", "-"))))
          add(ou, ": `effets` must give +, 0 or - for each of the 12 families")
        if (!(is.character(x$tableau) && x$tableau %in% .P4_TABLEAUX)) add(ou, ": `tableau` is invalid")
        if (!(is.logical(x$recolte) && length(x$recolte) == 1L && !is.na(x$recolte))) add(ou, ": `recolte` must be TRUE or FALSE")
        else {
          pre <- suppressWarnings(as.numeric(x$entrees$prelevement_capital))
          # invariant : recolte <=> prelevement > 0 <=> tableau coupes
          if (length(pre) == 1L && !is.na(pre) && x$recolte != (pre > 0))
            add(ou, ": `recolte` must be TRUE exactly when `prelevement_capital` > 0")
          if (x$recolte != identical(x$tableau, "coupes"))
            add(ou, ": `recolte` must be TRUE exactly when the tableau is `coupes`")
          sr <- x$sans_recolte
          if (isTRUE(x$recolte) && !is.list(sr)) add(ou, ": `sans_recolte` is required for an option that harvests")
          if (is.list(sr)) {
            ent(sr$entrees, paste0(ou, " (sans_recolte)"))
            if (!identical(as.numeric(sr$entrees$prelevement_capital), 0))
              add(ou, " (sans_recolte): no harvest allowed")
            if (!(is.character(sr$tableau) && sr$tableau %in% c("travaux", "aucun")) ||
                !(is.character(sr$libelle) && nzchar(sr$libelle)))
              add(ou, " (sans_recolte): `tableau` must be travaux or aucun, and `libelle` is required")
          }
        }
      }
      e0 <- o$conserver$entrees
      if (!(identical(as.numeric(e0$delta_score_alea_dominant), 0) && identical(as.numeric(e0$prelevement_capital), 0) &&
            identical(as.numeric(e0$facteur_gain), 1)))
        add("option `conserver` must leave the P4 inputs unchanged (status quo)")
    }
  }
  if (!length(err) && is.list(r$options)) {
    for (id in .P4_OPTIONS) r$options[[id]]$effets <- lapply(r$options[[id]]$effets, as.character)
  }
  if (length(err)) {
    cli::cli_abort(c("Invalid P4 action rules.", stats::setNames(err, rep("x", length(err)))),
                   class = "nemeton_p4_regles_invalides")
  }
  r
}

.p4_regles <- function(regles) {
  if (is.null(regles)) p4_regles_actions() else p4_valider_regles_actions(regles)
}

# --- Entrees ---------------------------------------------------------------

.p4_exiger <- function(units, cols) {
  manq <- setdiff(cols, names(units))
  if (length(manq)) {
    cli::cli_abort("Column(s) {.field {manq}} required: pass the output of {.fn indicateur_p4_rendement_net}.",
                   class = "nemeton_p4_entree_invalide")
  }
}

.p4_ids_ugf <- function(units, id_field) {
  ids <- if (is.null(id_field)) as.character(seq_len(nrow(units))) else as.character(units[[id_field]])
  if (anyNA(ids) || anyDuplicated(ids)) {
    cli::cli_abort("Unit identifiers must be present and unique.", class = "nemeton_p4_entree_invalide")
  }
  ids
}

.p4_statut_pareto <- function(pareto, n) {
  if (is.null(pareto)) return(rep(NA_character_, n))
  s <- if (is.data.frame(pareto)) pareto$p4_pareto_statut else as.character(pareto)
  if (length(s) != n || !all(s %in% c("domine", "non_domine", NA))) {
    cli::cli_abort("`pareto` must be the output of {.fn p4_pareto} or one status per unit.",
                   class = "nemeton_p4_entree_invalide")
  }
  s
}

# UGF concentrantes : une ligne par (alea, UGF) pour les aleas en depassement du plafond d'exposition.
.p4_concentrantes <- function(ruine) {
  vide <- data.frame(alea = character(), ugf = character(), stringsAsFactors = FALSE)
  if (is.null(ruine) || is.null(ruine$aleas)) return(vide)
  a <- ruine$aleas
  k <- which(!is.na(a$ugf_concentrante))
  if (!length(k)) return(vide)
  data.frame(alea = a$alea[k], ugf = as.character(a$ugf_concentrante[k]), stringsAsFactors = FALSE)
}

.p4_lettre <- function(axes) {
  vapply(axes, function(a) {
    if (a %in% names(.P4_FAMILLE_LETTRE)) return(unname(.P4_FAMILLE_LETTRE[a]))
    if (a %in% .P4_LETTRES) return(a)
    cli::cli_abort("Axis {.val {a}} is not a family column ({.val {names(.P4_FAMILLE_LETTRE)}}) nor a family letter.",
                   class = "nemeton_p4_entree_invalide")
  }, character(1), USE.NAMES = FALSE)
}

.p4_alea_perte <- function(ugf_p4, a) {
  cl <- paste0("p4_perte_", a)
  if (cl %in% names(ugf_p4)) as.numeric(ugf_p4[[cl]]) else rep(NA_real_, nrow(ugf_p4))
}

.p4_a_garde_profil <- function(garde_profil) {
  if (!is.null(garde_profil) && !is.function(garde_profil)) {
    cli::cli_abort("`garde_profil` must be NULL or a function returning one logical per row (TRUE = keep).",
                   class = "nemeton_p4_entree_invalide")
  }
}

.p4_appliquer_profil <- function(df, garde_profil) {
  if (is.null(garde_profil) || !nrow(df)) return(rep(TRUE, nrow(df)))
  k <- garde_profil(df)
  if (!(is.logical(k) && length(k) == nrow(df) && !anyNA(k))) {
    cli::cli_abort("`garde_profil` must return one non-missing logical per row.",
                   class = "nemeton_p4_entree_invalide")
  }
  k
}

# --- Actions candidates ----------------------------------------------------

#' Candidate actions per unit from the P4 diagnosis (spec 072, `actions.md`)
#'
#' Stage 2 of the P4-driven action plan, deterministic and LLM-free. For each
#' unit, applies the rules of [p4_regles_actions()]:
#' * **signal only** (P4 below the minimum NDP, or `p4_signal_seulement`): a
#'   single data-acquisition action, nothing else (guard 4);
#' * otherwise the rule of the P4 decision and Pareto status, one rule per
#'   hazard whose expected loss exceeds `seuil_alea`, and the exposure
#'   reduction rule for a concentrating unit of a hazard above the exposure cap.
#'
#' Guards (brief B6): **1 vocation** (no harvest outside the vocations of
#' `vocations_recolte`), **4 precision**, **6 traceability** (each action keeps
#' its rule, the P4 values used and the versions of parameters and rules).
#' Guard 2 (protected axes) and guard 5 (extent bounds) act on the options, see
#' [p4_options()]. Guard 3 (alert thresholds of the actor profiles) lives in the
#' application: it is exposed as `garde_profil`. Removed candidates are not
#' lost: they are kept, with the guard that removed them, in the attribute
#' `ecartees`.
#'
#' @param ugf_p4 Output of [indicateur_p4_rendement_net()].
#' @param pareto Output of [p4_pareto()], or one status (`domine` /
#'   `non_domine` / `NA`) per unit. An unknown status is treated as
#'   `non_domine` (no automatic harvest).
#' @param ruine Output of [p4_ruine_foret()] (same `id_field` convention), or
#'   `NULL`.
#' @param regles Rules, default [p4_regles_actions()].
#' @param parametres P4 parameters, default [p4_parametres()] (only their
#'   version is recorded).
#' @param id_field Unit identifier column (default: row position, as in
#'   [p4_ruine_foret()]).
#' @param vocation_field Vocation column.
#' @param garde_profil `NULL`, or a function receiving the candidate table and
#'   returning one logical per row (`TRUE` = keep): guard 3, supplied by the
#'   application from the thresholds of the actor profiles.
#'
#' @return A data frame, one row per unit and action: `ugf`, `action_id`,
#'   `regle`, `origine` (`decision`, `alea`, `concentrante`, `signal`), `alea`,
#'   `tableau` (`coupes`, `travaux`, `aucun`), `recolte`, `libelle`, the P4
#'   values used (`p4_rendement_net`, `p4_ecart`, `p4_decision`, `p4_ndp`,
#'   `p4_signal_seulement`, `pareto_statut`, `perte_alea`), `version_parametres`,
#'   `version_regles`, `regles_provisoires` and `prelevement_max_part_capital`
#'   (the bound of the rules file carried by every harvesting action, guard 5).
#'   Attribute `ecartees`: the
#'   removed candidates with their `garde`.
#' @examples
#' u <- data.frame(vocation = "production", capital = 14000, gain_valeur = 750,
#'                 surface_ha = 12, R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
#' u <- suppressMessages(indicateur_p4_rendement_net(u, ndp = 3))
#' p4_actions_candidates(u)[, c("action_id", "regle", "tableau")]
#' @md
#' @export
p4_actions_candidates <- function(ugf_p4, pareto = NULL, ruine = NULL, regles = NULL,
                                  parametres = NULL, id_field = NULL,
                                  vocation_field = "vocation", garde_profil = NULL) {
  r <- .p4_regles(regles)
  p <- .p4_params(parametres)
  .p4_a_garde_profil(garde_profil)
  .p4_exiger(ugf_p4, c("P4", "p4_ecart", "p4_decision", "p4_signal_seulement", "p4_ndp", vocation_field))
  n <- nrow(ugf_p4)
  ids <- .p4_ids_ugf(ugf_p4, id_field)
  par <- .p4_statut_pareto(pareto, n)
  conc <- .p4_concentrantes(ruine)
  voc <- as.character(ugf_p4[[vocation_field]])
  ndp_min <- max(.P4_NDP_PLANCHER, r$ndp_min_decision)

  lignes <- list()
  absents <- character()
  for (i in seq_len(n)) {
    if (is.na(ugf_p4$p4_decision[i])) {
      absents <- c(absents, ids[i])
      next
    }
    sig <- isTRUE(ugf_p4$p4_signal_seulement[i]) || is.na(ugf_p4$p4_ndp[i]) || ugf_p4$p4_ndp[i] < ndp_min
    liste <- list()
    emet <- function(acts, regle, origine, alea = NA_character_, perte = NA_real_) {
      for (a in acts) {
        liste[[length(liste) + 1L]] <<- data.frame(
          ugf = ids[i], action_id = a$id, regle = regle, origine = origine, alea = alea,
          tableau = a$tableau, recolte = isTRUE(a$recolte), libelle = a$libelle,
          p4_rendement_net = ugf_p4$P4[i], p4_ecart = ugf_p4$p4_ecart[i],
          p4_decision = ugf_p4$p4_decision[i], p4_ndp = ugf_p4$p4_ndp[i],
          p4_signal_seulement = isTRUE(ugf_p4$p4_signal_seulement[i]),
          pareto_statut = par[i], perte_alea = perte, stringsAsFactors = FALSE
        )
      }
    }
    if (sig) {
      emet(r$acquisition$actions, r$acquisition$id, "signal")
    } else {
      statut <- if (identical(par[i], "domine")) "domine" else "non_domine"
      for (x in r$regles_decision) {
        if (identical(x$decision, ugf_p4$p4_decision[i]) && x$pareto %in% c("indifferent", statut))
          emet(x$actions, x$id, "decision")
      }
      for (a in .P4_ALEAS) {
        perte <- .p4_alea_perte(ugf_p4, a)[i]
        if (!is.na(perte) && perte > r$seuil_alea)
          emet(r$regles_alea[[a]]$actions, r$regles_alea[[a]]$id, "alea", a, perte)
      }
      al_c <- conc$alea[conc$ugf == ids[i]]
      if (length(al_c)) emet(r$concentrante$actions, r$concentrante$id, "concentrante", paste(al_c, collapse = ","))
    }
    if (length(liste)) lignes[[length(lignes) + 1L]] <- do.call(rbind, liste)
  }
  tout <- if (length(lignes)) do.call(rbind, lignes) else .p4_candidates_vide()[, setdiff(names(.p4_candidates_vide()), "garde")]
  # B6.5 : une action de coupe porte la borne de prelevement du fichier de regles
  tout$prelevement_max_part_capital <- ifelse(tout$recolte, r$bornes_prelevement$prelevement_max_part_capital, NA_real_)
  tout$version_parametres <- rep(p$version, nrow(tout))
  tout$version_regles <- rep(r$version, nrow(tout))
  tout$regles_provisoires <- rep(isTRUE(r$provisoire) || isTRUE(p$provisoire), nrow(tout))

  # Gardes : vocation (1), precision (4), profil (3, fourni par l'application)
  voc_ligne <- voc[match(tout$ugf, ids)]
  g <- rep(NA_character_, nrow(tout))
  g[is.na(g) & tout$recolte & !(voc_ligne %in% intersect(unlist(r$vocations_recolte), .P4_VOCATIONS_RECOLTE))] <- "vocation"
  g[is.na(g) & tout$origine != "signal" & tout$recolte & !is.na(tout$p4_ndp) & tout$p4_ndp < ndp_min] <- "precision"
  reste <- is.na(g)
  g[reste] <- ifelse(.p4_appliquer_profil(tout[reste, , drop = FALSE], garde_profil), NA_character_, "profil")
  tout$garde <- g
  ecart <- !is.na(tout$garde)
  res <- tout[!ecart, setdiff(names(tout), "garde"), drop = FALSE]
  rownames(res) <- NULL
  ec <- tout[ecart, , drop = FALSE]
  for (u in absents) ec <- rbind(ec, .p4_ligne_ecartee(u, "p4_absent")[, names(ec)])
  rownames(ec) <- NULL
  attr(res, "ecartees") <- ec
  res
}

.p4_ligne_ecartee <- function(id, garde) {
  d <- .p4_candidates_vide()
  d[1L, "ugf"] <- id
  d$garde <- garde
  d$prelevement_max_part_capital <- NA_real_
  d$version_parametres <- NA_real_; d$version_regles <- NA_real_; d$regles_provisoires <- NA
  d
}

.p4_candidates_vide <- function() {
  data.frame(ugf = character(), action_id = character(), regle = character(), origine = character(),
             alea = character(), tableau = character(), recolte = logical(), libelle = character(),
             p4_rendement_net = numeric(), p4_ecart = numeric(), p4_decision = character(),
             p4_ndp = numeric(), p4_signal_seulement = logical(), pareto_statut = character(),
             perte_alea = numeric(), garde = character(), stringsAsFactors = FALSE)
}

# --- Options ---------------------------------------------------------------

# i est dominee par j : j au moins aussi bon partout et strictement meilleur quelque part.
.p4_dominees <- function(m) {
  k <- nrow(m)
  dom <- matrix(FALSE, k, k)
  for (i in seq_len(k)) for (j in seq_len(k)) {
    if (i != j && all(m[j, ] >= m[i, ] - 1e-12) && any(m[j, ] > m[i, ] + 1e-12)) dom[i, j] <- TRUE
  }
  dom
}

#' Costed options per unit: keep, intervene, convert (spec 072, `actions.md`)
#'
#' For each eligible unit (not signal only, and either under the decision
#' threshold, or marked by a hazard above `seuil_alea`, or concentrating),
#' builds at most three options. Each option carries `p4_net_apres`,
#' **recomputed by [indicateur_p4_rendement_net()]** on inputs modified by the
#' rules (points added to the score of the dominant hazard, share of the
#' capital harvested, gain factor), its qualitative effects `+`, `0`, `-` on the
#' axes, and the mark of dominated options (at least as good on `p4_net_apres`
#' and on every axis, strictly better on one).
#'
#' Guards, which are invariants of the code that no rules file can lower:
#' **1 vocation** (outside production and mixed, or for a unit to capitalise,
#' any option that harvests falls back on its `sans_recolte` variant, so that
#' `recolte` holds exactly when `prelevement_capital > 0` and the tableau is
#' `coupes`) and **4 precision** (NDP floor of 3), **5 extent**
#' (the harvest is capped by `prelevement_max_part_capital`, never a clear-cut),
#' **2 protected axes** (an option rated `-` on an axis protected by the
#' vocation or by `axes_proteges_profil` is `ecartee_axe_protege`, or, with
#' `axes_proteges_mode: arbitrage`, kept with the axes listed in
#' `arbitrage_axes`), **3** through `garde_profil`. The option `conserver` is
#' the reference status quo: it is always presented, and marked `dominee = TRUE`
#' when it is dominated, but never discarded. The effects are expert
#' hypotheses, never measures. The gain on the dominant hazard is added to every
#' score the hazard reads (`R3_norm` and `R5_norm` for the drought and health
#' hazard), so it raises the minimum; it has no effect on a unit with
#' `perte_saisie` (its entered loss is kept) or on a score already at 100.
#' Lowering the capital raises the gross yield without counting the income of
#' the harvest (model hypothesis, to be reviewed).
#'
#' @param ugf_p4 Output of [indicateur_p4_rendement_net()] (with its input
#'   columns: vocation, capital, gain, `R*_norm`, area).
#' @param regles Rules, default [p4_regles_actions()].
#' @param ruine Output of [p4_ruine_foret()], or `NULL`.
#' @param axes Columns of `ugf_p4` (family columns such as
#'   `famille_biodiversite`, or family letters) whose effects are reported.
#' @param axes_proteges_profil Family letters protected by the actor profile
#'   (added to those of the vocation).
#' @param parametres P4 parameters, default [p4_parametres()].
#' @param id_field,vocation_field,capital_field,gain_field,perte_saisie_field
#'   Column names, as in [indicateur_p4_rendement_net()].
#' @param garde_profil `NULL` or a function of the option table returning one
#'   logical per row (`TRUE` = keep); guard 3, supplied by the application.
#'
#' @return A data frame, one row per unit and option: `ugf`, `option`,
#'   `libelle`, `tableau`, `recolte`, `delta_score`, `prelevement_capital`,
#'   `facteur_gain`, `p4_net_avant`, `p4_net_apres`, `delta_p4`,
#'   `p4_ecart_apres`, `effet_<lettre>` for each axis, `cout_indicatif_eur_ha`
#'   (`NA`: no cost parameter), `dominee`, `dominee_par`, `statut`
#'   (`retenable`, `dominee`, `ecartee_axe_protege`, `ecartee_profil`),
#'   `arbitrage_axes`, `garde`, `version_parametres`, `version_regles` and
#'   `regles_provisoires`.
#' @examples
#' u <- data.frame(vocation = "production", capital = 11000, gain_valeur = 380,
#'                 surface_ha = 6, R1_norm = 75, R2_norm = 30, R3_norm = 20, R4_norm = 85,
#'                 B = 30, N = 20)
#' u <- suppressMessages(indicateur_p4_rendement_net(u, ndp = 3))
#' p4_options(u)[, c("option", "p4_net_apres", "statut")]
#' @md
#' @export
p4_options <- function(ugf_p4, regles = NULL, ruine = NULL, axes = c("B", "N"),
                       axes_proteges_profil = NULL, parametres = NULL, id_field = NULL,
                       vocation_field = "vocation", capital_field = "capital",
                       gain_field = "gain_valeur", perte_saisie_field = "perte_saisie",
                       garde_profil = NULL) {
  r <- .p4_regles(regles)
  p <- .p4_params(parametres)
  .p4_a_garde_profil(garde_profil)
  .p4_exiger(ugf_p4, c("P4", "p4_decision", "p4_signal_seulement", "p4_ndp", "p4_alea_dominant",
                       vocation_field, capital_field, gain_field))
  n <- nrow(ugf_p4)
  ids <- .p4_ids_ugf(ugf_p4, id_field)
  conc <- .p4_concentrantes(ruine)
  lettres <- .p4_lettre(axes)
  voc <- as.character(ugf_p4[[vocation_field]])
  d <- r$options$declencheurs
  alea_marque <- Reduce(`|`, lapply(.P4_ALEAS, function(a) {
    x <- .p4_alea_perte(ugf_p4, a); !is.na(x) & x > r$seuil_alea
  }))
  eligible <- !is.na(ugf_p4$p4_decision) & !is.na(ugf_p4$P4) & !is.na(ugf_p4$p4_ndp) &
    !ugf_p4$p4_signal_seulement & ugf_p4$p4_ndp >= max(.P4_NDP_PLANCHER, r$ndp_min_decision) &
    (ugf_p4$p4_decision %in% unlist(d$decisions) | (isTRUE(d$alea) & alea_marque) |
       (isTRUE(d$concentrante) & ids %in% conc$ugf))
  idx <- which(eligible)
  if (!length(idx)) return(.p4_options_vide(lettres))

  # Invariants : hors production et mixte, ou pour une UGF a capitaliser (regle D1), toute option qui
  # preleve retombe sur sa variante sans recolte.
  hors_voc <- !(voc[idx] %in% .P4_VOCATIONS_RECOLTE) | !(voc[idx] %in% intersect(unlist(r$vocations_recolte), .P4_VOCATIONS_RECOLTE))
  capit <- ugf_p4$p4_decision[idx] == "capitaliser"
  sans_recolte <- hors_voc | capit
  pmax_ <- r$bornes_prelevement$prelevement_max_part_capital
  blocs <- lapply(.P4_OPTIONS, function(o) {
    x <- r$options[[o]]
    preleve <- x$entrees$prelevement_capital > 0
    repli <- preleve & sans_recolte                 # variante sans recolte
    ent <- lapply(seq_along(idx), function(k) {
      e <- if (repli[k]) x$sans_recolte$entrees else x$entrees
      e$prelevement_capital <- min(e$prelevement_capital, pmax_)  # garde 5 : ampleur
      e
    })
    delta <- vapply(ent, function(e) as.numeric(e$delta_score_alea_dominant), numeric(1))
    pre <- vapply(ent, function(e) as.numeric(e$prelevement_capital), numeric(1))
    fg <- vapply(ent, function(e) as.numeric(e$facteur_gain), numeric(1))
    # Entrees de P4 modifiees, puis recalcul par l'indicateur lui-meme
    fr <- data.frame(row.names = seq_along(idx))
    fr[[vocation_field]] <- voc[idx]
    fr[[capital_field]] <- as.numeric(ugf_p4[[capital_field]][idx]) * (1 - pre)
    fr[[gain_field]] <- as.numeric(ugf_p4[[gain_field]][idx]) * fg
    fr$surface_ha <- if ("surface_ha" %in% names(ugf_p4)) as.numeric(ugf_p4$surface_ha[idx]) else NA_real_
    if (perte_saisie_field %in% names(ugf_p4)) fr[[perte_saisie_field]] <- ugf_p4[[perte_saisie_field]][idx]
    for (cl in grep("^R[0-9]+_norm$", names(ugf_p4), value = TRUE)) fr[[cl]] <- as.numeric(ugf_p4[[cl]][idx])
    dom <- ugf_p4$p4_alea_dominant[idx]
    for (a in .P4_ALEAS) {
      k <- which(dom == a)
      for (cd in unlist(p$aleas[[a]]$score)) {
        cl <- paste0(cd, "_norm")
        if (length(k) && cl %in% names(fr)) fr[[cl]][k] <- pmin(100, fr[[cl]][k] + delta[k])
      }
    }
    fr$ndp <- as.numeric(ugf_p4$p4_ndp[idx])
    apres <- suppressMessages(indicateur_p4_rendement_net(
      fr, vocation_field = vocation_field, capital_field = capital_field, gain_field = gain_field,
      perte_saisie_field = perte_saisie_field, parametres = p))
    # recolte <=> prelevement > 0 <=> tableau coupes (invariant du code)
    rec <- pre > 0
    tab <- ifelse(rec, "coupes", ifelse(repli, x$sans_recolte$tableau, x$tableau))
    lib <- if (preleve) ifelse(repli, x$sans_recolte$libelle, x$libelle) else rep(x$libelle, length(idx))
    gd <- ifelse(repli, ifelse(capit, "capitaliser_sans_recolte", "vocation_sans_recolte"), NA_character_)
    b <- data.frame(
      ugf = ids[idx], option = o, libelle = lib, tableau = tab, recolte = rec,
      delta_score = delta, prelevement_capital = pre, facteur_gain = fg,
      p4_net_avant = as.numeric(ugf_p4$P4[idx]), p4_net_apres = apres$P4,
      stringsAsFactors = FALSE)
    b$delta_p4 <- b$p4_net_apres - b$p4_net_avant
    b$p4_ecart_apres <- apres$p4_ecart
    for (l in lettres) b[[paste0("effet_", l)]] <- x$effets[[l]]
    b$garde <- gd
    b
  })
  res <- do.call(rbind, blocs)
  res$cout_indicatif_eur_ha <- NA_real_
  res <- res[order(match(res$ugf, ids), match(res$option, .P4_OPTIONS)), , drop = FALSE]

  # Garde 2 : axes proteges ; puis dominance parmi les options restantes ; garde 3.
  res$statut <- "retenable"
  res$arbitrage_axes <- ""
  res$dominee <- FALSE
  res$dominee_par <- ""
  for (u in unique(res$ugf)) {
    k <- which(res$ugf == u)
    v <- voc[match(u, ids)]
    prot <- unique(c(unlist(r$axes_proteges_vocation[[v]]), axes_proteges_profil))
    eff <- lapply(res$option[k], function(o) unlist(r$options[[o]]$effets))
    neg <- vapply(eff, function(e) paste(names(e)[e == "-" & names(e) %in% prot], collapse = ","), character(1))
    if (identical(r$axes_proteges_mode, "ecarter")) {
      res$statut[k[nzchar(neg)]] <- "ecartee_axe_protege"
    } else {
      res$arbitrage_axes[k] <- neg
    }
    sel <- res$statut[k] == "retenable"
    ok <- k[sel]
    if (length(ok) > 1L) {
      ef <- matrix(unlist(lapply(eff[sel], function(e) unname(c(`+` = 1, `0` = 0, `-` = -1)[e[lettres]]))),
                   nrow = length(ok), byrow = TRUE)
      dm <- .p4_dominees(cbind(res$p4_net_apres[ok], ef))
      for (a in seq_along(ok)) {
        par_qui <- res$option[ok][dm[a, ]]
        if (length(par_qui)) {
          # le statu quo reste toujours presente (reference) : marque dominee, jamais ecarte
          res$dominee[ok[a]] <- TRUE
          if (res$option[ok[a]] != "conserver") res$statut[ok[a]] <- "dominee"
          res$dominee_par[ok[a]] <- paste(par_qui, collapse = ",")
        }
      }
    }
  }
  kp <- .p4_appliquer_profil(res, garde_profil)
  res$statut[!kp & res$statut == "retenable" & res$option != "conserver"] <- "ecartee_profil"
  res$version_parametres <- p$version
  res$version_regles <- r$version
  res$regles_provisoires <- isTRUE(r$provisoire) || isTRUE(p$provisoire)
  rownames(res) <- NULL
  res
}

.p4_options_vide <- function(lettres) {
  d <- data.frame(ugf = character(), option = character(), libelle = character(), tableau = character(),
                  recolte = logical(), delta_score = numeric(), prelevement_capital = numeric(),
                  facteur_gain = numeric(), p4_net_avant = numeric(), p4_net_apres = numeric(),
                  delta_p4 = numeric(), p4_ecart_apres = numeric(), stringsAsFactors = FALSE)
  for (l in lettres) d[[paste0("effet_", l)]] <- character()
  d$garde <- character(); d$cout_indicatif_eur_ha <- numeric(); d$statut <- character()
  d$arbitrage_axes <- character(); d$dominee <- logical(); d$dominee_par <- character()
  d$version_parametres <- numeric(); d$version_regles <- numeric(); d$regles_provisoires <- logical()
  d
}

# --- Priorisation ----------------------------------------------------------

.p4_confiance_ndp <- function(ndp) {
  vapply(ndp, function(x) {
    if (is.na(x) || !x %in% 0:4) NA_real_ else get_ndp_confidence(x)
  }, numeric(1))
}

#' Deterministic priority of the units (spec 072, `actions.md`, brief B5)
#'
#' ```
#' manque_a_gagner = max(0, -ecart - seuil) * capital * surface      EUR/yr
#' priorite        = manque_a_gagner * confiance_ndp
#' ```
#'
#' `seuil` is `seuil_decision` of the P4 parameters and `confiance_ndp` the
#' Fibonacci confidence of the NDP ([get_ndp_confidence()]). Units are ranked by
#' decreasing `priorite`; at equal priority a dominated unit comes first. Three
#' lists are returned apart, because they answer different questions: the main
#' ranking (decision-grade units only, `rang` from 1), the concentrating
#' units of a hazard above the exposure cap (by decreasing disaster loss), and
#' the data acquisitions of the signal-only units (first those whose P4
#' decision is to harvest, since they condition a harvest decision). The
#' ranking is not meant to be changed by a language model.
#'
#' @param ugf_p4 Output of [indicateur_p4_rendement_net()].
#' @param pareto Output of [p4_pareto()] or one status per unit.
#' @param ruine Output of [p4_ruine_foret()], or `NULL`.
#' @param parametres P4 parameters, default [p4_parametres()].
#' @param id_field,capital_field,surface_field Column names (default: row
#'   position, `capital`, `surface_ha`; the area of an `sf` object is used when
#'   `surface_field` is absent).
#'
#' @return A list: `ugf` (all units: `manque_a_gagner_eur_an`, `confiance_ndp`,
#'   `priorite`, `rang`, `dominee`, `signal_seulement`, `concentrante`),
#'   `principale` (ranked units), `concentrantes` and `acquisitions`.
#' @examples
#' u <- data.frame(vocation = "production", capital = 11000, gain_valeur = 380,
#'                 surface_ha = 6, R1_norm = 75, R2_norm = 30, R3_norm = 20, R4_norm = 85)
#' u <- suppressMessages(indicateur_p4_rendement_net(u, ndp = 3))
#' p4_prioriser(u)$principale[, c("ugf", "manque_a_gagner_eur_an", "rang")]
#' @md
#' @export
p4_prioriser <- function(ugf_p4, pareto = NULL, ruine = NULL, parametres = NULL,
                         id_field = NULL, capital_field = "capital", surface_field = "surface_ha") {
  p <- .p4_params(parametres)
  .p4_exiger(ugf_p4, c("p4_ecart", "p4_decision", "p4_signal_seulement", "p4_ndp", capital_field))
  n <- nrow(ugf_p4)
  ids <- .p4_ids_ugf(ugf_p4, id_field)
  par <- .p4_statut_pareto(pareto, n)
  ha <- .p4_surface(ugf_p4, surface_field)
  k <- as.numeric(ugf_p4[[capital_field]])
  conc <- .p4_concentrantes(ruine)
  manque <- pmax(0, -ugf_p4$p4_ecart - p$seuil_decision) * k * ha
  conf <- .p4_confiance_ndp(ugf_p4$p4_ndp)
  prio <- manque * conf
  dominee <- par %in% "domine"
  signal <- ugf_p4$p4_signal_seulement %in% TRUE
  d <- data.frame(
    ugf = ids, p4_decision = ugf_p4$p4_decision, pareto_statut = par, dominee = dominee,
    p4_ecart = ugf_p4$p4_ecart, capital_total_eur = k * ha,
    manque_a_gagner_eur_an = manque, confiance_ndp = conf, priorite = prio,
    signal_seulement = signal, concentrante = ids %in% conc$ugf, stringsAsFactors = FALSE)
  eligible <- !signal & !is.na(prio) & prio > 0
  d$rang <- NA_integer_
  o <- order(-prio[eligible], !dominee[eligible], seq_len(n)[eligible])
  d$rang[which(eligible)[o]] <- seq_along(o)
  principale <- d[!is.na(d$rang), , drop = FALSE]
  principale <- principale[order(principale$rang), , drop = FALSE]

  ca <- data.frame(rang = integer(), alea = character(), ugf = character(), perte_sinistre_eur = numeric(),
                   part_capital = numeric(), part_premiere_ugf = numeric(), stringsAsFactors = FALSE)
  if (!is.null(ruine) && !is.null(ruine$aleas) && nrow(conc)) {
    a <- ruine$aleas[!is.na(ruine$aleas$ugf_concentrante), , drop = FALSE]
    a <- a[order(-a$perte_sinistre_eur), , drop = FALSE]
    ca <- data.frame(rang = seq_len(nrow(a)), alea = a$alea, ugf = as.character(a$ugf_concentrante),
                     perte_sinistre_eur = a$perte_sinistre_eur, part_capital = a$part_capital,
                     part_premiere_ugf = a$part_premiere_ugf, stringsAsFactors = FALSE)
  }
  acq <- d[signal & !is.na(d$p4_decision), c("ugf", "p4_decision", "manque_a_gagner_eur_an"), drop = FALSE]
  acq$conditionne_coupe <- acq$p4_decision %in% "recolter"
  acq <- acq[order(!acq$conditionne_coupe, -ifelse(is.na(acq$manque_a_gagner_eur_an), 0, acq$manque_a_gagner_eur_an)), , drop = FALSE]
  acq$rang <- seq_len(nrow(acq))
  rownames(d) <- rownames(principale) <- rownames(acq) <- NULL
  list(ugf = d, principale = principale, concentrantes = ca, acquisitions = acq)
}

# --- Contexte structure pour l'etage 3 (LLM, cote application) ---------------

.p4_id_sur <- function(i) paste0("ugf_", i)

# Unites qui dominent chaque unite sur P4 et les colonnes d'axes (toutes maximisees).
.p4_dominateurs <- function(ugf_p4, cols, ids) {
  cols <- intersect(c("P4", cols), names(ugf_p4))
  vide <- rep(list(character()), nrow(ugf_p4))
  if (length(cols) < 2L) return(vide)
  m <- as.matrix(as.data.frame(ugf_p4)[, cols, drop = FALSE])
  storage.mode(m) <- "double"
  lapply(seq_len(nrow(m)), function(i) {
    if (anyNA(m[i, ])) return(character())
    ids[vapply(seq_len(nrow(m)), function(j) {
      j != i && !anyNA(m[j, ]) && all(m[j, ] >= m[i, ] - 1e-12) && any(m[j, ] > m[i, ] + 1e-12)
    }, logical(1))]
  })
}

#' Structured context for the language-model stage (spec 072, brief B7)
#'
#' Builds, per unit, the object the application hands to the LLM: the P4
#' diagnosis, the Pareto status and its dominating units, the priority, the
#' candidate action identifiers and the non-dominated options with their
#' `p4_net_apres` and qualitative effects. **No free text coming from external
#' data**: only numbers, fixed identifiers of the rules, the closed lists of
#' vocations, decisions and hazards, and the unit identifier, which is replaced
#' by `ugf_<n>` (`n` = row position) **always**, also in `dominee_par`; the
#' true identifiers are returned apart in the attribute `correspondance` (data
#' frame `ugf_contexte`, `ugf`). Missing pieces
#' (`priorisation`, `candidates`, `options`) are computed with the functions of
#' the same family.
#'
#' @inheritParams p4_options
#' @param pareto Output of [p4_pareto()] or one status per unit.
#' @param id_field Unit identifier column (default: row position). Never sent
#'   to the LLM: units are renamed `ugf_<n>`.
#' @param vocation_field Vocation column.
#' @param priorisation,candidates,options Outputs of [p4_prioriser()],
#'   [p4_actions_candidates()] and [p4_options()]; computed when `NULL`.
#' @param garde_profil Passed to [p4_actions_candidates()] and [p4_options()]
#'   when those are computed here.
#'
#' @return An unnamed list with one element per unit (`ugf`, `vocation`, `p4`,
#'   `pareto`, `priorite`, `concentrante`, `actions`, `options`, `regles`),
#'   with the attribute `correspondance`.
#' @examples
#' u <- data.frame(vocation = "production", capital = 11000, gain_valeur = 380,
#'                 surface_ha = 6, R1_norm = 75, R2_norm = 30, R3_norm = 20, R4_norm = 85,
#'                 B = 30, N = 20)
#' u <- suppressMessages(indicateur_p4_rendement_net(u, ndp = 3))
#' str(p4_contexte_llm(u)[[1]]$p4)
#' @md
#' @export
p4_contexte_llm <- function(ugf_p4, pareto = NULL, ruine = NULL, regles = NULL, axes = c("B", "N"),
                            axes_proteges_profil = NULL, parametres = NULL, id_field = NULL,
                            vocation_field = "vocation", priorisation = NULL, candidates = NULL,
                            options = NULL, garde_profil = NULL) {
  r <- .p4_regles(regles)
  p <- .p4_params(parametres)
  n <- nrow(ugf_p4)
  ids <- .p4_ids_ugf(ugf_p4, id_field)
  par <- .p4_statut_pareto(pareto, n)
  lettres <- .p4_lettre(axes)
  if (is.null(priorisation)) priorisation <- p4_prioriser(ugf_p4, par, ruine, p, id_field)
  if (is.null(candidates)) {
    candidates <- p4_actions_candidates(ugf_p4, par, ruine, r, p, id_field, vocation_field, garde_profil)
  }
  if (is.null(options)) {
    options <- p4_options(ugf_p4, r, ruine, axes, axes_proteges_profil, p, id_field, vocation_field,
                          garde_profil = garde_profil)
  }
  conc <- .p4_concentrantes(ruine)
  domine_par <- .p4_dominateurs(ugf_p4, intersect(axes, names(ugf_p4)), ids)
  num <- function(x) if (is.null(x) || is.na(x)) NA_real_ else as.numeric(x)
  num_ou_na <- function(nm) if (nm %in% names(ugf_p4)) as.numeric(ugf_p4[[nm]]) else rep(NA_real_, n)
  brut <- num_ou_na("p4_rendement_brut"); pertes <- num_ou_na("p4_pertes_attendues")
  taux <- num_ou_na("p4_taux_exige")
  voc <- as.character(ugf_p4[[vocation_field]])
  res <- lapply(seq_len(n), function(i) {
    pr <- priorisation$ugf[priorisation$ugf$ugf == ids[i], , drop = FALSE]
    op <- options[options$ugf == ids[i] & options$statut == "retenable", , drop = FALSE]
    ac <- candidates[candidates$ugf == ids[i], , drop = FALSE]
    list(
      ugf = .p4_id_sur(i),
      vocation = if (voc[i] %in% names(p$vocations)) voc[i] else NA_character_,
      p4 = list(rendement_brut = brut[i], pertes_attendues = pertes[i], rendement_net = num(ugf_p4$P4[i]),
                taux_exige = taux[i], ecart = num(ugf_p4$p4_ecart[i]),
                decision = if (ugf_p4$p4_decision[i] %in% .P4_DECISIONS) ugf_p4$p4_decision[i] else NA_character_,
                alea_dominant = if (ugf_p4$p4_alea_dominant[i] %in% .P4_ALEAS) ugf_p4$p4_alea_dominant[i] else NA_character_,
                ndp = num(ugf_p4$p4_ndp[i]), signal_seulement = isTRUE(ugf_p4$p4_signal_seulement[i])),
      pareto = list(statut = par[i], axes = lettres,
                    dominee_par = vapply(domine_par[[i]], function(d) .p4_id_sur(match(d, ids)), character(1), USE.NAMES = FALSE)),
      priorite = list(rang = if (nrow(pr)) pr$rang else NA_integer_,
                      manque_a_gagner_eur_an = if (nrow(pr)) pr$manque_a_gagner_eur_an else NA_real_),
      concentrante = conc$alea[conc$ugf == ids[i]],
      actions = ac$action_id,
      options = lapply(seq_len(nrow(op)), function(k) {
        list(id = op$option[k], p4_net_apres = op$p4_net_apres[k],
             effets = stats::setNames(lapply(lettres, function(l) op[[paste0("effet_", l)]][k]), lettres))
      }),
      regles = list(version_regles = r$version, version_parametres = p$version,
                    provisoire = isTRUE(r$provisoire) || isTRUE(p$provisoire))
    )
  })
  attr(res, "correspondance") <- data.frame(ugf_contexte = .p4_id_sur(seq_len(n)), ugf = ids, stringsAsFactors = FALSE)
  res
}
