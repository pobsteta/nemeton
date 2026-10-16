# ifn_tarifs.R — numéros de tarif Schaeffer par essence × SER (spec 062)
# ---------------------------------------------------------------------------
# Marculus cube les tiges au tarif Schaeffer à une entrée, V = f(D, N). Ce
# fichier calcule N par essence depuis les arbres IFN cubés, à trois échelons
# (SER, GRECO, France), et le propose à l'échelle d'une forêt.
#
# Méthode reprise de `PPtools::TarifFindSch()` et `TarifIFN()` de Max
# Bruciamacchie (AgroParisTech Nancy), GPL-2, reprise sous GPL-3 avec son
# autorisation explicite (courriel du 22 juillet 2026, qui couvre tout
# PPtools). Deux écarts, documentés dans la spec 062 :
#   - variance pondérée à poids de fiabilité (dénominateur Σw − Σw²/Σw) au
#     lieu de `Hmisc::wtd.var` (Σw − 1), négative quand un groupe pèse moins
#     d'1 m³ ;
#   - pas de krigeage : une statistique par groupe.
# Données : IGN, Inventaire forestier national, données brutes, Licence
# Ouverte Etalab 2.0.

.TARIF_TYPES <- c("SCHR", "SCHI", "SCHL", "SCHTL")

# Constantes des quatre tarifs : V = (N + 8) / k * f(D), soit
# N = 5 V k' / f(D) - 8 avec k' le coefficient de PPtools.
.tarif_coef <- list(
  SCHR  = list(k = 70000,  f = function(d) (d - 5) * (d - 10)),
  SCHI  = list(k = 80000,  f = function(d) (d - 2.5) * (d - 7.5)),
  SCHL  = list(k = 90000,  f = function(d) d * (d - 5)),
  SCHTL = list(k = 101250, f = function(d) d^2)
)

.tarif_type <- function(type) {
  type <- toupper(as.character(type))
  bad <- setdiff(type, .TARIF_TYPES)
  if (length(bad)) {
    cli::cli_abort(c("Unknown Schaeffer tariff type{?s}: {.val {bad}}.",
                     i = "Allowed: {.val {(.TARIF_TYPES)}}."))
  }
  type
}


#' Schaeffer tariff number of a tree, and volume of a tariff
#'
#' One-entry Schaeffer tariffs (fast \code{SCHR}, intermediate \code{SCHI},
#' slow \code{SCHL}, very slow \code{SCHTL}), with the conventions of
#' \code{PPtools::TarifFindSch()} and of Marculus (\code{M = 0.8 + 0.1 N}):
#' \itemize{
#'   \item \code{SCHR}: \eqn{V = (N + 8) (D - 5)(D - 10) / 14000};
#'   \item \code{SCHI}: \eqn{V = (N + 8) (D - 2.5)(D - 7.5) / 16000};
#'   \item \code{SCHL}: \eqn{V = (N + 8) D (D - 5) / 18000};
#'   \item \code{SCHTL}: \eqn{V = (N + 8) D^2 / 20250}.
#' }
#' \code{numero_tarif_schaeffer()} inverts them: the number that gives a
#' tree of diameter \code{D} its volume \code{V}.
#'
#' @param volume_m3 Numeric. Merchantable stem volume (m3, IFN \code{V}).
#' @param diametre_cm Numeric. Diameter at 1.30 m (cm).
#' @param numero Numeric. Tariff number.
#' @param type Character, one of \code{"SCHR"}, \code{"SCHI"}, \code{"SCHL"},
#'   \code{"SCHTL"} (recycled).
#'
#' @return Numeric vector: the number (\code{numero_tarif_schaeffer}) or the
#'   volume in m3 (\code{volume_tarif_schaeffer}), \code{NA} where the formula
#'   is undefined.
#'
#' @section Lifecycle:
#' Experimental (spec 062).
#'
#' @examples
#' numero_tarif_schaeffer(1.2, 40, "SCHL")
#' volume_tarif_schaeffer(10, 40, "SCHL")
#'
#' @export
numero_tarif_schaeffer <- function(volume_m3, diametre_cm, type) {
  type <- .tarif_type(type)
  n <- max(length(volume_m3), length(diametre_cm), length(type))
  v <- rep_len(as.numeric(volume_m3), n)
  d <- rep_len(as.numeric(diametre_cm), n)
  type <- rep_len(type, n)
  out <- rep(NA_real_, n)
  for (t in unique(type)) {
    i <- type == t
    f <- .tarif_coef[[t]]$f(d[i])
    out[i] <- ifelse(f > 0, v[i] / 5 * .tarif_coef[[t]]$k / f - 8, NA_real_)
  }
  out
}

#' @rdname numero_tarif_schaeffer
#' @export
volume_tarif_schaeffer <- function(numero, diametre_cm, type) {
  type <- .tarif_type(type)
  n <- max(length(numero), length(diametre_cm), length(type))
  num <- rep_len(as.numeric(numero), n)
  d <- rep_len(as.numeric(diametre_cm), n)
  type <- rep_len(type, n)
  out <- rep(NA_real_, n)
  for (t in unique(type)) {
    i <- type == t
    out[i] <- pmax((num[i] + 8) * 5 / .tarif_coef[[t]]$k * .tarif_coef[[t]]$f(d[i]), 0)
  }
  out
}

# Moyenne et variance pondérées, poids de fiabilité : définies dès 2 arbres,
# jamais négatives (Hmisc::wtd.var divise par Σw − 1).
.stats_ponderees <- function(x, w) {
  ok <- !is.na(x) & !is.na(w) & w > 0
  x <- x[ok]
  w <- w[ok]
  if (length(x) < 2L) return(c(moyenne = NA_real_, variance = NA_real_))
  v1 <- sum(w)
  m <- sum(w * x) / v1
  den <- v1 - sum(w^2) / v1
  c(moyenne = m, variance = if (den > 0) sum(w * (x - m)^2) / den else NA_real_)
}


# ---- Part de houppier (EMERGE) ----------------------------------------

# Coefficients EMERGE par espar (gftools::ListTarEmerge, version « mai2 »,
# extraits par data-raw/build_ifn_tarifs_schaeffer.R).
.emerge_coefs <- function() {
  .tarif_lire("emerge_coefficients.csv", c("espar", "nom_lat"))
}

# Volumes EMERGE bois fort (découpe 7 cm) de la tige et du houppier, en m3,
# hdec = 0,8 · htot : mêmes équations que gftools::TarEmerge() et que
# Marculus (Cubage.kt). `c13` en mètres, `htot` en mètres, `k` une
# data.frame de coefficients alignée sur les arbres.
.emerge_volumes <- function(c13, htot, k) {
  cdec <- 7 * pi / 100
  ok <- !is.na(c13) & !is.na(htot) & htot > 1.4 & c13 > 0 & !is.na(k$a)
  tige <- houp <- rep(NA_real_, length(c13))
  if (!any(ok)) return(list(tige = tige, houppier = houp))
  c13 <- c13[ok]; h <- htot[ok]; k <- k[ok, , drop = FALSE]
  corr <- 1 - 1.3 / h
  hdn <- sqrt(c13) / h
  volcyl <- c13^2 * h / (4 * pi * corr^2)
  formtot <- k$a + k$b * hdn + k$c * h / c13
  fct <- k$d + k$e * log(0.8 / 0.2) + k$f * hdn + k$g / c13
  fct[fct > 0.95] <- 0.8
  formtige <- formtot * fct
  t_ok <- pmax(formtige * volcyl * ifelse(c13 > cdec, 1 - (cdec * corr / c13)^3, 0), 0)
  u <- 1 / fct - 1
  h_ok <- rep(0, length(c13))
  pos <- u > 0 & k$alpha > 0
  if (any(pos)) {
    r <- ((3 - k$beta[pos]) * u[pos] / (3 * k$alpha[pos]))
    cmax <- (c13[pos] / corr[pos]) * r^(1 / 3)
    dec <- ifelse(cmax > cdec,
                  1 - ((cdec / c13[pos] * corr[pos]) * r^(-1 / 3))^(3 - k$beta[pos]), 0)
    h_ok[pos] <- (formtot[pos] - formtige[pos]) * volcyl[pos] * dec
  }
  h_ok[!is.finite(h_ok) | h_ok < 0] <- 0
  tige[ok] <- t_ok
  houp[ok] <- h_ok
  list(tige = tige, houppier = houp)
}


#' Schaeffer tariff numbers from IFN trees
#'
#' The computing chain shared by the reference table
#' (\code{data-raw/build_ifn_tarifs_schaeffer.R}) and by
#' \code{\link{tarif_schaeffer_local}}, after \code{PPtools::TarifFindSch()}:
#' living trees (\code{VEGET == "0"}) with a volume \code{V}, circumference
#' \code{100 * C13 >= 50} cm (\code{C13} is in **metres** in the IGN raw
#' data), \eqn{17.5 \le D \le 80} cm with \eqn{D = 100 C13 / \pi}; four
#' numbers per tree (\code{\link{numero_tarif_schaeffer}}); per group and
#' species, mean weighted by the tree volume and coefficient of variation
#' (weighted standard deviation / |mean|, reliability weights). A species is
#' kept in a group from 3 trees on. Low-form species (holm oak, downy oak)
#' can get a negative number on the slower tariffs: it is kept, as in
#' PPtools; the coefficient of variation stays positive.
#'
#' When \code{arbres} has a \code{HTOT} column (total height, m), the
#' \strong{crown share} \code{part_houppier} is added: the share of the
#' merchantable wood (stem + branches over 7 cm) that is crown, in percent,
#' \eqn{100 \sum V_{houp} / \sum (V_{tige} + V_{houp})} over the trees of the
#' group with a height, both volumes from the EMERGE equations
#' (\code{gftools::ListTarEmerge}, as Marculus does for its EMERGE tariff;
#' \code{hdec = 0.8 htot}). It is a \strong{model}, not a measurement: the
#' IFN does not measure branches. \code{NA} below 3 trees with a height or
#' without EMERGE coefficients for the species. It is the same for the four
#' tariff types of a group; Marculus applies it as
#' \code{houppier = V_tige p / (1 - p)}.
#'
#' @param arbres data.frame of IFN trees with \code{ESPAR}, \code{C13} (m),
#'   \code{V} (m3), \code{VEGET} and \code{IDP}, plus the \code{groupes}
#'   columns (e.g. \code{SER}, joined from \code{PLACETTE}). Columns may be
#'   character, as read by \code{\link{ifn_charger}}.
#' @param groupes Character. Grouping columns (default none: one group).
#'
#' @return A data.frame with the \code{groupes} columns, \code{espar},
#'   \code{type} (\code{SCHR}, \code{SCHI}, \code{SCHL}, \code{SCHTL}),
#'   \code{numero} (to 0.1), \code{cv} (percent, to 0.1), \code{n_arbres} and
#'   \code{n_placettes}, and \code{part_houppier} (percent, to 0.1) when
#'   \code{HTOT} is given.
#'
#' @section Lifecycle:
#' Experimental (spec 062).
#'
#' @export
calculer_tarifs_schaeffer <- function(arbres, groupes = character(0)) {
  besoin <- c("ESPAR", "C13", "V", "VEGET", "IDP", groupes)
  manque <- setdiff(besoin, names(arbres))
  if (length(manque)) cli::cli_abort("{.arg arbres} lacks column{?s} {.val {manque}}.")
  avec_h <- "HTOT" %in% names(arbres)
  a <- as.data.frame(arbres)[, c(besoin, if (avec_h) "HTOT"), drop = FALSE]
  a$V <- suppressWarnings(as.numeric(a$V))
  a$C13 <- suppressWarnings(as.numeric(a$C13))
  a <- a[!is.na(a$VEGET) & as.character(a$VEGET) == "0" & !is.na(a$V) & a$V > 0 &
           !is.na(a$C13) & 100 * a$C13 >= 50, , drop = FALSE]
  a$D <- 100 * a$C13 / pi
  a <- a[a$D >= 17.5 & a$D <= 80, , drop = FALSE]
  a$espar <- as.character(a$ESPAR)
  if (avec_h) {
    # Volumes EMERGE des arbres qui ont une hauteur (sous-échantillon IFN).
    k <- .emerge_coefs()
    depad <- function(v) sub("^0([0-9])$", "\\1", v)
    k <- k[match(depad(a$espar), depad(k$espar)), , drop = FALSE]
    vol <- .emerge_volumes(a$C13, suppressWarnings(as.numeric(a$HTOT)), k)
    a$v_tige_em <- vol$tige
    a$v_houp_em <- vol$houppier
  }
  vide <- data.frame(matrix(nrow = 0, ncol = length(groupes)))
  names(vide) <- groupes
  vide <- cbind(vide, data.frame(espar = character(0), type = character(0),
                                 numero = numeric(0), cv = numeric(0),
                                 n_arbres = integer(0), n_placettes = integer(0)))
  if (avec_h) vide$part_houppier <- numeric(0)
  if (!nrow(a)) return(vide)
  cle <- interaction(a[, c(groupes, "espar"), drop = FALSE], drop = TRUE, sep = "\r")
  morceaux <- split(seq_len(nrow(a)), cle)
  morceaux <- morceaux[lengths(morceaux) > 2L]
  if (!length(morceaux)) return(vide)
  out <- lapply(morceaux, function(i) {
    lignes <- lapply(.TARIF_TYPES, function(t) {
      s <- .stats_ponderees(numero_tarif_schaeffer(a$V[i], a$D[i], t), a$V[i])
      data.frame(type = t, numero = round(unname(s["moyenne"]), 1),
                 # |moyenne| : une essence de faible forme (chêne vert) a un
                 # numéro négatif ; un CV négatif serait pris pour le meilleur.
                 cv = round(100 * sqrt(unname(s["variance"])) / abs(unname(s["moyenne"])), 1),
                 stringsAsFactors = FALSE)
    })
    tete <- a[i[1], c(groupes, "espar"), drop = FALSE]
    res <- cbind(tete[rep(1, 4), , drop = FALSE], do.call(rbind, lignes),
                 n_arbres = length(i), n_placettes = length(unique(a$IDP[i])),
                 row.names = NULL)
    if (avec_h) {
      j <- i[!is.na(a$v_tige_em[i])]
      tot <- sum(a$v_tige_em[j] + a$v_houp_em[j])
      res$part_houppier <- if (length(j) > 2L && tot > 0) {
        round(100 * sum(a$v_houp_em[j]) / tot, 1)
      } else NA_real_
    }
    res
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}


# ---- Table de référence (inst/extdata) --------------------------------

# Tables au format Marculus : séparateur `;`, décimale `.`, champ vide = NA ;
# les codes restent du texte (`09` n'est pas `9`).
.tarif_lire <- function(fichier, texte) {
  path <- system.file("extdata", fichier, package = "nemeton")
  if (!nzchar(path) || !file.exists(path)) {
    cli::cli_abort("{fichier} not found in the installed package.")
  }
  entete <- strsplit(readLines(path, n = 1L, encoding = "UTF-8"), ";", fixed = TRUE)[[1]]
  classes <- ifelse(entete %in% texte, "character", NA)
  utils::read.table(path, header = TRUE, sep = ";", dec = ".", quote = "\"",
                    na.strings = "", colClasses = classes, encoding = "UTF-8",
                    stringsAsFactors = FALSE, comment.char = "")
}

.tarif_table <- function() {
  .tarif_lire("ifn_tarif_schaeffer_ser.csv",
              c("niveau", "code", "espar", "essence_libelle", "type", "millesime"))
}

#' IFN Schaeffer tariff numbers by species and ecoregion
#'
#' Reads \code{inst/extdata/ifn_tarif_schaeffer_ser.csv}, built by
#' \code{data-raw/build_ifn_tarifs_schaeffer.R} with
#' \code{\link{calculer_tarifs_schaeffer}} over the latest IFN campaigns:
#' one row per level (\code{SER}, \code{GRECO}, \code{FRANCE} with code
#' \code{FR}) x species x tariff type, every group of 3 trees or more,
#' without threshold (the format Marculus embeds). \code{cv} is in percent.
#'
#' The numbers are a **default** for the marker, not a prescription: they
#' describe the trees the IFN measured.
#'
#' @param espar Optional IFN species codes (any form accepted by
#'   \code{\link{resoudre_espar}}).
#' @param code Optional SER / GRECO codes, or \code{"FR"}.
#' @param niveau Optional levels among \code{"SER"}, \code{"GRECO"},
#'   \code{"FRANCE"}.
#' @param type Optional tariff types.
#'
#' @return A data.frame \code{niveau}, \code{code}, \code{espar},
#'   \code{essence_libelle}, \code{type}, \code{numero}, \code{n_arbres},
#'   \code{cv}, \code{millesime}, \code{part_houppier} (crown share of the
#'   merchantable wood, percent, EMERGE model, see
#'   \code{\link{calculer_tarifs_schaeffer}}).
#'
#' @section Lifecycle:
#' Experimental (spec 062).
#'
#' @examples
#' ifn_tarif_schaeffer_ser(espar = "09", code = "C20", type = "SCHL")
#'
#' @export
ifn_tarif_schaeffer_ser <- function(espar = NULL, code = NULL, niveau = NULL, type = NULL) {
  d <- .tarif_table()
  if (!is.null(niveau)) {
    niveau <- match.arg(toupper(niveau), c("SER", "GRECO", "FRANCE"), several.ok = TRUE)
    d <- d[d$niveau %in% niveau, , drop = FALSE]
  }
  if (!is.null(espar)) d <- d[d$espar %in% .tarif_espar(espar), , drop = FALSE]
  if (!is.null(code)) d <- d[d$code %in% as.character(code), , drop = FALSE]
  if (!is.null(type)) d <- d[d$type %in% .tarif_type(type), , drop = FALSE]
  rownames(d) <- NULL
  d
}

.tarif_espar <- function(espar) {
  e <- resoudre_espar(as.character(espar))
  ifelse(is.na(e), as.character(espar), e)
}

#' Reference Schaeffer tariff number of a species (SER, GRECO, France)
#'
#' Cascade SER -> GRECO -> France over \code{\link{ifn_tarif_schaeffer_ser}}:
#' the first level where the species has at least \code{min_arbres} trees.
#' \code{type_conseille} is the type with the lowest coefficient of variation
#' at that level.
#'
#' @param espar Species codes (any form accepted by
#'   \code{\link{resoudre_espar}}).
#' @param ser Optional SER code (its GRECO is its first letter). \code{NULL}
#'   goes straight to France.
#' @param type Optional tariff type; \code{NULL} returns the four.
#' @param min_arbres Minimal number of trees of a level. Default 30, the
#'   threshold Marculus applies to the same table.
#'
#' @return A data.frame \code{espar}, \code{essence_libelle}, \code{type},
#'   \code{numero}, \code{cv}, \code{n_arbres}, \code{niveau_utilise},
#'   \code{code}, \code{type_conseille}, \code{part_houppier} (percent);
#'   \code{NA} where no level qualifies.
#'
#' @section Lifecycle:
#' Experimental (spec 062).
#'
#' @examples
#' ifn_tarif_schaeffer_reference(c("Chêne sessile", "09"), ser = "C20", type = "SCHL")
#'
#' @export
ifn_tarif_schaeffer_reference <- function(espar, ser = NULL, type = NULL, min_arbres = 30) {
  if (!is.null(ser) && (length(ser) != 1L || is.na(ser))) {
    cli::cli_abort("{.arg ser} must be a single SER code, or NULL.")
  }
  types <- if (is.null(type)) .TARIF_TYPES else .tarif_type(type)
  d <- .tarif_table()
  echelons <- Filter(Negate(is.null), list(
    if (!is.null(ser)) c("SER", ser),
    if (!is.null(ser)) c("GRECO", substr(ser, 1L, 1L)),
    c("FRANCE", "FR")
  ))
  une <- function(e_in) {
    e <- .tarif_espar(e_in)
    for (ech in echelons) {
      cand <- d[d$niveau == ech[1] & d$code == ech[2] & d$espar == e, , drop = FALSE]
      if (nrow(cand) && cand$n_arbres[1] >= min_arbres) {
        conseil <- cand$type[which.min(ifelse(is.na(cand$cv), Inf, cand$cv))]
        cand <- cand[cand$type %in% types, , drop = FALSE]
        return(data.frame(espar = e, essence_libelle = cand$essence_libelle,
                          type = cand$type, numero = cand$numero, cv = cand$cv,
                          n_arbres = cand$n_arbres, niveau_utilise = ech[1],
                          code = ech[2], type_conseille = conseil,
                          part_houppier = cand$part_houppier %||% NA_real_,
                          stringsAsFactors = FALSE))
      }
    }
    data.frame(espar = e, essence_libelle = NA_character_, type = types,
               numero = NA_real_, cv = NA_real_, n_arbres = NA_integer_,
               niveau_utilise = NA_character_, code = NA_character_,
               type_conseille = NA_character_, part_houppier = NA_real_,
               stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, lapply(as.character(espar), une))
  rownames(out) <- NULL
  out
}


#' Communes and their ecoregions
#'
#' Reads \code{inst/extdata/communes_ser.csv}: one row per commune x SER,
#' \code{part} = share of the commune's total area in the SER (shares under
#' 1 \% dropped, then renormalised: they sum to 1 per commune).
#'
#' @param insee Optional INSEE commune codes.
#'
#' @return A data.frame \code{insee}, \code{nom}, \code{departement},
#'   \code{ser}, \code{part}, \code{greco}.
#'
#' @section Lifecycle:
#' Experimental (spec 062).
#'
#' @examples
#' communes_ser("21295")
#'
#' @export
communes_ser <- function(insee = NULL) {
  d <- .tarif_lire("communes_ser.csv", c("insee", "nom", "departement", "ser", "greco"))
  if (!is.null(insee)) d <- d[d$insee %in% as.character(insee), , drop = FALSE]
  rownames(d) <- NULL
  d
}


# ---- Proposition à l'échelle de la forêt ------------------------------

# Tampon portant la surface de la forêt à `cible_ha` (PPtools::ExtractPlac) :
# π d² + 2 π √(S/π) d + S = cible, au moins `min_m`.
.tampon_extract_plac <- function(surface_m2, cible_ha = 2000, min_m = 450) {
  a <- pi
  b <- 2 * pi * sqrt(surface_m2 / pi)
  c <- surface_m2 - cible_ha * 1e4
  delta <- b^2 - 4 * a * c
  max((-b + sqrt(delta)) / (2 * a), min_m)
}

#' Schaeffer tariff numbers of a forest
#'
#' Tariff numbers computed on the IFN plots around the forest: \code{units}
#' plus a buffer bringing the area to about 2,000 ha (at least 450 m), as
#' \code{PPtools::ExtractPlac()}. A species keeps its forest number when it
#' has at least \code{min_arbres} trees on at least \code{min_placettes}
#' plots; otherwise the number falls back on
#' \code{\link{ifn_tarif_schaeffer_reference}} for the majority SER.
#'
#' Public IFN plots are placed at the centre of their kilometre cell (700 m
#' off at most): there are about ten plots per 2,000 ha of forest, hence the
#' tree threshold at the forest level (spec 062, D2).
#'
#' @param units sf polygons of the forest.
#' @param especes Optional species (any form accepted by
#'   \code{\link{resoudre_espar}}); default: the species found around the
#'   forest.
#' @param ifn Optional result of \code{\link{ifn_charger}} with
#'   \code{ARBRE} and \code{PLACETTE}; loaded when \code{NULL}.
#' @param campagnes Number of most recent campaigns kept. Default 15.
#' @param min_arbres,min_placettes Forest-level thresholds. Defaults 30 and 5.
#' @param ser Optional SER code; default: the majority SER of \code{units}
#'   (\code{\link{localiser_ser}}), else the majority SER of the plots found.
#' @param cible_ha Target area of the extraction zone. Default 2000.
#'
#' @return A data.frame as \code{\link{ifn_tarif_schaeffer_reference}}, with
#'   \code{niveau_utilise} \code{"foret"}, \code{"SER"}, \code{"GRECO"} or
#'   \code{"FRANCE"} and \code{n_placettes} (forest level only); attributes
#'   \code{ser} (the SER used for the fallback), \code{tampon_m} and
#'   \code{n_placettes_zone}.
#'
#' @section Lifecycle:
#' Experimental (spec 062).
#'
#' @export
tarif_schaeffer_local <- function(units, especes = NULL, ifn = NULL, campagnes = 15,
                                  min_arbres = 30, min_placettes = 5, ser = NULL,
                                  cible_ha = 2000) {
  if (!inherits(units, "sf")) cli::cli_abort("{.arg units} must be an sf object.")
  zone <- sf::st_union(sf::st_transform(sf::st_geometry(units), 2154))
  tampon <- .tampon_extract_plac(as.numeric(sf::st_area(zone)), cible_ha = cible_ha)
  zone <- sf::st_buffer(zone, tampon)
  if (is.null(ifn)) ifn <- ifn_charger(c("ARBRE", "PLACETTE"))
  pl <- as.data.frame(ifn$PLACETTE)
  pl <- pl[!duplicated(pl$IDP), c("IDP", "CAMPAGNE", "SER", "XL", "YL"), drop = FALSE]
  derniere <- max(as.integer(pl$CAMPAGNE), na.rm = TRUE)
  pl <- pl[as.integer(pl$CAMPAGNE) > derniere - campagnes, , drop = FALSE]
  pts <- sf::st_as_sf(pl, coords = c("XL", "YL"), crs = 2154)
  dedans <- pl$IDP[lengths(sf::st_intersects(pts, zone)) > 0]
  ar <- as.data.frame(ifn$ARBRE)
  ar <- ar[ar$IDP %in% dedans & as.integer(ar$CAMPAGNE) > derniere - campagnes, , drop = FALSE]
  loc <- calculer_tarifs_schaeffer(ar)

  if (is.null(ser)) {
    ser <- tryCatch({
      s <- localiser_ser(sf::st_sf(geometry = sf::st_transform(sf::st_geometry(units), 2154)))$ser
      s <- s[!is.na(s)]
      if (length(s)) names(sort(table(s), decreasing = TRUE))[1] else NULL
    }, error = function(e) NULL, warning = function(w) NULL)
    if (is.null(ser) && length(dedans)) {
      s <- pl$SER[pl$IDP %in% dedans & !is.na(pl$SER) & nzchar(pl$SER)]
      if (length(s)) ser <- names(sort(table(s), decreasing = TRUE))[1]
    }
  }
  especes <- if (is.null(especes)) unique(loc$espar) else .tarif_espar(especes)
  out <- lapply(especes, function(e) {
    l <- loc[loc$espar == e, , drop = FALSE]
    if (nrow(l) && l$n_arbres[1] >= min_arbres && l$n_placettes[1] >= min_placettes) {
      ref <- ifn_espar_correspondance(espar = e)
      return(data.frame(espar = e,
                        essence_libelle = if (nrow(ref)) ref$lib_espar[1] else NA_character_,
                        type = l$type, numero = l$numero, cv = l$cv,
                        n_arbres = l$n_arbres, niveau_utilise = "foret", code = NA_character_,
                        type_conseille = l$type[which.min(ifelse(is.na(l$cv), Inf, l$cv))],
                        part_houppier = l$part_houppier %||% NA_real_,
                        n_placettes = l$n_placettes, stringsAsFactors = FALSE))
    }
    r <- ifn_tarif_schaeffer_reference(e, ser = ser)
    r$n_placettes <- NA_integer_
    r
  })
  out <- do.call(rbind, out)
  if (is.null(out)) {
    out <- ifn_tarif_schaeffer_reference(character(0))
    out$n_placettes <- integer(0)
  }
  rownames(out) <- NULL
  attr(out, "tampon_m") <- tampon
  attr(out, "n_placettes_zone") <- length(dedans)
  attr(out, "ser") <- ser %||% NA_character_
  out
}


# ---- Export pour Marculus ---------------------------------------------

#' Export the Schaeffer tariff tables for Marculus
#'
#' Copies the three tables Marculus embeds (\code{tarifs-ifn/} of its
#' assets) and writes a \code{LISEZMOI.txt} with the IFN vintage, the date,
#' the IGN citation (Licence Ouverte Etalab 2.0) and the method credit:
#' \itemize{
#'   \item \code{ifn_tarif_schaeffer_ser.csv}
#'     (\code{niveau;code;espar;essence_libelle;type;numero;n_arbres;cv;millesime;part_houppier});
#'   \item \code{communes_ser.csv} (\code{insee;nom;departement;ser;part;greco});
#'   \item \code{ser.csv} (\code{code;nom;greco}).
#' }
#' UTF-8 without BOM, \code{;} separator, empty field for a missing value.
#' The same tables feed \code{\link{ifn_tarif_schaeffer_reference}}: one
#' chain, one vintage.
#'
#' @param dossier Destination directory (created).
#'
#' @return The paths of the written files (invisibly).
#'
#' @section Lifecycle:
#' Experimental (spec 062).
#'
#' @export
exporter_tarifs_marculus <- function(dossier) {
  dir.create(dossier, showWarnings = FALSE, recursive = TRUE)
  fichiers <- c("ifn_tarif_schaeffer_ser.csv", "communes_ser.csv", "ser.csv")
  src <- vapply(fichiers, function(f) {
    p <- system.file("extdata", f, package = "nemeton")
    if (!nzchar(p)) cli::cli_abort("File {.file extdata/{f}} not found in the nemeton installation.")
    p
  }, character(1))
  dest <- file.path(dossier, fichiers)
  if (!all(file.copy(src, dest, overwrite = TRUE))) {
    cli::cli_abort("Failed to copy the tariff tables to {.path {dossier}}.")
  }
  tab <- utils::read.csv2(dest[1], nrows = 1, colClasses = "character", encoding = "UTF-8")
  lis <- file.path(dossier, "LISEZMOI.txt")
  writeLines(enc2utf8(c(
    "Numeros de tarif Schaeffer par essence et sylvoecoregion (nemeton, spec 062)",
    "",
    paste0("Millesime IFN : ", tab$millesime[1]),
    paste0("Version nemeton : ", as.character(utils::packageVersion("nemeton"))),
    paste0("Exporte le : ", format(Sys.Date())),
    "",
    "Donnees : IGN - Inventaire forestier national francais, Donnees brutes,",
    "Campagnes annuelles 2005 et suivantes, https://inventaire-forestier.ign.fr/dataIFN/,",
    "Licence Ouverte Etalab 2.0.",
    "Contours : SER IGN/INRAE (inrae:ser_l93) ; communes Etalab contours-administratifs",
    "(derive d'ADMIN EXPRESS, Licence Ouverte).",
    "Methode : PPtools::TarifFindSch() et TarifIFN() de Max Bruciamacchie",
    "(AgroParisTech Nancy), GPL-2, reprise sous GPL-3 avec son autorisation.",
    "Part de houppier : equations EMERGE (projet ANR EMERGE, gftools::ListTarEmerge,",
    "version mai2), modele et non mesure : l'IFN ne mesure pas les branches.",
    "",
    "Valeur par defaut pour le marteleur, pas une prescription."
  )), lis, useBytes = TRUE)
  invisible(c(dest, lis))
}
