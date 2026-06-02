# Spec 017 — `read_fast_alert_raster` : indicateur unique, classes quartiles, énumération cache, perf

**Statut** : **CLOSE 2026-06-02**. **Livré** : sémantique D1-D3/D5 → **v0.55.0** ; persistance D6 → **v0.56.0** ; parallélisation D4 → **v0.57.0**. Toutes les décisions implémentées.
**Démarré** : 2026-05-31.
**Cible cœur** : v0.55.0 (sémantique) puis v0.56.0 (perf parallèle), ou combinées.
**Précédents** : spec 010 (carte pixel / `build_index_stack` v0.22.0), spec 013 (FAST alert raster v0.46.0), spec 014 (validation sampling v0.47.0), spec 016 (mask UGF v0.49.0), correctif union+pad multi-tuiles (v0.52.1).

## 1. Problème

Le **Diagnostic FAST** = la **carte d'alertes raster per-pixel**
(`read_fast_alert_raster()`), pas l'ingestion per-placette. Quatre
défauts :

1. **Lenteur** (« plusieurs minutes » sur villards, cache plein). Profil
   empirique (cache villards, sans réseau) : la phase raster domine
   (~17-24 s / 120 scènes wide, croît avec la charge ; ×2 tuiles en
   réel) et boucle **séquentiellement** sur les scènes via
   `build_index_stack()`. La DB n'est PAS le goulet (le diagnostic
   raster n'insère rien — confusion du brief initial entre « 2.4 M
   pixels » et « 2.4 M lignes DB »).
2. **Couplage aux placettes** : `read_fast_alert_raster()` énumère ses
   scènes via `read_obs_pixel(con, zone_id)` — donc dépend d'`obs_pixel`,
   donc des placettes. Or les placettes de suivi sont **construites
   après** le diagnostic. Ce couplage a aussi causé le FK `plot_id` vu
   en prod (le bouton app lance l'ingest per-placette).
3. **Indicateur mélangé** : la carte combine `NDVI < seuil OU NBR <
   seuil`. L'utilisateur veut **un seul indicateur au choix**.
4. **Classes à seuils fixes arbitraires** (`count = c(0,2,5,10,Inf)`,
   `rolling = c(0,0.05,0.10,0.20,Inf)`) — peu lisibles selon la zone.

## 2. Décisions (validées 2026-05-31)

- **D1 — Indicateur unique.** Nouveau paramètre `index = c("NDVI",
  "NBR")`, **défaut `NDVI`**. Le mode « OU des deux » est **supprimé**.
  La carte est toujours mono-indicateur. Bonus perf : une seule pile
  (NDVI _ou_ NBR) au lieu de deux → ~÷2 du travail raster.
- **D2 — Classes en quartiles.** La discrétisation 0-4
  (`compute_fast_alert_mask()`) devient adaptative pour **count ET
  rolling** : **classe 0 = pas d'alerte (valeur 0)** ; **classes 1-4 =
  quartiles des valeurs strictement positives** (bornes `c(0, q25, q50,
  q75, Inf)` où `qN = quantile(valeurs[valeurs>0], N)`). `breaks` reste
  surchargeable explicitement.
- **D3 — Énumération depuis le cache COG.** Les scènes sont listées
  depuis `cache_dir` (répertoires de scènes possédant les bandes
  requises pour l'`index` choisi), filtrées par `[date_from, date_to]`
  (date parsée du `scene_id`). Plus aucun appel à `read_obs_pixel()` /
  `obs_pixel` pour l'énumération → diagnostic **indépendant des
  placettes**. Pas de réseau.
- **D4 — Parallélisation opt-in.** Paramètre `parallel = FALSE`. Quand
  `TRUE` et `furrr` dispo, la phase raster (calcul des piles par tuile)
  tourne en `furrr::future_map()` ; sinon `lapply` séquentiel. `furrr`
  en **Suggests**. Le process principal reste seul à écrire (aucune DB
  ici de toute façon).
- **D5 — `con` / `zone_id` conservés pour le masque AOI seulement.** Ils
  ne servent plus à l'énumération mais restent utilisés par
  `.get_zone_aoi()` (masque UGF spec 016). `zone_wkt` est indépendant
  des placettes. `mask_polygon` reste passable directement.
- **D6 — Persistance du raster résultat (content-addressed).** Le raster
  continu est coûteux (minutes au 1er calcul) et re-consulté souvent
  (navigation app, re-rendu, reclassement quartiles). On le persiste en
  **COG** (DEFLATE) sous `<mask_cache_dir>/zone_<id>/`, **adressé par
  contenu** :
  ```
  fast_alert_<index>_<mode>_<hash>.tif
  hash = digest( scene_ids triés + index + threshold + mode +
                 window_days + date_from + date_to + zone_wkt )
  ```
  - **Lecture** : si le COG du hash courant existe → renvoyé
    instantanément (zéro recalcul). Sinon → calcul (parallèle) +
    écriture.
  - **Auto-invalidation** : une nouvelle scène ingérée dans le cache, ou
    tout changement de paramètre, change le hash → recalcul. Pas de
    logique de *staleness* fragile (le contenu EST la clé).
  - **GC** : garder les N derniers `.tif` par zone (purge par mtime).
  - **Gain** : le 1er diagnostic reste lent (mitigé par D4), les suivants
    sont **instantanés** ; les **quartiles se recalculent depuis le COG
    persisté** sans recalcul raster. Découple « calculer » d'« afficher ».
  - `digest` (ou hash maison) en **Suggests**. Nouveau paramètre
    `cache_result = TRUE` (opt-out possible).

## 3. Changements d'API

### `read_fast_alert_raster()`
```r
read_fast_alert_raster(
  con, zone_id,
  index           = c("NDVI", "NBR"),   # NOUVEAU (D1), défaut NDVI
  threshold       = NULL,               # seuil de l'indice choisi ;
                                        #   défaut 0.40 (NDVI) / 0.30 (NBR)
  date_from, date_to,
  mode            = c("count", "rolling"),
  window_days     = 30L,
  cache_dir,
  parallel        = FALSE,              # NOUVEAU (D4)
  apply_zone_mask = TRUE,
  mask_polygon    = NULL
)
```
- **Supprimés** : `threshold_ndvi`, `threshold_nbr` → remplacés par un
  seul `threshold` (défaut dépendant de `index`).
- Scènes : `.enumerate_cache_scenes(cache_dir, index, date_from,
  date_to)` au lieu de `read_obs_pixel()`.
- Une seule pile via `build_index_stack(cache_dir, sub, index,
  parallel = parallel)`.
- Helpers `.compute_alert_count()` / `.compute_alert_rolling()`
  réécrits en **mono-indice** (un seul `stack`, un seul `threshold`).

### `.enumerate_cache_scenes(cache_dir, index, date_from, date_to)` (nouveau, interne)
- Bandes requises : `NDVI → {B04, B08}`, `NBR → {B08, B12}`.
- Liste les répertoires de `cache_dir` ayant toutes les bandes requises.
- Parse `obs_date` + tuile MGRS depuis le nom (réutilise `.s2_mgrs_tile`).
- Filtre `[date_from, date_to]`. Retourne `data.frame(scene_id,
  obs_date)` trié.

### `compute_fast_alert_mask()` (D2)
- `breaks = NULL` → calcule les **quartiles des valeurs > 0** du raster
  continu : `breaks <- c(0, quantile(pos, c(.25,.5,.75)), Inf)`.
- Cas dégénéré (quantiles égaux, ex. tous les comptes = 1) :
  dédupliquer les bornes, accepter moins de classes occupées (jamais
  d'erreur `classify`). Si **aucun** pixel > 0 → masque tout en classe 0.
- Propage `index` / `threshold` à `read_fast_alert_raster()`.

### `build_index_stack()` (D4)
- Nouveau `parallel = FALSE`. Quand `TRUE` + `furrr`, le calcul
  per-scène de l'indice tourne en `future_map` (calcul pur, pas de DB).
  Le `cancel_path` (si applicable plus tard) reste vérifiable par
  fichier (thread-safe).

## 4. Rétro-compatibilité

- **Breaking** (comportement) : la carte passe de « NDVI OU NBR » à
  « un indice au choix » ; les classes passent de fixes à quartiles ;
  `threshold_ndvi`/`threshold_nbr` → `threshold`. Bump **MINOR** (0.x).
- L'énumération depuis le cache change la source des scènes mais pas le
  contrat de sortie (`SpatRaster` EPSG:2154 mono-couche). Un projet sans
  `obs_pixel` peuplé fonctionne désormais (avant : 0 scène).
- `read_fast_alert_mask()` (lecteur du masque persisté) : inchangé.

## 5. Phasage / releases

1. **v0.55.0** — D1+D2+D3+D5 (sémantique : index unique, quartiles,
   énumération cache). `feat(fast)!: single-index quartile alert map from
   cache`. Tests 2 comportements + quartiles + énumération cache.
2. **v0.56.0** — D6 (persistance content-addressed). `feat(perf): persist
   FAST alert raster as content-addressed COG`. C'est le plus gros gain
   UX (revisites instantanées) — candidat à passer **avant** D4.
3. **v0.57.0** — D4 (perf parallèle). `feat(perf): optional parallel
   raster in read_fast_alert_raster (furrr)`. Test `parallel == séquentiel`.

(Combinables si tu préfères un seul cycle. Ordre perf recommandé :
**D6 (persistance) avant D4 (parallèle)** — persister une fois rend les
revisites gratuites, ce qui résout le « plusieurs minutes » ressenti
mieux que d'accélérer un recalcul qu'on referait à chaque affichage.)

## 6. Tests (cœur)

- `.enumerate_cache_scenes()` : sélection par bandes de l'`index`,
  filtre date, parse tuile — sur un cache synthétique.
- Indicateur unique : `index="NDVI"` n'ouvre jamais B12 ; `index="NBR"`
  jamais B04 ; résultat ≠ ancien OU-des-deux.
- Quartiles : sur un raster continu synthétique connu, vérifier
  `breaks = c(0, q25, q50, q75, Inf)` et l'affectation des classes ;
  cas dégénéré (tous 0 ; toutes valeurs égales).
- Multi-tuiles : mosaïque `max` inchangée, couverture AOI complète.
- Perf : `parallel=TRUE` produit un raster **identique** à `FALSE`
  (`expect_equal` sur les valeurs).
- Pas de dépendance à `obs_pixel` : un diagnostic tourne sur un cache
  seul (zone enregistrée, `obs_pixel` vide).

## 7. Couplage app `nemetonshiny` (hors cœur, à signaler)

- **Désalignement à corriger** : le bouton « Diagnostic FAST » appelle
  aujourd'hui `ingest_sentinel2_timeseries()` (per-placette, d'où le FK
  `plot_id`). Il doit appeler **`read_fast_alert_raster()`** (raster).
- Exposer un **toggle indicateur** (NDVI / NBR) + le seuil, alimentant
  `index` / `threshold`.
- Toggle « Mode rapide (multi-cœur) » → `parallel = TRUE`.
- L'ingestion des COG vers le cache (réseau) reste un **prérequis
  séparé** du diagnostic (download ≠ diagnostic).
- Plancher `Imports: nemeton (>= 0.55.0)`.

## 8. Hors scope

- Changer le **modèle obs_pixel** vers du per-pixel (le brief initial) :
  non — le diagnostic raster ne persiste pas les pixels.
- `gdalcubes` (band-math) : éventuelle phase 3 ultérieure si parallèle
  insuffisant.
- Réécriture de l'ingestion COG / réseau.
