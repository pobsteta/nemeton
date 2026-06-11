# Run \`python -c \<code\>\` and capture stdout

Thin wrapper over \[base::system2()\] with \`stdout = TRUE\`. Exists so
tests can mock the captured output without dealing with \`system2\`
directly (mirrors \[.fordead_python_import_ok()\]).

## Usage

``` r
.python_capture_stdout(py_path, code)
```

## Arguments

- py_path:

  Character path to a Python interpreter.

- code:

  Character. Python statement(s) to execute.

## Value

Character vector of stdout lines (possibly empty on error).

## Details

\`system2()\` pastes \`args\` into a single shell command line without
quoting, so \`code\` MUST be \[shQuote()\]d here — otherwise spaces,
\`;\` and \`()\` in the Python snippet are word-split / interpreted by
the shell and the snippet never reaches the interpreter intact.
