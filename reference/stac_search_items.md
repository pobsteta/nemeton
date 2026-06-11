# Search a STAC API for items

Endpoint-agnostic STAC item search: POSTs a search request to a STAC API
`/search` endpoint and returns the matching item features. Pagination is
handled by the project-wide STAC paginator.

## Usage

``` r
stac_search_items(stac_api, collection, bbox, datetime = NULL, limit = 100L)
```

## Arguments

- stac_api:

  Character. Root URL of the STAC API (the `/search` suffix is appended
  automatically).

- collection:

  Character. STAC collection id to query.

- bbox:

  Numeric length 4: `c(xmin, ymin, xmax, ymax)` in WGS84.

- datetime:

  Optional character. A STAC datetime filter — a single instant, a
  closed interval `"start/end"`, or a half-open one (`"start/.."`).
  `NULL` = no time filter.

- limit:

  Integer. Maximum number of items to return. Default `100`.

## Value

A list of STAC item features (parsed JSON objects).

## Examples

``` r
if (FALSE) { # \dontrun{
items <- stac_search_items(
  "https://stac.example.org", "forms-t",
  bbox = c(6.0, 47.8, 6.3, 48.0), datetime = "2023-01-01/2023-12-31"
)
} # }
```
