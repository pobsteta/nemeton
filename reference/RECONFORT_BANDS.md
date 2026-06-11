# Sentinel-2 bands used by the RECONFORT indices

The six Sentinel-2 L2A bands feeding the RECONFORT continuum-removal
indices (spec 021 §10 Q2): CRswir uses B8A/B11/B12, CRre uses
B04/B05/B06. Documentary — IOTA² ingests the full L2A product; this
constant records the bands the model actually depends on (centre
wavelengths, nm: B04=665, B05=704, B06=741, B8A=865, B11=1610,
B12=2190). Parallel to
[`FORDEAD_BANDS`](https://pobsteta.github.io/nemeton/reference/FORDEAD_BANDS.md).

## Usage

``` r
RECONFORT_BANDS
```
