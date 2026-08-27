# Spécification Fonctionnelle : Intégration Open-Canopy

**Version** : 0.2.0 (draft validé)
**Date** : 2026-04-17
**Statut** : Draft — décisions validées, prêt pour tasks.md
**Auteur** : Pascal Obstétar (via Claude)
**Cible nemeton** : v0.16.0

---

## 1. Résumé Exécutif

### 1.1 Vision

Faire consommer par le cœur `nemeton` les **CHM (Canopy Height Models) produits par le package `opencanopy`** (pobsteta/opencanopy) afin d'améliorer substantiellement la qualité des indicateurs de production (P1, P2) et quelques indicateurs connexes (C1, B2, R2) **dès NDP 0-1**, là où aujourd'hui la hauteur de canopée n'est disponible qu'à partir de NDP 1 (via LiDAR HD).

### 1.2 Principe

`opencanopy` adapte les modèles UNet/PVTv2 Open-Canopy (entraînés sur SPOT 6-7 à 1.5 m) aux **ortho IGN BD ORTHO® (RVB + IRC à 0.20 m)**. Le cœur `nemeton` n'exécute pas les modèles : il consomme en entrée un **raster CHM géoréféré** produit par `opencanopy`, via la couche d'abstraction `get_data_source()` (ADR-002).

### 1.3 Objectifs métier

| Objectif | Métrique de succès |
|----------|-------------------|
| Fournir une hauteur de canopée à NDP 0-1 sans LiDAR HD | CHM disponible partout où l'IGN BD ORTHO est disponible (France entière) |
| Améliorer P2 (indice de station) | Passage d'un proxy climat×sol à la méthode H(âge) textbook (Duplat & Tran-Ha) |
| Améliorer P1 (volume bois) | RMSE attendue réduite de 20-40 % à NDP 0 |
| Ne pas alourdir le cœur | `nemeton` reste R-pur, la dépendance Python/PyTorch reste dans `opencanopy` |

### 1.4 Hors-scope

- Entraînement ou fine-tuning de modèles CHM (géré par `opencanopy` ou en amont)
- Inférence en temps réel depuis `nemeton` (le CHM est un artefact pré-calculé)
- Détection de changement (Open-Canopy-Δ) — sujet d'un spec ultérieur, voir §6

---

## 2. Architecture

### 2.1 Position dans les packages

```
┌──────────────────────────┐
│   opencanopy            │  (pobsteta/opencanopy, v0.1.0)
│   R + reticulate + torch │
│   Produit : CHM COG      │  ← sortie standard : Cloud-Optimized GeoTIFF
└────────────┬─────────────┘
             │ artefact raster (CHM, EPSG:2154)
             ▼
┌──────────────────────────┐
│   nemeton (ce repo)      │
│   get_data_source("chm") │
│   sanitize_chm()         │  ← masquage forêt/bâti/eau/NDVI/pente
│   compute_site_index()   │  ← courbes Duplat & Tran-Ha (nouveau)
│   indicator_productive_* │
│   indicator_carbon_*     │
└──────────────────────────┘
```

`opencanopy` devient une source de données au même titre que `tree_sat_nemeton` (essences) ou `maestro_nemeton` (essences+MNT). Pas de dépendance R de `nemeton` vers `opencanopy` : l'utilisateur appelle `opencanopy::pipeline_aoi_to_chm()` en amont, puis pointe `nemeton` vers le CHM produit.

### 2.2 Flux de données (Épaississement 5, vue AOI)

```
AOI (GeoPackage)
   │
   ├─► opencanopy::pipeline_aoi_to_chm(format = "COG")
   │      ├─ télécharger ortho IGN RVB + IRC via WMS
   │      ├─ agréger 0.20 m → 1.5 m
   │      ├─ inférer (UNet ou PVTv2) via reticulate
   │      └─ produire chm.tif (COG, 1.5 m, EPSG:2154)
   │
   └─► nemeton_compute(units, layers = list(chm = "chm.tif", ...))
          ├─ detect_ndp() → list(level=0, augmented=c("height_ml"))
          ├─ sanitize_chm(chm, forest_mask, buildings, water, ndvi)
          ├─ indicator_productive_volume() utilise H_CHM (P1)
          ├─ indicator_productive_station() via compute_site_index() (P2)
          ├─ indicator_carbon_biomass() mode allométrique H-based (C1)
          └─ indicator_biodiversity_structure() utilise CV(H_CHM) (B2)
```

### 2.3 NDP augmenté : amendement ADR-011

**Décision validée** : extension du système NDP existant via un flag vectoriel `augmented`, **sans** créer une dimension NDA parallèle.

**Rationale** :
- Un CHM ML (RMSE ~2-3 m) ne vaut pas un CHM LiDAR HD (RMSE ~30 cm). Gonfler la confiance φ Fibonacci fausserait le signal utilisateur.
- `compute_general_index_mixed()` permet déjà un NDP par indicateur : la granularité existe.
- Une seule dimension = UI lisible, documentation simple.

**API** :
```r
detect_ndp(units)
# → list(
#     level       = 0,
#     confidence  = 0.083,
#     augmented   = c("height_ml"),   # vecteur : "height_ml", "species_ml", ...
#     sources     = list(...)
#   )
```

**UI** (dans `nemetonshiny`) : badge principal inchangé « NDP 0 · 8,3 % ». Tag supplémentaire à côté : « ⚡ hauteur ML ». Le tag ne modifie pas φ global, mais `compute_general_index_mixed()` peut utiliser `augmented` pour pondérer P2 avec un poids Fibonacci équivalent NDP 1 localement.

Un **amendement ADR-011** sera rédigé en parallèle pour documenter la sémantique du flag.

---

## 3. Impact par indicateur

### 3.1 Famille P (Production & Économie)

| Ind. | Avant (NDP 0) | Après | Gain attendu |
|------|---------------|-------|--------------|
| **P1 volume** | allométrie IFN `V = f(D, espèce)` sans H → proxy grossier | `V = f(D, H_CHM, espèce)` | RMSE -20 à -40 % |
| **P2 station** | proxy fertilité × climat × espèce | courbes **Duplat & Tran-Ha** : indice de station = H₀ @ âge_ref | de « proxy » à « estimation sérieuse » |
| **P3 qualité** | forme, diamètre, défauts | marginal : CV spatial du CHM comme proxy d'hétérogénéité | +5 à 10 % au mieux |

### 3.2 Autres indicateurs sensibles à H

| Ind. | Usage du CHM | Gain |
|------|--------------|------|
| **C1 biomasse** | relation allométrique H-biomasse comme alternative à l'âge | +10-20 % précision NDP 0 |
| **B2 structure** | coefficient de variation du CHM (hétérogénéité verticale) | affine le score Shannon multi-strates |
| **R2 tempête** | H élevée = vulnérabilité accrue | calibre directement au lieu d'un proxy âge |
| **N3 naturalité** | intègre déjà N1×N2×T1×B1 — CHM peut affiner B2 dedans | indirect |

### 3.3 NDVI en bonus

`opencanopy` produit également NDVI/GNDVI/SAVI depuis l'IRC. Ces couches peuvent nourrir :
- **C2 NDVI** directement (vitalité)
- **A1 couverture arborée** (seuillage NDVI alternatif à OSO)
- **F2 érosion** (facteur protection sol)

À documenter comme effet de bord positif ; non bloquant pour les phases 1-4.

### 3.4 Amendement (v0.107.0) — sémantique « couvert nul »

**Contexte.** Sur une parcelle **rasée (coupe rase entière)**, le CHM
Open-Canopy est *correct* mais à hauteur ≈ 0 (H_dom ≈ 0). L'inventaire
synthétique (`estimate_synthetic_inventory()` → `estimate_dq_from_hdom()`)
renvoyait alors **NA** (la garde « H_dom < 6 m ⇒ allométrie non calibrée »
traitait le couvert nul comme un peuplement « trop jeune »). Conséquence
observée (projet `20260624_073705_armn`, secteur Mouthe) : **P1, P3, E1 tous
NA**, E2 dégénéré à 0, et **famille Énergie absente** — au lieu du résultat
correct d'une coupe rase : volume ≈ 0, E1 ≈ 0, **famille Énergie présente à 0**.

**Décision.** Distinguer trois régimes selon H_dom :

| H_dom | Interprétation | D_g / N | Indicateurs |
|-------|----------------|---------|-------------|
| `NA` (pas de couverture CHM) | inconnu | `NA` | P1/P3/E1 = `NA` (légitime) |
| `< min_stand_height` (défaut 1,3 m) | **pas de peuplement** (coupe rase, coupé, non-forêt) | **0 / 0** | P1 = 0, P3 défini bas, E1 = 0 |
| `[min_stand_height, 6 m)` | peuplement jeune, allométrie non calibrée | `NA` | inchangé (`NA`) |
| `≥ 6 m` | peuplement établi | allométrie IFN/Charru | inchangé |

Seuil `min_stand_height = 1,3 m` (hauteur de référence du dbh) : en deçà, le
dbh est nul par définition ⇒ pas de stock sur pied. Paramètre exposé sur
`estimate_synthetic_inventory()` et `ensure_inventory_fields()`.

**Invariants.** (1) Un CHM normal (peuplement établi) est inchangé
(non-régression). (2) `H_dom = NA` reste `NA` (on ne force pas 0 sur une absence
de donnée). (3) Le correctif est côté **cœur** : il vaut quel que soit le wiring
CHM de l'app — une coupe rase renvoie désormais 0, pas `NA`.

### 3.5 Amendement (v0.109.0) — dette H_dom faible/nul (items #1, #2, #3)

Le §3.4 laissait trois angles morts, traités ici ensemble car tous portent sur
la sémantique d'un H_dom faible ou nul.

**#2 — peuplement jeune `[1,3 ; 6)` m.** Le §3.4 laissait ce régime à `NA`. Or
un peuplement pré-marchand n'a **pas de volume marchand** (P1/P3/E1 ≈ 0), pas un
volume « inconnu ». On introduit `min_merchantable_height` (défaut **6 m**, le
plancher de calibration de l'allométrie) : en deçà, `D_g = 0`, `N = 0`. Le
tableau §3.4 devient :

| H_dom | Interprétation | D_g / N | P1/P3/E1 |
|-------|----------------|---------|----------|
| `NA` | pas de couverture CHM | `NA` | `NA` |
| `< min_merchantable_height` (6 m) | pas de stock marchand (rasé **ou** jeune) | **0 / 0** | **0** |
| `≥ 6 m` | peuplement établi | allométrie IFN/Charru | inchangé |

Le test porte sur la **hauteur**, pas sur `is.na(D_g)` : un peuplement de 25 m
dont l'espèce est manquante garde `D_g = NA` (réellement inconnu), il n'est
**jamais** forcé à 0. `min_stand_height` (1,3 m) subsiste pour documenter le
sous-cas « rasé » ; l'escape hatch de rétro-compatibilité v0.107.0 est
`min_merchantable_height = min_stand_height`.

**#3 — P2 station sur couvert nul.** `indicateur_p2_station()` passe par
`compute_site_index()`, pas par `ensure_inventory_fields()` : sur H_dom = 0 il
*clampait* vers la pire classe de fertilité (valeurs parasites + `NA`
hétérogènes). Or l'indice de station est une propriété de la **station**
(potentiel sol/climat), pas du peuplement abattu : il n'est **pas estimable**
depuis un CHM nu. `compute_site_index()` reçoit `min_stand_height = 1,3` ; en
deçà ⇒ **`NA`**. Cohérence : sur une coupe rase, **P1 = 0** (aucun volume
marchand *actuel*) mais **P2 = `NA`** (fertilité potentielle *inconnue* depuis
cette donnée) — deux réponses honnêtes et distinctes.

**#1 — garde-fou CHM dégénéré.** « Couvert nul ⇒ 0 » (§3.4/#2) masque un CHM
**cassé** (prédiction ratée, tout à 0) : on renverrait volume 0 partout sans
signal. `estimate_synthetic_inventory()` gagne un garde-fou heuristique : si
`suspect_frac` (défaut **0,95**) des unités observées sont sous le plancher
marchand **et** que le maximum global du CHM est lui-même sous ce plancher, on
émet un `cli::cli_warn` (« CHM dégénéré, vérifier ») et on pose
`attr(result, "chm_suspect") = TRUE`, propagé par `ensure_inventory_fields()`
sur l'`sf`. Une vraie coupe rase intégrale déclenche aussi l'alerte — c'est un
*heads-up* de vérification, et « volume 0 » reste alors l'action correcte.

**Invariants (inchangés + ajouts).** (4) Un peuplement à espèce manquante mais
grand reste `NA` (le seuil est en hauteur). (5) Le garde-fou #1 est un
**avertissement**, jamais une erreur — il ne bloque aucun calcul.

---

## 4. Interfaces techniques

### 4.1 Abstraction `get_data_source()`

Enrichir `R/datasources.R` (ADR-002) avec un type `chm_opencanopy` :

```r
sources <- list(
  chm_opencanopy = list(
    type          = "raster_local",
    format        = "COG",                  # Cloud-Optimized GeoTIFF obligatoire
    description   = "Canopy Height Model from opencanopy (IGN ortho + Open-Canopy models)",
    required_crs  = "EPSG:2154",            # Lambert-93 ; EPSG:3035 en phase paneuropéenne
    resolution_m  = c(0.20, 1.5),
    unit          = "m",
    value_range   = c(0, 50),               # bornes plausibles forêt FR
    provenance    = list(
      package     = "opencanopy",
      version_min = "0.1.0",
      model       = c("unet", "pvtv2"),
      base_data   = "BD ORTHO IGN + Open-Canopy pretrained"
    ),
    license       = list(
      bd_ortho    = "Etalab 2.0",
      open_canopy = "MIT/CC-BY-4.0 (à confirmer au commit)",
      derived     = "CHM = double attribution IGN + Fogel et al. 2024"
    )
  )
)
```

### 4.2 API publique minimale dans `nemeton`

```r
# Nouveau paramètre optionnel dans nemeton_compute()
nemeton_compute(
  units,
  layers = list(
    ...,
    chm = "/path/to/chm.tif",            # raster COG produit par opencanopy
    chm_source = "opencanopy"             # provenance tracée
  ),
  indicators = "all"
)

# Détection enrichie
detect_ndp(units)                         # → NDP 0 + augmented = "height_ml"

# Sanitisation
sanitize_chm(chm, forest_mask = bd_foret, buildings = bd_topo, water = bd_carthage,
             ndvi = ndvi_raster, ndvi_threshold = 0.3, max_height = 50)
# → list(chm_clean = <SpatRaster>, pct_masked = 0.23)

# Indice de station
compute_site_index(H_dom, age, species)   # courbes Duplat & Tran-Ha
```

### 4.3 Courbes de station — Duplat & Tran-Ha (1997)

**Stockage** : `inst/extdata/site_index_curves.csv`

Colonnes : `species, age, class_1, class_2, class_3, class_4, class_5` (H₀ en m par classe de fertilité IFN).

**10 essences MVP** (>90 % des surfaces productives FR) :

| Essence | Latin | Source |
|---------|-------|--------|
| Chêne sessile | *Quercus petraea* | Duplat & Tran-Ha 1997 |
| Chêne pédonculé | *Quercus robur* | Duplat & Tran-Ha 1997 |
| Hêtre | *Fagus sylvatica* | Duplat & Tran-Ha 1997 |
| Châtaignier | *Castanea sativa* | Duplat & Tran-Ha 1997 |
| Épicéa commun | *Picea abies* | Duplat & Tran-Ha 1997 |
| Sapin pectiné | *Abies alba* | Duplat & Tran-Ha 1997 |
| Douglas | *Pseudotsuga menziesii* | DSF / IRSTEA |
| Pin sylvestre | *Pinus sylvestris* | Duplat & Tran-Ha 1997 |
| Pin maritime | *Pinus pinaster* | IFN Landes |
| Peuplier cultivé | *Populus sp.* | CNPF |

**Fallbacks** :
- Feuillu inconnu → courbe chêne sessile
- Résineux inconnu → courbe épicéa commun

### 4.4 Fonction `sanitize_chm()`

Située dans `R/utils-chm.R` (nouveau). Pipeline en 5 étapes, toutes configurables :

1. **Masque forêt** (obligatoire) : `chm[!forest_mask] <- NA`. Source BD Forêt v2 (par défaut) ou OSO.
2. **Masque bâti + eau** : BD TOPO bâti + BD CARTHAGE hydrographie → NA.
3. **Seuillage NDVI** (si IRC disponible) : `chm[ndvi < 0.3] <- NA`.
4. **Bornes plausibles** : `chm[chm > 50 | chm < 0] <- NA` (configurable via `max_height`).
5. **Cohérence pente** (optionnel) : `chm[slope > 60°] <- NA`.

Sortie : `list(chm_clean, pct_masked, steps_applied)`. Un `pct_masked > 0.5` déclenche un `cli::cli_warn()` — probable problème d'alignement ou de millésime.

### 4.5 Modifications par indicateur (extraits)

- `R/indicators-productive.R::indicator_productive_volume()` : branche CHM-based (`V = f(D, H, espèce)`) active si `layers$chm` présent
- `R/indicators-productive.R::indicator_productive_station()` : délègue à `compute_site_index()` quand CHM présent
- `R/indicators-biodiversity.R::indicator_biodiversity_structure()` : intègre `cv_chm = sd(H)/mean(H)` comme composante optionnelle de B2

Tout est **rétrocompatible** : si `chm` absent, comportement actuel inchangé.

---

## 5. Plan d'implémentation

### Phase 1 — Tuyauterie cœur + ADR
- [ ] Amendement **ADR-011** : flag vectoriel `augmented` dans la détection NDP
- [ ] `R/datasources.R` : type `chm_opencanopy` avec format COG + license
- [ ] `R/ndp.R::detect_ndp()` : retourne également `augmented`
- [ ] `R/utils-chm.R` : `sanitize_chm()` + tests
- [ ] Fixture de test : CHM synthétique 20 m × 20 m sur `massif_demo` au format COG
- [ ] `inst/NOTICE` : attributions IGN BD ORTHO + Fogel et al.

### Phase 2 — P2 station (gain le plus élevé)
- [ ] `inst/extdata/site_index_curves.csv` — Duplat & Tran-Ha, 10 essences + fallbacks
- [ ] `R/indicators-productive.R::compute_site_index(H, age, species)`
- [ ] Branche CHM-based dans `indicator_productive_station()`
- [ ] Tests + vignette « Indice de station à NDP 0 avec Open-Canopy »

### Phase 3 — P1 volume
- [ ] Étendre `indicator_productive_volume()` : allométries `V = f(D, H, espèce)`
- [ ] Comparaison P1-sans-CHM vs P1-avec-CHM sur `massif_demo`
- [ ] Tests

### Phase 4 — Indicateurs connexes
- [ ] C1 biomasse : mode allométrique H-based
- [ ] B2 structure : composante `cv_chm`
- [ ] R2 tempête : calibration directe H → vulnérabilité

### Phase 5 — NDVI en bonus (optionnel)
- [ ] Connexion NDVI (sortie `opencanopy`) → C2, A1, F2

### Phase 6 — UI (`nemetonshiny`, hors cœur)
- [ ] Sélecteur de source CHM dans l'assistant projet
- [ ] Badge « ⚡ hauteur ML » à côté du badge NDP
- [ ] Lien vers documentation `opencanopy`

### Phase 7 — Mosaïquage à l'échelle (post-MVP)
- [ ] Cache par dalle IGN dans `~/.local/share/nemeton/chm_cache/` + index DuckDB
- [ ] Préparation S3 (ADR-002) pour un COG France entière à terme

---

## 6. Extensions ultérieures (hors scope 005)

- **Open-Canopy-Δ** : détection de changement de hauteur entre deux millésimes d'ortho
  - T2 changement d'occupation
  - R2 post-tempête (dégâts cartographiés)
  - Dynamique P1/P2 (accroissement annuel réel)
- **Pipeline automatisé** : appeler `opencanopy::pipeline_aoi_to_chm()` directement depuis `nemetonshiny` via `reticulate` côté serveur (coûteux GPU → ADR-003 Scaleway L4 ponctuel)
- **Fusion avec LiDAR HD** : quand disponible, préférer le CHM LiDAR, Open-Canopy en fallback
- **COG France entière** hébergé sur S3, accès par `terra::rast("s3://...")` + window (phase 7+)

---

## 7. Décisions validées

| # | Sujet | Décision |
|---|-------|----------|
| D1 | Licence | BD ORTHO Etalab 2.0 + Open-Canopy (MIT/CC-BY à confirmer) ; CHM dérivé = double attribution IGN + Fogel et al. ; fichier `inst/NOTICE` |
| D2 | NDP vs NDA | **Option A** : amendement ADR-011, flag vectoriel `augmented` (`"height_ml"`, `"species_ml"`, ...) ; confiance φ Fibonacci inchangée ; granularité fine via `compute_general_index_mixed()` |
| D3 | Courbes station | **Duplat & Tran-Ha 1997**, 10 essences MVP, `inst/extdata/site_index_curves.csv`, fallback chêne sessile (feuillus) / épicéa (résineux) |
| D4 | Masquage | `nemeton::sanitize_chm()` côté cœur, pipeline 5 étapes (forêt, bâti/eau, NDVI, bornes 0-50 m, pente 60°), alerte si `pct_masked > 50 %` |
| D5 | Mosaïquage | MVP AOI-driven (pipeline `opencanopy` existant) ; **format COG obligatoire** dès le début ; cache dalles IGN en phase 7+ ; S3 / COG France entière post-MVP |

---

## 8. Références

- ADR-009 (séparation 4 packages)
- ADR-011 (NDP, Fibonacci, φ) — **à amender pour le flag `augmented`**
- ADR-002 (abstraction sources de données)
- Package `opencanopy` v0.1.0 : https://github.com/pobsteta/opencanopy
- Dataset Open-Canopy : https://huggingface.co/datasets/AI4Forest/Open-Canopy
- Fogel et al. 2024, arXiv:2407.09392
- BD ORTHO® IGN : https://geoservices.ign.fr/bdortho
- Duplat, P., & Tran-Ha, M. (1997). *Modelling and simulation of stand growth of oak and beech in France: The model PNN*. IFN.
- Bontemps, J.-D., Duplat, P. (2012). *A non-asymptotic sigmoid growth curve for top height growth in forest stands.* Forestry.
