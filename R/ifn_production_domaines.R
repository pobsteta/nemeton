# ifn_production_domaines.R — production IFN de domaines quelconques (spec 054 lot 5)
# -----------------------------------------------------------------------------
# Estimateur composite (decision 2026-10-01) pour un domaine fourni par
# l'utilisateur (UT ONF, massif, foret) : la moyenne directe des placettes IFN
# du domaine est combinee a l'estimation Fay-Herriot de sa (ses) SER, avec la
# variance entre domaines sigma2_v du modele national :
#
#   gamma = (A + m_s) / (A + m_s + psi)      A = sigma2_v national
#   estimation = gamma * direct + (1 - gamma) * ser     m_s = MSE de la SER
#   mse = gamma * psi
#
# C'est l'EBLUP a A connu, la SER jouant le role de prediction synthetique.
# Approximation assumee : A a ete estime entre SER ; entre sous-domaines d'une
# meme SER, la variance vraie peut differer. Pas de FORMS-T a l'execution.
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

#' IFN production of user-defined domains
#'
#' @description
#' Estimates the annual biological production of arbitrary domains (forest
#' management units, massifs, forests) from the national forest inventory
#' plots that fall inside them, combined with the Fay-Herriot estimate of
#' their sylvoecoregion(s) (spec 054 lot 5).
#'
#' For each domain and campaign, the direct mean of its plots is shrunk
#' towards the SER estimate with the weight
#' `gamma = (A + m_s) / (A + m_s + psi)`, where `psi` is the sampling variance
#' of the direct mean, `m_s` the MSE of the SER estimate and `A` the
#' between-domain variance of the national model. A domain with many plots
#' keeps its own figure; a domain with few plots leans on its SER. Campaigns
#' are then averaged as in [ifn_production_reference()].
#'
#' @section Limits to state alongside the figures:
#' * Below 10 plots in a campaign, the sampling variance of the direct mean is
#'   taken from the plot-level variance of the domain's SER (generalised
#'   variance function), the direct variance being unstable.
#' * `A` was estimated **between sylvoecoregions**. Using it for sub-domains of
#'   a SER is an approximation; the true between-domain variance at that scale
#'   may differ.
#' * The public IFN coordinates are the centre of the 1 km grid cell, the real
#'   plot lying within 700 m of it. Plots near a domain boundary may be
#'   assigned to the wrong side; their share is reported in `part_bordure`.
#'   Below a few thousand hectares, prefer the SER figure.
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
#'
#' @return A data.frame with one row per domain: `id`, `attribut`, `valeur`,
#'   `mse`, `rse` (percent), `n_placettes` (live-tree plots over the window),
#'   `poids_direct` (mean `gamma`), `part_bordure` (share of plots within 700 m
#'   of the boundary), `ser` (SER weights, e.g. `"C30:0.8,C20:0.2"`),
#'   `surface_ha`, `nature` (`"composite"` or `"ser"` for a domain without
#'   plots), `campagnes`. The per-campaign detail is in the `detail`
#'   attribute.
#'
#' @seealso [ifn_production_reference()], [localiser_ser()].
#' @export
#' @examples
#' \dontrun{
#' ut <- sf::st_read("ut_onf.gpkg")
#' ifn_production_domaines(ut, id_col = "code_ut")
#' }
ifn_production_domaines <- function(domaines, attribut = c("pv", "pg"),
                                    id_col = NULL, n_campagnes = 5L,
                                    campagnes = NULL, ser_layer = NULL) {
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

  A <- .ifn_prod_modele()
  A <- A$sigma2_v[A$attribut == attribut]
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

    # Poids des SER : part des placettes vives (echantillon systematique, donc
    # proportionnelle a la surface). Sans placette : SER dominante du contour.
    if (nrow(vif) > 0L) {
      w <- table(vif$ser) / nrow(vif)
    } else {
      s <- localiser_ser(sf::st_sf(geometry = geom[d]), ser_layer = ser_layer)$ser
      w <- if (is.na(s)) NULL else stats::setNames(1, s)
    }

    # Part des placettes a moins de 700 m du contour (coordonnees floutees).
    bord <- if (nrow(vif) > 0L) {
      dist <- as.numeric(sf::st_distance(pts[k[p$echantillon == "vif"], ],
                                         sf::st_cast(geom[d], "MULTILINESTRING")))
      mean(dist < 700)
    } else NA_real_

    var_ech <- function(x, ech, t) {
      # Variance de la moyenne d'un echantillon : directe a partir de 10
      # placettes, sinon GVF (variance par placette des SER du domaine).
      if (!length(x)) return(0)
      if (length(x) >= 10L) return(stats::var(x) / length(x))
      if (is.null(w)) return(NA_real_)
      s2 <- s2_ser[paste(ech, names(w), t)]
      ok <- !is.na(s2)
      if (!any(ok)) return(NA_real_)
      sum(as.numeric(w)[ok] * s2[ok]) / sum(as.numeric(w)[ok]) / length(x)
    }
    par_camp <- lapply(camp, function(t) {
      a <- vif[[attribut]][vif$campagne == t]
      b <- p[[attribut]][p$echantillon == "coupe" & p$campagne == t]
      direct <- if (length(a)) mean(a) + (if (length(b)) mean(b) else 0) else NA_real_
      psi <- if (length(a)) var_ech(a, "vif", t) + var_ech(b, "coupe", t) else NA_real_
      # Estimation synthetique : SER ponderees, MSE sous independance.
      if (is.null(w)) return(NULL)
      st <- ser_tab[ser_tab$campagne == t & ser_tab$ser %in% names(w), , drop = FALSE]
      if (!nrow(st)) return(NULL)
      ww <- as.numeric(w[st$ser]) / sum(w[st$ser])
      synth <- sum(ww * st$estimation)
      m_s <- sum(ww^2 * st$mse)
      if (is.na(psi) || psi <= 0) {
        gamma <- 0; est <- synth; mse <- A + m_s
      } else {
        gamma <- (A + m_s) / (A + m_s + psi)
        est <- gamma * direct + (1 - gamma) * synth
        mse <- gamma * psi
      }
      data.frame(id = ids[d], campagne = t, n_vif = length(a), n_coupe = length(b),
                 direct = direct, psi = psi, ser = synth, mse_ser = m_s,
                 gamma = gamma, estimation = est, mse = mse)
    })
    dc <- do.call(rbind, par_camp)
    detail[[d]] <- dc
    if (is.null(dc) || !nrow(dc)) {
      lignes[[d]] <- data.frame(id = ids[d], attribut = attribut, valeur = NA_real_,
                                mse = NA_real_, rse = NA_real_, n_placettes = nrow(vif),
                                poids_direct = NA_real_, part_bordure = bord,
                                ser = NA_character_,
                                surface_ha = as.numeric(sf::st_area(geom[d])) / 1e4,
                                nature = NA_character_, campagnes = NA_character_)
      next
    }
    kk <- nrow(dc)
    val <- mean(dc$estimation)
    mse <- sum(dc$mse) / kk^2
    lignes[[d]] <- data.frame(
      id = ids[d], attribut = attribut, valeur = val, mse = mse,
      rse = 100 * sqrt(mse) / abs(val), n_placettes = nrow(vif),
      poids_direct = mean(dc$gamma), part_bordure = bord,
      ser = paste(sprintf("%s:%.2f", names(w), as.numeric(w)), collapse = ","),
      surface_ha = as.numeric(sf::st_area(geom[d])) / 1e4,
      nature = if (nrow(vif) > 0L) "composite" else "ser",
      campagnes = paste(dc$campagne, collapse = ","),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, lignes)
  rownames(out) <- NULL
  attr(out, "detail") <- do.call(rbind, detail)
  out
}
