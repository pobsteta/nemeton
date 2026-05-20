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
#' @param limit Integer. Maximum total number of scenes to return
#'   per backend (across all pagination pages). Default `10000L` —
#'   covers ~10 years of Sentinel-2 revisit at one tile. The
#'   backend page size is fixed internally at 1000 (the maximum
#'   accepted by both CDSE and Planetary Computer); pagination
#'   follows the STAC `links[rel=next]` convention until the
#'   `limit` cap is hit or the backend stops returning a `next`
#'   link. Use a smaller value to truncate (e.g. `limit = 50` for
#'   a quick preview).
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
                           limit = 10000L) {
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
      deduped   <- .dedup_s2_reprocessed(res)
      n_dropped <- nrow(res) - nrow(deduped)
      if (n_dropped > 0L) {
        cli::cli_alert_info(
          "Dropped {n_dropped} Sentinel-2 reprocessing duplicate{?s} (kept the latest processing baseline)."
        )
      }
      return(deduped)
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


# Per-page size requested from the STAC backend. Both CDSE and PC
# accept up to 1000 features per response; smaller values multiply
# the number of round-trips for the same total. Override via the
# env var `NEMETON_STAC_PAGE_SIZE` for backends with stricter caps.
.stac_page_size <- function() {
  v <- suppressWarnings(
    as.integer(Sys.getenv("NEMETON_STAC_PAGE_SIZE", "1000"))
  )
  if (is.na(v) || v < 1L) 1000L else v
}

# Maximum number of pagination pages to fetch from a single
# backend, regardless of `limit`. Guards against runaway loops
# from a buggy backend that keeps returning a `next` link with
# the same body. 100 pages × 1000 features = 100k scenes
# (effectively unbounded for realistic AOIs).
.STAC_MAX_PAGES <- 100L

# Generic STAC paginator. Both CDSE and PC follow the STAC API
# pagination extension: each response carries a `links` array
# and a `next` link points at the following page. The link can
# be GET (token baked into the href) or POST (full search body
# echoed back with a `token` field added). This helper handles
# both, accumulates features, and stops when:
#   - no `next` link is returned,
#   - the page yields 0 features (defensive),
#   - the cumulative count reaches `max_total`,
#   - we hit the `.STAC_MAX_PAGES` safety cap.
.stac_search_paginate <- function(initial_url,
                                  initial_body,
                                  max_total = 10000L,
                                  request_timeout = 60L) {
  features <- list()
  next_url    <- initial_url
  next_method <- "POST"
  next_body   <- initial_body

  for (page_no in seq_len(.STAC_MAX_PAGES)) {
    req <- httr2::request(next_url) |>
      httr2::req_method(next_method) |>
      httr2::req_headers(`Content-Type` = "application/json",
                         Accept         = "application/json") |>
      httr2::req_timeout(request_timeout) |>
      .with_stac_retry()
    if (identical(next_method, "POST") && !is.null(next_body)) {
      req <- httr2::req_body_json(req, next_body)
    }
    resp <- httr2::req_perform(req)
    parsed <- httr2::resp_body_json(resp)
    page_features <- parsed$features %||% list()
    if (!length(page_features)) break

    features <- c(features, page_features)
    if (length(features) >= max_total) {
      features <- features[seq_len(max_total)]
      return(features)
    }

    nl <- NULL
    for (lnk in (parsed$links %||% list())) {
      if (identical(lnk$rel, "next")) { nl <- lnk; break }
    }
    if (is.null(nl) || !nzchar(nl$href %||% "")) break

    next_url    <- nl$href
    next_method <- toupper(nl$method %||% "GET")
    next_body   <- if (identical(next_method, "POST"))
                     nl$body %||% nl$merge %||% NULL
                   else NULL

    if (page_no == .STAC_MAX_PAGES) {
      cli::cli_warn(c(
        "STAC pagination hit the {.STAC_MAX_PAGES}-page safety cap.",
        i = "Result may be truncated. Narrow {.arg start}/{.arg end} or lower {.arg max_cloud}."
      ))
    }
  }
  features
}


#' @rdname sentinel2_stac
#' @param bbox Numeric length 4: c(xmin, ymin, xmax, ymax) in WGS84.
#' @export
stac_search_s2_cdse <- function(bbox, start, end, max_cloud = 20, limit = 10000L) {
  .assert_httr2()
  body <- list(
    collections = list("SENTINEL-2"),
    bbox        = as.numeric(bbox),
    datetime    = sprintf("%sT00:00:00Z/%sT23:59:59Z", start, end),
    limit       = .stac_page_size(),
    query       = list(
      "eo:cloud_cover" = list(lte = as.numeric(max_cloud)),
      "productType"     = list(eq = "S2MSI2A")
    )
  )
  features <- .stac_search_paginate(
    initial_url  = "https://catalogue.dataspace.copernicus.eu/stac/search",
    initial_body = body,
    max_total    = as.integer(limit)
  )
  .features_to_tibble(features, source = "cdse")
}


#' @rdname sentinel2_stac
#' @export
stac_search_s2_pc <- function(bbox, start, end, max_cloud = 20, limit = 10000L) {
  .assert_httr2()
  body <- list(
    collections = list("sentinel-2-l2a"),
    bbox        = as.numeric(bbox),
    datetime    = sprintf("%s/%s", start, end),
    limit       = .stac_page_size(),
    query       = list(
      "eo:cloud_cover" = list(lte = as.numeric(max_cloud))
    )
  )
  features <- .stac_search_paginate(
    initial_url  = "https://planetarycomputer.microsoft.com/api/stac/v1/search",
    initial_body = body,
    max_total    = as.integer(limit)
  )
  out <- .features_to_tibble(features, source = "pc")
  if (nrow(out) > 0) {
    # Batched-token signing: one HTTP call gets a SAS query string for
    # the whole collection, then we append it to every href. Replaces
    # the per-href `/api/sas/v1/sign` loop that hit HTTP 429 as soon
    # as a search returned more than ~10 scenes (each scene = 3 bands).
    token <- .pc_collection_token("sentinel-2-l2a")
    if (!is.null(token)) {
      for (b in .S2_STAC_BANDS) {
        col <- paste0("href_", b)
        out[[col]] <- vapply(out[[col]], .pc_apply_token,
                             character(1), token)
      }
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

# Sentinel-2 bands exposed by STAC search. v0.24.1 widens this from
# c("B04","B08","B12") (FAST only) to the union of FAST + FORDEAD so
# any downstream consumer (NDVI / NBR pipeline, FORDEAD CRSWIR, custom
# pipeline) can pick what it needs without re-querying STAC. Adding a
# band here is essentially free: one more `href` lookup per feature,
# no extra HTTP call.
.S2_STAC_BANDS <- c("B02", "B04", "B05", "B08", "B8A", "B11", "B12")

# Bands required to keep a scene in the result set. FAST builds NDVI
# from (B04, B08) and NBR from (B08, B12), so a scene missing any of
# those is unusable for the FAST pipeline. The four FORDEAD-extra
# bands (B02, B05, B8A, B11) are kept tolerant (empty href = "");
# `ingest_s2_raw_bands_to_cache()` reports missing-band scenes
# individually when FORDEAD asks for them.
.S2_STAC_REQUIRED_BANDS <- c("B04", "B08", "B12")


.empty_scene_tibble <- function() {
  out <- data.frame(
    scene_id  = character(0),
    obs_date  = as.Date(character(0)),
    cloud_pct = numeric(0),
    stringsAsFactors = FALSE
  )
  for (b in .S2_STAC_BANDS) {
    out[[paste0("href_", b)]] <- character(0)
  }
  out$source <- character(0)
  out
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
    row <- list(
      scene_id  = ft$id %||% NA_character_,
      obs_date  = .parse_stac_datetime(props$datetime %||% props$start_datetime),
      cloud_pct = as.numeric(props$`eo:cloud_cover` %||% NA_real_)
    )
    for (b in .S2_STAC_BANDS) {
      row[[paste0("href_", b)]] <- href(b)
    }
    row$source <- source
    row
  })
  out <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
  required_cols <- paste0("href_", .S2_STAC_REQUIRED_BANDS)
  keep <- !is.na(out$obs_date)
  for (col in required_cols) keep <- keep & nzchar(out[[col]])
  out <- out[keep, , drop = FALSE]
  rownames(out) <- NULL
  out
}

.parse_stac_datetime <- function(dt) {
  if (is.null(dt) || is.na(dt) || !nzchar(dt)) return(as.Date(NA))
  as.Date(substr(dt, 1, 10))
}


# ---- Sentinel-2 reprocessing-duplicate handling ----------------------
#
# ESA periodically reprocesses the Sentinel-2 archive: an acquisition
# is republished under a NEW product id whose only change is the
# trailing processing-baseline timestamp (and, in the full ESA
# naming, the `N#####` baseline field). A STAC search then returns
# the same acquisition twice. Caching both wastes one download set
# per duplicate and feeds FORDEAD two STAC items with an identical
# `datetime`, which it flags ("Duplicas times found") and merges in
# an undefined order.

# Split a Sentinel-2 product id into its acquisition key + processing
# timestamp. The acquisition is identified by mission + datatake
# sensing time + relative orbit + MGRS tile — everything that is
# physically the same observation; the trailing timestamp is the
# processing discriminator. Recognises both the 6-field Planetary
# Computer id and the 7-field ESA id (with or without a `.SAFE`
# suffix). An id that does not parse becomes its own unique key and
# is therefore never merged.
.s2_split_product_id <- function(scene_id) {
  sid     <- sub("\\.SAFE$", "", as.character(scene_id))
  parts   <- strsplit(sid, "_", fixed = TRUE)[[1]]
  ts      <- grepl("^[0-9]{8}T[0-9]{6}$", parts)
  mission <- parts[grepl("^S2[A-D]$", parts)]
  orbit   <- parts[grepl("^R[0-9]{3}$", parts)]
  tile    <- parts[grepl("^T[0-9]{2}[A-Z]{3}$", parts)]
  if (sum(ts) >= 2L && length(mission) == 1L &&
      length(orbit) == 1L && length(tile) == 1L) {
    sensing <- parts[ts][1L]          # first timestamp = datatake sensing
    proc    <- parts[ts][sum(ts)]     # last timestamp  = processing baseline
    list(key  = paste(mission, sensing, orbit, tile, sep = "_"),
         proc = proc)
  } else {
    list(key = as.character(scene_id), proc = NA_character_)
  }
}

# Drop Sentinel-2 reprocessing duplicates from a scenes data.frame,
# keeping for each acquisition the row with the most recent
# processing baseline. Rows whose `scene_id` is not a recognisable
# S2 product id are always kept. Original row order is preserved.
.dedup_s2_reprocessed <- function(scenes_df) {
  if (!is.data.frame(scenes_df) || !nrow(scenes_df) ||
      !"scene_id" %in% names(scenes_df)) {
    return(scenes_df)
  }
  split <- lapply(scenes_df$scene_id, .s2_split_product_id)
  key   <- vapply(split, `[[`, character(1), "key")
  proc  <- vapply(split, `[[`, character(1), "proc")
  keep  <- rep(TRUE, nrow(scenes_df))
  for (k in unique(key[duplicated(key)])) {
    idx <- which(key == k)
    # Latest processing baseline wins. The timestamp is fixed-width
    # (YYYYMMDDTHHMMSS) so a lexicographic max is chronological.
    winner <- idx[order(proc[idx], decreasing = TRUE)][1L]
    keep[setdiff(idx, winner)] <- FALSE
  }
  scenes_df[keep, , drop = FALSE]
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
