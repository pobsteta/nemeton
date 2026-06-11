# Extract an alert mask from a categorical 0-4 raster (spec 014 A1)

Selects the cells of a categorical 0-4 SpatRaster (the FORDEAD
\`dieback_mask\` produced by \[run_fordead_dieback()\], or the FAST
alert mask produced by \[compute_fast_alert_mask()\]) that fall in the
requested \`classes\`, optionally dilating the mask by \`buffer_m\`
metres.

## Usage

``` r
fordead_alert_mask(alert_raster, classes = c(3L, 4L), buffer_m = 0)
```

## Arguments

- alert_raster:

  A \`terra::SpatRaster\` (single layer) with integer class values in
  \`\[0, 4\]\`. Typically produced by \[run_fordead_dieback()\]
  (categorical dieback mask) or by \[compute_fast_alert_mask()\] (FAST
  0-4 mask).

- classes:

  Integer vector. Class values to retain as alert cells. Default \`c(3L,
  4L)\` (the strong-alert + bare-ground classes, cf. spec 008 garde-fou
  G1).

- buffer_m:

  Numeric scalar in metres. Optional dilation around alert cells (\`0\`
  = no buffer, default). Useful to ensure that validation plots fall
  \*around\* a detection rather than exactly on it.

## Value

A \`terra::SpatRaster\` with the same geometry as \`alert_raster\`.
Alert cells keep their class value, buffer cells get \`min(classes)\`,
all other cells are \`NA\`. Layer name \`alert_priority\`.

## Details

The output preserves the \*\*class value\*\* on selected cells (so the
raster doubles as a \*priority raster\* for an unequal-probability GRTS
draw), and is \`NA\` elsewhere. Cells added by the buffer (not alert at
origin) take \`min(classes)\` so they are samplable but with the lowest
priority.

## See also

\[create_validation_sampling_plan()\] which consumes the output of this
function.

## Examples

``` r
if (FALSE) { # \dontrun{
  mask <- read_fordead_dieback_mask(con, zone_id = 1L,
            cache_dir = "/proj/cache/layers/fordead")
  alert <- fordead_alert_mask(mask, classes = c(3L, 4L), buffer_m = 20)
  terra::plot(alert)
} # }
```
