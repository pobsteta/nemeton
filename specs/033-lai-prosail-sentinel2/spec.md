# Spec 033 — Repli LAI Sentinel-2 / PROSAIL (canopée NDP 0, sans LiDAR)

**Version** : 0.1.0
**Date**    : 2026-07-04
**Statut**  : **Implémentée (increments 1+2, v0.128.0/v0.129.0, 2026-07-04)** —
D1–D6 validées par Pascal. Inc 1 : `lai_sentinel2()` (precomputed + réducteur p90
testés CI ; train PROSAIL vérifié), injection `pai` (D2), flag `lai_ml`. **Inc 2**
(v0.129.0) : **assemblage automatique MUSCATE** stateless (D4, via
`.get_s2_band_raster`, bandes B4/B5/B8 exposées) + **modèle pré-entraîné
versionné** `inst/extdata/prosail_lai_Sentinel_2A_B4-B5-B8.rds` (D3, chargé sans
ré-entraîner — sérialisation vérifiée + prédiction testée CI). **D5** : brief app
provenance canopée rédigé (`brief-nemetonshiny.md`).
**Correctif D4 (v0.134.1, 2026-07-05)** : l'assemblage MUSCATE était cassé —
`.get_s2_band_raster()` renvoie un **SpatRaster** mais le code lisait `g$path`
(→ crash silencieux, assemblage toujours `NULL`) ; en plus il ne configurait
pas GDAL S3 (`theia_configure_s3`) ni ne rééchantillonnait les bandes de
résolution mixte (B05 20 m vs B04/B08 10 m). Corrigé + testé CI (mock
search/S3/band). **Recherche MUSCATE validée sur données réelles** (22 scènes
Vercors, hrefs `/vsis3/`).
**Bout-en-bout validé (v0.135.0, 2026-07-05)** — MUSCATE→LAI **sur données
réelles** (Vercors, clé Theia) : LAI médian 2.33, max 7.2, 457×408 px. A
nécessité de découvrir le **vrai modèle d'accès THEIA** (SDK Python
`teledetection`) : les COG MESO@UM ne se lisent PAS en `/vsis3/` direct — il
faut des **URLs pré-signées** par la gateway `signing.stac.teledetection.fr`
(clés `access-key`/`secret-key`, modèle SAS). Nouveau `theia_sign_urls()` +
`.theia_signed_read()`. 3 bugs additionnels corrigés dans la chaîne :
`.get_s2_band_raster` veut un `sf` (pas un SpatVector) ; `band_names` de
`apply_prosail_inversion` = bandes réelles du raster (3, pas les 10 S2) ;
récupération du `_lai.tif[f]` sur disque + tolérance à l'erreur post-écriture.
**Reste** : badge provenance app ; FORMS (`load_theia_source`) à basculer sur le
même flux de signature (idem `/vsis3/` → gateway).
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` (feat mineur, API rétro-compatible).
**Cible app**  : aucune en v1 (repli automatique, invisible côté UI) — brief
éventuel si l'on veut exposer la provenance de la canopée (LiDAR vs satellite).
**Liens** : moteurs reGénération spec 027 (`regen_sensibilite` microclimf,
`regen_bilan_hydrique` biljouR, `pai_depuis_nuage`) ; réutilise le sous-système
STAC Sentinel-2 (specs 013/017) et la **source MUSCATE/Theia** de la spec 029
(`stac_search_s2(source = "muscate")`, `read_s2_band_stack`) ; s'inscrit dans
ADR-007 (pipeline NDP) et ADR-011 amendé (flags `augmented`).

> **Implication ADR (à acter dans `platform_nemeton` par Pascal)** :
> l'inversion **PROSAIL** (transfert radiatif) est une **méthode nouvelle** de
> restitution de variable biophysique. Contrairement à la spec 029 (simple
> backend STAC de plus), on introduit ici un **estimateur** dans le pipeline
> NDP. → **un ADR est justifié** (« restitution LAI par inversion PROSAIL comme
> repli canopée NDP 0 »), même si le paquet `prosail` est déjà déclaré.

---

## 1. Objectif

Fournir, **quand le LiDAR HD est absent (NDP 0)**, un **raster de LAI** (indice
de surface foliaire) dérivé de **Sentinel-2 L2A** par **inversion PROSAIL**, pour
alimenter en repli les entrées « canopée » des moteurs reGénération :

- **`regen_bilan_hydrique()` (biljouR)** — argument `lai_max` : **ajustement
  direct** (le LAI est *la* variable attendue par BILJOU).
- **`regen_sensibilite()` (microclimf)** — entrée `pai` : **proxy dégradé** (le
  LAI ≈ surface foliaire ; le PAI inclut le bois — voir §2).

Le repli est **opt-in / automatique en dernier recours** : NDP ≥ 1 (LiDAR HD)
conserve **toujours** le PAI structural de `pai_depuis_nuage()`.

## 2. Contexte : pourquoi ce n'est PAS le PAI LiDAR

| | PAI LiDAR (`pai_depuis_nuage`) | LAI Sentinel-2/PROSAIL (cette spec) |
|---|---|---|
| Grandeur | **Plant** Area Index (feuilles **+** branches) | **Leaf** Area Index (feuilles seules) |
| Résolution | ~2 m (structure 3D) | 10–20 m (2D, sommet de canopée) |
| Temporalité | instantanée (millésime LiDAR) | saisonnière (composite d'été) |
| Méthode | fraction de trouée + Beer-Lambert | inversion transfert radiatif (PROSAIL) |
| NDP | 1+ | **0** (repli) |

GEODES/Theia **ne distribue pas** de PAI structural ; il donne des réflectances
S2 L2A (→ LAI par inversion) et un LAI GEOV2-AVHRR ~1 km (trop grossier). Ce
repli est donc **un LAI, pas un substitut fidèle du PAI** : à réserver au NDP 0.

## 3. Source de données (à confirmer par smoke réel)

- **Sentinel-2 L2A MUSCATE/Theia** via GEODES, **déjà câblé** (spec 029) :
  `stac_search_s2(aoi, start, end, source = "muscate")` →
  `read_s2_band_stack()` pour les bandes de réflectance FRE.
- Bandes nécessaires à PROSAIL S2 : B03, B04, B05, B06, B07, B08, B8A, B11, B12
  (config `prosail::get_s2_geometry_from_THEIA` + bandes 2A).
- **Géométrie soleil/visée** : `prosail::get_s2_geometry_from_THEIA()` (lit les
  angles depuis les métadonnées MUSCATE) — **à vérifier** que nos assets MUSCATE
  exposent bien ces angles (sinon fallback `get_s2_geometry`).
- **Masque nuages/ombres** : masque MUSCATE (CLM/MG2) — plomberie à préciser
  (D4).

## 4. Méthode : inversion hybride PROSAIL (`prosail` 3.0.0)

Workflow **hybride** (réseau de neurones entraîné sur simulations PROSAIL, puis
appliqué aux réflectances) :

1. `prosail::prosail_hybrid_train()` — entraîne le modèle pour la **config
   spectrale S2** et la géométrie de la scène (LAI parmi les variables via
   `WhichParameters2Invert`).
2. `prosail::prosail_hybrid_apply()` (ou `apply_prosail_inversion`) — applique
   aux réflectances S2 masquées → **raster LAI** sur l'emprise.
3. **Composite estival** (D1) : réduction temporelle des scènes de la saison de
   végétation → `lai_max` par pixel (ex. maximum ou p90 de la série JJA).

Dépendances lourdes en **Suggests + Remotes** (`prosail` = `jbferet/prosail`),
gardées par `requireNamespace` ; dégradation propre → `NULL` (pas de scène,
prosail absent, trop de nuages).

## 5. Sémantique & points d'injection

- **Nouvelle fonction cœur** `lai_sentinel2(aoi, start, end, reducer = "p90",
  source = "muscate", precomputed = NULL, ...)` → `SpatRaster` LAI sur l'AOI
  (ou `NULL`). Chemin `precomputed` pur (comme les moteurs) : accepte un raster
  LAI déjà calculé.
- **biljouR** : `regen_bilan_hydrique(lai_max = ...)` accepte déjà un `lai_max` ;
  on documente qu'un LAI issu de `lai_sentinel2()` (agrégé par unité via
  `exactextractr`) est une source valide de `lai_max` en NDP 0.
- **microclimf** : `regen_sensibilite()` calcule aujourd'hui le PAI en interne.
  → **ajouter un argument `pai` optionnel** : si fourni (raster LAI de repli),
  il court-circuite `pai_depuis_nuage()` ; sinon comportement inchangé (LiDAR).
- **Flag NDP** : ajouter la valeur `"lai_ml"` au vecteur `augmented` de
  `detect_ndp()` (ADR-011 amendé) — le **niveau NDP reste 0**, la provenance ML
  est tracée séparément (comme `"height_ml"`).

## 6. Décisions à trancher

- **D1 — Réduction temporelle du LAI** : maximum estival vs **p90** (robuste au
  bruit/résidus nuageux) vs médiane JJA. *Proposé : p90.*
- **D2 — Périmètre d'usage** : (a) `lai_max` biljouR **seul** (usage propre,
  LAI = bonne variable), ou (b) **aussi** `pai` microclimf (proxy dégradé).
  *Proposé : livrer (a) d'abord, (b) derrière un flag explicite + avertissement.*
- **D3 — Modèle PROSAIL** : entraîner à chaque appel vs **embarquer un NN
  pré-entraîné** S2 dans `inst/extdata/`. *Proposé : pré-entraîné versionné
  (repro + rapidité), ré-entraînable en option.*
- **D4 — Masquage/compositing** : source du masque nuages MUSCATE, seuil de
  couverture nuageuse, gap-filling. À câbler sur l'existant S2.
- **D5 — Provenance côté app** : exposer « canopée : LiDAR HD / satellite » dans
  l'UI reGénération, ou repli silencieux ? *Proposé : silencieux v1, brief app
  ultérieur.*
- **D6 — Déclencheur du repli** : automatique quand `mnh/las` absents, ou opt-in
  explicite (`lai_source = "auto"|"lidar"|"sentinel2"`) ? *Proposé : `"auto"`.*

## 7. Changements cœur (`nemeton`)

- `R/lai_prosail.R` : `lai_sentinel2()` (+ helpers d'inversion, gardés
  `requireNamespace`), chemin `precomputed`.
- `R/regen_engines.R` : argument `pai` optionnel dans `regen_sensibilite()` ;
  doc `lai_max` de `regen_bilan_hydrique()` (source satellite).
- `R/ndp.R` : valeur `"lai_ml"` dans `augmented` (+ détection depuis un attribut
  `lai_source`).
- `inst/datasources/FR.json` : déclarer la provenance LAI S2 (licence Theia).
- `inst/extdata/` : NN PROSAIL pré-entraîné S2 (si D3 = pré-entraîné).
- Tests : plomberie (`precomputed`, dégradation `NULL`, agrégation par unité,
  flag `augmented`) — l'inversion réelle n'est pas jouable en CI (scènes S2 +
  prosail) ; validée par Pascal sur données réelles.

## 8. Critères d'acceptation

1. `lai_sentinel2(aoi, ...)` renvoie un `SpatRaster` LAI sur l'AOI, ou `NULL` en
   dégradation propre (pas de scène / prosail absent / nuages).
2. `regen_bilan_hydrique()` tourne en NDP 0 avec `lai_max` issu du repli (smoke
   réel sur une UGF sans LiDAR).
3. `regen_sensibilite(pai = <lai_repli>)` court-circuite le LiDAR sans régression
   du chemin LiDAR quand `pai` est absent.
4. `detect_ndp()` remonte `augmented` contenant `"lai_ml"` quand le repli est
   actif ; **niveau NDP inchangé (0)**.
5. Rétrocompatibilité totale : NDP ≥ 1 utilise **toujours** `pai_depuis_nuage()`.

## 9. Risques / réserves

- **R1** — LAI ≠ PAI : biais systématique sur microclimf (bois ignoré, sommet de
  canopée). À documenter ; réserver au NDP 0 (D2).
- **R2** — Saturation du LAI S2 en forêt dense (LAI > 5–6 mal restitué) : borne
  et avertissement.
- **R3** — Disponibilité/qualité MUSCATE (nuages, angles de visée dans les
  métadonnées) : plomberie géométrie à confirmer (§3).
- **R4** — Coût inversion (entraînement NN) : traité par D3 (modèle embarqué).
- **R5** — Cohérence temporelle : LAI estival vs millésime microclimf/années
  E-OBS — le repli fige un composite, pas une série ; acceptable en NDP 0.

## 10. Hors périmètre

- Toute restitution de **structure 3D** (hauteur, PAI vertical) depuis le
  satellite — reste du ressort du LiDAR HD / Open-Canopy (spec 005).
- L'exposition UI de la provenance canopée (brief app séparé si D5 le décide).
- Les LAI grossiers GEOV2-AVHRR (~1 km) : écartés (résolution inadaptée).
