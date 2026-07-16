# regen_rank_species.R — classement déterministe des essences par UGF (top-N)
# pour la régénération. Brief `brief-nemeton-regen-rank-species.md`, spec 039.
# ------------------------------------------------------------------
# Adéquation (UGF × essence) = agrégation pondérée de 3 axes 0-100 (haut = bon) :
#   A. Chaleur & sécheresse — T°max/VPD vs tolérances + REW édaphique vs drought_tol
#      (réutilise la logique de indice_priorite_regen()) ;
#   B. Gel tardif — pression gel de la station (R7 / r7_gel_days) vs frost_late de
#      l'essence (DIFFÉRENCIE les essences : hêtre sensible vs chêne résistant) ;
#   C. Ombre (OPTIONNELLE) — densité de couvert par UGF (cover_col, ou lai_col
#      converti par Beer-Lambert) vs shade_tol de l'essence. Omise si absente, et
#      shade_tol sert alors de départage déterministe.
# Déterministe (aucun aléa), NA-safe (station manquante → suitability NA, rank NA).

# Poids par défaut des 3 axes (renormalisés sur les axes présents).
.REGEN_RANK_WEIGHTS <- c(chaleur_secheresse = 0.5, gel = 0.3, ombre = 0.2)
# Coefficient d'extinction Beer-Lambert (LAI/PAI -> fraction de couvert).
.REGEN_RANK_K <- 0.5
# Plafond de jours de gel tardif -> pression max (quand R7 absent, repli gel_days).
.REGEN_RANK_GELMAX <- 15

.rank_clamp01 <- function(x) pmin(1, pmax(0, x))

# Trait de tolérance (échelle Niinemets & Valladares ~1-5, haut = plus tolérant)
# -> capacité 0-1. Clampe les valeurs hors [1,5] (robuste à un outlier de saisie).
.rank_cap <- function(v) .rank_clamp01((pmin(5, pmax(1, as.numeric(v))) - 1) / 4)

# Facteur limitant par ligne = l'axe à la plus forte pénalité (NA-aware). Toutes
# pénalités nulles -> aucune contrainte (NA). Toutes NA -> NA.
.rank_limiting <- function(pen) {
  cats <- colnames(pen)
  vapply(seq_len(nrow(pen)), function(i) {
    r <- pen[i, ]
    if (all(is.na(r))) return(NA_character_)
    r[is.na(r)] <- -Inf
    if (max(r) <= 0) return(NA_character_)
    cats[which.max(r)]
  }, character(1))
}

# Densité de couvert 0-1 par UGF, depuis une fraction (cover_col) ou un LAI/PAI
# (lai_col, converti par Beer-Lambert 1 - exp(-k·LAI)). NULL si aucune entrée.
.regen_rank_cover <- function(units, cover_col, lai_col, k) {
  n <- nrow(units)
  if (!is.null(lai_col) && lai_col %in% names(units)) {
    lai <- as.numeric(units[[lai_col]])
    return(.rank_clamp01(1 - exp(-k * pmax(0, lai))))
  }
  if (!is.null(cover_col) && cover_col %in% names(units)) {
    cov <- as.numeric(units[[cover_col]])
    if (any(cov > 1.5, na.rm = TRUE)) cov <- cov / 100   # tolère un % (0-100)
    return(.rank_clamp01(cov))
  }
  NULL
}

# Pool d'essences candidates avec traits COMPLETS (dont frost_late, absent de
# regen_species_choices). Accepte NULL (pool par défaut), un vecteur de codes, ou
# un data.frame de traits ; complète les colonnes manquantes depuis la table UE.
.regen_rank_pool <- function(units, species_pool, region, include_atlas) {
  eu <- tryCatch(european_species_tolerances(), error = function(e) NULL)
  need <- c("code", "label", "type", "tmax_tol_c", "vpd_tol_kpa", "drought_tol",
            "shade_tol", "frost_late", "confidence", "invasif")
  ensure_traits <- function(df) {
    if (is.null(df) || !nrow(df)) return(df)
    if (!"label" %in% names(df) && "species_fr" %in% names(df)) df$label <- df$species_fr
    miss <- setdiff(need, names(df))
    if (length(miss) && !is.null(eu)) {
      j <- eu[match(df$code, eu$code), , drop = FALSE]
      for (m in miss) {
        df[[m]] <- if (m == "label") {
          if ("species_fr" %in% names(j)) j$species_fr else df$code
        } else if (m %in% names(j)) j[[m]] else NA
      }
    }
    df
  }
  if (is.null(species_pool)) {
    base <- tryCatch(
      regen_species_choices(units, level = "species",
                            include_atlas = include_atlas, region = region),
      error = function(e) NULL)
    if (is.null(base)) base <- eu
    return(ensure_traits(base))
  }
  if (is.character(species_pool)) {
    if (is.null(eu)) {
      cli::cli_abort("european_species_tolerances() unavailable to resolve {.arg species_pool} codes.")
    }
    base <- eu[eu$code %in% species_pool, , drop = FALSE]
    return(ensure_traits(base))
  }
  if (is.data.frame(species_pool)) return(ensure_traits(species_pool))
  cli::cli_abort("{.arg species_pool} must be NULL, a character vector of codes, or a data.frame.")
}

# Sous-scores + suitability + facteur limitant pour UNE essence, vectorisé sur
# les UGF. `cover` = vecteur densité 0-1 ou NULL (axe ombre omis).
.regen_rank_one <- function(units, sp, cover, weights, span) {
  n <- nrow(units)
  col <- function(nm) if (nm %in% names(units)) as.numeric(units[[nm]]) else rep(NA_real_, n)

  # A — chaleur & sécheresse (atm. VPD + édaphique REW), loi du minimum de Liebig.
  tmax_abs <- col("tmax_moyenne") + col("d_tmax")
  p_heat <- .rank_clamp01((tmax_abs - as.numeric(sp$tmax_tol_c)) / span[["tmax_c"]])
  p_vpd  <- .rank_clamp01((col("vpd_canicule") - as.numeric(sp$vpd_tol_kpa)) /
                          span[["vpd_kpa"]])
  rew <- col("rew_min")
  if (any(rew > 1.5, na.rm = TRUE)) rew <- rew / 100       # REW attendu en 0-1
  dry <- .rank_clamp01(1 - rew)                            # sec = réserve basse
  p_drought <- dry * (1 - .rank_cap(sp$drought_tol))       # sec × essence peu tolérante
  p_sech <- pmax(p_vpd, p_drought)
  axisA <- 100 * (1 - pmax(p_heat, p_sech))

  # B — gel tardif : pression station × sensibilité essence (1 - frost_late cap).
  R7 <- col("R7")
  frost_press <- if (all(is.na(R7))) {
    .rank_clamp01(col("r7_gel_days") / .REGEN_RANK_GELMAX)
  } else {
    .rank_clamp01(1 - R7 / 100)                            # R7 0-100, haut = peu de gel
  }
  p_frost <- frost_press * (1 - .rank_cap(sp$frost_late))
  axisB <- 100 * (1 - p_frost)

  # C — ombre (optionnelle) : densité de couvert × essence peu tolérante à l'ombre.
  if (!is.null(cover)) {
    p_shade <- .rank_clamp01(cover) * (1 - .rank_cap(sp$shade_tol))
    axisC <- 100 * (1 - p_shade)
  } else {
    p_shade <- rep(NA_real_, n)
    axisC <- rep(NA_real_, n)
  }

  axes <- cbind(axisA, axisB, axisC)
  w <- c(weights[["chaleur_secheresse"]], weights[["gel"]], weights[["ombre"]])
  suit <- .regen_row_mean(axes, w)                         # moyenne renormalisée sur axes présents
  pen <- cbind(chaleur = p_heat, secheresse = p_sech, gel = p_frost, ombre = p_shade)
  list(suitability = round(suit, 1), limiting_factor = .rank_limiting(pen))
}

# Ordonne par UGF (suitability desc, départage confidence puis shade_tol puis
# code), garde top_n, pose rank 1..k. UGF sans donnée -> une ligne rank NA.
.regen_rank_topn <- function(long, top_n) {
  conf_rank <- c(eleve = 3, moyen = 2, faible = 1)
  long$.cr <- unname(conf_rank[as.character(long$confidence)])
  long$.cr[is.na(long$.cr)] <- 0
  long$.sh <- suppressWarnings(as.numeric(long$shade_tol))
  long$.sh[is.na(long$.sh)] <- -Inf
  parts <- split(long, long$ug_id)
  out <- lapply(parts, function(df) {
    ok <- df[is.finite(df$suitability), , drop = FALSE]
    if (nrow(ok) == 0L) {
      one <- df[1, , drop = FALSE]
      one$rank <- NA_integer_; one$species_code <- NA_character_
      one$label <- NA_character_; one$type <- NA_character_
      one$suitability <- NA_real_; one$limiting_factor <- NA_character_
      one$confidence <- NA_character_; one$invasif <- NA
      return(one)
    }
    o <- ok[order(-ok$suitability, -ok$.cr, -ok$.sh, ok$species_code), , drop = FALSE]
    k <- min(as.integer(top_n), nrow(o))
    o <- o[seq_len(k), , drop = FALSE]
    o$rank <- seq_len(k)
    o
  })
  res <- do.call(rbind, out)
  res$.cr <- NULL; res$.sh <- NULL
  cols <- c("ug_id", "rank", "species_code", "label", "type", "suitability",
            "limiting_factor", "confidence", "invasif")
  res <- res[, cols, drop = FALSE]
  res <- res[order(match(res$ug_id, unique(long$ug_id)),
                   ifelse(is.na(res$rank), Inf, res$rank)), , drop = FALSE]
  rownames(res) <- NULL
  res
}

.regen_rank_empty <- function() {
  data.frame(ug_id = character(0), rank = integer(0), species_code = character(0),
             label = character(0), type = character(0), suitability = numeric(0),
             limiting_factor = character(0), confidence = character(0),
             invasif = logical(0), stringsAsFactors = FALSE)
}

#' Rank the top-N regeneration species per management unit
#'
#' @description
#' Deterministic ecological suitability ranking of tree species for regeneration,
#' per management unit (UGF). For each `(unit × species)` it aggregates up to three
#' 0-100 sub-scores (high = well suited) and returns the `top_n` species per unit
#' (spec 039). This is the **deterministic core**; an LLM narrative layer lives in
#' the app (phase 2).
#'
#' Axes:
#' - **Heat & dryness** — summer T°max (`tmax_moyenne + d_tmax`) and VPD
#'   (`vpd_canicule`) against the species tolerances (`tmax_tol_c`, `vpd_tol_kpa`),
#'   plus edaphic dryness (`rew_min`) against `drought_tol`. Liebig's law of the
#'   minimum caps the axis at the worst stress (reuses [indice_priorite_regen()]'s
#'   thresholds `.REGEN_TOL_SPAN`).
#' - **Late frost** — station frost pressure (`R7`, else `r7_gel_days`) crossed with
#'   the species `frost_late` sensitivity, so the axis **differentiates** species
#'   (an early-flushing beech is penalised on a frost-prone site, a late-flushing
#'   oak is not).
#' - **Shade** *(optional)* — per-unit canopy density (`cover_col`, or `lai_col`
#'   converted with a Beer-Lambert `1 - exp(-k·LAI)`) crossed with `shade_tol`. When
#'   no density input is supplied the axis is omitted (the score renormalises over
#'   the present axes) and `shade_tol` breaks ranking ties instead.
#'
#' @param units An `sf` carrying the station columns produced by the regeneration
#'   engines (`tmax_moyenne`, `d_tmax`, `vpd_canicule`, `rew_min`, and `R7` or
#'   `r7_gel_days` for the frost axis).
#' @param species_pool `NULL` (default → [regen_species_choices()] for `units`), a
#'   character vector of species codes, or a `data.frame` of candidate traits.
#'   Missing trait columns (e.g. `frost_late`) are joined from
#'   [european_species_tolerances()] by `code`.
#' @param top_n Number of species to keep per unit (default 3).
#' @param weights Optional named numeric overriding the axis weights
#'   `c(chaleur_secheresse=, gel=, ombre=)` (default `c(0.5, 0.3, 0.2)`,
#'   renormalised over the axes actually present).
#' @param exclude_invasive Drop species flagged `invasif` (default `TRUE`).
#' @param region Region passed to [regen_species_choices()] when building the
#'   default pool.
#' @param cover_col,lai_col Optional column of `units` giving the per-unit residual
#'   canopy density — a cover fraction (`cover_col`, 0-1, or 0-100 auto-rescaled) or
#'   a leaf/plant area index (`lai_col`, converted with Beer-Lambert). `lai_col`
#'   takes precedence. Both `NULL` → shade axis omitted.
#' @param extinction_k Beer-Lambert extinction coefficient for `lai_col`
#'   (default 0.5).
#' @param id_col Unit id column (default `"ug_id"`; falls back to the row index).
#' @param ... Reserved.
#'
#' @return A long `data.frame`, one row per `(unit × rank)`: `ug_id`, `rank`,
#'   `species_code`, `label`, `type`, `suitability` (0-100), `limiting_factor`
#'   (`"chaleur"`/`"secheresse"`/`"gel"`/`"ombre"`, or `NA` when unconstrained),
#'   `confidence`, `invasif`. Units with no station data yield a single `rank = NA`
#'   row (no fabricated recommendation). An empty pool yields a 0-row frame.
#'   The chosen axis weights are attached as `attr(, "weights")`.
#' @seealso [regen_rank_to_wide()], [indice_priorite_regen()],
#'   [regen_species_choices()], [european_species_tolerances()]
#' @examples
#' \dontrun{
#'   units <- indice_priorite_regen(units)          # station columns present
#'   ranked <- regen_rank_species(units, top_n = 3, lai_col = "lai_max")
#'   regen_rank_to_wide(ranked, top_n = 3)
#' }
#' @export
regen_rank_species <- function(units, species_pool = NULL, top_n = 3,
                               weights = NULL, exclude_invasive = TRUE,
                               region = "BFC", cover_col = NULL, lai_col = NULL,
                               extinction_k = .REGEN_RANK_K, id_col = "ug_id",
                               include_atlas = FALSE, ...) {
  validate_sf(units)
  n <- nrow(units)
  ids <- if (id_col %in% names(units)) as.character(units[[id_col]]) else as.character(seq_len(n))

  w <- .REGEN_RANK_WEIGHTS
  if (!is.null(weights)) w[names(weights)] <- as.numeric(weights)
  span <- .REGEN_TOL_SPAN

  cover <- .regen_rank_cover(units, cover_col, lai_col, extinction_k)

  pool <- .regen_rank_pool(units, species_pool, region, include_atlas)
  if (is.null(pool) || !nrow(pool)) return(.regen_rank_empty())
  if (isTRUE(exclude_invasive) && "invasif" %in% names(pool)) {
    pool <- pool[!(as.logical(pool$invasif) %in% TRUE), , drop = FALSE]
  }
  if (!nrow(pool)) return(.regen_rank_empty())

  scored <- lapply(seq_len(nrow(pool)), function(i) {
    sp <- as.list(pool[i, , drop = FALSE])
    sc <- .regen_rank_one(units, sp, cover, w, span)
    data.frame(
      ug_id = ids, rank = NA_integer_,
      species_code = as.character(sp$code),
      label = as.character(sp$label %||% sp$code),
      type = as.character(sp$type %||% NA),
      suitability = sc$suitability, limiting_factor = sc$limiting_factor,
      confidence = as.character(sp$confidence %||% NA),
      shade_tol = suppressWarnings(as.numeric(sp$shade_tol %||% NA)),
      invasif = isTRUE(as.logical(sp$invasif)),
      stringsAsFactors = FALSE)
  })
  long <- do.call(rbind, scored)
  ranked <- .regen_rank_topn(long, top_n)
  attr(ranked, "weights") <- w
  ranked
}

#' Pivot a species ranking to one row per unit (wide)
#'
#' @description
#' Reshape the long output of [regen_rank_species()] to one row per unit with
#' `essence_r` / `score_r` / `label_r` / `facteur_r` columns for each rank
#' `r = 1..top_n` — convenient for a per-unit table or a map join.
#'
#' @param ranked The long `data.frame` returned by [regen_rank_species()].
#' @param top_n Number of ranks to spread into columns (default 3).
#'
#' @return A `data.frame` with `ug_id` and, per rank, `essence_r` (species code),
#'   `score_r` (suitability), `label_r` (name) and `facteur_r` (limiting factor).
#' @seealso [regen_rank_species()]
#' @export
regen_rank_to_wide <- function(ranked, top_n = 3) {
  if (!is.data.frame(ranked) || !all(c("ug_id", "rank") %in% names(ranked))) {
    cli::cli_abort("{.arg ranked} must be the long data.frame from {.fun regen_rank_species}.")
  }
  ug <- unique(ranked$ug_id)
  base <- data.frame(ug_id = ug, stringsAsFactors = FALSE)
  for (r in seq_len(as.integer(top_n))) {
    sub <- ranked[!is.na(ranked$rank) & ranked$rank == r, , drop = FALSE]
    m <- match(base$ug_id, sub$ug_id)
    base[[paste0("essence_", r)]] <- sub$species_code[m]
    base[[paste0("score_", r)]]   <- sub$suitability[m]
    base[[paste0("label_", r)]]   <- sub$label[m]
    base[[paste0("facteur_", r)]] <- sub$limiting_factor[m]
  }
  base
}
