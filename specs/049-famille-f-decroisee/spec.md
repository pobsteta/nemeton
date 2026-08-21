# Spec 049 — Famille F décroisée : F1 = fertilité, F2 = érosion

**Version** : 1.0.0
**Date**    : 2026-08-21
**Statut**  : **Livrée** (v0.182.0). Clôt le point laissé en suspens par la
spec 045.
**Cible**   : `nemeton` (cœur). Suite côté `nemetonshiny` : brief joint.

---

## 1. Le point resté ouvert

La spec 045 a décroisé la famille L en **renommant les fonctions**, et a laissé
F de côté en l'écrivant explicitement dans son propre test :

> « Reste F, dont le croisement est d'une autre nature : aucune fonction n'y
> contredit son propre titre, c'est le sens de `F1` qui est en suspens. »

Ce constat était juste. Il fallait trancher ce que **F1 désigne**.

## 2. Quatre sources, trois d'accord

| Source | Ce qu'elle dit |
|---|---|
| Nom des fonctions | `indicateur_f1_fertilite` = fertilité, `indicateur_f2_erosion` = érosion |
| `.normalize_resolve_alias()` | `"F1"` → `indicateur_f1_fertilite` |
| `CLAUDE.md` | « F1 (fertilité), F2 (érosion) » |
| **`INDICATOR_FAMILIES`** | **F1 = « Risque d'érosion », F2 = « Fertilité des sols »** |

Seule la table disait l'inverse — et son `column_names` était **croisé pour
compenser** :

```r
column_names = c("indicateur_f2_erosion", "indicateur_f1_fertilite")
```

## 3. Pourquoi ça devait être corrigé

Les deux erreurs s'annulaient **à l'affichage** : le libellé « Risque d'érosion »
était bien apparié à la colonne d'érosion. Le radar ne mentait pas.

Mais le **code court**, lui, désignait deux choses selon le chemin emprunté :

```
.normalize_resolve_alias("F1")  ->  indicateur_f1_fertilite   (fertilité)
INDICATOR_FAMILIES$F  : F1      ->  indicateur_f2_erosion     (érosion)
```

Un appelant qui normalise par code court obtient la règle de la fertilité pour
une colonne d'érosion. Aujourd'hui sans dégât visible — les deux sont 0-100
natifs — mais c'est un piège armé, exactement celui que la spec 045 décrivait au
§3 pour L.

## 4. Le correctif — la table, pas les fonctions

Contrairement à L, **aucune fonction n'est renommée et aucune colonne n'est
migrée** : les slugs persistés (`indicateur_f1_fertilite`,
`indicateur_f2_erosion`) étaient déjà justes. Seule la table change.

- `column_names` décroisé ;
- `indicator_labels` et `indicator_tooltips` remis dans l'ordre : F1 =
  Fertilité des sols, F2 = Risque d'érosion.

**Aucune valeur ne change**, aucune donnée persistée n'est touchée.

## 5. Correction annexe — la doc de F2 parlait de fertilité

`indicateur_f2_erosion` déclarait rendre des *« fertility scores (0-100, higher
= more fertile) »* et journalisait « Computing fertility from TWI + slope ».
Copié-collé depuis F1 : ses ingrédients sont topographiques — TWI, pente — plus
une résistance texturale optionnelle.

Le `@return` dit maintenant ce que la fonction calcule : un score de
**résistance à l'érosion**, haut = plus résistant, donc **risque d'érosion plus
faible**. L'infobulle F2 est réécrite en conséquence : elle mentionnait « la
couverture végétale », que le calcul n'utilise pas.

## 6. Tests

Le garde-fou change de sens, et c'est l'essentiel :

- `test-indicator-labels-pairing.R` exigeait que les lignes croisées soient
  « exactement les quatre documentées » ; il exige désormais **zéro croisement**
  sur les 41 lignes. Toute réapparition le fera échouer.
- `test-indicator-families.R` gardait le croisement de F et L ; il verrouille
  maintenant leur absence.

## 7. Ce que l'app doit savoir

Le **libellé affiché reste correct** — il l'était déjà. Ce qui change, c'est la
**lettre** attachée à chaque grandeur : l'érosion passe du créneau F1 au créneau
F2, la fertilité l'inverse. Une interface qui étiquette un axe « F1 » en dur, ou
qui a forké la table, doit être vérifiée.

## 8. Limite assumée

`indicateur_f2_erosion` reste une **résistance à l'érosion dérivée de la
topographie**, pas un modèle d'érosion (ni RUSLE, ni facteur de couverture). Le
nom, le libellé et la doc concordent désormais avec ce qu'elle fait ; la qualité
du proxy, elle, n'est pas l'objet de cette spec.
