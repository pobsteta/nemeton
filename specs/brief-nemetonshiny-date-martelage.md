# Brief `nemetonshiny` — la date de martelage exportée est un 1er janvier

**Dépôt concerné** : `nemetonshiny` seul. **Aucun impact cœur.**
**Fichier** : `R/service_marculus.R`, ≈ l. 192-198 et 217.
**Nature** : question de modèle, pas correctif — le code fait aujourd'hui ce
qu'il annonce faire.

## Le constat

`dateMartelage` vaut le **1er janvier de `annee_cible`** de l'action :

```r
annee <- suppressWarnings(as.integer(action$annee_cible %||% NA))
date_martelage <- if (!is.na(annee)) {
  round(as.numeric(as.POSIXct(sprintf("%d-01-01", annee), tz = "UTC")) * 1000)
} else NULL
```

C'est un substitut **assumé et documenté sur place** : « Un 1er janvier n'est
pas une date de chantier — l'opérateur la corrigera — mais laisser le champ vide
priverait la liste de son tri, qui est par date de martelage décroissante. »

Le raisonnement est bon : une date fausse mais ordonnable a été préférée à un
champ vide qui casse le classement. Ce brief ne le conteste pas — il demande si
le prix est encore le bon.

## Ce que ce substitut coûte

1. **Une date qui n'a pas eu lieu entre dans un document de gestion.** Le
   martelage est un acte tracé ; « 01/01/2027 » y a l'apparence d'une donnée
   saisie, pas d'un remplissage par défaut. Rien ne distingue, à la lecture, une
   date corrigée par l'opérateur d'une date jamais touchée.
2. **Toutes les actions d'une même année sont ex æquo.** Le tri « par date de
   martelage décroissante » ne trie donc rien à l'intérieur d'un millésime : le
   bénéfice invoqué pour ce substitut n'existe que d'une année à l'autre.
3. **`annee_cible` est une échéance de programme, pas une date d'exécution.**
   Les deux se ressemblent une fois écrites en millisecondes, et plus rien ne
   dit laquelle on lit.

## Trois issues, par coût croissant

**A — Ne rien changer, et le dire à l'écran.** Si le 1er janvier ne sort jamais
d'un usage de tri, le laisser est légitime — à condition que l'interface annonce
« année cible » là où elle affiche cette date, et non « date de martelage ».
Coût : un libellé. C'est le minimum, et c'est peut-être suffisant.

**B — Distinguer « proposée » de « saisie ».** Garder le substitut pour le tri,
mais marquer qu'il n'a pas été validé (un champ de contexte, ou la convention
« 1er janvier = non renseignée » écrite noir sur blanc dans le contrat
Marculus). L'opérateur voit alors ce qu'il corrige. Coût : un champ, et un
accord avec l'aval.

**C — Une vraie date de chantier dans le modèle d'action.** C'est la seule issue
qui supprime la question : une action porte `date_martelage_prevue`, distincte
de `annee_cible`, saisissable, vide tant qu'elle n'est pas décidée. Le tri
retombe alors sur l'année quand la date manque — ce qui est exactement le
comportement voulu. Coût : un champ de plus dans le modèle d'action, sa
migration, et son entrée dans l'interface du Plan d'actions.

## Ce que ce brief ne tranche pas

**Le choix entre A, B et C dépend de l'usage réel du champ côté téléphone et du
document produit après martelage** — deux choses que je ne peux pas observer
d'ici. Si `dateMartelage` ne sert qu'à ordonner une liste, A suffit et le reste
est du travail pour rien. S'il est repris dans un journal ou un état
récapitulatif, C est la seule honnête.

**Une vérification à faire côté Marculus avant de choisir** : que fait le
téléphone d'un contexte **sans** `dateMartelage` ? Le code actuel omet le champ
quand `annee_cible` est absente, donc ce cas existe déjà en production. S'il est
géré proprement (contextes non datés rangés en fin de liste), l'argument « un
champ vide casserait le tri » tombe, et A devient B sans effort.
