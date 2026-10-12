# Load a FORMS-T canopy-height time series over an area

Reads the FORMS-T canopy height (Theia, 10 m, centimetres) for several
years and returns one layer per year, on a common grid, cropped to
`aoi`. This is the input of the measured path of
[`indicateur_t2_changement()`](https://pobsteta.github.io/nemeton/reference/indicateur_t2_changement.md)
(spec 060).

## Usage

``` r
charger_forms_t_hauteurs(aoi, annees = 2019:2024, dossier = NULL, country = "FR")
```

## Arguments

- aoi:

  An `sf`/`sfc` area of interest (any CRS).

- annees:

  Integer vector of years. Default `2019:2024`, the years published at
  the time of writing.

- dossier:

  Directory holding local `Height_<year>.tif` files. Default `NULL`: the
  `NEMETON_FORMS_T_DIR` environment variable, and Theia when it is unset
  or a year is missing there.

- country:

  Character. ISO country code. Default `"FR"` (FORMS-T covers
  metropolitan France only).

## Value

A
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
in centimetres, one layer per year read, named by year and sorted
chronologically; `NULL` (with a warning) when fewer than three years
could be read.

## Details

Each year is read from a local copy of the national rasters when one is
available (`dossier`, files `Height_<year>.tif` as published on Zenodo),
otherwise from the Theia STAC catalogue through
[`load_theia_source()`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md)
(THEIA API key required, see `theia_sign_urls()`). A year that cannot be
read is skipped with a warning.

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).

## See also

[`indicateur_t2_changement()`](https://pobsteta.github.io/nemeton/reference/indicateur_t2_changement.md)

## Examples

``` r
if (FALSE) { # \dontrun{
h <- charger_forms_t_hauteurs(parcelles, annees = 2019:2024)
t2 <- indicateur_t2_changement(parcelles, forms_t = h)
} # }
```
