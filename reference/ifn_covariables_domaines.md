# Covariates of user-defined domains for the IFN production model

Computes, for each domain, the covariates of the national production
model (spec 054) exactly as they were computed for the sylvoecoregions:
mean and standard deviation of canopy height over the forest pixels
(height \>= 5 m), and mean and standard deviation of altitude weighted
by those pixels. Pass the result to
[`ifn_production_domaines`](https://pobsteta.github.io/nemeton/reference/ifn_production_domaines.md)
to get the domain-specific prediction (volume production only, see
there).

The model was fitted with **FORMS-T** canopy height at 10 m. Another
canopy height model (LiDAR, Open-Canopy) has a different distribution
and would bias the prediction.

## Usage

``` r
ifn_covariables_domaines(domaines, hauteur, altitude, id_col = NULL,
  unite_hauteur = c("cm", "m"), seuil_m = 5)
```

## Arguments

- domaines:

  An `sf` of polygons with a defined CRS.

- hauteur:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  of FORMS-T canopy height covering the domains.

- altitude:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  digital elevation model (m) covering the domains.

- id_col:

  Column of `domaines` identifying each domain, as in
  [`ifn_production_domaines`](https://pobsteta.github.io/nemeton/reference/ifn_production_domaines.md).
  `NULL` numbers them.

- unite_hauteur:

  Unit of `hauteur`: `"cm"` (default, FORMS-T as distributed) or `"m"`.

- seuil_m:

  Forest threshold in metres. Default `5`, as in the model.

## Value

A data.frame: `id`, `h_mean`, `h_sd`, `alt_mean`, `alt_sd`, `part_foret`
(share of the domain area covered by forest pixels).

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## See also

[`ifn_production_domaines`](https://pobsteta.github.io/nemeton/reference/ifn_production_domaines.md).

## Examples

``` r
if (FALSE) { # \dontrun{
h <- terra::rast("Height_2023.tif")   # FORMS-T, cm
cov <- ifn_covariables_domaines(ut, h, mnt, id_col = "code_ut")
ifn_production_domaines(ut, id_col = "code_ut", covariables = cov)
} # }
```
