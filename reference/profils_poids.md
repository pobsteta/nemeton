# Family weights of the actor profiles

The family weights used by
[`comparer_itineraires()`](https://pobsteta.github.io/nemeton/reference/comparer_itineraires.md)
for each actor profile (`inst/extdata/profils_poids.json`, spec 065 D-1:
the weights are business logic and live in the core; prompts and labels
stay in the app).

## Usage

``` r
profils_poids(profil = NULL)
```

## Arguments

- profil:

  A profile key (e.g. `"profil_naturaliste"`), or `NULL` for all
  profiles.

## Value

For one profile, a named numeric vector of the 12 family weights; for
`NULL`, a list of them, with the file's provenance in `attr(, "meta")`.

## Details

The shipped weights are **provisional**: priority families of each
profile (CLAUDE.md table) weigh 3, the others 1, and "all families"
profiles weigh 1 everywhere. They are a starting point to be validated
or replaced, not a calibration.

## Lifecycle

Experimental (spec 065): may change in any release.
