# Réponse cœur — FAST : masques et stack d'indice (brief app du 2026-09-23)

> **En réponse à** : `nemetonshiny/specs/BRIEF-nemeton-fast-masques-et-stack.md`.
> **Livré dans** : `nemeton` **v0.198.0** (2026-09-23).
> **Écart PLAN.md** : n° 12 (livré par le cœur, en attente chez `nemetonshiny`).

## 1. Défaut A — option retenue : **nom par contenu**

`compute_fast_alert_mask()` écrit désormais
`<mask_cache_dir>/zone_<id>/fast_alert_<INDEX>_<mode>_<hash16>.tif`.

- Le hash couvre la grille (CRS, étendue, résolution), les valeurs 0-4, l'indice
  et le mode : il résume scènes, seuil, fenêtre, paramètres de tendance, bornes
  et polygone sans en tenir la liste.
- Appel identique → **même chemin, fichier non réécrit** (mtime rafraîchi). Un
  `terra::rast(mask_path)` déjà ouvert par l'app reste valide.
- Appels différents → chemins différents, jamais d'écrasement. Écriture
  atomique (temporaire caché + renommage).
- `.fast_alert_mask_gc()` (`keep = 20`) conservé.
- `read_fast_alert_mask()` : « le plus récent » = dernier écrit **ou réutilisé**
  (mtime). `run_id` accepte le suffixe `<INDEX>_<mode>_<hash16>` ; les anciens
  masques horodatés restent lisibles.

**Côté app** : mettre à jour le commentaire de `.compute_fast_mask()` — le
masque identique est maintenant réutilisé sans réécriture (le raster continu,
lui, l'était déjà via le cache D6).

## 2. Défaut B — signature finale

```r
build_index_stack(cache_dir, scenes_df,
                  index = c("NDVI", "NBR", "NDMI", "NDRE"),
                  mask_polygon = NULL, parallel = FALSE,
                  cache_result = FALSE, result_cache_dir = NULL)
```

- **Répertoire conseillé** : `<project>/cache/layers/index_stack` — c'est aussi
  le défaut quand `result_cache_dir = NULL` et `cache_dir` =
  `<project>/cache/layers/sentinel2`. Passer `cache_result = TRUE` suffit donc.
- Clé : indice + `(scene_id, obs_date)` triés + taille et mtime de chaque bande
  utilisée + WKT de `mask_polygon`. Une scène ajoutée ou réingérée invalide.
- Relecture identique au calcul : noms, `terra::time()`, `attr(, "index")`,
  valeurs NA comprises (FLT8S + fichier compagnon `.dates`).
- LRU : `getOption("nemeton.index_stack_keep", 8)`.
- **Mesuré sur `armn` zone 5, 327 scènes NDVI** : calcul + écriture 15 s,
  relecture **0,05 s**. Disque : ~233 Mo par stack, donc ≤ ~1,9 Go par projet.

**Côté app** : `cache_result = TRUE` dans l'appel de la « Carte FAST », plancher
`Imports: nemeton (>= 0.198.0)`.

## 3. Question `parallel`

**Non**, pas dans l'app telle quelle. Sans `future::plan()` multisession posé,
furrr tourne en séquentiel et n'ajoute que le coût `terra::wrap()`/`unwrap()`
(un aller-retour mémoire de chaque couche). Poser un plan multisession
permanent dans un processus Shiny coûte des workers résidents pour un gain
limité à la première construction ; avec le cache, le cas payant devient rare.
Recommandation : `parallel = FALSE`, `cache_result = TRUE`.
