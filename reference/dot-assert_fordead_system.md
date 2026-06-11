# Assert reticulate is available and Python \>= 3.10 is installed

Raises a \`cli::cli_abort\` with installation hints when reticulate is
missing, when Python cannot be found, or when the discovered interpreter
is older than 3.10.

## Usage

``` r
.assert_fordead_system()
```

## Value

Invisibly the resolved Python interpreter path (string).

## Details

Discovery is two-pronged: first ask reticulate via
\[reticulate::py_discover_config()\] (which honours
\`RETICULATE_PYTHON\` and reticulate's pinned config). If that returns
nothing useful — a real failure mode when the user has just unset
\`RETICULATE_PYTHON\` or when reticulate's config cache is stale — fall
back to \[.find_python_on_path()\] which probes \`Sys.which()\`
directly.

We don't need reticulate to be initialised against the discovered
interpreter at this point; we only need to know that a 3.10+ Python is
reachable so the FORDEAD venv can be built from it.
