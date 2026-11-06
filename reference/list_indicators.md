# List available indicators

Returns the indicators of the 12-family framework: the **43 indicators**
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

  Logical. Include the twelve source-conditional indicators? Default
  `TRUE` (all 43).

## Value

Character vector of indicator names, or a data.frame with columns
`name`, `code`, `family`, `category`, `description`, `conditionnel`
(logical) and `source_conditionnelle` (the missing source that leaves
the indicator `NA`, `NA` for the base indicators).

## Details

Twelve indicators are **conditional**: they need a source that the
public NDP 0 layers do not provide, and return `NA` (with a
`<code>_status` column such as `"skipped_no_micro"`) when it is absent,
never an error. They are B4 and L3 (Sentinel-2 spectral diversity), B5
(LiDAR point cloud, spec 067), W4, A3, A4 and R6 (precomputed
microclimate), A5 (land-surface temperature), R5 (FORDEAD or RECONFORT
dieback), R7 (daily minimum temperature), T3 (SUFOSAT clear-cuts) and N5
(foundation-model embedding, spec 064). `conditionnels = FALSE` keeps
only the 31 indicators that the base layers can compute.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057). Since 1.0.0 the list
holds all the indicators (31 before; 41 in 1.0.0, 42 since N5, spec 064;
43 since B5, spec 067) and the details carry `code`, `conditionnel` and
`source_conditionnelle`.

## Examples

``` r
# All 43 indicator names
list_indicators()
#>  [1] "indicateur_c1_biomasse"           "indicateur_c2_ndvi"              
#>  [3] "indicateur_b1_protection"         "indicateur_b2_structure"         
#>  [5] "indicateur_b3_connectivite"       "indicateur_b4_div_spectrale"     
#>  [7] "indicateur_b5_stratification"     "indicateur_w1_reseau"            
#>  [9] "indicateur_w2_zones_humides"      "indicateur_w3_humidite"          
#> [11] "indicateur_w4_vpd"                "indicateur_a1_couverture"        
#> [13] "indicateur_a2_qualite_air"        "indicateur_a3_microclimat"       
#> [15] "indicateur_a4_tamponnement"       "indicateur_a5_rafraichissement"  
#> [17] "indicateur_f1_fertilite"          "indicateur_f2_erosion"           
#> [19] "indicateur_l1_effet_lisiere"      "indicateur_l2_morcellement"      
#> [21] "indicateur_l3_het_spectrale"      "indicateur_t1_anciennete"        
#> [23] "indicateur_t2_changement"         "indicateur_t3_coupes_rases"      
#> [25] "indicateur_r1_feu"                "indicateur_r2_tempete"           
#> [27] "indicateur_r3_secheresse"         "indicateur_r4_abroutissement"    
#> [29] "indicateur_r5_deperissement"      "indicateur_r6_sensibilite"       
#> [31] "indicateur_r7_gel"                "indicateur_s1_routes"            
#> [33] "indicateur_s2_bati"               "indicateur_s3_population"        
#> [35] "indicateur_p1_volume"             "indicateur_p2_station"           
#> [37] "indicateur_p3_qualite_bois"       "indicateur_e1_bois_energie"      
#> [39] "indicateur_e2_evitement"          "indicateur_n1_distance"          
#> [41] "indicateur_n2_continuite"         "indicateur_n3_naturalite"        
#> [43] "indicateur_n5_distance_reference"

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
