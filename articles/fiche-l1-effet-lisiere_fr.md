# Fiche indicateur L1 - Effet de lisiere

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> **Cette fiche documente une incohérence de sens active** (§4, piège
> n° 1) : le calcul, l’infobulle et N3 lisent L1 « haut = beaucoup de
> lisière = défavorable », la normalisation le lit « haut = favorable ».

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `L1` |
| Nom long / colonne | `indicateur_l1_effet_lisiere` |
| Famille | **L — Paysage** (avec L2, L3) |
| Grandeur mesurée | Intensité de l’effet de lisière subi par l’unité |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_l1_effet_lisiere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_effet_lisiere.md) — `R/indicators-families.R:1682` |
| Ancien nom | [`indicateur_l1_sylvosphere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_sylvosphere.md) — conservé en alias (spec 045) |

## 2. Le calcul — trois composantes pondérées

    L1 = 0,30 x geometrie + 0,40 x contraste_matrice + 0,30 x exposition

### Géométrie (30 %)

    SI = perimetre / (2 x racine(pi x aire))     indice de forme, 1 = disque parfait
    composante = min(100, (SI - 1) x 25)

Une parcelle compacte a un SI proche de 1 et une composante proche de 0
; une lanière étroite monte vite.

### Contraste de matrice (40 %)

Table de contraste OSO, appliquée aux pixels voisins :

| Occupation            | Contraste |
|-----------------------|-----------|
| Forêt (16, 17, 18)    | 0         |
| Landes (19)           | 15        |
| Prairies (20)         | 20        |
| Eau (30)              | 30        |
| Vignes (24)           | 45        |
| Cultures (21, 22, 23) | 50        |
| Routes (29)           | 75        |
| Bâti (25–28)          | 90        |

**Sans couche d’occupation du sol, cette composante vaut 50** pour
toutes les unités — soit 40 % du score figé sur une constante (cf. §4).

### Exposition (30 %)

`0,6 × score_vent + 0,4 × score_ensoleillement`, calculés sur le relief.
Repli à **50** en l’absence des entrées nécessaires.

## 3. Le calcul par niveau NDP

| NDP   | Ce qui change                                                     |
|-------|-------------------------------------------------------------------|
| **0** | OSO 30 m + MNT 25 m — les trois composantes sont calculables      |
| **1** | MNT LiDAR HD : l’exposition (vent, soleil) gagne en finesse       |
| **2** | ortho drone : le contraste de matrice devient réel, haie par haie |
| **3** | relevé terrain de la lisière                                      |
| **4** | —                                                                 |

## 4. Quatre pièges, dont une incohérence de sens

1.  **Le sens de L1 n’est pas le même selon qui le lit.**

    Le **calcul** produit un score qui monte avec l’influence des
    lisières : la composante géométrie vaut `(SI − 1) × 25`, donc 0 pour
    une parcelle compacte et beaucoup pour une lanière ; la composante
    contraste vaut 0 face à de la forêt et 90 face à du bâti. **Un L1
    élevé signifie donc : forme découpée, matrice contrastée, forte
    exposition** — c’est-à-dire un habitat intérieur fragmenté.

    L’**infobulle** dit la même chose : « Proportion de la parcelle sous
    influence des lisières (sylvosphère). Les lisières favorisent
    certaines espèces mais **fragmentent l’habitat intérieur**. »

    **N3** aussi : il calcule `anti_frag = 100 − L1` avant de l’ajouter
    positivement à la naturalité.

    Mais `indicateur_l1_effet_lisiere` figure dans
    `.NORMALIZE_NATIVE_0_100` (`R/normalization.R:521`), et aucune
    branche d’inversion ne le rattrape. La normalisation le laisse donc
    **passer tel quel, comme un score où haut = bon**.

    > **Conséquence** : une parcelle en lanière bordée de bâti obtient
    > un L1 élevé, que le **radar affiche comme un bon score de
    > paysage** et qui tire `famille_paysage` vers le haut — alors que
    > le même chiffre, injecté dans N3, la pénalise. Trois sources sur
    > quatre disent « haut = mauvais », la quatrième décide de
    > l’affichage.

    C’est exactement le défaut corrigé pour **R5** en 0.181.0 (spec 048
    : « seul R5 était inversé \[…\] une UGF très exposée obtenait un
    `famille_risque` élevé, c’est-à-dire flatteur ») et pour les
    **noms** de la famille L en 0.176.0 (spec 045 : « les deux noms
    historiques annonçaient l’inverse de ce qu’ils calculaient »). Le
    sens de L1, lui, n’a pas été revu.

    **Le correctif serait d’un mot** : retirer
    `indicateur_l1_effet_lisiere` (et son alias
    `indicateur_l1_sylvosphere`) de `.NORMALIZE_NATIVE_0_100`, et
    l’ajouter au bloc d’inversion aux côtés de R1–R5 et T3. Comme pour
    la spec 048, aucune fonction d’indicateur ne changerait — seule la
    valeur normalisée basculerait, et tout `famille_paysage` déjà
    calculé serait à refaire.

2.  **Deux composantes sur trois retombent sur 50 en l’absence de
    données**, sans avertissement — le contraste (40 %) et l’exposition
    (30 %). Sans occupation du sol ni relief exploitable, **70 % de L1
    est une constante** et le score se réduit à `35 + 0,3 × géométrie`.
    C’est le même motif que B3 : un score d’apparence mesurée dont la
    majeure partie est fabriquée. Vérifier qu’une couche `landcover` est
    bien chargée avant de lire L1.

3.  **La géométrie mesure la forme de l’UGF, pas celle du massif.** Un
    découpage cadastral en lanières produit des SI élevés sans qu’aucune
    lisière écologique n’existe : deux parcelles voisines au cœur d’un
    même massif continu peuvent obtenir des scores très différents pour
    une raison purement administrative.

4.  **Le nom a changé, l’ancien reste accepté.**
    [`indicateur_l1_sylvosphere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_sylvosphere.md)
    est conservé comme alias (spec 045) et les slugs
    `indicateur_l1_sylvosphere` restent reconnus par la normalisation
    pour les jeux non migrés. Les deux noms historiques de la famille L
    « annonçaient l’inverse de ce qu’ils calculaient » — d’où le
    renommage.

## 5. Aval

    indicateur_l1_effet_lisiere()  ->  colonne indicateur_l1_effet_lisiere
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("L")  -> famille_paysage = moy(L1, L2, L3)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction L1 | `R/indicators-families.R:1682-1860` |
| Alias historique | [`indicateur_l1_sylvosphere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_sylvosphere.md) — `:1992` |
| Renommage de la famille | `specs/045-renommage-famille-L/`, [`migrer_colonnes_l()`](https://pobsteta.github.io/nemeton/reference/migrer_colonnes_l.md) |
