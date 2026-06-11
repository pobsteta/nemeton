# Extract augmentation flags from a detect_ndp() result

Convenience accessor for the `augmented` slot of an `ndp_result` object.

## Usage

``` r
get_ndp_augmented(x)
```

## Arguments

- x:

  An `ndp_result` object from
  [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md).

## Value

Character vector of augmentation flags (possibly empty).

## Examples

``` r
df <- data.frame(x = 1)
attr(df, "chm_source") <- "opencanopy"
get_ndp_augmented(detect_ndp(df))  # "height_ml"
#> [1] "height_ml"
```
