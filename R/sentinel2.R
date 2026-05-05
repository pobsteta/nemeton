#' Sentinel-2 STAC Search Helpers (E6 monitoring)
#'
#' @description
#' Thin STAC clients for Sentinel-2 L2A imagery. Two backends are
#' supported, with automatic failover:
#'
#' \itemize{
#'   \item \strong{CDSE} — Copernicus Data Space Ecosystem (priority,
#'     ADR-008 souveraineté UE).
#'   \item \strong{Planetary Computer} — Microsoft (fallback,
#'     resilience).
#' }
#'
#' Both endpoints accept anonymous STAC search; PC additionally signs
#' the COG hrefs with a SAS token before returning them so that
#' `terra::rast(href)` reads work without further authentication.
#'
#' @name sentinel2_stac
NULL


.assert_httr2 <- function() {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg httr2} required.")
  }
}


#' Search Sentinel-2 L2A scenes via STAC
#'
#' Façade around CDSE (priority) and Planetary Computer (fallback).
#' Returns a tibble with one row per scene, holding the COG hrefs for
#' bands B04, B08, B12 (used to derive NDVI and NBR downstream).
#'
#' @param zone An sf or sfc object covering the area of interest.
#'   Re-projected to WGS84 internally.
#' @param start,end Date or character `"YYYY-MM-DD"`.
#' @param max_cloud Numeric. Maximum scene cloud cover in percent.
#'   Default 20.
#' @param source Character vector. Order in which to try backends.
#'   Default `c("cdse", "pc")`.
#' @param limit Integer. Maximum number of scenes to return per
#'   backend call. Default 100.
#'
#' @return A tibble with columns `scene_id`, `obs_date`,
#'   `cloud_pct`, `href_B04`, `href_B08`, `href_B12`, `source`. Empty
#'   tibble (0 rows) when no scene matches.
#'
#' @examples
#' \dontrun{
#' library(sf)
#' aoi <- st_as_sfc(st_bbox(c(xmin = 4.0, ymin = 47.5,
#'                            xmax = 4.5, ymax = 48.0), crs = 4326))
#' scenes <- stac_search_s2(aoi, "2025-06-01", "2025-09-30")
#' }
#'
#' @export
stac_search_s2 <- function(zone,
                           start, end,
                           max_cloud = 20,
                           source = c("cdse", "pc"),
                           limit = 100L) {
  .assert_httr2()
  source <- match.arg(source, c("cdse", "pc"), several.ok = TRUE)

  bbox <- .zone_to_bbox4326(zone)
  start <- as.Date(start); end <- as.Date(end)
  if (end < start) cli::cli_abort("{.arg end} ({end}) must be on or after {.arg start} ({start}).")

  for (s in source) {
    res <- tryCatch(
      switch(s,
        cdse = stac_search_s2_cdse(bbox, start, end, max_cloud, limit),
        pc   = stac_search_s2_pc(bbox, start, end, max_cloud, limit)
      ),
      error = function(e) {
        cli::cli_warn("STAC backend {.val {s}} failed: {conditionMessage(e)}")
        NULL
      }
    )
    if (!is.null(res) && nrow(res) > 0) {
      return(res)
    }
  }
  # All backends exhausted: return empty tibble with the canonical schema.
  .empty_scene_tibble()
}


#' @rdname sentinel2_stac
#' @param bbox Numeric length 4: c(xmin, ymin, xmax, ymax) in WGS84.
#' @export
stac_search_s2_cdse <- function(bbox, start, end, max_cloud = 20, limit = 100L) {
  .assert_httr2()
  body <- list(
    collections = list("SENTINEL-2"),
    bbox        = as.numeric(bbox),
    datetime    = sprintf("%sT00:00:00Z/%sT23:59:59Z", start, end),
    limit       = as.integer(limit),
    query       = list(
      "eo:cloud_cover" = list(lte = as.numeric(max_cloud)),
      "productType"     = list(eq = "S2MSI2A")
    )
  )
  resp <- httr2::request("https://catalogue.dataspace.copernicus.eu/stac/search") |>
    httr2::req_method("POST") |>
    httr2::req_headers(`Content-Type` = "application/json",
                       Accept         = "application/json") |>
    httr2::req_body_json(body) |>
    httr2::req_timeout(60) |>
    httr2::req_perform()

  features <- httr2::resp_body_json(resp)$features %||% list()
  .features_to_tibble(features, source = "cdse")
}


#' @rdname sentinel2_stac
#' @export
stac_search_s2_pc <- function(bbox, start, end, max_cloud = 20, limit = 100L) {
  .assert_httr2()
  body <- list(
    collections = list("sentinel-2-l2a"),
    bbox        = as.numeric(bbox),
    datetime    = sprintf("%s/%s", start, end),
    limit       = as.integer(limit),
    query       = list(
      "eo:cloud_cover" = list(lte = as.numeric(max_cloud))
    )
  )
  resp <- httr2::request("https://planetarycomputer.microsoft.com/api/stac/v1/search") |>
    httr2::req_method("POST") |>
    httr2::req_headers(`Content-Type` = "application/json",
                       Accept         = "application/json") |>
    httr2::req_body_json(body) |>
    httr2::req_timeout(60) |>
    httr2::req_perform()

  features <- httr2::resp_body_json(resp)$features %||% list()
  out <- .features_to_tibble(features, source = "pc")
  if (nrow(out) > 0) {
    out$href_B04 <- vapply(out$href_B04, .pc_sign_url, character(1))
    out$href_B08 <- vapply(out$href_B08, .pc_sign_url, character(1))
    out$href_B12 <- vapply(out$href_B12, .pc_sign_url, character(1))
  }
  out
}


# ---- Internal helpers ------------------------------------------------

.zone_to_bbox4326 <- function(zone) {
  if (inherits(zone, c("sf", "sfc"))) {
    zone <- sf::st_transform(zone, 4326)
    bb <- sf::st_bbox(zone)
    return(c(bb["xmin"], bb["ymin"], bb["xmax"], bb["ymax"]))
  }
  if (is.numeric(zone) && length(zone) == 4) {
    return(unname(zone))
  }
  cli::cli_abort("{.arg zone} must be an sf/sfc object or a length-4 bbox.")
}

.empty_scene_tibble <- function() {
  data.frame(
    scene_id  = character(0),
    obs_date  = as.Date(character(0)),
    cloud_pct = numeric(0),
    href_B04  = character(0),
    href_B08  = character(0),
    href_B12  = character(0),
    source    = character(0),
    stringsAsFactors = FALSE
  )
}

.features_to_tibble <- function(features, source) {
  if (!length(features)) return(.empty_scene_tibble())
  rows <- lapply(features, function(ft) {
    props  <- ft$properties %||% list()
    assets <- ft$assets     %||% list()
    href <- function(name) {
      a <- assets[[name]]
      if (is.null(a)) "" else (a$href %||% "")
    }
    list(
      scene_id  = ft$id %||% NA_character_,
      obs_date  = .parse_stac_datetime(props$datetime %||% props$start_datetime),
      cloud_pct = as.numeric(props$`eo:cloud_cover` %||% NA_real_),
      href_B04  = href("B04"),
      href_B08  = href("B08"),
      href_B12  = href("B12"),
      source    = source
    )
  })
  out <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
  out <- out[!is.na(out$obs_date) &
             nzchar(out$href_B04) &
             nzchar(out$href_B08) &
             nzchar(out$href_B12), , drop = FALSE]
  rownames(out) <- NULL
  out
}

.parse_stac_datetime <- function(dt) {
  if (is.null(dt) || is.na(dt) || !nzchar(dt)) return(as.Date(NA))
  as.Date(substr(dt, 1, 10))
}

.pc_sign_url <- function(url) {
  if (!nzchar(url)) return(url)
  resp <- tryCatch(
    httr2::request("https://planetarycomputer.microsoft.com/api/sas/v1/sign") |>
      httr2::req_url_query(href = url) |>
      httr2::req_timeout(20) |>
      httr2::req_perform(),
    error = function(e) {
      # Surface the failure so callers can tell the URL is unsigned (and
      # Azure will return 409). Silent fallback used to mask rate-limit
      # / auth / network errors and made debugging the 409 wave painful.
      cli::cli_warn("PC sign failed: {conditionMessage(e)}")
      NULL
    }
  )
  if (is.null(resp)) return(url)
  signed <- tryCatch(httr2::resp_body_json(resp)$href, error = function(e) {
    cli::cli_warn("PC sign returned malformed body: {conditionMessage(e)}")
    NULL
  })
  if (is.null(signed) || !nzchar(signed)) url else signed
}
