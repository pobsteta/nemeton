# Cadrage L7 — Masque UGF sur les sorties RECONFORT (spec 021)

**Statut** : ✅ **implémenté en `nemeton` v0.98.0** (`read_reconfort_layer()`,
`R/reconfort_manifest.R`, 11 tests) — 2026-06-28. Cadrage initial 2026-06-28.
**Reframé le
2026-06-28** : l'app `nemetonshiny` v0.92.3 applique déjà un `terra::mask`
de clip à l'AOI de zone **en présentation** (cf. §1bis) ; la finalité de L7
devient **rapatrier ce clip dans le cœur** (parité FAST/FORDEAD), pas
« ajouter » le masque. Décision Pascal 2026-06-28 : **maintenir L7 en mode
rapatriement**.
**Décisions** : actées via AskUserQuestion (2026-06-28), cf. §3.
**Cible cœur** : `nemeton` v0.98.0 (minor — changement de comportement par
défaut, parité spec 016).
**Pré-requis** : L2b (pipeline IOTA²-natif, v0.95.0+), manifeste des couches
(`reconfort_layer_manifest()`, v0.97.0 — sous-chantier post-L6) livrés.
**Étend** : spec 016 (« Mask UGF par défaut sur le pipeline raster »,
v0.49.0) — qui ne couvrait que FAST et FORDEAD, RECONFORT n'existant
pas encore. ADR-013 amendement **A6** (cf. `ADR-013-A6-reconfort-zone-mask.md`).

---

## 1. Problème

Les sorties RECONFORT ne sont **pas** masquées au polygone des UGFs, à la
différence de FAST et FORDEAD (spec 016). Vérifié dans le code :

- **Crop** : `.reconfort_oso_broadleaf_mask()` et
  `.reconfort_crop_scenes_to_aoi()` (`R/reconfort_crop.R`) découpent à la
  **bbox de l'AOI + 3 km de buffer** (`.reconfort_aoi_window()` → `st_bbox`),
  jamais au polygone. Emprise rectangulaire.
- **Masque** : `mask <- terra::ifel(crop == 16, 1, 0)` — masque d'occupation
  du sol **OSO feuillus** (classe 16) découpé à la bbox. C'est un masque de
  *land-cover national*, pas la limite de gestion.
- **Postprocess** : `reconfort_postprocess.R` extrait les centroïdes de
  clusters sans aucun `st_intersection`/`st_crop` avec la géométrie de zone.

**Conséquence** (identique aux 3 symptômes de spec 016 §1) : un pixel feuillu
situé **dans la bbox+buffer mais hors du polygone UGF** (forêt voisine non
gérée, lisière, bosquet) est quand même classé/scoré et peut générer une
alerte. Le score continu, les classes, la probabilité et les centroïdes
s'étendent au rectangle, pas à la forme réelle des UGFs.

Rappel chiffré spec 016 (villards) : union des 6 UGFs = **77 ha**, soit
**29 %** de la bbox englobante (264 ha). ~70 % des pixels affichés sont
hors gestion.

## 1bis. État au 2026-06-28 — le clip est déjà fait, mais en présentation

`nemetonshiny` **v0.92.3** (commit `7e7db429`) clippe déjà les rasters
RECONFORT à l'AOI de la zone de suivi sélectionnée via `terra::mask`, **côté
app**. Comme `monitoring_zone.zone_wkt = st_union(project$indicators_sf)`
(l'union des UGFs, spec 016 §1), ce clip d'affichage **couvre déjà le besoin
fonctionnel** de L7.

**Mais** c'est une opération spatiale (`terra::mask`) dans la couche de
présentation — exactement ce que FAST et FORDEAD **évitent** en confiant le
masque à leur reader cœur (`read_fast_alert_raster` / `read_fordead_dieback_mask`,
spec 016). RECONFORT est donc le seul des trois à porter cette logique dans
l'app.

**Finalité reframée de L7** : ne plus *ajouter* le masque (l'app le fait
déjà visuellement), mais **rapatrier le `terra::mask` de l'app vers un reader
cœur** `read_reconfort_layer(apply_zone_mask = TRUE)`. Bénéfices : parité
stricte des 3 pipelines, sémantique spatiale hors de la présentation (règles
strictes §1-3 / ADR-009), masque testable côté cœur. À terme, l'app
v0.93.x+ consomme le reader et **retire son `terra::mask`** local.

## 2. Vision cible

**Par défaut**, les couches raster RECONFORT (score continu, classification,
probabilité) sont **masquées au polygone des UGFs** : pixels hors polygone =
NA. Comportement strictement aligné sur spec 016 / FAST / FORDEAD.

- Le masque est appliqué **au read**, pas au write : les `.tif` produits par
  IOTA² restent à l'emprise large (bbox + OSO feuillus) ; le masque UGF est
  ré-appliqué à la lecture par un reader cœur dédié.
- Réutilise l'infrastructure spec 016 **sans nouveau code de masquage** :
  `.apply_zone_mask(raster, zone_polygon)` (`R/zone_aoi.R`) +
  `.get_zone_aoi(con, zone_id)` (résout `monitoring_zone.zone_wkt`, EPSG:2154).
- Opt-out pour les cas avancés (debug, analyse comparative) :
  `apply_zone_mask = FALSE`.

## 3. Décisions cadrées (AskUserQuestion 2026-06-28)

| # | Question | Décision |
|---|----------|----------|
| D1 | **Nommage** de l'option | **`apply_zone_mask`** (parité FAST `read_fast_alert_raster` / FORDEAD `read_fordead_dieback_mask`, spec 016). Pas `clip_to_aoi`. Défaut `TRUE`. |
| D2 | **Point d'application** | **Read-time** (parité spec 016 « masque au read, pas au write »). Nouveau reader cœur `read_reconfort_layer()`. Les `.tif` disque restent inchangés. |
| D3 | **Centroïdes d'alertes** | ~~Parité : non clippés~~ → **RÉVISÉE le 2026-06-29** (cf. §3bis). Un run réel a montré que le vecteur d'alertes RECONFORT déborde des UGFs (centroïdes issus du raster masqué **OSO-feuillus**, pas UGF). Décision : **clipper au read-time** via `filter_alerts_to_zone()`, **étendu aux 3 pipelines**. Livré en v0.99.0. |

## 3bis. Révision D3 (2026-06-29) — clip aussi le vecteur d'alertes

**Constat run réel** (zone 5, 1336 alertes) : le **score raster** est bien
clippé à l'UGF (v0.98.0), **mais le vecteur d'alertes déborde largement**. La
cause invalide l'argument initial de D3 (« centroïdes issus de rasters
UGF-masqués → tombent dans l'UGF ») : le postprocess
(`reconfort_postprocess.R`) extrait les centroïdes du
`Final_Classif_masked_<year>.tif`, masqué par **OSO feuillus** (occupation du
sol) et **non** par l'UGF → les clusters couvrent tous les feuillus de la
bbox + 3 km. (FORDEAD a le même défaut latent, moins visible.)

**Décision révisée** (AskUserQuestion 2026-06-29) :
- Clip du vecteur d'alertes au polygone UGF, **au read-time** (parité
  `read_reconfort_layer`, principe « masque au read, pas au write » : la table
  `alert` reste complète, seul l'affichage filtre).
- **Helper unique partagé par les 3 pipelines** : `filter_alerts_to_zone()`
  (le filtre `sf` POINT est identique pour RECONFORT/FORDEAD/FAST → vraie
  parité, pas de duplication). Interne `.filter_alerts_to_zone()` miroir de
  `.apply_zone_mask()`.
- Livré en **`nemeton` v0.99.0**. Côté app v0.93.x+ : passer la couche
  d'alertes (RECONFORT **et** FORDEAD) par `filter_alerts_to_zone()` avant
  rendu.

## 4. API cible

### 4.1 Nouveau reader cœur (exporté)

```r
read_reconfort_layer(layer, con = NULL, zone_id = NULL,
                     apply_zone_mask = TRUE, mask_polygon = NULL)
```

- `layer` : un chemin de raster RECONFORT (`.tif`) **ou** une ligne du
  manifeste `reconfort_layer_manifest()` de `type == "raster"` (on lit
  `layer$path`). Les lignes `type == "vector"` (alertes) sont rejetées
  (le vecteur n'est pas masqué — D3).
- Résout le polygone UGF : `mask_polygon` explicite, sinon
  `.get_zone_aoi(con, zone_id)` si `con`+`zone_id` fournis, sinon (rien) →
  pas de masque, avertissement `cli::cli_warn` (best-effort, parité spec 016).
- Retourne un `terra::SpatRaster` : si `apply_zone_mask`, pixels hors UGF = NA
  via `.apply_zone_mask()` ; sinon le raster brut.

Signature et garde-fous calqués sur `read_fast_alert_raster()`
(`R/fast_alert_raster.R:156`) et `read_fordead_dieback_mask()`
(`R/fordead_mask.R:62`).

### 4.2 Manifeste — inchangé

`reconfort_layer_manifest()` (sous-chantier post-L6, v0.97.0) continue de renvoyer les **chemins**
bruts. Il n'embarque ni géométrie ni logique de masquage (la sémantique de
masquage est portée par le reader, pas par le manifeste). Le consommateur
(`nemetonshiny`) itère le manifeste et lit **chaque couche raster cochée via
`read_reconfort_layer()`**, exactement comme il lit FAST/FORDEAD via leurs
readers respectifs.

### 4.3 `run_reconfort_dieback()` — inchangé

Le pipeline n'est pas modifié (le masque est au read). Aucune régression sur
les `.tif` produits, le score, la table `alert`. `con`+`zone_id` sont déjà des
arguments de `run_reconfort_dieback()` → le reader peut les réutiliser.

## 5. Périmètre & non-objectifs

**Dans le périmètre** :
- `read_reconfort_layer()` (nouvelle fonction exportée + Rd + tests).
- Réutilisation de `.apply_zone_mask()` / `.get_zone_aoi()` (aucune
  duplication).
- Tests unitaires : masque appliqué (pixels hors polygone = NA), opt-out
  `apply_zone_mask = FALSE`, repli sans `con`/`zone_id` (warn + raster brut),
  rejet d'une ligne `type == "vector"`, acceptation chemin OU ligne manifeste.

**Hors périmètre** :
- Clip des centroïdes d'alertes (D3 — parité, non).
- Masque au write / régénération des `.tif` (D2 — read-time).
- Toute UI : le câblage `nemetonshiny` (lecture des couches via le reader)
  fait l'objet d'un brief séparé, repo `nemetonshiny`.

## 6. Plan d'implémentation

1. `R/reconfort_manifest.R` (ou nouveau `R/reconfort_reader.R`) :
   `read_reconfort_layer()` ; réutilise `.apply_zone_mask` + `.get_zone_aoi`.
2. `NAMESPACE` : `export(read_reconfort_layer)` (édition manuelle, +
   `man/read_reconfort_layer.Rd` à la main — pas de `devtools::document()`).
3. `tests/testthat/test-reconfort-manifest.R` (ou `-reader.R`) : cas du §5,
   avec un petit raster terra + un polygone sf de test (skip_if_not_installed).
4. Release **minor v0.98.0** (`feat:`) : DESCRIPTION + NEWS + CITATION +
   CHANGELOG cohérents, PLAN.md (journal + statut), PR → merge → tag.
5. Brief Shiny (app v0.93.x+) : `nemetonshiny` lit chaque couche raster du
   manifeste via `read_reconfort_layer(layer, con, zone_id)` et **retire son
   `terra::mask` local** (v0.92.3) — le clip UGF passe désormais par le reader
   cœur. Curseur d'opacité, toggles et couche UGF overlay inchangés.

## 7. Risques & garde-fous

- **CRS** : `.apply_zone_mask` reprojette déjà le polygone vers le CRS du
  raster (`sf::st_transform(zone_polygon, terra::crs(raster))`). Les rasters
  RECONFORT sont en EPSG:2154, `.get_zone_aoi` renvoie EPSG:2154 → no-op.
- **Polygone absent** (zone sans `zone_wkt`) : best-effort, raster brut +
  `cli_warn`, jamais d'abort (parité spec 016).
- **Changement de comportement par défaut** (`TRUE`) : documenté en NEWS comme
  parité spec 016 ; opt-out explicite pour l'ancien comportement rectangulaire.
