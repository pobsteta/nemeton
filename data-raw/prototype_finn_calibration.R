# data-raw/prototype_finn_calibration.R
#
# Prototype de calibration FINN sur placettes IFN revisitees de BFC (spec 068,
# etape 3, critere d'acceptation 2) : FINN calibre sur au moins 200 placettes,
# erreur de prediction de la surface terriere a 5 ans sur des placettes
# TENUES A L'ECART de la calibration, comparee a la persistance (G a 5 ans =
# G initiale apres coupes), le modele nul a battre.
#
# Donnees : export IFN (Licence Ouverte), data-raw/ifn/export_dataifn_*.zip ;
#   placettes de 1re visite en t (CSA = 1, foret de production) revisitees en
#   t + 5, revisites 2015 et suivantes (depuis 2015 tous les arbres sont revus,
#   metadonnees IFN, VEGET5) ;
#   altitude : MNT IGN 250 m du cache de la spec 054 (ser/dem_250m.tif) ;
#   climat : E-OBS v33.0e mensuel (tx, rr) du cache de la spec 063
#   (~/.local/share/nemeton/cache/eobs/eobs_{tx,rr}_mensuel_france_v33.0e.tif) ;
#   sol : profondeur de sondage PROF2 (dm) de la table ECOLOGIE de l'IFN.
#
# Choix (a relire, pas des valeurs tirees d'un modele) :
#   - un site FINN = une placette IFN, une placette FINN de 0,0707 ha (cercle de
#     15 m, le plus grand des cercles concentriques) ; chaque arbre compte pour
#     W x 0,0707 tiges, W etant son poids a l'hectare (cercles de 6, 9, 15 m) ;
#   - un pas FINN = 5 ans (l'intervalle de revisite) ;
#   - etat a 5 ans (VEGET5, metadonnees IFN) : 0 vivant ; M, 5, C, A, 1, 2, T
#     mort ou sorti du peuplement (mortalite naturelle, chablis compris) ;
#     6, 7 coupe ; N non retrouve -> placette exclue ; un arbre vivant dont le
#     diametre varie hors de [-5, +15] cm en 5 ans -> placette exclue (erreur
#     de mesure ou d'appariement ; seuils choisis ici, a relire) ;
#   - la revisite ne porte pas de poids W : un arbre suivi garde celui de sa
#     1re visite, un recrute recoit le poids theorique de son cercle ;
#   - les arbres coupes sont retires de l'etat initial : la coupe est supposee
#     faite en debut d'intervalle (comme l'eclaircie entre deux pas, D-2) ; FINN
#     n'apprend donc que la dynamique naturelle ;
#   - recrutes : arbres presents a la revisite sans ligne en 1re visite
#     (C13 >= 23,5 cm, soit 7,5 cm de diametre) ; `recruits_dbh` = leur
#     diametre moyen observe ;
#   - essences : les plus frequentes couvrant 90 % de la surface terriere
#     initiale, le reste en "other" ;
#   - environnement (FINN_ENV) : "alt" = altitude seule ; "climat_sol" =
#     moyenne des tx de juin-aout et cumul annuel de rr sur les 5 ans de
#     l'intervalle (E-OBS), profondeur de sol PROF2 ; en unites naturelles
#     (FINN standardise). Altitude et temperature sont trop correlees pour
#     entrer ensemble (vignette D de FINN).
#
# Lancement (FINN et torch installes) :
#   Rscript data-raw/prototype_finn_calibration.R
# Rien n'est ecrit dans le paquet ; le script affiche ses resultats.

suppressMessages({
  library(FINN)
  library(data.table)
  library(terra)
})

FINN.seed(42)
set.seed(42)
zip <- Sys.getenv("NEMETON_IFN_ZIP",
                  unset = tail(sort(Sys.glob("data-raw/ifn/export_dataifn_2005_*.zip")), 1))
dem_f <- file.path(Sys.getenv("NEMETON_PROD_CACHE", unset = path.expand("~/.cache/nemeton")),
                   "ser", "dem_250m.tif")
n_train <- as.integer(Sys.getenv("FINN_N_TRAIN", "1000"))
n_test <- as.integer(Sys.getenv("FINN_N_TEST", "1000"))
epochs <- as.integer(Sys.getenv("FINN_EPOCHS", "300"))
lr <- as.numeric(Sys.getenv("FINN_LR", "0.01"))
env_mode <- Sys.getenv("FINN_ENV", "climat_sol")
eobs_dir <- Sys.getenv("NEMETON_EOBS_CACHE",
                       unset = path.expand("~/.local/share/nemeton/cache/eobs"))
patch_size <- pi * 15^2 / 1e4   # ha
bfc <- c("21", "25", "39", "58", "70", "71", "89", "90")

lire <- function(table, cols) {
  fread(cmd = sprintf("unzip -p '%s' %s.csv", zip, table), select = cols,
        colClasses = "character", encoding = "UTF-8")
}

# --- 1. Paires de visites -----------------------------------------------------
pla <- lire("PLACETTE", c("CAMPAGNE", "IDP", "VISITE", "DEP", "XL", "YL", "CSA"))
v2 <- pla[VISITE == "2" & DEP %in% bfc & as.integer(CAMPAGNE) >= 2015L,
          .(IDP, c2 = CAMPAGNE)]
v1 <- pla[VISITE == "1" & CSA == "1", .(IDP, c1 = CAMPAGNE, XL = as.numeric(XL),
                                        YL = as.numeric(YL))]
paires <- merge(v1, v2, by = "IDP")
paires <- paires[as.integer(c2) - as.integer(c1) == 5L]

arb <- lire("ARBRE", c("CAMPAGNE", "IDP", "A", "ESPAR", "VEGET", "VEGET5", "C13", "W"))
a1 <- arb[paires[, .(CAMPAGNE = c1, IDP)], on = .(CAMPAGNE, IDP), nomatch = NULL][
  VEGET == "0", .(IDP, A, ESPAR, d1 = as.numeric(C13) / pi * 100, W1 = as.numeric(W))]
a2 <- arb[paires[, .(CAMPAGNE = c2, IDP)], on = .(CAMPAGNE, IDP), nomatch = NULL][
  , .(IDP, A, ESPAR2 = ESPAR, VEGET5, d2 = as.numeric(C13) / pi * 100, W2 = as.numeric(W))]
rm(arb)
tr <- merge(a1, a2, by = c("IDP", "A"), all = TRUE)
tr[is.na(d1) & !is.na(d2), statut := "recrute"]
tr[!is.na(d1) & VEGET5 == "0", statut := "vivant"]
tr[!is.na(d1) & VEGET5 %in% c("M", "5", "C", "A", "1", "2", "T"), statut := "mort"]
tr[!is.na(d1) & VEGET5 %in% c("6", "7"), statut := "coupe"]
tr[!is.na(d1) & VEGET5 == "N", statut := "non_retrouve"]
# placettes exclues : arbre non retrouve, arbre de 1re visite sans suivi,
# vivant sans diametre a la revisite, aucun arbre vivant au depart
exclues <- tr[statut == "non_retrouve" | (!is.na(d1) & is.na(statut)) |
                (statut == "vivant" & !is.finite(d2)), unique(IDP)]
# accroissement aberrant (erreur de mesure ou d'appariement) : placette exclue
aberrantes <- tr[statut == "vivant" & !(d2 - d1 >= -5 & d2 - d1 <= 15), unique(IDP)]
exclues <- union(exclues, aberrantes)
tr <- tr[!IDP %in% exclues & statut %in% c("vivant", "mort", "coupe", "recrute")]
# un arbre suivi garde le poids de sa 1re visite
tr[statut != "recrute", W2 := W1]
# la revisite ne porte aucun W : un recrute recoit le poids theorique de son
# cercle (protocole IFN : 6 m si C13 < 70,5 cm, 9 m si < 117,5 cm, 15 m sinon)
tr[statut == "recrute", W2 := 1e4 / (pi * fifelse(d2 * pi < 70.5, 6, fifelse(d2 * pi < 117.5, 9, 15))^2)]
tr <- tr[statut != "recrute" | is.finite(d2)]
tr <- tr[IDP %in% tr[statut %in% c("vivant", "mort"), unique(IDP)]]
tr[statut == "recrute", `:=`(ESPAR = ESPAR2)]
cat(sprintf("%d placettes BFC revisitees (2015+), %d exclues, %d gardees\n",
            nrow(paires), length(exclues), uniqueN(tr$IDP)))

# --- 2. Essences ---------------------------------------------------------------
g1 <- tr[statut %in% c("vivant", "mort", "coupe"), .(G = sum(W1 * pi * (d1 / 200)^2)), by = ESPAR]
setorder(g1, -G)
gardees <- g1$ESPAR[seq_len(which(cumsum(g1$G) / sum(g1$G) >= 0.9)[1])]
lib <- fread("inst/extdata/ifn_espar_correspondance.csv", colClasses = "character")
tr[, espece := fifelse(ESPAR %in% gardees, ESPAR, "other")]
especes <- c(gardees, "other")
tr[, species := match(espece, especes)]
Nsp <- length(especes)
cat("Essences :", paste(sprintf("%s (%s)", especes,
                                lib$lib_espar[match(especes, lib$espar)]), collapse = ", "), "\n")

# --- 3. Tables FINN --------------------------------------------------------------
sites <- data.table(IDP = sort(unique(tr$IDP)))
sites[, siteID := .I]
tr <- tr[sites, on = "IDP"]
xy <- paires[sites, on = "IDP"]
alt <- terra::extract(rast(dem_f), vect(xy[, .(XL, YL)], geom = c("XL", "YL"), crs = "EPSG:2154"))[, 2]
sites[, alt := alt]
# climat E-OBS sur les 5 ans de l'intervalle (annees c1 .. c2 - 1)
xy <- paires[sites, on = "IDP"]
pts <- project(vect(xy[, .(XL, YL)], geom = c("XL", "YL"), crs = "EPSG:2154"), "EPSG:4326")
climat <- function(var) {
  r <- rast(file.path(eobs_dir, sprintf("eobs_%s_mensuel_france_v33.0e.tif", var)))
  v <- as.matrix(terra::extract(r, pts, ID = FALSE))
  an <- as.integer(substr(names(r), 1, 4)); mo <- as.integer(substr(names(r), 6, 7))
  c1 <- as.integer(xy$c1)
  vapply(seq_len(nrow(v)), function(i) {
    k <- an >= c1[i] & an < c1[i] + 5L
    if (var == "tx") mean(v[i, k & mo %in% 6:8]) else sum(v[i, k]) / 5
  }, numeric(1))
}
sites[, `:=`(tx_ete = climat("tx"), rr_an = climat("rr"))]
eco <- lire("ECOLOGIE", c("CAMPAGNE", "IDP", "PROF2"))
sites[eco[paires, on = .(IDP, CAMPAGNE = c1), .(IDP, prof = as.numeric(PROF2))], prof := i.prof, on = "IDP"]
vars_env <- if (env_mode == "alt") "alt" else c("tx_ete", "rr_an", "prof")
sites <- sites[complete.cases(sites[, ..vars_env])]
cat(sprintf("Environnement %s : %s\n", env_mode, paste(vars_env, collapse = ", ")))
print(round(cor(sites[, .(alt, tx_ete, rr_an, prof)], use = "complete.obs"), 2))
tr <- tr[siteID %in% sites$siteID]
sites[, new := .I]
tr[sites, siteID := i.new, on = "siteID"]
sites[, `:=`(siteID = new, new = NULL)]

# split train / test aleatoire : le test est tire en premier, il reste donc le
# meme quelle que soit la taille de la calibration (FINN_N_TRAIN = 0 : tout le
# reste)
ids <- sample(sites$siteID)
if (n_train == 0L) n_train <- length(ids) - n_test
stopifnot(length(ids) >= n_train + n_test)
id_test <- ids[seq_len(n_test)]
id_train <- ids[n_test + seq_len(n_train)]
cat(sprintf("Placettes : %d disponibles, %d calibration, %d test\n",
            length(ids), n_train, n_test))

recruits_dbh <- tr[statut == "recrute", mean(d2)]
ba_ha <- function(d, w) sum(w * pi * (d / 200)^2)

# etat initial : vivants au depart, coupes retires
init_all <- tr[statut %in% c("vivant", "mort"),
               .(siteID, patchID = 1L, year = 0L, species, dbh = d1,
                 trees = W1 * patch_size, treeName = paste(IDP, A), living = TRUE)]

# observations a 5 ans (annee 1), par site x essence, grille complete
obs_all <- tr[, .(
  ba = sum((W2 * pi * (d2 / 200)^2)[statut %in% c("vivant", "recrute")]) * patch_size,
  trees = sum(W2[statut %in% c("vivant", "recrute")]) * patch_size,
  dbh = { k <- statut %in% c("vivant", "recrute"); if (any(k)) weighted.mean(d2[k], W2[k]) else NA_real_ },
  growth = { k <- statut == "vivant"; if (any(k)) weighted.mean(d2[k] / d1[k] - 1, W1[k]) else NA_real_ },
  growth_n = sum(statut == "vivant"),
  n_at_risk = sum(statut %in% c("vivant", "mort")),
  n_died = sum(statut == "mort"),
  reg = sum(W2[statut == "recrute"])
), by = .(siteID, species)]
grille <- CJ(siteID = sites$siteID, species = seq_len(Nsp))
obs_all <- obs_all[grille, on = .(siteID, species)]
for (j in c("ba", "trees", "reg")) set(obs_all, which(is.na(obs_all[[j]])), j, 0)
for (j in c("growth_n", "n_at_risk", "n_died")) set(obs_all, which(is.na(obs_all[[j]])), j, 0L)
obs_all[, mort := fifelse(n_at_risk > 0, n_died / n_at_risk, NA_real_)]
obs_all[, `:=`(year = 1L, species_name = especes[species])]

env_all <- rbind(sites[, c("siteID", vars_env), with = FALSE][, year := 0L],
                 sites[, c("siteID", vars_env), with = FALSE][, year := 1L])

decouper <- function(ids) {
  # renumerote 1..n pour FINN
  map <- data.table(siteID = sort(ids))[, s := .I]
  f <- function(d) { d <- merge(d, map, by = "siteID"); d[, siteID := s][, s := NULL][] }
  list(obs = f(obs_all[siteID %in% ids]), env = f(env_all[siteID %in% ids]),
       init = makeInitCohorts(f(init_all[siteID %in% ids]), Nspecies = Nsp),
       ba0 = merge(init_all[siteID %in% ids, .(ba0 = sum(trees * pi * (dbh / 200)^2)),
                            by = siteID], map, by = "siteID")[, .(siteID = s, ba0)])
}
train <- decouper(id_train)
test <- decouper(id_test)

# --- 4. Calibration (mecaniste, vignette D de FINN) ------------------------------
f_env <- reformulate(vars_env)
m <- finn(
  N_species = Nsp,
  recruits_dbh = recruits_dbh,
  competition_process = createProcess(~0, FINN::competition, optimizeSpecies = TRUE),
  growth_process = createProcess(f_env, FINN::growth, optimizeSpecies = TRUE, optimizeEnv = TRUE),
  regeneration_process = createProcess(f_env, FINN::regeneration, optimizeSpecies = TRUE, optimizeEnv = TRUE),
  mortality_process = createProcess(f_env, FINN::mortality, optimizeSpecies = TRUE, optimizeEnv = TRUE)
)
t0 <- Sys.time()
if (epochs > 0L) fit(m, env = train$env, data = train$obs[, .(siteID, year, species, ba, dbh, trees, growth,
                                             growth_n, mort, n_at_risk, n_died, reg)],
    init_cohort = train$init, device = "cpu", epochs = epochs, batchsize = 50L,
    patches = 1L, patch_size = patch_size, lr = lr, plot_progress = FALSE)
duree <- Sys.time() - t0

# --- 5. Evaluation : surface terriere totale a 5 ans (m2/ha) ----------------------
# Trois modeles nuls, ajustes sur les placettes de calibration seulement :
#   persistance            G5 = G0 ;
#   persistance + accr.    G5 = G0 + accroissement moyen observe en calibration ;
#   regression lineaire    G5 ~ G0 + variables d'environnement.
# FINN_EPOCHS = 0 : pas d'ajustement FINN, modeles nuls seuls.
tableau <- function(d) {
  obs <- d$obs[, .(obs = sum(ba) / patch_size), by = siteID]
  x <- merge(obs, d$ba0[, .(siteID, persist = ba0 / patch_size)], by = "siteID")
  merge(x, d$env[year == 1L, c("siteID", vars_env), with = FALSE], by = "siteID")
}
x_train <- tableau(train)
accr <- x_train[, mean(obs - persist)]
reg <- stats::lm(reformulate(c("persist", vars_env), "obs"), data = x_train)

evaluer <- function(d, label) {
  x <- tableau(d)
  x[, `:=`(accr = persist + accr, lin = stats::predict(reg, newdata = x))]
  if (epochs > 0L) {
    m$eval()
    sim <- predict(m, env = d$env, init_cohort = d$init, patches = 1L,
                   patch_size = patch_size, device = "cpu")
    pred <- sim$long$site[variable == "ba" & year == 1L,
                          .(finn = sum(value) / patch_size), by = siteID]
    x <- merge(x, pred, by = "siteID")
  }
  r <- function(p) c(rmse = sqrt(mean((x$obs - p)^2)), biais = mean(p - x$obs),
                     r2 = 1 - sum((x$obs - p)^2) / sum((x$obs - mean(x$obs))^2))
  modeles <- c(FINN = "finn", persistance = "persist", `persistance + accr.` = "accr",
               `regression lineaire` = "lin")
  modeles <- modeles[modeles %in% names(x)]
  rbindlist(lapply(names(modeles), function(k)
    data.table(echantillon = label, modele = k, t(r(x[[modeles[[k]]]])))))[, n := nrow(x)][]
}
cat(sprintf("Accroissement moyen observe en calibration : %.2f m2/ha en 5 ans\n", accr))
res <- rbind(evaluer(train, "calibration"), evaluer(test, "tenu a l'ecart"))
cat(sprintf("\nCalibration : %d placettes, %d epoques, lr %g, %s ; G moyenne a 5 ans %.1f m2/ha\n",
            n_train, epochs, lr, format(round(duree, 1)), train$obs[, sum(ba)] / patch_size / n_train))
print(res[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
