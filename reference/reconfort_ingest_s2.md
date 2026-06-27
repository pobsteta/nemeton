# Acquire Sentinel-2 scenes for an AOI into the IOTA² layout

IOTA²-native ingestion: for each tile covering \`aoi\` (or each tile in
\`tiles\`), downloads the MUSCATE L2A archives from GEODES via the
vendored \`pygeodes\` driver, then unzips them into
\`\<s2_root\>/extracted/\<tile\>/\`. Requires the conda environment
(L2b.1) and a GEODES account; heavy and opt-in (not run in CI).

## Usage

``` r
reconfort_ingest_s2(
  aoi = NULL,
  tiles = NULL,
  date_from,
  date_to,
  s2_root,
  geodes_config = NULL,
  s2_collection = "THEIA_REFLECTANCE_SENTINEL2_L2A",
  keep_zips = FALSE,
  quiet = FALSE
)
```

## Arguments

- aoi:

  An \`sf\`/\`sfc\` AOI. Ignored when \`tiles\` is given.

- tiles:

  Explicit MGRS tile code(s) (e.g. \`"T31UDP"\`); resolved from \`aoi\`
  when \`NULL\`.

- date_from, date_to:

  Date range (\`"YYYY-MM-DD"\`). RECONFORT needs two full years.

- s2_root:

  Root directory for the S2 data (zip + extracted).

- geodes_config:

  Path to \`pygeodes-config.json\`. Default resolves
  \`options(nemeton.geodes_config)\` then the per-user nemeton data dir.

- s2_collection:

  GEODES collection id. Default \`"THEIA_REFLECTANCE_SENTINEL2_L2A"\` —
  the THEIA/MUSCATE Sentinel-2 surface-reflectance L2A products. (The
  bare \`MUSCATE\_\*\` name from the upstream RECONFORT example is not a
  valid GEODES id and 400s.)

- keep_zips:

  Keep the downloaded \`.zip\` archives after extraction. Default
  \`FALSE\`: each archive is deleted as soon as it is extracted, so peak
  disk usage stays near the size of the extracted scenes instead of
  \*archives + extracted\* (a full tile over two years is ~200 GB of
  zips). Set \`TRUE\` to retain the archives (e.g. to re-run the unzip
  without re-downloading).

- quiet:

  Suppress progress + subprocess output. Default \`FALSE\`.

## Value

Invisibly, a list: \`tiles\`, \`s2_root\`, and \`extracted\` (the
per-tile extraction directories), for the L2b.3 map-production step.
