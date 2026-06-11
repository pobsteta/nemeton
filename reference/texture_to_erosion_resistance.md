# Map soil texture to a 0-100 erosion-resistance score

First-pass heuristic converting a soil-texture composition into an
erosion-resistance score on the 0-100 scale (higher = more resistant,
less erodible), used by
[`indicateur_f2_erosion`](https://pobsteta.github.io/nemeton/reference/indicateur_f2_erosion.md)
when a Theia `theia_soil` texture is supplied (chantier sources Theia
phase 3b).

## Usage

``` r
texture_to_erosion_resistance(clay, silt, sand)
```

## Arguments

- clay, silt, sand:

  Numeric vectors of the clay, silt and sand contents (any consistent
  unit — they are renormalised).

## Value

Numeric vector on the 0-100 scale (higher = more resistant to erosion).

## Details

Following the USLE soil-erodibility logic, silt (and very fine sand) is
the most erodible fraction, clay resists through aggregate cohesion, and
coarse sand drains. The triplet is renormalised to fractions;
erodibility is `(silt_f + 0.4 * sand_f) * (1 - 0.6 * clay_f)` on the 0-1
scale, and resistance is `100 * (1 - erodibility)`.

Calibratable heuristic, exported for audit. NA in, NA out.
