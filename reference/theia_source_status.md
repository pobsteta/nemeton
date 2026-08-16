# Report whether a THEIA datasource is usable over an AOI

Answers "can this source be read here, and if not, why" **without**
downloading anything. Where
[`resolve_theia_assets`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md)
aborts on the first obstacle, this reports the obstacle as a stable key
the caller can translate and act on.

## Usage

``` r
theia_source_status(
  source_key,
  aoi,
  country = "FR",
  datetime = NULL,
  stac_api = NULL,
  limit = 50L
)
```

## Arguments

- source_key:

  Character. Datasource key in the country config (e.g. `"theia_lst"`,
  `"sufosat"`). Its `access$stac_collection` field must name a confirmed
  STAC collection.

- aoi:

  An `sf` / `sfc` object. Its bounding box is queried against the STAC
  catalogue.

- country:

  Character. Country config key. Default `"FR"`.

- datetime:

  Optional RFC 3339 datetime or interval passed to the STAC search, to
  restrict the temporal window.

- stac_api:

  Optional STAC API base URL, overriding the one declared in the country
  config.

- limit:

  Integer. Maximum number of items to resolve. Default `50`.

## Value

A list with:

- `available`: logical. `TRUE` only when the source can actually be read
  for this AOI.

- `reason`: character, one of `"ok"`, `"unknown_source"`,
  `"no_stac_collection"`, `"no_asset_over_aoi"`, `"no_credentials"`,
  `"error"`. A **stable key**, not a message: translate it downstream.

- `n_assets`: integer. Number of STAC items intersecting the AOI (`0`
  when the query could not run).

- `collection`: character. STAC collection queried, or `NA`.

- `detail`: character. Free-form diagnostic (upstream error message) or
  `NA`. For logs, never for the interface.

## Details

The motivating failure is silence: a source that is unreachable and a
source that legitimately has no data over the AOI both end as a `NULL`
layer and an `NA` indicator. On the 2026-08-16 project audit, A5 (urban
cooling) was empty because `theia_lst` — Thermocity lineage — only
covers a handful of French metropolises, which is correct and
documented; T3 (clear-cuts) was empty because the `sufosat` datasource
entry declared its STAC fields outside `access`, which was a defect.
Same symptom, opposite causes, no signal either way.

## See also

[`resolve_theia_assets`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md),
[`load_theia_source`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md)

## Examples

``` r
if (FALSE) { # \dontrun{
st <- theia_source_status("theia_lst", aoi)
if (!st$available && st$reason == "no_asset_over_aoi") {
  message("Outside Thermocity coverage - A5 stays NA, this is not an error")
}
} # }
```
