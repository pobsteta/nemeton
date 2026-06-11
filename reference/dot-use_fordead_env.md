# Switch reticulate to the FORDEAD virtualenv

Calls \[reticulate::use_virtualenv()\] with \`required = TRUE\`. The
virtualenv must already exist — see \[.ensure_fordead_python()\] which
creates it on first use.

## Usage

``` r
.use_fordead_env(env_name = .fordead_default_env())
```

## Arguments

- env_name:

  Character. Name of the virtualenv. Defaults to
  \`Sys.getenv("NEMETON_FORDEAD_ENV", "nemeton-fordead")\`.

## Value

Invisibly \`env_name\`.

## Details

Handles a notorious reticulate quirk: when the \`RETICULATE_PYTHON\`
environment variable is set (e.g. by a user's \`.Renviron\` pointing at
a conda env for another project), it silently overrides \`use_python()\`
/ \`use_virtualenv()\` even with \`required = TRUE\`. We work around
this in two phases:

\* If Python is \*\*not yet initialised\*\* in the session, we mask
\`RETICULATE_PYTHON\` for the duration of the \`use_virtualenv()\` call
(the var is restored on exit so other reticulate consumers — e.g.
OpenCanopy CHM operations from spec 005 — are unaffected for the rest of
their work, though Python's binding is now fixed for the session). \* If
Python is \*\*already initialised\*\* to a \*different\* binary, the
in-process switch is impossible (reticulate caches the binding once
Python is initialised). We surface a clear, actionable error pointing
the user at the env var.
