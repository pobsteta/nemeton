# Indicator family table

Public, stable view of the 12 indicator families of the Nemeton
framework. This is the canonical source for family codes, display names
and the indicators each family aggregates. Downstream packages (notably
`nemetonshiny`) should read it instead of re-declaring the list, so that
renaming a family in the core propagates instead of silently diverging.

The function is pure (no I/O, no state), and therefore safe to call from
a `future` worker.

## Usage

``` r
indicator_families(codes = NULL, lang = c("fr", "en"))
```

## Arguments

- codes:

  Character vector of family codes (case-insensitive), or `NULL`
  (default) for all 12 families in canonical order
  `C B W A F L T R S P E N`. When supplied, rows are returned in the
  order given.

- lang:

  Character. Language copied into the convenience columns `name`,
  `description`, `labels` and `tooltips`: `"fr"` (default) or `"en"`.
  The `_fr` / `_en` columns are returned regardless.

## Value

A `data.frame` with one row per family and the columns:

- code:

  Family code (`"C"`, `"B"`, ...).

- family_column:

  Name of the family score column produced by
  [`create_family_index`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
  (`"famille_carbone"`, ...). See
  [`get_famille_col`](https://pobsteta.github.io/nemeton/reference/get_famille_col.md).

- name:

  Family name in `lang`.

- name_fr, name_en:

  Family name in both languages.

- description:

  One-line description of the family in `lang`.

- description_fr, description_en:

  Description in both languages.

- icon:

  Bootstrap icon name.

- color:

  Semantic hex color (see *Colors*).

- indicators:

  List column: character vector of indicator codes (`"C1"`, `"C2"`,
  ...).

- column_names:

  List column: character vector of the produced column names, paired by
  position with `indicators`.

- labels:

  List column: named character vector of indicator labels in `lang`,
  named by indicator code.

- labels_fr, labels_en:

  Same, in each language.

- tooltips:

  List column: named character vector of indicator tooltips in `lang`,
  named by indicator code.

- tooltips_fr, tooltips_en:

  Same, in each language.

## Column pairing

`indicators` and `column_names` are always the same length and are
paired **by position**: `column_names[[i]]` is the column produced for
`indicators[[i]]`. Do **not** derive one from the other by string
manipulation: two families carry a legacy naming swap, where the short
code and the column slug disagree.

- `F1` is `indicateur_f2_erosion` and `F2` is `indicateur_f1_fertilite`.

- `L1` is `indicateur_l2_fragmentation` and `L2` is
  `indicateur_l1_sylvosphere`.

The labels follow the short code, so `labels[["F1"]]` describes erosion
– consistent with the paired column, not with the column's own slug.

## Both languages, always

Every translatable field is returned in **both** languages, in dedicated
`_fr` / `_en` columns. `lang` only selects which of them is copied into
the convenience columns `name`, `description`, `labels` and `tooltips`.
A caller that switches language at runtime – or that needs a fallback
when one language is missing – never has to call the function twice.

## Colors

`color` carries the *semantic* palette of the core (forest green for
carbon, water blue for the water family). It is deliberately not the
palette used by the Shiny application, which applies viridis for
colorblind accessibility. Consumers who need an accessible palette
should ignore this column.

## See also

[`indicator_labels`](https://pobsteta.github.io/nemeton/reference/indicator_labels.md)
for a long-format, one-row-per-indicator view.

## Examples

``` r
fams <- indicator_families()
fams$code
#>  [1] "C" "B" "W" "A" "F" "L" "T" "R" "S" "P" "E" "N"
fams[fams$code == "C", "name"]
#> [1] "Carbone & Vitalité"

# Loop over the families to build a menu
for (i in seq_len(nrow(fams))) {
  cat(sprintf("%s (%s)\n", fams$name[i], fams$code[i]))
}
#> Carbone & Vitalité (C)
#> Biodiversité (B)
#> Eau (W)
#> Air & Microclimat (A)
#> Fertilité des Sols (F)
#> Paysage (L)
#> Dynamique Temporelle (T)
#> Risques & Résilience (R)
#> Social & Récréatif (S)
#> Production (P)
#> Énergie & Climat (E)
#> Naturalité (N)

# A subset, in English
indicator_families(c("C", "W"), lang = "en")$name
#> [1] "Carbon & Vitality" "Water"            

# Both languages are always there, whatever `lang`
fams$labels_en[[1]]
#>                       C1                       C2 
#> "Carbon Biomass (tC/ha)"        "NDVI - Vitality" 

# The family score column produced by create_family_index()
fams$family_column
#>  [1] "famille_carbone"      "famille_biodiversite" "famille_eau"         
#>  [4] "famille_air"          "famille_sol"          "famille_paysage"     
#>  [7] "famille_temporel"     "famille_risque"       "famille_social"      
#> [10] "famille_production"   "famille_energie"      "famille_naturalite"  
```
