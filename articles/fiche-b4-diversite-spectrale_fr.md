# Fiche indicateur B4 - Diversite spectrale alpha

> **Document de référence** — Néméton (package cœur), 2026-08-27. **Un
> interdit d’usage est attaché à cet indicateur** (§4). Il fait l’objet
> de l’écart n° 7 du `PLAN.md` vers l’application.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `B4` |
| Nom long / colonne | `indicateur_b4_div_spectrale` |
| Famille | **B — Biodiversité** |
| Grandeur mesurée | Diversité spectrale **α** : indice de Shannon des « spectral species » |
| Unité brute | **indice de Shannon**, sans unité, ≈ \[0 ; 2,5\] |
| Sens | Haut = favorable |
| Normalisation | `score = min(100, max(0, H / log(10) × 100))` — `R/normalization.R:707` |
| Fonction | [`indicateur_b4_div_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_b4_div_spectrale.md) — `R/spectral_diversity.R:312` |
| Spécification | spec 028 |

## 2. Le calcul

    1. biodivMapR classe les pixels Sentinel-2 en « spectral species » (k-means)
    2. Shannon H de leur distribution, par fenetre de 100 m
    3. B4 = moyenne des fenetres couvrant l'unite            .aggregate_diversity()
    4. score = H / log(10) x 100                             plafond = 10 especes equi-abondantes

Le plafond `.B4_MAX_SPECTRAL_SPECIES = 10` s’interprète sur le **nombre
effectif d’espèces spectrales**, `exp(H)` — la quantité qu’un forestier
peut se représenter : dix communautés spectrales distinguables dans un
hectare est un peuplement réellement hétérogène.

**Exemples chiffrés** (jeu de référence : meilleure fenêtre 11,7 espèces
effectives, unité typique 2,2) :

| Situation                         | `exp(H)` | H    | Score              |
|-----------------------------------|----------|------|--------------------|
| Futaie régulière monospécifique   | 1,6      | 0,47 | **20,4**           |
| Unité typique du jeu de référence | 2,2      | 0,79 | **34,3**           |
| Mosaïque feuillus/résineux        | 4,5      | 1,50 | **65,3**           |
| Meilleure fenêtre mesurée         | 11,7     | 2,46 | **100,0** (saturé) |

## 3. Le calcul par niveau NDP

| NDP | Ce qui change |
|----|----|
| **0** | Sentinel-2 10 m — le cas nominal, B4 est un indicateur NDP 0 par nature |
| **1** | **inchangé** : le LiDAR HD ne porte aucun signal spectral |
| **2** | ortho drone multispectrale : les espèces spectrales cessent de mélanger houppier et trouée |
| **3** | relevé floristique de validation — B4 reste un proxy, le relevé le calibre |
| **4** | scan spectral par houppier |

Comme C2, B4 ne progresse pas entre NDP 0 et NDP 1.

## 4. L’interdit d’usage, et deux autres pièges

1.  **B4 ne se compare ni entre projets, ni dans le temps — c’est un
    interdit, pas une réserve.** Les « spectral species » sont un
    **k-means réajusté à chaque exécution** sur la scène traitée (spec
    028 §10.6). La classe n° 3 d’un projet n’a aucun rapport avec la
    classe n° 3 d’un autre, et deux runs sur le même massif à deux dates
    produisent deux partitions différentes. **Ne jamais classer,
    moyenner ou suivre B4 entre projets.** L’indicateur répond à « cette
    unité est-elle plus hétérogène que sa voisine, dans ce run ? » —
    rien d’autre. C’est l’objet de l’écart n° 7 du `PLAN.md`.

2.  **Un peuplement monospécifique légitime obtient un score bas**, et
    ce n’est pas un défaut : une futaie régulière de hêtre *est*
    spectralement homogène. B4 mesure une hétérogénéité, qui n’est pas
    une valeur de gestion en soi. Le tooltip de l’application le dit ;
    une lecture « B4 bas = mauvaise sylviculture » est une erreur
    d’interprétation.

3.  **Le plafond de 10 espèces effectives est provisoire.** Il remplace
    le `log(nbclusters) = log(50)` de la spec 028 D3 et est calibré sur
    **un seul massif de référence**. Il est explicitement à revoir dès
    qu’un deuxième massif est mesuré. Un score de 100 signifie « au
    plafond du calibrage actuel », pas « diversité maximale ».

4.  **Sans entrée spectrale, B4 vaut `NA`** — pas 0. Ni `spectral` ni
    `reflectance` fournis : la colonne est remplie de `NA` sans erreur.

## 5. Aval

    indicateur_b4_div_spectrale()  ->  colonne B4 (Shannon)
          |
          +- normalize_indicator()     -> H / log(10) x 100
          +- create_family_index("B")  -> famille_biodiversite = moy(B1, B2, B3, B4)

> B4 pesant un quart de `famille_biodiversite`, l’interdit de
> comparaison **remonte à la famille** : un `famille_biodiversite` n’est
> pas plus comparable entre projets que le B4 qu’il contient.

Le calcul partage son objet `spectral` avec **L3** (diversité β) :
appeler
[`compute_spectral_diversity()`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
une fois et passer le résultat aux deux indicateurs, plutôt que de le
recalculer.

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction B4 | `R/spectral_diversity.R:312` |
| Plafond de normalisation | `.B4_MAX_SPECTRAL_SPECIES` — `R/spectral_diversity.R:23` |
| Règle de normalisation | `R/normalization.R:694-707` |
| Indicateur jumeau (β) | [`indicateur_l3_het_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_l3_het_spectrale.md) |
| Spécification | `specs/028-diversite-spectrale/` |
| Écart ouvert vers l’app | `PLAN.md`, table des écarts, ligne 7 |
