# Spec 016 — Mask UGF par défaut sur le pipeline raster

**Statut** : validée 2026-05-27 (décisions actées via AskUserQuestion), implémentation en cours pour release v0.49.0.
**Démarré** : 2026-05-27.
**Cible cœur** : v0.49.0 (minor — changement de comportement par défaut).
**Précédents** : spec 011 (project_uuid binding v0.44.0), spec 012
(AOI alignment v0.45.0), spec 013 (FAST alert raster v0.46.0), spec
014 (validation sampling v0.47.0).

## 1. Problème

L'AOI passée aux pipelines FAST/FORDEAD est `monitoring_zone.zone_wkt`,
qui est `st_union(project$indicators_sf)` — l'union des UGFs du
projet. C'est un POLYGONE potentiellement non-rectangulaire (suivant
le contour des parcelles cadastrales).

Mais le **crop** des COGs Sentinel-2 se fait sur la **bbox** de ce
polygone (`terra::crop(snap = "out")`), donc le rectangle englobant.

Pour villards :

| | Surface | % bbox |
|---|---|---|
| Bbox UGFs (1.32 km × 2 km) | 264 ha | 100 % |
| Union UGFs (les 6 parcelles réelles) | **77 ha** | **29 %** |

**Conséquence** : ~70 % des pixels comptés/affichés sont **hors UGF**
(routes, village, prairies, eau). Trois symptômes concrets :

1. Le **compte d'alertes FAST** (count mode) inclut des pixels village
   qui chutent en NDVI pour des raisons agricoles (récolte, fauche)
   → pollution du signal sanitaire forêt.
2. La **carte d'alertes FAST** affiche du rouge sur tout un rectangle,
   y compris des zones où l'utilisateur n'a aucune action de gestion
   → mauvaise lisibilité.
3. Le **dieback_mask FORDEAD** est masqué par BD Forêt v2 nationale,
   donc filtre déjà les non-forêts. Mais il garde les forêts **hors
   UGF gérées par l'utilisateur** (forêts voisines, etc.).

## 2. Vision cible

**Par défaut**, tous les outputs raster du pipeline (FAST, FORDEAD)
sont **masqués au polygone des UGFs** : pixels hors polygone = NA.

Le calcul et l'affichage gagnent automatiquement en pertinence. Les
appelants qui voulaient explicitement le rectangle complet (cas
avancés : analyse comparative, debug) peuvent désactiver via
`apply_zone_mask = FALSE`.

L'**architecture du cache** ne change pas : le COG cached reste un
rectangle pixel-aligné à la bbox de l'AOI (compatible avec snap-to-grid
v0.48.1, tile-aware v0.48.2, memoization v0.48.3). Le **mask** est
appliqué au moment du **read** ou du **compute**, pas du write.

## 3. Décisions actées (cf. AskUserQuestion 2026-05-27)

1. **Cible** : les deux — calcul (compteurs précis) + affichage
   (carte propre). Un seul argument couvre les deux puisque c'est
   le même raster qui sort.
2. **Périmètre** : tout le pipeline raster — FAST
   (`read_fast_alert_raster`, `compute_fast_alert_mask`,
   `build_index_stack`) **et** FORDEAD (`read_fordead_dieback_mask`,
   `read_fordead_pixel_series`) **et** `read_obs_pixel` (SQL spatial
   filter, no-op statistique mais protection défensive).
3. **Comportement par défaut** : **opt-out** — `apply_zone_mask =
   TRUE` par défaut. Le polygone UGF est dérivé automatiquement
   depuis `.get_zone_aoi(con, zone_id)`. Pour désactiver,
   `apply_zone_mask = FALSE` ou `mask_polygon = NULL`.

## 4. Architecture

### 4.1 Helper interne

`.apply_zone_mask(raster, zone_polygon)` : reçoit un `SpatRaster` et
un `sf POLYGON`, retourne le raster avec NA hors polygone (via
`terra::mask(raster, terra::vect(zone_polygon))`).

### 4.2 Signature publique commune

Toutes les fonctions raster impactées gagnent deux arguments :

```r
fn(
  ...,
  apply_zone_mask = TRUE,           # nouveau, défaut TRUE
  mask_polygon    = NULL            # nouveau, défaut NULL (dérivé via .get_zone_aoi)
)
```

Logique :

```r
mask_to_apply <- if (apply_zone_mask) {
  mask_polygon %||% .get_zone_aoi(con, zone_id)
} else {
  NULL
}
# ... compute raster ...
if (!is.null(mask_to_apply)) {
  out <- .apply_zone_mask(out, mask_to_apply)
}
```

L'utilisateur peut :
- ne rien faire → mask UGF auto (`apply_zone_mask = TRUE`, `mask_polygon = NULL` → dérivé de la zone)
- forcer un polygone custom → `mask_polygon = mon_sf`
- désactiver → `apply_zone_mask = FALSE` (retour rectangle complet, comportement pré-v0.49.0)

### 4.3 Fonctions impactées (5 exportées + helpers)

| Fonction | Type | Action |
|---|---|---|
| `read_fast_alert_raster(con, zone_id, ...)` | raster | + 2 args, mask appliqué sur output |
| `compute_fast_alert_mask(con, zone_id, ...)` | raster + write | + 2 args, mask appliqué AVANT discretization, mask aussi dans le TIF écrit |
| `read_fast_alert_mask(con, zone_id, ...)` | raster | + 2 args, mask appliqué sur output (le TIF on disk peut déjà être masqué si écrit par compute_fast_alert_mask v0.49.0+) |
| `build_index_stack(cache_dir, scenes_df, index, ...)` | stack | + 2 args, mask appliqué à chaque layer. **Note** : pas de `con`/`zone_id` ici → `mask_polygon` doit être passé explicitement par le caller |
| `read_fordead_dieback_mask(con, zone_id, ...)` | raster | + 2 args, mask appliqué sur output |
| `read_fordead_pixel_series(con, zone_id, xy, ...)` | data.frame | pas affecté (déjà 1 pixel à la fois — vérifier que xy ∈ UGF, sinon warn) |
| `read_obs_pixel(con, zone_id, ...)` | SQL | + 1 arg `restrict_to_ugf = TRUE`. Filter `WHERE ST_Within(plot.geom, zone_wkt)`. No-op statistique car plots déjà inscrits sous UGF, mais protection. |

### 4.4 `extract_pixel_timeseries()` (spec 010)

Cette fonction extrait une **série temporelle** à un point `xy`. Le
mask UGF n'est pas pertinent ici (1 pixel demandé, pas un area).
Cependant on peut ajouter un check défensif : warn si `xy` est hors
des UGFs (et retourner NULL ou la série quand même selon décision).

**Proposition** : ajouter `warn_outside_zone = TRUE` qui warn (mais
ne fail pas) si le point est hors zone. Pas de mask physique.

### 4.5 Cache COG inchangé

Le COG cache (`<cache_dir>/<scene_id>/<band>.tif`) reste **un
rectangle pixel-aligné à la bbox UGF**. Aucun changement de cache
write. Les mécaniques v0.48.1-3 (snap-to-grid, tile-aware, memo)
restent intactes. Le mask est appliqué **au-dessus** du cache.

## 5. Performances

`terra::mask(raster, sf_polygon)` rasterise le polygone à la grille
du raster puis pose NA. Coût ~5-20 ms pour un raster 1.3 km × 2 km
@ 10 m (≈ 26 000 pixels). Sur 122 scènes × 2 bandes index = 244
mask applications × 10 ms = ~2.5 s totaux pour le pipeline FAST.
**Négligeable** vs les bénéfices.

`compute_fast_alert_mask()` qui persiste un TIF écrit désormais un
fichier masqué (NA hors UGF). Compression DEFLATE traite très bien
les NA → fichier plus petit qu'avant pour villards (~30 % de
pixels valides).

`read_obs_pixel()` : filter SQL ST_Within ajoute ~5 ms sur une
requête déjà rapide (<50 ms). Négligeable.

## 6. Migration / backward-compat

**Breaking change** par défaut :
- Tous les call sites qui ne précisent pas `apply_zone_mask`
  voient maintenant un raster masqué.
- Les fichiers cached **par `compute_fast_alert_mask()`** pré-v0.49.0
  sont des rectangles ; en v0.49.0 ils seront masqués. Le lecteur
  `read_fast_alert_mask()` n'applique pas un re-mask sur un fichier
  déjà masqué (pas de pénalité, juste re-NA sur des NA).
- Les tests doivent être ajustés pour ce nouveau comportement (cf.
  §8).

Pour les usages qui voulaient le rectangle complet (rare) :
explicitement passer `apply_zone_mask = FALSE`. Documenté dans
les `@param` roxygen.

## 7. Côté `nemetonshiny`

**Aucun changement requis pour bénéficier du mask** — les modules
qui appellent `read_fast_alert_raster()` etc. utilisent les défauts
et reçoivent automatiquement un raster masqué. Le contour des UGFs
peut maintenant être ajouté en `addPolygons()` par-dessus pour donner
le repère visuel (déjà demandé par l'utilisateur dans le chantier
UX en cours).

## 8. Tests d'acceptation

| AC | Description | Comment |
|---|---|---|
| AC.1 | `read_fast_alert_raster(apply_zone_mask = TRUE)` retourne NA hors UGF | Compter cells NA = celles hors polygone |
| AC.2 | `read_fast_alert_raster(apply_zone_mask = FALSE)` retourne le rectangle complet (comportement v0.48.x) | Bbox raster = bbox AOI |
| AC.3 | `compute_fast_alert_mask()` persiste un TIF masqué par défaut | Lire le TIF, vérifier NA hors UGF |
| AC.4 | `read_fordead_dieback_mask(apply_zone_mask = TRUE)` filtre les pixels forêt hors UGF | Pixels classe > 0 strictement dans le polygone UGF |
| AC.5 | `read_obs_pixel(restrict_to_ugf = TRUE)` n'inclut que les plots dans la zone | Pour les plots de villards, count == 155 (tous inscrits) |
| AC.6 | `build_index_stack(mask_polygon = ugf_sf)` applique le mask sur chaque layer | Pixels NA cohérents entre layers |
| AC.7 | `extract_pixel_timeseries(xy, warn_outside_zone = TRUE)` warn si xy hors UGF | `expect_warning("outside zone")` |
| AC.8 | Aucune régression sur les fonctions qui ne touchent pas au raster (FORDEAD pipeline, validation sampling) | Suite globale verte |

## 9. Hors scope V1

- **Mask au cache write** (option A dans la discussion) — reporté.
  Le cache reste rectangle ; le mask est au-dessus.
- **Migration des TIFs persistés pré-v0.49.0** (`fast_alert_mask`
  écrits par v0.47.0+) — le lecteur `read_fast_alert_mask()` applique
  un re-mask au read pour assurer cohérence. Pas de migration disque.
- **Dilatation du mask** (e.g. mask + buffer 50 m pour inclure les
  pixels border-effects) — V2 si besoin.
- **Mask multi-zone** (e.g. plusieurs UGFs disjointes traitées
  séparément) — V2.

## 10. Suite

Si validée :

- Release **v0.49.0** (minor — nouveau comportement par défaut).
- Estimation effort : **1-2 sessions**.
  - Helper `.apply_zone_mask()` + tests (30 min)
  - Wiring des 5 fonctions raster + leurs tests (1-2 h)
  - `read_obs_pixel(restrict_to_ugf)` + test intégration (30 min)
  - Doc roxygen + NEWS + CHANGELOG + PLAN (30 min)
- Bump `Imports: nemeton (>= 0.49.0)` côté `nemetonshiny` dans la
  prochaine release app.
