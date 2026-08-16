# Calculate Urban Cooling Index (A5)

Relative surface-temperature freshness of a forest / tree unit compared
with its local surroundings, from a Land Surface Temperature (LST)
raster (e.g. Theia Thermocity ECOSTRESS/ASTER). High = the unit is
markedly **cooler** than its surroundings — the cooling service trees
provide in an urban heat-island context.

## Usage

``` r
indicateur_a5_rafraichissement(
  units,
  lst = NULL,
  reference = NULL,
  buffer_m = 500,
  delta_scale = 5,
  ...
)
```

## Arguments

- units:

  An sf object with the tree / forest units.

- lst:

  A terra SpatRaster of Land Surface Temperature (K or °C). `NULL`
  (default) -\> the indicator is not applicable and `A5 = NA` for every
  unit (source-conditional, like A3/A4 without a microclimate model).

- reference:

  Optional numeric. A fixed reference temperature (same unit as `lst`).
  `NULL` (default) -\> a per-unit local reference is used: the median
  LST of a ring around the unit (`buffer_m`).

- buffer_m:

  Numeric. Radius (m) of the local-reference ring around each unit.
  Default 500.

- delta_scale:

  Numeric. Temperature difference (K/°C) mapped to the full score swing:
  a unit `delta_scale` cooler than its reference scores 100,
  `delta_scale` hotter scores 0, equal scores 50. Default 5.

- ...:

  Unused.

## Value

`units` with `A5` (0-100, high = cooler than surroundings), `A5_delta`
(raw reference − unit LST) and `a5_status`. `A5 = NA` where `lst` is
`NULL`, the unit does not overlap the raster, or no local reference is
available.

`a5_status` is one of `"calculated"`, `"skipped_no_lst"` (no LST raster
supplied) or `"skipped_no_reference"` (raster supplied but no unit could
be scored — no overlap, or no local reference). It mirrors `r5_status`
and exists so that a consumer can tell an empty indicator apart from a
broken one: outside Thermocity coverage `A5 = NA` is the correct answer,
not a failure.

## Details

Scope (spec 032, reoriented): this indicator targets the **urban tree /
forest-city interface**, precisely where an LST product is available.
Over rural forests, where no LST covers the area, it is left `NA`.
Surface **albedo is deliberately NOT used**: for a tree it is not a
valid cooling proxy (cooling comes from shade + evapotranspiration;
canopy albedo is low and second-order), so LST — the direct temperature
signal — is the only physically sound basis.

The score is a **relative** freshness: the unit's mean LST is compared
with a local reference (median LST of a surrounding ring, or a supplied
`reference`). Differences are scale-invariant between kelvin and
celsius, so either unit works.
