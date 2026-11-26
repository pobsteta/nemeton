# reconfort_fenetre.R - acquisition RECONFORT par lecture fenetree (mission 071)
# ---------------------------------------------------------------------------
# La voie « archive » (reconfort_ingest.R) telecharge l'archive MUSCATE
# entiere de chaque scene (~2 Go) pour n'en garder que la fenetre de la zone.
# La voie « fenetre » lit a distance, par plages d'octets (`/vsicurl/`), les
# seules fenetres utiles des bandes et masques que le catalogue STAC THEIA
# expose (collection `sentinel2-l2a-theia`, spec 029), et ecrit EXACTEMENT ce
# que `.reconfort_crop_scene_to_aoi()` ecrit aujourd'hui : memes noms, meme
# arborescence `<scene>/*.tif`, `<scene>/MASKS/*.tif`, meme grille et memes
# valeurs, car c'est la meme operation gdalwarp
# (`.reconfort_warp_one()`), appliquee a la source distante au lieu du fichier
# extrait. IOTA2 ne voit pas la difference.
#
# Differences connues, a verifier par la comparaison (data-raw/comparaison_reconfort/) :
#   * le catalogue n'expose pas tous les fichiers d'une archive (pas de DFP,
#     IAB, WGT, ni des SRE, ni de l'apercu) : seuls ceux listes ci-dessous sont
#     ecrits ;
#   * l'ordre d'acquisition des scenes et les scenes dont l'emprise ne touche
#     pas la fenetre : la recherche STAC se fait par tuile et par dates, comme
#     le listage GEODES, donc le meme jeu de scenes.
#
# Acces : la signature des URL passe par la passerelle teledetection
# (`theia_sign_urls()`, cles TLD_ACCESS_KEY / TLD_SECRET_KEY) ; ni conda, ni
# pygeodes, ni compte GEODES ne sont requis pour cette voie.

# Bandes de reflectance FRE (cles d'assets STAC) ecrites pour chaque scene.
# Les 10 bandes MUSCATE utiles : IOTA2 lit celles que sa configuration retient,
# l'archive les contient toutes, la fenetre aussi.
.RECONFORT_FENETRE_BANDES <- c("B02", "B03", "B04", "B05", "B06", "B07",
                               "B08", "B8A", "B11", "B12")

# Masques MAJA ecrits dans `MASKS/` : nuages et ombres (CLM), bord (EDG),
# geophysique eau/neige (MG2), pixels satures (SAT), a 10 m (R1) et 20 m (R2).
.RECONFORT_FENETRE_MASQUES <- c("CLM_R1", "CLM_R2", "EDG_R1", "EDG_R2",
                                "MG2_R1", "MG2_R2", "SAT_R1", "SAT_R2")

# Epaisseur optique des aerosols : ecrite quand elle existe (l'archive la
# contient a la racine de la scene), pas exigee.
.RECONFORT_FENETRE_OPTIONNELS <- c("ATB_R1", "ATB_R2")

# Cle d'asset STAC -> chemin relatif a la scene, a partir du nom de fichier
# porte par l'asset (le nom du catalogue est celui de l'archive).
.reconfort_fenetre_rel <- function(cle, href) {
  nom <- basename(sub("[?#].*$", "", href))
  if (cle %in% .RECONFORT_FENETRE_MASQUES) file.path("MASKS", nom) else nom
}

# Nom de la scene (dossier IOTA2) : nom du fichier de la bande B04 sans son
# suffixe `_FRE_B4.tif`.
.reconfort_fenetre_nom_scene <- function(href_b04) {
  nom <- basename(sub("[?#].*$", "", href_b04))
  if (!grepl("_FRE_B4\\.tif$", nom)) {
    cli::cli_abort(c(
      "Cannot derive the scene name from the B04 asset {.val {nom}}.",
      i = "Expected a MUSCATE file name ending in {.val _FRE_B4.tif}."))
  }
  sub("_FRE_B4\\.tif$", "", nom)
}

# Plan d'ecriture d'une scene a partir d'un item STAC : data.frame (cle, href,
# rel) des fichiers a ecrire, et `xml` (href des metadonnees) ou NA. Echoue
# AVANT toute ecriture si une bande ou un masque exige manque, en les nommant.
.reconfort_fenetre_plan <- function(feature) {
  assets <- feature$assets %||% list()
  href_de <- function(cle) {
    h <- assets[[cle]]$href %||% ""
    if (nzchar(h)) h else NA_character_
  }
  exiges <- c(.RECONFORT_FENETRE_BANDES, .RECONFORT_FENETRE_MASQUES)
  hrefs <- vapply(exiges, href_de, character(1))
  manquants <- exiges[is.na(hrefs)]
  if (length(manquants)) {
    cli::cli_abort(c(
      "STAC item {.val {feature$id %||% '?'}} lacks {length(manquants)} required asset{?s}: {.val {manquants}}.",
      i = "No file was written for this scene; use {.code acquisition = \"archive\"} to read the full archive instead."),
      class = "reconfort_fenetre_asset_absent")
  }
  opt <- vapply(.RECONFORT_FENETRE_OPTIONNELS, href_de, character(1))
  opt <- opt[!is.na(opt)]
  cles <- c(exiges, names(opt))
  hr <- c(hrefs, opt)
  plan <- data.frame(
    cle = cles, href = unname(hr),
    rel = unname(mapply(.reconfort_fenetre_rel, cles, hr)),
    stringsAsFactors = FALSE)
  list(scene = .reconfort_fenetre_nom_scene(hrefs[["B04"]]),
       fichiers = plan, xml = href_de("MD"))
}

# Signe des URL d'assets pour GDAL (`/vsicurl/<url signee>`). Isole pour etre
# simule dans les tests. Un chemin local (jeux d'essai) est rendu tel quel.
.reconfort_fenetre_signer <- function(hrefs) {
  local <- file.exists(hrefs)
  out <- hrefs
  if (any(!local)) {
    sg <- .theia_signed_read(hrefs[!local])
    if (is.null(sg)) {
      cli::cli_abort("THEIA signing failed (see the warning above).")
    }
    out[!local] <- sg
  }
  out
}

# Les cles THEIA doivent exister avant de lancer la voie fenetre. Isole pour
# les tests.
.reconfort_fenetre_verifier_acces <- function() {
  if (!nzchar(Sys.getenv("TLD_ACCESS_KEY")) ||
      !nzchar(Sys.getenv("TLD_SECRET_KEY"))) {
    cli::cli_abort(c(
      "{.code acquisition = \"fenetre\"} needs THEIA credentials to sign the asset URLs.",
      i = "Set {.envvar TLD_ACCESS_KEY} and {.envvar TLD_SECRET_KEY} (create an API key at {.url https://gate.stac.teledetection.fr}).",
      i = "Or pass {.code acquisition = \"archive\"} to download the full archives from GEODES."),
      class = "reconfort_fenetre_sans_cles")
  }
  invisible(TRUE)
}

# Vrai quand les cles THEIA sont presentes (sans lever).
.reconfort_fenetre_cles_presentes <- function() {
  nzchar(Sys.getenv("TLD_ACCESS_KEY")) && nzchar(Sys.getenv("TLD_SECRET_KEY"))
}

# Recupere un petit fichier (metadonnees XML) : copie locale ou GET HTTP(S).
.reconfort_fenetre_fetch_fichier <- function(src, dest) {
  if (file.exists(src)) {
    ok <- file.copy(src, dest, overwrite = TRUE)
    if (!isTRUE(ok)) cli::cli_abort("Cannot copy {.path {src}}.")
    return(invisible(dest))
  }
  url <- sub("^/vsicurl/", "", src)
  req <- httr2::request(url) |>
    httr2::req_timeout(60L) |>
    .with_stac_retry()
  httr2::req_perform(req, path = dest)
  invisible(dest)
}

# Lit une fenetre distante vers `dst` avec reprise : jusqu'a `max_tries`
# essais (NEMETON_S2_MAX_TRIES, defaut 3), attente 2 s, 4 s, ... plafonnee a
# 30 s, options GDAL de lecture distante (.with_s2_gdal_opts), cache GDAL
# contourne des le 2e essai, URL re-signee a chaque essai (`src_fn(essai)`).
# Toute erreur est reprise : la lecture vise des URL signees, ou un echec est
# presque toujours passager (coupure, 5xx, signature expiree). Echec durable :
# l'erreur nomme `etiquette`, sans l'URL signee (.redact_url).
.reconfort_fenetre_lire <- function(src_fn, dst, win, target_crs, etiquette,
                                    max_tries = NULL, sleep = Sys.sleep) {
  if (is.null(max_tries)) {
    mt <- suppressWarnings(as.integer(Sys.getenv("NEMETON_S2_MAX_TRIES", "3")))
    max_tries <- if (is.na(mt) || mt < 1L) 3L else mt
  }
  dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)
  derniere <- NULL
  for (essai in seq_len(max_tries)) {
    src <- src_fn(essai)
    nc <- if (essai > 1L && grepl("^/vsicurl/", src)) src else NULL
    res <- tryCatch({
      unlink(dst, force = TRUE)
      .with_s2_gdal_opts(
        .reconfort_warp_one(src, dst, win, target_crs), non_cached = nc)
      if (!file.exists(dst) || file.size(dst) == 0) {
        stop("gdalwarp wrote no output")
      }
      NULL
    }, error = function(e) e)
    if (is.null(res)) return(invisible(dst))
    derniere <- res
    if (essai < max_tries) sleep(min(30, 2^essai))
  }
  unlink(dst, force = TRUE)
  cli::cli_abort(c(
    "Windowed read of {.val {etiquette}} failed after {max_tries} attempt{?s}.",
    x = "{(.redact_url(conditionMessage(derniere)))}"),
    class = "reconfort_fenetre_lecture")
}

# Ecrit une scene (fenetre de chaque bande et masque) dans `scene_dir` (dossier
# de preparation, jamais extracted/). Leve si un asset exige manque (avant toute
# ecriture) ou si une lecture echoue durablement ; l'appelant supprime alors le
# dossier de preparation. Renvoie le nom de la scene.
.reconfort_fenetre_ecrire_scene <- function(feature, staging, win, target_crs,
                                            max_tries = NULL,
                                            sleep = Sys.sleep) {
  plan <- .reconfort_fenetre_plan(feature)
  scene_dir <- file.path(staging, plan$scene)
  dir.create(file.path(scene_dir, "MASKS"), recursive = TRUE,
             showWarnings = FALSE)
  f <- plan$fichiers
  signes <- .reconfort_fenetre_signer(f$href)
  for (i in seq_len(nrow(f))) {
    src_fn <- function(essai) {
      # 1er essai : URL deja signee ; ensuite, nouvelle signature de ce seul
      # fichier (la precedente a pu expirer).
      if (essai == 1L) signes[[i]] else .reconfort_fenetre_signer(f$href[[i]])
    }
    .reconfort_fenetre_lire(src_fn, file.path(scene_dir, f$rel[[i]]), win,
                            target_crs, etiquette = f$cle[[i]],
                            max_tries = max_tries, sleep = sleep)
  }
  if (!is.na(plan$xml)) {
    src_xml <- .reconfort_fenetre_signer(plan$xml)
    .reconfort_fenetre_fetch_fichier(
      src_xml, file.path(scene_dir, basename(sub("[?#].*$", "", plan$xml))))
  }
  plan$scene
}

# Recherche STAC des scenes d'une tuile sur une periode (une requete,
# pagination comprise) : memes scenes que le listage GEODES (tuile + dates).
# `bare` : code MGRS sans `T` (ex. "31TCN"). Isole pour etre simule en test.
.reconfort_fenetre_lister <- function(bare, date_from, date_to, country = "FR") {
  .assert_httr2()
  api <- .theia_stac_api(country)
  collection <- .muscate_collection(country)
  body <- list(
    collections = list(collection),
    datetime    = sprintf("%sT00:00:00Z/%sT23:59:59Z",
                          as.Date(date_from), as.Date(date_to)),
    query       = list("grid:code" = list(eq = paste0("MGRS-", bare))),
    limit       = .stac_page_size()
  )
  feats <- .stac_search_paginate(
    initial_url  = paste0(sub("/+$", "", api), "/search"),
    initial_body = body, max_total = 10000L)
  # Le serveur filtre deja sur la tuile ; on ne garde que ce qui la porte
  # (defense contre un serveur qui ignorerait `query`).
  garde <- vapply(feats, function(ft) {
    identical(ft$properties[["grid:code"]], paste0("MGRS-", bare))
  }, logical(1))
  feats[garde]
}

# Voie fenetre d'une tuile : une recherche STAC, puis par scene lecture des
# fenetres, ecriture dans un dossier de preparation, promotion atomique dans
# `out_dir`, marqueur d'idempotence (le meme que la voie archive : fenetre et
# CRS). Une scene en echec est sautee et dite ; aucune scene ecrite = erreur.
.reconfort_ingest_tile_fenetre <- function(tile, bare, aoi, date_from, date_to,
                                           s2_root, out_dir, target_crs,
                                           buffer_m, quiet = FALSE,
                                           progress_callback = NULL,
                                           country = "FR") {
  emit <- function(payload) {
    if (is.null(progress_callback)) return(invisible(NULL))
    tryCatch(progress_callback(payload), error = function(e) invisible(NULL))
  }
  win     <- .reconfort_aoi_window(aoi, target_crs, buffer_m)
  win_key <- .reconfort_window_key(win, target_crs)
  marker_dir   <- file.path(s2_root, "ingested", tile)
  scratch_root <- file.path(s2_root, "scratch", tile)
  dir.create(marker_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(scratch_root, recursive = TRUE, showWarnings = FALSE)

  if (!quiet) cli::cli_alert_info(
    "RECONFORT: searching THEIA STAC for tile {.val {tile}} ...")
  feats <- .reconfort_fenetre_lister(bare, date_from, date_to, country)
  n_items <- length(feats)
  if (n_items == 0L) {
    cli::cli_abort(c(
      "No Sentinel-2 item found for tile {.val {tile}} ({date_from}..{date_to}).",
      i = "Check the STAC collection and the date range."))
  }
  if (!quiet) cli::cli_alert_info(
    "RECONFORT: tile {.val {tile}} - {n_items} S2 scene{?s} to read (windowed).")
  emit(list(current = "reconfort:ingest_listed", tile = tile,
            total = as.integer(n_items)))

  n_done <- 0L; n_skip <- 0L; n_fail <- 0L
  for (i in seq_len(n_items)) {
    ft        <- feats[[i]]
    item_id   <- as.character(ft$id %||% sprintf("item_%05d", i))
    item_date <- substr(as.character(ft$properties$datetime %||% NA_character_),
                        1L, 10L)
    safe   <- gsub("[^A-Za-z0-9._-]", "_", item_id)
    marker <- file.path(marker_dir, paste0(safe, ".", win_key, ".done"))
    ev <- function(step) emit(list(current = "reconfort:ingest_item",
                                   tile = tile, step = step,
                                   completed = as.integer(i),
                                   total = as.integer(n_items),
                                   item_date = item_date))
    if (file.exists(marker)) {
      n_skip <- n_skip + 1L
      ev("cached")
      next
    }
    if (!quiet) cli::cli_alert_info(
      "RECONFORT: {tile} {i}/{n_items} reading windows{if (!is.na(item_date)) paste0(' ', item_date) else ''} ...")
    ev("download")
    staging <- file.path(scratch_root, paste0(safe, ".crop"))
    unlink(staging, recursive = TRUE, force = TRUE)
    scene <- tryCatch(
      .reconfort_fenetre_ecrire_scene(ft, staging, win, target_crs),
      error = function(e) e)
    if (inherits(scene, "error")) {
      if (!quiet) cli::cli_alert_warning(
        "RECONFORT: item {.val {item_id}} skipped: {(.redact_url(conditionMessage(scene)))}")
      n_fail <- n_fail + 1L
      ev("failed")
      unlink(staging, recursive = TRUE, force = TRUE)
      next
    }
    # Promotion de la scene complete seulement : une scene a moitie ecrite
    # n'apparait jamais dans extracted/ ou IOTA2 la lirait.
    .atomic_promote(file.path(staging, scene), file.path(out_dir, scene))
    unlink(staging, recursive = TRUE, force = TRUE)
    unlink(list.files(marker_dir, full.names = TRUE,
                      pattern = paste0("^", gsub(".", "\\.", safe, fixed = TRUE),
                                       "(\\.[0-9a-f]+)?\\.done$")),
           force = TRUE)
    file.create(marker)
    n_done <- n_done + 1L
    ev("done")
  }
  unlink(scratch_root, recursive = TRUE, force = TRUE)

  scenes <- list.dirs(out_dir, recursive = FALSE)
  if (length(scenes) == 0L) {
    cli::cli_abort(c(
      "RECONFORT: no scene read for tile {.val {tile}}.",
      i = "{n_fail} item{?s} failed; check the THEIA credentials and connectivity, or use {.code acquisition = \"archive\"}."))
  }
  if (!quiet) cli::cli_alert_success(
    "RECONFORT: tile {.val {tile}} - {length(scenes)} scene{?s} read by window ({n_skip} cached, {n_fail} failed).")
  out_dir
}


# ---------------------------------------------------------------------------
# Comparaison des deux acquisitions (mission 071, point 4a)
# ---------------------------------------------------------------------------

# Compare deux arborescences de scenes (voie archive, voie fenetre) : fichiers
# presents des deux cotes ou d'un seul, puis, pour chaque fichier commun, la
# grille (dimensions, etendue, resolution, CRS), le type, et les valeurs.
# Rend un data.frame `fichiers` (une ligne par fichier .tif et .xml) et un
# resume. `ecart_max` : plus grand ecart absolu entre valeurs (0 = au bit pres).
.reconfort_comparer_acquisitions <- function(dir_archive, dir_fenetre) {
  lister <- function(d) {
    f <- list.files(d, recursive = TRUE, pattern = "\\.(tif|xml)$")
    f[order(f)]
  }
  fa <- lister(dir_archive); ff <- lister(dir_fenetre)
  tous <- sort(union(fa, ff))
  ligne <- function(rel) {
    a <- file.path(dir_archive, rel); b <- file.path(dir_fenetre, rel)
    out <- data.frame(fichier = rel, archive = rel %in% fa,
                      fenetre = rel %in% ff, meme_grille = NA, meme_type = NA,
                      ecart_max = NA_real_, identique = NA,
                      stringsAsFactors = FALSE)
    if (!(out$archive && out$fenetre)) return(out)
    if (grepl("\\.xml$", rel)) {
      out$identique <- identical(readLines(a, warn = FALSE),
                                 readLines(b, warn = FALSE))
      return(out)
    }
    ra <- terra::rast(a); rb <- terra::rast(b)
    out$meme_grille <- isTRUE(terra::compareGeom(
      ra, rb, stopOnError = FALSE, crs = TRUE, ext = TRUE, rowcol = TRUE,
      res = TRUE)) && terra::nlyr(ra) == terra::nlyr(rb)
    out$meme_type <- identical(terra::datatype(ra), terra::datatype(rb))
    if (isTRUE(out$meme_grille)) {
      va <- terra::values(ra, mat = FALSE); vb <- terra::values(rb, mat = FALSE)
      na_a <- is.na(va); na_b <- is.na(vb)
      out$ecart_max <- if (!identical(na_a, na_b)) Inf else
        if (all(na_a)) 0 else max(abs(va[!na_a] - vb[!na_b]))
      out$identique <- out$ecart_max == 0
    } else {
      out$identique <- FALSE
    }
    out
  }
  fichiers <- do.call(rbind, lapply(tous, ligne))
  if (is.null(fichiers)) {
    fichiers <- data.frame(fichier = character(0), archive = logical(0),
                           fenetre = logical(0), meme_grille = logical(0),
                           meme_type = logical(0), ecart_max = numeric(0),
                           identique = logical(0))
  }
  communs <- fichiers$archive & fichiers$fenetre
  resume <- list(
    n_archive = length(fa), n_fenetre = length(ff),
    seulement_archive = fichiers$fichier[fichiers$archive & !fichiers$fenetre],
    seulement_fenetre = fichiers$fichier[!fichiers$archive & fichiers$fenetre],
    n_communs = sum(communs),
    n_identiques = sum(fichiers$identique[communs] %in% TRUE),
    ecart_max = if (any(communs & !is.na(fichiers$ecart_max)))
      max(fichiers$ecart_max[communs & !is.na(fichiers$ecart_max)]) else NA_real_)
  resume$n_meme_type <- sum(fichiers$meme_type[communs] %in% TRUE |
                              grepl("\\.xml$", fichiers$fichier[communs]))
  resume$conforme <- resume$n_communs > 0L &&
    resume$n_identiques == resume$n_communs &&
    resume$n_meme_type == resume$n_communs
  list(fichiers = fichiers, resume = resume)
}
