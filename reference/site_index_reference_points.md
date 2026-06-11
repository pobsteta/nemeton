# Published calibration points for the site-index curves

Returns the set of per-species \\(age, H\_{class\\3})\\ reference points
against which the parameters in `data-raw/site_index_curves.R` are
tuned. Each row carries the source citation so that downstream users can
audit the provenance of the curves, and the regression test
`test-site-index-calibration.R` asserts that the generated CSV
reproduces these points within a 0.5 m tolerance (class_3 at the stated
reference age).

## Usage

``` r
site_index_reference_points()
```

## Value

A data.frame with columns `species, age, h_class_3, source`.

## Details

For Phase A species, the underlying equations differ (Duplat & Tran-Ha
1997, Seynave 2005, Vallet & Pérot 2011…) but the current
Chapman-Richards approximation is calibrated to match one published
point per species. For FASY the full Korf model from Bontemps et al.
2007 is used, so its calibration point is the H(100) produced by the
Bontemps parameters themselves.

## Examples

``` r
site_index_reference_points()
#>    species age h_class_3                                  source
#> 1     QUPE 100      24.0                   Duplat & Tran-Ha 1997
#> 2     QURO 100      22.0                   Duplat & Tran-Ha 1997
#> 3     FASY 100      29.2 Bontemps et al. 2007 (Korf, NO+NE mean)
#> 4     CASA  80      22.0           Dhôte-like scaling (IFN 2004)
#> 5     PIAB  50      22.0                     Seynave et al. 2005
#> 6     ABAL  50      20.0                     Vallet & Pérot 2011
#> 7     PSME  50      27.5                       DSF / IRSTEA 2010
#> 8     PISY  50      16.5                   Duplat 2001 follow-up
#> 9     PIPI  40      17.5               Lemoine 1991 (IFN Landes)
#> 10    POSP  25      23.5                  CNPF 2013 (peupleraie)
```
