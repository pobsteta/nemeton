# Read a SharkRF random-forest model file (RECONFORT)

Reads the text model file used by the RECONFORT v3 classifiers
(`model_1_seed_0.txt`, an OTB/Shark `RFClassifier` of 1000 trees) into a
compact object that
[`reconfort_sharkrf_predire()`](https://pobsteta.github.io/nemeton/reference/reconfort_sharkrf_predire.md)
can apply, without OTB, conda or IOTA2. The result is cached in memory
for the session (reading the 205 MB file of the `v3` model takes tens of
seconds), and, when `cache_dir` is given, on disk as an `.rds` next to a
checksum of the file's identity.

## Usage

``` r
reconfort_sharkrf_lire(path, cache_dir = NULL)
```

## Arguments

- path:

  Path to a `model_1_seed_0.txt` file.

- cache_dir:

  Optional directory for the on-disk cache of the parsed model. `NULL`
  (default) keeps the in-memory cache only.

## Value

An object of class `reconfort_sharkrf`: a list with `attr`, `seuil`,
`gauche`, `droite`, `racines`, `n_arbres`, `n_vars`, `classes` (the
class labels announced by the file header) and `source` (file size and
mtime).

## Details

The format is deduced from observation (studies 091 and 093 of the
platform), not from Shark's documentation; the reader checks the
structure and fails with a classed error (`nemeton_sharkrf_format`) when
the file does not match.

## Examples

``` r
f <- tempfile(fileext = ".txt")
writeLines(c("#RFClassifier with_dictionary", "2 1 2 ",
  "22 serialization::archive 18 0 0 1 0 0 1 0",
  "0 3 0 0 0 0 5.0e-01 1 2 0 0.0e+00 0 0 0 0.0e+00 0 1",
  "1 2 0 0 1 0 1 1 1 1 1",
  "2 1 0 3 3"), f)
m <- reconfort_sharkrf_lire(f)
reconfort_sharkrf_predire(m, matrix(c(0.2, 0.9), ncol = 1))
#>      [,1] [,2]
#> [1,]    1    0
#> [2,]    1    0
```
