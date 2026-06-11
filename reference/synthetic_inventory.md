# Synthetic inventory from a Canopy Height Model (NDP 1)

Derive a coarse stand-level inventory (quadratic mean diameter \\D_g\\
and stems per hectare \\N\\) for each spatial unit directly from a CHM,
a species code and (optionally) a stand age. This is the *NDP 1
synthetic* path between NDP 0 (public raster/vector data only) and NDP 2
(actual terrain measurements), introduced alongside the Open-Canopy CHM
integration (spec 005 phase 6+) so that indicators depending on \\D_g\\
or \\N\\ (P1, P3, E1) do not have to silently fail at NDP 0.

## Details

The method is intentionally simple: \\H\_{dom}\\ is extracted from the
CHM per unit, inverted to a plausible \\D_g\\ through a species-specific
linear allometry, and the resulting \\D_g\\ is fed to the Charru 2012
self-thinning relationship to obtain the maximum stand density at that
diameter. A user-tunable stocking fraction (default 0.75) is applied to
reflect the typical ratio of observed density to the self-thinning
boundary in French managed stands.
