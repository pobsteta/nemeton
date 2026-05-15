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


# Treat 429 + 5xx as transient (worth retrying). Default `httr2`
# `is_transient` only covers 429 + 503; 504 (Gateway Timeout) is a
# common Planetary Computer hiccup on big AOIs / wide date ranges
# and absolutely should be retried.
.is_stac_transient <- function(resp) {
  httr2::resp_status(resp) %in% c(429, 500, 502, 503, 504)
}


# Wrap an `httr2_request` with the project-wide STAC retry policy.
# Max-tries default is 4 (≈ 14 s of cumulative backoff in the worst
# case: 2 + 4 + 8 seconds between attempts). Override with the env
# var `NEMETON_STAC_MAX_TRIES` (integer) for power users or CI.
.with_stac_retry <- function(req, max_tries = NULL) {
  if (is.null(max_tries)) {
    mt <- suppressWarnings(
      as.integer(Sys.getenv("NEMETON_STAC_MAX_TRIES", "4"))
    )
    max_tries <- if (is.na(mt) || mt < 1L) 4L else mt
  }
  req |>
    httr2::req_retry(
      max_tries    = max_tries,
      is_transient = .is_stac_transient,
      backoff      = function(i) min(60, 2^i)
    )
}


#' Search Sentinel-2 L2A scenes via STAC
#'
#' Façade around CDSE (priority) and Planetary Computer (fallback).
#' Returns a tibble with one row per scene, holding the COG hrefs for
#' bands B04, B08, B12 (used to derive NDVI and NBR downstream).
#'
#' Each backend request is automatically retried on transient HTTP
#' errors (429, 500, 502, 503, 504) with exponential backoff capped
#' at 60 s. Default budget is 4 attempts per backend; override with
#' the `NEMETON_STAC_MAX_TRIES` environment variable. When every
#' configured backend exhausts its retry budget the function emits
#' a single \dQuote{All STAC backends failed} warning (in addition
#' to the per-backend warnings) and returns the canonical empty
#' tibble — callers (e.g. `nemetonshiny`) can use that aggregated
#' warning to render one toast instead of stacking one per backend.
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

  failures <- character(0)
  for (s in source) {
    res <- tryCatch(
      switch(s,
        cdse = stac_search_s2_cdse(bbox, start, end, max_cloud, limit),
        pc   = stac_search_s2_pc(bbox, start, end, max_cloud, limit)
      ),
      error = function(e) {
        msg <- conditionMessage(e)
        failures[[s]] <<- msg
        cli::cli_warn("STAC backend {.val {s}} failed: {msg}")
        NULL
      }
    )
    if (!is.null(res) && nrow(res) > 0) {
      return(res)
    }
  }
  # All backends exhausted: surface a single, actionable warning so
  # the UI can render one toast instead of stacking the per-backend
  # ones. The caller still sees the per-backend warnings above for
  # debugging.
  if (length(failures)) {
    cli::cli_warn(c(
      "All STAC backends ({.val {names(failures)}}) failed after retries.",
      i = "This is usually transient (504 Gateway Timeout on Planetary Computer, EU peak hours on CDSE). Retry in a few minutes or narrow the date range."
    ))
  }
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
    .with_stac_retry() |>
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
    .with_stac_retry() |>
    httr2::req_perform()

  features <- httr2::resp_body_json(resp)$features %||% list()
  out <- .features_to_tibble(features, source = "pc")
  if (nrow(out) > 0) {
    # Batched-token signing: one HTTP call gets a SAS query string for
    # the whole collection, then we append it to every href. Replaces
    # the per-href `/api/sas/v1/sign` loop that hit HTTP 429 as soon
    # as a search returned more than ~10 scenes (each scene = 3 bands).
    token <- .pc_collection_token("sentinel-2-l2a")
    if (!is.null(token)) {
      out$href_B04 <- vapply(out$href_B04, .pc_apply_token,
                             character(1), token)
      out$href_B08 <- vapply(out$href_B08, .pc_apply_token,
                             character(1), token)
      out$href_B12 <- vapply(out$href_B12, .pc_apply_token,
                             character(1), token)
    }
    # On token failure: hrefs stay unsigned. Azure will return 409;
    # the user already saw the "PC token fetch failed" warning above
    # so the cause is visible.
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
      .with_stac_retry() |>
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


# Per-process cache of SAS tokens, keyed by collection. Each entry is
# a list(token = "<query string>", expiry = POSIXct). The token is
# valid for ~30 minutes per Planetary Computer's documented contract.
.pc_token_cache <- new.env(parent = emptyenv())


# Drop the cached SAS token for a collection so the next
# `.pc_collection_token()` call hits the network again. Used by the
# 403/401 auto-retry path in `.terra_rast_with_pc_retry()`: when an
# already-signed href starts returning Forbidden, the most likely
# cause is a token that expired between STAC search and band read
# (long ingestions outrun the 30-minute window). Invalidating the
# cache + re-signing the href fixes the request.
.pc_invalidate_token <- function(collection) {
  if (!nzchar(collection)) return(invisible())
  if (exists(collection, envir = .pc_token_cache, inherits = FALSE)) {
    rm(list = collection, envir = .pc_token_cache, inherits = FALSE)
  }
  invisible()
}


# Strip the current SAS query string from a Planetary Computer href
# and re-apply a freshly-fetched one. Returns NULL when the token
# refresh itself failed (network down, 5xx after retries…) so the
# caller can decide whether to abort or fall back to the unsigned URL.
.pc_resign_href <- function(href, collection = "sentinel-2-l2a") {
  if (!nzchar(href)) return(href)
  token <- .pc_collection_token(collection)
  if (is.null(token)) return(NULL)
  base_href <- sub("\\?.*", "", href)
  .pc_apply_token(base_href, token)
}


# Parse the SAS token's `se=` (expiry) query parameter from a PC blob
# URL and return it as a POSIXct (UTC), or NA if absent / unparseable.
# Used by `.pc_ensure_fresh_href()` to decide whether to refresh
# proactively before issuing a request.
.pc_href_expires_at <- function(href) {
  if (!is.character(href) || length(href) != 1L || is.na(href) ||
      !nzchar(href)) {
    return(as.POSIXct(NA, tz = "UTC"))
  }
  m <- regmatches(href, regexpr("[?&]se=[^&]+", href, perl = TRUE))
  if (!length(m) || !nzchar(m)) return(as.POSIXct(NA, tz = "UTC"))
  raw <- utils::URLdecode(sub("^[?&]se=", "", m))
  out <- tryCatch(
    as.POSIXct(raw, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    error = function(e) NA
  )
  if (length(out) != 1L || is.na(out)) {
    return(as.POSIXct(NA, tz = "UTC"))
  }
  out
}


# Proactively refresh a Planetary Computer signed href if its embedded
# SAS token (`se=...`) is within `grace_seconds` of expiring. No-op on
# hrefs that don't look like signed PC blob URLs (other STAC backends,
# unsigned fallbacks, etc.).
#
# This is the v0.22.1 fix: previously, hrefs were signed once at STAC
# search time (`stac_search_s2_pc`) and baked into `scenes_df`, then
# consumed many minutes later during the ingestion loop. On long runs
# (> 30 min) every remaining scene hit a 403 first, then was rescued
# by `.terra_rast_with_pc_retry`'s reactive refresh — costly and
# noisy. The proactive check avoids the 403 in the first place; the
# reactive path stays as a safety net for clock skew / unusual
# expiry formats.
#
# On refresh failure (`.pc_resign_href` returns NULL because the
# token endpoint itself is down), we fall back to the original href.
# The downstream retry helper will then either succeed if the cached
# token in `scenes_df` is still good, or surface a clean PC token
# fetch failure warning.
.pc_ensure_fresh_href <- function(href,
                                  collection    = "sentinel-2-l2a",
                                  grace_seconds = 60L) {
  if (!is.character(href) || length(href) != 1L || is.na(href) ||
      !nzchar(href)) return(href)
  # Only act on signed PC blob URLs
  if (!grepl("blob\\.core\\.windows\\.net", href) ||
      !grepl("sig=", href, fixed = TRUE)) return(href)
  expires <- .pc_href_expires_at(href)
  if (is.na(expires)) {
    # Unsignable expiry — defensive refresh
    refreshed <- .pc_resign_href(href, collection)
    return(refreshed %||% href)
  }
  if (as.numeric(expires - Sys.time(), units = "secs") > grace_seconds) {
    return(href)   # token still has time
  }
  refreshed <- .pc_resign_href(href, collection)
  refreshed %||% href
}


#' Fetch a SAS token for a Planetary Computer collection
#'
#' Calls `/api/sas/v1/token/{collection}` once and caches the result
#' until ~`grace_seconds` before its documented expiry. Subsequent
#' calls in the same R session return the cached token without
#' another round-trip — the previous per-href `/api/sas/v1/sign`
#' implementation triggered HTTP 429 the moment a STAC search
#' returned more than a handful of scenes.
#'
#' @param collection Character. Planetary Computer collection name
#'   (e.g. `"sentinel-2-l2a"`).
#' @param grace_seconds Integer. Refresh the token this many seconds
#'   before the announced expiry to avoid races at the boundary.
#' @return Character. The SAS query string (without leading `?`),
#'   or `NULL` on any failure (network down, 5xx, malformed body).
#' @noRd
.pc_collection_token <- function(collection,
                                 grace_seconds = 60L) {
  if (!nzchar(collection)) return(NULL)
  now <- Sys.time()
  cached <- .pc_token_cache[[collection]]
  if (!is.null(cached) &&
      !is.null(cached$expiry) &&
      as.numeric(cached$expiry - now, units = "secs") > grace_seconds) {
    return(cached$token)
  }
  url <- sprintf(
    "https://planetarycomputer.microsoft.com/api/sas/v1/token/%s",
    utils::URLencode(collection, reserved = TRUE)
  )
  resp <- tryCatch(
    httr2::request(url) |>
      httr2::req_timeout(20) |>
      .with_stac_retry() |>
      httr2::req_perform(),
    error = function(e) {
      cli::cli_warn("PC token fetch failed: {conditionMessage(e)}")
      NULL
    }
  )
  if (is.null(resp)) return(NULL)
  body <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
  if (is.null(body) || is.null(body$token) || !nzchar(body$token)) {
    cli::cli_warn("PC token response malformed (collection {.val {collection}})")
    return(NULL)
  }
  expiry <- tryCatch(
    as.POSIXct(body$`msft:expiry`,
               format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    error = function(e) NA
  )
  # Default to 25 min if expiry is unparseable — PC tokens last
  # 30 min, so we retain a 5 min margin even without server hint.
  if (is.na(expiry) || length(expiry) != 1L) expiry <- now + 25 * 60
  .pc_token_cache[[collection]] <- list(token = body$token,
                                        expiry = expiry)
  body$token
}


#' Append a SAS token to a Planetary Computer href
#'
#' The token returned by `/api/sas/v1/token/{collection}` is a
#' query string of the form `se=...&sp=...&sig=...` (PC docs say it
#' may or may not start with `?`; we normalise both shapes). When
#' the href already carries query parameters (rare for Sentinel-2
#' blob URLs but possible) we append with `&` instead of `?`.
#'
#' @param href Character. Blob URL.
#' @param token Character. SAS query string from
#'   [.pc_collection_token()].
#' @return Character. The signed URL, or the original `href`
#'   unchanged when either argument is empty.
#' @noRd
.pc_apply_token <- function(href, token) {
  if (!nzchar(href) || is.null(token) || !nzchar(token)) return(href)
  q <- sub("^\\?", "", token)
  sep <- if (grepl("?", href, fixed = TRUE)) "&" else "?"
  paste0(href, sep, q)
}
