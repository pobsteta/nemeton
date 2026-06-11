# Probe the installed fordead version in a virtualenv

Reads the \*distribution\* version via
\`importlib.metadata.version("fordead")\` — the canonical source. Note:
the \`fordead.version\` attribute is a \*function\*, not a version
string, so \`print(fordead.version)\` yields a \`\<function …\>\` repr.
Probing that made the installed version never match the pin, triggering
a spurious \`pip install\` on every pipeline run. Returns
\`NA_character\_\` when fordead isn't installed or the call fails.

## Usage

``` r
.fordead_python_version(env_name)
```

## Arguments

- env_name:

  Character. Virtualenv name.

## Value

Character(1) — installed version, or \`NA\`.
