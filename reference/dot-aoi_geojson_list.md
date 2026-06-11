# GeoJSON representation of an AOI, R list (used for \`pystac.Item.geometry\`)

\`pystac.Item.geometry\` accepts a GeoJSON dict. \`sf::st_as_text()\` +
\`geojsonio::geojson_json()\` would work but pulls a heavy dep. We build
the dict by hand via \`sf::st_geometry()\` -\> coordinates.

## Usage

``` r
.aoi_geojson_list(aoi)
```

## Arguments

- aoi:

  An \`sf\` or \`sfc\` object. Reprojected to EPSG:4326.

## Value

A nested R list \`list(type=..., coordinates=...)\` ready for
\`reticulate::r_to_py()\` -\> Python dict.
