#' Catalogue of silvicultural itineraries
#'
#' Reads the catalogue of silvicultural itineraries shipped with the
#' package (`inst/extdata/itineraires_sylvicoles.json`, spec 065) or a
#' catalogue file of your own with the same schema. Each itinerary is
#' described by parameterised **rules** and by its **expected effects** on
#' the indicator families, all sourced.
#'
#' **Sourcing rule.** A numeric parameter without a reference does not enter
#' the catalogue: an entry whose rules are not yet sourced carries
#' `statut_source = "a_sourcer"` and is never admissible. The shipped
#' catalogue holds the skeleton of the first itineraries (spec 065, D-4),
#' all `"a_sourcer"`: their parameters are filled from silvicultural guides
#' by the forester, not invented.
#'
#' @param chemin Path to a catalogue JSON file. `NULL`: the shipped one.
#' @return A list of itineraries (each a list: `code`, `famille_itineraire`,
#'   `libelle`, `domaine`, `regles`, `effets_attendus`, `sources`,
#'   `statut_source`), validated by [valider_catalogue_itineraires()].
#'
#' @section Lifecycle:
#' Experimental (spec 065): may change in any release.
#' @seealso [itineraires_admissibles()], [comparer_itineraires()]
#' @export
itineraires_catalogue <- function(chemin = NULL) {
  if (is.null(chemin)) {
    chemin <- system.file("extdata", "itineraires_sylvicoles.json", package = "nemeton")
  }
  if (!nzchar(chemin) || !file.exists(chemin)) {
    cli::cli_abort("Catalogue file not found: {.path {chemin}}.")
  }
  cat <- jsonlite::read_json(chemin, simplifyVector = FALSE)
  itin <- cat$itineraires %||% list()
  valider_catalogue_itineraires(itin)
  names(itin) <- vapply(itin, `[[`, "", "code")
  itin
}

#' Validate a catalogue of silvicultural itineraries
#'
#' Checks the schema of every entry and the sourcing rule: an entry marked
#' `statut_source = "source"` must cite at least one reference, and every
#' expected effect must give its source.
#'
#' @param itineraires A list of itineraries, as read by
#'   [itineraires_catalogue()].
#' @return Invisibly `TRUE`; an error naming the first faulty entry
#'   otherwise.
#' @section Lifecycle:
#' Experimental (spec 065): may change in any release.
#' @export
valider_catalogue_itineraires <- function(itineraires) {
  champs <- c("code", "famille_itineraire", "libelle", "domaine", "regles",
              "effets_attendus", "sources", "statut_source")
  codes <- character()
  for (it in itineraires) {
    code <- it$code %||% "<sans code>"
    manquants <- setdiff(champs, names(it))
    if (length(manquants)) {
      cli::cli_abort("Itinerary {.val {code}}: missing field{?s} {.field {manquants}}.")
    }
    if (!it$famille_itineraire %in% .FAMILLES_ITINERAIRE) {
      cli::cli_abort("Itinerary {.val {code}}: unknown famille_itineraire {.val {it$famille_itineraire}}.")
    }
    if (!it$statut_source %in% c("source", "a_sourcer")) {
      cli::cli_abort("Itinerary {.val {code}}: statut_source must be \"source\" or \"a_sourcer\".")
    }
    for (f in names(it$effets_attendus)) {
      e <- it$effets_attendus[[f]]
      if (!f %in% .FAMILLES_CODES) {
        cli::cli_abort("Itinerary {.val {code}}: unknown family {.val {f}} in effets_attendus.")
      }
      if (!(e$sens %||% "") %in% c("+", "0", "-", "?")) {
        cli::cli_abort("Itinerary {.val {code}}, family {f}: sens must be +, 0, - or ?.")
      }
      if (identical(it$statut_source, "source") && e$sens != "?" &&
          !nzchar(e$source %||% "")) {
        cli::cli_abort("Itinerary {.val {code}}, family {f}: an effect without a source.")
      }
    }
    if (identical(it$statut_source, "source") && !length(it$sources)) {
      cli::cli_abort("Itinerary {.val {code}} is marked \"source\" but cites no reference.")
    }
    codes <- c(codes, code)
  }
  if (anyDuplicated(codes)) {
    cli::cli_abort("Duplicated itinerary code{?s}: {.val {unique(codes[duplicated(codes)])}}.")
  }
  invisible(TRUE)
}

#' Admissible silvicultural itineraries per unit
#'
#' For every unit and every itinerary of the catalogue, says whether the
#' itinerary is admissible and, if not, **why** (closed set of codes,
#' spec 065 § 4). A criterion whose data is missing never admits nor
#' excludes silently: the row carries `donnee_manquante`.
#'
#' @param units sf (or data frame) of units.
#' @param catalogue Itineraries, from [itineraires_catalogue()].
#' @param protected_areas Optional sf of protected areas with a type column
#'   (`type_protection`, `zone_type`, `type` or `statut`), whose codes are
#'   those of B1 (`rnn`, `rb`, `coeur`, `apb`, `natura`, ...). Needed only by
#'   itineraries that exclude protections.
#' @param colonnes Named list of the unit columns read by the filter:
#'   `id`, `p2` (station, P2), `ser` (sylvoecoregion code), `essence`,
#'   `pente` (slope, %), `desserte` (skidding distance, m; spec 065 D-3).
#'
#' @return A long data frame: `unit_id`, `itineraire`, `admissible`
#'   (logical, `NA` when data is missing), `raison` (`NA` if admissible;
#'   else `source_manquante`, `statut_protection`, `hors_ser`,
#'   `essence_absente`, `station_insuffisante`, `pente`, `desserte` or
#'   `donnee_manquante`) and `detail` (observed value against threshold).
#'   Criteria are checked in that order and the first failing one is
#'   reported.
#'
#' @details Admissible does not mean recommended: it means that nothing in
#' the catalogue's rules and the data rules the itinerary out.
#'
#' @section Lifecycle:
#' Experimental (spec 065): may change in any release.
#' @seealso [comparer_itineraires()]
#' @export
itineraires_admissibles <- function(units, catalogue = itineraires_catalogue(),
                                    protected_areas = NULL,
                                    colonnes = list(id = NULL, p2 = "P2", ser = "ser",
                                                    essence = "essence",
                                                    pente = "pente_pct",
                                                    desserte = "desserte_m")) {
  if (!is.data.frame(units)) cli::cli_abort("{.arg units} must be an sf or a data frame.")
  defaut <- list(id = NULL, p2 = "P2", ser = "ser", essence = "essence",
                 pente = "pente_pct", desserte = "desserte_m")
  colonnes <- utils::modifyList(defaut, colonnes)
  ids <- .itin_ids(units, colonnes$id)
  lire <- function(nom) {
    if (is.null(nom) || !nom %in% names(units)) return(rep(NA, nrow(units)))
    units[[nom]]
  }
  p2 <- suppressWarnings(as.numeric(lire(colonnes$p2)))
  ser <- as.character(lire(colonnes$ser))
  essence <- as.character(lire(colonnes$essence))
  pente <- suppressWarnings(as.numeric(lire(colonnes$pente)))
  desserte <- suppressWarnings(as.numeric(lire(colonnes$desserte)))
  types_prot <- .itin_types_protection(units, protected_areas)

  lignes <- vector("list", nrow(units) * length(catalogue))
  k <- 0L
  for (i in seq_len(nrow(units))) {
    for (it in catalogue) {
      k <- k + 1L
      v <- .itin_verdict(it, p2[i], ser[i], essence[i], pente[i], desserte[i],
                         if (is.null(types_prot)) NULL else types_prot[[i]])
      lignes[[k]] <- data.frame(unit_id = ids[i], itineraire = it$code,
                                admissible = v$admissible, raison = v$raison,
                                detail = v$detail, stringsAsFactors = FALSE)
    }
  }
  if (!k) {
    return(data.frame(unit_id = ids[0], itineraire = character(), admissible = logical(),
                      raison = character(), detail = character()))
  }
  out <- do.call(rbind, lignes[seq_len(k)])
  rownames(out) <- NULL
  out
}

#' Compare silvicultural itineraries under an actor profile
#'
#' Ranks the itineraries of each unit by the weighted sum of their expected
#' effects on the indicator families (`+` = 1, `0` = 0, `-` = -1), says which
#' families win and lose against a reference itinerary, flags the Pareto
#' front and carries the catalogue's citations (spec 065 § 5).
#'
#' @param units sf (or data frame) of units.
#' @param poids Named numeric vector of weights per family (`c(P = 3, B = 2)`),
#'   or the key of a profile of [profils_poids()].
#' @param catalogue Itineraries, from [itineraires_catalogue()].
#' @param admissibles Output of [itineraires_admissibles()]. `NULL`: computed
#'   with the default columns (and `protected_areas`).
#' @param itineraires Optional character vector restricting the candidates.
#' @param reference `"statu_quo"`: the unit's declared itinerary (column
#'   `col_actuel`) when it is a candidate, else the best `score_global`
#'   (spec 065, D-6). Or the code of an itinerary.
#' @param col_actuel Column of the declared current itinerary.
#' @param protected_areas Passed to [itineraires_admissibles()].
#' @param trajectoires `NULL` (default): compare on the qualitative effects
#'   of the catalogue. Or the simulated trajectories of chantier D: the
#'   output of [simuler_itineraire()], one call per itinerary bound with
#'   `rbind()`, with `volume = TRUE` and `carbone = TRUE` for the two
#'   families it carries (see Details). The rows of `simuler_itineraire()`
#'   without management (`itineraire = "sans_gestion"`) are a candidate of
#'   every unit. Then `methode` becomes `"finn"` and `incertitude` numeric;
#'   the output columns do not change.
#' @param horizon Numeric or `NULL`. Year of the trajectories read with
#'   `trajectoires`. `NULL`: the longest horizon simulated for every
#'   itinerary.
#' @param tolerance Numeric. With `trajectoires`, a family is won or lost
#'   against the reference only when the values differ by more than this
#'   share of the reference value (FINN trajectories are stochastic means).
#'   Default 0.05, a convention.
#'
#' @return A data frame, one row per unit x candidate itinerary: `unit_id`,
#'   `itineraire`, `score_global` (in `[-1, 1]`, `NA` if an evaluated family
#'   has an unknown effect `?` for that itinerary), `rang` (1 = best within the unit), `pareto`,
#'   `reference`, `familles_gagnantes`, `familles_perdantes` (against the
#'   reference, comma-separated codes), `familles_evaluees` (weighted
#'   families documented by at least one candidate; the others are set
#'   aside, since they rank nothing), `incertitude` (`"qualitative"`; with
#'   `trajectoires`, the half-width of the conformal interval of the basal
#'   area at the horizon, m2/ha, `NA` without conformal residuals),
#'   `methode` (`"catalogue_qualitatif"` or `"finn"`), `citations`. With
#'   `trajectoires`, `attr(, "valeurs")` holds the simulated values behind
#'   the score: `unit_id`, `itineraire`, `famille`, `variable`, `valeur`,
#'   `unite_mesure`, `horizon`.
#'
#' @details `score_global` is an **order**, not a measure: the effects are
#' qualitative and sourced, not simulated. Display it as a rank. The
#' catalogue is not exhaustive; an itinerary absent from it is not compared.
#'
#' **With `trajectoires`** (spec 068), two families are read from the
#' simulation, the others weighted by the profile are set aside (said in
#' `familles_evaluees`):
#' \describe{
#'   \item{P}{volume harvested, summed up to the horizon (`volume_preleve`,
#'     m3/ha; `g_prelevee`, m2/ha, when the volume was not simulated).}
#'   \item{C}{carbon standing at the horizon (`carbone`, tC/ha).}
#' }
#' Within a unit, each family is rescaled to `[-1, 1]` across the candidates
#' (`-1` the lowest value, `1` the highest, `0` for all when they are
#' equal), then weighted as the qualitative effects. The score is still an
#' order: it depends on the candidates compared, and the rescaling gives the
#' same weight to a small and to a large difference. The values are in
#' `attr(, "valeurs")`. The pitfalls of [simuler_itineraire()] hold: recent
#' climate held constant, response to thinning not learnt, interval widened
#' under a hypothesis beyond one step.
#'
#' @section Lifecycle:
#' Experimental (spec 065): may change in any release.
#' @seealso [itineraires_admissibles()], [profils_poids()],
#'   [identify_pareto_optimal()]
#' @export
comparer_itineraires <- function(units, poids, catalogue = itineraires_catalogue(),
                                 admissibles = NULL, itineraires = NULL,
                                 reference = "statu_quo",
                                 col_actuel = "itineraire_actuel",
                                 protected_areas = NULL, trajectoires = NULL,
                                 horizon = NULL, tolerance = 0.05) {
  if (is.character(poids) && length(poids) == 1L) poids <- profils_poids(poids)
  if (!is.numeric(poids) || is.null(names(poids))) {
    cli::cli_abort("{.arg poids} must be a named numeric vector or a profile key.")
  }
  poids <- poids[poids > 0]
  familles <- names(poids)
  if (is.null(admissibles)) {
    admissibles <- itineraires_admissibles(units, catalogue, protected_areas)
  }
  ids <- unique(admissibles$unit_id)
  actuel <- if (col_actuel %in% names(units)) {
    stats::setNames(as.character(units[[col_actuel]]), .itin_ids(units, NULL))
  } else NULL
  simule <- !is.null(trajectoires)
  if (simule) {
    if (!is.numeric(tolerance) || length(tolerance) != 1L || !is.finite(tolerance) ||
        tolerance < 0) {
      cli::cli_abort("{.arg tolerance} must be a non-negative number.")
    }
    valeurs <- .itin_valeurs_trajectoires(trajectoires, horizon)
    absentes <- setdiff(unique(valeurs$unit_id), ids)
    if (length(absentes) == length(unique(valeurs$unit_id))) {
      cli::cli_abort(c(
        "No unit of {.arg trajectoires} is a unit of {.arg admissibles}.",
        "i" = "Simulate with {.code simuler_itineraire(unites =)} and the unit ids of {.arg units}."
      ))
    }
  }

  effet_num <- function(it, f) {
    e <- it$effets_attendus[[f]]$sens %||% "?"
    switch(e, "+" = 1, "0" = 0, "-" = -1, NA_real_)
  }
  res <- lapply(ids, function(uid) {
    a <- admissibles[admissibles$unit_id == uid & admissibles$admissible %in% TRUE, ]
    cand <- intersect(a$itineraire, names(catalogue))
    if (simule) {
      vu <- valeurs[valeurs$unit_id == uid, , drop = FALSE]
      # « sans_gestion » n'est pas au catalogue : candidat des qu'il est simule
      cand <- c(intersect(cand, vu$itineraire),
                intersect(.ITIN_SANS_GESTION, setdiff(vu$itineraire, cand)))
    }
    if (!is.null(itineraires)) cand <- intersect(cand, itineraires)
    if (!length(cand)) return(NULL)
    if (simule) {
      brut <- .itin_matrice_valeurs(vu, cand, familles)
      doc <- colnames(brut)
      if (!length(doc)) return(NULL)
      # note par famille, ramenee a [-1, 1] entre les candidats de l'UGF
      eff <- apply(brut, 2L, function(v) {
        r <- range(v, na.rm = TRUE)
        if (!all(is.finite(r)) || r[2] - r[1] <= 0) return(ifelse(is.na(v), NA_real_, 0))
        2 * (v - r[1]) / (r[2] - r[1]) - 1
      })
      eff <- matrix(eff, nrow = length(cand), dimnames = list(cand, doc))
    } else {
      # Familles evaluees : celles dont au moins un candidat connait l'effet
      # (+, 0 ou -). Une famille qu'aucun itineraire ne documente ne departage
      # rien : elle est mise de cote (et dite dans `familles_evaluees`). Une
      # famille renseignee pour certains candidats mais inconnue pour un autre
      # rend son score NA.
      doc <- familles[vapply(familles, function(f) any(vapply(cand, function(cd)
        !is.na(effet_num(catalogue[[cd]], f)), TRUE)), TRUE)]
      if (!length(doc)) return(NULL)
      eff <- matrix(vapply(cand, function(cd) {
        vapply(doc, function(f) effet_num(catalogue[[cd]], f), 0)
      }, numeric(length(doc))), nrow = length(cand), byrow = TRUE,
      dimnames = list(cand, doc))
      brut <- eff
    }
    w <- poids[doc]
    score <- apply(eff, 1L, function(e) {
      if (anyNA(e)) NA_real_ else sum(e * w) / sum(w)
    })
    complet <- stats::complete.cases(brut)
    pareto <- rep(NA, length(cand))
    if (any(complet)) {
      df <- as.data.frame(brut[complet, , drop = FALSE])
      pareto[complet] <- identify_pareto_optimal(df, objectives = doc)$is_optimal
    }
    ref <- if (identical(reference, "statu_quo")) {
      sq <- if (!is.null(actuel)) actuel[[as.character(uid)]] else NA
      if (!is.na(sq %||% NA) && sq %in% cand) sq
      else if (any(!is.na(score))) cand[which.max(score)] else cand[1]
    } else reference
    if (ref %in% cand) {
      bref <- brut[ref, ]
    } else if (simule) {
      cli::cli_abort("Reference {.val {ref}} is not a simulated candidate of unit {.val {uid}}.")
    } else {
      bref <- vapply(doc, function(f) effet_num(catalogue[[ref]], f), 0)
    }
    seuil <- if (simule) tolerance * pmax(abs(bref), .Machine$double.eps) else 0
    gagne <- apply(brut, 1L, function(e) paste(doc[which(e - bref > seuil)], collapse = ", "))
    perd <- apply(brut, 1L, function(e) paste(doc[which(bref - e > seuil)], collapse = ", "))
    incert <- if (simule) {
      unname(attr(valeurs, "incertitude")[paste(uid, cand)])
    } else "qualitative"
    data.frame(
      unit_id = uid, itineraire = cand, score_global = unname(score),
      rang = rank(-ifelse(is.na(score), -Inf, score), ties.method = "min"),
      pareto = pareto, reference = ref,
      familles_gagnantes = unname(gagne), familles_perdantes = unname(perd),
      familles_evaluees = paste(sort(doc), collapse = ", "),
      incertitude = incert,
      methode = if (simule) "finn" else "catalogue_qualitatif",
      citations = vapply(cand, function(cd) {
        if (cd %in% names(catalogue)) .itin_citations(catalogue[[cd]]) else ""
      }, ""),
      stringsAsFactors = FALSE, row.names = NULL
    )
  })
  out <- do.call(rbind, res)
  if (is.null(out)) {
    cli::cli_alert_info("comparer_itineraires: no admissible itinerary to compare.")
    return(data.frame())
  }
  rownames(out) <- NULL
  if (simule) {
    v <- valeurs[paste(valeurs$unit_id, valeurs$itineraire) %in%
                   paste(out$unit_id, out$itineraire) & valeurs$famille %in% familles, ]
    rownames(v) <- NULL
    attr(out, "valeurs") <- v
  }
  out
}

#' Family weights of the actor profiles
#'
#' The family weights used by [comparer_itineraires()] for each actor
#' profile (`inst/extdata/profils_poids.json`, spec 065 D-1: the weights are
#' business logic and live in the core; prompts and labels stay in the app).
#'
#' @param profil A profile key (e.g. `"profil_naturaliste"`), or `NULL` for
#'   all profiles.
#' @return For one profile, a named numeric vector of the 12 family weights;
#'   for `NULL`, a list of them, with the file's provenance in
#'   `attr(, "meta")`.
#'
#' @details The shipped weights are **provisional**: priority families of
#' each profile (CLAUDE.md table) weigh 3, the others 1, and "all families"
#' profiles weigh 1 everywhere. They are a starting point to be validated
#' or replaced, not a calibration.
#'
#' @section Lifecycle:
#' Experimental (spec 065): may change in any release.
#' @export
profils_poids <- function(profil = NULL) {
  f <- system.file("extdata", "profils_poids.json", package = "nemeton")
  d <- jsonlite::read_json(f, simplifyVector = TRUE)
  profils <- lapply(d$profils, function(p) unlist(p$poids))
  if (is.null(profil)) {
    attr(profils, "meta") <- d[setdiff(names(d), "profils")]
    return(profils)
  }
  if (!profil %in% names(profils)) {
    cli::cli_abort("Unknown profile {.val {profil}}; known: {.val {names(profils)}}.")
  }
  profils[[profil]]
}

# ------------------------------------------------------------------ internes

.FAMILLES_ITINERAIRE <- c("futaie_reguliere", "futaie_irreguliere",
                          "taillis_sous_futaie", "libre_evolution", "conversion",
                          "ilot_senescence", "plantation_diversification")
.FAMILLES_CODES <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")

.itin_ids <- function(units, col) {
  if (!is.null(col) && col %in% names(units)) return(as.character(units[[col]]))
  for (c in c("unit_id", "id", "parcel_id", "nemeton_id")) {
    if (c %in% names(units)) return(as.character(units[[c]]))
  }
  as.character(seq_len(nrow(units)))
}

# Codes de protection touchant chaque UGF (meme lecture que B1).
.itin_types_protection <- function(units, protected_areas) {
  if (is.null(protected_areas) || !inherits(units, "sf")) return(NULL)
  col <- intersect(c("type_protection", "zone_type", "type", "statut"),
                   names(protected_areas))[1]
  if (is.na(col)) cli::cli_abort("{.arg protected_areas} has no type column.")
  pa <- sf::st_transform(protected_areas, sf::st_crs(units))
  touche <- sf::st_intersects(units, pa)
  lapply(touche, function(j) tolower(as.character(pa[[col]][j])))
}

.itin_verdict <- function(it, p2, ser, essence, pente, desserte, types_prot) {
  d <- it$domaine
  ok <- function() list(admissible = TRUE, raison = NA_character_, detail = NA_character_)
  non <- function(raison, detail) list(admissible = FALSE, raison = raison, detail = detail)
  manque <- function(quoi) list(admissible = NA, raison = "donnee_manquante",
                                detail = paste("missing:", quoi))
  if (!identical(it$statut_source, "source")) {
    return(non("source_manquante", "statut_source = a_sourcer"))
  }
  excl <- unlist(d$protections_exclues)
  if (length(excl)) {
    if (is.null(types_prot)) return(manque("protected_areas"))
    hit <- excl[vapply(excl, function(e) any(grepl(e, types_prot, fixed = TRUE)), TRUE)]
    if (length(hit)) return(non("statut_protection", paste("protection:", paste(hit, collapse = ", "))))
  }
  sers <- unlist(d$ser)
  if (length(sers)) {
    if (is.na(ser)) return(manque("ser"))
    if (!ser %in% sers) return(non("hors_ser", sprintf("SER %s not in %s", ser, paste(sers, collapse = ", "))))
  }
  ess <- unlist(d$essences_objectif)
  if (length(ess)) {
    if (is.na(essence)) return(manque("essence"))
    if (!essence %in% ess) return(non("essence_absente", sprintf("essence %s not in %s", essence, paste(ess, collapse = ", "))))
  }
  if (!is.null(d$p2_min) || !is.null(d$p2_max)) {
    if (is.na(p2)) return(manque("P2"))
    if (!is.null(d$p2_min) && p2 < d$p2_min) return(non("station_insuffisante", sprintf("P2 %.3g < %.3g", p2, d$p2_min)))
    if (!is.null(d$p2_max) && p2 > d$p2_max) return(non("station_insuffisante", sprintf("P2 %.3g > %.3g", p2, d$p2_max)))
  }
  if (!is.null(d$pente_max_pct)) {
    if (is.na(pente)) return(manque("pente"))
    if (pente > d$pente_max_pct) return(non("pente", sprintf("slope %.3g %% > %.3g %%", pente, d$pente_max_pct)))
  }
  if (isTRUE(d$desserte_requise)) {
    if (is.na(desserte)) return(manque("desserte"))
    seuil <- d$desserte_max_m
    if (!is.null(seuil) && desserte > seuil) return(non("desserte", sprintf("skidding %.0f m > %.0f m", desserte, seuil)))
  }
  ok()
}

.itin_citations <- function(it) {
  refs <- vapply(it$sources, function(s) {
    p <- s$pages %||% ""
    if (nzchar(p)) paste0(s$ref, ", ", p) else s$ref
  }, "")
  paste(refs, collapse = "; ")
}

# ------------------------------------------------- trajectoires (spec 068)

.ITIN_SANS_GESTION <- "sans_gestion"

# Familles lues dans les trajectoires de simuler_itineraire() : variable(s)
# par ordre de preference, cumul jusqu'a l'horizon ou valeur a l'horizon.
.ITIN_FAMILLES_SIMULEES <- list(
  P = list(variables = c(volume_preleve = "m3/ha", g_prelevee = "m2/ha"), cumul = TRUE),
  C = list(variables = c(carbone = "tC/ha"), cumul = FALSE)
)

# Valeurs par UGF x itineraire x famille a l'horizon, depuis la table longue
# de simuler_itineraire() (plusieurs itineraires lies par rbind). L'attribut
# « incertitude » porte la demi-largeur conforme de G a l'horizon.
.itin_valeurs_trajectoires <- function(trajectoires, horizon) {
  t <- as.data.frame(trajectoires)
  id <- if ("unite" %in% names(t)) "unite" else "placette"
  manq <- setdiff(c(id, "itineraire", "annee", "variable", "moyenne"), names(t))
  if (length(manq)) {
    cli::cli_abort(c(
      "{.arg trajectoires} lacks {.field {manq}}.",
      "i" = "It must be the output of {.fn simuler_itineraire}."
    ))
  }
  if (!nrow(t)) cli::cli_abort("{.arg trajectoires} has no row.")
  t$unit_id <- as.character(t[[id]])
  fin <- tapply(t$annee, t$itineraire, max)
  if (is.null(horizon)) horizon <- min(fin)
  if (!is.numeric(horizon) || length(horizon) != 1L || !is.finite(horizon)) {
    cli::cli_abort("{.arg horizon} must be a single year.")
  }
  courts <- names(fin)[fin < horizon]
  if (length(courts)) {
    cli::cli_abort("{.val {courts}} not simulated up to year {horizon}.")
  }
  t <- t[t$annee <= horizon, , drop = FALSE]
  lignes <- list()
  for (f in names(.ITIN_FAMILLES_SIMULEES)) {
    spec <- .ITIN_FAMILLES_SIMULEES[[f]]
    var <- intersect(names(spec$variables), unique(t$variable))[1]
    if (is.na(var)) next
    x <- t[t$variable == var, , drop = FALSE]
    if (!spec$cumul) x <- x[x$annee == horizon, , drop = FALSE]
    if (!nrow(x)) next
    a <- stats::aggregate(moyenne ~ unit_id + itineraire, data = x, FUN = sum)
    lignes[[f]] <- data.frame(unit_id = a$unit_id, itineraire = a$itineraire, famille = f,
                              variable = var, valeur = a$moyenne,
                              unite_mesure = unname(spec$variables[var]), horizon = horizon,
                              stringsAsFactors = FALSE)
  }
  if (!length(lignes)) {
    cli::cli_abort(c(
      "{.arg trajectoires} carries no variable read by the comparison.",
      "i" = "Simulate with {.code volume = TRUE, carbone = TRUE} (P: {.field volume_preleve}, C: {.field carbone})."
    ))
  }
  v <- do.call(rbind, lignes)
  rownames(v) <- NULL
  g <- t[t$variable == "g" & t$annee == horizon, , drop = FALSE]
  dl <- if (nrow(g) && all(c("bas", "haut") %in% names(g))) (g$haut - g$bas) / 2 else
    rep(NA_real_, nrow(g))
  attr(v, "incertitude") <- stats::setNames(as.numeric(dl), paste(g$unit_id, g$itineraire))
  v
}

# Matrice candidats x familles ponderees renseignees par la simulation.
.itin_matrice_valeurs <- function(vu, cand, familles) {
  doc <- intersect(familles, unique(vu$famille))
  m <- matrix(NA_real_, length(cand), length(doc), dimnames = list(cand, doc))
  for (f in doc) {
    x <- vu[vu$famille == f, , drop = FALSE]
    m[, f] <- x$valeur[match(cand, x$itineraire)]
  }
  m
}
