# test-read_obs_pixel.R — exported reader for obs_pixel hypertable
#
# Pure unit tests cover argument validation and the canonical empty
# shape. Integration tests (skip_if_no_timescaledb) cover the SQL +
# join path, with rows inserted directly via DBI to keep the test
# offline w.r.t. STAC.

# ---- argument validation --------------------------------------------

test_that("read_obs_pixel rejects non-DBI con", {
  expect_error(read_obs_pixel("not-a-con", 1L), "DBI connection")
})

test_that("read_obs_pixel rejects bad zone_id", {
  fake_con <- structure(list(), class = "DBIConnection")
  expect_error(read_obs_pixel(fake_con, NA_integer_),
               "single non-NA integer")
  expect_error(read_obs_pixel(fake_con, c(1L, 2L)),
               "single non-NA integer")
  expect_error(read_obs_pixel(fake_con, "abc"),
               "single non-NA integer")
})

test_that("read_obs_pixel rejects bad plot_ids / bands", {
  fake_con <- structure(list(), class = "DBIConnection")
  expect_error(read_obs_pixel(fake_con, 1L, plot_ids = list("a")),
               "character vector or NULL")
  expect_error(read_obs_pixel(fake_con, 1L, bands = 42),
               "character vector or NULL")
})

test_that("read_obs_pixel rejects bad date bounds", {
  fake_con <- structure(list(), class = "DBIConnection")
  expect_error(read_obs_pixel(fake_con, 1L, date_from = c("a", "b")),
               "single Date or NULL")
  expect_error(read_obs_pixel(fake_con, 1L, date_from = "not-a-date"),
               "not coercible to Date")
  expect_error(
    read_obs_pixel(fake_con, 1L,
                   date_from = "2025-12-01", date_to = "2025-01-01"),
    "must be <= "
  )
})

test_that("read_obs_pixel short-circuits on empty filter vectors", {
  # plot_ids = character(0) and bands = character(0) mean "match
  # nothing" — we return an empty df without touching the DB.
  fake_con <- structure(list(), class = "DBIConnection")
  out1 <- read_obs_pixel(fake_con, 1L, plot_ids = character(0))
  out2 <- read_obs_pixel(fake_con, 1L, bands = character(0))
  for (out in list(out1, out2)) {
    expect_s3_class(out, "data.frame")
    expect_equal(nrow(out), 0L)
    expect_named(out, c("plot_id", "obs_date", "band", "value",
                        "cloud_pct", "source", "scene_id"))
  }
})

test_that(".empty_obs_pixel returns the canonical zero-row shape", {
  out <- nemeton:::.empty_obs_pixel()
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("plot_id", "obs_date", "band", "value",
                      "cloud_pct", "source", "scene_id"))
  expect_type(out$plot_id, "character")
  expect_s3_class(out$obs_date, "Date")
  expect_type(out$band, "character")
  expect_type(out$value, "double")
  expect_type(out$cloud_pct, "double")
  expect_type(out$source, "character")
  expect_type(out$scene_id, "character")
})


# ---- integration: round-trip via DBI direct INSERT ------------------

# Tiny helper: insert N obs_pixel rows for the given (plot_db_id, dates,
# bands, values) cartesian-ish. Keeps the DB-touching tests below tight.
.seed_obs <- function(con, plot_db_id, dates, bands, values,
                      source = "fake", cloud_pct = 5,
                      scene_prefix = "S2A_FAKE") {
  rows <- expand.grid(
    plot_id = plot_db_id, obs_date = dates, band = bands,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  rows$value     <- rep(values, length.out = nrow(rows))
  rows$cloud_pct <- cloud_pct
  rows$source    <- source
  rows$scene_id  <- sprintf("%s_%s", scene_prefix,
                            format(rows$obs_date, "%Y%m%d"))
  for (i in seq_len(nrow(rows))) {
    DBI::dbExecute(
      con,
      "INSERT INTO obs_pixel
         (plot_id, obs_date, band, value, cloud_pct, source, scene_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7)",
      params = list(
        as.integer(rows$plot_id[i]),
        format(rows$obs_date[i], "%Y-%m-%d"),
        rows$band[i],
        as.numeric(rows$value[i]),
        as.numeric(rows$cloud_pct),
        rows$source[i],
        rows$scene_id[i]
      )
    )
  }
  invisible(nrow(rows))
}

test_that("read_obs_pixel returns empty df for unknown / empty zone", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    out <- read_obs_pixel(con, zone_id = 9999L)
    expect_s3_class(out, "data.frame")
    expect_equal(nrow(out), 0L)
    expect_named(out, c("plot_id", "obs_date", "band", "value",
                        "cloud_pct", "source", "scene_id"))
  })
})

test_that("read_obs_pixel: full read returns every (plot, date, band)", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = c("P01", "P02"),
      geometry = sf::st_sfc(
        sf::st_point(c(4.5, 47.5)),
        sf::st_point(c(4.6, 47.6)),
        crs = 4326))
    zid <- register_monitoring_zone(con, "Z1", pol, placettes)

    db_ids <- DBI::dbGetQuery(con,
      "SELECT id, plot_id FROM plot WHERE zone_id = $1 ORDER BY plot_id",
      params = list(zid))
    .seed_obs(con,
              plot_db_id = db_ids$id,
              dates      = as.Date(c("2025-06-10", "2025-06-25")),
              bands      = c("NDVI", "NBR"),
              values     = c(0.7, 0.5, 0.65, 0.45,
                             0.72, 0.52, 0.68, 0.48))

    out <- read_obs_pixel(con, zid)
    expect_equal(nrow(out), 8L)             # 2 plots × 2 dates × 2 bands
    expect_setequal(unique(out$plot_id),  c("P01", "P02"))
    expect_setequal(unique(out$band),     c("NDVI", "NBR"))
    expect_setequal(unique(as.character(out$obs_date)),
                    c("2025-06-10", "2025-06-25"))

    # Stable sort: (plot_id, obs_date, band)
    expect_equal(
      out[, c("plot_id", "obs_date", "band")],
      out[order(out$plot_id, out$obs_date, out$band),
          c("plot_id", "obs_date", "band")],
      ignore_attr = TRUE
    )

    # Column types coerced.
    expect_s3_class(out$obs_date, "Date")
    expect_type(out$value, "double")
  })
})

test_that("read_obs_pixel filters by plot_ids, bands, and date bounds", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = c("P01", "P02", "P03"),
      geometry = sf::st_sfc(
        sf::st_point(c(4.5, 47.5)),
        sf::st_point(c(4.6, 47.6)),
        sf::st_point(c(4.7, 47.7)),
        crs = 4326))
    zid <- register_monitoring_zone(con, "Z2", pol, placettes)

    db_ids <- DBI::dbGetQuery(con,
      "SELECT id, plot_id FROM plot WHERE zone_id = $1 ORDER BY plot_id",
      params = list(zid))
    .seed_obs(con,
              plot_db_id = db_ids$id,
              dates      = as.Date(c("2025-05-01", "2025-06-15",
                                     "2025-07-30")),
              bands      = c("NDVI", "NBR", "B04"),
              values     = seq(0.1, 0.9, by = 0.1))

    # Plot filter.
    out <- read_obs_pixel(con, zid, plot_ids = c("P01", "P03"))
    expect_setequal(unique(out$plot_id), c("P01", "P03"))
    expect_false(any(out$plot_id == "P02"))

    # Band filter.
    out <- read_obs_pixel(con, zid, bands = "NDVI")
    expect_equal(unique(out$band), "NDVI")

    # Date filter (inclusive).
    out <- read_obs_pixel(con, zid,
                          date_from = "2025-06-01",
                          date_to   = "2025-06-30")
    expect_setequal(as.character(unique(out$obs_date)), "2025-06-15")

    # Combined.
    out <- read_obs_pixel(
      con, zid,
      plot_ids  = "P02",
      bands     = c("NDVI", "NBR"),
      date_from = "2025-05-01",
      date_to   = "2025-06-30"
    )
    expect_setequal(unique(out$plot_id), "P02")
    expect_setequal(unique(out$band), c("NDVI", "NBR"))
    expect_true(all(out$obs_date <= as.Date("2025-06-30")))
    expect_true(all(out$obs_date >= as.Date("2025-05-01")))
  })
})

test_that("read_obs_pixel does not leak rows from sibling zones", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))

    # Two zones, same plot_id "P01" in each → DB ids differ but the
    # human plot_id collides. read_obs_pixel must filter by zone via
    # the JOIN.
    pa <- sf::st_sf(
      plot_id = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid_a <- register_monitoring_zone(con, "ZoneA", pol, pa)
    zid_b <- register_monitoring_zone(con, "ZoneB", pol, pa)

    db_a <- DBI::dbGetQuery(con,
      "SELECT id FROM plot WHERE zone_id = $1", params = list(zid_a))$id
    db_b <- DBI::dbGetQuery(con,
      "SELECT id FROM plot WHERE zone_id = $1", params = list(zid_b))$id
    expect_false(db_a == db_b)

    .seed_obs(con, db_a, as.Date("2025-06-10"), "NDVI", 0.10,
              scene_prefix = "ZA")
    .seed_obs(con, db_b, as.Date("2025-06-10"), "NDVI", 0.99,
              scene_prefix = "ZB")

    out_a <- read_obs_pixel(con, zid_a)
    out_b <- read_obs_pixel(con, zid_b)
    expect_equal(out_a$value, 0.10)
    expect_equal(out_b$value, 0.99)
    expect_match(out_a$scene_id, "^ZA_")
    expect_match(out_b$scene_id, "^ZB_")
  })
})
