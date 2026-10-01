# ifn_production.R — production biologique IFN par SER x campagne (spec 054)
# -----------------------------------------------------------------------------
# Production recalculée depuis les données brutes IGN (Licence Ouverte Etalab
# v2.0) : l'export n'a pas de colonne de production. On la reconstruit depuis
# IR5 (accroissement radial sur 5 ans, en METRES dans la table) et C13.
#
#   PG (m2/ha/an) : exacte. C_passe = C13 - 2*pi*IR5, g = C^2 / (4*pi).
#   PV (m3/ha/an) : voie (a) de la spec 054 D1, forme et hauteur constantes,
#                   dV = V * (1 - (C_passe / C13)^2). Biais bas documente
#                   (spec 054 §3.a : -15 % a -20 % de la reference IGN).
#   Recrutement   : arbre dont C_passe < 0,2356 m (diametre 7,5 cm, methodo IGN
#                   2023) -> g et V entiers dans la production.
#
# PIEGE (spec 054 §3.a point 3, §8.9) : depuis 2014, l'IGN ne carotte qu'un
# arbre par essence x categorie de dimension (+ gros bois) ; ~47 % de la G n'a
# pas d'IR5. On impute le taux relatif rg = 1 - (C_passe/C13)^2 en cascade, et
# on RECALCULE C_passe = C13 * sqrt(1 - rg) pour les arbres imputes : sans
# cela, le test de recrutement rend NA et l'arbre sort de la somme sans bruit.

# Seuil de recensabilite IFN : diametre 7,5 cm a 1,30 m.
.IFN_C13_RECRUTEMENT <- 7.5 / 100 * pi

# Groupe d'essence : un code IFN dont le prefixe numerique est entre 51 et 79
# est un resineux (51 pin maritime ... 78) ; tout le reste est feuillu, chenes
# a un chiffre (5, 6, 7) et hetre (9 / 09) compris. Verifie sur espar-cdref13.
.ifn_groupe_espar <- function(espar) {
  n <- suppressWarnings(as.integer(sub("^([0-9]+).*$", "\\1", as.character(espar))))
  ifelse(!is.na(n) & n >= 51L & n <= 79L, "resineux", "feuillus")
}

# Categorie de dimension IFN (diametre en cm) : PB < 22,5 <= BM < 47,5 <=
# GB < 67,5 <= TGB. C'est le grain du plan de carottage depuis 2014.
.ifn_categorie_dimension <- function(c13) {
  d <- c13 / pi * 100
  cut(d, c(-Inf, 22.5, 47.5, 67.5, Inf), labels = c("PB", "BM", "GB", "TGB"),
      right = FALSE)
}

# Production par arbre. `arbres` : arbres vivants de 1re visite, colonnes
# CAMPAGNE, IDP, ESPAR, C13, IR5, V, W (numeriques pour les quatre dernieres).
# Ajoute : groupe, rg, ir5_impute, c_passe, recrute, pg, pv (par arbre et par
# an, a multiplier par W pour passer a l'hectare).
.ifn_production_arbres <- function(arbres) {
  a <- arbres
  a$groupe <- .ifn_groupe_espar(a$ESPAR)
  a$cat <- .ifn_categorie_dimension(a$C13)
  a$rg <- ifelse(is.na(a$IR5), NA_real_,
                 1 - (pmax(a$C13 - 2 * pi * a$IR5, 0) / a$C13)^2)
  a$ir5_impute <- FALSE
  plac <- paste(a$CAMPAGNE, a$IDP, sep = "_")
  cles <- list(paste(plac, a$ESPAR, a$cat), paste(plac, a$ESPAR), plac)
  for (k in cles) {
    m <- ave(a$rg, k, FUN = function(x) {
      if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
    })
    a_imputer <- is.na(a$rg) & !is.na(m)
    a$rg[a_imputer] <- m[a_imputer]
    a$ir5_impute[a_imputer] <- TRUE
  }
  # Le piege : C_passe se deduit de rg, pas de IR5 (vide pour un impute).
  a$c_passe <- a$C13 * sqrt(1 - a$rg)
  a$recrute <- a$c_passe < .IFN_C13_RECRUTEMENT
  g <- a$C13^2 / (4 * pi)
  v <- ifelse(is.na(a$V), 0, a$V)
  a$pg <- ifelse(a$recrute, g, g * a$rg) / 5
  a$pv <- ifelse(a$recrute, v, v * a$rg) / 5
  a$g <- g
  a
}

# Production par placette et par groupe. `placettes` : placettes de 1re visite
# (CAMPAGNE, IDP, SER) ; une placette sans arbre recensable vaut 0 (depuis
# 2015, toute placette de l'export est en foret disponible pour la production :
# c'est le denominateur de l'IGN). `arbres` : sortie de .ifn_production_arbres().
# Retour : une ligne par placette x groupe ("tous", "feuillus", "resineux"),
# colonnes CAMPAGNE, IDP, SER, groupe, pg, pv, g_tot, g_sans_valeur, g_imputee.
.ifn_production_placettes <- function(arbres, placettes) {
  a <- arbres
  a$w_g <- a$W * a$g
  a$w_pg <- a$W * a$pg
  a$w_pv <- a$W * a$pv
  a$w_g_nv <- ifelse(is.na(a$rg), a$w_g, 0)
  a$w_g_imp <- ifelse(a$ir5_impute, a$w_g, 0)
  sommer <- function(d, groupe) {
    if (nrow(d) == 0L) {
      return(data.frame(CAMPAGNE = character(0), IDP = character(0),
                        groupe = character(0), pg = numeric(0),
                        pv = numeric(0), g_tot = numeric(0),
                        g_sans_valeur = numeric(0), g_imputee = numeric(0)))
    }
    s <- stats::aggregate(
      cbind(pg = w_pg, pv = w_pv, g_tot = w_g, g_sans_valeur = w_g_nv,
            g_imputee = w_g_imp) ~ CAMPAGNE + IDP,
      data = d, FUN = sum, na.rm = TRUE, na.action = stats::na.pass
    )
    s$groupe <- groupe
    s
  }
  parts <- list(sommer(a, "tous"),
                sommer(a[a$groupe == "feuillus", , drop = FALSE], "feuillus"),
                sommer(a[a$groupe == "resineux", , drop = FALSE], "resineux"))
  s <- do.call(rbind, parts)
  pl <- unique(placettes[, c("CAMPAGNE", "IDP", "SER")])
  grille <- merge(pl, data.frame(groupe = c("tous", "feuillus", "resineux")),
                  by = NULL)
  out <- merge(grille, s, by = c("CAMPAGNE", "IDP", "groupe"), all.x = TRUE)
  for (j in c("pg", "pv", "g_tot", "g_sans_valeur", "g_imputee")) {
    out[[j]][is.na(out[[j]])] <- 0
  }
  out
}

# Estimation directe par domaine : moyenne des placettes, variance de la
# moyenne psi = var / n (spec 054 §4). `cle` : vecteur de domaine.
.ifn_production_direct <- function(valeur, cle) {
  n <- tapply(valeur, cle, length)
  moy <- tapply(valeur, cle, mean)
  v <- tapply(valeur, cle, stats::var)
  data.frame(cle = names(n), n_plac = as.integer(n), direct = as.numeric(moy),
             psi = as.numeric(v) / as.numeric(n), stringsAsFactors = FALSE)
}

.ifn_prod_table <- function() .ifn_table("ifn_production_ser.csv")

#' IFN biological production by sylvoecoregion and campaign
#'
#' @description
#' Returns the bundled table of annual biological production recomputed from
#' the IGN raw forest-inventory data, per sylvoecoregion (SER) and campaign,
#' with a Fay-Herriot small-area estimate and its uncertainty (spec 054).
#'
#' Two attributes: `"pg"`, basal-area production (m2/ha/yr), exact; and
#' `"pv"`, volume production (m3/ha/yr), computed under a constant form and
#' height assumption, which biases it low (about 15-20 percent under the
#' published IGN figure, see the `methode_pv` column and spec 054 §3.a).
#'
#' Campaign `t` measures the growth of years `t-5` to `t-1`.
#'
#' @param ser,greco Optional SER / GRECO codes to filter on.
#' @param campagne Optional campaign year(s).
#' @param attribut Optional `"pg"` and/or `"pv"`.
#' @param groupe Optional `"tous"`, `"feuillus"` and/or `"resineux"`.
#' @param niveau Optional `"ser"`, `"greco"` and/or `"national"`.
#'
#' @return A data.frame with columns `niveau`, `ser`, `greco`, `campagne`,
#'   `attribut`, `groupe`, `n_plac`, `direct`, `psi`, `estimation`, `mse`,
#'   `rse`, `gamma`, `nature` (`"fay_herriot"`, `"synthetique"` or
#'   `"direct"`), `methode_pv`, `covariables`, `part_g_imputee`, `millesime`,
#'   `source`. Read `nature` before using `estimation`: a synthetic value is a
#'   model prediction, not a measurement.
#'
#' @seealso [ifn_production_reference()], [estimer_fay_herriot()].
#' @export
#' @examples
#' \dontrun{
#' ifn_production_ser(ser = "C30", attribut = "pv", groupe = "tous")
#' }
ifn_production_ser <- function(ser = NULL, greco = NULL, campagne = NULL,
                               attribut = NULL, groupe = NULL, niveau = NULL) {
  d <- .ifn_prod_table()
  if (!is.null(niveau)) {
    niveau <- match.arg(niveau, c("ser", "greco", "national"), several.ok = TRUE)
    d <- d[d$niveau %in% niveau, , drop = FALSE]
  }
  if (!is.null(attribut)) {
    attribut <- match.arg(attribut, c("pg", "pv"), several.ok = TRUE)
    d <- d[d$attribut %in% attribut, , drop = FALSE]
  }
  if (!is.null(groupe)) {
    groupe <- match.arg(groupe, c("tous", "feuillus", "resineux"), several.ok = TRUE)
    d <- d[d$groupe %in% groupe, , drop = FALSE]
  }
  if (!is.null(campagne)) d <- d[d$campagne %in% campagne, , drop = FALSE]
  if (!is.null(ser)) d <- d[!is.na(d$ser) & d$ser %in% ser, , drop = FALSE]
  if (!is.null(greco)) d <- d[!is.na(d$greco) & d$greco %in% greco, , drop = FALSE]
  rownames(d) <- NULL
  d
}

#' Reference biological production to apply to a stand
#'
#' @description
#' Averages the production estimate of a sylvoecoregion over its most recent
#' campaigns (spec 054 D8), falling back to the GRECO then to the national
#' figure when the SER is unknown or absent. The level and the nature of the
#' estimate are reported, never hidden.
#'
#' The value is that of the **domain**, not of the stand: a stand inherits the
#' production of its SER.
#'
#' @param ser SER code, a single string (e.g. `"C30"`), or `NULL` for the
#'   national figure.
#' @param attribut `"pv"` (default, m3/ha/yr) or `"pg"` (m2/ha/yr).
#' @param groupe `"tous"` (default), `"feuillus"` or `"resineux"`.
#' @param n_campagnes Number of most recent campaigns to average. Default `5`.
#' @param campagnes Explicit campaign years; overrides `n_campagnes`.
#'
#' @return A one-row data.frame: `ser`, `attribut`, `groupe`, `valeur`, `mse`,
#'   `rse`, `niveau_utilise`, `nature` (the natures of the averaged rows,
#'   collapsed), `campagnes` (collapsed), `n_campagnes`. The MSE of the mean
#'   assumes independence between campaigns; it is a lower bound.
#'
#' @seealso [ifn_production_ser()].
#' @export
#' @examples
#' \dontrun{
#' ifn_production_reference("C30")
#' ifn_production_reference("C30", attribut = "pg", groupe = "resineux")
#' }
ifn_production_reference <- function(ser = NULL, attribut = c("pv", "pg"),
                                     groupe = c("tous", "feuillus", "resineux"),
                                     n_campagnes = 5L, campagnes = NULL) {
  attribut <- match.arg(attribut)
  groupe <- match.arg(groupe)
  if (!is.null(ser) && (length(ser) != 1L || is.na(ser))) {
    cli::cli_abort("{.arg ser} must be a single SER code, or NULL.")
  }
  d <- .ifn_prod_table()
  d <- d[d$attribut == attribut & d$groupe == groupe, , drop = FALSE]
  echelons <- list(
    ser = if (!is.null(ser)) d[d$niveau == "ser" & !is.na(d$ser) & d$ser == ser, ],
    greco = if (!is.null(ser)) d[d$niveau == "greco" & !is.na(d$greco) &
                                   d$greco == substr(ser, 1L, 1L), ],
    national = d[d$niveau == "national", ]
  )
  for (niv in names(echelons)) {
    e <- echelons[[niv]]
    if (is.null(e) || nrow(e) == 0L) next
    e <- e[!is.na(e$estimation), , drop = FALSE]
    if (nrow(e) == 0L) next
    if (!is.null(campagnes)) {
      e <- e[e$campagne %in% campagnes, , drop = FALSE]
    } else {
      dernieres <- utils::tail(sort(unique(e$campagne)), n_campagnes)
      e <- e[e$campagne %in% dernieres, , drop = FALSE]
    }
    if (nrow(e) == 0L) next
    k <- nrow(e)
    valeur <- mean(e$estimation)
    mse <- sum(e$mse) / k^2
    return(data.frame(
      ser = if (is.null(ser)) NA_character_ else ser,
      attribut = attribut, groupe = groupe, valeur = valeur, mse = mse,
      rse = 100 * sqrt(mse) / abs(valeur), niveau_utilise = niv,
      nature = paste(sort(unique(e$nature)), collapse = "+"),
      campagnes = paste(sort(unique(e$campagne)), collapse = ","),
      n_campagnes = k, stringsAsFactors = FALSE
    ))
  }
  data.frame(ser = if (is.null(ser)) NA_character_ else ser,
             attribut = attribut, groupe = groupe, valeur = NA_real_,
             mse = NA_real_, rse = NA_real_, niveau_utilise = NA_character_,
             nature = NA_character_, campagnes = NA_character_,
             n_campagnes = 0L, stringsAsFactors = FALSE)
}
