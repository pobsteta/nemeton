# Build the BILJOU soil object(s) for management units

Produce the `sol` input of
[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
— one or several
[`biljou_soil`](https://pobsteta.github.io/biljouR/reference/biljou_soil.html)
objects (extractable water `ewm`, root fractions, macro/micro porosity,
initial fill).

## Usage

``` r
build_biljou_soil(
  units = NULL,
  ewm = 150,
  source = c("uniform", "soilgrids"),
  rooting_depth_cm = 100,
  country = "FR",
  roots = NULL,
  macro = NULL,
  micro = NULL,
  init = 1,
  progress_callback = NULL,
  ...
)
```

## Arguments

- units:

  An sf/sfc of the management units. Required when
  `source = "soilgrids"`.

- ewm:

  Maximum extractable water (mm). Default `150`. Under
  `source = "uniform"` it is the reserve per soil layer (length 1-3);
  under `source = "soilgrids"` it is only the per-unit fallback value.

- source:

  `"uniform"` (default, shared soil) or `"soilgrids"` (per-unit soil
  from SoilGrids + pedotransfer).

- rooting_depth_cm:

  Rooting depth in cm passed to
  [`ewm_depuis_soilgrids`](https://pobsteta.github.io/nemeton/reference/ewm_depuis_soilgrids.md)
  (default 100). Ignored under `source = "uniform"`.

- country:

  ISO country code for the datasource lookup. Default `"FR"`.

- roots, macro, micro, init:

  Passed to
  [`biljou_soil`](https://pobsteta.github.io/biljouR/reference/biljou_soil.html)
  (root fractions, macro/micro porosity, initial fill fraction).

- progress_callback:

  Optional monitoring callback, forwarded to
  [`ewm_depuis_soilgrids`](https://pobsteta.github.io/nemeton/reference/ewm_depuis_soilgrids.md).

- ...:

  Ignored (forward-compat).

## Value

A `biljou_soil` object (uniform mode), a **named list** of `biljou_soil`
objects keyed by unit id (SoilGrids mode), or `NULL` when biljouR is
unavailable.

## Details

**Two modes.**

- `source = "uniform"` (default): a **single** shared soil, as in
  v0.146.x. `ewm` is then the reserve *per soil layer* (1 to 3 layers,
  per BILJOU) — **not** per unit.

- `source = "soilgrids"`: one **single-layer soil per unit**, its `ewm`
  derived from SoilGrids 250 m through the Saxton & Rawls pedotransfer
  function
  ([`ewm_depuis_soilgrids`](https://pobsteta.github.io/nemeton/reference/ewm_depuis_soilgrids.md)).
  Returns a list named by unit id, which `biljou_run_grid()` indexes per
  point — this is what spatialises the water balance (spec 035).

Falls back to the uniform soil, with a warning, when SoilGrids cannot be
reached. Units whose `ewm` is `NA` or non-positive get the `ewm`
default, since
[`biljou_soil`](https://pobsteta.github.io/biljouR/reference/biljou_soil.html)
rejects non-positive reserves.

## See also

[`ewm_depuis_soilgrids`](https://pobsteta.github.io/nemeton/reference/ewm_depuis_soilgrids.md),
[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
