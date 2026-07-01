# Run the under-canopy microclimate model (scaffold — spec 027 L1)

Orchestrator that will produce the summer-aggregated microclimate
rasters (`tmax_understorey`, `tmax_open`, `vpd`, `rh`) consumed by the
A3/A4/W4 indicators, via the mechanistic model **microclimf** forced by
ERA5-Land and driven by LiDAR-HD canopy structure (PAI + height), with
an opencanopy CHM fallback (ADR-014).

**Scaffold**: the heavy dependencies (`microclimf`, `mcera5`, `ecmwfr`,
`lidR`, `lasR`) are in `Suggests`; this entry point validates their
presence and defines the `micro` contract. The full microclimf
orchestration (per the spec §6 pipeline) is wired in a later L1
increment once the forcing/structure data are available — in the
meantime the indicators accept a precomputed `micro` set.

## Usage

``` r
microclimate_run(aoi, year, structure = c("lidarhd", "opencanopy"),
  resolution = 5, cache_dir = NULL, quiet = FALSE)
```

## Arguments

- aoi:

  An `sf`/`sfc` AOI (union of parcels + buffer).

- year:

  Integer year of the ERA5-Land forcing.

- structure:

  Canopy structure source: `"lidarhd"` or `"opencanopy"`.

- resolution:

  Working resolution in metres (default 5).

- cache_dir:

  Optional cache directory for the microclimate rasters.

- quiet:

  Suppress progress messages.

## Value

A named list of
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
— `tmax_understorey`, `tmax_open`, `vpd`, `rh` (summer JJA) — the
`micro` contract.

## See also

[`indicateur_a3_microclimat`](https://pobsteta.github.io/nemeton/reference/indicateur_a3_microclimat.md)
