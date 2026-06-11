# Map soil texture to a 0-100 fertility score

First-pass heuristic converting a soil-texture composition into a
forest-fertility score on the 0-100 scale, used by
[`indicateur_f1_fertilite`](https://pobsteta.github.io/nemeton/reference/indicateur_f1_fertilite.md)
in `"theia_soil"` mode (Theia `theia_soil` product, chantier sources
Theia phase 3b).

## Usage

``` r
texture_to_fertility_score(clay, silt, sand, coarse_elements = NULL)
```

## Arguments

- clay, silt, sand:

  Numeric vectors of the clay, silt and sand contents (any consistent
  unit — they are renormalised).

- coarse_elements:

  Optional numeric vector of coarse-element content in percent (0-100).
  Default `NULL` (no penalty).

## Value

Numeric vector on the 0-100 scale (higher = more fertile).

## Details

The texture triplet `clay` / `silt` / `sand` is normalised internally to
fractions summing to 1, so the inputs may be given in any consistent
unit (g/kg, percent, fraction). The score is the proximity of the
texture to the loam optimum (clay 0.20, silt 0.40, sand 0.40) in the
texture triangle: loam scores ~100, pure sand ~50, pure silt ~30, heavy
clay ~0 (waterlogging, root constraints). When `coarse_elements` is
supplied (percent of coarse fragments, 0-100), the score is multiplied
by `(1 - coarse/100)` — a stony soil has less fine earth and retains
fewer nutrients.

This is a calibratable heuristic, not a validated pedotransfer function;
it is exported so a pedologist can audit and tune it. NA in, NA out.
