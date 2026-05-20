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


#' Resolve THEIA datasource assets for an area of interest
#'
#' Looks up a Theia datasource declared in
#' \code{inst/datasources/<country>.json}, searches the THEIA STAC API
#' for items of its collection intersecting \code{aoi}, and returns the
#' matching asset hrefs prefixed with \code{/vsicurl/} so that GDAL can
#' read them directly.
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
#' @return A character vector of \code{/vsicurl/}-prefixed asset hrefs.
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
  paste0("/vsicurl/", hrefs)
}


#' Load a THEIA datasource as a SpatRaster
#'
#' Resolves a Theia datasource for an area of interest via the THEIA
#' STAC API (see \code{\link{resolve_theia_assets}}), loads the
#' matching Cloud-Optimised GeoTIFF asset(s) and crops them to the
#' AOI. When several items match, they are assembled into a virtual
#' raster mosaic — this assumes the assets share a CRS, which holds
#' for national products such as FORMS-T; for per-tile UTM products
#' resolve the assets with \code{\link{resolve_theia_assets}} and
#' mosaic them explicitly.
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
