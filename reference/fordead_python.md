# FORDEAD Python Environment Helpers (E6.c.1, spec 008)

Manage the isolated Python virtual environment that hosts the `fordead`
pipeline used by \[run_fordead_dieback()\]. The env lives in
`~/.virtualenvs/nemeton-fordead` by default and is created lazily on
first use; subsequent calls are idempotent.

Python \\\geq\\ 3.11 is required (by the pinned stack). The dependency
list lives in `inst/python/requirements.txt`: every package is pinned to
an exact version (the \`pip freeze\` of the validated venv), no open
bound.
