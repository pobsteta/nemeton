# Spec 072 — P4 : rendement net du risque

**Version** : 0.2.0
**Date**    : 2026-11-28 (§ 7 bis ajouté le même jour)
**Statut**  : **Proposée**, à valider par Pascal. Aucune ligne de code n'est écrite.
**Cible**   : `nemeton` (cœur). Suite côté app : `brief-nemetonshiny.md` (même dossier).

---

## 0. Consignes à lire avant de coder

1. **Vérifié dans le dépôt** (commit `e7eea90`) : `indicateur_p1_volume()` rend `P1` en m³/ha, `indicateur_p2_station()` rend `P2` en m³/ha/an, les colonnes normalisées portent le suffixe `_norm`, le front de Pareto passe par `identify_pareto_optimal(data, objectives, maximize)`. Le reste du code n'a pas été lu : tout nom proposé ici s'aligne sur l'existant en cas d'écart.
2. **Avancer jalon par jalon** (§ 12). Ne pas commencer un jalon tant que les critères du précédent ne sont pas remplis.
3. **Ne rien inventer d'économique.** Prix, probabilités d'aléas, parts perdues et taux exigés viennent du fichier de paramètres, où ils sont marqués `provisoire: true` tant qu'ils ne sont pas sourcés.
4. **Signaler plutôt que deviner.** Un capital nul, une vocation inconnue ou un score R manquant produit `NA` et un avertissement `cli`, jamais une valeur par défaut silencieuse.
5. **P4 est un indicateur conditionnel**, comme B4, R5 ou T3 : il n'est calculé que si ses sources sont fournies (prix, vocation). Les projets existants gardent donc leur score de famille P à l'identique.
6. **Convention du radar (spec 048)** : la colonne consommée par le radar est sur 0-100 et « haut = bon ». P4 la respecte par une règle de normalisation dédiée.
7. Convention NMT pour les nouveaux noms, roxygen en anglais, commentaires en français, un test par fonction exportée. Versionnage et NEWS selon les consignes de release, au moment de l'implémentation.

## 1. Objet

P4 mesure, pour chaque UGF, ce que le capital sur pied rapporte par an une fois déduites les pertes attendues dues aux aléas, et le compare à un taux exigé propre à la vocation de l'UGF.

Il transpose à l'UGF trois résultats de l'économie forestière :

| Héritage | Idée reprise |
|---|---|
| Faustmann (1849), Pressler (1860) | garder un capital tant que sa valeur croît plus vite que le taux exigé |
| Reed (1984) | un risque de destruction agit comme une majoration du taux d'actualisation |
| Hartman (1976) | les fonctions non marchandes modifient la décision ; ici par le taux exigé, sans monétisation |

Deux sorties : un **écart en points** pour la décision, un **score 0-100** pour le radar.

Hors périmètre de la version 1 : valeur d'attente du fonds (Faustmann complet), simulation de scénarios de gestion, calcul arbre par arbre, corrélation entre aléas.

## 2. Définitions et formules

Toutes les grandeurs de taux sont stockées en **proportion** (0,03 pour 3 %) et affichées en %.

```
rendement_brut   = gain_valeur / capital
perte_i          = p_max_i × (1 − Ri_norm / 100) × part_perdue_i     pour chaque aléa i
pertes_attendues = perte_saisie            si renseignée
                 = somme des perte_i       sinon
rendement_net    = rendement_brut − pertes_attendues
ecart            = rendement_net − taux_exige[vocation]
P4_norm          = min(100, max(0, arrondi(100 × rendement_net / plafond_score)))
```

| Grandeur | Sens | Unité |
|---|---|---|
| `capital` (K) | valeur du bois sur pied de l'UGF | €/ha |
| `gain_valeur` (ΔK) | gain annuel de valeur : accroissement en volume et passages en catégorie supérieure | €/ha/an |
| `Ri_norm` | `R1_norm` à `R4_norm`, 0-100, haut = bon (spec 048) | 0-100 |
| `p_max_i` | probabilité annuelle de l'aléa quand le score vaut 0 | proportion/an |
| `part_perdue_i` | part de la valeur détruite si l'aléa survient | proportion |

**Les scores R entrent sous leur forme normalisée.** Les colonnes brutes `R1` à `R4` sont orientées « haut = risque » ; seules les colonnes `_norm` suivent la convention de la spec 048, confirmée par Pascal le 2026-11-28 pour P4 : un score élevé signifie un risque faible. Lire la colonne brute inverserait le calcul.

**Risque sanitaire.** L'aléa « sécheresse et sanitaire » lit `min(R3_norm, R5_norm)` quand R5 (dépérissement, conditionné à FORDEAD) est disponible, et `R3_norm` seul sinon.

Décision, avec `seuil` = 0,005 (0,5 point) par défaut :

| Condition | Décision |
|---|---|
| `ecart > +seuil` | `capitaliser` |
| `−seuil ≤ ecart ≤ +seuil` | `equilibre` |
| `ecart < −seuil` et lecture de la vocation = récolter | `recolter` |
| `ecart < −seuil` et lecture de la vocation = surveiller | `surveiller` |

## 3. Entrées par UGF

| Champ | Origine | Obligatoire |
|---|---|---|
| surface | géométrie de l'UGF | oui |
| `capital`, `gain_valeur` | calculés selon le NDP (§ 4) ou fournis | oui |
| `R1_norm` à `R4_norm`, `R5_norm` si présent | famille R, après normalisation | oui, sauf si `perte_saisie` |
| `vocation` | **nouveau champ**, déclaré par le gestionnaire | oui |
| `perte_saisie` | **nouveau champ**, proportion/an, facultatif | non |

Le radar peut suggérer une vocation, mais il décrit un état et non un objectif : la valeur déclarée fait foi.

## 4. Capital et gain de valeur selon le NDP

| NDP | Capital K | Gain ΔK | Usage de P4 |
|---|---|---|---|
| 0 | `P1` (m³/ha) × prix moyen par essence | `P2` (m³/ha/an) × prix moyen | signal, repérage |
| 1 | `P1` avec hauteur du CHM × prix moyen | `P2` par indice de station | classement relatif |
| 2 | tiges détectées par drone, hauteur par arbre | idem | zones exposées dans l'UGF |
| 3 | inventaire : volume par essence, catégorie de diamètre et qualité × prix par qualité | accroissement mesuré par comparaison d'inventaires, passages de catégorie compris | **décision** |
| 4 | jumeau numérique | croissance simulée arbre par arbre | décision par arbre |

- La confiance suit la règle NDP générale (ADR-011) ; P4 hérite du NDP le plus faible de ses entrées.
- En dessous de NDP 3, la sortie porte `p4_signal_seulement = TRUE`.
- `P2` en mode sylvoécorégion est une production régionale, pas l'accroissement de l'UGF : à NDP 0, le rendement brut est un ordre de grandeur.

## 5. Fichier de paramètres

`inst/extdata/p4_parametres.yml`, surchargeable par projet.

```yaml
version: 1
provisoire: true
plafond_score: 0.06
seuil_decision: 0.005
horizon_ans: 20
plafond_exposition: 0.20
aleas:
  incendie:              {score: R1, p_max: 0.01, part_perdue: 0.80, portee: localisee}
  tempete:               {score: R2, p_max: 0.02, part_perdue: 0.50, portee: systemique}
  secheresse_sanitaire:  {score: [R3, R5], p_max: 0.03, part_perdue: 0.40, portee: systemique}
  abroutissement:        {score: R4, p_max: 0.02, part_perdue: 0.10, portee: localisee}
vocations:
  production: {taux_exige: 0.03, si_ecart_negatif: recolter}
  mixte:      {taux_exige: 0.02, si_ecart_negatif: recolter}
  protection: {taux_exige: 0.01, si_ecart_negatif: surveiller}
  accueil:    {taux_exige: 0.01, si_ecart_negatif: surveiller}
  naturalite: {taux_exige: 0.00, si_ecart_negatif: surveiller}
prix:            # €/m³ par essence et qualité, à sourcer
  provisoire: true
```

Toutes ces valeurs sont des valeurs de départ non calibrées.

## 6. Sorties par UGF

`indicateur_p4_rendement_net()` ajoute :

| Colonne | Contenu |
|---|---|
| `P4` | rendement net, proportion/an (valeur brute de l'indicateur) |
| `P4_norm` | 0-100, par la règle dédiée de `normalize_indicator()` ; entre dans `famille_production` |
| `p4_rendement_brut` | proportion/an |
| `p4_perte_incendie`, `_tempete`, `_secheresse_sanitaire`, `_abroutissement` | proportion/an, `NA` si perte saisie |
| `p4_pertes_attendues` | proportion/an |
| `p4_rendement_geometrique` | proportion/an, croissance de long terme du capital (§ 7 bis) |
| `p4_taux_exige`, `p4_ecart` | proportion, points |
| `p4_decision` | `capitaliser`, `equilibre`, `recolter`, `surveiller` |
| `p4_alea_dominant` | aléa de plus forte perte |
| `p4_signal_seulement` | `TRUE` sous NDP 3 |

Le score repose sur le rendement net absolu, pas sur l'écart : le radar décrit l'état économique, la vocation n'intervient que dans la décision. Une UGF en libre évolution affiche donc un P4 bas sans que ce soit un défaut.

À déclarer dans `INDICATOR_FAMILIES` et `indicator-config.R` : famille P, conditionnel, sens « haut = bon », unité proportion/an.

## 7. Synthèse à l'échelle de la forêt

`p4_synthese_foret()` renvoie :

- `rendement_net_foret` = Σ(surface × capital × rendement_net) / Σ(surface × capital) ;
- `part_capital_ecart_negatif` = capital des UGF sous `−seuil` / capital total ;
- `pertes_attendues_eur_an` = Σ(surface × capital × pertes_attendues) ;
- `alea_dominant_foret` : aléa de plus forte perte en €/an.

## 7 bis. Risque de ruine

Le rendement net est une espérance : il multiplie une probabilité par une perte et masque ce qui arrive le jour où l'aléa frappe. Quatre mesures le complètent. Aucune n'entre dans `P4` ni dans `P4_norm`.

### Dommage en cas de sinistre

```
dommage_i      = part_perdue_i × (1 − Ri_norm / 100)          par UGF et par aléa
perte_sinistre = dommage_i × capital × surface                en €
```

L'espérance du § 2 s'écrit alors `p_max_i × dommage_i` : les deux lectures sont cohérentes.

### Les quatre mesures

| Mesure | Définition | Sortie |
|---|---|---|
| Perte en cas de sinistre majeur | par aléa : **somme** des `perte_sinistre` des UGF si l'aléa est `systemique`, **maximum** s'il est `localisee` | en €, en part du capital, en années de gain net de la forêt |
| Probabilité sur l'horizon | `1 − (1 − p_max_i)^horizon_ans` | proportion |
| Concentration | part de la perte de sinistre portée par la première UGF, et nombre effectif d'UGF `1 / Σ part²` | proportion, nombre |
| Rendement géométrique | `exp(ln(1 + rendement_brut) + Σ p_max_i × ln(1 − dommage_i)) − 1`, par UGF | proportion/an |

La portée d'un aléa est une hypothèse de paramétrage : une tempête ou une sécheresse touche toutes les UGF exposées en même temps, un incendie ou l'abroutissement une seule.

### Usage

- **Plafond d'exposition** : `p4_ruine_foret()` marque `exposition_depassee = TRUE` pour tout aléa dont la perte de sinistre dépasse `plafond_exposition` du capital. C'est une contrainte, pas un terme de la moyenne.
- **UGF concentrante** : l'UGF qui porte la plus grande part de la perte d'un aléa en dépassement est signalée, quelle que soit sa décision P4.
- **Pareto** : la perte de sinistre peut entrer comme objectif à minimiser, à côté de `P4` (§ 8).

Le rendement géométrique suppose des aléas indépendants entre eux et un sinistre au plus par an ; c'est une approximation, pas une simulation de la distribution des pertes.

## 8. Pareto et sélection des axes

1. **Entrée de Pareto** : `P4` (rendement net), jamais `P4_norm` plafonné ni la décision. Appel de `identify_pareto_optimal()` avec `maximize = TRUE` sur tous les objectifs.
2. **Trois axes au plus** croisés avec P4, car avec 12 objectifs presque tout est non dominé.
3. **Sélection des axes** par `p4_selectionner_axes()` :
   - ACP des 12 scores de famille, P4 en variable supplémentaire ; ACM ou AFDM en option si l'on ajoute des variables qualitatives (essence, vocation) ;
   - sur chacune des trois premières dimensions, retenir la famille de plus forte contribution, en préférant celle qui s'oppose à P4 en cas d'égalité ;
   - un axe imposé par la vocation remplace le moins contributif.
4. **Garde sur l'effectif** : sous un nombre minimal d'UGF (paramètre, 30 par défaut), pas d'analyse factorielle ; repli sur les axes de la vocation, avec un avertissement. L'analyse se calcule à l'échelle d'un massif ou d'un ensemble de forêts.
5. **Sortie** : statut `domine` ou `non_domine` par UGF, et prix implicite entre deux UGF voisines du front (points de rendement par point de score).
6. **Front rendement-risque** : variante où l'on croise `P4` avec la perte de sinistre de l'aléa dominant (`maximize = FALSE` pour celle-ci), au lieu de fondre le risque dans le rendement net.
7. Le front construit sur des UGF existantes décrit la forêt. Le front de décision, sur des options de gestion d'une même UGF, relève du brief app.

Dépendance factorielle en `Suggests`, avec repli propre si elle est absente.

## 9. Côté application

Rien n'est modifié dans `nemetonshiny` depuis ce dépôt (règle 11). L'exposition de P4 et son usage par le plan d'actions sont décrits dans `brief-nemetonshiny.md`.

## 10. Jeu d'essai de référence

Forêt fictive de cinq UGF, paramètres du § 5, R5 absent. Fixture de test, test d'acceptation de M1 et M2. Les scores R sont donnés **normalisés**.

| UGF | Vocation | ha | K €/ha | ΔK €/ha/an | R1_norm | R2_norm | R3_norm | R4_norm |
|---|---|---|---|---|---|---|---|---|
| 1 Douglasaie régulière | production | 12 | 14 000 | 750 | 70 | 40 | 45 | 80 |
| 2 Chênaie irrégulière | production | 18 | 9 000 | 330 | 85 | 75 | 70 | 50 |
| 3 Pessière | production | 6 | 11 000 | 380 | 75 | 30 | 20 | 85 |
| 4 Ripisylve | protection | 3 | 4 000 | 80 | 95 | 70 | 60 | 60 |
| 5 Vieille hêtraie-chênaie | naturalite | 5 | 12 000 | 150 | 85 | 60 | 50 | 70 |

Résultats attendus, en %, tolérance 0,005 point :

| UGF | Brut | Incendie | Tempête | Séch. sanit. | Abrout. | Pertes | Net | Écart | P4_norm | Décision |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 5,357 | 0,24 | 0,60 | 0,66 | 0,04 | 1,54 | 3,817 | +0,817 | 64 | capitaliser |
| 2 | 3,667 | 0,12 | 0,25 | 0,36 | 0,10 | 0,83 | 2,837 | −0,163 | 47 | equilibre |
| 3 | 3,455 | 0,20 | 0,70 | 0,96 | 0,03 | 1,89 | 1,565 | −1,435 | 26 | recolter |
| 4 | 2,000 | 0,04 | 0,30 | 0,48 | 0,08 | 0,90 | 1,100 | +0,100 | 18 | equilibre |
| 5 | 1,250 | 0,12 | 0,40 | 0,60 | 0,06 | 1,18 | 0,070 | +0,070 | 1 | equilibre |

Forêt : capital 468 000 €, rendement net 2,610 %, part du capital à écart négatif 14,10 %, pertes attendues 5 995,2 €/an, aléa dominant sécheresse et sanitaire.

Pareto sur P4, B, N avec les scores fictifs B = 35, 65, 30, 80, 90 et N = 25, 55, 20, 70, 92 : seule l'UGF 3 est dominée.

Risque de ruine (§ 7 bis), horizon 20 ans, gain net de la forêt 12 214,8 €/an :

| Aléa | Portée | Perte de sinistre | Part du capital | Années de gain net | Probabilité à 20 ans | Première UGF | Nombre effectif |
|---|---|---|---|---|---|---|---|
| incendie | localisée | 40 320 € | 8,62 % | 3,30 | 18,2 % | UGF 1, 50,0 % | 2,92 |
| tempête | systémique | 107 550 € | 22,98 % | 8,80 | 33,2 % | UGF 1, 46,9 % | 3,19 |
| sécheresse et sanitaire | systémique | 91 440 € | 19,54 % | 7,49 | 45,6 % | UGF 1, 40,4 % | 3,58 |
| abroutissement | localisée | 8 100 € | 1,73 % | 0,66 | 33,2 % | UGF 2, 55,0 % | 2,67 |

Seule la tempête dépasse le plafond de 20 % ; l'UGF 1, pourtant classée `capitaliser`, est l'UGF concentrante.

Rendement géométrique par UGF, en % : 3,505 ; 2,757 ; 1,131 ; 1,015 ; −0,062.

## 11. Tests

- Jeu de référence : toutes les colonnes et la synthèse forêt.
- `perte_saisie` renseignée : remplace le calcul, pertes par aléa à `NA`.
- `capital` nul ou manquant : `NA` et avertissement, pas d'erreur fatale.
- Vocation absente du fichier de paramètres : erreur explicite.
- Score R normalisé manquant sans `perte_saisie` : `NA` et avertissement.
- R5 présent : l'aléa sécheresse et sanitaire lit le minimum de `R3_norm` et `R5_norm`.
- Garde contre la colonne brute : le calcul refuse `R1` sans `R1_norm`.
- `P4_norm` borné à 0 pour un rendement net négatif et à 100 au-dessus du plafond.
- Risque de ruine : tableau de référence exact ; somme pour un aléa systémique, maximum pour un aléa localisé ; dépassement du plafond et UGF concentrante ; rendement géométrique toujours inférieur ou égal au rendement net à 0,05 point près sur le jeu de référence.
- Sélection d'axes : repli quand l'effectif est insuffisant ou la dépendance absente.
- Non-régression : sans les sources de P4, `famille_production` est inchangée sur `massif_demo_units`.

## 12. Jalons

| Jalon | Livrable | Critère d'acceptation |
|---|---|---|
| M0 | lecture du code de la famille P, de la normalisation et de Pareto ; fichier de paramètres et son validateur | note d'alignement relue ; validateur vert |
| M1 | `indicateur_p4_rendement_net()`, capital et gain fournis | jeu de référence exact, tests du § 11 verts |
| M2 | `p4_synthese_foret()`, `p4_ruine_foret()`, branchement Pareto, `p4_selectionner_axes()` | synthèse, risque de ruine et statut Pareto du jeu de référence exacts |
| M3 | capital et gain calculés depuis `P1`, `P2` et les prix ; déclaration dans `INDICATOR_FAMILIES` | non-régression verte ; drapeau de précision correct |
| M4 | côté app | selon `brief-nemetonshiny.md` |

## 13. Questions ouvertes

1. Calibration des `p_max` et des parts perdues, par région et par essence : quelles sources ?
2. Source des prix par essence et qualité, et fréquence de mise à jour.
3. Vocation : champ déclaré par UGF, ou poids de production déduit du profil d'acteur (variante continue `taux_exige = taux_ref × poids_production`) ?
4. Plafond du score (6 %) et seuil de décision (0,5 point).
5. Poids de P4 dans `famille_production` face à P1, P2, P3.
6. R6 (sensibilité microclimatique) et R7 (gel tardif) doivent-ils devenir des aléas de P4 ?
7. La règle `min(R3_norm, R5_norm)` pour le sanitaire convient-elle, ou faut-il deux aléas distincts ?
8. Portée de chaque aléa (systémique ou localisée), horizon (20 ans) et plafond d'exposition (20 % du capital) : valeurs à arrêter.
9. Faut-il une simulation de la distribution des pertes, avec corrélations entre aléas, au-delà des quatre mesures du § 7 bis ?

## 14. Références

- Faustmann M. (1849), *Allgemeine Forst- und Jagd-Zeitung*, 441-455.
- Hartman R. (1976), The harvesting decision when a standing forest has value, *Economic Inquiry* 14(1), 52-58.
- Reed W. J. (1984), The effects of the risk of fire on the optimal rotation of a forest, *Journal of Environmental Economics and Management* 11(2), 180-190.
- Chang S. J., Gadow K. v. (2010), Application of the generalized Faustmann model to uneven-aged forest management, *Journal of Forest Economics* 16(4), 313-325.
- Spec 048 (convention du radar), ADR-011 (NDP).
