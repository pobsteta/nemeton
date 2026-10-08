# Spec 058 — UGF d'une forêt publique construites depuis le parcellaire ONF calé sur le cadastre

> **Statut** : livré en v1.1.0, 2026-10-08.
> **Origine** : brief `briefs/vers-nemeton/2026-10-08-ugf-depuis-onf.md`
> (session `nemetonclaude`, règles énoncées et validées par Pascal le
> 2026-10-07/08), copié dans ce dossier (`brief-origine.md`).
> **Brief lié côté app** : `briefs/vers-nemetonshiny/2026-10-08-ugf-depuis-onf.md`
> (stockage du n° ONF dans les UGF, intégration, API d'écriture). Hors de ce dépôt.
> **Version cible** : 1.1.0 (ajout d'API, rien de cassé).

## 1. Règle métier

> Les parcelles forestières ne sont qu'une partition des parcelles cadastrales.
> On part **toujours des parcelles cadastrales**, qu'on agrège et qu'on coupe
> pour obtenir les UGF. Le cadastre n'est **jamais déformé** ; c'est la couche
> ONF, qui déborde, qu'il faut ajuster. (Pascal)

Nouveau chemin « depuis la forêt » : le cœur trouve lui-même les parcelles
cadastrales qui relèvent de la forêt publique et les découpe en UGF numérotées
comme les parcelles forestières ONF.

## 2. Algorithme

Celui du brief, § 3.1 à 3.5, sans changement de règle : candidates PCI touchant
l'union ONF et restreintes à la commune, calage élastique de l'ONF, sélection
DGFiP × couverture ONF calée ≥ 50 %, découpage par accrochage (ouverture
morphologique), rattachements finaux. Les paramètres et leurs valeurs par défaut
sont ceux du brief, § 5.2.

## 3. Décisions prises

| Question ouverte du brief | Décision |
|---|---|
| Nom de la fonction | `construire_ugf_onf()` |
| Calage réutilisable | `caler_onf_sur_cadastre()`, exportée |
| Chargeur DGFiP | `load_parcelles_personnes_morales(insee, fichier = NULL, cache_dir = NULL)` |
| Téléchargement DGFiP | Fichier national gardé **une fois** dans `tools::R_user_dir("nemeton", "cache")/dgfip_personnes_morales/`. URL résolue par l'API data.gouv.fr (jeu `6900772ca5c4fa6c5687b3bd`, ressource `parcelles_personnes_morales_latest.parquet`). Le nom du fichier en cache porte l'horodatage de publication : un nouveau millésime se télécharge à côté, l'ancien est supprimé avec ses extraits. Un **extrait par département** est gardé à côté : le filtre sur le fichier national prend de 1 à 45 s selon l'état du cache disque, l'extrait (5,6 Mo pour le 21) se lit en un instant. Pas d'API par commune trouvée. |
| Injection hors ligne | `construire_ugf_onf()` accepte `parcelles_onf`, `cadastre` et `proprietaires` déjà chargés. Les tests et l'app s'en servent. |
| Option dans `croiser_parcelles_onf()` | Nouvel argument `calage_elastique = FALSE`, indépendant de `caler_sur_cadastre`. Les valeurs par défaut ne changent pas. |
| Statut | `construire_ugf_onf()`, `caler_onf_sur_cadastre()` et `load_parcelles_personnes_morales()` sont **experimental** (semver strict, spec 057). |
| Personne publique | `groupe_personne_code` DGFiP dans 1 (État), 2 (région), 3 (département), 4 (commune), 9 (établissements publics ou organismes associés). Exclus : 0 (personnes morales non remarquables), 5 (offices HLM), 6 (SEM), 7 (copropriétaires), 8 (associés). Une parcelle absente du fichier appartient à une personne physique : privée. |

## 4. Approximation du régime forestier

Ni le PCI ni le cadastre Etalab ne disent qu'une parcelle relève du régime
forestier. La source officielle est l'arrêté préfectoral d'application, qui
n'est pas ouvert parcelle par parcelle. Le croisement « propriétaire public
(DGFiP) × couverture ONF calée ≥ 50 % » en est une **approximation**, documentée
comme telle dans l'aide de `construire_ugf_onf()`.

## 5. Mesures (Couchey, 21200)

| | Prototype | v1.1.0 |
|---|---|---|
| Candidates / retenues | 63 / 19 (493,79 ha) | 63 / 19 (493,79 ha) |
| UGF / `cad~` / tènements / parcelles coupées | 63 / 0 / 85 / 9 | 63 / 0 / 85 / 9 |
| Plus petite UGF | 2,11 ha | 2,11 ha |
| Écart de surface par UGF | — | 0,09 ha au plus, 0,6 ha au total |
| Pavage par parcelle | 0,003 ha (arrondi) | < 10⁻⁵ m² |
| Sommets cadastraux conservés (1 mm) | non mesuré | 1 047 / 1 047 |
| Temps (sources chargées) | ~10 min | 15 s |
| Lecture DGFiP | — | 1,3 s (extrait départemental) |

Deux écarts au prototype, l'un et l'autre pour tenir « le cadastre n'est jamais
déformé » :

1. **Reprojection avant validation.** `st_make_valid()` sur des coordonnées en
   degrés passe par s2, qui déplace les sommets de quelques millimètres (jusqu'à 14 m² d'écart sur A 36). Le PCI arrive en EPSG:4326 : on
   reprojette en Lambert 93 d'abord.
2. **Re-pavage final.** Le découpage travaille au centimètre (`st_set_precision`)
   pour que les morceaux voisins partagent leurs sommets. Mais l'arrondi
   déplace chaque sommet cadastral de quelques millimètres et laissait des
   chevauchements internes (15 m² sur A 36). Les 14 m² d'écart de pavage
   d'abord mesurés sur A 36 venaient, eux, de s2 (point 1). Chaque tènement est
   redécoupé dans la parcelle d'origine ; les interstices et les éclats < 1 m²
   (des triangles de 2 mm de large) rejoignent le tènement de plus longue
   limite commune, après un `st_snap` de 1 mm du tènement sur l'éclat.

## 6. Critères d'acceptation

Ceux du brief, § 7.

## 7. Suite : chemin unique (v1.2.0, 2026-10-08)

Brief `2026-10-08-onf-retrait-ancien-calage` (copié dans
`brief-retrait-ancien-calage.md`). Pascal : *« je ne veux conserver que cette
nouvelle façon de faire »*.

| Point du brief | Décision |
|---|---|
| Retrait de `croiser_parcelles_onf()` | Dépréciation en 1.2.0. Retrait en 2.0, puisque le contrat 057 interdit de retirer une fonction stable en version mineure. Pas de `lifecycle` : l'idiome du paquet (`deprecatedWarning` une fois par session) suffit, avec l'option `nemeton.deprecation_verbosity`. Les helpers `.croiser_*` partent avec elle ; `construire_ugf_onf()` n'en utilise aucun. |
| Multi-communes | `insee` vectoriel, éventuellement sur plusieurs départements ; un seul passage de calage, découpage et rattachement. Déduit de `code_insee` ou de `substr(idu, 1, 5)` quand `cadastre` est fourni. |
| Filtre `code_insee` | Supprimé sur un `cadastre` fourni : c'est la sélection de l'appelant. |
| Parcelles hors ONF | En mode `"foret"`, elles sont rendues dans `attr(x, "parcelles")` avec `raison = "hors ONF"`, `couverture_onf = 0` et leur propriétaire DGFiP. Elles restent hors du calage, si bien que Couchey ne change pas. |
