# Read the UTS → fertility crosswalk shipped with the package

Loads `inst/extdata/uts_fertilite_fr.csv`, the V1 French
typological-soil-unit to forest-fertility table (AFES 2008 Référentiel
Pédologique, 54 rows covering the 14 Grands Ensembles de Référence).
Columns: `rpf_code` (primary key), `rpf_name`, `wrb_code` (WRB 2014
equivalent), `fertility_class` (1-5), `fertility_score` (0-100),
`texture_dom`, `drainage`, `depth_cm`, `ph_range`, `forest_note`,
`source_biblio`, `notes`.

## Usage

``` r
read_uts_fertility_table()
```

## Value

A data.frame with 12 columns and 54 rows.

## Details

The primary consumer is
[`indicateur_f1_fertilite`](https://pobsteta.github.io/nemeton/reference/indicateur_f1_fertilite.md)
in `"gissol"` mode. The table is exposed for external review
(pedologists auditing scores) and for users who want to join arbitrary
RRP vector data against the same crosswalk directly.
