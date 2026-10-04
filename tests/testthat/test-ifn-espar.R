# Tests du pont de nomenclatures (spec 040, D9).

test_that("the correspondence table carries the three nomenclatures", {
  d <- ifn_espar_correspondance()
  expect_true(all(c("espar", "lib_espar", "espece_sci", "code_p1",
                    "code_tolerances") %in% names(d)))
  expect_gt(nrow(d), 150)
  expect_false(any(duplicated(d$espar)))
})

test_that("espar codes follow the ARBRE.csv convention, zero-padded", {
  # Piege des zeros non significatifs : le referentiel ecrit "9", les donnees
  # "09". Un pont rendant "9" n'apparierait AUCUNE ligne des tables de
  # reference — silencieusement. Verrou explicite.
  d <- ifn_espar_correspondance()
  numeriques <- grepl("^[0-9]+$", d$espar)
  expect_true(all(nchar(d$espar[numeriques]) >= 2L))
  expect_true("09" %in% d$espar)
  expect_false("9" %in% d$espar)
})

test_that("the bridge output actually keys the reference tables", {
  # Le test qui compte : un code resolu doit retrouver une ligne reelle.
  e <- resoudre_espar("FASY")
  expect_identical(e, "09")
  expect_gt(nrow(ifn_volume_essence_ser(espar = e, niveau = "national")), 0L)
})

test_that("all four nomenclatures resolve to the same espar", {
  x <- c("09", "FASY", "fagus_sylvatica", "Fagus sylvatica")
  expect_identical(unique(resoudre_espar(x)), "09")
})

test_that("resolution is case-insensitive except for espar itself", {
  expect_identical(resoudre_espar("fasy"), "09")
  expect_identical(resoudre_espar("FAGUS SYLVATICA"), "09")
})

test_that("the autonym rescues infraspecific IGN names", {
  # L'IGN publie "Picea abies subsp. abies" la ou nos tables portent le binome.
  expect_identical(resoudre_espar("PIAB"), "62")
  expect_identical(resoudre_espar("QURO"), "02")
  expect_identical(resoudre_espar("Quercus petraea"), "03")
})

test_that("Douglas maps to Pseudotsuga, not Pinus", {
  # ifn_volume_equations.csv portait "Pinus menziesii" — corrige en
  # "Pseudotsuga menziesii" grace a ce croisement.
  # Le code PIME (doublon historique) a disparu : le Douglas est PSME
  # partout, comme dans tout le code (audit 1.0). resoudre_espar("PSME")
  # rendait NA.
  expect_identical(resoudre_espar("PSME"), "64")
  expect_true(is.na(resoudre_espar("PIME")))
  d <- ifn_espar_correspondance(espar = "64")
  expect_match(d$espece_sci, "^Pseudotsuga")
  expect_identical(d$code_p1, "PSME")
})

test_that("PSME is the single Douglas code across the reference tables", {
  lire <- function(f) utils::read.csv(
    system.file("extdata", f, package = "nemeton"), stringsAsFactors = FALSE)
  for (f in c("ifn_volume_equations.csv", "wood_density.csv",
              "productivity_tables.csv")) {
    tab <- lire(f)
    expect_false("PIME" %in% tab$species_code, info = f)
    expect_true("PSME" %in% tab$species_code, info = f)
  }
  # Une seule ligne de tarif pour le Douglas.
  eq <- lire("ifn_volume_equations.csv")
  expect_equal(sum(grepl("^Pseudotsuga", eq$species_name)), 1L)
  # Densité propre du Douglas, et non plus le repli feuillu (620).
  expect_equal(lookup_species_threshold("PSME", "density_kg_m3"), 490)
})

test_that("unknown codes yield NA, never a guess", {
  expect_true(is.na(resoudre_espar("ZZZZ")))
  expect_true(is.na(resoudre_espar("POSP")))  # "Populus cultive" : pas du latin
  expect_equal(length(resoudre_espar(c("FASY", "ZZZZ"))), 2L)
})

test_that("resolution is vectorised and order-preserving", {
  r <- resoudre_espar(c("FASY", "ZZZZ", "PIAB"))
  expect_identical(r, c("09", NA, "62"))
})
