# List available indicators

Returns a character vector of available indicator names.

## Usage

``` r
list_indicators(category = "all", return_type = c("names", "details"))
```

## Arguments

- category:

  Character. Filter by category: "all", "biophysical", "social",
  "landscape". Default "all".

- return_type:

  Character. Return "names" (default) or "details" (data.frame with
  descriptions)

## Value

Character vector of indicator names or data.frame with details

## Examples

``` r
if (FALSE) { # \dontrun{
# Get all indicator names
list_indicators()

# Get details
list_indicators(return_type = "details")
} # }
```
