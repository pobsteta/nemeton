# Latest available French NFI campaign

Probes the IGN download server for the most recent annual export,
walking back year by year from `depuis`.

This is deliberately dynamic. `FrenchNFIfindeR` pins the URL to the
2005-2023 export in its source, and is therefore one campaign behind as
soon as the IGN publishes a new one — which it does every autumn.

## Usage

``` r
ifn_campagne_disponible(depuis = NULL, back = 5L)
```

## Arguments

- depuis:

  Year to start probing from. Defaults to the current year.

- back:

  How many years to walk back before giving up. Default `5`.

## Value

A list with `campagne` (integer, the last campaign covered), `millesime`
(e.g. `"2005-2024"`) and `url`.

## Examples

``` r
if (FALSE) { # \dontrun{
ifn_campagne_disponible()
} # }
```
