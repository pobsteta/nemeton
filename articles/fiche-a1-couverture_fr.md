# Fiche indicateur A1 - Couverture arboree

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `A1` |
| Nom long / colonne | `indicateur_a1_couverture` |
| Famille | **A — Air & Microclimat** (avec A2, A3, A4, A5) |
| Grandeur mesurée | Part boisée **dans un rayon autour de l’unité**, pas dans l’unité |
| Unité brute | **pourcentage 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_a1_couverture()`](https://pobsteta.github.io/nemeton/reference/indicateur_a1_couverture.md) — `R/indicators-air.R:75` |

## 2. Deux modes

| Mode | Déclencheur | Calcul |
|----|----|----|
| **FVC** | argument `fvc` (`SpatRaster`) | `moyenne(FVC sur le buffer) × 100` |
| **Occupation du sol** | défaut, `land_cover` obligatoire | `pixels forêt / pixels valides × 100` |

    buffer = st_buffer(unite, buffer_radius)         defaut 1 000 m
    A1     = part boisee dans ce buffer, en %

Classes forestières par défaut : `c(16, 17, 18)` — la nomenclature
**OSO** (feuillus, conifères, forêt mélangée). Un raster d’une autre
nomenclature exige de passer `forest_classes` explicitement, sans quoi
le compte est faux silencieusement.

**Exemples chiffrés** (rayon 1 km) :

| Contexte                             | A1       |
|--------------------------------------|----------|
| Parcelle au cœur d’un massif continu | **95,0** |
| Lisière de massif                    | **55,0** |
| Bosquet en plaine agricole           | **12,0** |
| Parcelle périurbaine isolée          | **6,0**  |

## 3. Le calcul par niveau NDP

| NDP | Source | Ce qui change |
|----|----|----|
| **0** | OSO 30 m | le cas nominal ; un bosquet de 20 m disparaît |
| **0 augmenté** | Theia `s2_biophysical` → **FVC** 10 m | grandeur continue au lieu d’une classe : les couverts partiels comptent |
| **1** | BD TOPO + OSO | contours de massif justes |
| **2** | ortho drone | le couvert réel, arbre par arbre |
| **3** | relevé terrain | — |
| **4** | ortho précision scanner | — |

> **Le mode FVC change la nature de la mesure.** En occupation du sol,
> un pixel est boisé ou ne l’est pas ; en FVC, il porte une **fraction
> de couvert végétal** continue. Une haie, une lisière progressive ou un
> peuplement clair valent 0,4 en FVC et « 0 ou 1 » en OSO. Les deux
> modes ne sont donc pas comparables entre eux, même sur la même
> parcelle.

## 4. Trois pièges

1.  **A1 ne décrit pas l’unité, mais son voisinage.** Le buffer de 1 km
    domine largement une parcelle forestière ordinaire (quelques
    hectares). Deux parcelles voisines ont donc des A1 presque
    identiques, quel que soit leur propre boisement. C’est voulu — A1
    mesure un **effet de contexte** sur le microclimat et la qualité de
    l’air — mais interdit de le lire comme « cette parcelle est boisée à
    X % ».
2.  **Le buffer n’est pas soustrait de l’unité.** Le calcul porte sur
    `st_buffer(unité)`, qui **contient** l’unité. Une parcelle boisée
    gonfle donc son propre score, d’autant plus qu’elle est grande par
    rapport au rayon.
3.  **Les classes 16/17/18 sont celles d’OSO, et rien ne le vérifie.**
    Passer un raster d’une autre nomenclature ne produit aucune erreur :
    simplement un comptage de pixels qui ne veut rien dire. Vérifier la
    légende avant.

## 5. Aval

    indicateur_a1_couverture()  ->  colonne A1 (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("A")  -> famille_air = moy(A1, A2, A3, A4, A5)

## 6. Références internes

| Sujet                    | Fichier                                       |
|--------------------------|-----------------------------------------------|
| Fonction A1              | `R/indicators-air.R:75-175`                   |
| Source FVC               | `inst/datasources/FR.json` — `s2_biophysical` |
| Source occupation du sol | `oso`                                         |
