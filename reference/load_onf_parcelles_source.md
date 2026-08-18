# Acquire the ONF public-forest parcel layer for an AOI

Fetch the **forest parcels of French public forests** (state-owned
*domaniales* and local-authority forests under the *régime forestier*)
over `aoi` from the ONF "Forêts publiques" WFS (Carmen, ONF as producer,
public diffusion), and return them ready to be turned into forest
management units (UGF): one row per parcel, with a stable id, a display
label, the owning forest and its ownership status.

The forest parcel is the reference frame ONF uses on the ground for
management, so it is a far better UGF seed than a cadastral parcel. Note
the grain is the **parcel**, not the sub-parcel: the finer management
unit of the *aménagement* is not published, so a parcel may still mix
stands.

Degrades gracefully — returns `NULL` on any failure (no network, service
firewall rejection, OWS exception, unknown territory) so the caller can
fall back to cadastral selection. A 0-row sf is returned when the AOI
simply holds no public forest.

## Usage

``` r
load_onf_parcelles_source(
  aoi,
  crs = 2154,
  domanialite = c("toutes", "domaniale", "autre"),
  territoire = "FR",
  max_parcelles = 5000L,
  clip = FALSE
)
```

## Arguments

- aoi:

  An sf/sfc project extent (must have a defined CRS).

- crs:

  Target EPSG of the returned layer. Default `2154`.

- domanialite:

  Ownership filter: `"toutes"` (default), `"domaniale"` (state forests
  only) or `"autre"` (local-authority and other public forests). Parcels
  whose ownership could not be resolved are dropped by the two filtering
  modes.

- territoire:

  Territory served by the WFS: `"FR"` (metropolitan, default), `"GLP"`,
  `"MTQ"`, `"GUF"`, `"REU"` or `"MYT"`.

- max_parcelles:

  Maximum number of parcels requested (`COUNT`). Guards against pulling
  a whole region; a warning is emitted when the service announces more
  matches than returned. Default `5000`.

- clip:

  Clip parcels to `aoi` instead of keeping whole parcels that intersect
  it. Default `FALSE` — a UGF is normally the entire parcel.

## Value

An sf of forest parcels in `crs` with columns `id`
(`<forêt>-<parcelle>`), `foret_id`, `foret_nom`, `parcelle`,
`domaniale`, `nom_ugf`, `contenance` (m², computed in the territory's
projected CRS) and `surface_ha`; a 0-row sf if none; `NULL` on failure.

## See also

[`load_foret_ancienne_source`](https://pobsteta.github.io/nemeton/reference/load_foret_ancienne_source.md),
[`get_layer_service`](https://pobsteta.github.io/nemeton/reference/get_layer_service.md)
