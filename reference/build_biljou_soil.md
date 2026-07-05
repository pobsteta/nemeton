# Build the BILJOU soil object for management units

Produce the `sol` input of
[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
— a
[`biljou_soil`](https://pobsteta.github.io/biljouR/reference/biljou_soil.html)
object (extractable water `ewm`, root fractions, macro/micro porosity,
initial fill). A single soil is returned (shared across the
`biljou_run_grid()` points, as the engine expects). With no fine soil
reference (RRP / BDGSF / European Soil DB), a sensible uniform default
is used — the app already exposes an `ewm` default (150 mm) usable as a
fallback.

## Usage

``` r
build_biljou_soil(
  units = NULL,
  ewm = 150,
  roots = NULL,
  macro = NULL,
  micro = NULL,
  init = 1,
  ...
)
```

## Arguments

- units:

  An sf/sfc of the management units (currently used for count / future
  per-region soil lookup; the returned soil is uniform).

- ewm:

  Maximum extractable water (mm). Default `150`.

- roots, macro, micro, init:

  Passed to
  [`biljou_soil`](https://pobsteta.github.io/biljouR/reference/biljou_soil.html)
  (root fractions, macro/micro porosity, initial fill fraction).

- ...:

  Ignored (forward-compat).

## Value

A `biljou_soil` object, or `NULL` when biljouR is unavailable.

## See also

[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md),
[`load_biljou_forcing`](https://pobsteta.github.io/nemeton/reference/load_biljou_forcing.md)
