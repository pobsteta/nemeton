# Spec 042 — Produits biophysiques Sentinel-2 (LAI, fAPAR, FVC, CCC)

**Version** : 2.0.0
**Date**    : 2026-07-24
**Statut**  : **Lot 1 livré (v0.166.0)** — `biophysique_sentinel2()` (LAI/fAPAR/FVC).
Calcul interne depuis Sentinel-2 (généralisation de `lai_sentinel2()`), GEODES
rétrogradé de *source* à *référence de validation* (D1 dissous). Restent : lots 2
(branchements A1/C2), 3 (validation GEODES), 4 (CCC), 5 (confiance pixel).
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` — `biophysique_sentinel2()` + upgrades de proxys.
**Cible app**  : `nemetonshiny` — affichage, badge de provenance/qualité.
**Origine** : question de cohérence (2026-07-24) ; pivot après vérification que la
machinerie PROSAIL du cœur produit **déjà** les quatre variables.

> **v1 → v2.** La v1 proposait de *consommer* le produit national CNES/GEODES
> (bloquée sur D1 : mécanisme d'accès inconnu). Vérification faite, `nemeton`
> calcule **déjà** LAI par inversion PROSAIL hybride (`lai_sentinel2()`, spec 033),
> et la même machinerie produit fAPAR / FVC / CCC. Le calcul interne est **plus
> cohérent** (une méthode, une source S2 déjà câblée, étiquetage NDP maîtrisé) et
> **n'a pas de dépendance d'accès**. GEODES devient la référence pour *valider*
> l'inversion, pas la fournir.

## 1. Objectif

Restituer, en interne depuis Sentinel-2, les quatre variables biophysiques —
**LAI, fAPAR, FVC, CCC** — par la **même inversion PROSAIL hybride** que
`lai_sentinel2()`, et s'en servir pour **remplacer des proxys grossiers** dans les
indicateurs existants. **Pas pour créer quatre nouveaux indicateurs** (§3).

## 2. La machinerie est déjà là (vérifié dans le code)

`lai_sentinel2()` (`R/lai_prosail.R`, spec 033) fait déjà :
`S2 (MUSCATE) → inversion PROSAIL hybride → LAI → réduction temporelle`.

Le seul point figé est la variable cible :

```r
# .lai_prosail_train() — actuel :
prosail::train_prosail_inversion(parms_to_estimate = "lai",
                                 selected_bands = list(lai = selected_bands), …)
```

Or `train_prosail_inversion()` prend `parms_to_estimate` en **argument** :
- `"fCover"` → **FVC** (même inversion, autre cible) ;
- `"CCC"` (ou `Cab`, puis `Cab × LAI`) → **CCC** ;
- `prosail::Compute_fAPAR()` → **fAPAR**, calculé **analytiquement** depuis les
  paramètres PROSAIL restitués + la géométrie d'acquisition.

Le modèle d'inversion est **caché** (clé `prosail_<var>_<sensor>_<bands>.rds`) et
un modèle LAI pré-entraîné est déjà **livré** dans `inst/extdata`
(`prosail_lai_Sentinel_2A_B4-B5-B8.rds`). Généraliser = paramétrer la variable et
livrer un modèle par variable.

## 3. Analyse de cohérence (inchangée depuis v1)

Colinéarité de fond : `fAPAR ≈ 1 − e^(−k·LAI)`, `FVC ≈ 1 − e^(−0,5·LAI)`. LAI,
fAPAR et FVC mesurent **la même densité de couvert** sous trois angles. Les
exposer comme trois indicateurs de la famille C **triplerait le poids de la
verdeur** dans l'agrégation Fibonacci — *moins* cohérent. La valeur est de
**raffiner des proxys existants** :

| Variable | Proxy actuel qu'elle remplace | Geste |
|---|---|---|
| **fAPAR** | **C2 = NDVI** (`indicateur_c2_ndvi`), qui **sature** à fort LAI | **Upgrade** de C2 (lié à la production primaire) |
| **FVC** | A1 — `indicateur_a1_couverture(fvc = NULL)` **déjà câblé** | **Branchement** |
| **LAI** | déjà consommé (regen/microclimat) ; **C1 = `ndvi_mean × 150`** (`indicators-families.R:371`, grossier) | **Amélioration** possible de C1 |
| **CCC** | — (rien) | **Seul ajout neuf** : chlorophylle/azote = **santé**, pas densité → candidat R5 |

## 4. Fonction

Généralisation de `lai_sentinel2()`, mêmes conventions (fast-path `precomputed`,
réduction temporelle, dégradation `NULL`, `requireNamespace("prosail")`) :

```r
biophysique_sentinel2(
  variable = c("lai", "fapar", "fvc", "ccc"),   # une ou plusieurs
  aoi = NULL, refl = NULL, start = NULL, end = NULL,
  reducer = "p90", source = "muscate", sensor = "Sentinel_2A",
  selected_bands = NULL,          # défaut PAR VARIABLE (§7)
  geom_acq = NULL, mask = NULL, cache_dir = NULL, precomputed = NULL, …
)
```

→ `SpatRaster` à une couche par variable demandée. `lai_sentinel2()` **conservé**
comme alias mince (`variable = "lai"`) — rétrocompatibilité stricte, aucun appelant
existant cassé.

## 5. GEODES — référence de validation, pas source (D1 dissous)

Le produit CNES/GEODES (LAI/fAPAR/FVC/CCC, 20 m France, S2, **même méthode
PROSAIL-ML**, masque qualité 1-4) **n'est plus consommé**. Il sert à **valider**
notre inversion là où ses dalles existent :

- comparer, sur quelques tuiles S2, `biophysique_sentinel2()` à GEODES → biais,
  RMSE par variable. C'est le **lot de validation** (§9), pas une dépendance.
- l'accès GEODES (STAC ? dalles ? — non publié) redevient une **question annexe**,
  utile à la validation seule, plus **bloquante**.

## 6. Les deux réserves qui SURVIVENT au pivot

Le calcul interne dissout l'accès, **pas** ces deux limites — les écrire, ne pas
les masquer :

**1. Le mal-posé du CCC est inhérent à Sentinel-2.** L'inversion du Cab est mal
contrainte par S2 — inverser localement **ne le rend pas plus fiable** que le CCC
de GEODES. Même limite physique. Le CCC reste le maillon faible, **gaté sur une
mesure de confiance** (§8) avant tout usage dur.

**2. On n'a ni validation ni masque qualité « gratuits ».** GEODES est validé au
niveau national et livre une confiance par pixel ; une inversion locale n'a
**rien de tel** par défaut. Deux réponses, non exclusives :
- **valider** contre GEODES (§5) pour caractériser le biais une fois ;
- **construire notre propre confiance** par pixel (§8) — écart aux bornes
  physiques PROSAIL, résidu de reconstruction spectrale, ou écart local à GEODES.

## 7. Points techniques à trancher

- **Bandes par variable.** Le modèle LAI livré utilise `B4-B5-B8`. Le CCC (Cab)
  et le fAPAR sont sensibles au **red-edge** (B5/B6/B7) : le jeu de bandes optimal
  **diffère par variable**, à établir (D3). D'où `selected_bands = NULL` → défaut
  par variable.
- **Modèles pré-entraînés.** Livrer un `.rds` par variable dans `inst/extdata`
  (comme le LAI), pour que la voie sans `prosail` installé fonctionne en
  `precomputed`. Reproductibles par un script `data-raw/`.
- **Coût.** L'entraînement est **caché** (amorti) ; l'application par tuile est le
  coût courant. À benchmarker, mais du même ordre que le LAI actuel.

## 8. Confiance par pixel (D5 — le vrai chantier)

Sans masque GEODES, construire une confiance interne, alignée sur le système NDP
(ADR-011) : une confiance biophysique 0-1 par pixel (résidu spectral / proximité
des bornes PROSAIL) qui **module la confiance φ** de l'UGF. C'est ce qui ferait de
ces variables une vraie brique NDP, pas juste de meilleurs proxys. Chantier à
isoler, à ne lancer qu'après le socle (§9 lots 1-2).

## 9. Décisions

| # | Décision | Statut |
|---|---|---|
| D1 | ~~Mécanisme d'accès GEODES~~ | **Dissous** — calcul interne, GEODES = validation |
| D2 | CCC : entrée de R5, composante vitalité, ou rien pour l'instant | **Ouverte** (§3) |
| D3 | Jeu de bandes S2 par variable (red-edge pour CCC/fAPAR) | **Ouverte** (§7) |
| D4 | C2 : `fapar` prime sur NDVI, repli NDVI | Proposée (patron `chm=NULL`) |
| D5 | Confiance par pixel modulant φ (interne + validation GEODES) | **Ouverte** (§8) |

## 10. Plan en lots

### Lot 1 — `biophysique_sentinel2()` (socle) — **livré v0.166.0**
`.lai_prosail_train()` / `.lai_prosail_apply()` paramétrés par `parm` (clé de
cache `prosail_<parm>_…`), `lai_sentinel2()` → alias mince de
`biophysique_sentinel2()`. Trois cibles directes (`lai`/`fapar`/`fcover`), CCC
refusé (message → lot 4). Tests voie `precomputed` (pure). **Reste** : modèles
pré-entraînés fAPAR/FVC en `extdata` (voie engine sinon entraînement à la volée)
et bandes optimales par variable (D3) — dépendent de la validation lot 3.

### Lot 2 — Branchements rétrocompatibles
FVC → A1 (déjà câblé, fournir la couche). fAPAR → C2 (`fapar = NULL`, prime sinon
NDVI). LAI → déjà consommé + option C1. Non-régression `chm=NULL`-style : valeur
inchangée sans couche biophysique.

### Lot 3 — Validation contre GEODES
Comparer sur quelques tuiles S2 : biais/RMSE par variable. Caractérise le CCC
avant de l'utiliser. Sortie : verdict de fiabilité par variable, pas une
dépendance.

### Lot 4 — CCC prudent *(D2, après lot 3)*
Brancher le CCC en **entrée** (R5 ou vitalité), **gaté sur la confiance** (§8).
Jamais un indicateur autonome tant que le lot 3 n'a pas conclu.

### Lot 5 — Confiance par pixel *(D5, optionnel)*
Le chantier §8. À isoler.

## 11. Hors périmètre

- Quatre indicateurs biophysiques distincts dans la famille C — **refusé** (§3).
- Consommer GEODES comme source de données — **abandonné** au profit du calcul
  interne (§5).
- Le badge de provenance/qualité côté app — relève de `nemetonshiny`.
