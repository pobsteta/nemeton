# Invert indicator values

Reverses the scale of an indicator (e.g., for indicators where low =
good).

## Usage

``` r
invert_indicator(
  data,
  indicators,
  scale = 100,
  suffix = "_inv",
  keep_original = FALSE
)
```

## Arguments

- data:

  Data containing the indicator

- indicators:

  Character vector of indicator names to invert

- scale:

  Numeric. The scale maximum. Default 100 (assumes 0-100 scale).

- suffix:

  Character. Suffix for inverted columns. Default "\_inv".

- keep_original:

  Logical. Keep original columns? Default FALSE.

## Value

Data with inverted indicator columns

## Details

Some indicators have inverse relationships with "goodness":

- Accessibility: High = more human pressure (bad for wilderness)

- Fragmentation: High = more fragmented (bad for biodiversity)

This function inverts the scale: `inverted = scale - original`

## Examples

``` r
if (FALSE) { # \dontrun{
# Invert accessibility for wilderness index
data <- invert_indicator(
  data,
  indicators = "accessibility_norm",
  suffix = "_wilderness"
)
} # }
```
