# Cadrage L2b — pipeline RECONFORT IOTA²-natif (spec 021)

**Statut** : cadrage (paperwork avant code) — 2026-06-11
**Pré-requis** : L1 (v0.70.0), L2a (v0.71.0) livrés.
**Cible** : `nemeton` v0.72.0+ (probablement scindé, voir §6).

---

## 1. Décisions cadrées (2026-06-11)

| # | Question | Décision |
|---|----------|----------|
| D1 | Ingestion S2 pour IOTA² | **IOTA²-natif** : télécharger les scènes S2 brutes (MUSCATE L2A) via la chaîne amont (pygeodes/GEODES) dans le layout attendu par IOTA². **Pas** de réutilisation du cache COG FAST. |
| D2 | Environnement conda | **Localiser + valider** : l'utilisateur installe l'env `nemeton-reconfort` (mamba install iota2) ; nemeton le localise/valide, abort avec instructions si absent. |
| D3 | Glue Python vendorisée | **Suivre D1 → chaîne complète** : download + générateurs de cfg + wrapper `Iota2.py` (subprocess ×2) + masquage/score. |

**Conséquence** : L2b est l'intégration IOTA² **complète** — c'est le lot le plus
lourd, avec dépendances externes réelles (compte GEODES, env conda IOTA²,
téléchargement S2 volumineux, exécution OTB/Shark type batch/HPC). Il **doit
être scindé** (§6).

---

## 2. La chaîne amont (vérifiée sur le clone `main` 25198c9)

Trois étapes successives côté RECONFORT :

1. **Download** (`run_geodes_download.py`) — `pygeodes` + compte GEODES
   (`pygeodes-config.json`, clé API) interroge MUSCATE S2 L2A par **tuile MGRS**
   + plage de dates, télécharge les archives zip dans `zip_path`.
2. **Process** (`run_process_downloaded_images.py`) — dézippe vers `out_dir`,
   produisant le layout S2 attendu par IOTA² : `/S2_data/<year>/<tile>/`
   (2 années par tuile).
3. **Map production** (`run_map_production_reconfort.py`) — génère les cfg
   IOTA² (part1 sampling, part2 classification), lance `Iota2.py` en
   **subprocess ×2**, copie le modèle (L2a) dans le dossier IOTA², applique le
   RF (OTB/Shark), masque (OSO feuillus par défaut), calcule le **score continu**
   `(1001 + (−P1 + P2 + 2·P3))/30`. Sorties dans
   `results/iota2_results_classif_labels-<label>-S2_<year>/final/` :
   `Classif_Seed_0.tif`, `ProbabilityMap_seed_0.tif`,
   `Final_Classif_masked_<year>.tif`, `Final_continuous_score_masked<year>.tif`
   (CRS **EPSG:2154**).

**Entrées que nemeton doit fournir** : tuile(s) MGRS dérivée(s) de l'AOI,
année S2 (dernière de 2), plage de dates, `v_model` (L2a), masque binaire
(OSO par défaut), compte GEODES.

---

## 3. Architecture nemeton-native (D1+D2+D3)

`run_reconfort_dieback(con, zone_id, cache_dir, ...)` orchestre :

```
   con + zone_id  →  AOI (.get_zone_aoi)
        │
        ▼  ENV          .ensure_reconfort_python()  — locate+validate conda (D2)
        ▼  MODEL        ensure_reconfort_model(v_model)            (L2a)
        ▼  TILE         AOI → tuile(s) MGRS S2
        ▼  DOWNLOAD     pygeodes(GEODES) → /S2_data/<year>/<tile>/  (vendor)
        ▼  PROCESS      unzip → layout IOTA²                        (vendor)
        ▼  MAP-PROD     cfg IOTA² → Iota2.py ×2 → RF → mask → score (vendor)
        │
        ▼  RESULT       classif.tif + proba.tif + score.tif + run_meta.json
```

Le **post-process → table `alert`** (centroïdes, confidence_class, stress_index
= score continu) reste **L3**, pas L2b.

### Fichiers cœur visés

| Fichier | Rôle | Sous-lot |
|---------|------|----------|
| `R/reconfort_python.R` | `.ensure_reconfort_python()` / `.use_reconfort_env()` — locate+validate conda IOTA² | L2b.1 |
| `inst/python/reconfort/` | glue vendorisée Apache-2.0 (custom_index, cfg generators, download, masking/score) + `inst/NOTICE` | L2b.1 |
| `R/reconfort_ingest.R` | AOI→MGRS tile + wrapper pygeodes download + process/unzip | L2b.2 |
| `R/reconfort_pipeline.R` | `run_reconfort_dieback()` orchestration phases 0-3 | L2b.3 |
| `RECONFORT_BANDS` | constante `c("B04","B05","B06","B8A","B11","B12")` (documentaire — IOTA² lit le L2A complet) | L2b.1 |

---

## 4. Environnement conda (D2) — locate + validate

`.ensure_reconfort_python()` (calqué sur `.ensure_fordead_python()` mais conda) :
- localise l'env `nemeton-reconfort` via `reticulate::conda_list()` /
  `use_condaenv("nemeton-reconfort", required = TRUE)` (nom surchargeable par
  `options(nemeton.reconfort_conda_env)`) ;
- valide : python 3.9–3.11, `iota2` importable, `pygeodes` importable,
  `Iota2.py` sur le PATH ;
- abort typé avec les instructions d'install amont si absent
  (`mamba install iota2 -c iota2 -c iota2-deps` ; `pip install pygeodes`).
- **Ne bootstrappe pas** l'env (D2).

---

## 5. Frontière mock / réel

- **Unit tests** (CI) : reticulate/Python **mockés**, subprocess Iota2 mocké,
  pygeodes mocké. Skip si reticulate absent. Aucune dépendance réelle.
- **Intégration réelle** : opt-in `NEMETON_RECONFORT_INTEGRATION=TRUE`,
  nécessite l'env conda + un compte GEODES + ~dizaines de Go de S2 +
  exécution OTB/Shark (lourde, type batch). **Jamais en CI.**

---

## 6. Découpage proposé de L2b (scindé)

L2b complet est trop gros pour un seul lot. Proposition :

| Sous-lot | Contenu | Testable seul |
|----------|---------|---------------|
| **L2b.1** | `reconfort_python.R` (env conda) + glue vendorisée `inst/python/reconfort/` + `RECONFORT_BANDS` + `inst/NOTICE` | ✅ (env mocké, import glue) |
| **L2b.2** | `reconfort_ingest.R` : AOI→MGRS tile + wrapper pygeodes download + process/unzip | ✅ (pygeodes/subprocess mockés) |
| **L2b.3** | `reconfort_pipeline.R::run_reconfort_dieback()` : orchestration env→model→ingest→IOTA²→score + outputs | ✅ (mocké) + intégration opt-in |

Chaque sous-lot = une release mineure (feat).

---

## 7. Questions ouvertes à trancher avant de coder L2b.1

1. **AOI → tuile MGRS** : IOTA²-natif raisonne par tuile S2 (T31UEQ…). Comment
   dériver la/les tuile(s) couvrant l'AOI ? Options : (a) embarquer la grille
   MGRS S2 (KML/GeoJSON Sentinel-2) et intersecter ; (b) interroger GEODES pour
   les tuiles intersectantes. → décision L2b.2.
2. **Compte GEODES** : confirmes-tu disposer (ou pouvoir créer) d'un compte
   GEODES (gratuit, CNES) + `pygeodes-config.json` ? Indispensable pour tout
   run réel (les tests mockés n'en ont pas besoin). nemeton **n'embarque aucune
   clé** — chemin fourni via `options(nemeton.geodes_config)` ou argument.
3. **GEODES vs THEIA** : l'amont supporte les deux (`config_file_theia_download`
   aussi). Défaut **GEODES** (portail CNES actuel), THEIA en alternative ?
4. **Empreinte/temps** : un run réel = 2 ans de S2 d'une tuile (~dizaines de Go)
   + IOTA² (RAM/CPU lourd, `scheduler_type=localCluster` ou Slurm). C'est un
   traitement **batch**, pas interactif. Acceptes-tu ce profil (ExtendedTask /
   worker côté app, durées longues) ?

---

## 8. Prochaine étape

Sur accord du découpage (§6) et des questions ouvertes (§7) : démarrer
**L2b.1** (fondations Python : env conda + glue vendorisée + `RECONFORT_BANDS`),
le sous-lot le moins risqué et 100 % testable en mocké.
