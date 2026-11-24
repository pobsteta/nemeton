# Tables et rapport (sourcé par etude.R : px, zones, dossier, ANNEES_*, fonctions).
METH <- list(decoloration = c("niv_dec", "sc_dec"), fast_count = c("cl_count", "sc_count"),
             fast_rolling = c("cl_rolling", "sc_rolling"), fast_trend = c("cl_trend", "sc_trend"))
COHORTES <- list("2021" = 2021L, "2022" = 2022L, "2023" = 2023L, "2021-2022" = 2021:2022)
test <- px[px$annee %in% ANNEES_TEST & px$comparable, ]       # cas 0 : pixels comparables seulement
groupes <- c("tous", unique(zones$groupe))
sous_groupe <- function(d, g) if (g == "tous") d else d[d$groupe == g, ]

# 1. risque de coupe par classe : Kaplan-Meier en pixels et pondéré par le volume FORMS-T a-1, lift
risque <- do.call(rbind, lapply(names(METH), function(m) do.call(rbind, lapply(groupes, function(g)
  do.call(rbind, lapply(names(COHORTES), function(co) {
    d <- sous_groupe(test[test$annee %in% COHORTES[[co]], ], g); d$cl <- d[[METH[[m]][1]]]
    d <- d[!d$cl %in% c("manquant", "non_applicable") & !is.na(d$cl), ]
    if (!nrow(d)) return(NULL)
    do.call(rbind, lapply(sort(unique(d$cl)), function(k) { e <- d[d$cl == k, ]
      ev <- function(w) setNames(km_risque(e$delai, e$evenement, w), paste0("risque_", HORIZONS))
      data.frame(methode = m, groupe = g, cohorte = co, classe = k, n_pixels = nrow(e),
                 t(ev(rep(1, nrow(e)))), t(setNames(ev(ifelse(is.na(e$vol), 0, e$vol)), paste0("vol_", names(ev(1)))))) }))
  }))))))
if (!is.null(risque)) {
  cle <- paste(risque$methode, risque$groupe, risque$cohorte)
  ref <- risque[risque$classe == "0", ]
  risque$lift_24 <- risque$risque_24 / ref$risque_24[match(cle, paste(ref$methode, ref$groupe, ref$cohorte))]
  utils::write.csv(risque, file.path(dossier, "risque_par_classe.csv"), row.names = FALSE)
}

# 2. détection, contre « coupé sous 24 mois » (2021-2022, non censurées) : AUC, précision/rappel
#    à surface égale (k = part alertée par la décoloration), intervalles par tirage PAR ZONE
base <- test[test$annee %in% 2021:2022 & !is.na(test$y24), ]
app <- base[base$niv_dec != "non_applicable" & base$niv_dec != "manquant", ]
k_dec <- if (nrow(app)) mean(as.numeric(app$niv_dec) >= 2) else NA_real_
detection <- do.call(rbind, lapply(names(METH), function(m) do.call(rbind, lapply(groupes, function(g) {
  d <- sous_groupe(if (m == "decoloration" || g != "melange") app else base, g)
  if (m != "decoloration" && g == "melange") d <- sous_groupe(base, g)
  d$sc <- d[[METH[[m]][2]]]; d <- d[!is.na(d$sc), ]
  if (nrow(d) < 10 || !any(d$y24) || all(d$y24)) return(NULL)
  st <- function(x) { pr <- precision_rappel(x$sc, x$y24, k_dec)
    c(auc = auc_rang(x$sc, x$y24), precision = pr[["precision"]], rappel = pr[["rappel"]]) }
  ic <- ic_par_zone(d[, c("zone", "sc", "y24")], st, B = 100L)   # tirage par zone
  data.frame(methode = m, groupe = g, n_pixels = nrow(d), n_zones = length(unique(d$zone)),
             prevalence_24 = mean(d$y24), k_surface = k_dec, ic)
}))))
if (!is.null(detection)) utils::write.csv(detection, file.path(dossier, "detection_24m.csv"), row.names = FALSE)

# 3. accord FAST (count) x décoloration, en surfaces, et coupes vues par l'une, l'autre, les deux
acc <- app[!is.na(app$cl_count), ]
if (nrow(acc)) {
  utils::write.csv(croisement_classes(acc$cl_count, acc$niv_dec), file.path(dossier, "accord_classes.csv"), row.names = FALSE)
  # alerte FAST à surface égale : les k % pixels de plus haut score (la classe >= 1 couvre ~90 % des pixels)
  alerte_fast <- seq_len(nrow(acc)) %in% order(-acc$sc_count, seq_len(nrow(acc)))[seq_len(ceiling(k_dec * nrow(acc)))]
  vues <- part_coupes_vues(alerte_fast, as.numeric(acc$niv_dec) >= 2, acc$y24 %in% TRUE)
  utils::write.csv(vues, file.path(dossier, "coupes_vues_24m.csv"), row.names = FALSE)
}

# 4. FAST seul 2018-2020, à part : ses alertes précèdent-elles les coupes ?
seul <- px[px$annee %in% ANNEES_FAST_SEUL & !is.na(px$cl_count), ]
fast_seul <- if (nrow(seul)) do.call(rbind, lapply(split(seul, list(seul$annee, seul$cl_count), drop = TRUE), function(e)
  data.frame(annee = e$annee[1], classe = e$cl_count[1], n_pixels = nrow(e), t(setNames(km_risque(e$delai, e$evenement), paste0("risque_", HORIZONS)))))) else NULL
if (!is.null(fast_seul)) utils::write.csv(fast_seul, file.path(dossier, "fast_seul_2018_2020.csv"), row.names = FALSE)

# 5. rapport
dur <- utils::read.csv(file.path(dossier, "durees.csv"))
kb <- function(x, ...) if (is.null(x) || !nrow(x)) "_(vide : voir limites)_" else knitr::kable(x, format = "pipe", digits = 3, row.names = FALSE, ...)
writeLines(c("# Étude FAST contre décoloration — rapport généré", "",
  sprintf("Zones : %s. Graine : 45. Cohortes : 2021 et 2022 complètes à 24 mois, 2023 censurée.", paste(zones$zone, collapse = ", ")), "",
  "## Horizon", "",
  "Horizon principal **24 mois** ; 12 et 36 mois en sensibilité ; 46 mois pour la seule cohorte 2021, à titre d'information.",
  "Justification (sorties régionales `risque_delais_coupe.csv`, cohorte 2021, sans biais) : l'excès de coupe des niveaux 2-4",
  "sur le niveau 0 vaut 1,65 / 1,98 / 1,96 / 1,90 points à 12 / 24 / 36 / 46 mois, il plafonne donc à 24 mois, tandis que le lift",
  "baisse (6,3 / 4,1 / 3,3 / 2,6) : au-delà de 24 mois on n'ajoute que des coupes ordinaires. L'AUC et la précision à surface",
  "égale sont calculées contre « coupé sous 24 mois ».", "",
  "## Risque de coupe par classe (Kaplan-Meier ; pixels et volume FORMS-T a-1)", "", kb(risque), "",
  sprintf("## Détection à 24 mois (surface alertée k = %.1f %%, part du niveau >= 2 de la décoloration ; IC 95 %% par tirage par zone)", 100 * k_dec), "", kb(detection), "",
  "## Accord FAST (count) x décoloration (surfaces)", "", kb(if (nrow(acc)) croisement_classes(acc$cl_count, acc$niv_dec) else NULL), "",
  "## Coupes à 24 mois vues par FAST seul, décoloration seule, les deux, aucune", "", kb(if (nrow(acc)) vues else NULL), "",
  "## FAST seul, 2018-2020 (à part, sans comparaison)", "", kb(fast_seul), "",
  "## Durées par étape (secondes)", "", kb(dur), "",
  "## Limites de la vérité (brief § 4)", "",
  "Coupe de régénération comptée « atteint » ; dépérissement sans coupe rase invisible (hêtre, chêne, forêt privée, scolytés extraits) ;",
  "résultat plus sûr pour sapin/épicéa que chêne/hêtre ; prévalence faible : on lit lift, AUC et précision à surface égale, pas le kappa.",
  "Cas 0 : les pixels coupés trop tôt pour avoir 4 années de référence ne sont pas comparés (dans les deux méthodes).",
  "Les zones « melange » : décoloration `non_applicable`, FAST seul. Niveaux 3 et 4 reconstruits depuis `classe` et `icd_min`."),
  file.path(dossier, "rapport.md"))
msg("rapport : %s", file.path(dossier, "rapport.md"))
