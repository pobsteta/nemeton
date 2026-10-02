# ifn_production_domaines.R — production IFN de domaines quelconques (spec 054 lots 5 et 5-bis)
# -----------------------------------------------------------------------------
# Estimateur composite pour un domaine fourni par l'utilisateur (UT ONF,
# massif, foret) :
#
#   gamma = A(S) / (A(S) + psi)
#   estimation = gamma * direct + (1 - gamma) * prediction
#   mse = gamma * psi
#
# - direct     : moyenne des placettes IFN du domaine (vives + coupees) ;
# - prediction : estimations Fay-Herriot des SER du domaine, ponderees par la
#                part des placettes ("ser") ; pour PV, avec les covariables du
#                domaine, corrigee de l'ecart de ses covariables a celles de
#                ses SER ("hybride", lot 5-bis) ;
# - A(S)       : MSE du predicteur face a la verite d'un domaine de surface S,
#                calee sur des mailles de 15 a 100 km (data-raw/
#                calibrer_domaines.R) : log A = a + b log S. Elle remplace le
#                sigma2_v national du lot 5, qui sous-estimait l'erreur des
#                petits domaines (0,43 contre 0,67 mesure a 20 km pour PV).
#
# Les placettes sont placees au centre de leur maille kilometrique (XL/YL) ; la
# placette reelle est a 700 m au plus. Une placette proche du contour peut etre
# attribuee au mauvais domaine : la part concernee est publiee (part_bordure).

.ifn_prod_placettes <- function() {
  d <- .ifn_table("ifn_production_placettes.csv.gz")
  d$ser <- as.character(d$ser)
  d
}

.ifn_prod_modele <- function() .ifn_table("ifn_production_modele.csv")
.ifn_prod_coef <- function() .ifn_table("ifn_production_modele_coef.csv")
.ifn_prod_echelle <- function() .ifn_table("ifn_production_echelle.csv")
.ifn_prod_cov_ser <- function() .ifn_table("ifn_production_covariables_ser.csv")

#' Covariates of user-defined domains for the IFN production model
#'
#' @description
#' Computes, for each domain, the covariates of the national production model
#' (spec 054) exactly as they were computed for the sylvoecoregions: mean and
#' standard deviation of canopy height over the forest pixels (height >= 5 m),
#' and mean and standard deviation of altitude weighted by those pixels.
#' Pass the result to [ifn_production_domaines()] to get the domain-specific
#' prediction (volume production only, see there).
#'
#' The model was fitted with **FORMS-T** canopy height at 10 m. Another canopy
#' height model (LiDAR, Open-Canopy) has a different distribution and would
#' bias the prediction.
#'
#' @param domaines An `sf` of polygons with a defined CRS.
#' @param hauteur A `terra::SpatRaster` of FORMS-T canopy height covering the
#'   domains.
#' @param altitude A `terra::SpatRaster` digital elevation model (m) covering
#'   the domains.
#' @param id_col Column of `domaines` identifying each domain, as in
#'   [ifn_production_domaines()]. `NULL` numbers them.
#' @param unite_hauteur Unit of `hauteur`: `"cm"` (default, FORMS-T as
#'   distributed) or `"m"`.
#' @param seuil_m Forest threshold in metres. Default `5`, as in the model.
#'
#' @return A data.frame: `id`, `h_mean`, `h_sd`, `alt_mean`, `alt_sd`,
#'   `part_foret` (share of the domain area covered by forest pixels).
#'
#' @seealso [ifn_production_domaines()].
#' @export
#' @examples
#' \dontrun{
#' h <- terra::rast("Height_2023.tif")   # FORMS-T, cm
#' cov <- ifn_covariables_domaines(ut, h, mnt, id_col = "code_ut")
#' ifn_production_domaines(ut, id_col = "code_ut", covariables = cov)
#' }
ifn_covariables_domaines <- function(domaines, hauteur, altitude, id_col = NULL,
                                     unite_hauteur = c("cm", "m"), seuil_m = 5) {
  unite_hauteur <- match.arg(unite_hauteur)
  if (!inherits(domaines, "sf")) cli::cli_abort("{.arg domaines} must be an sf object.")
  if (!inherits(hauteur, "SpatRaster") || !inherits(altitude, "SpatRaster")) {
    cli::cli_abort("{.arg hauteur} and {.arg altitude} must be terra SpatRasters.")
  }
  ids <- if (is.null(id_col)) as.character(seq_len(nrow(domaines))) else {
    if (!id_col %in% names(domaines)) cli::cli_abort("Column {.val {id_col}} not found.")
    as.character(domaines[[id_col]])
  }
  k <- if (unite_hauteur == "cm") 0.01 else 1
  dom <- sf::st_transform(domaines, terra::crs(hauteur))
  h <- terra::crop(hauteur[[1]], terra::vect(dom), snap = "out") * k
  foret <- terra::ifel(!is.na(h) & h >= seuil_m, 1, 0)
  hf <- terra::ifel(foret == 1, h, 0)
  # Reprojeter / reechantillonner seulement si besoin : sur le runner CI,
  # terra/GDAL echoue sur un warp qui ne change rien ("could not find valid
  # method", 2026-10-01), que ce soit project() vers le meme CRS ou
  # resample() vers la meme grille.
  alt <- altitude[[1]]
  if (!terra::same.crs(alt, h)) alt <- terra::project(alt, terra::crs(h))
  if (!terra::compareGeom(alt, h, stopOnError = FALSE)) {
    alt <- terra::resample(alt, h, method = "bilinear")
  }
  af <- terra::ifel(foret == 1 & !is.na(alt), alt, 0)
  nalt <- terra::ifel(foret == 1 & !is.na(alt), 1, 0)
  st <- c(foret, hf, hf^2, nalt, af, af^2)
  names(st) <- c("n", "s1", "s2", "na", "a1", "a2")
  e <- exactextractr::exact_extract(st, dom, "sum", progress = FALSE)
  names(e) <- names(st)
  aire_pix <- prod(terra::res(h))
  data.frame(
    id = ids,
    h_mean = ifelse(e$n > 0, e$s1 / e$n, NA_real_),
    h_sd = ifelse(e$n > 0, sqrt(pmax(e$s2 / e$n - (e$s1 / e$n)^2, 0)), NA_real_),
    alt_mean = ifelse(e$na > 0, e$a1 / e$na, NA_real_),
    alt_sd = ifelse(e$na > 0, sqrt(pmax(e$a2 / e$na - (e$a1 / e$na)^2, 0)), NA_real_),
    part_foret = e$n * aire_pix / as.numeric(sf::st_area(dom)),
    stringsAsFactors = FALSE
  )
}

#' IFN production of user-defined domains
#'
#' @description
#' Estimates the annual biological production of arbitrary domains (forest
#' management units, massifs, forests) from the national forest inventory
#' plots that fall inside them, combined with a prediction drawn from their
#' sylvoecoregion(s) (spec 054 lots 5 and 5-bis).
#'
#' For each domain and campaign, the direct mean of its plots is shrunk
#' towards the prediction with the weight `gamma = A(S) / (A(S) + psi)`,
#' where `psi` is the sampling variance of the direct mean and `A(S)` the
#' error of the prediction for a domain of area `S`, calibrated on grid cells
#' of 15 to 100 km. A domain with many plots keeps its own figure; a domain
#' with few plots leans on the prediction. Campaigns are then averaged as in
#' [ifn_production_reference()].
#'
#' Two predictions:
#' * `"ser"`: the Fay-Herriot estimates of the domain's sylvoecoregions,
#'   weighted by the share of its plots in each.
#' * `"hybride"` (volume production only, when `covariables` is supplied): the
#'   same, corrected by the national model coefficients for the gap between
#'   the domain's covariates and those of its sylvoecoregions. Validated
#'   against the inventory on grid cells: 19 to 35 percent lower error than
#'   `"ser"` for `"pv"`, but no gain for `"pg"`, which therefore keeps `"ser"`.
#'
#' @section Limits to state alongside the figures:
#' * `A(S)` is calibrated between 22 500 ha (15 km cells) and 1 million ha;
#'   outside that range it is extrapolated (`hors_calibrage = TRUE`).
#' * Below 10 plots in a campaign, the sampling variance of the direct mean
#'   is taken from the plot-level variance of the domain's SER (generalised
#'   variance function), the direct variance being unstable.
#' * The public IFN coordinates are the centre of the 1 km grid cell, the real
#'   plot lying within 700 m of it. Plots near a domain boundary may be
#'   assigned to the wrong side; their share is reported in `part_bordure`.
#'
#' @param domaines An `sf` of polygons with a defined CRS.
#' @param attribut `"pv"` (default, m3/ha/yr) or `"pg"` (m2/ha/yr).
#' @param id_col Column of `domaines` identifying each domain. `NULL`
#'   (default) numbers them.
#' @param n_campagnes,campagnes Campaign window, as in
#'   [ifn_production_reference()]. Only the campaigns of the national model
#'   are available (2019-2024).
#' @param ser_layer Optional SER outlines passed to [localiser_ser()], used
#'   only for a domain without any plot.
#' @param covariables Optional output of [ifn_covariables_domaines()] (same
#'   `id`s). Enables the `"hybride"` prediction for `"pv"`.
#'
#' @return A data.frame with one row per domain: `id`, `attribut`, `valeur`,
#'   `mse`, `rse` (percent), `n_placettes` (live-tree plots over the window),
#'   `poids_direct` (mean `gamma`), `part_bordure` (share of plots within 700 m
#'   of the boundary), `ser` (SER weights, e.g. `"C30:0.80,C20:0.20"`),
#'   `surface_ha`, `predicteur` (`"ser"` or `"hybride"`), `variance_domaine`
#'   (`A(S)`), `hors_calibrage`, `nature` (`"composite"`, or `"prediction"` for
#'   a domain without plots), `campagnes`. The per-campaign detail is in the
#'   `detail` attribute.
#'
#' @seealso [ifn_covariables_domaines()], [ifn_production_reference()],
#'   [localiser_ser()].
#' @export
#' @examples
#' \dontrun{
#' ut <- sf::st_read("ut_onf.gpkg")
#' ifn_production_domaines(ut, id_col = "code_ut")
#' }
ifn_production_domaines <- function(domaines, attribut = c("pv", "pg"),
                                    id_col = NULL, n_campagnes = 5L,
                                    campagnes = NULL, ser_layer = NULL,
                                    covariables = NULL) {
  attribut <- match.arg(attribut)
  if (!inherits(domaines, "sf")) cli::cli_abort("{.arg domaines} must be an sf object.")
  if (is.na(sf::st_crs(domaines))) cli::cli_abort("{.arg domaines} must have a defined CRS.")
  if (nrow(domaines) == 0L) cli::cli_abort("{.arg domaines} is empty.")
  ids <- if (is.null(id_col)) as.character(seq_len(nrow(domaines))) else {
    if (!id_col %in% names(domaines)) cli::cli_abort("Column {.val {id_col}} not found.")
    as.character(domaines[[id_col]])
  }
  geom <- sf::st_make_valid(sf::st_transform(sf::st_geometry(domaines), 2154))

  pl <- .ifn_prod_placettes()
  disp <- sort(unique(pl$campagne))
  camp <- if (!is.null(campagnes)) intersect(campagnes, disp) else utils::tail(disp, n_campagnes)
  if (!length(camp)) cli::cli_abort("No campaign available in {.val {disp}}.")
  pl <- pl[pl$campagne %in% camp, , drop = FALSE]
  pts <- sf::st_as_sf(pl, coords = c("xl", "yl"), crs = 2154)
  dans <- sf::st_intersects(geom, pts)

  # Predicteur et variance calee selon la surface.
  ech <- .ifn_prod_echelle()
  ech <- ech[ech$attribut == attribut & ech$servi, , drop = FALSE]
  hybride <- !is.null(covariables) && "hybride" %in% ech$predicteur
  if (!is.null(covariables) && !hybride) {
    cli::cli_inform("{.arg covariables} unused for {.val {attribut}}: the hybrid prediction did not beat the SER one in validation.")
  }
  e_pred <- ech[ech$predicteur == if (hybride) "hybride" else "ser", , drop = FALSE]
  if (hybride) {
    if (!all(c("id", "h_mean", "h_sd", "alt_mean", "alt_sd") %in% names(covariables))) {
      cli::cli_abort("{.arg covariables} must come from {.fn ifn_covariables_domaines}.")
    }
    cf <- .ifn_prod_coef()
    cf <- cf[cf$attribut == attribut & !is.na(cf$centre), , drop = FALSE]
    cov_ser <- .ifn_prod_cov_ser()
  }

  ser_tab <- ifn_production_ser(niveau = "ser", attribut = attribut, groupe = "tous",
                                campagne = camp)
  # GVF : sous 10 placettes, la variance directe est instable (2 placettes
  # presque egales donnaient psi = 0,0003 et gamma = 0,999). On prend la
  # variance par placette de la SER pour la campagne, divisee par n.
  cle_s2 <- paste(pl$echantillon, pl$ser, pl$campagne)
  s2_ser <- tapply(pl[[attribut]], cle_s2, stats::var)

  detail <- list()
  lignes <- vector("list", length(geom))
  for (d in seq_along(geom)) {
    k <- dans[[d]]
    p <- pl[k, , drop = FALSE]
    vif <- p[p$echantillon == "vif", , drop = FALSE]
    surface <- as.numeric(sf::st_area(geom[d])) / 1e4
    A <- exp(e_pred$a + e_pred$b * log(surface))
    hors <- surface < e_pred$surface_min_ha || surface > e_pred$surface_max_ha

    # Poids des SER : part des placettes vives (echantillon systematique, donc
    # proportionnelle a la surface). Sans placette : SER dominante du contour.
    if (nrow(vif) > 0L) {
      w <- table(vif$ser) / nrow(vif)
    } else {
      s <- localiser_ser(sf::st_sf(geometry = geom[d]), ser_layer = ser_layer)$ser
      w <- if (is.na(s)) NULL else stats::setNames(1, s)
    }

    # Correction hybride : beta x (covariables du domaine - celles de ses SER).
    delta <- 0
    if (hybride && !is.null(w)) {
      xd <- covariables[match(ids[d], as.character(covariables$id)), , drop = FALSE]
      xs <- cov_ser[match(names(w), cov_ser$ser), , drop = FALSE]
      ok <- !is.na(xs$ser)
      if (nrow(xd) == 1L && any(ok)) {
        ww <- as.numeric(w)[ok] / sum(as.numeric(w)[ok])
        termes <- vapply(seq_len(nrow(cf)), function(j) {
          v <- cf$terme[j]
          cf$beta[j] * (xd[[v]] - sum(ww * xs[[v]][ok])) / cf$echelle[j]
        }, numeric(1))
        if (all(is.finite(termes))) delta <- sum(termes)
      }
    }

    # Part des placettes a moins de 700 m du contour (coordonnees floutees).
    bord <- if (nrow(vif) > 0L) {
      dist <- as.numeric(sf::st_distance(pts[k[p$echantillon == "vif"], ],
                                         sf::st_cast(geom[d], "MULTILINESTRING")))
      mean(dist < 700)
    } else NA_real_

    var_ech <- function(x, ech_nom, t) {
      # Variance de la moyenne d'un echantillon : directe a partir de 10
      # placettes, sinon GVF (variance par placette des SER du domaine).
      if (!length(x)) return(0)
      if (length(x) >= 10L) return(stats::var(x) / length(x))
      if (is.null(w)) return(NA_real_)
      s2 <- s2_ser[paste(ech_nom, names(w), t)]
      ok <- !is.na(s2)
      if (!any(ok)) return(NA_real_)
      sum(as.numeric(w)[ok] * s2[ok]) / sum(as.numeric(w)[ok]) / length(x)
    }
    par_camp <- lapply(camp, function(t) {
      a <- vif[[attribut]][vif$campagne == t]
      b <- p[[attribut]][p$echantillon == "coupe" & p$campagne == t]
      direct <- if (length(a)) mean(a) + (if (length(b)) mean(b) else 0) else NA_real_
      psi <- if (length(a)) var_ech(a, "vif", t) + var_ech(b, "coupe", t) else NA_real_
      if (is.null(w)) return(NULL)
      st <- ser_tab[ser_tab$campagne == t & ser_tab$ser %in% names(w), , drop = FALSE]
      if (!nrow(st)) return(NULL)
      ww <- as.numeric(w[st$ser]) / sum(w[st$ser])
      pred_ser <- sum(ww * st$estimation)
      pred <- pred_ser + delta
      if (is.na(psi) || psi <= 0) {
        gamma <- 0; est <- pred; mse <- A
      } else {
        gamma <- A / (A + psi)
        est <- gamma * direct + (1 - gamma) * pred
        mse <- gamma * psi
      }
      data.frame(id = ids[d], campagne = t, n_vif = length(a), n_coupe = length(b),
                 direct = direct, psi = psi, ser = pred_ser, prediction = pred,
                 gamma = gamma, estimation = est, mse = mse)
    })
    dc <- do.call(rbind, par_camp)
    detail[[d]] <- dc
    base <- data.frame(id = ids[d], attribut = attribut, valeur = NA_real_,
                       mse = NA_real_, rse = NA_real_, n_placettes = nrow(vif),
                       poids_direct = NA_real_, part_bordure = bord,
                       ser = NA_character_, surface_ha = surface,
                       predicteur = if (hybride) "hybride" else "ser",
                       variance_domaine = A, hors_calibrage = hors,
                       nature = NA_character_, campagnes = NA_character_,
                       stringsAsFactors = FALSE)
    if (is.null(dc) || !nrow(dc)) {
      lignes[[d]] <- base
      next
    }
    kk <- nrow(dc)
    base$valeur <- mean(dc$estimation)
    base$mse <- sum(dc$mse) / kk^2
    base$rse <- 100 * sqrt(base$mse) / abs(base$valeur)
    base$poids_direct <- mean(dc$gamma)
    base$ser <- paste(sprintf("%s:%.2f", names(w), as.numeric(w)), collapse = ",")
    base$nature <- if (nrow(vif) > 0L) "composite" else "prediction"
    base$campagnes <- paste(dc$campagne, collapse = ",")
    lignes[[d]] <- base
  }
  out <- do.call(rbind, lignes)
  rownames(out) <- NULL
  attr(out, "detail") <- do.call(rbind, detail)
  out
}
