# Spec 065 : catalogue, admissibilite, comparaison. Le catalogue de test est
# FICTIF (references « Test ») : il ne sert qu'a exercer le moteur.

.it_test <- function(code, fam = "futaie_reguliere", domaine = list(),
                     effets = list(), statut = "source") {
  list(
    code = code, famille_itineraire = fam,
    libelle = list(fr = code, en = code),
    domaine = local({
      d <- list(essences_objectif = list(), ser = list(), protections_exclues = list())
      # affectation champ par champ : modifyList() ignore les listes non nommees
      for (n in names(domaine)) d[[n]] <- domaine[[n]]
      d
    }),
    regles = list(rotation_ans = NULL),
    effets_attendus = effets,
    sources = if (statut == "source") list(list(ref = paste("Test", code), pages = "p. 1")) else list(),
    statut_source = statut
  )
}
.e <- function(sens) list(sens = sens, horizon = "long", source = "Test")

.catalogue_test <- function() {
  l <- list(
    .it_test("production", effets = list(P = .e("+"), E = .e("+"), B = .e("-"), N = .e("-"))),
    .it_test("conservation", fam = "libre_evolution",
             effets = list(P = .e("-"), E = .e("-"), B = .e("+"), N = .e("+"))),
    .it_test("mixte", fam = "futaie_irreguliere",
             effets = list(P = .e("0"), E = .e("0"), B = .e("+"), N = .e("0")))
  )
  names(l) <- vapply(l, `[[`, "", "code")
  l
}

.unites <- function(n = 1, ...) {
  sf::st_sf(id = seq_len(n), ...,
            geometry = sf::st_sfc(lapply(seq_len(n), function(i)
              sf::st_polygon(list(rbind(c(0, 0), c(100, 0), c(100, 100), c(0, 100), c(0, 0)) +
                                    (i - 1) * 200))), crs = 2154))
}

test_that("the shipped catalogue is valid; only its sourced entries can be admitted", {
  cat <- itineraires_catalogue()
  expect_gte(length(cat), 10L)
  expect_true(valider_catalogue_itineraires(cat))
  statut <- vapply(cat, `[[`, "", "statut_source")
  # entrees sourcees : futaie irreguliere de hetre (ONF 2013) ; futaie
  # reguliere et irreguliere de chene, conversion du TSF (Sardin 2008) ;
  # futaies regulieres resineuses (SFFC 2012) ; futaie reguliere de hetre
  # (ONF 2018, hors BFC) ; libre evolution et ilot de senescence, sans
  # coupe (ONF 2011, RTG 2021), D-9 a D-11
  sans_coupe <- c("bfc_libre_evolution", "bfc_ilot_senescence")
  resineux <- c("bfc_epicea_futaie_reguliere", "bfc_sapin_futaie_reguliere",
                "bfc_douglas_futaie_reguliere")
  sources <- c("bfc_hetre_futaie_irreguliere", "bfc_chene_sessile_futaie_reguliere",
               "bfc_chene_futaie_irreguliere", "bfc_conversion_tsf_futaie", resineux,
               "bfc_hetre_futaie_reguliere", sans_coupe)
  expect_setequal(names(statut)[statut == "source"], sources)
  expect_equal(unlist(cat$bfc_chene_futaie_irreguliere$domaine$essences_objectif), c("03", "02"))
  expect_equal(cat$bfc_chene_futaie_irreguliere$regles$surface_terriere_cible_m2ha, 15)
  expect_equal(cat$bfc_conversion_tsf_futaie$famille_itineraire, "conversion")
  expect_true(all(vapply(cat[sources], function(it) nzchar(it$notes %||% ""), TRUE)))
  ch <- cat$bfc_chene_sessile_futaie_reguliere
  expect_equal(unlist(ch$domaine$essences_objectif), "03")
  expect_equal(ch$regles$diametre_exploitabilite_cm, 75)
  expect_length(unlist(ch$regles$norme_g_selon_dg$dg_cm), 12L)
  # resineux : une essence chacun, Dexp 55 cm, norme du douglas a 205/275 de
  # celle de l'epicea, que le sapin reprend telle quelle
  expect_equal(unname(vapply(cat[resineux], function(it) unlist(it$domaine$essences_objectif), "")),
               c("62", "61", "64"))
  expect_true(all(vapply(cat[resineux], function(it) it$regles$diametre_exploitabilite_cm, 1) == 55))
  g_ep <- unlist(cat$bfc_epicea_futaie_reguliere$regles$norme_g_selon_dg$g_m2ha)
  expect_equal(unlist(cat$bfc_sapin_futaie_reguliere$regles$norme_g_selon_dg$g_m2ha), g_ep)
  expect_equal(unlist(cat$bfc_douglas_futaie_reguliere$regles$norme_g_selon_dg$g_m2ha),
               g_ep * 205 / 275, tolerance = 0.01)
  hr <- cat$bfc_hetre_futaie_reguliere
  expect_equal(unlist(hr$domaine$essences_objectif), "09")
  expect_equal(hr$regles$diametre_exploitabilite_cm, 55)
  expect_equal(range(unlist(hr$regles$norme_g_selon_dg$g_m2ha)), c(16.8, 18.4))
  fi <- cat$bfc_hetre_futaie_irreguliere
  expect_equal(fi$famille_itineraire, "futaie_irreguliere")
  expect_equal(unlist(fi$domaine$essences_objectif), "09")
  expect_equal(fi$regles$rotation_ans, 10)
  expect_equal(fi$regles$diametre_exploitabilite_cm, 60)
  expect_equal(fi$regles$surface_terriere_cible_m2ha, 16.5)
  expect_equal(fi$regles$intensite_prelevement_pct, 25)
  expect_true(all(nzchar(vapply(fi$sources, `[[`, "", "pages"))))
  # les entrees a sourcer ne sont jamais admissibles ; le hetre l'est sur
  # une UGF a hetre, pas sur une chenaie, et l'essence manquante le dit
  u <- .unites(3, essence = c("09", "03", NA))
  a <- itineraires_admissibles(u, cat)
  autres <- a[!a$itineraire %in% sources, ]
  expect_true(all(autres$raison == "source_manquante"))
  expect_true(all(!autres$admissible))
  hetres <- c("bfc_hetre_futaie_irreguliere", "bfc_hetre_futaie_reguliere")
  for (code in hetres) {
    h <- a[a$itineraire == code, ]
    expect_equal(h$admissible, c(TRUE, FALSE, NA), label = code)
    expect_equal(h$raison, c(NA, "essence_absente", "donnee_manquante"), label = code)
  }
  for (code in sans_coupe) {
    expect_true(isTRUE(cat[[code]]$regles$aucune_coupe), label = code)
    expect_equal(a$admissible[a$itineraire == code], c(TRUE, TRUE, TRUE), label = code)
  }
  for (code in setdiff(sources, c(hetres, resineux, sans_coupe))) {
    expect_equal(a$admissible[a$itineraire == code], c(FALSE, TRUE, NA), label = code)
  }
  for (code in resineux) {
    expect_equal(a$admissible[a$itineraire == code], c(FALSE, FALSE, NA), label = code)
  }
  ep <- itineraires_admissibles(.unites(1, essence = "62"), cat)
  expect_setequal(ep$itineraire[ep$admissible %in% TRUE],
                  c("bfc_epicea_futaie_reguliere", sans_coupe))
})

test_that("the validator enforces the sourcing rule and the schema", {
  sans_ref <- .it_test("x"); sans_ref$sources <- list()
  expect_error(valider_catalogue_itineraires(list(sans_ref)), "cites no reference")
  sans_src <- .it_test("y", effets = list(P = list(sens = "+", horizon = "long", source = "")))
  expect_error(valider_catalogue_itineraires(list(sans_src)), "without a source")
  mauvais <- .it_test("z", effets = list(P = .e("++")))
  expect_error(valider_catalogue_itineraires(list(mauvais)), "sens must be")
  fam <- .it_test("w", fam = "jardinage_magique")
  expect_error(valider_catalogue_itineraires(list(fam)), "unknown famille_itineraire")
  expect_error(valider_catalogue_itineraires(list(.it_test("d"), .it_test("d"))), "Duplicated")
  incomplet <- .it_test("v"); incomplet$regles <- NULL
  expect_error(valider_catalogue_itineraires(list(incomplet)), "missing field")
  # un effet « ? » peut rester sans source
  expect_true(valider_catalogue_itineraires(list(.it_test("u", effets = list(P = list(sens = "?"))))))
})

test_that("every exclusion code is produced, and missing data is never silent", {
  cat <- list(
    a_sourcer = .it_test("a_sourcer", statut = "a_sourcer"),
    protege = .it_test("protege", domaine = list(protections_exclues = list("rb"))),
    ser = .it_test("ser", domaine = list(ser = list("C30"))),
    essence = .it_test("essence", domaine = list(essences_objectif = list("09"))),
    station = .it_test("station", domaine = list(p2_min = 6)),
    pente = .it_test("pente", domaine = list(pente_max_pct = 30)),
    desserte = .it_test("desserte", domaine = list(desserte_requise = TRUE, desserte_max_m = 500)),
    libre = .it_test("libre")
  )
  u <- .unites(2, P2 = c(4, NA), ser = c("B10", "C30"), essence = c("03", "09"),
               pente_pct = c(45, 10), desserte_m = c(900, NA))
  aires <- sf::st_sf(type = "RB", geometry = sf::st_sfc(sf::st_polygon(list(
    rbind(c(-10, -10), c(110, -10), c(110, 110), c(-10, 110), c(-10, -10)))), crs = 2154))
  a <- itineraires_admissibles(u, cat, protected_areas = aires)
  r1 <- stats::setNames(a$raison[a$unit_id == "1"], a$itineraire[a$unit_id == "1"])
  expect_equal(unname(r1[c("a_sourcer", "protege", "ser", "essence", "station",
                           "pente", "desserte")]),
               c("source_manquante", "statut_protection", "hors_ser", "essence_absente",
                 "station_insuffisante", "pente", "desserte"))
  expect_true(is.na(r1[["libre"]]))
  expect_true(a$admissible[a$unit_id == "1" & a$itineraire == "libre"])
  expect_match(a$detail[a$unit_id == "1" & a$itineraire == "pente"], "45")
  # UGF 2 : P2 et desserte manquants -> donnee_manquante, admissible NA
  r2 <- a[a$unit_id == "2", ]
  expect_equal(r2$raison[r2$itineraire == "station"], "donnee_manquante")
  expect_equal(r2$raison[r2$itineraire == "desserte"], "donnee_manquante")
  expect_true(is.na(r2$admissible[r2$itineraire == "station"]))
  expect_true(r2$admissible[r2$itineraire == "essence"])
  # exclusion de protection sans couche d'aires protegees : donnee_manquante
  b <- itineraires_admissibles(u, cat["protege"])
  expect_true(all(b$raison == "donnee_manquante"))
})

test_that("the ranking follows the profile: production vs naturalist (massif_demo_units)", {
  data("massif_demo_units", package = "nemeton")
  u <- massif_demo_units[1:3, ]
  cat <- .catalogue_test()
  prod <- comparer_itineraires(u, c(P = 3, E = 3, B = 1, N = 1), cat)
  natu <- comparer_itineraires(u, "profil_naturaliste", cat)
  meilleur <- function(x) x$itineraire[x$unit_id == x$unit_id[1] & x$rang == 1]
  expect_equal(meilleur(prod), "production")
  expect_equal(meilleur(natu), "conservation")
  expect_true(all(nzchar(prod$citations)))
  expect_match(prod$citations[1], "^Test ")
  expect_true(all(prod$methode == "catalogue_qualitatif"))
  expect_true(all(prod$incertitude == "qualitative"))
  expect_true(all(prod$score_global >= -1 & prod$score_global <= 1))
  # le profil naturaliste pese les 12 familles ; seules P, E, B, N sont
  # renseignees par le catalogue : les autres sont mises de cote, dites
  expect_equal(natu$familles_evaluees[1], "B, E, N, P")
  # reference par defaut = meilleur score ; gagnants / perdants face a elle
  l <- natu[natu$unit_id == natu$unit_id[1] & natu$itineraire == "production", ]
  expect_equal(l$reference, "conservation")
  expect_match(l$familles_gagnantes, "P")
  expect_match(l$familles_perdantes, "B")
})

test_that("the declared current itinerary is the reference when it is a candidate", {
  u <- .unites(1, itineraire_actuel = "mixte")
  res <- comparer_itineraires(u, c(P = 1, B = 1), .catalogue_test())
  expect_true(all(res$reference == "mixte"))
  expect_equal(res$familles_gagnantes[res$itineraire == "mixte"], "")
})

test_that("an unknown effect on a weighted family gives an NA score, not a guess", {
  cat <- .catalogue_test()
  cat$production$effets_attendus$W <- .e("+")
  cat$conservation$effets_attendus$W <- .e("0")
  cat$mixte$effets_attendus$W <- list(sens = "?")
  res <- comparer_itineraires(.unites(1), c(P = 1, W = 1), cat)
  expect_true(is.na(res$score_global[res$itineraire == "mixte"]))
  expect_true(is.na(res$pareto[res$itineraire == "mixte"]))
  expect_false(anyNA(res$score_global[res$itineraire != "mixte"]))
  # une famille que personne ne connait (seulement « ? ») est mise de cote
  cat2 <- .catalogue_test()
  cat2$mixte$effets_attendus$W <- list(sens = "?")
  res2 <- comparer_itineraires(.unites(1), c(P = 1, W = 1), cat2)
  expect_false(anyNA(res2$score_global))
  expect_equal(res2$familles_evaluees[1], "P")
})

# Trajectoires FICTIVES a la forme de simuler_itineraire(unites =) : P lu sur
# le volume preleve cumule, C sur le carbone a l'horizon (spec 068).
.traj <- function(itin, prel, carb, unites = c("1", "2"), annees = c(0, 5, 10),
                  dl = 2) {
  do.call(rbind, lapply(unites, function(u) {
    n <- length(annees)
    rbind(
      data.frame(unite = u, n_placettes = 4L, itineraire = itin, annee = annees,
                 variable = "g", moyenne = 20 + annees,
                 bas = ifelse(annees > 0, 20 + annees - dl, NA),
                 haut = ifelse(annees > 0, 20 + annees + dl, NA)),
      data.frame(unite = u, n_placettes = 4L, itineraire = itin, annee = annees,
                 variable = "volume_preleve", moyenne = c(0, rep(prel, n - 1)),
                 bas = NA, haut = NA),
      data.frame(unite = u, n_placettes = 4L, itineraire = itin, annee = annees,
                 variable = "carbone", moyenne = carb * annees / max(annees) + 50,
                 bas = NA, haut = NA)
    )
  }))
}
.traj_test <- function() {
  rbind(.traj("production", prel = 40, carb = 10),
        .traj("conservation", prel = 0, carb = 60),
        .traj("sans_gestion", prel = 0, carb = 59, dl = 3))
}

test_that("trajectoires: FINN values rank the itineraries, method and interval say so", {
  u <- .unites(2)
  tr <- .traj_test()
  prod <- comparer_itineraires(u, c(P = 3, C = 1, B = 2), .catalogue_test(), trajectoires = tr)
  carb <- comparer_itineraires(u, c(P = 1, C = 3), .catalogue_test(), trajectoires = tr)
  # « mixte » est admissible mais pas simule : il n'est pas candidat ;
  # « sans_gestion » n'est pas au catalogue mais l'est
  expect_setequal(prod$itineraire[prod$unit_id == "1"],
                  c("production", "conservation", "sans_gestion"))
  expect_true(all(prod$methode == "finn"))
  expect_type(prod$incertitude, "double")
  expect_equal(prod$incertitude[prod$itineraire == "sans_gestion"], c(3, 3))
  expect_equal(prod$incertitude[prod$itineraire == "production"], c(2, 2))
  # B est ponderee mais non simulee : mise de cote, dite
  expect_true(all(prod$familles_evaluees == "C, P"))
  meilleur <- function(x) x$itineraire[x$unit_id == "1" & x$rang == 1]
  expect_equal(meilleur(prod), "production")
  expect_equal(meilleur(carb), "conservation")
  expect_true(all(prod$score_global >= -1 & prod$score_global <= 1))
  expect_equal(prod$citations[prod$itineraire == "sans_gestion"], c("", ""))
  expect_match(prod$citations[prod$itineraire == "production"][1], "^Test ")
  # valeurs derriere la note : P cumule jusqu'a l'horizon, C a l'horizon
  v <- attr(prod, "valeurs")
  expect_setequal(names(v), c("unit_id", "itineraire", "famille", "variable", "valeur",
                              "unite_mesure", "horizon"))
  vp <- v[v$unit_id == "1" & v$itineraire == "production", ]
  expect_equal(vp$valeur[vp$famille == "P"], 80)
  expect_equal(vp$valeur[vp$famille == "C"], 60)
  expect_equal(vp$unite_mesure[vp$famille == "C"], "tC/ha")
  expect_true(all(v$horizon == 10))
})

test_that("trajectoires: the tolerance keeps stochastic noise out of wins and losses", {
  u <- .unites(1, itineraire_actuel = "sans_gestion")
  tr <- .traj_test()
  tr <- tr[tr$unite == "1", ]
  r <- comparer_itineraires(u, c(P = 1, C = 1), .catalogue_test(), trajectoires = tr)
  expect_true(all(r$reference == "sans_gestion"))
  cons <- r[r$itineraire == "conservation", ]
  # 110 contre 109 tC/ha : moins de 5 %, ni gagne ni perdu
  expect_equal(cons$familles_gagnantes, "")
  expect_equal(cons$familles_perdantes, "")
  r0 <- comparer_itineraires(u, c(P = 1, C = 1), .catalogue_test(), trajectoires = tr,
                             tolerance = 0)
  expect_equal(r0$familles_gagnantes[r0$itineraire == "conservation"], "C")
  prod <- r[r$itineraire == "production", ]
  expect_equal(prod$familles_gagnantes, "P")
  expect_equal(prod$familles_perdantes, "C")
  expect_error(comparer_itineraires(u, c(P = 1), .catalogue_test(), trajectoires = tr,
                                    tolerance = -1), "tolerance")
})

test_that("trajectoires: horizon, missing variables and unknown units are refused", {
  u <- .unites(2)
  tr <- .traj_test()
  r5 <- comparer_itineraires(u, c(P = 1, C = 1), .catalogue_test(), trajectoires = tr,
                             horizon = 5)
  v5 <- attr(r5, "valeurs")
  expect_equal(v5$valeur[v5$unit_id == "1" & v5$itineraire == "production" & v5$famille == "P"], 40)
  expect_error(comparer_itineraires(u, c(P = 1), .catalogue_test(), trajectoires = tr,
                                    horizon = 50), "not simulated up to")
  expect_error(comparer_itineraires(u, c(P = 1), .catalogue_test(),
                                    trajectoires = tr[tr$variable == "g", ]), "carbone = TRUE")
  expect_error(comparer_itineraires(u, c(P = 1), .catalogue_test(),
                                    trajectoires = tr[, c("unite", "annee")]), "simuler_itineraire")
  autre <- tr; autre$unite <- paste0("x", autre$unite)
  expect_error(comparer_itineraires(u, c(P = 1), .catalogue_test(), trajectoires = autre),
               "No unit")
  # sans volume simule, P se lit sur la surface terriere prelevee
  g <- tr[tr$variable != "volume_preleve", ]
  gp <- tr[tr$variable == "volume_preleve", ]
  gp$variable <- "g_prelevee"; gp$moyenne <- gp$moyenne / 10
  r <- comparer_itineraires(u, c(P = 1, C = 1), .catalogue_test(), trajectoires = rbind(g, gp))
  expect_true(all(attr(r, "valeurs")$unite_mesure[attr(r, "valeurs")$famille == "P"] == "m2/ha"))
})

test_that("profils_poids gives 12 family weights per profile", {
  p <- profils_poids()
  expect_gte(length(p), 13L)
  expect_true(all(vapply(p, length, 0L) == 12L))
  n <- profils_poids("profil_naturaliste")
  expect_equal(unname(n[c("B", "N", "W", "R")]), c(3, 3, 3, 3))
  expect_equal(unname(n["P"]), 1)
  expect_true(all(profils_poids("profil_chercheur") == 1))
  expect_equal(attr(p, "meta")$statut, "provisoire")
  expect_error(profils_poids("profil_inconnu"), "Unknown profile")
})
