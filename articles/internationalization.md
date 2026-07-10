# Internationalisation (i18n)

## Introduction

Le package `nemeton` supporte nativement le **français** et
l’**anglais** pour tous les messages, erreurs et documentations. Cette
vignette explique comment utiliser le système d’internationalisation
(i18n).

``` r

library(nemeton)
```

## Langues supportées

| Code | Langue   | Statut  |
|------|----------|---------|
| `fr` | Français | Complet |
| `en` | English  | Complet |

## Définir la langue

### Langue par défaut

Par défaut, le package détecte la langue du système :

``` r

# Afficher la langue actuelle
Sys.getenv("LANG")
#> [1] "C.UTF-8"
```

### Changer la langue

Utilisez
[`nemeton_set_language()`](https://pobsteta.github.io/nemeton/reference/nemeton_set_language.md)
pour définir explicitement la langue :

``` r

# Passer en français
nemeton_set_language("fr")

# Switch to English
nemeton_set_language("en")
```

### Vérifier la langue active

``` r

# La langue est stockée dans une option
getOption("nemeton.lang")
# [1] "fr"  ou "en"
```

## Messages et erreurs

Les messages d’information, d’avertissement et d’erreur s’affichent dans
la langue définie.

### Exemple en français

``` r

nemeton_set_language("fr")

# Erreur si données manquantes
nemeton_compute(NULL, NULL, "indicateur_c1_biomasse")
# Erreur : Les données 'data' doivent être un objet sf
```

### Example in English

``` r

nemeton_set_language("en")

# Error with missing data
nemeton_compute(NULL, NULL, "indicateur_c1_biomasse")
# Error: 'data' must be an sf object
```

## Messages disponibles

Le système i18n couvre :

- **Erreurs de validation** : Types de données, paramètres manquants
- **Avertissements** : Indicateurs manquants, valeurs atypiques
- **Messages d’information** : Progression des calculs, résultats
- **Noms de familles** : Labels pour les 12 familles d’indicateurs

## Noms de familles bilingues

``` r

# En français
nemeton_set_language("fr")
get_family_name("C")
# [1] "Carbone & Vitalité"

get_family_name("W")
# [1] "Eau"

# In English
nemeton_set_language("en")
get_family_name("C")
# [1] "Carbon & Vitality"

get_family_name("W")
# [1] "Water Regulation"
```

## Persistance de la langue

La langue définie reste active pour toute la session R :

``` r

# Définir le français au début du script
nemeton_set_language("fr")

# Tous les appels suivants utilisent le français
results <- nemeton_compute(...)
normalized <- normalize_indicators(...)
plot_indicators_map(...)
```

## Documentation bilingue

### Aide des fonctions

La documentation des fonctions (help) est en **anglais** (standard R),
avec des exemples en français dans les vignettes.

``` r

?nemeton_compute
?plot_indicators_map
```

### Vignettes

Les vignettes sont disponibles en **français** :

- [`vignette("getting-started_fr")`](https://pobsteta.github.io/nemeton/articles/getting-started_fr.md) -
  Démarrage rapide
- [`vignette("indicator-families_fr")`](https://pobsteta.github.io/nemeton/articles/indicator-families_fr.md) -
  Familles d’indicateurs
- [`vignette("temporal-analysis_fr")`](https://pobsteta.github.io/nemeton/articles/temporal-analysis_fr.md) -
  Analyse temporelle

## Contribuer aux traductions

Le système i18n utilise des fichiers de traduction dans `R/i18n.R`.

### Structure des messages

``` r

# Exemple de structure interne
messages <- list(
  fr = list(
    error_no_data = "Les données 'data' doivent être un objet sf",
    info_computing = "Calcul de {n} indicateurs..."
  ),
  en = list(
    error_no_data = "'data' must be an sf object",
    info_computing = "Computing {n} indicators..."
  )
)
```

### Ajouter une traduction

Pour contribuer une nouvelle langue :

1.  Créer une nouvelle section dans `R/i18n.R`
2.  Traduire tous les messages
3.  Mettre à jour
    [`nemeton_set_language()`](https://pobsteta.github.io/nemeton/reference/nemeton_set_language.md)
    pour supporter le nouveau code langue
4.  Soumettre une Pull Request

## Exemple complet bilingue

``` r

# ===== VERSION FRANÇAISE =====
nemeton_set_language("fr")

data(massif_demo_units)
layers <- massif_demo_layers()

results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "indicateur_c1_biomasse"
)
# ℹ Calcul de 1 indicateurs...
# ✔ 1/1 indicateurs calculés

plot_indicators_map(
  results,
  indicators = "indicateur_c1_biomasse",
  title = "Stock de carbone",
  legend_title = "Mg C/parcel"
)

# ===== ENGLISH VERSION =====
nemeton_set_language("en")

data(massif_demo_units)
layers <- massif_demo_layers()

results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "indicateur_c1_biomasse"
)
# ℹ Computing 1 indicators...
# ✔ 1/1 indicators computed

plot_indicators_map(
  results,
  indicators = "indicateur_c1_biomasse",
  title = "Carbon Stock",
  legend_title = "Mg C/parcel"
)
```

## Bonnes pratiques

1.  **Définir la langue une seule fois** au début du script
2.  **Documenter la langue utilisée** dans vos analyses
3.  **Utiliser les noms de familles localisés** avec
    [`get_family_name()`](https://pobsteta.github.io/nemeton/reference/get_family_name.md)
4.  **Tester les deux langues** si vous partagez du code international

## Limitations

- **Documentation R** : Aide des fonctions uniquement en anglais
  (standard CRAN)
- **Noms de colonnes** : Identifiants techniques toujours en anglais
  (ex: `carbon_norm`)
- **Palettes et thèmes** : Labels graphiques définis par l’utilisateur

## Roadmap

**Versions futures** : - Support additionnel : Espagnol, Italien,
Allemand - Traduction automatique des labels de graphiques - Templates
de rapports multilingues

## Session Info

``` r

sessionInfo()
#> R version 4.6.1 (2026-06-24)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 24.04.4 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.26.so;  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=C.UTF-8       LC_NUMERIC=C           LC_TIME=C.UTF-8       
#>  [4] LC_COLLATE=C.UTF-8     LC_MONETARY=C.UTF-8    LC_MESSAGES=C.UTF-8   
#>  [7] LC_PAPER=C.UTF-8       LC_NAME=C              LC_ADDRESS=C          
#> [10] LC_TELEPHONE=C         LC_MEASUREMENT=C.UTF-8 LC_IDENTIFICATION=C   
#> 
#> time zone: UTC
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] nemeton_0.147.3.9000
#> 
#> loaded via a namespace (and not attached):
#>  [1] terra_1.9-34       cli_3.6.6          knitr_1.51         rlang_1.3.0       
#>  [5] xfun_0.60          KernSmooth_2.23-26 otel_0.2.0         DBI_1.3.0         
#>  [9] textshaping_1.0.5  sf_1.1-1           jsonlite_2.0.0     glue_1.8.1        
#> [13] e1071_1.7-17       htmltools_0.5.9    ragg_1.5.2         sass_0.4.10       
#> [17] rmarkdown_2.31     grid_4.6.1         classInt_0.4-11    evaluate_1.0.5    
#> [21] jquerylib_0.1.4    fastmap_1.2.0      yaml_2.3.12        lifecycle_1.0.5   
#> [25] compiler_4.6.1     codetools_0.2-20   fs_2.1.0           Rcpp_1.1.2        
#> [29] htmlwidgets_1.6.4  systemfonts_1.3.2  digest_0.6.39      R6_2.6.1          
#> [33] class_7.3-23       bslib_0.11.0       proxy_0.4-29       tools_4.6.1       
#> [37] units_1.0-1        pkgdown_2.2.1      cachem_1.1.0       desc_1.4.3
```
