# Spec 019 — Indice NDMI dans le suivi sanitaire FAST

**Version** : 0.1.0
**Date**    : 2026-06-03
**Statut**  : Validée (décisions D1-D3 actées) — en implémentation.
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton@v0.64.0` (minor — nouvel index, API rétro-compatible).
**Cible app**  : `nemetonshiny` (option NDMI dans le sélecteur FAST).
**Lien**    : étend le sous-système d'alerte FAST (spec 013 + spec 017).

---

## 1. Objectif

Ajouter le **NDMI** (Normalized Difference Moisture Index) comme nouvel
index calculable du suivi sanitaire **FAST** (surveillance rapide), à
côté de NDVI et NBR.

```
NDMI = (B08 − B11) / (B08 + B11)          (NIR − SWIR1)
```

Le NDMI mesure l'**humidité de la végétation** : il **baisse** sous stress
hydrique, donc il s'intègre tel quel dans la logique d'alerte FAST
existante (déclin sous seuil = alerte, modes `count` / `rolling`,
classification 0-4 par quartiles).

## 2. Faisabilité

- **B11 (SWIR1, 20 m) est déjà recherchée sur STAC** (`.S2_STAC_BANDS`
  la contient) → aucune modification de la requête STAC.
- Il manque uniquement : (a) mettre B11 en cache disque, (b) l'autoriser
  dans les lecteurs de bande, (c) ajouter la formule NDMI, (d) propager la
  valeur `"NDMI"` dans les `match.arg(index, …)`.

## 3. Décisions actées

| # | Décision | Choix |
|---|----------|-------|
| **D1** | Index par défaut | **Défaut reste NDVI.** NDMI est ajouté et listé **en premier** dans le sélecteur app, mais l'index calculé par défaut (signatures `index = c("NDVI","NBR","NDMI")`, premier = NDVI) reste NDVI. Rétro-compatible. |
| **D2** | Seuil NDMI | **Adaptatif (quantiles).** La classification 0-4 par quartiles des pixels en déclin (déjà en place dans `compute_fast_alert_mask`) s'applique à NDMI sans changement. Le seuil par pixel de `read_fast_alert_raster` reprend le défaut générique non-NDVI (0.30, comme NBR) — aucune constante NDMI nouvelle, zéro calibration. |
| **D3** | Cache B11 | **Systématique** (futurs ingests). B11 est mise en cache à chaque ingestion S2, **en best-effort** (une scène sans href B11 est ignorée sans faire échouer l'ingestion NDVI/NBR). Les scènes déjà en cache nécessitent une ré-ingestion (`skip_cached = FALSE`) pour obtenir B11. |

## 4. Changements cœur (`nemeton`)

| # | Fichier | Changement |
|---|---------|-----------|
| A1 | `R/pixel-map.R` | `read_s2_band_raster()` / `read_s2_band_stack()` : `match.arg(band, c("B04","B08","B12","B11"))` + doc |
| A2 | `R/pixel-map.R` | `build_index_stack()` : `index = c("NDVI","NBR","NDMI")` ; `bands_needed` NDMI = `c("B08","B11")` ; formule `(B08 − B11_10m)/(B08 + B11_10m)`, **resample B11 20 m → 10 m bilinéaire** comme B12 |
| A3 | `R/pixel-map.R` | `extract_pixel_timeseries()` : `indices` accepte `"NDMI"` ; B11 échantillonnée à 20 m natif (cohérent avec B12) |
| A4 | `R/monitoring.R` | `.s2_required_bands()` : `NDMI → B08, B11` |
| A5 | `R/monitoring.R` | `.cache_scene_bands()` : nouvel argument `optional_bands` caché en **best-effort** (tryCatch par bande) |
| A6 | `R/monitoring.R` | `ingest_sentinel2_timeseries()` : `bands` accepte `"NDMI"` ; **B11 systématiquement** ajoutée en bande optionnelle (D3) ; doc |
| A7 | `R/fast_alert_raster.R`, `R/fast_alert_mask.R` | `index = c("NDVI","NBR","NDMI")` (défaut NDVI) ; le hash D6 inclut déjà `index` → COG `fast_NDMI_<mode>_<hash>.tif`, pas de collision |
| A8 | tests | formule NDMI, bandes requises, best-effort B11, FAST raster+mask NDMI |
| A9 | release | `feat:` minor `0.63.0 → 0.64.0` ; NEWS/CHANGELOG/CITATION/PLAN ; `document()` |

**Best-effort B11 (A5/A6)** : `.scene_cogs_cached()` garde la décision de
skip sur les bandes **strictement requises** par les index demandés (B11
n'y figure que si NDMI est demandé). B11 systématique est cachée pour les
scènes effectivement traitées ; une scène sans href B11 est ignorée (pas
d'abort), conformément au comportement tolérant des bandes FORDEAD-extra.

## 5. Changements app (`nemetonshiny`) — hors repo cœur

- Sélecteur d'index FAST : ajouter `NDMI`, **listé en premier** (`choices = c("NDMI","NDVI","NBR")`), **défaut NDVI** conservé.
- i18n FR/EN : libellé `index_ndmi`, tooltip (« humidité / stress hydrique »), étiquette de légende, titre de couche.
- Transmettre `index = "NDMI"` à `read_fast_alert_raster()` / `compute_fast_alert_mask()` (déjà câblé pour NDVI/NBR).
- Pré-chauffage : inclure NDMI dans les combinaisons `index × mode` si activé.
- Palette/échelle 0-4 inchangée.

## 6. Compatibilité

- Caches NDVI/NBR existants **intacts** (hash keyé par index).
- Pour NDMI sur scènes historiques déjà cachées : **ré-ingérer** la zone
  (`skip_cached = FALSE`) pour peupler B11.
- Stockage : +1 COG 20 m par scène nouvellement ingérée.

## 7. Critères d'acceptation (cœur)

- [ ] `build_index_stack(index = "NDMI")` calcule `(B08−B11)/(B08+B11)` (B11 resamplé 10 m).
- [ ] `read_s2_band_raster(..., "B11")` lit la bande cachée.
- [ ] `.s2_required_bands(c("NDMI"))` == `c("B08","B11")`.
- [ ] `ingest_sentinel2_timeseries()` cache B11 systématiquement, tolère son absence.
- [ ] `read_fast_alert_raster(index = "NDMI")` produit un COG `fast_NDMI_*`.
- [ ] Défaut inchangé : `read_fast_alert_raster()` sans `index` → NDVI.
- [ ] `devtools::check()` clean.

## 8. Hors scope

- Calibration fine d'un seuil NDMI dédié (D2 = adaptatif).
- UI `nemetonshiny` (brief séparé).
- Bandes additionnelles (B8A, etc.) pour d'autres indices.
