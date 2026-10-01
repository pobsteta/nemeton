# build_ifn_production.R — table de production IFN par SER x campagne (spec 054, lot 1)
# -----------------------------------------------------------------------------
# Produit inst/extdata/ifn_production_ser.csv :
#   1. production par arbre puis par placette (R/ifn_production.R) ;
#   2. estimation directe par SER / GRECO / national x campagne x groupe ;
#   3. covariables du jeu F (spec 054 §5.b) : hauteur FORMS-T sous masque foret
#      (>= 5 m), moyenne et ecart-type a 10 m, et altitude IGN ponderee par la
#      part de foret, par SER x annee ;
#   4. selection de variables (best subset <= 3, AIC des moindres carres sur les
#      estimations directes, comme leaps dans l'article) ;
#   5. Fay-Herriot (estimer_fay_herriot) sur SER x campagne, groupe "tous",
#      campagnes couvertes par FORMS-T, GRECO en effet fixe ; I de Moran des
#      residus par contiguite entre SER ;
#   6. controle national contre la reference IGN (flux2024 : 5,4 m3/ha/an).
#
# Lourd : FORMS-T = 6 x 6,3 Go. Lancer dans un cgroup plafonne :
#   systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 \
#     Rscript data-raw/build_ifn_production.R
#
# Caches (hors depot) : NEMETON_PROD_CACHE, defaut ~/.cache/nemeton.
#   forms_t/Height_<annee>.tif   Zenodo 15489231 (CC-BY 4.0), a telecharger
#   ser/ser_l93.json             WFS INRAE inrae:ser_l93
#   ser/dem_250m.tif             WMS IGN ELEVATION.ELEVATIONGRIDCOVERAGE
#   prod/*.rds                   resultats intermediaires

suppressMessages({
  library(data.table)
  library(terra)
  library(sf)
})
devtools::load_all(quiet = TRUE)

cache <- Sys.getenv("NEMETON_PROD_CACHE", unset = path.expand("~/.cache/nemeton"))
dir.create(file.path(cache, "prod"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(cache, "ser"), showWarnings = FALSE, recursive = TRUE)
annees_cov <- 2019:2024   # fenetre commune avec GEDI (spec 054 §5.b)
REF_IGN_PV <- 5.4         # m3/ha/an, IGN flux2024, periode 2014-2022
REF_IGN_PREL <- 3.3       # m3/ha/an, idem (prelevements, codes coupes 6 et 7)
terraOptions(memfrac = 0.4, tempdir = file.path(cache, "prod"))

# --- 1. Production par placette ---------------------------------------------
# Deux echantillons de placettes par campagne t (spec 054 §3.c) :
#   A = placettes de 1re visite en t : croissance des arbres vifs (cernes t-5..t-1) ;
#   B = placettes revisitees en t (1er passage en t-5) : arbres coupes entre les
#       deux passages -> leur production avant coupe et le volume preleve.
f_plac <- file.path(cache, "prod", "placettes_v2.rds")
if (!file.exists(f_plac)) {
  src_dir <- Sys.getenv("NEMETON_IFN_SRC", unset = "data-raw/ifn")
  dat <- ifn_charger(c("ARBRE", "PLACETTE"), dest_dir = src_dir)
  millesime <- attr(dat, "millesime")
  pla <- as.data.table(dat$PLACETTE)[, .(CAMPAGNE, IDP, VISITE = as.character(VISITE), SER)]
  pla <- pla[!is.na(SER) & SER != ""]
  pl1 <- pla[VISITE == "1", .(CAMPAGNE, IDP, SER)]
  pl2 <- pla[VISITE == "2", .(CAMPAGNE, IDP, SER)]
  arbre <- as.data.table(dat$ARBRE)
  rm(dat)
  ar <- arbre[VEGET == "0", .(CAMPAGNE, IDP, A, ESPAR, C13, HTOT, IR5, V, W)]
  coupes <- arbre[VEGET5 %in% c("6", "7"), .(CAMPAGNE, IDP, A, VEGET5)]
  rm(arbre)
  for (j in c("C13", "HTOT", "IR5", "V", "W")) set(ar, j = j, value = as.numeric(ar[[j]]))
  ar <- ar[!is.na(C13) & !is.na(W) & C13 > 0]
  # Seuls les arbres des placettes de 1re visite (la revisite ne porte pas IR5).
  ar <- ar[pl1, on = .(CAMPAGNE, IDP), nomatch = NULL][, SER := NULL]
  message(nrow(ar), " arbres vivants de 1re visite, ", nrow(pl1), " placettes ; ",
          nrow(pl2), " placettes revisitees, ", nrow(coupes), " arbres coupes")

  # Allometrie hauteur-diametre (voie (b), lot 1-bis).
  beta <- .ifn_beta_hauteur(as.data.frame(ar))
  message("beta hauteur-diametre :\n",
          paste(sprintf("  %s %s : %.3f (n = %d)", beta$groupe, beta$cat, beta$beta, beta$n),
                collapse = "\n"))
  fwrite(beta, file.path(cache, "prod", "beta_hauteur.csv"))

  arb <- .ifn_production_arbres(as.data.frame(ar), beta = beta)
  message(sprintf("G imputee : %.1f %% ; G sans valeur apres imputation : %.2f %%",
                  100 * sum(arb$W * arb$g * arb$ir5_impute) / sum(arb$W * arb$g),
                  100 * sum(arb$W * arb$g * is.na(arb$rg)) / sum(arb$W * arb$g)))
  plac <- .ifn_production_placettes(arb, as.data.frame(pl1))
  setDT(plac)
  # Regle D7 : placette exclue si plus de 50 % de sa G reste sans valeur.
  excl <- plac[groupe == "tous" & g_tot > 0 & g_sans_valeur / g_tot > 0.5,
               .(CAMPAGNE, IDP)]
  message(nrow(excl), " placettes exclues (D7)")
  plac <- plac[!excl, on = .(CAMPAGNE, IDP)]

  cp <- .ifn_production_coupes(arb, as.data.frame(coupes))
  message(sprintf("%d arbres coupes rattaches a leur 1er passage (%.0f %%)",
                  nrow(cp), 100 * nrow(cp) / nrow(coupes)))
  plac_b <- .ifn_sommer_placettes(cp, as.data.frame(pl2),
                                  c("pv_coupe", "pg_coupe", "prel", "prel_vidange"))
  setDT(plac_b)
  # Une placette revisitee dont le 1er passage a ete exclu (D7) l'est aussi.
  excl_b <- excl[, .(CAMPAGNE = as.character(as.integer(CAMPAGNE) + 5L), IDP)]
  plac_b <- plac_b[!excl_b, on = .(CAMPAGNE, IDP)]
  plac[, GRECO := substr(SER, 1L, 1L)]
  plac_b[, GRECO := substr(SER, 1L, 1L)]
  saveRDS(list(a = plac, b = plac_b, beta = beta, millesime = millesime), f_plac)
}
pp <- readRDS(f_plac)
plac <- pp$a
plac_b <- pp$b
millesime <- pp$millesime

# --- 2. Estimations directes -------------------------------------------------
# pg, pv : somme des deux echantillons independants (A vifs + B coupes),
#          variances additionnees ; une campagne sans revisite n'a que A.
# prel, prel_vidange : echantillon B seul.
directs <- function(niveau, cle_dom) {
  by <- c(cle_dom, "CAMPAGNE", "groupe")
  stat <- function(d, col) d[, .(n = .N, m = mean(get(col)), v = var(get(col)) / .N), by = by]
  out <- list()
  for (att in c("pg", "pv")) {
    sa <- stat(plac, att)
    sb <- stat(plac_b, paste0(att, "_coupe"))
    setnames(sb, c("n", "m", "v"), c("n_b", "m_b", "v_b"))
    d <- merge(sa, sb, by = by, all.x = TRUE)
    d[is.na(m_b), `:=`(n_b = 0L, m_b = 0, v_b = 0)]
    d[, `:=`(n_plac = n, direct = m + m_b, psi = v + v_b)]
    imp <- plac[, .(part_g_imputee = sum(g_imputee) / max(sum(g_tot), 1e-12)), by = by]
    d <- merge(d, imp, by = by)
    d[, attribut := att]
    out[[att]] <- d[, c(by, "attribut", "n_plac", "direct", "psi", "part_g_imputee"), with = FALSE]
  }
  for (att in c("prel", "prel_vidange")) {
    d <- stat(plac_b, att)
    d[, `:=`(n_plac = n, direct = m, psi = v, part_g_imputee = NA_real_, attribut = att)]
    out[[att]] <- d[, c(by, "attribut", "n_plac", "direct", "psi", "part_g_imputee"), with = FALSE]
  }
  r <- rbindlist(out)
  r[, niveau := niveau]
  r
}
d_ser <- directs("ser", "SER")
d_gre <- directs("greco", "GRECO")
d_nat <- directs("national", character(0))

ctrl <- function(att) d_nat[groupe == "tous" & attribut == att &
                              as.integer(CAMPAGNE) %between% c(2019, 2023),
                            weighted.mean(direct, n_plac)]
message(sprintf(paste0("Controle national (campagnes 2019-2023, periode 2014-2022) : ",
                       "PV %.2f m3/ha/an = %.0f %% de l'IGN (%.1f) ; prelevement %.2f = %.0f %% de l'IGN (%.1f) ; ",
                       "ratio %.2f (IGN %.2f)"),
                ctrl("pv"), 100 * ctrl("pv") / REF_IGN_PV, REF_IGN_PV,
                ctrl("prel"), 100 * ctrl("prel") / REF_IGN_PREL, REF_IGN_PREL,
                ctrl("prel") / ctrl("pv"), REF_IGN_PREL / REF_IGN_PV))

# --- 3. Covariables du jeu F -------------------------------------------------
ser_f <- file.path(cache, "ser", "ser_l93.json")
if (!file.exists(ser_f)) {
  download.file(paste0("https://geodata.inrae.fr/geoserver/inrae/ows?service=WFS",
                       "&version=2.0.0&request=GetFeature&typeNames=inrae:ser_l93",
                       "&outputFormat=application/json&srsName=EPSG:2154"),
                ser_f, quiet = TRUE)
}
ser <- st_read(ser_f, quiet = TRUE)
ser <- aggregate(ser["codeser"], by = list(SER = ser$codeser), FUN = function(x) x[1])
ser <- st_make_valid(ser[ser$SER != "-1", "SER"])   # "-1" : hors SER dans le WFS
manquantes <- setdiff(unique(plac$SER), ser$SER)
if (length(manquantes)) message("SER sans polygone : ", paste(manquantes, collapse = ", "))

# Altitude 250 m : 12 x 12 dalles WMS de 100 km (valeurs Float32 brutes).
dem_f <- file.path(cache, "ser", "dem_250m.tif")
if (!file.exists(dem_f)) {
  dalles <- character(0)
  for (x0 in seq(75730, 1175730, by = 100000)) for (y0 in seq(6005080, 7105080, by = 100000)) {
    f <- file.path(cache, "ser", sprintf("dem_%d_%d.tif", x0, y0))
    if (!file.exists(f)) {
      u <- sprintf(paste0("https://data.geopf.fr/wms-r/wms?SERVICE=WMS&VERSION=1.3.0",
                          "&REQUEST=GetMap&LAYERS=ELEVATION.ELEVATIONGRIDCOVERAGE&STYLES=",
                          "&CRS=EPSG:2154&BBOX=%d,%d,%d,%d&WIDTH=400&HEIGHT=400",
                          "&FORMAT=image/geotiff"), x0, y0, x0 + 100000, y0 + 100000)
      # Le WMS renvoie parfois un 400 passager : trois essais.
      for (essai in 1:3) {
        ok <- tryCatch({ download.file(u, f, quiet = TRUE, mode = "wb"); TRUE },
                       error = function(e) FALSE, warning = function(w) FALSE)
        if (ok && file.size(f) > 1000) break
        unlink(f); Sys.sleep(5 * essai)
      }
      if (!file.exists(f)) stop("Dalle d'altitude introuvable apres 3 essais : ", u)
    }
    dalles <- c(dalles, f)
  }
  r <- merge(sprc(lapply(dalles, rast)))
  crs(r) <- "EPSG:2154"  # jamais en aveugle : les dalles sont demandees en 2154
  NAflag(r) <- -99999
  writeRaster(r, dem_f, overwrite = TRUE)
}
dem <- rast(dem_f)

# Hauteur : par annee, sommes exactes a 10 m agregees a 250 m (n, somme h,
# somme h^2 des pixels >= 5 m), puis par SER. Moyenne et ecart-type exacts a
# 10 m. Lecture par bandes de 250 lignes, agregation vectorisee en memoire :
# aucun raster intermediaire a 10 m sur disque (13 milliards de cellules).
# Bandes de 125 lignes (15 M de valeurs) : le pic memoire reste sous 3 Go, ce qui
# permet de lancer les 6 annees en parallele dans des cgroups de 4 Go.
agreger_forms <- function(f, fact = 25L, bande = 125L, seuil_cm = 500,
                          sauvegarde = NULL) {
  h <- rast(f)
  nc <- ncol(h); nr <- nrow(h)
  stopifnot(nc %% fact == 0L, nr %% bande == 0L, bande %% fact == 0L)
  oc <- nc %/% fact; ob <- bande %/% fact
  out <- array(0, c(oc, nr %/% fact, 3L))
  readStart(h); on.exit(readStop(h))
  for (b in seq_len(nr %/% bande)) {
    v <- readValues(h, row = (b - 1L) * bande + 1L, nrows = bande)
    # Pas d'ifelse() : 2,5 fois plus lent sur 30 millions de valeurs.
    ok <- !is.na(v) & v >= seuil_cm
    v[!ok] <- 0
    v <- v / 100
    for (k in 1:3) {
      x <- switch(k, as.numeric(ok), v, v * v)
      dim(x) <- c(fact, oc, bande)          # (col fine, col grosse, ligne fine)
      x <- colSums(x)                        # (col grosse, ligne fine)
      dim(x) <- c(oc, fact, ob)              # (col grosse, ligne fine, ligne grosse)
      x <- colSums(aperm(x, c(2L, 1L, 3L)))  # (col grosse, ligne grosse)
      out[, (b - 1L) * ob + seq_len(ob), k] <- x
    }
  }
  # Sommes sauvees AVANT de construire le raster : un OOM a cette etape a coute
  # 6 x 35 min de calcul au premier essai (journalctl, 2026-10-01).
  rm(v, ok, x); gc()
  if (!is.null(sauvegarde)) saveRDS(out, sauvegarde)
  # Raster construit en une fois : (lignes, colonnes, couches).
  r <- rast(aperm(out, c(2L, 1L, 3L)), extent = ext(h), crs = crs(h))
  rm(out); gc()
  names(r) <- c("n", "s1", "s2")
  r
}

cov_annee <- function(an) {
  f_out <- file.path(cache, "prod", sprintf("cov_forms_%d.rds", an))
  if (file.exists(f_out)) return(readRDS(f_out))
  f_ag <- file.path(cache, "prod", sprintf("forms_250m_%d.tif", an))
  if (!file.exists(f_ag)) {
    f_somme <- file.path(cache, "prod", sprintf("forms_sommes_%d.rds", an))
    h <- rast(file.path(cache, "forms_t", sprintf("Height_%d.tif", an)))
    r <- if (file.exists(f_somme)) {
      rast(aperm(readRDS(f_somme), c(2L, 1L, 3L)), extent = ext(h), crs = crs(h))
    } else {
      agreger_forms(sources(h), sauvegarde = f_somme)
    }
    names(r) <- c("n", "s1", "s2")
    writeRaster(r, f_ag, overwrite = TRUE)
    rm(r); gc()
  }
  st <- rast(f_ag)
  n <- st[["n"]]
  e <- exactextractr::exact_extract(st, ser, "sum", progress = FALSE)
  e <- as.data.table(e)
  setnames(e, c("n", "s1", "s2"))
  e[, SER := ser$SER]
  e[, `:=`(h_mean = s1 / n, h_sd = sqrt(pmax(s2 / n - (s1 / n)^2, 0)))]
  # Part de foret de la SER (pixels de 100 m2 / surface).
  e[, foret_part := n * 100 / as.numeric(st_area(ser))]
  # Altitude ponderee par la part de foret de chaque cellule de 250 m.
  nn <- resample(n, dem, method = "near")
  alt <- c(dem, dem^2)
  names(alt) <- c("alt", "alt2")   # exact_extract exige des noms uniques
  a <- exactextractr::exact_extract(alt, ser, "weighted_mean",
                                    weights = nn, progress = FALSE)
  e[, alt_mean := a[[1]]]
  e[, alt_sd := sqrt(pmax(a[[2]] - a[[1]]^2, 0))]
  e[, annee := an]
  r <- e[, .(SER, annee, h_mean, h_sd, foret_part, alt_mean, alt_sd)]
  saveRDS(r, f_out)
  r
}
# Mode une-annee : NEMETON_PROD_ANNEE=2021 calcule les covariables de cette
# annee puis s'arrete. Permet de lancer les 6 annees en parallele (environ
# 45 min chacune) avant le run complet, qui les relit depuis le cache.
seule <- Sys.getenv("NEMETON_PROD_ANNEE")
if (nzchar(seule)) {
  invisible(cov_annee(as.integer(seule)))
  quit(save = "no")
}

# Un fichier en cours de telechargement existe deja : on exige sa taille
# complete (6,2 a 6,4 Go selon l'annee sur Zenodo).
f_forms <- file.path(cache, "forms_t", sprintf("Height_%d.tif", annees_cov))
disp <- annees_cov[file.exists(f_forms) & file.size(f_forms) > 6e9]
if (!length(disp)) {
  message("Aucune annee FORMS-T complete : arret apres le controle national.")
  quit(save = "no")
}
cov <- rbindlist(lapply(disp, function(an) { message("FORMS-T ", an); cov_annee(an) }))

# --- 4-5. Selection et Fay-Herriot (SER x campagne, groupe "tous") ----------
# GRECO en effet fixe, toujours present (decision 2026-10-01, spec 054 §8.7) :
# sans lui, les residus sont autocorreles entre SER voisines (Moran par
# contiguite I = 0,16-0,34, p <= 0,004) ; avec lui, plus de structure
# significative et RE PV 2,68 -> 3,34. L'AIC ne choisit que les covariables
# continues, a GRECO fixee.
vars <- c("h_mean", "h_sd", "alt_mean", "alt_sd")
voisins <- st_touches(ser)
moran_contiguite <- function(res, sers, n_perm = 999L) {
  idx <- match(sers, ser$SER)
  W <- matrix(0, length(sers), length(sers))
  for (i in seq_along(sers)) {
    j <- match(ser$SER[voisins[[idx[i]]]], sers)
    j <- j[!is.na(j)]
    if (length(j)) W[i, j] <- 1 / length(j)
  }
  stat <- function(z) (length(z) / sum(W)) * sum(W * outer(z, z)) / sum(z^2)
  z <- res - mean(res)
  i0 <- stat(z)
  c(I = i0, p = (1 + sum(replicate(n_perm, stat(sample(z))) >= i0)) / (n_perm + 1))
}
set.seed(54L)
fh_res <- list()
for (att in c("pg", "pv")) {
  d <- d_ser[groupe == "tous" & attribut == att & as.integer(CAMPAGNE) %in% disp]
  d[, `:=`(annee = as.integer(CAMPAGNE), GRECO = substr(SER, 1L, 1L))]
  d <- merge(d, cov, by = c("SER", "annee"))
  combis <- unlist(lapply(1:3, function(k) combn(vars, k, simplify = FALSE)),
                   recursive = FALSE)
  aic <- vapply(combis, function(v) {
    AIC(lm(reformulate(c(v, "GRECO"), "direct"), data = d[!is.na(psi) & psi > 0]))
  }, numeric(1))
  best <- combis[[which.min(aic)]]
  message(sprintf("%s : covariables retenues %s + GRECO (AIC %.1f)", att,
                  paste(best, collapse = " + "), min(aic)))
  X <- cbind(scale(as.matrix(d[, ..best])), model.matrix(~ GRECO, d)[, -1, drop = FALSE])
  fh <- estimer_fay_herriot(d$direct, d$psi, X)
  ok <- fh$nature == "fay_herriot"
  r2 <- 1 - sum((d$direct[ok] - fh$synthetique[ok])^2 - d$psi[ok]) /
    sum((d$direct[ok] - mean(d$direct[ok]))^2)
  message(sprintf(paste0("%s : sigma2_v = %.4g ; R2 synthetique (corrige de psi) %.2f ; ",
                         "RE globale = %.2f ; RSE mediane FH %.1f %% vs direct %.1f %%"),
                  att, attr(fh, "sigma2_v"), r2,
                  mean(d$psi[ok]) / mean(fh$mse[ok]),
                  median(fh$rse), median(100 * sqrt(d$psi) / d$direct, na.rm = TRUE)))
  # I de Moran des residus (direct - synthetique), par campagne, contiguite.
  for (cp in sort(unique(d$annee))) {
    k <- which(d$annee == cp & ok)
    m <- moran_contiguite(d$direct[k] - fh$synthetique[k], d$SER[k])
    message(sprintf("  Moran %s %d : I = %.3f, p = %.3f", att, cp, m[["I"]], m[["p"]]))
  }
  d[, `:=`(estimation = fh$estimation, mse = fh$mse, rse = fh$rse,
           gamma = fh$gamma, nature = fh$nature,
           covariables = paste0("forms_mnt:", paste(best, collapse = "+"), "+greco"))]
  fh_res[[att]] <- d[, .(SER, CAMPAGNE, attribut, groupe, estimation, mse, rse,
                         gamma, nature, covariables)]
}
fh_res <- rbindlist(fh_res)

# --- 6. Assemblage -----------------------------------------------------------
tab <- rbindlist(list(d_ser, d_gre, d_nat), fill = TRUE)
tab <- merge(tab, fh_res, by = c("SER", "CAMPAGNE", "attribut", "groupe"), all.x = TRUE)
# Hors FH : l'estimation est la moyenne directe, sa MSE la variance psi.
hors <- is.na(tab$nature)
tab[hors, `:=`(estimation = direct, mse = psi, gamma = 1, nature = "direct",
               covariables = NA_character_)]
tab[hors, rse := 100 * sqrt(mse) / abs(estimation)]
tab[, `:=`(ser = SER, greco = fifelse(niveau == "ser", substr(SER, 1, 1), GRECO),
           campagne = as.integer(CAMPAGNE),
           methode_pv = fifelse(attribut == "pv", "allometrie_hauteur_diametre", NA_character_),
           millesime = millesime,
           # Source courte : repetee sur chaque ligne (1,8 Mo en version longue).
           # Detail : ?ifn_production_ser et spec 054.
           source = "IGN IFN brut (Etalab 2.0) ; FORMS-T (CC-BY 4.0) ; spec 054")]
tab[niveau != "ser", ser := NA_character_]
tab[niveau == "national", greco := NA_character_]
num <- c("direct", "psi", "estimation", "mse", "rse", "gamma", "part_g_imputee")
tab[, (num) := lapply(.SD, signif, 5), .SDcols = num]
tab <- tab[, .(niveau, ser, greco, campagne, attribut, groupe, n_plac, direct, psi,
               estimation, mse, rse, gamma, nature, methode_pv, covariables,
               part_g_imputee, millesime, source)]
setorder(tab, niveau, ser, greco, attribut, groupe, campagne)
fwrite(tab, "inst/extdata/ifn_production_ser.csv", na = "")
message(nrow(tab), " lignes -> inst/extdata/ifn_production_ser.csv")
