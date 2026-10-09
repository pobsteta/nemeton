# Build the management units (UGF) of a public forest from the cadastre

Build the UGF of a public forest **from the cadastral parcels**, each
UGF carrying the number of its ONF forest parcel. Rule (Pascal,
2026-10-08): forest parcels are only a partition of cadastral parcels;
UGF are always obtained by grouping and cutting **cadastral** parcels,
the cadastre is never warped, and it is the ONF layer, which overflows,
that is adjusted.

By default this function starts from the forest and **finds** the
cadastral parcels that belong to it (spec 058):

1.  **Candidates**: cadastral parcels (PCI, IGN) touching the union of
    the ONF parcels, restricted to the commune `insee`.

2.  **Calage**: the ONF layer is rubber-sheeted onto the candidates'
    boundaries
    ([`caler_onf_sur_cadastre`](https://pobsteta.github.io/nemeton/reference/caler_onf_sur_cadastre.md)).

3.  **Selection**: a candidate belongs to the forest when its owner is a
    **public person** according to the DGFiP legal-entity file
    ([`load_parcelles_personnes_morales`](https://pobsteta.github.io/nemeton/reference/load_parcelles_personnes_morales.md))
    **and** the warped ONF covers at least `seuil_couverture` of it.
    Neither condition is enough alone: at Couchey (21), three communal
    parcels of 22 to 57 ha are covered at 2–3 % (moorland outside the
    *régime forestier*), and a 0.04 ha private parcel is covered at 56 %
    by an ONF overflow.

4.  **Cutting by snapping**: within each selected parcel, the pieces cut
    by the ONF parcels are reduced to their core by a morphological
    opening of radius `tol / 2` (`larg_hors / 2` for the uncovered
    remainder, whose cores under `ha_hors` are dropped). The strips left
    over join the core they share the longest boundary with; detached
    parts under `min_part_m2` join their longest-boundary neighbour. An
    ONF limit closer than `tol` to a cadastral limit thus **snaps** onto
    it: a parcel is cut only where the ONF limit really departs from it.

5.  **Final attachments**, over all tenements (neighbours share at least
    1 m of boundary, measured within 10 cm): an ONF piece under `seuil`
    ha whose neighbours all belong to one other UGF, and which does not
    touch its own, moves to that UGF (up to 5 passes); an uncovered
    piece (`cad~`) under `seuil_hors` ha joins its longest-boundary
    neighbour; a whole UGF under `seuil` ha is shared out among its
    longest-boundary neighbours.

The cutting works on a centimetre grid; each parcel is finally re-tiled
on its **original** geometry, so the cadastre does not move even by a
millimetre.

Measured at Couchey (21200): 63 candidates, 19 parcels kept (493.79 ha),
63 UGF, none uncovered, 85 tenements, smallest UGF 2.11 ha, in about 15
s once the sources are loaded.

## Usage

``` r
construire_ugf_onf(
  aoi = NULL,
  insee = NULL,
  parcelles_onf = NULL,
  cadastre = NULL,
  proprietaires = NULL,
  pas = 5,
  dmax = 80,
  rayon = 200,
  k = 12,
  seuil_couverture = 0.5,
  tol = 15,
  larg_hors = 50,
  ha_hors = 0.5,
  seuil = 0.5,
  seuil_hors = 1,
  min_part_m2 = 500,
  crs = 2154,
  selection = c("foret", "toutes")
)
```

## Arguments

- aoi:

  An sf/sfc extent used to fetch the ONF parcels when `parcelles_onf` is
  `NULL`.

- insee:

  INSEE code(s) of the communes whose cadastral parcels are fetched and
  whose DGFiP owners are read. Several communes, even in several
  départements, are processed **together**: calage, cutting and
  attachments run once over all of them, so limits between communes are
  handled on both sides. Optional when `cadastre` is given: then deduced
  from its `code_insee` column, or from the first five characters of
  `idu`.

- parcelles_onf:

  Optional sf of ONF parcels, as returned by
  [`load_onf_parcelles_source`](https://pobsteta.github.io/nemeton/reference/load_onf_parcelles_source.md);
  fetched over `aoi` when `NULL`.

- cadastre:

  Optional sf of candidate cadastral parcels with an `idu` column;
  fetched from the IGN WFS (PCI,
  `CADASTRALPARCELS.PARCELLAIRE_EXPRESS:parcelle`) for `insee` when
  `NULL`. A given `cadastre` is taken as is, whatever its communes
  (since 1.2.0; 1.1.x kept only the rows of `insee`).

- proprietaires:

  Optional `data.frame` as returned by
  [`load_parcelles_personnes_morales`](https://pobsteta.github.io/nemeton/reference/load_parcelles_personnes_morales.md);
  read for `insee` when `NULL`.

- pas, dmax, rayon, k:

  Calage parameters, see
  [`caler_onf_sur_cadastre`](https://pobsteta.github.io/nemeton/reference/caler_onf_sur_cadastre.md).
  Defaults `5`, `80`, `200`, `12`.

- seuil_couverture:

  Minimum share of a cadastral parcel covered by the warped ONF for it
  to belong to the forest. Default `0.5`.

- tol:

  Snapping tolerance, in metres. Default `15`.

- larg_hors:

  Minimum width of an uncovered block kept as its own unit, in metres.
  Default `50`.

- ha_hors:

  Minimum area of an uncovered core, in hectares. Default `0.5`.

- seuil:

  Minimum area of an ONF piece and of a UGF, in hectares. Default `0.5`.

- seuil_hors:

  Minimum area of an uncovered piece, in hectares. Default `1`.

- min_part_m2:

  Minimum area of a detached part within a parcel, in square metres.
  Default `500`.

- crs:

  CRS of the result. Default `2154`.

- selection:

  `"foret"` (default) selects the cadastral parcels of the forest as
  described above. `"toutes"` keeps **every** parcel of `cadastre` that
  touches the ONF layer — the caller's own selection — and applies the
  same calage, cutting and attachments; DGFiP owners are then not read
  unless `proprietaires` is given. A kept parcel that is not under the
  *régime forestier* becomes its own `cad~<idu>` unit when its uncovered
  part is at least `larg_hors` wide and `seuil_hors` ha, and is attached
  to its neighbours otherwise; a parcel that does not touch the ONF
  layer at all is kept the same way. Measured on the 23 parcels of the
  Couchey project: 67 UGF, of which four `cad~` (A 283, A 9, A 286, AO
  212: communal, outside the *régime forestier*).

## Value

An sf of tenements (one row per cadastral parcel × UGF) with columns
`idu`, `tenement_id` (`<ugf_id>~<idu>`), `ugf_id` (`<forêt>-<parcelle>`,
or `cad~<idu>` for an uncovered block), `nom_ugf`, `foret_id`,
`foret_nom`, `parcelle`, `domaniale`, `surface_m2` and `part_onf` (share
of the tenement covered by its warped ONF parcel, a confidence measure;
`NA` for `cad~`). The tenements of a parcel tile it exactly, on its
original vertices.

Attributes: `parcelles`, a `data.frame` of every candidate with `idu`,
`retenue`, `raison` (`NA` when kept, `"hors ONF"` for a parcel of
`cadastre` that does not touch the ONF layer, `"privee"` or
`"couverture < 50 %"`), `publique`, `proprietaire`, `groupe`, `natures`,
`couverture_onf` and `surface_ha`; `calage`, as in
[`caler_onf_sur_cadastre`](https://pobsteta.github.io/nemeton/reference/caler_onf_sur_cadastre.md).
`NULL` with a warning when a source cannot be fetched.

## Approximation of the régime forestier

Neither the PCI nor the Etalab cadastre records whether a parcel is
under the *régime forestier*. The authoritative source is the
prefectoral order of application, which is not published parcel by
parcel. The "public owner × ONF coverage" test is an **approximation**
of it, to be checked against the management plan.

## Lifecycle

Experimental (spec 058): may change in any release.

## See also

[`caler_onf_sur_cadastre`](https://pobsteta.github.io/nemeton/reference/caler_onf_sur_cadastre.md),
[`load_parcelles_personnes_morales`](https://pobsteta.github.io/nemeton/reference/load_parcelles_personnes_morales.md),
[`load_onf_parcelles_source`](https://pobsteta.github.io/nemeton/reference/load_onf_parcelles_source.md)
