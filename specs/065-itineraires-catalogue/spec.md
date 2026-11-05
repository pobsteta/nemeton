# Spec 065 — Catalogue d'itinéraires sylvicoles, admissibilité et comparaison (sans simulation)

> **Statut** : **brouillon, à valider par Pascal**. Rien n'est implémenté avant
> validation (brief § 5.5).
> **Origine** : brief « Modèles de fondation et raisonnement sylvicole dans
> l'écosystème Néméton » du 2026-11-05, § 3.2 et étape 4 du § 4.
> **Dépôts** : `nemeton` (cœur, ce qui calcule) ; `aigora` (agent, ce qui
> raisonne) et `victor` (voix) par briefs dérivés.
> **Décisions ouvertes** : § 8, renvoyées par **[D-n]**.

## 1. Pourquoi, et pourquoi avant FINN

La question du brief : l'IA peut-elle raisonner sur les itinéraires
sylvicoles possibles et souhaitables ? Oui, à une condition : **le moteur est
déterministe et vit dans le cœur**, l'agent ne fait qu'énumérer, comparer,
citer. Cette spec livre le moteur **sans simulation** :

- un **catalogue** d'itinéraires décrits par des règles paramétrées et
  sourcées ;
- un **filtre d'admissibilité** par UGF, qui dit pourquoi chaque itinéraire
  est exclu ;
- un **comparateur** qui classe les itinéraires admissibles sous les poids
  d'un profil, et rend gagnants, perdants, incertitude et citations.

Placer cette étape avant FINN (chantier D) a un but précis : **fixer les
contrats d'interface** (§ 6) que FINN remplira ensuite avec des trajectoires
chiffrées. La sortie change de contenu, pas de forme.

## 2. Ce que le cœur a déjà (vérifié le 2026-11-05)

| Brique | Où | Utilisation ici |
|---|---|---|
| Front de Pareto | `identify_pareto_optimal(data, objectives, maximize)` (`R/analysis-pareto.R`) | réutilisée telle quelle sur une table d'itinéraires au lieu d'une table d'UGF |
| Trade-offs | `plot_tradeoff()` (`R/analysis-tradeoff.R`) | figure du rapport |
| Station | P2, `compute_site_index()`, `ifn_production_ser()` | filtre de fertilité |
| Essences | `get_species_config()`, `european_species_tolerances()` | essences objectif admissibles |
| Contraintes réglementaires | couche des aires protégées de B1 et ses codes de type (`rnn`, `rb`, `coeur`, `apb`, `natura`, … — `protection_weights` dans `R/indicators-biodiversity.R`) | exclusions. B1 rend un **score**, pas un type : le filtre relit la couche, avec les mêmes codes |
| Régénération | `indice_priorite_regen()`, `regen_species_choices()` | itinéraires de plantation / diversification |
| Densité, croissance | `n_max_selfthinning()`, `bai_drift_factor()` | réservées au chantier D |

**Ce que le cœur n'a pas** :

- **les profils experts** : les 13 profils YAML vivent dans
  `nemetonshiny/inst/experts/`. Le cœur ne peut pas les lire (règle stricte
  n° 8 : pas de dépendance inverse). **[D-1]**
- **`yaml`** : absent de DESCRIPTION. Les catalogues du cœur sont en JSON
  (`inst/datasources/*.json`) ou en CSV. **[D-2]**
- **`foretaccess`** : la desserte n'est pas une dépendance du cœur. Le filtre
  lit une colonne de desserte déjà présente sur les UGF, il n'appelle pas
  `foretaccess`. **[D-3]**

## 3. Le catalogue

Fichier `inst/extdata/itineraires_sylvicoles.json` (ou `.yml`, D-2),
accesseur `itineraires_catalogue()`, schéma validé par
`valider_catalogue_itineraires()` (test unitaire sur le fichier livré).

Familles d'itinéraires visées (brief § 3.2) : futaie régulière (par essence
et classe de fertilité), futaie irrégulière Pro Silva, taillis-sous-futaie,
libre évolution, conversion, îlots de sénescence, plantation avec essences
de diversification.

Chaque entrée :

```json
{
  "code": "fr_chene_sessile_fertilite_1",
  "famille_itineraire": "futaie_reguliere",
  "libelle": {"fr": "...", "en": "..."},
  "domaine": {
    "essences_objectif": ["QUPE"],
    "ser": null,
    "p2_min": 28, "p2_max": null,
    "pente_max_pct": 45,
    "desserte_requise": true,
    "protections_exclues": ["rb", "coeur"]
  },
  "regles": {
    "rotation_ans": [180, 220],
    "diametre_exploitabilite_cm": [60, 70],
    "surface_terriere_cible_m2ha": null,
    "intensite_prelevement_pct": [15, 25]
  },
  "effets_attendus": {
    "P": {"sens": "+", "horizon": "long", "source": "..."},
    "N": {"sens": "-", "horizon": "long", "source": "..."}
  },
  "sources": [{"ref": "ONF, Guide des sylvicultures ...", "pages": "..."}],
  "statut_source": "source"
}
```

**Règle de sourçage, non négociable** : un paramètre numérique sans
référence n'entre pas dans le catalogue. Une entrée dont une règle n'est pas
encore sourcée porte `statut_source = "a_sourcer"` et **n'est jamais rendue
admissible**. Le premier remplissage est fait par Pascal ou relu par lui
ligne à ligne ; Claude ne propose pas de valeurs de rotation ou de diamètre de
mémoire. **[D-4]** périmètre du premier catalogue.

**`effets_attendus`** : sans FINN, l'effet d'un itinéraire sur une famille est
**qualitatif** (`+`, `0`, `-`, `?`) et sourcé. C'est ce qui rend la
comparaison possible sans simulation ; c'est aussi sa limite, écrite dans la
sortie (`methode = "catalogue_qualitatif"`). **[D-5]**

## 4. `itineraires_admissibles(units, catalogue = itineraires_catalogue(), desserte = NULL)`

Pour chaque UGF et chaque itinéraire du catalogue, une ligne :

| Colonne | Contenu |
|---|---|
| `unit_id`, `itineraire` | clés |
| `admissible` | logique |
| `raison` | code d'exclusion, `NA` si admissible |
| `detail` | valeur observée face au seuil (« pente 62 % > 45 % ») |

Codes d'exclusion (fermés, testés un par un) : `station_insuffisante` (P2),
`hors_ser`, `essence_absente`, `pente`, `desserte`, `statut_protection` (intersection
avec une aire protégée dont le code figure dans `protections_exclues`),
`source_manquante` (statut `a_sourcer`), `donnee_manquante` (la colonne
nécessaire est `NA` : **l'itinéraire n'est ni admis ni exclu en silence**, il
est rendu avec cette raison).

Rend un `data.frame` long, pas un `sf` : ce n'est pas un indicateur, le
contrat § 1 de la spec 057 ne s'applique pas.

## 5. `comparer_itineraires(units, itineraires = NULL, poids, reference = "statu_quo")`

- `itineraires` : par défaut, les admissibles de l'UGF.
- `poids` : vecteur nommé de poids par famille (`c(P = 3, B = 2, ...)`). Voir
  D-1 pour leur origine.
- `reference` : itinéraire de comparaison. Les gagnants et perdants n'ont de
  sens que **par rapport à quelque chose**. **[D-6]**

Sortie, une ligne par UGF × itinéraire :

| Colonne | Contenu |
|---|---|
| `itineraire` | code |
| `score_global` | somme pondérée des effets (`+` = 1, `0` = 0, `-` = −1), sur [−1, 1] ; `NA` si une famille de poids non nul a un effet `?` |
| `pareto` | issu de `identify_pareto_optimal()` sur les effets par famille |
| `familles_gagnantes`, `familles_perdantes` | face à `reference` |
| `incertitude` | `"qualitative"` dans cette spec ; intervalle numérique avec FINN |
| `methode` | `"catalogue_qualitatif"` ; `"finn"` au chantier D |
| `citations` | références du catalogue, au format de `format_citations()` (RAG E7) |

`score_global` est un **ordre**, pas une mesure : la fiche le dit, et l'app
comme l'agent l'affichent comme un rang.

## 6. Contrats d'interface laissés à FINN (chantier D)

Fixés ici pour ne pas changer de forme plus tard :

- `simuler_itineraire(units, itineraire, horizon = c(20, 50, 100), n = 100)`
  rendra une table longue `unit_id × itineraire × horizon × indicateur` avec
  `valeur`, `bas`, `haut`, `methode`. **Non livrée dans cette spec.**
- `comparer_itineraires()` acceptera `trajectoires =` (sortie de
  `simuler_itineraire()`) ; alors `methode = "finn"` et `incertitude` devient
  numérique. Les colonnes du § 5 ne changent pas.
- `effet_gestion()` (chantier D) : hors périmètre.

## 7. Couches 2 et 3 (briefs dérivés, aucun code dans ce dépôt)

- **Aigora** : skill + agent `sylviculteur` (`brief-aigora.md`). Il appelle
  uniquement les fonctions des § 3 à 5 et leurs sorties ; garde-fous du brief
  § 3.3 recopiés tels quels.
- **Victor** : outil `nemeton_itineraires(projet, ugf)` (lecture des
  admissibles) et délégation à `aigora` pour la comparaison longue
  (`brief-victor.md`).
- **App** : vue « itinéraires » dans l'onglet plan d'actions
  (`brief-nemetonshiny.md`).

## 8. Décisions ouvertes (à arbitrer par Pascal)

| # | Question | Proposition |
|---|---|---|
| D-1 | Les poids des profils : le brief fait lire les 13 profils YAML par le cœur, qui ne le peut pas (dépendance inverse). | (a) le cœur prend un vecteur `poids`, l'app et l'agent le dérivent du profil ; **ou** (b) les poids par famille (pas les prompts) migrent dans le cœur, `inst/extdata/profils_poids.json`, puisque c'est de la logique métier (règle stricte n° 1). Proposition : **(b)**, l'app garde prompts et libellés |
| D-2 | Format du catalogue : YAML (brief) impose `yaml` en Imports ; JSON est déjà lu par `jsonlite`. | JSON, pour ne rien ajouter ; YAML seulement si Pascal veut éditer le catalogue à la main en priorité |
| D-3 | Desserte : appeler `foretaccess` depuis le cœur, ou lire une colonne déjà calculée ? | colonne (`desserte_m`, distance de débardage) fournie par l'appelant ; `NA` → `donnee_manquante` |
| D-4 | Périmètre du premier catalogue | BFC d'abord : chêne sessile, hêtre, sapin, épicéa, douglas en futaie régulière ; futaie irrégulière Pro Silva ; TSF ; libre évolution ; îlots de sénescence. ~12 entrées, sourcées par Pascal |
| D-5 | Effets qualitatifs `+ / 0 / - / ?` par famille et horizon : acceptables comme base de comparaison sans simulation ? | oui, avec `methode` affichée partout et le score présenté comme un rang |
| D-6 | Itinéraire de référence pour gagnants / perdants | `statu_quo` = itinéraire déclaré de l'UGF quand il existe, sinon le meilleur `score_global` sous le profil |
| D-7 | Granularité | UGF par UGF ; l'agrégation au massif est laissée à l'agent / à l'app |

## 9. Critères d'acceptation

1. Catalogue livré validé par `valider_catalogue_itineraires()` ; aucune
   entrée `source` sans référence (test).
2. `itineraires_admissibles()` rend **chaque** code d'exclusion sur une
   fixture dédiée, et `donnee_manquante` quand une colonne est `NA` (jamais
   un itinéraire admis par défaut).
3. `comparer_itineraires()` sur `massif_demo_units` sous deux jeux de poids
   opposés (production / naturaliste) : le classement change, les citations
   sont présentes sur chaque ligne.
4. Fiche « itinéraires » (pièges : effets qualitatifs, catalogue non
   exhaustif, l'admissibilité n'est pas une recommandation).
5. Contrat du § 6 écrit dans la doc roxygen de `comparer_itineraires()`.

## 10. Écarts cœur → app ouverts dès maintenant

Inscrits dans PLAN.md (n° 23 et 24) **avant** la première release : vue des
itinéraires admissibles avec raisons d'exclusion ; table de comparaison
pondérée par le profil (et origine des poids, D-1).
