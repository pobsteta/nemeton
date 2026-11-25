# Is the Rust core of nemeton available?

\`TRUE\` when the package was installed with its Rust crate compiled
\*\*and\*\* the option \`nemeton.rust\` is not set to \`FALSE\`. When
\`FALSE\`, functions that have a Rust implementation (currently
\[reconfort_indices()\]) use their pure-R fallback, which returns the
same values.

## Usage

``` r
nemeton_rust_disponible()
```

## Value

A single logical.

## Examples

``` r
nemeton_rust_disponible()
#> [1] TRUE
withr::with_options(list(nemeton.rust = FALSE), nemeton_rust_disponible())
#> [1] FALSE
```
