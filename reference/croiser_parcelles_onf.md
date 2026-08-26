# Tenements met by each ONF forest parcel (UGF)

Start from the **forest parcels** returned by
[`load_onf_parcelles_source`](https://pobsteta.github.io/nemeton/reference/load_onf_parcelles_source.md)
— they are the management units, hence the UGF — and return, for each of
them, the tenement(s) cut out of the **cadastral** parcels it meets. One
tenement per cadastral parcel met, so the result reads as: *this UGF is
made of these pieces of these cadastral parcels*.

The two subdivisions do not coincide, and the misalignment is invisible
at UGF scale. Measured on the *forêt communale de La-Vieille-Loye* (39):
coverage of each forest parcel by the cadastre is 98.1 % at worst, 100 %
at the median — yet cutting 33 forest parcels against 56 cadastral
parcels yields 92 fragments, **51 of them under 0.05 ha**, carrying
together **0.13 %** of the area. Digitising slivers, not management
objects.

Cadastral parcels that meet **no** forest parcel are detected up front
and never crossed: they can only produce one row — themselves, whole,
outside any UGF — so that row is emitted directly, from the untouched
geometry. On a real commune (La-Vieille-Loye, 39) only 181 of 1 271
parcels meet the public forest; skipping the rest takes the crossing
from 19.1 s to 7.3 s with `inclure_reste = FALSE`, and from 20.6 s to
14.0 s with it. The result is unchanged, geometry for geometry.

Two corrections, mildest first:

- `min_surface_ha` — a sliver is **absorbed** by the largest tenement of
  the same cadastral parcel, never dropped, so each cadastral parcel
  stays exactly tiled (the application's tiling invariant).

- `caler_sur_cadastre` — when one UGF already holds at least
  `seuil_calage` of a cadastral parcel, that parcel is given to it
  **whole**: the UGF boundary snaps onto the cadastral boundary. Parcels
  genuinely shared between two UGF stay cut, and the uncovered remainder
  can never take a parcel — dropping forest is not a correction.

## Usage

``` r
croiser_parcelles_onf(
  parcelles_onf,
  parcelles,
  min_surface_ha = 0.05,
  caler_sur_cadastre = FALSE,
  seuil_calage = 0.9,
  inclure_reste = FALSE,
  rattacher_reste = FALSE,
  id_col = NULL
)
```

## Arguments

- parcelles_onf:

  An sf of forest parcels, as returned by
  [`load_onf_parcelles_source`](https://pobsteta.github.io/nemeton/reference/load_onf_parcelles_source.md).
  These are the UGF.

- parcelles:

  An sf of cadastral parcels. Its identifier column is taken from
  `id_col`, or auto-detected among `id`, `nemeton_id`, `geo_parcelle`,
  `idu`.

- min_surface_ha:

  Tenements strictly smaller than this are treated as slivers and
  absorbed. Default `0.05` (500 m²) — inside the natural gap measured
  between slivers (≤ 0.035 ha) and real tenements (≥ 0.12 ha). Use `0`
  to keep every sliver.

- caler_sur_cadastre:

  Snap UGF boundaries onto cadastral boundaries by giving each
  nearly-covered cadastral parcel whole to its dominant UGF. Default
  `FALSE`.

- seuil_calage:

  Share of a cadastral parcel above which its dominant UGF takes it
  whole. Only used when `caler_sur_cadastre` is `TRUE`. Default `0.9`.

- rattacher_reste:

  When `TRUE`, each piece of the remainder joins the forest parcel it
  shares its **longest common boundary** with, instead of piling up in a
  "hors forêt" catch-all. Length, not area nor distance: a ride running
  400 m along parcel 3 and touching parcel 4 at a corner belongs to 3,
  and a point contact is not a neighbourhood. A piece with no forest
  neighbour makes its cadastral parcel **its own unit**, named after its
  reference. Measured at Couchey: the catch-all held 72 tenements and
  49.68 ha on a project whose parcels are *all* in forest. Only
  meaningful with `inclure_reste = TRUE`.

  **Default `FALSE`, deliberately.** `inclure_reste` promises rows
  carrying `ugf_id = NA` and `hors_ugf = TRUE`; flipping this default
  would void that promise without a word for every existing caller.

- inclure_reste:

  Also return, with `ugf_id` `NA` and `hors_ugf` `TRUE`, the parts of
  cadastral parcels no forest parcel covers. Default `FALSE` — the
  UGF-first view does not need them, and the application's
  `tenement_split_by_import()` recreates that remainder itself.

- id_col:

  Name of the identifier column of `parcelles`. Default `NULL`
  (auto-detect).

## Value

An sf of tenements in the CRS of `parcelles_onf`, ordered by UGF then by
decreasing area, with columns `ugf_id`, `nom_ugf`, `foret_id`,
`foret_nom`, `parcelle`, `domaniale`, `tenement_id`
(`<ugf_id>~<cadastral id>`), `parcelle_cadastrale`, `hors_ugf`,
`surface_ha`, `part_ugf` (share of the UGF this tenement represents),
`part_cadastrale` (share of the cadastral parcel) and `n_tenements`
(tenements of that UGF). A 0-row sf when nothing intersects.

The result carries a `parcelles_concernees` attribute, a named integer
vector `c(concernees =, total =)`: how many cadastral parcels actually
meet the forest layer, out of how many were given. It saves the caller
an
[`st_intersects()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html)
just to report "N parcels out of M".

`part_ugf` is measured against the *original* ONF parcel, so it answers
"how much of this forest parcel does the selection hold". With
`caler_sur_cadastre = TRUE` it can exceed 1, since the UGF then gains
the sliver of the cadastral parcel it did not cover.

## See also

[`load_onf_parcelles_source`](https://pobsteta.github.io/nemeton/reference/load_onf_parcelles_source.md)
