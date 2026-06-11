# Fetch a single STAC item by id

Retrieves one item from a STAC API by its collection and item id
(`<stac_api>/collections/<collection>/items/<item_id>`). Used to target
a specific item — e.g. a given year of an annual time-series collection
such as FORMSpoT.

## Usage

``` r
stac_get_item(stac_api, collection, item_id)
```

## Arguments

- stac_api:

  Character. Root URL of the STAC API.

- collection:

  Character. STAC collection id.

- item_id:

  Character. STAC item id.

## Value

The STAC item feature (a parsed JSON object).

## Examples

``` r
if (FALSE) { # \dontrun{
item <- stac_get_item("https://api.stac.teledetection.fr",
                      "FORMSpoT", "FORMSpoT-2023")
} # }
```
