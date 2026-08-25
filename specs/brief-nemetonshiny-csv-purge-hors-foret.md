# Brief `nemetonshiny` — l'import CSV croise, mais ne purge pas

**Dépôt concerné** : `nemetonshiny` seul. **Aucun impact cœur.**
**Fichier** : `R/mod_ug.R`, bloc CSV ≈ l. 2519-2542.
**Constat** : Pascal, 2026-08-25. Après import de `couchey-21200.csv`, une UGF
« Hors forêt publique » subsiste dans le Tableau UGF et sur la Carte UGF —
74 tènements, 50,15 ha, groupe d'aménagement `---`, sur 535,59 ha de projet.

---

## Ce n'est pas un défaut du croisement

L'UGF « Hors forêt publique » est le **reste**, produit à dessein : sans lui, la
parcelle cadastrale cesse d'être entièrement pavée, en silence, et
`validate_tiling()` a précisément pour rôle d'interdire ça. Le cœur documente ce
partage — `croiser_parcelles_onf(inclure_reste = FALSE)` par défaut, « the
application's `tenement_split_by_import()` recreates that remainder itself ».

Le reste **doit** donc exister. Ce qui manque, c'est l'étape d'après.

## Un des deux chemins d'entrée purge, l'autre non

| Chemin | Croisement | Purge |
|---|---|---|
| Bouton « Créer les UGF avec le parcellaire ONF » (`mod_ug.R:2309`) | ✅ | ✅ `onf_purger_hors_foret(..., seuil_foret = cfg$seuil_foret)` (l. 2323-2330) |
| **Import CSV** (`mod_ug.R:2526`) | ✅ | ❌ **absente** |

`onf_purger_hors_foret()` n'est appelée **qu'à une seule ligne de toute
l'application** : `mod_ug.R:2324`.

Le bloc CSV lit pourtant déjà les réglages : `cfg_csv <-
project_onf_params(charge$metadata)` (l. 2521). Il en consomme **deux sur
quatre** — `domanialite` et `clip_cadastre` — et laisse `purger` et
`seuil_foret` inutilisés. Les valeurs sont là, sous la main, au bon endroit.

## Le correctif naïf est faux — et c'est le point de ce brief

Ajouter l'appel à la purge ne suffit pas. **La purge retire des parcelles du
projet**, et le bouton ONF le gère par un second mécanisme :

```r
.onf_commit(projet_final, with_parcels = purger)
```

`.onf_commit(with_parcels = TRUE)` appelle `save_parcels()` **en plus** de
`save_ug_data()`. Sans cela — commentaire d'origine, l. 2147-2150 —
« elles réapparaîtraient au prochain chargement du projet, sans leurs
tènements ». C'est le défaut corrigé en **v0.130.7** (« L'onglet Sélection
affichait des parcelles supprimées ») : le réintroduire par la porte du CSV
serait une régression sur un bug déjà payé.

Or le bloc CSV persiste avec `save_ug_data(pid, out$projet)` **seul** (l. 2534),
puis recharge. Il lui faut donc **aussi** l'écriture des parcelles quand la
purge a mordu.

## Ce qu'il reste à décider, et qui ne m'appartient pas

**La purge doit-elle s'appliquer sans que l'utilisateur l'ait demandée sur ce
chemin ?** Le bouton ONF expose une coche ; l'import CSV, lui, n'en propose
aucune — il utiliserait donc `cfg_csv$purger`, c'est-à-dire le réglage **persisté
du projet**. Deux lectures défendables :

* **Cohérente** — le réglage vaut pour le projet, quel que soit le chemin qui
  crée les UGF. C'est ce que la présence de `cfg_csv` suggère déjà.
* **Prudente** — un import CSV est une création de projet *entier* ; supprimer
  des parcelles que l'utilisateur vient de fournir dans son fichier peut
  surprendre, même si elles sont hors forêt publique. Un compte rendu explicite
  (« N parcelles retirées, hors forêt publique ») serait alors le minimum.

Je penche pour la première, avec la notification de la seconde — mais c'est un
choix d'usage, pas une question technique.

## Vérification

| Contrôle | Attendu |
|---|---|
| Import de `couchey-21200.csv`, réglage projet « purger » actif | plus d'UGF « Hors forêt publique » dans le Tableau UGF ni sur la Carte UGF |
| Onglet Sélection après l'import purgé | les parcelles retirées **n'y sont plus** (régression v0.130.7) |
| Rechargement du projet | elles ne réapparaissent pas — c'est le test qui distingue le correctif complet du naïf |
| Réglage « purger » inactif | le reste subsiste, et c'est le comportement voulu |
| Invariant de pavage | `validate_tiling()` passe dans les deux cas |

## Contournement en attendant

Dans l'onglet Carte UGF, relancer « Créer les UGF avec le parcellaire ONF » avec
la coche de suppression : le même croisement s'exécute, suivi cette fois de la
purge — et du `with_parcels` qui va avec.
