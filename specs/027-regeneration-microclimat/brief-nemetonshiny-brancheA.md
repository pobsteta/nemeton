# Brief `nemetonshiny` — Carte bivariée de tendances E-OBS (spec 027 branche A)

**Cœur requis** : `nemeton (>= 0.118.0)` — `tendances_estivales_eobs()`.
**Objectif app** : afficher, dans l'onglet **reGénération**, la **carte
bivariée de tendances estivales** (réchauffement × assèchement) **sur l'emprise
des UGF + 25 km**, comme contexte régional du diagnostic parcellaire.

> Le cœur **calcule** (pentes + classes bivariées par maille) ; l'app **rend**
> la choroplèthe. Aucune logique métier côté app (règle CLAUDE.md).

---

## 1. Ce que le cœur fournit

```r
cells <- nemeton::tendances_estivales_eobs(
  aoi          = ugf_sf,          # union des UGF (sf/sfc)
  tx           = eobs_tx_annuel,  # SpatRaster : 1 couche/an, T°max estivale (JJA)
  rr           = eobs_rr_annuel,  # SpatRaster : 1 couche/an, précip estivales
  years        = 1995:2024,       # optionnel (défaut seq_len(nlyr))
  buffer_m     = 25000            # défaut ; validé Pascal
)
# -> sf de POINTS (centres de maille E-OBS) dans l'emprise + buffer, colonnes :
#    trend_tmax, trend_precip, classe_tmax (1-3), classe_precip (1-3),
#    classe_bivariee (1-9)  -- « chaud & sec » = classe_tmax 3 & classe_precip 1
```

- **Deux chemins d'alimentation** (E-OBS = NetCDF externe, licence recherche
  non commerciale) :
  1. **`tx`/`rr`** : rasters E-OBS **agrégés par an** (moyenne estivale T°max /
     cumul estival précip, 1 couche/an). Le cœur calcule les pentes.
  2. **`precomputed`** : une `sf`/`SpatRaster` de tendances déjà calculées
     (`trend_tmax`/`trend_precip`) → le cœur ne fait que recadrer + classer.
- Sans données ni `precomputed` → **erreur propre** (message actionnable).
- Le **buffer de 25 km** est métrique (EPSG:3035) — correct même en lon/lat.

## 2. Acquisition E-OBS + agrégation estivale (app / service)

E-OBS n'est pas récupéré par le cœur. Côté app (ou un `service_eobs`) :
1. Télécharger les NetCDF **E-OBS `tx`** (T°max) et **`rr`** (précip) — Copernicus
   C3S / ECA&D (`surfobs.climate.copernicus.eu`), tranches ~1995-2010 / 2011-2025.
   **Licence recherche/enseignement non commerciale** — à afficher.
2. **Agréger en estival par an** (JJA) : moyenne T°max / cumul précip par cellule
   et par année → deux `SpatRaster` à N couches (N années). *(terra : `tapp` par
   année, ou pré-agrégé.)* Prototype de référence :
   `/home/pascal/Documents/reGénération/carte_tendances_estivales_eobs.R`.
3. **Cache projet** : les rasters annuels agrégés + le résultat
   `tendances_estivales_eobs()` par `(emprise, buffer, période)` — E-OBS est
   national et lourd, ne pas re-télécharger/agréger à chaque ouverture.

## 3. Rendu (`mod_regeneration`, sous-bloc « Contexte climatique »)

- **Carte bivariée** (Leaflet ou ggplot) : colorer chaque maille par
  `classe_bivariee` (1-9) avec une **palette bivariée 3×3** (axe chaud →,
  axe sec ↓). Les points centres de maille peuvent être rendus en **carrés**
  (résolution E-OBS ~0,1°) ou en cercles.
  - Convention : `classe_tmax` 3 = plus chaud, `classe_precip` 1 = plus sec →
    **coin « chaud & sec »** = teinte d'alerte (rouge foncé).
- **Légende bivariée 3×3** (matrice de couleurs) + infobulle par maille :
  `trend_tmax` (°C/an), `trend_precip` (mm/an), classe.
- **Emprise** : afficher le contour UGF + le buffer 25 km pour situer.
- **Optionnel** : bascule mono-variable (tendance T°max seule / précip seule).

## 4. i18n (clés à ajouter)

- Titre bloc : « Contexte climatique (tendances estivales E-OBS) » / « Climate
  context (E-OBS summer trends) ».
- Axes légende : « Réchauffement » / « Warming », « Assèchement » / « Drying ».
- Mention licence E-OBS (non commerciale) + attribution ECA&D/Copernicus.

## 5. Critères d'acceptation (app)

- [ ] La carte couvre **l'emprise UGF + 25 km**, pas la France.
- [ ] Palette **bivariée 3×3** cohérente (coin chaud & sec = alerte).
- [ ] Résultat **mis en cache** par `(emprise, buffer, période)`.
- [ ] E-OBS indisponible → message clair (pas d'erreur silencieuse), la carte
      est simplement absente (le reste de l'onglet fonctionne).
- [ ] Attribution + licence E-OBS affichées.
- [ ] Tous les textes passent par `i18n$t()`.

## 6. Hors scope (v1)

- Animation départementale (le prototype `…_avec_animation.R`) — plus tard.
- Choix interactif de la période / du buffer : commencer avec 25 km + période
  E-OBS par défaut ; paramétrer ensuite si besoin.
