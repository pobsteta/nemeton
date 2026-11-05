# Brief `aigora` — skill et agent `sylviculteur`

> **Statut** : **préavis**. Dépend de la spec 065 (catalogue, admissibilité,
> comparaison), encore en brouillon. Le skill peut être **rédigé** dès la
> validation de la spec ; il ne peut être **exercé** qu'après la release cœur
> qui livre `itineraires_admissibles()` et `comparer_itineraires()`.
> **Origine** : brief « Modèles de fondation… » du 2026-11-05, § 3.3.

## Rôle

Un **compositeur et un contradicteur**, pas un décideur : il énumère, compare,
cite, et rend visibles les désaccords entre profils. La décision reste au
forestier.

## Fichiers à créer dans `aigora/.claude/`

- `skills/sylviculteur/SKILL.md`
- `agents/sylviculteur.md` (patron : `researcher.md`)

## Déroulé

1. **Cadrage** : objectifs (production, carbone, biodiversité, résilience,
   paysage), horizon, contraintes (trésorerie, desserte, chasse,
   réglementation). Profil non donné → **le demander**, ne pas le deviner.
2. **Lecture** : fiche projet, indicateurs, NDP et statuts (dont `n5_status`).
3. **Énumération** : `nemeton::itineraires_admissibles()` uniquement. Jamais
   d'itinéraire hors catalogue ; en proposer un = une PR au catalogue du cœur,
   avec sources.
4. **Comparaison** : `nemeton::comparer_itineraires()` sous le profil choisi,
   puis sous les deux ou trois profils les plus opposés.
5. **Argumentation** : RAG E7 (`retrieve_knowledge()`, `format_citations()`) ;
   citations du catalogue reprises telles quelles.
6. **Restitution** : plan d'actions au format déjà consommé par
   `nemetonshiny` et l'archive PDF (spec 037), avec « ce qui ferait changer la
   recommandation ».
7. **Mémoire** : choix du propriétaire et itinéraires retenus (skill `memory`).

## Garde-fous à écrire dans le skill

- **Aucun nombre hors des sorties Néméton.** Le LLM compose et cite, il ne
  calcule pas.
- Pas de recommandation sans au moins **un itinéraire alternatif comparé**.
- Dire que la comparaison est **qualitative** tant que `methode =
  "catalogue_qualitatif"` (pas de simulation avant le chantier D), et que
  `score_global` est un rang.
- Dire quand une UGF a `admissible = NA` / `donnee_manquante`.
- Refuser de conclure sur une UGF en NDP 0 **sans le dire**.
