# Available water capacity from soil texture — Saxton & Rawls (2006)

Pedotransfer function giving the **available water capacity** (AWC) of a
soil horizon from its texture and organic-matter content: the difference
between water content at field capacity (-33 kPa) and at the permanent
wilting point (-1500 kPa). Feeds
[`ewm_depuis_soilgrids`](https://pobsteta.github.io/nemeton/reference/ewm_depuis_soilgrids.md),
which integrates it over the rooting depth to produce the `ewm` of
[`biljou_soil`](https://pobsteta.github.io/biljouR/reference/biljou_soil.html).

## Usage

``` r
awc_saxton_rawls(clay, sand, om, coarse = NULL)
```

## Arguments

- clay, sand:

  Numeric vectors, clay and sand content as **fractions** (0-1). Silt is
  implicit (`1 - clay - sand`).

- om:

  Numeric vector, organic-matter content in **percent** by mass. Derive
  from organic carbon with `om = oc_percent * 1.724`.

- coarse:

  Optional numeric vector of coarse-fragment content in **volume
  percent** (0-100). Default `NULL` (no correction, fine-earth AWC).

## Value

Numeric vector of available water capacity in m3/m3, clamped to
`[0, 1]`.

## Details

Closed-form equations of Saxton & Rawls (2006), Table 1:
\$\$\theta\_{1500t} = -0.024 S + 0.487 C + 0.006 OM + 0.005 (S \cdot
OM) - 0.013 (C \cdot OM) + 0.068 (S \cdot C) + 0.031\$\$
\$\$\theta\_{1500} = \theta\_{1500t} + (0.14\\ \theta\_{1500t} -
0.02)\$\$ \$\$\theta\_{33t} = -0.251 S + 0.195 C + 0.011 OM + 0.006 (S
\cdot OM) - 0.027 (C \cdot OM) + 0.452 (S \cdot C) + 0.299\$\$
\$\$\theta\_{33} = \theta\_{33t} + (1.283\\ \theta\_{33t}^2 - 0.374\\
\theta\_{33t} - 0.015)\$\$

Several online transcriptions give `-0.002` instead of `-0.02`, and
`-0.15` instead of `-0.015`. Those variants yield a **negative** field
capacity for sand and a negative AWC across every USDA texture class;
they are wrong. The constants above reproduce the NRCS reference values
(see `tests/testthat/test-soil-water.R`).

When `coarse` is supplied, the fine-earth AWC is scaled to bulk soil by
`(1 - coarse / 100)`: stones store no plant-available water.

This is a published pedotransfer function, not a calibration of this
project. It is exported so that a pedologist can audit it. NA in, NA
out.

## References

Saxton K.E., Rawls W.J. (2006). Soil Water Characteristic Estimates by
Texture and Organic Matter for Hydrologic Solutions. *Soil Science
Society of America Journal* 70:1569-1578.

## See also

[`ewm_depuis_soilgrids`](https://pobsteta.github.io/nemeton/reference/ewm_depuis_soilgrids.md)

## Examples

``` r
# Limon (loam) : AWC ~ 0.14 m3/m3
awc_saxton_rawls(clay = 0.20, sand = 0.40, om = 2.5)
#> [1] 0.1425866

# Le meme sol avec 30 % de cailloux
awc_saxton_rawls(clay = 0.20, sand = 0.40, om = 2.5, coarse = 30)
#> [1] 0.0998106
```
