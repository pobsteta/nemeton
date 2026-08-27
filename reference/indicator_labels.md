# Indicator table (long format)

One row per indicator, flattening
[`indicator_families`](https://pobsteta.github.io/nemeton/reference/indicator_families.md).
Useful to build a label lookup keyed by indicator code or by column
name, without re-declaring the strings downstream.

Rows follow the canonical family order, and within a family the
declaration order of the indicators. `column_name` is the column paired
with `code` – see the *Column pairing* section of
[`indicator_families`](https://pobsteta.github.io/nemeton/reference/indicator_families.md)
for the two families where the short code and the column slug disagree.

As in
[`indicator_families`](https://pobsteta.github.io/nemeton/reference/indicator_families.md),
both languages are always returned: `lang` only selects which one is
copied into the convenience columns `label` and `tooltip`.

## Usage

``` r
indicator_labels(codes = NULL, lang = c("fr", "en"))
```

## Arguments

- codes:

  Character vector of family codes (case-insensitive), or `NULL`
  (default) for all 12 families.

- lang:

  Character. Language copied into `label` and `tooltip`: `"fr"`
  (default) or `"en"`. The `_fr` / `_en` columns are returned
  regardless.

## Value

A `data.frame` with columns `family` (family code), `family_column`
(family score column), `code` (indicator code), `column_name`, `label`,
`label_fr`, `label_en`, `tooltip`, `tooltip_fr` and `tooltip_en`.

## See also

[`indicator_families`](https://pobsteta.github.io/nemeton/reference/indicator_families.md)

## Examples

``` r
ind <- indicator_labels()
head(ind)
#>   family        family_column code                 column_name
#> 1      C      famille_carbone   C1      indicateur_c1_biomasse
#> 2      C      famille_carbone   C2          indicateur_c2_ndvi
#> 3      B famille_biodiversite   B1    indicateur_b1_protection
#> 4      B famille_biodiversite   B2     indicateur_b2_structure
#> 5      B famille_biodiversite   B3  indicateur_b3_connectivite
#> 6      B famille_biodiversite   B4 indicateur_b4_div_spectrale
#>                      label                 label_fr                label_en
#> 1 Biomasse carbone (tC/ha) Biomasse carbone (tC/ha)  Carbon Biomass (tC/ha)
#> 2          NDVI - Vitalité          NDVI - Vitalité         NDVI - Vitality
#> 3  Protection biodiversité  Protection biodiversité Biodiversity Protection
#> 4    Diversité structurale    Diversité structurale    Structural Diversity
#> 5  Connectivité écologique  Connectivité écologique Ecological Connectivity
#> 6      Diversité spectrale      Diversité spectrale      Spectral Diversity
#>                                                                                                                                                                                                                                                                                                                                 tooltip
#> 1                                                                                                                                                                  Stock de carbone dans la biomasse aérienne (troncs, branches, feuilles). Estimé à partir de données LiDAR ou de modèles forestiers. Valeurs typiques : 50-200 tC/ha.
#> 2                                                                                                                                                              Indice de végétation par différence normalisée (NDVI). Mesure la vitalité et l'activité photosynthétique de la végétation. Valeurs de 0 (sol nu) à 1 (végétation dense).
#> 3                                                                                                                                                                                                       Niveau de protection réglementaire (ZNIEFF, Natura 2000, Réserves). Score de 0 (aucune protection) à 100 (protection maximale).
#> 4                                                                                                                                                                                                                Diversité des strates verticales et horizontales du peuplement. Basé sur l'hétérogénéité des hauteurs et des essences.
#> 5                                                                                                                                                                                                  Capacité de la parcelle à servir de corridor écologique. Mesure la continuité forestière et la proximité d'autres habitats naturels.
#> 6 Diversité spectrale (α) dérivée de Sentinel-2 : indice de Shannon des « spectral species » par fenêtre de 100 m, moyenné sur l’unité. Le score atteint 100 pour l’équivalent de 10 spectral species également abondantes par hectare. Proxy à valider terrain ; une futaie régulière monospécifique légitime peut avoir un score bas.
#>                                                                                                                                                                                                                                                                                                                              tooltip_fr
#> 1                                                                                                                                                                  Stock de carbone dans la biomasse aérienne (troncs, branches, feuilles). Estimé à partir de données LiDAR ou de modèles forestiers. Valeurs typiques : 50-200 tC/ha.
#> 2                                                                                                                                                              Indice de végétation par différence normalisée (NDVI). Mesure la vitalité et l'activité photosynthétique de la végétation. Valeurs de 0 (sol nu) à 1 (végétation dense).
#> 3                                                                                                                                                                                                       Niveau de protection réglementaire (ZNIEFF, Natura 2000, Réserves). Score de 0 (aucune protection) à 100 (protection maximale).
#> 4                                                                                                                                                                                                                Diversité des strates verticales et horizontales du peuplement. Basé sur l'hétérogénéité des hauteurs et des essences.
#> 5                                                                                                                                                                                                  Capacité de la parcelle à servir de corridor écologique. Mesure la continuité forestière et la proximité d'autres habitats naturels.
#> 6 Diversité spectrale (α) dérivée de Sentinel-2 : indice de Shannon des « spectral species » par fenêtre de 100 m, moyenné sur l’unité. Le score atteint 100 pour l’équivalent de 10 spectral species également abondantes par hectare. Proxy à valider terrain ; une futaie régulière monospécifique légitime peut avoir un score bas.
#>                                                                                                                                                                                                                                                                                                     tooltip_en
#> 1                                                                                                                                                                   Carbon stock in above-ground biomass (trunks, branches, leaves). Estimated from LiDAR data or forest models. Typical values: 50-200 tC/ha.
#> 2                                                                                                                                                  Normalized Difference Vegetation Index (NDVI). Measures vegetation vitality and photosynthetic activity. Values from 0 (bare soil) to 1 (dense vegetation).
#> 3                                                                                                                                                                                    Level of regulatory protection (ZNIEFF, Natura 2000, Reserves). Score from 0 (no protection) to 100 (maximum protection).
#> 4                                                                                                                                                                                                             Diversity of vertical and horizontal stand structure. Based on height and species heterogeneity.
#> 5                                                                                                                                                                                    Parcel's capacity to serve as an ecological corridor. Measures forest continuity and proximity to other natural habitats.
#> 6 Spectral (α) diversity from Sentinel-2: Shannon index of spectral species over 100 m windows, averaged over the unit. The score reaches 100 for the equivalent of 10 equally abundant spectral species per hectare. Proxy pending field validation; a legitimate even-aged monospecific stand may score low.

# Lookup table: column name -> label
stats::setNames(ind$label, ind$column_name)[["indicateur_c1_biomasse"]]
#> [1] "Biomasse carbone (tC/ha)"

# Bilingual lookup, without a second call
stats::setNames(ind$label_en, ind$code)[["C1"]]
#> [1] "Carbon Biomass (tC/ha)"
```
