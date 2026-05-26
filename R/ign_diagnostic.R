#' Probe an IGN LiDAR HD tile URL to diagnose download failures
#'
#' @description
#' When `nemetonshiny` reports "Tile X/Y: failed" on IGN LiDAR HD
#' MNT / MNH downloads (while NUAGE tiles succeed), this helper
#' classifies the failure mode by issuing a lightweight HEAD request
#' (with a `GET Range: 0-0` fallback for servers that reject HEAD).
#'
#' Typical patterns observed in production:
#'
#' \itemize{
#'   \item **HTTP 404** — the dalle exists in the WFS catalogue but the
#'         derived raster has not yet been published (IGN publishes
#'         NUAGE first; MNT/MNH dérivés arrivent souvent semaines à
#'         mois plus tard).
#'   \item **HTTP 403 / 401** — quota or auth issue on the download host.
#'   \item **`timeout`** — the host is reachable but the response did
#'         not complete in `timeout` seconds; usually a temporary
#'         server-side load issue.
#'   \item **`dns` / `connect`** — host unreachable: check VPN /
#'         outbound firewall.
#' }
#'
#' @param url Character. The download URL for one IGN LiDAR HD dalle
#'   (typically a `https://data.geopf.fr/telechargement/.../*.tif` or
#'   `https://wxs.ign.fr/...` link extracted from a happign WFS query).
#' @param timeout Numeric. Per-request timeout in seconds. Default 10.
#' @param user_agent Character. UA string to send. Default identifies
#'   nemeton.
#'
#' @return A `list` with:
#'   \describe{
#'     \item{ok}{Logical. `TRUE` when the URL resolves to a downloadable
#'           resource (HTTP 200 / 206).}
#'     \item{status}{Integer HTTP status code, or `NA` on transport
#'           failure.}
#'     \item{category}{Character classification: `"ok"`, `"not_found"`,
#'           `"forbidden"`, `"server_error"`, `"timeout"`,
#'           `"connection"`, `"dns"`, `"other"`.}
#'     \item{message}{Human-readable diagnostic.}
#'     \item{content_length}{Numeric file size in bytes, or `NA`.}
#'     \item{server}{Character. `Server` response header, or `NA`.}
#'     \item{content_type}{Character. `Content-Type` header, or `NA`.}
#'   }
#'
#' @examples
#' \dontrun{
#' # Inspect one failing MNT tile:
#' probe_ign_lidar_tile(
#'   "https://data.geopf.fr/telechargement/download/LIDAR-HD/MNT/LHD_FXX_0929_6592_MNT_O_0M50_LAMB93_IGN69.tif"
#' )
#' # $ok: FALSE, $status: 404, $category: "not_found"
#' # → dalle MNT pas encore publiée par IGN
#' }
#' @export
probe_ign_lidar_tile <- function(url,
                                 timeout    = 10,
                                 user_agent = "nemeton/probe (https://github.com/pobsteta/nemeton)") {
  if (!is.character(url) || length(url) != 1L || !nzchar(url)) {
    cli::cli_abort("{.arg url} must be a single non-empty URL.")
  }
  if (!requireNamespace("httr2", quietly = TRUE)) {
    cli::cli_abort("{.pkg httr2} is required for {.fn probe_ign_lidar_tile}.")
  }

  build_req <- function(method = c("HEAD", "GET")) {
    method <- match.arg(method)
    req <- httr2::request(url) |>
      httr2::req_user_agent(user_agent) |>
      httr2::req_timeout(timeout) |>
      httr2::req_error(is_error = function(resp) FALSE)
    if (method == "HEAD") {
      req |> httr2::req_method("HEAD")
    } else {
      # Range: bytes=0-0 keeps the response tiny while still forcing
      # the origin to confirm the resource is available.
      req |> httr2::req_headers(Range = "bytes=0-0")
    }
  }

  classify_status <- function(s) {
    if (is.na(s)) return("other")
    if (s %in% c(200L, 206L)) return("ok")
    if (s == 404L)           return("not_found")
    if (s %in% c(401L, 403L)) return("forbidden")
    if (s >= 500L)           return("server_error")
    "other"
  }

  do_request <- function(method) {
    tryCatch(
      list(resp = httr2::req_perform(build_req(method)), err = NULL),
      error = function(e) list(resp = NULL, err = e)
    )
  }

  attempt <- do_request("HEAD")

  # Some IGN endpoints disallow HEAD (return 405). Retry with a tiny
  # GET in that case so we still get a useful verdict.
  if (!is.null(attempt$resp) &&
      isTRUE(httr2::resp_status(attempt$resp) == 405L)) {
    attempt <- do_request("GET")
  }

  if (!is.null(attempt$err)) {
    msg  <- conditionMessage(attempt$err)
    cls  <- class(attempt$err)
    cat  <- if (any(grepl("timeout|Timed out|HTTP2.*-25", msg, ignore.case = TRUE))) {
      "timeout"
    } else if (any(grepl("resolve|dns|getaddrinfo", msg, ignore.case = TRUE))) {
      "dns"
    } else if (any(grepl("refused|reset|unreachable|connect", msg, ignore.case = TRUE))) {
      "connection"
    } else {
      "other"
    }
    return(list(
      ok             = FALSE,
      status         = NA_integer_,
      category       = cat,
      message        = msg,
      content_length = NA_real_,
      server         = NA_character_,
      content_type   = NA_character_
    ))
  }

  resp   <- attempt$resp
  status <- httr2::resp_status(resp)
  cat    <- classify_status(status)
  hdr    <- function(name) {
    v <- tryCatch(httr2::resp_header(resp, name), error = function(e) NA_character_)
    if (is.null(v)) NA_character_ else v
  }
  cl_raw <- hdr("Content-Length")
  cl_num <- suppressWarnings(as.numeric(cl_raw))

  pretty_msg <- switch(cat,
    ok           = sprintf("HTTP %d — tile reachable.", status),
    not_found    = sprintf("HTTP %d — dalle absente (probable production retardée côté IGN).", status),
    forbidden    = sprintf("HTTP %d — accès refusé (quota / auth).", status),
    server_error = sprintf("HTTP %d — erreur serveur IGN.", status),
    sprintf("HTTP %d.", status)
  )

  list(
    ok             = identical(cat, "ok"),
    status         = as.integer(status),
    category       = cat,
    message        = pretty_msg,
    content_length = if (is.na(cl_num)) NA_real_ else cl_num,
    server         = hdr("Server"),
    content_type   = hdr("Content-Type")
  )
}


#' Batch-probe a vector of IGN LiDAR HD tile URLs
#'
#' Convenience wrapper around [`probe_ign_lidar_tile()`] for the
#' "4/4 tiles failed" diagnostic scenario. Returns a `data.frame`
#' with one row per URL and a summary classification, ready to be
#' rendered in the app.
#'
#' @param urls Character vector of tile URLs.
#' @param timeout Per-request timeout in seconds (default 10).
#'
#' @return A `data.frame` with columns `url`, `status`, `category`,
#'   `message`, `content_length`.
#'
#' @export
probe_ign_lidar_tiles <- function(urls, timeout = 10) {
  if (!length(urls)) {
    return(data.frame(
      url = character(), status = integer(), category = character(),
      message = character(), content_length = numeric()
    ))
  }
  results <- lapply(urls, function(u) {
    r <- probe_ign_lidar_tile(u, timeout = timeout)
    data.frame(
      url            = u,
      status         = r$status,
      category       = r$category,
      message        = r$message,
      content_length = r$content_length,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, results)
}
