# Validate a P4 rules list

Aborts with class `nemeton_p4_regles_invalides` when a rule is
malformed, a decision/Pareto case is not covered exactly once, an action
id is repeated, the status quo option is not neutral, a harvest bound is
out of range or `coupe_rase` is not `FALSE`.

## Usage

``` r
p4_valider_regles_actions(r)
```

## Arguments

- r:

  Named list, as read by
  [`p4_regles_actions()`](https://pobsteta.github.io/nemeton/reference/p4_regles_actions.md).

## Value

`r`, invisibly valid.

## Examples

``` r
p4_valider_regles_actions(p4_regles_actions())
#> $version
#> [1] 1
#> 
#> $provisoire
#> [1] TRUE
#> 
#> $seuil_alea
#> [1] 0.005
#> 
#> $ndp_min_decision
#> [1] 3
#> 
#> $vocations_recolte
#> [1] "production" "mixte"     
#> 
#> $bornes_prelevement
#> $bornes_prelevement$coupe_rase
#> [1] FALSE
#> 
#> $bornes_prelevement$prelevement_max_part_capital
#> [1] 0.25
#> 
#> 
#> $axes_proteges_vocation
#> $axes_proteges_vocation$production
#> list()
#> 
#> $axes_proteges_vocation$mixte
#> list()
#> 
#> $axes_proteges_vocation$protection
#> [1] "B" "W" "N"
#> 
#> $axes_proteges_vocation$accueil
#> [1] "S" "L" "B"
#> 
#> $axes_proteges_vocation$naturalite
#> [1] "B" "N"
#> 
#> 
#> $axes_proteges_mode
#> [1] "ecarter"
#> 
#> $regles_decision
#> $regles_decision[[1]]
#> $regles_decision[[1]]$id
#> [1] "D1"
#> 
#> $regles_decision[[1]]$decision
#> [1] "capitaliser"
#> 
#> $regles_decision[[1]]$pareto
#> [1] "indifferent"
#> 
#> $regles_decision[[1]]$actions
#> $regles_decision[[1]]$actions[[1]]
#> $regles_decision[[1]]$actions[[1]]$id
#> [1] "pas_de_coupe_au_dela_accroissement"
#> 
#> $regles_decision[[1]]$actions[[1]]$tableau
#> [1] "travaux"
#> 
#> $regles_decision[[1]]$actions[[1]]$recolte
#> [1] FALSE
#> 
#> $regles_decision[[1]]$actions[[1]]$libelle
#> [1] "Pas de coupe au-dela de l'accroissement ; travaux d'amelioration au profit des tiges d'avenir"
#> 
#> 
#> 
#> 
#> $regles_decision[[2]]
#> $regles_decision[[2]]$id
#> [1] "D2"
#> 
#> $regles_decision[[2]]$decision
#> [1] "equilibre"
#> 
#> $regles_decision[[2]]$pareto
#> [1] "indifferent"
#> 
#> $regles_decision[[2]]$actions
#> $regles_decision[[2]]$actions[[1]]
#> $regles_decision[[2]]$actions[[1]]$id
#> [1] "coupe_accroissement"
#> 
#> $regles_decision[[2]]$actions[[1]]$tableau
#> [1] "coupes"
#> 
#> $regles_decision[[2]]$actions[[1]]$recolte
#> [1] TRUE
#> 
#> $regles_decision[[2]]$actions[[1]]$libelle
#> [1] "Coupe prelevant l'accroissement a la rotation prevue"
#> 
#> 
#> 
#> 
#> $regles_decision[[3]]
#> $regles_decision[[3]]$id
#> [1] "D3a"
#> 
#> $regles_decision[[3]]$decision
#> [1] "recolter"
#> 
#> $regles_decision[[3]]$pareto
#> [1] "domine"
#> 
#> $regles_decision[[3]]$actions
#> $regles_decision[[3]]$actions[[1]]
#> $regles_decision[[3]]$actions[[1]]$id
#> [1] "coupe_decapitalisation_ciblee"
#> 
#> $regles_decision[[3]]$actions[[1]]$tableau
#> [1] "coupes"
#> 
#> $regles_decision[[3]]$actions[[1]]$recolte
#> [1] TRUE
#> 
#> $regles_decision[[3]]$actions[[1]]$libelle
#> [1] "Coupe de decapitalisation ciblee sur les tiges exposees et peu dynamiques"
#> 
#> 
#> $regles_decision[[3]]$actions[[2]]
#> $regles_decision[[3]]$actions[[2]]$id
#> [1] "conversion_diversification"
#> 
#> $regles_decision[[3]]$actions[[2]]$tableau
#> [1] "travaux"
#> 
#> $regles_decision[[3]]$actions[[2]]$recolte
#> [1] FALSE
#> 
#> $regles_decision[[3]]$actions[[2]]$libelle
#> [1] "Option de conversion ou de diversification des essences"
#> 
#> 
#> 
#> 
#> $regles_decision[[4]]
#> $regles_decision[[4]]$id
#> [1] "D3b"
#> 
#> $regles_decision[[4]]$decision
#> [1] "recolter"
#> 
#> $regles_decision[[4]]$pareto
#> [1] "non_domine"
#> 
#> $regles_decision[[4]]$actions
#> $regles_decision[[4]]$actions[[1]]
#> $regles_decision[[4]]$actions[[1]]$id
#> [1] "note_arbitrage_taux_exige"
#> 
#> $regles_decision[[4]]$actions[[1]]$tableau
#> [1] "aucun"
#> 
#> $regles_decision[[4]]$actions[[1]]$recolte
#> [1] FALSE
#> 
#> $regles_decision[[4]]$actions[[1]]$libelle
#> [1] "Pas de coupe automatique : arbitrage a signaler, revoir le taux exige ou une intervention legere"
#> 
#> 
#> 
#> 
#> $regles_decision[[5]]
#> $regles_decision[[5]]$id
#> [1] "D4"
#> 
#> $regles_decision[[5]]$decision
#> [1] "surveiller"
#> 
#> $regles_decision[[5]]$pareto
#> [1] "indifferent"
#> 
#> $regles_decision[[5]]$actions
#> $regles_decision[[5]]$actions[[1]]
#> $regles_decision[[5]]$actions[[1]]$id
#> [1] "suivi_sanitaire_renforce"
#> 
#> $regles_decision[[5]]$actions[[1]]$tableau
#> [1] "travaux"
#> 
#> $regles_decision[[5]]$actions[[1]]$recolte
#> [1] FALSE
#> 
#> $regles_decision[[5]]$actions[[1]]$libelle
#> [1] "Suivi sanitaire renforce, aucune coupe motivee par P4"
#> 
#> 
#> 
#> 
#> 
#> $acquisition
#> $acquisition$id
#> [1] "S1"
#> 
#> $acquisition$actions
#> $acquisition$actions[[1]]
#> $acquisition$actions[[1]]$id
#> [1] "inventaire_terrain"
#> 
#> $acquisition$actions[[1]]$tableau
#> [1] "travaux"
#> 
#> $acquisition$actions[[1]]$recolte
#> [1] FALSE
#> 
#> $acquisition$actions[[1]]$libelle
#> [1] "Acquisition de donnees : inventaire de terrain avant toute decision de coupe"
#> 
#> 
#> 
#> 
#> $concentrante
#> $concentrante$id
#> [1] "C1"
#> 
#> $concentrante$actions
#> $concentrante$actions[[1]]
#> $concentrante$actions[[1]]$id
#> [1] "reduction_exposition_diversification"
#> 
#> $concentrante$actions[[1]]$tableau
#> [1] "travaux"
#> 
#> $concentrante$actions[[1]]$recolte
#> [1] FALSE
#> 
#> $concentrante$actions[[1]]$libelle
#> [1] "Reduction d'exposition : diversification des essences et des classes de hauteur"
#> 
#> 
#> $concentrante$actions[[2]]
#> $concentrante$actions[[2]]$id
#> [1] "etalement_recoltes"
#> 
#> $concentrante$actions[[2]]$tableau
#> [1] "coupes"
#> 
#> $concentrante$actions[[2]]$recolte
#> [1] TRUE
#> 
#> $concentrante$actions[[2]]$libelle
#> [1] "Etalement des recoltes dans le temps"
#> 
#> 
#> $concentrante$actions[[3]]
#> $concentrante$actions[[3]]$id
#> [1] "note_arbitrage_exposition"
#> 
#> $concentrante$actions[[3]]$tableau
#> [1] "aucun"
#> 
#> $concentrante$actions[[3]]$recolte
#> [1] FALSE
#> 
#> $concentrante$actions[[3]]$libelle
#> [1] "Note d'arbitrage : UGF concentrante d'un alea en depassement"
#> 
#> 
#> 
#> 
#> $regles_alea
#> $regles_alea$tempete
#> $regles_alea$tempete$id
#> [1] "A_tempete"
#> 
#> $regles_alea$tempete$actions
#> $regles_alea$tempete$actions[[1]]
#> $regles_alea$tempete$actions[[1]]$id
#> [1] "eclaircie_precoce_rapport_hd"
#> 
#> $regles_alea$tempete$actions[[1]]$tableau
#> [1] "coupes"
#> 
#> $regles_alea$tempete$actions[[1]]$recolte
#> [1] TRUE
#> 
#> $regles_alea$tempete$actions[[1]]$libelle
#> [1] "Eclaircies precoces pour abaisser le rapport H/D"
#> 
#> 
#> $regles_alea$tempete$actions[[2]]
#> $regles_alea$tempete$actions[[2]]$id
#> [1] "traitement_lisieres"
#> 
#> $regles_alea$tempete$actions[[2]]$tableau
#> [1] "travaux"
#> 
#> $regles_alea$tempete$actions[[2]]$recolte
#> [1] FALSE
#> 
#> $regles_alea$tempete$actions[[2]]$libelle
#> [1] "Traitement des lisieres"
#> 
#> 
#> $regles_alea$tempete$actions[[3]]
#> $regles_alea$tempete$actions[[3]]$id
#> [1] "recolte_anticipee_peuplements_hauts"
#> 
#> $regles_alea$tempete$actions[[3]]$tableau
#> [1] "coupes"
#> 
#> $regles_alea$tempete$actions[[3]]$recolte
#> [1] TRUE
#> 
#> $regles_alea$tempete$actions[[3]]$libelle
#> [1] "Recolte anticipee des peuplements hauts et instables"
#> 
#> 
#> 
#> 
#> $regles_alea$secheresse_sanitaire
#> $regles_alea$secheresse_sanitaire$id
#> [1] "A_secheresse"
#> 
#> $regles_alea$secheresse_sanitaire$actions
#> $regles_alea$secheresse_sanitaire$actions[[1]]
#> $regles_alea$secheresse_sanitaire$actions[[1]]$id
#> [1] "diversification_essences"
#> 
#> $regles_alea$secheresse_sanitaire$actions[[1]]$tableau
#> [1] "travaux"
#> 
#> $regles_alea$secheresse_sanitaire$actions[[1]]$recolte
#> [1] FALSE
#> 
#> $regles_alea$secheresse_sanitaire$actions[[1]]$libelle
#> [1] "Diversification des essences"
#> 
#> 
#> $regles_alea$secheresse_sanitaire$actions[[2]]
#> $regles_alea$secheresse_sanitaire$actions[[2]]$id
#> [1] "recolte_sanitaire"
#> 
#> $regles_alea$secheresse_sanitaire$actions[[2]]$tableau
#> [1] "coupes"
#> 
#> $regles_alea$secheresse_sanitaire$actions[[2]]$recolte
#> [1] TRUE
#> 
#> $regles_alea$secheresse_sanitaire$actions[[2]]$libelle
#> [1] "Recolte sanitaire"
#> 
#> 
#> $regles_alea$secheresse_sanitaire$actions[[3]]
#> $regles_alea$secheresse_sanitaire$actions[[3]]$id
#> [1] "suivi_sanitaire_spec008"
#> 
#> $regles_alea$secheresse_sanitaire$actions[[3]]$tableau
#> [1] "travaux"
#> 
#> $regles_alea$secheresse_sanitaire$actions[[3]]$recolte
#> [1] FALSE
#> 
#> $regles_alea$secheresse_sanitaire$actions[[3]]$libelle
#> [1] "Suivi sanitaire (spec 008)"
#> 
#> 
#> $regles_alea$secheresse_sanitaire$actions[[4]]
#> $regles_alea$secheresse_sanitaire$actions[[4]]$id
#> [1] "adaptation_densite"
#> 
#> $regles_alea$secheresse_sanitaire$actions[[4]]$tableau
#> [1] "coupes"
#> 
#> $regles_alea$secheresse_sanitaire$actions[[4]]$recolte
#> [1] TRUE
#> 
#> $regles_alea$secheresse_sanitaire$actions[[4]]$libelle
#> [1] "Adaptation de la densite"
#> 
#> 
#> 
#> 
#> $regles_alea$incendie
#> $regles_alea$incendie$id
#> [1] "A_incendie"
#> 
#> $regles_alea$incendie$actions
#> $regles_alea$incendie$actions[[1]]
#> $regles_alea$incendie$actions[[1]]$id
#> [1] "travaux_defense_incendie"
#> 
#> $regles_alea$incendie$actions[[1]]$tableau
#> [1] "travaux"
#> 
#> $regles_alea$incendie$actions[[1]]$recolte
#> [1] FALSE
#> 
#> $regles_alea$incendie$actions[[1]]$libelle
#> [1] "Travaux de defense contre l'incendie"
#> 
#> 
#> $regles_alea$incendie$actions[[2]]
#> $regles_alea$incendie$actions[[2]]$id
#> [1] "entretien_acces_coupures"
#> 
#> $regles_alea$incendie$actions[[2]]$tableau
#> [1] "travaux"
#> 
#> $regles_alea$incendie$actions[[2]]$recolte
#> [1] FALSE
#> 
#> $regles_alea$incendie$actions[[2]]$libelle
#> [1] "Entretien des acces et des coupures"
#> 
#> 
#> 
#> 
#> $regles_alea$abroutissement
#> $regles_alea$abroutissement$id
#> [1] "A_abroutissement"
#> 
#> $regles_alea$abroutissement$actions
#> $regles_alea$abroutissement$actions[[1]]
#> $regles_alea$abroutissement$actions[[1]]$id
#> [1] "protections_plants"
#> 
#> $regles_alea$abroutissement$actions[[1]]$tableau
#> [1] "travaux"
#> 
#> $regles_alea$abroutissement$actions[[1]]$recolte
#> [1] FALSE
#> 
#> $regles_alea$abroutissement$actions[[1]]$libelle
#> [1] "Protections contre l'abroutissement"
#> 
#> 
#> $regles_alea$abroutissement$actions[[2]]
#> $regles_alea$abroutissement$actions[[2]]$id
#> [1] "suivi_regeneration"
#> 
#> $regles_alea$abroutissement$actions[[2]]$tableau
#> [1] "travaux"
#> 
#> $regles_alea$abroutissement$actions[[2]]$recolte
#> [1] FALSE
#> 
#> $regles_alea$abroutissement$actions[[2]]$libelle
#> [1] "Suivi de la regeneration"
#> 
#> 
#> $regles_alea$abroutissement$actions[[3]]
#> $regles_alea$abroutissement$actions[[3]]$id
#> [1] "concertation_plan_chasse"
#> 
#> $regles_alea$abroutissement$actions[[3]]$tableau
#> [1] "aucun"
#> 
#> $regles_alea$abroutissement$actions[[3]]$recolte
#> [1] FALSE
#> 
#> $regles_alea$abroutissement$actions[[3]]$libelle
#> [1] "Concertation sur le plan de chasse (profil chasseur)"
#> 
#> 
#> 
#> 
#> 
#> $options
#> $options$declencheurs
#> $options$declencheurs$decisions
#> [1] "recolter"   "surveiller"
#> 
#> $options$declencheurs$alea
#> [1] TRUE
#> 
#> $options$declencheurs$concentrante
#> [1] TRUE
#> 
#> 
#> $options$conserver
#> $options$conserver$libelle
#> [1] "Conserver : aucune intervention motivee par P4"
#> 
#> $options$conserver$tableau
#> [1] "aucun"
#> 
#> $options$conserver$recolte
#> [1] FALSE
#> 
#> $options$conserver$entrees
#> $options$conserver$entrees$delta_score_alea_dominant
#> [1] 0
#> 
#> $options$conserver$entrees$prelevement_capital
#> [1] 0
#> 
#> $options$conserver$entrees$facteur_gain
#> [1] 1
#> 
#> 
#> $options$conserver$effets
#> $options$conserver$effets$P
#> [1] "0"
#> 
#> $options$conserver$effets$C
#> [1] "0"
#> 
#> $options$conserver$effets$B
#> [1] "0"
#> 
#> $options$conserver$effets$W
#> [1] "0"
#> 
#> $options$conserver$effets$A
#> [1] "0"
#> 
#> $options$conserver$effets$F
#> [1] "0"
#> 
#> $options$conserver$effets$L
#> [1] "0"
#> 
#> $options$conserver$effets$T
#> [1] "0"
#> 
#> $options$conserver$effets$R
#> [1] "0"
#> 
#> $options$conserver$effets$S
#> [1] "0"
#> 
#> $options$conserver$effets$E
#> [1] "0"
#> 
#> $options$conserver$effets$N
#> [1] "0"
#> 
#> 
#> 
#> $options$intervenir
#> $options$intervenir$libelle
#> [1] "Intervenir : prelevement leger cible et travaux de reduction du risque"
#> 
#> $options$intervenir$tableau
#> [1] "coupes"
#> 
#> $options$intervenir$recolte
#> [1] TRUE
#> 
#> $options$intervenir$entrees
#> $options$intervenir$entrees$delta_score_alea_dominant
#> [1] 10
#> 
#> $options$intervenir$entrees$prelevement_capital
#> [1] 0.1
#> 
#> $options$intervenir$entrees$facteur_gain
#> [1] 0.97
#> 
#> 
#> $options$intervenir$sans_recolte
#> $options$intervenir$sans_recolte$libelle
#> [1] "Intervenir sans recolte : travaux de reduction du risque"
#> 
#> $options$intervenir$sans_recolte$tableau
#> [1] "travaux"
#> 
#> $options$intervenir$sans_recolte$entrees
#> $options$intervenir$sans_recolte$entrees$delta_score_alea_dominant
#> [1] 10
#> 
#> $options$intervenir$sans_recolte$entrees$prelevement_capital
#> [1] 0
#> 
#> $options$intervenir$sans_recolte$entrees$facteur_gain
#> [1] 1
#> 
#> 
#> 
#> $options$intervenir$effets
#> $options$intervenir$effets$P
#> [1] "+"
#> 
#> $options$intervenir$effets$C
#> [1] "-"
#> 
#> $options$intervenir$effets$B
#> [1] "0"
#> 
#> $options$intervenir$effets$W
#> [1] "0"
#> 
#> $options$intervenir$effets$A
#> [1] "0"
#> 
#> $options$intervenir$effets$F
#> [1] "0"
#> 
#> $options$intervenir$effets$L
#> [1] "0"
#> 
#> $options$intervenir$effets$T
#> [1] "0"
#> 
#> $options$intervenir$effets$R
#> [1] "+"
#> 
#> $options$intervenir$effets$S
#> [1] "0"
#> 
#> $options$intervenir$effets$E
#> [1] "+"
#> 
#> $options$intervenir$effets$N
#> [1] "-"
#> 
#> 
#> 
#> $options$convertir
#> $options$convertir$libelle
#> [1] "Convertir : diversification ou conversion des essences"
#> 
#> $options$convertir$tableau
#> [1] "travaux"
#> 
#> $options$convertir$recolte
#> [1] FALSE
#> 
#> $options$convertir$entrees
#> $options$convertir$entrees$delta_score_alea_dominant
#> [1] 25
#> 
#> $options$convertir$entrees$prelevement_capital
#> [1] 0
#> 
#> $options$convertir$entrees$facteur_gain
#> [1] 0.92
#> 
#> 
#> $options$convertir$effets
#> $options$convertir$effets$P
#> [1] "-"
#> 
#> $options$convertir$effets$C
#> [1] "0"
#> 
#> $options$convertir$effets$B
#> [1] "+"
#> 
#> $options$convertir$effets$W
#> [1] "0"
#> 
#> $options$convertir$effets$A
#> [1] "0"
#> 
#> $options$convertir$effets$F
#> [1] "0"
#> 
#> $options$convertir$effets$L
#> [1] "0"
#> 
#> $options$convertir$effets$T
#> [1] "0"
#> 
#> $options$convertir$effets$R
#> [1] "+"
#> 
#> $options$convertir$effets$S
#> [1] "0"
#> 
#> $options$convertir$effets$E
#> [1] "0"
#> 
#> $options$convertir$effets$N
#> [1] "+"
#> 
#> 
#> 
#> 
```
