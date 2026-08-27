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
`label_fr`, `label_en`, `tooltip`, `tooltip_fr`, `tooltip_en`,
`doc_url`, `doc_url_fr`, `doc_url_en` and `doc_lang`.

## Indicator fact sheets (`doc_url`)

Some indicators have a long-form fact sheet published as a pkgdown
article (C1 today). `doc_url` carries its absolute URL, and is `NA` for
every indicator without one – that `NA` is the condition a UI tests
before offering a "read the fact sheet" link next to the tooltip, not an
error. The base of the URL is the first entry of the package `URL`
field, so the site address is declared once, in `DESCRIPTION`.

A fact sheet is declared per language. When the requested language has
no page but the other one does, that other page is returned rather than
`NA`: a fact sheet in the wrong language beats no fact sheet. `doc_lang`
names the language actually served, so an interface can say so instead
of opening French without warning – today
`indicator_labels(lang = "en")` returns the French C1 page with
`doc_lang == "fr"`. Compare `doc_lang` with the language you asked for;
do not assume they match.

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
#>                                                                            doc_url
#> 1            https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.html
#> 2                https://pobsteta.github.io/nemeton/articles/fiche-c2-ndvi_fr.html
#> 3          https://pobsteta.github.io/nemeton/articles/fiche-b1-protection_fr.html
#> 4           https://pobsteta.github.io/nemeton/articles/fiche-b2-structure_fr.html
#> 5        https://pobsteta.github.io/nemeton/articles/fiche-b3-connectivite_fr.html
#> 6 https://pobsteta.github.io/nemeton/articles/fiche-b4-diversite-spectrale_fr.html
#>                                                                         doc_url_fr
#> 1            https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.html
#> 2                https://pobsteta.github.io/nemeton/articles/fiche-c2-ndvi_fr.html
#> 3          https://pobsteta.github.io/nemeton/articles/fiche-b1-protection_fr.html
#> 4           https://pobsteta.github.io/nemeton/articles/fiche-b2-structure_fr.html
#> 5        https://pobsteta.github.io/nemeton/articles/fiche-b3-connectivite_fr.html
#> 6 https://pobsteta.github.io/nemeton/articles/fiche-b4-diversite-spectrale_fr.html
#>                                                                         doc_url_en
#> 1            https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.html
#> 2                https://pobsteta.github.io/nemeton/articles/fiche-c2-ndvi_fr.html
#> 3          https://pobsteta.github.io/nemeton/articles/fiche-b1-protection_fr.html
#> 4           https://pobsteta.github.io/nemeton/articles/fiche-b2-structure_fr.html
#> 5        https://pobsteta.github.io/nemeton/articles/fiche-b3-connectivite_fr.html
#> 6 https://pobsteta.github.io/nemeton/articles/fiche-b4-diversite-spectrale_fr.html
#>   doc_lang
#> 1       fr
#> 2       fr
#> 3       fr
#> 4       fr
#> 5       fr
#> 6       fr

# Lookup table: column name -> label
stats::setNames(ind$label, ind$column_name)[["indicateur_c1_biomasse"]]
#> [1] "Biomasse carbone (tC/ha)"

# Bilingual lookup, without a second call
stats::setNames(ind$label_en, ind$code)[["C1"]]
#> [1] "Carbon Biomass (tC/ha)"

# Indicators that have a fact sheet, and where to read it
ind[!is.na(ind$doc_url), c("code", "doc_url", "doc_lang")]
#>    code
#> 1    C1
#> 2    C2
#> 3    B1
#> 4    B2
#> 5    B3
#> 6    B4
#> 7    W1
#> 8    W2
#> 9    W3
#> 10   W4
#> 11   A1
#> 12   A2
#> 13   A3
#> 14   A4
#> 15   A5
#> 16   F1
#> 17   F2
#> 18   L1
#> 19   L2
#> 20   L3
#> 21   T1
#> 22   T2
#> 23   T3
#> 24   R1
#> 25   R2
#> 26   R3
#> 27   R4
#> 28   R5
#> 29   R6
#> 30   R7
#> 31   S1
#> 32   S2
#> 33   S3
#> 34   P1
#> 35   P2
#> 36   P3
#> 37   E1
#> 38   E2
#> 39   N1
#> 40   N2
#> 41   N3
#>                                                                                 doc_url
#> 1                 https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.html
#> 2                     https://pobsteta.github.io/nemeton/articles/fiche-c2-ndvi_fr.html
#> 3               https://pobsteta.github.io/nemeton/articles/fiche-b1-protection_fr.html
#> 4                https://pobsteta.github.io/nemeton/articles/fiche-b2-structure_fr.html
#> 5             https://pobsteta.github.io/nemeton/articles/fiche-b3-connectivite_fr.html
#> 6      https://pobsteta.github.io/nemeton/articles/fiche-b4-diversite-spectrale_fr.html
#> 7                   https://pobsteta.github.io/nemeton/articles/fiche-w1-reseau_fr.html
#> 8            https://pobsteta.github.io/nemeton/articles/fiche-w2-zones-humides_fr.html
#> 9                 https://pobsteta.github.io/nemeton/articles/fiche-w3-humidite_fr.html
#> 10                     https://pobsteta.github.io/nemeton/articles/fiche-w4-vpd_fr.html
#> 11              https://pobsteta.github.io/nemeton/articles/fiche-a1-couverture_fr.html
#> 12             https://pobsteta.github.io/nemeton/articles/fiche-a2-qualite-air_fr.html
#> 13             https://pobsteta.github.io/nemeton/articles/fiche-a3-microclimat_fr.html
#> 14            https://pobsteta.github.io/nemeton/articles/fiche-a4-tamponnement_fr.html
#> 15        https://pobsteta.github.io/nemeton/articles/fiche-a5-rafraichissement_fr.html
#> 16               https://pobsteta.github.io/nemeton/articles/fiche-f1-fertilite_fr.html
#> 17                 https://pobsteta.github.io/nemeton/articles/fiche-f2-erosion_fr.html
#> 18           https://pobsteta.github.io/nemeton/articles/fiche-l1-effet-lisiere_fr.html
#> 19            https://pobsteta.github.io/nemeton/articles/fiche-l2-morcellement_fr.html
#> 20 https://pobsteta.github.io/nemeton/articles/fiche-l3-heterogeneite-spectrale_fr.html
#> 21              https://pobsteta.github.io/nemeton/articles/fiche-t1-anciennete_fr.html
#> 22              https://pobsteta.github.io/nemeton/articles/fiche-t2-changement_fr.html
#> 23            https://pobsteta.github.io/nemeton/articles/fiche-t3-coupes-rases_fr.html
#> 24                     https://pobsteta.github.io/nemeton/articles/fiche-r1-feu_fr.html
#> 25                 https://pobsteta.github.io/nemeton/articles/fiche-r2-tempete_fr.html
#> 26              https://pobsteta.github.io/nemeton/articles/fiche-r3-secheresse_fr.html
#> 27          https://pobsteta.github.io/nemeton/articles/fiche-r4-abroutissement_fr.html
#> 28           https://pobsteta.github.io/nemeton/articles/fiche-r5-deperissement_fr.html
#> 29             https://pobsteta.github.io/nemeton/articles/fiche-r6-sensibilite_fr.html
#> 30                     https://pobsteta.github.io/nemeton/articles/fiche-r7-gel_fr.html
#> 31                  https://pobsteta.github.io/nemeton/articles/fiche-s1-routes_fr.html
#> 32                    https://pobsteta.github.io/nemeton/articles/fiche-s2-bati_fr.html
#> 33              https://pobsteta.github.io/nemeton/articles/fiche-s3-population_fr.html
#> 34                  https://pobsteta.github.io/nemeton/articles/fiche-p1-volume_fr.html
#> 35                 https://pobsteta.github.io/nemeton/articles/fiche-p2-station_fr.html
#> 36            https://pobsteta.github.io/nemeton/articles/fiche-p3-qualite-bois_fr.html
#> 37            https://pobsteta.github.io/nemeton/articles/fiche-e1-bois-energie_fr.html
#> 38               https://pobsteta.github.io/nemeton/articles/fiche-e2-evitement_fr.html
#> 39                https://pobsteta.github.io/nemeton/articles/fiche-n1-distance_fr.html
#> 40              https://pobsteta.github.io/nemeton/articles/fiche-n2-continuite_fr.html
#> 41              https://pobsteta.github.io/nemeton/articles/fiche-n3-naturalite_fr.html
#>    doc_lang
#> 1        fr
#> 2        fr
#> 3        fr
#> 4        fr
#> 5        fr
#> 6        fr
#> 7        fr
#> 8        fr
#> 9        fr
#> 10       fr
#> 11       fr
#> 12       fr
#> 13       fr
#> 14       fr
#> 15       fr
#> 16       fr
#> 17       fr
#> 18       fr
#> 19       fr
#> 20       fr
#> 21       fr
#> 22       fr
#> 23       fr
#> 24       fr
#> 25       fr
#> 26       fr
#> 27       fr
#> 28       fr
#> 29       fr
#> 30       fr
#> 31       fr
#> 32       fr
#> 33       fr
#> 34       fr
#> 35       fr
#> 36       fr
#> 37       fr
#> 38       fr
#> 39       fr
#> 40       fr
#> 41       fr

# A fact sheet served in a language other than the one requested
en <- indicator_labels(lang = "en")
en[!is.na(en$doc_lang) & en$doc_lang != "en", c("code", "doc_lang")]
#>    code doc_lang
#> 1    C1       fr
#> 2    C2       fr
#> 3    B1       fr
#> 4    B2       fr
#> 5    B3       fr
#> 6    B4       fr
#> 7    W1       fr
#> 8    W2       fr
#> 9    W3       fr
#> 10   W4       fr
#> 11   A1       fr
#> 12   A2       fr
#> 13   A3       fr
#> 14   A4       fr
#> 15   A5       fr
#> 16   F1       fr
#> 17   F2       fr
#> 18   L1       fr
#> 19   L2       fr
#> 20   L3       fr
#> 21   T1       fr
#> 22   T2       fr
#> 23   T3       fr
#> 24   R1       fr
#> 25   R2       fr
#> 26   R3       fr
#> 27   R4       fr
#> 28   R5       fr
#> 29   R6       fr
#> 30   R7       fr
#> 31   S1       fr
#> 32   S2       fr
#> 33   S3       fr
#> 34   P1       fr
#> 35   P2       fr
#> 36   P3       fr
#> 37   E1       fr
#> 38   E2       fr
#> 39   N1       fr
#> 40   N2       fr
#> 41   N3       fr
```
