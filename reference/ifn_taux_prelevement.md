# Reference harvest rate, with a SER -\> GRECO -\> national fallback

Returns one harvest rate per requested species, in **m3/ha/year**,
walking the mesh down until the cell rests on enough plots and reporting
the level actually used. This is the rate
[`volume_mobilisable`](https://pobsteta.github.io/nemeton/reference/volume_mobilisable.md)
consumes.

## Usage

``` r
ifn_taux_prelevement(espar, ser = NULL, min_plac = 30,
  mesure = c("maille", "present"))
```

## Arguments

- espar:

  IFN species code(s), character.

- ser:

  SER code, a single string. `NULL` starts at the national level.

- min_plac:

  Minimum plots carrying the species for a level to qualify. Default
  `30`.

- mesure:

  `"maille"` (default) returns the rate per hectare of forest in the
  mesh — the figure whose national sum matches published harvest.
  `"present"` returns the rate over the plots where the species occurs,
  which is much higher for a clear-felled species such as poplar.

## Value

A data.frame with one row per `espar`: `espar`, `libelle_essence`,
`taux_m3_ha_an`, `niveau_utilise`, `n_plac_presence`, `ser`, `greco`.

## See also

[`ifn_prelevement_essence_ser`](https://pobsteta.github.io/nemeton/reference/ifn_prelevement_essence_ser.md),
[`volume_mobilisable`](https://pobsteta.github.io/nemeton/reference/volume_mobilisable.md).

## Examples

``` r
if (FALSE) { # \dontrun{
ifn_taux_prelevement(c("62", "09"), ser = "C20")
} # }
```
