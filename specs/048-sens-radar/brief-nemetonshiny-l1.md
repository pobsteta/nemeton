# Brief `nemetonshiny` — `L1` change de sens, `T1` change d'échelle (spec 048 §9-§10)

**Cœur requis** : `nemeton (>= 0.197.0)`.
**Portée app** : **aucun code à écrire**. Une chose à faire, une à ne surtout
pas faire, une à dire.

Suite directe du brief `brief-nemetonshiny.md` (famille R, 0.181.0) : même
défaut, même correctif, autre famille.

## Ce qui a changé dans le cœur

`indicateur_l1_effet_lisiere` (colonne `L1`, famille **L — Paysage**) est
désormais **inversé à la normalisation**, comme R1–R5 et T3.

Sa grandeur brute est « haut = mauvais » : ses trois composantes montent toutes
avec l'effet de lisière subi — la géométrie avec l'irrégularité du contour, le
contraste de matrice qui code le **bâti à 90** et la forêt à 0, l'exposition
avec le vent et le soleil reçus. Elle passait pourtant telle quelle sur le
radar. Une parcelle en lanière bordée de bâti obtenait donc un
`famille_paysage` **flatteur**, pendant que le **même chiffre** la pénalisait
dans `N3` (qui calcule `anti_frag = 100 − L1`).

## 1. À NE PAS faire — ré-inverser

Le cœur rend déjà la valeur dans le bon sens. Toute inversion côté app
annulerait la correction, en silence. Même consigne que pour R5 en 0.94.0 et
pour R1–R4 en 0.181.0.

## 2. À faire — invalider et recalculer

**Tous les `famille_paysage` déjà calculés sont faux**, et l'indice général
avec eux. Même mécanisme que pour la famille R :
`invalidate_indicators(project_id)`, déclenché une fois à la montée de version
— sans quoi `compute_all_indicators()` relira un `indicators.parquet` construit
avec l'ancien sens et sautera le recalcul en croyant avoir déjà travaillé.

## 3. À dire à l'utilisateur

Un projet rouvert après la montée de version affichera un `famille_paysage`
**différent**, nettement plus bas sur les parcelles morcelées ou bordées de
bâti. Une comparaison de scores de paysage d'avant et d'après le 2026-09-18 n'a
pas de sens.

## 4. Ce qui ne change pas

- Les **valeurs brutes** de `L1` : la fonction d'indicateur est inchangée.
- **`N3` et `famille_naturalite`** : `indicateur_n3_naturalite()` lit la
  colonne `L1` **brute** — `create_family_index()` travaille sur une copie et
  ne mute pas les colonnes source — et applique sa propre inversion. Aucun N3
  ne bouge. Si vous voyez N3 changer, c'est qu'une double inversion s'est
  glissée quelque part.
- **`L2` (morcellement)** : COHESION + AI, déjà « haut = bon », **reste en
  passthrough**. Et `L3` (hétérogénéité spectrale) aussi.
- Les libellés, les couleurs, l'ordre des axes du radar. L'infobulle de L1 est
  précisée côté cœur (« Sens inversé : plus d'effet de lisière = indice plus
  bas ») — elle vient d'`INDICATOR_FAMILIES`, donc elle arrive toute seule.

## 5. Le piège, si jamais vous touchez aux slugs

Les deux noms de colonnes retirés en 0.176.0 sont **croisés** (spec 045) :

```
indicateur_l2_fragmentation -> porte les valeurs de L1  (s'inverse)
indicateur_l1_sylvosphere   -> porte les valeurs de L2  (reste passthrough)
```

Le relevé initial de l'écart, et les deux fiches indicateurs, désignaient le
mauvais des deux. Inverser `indicateur_l1_sylvosphere` retournerait le
**morcellement** sur tous les jeux non migrés.

## 6. Vérification

Sur un projet déjà calculé, avant et après recalcul :

| Contrôle | Attendu |
|---|---|
| `famille_paysage` d'une UGF en lanière bordée de bâti | **baisse** nettement |
| `famille_paysage` d'une UGF au cœur d'un massif continu | monte, ou bouge peu |
| `N3` et `famille_naturalite` | **inchangés** |
| `L2`, `L3` | inchangés |

Si `famille_paysage` **monte** sur vos parcelles les plus morcelées, c'est
qu'une inversion a été appliquée deux fois — cf. §1.


---

# Deuxième partie — `T1` ancienneté change d'échelle (spec 048 §10)

Trouvé en vérifiant le correctif L1. Même famille de défaut, autre symptôme :
ce n'est pas le **sens** de T1 qui était faux, c'est son **échelle**.

## Ce qui a changé dans le cœur

`indicateur_t1_anciennete()` rend un **âge en années**, pas un score. Il était
déclaré natif 0-100, donc simplement écrêté : une futaie de 150 ans et une de
250 ans sortaient au même **100**, et un peuplement de 30 ans était noté 30/100.

T1 reçoit désormais une borne haute de **1000 ans** :
`0, 250, 500, 1000 → 0, 25, 50, 100`. **Aucune inversion** — plus vieux = mieux,
le sens était juste.

## À faire — le même recalcul

`invalidate_indicators(project_id)` couvre L1 et T1 d'un coup : c'est le même
geste, à la même montée de version. **Tous les `famille_temporelle` changent**
en plus des `famille_paysage`.

## À dire à l'utilisateur, et c'est le point qui va surprendre

**T1 va tomber très bas sur le radar, et c'est correct.** Le domaine forestier
ordinaire — 30 à 150 ans — occupe désormais le bas de l'échelle : **3 à 15 sur
100**. Avant, tout ce qui dépassait un siècle était uniformément à 100.

Un utilisateur qui voit son axe « Ancienneté » s'effondrer va le lire comme une
régression. Ce n'en est pas une : la borne de 1000 ans rapporte le peuplement à
une forêt ancienne, et un peuplement jeune y est **effectivement** bas. Si
l'interface commente les axes faibles, T1 mérite probablement un mot dédié —
l'infobulle du cœur le dit déjà (« un peuplement jeune reste donc bas sur
l'axe »), mais un axe à 5/100 attire l'œil plus qu'une infobulle.

C'est le seul point de ce brief qui demande peut-être un arbitrage de votre
côté : nous n'avons pas changé l'échelle du radar, seulement celle de T1.

## Ce qui ne change pas

- Les **valeurs brutes** de T1 : toujours un âge en années.
- Son sens : haut = plus ancien = mieux. **Ne pas inverser.**
- `T2`, `T3` : inchangés (`T3` reste inversé, comme depuis la spec 030).
