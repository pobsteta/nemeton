# Default gating thresholds for the Sentinel-2 biophysical augmentation

The four conditions that must **all** hold for a unit to earn the
`"biophysical_s2"` NDP augmentation flag (spec 043 D6, ADR-015).

## Usage

``` r
biophys_gating_thresholds()
```

## Value

A named list of the four thresholds.

## All values are provisional — to calibrate

None of these thresholds is settled. Each ships with the order of
magnitude expected and the calibration method, per the spec:

- `n_obs_min` (default 3): 3-6; from the stability curve of the median
  composite versus `n_obs` (the invariance test, spec 043 §9).

- `pct_masked_max` (default 0.4): 0.3-0.5; from the composite's
  sensitivity to the cloud/shadow masking rate.

- `oob_frac_max` (default 0.10): 0.05-0.10; the tolerated fraction of
  pixels flagged out-of-domain by SL2P (input or output).

- `area_px_min` (default 25): ~1 ha at 20 m (25 px); from the
  within-unit variance versus area.

## See also

[`biophys_gating`](https://pobsteta.github.io/nemeton/reference/biophys_gating.md)
