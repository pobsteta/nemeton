# IFN standing volume by species and sylvoecoregion

Reference table of standing timber volume per hectare, by IFN species
code and by sylvoecoregion (SER), derived from the raw IFN tree and plot
data (campaigns 2005-2019: 1 015 606 living trees over 93 043 plots).

Three nested levels live in the same table, selected by `niveau`:
`"ser"` (86 sylvoecoregions), `"greco"` (the SER code's first letter —
the greater ecological region) and `"national"`. Use
[`ifn_volume_reference`](https://pobsteta.github.io/nemeton/reference/ifn_volume_reference.md)
to walk them as a fallback ladder.

Two volume columns, deliberately both kept:

- `vol_ha_present` — mean volume per hectare **over the plots where the
  species occurs**. This is a stand-level figure, the one comparable to
  a P1 computed on a forest unit of that species.

- `vol_ha_maille` — the species' contribution to the mesh's mean volume
  per hectare, averaged over **all** its plots. This is a regional
  resource figure; it is much lower for a scattered species.

## Usage

``` r
ifn_volume_essence_ser(espar = NULL, ser = NULL, greco = NULL, niveau = NULL)
```

## Arguments

- espar:

  Optional IFN species code filter (character, e.g. `"09"` for beech).
  Note these are the IFN's own codes, not the four-letter codes of
  [`indicateur_p1_volume`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md).

- ser:

  Optional SER code filter (e.g. `"C20"`).

- greco:

  Optional GRECO code filter (single letter, e.g. `"C"`).

- niveau:

  Optional level filter: `"ser"`, `"greco"` or `"national"`.

## Value

A data.frame with `niveau`, `ser`, `greco`, `espar`, `n_plac_presence`,
`n_plac_maille`, `vol_ha_present`, `vol_ha_maille`, `taux_presence`,
`libelle_essence`, `millesime`, `source`.

## Standing volume, not harvest

These figures are **standing stock**. The IFN harvest estimate comes
from the five-year revisit, which is not part of this dataset — so this
table does **not** supply the harvest rate of
[`volume_mobilisable`](https://pobsteta.github.io/nemeton/reference/volume_mobilisable.md)
(spec 040, D4).

## Sampling depth

`n_plac_presence` (plots carrying the species) grades reliability and is
not decorative: of the 4 639 species x SER cells, only 1 193 rest on 30
plots or more and 2 107 rest on fewer than 5. Filter on it, or use
[`ifn_volume_reference`](https://pobsteta.github.io/nemeton/reference/ifn_volume_reference.md),
which does.

## References

Data and aggregation method from the `DataForet` and `PPtools` packages
by Max Bruciamacchie (AgroParisTech Nancy), GPL-2, reused under GPL-3
with explicit permission. Method after `PPtools::CarteEssenceSer()`.

## See also

[`ifn_volume_reference`](https://pobsteta.github.io/nemeton/reference/ifn_volume_reference.md)
for the fallback ladder.

## Examples

``` r
if (FALSE) { # \dontrun{
# Beech across all sylvoecoregions, best-sampled first.
b <- ifn_volume_essence_ser(espar = "09", niveau = "ser")
head(b[order(-b$n_plac_presence), c("ser", "n_plac_presence", "vol_ha_present")])
} # }
```
