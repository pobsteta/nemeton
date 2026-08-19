# Cross ONF forest parcels with selected cadastral parcels

Intersect the ONF public-forest parcels returned by
[`load_onf_parcelles_source`](https://pobsteta.github.io/nemeton/reference/load_onf_parcelles_source.md)
with a selection of **cadastral** parcels, and return the fragments that
the application turns into tenements: one row per (cadastral parcel ×
forest parcel) pair, plus one `reste` row per cadastral parcel whose
area is not covered by any forest parcel.

The two subdivisions do not coincide, and their misalignment is the
whole difficulty. Measured on the *forêt communale de La-Vieille-Loye*
(39): 56 cadastral parcels × 33 forest parcels produce 92 fragments, of
which **51 fall under 0.05 ha** while carrying together **0.13 %** of
the area — digitising slivers, not management objects.

Slivers below `min_surface_ha` are therefore **absorbed** into the
largest fragment of the same cadastral parcel (the `reste` included),
never dropped: each cadastral parcel stays exactly tiled, which is what
the application's tiling invariant requires.

## Usage

``` r
croiser_parcelles_onf(
  parcelles,
  parcelles_onf,
  min_surface_ha = 0.05,
  absorber_echardes = TRUE,
  id_col = NULL
)
```

## Arguments

- parcelles:

  An sf of selected cadastral parcels. Its identifier column is taken
  from `id_col`, or auto-detected among `id`, `nemeton_id`,
  `geo_parcelle`, `idu`.

- parcelles_onf:

  An sf of forest parcels, as returned by
  [`load_onf_parcelles_source`](https://pobsteta.github.io/nemeton/reference/load_onf_parcelles_source.md).

- min_surface_ha:

  Fragments strictly smaller than this are treated as slivers. Default
  `0.05` (500 m²) — inside the natural gap measured between slivers (≤
  0.035 ha) and real fragments (≥ 0.12 ha).

- absorber_echardes:

  Absorb slivers into the largest fragment of the same cadastral parcel.
  Default `TRUE`. Set `FALSE` to inspect them.

- id_col:

  Name of the identifier column of `parcelles`. Default `NULL`
  (auto-detect).

## Value

An sf of fragments in the CRS of `parcelles`, with columns
`parcelle_cadastrale`, `id_onf`, `nom_ugf`, `foret_id`, `foret_nom`,
`parcelle`, `domaniale`, `reste`, `surface_ha`, `part_cadastrale` (share
of the cadastral parcel) and `part_onf` (share of the forest parcel —
how much of it the selection actually holds). A 0-row sf when nothing
intersects.

## See also

[`load_onf_parcelles_source`](https://pobsteta.github.io/nemeton/reference/load_onf_parcelles_source.md)
