# Spec 072 -- extension : actions candidates (section 15)

**Version** : 0.1.0
**Date**    : 2026-11-28 (mission 104)
**Statut**  : **Proposee**, a valider par Pascal. La matrice signal-action est **provisoire** : un forestier doit la relire avant
toute mise en service (relecture a la charge de Pascal, non faite).
**Origine** : `brief-nemetonshiny.md`, partie B, B2 (etage 2), B3 a B7, que le brief demande « a ajouter au coeur (extension de la
spec 072) ». Les etages 3 (LLM, profils) et 4 (validation) restent cote application (mission 105).

Cette extension suit la numerotation de `spec.md` : c'est son **section 15**. Elle reprend B2 a B7 en termes de coeur.

## 15.1 Principe

L'etage 2 fonctionne **sans LLM**. Du diagnostic P4 (`indicateur_p4_rendement_net()`), du statut Pareto (`p4_pareto()`) et du
risque de ruine (`p4_ruine_foret()`), il produit des actions candidates, au plus trois options chiffrees par UGF, une priorite
deterministe et le contexte structure que l'application donnera au LLM. Le plan degrade (candidates classees, sans redaction) est le
repli quand l'API est indisponible. Rien n'est inscrit au plan sans validation de l'utilisateur : le statut `proposee` est pose cote
application.

## 15.2 Fichier de regles `inst/extdata/p4_regles_actions.yml`

`provisoire: true`, surchargeable par projet : `p4_regles_actions(fichier, surcharge)` lit et valide ; `p4_valider_regles_actions(r)`
valide une liste (classe d'erreur **`nemeton_p4_regles_invalides`**).

| Cle | Contenu | Valeur de depart |
|---|---|---|
| `version`, `provisoire` | version du fichier, drapeau | 1, `true` |
| `seuil_alea` | une action d'alea n'est ajoutee que si la perte de cet alea depasse ce seuil | 0,005 (0,5 point) |
| `ndp_min_decision` | sous ce NDP : acquisition seulement (garde 4) | 3 |
| `vocations_recolte` | seules vocations ou P4 peut motiver une coupe (garde 1) | production, mixte |
| `bornes_prelevement` | `coupe_rase` (doit rester `false`), `prelevement_max_part_capital` (garde 5) | false, 0,25 |
| `axes_proteges_vocation`, `axes_proteges_mode` | familles protegees par vocation ; `ecarter` ou `arbitrage` (garde 2) | provisoire |
| `regles_decision` | liste `{id, decision, pareto, actions}` : B3, premier tableau, decision x Pareto | D1, D2, D3a, D3b, D4 |
| `acquisition` | action unique du signal seulement | S1 |
| `concentrante` | actions de l'UGF concentrante d'un alea en depassement | C1 |
| `regles_alea` | par alea : actions (B3, second tableau) | A_tempete, A_secheresse, A_incendie, A_abroutissement |
| `options` | `declencheurs`, et pour `conserver`, `intervenir`, `convertir` : `entrees`, `effets` qualitatifs par famille (B4) | hypotheses d'expert |

Une action : `{id, tableau (coupes, travaux, aucun), recolte (vrai/faux), libelle}`. `id` : snake_case ASCII unique dans tout le
fichier (l'application le traduit). Une `recolte` n'existe que dans le tableau `coupes`. Le validateur exige aussi que chaque couple
decision x statut Pareto (`domine`, `non_domine`) soit couvert **exactement une fois**, que `conserver` laisse les entrees de P4
inchangees (c'est le statu quo : son `p4_net_apres` est le P4 actuel), que les prelevements respectent la borne et que `coupe_rase`
soit `false`. Les lettres de famille sont entre guillemets dans le YAML (en YAML 1.1, `N` seul vaut faux).

## 15.3 Fonctions exportees

| Fonction | Entrees | Sortie |
|---|---|---|
| `p4_actions_candidates(ugf_p4, pareto, ruine, regles, parametres, id_field, vocation_field, garde_profil)` | sortie de `indicateur_p4_rendement_net()` ; `pareto` : sortie de `p4_pareto()` ou un statut par UGF ; `ruine` : sortie de `p4_ruine_foret()` | une ligne par UGF et par action : `ugf`, `action_id`, `regle`, `origine` (decision, alea, concentrante, signal), `alea`, `tableau`, `recolte`, `libelle`, valeurs P4 utilisees, `version_parametres`, `version_regles`, `regles_provisoires` ; attribut `ecartees` (candidates retirees et garde qui les a retirees) |
| `p4_options(ugf_p4, regles, ruine, axes, axes_proteges_profil, parametres, ..., garde_profil)` | idem ; `axes` : colonnes d'axes de Pareto (colonnes `famille_*` ou lettres) | une ligne par UGF et par option : entrees modifiees, `p4_net_avant`, `p4_net_apres`, `delta_p4`, `p4_ecart_apres`, `effet_<lettre>`, `cout_indicatif_eur_ha` (`NA` : aucun parametre de cout), `dominee`, `dominee_par`, `statut`, `arbitrage_axes`, `garde`, versions |
| `p4_prioriser(ugf_p4, pareto, ruine, parametres, ...)` | idem | liste : `ugf` (toutes les UGF), `principale` (classement), `concentrantes`, `acquisitions` |
| `p4_contexte_llm(ugf_p4, pareto, ruine, regles, axes, ...)` | idem, plus les trois sorties precedentes si on les a deja | une liste par UGF au format de B7 |
| `p4_regles_actions()`, `p4_valider_regles_actions()` | voir 15.2 | regles validees |

**Candidates.** Pour chaque UGF dont P4 est calcule :
1. signal seulement (`p4_signal_seulement` ou NDP sous `ndp_min_decision`) : la seule action `inventaire_terrain`, rien d'autre ;
2. sinon : la ou les regles de `regles_decision` pour (decision, statut Pareto) -- un statut Pareto absent est traite comme
   `non_domine`, donc sans coupe automatique ; une regle `regles_alea` pour **chaque alea dont `p4_perte_<alea>` depasse
   `seuil_alea`** (le tableau B3 est lu par alea ; une UGF peut donc en avoir deux, comme l'UGF 3 : secheresse et tempete) ; la regle
   `concentrante` si l'UGF est la premiere UGF d'un alea dont `exposition_depassee` est vrai (`p4_ruine_foret()`).

**Options.** Une UGF recoit des options si elle n'est pas en signal seulement et si sa decision est `recolter` ou `surveiller`
(declencheur `decisions`), ou si un alea la marque (`alea`), ou si elle est concentrante (`concentrante`). Chaque option **recalcule**
`P4` par `indicateur_p4_rendement_net()` sur des entrees modifiees : `delta_score_alea_dominant` points ajoutes a `R*_norm` de l'alea
dominant (plafonne a 100), `prelevement_capital` (part du capital prelevee), `facteur_gain` (multiplicateur de `gain_valeur`). C'est la
reponse retenue a la question ouverte 4 (simple modification des entrees, pas de simulateur de croissance). Une option est
**dominee** si une autre option de la meme UGF est au moins aussi bonne sur `p4_net_apres` et sur chaque effet qualitatif
(`+` > `0` > `-`) des axes, strictement meilleure sur un.

**Priorite** (B5), deterministe, que le LLM ne modifie pas :
```
manque_a_gagner = max(0, -ecart - seuil_decision) * capital * surface        EUR/an
priorite        = manque_a_gagner * confiance_ndp                            (confiance de get_ndp_confidence())
```
Le rang va de 1 a n pour les UGF a decision fiable (hors signal seulement) dont la priorite est strictement positive, par priorite
decroissante ; **a priorite egale, l'UGF dominee (Pareto) passe devant**. Trois listes a part : le classement (`principale`), les UGF
concentrantes d'un alea en depassement classees par perte de sinistre decroissante (`concentrantes`), les acquisitions des UGF en
signal seulement, celles dont la decision P4 est `recolter` d'abord car elles conditionnent une coupe (`acquisitions`).

**Contexte LLM** (B7). Par UGF : `ugf`, `vocation`, `p4` (rendement brut, pertes attendues, rendement net, taux exige, ecart,
decision, alea dominant, ndp, signal seulement), `pareto` (statut, axes, `dominee_par`), `priorite` (rang, manque a gagner),
`concentrante` (aleas), `actions` (identifiants), `options` (**seulement les options retenables** : identifiant, `p4_net_apres`,
effets), `regles` (versions, drapeau provisoire). **Aucun texte libre issu des donnees** : seuls figurent des nombres, des
identifiants fixes des regles, des listes fermees (vocations, decisions, aleas) et l'identifiant de l'UGF, remplace par `ugf_<n>`
s'il n'est pas un libelle court (lettres, chiffres, espace, point, tiret, souligne ; 40 caracteres au plus).

## 15.4 Garde-fous (B6)

| Garde | Ou | Effet |
|---|---|---|
| 1 Vocation | `p4_actions_candidates()` | une action `recolte` hors `vocations_recolte` est retiree (`ecartees`, garde `vocation`) ; pour une option, `intervenir` bascule sur sa variante `sans_recolte` (garde `vocation_sans_recolte`) |
| 2 Axes proteges | `p4_options()` | une option notee `-` sur un axe protege de la vocation (ou de `axes_proteges_profil`) est `ecartee_axe_protege`, ou, en mode `arbitrage`, gardee avec ses axes dans `arbitrage_axes` ; jamais retenue en silence |
| 3 Seuils d'alerte des profils | **application** | expose comme parametre `garde_profil` (fonction de la table, une valeur logique par ligne, `TRUE` = garder) ; raison `profil` / statut `ecartee_profil` |
| 4 Precision | `p4_actions_candidates()`, `p4_options()` | sous le NDP minimum : acquisition seule, aucune option ; toute action de recolte retiree (garde `precision`) |
| 5 Ampleur | `p4_options()`, validateur | pas de coupe rase (`coupe_rase` doit etre `false`), prelevement borne par `prelevement_max_part_capital` |
| 6 Tracabilite | toutes les sorties | chaque action et option garde la regle qui l'a produite, les valeurs P4 utilisees, `version_parametres`, `version_regles` et le drapeau `regles_provisoires` |

## 15.5 Resultats sur la foret de reference (section 10, NDP 3)

| UGF | Attendu | Obtenu |
|---|---|---|
| 1 | capitaliser, travaux d'amelioration, pas de coupe ; concentrante de la tempete | exact ; actions d'alea tempete et secheresse en plus (pertes 0,60 et 0,66 point, au-dessus de 0,5) |
| 2 | equilibre, coupe d'accroissement, priorite nulle | exact ; aucune option |
| 3 | rang 1, 617 EUR/an, trois options, alea secheresse et tempete | rang 1 ; **617,4 EUR/an** (0,9355 point x 66 000 ; le brief arrondit 0,9355 a 0,935 et lit 617,1) ; trois options, dont le statu quo **dominee** par `convertir` avec les valeurs provisoires |
| 4 | equilibre, protection : aucune coupe | exact (la coupe d'accroissement est retiree par la garde 1) |
| 5 | equilibre, naturalite : aucune coupe | exact (idem, plus la recolte sanitaire et l'adaptation de la densite) |

## 15.6 Questions ouvertes (notees, non tranchees)

Les six questions du brief (partie B, « Questions ouvertes ») restent ouvertes ; ce qui suit dit ce que cette extension a du
supposer pour avancer, **sans trancher** :

1. *Structure d'une action dans le plan* : cote application ; le cœur ne rend que la table de 15.3, a mapper.
2. *Liste ou libre proposition du LLM* : l'extension suppose le passage a une liste de candidates (c'est le principe du brief).
3. *Qui relit la matrice, sur quels referentiels regionaux* : non fait. Toutes les valeurs de `p4_regles_actions.yml` (regles,
   effets `+`/`0`/`-`, `delta_score_alea_dominant`, `prelevement_capital`, `facteur_gain`, axes proteges, borne de 25 %) sont des
   hypotheses du developpeur, pas des valeurs sylvicoles.
4. *Effet d'une option sur P4* : provisoirement une modification des entrees (15.3). Une UGF avec `perte_saisie` garde sa perte
   saisie : le gain de score sur l'alea dominant n'a pas d'effet sur elle.
5. *Seuil de manque a gagner sous lequel aucune action P4 n'est proposee* : aucun seuil n'est pose ; seul `seuil_decision` joue.
6. *Conflits entre profils* : hors du coeur.

Questions de sens soulevees par l'implementation, pour Pascal :
- **A.** Le tableau B3 « selon l'alea dominant » est lu **par alea au-dessus du seuil**, non pour le seul alea dominant (l'UGF 3 du
  brief attend deux aleas). Faut-il se limiter a l'alea dominant ?
- **B.** Une option dominee est ecartee, y compris le statu quo `conserver` (cas de l'UGF 3, 5). Faut-il toujours garder `conserver` ?
- **C.** Axes proteges : `ecarter` (defaut) ou `arbitrage` ? Quelles familles par vocation ?
- **D.** Signal seulement : acquisition **seule** (le brief B3 et ses tests) ou aussi suivi sans recolte (le brief B6.4 l'autorise) ?
- **E.** Un statut Pareto inconnu vaut `non_domine` (pas de coupe automatique) : convient-il ?
- **F.** Manque a gagner : `max(0, -ecart - seuil)` utilise le seuil de decision du fichier de parametres (0,5 point).
