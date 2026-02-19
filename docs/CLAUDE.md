# nemeton Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-01-05

## Active Technologies

- R \>= 4.0.0 (v0.2.0 uses R 4.5.2) (001-mvp-v0-3-0)

- R package data structures (.rda in data/), external data sources (INPN
  WFS, IGN BD Forêt, Corine Land Cover rasters) (001-mvp-v0-3-0)

- R \>= 4.0.0 (targeting R 4.1.0+ for compatibility with existing
  codebase) (001-mvp-v0.4.0)

- R \>= 4.0.0 (compatible avec nemeton v0.4.0) (001-learnr-tutorial)

- R \>= 4.1.0 (constitution minimum 4.1.0, recommend 4.3.0+ for
  performance) (001-mvp-v0.2.0)

## Project Structure

``` text
src/
tests/
```

## Commands

# Add commands for R \>= 4.1.0 (constitution minimum 4.1.0, recommend 4.3.0+ for performance)

## Code Style

R \>= 4.1.0 (constitution minimum 4.1.0, recommend 4.3.0+ for
performance): Follow standard conventions

## Recent Changes

- 001-learnr-tutorial: Added R \>= 4.0.0 (compatible avec nemeton
  v0.4.0)
- 001-mvp-v0.4.0: Added R \>= 4.0.0 (targeting R 4.1.0+ for
  compatibility with existing codebase)
- 001-mvp-v0-3-0: Added R \>= 4.0.0 (v0.2.0 uses R 4.5.2)

# CLAUDE.md — Addendum Tests & Couverture pour nemeton

# Ce fichier complète le CLAUDE.md existant avec les conventions de test spécifiques.

# Si un CLAUDE.md existe déjà, fusionner ce contenu avec l’existant.

## Stack de test

- **Framework** : testthat (edition 3)
- **Tests Shiny** : shinytest2 (E2E via chromote headless) +
  testServer() (unitaire)
- **Couverture** : covr → codecov
- **R \>= 4.1.0**, dépendances : sf, terra, ggplot2, shiny

## Commandes de référence

``` bash
# Lancer tous les tests
Rscript -e 'devtools::test()'

# Lancer un fichier de test spécifique
Rscript -e 'testthat::test_file("tests/testthat/test-mon_fichier.R")'

# Couverture globale (pourcentage)
Rscript -e 'cat(covr::percent_coverage(covr::package_coverage(quiet=TRUE)))'

# Couverture par fichier
Rscript -e 'print(as.data.frame(covr::tally_coverage(covr::package_coverage(quiet=TRUE), by="file")))'

# Lignes non couvertes
Rscript -e 'print(covr::zero_coverage(covr::package_coverage(quiet=TRUE)))'

# Rapport HTML interactif
Rscript -e 'covr::report(covr::package_coverage())'
```

## Conventions de nommage des tests

| Fichier source   | Fichier de test (unitaire)               | Fichier de test (E2E Shiny)           |
|------------------|------------------------------------------|---------------------------------------|
| `R/indicators.R` | `tests/testthat/test-indicators.R`       | —                                     |
| `R/mod_radar.R`  | `tests/testthat/test-mod_radar-server.R` | `tests/testthat/test-mod_radar-e2e.R` |
| `R/app_server.R` | `tests/testthat/test-app_server.R`       | `tests/testthat/test-app-e2e.R`       |

## Stratégie de test par type de code

### Fonctions R pures (indicateurs, calculs, normalisation)

``` r
test_that("calculate_carbon_index() retourne les bonnes valeurs", {
  data(massif_demo_units, package = "nemeton")
  result <- calculate_carbon_index(massif_demo_units)
  expect_true(is.numeric(result))
  expect_true(all(result >= 0 & result <= 100, na.rm = TRUE))
})

test_that("calculate_carbon_index() gère les NA", {
  df <- data.frame(biomass = c(100, NA, 300), area = c(10, 20, 30))
  result <- calculate_carbon_index(df)
  expect_true(any(is.na(result)))
})

test_that("calculate_carbon_index() refuse les entrées invalides", {
  expect_error(calculate_carbon_index(NULL))
  expect_error(calculate_carbon_index("pas un dataframe"))
})
```

### Fonctions spatiales (sf, terra)

``` r
test_that("nemeton_units() crée des unités spatiales", {
  withr::with_tempdir({
    # Créer un geopackage minimal pour le test
    test_sf <- sf::st_sf(
      id = 1:5,
      name = paste0("parcelle_", 1:5),
      area_ha = c(10, 20, 30, 40, 50),
      geometry = sf::st_sfc(lapply(1:5, function(i) {
        sf::st_polygon(list(matrix(
          c(i, 0, i+1, 0, i+1, 1, i, 1, i, 0), ncol = 2, byrow = TRUE
        )))
      })),
      crs = 4326
    )
    sf::st_write(test_sf, "test.gpkg", quiet = TRUE)
    result <- nemeton_units("test.gpkg")
    expect_s3_class(result, "sf")
    expect_equal(nrow(result), 5)
  })
})
```

### Modules Shiny — testServer() (PRIORITAIRE pour covr)

``` r
# testServer() exécute le code serveur du module dans le même processus R
# → le code EST instrumenté par covr → CONTRIBUE à la couverture

test_that("mod_radar_server retourne un plot", {
  data(massif_demo_units, package = "nemeton")

  testServer(mod_radar_server, args = list(
    data = reactive(massif_demo_units),
    selected_unit = reactive(1)
  ), {
    session$setInputs(mode = "family")
    # Vérifier que le plot est généré
    expect_true(!is.null(output$radar_plot))
  })
})

test_that("mod_radar_server gère les données vides", {
  testServer(mod_radar_server, args = list(
    data = reactive(data.frame()),
    selected_unit = reactive(NULL)
  ), {
    # Vérifier que ça ne plante pas
    expect_silent(session$flushReact())
  })
})
```

### Modules Shiny — shinytest2 AppDriver (E2E, complémentaire)

``` r
# AppDriver lance l'app dans un processus R SÉPARÉ
# → le code n'est PAS instrumenté par covr (ne contribue PAS directement à la couverture)
# → MAIS teste l'intégration UI + Server + interactions utilisateur
# → UTILE pour détecter les bugs d'intégration, les erreurs JS, etc.

test_that("mod_radar E2E : l'utilisateur peut changer de mode", {
  skip_on_cran()
  skip_if_not_installed("shinytest2")
  skip_if_not(shinytest2::has_chromote(), "Chrome/Chromium requis")

  data(massif_demo_units, package = "nemeton")

  app <- shinytest2::AppDriver$new(
    shiny::shinyApp(
      ui = shiny::fluidPage(mod_radar_ui("test")),
      server = function(input, output, session) {
        mod_radar_server("test",
          data = reactive(massif_demo_units),
          selected_unit = reactive(1)
        )
      }
    ),
    name = "mod-radar-e2e",
    height = 800, width = 1200,
    load_timeout = 20000
  )
  on.exit(app$stop(), add = TRUE)

  # Vérifier que l'app charge
  vals <- app$get_values()
  expect_true(length(vals$output) > 0)

  # Changer de mode
  app$set_inputs(`test-mode` = "indicator")
  app$wait_for_idle(timeout = 5000)

  new_vals <- app$get_values()
  # L'output devrait avoir changé
})
```

### App complète

``` r
test_that("L'app nemeton démarre et affiche les contrôles", {
  skip_on_cran()
  skip_if_not_installed("shinytest2")
  skip_if_not(shinytest2::has_chromote(), "Chrome/Chromium requis")

  app <- shinytest2::AppDriver$new(
    nemeton::run_app(),
    name = "nemeton-app",
    load_timeout = 30000,
    timeout = 15000
  )
  on.exit(app$stop(), add = TRUE)

  vals <- app$get_values()
  expect_true(length(vals$input) > 0 || length(vals$output) > 0)
})
```

## Point critique : covr et shinytest2

> **testServer() contribue à covr** car le code tourne dans le même
> processus R. **AppDriver (shinytest2) ne contribue PAS à covr** car
> l’app tourne dans un processus séparé.
>
> Pour MAXIMISER la couverture : écrire TOUJOURS des tests testServer()
> en premier, puis ajouter des tests AppDriver pour les scénarios E2E.

## Données de test disponibles

- `data(massif_demo_units)` : 20 unités forestières, 12 familles
  d’indicateurs
- Créer des sf minimaux pour les tests spatiaux (voir exemples
  ci-dessus)
- [`withr::with_tempdir()`](https://withr.r-lib.org/reference/with_tempfile.html)
  pour les fichiers temporaires
- [`testthat::local_mocked_bindings()`](https://testthat.r-lib.org/reference/local_mocked_bindings.html)
  pour mocker les dépendances

## Règles strictes

1.  **NE JAMAIS modifier** R/, inst/, man/, data/, src/, NAMESPACE
2.  **DESCRIPTION** : modifiable uniquement pour Suggests
3.  **Pas de tests triviaux** — chaque test vérifie un comportement réel
4.  \*\*on.exit(app$stop{()})**obligatoireaprèschaqueAppDriver$new()
5.  **skip_on_cran()** obligatoire avant tout test shinytest2
6.  **Vérifier que les 2987+ tests existants passent** avant de commiter
