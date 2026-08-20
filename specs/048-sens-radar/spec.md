# Spec 048 — Convention du radar : 0-100, haut = bon

**Version** : 1.0.0
**Date**    : 2026-08-20
**Statut**  : **Décidée par Pascal le 2026-08-20**, énoncée ainsi : « tous les
indicateurs doivent être calculés entre 0-100 pour le graphique radar, et plus
l'indicateur est haut, meilleur il est. Si R1 est proche de 100, il y a peu de
risque incendie. »
**Cible**   : `nemeton` (cœur). Suite obligatoire : recalcul côté app.

---

## 1. La convention

Toute colonne d'indicateur consommée par le radar est sur **0-100**, et
**plus la valeur est haute, meilleur c'est**. Sans exception.

Un indicateur dont la grandeur brute est « haut = mauvais » — un risque, une
pression, un stress — n'est pas exclu : il est **inversé à la normalisation**.
La fonction d'indicateur et ses appelants ne changent pas ; seule la valeur
normalisée bascule.

## 2. L'audit

Les 41 colonnes déclarées par `INDICATOR_FAMILIES` ont été passées au même test :
orientation **déclarée** dans la doc roxygen, contre orientation **réelle**
mesurée en faisant croître l'entrée de `normalize_indicator()`.

### 2.1 Couverture — saine

23 indicateurs natifs 0-100, 18 avec une règle dédiée. **Aucun ne tombe au repli
naïf** que `create_family_index()` signale.

### 2.2 Quatre violations

| Indicateur | Doc (brut) | Normalisé avant | |
|---|---|---|---|
| `indicateur_r1_feu` | *Higher = higher risk* | croissant | ❌ |
| `indicateur_r2_tempete` | *Higher = more vulnerable* | croissant | ❌ |
| `indicateur_r3_secheresse` | *(aucun `@return`)* — le code atténue le score avec la neige et l'humidité du sol, donc haut = plus de stress | croissant | ❌ |
| `indicateur_r4_abroutissement` | *Higher = higher risk* | croissant | ❌ |

Ce n'est pas qu'une affaire de documentation : dans le corps de R1, plus la
pente est forte, plus le score monte.

### 2.3 Ce qui était déjà juste

`T3`, `R5`, `S1`, `S2` étaient inversés à raison. `R6` (« higher = less
sensitive ») et `R7` (« high = low frost risk ») sont orientés « haut = bon » à
la source : les inverser les casserait. `S1`/`S2` valorisent la **proximité**
(famille Social & Usages), `N1` la **distance** (famille Naturalité) : sens
opposés assumés, pas une incohérence.

## 3. Ce que la faute produisait

Une UGF très exposée au feu, vulnérable aux tempêtes, en stress hydrique et
fortement abroutie obtenait un `famille_risque` **élevé** — donc flatteur sur le
radar.

Et dans la même famille, `R5` pointait **à l'opposé** de `R1`, `R2` et `R4`.

## 4. Comment la faute a survécu

Elle était **écrite deux fois**, ce qui la rendait auto-confirmante :

1. le commentaire qui justifie l'inversion de `R5`, dans `normalization.R`,
   affirmait que c'était « pour que sa contribution reste *high = good*
   **comme R1-R4** ». La prémisse était fausse ;
2. un test, `test-normalization.R`, affirmait en commentaire que R1 était
   « *a plain risk indicator (already oriented high=good)* » et vérifiait le
   passthrough. Un test qui valide le défaut le protège.

C'est la même mécanique que la famille L en 0.176.0 : un texte qui décrit
l'intention et non le comportement, et que personne ne recoupe.

## 5. Le correctif

Dans `normalize_indicator()`, `R1` à `R4` rejoignent `R5` dans la branche
d'inversion. Ils quittent `.NORMALIZE_NATIVE_0_100` — ils sont bien 0-100
natifs, mais ils ont besoin d'une **règle**, pas d'un passthrough — pour
`.NORMALIZE_RULED`.

```r
if (indicator %in% c("indicateur_r1_feu", "R1", …, "indicateur_r5_deperissement", "R5")) {
  return(pmin(100, pmax(0, 100 - values)))
}
```

Le commentaire fautif du §4.1 est réécrit ; le test fautif du §4.2 aussi.

## 6. Tests

Trois verrous dans `test-normalization.R` :

1. les cinq indicateurs de risque sont inversés, **nom long et code court** ;
2. `R6` et `R7` ne le sont **pas** — la régression symétrique est aussi possible ;
3. **balayage des 41 colonnes** : chacune doit être monotone après
   normalisation, et la liste des inversées doit être **exactement** R1-R5, T3,
   S1, S2. Tout nouvel indicateur mal orienté fera échouer ce test.

Deux tests existants encodaient l'ancien comportement et sont corrigés :
`test-normalization.R` (famille_risque attendue sur des bruts non inversés) et
`test-family-system.R` (moyenne pondérée calculée sur les bruts).

## 7. Conséquence, à annoncer

**Tous les `famille_risque` déjà calculés changent**, et l'indice général avec
eux. Ce n'est pas une régression, c'est la correction — mais tout projet doit
être recalculé, et une comparaison de scores d'avant et d'après le 2026-08-20
n'a pas de sens.

Côté app : **ne jamais ré-inverser**. Le cœur rend déjà la valeur dans le bon
sens, comme pour R5 depuis 0.99.1.

## 8. Réserve

L'orientation **déclarée** a pu être lue pour 13 indicateurs sur 41 : les autres
n'annoncent aucun sens dans leur roxygen. Pour ceux-là, la vérification a porté
sur la **monotonie** de la normalisation et sur la lecture du calcul quand le
nom laissait un doute (`f2_erosion`, `s3_population`, `w3_humidite`,
`c2_ndvi`), pas sur une relecture ligne à ligne des 28 fonctions.

Un cas reste ouvert, de nature différente : `indicateur_f2_erosion` déclare
rendre des *« fertility scores (0-100, higher = more fertile) »* et calcule
effectivement de la fertilité — TWI plus pente aplanie, plus résistance
texturale. Son **orientation est juste** ; c'est son **nom** qui annonce
l'érosion quand il duplique la sémantique de F1. Même famille de défaut que L1/L2
avant 0.176.0, à traiter séparément.
