# Smart Map for Spatial Data with Row Indices

Convenience wrapper for spatial operations where the function operates
on row indices of an sf object. Automatically passes the sf object to
each worker in parallel mode.

## Usage

``` r
smart_map_sf(
  sf_data,
  fn,
  ...,
  complexity = "medium",
  threshold = NULL,
  workers = NULL,
  progress = NULL,
  .type = "list"
)
```

## Arguments

- sf_data:

  An sf object.

- fn:

  Function that takes (index, sf_data) and returns a value.

- ...:

  Additional arguments passed to \`fn\`.

- complexity:

  Character. Operation complexity level: \`"very_low"\`, \`"low"\`,
  \`"medium"\` (default), \`"high"\`, \`"very_high"\`. See
  \[smart_map()\] for details.

- threshold:

  Integer or NULL. Explicit threshold. If NULL, uses \`complexity\`.

- workers:

  Integer. Number of workers. Default auto-detected.

- progress:

  Logical. Show progress? Default TRUE for n \> 50.

- .type:

  Character. Return type: "list", "dbl", "chr", "lgl", "int".

## Value

A list or vector of results.

## Examples

``` r
if (FALSE) { # \dontrun{
# Calculate indicator for each parcel (medium complexity = spatial ops)
parcelles$indicator <- smart_map_sf(parcelles, function(i, data) {
  geom <- sf::st_geometry(data[i, ])
  # ... spatial calculation ...
  return(value)
}, complexity = "medium", .type = "dbl")

# WFS query per parcel (high complexity)
parcelles$zones <- smart_map_sf(parcelles, function(i, data) {
  query_wfs(data[i, ])
}, complexity = "high")
} # }
```
