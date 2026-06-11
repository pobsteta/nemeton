# THEIA STAC resolver

Generic STAC (SpatioTemporal Asset Catalog) item search and a
THEIA-specific asset resolver, so that the Theia datasources declared in
`inst/datasources/<country>.json` (`forms_t`, `s2_biophysical`,
`theia_snow`, ...) can be materialised from the THEIA STAC API instead
of a manual download.

The plumbing is endpoint-agnostic:
[`stac_search_items`](https://pobsteta.github.io/nemeton/reference/stac_search_items.md)
works against any STAC API, and the THEIA endpoint is read from the
`services$theia_stac` entry of the country configuration (or passed
explicitly via `stac_api`).
