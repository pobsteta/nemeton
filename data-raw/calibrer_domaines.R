# calibrer_domaines.R — calibrage des domaines utilisateur (spec 054 lot 5-bis)
# -----------------------------------------------------------------------------
# Spec 054 lot 5-bis. Pseudo-domaines : mailles carrees de COTE km sur la
# France. Pour chaque maille, moyenne 2020-2024 :
#   direct    : placettes IFN de la maille (vives + coupees), sa variance psi ;
#   P_ser     : SER ponderees par la part des placettes (lot 5) ;
#   P_dom     : modele national (beta) applique aux covariables DE LA MAILLE
#               (hauteur FORMS-T sous masque >= 5 m, altitude ponderee foret,
#               GRECO majoritaire) -> lot 5-bis.
# Critere : MSE debiaisee = moyenne((direct - P)^2 - psi). Plus bas = mieux.
suppressMessages({ library(data.table); library(sf); library(terra) })
devtools::load_all(quiet = TRUE)
cache <- path.expand("~/.cache/nemeton")
camp <- 2020:2024
pl <- as.data.table(nemeton:::.ifn_prod_placettes())[campagne %in% camp]
coef <- fread("inst/extdata/ifn_production_modele_coef.csv")
dem <- rast(file.path(cache, "ser", "dem_250m.tif"))
forms <- lapply(camp, function(a) rast(file.path(cache, "prod", sprintf("forms_250m_%d.tif", a))))

valider <- function(cote_km, att) {
  pts <- st_as_sf(pl, coords = c("xl", "yl"), crs = 2154)
  grille <- st_sf(geometry = st_make_grid(pts, cellsize = cote_km * 1000))
  grille$cell <- seq_len(nrow(grille))
  pl$cell <- unlist(lapply(st_intersects(pts, grille), `[`, 1L))
  # Direct par maille x campagne, puis moyenne sur la fenetre.
  vif <- pl[echantillon == "vif", .(n = .N, m = mean(get(att)), v = var(get(att)) / .N), by = .(cell, campagne)]
  cou <- pl[echantillon == "coupe", .(mb = mean(get(att)), vb = var(get(att)) / .N), by = .(cell, campagne)]
  d <- merge(vif, cou, by = c("cell", "campagne"), all.x = TRUE)
  d[is.na(mb), `:=`(mb = 0, vb = 0)][is.na(vb), vb := 0]
  d <- d[n >= 2, .(n = sum(n), direct = mean(m + mb), psi = sum(v + vb) / .N^2, k = .N), by = cell][k == length(camp)]
  # P_ser : SER ponderees par les placettes vives de la maille.
  st <- as.data.table(ifn_production_ser(niveau = "ser", attribut = att, groupe = "tous", campagne = camp))
  st <- st[, .(est = mean(estimation)), by = ser]
  w <- pl[echantillon == "vif", .N, by = .(cell, ser)][, w := N / sum(N), by = cell]
  pser <- merge(w, st, by = "ser")[, .(p_ser = sum(w * est) / sum(w)), by = cell]
  greco <- w[order(-w), .(GRECO = substr(ser[1], 1, 1)), by = cell]
  # Covariables de la maille, moyennees sur les annees.
  g <- grille[grille$cell %in% d$cell, ]
  cov <- rbindlist(lapply(seq_along(camp), function(i) {
    e <- exactextractr::exact_extract(forms[[i]], g, "sum", progress = FALSE)
    names(e) <- c("n", "s1", "s2")
    a <- exactextractr::exact_extract(c(dem, dem^2) |> setNames(c("a", "a2")), g, "weighted_mean",
                                      weights = resample(forms[[i]][["n"]], dem, method = "near"), progress = FALSE)
    data.table(cell = g$cell, h_mean = e$s1 / e$n, h_sd = sqrt(pmax(e$s2 / e$n - (e$s1 / e$n)^2, 0)),
               alt_mean = a[[1]], alt_sd = sqrt(pmax(a[[2]] - a[[1]]^2, 0)), nf = e$n)
  }))[nf > 0, lapply(.SD, mean), by = cell, .SDcols = c("h_mean", "h_sd", "alt_mean", "alt_sd")]
  cf <- coef[attribut == att]
  x <- merge(merge(cov, greco, by = "cell"), d, by = "cell")
  pdom <- cf[terme == "(Intercept)", beta] +
    Reduce(`+`, lapply(cf[!is.na(centre), terme], function(v) {
      r <- cf[terme == v]; r$beta * (x[[v]] - r$centre) / r$echelle
    })) +
    vapply(x$GRECO, function(gg) { b <- cf[terme == paste0("GRECO", gg), beta]; if (length(b)) b else 0 }, numeric(1))
  x[, p_dom := pdom]
  x <- merge(x, pser, by = "cell")
  # Variante hybride : SER (avec son effet propre) + beta x ecart des
  # covariables de la maille a celles de ses SER (ponderees comme P_ser).
  covs <- rbindlist(lapply(camp, function(a) readRDS(file.path(cache, "prod", sprintf("cov_forms_%d.rds", a)))))[
    , lapply(.SD, mean), by = SER, .SDcols = c("h_mean", "h_sd", "alt_mean", "alt_sd")]
  vars_m <- cf[!is.na(centre), terme]
  xs <- merge(w, covs, by.x = "ser", by.y = "SER")[, lapply(.SD, function(v) sum(w * v) / sum(w)),
                                                    by = cell, .SDcols = vars_m]
  setnames(xs, vars_m, paste0(vars_m, "_ser"))
  x <- merge(x, xs, by = "cell")
  x[, p_hyb := p_ser + Reduce(`+`, lapply(vars_m, function(v) {
    r <- cf[terme == v]; r$beta * (get(v) - get(paste0(v, "_ser"))) / r$echelle }))]
  # Controle : beta applique aux covariables DES SER reproduit leur synthetique.
  cs <- merge(covs, unique(w[, .(ser, GRECO = substr(ser, 1, 1))]), by.x = "SER", by.y = "ser")
  ps <- cf[terme == "(Intercept)", beta] + Reduce(`+`, lapply(vars_m, function(v) {
    r <- cf[terme == v]; r$beta * (cs[[v]] - r$centre) / r$echelle })) +
    vapply(cs$GRECO, function(gg) { b <- cf[terme == paste0("GRECO", gg), beta]; if (length(b)) b else 0 }, numeric(1))
  cs <- merge(cs[, .(SER, ps)], st, by.x = "SER", by.y = "ser")
  message(sprintf("  controle SER : cor(beta x covariables SER, estimation FH) = %.2f", cor(cs$ps, cs$est)))
  mse <- function(p) mean((x$direct - p)^2 - x$psi)
  res_echelle[[paste(att, cote_km)]] <<- data.table(
    attribut = att, cote_km = cote_km, surface_ha = (cote_km * 1000)^2 / 1e4,
    n_mailles = nrow(x), n_plac_med = median(x$n),
    a_eff_ser = mse(x$p_ser), a_eff_hyb = mse(x$p_hyb), a_eff_dom = mse(x$p_dom),
    psi_moyen = mean(x$psi))
  message(sprintf("%s, mailles %d km : %d mailles (placettes vives : mediane %d) | MSE debiaisee : SER %.4f | domaine %.4f (%+.0f %%) | hybride %.4f (%+.0f %%) | psi moyen %.4f",
                  att, cote_km, nrow(x), as.integer(median(x$n)), mse(x$p_ser),
                  mse(x$p_dom), 100 * (1 - mse(x$p_dom) / mse(x$p_ser)),
                  mse(x$p_hyb), 100 * (1 - mse(x$p_hyb) / mse(x$p_ser)), mean(x$psi)))
  invisible(x)
}
res_echelle <- list()
for (att in c("pv", "pg")) for (cote in c(100, 50, 30, 20, 15)) valider(cote, att)
res_echelle <- rbindlist(res_echelle)
fwrite(res_echelle, file.path(cache, "prod", "lot5bis_echelles.csv"))
print(res_echelle[, .(attribut, cote_km, n_mailles, n_plac_med, a_eff_ser = round(a_eff_ser, 4),
                      a_eff_hyb = round(a_eff_hyb, 4), psi_moyen = round(psi_moyen, 4))])

# --- Calibrage : variance residuelle selon la surface, covariables des SER ---
# log(A_eff) = a + b log(surface_ha), par attribut x predicteur, moindres carres
# ponderes par le nombre de mailles. A_eff est la MSE du predicteur face a la
# verite du domaine (debiaisee de psi) : gamma = A_eff / (A_eff + psi).
# Validation (2026-10-01) : l'hybride bat la SER pour PV a toutes les echelles,
# pas pour PG -> le predicteur hybride n'est servi que pour PV.
ech <- rbindlist(lapply(c("pv", "pg"), function(att) rbindlist(lapply(c("ser", "hybride"), function(pr) {
  r <- res_echelle[attribut == att]
  y <- if (pr == "ser") r$a_eff_ser else r$a_eff_hyb
  f <- lm(log(y) ~ log(surface_ha), weights = n_mailles, data = r)
  data.table(attribut = att, predicteur = pr, a = coef(f)[[1]], b = coef(f)[[2]],
             surface_min_ha = min(r$surface_ha), surface_max_ha = max(r$surface_ha),
             servi = pr == "ser" || att == "pv")
}))))
print(ech)
fwrite(ech, "inst/extdata/ifn_production_echelle.csv")
covs_ser <- rbindlist(lapply(camp, function(a) readRDS(file.path(cache, "prod", sprintf("cov_forms_%d.rds", a)))))[
  , lapply(.SD, function(v) signif(mean(v), 6)), by = SER, .SDcols = c("h_mean", "h_sd", "alt_mean", "alt_sd")]
setnames(covs_ser, "SER", "ser")
fwrite(covs_ser, "inst/extdata/ifn_production_covariables_ser.csv")
message(nrow(covs_ser), " SER -> inst/extdata/ifn_production_covariables_ser.csv (campagnes ",
        paste(range(camp), collapse = "-"), ")")
