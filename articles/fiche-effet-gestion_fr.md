# Fiche - Effets de la gestion

> **Document de référence** — Néméton (package cœur), 2026-11-06. Spec
> 068 (chantier D, étape 1). Fonction **expérimentale** : elle peut
> changer à toute version.

------------------------------------------------------------------------

## 1. Ce que fait `effet_gestion()`

Elle estime, sur les UGF du projet lui-même, ce que le type de gestion
déclaré a produit sur chaque famille (ou indicateur), comparé à un type
de référence, **à station comparable** : P2, altitude, pente et SER
servent de covariables. Elle ne simule rien ; elle lit ce que la gestion
passée a laissé dans les indicateurs, pour qu’une simulation (FINN,
étapes suivantes de la spec 068) puisse un jour y être confrontée.

``` r

e <- effet_gestion(units, traitement = "type_sylviculture",
                   reference = "futaie_reguliere")
e$resume   # un effet moyen par type et par famille, avec intervalle
e$unites   # l'effet estimé UGF par UGF
```

## 2. Le calcul

1.  **Contrastes.** Chaque type de gestion est comparé au type de
    référence (par défaut le plus fréquent).
2.  **Recouvrement.** Un score de propension (régression logistique sur
    les covariables) dit à quel point une UGF « aurait pu » recevoir
    l’autre gestion. Seules les UGF dont le score est dans la plage
    commune aux deux groupes, et entre 0,05 et 0,95, sont gardées. Si
    moins de 70 % des UGF sont dans ce support commun, ou si un type a
    moins de 10 UGF, la fonction **refuse** (`recouvrement_insuffisant`,
    `trop_peu_unites`) : les deux seuils sont des conventions (spec 068,
    D-4).
3.  **Effet moyen.** Estimateur doublement robuste (AIPW) : un modèle de
    la famille par groupe (forêts aléatoires *ranger*, sinon régression
    linéaire), corrigé par le score de propension ; intervalle à 90 %.
4.  **Effets par UGF.** Méta-apprenant X (par défaut) ou T (Künzel et
    al.
    2019. ; intervalles par bootstrap, indicatifs.

## 3. Sur données simulées

150 UGF, effet réel de **+8 points**, gestion fortement liée à la
station (les UGF fertiles sont plus souvent en irrégulier), 30 tirages :

| Estimation                    | Moyenne | Couverture de l’intervalle à 90 % |
|-------------------------------|---------|-----------------------------------|
| Différence brute des moyennes | 18,5    | —                                 |
| AIPW (`effet_moyen`)          | 7,1     | 93 %                              |

La différence brute mélange l’effet de la gestion et celui de la station
; l’ajustement en retire l’essentiel. Un petit biais vers le bas
subsiste avec les forêts aléatoires.

## 4. Pièges

1.  **Une association, pas une preuve.** L’effet n’est causal que si
    toutes les causes communes de la gestion et du résultat sont parmi
    les covariables. Un propriétaire qui met en irrégulier ses
    meilleures parcelles *et* les mieux desservies fausse l’estimation
    si la desserte n’est pas une covariable.
2.  **Déclaré n’est pas appliqué.** `type_sylviculture` dit ce qui est
    déclaré, pas ce qui a été fait, ni depuis quand.
3.  **Peu d’UGF, intervalles larges.** Avec dix UGF par type,
    l’intervalle l’emporte sur l’estimation : le lire avant le chiffre.
4.  **Les familles sont des indices.** Un écart de 8 points sur la
    famille B est un écart d’indice normalisé, pas d’espèces.

Les résultats entrent dans les perspectives IA comme **résultats du
projet**, cités comme tels, avec leur intervalle et leur statut ; jamais
quand le statut n’est pas `calcule`.

## 5. Références

Künzel S. R., Sekhon J. S., Bickel P. J., Yu B. (2019). *Metalearners
for estimating heterogeneous treatment effects using machine learning.*
PNAS 116(10), 4156-4165.

| Sujet         | Fichier                               |
|---------------|---------------------------------------|
| Fonction      | `R/effet_gestion.R`                   |
| Spécification | `specs/068-trajectoires-finn/spec.md` |
