# Install the pinned FORDEAD requirements, surfacing pip's real error

[`reticulate::virtualenv_install()`](https://rstudio.github.io/reticulate/reference/virtualenv-tools.html)
runs pip but, on a non-zero exit, raises the generic and near-useless
message `"Error installing package(s): "` — the actual pip diagnostic
(the line that tells you \*why\* the install failed: a missing `git` for
the `git+https` pins, an unreachable `gitlab.com` / `forge.inrae.fr`, a
wheel that won't build, …) is lost. That left users staring at an empty
error (cf. the Windows report 2026-06-23).

## Usage

``` r
.fordead_pip_install(env_name, requirements, verbose = TRUE)
```

## Arguments

- env_name:

  Character. Virtualenv name.

- requirements:

  Character path to the pinned requirements file.

- verbose:

  Logical. Echo pip output once captured. Default \`TRUE\`.

## Value

Invisibly \`TRUE\` on success; aborts otherwise.

## Details

This helper runs pip directly in the venv's interpreter, captures the
combined stdout+stderr, and on failure re-raises a
[`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
carrying the tail of pip's own output plus the most common offline /
Windows causes. On success it returns invisibly, echoing the captured
output when \`verbose\`.
