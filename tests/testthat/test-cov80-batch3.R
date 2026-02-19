# test-cov80-batch3.R
# Coverage boost for R/service_project.R
# Target: create/update/delete project, save/load parcels/indicators/comments,
#         list_recent_projects, check_project_health, cache data

# ==============================================================================
# Helper: mock get_app_options to use temp dir
# ==============================================================================

with_temp_projects <- function(code) {
  withr::with_tempdir({
    temp_root <- file.path(getwd(), "projects")
    dir.create(temp_root, recursive = TRUE)

    local_mocked_bindings(
      get_app_options = function() list(project_dir = temp_root),
      .package = "nemeton"
    )

    force(code)
  })
}

# ==============================================================================
# get_projects_root()
# ==============================================================================

test_that("get_projects_root creates directory if not exists", {
  with_temp_projects({
    root <- nemeton:::get_projects_root()
    expect_true(dir.exists(root))
  })
})

# ==============================================================================
# create_project()
# ==============================================================================

test_that("create_project creates project directory and metadata", {
  with_temp_projects({
    result <- nemeton:::create_project("My Project", "A description", "Owner")
    expect_type(result, "list")
    expect_true(!is.null(result$id))
    expect_true(dir.exists(result$path))
    expect_equal(result$metadata$name, "My Project")
    expect_equal(result$metadata$description, "A description")
    expect_equal(result$metadata$status, "draft")

    # Check metadata file exists
    meta_path <- file.path(result$path, "metadata.json")
    expect_true(file.exists(meta_path))

    # Check subdirectories
    expect_true(dir.exists(file.path(result$path, "data")))
    expect_true(dir.exists(file.path(result$path, "cache")))
    expect_true(dir.exists(file.path(result$path, "exports")))
  })
})

test_that("create_project with parcels saves them", {
  with_temp_projects({
    parcels <- create_test_units(n_features = 3)
    result <- nemeton:::create_project("With Parcels", parcels = parcels)
    expect_equal(result$metadata$parcels_count, 3)

    # Verify parcels file exists
    gpkg <- file.path(result$path, "data", "parcels.gpkg")
    expect_true(file.exists(gpkg))
  })
})

test_that("create_project validates empty name", {
  with_temp_projects({
    expect_error(nemeton:::create_project(""), "name is required")
    expect_error(nemeton:::create_project("  "), "name is required")
    expect_error(nemeton:::create_project(NULL), "name is required")
  })
})

test_that("create_project validates name length", {
  with_temp_projects({
    expect_error(
      nemeton:::create_project(paste(rep("x", 101), collapse = "")),
      "100 characters"
    )
  })
})

test_that("create_project validates description length", {
  with_temp_projects({
    expect_error(
      nemeton:::create_project("Test", description = paste(rep("x", 501), collapse = "")),
      "500 characters"
    )
  })
})

test_that("create_project validates owner length", {
  with_temp_projects({
    expect_error(
      nemeton:::create_project("Test", owner = paste(rep("x", 101), collapse = "")),
      "100 characters"
    )
  })
})

# ==============================================================================
# save_parcels() / load_parcels()
# ==============================================================================

test_that("save_parcels and load_parcels round-trip GeoPackage", {
  with_temp_projects({
    proj <- nemeton:::create_project("Parcel Test")
    parcels <- create_test_units(n_features = 4)

    result <- nemeton:::save_parcels(proj$id, parcels)
    expect_true(result)

    loaded <- nemeton:::load_parcels(proj$id)
    expect_s3_class(loaded, "sf")
    expect_equal(nrow(loaded), 4)
  })
})

test_that("save_parcels sets CRS when missing", {
  with_temp_projects({
    proj <- nemeton:::create_project("CRS Test")
    parcels <- create_test_units(n_features = 2)
    sf::st_crs(parcels) <- NA

    result <- nemeton:::save_parcels(proj$id, parcels)
    expect_true(result)

    loaded <- nemeton:::load_parcels(proj$id)
    expect_false(is.na(sf::st_crs(loaded)))
  })
})

test_that("save_parcels rejects non-sf object", {
  with_temp_projects({
    proj <- nemeton:::create_project("Bad Input")
    expect_error(nemeton:::save_parcels(proj$id, data.frame(x = 1)), "must be an sf")
  })
})

test_that("load_parcels returns NULL for nonexistent project", {
  with_temp_projects({
    result <- nemeton:::load_parcels("nonexistent_id")
    expect_null(result)
  })
})

test_that("load_parcels returns NULL when no parcels file", {
  with_temp_projects({
    proj <- nemeton:::create_project("Empty")
    result <- nemeton:::load_parcels(proj$id)
    expect_null(result)
  })
})

# ==============================================================================
# save_indicators() / load_indicators()
# ==============================================================================

test_that("save_indicators and load_indicators round-trip", {
  skip_if_not_installed("arrow")
  with_temp_projects({
    proj <- nemeton:::create_project("Indicator Test")
    indicators <- data.frame(C1 = c(80, 60), B1 = c(70, 50))

    result <- nemeton:::save_indicators(proj$id, indicators)
    expect_true(result)

    loaded <- nemeton:::load_indicators(proj$id)
    expect_true(is.data.frame(loaded))
    expect_equal(nrow(loaded), 2)
  })
})

test_that("save_indicators converts list to data.frame", {
  skip_if_not_installed("arrow")
  with_temp_projects({
    proj <- nemeton:::create_project("List Test")
    indicators <- list(C1 = c(80, 60), B1 = c(70, 50))

    result <- nemeton:::save_indicators(proj$id, indicators)
    expect_true(result)
  })
})

test_that("load_indicators returns NULL when no file", {
  with_temp_projects({
    proj <- nemeton:::create_project("No Indicators")
    result <- nemeton:::load_indicators(proj$id)
    expect_null(result)
  })
})

test_that("load_indicators returns NULL for nonexistent project", {
  with_temp_projects({
    result <- nemeton:::load_indicators("nonexistent")
    expect_null(result)
  })
})

# ==============================================================================
# save_comments() / load_comments()
# ==============================================================================

test_that("save_comments and load_comments round-trip", {
  with_temp_projects({
    proj <- nemeton:::create_project("Comment Test")

    result <- nemeton:::save_comments(proj$id,
      synthesis = "Overall good",
      families = list(C = "Carbon is fine", B = "Biodiversity needs work")
    )
    expect_true(result)

    loaded <- nemeton:::load_comments(proj$id)
    expect_equal(loaded$synthesis, "Overall good")
    expect_equal(loaded$families$C, "Carbon is fine")
  })
})

test_that("save_comments merges with existing", {
  with_temp_projects({
    proj <- nemeton:::create_project("Merge Test")

    # Save synthesis first
    nemeton:::save_comments(proj$id, synthesis = "First synthesis")

    # Save families (should preserve synthesis)
    nemeton:::save_comments(proj$id, families = list(C = "Carbon"))

    loaded <- nemeton:::load_comments(proj$id)
    expect_equal(loaded$synthesis, "First synthesis")
    expect_equal(loaded$families$C, "Carbon")
  })
})

test_that("save_comments returns FALSE for nonexistent project", {
  with_temp_projects({
    result <- suppressWarnings(nemeton:::save_comments("nonexistent", synthesis = "Test"))
    expect_false(result)
  })
})

test_that("load_comments returns NULL when no file", {
  with_temp_projects({
    proj <- nemeton:::create_project("No Comments")
    result <- nemeton:::load_comments(proj$id)
    expect_null(result)
  })
})

test_that("load_comments returns NULL for nonexistent project", {
  with_temp_projects({
    result <- nemeton:::load_comments("nonexistent")
    expect_null(result)
  })
})

# ==============================================================================
# load_project()
# ==============================================================================

test_that("load_project returns full project structure", {
  with_temp_projects({
    proj <- nemeton:::create_project("Full Project", "desc", "owner",
                                      parcels = create_test_units(n_features = 2))
    nemeton:::save_comments(proj$id, synthesis = "Good")

    loaded <- nemeton:::load_project(proj$id)
    expect_type(loaded, "list")
    expect_equal(loaded$id, proj$id)
    expect_equal(loaded$metadata$name, "Full Project")
    expect_s3_class(loaded$parcels, "sf")
    expect_equal(loaded$comments$synthesis, "Good")
  })
})

test_that("load_project returns NULL for nonexistent project", {
  with_temp_projects({
    result <- suppressWarnings(nemeton:::load_project("nonexistent"))
    expect_null(result)
  })
})

# ==============================================================================
# update_project()
# ==============================================================================

test_that("update_project updates metadata", {
  with_temp_projects({
    proj <- nemeton:::create_project("Original Name")

    updated <- nemeton:::update_project(proj$id, "New Name", "New desc", "New owner")
    expect_equal(updated$metadata$name, "New Name")
    expect_equal(updated$metadata$description, "New desc")
    expect_equal(updated$metadata$owner, "New owner")
  })
})

test_that("update_project with new parcels", {
  with_temp_projects({
    proj <- nemeton:::create_project("Update Parcels")
    new_parcels <- create_test_units(n_features = 5)

    updated <- nemeton:::update_project(proj$id, "Update Parcels", parcels = new_parcels)
    expect_equal(updated$metadata$parcels_count, 5)
  })
})

test_that("update_project errors on nonexistent project", {
  with_temp_projects({
    expect_error(nemeton:::update_project("fake_id", "Name"), "not found")
  })
})

# ==============================================================================
# list_recent_projects()
# ==============================================================================

test_that("list_recent_projects returns empty for no projects", {
  with_temp_projects({
    result <- nemeton:::list_recent_projects()
    expect_true(is.data.frame(result))
    expect_equal(nrow(result), 0)
  })
})

test_that("list_recent_projects returns project info", {
  with_temp_projects({
    nemeton:::create_project("Project A")
    Sys.sleep(0.2)
    nemeton:::create_project("Project B")

    result <- nemeton:::list_recent_projects()
    expect_true(is.data.frame(result))
    expect_equal(nrow(result), 2)
    expect_true("name" %in% names(result))
    # Both project names should be present
    expect_true(all(c("Project A", "Project B") %in% result$name))
  })
})

test_that("list_recent_projects respects limit", {
  with_temp_projects({
    for (i in 1:5) {
      nemeton:::create_project(paste("Project", i))
      Sys.sleep(0.05)
    }
    result <- nemeton:::list_recent_projects(limit = 3)
    expect_equal(nrow(result), 3)
  })
})

# ==============================================================================
# check_project_health()
# ==============================================================================

test_that("check_project_health reports valid project", {
  with_temp_projects({
    proj <- nemeton:::create_project("Healthy Project")
    health <- nemeton:::check_project_health(proj$id)
    expect_true(health$valid)
    expect_equal(length(health$issues), 0)
  })
})

test_that("check_project_health detects missing metadata", {
  with_temp_projects({
    proj <- nemeton:::create_project("Bad Project")
    unlink(file.path(proj$path, "metadata.json"))
    health <- nemeton:::check_project_health(proj$id)
    expect_false(health$valid)
    expect_true(any(grepl("metadata", health$issues)))
  })
})

test_that("check_project_health detects missing data directory", {
  with_temp_projects({
    proj <- nemeton:::create_project("No Data Dir")
    unlink(file.path(proj$path, "data"), recursive = TRUE)
    health <- nemeton:::check_project_health(proj$id)
    expect_false(health$valid)
    expect_true(any(grepl("data directory", health$issues)))
  })
})

test_that("check_project_health detects nonexistent project", {
  with_temp_projects({
    health <- nemeton:::check_project_health("nonexistent_id")
    expect_false(health$valid)
  })
})

# ==============================================================================
# delete_project()
# ==============================================================================

test_that("delete_project removes project directory", {
  with_temp_projects({
    proj <- nemeton:::create_project("To Delete")
    expect_true(dir.exists(proj$path))

    result <- nemeton:::delete_project(proj$id)
    expect_true(result)
    expect_false(dir.exists(proj$path))
  })
})

test_that("delete_project returns FALSE for nonexistent project", {
  with_temp_projects({
    result <- suppressWarnings(nemeton:::delete_project("nonexistent"))
    expect_false(result)
  })
})

# ==============================================================================
# update_project_status()
# ==============================================================================

test_that("update_project_status updates status field", {
  with_temp_projects({
    proj <- nemeton:::create_project("Status Test")
    nemeton:::update_project_status(proj$id, "computing")

    meta <- nemeton:::load_project_metadata(proj$id)
    expect_equal(meta$status, "computing")
  })
})

test_that("update_project_status rejects invalid status", {
  with_temp_projects({
    proj <- nemeton:::create_project("Invalid Status")
    expect_error(nemeton:::update_project_status(proj$id, "invalid_status"), "Invalid status")
  })
})

# ==============================================================================
# update_project_metadata()
# ==============================================================================

test_that("update_project_metadata updates arbitrary fields", {
  with_temp_projects({
    proj <- nemeton:::create_project("Meta Update")
    nemeton:::update_project_metadata(proj$id, list(
      indicators_computed = TRUE,
      parcels_count = 10L
    ))

    meta <- nemeton:::load_project_metadata(proj$id)
    expect_true(meta$indicators_computed)
    expect_equal(meta$parcels_count, 10)
  })
})

# ==============================================================================
# get_project_path()
# ==============================================================================

test_that("get_project_path returns NULL for empty/NULL id", {
  expect_null(nemeton:::get_project_path(NULL))
  expect_null(nemeton:::get_project_path(""))
})

test_that("get_project_path returns NULL for nonexistent project", {
  with_temp_projects({
    result <- nemeton:::get_project_path("nonexistent_12345")
    expect_null(result)
  })
})

# ==============================================================================
# save_cache_data() / load_cache_data()
# ==============================================================================

test_that("save_cache_data saves sf data with WKT geometry", {
  skip_if_not_installed("arrow")
  with_temp_projects({
    proj <- nemeton:::create_project("Cache Test")
    test_sf <- create_test_units(n_features = 2)

    result <- nemeton:::save_cache_data(proj$id, "bdforet", test_sf)
    expect_true(result)

    # Verify the parquet and CRS files exist
    cache_dir <- file.path(proj$path, "cache")
    expect_true(file.exists(file.path(cache_dir, "bdforet.parquet")))
    expect_true(file.exists(file.path(cache_dir, "bdforet_crs.json")))
  })
})

test_that("load_cache_data restores sf from WKT", {
  skip_if_not_installed("arrow")
  with_temp_projects({
    proj <- nemeton:::create_project("Cache SF Load")
    test_sf <- create_test_units(n_features = 2)

    nemeton:::save_cache_data(proj$id, "bdforet", test_sf)
    loaded <- nemeton:::load_cache_data(proj$id, "bdforet")

    # Should have geometry_wkt converted back to sf
    expect_true(is.data.frame(loaded))
    expect_equal(nrow(loaded), 2)
  })
})

test_that("save_cache_data handles non-sf data", {
  skip_if_not_installed("arrow")
  with_temp_projects({
    proj <- nemeton:::create_project("Cache DF")
    df <- data.frame(x = 1:3, y = 4:6)

    result <- nemeton:::save_cache_data(proj$id, "climate", df)
    expect_true(result)

    loaded <- nemeton:::load_cache_data(proj$id, "climate")
    expect_true(is.data.frame(loaded))
    expect_equal(nrow(loaded), 3)
  })
})

test_that("load_cache_data returns NULL when no cached data", {
  with_temp_projects({
    proj <- nemeton:::create_project("No Cache")
    result <- nemeton:::load_cache_data(proj$id, "bdforet")
    expect_null(result)
  })
})

test_that("load_cache_data returns NULL for nonexistent project", {
  with_temp_projects({
    result <- nemeton:::load_cache_data("nonexistent", "bdforet")
    expect_null(result)
  })
})
