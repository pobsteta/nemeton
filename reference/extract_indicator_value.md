# Extract an indicator's value column from its result

Single source of truth for the Nemeton indicator naming convention: most
indicator functions return the `units` object (an `sf` / `data.frame`)
with the computed value added under a column named by the family short
code (`indicateur_p1_volume` -\> `"P1"`, `indicateur_r1_feu` -\> `"R1"`,
...). This helper resolves that column to a plain numeric vector so both
the core dispatcher
([`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)
via `compute_indicator()`) and downstream callers (e.g. the
`nemetonshiny` compute loop) share **one** convention and can never
drift apart.

## Usage

``` r
extract_indicator_value(result, indicator, exclude = character(0))
```

## Arguments

- result:

  The raw return value of an indicator function (an `sf`, a
  `data.frame`, or a numeric vector).

- indicator:

  Character. The NMT indicator name (function name), e.g.
  `"indicateur_p1_volume"`.

- exclude:

  Character vector of column names to treat as pre-existing (not the
  freshly computed value) when falling back to the `"<Letter><digit>"`
  pattern. Default none.

## Value

A numeric vector of the indicator's per-unit values.

## Details

Resolution order for an `sf` / `data.frame` result:

1.  the short code derived from the indicator name
    (`indicateur_<code>_...` -\> upper-case `<code>`, e.g. `P1`);

2.  the NMT indicator name itself (or its upper-case form);

3.  any single `"<Letter><digit>"` column (optionally suffixed `_norm`),
    preferring columns **not** present in `exclude` (pass the
    pre-existing input column names so a freshly added value column wins
    over a same-shaped attribute already on the units).

A result that is already a plain vector is returned unchanged.

## See also

[`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)
