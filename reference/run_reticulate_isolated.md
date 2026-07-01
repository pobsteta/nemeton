# Run a Python/reticulate task in an isolated subprocess (pinned env)

Runs `fun` in a fresh callr R subprocess whose reticulate is pinned to a
specific Python interpreter (`python` / `virtualenv` / `condaenv`). The
subprocess starts with an **unbound** reticulate, so it always binds to
the requested environment — even if the parent session already bound
reticulate to a different Python (another env, Theia, or reticulate's uv
ephemeral default). This lets several Python workloads that need
*different* environments coexist in one app session without the
single-binding conflict, and **without** a global `RETICULATE_PYTHON`
(which can only serve one env).

`R_ENVIRON_USER = ""` is set for the subprocess so a `RETICULATE_PYTHON`
in the user's `~/.Renviron` cannot override the pin.

`fun` must be self-contained (callr serialises it): qualify packages
explicitly (`pkg::fn`) and pass everything via `args`. Return values and
`args` must be serialisable — exchange rasters as **file paths**, not
in-memory `SpatRaster` objects.

Falls back to running `fun` **in-process** when callr is missing or no
Python could be resolved (a `cli_warn` is emitted in the latter case).

## Usage

``` r
run_reticulate_isolated(fun, args = list(), python = NULL,
  virtualenv = NULL, condaenv = NULL, show = TRUE)
```

## Arguments

- fun:

  A function to run in the subprocess.

- args:

  A named list of arguments passed to `fun`.

- python:

  Direct path to a Python interpreter (highest priority).

- virtualenv:

  A virtualenv name (resolved via
  [`reticulate::virtualenv_python()`](https://rstudio.github.io/reticulate/reference/virtualenv-tools.html)).

- condaenv:

  A conda env name (resolved via
  [`reticulate::conda_python()`](https://rstudio.github.io/reticulate/reference/conda-tools.html),
  with a fallback over the usual conda/mamba install roots).

- show:

  Stream the subprocess output to the console (default `TRUE`) — the way
  to surface progress, since R callbacks cannot cross the process
  boundary.

## Value

Whatever `fun` returns.
