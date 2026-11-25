# Import a DEPERIS round returned by Ramulus

Reads the package(s) `.zip` returned by the Ramulus app (a completed
`deperis.gpkg` plus its `photos/`), checks them against the `deperis-v1`
format and the round that Nemeton wrote
([`creer_tournee_deperis()`](https://pobsteta.github.io/nemeton/reference/creer_tournee_deperis.md)),
and returns the verdict, the reasons and, unless refused, the data.

## Usage

``` r
importer_deperis(
  zip,
  depart,
  precedent = NULL,
  operateur = NULL,
  version_ramulus = NULL,
  dossier_photos = NULL
)
```

## Arguments

- zip:

  Character. One or several `.zip` packages returned by Ramulus (or
  `deperis.gpkg` files).

- depart:

  Character. Path of the `deperis.gpkg` that
  [`creer_tournee_deperis()`](https://pobsteta.github.io/nemeton/reference/creer_tournee_deperis.md)
  wrote for this round (what Nemeton wrote must come back unchanged).

- precedent:

  Optional result of an earlier `importer_deperis()` of the same round;
  its data are merged with `zip` (replay without duplicates).

- operateur, version_ramulus:

  Operator and Ramulus version written in the `tournee` row of the union
  when several packages are merged (default: those of the first
  package).

- dossier_photos:

  Optional directory where the photos kept by the import are copied
  (never written on refusal).

## Value

A list of class `deperis_import` with `verdict` (`"accepte"`,
`"signale"` or `"refuse"`), `motifs` (sorted reason codes), `messages`,
`importe` (logical), `nature`, `code_tournee`, and, when imported:
`placettes`, `centres` (`sf` points, EPSG:2154), `notes` (data.frame
with the recomputed `classe` and the source `table`), `photos`
(data.frame `nom`, `sha256`, `chemin`), `conflits` (data.frame `objet`,
`cle`, `plot_id`, `message`) and `placettes_signalees` (plots whose
centre was left out for a conflict, kept with their notes). The `paquet`
element keeps the merged package for `precedent`.

## Details

The import is **all or nothing**: a package with at least one refusal
reason imports nothing. It is **replayable without duplicates**: rows
are merged on their `uuid`, so importing the same package twice, or a
package already contained in `precedent`, gives the same data. Several
packages (several operators) are merged the same way; a same `uuid` (or
photo) with two different contents is a conflict: both versions are left
out, the rest of the union is kept and the package is flagged
(`uuid_contenu_different`), never settled silently. The class of each
note is **recomputed** from the abacus (MB and MR or MA) of the DSF
sheets and a different class is refused (`classe_differente_abaque`).

The reasons come from the catalogue of the format (copy of the Ramulus
schema in `inst/schemas/`): refusals such as `plan_modifie` (a value
Nemeton wrote came back changed), `essence_hors_referentiel`,
`note_hors_bornes`, `photo_absente`, `hors_france`, and flags such as
`doublon_arbre`, `centre_eloigne`, `uuid_contenu_different`. A flagged
package is imported with its flags; only a refusal blocks.

## See also

[`creer_tournee_deperis()`](https://pobsteta.github.io/nemeton/reference/creer_tournee_deperis.md)
