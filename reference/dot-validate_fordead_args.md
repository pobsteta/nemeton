# Validate \`run_fordead_dieback()\` arguments

Runs cheap, deterministic checks only — heavy validation (CRS
consistency, raster paths, etc.) is left to the FORDEAD steps themselves
so that we surface real Python errors instead of double-checking.

## Usage

``` r
.validate_fordead_args(
  dates_training,
  dates_monitoring,
  vegetation_index,
  threshold_anomaly,
  output_dir
)
```
