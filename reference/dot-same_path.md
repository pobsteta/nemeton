# Compare two filesystem paths for equality

Robust to symlinks, trailing slashes, and \`~\` expansion via
\[normalizePath()\] with \`mustWork = FALSE\` (so a non-existent path
doesn't error — useful when comparing a configured value to a venv that
may not be created yet).

## Usage

``` r
.same_path(a, b)
```

## Arguments

- a, b:

  Character paths.

## Value

Logical(1).
