# Spec 069 — Surmortalité : la mortalité de FINN comme référence

> **Statut** : **décisions S-1 à S-4 prises par Pascal le 2026-11-14** ;
> prochaine étape : référence d'avant-crise puis prototype régional (§ 8). Idée de
> Pascal, discutée le 2026-11-14 pendant la recalibration de FINN
> (spec 068, décision D-G).
> **Dépôt** : `nemeton` (cœur). Dépend de `calibrer_finn()` et de
> `.itin_un_pas()` (mortalité par cohorte, v2026.11.24).
> **Décisions ouvertes** : § 7, renvoyées par **[S-n]**.

## 1. Pourquoi

FINN apprend la mortalité **ordinaire** d'un peuplement : celle qui suit
la densité, la taille des tiges, l'essence et le climat moyen. Il ne
reproduit pas les crises (scolytes, chalarose, sécheresses extrêmes,
tempêtes). La différence entre la mortalité observée et celle que FINN
attend est donc une mesure de **surmortalité**, au sens des
épidémiologistes : ce qui meurt en plus de ce qui mourrait « normalement »
à cette densité.

Constat du 2026-11-14 (modèle B, 780 placettes de test BFC, un pas de
5 ans, m²/ha) :

| placette | essence dominante | G initiale | morts observés | morts FINN |
|---|---|---|---|---|
| 1305675 | sapin pectiné (61) | 51,8 | 34,7 | 4,2 |
| 1453989 | épicéa commun (62) | 58,5 | 47,4 | 20,9 |
| 1112388 | frêne (17C) | 37,1 | 26,1 | 4,8 |
| 1500047 | frêne (17C) | 52,0 | 30,7 | 10,1 |
| 910424 | sapin pectiné (61) | 53,1 | 18,2 | 0,6 |

Par essence dominante (n ≥ 15), la part de placettes avec plus de
3 m²/ha de surmortalité en 5 ans va de 0 % (robinier) et 4 à 9 % (hêtre,
chênes, charme, douglas) à 12 % (épicéa), 19 % (frêne) et 25 % (tremble,
16 placettes). Au-delà de
50 m²/ha, l'IFN observe 7,1 m²/ha de morts, FINN 4,0. En moyenne sur
toutes les classes, la mortalité de FINN suit l'observée à 0,35 m²/ha
près (spec 068, note « D'où vient le biais de croissance ») : l'excès est
concentré sur peu de placettes, ce qu'on attend de crises.

## 2. Principe

Pour une placette (ou un ensemble de placettes) entre deux dates :

- **attendu** : G des tiges mortes pendant le pas simulé par FINN depuis
  l'état initial (`attr(, "morts")` de `.itin_un_pas()`), moyenne de
  n tirages, plus la mortalité du plafond de densité si on l'applique ;
- **observé** : G initiale des tiges mortes (inventaire, ou satellite,
  § 5) ;
- **surmortalité** = observé − attendu, en m²/ha ou en % de G initiale ;
- **seuil** : quantile conforme des écarts observé − attendu mesurés sur
  le jeu conforme, comme l'intervalle de G (spec 068). Au-delà du quantile
  à 95 %, la surmortalité est « anormale ».

## 3. Les trois verrous

### 3.1 La référence doit être une mortalité ordinaire

Le modèle actuel est calibré sur les revisites IFN de 2015 à 2025. Il a
donc vu une partie des crises de 2018-2022 et en a appris une partie comme
mortalité ordinaire (le frêne : 3,3 m²/ha de morts attendus en 5 ans).
Options :

- **(a)** calibrer la référence sur les revisites antérieures aux crises
  (deuxième visite 2015-2017, première 2010-2012). La campagne est dans la
  table PLACETTE de l'IFN (`CAMPAGNE`, déjà lue par
  `data-raw/prototype_finn_calibration.R`) ; `donnees.rds` ne la porte pas,
  il faut la remonter. Compté le 2026-11-14 : 2 352 placettes BFC
  revisitées en 2015-2017 (1 724 hors conforme et test, 311 conforme,
  317 test), autant que les 1 000 de la calibration d'origine et au-delà ;
  la revisite 2018 (intervalle 2013-2018) touche déjà la crise et reste
  dehors ;
- **(b)** garder le modèle actuel et le dire : la surmortalité mesurée est
  alors un excès sur la moyenne 2015-2024, pas sur une mortalité d'avant
  les crises ;
- **(c)** exclure de la calibration les tiges mortes dont l'IFN donne une
  cause de crise, si une telle variable existe (à vérifier dans la
  documentation IFN des arbres morts ; pas supposé ici).

### 3.2 Une placette seule est trop bruitée

La mort d'une tige est un événement rare ; sur une placette IFN et
5 ans, quelques arbres font l'écart. L'indice a du sens **agrégé** :
par essence × SER × campagne pour un diagnostic régional ; par UGF dans un
projet, avec la même logique d'échelle que l'intervalle conforme d'UGF
(spec 068, v2026.11.12).

### 3.3 Il faut deux dates

- **IFN** : les revisites à 5 ans donnent l'observé sur tout le
  territoire (diagnostic régional) ;
- **projet** : deux inventaires du même peuplement (Groma, terrain) ;
- **satellite** : FORDEAD / RECONFORT (R5) détectent le dépérissement ; il
  faudrait convertir les pixels dépérissants en G morte (part de couvert
  × G du peuplement), ce qui est une hypothèse forte.

## 4. Livrables proposés

1. **Prototype** `data-raw/surmortalite_ifn_bfc.R` : surmortalité par
   essence × SER × campagne sur toutes les placettes BFC hors calibration,
   avec la référence d'avant-crise (le modèle B en attendant). Critère de réussite : l'excès doit monter avec les
   crises connues (épicéa après 2018, frêne avec la chalarose) et rester
   proche de zéro pour le hêtre et les chênes avant 2018. Aucune API tant
   que ce critère n'est pas tenu.
2. **Fonction** `surmortalite_finn(calibration, arbres, environnement,
   unites = NULL, n_tirages = 20L)` : attendu, observé, écart et seuil
   conforme, par placette ou par unité. Arbres au format de
   `calibrer_finn()` (statut `vivant` / `mort` / `coupe` / `recrute`) ;
   placettes coupées entre les deux dates exclues.
3. **Seuil** : `conformer_finn()` mesure aussi les résidus de mortalité.

## 5. Lien avec R5 et avec les trajectoires

- **R5** : aujourd'hui une part de surface dépérissante (FORDEAD /
  RECONFORT). La surmortalité dirait « combien de plus que la compétition
  ». Croiser les deux est un usage, pas un remplacement de R5 ; brancher
  R5 sur FINN demande la conversion pixel → G de § 3.3, à ne pas faire
  avant le prototype.
- **Trajectoires** (spec 068) : FINN reste la dynamique de fond ; les
  crises s'ajoutent comme **scénario de perturbation** séparé (taux de
  mortalité par essence et par décennie, tiré de la surmortalité
  observée), plutôt qu'en corrigeant la mortalité de FINN. La classe
  ≥ 50 m²/ha de la spec 068 relève de ce scénario.

## 6. Ce que ce n'est pas

- Pas un diagnostic de cause : la surmortalité dit « plus que prévu »,
  pas « scolytes ». La cause vient de l'essence, de la date, de R5 ou du
  terrain.
- Pas un indicateur des 43 tant que S-3 n'est pas tranchée.

## 7. Décisions ouvertes

- **[S-1]** Référence : (a) calibration d'avant 2018, (b) modèle actuel
  et dire ce qu'il mesure, (c) exclusion par cause si l'IFN la donne.
  **Décidé par Pascal le 2026-11-14 : (a).** Les 1 724 placettes
  d'avant-crise calibrent la référence (poids du modèle B), le conforme
  est restreint aux 311 placettes conformes revisitées en 2015-2017 ; la
  surmortalité se lit sur les revisites 2018-2025.
- **[S-2]** Échelle d'agrégation par défaut : placette (avec avertissement)
  ou unité seulement. **Décidé par Pascal le 2026-11-14 : par unité**
  (UGF, ou essence × SER × période en diagnostic régional) ; le chiffre
  par placette reste disponible en diagnostic, avec un avertissement.
- **[S-3]** Statut : diagnostic (fonction du cœur, sans famille) ou
  composante de R5. **Décidé par Pascal le 2026-11-14 : diagnostic
  d'abord** (fonction du cœur, hors des 43 indicateurs) ; R5 seulement
  après le prototype et la conversion pixel → G.
- **[S-4]** Seuil : quantile à 95 % des résidus conformes, ou 90 % comme
  l'intervalle de G. **Décidé par Pascal le 2026-11-14 : 95 %**
  (on cherche l'anormal).

## 8. Ordre proposé

1. ~~Compter les placettes BFC par campagne~~ (fait, § 3.1) ; ~~remonter
   `CAMPAGNE` dans les données FINN et calibrer la référence 2015-2017~~
   (fait le 2026-11-14, 6,1 h).
2. ~~Prototype régional (§ 4.1)~~ avec la référence d'avant-crise (fait le
   2026-11-14, § 9) : critère tenu.
3. ~~Décisions S-1 à S-4 par Pascal~~ (prises le 2026-11-14, § 7).
4. ~~`surmortalite_finn()`, tests, release~~ (v2026.11.27, § 10).

## 9. Prototype régional : résultats (2026-11-14)

`data-raw/surmortalite_ifn_bfc.R`, référence FINN calibrée sur les
1 724 placettes BFC revisitées en 2015-2017 (400 époques, poids du
modèle B ; demi-largeur conforme de G 3,98 m²/ha). Un pas de 5 ans,
5 tirages, sur les placettes hors de cette calibration et non coupées :
241 conformes et 255 de test revisitées en 2015-2017 (« avant »), 4 102
revisitées de 2018 à 2025 (« crise »). 17 min.

**Seuil** (S-4) : quantile conforme à 95 % de l'écart observé − attendu
par placette, toutes essences : **2,45 m²/ha** de morts en plus en 5 ans.

**Avant les crises, la référence tient.** Écart moyen par campagne de
− 0,24 à + 0,10 m²/ha sur les deux jeux ; part des placettes de test
au-dessus du seuil : 4,1 %, 6,6 %, 3,7 % (attendu 5 %).

**Après 2018, l'excès monte** (moyenne par placette, m²/ha en 5 ans ;
part au-dessus du seuil) :

| Revisite | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
|---|---|---|---|---|---|---|---|---|
| Observé | 0,69 | 0,88 | 1,07 | 1,56 | 1,41 | 2,02 | 1,68 | 1,71 |
| Attendu | 0,68 | 0,69 | 0,85 | 0,83 | 0,72 | 0,80 | 0,76 | 0,66 |
| Excès | 0,01 | 0,18 | 0,22 | 0,74 | 0,69 | 1,22 | 0,93 | 1,06 |
| > seuil | 5,9 % | 7,9 % | 9,2 % | 14,8 % | 13,0 % | 20,0 % | 19,1 % | 17,0 % |

**Par essence** (placettes où elle est présente ; observé / attendu
[IC bootstrap 95 %], excès en m²/ha et en % de la G initiale de
l'essence) :

| Essence | 2015-17 | 2018-20 | 2021-25 | Excès 2021-25 |
|---|---|---|---|---|
| Épicéa commun | 0,36 [0,04-0,71] | 0,98 [0,47-1,73] | **4,90 [3,13-6,77]** | 1,36 (9,4 %) |
| Frêne | 0,66 [0,17-1,30] | 1,51 [1,15-1,92] | **2,95 [2,36-3,62]** | 1,19 (18,4 %) |
| Hêtre | 1,37 [0,17-3,37] | 0,92 [0,49-1,46] | 1,06 [0,73-1,47] | 0,01 (0,2 %) |
| Chêne sessile | 0,65 [0,35-1,02] | 1,07 [0,82-1,34] | 1,87 [1,52-2,22] | 0,18 (1,5 %) |
| Chêne pédonculé | 0,85 [0,28-1,62] | 1,50 [1,02-2,08] | 2,40 [1,86-2,94] | 0,21 (2,3 %) |
| Sapin pectiné | 1,61 [0,00-4,03] | 1,09 [0,49-1,99] | 1,78 [1,12-2,55] | 0,40 (2,7 %) |
| Douglas | — | 0,47 [0,12-1,05] | 0,99 [0,52-1,61] | − 0,01 (0,0 %) |
| Charme | 0,90 [0,41-1,48] | 1,57 [1,25-1,92] | 4,35 [3,70-5,14] | 0,33 (4,5 %) |
| Pin sylvestre | 0,44 [0,05-0,82] | 0,76 [0,36-1,94] | 1,67 [1,02-2,77] | 0,51 (5,8 %) |
| Bouleau verruqueux | 1,50 [0,59-2,48] | 1,82 [0,92-3,02] | 3,23 [2,38-4,18] | 0,56 (14,1 %) |

Lecture :

- **Critère de § 4.1 tenu** : l'épicéa saute à la revisite 2021
  (intervalle 2016-2021, sécheresses et scolytes de 2018-2020) et reste
  haut jusqu'en 2025 (excès 0,9 à 1,8 m²/ha par campagne) ; le frêne
  monte dès 2018-2020 puis double (chalarose) ; le hêtre reste à 1 et les
  chênes sont sous 1 avant 2018 ; le douglas reste à 1.
- Les chênes montent modérément en 2021-25 (+ 0,2 m²/ha) : dépérissement
  du chêne pédonculé connu, à confirmer avant de l'affirmer.
- **Le rapport trompe quand l'attendu est faible** : charme 4,35 pour un
  excès de 0,33 m²/ha seulement. L'excès en m²/ha (et en % de G) est le
  chiffre à rendre, le rapport un complément.
- **Par SER** (n ≥ 20), l'épicéa 2021-25 : excès 2,85 m²/ha en C20,
  1,67 en E10, 1,24 en G23, 0,98 en E20 ; le frêne 2021-25 : 1,82 en C51,
  1,66 en E10, 1,10 en C20, 0,55 en E20. La surmortalité se régionalise,
  ce que demande S-2.
- La mortalité observée compte toutes les tiges mortes entre les visites
  (chablis compris) hors coupes : la tempête et la sécheresse ne se
  séparent pas ici (§ 6).

Suite : `surmortalite_finn()` (§ 4.2) et le résidu de mortalité dans
`conformer_finn()` (§ 4.3).

## 10. `surmortalite_finn()` (v2026.11.27)

`surmortalite_finn(calibration, arbres, environnement, unites = NULL,
niveau = 0.95, n_tirages = 20L, correction = TRUE)` : par placette (avec
avertissement, S-2) ou par unité (moyenne des placettes), `g_initiale`,
`mort_observee`, `mort_attendue`, `surmortalite`, `surmortalite_pct`,
`seuil`, `anormale`. Placettes coupées écartées ; placettes de la
calibration signalées. `conformer_finn(mortalite = TRUE)` garde les
résidus de mortalité de ses placettes (NA pour les coupées) ; le seuil
d'une unité de `k` placettes vient de groupes de `k` placettes tenues à
l'écart (voisines si les coordonnées sont données), comme l'intervalle de
G ; il vaut NA quand on ne peut pas former 30 groupes.

Contrôle sur données réelles (référence 2015-2017, 5 tirages,
`conformer_finn()` sur les 241 placettes conformes d'avant-crise) : seuil
par placette 2,50 m²/ha (prototype 2,45) ; placettes test d'avant-crise
au-dessus : 4,3 % ; revisites 2018 à 2025 : 5,9, 6,7, 8,8, 14,6, 13,2,
19,3, 18,9, 16,2 % ; excès moyen identique au prototype à 0,02 m²/ha
près. Seuil d'une unité de 4 placettes (groupes au hasard, sans
coordonnées) : 1,60 m²/ha.

