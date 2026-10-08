# Rubber-sheet the ONF forest parcels onto cadastral boundaries

Warp the ONF forest-parcel layer so that its outline lands on the
cadastral boundaries, **without ever moving the cadastre**. The ONF
contour and the cadastral limits are digitised independently: at Couchey
(21) they are about 10 m apart at the median, 40 m at the 90th
percentile, and no global translation helps (the best one gains 1 ha) —
the offset is local.

Method (spec 058, § 3.2):

1.  **Control points.** The outer contour of the union of the ONF
    parcels is sampled every `pas` metres; each point is paired with the
    nearest point of **any** boundary of `cadastre` when closer than
    `dmax`.

2.  **Displacement field.** At any vertex, the displacement is the
    inverse-square-distance weighted mean of the `k` nearest control
    vectors, damped far from them by a null weight of `1 / rayon^2`. The
    nearest neighbours come from FNN when it is installed (a pure-R
    fallback gives the same result, more slowly).

3.  **Application.** The ONF parcels are densified every `pas` metres
    and **every** vertex moves, inner limits included, so neighbouring
    parcels stay a partition. The result is then simplified
    (`simplification` metres) — without it the layer grows tenfold and
    downstream cutting slows down by an order of magnitude — and
    residual overlaps are removed, largest parcel first.

## Usage

``` r
caler_onf_sur_cadastre(
  onf,
  cadastre,
  pas = 5,
  dmax = 80,
  rayon = 200,
  k = 12,
  simplification = 1
)
```

## Arguments

- onf:

  An sf of forest parcels, e.g. from
  [`load_onf_parcelles_source`](https://pobsteta.github.io/nemeton/reference/load_onf_parcelles_source.md).
  All attributes are kept.

- cadastre:

  An sf/sfc of cadastral parcels. Never modified.

- pas:

  Sampling step of the contour and densification step, in metres.
  Default `5`.

- dmax:

  Maximum distance between a contour point and the cadastre for the pair
  to be a control point, in metres. Default `80`.

- rayon:

  Damping radius, in metres. Default `200`.

- k:

  Number of control vectors averaged at each vertex. Default `12`.

- simplification:

  Simplification tolerance applied after warping, in metres. Default
  `1`; `0` to skip.

## Value

`onf` restricted to the parcels within `dmax` of the cadastre, warped,
in the CRS of `onf`. It carries a `calage` attribute: a named numeric
vector with the number of control points (`n_controle`) and the median
and 90th-percentile gap (`ecart_median_m`, `ecart_p90_m`). With no
control point, `onf` is returned unwarped with a warning.

## Lifecycle

Experimental (spec 058): may change in a minor release.

## See also

[`construire_ugf_onf`](https://pobsteta.github.io/nemeton/reference/construire_ugf_onf.md)
