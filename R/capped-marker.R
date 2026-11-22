# ============================================================
# Marqueur de run plafonné — un seul moteur vivant par projet
# ============================================================
#
# 2026-11-22, Parc de la Colombière : quatre moteurs reGénération tournaient en
# même temps sur le même projet, trois d'entre eux depuis 15 à 24 h pour des runs
# que l'app avait abandonnés. Rien ne permettait à l'app de savoir qu'un moteur
# vivait encore : le seul état disque (`engine_status.json`) était effacé au
# lancement suivant. `run_memory_capped(marker_path = )` dépose donc un marqueur
# qui nomme le scope et le pid de l'enfant ; les deux fonctions ci-dessous le
# lisent pour demander si le run vit encore, ou pour l'arrêter.

.capped_marker_write <- function(path, unit, pid, fun, package) {
  rec <- list(
    unit       = if (is.null(unit) || !nzchar(unit)) NA_character_ else unit,
    pid        = as.integer(pid),
    parent_pid = as.integer(Sys.getpid()),
    fun        = fun,
    package    = package,
    started    = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  tryCatch(
    .atomic_write(path, function(tmp)
      jsonlite::write_json(rec, tmp, auto_unbox = TRUE, na = "null")),
    error = function(e) cli::cli_warn(c(
      "Could not write the run marker {.path {path}}.",
      i = "{conditionMessage(e)}")))
  invisible(path)
}

.capped_marker_read <- function(path) {
  if (is.null(path) || !file.exists(path)) return(NULL)
  rec <- tryCatch(jsonlite::read_json(path), error = function(e) NULL)
  if (!is.list(rec) || is.null(rec$pid)) return(NULL)
  if (is.null(rec$unit)) rec$unit <- NA_character_
  rec$pid <- suppressWarnings(as.integer(rec$pid))
  rec
}

# Retire le marqueur seulement s'il est encore le NÔTRE : un run plus récent a pu
# le réécrire entre-temps, et l'effacer ferait croire son moteur absent.
.capped_marker_release <- function(path, pid) {
  rec <- .capped_marker_read(path)
  if (!is.null(rec) && identical(rec$pid, as.integer(pid))) unlink(path)
  invisible(NULL)
}

# Le scope existe-t-il encore ? NA quand systemd ne peut pas répondre.
.capped_unit_active <- function(unit) {
  if (is.null(unit) || is.na(unit) || !nzchar(unit)) return(NA)
  bin <- unname(Sys.which("systemctl"))
  if (!nzchar(bin)) return(NA)
  out <- tryCatch(
    suppressWarnings(system2(bin, c("--user", "is-active", unit),
                             stdout = TRUE, stderr = FALSE)),
    error = function(e) character())
  out <- trimws(paste(out, collapse = ""))
  if (!nzchar(out)) return(NA)
  out %in% c("active", "activating", "deactivating")
}

.capped_marker_alive <- function(rec) {
  actif <- .capped_unit_active(rec$unit)
  if (!is.na(actif)) return(actif)
  .rsen_pid_vivant(rec$pid)
}

#' Is a capped run still alive?
#'
#' Reads the run marker written by [run_memory_capped()] (`marker_path =`) and
#' asks systemd — or, without systemd, the process table — whether that run is
#' still going. A stale marker (its run is gone) is removed.
#'
#' @param marker_path Path of the JSON run marker.
#'
#' @return The marker as a list (`unit`, `pid`, `parent_pid`, `fun`, `package`,
#'   `started`) when the run is alive, otherwise `NULL`.
#'
#' @section Lifecycle:
#' Experimental.
#'
#' @seealso [stop_memory_capped()], [run_memory_capped()]
#' @export
capped_run_alive <- function(marker_path) {
  if (!is.character(marker_path) || length(marker_path) != 1L || !nzchar(marker_path)) {
    cli::cli_abort("{.arg marker_path} must be a single non-empty path.")
  }
  rec <- .capped_marker_read(marker_path)
  if (is.null(rec)) {
    if (file.exists(marker_path)) unlink(marker_path)   # illisible : périmé
    return(NULL)
  }
  if (isTRUE(.capped_marker_alive(rec))) return(rec)
  unlink(marker_path)
  NULL
}

#' Stop a capped run
#'
#' Stops the run named by a marker written by [run_memory_capped()]
#' (`marker_path =`): `systemctl --user stop` on its scope, or — without
#' systemd — `SIGTERM` to its process. The caller of [run_memory_capped()] then
#' sees its child fail, as for any other external stop.
#'
#' @param marker_path Path of the JSON run marker.
#' @param timeout Seconds to wait for the run to be gone.
#'
#' @return `TRUE` (invisibly) when a live run was stopped, `FALSE` when there was
#'   nothing to stop.
#'
#' @section Lifecycle:
#' Experimental.
#'
#' @seealso [capped_run_alive()], [run_memory_capped()]
#' @export
stop_memory_capped <- function(marker_path, timeout = 10) {
  rec <- capped_run_alive(marker_path)
  if (is.null(rec)) return(invisible(FALSE))
  bin <- unname(Sys.which("systemctl"))
  arrete <- FALSE
  if (!is.na(rec$unit) && nzchar(bin)) {
    st <- tryCatch(
      suppressWarnings(system2(bin, c("--user", "stop", rec$unit),
                               stdout = FALSE, stderr = FALSE)),
      error = function(e) 1L)
    arrete <- identical(as.integer(st), 0L)
  }
  if (!arrete && identical(.Platform$OS.type, "unix") && .rsen_pid_vivant(rec$pid)) {
    tools::pskill(rec$pid, tools::SIGTERM)
  }
  deadline <- Sys.time() + timeout
  while (isTRUE(.capped_marker_alive(rec)) && Sys.time() < deadline) Sys.sleep(0.2)
  if (isTRUE(.capped_marker_alive(rec)) && identical(.Platform$OS.type, "unix")) {
    tools::pskill(rec$pid, tools::SIGKILL)
  }
  .capped_marker_release(marker_path, rec$pid)
  invisible(TRUE)
}
