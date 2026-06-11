# Map SoilGrids CEC values to a 0-100 fertility score

Cation Exchange Capacity (CEC) is the most common proxy for nutrient
retention in forest soils. SoilGrids 2.0 distributes CEC in \\cmol(c)/kg
\times 10\\; the raw raster value must be divided by 10 to recover the
physical unit. The mapping used here is linear on the \\\[0,
30\]\\cmol(c)/kg\\ window, capped at the bounds:

- \< 3 cmol(c)/kg: very poor (acid podzols, sandy soils)

- 3-7: poor

- 7-15: moderate

- 15-25: good

- \> 25: rich (calcareous, alluvial, peaty)

Thresholds after Baize & Jabiol (1995), *Guide pour la description des
sols*. NA in, NA out.

## Usage

``` r
cec_to_fertility_score(cec_x10)
```

## Arguments

- cec_x10:

  Numeric. Raw SoilGrids CEC value (cmol(c)/kg x 10).

## Value

Numeric vector on the 0-100 scale (higher = more fertile).
