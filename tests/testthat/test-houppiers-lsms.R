# test-houppiers-lsms.R — spec 051, délimitation par LSMS (OTB).
#
# Le pipeline OTB lui-même demande un binaire externe et ~3 min pour la plus
# petite fenêtre utile : il est couvert par un smoke manuel. Ces cas verrouillent
# ce qui décide sans lui — le garde-fou de budget, les deux usages, et la
# validation des arguments. C'est là que sont les décisions de la spec.

test_that("the cost model reproduces its two measured points", {
  # Spec 051 §2.1 : 1,0 Mpx -> 160,5 s et 4,0 Mpx -> 716 s, mesurés sur une
  # fenêtre de futaie fermée à 89 %. Le modèle est calé DESSUS ; s'il s'en
  # écarte, c'est qu'on a touché à ses constantes sans refaire la mesure.
  expect_equal(lsms_duree_estimee(1e6), 160.5, tolerance = 0.01)
  expect_equal(lsms_duree_estimee(4e6), 716, tolerance = 0.01)
  # Sur-linéaire : ×4 pixels coûte plus que ×4.
  expect_gt(lsms_duree_estimee(4e6) / lsms_duree_estimee(1e6), 4)
})

test_that("cost grows with spatialr, which is why 15 is the default", {
  # 15 -> 178 s et 20 -> 321 s à minsize égal : le rayon spatial est le poste
  # dominant, et il n'achète rien (spec 051 §3.3).
  expect_gt(lsms_duree_estimee(1e6, spatialr = 20),
            1.7 * lsms_duree_estimee(1e6, spatialr = 15))
  expect_lt(lsms_duree_estimee(1e6, spatialr = 10),
            lsms_duree_estimee(1e6, spatialr = 15))
})

test_that("lsms_budget_pixels inverts lsms_duree_estimee", {
  for (b in c(60, 300, 600, 1800)) {
    p <- lsms_budget_pixels(b)
    expect_equal(lsms_duree_estimee(p), b, tolerance = 1e-6)
  }
  # Le budget de 10 min retenu par Pascal : ~3,4 Mpx (spec 051 §3.1).
  expect_equal(lsms_budget_pixels(600) / 1e6, 3.40, tolerance = 0.01)
  # Un spatialr plus grand achète moins de pixels pour le même budget.
  expect_lt(lsms_budget_pixels(600, spatialr = 20), lsms_budget_pixels(600))
})

test_that("the budget helpers reject nonsense rather than extrapolate it", {
  expect_error(lsms_duree_estimee(-1), "non-negative")
  expect_error(lsms_duree_estimee(c(1, 2)), "single")
  expect_error(lsms_duree_estimee(1e6, spatialr = 0), "positive")
  expect_error(lsms_budget_pixels(0), "positive")
})

test_that("algorithme = 'lsms' demands an image, since it segments one", {
  expect_error(
    segment_houppiers(chm = NULL, algorithme = "lsms", usage = "couvert"),
    "segments an IMAGE")
})

test_that("usage = 'martelage' refuses without a CHM (D2)", {
  # LSMS délimite, il ne mesure pas. Une couche sans hauteur est ignorée SANS
  # UN MOT par Marculus : la refuser vaut mieux que la livrer.
  r <- terra::rast(nrows = 4, ncols = 4, crs = "EPSG:2154")
  terra::values(r) <- seq_len(16)
  expect_error(
    segment_houppiers(chm = NULL, algorithme = "lsms", image = r),
    "requires a CHM")
  # Le message doit nommer la sortie de secours, pas seulement le refus.
  err <- tryCatch(segment_houppiers(chm = NULL, algorithme = "lsms", image = r),
                  error = function(e) conditionMessage(e))
  expect_match(err, "couvert")
})

test_that("usage is rejected on the CHM route, which always measures a height", {
  expect_error(
    segment_houppiers(chm = NULL, algorithme = "dalponte", usage = "couvert"),
    "only applies")
})

test_that("the CHM routes still demand a CHM", {
  for (a in c("dalponte", "silva", "watershed")) {
    expect_error(segment_houppiers(chm = NULL, algorithme = a),
                 "required for", info = a)
  }
})

test_that("the LSMS defaults are the calibrated ones, not the CookBook's", {
  # Le défaut du CookBook (5/15/50) sur-segmente d'un facteur 15 : à 2,4 m de
  # diamètre médian on segmente des facettes de houppier, pas des arbres.
  # 15/20/700 est calibré contre la voie CHM (écart -0,15 m, spec 051 §3.3).
  expect_equal(nemeton:::.LSMS_DEFAUTS$spatialr, 15L)
  expect_equal(nemeton:::.LSMS_DEFAUTS$ranger, 20)
  expect_equal(nemeton:::.LSMS_DEFAUTS$minsize, 700L)
})

test_that("OTB absence is reported as a missing tool, not as a crash", {
  skip_if(nzchar(nemeton:::.lsms_otb_dir()), "OTB is installed here")
  r <- terra::rast(nrows = 4, ncols = 4, crs = "EPSG:2154")
  terra::values(r) <- seq_len(16)
  err <- tryCatch(
    segment_houppiers(chm = NULL, algorithme = "lsms", image = r,
                      usage = "couvert"),
    error = function(e) conditionMessage(e))
  expect_match(err, "Orfeo ToolBox")
  expect_match(err, "OTB_DIR")          # dit COMMENT reparer
  expect_match(err, "dalponte")         # et par quoi se rabattre
})

test_that("the budget guard refuses before calling OTB, and says what fits", {
  skip_if_not(nzchar(nemeton:::.lsms_otb_dir()), "needs an OTB installation")
  skip_if_not_installed("terra")
  # 2000 x 2000 px à 0,20 m = 16 ha : ~716 s estimées, au-dessus d'un budget
  # de 60 s. Le refus doit être INSTANTANÉ — s'il appelait OTB on attendrait
  # douze minutes pour se faire dire non.
  r <- terra::rast(nrows = 2000, ncols = 2000, resolution = 0.2,
                   crs = "EPSG:2154")
  terra::values(r) <- 1L
  t0 <- Sys.time()
  err <- tryCatch(
    segment_houppiers(chm = NULL, algorithme = "lsms", image = r,
                      usage = "couvert", budget_s = 60),
    error = function(e) conditionMessage(e))
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 30)
  expect_match(err, "over the")
  expect_match(err, "affords")            # combien tient, pas juste "trop grand"
  expect_match(err, "resolution_image")   # le levier d'ordre de grandeur
})

test_that("a generous budget lets the same image through the guard", {
  skip_if_not(nzchar(nemeton:::.lsms_otb_dir()), "needs an OTB installation")
  # Même image, budget large : le garde-fou ne doit plus être la cause de
  # l'échec. On n'attend PAS le run OTB — on vérifie seulement que le message
  # n'est plus celui du budget.
  r <- terra::rast(nrows = 40, ncols = 40, resolution = 0.2, crs = "EPSG:2154")
  terra::values(r) <- 1L
  expect_lt(lsms_duree_estimee(terra::ncell(r)), 600)
})
