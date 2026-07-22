# Mobilisable timber volume for road-network sizing

Turns the P1 standing-volume indicator into the volume column expected
by the `foretaccess` road-network engines, applying a harvest rate over
a planning horizon and converting to the unit the downstream consumer
needs.

No volume is computed here:
[`indicateur_p1_volume`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
remains the single owner of the IFN tarif. This function only converts
and weights.

## Usage

``` r
volume_mobilisable(units, volume_col = "P1", unite = c("m3_total", "m3_ha"),
  taux_prelevement = NULL, horizon_ans = NULL, espar_field = "espar",
  ser = NULL, min_plac = 30, na_policy = c("na", "zero", "error"),
  column_name = "volume_mobilisable")
```

## Arguments

- units:

  An `sf` object carrying the P1 column.

- volume_col:

  Name of the standing-volume column, in m3/ha, as produced by
  [`indicateur_p1_volume`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md).
  Default `"P1"`.

- unite:

  Output unit: `"m3_total"` (default, for `calculer_flux()`) or
  `"m3_ha"` (for `reseau_desserte()` / `optimiser_reseau()`).

- taux_prelevement:

  Harvest rate in m3/ha/year: a single number applied to every unit, or
  a numeric vector of `nrow(units)`. `NULL` (default) resolves it per
  unit from the IFN table via
  [`ifn_taux_prelevement`](https://pobsteta.github.io/nemeton/reference/ifn_taux_prelevement.md),
  which then requires `espar_field`.

- espar_field:

  Name of the column holding the IFN species code, used only when
  `taux_prelevement` is `NULL`.

- ser:

  SER code for the units, a single string, used only when
  `taux_prelevement` is `NULL`. `NULL` falls back to national rates.

- min_plac:

  Minimum plots for an IFN mesh level to qualify, passed to
  [`ifn_taux_prelevement`](https://pobsteta.github.io/nemeton/reference/ifn_taux_prelevement.md).

- horizon_ans:

  Planning horizon in years. Required whenever `taux_prelevement` is
  supplied.

- na_policy:

  What to do with units whose volume is `NA` — typically the NDP 0 case,
  where P1 has neither field inventory nor CHM. `"na"` (default)
  propagates `NA` and warns; `"zero"` maps them to 0 (**paints an
  uninventoried parcel as "nothing to haul"**); `"error"` aborts.

- column_name:

  Name of the added column. Default `"volume_mobilisable"`.

## Value

`units` with the `column_name` column added.

## Choosing `unite`

The two `foretaccess` consumers of `volume_champ` expect **opposite**
semantics, and neither raises an error on the wrong one:

- `calculer_flux()` splits the parcel volume across its source points
  and accumulates it down the network — it expects a **total in m3**
  (`unite = "m3_total"`);

- `reseau_desserte()` / `optimiser_reseau()` rasterise the column onto
  the grid, one value per cell — they expect a **density in m3/ha**
  (`unite = "m3_ha"`). A total there would be counted once per cell,
  mechanically over-weighting large parcels.

## Harvest rate

`taux_prelevement` is a **yearly flux** in m3/ha/year, not a fraction,
so `horizon_ans` is required with it:
`volume = P1 x taux x horizon_ans`. A harvest rate describes what **has
been** removed, not what **should** be; sizing a road network on it
assumes management carries on unchanged.

`taux_prelevement = NULL` resolves the rate from the IFN species x
sylvoecoregion table
([`ifn_taux_prelevement`](https://pobsteta.github.io/nemeton/reference/ifn_taux_prelevement.md)),
which requires `espar_field` on `units` — the IFN species code. The
level actually used (SER, GRECO or national) is reported through the
`niveau_prelevement` attribute of the returned object, never silently.

## See also

[`indicateur_p1_volume`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
for the volume itself.

## Examples

``` r
if (FALSE) { # \dontrun{
units <- indicateur_p1_volume(units)

# For calculer_flux(): a total in m3 over a 10-year horizon.
units <- volume_mobilisable(units, taux_prelevement = 4, horizon_ans = 10)

# For reseau_desserte(): the same rate as a density.
units <- volume_mobilisable(units, unite = "m3_ha",
                            taux_prelevement = 4, horizon_ans = 10)
} # }
```
