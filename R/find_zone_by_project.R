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
#'   `integer(0)` when no zone matches.
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
  rs <- .db_get_query(con,
    "SELECT id FROM monitoring_zone WHERE project_uuid = $1",
    params = list(project_uuid))
  if (!nrow(rs)) {
    return(integer(0))
  }
  as.integer(rs$id[1L])
}
