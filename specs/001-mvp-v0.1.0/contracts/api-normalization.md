# API Contract: Normalization & Indices

**Module**: Normalization, Aggregation
**Date**: 2026-01-04

---

## `nemeton_index()`

### Purpose
Normaliser les indicateurs bruts et calculer un indice Néméton composite.

### Signature
```r
nemeton_index(
  data,
  method = c("weighted", "geometric", "harmonic"),
  weights = NULL,
  normalize = TRUE,
  normalize_method = c("minmax", "zscore", "rank"),
  polarity = NULL,
  thematic_groups = NULL,
  range = c(0, 100)
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `data` | `sf` | Yes | - | Résultats avec indicateurs calculés (de `nemeton_compute()`) |
| `method` | `character` | No | `"weighted"` | Méthode d'agrégation: weighted (moyenne pondérée), geometric (moyenne géométrique), harmonic |
| `weights` | `named numeric` | No | `NULL` | Poids par indicateur. NULL = équipondéré |
| `normalize` | `logical` | No | `TRUE` | Normaliser avant agrégation ? |
| `normalize_method` | `character` | No | `"minmax"` | Méthode de normalisation: minmax (0-100), zscore, rank |
| `polarity` | `named numeric` | No | `NULL` | +1 ou -1 par indicateur. +1 = plus haut mieux, -1 = plus bas mieux |
| `thematic_groups` | `named list` | No | `NULL` | Groupes thématiques pour indices partiels |
| `range` | `numeric(2)` | No | `c(0,100)` | Intervalle pour normalisation minmax |

### Returns

**Type**: `sf` (enriched)

**Structure**:
```r
# Original data + nouvelles colonnes:
# - <indicator>_norm: Indicateur normalisé (si normalize = TRUE)
# - nemeton_index: Indice global (0-100)
# - <group>_index: Indices thématiques (si thematic_groups spécifié)
# - Updated metadata attribute
```

### Behavior

1. **Détection des indicateurs**: Colonnes numériques non-géométriques (hors nemeton_id, etc.)
2. **Validation**: Vérifier que weights correspond aux indicateurs
3. **Polarité**: Inverser indicateurs si polarity = -1 (ex: fragmentation)
4. **Normalisation** (si `normalize = TRUE`):
   - minmax: (x - min) / (max - min) * (range[2] - range[1]) + range[1]
   - zscore: (x - mean) / sd
   - rank: percentile rank * 100
5. **Agrégation**:
   - weighted: Σ(wi * xi) / Σ(wi)
   - geometric: (Π xi^wi)^(1/Σwi)
   - harmonic: Σwi / Σ(wi/xi)
6. **Groupes thématiques**: Répéter agrégation par sous-groupe

### Errors

| Condition | Error Type | Message |
|-----------|-----------|---------|
| No numeric indicators in data | `cli::cli_abort()` | "No numeric indicators found in data" |
| weights names don't match indicators | `cli::cli_abort()` | "weights names must match indicator columns: {mismatch}" |
| polarity not -1 or +1 | `cli::cli_abort()` | "polarity values must be -1 or +1" |
| All values identical (no variance) | `cli::cli_warn()` | "Indicator '{ind}' has no variance, normalized to 50" |

### Example 1: Simple index

```r
# Calculer indicateurs
results <- nemeton_compute(units, layers, indicators = c("carbon", "biodiversity", "water"))

# Indice équipondéré
indices <- nemeton_index(results)

head(indices)
#> nemeton_id carbon biodiv water carbon_norm biodiv_norm water_norm nemeton_index
#> unit_001   120.5  2.3    8.5   85.3        92.1        78.2       85.2
```

### Example 2: Weighted with polarity

```r
indices <- nemeton_index(
  results,
  method = "weighted",
  weights = c(carbon = 0.4, biodiversity = 0.4, fragmentation = 0.2),
  polarity = c(carbon = 1, biodiversity = 1, fragmentation = -1)  # fragmentation: moins = mieux
)

# fragmentation inversé avant agrégation
```

### Example 3: Thematic groups

```r
indices <- nemeton_index(
  results,
  thematic_groups = list(
    ecological = c("biodiversity", "water"),
    climate = c("carbon"),
    landscape = c("fragmentation")
  )
)

# Colonnes additionnelles: ecological_index, climate_index, landscape_index
```

---

## `normalize_indicators()`

### Purpose
Normaliser des indicateurs bruts (fonction de niveau inférieur, utilisée par `nemeton_index()`).

### Signature
```r
normalize_indicators(
  data,
  indicators = NULL,
  method = c("minmax", "zscore", "rank", "percentile"),
  polarity = NULL,
  range = c(0, 100),
  suffix = "_norm"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `data` | `sf` or `data.frame` | Yes | - | Données avec indicateurs |
| `indicators` | `character` | No | `NULL` | Noms des colonnes à normaliser. NULL = toutes numériques |
| `method` | `character` | No | `"minmax"` | Méthode de normalisation |
| `polarity` | `named numeric` | No | `NULL` | +1 ou -1 par indicateur |
| `range` | `numeric(2)` | No | `c(0,100)` | Intervalle cible (minmax seulement) |
| `suffix` | `character` | No | `"_norm"` | Suffixe pour colonnes normalisées |

### Returns

**Type**: Même que `data` (sf ou data.frame)

**Structure**: Original + colonnes normalisées avec `suffix`

### Normalization Methods

**minmax** (0-100 par défaut):
```r
x_norm <- (x - min(x)) / (max(x) - min(x)) * (range[2] - range[1]) + range[1]
```

**zscore** (μ=0, σ=1):
```r
x_norm <- (x - mean(x)) / sd(x)
```

**rank** (0-100):
```r
x_norm <- rank(x, na.last = "keep") / sum(!is.na(x)) * 100
```

**percentile** (0-100, similaire rank mais interpolé):
```r
x_norm <- ecdf(x)(x) * 100
```

### Special Cases

| Case | Handling |
|------|----------|
| All values identical | Return median of range (e.g., 50 for [0,100]) + warning |
| Only 1 non-NA value | Return median of range + warning |
| All NA | Return all NA (no warning) |
| polarity = -1 | Invert before normalization: x_inv = max(x) - x + min(x) |

### Example
```r
data_norm <- normalize_indicators(
  data = results,
  indicators = c("carbon", "biodiversity"),
  method = "minmax",
  polarity = c(carbon = 1, biodiversity = 1),
  range = c(0, 100)
)

# Nouvelles colonnes: carbon_norm, biodiversity_norm (0-100)
```

---

## Helper Functions (Internal)

### `aggregate_weighted()`

**Purpose**: Moyenne pondérée de vecteurs

**Signature**:
```r
aggregate_weighted(x, weights = NULL)
```

**Parameters**:
- `x`: Matrice ou data.frame d'indicateurs (rows = unités, cols = indicateurs)
- `weights`: Vecteur de poids (length = ncol(x))

**Returns**: Vecteur numérique (length = nrow(x))

**Formula**:
```r
# Pour chaque unité i:
index_i <- Σ(w_j * x_ij) / Σ(w_j)
```

---

### `aggregate_geometric()`

**Purpose**: Moyenne géométrique pondérée

**Signature**:
```r
aggregate_geometric(x, weights = NULL)
```

**Formula**:
```r
# Moyenne géométrique pondérée:
index_i <- (Π x_ij^w_j)^(1 / Σw_j)

# Équivalent:
index_i <- exp(Σ(w_j * log(x_ij)) / Σ(w_j))
```

**Note**: Requiert toutes valeurs > 0 (checked, abort if not)

---

### `aggregate_harmonic()`

**Purpose**: Moyenne harmonique pondérée

**Signature**:
```r
aggregate_harmonic(x, weights = NULL)
```

**Formula**:
```r
index_i <- Σ(w_j) / Σ(w_j / x_ij)
```

**Note**: Requiert toutes valeurs > 0 (checked, abort if not)

---

## Metadata Tracking

Après `nemeton_index()`, métadonnées mises à jour :

```r
attr(indices, "metadata") <- c(
  attr(data, "metadata"),  # Métadonnées originales
  list(
    normalized_at = Sys.time(),
    normalization_method = "minmax",
    normalization_range = c(0, 100),
    aggregation_method = "weighted",
    weights = c(carbon = 0.4, biodiversity = 0.6),
    polarity = c(carbon = 1, biodiversity = 1),
    thematic_groups = list(...)
  )
)
```

---

## Validation & Edge Cases

### Pre-computation Checks

1. **Indicators exist**: Vérifier que colonnes spécifiées existent
2. **Numeric**: Vérifier que colonnes sont numériques
3. **Weights sum**: Normaliser weights si sum != 1 (avec message)
4. **Polarity values**: Vérifier que -1 ou +1 seulement

### During Normalization

1. **No variance**: Si sd(x) == 0, retourner 50 (milieu de range) + warning
2. **Infinite values**: Remplacer Inf/-Inf par NA + warning
3. **Negative values**: Si geometric/harmonic, abort si valeurs < 0

### Post-aggregation

1. **Bounds check**: Vérifier que indices dans [0, 100] si minmax
2. **NA propagation**: Si toute ligne a >= 1 NA, index = NA

---

## Example Workflow Complete

```r
library(nemeton)

# 1. Créer unités
units <- nemeton_units(st_read("parcels.gpkg"))

# 2. Charger couches
layers <- nemeton_layers(
  rasters = list(
    biomass = "biomass.tif",
    species = "species.tif"
  ),
  vectors = list(
    roads = "roads.gpkg"
  )
)

# 3. Calculer indicateurs
results <- nemeton_compute(
  units, layers,
  indicators = c("carbon", "biodiversity", "accessibility")
)

# 4. Normaliser et agréger
indices <- nemeton_index(
  results,
  method = "weighted",
  weights = c(
    carbon = 0.35,
    biodiversity = 0.40,
    accessibility = 0.25
  ),
  normalize = TRUE,
  normalize_method = "minmax",
  polarity = c(
    carbon = 1,         # Plus = mieux
    biodiversity = 1,   # Plus = mieux
    accessibility = 1   # Plus = mieux
  ),
  thematic_groups = list(
    ecological = c("biodiversity"),
    climate = c("carbon"),
    social = c("accessibility")
  )
)

# 5. Résultat
names(indices)
#> [1] "nemeton_id" "carbon" "biodiversity" "accessibility"
#> [5] "carbon_norm" "biodiversity_norm" "accessibility_norm"
#> [9] "ecological_index" "climate_index" "social_index"
#> [10] "nemeton_index" "geometry"

summary(indices$nemeton_index)
#> Min. 1st Qu. Median Mean 3rd Qu. Max.
#> 32.1 58.7    72.3   70.1 84.5    96.8
```

---

**Contract Status**: ✅ Complete
