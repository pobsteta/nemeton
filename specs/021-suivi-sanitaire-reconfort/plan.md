# Plan de développement — RECONFORT, 3ᵉ méthode de suivi sanitaire

**Statut** : Draft (paperwork avant code)
**Date** : 2026-06-10
**Cible** : `nemeton` v0.68.0 (cœur) + `nemetonshiny` (app, release suivante)
**Étend** : spec 008 (suivi sanitaire) — ajoute une 3ᵉ méthode au triptyque
**Source amont** : RECONFORT — https://framagit.org/fl.mouret/reconfort
(F. Mouret, Université d'Orléans / CESBIO, projet RECONFORT Centre-Val de Loire)

---

## 1. Positionnement : pourquoi une 3ᵉ méthode

La stratégie hybride de spec 008 couple deux pipelines. RECONFORT en ajoute
un troisième qui comble un **trou de domaine explicitement laissé hors-scope
par spec 008 §1.4 et §4.5 : les feuillus**.

| Pipeline | Méthode | Question | Domaine de validité | Coût |
|----------|---------|----------|---------------------|------|
| **FAST** (surveillance rapide) | rolling-window NDVI/NBR | « Choc récent ? » | tout peuplement | secondes |
| **FORDEAD** (diagnostic résineux) | modèle harmonique CRSWIR | « Dépérissement progressif résineux ? » | épicéa + sapin, 5 départements Est | minutes–heures |
| **RECONFORT** (diagnostic feuillus) | Random Forest supervisé CRswir + CRre | « Dépérissement progressif feuillus ? » | chêne + châtaignier + pin sylvestre, Centre-Val de Loire | minutes |

**Complémentarité, pas redondance.** FORDEAD est non validé sur feuillus
(spec 008 §4.5 limite 5) ; RECONFORT est calibré dessus. Un projet forestier
mixte pourra router le diagnostic vers la bonne méthode selon l'essence
dominante de chaque UGF. Les trois pipelines alimentent **la même table
`alert`** avec un `alert_type` discriminant supplémentaire :
`reconfort_dieback`.

### 1.1 Caractérisation technique de RECONFORT (état des connaissances)

Synthèse des publications CESBIO / Revue Forestière Française / GEODES-CNES
(références §11). **À confirmer sur le dépôt Framagit** — voir questions
ouvertes §10.

- **Algorithme** : classification supervisée **Random Forest** (≈ 80 % de
  bonne classification sur zones d'apprentissage, ≈ −5 % sur zones non vues
  → robuste à l'échelle régionale).
- **Variables d'entrée** : séries temporelles sur **2 années consécutives**
  de deux indices Sentinel-2 complémentaires :
  - **CRswir** (continuum removal SWIR) — teneur en eau du couvert (le signal
    discriminant : faible contenu en eau l'été = dépérissement) ;
  - **CRre** (continuum removal red-edge) — teneur en chlorophylle.
- **Données** : Sentinel-2 niveau **2A**, chaîne de traitement **IOTA²**
  (CESBIO, Python) pour un calcul opérationnel et reproductible.
- **Sorties** : carte raster de classification du dépérissement (sain /
  dépérissant, possiblement par stades), mise à jour annuelle.
- **Essences ciblées** : chêne (étendu châtaignier + pin sylvestre).
- **Pré-requis supervisé** : un **modèle RF entraîné** (≠ FORDEAD qui s'auto-
  calibre par pixel). C'est la différence structurante — voir §3.4 et §10.

---

## 2. Frontière nemeton / nemetonshiny (rappel ADR-009)

Identique au pattern FORDEAD (spec 008 §3.1) :

- **`nemeton`** (cœur) : pipeline RECONFORT via reticulate, post-processing
  raster → alertes, validité géo/essences, contribution à l'indicateur de
  dépérissement, schéma SQL, datasource.
- **`nemetonshiny`** (app) : 3ᵉ mode dans `mod_monitoring`, bannières,
  leaflet, plotly, génération QField. Aucune logique métier côté app.

Frontière R/Python : un environnement virtuel reticulate **dédié**
`~/.virtualenvs/nemeton-reconfort/` (isolé de `nemeton-fordead` car deps
distinctes : scikit-learn / IOTA² vs fordead). Licence amont **contenue à
la frontière reticulate** (appel runtime, pas de linking) — voir §10 Q1.

---

## 3. Architecture du pipeline RECONFORT (cœur)

### 3.1 Réutilisation maximale de l'acquis FORDEAD/FAST

Le pipeline RECONFORT **réutilise** l'infrastructure déjà livrée par spec 008
et ses amendements ; on ne réécrit pas l'ingestion ni le cache :

| Brique réutilisée | Origine | Usage RECONFORT |
|-------------------|---------|-----------------|
| `ingest_sentinel2_timeseries()` | E6.a / spec 008 §13 | Phase 0 : garantit le cache des bandes RECONFORT (partial-coverage-aware, `skip_cached = TRUE`) |
| `.build_stac_collection_for_aoi()` | spec 008 §12 | Assemblage STAC des COG cachés |
| `.get_zone_aoi(con, zone_id)` | spec 008 §13.6 | AOI depuis `monitoring_zone` |
| Table `alert` + `0002_fordead.sql` | spec 008 §8.3 | Mêmes colonnes (`confidence_class`, `stress_index`, `validation_*`) |
| Workflow validation QField | spec 008 §6 | Schéma sanitaire feuillus (réutilise `get_health_validation_schema()` étendu) |
| `classify_disturbance()` | garde-fou G2 | Étendu à 3 méthodes (§3.5) |

### 3.2 Bandes Sentinel-2 requises

CRswir et CRre mobilisent SWIR **et** red-edge — donc une liste de bandes
différente de FORDEAD :

| Pipeline | Bandes | Note |
|----------|--------|------|
| FAST | B04, B08, B12 | NDVI/NBR |
| FORDEAD | B02, B04, B05, B8A, B11, B12 | CRSWIR + masques |
| **RECONFORT** | **B02, B04, B05, B06, B07, B8A, B11, B12** | CRre (B05/B06/B07 red-edge) + CRswir (B8A/B11/B12) + masques nuages |
| Union des 3 | B02, B04, B05, B06, B07, B08, B8A, B11, B12 | cache mutualisé, `skip_cached` ne re-fetche que le manquant |

**Nouvelle constante exportée** `RECONFORT_BANDS` (parallèle à `FORDEAD_BANDS`).
La liste exacte des red-edge dépend de la définition CRre du dépôt → §10 Q2.

### 3.3 Flux du pipeline

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
        ▼  PHASE 2 — features (Python via reticulate)
   calcul CRswir + CRre, masquage nuages/ombres (SCL),
   empilement 2 ans → matrice de features par pixel (chaîne IOTA²)
        │
        ▼  PHASE 3 — predict (Python via reticulate)
   modèle RF pré-entraîné -> classe + probabilité par pixel
        │
        ▼  PHASE 4 — postprocess (R)
   raster classes -> patches 8-connexité -> centroïdes POINT
   probabilité RF -> confidence_class / stress_index
   INSERT alert (alert_type = 'reconfort_dieback')
        │
        ▼  PHASE 5 — persist (optionnel)
   masque catégoriel + run_meta.json (parité avec FORDEAD §14)
```

### 3.4 Fichiers cœur à créer

| Fichier | Rôle | Modèle existant |
|---------|------|-----------------|
| `R/reconfort_pipeline.R` | `run_reconfort_dieback(con, zone_id, cache_dir, dates_obs, model = NULL, ...)` orchestration end-to-end | `R/fordead_pipeline.R` |
| `R/reconfort_python.R` | `.ensure_reconfort_python()`, `.use_reconfort_env()` — venv reticulate, deps figées | `R/fordead_python.R` |
| `R/reconfort_postprocess.R` | rasters classes → alertes ; `RECONFORT_CONFIDENCE_WEIGHTS` | `R/fordead_postprocess.R` |
| `R/reconfort_validity.R` | `check_reconfort_validity(aoi, units)`, `load_reconfort_validity_zones()`, `RECONFORT_VALIDITY_DEPARTMENTS`, `RECONFORT_VALIDITY_SPECIES` | `R/fordead_validity.R` |
| `inst/python/reconfort_requirements.txt` | deps Python figées (scikit-learn, rasterio, numpy, etc. ± IOTA²) | `inst/python/requirements.txt` |
| `inst/extdata/reconfort_validity_zones.geojson` | région Centre-Val de Loire (6 départements : 18, 28, 36, 37, 41, 45) | `fordead_validity_zones.geojson` |
| `data-raw/build_reconfort_validity_zones.R` | génération du GeoJSON depuis ADMIN-EXPRESS | `data-raw/build_fordead_validity_zones.R` |
| `inst/extdata/reconfort.model/` | **modèle RF pré-entraîné** (si redistribuable — §10 Q1/Q3) | (nouveau) |

### 3.5 Garde-fous (parallèles aux G1-G5 de spec 008)

- **G1 — filtrage par confiance** : seules les classes à forte probabilité RF
  remontent par défaut ; seuil documenté depuis la matrice de confusion
  RECONFORT (calibration à transcrire dans `RECONFORT_CONFIDENCE_WEIGHTS`).
- **G2 — fusion** : `classify_disturbance()` étendu. Trois méthodes ⇒
  `disturbance_type` enrichi (cf. §3.6).
- **G3 — bannières validité** : `check_reconfort_validity()` →
  `geo_valid` (intersection Centre-Val de Loire > 50 %) + `species_valid`
  (≥ X % chêne/châtaignier/pin sylvestre selon BD Forêt v2).
- **G4 — validation terrain** : workflow QField réutilisé, schéma de saisie
  feuillus (stades de dépérissement chêne adaptés du protocole DSF feuillus).
- **G5 — contribution indicateur** : pondération par la confiance RF (§4).

### 3.6 Fusion à 3 méthodes (G2 étendu)

`classify_disturbance()` doit gérer la co-occurrence des trois `alert_type` :

| Signaux présents (même pixel/plot, ±30 j) | `disturbance_type` |
|-------------------------------------------|--------------------|
| FAST seul | `recent_event` (coupe/chablis/incendie) |
| FORDEAD ou RECONFORT seul | `progressive` (dépérissement) |
| (FORDEAD ∣ RECONFORT) **+** FAST | `mechanical` (perturbation mécanique recouvrant une anomalie) |
| FORDEAD **+** RECONFORT (zone mixte limitrophe) | `progressive` + drapeau `method_overlap` (signaler, ne pas double-compter) |

Calculé à la volée (non persisté), comme aujourd'hui.

---

## 4. Indicateur de dépérissement — décision R5 unifié vs nouveau R6

**Recommandation : unifier sous R5, routé par essence dominante** plutôt que
créer un R6.

Justification :
- CLAUDE.md fixe la famille R à R1–R5, R5 = « dépérissement ». Ajouter R6
  ferait passer la famille à 6 indicateurs et changerait la table de
  référence (12 familles / 32 indicateurs max).
- Sémantiquement, R5 = « dépérissement détecté par télédétection », la méthode
  (FORDEAD/RECONFORT) est un **détail d'implémentation** routé par l'essence :
  - UGF dominée résineux (EPC/SAP) + zone FORDEAD valide → R5 via FORDEAD ;
  - UGF dominée feuillus (chêne/châtaignier) + zone RECONFORT valide → R5 via
    RECONFORT ;
  - sinon → R5 = NA (statut `skipped_no_method`).

Implémentation : `indicateur_r5_deperissement()` (déjà existant,
`R/indicators-deperissement.R`) gagne un paramètre `reconfort_results = NULL`
et une logique de **routage par essence** par UGF. Le statut `r5_status`
s'enrichit de `"calculated_reconfort"` / `"skipped_no_feuillus"`. Aucun
changement de la signature radar — R5 reste une colonne 0-100.

> Alternative écartée (R6 séparé) : documentée pour traçabilité, mais
> introduit une asymétrie résineux/feuillus dans le radar que rien ne
> justifie côté métier. **Décision à valider — §10 Q4.**

---

## 5. Schéma SQL, NDP, datasources

- **Migration `0005_reconfort.sql`** (additive, rétrocompatible) : aucune
  nouvelle colonne nécessaire si on réutilise `confidence_class` +
  `stress_index` ; on ajoute seulement, si besoin, un index sur
  `alert_type = 'reconfort_dieback'`. `alert_type` reste libre (pas de CHECK).
  → vérifier que `0002_fordead.sql` suffit ; sinon ajouter `rf_proba DOUBLE`.
- **NDP** : nouveau flag `health_reconfort` dans `detect_ndp()` (parallèle à
  `health_fordead`). Le niveau NDP et la confiance φ restent inchangés.
- **`inst/datasources/FR.json`** : entrée `reconfort_anomalies`
  (`method: "reconfort"`, `validity_zones: "reconfort_validity_zones.geojson"`,
  `validity_species: ["CHE","CHT","PS"]`, `ndp_flag: "health_reconfort"`,
  licence amont à renseigner après §10 Q1).

---

## 6. Tests (cœur)

Miroir de la suite FORDEAD :

- `test-reconfort-pipeline.R` — orchestration mockée (Python mocké), skip si
  reticulate absent.
- `test-reconfort-postprocess.R` — raster classes → POINT centroïdes →
  INSERT alert (intégration TimescaleDB via `with_clean_db()`).
- `test-reconfort-validity.R` — AOI Centre-Val de Loire → valide ; hors zone →
  warning ; feuillus vs résineux.
- `test-reconfort-validity-zones.R` — le GeoJSON charge, 6 polygones.
- `test-indicators-deperissement.R` — **étendu** : routage par essence,
  cas feuillus RECONFORT, cas mixte, `skipped_no_method`.
- `test-classify-disturbance.R` — **étendu** : fusion à 3 méthodes.
- `test-db.R` — **étendu** : migration `0005_reconfort.sql`.
- `test-reconfort-integration.R` — opt-in
  (`NEMETON_RECONFORT_INTEGRATION=TRUE`), appelle réellement le modèle RF sur
  une AOI de test ≤ 1 km².

Respecter le garde-fou DB de test (`NEMETON_DB_URL_TEST`, CLAUDE.md) : tests
d'intégration *skipped* sans base jetable, jamais *failed*.

---

## 7. Côté app `nemetonshiny` (release séparée, pour mémoire)

- `mod_monitoring` : 3ᵉ mode (toggle) « Diagnostic feuillus (RECONFORT) ».
- Bannières géo (Centre-Val de Loire) + essences (feuillus) via
  `check_reconfort_validity()`.
- Leaflet : alertes `reconfort_dieback`, popup probabilité RF.
- Plotly : séries CRswir + CRre au clic (parité avec le diagnostic pixel
  FORDEAD spec 008 §14 — nécessite la persistance des features, phase 5).
- Clés i18n FR/EN : `monitoring_mode_reconfort`,
  `monitoring_reconfort_phase_*`, `monitoring_reconfort_outside_validity`,
  `monitoring_reconfort_crswir`, `monitoring_reconfort_crre`.
- `Imports: nemeton (>= 0.68.0)` + `Remotes: pobsteta/nemeton@v0.68.0`.

---

## 8. ADR

Amender **ADR-013** (méthode de suivi sanitaire) plutôt que créer un ADR-014 :
ADR-013 devient « suivi sanitaire **multi-méthodes** : FAST (rapide) +
FORDEAD (résineux) + RECONFORT (feuillus), routage par essence, fusion G2 à
3 voies ». Amendement A4. CLAUDE.md (table ADR + §4 contexte_sante +
table familles R5) à mettre à jour à la livraison.

---

## 9. Découpage en livraisons (séquencé)

| Lot | Contenu | Version | Bloquant |
|-----|---------|---------|----------|
| **L0** | Spec validée + questions §10 tranchées (licence, modèle, indices) | — | **prérequis** |
| **L1** | `reconfort_validity.R` + GeoJSON Centre-Val de Loire + datasource + NDP flag (pas de Python) | v0.68.0 | non |
| **L2** | `reconfort_python.R` + venv + `reconfort_pipeline.R` (phases 0-3) + tests mockés | v0.69.0 | L0 Q1/Q3 |
| **L3** | `reconfort_postprocess.R` → table `alert` + migration `0005` + fusion G2 3-voies | v0.70.0 | L2 |
| **L4** | R5 unifié (routage par essence) + tests indicateur étendus | v0.71.0 | L3 |
| **L5** | Persistance features (parité diagnostic pixel) + `read_reconfort_pixel_series()` | v0.72.0 | L3 |
| **L6** | App `nemetonshiny` : 3ᵉ mode, bannières, plotly, QField feuillus | release app | L4 |

Chaque lot fonctionnel suit les *Consignes de release* de CLAUDE.md
(DESCRIPTION + NEWS.md + tag + release + PLAN.md). L1 seul est doc/data →
patch ; L2-L5 sont `feat:` → minor.

---

## 10. Questions ouvertes (à trancher avant L2 — bloquantes)

Le dépôt Framagit a renvoyé 403 en accès anonyme ; ces points doivent être
confirmés depuis le code source / le README réel ou auprès de F. Mouret.

1. **Q1 — Licence amont de RECONFORT.** Déterminante pour la stratégie
   « contenue à la frontière reticulate » (comme GPL-3 de fordead) et la
   redistribution. À lire dans `LICENSE` du dépôt. *Sans réponse, ne pas
   embarquer de code/modèle.*
2. **Q2 — Définition exacte de CRswir / CRre** (bandes red-edge précises,
   formules continuum-removal) → fige `RECONFORT_BANDS`.
3. **Q3 — Modèle RF : pré-entraîné redistribuable ?** Le cœur du sujet
   supervisé. Trois cas :
   (a) modèle CVL livré et redistribuable → on l'embarque (`inst/extdata/`) ;
   (b) modèle non redistribuable → l'utilisateur fournit le `.model` ;
   (c) pas de modèle, seulement le code d'entraînement → scope bien plus large
   (hors v0.68.x, aligné sur le hors-scope « pas de fine-tuning » de spec 008).
4. **Q4 — R5 unifié vs R6 séparé** (§4). Recommandation : R5 unifié.
5. **Q5 — Dépendance IOTA²** : requise (lourde, orientée chaîne) ou un
   extracteur de features autonome suffit-il ? Impacte la taille du venv et
   la faisabilité d'un appel pixel-wise léger.
6. **Q6 — Zones/essences de validité** : confirmer les 6 départements CVL et
   les codes essences (chêne CHE, châtaignier CHT, pin sylvestre PS) vs la
   nomenclature BD Forêt v2 utilisée dans le projet.

---

## 11. Références

- F. Mouret et al. — projet RECONFORT, dépôt :
  https://framagit.org/fl.mouret/reconfort
- CESBIO / Séries Temporelles — « Une nouvelle méthode opérationnelle pour
  surveiller le dépérissement des chênes en région Centre-Val de Loire »
- GEODES-CNES — « Détection du dépérissement forestier par IA à partir de
  données Sentinel-2 »
- Revue Forestière Française — « Apport de la télédétection pour la
  cartographie du dépérissement forestier des chênes en région
  Centre-Val de Loire »
- THEIA / Data Terra — projet RECONFORT Chêne
- spec 008 (suivi sanitaire) + amendements §12-§14, ADR-013
