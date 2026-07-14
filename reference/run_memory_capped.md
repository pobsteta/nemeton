# Run a heavy nemeton pipeline in a memory-capped child process

Runs an exported `nemeton` function in a **child R process** placed in a
transient, memory-capped cgroup. A run that overshoots then dies
**alone**, with an ordinary error the caller can report — instead of
having `systemd-oomd` kill the entire application scope (the R session,
the Shiny app, the terminals) for being the biggest thing under memory
pressure.

Use it for the pipelines whose memory lives *inside* the R process and
so cannot be capped in place:
[`run_fordead_dieback`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
(Python through reticulate's embedded interpreter) and the reGénération
engines (plain R).
[`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
does **not** need it — it already caps the Python subprocess it spawns.

## Usage

``` r
run_memory_capped(
  fun,
  args = list(),
  db_url = NULL,
  progress_path = NULL,
  progress_callback = NULL,
  memory_max = NULL,
  poll_ms = 500L,
  quiet = FALSE
)
```

## Arguments

- fun:

  Name of the exported `nemeton` function to run (character).

- args:

  Named list of arguments. Must be serialisable: no connections, no
  closures, no `SpatRaster` — pass file paths.

- db_url:

  Database URL. When given, the child opens a connection and passes it
  to `fun` as `con`.

- progress_path:

  Path of the progress `.json` file. When given, the child passes `fun`
  a callback writing there.

- progress_callback:

  Parent-side callback, fed by replaying the child's events (requires
  `progress_path`).

- memory_max:

  Ceiling as a systemd size string (e.g. `"12G"`). Default: 70% of RAM,
  or `options(nemeton.reconfort_memory_max)`. `FALSE` disables it.

- poll_ms:

  How often to poll the child for progress, in milliseconds.

- quiet:

  Suppress the child's console output.

## Value

Whatever `fun` returned.

## Details

Two arguments cannot be serialised across a process boundary, and are
therefore rebuilt in the child rather than passed:

- **`con`** — a `DBIConnection` is not serialisable. Pass `db_url` and
  the child opens (and closes) its own via
  [`db_connect`](https://pobsteta.github.io/nemeton/reference/db_connect.md).

- **`progress_callback`** — a closure is not serialisable either. Pass
  `progress_path`: the child writes each event to `<path>.json` (last
  event, written atomically) and appends it to `<path>.ndjson`, and the
  parent tails that file and replays every event into the
  `progress_callback` you gave here. Callers therefore keep receiving
  events as before — including any side effects of their callback, such
  as push notifications.

Without `systemd-run` (non-Linux, container with no user bus, CI) the
work still runs in a child process — whose memory at least returns to
the OS on exit — but **uncapped**, with a warning. Without a cgroup, an
overshoot is once again the whole scope's problem.

## See also

[`run_fordead_dieback`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md),
[`run_reticulate_isolated`](https://pobsteta.github.io/nemeton/reference/run_reticulate_isolated.md)
(which pins a Python env rather than capping memory),
[`scratch_dir`](https://pobsteta.github.io/nemeton/reference/scratch_dir.md)

## Examples

``` r
if (FALSE) { # \dontrun{
res <- run_memory_capped(
  "run_fordead_dieback",
  args       = list(zone_id = 9L, cache_dir = "~/cache"),
  db_url     = Sys.getenv("NEMETON_DB_URL"),
  memory_max = "12G"
)
} # }
```
