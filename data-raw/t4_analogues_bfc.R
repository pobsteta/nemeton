# data-raw/t4_analogues_bfc.R
#
# Placettes IFN analogues de T4 (spec 068, decision T4-1) : pour chaque
# placette IFN de Bourgogne-Franche-Comte mesuree en premiere visite de 2017
# a 2021 (autour de 2019, debut de la serie FORMS-T), accroissement de
# hauteur dominante en un pas FINN (5 ans) sous le climat E-OBS 2019-2023,
# n tirages. indicateur_t4_vitalite() y choisit les analogues d'une UGF
# (meme essence dominante, meme SER, hauteur dominante initiale voisine) ;
# le paquet n'a donc pas besoin de FINN ni de libtorch pour calculer T4.
#
# Etat initial : arbres vivants de la visite (VEGET 0), diametre C13 / pi,
# poids W. Hauteurs : allometrie IFN (data-raw/allometrie_hauteur_ifn.R).
# Environnement : tx_ete = moyenne des tx de juin-aout 2019-2023,
# rr_an = cumul annuel moyen 2019-2023, prof = PROF2 de la visite (variables
# de la calibration, data-raw/prototype_finn_calibration.R).
# Modele : calibration de production corrigee (FINN_SIM_DOSSIER, defaut le
# modele B corrige de 2026.11.26).
#
# Variables : FINN_SIM_DOSSIER (calibration.rds + calibration.pt),
# FINN_IFN_ZIP, NEMETON_EOBS_CACHE, FINN_T4_TIRAGES (defaut 20),
# FINN_T4_CAMPAGNES (defaut 2017:2021), FINN_DIAG_N (essai : placettes au plus),
# FINN_THREADS.
#
# Sortie : inst/extdata/t4_analogues_bfc.csv.gz
#   placette, ser, essence, g0, h_dom, a1 .. aN (accroissements par tirage, m)
#
# Source : IGN, Inventaire forestier national (Licence Ouverte Etalab 2.0) ;
# E-OBS v33.0e (Copernicus Climate Change Service, ECA&D).

library(data.table)
library(terra)
pkgload::load_all(quiet = TRUE)

zip <- Sys.getenv("FINN_IFN_ZIP", "data-raw/ifn/export_dataifn_2005_2025.zip")
dossier <- Sys.getenv("FINN_SIM_DOSSIER")
eobs_dir <- Sys.getenv("NEMETON_EOBS_CACHE",
                       unset = path.expand("~/.local/share/nemeton/cache/eobs"))
n_tirages <- as.integer(Sys.getenv("FINN_T4_TIRAGES", "20"))
campagnes <- eval(parse(text = Sys.getenv("FINN_T4_CAMPAGNES", "2017:2021")))
n_max <- as.integer(Sys.getenv("FINN_DIAG_N", "0"))
torch::torch_set_num_threads(as.integer(Sys.getenv("FINN_THREADS", "4")))
bfc <- c("21", "25", "39", "58", "70", "71", "89", "90")
annees_climat <- 2019:2023

lire <- function(table, cols) {
  fread(cmd = sprintf("unzip -p '%s' %s.csv", zip, table), select = cols,
        colClasses = "character", encoding = "UTF-8")
}

pla <- lire("PLACETTE", c("CAMPAGNE", "IDP", "VISITE", "DEP", "XL", "YL", "CSA", "SER"))
pla <- pla[VISITE == "1" & CSA == "1" & DEP %in% bfc & as.integer(CAMPAGNE) %in% campagnes]
arb <- lire("ARBRE", c("CAMPAGNE", "IDP", "ESPAR", "VEGET", "C13", "W"))
arb <- arb[pla[, .(CAMPAGNE, IDP)], on = .(CAMPAGNE, IDP), nomatch = NULL][VEGET == "0"]
arbres <- arb[, .(placette = IDP, essence = ESPAR, d1 = as.numeric(C13) / pi * 100,
                  poids = as.numeric(W))]
arbres <- arbres[is.finite(d1) & is.finite(poids)]
pla <- pla[IDP %in% arbres$placette]
if (n_max > 0L && nrow(pla) > n_max) pla <- pla[sort(sample(.N, n_max))]
arbres <- arbres[placette %in% pla$IDP]

pts <- project(vect(pla[, .(x = as.numeric(XL), y = as.numeric(YL))], geom = c("x", "y"),
                    crs = "EPSG:2154"), "EPSG:4326")
climat <- function(var) {
  r <- rast(file.path(eobs_dir, sprintf("eobs_%s_mensuel_france_v33.0e.tif", var)))
  v <- as.matrix(terra::extract(r, pts, ID = FALSE))
  an <- as.integer(substr(names(r), 1, 4)); mo <- as.integer(substr(names(r), 6, 7))
  k <- an %in% annees_climat
  if (var == "tx") rowMeans(v[, k & mo %in% 6:8, drop = FALSE])
  else rowSums(v[, k, drop = FALSE]) / length(annees_climat)
}
eco <- lire("ECOLOGIE", c("CAMPAGNE", "IDP", "PROF2"))
env <- data.table(placette = pla$IDP, tx_ete = climat("tx"), rr_an = climat("rr"))
env[eco[pla, on = .(IDP, CAMPAGNE), .(IDP, prof = as.numeric(PROF2))], prof := i.prof,
    on = c(placette = "IDP")]
env <- env[complete.cases(env)]
cat(sprintf("%d placettes BFC (premieres visites %s), %d avec environnement complet\n",
            nrow(pla), paste(range(campagnes), collapse = "-"), nrow(env)))

cal <- readRDS(file.path(dossier, "calibration.rds"))
cal$modele <- torch::torch_load(file.path(dossier, "calibration.pt"))
stopifnot(!is.null(cal$correction))

t0 <- Sys.time()
set.seed(68)
r <- accroissement_hdom_finn(cal, arbres[placette %in% env$placette], env,
                             ser = setNames(pla$SER, pla$IDP), n_tirages = n_tirages)
cat(sprintf("FINN : %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

r <- as.data.table(r)
large <- dcast(r, placette + ser + essence + g0 + h_dom ~ tirage, value.var = "accroissement")
setnames(large, as.character(seq_len(n_tirages)), paste0("a", seq_len(n_tirages)))
cols <- paste0("a", seq_len(n_tirages))
large[, (cols) := lapply(.SD, round, 3), .SDcols = cols]
large[, `:=`(g0 = round(g0, 2), h_dom = round(h_dom, 2))]
large <- large[is.finite(h_dom)]

cat("\nAccroissement moyen (m / 5 ans) par essence dominante :\n")
print(r[is.finite(accroissement), .(n = uniqueN(placette), h_dom = mean(h_dom),
                                     acc = mean(accroissement),
                                     sd_tirages = mean(tapply(accroissement, placette, sd))),
        by = essence][n >= 30][order(-n)], digits = 3)
fwrite(large, "inst/extdata/t4_analogues_bfc.csv.gz")
cat(sprintf("\n%d placettes ecrites\n", nrow(large)))
