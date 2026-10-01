# Spec 054 — Production IFN par petits domaines (Fay-Herriot) et ses consommateurs

**Version** : 0.2.0 (cadrage, décisions tranchées)
**Date**    : 2026-10-01
**Statut**  : **Cadrage — aucune ligne de code.** Décisions D1-D8 **tranchées le
2026-10-01** (§9). Reste le lot 0 (relevés IGN) avant le lot 1. ADR associé : `ADR-016-estimation-petits-domaines.md` (brouillon,
même dossier, à reporter dans `platform_nemeton`).
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` — moteur Fay-Herriot, table de production IFN par
SER × campagne, et branchement sur P2, P1/C1, E1/E2 et la spec 040.
**Cible app**  : `nemetonshiny` — aucune dans cette spec ; un brief suivra le lot 4.
**Origine** : Onwunji I.C., Vega C., Durrieu S., Korhonen L., Tokola T., Massey A.,
Cordonnier T., Bouriaud O., Besic N., Belhoul S., Renaud J.-P. (2026).
*Leveraging GEDI and NFI to inform on forest productivity at the level of the
management units.* Annals of Forest Science 83:46.
doi:10.1186/s13595-026-01358-2 — CC-BY 4.0.

---

## 1. Objectif

Donner au cœur ce qui lui manque aujourd'hui : **un flux de production
biologique** (m³/ha/an et m²/ha/an) **mesuré par l'IFN**, avec une **incertitude
par domaine**. Ensuite, faire consommer ce flux par les indicateurs qui le
remplacent aujourd'hui par une table ONF figée ou par un pourcentage du stock.

Ce n'est pas l'apport de GEDI qui compte ici, c'est la **méthode** de l'article :
l'estimateur Fay-Herriot (FH) au niveau du domaine. Il combine :

- la **moyenne directe IFN** du domaine : sans biais, mais bruitée quand il y a peu
  de placettes ;
- une **prédiction synthétique** Xβ, régression sur des covariables de
  télédétection agrégées au même domaine.

Le dosage entre les deux suit leurs variances, et chaque domaine reçoit une erreur
quadratique (MSE).

## 2. Ce que l'article établit, et ce qu'on en reprend

| Élément de l'article | Repris ? | Commentaire |
|---|---|---|
| FH au niveau du domaine (EBLUP + MSE Prasad-Rao g1+g2+g3) | **Oui** | Cœur de la spec (§4). |
| Empilement domaine × année (*pooled cross-section*), β et σᵥ² invariants dans le temps | **Oui** | Garde le signal annuel sans agréger les campagnes a priori. |
| Covariables GEDI L2A (rh98 moyenne/écart-type, altitude du sol moyenne/écart-type) | **Oui, en concurrence** | Deux jeux construits et comparés (D3) : GEDI L2A brut comme l'article, et FORMS-T hauteur + MNT. Le meilleur est retenu sur critères fixés à l'avance (§5.b). |
| Sélection de variables par best subset + AIC, 3 prédicteurs au plus, une seule métrique de hauteur | **Oui** | Évite la colinéarité rh90/rh98/rh100. |
| Domaines ONF agence / unité territoriale | **Non (par défaut)** | Domaine natif = SER (cohérent avec la spec 040). Les UT ONF restent possibles en domaine utilisateur (D2). |
| Production fournie par la base IFN interne (accroissement + recrutement) | **Non** | Les données brutes ouvertes n'ont **pas** de colonne de production. On la recalcule (§3). |
| Seuils de RSE : 15 % pour la production, 10 % pour le stock | **Oui** | Repris comme seuils d'affichage, pas comme filtre. |

**Résultats chiffrés de l'article** (Bourgogne-Franche-Comté, forêts publiques,
2019-2022, 5 591 placettes). R² de PV : 0,66 sur les agences et 0,62 sur les unités
territoriales. L'efficacité relative est toujours supérieure à 1 (≥ 4 sur les
agences). Avant FH, 16 unités territoriales sur 51 passaient sous 15 % de RSE pour
PV ; après FH, 43 sur 51.
**Ce qu'il ne montre pas** : aucune tendance détectable sur 4 ans (§7.6).

## 3. Ce que l'IFN brut permet de calculer — vérifié sur l'export

Vérifié sur `data-raw/ifn/export_dataifn_2005_2024.zip` (IGN, Licence Ouverte
Etalab v2.0, doc `IGN_DB_doc_arbre.pdf` v2.4 du 14/10/2025) :

- `ARBRE.csv` porte `C13` (circonférence à 1,30 m), `HTOT`, `V`, `W` et **`IR5`**,
  l'accroissement radial cumulé des 5 derniers cernes complets, mesuré à la tarière
  au niveau de C13. **`IR5` est en mètres** dans la table, pas en dixièmes de mm
  (la doc le précise).
- `IR5` est renseigné sur 854 804 lignes sur 2 363 567. Il est **absent** :
  - sur les arbres simplifiés ;
  - sur les noyers (`ESPAR = 27C`) ;
  - sur le chêne vert (`ESPAR = 6`) depuis 2015 ;
  - sur les lignes de revisite (même piège que `VEGET5`, spec 040 §5.c).
  Pour un arbre de moins de 5 cernes à 1,30 m, `IR5` est extrapolé au prorata.
- **Aucune colonne de production** dans `ARBRE` ni dans `PLACETTE`.
- **Aucune colonne de propriété** dans `PLACETTE` : on ne peut pas restreindre aux
  forêts publiques comme l'article. Ses ordres de grandeur (PV moyen 5,87 m³/ha/an,
  PG 0,65 m²/ha/an) ne sont donc **pas** un contrôle direct.

Conséquences sur ce que chaque attribut demande :

**PG (production en surface terrière, m²/ha/an) : exacte, sans hypothèse.**
Il suffit de reconstituer la circonférence d'il y a 5 ans :

```
C_passé = C13 − 2π·IR5
g = C²/(4π)
PG_arbre = (g(C13) − g(C_passé)) / 5
PG = Σ W·PG_arbre
```

`W` est le poids à l'hectare de l'arbre.

**PV (production en volume, m³/ha/an) : demande une hypothèse.**
L'accroissement en hauteur n'est pas mesuré. Deux voies :
- **(a) Forme et hauteur constantes** : `ΔV ≈ V·(1 − (C_passé/C13)²)`. Cette voie
  sous-estime la production, puisque la hauteur a aussi crû.
- **(b) Tarif IFN du cœur** (`lookup_ifn_equation()`, déjà utilisé par P1)
  appliqué à `C_passé`, avec une hauteur passée modélisée.
C'est la décision D1.

**Recrutement.** Un arbre dont `C_passé` est sous le seuil de recensabilité
(23,5 cm) est compté comme recruté : sa surface terrière et son volume entiers
entrent dans la production. **Hypothèse à confirmer** contre la méthodologie IGN
publiée avant le lot 1 (D1). La doc générale de l'export ne décrit pas le calcul de
production.

**Contrôle externe obligatoire** (même esprit que les 2,84 m³/ha/an de la spec
040). La production nationale toutes essences recalculée doit tomber dans l'ordre
de grandeur publié par l'IGN (Mémento de l'inventaire forestier, production
biologique). **Le chiffre de référence est à relever dans le Mémento au lot 1, pas
de mémoire.** Un test verrouille l'ordre de grandeur.

## 4. Le moteur Fay-Herriot — implémentation maison

Pour un domaine i et une campagne t :

```
θ̂_it = X_it·β + v_i + e_it        v_i ~ N(0, σᵥ²)    e_it ~ N(0, ψ_it)
ψ_it = Σ_j (y_ijt − θ̂_it)² / (n_it (n_it − 1))         (variance de la moyenne)
γ_it = σᵥ² / (σᵥ² + ψ_it)
θ̂_it^FH = γ_it·θ̂_it + (1 − γ_it)·X_it·β̂
MSE_it ≈ g1 + g2 + g3                                   (Prasad-Rao)
RSE_it = √MSE_it / θ̂_it^FH × 100
```

**Choix : implémentation en R de base, environ 150 lignes, sans dépendance**
(D4). Raisons :

- `JoSAE` (0.3.0) et `sae` (1.3) sont sous licence **GPL-2** stricte, vérifié
  sur CRAN le 2026-10-01. Leur compatibilité avec le GPL-3 de `nemeton` en
  `Imports` est discutable.
- `emdi` (GPL-2) tire une quinzaine de dépendances, dont `spdep` et `openxlsx`.
- Le modèle FH est court : estimation de σᵥ² (REML ou Fay-Herriot par moments),
  β par moindres carrés généralisés, puis EBLUP et MSE.

`sae` entre en **`Suggests`** uniquement, pour un test de non-régression :
l'EBLUP et la MSE maison doivent reproduire `sae::eblupFH()` / `sae::mseFH()` à
1e-6 près sur un jeu fixé.

**Cas limites à traiter explicitement** :

- **σ̂ᵥ² ≤ 0.** On le tronque à 0 et on émet un avertissement : toutes les
  estimations deviennent synthétiques, et il faut le dire.
- **n_it = 1.** ψ n'est pas calculable. On ne crée pas de domaine-année direct ;
  il passe en domaine **synthétique**.
- **Domaine sans placette.** Prédiction synthétique seule, MSE = g2 + σᵥ².
  Marquée `nature = "synthetique"`, jamais `"fay_herriot"`.

**Sorties ligne à ligne** : `estimation`, `mse`, `rse`, `gamma`, `n_plac`,
`direct`, `psi`, `synthetique`, `nature` (`"direct"` / `"fay_herriot"` /
`"synthetique"`). Le γ est publié parce que le FH dépend d'un modèle et peut être
biaisé si ce modèle est faux (Kangas et al. 2025, cités par l'article §4.2). Le
lecteur doit voir **quelle part de l'estimation est un modèle**.

## 5. Domaines et covariables

### 5.a Domaines

- **Natif : SER × campagne**, avec la GRECO en repli d'affichage. Mêmes clés que
  `ifn_volume_essence_ser.csv` et `ifn_prelevement_essence_ser.csv`, ce qui permet
  de joindre directement le ratio prélèvement/production (§7.2).
- **Domaine utilisateur** (lot 5, D2) : l'appelant fournit des polygones, par
  exemple des UT ONF (parcellaire, spec 046) ou un massif. Les placettes IFN sont
  rattachées par jointure point-dans-polygone sur `XL`/`YL`. Les coordonnées
  publiques sont floutées : à un niveau agrégé c'est tolérable (c'est l'argument de
  l'article §4.1), mais une placette en bordure peut tomber dans le mauvais
  domaine. Il faut le documenter, et ne pas descendre sous quelques milliers
  d'hectares.
- **Jamais l'UGF.** Une UGF de quelques hectares n'a pas de placette ; elle ne
  reçoit que la valeur de son domaine (§7).

### 5.b Covariables (D3 — deux jeux, comparés)

Deux jeux sont construits sur les **mêmes domaines-années** et départagés au lot 1.

| Jeu | Covariable | Source | Agrégat par domaine × année |
|---|---|---|---|
| **G** (comme l'article) | Hauteur | GEDI L2A, rh98 (et rh70, retenu par l'article sur ses agences pour PG) | moyenne, écart-type |
| **G** | Altitude du sol | GEDI L2A, *ground elevation* | moyenne, écart-type |
| **F** | Hauteur de canopée | FORMS-T `height` (10 m, annuel 2018→) | moyenne, écart-type |
| **F** | Altitude | MNT 25 m (déjà en NDP 0) | moyenne, écart-type |
| les deux (option) | Climat | WorldClim / E-OBS | moyenne |

**Filtrage GEDI** (jeu G), repris de l'article §2.3 :
- `degrade_flag = 0` et `quality_flag = 1` ;
- hauteur > 65 m écartée ;
- faisceaux *power* et *coverage* gardés, de jour comme de nuit ;
- seuls les tirs **sous masque forêt** sont retenus (§8.8).

Le seuil de sensibilité ≥ 0,95 a été testé par les auteurs : il fait tomber 45,5 %
des tirs *coverage*. Il n'est pas repris par défaut.

**GEDI a deux points d'attention.** L'acquisition passe par Earthdata, avec un
identifiant NASA, et uniquement dans `data-raw/`, jamais à l'exécution du paquet.
Il faut aussi vérifier les trous de couverture temporelle (période de mise en
veille de la mission) avant d'empiler les années. Aucune source GEDI n'est
déclarée aujourd'hui dans `inst/datasources/FR.json` : le jeu G ne crée pas de
source d'exécution, il ne vit que dans `data-raw/`.

**Critères de choix, fixés avant de voir les résultats** (pour ne pas choisir sur
le bruit) :

1. **Efficacité relative globale** (RE, article éq. 6) sur PG et PV, pour chaque
   jeu, sur les mêmes domaines-années.
2. **Validation croisée « un domaine en moins »** : RMSE de la prédiction
   synthétique sur la SER retirée. C'est ce critère qui juge la partie modèle.
3. **I de Moran des résidus** : un jeu qui laisse une structure spatiale est
   pénalisé.

L'AIC ne sert qu'à **choisir les variables à l'intérieur d'un jeu** (*best
subset*, 3 prédicteurs au plus, une seule métrique de hauteur). Il ne sert pas à
comparer les deux jeux.

En cas d'égalité (écart de RE inférieur à 10 %), on retient **F** : couverture
continue, déjà déclaré, aucun téléchargement Earthdata à maintenir. Le jeu perdant
reste documenté dans `data-raw/` avec ses scores, et n'est **pas** embarqué.

**Circularité.** Le *volume* et la *biomasse* de FORMS-T sont calés sur des
placettes IFN (Schwartz et al. 2023). Les utiliser comme covariables pour estimer
un attribut IFN réintroduirait l'IFN des deux côtés de l'équation. **Seule la
hauteur FORMS-T**, apprise sur GEDI, est admise. GEDI brut n'a pas ce problème.

**Fenêtre temporelle.** La fenêtre commune aux deux jeux est 2019 (début de GEDI)
→ dernière campagne, moins les années trouées. FORMS-T commence en 2018, mais on
l'aligne sur GEDI pour comparer à données égales. Cela fait environ 6 campagnes ×
environ 86 SER, soit à peu près 500 observations. Les campagnes 2005-2018 restent
utilisables en estimation directe seule.

**Précalcul.** Agréger FORMS-T et GEDI sur toute la France métropolitaine est
lourd. Le calcul se fait dans `data-raw/build_ifn_production.R`, comme les tables de
la spec 040, et le paquet n'embarque qu'un CSV. Jamais de raster dans le paquet ni
en base (ADR-002). Le run sur la France entière se lance dans un cgroup plafonné
(cf. mémoire « isoler les jobs lourds »). La colonne `covariables` de la table
indique le jeu retenu (`"forms_mnt"` ou `"gedi_l2a"`).

## 6. Livrables cœur

| Objet | Type | Rôle |
|---|---|---|
| `estimer_fay_herriot(direct, psi, X, domaine, annee, methode = "REML")` | exportée | Moteur générique (§4). Réutilisable pour V, G, Dg. |
| `ifn_production_placettes()` | interne (`data-raw`) | PG/PV par placette depuis `ARBRE` (§3). |
| `inst/extdata/ifn_production_ser.csv` | table | Une ligne par niveau × ser × campagne × attribut (`pg`, `pv`) et par essence groupée (`tous`, `feuillus`, `resineux`) : `direct`, `psi`, `n_plac`, `estimation`, `mse`, `rse`, `gamma`, `nature`, `methode_pv`, `covariables`, `millesime`, `source`. |
| `ifn_production_ser(ser, greco, campagne, attribut, groupe)` | exportée | Accesseur filtrant, même idiome que `ifn_volume_essence_ser()`. |
| `ifn_production_reference(ser, attribut, groupe, campagnes)` | exportée | Valeur à appliquer à une UGF. Moyenne FH sur une fenêtre de campagnes, MSE propagée. Attributs `niveau` et `nature`. |
| `ifn_taux_prelevement_production(ser, groupe)` | exportée | Ratio prélèvement/production avec son incertitude (§7.2). |

**Pas de déclinaison par essence au lot 1.** Par SER, une essence a souvent moins
de 10 placettes par campagne : le FH tiendrait mais serait surtout synthétique.
Feuillus/résineux est le grain le plus fin défendable. L'essence viendra
éventuellement au lot 6, avec un FH multivarié (hors périmètre, §10).

Règle 5 : chaque fonction exportée a son test dans `tests/testthat/`.

## 7. Les consommateurs — points 1 à 6

### 7.1 P2 (station / productivité) — consommateur principal

**Aujourd'hui** : `indicateur_p2_station()` (`R/indicators-productive.R:334`) a
deux modes :
- le mode historique lit `annual_increment_m3_ha_yr` dans
  `productivity_tables.csv` (ONF 2021) par essence × fertilité × climat ;
- le mode CHM calcule un indice de station H₀ (courbes Duplat & Tran-Ha).

**Après** : un troisième mode `source = "ifn_fh"` donne
`P2 = ifn_production_reference(ser, "pv", groupe)`, en m³/ha/an. C'est l'unité du
mode historique, donc la normalisation existante s'applique telle quelle.

Garde-fous :
- **Défaut inchangé** (rétrocompatibilité stricte, comme `chm = NULL`). Le mode FH
  est opt-in jusqu'à validation sur un cas réel.
- La valeur est celle du **domaine**, pas de la station de l'UGF. On écrit un
  attribut `p2_provenance` (`"ifn_fh_ser"`, `"ifn_fh_greco"`, `"table_onf"`,
  `"site_index_chm"`) et un attribut `p2_rse`.
- **Combinaison possible** avec le mode CHM : le FH donne le niveau régional, le
  site index module à l'intérieur du domaine. C'est la décision D5 ; par défaut,
  pas de combinaison au lot 2.

### 7.2 Spec 040 — le ratio prélèvement/production

La spec 040 §5.a cite ce ratio comme forme de publication IFN, sans pouvoir le
calculer : le cœur n'a que le stock et le prélèvement.
`ifn_taux_prelevement_production()` le calcule par SER × groupe avec les mêmes clés
que `ifn_prelevement_essence_ser.csv`.

**Deux pièges à traiter** :
- **Le prélèvement de la spec 040 est mesuré au premier passage** (approximation
  assumée §5.c), alors que la production porte sur les 5 ans *avant* la campagne.
  Les deux fenêtres ne coïncident pas : il faut aligner sur des campagnes communes
  et le documenter.
- **L'incertitude du ratio.** La production a une MSE FH, le prélèvement n'a qu'une
  estimation directe. On propage par la méthode delta, en supposant
  l'indépendance, et on le dit. Un ratio supérieur à 1 n'est pas une erreur : c'est
  une SER qui décapitalise.

### 7.3 P1 (volume) et C1 (biomasse) — le repli continu remplace le repli en escalier

**Aujourd'hui** : `.ifn_cascade()` (`R/ifn_tables.R:48`) et
`completer_volume_ifn()` descendent SER → GRECO → national **dès que le nombre de
placettes passe sous `min_plac`** (30 par défaut). Une SER à 29 placettes est
jetée en bloc au profit de la GRECO.

**Après** : `estimer_fay_herriot()` appliqué à V par SER (`ifn_volume_essence_ser`
au grain `tous` / `feuillus` / `resineux`) donne un repli **continu**. γ dose la
moyenne de la SER et la prédiction synthétique, et chaque valeur a une MSE.
`completer_volume_ifn(methode = c("cascade", "fay_herriot"))`, avec `"cascade"`
par défaut. La provenance ligne à ligne de la spec 040 D8 gagne la valeur
`"ifn_fh_ser"`. Une mesure n'est **jamais** écrasée, ce qui est inchangé.

**C1** (`R/indicators-families.R:337`) passe par V × ρ × BEF × C_frac : il hérite du
gain **sans modification de code**, dès que l'UGF reçoit un V complété par FH. Il
faut seulement un test qui le vérifie.

L'article obtient pour V le meilleur ajustement de ses cinq attributs (R² 0,81 sur
les agences, 0,72 sur les unités territoriales).

### 7.4 E1 (bois-énergie) et E2 (évitement) — passer du stock au flux

**Aujourd'hui, vérifié** : `indicateur_e1_bois_energie()`
(`R/indicators-energy.R:37`) calcule
`annual_harvest_m3_ha = volume × harvest_rate`, avec `harvest_rate = 0.02`. C'est
**2 % du stock sur pied**, quel que soit le peuplement. Un peuplement capitalisé à
faible croissance reçoit ainsi plus de bois-énergie qu'un peuplement jeune en
pleine production. Le contresens est structurel.

**Après (D6 : le flux remplace le stock)** : nouveaux arguments
`production_field = NULL` et `taux_mobilisation = NULL`.

- **`production_field` fourni** :
  `annual_harvest_m3_ha = production × taux_mobilisation`. Le volume sur pied et
  `harvest_rate` ne servent plus à E1. S'ils sont aussi fournis, ils sont ignorés
  avec un avertissement, pour ne pas laisser croire qu'ils comptent.
- **`taux_mobilisation` n'a pas de défaut inventé.** Deux sources admises :
  - une valeur explicite de l'appelant ;
  - `taux_mobilisation = "ifn_ser"` : la part de la production effectivement
    récoltée dans la SER, c'est-à-dire le ratio prélèvement/production du §7.2,
    plafonné à 1.
  Avec `production_field` mais sans `taux_mobilisation`, E1 s'arrête avec une
  erreur explicite, plutôt que de supposer une valeur.
- **`production_field = NULL`** (défaut) conserve exactement le comportement
  actuel. La rétrocompatibilité est stricte, et les scores existants ne bougent pas
  tant que l'appelant ne bascule pas.

**Normalisation : à refaire, pas à revérifier.** Le `ref_max` actuel (1,32 t
MS/ha/an) est calé sur le plafond de P1 (800 m³/ha × 2 %). Avec un flux, le plafond
devient « production haute × taux_mobilisation maximal ». Il doit être recalé sur la
distribution réelle des PV FH par SER (par exemple leur 95ᵉ centile), et
**seulement en mode flux**. Le mode stock garde son `ref_max`, sinon les scores des
projets existants changeraient. Il faut un test qui vérifie que les deux modes
gardent chacun leur plafond.

**Piège de dégénérescence, à traiter au lot 4.** Si la production vient du FH par
SER (`ifn_production_reference()`) **et** que `taux_mobilisation = "ifn_ser"`, alors
`production_SER × (prélèvement_SER / production_SER) = prélèvement_SER`. E1 ne
mesure plus une ressource soutenable, il **recopie la récolte observée** de la SER,
identique pour toutes les UGF du domaine. Le mode `"ifn_ser"` n'a de sens que si la
production est **propre à l'UGF**, par exemple P2 en mode site index CHM, ce qui
renvoie à la combinaison reportée en D5. Le lot 4 doit donc :
- **détecter** ce cas, c'est-à-dire une production de provenance `ifn_fh_*` avec un
  taux `"ifn_ser"` ;
- **avertir** explicitement ;
- **écrire** l'attribut `e1_mode = "recolte_observee"` au lieu de
  `"ressource_flux"`, pour que l'app ne le présente pas comme un potentiel.

Un test verrouille l'égalité E1 = prélèvement × facteur énergie dans ce cas, et
l'avertissement.

**Pourquoi remplacer plutôt que plafonner.** Plafonner aurait gardé le stock comme
moteur, et le contresens avec lui : à faible production, le plafond mord ; ailleurs,
c'est encore 2 % du stock. Remplacer rend E1 cohérent avec ce qu'il prétend
mesurer, une ressource renouvelable. Le coût est un changement de valeurs plus
marqué, absorbé par l'opt-in.

**E2** (`R/indicators-energy.R:139`) lit `E1` (`fuelwood_field = "E1"`) : il
hérite, sans modification de code.

### 7.5 B2 (structure) — conforté, pas modifié

L'article montre que l'hétérogénéité verticale (rh98_sd) explique la productivité à
l'échelle des unités territoriales (§4.1, avec Cordonnier et al. 2018 et Bouvier et
al. 2015). C'est la composante CV(CHM) de `indicateur_b2_structure()`.
**Aucun code** : on ajoute la référence à `inst/REFERENCES.md` et à la roxygen de B2
comme justification de la composante.

### 7.6 T2 / R3 / R5 — dimension temporelle, en prospective

L'empilement domaine × campagne produit une **série annuelle de PG/PV par SER avec
intervalle de confiance**. C'est un candidat naturel pour signaler un
ralentissement de croissance (sécheresse, dépérissement).

**Ce qu'on ne fait pas** : brancher cette série sur T2, R3 ou R5. L'article ne
détecte aucune tendance sur 2019-2022 (§4.3). Une campagne IFN mesure 5 ans de
cernes, donc deux campagnes successives partagent 4 cernes sur 5 et la série est
**lissée par construction**. Un signal de dépérissement y arriverait avec plusieurs
années de retard sur FORDEAD.

**Ce qu'on fait** : `ifn_production_ser()` expose la série. Un futur chantier
pourra croiser cette série avec le SPEI ou E-OBS (spec 034), avec un FH
spatio-temporel (Rao & Yu 1994). C'est hors périmètre.

### 7.7 Transverse — incertitude et NDP

- **La RSE n'entre pas dans le NDP.** Le NDP mesure la qualité des *données
  d'entrée de l'UGF* (règle 7, ADR-011). Une valeur de domaine IFN reste du NDP 0,
  quelle que soit sa RSE. La RSE est portée en **attribut** (`p2_rse`, MSE dans
  `completer_volume_ifn`) pour l'affichage.
- **Plan de validation** : les auteurs proposent de stratifier l'échantillonnage
  terrain par GEDI (§4.3). Pas de branchement :
  `create_validation_sampling_plan(weighting = "continuous")` accepte déjà un raster
  de poids quelconque.

## 8. Pièges identifiés à l'avance

1. **Unités d'IR5** : mètres dans la table, pas dixièmes de mm. Un facteur 10⁴ se
   détecte au contrôle national. On le verrouille par un test.
2. **IR5 manquant n'est pas IR5 nul.** Arbres simplifiés, noyers, chêne vert : les
   mettre à 0 sous-estime la production. Il faut les imputer à la placette (rapport
   PG/G des arbres mesurés de la même essence groupée) ou exclure la placette.
   C'est la décision D7.
3. **Lignes de revisite** : comme pour `VEGET5`, on ne lit `IR5` que sur la ligne de
   premier passage.
4. **Un domaine-année avec 1 placette** n'a pas de ψ (§4).
5. **σᵥ² tronqué à 0** : il faut avertir, pas se taire.
6. **Estimation synthétique présentée comme une mesure** : le champ `nature` est
   obligatoire, comme la provenance de la spec 040 D8.
7. **Indépendance des domaines** : l'article la vérifie par le I de Moran sur les
   résidus (non significatif). On refait ce test au lot 1, sur les SER. S'il est
   significatif, on passe à un FH spatial, et c'est une décision à remonter.
8. **Masquage de forêt des covariables** : FORMS-T doit être agrégé **sous masque
   forêt**, pas sur toute la SER. Sinon, la hauteur moyenne mesure le taux de
   boisement.

## 9. Décisions — tranchées le 2026-10-01

| # | Question | Décision |
|---|---|---|
| D1 | Méthode PV et règle de recrutement | **PG d'abord** (exacte). PV par la voie (a), forme et hauteur constantes, avec biais bas documenté. La voie (b), tarif du cœur + hauteur passée modélisée, passe en lot 1-bis si le contrôle national sort trop bas. Recrutement par seuil 23,5 cm, **après** relecture de la méthodo IGN (lot 0). |
| D2 | Domaines | SER × campagne au lot 1 ; domaines utilisateur (UT ONF, massif) au lot 5. |
| D3 | Covariables | **Deux jeux, comparés** : GEDI L2A brut (G) et FORMS-T hauteur + MNT (F). Critères fixés à l'avance (§5.b) ; F en cas d'égalité. |
| D4 | Moteur | **Maison**, en R de base ; `sae` en `Suggests` pour le test d'égalité (§4). |
| D5 | P2 | FH seul au lot 2 ; combinaison avec le site index CHM plus tard, sur un cas réel. |
| D6 | E1 | **Le flux remplace le stock** : `production × taux_mobilisation`, sans défaut inventé pour le taux (valeur explicite ou ratio IFN de la SER). Opt-in, `ref_max` propre au mode flux (§7.4). |
| D7 | IR5 manquant | Imputer par le rapport PG/G du groupe dans la placette ; exclure la placette si plus de 50 % de sa surface terrière n'a pas d'IR5. |
| D8 | Fenêtre de `ifn_production_reference()` | 5 dernières campagnes, configurable par `campagnes`. |

## 10. Hors périmètre

- FH multivarié : additivité des essences, ou PV et V conjoints (Benavent & Morales
  2016).
- FH spatial et spatio-temporel (Rao & Yu 1994) : seulement si le test de Moran le
  justifie (§8.7).
- Déclinaison par essence.
- Branchement sur T2, R3 ou R5 (§7.6).
- Toute modification de `nemetonshiny` : un brief suivra le lot 4, déposé dans
  `specs/054-…/brief-nemetonshiny.md` et notifié dans
  `/home/pascal/dev/briefs/vers-nemetonshiny/` (règle 11).

## 11. Découpage en lots

Chaque lot = une release (consignes de release de `CLAUDE.md`).

| Lot | Contenu | Bump | Prérequis |
|---|---|---|---|
| 0 | Cette spec + ADR-016 ; relevé du chiffre IGN de production nationale ; relecture de la méthodo de recrutement ; vérification de la couverture temporelle GEDI et de l'accès Earthdata | — (doc) | — |
| 1 | `estimer_fay_herriot()` + tests (égalité `sae`, σᵥ² = 0, n = 1, domaine vide) ; `data-raw/build_ifn_production.R` ; PG/PV par placette ; agrégats des jeux G et F ; comparaison selon §5.b ; FH SER × campagne avec le jeu retenu ; `ifn_production_ser.csv` + accesseurs ; contrôle national ; test de Moran | minor | D1, D3, D4, D7 |
| 2 | P2 `source = "ifn_fh"` + attributs de provenance/RSE ; ratio prélèvement/production (§7.2) | minor | lot 1, D5 |
| 3 | `completer_volume_ifn(methode = "fay_herriot")` ; test d'héritage C1 | minor | lot 1 |
| 4 | E1 `production_field` + `taux_mobilisation` + `ref_max` propre au mode flux ; détection du cas dégénéré FH-SER × `"ifn_ser"` (§7.4) ; test d'héritage E2 ; référence B2 ; brief app | minor | lot 2, D6 |
| 5 | Domaines utilisateur (UT ONF, massif) | minor | lot 1, D2 |

## 12. Références

- Onwunji et al. (2026), Ann. For. Sci. 83:46 — source de la méthode.
- Fay R.E., Herriot R.A. (1979), JASA 74:269-277.
- Rao J.N.K., Molina I. (2015), *Small Area Estimation*, 2ᵉ éd., Wiley.
- Breidenbach J., Astrup R. (2012), Eur. J. For. Res. — FH appliqué à l'inventaire forestier (référence complète dans la bibliographie de l'article).
- Schwartz M. et al. (2023), ESSD 15:4927-4945 — FORMS.
- IGN, *Documentation des données brutes de l'inventaire forestier*, v2.4
  (14/10/2025), fichier ARBRE.csv, variable IR5.
