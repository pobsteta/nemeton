# List available indicators

Returns the indicators of the 12-family framework: the **41 indicators**
of
[`indicator_families()`](https://pobsteta.github.io/nemeton/reference/indicator_families.md),
in the same order, including the source-conditional ones.

## Usage

``` r
list_indicators(
  category = "all",
  return_type = c("names", "details"),
  conditionnels = TRUE
)
```

## Arguments

- category:

  Character. Filter by category: `"all"` (default), `"biophysical"`,
  `"landscape"`, `"risk"`, `"temporal"`, `"social"`, `"productive"`,
  `"energy"`, `"naturalness"`.

- return_type:

  Character. Return `"names"` (default) or `"details"` (data.frame with
  descriptions).

- conditionnels:

  Logical. Include the ten source-conditional indicators? Default `TRUE`
  (all 41).

## Value

Character vector of indicator names, or a data.frame with columns
`name`, `code`, `family`, `category`, `description`, `conditionnel`
(logical) and `source_conditionnelle` (the missing source that leaves
the indicator `NA`, `NA` for the base indicators).

## Details

Ten indicators are **conditional**: they need a source that the public
NDP 0 layers do not provide, and return `NA` (with a `<code>_status`
column such as `"skipped_no_micro"`) when it is absent, never an error.
They are B4 and L3 (Sentinel-2 spectral diversity), W4, A3, A4 and R6
(precomputed microclimate), A5 (land-surface temperature), R5 (FORDEAD
or RECONFORT dieback), R7 (daily minimum temperature) and T3 (SUFOSAT
clear-cuts). `conditionnels = FALSE` keeps only the 31 indicators that
the base layers can compute.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057). Since 1.0.0 the list
holds all 41 indicators (31 before) and the details carry `code`,
`conditionnel` and `source_conditionnelle`.

## Examples

``` r
# All 41 indicator names
list_indicators()
#>  [1] "indicateur_c1_biomasse"         "indicateur_c2_ndvi"            
#>  [3] "indicateur_b1_protection"       "indicateur_b2_structure"       
#>  [5] "indicateur_b3_connectivite"     "indicateur_b4_div_spectrale"   
#>  [7] "indicateur_w1_reseau"           "indicateur_w2_zones_humides"   
#>  [9] "indicateur_w3_humidite"         "indicateur_w4_vpd"             
#> [11] "indicateur_a1_couverture"       "indicateur_a2_qualite_air"     
#> [13] "indicateur_a3_microclimat"      "indicateur_a4_tamponnement"    
#> [15] "indicateur_a5_rafraichissement" "indicateur_f1_fertilite"       
#> [17] "indicateur_f2_erosion"          "indicateur_l1_effet_lisiere"   
#> [19] "indicateur_l2_morcellement"     "indicateur_l3_het_spectrale"   
#> [21] "indicateur_t1_anciennete"       "indicateur_t2_changement"      
#> [23] "indicateur_t3_coupes_rases"     "indicateur_r1_feu"             
#> [25] "indicateur_r2_tempete"          "indicateur_r3_secheresse"      
#> [27] "indicateur_r4_abroutissement"   "indicateur_r5_deperissement"   
#> [29] "indicateur_r6_sensibilite"      "indicateur_r7_gel"             
#> [31] "indicateur_s1_routes"           "indicateur_s2_bati"            
#> [33] "indicateur_s3_population"       "indicateur_p1_volume"          
#> [35] "indicateur_p2_station"          "indicateur_p3_qualite_bois"    
#> [37] "indicateur_e1_bois_energie"     "indicateur_e2_evitement"       
#> [39] "indicateur_n1_distance"         "indicateur_n2_continuite"      
#> [41] "indicateur_n3_naturalite"      

# Only those computable from the base layers
list_indicators(conditionnels = FALSE)
#>  [1] "indicateur_c1_biomasse"       "indicateur_c2_ndvi"          
#>  [3] "indicateur_b1_protection"     "indicateur_b2_structure"     
#>  [5] "indicateur_b3_connectivite"   "indicateur_w1_reseau"        
#>  [7] "indicateur_w2_zones_humides"  "indicateur_w3_humidite"      
#>  [9] "indicateur_a1_couverture"     "indicateur_a2_qualite_air"   
#> [11] "indicateur_f1_fertilite"      "indicateur_f2_erosion"       
#> [13] "indicateur_l1_effet_lisiere"  "indicateur_l2_morcellement"  
#> [15] "indicateur_t1_anciennete"     "indicateur_t2_changement"    
#> [17] "indicateur_r1_feu"            "indicateur_r2_tempete"       
#> [19] "indicateur_r3_secheresse"     "indicateur_r4_abroutissement"
#> [21] "indicateur_s1_routes"         "indicateur_s2_bati"          
#> [23] "indicateur_s3_population"     "indicateur_p1_volume"        
#> [25] "indicateur_p2_station"        "indicateur_p3_qualite_bois"  
#> [27] "indicateur_e1_bois_energie"   "indicateur_e2_evitement"     
#> [29] "indicateur_n1_distance"       "indicateur_n2_continuite"    
#> [31] "indicateur_n3_naturalite"    

# Details
head(list_indicators(return_type = "details"))
#>                          name code family    category
#> 1      indicateur_c1_biomasse   C1      C biophysical
#> 2          indicateur_c2_ndvi   C2      C biophysical
#> 3    indicateur_b1_protection   B1      B biophysical
#> 4     indicateur_b2_structure   B2      B biophysical
#> 5  indicateur_b3_connectivite   B3      B biophysical
#> 6 indicateur_b4_div_spectrale   B4      B biophysical
#>                                       description conditionnel
#> 1 Carbon stock via biomass allometric models (C1)        FALSE
#> 2               Vegetation vitality via NDVI (C2)        FALSE
#> 3             Biodiversity protection status (B1)        FALSE
#> 4                       Structural diversity (B2)        FALSE
#> 5                       Habitat connectivity (B3)        FALSE
#> 6       Spectral alpha diversity, Sentinel-2 (B4)         TRUE
#>   source_conditionnelle
#> 1                  <NA>
#> 2                  <NA>
#> 3                  <NA>
#> 4                  <NA>
#> 5                  <NA>
#> 6              spectral
```
