# Brief `victor` — outils vocaux pour les itinéraires

> **Statut** : **préavis**. Dépend de la spec 065 (validée le 2026-11-05) et du skill
> `sylviculteur` d'`aigora`. Rien à coder avant la release cœur.
> **Origine** : brief « Modèles de fondation… » du 2026-11-05, § 3.4.

## Outils à ajouter dans `server.py`

1. **`nemeton_itineraires(projet, ugf)`** : lecture immédiate, comme
   `nemeton_fiche`. Appelle `nemeton::itineraires_admissibles()` et rend la
   liste des admissibles et, pour les exclus, la raison (codes fermés de la
   spec 065 § 4).
2. **Délégation à `aigora`** pour « compare les itinéraires de X pour un
   objectif carbone » : tâche longue, retour par `[SYSTÈME]`.

## `display_report`

Deux nouveaux types de bloc :

- `pareto` : nuage des itinéraires (colonnes `itineraire`, `score_global`,
  `pareto` de `comparer_itineraires()`) ;
- `trajectoires` : courbes par itinéraire et par famille — **réservé** au
  chantier D (FINN) ; ne pas l'implémenter avant.

## À voix haute

L'itinéraire retenu, la famille qui gagne, la famille qui perd, puis
« voulez-vous voir les alternatives ? ». Tout le reste va à l'écran. Aucun
nombre prononcé qui ne vienne d'une sortie Néméton ; tant que la comparaison
est qualitative, ne pas lire `score_global` comme une note.
