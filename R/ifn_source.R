# ifn_source.R — accès aux données brutes de l'inventaire forestier national
# ===========================================================================
# Téléchargement et chargement de l'export annuel de l'IGN
# (https://inventaire-forestier.ign.fr/dataIFN/), sous Licence Ouverte
# Etalab v2.0.
#
# Reprise intégrale — et non simple dépendance — de la capacité offerte par
# `FrenchNFIfindeR::get_NFI()` (Jérémy Borderieux, AgroParisTech, GPL-3).
# `nemeton` n'importe pas ce package : le code est réécrit ici, avec cinq
# différences délibérées, documentées dans la rubrique « Improvements » de
# `ifn_charger()`.

.IFN_BASE_URL <- "https://inventaire-forestier.ign.fr/dataifn/data"

.ifn_url <- function(campagne) {
  sprintf("%s/export_dataifn_2005_%d.zip", .IFN_BASE_URL, as.integer(campagne))
}

.ifn_url_existe <- function(url) {
  if (!requireNamespace("curl", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg curl} is required to probe the IFN export.")
  }
  tryCatch({
    h <- curl::new_handle(nobody = TRUE, timeout = 30L)
    identical(curl::curl_fetch_memory(url, handle = h)$status_code, 200L)
  }, error = function(e) FALSE)
}

#' Latest available French NFI campaign
#'
#' @description
#' Probes the IGN download server for the most recent annual export, walking
#' back year by year from `depuis`.
#'
#' This is deliberately dynamic. `FrenchNFIfindeR` pins the URL to the
#' 2005-2023 export in its source, and is therefore one campaign behind as
#' soon as the IGN publishes a new one — which it does every autumn.
#'
#' @param depuis Year to start probing from. Defaults to the current year.
#' @param back How many years to walk back before giving up. Default `5`.
#'
#' @return A list with `campagne` (integer, the last campaign covered),
#'   `millesime` (e.g. `"2005-2024"`) and `url`.
#'
#' @export
#' @examples
#' \dontrun{
#' ifn_campagne_disponible()
#' }
ifn_campagne_disponible <- function(depuis = NULL, back = 5L) {
  depuis <- as.integer(depuis %||% format(Sys.Date(), "%Y"))
  for (y in seq(depuis, depuis - as.integer(back))) {
    u <- .ifn_url(y)
    if (.ifn_url_existe(u)) {
      return(list(campagne = y, millesime = paste0("2005-", y), url = u))
    }
  }
  cli::cli_abort(
    "No IFN export found within {back} year{?s} back from {depuis}."
  )
}

#' Download the raw French NFI export
#'
#' @description
#' Fetches the IGN annual export archive and caches it in `dest_dir`. An
#' archive already present is reused, never re-downloaded silently and never
#' by asking the user a question — see the note below.
#'
#' @section Non-interactive by design:
#' `FrenchNFIfindeR::get_NFI()` calls `readline()` when raw data is already on
#' disk, asking whether to reuse or re-download. That blocks in any
#' non-interactive context — a `future` worker, a CI job, a scheduled build —
#' which is exactly where a download step belongs. Here the choice is an
#' argument: `force = FALSE` reuses, `force = TRUE` re-downloads.
#'
#' @param dest_dir Directory holding the cached archive. Created if needed.
#' @param campagne Campaign year to fetch. `NULL` (default) resolves the most
#'   recent one via [ifn_campagne_disponible()].
#' @param force Re-download even when the archive is already cached.
#'
#' @return The path to the cached `.zip`, invisibly, with attributes
#'   `campagne` and `millesime`.
#'
#' @export
#' @examples
#' \dontrun{
#' zip <- ifn_telecharger(tempdir())
#' }
ifn_telecharger <- function(dest_dir, campagne = NULL, force = FALSE) {
  if (missing(dest_dir) || !is.character(dest_dir) || length(dest_dir) != 1L) {
    cli::cli_abort("{.arg dest_dir} must be a single directory path.")
  }
  info <- if (is.null(campagne)) {
    ifn_campagne_disponible()
  } else {
    list(campagne = as.integer(campagne),
         millesime = paste0("2005-", as.integer(campagne)),
         url = .ifn_url(campagne))
  }
  dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(dest_dir, basename(info$url))

  if (file.exists(path) && !isTRUE(force)) {
    cli::cli_alert_info("Using cached IFN export {.file {basename(path)}}.")
  } else {
    cli::cli_alert_info("Downloading IFN export {info$millesime} (~65 MB).")
    utils::download.file(info$url, path, mode = "wb", quiet = TRUE)
  }
  attr(path, "campagne")  <- info$campagne
  attr(path, "millesime") <- info$millesime
  invisible(path)
}

#' Load raw French NFI tables
#'
#' @description
#' Reads the requested CSV tables out of the IGN export archive and returns
#' them. Column names are kept **as published by the IGN** (upper case:
#' `IDP`, `ESPAR`, `VEGET5`…), so the IGN documentation shipped inside the
#' archive applies directly.
#'
#' @section Improvements over `FrenchNFIfindeR::get_NFI()`:
#' This is a reimplementation, not a wrapper — `nemeton` does not depend on
#' that package. Five deliberate differences:
#' \enumerate{
#'   \item **Dynamic campaign** — the download URL is discovered
#'     ([ifn_campagne_disponible()]) instead of being pinned in the source,
#'     which leaves the original one campaign behind each autumn.
#'   \item **Non-interactive** — no `readline()` prompt; see [ifn_telecharger()].
#'   \item **Selective tables** — only the tables asked for are read. The
#'     original always reads five, including `FLORE.csv` (~58 MB) and
#'     `ECOLOGIE.csv`, even when only trees are needed.
#'   \item **Returns a value** — the original defaults to
#'     `export_to_env = TRUE`, assigning six objects into the global
#'     environment. Here the tables are returned as a named list.
#'   \item **No silent derivation** — the original imputes missing heights and
#'     increments from plot/species/size-class means, and adds computed basal
#'     areas, as a side effect of loading. Loading here returns the published
#'     data unchanged; derivations belong to the caller, where they can be
#'     documented and tested.
#' }
#'
#' @param tables Character vector of table names, without extension, e.g.
#'   `c("ARBRE", "PLACETTE")`. Available: `ARBRE`, `PLACETTE`, `ECOLOGIE`,
#'   `COUVERT`, `FLORE`, `HABITAT`, `BOIS_MORT`, `metadonnees`,
#'   `espar-cdref13`.
#' @param campagne Campaign year, or `NULL` for the most recent.
#' @param dest_dir Directory holding (or receiving) the cached archive.
#'   Defaults to a session temporary directory.
#' @param visite Optional visit filter applied to `PLACETTE` only: `1` (first
#'   measurement), `2` (the five-year revisit) or `c(1, 2)`. `NULL` keeps all.
#' @param force Passed to [ifn_telecharger()].
#'
#' @return A named list of data.frames, one per requested table, carrying a
#'   `millesime` attribute.
#'
#' @references
#' IGN — Inventaire forestier national français, Données brutes, Campagnes
#' annuelles 2005 et suivantes, <https://inventaire-forestier.ign.fr/dataIFN/>.
#' Licence Ouverte Etalab v2.0. Approach after `FrenchNFIfindeR::get_NFI()`
#' (J. Borderieux, GPL-3).
#'
#' @export
#' @examples
#' \dontrun{
#' d <- ifn_charger(c("ARBRE", "PLACETTE"), visite = 1)
#' nrow(d$ARBRE)
#' }
ifn_charger <- function(tables = c("ARBRE", "PLACETTE"), campagne = NULL,
                        dest_dir = file.path(tempdir(), "ifn"),
                        visite = NULL, force = FALSE) {
  if (!is.character(tables) || length(tables) == 0L) {
    cli::cli_abort("{.arg tables} must be a non-empty character vector.")
  }
  if (!is.null(visite) && !all(visite %in% c(1, 2))) {
    cli::cli_abort("{.arg visite} must be 1, 2 or c(1, 2).")
  }
  zip <- ifn_telecharger(dest_dir, campagne = campagne, force = force)
  millesime <- attr(zip, "millesime")

  dispo <- utils::unzip(zip, list = TRUE)$Name
  voulus <- paste0(tables, ".csv")
  manquants <- setdiff(voulus, dispo)
  if (length(manquants) > 0L) {
    cli::cli_abort(c(
      "Table{?s} not found in the IFN archive: {.val {manquants}}.",
      "i" = "Available: {.val {sub('\\\\.csv$', '', grep('\\\\.csv$', dispo, value = TRUE))}}."
    ))
  }

  # Extraction dans un dossier temporaire : `fread` ne lit pas une connexion
  # `unz()`, et `cmd = \"unzip -p\"` ne serait pas portable hors Unix.
  tmp <- file.path(tempdir(), paste0("ifn_", basename(tempfile())))
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  utils::unzip(zip, files = voulus, exdir = tmp)

  lire_une <- function(nom) {
    f <- file.path(tmp, paste0(nom, ".csv"))
    if (requireNamespace("data.table", quietly = TRUE)) {
      d <- data.table::fread(f, sep = ";", showProgress = FALSE,
                             colClasses = "character", data.table = FALSE)
    } else {
      d <- utils::read.csv2(f, stringsAsFactors = FALSE, colClasses = "character")
    }
    # Le premier en-tête porte un BOM UTF-8 dans l'export IGN.
    names(d) <- sub("^﻿", "", names(d))
    d
  }

  out <- stats::setNames(lapply(tables, lire_une), tables)

  if (!is.null(visite) && "PLACETTE" %in% tables) {
    p <- out$PLACETTE
    out$PLACETTE <- p[p$VISITE %in% as.character(visite), , drop = FALSE]
  }
  attr(out, "millesime") <- millesime
  out
}
