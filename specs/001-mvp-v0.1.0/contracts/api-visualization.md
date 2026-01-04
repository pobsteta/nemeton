# API Contract: Visualization Functions

**Module**: Visualizations (maps, radar charts)
**Date**: 2026-01-04

---

## `nemeton_map()`

### Purpose
Générer une carte thématique choroplèthe pour visualiser un indicateur spatialement.

### Signature
```r
nemeton_map(
  data,
  indicator,
  palette = "viridis",
  title = NULL,
  legend_title = NULL,
  breaks = NULL,
  method = c("quantile", "equal", "jenks", "pretty"),
  n_breaks = 5,
  reverse_palette = FALSE,
  ...
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `data` | `sf` | Yes | - | Données avec indicateurs (résultats de `nemeton_compute()` ou `nemeton_index()`) |
| `indicator` | `character` | Yes | - | Nom de la colonne à cartographier |
| `palette` | `character` | No | `"viridis"` | Palette de couleurs: "viridis", "plasma", "inferno", "magma", "cividis", ou nom RColorBrewer |
| `title` | `character` | No | `NULL` | Titre de la carte. NULL = auto-généré |
| `legend_title` | `character` | No | `NULL` | Titre de la légende. NULL = nom indicateur |
| `breaks` | `numeric` | No | `NULL` | Breaks manuels pour classes. NULL = auto |
| `method` | `character` | No | `"quantile"` | Méthode de classification: quantile, equal, jenks, pretty |
| `n_breaks` | `integer` | No | `5` | Nombre de classes (si breaks = NULL) |
| `reverse_palette` | `logical` | No | `FALSE` | Inverser l'ordre des couleurs ? |
| `...` | various | No | - | Arguments additionnels passés à `ggplot2::geom_sf()` |

### Returns

**Type**: `ggplot` object

**Structure**: Carte ggplot2 personnalisable

### Behavior

1. **Validation**: Vérifier que `indicator` existe dans `data` et est numérique
2. **Classification**:
   - Si `breaks` fourni: utiliser directement
   - Sinon: calculer selon `method` et `n_breaks`
3. **Palette**:
   - Si viridis family: `scale_fill_viridis_c()` ou `_d()` selon breaks
   - Si RColorBrewer: `scale_fill_distiller()` ou `_brewer()`
4. **Layout**:
   - Theme minimal par défaut
   - Légende à droite
   - Titre auto si NULL: "Indicateur: {indicator}"

### Errors

| Condition | Error Type | Message |
|-----------|-----------|---------|
| `indicator` not in data | `cli::cli_abort()` | "Column '{indicator}' not found in data" |
| `indicator` not numeric | `cli::cli_abort()` | "Column '{indicator}' must be numeric" |
| Unknown palette | `cli::cli_abort()` | "Palette '{palette}' not recognized" |
| All NA values | `cli::cli_abort()` | "All values are NA for '{indicator}', cannot create map" |

### Customization

Le ggplot retourné est modifiable :

```r
p <- nemeton_map(data, "carbon")

# Personnaliser
p +
  labs(title = "Stock de carbone forestier") +
  theme_bw() +
  theme(legend.position = "bottom")
```

### Example 1: Basic map

```r
results <- nemeton_compute(units, layers, indicators = "carbon")

map <- nemeton_map(
  data = results,
  indicator = "carbon",
  palette = "viridis",
  title = "Stock de carbone (t/ha)"
)

print(map)
ggsave("carbon_map.png", map, width = 8, height = 6, dpi = 300)
```

### Example 2: Custom breaks

```r
map <- nemeton_map(
  results,
  indicator = "biodiversity",
  breaks = c(0, 1, 2, 3, 4, 5),  # Shannon index classes
  palette = "YlGn",              # ColorBrewer
  legend_title = "Shannon H'"
)
```

### Example 3: Equal interval classification

```r
map <- nemeton_map(
  results,
  indicator = "accessibility",
  method = "equal",
  n_breaks = 10,
  reverse_palette = TRUE  # Rouge = faible accessibilité
)
```

---

## `nemeton_radar()`

### Purpose
Générer un diagramme radar (spider chart) pour visualiser le profil multi-dimensionnel d'une unité ou moyenne.

### Signature
```r
nemeton_radar(
  data,
  unit_id = NULL,
  indicators = NULL,
  normalize = TRUE,
  normalize_method = "minmax",
  fill = TRUE,
  fill_alpha = 0.3,
  color = "steelblue",
  title = NULL,
  axis_labels = NULL
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `data` | `sf` or `data.frame` | Yes | - | Données avec indicateurs |
| `unit_id` | `character` or `numeric` | No | `NULL` | Identifiant de l'unité à visualiser. NULL = moyenne de toutes |
| `indicators` | `character` | No | `NULL` | Indicateurs à afficher. NULL = tous numériques (hors id, geometry) |
| `normalize` | `logical` | No | `TRUE` | Normaliser 0-100 avant affichage ? |
| `normalize_method` | `character` | No | `"minmax"` | Méthode de normalisation si normalize = TRUE |
| `fill` | `logical` | No | `TRUE` | Remplir le polygone ? |
| `fill_alpha` | `numeric` | No | `0.3` | Transparence du remplissage (0-1) |
| `color` | `character` | No | `"steelblue"` | Couleur de la ligne et remplissage |
| `title` | `character` | No | `NULL` | Titre. NULL = auto ("Profil Néméton - {unit_id}") |
| `axis_labels` | `named character` | No | `NULL` | Labels personnalisés pour axes. NULL = noms indicateurs |

### Returns

**Type**: `ggplot` object

**Structure**: Radar chart via `coord_polar()`

### Behavior

1. **Sélection unité**:
   - Si `unit_id` fourni: extraire ligne correspondante
   - Si NULL: calculer moyenne de chaque indicateur
2. **Détection indicateurs**:
   - Si `indicators` NULL: toutes colonnes numériques sauf geometry, nemeton_id, etc.
3. **Normalisation** (si `normalize = TRUE`):
   - Normaliser chaque indicateur 0-100 (global sur tout data, pas juste unité)
4. **Construction radar**:
   - Transformation en coordonnées polaires via `coord_polar()`
   - Axes: un par indicateur
   - Échelle: 0-100 (si normalisé) ou valeurs brutes

### Technical Implementation

```r
# Pseudo-code structure
# 1. Reshape data to long format
radar_data <- data.frame(
  indicator = c("carbon", "biodiversity", "water"),
  value = c(85, 92, 78)
)

# 2. ggplot with coord_polar
ggplot(radar_data, aes(x = indicator, y = value, group = 1)) +
  geom_polygon(fill = color, alpha = fill_alpha) +
  geom_point(color = color, size = 3) +
  geom_line(color = color, size = 1) +
  coord_polar() +
  ylim(0, 100) +
  theme_minimal()
```

### Errors

| Condition | Error Type | Message |
|-----------|-----------|---------|
| `unit_id` not found | `cli::cli_abort()` | "Unit '{unit_id}' not found in data" |
| No numeric indicators | `cli::cli_abort()` | "No numeric indicators found in data" |
| < 3 indicators | `cli::cli_abort()` | "Radar chart requires at least 3 indicators" |

### Example 1: Single unit

```r
results <- nemeton_compute(units, layers)

radar <- nemeton_radar(
  data = results,
  unit_id = "unit_042",
  indicators = c("carbon", "biodiversity", "water", "accessibility"),
  fill = TRUE,
  color = "forestgreen",
  title = "Profil Néméton - Parcelle 42"
)

print(radar)
```

### Example 2: Average profile

```r
radar <- nemeton_radar(
  data = results,
  unit_id = NULL,  # Moyenne
  title = "Profil moyen du massif"
)

# Affiche le profil radar de la moyenne de toutes les unités
```

### Example 3: Custom labels

```r
radar <- nemeton_radar(
  results,
  unit_id = "unit_001",
  indicators = c("carbon", "biodiversity", "water"),
  axis_labels = c(
    carbon = "Carbone\n(t/ha)",
    biodiversity = "Biodiversité\n(Shannon)",
    water = "Eau\n(TWI)"
  ),
  color = "#2E7D32",
  fill_alpha = 0.5
)
```

---

## Helper Functions (Internal)

### `classify_values()`

**Purpose**: Calculer breaks pour classification (utilisé par `nemeton_map()`)

**Signature**:
```r
classify_values(x, method = "quantile", n = 5)
```

**Parameters**:
- `x`: Vecteur numérique
- `method`: "quantile", "equal", "jenks", "pretty"
- `n`: Nombre de classes

**Returns**: Vecteur de breaks

**Methods**:

```r
# quantile
quantile(x, probs = seq(0, 1, length.out = n + 1))

# equal
seq(min(x), max(x), length.out = n + 1)

# jenks (natural breaks)
classInt::classIntervals(x, n = n, style = "jenks")$brks

# pretty
pretty(x, n = n)
```

---

### `prepare_radar_data()`

**Purpose**: Transformer sf en format long pour radar chart

**Signature**:
```r
prepare_radar_data(data, unit_id = NULL, indicators = NULL, normalize = TRUE)
```

**Returns**:
```r
data.frame(
  indicator = character(),  # Nom indicateur
  value = numeric(),        # Valeur (normalisée ou non)
  label = character()       # Label pour affichage
)
```

---

## Visualization Best Practices (Implemented)

### Color Palettes

**Recommandations**:
- **Sequential** (low → high): viridis, Blues, Greens
- **Diverging** (low ← mid → high): RdYlGn, BrBG
- **Qualitative** (catégories): Set2, Dark2

**Accessibility**: Toutes palettes viridis sont colorblind-safe

### Radar Chart Limitations

**Important**: Radar charts efficaces pour <= 8 indicateurs. Au-delà, privilégier heatmap ou barres.

---

## Example Complete Workflow with Visualizations

```r
library(nemeton)
library(sf)

# 1. Données
units <- nemeton_units(st_read("parcels.gpkg"))
layers <- nemeton_layers(
  rasters = list(biomass = "biomass.tif", species = "species.tif"),
  vectors = list(roads = "roads.gpkg")
)

# 2. Calcul
results <- nemeton_compute(units, layers)

# 3. Normalisation
indices <- nemeton_index(results)

# 4. Cartes multiples
map_carbon <- nemeton_map(results, "carbon", palette = "YlGn")
map_biodiv <- nemeton_map(results, "biodiversity", palette = "BuPu")
map_index <- nemeton_map(indices, "nemeton_index", palette = "RdYlGn")

# Combiner (patchwork)
library(patchwork)
combined <- map_carbon / map_biodiv / map_index +
  plot_annotation(title = "Analyse Néméton - Forêt de Test")

ggsave("nemeton_maps.png", combined, width = 10, height = 12, dpi = 300)

# 5. Radar charts (top 3 unités par index)
top3 <- indices |>
  dplyr::slice_max(nemeton_index, n = 3)

radars <- lapply(top3$nemeton_id, function(id) {
  nemeton_radar(indices, unit_id = id, title = paste("Unité", id))
})

# Combiner radars
radars_combined <- wrap_plots(radars, ncol = 3)
ggsave("top3_radars.png", radars_combined, width = 12, height = 4, dpi = 300)
```

---

## Future Enhancements (Post-MVP)

**v0.2.0+**:
- `nemeton_timeline()`: Evolution temporelle d'un indicateur
- `nemeton_radar_compare()`: Superposer plusieurs unités/époques
- `nemeton_matrix()`: Heatmap de corrélation entre indicateurs
- Export interactif (leaflet, plotly)

---

**Contract Status**: ✅ Complete - 2 visualizations specified
