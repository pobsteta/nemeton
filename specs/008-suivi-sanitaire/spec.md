# Spécification Fonctionnelle : Suivi sanitaire des peuplements forestiers

**Version** : 0.1.0 (draft validé)
**Date**    : 2026-04-26
**Statut**  : Draft — décisions validées, prêt pour `plan.md`
**Auteur**  : Pascal Obstétar (via Claude)
**Cible**   : `nemeton` v0.21.0 + `nemetonshiny` v0.21.0
**Remplace** : reframing du chantier E6 (ex « monitoring forestier continu », spec 007). E6.a (squelette TimescaleDB + ingestion S2 + rolling-window NDVI/NBR) n'est pas du throwaway — il devient la couche « surveillance rapide » de la stratégie hybride définie ici.

---

## 1. Résumé Exécutif

### 1.1 Vision

Permettre à un forestier d'instruire à grande échelle l'état sanitaire de ses peuplements résineux à partir des images Sentinel-2, en intégrant la méthode **FORDEAD** (INRAE/CIRAD/ONF) — état de l'art francophone pour la détection des dépérissements scolyte/sécheresse — comme **méthode officielle** du suivi, couplée à **un détecteur de changement brutal** (rolling-window NDVI/NBR) pour distinguer dépérissement progressif et perturbation mécanique (coupe, chablis, casse de cime).

### 1.2 Principe — Stratégie hybride

| Pipeline | Méthode | Question répondue | Coût | Quand l'utiliser |
|----------|---------|-------------------|------|------------------|
| **Surveillance rapide** | rolling-window NDVI/NBR (E6.a, déjà livré) | « Y a-t-il eu un choc récent ? » | secondes | détection coupes / chablis / incendies |
| **Diagnostic sanitaire** | FORDEAD (CRSWIR + modèle harmonique) | « Mes peuplements dépérissent-ils ? » | minutes-heures | suivi scolyte / sécheresse / dépérissement progressif |
| **Fusion** | join SQL des deux pipelines | « Cette anomalie est-elle un dépérissement ou une perturbation ? » | ms | discriminer le type de cause |

Les deux pipelines alimentent **la même table `alert`** (TimescaleDB) avec un champ `alert_type` discriminant (`ndvi_drop`, `nbr_drop`, `fordead_dieback`). Le projet `nemeton` n'embarque pas FORDEAD : appel runtime via **reticulate** (Python isolé du package R, licence GPL-3 contenue à la frontière).

### 1.3 Objectifs métier

| Objectif | Métrique de succès |
|----------|-------------------|
| Détecter un dépérissement résineux à grande échelle (épicéa/sapin) | `dieback_detection()` produit un raster `state.tif` lisible et alimente la table `alert` |
| Distinguer dépérissement vs perturbation mécanique | Un événement classé FORDEAD ET rolling-window est marqué `mechanical_disturbance` ; FORDEAD seul → `progressive_dieback` |
| Garantir la fiabilité des alertes affichées | Par défaut, seules les classes 3-forte et 4-sol nu remontent dans l'UI (taux de bonne détection > 70% selon ONF/DSF 2024) |
| Documenter les limites de validité | Bannières UI géographique + essences ; spec 008 §5 listant explicitement les domaines hors-validation |
| Permettre la validation terrain par un agent | Workflow QField (réutilise E5.b) avec schéma de saisie aligné sur le protocole DSF (stade dépérissement, cause) |
| Alimenter la famille R d'indicateurs | Nouvel **R5** (indicateur de dépérissement) intégré au radar, pondéré par les taux de détection ONF |

### 1.4 Hors-scope

- Détection sur essences feuillues (FORDEAD non validé sur feuillus)
- Détection sur autres résineux que épicéa commun et sapin pectiné — un avertissement bloque le calcul, l'utilisateur peut forcer mais à ses risques
- Ré-entraînement local des modèles (on consomme FORDEAD tel quel, pas de fine-tuning)
- Cron worker automatique (idem E6.a : déclenchement à la demande)
- Prévisions quantitatives de volumes impactés (le rapport ONF/DSF dit explicitement que FORDEAD n'est pas calibré pour ça)

---

## 2. Scope

### 2.1 Inclus dans nemeton v0.21.0 (cœur)

- **Pipeline FORDEAD côté cœur** :
  - `R/fordead_pipeline.R` : `run_fordead_dieback(zone_aoi, dates_training, dates_monitoring, output_dir, vegetation_index = "CRSWIR", threshold_anomaly = 0.16, ...)` — orchestration end-to-end via reticulate
  - `R/fordead_python.R` : helpers reticulate (`.ensure_fordead_python()`, `.use_fordead_env()`)
  - `R/fordead_postprocess.R` : conversion des rasters FORDEAD vers le schéma `alert` (clusters → POINT centroïdes + classe + stress_index)
- **Indicateur R5 dépérissement** : `indicateur_r5_deperissement(units, fordead_results, weights = FORDEAD_CONFIDENCE_WEIGHTS, min_resineux = 0.3)`
- **Constantes calibrées** : `FORDEAD_CONFIDENCE_WEIGHTS` documenté (rapport ONF/DSF 2024 cité)
- **Données embarquées** :
  - `inst/extdata/fordead_validity_zones.geojson` : Vosges (88), Jura (39), Ain (01), Savoie (73), Haute-Savoie (74) — départements où la calibration FORDEAD est validée
  - `inst/datasources/FR.json` : nouvelle source `fordead_anomalies`
- **NDP augmenté** : flag `health_fordead` ajouté à `detect_ndp()`
- **Schéma SQL étendu** :
  - Table `alert` enrichie : colonnes `confidence_class` (1-faible / 2-moyenne / 3-forte / 4-sol-nu / NA), `stress_index`, `validation_status` (`pending`, `confirmed`, `false_positive`, `closed`), `validation_cause` (libre, ex. `coupe_rase`, `chablis`, `casse_cime`, `phenologie`, `autre`), `validated_by`, `validated_at`
  - Migration `0002_fordead.sql` rétrocompatible
- **Schéma de saisie QField** étendu : `R/field_schema.R` ajout `get_health_validation_schema()` (champs : `stade_deperissement`, `cause`, `taux_couvert`, `essence_dominante`, photo)
- **Fonction de génération de placettes de vérification** : `generate_health_validation_plots(alerts_sf, n = 30)` retourne une `sf` POINT prête pour `create_qfield_project()`

### 2.2 Inclus dans nemetonshiny v0.21.0 (app)

- **Renommage de l'onglet** : « Suivi » → « Suivi sanitaire » (i18n)
- **`mod_monitoring`** acquiert deux modes (toggle UI) :
  - **Mode 1 — Surveillance rapide** : pipeline E6.a (NDVI/NBR rolling) — déjà fonctionnel
  - **Mode 2 — Diagnostic sanitaire** : pipeline FORDEAD via `nemeton::run_fordead_dieback()` (async, ExtendedTask + future_promise)
- **Bannières d'avertissement obligatoires** :
  - Géographique : si la zone d'étude n'intersecte pas `fordead_validity_zones.geojson` à >50% → bannière `border-warning`
  - Essences : si BD Forêt v2 indique <70% épicéa+sapin pectiné → bannière `border-warning`
- **Filtrage par défaut** : seules classes 3-forte + 4-sol-nu affichées sur leaflet et utilisées pour R5. Toggle « inclure faible/moyenne » ajoute une bannière `border-warning` "taux de faux positifs jusqu'à 50%".
- **Time series plotly** : NDVI/NBR (mode 1) ou CRSWIR + courbe modèle harmonique + seuil (mode 2)
- **Carte leaflet alertes** : POINT colorés par classe d'anomalie, popup avec stress_index + boutons « Valider » / « Faux positif »
- **Workflow validation terrain** :
  - Bouton « Générer placettes QField pour vérification » → produit un `.qgz` avec les centroïdes des alertes pendantes + schéma DSF
  - Réingestion via `mod_field_ingest` met à jour `validation_status` dans la table `alert`
- **Persistance config projet** : seuils, mode actif, validity zones intersection — dans `metadata.json`

### 2.3 Hors-scope v0.21.0 (reportés)

- Cron worker / scheduling automatique (E6.f, après v0.21.0)
- Notifications externes (blastula email, webhook Mattermost)
- Tableau de bord sysadmin (queue d'ingestion, latence STAC)
- Interface de re-calibration des seuils par l'utilisateur (figés sur les valeurs ONF/DSF 2024 dans cette version)
- FORDEAD sur feuillus / autres résineux (en attente d'études de transposition citées dans le rapport ONF, page 9)

---

## 3. Architecture

### 3.1 Frontière nemeton / nemetonshiny

Conformément à l'ADR-009 (séparation cœur / app) :
- **`nemeton`** porte la logique métier : pipeline FORDEAD, indicateur R5, schéma SQL, post-processing rasters → alertes, schéma QField sanitaire
- **`nemetonshiny`** est de la présentation : UI mode toggle, bannières, plotly, leaflet, génération QField, async wrapper

Aucune logique métier n'entre dans `mod_monitoring.R`. Le module appelle exclusivement les fonctions exportées par `nemeton`.

### 3.2 Frontière R / Python — Couche reticulate

- Python isolé dans un environnement virtuel **reticulate-managed** : `~/.virtualenvs/nemeton-fordead/` (création au premier appel via `reticulate::virtualenv_create()`).
- Dépendances Python figées dans `inst/python/requirements.txt` : `fordead @ git+https://gitlab.com/fordead/fordead_package@v1.11.4` (pas sur PyPI, cf. fix v0.22.2 ; downgrade 2.1.1 → 1.11.4 en v0.22.5 car fordead 2.x a refactoré l'API du pipeline), `xarray`, `dask[complete]`, `rasterio`, `eodag`, `numpy`, `pandas`, `geopandas`, `shapely`.
- Helpers `.ensure_fordead_python()` et `.use_fordead_env()` dans `R/fordead_python.R` :
  - vérifient la présence de Python ≥ 3.10
  - créent l'env virtuel si absent
  - installent fordead et ses dépendances
  - retournent un module `fordead_module` réutilisable
- `nemeton::run_fordead_dieback()` orchestre les 5 étapes FORDEAD (compute_masked_vegetationindex → train_model → dieback_detection → forest_mask → export_results) en R, mais chaque étape appelle le Python correspondant.
- **Licence** : fordead est GPL-3. L'appel via reticulate est un appel runtime (RPC), pas un linking statique. nemeton reste sous MIT, fordead est mentionné comme dépendance optionnelle dans `Suggests`. Avis juridique formalisé dans `inst/NOTICE`.

### 3.3 Pipeline FORDEAD complet (par AOI)

```
   AOI (sf POLYGON, EPSG:2154)
       │
       ▼
   STAC search Sentinel-2 (réutilise stac_search_s2 de E6.a)
       │
       ▼
   ┌─────────────────────────────────────┐
   │ Phase Python (via reticulate)       │
   │  ├─ compute_masked_vegetationindex  │
   │  │    (CRSWIR par défaut, masque    │
   │  │     SCL : nuages, ombres, sol)   │
   │  ├─ train_model                     │
   │  │    (harmonique, 2 ans, 2016-2017 │
   │  │     par défaut, configurable)    │
   │  ├─ forest_mask (BD Forêt v2 IGN)   │
   │  ├─ dieback_detection               │
   │  │    (3 anomalies consécutives,    │
   │  │     stress_index pondéré)        │
   │  └─ export_results                  │
   │       (rasters first_dieback_date,  │
   │        state, stress_index, classe) │
   └─────────────────────────────────────┘
       │
       ▼
   ┌─────────────────────────────────────┐
   │ Phase R (post-processing)           │
   │  ├─ rasters → polygons (terra)      │
   │  ├─ clustering 8-connexité          │
   │  ├─ centroïdes POINT                │
   │  ├─ enrichissement attributs        │
   │  │    (classe, stress_index, dates) │
   │  └─ INSERT ON CONFLICT DO NOTHING   │
   │     dans alert (alert_type =        │
   │     'fordead_dieback')              │
   └─────────────────────────────────────┘
       │
       ▼
   Alertes consultables côté UI
```

### 3.4 Logique de fusion (G2)

Lors d'une requête `list_alerts(con, zone_id, period)` :
- Pour chaque alerte FORDEAD `(plot_id, trigger_date)`, on cherche dans `alert` une alerte rolling-window `(plot_id, trigger_date ± 30 jours)`
- Si trouvée → `disturbance_type = 'mechanical'` (probable coupe/chablis/casse)
- Sinon → `disturbance_type = 'progressive'` (probable scolyte/sécheresse)
- Si rolling-window seul, FORDEAD muet → `disturbance_type = 'recent_event'` (incendie/tempête/coupe sans dépérissement antérieur)

`disturbance_type` est calculé à la volée (vue SQL ou helper R), pas persisté.

---

## 4. Méthode FORDEAD — paramètres et calibration

### 4.1 Indice de végétation

**CRSWIR** par défaut : `B11 / (B8A · B12)`. Sensible au contenu en eau du couvert. Augmente quand l'arbre se dessèche (signal positif → stress).

Alternative configurable : NDVI, NDWI (pour le diagnostic d'autres causes que le scolyte). NDVI est documenté comme moins précoce dans le rapport.

### 4.2 Période d'entraînement

**2 ans** par défaut (2016-2017 dans la calibration ONF/DSF), supposés sains pour le peuplement. Configurable via `dates_training = c(start, end)`. Le rapport ONF a utilisé la même période pour les 4 massifs (Vosges, Jura, Massif Central, Alpes Nord) sans dégradation observée.

### 4.3 Seuils

- **`threshold_anomaly`** : 0.16 (par défaut, espace CRSWIR). Modulable mais le rapport ONF montre que la modification *« n'a pas d'effet réel sur les performances »* — laisser cette valeur fixe à v0.21.0.
- **`nb_consecutive_anomalies`** : 3 (anti-bruit, requis pour confirmer un dépérissement)

### 4.4 Classes d'anomalie et calibration de la confiance

| Classe | Signal terrain (rapport ONF/DSF 2024) | Coefficient de confiance |
|--------|---------------------------------------|--------------------------|
| 0-Hors anomalie | 73% sain | 0.0 (pas une alerte) |
| 1-Faible | 54% sain (FAUX POSITIFS DOMINANTS) | 0.10 |
| 2-Moyenne | 37% sain | 0.30 |
| 3-Forte | 18% sain (>80% bonne détection) | **0.82** |
| 4-Sol nu | 13% sain (70% coupes rases + 13% dépérissements) | 0.70 |

Les coefficients vivent dans `R/fordead_postprocess.R` :

```r
FORDEAD_CONFIDENCE_WEIGHTS <- c(
  "1-faible"  = 0.10,
  "2-moyenne" = 0.30,
  "3-forte"   = 0.82,
  "4-sol-nu"  = 0.70
)
```

Référence en commentaire : *Bernard C, Doridant JB (2024) — Méthode FORDEAD : analyse de la validité des détections d'anomalies de végétation par contrôle terrain. ONF/DSF, mai 2024.*

### 4.5 Limites documentées

Synthétisées du rapport ONF/DSF (à reproduire dans la documentation utilisateur) :

1. **Faible fiabilité des classes 1-2** : 50% et 1/3 de faux positifs respectivement. Inutilisables seules.
2. **Détection précoce médiocre** : ~60% des stades précoces (scolyte vert) non détectés par FORDEAD. Performance comparable à Bárta 2021 et Deepak 2024 selon les auteurs.
3. **Confusion dépérissement / perturbation mécanique** : 25% des trouées-chablis classés en anomalie, 38% des interventions sylvicoles, 41% des casses de cime. → motivation forte pour le pipeline de fusion (G2).
4. **Validité géographique restreinte** : Vosges, Jura, Ain, Savoie, Haute-Savoie validés. Massif Central déjà dégradé. Pyrénées et Sud Alpes en cours d'étude. Hors zone → résultats à interpréter avec circonspection.
5. **Validité essences restreinte** : épicéa commun + sapin pectiné. Autres résineux non vérifiés. Feuillus exclus.
6. **Sensibilité au taux de couvert** : peuplements ouverts → plus d'erreurs.
7. **Sur-détection en peuplement non-conforme au masque** : faible capital, mélange feuillus → favorise classes 1-2.
8. **Le seuillage harmonique n'est peut-être pas la méthode la plus adaptée** (citation directe du rapport ONF) — pistes alternatives à explorer en V+1 (méthodes ML).

---

## 5. Garde-fous applicatifs

Traduction directe des findings du rapport ONF/DSF en garde-fous code/UI.

### G1 — Filtrage par défaut classe 3+4

**Implémentation** :
- Côté cœur : `list_alerts(con, zone_id, classes = c("3-forte", "4-sol-nu"))` par défaut
- Côté UI : checkbox « Inclure anomalies faibles/moyennes » désactivé par défaut, génère bannière `border-warning` quand activé
- Indicateur R5 : pondération via `FORDEAD_CONFIDENCE_WEIGHTS`, donc poids des classes 1-2 reste très faible même si l'utilisateur les inclut

### G2 — Fusion rolling-window × FORDEAD

**Implémentation** : helper R `classify_disturbance(alerts_df)` qui ajoute la colonne `disturbance_type ∈ {progressive, mechanical, recent_event}`. Pas de persistance — calculé à chaque requête.

### G3 — Bannières géographiques + essences

**Implémentation** :
- `R/fordead_validity.R::check_fordead_validity(aoi, units)` retourne une liste avec deux flags :
  - `geo_valid` : `aoi` intersecte-t-elle `fordead_validity_zones.geojson` à >50% ?
  - `species_valid` : `units` contient-elle ≥70% épicéa + sapin pectiné selon BD Forêt v2 ?
- Côté UI : `mod_monitoring` lit ces flags et affiche les bannières correspondantes au-dessus de la carte
- Si l'utilisateur lance malgré une zone hors-validation → demande de confirmation modale

### G4 — Workflow de validation terrain

Voir §6.

### G5 — Indicateur R5 pondéré par confiance

Voir §7.

---

## 6. Workflow de validation terrain (G4)

Réutilise massivement le code E5.b (`mod_field_ingest`, `R/qgis_export.R`, `R/qgis_import.R`).

### 6.1 États d'une alerte

```
                         ┌──────────────┐
                         │  pending     │  ← FORDEAD vient de la créer
                         └──────┬───────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
       ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
       │  confirmed   │ │false_positive│ │  closed      │
       │ (sanitaire   │ │ (cause notée)│ │ (traité,     │
       │  vérifié)    │ │              │ │  ex. coupé)  │
       └──────────────┘ └──────────────┘ └──────────────┘
```

### 6.2 Étapes côté utilisateur

1. FORDEAD tourne → N alertes en `pending` dans la zone.
2. L'utilisateur clique « Générer placettes QField » dans `mod_monitoring`.
   → `nemeton::generate_health_validation_plots(alerts_sf, n = 30)` retourne une `sf` POINT, échantillonnage GRTS sur les centroïdes des clusters d'alertes.
   → `nemeton::create_qfield_project(...)` produit un `.qgz` avec :
   - couche `placettes` (les centroïdes)
   - schéma de saisie sanitaire (`get_health_validation_schema()`) : `stade_deperissement` (Sain / Sain_scolyte_vert_indif / Scolyte_vert / Scolyte_rouge / Scolyte_gris / Scolyte_rouge_gris_indif / Coupe_rase), `cause` (Scolyte / Sécheresse / Casse_cime / Coupe / Chablis / Phénologie / Autre), `taux_couvert` (%), `essence_dominante` (liste résineux), `photo` (External Resource)
3. L'agent va sur le terrain, saisit, télécharge le GPKG.
4. Réingestion via `mod_field_ingest` (mode « Validation sanitaire » du tab Terrain).
   → `nemeton::ingest_health_validation(con, gpkg_path, zone_id)` :
   - lit le GPKG
   - pour chaque placette, trouve l'alerte la plus proche (distance < 50m)
   - met à jour `alert.validation_status`, `validation_cause`, `validated_by` (auth user), `validated_at`
   - retourne un rapport (X alertes confirmées, Y faux positifs, Z sans correspondance terrain)

### 6.3 Schéma de saisie aligné DSF

Reproduit la nomenclature de l'Annexe 1 du rapport ONF/DSF 2024 (codes Sain, Scolyte_vert, Scolyte_rouge, Scolyte_gris, Sain_scolyte_vert_indif, Scolyte_rouge_gris_indif, Coupe_rase) — interopérabilité avec les bases de données DSF existantes.

---

## 7. Indicateur R5 dépérissement

### 7.1 Définition

**R5 ∈ [0, 1]** par UGF. Score plus élevé = plus de dépérissement.

```
R5(UGF) = (
   surface(classe_3-forte, UGF)    × 0.82
 + surface(classe_4-sol-nu, UGF)   × 0.70
 + surface(classe_2-moyenne, UGF)  × 0.30   # désactivé par défaut, optionnel
 + surface(classe_1-faible, UGF)   × 0.10   # désactivé par défaut, optionnel
) / surface_totale(UGF)
```

Plafonné à 1.0 (cas extrême : 100% sol-nu = R5 = 0.70 par défaut, pas 1.0 — c'est volontaire, on ne peut pas dépasser le coefficient de la meilleure classe).

### 7.2 Conditions d'application

- L'UGF doit avoir **≥30% de résineux** selon BD Forêt v2 (paramètre `min_resineux = 0.3`). Sinon R5 = NA.
- L'UGF doit intersecter au moins une `fordead_validity_zone` à >50%. Sinon R5 = NA + flag projet `r5_extrapolation = TRUE` (l'utilisateur a forcé) ou R5 omis (par défaut).
- La zone doit avoir été couverte par un run FORDEAD (sinon R5 = NA, la famille R reste utilisable sur R1-R4).

### 7.3 Intégration radar

R5 entre dans la famille **R (Risques)** au même titre que R1-R4. Le radar 12-familles devient « augmenté » via le flag `health_fordead` quand FORDEAD a tourné, et la famille R passe de moyenne(R1..R4) à moyenne(R1..R5).

### 7.4 Tests

- `test-indicators-deperissement.R` : 15-20 assertions (cas vide, mono-classe, multi-classes, < 30% résineux, hors zone validité, pondération correcte)
- Fixture : sf 5 UGF avec attributs `surf_classe_3_forte`, `surf_classe_4_sol_nu`, etc.

---

## 8. Spécifications de données

### 8.1 `fordead_validity_zones.geojson`

- Construit à partir des contours départementaux IGN ADMIN-EXPRESS via `geo.api.gouv.fr`
- Départements inclus : 88 (Vosges), 39 (Jura), 01 (Ain), 73 (Savoie), 74 (Haute-Savoie)
- CRS : EPSG:4326 (compatibilité web)
- Format : GeoJSON simplifié (tolérance 100m, suffisant pour tests d'intersection >50%)
- Métadonnées : nom du département, code INSEE, source (rapport ONF/DSF 2024 §2.2)

### 8.2 `inst/datasources/FR.json` — entrée `fordead_anomalies`

```json
{
  "id": "fordead_anomalies",
  "type": "derived_raster",
  "format": "COG",
  "crs": "EPSG:2154",
  "bands": ["state", "first_dieback_date", "stress_index", "anomaly_class"],
  "method": "fordead",
  "method_version": "2.1.x",
  "calibration_reference": "ONF/DSF Bernard & Doridant 2024",
  "validity_zones": "fordead_validity_zones.geojson",
  "validity_species": ["EPC", "SAP"],
  "license": {
    "method": "GPL-3.0 (fordead)",
    "data": "Sentinel-2 ESA Copernicus + IGN BD Forêt v2 (Etalab 2.0)"
  },
  "ndp_flag": "health_fordead"
}
```

### 8.3 Migration SQL `0002_fordead.sql`

```sql
-- Migration 0002 — FORDEAD validation workflow (spec 008 / E6.c)

ALTER TABLE alert
  ADD COLUMN IF NOT EXISTS confidence_class TEXT,    -- 1-faible / 2-moyenne / 3-forte / 4-sol-nu
  ADD COLUMN IF NOT EXISTS stress_index DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS validation_status TEXT NOT NULL DEFAULT 'pending',
                              -- pending / confirmed / false_positive / closed
  ADD COLUMN IF NOT EXISTS validation_cause TEXT,    -- libre, ex. scolyte / coupe / casse / phéno
  ADD COLUMN IF NOT EXISTS validated_by TEXT,        -- email / oauth subject
  ADD COLUMN IF NOT EXISTS validated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS alert_validation_status_idx
  ON alert (validation_status);

-- Index composite pour la fusion rolling-window × fordead
CREATE INDEX IF NOT EXISTS alert_plot_date_type_idx
  ON alert (plot_id, trigger_date, alert_type);

-- L'extension du alert_type est par convention, pas de CHECK constraint
-- (libre : ndvi_drop, nbr_drop, fordead_dieback, futur).
```

---

## 9. Tests

### 9.1 Côté cœur (nemeton)

- `test-fordead-pipeline.R` : appel mocké du Python, vérifie l'orchestration (fonction par fonction). Skip if reticulate absent.
- `test-fordead-postprocess.R` : conversion raster → POINT centroides, classification, INSERT alert (TimescaleDB intégration via `with_clean_db`)
- `test-fordead-validity.R` : `check_fordead_validity()` sur AOIs synthétiques (Vosges → valid ; Massif Central → flag warning ; Brie → invalide géo + invalide espèces)
- `test-indicators-deperissement.R` : 15-20 assertions sur R5
- `test-fordead-validity-zones.R` : la `inst/extdata/fordead_validity_zones.geojson` charge, contient 5 polygones, surface attendue
- `test-health-validation-schema.R` : codes DSF présents, alignés Annexe 1
- `test-generate-health-validation-plots.R` : GRTS sur clusters, schéma QField correct
- `test-ingest-health-validation.R` : mise à jour `alert.validation_status`, `validation_cause`, snapping spatial < 50m
- Migration `0002_fordead.sql` : ajout au `test-db.R`

### 9.2 Côté app (nemetonshiny)

- `test-mod_monitoring.R` étendu : mode toggle, bannières conditionnelles, génération QField
- `test-service_monitoring_db.R` étendu : list_alerts avec filtre classes
- `test-mod_field_ingest.R` étendu : mode validation sanitaire

### 9.3 Smoke shinytest2

Un scénario E2E couvrant : ouvrir un projet, lancer FORDEAD (mocké), voir alertes leaflet, générer placettes, télécharger GPKG, simuler une saisie, ré-ingérer, voir alerte mise à jour.

---

## 10. Hors scope v0.21.0 (V+1 ou plus tard)

- **Cron worker** + ingestion automatique S2 (E6.f, après v0.21.0)
- **Notifications externes** (email, webhook)
- **Méthodes ML alternatives** (suite à la critique du rapport ONF sur le seuillage harmonique — explorer Bárta 2021, Deepak 2024)
- **Transposition autres essences** (en cours côté ONF, intégration future quand validé)
- **Re-calibration utilisateur** des seuils
- **Dashboard sysadmin** (latence STAC, queue Python)

---

## 11. Références

- Boissieu F, Fernandez E, Dutrieux R, Ose K, Féret J-B (2024). *fordead: a python package for vegetation anomalies detection from SENTINEL-2 images.* Zenodo. doi:10.5281/zenodo.12802456 (GPL-3)
- Bernard C, Doridant JB (2024). *Méthode FORDEAD — analyse de la validité des détections d'anomalies de végétation dans le cas des résineux par contrôle sur le terrain.* Office National des Forêts / Département de la Santé des Forêts, mai 2024.
- Bárta V, Lukeš P, Homolová L (2021). *Early detection of bark beetle infestation in Norway spruce forests of Central Europe using Sentinel-2.* International Journal of Applied Earth Observation and Geoinformation 100, 102335.
- Deepak M et al. (2024). *Early stress detection in conifer forests…* (cité par le rapport ONF, référence à compléter)
- Spec 005 (Open-Canopy CHM), Spec 007 (Monitoring continu — devient la couche surveillance rapide de spec 008)
- ADR-013 (à rédiger) — Méthode de suivi sanitaire = FORDEAD
- ADR-008 (souveraineté données UE), ADR-009 (séparation cœur/app), ADR-011 (NDP augmenté)

---

## 12. Amendement v0.23.0 — Migration vers l'API fordead 2.x

**Date** : 2026-05-16
**Statut** : approuvé (paperwork avant code)
**Concerne** : §3.3 (Pipeline FORDEAD complet) + §4 (Méthode FORDEAD — paramètres) + plan 008 §1.3 + §2.2 + ADR-013 amendement A1.
**Ce qui ne change pas** : tout le reste de spec 008 — vision (§1), garde-fous G1-G5, indicateur R5 (`R/indicators-deperissement.R`), workflow validation QField, tests et fixtures (`test-fordead-validity*.R`, `test-health_validation.R`, `test-indicators-deperissement.R`).

### 12.1 Motivation

La cascade de patches `v0.22.2..v0.22.5` (PyPI fix → RETICULATE_PYTHON conflict → PATH fallback → fordead 1.x pin → version-aware reinstall) a révélé un **gap d'intégration jamais validé** entre la spec originale et le code livré en `v0.21.0` :

1. **Kwargs incorrects** : `R/fordead_pipeline.R` appelait `compute_masked_vegetationindex(input_directory, vegetation_index)` ; la vraie signature fordead 1.11.4 est `compute_masked_vegetationindex(input_directory, data_directory, vi='CRSWIR', ...)`. Idem pour les steps 2/3/5 où c'est `data_directory` (pas `input_directory`).
2. **Mismatch de format d'entrée** : fordead 1.x lit des scènes Sentinel-2 au format **THEIA L2A** (sortie MAJA, structure `SENTINEL2A_<date>_<...>_T<tile>/` avec bandes + masques nuages + XML). Notre pipeline `ingest_sentinel2_timeseries()` produit un cache **STAC COG** (`<cache_dir>/{scene_id}/{band}.tif`). **Les deux formats ne sont pas interchangeables.** Aucun pont n'avait été conçu — plan 008 §2.2 montrait `input_directory = ...` sans préciser d'où venait le `...`.
3. **Tests offline mockés** : les 44 tests offline de `test-fordead-pipeline.R` acceptaient n'importe quel kwarg via des fixtures complaisantes. Aucun test ne touchait un vrai fordead → la double dérive est passée inaperçue jusqu'à la première exécution réelle en production (utilisateur final, 2026-05-16).

### 12.2 Décision

**Migrer vers fordead 2.x** (pin `@v2.1.1`). fordead 2.x est **conçu pour accepter directement une `simplestac.ItemCollection`** via la classe unifiée `fordead.workflow.FordeadProcess(collection, output_dir, bbox, geometry, config=FordeadConfig())`. C'est exactement le format de notre cache (notre `obs_pixel` table + les COGs disque sont des items STAC dérivables).

Bénéfices :
- **Suppression du gap STAC ↔ THEIA** — fordead 2.x lit directement nos COGs STAC, plus besoin d'un préprocesseur MAJA / THEIA download.
- **API unifiée** — une classe `FordeadProcess` au lieu de 5 step modules dispersés. Deux méthodes umbrella : `fit()` (entraîne le modèle) et `predict()` (produit les rasters d'anomalies).
- **Calibration ONF/DSF préservée** — les défauts 2.x correspondent exactement à ADR-013 : CRSWIR, seuil 0.16, 3 anomalies consécutives, fenêtre training 2016-01-01..2017-12-31. Aucune dérive métier.
- **Active branch** — fordead 1.x est en maintenance, 2.x est la branche de développement (INRAE/CNES).

### 12.3 Nouveau pipeline (§3.3 amendé)

```
                ┌─────────────────────────────────────────────┐
                │ INGESTION (E6.a, inchangée)                 │
                │   ingest_sentinel2_timeseries()             │
                │   → obs_pixel table + cache/{scene}/B*.tif  │
                └─────────────────────────────────────────────┘
                                    │
                                    ▼
                ┌─────────────────────────────────────────────┐
                │ STAC ASSEMBLY (NOUVEAU, R-side)             │
                │   .build_stac_collection_for_aoi(           │
                │       aoi, dates_training+dates_monitoring, │
                │       cache_dir)                            │
                │   → reticulate -> pystac.Item[] -> Item-    │
                │     Collection (simplestac)                 │
                └─────────────────────────────────────────────┘
                                    │
                                    ▼
                ┌─────────────────────────────────────────────┐
                │ FORDEAD 2.x (Python via reticulate)         │
                │   fp = FordeadProcess(collection, out_dir,  │
                │                       bbox=aoi_bbox,        │
                │                       config=cfg)           │
                │   fp$fit()      # entraîne (training range) │
                │   fp$predict()  # produit anomalies (monit) │
                │   → out_dir/ANOMALY_CONFIRMED/*.tif         │
                │     out_dir/ANOMALY_INDEX/*.tif             │
                │     out_dir/CONSECUTIVE_DETECTIONS/*.tif    │
                │     out_dir/DEVIATION/*.tif                 │
                └─────────────────────────────────────────────┘
                                    │
                                    ▼
                ┌─────────────────────────────────────────────┐
                │ POSTPROCESS (E6.c.2, adapté)                │
                │   .postprocess_fordead_rasters(out_dir)     │
                │   → lit ANOMALY_CONFIRMED (status)          │
                │   → lit ANOMALY_INDEX (stress_index)        │
                │   → utils.backward_start() pour             │
                │     first_dieback_date                      │
                │   → raster → patches → POINT clusters       │
                │   → snap-to-plot → INSERT alert table       │
                └─────────────────────────────────────────────┘
                                    │
                                    ▼
                ┌─────────────────────────────────────────────┐
                │ R5 INDICATEUR (E6.d, inchangé)              │
                │   indicateur_r5_deperissement(units, ...)   │
                └─────────────────────────────────────────────┘
```

### 12.4 Mapping outputs 1.x → 2.x

| Lecture postprocess actuelle (1.x théorique) | Équivalent 2.x |
|----------------------------------------------|----------------|
| `<out_dir>/DataAnomalies/state.tif` | `<out_dir>/ANOMALY_CONFIRMED/fordead_<YYYYMMDD>_ANOMALY_CONFIRMED.tif` (un fichier par date monitoring — prendre le plus récent) |
| `<out_dir>/DataAnomalies/first_dieback_date.tif` | Dérivé via `fordead.utils.backward_start(arr)` sur la pile `ANOMALY_CONFIRMED` |
| `<out_dir>/DataAnomalies/stress_index.tif` | `<out_dir>/ANOMALY_INDEX/fordead_<YYYYMMDD>_ANOMALY_INDEX.tif` |

`.postprocess_fordead_rasters()` reste un helper R-side ; seuls les chemins changent.

### 12.5 Phases du `progress_callback` (mises à jour)

Ancienne liste (1.x théorique) : `vegetation_index → train_model → forest_mask → dieback_detection → export_results → postprocess [→ persist]` — 6 ou 7 phases.

Nouvelle liste (2.x) : `stac_assembly → fit → predict → postprocess [→ persist]` — 4 ou 5 phases. Plus court, plus honnête : `fit()` et `predict()` englobent chacun plusieurs sous-étapes internes fordead (compute_spectral_index, compute_masks, train_model, predict_model, anomaly_detection, anomaly_analysis, confidence_analysis, stop_analysis).

Compatibilité côté `nemetonshiny@mod_monitoring` : les noms de phases sont des chaînes opaques côté UI (consommées comme `phase_name` pour les toasts). Le wiring se met à jour avec la release v0.23.0 (suivi côté app, séparé).

### 12.6 Configuration FordeadConfig — calibration

Les défauts de `FordeadConfig()` correspondent à ADR-013 :

| Paramètre ADR-013 | Champ fordead 2.x | Valeur défaut |
|-------------------|-------------------|---------------|
| Indice CRSWIR | `config.spectral_index.name` | `"CRSWIR"` |
| Formule CRSWIR | `config.spectral_index.formula` | `B11/(B8A+((B12-B8A)/(2185.7-864))*(1610.4-864))` |
| Fenêtre training | `config.fit.start` / `.end` | `"2016-01-01"` / `"2017-12-31"` |
| N min observations | `config.fit.Nmin` | `10` |
| Période monitoring | `config.predict.start` / `.end` | `"2018-01-01"` / `None` |
| Seuil anomalie | `config.predict.threshold` | `0.16` |
| Anomalies consécutives | `config.predict.nmax_anomaly` | `3` |
| Stops consécutifs | `config.predict.nmax_stop` | `3` |
| Stop définitif | `config.predict.definitive_stop` | `True` |
| Anomalie définitive | `config.predict.definitive_anomaly` | `False` |
| Mode count | `config.predict.flag_count_type` | `"v2"` |

`run_fordead_dieback()` continue d'exposer `dates_training`, `dates_monitoring`, `threshold_anomaly`, `vegetation_index` en argument R — ces valeurs sont propagées dans le `FordeadConfig` Python construit côté `R/fordead_pipeline.R`. **Pas de changement d'API R publique**.

### 12.7 Critères d'acceptation v0.23.0

- [ ] **AC.12.1** — `run_fordead_dieback(aoi, ...)` aboutit en `status = "success"` sur une AOI de test (≤ 1 km², données S2 PC) sans intervention manuelle (pas de `Sys.setenv("RETICULATE_PYTHON")` requis). *Couvert par `test-fordead-integration.R` opt-in (`NEMETON_FORDEAD_INTEGRATION=TRUE`) — validation finale côté utilisateur sur un cache S2 réel.*
- [ ] **AC.12.2** — Sortie `rasters$state` = `<out_dir>/ANOMALY_CONFIRMED/fordead_<YYYYMMDD>_ANOMALY_CONFIRMED.tif` existante et valide (`terra::rast()` ouvre, ≥ 1 pixel non-NA). *Vérifié dans le 1er test d'intégration.*
- [x] **AC.12.3** — Tests offline mockés mis à jour pour la nouvelle API ; **+ au moins 2 tests d'intégration** taggés `skip_if_no_fordead_integration()` qui appellent réellement `fp$fit()` (`test-fordead-integration.R` : pipeline e2e + AOI hors collection). *Recalibrage empirique des seuils dans `.fordead_2x_status_to_classes` reporté à un patch suivant (les seuils 3/6/10 sont des placeholders documentés).*
- [x] **AC.12.4** — Indicateur R5 (`R/indicators-deperissement.R`) inchangé. `.postprocess_fordead_rasters()` non modifié (input shape `list(state, stress_index, first_dieback_date)` préservé). Test de régression `test-indicators-deperissement.R` n'est pas touché.
- [x] **AC.12.5** — Migration documentée : NEWS.md `0.23.0` section "Changed" (avec migration notes + known limitations), PLAN.md journal, spec 008 §12 (ce document), plan 008 §9, ADR-013 amendement A1.

### 12.8 Migration côté app `nemetonshiny`

Hors scope cœur. À traiter dans un patch app séparé (probable `nemetonshiny@v0.32.0`) :

- Wiring des noms de phases dans les toasts (`monitoring_fordead_phase_*` i18n keys).
- Mise à jour du `Imports: nemeton (>= 0.23.0)` + `Remotes: pobsteta/nemeton@v0.23.0`.
- Smoke shinytest2 inchangé (skip si fordead absent).

---

## 13. Amendement v0.24.0 — Intégration FORDEAD ↔ ingest FAST (zone-as-input)

**Date** : 2026-05-16
**Statut** : approuvé (paperwork avant code)
**Concerne** : §12 (amendement A1 / v0.23.0) — refonte de la signature publique de `run_fordead_dieback()` et ajout d'une phase d'ingest interne. Garde-fous G1-G5 (§5), indicateur R5 (§6), workflow validation QField, calibration ADR-013 — tous inchangés.

### 13.1 Motivation

La v0.23.0 (livrée 2026-05-16) a sorti FORDEAD du gouffre 1.x / THEIA mais a introduit une API verbose côté caller :

```r
res <- run_fordead_dieback(
  aoi              = aoi,        # déjà connu par l'app
  scenes_df        = ???,        # à fabriquer
  cache_dir        = cache_dir,  # déjà connu par l'app
  dates_training   = ...,
  dates_monitoring = ...
)
```

Trois frictions découvertes à la 1ʳᵉ utilisation app (cf. journal 2026-05-16 *« scenes_df is required and must be a data.frame »*) :

1. **L'app a `con + zone_id` mais pas `scenes_df`**. Le scene_id est consommé pendant l'ingest puis n'est plus stocké en DB (la table `obs_pixel` est indexée par `(plot_id, obs_date, band)`, pas par scene_id). Reconstituer `scenes_df` impose de walker le cache disque depuis l'app, ce qui duplique de la logique côté présentation.
2. **FAST et FORDEAD partagent déjà `cache_dir` (`{projet}/cache/layers/sentinel2/`)** mais FORDEAD n'utilise pas le downloader de FAST. Conséquence : si FAST a tourné avec ses 3 bandes NDVI/NBR (B04, B08, B12) mais l'utilisateur lance FORDEAD avant d'avoir téléchargé les 4 bandes additionnelles requises pour CRSWIR + masques (B02, B05, B8A, B11), `.build_stac_collection_for_aoi()` skip toutes les scènes avec un warning agrégé — pipeline blocking sans message clair sur comment réparer.
3. **Aucun pont entre les deux pipelines** alors qu'ils visent la même donnée d'entrée et le même cache. `ingest_sentinel2_timeseries()` est déjà *partial-coverage-aware* depuis v0.21.3 (skip_cached vérifie l'`obs_pixel` au niveau band-par-scène) : si on l'appelle avec la liste de bandes FORDEAD complète et `skip_cached = TRUE`, elle se contente de descendre les bandes manquantes par scène, en ré-utilisant les COG cachés pour les bandes déjà là.

### 13.2 Décision

**Refondre la signature** de `run_fordead_dieback()` pour qu'elle prenne `con + zone_id + cache_dir` (au lieu de `aoi + scenes_df + cache_dir`) **et** délègue la garantie de disponibilité des bandes à `ingest_sentinel2_timeseries()` en première phase interne.

```r
res <- run_fordead_dieback(
  con              = con,         # NEW required — DBI connection
  zone_id          = zone_id,     # NEW required — monitoring_zone.id
  cache_dir        = cache_dir,   # required — partagé FAST/FORDEAD
  dates_training   = c("2016-01-01", "2017-12-31"),
  dates_monitoring = c("2018-01-01", as.character(Sys.Date()))
)
```

Tout le reste (`output_dir`, `vegetation_index`, `threshold_anomaly`, `min_pixels`, `connectivity`, `verbose`, `progress_callback`) inchangé.

**Conséquences API publique** :

- ❌ `aoi` supprimé (dérivé de `monitoring_zone.aoi`)
- ❌ `scenes_df` supprimé (retourné par l'ingest interne)
- ❌ `forest_mask` supprimé définitivement (était déjà deprecated / ignoré en v0.23.0)
- ✅ `con` et `zone_id` deviennent requis (n'étaient qu'optionnels — pour la phase persist — en v0.23.0)

**Breaking change** — tous les callers v0.23.0 doivent migrer. L'app fait `con + zone_id + cache_dir` au lieu de fabriquer scenes_df, donc en pratique c'est une simplification côté caller.

### 13.3 Nouveau pipeline (§3.3 et §12.3 amendés)

```
                ┌─────────────────────────────────────────────┐
                │ PHASE 0 — ingest (NOUVEAU)                  │
                │   ingest_sentinel2_timeseries(              │
                │     con, zone_id,                           │
                │     bands     = c("B02","B04","B05",        │
                │                   "B8A","B11","B12"),       │
                │     date_from = dates_training[1],          │
                │     date_to   = dates_monitoring[2],        │
                │     cache_dir,                              │
                │     skip_cached = TRUE,                     │
                │     progress_callback                        │
                │   )                                          │
                │   → garantit le cache complet               │
                │   → retourne scenes_df                      │
                │   → re-utilise COGs partiels du cache FAST  │
                │     sans re-télécharger                     │
                └─────────────────────────────────────────────┘
                                    │
                                    ▼
                ┌─────────────────────────────────────────────┐
                │ PHASE 1 — stac_assembly (v0.23.0)           │
                │   aoi <- .get_zone_aoi(con, zone_id)        │
                │   .build_stac_collection_for_aoi(           │
                │     aoi, scenes_df, cache_dir, bands)       │
                │   .build_fordead_config(...)                │
                └─────────────────────────────────────────────┘
                                    │
                                    ▼
                ┌─────────────────────────────────────────────┐
                │ PHASE 2 — fit (v0.23.0)                     │
                │ PHASE 3 — predict (v0.23.0)                 │
                │ PHASE 4 — postprocess (v0.23.0)             │
                │ PHASE 5 — persist (optionnel, v0.23.0)      │
                └─────────────────────────────────────────────┘
```

### 13.4 progress_callback — flux d'événements

L'ingest interne émet ses propres événements (`s2:search`, `s2:scene`, `s2:scene_cached`, `s2:band_fetched`, `s2:complete`) — déjà connus de l'app pour FAST. La FORDEAD pipeline laisse ces événements traverser intacts vers le callback utilisateur, **en plus** des événements `fordead:*` à elle. L'app a donc deux flux superposés :

- `fordead:phase` / `fordead:phase_done` — granularité pipeline (6 phases au lieu de 5 en v0.23.0 : ajout de `ingest` en tête)
- `s2:*` — granularité scène-par-scène à l'intérieur de la phase ingest

Avantage : les toasts de l'app (déjà génériques côté `nemetonshiny@v0.32.0`) gèrent les deux familles sans rework. Une nouvelle clé i18n `monitoring_fordead_phase_ingest` à ajouter côté app pour le label de la phase.

### 13.5 Liste de bandes FORDEAD vs FAST

| Pipeline | Bandes |
|----------|--------|
| FAST (rolling-window NDVI/NBR) | B04, B08, B12 |
| FORDEAD (CRSWIR + masques) | B02, B04, B05, B8A, B11, B12 |
| Union (cache rempli après FAST puis FORDEAD) | B02, B04, B05, B08, B8A, B11, B12 (7 bandes) |

L'ingest FORDEAD demande l'union de SES bandes ; le `skip_cached = TRUE` partial-coverage-aware ne re-fetche que ce qui manque. Pas de duplication.

Note : B08 n'est pas dans la liste FORDEAD (B8A est utilisé à la place, plus étroit, requis par la formule CRSWIR). Si FAST n'a tourné avant, B08 reste downloadable pour FAST mais FORDEAD ne le demande pas.

### 13.6 Helpers à ajouter / modifier

| Helper | Statut | Description |
|--------|--------|-------------|
| `.get_zone_aoi(con, zone_id)` | **nouveau** | Query `monitoring_zone` → retourne sf POLYGON en EPSG:2154. Erreur typée si zone_id inconnu. |
| `FORDEAD_BANDS` | **nouveau** constante exportée | `c("B02","B04","B05","B8A","B11","B12")` — utilisée par run_fordead_dieback et documentée publique. |
| `run_fordead_dieback()` | refondu | Nouvelle signature §13.2. Phase `ingest` ajoutée en tête du `phase_plan`. |
| `.build_stac_collection_for_aoi()` | inchangé | Helper de session 1 v0.23.0 — toujours appelé en phase stac_assembly. |
| `.build_fordead_config()` | inchangé | Idem. |
| `.fordead_2x_status_to_classes()` | inchangé | Idem. |
| `.postprocess_fordead_rasters()` | inchangé | Idem. |

### 13.7 Critères d'acceptation v0.24.0

- [ ] **AC.13.1** — `run_fordead_dieback(con, zone_id, cache_dir, dates_*)` aboutit en `status = "success"` sur la zone de test de l'utilisateur sans intervention manuelle.
- [ ] **AC.13.2** — La phase `ingest` complète le cache (constatable par `diagnose_s2_cache()` avant et après — nombre de bandes par scène passe de 3 à 6+).
- [ ] **AC.13.3** — Re-lancer `run_fordead_dieback()` sur la même zone avec le cache déjà rempli ne re-télécharge rien (vérifiable par les événements `s2:scene_cached` qui doivent dominer les logs).
- [ ] **AC.13.4** — `FORDEAD_BANDS` est exporté et documenté (cf. NAMESPACE).
- [ ] **AC.13.5** — Tests offline mockés mis à jour pour la nouvelle signature ; tests d'intégration `test-fordead-integration.R` mis à jour pour appeler la nouvelle API.
- [ ] **AC.13.6** — Migration documentée : NEWS.md `0.24.0` section "Changed" (breaking), PLAN.md journal, spec 008 §13 (ce document), plan 008 §10, ADR-013 amendement A2.

### 13.8 Migration côté app `nemetonshiny`

Le call site dans `R/mod_monitoring.R` passe de :

```r
nemeton::run_fordead_dieback(
  aoi              = aoi,
  dates_training   = ...,
  dates_monitoring = ...
)
```

vers :

```r
nemeton::run_fordead_dieback(
  con              = con,
  zone_id          = zone_id,
  cache_dir        = cache_dir,
  dates_training   = ...,
  dates_monitoring = ...
)
```

`Imports: nemeton (>= 0.24.0)` + `Remotes: pobsteta/nemeton@v0.24.0`. Nouvelle clé i18n `monitoring_fordead_phase_ingest` à ajouter (FR `"Téléchargement des scènes"` / EN `"Scene download"`). Tout le wiring toast existant absorbe la nouvelle phase sans modification grâce au design générique de `nemetonshiny@v0.32.0`. Probable release `nemetonshiny@v0.33.0`.

## 14. Amendement v0.42.0 — Diagnostic pixel CRSWIR au clic (Carte FORDEAD)

**Date** : 2026-05-20
**Statut** : approuvé (paperwork avant code)
**Concerne** : §3.3 / §12.3 / §13.3 (pipeline `run_fordead_dieback()` — phase `persist`). Ajoute une API de lecture cœur et une interaction app. Garde-fous G1-G5 (§5), indicateur R5 (§7), calibration (§4), workflow QField (§6) — tous inchangés.

### 14.1 Motivation

La Carte FORDEAD (`nemetonshiny::mod_monitoring_fordead_map`) n'affiche aujourd'hui que le raster catégoriel 0-4 du masque de dépérissement. Un clic ne déclenche rien.

Sur la voie rapide, la Carte pixel FAST (spec 010) offre déjà un diagnostic au clic : `observeEvent(input$map_click)` → `nemeton::extract_pixel_timeseries()` → modal plotly de la série NDVI/NBR. C'est l'outil d'investigation « pourquoi ce pixel est-il flaggé ? ».

L'équivalent FORDEAD manque. Le forestier qui voit une tache rouge (classe 3-forte) sur la Carte FORDEAD ne peut pas inspecter le **signal CRSWIR** sous-jacent : sa série observée, la courbe du modèle harmonique fitté sur la période d'entraînement, et le seuil d'anomalie qui a déclenché la détection. C'est pourtant le diagnostic le plus parlant de la méthode FORDEAD (cf. les figures pixel des tutoriels INRAE fordead).

### 14.2 Décision

Ajouter un **diagnostic pixel CRSWIR au clic** sur la Carte FORDEAD, calqué sur le patron Carte pixel FAST. Le graphique superpose :

1. **CRSWIR observé** — la série temporelle masquée (nuage / ombre / sol) telle que FORDEAD l'a vue.
2. **Prédiction du modèle harmonique** — la courbe saisonnière fittée sur la période d'entraînement.
3. **Bande de seuil d'anomalie** — l'aire `prédiction → prédiction + threshold_anomaly` ; un CRSWIR observé au-dessus = anomalie (le CRSWIR monte sous stress hydrique).
4. **Marqueur de première détection** — `vline` à la date de première anomalie confirmée sur ce pixel.

**Contrainte d'architecture** : les bornes affichées doivent provenir du **run FORDEAD réel** (ADR-013 §1 — FORDEAD est la méthode officielle). On **ne re-fitte pas** le modèle côté R. Cela impose de **persister les artefacts du modèle harmonique**, aujourd'hui perdus avec l'`output_dir` temporaire.

Trois sous-livraisons :

- **L1 (cœur, v0.42.0)** — persistance d'un *bundle diagnostic* léger dans la phase `persist`.
- **L2 (cœur, v0.43.0)** — fonction de lecture exportée `read_fordead_pixel_series()`.
- **L3 (app, `nemetonshiny`)** — handler de clic + modal plotly sur `mod_monitoring_fordead_map`.

### 14.3 Artefacts persistés — le bundle diagnostic (L1)

Aujourd'hui, seul le masque 0-4 `dieback_mask_<ts>.tif` est persisté (v0.41.0) ; le reste du working set FORDEAD (~1000 rasters) vit dans un `output_dir` temporaire effacé en fin de session, sauf `keep_output = TRUE`.

La phase `persist` écrit en plus, sous `<mask_cache_dir>/zone_<id>/model_<run_id>/` (le `run_id` = timestamp du run, identique à celui du masque) :

| Artefact | Fichier | Contenu |
|---|---|---|
| Coefficients harmoniques | `coeff_model.tif` | Raster 5 bandes — les 5 coefficients du `HarmonicModel` fordead par pixel. Empreinte négligeable. |
| CRSWIR observé masqué | `crswir_stack.tif` | Raster multibande, une bande par date (`terra::time()` posé), valeurs masquées nuage / ombre / sol — tel que FORDEAD l'a modélisé. |
| Date de première anomalie | `first_anomaly.tif` | Raster 1 bande — date (jours depuis l'époque) de la première anomalie confirmée. |
| Métadonnées du run | `run_meta.json` | `vegetation_index`, `threshold_anomaly`, `dates_training`, `dates_monitoring`, `run_id`, version fordead, CRS. |

Écriture **best-effort** : un échec `warn` mais n'aborte jamais le run — même contrat que le persist-hook du masque (v0.41.0). Empreinte attendue sur une AOI de monitoring : quelques Mo (`coeff_model` négligeable, `crswir_stack` ≈ N dates × petit raster).

`keep_output = TRUE` reste l'échappatoire « tout garder » ; le bundle curé est le chemin nominal toujours actif.

### 14.4 API cœur — `read_fordead_pixel_series()` (L2)

```r
read_fordead_pixel_series(
  con,                         # DBI — réservé (lien run↔projet futur)
  zone_id,
  xy,                          # numeric(2) — coordonnées du pixel cliqué
  crs       = 4326,            # EPSG d'origine de xy (convention leaflet)
  run_id    = NULL,            # NULL → run le plus récent
  cache_dir                    # racine cache projet (cf. read_fordead_dieback_mask)
)
```

**Retour** : `data.frame` trié par `obs_date`, colonnes :

| Colonne | Type | Description |
|---|---|---|
| `obs_date` | Date | Date d'observation. |
| `crswir_obs` | numeric | CRSWIR observé masqué (NA si date masquée — conservé, pas filtré). |
| `crswir_pred` | numeric | CRSWIR prédit par le modèle harmonique. |
| `seuil_haut` | numeric | `crswir_pred + threshold_anomaly`. |
| `anomalie` | logical | `crswir_obs > seuil_haut`. |

Attributs portés sur le `data.frame` : `threshold_anomaly`, `premiere_detection` (Date ou `NA`), `dans_zone_validite` (logical, via `check_fordead_validity()`), `vegetation_index`.

Conventions de chemin et de sélection `run_id` alignées sur `read_fordead_dieback_mask()` (v0.25.0). Retourne `NULL` proprement si aucun run trouvé ou pixel hors emprise. Modelée sur `extract_pixel_timeseries()` (spec 010 §4.4).

### 14.5 Reconstruction de la prédiction harmonique — parité FORDEAD

`crswir_pred` doit être **identique** à ce que FORDEAD calcule en interne. La prédiction = `(coeff_model · termes_harmoniques(date)).sum()`, où `termes_harmoniques` est la base 5-termes de `fordead.modeling.compute_HarmonicTerms`.

**Décision D3** : ne PAS réimplémenter la base harmonique en R. `read_fordead_pixel_series()` appelle, via `reticulate`, `fordead.modeling.HarmonicModel` (ou directement `compute_HarmonicTerms` / `dates_to_days`) sur les coefficients lus au pixel. Garantit la parité bit-à-bit avec le run et évite la dérive d'une 2ᵉ implémentation (cf. ADR-013 alternative D — fork R écarté). `reticulate` est déjà en `Suggests` (FORDEAD).

### 14.6 Pipeline persist amendé

`run_fordead_dieback()` — la phase `persist` (la dernière) gagne, après l'écriture du masque 0-4 :

```
PHASE 5 — persist
  ├─ écrit dieback_mask_<run_id>.tif        (v0.41.0, inchangé)
  └─ écrit model_<run_id>/                  (NOUVEAU — L1)
       ├─ coeff_model.tif
       ├─ crswir_stack.tif
       ├─ first_anomaly.tif
       └─ run_meta.json
```

Pas de nouvelle phase, pas de changement de signature, pas de nouvel événement `progress_callback`. Le résultat de `run_fordead_dieback()` gagne `rasters$model_dir` (chemin du bundle, ou `NA_character_` si l'écriture a échoué).

### 14.7 Critères d'acceptation

- [x] **AC.14.1** — Après `run_fordead_dieback()`, `<mask_cache_dir>/zone_<id>/model_<run_id>/` contient les 4 artefacts (§14.3). *(L1, v0.42.0)*
- [x] **AC.14.2** — `read_fordead_pixel_series()` retourne un `data.frame` au schéma §14.4 ; `crswir_pred` égale (tolérance 1e-6) la prédiction de `fordead.modeling` (`compute_HarmonicTerms`) sur les mêmes coefficients. *(L2, v0.43.0 — test parité testé contre le venv réel)*
- [x] **AC.14.3** — `read_fordead_pixel_series()` retourne `NULL` sans erreur si aucun run / pixel hors emprise / venv absent. *(L2, v0.43.0)*
- [ ] **AC.14.4** — La colonne `anomalie` est cohérente avec le masque 0-4 (un pixel classe ≥ 1 a au moins une date `anomalie = TRUE`). *(propriété d'intégration — à vérifier sur un run réel ; la logique `anomalie = crswir_obs > seuil_haut` est en place et testée unitairement)*
- [x] **AC.14.5** — Persistance best-effort : un `model_dir` non inscriptible `warn` mais le run termine `status = "success"`. *(L1, v0.42.0)*
- [x] **AC.14.6** — `read_fordead_pixel_series()` exporté + roxygen complet ; ≥ 8 tests offline (`test-fordead-pixel-series.R`, 13 blocs / 32 assertions) avec fixture bundle synthétique. *(L2, v0.43.0)*
- [x] **AC.14.7** — `devtools::check()` sans nouveau ERROR / WARNING / NOTE. *(v0.42.0 + v0.43.0)*
- [x] **AC.14.8** — Doc : NEWS.md, PLAN.md journal, spec 008 §14 (ce document), ADR-013 amendement A3.

### 14.8 Migration / intégration côté app `nemetonshiny` (L3 — pour mémoire, hors repo cœur)

`mod_monitoring_fordead_map.R` gagne :

- `observeEvent(input$map_click)` → `nemeton::read_fordead_pixel_series(con, zone_id, xy = c(lng, lat), cache_dir = ...)` → `showModal` + `plotlyOutput`.
- Graphique plotly : `crswir_obs` (points), `crswir_pred` (ligne), bande `seuil_haut` (aire remplie), `vline` à `premiere_detection`. Bannière d'avertissement si `dans_zone_validite = FALSE`.
- Patron strictement calqué sur le modal de `mod_monitoring_pixel_map.R` (lignes 669-754).
- Nouvelles clés i18n FR/EN : `monitoring_fordead_pixel_modal_title_fmt`, `monitoring_fordead_crswir_observed`, `monitoring_fordead_crswir_model`, `monitoring_fordead_anomaly_band`, `monitoring_fordead_first_detection`, `monitoring_fordead_outside_validity`.
- `Imports: nemeton (>= 0.43.0)`. Release probable `nemetonshiny@vX.Y.0`.
