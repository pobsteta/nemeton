# Brief `nemetonshiny` — Cache disque du PAI LiDAR (moteur reGénération, spec 027)

**Cœur requis** : `nemeton (>= 0.146.2)`. La fonctionnalité `pai_cache` elle-même
existe depuis 0.145.0, **mais installe `>= 0.146.2`** : c'est la version où le moteur
d'exposition tourne réellement de bout en bout sous **microclimf 2.0.0** (chaîne de
6 correctifs 2026-07-08 : creds → 403 ERA5 → `soilparameters` → `trim`/temps →
`writeRaster`/`app` → `NaN` z-score). Avec une version antérieure, `sensibilite.gpkg`
n'est jamais produit. `regen_sensibilite()` gagne `pai_cache = <chemin GeoTIFF>`
(relit le PAI si présent + géométrie alignée, sinon calcule + écrit). **Correctif app
minimal** (`service_regeneration.R` + 1-2 clés i18n + un bouton optionnel). Pas de
nouvelle dépendance.

**Motivation** (mesuré en run réel RECONFORT, projet `20260701_204501_ltcp`) :
la phase **PAI** (`pai_depuis_nuage()` sur le nuage COPC — 25 dalles / 4,7 Go)
tient **>30 min** à ~0,8 Mo/s (décompression COPC + rastérisation `lasR`
mono-thread sur un gros AOI), **avant** même qu'ERA5 démarre. Or le PAI ne dépend
que du nuage + de la grille de travail : **invariant** pour un projet / AOI /
`res`. Aujourd'hui il est **recalculé à chaque run** (l'ancien PAI partait en
`tempfile()`), donc chaque relance (changement d'années de référence, reprise
après throttle CDS, ajustement de paramètres) repaye ces dizaines de minutes.

---

## 1. Le cœur fait déjà tout le travail

`nemeton 0.145.0` — `regen_sensibilite(..., pai_cache = <path>)` :

- `pai_cache` **présent** et `compareGeom(rast(pai_cache), grille)` **vrai** →
  PAI **relu du disque**, `pai_depuis_nuage()` **non appelé** (phase quasi
  instantanée). Événement `regen_expo:pai` avec `source = "cache"`.
- sinon → PAI dérivé du nuage **puis écrit** dans `pai_cache` (source `"lidar"`).
- géométrie différente (AOI / `res` changés) → cache **invalidé** automatiquement
  (recalcul + réécriture) : **jamais de PAI périmé**, aucune gestion de clé à la
  charge de l'app.
- `pai` fourni explicitement (repli LAI S2/PROSAIL) → `pai_cache` ignoré (inchangé).

L'app n'a donc **qu'à fournir un chemin persistant**.

---

## 2. Retouche app — passer `pai_cache` (`service_regeneration.R`)

Dans `run_regeneration_engine()`, à l'appel `do.call(nemeton::regen_sensibilite, …)`
(le bloc microclimf, là où `cache_dir = micro_cache` et `progress_callback = on_prog`
sont déjà passés), ajouter **un seul argument** :

```r
sens <- tryCatch(
  do.call(nemeton::regen_sensibilite, c(list(res,
    mnt = grid$mnt_dir, mnh = grid$mnh_dir,
    annees_moy = cfg$year_moyenne, annees_canic = cfg$year_canicule,
    cache_dir = micro_cache,
    pai_cache = file.path(out_dir, "pai.tif"),   # <-- NOUVEAU : cache PAI persistant
    progress_callback = on_prog), veg_args)),
  error = function(e) { … })
```

- `out_dir` (= `<project>/cache/regeneration`) est déjà défini en tête de la
  fonction → le PAI vit à `cache/regeneration/pai.tif`, à côté de
  `sensibilite.gpkg` / `biljou.gpkg` / `microclimf/`.
- **Chemin `veg_args$pai` (repli satellite)** : quand l'app passe déjà un raster
  `pai` (pas de `las`), le cœur ignore `pai_cache` — inutile de conditionner,
  mais tu **peux** ne poser `pai_cache` que sur la branche LiDAR (`grid$las_dir`
  non nul) pour la clarté :
  ```r
  extra <- if (!is.null(grid$las_dir)) list(pai_cache = file.path(out_dir, "pai.tif")) else list()
  do.call(nemeton::regen_sensibilite, c(list(res, …), extra, veg_args))
  ```

> **Clé de cache & `res`.** Le nom `pai.tif` suffit : le cœur valide la géométrie
> et recalcule si `res`/AOI changent. Si tu exposes un sélecteur de résolution et
> veux éviter le va-et-vient recalcul, tu peux keyer le nom :
> `sprintf("pai_res%g.tif", res)`. Optionnel.

---

## 3. Invalidation manuelle — bouton « recalculer le PAI » (optionnel)

Le cache s'auto-invalide sur changement d'AOI/`res`. Reste le cas d'un nuage LiDAR
**re-téléchargé/corrigé** à AOI constant : la géométrie ne change pas, le cache
serait réutilisé à tort. Prévoir un petit contrôle qui **supprime le fichier** :

```r
shiny::observeEvent(input$recompute_pai, {
  project_path <- tryCatch(app_state$current_project$path, error = function(e) NULL)
  if (!is.null(project_path)) {
    f <- file.path(project_path, "cache", "regeneration", "pai.tif")
    if (file.exists(f)) { unlink(f); shiny::showNotification(i18n$t("regen_pai_cache_cleared"), type = "message") }
  }
})
```

UI : une petite `actionLink`/`input_task_button` secondaire près du bouton moteur,
libellé `i18n$t("regen_pai_recompute")`. À défaut, l'utilisateur peut supprimer
le fichier à la main — documenter dans le tooltip.

---

## 4. Affichage de la phase (déjà couvert par le brief phase-status)

Le brief `brief-nemetonshiny-engine-phase-status.md` mappe déjà `regen_expo:pai`
→ phase « Structure de végétation (PAI {source}) ». Le cœur enverra désormais
`source = "cache"` sur un hit : ajouter le libellé i18n correspondant pour que la
notif bas-droite affiche **« PAI (cache) »** (phase éclair) au lieu de
« PAI (LiDAR) » (phase longue). Une clé :

| Clé | FR | EN |
|---|---|---|
| `regen_phase_pai_cache` | « cache » | "cache" |
| `regen_pai_recompute` *(si §3)* | « Recalculer le PAI » | "Recompute PAI" |
| `regen_pai_cache_cleared` *(si §3)* | « Cache PAI supprimé — recalcul au prochain run. » | "PAI cache cleared — recomputed on next run." |

Dans `.regen_phase_label()` (brief phase-status), étendre le mapping `source` :
`"cache"` → `i18n$t("regen_phase_pai_cache")`, à côté de `lidar`/`raster`.

---

## 5. Ce qu'on ne fait PAS

- **Pas de cache du PAI côté repli satellite** : quand `pai` (LAI S2) est fourni,
  il est déjà un raster prêt (rééchantillonné) — pas de coût `lasR` à éviter.
- **Pas de purge LRU du `pai.tif`** : un seul fichier par projet, quelques Mo ;
  il est écrasé quand la géométrie change. Rien à collecter.
- **Pas de clé de hash du contenu du nuage** : coûteux et inutile — la géométrie
  suffit à 99 %, le bouton §3 couvre le cas résiduel (nuage remplacé à AOI égal).

---

## 6. Test app (smoke)

- 1er run moteur (branche LiDAR) : phase « PAI (LiDAR) » longue, puis
  `cache/regeneration/pai.tif` **présent** en fin de phase.
- 2ᵉ run **même projet/AOI** : la notif bas-droite affiche **« PAI (cache) »**,
  la phase passe en **quelques secondes**, puis ERA5 démarre bien plus tôt.
- Changer l'AOI (autre sélection cadastrale) puis relancer : le PAI est
  **recalculé** (géométrie différente), `pai.tif` réécrit — pas de carte fausse.
- (si §3) Bouton « recalculer le PAI » : supprime `pai.tif`, run suivant recalcule.

---

## 7. Résumé des points de retouche

| Fichier | Retouche |
|---|---|
| `service_regeneration.R` | `pai_cache = file.path(out_dir, "pai.tif")` à l'appel `regen_sensibilite` (branche LiDAR) ; (option §3) observer `input$recompute_pai` → `unlink` |
| `mod_regeneration.R` | (option §3) bouton « recalculer le PAI » ; mapping phase `source == "cache"` → libellé (via brief phase-status) |
| `utils_i18n.R` | `regen_phase_pai_cache` (+ 2 clés si §3) FR/EN |
| DESCRIPTION | `Imports: nemeton (>= 0.145.0)` |

> **Dépend de** `brief-nemetonshiny-engine-phase-status.md` (déjà livré, v0.100.11)
> pour l'affichage de la phase PAI ; ce brief n'en change que le libellé `cache`.
