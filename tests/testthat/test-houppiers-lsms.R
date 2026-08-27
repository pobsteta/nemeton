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

# --- Garde-fou « CHM dégénéré » (v0.191.1) ----------------------------------
# Un CHM mort ne fait pas échouer la segmentation : il rend zéro houppier. Une
# clairière légitime et une prédiction Open-Canopy en panne produisaient donc le
# MÊME objet vide, sans un mot. Mesuré sur le projet Fordead :
# `chm_predicted_0_2m.tif` plafonne à 0,1879 m sur 292 M cellules.

.chm_test <- function(values) {
  n <- ceiling(sqrt(length(values)))
  r <- terra::rast(nrows = n, ncols = n, xmin = 0, xmax = n * 0.5,
                   ymin = 0, ymax = n * 0.5, crs = "EPSG:2154")
  terra::values(r) <- rep_len(values, terra::ncell(r))
  r
}

test_that("a dead CHM is diagnosed, not silently empty", {
  skip_if_not_installed("terra")
  mort <- .chm_test(runif(400, 0, 0.19))      # l'ordre de grandeur réel mesuré
  d <- nemeton:::.houppier_chm_degenere(mort, hmin = 5)
  expect_true(d$suspect)
  expect_lt(d$chm_max, 0.2)
  expect_equal(d$frac_low, 1)
  expect_warning(nemeton:::.houppier_chm_degenere(mort, hmin = 5), "degenerate")
})

test_that("the warning says why an empty layer is ambiguous", {
  skip_if_not_installed("terra")
  msg <- tryCatch(
    nemeton:::.houppier_chm_degenere(.chm_test(rep(0, 400)), hmin = 5),
    warning = function(w) conditionMessage(w))
  # Le message doit expliquer la CONFUSION, pas seulement constater la hauteur :
  # c'est « 0 n'est pas NA » (v0.186/v0.187) appliqué ici.
  expect_match(msg, "same empty crown layer", ignore.case = TRUE)
  expect_match(msg, "clearing")
})

test_that("a healthy CHM is not flagged", {
  skip_if_not_installed("terra")
  sain <- .chm_test(runif(400, 0, 30))
  expect_silent(d <- nemeton:::.houppier_chm_degenere(sain, hmin = 5))
  expect_false(d$suspect)
})

test_that("the guard needs BOTH conditions, not just a low maximum", {
  skip_if_not_installed("terra")
  # Un jeune peuplement homogène à 4 m : 100 % sous le plancher de 5 m, mais son
  # maximum n'est PAS quasi nul. Ce n'est pas un CHM mort, c'est un gaulis.
  #
  # La règle portée depuis `synthetic_inventory.R` le signalait pourtant : elle
  # n'exigeait qu'un maximum « sous le plancher ». Resserrée ici à `max_frac`
  # fois le plancher (0,5 m pour 5 m), parce que le CHM réellement mort mesuré
  # sur Fordead plafonne à 0,19 m — trois ordres de grandeur plus bas.
  gaulis <- .chm_test(rep(4, 400))
  expect_silent(d <- nemeton:::.houppier_chm_degenere(gaulis, hmin = 5))
  expect_false(d$suspect)
  # Descendre le plancher sous la hauteur du gaulis le disculpe aussi.
  expect_false(nemeton:::.houppier_chm_degenere(gaulis, hmin = 3)$suspect)
})

test_that("a partially stocked stand is not flagged either", {
  skip_if_not_installed("terra")
  # 96 % de sol nu mais 4 % d'arbres à 25 m : au-dessus de suspect_frac, et
  # pourtant parfaitement légitime — le maximum le prouve.
  clair <- .chm_test(c(rep(0, 384), rep(25, 16)))
  d <- nemeton:::.houppier_chm_degenere(clair, hmin = 5)
  expect_gt(d$frac_low, 0.95)
  expect_false(d$suspect)
})

test_that("the verdict is stamped on the OUTPUT, empty layer included", {
  skip_if_not_installed("terra")
  skip_if_not_installed("lidR")
  f <- withr::local_tempfile(fileext = ".tif")
  terra::writeRaster(.chm_test(rep(0.1, 400)), f)
  out <- suppressWarnings(segment_houppiers(f))
  expect_equal(nrow(out), 0L)
  # C'est le cas VIDE qui a le plus besoin de porter le diagnostic : sans
  # l'attribut, l'appelant ne peut pas distinguer « rien ici » de « CHM mort ».
  expect_true(attr(out, "chm_suspect"))
  expect_lt(attr(out, "chm_max"), 0.2)
})

test_that("a healthy segmentation carries chm_suspect = FALSE, not NULL", {
  skip_if_not_installed("terra")
  skip_if_not_installed("lidR")
  # Un cône : un apex net, donc au moins un houppier.
  r <- terra::rast(nrows = 60, ncols = 60, resolution = 0.5, crs = "EPSG:2154")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  ctr <- c(mean(xy[, 1]), mean(xy[, 2]))
  d <- sqrt((xy[, 1] - ctr[1])^2 + (xy[, 2] - ctr[2])^2)
  terra::values(r) <- pmax(0, 25 - d * 2)
  out <- segment_houppiers(r, ws = 3, hmin = 2)
  expect_false(is.null(attr(out, "chm_suspect")))
  expect_false(attr(out, "chm_suspect"))
})
