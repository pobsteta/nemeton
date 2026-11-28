# Validate a P4 parameter list

Aborts with class `nemeton_p4_parametres_invalides` when a vocation, a
hazard or a field is missing, or when a value is out of its domain.

## Usage

``` r
p4_valider_parametres(p)
```

## Arguments

- p:

  Named list, as read by
  [`p4_parametres()`](https://pobsteta.github.io/nemeton/reference/p4_parametres.md).

## Value

`p`, invisibly valid.

## Examples

``` r
p4_valider_parametres(p4_parametres())
#> $version
#> [1] 1
#> 
#> $provisoire
#> [1] TRUE
#> 
#> $plafond_score
#> [1] 0.06
#> 
#> $seuil_decision
#> [1] 0.005
#> 
#> $horizon_ans
#> [1] 20
#> 
#> $plafond_exposition
#> [1] 0.2
#> 
#> $aleas
#> $aleas$incendie
#> $aleas$incendie$score
#> [1] "R1"
#> 
#> $aleas$incendie$p_max
#> [1] 0.01
#> 
#> $aleas$incendie$part_perdue
#> [1] 0.8
#> 
#> $aleas$incendie$portee
#> [1] "localisee"
#> 
#> 
#> $aleas$tempete
#> $aleas$tempete$score
#> [1] "R2"
#> 
#> $aleas$tempete$p_max
#> [1] 0.02
#> 
#> $aleas$tempete$part_perdue
#> [1] 0.5
#> 
#> $aleas$tempete$portee
#> [1] "systemique"
#> 
#> 
#> $aleas$secheresse_sanitaire
#> $aleas$secheresse_sanitaire$score
#> [1] "R3" "R5"
#> 
#> $aleas$secheresse_sanitaire$p_max
#> [1] 0.03
#> 
#> $aleas$secheresse_sanitaire$part_perdue
#> [1] 0.4
#> 
#> $aleas$secheresse_sanitaire$portee
#> [1] "systemique"
#> 
#> 
#> $aleas$abroutissement
#> $aleas$abroutissement$score
#> [1] "R4"
#> 
#> $aleas$abroutissement$p_max
#> [1] 0.02
#> 
#> $aleas$abroutissement$part_perdue
#> [1] 0.1
#> 
#> $aleas$abroutissement$portee
#> [1] "localisee"
#> 
#> 
#> 
#> $vocations
#> $vocations$production
#> $vocations$production$taux_exige
#> [1] 0.03
#> 
#> $vocations$production$si_ecart_negatif
#> [1] "recolter"
#> 
#> 
#> $vocations$mixte
#> $vocations$mixte$taux_exige
#> [1] 0.02
#> 
#> $vocations$mixte$si_ecart_negatif
#> [1] "recolter"
#> 
#> 
#> $vocations$protection
#> $vocations$protection$taux_exige
#> [1] 0.01
#> 
#> $vocations$protection$si_ecart_negatif
#> [1] "surveiller"
#> 
#> 
#> $vocations$accueil
#> $vocations$accueil$taux_exige
#> [1] 0.01
#> 
#> $vocations$accueil$si_ecart_negatif
#> [1] "surveiller"
#> 
#> 
#> $vocations$naturalite
#> $vocations$naturalite$taux_exige
#> [1] 0
#> 
#> $vocations$naturalite$si_ecart_negatif
#> [1] "surveiller"
#> 
#> 
#> 
#> $prix
#> $prix$provisoire
#> [1] TRUE
#> 
#> $prix$par_essence
#> named list()
#> 
#> 
```
