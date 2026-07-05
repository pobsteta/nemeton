# Canonical canopy-structure provenance from NDP augmented flags

Maps the ML-augmentation flags of
[`detect_ndp`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
to a single canonical canopy-structure provenance key, so a UI can badge
which data produced the canopy / LAI used by the regeneration engines
without re-implementing the flag-to-meaning rule (business logic stays
in the core). Priority: the Sentinel-2 fallback (`lai_ml`) wins — its
presence means LiDAR HD was absent.

## Usage

``` r
canopy_provenance(augmented = character(0))
```

## Arguments

- augmented:

  Character vector of augmentation flags, as returned in the `augmented`
  field of
  [`detect_ndp`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md).

## Value

A single character key:

- `"prosail_s2"`:

  Sentinel-2 LAI (PROSAIL inversion) — the NDP-0 satellite fallback used
  when LiDAR HD is absent (flag `lai_ml`).

- `"opencanopy"`:

  Open-Canopy ML canopy-height model (flag `height_ml`).

- `"lidar_hd"`:

  Native LiDAR HD structure (PAI) — the default when no satellite / ML
  canopy flag is present.

## See also

[`detect_ndp`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)

## Examples

``` r
canopy_provenance(character(0))                  # "lidar_hd"
#> [1] "lidar_hd"
canopy_provenance("lai_ml")                      # "prosail_s2"
#> [1] "prosail_s2"
canopy_provenance(c("height_ml", "species_ml"))  # "opencanopy"
#> [1] "opencanopy"
```
