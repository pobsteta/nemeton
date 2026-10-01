# comparer_covariables_gedi.R — jeu G (GEDI L2A) contre jeu F (FORMS-T + MNT)
# -----------------------------------------------------------------------------
# Spec 054 lot 1-ter, critères fixés AVANT de voir les résultats (§5.b) :
#   1. efficacité relative globale (RE) du Fay-Herriot, PG et PV ;
#   2. validation croisée « une SER en moins » : RMSE de la prédiction
#      synthétique sur la SER retirée (toutes ses campagnes) ;
#   3. I de Moran des résidus par contiguïté.
# L'AIC ne sert qu'à choisir les variables DANS un jeu. GRECO en effet fixe
# dans les deux jeux (décision du 2026-10-01). Égalité (écart de RE < 10 %) :
# F l'emporte. Comparaison sur les MÊMES domaines-années.
#
# Entrées (cache, hors dépôt) :
#   gedi/gedi_l2a_<an>.csv     data-raw/gedi_l2a_france.py (tirs valides)
#   forms_t/Height_<an>.tif    masque forêt au point du tir (>= 5 m)
#   prod/cov_forms_<an>.rds    jeu F (build_ifn_production.R)
#   prod/placettes_v2.rds      estimations directes
# Sortie : prod/cov_gedi_<an>.rds et un compte rendu sur la console.

suppressMessages({ library(data.table); library(sf); library(terra) })
devtools::load_all(quiet = TRUE)
cache <- Sys.getenv("NEMETON_PROD_CACHE", unset = path.expand("~/.cache/nemeton"))
ser <- st_read(file.path(cache, "ser", "ser_l93.json"), quiet = TRUE)
ser <- aggregate(ser["codeser"], by = list(SER = ser$codeser), FUN = function(x) x[1])
ser <- st_make_valid(ser[ser$SER != "-1", "SER"])

# --- 1. Agrégats GEDI par SER x année, tirs sous forêt ------------------------
cov_gedi <- function(an) {
  f_out <- file.path(cache, "prod", sprintf("cov_gedi_%d.rds", an))
  if (file.exists(f_out)) return(readRDS(f_out))
  g <- fread(file.path(cache, "gedi", sprintf("gedi_l2a_%d.csv", an)))
  # Un lot interrompu puis repris (gedi_l2a_france.py est reprenable) a pu
  # ecrire ses tirs deux fois : doublons exacts retires.
  g <- unique(g)
  pts <- st_transform(st_as_sf(g, coords = c("lon", "lat"), crs = 4326), 2154)
  # Masque forêt : hauteur FORMS-T de l'année au point du tir (cm, >= 500).
  h <- rast(file.path(cache, "forms_t", sprintf("Height_%d.tif", an)))
  hv <- terra::extract(h, vect(pts), ID = FALSE)[[1]]
  foret <- !is.na(hv) & hv >= 500
  i <- st_intersects(pts[foret, ], ser)
  k <- lengths(i) > 0
  d <- g[foret][k]
  d[, SER := ser$SER[vapply(i[k], `[`, 1L, 1L)]]
  r <- d[, .(n_tirs = .N, rh98_mean = mean(rh98), rh98_sd = sd(rh98),
             rh70_mean = mean(rh70), ge_mean = mean(elev), ge_sd = sd(elev)), by = SER]
  r[, annee := an]
  message(sprintf("GEDI %d : %d tirs valides, %d sous forêt (%.0f %%), %d SER, médiane %d tirs/SER",
                  an, nrow(g), sum(foret), 100 * mean(foret), nrow(r), as.integer(median(r$n_tirs))))
  saveRDS(r, f_out)
  r
}
# Annees explicites (NEMETON_GEDI_ANNEES="2019,2020,2021") : un CSV en cours
# d'extraction existe deja et serait agrege, puis mis en cache, incomplet.
annees <- as.integer(strsplit(Sys.getenv("NEMETON_GEDI_ANNEES", "2019,2020,2021,2022,2023,2024"), ",")[[1]])
annees <- annees[file.exists(file.path(cache, "gedi", sprintf("gedi_l2a_%d.csv", annees)))]
cg <- rbindlist(lapply(annees, cov_gedi))
# Une SER-année à moins de 200 tirs sous forêt n'est pas une moyenne fiable
# (2023 : instrument retiré de l'ISS le 17 mars).
cg <- cg[n_tirs >= 200]
cf <- rbindlist(lapply(annees, function(a) readRDS(file.path(cache, "prod", sprintf("cov_forms_%d.rds", a)))))

# --- 2. Estimations directes (mêmes formules que build_ifn_production.R) ------
pp <- readRDS(file.path(cache, "prod", "placettes_v2.rds"))
stat <- function(d, col) d[, .(n = .N, m = mean(get(col)), v = var(get(col)) / .N),
                           by = .(SER, CAMPAGNE, groupe)]
directs <- rbindlist(lapply(c("pg", "pv"), function(att) {
  sa <- stat(pp$a, att)
  sb <- stat(pp$b, paste0(att, "_coupe"))
  setnames(sb, c("n", "m", "v"), c("n_b", "m_b", "v_b"))
  d <- merge(sa, sb, by = c("SER", "CAMPAGNE", "groupe"), all.x = TRUE)
  d[is.na(m_b), `:=`(m_b = 0, v_b = 0)]
  d[groupe == "tous", .(SER, annee = as.integer(CAMPAGNE), attribut = att,
                        direct = m + m_b, psi = v + v_b)]
}))

# --- 3. Comparaison sur les mêmes domaines-années ----------------------------
voisins <- st_touches(ser)
moran <- function(res, sers) {
  idx <- match(sers, ser$SER)
  W <- matrix(0, length(sers), length(sers))
  for (i in seq_along(sers)) {
    j <- match(ser$SER[voisins[[idx[i]]]], sers); j <- j[!is.na(j)]
    if (length(j)) W[i, j] <- 1 / length(j)
  }
  st <- function(z) (length(z) / sum(W)) * sum(W * outer(z, z)) / sum(z^2)
  z <- res - mean(res); i0 <- st(z)
  c(I = i0, p = (1 + sum(replicate(499, st(sample(z))) >= i0)) / 500)
}
set.seed(54L)
evaluer <- function(d, vars, jeu, att) {
  combis <- unlist(lapply(1:3, function(k) combn(vars, k, simplify = FALSE)), recursive = FALSE)
  # Une seule métrique de hauteur par modèle (rh98 / rh70 colinéaires, §2).
  combis <- Filter(function(v) sum(v %in% c("rh98_mean", "rh70_mean")) <= 1, combis)
  aic <- vapply(combis, function(v) AIC(lm(reformulate(c(v, "GRECO"), "direct"), data = d)), numeric(1))
  best <- combis[[which.min(aic)]]
  X <- cbind(scale(as.matrix(d[, ..best])), model.matrix(~ GRECO, d)[, -1, drop = FALSE])
  fh <- estimer_fay_herriot(d$direct, d$psi, X)
  re <- mean(d$psi) / mean(fh$mse)
  # Validation croisée : SER retirée, modèle refait, prédiction synthétique.
  err <- unlist(lapply(unique(d$SER), function(s) {
    k <- d$SER == s
    if (sum(!k) <= ncol(X) + 1L) return(NULL)
    f2 <- suppressWarnings(estimer_fay_herriot(d$direct[!k], d$psi[!k], X[!k, , drop = FALSE]))
    b <- attr(f2, "beta")
    pred <- drop(cbind(1, X[k, , drop = FALSE]) %*% b)
    d$direct[k] - pred
  }))
  mo <- sapply(sort(unique(d$annee)), function(a) {
    k <- d$annee == a
    moran(d$direct[k] - fh$synthetique[k], d$SER[k])[["p"]]
  })
  message(sprintf("  %s %s : %s + GRECO | RE %.2f | RMSE CV %.3f | Moran p min %.3f (%d/%d < 0,05)",
                  att, jeu, paste(best, collapse = " + "), re, sqrt(mean(err^2)),
                  min(mo), sum(mo < 0.05), length(mo)))
  data.table(attribut = att, jeu = jeu, covariables = paste(best, collapse = "+"),
             re = re, rmse_cv = sqrt(mean(err^2)), moran_p_min = min(mo),
             n_moran_sig = sum(mo < 0.05), n = nrow(d))
}
res <- list()
for (att in c("pg", "pv")) {
  d <- merge(directs[attribut == att & !is.na(psi) & psi > 0], cg, by = c("SER", "annee"))
  d <- merge(d, cf, by = c("SER", "annee"))
  d[, GRECO := substr(SER, 1L, 1L)]
  message(sprintf("%s : %d domaines-années communs (%s)", att, nrow(d),
                  paste(sort(unique(d$annee)), collapse = ",")))
  res[[paste(att, "F")]] <- evaluer(d, c("h_mean", "h_sd", "alt_mean", "alt_sd"), "F (FORMS-T + MNT)", att)
  res[[paste(att, "G")]] <- evaluer(d, c("rh98_mean", "rh98_sd", "rh70_mean", "ge_mean", "ge_sd"), "G (GEDI L2A)", att)
}
res <- rbindlist(res)
fwrite(res, file.path(cache, "prod", "comparaison_f_g.csv"))
print(res)
for (att in c("pg", "pv")) {
  r <- res[attribut == att]
  gain <- r[jeu %like% "^G", re] / r[jeu %like% "^F", re] - 1
  message(sprintf("%s : RE G/F - 1 = %+.0f %% -> %s", att, 100 * gain,
                  if (gain >= 0.10) "G" else "F (égalité ou mieux, §5.b)"))
}
