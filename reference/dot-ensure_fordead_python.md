# Ensure the FORDEAD virtualenv exists and return the loaded module

Idempotent. On first call, creates the virtualenv (via
\[reticulate::virtualenv_create()\]) and installs the pinned
dependencies from `inst/python/requirements.txt`. On subsequent calls in
the same R session, the result is cached.

## Usage

``` r
.ensure_fordead_python(
  env_name = .fordead_default_env(),
  requirements = .fordead_requirements_path(),
  verbose = TRUE
)
```

## Arguments

- env_name:

  Character. Virtualenv name. Defaults to \`nemeton-fordead\`.

- requirements:

  Character path. Pinned requirements file. Defaults to the
  package-shipped one.

- verbose:

  Logical. Print progress via \`cli\`. Default \`TRUE\`.

## Value

The imported \`fordead\` Python module (a \`python.builtin.module\`
object usable with \`\$\` syntax).

## Details

Set the env var `NEMETON_FORDEAD_ENV` to override the default virtualenv
name, e.g. for parallel test runs.
