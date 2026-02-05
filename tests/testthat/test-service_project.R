# Tests for Project Service
# Phase 3: Project management

test_that("get_projects_root creates directory if missing", {
  # Use temp directory for testing
  temp_dir <- file.path(tempdir(), "nemeton_test_projects")
  unlink(temp_dir, recursive = TRUE)

  withr::local_options(list(
    nemeton.project_dir = temp_dir
  ))

  # Mock get_app_options
  with_mocked_bindings(
    get_app_options = function() list(project_dir = temp_dir),
    {
      root <- nemeton:::get_projects_root()
      expect_true(dir.exists(root))
    }
  )

  unlink(temp_dir, recursive = TRUE)
})

test_that("create_project validates name", {
  expect_error(
    nemeton:::create_project(name = ""),
    regexp = "required"
  )

  expect_error(
    nemeton:::create_project(name = NULL),
    regexp = "required"
  )

  expect_error(
    nemeton:::create_project(name = paste(rep("a", 101), collapse = "")),
    regexp = "100 characters"
  )
})

test_that("create_project validates description length", {
  expect_error(
    nemeton:::create_project(
      name = "Test",
      description = paste(rep("a", 501), collapse = "")
    ),
    regexp = "500 characters"
  )
})

test_that("create_project validates owner length", {
  expect_error(
    nemeton:::create_project(
      name = "Test",
      owner = paste(rep("a", 101), collapse = "")
    ),
    regexp = "100 characters"
  )
})

test_that("create_project creates project structure", {
  temp_dir <- file.path(tempdir(), "nemeton_test_projects")
  unlink(temp_dir, recursive = TRUE)
  dir.create(temp_dir, recursive = TRUE)

  with_mocked_bindings(
    get_app_options = function() list(project_dir = temp_dir),
    {
      project <- nemeton:::create_project(
        name = "Test Project",
        description = "Test description",
        owner = "Test Owner"
      )

      expect_type(project, "list")
      expect_true("id" %in% names(project))
      expect_true("path" %in% names(project))
      expect_true("metadata" %in% names(project))

      # Check directories created
      expect_true(dir.exists(project$path))
      expect_true(dir.exists(file.path(project$path, "data")))
      expect_true(dir.exists(file.path(project$path, "cache")))
      expect_true(dir.exists(file.path(project$path, "exports")))

      # Check metadata file
      expect_true(file.exists(file.path(project$path, "metadata.json")))
    }
  )

  unlink(temp_dir, recursive = TRUE)
})

test_that("create_project sets correct metadata", {
  temp_dir <- file.path(tempdir(), "nemeton_test_projects")
  unlink(temp_dir, recursive = TRUE)
  dir.create(temp_dir, recursive = TRUE)

  with_mocked_bindings(
    get_app_options = function() list(project_dir = temp_dir),
    {
      project <- nemeton:::create_project(
        name = "My Project",
        description = "My description",
        owner = "John Doe"
      )

      expect_equal(project$metadata$name, "My Project")
      expect_equal(project$metadata$description, "My description")
      expect_equal(project$metadata$owner, "John Doe")
      expect_equal(project$metadata$status, "draft")
      expect_equal(project$metadata$parcels_count, 0L)
    }
  )

  unlink(temp_dir, recursive = TRUE)
})

test_that("update_project_status validates status", {
  expect_error(
    nemeton:::update_project_status("fake_id", "invalid_status"),
    regexp = "Invalid status"
  )
})

test_that("update_project_status accepts valid statuses", {
  temp_dir <- file.path(tempdir(), "nemeton_test_projects")
  unlink(temp_dir, recursive = TRUE)
  dir.create(temp_dir, recursive = TRUE)

  with_mocked_bindings(
    get_app_options = function() list(project_dir = temp_dir),
    {
      project <- nemeton:::create_project(name = "Test")

      # Should not error for valid statuses
      for (status in c("draft", "downloading", "computing", "completed", "error")) {
        expect_no_error(
          nemeton:::update_project_status(project$id, status)
        )
      }
    }
  )

  unlink(temp_dir, recursive = TRUE)
})

test_that("load_project_metadata returns metadata", {
  temp_dir <- file.path(tempdir(), "nemeton_test_projects")
  unlink(temp_dir, recursive = TRUE)
  dir.create(temp_dir, recursive = TRUE)

  with_mocked_bindings(
    get_app_options = function() list(project_dir = temp_dir),
    {
      project <- nemeton:::create_project(name = "Test Metadata")

      metadata <- nemeton:::load_project_metadata(project$id)

      expect_type(metadata, "list")
      expect_equal(metadata$name, "Test Metadata")
    }
  )

  unlink(temp_dir, recursive = TRUE)
})

test_that("load_project_metadata returns NULL for missing project", {
  with_mocked_bindings(
    get_app_options = function() list(project_dir = tempdir()),
    {
      result <- nemeton:::load_project_metadata("nonexistent_project")
      expect_null(result)
    }
  )
})

test_that("list_recent_projects returns empty data.frame when no projects", {
  temp_dir <- file.path(tempdir(), "nemeton_empty_projects")
  unlink(temp_dir, recursive = TRUE)
  dir.create(temp_dir, recursive = TRUE)

  with_mocked_bindings(
    get_app_options = function() list(project_dir = temp_dir),
    {
      projects <- nemeton:::list_recent_projects()

      expect_s3_class(projects, "data.frame")
      expect_equal(nrow(projects), 0)
      expect_true("id" %in% names(projects))
      expect_true("name" %in% names(projects))
      expect_true("is_corrupted" %in% names(projects))
    }
  )

  unlink(temp_dir, recursive = TRUE)
})

test_that("list_recent_projects returns projects sorted by date", {
  temp_dir <- file.path(tempdir(), "nemeton_test_projects")
  unlink(temp_dir, recursive = TRUE)
  dir.create(temp_dir, recursive = TRUE)

  with_mocked_bindings(
    get_app_options = function() list(project_dir = temp_dir),
    {
      # Create projects with delay (1 second to ensure different timestamps)
      p1 <- nemeton:::create_project(name = "First")
      Sys.sleep(1.1)
      p2 <- nemeton:::create_project(name = "Second")

      projects <- nemeton:::list_recent_projects()

      expect_equal(nrow(projects), 2)
      # Most recent first (sorted by updated_at descending)
      expect_equal(projects$name[1], "Second")
      expect_equal(projects$name[2], "First")
    }
  )

  unlink(temp_dir, recursive = TRUE)
})

test_that("check_project_health detects missing metadata", {
  temp_dir <- file.path(tempdir(), "nemeton_test_projects")
  unlink(temp_dir, recursive = TRUE)
  dir.create(temp_dir, recursive = TRUE)

  # Create project directory without metadata
  fake_project <- file.path(temp_dir, "fake_project")
  dir.create(fake_project)

  with_mocked_bindings(
    get_app_options = function() list(project_dir = temp_dir),
    {
      health <- nemeton:::check_project_health("fake_project")

      expect_false(health$valid)
      expect_true(any(grepl("metadata", health$issues, ignore.case = TRUE)))
    }
  )

  unlink(temp_dir, recursive = TRUE)
})

test_that("check_project_health returns valid for good project", {
  temp_dir <- file.path(tempdir(), "nemeton_test_projects")
  unlink(temp_dir, recursive = TRUE)
  dir.create(temp_dir, recursive = TRUE)

  with_mocked_bindings(
    get_app_options = function() list(project_dir = temp_dir),
    {
      project <- nemeton:::create_project(name = "Healthy Project")

      health <- nemeton:::check_project_health(project$id)

      expect_true(health$valid)
      expect_length(health$issues, 0)
    }
  )

  unlink(temp_dir, recursive = TRUE)
})

test_that("delete_project removes project directory", {
  temp_dir <- file.path(tempdir(), "nemeton_test_projects")
  unlink(temp_dir, recursive = TRUE)
  dir.create(temp_dir, recursive = TRUE)

  with_mocked_bindings(
    get_app_options = function() list(project_dir = temp_dir),
    {
      project <- nemeton:::create_project(name = "To Delete")

      expect_true(dir.exists(project$path))

      result <- nemeton:::delete_project(project$id)

      expect_true(result)
      expect_false(dir.exists(project$path))
    }
  )

  unlink(temp_dir, recursive = TRUE)
})

test_that("delete_project returns FALSE for nonexistent project", {
  with_mocked_bindings(
    get_app_options = function() list(project_dir = tempdir()),
    {
      result <- nemeton:::delete_project("nonexistent_id")
      expect_false(result)
    }
  )
})

test_that("get_project_path returns NULL for invalid ID", {
  with_mocked_bindings(
    get_app_options = function() list(project_dir = tempdir()),
    {
      expect_null(nemeton:::get_project_path(NULL))
      expect_null(nemeton:::get_project_path(""))
      expect_null(nemeton:::get_project_path("nonexistent"))
    }
  )
})
