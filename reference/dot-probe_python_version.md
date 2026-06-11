# Parse a Python interpreter's version string via \`python –version\`

Runs \`\<py_path\> –version\` and extracts the major.minor numeric
version. Robust to "Python 3.12.3" on stdout (Python ≥ 3.4) or stderr
(older builds). Returns \`NA_numeric_version\_\` if the interpreter is
unreachable or the output is unparseable.

## Usage

``` r
.probe_python_version(py_path)
```

## Arguments

- py_path:

  Character path to a Python interpreter.

## Value

A \[numeric_version\] of length 1 (possibly NA).
