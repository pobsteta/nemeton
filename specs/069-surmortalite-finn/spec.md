# Spec 069 — Surmortalité : la mortalité de FINN comme référence

> **Statut** : **brouillon, ouvert avant le code** (2026-11-14). Idée de
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
  composante de R5. Proposition : diagnostic d'abord, R5 après le
  prototype et la conversion pixel → G.
- **[S-4]** Seuil : quantile à 95 % des résidus conformes, ou 90 % comme
  l'intervalle de G. Proposition : 95 % (on cherche l'anormal).

## 8. Ordre proposé

1. ~~Compter les placettes BFC par campagne~~ (fait, § 3.1) ; remonter
   `CAMPAGNE` dans les données FINN et calibrer la référence 2015-2017
   (~7 h, comme le modèle B).
2. Prototype régional (§ 4.1) avec le modèle B ; résultat écrit ici.
3. Décisions S-1 à S-4 par Pascal.
4. `surmortalite_finn()`, tests, release.
