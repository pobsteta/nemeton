# Spécification Fonctionnelle : Suivi sanitaire des feuillus (RECONFORT)

**Version** : 0.1.0 (draft validé — §10 spec 021 tranché sur dépôt amont)
**Date**    : 2026-06-10
**Statut**  : Draft — décisions validées, prêt pour `plan.md` (déjà rédigé)
**Auteur**  : Pascal Obstétar (via Claude)
**Cible**   : `nemeton` v0.68.0+ (cœur) + `nemetonshiny` (app, release suivante)
**Étend**   : spec 008 (suivi sanitaire) — ajoute une 3ᵉ méthode au triptyque, comble le hors-scope feuillus (008 §1.4, §4.5)
**ADR**     : ADR-013 amendement A4 (suivi sanitaire multi-méthodes)
**Source amont** : RECONFORT — https://framagit.org/fl.mouret/reconfort (clone vérifié `main` 25198c9, Apache-2.0)

---

## 1. Résumé Exécutif

### 1.1 Vision

Permettre à un forestier d'instruire l'état sanitaire de ses peuplements
**feuillus** (chêne, châtaignier) et du pin sylvestre à partir des images
Sentinel-2, en intégrant la méthode **RECONFORT** (Mouret et al. 2023,
CESBIO / Université d'Orléans, doi:10.1109/JSTARS.2023.3332420) — première
méthode opérationnelle de cartographie du dépérissement du chêne validée en
région Centre-Val de Loire — comme **méthode officielle du diagnostic
feuillus**, en complément de FORDEAD (résineux) et du détecteur de
changement brutal FAST (NDVI/NBR).

### 1.2 Principe — Stratégie hybride à 3 méthodes

| Pipeline | Méthode | Question | Domaine de validité | Coût |
|----------|---------|----------|---------------------|------|
| **FAST** (surveillance rapide) | rolling-window NDVI/NBR | « Choc récent ? » | tout peuplement | secondes |
| **FORDEAD** (diagnostic résineux) | modèle harmonique CRSWIR auto-calibré | « Dépérissement progressif résineux ? » | épicéa + sapin, massifs Est | minutes–heures |
| **RECONFORT** (diagnostic feuillus) | Random Forest supervisé CRswir + CRre | « Dépérissement progressif feuillus ? » | chêne + châtaignier + pin sylvestre, Centre-Val de Loire | minutes |

**Complémentarité, pas redondance.** FORDEAD est non validé sur feuillus
(spec 008 §4.5 limite 5) ; RECONFORT est calibré dessus. Les trois pipelines
alimentent **la même table `alert`** (TimescaleDB) avec un `alert_type`
discriminant supplémentaire : `reconfort_dieback`. Le projet `nemeton`
n'embarque pas la chaîne RECONFORT : appel runtime via **reticulate** vers un
environnement conda IOTA² isolé. La licence amont est **Apache-2.0**
(permissive, sans copyleft) : la glue Python est **vendorisée** dans le
package (≠ confinement « frontière reticulate » de la GPL-3 de FORDEAD).

### 1.3 Objectifs métier

| Objectif | Métrique de succès |
|----------|-------------------|
| Détecter un dépérissement feuillus (chêne/châtaignier) à grande échelle | `run_reconfort_dieback()` produit un raster de classe + score continu et alimente la table `alert` |
| Router le diagnostic vers la bonne méthode selon l'essence | UGF résineux → R5 via FORDEAD ; UGF feuillus → R5 via RECONFORT ; sinon NA |
| Distinguer dépérissement vs perturbation mécanique | Fusion G2 à 3 voies : RECONFORT + FAST (±30 j) → `mechanical` ; RECONFORT seul → `progressive` |
| Garantir la fiabilité des alertes affichées | Filtrage par probabilité RF (G1), seuil documenté depuis la matrice de confusion RECONFORT |
| Documenter les limites de validité | Bannière géo (Centre-Val de Loire) + essences (feuillus) ; **avertit sans bloquer** (pas de verrou amont) |
| Permettre la validation terrain | Workflow QField réutilisé, schéma de saisie feuillus (stades DSF) |
| Alimenter la famille R d'indicateurs | R5 **unifié** (pas de R6), routé par essence dominante |

### 1.4 Hors-scope

- **Ré-entraînement / fine-tuning des modèles RF** : on consomme les modèles
  RECONFORT tels quels ; le code amont `train_new_model/` est hors-scope
  (aligné sur le hors-scope « pas de fine-tuning » de spec 008 §1.4).
- **Extracteur de features pixel-wise autonome** (sans IOTA²) : R&D non
  validée amont (spec 021 §10 Q5) — hors v0.68.x.
- **Usage hors essences cibles** (autres que chêne, châtaignier, pin
  sylvestre) : la bannière avertit, l'utilisateur reste responsable.
- **Verrou géographique dur** : le code amont n'en pose aucun (son exemple
  tourne hors CVL). On reproduit ce choix : bannière, pas blocage.
- **Cron worker automatique** : déclenchement à la demande (idem FAST/FORDEAD).
- **Prévisions quantitatives de volumes / pertes économiques.**

---

## 2. Scope

### 2.1 Inclus dans nemeton v0.68.0+ (cœur)

- **Pipeline RECONFORT côté cœur** :
  - `R/reconfort_pipeline.R` : `run_reconfort_dieback(con, zone_id, cache_dir, dates_obs, model = NULL, ...)` — orchestration end-to-end via reticulate (phases 0 ingest → 1 STAC → 2 features IOTA² → 3 predict RF → 4 postprocess → 5 persist).
  - `R/reconfort_python.R` : helpers reticulate vers l'**env conda** IOTA² (`.ensure_reconfort_python()`, `.use_reconfort_env()` via `use_condaenv()`).
  - `R/reconfort_model.R` : `ensure_reconfort_model(version, cache_dir)` — **téléchargement à la demande + checksum + cache**, fallback chemin utilisateur (modèles 5,7–197 Mo, inembarquables).
  - `R/reconfort_postprocess.R` : rasters classes + score continu → schéma `alert` (patches 8-connexité → POINT centroïdes + classe + `stress_index`).
  - `R/reconfort_validity.R` : `check_reconfort_validity(aoi, units)`, `load_reconfort_validity_zones()`, `RECONFORT_VALIDITY_DEPARTMENTS`, `RECONFORT_VALIDITY_SPECIES`.
- **Indicateur R5 unifié** : `indicateur_r5_deperissement(units, fordead_results = NULL, reconfort_results = NULL, ...)` — routage par essence dominante.
- **Constantes calibrées** : `RECONFORT_BANDS <- c("B04","B05","B06","B8A","B11","B12")` ; `RECONFORT_CONFIDENCE_WEIGHTS` (matrice de confusion RECONFORT).
- **Glue Python vendorisée** : `inst/python/reconfort/` (Apache-2.0 : `custom_index.py`, génération cfg, masquage/score).
- **Données embarquées** :
  - `inst/extdata/reconfort_validity_zones.geojson` : 6 départements CVL (18, 28, 36, 37, 41, 45).
  - `inst/datasources/FR.json` : nouvelle source `reconfort_anomalies`.
- **NDP augmenté** : flag `health_reconfort` dans `detect_ndp()`.
- **Schéma SQL** : migration `0005_reconfort.sql` additive (réutilise `confidence_class` + `stress_index` ; index sur `alert_type = 'reconfort_dieback'` au besoin).
- **Schéma de saisie QField** : `get_health_validation_schema()` étendu aux stades de dépérissement feuillus.

### 2.2 Inclus dans nemetonshiny (app, release séparée)

- **`mod_monitoring`** : 3ᵉ mode (toggle) « Diagnostic feuillus (RECONFORT) ».
- **Bannières d'avertissement** : géo (Centre-Val de Loire) + essences (feuillus) via `check_reconfort_validity()` — **avertissent sans bloquer**.
- **Leaflet** : alertes `reconfort_dieback`, popup probabilité RF + score continu.
- **Plotly** : séries CRswir + CRre au clic (parité avec le diagnostic pixel FORDEAD — nécessite la persistance des features, phase 5).
- **Clés i18n FR/EN** : `monitoring_mode_reconfort`, `monitoring_reconfort_phase_*`, `monitoring_reconfort_outside_validity`, `monitoring_reconfort_crswir`, `monitoring_reconfort_crre`.

### 2.3 Hors-scope de la première release (reportés)

- Persistance des features pour le diagnostic pixel (lot L5, release ultérieure).
- App `nemetonshiny` (lot L6, release app distincte).
- Extension européenne des zones de validité (hors CVL).

---

## 3. Architecture

### 3.1 Frontière nemeton / nemetonshiny (ADR-009)

Identique au pattern FORDEAD (spec 008 §3.1) : toute la logique métier
(pipeline, post-processing, R5, validité, schéma SQL, datasource) vit dans
`nemeton`. `nemetonshiny` est purement présentationnel (toggle UI, bannières,
plotly, leaflet, async wrapper). Aucune logique métier côté app.

### 3.2 Frontière R / Python — couche reticulate + conda

- **Environnement conda dédié** `nemeton-reconfort` (IOTA² + Shark/OTB),
  isolé de `nemeton-fordead`. RECONFORT impose conda
  (`mamba install iota2 -c iota2 -c iota2-deps`, python 3.9–3.11,
  `pygeodes` en pip) — **pas** un `requirements.txt` pip ; reticulate pointe
  via `use_condaenv()`.
- **Licence Apache-2.0** : glue Python **vendorisée** dans `inst/python/reconfort/`,
  attribuée dans `inst/NOTICE`. `nemeton` reste sous MIT. Modèles RF
  (Apache-2.0) distribués hors-package (téléchargement + checksum).

### 3.3 Pipeline RECONFORT complet (par zone)

```
   con + zone_id + cache_dir
        │
        ▼  PHASE 0 — ingest (réutilise spec 008 §13)
   ingest_sentinel2_timeseries(bands = RECONFORT_BANDS, skip_cached = TRUE)
        │
        ▼  PHASE 1 — stac_assembly
   aoi <- .get_zone_aoi(con, zone_id)
   .build_stac_collection_for_aoi(aoi, scenes_df, cache_dir, RECONFORT_BANDS)
        │
        ▼  PHASE 2 — features (Python via reticulate, chaîne IOTA²)
   série interpolée IOTA² → CRswir + CRre (custom_index.py),
   masquage nuages/ombres → matrice de features par pixel
        │
        ▼  PHASE 3 — predict (Python via reticulate, OTB/Shark)
   modèle RF pré-entraîné → classe + probabilité par pixel
        │
        ▼  PHASE 4 — postprocess (R)
   score continu (1001 + (−P1 + P2 + 2·P3))/30, borné ~1..100, 0 = no-data
   raster classes → patches 8-connexité → centroïdes POINT
   classe RF → confidence_class ; score → stress_index
   masque essence externe (OSO feuillus par défaut)
   INSERT alert (alert_type = 'reconfort_dieback')
        │
        ▼  PHASE 5 — persist (optionnel)
   features CRswir/CRre + run_meta.json (parité diagnostic pixel FORDEAD)
```

### 3.4 Logique de fusion (G2) — 3 voies

`classify_disturbance()` gère la co-occurrence des trois `alert_type`,
calculée à la volée (non persistée) :

| Signaux présents (même pixel/plot, ±30 j) | `disturbance_type` |
|-------------------------------------------|--------------------|
| FAST seul | `recent_event` |
| FORDEAD **ou** RECONFORT seul | `progressive` |
| (FORDEAD ∣ RECONFORT) **+** FAST | `mechanical` |
| FORDEAD **+** RECONFORT (zone mixte limitrophe) | `progressive` + drapeau `method_overlap` (signaler, ne pas double-compter) |

---

## 4. Méthode RECONFORT — paramètres et calibration

### 4.1 Indices de végétation

Deux indices Sentinel-2 complémentaires, calculés sur la **série interpolée
IOTA²** dans `iota2/external_features/custom_index.py` (formules de
production, **sans offset additif**) :

```
CRswir = B11 / [ B8A + (1610 − 865) · (B12 − B8A) / (2190 − 865) ]   # teneur en eau
CRre   = B5  / [ B4  + ( 704 − 665) · (B6  − B4 ) / ( 741 − 665) ]   # chlorophylle
```

Bandes : `B04, B05, B06, B8A, B11, B12` (**ni B02 ni B07**).
λ (nm) : B04=665, B05=704, B06=741, B8A=865, B11=1610, B12=2190.

### 4.2 Période d'observation

- Modèle `v3` : **2 années consécutives** (1ᵉʳ janv. Y1 → 31 déc. Y2).
- Modèle `v3_early_may` : **1,5 an** (janv. → mai), détection précoce.

### 4.3 Modèles RF (Shark/OTB via IOTA²)

| Modèle | Cible | Classes | Taille |
|--------|-------|---------|--------|
| `v3` | chêne (2 ans) | 3 | 197 Mo |
| `v3_early_may` | chêne (1,5 an) | 3 | 197 Mo |
| `v3_chestnut` | châtaignier | 3 | 14 Mo |
| `v3_pine` | pin sylvestre | 2 | 5,7 Mo |

Redistribuables (Apache-2.0) mais inembarquables → fetch à la demande +
checksum + cache. Étiquette d'entraînement `dep_cor`, seuil %D+ via
`DEPERIS_pe`.

### 4.4 Classes et score continu

- **Classes** : 1 sain / 2 dépérissant / 3 très dépérissant (chêne,
  châtaignier) ; 1 / 2 (pin).
- **Score continu** (de `mask_and_compress_rasters.py::compute_continuous_score`) :

  ```
  score = (1001 + (−P1 + P2 + 2·P3)) / 30      # P1=sain, P2=dépérissant, P3=très dépérissant
  ```

  Borné ~1..100 (1 = sain, 100 = très dépérissant), 0 = no-data. Alimente
  `stress_index`. **CRS EPSG:2154** (Lambert-93).
- **Séparation feuillus/résineux** : par **masque externe** (OSO feuillus
  2021 par défaut), appliqué en aval, **pas** par le RF.

### 4.5 Limites documentées

- **Validité géographique** : calibrée sur 6 départements CVL, **non
  verrouillée** dans le code (l'exemple amont tourne hors CVL). Extrapolation
  sous responsabilité utilisateur.
- **Supervision figée** : pas de ré-entraînement local (hors-scope).
- **Dépendance IOTA²/conda** : chaîne lourde orientée production batch.
- **Robustesse régionale** : ≈ 80 % de bonne classification sur zones
  d'apprentissage, ≈ −5 % hors zones vues (Mouret et al. 2023).

---

## 5. Garde-fous applicatifs (parallèles aux G1-G5 de spec 008)

### G1 — Filtrage par confiance

Seules les classes à forte probabilité RF remontent par défaut ; seuil
documenté depuis la matrice de confusion RECONFORT
(`RECONFORT_CONFIDENCE_WEIGHTS`). Miroir du filtrage classes 3-4 de FORDEAD.

### G2 — Fusion à 3 méthodes

cf. §3.4. `classify_disturbance()` étendu à 3 voies.

### G3 — Bannières validité (avertissent, ne bloquent pas)

`check_reconfort_validity()` → `geo_valid` (intersection Centre-Val de Loire
> 50 %) + `species_valid` (≥ X % chêne/châtaignier/pin sylvestre, BD Forêt
v2). **Différence avec FORDEAD** : la bannière avertit mais **ne bloque
pas** le calcul (le code amont ne pose aucun verrou géo).

### G4 — Validation terrain par QField

Workflow QField réutilisé (spec 008 §6), schéma de saisie adapté aux stades
de dépérissement feuillus (protocole DSF feuillus). Cycle de vie d'alerte
identique (`pending → confirmed | false_positive | closed`).

### G5 — Indicateur R5 pondéré par confiance

cf. §7. R5 unifié routé par essence ; poids RECONFORT distincts des poids
FORDEAD.

---

## 6. Workflow de validation terrain (G4)

Réutilise intégralement l'infrastructure de spec 008 §6 :

- **États d'une alerte** : `pending → confirmed | false_positive | closed`.
- **Génération de placettes** : `generate_health_validation_plots(alerts_sf, n)`
  sur les alertes `reconfort_dieback`.
- **Schéma de saisie** : `get_health_validation_schema()` étendu — stades de
  dépérissement feuillus (défoliation, mortalité de branches, descente de
  cime), cause, taux de couvert, essence dominante, photo.

---

## 7. Indicateur R5 dépérissement — unifié, routé par essence

### 7.1 Définition

`nemeton` **n'ajoute pas de R6**. L'indicateur R5 existant
(`R/indicators-deperissement.R`) reste « dépérissement détecté par
télédétection » ; la méthode est un **détail d'implémentation routé par
l'essence dominante** de chaque UGF :

- UGF résineux (EPC/SAP) + zone FORDEAD valide → R5 via FORDEAD ;
- UGF feuillus (chêne/châtaignier) + zone RECONFORT valide → R5 via RECONFORT ;
- sinon → R5 = NA.

`indicateur_r5_deperissement()` gagne un paramètre `reconfort_results = NULL`.

### 7.2 Conditions d'application

`r5_status` s'enrichit de `"calculated_reconfort"` et `"skipped_no_method"`.
R5 retourne **NA** quand l'UGF n'a ni méthode applicable (essence/zone) ni
run correspondant.

### 7.3 Intégration radar

Aucun changement de la signature radar — R5 reste une colonne 0-100. Pas
d'asymétrie résineux/feuillus introduite.

### 7.4 Tests

`test-indicators-deperissement.R` étendu : routage par essence, cas feuillus
RECONFORT, cas mixte, `skipped_no_method`.

---

## 8. Spécifications de données

### 8.1 `reconfort_validity_zones.geojson`

6 polygones (départements CVL : 18, 28, 36, 37, 41, 45), généré par
`data-raw/build_reconfort_validity_zones.R` depuis ADMIN-EXPRESS. CRS de
travail EPSG:2154.

### 8.2 `inst/datasources/FR.json` — entrée `reconfort_anomalies`

```json
{
  "method": "reconfort",
  "crs": "EPSG:2154",
  "validity_zones": "reconfort_validity_zones.geojson",
  "validity_species": ["CHE", "CHT", "PS"],
  "ndp_flag": "health_reconfort",
  "license": "Apache-2.0"
}
```

### 8.3 Migration SQL `0005_reconfort.sql`

Additive, rétrocompatible. Aucune nouvelle colonne nécessaire si on réutilise
`confidence_class` + `stress_index` ; index optionnel sur
`alert_type = 'reconfort_dieback'`. `alert_type` reste libre (pas de CHECK).
Si la probabilité RF brute doit être persistée : ajouter `rf_proba DOUBLE`.

---

## 9. Tests

### 9.1 Côté cœur (nemeton)

- `test-reconfort-pipeline.R` — orchestration mockée (Python mocké), skip si reticulate absent.
- `test-reconfort-postprocess.R` — raster classes + score → POINT centroïdes → INSERT alert (intégration TimescaleDB via `with_clean_db()`).
- `test-reconfort-validity.R` — AOI CVL → valide ; hors zone → warning (pas fail) ; feuillus vs résineux.
- `test-reconfort-validity-zones.R` — le GeoJSON charge, 6 polygones.
- `test-indicators-deperissement.R` — **étendu** : routage par essence.
- `test-classify-disturbance.R` — **étendu** : fusion à 3 méthodes.
- `test-db.R` — **étendu** : migration `0005_reconfort.sql`.
- `test-reconfort-integration.R` — opt-in (`NEMETON_RECONFORT_INTEGRATION=TRUE`), modèle RF réel sur AOI ≤ 1 km².

Respecter le garde-fou DB de test (`NEMETON_DB_URL_TEST`, CLAUDE.md) : tests
d'intégration *skipped* sans base jetable, jamais *failed*.

### 9.2 Côté app (nemetonshiny, pour mémoire)

- `testServer()` sur le 3ᵉ mode de `mod_monitoring`.
- Smoke shinytest2 : toggle mode RECONFORT, bannière hors-CVL affichée.

---

## 10. Hors scope de la première release (V+1 ou plus tard)

- Ré-entraînement local des modèles RF.
- Extracteur de features pixel-wise sans IOTA².
- Extension des zones de validité hors Centre-Val de Loire.
- Diagnostic pixel CRswir/CRre au clic (lot L5).

---

## 11. Références

- **Référence primaire** : F. Mouret, D. Morin, H. Martin, M. Planells,
  C. Vincent-Barbaroux (2023). *Toward an Operational Monitoring of Oak
  Dieback With Multispectral Satellite Time Series: A Case Study in
  Centre-Val De Loire Region of France.* IEEE J-STARS,
  doi:10.1109/JSTARS.2023.3332420. (Apache-2.0)
- RECONFORT — dépôt : https://framagit.org/fl.mouret/reconfort (clone vérifié `main` 25198c9).
- IOTA² — https://docs.iota2.net (CESBIO).
- spec 008 (suivi sanitaire) + amendements §12-§14 ; ADR-013 amendement A4.
- spec 021 `plan.md` (plan de développement, découpage L1→L6).
