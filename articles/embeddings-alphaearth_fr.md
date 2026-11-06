# Embeddings AlphaEarth : N5, B4/L3 en mode embedding, hauteur de NDP 0

> Spec 064, chantier A. Fonctions **expérimentales** : elles peuvent
> changer à toute version. Voir aussi la fiche [Modèles de
> fondation](https://pobsteta.github.io/nemeton/articles/fiche-modeles-de-fondation_fr.md).

## 1. Ce que l’on obtient

AlphaEarth Foundations (Google DeepMind) publie chaque année depuis 2017
un **vecteur de 64 dimensions par pixel de 10 m**, appris sur
Sentinel-1, Sentinel-2, Landsat, GEDI et ERA5. Le cœur `nemeton` ne
télécharge rien : le paquet amont `alphaearthnemeton` (GPL-3) rapatrie
les embeddings, le cœur les lit comme un raster de 64 bandes. Trois
usages :

| Usage | Fonction | Ce que l’embedding apporte |
|----|----|----|
| **N5**, distance à une forêt de référence | [`indicateur_n5_distance_reference()`](https://pobsteta.github.io/nemeton/reference/indicateur_n5_distance_reference.md) | une naturalité *fonctionnelle*, à côté de N1-N3 qui sont administratives |
| **B4 / L3** comparables entre projets | `indicateur_b4_div_spectrale(embedding =)`, `indicateur_l3_het_spectrale(embedding =)` | un dictionnaire de clusters fixe et une grille fixe |
| **Hauteur de NDP 0** | [`embedding_regress()`](https://pobsteta.github.io/nemeton/reference/embedding_regress.md) | une hauteur prédite quand il n’y a ni CHM ni LiDAR |

## 2. Récupérer les embeddings

``` r

# remotes::install_github("pobsteta/alphaearthnemeton")
library(nemeton)
library(alphaearthnemeton)

data(massif_demo_units)          # ou les UGF de votre projet (sf)
ugf <- massif_demo_units

emb <- aef_fetch(ugf, years = 2023:2024)   # liste nommée par année
emb[["2024"]]                              # SpatRaster de 64 bandes A00..A63
aef_info()$attribution                     # attribution CC-BY 4.0 obligatoire
```

`aef_fetch()` interroge l’index des tuiles sur l’emprise, lit seulement
les fenêtres utiles des COG publics (sans Python ni compte Earth
Engine), reprojette en Lambert-93 au plus proche voisin sur une grille
de 10 m et met le résultat en cache. Mesure du 2026-11-05 près de Dabo :
2 × 2 km, deux années, 52 s ; 4 s au second appel.

## 3. N5, distance à la référence

``` r

# Référence par défaut : UGF couvertes par le palier le plus ancien de la
# forêt ancienne ET N1 >= 80. N1 doit donc être calculé avant.
ugf <- indicateur_n1_distance(ugf, roads = routes, buildings = bati)
res <- indicateur_n5_distance_reference(ugf, emb, foret_ancienne = fa)

# Ou une référence à vous : réserves intégrales, îlots de sénescence...
res <- indicateur_n5_distance_reference(ugf, emb, reference = reserves)
table(res$n5_status)
```

`N5 = 100` : l’UGF est indiscernable de la référence ; `N5 = 0` : elle
en est plus loin que toute unité de la référence. Il faut au moins 15
unités de référence (`skipped_reference_too_small` sinon). Lire la fiche
N5 avant d’interpréter : la référence n’est pas un tirage aléatoire, et
la référence par défaut est choisie par N1 et N2.

## 4. B4 et L3 en mode embedding

``` r

b4 <- indicateur_b4_div_spectrale(ugf, embedding = emb)
l3 <- indicateur_l3_het_spectrale(ugf, embedding = emb)
table(b4$b4_methode, b4$b4_status)

# La normalisation lit le statut : le mode embedding a ses propres bornes.
normalize_indicator("B4", b4$B4, statut = b4$b4_status)
```

Une même parcelle obtient la même valeur dans tous les projets : le
dictionnaire de 32 clusters
([`aef_clusters()`](https://pobsteta.github.io/nemeton/reference/aef_clusters.md))
et la grille de fenêtres de 100 m sont fixes. Pour B4, chaque pixel est
réparti entre les clusters (affectation souple) et la diversité d’une
fenêtre est la divergence de Jensen-Shannon des appartenances. Stabilité
entre 2023 et 2024 près de Dabo, 16 UGF de 500 m : écart médian 0,7
point, maximum 2,2 (B4) ; écart médian 1,2 point, maximum 2,9 (L3).

## 5. Une hauteur de NDP 0

``` r

plac <- placettes_ifn_du_projet          # sf de points avec une colonne H0
m <- embedding_regress(plac, emb, target = "H0")
m                                         # RMSE, R2 et biais hors pli

# La prédiction remplace un CHM pour les indicateurs qui lisent un niveau
p2 <- indicateur_p2_station(ugf, chm = m$prediction)
```

La validation croisée est faite par **blocs spatiaux de 5 km** : une
placette et ses voisines tombent dans le même pli, ce qui évite un score
flatteur. Le RMSE hors pli est l’erreur à citer avec toute valeur
dérivée. En dessous de 30 placettes, aucun modèle n’est ajusté
(`train_too_small`). **Ne pas l’utiliser pour B2** : la composante
structurelle de B2 est le coefficient de variation du CHM, et celui
d’une hauteur prédite mesure le modèle, pas le peuplement.

## 6. NDP

``` r

attr(ugf, "embedding_source") <- "aef"
detect_ndp(ugf)$augmented    # "embedding_ml" ; le niveau NDP ne change pas
```

## 7. Ce qui n’est pas encore validé

- N5 sur le vrai parcellaire de Dabo et sur un projet hors de France.
- [`embedding_regress()`](https://pobsteta.github.io/nemeton/reference/embedding_regress.md)
  sur de vraies placettes IFN.
- La température de l’affectation souple (τ = 0,1) et les bornes de B4
  ont été choisies sur un seul site.
