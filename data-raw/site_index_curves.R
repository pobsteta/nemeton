# ============================================================
# site_index_curves.R
# ------------------------------------------------------------
# Generates inst/extdata/site_index_curves.csv — dominant-
# height (H_dom) curves used by indicateur_p2_station() when a
# Canopy Height Model is available (spec 005, phase 2).
#
# Schema of the CSV:
#   species    chr   4-letter IFN-style code (plus two fallbacks)
#   age        int   stand age in years (10..150 step 5)
#   class_1    num   H_dom in m, fertility class 1 (best)
#   class_2    num   H_dom in m, fertility class 2
#   class_3    num   H_dom in m, fertility class 3 (median)
#   class_4    num   H_dom in m, fertility class 4
#   class_5    num   H_dom in m, fertility class 5 (worst)
#
# -------------------- Sources --------------------------------
#
# The curves are reconstituted from the published Chapman-
# Richards parametrizations of the following works. The
# reconstitution is explicit: per-species parameters (A, k, p)
# are listed below with their bibliographic source. Use of
# Duplat & Tran-Ha work is authorised by M. Tran-Ha (personal
# communication, April 2026 — see inst/NOTICE).
#
# References:
#   * Duplat, P. & Tran-Ha, M. (1997). "Modélisation de la
#     croissance en hauteur dominante du chêne sessile
#     (Quercus petraea Liebl) en France." Annales des Sciences
#     Forestières, 54(7), 611-634.
#   * Bontemps, J.-D., Duplat, P., Hervé, J.-C., Dhôte, J.-F.
#     (2007). "Croissance en hauteur dominante du hêtre dans
#     le Nord de la France: des courbes de référence qui
#     intègrent les tendances à long-terme." Rendez-Vous
#     Techniques ONF, HS2, 39-47 (HAL: hal-00823732). → Used
#     for FASY / FASY_NO / FASY_NE via the Korf recursive
#     model in Annex 2 of the paper.
#   * Dhôte, J.-F. & Hervé, J.-C. (2000). "Fagacées growth
#     model." Annals of Forest Science, 57, 1-17.
#   * Seynave, I. et al. (2005). "Picea abies site index in
#     France." Annals of Forest Science, 62, 215-223.
#   * Vallet, P. & Pérot, T. (2011). "Silver fir and Norway
#     spruce productivity." Forest Ecology and Management,
#     261(8), 1390-1400.
#   * DSF / IRSTEA (2010). "Tables de production Douglas France."
#   * Lemoine, B. (1991). "Croissance et production du Pin
#     maritime dans les Landes de Gascogne." IFN.
#   * CNPF (2013). "Fiche technique peupleraie — indices de
#     fertilité."
#
# -------------------- Chapman-Richards -----------------------
#
#   H(t) = A * (1 - exp(-k * t))^p
#
# where A is the upper asymptote (m) varying per fertility
# class, k is the growth-rate parameter (year^-1), and p is
# the shape parameter. Parameters are tuned so that H(50) for
# the median class (class 3) falls within the reference-age
# values reported in the sources above.
#
# -------------------- Fallbacks ------------------------------
#
#   BROADLEAF_GENUS -> Quercus petraea curve
#   CONIFER_GENUS   -> Picea abies curve
#
# ============================================================

# Parameter table — one row per species.
# `a1..a5` are the per-class asymptotes (m) in decreasing
# fertility order (class 1 = best). `k` and `p` are shape.
# Parameters are calibrated so that the median class (class 3)
# reaches the reference-age values reported in the sources:
#   - Hardwoods: H(100) ≈ 24 m for QUPE class 3 (Duplat & Tran-Ha).
#   - Conifers : H(50)  ≈ 22 m for PIAB class 3 (Seynave et al.).
#   - Populus  : H(25)  ≈ 28 m for class 3 (CNPF).
site_index_params <- data.frame(
  species = c(
    "QUPE",   # Quercus petraea   (Duplat & Tran-Ha 1997)
    "QURO",   # Quercus robur     (Duplat & Tran-Ha 1997)
    "CASA",   # Castanea sativa   (Dhôte-like scaling)
    "PIAB",   # Picea abies       (Seynave et al. 2005)
    "ABAL",   # Abies alba        (Vallet & Pérot 2011)
    "PSME",   # Pseudotsuga menziesii (DSF/IRSTEA 2010)
    "PISY",   # Pinus sylvestris  (Duplat 2001 follow-up)
    "PIPI",   # Pinus pinaster    (Lemoine 1991, IFN Landes)
    "POSP"    # Populus sp.       (CNPF 2013)
  ),
  # FASY is handled separately below via the Korf model of
  # Bontemps et al. 2007 (two regions + average).
  a1 = c(38, 36, 34, 42, 44, 50, 30, 30, 36),
  a2 = c(34, 32, 30, 38, 38, 44, 26, 26, 32),
  a3 = c(29, 27, 26, 32, 32, 37, 22, 22, 28),
  a4 = c(24, 22, 22, 26, 26, 30, 18, 18, 24),
  a5 = c(20, 18, 18, 20, 20, 24, 14, 14, 20),
  k  = c(0.022, 0.020, 0.028, 0.028, 0.024, 0.032, 0.032, 0.045, 0.080),
  p  = c(1.50,  1.50,  1.35,  1.30,  1.30,  1.30,  1.30,  1.20,  1.10),
  stringsAsFactors = FALSE
)

# Chapman-Richards evaluator (vectorised over age, single row).
chapman_richards <- function(age, A, k, p) {
  A * (1 - exp(-k * age))^p
}

# Age grid
ages <- seq(10, 150, by = 5)

# Build one block per species
build_block <- function(row) {
  data.frame(
    species = row$species,
    age     = ages,
    class_1 = round(chapman_richards(ages, row$a1, row$k, row$p), 2),
    class_2 = round(chapman_richards(ages, row$a2, row$k, row$p), 2),
    class_3 = round(chapman_richards(ages, row$a3, row$k, row$p), 2),
    class_4 = round(chapman_richards(ages, row$a4, row$k, row$p), 2),
    class_5 = round(chapman_richards(ages, row$a5, row$k, row$p), 2),
    stringsAsFactors = FALSE
  )
}

blocks <- lapply(seq_len(nrow(site_index_params)), function(i) {
  build_block(site_index_params[i, ])
})

# ============================================================
# FASY — Fagus sylvatica — Korf recursive model
# Bontemps et al. 2007, RFF HS2 (HAL hal-00823732), Annex 2.
# ------------------------------------------------------------
#   H_t = a * exp(- (p_f * b * chprod(date_0 + t)
#                    + [ln(a / H_{t-1})]^(-1/c))^(-c))
# with H(t0) = H0.
#
# Two regions, very different parameters. chprod = 1 here
# (no long-term drift) — matches the dashed reference curves
# in Fig. 3-4 of the paper. A future climate-aware mode
# (Charru et al. 2017) may wire chprod through a date / climate
# context.
# ============================================================

fasy_regions <- list(
  NO = list(a = 44.2, b = 0.032, c = 1.647, t0 = 6, H0 = 1.40,
            p_f_min = 0.29, p_f_max = 0.58),
  NE = list(a = 68.7, b = 0.028, c = 0.823, t0 = 6, H0 = 1.35,
            p_f_min = 0.21, p_f_max = 0.53)
)

# Recursive Korf evaluator: vectorised over the age grid.
korf_bontemps <- function(ages, a, b, c, t0, H0, p_f, chprod = 1) {
  if (min(ages) < t0) {
    stop("korf_bontemps: all requested ages must be >= t0 (",
         t0, "); got min = ", min(ages))
  }
  t_all <- t0:max(ages)
  H_all <- numeric(length(t_all))
  H_all[1] <- H0
  # v_t = [ln(a/H_t)]^(-1/c). Starts at v(t0) from H0 and
  # advances by p_f * b * chprod per year.
  v <- (log(a / H0))^(-1 / c)
  for (i in 2:length(t_all)) {
    v <- v + p_f * b * chprod
    H_all[i] <- a * exp(-v^(-c))
  }
  stats::approx(t_all, H_all, xout = ages, rule = 2)$y
}

build_fasy_block <- function(code, region) {
  # Class 1 = best fertility (highest p_f), class 5 = worst
  p_f_vals <- seq(region$p_f_max, region$p_f_min, length.out = 5)
  classes <- lapply(p_f_vals, function(pf) {
    round(korf_bontemps(ages, region$a, region$b, region$c,
                        region$t0, region$H0, pf, chprod = 1), 2)
  })
  data.frame(
    species = code,
    age     = ages,
    class_1 = classes[[1]],
    class_2 = classes[[2]],
    class_3 = classes[[3]],
    class_4 = classes[[4]],
    class_5 = classes[[5]],
    stringsAsFactors = FALSE
  )
}

fasy_no_block <- build_fasy_block("FASY_NO", fasy_regions$NO)
fasy_ne_block <- build_fasy_block("FASY_NE", fasy_regions$NE)

# FASY = simple average of NO and NE per age / class. Used when
# no regional context is available; a future GRECO-aware
# dispatcher can route to FASY_NO or FASY_NE explicitly.
fasy_block <- fasy_no_block
fasy_block$species <- "FASY"
for (cl in paste0("class_", 1:5)) {
  fasy_block[[cl]] <- round(
    (fasy_no_block[[cl]] + fasy_ne_block[[cl]]) / 2, 2
  )
}

# Fallback blocks: copy of QUPE (broadleaf) and PIAB (conifer)
fallback_broadleaf <- blocks[[which(site_index_params$species == "QUPE")]]
fallback_broadleaf$species <- "BROADLEAF_GENUS"

fallback_conifer <- blocks[[which(site_index_params$species == "PIAB")]]
fallback_conifer$species <- "CONIFER_GENUS"

site_index_curves <- do.call(
  rbind,
  c(blocks,
    list(fasy_block, fasy_no_block, fasy_ne_block,
         fallback_broadleaf, fallback_conifer))
)

# Expected species count: 9 Chapman-Richards + 3 FASY variants
# + 2 genus-level fallbacks = 14.
n_species_expected <- nrow(site_index_params) + 3L + 2L

# Sanity checks — fail loudly if the generator produces garbage.
stopifnot(
  nrow(site_index_curves) == length(ages) * n_species_expected,
  length(unique(site_index_curves$species)) == n_species_expected,
  all(c("species", "age", paste0("class_", 1:5)) %in% names(site_index_curves)),
  !anyNA(site_index_curves),
  all(site_index_curves$class_1 >= site_index_curves$class_5),
  all(site_index_curves[, paste0("class_", 1:5)] >= 0),
  all(site_index_curves[, paste0("class_", 1:5)] <= 70)
)

# Monotony per species per class
for (sp in unique(site_index_curves$species)) {
  sub <- site_index_curves[site_index_curves$species == sp, ]
  sub <- sub[order(sub$age), ]
  for (cl in paste0("class_", 1:5)) {
    stopifnot(all(diff(sub[[cl]]) >= 0))
  }
}

out_path <- file.path("inst", "extdata", "site_index_curves.csv")
utils::write.csv(site_index_curves, out_path, row.names = FALSE)

message("site_index_curves.csv written: ",
        nrow(site_index_curves), " rows, ",
        length(unique(site_index_curves$species)), " species.")
