# Reference standing volume, with a SER -\> GRECO -\> national fallback

Returns one reference volume per requested species, walking down the
mesh until the cell rests on enough plots: sylvoecoregion, then greater
ecological region, then national. The level actually used is reported,
so a caller can tell a regional figure from a national one — never
silently.

This mirrors the fallback already used by
[`indicateur_p1_volume`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
(species -\> genus -\> conifer/broadleaf): degrade the resolution rather
than return a figure resting on three plots.

## Usage

``` r
ifn_volume_reference(espar, ser = NULL, min_plac = 30,
  mesure = c("present", "maille"))
```

## Arguments

- espar:

  IFN species code(s), character.

- ser:

  SER code, a single string (e.g. `"C20"`). Its first letter gives the
  GRECO. `NULL` starts the ladder at the national level.

- min_plac:

  Minimum number of plots carrying the species for a level to be
  accepted. Default `30`.

- mesure:

  Which volume column to return: `"present"` (default, the stand-level
  figure) or `"maille"` (the regional resource figure). See
  [`ifn_volume_essence_ser`](https://pobsteta.github.io/nemeton/reference/ifn_volume_essence_ser.md).

## Value

A data.frame with one row per `espar`: `espar`, `libelle_essence`,
`vol_ha`, `niveau_utilise` (`"ser"`/`"greco"`/`"national"`, or `NA` when
no level qualified), `n_plac_presence`, `ser`, `greco`.

## See also

[`ifn_volume_essence_ser`](https://pobsteta.github.io/nemeton/reference/ifn_volume_essence_ser.md)
for the raw table.

## Examples

``` r
if (FALSE) { # \dontrun{
# Beech and silver fir in sylvoecoregion C20.
ifn_volume_reference(c("09", "61"), ser = "C20")
} # }
```
