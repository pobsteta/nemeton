# Plan de développement — RECONFORT, 3ᵉ méthode de suivi sanitaire

**Statut** : Draft — §10 tranché sur dépôt amont (clone `main` 25198c9), L0 levé, prêt pour L1
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

### 1.1 Caractérisation technique de RECONFORT (vérifiée sur le dépôt)

Confirmé sur le clone Framagit (`main` 25198c9, voir §10). Référence :
Mouret et al. 2023, *IEEE JSTARS*, doi:10.1109/JSTARS.2023.3332420.

- **Algorithme** : classification supervisée **Random Forest** (≈ 80 % de
  bonne classification sur zones d'apprentissage, ≈ −5 % sur zones non vues
  → robuste à l'échelle régionale). Implémenté via **Shark/OTB** dans la
  chaîne IOTA² (4 modèles `.txt` versionnés, §10 Q3).
- **Variables d'entrée** : séries temporelles **interpolées IOTA²** sur
  **2 années consécutives** (modèle `v3`) ou **1,5 an** janv.→mai
  (`v3_early_may`), de deux indices Sentinel-2 complémentaires calculés
  dans `iota2/external_features/custom_index.py` (§10 Q2) :
  - **CRswir** (continuum removal SWIR) — teneur en eau du couvert (le signal
    discriminant : faible contenu en eau l'été = dépérissement) ;
  - **CRre** (continuum removal red-edge) — teneur en chlorophylle.
- **Données** : Sentinel-2 niveau **2A**, chaîne de traitement **IOTA²**
  (CESBIO, Python, conda obligatoire) pour un calcul opérationnel et
  reproductible. Téléchargement S2 via `pygeodes` (GEODES/CNES).
- **Sorties** : raster de classification (1 sain / 2 dépérissant / 3 très
  dépérissant pour chêne et châtaignier ; 1 / 2 pour pin) + carte de
  probabilité, dont est dérivé un **score continu** (§10 Q6), mise à jour
  annuelle. Masque essence appliqué **en aval** (OSO feuillus par défaut).
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

Frontière R/Python : un environnement **conda/mamba dédié**
`nemeton-reconfort` (isolé de `nemeton-fordead` car deps distinctes :
IOTA² + Shark/OTB vs fordead). RECONFORT impose conda (`mamba install
iota2 -c iota2 -c iota2-deps`, python 3.9–3.11, `pygeodes` en pip) — ce
n'est **pas** un `requirements.txt` pip ; reticulate pointe sur le python
de cet env (`reticulate::use_condaenv()`). Voir §10 Q5.

**Licence amont Apache-2.0** (permissive, sans copyleft) : code et
modèles redistribuables avec attribution, **glue Python vendorisable**
dans `inst/python/`. Pas de confinement « frontière reticulate » de type
GPL-3 (contrairement à fordead) — voir §10 Q1.

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
| **RECONFORT** | **B04, B05, B06, B8A, B11, B12** | CRre (B04/B05/B06) + CRswir (B8A/B11/B12) ; **ni B02 ni B07** (§10 Q2) |
| Union des 3 | B02, B04, B05, B06, B08, B8A, B11, B12 | cache mutualisé, `skip_cached` ne re-fetche que le manquant |

**Nouvelle constante exportée** (vérifiée dans `custom_index.py`, §10 Q2) :

```r
RECONFORT_BANDS <- c("B04", "B05", "B06", "B8A", "B11", "B12")
# λ (nm) : B04=665, B05=704, B06=741, B8A=865, B11=1610, B12=2190
```

Note : RECONFORT calcule ses indices sur la **série interpolée IOTA²**, pas
sur les COG bruts ; le cache S2 ne sert qu'à alimenter IOTA² en entrée.

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
   score continu RECONFORT (1001 + (−P1 + P2 + 2·P3))/30, borné ~1..100,
     0 = no-data -> stress_index ; classe RF -> confidence_class
   INSERT alert (alert_type = 'reconfort_dieback')
        │
        ▼  PHASE 5 — persist (optionnel)
   masque catégoriel + run_meta.json (parité avec FORDEAD §14)
```

### 3.4 Fichiers cœur à créer

| Fichier | Rôle | Modèle existant |
|---------|------|-----------------|
| `R/reconfort_pipeline.R` | `run_reconfort_dieback(con, zone_id, cache_dir, dates_obs, model = NULL, ...)` orchestration end-to-end | `R/fordead_pipeline.R` |
| `R/reconfort_python.R` | `.ensure_reconfort_python()`, `.use_reconfort_env()` — env **conda** IOTA² (pas un venv pip), `use_condaenv()` | `R/fordead_python.R` |
| `R/reconfort_model.R` | `ensure_reconfort_model(version, cache_dir)` — **téléchargement à la demande** + checksum + cache, fallback chemin utilisateur (§10 Q3) | (nouveau) |
| `R/reconfort_postprocess.R` | rasters classes + score continu → alertes ; `RECONFORT_CONFIDENCE_WEIGHTS` | `R/fordead_postprocess.R` |
| `R/reconfort_validity.R` | `check_reconfort_validity(aoi, units)`, `load_reconfort_validity_zones()`, `RECONFORT_VALIDITY_DEPARTMENTS`, `RECONFORT_VALIDITY_SPECIES` | `R/fordead_validity.R` |
| `inst/python/reconfort/` | glue Python **vendorisée** (Apache-2.0 : `custom_index.py`, génération cfg, masquage/score) ; **pas** de `requirements.txt` (conda, §10 Q5) | (vendor amont) |
| `inst/extdata/reconfort_validity_zones.geojson` | région Centre-Val de Loire (6 départements : 18, 28, 36, 37, 41, 45) — **avertit, ne bloque pas** (§10 Q6) | `fordead_validity_zones.geojson` |
| `data-raw/build_reconfort_validity_zones.R` | génération du GeoJSON depuis ADMIN-EXPRESS | `data-raw/build_fordead_validity_zones.R` |

### 3.5 Garde-fous (parallèles aux G1-G5 de spec 008)

- **G1 — filtrage par confiance** : seules les classes à forte probabilité RF
  remontent par défaut ; seuil documenté depuis la matrice de confusion
  RECONFORT (calibration à transcrire dans `RECONFORT_CONFIDENCE_WEIGHTS`).
- **G2 — fusion** : `classify_disturbance()` étendu. Trois méthodes ⇒
  `disturbance_type` enrichi (cf. §3.6).
- **G3 — bannières validité** : `check_reconfort_validity()` →
  `geo_valid` (intersection Centre-Val de Loire > 50 %) + `species_valid`
  (≥ X % chêne/châtaignier/pin sylvestre selon BD Forêt v2). **La bannière
  avertit, ne bloque pas** : le code amont ne pose aucun verrou géo (son
  exemple tourne hors CVL, FD Saint-Gobain dans l'Aisne — §10 Q6). La
  séparation feuillus/résineux se fait par **masque externe** (OSO feuillus
  par défaut), appliqué en aval, **pas** par le RF lui-même.
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
> justifie côté métier. **Décision tranchée (R5 unifié, routé par essence)
> — §10 Q4.**

---

## 5. Schéma SQL, NDP, datasources

- **Migration `0005_reconfort.sql`** (additive, rétrocompatible) : aucune
  nouvelle colonne nécessaire si on réutilise `confidence_class` +
  `stress_index` (alimenté par le score continu RECONFORT, §10 Q6) ; on
  ajoute seulement, si besoin, un index sur `alert_type = 'reconfort_dieback'`.
  `alert_type` reste libre (pas de CHECK). → vérifier que `0002_fordead.sql`
  suffit ; sinon ajouter `rf_proba DOUBLE`.
- **NDP** : nouveau flag `health_reconfort` dans `detect_ndp()` (parallèle à
  `health_fordead`). Le niveau NDP et la confiance φ restent inchangés.
- **`inst/datasources/FR.json`** : entrée `reconfort_anomalies`
  (`method: "reconfort"`, `crs: "EPSG:2154"`,
  `validity_zones: "reconfort_validity_zones.geojson"`,
  `validity_species: ["CHE","CHT","PS"]`, `ndp_flag: "health_reconfort"`,
  `license: "Apache-2.0"` — code et modèles amont, §10 Q1/Q3).

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

**L0 levé** : les 6 questions §10 sont tranchées (licence Apache-2.0,
indices figés, modèles redistribuables, IOTA² obligatoire, validité). Plus
aucun prérequis bloquant amont — le développement peut démarrer sur L1.
L2 est scindé en **L2a (fetch-modèle)** et **L2b (pipeline-conda)** : le
téléchargement+checksum du modèle est indépendant et testable seul, alors
que le pipeline IOTA²/conda est la brique la plus lourde et la plus risquée.

| Lot | Contenu | Version | Bloquant |
|-----|---------|---------|----------|
| ✅ **L1** | `reconfort_validity.R` + GeoJSON 6 dép. CVL + tests (pas de Python) — **livré v0.70.0** (2026-06-11). NDP flag / datasource **reportés** : pas de précédent FORDEAD, ne s'inscrivent pas dans la sémantique `augmented` de `detect_ndp()`. | **v0.70.0** | non |
| ✅ **L2a** | `reconfort_model.R` : `ensure_reconfort_model()` + registre `RECONFORT_MODELS` (4 versions, MD5) + fallback `local_path` (pas d'IOTA²) — **livré v0.71.0** (2026-06-11). MD5/URL validés par fetch réel du modèle pin. | **v0.71.0** | non |
| **L2b** | `reconfort_python.R` (env conda IOTA²) + glue vendorisée `inst/python/reconfort/` + `reconfort_pipeline.R` (phases 0-3) + tests mockés | v0.70.0 | L2a |
| **L3** | `reconfort_postprocess.R` (score continu) → table `alert` + migration `0005` + fusion G2 3-voies | v0.71.0 | L2b |
| **L4** | R5 unifié (routage par essence) + tests indicateur étendus | v0.72.0 | L3 |
| **L5** | Persistance features (parité diagnostic pixel) + `read_reconfort_pixel_series()` | v0.73.0 | L3 |
| **L6** | App `nemetonshiny` : 3ᵉ mode, bannières, plotly, QField feuillus | release app | L4 |

Chaque lot fonctionnel suit les *Consignes de release* de CLAUDE.md
(DESCRIPTION + NEWS.md + tag + release + PLAN.md). L1 seul est doc/data →
patch ; L2a–L5 sont `feat:` → minor.

---

## 10. Faits vérifiés sur le dépôt amont (questions tranchées)

Le dépôt a été cloné et lu — `git clone https://framagit.org/fl.mouret/reconfort.git`
(`main` 25198c9). Les 6 questions ouvertes de la version précédente sont
désormais **tranchées**. Aucune n'est plus bloquante (L0 levé, §9).

1. **Q1 — Licence : Apache-2.0** (`LICENSE.md`). Permissive, sans copyleft
   → code **et** modèles redistribuables avec attribution ; glue Python
   **vendorisable** dans `inst/python/`. Pas de confinement « frontière
   reticulate » de type GPL-3 (contrairement à fordead).

2. **Q2 — CRswir / CRre** : formules de production lues dans
   `iota2/external_features/custom_index.py` (**sans offset additif** ; la
   variante CRre avec `1.1 +` y est commentée, donc non utilisée).

   ```
   CRswir = B11 / [ B8A + (1610 − 865) · (B12 − B8A) / (2190 − 865) ]
   CRre   = B5  / [ B4  + ( 704 − 665) · (B6  − B4 ) / ( 741 − 665) ]
   ```

   → `RECONFORT_BANDS <- c("B04","B05","B06","B8A","B11","B12")`
   (**ni B02 ni B07**). λ (nm) : B04=665, B05=704, B06=741, B8A=865,
   B11=1610, B12=2190. Indices calculés sur la **série interpolée IOTA²**.

3. **Q3 — Modèles RF : livrés ET redistribuables, mais inembarquables.**
   4 modèles Shark/OTB versionnés dans `models/` :

   | Modèle | Cible | Classes | Taille |
   |--------|-------|---------|--------|
   | `v3` | chêne (2 ans) | 3 | 197 Mo |
   | `v3_early_may` | chêne (1,5 an, janv.→mai) | 3 | 197 Mo |
   | `v3_chestnut` | châtaignier | 3 | 14 Mo |
   | `v3_pine` | pin sylvestre | 2 | 5,7 Mo |

   Taille totale → **pas** dans `inst/extdata/`. Stratégie =
   **téléchargement à la demande + checksum + cache**, fallback chemin
   utilisateur (`R/reconfort_model.R`, lot L2a). Le code d'entraînement
   `train_new_model/` est **hors-scope** (aligné sur le hors-scope « pas de
   fine-tuning » de spec 008).

4. **Q4 — R5 unifié** (décision interne nemeton, §4), routé par essence
   dominante. **Confirmé.** Pas de R6 séparé.

5. **Q5 — IOTA² obligatoire.** `run_map_production_reconfort.py` invoque
   `Iota2.py` en **subprocess ×2** (sampling part 1, classification part 2),
   branche les indices via `external_features`, applique le modèle via
   **OTB/Shark**. Environnement **conda** (`mamba install iota2 -c iota2
   -c iota2-deps`, python 3.9–3.11, `pygeodes` en pip) — **pas** un
   `requirements.txt` pip. Un extracteur de features autonome (appel
   pixel-wise léger) relève de la **R&D à part, non validée** → hors-scope
   v0.68.x.

6. **Q6 — Validité.** Les 6 départements CVL (18 / 28 / 36 / 37 / 41 / 45)
   sont le domaine calibré, **mais aucun verrou géo n'existe dans le code**
   (l'exemple fourni tourne sur la FD Saint-Gobain, Aisne, **hors CVL**) →
   la bannière G3 **avertit, ne bloque pas**. La séparation des essences se
   fait par **masque externe** (OSO feuillus 2021 par défaut), **pas** par le
   RF. Classes : 1 sain / 2 dépérissant / 3 très dépérissant (chêne,
   châtaignier) ; 1 / 2 (pin). Étiquette d'entraînement `dep_cor`, seuil
   %D+ via `DEPERIS_pe`. **Score continu** dérivé de la carte de probabilité
   (`mask_and_compress_rasters.py::compute_continuous_score`) :

   ```
   score = (1001 + (−P1 + P2 + 2·P3)) / 30      # borné ~1..100, 0 = no-data
   #         P1=proba sain, P2=dépérissant, P3=très dépérissant
   ```

   1 = sain, 100 = très dépérissant. **CRS EPSG:2154** (Lambert-93).

---

## 11. Références

- **Référence primaire** : F. Mouret, D. Morin, H. Martin, M. Planells,
  C. Vincent-Barbaroux, « Toward an Operational Monitoring of Oak Dieback
  With Multispectral Satellite Time Series: A Case Study in Centre-Val De
  Loire Region of France », *IEEE J-STARS*, 2023,
  doi:10.1109/JSTARS.2023.3332420.
- F. Mouret et al. — projet RECONFORT, dépôt :
  https://framagit.org/fl.mouret/reconfort (clone vérifié `main` 25198c9,
  licence Apache-2.0 ; programme SYCOMORE, Université d'Orléans / CESBIO /
  UT3 Paul Sabatier, financement Région Centre-Val de Loire)
- CESBIO / Séries Temporelles — « Une nouvelle méthode opérationnelle pour
  surveiller le dépérissement des chênes en région Centre-Val de Loire »
- GEODES-CNES — « Détection du dépérissement forestier par IA à partir de
  données Sentinel-2 »
- Revue Forestière Française — « Apport de la télédétection pour la
  cartographie du dépérissement forestier des chênes en région
  Centre-Val de Loire »
- THEIA / Data Terra — projet RECONFORT Chêne
- spec 008 (suivi sanitaire) + amendements §12-§14, ADR-013
