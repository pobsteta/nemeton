# Fiche indicateur C2 - NDVI - Vitalite

> **Document de référence** — Néméton (package cœur), 2026-08-27. Fiche
> jumelle de celle de C1 : les deux composent à parts égales le score
> `famille_carbone`.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `C2` |
| Nom long / colonne | `indicateur_c2_ndvi` |
| Famille | **C — Carbone & Vitalité** (avec `C1` biomasse) |
| Grandeur mesurée | Vitalité photosynthétique de la végétation |
| Unité brute | **sans unité, \[0, 1\]** |
| Sens | Haut = favorable |
| Normalisation | `score = min(100, max(0, valeur × 100))` — `R/normalization.R:588` |
| Fonction | [`indicateur_c2_ndvi()`](https://pobsteta.github.io/nemeton/reference/indicateur_c2_ndvi.md) — `R/indicators-families.R` |

C2 est l’indicateur le plus simple des 41 : une **moyenne zonale** d’un
raster déjà calculé. Toute la difficulté est en amont, dans la façon
dont ce raster est produit — et c’est là que le NDP se joue.

## 2. Deux modes, pas une cascade

Contrairement à C1, C2 n’a pas de repli en cascade. Il a **deux modes
exclusifs**, choisis par la présence de l’argument `fapar` :

| Mode | Déclencheur | Grandeur rendue |
|----|----|----|
| **FAPAR** | argument `fapar` fourni (`SpatRaster`) | fraction du rayonnement photosynthétiquement actif absorbé |
| **NDVI** | défaut | `(NIR − Rouge) / (NIR + Rouge)` moyenné sur l’unité |

    C2 = moyenne zonale du raster sur l'unité      safe_extract(fun = "mean")

Les deux grandeurs vivent sur la même échelle `[0, 1]` et « haut = plus
de vitalité », si bien que la normalisation aval est **identique**.
C’est la raison assumée du choix de conception : le mode FAPAR remplace
la valeur sans rien changer en aval.

> **FAPAR est physiquement fondé, NDVI ne l’est pas.** Le NDVI est un
> rapport de réflectances ; FAPAR est une **variable biophysique
> restituée** (produit Theia `s2_biophysical`, chaîne SL2P). Sur couvert
> dense, le NDVI sature vers 0,85–0,9 quand FAPAR continue de
> discriminer. À NDP 0, brancher FAPAR est le gain le plus rentable sur
> C2 — sans changer une ligne d’aval.

## 3. Le calcul par niveau NDP

| NDP | Source du raster | Résolution | Ce qui change |
|----|----|----|----|
| **0** | Sentinel-2 (MUSCATE L2A, `s2_l2a_muscate`) → NDVI | 10 m | le cas de base |
| **0 augmenté** | Theia `s2_biophysical` → **FAPAR** | 10 m | grandeur physique, ne sature pas comme le NDVI |
| **1** | Sentinel-2 (idem) | 10 m | **inchangé** — le LiDAR HD n’apporte rien au signal spectral |
| **2** | ortho drone multispectrale | cm | vraie rupture : le NDVI cesse de mélanger houppier, trouée et sol |
| **3** | \+ notation de vigueur terrain | placette | validation, pas remplacement : C2 reste le raster |
| **4** | \+ scan spectral détaillé | arbre | signal par houppier |

**Le point à retenir** : entre NDP 0 et NDP 1, **C2 ne bouge pas**. Le
NDP mesure la qualité des données d’entrée (ADR-011), et pour C2 cette
qualité est gouvernée par le capteur spectral, que le LiDAR HD
n’améliore pas. Une hausse du NDP due au LiDAR augmente le **poids
Fibonacci** de la famille C sans que C2 ait gagné en précision — c’est
correct au sens de l’ADR (la famille dans son ensemble est mieux connue
via C1), mais il ne faut pas lire une amélioration de C2 là où il n’y en
a pas.

**Exemples chiffrés** :

| Situation                                | Valeur brute | Score normalisé |
|------------------------------------------|--------------|-----------------|
| Sol nu / coupe rase                      | 0,15         | 15,0            |
| Peuplement stressé, houppiers clairsemés | 0,45         | 45,0            |
| Futaie feuillue en pleine saison         | 0,72         | 72,0            |
| Couvert dense, NDVI saturé               | 0,88         | 88,0            |

La normalisation étant `× 100`, **la valeur brute et le score sont le
même nombre à un facteur 100 près**. C2 est le seul indicateur où lire
le score revient exactement à lire la mesure.

## 4. Trois pièges

1.  **`trend = TRUE` ne calcule rien.** L’argument existe, est
    documenté, et produit un
    `warning("NDVI trend calculation not yet implemented in v0.2.0 — returning single-date mean only")`
    puis **retourne la moyenne mono-date**. Ce n’est pas une erreur :
    c’est un no-op annoncé. Pour une vraie tendance temporelle, passer
    par
    [`extract_pixel_trend()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_trend.md)
    /
    [`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md),
    pas par C2.
2.  **C2 lève une erreur, il ne rend pas `NA`.** Si la couche `ndvi` est
    absente de l’objet `layers`, la fonction
    [`stop()`](https://rdrr.io/r/base/stop.html). C’est le seul
    comportement de ce type parmi les indicateurs de la famille C — C1,
    lui, rend `NA` avec un avertissement. Un pipeline qui calcule les 41
    indicateurs doit donc protéger l’appel de C2, ou garantir la couche.
3.  **La date compte, et n’est pas dans la valeur.** Un NDVI de juillet
    et un NDVI de mars sur le même peuplement diffèrent de 0,2 à 0,4. La
    colonne ne porte aucune trace de la date d’acquisition : c’est le
    raster fourni qui la détermine, en amont. Comparer deux projets
    suppose de comparer deux fenêtres phénologiques équivalentes.

## 5. Aval

    indicateur_c2_ndvi()  ->  colonne `indicateur_c2_ndvi` ([0, 1])
          |
          +- normalize_indicator()     -> C2_norm = min(100, valeur x 100)
          +- create_family_index("C")  -> famille_carbone = moyenne(C1_norm, C2_norm)
          +- compute_general_index()   -> axe C du radar, pondere Fibonacci

Poids par défaut : **50 / 50 avec C1**. Surchargeable par
`create_family_index(..., weights = list(C = c(C1 = 0.7, C2 = 0.3)))`.

> Conséquence directe : sur un projet où C1 sature (chemin CHM, cf. sa
> fiche), `famille_carbone` devient pour moitié un simple NDVI remis à
> l’échelle. Lire les deux colonnes brutes avant de conclure sur la
> famille.

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction C2 | `R/indicators-families.R` |
| Normalisation | `R/normalization.R:588` (branche `indicateur_c2_ndvi`) |
| Sources déclarées | `inst/datasources/FR.json` — `s2_l2a_muscate`, `s2_biophysical` |
| Tendance temporelle (le vrai outil) | [`extract_pixel_trend()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_trend.md), [`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md) |
| Fiche jumelle | [`vignette("fiche-c1-biomasse_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.md) |
