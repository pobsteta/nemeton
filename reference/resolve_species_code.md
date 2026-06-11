# Resolve a species code to a row-group in the curves

Given a raw species code, returns the code actually available in the
reference CSV. If the species is directly present, returns it unchanged.
Otherwise falls back to `CONIFER_GENUS` or `BROADLEAF_GENUS` based on
the internal `.conifer_codes` list (used by
[`is_conifer`](https://pobsteta.github.io/nemeton/reference/is_conifer.md)).

## Usage

``` r
resolve_species_code(species, available)
```

## Arguments

- species:

  Character. Species code (length 1).

- available:

  Character vector of species codes present in the curves.

## Value

Character scalar - the resolved species code, or `NA_character_` if
neither the species nor its genus-level fallback is available.
