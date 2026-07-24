# ADR-015 — Variables biophysiques Sentinel-2 dans le système NDP

> **Statut : Proposé (draft cœur).** Rédigé dans `nemeton/specs/` selon la
> convention héritée de l'ADR-013 ; à **porter vers `nemetonplateform/docs/`**
> (dépôt canonique des ADR) une fois accepté.
>
> - **Date** : 2026-07-24
> - **Décideur** : Pascal Obstétar
> - **Contexte technique** : spec 043 (biophysique S2), nemeton ≥ v0.166.1
> - **ADR liés** : [[ADR-009]] (4 packages, dépendances vers le cœur),
>   [[ADR-011]] (Fibonacci/NDP, confiance φ)
> - **Amende** : **ADR-011**
> - **Note de numérotation** : le brief demandait « ADR-012 », **déjà attribué**
>   (extensions PG : TimescaleDB + pgvector). Le plus haut ADR existant est 014 ;
>   ce document prend donc **015**.

## Contexte et problème

La spec 043 intègre quatre variables biophysiques Sentinel-2 (LAI, fAPAR,
FCOVER, CCC), produites par un package amont `biophysnemeton` (ADR-009) et
consommées par nemeton pour raffiner des indicateurs existants. Deux points
touchent directement l'ADR-011 (pondération Fibonacci, confiance φ) et méritent
une décision d'architecture, car ils gouvernent **la confiance** attachée au
score global — pas seulement une valeur d'indicateur.

**Constat sur le code réel** (spec 043 §0) : le champ `augmented` de
`detect_ndp()` est **déjà un vecteur `character`** (`R/ndp.R`), et porte déjà des
flags ML — dont **`lai_ml`** (spec 033, LAI par inversion prosail). La question
« augmented devient-il multi-valué » est donc **caduque** : il l'a toujours été.
Ce que l'ADR doit trancher n'est pas la structure, mais **la gouvernance** de
l'ajout du flag biophysique et son effet sur φ.

## Décision

### 1 — Le flag n'élève pas le NDP de base ; il augmente, sous condition

`"biophysical_s2"` rejoint le vecteur `augmented` **sans changer le niveau NDP
de base** (comme `height_ml`, `lai_ml`, ADR-011 amendé). Il est posé **seulement
si** le gating de la spec 043 §6 passe (`n_obs`, masquage, flags SL2P, surface).
Sinon absent, et l'indicateur est calculé en mode nominal.

*Justification.* Un flag d'augmentation signale une **granularité de donnée**
supérieure exploitée par `compute_general_index_mixed()`, pas une source NDP
supplémentaire. Poser le flag sur une base insuffisante ferait compter la donnée
biophysique dans φ alors qu'elle est peu fiable — ce que l'ADR-011 interdit de
fait.

*Conséquence.* Le gating est **normatif**, pas cosmétique : c'est la seule barrière
entre « donnée présente » et « donnée digne de peser dans φ ». Ses seuils
(spec 043 §6) sont à calibrer avant mise en service.

### 2 — Un flag unique `"biophysical_s2"`, pas un flag par variable

Les quatre variables partagent la même acquisition, le même composite et le même
gating (elles sortent du même traitement SL2P sur les mêmes scènes). Un flag
**unique** les couvre.

*Justification.* Un flag par variable (`lai_s2`, `ccc_s2`…) multiplierait les
états sans information supplémentaire : si le gating passe, les quatre sont
disponibles ; s'il échoue, aucune. La provenance fine par indicateur est déjà
lisible par la présence/absence de la valeur dans chaque colonne.

*Conséquence.* `canopy_provenance()` (`R/ndp.R`) gagne au plus une correspondance
`"biophysical_s2"` → clé canonique. Pas d'explosion combinatoire.

### 3 — Effet sur la confiance φ : par la granularité, pas par un poids ad hoc

L'augmentation biophysique agit via `compute_general_index_mixed()` (granularité
par indicateur), **jamais** par un bonus de confiance forfaitaire ajouté au
score.

*Justification.* L'ADR-011 fait de φ le ratio du poids Fibonacci cumulé sur le
poids total. Un bonus ad hoc court-circuiterait cette définition et rendrait φ
non comparable entre unités.

*Conséquence.* Aucune constante de confiance nouvelle. Le seul levier est
l'éligibilité (flag posé ou non), déjà tranchée en (1).

## Conséquences transverses

### `nemetonshiny`
- Le badge de provenance (déjà présent pour CHM/LiDAR) gagne un état
  « biophysique S2 » quand `"biophysical_s2"` est dans `augmented`.
- Aucun nouvel axe radar ni sous-indicateur (spec 043, D-brief 1) : l'affichage
  radar est **inchangé**.
- La confiance φ affichée sous le score reste calculée côté cœur ; l'app ne
  recompose rien.

### Exports GeoPackage
- `augmented` étant déjà sérialisé comme vecteur/chaîne dans le résultat NDP,
  l'ajout d'une valeur **ne change pas le schéma** — un consommateur qui lit
  `augmented` reçoit une valeur de plus, pas une colonne de plus.
- **À vérifier à l'implémentation** : la sérialisation actuelle d'`augmented`
  (concaténation ? liste ?) tolère bien N valeurs. Le code (`new_ndp_result`)
  le porte déjà comme `character` multi-élément (spec 043 E2), donc a priori oui.

### Affichage radar
- Inchangé. Les variables biophysiques raffinent la **valeur** de sous-indicateurs
  existants (a1, c1, c2, b2, w3, f1, r3), pas le nombre d'axes.

## Alternatives écartées

- **Élever le NDP de base** quand la donnée biophysique est présente : rejeté —
  la donnée biophysique est une granularité ML sur données publiques (S2), pas un
  saut de niveau NDP (qui suppose LiDAR/terrain, ADR-011).
- **Bonus de confiance forfaitaire** : rejeté (décision 3).
- **Flag par variable** : rejeté (décision 2).

## Statut de validation

Proposé. Dépend de la calibration des seuils de gating (spec 043 §6) avant
acceptation opérationnelle. À porter dans `nemetonplateform/docs/` une fois
accepté, avec mise à jour de la table ADR de `CLAUDE.md` (ligne 015).
