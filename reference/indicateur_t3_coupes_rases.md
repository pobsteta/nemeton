# Calculate Clear-cut Pressure Index (T3)

Recency-weighted fraction of a forest unit affected by clear-cuts,
derived from the SUFOSAT national product (CNES/CESBIO; Sentinel-1 radar
change detection, submonthly, mainland France). High = more recent
clear-cutting. This is a “high = bad” indicator (like R5 dieback): its
normalized radar value is inverted downstream (see `normalization.R`).

## Usage

``` r
indicateur_t3_coupes_rases(
  units,
  sufosat_dates = NULL,
  sufosat_proba = NULL,
  window_years = 5L,
  min_proba = 0.9,
  reference_year = NULL
)
```

## Arguments

- units:

  An sf object with forest units.

- sufosat_dates:

  A terra SpatRaster of clear-cut dates (`YYDDD`). `NULL` (default) -\>
  the indicator is not applicable and `NA` is returned for every unit
  (source-conditional, like R5 without FORDEAD).

- sufosat_proba:

  A terra SpatRaster of clear-cut probability (percent). `NULL` -\> no
  probability filter is applied.

- window_years:

  Integer. Length of the recency window in years. Default `5`.
  Clear-cuts older than `reference_year - window_years + 1` are ignored.

- min_proba:

  Numeric in \[0, 1\]. Minimum clear-cut probability to count a pixel,
  compared against `sufosat_proba / 100`. Default `0.9`.

- reference_year:

  Integer or `NULL`. Most-recent year of the recency window (weight 1).
  `NULL` (default) -\> derived from the most recent clear-cut year found
  across the extracted units.

  **Pass a calendar year when scores must be comparable.** With `NULL`
  the window is anchored on the *data*, not on the calendar: a massif
  whose last clear-cut dates from 2021 is scored over 2017-2021, so a
  2018 cut still counts as "recent", and two projects with different
  last-cut years are not comparable at the same `window_years`.
  Anchoring on the current year —
  `reference_year = as.integer(format(Sys.Date(), "%Y"))` — makes "the
  last N years" mean exactly that.

## Value

Numeric vector, one value per unit: recency-weighted percentage of the
unit footprint under clear-cut within the window (0-100, high = more
clear-cutting). `NA` where `sufosat_dates` is `NULL` or the unit does
not overlap the raster.

## Details

SUFOSAT rasters (spec 030, band metadata confirmed on the live Theia MTD
STAC 2026-07-02):

- `sufosat_dates`: clear-cut date per pixel, encoded `YYDDD` (YY = year
  18-25 -\> 2018-2025, DDD = day of year 1-366). `0` = no clear-cut
  (nodata).

- `sufosat_proba`: clear-cut probability in percent (0-100). `0` =
  nodata. SUFOSAT publishes detections at \>= ~85%.

The score is coverage-fraction weighted, so equal-area pixels cancel and
no cell-area computation is needed: it is the share of the unit
footprint under clear-cut within the recency window, weighted linearly
by recency.
