# Numéros de tarif Schaeffer par sylvoécorégion

Marculus cube les tiges au **tarif Schaeffer à une entrée** : le volume
ne dépend que du diamètre et d’un **numéro de tarif** N, propre au
peuplement. nemeton calcule ce numéro par essence depuis les arbres
cubés de l’Inventaire forestier national, pour chaque sylvoécorégion
(SER), chaque grande région écologique (GRECO) et la France. Spec 062.

> Le numéro est une **valeur par défaut** pour le marteleur, pas une
> prescription : il décrit les arbres que l’IFN a mesurés.

## Les quatre tarifs

Rapide (`SCHR`), intermédiaire (`SCHI`), lent (`SCHL`) et très lent
(`SCHTL`), avec la convention de Marculus `M = 0,8 + 0,1 N` :

``` r

volume_tarif_schaeffer(10, 40, c("SCHR", "SCHI", "SCHL", "SCHTL"))
#> [1] 1.350000 1.371094 1.400000 1.422222
numero_tarif_schaeffer(1.2, 40, "SCHL")
#> [1] 7.428571
```

## Méthode

Reprise de `PPtools::TarifFindSch()` de Max Bruciamacchie (GPL-2,
reprise sous GPL-3 avec son autorisation) : arbres vifs cubés des 15
dernières campagnes, circonférence d’au moins 50 cm, diamètre entre 17,5
et 80 cm ; numéro de chaque arbre, puis **moyenne pondérée par le
volume** et coefficient de variation par groupe (essence retenue dès 3
arbres). Le type conseillé est celui dont le CV est le plus faible.

## Table de référence et cascade

``` r

ifn_tarif_schaeffer_reference(c("Chêne sessile", "Hêtre"), ser = "C20", type = "SCHL")
#>   espar essence_libelle type numero   cv n_arbres niveau_utilise code
#> 1    03   Chêne sessile SCHL    7.8 40.1     8746            SER  C20
#> 2    09           Hêtre SCHL    8.5 38.7     7056            SER  C20
#>   type_conseille
#> 1           SCHI
#> 2           SCHL
```

La cascade descend SER → GRECO → France jusqu’au premier échelon qui
compte au moins 30 arbres de l’essence. La commune donne sa ou ses SER :

``` r

communes_ser("21295")
#>   insee               nom departement ser   part greco
#> 1 21295 Gevrey-Chambertin          21 C20 0.5563     C
#> 2 21295 Gevrey-Chambertin          21 C51 0.4437     C
```

## À l’échelle d’une forêt

[`tarif_schaeffer_local()`](https://pobsteta.github.io/nemeton/reference/tarif_schaeffer_local.md)
reprend le calcul sur les placettes IFN de la forêt, élargie à environ 2
000 ha (`PPtools::ExtractPlac()`). Il n’y en a qu’une dizaine par 2 000
ha de forêt, placées au centre de leur maille kilométrique : le niveau «
forêt » exige 30 arbres sur 5 placettes, sinon la SER majoritaire prend
le relais.

## Pour Marculus

``` r

exporter_tarifs_marculus("tarifs-ifn")
```

écrit `ifn_tarif_schaeffer_ser.csv`, `communes_ser.csv`, `ser.csv` et un
`LISEZMOI.txt` (millésime, citations). Ces tables sont reconstruites une
fois par millésime IFN par `data-raw/build_ifn_tarifs_schaeffer.R`.

Données : IGN, Inventaire forestier national, données brutes, Licence
Ouverte Etalab 2.0. Contours communaux : Etalab, dérivé d’ADMIN EXPRESS.
