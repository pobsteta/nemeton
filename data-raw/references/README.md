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

## Knowledge corpus — BILJOU institutional sources (`build_knowledge_corpus.R`)

Cleared institutional reports cited by the BILJOU tool (INRAE Nancy) and
ingested full-text by the RAG corpus build. PDFs gitignored; download to
`data-raw/references/` under the filename used in `knowledge_corpus_v1.csv`
(`local_path`):

- **Ulrich E., Lelong N., Lanier M., Schneider (1995).** *Interception des
  pluies en forêt — sous-réseau CATAENAT de RENECOFOR.* ONF, Bulletin
  technique n°30. → `Ulrich_et_al_1995.pdf`
  <https://appgeodb.nancy.inrae.fr/biljou/pdf/Ulrich_et_al_1995.pdf>
- **Badeau V. & Bréda N. (2008).** *Modélisation du bilan hydrique : étape
  clé.* RDV techniques hors-série n°4, ONF. → `Badeau_Breda_2008_RENECOFOR.pdf`
  <https://appgeodb.nancy.inrae.fr/biljou/pdf/Badeau_Br%C3%A9da_2008_RENECOFOR.pdf>
- **Allen R.G., Pereira L.S., Raes D., Smith M. (1998).** *Crop
  evapotranspiration — FAO Irrigation and Drainage Paper 56.* FAO, Rome.
  → `FAO56_x0490e.pdf` (official: <https://www.fao.org/3/x0490e/x0490e00.htm>;
  single-PDF copies available from public mirrors).
- **IPCC (2019).** *2019 Refinement to the 2006 IPCC Guidelines — Vol. 4,
  Ch. 4 Forest Land.* → `IPCC_2019_V4_Ch04_ForestLand.pdf`
  <https://www.ipcc-nggip.iges.or.jp/public/2019rf/pdf/4_Volume4/19R_V4_Ch04_Forest%20Land.pdf>
- **Duplat P. & Tran-Ha M. (1997).** *Croissance en hauteur dominante du
  chêne sessile.* Ann. Sci. For. 54(7). → `Duplat_TranHa_1997.pdf`
  <https://www.afs-journal.org/articles/forest/pdf/1997/07/AFS_0003-4312_1997_54_7_ART0003.pdf> (EDP open archive)
- **Larrieu et al. — IBP.** *Indice de Biodiversité Potentielle, guide CNPF
  v3.2.* → `Larrieu_IBP_CNPF_v3.pdf`
  <https://www.cnpf.fr/sites/socle/files/2026-04/IBP_FR_v3_2_260202.pdf>
- **Commission européenne (2021).** *Stratégie de l'UE pour les forêts —
  COM(2021) 572.* → `Strategie_foret_UE_2021_COM572.pdf`
  <https://eur-lex.europa.eu/resource.html?uri=cellar:0d918e07-e610-11eb-a1a5-01aa75ed71a1.0012.02/DOC_1&format=PDF>

### Open-access PDFs to fetch manually (anti-bot blocks scripted download)

These refs are open access but their host (`hal.science` Cloudflare, MDPI)
serves a JS/anti-bot wall to `curl`. Download with a browser into
`data-raw/references/`, set `local_path` and flip the row to `full` to ingest
the full text (currently ingested as `link_only` references):

- **Monnet & Mermin (2014)**, *Forests* 5(9):2307-2326, DOI 10.3390/f5092307
  — <https://www.mdpi.com/1999-4907/5/9/2307/pdf> · <https://hal.science/hal-01086012>
- **OFB CT88 / CT82** (web-books, no single PDF) — <https://ct88.espaces-naturels.fr/> · <https://ct82.espaces-naturels.fr/>

Other cleared institutional refs without a public full-text PDF (reference
only, `source_url` in the manifest): Badeau & Ulrich 2008 and Peiffer et al.
2008 ([HAL hal-02813279](https://hal.inrae.fr/hal-02813279),
[HAL hal-03758947](https://hal.inrae.fr/hal-03758947)); EFI WSCTU n°1
([efi.int](https://efi.int/publications-bank/wsctu)); Bréthes & Ulrich 1997
(no public digital edition).

## H_dom → D_g allometry (NDP 1 synthetic inventory)

The per-species power-law parameters used by
`estimate_dq_from_hdom()` (power law `D_g = a · H^0.9` with clamps
to the observed D_g range) are calibrated against the mean IFN
`(H_0, D_g)` pair of each species, crossing two Charru papers:

| Code | H_0 IFN mean | D_g IFN mean | Source H_0         | Source D_g     |
|------|--------------|--------------|--------------------|----------------|
| FASY |  24.7 m      |  27.3 cm     | Charru 2017 Tab. 1 | Charru 2012 T1 |
| QUPE |  23.3 m      |  23.0 cm     | Charru 2017 Tab. 1 | Charru 2012 T1 |
| QURO |  21.3 m      |  26.0 cm     | Charru 2017 Tab. 1 | Charru 2012 T1 |
| PIAB |  24.5 m      |  29.3 cm     | Charru 2017 Tab. 1 | Charru 2012 T1 |
| ABAL |  25.3 m      |  29.6 cm     | Charru 2017 Tab. 1 | Charru 2012 T1 |
| PISY |  15.0 m      |  22.2 cm     | Charru 2017 Tab. 1 | Charru 2012 T1 |
| QUPU |  14.2 m      |  21.2 cm     | Charru 2017 Tab. 1 | Charru 2012 T1 |
| PIHA |  12.3 m      |  23.5 cm     | Charru 2017 Tab. 1 | Charru 2012 T1 |
| PSME |  ~25 m*      |  28.1 cm     | IFN 2004 typical*  | Charru 2012 T1 |
| PIPI |  ~17 m*      |  26.3 cm     | IFN 2004 typical*  | Charru 2012 T1 |
| PILA |  ~20 m*      |  30.5 cm     | IFN 2004 typical*  | Charru 2012 T1 |

(*) species not in Charru 2017 Tab. 1; H_0 typical values from
generic IFN 2004 population statistics — less anchored. CASA and
POSP fall back to broadleaf genus defaults (a = 1.45) for the
same reason.

Enforced by `tests/testthat/test-synthetic-inventory-calibration.R`
with 1 cm tolerance on the IFN mean back-propagation.

Phase B (yield-table upgrade, precision target ±15 %) would
replace this power-law with a proper age-aware table lookup from
Vannière 1984 (*Tables de production pour les forêts françaises*,
ENGREF, ISBN 2-85710-016-7); the book is available at ~40 € from
Decitre / Unithèque / Librairie Gérard, not on HAL.

## Future climate-aware correction (Phase C)

- **Charru M., Seynave I., Hervé J.-C., Bertrand R., Bontemps J.-D.
  (2017).** *Recent growth changes in Western European forests are
  driven by climate warming and structured across tree species
  climatic habitats.* Annals of Forest Science 74:33.
  [HAL hal-01573238](https://hal.science/hal-01573238) — informs
  the future `chprod`/`climate_context` enhancement of
  `compute_site_index()`.
