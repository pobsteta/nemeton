# Fiche indicateur S3 - Population accessible

> **Document de référence** — Néméton (package cœur), 2026-08-27. Deux
> correctifs importants sont documentés ici (§4).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `S3` |
| Nom long / colonne | `indicateur_s3_population` |
| Famille | **S — Social & Usages** |
| Grandeur mesurée | **Densité de population** dans la couronne d’accessibilité |
| Unité brute | **hab/km²** |
| Sens | Haut = favorable |
| Normalisation | **logarithmique** : `100 × log10(1 + d) / log10(1001)` |
| Fonction | [`indicateur_s3_population()`](https://pobsteta.github.io/nemeton/reference/indicateur_s3_population.md) — `R/indicators-social.R:251` |
| Colonnes annexes | `S3_5km`, `S3_10km`, `S3_20km` |

## 2. Le calcul

La population est sommée dans des couronnes de 5, 10 et 20 km autour de
l’unité (grille de population INSEE ou équivalent), puis ramenée à une
densité.

    score = 100 x log10(1 + densite) / log10(1 + 1000)     plafond 1 000 hab/km2 = 100

**Pourquoi une échelle logarithmique** : la grandeur couvre trois ordres
de grandeur en France — 5 hab/km² dans un massif alpin isolé, 40–80 en
rural ordinaire, 300–1 000 en périurbain. Une échelle linéaire
écraserait tout le domaine forestier dans les premiers points.

| Densité         | Score     |
|-----------------|-----------|
| 10 hab/km²      | **33,3**  |
| 50 hab/km²      | **56,7**  |
| 100 hab/km²     | **66,7**  |
| 300 hab/km²     | **82,7**  |
| ≥ 1 000 hab/km² | **100,0** |

Au-delà de 300 hab/km², la forêt est périurbaine : que le chiffre exact
soit 400 ou 900 cesse d’être informatif, et la compression logarithmique
le reflète.

## 3. Le calcul par niveau NDP

| NDP     | Ce qui change                                   |
|---------|-------------------------------------------------|
| **0**   | grille de population INSEE (200 m ou 1 km)      |
| **1–2** | inchangé — la population n’est pas télédétectée |
| **3–4** | enquête de fréquentation                        |

## 4. Trois pièges, dont deux correctifs

1.  **Sans grille de population, S3 vaut `NA`** — et c’est un correctif.
    La méthode antérieure rendait `surface_du_tampon × 100 hab/km²`
    **sans jamais lire de grille** : un nombre qui variait avec la
    taille du tampon et ressemblait à une mesure. Elle a été retirée,
    avec un message explicite.
2.  **`ref_max` a disparu au profit de l’échelle log** — second
    correctif. L’ancien plafond de 10 000 bornait un **effectif brut**
    et saturait dès qu’une vraie source était branchée : mesuré sur
    Couchey, 46 110 habitants dans 5 km donnaient **100/100 pour une
    commune rurale de Bourgogne**. L’indicateur porte désormais une
    **densité**, pas un effectif.
3.  **Les trois colonnes de rayon ne sont pas agrégées dans la
    famille.** `S3_5km`, `S3_10km`, `S3_20km` sont des colonnes de
    diagnostic. Un motif `^S[0-9]` non ancré les avait un temps fait
    entrer dans `famille_social`, qui comptait alors **quatre fois la
    même population** — corrigé en ancrant le motif en fin de nom.

## 5. Aval

    indicateur_s3_population()  ->  colonnes S3 (hab/km2) + S3_5km / S3_10km / S3_20km
          |
          +- normalize_indicator()     -> echelle logarithmique
          +- create_family_index("S")  -> famille_social = moy(S1, S2, S3)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction S3 | `R/indicators-social.R:251-400` |
| Source population | [`load_insee_population_source()`](https://pobsteta.github.io/nemeton/reference/load_insee_population_source.md) — `R/load_insee_population.R`, spec 050 |
| Normalisation logarithmique | `R/normalization.R`, branche `indicateur_s3_population` |
| Correctif du motif de famille | `R/family-system.R`, stratégie 1 |
