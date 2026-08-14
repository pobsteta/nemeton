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

## Usage

``` r
indicator_labels(codes = NULL, lang = c("fr", "en"))
```

## Arguments

- codes:

  Character vector of family codes (case-insensitive), or `NULL`
  (default) for all 12 families.

- lang:

  Character. `"fr"` (default) or `"en"`.

## Value

A `data.frame` with columns `family` (family code), `code` (indicator
code), `column_name`, `label` and `tooltip`.

## See also

[`indicator_families`](https://pobsteta.github.io/nemeton/reference/indicator_families.md)

## Examples

``` r
ind <- indicator_labels()
head(ind)
#>   family code                 column_name                    label
#> 1      C   C1      indicateur_c1_biomasse Biomasse carbone (tC/ha)
#> 2      C   C2          indicateur_c2_ndvi          NDVI - Vitalité
#> 3      B   B1    indicateur_b1_protection  Protection biodiversité
#> 4      B   B2     indicateur_b2_structure    Diversité structurale
#> 5      B   B3  indicateur_b3_connectivite  Connectivité écologique
#> 6      B   B4 indicateur_b4_div_spectrale      Diversité spectrale
#>                                                                                                                                                                                                                                       tooltip
#> 1                                                                        Stock de carbone dans la biomasse aérienne (troncs, branches, feuilles). Estimé à partir de données LiDAR ou de modèles forestiers. Valeurs typiques : 50-200 tC/ha.
#> 2                                                                    Indice de végétation par différence normalisée (NDVI). Mesure la vitalité et l'activité photosynthétique de la végétation. Valeurs de 0 (sol nu) à 1 (végétation dense).
#> 3                                                                                                             Niveau de protection réglementaire (ZNIEFF, Natura 2000, Réserves). Score de 0 (aucune protection) à 100 (protection maximale).
#> 4                                                                                                                      Diversité des strates verticales et horizontales du peuplement. Basé sur l'hétérogénéité des hauteurs et des essences.
#> 5                                                                                                        Capacité de la parcelle à servir de corridor écologique. Mesure la continuité forestière et la proximité d'autres habitats naturels.
#> 6 Diversité spectrale (α) dérivée de Sentinel-2 : hétérogénéité des « spectral species » (Shannon) comme proxy de diversité compositionnelle. Proxy à valider terrain ; une futaie régulière monospécifique légitime peut avoir un score bas.

# Lookup table: column name -> label
stats::setNames(ind$label, ind$column_name)[["indicateur_c1_biomasse"]]
#> [1] "Biomasse carbone (tC/ha)"
```
