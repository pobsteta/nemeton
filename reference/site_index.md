# Site-index curves and estimation

Reads the site-index reference CSV shipped with the package and exposes
helpers to estimate a stand site index from an observed dominant height
and age.

## Details

These functions support the CHM-driven mode of
[`indicateur_p2_station`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md)
(spec 005, phase 2). When a Canopy Height Model is available, the CHM
provides \\H\_{dom}\\, the stand age is read from BD Forêt / inventory
data, and
[`compute_site_index()`](https://pobsteta.github.io/nemeton/reference/compute_site_index.md)
returns the dominant height at a reference age (by default 50 years),
which is the classical forestry definition of the site index.

The curves are loaded once per R session from
`inst/extdata/site_index_curves.csv` and cached in an internal
environment.
