# GNU General Public License v3.0

nemeton — plateforme d'analyse forestière systémique
Copyright (C) 2026 Pascal Obstetar

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, **version 3** of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

The full text of the GNU General Public License version 3 is available at
<https://www.gnu.org/licenses/gpl-3.0.txt>.

---

## Relicensing note (2026-07-01)

From **v0.110.0**, `nemeton` is distributed under **GPL-3** (previously MIT).
Reason: direct dependency on [`biodivMapR`](https://github.com/jbferet/biodivMapR)
(GPL-3) for the spectral-diversity indicators **B4 / L3** (spec 028). This makes
`nemeton` a copyleft derivative work. Packages that import it
(`nemetonshiny`, `tree_sat_nemeton`, `maestro_nemeton`) become GPL-3 at
distribution by dependency; their own `LICENSE` files are updated in their
respective repositories.

## Related packages & data

- **Produced data** (CC-BY 4.0): indicator values, species maps, reports —
  unaffected by this relicensing (ADR-006 data clause unchanged).
- Downstream packages: see each repository's own `LICENSE`.

## Third-party data attributions

See `inst/NOTICE` (installed alongside the package at
`system.file("NOTICE", package = "nemeton")`) for attributions of the
third-party datasets and models that `nemeton` consumes at runtime
(IGN BD ORTHO, IGN LiDAR HD, Theia OSO, Open-Canopy pre-trained
weights, WorldClim, IFN site-index curves, etc.).
