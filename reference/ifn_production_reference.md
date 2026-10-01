# Reference biological production to apply to a stand

Averages the production estimate of a sylvoecoregion over its most
recent campaigns (spec 054 D8), falling back to the GRECO then to the
national figure when the SER is unknown or absent. The level and the
nature of the estimate are reported, never hidden.

The value is that of the **domain**, not of the stand: a stand inherits
the production of its SER.

## Usage

``` r
ifn_production_reference(ser = NULL, attribut = c("pv", "pg"),
  groupe = c("tous", "feuillus", "resineux"), n_campagnes = 5L,
  campagnes = NULL)
```

## Arguments

- ser:

  SER code, a single string (e.g. `"C30"`), or `NULL` for the national
  figure.

- attribut:

  `"pv"` (default, m3/ha/yr) or `"pg"` (m2/ha/yr).

- groupe:

  `"tous"` (default), `"feuillus"` or `"resineux"`.

- n_campagnes:

  Number of most recent campaigns to average. Default `5`.

- campagnes:

  Explicit campaign years; overrides `n_campagnes`.

## Value

A one-row data.frame: `ser`, `attribut`, `groupe`, `valeur`, `mse`,
`rse`, `niveau_utilise`, `nature` (the natures of the averaged rows,
collapsed), `campagnes` (collapsed), `n_campagnes`. The MSE of the mean
assumes independence between campaigns; it is a lower bound.

## See also

[`ifn_production_ser`](https://pobsteta.github.io/nemeton/reference/ifn_production_ser.md).

## Examples

``` r
if (FALSE) { # \dontrun{
ifn_production_reference("C30")
ifn_production_reference("C30", attribut = "pg", groupe = "resineux")
} # }
```
