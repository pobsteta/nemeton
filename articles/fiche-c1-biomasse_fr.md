# Fiche indicateur C1 - Biomasse carbone

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Complète et détaille la ligne `C1` du tableau récapitulatif
> `docs/TABLEAU_INDICATEURS_NDP.md`, resté à la v0.14.1 et qui ignore le
> chemin CHM introduit par la spec 005.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `C1` |
| Nom long / colonne | `indicateur_c1_biomasse` |
| Famille | **C — Carbone & Vitalité** (avec `C2` NDVI), couleur `#228B22` |
| Grandeur mesurée | Stock de carbone de la **biomasse aérienne** (troncs, branches, écorce) |
| Unité brute | **tC/ha** (tonnes de carbone par hectare) |
| Sens | Haut = favorable (pas d’inversion à la normalisation) |
| Normalisation | `ref_max = 150 tC/ha` → `score = min(100, valeur / 150 × 100)` |
| Fonction | [`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md) — `R/indicators-families.R:337` |
| Statut normalisation | listé dans `.NORMALIZE_RULED` (`R/normalization.R:550`) : règle explicite, jamais d’écrêtage naïf |
| Tests | `tests/testthat/test-indicators-carbon.R`, `test-family-normalisation.R` |

Ce que C1 **ne** mesure **pas** : le carbone du sol, la litière, les
racines (pas de facteur racinaire `R` de l’IPCC), ni le carbone stocké
dans les produits bois. C’est un stock aérien instantané, pas un flux de
séquestration — le flux est porté par `E2` (évitement carbone).

------------------------------------------------------------------------

## 2. Le principe : cinq chemins, un aiguillage par la donnée disponible

C1 n’a pas « une » formule mais **cinq chemins de calcul**, essayés dans
un ordre fixe. Le premier dont les entrées sont présentes gagne, les
suivants ne sont pas évalués. **Point capital : l’aiguillage se fait sur
la forme de la donnée reçue (colonnes de l’`sf`, couches du
`nemeton_layers`, argument `chm`), jamais sur le NDP.** Le NDP est un
*constat* posé par
[`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
sur les mêmes sources ; il qualifie le résultat, il ne le pilote pas.

| Ordre | Chemin | Condition de déclenchement | Ligne |
|----|----|----|----|
| 0 | **CHM + tarif IFN** | `chm` fourni **et** colonnes `species` **et** `dbh` | `:352` |
| 1 | **Allométrie âge/densité** | colonnes `species` + `age` + `density` | `:398` |
| 2 | **LiDAR MNH** | couche raster `lidar_mnh` dans `layers` | `:411` |
| 3 | **BD Forêt V2** | couche vecteur `bdforet` → enrichit puis retombe sur le chemin 1 | `:443` |
| 4 | **NDVI** | couche raster `ndvi` dans `layers` | `:456` |
| — | *Aucun* | rien de ce qui précède | `:469` → `NA` + `cli_alert_warning` |

Conséquence pratique : un projet qui possède **à la fois** un CHM avec
`dbh` et un inventaire terrain `age`/`density` sera calculé par le
chemin 0, pas par le chemin 1 — ce qui est le bon choix (le tarif de
cubage est mieux fondé que l’allométrie sur l’âge), mais ce n’est pas ce
que « NDP 3 » laisserait deviner.

------------------------------------------------------------------------

## 3. Le calcul par niveau NDP

### NDP 0 — Découverte (Fibonacci 1, confiance φ 8,3 %)

**Sources** : Sentinel-2, WorldClim, BD TOPO, MNT 25 m. **Chemin
retenu** : 4 (NDVI) ou 3 (BD Forêt V2 si la couche est chargée).

#### 3.0.a Chemin 4 — proxy NDVI

    C1 = max(0, NDVI_moyen_zonal) × 150

`R/indicators-families.R:456-467`. Le NDVI moyen est extrait par unité
(`safe_extract`, `fun = "mean"`), puis multiplié par 150 — la constante
est choisie pour qu’un couvert dense (NDVI ≈ 0,85) rende ~128 tC/ha,
dans la fourchette « forêt tempérée mature 80–150 tC/ha » citée en
commentaire du code.

> **C’est un proxy linéaire non calibré, pas un modèle de biomasse.** Le
> NDVI sature autour de 0,8–0,9 bien avant que la biomasse ne sature ;
> deux peuplements de 60 et 200 tC/ha peuvent rendre le même NDVI. À NDP
> 0 sans CHM, C1 mesure surtout « il y a de la végétation verte », et la
> normalisation `/150` rend alors, par construction,
> `score = NDVI × 100`.

**Exemple chiffré** — hêtraie fermée, NDVI moyen 0,72 :

| Étape        | Valeur                             |
|--------------|------------------------------------|
| NDVI zonal   | 0,72                               |
| C1 brut      | 0,72 × 150 = **108 tC/ha**         |
| C1 normalisé | min(100, 108/150 × 100) = **72,0** |

#### 3.0.b Chemin 3 — BD Forêt V2

[`enrich_parcels_bdforet()`](https://pobsteta.github.io/nemeton/reference/enrich_parcels_bdforet.md)
(`R/utils.R:1118`) intersecte les parcelles avec la BD Forêt V2, retient
l’essence **dominante en surface** par parcelle, la traduit en nom de
modèle allométrique (`map_essence_to_species()` : chêne→`Quercus`,
hêtre→`Fagus`, pin/épicéa→`Pinus`, sapin/douglas→`Abies`, sinon
`Generic`), puis **délègue au chemin 1**. Si aucune essence n’est
retrouvée (`all(is.na(enriched$species))`), on retombe sur le chemin 4.

> **À savoir avant d’interpréter** : `age` et `density` ne sont **pas**
> lus dans la BD Forêt — ils sont **écrits en dur**, `age = 60` et
> `density = 0,7` pour toutes les parcelles (`R/utils.R:1206-1207`). Ce
> chemin ne fait donc varier C1 **que par l’essence dominante**, sur
> cinq valeurs possibles :

| Essence déduite | C1 brut    | C1 normalisé |
|-----------------|------------|--------------|
| Fagus           | 14,1 tC/ha | 9,4          |
| Abies           | 10,0 tC/ha | 6,7          |
| Generic         | 7,9 tC/ha  | 5,3          |
| Quercus         | 7,6 tC/ha  | 5,1          |
| Pinus           | 4,3 tC/ha  | 2,9          |

> Autrement dit : à NDP 0, charger la BD Forêt **remplace** un proxy
> NDVI qui discrimine mal (§3.0.a) par une constante par essence qui ne
> discrimine pas du tout, et 5 à 10 fois plus basse. Tant que
> l’allométrie âge/densité n’est pas recalibrée (§ NDP 3), ce chemin est
> le maillon faible de la cascade.

### NDP 0 « augmenté » — flag `height_ml` (Fibonacci 1, confiance φ inchangée)

C’est le cas le plus important en production aujourd’hui, et il n’existe
pas dans l’ancien tableau. Un **CHM prédit par apprentissage** (FORMS-T,
FORMSpoT, Open-Canopy) est une donnée publique : il **ne change pas le
niveau NDP**, il pose un drapeau vectoriel `augmented = "height_ml"`
([`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md),
`R/ndp.R:307`, ADR-011 amendé). Mais il débloque le chemin 0, de loin le
mieux fondé.

**Chemin retenu** : 0 (CHM + tarif IFN).

    H_dom   = quantile(CHM ∩ unité, p = 0,9)                    extract_h_dom()
    V_arbre = a_essence × D²  × H_dom                            tarif IFN à variable combinée
    C1      = V_arbre × ρ_essence/1000 × BEF × C_frac × N        tC/ha

avec, `R/indicators-families.R:352-393` :

| Paramètre | Source | Valeur |
|----|----|----|
| `a`, `b`, `c` | `inst/extdata/ifn_volume_equations.csv`, `lookup_ifn_equation()` | `b = 2.0`, `c = 1.0` sur les 25 lignes ; `a` = facteur de forme 0,42–0,57 ×10⁻⁴ |
| `ρ` (densité du bois) | `inst/extdata/wood_density.csv`, `lookup_species_threshold()` | 430 (ABAL) à 690 kg/m³ (QUPE) |
| `C_frac` | même table, colonne `carbon_content_fraction` | 0,50 |
| `BEF` | argument `bef` de la fonction | **1,30** (défaut IPCC 2006 forêt tempérée) |
| `N` (tiges/ha) | colonne `stems_ha`, sinon `density × 500`, sinon 300 | — |
| `p` (percentile H) | argument `h_dom_percentile` | 0,9 |

Repli essence : une essence absente de la table bascule sur
`CONIFER_GENUS` ou `BROADLEAF_GENUS` via
[`is_conifer()`](https://pobsteta.github.io/nemeton/reference/is_conifer.md).
Une essence, un `dbh` ou un `H_dom` manquant rend `NA` pour l’unité, pas
0.

**D’où viennent `dbh` et `stems_ha` quand il n’y a pas d’inventaire ?**
De l’**inventaire synthétique**
([`estimate_synthetic_inventory()`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md),
`R/synthetic_inventory.R:246`, « chemin NDP 1 synthétique » de la spec
005) :

    D_g = a_essence × H_dom^0,9              allométrie Charru 2012 × 2017, bornée [dq_min, dq_max]
    N   = N_max(D_g, essence) × stocking     auto-éclaircie Charru 2012, stocking = 0,75

**Exemple chiffré** — hêtraie (FASY), CHM FORMS-T (hauteur en cm ⇒
**diviser par 100** avant de la passer en argument `chm`), H_dom p90 =
24 m :

| Étape            | Calcul                         | Valeur             |
|------------------|--------------------------------|--------------------|
| D_g              | 1,523 × 24^0,9                 | **26,6 cm**        |
| N_max            | exp(9,790 − 0,296 × ln(26,6)²) | 738 tiges/ha       |
| N retenu         | 738 × 0,75                     | **553 tiges/ha**   |
| V/arbre          | 0,000039 × 26,6² × 24          | **0,662 m³**       |
| Masse de tige    | 0,662 × 680/1000               | 0,450 t            |
| AGB totale       | × 1,30 (BEF)                   | 0,585 t            |
| Carbone/arbre    | × 0,50                         | 0,293 tC           |
| **C1 brut**      | × 553                          | **162 tC/ha**      |
| **C1 normalisé** | min(100, 162/150 × 100)        | **100,0 — saturé** |

> Le plafond de 150 tC/ha est franchi par une hêtraie mûre parfaitement
> ordinaire. Sur un projet dominé par des peuplements adultes, ce chemin
> écrase la variabilité inter-unités en haut d’échelle. À garder en tête
> avant de lire un `famille_carbone` : un 100 peut vouloir dire 152
> comme 300 tC/ha.

Sources CHM déclarées et câblées sur C1 (`inst/datasources/FR.json`, clé
`consumed_by`) :

| Source | Résolution | Unité stockée | Conversion à faire |
|----|----|----|----|
| `forms_t` (produit `height`) | 10 m | **cm** | `chm = raster / 100` |
| `formspot` (produit `height`) | arbre, sub-métrique | **dm** | `chm = raster / 10` |
| `chm_opencanopy` | selon BD ORTHO | m | aucune |
| `theia_species` | 10 m | classe | fournit `species` |

Avant usage, le CHM doit passer par
[`sanitize_chm()`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md)
(`R/utils-chm.R:109`) : masque forêt → masque bâti/eau → seuil NDVI →
bornes de hauteur plausibles → masque de pente. Elle rend
`list(chm_clean, pct_masked, steps_applied)`.

### NDP 1 — Observation (Fibonacci 1, confiance φ 16,7 %)

**Sources ajoutées** : IGN RGE ALTI, BD ORTHO, **LiDAR HD**. **Chemin
retenu** : 0 si un `dbh` est disponible (le MNH LiDAR est alors passé en
`chm`, flag `augmented = "height_lidar"`), **sinon 2**.

#### Chemin 2 — modèle LiDAR MNH (tutoriel 02)

    pzabove2 = 100 × part des pixels MNH > 2 m          (taux de couvert)
    zmean    = moyenne des pixels MNH > 2 m             (hauteur DE LA CANOPÉE)
    AGB      = 2,5 × (pzabove2/100) × zmean^1,5
    C1       = AGB × 0,47

`R/indicators-families.R:411-441`. `k = 2,5` et fraction carbone `0,47`.

> **Correctif 0.174.0 à connaître** : `zmean` était calculé sur *toutes*
> les cellules, trouées comprises, alors que `pzabove2` porte déjà la
> fraction de couvert — la surface nue pénalisait donc deux fois. Sur le
> projet Fordead, parcelle 1 : 47 % de cellules à exactement 0 m,
> `zmean` 1,04 m sur l’unité contre **6,03 m sur la canopée**, soit C1
> 0,138 au lieu de 1,913 tC/ha. Un facteur 10 à 14 sur trois parcelles.
> Une unité sans aucune cellule de canopée rend désormais **0, pas
> `NA`** : une coupe rase n’est pas une donnée manquante.

**Exemple chiffré** — futaie fermée sur LiDAR HD, 85 % de couvert,
canopée à 18 m :

| Étape            | Calcul              | Valeur         |
|------------------|---------------------|----------------|
| pzabove2         | —                   | 85 %           |
| zmean (canopée)  | —                   | 18 m           |
| AGB              | 2,5 × 0,85 × 18^1,5 | **162,3 t/ha** |
| **C1 brut**      | × 0,47              | **76,3 tC/ha** |
| **C1 normalisé** | 76,3/150 × 100      | **50,8**       |

Pour comparaison, peuplement clair (60 % de couvert, canopée 12 m) : AGB
62,4 → **C1 29,3 tC/ha** → score **19,5**.

### NDP 2 — Exploration (Fibonacci 2, confiance φ 33,3 %)

**Sources ajoutées** : drone RGB, LiDAR drone. **Chemin retenu** :
identique au NDP 1 (chemin 2, ou 0 avec `dbh`) — **seule la résolution
du MNH change**. Aucune branche de code spécifique au drone n’existe
dans
[`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md)
: le MNH drone est consommé comme un MNH LiDAR HD.

> À noter : `detect_ndp_from_cache()` (`R/ndp.R:552`) plafonne
> aujourd’hui à **NDP 1** — « NDP 2+ : pas encore dans le pipeline ». Un
> projet ne dépasse NDP 1 que par les attributs (`has_drone_rgb`,
> `has_lidar_drone`) ou par le comptage de placettes QField
> (`field_plots_count ≥ 1` ⇒ NDP 2).

### NDP 3 — Diagnostic (Fibonacci 3, confiance φ 58,3 %)

**Source ajoutée** : inventaire terrain complet (≥ 10 arbres/placette en
moyenne via QField ⇒ NDP 3). **Chemin retenu** : 0 si `dbh` mesuré + CHM
; **sinon 1**.

#### Chemin 1 — allométrie âge/densité

    C1 = a_essence × âge^b_essence × densité^c_essence

`calculate_allometric_biomass()` / `get_allometric_coefficients()`
(`R/utils.R:618` et `:582`), coefficients dans `R/sysdata.rda`, source
`data-raw/allometric_models.R`. `densité` est ici une **fraction 0–1**,
pas des tiges/ha.

| Essence | a     | b    | c    | Source citée           |
|---------|-------|------|------|------------------------|
| Quercus | 0,012 | 1,65 | 0,85 | Dupouey et al. 2011    |
| Fagus   | 0,015 | 1,75 | 0,90 | Bontemps & Duplat 2012 |
| Pinus   | 0,010 | 1,55 | 0,80 | Vallet & Pérot 2011    |
| Abies   | 0,013 | 1,70 | 0,88 | Wutzler et al. 2008    |
| Generic | 0,011 | 1,68 | 0,85 | Wutzler et al. 2008    |

Essence inconnue → ligne `Generic`. Toute entrée `NA` → `NA`.

**Exemples chiffrés** :

| Essence | Âge | Densité | C1 brut        | C1 normalisé |
|---------|-----|---------|----------------|--------------|
| Quercus | 80  | 0,70    | **12,2 tC/ha** | 8,2          |
| Fagus   | 60  | 0,80    | **15,9 tC/ha** | 10,6         |
| Fagus   | 120 | 0,80    | **53,4 tC/ha** | 35,6         |
| Pinus   | 80  | 0,70    | **6,7 tC/ha**  | 4,5          |
| Abies   | 100 | 0,90    | **29,8 tC/ha** | 19,9         |

> **Anomalie à documenter, pas à ignorer.** Le chemin censé être le
> *plus* précis rend les valeurs les *plus basses* : 6 à 53 tC/ha pour
> des peuplements mûrs, là où les chemins CHM et NDVI rendent 76 à 162
> tC/ha sur des peuplements comparables, et là où le `ref_max` de
> normalisation vaut 150. L’écart est d’un facteur 3 à 10.
> `data-raw/allometric_models.R` l’annonce lui-même : *« These are
> illustrative coefficients based on literature patterns \[…\] In
> production, these would be extracted from the exact published
> equations »*, et vise 50–200 tC/ha — ce que les coefficients livrés ne
> produisent pas. Le test associé ne contrôle qu’un ordre de grandeur
> très large (`> 1` et `< 500`), il ne rattrape donc pas l’écart. **Un
> projet qui bascule du chemin 2 au chemin 1 en acquérant un inventaire
> verra son C1 chuter, et son `famille_carbone` avec.** Le chemin 0
> (CHM + `dbh` mesuré) évite complètement ce problème : c’est celui à
> privilégier dès qu’un diamètre terrain existe.

### NDP 4 — Jumeau (Fibonacci 5, confiance φ 100 %)

**Sources ajoutées** : scanner terrestre (TLS), modèle 3D. **Chemin
retenu** : 0, alimenté par un `dbh` mesuré au ruban/TLS, un `stems_ha`
compté et un CHM très haute résolution. Aucune branche dédiée : le gain
de NDP 4 est un gain de **qualité d’entrées** du même chemin 0, pas un
modèle différent. Le poids Fibonacci passe à 5 et la confiance à 100 %
dans l’indice général.

### Récapitulatif d’une ligne

| NDP | Flag | Chemin | Formule effective | Entrées critiques |
|----|----|----|----|----|
| 0 | — | 4 | `NDVI × 150` | Sentinel-2 |
| 0 | `height_ml` | 0 | `a·D²·H × ρ/1000 × 1,3 × 0,5 × N` | CHM ML + essence (+ D_g synthétique) |
| 0 | — | 3 | → chemin 1 sur attributs BD Forêt | BD Forêt V2 |
| 1 | `height_lidar` | 2 (ou 0) | `2,5 · (pz>2m) · z̄_canopée^1,5 × 0,47` | MNH LiDAR HD |
| 2 | `height_lidar` | 2 (ou 0) | idem, MNH drone | MNH drone |
| 3 | — | 1 (ou 0) | `a · âge^b · densité^c` | essence, âge, densité terrain |
| 4 | — | 0 | tarif IFN sur D et H mesurés | TLS, comptage réel |

------------------------------------------------------------------------

## 4. De la valeur brute au livrable

    indicateur_c1_biomasse()  →  colonne `indicateur_c1_biomasse` (tC/ha) dans l'sf
            │
            ├─ normalize_indicator("indicateur_c1_biomasse", v)      R/normalization.R:588
            │      score = min(100, max(0, v / 150 × 100))
            │      → colonne `C1_norm` (via normalize_indicators(suffix = "_norm"))
            │
            ├─ create_family_index(data, family_codes = "C")         R/family-system.R
            │      famille_carbone = moyenne(C1_norm, C2_norm)       poids égaux par défaut,
            │                                                        surchargeables : list(C = c(C1 = .7, C2 = .3))
            │
            ├─ compute_general_index(family_scores, ndp)             R/ndp.R
            │      moyenne des 12 familles pondérée Fibonacci(NDP) + confiance φ
            │      (compute_general_index_mixed() si le NDP diffère par famille)
            │
            └─ nemeton_radar() / plot_indicators_map()               R/visualization.R

Détails qui comptent :

- [`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
  **normalise elle-même** les colonnes brutes qu’on lui passe. Une
  colonne déjà en `_norm` est simplement écrêtée `[0,100]`, pas
  normalisée deux fois. C1 étant dans `.NORMALIZE_RULED`, il ne
  déclenche jamais l’avertissement « no normalization rule; naively
  clamped ».
- Piège corrigé en 0.174.0 : `normalize_indicator("C1", 75)` et
  `normalize_indicator("indicateur_c1_biomasse", 75)` rendent tous deux
  **50** aujourd’hui. Avant le correctif, le code court tombait sur
  l’écrêtage naïf et rendait 75 — un `famille_carbone` faux sans le
  moindre message.
- `restore_ndp_attributes()` (`R/ndp.R:523`) existe parce que la
  sérialisation Parquet **perd les attributs** : le NDP doit être
  réinjecté depuis les métadonnées du projet après relecture, sinon
  l’indice général est repondéré Fibonacci 1 sans prévenir.

### Ce qui est effectivement livré

**Dans le package cœur (ce dépôt)** — les artefacts sont des *colonnes*
et des *objets R*, pas des fichiers :

| Livrable | Nature | Producteur |
|----|----|----|
| `indicateur_c1_biomasse` | colonne numérique tC/ha de l’`sf` | `nemeton_compute(units, layers, indicators = "indicateur_c1_biomasse")` |
| `C1_norm` | colonne 0–100 | [`normalize_indicators()`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md) |
| `famille_carbone` | colonne 0–100 | [`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md) |
| score global + confiance φ | `list(score, ndp, confidence, weight, n_families)` | [`compute_general_index()`](https://pobsteta.github.io/nemeton/reference/compute_general_index.md) |
| libellés/infobulles FR-EN | `indicator_labels("C1", lang)` | `R/indicator-config.R` |
| fixture de démo | `data(massif_demo_units)` : `C1` (tC/ha, 20–300) et `C1_norm` | `data-raw/massif_demo.R:441` |

**Sur le disque d’un projet** — arborescence attendue, résolue par
[`resolve_project_chm()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)
/
[`resolve_project_dem()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)
(`R/project_layers.R`) :

    <projet>/
    ├── cache/layers/
    │   ├── chm/          ← CHM Open-Canopy      (priorité 1, alimente le chemin 0)
    │   ├── lidar_mnh/    ← MNH LiDAR HD         (priorité 2, chemins 0 et 2)
    │   ├── mnh/          ← MNH générique        (priorité 3)
    │   ├── lidar_nuage/  ← nuage .laz ; MNH recalculé à la volée via lasR si absent
    │   └── chm.tif | mnh.tif                    (fichiers directs)
    ├── data/chm.tif | data/mnh.tif              (dernier recours)
    └── (chm.tif | mnh.tif à la racine — convention opencanopy)

La présence de `cache/layers/lidar_mn[ht]` est aussi ce qui fait
basculer `detect_ndp_from_cache()` de NDP 0 à NDP 1.

**Dans l’application `nemetonshiny`** (dépôt séparé, ADR-009 — le cœur
ne fait qu’exporter, l’app présente) :

- onglet **Carbone & Vitalité (C)** : C1 en tC/ha + son score 0–100,
  libellé et infobulle lus dans le cœur via
  [`indicator_labels()`](https://pobsteta.github.io/nemeton/reference/indicator_labels.md)
  /
  [`indicator_families()`](https://pobsteta.github.io/nemeton/reference/indicator_families.md)
  (API livrée en 0.170.0,
  cf. `specs/BRIEF-indicator-families-export.md`) ;
- **radar de synthèse** : `famille_carbone` sur un des 12 axes ;
- **score global + badge NDP**
  ([`compute_general_index()`](https://pobsteta.github.io/nemeton/reference/compute_general_index.md),
  jamais un
  [`mean()`](https://rspatial.github.io/terra/reference/summarize-generics.html))
  ;
- **perspectives IA** : la valeur C1 et son score entrent dans le prompt
  du profil expert sélectionné (`inst/experts/*.yml`) ;
- **exports** : CSV/Parquet des indicateurs, PDF de plan d’action (spec
  037). ⚠️ Les `indicators.parquet` persistés avec une version **≤
  0.168.0** portent un C1 (et un P1) gonflé ×3–5 par les exposants
  erronés du tarif IFN — corrigés en 0.169.0, spec 040. **Ils doivent
  être recalculés, pas relus.**

------------------------------------------------------------------------

## 5. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgMTA2MCA2NjAiIHN0eWxlPSJ3aWR0aDoxMDAlO2hlaWdodDphdXRvO21heC13aWR0aDoxMDAlIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9IkNoYcOubmUgZGUgY2FsY3VsIGRlIEMxIDogY2lucSBzb3VyY2VzIGQmIzM5O2VudHLDqWUgYWxpbWVudGVudCBjaW5xIGNoZW1pbnMgZGUgY2FsY3VsIGVzc2F5w6lzIGVuIGNhc2NhZGUgOyBsZSBwcmVtaWVyIHNlcnZpIHByb2R1aXQgbGEgY29sb25uZSBlbiB0b25uZXMgZGUgY2FyYm9uZSBwYXIgaGVjdGFyZSwgcXVpIGVzdCBlbnN1aXRlIG5vcm1hbGlzw6llLCBhZ3LDqWfDqWUgZW4gc2NvcmUgZGUgZmFtaWxsZSBDYXJib25lLCBwb25kw6lyw6llIEZpYm9uYWNjaSBkYW5zIGwmIzM5O2luZGljZSBnw6luw6lyYWwsIHB1aXMgbGl2csOpZSBkYW5zIGwmIzM5O2FwcGxpY2F0aW9uIGV0IGxlcyBmaWNoaWVycyBkdSBwcm9qZXQuIj48ZGVmcz48bWFya2VyIGlkPSJhciIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNyIgbWFya2VyaGVpZ2h0PSI3IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PG1hcmtlciBpZD0iYXItYSIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNyIgbWFya2VyaGVpZ2h0PSI3IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSIjMkM2QjYwIiAvPjwvbWFya2VyPjwvZGVmcz48ZyBmaWxsPSJjdXJyZW50Q29sb3IiIGZvbnQtZmFtaWx5PSImIzM5O0JyaWNvbGFnZSBHcm90ZXNxdWUmIzM5OyxzYW5zLXNlcmlmIiBmb250LXNpemU9IjExIiBsZXR0ZXItc3BhY2luZz0iMS40IiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjIwIiB5PSIzMCI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMzIyIiB5PSIzMCI+QUlHVUlMTEFHRSDigJQKUFJFTUlFUiBDSEVNSU4gU0VSVkk8L3RleHQ+PHRleHQgeD0iNzYyIiB5PSIzMCI+QVZBTCBFVApMSVZSQUJMRVM8L3RleHQ+PC9nPjwhLS0gPT09PT09PT09PT09PT09PT0gc291cmNlcyA9PT09PT09PT09PT09PT09PSAtLT48ZyBmb250LWZhbWlseT0iJiMzOTtCcmljb2xhZ2UgR3JvdGVzcXVlJiMzOTssc2Fucy1zZXJpZiI+PGc+PHJlY3QgeD0iMjAiIHk9IjUyIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjcyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzQiIHk9Ijc0IiBmb250LXNpemU9IjEzIiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNITQpNTCBvdSBNTkggTGlEQVIgKyBlc3NlbmNlPC90ZXh0Pjx0ZXh0IHg9IjM0IiB5PSI5MyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNyI+Rk9STVMtVArDtzEwMCDCtyBGT1JNU3BvVCDDtzEwIMK3IE9wZW4tQ2Fub3B5PC90ZXh0Pjx0ZXh0IHg9IjM0IiB5PSIxMTAiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjciPnNhbml0aXplX2NobQrihpIgSF9kb20gcDkwIOKGkiBEX2csIE4gKENoYXJydSk8L3RleHQ+PC9nPjxnPjxyZWN0IHg9IjIwIiB5PSIxNDAiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTYiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzNCIgeT0iMTYyIiBmb250LXNpemU9IjEzIiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkludmVudGFpcmUKdGVycmFpbiAvIFRMUzwvdGV4dD48dGV4dCB4PSIzNCIgeT0iMTgxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43Ij5lc3NlbmNlLArDomdlLCBkZW5zaXTDqSAw4oCTMSDigJQgUUZpZWxkPC90ZXh0PjwvZz48Zz48cmVjdCB4PSIyMCIgeT0iMjEyIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU2IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzQiIHk9IjIzNCIgZm9udC1zaXplPSIxMyIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5NTkgKTGlEQVIgSEQgb3UgZHJvbmU8L3RleHQ+PHRleHQgeD0iMzQiIHk9IjI1MyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNyI+Y291Y2hlCmxheWVycyRsaWRhcl9tbmg8L3RleHQ+PC9nPjxnPjxyZWN0IHg9IjIwIiB5PSIyODQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTYiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzNCIgeT0iMzA2IiBmb250LXNpemU9IjEzIiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkJECkZvcsOqdCBWMjwvdGV4dD48dGV4dCB4PSIzNCIgeT0iMzI1IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43Ij5lc3NlbmNlCmRvbWluYW50ZSBlbiBzdXJmYWNlPC90ZXh0PjwvZz48Zz48cmVjdCB4PSIyMCIgeT0iMzU2IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU2IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzQiIHk9IjM3OCIgZm9udC1zaXplPSIxMyIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5TZW50aW5lbC0yPC90ZXh0Pjx0ZXh0IHg9IjM0IiB5PSIzOTciIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjciPk5EVkkKbW95ZW4gem9uYWw8L3RleHQ+PC9nPjwvZz48IS0tID09PT09PT09PT09PT09PT09IGFycm93cyBzb3VyY2VzIC0+IHJ1bmdzID09PT09PT09PT09PT09PT09IC0tPjxnIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBmaWxsPSJub25lIiBtYXJrZXItZW5kPSJ1cmwoI2FyKSI+PGxpbmUgeDE9IjI4MiIgeTE9Ijg4IiB4Mj0iMzI2IiB5Mj0iODgiPjwvbGluZT48bGluZSB4MT0iMjgyIiB5MT0iMTY4IiB4Mj0iMzI2IiB5Mj0iMTY4Ij48L2xpbmU+PGxpbmUgeDE9IjI4MiIgeTE9IjI0MCIgeDI9IjMyNiIgeTI9IjI0MCI+PC9saW5lPjxsaW5lIHgxPSIyODIiIHkxPSIzMTIiIHgyPSIzMjYiIHkyPSIzMTIiPjwvbGluZT48bGluZSB4MT0iMjgyIiB5MT0iMzg0IiB4Mj0iMzI2IiB5Mj0iMzg0Ij48L2xpbmU+PC9nPjwhLS0gPT09PT09PT09PT09PT09PT0gcnVuZ3MgPT09PT09PT09PT09PT09PT0gLS0+PGcgZm9udC1mYW1pbHk9IiYjMzk7QnJpY29sYWdlIEdyb3Rlc3F1ZSYjMzk7LHNhbnMtc2VyaWYiPjxnPjxyZWN0IHg9IjMzMCIgeT0iNTIiIHdpZHRoPSIzODYiIGhlaWdodD0iNzIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwIiBmaWxsLW9wYWNpdHk9Ii4xMCIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuNiIgLz48dGV4dCB4PSIzNDYiIHk9Ijc0IiBmb250LXNpemU9IjEzIiBmb250LXdlaWdodD0iNzAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPjAKwrcgQ0hNICsgdGFyaWYgSUZOPC90ZXh0Pjx0ZXh0IHg9IjM0NiIgeT0iOTQiIGZvbnQtc2l6ZT0iMTEuNSIgZm9udC1mYW1pbHk9IiYjMzk7SUJNIFBsZXggTW9ubyYjMzk7LG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIj5WCj0gYcK3RMKywrdIX2RvbTwvdGV4dD48dGV4dCB4PSIzNDYiIHk9IjExMSIgZm9udC1zaXplPSIxMS41IiBmb250LWZhbWlseT0iJiMzOTtJQk0gUGxleCBNb25vJiMzOTssbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiPkMxCj0gViDCtyDPgS8xMDAwIMK3IEJFRiAxLDMgwrcgMCw1IMK3IE48L3RleHQ+PC9nPjxnPjxyZWN0IHg9IjMzMCIgeT0iMTQwIiB3aWR0aD0iMzg2IiBoZWlnaHQ9IjU2IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzQ2IiB5PSIxNjIiIGZvbnQtc2l6ZT0iMTMiIGZvbnQtd2VpZ2h0PSI3MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+MQrCtyBBbGxvbcOpdHJpZSDDomdlIC8gZGVuc2l0w6k8L3RleHQ+PHRleHQgeD0iMzQ2IiB5PSIxODIiIGZvbnQtc2l6ZT0iMTEuNSIgZm9udC1mYW1pbHk9IiYjMzk7SUJNIFBsZXggTW9ubyYjMzk7LG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIj5DMQo9IGEgwrcgw6JnZV5iIMK3IGRlbnNpdMOpXmM8L3RleHQ+PC9nPjxnPjxyZWN0IHg9IjMzMCIgeT0iMjEyIiB3aWR0aD0iMzg2IiBoZWlnaHQ9IjU2IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzQ2IiB5PSIyMzQiIGZvbnQtc2l6ZT0iMTMiIGZvbnQtd2VpZ2h0PSI3MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+MgrCtyBNb2TDqGxlIExpREFSIE1OSDwvdGV4dD48dGV4dCB4PSIzNDYiIHk9IjI1NCIgZm9udC1zaXplPSIxMS41IiBmb250LWZhbWlseT0iJiMzOTtJQk0gUGxleCBNb25vJiMzOTssbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiPkMxCj0gMiw1IMK3IHB6Jmd0OzJtIMK3IHrMhF9jYW5vcMOpZV4xLDUgwrcgMCw0NzwvdGV4dD48L2c+PGc+PHJlY3QgeD0iMzMwIiB5PSIyODQiIHdpZHRoPSIzODYiIGhlaWdodD0iNTYiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzNDYiIHk9IjMwNiIgZm9udC1zaXplPSIxMyIgZm9udC13ZWlnaHQ9IjcwMCIgZmlsbD0iY3VycmVudENvbG9yIj4zCsK3IEJEIEZvcsOqdCDihpIgcmFuZyAxPC90ZXh0Pjx0ZXh0IHg9IjM0NiIgeT0iMzI2IiBmb250LXNpemU9IjExLjUiIGZvbnQtZmFtaWx5PSImIzM5O0lCTSBQbGV4IE1vbm8mIzM5Oyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciI+w6JnZQo9IDYwIGV0IGRlbnNpdMOpID0gMCw3IGVuIGR1cjwvdGV4dD48L2c+PGc+PHJlY3QgeD0iMzMwIiB5PSIzNTYiIHdpZHRoPSIzODYiIGhlaWdodD0iNTYiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzNDYiIHk9IjM3OCIgZm9udC1zaXplPSIxMyIgZm9udC13ZWlnaHQ9IjcwMCIgZmlsbD0iY3VycmVudENvbG9yIj40CsK3IFByb3h5IE5EVkk8L3RleHQ+PHRleHQgeD0iMzQ2IiB5PSIzOTgiIGZvbnQtc2l6ZT0iMTEuNSIgZm9udC1mYW1pbHk9IiYjMzk7SUJNIFBsZXggTW9ubyYjMzk7LG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIj5DMQo9IE5EVkkgw5cgMTUwPC90ZXh0PjwvZz48Zz48cmVjdCB4PSIzMzAiIHk9IjQyOCIgd2lkdGg9IjM4NiIgaGVpZ2h0PSIzNCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgb3BhY2l0eT0iLjU1IiAvPjx0ZXh0IHg9IjM0NiIgeT0iNDUwIiBmb250LXNpemU9IjEyIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii44Ij5hdWN1bmUKZW50csOpZSDihpIgTkEgKyBhdmVydGlzc2VtZW50PC90ZXh0PjwvZz48L2c+PCEtLSBmYWxsLXRocm91Z2ggLS0+PGcgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMSIgc3Ryb2tlLWRhc2hhcnJheT0iNCA0IiBvcGFjaXR5PSIuNSIgZmlsbD0ibm9uZSIgbWFya2VyLWVuZD0idXJsKCNhcikiPjxwYXRoIGQ9Ik0zMTgsMTI0IEwzMTgsMTQwIiAvPjxwYXRoIGQ9Ik0zMTgsMTk2IEwzMTgsMjEyIiAvPjxwYXRoIGQ9Ik0zMTgsMjY4IEwzMTgsMjg0IiAvPjxwYXRoIGQ9Ik0zMTgsMzQwIEwzMTgsMzU2IiAvPjxwYXRoIGQ9Ik0zMTgsNDEyIEwzMTgsNDI4IiAvPjwvZz48ZyBmb250LWZhbWlseT0iJiMzOTtCcmljb2xhZ2UgR3JvdGVzcXVlJiMzOTssc2Fucy1zZXJpZiIgZm9udC1zaXplPSI5LjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0iZW5kIj48dGV4dCB4PSIzMTIiIHk9IjEzNiI+c2lub248L3RleHQ+PHRleHQgeD0iMzEyIiB5PSIyMDgiPnNpbm9uPC90ZXh0Pjx0ZXh0IHg9IjMxMiIgeT0iMjgwIj5zaW5vbjwvdGV4dD48dGV4dCB4PSIzMTIiIHk9IjM1MiI+c2lub248L3RleHQ+PC9nPjwhLS0gY29sbGVjdG9yIC0tPjxnIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjQiIGZpbGw9Im5vbmUiIG9wYWNpdHk9Ii45Ij48bGluZSB4MT0iNzE2IiB5MT0iODgiIHgyPSI3NDIiIHkyPSI4OCI+PC9saW5lPjxsaW5lIHgxPSI3MTYiIHkxPSIxNjgiIHgyPSI3NDIiIHkyPSIxNjgiPjwvbGluZT48bGluZSB4MT0iNzE2IiB5MT0iMjQwIiB4Mj0iNzQyIiB5Mj0iMjQwIj48L2xpbmU+PGxpbmUgeDE9IjcxNiIgeTE9IjMxMiIgeDI9Ijc0MiIgeTI9IjMxMiI+PC9saW5lPjxsaW5lIHgxPSI3MTYiIHkxPSIzODQiIHgyPSI3NDIiIHkyPSIzODQiPjwvbGluZT48bGluZSB4MT0iNzQyIiB5MT0iODgiIHgyPSI3NDIiIHkyPSIzODQiPjwvbGluZT48bGluZSB4MT0iNzQyIiB5MT0iODgiIHgyPSI3NjgiIHkyPSI4OCIgbWFya2VyLWVuZD0idXJsKCNhci1hKSI+PC9saW5lPjwvZz48IS0tID09PT09PT09PT09PT09PT09IGRvd25zdHJlYW0gPT09PT09PT09PT09PT09PT0gLS0+PGcgZm9udC1mYW1pbHk9IiYjMzk7QnJpY29sYWdlIEdyb3Rlc3F1ZSYjMzk7LHNhbnMtc2VyaWYiPjxnPjxyZWN0IHg9Ijc3MiIgeT0iNTIiIHdpZHRoPSIyNjgiIGhlaWdodD0iNjAiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwIiBmaWxsLW9wYWNpdHk9Ii4xMCIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuNiIgLz48dGV4dCB4PSI3ODgiIHk9Ijc2IiBmb250LXNpemU9IjEzIiBmb250LXdlaWdodD0iNzAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmluZGljYXRldXJfYzFfYmlvbWFzc2U8L3RleHQ+PHRleHQgeD0iNzg4IiB5PSI5NSIgZm9udC1zaXplPSIxMS41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43NSI+Y29sb25uZQpicnV0ZSwgdEMvaGE8L3RleHQ+PC9nPjxnPjxyZWN0IHg9Ijc3MiIgeT0iMTQwIiB3aWR0aD0iMjY4IiBoZWlnaHQ9IjYwIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNzg4IiB5PSIxNjQiIGZvbnQtc2l6ZT0iMTMiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9Ijc4OCIgeT0iMTgzIiBmb250LXNpemU9IjExLjUiIGZvbnQtZmFtaWx5PSImIzM5O0lCTSBQbGV4IE1vbm8mIzM5Oyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjgiPkMxX25vcm0KPSBtaW4oMTAwLCB2LzE1MMK3MTAwKTwvdGV4dD48L2c+PGc+PHJlY3QgeD0iNzcyIiB5PSIyMjgiIHdpZHRoPSIyNjgiIGhlaWdodD0iNjAiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI3ODgiIHk9IjI1MiIgZm9udC1zaXplPSIxMyIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnEPigJ0pPC90ZXh0Pjx0ZXh0IHg9Ijc4OCIgeT0iMjcxIiBmb250LXNpemU9IjExLjUiIGZvbnQtZmFtaWx5PSImIzM5O0lCTSBQbGV4IE1vbm8mIzM5Oyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjgiPmZhbWlsbGVfY2FyYm9uZQo9IG1veShDMSwgQzIpPC90ZXh0PjwvZz48Zz48cmVjdCB4PSI3NzIiIHk9IjMxNiIgd2lkdGg9IjI2OCIgaGVpZ2h0PSI2MCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9Ijc4OCIgeT0iMzQwIiBmb250LXNpemU9IjEzIiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleChuZHApPC90ZXh0Pjx0ZXh0IHg9Ijc4OCIgeT0iMzU5IiBmb250LXNpemU9IjExLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc1Ij5wb25kw6lyYXRpb24KRmlib25hY2NpIMK3IGNvbmZpYW5jZSDPhjwvdGV4dD48L2c+PGc+PHJlY3QgeD0iNzcyIiB5PSI0MDQiIHdpZHRoPSIyNjgiIGhlaWdodD0iODYiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjQiIC8+PHRleHQgeD0iNzg4IiB5PSI0MjgiIGZvbnQtc2l6ZT0iMTMiIGZvbnQtd2VpZ2h0PSI3MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+TGl2cmFibGVzPC90ZXh0Pjx0ZXh0IHg9Ijc4OCIgeT0iNDQ3IiBmb250LXNpemU9IjExLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjgiPmFwcAo6IG9uZ2xldCBDLCByYWRhciAxMiBheGVzLCBiYWRnZSBORFA8L3RleHQ+PHRleHQgeD0iNzg4IiB5PSI0NjQiIGZvbnQtc2l6ZT0iMTEuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuOCI+cGVyc3BlY3RpdmVzCklBIHBhciBwcm9maWw8L3RleHQ+PHRleHQgeD0iNzg4IiB5PSI0ODEiIGZvbnQtc2l6ZT0iMTEuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuOCI+cHJvamV0CjogQ1NWIC8gUGFycXVldCAvIFBERiBwbGFuIGTigJlhY3Rpb248L3RleHQ+PC9nPjwvZz48ZyBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgZmlsbD0ibm9uZSIgbWFya2VyLWVuZD0idXJsKCNhcikiPjxsaW5lIHgxPSI5MDYiIHkxPSIxMTIiIHgyPSI5MDYiIHkyPSIxMzgiPjwvbGluZT48bGluZSB4MT0iOTA2IiB5MT0iMjAwIiB4Mj0iOTA2IiB5Mj0iMjI2Ij48L2xpbmU+PGxpbmUgeDE9IjkwNiIgeTE9IjI4OCIgeDI9IjkwNiIgeTI9IjMxNCI+PC9saW5lPjxsaW5lIHgxPSI5MDYiIHkxPSIzNzYiIHgyPSI5MDYiIHkyPSI0MDIiPjwvbGluZT48L2c+PCEtLSBmb290bm90ZSAtLT48ZyBmb250LWZhbWlseT0iJiMzOTtCcmljb2xhZ2UgR3JvdGVzcXVlJiMzOTssc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNiI+PHRleHQgeD0iMjAiIHk9IjUyMCI+TGUgcmFuZyAwIGVzdCBsZSBzZXVsIGNoZW1pbiBmb25kw6kgc3VyIHVuIGN1YmFnZSA7CmxlcyByYW5ncyAyIMOgIDQgc29udCBkZXMgcHJveHlzIGRlIHBsdXMgZW4gcGx1cyBpbmRpcmVjdHMuPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI1NDAiPkxlIE5EUCBuZSBjaG9pc2l0IHBhcyBsZSBjaGVtaW4gOiBpbCBxdWFsaWZpZSBhCnBvc3RlcmlvcmkgbGEgc291cmNlIHF1aSBhIHNlcnZpLCBldCBmaXhlIGxlIHBvaWRzIEZpYm9uYWNjaSBkZSBsYQpmYW1pbGxlLjwvdGV4dD48L2c+PC9zdmc+)

La cascade complète. Chaque source alimente un rang ; si ses entrées
manquent, le calcul retombe d’un cran. Le résultat, quel que soit le
rang servi, rejoint la même chaîne aval — d’où le risque de comparer
deux unités calculées par deux chemins différents.

------------------------------------------------------------------------

## 6. Pièges connus — mémo avant de conclure quoi que ce soit sur un C1

1.  **`density` porte deux unités différentes selon l’indicateur.**
    Chemin 1 de C1 : fraction 0–1.
    [`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
    et
    [`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md)
    : **tiges/ha**. Or le chemin 0 de C1, faute de colonne `stems_ha`,
    calcule `density × 500`. Un `sf` passé d’abord dans P1 (qui remplit
    `density` en tiges/ha) puis dans C1 sans `stems_ha` produit donc un
    C1 **surestimé ×500**, silencieusement. **Toujours fournir
    `stems_ha` explicitement**, ou appeler
    `indicateur_c1_biomasse(..., stems_col = "density")`.
2.  **Le plafond de 150 tC/ha sature.** Un épicéa H 28 m / D 34 cm / 400
    tiges/ha rend 163 tC/ha, une hêtraie mûre 162 : score 100 dans les
    deux cas. Lire la colonne brute, pas seulement le score, dès qu’on
    compare des peuplements capitalisés.
3.  **Le chemin « inventaire » sous-estime d’un facteur 3 à 10**
    (cf. §3, NDP 3). Coefficients « illustratifs » assumés dans
    `data-raw/allometric_models.R`.
4.  **Le chemin BD Forêt rend une constante par essence** (âge 60 /
    densité 0,7 en dur) : 4,3 à 14,1 tC/ha, aucune variabilité
    intra-essence.
5.  **Le NDVI ne discrimine pas la biomasse au-delà de 0,8.** À NDP 0
    sans CHM, C1 ≈ un indice de verdeur remis à l’échelle.
6.  **Unités des CHM publics** : FORMS-T en **cm** (÷100), FORMSpoT en
    **dm** (÷10). Passer le raster brut multiplie C1 par 100 ou 10.
7.  **Parquet ≤ 0.168.0 : recalculer.** Exposants du tarif IFN corrigés
    en 0.169.0.
8.  **Attributs NDP perdus à la sérialisation** : sans
    `restore_ndp_attributes()`, l’indice général repondère tout en
    Fibonacci 1.

------------------------------------------------------------------------

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction C1 et ses 5 chemins | `R/indicators-families.R:293-474` |
| Allométrie âge/densité | `R/utils.R:582-634`, `data-raw/allometric_models.R` |
| Tarif IFN, densités du bois | `inst/extdata/ifn_volume_equations.csv`, `wood_density.csv` |
| CHM : nettoyage, H_dom | `R/utils-chm.R` (`sanitize_chm:109`, `extract_h_dom:405`) |
| Inventaire synthétique | `R/synthetic_inventory.R`, `R/density_selfthinning.R` |
| Normalisation | `R/normalization.R:588` (règle), `:550` (`.NORMALIZE_RULED`) |
| Agrégation famille | `R/family-system.R` |
| NDP, Fibonacci, φ, flags | `R/ndp.R` |
| Déclaration des sources | `inst/datasources/FR.json` (clés `consumed_by`, `augmented`) |
| Libellés / infobulles | `R/indicator-config.R:10-26` |
| Historique des correctifs | `NEWS.md` — 0.169.0 (spec 040), 0.174.0 (zmean canopée + alias `C1`) |
| Spécifications | `specs/005-opencanopy-integration/`, `specs/038-normalisation-indicateurs/`, `specs/040-volume-mobilisable-desserte/` |
