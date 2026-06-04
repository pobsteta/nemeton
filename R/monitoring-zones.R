# Monitoring zones derived from UGF x BD Forêt v2 strata (spec 020).
# Builds up to 4 zones per project — <project>_tot/_feu/_res/_mix — from
# the UGF union crossed with the BD Forêt v2 broadleaf / conifer / mixed
# strata. Zones are pure geometries (no placettes: since spec 017 the
# FAST/FORDEAD diagnostic is per-pixel raster, placette-independent).

# NMT slug: lowercase ASCII, accents transliterated (é->e, ç->c, …),
# every non-alphanumeric run collapsed to a single `_`, trimmed. Empty
# input falls back to "projet". Used to name zones `<slug>_<stratum>`.
.nmt_slug <- function(x) {
  s <- tolower(as.character(x)[1L])
  if (is.na(s) || !nzchar(s)) return("projet")
  s <- chartr("àâäéèêëîïôöùûüç",
              "aaaeeeeiioouuuc", s)
  s <- gsub("[^a-z0-9]+", "_", s)
  s <- gsub("^_+|_+$", "", s)
  if (!nzchar(s)) return("projet")
  s
}

# Classify BD Forêt v2 polygons into NMT strata using the IGN simplified
# `tfv_g11` nomenclature, falling back to `essence` (then leaving "autre")
# when `tfv_g11` is missing. Returns a character vector aligned with the
# rows of `bdforet`: "feuillu", "resineux", "mixte" or "autre".
.classify_bdforet_strata <- function(bdforet) {
  n <- nrow(bdforet)
  if (is.null(n) || n == 0L) return(character(0))
  g <- if ("tfv_g11" %in% names(bdforet))
    tolower(as.character(bdforet$tfv_g11)) else rep(NA_character_, n)
  out <- rep("autre", n)
  out[!is.na(g) & grepl("feuillus", g)] <- "feuillu"
  out[!is.na(g) & grepl("conif",    g)] <- "resineux"   # "conifères"
  out[!is.na(g) & grepl("mixte",    g)] <- "mixte"
  # Fallback on `essence` for rows where tfv_g11 is absent/empty.
  na <- is.na(g) | !nzchar(g)
  if (any(na) && "essence" %in% names(bdforet)) {
    e <- tolower(as.character(bdforet$essence[na]))
    r <- rep("autre", length(e))
    r[!is.na(e) & grepl("feuillus", e)]             <- "feuillu"
    r[!is.na(e) & grepl("sapin|épicéa|conif", e)] <- "resineux"
    r[!is.na(e) & grepl("mixte", e)]                <- "mixte"
    out[na] <- r
  }
  out
}


#' Create a monitoring zone (geometry only, no placettes)
#'
#' Inserts a single row into `monitoring_zone` from a polygon, optionally
#' bound to a project via `project_uuid` (spec 011). Unlike
#' [register_monitoring_zone()], it writes **no** placettes: since spec 017
#' the FAST/FORDEAD diagnostic is computed per-pixel from the COG cache and
#' is placette-independent, so a monitoring zone needs only its geometry.
#' Validation-terrain placettes, if ever needed, are added separately.
#'
#' The polygon is reprojected to EPSG:4326 and stored as WKT, consistent
#' with [register_monitoring_zone()].
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#' @param zone_name Non-empty character scalar. Zone name (unique per
#'   `project_uuid` since migration 0005).
#' @param zone_polygon An `sf`/`sfc` object carrying the zone polygon (any
#'   CRS; reprojected to 4326 on insert).
#' @param project_uuid Optional character scalar (or `NULL`, default).
#'   Opaque project identifier; uniqueness is on `(project_uuid, name)`.
#'
#' @return The new zone id (integer, invisibly).
#'
#' @seealso [build_project_monitoring_zones()] (the strata builder that
#'   calls this), [find_zones_by_project()], [register_monitoring_zone()].
#'
#' @export
create_monitoring_zone <- function(con, zone_name, zone_polygon,
                                   project_uuid = NULL) {
  .assert_db_pkgs()
  if (!is.character(zone_name) || length(zone_name) != 1L ||
      is.na(zone_name) || !nzchar(zone_name)) {
    cli::cli_abort("{.arg zone_name} must be a non-empty character scalar.")
  }
  if (!inherits(zone_polygon, c("sf", "sfc"))) {
    cli::cli_abort("{.arg zone_polygon} must be an sf/sfc object.")
  }
  if (!is.null(project_uuid)) {
    if (!is.character(project_uuid) || length(project_uuid) != 1L ||
        is.na(project_uuid) || !nzchar(project_uuid)) {
      cli::cli_abort("{.arg project_uuid} must be a non-empty character scalar or {.code NULL}.")
    }
  }

  zone_4326 <- sf::st_transform(zone_polygon, 4326)
  zone_wkt  <- sf::st_as_text(sf::st_geometry(zone_4326)[[1L]])

  zone_id <- DBI::dbWithTransaction(con, {
    if (is.null(project_uuid)) {
      .db_execute(con,
        "INSERT INTO monitoring_zone (name, zone_wkt, crs_epsg) VALUES ($1, $2, 4326)",
        params = list(zone_name, zone_wkt))
      rs <- .db_get_query(con,
        "SELECT id FROM monitoring_zone WHERE name = $1 ORDER BY id DESC LIMIT 1",
        params = list(zone_name))
    } else {
      .db_execute(con,
        paste0("INSERT INTO monitoring_zone (name, zone_wkt, crs_epsg, project_uuid) ",
               "VALUES ($1, $2, 4326, $3)"),
        params = list(zone_name, zone_wkt, project_uuid))
      rs <- .db_get_query(con,
        "SELECT id FROM monitoring_zone WHERE project_uuid = $1 AND name = $2",
        params = list(project_uuid, zone_name))
    }
    rs$id[1L]
  })
  invisible(as.integer(zone_id))
}


#' List the monitoring zones bound to a project UUID
#'
#' Returns every `monitoring_zone` row carrying `project_uuid`, ordered by
#' name. Since spec 020 a project may own several zones
#' (`<project>_tot/_feu/_res/_mix`), so prefer this over
#' [find_zone_by_project()] (which returns only the first id).
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#' @param project_uuid Non-empty character scalar. Opaque project id.
#'
#' @return A `data.frame` with columns `id` (integer) and `name`
#'   (character), ordered by `name`; zero rows when no zone matches.
#'
#' @seealso [find_zone_by_project()], [build_project_monitoring_zones()].
#'
#' @export
find_zones_by_project <- function(con, project_uuid) {
  .assert_db_pkgs()
  if (!is.character(project_uuid) || length(project_uuid) != 1L ||
      is.na(project_uuid) || !nzchar(project_uuid)) {
    cli::cli_abort("{.arg project_uuid} must be a non-empty character scalar.")
  }
  rs <- .db_get_query(con,
    "SELECT id, name FROM monitoring_zone WHERE project_uuid = $1 ORDER BY name",
    params = list(project_uuid))
  if (!nrow(rs)) {
    return(data.frame(id = integer(0), name = character(0),
                      stringsAsFactors = FALSE))
  }
  data.frame(id = as.integer(rs$id), name = as.character(rs$name),
             stringsAsFactors = FALSE)
}

# Delete every monitoring zone bound to `project_uuid` (and, via the
# `plot.zone_id ON DELETE CASCADE` FK, their placettes). Used by the D5
# upsert path. No-op when the project has no zone.
.delete_project_zones <- function(con, project_uuid) {
  .db_execute(con,
    "DELETE FROM monitoring_zone WHERE project_uuid = $1",
    params = list(project_uuid))
  invisible(NULL)
}


#' Build a project's monitoring zones from UGF x BD Forêt v2 strata
#'
#' Creates up to four monitoring zones for a project (spec 020):
#'
#' * `<project>_tot` — union of the UGFs;
#' * `<project>_feu` — that union intersected with BD Forêt v2 broadleaf;
#' * `<project>_res` — intersected with BD Forêt v2 conifer;
#' * `<project>_mix` — intersected with BD Forêt v2 mixed forest.
#'
#' `<project>` is the project name as an NMT slug (lowercase, accents
#' transliterated). BD Forêt polygons are classified by their `tfv_g11`
#' field (fallback `essence`). A stratum with no surface is **skipped**
#' with a warning (D4): a project therefore owns 1 to 4 zones. When
#' `replace = TRUE` (default, D5) the project's existing zones are deleted
#' first, so re-running refreshes them.
#'
#' All geometry is computed in `work_crs` (a projected CRS, for valid
#' area-based intersection); [create_monitoring_zone()] stores each zone in
#' EPSG:4326. Zones carry no placettes (see [create_monitoring_zone()]).
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#' @param project_name Character scalar. Human project name; slugged for
#'   the zone names.
#' @param project_uuid Non-empty character scalar. Opaque project id that
#'   binds the created zones (uniqueness on `(project_uuid, name)`).
#' @param ugf An `sf`/`sfc` of the project's UGF (management unit) polygons.
#' @param bdforet An `sf` of BD Forêt v2 polygons, carrying `tfv_g11`
#'   (and/or `essence`).
#' @param strata Character vector, subset of `c("tot","feu","res","mix")`.
#'   Default all four.
#' @param work_crs Numeric EPSG of the working projected CRS for the
#'   geometry operations. Default 2154 (Lambert-93).
#' @param replace Logical. When `TRUE` (default) the project's existing
#'   zones are deleted before (re)creating (idempotent upsert).
#'
#' @return A named `list` mapping each created stratum (`"tot"`, `"feu"`,
#'   `"res"`, `"mix"`) to its new zone id. Skipped (empty) strata are
#'   absent from the list.
#'
#' @seealso [create_monitoring_zone()], [find_zones_by_project()].
#'
#' @export
build_project_monitoring_zones <- function(con, project_name, project_uuid,
                                           ugf, bdforet,
                                           strata = c("tot", "feu", "res", "mix"),
                                           work_crs = 2154L,
                                           replace = TRUE) {
  .assert_db_pkgs()
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} required.")
  }
  if (!is.character(project_name) || length(project_name) != 1L ||
      is.na(project_name) || !nzchar(project_name)) {
    cli::cli_abort("{.arg project_name} must be a non-empty character scalar.")
  }
  if (!is.character(project_uuid) || length(project_uuid) != 1L ||
      is.na(project_uuid) || !nzchar(project_uuid)) {
    cli::cli_abort("{.arg project_uuid} must be a non-empty character scalar.")
  }
  if (!inherits(ugf, c("sf", "sfc"))) {
    cli::cli_abort("{.arg ugf} must be an sf/sfc object.")
  }
  if (!inherits(bdforet, "sf")) {
    cli::cli_abort("{.arg bdforet} must be an sf object (needs tfv_g11/essence).")
  }
  strata <- match.arg(strata, c("tot", "feu", "res", "mix"), several.ok = TRUE)

  # UGF union in the working CRS.
  u <- sf::st_union(sf::st_make_valid(
    sf::st_transform(sf::st_geometry(ugf), work_crs)))

  # BD Forêt strata unions in the same CRS.
  bd  <- sf::st_make_valid(sf::st_transform(bdforet, work_crs))
  cls <- .classify_bdforet_strata(bd)

  .stratum_inter <- function(klass) {
    sub <- sf::st_geometry(bd[cls == klass, ])
    if (!length(sub)) return(NULL)
    gi <- suppressWarnings(sf::st_intersection(u, sf::st_union(sub)))
    if (!length(gi)) return(NULL)
    # Keep only polygonal parts (intersections can yield collections).
    gi <- suppressWarnings(sf::st_collection_extract(gi, "POLYGON"))
    if (!length(gi) || all(sf::st_is_empty(gi))) return(NULL)
    gi
  }

  geoms <- list(tot = u,
                feu = .stratum_inter("feuillu"),
                res = .stratum_inter("resineux"),
                mix = .stratum_inter("mixte"))

  # D5 — upsert: drop the project's existing zones before recreating.
  if (isTRUE(replace)) .delete_project_zones(con, project_uuid)

  base <- .nmt_slug(project_name)
  ids  <- list()
  for (s in strata) {
    g <- geoms[[s]]
    empty <- is.null(g) || all(sf::st_is_empty(g)) ||
      as.numeric(sum(sf::st_area(g))) <= 0
    if (empty) {
      cli::cli_warn("FAST/FORDEAD stratum {.val {s}} is empty for {.val {project_name}} — zone not created.")
      next
    }
    ids[[s]] <- create_monitoring_zone(
      con,
      zone_name    = paste0(base, "_", s),
      zone_polygon = sf::st_sf(geometry = sf::st_sfc(sf::st_union(g),
                                                     crs = work_crs)),
      project_uuid = project_uuid)
  }
  ids
}


#' Remove cache directories of monitoring zones that no longer exist
#'
#' Scans the per-zone cache directories under `cache_root` and removes
#' every `zone_<id>/` folder whose `id` is no longer present in
#' `monitoring_zone`. Such orphans appear after a zone upsert (spec 020,
#' [build_project_monitoring_zones()] with `replace = TRUE`): re-created
#' zones get **new** ids, so the previous `zone_<old_id>/` caches are
#' stranded. The per-zone LRU GCs (`nemeton.fast_raster_keep`,
#' `nemeton.fast_mask_keep`) only trim *within* a live zone dir, never a
#' whole stale dir — hence this housekeeping helper.
#'
#' Only directories named exactly `zone_<integer>` under the listed
#' `subdirs` are considered; everything else (shared `sentinel2/`,
#' `lidar_*`, …) is left untouched.
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#' @param cache_root Character scalar. Path to `<project>/cache/layers`
#'   (the parent of the per-zone cache subdirs).
#' @param subdirs Character vector of cache subdirectory names that hold
#'   `zone_<id>/` folders. Default covers the FAST continuous
#'   (`fast_alert`, `fast_raster`), FAST 0-4 mask (`fast_alert_mask`,
#'   `fast`), validation-sampling (`fast_sampling`) and FORDEAD
#'   (`fordead`) caches.
#' @param dry_run Logical. When `TRUE`, report what would be removed
#'   without deleting anything. Default `FALSE`.
#'
#' @return A `data.frame` (`path`, `zone_id`, `removed`) of the orphan
#'   directories found, invisibly. `removed` is `FALSE` on a dry-run or a
#'   failed unlink.
#'
#' @seealso [build_project_monitoring_zones()] (the upsert that strands
#'   the caches), [find_zones_by_project()].
#'
#' @export
prune_orphan_zone_caches <- function(con, cache_root,
                                     subdirs = c("fast_alert", "fast_alert_mask",
                                                 "fast_sampling", "fast",
                                                 "fast_raster", "fordead"),
                                     dry_run = FALSE) {
  .assert_db_pkgs()
  if (!is.character(cache_root) || length(cache_root) != 1L ||
      is.na(cache_root) || !nzchar(cache_root)) {
    cli::cli_abort("{.arg cache_root} must be a non-empty path.")
  }
  empty <- data.frame(path = character(0), zone_id = integer(0),
                      removed = logical(0), stringsAsFactors = FALSE)
  if (!dir.exists(cache_root)) return(invisible(empty))

  rs <- .db_get_query(con, "SELECT id FROM monitoring_zone")
  valid <- if (nrow(rs)) as.integer(rs$id) else integer(0)

  found <- empty
  for (sd in subdirs) {
    root <- file.path(cache_root, sd)
    if (!dir.exists(root)) next
    dirs <- list.dirs(root, recursive = FALSE, full.names = TRUE)
    zdirs <- dirs[grepl("^zone_[0-9]+$", basename(dirs))]
    if (!length(zdirs)) next
    ids    <- as.integer(sub("^zone_", "", basename(zdirs)))
    orphan <- !(ids %in% valid)
    if (!any(orphan)) next
    found <- rbind(found, data.frame(path = zdirs[orphan],
                                     zone_id = ids[orphan],
                                     removed = FALSE,
                                     stringsAsFactors = FALSE))
  }

  if (!nrow(found)) {
    cli::cli_alert_info("No orphan zone cache under {.path {cache_root}}.")
    return(invisible(found))
  }
  if (!isTRUE(dry_run)) {
    for (i in seq_len(nrow(found))) {
      found$removed[i] <- tryCatch(
        unlink(found$path[i], recursive = TRUE, force = TRUE) == 0L,
        error = function(e) FALSE)
    }
  }
  n <- if (isTRUE(dry_run)) nrow(found) else sum(found$removed)
  verb <- if (isTRUE(dry_run)) "Would prune" else "Pruned"
  cli::cli_alert_info("{verb} {n} orphan zone cache dir{?s} under {.path {cache_root}}.")
  invisible(found)
}
