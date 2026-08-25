# Segment tree crowns on a Canopy Height Model

Delineates individual tree crowns from a CHM and returns one polygon per
crown with its apex height. This is the `houppier` layer consumed by the
Marculus marking application, where a stem's height is pre-filled by a
point-in-polygon on the GNSS position.

## Usage

``` r
segment_houppiers(
  chm,
  aoi = NULL,
  ws = 5,
  hmin = 5,
  algorithme = c("dalponte", "silva", "watershed"),
  emprise = c("intersecte", "decoupe"),
  marge_m = NULL,
  resolution = 0.5,
  max_cells = 2e+07,
  h_range = c(1, 70)
)
```

## Arguments

- chm:

  Canopy Height Model: a `SpatRaster` or a path readable by
  [`rast`](https://rspatial.github.io/terra/reference/rast.html).
  Heights in **metres**, in a projected CRS.

- aoi:

  Optional `sf`/`sfc` clipping extent (typically the stand being
  marked). Reprojected to the CHM's CRS, then used to crop **and** mask.
  Cropping first is what bounds the memory of everything below.

- ws:

  Local-maximum search window, in metres. Roughly the crown radius of
  the dominant trees: too small splits a crown into several, too large
  merges neighbours.

- hmin:

  Minimum apex height, in metres. Below it, no tree is located.

- algorithme:

  `"dalponte"` (default), `"silva"` or `"watershed"`. The first two grow
  regions from located apexes; `"watershed"` ignores them and floods the
  inverted surface.

- emprise:

  How `aoi` is honoured. `"intersecte"` (default) segments on the AOI
  grown by `marge_m`, then keeps **whole** every crown that meets the
  AOI: a tree on the boundary is a tree, not a fraction of one.
  `"decoupe"` lets the AOI cut the raster, so boundary crowns are
  truncated — measured on Couchey, 4.7% of them, losing 29% of their
  area and 1.6 m of height. Use it only when a strict geometric clip is
  what you want.

- marge_m:

  Metres by which the AOI is grown before segmentation, so a crown
  standing on the boundary is complete. `NULL` (default) means `3 * ws`.
  Ignored when `emprise = "decoupe"`.

- resolution:

  Working resolution in metres (default `0.5`). Ignored when the CHM is
  already coarser.

- max_cells:

  Backstop cell cap for the working raster (default `2e7`). A CHM that
  is still too large after `resolution` is aggregated further.

- h_range:

  Admissible apex heights, in metres (default `c(1, 70)`). Crowns
  outside are dropped rather than shipped — the phone rejects them.

## Value

An `sf` of POLYGON, one row per crown, with:

- `houppier_id`:

  integer, 1..n, ordered by decreasing `h_max`.

- `h_max`:

  apex height in metres — the canonical Marculus name.

- `surface_m2`:

  crown area in square metres.

Zero crowns yields a zero-row `sf` with those columns, not `NULL`: the
caller writes an empty layer rather than a missing one.

## Details

**Working resolution is decided here, not by the caller.** A crown is 3
to 10 m across; segmenting a 0.20 m CHM neither adds silvicultural
information nor fits in memory — the Couchey CHM is 418 million cells.
The CHM is therefore aggregated to `resolution` (default 0.5 m) before
anything else, which divides the cost by 6 to 25, and further if the
result would still exceed `max_cells`.

The aggregation uses **`max`, not `mean`**: the apexes are precisely
what local-maximum detection looks for, and a smoothing statistic would
flatten them away. This costs a slight upward bias on `h_max` (the
tallest cell of each aggregate wins) — deliberate, and preferable to
losing a tree.

Heights are read back with a zonal statistic on the raster
([`zonal`](https://rspatial.github.io/terra/reference/zonal.html)),
never with a global
[`values()`](https://rspatial.github.io/terra/reference/values.html) or
[`extract()`](https://rspatial.github.io/terra/reference/extract.html):
the same innocent-looking call cost a 3 h 20 pipeline run on 2026-08-22.

Crowns may overlap, and that is not a defect: the marking application
keeps the tallest, the one whose apex physically dominates the operator.
No gap-filling is attempted either — a position inside no crown writes
nothing rather than guessing the neighbouring tree.

## See also

[`extract_h_dom`](https://pobsteta.github.io/nemeton/reference/extract_h_dom.md)
for the stand-level dominant height, which answers a different question
on the same raster.

## Examples

``` r
if (FALSE) { # \dontrun{
crowns <- segment_houppiers(
  "cache/layers/opencanopy/chm_predicted_0_2m.tif",
  aoi = ugf, ws = 5, hmin = 5
)
sf::st_write(crowns, "marculus.gpkg", layer = "houppier", append = FALSE)
} # }
```
