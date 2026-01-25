# Module 5 API Contract: Export et Valorisation des Résultats

**Module**: Tutorial Module 5 - Export et Valorisation des Résultats
**Feature**: 001-learnr-tutorial
**User Story**: US5 (P2)

## Overview

Ce module enseigne l'export des analyses dans des formats opérationnels pour partager avec les gestionnaires forestiers et décideurs :
- Export GeoPackage complet avec tous indicateurs
- Génération rapport HTML interactif avec cartes
- Export PDF pour présentation
- Export CSV pour SIG externe (QGIS)
- Template de rapport personnalisable

**Pédagogie** : Workflow d'export multi-formats avec templates personnalisables.

---

## Exercice 5.1 : Export GeoPackage Complet

### Objectif Pédagogique
L'utilisateur apprend à exporter le dataset complet des 12 familles au format GeoPackage pour utilisation dans des SIG.

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles (Module 3)

### Code attendu de l'utilisateur
```r
# Préparer métadonnées
metadata <- data.frame(
  layer = "parcelles_12_familles",
  description = "Parcelles forestières CIRON avec 12 familles d'indicateurs écosystémiques",
  source = "IGN (cadastre, MNT, LiDAR HD) + nemeton v0.4.1",
  date_calcul = Sys.Date(),
  crs = "EPSG:2154 (Lambert-93)",
  nb_parcelles = nrow(parcelles_complet),
  families = "C,B,W,F,L,A,T,R,S,P,E,N"
)

# Exporter GeoPackage
output_gpkg <- "results/ciron_12_familles.gpkg"
st_write(parcelles_complet, output_gpkg, layer = "parcelles", delete_dsn = TRUE)

# Ajouter table métadonnées
# Note: GeoPackage supporte tables non-spatiales
con <- DBI::dbConnect(RSQLite::SQLite(), output_gpkg)
DBI::dbWriteTable(con, "metadata", metadata, overwrite = TRUE)
DBI::dbDisconnect(con)

# Vérifier export
cat("GeoPackage créé:", output_gpkg, "\n")
cat("Taille:", round(file.size(output_gpkg) / 1e6, 2), "MB\n")

# Lister couches
st_layers(output_gpkg)
```

### Outputs attendus
- `ciron_12_familles.gpkg` : GeoPackage avec 2 couches
  - `parcelles` : couche spatiale sf avec géométries + 12 familles
  - `metadata` : table non-spatiale avec métadonnées projet
- Taille fichier : ~5-20 MB selon zone
- CRS : EPSG:2154 préservé

### Validation gradethis
```r
grade_result(
  pass_if(~ file.exists(.result),
          "Excellent ! GeoPackage exporté."),
  fail_if(~ !file.exists(.result),
          "Fichier GeoPackage non trouvé. Vérifiez st_write()."),
  pass_if(~ file.size(.result) > 1000,
          "Fichier GeoPackage non vide."),
  pass_if(~ length(st_layers(.result)$name) >= 1,
          "Au moins une couche spatiale présente.")
)
```

### Concepts enseignés
- Format GeoPackage (OGC standard)
- Export sf avec `st_write()`
- Métadonnées intégrées
- Interopérabilité SIG (QGIS, ArcGIS)

---

## Exercice 5.2 : Génération Rapport HTML Interactif

### Objectif Pédagogique
L'utilisateur apprend à générer un rapport HTML interactif avec cartes leaflet et visualisations ggplot2.

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles

### Code attendu de l'utilisateur
```r
# Créer rapport RMarkdown interactif
library(rmarkdown)
library(leaflet)

# Template rapport HTML
report_rmd <- "templates/rapport_12_familles.Rmd"

# Paramètres rapport
params <- list(
  parcels = parcelles_complet,
  zone_name = "CIRON",
  date_calcul = Sys.Date(),
  familles_focus = c("B", "N", "P")  # 3 familles à mettre en avant
)

# Rendre rapport
output_html <- "results/ciron_rapport_interactif.html"
rmarkdown::render(
  input = report_rmd,
  output_file = output_html,
  params = params,
  envir = new.env()
)

# Ouvrir dans navigateur
browseURL(output_html)
```

### Template Rapport RMarkdown (`rapport_12_familles.Rmd`)
```rmd
---
title: "Analyse Écosystémique Forestière - `r params$zone_name`"
subtitle: "Référentiel 12 Familles d'Indicateurs"
date: "`r params$date_calcul`"
output:
  html_document:
    toc: true
    toc_float: true
    theme: flatly
    highlight: tango
params:
  parcels: NULL
  zone_name: "Zone"
  date_calcul: !r Sys.Date()
  familles_focus: ["B", "N", "P"]
---

## Résumé Exécutif

Cette analyse présente les résultats du référentiel 12 familles d'indicateurs écosystémiques pour `r nrow(params$parcels)` parcelles forestières de `r params$zone_name`.

## Carte Interactive Multi-Familles

```{r echo=FALSE, message=FALSE, warning=FALSE}
library(leaflet)
library(sf)

# Transformer en WGS84 pour leaflet
parcels_wgs84 <- st_transform(params$parcels, 4326)

# Palette couleur
pal <- colorNumeric("viridis", domain = c(0, 1))

# Carte leaflet avec 3 familles en focus
leaflet(parcels_wgs84) |>
  addTiles() |>
  addPolygons(
    fillColor = ~pal(family_index_B),
    fillOpacity = 0.7,
    color = "white",
    weight = 1,
    label = ~paste0("Parcelle ", id_parcel, " | B:", round(family_index_B, 2)),
    group = "Biodiversité (B)"
  ) |>
  addPolygons(
    fillColor = ~pal(family_index_N),
    fillOpacity = 0.7,
    color = "white",
    weight = 1,
    label = ~paste0("Parcelle ", id_parcel, " | N:", round(family_index_N, 2)),
    group = "Naturalité (N)"
  ) |>
  addPolygons(
    fillColor = ~pal(family_index_P),
    fillOpacity = 0.7,
    color = "white",
    weight = 1,
    label = ~paste0("Parcelle ", id_parcel, " | P:", round(family_index_P, 2)),
    group = "Production (P)"
  ) |>
  addLayersControl(
    baseGroups = c("Biodiversité (B)", "Naturalité (N)", "Production (P)"),
    options = layersControlOptions(collapsed = FALSE)
  ) |>
  addLegend("bottomright", pal = pal, values = c(0, 1), title = "Indice (0-1)")
```

## Statistiques Descriptives

```{r echo=FALSE}
library(dplyr)

family_cols <- paste0("family_index_", c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N"))
stats <- params$parcels |>
  st_drop_geometry() |>
  select(all_of(family_cols)) |>
  summarise(across(everything(), list(
    mean = ~mean(.x, na.rm = TRUE),
    sd = ~sd(.x, na.rm = TRUE),
    min = ~min(.x, na.rm = TRUE),
    max = ~max(.x, na.rm = TRUE)
  )))

knitr::kable(t(stats), digits = 2, caption = "Statistiques des 12 Familles")
```

## Recommandations

1. **Conservation prioritaire** : `r sum(params$parcels$family_index_B > 0.7 & params$parcels$family_index_N > 0.7)` parcelles avec forts indices B et N.
2. **Production prioritaire** : `r sum(params$parcels$family_index_P > 0.7)` parcelles avec fort indice P.
3. **Multifonctionnalité** : `r sum(params$parcels$family_index_B > 0.5 & params$parcels$family_index_P > 0.5 & params$parcels$family_index_N > 0.5)` parcelles équilibrées.
```

### Outputs attendus
- `ciron_rapport_interactif.html` : Rapport HTML avec :
  - Table des matières flottante
  - Carte leaflet interactive avec 3 familles sélectionnables
  - Statistiques descriptives (tableau)
  - Recommandations de gestion
- Taille : ~2-5 MB
- Visualisable dans n'importe quel navigateur

### Validation gradethis
```r
grade_result(
  pass_if(~ file.exists(.result),
          "Super ! Rapport HTML généré."),
  fail_if(~ !file.exists(.result),
          "Fichier HTML non trouvé. Vérifiez rmarkdown::render()."),
  pass_if(~ file.size(.result) > 10000,
          "Rapport HTML non vide."),
  pass_if(~ grepl("\\.html$", .result),
          "Extension .html correcte.")
)
```

### Concepts enseignés
- RMarkdown paramétré
- Rapport HTML interactif
- Leaflet pour cartes web
- Templates réutilisables

---

## Exercice 5.3 : Export PDF pour Présentation

### Objectif Pédagogique
L'utilisateur apprend à générer un rapport PDF de qualité présentation pour partage avec décideurs.

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles

### Code attendu de l'utilisateur
```r
# Template rapport PDF
report_pdf_rmd <- "templates/rapport_12_familles_pdf.Rmd"

# Paramètres rapport
params_pdf <- list(
  parcels = parcelles_complet,
  zone_name = "CIRON",
  date_calcul = Sys.Date()
)

# Rendre rapport PDF
output_pdf <- "results/ciron_rapport_presentation.pdf"
rmarkdown::render(
  input = report_pdf_rmd,
  output_file = output_pdf,
  output_format = "pdf_document",
  params = params_pdf
)

cat("Rapport PDF créé:", output_pdf, "\n")
```

### Template Rapport PDF (`rapport_12_familles_pdf.Rmd`)
```rmd
---
title: "Analyse Écosystémique Forestière"
subtitle: "`r params$zone_name` - Référentiel 12 Familles"
date: "`r format(params$date_calcul, '%d/%m/%Y')`"
output:
  pdf_document:
    toc: true
    number_sections: true
    fig_caption: yes
params:
  parcels: NULL
  zone_name: "Zone"
  date_calcul: !r Sys.Date()
---

\newpage

# Résumé Exécutif

Cette analyse évalue `r nrow(params$parcels)` parcelles forestières selon 12 familles d'indicateurs écosystémiques.

# Résultats Visuels

## Carte Thématique Biodiversité

```{r echo=FALSE, fig.width=7, fig.height=5, fig.cap="Indice Biodiversité (B)"}
library(ggplot2)
library(sf)

ggplot(params$parcels) +
  geom_sf(aes(fill = family_index_B), color = "grey50", size = 0.3) +
  scale_fill_viridis_c(option = "viridis", limits = c(0, 1)) +
  labs(title = "Indice Biodiversité (B)", fill = "Indice") +
  theme_minimal() +
  theme(legend.position = "bottom")
```

## Radar Chart Parcelle Représentative

```{r echo=FALSE, fig.width=6, fig.height=6, fig.cap="Profil 12-axes - Parcelle médiane"}
library(fmsb)

# Sélectionner parcelle médiane
median_idx <- which.min(abs(rowMeans(st_drop_geometry(params$parcels[, paste0("family_index_", c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N"))]), na.rm = TRUE) - 0.5))
parcelle_median <- params$parcels[median_idx, ]

indices <- as.numeric(st_drop_geometry(parcelle_median[, paste0("family_index_", c("C", "B", "W", "F", "L", "A", "T", "R", "S", "P", "E", "N"))]))
names(indices) <- c("C", "B", "W", "F", "L", "A", "T", "R", "S", "P", "E", "N")

radar_data <- rbind(max = rep(1, 12), min = rep(0, 12), indices)
radarchart(radar_data, axistype = 1, pcol = "forestgreen",
           pfcol = scales::alpha("forestgreen", 0.3), plwd = 2)
```

# Recommandations de Gestion

```{r echo=FALSE, results='asis'}
cat("- **Conservation** :", sum(params$parcels$family_index_B > 0.7), "parcelles prioritaires\n")
cat("- **Production** :", sum(params$parcels$family_index_P > 0.7), "parcelles à fort potentiel\n")
cat("- **Multifonctionnalité** :", sum(params$parcels$family_index_B > 0.5 & params$parcels$family_index_P > 0.5), "parcelles équilibrées\n")
```
```

### Outputs attendus
- `ciron_rapport_presentation.pdf` : Rapport PDF avec :
  - Page de titre professionnelle
  - Table des matières
  - Cartes thématiques haute résolution
  - Radar chart
  - Recommandations
- Taille : ~5-10 MB
- Format A4, imprimable

### Validation gradethis
```r
grade_result(
  pass_if(~ file.exists(.result),
          "Parfait ! Rapport PDF généré."),
  fail_if(~ !file.exists(.result),
          "Fichier PDF non trouvé. Vérifiez rmarkdown::render() avec output_format='pdf_document'."),
  pass_if(~ grepl("\\.pdf$", .result),
          "Extension .pdf correcte.")
)
```

### Concepts enseignés
- RMarkdown vers PDF
- LaTeX pour formatage professionnel
- Figures haute résolution
- Rapport imprimable

---

## Exercice 5.4 : Export CSV pour SIG Externe

### Objectif Pédagogique
L'utilisateur apprend à exporter les résultats en CSV pour utilisation dans des SIG externes (QGIS, Excel).

### Inputs de l'exercice
- `parcelles_complet` : objet sf avec 12 familles

### Code attendu de l'utilisateur
```r
# Exporter données tabulaires (sans géométrie)
parcelles_table <- parcelles_complet |>
  st_drop_geometry() |>
  select(id_parcel, starts_with("family_index_"), starts_with("ind_"))

# Export CSV
output_csv <- "results/ciron_12_familles.csv"
write.csv(parcelles_table, output_csv, row.names = FALSE)

cat("CSV exporté:", output_csv, "\n")
cat("Lignes:", nrow(parcelles_table), "\n")
cat("Colonnes:", ncol(parcelles_table), "\n")

# Export centroïdes pour jointure SIG (avec coordonnées XY)
parcelles_centroids <- parcelles_complet |>
  st_centroid() |>
  mutate(
    X = st_coordinates(geometry)[, 1],
    Y = st_coordinates(geometry)[, 2]
  ) |>
  st_drop_geometry() |>
  select(id_parcel, X, Y, starts_with("family_index_"))

output_csv_xy <- "results/ciron_12_familles_centroids_xy.csv"
write.csv(parcelles_centroids, output_csv_xy, row.names = FALSE)

cat("CSV avec XY exporté:", output_csv_xy, "\n")
```

### Outputs attendus
- `ciron_12_familles.csv` : Table attributaire complète (sans géométrie)
  - Colonnes : `id_parcel`, 12 x `family_index_*`, ~40-50 x `ind_*` (indicateurs détaillés)
- `ciron_12_familles_centroids_xy.csv` : Table avec coordonnées centroïdes
  - Colonnes : `id_parcel`, `X`, `Y`, 12 x `family_index_*`
- Encodage : UTF-8
- Séparateur : virgule

### Validation gradethis
```r
grade_result(
  pass_if(~ file.exists(.result),
          "Excellent ! CSV exporté."),
  fail_if(~ !file.exists(.result),
          "Fichier CSV non trouvé. Vérifiez write.csv()."),
  pass_if(~ file.size(.result) > 100,
          "CSV non vide."),
  pass_if(~ grepl("\\.csv$", .result),
          "Extension .csv correcte.")
)
```

### Concepts enseignés
- Export CSV (`write.csv`)
- Suppression géométrie (`st_drop_geometry`)
- Extraction centroïdes avec coordonnées XY
- Interopérabilité avec Excel, QGIS

---

## Exercice 5.5 : Template de Rapport Personnalisable

### Objectif Pédagogique
L'utilisateur apprend à créer un template de rapport personnalisable pour réutilisation sur d'autres zones.

### Inputs de l'exercice
- Template générique `rapport_template.Rmd`
- Paramètres personnalisés (zone, date, familles focus)

### Code attendu de l'utilisateur
```r
# Créer fonction wrapper pour générer rapport personnalisé
generate_custom_report <- function(parcels, zone_name, output_dir = "results",
                                   format = c("html", "pdf"), families_focus = c("B", "N", "P")) {

  # Valider inputs
  stopifnot(inherits(parcels, "sf"))
  stopifnot(all(paste0("family_index_", c("C", "B", "W", "F", "L", "A", "R", "S", "P", "E", "N")) %in% names(parcels)))

  # Paramètres rapport
  params <- list(
    parcels = parcels,
    zone_name = zone_name,
    date_calcul = Sys.Date(),
    familles_focus = families_focus
  )

  # Template et output selon format
  if (format == "html") {
    template <- system.file("templates/rapport_12_familles.Rmd", package = "nemeton")
    output_file <- file.path(output_dir, paste0(zone_name, "_rapport.html"))
    output_format <- "html_document"
  } else {
    template <- system.file("templates/rapport_12_familles_pdf.Rmd", package = "nemeton")
    output_file <- file.path(output_dir, paste0(zone_name, "_rapport.pdf"))
    output_format <- "pdf_document"
  }

  # Rendre rapport
  rmarkdown::render(
    input = template,
    output_file = output_file,
    output_format = output_format,
    params = params,
    envir = new.env()
  )

  message("Rapport généré: ", output_file)
  invisible(output_file)
}

# Utilisation
report_path <- generate_custom_report(
  parcels = parcelles_complet,
  zone_name = "CIRON",
  format = "html",
  families_focus = c("B", "N", "P")
)

browseURL(report_path)
```

### Outputs attendus
- Fonction `generate_custom_report()` exportée dans package nemeton
- Rapport personnalisé HTML ou PDF
- Template réutilisable pour n'importe quelle zone

### Validation gradethis
```r
grade_result(
  pass_if(~ is.function(.result),
          "Super ! Fonction de génération de rapport créée."),
  pass_if(~ "parcels" %in% names(formals(.result)),
          "Paramètre 'parcels' présent."),
  pass_if(~ "zone_name" %in% names(formals(.result)),
          "Paramètre 'zone_name' présent.")
)
```

### Concepts enseignés
- Fonction wrapper personnalisée
- Template générique réutilisable
- Export package avec `system.file()`
- Workflow reproductible

---

## Quiz de Validation Module 5

### Question 1 : GeoPackage vs Shapefile
**Question** : Pourquoi privilégier GeoPackage (.gpkg) plutôt que Shapefile (.shp) ?

- A) GeoPackage est plus rapide
- B) GeoPackage supporte plusieurs couches et métadonnées dans un fichier unique ✓
- C) GeoPackage est plus léger
- D) GeoPackage est plus ancien

**Feedback** : GeoPackage (OGC standard) est un format moderne qui supporte multi-couches, métadonnées, et pas de limite de taille/noms.

### Question 2 : Rapport HTML vs PDF
**Question** : Quel est l'avantage principal d'un rapport HTML interactif par rapport à un PDF ?

- A) HTML est plus petit
- B) HTML permet des cartes leaflet interactives avec zoom/sélection de couches ✓
- C) HTML est plus facile à créer
- D) HTML fonctionne sans navigateur

**Feedback** : HTML permet des visualisations interactives (leaflet, plotly) impossibles en PDF statique.

### Question 3 : Export CSV
**Question** : Pourquoi exporter les centroïdes avec coordonnées XY en CSV ?

- A) Pour réduire la taille du fichier
- B) Pour permettre la re-spatialisation dans QGIS/Excel ✓
- C) Pour accélérer les calculs
- D) Pour éviter les erreurs

**Feedback** : Les coordonnées XY permettent de ré-importer les données comme couche ponctuelle dans QGIS (Join via CSV).

---

## Résumé des Fonctions Utilisées

### Fonctions sf
- `st_write(obj, path, layer, delete_dsn)` (export GeoPackage)
- `st_layers(path)` (lister couches GeoPackage)
- `st_drop_geometry()` (supprimer géométrie pour CSV)
- `st_centroid()`, `st_coordinates()` (extraire coordonnées XY)

### Fonctions RMarkdown
- `rmarkdown::render(input, output_file, output_format, params)`

### Fonctions R standard
- `write.csv(data, file, row.names = FALSE)`
- `DBI::dbConnect()`, `DBI::dbWriteTable()` (ajouter métadonnées GeoPackage)

### Packages visualisation
- **leaflet** : cartes interactives web
- **ggplot2** + **sf** : cartes statiques haute résolution
- **fmsb** : radar charts

---

## Tests Attendus (Post-Exercices)

### Test 1 : GeoPackage exporté
```r
testthat::test_that("GeoPackage créé correctement", {
  parcelles_complet <- readRDS("data/parcelles_12_familles.rds")
  output_gpkg <- "results/test_export.gpkg"

  st_write(parcelles_complet, output_gpkg, delete_dsn = TRUE)

  expect_true(file.exists(output_gpkg))
  expect_gt(file.size(output_gpkg), 1000)
  expect_equal(st_layers(output_gpkg)$name, "test_export")
})
```

### Test 2 : Rapport HTML généré
```r
testthat::test_that("Rapport HTML généré", {
  skip_if_not_installed("rmarkdown")

  parcelles_complet <- readRDS("data/parcelles_12_familles.rds")
  output_html <- tempfile(fileext = ".html")

  # Minimal template
  rmd_content <- '
---
output: html_document
params:
  parcels: NULL
---
# Test Report
`r nrow(params$parcels)` parcelles.
'
  rmd_file <- tempfile(fileext = ".Rmd")
  writeLines(rmd_content, rmd_file)

  rmarkdown::render(rmd_file, output_file = output_html, params = list(parcels = parcelles_complet), quiet = TRUE)

  expect_true(file.exists(output_html))
  expect_gt(file.size(output_html), 100)
})
```

### Test 3 : CSV exporté
```r
testthat::test_that("CSV exporté correctement", {
  parcelles_complet <- readRDS("data/parcelles_12_familles.rds")
  output_csv <- tempfile(fileext = ".csv")

  parcelles_table <- st_drop_geometry(parcelles_complet)
  write.csv(parcelles_table, output_csv, row.names = FALSE)

  expect_true(file.exists(output_csv))
  expect_gt(file.size(output_csv), 100)

  # Re-lire et vérifier
  data_read <- read.csv(output_csv)
  expect_equal(nrow(data_read), nrow(parcelles_complet))
})
```

---

## Dépendances

### Packages R requis
- **sf** >= 1.0-0 (export GeoPackage)
- **rmarkdown** >= 2.20 (rapports HTML/PDF)
- **knitr** >= 1.40 (moteur RMarkdown)
- **leaflet** >= 2.1.0 (cartes interactives)
- **DBI** + **RSQLite** (métadonnées GeoPackage)
- **ggplot2**, **fmsb**, **scales** (visualisations)
- **learnr** >= 0.11.0, **gradethis** >= 0.2.0

### Données
- `parcelles_complet` avec 12 familles (Module 3)

### Modules précédents
- **Module 3** : Fournit `parcelles_complet` (sf avec 12 familles)
- **Module 4** : Fournit visualisations (cartes, radar charts, corrélations)

### Modules suivants
Aucun (Module 5 est le dernier du workflow principal)

---

## Notes d'Implémentation

### Templates RMarkdown
Les templates `rapport_12_familles.Rmd` et `rapport_12_familles_pdf.Rmd` doivent être inclus dans :
```
inst/templates/
├── rapport_12_familles.Rmd
└── rapport_12_familles_pdf.Rmd
```

### Fonction Exportée
La fonction `generate_custom_report()` doit être exportée dans le package nemeton :
```r
#' @export
generate_custom_report <- function(parcels, zone_name, output_dir = "results",
                                   format = c("html", "pdf"), families_focus = c("B", "N", "P")) {
  # ... (code de l'exercice 5.5)
}
```

### Dépendances LaTeX pour PDF
Pour générer des PDFs, l'utilisateur doit avoir TinyTeX ou LaTeX installé :
```r
# Installation TinyTeX (recommandé)
tinytex::install_tinytex()
```
→ Mentionner dans la vignette tutorial-guide.Rmd
