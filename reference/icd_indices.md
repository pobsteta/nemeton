# ICD spectral indices (GRVI, CIre, CRSWIR, CRre, NDVI)

Computes the five indices of the composite discoloration indicator (ICD,
spec 071) from Sentinel-2 surface reflectances: \$\$GRVI = (B03 - B04) /
(B03 + B04)\$\$ \$\$CIre = B07 / B05 - 1\$\$ \$\$CRSWIR = B11 / (B8A +
(B12 - B8A) \times 0.56)\$\$ \$\$CRre = B05 / (B04 + (B06 - B04) \times
0.51)\$\$ \$\$NDVI = (B08 - B04) / (B08 + B04)\$\$ CRSWIR and CRre are
not recomputed here: they call the kernels of \[reconfort_indices()\]
(Rust core with R fallback), whose coefficients are \`(1610 - 865) /
(2190 - 865)\` = 0.5623 and \`(704 - 665) / (741 - 665)\` = 0.5132, the
"about 0.56 and 0.51" of the method note. A zero denominator gives
\`NA\` for GRVI, CIre and NDVI (and 1 for the two continuum-removal
indices, as in \[reconfort_indices()\]).

## Usage

``` r
icd_indices(bands, indices = .ICD_INDICES)
```

## Arguments

- bands:

  Surface reflectances (offset already removed), with the band names
  \`B03\`, \`B04\`, \`B05\`, \`B06\`, \`B07\`, \`B08\`, \`B8A\`,
  \`B11\`, \`B12\` (case-insensitive, \`B3\` and \`B03\` are the same
  band): a \[terra::SpatRaster\] (one named layer per band), or a
  \`data.frame\`, matrix or named list of equal-length numeric vectors.
  Only the bands of the requested indices are needed.

- indices:

  Which indices to compute, among \`"GRVI"\`, \`"CIre"\`, \`"CRSWIR"\`,
  \`"CRre"\`, \`"NDVI"\`. Default: all five.

## Value

A \[terra::SpatRaster\] (one layer per index) when \`bands\` is a
\`SpatRaster\`, otherwise a \`data.frame\` with one column per index.

## See also

\[reconfort_indices()\], \[run_icd_decoloration()\].

## Examples

``` r
b <- data.frame(B03 = 0.06, B04 = 0.04, B05 = 0.08, B06 = 0.2, B07 = 0.3,
                B08 = 0.4, B8A = 0.42, B11 = 0.25, B12 = 0.15)
icd_indices(b)
#>   GRVI CIre    CRSWIR      CRre      NDVI
#> 1  0.2 2.75 0.9321795 0.6551724 0.8181818
```
