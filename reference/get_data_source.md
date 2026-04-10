# Get data source URL or configuration

Returns the URL or configuration for a specific data source in a
country.

## Usage

``` r
get_data_source(source_key, country = "FR", section = NULL)
```

## Arguments

- source_key:

  Character. The data source key (e.g., "dem", "roads", "ortho_irc",
  "oso", "cadastre_api").

- country:

  Character. ISO country code. Default "FR".

- section:

  Character. Configuration section to search in. One of "layers",
  "datasets", "services", "communes". Default: auto-detect.

## Value

A list with the source configuration, or NULL if not found.

## Examples

``` r
# Get DEM layer config for France
dem <- get_data_source("dem", "FR")
dem$layer  # "ELEVATION.ELEVATIONGRIDCOVERAGE"
#> [1] "ELEVATION.ELEVATIONGRIDCOVERAGE"

# Get OSO dataset URL
oso <- get_data_source("oso", "FR")
oso$url
#> [1] "https://entrepot.recherche.data.gouv.fr/api/access/datafile/:persistentId?persistentId=doi:10.57745/8M1AN1"
```
