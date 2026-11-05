# Fixed cluster dictionary of AlphaEarth embeddings (B4/L3 embedding mode)

The `k` centroids against which every embedding pixel is labelled when
B4 and L3 run in embedding mode. They were fitted **once**, on a corpus
of forest landscapes (11 massifs of Bourgogne-Franche-Comté and outside
France, AlphaEarth 2024, `data-raw/aef_clusters.R`), and are versioned:
a k-means refitted on every project would make B4 as incomparable
between projects as its biodivMapR version (spec 064, decision D-6).

## Usage

``` r
aef_clusters(version = "v1")
```

## Arguments

- version:

  Dictionary version. Only `"v1"` (k = 32) exists.

## Value

A `k x 64` numeric matrix (columns `A00` to `A63`), with the provenance
(sites, year, algorithm, inertia) in `attr(, "meta")`.

## Lifecycle

Experimental (spec 064): may change in any release.
