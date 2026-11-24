# Mission 044 — lecture S2 distante par fenêtre (/vsicurl/)

test_that("cas 1 : une URL http(s) est ouverte en /vsicurl/, le reste est inchangé", {
  u <- "https://acct.blob.core.windows.net/s2/B04.tif?sv=1&se=2030-01-01T00:00:00Z&sig=abc"
  expect_identical(nemeton:::.s2_vsi_path(u), paste0("/vsicurl/", u))
  expect_identical(nemeton:::.s2_vsi_path("http://x/y.tif"), "/vsicurl/http://x/y.tif")
  expect_identical(nemeton:::.s2_vsi_path("/tmp/B04.tif"), "/tmp/B04.tif")
  expect_identical(nemeton:::.s2_vsi_path("/vsicurl/https://x/y.tif"),
                   "/vsicurl/https://x/y.tif")
  expect_identical(nemeton:::.s2_vsi_path("/vsis3/b/k.tif"), "/vsis3/b/k.tif")
})

test_that("cas 2 : le jeton renouvelé n'est pas préfixé deux fois", {
  vus <- character()
  local_mocked_bindings(
    rast = function(x, ...) { vus <<- c(vus, x); stop("HTTP 403 forbidden") },
    .package = "terra"
  )
  local_mocked_bindings(
    .pc_invalidate_token = function(...) invisible(NULL),
    .pc_resign_href = function(href, ...) paste0(sub("\\?.*$", "", href), "?sig=neuf")
  )
  old <- "https://a.blob.core.windows.net/s2/B04.tif?sig=vieux"
  expect_error(suppressWarnings(
    nemeton:::.terra_rast_with_pc_retry(old, max_tries = 2L)))
  expect_identical(vus[1], paste0("/vsicurl/", old))
  expect_identical(vus[2], "/vsicurl/https://a.blob.core.windows.net/s2/B04.tif?sig=neuf")
  expect_false(any(grepl("vsicurl//vsicurl", vus, fixed = TRUE)))
})

test_that("cas 3 : option GDAL posée pendant la lecture, état d'avant restauré", {
  nm <- "GDAL_DISABLE_READDIR_ON_OPEN"
  withr::local_envvar(c(GDAL_DISABLE_READDIR_ON_OPEN = NA))
  pendant <- nemeton:::.with_s2_gdal_opts(Sys.getenv(nm))
  expect_identical(pendant, "EMPTY_DIR")
  expect_identical(Sys.getenv(nm, unset = NA), NA_character_)
  withr::local_envvar(c(GDAL_DISABLE_READDIR_ON_OPEN = "FALSE"))
  nemeton:::.with_s2_gdal_opts(1)
  expect_identical(Sys.getenv(nm), "FALSE")
  try(nemeton:::.with_s2_gdal_opts(stop("boum")), silent = TRUE)
  expect_identical(Sys.getenv(nm), "FALSE")
})

test_that("cas 4 : un raster servi en HTTP local est lu à l'identique via /vsicurl/", {
  skip_if_not_installed("processx")
  skip_if(Sys.which("python3") == "", "python3 absent")
  withr::with_tempdir({
    r <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 200, ymin = 0,
                     ymax = 200, crs = "EPSG:32631")
    terra::values(r) <- seq_len(400)
    terra::writeRaster(r, "b.tif")
    port <- 20000L + sample.int(20000L, 1L)
    srv <- processx::process$new(
      "python3", c("-m", "http.server", port, "--bind", "127.0.0.1"),
      stdout = "|", stderr = "|")
    withr::defer(srv$kill())
    url <- sprintf("http://127.0.0.1:%d/b.tif", port)
    ok <- FALSE
    for (i in 1:30) {
      ok <- tryCatch({ close(socketConnection("127.0.0.1", port, timeout = 1)); TRUE },
                     error = function(e) FALSE, warning = function(w) FALSE)
      if (ok) break
      Sys.sleep(0.2)
    }
    skip_if_not(ok, "serveur HTTP local indisponible")
    avant <- terra::rast("b.tif")
    apres <- tryCatch(nemeton:::.terra_rast_with_pc_retry(url, max_tries = 1L),
                      error = function(e) NULL)
    skip_if(is.null(apres), "GDAL n'a pas pu lire via /vsicurl/ en local")
    expect_match(terra::sources(apres), "^/vsicurl/http://127\\.0\\.0\\.1")
    expect_equal(terra::values(apres), terra::values(avant))
    expect_equal(as.vector(terra::ext(apres)), as.vector(terra::ext(avant)))
    expect_equal(terra::res(apres), terra::res(avant))
  })
})

test_that("reprise : 'HTTP response code: 503' (/vsicurl/) est transitoire", {
  vus <- 0L
  ok_r <- terra::rast(nrows = 2, ncols = 2)
  local_mocked_bindings(
    rast = function(x, ...) {
      vus <<- vus + 1L
      if (vus == 1L) stop("HTTP response code: 503")
      ok_r
    },
    .package = "terra"
  )
  local_mocked_bindings(Sys.sleep = function(...) invisible(NULL), .package = "base")
  r <- nemeton:::.terra_rast_with_pc_retry(
    "https://a.blob.core.windows.net/B04.tif?sig=x", max_tries = 2L)
  expect_s4_class(r, "SpatRaster")
  expect_identical(vus, 2L)
})

# Serveur local à plages d'octets (python3) qui répond 503 aux `n_503`
# premières requêtes (Inf = toujours), puis 200/206 sur b.tif (dans le
# répertoire courant). Retourne l'URL ; le processus est tué en fin de test.
.serveur_503 <- function(n_503, env = parent.frame()) {
  writeLines(c(
    "import http.server, sys",
    "lim = float(sys.argv[2]); n = {'k': 0}",
    "class H(http.server.BaseHTTPRequestHandler):",
    "    def log_message(self, *a): pass",
    "    def serve(self, body):",
    "        if n['k'] < lim:",
    "            n['k'] += 1; self.send_response(503); self.send_header('Content-Length','0'); self.end_headers(); return",
    "        data = open('b.tif', 'rb').read(); rg = self.headers.get('Range')",
    "        if rg:",
    "            a, b = rg.split('=')[1].split('-'); a = int(a)",
    "            b = min(int(b) if b else len(data) - 1, len(data) - 1)",
    "            self.send_response(206); self.send_header('Content-Range', 'bytes %d-%d/%d' % (a, b, len(data))); chunk = data[a:b+1]",
    "        else:",
    "            self.send_response(200); chunk = data",
    "        self.send_header('Content-Length', str(len(chunk))); self.send_header('Accept-Ranges', 'bytes'); self.end_headers()",
    "        if body: self.wfile.write(chunk)",
    "    def do_GET(self): self.serve(True)",
    "    def do_HEAD(self): self.serve(False)",
    "http.server.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()"
  ), "srv.py")
  port <- 20000L + sample.int(20000L, 1L)
  srv <- processx::process$new("python3", c("srv.py", port, as.character(n_503)),
                               stdout = "|", stderr = "|")
  withr::defer(srv$kill(), envir = env)
  ok <- FALSE
  for (i in 1:30) {
    ok <- tryCatch({ close(socketConnection("127.0.0.1", port, timeout = 1)); TRUE },
                   error = function(e) FALSE, warning = function(w) FALSE)
    if (ok) break
    Sys.sleep(0.2)
  }
  if (!ok) return(NULL)
  sprintf("http://127.0.0.1:%d/b.tif", port)
}

.ecrire_b_tif <- function() {
  r <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 200, ymin = 0,
                   ymax = 200, crs = "EPSG:32631")
  terra::values(r) <- seq_len(400)
  terra::writeRaster(r, "b.tif")
}

test_that("reprise réelle : un 503 mis en cache par /vsicurl/ est retenté", {
  skip_if_not_installed("processx")
  skip_if(Sys.which("python3") == "", "python3 absent")
  withr::with_tempdir({
    .ecrire_b_tif()
    url <- .serveur_503(1)
    skip_if(is.null(url), "serveur HTTP local indisponible")
    ev <- character()
    res <- suppressWarnings(nemeton:::.terra_rast_with_pc_retry(
      url, max_tries = 3L, emit_fn = function(x) ev <<- c(ev, x$current)))
    expect_s4_class(res, "SpatRaster")
    expect_equal(terra::values(res), terra::values(terra::rast("b.tif")))
    expect_false("s2:band_fetch_failed" %in% ev)
  })
})

test_that("serveur toujours en 503 : échec borné en temps (pas de retry GDAL)", {
  skip_if_not_installed("processx")
  skip_if(Sys.which("python3") == "", "python3 absent")
  withr::with_tempdir({
    .ecrire_b_tif()
    url <- .serveur_503(Inf)
    skip_if(is.null(url), "serveur HTTP local indisponible")
    ev <- character()
    dt <- system.time(
      expect_error(suppressWarnings(nemeton:::.terra_rast_with_pc_retry(
        url, max_tries = 3L, emit_fn = function(x) ev <<- c(ev, x$current))))
    )[["elapsed"]]
    expect_true("s2:band_fetch_failed" %in% ev)
    expect_lt(dt, 20)
  })
})

test_that("reprise : une coupure 'CURL error' est transitoire", {
  vus <- 0L
  ok_r <- terra::rast(nrows = 2, ncols = 2)
  local_mocked_bindings(
    rast = function(x, ...) {
      vus <<- vus + 1L
      if (vus == 1L) stop("CURL error: Couldn't connect to server")
      ok_r
    },
    .package = "terra"
  )
  local_mocked_bindings(Sys.sleep = function(...) invisible(NULL), .package = "base")
  r <- nemeton:::.terra_rast_with_pc_retry(
    "https://a.blob.core.windows.net/B04.tif?sig=x", max_tries = 2L)
  expect_s4_class(r, "SpatRaster")
  expect_identical(vus, 2L)
})
