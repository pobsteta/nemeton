# Reference biological production to apply to a stand

Averages the production estimate of a sylvoecoregion over its most
recent campaigns (spec 054 D8), falling back to the GRECO then to the
national figure when the SER is unknown or absent. The level and the
nature of the estimate are reported, never hidden.

The value is that of the **domain**, not of the stand: a stand inherits
the production of its SER.

## Usage

``` r
ifn_production_reference(ser = NULL,
  attribut = c("pv", "pg", "prel", "prel_vidange"),
  groupe = c("tous", "feuillus", "resineux"), n_campagnes = 5L,
  campagnes = NULL, niveaux = c("ser", "greco", "national"), min_plac = 30)
```

## Arguments

- ser:

  SER code, a single string (e.g. `"C30"`), or `NULL` for the national
  figure.

- attribut:

  `"pv"` (default, m3/ha/yr), `"pg"` (m2/ha/yr), `"prel"` or
  `"prel_vidange"` (harvest, m3/ha/yr; see
  [`ifn_production_ser`](https://pobsteta.github.io/nemeton/reference/ifn_production_ser.md)).

- groupe:

  `"tous"` (default), `"feuillus"` or `"resineux"`.

- n_campagnes:

  Number of most recent campaigns to average. Default `5`.

- campagnes:

  Explicit campaign years; overrides `n_campagnes`.

- niveaux:

  Levels the fallback may use, in this order. Default all three;
  restrict it to pin a level (e.g. to align two flows).

- min_plac:

  Minimum number of plots, summed over the campaign window, for a
  **direct** estimate to qualify a SER or GRECO level; below it the
  fallback moves up. Fay-Herriot estimates are not subject to it.
  Default `30`, as in
  [`ifn_volume_reference`](https://pobsteta.github.io/nemeton/reference/ifn_volume_reference.md).

## Value

A one-row data.frame: `ser`, `attribut`, `groupe`, `valeur`, `mse`,
`rse`, `niveau_utilise`, `nature` (the natures of the averaged rows,
collapsed), `campagnes` (collapsed), `n_campagnes`. The MSE of the mean
assumes independence between campaigns; it is a lower bound.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## See also

[`ifn_production_ser`](https://pobsteta.github.io/nemeton/reference/ifn_production_ser.md).

## Examples

``` r
if (FALSE) { # \dontrun{
ifn_production_reference("C30")
ifn_production_reference("C30", attribut = "pg", groupe = "resineux")
} # }
```
