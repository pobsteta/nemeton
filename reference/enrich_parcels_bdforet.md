# Enrich Parcels with BD Forêt V2 Data

Performs spatial intersection between parcels and BD Forêt V2 polygons
to extract the dominant essence (largest area), then maps the BD Forêt
label to the four-letter species code the rest of the package reads
(site-index curves, conifer test, IFN tarifs, wood density): e.g.
`"Sapin, épicéa"` -\> `"ABAL"`, `"Chênes décidus"` -\> `"QUPE"`,
`"Pin sylvestre"` -\> `"PISY"`. Generic labels map to the genus-level
fallbacks `"CONIFER_GENUS"` / `"BROADLEAF_GENUS"`; a mixed
broadleaf/conifer stand (`"Mixte"`), `"NC"`, `"NR"` or an unknown label
give `NA`. Used upstream of indicator functions that accept
\`species\`/\`age\` unit columns (P2 station in CHM mode, P3, C1).

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

A data.frame with columns \`species\` (four-letter code), \`age\` and
\`density\` (both always `NA`; one row per parcel). Parcels with no BD
Forêt coverage get NA values.

## Details

BD Forêt V2 carries no stand age: \`age\` is always `NA` (no invented
value; before 1.0.0 it was a constant 60 years, spec 056). Supply a
measured age (inventory, T1) to compute the site index.

The returned \`density\` column is always `NA`: BD Forêt does not
measure canopy cover (before 1.0.0 it was a constant 0.7). Supply a
measured canopy-cover fraction for the C1 allometric formula; it is not
a stems-per-hectare figure for
[`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md).

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).
