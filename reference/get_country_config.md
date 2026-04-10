# Get country data source configuration

Loads and caches the JSON configuration for a given country.

## Usage

``` r
get_country_config(country = "FR")
```

## Arguments

- country:

  Character. ISO 3166-1 alpha-2 country code (e.g., "FR", "DE"). Use
  "EU" for pan-European fallback sources.

## Value

A list with the country's data source configuration.

## Examples

``` r
config <- get_country_config("FR")
config$crs_national  # 2154
#> [1] 2154
config$services$ign_wfs$url
#> [1] "https://data.geopf.fr/wfs/ows"
```
