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

  Character. Language used to fill the `name`, `labels` and `tooltips`
  columns: `"fr"` (default) or `"en"`. `name_fr` and `name_en` are
  always both returned, so a caller that switches language at runtime
  does not need to call the function twice.

## Value

A `data.frame` with one row per family and the columns:

- code:

  Family code (`"C"`, `"B"`, ...).

- name:

  Family name in `lang`.

- name_fr, name_en:

  Family name in both languages.

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

- tooltips:

  List column: named character vector of indicator tooltips in `lang`,
  named by indicator code.

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
```
