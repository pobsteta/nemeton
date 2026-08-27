# Fiche indicateur L3 - Heterogeneite spectrale beta

> **Document de référence** — Néméton (package cœur), 2026-08-27. **Même
> interdit d’usage que B4** (§4) : écart n° 6 du `PLAN.md`.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `L3` |
| Nom long / colonne | `indicateur_l3_het_spectrale` |
| Famille | **L — Paysage** |
| Grandeur mesurée | Diversité spectrale **β** : hétérogénéité de la mosaïque paysagère |
| Unité brute | **dispersion multivariée**, sans unité, ≈ \[0 ; 0,5\] |
| Sens | Haut = favorable |
| Normalisation | `score = min(100, dispersion / 0,5 × 100)` |
| Fonction | [`indicateur_l3_het_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_l3_het_spectrale.md) — `R/spectral_diversity.R:367` |
| Plafond | `.L3_MAX_DISPERSION = 0.5` |
| Spécification | spec 028 |

## 2. Le calcul

biodivMapR ne rend **pas** un raster de dissimilarité scalaire : il rend
les **trois premiers axes d’une PCoA** de la dissimilarité de
Bray-Curtis entre fenêtres. La valeur reportée est donc la **dispersion
multivariée** de l’unité dans cet espace d’ordination — la distance
euclidienne moyenne des fenêtres de l’unité à son propre centroïde
(betadisper d’Anderson).

    L3 = distance moyenne des fenetres de l'unite a son centroide, en espace PCoA
         NA si moins de `min_windows` fenetres couvertes (defaut 3)
    score = min(100, L3 / 0,5 x 100)

Une unité spectralement uniforme tend vers 0 ; une unité chevauchant des
communautés spectrales contrastées monte.

> **Correctif 0.190.0 à connaître.** Avant, les trois axes étaient
> **simplement moyennés**, ce qui mesurait la **position** moyenne de
> l’unité dans l’espace d’ordination — une quantité centrée sur zéro par
> construction, et écrasée à 0 pour toutes les unités du côté négatif.
> Les L3 calculés avant cette version sont inexploitables.

**Exemples chiffrés** (jeu de référence : dispersions mesurées de 0,064
à 0,440) :

| Situation                               | Dispersion | Score    |
|-----------------------------------------|------------|----------|
| Unité spectralement uniforme            | 0,07       | **14,0** |
| Mosaïque modérée                        | 0,20       | **40,0** |
| Mosaïque contrastée                     | 0,38       | **76,0** |
| Maximum observé sur le jeu de référence | 0,44       | **88,0** |

## 3. Le calcul par niveau NDP

Identique à B4 : indicateur **NDP 0 par nature** (Sentinel-2),
**inchangé au NDP 1** (le LiDAR ne porte pas de signal spectral),
amélioré au NDP 2 par une ortho drone multispectrale.

## 4. L’interdit d’usage, et deux autres pièges

1.  **L3 ne se compare ni entre projets, ni dans le temps.** Comme B4,
    les « spectral species » sont un **k-means réajusté à chaque
    exécution** (spec 028 §10.6). S’y ajoute une raison propre à L3 : la
    PCoA est une ordination **relative au jeu de fenêtres traité**, donc
    ses axes changent d’un run à l’autre. **Ne jamais classer, moyenner
    ou suivre L3 entre projets.** C’est l’écart n° 6 du `PLAN.md`.
2.  **Le plafond de 0,5 est provisoire et sous-utilisé.** Bray-Curtis
    est nominalement borné par 1, mais une PCoA à 3 axes n’en restitue
    qu’une partie (qualité d’ajustement 0,56/0,62 sur le jeu de
    référence). Les dispersions mesurées plafonnent à 0,44 : **aucune
    unité du jeu de référence n’atteint 100**, et l’échelle est utilisée
    sur sa moitié basse.
3.  **`min_windows = 3` est un plancher mathématique, pas un réglage.**
    Une dispersion autour d’un centroïde n’a pas de sens en dessous de
    trois points ; les valeurs inférieures sont relevées à 3. Les
    petites unités sortent donc `NA`.

## 5. Aval

    indicateur_l3_het_spectrale()  ->  colonne L3 (dispersion)
          |
          +- normalize_indicator()     -> dispersion / 0,5 x 100
          +- create_family_index("L")  -> famille_paysage = moy(L1, L2, L3)

> L3 pesant un tiers de `famille_paysage`, l’interdit de comparaison
> **remonte à la famille**, exactement comme B4 pour
> `famille_biodiversite`.

L3 partage son objet `spectral` avec **B4** : appeler
[`compute_spectral_diversity()`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
une fois et le passer aux deux.

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction L3 | `R/spectral_diversity.R:367` |
| Plafond | `.L3_MAX_DISPERSION` — `R/spectral_diversity.R:~28` |
| Indicateur jumeau (α) | [`vignette("fiche-b4-diversite-spectrale_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-b4-diversite-spectrale_fr.md) |
| Spécification | `specs/028-diversite-spectrale/`, §10 |
| Écart ouvert vers l’app | `PLAN.md`, table des écarts, ligne 6 |
