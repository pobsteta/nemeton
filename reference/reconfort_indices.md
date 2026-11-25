# RECONFORT spectral indices CRswir and CRre

Computes, per pixel, the two red-edge/SWIR "chlorophyll-red-edge"
indices used by the RECONFORT dieback model (Sentinel-2 bands B4, B5,
B6, B8A, B11, B12): \$\$CRswir = B11 / (B8A + (1610 - 865) (B12 - B8A) /
(2190 - 865))\$\$ \$\$CRre = B5 / (B4 + (704 - 665) (B6 - B4) / (741 -
665))\$\$ A zero denominator is replaced by 1 and \`NA\` inputs give
\`NA\` (same rules as the upstream iota2 \`custom_index.py\`,
Apache-2.0).

## Usage

``` r
reconfort_indices(bands, indices = c("CRswir", "CRre"))
```

## Arguments

- bands:

  Surface reflectances, with the band names \`B4\`, \`B5\`, \`B6\`,
  \`B8A\`, \`B11\`, \`B12\` (case-insensitive): a \[terra::SpatRaster\]
  (one layer per band, named), or a \`data.frame\`, matrix or named list
  of equal-length numeric vectors. Only the bands of the requested
  indices are needed.

- indices:

  Which indices to compute: \`"CRswir"\`, \`"CRre"\` or both.

## Value

A \[terra::SpatRaster\] (layers \`CRswir\`, \`CRre\`) when \`bands\` is
a \`SpatRaster\`, otherwise a \`data.frame\` with the same columns.

## Details

The computation runs in the Rust core of the package when it is compiled
and the option \`nemeton.rust\` is not \`FALSE\`; otherwise a pure-R
fallback returns the same values (to 1e-12). See
\[nemeton_rust_disponible()\].

## References

Upstream RECONFORT: \<https://framagit.org/fl.mouret/reconfort\>
(Apache-2.0).

## Examples

``` r
b <- data.frame(B4 = 0.05, B5 = 0.08, B6 = 0.2, B8A = 0.4, B11 = 0.25, B12 = 0.15)
reconfort_indices(b)
#>      CRswir      CRre
#> 1 0.9636364 0.6300518
```
