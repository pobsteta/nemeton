# Indicateurs P1, P2, C1, B2, R2 via un CHM Open-Canopy

## Contexte

Depuis la spec 005, le package `nemeton` peut exploiter un **Canopy
Height Model (CHM)** — typiquement produit par le package
[`opencanopy`](https://github.com/pobsteta/opencanopynemeton) à partir
de l’ortho IGN et de modèles ML — pour estimer un véritable **indice de
station** par unité forestière. L’indice de station est la hauteur
dominante $`H_0`$ qu’un peuplement atteindrait à un âge de référence
(traditionnellement 50 ans pour les résineux, 100 ans pour les
feuillus). Il est la mesure classique de la fertilité d’une station en
foresterie française.

Jusqu’à la v0.15.x, l’indicateur `P2` utilisait un proxy combinant
fertilité × climat × essence (tables ONF/IFN). Le mode CHM introduit
dans la v0.16.0 transforme cette estimation « proxy » en une
**estimation sérieuse**, calibrée sur les courbes de Duplat & Tran-Ha
1997 et équivalents (cf. `inst/NOTICE`).

``` r

library(nemeton)
library(sf)
library(terra)
```

## Les courbes de station embarquées

Le package embarque un CSV de courbes dans
`inst/extdata/site_index_curves.csv`, couvrant les 10 essences MVP
françaises (\>90 % des surfaces productives) plus deux fallbacks
génériques.

``` r

list_site_index_species()
#>  [1] "ABAL"            "BROADLEAF_GENUS" "CASA"            "CONIFER_GENUS"  
#>  [5] "FASY"            "FASY_NE"         "FASY_NO"         "PIAB"           
#>  [9] "PIPI"            "PISY"            "POSP"            "PSME"           
#> [13] "QUPE"            "QURO"
```

Chaque courbe donne la hauteur dominante $`H(t)`$ en mètres, par classe
de fertilité (1 = meilleure, 5 = pire), de 10 à 150 ans par pas de 5.

``` r

curves <- read_site_index_curves()
head(curves)
#>   species age class_1 class_2 class_3 class_4 class_5
#> 1    QUPE  10    3.33    2.98    2.54    2.11    1.76
#> 2    QUPE  15    5.66    5.07    4.32    3.58    2.98
#> 3    QUPE  20    8.07    7.22    6.16    5.10    4.25
#> 4    QUPE  25   10.46    9.36    7.98    6.60    5.50
#> 5    QUPE  30   12.76   11.42    9.74    8.06    6.72
#> 6    QUPE  35   14.95   13.38   11.41    9.44    7.87
```

Voici l’allure des courbes pour le chêne sessile (`QUPE`) :

``` r

qupe <- curves[curves$species == "QUPE", ]
plot(NA, xlim = c(10, 150), ylim = c(0, 40),
     xlab = "Âge (ans)", ylab = expression(H[dom] ~ "(m)"),
     main = "Chêne sessile — courbes de station")
for (k in 1:5) {
  lines(qupe$age, qupe[[paste0("class_", k)]],
        col = k, lwd = 2)
}
legend("bottomright", legend = paste("Classe", 1:5),
       col = 1:5, lwd = 2, bty = "n")
```

![Courbes de hauteur dominante du chêne sessile par classe de
fertilité](site-index-open-canopy_fr_files/figure-html/unnamed-chunk-4-1.png)

## Estimer un indice de station à la main

La fonction
[`compute_site_index()`](https://pobsteta.github.io/nemeton/reference/compute_site_index.md)
prend une hauteur dominante observée, un âge et une essence, et retourne
la hauteur au `reference_age` pour la classe de fertilité interpolée.

``` r

# Chêne sessile : 20 m à 80 ans -> indice de station à 50 ans
compute_site_index(H_dom = 20, age = 80, species = "QUPE")
#> [1] 14.46525

# Épicéa commun : 25 m à 40 ans
compute_site_index(H_dom = 25, age = 40, species = "PIAB")
#> [1] 28.91933

# Vectorisé sur trois unités
compute_site_index(
  H_dom   = c(20, 25, 18),
  age     = c(80, 40, 60),
  species = c("QUPE", "PIAB", "FASY")
)
#> [1] 14.46525 28.91933 15.16204
```

Le `reference_age` est configurable — utile pour les feuillus où la
référence est traditionnellement 100 ans :

``` r

compute_site_index(H_dom = 20, age = 80, species = "QUPE",
                   reference_age = 100)
#> [1] 22.25899
```

## Workflow complet : d’un CHM fictif à l’indicateur P2

Voici une démonstration end-to-end sur un massif fictif, avec un CHM
synthétique.

``` r

# Un CHM uniforme à 25 m sur 300 x 300 m, EPSG:2154
set.seed(42)
chm <- terra::rast(
  nrows = 60, ncols = 60,
  xmin = 0, xmax = 300, ymin = 0, ymax = 300,
  crs = "EPSG:2154",
  vals = stats::rnorm(3600, mean = 25, sd = 2)
)

# Trois parcelles avec essences et âges différents
polys <- list(
  sf::st_polygon(list(rbind(c(10, 10), c(100, 10),
                            c(100, 100), c(10, 100), c(10, 10)))),
  sf::st_polygon(list(rbind(c(110, 10), c(200, 10),
                            c(200, 100), c(110, 100), c(110, 10)))),
  sf::st_polygon(list(rbind(c(210, 10), c(290, 10),
                            c(290, 100), c(210, 100), c(210, 10))))
)
units <- sf::st_sf(
  species   = c("QUPE", "FASY", "PIAB"),
  age       = c(80, 70, 40),
  geometry  = sf::st_sfc(polys, crs = 2154)
)

# Mode CHM : branche spec 005 phase 2
res <- indicateur_p2_station(units, chm = chm)
res[, c("species", "age", "P2")]
#> Simple feature collection with 3 features and 3 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 10 ymin: 10 xmax: 290 ymax: 100
#> Projected CRS: RGF93 v1 / Lambert-93
#>   species age       P2                       geometry
#> 1    QUPE  80 19.69756 POLYGON ((10 10, 100 10, 10...
#> 2    FASY  70 21.58464 POLYGON ((110 10, 200 10, 2...
#> 3    PIAB  40 29.07000 POLYGON ((210 10, 290 10, 2...
```

La colonne `P2` contient désormais l’indice de station $`H_0`$ (en
mètres) à 50 ans, **pas** le volume annuel m³/ha/an du mode historique.

## Limites et précautions

Trois points à garder à l’esprit :

1.  **RMSE du CHM ML ≈ 2-3 m**. Les hauteurs Open-Canopy sont le
    résultat d’une inférence par réseau de neurones sur l’ortho RVB+IRC.
    Elles sont **moins précises qu’un CHM LiDAR HD** (RMSE ≈ 30 cm).
    D’où le flag `augmented = c("height_ml")` dans la détection NDP, qui
    laisse la confiance Fibonacci globale inchangée (cf. ADR-011
    amendé).

2.  **[`sanitize_chm()`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md)
    est indispensable**. Le CHM doit être nettoyé avant
    [`extract_h_dom()`](https://pobsteta.github.io/nemeton/reference/extract_h_dom.md)
    : masquage forêt (BD Forêt v2 / OSO), bâtiments et eau (BD TOPO),
    seuillage NDVI, bornes plausibles (0-50 m), cohérence de pente. Un
    `pct_masked > 0.5` signale un problème d’alignement ou de millésime.

3.  **Dépendance à l’âge** :
    [`compute_site_index()`](https://pobsteta.github.io/nemeton/reference/compute_site_index.md)
    a besoin de l’âge du peuplement. Il vient de la BD Forêt v2, d’un
    inventaire ou d’un fichier cadastral. Sans âge, la fonction retourne
    `NA` pour l’unité concernée.

## Fallback génériques

Pour les essences hors liste MVP, les fallbacks sont appliqués
automatiquement :

``` r

# Acer pseudoplatanus non tabulé -> BROADLEAF_GENUS (= QUPE)
compute_site_index(H_dom = 20, age = 80, species = "ACPS")
#> [1] 14.46525

# Larix decidua non tabulé -> CONIFER_GENUS (= PIAB)
compute_site_index(H_dom = 25, age = 40, species = "LADE")
#> [1] 28.91933
```

## Volume bois sur pied — P1 en mode CHM

Depuis la spec 005 phase 3,
[`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
accepte également un CHM. En mode CHM, la hauteur utilisée par le tarif
IFN $`V = a \cdot D^b \cdot H^c`$ est extraite du CHM par
[`extract_h_dom()`](https://pobsteta.github.io/nemeton/reference/extract_h_dom.md),
au lieu d’être approximée par la formule de Näslund
$`H = 1{,}3 + 0{,}65 \cdot DBH`$. Cela réduit typiquement le RMSE de P1
de 20 à 40 % sur peuplements mûrs.

``` r

# Jeu de données : trois parcelles avec DBH et densité connus
# (issues d'un inventaire ou de BD Forêt v2), et le CHM fictif
# déjà défini plus haut.
units_p1 <- sf::st_sf(
  species  = c("QUPE", "FASY", "PIAB"),
  dbh      = c(40, 35, 30),
  height   = c(22, 24, 20),
  density  = c(180, 200, 280),
  geometry = sf::st_sfc(polys, crs = 2154)
)

# Mode legacy (H = Näslund ou height_field)
p1_legacy <- indicateur_p1_volume(units_p1)
p1_legacy[, c("species", "dbh", "P1")]
#> Simple feature collection with 3 features and 3 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 10 ymin: 10 xmax: 290 ymax: 100
#> Projected CRS: RGF93 v1 / Lambert-93
#>   species dbh       P1                       geometry
#> 1    QUPE  40 1537.922 POLYGON ((10 10, 100 10, 10...
#> 2    FASY  35 1430.763 POLYGON ((110 10, 200 10, 2...
#> 3    PIAB  30 1445.557 POLYGON ((210 10, 290 10, 2...
```

``` r

# Mode CHM : H vient du raster
p1_chm <- indicateur_p1_volume(units_p1, chm = chm)
p1_chm[, c("species", "dbh", "P1")]
#> Simple feature collection with 3 features and 3 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 10 ymin: 10 xmax: 290 ymax: 100
#> Projected CRS: RGF93 v1 / Lambert-93
#>   species dbh       P1                       geometry
#> 1    QUPE  40 1898.891 POLYGON ((10 10, 100 10, 10...
#> 2    FASY  35 1641.551 POLYGON ((110 10, 200 10, 2...
#> 3    PIAB  30 1970.401 POLYGON ((210 10, 290 10, 2...
```

Un CHM moyen plus élevé que le `height_field` stocké se traduit par des
volumes supérieurs — ce qui est cohérent puisque le peuplement réel est
plus développé que l’estimation inventaire.

#### Qualité du CHM

Si
[`sanitize_chm()`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md)
a renvoyé un `pct_masked > 0.3`, le CHM est fortement tronqué (problème
d’alignement, millésime obsolète…) et les volumes dérivés deviennent peu
fiables. On passe alors la fraction masquée à
[`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
et une alerte est émise :

``` r

# Avertissement : pct_masked = 0.5 dépasse le seuil de 0.3
res <- indicateur_p1_volume(units_p1, chm = chm, pct_masked = 0.5)
```

## Indicateurs connexes (spec 005 phase 4)

Trois indicateurs supplémentaires acceptent un CHM depuis la phase 4 :

### C1 — biomasse et stock carbone

[`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md)
ajoute une branche CHM qui calcule la biomasse via le tarif IFN
$`V = a \cdot D^b \cdot H^c`$ combiné à la densité du bois, un facteur
d’expansion de biomasse (BEF = 1,30 par défaut, IPCC 2006) et la
fraction de carbone :

``` r

units_c1 <- sf::st_sf(
  species  = c("QUPE", "PIAB"),
  dbh      = c(40, 30),
  stems_ha = c(180, 300),
  geometry = sf::st_sfc(polys[[1]], polys[[2]], crs = 2154)
)
indicateur_c1_biomasse(units_c1, chm = chm)
#> [1] 851.6527 617.9223
```

Si `stems_ha` est absent mais une colonne `density` (0-1) est présente,
elle est convertie en stems/ha par multiplication par 500. Le paramètre
`bef` est modifiable si vous disposez de valeurs calibrées localement.

### B2 — diversité structurelle

[`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md)
intègre `CV(H) = sd(H) / mean(H)` par unité lorsque le CHM est fourni.
Un CV élevé (peuplement mixte multi-strates) fait monter le score B2 :

``` r

poly_b2 <- sf::st_polygon(list(rbind(c(0, 0), c(300, 0),
                                     c(300, 300), c(0, 300),
                                     c(0, 0))))
set.seed(5)
chm_het <- terra::rast(
  nrows = 40, ncols = 40,
  xmin = 0, xmax = 300, ymin = 0, ymax = 300,
  crs = "EPSG:2154",
  vals = stats::runif(1600, 5, 35)
)
units_b2 <- sf::st_sf(
  strata    = "Dominant",
  age_class = "Mature",
  geometry  = sf::st_sfc(poly_b2, crs = 2154)
)
# Contribution CHM pondérée (20 % par défaut)
indicateur_b2_structure(units_b2, chm = chm_het)$B2
#> [1] 33.6
```

Le poids du CHM est réglable via `cv_chm_weight` (0 à 1). Une analyse de
sensibilité typique varie ce paramètre de 0 à 0,5.

### R2 — vulnérabilité tempête

[`indicateur_r2_tempete()`](https://pobsteta.github.io/nemeton/reference/indicateur_r2_tempete.md)
module le score DEM par un facteur $`f(H, espèce)`$ : à hauteur égale,
les résineux (facteur 1,2) sont plus vulnérables que les feuillus
(facteur 0,8), et plus la hauteur dominante est élevée, plus la
vulnérabilité est amplifiée (borné à $`[0{,}5, 1{,}5]`$).

``` r

# Nécessite un DEM réel
dem <- terra::rast("path/to/dem.tif")
indicateur_r2_tempete(units, dem = dem, chm = chm)
```

## Pour aller plus loin

- ADR-011 (amendement) : sémantique du flag `augmented` pour la
  détection NDP.
- Spec 005 : `specs/005-opencanopy-integration/` (plan, tâches).
- Package amont
  [`opencanopy`](https://github.com/pobsteta/opencanopynemeton) pour
  produire les CHM à partir de l’ortho IGN.
- `inst/NOTICE` pour les attributions des courbes Duplat & Tran-Ha et
  sources complémentaires.
