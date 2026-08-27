# Fiche indicateur W4 - Deficit de saturation sous couvert

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** : il n’existe que si la chaîne microclimat
> a tourné (spec 027, ADR-014).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `W4` |
| Nom long / colonne | `indicateur_w4_vpd` |
| Famille | **W — Eau & Régulation** |
| Grandeur mesurée | **VPD** — déficit de pression de vapeur sous couvert, en été |
| Unité brute | **score 0–100** (le VPD brut est en kPa, cf. colonne annexe) |
| Sens | Haut = favorable (**VPD bas = air humide = peu de stress**) |
| Normalisation | **native 0–100**, écrêtage (`.NORMALIZE_NATIVE_0_100`) |
| Fonction | [`indicateur_w4_vpd()`](https://pobsteta.github.io/nemeton/reference/indicateur_w4_vpd.md) — `R/indicators-microclimate.R:179` |
| Bornes | `.MICRO_BOUNDS$w4 = c(lo = 0,5 ; hi = 4,0)` kPa, **décroissant** |
| Colonne annexe | `W4_vpd` (kPa brut) |
| Drapeau NDP | `microclimate_model` |

## 2. Le calcul

W4 n’est pas calculé par Néméton : il **extrait** une couche produite
par le moteur microclimatique (`microclimf`, orchestré par
[`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)),
puis la normalise.

    W4_vpd = moyenne zonale du raster `vpd` sur l'unite      kPa
    W4     = 100 x (4,0 - VPD) / (4,0 - 0,5)                 ecrete [0, 100]

L’échelle est **décroissante** : 4,0 kPa → 0, 0,5 kPa → 100.

**Exemples chiffrés** :

| Situation                              | VPD (kPa) | W4       |
|----------------------------------------|-----------|----------|
| Sous couvert fermé, ambiance tamponnée | 0,8       | **91,4** |
| Futaie claire                          | 1,6       | **68,6** |
| Peuplement ouvert, journée chaude      | 2,8       | **34,3** |
| Trouée exposée, canicule               | 3,9       | **2,9**  |

## 3. Le calcul par niveau NDP

W4 ne suit pas l’échelle NDP habituelle : il est **conditionné à la
disponibilité d’un modèle**, pas à un capteur.

| NDP | Ce qui existe | W4 |
|----|----|----|
| **0** sans microclimat | rien | **`NA`** — l’indicateur n’est pas calculé |
| **0** + [`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md) | forçage ERA5-Land + CHM ML | **calculé**, drapeau `microclimate_model` |
| **1** | \+ structure LiDAR HD en entrée du modèle | même grandeur, canopée mieux décrite |
| **2** | \+ structure drone | idem, résolution supérieure |
| **3–4** | \+ capteurs in situ | validation du modèle, pas remplacement |

> **Le drapeau `microclimate_model` ne change pas le niveau NDP**
> (ADR-011 amendé) : un microclimat modélisé reste une modélisation. Il
> signale que la famille A et les indicateurs W4/R6 reposent sur une
> simulation, pas sur une mesure.

## 4. Trois pièges

1.  **`NA` est le cas nominal, pas une anomalie.** Sur un projet où la
    chaîne microclimat n’a pas tourné, W4 vaut `NA` pour toutes les
    unités et `famille_eau` se calcule sur W1–W3 seuls (`na.rm = TRUE`).
    Ce n’est pas un défaut à corriger.
2.  **Le sens est inversé par rapport à l’intuition.** Un VPD **élevé**
    est défavorable (air sec, forte demande évaporative), donc le score
    est décroissant. Lire `W4 = 90` comme « fort déficit de saturation »
    est un contresens : c’est l’inverse. La colonne annexe `W4_vpd`
    porte la grandeur physique, dans le bon sens.
3.  **Les bornes 0,5–4,0 kPa sont des bornes de modèle, pas de mesure.**
    Elles encadrent ce que `microclimf` produit sur un été français ;
    une station météo sous couvert pourrait sortir de la plage. Les deux
    extrêmes du score sont donc des plafonds de convention.

## 5. Aval

    indicateur_w4_vpd()  ->  colonnes W4 (0-100) et W4_vpd (kPa)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("W")  -> famille_eau = moy(W1, W2, W3, W4)

W4 partage son objet `micro` avec **A3** (T°max sous couvert), **A4**
(tamponnement) et **R6** (sensibilité) : un seul
[`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
alimente les quatre.

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction W4 | `R/indicators-microclimate.R:179` |
| Bornes | `.MICRO_BOUNDS` — `R/indicators-microclimate.R:21-26` |
| Orchestration | [`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md), [`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md) |
| Spécification | `specs/027-regeneration-microclimat/`, ADR-014 |
