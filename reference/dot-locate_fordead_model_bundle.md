# Locate a FORDEAD diagnostic bundle directory

Mirrors the path convention of \[read_fordead_dieback_mask()\]: model
bundles live under
\`\<cache_dir\>/zone\_\<zone_id\>/model\_\<run_id\>/\`. When \`run_id\`
is \`NULL\` the most recent bundle (lexicographic order on the
\`YYYYMMDDTHHMMSS\` suffix, which is also chronological) wins.

## Usage

``` r
.locate_fordead_model_bundle(cache_dir, zone_id, run_id = NULL)
```

## Arguments

- cache_dir:

  Character(1). Root of the FORDEAD cache.

- zone_id:

  Integer. \`monitoring_zone.id\`.

- run_id:

  Optional character/integer. Explicit run selector.

## Value

Character(1) bundle directory, or \`NULL\` when none exists.
