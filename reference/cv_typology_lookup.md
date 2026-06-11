# CV Typology Lookup for Forest Sampling

Reference coefficient-of-variation (CV) lookup tables used by
[`compute_sample_size`](https://pobsteta.github.io/nemeton/reference/compute_sample_size.md)
to size an inventory plan from a target relative error.

Two CSV files back this module (both under `inst/extdata`):

- `cv_typology.csv` — 8 generic forest contexts with low / mid / high CV
  bounds on basal area (G/ha, the IFN / PPtools convention). Derived
  from expert literature compiled with Pascal Obstetar (2026).

- `bdforet_v2_mapping.csv` — the 32 BD Forêt v2 TFV codes mapped to one
  of the generic contexts, with a confidence flag and a secondary
  candidate for ambiguous classes.

Both files are editable: the user is invited to override them via
`cv_typology(file = ...)` / `bdforet_v2_mapping(file = ...)` to reflect
local silvicultural reality.
