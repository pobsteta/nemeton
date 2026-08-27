# Estimate the LSMS compute time for a pixel count

Upper-bound estimate used by
[`segment_houppiers`](https://pobsteta.github.io/nemeton/reference/segment_houppiers.md)
to refuse a job that would exceed its compute budget. See spec 051
section 3.1 for the model and its limits – it is calibrated on two
points, on the most textured stand of the reference massif, and is
deliberately pessimistic.

## Usage

``` r
lsms_duree_estimee(n_pixels, spatialr = 15L)
```

## Arguments

- n_pixels:

  Number of pixels of the image LSMS would segment.

- spatialr:

  Spatial radius passed to LSMS (cost grows roughly with its square).

## Value

Estimated wall-clock seconds.

## Details

The model is `t = 160.5 * (P/1e6)^1.0787 * (spatialr/15)^2.04`, fitted
on measurements taken on a 200 x 200 m window of mature high forest
closed at 89 percent: 1.0 Mpx in 160.5 s, 4.0 Mpx in 716 s, and 178 s
against 321 s for `spatialr` 15 against 20 at equal `minsize`.

It is **not a prediction**. Mean-shift converges according to image
content, and every measurement comes from the most textured stand
available, so the estimate is an upper bound meant to refuse an
obviously over-long job – not to promise a duration.

## See also

[`lsms_budget_pixels`](https://pobsteta.github.io/nemeton/reference/lsms_budget_pixels.md),
[`segment_houppiers`](https://pobsteta.github.io/nemeton/reference/segment_houppiers.md)
