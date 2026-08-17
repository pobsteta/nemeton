# Can A5 urban cooling be computed here?

Answers, **before** any computation, whether the LST-based cooling
indicator applies to a set of units — and if not, which condition fails.
The counterpart of
[`r5_applicabilite`](https://pobsteta.github.io/nemeton/reference/r5_applicabilite.md)
for the A family.

## Usage

``` r
a5_applicabilite(units, lst = NULL, buffer_m = 500, country = "FR")
```

## Arguments

- units:

  An sf object with the units.

- lst:

  A SpatRaster of Land Surface Temperature, when one is already
  available (project cache). `NULL` (default) answers at extent level.

- buffer_m:

  Numeric. Radius (m) of the local-reference ring, as in
  [`indicateur_a5_rafraichissement`](https://pobsteta.github.io/nemeton/reference/indicateur_a5_rafraichissement.md).
  Default 500.

- country:

  Character. Country config key for the catalogue query. Default `"FR"`.

## Value

A list with:

- `status`: one of `"eligible"`, `"eligible_partial"` (coverage, but
  only some units are scorable), `"no_coverage"`, `"no_reference"`,
  `"no_credentials"`, `"error"`. A **stable key**, meant to be
  translated downstream.

- `n_units`, `n_eligible`.

- `n_assets`: LST scenes intersecting the extent (`NA` when `lst` was
  supplied and no query was made).

- `per_unit`: data.frame (`has_lst`, `has_reference`, `eligible`) or
  `NULL` at extent level.

## Details

A5 has two independent conditions, and they fail at different scales:

- **coverage** — a Land Surface Temperature product must exist over the
  extent. Theia's Thermocity lineage covers a handful of French
  metropolises, not rural forests. Checked with
  [`theia_source_status`](https://pobsteta.github.io/nemeton/reference/theia_source_status.md),
  which queries the catalogue without downloading.

- **local reference** — each unit is scored against the median LST of a
  ring around it (`buffer_m`). A unit inside the scene footprint but
  with no valid pixel in its ring cannot be scored.

The first is answered at the scale of the **scene**: a STAC query knows
bounding boxes, not pixels. A unit 20 km from a covered city may fall
inside a scene's bbox without holding a single valid pixel. So the
verdict is two-tiered: without `lst`, an extent-level answer costing one
catalogue query; with a raster already at hand (typically the project
cache), a per-unit answer.

## See also

[`theia_source_status`](https://pobsteta.github.io/nemeton/reference/theia_source_status.md),
[`indicateur_a5_rafraichissement`](https://pobsteta.github.io/nemeton/reference/indicateur_a5_rafraichissement.md),
[`r5_applicabilite`](https://pobsteta.github.io/nemeton/reference/r5_applicabilite.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ap <- a5_applicabilite(units)
if (ap$status == "no_coverage") {
  message("Hors couverture Thermocity - A5 restera NA, ce n'est pas une erreur")
}
} # }
```
