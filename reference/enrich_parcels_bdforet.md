# Enrich Parcels with BD Forêt V2 Data

Performs spatial intersection between parcels and BD Forêt V2 polygons
to extract dominant species, then maps IGN essence codes to allometric
model species names. Used upstream of indicator functions that accept
\`species\`/\`age\` unit columns (P2 station in CHM mode, C1 biomass in
allometric mode).

## Usage

``` r
enrich_parcels_bdforet(parcels, bdforet_sf)
```

## Arguments

- parcels:

  sf object. Parcel geometries to enrich.

- bdforet_sf:

  sf object. BD Forêt V2 formation_vegetale layer.

## Value

A data.frame with columns \`species\`, \`age\`, \`density\` (one row per
parcel). Parcels with no BD Forêt coverage get NA values.

## Details

The returned \`density\` column is a canopy-cover fraction (default
`0.7`), suitable for the C1 allometric formula. It is NOT a
stems-per-hectare figure, so do not feed it to
[`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
as \`density_field\`.
