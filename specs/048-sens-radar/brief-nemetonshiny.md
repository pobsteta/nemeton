# Brief `nemetonshiny` — la famille R change de sens (spec 048)

**Cœur requis** : `nemeton (>= 0.181.0)`.
**Portée app** : **aucun code à écrire**, mais deux choses à faire et une à ne
surtout pas faire.

## Ce qui a changé dans le cœur

`R1` (feu), `R2` (tempête), `R3` (sécheresse) et `R4` (abroutissement) sont
désormais **inversés à la normalisation**, comme `R5` l'est depuis 0.99.1.

Leur grandeur brute est « haut = mauvais » — plus de risque, plus de
vulnérabilité, plus de stress — et elle passait telle quelle sur le radar. Une
UGF très exposée obtenait donc un `famille_risque` **élevé**, c'est-à-dire
flatteur. Et `R5` pointait à l'opposé des quatre autres dans sa propre famille.

## 1. À NE PAS faire — ré-inverser

Le cœur rend déjà la valeur dans le bon sens. `normalize_indicator()` s'en
charge, exactement comme pour `R5` et `T3`. Toute inversion côté app annulerait
la correction et remettrait le défaut, en silence.

C'est la même consigne que pour R5 en 0.94.0, et elle vaut maintenant pour les
cinq indicateurs de la famille R.

## 2. À faire — invalider et recalculer

**Tous les `famille_risque` déjà calculés sont faux**, et l'indice général avec
eux. Il faut recalculer chaque projet.

Le mécanisme existe déjà : `invalidate_indicators(project_id)`, celui qu'utilise
`.onf_commit()` après un croisement ONF. Il faut le déclencher une fois, à la
montée de version — sans quoi `compute_all_indicators()` relira un
`indicators.parquet` construit avec l'ancien sens et sautera le recalcul en
croyant avoir déjà travaillé.

## 3. À dire à l'utilisateur

Un projet rouvert après la montée de version affichera un `famille_risque`
**différent**, souvent nettement plus bas sur les massifs exposés. Ce n'est pas
une régression : c'est la première fois que le radar dit vrai sur cette famille.

Une comparaison de scores d'avant et d'après le 2026-08-20 n'a aucun sens.

## 4. Ce qui ne change pas

- Les **valeurs brutes** `R1`…`R5` : les fonctions d'indicateur et leurs
  appelants sont inchangés. Seule la valeur normalisée bascule.
- `R6` (sensibilité microclimatique) et `R7` (gel tardif) : ils sont orientés
  « haut = bon » à la source et **ne s'inversent pas**.
- Les libellés, les couleurs, l'ordre des axes du radar.

## 5. Vérification

Sur un projet déjà calculé, avant et après recalcul :

| Contrôle | Attendu |
|---|---|
| `famille_risque` d'une UGF à fort risque | **baisse** nettement |
| `famille_risque` d'une UGF peu exposée | monte, ou bouge peu |
| Une UGF avec R5 sévère | continue de tirer la famille vers le bas, comme avant |
| R6 / R7 | inchangés |

Si `famille_risque` **monte** sur vos massifs les plus exposés, c'est qu'une
inversion a été appliquée deux fois — cf. §1.
