# Garde-fou de capacité pour les tests qui exigent une VRAIE reprojection.
#
# Même famille d'anomalie que `skip_if_terra_write_broken()`
# (cf. helper-fast-raster.R) : sur certains runners GitHub Actions, les
# opérations terra qui passent par PROJ échouent en cours de suite —
# `terra::project()` rend alors `could not find valid method`
# (std::range_error) alors que :
#   * le même appel réussit localement (suite complète verte),
#   * le job `R-CMD-check` de la MÊME exécution CI passe pendant que le job
#     `tests` échoue — même code, même suite, deux runners.
#
# On ne masque donc pas une régression : on saute un test que le runtime ne
# permet pas d'exécuter. Sur tout environnement sain, la sonde passe et le test
# tourne normalement.
#
# À n'utiliser que pour une reprojection entre CRS réellement différents. Un
# code qui demande à PROJ une opération identité (4326 -> 4326) doit être
# corrigé, pas sauté — cf. `.eobs_point_vect()`.
skip_if_terra_project_broken <- function() {
  testthat::skip_if_not_installed("terra")
  # Sonde à chaque appel : l'anomalie apparaît EN COURS de suite, un cache
  # « OK » posé tôt laisserait passer les tests suivants. Une fois apparue elle
  # persiste, d'où le court-circuit collant côté « cassé ».
  if (isTRUE(getOption("nemeton.terra_project_broken", FALSE))) {
    testthat::skip(
      "terra::project() unavailable in this runtime (runner-specific PROJ anomaly)")
  }
  ok <- tryCatch({
    pt <- terra::vect(matrix(c(7, 48.5), ncol = 2), type = "points",
                      crs = "EPSG:4326")
    terra::project(pt, "EPSG:2154")
    TRUE
  }, error = function(e) FALSE)
  if (!isTRUE(ok)) {
    options(nemeton.terra_project_broken = TRUE)
    testthat::skip(
      "terra::project() unavailable in this runtime (runner-specific PROJ anomaly)")
  }
}
