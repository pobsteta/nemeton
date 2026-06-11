# Probe PATH for a Python ≥ 3.10 interpreter

Walks a list of conventional Python binary names from newest to oldest
(3.14 → 3.10 → generic \`python3\` → \`python\`) and returns the first
one that exists on \`PATH\` AND reports a version ≥ 3.10.

## Usage

``` r
.find_python_on_path()
```

## Value

Character path (string) to a Python ≥ 3.10 interpreter, or \`""\` if
nothing matches.

## Details

Used as a fallback when \[reticulate::py_discover_config()\] returns
nothing useful — for instance because the user just removed
\`RETICULATE_PYTHON\` from their \`.Renviron\` and reticulate's internal
discovery hasn't kicked in.
