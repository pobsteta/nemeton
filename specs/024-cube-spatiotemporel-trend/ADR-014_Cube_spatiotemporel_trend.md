# ADR-014 — Cube spatio-temporel pour le suivi `trend` à l'échelle régionale

> **Statut : Proposé (draft cœur).** Rédigé dans `nemeton/specs/` selon la
> convention héritée de l'ADR-013 ; à **porter vers
> `nemetonplateform/docs/`** (dépôt canonique des ADR) une fois accepté.
>
> - **Date** : 2026-06-14
> - **Décideur** : Pascal Obstétar
> - **Contexte technique** : FAST mode `trend` (spec 023), nemeton ≥ v0.83.1
> - **ADR liés** : [[ADR-002]] (PostGIS + S3/COPC), [[ADR-008]] (OGC,
>   ETRS89/EPSG:3035 paneuropéen), [[ADR-011]] (Fibonacci/NDP),
>   [[ADR-013]] (suivi sanitaire FORDEAD)

## Contexte et problème

Le mode FAST `trend` (spec 023) détecte le dépérissement **chronique** des
feuillus par une régression Theil-Sen + test de Mann-Kendall sur un composite
annuel saisonnier de Sentinel-2 (NDMI par défaut). L'implémentation actuelle
(`R/fast_alert_raster.R`) :

1. énumère les scènes du cache COG, les groupe **par tuile MGRS** ;
2. construit un stack d'indice par tuile (`build_index_stack`) ;
3. ajuste la tendance **par tuile** dans le CRS natif (UTM) ;
4. reprojette chaque raster en EPSG:2154 et **mosaïque** les tuiles avec
   `fun = "max"`.

Deux limites structurelles apparaissent dès qu'on vise une **échelle
régionale** (au-delà de l'UGF mono- ou bi-tuile) :

- **P3 — biais de recouvrement** : dans la bande de chevauchement (~10 km)
  entre tuiles voisines, chaque tuile ajuste sa pente sur **son propre** jeu
  de scènes ; `mosaic(fun = "max")` retient la plus forte magnitude de déclin
  → léger biais haut sur les liserés (documenté en v0.83.2, borné et
  conservateur, mais arbitraire).
- **Mise à l'échelle / mémoire** : le fit vectorisé (v0.83.1) charge la
  matrice `ncell × années` **en mémoire** via `terra::values()`. Performant
  sur une tuile (~9× vs per-cellule, mesuré), mais une emprise régionale
  multi-tuiles à 10 m **ne tient pas en RAM** et impose un découpage manuel.

La question : faut-il introduire un **cube spatio-temporel régulier**
(x, y, temps) — typiquement via le package R **`gdalcubes`** — pour porter le
`trend` à l'échelle régionale, et si oui, à quelles conditions ?

## Facteurs de décision

1. **Correction de P3 par construction** (unifier les tuiles multi-CRS sur une
   grille cible avec une agrégation de recouvrement *définie*, pas `max`).
2. **Traitement out-of-core** (régions ne tenant pas en mémoire).
3. **Alignement ADR-008** (grille paneuropéenne ETRS89/EPSG:3035).
4. **Coût de dépendance** (pile GDAL/netCDF de `gdalcubes` vs pile actuelle
   terra/sf légère).
5. **Préservation de l'acquis perf** : ne pas réintroduire un callback R
   per-pixel (le goulot qu'on vient de supprimer par vectorisation).
6. **Simplicité d'exploitation** à l'échelle UGF actuelle (ne pas sur-outiller).

## Options envisagées

### Option A — Statu quo terra (per-tuile + `mosaic(max)`)
Garder l'implémentation v0.83.1/v0.83.2.
- ✅ Aucune dépendance nouvelle ; rapide et correct à l'échelle UGF ; fit
  vectorisé byte-identique au chemin de référence.
- ✅ Biais P3 **borné, documenté, conservateur** pour la détection.
- ❌ Ne corrige pas P3 ; ne passe pas à l'échelle régionale (mémoire) ;
  `max` reste une heuristique de recouvrement.

### Option B — `gdalcubes` de bout en bout (`reduce_time(FUN = …)`)
Construire un cube régulier et appliquer la tendance via `reduce_time()` avec
une fonction R utilisateur (Theil-Sen + Mann-Kendall).
- ✅ Régularisation/mosaïquage multi-CRS automatique → **P3 réglé** ;
  traitement par chunks lazy → **out-of-core** ; agrégation de recouvrement
  définie (median/mean) ; parallélisme threads C++/OpenMP (pas PSOCK).
- ❌ Theil-Sen / Mann-Kendall **ne sont pas** des réducteurs natifs de
  `gdalcubes` → `reduce_time()` rappelle une fonction **R par pixel**, soit
  exactement le pattern per-cellule supprimé en v0.83.1 (~270 µs/pixel). Le
  parallélisme par chunks en rattrape une partie, mais on **perd** le gain
  vectorisé.
- ❌ Dépendance lourde (stack GDAL/netCDF) ; courbe d'apprentissage.

### Option C — `stars` (proxy / tiles)
Cube via `stars` + `st_apply`.
- ✅ Intégration `sf`/proxy lazy ; pas de pile GDAL supplémentaire majeure.
- ❌ `st_apply` reste un callback R per-pixel ; gestion multi-CRS/recouvrement
  moins aboutie que `gdalcubes` pour des collections d'images ; perf incertaine.

### Option D — Hybride : cube `gdalcubes` **uniquement** pour le composite annuel + fit vectorisé terra (recommandée)
Utiliser `gdalcubes` **seulement** pour produire le **composite annuel régulier**
(remplaçant `build_index_stack` + `mosaic` per-tuile : régularisation, choix
d'agrégation de recouvrement = median, sortie en grille EPSG:3035/2154), puis
extraire les valeurs du cube par blocs et appliquer **notre `.trend_fit_cells`
vectorisé** existant sur chaque bloc.
- ✅ **P3 réglé** (agrégation de recouvrement définie, plus de `max`) **sans**
  perdre le fit vectorisé (~9×) ; découpage par blocs natif → out-of-core ;
  alignement ADR-008 (grille cible 3035).
- ✅ Frontière nette : le cube ne fait que la **régularisation** (ce que
  `gdalcubes` fait bien), la **statistique** reste dans le cœur testé.
- ❌ Dépendance `gdalcubes` introduite (mais cantonnée à la phase composite,
  derrière une frontière claire et testable) ; logique de blocs à écrire.

## Décision

**Conserver l'Option A (statu quo terra) tant que le `trend` reste à l'échelle
UGF (mono-/bi-tuile, en mémoire).** Le gain de `gdalcubes` n'est ni la vitesse
du fit (la vectorisation reste supérieure) ni nécessaire à cette échelle.

**Adopter l'Option D (hybride) dès que l'un des seuils de déclenchement est
franchi :**

- emprise `trend` **multi-tuiles dépassant ~2-3 tuiles MGRS** ou ne tenant pas
  raisonnablement en RAM (`terra::values()` impraticable) ; **ou**
- besoin produit d'une **carte `trend` régionale** sur la grille paneuropéenne
  EPSG:3035 (ADR-008) ; **ou**
- le biais de recouvrement P3 devient **métier-significatif** (calibration
  terrain DEPERIS montrant que le `max` fausse la sévérité sur les liserés).

L'Option B (gdalcubes de bout en bout) est **rejetée** : elle sacrifie l'acquis
vectorisé sans bénéfice supplémentaire par rapport à l'hybride. L'Option C
(`stars`) est tenue en réserve si l'on veut éviter la pile GDAL de `gdalcubes`.

## Conséquences

**Positives**
- Pas de dépendance lourde tant qu'elle n'est pas justifiée par l'échelle.
- Trajectoire claire et conditionnée : un déclencheur objectif fait basculer
  vers l'hybride, sans réécriture du cœur statistique (`.trend_fit_cells`
  reste la brique de fit, déjà testée).
- Frontière d'architecture nette : `gdalcubes` = **régularisation** du cube ;
  nemeton = **statistique** + indicateur R5. Respecte la règle « métier dans
  le cœur ».

**Négatives / risques**
- Tant qu'on est en Option A, P3 subsiste (atténué : documenté, borné,
  conservateur).
- L'Option D ajoutera une dépendance `gdalcubes` (Suggests, derrière la phase
  composite) et un chemin de code « cube » à tester (régularisation,
  agrégation de recouvrement, alignement de grille 3035).
- Nécessite, le moment venu, un **benchmark réel** cube-composite vs
  per-tuile+mosaic pour confirmer le gain out-of-core et l'absence de
  régression de résultat.

## Notes de mise en œuvre (pour l'Option D, le jour venu)

- Cantonner `gdalcubes` à un helper interne `.build_trend_cube()` produisant le
  **composite annuel** (une bande par année, agrégation `median` intra-année
  et de recouvrement), en `Suggests` — dégradation gracieuse vers le chemin
  terra per-tuile si le package est absent.
- Réutiliser **tel quel** `.trend_fit_cells()` sur les blocs du cube (pré-filtre
  `min_years` + Theil-Sen/Mann-Kendall vectorisés ; fallback ex-aequo).
- Grille cible : EPSG:3035 (ADR-008) pour l'usage régional, EPSG:2154 conservé
  pour l'usage national/UGF.
- Rasters/cubes **jamais** en PostgreSQL (ADR-002) ; stockage S3/COG.

## Références

- spec 023 — FAST mode `trend` (Theil-Sen + Mann-Kendall).
- nemeton v0.83.1 — fit vectorisé (~9×, terra::app/furrr mesurés inadaptés).
- nemeton v0.83.2 — documentation du biais P3 `mosaic(fun = "max")`.
- `gdalcubes` (Appel & Pebesma, 2019) — *On-Demand Processing of Data Cubes
  from Satellite Image Collections with the gdalcubes Library*, Data 4(3):92.
- ADR-008 (grille paneuropéenne EPSG:3035), ADR-002 (S3/COPC).
