# Pivot a species ranking to one row per unit (wide)

Reshape the long output of
[`regen_rank_species`](https://pobsteta.github.io/nemeton/reference/regen_rank_species.md)
to one row per unit with `essence_r` / `score_r` / `label_r` /
`facteur_r` columns for each rank `r = 1..top_n` — convenient for a
per-unit table or a map join.

## Usage

``` r
regen_rank_to_wide(ranked, top_n = 3)
```

## Arguments

- ranked:

  The long `data.frame` returned by
  [`regen_rank_species`](https://pobsteta.github.io/nemeton/reference/regen_rank_species.md).

- top_n:

  Number of ranks to spread into columns (default 3).

## Value

A `data.frame` with `ug_id` and, per rank, `essence_r` (species code),
`score_r` (suitability), `label_r` (name) and `facteur_r` (limiting
factor).

## See also

[`regen_rank_species`](https://pobsteta.github.io/nemeton/reference/regen_rank_species.md)
