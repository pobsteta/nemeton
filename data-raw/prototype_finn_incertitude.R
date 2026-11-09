# data-raw/prototype_finn_incertitude.R
#
# Incertitude des predictions FINN (spec 068, etape 3, avant
# simuler_itineraire()). Les quantiles des tirages d'un seul modele ne
# contiennent que 19 % des G observees a 5 ans sur BFC : ils ne portent que la
# stochasticite demographique. Trois sources d'incertitude comparees, sur les
# memes 1000 placettes tenues a l'ecart que prototype_finn_calibration.R :
#   graine     : K calibrations sur les memes placettes, graines differentes
#                (variance de l'optimisation) ;
#   bootstrap  : K calibrations sur des tirages avec remise des placettes de
#                calibration (variance d'echantillonnage des parametres) ;
#   conforme   : un seul modele, intervalle elargi par les quantiles des
#                residus absolus sur 1000 AUTRES placettes, ni calibration ni
#                test (conformal split, Lei et al. 2018) : couverture garantie
#                en moyenne si les placettes sont echangeables.
# Pour graine et bootstrap, l'intervalle 90 % est pris sur les tirages de tous
# les modeles mis ensemble (10 tirages par modele).
#
# Etapes (variables d'environnement) :
#   FINN_INC_ETAPE=donnees   construit la table d'arbres et d'environnement
#                            depuis prototype_finn_calibration.R (FINN_EPOCHS=0,
#                            FINN_PATCH_MULT=10) et l'ecrit dans FINN_INC_DONNEES ;
#   FINN_INC_ETAPE=ajuster   FINN_INC_TYPE=graine|bootstrap, FINN_INC_K=k :
#                            une calibration, ecrite dans FINN_INC_DOSSIER ;
#   FINN_INC_ETAPE=evaluer   lit tous les modeles du dossier et compare.
# Les modeles sont des fichiers torch (.pt), hors du depot.

suppressMessages({
  library(data.table)
  pkgload::load_all(".", quiet = TRUE)
})
etape <- Sys.getenv("FINN_INC_ETAPE", "evaluer")
f_donnees <- Sys.getenv("FINN_INC_DONNEES")
dossier <- Sys.getenv("FINN_INC_DOSSIER")
stopifnot(nzchar(f_donnees), nzchar(dossier))
dir.create(dossier, showWarnings = FALSE, recursive = TRUE)

if (etape == "donnees") {
  Sys.setenv(FINN_EPOCHS = "0", FINN_PATCH_MULT = "10")
  source("data-raw/prototype_finn_calibration.R")
  arbres <- tr[, .(placette = IDP, essence = ESPAR, d1, d2, poids = W2, statut)]
  env <- sites[, c("IDP", vars_env), with = FALSE]
  setnames(env, "IDP", "placette")
  pla_test <- sites[siteID %in% id_test, IDP]
  pla_train <- sites[siteID %in% id_train, IDP]
  set.seed(7)
  reste <- setdiff(sites$IDP, c(pla_test, pla_train))
  pla_conforme <- sample(reste, 1000L)
  saveRDS(list(arbres = arbres, env = env, test = pla_test, train = pla_train,
               conforme = pla_conforme), f_donnees)
  quit(save = "no")
}

d <- readRDS(f_donnees)
sous <- function(p) list(a = d$arbres[placette %in% p], e = d$env[placette %in% p])

if (etape == "ajuster") {
  type <- Sys.getenv("FINN_INC_TYPE")
  k <- as.integer(Sys.getenv("FINN_INC_K"))
  graine <- 42L + k
  if (type == "graine") {
    x <- sous(d$train)
  } else if (type == "bootstrap") {
    # tirage avec remise ; une placette tiree deux fois devient deux sites
    set.seed(1000L + k)
    tir <- sample(d$train, replace = TRUE)
    x <- list(a = rbindlist(lapply(seq_along(tir), function(i)
      d$arbres[placette == tir[i]][, placette := paste0(tir[i], "_", i)])),
      e = rbindlist(lapply(seq_along(tir), function(i)
        d$env[placette == tir[i]][, placette := paste0(tir[i], "_", i)])))
  } else stop("FINN_INC_TYPE : graine ou bootstrap")
  t0 <- Sys.time()
  cal <- calibrer_finn(x$a, x$e, graine = graine)
  cal_f <- file.path(dossier, sprintf("%s_%d", type, k))
  torch::torch_save(cal$modele$clone(deep = FALSE), paste0(cal_f, ".pt"))
  cal$modele <- NULL
  saveRDS(cal, paste0(cal_f, ".rds"))
  cat(sprintf("%s %d : %s\n", type, k, format(round(Sys.time() - t0, 1))))
  quit(save = "no")
}

# --- evaluation ---------------------------------------------------------------
charger <- function(f) {
  cal <- readRDS(f)
  cal$modele <- torch::torch_load(sub("\\.rds$", ".pt", f))
  cal
}
g_obs <- function(a) a[, .(obs = sum((poids * pi * (d2 / 200)^2)[statut %in% c("vivant", "recrute")])),
                       by = placette]
# tirages bruts d'un modele : matrice placette x tirage
tirages <- function(cal, p, n = 10L) {
  x <- sous(p)
  vapply(seq_len(n), function(i) {
    r <- predire_finn(cal, x$a, x$e, n_tirages = 1L)
    r$g_predite[match(p, r$placette)]
  }, numeric(length(p)))
}
resume <- function(label, pred, lo, hi, obs) {
  data.table(source = label, rmse = sqrt(mean((pred - obs)^2)), biais = mean(pred - obs),
             couverture_90 = mean(obs >= lo & obs <= hi), largeur = mean(hi - lo))
}

obs_test <- g_obs(d$arbres[placette %in% d$test])[match(d$test, placette), obs]
fichiers <- sort(Sys.glob(file.path(dossier, "*.rds")))
res <- list()
for (type in c("graine", "bootstrap")) {
  fs <- grep(paste0("/", type, "_"), fichiers, value = TRUE)
  if (!length(fs)) next
  tt <- do.call(cbind, lapply(fs, function(f) tirages(charger(f), d$test)))
  moy_par_modele <- sapply(seq_along(fs), function(j) rowMeans(tt[, (j - 1) * 10 + 1:10]))
  for (j in seq_along(fs)) {
    res[[length(res) + 1]] <- resume(sprintf("%s, modele %d seul", type, j), moy_par_modele[, j],
                                     apply(tt[, (j - 1) * 10 + 1:10], 1, quantile, 0.05),
                                     apply(tt[, (j - 1) * 10 + 1:10], 1, quantile, 0.95), obs_test)
  }
  res[[length(res) + 1]] <- resume(sprintf("%s, ensemble de %d", type, length(fs)), rowMeans(tt),
                                   apply(tt, 1, quantile, 0.05), apply(tt, 1, quantile, 0.95), obs_test)
  # dispersion entre modeles : ecart-type des moyennes par placette
  cat(sprintf("%s : ecart-type entre modeles de G predite, mediane %.2f m2/ha\n", type,
              median(apply(moy_par_modele, 1, sd))))
}

# conforme : premier modele graine, residus sur les placettes « conforme »
f1 <- grep("/graine_", fichiers, value = TRUE)[1]
if (!is.na(f1)) {
  cal <- charger(f1)
  pc <- tirages(cal, d$conforme)
  obs_c <- g_obs(d$arbres[placette %in% d$conforme])[match(d$conforme, placette), obs]
  q <- quantile(abs(rowMeans(pc) - obs_c), 0.9 * (1 + 1 / length(obs_c)))
  pt <- rowMeans(tirages(cal, d$test))
  res[[length(res) + 1]] <- resume("conforme (modele graine 1)", pt, pt - q, pt + q, obs_test)
  cat(sprintf("conforme : demi-largeur %.2f m2/ha\n", q))
}
out <- rbindlist(res)
print(out[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
