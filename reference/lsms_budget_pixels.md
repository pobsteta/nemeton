# Pixel budget affordable within a compute budget

The inverse of
[`lsms_duree_estimee`](https://pobsteta.github.io/nemeton/reference/lsms_duree_estimee.md).
Reported to the caller when a job is refused, because the useful answer
is not "too big" but "how much fits".

## Usage

``` r
lsms_budget_pixels(budget_s, spatialr = 15L)
```

## Arguments

- budget_s:

  Compute budget, in seconds.

- spatialr:

  Spatial radius passed to LSMS.

## Value

Number of pixels affordable within `budget_s`.

## Details

The budget buys *pixels*, and the area they cover depends on the image
resolution – which is the whole point of expressing the guard this way.
A ten-minute budget affords about 3.4 Mpx: **13.6 ha at 0.20 m, but 84.9
ha at 0.50 m**. Coarsening the orthophoto is the only lever that changes
the order of magnitude, at the cost of the spectral detail that
justifies LSMS in the first place.

## See also

[`lsms_duree_estimee`](https://pobsteta.github.io/nemeton/reference/lsms_duree_estimee.md),
[`segment_houppiers`](https://pobsteta.github.io/nemeton/reference/segment_houppiers.md)
