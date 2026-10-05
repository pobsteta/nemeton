# Get Family Name from Code

Returns the family name for a given family code, read from
`INDICATOR_FAMILIES` (`name_fr` / `name_en`), the single source of
truth.

## Usage

``` r
get_family_name(family_code, lang = NULL)
```

## Arguments

- family_code:

  Character. Family code (C, W, F, etc.).

- lang:

  Character. Language ("en" or "fr"). Default uses current locale.

## Value

Character. Family name, or the code itself when unknown.
