## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

- Local Ubuntu 24.04, R 4.5.2
- GitHub Actions (ubuntu-latest, R release)

## Notes

- The package includes a Shiny application (`run_app()`) for interactive
  forest analysis. The app requires optional packages listed in Suggests.
- Large spatial datasets (rasters, geopackages) used for indicator computation
  are not bundled with the package. Users download them as needed via
  `download_hunting_data()` and similar functions.
- Some examples use `\donttest{}` because they require spatial data files
  or take more than a few seconds to run.
