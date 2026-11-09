# Basic wood density (infradensity) of IFN species

Basic wood density (oven-dry mass over green volume, g/cm3) of each IFN
species (`espar`), from the Global Wood Density Database (Chave et al.
2009, Zanne et al. 2009, doi:10.5061/dryad.234, CC0). This is the
density that turns a standing volume into a dry biomass; an air-dry
density (about 12 % moisture) is 15 to 25 % higher.

The `niveau` column tells where the value comes from, from the most to
the least precise: `"espece_europe"` (mean of the species' European
records), `"espece"` (all regions), `"genre"` (mean of the species means
of the genus in Europe and North America) and `"groupe"` (mean of the
broadleaved or coniferous IFN species valued at species level). Two
generic rows, `"FEUILLU"` and `"RESINEUX"`, carry the group values.

## Usage

``` r
infradensite_espar(espar = NULL)
```

## Arguments

- espar:

  Optional. Species codes in any nomenclature accepted by
  [`resoudre_espar()`](https://pobsteta.github.io/nemeton/reference/resoudre_espar.md)
  (IFN `espar`, four-letter code, Latin name, French label). Codes that
  do not resolve, or the generic `"BROADLEAF_GENUS"` and
  `"CONIFER_GENUS"`, take the broadleaved or coniferous group value (by
  the package's conifer list). `NULL` (default) returns the whole table.

## Value

Without `espar`, a data.frame with `espar`, `lib_espar`, `nom_latin`,
`groupe`, `infradensite_g_cm3`, `niveau`, `n_valeurs` (records or
species averaged) and `source`. With `espar`, the matching rows in the
order of `espar` (the group row where a code does not resolve), plus a
column `code` holding the input; `NA` for a `NA` input.

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).

## See also

[`ifn_espar_correspondance()`](https://pobsteta.github.io/nemeton/reference/ifn_espar_correspondance.md),
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md),
[`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md)

## Examples

``` r
infradensite_espar(c("09", "PIAB", "Quercus pubescens", "CONIFER_GENUS"))
#>                code    espar       lib_espar         nom_latin   groupe
#> 1                09       09           Hêtre   Fagus sylvatica  feuillu
#> 2              PIAB       62   Épicéa commun       Picea abies resineux
#> 3 Quercus pubescens       05 Chêne pubescent Quercus pubescens  feuillu
#> 4     CONIFER_GENUS RESINEUX        Résineux              <NA> resineux
#>   infradensite_g_cm3        niveau n_valeurs
#> 1              0.585 espece_europe         2
#> 2              0.370 espece_europe         1
#> 3              0.669         genre        37
#> 4              0.413        groupe        37
#>                                                                         source
#> 1 Global Wood Density Database (Zanne et al. 2009, doi:10.5061/dryad.234, CC0)
#> 2 Global Wood Density Database (Zanne et al. 2009, doi:10.5061/dryad.234, CC0)
#> 3 Global Wood Density Database (Zanne et al. 2009, doi:10.5061/dryad.234, CC0)
#> 4 Global Wood Density Database (Zanne et al. 2009, doi:10.5061/dryad.234, CC0)
```
