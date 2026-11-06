# Brief `aigora` — skill et agent `sylviculteur`

> **Statut** : **préavis** ; fonctions du cœur livrées en **2026.11.4** (`itineraires_admissibles()`, `comparer_itineraires()`, `profils_poids()`), catalogue encore vide de sources. Dépend de la spec 065 (catalogue, admissibilité,
> comparaison), validée le 2026-11-05. Le skill peut être **rédigé** dès
> maintenant ; il ne peut être **exercé** qu'après la release cœur
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

## Ajout du 2026-11-06 — résultats du projet que le skill peut citer

Livrés depuis ce préavis (cœur 2026.11.5 à 2026.11.8) :

- **`nemeton::effet_gestion()`** (spec 068) : ce que le type de gestion
  déclaré a produit sur chaque famille du projet, à station comparable.
  À l'étape **Argumentation**, le skill peut le citer comme *résultat du
  projet* (« sur ce massif, les UGF en irrégulier ont un indice de
  biodiversité supérieur de X points, intervalle [a ; b] »), **seulement**
  quand `statut == "calcule"`, toujours avec l'intervalle, et en disant que
  c'est une association ajustée sur la station, pas une preuve causale.
  Statut `recouvrement_insuffisant` ou `trop_peu_unites` : dire que le
  projet ne permet pas de conclure, ne rien citer.
- **Sources des valeurs** : T1 rend `t1_source` (âge relevé, année
  d'installation, âge structurel, BD Forêt, NDVI) ; B5 rend `b5_status` et
  `b5_densite`. Le skill dit d'où vient un âge avant de s'en servir (un âge
  typologique de la BD Forêt n'est pas un âge relevé).
- **Trajectoires** : toujours absentes (FINN, spec 068, étapes 2 à 4) ;
  la comparaison reste qualitative (`methode = "catalogue_qualitatif"`).

Garde-fou ajouté : **ne jamais présenter un effet de gestion comme la
prévision d'un itinéraire**. L'un dit ce qui s'est passé sur le massif,
l'autre ce que le catalogue attend ; s'ils divergent, le dire.
