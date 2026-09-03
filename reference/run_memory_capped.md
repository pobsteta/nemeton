# Run a heavy pipeline in a memory-capped child process

Runs a function of `package` (an export **or** an internal, resolved via
[`asNamespace`](https://rdrr.io/r/base/ns-internal.html)) in a **child R
process** placed in a transient, memory-capped cgroup. A run that
overshoots then dies **alone**, with an ordinary error the caller can
report — instead of having `systemd-oomd` kill the entire application
scope (the R session, the Shiny app, the terminals) for being the
biggest thing under memory pressure.

Use it for the pipelines whose memory lives *inside* the R process and
so cannot be capped in place:
[`run_fordead_dieback`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
(Python through reticulate's embedded interpreter) and the reGénération
engines (plain R). The latter live in `nemetonshiny` — hence `package`
and `options` (to reach an internal worker and to seed session options
such as `nemeton.app_options` across the boundary).
[`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
does **not** need it — it already caps the Python subprocess it spawns.

## Usage

``` r
run_memory_capped(
  fun,
  args = list(),
  package = "nemeton",
  db_url = NULL,
  options = NULL,
  progress_path = NULL,
  progress_callback = NULL,
  memory_max = NULL,
  poll_ms = 500L,
  quiet = FALSE,
  log_path = NULL
)
```

## Arguments

- fun:

  Name of the function to run, in `package` (character). May be internal
  (not exported).

- args:

  Named list of arguments. Must be serialisable: no connections, no
  closures, no `SpatRaster` — pass file paths.

- package:

  Package the child loads and resolves `fun` from. Default `"nemeton"`.
  Use e.g. `"nemetonshiny"` to cap an app-side worker.

- db_url:

  Database URL. When given, the child opens a connection and passes it
  to `fun` as `con` (only if `fun` takes a `con` argument).

- options:

  Named list of session options set in the child (via
  [`options`](https://rdrr.io/r/base/options.html)) before calling
  `fun`. Use for options the worker reads but that do not cross the
  process boundary, e.g. `list(nemeton.app_options = ...)`.

- progress_path:

  Path of the progress `.json` file. When given, the child passes `fun`
  a callback writing there.

- progress_callback:

  Parent-side callback, fed by replaying the child's events (requires
  `progress_path`).

- memory_max:

  Ceiling as a systemd size string (e.g. `"12G"`), or `FALSE` to disable
  it. Default (`NULL`): **40% of `MemTotal`**, unless
  `options(nemeton.memory_max)` or the `NEMETON_MEMORY_MAX` environment
  variable says otherwise — one policy, shared with the RECONFORT
  subprocess cap. The fraction is not a guess: on the reference
  workstation `systemd-oomd` was observed killing the session at 17.1 GB
  of 31.2 GB, then at 14.5 GB three months later — a trip point that
  MOVES with what else the desktop is doing. A ceiling that can only
  trip after the OOM killer has acted is not a ceiling, so the fraction
  sits under both figures and above the heaviest run measured here (11.3
  GB). See `R/memory-ceiling.R` for the full argument and the escape
  hatches.

- poll_ms:

  How often to poll the child for progress, in milliseconds.

- quiet:

  Suppress the child's console output.

- log_path:

  Path of a file capturing the child's stdout **and** stderr (merged).
  Default (`NULL`): the child's output follows the parent's, which is
  right on a console and **wrong under a `future` worker** —
  `parallelly` starts those with `OUT=/dev/null`, so the child's
  traceback goes to the bit bucket and a 20-hour failure leaves no
  message at all (incident Couchey, 2026-09-03). Give a path and the
  output is kept whatever becomes of the child; the failure message then
  cites the file and quotes its last lines. Takes precedence over
  `quiet`.

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
