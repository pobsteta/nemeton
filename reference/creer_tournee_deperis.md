# Write the starting file of a DEPERIS round (`deperis.gpkg`)

Writes the `deperis.gpkg` that the Ramulus app completes in the field
(format `deperis-v1`, EPSG:2154): tables `tournee` (one row),
`placettes` (planned points and the columns of the plan) and the empty
tables `centres` and `notations`. With `nature = "contre_notation"` it
writes the separate file of the second operator: only the plots marked
for re-scoring, the centre of the first operator as a read-only copy, an
empty `contre_notations` table and **no** `notations` table nor any
first note.

## Usage

``` r
creer_tournee_deperis(
  plan,
  code,
  nature = c("premiere", "contre_notation"),
  saison = c("ETE", "HIVER"),
  regle_choix = .dp_regle_choix_defaut,
  dossier,
  contre_notation = NULL,
  graine = 1L,
  nb_arbres = NULL,
  collecte_photos = NULL,
  prepare_le = Sys.time(),
  delai_contre_notation_jours = NULL,
  version_nemeton = NULL,
  overwrite = FALSE
)
```

## Arguments

- plan:

  An `sf` object of POINT geometries in EPSG:2154 (planned points,
  inside the extent of EPSG:2154), one row per plot. Required column
  `plot_id` (unique text); columns `nb_arbres` (integer, at least 1),
  `collecte_photos` and `contre_notation` (logical or 0/1) are used when
  present; every other column (`wgt`, `ip`, `stratum`, `strat_*`...) is
  a plan column, copied as is and never changed by Ramulus. `etat`,
  `regle_choix`, `saison` and `fid` are reserved, and no column may be
  named `date`.

- code:

  Character. Code of the round (letters, digits, `.`, `_`, `-`); it
  names the returned `.zip`. Never a person or agent name.

- nature:

  `"premiere"` (first scoring, default) or `"contre_notation"`.

- saison:

  `"ETE"` or `"HIVER"`.

- regle_choix:

  Character. Tree choice rule, a campaign parameter; default "Kraft 1 a
  3, tour d'horizon depuis le nord, sens horaire".

- dossier:

  Directory where `deperis.gpkg` is written (created if missing).

- contre_notation:

  For `nature = "premiere"`: `NULL` (use the `contre_notation` column of
  the plan if any, else none), a share in (0, 1\] of the plots to mark
  for re-scoring (e.g. `0.05`, at least one plot), or a character vector
  of `plot_id`. For `nature = "contre_notation"`: the result of
  [`importer_deperis()`](https://pobsteta.github.io/nemeton/reference/importer_deperis.md)
  on the first round, which provides the centres.

- graine:

  Integer seed of the re-scoring draw.

- nb_arbres, collecte_photos:

  Campaign values used when the plan has no such column (`nb_arbres` is
  then required; `collecte_photos` defaults to `FALSE`).

- prepare_le:

  Time stamp of the preparation (default now, written in UTC).

- delai_contre_notation_jours:

  Maximal delay in days between the two passes, or `NULL` (left empty;
  the value is not settled yet).

- version_nemeton:

  Character, default the installed nemeton version.

- overwrite:

  Logical; replace an existing `deperis.gpkg`?

## Value

The path of the written `deperis.gpkg`, invisibly, with the attribute
`contre_notation` (the `plot_id` marked for re-scoring).

## Details

The file is written to the OGC GeoPackage rules the format requires:
`geom` and `fid` column names, **no spatial index** on `placettes` and
`centres` (`SPATIAL_INDEX=NO`: no R\*Tree table or trigger), no column
named `date`, ISO 8601 UTC time stamps, NFC text, `notations` and
`contre_notations` as `attributes` tables. The file just written is read
back and checked by the same control as an import; nothing is returned
if it would be refused.

The re-scoring covers a share of the plots (5 % in the brief), drawn
reproducibly: the plots are sorted by `plot_id`, then drawn with
`set.seed(graine)`, so the same plan and seed give the same draw.

## See also

[`importer_deperis()`](https://pobsteta.github.io/nemeton/reference/importer_deperis.md)
