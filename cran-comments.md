## Submission status

`nemeton` is not submitted to CRAN. Blocking points, by design:

- several Suggests are not on CRAN (`biodivMapR`, `microclimf`, `microclima`,
  `mcera5`, `biljouR`, `lasR`, `prosail`), installed from the `Remotes` field;
- the source tarball is about 11 MB (embedded reference tables in
  `inst/extdata`), above the CRAN 5 MB guideline;
- `.onLoad` sets `terra` memory options for heavy raster pipelines.

## R CMD check

Run in CI on every pull request (`.github/workflows/r.yml`,
`--as-cran --no-manual`). The release workflow only tags a version once that
check has passed on `main`.
