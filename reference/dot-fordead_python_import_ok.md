# Run \`python -c "import \<module\>"\` in an external interpreter

Thin wrapper over \[base::system2()\] used to probe whether a Python
module is importable from a specific interpreter, without loading it
into the current reticulate session. Exists so tests can mock the system
call without dealing with \`system2\` directly.

## Usage

``` r
.fordead_python_import_ok(py_path, module = "fordead")
```

## Arguments

- py_path:

  Character path to a Python interpreter.

- module:

  Module name to import (default \`"fordead"\`).

## Value

\`TRUE\` if the import succeeded (exit code 0), \`FALSE\` otherwise
(non-zero exit, signal, or any error).
