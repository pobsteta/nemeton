# Read a CV value from the typology table

Read a CV value from the typology table

## Usage

``` r
cv_lookup(context_key, position = c("mid", "low", "high"), table = NULL)
```

## Arguments

- context_key:

  Character. One of `cv_typology()$context_key`.

- position:

  Character. Which bound to read: `"low"`, `"mid"` (default, central
  estimate), or `"high"` (conservative).

- table:

  Optional override table (returned by
  [`cv_typology`](https://pobsteta.github.io/nemeton/reference/cv_typology.md)).

## Value

Numeric CV (fraction).
