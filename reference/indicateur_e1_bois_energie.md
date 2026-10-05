# E1: Fuelwood Potential Indicator

Calculates mobilizable fuelwood potential (tonnes dry matter/year) from
forest harvest residues and coppice biomass.

## Usage

``` r
indicateur_e1_bois_energie(
  units,
  volume_field = "volume",
  species_field = "species",
  harvest_rate = 0.02,
  residue_fraction = 0.3,
  coppice_area_field = NULL,
  column_name = "E1",
  lang = "en",
  chm = NULL,
  production_field = NULL,
  taux_mobilisation = NULL,
  ser_field = "ser"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- volume_field:

  Character. Column name containing standing volume (m³/ha). Default
  "volume".

- species_field:

  Character. Column name containing species codes. Default "species".

- harvest_rate:

  Numeric. Annual harvest rate (fraction of volume). Default 0.02 (2
  percent/year).

- residue_fraction:

  Numeric. Fraction of harvest available as residues. Default 0.3 (30
  percent).

- coppice_area_field:

  Character. Column name for coppice area fraction. Optional.

- column_name:

  Character. Name for output column. Default "E1".

- lang:

  Character. Currently unused (messages are in English); kept for
  backward compatibility. Default "en".

- chm:

  Optional \`terra::SpatRaster\` canopy height model (spec 005). When
  supplied and \`volume_field\` is absent, standing volume is
  auto-estimated by running P1 internally. Default \`NULL\`.

- production_field:

  Character or `NULL` (default). Column holding the annual volume
  production (m3/ha/yr), e.g. P2 computed with
  `indicateur_p2_station(source = "ifn_fh")`. When supplied, E1 switches
  to **flux mode** (spec 054 lot 4): the annual harvest is
  `production x taux_mobilisation` instead of 2 percent of the standing
  stock, and `volume_field` / `harvest_rate` are not used.

- taux_mobilisation:

  Required in flux mode, no default on purpose: either a number in
  `[0, 1]` (share of the production harvested), or `"ifn_ser"` to use
  the harvest / production ratio observed by the IFN in the unit's
  sylvoecoregion
  ([`ifn_taux_prelevement_production`](https://pobsteta.github.io/nemeton/reference/ifn_taux_prelevement_production.md),
  capped at 1).

- ser_field:

  Character. SER column used by `taux_mobilisation = "ifn_ser"`. Default
  `"ser"`.

## Value

sf object with added columns: E1 (fuelwood potential tonnes DM/ha/yr),
E1_residues, E1_coppice; in flux mode also `E1_mode` (`"ressource_flux"`
or `"recolte_observee"`). **Higher = more fuelwood available =
favourable**, not inverted; normalize_indicator() rescales it against a
ref_max of 2.64 t DM/ha/yr – the yield of a stand at P1's own ceiling
(800 m3/ha, density 550), so E1, E2 and P1 score the same stand alike.
See spec 048 section 11. A unit with no volume gets `NA` in E1,
E1_residues and E1_coppice.

## Stock mode and flux mode

The default (**stock mode**) harvests 2 percent of the standing volume
every year, whatever the stand: a capitalised, slow-growing stand yields
more fuelwood than a young stand in full production. **Flux mode** ties
the harvest to what the forest grows. Both modes return the same
physical quantity (t DM/ha/yr) and share the same normalisation ceiling.

One combination is degenerate: a production taken from the IFN for the
SER (provenance `"ifn_prod_*"`, as written by P2 in IFN mode) multiplied
by the SER's own harvest / production ratio is simply the **observed
harvest** of the SER, identical for every unit of the domain. E1 then
warns and writes `E1_mode = "recolte_observee"` instead of
`"ressource_flux"`, so that it is not presented as a potential.

## Wood density

Residue volume is converted to dry matter with the species density of
`inst/extdata/wood_density.csv` (`density_kg_m3`), an air-dry density
(about 12 percent moisture), used as is as a dry-matter density – as C1
does. Versions up to 0.211.0 multiplied it by a further 0.5 ("dry matter
= 50 percent of fresh weight"), which halved E1.
