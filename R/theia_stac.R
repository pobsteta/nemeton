#' THEIA STAC resolver
#'
#' @description
#' Generic STAC (SpatioTemporal Asset Catalog) item search and a
#' THEIA-specific asset resolver, so that the Theia datasources
#' declared in \code{inst/datasources/<country>.json} (\code{forms_t},
#' \code{s2_biophysical}, \code{theia_snow}, ...) can be materialised
#' from the THEIA STAC API instead of a manual download.
#'
#' The plumbing is endpoint-agnostic: \code{\link{stac_search_items}}
#' works against any STAC API, and the THEIA endpoint is read from the
#' \code{services$theia_stac} entry of the country configuration (or
#' passed explicitly via \code{stac_api}).
#'
#' @name theia_stac
NULL


# Build a WGS84 [xmin, ymin, xmax, ymax] bbox from an sf/sfc AOI.
.theia_bbox_4326 <- function(aoi) {
  if (!inherits(aoi, "sf") && !inherits(aoi, "sfc")) {
    cli::cli_abort("{.arg aoi} must be an sf or sfc object.")
  }
  bb <- sf::st_bbox(sf::st_transform(aoi, 4326))
  as.numeric(c(bb["xmin"], bb["ymin"], bb["xmax"], bb["ymax"]))
}


# Pick an asset href from a STAC item feature. When `asset` is given,
# that named asset is used; otherwise the first asset carrying the
# "data" role (or, failing that, the first asset) is picked.
.stac_pick_asset <- function(feature, asset = NULL) {
  assets <- feature$assets %||% list()
  if (!length(assets)) {
    cli::cli_abort("STAC item {.val {feature$id %||% '?'}} carries no assets.")
  }
  if (!is.null(asset)) {
    entry <- assets[[asset]]
    if (is.null(entry) || !nzchar(entry$href %||% "")) {
      cli::cli_abort(c(
        "STAC item {.val {feature$id %||% '?'}} has no asset {.val {asset}}.",
        i = "Available assets: {.val {names(assets)}}."
      ))
    }
    return(entry$href)
  }
  for (entry in assets) {
    roles <- unlist(entry$roles %||% list())
    if ("data" %in% roles && nzchar(entry$href %||% "")) {
      return(entry$href)
    }
  }
  first <- assets[[1]]
  if (is.null(first) || !nzchar(first$href %||% "")) {
    cli::cli_abort("STAC item {.val {feature$id %||% '?'}} has no usable asset href.")
  }
  first$href
}


# Normalise a Theia asset href to a GDAL-readable path. The Theia
# COG/VRT assets live on an S3-compatible store; depending on how the
# href was produced it can be a teledetection download-gateway URL
# (gate.../download?url=<inner>), an `s3://bucket/key` URI, a
# path-style `https://<endpoint>/bucket/key` URL, or an already-/vsi
# path. All forms are reduced to `/vsis3/bucket/key` so GDAL reads
# the object directly with native SigV4 signing (see
# theia_configure_s3()).
.theia_href_to_gdal <- function(href) {
  if (!nzchar(href %||% "")) {
    cli::cli_abort("Empty Theia asset href.")
  }
  if (grepl("^/vsi", href)) return(href)

  # Download gateway: <gateway>/download?url=<url-encoded inner href>
  inner <- regmatches(href, regexpr("(?<=[?&]url=)[^&]+", href, perl = TRUE))
  if (length(inner) == 1L && nzchar(inner)) {
    return(.theia_href_to_gdal(utils::URLdecode(inner)))
  }

  if (grepl("^s3://", href)) {
    return(paste0("/vsis3/", sub("^s3://", "", href)))
  }
  if (grepl("^https?://", href)) {
    # path-style object URL: strip scheme + host, keep bucket/key
    return(paste0("/vsis3/", sub("^https?://[^/]+/", "", href)))
  }
  href
}



#' Search a STAC API for items
#'
#' Endpoint-agnostic STAC item search: POSTs a search request to a
#' STAC API \code{/search} endpoint and returns the matching item
#' features. Pagination is handled by the project-wide STAC paginator.
#'
#' @param stac_api Character. Root URL of the STAC API (the
#'   \code{/search} suffix is appended automatically).
#' @param collection Character. STAC collection id to query.
#' @param bbox Numeric length 4: \code{c(xmin, ymin, xmax, ymax)} in
#'   WGS84.
#' @param datetime Optional character. A STAC datetime filter — a
#'   single instant, a closed interval \code{"start/end"}, or a
#'   half-open one (\code{"start/.."}). \code{NULL} = no time filter.
#' @param limit Integer. Maximum number of items to return. Default
#'   \code{100}.
#'
#' @return A list of STAC item features (parsed JSON objects).
#'
#' @examples
#' \dontrun{
#' items <- stac_search_items(
#'   "https://stac.example.org", "forms-t",
#'   bbox = c(6.0, 47.8, 6.3, 48.0), datetime = "2023-01-01/2023-12-31"
#' )
#' }
#'
#' @export
stac_search_items <- function(stac_api, collection, bbox,
                              datetime = NULL, limit = 100L) {
  .assert_httr2()
  if (!nzchar(stac_api %||% "")) {
    cli::cli_abort("{.arg stac_api} is required.")
  }
  if (length(bbox) != 4L || anyNA(bbox)) {
    cli::cli_abort("{.arg bbox} must be a numeric vector of length 4.")
  }

  body <- list(
    collections = list(collection),
    bbox        = as.numeric(bbox),
    limit       = .stac_page_size()
  )
  if (!is.null(datetime) && nzchar(datetime)) {
    body$datetime <- datetime
  }

  search_url <- paste0(sub("/+$", "", stac_api), "/search")
  .stac_search_paginate(
    initial_url  = search_url,
    initial_body = body,
    max_total    = as.integer(limit)
  )
}


#' Fetch a single STAC item by id
#'
#' Retrieves one item from a STAC API by its collection and item id
#' (\code{<stac_api>/collections/<collection>/items/<item_id>}). Used
#' to target a specific item — e.g. a given year of an annual
#' time-series collection such as FORMSpoT.
#'
#' @param stac_api Character. Root URL of the STAC API.
#' @param collection Character. STAC collection id.
#' @param item_id Character. STAC item id.
#'
#' @return The STAC item feature (a parsed JSON object).
#'
#' @examples
#' \dontrun{
#' item <- stac_get_item("https://api.stac.teledetection.fr",
#'                       "FORMSpoT", "FORMSpoT-2023")
#' }
#'
#' @export
stac_get_item <- function(stac_api, collection, item_id) {
  .assert_httr2()
  if (!nzchar(stac_api %||% "")) {
    cli::cli_abort("{.arg stac_api} is required.")
  }
  url <- paste0(sub("/+$", "", stac_api), "/collections/",
                collection, "/items/", item_id)
  req <- httr2::request(url) |>
    httr2::req_headers(Accept = "application/json") |>
    httr2::req_timeout(60L) |>
    .with_stac_retry()
  resp <- httr2::req_perform(req)
  httr2::resp_body_json(resp)
}


# Resolve the configured THEIA STAC API URL (argument overrides
# config; aborts with an actionable message when still unset).
.theia_stac_api <- function(country = "FR", stac_api = NULL) {
  if (!is.null(stac_api) && nzchar(stac_api)) return(stac_api)
  config <- get_country_config(country)
  url <- config$services$theia_stac$url %||% ""
  if (!nzchar(url) || grepl("to confirm", url, ignore.case = TRUE)) {
    cli::cli_abort(c(
      "No THEIA STAC API endpoint configured for country {.val {country}}.",
      i = "Set {.field services.theia_stac.url} in the datasource JSON, or pass {.arg stac_api} explicitly."
    ))
  }
  url
}


#' Configure GDAL for authenticated THEIA S3 reads
#'
#' The THEIA / FORMS COG and VRT assets live on an S3-compatible
#' (MinIO) object store. This helper sets the GDAL configuration
#' options so that \code{terra}/GDAL can read \code{/vsis3/} paths
#' with native SigV4 signing — call it once per session before
#' \code{\link{load_theia_source}}.
#'
#' Credentials are never stored in the package. They are read from
#' the \env{TLD_ACCESS_KEY} and \env{TLD_SECRET_KEY} environment
#' variables — the same THEIA API-key pair used by the
#' \code{teledetection} SDK (create one at
#' \url{https://gate.stac.teledetection.fr}, set it in a gitignored
#' \file{.Renviron}) — or passed explicitly. The non-secret S3
#' endpoint, region and options are read from the
#' \code{services$theia_s3} entry of the country configuration.
#'
#' @param access_key,secret_key Character. THEIA S3 credentials.
#'   When \code{NULL} (default) they are read from
#'   \env{TLD_ACCESS_KEY} and \env{TLD_SECRET_KEY}.
#' @param country Character. ISO country code. Default \code{"FR"}.
#'
#' @return \code{TRUE} invisibly on success.
#'
#' @examples
#' \dontrun{
#' theia_configure_s3()
#' chm <- load_theia_source("formspot", aoi, asset = "height_2023")
#' }
#'
#' @export
theia_configure_s3 <- function(access_key = NULL, secret_key = NULL,
                               country = "FR") {
  if (is.null(access_key)) {
    access_key <- Sys.getenv("TLD_ACCESS_KEY", "")
  }
  if (is.null(secret_key)) {
    secret_key <- Sys.getenv("TLD_SECRET_KEY", "")
  }
  if (!nzchar(access_key) || !nzchar(secret_key)) {
    cli::cli_abort(c(
      "THEIA S3 credentials not found.",
      i = "Set {.envvar TLD_ACCESS_KEY} and {.envvar TLD_SECRET_KEY} in a gitignored {.file .Renviron} (create an API key at {.url https://gate.stac.teledetection.fr}), or pass {.arg access_key} / {.arg secret_key}."
    ))
  }

  config <- get_country_config(country)
  s3 <- config$services$theia_s3
  if (is.null(s3) || !nzchar(s3$endpoint %||% "")) {
    cli::cli_abort("No {.field services.theia_s3} endpoint configured for country {.val {country}}.")
  }

  terra::setGDALconfig("AWS_ACCESS_KEY_ID", access_key)
  terra::setGDALconfig("AWS_SECRET_ACCESS_KEY", secret_key)
  terra::setGDALconfig("AWS_S3_ENDPOINT", s3$endpoint)
  terra::setGDALconfig("AWS_VIRTUAL_HOSTING",
                       if (isTRUE(s3$virtual_hosting)) "TRUE" else "FALSE")
  terra::setGDALconfig("AWS_HTTPS",
                       if (isFALSE(s3$https)) "NO" else "YES")
  terra::setGDALconfig("AWS_REGION", s3$region %||% "sm1")

  cli::cli_alert_success("THEIA S3 configured ({.val {s3$endpoint}}).")
  invisible(TRUE)
}


#' Resolve a signed THEIA asset URL via the teledetection SDK
#'
#' Returns a ready-to-read, signed URL for one asset of a THEIA
#' datasource. THEIA asset objects require an authenticated,
#' time-limited signed URL; the signing is delegated to the official
#' \code{teledetection} Python SDK through \pkg{reticulate} (the
#' \code{tld.sign_inplace} pystac modifier — a standard AWS SigV4
#' presign). The returned URL is prefixed with \code{/vsicurl/} so
#' that \code{terra::rast()} reads it directly.
#'
#' Requirements: \pkg{reticulate}, plus the Python packages
#' \code{teledetection} and \code{pystac_client} (declared via
#' \code{reticulate::py_require()} automatically), and a registered
#' THEIA API key — see \code{\link{theia_configure_s3}} and
#' \url{https://gate.stac.teledetection.fr}.
#'
#' @param source_key Character. Theia datasource key (e.g.
#'   \code{"formspot"}).
#' @param year Optional integer. Target year of an annual collection;
#'   the item id and asset name are built from the datasource
#'   \code{access$item_id_template} / \code{access$asset_template}.
#' @param asset Optional character. Asset name. Overrides the
#'   template-derived name.
#' @param item_id Optional character. STAC item id. Overrides the
#'   template-derived id (use instead of \code{year}).
#' @param country Character. ISO country code. Default \code{"FR"}.
#' @param stac_api Optional character. Overrides the STAC API URL.
#'
#' @return A character scalar: \code{/vsicurl/}-prefixed signed URL.
#'
#' @examples
#' \dontrun{
#' href <- theia_signed_href("formspot", year = 2023)
#' chm <- terra::rast(href)
#' }
#'
#' @export
theia_signed_href <- function(source_key, year = NULL, asset = NULL,
                              item_id = NULL, country = "FR",
                              stac_api = NULL) {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg reticulate} is required for THEIA SDK signing.")
  }
  src <- get_data_source(source_key, country)
  if (is.null(src)) {
    cli::cli_abort("Unknown datasource key {.val {source_key}} for country {.val {country}}.")
  }
  collection <- src$access$stac_collection %||% ""
  if (!nzchar(collection) || grepl("to confirm", collection, ignore.case = TRUE)) {
    cli::cli_abort("Datasource {.val {source_key}} has no confirmed STAC collection.")
  }
  api <- .theia_stac_api(country, stac_api)

  if (is.null(item_id)) {
    if (is.null(year)) {
      cli::cli_abort("Provide either {.arg year} or {.arg item_id}.")
    }
    tmpl <- src$access$item_id_template %||% ""
    if (!nzchar(tmpl)) {
      cli::cli_abort(c(
        "Datasource {.val {source_key}} does not support year targeting.",
        i = "It declares no {.field access.item_id_template}."
      ))
    }
    item_id <- gsub("{year}", as.character(year), tmpl, fixed = TRUE)
  }
  if (is.null(asset) && !is.null(year)) {
    atmpl <- src$access$asset_template %||% ""
    if (nzchar(atmpl)) {
      asset <- gsub("{year}", as.character(year), atmpl, fixed = TRUE)
    }
  }

  reticulate::py_require(c("teledetection", "pystac_client"))
  tld <- reticulate::import("teledetection")
  psc <- reticulate::import("pystac_client")
  client <- psc$Client$open(api, modifier = tld$sign_inplace)
  item <- client$get_collection(collection)$get_item(item_id)
  if (is.null(item)) {
    cli::cli_abort("STAC item {.val {item_id}} not found in collection {.val {collection}}.")
  }
  assets <- item$get_assets()
  if (is.null(asset)) {
    asset <- names(assets)[1]
  }
  entry <- assets[[asset]]
  if (is.null(entry) || !nzchar(entry$href %||% "")) {
    cli::cli_abort(c(
      "STAC item {.val {item_id}} has no asset {.val {asset}}.",
      i = "Available assets: {.val {names(assets)}}."
    ))
  }
  paste0("/vsicurl/", entry$href)
}
#' Looks up a Theia datasource declared in
#' \code{inst/datasources/<country>.json} and returns the matching
#' asset paths normalised to \code{/vsis3/} so that GDAL reads the
#' objects directly from the S3 store (call
#' \code{\link{theia_configure_s3}} once first to authenticate).
#'
#' Two access modes:
#' \itemize{
#'   \item \strong{Year targeting} — when \code{year} is supplied and
#'     the datasource declares an \code{access$item_id_template} (such
#'     as FORMSpoT, one item per year), the matching item is fetched
#'     directly by id and a single asset path is returned.
#'   \item \strong{Spatial search} — otherwise, the THEIA STAC API is
#'     searched for items of the collection intersecting \code{aoi}.
#' }
#'
#' @param source_key Character. Theia datasource key (e.g.
#'   \code{"forms_t"}). Its \code{access$stac_collection} field
#'   provides the STAC collection id.
#' @param aoi An \code{sf}/\code{sfc} area of interest. Used for the
#'   spatial search; ignored in year-targeting mode.
#' @param asset Optional character. Name of the STAC asset to resolve.
#'   When \code{NULL}: in year mode the \code{access$asset_template}
#'   (with \code{{year}} substituted) is used; otherwise the first
#'   \code{"data"}-role asset.
#' @param year Optional integer. Target a single year of an annual
#'   time-series collection. Requires the datasource to declare
#'   \code{access$item_id_template}.
#' @param datetime Optional character. STAC datetime filter (see
#'   \code{\link{stac_search_items}}).
#' @param country Character. ISO country code. Default \code{"FR"}.
#' @param stac_api Optional character. Overrides the STAC API URL read
#'   from \code{services$theia_stac}.
#' @param limit Integer. Maximum number of items to resolve in search
#'   mode. Default \code{50}.
#'
#' @return A character vector of \code{/vsis3/} asset paths (length 1
#'   in year-targeting mode).
#'
#' @export
resolve_theia_assets <- function(source_key, aoi, asset = NULL,
                                 year = NULL, datetime = NULL,
                                 country = "FR",
                                 stac_api = NULL, limit = 50L) {
  src <- get_data_source(source_key, country)
  if (is.null(src)) {
    cli::cli_abort("Unknown datasource key {.val {source_key}} for country {.val {country}}.")
  }
  collection <- src$access$stac_collection %||% ""
  if (!nzchar(collection) || grepl("to confirm", collection, ignore.case = TRUE)) {
    cli::cli_abort(c(
      "Datasource {.val {source_key}} has no confirmed STAC collection.",
      i = "Set {.field access.stac_collection} in the datasource JSON."
    ))
  }

  api <- .theia_stac_api(country, stac_api)

  # ---- Year-targeting mode: fetch the item by id ----
  if (!is.null(year)) {
    tmpl <- src$access$item_id_template %||% ""
    if (!nzchar(tmpl)) {
      cli::cli_abort(c(
        "Datasource {.val {source_key}} does not support year targeting.",
        i = "It declares no {.field access.item_id_template}."
      ))
    }
    item_id <- gsub("{year}", as.character(year), tmpl, fixed = TRUE)
    if (is.null(asset)) {
      atmpl <- src$access$asset_template %||% ""
      if (nzchar(atmpl)) {
        asset <- gsub("{year}", as.character(year), atmpl, fixed = TRUE)
      }
    }
    item <- stac_get_item(api, collection, item_id)
    return(.theia_href_to_gdal(.stac_pick_asset(item, asset = asset)))
  }

  # ---- Spatial-search mode ----
  bbox <- .theia_bbox_4326(aoi)
  items <- stac_search_items(api, collection, bbox,
                             datetime = datetime, limit = limit)
  if (!length(items)) {
    cli::cli_abort(c(
      "No {.val {collection}} STAC item intersects the AOI.",
      i = "Widen {.arg datetime} or check the AOI extent."
    ))
  }

  hrefs <- vapply(items, .stac_pick_asset, character(1), asset = asset)
  vapply(hrefs, .theia_href_to_gdal, character(1), USE.NAMES = FALSE)
}


#' Load a THEIA datasource as a SpatRaster
#'
#' Loads a Theia datasource for an area of interest and crops it to
#' the AOI. Two modes:
#' \itemize{
#'   \item \strong{Year targeting} (\code{year} supplied) — the
#'     asset URL is signed through the \code{teledetection} SDK (see
#'     \code{\link{theia_signed_href}}) and read via \code{/vsicurl/}.
#'     This is the authenticated path that THEIA assets require.
#'   \item \strong{Spatial search} — resolves \code{/vsis3/} asset
#'     paths via \code{\link{resolve_theia_assets}}; call
#'     \code{\link{theia_configure_s3}} first. Reserved for direct-S3
#'     setups.
#' }
#'
#' @inheritParams resolve_theia_assets
#'
#' @return A \code{SpatRaster} cropped to \code{aoi}.
#'
#' @examples
#' \dontrun{
#' # FORMSpoT canopy height for 2023 (signed via the teledetection SDK)
#' chm <- load_theia_source("formspot", aoi, year = 2023)
#' }
#'
#' @export
load_theia_source <- function(source_key, aoi, asset = NULL,
                              year = NULL, datetime = NULL,
                              country = "FR",
                              stac_api = NULL, limit = 50L) {
  if (!is.null(year)) {
    # Authenticated path: teledetection SDK signs the asset URL.
    rast <- terra::rast(
      theia_signed_href(source_key, year = year, asset = asset,
                        country = country, stac_api = stac_api)
    )
  } else {
    hrefs <- resolve_theia_assets(source_key, aoi, asset = asset,
                                  datetime = datetime, country = country,
                                  stac_api = stac_api, limit = limit)
    rast <- if (length(hrefs) == 1L) {
      terra::rast(hrefs)
    } else {
      terra::vrt(hrefs)
    }
  }

  aoi_v <- terra::vect(aoi)
  if (!is.na(terra::crs(aoi_v)) && !is.na(terra::crs(rast)) &&
      terra::crs(aoi_v) != terra::crs(rast)) {
    aoi_v <- terra::project(aoi_v, terra::crs(rast))
  }
  terra::crop(rast, aoi_v, snap = "out")
}
