# Schaeffer tariff numbers from IFN trees

The computing chain shared by the reference table
(`data-raw/build_ifn_tarifs_schaeffer.R`) and by
[`tarif_schaeffer_local`](https://pobsteta.github.io/nemeton/reference/tarif_schaeffer_local.md),
after `PPtools::TarifFindSch()`: living trees (`VEGET == "0"`) with a
volume `V`, circumference `100 * C13 >= 50` cm (`C13` is in
\*\*metres\*\* in the IGN raw data), \\17.5 \le D \le 80\\ cm with \\D =
100 C13 / \pi\\; four numbers per tree
([`numero_tarif_schaeffer`](https://pobsteta.github.io/nemeton/reference/numero_tarif_schaeffer.md));
per group and species, mean weighted by the tree volume and coefficient
of variation (weighted standard deviation / \|mean\|, reliability
weights). A species is kept in a group from 3 trees on. Low-form species
(holm oak, downy oak) can get a negative number on the slower tariffs:
it is kept, as in PPtools; the coefficient of variation stays positive.

## Usage

``` r
calculer_tarifs_schaeffer(arbres, groupes = character(0))
```

## Arguments

- arbres:

  data.frame of IFN trees with `ESPAR`, `C13` (m), `V` (m3), `VEGET` and
  `IDP`, plus the `groupes` columns (e.g. `SER`, joined from
  `PLACETTE`). Columns may be character, as read by
  [`ifn_charger`](https://pobsteta.github.io/nemeton/reference/ifn_charger.md).

- groupes:

  Character. Grouping columns (default none: one group).

## Value

A data.frame with the `groupes` columns, `espar`, `type` (`SCHR`,
`SCHI`, `SCHL`, `SCHTL`), `numero` (to 0.1), `cv` (percent, to 0.1),
`n_arbres` and `n_placettes`, and `part_houppier` (percent, to 0.1) when
`HTOT` is given.

## Details

When `arbres` has a `HTOT` column (total height, m), the **crown share**
`part_houppier` is added: the share of the merchantable wood (stem +
branches over 7 cm) that is crown, in percent, \\100 \sum V\_{houp} /
\sum (V\_{tige} + V\_{houp})\\ over the trees of the group with a
height, both volumes from the EMERGE equations
(`gftools::ListTarEmerge`, as Marculus does for its EMERGE tariff;
`hdec = 0.8 htot`). It is a **model**, not a measurement: the IFN does
not measure branches. `NA` below 3 trees with a height or without EMERGE
coefficients for the species. It is the same for the four tariff types
of a group; Marculus applies it as `houppier = V_tige p / (1 - p)`.

## Lifecycle

Experimental (spec 062).
