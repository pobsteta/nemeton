# Spec 056 — agrégation des mesures par projet (sorties de mesures_projet.R)
# en tableaux Markdown repris dans mesures.md.
#
# Usage : Rscript specs/056-choix-methode/agrege.R <out_dir>
# Aucune dépendance au paquet : ne relit que les .rds produits par
# mesures_projet.R (et, pour contrôle, data/indicators.parquet des projets).

suppressPackageStartupMessages(library(knitr))
args <- commandArgs(trailingOnly = TRUE)
out_dir <- args[1]
R <- lapply(sort(Sys.glob(file.path(out_dir, "2*_*.rds"))), readRDS)
names(R) <- vapply(R, `[[`, "", "name")
md <- function(x, digits = 2) print(kable(x, format = "pipe", digits = digits, row.names = FALSE))
h <- function(x) cat("\n\n### ", x, "\n\n", sep = "")
wmean <- function(x, w) sum(x * w) / sum(w)
clamp01 <- function(x) pmin(1, pmax(0, x))
set.seed(56)

# Grille « de travail » métrique pour les bornes poolées : LiDAR 2 m quand il
# existe ; pour les projets sans LiDAR, le MNT IGN reprojeté à 25 m en L93 (le
# TWI de l'app y est calculé en degrés, cf. section 2).
metric_grid <- function(r) if (r$dem_src == "lidar_mnt_2m") r$terrain else r$terrain25

# ============================================================================
# 1. R2 / R3 : distributions brutes
# ============================================================================
h("1a. Distribution brute de TRI et TWI dans les UGF (grille de l'app)")
md(do.call(rbind, lapply(R, function(r) {
  t <- r$terrain
  data.frame(projet = r$name, mnt = r$dem_src, pas_m = round(t$res_m, 1),
             n_ugf = nrow(r$units),
             TRI_q05 = t$tri_q[1], TRI_q50 = t$tri_q[2], TRI_q95 = t$tri_q[3],
             TRI_max_emprise = t$tri_max,
             TWI_q05 = t$twi_q[1], TWI_q50 = t$twi_q[2], TWI_q95 = t$twi_q[3],
             TWI_max_emprise = t$twi_max)
})))
h("1b. Contrôle : même terrain, MNT IGN 25 m reprojeté en Lambert-93")
md(do.call(rbind, lapply(R, function(r) {
  t <- r$terrain25
  data.frame(projet = r$name,
             TRI_q05 = t$tri_q[1], TRI_q50 = t$tri_q[2], TRI_q95 = t$tri_q[3],
             TRI_max = t$tri_max, TRI_sur_pas_q50 = t$tri_q[2] / 25,
             TWI_q05 = t$twi_q[1], TWI_q50 = t$twi_q[2], TWI_q95 = t$twi_q[3],
             TWI_max = t$twi_max)
})))

# Bornes poolées : même poids par projet (20 000 pixels tirés par projet)
pool <- function(f) unlist(lapply(R, function(r) {
  v <- f(r); v[sample.int(length(v), min(20000, length(v)))]
}))
tri_rel_pool <- pool(function(r) { g <- metric_grid(r); g$tri_pix_sample / g$res_m })
twi_pool     <- pool(function(r) metric_grid(r)$twi_pix_sample)
tri_lidar_pool <- pool(function(r) if (r$dem_src == "lidar_mnt_2m") r$terrain$tri_pix_sample else numeric(0))
B <- list(
  tri_rel = quantile(tri_rel_pool, c(.05, .95)),
  tri_m2  = quantile(tri_lidar_pool, c(.05, .95)),
  twi     = quantile(twi_pool, c(.05, .95))
)
h("1c. Bornes poolées (quantiles 5-95 %, poids égal par projet, grille métrique)")
md(data.frame(grandeur = c("TRI / pas (sans dimension)", "TRI en m (LiDAR 2 m seuls)", "TWI (grille métrique)"),
              q05 = c(B$tri_rel[1], B$tri_m2[1], B$twi[1]),
              q95 = c(B$tri_rel[2], B$tri_m2[2], B$twi[2])), 3)

# Scores par UGF selon l'option de normalisation
scores_terrain <- function(r, g = r$terrain) {
  px <- g$pixels; res_m <- g$res_m
  by <- split(px, px$ug_id)
  out <- do.call(rbind, lapply(names(by), function(u) {
    d <- by[[u]]
    r2 <- function(tn) 100 * wmean(d$expo * (0.6 * d$pente_n + 0.4 * tn), d$w)
    r3 <- function(wn) 100 * wmean(0.4 * d$aspect_risk + 0.3 * d$pente_risk + 0.3 * (1 - wn), d$w)
    data.frame(
      ug_id = u,
      R2_actuel = r2(clamp01(d$tri / g$tri_max)),
      R2_emprise_locale = r2(clamp01(d$tri / g$tri_max_loc)),
      R2_borne_tri_rel = r2(clamp01((d$tri / res_m - B$tri_rel[1]) / diff(B$tri_rel))),
      R2_sans_tri = 100 * wmean(d$expo * d$pente_n, d$w),
      R3_actuel = r3(clamp01(d$twi / g$twi_max)),
      R3_emprise_locale = r3(clamp01(d$twi / g$twi_max_loc)),
      R3_borne_twi = r3(clamp01((d$twi - B$twi[1]) / diff(B$twi))),
      twi_mean = wmean(d$twi, d$w)
    )
  }))
  out
}
S <- lapply(R, scores_terrain)
S25 <- lapply(R, function(r) scores_terrain(r, r$terrain25))

cmp <- function(a, b) c(delta_moy = mean(b - a, na.rm = TRUE),
                        delta_abs_max = max(abs(b - a), na.rm = TRUE),
                        spearman = suppressWarnings(cor(a, b, method = "spearman", use = "complete.obs")))
h("1d. R2 (repli terrain) : actuel (max de l'emprise) contre bornes fixes")
md(do.call(rbind, lapply(names(S), function(n) {
  s <- S[[n]]
  c1 <- cmp(s$R2_actuel, s$R2_borne_tri_rel); c2 <- cmp(s$R2_actuel, s$R2_emprise_locale)
  data.frame(projet = n, R2_actuel_moy = mean(s$R2_actuel), R2_actuel_et = sd(s$R2_actuel),
             R2_fixe_moy = mean(s$R2_borne_tri_rel), R2_fixe_et = sd(s$R2_borne_tri_rel),
             delta_moy = c1[1], spearman = c1[3],
             emprise_locale_delta_max = c2[2])
})))
h("1e. R3 (composante topographique seule) : actuel contre bornes fixes")
md(do.call(rbind, lapply(names(S), function(n) {
  s <- S[[n]]
  c1 <- cmp(s$R3_actuel, s$R3_borne_twi); c2 <- cmp(s$R3_actuel, s$R3_emprise_locale)
  data.frame(projet = n, R3_actuel_moy = mean(s$R3_actuel), R3_actuel_et = sd(s$R3_actuel),
             R3_fixe_moy = mean(s$R3_borne_twi), R3_fixe_et = sd(s$R3_borne_twi),
             delta_moy = c1[1], spearman = c1[3],
             emprise_locale_delta_max = c2[2])
})))
h("1f. Même terrain, deux MNT (LiDAR 2 m contre IGN 25 m) : écart de score par UGF")
md(do.call(rbind, lapply(names(S), function(n) {
  a <- S[[n]]; b <- S25[[n]][match(a$ug_id, S25[[n]]$ug_id), ]
  data.frame(projet = n,
             R2_actuel_ecart_moy = mean(abs(a$R2_actuel - b$R2_actuel), na.rm = TRUE),
             R2_fixe_ecart_moy = mean(abs(a$R2_borne_tri_rel - b$R2_borne_tri_rel), na.rm = TRUE),
             R3_actuel_ecart_moy = mean(abs(a$R3_actuel - b$R3_actuel), na.rm = TRUE),
             R3_fixe_ecart_moy = mean(abs(a$R3_borne_twi - b$R3_borne_twi), na.rm = TRUE),
             TWI_ecart_moy = mean(a$twi_mean - b$twi_mean, na.rm = TRUE))
})))
h("1g. Ce que vaut un même TRI / TWI brut selon le projet (normalisation actuelle)")
md(do.call(rbind, lapply(R, function(r) {
  t <- r$terrain
  data.frame(projet = r$name, TRI_max = t$tri_max,
             score_TRI_1m = 100 * min(1, 1 / t$tri_max),
             TWI_max = t$twi_max,
             risque_TWI_5 = 100 * (1 - min(1, 5 / t$twi_max)))
})))

h("1h. Redondance TRI / pente (corrélation de Pearson, pixels des UGF, grille de l'app)")
md(do.call(rbind, lapply(R, function(r) {
  px <- r$terrain$pixels
  data.frame(projet = r$name, cor_pixels = cor(px$tri, px$pente_n),
             cor_ugf = { m <- aggregate(cbind(tri, pente_n) ~ ug_id, px, mean); cor(m$tri, m$pente_n) })
})))
h("1i. R2 sans le terme TRI (0,6 pente seule, repondérée à 1) : effet sur le classement")
md(do.call(rbind, lapply(names(S), function(n) {
  s <- S[[n]]
  data.frame(projet = n, spearman_actuel_vs_sans_tri = cor(s$R2_actuel, s$R2_sans_tri, method = "spearman"))
})))
# Ecart W3 en pas de TWI attendu par l'analyse dimensionnelle : a = A / pas,
# donc TWI(2 m) - TWI(25 m) ~ ln(25 / 2) = 2,53 pour la même pente.
cat("\n\nÉcart attendu TWI 2 m - TWI 25 m (ln(25/2)) :", round(log(25 / 2), 2), "\n")

# ============================================================================
# 2. W3 / F2 : saturation des fenêtres TWI
# ============================================================================
win <- list(W3 = c(2.5, 4.5), F2 = c(2.5, 10), commune = unname(B$twi))
sat_tab <- function(g, label) do.call(rbind, lapply(names(R), function(n) {
  r <- R[[n]]; gg <- g(r)
  twi <- gg$twi_pix_sample
  um <- tapply(gg$pixels$twi * gg$pixels$w, gg$pixels$ug_id, sum) /
        tapply(gg$pixels$w, gg$pixels$ug_id, sum)
  row <- data.frame(projet = n, grille = label)
  for (k in names(win)) {
    lo <- win[[k]][1]; hi <- win[[k]][2]
    row[[paste0(k, "_pix_0")]]   <- 100 * mean(twi <= lo)
    row[[paste0(k, "_pix_100")]] <- 100 * mean(twi >= hi)
    row[[paste0(k, "_ugf_sat")]] <- 100 * mean(um <= lo | um >= hi)
  }
  row
}))
h(sprintf("2a. Saturation (%% de pixels à 0 ou 100, %% d'UGF dont la moyenne sature) — fenêtres W3 [2,5 ; 4,5], F2 [2,5 ; 10], commune [%.2f ; %.2f]",
          B$twi[1], B$twi[2]))
md(rbind(sat_tab(function(r) r$terrain, "app"),
         sat_tab(function(r) r$terrain25, "IGN 25 m L93")), 1)

h("2b. W3 et composante TWI de F2 par UGF (moyenne du projet)")
md(do.call(rbind, lapply(names(S), function(n) {
  t <- S[[n]]$twi_mean
  sc <- function(lo, hi) 100 * clamp01((t - lo) / (hi - lo))
  data.frame(projet = n, TWI_ugf_moy = mean(t),
             W3_actuel = mean(sc(2.5, 4.5)), W3_et = sd(sc(2.5, 4.5)),
             F2twi_actuel = mean(sc(2.5, 10)), F2twi_et = sd(sc(2.5, 10)),
             commune = mean(sc(B$twi[1], B$twi[2])), commune_et = sd(sc(B$twi[1], B$twi[2])))
})))

# ============================================================================
# 3. N1
# ============================================================================
h("3. N1 actuel contre N1 sans le terme urbain constant (repondéré 0,40/0,35)")
md(do.call(rbind, lapply(R, function(r) {
  n1 <- r$n1$N1; n1b <- (n1 - 25) / 0.75
  data.frame(projet = r$name, couches = paste0(ifelse(r$n1$has_roads[1], "routes", "-"), "+",
                                               ifelse(r$n1$has_buildings[1], "bati", "-")),
             n_ugf = length(n1), n_NA = sum(is.na(n1)),
             N1_moy = mean(n1, na.rm = TRUE), N1_min = suppressWarnings(min(n1, na.rm = TRUE)),
             N1_max = suppressWarnings(max(n1, na.rm = TRUE)), N1_et = sd(n1, na.rm = TRUE),
             N1b_moy = mean(n1b, na.rm = TRUE), N1b_min = suppressWarnings(min(n1b, na.rm = TRUE)),
             N1b_max = suppressWarnings(max(n1b, na.rm = TRUE)), N1b_et = sd(n1b, na.rm = TRUE),
             delta_N3_moy = 0.35 * mean(n1b - n1, na.rm = TRUE))
})))

# ============================================================================
# 4. P3
# ============================================================================
h("4. P3 : part des défauts et trois options")
md(do.call(rbind, lapply(R, function(r) {
  p <- r$prod; if (is.null(p)) return(NULL)
  ok <- !is.na(p$P3)
  data.frame(projet = r$name, n_ugf = nrow(p), n_P3 = sum(ok),
             part_defauts_pct = 100 * mean(45 / p$P3[ok]),
             P3_actuel_moy = mean(p$P3[ok]), P3_actuel_min = min(p$P3[ok]), P3_actuel_max = max(p$P3[ok]),
             P3_actuel_et = sd(p$P3[ok]),
             P3_NA = sum(ok), # toutes passent à NA : aucune forme/défaut mesurés
             P3_diam_moy = mean(p$diam_score[ok]), P3_diam_min = min(p$diam_score[ok]),
             P3_diam_max = max(p$diam_score[ok]), P3_diam_et = sd(p$diam_score[ok]),
             diam_sature_100_pct = 100 * mean(p$diam_score[ok] >= 99.999),
             diam_0_pct = 100 * mean(p$diam_score[ok] <= 0.001))
})))

# ============================================================================
# 5. Indice de station
# ============================================================================
h("5a. Position de H_dom par rapport aux courbes Duplat & Tran-Ha (à l'âge BD Forêt)")
pos_lv <- c("dans_courbes", "au_dessus_classe1", "sous_classe5", "non_estimable",
            "essence_inconnue", "age_hors_table")
md(do.call(rbind, lapply(R, function(r) {
  p <- r$prod; if (is.null(p)) return(NULL)
  tb <- table(factor(p$position, pos_lv))
  data.frame(projet = r$name, chm = basename(dirname(r$chm_path)), n_ugf = nrow(p),
             as.list(tb), hors_courbe_pct = 100 * (tb[[2]] + tb[[3]]) / sum(tb[1:3]),
             ages = paste(sort(unique(p$age)), collapse = "/"))
})))
h("5b. Effet sur P2 (mode CHM, normalisé sur 40 m) du passage à NA hors courbe")
md(do.call(rbind, lapply(R, function(r) {
  p <- r$prod; if (is.null(p)) return(NULL)
  a <- 100 * pmin(1, p$si / 40); b <- 100 * pmin(1, p$si_na / 40)
  data.frame(projet = r$name, P2_n = sum(!is.na(a)), P2_moy = mean(a, na.rm = TRUE),
             P2_et = sd(a, na.rm = TRUE),
             P2_na_n = sum(!is.na(b)), P2_na_moy = mean(b, na.rm = TRUE),
             P2_na_et = sd(b, na.rm = TRUE),
             SI_borne_classe1_n = sum(p$position == "au_dessus_classe1"),
             SI_borne_classe5_n = sum(p$position == "sous_classe5"))
})))
h("5c. Détail des UGF hors courbe (essence, âge, H_dom, indice borné)")
md(do.call(rbind, lapply(R, function(r) {
  p <- r$prod; if (is.null(p)) return(NULL)
  p <- p[p$position %in% c("au_dessus_classe1", "sous_classe5"), ]
  if (!nrow(p)) return(NULL)
  agg <- aggregate(h_dom ~ species + age + position, p, function(x) c(n = length(x), min = min(x), max = max(x)))
  agg <- do.call(data.frame, agg)
  agg$si_borne <- vapply(seq_len(nrow(agg)), function(i)
    unique(round(p$si[p$species == agg$species[i] & p$age == agg$age[i] & p$position == agg$position[i]], 2))[1], 0)
  cbind(projet = r$name, agg)
})))

# Variante de sensibilité : codes d'essence reconnus par les courbes. La BD
# Forêt enrichie (enrich_parcels_bdforet -> map_essence_to_species) renvoie des
# genres latins ("Abies", "Pinus"...) que resolve_species_code() ne reconnaît
# pas : toutes les UGF tombent sur BROADLEAF_GENUS (= courbe QUPE).
suppressMessages(devtools::load_all(".", quiet = TRUE))
code_map <- c(Quercus = "QUPE", Fagus = "FASY", Pinus = "CONIFER_GENUS",
              Abies = "ABAL", Generic = "BROADLEAF_GENUS")
h("5d. Sensibilité : même calcul avec l'essence mappée sur un code des courbes (Abies -> ABAL, Pinus -> CONIFER_GENUS, Fagus -> FASY, Quercus -> QUPE)")
md(do.call(rbind, lapply(R, function(r) {
  p <- r$prod; if (is.null(p)) return(NULL)
  sp <- unname(code_map[p$species])
  curves <- read_site_index_curves()
  pos <- vapply(seq_len(nrow(p)), function(i) {
    h <- p$h_dom[i]; a <- p$age[i]
    if (is.na(h) || is.na(sp[i]) || h < 1.3) return("non_estimable")
    sub <- curves[curves$species == sp[i], ]; sub <- sub[order(sub$age), ]
    hh <- vapply(paste0("class_", 1:5), function(cl) stats::approx(sub$age, sub[[cl]], xout = a)$y, 0)
    if (h > hh[1]) "au_dessus" else if (h < hh[5]) "sous" else "dans"
  }, "")
  si <- compute_site_index(p$h_dom, p$age, sp)
  si_na <- ifelse(pos %in% c("au_dessus", "sous"), NA, si)
  est <- pos != "non_estimable"
  data.frame(projet = r$name, dans = sum(pos == "dans"), au_dessus_classe1 = sum(pos == "au_dessus"),
             sous_classe5 = sum(pos == "sous"),
             hors_courbe_pct = 100 * mean(pos[est] != "dans"),
             P2_borne_moy = mean(100 * pmin(1, si / 40), na.rm = TRUE),
             P2_na_n = sum(!is.na(si_na)),
             P2_na_moy = mean(100 * pmin(1, si_na / 40), na.rm = TRUE))
})))

saveRDS(list(B = B, S = S, S25 = S25), file.path(out_dir, "agrege.rds"))
