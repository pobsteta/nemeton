# Fiche indicateur A4 - Tamponnement de la canopee

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** à la chaîne microclimat (spec 027,
> ADR-014).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `A4` |
| Nom long / colonne | `indicateur_a4_tamponnement` |
| Famille | **A — Air & Microclimat** |
| Grandeur mesurée | **ΔT** entre l’air libre et le sous-couvert : ce que la canopée amortit |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable (plus la canopée tamponne, mieux c’est) |
| Normalisation | **native 0–100**, écrêtage |
| Bornes | `.MICRO_BOUNDS$a4 = c(lo = 0, hi = 10)` °C, **croissant** |
| Fonction | [`indicateur_a4_tamponnement()`](https://pobsteta.github.io/nemeton/reference/indicateur_a4_tamponnement.md) — `R/indicators-microclimate.R:149` |
| Drapeau NDP | `microclimate_model` |

## 2. Le calcul

    A4_delta = moyenne zonale du tamponnement (T_air_libre - T_sous_couvert)   °C
    A4       = 100 x delta / 10                                                 ecrete [0, 100]

**A3 et A4 sont complémentaires, pas redondants** : A3 dit *quelle
température il fait sous le couvert*, A4 dit *combien la canopée en a
retiré*. Un peuplement de fond de vallon peut être frais (A3 élevé) sans
tamponner beaucoup (A4 modeste) — c’est la topographie qui fait le
travail, pas les arbres.

**Exemples chiffrés** :

| Situation                              | ΔT     | A4       |
|----------------------------------------|--------|----------|
| Canopée fermée, forte surface foliaire | 7,5 °C | **75,0** |
| Futaie ordinaire                       | 4,5 °C | **45,0** |
| Peuplement clair                       | 2,0 °C | **20,0** |
| Coupe rase, régénération basse         | 0,3 °C | **3,0**  |

## 3. Le calcul par niveau NDP

Identique à A3 : `NA` sans chaîne microclimat ; calculé dès qu’un
[`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
a tourné ; structure de canopée mieux décrite aux NDP 1 et 2. Le drapeau
`microclimate_model` ne relève pas le niveau.

> **A4 est celui des quatre indicateurs microclimatiques qui dépend le
> plus de la qualité du CHM** : le tamponnement est directement fonction
> de la structure et de la densité du couvert. Passer d’un CHM ML (NDP 0
> augmenté) à un MNH LiDAR HD (NDP 1) change davantage A4 que A3.

## 4. Deux pièges

1.  **Le plafond de 10 °C n’est pas atteint en France.** Les valeurs
    mesurées sous couvert tempéré plafonnent typiquement vers 5–8 °C.
    L’échelle est donc utilisée sur sa moitié basse, et un A4 de 45
    n’est pas « médiocre » : c’est un tamponnement ordinaire de futaie.
2.  **Une coupe rase donne A4 proche de 0, et c’est correct.**
    Contrairement à C1 où un couvert nul valait `NA` avant correctif, A4
    rend bien 0 : il n’y a pas de canopée, donc pas de tamponnement. Ne
    pas y voir une donnée manquante.

## 5. Aval

    indicateur_a4_tamponnement()  ->  colonnes A4 et A4_delta (°C)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("A")  -> famille_air

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction A4 | `R/indicators-microclimate.R:149` |
| Bornes | `.MICRO_BOUNDS` |
| Indicateur jumeau | [`vignette("fiche-a3-microclimat_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-a3-microclimat_fr.md) |
