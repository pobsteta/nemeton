#' Find the monitoring zone bound to a project UUID
#'
#' Looks up `monitoring_zone.project_uuid` and returns the matching
#' zone id, or `integer(0)` if no zone is bound to that project.
#' Available since spec 011 (migration `0003_project_uuid`).
#'
#' This is the stable lookup path used by `nemetonshiny` to re-hydrate
#' a project's monitoring zone when the project metadata does not (or
#' no longer) carry `monitoring_zone_id` (e.g. project moved across
#' machines, metadata wiped, or zone registered before the field
#' existed). The function deliberately does **not** fall back to a
#' name-based lookup: matching by `name` was the legacy convention,
#' brittle (duplicates, renames) and we want callers to migrate to the
#' UUID binding.
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#' @param project_uuid Non-empty character scalar. Opaque project
#'   identifier as previously passed to [register_monitoring_zone()].
#'
#' @return An integer of length 1 (the zone id) when found, or
#'   `integer(0)` when no zone matches. When the project owns several
#'   zones (spec 020), the oldest one (lowest id) is returned; use
#'   [find_zones_by_project()] to list them all.
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @seealso [register_monitoring_zone()] for the writer side of the
#'   binding.
#'
#' @export
find_zone_by_project <- function(con, project_uuid) {
  .assert_db_pkgs()
  if (!is.character(project_uuid) || length(project_uuid) != 1L ||
      is.na(project_uuid) || !nzchar(project_uuid)) {
    cli::cli_abort("{.arg project_uuid} must be a non-empty character scalar.")
  }
  # ORDER BY id (audit 1.0) : depuis la spec 020 un projet porte plusieurs
  # zones ; sans tri, la ligne « première » dépendait du plan d'exécution
  # (index unique (project_uuid, name) -> ordre alphabétique sous SQLite).
  # On renvoie la plus ancienne, de façon déterministe.
  rs <- .db_get_query(con,
    "SELECT id FROM monitoring_zone WHERE project_uuid = $1 ORDER BY id LIMIT 1",
    params = list(project_uuid))
  if (!nrow(rs)) {
    return(integer(0))
  }
  as.integer(rs$id[1L])
}
