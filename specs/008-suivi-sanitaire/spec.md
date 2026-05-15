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
- Dépendances Python figées dans `inst/python/requirements.txt` : `fordead @ git+https://gitlab.com/fordead/fordead_package@v2.1.1` (pas sur PyPI, cf. fix v0.22.2), `xarray`, `dask[complete]`, `rasterio`, `eodag`, `numpy`, `pandas`, `geopandas`, `shapely`.
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
