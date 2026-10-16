# Resolve any species code to the IFN `espar` code

Accepts whichever nomenclature the caller happens to hold — IFN `espar`,
the four-letter P1 code, the snake-case tolerance code, a plain Latin
binomial, or the French label `lib_espar` — and returns the
corresponding `espar`. This is what lets
[`volume_mobilisable`](https://pobsteta.github.io/nemeton/reference/volume_mobilisable.md)
and
[`completer_volume_ifn`](https://pobsteta.github.io/nemeton/reference/completer_volume_ifn.md)
take a `species` column as it exists in the caller's data, rather than
demanding IFN codes.

Resolution is tried in that order and is **case-insensitive** for the
non-`espar` forms; the French label also ignores accents
(`"Epicea commun"` is `"Épicéa commun"`). A label matching several
`espar` (a genus name such as `"Frêne"`) is not resolved. Unresolved
entries come back as `NA` — never guessed.

## Usage

``` r
resoudre_espar(x)
```

## Arguments

- x:

  Character vector of species codes, Latin names or French labels.

## Value

A character vector of `espar` codes, same length as `x`, `NA` where no
correspondence exists.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## See also

[`ifn_espar_correspondance`](https://pobsteta.github.io/nemeton/reference/ifn_espar_correspondance.md)
for the table itself.

## Examples

``` r
if (FALSE) { # \dontrun{
resoudre_espar(c("09", "FASY", "fagus_sylvatica", "Fagus sylvatica", "Hêtre"))
# -> tous "09"
} # }
```
