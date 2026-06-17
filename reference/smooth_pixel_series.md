# Robustly smooth a per-pixel spectral series (spec 026)

Adds a \`smoothed\` column to the long series returned by
\[extract_pixel_timeseries()\], denoising each index independently so a
caller (e.g. \`nemetonshiny\`) can draw **faded raw points + a clean
line** instead of joining every acquisition with a sawtooth. The
variability in a raw Sentinel-2 series is mostly residual cloud / shadow
/ snow and view-angle noise, not forest signal, so the default smoother
is a **rolling median** — robust to the isolated drops a simple moving
average or LOESS would chase.

## Usage

``` r
smooth_pixel_series(
  ts,
  window_days = 45,
  method = c("rolling_median", "loess", "harmonic"),
  min_obs = 3L,
  n_harmonics = 2L
)
```

## Arguments

- ts:

  A \`data.frame\` with columns \`obs_date\` (Date or \`"YYYY-MM-DD"\`),
  \`index\` (character) and \`value\` (numeric, possibly \`NA\`) — the
  output of \[extract_pixel_timeseries()\].

- window_days:

  Numeric \`\> 0\`. Full width (days) of the centred window
  (\`rolling_median\` / \`loess\` only). Default \`45\`.

- method:

  One of:

  \`"rolling_median"\`

  :   (default) median over a centred temporal window — robust, but
      \`NA\` in genuine data gaps (winter / cloud runs): it only shows
      real data, never bridges a gap.

  \`"loess"\`

  :   local regression (\`family = "symmetric"\`, outlier-robust); also
      local, so still gappy.

  \`"harmonic"\`

  :   robust harmonic regression — models the annual cycle (Fourier) + a
      linear trend, so the curve is **continuous** across the
      winter/summer gaps the local methods can't bridge. NB this is a
      fitted *model* (the winter is interpolated from the seasonal
      shape), not raw data — present it as such.

- min_obs:

  Integer \`\>= 1\`. Minimum clear (non-\`NA\`) observations in the
  window for a smoothed value; below it the point is \`NA\`. Default
  \`3\`.

- n_harmonics:

  Integer in \`1:3\`. \`harmonic\` method only: number of annual Fourier
  pairs. Default \`2\`.

## Value

The input \`data.frame\`, sorted by \`(index, obs_date)\`, with a new
numeric \`smoothed\` column. For \`rolling_median\` / \`loess\` it is
\`NA\` in data gaps (window below \`min_obs\`); for \`harmonic\` it is
continuous at every date, \`NA\` only for an index with too few clear
points or under ~9 months of span.

## Details

The window is **temporal** (\`window_days\`), not a fixed number of
points, because acquisitions are irregularly spaced; \`NA\` values are
ignored.

## See also

\[extract_pixel_timeseries()\] (the raw series),
\[extract_pixel_trend()\] (the seasonal-composite trend at a pixel).

## Examples

``` r
if (FALSE) { # \dontrun{
  ts  <- extract_pixel_timeseries(cache_dir, scenes, xy = c(6.1, 46.6),
                                  indices = c("NDVI", "NBR", "NDMI"))
  sm  <- smooth_pixel_series(ts, window_days = 45)
  # plot: points = sm$value (faded), line = sm$smoothed, by index
} # }
```
