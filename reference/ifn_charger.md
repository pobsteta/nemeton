# Load raw French NFI tables

Reads the requested CSV tables out of the IGN export archive and returns
them. Column names are kept **as published by the IGN** (upper case:
`IDP`, `ESPAR`, `VEGET5`…), so the IGN documentation shipped inside the
archive applies directly.

## Usage

``` r
ifn_charger(tables = c("ARBRE", "PLACETTE"), campagne = NULL,
  dest_dir = file.path(tempdir(), "ifn"), visite = NULL, force = FALSE)
```

## Arguments

- tables:

  Character vector of table names, without extension, e.g.
  `c("ARBRE", "PLACETTE")`. Available: `ARBRE`, `PLACETTE`, `ECOLOGIE`,
  `COUVERT`, `FLORE`, `HABITAT`, `BOIS_MORT`, `metadonnees`,
  `espar-cdref13`.

- campagne:

  Campaign year, or `NULL` for the most recent.

- dest_dir:

  Directory holding (or receiving) the cached archive. Defaults to a
  session temporary directory.

- visite:

  Optional visit filter applied to `PLACETTE` only: `1` (first
  measurement), `2` (the five-year revisit) or `c(1, 2)`. `NULL` keeps
  all.

- force:

  Passed to
  [`ifn_telecharger`](https://pobsteta.github.io/nemeton/reference/ifn_telecharger.md).

## Value

A named list of data.frames, one per requested table, carrying a
`millesime` attribute.

## Improvements over `FrenchNFIfindeR::get_NFI()`

This is a reimplementation, not a wrapper — `nemeton` does not depend on
that package. Five deliberate differences:

1.  **Dynamic campaign** — the download URL is discovered
    ([`ifn_campagne_disponible`](https://pobsteta.github.io/nemeton/reference/ifn_campagne_disponible.md))
    instead of being pinned in the source, which leaves the original one
    campaign behind each autumn.

2.  **Non-interactive** — no
    [`readline()`](https://rdrr.io/r/base/readline.html) prompt; see
    [`ifn_telecharger`](https://pobsteta.github.io/nemeton/reference/ifn_telecharger.md).

3.  **Selective tables** — only the tables asked for are read. The
    original always reads five, including `FLORE.csv` (~58 MB) and
    `ECOLOGIE.csv`, even when only trees are needed.

4.  **Returns a value** — the original defaults to
    `export_to_env = TRUE`, assigning six objects into the global
    environment. Here the tables are returned as a named list.

5.  **No silent derivation** — the original imputes missing heights and
    increments from plot/species/size-class means, and adds computed
    basal areas, as a side effect of loading. Loading here returns the
    published data unchanged; derivations belong to the caller, where
    they can be documented and tested.

## References

IGN — Inventaire forestier national français, Données brutes, Campagnes
annuelles 2005 et suivantes,
<https://inventaire-forestier.ign.fr/dataIFN/>. Licence Ouverte Etalab
v2.0. Approach after `FrenchNFIfindeR::get_NFI()` (J. Borderieux,
GPL-3).

## Examples

``` r
if (FALSE) { # \dontrun{
d <- ifn_charger(c("ARBRE", "PLACETTE"), visite = 1)
nrow(d$ARBRE)
} # }
```
