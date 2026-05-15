# Spécification Fonctionnelle : Carte pixel + time series interactive (Suivi sanitaire)

**Version** : 0.1.0 (draft)
**Date**    : 2026-05-15
**Statut**  : Draft — en attente de validation pour `plan.md`
**Auteur**  : Pascal Obstétar (via Claude)
**Cible**   : `nemeton` v0.22.0 + `nemetonshiny` v0.28.0
**Lien**    : extension UI du chantier E6 (Suivi sanitaire, spec 008) — close depuis 2026-04-30 côté cœur, depuis 2026-05-15 côté app

---

## 1. Résumé exécutif

### 1.1 Vision

Compléter l'onglet **Suivi sanitaire** existant (E6.b, phases 3-4-5 livrées) par une **vue cartographique haute résolution** : une carte des indices spectraux (NDVI / NBR) à la résolution native Sentinel-2 (10 m), navigable dans le temps, sur laquelle l'utilisateur peut cliquer un pixel pour afficher sa série temporelle complète.

Aujourd'hui l'onglet propose deux vues :

| Vue existante | Granularité spatiale | Granularité temporelle | Origine |
|---------------|----------------------|------------------------|---------|
| Carte des alertes (E6.b phase 4) | POINT (centroïde cluster FORDEAD) | snapshot (date d'alerte) | hypertable `alert` |
| Plotly NDVI/NBR per-plot (E6.b phase 3, v0.21.11) | POINT (placette ⌀ 30 m) | série complète | hypertable `obs_pixel` |

Aucune ne donne **la dynamique fine intra-parcelle**. Un peuplement de 10 ha contient ~1000 pixels Sentinel-2 ; quand FORDEAD détecte un cluster, le forestier veut comprendre quels pixels ont décroché en premier, à quelle vitesse, et si les pixels voisins suivent.

### 1.2 Principe — la donnée existe déjà

Depuis v0.21.4 (et fonctionnellement depuis v0.21.12), le cache disque `<project>/cache/layers/sentinel2/{scene_id}/{band}.tif` contient les **bandes croppées sur l'AOI** à la résolution native :

- B04 (Red), B08 (NIR) → 10 m
- B12 (SWIR) → 20 m, resampling bilinéaire à 10 m au runtime

Le hypertable `obs_pixel` n'en stocke que la **moyenne par buffer placette** (`exactextractr::exact_extract(..., "mean")`) — perte d'information délibérée pour la time series per-plot, mais le matériau brut est conservé sur disque.

Cette spec expose le matériau brut en API publique cœur, sans changer le modèle de données DB.

### 1.3 Objectifs métier

| Objectif | Métrique de succès |
|----------|-------------------|
| Visualiser le NDVI/NBR pixel à pixel sur une parcelle | Carte leaflet rendue en < 2 s pour AOI ≤ 10 km² |
| Naviguer dans le temps via un slider | Changement de date affiche le layer du stack ≤ 200 ms |
| Comprendre la dynamique locale en un clic | Plotly de la série temporelle (NDVI + NBR superposés) affiché en < 500 ms |
| Pas de re-téléchargement | Toute la vue lit le cache local — zéro HTTP en mode interactif |
| Reproductibilité | Stack indices reconstructible à l'identique depuis (`scene_ids`, `obs_dates`) — donc liable à un rapport Quarto futur |

### 1.4 Hors-scope (cette spec)

- Stockage per-pixel en DB (`obs_pixel_raster` hypertable). Raison : volume non-justifié (~3 M lignes/zone/an, peu de requêtes analytiques anticipées), et le cache disque est déjà la source de vérité.
- Carte FORDEAD raster (`state.tif`) — déjà persisté par le pipeline FORDEAD, exposable séparément si demandé (hors scope spec 010).
- Animation temporelle (timelapse vidéo) — possible en extension future via `terra::animate()`.
- Pré-export multi-bande COG sur disque (forme « .vrt + N-layer COG »). Si la performance live s'avère insuffisante au-delà de ~200 scènes, sera traité dans une spec 011.
- Calcul d'indices autres que NDVI/NBR (NDWI, NDMI, EVI, CRSWIR). Possible extension, voir §6.

---

## 2. Scope

### 2.1 Périmètre cœur (`nemeton`)

Quatre fonctions exportées :

| Fonction | Rôle | Retour |
|----------|------|--------|
| `read_s2_band_raster(cache_dir, scene_id, band)` | Lit **une** bande cachée comme SpatRaster | `terra::SpatRaster` ou `NULL` si manquante |
| `read_s2_band_stack(cache_dir, scenes_df, band)` | Empile **N scènes** d'une bande, ordonnées par date | SpatRaster N-layers (noms = `as.character(obs_date)`) |
| `build_index_stack(cache_dir, scenes_df, index)` | Calcule NDVI ou NBR scène par scène, retourne le stack | SpatRaster N-layers + attributs `index` (`"NDVI"`/`"NBR"`) et `dates` |
| `extract_pixel_timeseries(cache_dir, scenes_df, xy, crs, indices)` | Time series complète à une coordonnée (x, y) | `data.frame(obs_date, index, value)` |

Caractéristiques transverses :

- **Aucune nouvelle dépendance** — réutilise `terra`, `sf`, `cli` déjà en Imports.
- **Aucune migration DB** — pas de schéma touché.
- **API path-agnostique** — `cache_dir` reste passé explicitement, `nemetonshiny` gère le wiring `<project>/cache/layers/sentinel2/`.
- **Tolérance aux trous** — si un scene_dir est absent ou incomplet (e.g. B04 mais pas B08), `build_index_stack` skip silencieusement la scène + warning structuré (pas d'erreur fatale).

### 2.2 Périmètre app (`nemetonshiny`) — pour mémoire (hors repo, hors scope cœur)

Refonte de l'onglet **Suivi sanitaire** : nouveau sous-onglet **« Carte pixel »** à côté de :

- (existant) Carte des alertes
- (existant) Time series per-plot
- **(nouveau)** Carte pixel

Contenu :

- `leaflet` avec **couche raster colorée** (palette divergente `[NDVI: -1 → 1]` ou `[NBR: -1 → 1]`, NA en gris)
- Slider de date (valeurs = `terra::names(stack)`)
- Toggle NDVI ↔ NBR
- Clic sur pixel → modal ou panneau latéral plotly avec NDVI + NBR superposés (couleurs figées comme dans la vue per-plot v0.27.0)
- Réutilise `read_obs_pixel()` pour l'overlay des placettes existantes (rond translucide indiquant les pixels échantillonnés par le plotly per-plot)

L'app **n'écrit aucune ligne de SQL ou de `terra::*`** — tout transite par les 4 fonctions cœur.

### 2.3 Hors scope

Déjà listé §1.4.

---

## 3. User stories

### 3.1 Forestier — découverte d'une zone d'alerte

> En tant que forestier, après que FORDEAD a marqué un cluster en classe 3-forte sur une de mes parcelles, je veux visualiser le NDVI de cette parcelle à la date d'alerte et 6 mois avant, pour confirmer visuellement la chute de signal végétal.

**Workflow attendu** :
1. Sur l'onglet **Suivi sanitaire / Carte alertes**, clic sur un cluster en classe 3-forte (UI existante).
2. L'app pré-renseigne la zone d'AOI focalisée sur l'emprise du cluster.
3. Bascule sur le sous-onglet **Carte pixel** → NDVI à la `trigger_date` du cluster est rendu.
4. Slider permet de reculer dans le temps, animation ou pas-à-pas.

**Critère de succès** : la carte affiche bien des pixels rouges (NDVI bas) au centre du cluster à la date de l'alerte, et des pixels verts (NDVI haut) à T-6 mois.

### 3.2 Forestier — investigation d'un pixel particulier

> En tant que forestier voyant un pixel particulièrement décroché sur la carte, je veux connaître son historique complet (NDVI + NBR sur 2 ans) pour décider si l'anomalie est ancienne ou récente.

**Workflow attendu** :
1. Sur la **Carte pixel**, clic sur un pixel rouge.
2. Panneau latéral / modal s'ouvre avec un plotly NDVI/NBR sur toute la fenêtre d'ingestion.
3. La date courante (du slider) est marquée par une ligne verticale.

**Critère de succès** : le plotly s'affiche en < 500 ms, montre bien la série complète, et permet de comparer NDVI vs NBR (deux courbes superposées, couleurs figées par convention de l'app).

### 3.3 Chercheur / forestier expert — comparaison de pixels

> En tant qu'utilisateur expert, je veux comparer la dynamique de plusieurs pixels (clic successifs) sans perdre les courbes précédentes.

**Workflow attendu** :
1. Clic 1 → courbe ajoutée au plotly (label = `pixel X / Y`).
2. Clic 2 → seconde courbe ajoutée, première préservée.
3. Bouton "Effacer" pour repartir à zéro.

**Critère de succès** : jusqu'à 5 pixels affichés simultanément avec une légende lisible.

**Note** : ce story est **côté app** seulement — l'API cœur retourne toujours la time series d'**un seul** pixel à la fois (composition côté app).

---

## 4. API cœur — contrats détaillés

### 4.1 `read_s2_band_raster(cache_dir, scene_id, band)`

```r
read_s2_band_raster(
  cache_dir,      # character(1) — root du cache S2
  scene_id,       # character(1) — sanitized scene id (e.g. "S2A_MSIL2A_…")
  band            # character(1) — "B04" | "B08" | "B12"
)
```

**Retour** :
- `terra::SpatRaster` (1 layer) si `<cache_dir>/{scene_id}/{band}.tif` existe et est lisible.
- `NULL` si le fichier est absent.
- `stop()` si lecture corrompue (déléguer le diagnostic au caller).

**Garanties** :
- Aucun HTTP. Lecture stricte du fichier local.
- Le SpatRaster a son CRS source (typiquement EPSG:32631 ou 32632 selon la tuile S2), pas reprojeté.

**Cas limite** : `band = "B12"` retourne le raster 20 m natif (pas resampled). Le resampling à 10 m est de la responsabilité de `build_index_stack` quand on combine avec B08.

### 4.2 `read_s2_band_stack(cache_dir, scenes_df, band)`

```r
read_s2_band_stack(
  cache_dir,      # character(1)
  scenes_df,      # data.frame(scene_id chr, obs_date Date) — typiquement
                  # issu de SELECT DISTINCT scene_id, obs_date FROM obs_pixel
                  # WHERE zone_id = ? ORDER BY obs_date
  band            # character(1)
)
```

**Retour** : `terra::SpatRaster` à `N = nrow(scenes_df)` layers (ou moins si certaines scènes absentes), nommé par `as.character(obs_date)`, attribut `time` posé via `terra::time(out) <- scenes_df$obs_date[matched]`.

**Comportement scènes manquantes** :
- Skip silencieux (warning structuré agrégé : `"Skipped N/M scenes (no cached file)"`).
- L'ordre des layers respecte l'ordre temporel des scènes effectivement présentes.

**Comportement extents différents** :
- Toutes les scènes du même tile S2 partagent le même extent post-crop.
- Si on agrège des scènes de tiles différentes (rare, frontière de tile), `terra::merge` les met sur une grille commune. Hors-scope v1 : on assume single-tile par zone (cas dominant, et le `monitoring_zone` est typiquement < 1 tile).

### 4.3 `build_index_stack(cache_dir, scenes_df, index)`

```r
build_index_stack(
  cache_dir,
  scenes_df,
  index = c("NDVI", "NBR")     # match.arg
)
```

**Formules** :
- `NDVI = (B08 - B04) / (B08 + B04)`
- `NBR  = (B08 - B12) / (B08 + B12)` avec B12 resamplé à 10 m par `terra::resample(B12, B08, method = "bilinear")` (cohérent avec `.extract_scene_obs` actuel)

**Retour** : SpatRaster N-layers où chaque layer = indice d'une scène, nommé par `obs_date`, valeurs `[-1, 1]`, NA propagés si une bande source a NA au même pixel.

**Performance attendue** (AOI 5 km² × 100 scènes) :
- Lecture stack : ~2 s (terra ouvre 100 GeoTIFF locaux)
- Calcul indice : ~1 s par scène arithmétique en RAM
- Total : < 5 s pour le premier render, ensuite cached côté caller

### 4.4 `extract_pixel_timeseries(cache_dir, scenes_df, xy, crs, indices)`

```r
extract_pixel_timeseries(
  cache_dir,
  scenes_df,
  xy,                          # numeric(2) — coordonnées du pixel cliqué
  crs = 4326,                  # EPSG d'origine de `xy` (par défaut: WGS84,
                               # convention leaflet)
  indices = c("NDVI", "NBR")
)
```

**Retour** : `data.frame(obs_date, index, value)`, trié par `(obs_date, index)`, longueur ≤ `nrow(scenes_df) × length(indices)`. Pixels en NA (nuage masqué, hors emprise) sont **conservés en NA** (le plotly côté app affiche les trous), pas filtrés.

**Algorithme interne** :
1. `sf::st_transform(xy, crs → EPSG_source)` (CRS du raster S2)
2. Pour chaque scène : ouvre B04/B08 (+ B12 si NBR demandé), `terra::extract(rast, vect_point)`, calcule indice
3. Empile en long data.frame

**Performance attendue** : < 50 ms par scène, donc < 5 s pour 100 scènes × 2 indices. **Si nécessaire**, on peut faire passer en parallèle (`furrr::future_map`) — hors scope v1.

---

## 5. Critères d'acceptation

### 5.1 Côté cœur (cette spec)

- [ ] **A1** — `read_s2_band_raster()` retourne un SpatRaster valide sur un fichier existant
- [ ] **A2** — `read_s2_band_raster()` retourne `NULL` sur fichier absent (pas d'erreur)
- [ ] **A3** — `read_s2_band_stack()` ordonne par `obs_date` croissant
- [ ] **A4** — `read_s2_band_stack()` skip silencieusement les scènes manquantes + émet **un seul** warning agrégé
- [ ] **A5** — `build_index_stack("NDVI")` produit des valeurs ∈ [-1, 1] (NA inclus)
- [ ] **A6** — `build_index_stack("NBR")` resample bien B12 à la grille B08 (test : `terra::ext` et `terra::res` égaux)
- [ ] **A7** — `extract_pixel_timeseries()` accepte xy en 4326, transform interne correct (test contre une coordonnée connue d'un pixel à valeur connue)
- [ ] **A8** — Toutes les fonctions sont exportées + roxygen complet (`@export`, `@examples`, `@seealso`)
- [ ] **A9** — Au moins **10 tests** dans `test-pixel-map.R` (offline) couvrant : happy path, scènes manquantes, CRS mismatch, NA propagation, format de retour stable
- [ ] **A10** — Pas de régression sur `devtools::check()` (0 ERROR / 0 WARNING / 0 NOTE nouveau)

### 5.2 Côté app (pour mémoire — hors repo)

- [ ] **B1** — Sous-onglet **Carte pixel** intégré à `mod_monitoring`
- [ ] **B2** — Slider de date branché sur `terra::names(stack)`
- [ ] **B3** — Toggle NDVI/NBR
- [ ] **B4** — Clic pixel → plotly via `extract_pixel_timeseries()`
- [ ] **B5** — Première render < 2 s pour AOI ≤ 10 km² (mesure shinyloadtest ou manuelle)

---

## 6. Extensions possibles (post-v0.22.0)

Numérotées pour devenir des specs filles si livrées :

- **010.1** — Indices additionnels : NDWI, NDMI, EVI (paramètre `index = "NDWI"` etc. dans `build_index_stack`)
- **010.2** — CRSWIR (indice FORDEAD) — calcul (`B11 - B12 * scale`) — nécessite ajout de B11 au cache
- **010.3** — Animation temporelle (export GIF / MP4 via `terra::animate`)
- **010.4** — Pré-export multi-bande COG sur disque (si perf live insuffisante au-delà de 200 scènes)
- **010.5** — Per-pixel storage en TimescaleDB (`obs_pixel_raster` hypertable) — si analytics SQL deviennent nécessaires (e.g. "find all pixels where NDVI dropped > 0.2 between dates A and B")

---

## 7. Risques et mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|------------|--------|------------|
| Cache incomplet (scènes ratées en ingestion) | Moyenne | Carte trouée temporellement | Skip silencieux + warning agrégé. Côté app, affichage "X scènes manquantes" en pied de carte. |
| Performance dégradée sur grandes AOI (> 10 km²) | Faible (cas cible = parcelle) | UX dégradée | Documenter la limite. Spec 010.4 réserve l'option pré-export COG. |
| Différence d'extent inter-tile S2 (zone à cheval) | Faible (rare en France métropolitaine forestière) | Stack non-uniforme | Hors-scope v1, documenté. |
| B12 resampled diffère de B12 utilisé par `.extract_scene_obs` | Faible | Discordance NBR per-pixel vs per-plot | Réutiliser exactement la même formule `terra::resample(..., method = "bilinear")`. Cf. A6. |
| Click sur pixel hors AOI | Moyenne (bordure) | Time series de NA partout | Comportement défini : retourne data.frame de NA, l'app affiche un toast informatif. |
| Migration future vers Plumber (ADR-001 : > 50 users) | Faible court terme | API doit pouvoir partir derrière un endpoint | Tout est déjà découplé du Shiny via les fonctions exportées. Aucune action immédiate. |

---

## 8. Décisions à valider

| Décision | Default proposé | À confirmer |
|----------|-----------------|-------------|
| **D1** — Stockage per-pixel | NON, lire à la volée depuis le cache | ✅ proposé |
| **D2** — Indices initiaux | NDVI + NBR uniquement | ✅ proposé (extensions §6) |
| **D3** — Resampling B12 | bilinear → grille B08, cohérent avec `.extract_scene_obs` | ✅ proposé |
| **D4** — CRS retour des rasters | natif S2 (32631/32632), pas reprojeté en 4326 | ✅ proposé (reprojection est responsabilité de leaflet/leafem) |
| **D5** — `extract_pixel_timeseries` xy en 4326 par défaut | OUI (convention leaflet) | ✅ proposé |
| **D6** — Comportement scènes manquantes | Skip silencieux + 1 warning agrégé | ✅ proposé |
| **D7** — Cible release | `nemeton@v0.22.0` (minor) | À valider — v0.22.0 alloue ce changement à cette spec (E7 RAG bascule en v0.23.0) |
| **D8** — Ouvrir une spec 011 ou rester en 010 | Rester en 010, extensions en 010.x | ✅ proposé |

---

## 9. Documents liés

- `specs/008-suivi-sanitaire/spec.md` — contexte E6 (Suivi sanitaire)
- `specs/008-suivi-sanitaire/plan.md` — pipeline d'ingestion et hypertable `obs_pixel`
- `R/monitoring.R` (v0.21.12) — code source de l'ingestion S2 et du cache
- `R/read_obs_pixel.R` (v0.21.11) — reader DB plot-aggregated, complémentaire de cette spec
- ADR-001 (Plumber+Vue.js futur) — pertinent si l'API doit migrer derrière un endpoint
- ADR-011 (NDP / Fibonacci) — pas d'impact direct, on reste en NDP 0 (Sentinel-2 publique)

---

## 10. Validation

**Prêt à passer à `plan.md` une fois validé** :
- [ ] Vision (§1) approuvée
- [ ] Scope (§2) approuvé
- [ ] User stories (§3) approuvées
- [ ] API contracts (§4) approuvés
- [ ] Critères d'acceptation cœur (§5.1) approuvés
- [ ] Décisions §8 toutes validées

**Validateur** : Pascal Obstétar
**Date validation** : _à remplir_
