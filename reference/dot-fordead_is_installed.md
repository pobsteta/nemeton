# Check whether \`fordead\` is actually importable in the given venv

Returns \`TRUE\` when the venv exists, its Python can \`import
fordead\`, AND — when a \`requirements_path\` is provided — the
installed fordead version matches the pin. This last check is the
recovery mechanism for cases where a previous nemeton release pinned a
different fordead version (e.g. v0.22.2..v0.22.4 pinned v2.1.1, v0.22.5
downgrades to v1.11.4): without it, \`.ensure_fordead_python\` would see
fordead as "installed" and skip the upgrade, leaving the user with a
wrong-API fordead in their venv.

## Usage

``` r
.fordead_is_installed(env_name, requirements_path = NULL)
```

## Arguments

- env_name:

  Character. Virtualenv name.

- requirements_path:

  Optional character path to the pinned requirements file. When
  supplied, the version is compared against the pin and a mismatch
  returns \`FALSE\` (with a \`cli::cli_alert_warning\` so the user knows
  why a reinstall is about to happen).

## Value

Logical(1).
