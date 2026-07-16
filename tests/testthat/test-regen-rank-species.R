# test-regen-rank-species.R — classement déterministe top-N essences (spec 039).
# Pool d'essences explicite (traits contrôlés) + UGF aux conditions contrastées,
# valeurs attendues calculées à la main. Aucun aléa, aucune acquisition.

# UGF : 1 chaude & sèche, 1 tempérée. Colonnes station du contrat §7.
.rk_units <- function() {
  g <- lapply(1:2, function(i) {
    x <- (i - 1) * 10
    sf::st_polygon(list(rbind(c(x, 0), c(x + 5, 0), c(x + 5, 5), c(x, 5), c(x, 0))))
  })
  sf::st_sf(
    ug_id = c("A", "B"),
    tmax_moyenne = c(28, 22), d_tmax = c(6, 2),
    vpd_canicule = c(3.0, 1.2), rew_min = c(0.1, 0.8),
    R7 = c(90, 95),
    geometry = sf::st_sfc(g, crs = 2154))
}

# Pool : chêne thermophile (chaud/sec tolérant), sapin (frais/humide), robinier
# (invasif). Traits sur l'échelle Niinemets & Valladares 1-5 (haut = tolérant).
.rk_pool <- function() {
  data.frame(
    code = c("chene_vert", "sapin", "robinier"),
    label = c("Chêne vert", "Sapin", "Robinier"),
    type = c("feuillu", "resineux", "feuillu"),
    tmax_tol_c = c(35, 29, 36), vpd_tol_kpa = c(2.5, 1.6, 3.0),
    drought_tol = c(5, 1.4, 4), shade_tol = c(3, 4.6, 2),
    frost_late = c(4, 2, 4), confidence = c("eleve", "eleve", "moyen"),
    invasif = c(FALSE, FALSE, TRUE),
    stringsAsFactors = FALSE)
}

test_that("regen_rank_species ranks the heat/dry-tolerant species first on a hot dry UGF", {
  ranked <- regen_rank_species(.rk_units(), species_pool = .rk_pool(), top_n = 2)
  expect_s3_class(ranked, "data.frame")
  expect_identical(names(ranked), c("ug_id", "rank", "species_code", "label",
    "type", "suitability", "limiting_factor", "confidence", "invasif"))
  # robinier (invasif) exclu par défaut -> 2 essences × 2 UGF = 4 lignes.
  expect_equal(nrow(ranked), 4L)
  expect_false("robinier" %in% ranked$species_code)
  a <- ranked[ranked$ug_id == "A", ]
  expect_equal(a$rank, c(1L, 2L))
  expect_equal(a$species_code[1], "chene_vert")      # thermophile gagne sur UGF chaude/sèche
  expect_equal(a$suitability[1], 78.2, tolerance = 0.2)   # calc manuel (axes A+B renorm.)
  expect_equal(a$limiting_factor[1], "secheresse")   # VPD est le facteur plafond
  expect_equal(a$species_code[2], "sapin")
  expect_lt(a$suitability[2], a$suitability[1])
  expect_identical(a$confidence[1], "eleve")         # propagée, pas fondue dans le score
})

test_that("regen_rank_species includes invasives when exclude_invasive = FALSE", {
  ranked <- regen_rank_species(.rk_units(), species_pool = .rk_pool(),
                               top_n = 3, exclude_invasive = FALSE)
  expect_true("robinier" %in% ranked$species_code)
  expect_equal(sum(ranked$ug_id == "A"), 3L)
})

test_that("regen_rank_species is NA-safe when station data is missing", {
  u <- .rk_units()
  u$d_tmax <- NA_real_; u$tmax_moyenne <- NA_real_
  u$vpd_canicule <- NA_real_; u$rew_min <- NA_real_; u$R7 <- NA_real_
  ranked <- regen_rank_species(u, species_pool = .rk_pool(), top_n = 3)
  # aucune reco fabriquée : une ligne rank NA par UGF
  expect_true(all(is.na(ranked$rank)))
  expect_true(all(is.na(ranked$suitability)))
  expect_equal(nrow(ranked), 2L)
})

test_that("regen_rank_species returns an empty frame when the pool is empty after exclusion", {
  only_inv <- .rk_pool()[.rk_pool()$invasif, , drop = FALSE]
  ranked <- regen_rank_species(.rk_units(), species_pool = only_inv,
                               top_n = 3, exclude_invasive = TRUE)
  expect_equal(nrow(ranked), 0L)
  expect_true(is.data.frame(ranked))
})

test_that("late-frost axis differentiates species by frost_late", {
  # UGF gélive (R7 bas = forte pression gel) ; deux essences identiques sauf
  # frost_late (1 sensible vs 5 résistant). La résistante doit scorer plus haut.
  u <- .rk_units()[1, ]; u$R7 <- 10                 # forte pression gel
  pool <- data.frame(
    code = c("sensible", "resistante"), label = c("S", "R"),
    type = "feuillu", tmax_tol_c = 40, vpd_tol_kpa = 5, drought_tol = 5,
    shade_tol = 3, frost_late = c(1, 5), confidence = "eleve",
    invasif = FALSE, stringsAsFactors = FALSE)
  ranked <- regen_rank_species(u, species_pool = pool, top_n = 2)
  expect_equal(ranked$species_code[1], "resistante")
  expect_gt(ranked$suitability[ranked$species_code == "resistante"],
            ranked$suitability[ranked$species_code == "sensible"])
  expect_equal(ranked$limiting_factor[ranked$species_code == "sensible"], "gel")
})

test_that("shade axis via lai_col penalises light-demanding species under dense canopy", {
  # LAI élevé -> fort couvert résiduel ; l'essence de lumière (shade_tol bas) est
  # pénalisée sur l'axe ombre, l'essence d'ombre non.
  u <- .rk_units()[1, ]; u$lai_max <- 6             # couvert dense
  # neutralise chaleur/sécheresse/gel pour isoler l'ombre
  u$tmax_moyenne <- 15; u$d_tmax <- 0; u$vpd_canicule <- 0.5
  u$rew_min <- 1; u$R7 <- 100
  pool <- data.frame(
    code = c("ombre", "lumiere"), label = c("O", "L"), type = "resineux",
    tmax_tol_c = 40, vpd_tol_kpa = 5, drought_tol = 5,
    shade_tol = c(5, 1), frost_late = 5, confidence = "eleve",
    invasif = FALSE, stringsAsFactors = FALSE)
  ranked <- regen_rank_species(u, species_pool = pool, top_n = 2, lai_col = "lai_max")
  expect_equal(ranked$species_code[1], "ombre")
  expect_equal(ranked$limiting_factor[ranked$species_code == "lumiere"], "ombre")
})

test_that("weights override changes the aggregation", {
  u <- .rk_units()[1, ]
  base <- regen_rank_species(u, species_pool = .rk_pool()[1:2, ], top_n = 2)
  # tout le poids sur le gel -> suitability = axisB (gel) seul
  only_gel <- regen_rank_species(u, species_pool = .rk_pool()[1:2, ], top_n = 2,
    weights = c(chaleur_secheresse = 0, gel = 1, ombre = 0))
  expect_false(isTRUE(all.equal(sort(base$suitability), sort(only_gel$suitability))))
})

test_that("regen_rank_to_wide pivots to one row per unit", {
  ranked <- regen_rank_species(.rk_units(), species_pool = .rk_pool(), top_n = 2)
  wide <- regen_rank_to_wide(ranked, top_n = 2)
  expect_equal(nrow(wide), 2L)                       # 2 UGF
  expect_true(all(c("ug_id", "essence_1", "score_1", "label_1", "facteur_1",
                    "essence_2", "score_2") %in% names(wide)))
  a <- wide[wide$ug_id == "A", ]
  expect_equal(a$essence_1, "chene_vert")
  expect_equal(a$score_1, ranked$suitability[ranked$ug_id == "A" & ranked$rank == 1])
})

test_that("regen_rank_species resolves frost_late from the EU table for code pools", {
  # pool = vecteur de codes réels -> traits (dont frost_late) joints depuis la
  # table UE ; le hêtre (frost_late=1) est pénalisé sur une UGF gélive.
  skip_if_not(nrow(tryCatch(european_species_tolerances(), error = function(e) data.frame())) > 0)
  u <- .rk_units()[1, ]; u$R7 <- 10
  ranked <- regen_rank_species(u, species_pool = c("fagus_sylvatica", "quercus_robur"),
                               top_n = 2)
  expect_equal(nrow(ranked), 2L)
  # chêne (frost_late=3) mieux classé que hêtre (frost_late=1) sur UGF gélive
  expect_equal(ranked$species_code[1], "quercus_robur")
})
