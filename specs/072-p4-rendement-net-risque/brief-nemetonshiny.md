# BRIEF `nemetonshiny` — P4 : exposition et plan d'actions

**Dépôt cible** : `nemetonshiny`. Session dédiée requise : ce brief est livré côté cœur (règle 11), rien n'a été modifié dans l'app.

**Origine** : spec 072 (`spec.md`, même dossier). Suppose la spec réalisée jusqu'au jalon M2.

**Statut** : **Proposé**, à valider par Pascal. Rédigé sans lecture du code de l'app : les noms de fichiers cités (`service_action_plan.R`, `R/llm_prompts.R`, `inst/experts/*.yml`) sont à vérifier.

---

## 0. Consignes à lire avant de coder

1. **Lire le code existant avant d'écrire** : le service du plan d'actions, les profils experts, le service de synthèse LLM.
2. **Aucune logique métier dans l'app.** Le calcul de P4, la synthèse forêt, le statut Pareto et le moteur de règles vivent dans `nemeton`. L'app appelle, affiche et recueille la validation.
3. **Le LLM ne calcule pas et ne décide pas seul.** Les chiffres, le classement des priorités et la liste des actions candidates sont produits par du code déterministe. Le LLM choisit parmi les candidates, rédige, justifie et signale les conflits.
4. **L'utilisateur valide.** Toute action sort au statut `proposee`. Rien n'est inscrit au plan sans validation.
5. **Ne pas toucher au versionnage du plan d'actions sans migration** : tout champ ajouté passe par un incrément de version du schéma et un test d'aller-retour.
6. **Aucune règle sylvicole en dur.** La matrice signal-action vit dans un fichier YAML marqué `provisoire: true`, relu par un forestier avant mise en service.
7. **P4 sous NDP 3 est un signal, pas une décision.** Aucune coupe n'est proposée sur la seule foi d'un P4 marqué `p4_signal_seulement`.
8. **Jamais de coupe rase déduite de P4 seul**, et jamais de récolte motivée par P4 sur une UGF de vocation protection, accueil ou naturalité.
9. Textes d'interface par `i18n$t()`, FR et EN.

## Partie A — Exposer P4

### A1. Champs par UGF

Deux champs nouveaux : `vocation` (liste fermée : production, mixte, protection, accueil, naturalité) et `perte_saisie` (proportion par an, facultative). Toute évolution du format des données UG commence par un test d'aller-retour sauvegarde-chargement, avec une version de schéma lue et stricte.

### A2. Affichage

- **Détail de la famille P** : le rendement brut partagé entre rendement net et pertes attendues, le taux exigé de la vocation, la décision, l'aléa dominant, le drapeau de précision.
- **Synthèse** : rendement net de la forêt, part du capital à écart négatif, pertes attendues en €/an, aléa dominant.
- **Pareto** : statut dominé ou non dominé par UGF, sur P4 et les axes retenus.
- **Risque de ruine** (spec 072 § 7 bis) : par aléa, la perte en cas de sinistre majeur en part du capital et en années de gain net, la probabilité sur l'horizon, l'UGF concentrante, et le dépassement du plafond d'exposition. Le rendement géométrique s'affiche à côté du rendement net.
- Un P4 marqué « signal seulement » s'affiche comme tel, sans décision de coupe.

### A3. i18n et export

Clés FR et EN pour l'indicateur, les quatre décisions, les cinq vocations et les quatre aléas. Colonnes P4 dans le GeoPackage et le rapport Quarto.

## Partie B — Plan d'actions piloté par P4

### B1. Objet

Faire en sorte que le plan d'actions généré par l'IA tienne compte du résultat économique de chaque UGF.

| Apport de P4 | Usage |
|---|---|
| Écart au taux exigé | dit s'il faut capitaliser, prélever l'accroissement ou décapitaliser |
| Aléa dominant | oriente le type de travaux |
| Statut Pareto | distingue l'UGF qui paie d'autres services de celle qui est réellement inefficace |
| Manque à gagner en €/an | classe les priorités sur une base objective |
| Précision NDP | dit si l'on peut agir ou s'il faut d'abord mesurer |
| Risque de ruine | signale l'UGF qui concentre la perte potentielle, même si son rendement est bon |

### B2. Architecture en quatre étages

```
 diagnostic P4 ──► actions candidates ──► arbitrage et rédaction ──► validation
 (cœur)            (cœur, règles YAML)    (app, LLM par profil)      (utilisateur)
```

1. **Diagnostic** : sorties P4 par UGF, statut Pareto, synthèse forêt.
2. **Actions candidates** : un moteur de règles applique la matrice B3 et produit, pour chaque UGF, deux ou trois options chiffrées. Il est à ajouter au cœur (extension de la spec 072).
3. **Arbitrage et rédaction** : le LLM reçoit le diagnostic et les options, retient une option par UGF selon le profil d'acteur, rédige la justification, signale les conflits entre profils.
4. **Validation** : l'utilisateur accepte, modifie ou rejette.

L'étage 2 fonctionne sans LLM : le plan dégradé (candidates classées, sans rédaction) est le repli quand l'API est indisponible.

### B3. Matrice signal-action

Valeurs de départ, à faire relire. Fichier `p4_regles_actions.yml`, côté cœur.

**Selon la décision P4 et le statut Pareto**

| Décision | Pareto | Action candidate principale | Tableau |
|---|---|---|---|
| capitaliser | indifférent | pas de coupe au-delà de l'accroissement ; travaux d'amélioration au profit des tiges d'avenir | Travaux |
| equilibre | indifférent | coupe prélevant l'accroissement à la rotation prévue | Coupes |
| recolter | dominée | coupe de décapitalisation ciblée sur les tiges exposées et peu dynamiques ; option de conversion ou de diversification | Coupes, Travaux |
| recolter | non dominée | **pas de coupe automatique** : signaler l'arbitrage, proposer de revoir le taux exigé ou une intervention légère | aucun, note d'arbitrage |
| surveiller | indifférent | suivi sanitaire renforcé, aucune coupe motivée par P4 | Travaux (suivi) |
| toute | signal seulement | acquisition de données : inventaire de terrain avant toute décision de coupe | Travaux (étude) |
| toute | UGF concentrante d'un aléa en dépassement | réduction d'exposition : diversification des essences et des classes de hauteur, étalement des récoltes, sans récolte motivée par ce seul signal hors vocation production ou mixte | Travaux, note d'arbitrage |

**Selon l'aléa dominant**

| Aléa dominant | Actions candidates |
|---|---|
| tempête | éclaircies précoces pour abaisser le rapport H/D, traitement des lisières, récolte anticipée des peuplements hauts et instables |
| sécheresse et sanitaire | diversification des essences, récolte sanitaire, suivi sanitaire (spec 008), adaptation de la densité |
| incendie | travaux de défense contre l'incendie, entretien des accès et des coupures |
| abroutissement | protections, suivi de la régénération, concertation sur le plan de chasse (profil chasseur) |

Une action d'aléa ne s'ajoute que si la perte de cet aléa dépasse un seuil (paramètre, 0,5 point par défaut).

### B4. Options et front de décision

Pour chaque UGF sous le seuil ou marquée par un aléa, le moteur génère au plus trois options : **conserver**, **intervenir**, **convertir**. Chaque option porte :

- son effet estimé sur P4, calculé par le code de P4 avec des entrées modifiées ;
- son effet qualitatif sur les axes retenus pour Pareto : `+`, `0` ou `−`, lu dans le fichier de règles ;
- son coût ou sa recette indicative, si les paramètres existent.

Les options dominées sont écartées avant l'appel au LLM. Le LLM n'arbitre qu'entre options non dominées : c'est là que le profil d'acteur a un rôle légitime. Les effets qualitatifs sont des hypothèses d'expert marquées provisoires, jamais présentées comme des mesures.

### B5. Priorisation

Le classement est déterministe et n'est pas modifiable par le LLM.

```
manque_a_gagner = max(0, −ecart − seuil) × capital × surface      en €/an
priorite        = manque_a_gagner × confiance_ndp
```

À manque à gagner égal, l'UGF dominée passe devant. Les UGF concentrantes d'un aléa en dépassement forment une seconde liste, classée par perte de sinistre décroissante : elle n'est pas fondue dans la première, car elle répond à une autre question. Les actions d'acquisition de données sont classées à part, en tête quand elles conditionnent une décision de coupe.

### B6. Garde-fous

1. **Vocation** : aucune coupe motivée par P4 hors vocation production ou mixte.
2. **Axes protégés** : une option notée `−` sur un axe prioritaire de la vocation ou du profil est écartée, ou présentée comme arbitrage explicite, jamais retenue en silence.
3. **Seuils d'alerte des profils** : les seuils définis dans les profils experts priment sur P4.
4. **Précision** : sous NDP 3, seules des actions d'acquisition, de suivi ou de travaux sans récolte sont proposées.
5. **Ampleur** : pas de coupe rase issue de ces règles ; les prélèvements restent dans les bornes du fichier de règles.
6. **Traçabilité** : chaque action garde la règle qui l'a produite, les valeurs P4 utilisées et la version des paramètres.

### B7. Contexte transmis au LLM

Un objet structuré par UGF, sans texte libre issu de données externes.

```json
{
  "ugf": "UGF 3",
  "vocation": "production",
  "p4": {"rendement_brut": 0.0345, "pertes_attendues": 0.0189, "rendement_net": 0.0156,
         "taux_exige": 0.03, "ecart": -0.0144, "decision": "recolter",
         "alea_dominant": "secheresse_sanitaire", "ndp": 3, "signal_seulement": false},
  "pareto": {"statut": "domine", "axes": ["B", "N"], "dominee_par": ["UGF 1", "UGF 2"]},
  "priorite": {"rang": 1, "manque_a_gagner_eur_an": 617},
  "options": [
    {"id": "conserver",  "p4_net_apres": 0.0156, "effets": {"B": "0", "N": "0"}},
    {"id": "intervenir", "p4_net_apres": 0.0240, "effets": {"B": "0", "N": "0"}},
    {"id": "convertir",  "p4_net_apres": 0.0210, "effets": {"B": "+", "N": "+"}}
  ]
}
```

Les valeurs `p4_net_apres` de cet exemple sont illustratives.

### B8. Ajout aux profils experts

Bloc commun, à décliner en FR et EN dans chaque profil :

```yaml
p4:
  regles:
    - Cite les valeurs P4 telles qu'elles sont fournies ; ne recalcule rien.
    - Choisis une seule option par UGF parmi celles proposées ; n'en invente pas.
    - Ne modifie pas l'ordre de priorité ; tu peux le commenter.
    - Si signal_seulement est vrai, dis que la précision ne permet pas de décider et propose de mesurer.
    - Explique l'arbitrage : ce que l'option retenue gagne et ce qu'elle coûte sur les autres axes.
    - Respecte la vocation de l'UGF et les seuils d'alerte de ton profil avant tout argument économique.
  poids_p4: moyen        # fort, moyen, faible selon le profil
```

Le poids exprime l'importance que le profil accorde à l'argument économique dans son choix entre options non dominées. Un profil naturaliste peut le fixer à `faible` : il choisira `convertir` là où un profil industrie du bois choisira `intervenir`, à partir du même diagnostic.

### B9. Sortie attendue du LLM

Sortie structurée, validée contre un schéma ; une réponse non conforme est rejetée et remplacée par le plan dégradé.

| Champ | Contenu |
|---|---|
| `ugf` | identifiant |
| `option` | identifiant d'une option fournie |
| `tableau` | coupes, travaux, aucun |
| `libelle` | intitulé court de l'action |
| `annee` | année ou période proposée |
| `justification` | deux à quatre phrases, chiffres P4 cités |
| `arbitrage` | ce qui est gagné et perdu sur les autres axes |
| `conflit_profils` | profils qui auraient choisi autrement, si connu |
| `statut` | toujours `proposee` |

### B10. Boucle d'évaluation

À chaque nouvel inventaire, comparer le P4 des UGF où une action a été réalisée à leur P4 antérieur, et aux UGF comparables restées sans action. Trois résultats par action : écart avant, écart après, évolution des axes retenus. C'est la seule façon de calibrer les effets qualitatifs de B4.

## Tests

Sur la forêt de référence de la spec 072 (§ 10), LLM simulé :

| UGF | Attendu de l'étage 2 |
|---|---|
| 1 Douglasaie | capitaliser : travaux d'amélioration, pas de coupe au-delà de l'accroissement ; **UGF concentrante** pour la tempête (46,9 % d'une perte de 22,98 % du capital) : action de réduction d'exposition |
| 2 Chênaie irrégulière | équilibre : coupe d'accroissement, priorité nulle |
| 3 Pessière | récolter et dominée : rang 1, manque à gagner 617 €/an (0,935 point × 66 000 €), trois options, actions d'aléa sécheresse et tempête |
| 4 Ripisylve | équilibre, vocation protection : aucune coupe motivée par P4 |
| 5 Vieille hêtraie-chênaie | équilibre, vocation naturalité : aucune coupe motivée par P4 |

Autres tests : repli sans LLM ; rejet d'une sortie non conforme ; option inventée par le LLM refusée ; signal seulement ne produit que des acquisitions ; garde-fou de vocation ; aller-retour du plan avec les nouveaux champs ; traçabilité de la règle et de la version des paramètres.

## Jalons

| Jalon | Livrable | Critère d'acceptation |
|---|---|---|
| A0 | lecture du service de plan d'actions et des profils ; fichier de règles et son validateur | note d'alignement relue ; règles relues par un forestier |
| A1 | partie A : champs UG, affichage, i18n, export | parcours complet sur un projet de démonstration |
| A2 | étages 1 et 2 : candidates, options, priorisation, garde-fous | tableau des tests exact, sans LLM |
| A3 | étage 3 : contexte, bloc profil, sortie structurée, repli | tests LLM simulé verts ; essai réel sur deux profils opposés |
| A4 | validation dans l'application ; champs du plan versionnés ; boucle d'évaluation | comparaison avant-après sur un projet à deux inventaires |

## Questions ouvertes

1. Structure actuelle d'une action dans le plan : quels champs existent, lesquels ajouter ?
2. Le LLM propose-t-il aujourd'hui les actions librement, ou à partir d'une liste ? Ce brief suppose le passage à une liste de candidates.
3. Qui relit la matrice signal-action, et sur quels référentiels sylvicoles régionaux s'appuie-t-elle ?
4. Comment estimer l'effet d'une option sur P4 : simple modification des entrées, ou lien avec un simulateur de croissance ?
5. Faut-il un seuil de manque à gagner sous lequel aucune action P4 n'est proposée ?
6. Les conflits entre profils sont-ils résolus par le LLM, ou seulement exposés à l'utilisateur ?
