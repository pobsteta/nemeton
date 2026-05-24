# Spec 013 — Raster d'alerte FAST pixel-par-pixel

**Statut** : draft, à valider.
**Démarré** : 2026-05-24.
**Cible cœur** : `nemeton` v0.46.0 (minor — nouvelle fonction exportée).
**Lien** : implémente la phase A du chantier
`nemetonshiny/design/validation-sampling.md` (mention `read_fast_alert_raster()`).

## 1. Problème observé

Sur villards (run 2026-05-23, 17 050 obs insérées, 55 dates, 155 plots),
le mode FAST actuel produit :

- **Onglet « Alertes FAST »** : tableau / markers par placette via
  `list_fast_alerts_for_zone()` qui calcule une moyenne 30 jours par
  placette puis classifie en `info` / `warning` / `critical`. Pour
  villards, retourne 30 placettes (25 `info` + 5 `warning`).
- **Onglet « Carte FAST »** : raster pixel NDVI ou NBR à une date (via
  `read_s2_band_raster()` + `build_index_stack()` livrés spec 010 en
  v0.22.0). Clic pixel → série temporelle NDVI+NBR (déjà via
  `extract_pixel_timeseries()`).

**Problèmes** :

1. La sémantique placette est en désaccord avec la sémantique S2 (10 m
   natif). Un pixel S2 fait 100 m², le buffer placette 15 m fait
   ≈ 707 m². On agrège 7 pixels pour produire une valeur par placette
   alors que les pixels eux-mêmes portent l'information.
2. Le résultat est compté par placette (limité à 155 lignes) et perd
   toute la couverture spatiale entre placettes — pourtant le cache
   COG contient les valeurs de chaque pixel de l'AOI.
3. La carte d'alerte n'existe pas : impossible de voir « cette tache
   forestière a été en alerte 12 jours sur 55 ».
4. Le graphique pixel courant n'affiche pas le seuil d'alerte horizontal.

## 2. Vision cible

### Onglet « Alertes FAST »

- Raster Leaflet d'un **SpatRaster mono-bande** où chaque pixel porte
  un **score d'alerte** entier ou réel selon le mode (cf. §3).
- Légende classifiée (palette continue ou discrète).
- Pas de markers placettes (les placettes restent disponibles via
  l'onglet « Carte FAST » pour le click time series).

### Onglet « Carte FAST »

- Raster NDVI ou NBR (toggle) à la **résolution native 10 m**, pour la
  date la plus récente de la fenêtre par défaut, avec slider date
  optionnel (hors scope V1, cf. §6).
- Clic pixel → modal plotly avec la série temporelle NDVI **et** NBR
  sur toute la fenêtre, **ligne horizontale au seuil** (0.40 NDVI,
  0.30 NBR par défaut).

## 3. Décision sémantique — deux modes en parallèle

L'utilisateur a tranché : exposer **les deux modes** côté cœur, l'app
choisira via un toggle UI.

| Mode | Sortie raster | Question répondue | Bruit |
|---|---|---|---|
| `"count"` | Entier ∈ [0, N_dates]. Compte de dates où le pixel a `(NDVI_d < threshold_ndvi) OR (NBR_d < threshold_nbr)`. | « Combien de fois ce pixel a été stressé ? » | Sensible aux nuages non masqués → mitigation = `max_cloud` strict à l'ingestion (déjà appliqué) |
| `"rolling"` | Réel ≥ 0. Magnitude de déficit `max(max(0, threshold_ndvi - mean_ndvi_30j), max(0, threshold_nbr - mean_nbr_30j))` calculée sur la fenêtre des `window_days` les plus récents. Valeur 0 = pas en alerte. | « Cette zone est-elle dans un état dégradé persistant ? À quel point ? » | Robuste, mais insensible aux chocs brefs |

**Combinaison NDVI + NBR** :

- Mode `"count"` : chaque date où **NDVI<seuil OU NBR<seuil** compte +1
  (l'utilisateur veut détecter le stress quelle que soit la signature).
- Mode `"rolling"` : on retient le pixel comme « en alerte » si la
  moyenne 30j de NDVI OU la moyenne 30j de NBR est sous son seuil.

## 4. API cœur

### 4.1 Fonction exportée principale

```r
read_fast_alert_raster(
  con,
  zone_id,
  threshold_ndvi = 0.40,
  threshold_nbr  = 0.30,
  date_from,
  date_to,
  mode           = c("count", "rolling"),
  window_days    = 30L,
  cache_dir
) -> SpatRaster
```

**Comportement** :

1. Résout l'AOI via `.get_zone_aoi(con, zone_id)` (spec 012).
2. Énumère les scènes du cache dans `[date_from, date_to]` qui ont les
   trois bandes requises (B04, B08, B12).
3. Construit les stacks `build_index_stack(cache, scenes, "NDVI")` et
   `build_index_stack(cache, scenes, "NBR")` (spec 010 — déjà livrée).
4. Selon `mode` :
   - `"count"` :
     ```
     in_alert = (NDVI_stack < threshold_ndvi) | (NBR_stack < threshold_nbr)
     out = sum(in_alert, na.rm = TRUE)
     ```
     Renvoie un raster entier `[0, N_dates]`.
   - `"rolling"` :
     Pour chaque pixel, fenêtre glissante de `window_days` (en jours
     calendaires, pas en nombre d'observations) ; on prend la moyenne
     sur la fenêtre la plus récente (pas toutes les fenêtres
     possibles — la V1 ne fait pas de stack 4D). On retourne 1 si
     `mean_NDVI < threshold_ndvi` OR `mean_NBR < threshold_nbr`, 0
     sinon. Sortie booléenne stockée en entier.

5. CRS de sortie : **CRS natif du COG S2** (typiquement EPSG:32631 pour
   T31TFM/TGM/TFN). L'app reprojettera pour Leaflet.

### 4.2 Validation des entrées

- `zone_id` : scalaire non-NA → sinon `cli_abort` typée.
- `cache_dir` : chemin existant → sinon `cli_abort` typée.
- `threshold_ndvi`, `threshold_nbr` : numérique scalaire dans (0, 1) →
  sinon `cli_abort`.
- `date_from <= date_to`, parsables → sinon `cli_abort`.
- `mode` : `match.arg`.
- `window_days` : entier positif quand `mode = "rolling"`.

### 4.3 Dégradation propre

- Aucune scène dans la fenêtre → `NULL` avec `cli_alert_info`.
- Cache vide / bandes manquantes → ignorer les scènes incomplètes,
  warner si > 50 % rejetées.
- Zone sans `zone_wkt` → propage l'erreur de `.get_zone_aoi()`.

### 4.4 Performance attendue

- 55 dates × 3 bandes × ~10 000 pixels = ~1.6 M lectures pixel.
- `terra` est vectorisé : `sum(in_alert)` sur un stack 55-couche prend
  ~1 s sur un raster 100×100. Cible < 5 s pour villards typique.
- Pas de parallélisme V1 (mono-thread terra, suffisant).

## 5. Livrables cœur

| Livrable | Fichier | Statut |
|---|---|---|
| `read_fast_alert_raster()` exportée | `R/fast_alert_raster.R` (neuf) | à coder |
| Helper interne `.compute_alert_count()` | idem | à coder |
| Helper interne `.compute_alert_rolling()` | idem | à coder |
| Tests offline (fixtures fakes) | `tests/testthat/test-fast-alert-raster.R` | à coder |
| Test intégration `with_clean_db` | idem | à coder |
| Roxygen `@param`, `@return`, `@examples` | inline | à coder |
| NAMESPACE export | auto via roxygen | auto |
| NEWS, CHANGELOG, PLAN, README badge, CITATION | release v0.46.0 | std |

### Tests minimum

- Valid mode args : `mode = "count"` et `mode = "rolling"`.
- Validation entrées (zone_id, cache_dir, seuils, dates).
- `NULL` retourné si pas de scène.
- Comparaison contre un calcul manuel sur un fixture 3 dates × 4×4
  pixels.
- Régression : `mode = "count"` borné par `length(scenes)`.
- Robustesse : pixels NA (cloud mask), bandes manquantes silencieusement
  ignorées.

## 6. Hors scope V1 (à reporter en spec 014+ si besoin)

- **Slider date sur la Carte FAST** (afficher un date pickable au lieu
  de la dernière disponible).
- **Rolling window « toutes les fenêtres »** (stack 4D historique au
  lieu de juste la fenêtre la plus récente).
- **Persistance du raster d'alerte** (pour le moment recalculé à chaque
  read, c'est rapide).
- **Sortie GeoTIFF disque** (utilisable mais l'app peut le faire si
  besoin via `terra::writeRaster(raster, …)`).
- **Composition multi-tuile** (si l'AOI s'étend sur 2+ MGRS tiles, V1
  retourne soit une mosaïque virtuelle si `build_index_stack` la fait,
  soit erreur claire).

## 7. Côté app `nemetonshiny` (chantier séparé)

Suit la livraison cœur v0.46.0. À traiter dans une session dédiée
`nemetonshiny`. Hauts niveau :

1. **mod_monitoring_fast_alerts** :
   - Remplacer `addCircleMarkers` par `addRasterImage(read_fast_alert_raster(
     con, zone_id, threshold_ndvi, threshold_nbr, date_from, date_to,
     mode = input$mode, window_days, cache_dir))`.
   - Toggle radio `mode ∈ {compte, rolling}`.
   - Légende classifiée (`addLegend` continue ou pas).
   - Reformuler i18n placette → pixel (cf. prompt UX précédent).

2. **mod_monitoring_fast_map** (Carte FAST) :
   - Garder le raster NDVI / NBR existant (spec 010).
   - Sur le clic pixel, modal plotly avec :
     - série NDVI (ligne bleue) avec horizontale `threshold_ndvi`
     - série NBR (ligne orange) avec horizontale `threshold_nbr`
     - hover : date + valeur.

3. **Réactif refresh** (cf. bug observé 2026-05-23 — l'app n'invalide
   pas ses réactifs après `s2:complete`) :
   - Hook un `observeEvent` sur `s2:complete` qui bump un
     `reactiveVal` partagé entre les deux onglets.
   - Sans ça, le nouveau raster d'alerte reste invisible jusqu'à
     refresh manuel.

## 8. Risques et mitigations

| Risque | Mitigation |
|---|---|
| `build_index_stack` n'aligne pas les rasters si certaines scènes ont des extents légèrement différents | spec 012 garantit le même crop AOI pour toutes les scènes — devrait être OK ; à vérifier dans le test fixture |
| Sortie en CRS natif S2 (32631) embarrasse l'app pour Leaflet (EPSG:3857) | terra::project() côté app, perte de qualité négligeable ; OU on projette côté cœur en EPSG:2154 cohérent avec le reste du projet |
| Trous de données (scènes nuageuses) → biais sur `count` mode | Doc explicite dans `@details`, `max_cloud` à l'ingestion + filtre `is.na` dans la fonction |
| Mode `rolling` lent si fenêtre 4D | V1 fait UNE fenêtre (la plus récente), pas toutes — performance bornée |

## 9. Décisions actées (2026-05-24)

1. **CRS de sortie : EPSG:2154 Lambert-93**. Calcul interne en CRS
   natif S2 (32631 typiquement) pour éviter de reprojeter les bandes
   d'entrée, **projection en sortie** vers 2154 via `terra::project()`
   (méthode `near` pour la sortie classifiée).
2. **Mode `"rolling"` : sortie continue** = `max(deficit_ndvi, deficit_nbr)`
   où `deficit_x = max(0, threshold_x - mean_x)`. Unit = magnitude du
   déficit sous seuil. Valeur = 0 ⇒ pixel pas en alerte, valeur > 0 ⇒
   en alerte avec amplitude. Sémantique « à quel point ».
3. **Si 0 scène dans la fenêtre : retourne `NULL`** + `cli_alert_info`.
   Cohérent avec `read_fordead_dieback_mask()`.

## 10. Suite

Si la spec est validée :

- Release minor cœur **v0.46.0** : 1 fonction exportée, 1 fichier R
  neuf, 1 fichier de test neuf. ~300 lignes au total. ~1 session.
- Puis chantier app `nemetonshiny` (prompt à régénérer pour intégrer
  le toggle mode + threshold lines + observe `s2:complete`).
- Synergie spec 014 (validation-sampling) : `read_fast_alert_raster()`
  devient l'entrée du `priority_raster` pour le GRTS pondéré.
