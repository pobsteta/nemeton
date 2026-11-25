# Etiquettes RECONFORT au format amont, avec propagation Y-2..Y+2
# (spike de re-entrainement, mission 060 de nemetonplateforme).
#
# Format de `train_new_model/` du depot amont : dep_cor (1 sain, 2 deperissant,
# 3 tres deperissant ; jamais 0), DEPERIS_pe (part de D+ dans [0, 1]),
# id_unique, date (annee du releve). Classes (page Sycomore) : saine < 20 % de
# D+, deperissante 20-50 %, tres deperissante > 50 %.

#' Class of a DEPERIS dieback share
#'
#' Maps the share of D+ trees (`DEPERIS_pe`, in \[0, 1\]) to the RECONFORT class:
#' 1 healthy (< 0.20), 2 declining (0.20 to 0.50 inclusive), 3 severely
#' declining (> 0.50).
#'
#' @param deperis_pe Numeric vector in \[0, 1\].
#' @return An integer vector of classes 1, 2 or 3 (`NA` where the input is `NA`).
#' @export
#' @examples
#' reconfort_classe(c(0, 0.19, 0.2, 0.5, 0.51, 1))
reconfort_classe <- function(deperis_pe) {
  if (!is.numeric(deperis_pe)) {
    cli::cli_abort("{.arg deperis_pe} must be numeric.")
  }
  if (any(deperis_pe < 0 | deperis_pe > 1, na.rm = TRUE)) {
    cli::cli_abort("{.arg deperis_pe} must lie in [0, 1].")
  }
  out <- rep(NA_integer_, length(deperis_pe))
  ok <- !is.na(deperis_pe)
  out[ok] <- ifelse(deperis_pe[ok] < 0.20, 1L, ifelse(deperis_pe[ok] <= 0.50, 2L, 3L))
  out
}

#' RECONFORT field labels, checked and propagated from Y-2 to Y+2
#'
#' Validates survey plots in the format of the upstream `train_new_model/`
#' labels, recomputes the class from `DEPERIS_pe`, then propagates the labels
#' in time: a **healthy** plot in year Y is healthy in Y-1 and Y-2; a
#' **declining** plot (class 2 or 3) in year Y is declining in Y+1 and Y+2
#' (class 2, the minimum guaranteed by the rule, whatever the observed class).
#' A propagation never overwrites a real observation, and a disagreement is
#' listed, never settled silently.
#'
#' @param placettes A `data.frame` with columns `id_unique`, `date` (survey
#'   year, integer or `Date`), `dep_cor` (1, 2 or 3; 0 is refused) and
#'   `DEPERIS_pe` in \[0, 1\]. Other columns (e.g. `x`, `y`) are carried along.
#' @param propager Logical; `FALSE` keeps the observations only.
#' @param avant,apres Years propagated before (healthy) and after (declining)
#'   an observation; 2 by default.
#' @return A `data.frame` with `id_unique`, `annee`, `dep_cor` (class from
#'   `DEPERIS_pe`), `DEPERIS_pe` (`NA` on propagated rows), `source`
#'   (`"observation"` or `"propagation"`) and the carried columns. Attributes:
#'   `conflits` (disagreements; a row whose two propagations disagree is
#'   dropped and listed with `classe_retenue = NA`) and `ecarts_classe`
#'   (observations whose given `dep_cor` differs from the class recomputed from
#'   `DEPERIS_pe`).
#' @export
#' @examples
#' p <- data.frame(id_unique = "a", date = 2022L, dep_cor = 1L, DEPERIS_pe = 0.05)
#' reconfort_etiquettes(p)
reconfort_etiquettes <- function(placettes, propager = TRUE, avant = 2L, apres = 2L) {
  requis <- c("id_unique", "date", "dep_cor", "DEPERIS_pe")
  if (!is.data.frame(placettes) || !all(requis %in% names(placettes))) {
    cli::cli_abort("{.arg placettes} must be a data.frame with columns {.field {requis}}.")
  }
  p <- as.data.frame(placettes)
  if (!nrow(p)) cli::cli_abort("{.arg placettes} is empty.")

  # --- controle du format amont ---------------------------------------------
  if (anyNA(p$id_unique)) cli::cli_abort("{.field id_unique} contains NA.")
  if (!is.numeric(p$dep_cor) || anyNA(p$dep_cor) || !all(p$dep_cor %in% c(1, 2, 3))) {
    cli::cli_abort("{.field dep_cor} must be 1, 2 or 3 (0 and NA are refused).")
  }
  if (!is.numeric(p$DEPERIS_pe) || anyNA(p$DEPERIS_pe) ||
      any(p$DEPERIS_pe < 0 | p$DEPERIS_pe > 1)) {
    cli::cli_abort("{.field DEPERIS_pe} must be numeric in [0, 1], without NA.")
  }
  annee <- if (inherits(p$date, "Date")) {
    as.integer(format(p$date, "%Y"))
  } else if (is.numeric(p$date) && !anyNA(p$date) && all(p$date == round(p$date))) {
    as.integer(p$date)
  } else {
    cli::cli_abort("{.field date} must be a survey year (integer) or a Date.")
  }
  cle <- paste(p$id_unique, annee)
  if (anyDuplicated(cle)) {
    dup <- unique(cle[duplicated(cle)])
    cli::cli_abort("Duplicate {.field id_unique} in the same year: {.val {dup}}.")
  }

  # --- classes recalculees depuis DEPERIS_pe --------------------------------
  classe <- reconfort_classe(p$DEPERIS_pe)
  autres <- setdiff(names(p), c(requis))
  obs <- data.frame(
    id_unique = p$id_unique, annee = annee, dep_cor = classe,
    DEPERIS_pe = p$DEPERIS_pe, source = "observation",
    stringsAsFactors = FALSE
  )
  if (length(autres)) obs <- cbind(obs, p[autres])
  ecarts <- data.frame(
    id_unique = p$id_unique, annee = annee, dep_cor_fourni = as.integer(p$dep_cor),
    dep_cor_recalcule = classe, stringsAsFactors = FALSE
  )
  ecarts <- ecarts[ecarts$dep_cor_fourni != ecarts$dep_cor_recalcule, , drop = FALSE]
  if (nrow(ecarts)) {
    cli::cli_warn(c(
      "{nrow(ecarts)} observation{?s} where {.field dep_cor} differs from the class of {.field DEPERIS_pe}.",
      i = "The class recomputed from {.field DEPERIS_pe} is kept; see attribute {.field ecarts_classe}."
    ))
  }

  conflits <- .reconfort_conflits_vide()
  res <- obs
  if (isTRUE(propager)) {
    prop <- .reconfort_propositions(obs, as.integer(avant), as.integer(apres))
    fusion <- .reconfort_fusionner(obs, prop, autres)
    res <- fusion$etiquettes
    conflits <- fusion$conflits
  }
  res <- res[order(res$id_unique, res$annee), , drop = FALSE]
  rownames(res) <- NULL
  rownames(ecarts) <- NULL
  attr(res, "conflits") <- conflits
  attr(res, "ecarts_classe") <- ecarts
  res
}

.reconfort_conflits_vide <- function() {
  data.frame(
    id_unique = character(), annee = integer(), classe_retenue = integer(),
    classe_refusee = integer(), origine_retenue = character(),
    origine_refusee = character(), stringsAsFactors = FALSE
  )
}

# Etiquettes proposees par propagation : une ligne par (observation, annee).
.reconfort_propositions <- function(obs, avant, apres) {
  l <- lapply(seq_len(nrow(obs)), function(i) {
    y <- obs$annee[i]
    if (obs$dep_cor[i] == 1L) {
      ans <- if (avant > 0L) y - seq_len(avant) else integer(0)
      cl <- 1L
    } else {
      ans <- if (apres > 0L) y + seq_len(apres) else integer(0)
      cl <- 2L
    }
    if (!length(ans)) return(NULL)
    data.frame(id_unique = obs$id_unique[i], annee = ans, dep_cor = cl,
               depuis = y, stringsAsFactors = FALSE)
  })
  l <- l[!vapply(l, is.null, logical(1))]
  if (!length(l)) {
    return(data.frame(id_unique = character(), annee = integer(),
                      dep_cor = integer(), depuis = integer(),
                      stringsAsFactors = FALSE))
  }
  do.call(rbind, l)
}

.reconfort_fusionner <- function(obs, prop, autres) {
  conflits <- .reconfort_conflits_vide()
  ajouter <- function(df, id, an, retenue, refusee, o_ret, o_ref) {
    rbind(df, data.frame(id_unique = id, annee = an, classe_retenue = retenue,
                         classe_refusee = refusee, origine_retenue = o_ret,
                         origine_refusee = o_ref, stringsAsFactors = FALSE))
  }
  cle_obs <- paste(obs$id_unique, obs$annee)
  nouvelles <- list()
  if (nrow(prop)) {
    cle_p <- paste(prop$id_unique, prop$annee)
    for (k in unique(cle_p)) {
      lignes <- prop[cle_p == k, , drop = FALSE]
      id <- lignes$id_unique[1]
      an <- lignes$annee[1]
      cls <- unique(lignes$dep_cor)
      i_obs <- match(k, cle_obs)
      if (!is.na(i_obs)) {
        # une vraie observation existe : elle gagne ; desaccord liste
        for (cl in cls[cls != obs$dep_cor[i_obs]]) {
          conflits <- ajouter(conflits, id, an, obs$dep_cor[i_obs], cl,
                              "observation", "propagation")
        }
        next
      }
      if (length(cls) > 1L) {
        # deux propagations en desaccord : on ne tranche pas, ligne ecartee
        conflits <- ajouter(conflits, id, an, NA_integer_, NA_integer_,
                            "propagation", "propagation")
        next
      }
      nouvelles[[length(nouvelles) + 1L]] <- data.frame(
        id_unique = id, annee = an, dep_cor = cls, DEPERIS_pe = NA_real_,
        source = "propagation", stringsAsFactors = FALSE
      )
    }
  }
  etiquettes <- obs
  if (length(nouvelles)) {
    nv <- do.call(rbind, nouvelles)
    # colonnes portees : celles de la placette (meme id), valeur de l'observation la plus proche
    for (a in autres) {
      nv[[a]] <- vapply(seq_len(nrow(nv)), function(j) {
        o <- which(obs$id_unique == nv$id_unique[j])
        o <- o[which.min(abs(obs$annee[o] - nv$annee[j]))]
        obs[[a]][o]
      }, FUN.VALUE = obs[[a]][1])
    }
    nv <- nv[names(obs)]
    etiquettes <- rbind(obs, nv)
  }
  list(etiquettes = etiquettes, conflits = conflits)
}
