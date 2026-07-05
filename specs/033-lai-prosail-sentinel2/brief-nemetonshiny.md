# Brief `nemetonshiny` — Provenance canopée reGénération (spec 033 D5)

**Cœur requis** : `nemeton (>= 0.137.0)` (helper `canopy_provenance()`).
**Statut cœur** : chaîne validée **bout-en-bout sur données réelles** (v0.135.0/
0.136.0) — MUSCATE→LAI (LAI médian 2.33) + FORMS-T débloqué. Le repli satellite
lit via des **URLs pré-signées** (gateway teledetection) : nécessite
`TLD_ACCESS_KEY`/`TLD_SECRET_KEY` dans l'environnement (déjà dans le `.Renviron`
de nemetonshiny).
**Objectif** : afficher dans l'onglet **reGénération** la **provenance de la
donnée canopée** utilisée par les moteurs (LiDAR HD **ou** repli satellite
Sentinel-2/PROSAIL), et permettre le **repli NDP 0** quand le LiDAR est absent.
**Portée** : purement présentation — la décision de source et le calcul du LAI
vivent dans le cœur (règles #1/#3). Aucune logique métier côté app.

---

## 1. Contexte

Les moteurs reGénération ont besoin d'une **structure de canopée** :

- **`pai` de `regen_sensibilite()` (microclimf)** : PAI structural LiDAR HD
  (`pai_depuis_nuage()`) **par défaut** ; sinon, repli **LAI Sentinel-2/PROSAIL**
  (`lai_sentinel2()`) injecté via l'argument `pai` — **proxy dégradé** (LAI ≠
  PAI : feuilles seules, 10-20 m, sommet de canopée).
- **`lai_max` de `regen_bilan_hydrique()` (biljouR)** : le LAI S2/PROSAIL est un
  **ajustement direct** (LAI = variable attendue).

**NDP ≥ 1 (LiDAR HD présent) utilise TOUJOURS le PAI structural.** Le repli
satellite est un **dernier recours NDP 0**.

## 2. Contrat cœur — fonctions à appeler (nemeton >= 0.129.0)

```r
# Repli LAI Sentinel-2/PROSAIL sur l'emprise (auto MUSCATE si `refl` non fourni).
lai <- nemeton::lai_sentinel2(aoi = ugf, start = "2023-06-01", end = "2023-09-30")
#   -> SpatRaster `lai` (1 couche, p90 estival), ou NULL (dégradation propre)

# Injection dans les moteurs (chemin `precomputed` recommandé côté app) :
nemeton::regen_sensibilite(units, mnt, mnh, pai = lai, annees_moy, annees_canic)  # microclimf
nemeton::regen_bilan_hydrique(units, meteo, sol, lai_max = <lai agrégé par UGF>)   # biljouR

# Provenance / NDP : le flag ML est porté par detect_ndp().
attr(data, "lai_source") <- "prosail_s2"     # posé par le cœur/pipeline
nemeton::detect_ndp(data)$augmented          # contient "lai_ml" quand repli actif
```

**Point clé** : c'est le **cœur** qui décide de la source (LiDAR si dispo, sinon
satellite) et qui pose `augmented = "lai_ml"`. L'app **lit** ce flag et
**affiche**. Le niveau NDP de base reste **0** (le repli n'augmente pas le NDP).

## 3. Détermination de la provenance — via `canopy_provenance()` (règle #1)

Depuis v0.137.0, **ne pas** tester les flags à la main : appeler le helper cœur
qui mappe `augmented` → une **clé de provenance canonique**.

```r
prov <- nemeton::canopy_provenance(detect_ndp(data)$augmented)
# -> "lidar_hd" | "prosail_s2" | "opencanopy"
```

| Clé retournée | Flag `augmented` | Provenance à afficher |
|---------------|------------------|-----------------------|
| `"lidar_hd"`   | (aucun flag canopée) | **Canopée : LiDAR HD** |
| `"prosail_s2"` | `"lai_ml"` | **Canopée : satellite (repli Sentinel-2/PROSAIL)** |
| `"opencanopy"` | `"height_ml"` | **Canopée : CHM ML (Open-Canopy)** |

`lai_ml` est **prioritaire** (sa présence = LiDAR absent). L'app obtient
`augmented` via `detect_ndp()` (déjà consommé pour le badge NDP) et **ne
ré-implémente aucune règle de choix**.

## 4. UI `mod_regeneration`

- **Badge provenance** près du score de priorité / du bouton « Lancer
  l'analyse » : `switch(prov, …)` sur la clé de `canopy_provenance()` → trois
  états i18n (`regen_canopee_lidar`, `regen_canopee_satellite`,
  `regen_canopee_chm`).
- **Info-bulle** sur l'état satellite (avertissement métier, texte i18n, pas de
  littéral) : `regen_canopee_satellite_info` → « Repli NDP 0 : LAI Sentinel-2
  (inversion PROSAIL) en l'absence de LiDAR HD. Proxy dégradé de la structure de
  canopée (LAI ≠ PAI) ; précision moindre. »
- **Aucune** exposition des paramètres PROSAIL/bandes dans l'UI (détail cœur).

## 5. i18n (clés à ajouter dans `utils_i18n.R`, FR/EN)

| Clé | FR | EN |
|-----|----|----|
| `regen_canopee_lidar` | Canopée : LiDAR HD | Canopy: LiDAR HD |
| `regen_canopee_satellite` | Canopée : satellite (repli) | Canopy: satellite (fallback) |
| `regen_canopee_chm` | Canopée : CHM ML (Open-Canopy) | Canopy: ML CHM (Open-Canopy) |
| `regen_canopee_satellite_info` | Repli NDP 0 : LAI Sentinel-2 (PROSAIL) sans LiDAR ; proxy dégradé (LAI ≠ PAI). | NDP-0 fallback: Sentinel-2 LAI (PROSAIL) without LiDAR; degraded proxy (LAI ≠ PAI). |

## 6. Dégradation

- `lai_sentinel2()` → `NULL` (pas de scène / prosail absent / réseau / **pas de
  clé Theia `TLD_*`** pour la signature MUSCATE) : l'app n'affiche pas le badge
  satellite et les moteurs restent sur le chemin LiDAR (ou non lançables si pas
  de LiDAR non plus) — **comportement inchangé**. `canopy_provenance()` renvoie
  alors `"lidar_hd"` par défaut.
- Le badge provenance ne s'affiche que quand une canopée est effectivement
  utilisée.

## 7. Règles

1. **Aucune logique métier** côté app : la source, le LAI et le flag `lai_ml`
   sont cœur. L'app lit `detect_ndp()$augmented` et affiche.
2. Textes UI **toujours** via `i18n$t(...)`, jamais en littéral.
3. Chemin **`precomputed`** privilégié : calculer `lai_sentinel2()` /
   `regen_*()` en tâche asynchrone (ExtendedTask) et cacher sous
   `<project>/cache/regeneration/` comme les autres sorties reGénération.
4. Persistance : le LAI de repli peut être caché
   (`cache/regeneration/lai_prosail.tif`) au même titre que `micro.tif` /
   `biljou.gpkg`.

## 8. Hors périmètre (reste cœur / futur)

- Validation PROSAIL sur scène S2 réelle : **faite** (v0.135.0, LAI médian 2.33).
- Choix des années moyenne/canicule (déjà couvert par le brief onglet 027).
- Toute restitution de structure 3D depuis le satellite (hors sujet — LiDAR HD).
