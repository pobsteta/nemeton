# Fiche indicateur B1 - Protection reglementaire

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `B1` |
| Nom long / colonne | `indicateur_b1_protection` |
| Famille | **B — Biodiversité** (avec B2, B3, B4) |
| Grandeur mesurée | Couverture de l’unité par des statuts de protection, **pondérée par la force du statut** |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, simple écrêtage (`.NORMALIZE_NATIVE_0_100`) |
| Fonction | [`indicateur_b1_protection()`](https://pobsteta.github.io/nemeton/reference/indicateur_b1_protection.md) — `R/indicators-biodiversity.R:68` |
| Colonnes annexes | `B1_pct` (couverture brute), `B1_nb` (nombre de statuts croisés) |

## 2. Le calcul

Pour chaque unité, et pour **chaque type de protection présent** :

    couverture_type = min(1, aire(intersection) / aire(unité))
    B1 = somme(couverture_type x poids_type) / somme(poids_type)  x 100

Autrement dit une **moyenne des couvertures pondérée par la force du
statut**, et non une simple somme de surfaces.

| Force | Poids | Statuts reconnus (sous-chaîne, insensible à la casse) |
|----|----|----|
| Forte | **1,0** | `rnn`, `rnr`, `apb`, `rb`, `rncfs`, `pn`, `coeur` |
| Moyenne | **0,6** | `sic`, `zps`, `zsc`, `natura`, `znieff1` |
| Faible / informative | **0,3** | `pnr`, `ramsar`, `pnm`, `znieff2` |
| Inconnue | **0,5** | tout type non reconnu |

Le type est lu dans la première colonne trouvée parmi `type_protection`,
`zone_type`, `type`, `statut`.

**Exemples chiffrés** :

| Situation | Calcul | B1 |
|----|----|----|
| 100 % en réserve naturelle (poids 1,0) | (1,0 × 1,0) / 1,0 × 100 | **100,0** |
| 100 % en ZNIEFF 2 (poids 0,3) | (1,0 × 0,3) / 0,3 × 100 | **100,0** |
| 50 % en Natura 2000 seul | (0,5 × 0,6) / 0,6 × 100 | **50,0** |
| 100 % ZNIEFF 2 + 40 % Natura 2000 | (1,0 × 0,3 + 0,4 × 0,6) / (0,3 + 0,6) × 100 | **60,0** |
| Aucun recoupement | — | **0,0** |

> **Le poids ne hiérarchise pas les statuts entre eux, il les pondère
> dans la moyenne.** Une unité entièrement en ZNIEFF 2 obtient **100**,
> exactement comme une unité entièrement en réserve naturelle intégrale
> : le dénominateur normalise par la somme des poids. La force du statut
> ne joue que lorsque **plusieurs statuts se croisent** avec des taux de
> couverture différents. C’est un choix défendable — « cette unité est
> intégralement protégée, à la hauteur de ce que son statut permet » —
> mais ce n’est pas ce que le mot « pondéré » laisse spontanément
> entendre. À dire avant toute comparaison entre unités de statuts
> différents.

## 3. Le calcul par niveau NDP

| NDP | Source | Ce qui change |
|----|----|----|
| **0** | INPN (WFS) — **non implémenté**, cf. §4 | `NA` en pratique, sauf couche fournie à la main |
| **1** | idem NDP 0 | inchangé : B1 dépend d’un zonage réglementaire, pas d’un capteur |
| **2** | \+ vérification drone des limites | correction des contours litigieux |
| **3** | \+ relevé terrain des statuts | statuts constatés sur place |
| **4** | jumeau numérique complet | — |

**B1 est l’indicateur le moins sensible au NDP des 41.** Un statut de
protection est une donnée juridique : ni le LiDAR, ni le drone, ni le
scanner terrestre ne la produisent. Ce qui progresse avec le NDP, c’est
la **précision géométrique des contours**, pas la connaissance du
statut.

## 4. Trois pièges

1.  **Le mode `source = "wfs"` n’interroge rien.** L’appel émet
    `biodiversity_wfs_fetching` puis immédiatement
    `biodiversity_wfs_failed`, et rend `NA`. Le connecteur INPN n’est
    pas implémenté. **En pratique, B1 n’est calculé que si l’on fournit
    soi-même `protected_areas`.**
2.  **`NA` et `0` ne disent pas la même chose, et le code y tient.**
    Absence de donnée → `NA` (« on n’a pas pu regarder ») ; couche
    fournie mais vide → `0` (« on a regardé, rien ne protège »).
    [`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
    moyennant avec `na.rm = TRUE`, un `0` fabriqué tirerait
    `famille_biodiversite` vers le bas tandis qu’un `NA` honnête
    s’efface. Ne jamais « corriger » un `NA` de B1 en `0` en amont.
3.  **Sans colonne de type, le score est divisé par deux.** Quand aucune
    des colonnes `type_protection` / `zone_type` / `type` / `statut`
    n’est présente, le code applique `B1 = pct × 0.5` — le poids par
    défaut, **sans le dénominateur normalisateur** du chemin principal.
    Une unité couverte à 100 % obtient alors **50**, pas 100. Deux jeux
    de données identiques au nom d’une colonne près donnent donc des
    scores du simple au double. **Toujours fournir une colonne de
    type**, quitte à la remplir d’une constante.

## 5. Aval

    indicateur_b1_protection()  ->  colonnes B1, B1_pct, B1_nb
          |
          +- normalize_indicator()     -> passthrough clamp [0, 100]
          +- create_family_index("B")  -> famille_biodiversite = moy(B1, B2, B3, B4)

`B1_pct` (couverture brute non pondérée) et `B1_nb` (nombre de statuts
croisés) ne sont **pas** agrégées dans la famille : ce sont des colonnes
de diagnostic, utiles pour expliquer un score à un propriétaire.

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction B1 et table des poids | `R/indicators-biodiversity.R:68-200` |
| Déclaration « native 0-100 » | `R/normalization.R`, `.NORMALIZE_NATIVE_0_100` |
| Source essences (composition) | `inst/datasources/FR.json` — `theia_species` |
