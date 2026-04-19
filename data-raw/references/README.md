# Bibliographic references — data-raw sources

This folder holds the primary references cited by the `data-raw/`
scripts that generate package data (e.g. `site_index_curves.csv`).

PDFs are **gitignored** to keep the repo lean. Download them from
the HAL links below when you need to audit or extend the parameters.

## Site index curves (`site_index_curves.R`)

### FASY — Fagus sylvatica (Hêtre)

- **Bontemps J.-D., Duplat P., Hervé J.-C., Dhôte J.-F. (2007).**
  *Croissance en hauteur dominante du hêtre dans le Nord de la France :
  des courbes de référence qui intègrent les tendances à long-terme.*
  Rendez-Vous Techniques ONF, HS2, 39-47.
  [HAL hal-00823732](https://hal.science/hal-00823732) — primary
  source of the Korf recursive parameters (Annex 2).

- **Bontemps J.-D., Hervé J.-C., Dhôte J.-F. (2009).**
  *Long-term changes in forest productivity: a consistent assessment
  in even-aged stands.* Forest Science 55(6), 549-564.
  [HAL hal-00873977](https://hal.science/hal-00873977) —
  international version with additional context on the long-term
  drift term (`chprod`).

- **Bontemps J.-D. (2006).** *Évolution de la productivité des
  peuplements réguliers et monospécifiques de hêtre (Fagus sylvatica
  L.) et de chêne sessile (Quercus petraea Liebl.) dans la moitié
  Nord de la France au cours du XXᵉ siècle.* Thèse AgroParisTech.
  [HAL pastel-00761239](https://pastel.hal.science/pastel-00761239)
  — full methodological background and per-region calibration.

### QUPE / QURO — Quercus petraea / Quercus robur (Chênes)

- **Duplat P. & Tran-Ha M. (1997).** *Modélisation de la croissance
  en hauteur dominante du chêne sessile (Quercus petraea Liebl) en
  France.* Annales des Sciences Forestières 54(7), 611-634.
  Parameters currently used via Chapman-Richards approximation;
  pending audit against the original equations.

### PIAB — Picea abies (Épicéa)

- **Seynave I. et al. (2005).** *Picea abies site index in France.*
  Annals of Forest Science 62, 215-223.

### ABAL — Abies alba (Sapin)

- **Vallet P. & Pérot T. (2011).** *Silver fir and Norway spruce
  productivity.* Forest Ecology and Management 261(8), 1390-1400.

### Other species (pending audit)

CASA, PSME, PISY, PIPI, POSP — Chapman-Richards heuristic
calibration; see comments at the top of `site_index_curves.R`.

## Future climate-aware correction (Phase C)

- **Charru M., Seynave I., Hervé J.-C., Bertrand R., Bontemps J.-D.
  (2017).** *Recent growth changes in Western European forests are
  driven by climate warming and structured across tree species
  climatic habitats.* Annals of Forest Science 74:33.
  [HAL hal-01573238](https://hal.science/hal-01573238) — informs
  the future `chprod`/`climate_context` enhancement of
  `compute_site_index()`.
