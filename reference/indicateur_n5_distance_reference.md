# N5: Distance to a low-disturbance reference (foundation-model embedding)

Functional naturalness of each unit, read in a foundation-model
embedding space: how close the unit's mean embedding is to that of a
reference set of low-disturbance forests. N1-N3 measure an
administrative naturalness (remoteness, cartographic continuity); N5
looks at the forest itself, as seen by the model (spec 064).
Source-conditional: without an embedding, N5 is `NA` with its status and
the N family is unchanged.

## Usage

``` r
indicateur_n5_distance_reference(
  units,
  embedding = NULL,
  reference = NULL,
  layers = NULL,
  foret_ancienne = NULL,
  annee = NULL,
  min_reference = 15L,
  n1_min = 80,
  couverture_min = 0.5,
  score = c("reference", "projet"),
  min_pixels = 10,
  source = NULL
)
```

## Arguments

- units:

  sf polygon layer (spatial units / UGF).

- embedding:

  SpatRaster, one band per embedding dimension (e.g. the 64 bands of
  AlphaEarth Foundations from `alphaearthnemeton::aef_fetch()`), or a
  list of such rasters named by year. `NULL`: taken from
  `layers$aef_embedding`.

- reference:

  Optional sf polygons of the user's own reference (strict reserves,
  senescence islands, reference plots). `NULL`: default reference, see
  Details.

- layers:

  nemeton_layers object, used to resolve `embedding` (`aef_embedding`)
  and `foret_ancienne` when not given.

- foret_ancienne:

  Optional ancient-forest layer
  ([`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)),
  used by the default reference.

- annee:

  Year to use when `embedding` is a list named by year. `NULL`: the most
  recent.

- min_reference:

  Integer. Minimum number of reference units (or polygons) with an
  embedding; below it, N5 is `NA` with status
  `skipped_reference_too_small`. Default 15.

- n1_min:

  Numeric. N1 threshold of the default reference. Default 80.

- couverture_min:

  Numeric in `[0, 1]`. Share of a unit's area that the top
  ancient-forest tier must cover for the unit to enter the default
  reference. Default 0.5.

- score:

  `"reference"` (default) or `"projet"`, see Details.

- min_pixels:

  Passed to
  [`embedding_summary()`](https://pobsteta.github.io/nemeton/reference/embedding_summary.md).

- source:

  Label stored in `n5_source` (`"aef"`; `"forpt"` and `"fused"` are
  reserved for spec 064 chantier C). Default: the `embedding_source`
  attribute of the raster, else `"aef"`.

## Value

`units` with

- N5:

  score 0-100, 100 = indistinguishable from the reference.

- n5_status:

  `calculated`, `skipped_no_embedding`, `skipped_no_reference`,
  `skipped_reference_too_small` or `skipped_no_coverage` (fewer than
  `min_pixels` valid pixels in the unit).

- n5_source:

  embedding source.

- n5_reference:

  `"defaut"` or `"utilisateur"`.

- n5_annee:

  year of the embedding used (`NA` if unknown).

- n5_distance:

  raw distance (Mahalanobis, Ledoit-Wolf).

## Details

**Default reference**: units covered (share \>= `couverture_min`) by the
top tier of `foret_ancienne` (its `anciennete` column when present, else
every polygon) **and** with `N1 >= n1_min`. It therefore needs the `N1`
column, which is why N5 is computed after N1 by
[`nemeton_compute()`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md).

**Distance**:
[`distance_reference()`](https://pobsteta.github.io/nemeton/reference/distance_reference.md)
on the mean embeddings of
[`embedding_summary()`](https://pobsteta.github.io/nemeton/reference/embedding_summary.md).

**Score** (spec 064, D-4):

- `"reference"` (default): `N5 = 100 * (1 - F(d))`, where `F` is the
  empirical distribution of the reference's own leave-one-out distances.
  A unit as close as a typical reference unit scores about 50; a unit
  farther than every reference unit scores 0. The score depends on the
  reference only, not on the other units being scored. With the default
  reference, a unit that belongs to it is scored on its leave-one-out
  distance.

- `"projet"`: percentile rank of the distance among the project's units
  (100 = closest). Spreads every project over 0-100 whatever its
  content: values are not comparable between projects.

**Pitfalls** (fiche N5): the reference is not a random sample (slope,
access, poor soils); the default reference is chosen by N1 and N2, so N5
correlates with them by construction; a distance is not a cause; with 15
reference units in 64 dimensions the shrinkage dominates and the
distance is close to Euclidean; AlphaEarth is annual.

## Lifecycle

Experimental (spec 064): may change in any release.

## See also

[`embedding_summary()`](https://pobsteta.github.io/nemeton/reference/embedding_summary.md),
[`distance_reference()`](https://pobsteta.github.io/nemeton/reference/distance_reference.md),
[`indicateur_n1_distance()`](https://pobsteta.github.io/nemeton/reference/indicateur_n1_distance.md),
[`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)
