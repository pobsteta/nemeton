# ifn_production.R — production biologique IFN par SER x campagne (spec 054)
# -----------------------------------------------------------------------------
# Production recalculée depuis les données brutes IGN (Licence Ouverte Etalab
# v2.0) : l'export n'a pas de colonne de production. On la reconstruit depuis
# IR5 (accroissement radial sur 5 ans, en METRES dans la table) et C13.
#
#   PG (m2/ha/an) : exacte. C_passe = C13 - 2*pi*IR5, g = C^2 / (4*pi).
#   PV (m3/ha/an) : voie (b) de la spec 054 D1 (lot 1-bis). La hauteur suit le
#                   diametre selon l'allometrie H ~ D^beta, estimee dans
#                   l'IFN par groupe x categorie de dimension, donc a forme
#                   constante V ~ D^(2 + beta) :
#                   dV = V * (1 - (C_passe / C13)^(2 + beta)).
#                   beta = 0 redonne la voie (a) du lot 1 (biais -22 %).
#   Arbres coupes : production des arbres vifs au 1er passage et coupes avant
#                   la revisite (codes VEGET5 6 et 7, definition IGN), sur
#                   2,5 ans en moyenne. Le volume preleve est actualise de
#                   la meme croissance (methodo IGN 2023, p. 19).
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

# Groupe d'essence : definition unique du paquet (R/resineux.R) ; sur un code
# espar, un prefixe numerique entre 51 et 79 est un resineux, tout le reste est
# feuillu (chenes 02-07 et hetre 09 compris). Verifie sur espar-cdref13.
.ifn_groupe_espar <- function(espar) {
  ifelse(.est_resineux(espar), "resineux", "feuillus")
}

# Categorie de dimension IFN (diametre en cm) : PB < 22,5 <= BM < 47,5 <=
# GB < 67,5 <= TGB. C'est le grain du plan de carottage depuis 2014.
.ifn_categorie_dimension <- function(c13) {
  d <- c13 / pi * 100
  cut(d, c(-Inf, 22.5, 47.5, 67.5, Inf), labels = c("PB", "BM", "GB", "TGB"),
      right = FALSE)
}

# Exposant beta de l'allometrie hauteur-diametre H ~ D^beta, par groupe x
# categorie de dimension, estime DANS chaque placette x essence (au moins
# 3 arbres mesures en hauteur) pour retirer l'effet station. `arbres` :
# CAMPAGNE, IDP, ESPAR, C13, HTOT. Retour : groupe, cat, beta, n.
.ifn_beta_hauteur <- function(arbres, min_arbres = 3L) {
  a <- arbres[!is.na(arbres$HTOT) & arbres$HTOT > 1.3 & !is.na(arbres$C13) &
                arbres$C13 > 0, , drop = FALSE]
  a$groupe <- .ifn_groupe_espar(a$ESPAR)
  a$cat <- .ifn_categorie_dimension(a$C13)
  k <- paste(a$CAMPAGNE, a$IDP, a$ESPAR)
  n <- ave(a$C13, k, FUN = length)
  a <- a[n >= min_arbres, , drop = FALSE]
  k <- k[n >= min_arbres]
  lh <- log(a$HTOT)
  lc <- log(a$C13)
  lh0 <- lh - ave(lh, k)
  lc0 <- lc - ave(lc, k)
  cle <- paste(a$groupe, a$cat)
  out <- data.frame(
    groupe = tapply(a$groupe, cle, `[`, 1),
    cat = tapply(as.character(a$cat), cle, `[`, 1),
    beta = tapply(lh0 * lc0, cle, sum) / tapply(lc0^2, cle, sum),
    n = as.integer(tapply(lh0, cle, length)),
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out
}

# Exposant beta de chaque arbre : scalaire, ou table groupe x cat issue de
# .ifn_beta_hauteur() (0 si la cellule manque, c'est-a-dire voie (a)).
.ifn_beta_arbre <- function(groupe, cat, beta) {
  if (is.numeric(beta) && length(beta) == 1L) return(rep(beta, length(groupe)))
  b <- beta$beta[match(paste(groupe, cat), paste(beta$groupe, beta$cat))]
  b[is.na(b)] <- 0
  b
}

# Production par arbre. `arbres` : arbres vivants de 1re visite, colonnes
# CAMPAGNE, IDP, ESPAR, C13, IR5, V, W (numeriques pour les quatre dernieres).
# `beta` : exposant hauteur-diametre (scalaire ou table, cf. .ifn_beta_arbre).
# Ajoute : groupe, rg (fraction de g produite en 5 ans), rv (idem en volume),
# ir5_impute, c_passe, recrute, pg, pv (par arbre et par an, a multiplier par
# W pour passer a l'hectare).
.ifn_production_arbres <- function(arbres, beta = 0) {
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
  # Volume : V ~ D^(2 + beta) a forme constante, donc
  # V_passe / V = (C_passe / C13)^(2 + beta) = (1 - rg)^((2 + beta) / 2).
  a$beta <- .ifn_beta_arbre(a$groupe, a$cat, beta)
  a$rv <- 1 - (1 - a$rg)^((2 + a$beta) / 2)
  g <- a$C13^2 / (4 * pi)
  v <- ifelse(is.na(a$V), 0, a$V)
  a$pg <- ifelse(a$recrute, g, g * a$rg) / 5
  a$pv <- ifelse(a$recrute, v, v * a$rv) / 5
  a$g <- g
  a
}

# Arbres coupes entre le 1er passage (campagne t-5) et la revisite (t).
# `arbres` : sortie de .ifn_production_arbres() sur les arbres de 1re visite,
# avec la colonne A. `coupes` : IDP, A, VEGET5 ("6" coupe vidange, "7" coupe
# non vidange), CAMPAGNE (de revisite). Par arbre et par an (x W pour l'ha) :
#   pv_coupe, pg_coupe : croissance avant la coupe, 2,5 ans sur 5 en moyenne ;
#   prel, prel_vidange : volume preleve actualise a la date mediane de coupe,
#                        tous codes (definition IGN) ou code 6 seul (spec 040).
.ifn_production_coupes <- function(arbres, coupes) {
  cle_a <- paste(arbres$IDP, arbres$A)
  i <- match(paste(coupes$IDP, coupes$A), cle_a)
  ok <- !is.na(i)
  a <- arbres[i[ok], , drop = FALSE]
  a$CAMPAGNE <- coupes$CAMPAGNE[ok]
  a$VEGET5 <- coupes$VEGET5[ok]
  v <- ifelse(is.na(a$V), 0, a$V)
  g <- a$C13^2 / (4 * pi)
  rv <- ifelse(is.na(a$rv), 0, a$rv)
  rg <- ifelse(is.na(a$rg), 0, a$rg)
  a$pv_coupe <- v * rv * 0.5 / 5
  a$pg_coupe <- g * rg * 0.5 / 5
  a$prel <- v * (1 + rv / 2) / 5
  a$prel_vidange <- ifelse(a$VEGET5 == "6", a$prel, 0)
  a
}

# Sommes a l'hectare par placette x groupe pour des colonnes de valeurs
# donnees ; une placette sans arbre vaut 0. Commun aux arbres vifs et coupes.
.ifn_sommer_placettes <- function(arbres, placettes, colonnes) {
  pl <- unique(placettes[, c("CAMPAGNE", "IDP", "SER")])
  grille <- merge(pl, data.frame(groupe = c("tous", "feuillus", "resineux")),
                  by = NULL)
  if (nrow(arbres) == 0L) {
    for (j in colonnes) grille[[j]] <- 0
    return(grille)
  }
  w <- as.data.frame(lapply(arbres[colonnes], function(x) arbres$W * x))
  parts <- list()
  for (gr in c("tous", "feuillus", "resineux")) {
    sel <- if (gr == "tous") rep(TRUE, nrow(arbres)) else arbres$groupe == gr
    if (!any(sel)) next
    cle <- paste(arbres$CAMPAGNE[sel], arbres$IDP[sel], sep = "|")
    s <- rowsum(w[sel, , drop = FALSE], cle, na.rm = TRUE)
    morceaux <- strsplit(rownames(s), "|", fixed = TRUE)
    parts[[gr]] <- data.frame(CAMPAGNE = vapply(morceaux, `[`, "", 1L),
                              IDP = vapply(morceaux, `[`, "", 2L),
                              groupe = gr, s, stringsAsFactors = FALSE,
                              row.names = NULL)
  }
  s <- do.call(rbind, parts)
  out <- merge(grille, s, by = c("CAMPAGNE", "IDP", "groupe"), all.x = TRUE)
  for (j in colonnes) out[[j]][is.na(out[[j]])] <- 0
  out
}

# Production par placette et par groupe. `placettes` : placettes de 1re visite
# (CAMPAGNE, IDP, SER) ; une placette sans arbre recensable vaut 0 (depuis
# 2015, toute placette de l'export est en foret disponible pour la production :
# c'est le denominateur de l'IGN). `arbres` : sortie de .ifn_production_arbres().
# Retour : une ligne par placette x groupe ("tous", "feuillus", "resineux"),
# colonnes CAMPAGNE, IDP, SER, groupe, pg, pv, g_tot, g_sans_valeur, g_imputee.
.ifn_production_placettes <- function(arbres, placettes) {
  a <- arbres
  a$g_tot <- a$g
  a$g_sans_valeur <- ifelse(is.na(a$rg), a$g, 0)
  a$g_imputee <- ifelse(a$ir5_impute, a$g, 0)
  .ifn_sommer_placettes(a, placettes,
                        c("pg", "pv", "g_tot", "g_sans_valeur", "g_imputee"))
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
#' Four attributes, all per hectare and per year:
#' * `"pg"`: basal-area production (m2/ha/yr), exact from the increment cores;
#' * `"pv"`: volume production (m3/ha/yr). Height growth follows diameter
#'   growth through the height-diameter allometry estimated in the inventory
#'   (`methode_pv = "allometrie_hauteur_diametre"`), and the growth of trees
#'   felled between two visits is included, as in the IGN definition. National
#'   check: 97 percent of the published IGN figure (spec 054 section 3.c);
#' * `"prel"`: harvested volume (m3/ha/yr), all felled trees (IGN definition);
#' * `"prel_vidange"`: harvested volume of trees felled **and extracted**
#'   (`VEGET5 == "6"`), the definition used for forest roads (spec 040).
#'
#' Campaign `t` measures the growth of years `t-5` to `t-1`, and the harvest
#' between the first visit of a plot (`t-5`) and its revisit (`t`).
#'
#' **Groups are contributions, not stand figures.** The `"feuillus"` and
#' `"resineux"` rows are per hectare of the **whole** forest of the domain
#' (plots without the group count as zero), so that the groups add up to
#' `"tous"`. They are not the production of a hectare of broadleaf or
#' conifer stand. Ratios between two attributes of the same group (e.g.
#' harvest / production) remain meaningful.
#'
#' @param ser,greco Optional SER / GRECO codes to filter on.
#' @param campagne Optional campaign year(s).
#' @param attribut Optional `"pg"`, `"pv"`, `"prel"` and/or `"prel_vidange"`.
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
    attribut <- match.arg(attribut, c("pg", "pv", "prel", "prel_vidange"),
                          several.ok = TRUE)
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
#' @param attribut `"pv"` (default, m3/ha/yr), `"pg"` (m2/ha/yr), `"prel"` or
#'   `"prel_vidange"` (harvest, m3/ha/yr; see [ifn_production_ser()]).
#' @param groupe `"tous"` (default), `"feuillus"` or `"resineux"`.
#' @param n_campagnes Number of most recent campaigns to average. Default `5`.
#' @param campagnes Explicit campaign years; overrides `n_campagnes`.
#' @param niveaux Levels the fallback may use, in this order. Default all
#'   three; restrict it to pin a level (e.g. to align two flows).
#' @param min_plac Minimum number of plots, summed over the campaign window,
#'   for a **direct** estimate to qualify a SER or GRECO level; below it the
#'   fallback moves up. Fay-Herriot estimates are not subject to it. Default
#'   `30`, as in [ifn_volume_reference()].
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
ifn_production_reference <- function(ser = NULL,
                                     attribut = c("pv", "pg", "prel", "prel_vidange"),
                                     groupe = c("tous", "feuillus", "resineux"),
                                     n_campagnes = 5L, campagnes = NULL,
                                     niveaux = c("ser", "greco", "national"),
                                     min_plac = 30) {
  attribut <- match.arg(attribut)
  groupe <- match.arg(groupe)
  niveaux <- match.arg(niveaux, several.ok = TRUE)
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
  for (niv in intersect(names(echelons), niveaux)) {
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
    # Une estimation directe sur trop peu de placettes ne qualifie pas le
    # niveau (cascade de la spec 040) : en SER "Marais littoraux", une seule
    # coupe sur 3 placettes donnait 79 m3/ha/an. Le Fay-Herriot, lui, tient.
    if (niv != "national" && all(e$nature == "direct") &&
        sum(e$n_plac, na.rm = TRUE) < min_plac) next
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

#' Harvest to production ratio by sylvoecoregion
#'
#' @description
#' Divides the harvested volume by the biological volume production of a
#' sylvoecoregion, over the same campaigns: both flows cover the same growing
#' seasons (spec 054 section 7.2). A ratio above 1 means the domain harvests
#' more than it grows (decapitalisation), below 1 that it capitalises.
#'
#' **Known bias.** Nationally the ratio is 0.67 against 0.61 published by the
#' IGN for 2014-2022 (about +10 percent, spec 054 section 3.c). A ratio
#' slightly above 1 is therefore not proof of decapitalisation.
#'
#' @param ser SER code, a single string, or `NULL` for the national figure.
#' @param groupe `"tous"` (default), `"feuillus"` or `"resineux"`.
#' @param definition `"ign"` (default): every felled tree, as the IGN counts
#'   harvest; `"vidange"`: felled **and extracted** trees only, the definition
#'   used for forest roads (spec 040).
#' @param n_campagnes,campagnes,min_plac Campaign window and minimum number of
#'   revisited plots, as in [ifn_production_reference()]. The harvest estimate
#'   sets the level; the production is taken at the same level and campaigns.
#'
#' @return A one-row data.frame: `ser`, `groupe`, `definition`, `prelevement`
#'   and `production` (m3/ha/yr), `ratio`, `rse` (percent, delta method under
#'   independence of the two estimates), `niveau_utilise`, `campagnes`.
#'
#' @seealso [ifn_production_reference()], [ifn_taux_prelevement()].
#' @export
#' @examples
#' \dontrun{
#' ifn_taux_prelevement_production("C30")
#' ifn_taux_prelevement_production(NULL)   # national, about 0.67
#' }
ifn_taux_prelevement_production <- function(ser = NULL,
                                            groupe = c("tous", "feuillus", "resineux"),
                                            definition = c("ign", "vidange"),
                                            n_campagnes = 5L, campagnes = NULL,
                                            min_plac = 30) {
  groupe <- match.arg(groupe)
  definition <- match.arg(definition)
  att_prel <- if (definition == "ign") "prel" else "prel_vidange"
  # Le prelevement (estimation directe) fixe le niveau ; la production est
  # alignee sur ce niveau et sur ses campagnes : deux flux comparables.
  prel <- ifn_production_reference(ser, att_prel, groupe, n_campagnes, campagnes,
                                   min_plac = min_plac)
  vide <- data.frame(ser = if (is.null(ser)) NA_character_ else ser,
                     groupe = groupe, definition = definition,
                     prelevement = NA_real_, production = NA_real_,
                     ratio = NA_real_, rse = NA_real_,
                     niveau_utilise = NA_character_, campagnes = NA_character_,
                     stringsAsFactors = FALSE)
  if (is.na(prel$valeur)) return(vide)
  camp <- as.integer(strsplit(prel$campagnes, ",", fixed = TRUE)[[1]])
  prod <- ifn_production_reference(ser, "pv", groupe, campagnes = camp,
                                   niveaux = prel$niveau_utilise, min_plac = 0)
  if (is.na(prod$valeur)) return(vide)
  ratio <- prel$valeur / prod$valeur
  data.frame(
    ser = prel$ser, groupe = groupe, definition = definition,
    prelevement = prel$valeur, production = prod$valeur, ratio = ratio,
    rse = sqrt(prel$rse^2 + prod$rse^2),
    niveau_utilise = prod$niveau_utilise, campagnes = prod$campagnes,
    stringsAsFactors = FALSE
  )
}
