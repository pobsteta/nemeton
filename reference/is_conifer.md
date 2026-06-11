# Is a species code a conifer?

Small helper used by the genus-level fallback logic in both
[`compute_site_index`](https://pobsteta.github.io/nemeton/reference/compute_site_index.md)
and
[`indicateur_p1_volume`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md).

## Usage

``` r
is_conifer(species)
```

## Arguments

- species:

  Character. Species code (IFN style).

## Value

Logical scalar. `TRUE` if the code is on the known conifer list.
