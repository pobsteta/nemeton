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
#' the \env{THEIA_S3_ACCESS_KEY} and \env{THEIA_S3_SECRET_KEY}
#' environment variables (set them in a gitignored \file{.Renviron}),
#' or passed explicitly. The non-secret S3 endpoint and options are
#' read from the \code{services$theia_s3} entry of the country
#' configuration.
#'
#' @param access_key,secret_key Character. S3 credentials. When
#'   \code{NULL} (default) they are read from \env{THEIA_S3_ACCESS_KEY}
#'   and \env{THEIA_S3_SECRET_KEY}.
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
    access_key <- Sys.getenv("THEIA_S3_ACCESS_KEY", "")
  }
  if (is.null(secret_key)) {
    secret_key <- Sys.getenv("THEIA_S3_SECRET_KEY", "")
  }
  if (!nzchar(access_key) || !nzchar(secret_key)) {
    cli::cli_abort(c(
      "THEIA S3 credentials not found.",
      i = "Set {.envvar THEIA_S3_ACCESS_KEY} and {.envvar THEIA_S3_SECRET_KEY} in a gitignored {.file .Renviron}, or pass {.arg access_key} / {.arg secret_key}."
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
  terra::setGDALconfig("AWS_REGION", s3$region %||% "us-east-1")

  cli::cli_alert_success("THEIA S3 configured ({.val {s3$endpoint}}).")
  invisible(TRUE)
}


#' Resolve THEIA datasource assets for an area of interest
#'
#' Looks up a Theia datasource declared in
#' \code{inst/datasources/<country>.json}, searches the THEIA STAC API
#' for items of its collection intersecting \code{aoi}, and returns the
#' matching asset paths normalised to \code{/vsis3/} so that GDAL reads
#' the objects directly from the S3 store (call
#' \code{\link{theia_configure_s3}} once first to authenticate).
#'
#' @param source_key Character. Theia datasource key (e.g.
#'   \code{"forms_t"}). Its \code{access$stac_collection} field
#'   provides the STAC collection id.
#' @param aoi An \code{sf}/\code{sfc} area of interest.
#' @param asset Optional character. Name of the STAC asset to resolve
#'   (e.g. \code{"height"} for a multi-product source). When
#'   \code{NULL}, the first \code{"data"}-role asset is used.
#' @param datetime Optional character. STAC datetime filter (see
#'   \code{\link{stac_search_items}}).
#' @param country Character. ISO country code. Default \code{"FR"}.
#' @param stac_api Optional character. Overrides the STAC API URL read
#'   from \code{services$theia_stac}.
#' @param limit Integer. Maximum number of items to resolve. Default
#'   \code{50}.
#'
#' @return A character vector of \code{/vsis3/} asset paths.
#'
#' @export
resolve_theia_assets <- function(source_key, aoi, asset = NULL,
                                 datetime = NULL, country = "FR",
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
#' Resolves a Theia datasource for an area of interest via the THEIA
#' STAC API (see \code{\link{resolve_theia_assets}}), loads the
#' matching Cloud-Optimised GeoTIFF / VRT asset(s) and crops them to
#' the AOI. When several items match, they are assembled into a
#' virtual raster mosaic — this assumes the assets share a CRS, which
#' holds for national products such as FORMS-T.
#'
#' Call \code{\link{theia_configure_s3}} once per session first so
#' that GDAL can authenticate the \code{/vsis3/} reads.
#'
#' @inheritParams resolve_theia_assets
#'
#' @return A \code{SpatRaster} cropped to \code{aoi}.
#'
#' @examples
#' \dontrun{
#' chm <- load_theia_source("forms_t", aoi, asset = "height")
#' }
#'
#' @export
load_theia_source <- function(source_key, aoi, asset = NULL,
                              datetime = NULL, country = "FR",
                              stac_api = NULL, limit = 50L) {
  hrefs <- resolve_theia_assets(source_key, aoi, asset = asset,
                                datetime = datetime, country = country,
                                stac_api = stac_api, limit = limit)

  rast <- if (length(hrefs) == 1L) {
    terra::rast(hrefs)
  } else {
    terra::vrt(hrefs)
  }

  aoi_v <- terra::vect(aoi)
  if (!is.na(terra::crs(aoi_v)) && !is.na(terra::crs(rast)) &&
      terra::crs(aoi_v) != terra::crs(rast)) {
    aoi_v <- terra::project(aoi_v, terra::crs(rast))
  }
  terra::crop(rast, aoi_v, snap = "out")
}
