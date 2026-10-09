# Parcels owned by legal entities (DGFiP), for one or more communes

Read, for the communes `insee`, the DGFiP file of **parcels owned by
legal entities** (*Fichiers des locaux et des parcelles des personnes
morales*, data.gouv.fr, Licence Ouverte) and return one row per
cadastral parcel with its owner and whether that owner is a **public
person** (State, region, département, commune, public establishment:
DGFiP groups 1, 2, 3, 4 and 9).

A parcel **absent** from the file belongs to a natural person, hence is
private.

The national file (~380 MB, Parquet) is downloaded **once** into
`cache_dir`; its URL is resolved through the data.gouv.fr API, so a new
release is fetched alongside and the old one removed. Each département
read is then kept as a small extract next to it.

## Usage

``` r
load_parcelles_personnes_morales(insee, fichier = NULL, cache_dir = NULL)
```

## Arguments

- insee:

  One or more commune INSEE codes (5 characters). Communes may lie in
  several départements (one extract is read per département).

- fichier:

  Optional path to a DGFiP parcel Parquet file (national file or
  extract) to read instead of the cache. Nothing is downloaded.

- cache_dir:

  Cache directory. Default
  `tools::R_user_dir("nemeton", "cache")/dgfip_personnes_morales`.

## Value

A `data.frame` with columns `idu` (14-character cadastral identifier),
`code_insee`, `publique` (logical), `groupe` (owner group label),
`proprietaire` (owner names, `" | "`-separated), `natures` (distinct
land-use labels of its fiscal subdivisions, `", "`-separated) and
`contenance_m2`. A 0-row `data.frame` when the communes hold no
legal-entity parcel; `NULL` on failure (missing arrow, no network and no
cache), with a warning.

## Lifecycle

Experimental (spec 058): may change in any release.

## See also

[`construire_ugf_onf`](https://pobsteta.github.io/nemeton/reference/construire_ugf_onf.md)
