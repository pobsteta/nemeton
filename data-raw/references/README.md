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

### Other species — Phase A calibration vs published points

Parameters for the following species remain on a Chapman-Richards
approximation (pending full equation transcription), but the
(a, k, p) triplets are calibrated to match one published reference
point per species at ±0.5 m. Enforced by
`tests/testthat/test-site-index-calibration.R`.

| Code | Published point           | Source                         |
|------|---------------------------|--------------------------------|
| QUPE | H(100) class_3 ≈ 24.0 m   | Duplat & Tran-Ha 1997          |
| QURO | H(100) class_3 ≈ 22.0 m   | Duplat & Tran-Ha 1997          |
| CASA | H(80)  class_3 ≈ 22.0 m   | Dhôte-like scaling (IFN 2004)  |
| PIAB | H(50)  class_3 ≈ 22.0 m   | Seynave et al. 2005            |
| ABAL | H(50)  class_3 ≈ 20.0 m   | Vallet & Pérot 2011            |
| PSME | H(50)  class_3 ≈ 27.5 m   | DSF / IRSTEA 2010              |
| PISY | H(50)  class_3 ≈ 16.5 m   | Duplat 2001 follow-up          |
| PIPI | H(40)  class_3 ≈ 17.5 m   | Lemoine 1991 (IFN Landes)      |
| POSP | H(25)  class_3 ≈ 23.5 m   | CNPF 2013 (peupleraie)         |

FASY is separately handled via the Korf recursive model of
Bontemps et al. 2007 (see the FASY block in
`data-raw/site_index_curves.R`).

Future phase B would replace each Chapman-Richards approximation
with the species' native equation (Lundqvist-Matérn BP2 for
QUPE/QURO from Bontemps 2006, Chapman-Richards fitted via
stochastic frontier for PIAB from Seynave 2005, etc.); this
requires non-linear mixed-effects fits over IFN microdata and is
out of scope of a single documentation pass.

## Future climate-aware correction (Phase C)

- **Charru M., Seynave I., Hervé J.-C., Bertrand R., Bontemps J.-D.
  (2017).** *Recent growth changes in Western European forests are
  driven by climate warming and structured across tree species
  climatic habitats.* Annals of Forest Science 74:33.
  [HAL hal-01573238](https://hal.science/hal-01573238) — informs
  the future `chprod`/`climate_context` enhancement of
  `compute_site_index()`.
