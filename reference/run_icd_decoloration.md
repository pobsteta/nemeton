# Composite discoloration indicator (ICD) for a monitoring zone

Runs the ICD chain of the method note "Suivi de la decoloration anormale
du feuillage" (v2, 2026-10-29, sections 3 to 8) on one monitoring zone,
as FAST, FORDEAD and RECONFORT do (spec 071):

1.  \*\*Ingest\*\* (\`ingest = TRUE\`): Sentinel-2 L2A bands B03, B04,
    B05, B06, B07, B08, B8A, B11, B12 and the SCL layer, into the shared
    COG cache (\`ingest_s2_raw_bands_to_cache()\`, events \`s2:\*\`).

2.  \*\*Indices\*\* per scene at 20 m (\[icd_indices()\]), after the L2A
    offset correction and the SCL mask (classes 0, 1, 3, 8, 9, 10, 11).

3.  \*\*Monthly composite\*\*, April to October, since 2017: the median
    of the valid images of the month; a month without valid image stays
    empty. A composite is written atomically; an unreadable one is
    deleted and rebuilt at the next run. With \`mois_en_cours =
    "garder"\` the month under way is left as it is until it has ended
    for 5 days.

4.  \*\*Standardised anomaly\*\* \`z = (x - median of the other years) /
    max(1.4826 MAD, floor)\`, same pixel, same month; at least 4
    reference years, otherwise \`NA\`. Floors: 0.01 (GRVI, CRre, NDVI),
    0.05 (CIre), 0.02 (CRSWIR). A pixel is removed from its clear-cut
    month onward when \`sufosat_dates\` is given.

5.  \*\*ICD\*\* \`w1 z(GRVI) + w2 z(CIre) - w3 z(CRSWIR) - w4 z(CRre) +
    w5 z(NDVI)\` on the sensitive months of the species group, with the
    weights \`poids\`.

6.  \*\*Class and level\*\* of each year: Alert (ICD \< -2 for at least
    2 consecutive valid months, alert date = first month), Watch (ICD \<
    -1.5 once), Normal; levels 0 to 4 (3 = alert with minimum ICD \< -3,
    4 = alert this year and over the whole previous season). A second
    set, "to date", reads every year on the months already available
    this year.

Only pixels of the four pure stands (BD Foret V2, TFV FF1G01-01,
FF1-09-09, FF2G61-61, FF2-64-64; 10 m edge removed) get an ICD; the
others have none (no value is invented). Only the weights are
parameters; thresholds, persistence and months are those of the note.

## Usage

``` r
run_icd_decoloration(
  con = NULL,
  zone_id,
  cache_dir,
  result_dir = NULL,
  poids = icd_poids_defaut(),
  bdforet = NULL,
  sufosat_dates = NULL,
  sufosat_proba = NULL,
  annees_reference = NULL,
  buffer_interieur = 10,
  start_year = .ICD_ANNEE_DEBUT,
  end_year = NULL,
  ingest = TRUE,
  max_cloud = .ICD_NUAGES_MAX,
  mois_en_cours = c("garder", "refaire"),
  apply_zone_mask = TRUE,
  write_alerts = TRUE,
  progress_callback = NULL,
  cancel_path = NULL,
  today = Sys.Date(),
  aoi = NULL,
  source_s2 = NULL
)
```

## Arguments

- con:

  A \`DBIConnection\` (zone geometry, alerts), or \`NULL\` when \`aoi\`
  is given.

- zone_id:

  Integer. Monitoring zone.

- cache_dir:

  Character. Root of the Sentinel-2 COG cache.

- result_dir:

  Character. Root of the ICD results; default
  \`\<dirname(cache_dir)\>/icd\`.

- poids:

  Weights table, see \[icd_poids_defaut()\] and \[icd_poids_valider()\];
  a row whose sum is not 1 is rescaled to 1 and the run says so.

- bdforet:

  BD Foret V2 polygons (\`sf\` with a \`code_tfv\` column) or a
  \`SpatRaster\` already coded 1..4 (\`chene\`, \`hetre\`,
  \`sapin_epicea\`, \`douglas\`). Required: without species there is no
  ICD.

- sufosat_dates, sufosat_proba:

  Optional \`SpatRaster\`s of SUFOSAT clear-cut dates (\`YYDDD\`) and
  probability (percent, kept when \>= 90). Without them clear-cuts are
  not removed, and the result says so.

- annees_reference:

  Optional integer vector of healthy years used as reference; default:
  all other years.

- buffer_interieur:

  Edge removed from the pure stands, in metres.

- start_year, end_year:

  First and last year; \`end_year\` defaults to the year of \`today\`.

- ingest:

  Logical. Fetch the bands first (needs \`con\` and the network).

- max_cloud:

  Scene cloud cover ceiling for the STAC search (percent).

- mois_en_cours:

  \`"garder"\` (default) or \`"refaire"\`.

- apply_zone_mask:

  Logical. Mask pixels outside the UGF zone.

- write_alerts:

  Logical. Write the yearly alerts of the last year in the \`alert\`
  table (\`alert_type = "icd_decoloration"\`) when \`con\` is a database
  connection.

- progress_callback:

  Optional \`function(payload)\`.

- cancel_path:

  Optional cancellation flag file.

- today:

  Date; for tests.

- aoi:

  Optional \`sf\` zone polygon, instead of reading it from \`con\`.

- source_s2:

  Sentinel-2 reflectance source (mission 096): \`NULL\` (default:
  nothing changes, same search, same cache, same outputs as before),
  \`"theia"\` (MAJA, THEIA STAC catalogue, cache
  \`\<cache_dir\>\_theia\`) or \`"sen2cor"\` (CDSE then Planetary
  Computer, without the MUSCATE fallback). This method is calibrated on
  Sen2Cor: \`"theia"\` warns (class \`nemeton_s2_source_non_calee\`) and
  records \`calee_sur\` and \`mention_source\`. THEIA unavailable
  switches the WHOLE series to Sen2Cor (class
  \`nemeton_s2_repli_sen2cor\`); a 401/403 or missing keys is an error.
  The effective source is written in the outputs as \`source_s2\` only
  when this argument is given. THEIA results go to
  \`\<result_dir\>\_theia\`. See \[s2_source_resoudre()\].

## Value

A list with \`status\` (\`"success"\`, \`"cancelled"\`, \`"error"\`),
\`zone_dir\`, \`annees\`, \`poids\` (the weights actually used, with the
attributes of \[icd_poids_valider()\]), \`coupes_retirees\` (logical),
\`n_pixels_zone\`, \`n_pixels_icd\`, \`n_pixels_sans_icd\`, \`alertes\`
(rows inserted) and \`message\`.

## Details

Outputs are rasters under \`\<result_dir\>/zone\_\<id\>/\`:
\`composites/\`, \`z/\`, \`icd/\` (one file per year and month),
\`annuel/\` and \`annuel_a_date/\` (layers \`classe\`, \`niveau\`,
\`icd_min\`, \`mois_alerte\`, \`n_mois_valides\`), \`essence.tif\` and
\`meta.json\`. They are read back with \[read_icd_raster()\] and
\[read_icd_pixel_series()\].

Progress events (\`progress_callback\`, same channel as \`s2:\*\`):
\`icd:start\`, \`icd:composite\` (\`completed\`, \`total\`),
\`icd:anomalies\`, \`icd:annuel\`, \`icd:alertes\`, then exactly one
terminal event: \`icd:complete\`, \`icd:cancelled\` or \`icd:error\`.
Cancellation is cooperative: the \`cancel_path\` flag file is polled
before each scene and each month; what is already on disk stays valid.

## See also

\[read_icd_raster()\], \[read_icd_pixel_series()\],
\[comparer_fast_icd()\], \[icd_poids_defaut()\].
