# Spécification Fonctionnelle : Intégration produits globaux pré-calculés

**Version** : 0.1.0 (draft)
**Date** : 2026-04-17
**Statut** : Draft
**Auteur** : Pascal Obstétar (via Claude)
**Cible nemeton** : v0.16.0 (parallèle à spec 005) ou v0.17.0

---

## 1. Résumé Exécutif

### 1.1 Vision

Étendre la couche d'abstraction `get_data_source()` (ADR-002) pour permettre à `nemeton` de **consommer directement** des produits de télédétection globaux **déjà calculés et publiés** (Meta/WRI Canopy Height, ESA WorldCover, Dynamic World, Potapov GFCH), sans dépendance d'inférence locale.

### 1.2 Principe

Spec 005 (Open-Canopy) produit un CHM **localement** via inférence PyTorch, idéal pour la France métropolitaine à 0.20 m natif. Spec 006 adopte l'approche inverse : consommer ce qui est **déjà calculé à l'échelle mondiale** sous licence ouverte. Pas d'inférence, pas de GPU, pas de Python — juste `terra::rast()` avec lecture par fenêtre (COG ou STAC).

Les deux specs sont **complémentaires**, pas concurrentes :
- **Spec 005 / `opencanopy`** : France métropolitaine, HR native IGN, P1/P2 parcellaire fin
- **Spec 006 / `nemeton` direct** : outre-mer, Europe, monde, NDP 0 universel

### 1.3 Objectifs métier

| Objectif | Métrique de succès |
|----------|-------------------|
| Couvrir l'outre-mer français (Guyane, Antilles, Réunion, Mayotte, NC) | CHM disponible pour au moins une AOI DOM-TOM avec qualité satisfaisante |
| Couvrir l'Europe et le monde | `nemeton_compute()` fonctionne sur une parcelle en Allemagne, Espagne, Canada |
| Éviter la dépendance PyTorch/GPU côté client | Aucune installation Python requise pour utiliser les indicateurs P1/P2 à NDP 0 via Meta/WRI |
| Validation croisée avec Open-Canopy | Fonction `cross_validate_chm(chm_opencanopy, chm_meta)` produit une divergence locale |

### 1.4 Hors-scope

- Entraînement ou fine-tuning de modèles (c'est la raison même de consommer ces produits)
- Génération de time-series S2 (traité ultérieurement dans un `sentinel_nemeton` si besoin)
- Hébergement miroir des produits (on s'appuie sur AWS Open Data Registry, Google Earth Engine, etc.)
- Détection de changement multi-millésimes (spec 007 potentiel)

---

## 2. Produits ciblés

### 2.1 Sélection initiale

Quatre produits retenus, tous en licence ouverte et hébergés publiquement :

| Produit | Résolution | Couverture | Nature | Licence | Source |
|---------|------------|------------|--------|---------|--------|
| **Meta/WRI HR Canopy Height** | 1 m | Monde (forêts) | CHM | CC-BY 4.0 | AWS Open Data Registry |
| **Potapov Global Forest Canopy Height** | 30 m | Monde | CHM | CC-BY (UMD) | Univ. of Maryland / GLAD |
| **ESA WorldCover 2020 / 2021** | 10 m | Monde | 11 classes occupation | CC-BY 4.0 | ESA (zenodo + S3) |
| **Dynamic World** | 10 m | Monde, quasi temps réel | 9 classes occupation + probabilités | CC-BY 4.0 | Google / WRI (via GEE et STAC) |

### 2.2 Méthodologies sous-jacentes (pour contexte)

- **Meta/WRI** : DINOv2 (ViT auto-supervisé) sur Maxar RVB, calibré via **GEDI** (lidar spatial NASA). Publication : Tolan et al. 2024.
- **Potapov GFCH** : régression GEDI sur Landsat multi-annuelles. Publication : Potapov et al. 2021.
- **ESA WorldCover** : classification S1+S2 par CNN. Produit par une consortium européen.
- **Dynamic World** : TensorFlow semantic segmentation sur S2 L1C, cadence hebdomadaire. Google Research 2022.

### 2.3 Extensions envisagées (hors MVP)

- **CCI Biomass** (ESA CCI) : biomasse aérienne 100 m global
- **Hansen Global Forest Change** : détection déforestation à 30 m, annuelle
- **Copernicus HRL Forest** : Europe, 10 m
- **WRI Global Forest Watch layers** : incendies, alertes déforestation (GLAD, RADD)

---

## 3. Architecture

### 3.1 Principe d'abstraction

Aucun nouveau package. Tout s'inscrit dans `nemeton::get_data_source()` (ADR-002) et dans un nouveau module `R/remote_data.R` pour l'accès réseau.

```
┌───────────────────────────────┐
│   nemeton (ce repo)           │
│                               │
│   get_data_source(            │
│     "canopy_height_meta"      │
│     aoi = units               │
│   )                           │
│      │                        │
│      ▼                        │
│   fetch_remote_raster()       │
│      │  (vsis3, STAC, COG)    │
│      ▼                        │
│   terra::rast (window=aoi)    │
│      │                        │
│      ▼                        │
│   raster local (ou cache)     │
└────────────┬──────────────────┘
             │
             ▼
     indicators-*.R
     (P1, P2, A1, C1, B2, R2)
```

### 3.2 Accès réseau

Trois modes techniques possibles :

1. **S3 direct (vsis3 GDAL)** : pour COG hébergés sur AWS Open Data Registry. `terra::rast("/vsis3/...")` avec crédentials anonymes. **Mode privilégié Meta/WRI.**
2. **STAC** : via `rstac` (package R) pour Dynamic World, Planetary Computer, etc. Catalogue, recherche, puis lecture COG.
3. **HTTPS + téléchargement** : pour ESA WorldCover (fichiers Zenodo), Potapov GFCH. Cache local obligatoire.

### 3.3 Cache local

- Répertoire : `~/.local/share/nemeton/remote_cache/{source}/{tile_id}/`
- Index DuckDB : `~/.local/share/nemeton/remote_cache.duckdb` — colonnes `source, tile_id, aoi_hash, path, fetched_at, checksum`
- Stratégie par produit :
  - Meta/WRI : COG, lecture par fenêtre sans téléchargement intégral possible si réseau disponible
  - ESA WorldCover : tuiles 3° × 3°, téléchargement + cache
  - Dynamic World : patch AOI, téléchargement + cache
  - Potapov : tuiles 10° × 10°, téléchargement + cache

---

## 4. Impact sur les indicateurs

### 4.1 Famille P (Production)

| Ind. | Usage | Niveau de gain |
|------|-------|----------------|
| **P1 volume** | CHM Meta → H_dom si opencanopy indisponible | Équivalent opencanopy (~2-3 m RMSE) |
| **P2 station** | CHM Meta → indice de station (réutilise `compute_site_index`) | Équivalent opencanopy |

### 4.2 Famille C (Carbone)

| Ind. | Usage | Niveau de gain |
|------|-------|----------------|
| **C1 biomasse** | CHM Meta → allométrie H-based + éventuellement CCI Biomass direct | Élevé, particulièrement outre-mer |
| **C2 vitalité** | Dynamic World NDVI time-series | Élevé, dynamique temporelle gratuite |

### 4.3 Famille A (Air & Microclimat)

| Ind. | Usage | Niveau de gain |
|------|-------|----------------|
| **A1 couverture arborée** | ESA WorldCover 10 m (classe 10 tree cover) | Élevé hors France, remplace OSO |

### 4.4 Famille L (Paysage)

| Ind. | Usage | Niveau de gain |
|------|-------|----------------|
| **L1 fragmentation** | ESA WorldCover / Dynamic World classes forestières | Élevé, disponible partout |
| **L2 fragmentation edge** | Idem | Même gain |

### 4.5 Famille B (Biodiversité)

| Ind. | Usage | Niveau de gain |
|------|-------|----------------|
| **B2 structure** | CHM Meta pour cv_chm en plus (mêmes branches que spec 005) | Équivalent opencanopy |
| **B3 connectivité** | ESA WorldCover pour continuité forestière | Moyen |

### 4.6 Famille T (Temporel)

| Ind. | Usage | Niveau de gain |
|------|-------|----------------|
| **T2 changement** | Dynamic World (hebdo) ou Hansen GFC (annuel) | **Très élevé** — ouvre la détection continue |

### 4.7 Famille R (Risque)

| Ind. | Usage | Niveau de gain |
|------|-------|----------------|
| **R2 tempête** | CHM Meta → calibration vulnérabilité (comme spec 005) | Équivalent opencanopy |

---

## 5. Interfaces techniques

### 5.1 Enrichissement `datasources.R`

Nouvelles entrées :

```r
list(
  canopy_height_meta = list(
    type          = "raster_remote_cog",
    endpoint      = "s3://dataforgood-fb-forests/v1/...",
    format        = "COG",
    resolution_m  = 1.0,
    unit          = "m",
    coverage      = "global",
    licence       = "CC-BY 4.0 (derived) ; Maxar terms apply to imagery",
    citation      = "Tolan et al. 2024, Meta/WRI",
    recommended_for = c("outre_mer", "europe", "world"),
    not_recommended_for = "france_metropolitaine (prefer opencanopy)"
  ),
  landcover_worldcover = list(
    type         = "raster_remote_cog",
    endpoint     = "s3://esa-worldcover/v200/...",
    resolution_m = 10,
    classes      = 11,
    licence      = "CC-BY 4.0",
    citation     = "ESA WorldCover 2021, Zanaga et al."
  ),
  landcover_dynamic_world = list(
    type         = "raster_stac",
    stac_url     = "https://planetarycomputer.microsoft.com/api/stac/v1",
    collection   = "io-lulc-annual-v02",
    resolution_m = 10,
    classes      = 9,
    temporal     = "weekly",
    licence      = "CC-BY 4.0",
    citation     = "Brown et al. 2022, Dynamic World / Google"
  ),
  canopy_height_potapov = list(
    type         = "raster_remote_http",
    endpoint     = "https://glad.umd.edu/dataset/global_2008_2020/",
    resolution_m = 30,
    licence      = "CC-BY",
    citation     = "Potapov et al. 2021"
  )
)
```

### 5.2 API publique

```r
# Récupération d'un raster distant pour une AOI
chm <- fetch_remote_raster(
  source = "canopy_height_meta",
  aoi    = units,
  crs    = "EPSG:2154",
  cache  = TRUE
)
# → SpatRaster terra, découpé sur l'AOI, reprojeté si nécessaire

# Sélection automatique de la meilleure source pour une zone
source_name <- auto_select_chm_source(aoi = units)
# → "opencanopy" pour France métro, "canopy_height_meta" ailleurs

# Validation croisée (si deux sources disponibles)
cv <- cross_validate_chm(chm_opencanopy, chm_meta)
# → list(mean_abs_diff, pixelwise_diff_raster, agreement_pct)
```

### 5.3 Modifications indicateurs

Pour les indicateurs déjà adaptés en spec 005 (P1, P2, C1, B2, R2) : **aucune modification** supplémentaire. Ils acceptent un raster CHM en entrée, peu importe sa provenance.

Nouvelles modifications pour les indicateurs qui consomment des classes d'occupation :

- `R/indicators-air.R::indicator_air_coverage()` : branche `landcover_worldcover`
- `R/indicators-landscape.R::indicator_landscape_fragmentation()` : branche `landcover_worldcover` ou `landcover_dynamic_world`
- `R/indicators-temporal.R::indicator_temporal_change()` : branche `landcover_dynamic_world` (multi-dates) ou Hansen GFC

### 5.4 Sélection de la source selon zone et NDP

Règle métier dans `auto_select_chm_source()` :

```r
if (aoi_in_france_metro(aoi)) {
  if (has_local_file("opencanopy")) return("opencanopy")     # priorité IGN
  return("canopy_height_meta")                               # fallback global
} else if (aoi_in_dom_tom(aoi) || aoi_in_europe(aoi)) {
  return("canopy_height_meta")                               # monde entier
} else {
  return("canopy_height_meta")                               # monde
}
```

Peut être surchargée par `layers$chm_source` pour forcer une source.

---

## 6. Licences et attributions

### 6.1 Licences sources

- **Meta/WRI Canopy Height** : CC-BY 4.0 pour le produit dérivé ; attribution « Meta & WRI 2024, Tolan et al. »
- **ESA WorldCover** : CC-BY 4.0 ; attribution « © ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data »
- **Dynamic World** : CC-BY 4.0 ; attribution « Google / WRI / NGS / UN »
- **Potapov GFCH** : CC-BY ; attribution « Potapov et al. 2021, University of Maryland, GLAD »

### 6.2 Enrichissement `inst/NOTICE`

Compléter le NOTICE créé en spec 005 :
- Mention Meta/WRI avec DOI Tolan et al.
- Mention ESA WorldCover
- Mention Dynamic World
- Mention GLAD / Potapov

### 6.3 Point de vigilance Maxar

Le produit Meta/WRI est CC-BY 4.0, mais **les images Maxar sous-jacentes** restent sous licence commerciale. Ça veut dire :
- On peut redistribuer le CHM dérivé librement ✓
- On NE peut PAS redistribuer des patches Maxar bruts
- Dans `massif_demo`, si on met un CHM issu de Meta/WRI comme fixture, uniquement le **CHM**, jamais l'imagerie source

---

## 7. Stratégie de cache

Les produits sont gros. Règles :

1. **Meta/WRI** : COG global, lecture par fenêtre via `vsis3`. Pas de téléchargement intégral. Cache local des fenêtres lues dans `remote_cache/canopy_height_meta/{aoi_hash}.tif`.
2. **ESA WorldCover** : tuiles 3° × 3° en GeoTIFF. ~60 Mo par tuile. Cache local, max 10 Go.
3. **Dynamic World** : patch découpé à l'AOI via STAC + `rstac::assets_url()` + `terra::rast()`. Cache par AOI + date.
4. **Potapov** : tuiles 10° × 10°. ~200 Mo par tuile. Cache local.

**Purge** : fonction `clean_remote_cache(max_age_days = 180, max_size_gb = 20)` exportée.

**Config** : `options(nemeton.remote_cache = "/path/to/cache")` pour surcharger.

---

## 8. Plan d'implémentation (synthèse — détail dans plan.md)

| Phase | Contenu | Version |
|-------|---------|---------|
| 1 | Infrastructure `fetch_remote_raster` + cache + `datasources.R` enrichi | v0.16.x intermédiaire |
| 2 | Meta/WRI comme source CHM de fallback pour P1/P2/C1/B2/R2 | v0.17.0 |
| 3 | ESA WorldCover pour A1/L1/L2/B3 | v0.17.0 |
| 4 | Dynamic World pour T2 (changement) | v0.17.0 |
| 5 | Potapov 30 m comme fallback tertiaire | v0.17.1 |
| 6 | `cross_validate_chm` + diagnostic divergence (bonus NDP augmenté) | v0.17.1 |

Phases indépendantes les unes des autres après la phase 1.

---

## 9. Risques et points d'attention

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Indisponibilité AWS/GCP | Faible | Moyen | Cache local persistant, fallback Potapov |
| Changement d'endpoint Meta/WRI | Moyen | Faible | Abstraction via `datasources.R` — un seul point à modifier |
| Coût réseau élevé en utilisation intensive | Moyen | Moyen | Cache local obligatoire + limites configurables |
| Hétérogénéité CRS entre produits | Élevé | Faible | `terra::project()` automatique vers le CRS de l'AOI |
| Meta/WRI RMSE trop dégradée pour certaines zones | Moyen | Moyen | Exposer via `cross_validate_chm` + warning si diff > 5 m |
| Licence Maxar « contamine » notre redistribution | Faible | Moyen | Ne jamais redistribuer que le CHM, pas l'imagerie |

---

## 10. Relation avec spec 005

Les deux specs sont **parfaitement complémentaires** :

| Aspect | spec 005 (opencanopy) | spec 006 (produits globaux) |
|--------|------------------------|------------------------------|
| Package externe | `opencanopy` (reticulate + PyTorch) | Aucun — tout dans `nemeton` |
| Zone | France métropolitaine uniquement | Monde |
| Infrastructure | GPU/CPU local | Réseau + cache |
| Résolution | 0.20 m natif / 1.5 m agrégé | 1-30 m selon produit |
| Inférence | Locale | Déjà calculée |
| Mise à jour | Manuelle (relancer `pipeline_aoi_to_chm`) | Automatique (providers) |

**Logique NDP** :
- À NDP 0, les deux sources sont valables — selon la zone, `auto_select_chm_source()` choisit.
- Flag `augmented` reste `"height_ml"` quelle que soit la source ML (pas de sous-distinction dans le flag pour garder la simplicité).
- Si les deux sont disponibles : `cross_validate_chm()` expose la divergence sans masquer l'information.

---

## 11. Décisions à valider

| # | Sujet | Proposition |
|---|-------|-------------|
| Q1 | Créer un nouveau package `remote_data_nemeton` ou garder dans `nemeton` ? | **Garder dans `nemeton`** : uniquement du fetch + cache, pas de ML |
| Q2 | Dépendances à ajouter | `aws.s3` ou mieux `paws` (lecture S3), `rstac` (STAC queries) — **Suggests seulement**, pas Imports |
| Q3 | Cache par défaut via `rappdirs::user_cache_dir()` ou chemin fixe ? | `rappdirs::user_cache_dir("nemeton")` pour portabilité OS |
| Q4 | Priorité Meta/WRI vs opencanopy en France métro | **opencanopy prioritaire** (résolution native 0.20 m) ; Meta/WRI en fallback silencieux |
| Q5 | Dynamic World nécessite Google ou STAC public ? | STAC public via Microsoft Planetary Computer (gratuit, pas d'auth) |

---

## 12. Références

- ADR-002 (abstraction sources de données) — **à étendre**
- ADR-009 (séparation 4 packages — ici on reste dans `nemeton`)
- spec 005 (Open-Canopy intégration) — complémentaire
- Tolan, J. et al. (2024). *Very High Resolution Canopy Height Maps from RGB Imagery Using Self-Supervised Vision Transformer*. arXiv:2304.07213
- Potapov, P. et al. (2021). *Mapping global forest canopy height through integration of GEDI and Landsat*. Remote Sensing of Environment
- Zanaga, D. et al. (2022). *ESA WorldCover 10 m 2021 v200*
- Brown, C. F. et al. (2022). *Dynamic World, Near real-time global 10 m land use land cover mapping*. Scientific Data
- AWS Open Data Registry — Meta/WRI Canopy Height : https://registry.opendata.aws/dataforgood-fb-forests/
- Microsoft Planetary Computer : https://planetarycomputer.microsoft.com/
