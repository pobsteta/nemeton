# Brief Shiny — RECONFORT : rapatrier le masquage UGF dans le cœur (v0.93.0)

**Repo** : `nemetonshiny` · **Cible** : `v0.93.0` (minor, `feat:`)
**Module** : `mod_monitoring_reconfort_map` (+ équivalent FORDEAD pour les alertes)
**Débloqué par** : `nemeton@v0.99.0` — deux fonctions exportées :
`read_reconfort_layer()` (rasters, v0.98.0) et `filter_alerts_to_zone()` (alertes, v0.99.0).
**Plancher** : `Imports: nemeton (>= 0.99.0)`.

---

## Objectif

Sortir **toute** opération spatiale de masquage de la présentation et la
déléguer au cœur, pour parité stricte FAST/FORDEAD/RECONFORT et respect des
règles strictes §1-3 (aucune sémantique spatiale dans `mod_*`). Deux volets :

1. **Rasters** (déjà cadré) — remplacer le `terra::mask` local (v0.92.3) par
   `read_reconfort_layer()`.
2. **Vecteur d'alertes** (nouveau) — passer la couche par
   `filter_alerts_to_zone()` avant rendu. **C'est le correctif du débordement
   observé** : sans ça, les centroïdes s'affichent hors UGF (le raster est
   clippé mais pas le vecteur).

---

## Volet 1 — Rasters : `read_reconfort_layer()`

Partout où le module fait `terra::rast(path)` **puis** `terra::mask(...)` sur
une couche raster RECONFORT, remplacer les deux par :

```r
r <- nemeton::read_reconfort_layer(
  layer           = row,            # ligne du manifeste, type == "raster"
  con             = con,
  zone_id         = zone_id,
  apply_zone_mask = TRUE
)                                    # SpatRaster déjà masqué à l'UGF, prêt à rendre
```

Les deux cas de polygone (l'app **choisit**, le cœur **applique**) :

| Affichage voulu | Appel |
|---|---|
| UGF entière (zone de suivi) | `read_reconfort_layer(row, con, zone_id)` → `monitoring_zone.zone_wkt` |
| Strate sélectionnée (`_tot`/`_res`/`_feu`/`_mix`) | `read_reconfort_layer(row, mask_polygon = strata_sf)` |

→ **Plus aucun `terra::mask` dans le module.**

## Volet 2 — Alertes : `filter_alerts_to_zone()` (le correctif du débordement)

Avant de rendre la couche « Alertes », filtrer le vecteur au polygone UGF :

```r
alerts_view <- nemeton::filter_alerts_to_zone(
  alerts          = result$alerts_sf,   # ou la couche chargée depuis la table `alert`
  con             = con,
  zone_id         = zone_id,
  apply_zone_mask = TRUE
)
# Pour coller exactement au raster affiché (strate sélectionnée) :
#   mask_polygon = strata_sf   (même polygone que le raster du volet 1)
leafletProxy(...) |> addCircleMarkers(data = alerts_view, group = "alerts", ...)
```

- **Helper unique partagé** : la même fonction sert RECONFORT **et FORDEAD**
  (et FAST). Appliquer le filtre dans **les deux** modules (RECONFORT + le
  module carte FORDEAD), pas seulement RECONFORT — c'est le point « parité des
  3 pipelines » de la décision.
- Filtre à l'affichage : la table `alert` n'est pas touchée.
- Reprojection CRS automatique ; `cli_warn` + passthrough si aucun polygone
  n'est résoluble (toujours fournir soit `mask_polygon`, soit `con`+`zone_id`).
- Opt-out `apply_zone_mask = FALSE` (mode rectangle complet / debug).

**Cohérence visuelle** : passer la **même** géométrie (`mask_polygon` ou
`con`+`zone_id`) au raster (volet 1) et aux alertes (volet 2) pour que points
et raster coïncident exactement.

---

## Ce qui NE change PAS

- **Manifeste** : `nemeton::reconfort_layer_manifest(result, include_range = TRUE)`
  pour générer cases à cocher + curseur d'opacité.
- **Curseur d'opacité / toggles** : inchangés (`leafletProxy`).
- **Couche UGF overlay** (`project$indicators_sf`) : reste un overlay vecteur
  toggleable — ce n'est PAS du masquage, on n'y touche pas.
- **Itération du manifeste** : ne passer au reader que les lignes
  `type == "raster"` ; la ligne `type == "vector"` (alertes) va au filtre, pas
  au reader (`read_reconfort_layer()` rejette une ligne vecteur).
- **Clic-pixel CRSWIR/CRre** : préservé, inchangé.

## Dépendance & version

- `DESCRIPTION` : `Imports: nemeton (>= 0.99.0)`.
- Release **`nemetonshiny@v0.93.0`** (`feat:` — consomme les nouvelles API
  cœur, retire `terra::mask` local + filtre les alertes).
- Ordre respecté : `nemeton@v0.99.0` est publié → l'app peut bumper et propager
  via `@*release`.

## Tests

- `testServer()` sur `mod_monitoring_reconfort_map` (+ module FORDEAD) :
  - mocker `nemeton::read_reconfort_layer` et `nemeton::filter_alerts_to_zone`
    (`local_mocked_bindings`) ; vérifier qu'ils sont **appelés** (rasters cochés
    via le reader ; couche alertes via le filtre) avec `mask_polygon` (strate)
    ou `con`+`zone_id` (UGF) ;
  - vérifier qu'**aucun `terra::mask`** n'est plus appelé dans le module ;
  - toggles : couche cochée → groupe affiché ; opacité → re-render.
- `shinytest2` E2E optionnel : carte rendue, raster ET alertes restreints à
  l'UGF (plus de points hors polygone).

## État cible (après ce câblage)

Les **3 pipelines** (FAST, FORDEAD, RECONFORT) appliquent le masque UGF —
**rasters ET vecteurs** — dans le cœur `nemeton` ; `nemetonshiny` ne porte plus
aucune opération spatiale de masquage. C'est l'aboutissement de spec 016 +
spec 021 L7.

---

### Référence API cœur (v0.99.0)

```r
# RASTER — renvoie un SpatRaster masqué à l'UGF
read_reconfort_layer(layer, con = NULL, zone_id = NULL,
                     apply_zone_mask = TRUE, mask_polygon = NULL)

# VECTEUR — renvoie l'sf des alertes restreintes à l'UGF (partagé 3 pipelines)
filter_alerts_to_zone(alerts, con = NULL, zone_id = NULL,
                      apply_zone_mask = TRUE, mask_polygon = NULL)
```
