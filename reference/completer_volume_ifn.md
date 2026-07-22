# Fill missing P1 volumes with the IFN regional reference

Where the standing-volume column is `NA`, substitutes the IFN reference
volume for that species and sylvoecoregion, walking the mesh down SER
-\> GRECO -\> national as needed
([`ifn_volume_reference`](https://pobsteta.github.io/nemeton/reference/ifn_volume_reference.md)).

This addresses the ordinary NDP 0 case: with public data only,
[`indicateur_p1_volume`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
has neither a field inventory nor a CHM to work from, and returns `NA`.
A sourced regional figure is more useful than a hole — provided nobody
mistakes it for a measurement, hence `source_col`.

## Usage

``` r
completer_volume_ifn(units, volume_col = "P1", species_field = "species",
  ser = NULL, min_plac = 30, mesure = c("present", "maille"),
  source_col = "volume_source")
```

## Arguments

- units:

  An `sf` object.

- volume_col:

  Standing-volume column, m3/ha. Default `"P1"`.

- species_field:

  Column holding the species code, in **any** of the project's
  nomenclatures — IFN `espar`, four-letter P1 code, snake-case tolerance
  code or Latin name. Resolved by
  [`resoudre_espar`](https://pobsteta.github.io/nemeton/reference/resoudre_espar.md).

- ser:

  SER code for the units, a single string, or `NULL` for national
  references.

- min_plac:

  Minimum plots for a mesh level to qualify. Default `30`.

- mesure:

  `"present"` (default) or `"maille"`; see below.

- source_col:

  Name of the added provenance column. Default `"volume_source"`.

## Value

`units` with `volume_col` completed and `source_col` added.

## A measurement is never overwritten

Rows where `volume_col` is already filled are left strictly untouched.
Only `NA`s are completed. The added `source_col` records, per row, where
each value came from: `"mesure"` for the original values, `"ifn_ser"`,
`"ifn_greco"` or `"ifn_national"` for completed ones, and `NA` where no
reference could be found. Any downstream reader can therefore separate
measured from imputed — which the caller **should** do before reporting.

## Which figure is substituted

`mesure = "present"` (default) uses the mean volume over the plots where
the species actually occurs — a stand-level figure, comparable to a P1
computed on a forest unit of that species. `"maille"` would use the
species' contribution to the regional mean, which is a resource figure
and far too low for this purpose.

## See also

[`ifn_volume_reference`](https://pobsteta.github.io/nemeton/reference/ifn_volume_reference.md),
[`volume_mobilisable`](https://pobsteta.github.io/nemeton/reference/volume_mobilisable.md).

## Examples

``` r
if (FALSE) { # \dontrun{
units <- indicateur_p1_volume(units)          # NA en NDP 0
units <- completer_volume_ifn(units, species_field = "species", ser = "C20")
table(units$volume_source)
} # }
```
