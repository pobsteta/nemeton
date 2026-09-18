# Spec 048 — Convention du radar : 0-100, haut = bon

**Version** : 1.3.0
**Date**    : 2026-08-20, §9 à §11 ajoutés le 2026-09-18
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

**Cette réserve s'est réalisée** : `indicateur_l1_effet_lisiere` était l'une
des 28 fonctions non relues, et il était bien mal orienté. Cf. §9.

Un cas reste ouvert, de nature différente : `indicateur_f2_erosion` déclare
rendre des *« fertility scores (0-100, higher = more fertile) »* et calcule
effectivement de la fertilité — TWI plus pente aplanie, plus résistance
texturale. Son **orientation est juste** ; c'est son **nom** qui annonce
l'érosion quand il duplique la sémantique de F1. Même famille de défaut que L1/L2
avant 0.176.0, à traiter séparément.


---

## 9. Addendum — `L1` effet de lisière (0.197.0)

> Relevé le 2026-08-27 en rédigeant la fiche indicateur L1, corrigé le
> 2026-09-18. C'est la réserve du §8 qui se réalise, à la lettre : L1 est l'une
> des 28 fonctions dont l'orientation n'avait pas été relue ligne à ligne.

### 9.1 Pourquoi l'audit du §2 l'a manqué

L'audit comparait l'orientation **déclarée en roxygen** à l'orientation
**mesurée** après normalisation. Les quatre violations trouvées (R1–R4) l'ont
été parce que leur roxygen **annonçait** « *Higher = higher risk* » : le
désaccord était lisible sans ouvrir le corps de la fonction.

Le roxygen de `indicateur_l1_effet_lisiere()` n'annonce, lui, **aucun sens** —
il dit seulement « *Numeric vector of sylvosphere scores (0-100)* ». Le test de
monotonie du §6.3 ne pouvait rien y voir non plus : une normalisation en
passthrough est parfaitement monotone, elle est simplement monotone **dans le
mauvais sens**. Il fallait lire le calcul, et le §8 disait que ça n'avait pas
été fait.

### 9.2 Le calcul dit « haut = mauvais », trois fois

`L1 = 0,30 × géométrie + 0,40 × contraste + 0,30 × exposition`, et les trois
composantes montent avec l'effet de lisière subi :

| Composante | Formule | Ce qui fait monter le score |
|---|---|---|
| Géométrie (30 %) | `(SI − 1) × 25`, `SI = P / (2√(πA))` | contour plus irrégulier, donc plus de lisière par hectare |
| Contraste (40 %) | table OSO pondérée par les pixels du tampon | matrice hostile — **bâti = 90**, routes = 75, cultures = 50, **forêt = 0** |
| Exposition (30 %) | 0,6 × vent + 0,4 × soleil, projetés sur la normale aux segments | lisière plus exposée au vent dominant et au sud |

Les deux autres lectures de la colonne concordent : l'infobulle
(« fragmentent l'habitat intérieur ») et `indicateur_n3_naturalite()`, qui
calcule `anti_frag = 100 − L1` **avant** de l'ajouter positivement à la
naturalité.

### 9.3 Ce que la faute produisait

Une parcelle en lanière bordée de bâti obtenait un L1 élevé, que le radar
affichait comme un **bon** score de paysage et qui tirait `famille_paysage`
vers le haut — pendant que le **même chiffre**, injecté dans N3, la pénalisait.
Trois lectures sur quatre disaient « haut = mauvais », la quatrième décidait de
l'affichage.

### 9.4 Le correctif, et le piège des slugs croisés

`indicateur_l1_effet_lisiere` quitte `.NORMALIZE_NATIVE_0_100` pour
`.NORMALIZE_RULED` et rejoint la branche d'inversion, aux côtés de R1–R5 et T3.

**Le relevé initial de l'écart désignait le mauvais slug retiré** — il parlait
de « l'alias `indicateur_l1_sylvosphere` ». C'est l'inverse : les deux noms de
0.176.0 étaient **croisés**, c'est même tout l'objet de la spec 045.

```
indicateur_l2_fragmentation -> indicateur_l1_effet_lisiere   (s'inverse)
indicateur_l1_sylvosphere   -> indicateur_l2_morcellement    (reste passthrough)
```

Inverser `indicateur_l1_sylvosphere` aurait retourné le **morcellement** — un
COHESION + AI déjà orienté « haut = bon » — sur tous les jeux non migrés : le
correctif aurait fabriqué une seconde faute en réparant la première. La même
inversion croisée s'était glissée dans les deux fiches indicateurs, chacune
annonçant comme « ancien nom » le sien propre plutôt que celui de sa voisine.

### 9.5 Tests

Quatre verrous dans `test-normalization.R`, plus un cinquième ailleurs :

1. L1 s'inverse — nom long, code court `L1`, écrêtage avant inversion ;
2. les deux slugs retirés sont **croisés** : `indicateur_l2_fragmentation`
   s'inverse, `indicateur_l1_sylvosphere` et `indicateur_l2_morcellement` non ;
3. `create_family_index()` : un L1 de 85 doit **baisser** `famille_paysage` ;
4. le balayage du §6.3 attend désormais **neuf** inversés — L1 rejoint la liste ;
5. `indicateur_n3_naturalite()` lit le L1 **brut** et applique sa propre
   inversion : sans ce verrou, quelqu'un qui « harmoniserait » N3 sur la
   nouvelle convention l'inverserait deux fois.

### 9.6 Conséquence, à annoncer

**Tous les `famille_paysage` déjà calculés changent**, et l'indice général avec
eux. `N3` et toutes les valeurs brutes de L1 sont **inchangés** : seule la
valeur normalisée bascule. Comme en §7, une comparaison de scores de paysage
d'avant et d'après le 2026-09-18 n'a pas de sens.

Côté app : rien à coder, et surtout **ne pas ré-inverser**.

---

## 10. Addendum — `T1` ancienneté : un âge en années pris pour un score (0.197.0)

> Trouvé le 2026-09-18 **en vérifiant le correctif du §9**, pas en le
> cherchant : l'audit qui a suivi la correction de L1 a passé en revue les
> indicateurs déclarés natifs 0-100 dont le roxygen n'annonce aucun sens. Borne
> décidée par Pascal le 2026-09-18.

### 10.1 Le défaut

`indicateur_t1_anciennete()` ne rend pas un score : il rend un **âge en
années**. Son propre `@return` le disait — *« estimated age in years »* — et
les trois chemins de calcul le confirment : âge TFV pondéré par les surfaces,
colonne `age` fournie telle quelle, ou `current_year − establishment_year`.

Il figurait pourtant dans `.NORMALIZE_NATIVE_0_100`, donc `normalize_indicator()`
se contentait d'un `clamp(0, 100)` :

```r
normalize_indicator("indicateur_t1_anciennete", c(30, 80, 150, 250))
#>  30  80  100  100      # avant 0.197.0
```

Une futaie de 150 ans et une de 250 ans sortaient au **même 100**, et un
peuplement de 30 ans était noté 30/100 — une « note d'ancienneté » qui était
l'âge lui-même. Ce n'était pas une normalisation, c'était une coïncidence
d'échelle qui plafonnait à 100 ans.

### 10.2 Ce qui l'a rendu invisible

Le même mécanisme qu'au §9, à un cran de plus. La déclaration « natif 0-100 »
ne se contente pas de laisser passer la valeur : elle **désarme le garde-fou**.
Le filet de la spec 038 n'avertit que pour un indicateur connu qui tombe au
repli naïf **sans** être déclaré natif — déclarer un indicateur natif, c'est
donc affirmer qu'il n'a pas besoin de règle, et cette affirmation n'est vérifiée
par rien.

La fiche T1 documentait d'ailleurs le défaut depuis le 2026-08-27, en piège
n° 1, avec le bon exemple (« 120 ans et 300 ans obtiennent le même score »).
Il n'était simplement pas remonté dans la table des écarts.

### 10.3 Le correctif

`indicateur_t1_anciennete` quitte `.NORMALIZE_NATIVE_0_100` pour
`.NORMALIZE_RULED` et reçoit un `ref_max` de **200 ans** :

```r
normalize_indicator("indicateur_t1_anciennete", c(0, 50, 100, 200, 400))
#>   0  25  50  100  100
```

**Pas d'inversion** : plus vieux = mieux, le sens était juste, c'est l'échelle
qui ne l'était pas. La fonction d'indicateur est inchangée et rend toujours un
âge en années.

**Pourquoi 200 et pas une borne physique.** 200 ans est un **seuil sylvicole**,
pas l'âge maximal d'un arbre : au-delà de deux siècles, l'ancienneté est tenue
pour maximale — une futaie de 200 ans et une de 400 ans ne se distinguent plus
utilement pour un gestionnaire, et les distinguer sur le radar reviendrait à
noter la seconde « meilleure » sans qu'aucune décision n'en dépende.

La borne décide surtout de **l'étalement du domaine courant**. À 200 ans, 30 à
150 ans s'étale sur **15 à 75** — c'est-à-dire sur l'essentiel de l'axe, ce
qu'on attend d'un indicateur discriminant. Une borne lointaine (1000 ans, un
temps envisagée) aurait écrasé ce même domaine sur 3 à 15 : le défaut se serait
déplacé du haut de l'échelle vers le bas, sans être corrigé.

### 10.4 Tests

Trois verrous dans `test-normalization.R` : la borne (0, 250, 500, 1000 →
0, 25, 50, 100, plus le code court et la saturation) ; **150 ans et 250 ans se
distinguent** — le test qui aurait échoué avant la 0.197.0 ; et `T1` a bien une
règle (`.normalize_has_rule()`), donc plus de repli naïf silencieux.

### 10.5 Conséquence, à annoncer

**Tous les `famille_temporelle` déjà calculés changent**, et l'indice général
avec eux. Les valeurs brutes de T1 sont inchangées. Côté app : rien à coder,
recalculer.

### 10.6 Ce que ces deux addenda disent de la méthode

Le §9 et le §10 ont été trouvés de la même façon : en **relisant le calcul**,
pas en relisant les déclarations. L'audit du §2 avait fait l'inverse, et il
avait attrapé les quatre indicateurs qui *annonçaient* leur sens. Les deux
défauts restants étaient précisément ceux qui n'annonçaient rien.

Conséquence pratique : `.NORMALIZE_NATIVE_0_100` est une **affirmation non
vérifiée**, et c'est le seul endroit du système de normalisation qui en soit
une. Y inscrire un indicateur devrait demander la même justification que lui
écrire une règle. Les `@return` de L1, L2 et T1 déclarent désormais leur
orientation et leur échelle ; les neuf indicateurs qui restent muets
(`w4_vpd`, `a1`, `a3`, `a4`, `a5`, `p3`, `n1`, `n2`, `n3`) n'ont **pas** été
relus ligne à ligne — comme au §8, la réserve est écrite pour être reprise.

---

## 11. Addendum — `E1` / `E2` : le même nombre, trois bornes (0.197.0)

> Trouvé le 2026-09-18 **en dressant le tableau des 41 indicateurs** demandé par
> Pascal — c'est-à-dire en mettant chaque borne à côté de son unité, ce que rien
> n'obligeait à faire jusque-là. Borne décidée par Pascal le même jour.

### 11.1 E2 **est** E1

`indicateur_e2_evitement()` ne mesure rien d'indépendant : il se déduit de E1.

```
E2 = E1 × 4500 kWh/t × 0,222 kgCO₂/kWh ÷ 1000 = E1 × 0,999
```

À 0,1 % près, **E2 et E1 sont le même nombre**. Ils portaient pourtant
`ref_max = 0,3` et `ref_max = 0,75` : les deux axes de la famille Énergie
étaient en désaccord d'un facteur 2,5 sur ce que vaut « plein score », à partir
d'une donnée identique. `famille_energie` en faisait la moyenne.

### 11.2 Et tous deux sont P1

E1 dérive linéairement du volume sur pied :

```
E1 = V × harvest_rate(0,02) × residue_fraction(0,3) × ρ/1000 × 0,5
   = 0,00165 × V        (ρ = 550)
```

Trois colonnes strictement proportionnelles au même volume, qui saturaient à
**182, 455 et 800 m³/ha** :

| Volume | E1 | **E1 avant** | **E2 avant** | **P1** |
|---|---|---|---|---|
| 100 m³/ha | 0,165 t | 55 | 22 | 12,5 |
| **182 m³/ha** | 0,300 t | **100** | 40 | 22,8 |
| 400 m³/ha | 0,660 t | **100** | 88 | 50 |
| 800 m³/ha | 1,320 t | **100** | **100** | 100 |

À 182 m³/ha — un peuplement français très ordinaire, l'infobulle de P1 annonce
100-400 m³/ha comme typique — la même parcelle était **au maximum** en
bois-énergie et à **22,8/100** en volume. Elles ne pouvaient pas avoir raison
toutes les trois.

Le forfait taillis aggravait : `coppice_fraction × 2` t MS/ha/an, soit une
fraction de taillis de **15 %** suffisant à elle seule à saturer E1, volume
ignoré.

### 11.3 Le correctif

`ref_max(E1) = ref_max(E2) = **1,32 t**` — exactement E1 au plafond de P1
(800 m³/ha, ρ = 550). Les deux bornes doivent être **égales** puisque les deux
grandeurs le sont ; leur valeur commune est celle qui aligne la famille Énergie
sur la famille Production.

Vérification, après correctif — les trois axes notent le même peuplement à
l'identique :

| Volume | E1 | E2 | P1 |
|---|---|---|---|
| 100 m³/ha | 12,5 | 12,5 | 12,5 |
| 182 m³/ha | 22,8 | 22,7 | 22,8 |
| 400 m³/ha | 50,0 | 50,0 | 50,0 |
| 800 m³/ha | 100,0 | 99,9 | 100,0 |

Le résidu de 0,1 point à 800 m³/ha est le facteur 0,999, et le test l'énonce au
lieu de le cacher dans une tolérance.

### 11.4 Limite assumée

Une borne fixe ne peut pas suivre les paramètres dont dépend la grandeur :

- **densité de l'essence** — E1(800 m³/ha) vaut 0,96 t pour ρ = 400 (peuplier)
  et 1,68 t pour ρ = 700 (chêne) ; la borne est ancrée sur ρ = 550, le défaut ;
- **scénario de substitution** — E2 = E1 × 0,999 face au gaz, × 1,458 face au
  fioul ; la borne est ancrée sur `vs_natural_gas`, le défaut.

Une essence dense ou un scénario fioul saturent donc un peu plus tôt. C'est
inhérent à un `ref_max` scalaire sur une grandeur paramétrée, et c'est écrit
plutôt que découvert.

### 11.5 Tests

Trois verrous dans `test-normalization.R` : E1 et E2 portent la **même** borne ;
E1, E2 et P1 notent le même peuplement pareil pour sept volumes de 50 à
800 m³/ha ; et E1 **ne sature plus** sur 100-400 m³/ha, la plage que P1 annonce
comme typique.

### 11.6 Le tableau comme instrument

Les §9 et §10 ont été trouvés en relisant un calcul. Le §11 l'a été autrement :
en **mettant chaque borne à côté de son unité**, sur les 41 indicateurs d'un
coup. Trois anomalies ont sauté aux yeux en une lecture (`E1`, `E2`, `W2`), dont
deux réelles — `W2` sature à 5 % de couverture de zone humide, mais c'est une
affirmation écologique cohérente, pas une erreur d'échelle.

Ce n'est pas un hasard : une borne fausse est invisible dans le code, où elle
n'est qu'un nombre dans un `switch`, et évidente dans un tableau, où elle est à
côté de son unité. L'audit du §2 n'a pas dressé ce tableau.

**Et la fiche E1 documentait déjà le défaut** depuis le 2026-08-27, en piège
n° 1 : « *Le plafond de 0,3 t MS/ha/an sature dès 150 m³/ha environ. Un
peuplement ordinaire atteint donc 100.* » Comme T1 au §10, il n'avait jamais été
remonté dans la table des écarts. **Deux des trois défauts de cette release
étaient écrits, datés, et non lus.**
