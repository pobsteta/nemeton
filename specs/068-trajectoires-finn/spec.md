# Spec 068 — Dynamique et causalité : trajectoires FINN, T4, effets de la gestion

> **Statut** : **validée par Pascal le 2026-11-06** (décisions D-1 à D-8
> retenues telles que proposées). Première étape : `effet_gestion()`.
> **Origine** : brief « Modèles de fondation et raisonnement sylvicole » du
> 2026-11-05, chantier D (priorité 3, « année 2 ») et § 3.2.
> **Dépôt** : `nemeton` (cœur). FINN reste un paquet R (torch pour R, pas de
> Python) : ADR-009 n'est pas en cause, mais la dépendance est lourde (D-1).
> **Décisions ouvertes** : § 8, renvoyées par **[D-n]**.

## 1. Pourquoi

`comparer_itineraires()` (spec 065) compare des itinéraires sur des effets
**qualitatifs** (`+ 0 - ?`) tirés du catalogue. Il ne dit ni de combien ni
quand. Le chantier D remplit l'argument réservé `trajectoires =` avec des
trajectoires simulées, et confronte la simulation à ce que la gestion a
réellement produit.

## 2. Ce qui existe, vérifié le 2026-11-06

**FINN** (*Forest Informed Neural Networks*, Pichler et Käber 2026, *Methods in
Ecology and Evolution*, doi 10.1111/2041-210x.70347) :

- paquet R sur CRAN, **v0.1.0 du 2026-08-09**, licence **GPL-3**
  (`github.com/finnverse/finn`), compatible avec le cœur ;
- modèle de trouées différentiable : des cohortes (même essence, même taille)
  mises à jour à chaque pas par quatre processus, compétition, croissance,
  mortalité, régénération ; chacun peut être mécaniste, neuronal ou hybride ;
  calibration par gradient ;
- s'appuie sur **torch pour R** (libtorch, C++), GPU optionnel ;
- vignettes : prise en main, paramétrage par les indicateurs d'Ellenberg,
  préparation des données d'arbres, ajustement sur l'inventaire FIA (Oregon).

**Ce qui n'a pas pu être vérifié** : l'API exacte (`finn()`, création des
processus, format des cohortes et du climat, sorties). CRAN et son miroir de
l'ETH sont bloqués depuis la session ; la page GitHub ne la détaille pas.
**Aucune mention d'interventions sylvicoles** (coupes, éclaircies) n'a été
trouvée : la documentation lue ne parle que des quatre processus
démographiques. C'est le point dur du chantier (D-2).

**Côté cœur**, briques mécanistes existantes que le brief propose de reprendre :
`ifn_production_ser()` / `ifn_production_reference()` (production par SER),
`n_max_selfthinning()` (auto-éclaircie, Charru), `bai_drift_factor()` (dérive
climatique de l'accroissement, Charru et al. 2017), `charger_forms_t_hauteurs()`
(séries de hauteurs FORMS-T, spec 060), `comparer_itineraires(trajectoires =)`
réservé depuis la spec 065.

## 3. Livrables

### 3.1 `effet_gestion()` — ce que la gestion a produit (sans FINN)

`effet_gestion(units, traitement = "type_sylviculture", resultats = familles,
covariables = c("P2", "altitude", "pente", "ser"), methode = c("x_learner",
"t_learner"))`

- méta-apprenant T ou X (ranger, déjà en Suggests) : effet individuel du
  traitement sur chaque famille (ou indicateur), par UGF, avec intervalle
  (bootstrap) ;
- **diagnostic de recouvrement** : score de propension (régression logistique
  ou ranger) ; les UGF hors du support commun sont exclues et comptées ;
  **refus explicite** (`statut = "recouvrement_insuffisant"`) quand moins d'une
  part donnée des UGF est dans le support commun (D-4) ;
- sortie : par UGF et par famille, `effet`, `ic_bas`, `ic_haut`, `support`
  (logique) ; un résumé par famille (effet moyen sur le support commun) ;
- garde-fous écrits dans la fiche : association, pas causalité, sans
  hypothèse d'absence de confusion ; un traitement déclaré n'est pas un
  traitement appliqué ; peu d'UGF par traitement → intervalles larges.

Utile tout de suite, sur tout projet où le type de sylviculture est déclaré,
et testable sur données simulées à effet connu.

### 3.2 `calibrer_finn()` et `simuler_itineraire()` — trajectoires

- `calibrer_finn(placettes, climat, ser, processus = "mecaniste")` : cohortes
  initiales depuis des placettes (IFN, QField, inventaire vidéo), climat par
  `meteoland_daily_grid()` / E-OBS (spec 063) ; processus mécanistes d'abord,
  paramétrés depuis les briques du cœur (production par SER, auto-éclaircie,
  dérive de l'accroissement), remplacés un à un par des composantes neuronales
  quand le projet a assez de placettes (D-3) ;
- `simuler_itineraire(units, itineraire, horizon = 50, n = 100, modele)` :
  pour chaque UGF admissible (spec 065), `n` trajectoires sous un itinéraire
  du catalogue ; les règles de l'itinéraire (rotation, intensité de
  prélèvement, diamètre d'exploitabilité, surface terrière cible) sont
  appliquées **entre les pas de FINN**, en retirant des cohortes (D-2) ;
- sortie : table longue `unite`, `itineraire`, `annee`, `variable`,
  `mediane`, `q05`, `q95`, pour les variables que FINN porte (surface
  terrière, tiges, diamètre, hauteur, volume) et les indicateurs qui s'en
  déduisent (P1, C1, B2, R2 ; B5 et N4 si un lien structure → strates est
  établi, D-5) ;
- `comparer_itineraires(trajectoires =)` consomme cette table : la méthode
  passe de `"catalogue_qualitatif"` à `"simulation"`, `score_global` devient
  une note ; pas avant que la simulation soit validée (§ 7).

### 3.3 T4 — vitalité dynamique

Écart entre la trajectoire **observée** (FORMS-T 2019-2024, ou FORMSpoT
2014-2025 si disponible, hauteur dominante par UGF) et la trajectoire
**attendue** par FINN sous l'itinéraire déclaré, rapporté à la dispersion des
trajectoires simulées : T4 > 50 l'UGF fait mieux que prévu, < 50 décroche.
Conditionnel : au moins 6 années de série et un modèle calibré. Nouvel
indicateur de la famille T (44 → selon N4, D-6). Fiche obligatoire.

## 4. Pièges à écrire dans les fiches

1. **Un modèle calibré ailleurs.** FINN est démontré sur la FIA de l'Oregon ;
   sans calibration sur placettes françaises, les trajectoires sont des
   ordres de grandeur.
2. **La gestion n'est pas dans FINN.** Les coupes sont imposées de l'extérieur
   (D-2) : la réponse du peuplement à une éclaircie (accélération de
   l'accroissement) n'est pas apprise, sauf si des placettes éclaircies
   entrent dans la calibration.
3. **Climat futur.** Une trajectoire à 50 ans dépend du scénario climatique ;
   sans scénario explicite, elle suppose le climat récent.
4. **Effet de gestion ≠ causalité.** Voir 3.1.
5. **T4 compare deux incertitudes** : la hauteur observée (FORMS-T, erreur de
   l'ordre du mètre) et la trajectoire simulée.

## 5. Ordre proposé

1. `effet_gestion()` (cœur, ranger, sans FINN) : valeur immédiate, testable.
2. Prototype FINN hors du cœur (script `data-raw/`) : vérifier l'API, la
   possibilité de retirer des cohortes entre deux pas, les temps de calcul sur
   CPU pour 100 UGF × 100 trajectoires × 50 ans.
3. `calibrer_finn()` + `simuler_itineraire()` si le prototype tient ; sinon
   révision de la spec.
4. T4, puis `comparer_itineraires(trajectoires =)`.

## 6. Écarts cœur → app

À ouvrir à la validation : trajectoires dans l'onglet plan d'actions (bloc
`trajectoires` de Victor, réservé depuis la spec 065) ; effets de la gestion
dans la synthèse ; T4 (couche, statut).

## 7. Critères d'acceptation

1. `effet_gestion()` retrouve, sur données simulées, un effet connu dans son
   intervalle, et refuse quand le recouvrement est insuffisant.
2. FINN calibré sur au moins 200 placettes IFN de BFC : erreur de prédiction de
   la surface terrière à 5 ans (placettes revisitées) publiée dans la fiche.
3. Temps : 100 UGF × 100 trajectoires × 50 ans en moins d'une heure de CPU,
   ou passage au GPU ponctuel (ADR-003).
4. Fiches `effet_gestion`, trajectoires et T4 complètes (spec 052).

## 8. Décisions ouvertes

| # | Question | Décision (validée le 2026-11-06) |
|---|---|---|
| D-1 | FINN (et torch pour R) dans le cœur ? | **Suggests** du cœur, fonctions qui s'arrêtent proprement sans FINN ; pas de paquet amont, puisqu'il n'y a pas de Python. Alternative : `finnnemeton` amont si l'installation de torch pèse trop sur la CI |
| D-2 | Interventions sylvicoles : FINN n'en documente pas | simuler pas à pas et **retirer des cohortes entre deux pas** selon les règles de l'itinéraire ; à vérifier sur le prototype (étape 2) avant tout code dans le cœur |
| D-3 | Processus neuronaux : quand ? | mécaniste seul en première version ; neuronal seulement avec une validation croisée qui montre un gain sur placettes revisitées |
| D-4 | Seuil de recouvrement d'`effet_gestion()` | refus si moins de 70 % des UGF sont dans le support commun ou si un traitement a moins de 10 UGF ; seuils affichés comme conventions |
| D-5 | B5 et N4 dans les trajectoires | non en première version : FINN porte des cohortes (diamètre, hauteur), pas un nuage ; B2 oui (CV des hauteurs) |
| D-6 | T4 : nouveau code de la famille T, et son échelle | oui, T4 conditionnel ; décompte 43 → 44 (45 avec N4). Le brief le définit en signe (> 0 / < 0) ; proposé : score 0-100 centré sur 50 (rang de l'observé dans les trajectoires simulées), pour qu'il se normalise comme les autres |
| D-7 | Données de calibration | export IFN déjà dans `data-raw/ifn/` (Licence Ouverte) : placettes de BFC revisitées à 5 ans, revisites 2015 et suivantes ; FORMS-T pour T4 |
| D-8 | TerraMind (optionnel du brief) | **hors de cette spec** : à n'ouvrir que si le besoin outre-mer se confirme |

## 9. Avancement

| Étape | État |
|---|---|
| 1. `effet_gestion()` | ✅ **2026.11.8** — fiche, écart n° 27 |
| 2. Prototype FINN (`data-raw/prototype_finn.R`) | ✅ 2026-11-07 — **D-2 tient** (voir ci-dessous) ; temps CPU très en dessous du critère 3 |
| 3. `calibrer_finn()`, `simuler_itineraire()` | prototype de calibration ✅ 2026-11-08 ; **`calibrer_finn()` + `predire_finn()` ✅ 2026-11-09 (v2026.11.9)** : 3,36 m²/ha hors calibration (voir ci-dessous) ; **`simuler_itineraire()` + `conformer_finn()` ✅ 2026-11-09 (v2026.11.11)** |
| 4. T4, `comparer_itineraires(trajectoires =)` | **`comparer_itineraires(trajectoires =)` ✅ 2026-11-10 (v2026.11.15)**, avant T4 (voir ci-dessous) ; T4 à faire |

**Écart au § 3.1 lors du codage.** L'effet moyen n'est pas la moyenne des
effets individuels du méta-apprenant : sur données simulées (150 UGF, effet
8, forte confusion), cette moyenne valait 8,8 (X) ou 10,9 (T) avec des
intervalles de bootstrap qui couvraient l'effet réel dans 60 % et 10 % des
cas. Il est remplacé par un estimateur doublement robuste (AIPW, prédictions
hors sac des forêts) : 7,1 en moyenne, couverture de 93 % pour un intervalle
à 90 % (30 tirages). Les effets par UGF restent ceux du méta-apprenant.

**Prototype FINN, 2026-11-07** (`data-raw/prototype_finn.R`, FINN 0.1.0 et
torch installés dans une bibliothèque à part, CPU 8 cœurs, sans GPU ;
paramètres mécanistes de la vignette A de FINN, **non calibrés** : ce sont
des ordres de grandeur d'API, pas une forêt).

- **Ce que FINN offre** : `disturbance` = fraction des placettes **vidées**
  chaque année (tirage de Bernoulli par placette, `trees × 0`) ; c'est une
  perturbation totale, l'équivalent d'une coupe rase par placette. **Aucune
  coupe sélective.**
- **D-2 vérifiée** : la simulation se reprend pas à pas. `return_cohorts =
  "last"` rend les cohortes (format long `variable` / `value`, à passer en
  large) ; on les modifie, puis `init_cohort = CohortMat$new(obs_df = ...)`
  relance. Sans gestion, la surface terrière par pas de 10 ans (54,5 / 54,3 /
  53,2 m²/ha aux années 50, 100, 150) reste dans le bruit de la simulation
  continue (52,6 / 50,9 / 54,4).
- **Une éclaircie se voit** : retirer 30 % des tiges ≥ 20 cm tous les 10 ans
  à partir de 50 ans donne 47,9 et 45,5 m²/ha aux années 100 et 150 ; une
  éclaircie fait passer G de 52,4 à 34,6 m²/ha, que FINN refait monter à
  43,4 en 10 ans par la compétition pour la lumière.
- **Piège trouvé** : sur des placettes de 0,1 ha, les gros arbres sont des
  cohortes d'**une seule tige** ; arrondir `trees × (1 − taux)` ne coupe
  rien. L'éclaircie doit tirer les tiges coupées (binomiale).
- **Temps** : 100 sites × 100 placettes × 50 ans en **21 s de CPU** ; le
  critère 3 (< 1 h) tient sans GPU. torch pour R (libtorch, ≈ 1 Go) suffit,
  sans Python : D-1 (FINN en Suggests) confirmée.

**Suite** : étape 3, `calibrer_finn()` et `simuler_itineraire()`, attend les
placettes IFN de BFC (D-7) ; sans calibration, les trajectoires restent des
ordres de grandeur.

**Prototype de calibration, 2026-11-08** (`data-raw/prototype_finn_calibration.R`,
CPU, FINN 0.1.0, processus mécanistes, altitude seule comme variable
d'environnement).

- **Données** : 8 119 placettes de BFC revisitées à 5 ans (revisites
  2015-2025), 85 exclues (arbre non retrouvé, accroissement hors de
  [−5, +15] cm), 7 635 gardées ; 15 essences couvrant 90 % de la surface
  terrière, le reste en « autres ». Un pas FINN = 5 ans, une placette FINN =
  le cercle de 15 m, chaque arbre pèse W × 0,0707 tiges.
- **Ce que l'export IFN ne donne pas** : la revisite ne porte **aucun poids
  W** ; un arbre suivi garde celui de sa 1re visite, un recruté reçoit le
  poids théorique de son cercle (6, 9 ou 15 m selon C13).
- **Coupes** : les arbres coupés entre les deux visites sont retirés de
  l'état initial (coupe supposée en début d'intervalle, comme D-2). FINN
  n'apprend que la dynamique naturelle.
- **Résultat** (1 000 placettes de calibration, 1 000 tenues à l'écart, 300
  époques, 19 min de CPU), surface terrière totale à 5 ans, m²/ha :

  | Échantillon | Modèle | RMSE | Biais | R² |
  |---|---|---|---|---|
  | calibration | FINN | 4,17 | +1,58 | 0,89 |
  | calibration | persistance | 3,89 | −2,05 | 0,90 |
  | tenu à l'écart | FINN | 3,90 | +1,33 | 0,91 |
  | tenu à l'écart | persistance | 3,74 | −2,31 | 0,92 |

  La persistance (G à 5 ans = G initiale après coupes) est le modèle nul.
  **FINN ne la bat pas en RMSE** ; il réduit le biais (il fait croître le
  peuplement, la persistance non) mais en surestimant la croissance.
- **Critère 2** : l'erreur est publiée sur plus de 200 placettes, il est donc
  formellement rempli ; mais tant que FINN ne fait pas mieux que la
  persistance à 5 ans, une trajectoire à 50 ans n'a pas de valeur
  démontrée. `simuler_itineraire()` ne doit pas sortir avant.
- **Pistes, dans l'ordre** : climat (E-OBS, spec 063) et sol (ECOLOGIE) en
  plus de l'altitude ; plus de placettes de calibration (7 635 disponibles) ;
  croissance hybride (réseau de neurones, vignette D de FINN) ; écarter les
  placettes coupées de la calibration pour voir si elles brouillent le signal.

**Piste 1, climat et sol, 2026-11-08** (`FINN_ENV=climat_sol`, défaut du
script) : moyenne des tx de juin-août et cumul annuel de rr sur les 5 ans de
l'intervalle (E-OBS v33.0e mensuel, cache de la spec 063), profondeur de
sondage PROF2 (ECOLOGIE). L'altitude sort : elle est corrélée à −0,77 avec tx
et à 0,77 avec rr.

| Échantillon | Modèle | RMSE | Biais | R² |
|---|---|---|---|---|
| calibration | FINN | 3,89 | +1,11 | 0,90 |
| calibration | persistance | 4,24 | −2,11 | 0,88 |
| tenu à l'écart | FINN | 4,14 | +0,98 | 0,90 |
| tenu à l'écart | persistance | 3,94 | −2,08 | 0,91 |

(1 000 / 1 000 placettes, 300 époques, 21 min de CPU ; le tirage diffère un
peu de celui de l'altitude seule, d'où la persistance qui change.) Le climat
et le sol font passer FINN devant la persistance **sur les placettes de
calibration**, pas sur celles tenues à l'écart : le rapport RMSE FINN /
persistance y reste à 1,05 (1,04 avec l'altitude seule). Le gain ne se
transfère pas ; avec 1 000 placettes et 16 essences, FINN apprend du bruit.
Piste suivante : plus de placettes de calibration (6 600 disponibles hors
test).

**Piste 2, plus de placettes, 2026-11-08** (`FINN_N_TRAIN=5000`) : le tirage
du test passe en premier, il ne dépend donc plus de la taille de la
calibration (`FINN_N_TRAIN=0` prend tout le reste). 7 632 placettes
disponibles, 5 000 en calibration, 1 000 tenues à l'écart, climat et sol,
300 époques, 2 h de CPU.

| Échantillon | Modèle | RMSE | Biais | R² |
|---|---|---|---|---|
| calibration | FINN | 4,40 | +1,84 | 0,88 |
| calibration | persistance | 4,11 | −2,13 | 0,90 |
| tenu à l'écart | FINN | 4,55 | +1,93 | 0,86 |
| tenu à l'écart | persistance | 4,24 | −2,11 | 0,88 |

Cinq fois plus de placettes ne rapprochent pas FINN de la persistance : il
fait maintenant moins bien qu'elle **même sur sa calibration**, et son biais
monte de +1,0 à +1,9 m²/ha (il surestime l'accroissement). Ce n'est donc pas
seulement du sur-apprentissage : avec ces réglages (pas d'apprentissage 0,01,
lots de 50, 300 époques), l'ajustement n'atteint pas la persistance. Pistes
restantes : comparer d'abord à un modèle nul plus exigeant (persistance plus
accroissement moyen observé), puis croissance hybride (vignette D) et
placettes coupées écartées.

**Modèles nuls plus exigeants, 2026-11-08** (même tirage que la piste 2,
`FINN_EPOCHS=0` : modèles nuls seuls, quelques secondes). Ajustés sur les
5 000 placettes de calibration, évalués sur les 1 000 tenues à l'écart :

| Modèle | RMSE | Biais | R² |
|---|---|---|---|
| FINN (piste 2, 2 h de CPU) | 4,55 | +1,93 | 0,86 |
| persistance (G5 = G0) | 4,24 | −2,11 | 0,88 |
| persistance + accroissement moyen (+2,13 m²/ha) | 3,68 | +0,03 | 0,91 |
| régression linéaire G5 ~ G0 + tx_ete + rr_an + prof | 3,58 | +0,05 | 0,91 |

La barre que FINN doit franchir n'est pas 4,24 mais **3,58 m²/ha** : une
régression linéaire sur la surface terrière de départ et l'environnement. FINN
en est à 0,97 m²/ha (+27 %). Ce sont ces deux modèles nuls, pas la seule
persistance, qui servent désormais de référence au critère de D-3 et à
`calibrer_finn()`.

**Réglages de l'ajustement, 2026-11-08** (`FINN_LR`, 1 000 placettes de
calibration, même test de 1 000 placettes, 600 époques, deux runs en
parallèle de 4 threads, 1,1 à 1,2 h chacun). Sur les placettes tenues à
l'écart :

| Modèle | RMSE | Biais |
|---|---|---|
| FINN, lr 0,01, 600 époques | 4,30 | +1,49 |
| FINN, lr 0,003, 600 époques | 4,15 | +1,37 |
| persistance | 4,24 | −2,11 |
| persistance + accroissement moyen | 3,68 | −0,02 |
| régression linéaire G0 + climat + sol | 3,58 | 0,00 |

Un pas plus fin aide un peu (4,15, FINN passe juste devant la persistance),
mais reste à 0,57 m²/ha de la régression linéaire. Le biais positif tient
dans tous les réglages (+1,0 à +1,9 m²/ha) : FINN surestime l'accroissement
de façon systématique, ce que l'optimiseur seul ne corrige pas. Avant la
croissance hybride, il faut savoir quel processus le produit : décomposer
l'écart en croissance des survivants, mortalité et recrutement, observés
contre simulés.

**Arrondi des effectifs et décomposition, 2026-11-08.** `CohortMat` (FINN
0.1.0, `CohortMat.R`) arrondit les effectifs des cohortes à l'entier. Sur une
placette FINN de 0,0707 ha (le cercle de 15 m), un arbre du cercle de 6 m
compte 6,25 tiges ramenées à 6, un du cercle de 9 m 2,78 ramenées à 3 : sans
biais en moyenne (+0,07 m²/ha) mais avec 1,41 m²/ha d'écart-type par
placette sur G initiale ; les recrutés, une tige entière au minimum, pèsent
aussi trop lourd. `FINN_PATCH_MULT=10` prend une placette FINN de 0,707 ha à
densité par hectare inchangée, et l'arrondi ne compte presque plus.
`FINN_N_PRED=10` moyenne dix tirages de `predict()`, qui est stochastique.
1 000 placettes de calibration, lr 0,003, 600 époques, 1 h ; même test :

| Modèle (tenu à l'écart) | RMSE | Biais | R² |
|---|---|---|---|
| FINN, placette 0,0707 ha | 4,02 | +1,36 | 0,89 |
| **FINN, placette 0,707 ha** | **3,50** | **+0,33** | **0,92** |
| régression linéaire G0 + climat + sol | 3,58 | 0,00 | 0,91 |
| persistance + accroissement moyen | 3,68 | −0,02 | 0,91 |
| persistance | 4,24 | −2,11 | 0,88 |

**FINN bat les trois modèles nuls sur des placettes qu'il n'a pas vues** : le
critère d'acceptation 2 est rempli en mécaniste. L'écart à la régression est
faible (0,08 m²/ha) et vient d'un seul tirage du test, sans intervalle de
confiance.

Décomposition de G5 − G0 (`data-raw/diagnostic_finn_processus.R`, modèles
sauvegardés par `FINN_MODELE`), m²/ha, placettes tenues à l'écart, écart =
FINN − observé :

| Part | Observé | Écart, 0,0707 ha | Écart, 0,707 ha | RMSE, 0,707 ha |
|---|---|---|---|---|
| G0 (après arrondi) | 23,67 | +0,16 | −0,01 | 0,15 |
| croissance des survivants | 2,90 | +0,24 | +0,20 | 1,93 |
| mortalité (perte) | 1,05 | −0,30 | −0,06 | 2,58 |
| recrutement | 0,26 | +0,66 | +0,08 | 0,57 |

Avec la petite placette, la moitié du biais (+0,66 sur +1,36) venait du
recrutement : une recrue y vaut au moins 14 tiges/ha. Les trois parts sont
presque sans biais avec la grande placette ; l'erreur restante est surtout
celle de la mortalité (RMSE 2,58 m²/ha), faite de quelques gros arbres qui
meurent ou non, que la persistance et la régression ne prédisent pas mieux.
**Conséquence pour `calibrer_finn()` et `simuler_itineraire()`** : placette
FINN de 0,7 ha au moins (ou poids entiers par construction) et moyenne de
plusieurs tirages ; à écrire dans la fiche.

### `calibrer_finn()` et `predire_finn()` dans le cœur (2026-11-09, v2026.11.9)

Signature retenue, plus étroite que celle du § 3.2 : `calibrer_finn(arbres,
environnement, processus = "mecaniste", surface_placette = 0.7, ...)`. La
fonction prend une table d'arbres déjà appariée entre deux visites
(`placette`, `essence`, `d1`, `d2`, `poids`, `statut`) et une table
d'environnement par placette. Lire l'IFN, extraire le climat (E-OBS,
`meteoland_daily_grid()`) et la SER reste en amont : la même fonction sert
ainsi aux placettes IFN, QField ou d'inventaire. `predire_finn()` rend G après
`pas` pas, en moyenne de `n_tirages` tirages. FINN et torch sont en Suggests
(D-1) ; les processus neuronaux sont refusés (D-3).

La préparation des tables (R de base, testée sans FINN) reproduit à
l'identique celle du prototype sur les 7 632 placettes de BFC (obs, état
initial, `recruits_dbh`). Calibration de bout en bout avec la fonction du cœur,
même tirage (1 000 placettes de calibration, 1 000 tenues à l'écart, placette
FINN de 0,7 ha, 600 époques, lr 0,003, 10 tirages, 40 min de CPU) : **RMSE
3,36 m²/ha, biais +0,37** (prototype : 3,50 ; régression 3,58 ; persistance
4,24). L'écart au prototype vient de la graine (posée juste avant `finn()`) :
c'est un second tirage, pas un gain. Les quantiles 5-95 % des tirages ne
contiennent que 19 % des valeurs observées : ils montrent la stochasticité
démographique de FINN, pas l'incertitude des paramètres. Pour les
trajectoires de `simuler_itineraire()`, il faudra donc une autre source
d'incertitude (plusieurs calibrations, ou ré-échantillonnage des placettes).

Deux contraintes de FINN 0.1.0 trouvées en route : `createProcess()` évalue
sa formule dans l'espace de noms de FINN (on la lui passe par `do.call`), et
`fit()` jette le dernier lot incomplet (taille de lot bornée au nombre de
placettes).

### Incertitude des prédictions (2026-11-09)

`data-raw/prototype_finn_incertitude.R` : trois sources d'incertitude
comparées sur les mêmes 1 000 placettes tenues à l'écart. Chaque calibration
porte sur 1 000 placettes, avec une placette FINN de 0,7 ha et 10 tirages par
modèle ; l'intervalle visé est à 90 %.

| Source | RMSE | Biais | Couverture 90 % | Largeur moyenne (m²/ha) |
|---|---|---|---|---|
| un modèle seul (tirages) | 3,35 à 3,41 | +0,37 à +0,45 | 0,21 | 1,0 |
| 4 graines, ensemble | 3,37 | +0,42 | 0,26 | 1,25 |
| 4 bootstraps, ensemble | 4,96 | +0,65 | 0,38 | 3,0 |
| conforme (1 modèle, résidus sur 1 000 autres placettes) | 3,36 | +0,38 | **0,92** | 9,5 |

- **Graines** : les quatre modèles sont presque identiques (écart-type entre
  modèles de G prédite, médiane 0,15 m²/ha). La variance d'optimisation est
  négligeable : plusieurs graines n'apportent pas d'incertitude utile.
- **Bootstrap** : plus de variance de paramètres (0,42 m²/ha), mais deux
  modèles sur quatre **explosent** sur quelques placettes. Exemple : 443 m²/ha
  prédits pour 13 m²/ha au départ (RMSE 13,8, contre 2,7 sans le 1 % de
  placettes extrêmes). Ces placettes portent des essences rares (54, 20G :
  130 à 140 arbres en calibration) qui passent juste au-dessus du seuil de
  90 % de G et reçoivent leurs propres paramètres. Le bootstrap rend ces
  paramètres instables.
- **Conforme** (split conformal, Lei et al. 2018) : la couverture est
  atteinte (92 % pour 90 % visés) sans toucher à la prédiction centrale, pour
  le coût d'un seul modèle. Demi-largeur 4,75 m²/ha : c'est l'erreur réelle
  d'une placette à 5 ans, mortalité des gros arbres comprise.

**Conséquences.**
1. Pour `simuler_itineraire()`, l'intervalle viendra des **résidus conformes**,
   pas d'un ensemble de modèles. Ils ne sont mesurés qu'à **un pas (5 ans)** :
   on n'a pas de placettes revisitées à 50 ans. Pour un horizon de plusieurs
   pas, il faut une hypothèse (cumul des résidus pas à pas, ou intervalle
   élargi en racine du nombre de pas), à écrire dans la fiche comme une
   hypothèse, pas comme une mesure. À l'échelle d'une UGF (moyenne de
   placettes ou de pixels), l'intervalle d'une placette est trop large : il
   faut un résidu agrégé.
2. **Garde-fou à ajouter à `calibrer_finn()`** : un nombre minimal d'arbres par
   essence avant de lui donner ses propres paramètres (sinon `"other"`). Les
   modèles « graine » n'ont pas explosé sur le test, mais le risque est le
   même pour une essence rare d'un projet.

### Garde-fou « arbres minimum par essence » (2026-11-09, v2026.11.10)

`calibrer_finn(min_arbres_essence = 300L)` : une essence de moins de
300 arbres dans l'état initial rejoint `"other"`. Sur les 1 000 placettes de
calibration BFC, cela renvoie dans `"other"` 52, 20G, 54, 12V et 24 (132 à
224 arbres) ; 14 et 64 (320 et 323) gardent leurs paramètres. Le seuil vient
de ce test : les essences qui ont explosé en avaient 130 à 140. Recalcul sur
les mêmes tirages, mêmes 1 000 placettes tenues à l'écart :

| Modèle | RMSE sans garde-fou | RMSE avec | Couverture 90 % avec |
|---|---|---|---|
| graine 0 | 3,37 | 3,37 | 0,21 |
| bootstrap 1 | 6,23 | 3,49 | 0,21 |
| bootstrap 3 | 13,84 | 3,51 | 0,23 |
| conforme (graine 0) | 3,36 | 3,38 | 0,91 (demi-largeur 4,70) |

Le garde-fou supprime les explosions sans dégrader le modèle principal. Le
bootstrap reste une sous-estimation de l'incertitude (30 % de couverture pour
l'ensemble de deux) : l'intervalle de `simuler_itineraire()` reste conforme.

### `simuler_itineraire()` et `conformer_finn()` (2026-11-09, v2026.11.11)

- **Pas à pas** : chaque pas FINN repart des cohortes du pas précédent
  (`return_cohorts = "last"`, puis `makeInitCohorts`). Un pas redonne
  `predire_finn()` (écart moyen 0,04 m²/ha sur 20 placettes) ; 50 ans pas à
  pas, 43,5 m²/ha en moyenne sur 100 placettes, contre 43,1 en continu
  (écart-type des écarts 0,84 : le bruit des tirages).
- **Règles entre les pas** (sémantique écrite dans la doc, pas de valeur
  par défaut) : à chaque rotation, tiges au-dessus du diamètre
  d'exploitabilité récoltées, puis éclaircie uniforme de la part
  `(G − cible) / G`, plafonnée par l'intensité ; tirage binomial par
  cohorte. Itinéraire test (rotation 10 ans, exploitabilité 60 cm, cible
  20 m²/ha, 30 % au plus ; valeurs de test, pas un itinéraire) : G moyenne
  24,6 → 21,4 → 23,2 m²/ha aux années 0, 25 et 50, contre 24,6 → 34,2 → 43,4
  sans gestion.
- **Temps** : 100 placettes × 100 trajectoires × 50 ans en 16 min de CPU
  (4 fils), avec ou sans éclaircie : critère 3 tenu.
- **Intervalle** : `conformer_finn()` sur les 1 000 placettes « conformes »
  donne 4,67 m²/ha à 90 % (4,70 dans le prototype, autres tirages). Au-delà
  d'un pas, élargissement en racine du nombre de pas par défaut ;
  hypothèse étiquetée dans la colonne `intervalle`.
- **Reste** : aucun itinéraire du catalogue n'est sourcé, donc aucun n'est
  simulable en dehors d'un catalogue fourni par le forestier ; résidu
  agrégé à l'échelle de l'UGF (moyenne de placettes) ; variables dérivées
  (volume, P1, C1, B2) ; puis `comparer_itineraires(trajectoires =)` et T4.

### Intervalle à l'échelle de l'UGF (2026-11-09, v2026.11.12)

`data-raw/prototype_finn_unites.R` : résidus à 5 ans du modèle « graine 0 »
(seuil de 300 arbres par essence) sur les 2 000 placettes tenues à l'écart,
coordonnées IFN (floutées au kilomètre).

- **Corrélation spatiale des résidus** presque nulle : −0,06 sous 1,5 km
  (318 paires), 0,03 à 0,04 de 1,5 à 5 km, 0,02 à 0,03 de 5 à 20 km, 0
  au-delà.
- **Mais l'erreur moyenne de k placettes ne baisse pas en 1/√k** : le biais
  commun (+0,44 m²/ha) reste. Demi-largeur 90 % mesurée sur les 1 000
  placettes « conforme », couverture sur des groupes de k voisines des 1 000
  placettes « test » :

  | k | voisines : q (couverture) | hasard : q (couverture) | q/√k (couverture) |
  |---|---|---|---|
  | 1 | 4,57 (0,91) | 4,57 (0,91) | 4,57 (0,91) |
  | 2 | 3,30 (0,89) | 3,57 (0,92) | 3,23 (0,89) |
  | 4 | 2,93 (0,93) | 3,01 (0,94) | 2,28 (0,88) |
  | 8 | 2,30 (0,93) | 1,93 (0,90) | 1,61 (0,85) |
  | 16 | 1,79 (0,91) | 1,49 (0,86) | 1,14 (0,77) |
  | 33 | 1,66 (0,95) | 1,29 (0,87) | 0,80 (0,65) |

- **Décision** : `simuler_itineraire(unites =)` prend la demi-largeur des
  groupes de k voisines (`conformer_finn(coordonnees =)`) ; sans
  coordonnées, des groupes au hasard, signalés `"hasard"` (sous-couverture
  dès 16 placettes). Il faut au moins 30 groupes : une unité de k placettes
  demande 30·k placettes tenues à l'écart.
- **Limite** : les placettes d'une vraie UGF sont à quelques centaines de
  mètres, celles de l'IFN à plusieurs kilomètres. Une corrélation plus forte
  à l'intérieur d'un peuplement rendrait l'intervalle trop étroit ; elle
  n'est pas mesurable avec l'IFN. La sous-corrélation observée sous 1,5 km
  (−0,06) n'en montre pas trace, sur peu de paires.

### Volume le long des trajectoires (2026-11-09, v2026.11.13)

FINN ne porte pas de hauteur : `simuler_itineraire(volume = TRUE)` cube les
cohortes au diamètre seul, avec les tarifs Schaeffer à une entrée de l'IFN
(spec 062 ; numéro et type conseillé par essence, cascade SER → GRECO →
France). `"other"` : tarif de l'essence « other » dominante de la placette au
départ (ou de l'ensemble) qui a un tarif.

- **Contrôle des tarifs** (`data-raw/prototype_finn_volume.R`, 12 974 arbres
  vifs de la première visite des 1 000 placettes « test », essence exacte,
  SER de la placette) : +1,8 % sur le volume total ; par classe de
  diamètre, −9,6 % sous 20 cm, +3,5 / +2,3 / +3,4 % de 20 à 70 cm, +18,6 %
  au-delà de 70 cm. Les très gros bois sont surestimés : à dire dans la
  fiche pour un itinéraire à diamètre d'exploitabilité élevé.
- **« other »** : sur les mêmes placettes, le tarif de l'essence dominante
  donne 207,0 m³/ha contre 206,8 avec l'essence exacte de chaque arbre.
- **Piège trouvé** : une essence sans tarif rendait 0 au lieu de `NA` (somme
  par placette) ; corrigé, et le groupe « other » ne retient que des
  essences qui ont un tarif.
- **Trajectoires** (100 placettes « test », 10 tirages) : 219 m³/ha au
  départ, 261, 327 et 438 m³/ha à 10, 25 et 50 ans sans gestion ; avec
  l'éclaircie de test (rotation 10 ans, exploitabilité 60 cm, cible
  20 m²/ha), 195 à 211 m³/ha sur pied et 219 m³/ha prélevés en cumul.
- **Reste** : C1 (traité ci-dessous, v2026.11.14) ; B2 n'a pas d'équivalent
  sans hauteurs.

### Carbone le long des trajectoires (2026-11-09, v2026.11.14)

`simuler_itineraire(carbone = TRUE)` : carbone (tC/ha) = volume des tarifs
Schaeffer × infradensité de l'essence × BEF × fraction de carbone, avec le
BEF (1,30, IPCC 2006) et la fraction (0,50) du C1, pour que l'année 0 se
compare au C1. `"other"` : infradensité de l'essence du tarif.

- **Source de l'infradensité** (décision de Pascal, 2026-11-09) : Global
  Wood Density Database (Chave et al. 2009, Zanne et al. 2009,
  doi:10.5061/dryad.234, CC0), densité basale = infradensité. Dryad exige un
  jeton pour le fichier ; la même donnée est lue dans `data/wdData.rda` du
  paquet CRAN BIOMASS (on ne reprend que la donnée CC0).
  `data-raw/infradensite_espar.R` → `inst/extdata/infradensite_espar.csv`.
- **Cascade** : espèce en Europe (55 essences IFN), espèce toutes régions
  (55), genre en Europe et Amérique du Nord (61 ; le genre mondial tire
  *Quercus* à 0,70 avec les chênes tropicaux, 0,67 en tempéré), groupe
  feuillus / résineux (22 ; 0,539 et 0,413).
- **Biais trouvé dans le C1** : `wood_density.csv` est une densité à l'air
  sec, employée comme masse sèche en mode CHM ; l'infradensité est 0,79 à
  0,87 fois plus faible (médiane 0,83). Le C1 CHM passe à l'infradensité
  (décision de Pascal) ; E1 garde la densité à l'air sec (hors chantier).
- **Trajectoires** (100 placettes « test », 10 tirages) : 75 tC/ha au
  départ, 89, 112 et 150 tC/ha à 10, 25 et 50 ans sans gestion ; avec
  l'éclaircie de test, 67 à 89 tC/ha sur pied et 73 tC/ha prélevés en
  cumul ; 0,344 tC/m³ au départ (infradensité moyenne pondérée 0,53).
- **Reste** : BEF et fraction de carbone sont des constantes du C1 (BEF
  IPCC générique, fraction non sourcée) ; les rendre par essence est un
  chantier distinct.

### `comparer_itineraires(trajectoires =)` (2026-11-10, v2026.11.15)

Fait avant T4 (inversion de l'ordre du § 5, à la demande de Pascal : la
comparaison ne dépend que de la table de `simuler_itineraire()`). Choix
faits au codage, à valider :

- **Familles lues** : P = volume prélevé **cumulé** jusqu'à l'horizon
  (`volume_preleve`, repli `g_prelevee`) ; C = carbone **sur pied** à
  l'horizon. E (carbone prélevé, substitution) n'est pas lu : le lien
  prélèvement → évitement n'est pas établi dans le cœur. B2 et R2 ne sont
  pas lus (pas de hauteurs dans FINN, D-5). Les autres familles pondérées
  sont mises de côté, comme une famille non documentée du catalogue.
- **Note** : chaque famille ramenée sur `[-1, 1]` (min-max) entre les
  candidats de l'UGF, puis pondérée ; la note reste un ordre (le § 3.2
  annonçait « une note » : elle n'en est pas une, un écart de 1 % pèse
  comme un écart de 50 %). Valeurs dans `attr(, "valeurs")`.
- **Gagnants / perdants** : écart à la référence au-delà de `tolerance`
  (5 % de la valeur de référence, convention) : les trajectoires sont des
  moyennes de tirages.
- **`incertitude`** : demi-largeur conforme de G à l'horizon (m²/ha), seule
  variable qui porte un intervalle.
- **`"sans_gestion"`** (sortie de `simuler_itineraire(itineraire = NULL)`) :
  candidat de chaque UGF, sans citation.
- **Écart au contrat de la spec 065 § 6** : la table d'entrée est celle que
  `simuler_itineraire()` rend réellement (`unite`/`placette`, `annee`,
  `variable`, `moyenne`, `bas`, `haut`), pas la forme prévue (`horizon`,
  `indicateur`, `valeur`, `methode`) ; les colonnes de sortie, elles, ne
  changent pas.
- **Non exercé sur un vrai run** : FINN et torch absents de la session ; testé
  sur des trajectoires synthétiques. Aucun itinéraire du catalogue n'est
  sourcé : un vrai run demande un catalogue fourni par le forestier.

### Premier run réel du catalogue BFC et plafond de densité (2026-11-11, v2026.11.21)

**Run.** `data-raw/simulation_catalogue_bfc.R` : FINN calibré par
`calibrer_finn()` sur 1 000 placettes IFN de BFC (1,2 h ; essences 03, 11,
02, 09, 61, 62, 17C, 64, 21C, 14 et `other`), `conformer_finn()` sur
1 000 autres (demi-largeur 4,58 m²/ha à 5 ans). Chacun des 10 itinéraires
sourcés et `sans_gestion` tournent sur les mêmes placettes de test
(60 au plus par itinéraire, choisies sur l'essence dominante en G ; 45 pour
le douglas, 49 pour l'épicéa) : 50 ans, 10 tirages, volume et carbone.
Les échantillons sont tirés avant toute simulation : FINN consomme le
générateur aléatoire, et un tirage fait entre deux itinéraires changeait les
placettes de 7 groupes sur 10. Les modèles et les sorties restent hors du
dépôt.

**Défaut constaté.** Sans gestion, G croît presque en ligne droite sur
50 ans (douglas 81 m²/ha, 1 118 m³/ha). Diagnostic
(`data-raw/diagnostic_plafond_finn.R`, placettes hors calibration non
coupées entre les visites) : sur un pas de 5 ans, FINN surestime
l'accroissement net de G de 10 à 50 m²/ha (+0,7 à +0,9 m²/ha par pas) et le
sous-estime au-delà de 50 m²/ha (0,9 contre 1,6). Sa mortalité augmente donc
bien avec la densité, mais trop tard. Sur 150 ans sans gestion, G atteint
81-89 m²/ha pour les chênes, 88 pour le hêtre, 90 pour le sapin, 96 pour
l'épicéa et 238 pour le douglas (RDI 2 758). Les quantiles 99 % observés en
BFC sont de 49-50 m²/ha pour les chênes, 58 pour le hêtre, 62 pour le
douglas, 68 pour le sapin et 75 pour l'épicéa. Calibré sur des pas de
5 ans, FINN n'a jamais vu de peuplement au plafond assez longtemps pour
l'apprendre.

**Correctif : plafond d'auto-éclaircie hors de FINN** (même logique que
D-2 : ce que FINN n'apprend pas est imposé entre les pas).
`densite_max_ifn()` calcule, par essence dominante (100 placettes au
moins), le quantile 99 % de la forme additive du RDI de Reineke
(`Σ poids (d/25)^1,605`) et de G sur la première visite de toutes les
placettes BFC (7 632), avec une ligne `"toutes"`. En BFC, le RDI va de 955
(02) à 1 254 (62) et G de 49 à 75 m²/ha. `simuler_itineraire(densite_max =)`
retire, après chaque pas, les plus petites tiges d'une placette qui dépasse
l'un des deux plafonds de son essence dominante. C'est une mortalité
naturelle, qui ne compte pas dans `g_prelevee`. Le plafond de RDI seul ne
suffisait pas : sur 150 ans, les chênes atteignaient 65-68 m²/ha et le
douglas 106. La droite de Reineke laisse G croître comme `Dg^0,395`, alors
que la limite observée s'infléchit chez les gros bois (Charru et al.
2012). D'où le second plafond, sur G. Avec les deux, les courbes se
stabilisent sur 150 ans : chênes 50, hêtre 55, sapin 62, épicéa 68,
douglas 61 m²/ha.

Limites : le plafond est une borne (quantile 99 %) et non une trajectoire ;
FINN reste en avance de 0,7 m²/ha par pas entre 10 et 50 m²/ha, ce qui
fait arriver le plafond trop tôt ; le plafond est calculé sur toutes les
placettes, celles de test comprises (leur état initial seulement). Option
par défaut `densite_max = NULL` : le comportement des versions précédentes
est conservé.

**Nature de l'éclaircie (`rapport_g_tiges`).** Le moteur retirait la même
part de chaque cohorte : un rapport G prélevée / tiges prélevées de 1, ce
que les guides appellent déjà une éclaircie « par le haut » (glossaire SFFC
p. 9 : Ve/V > 0,9). La règle `rapport_g_tiges` impose un autre rapport :
probabilité `min(1, c (g/ḡ)^b)` par cohorte, `c` et `b` résolus par
placette. Le hêtre en futaie régulière reçoit 0,92 (médiane de la table du
mémento) ; l'épicéa, le sapin et le douglas 0,83 (SFFC p. 21). Les chênes
n'en ont pas, faute de chiffre dans la table 28. Spec 065, relevé § 4.3.

**Résultats à 50 ans** (moyenne des placettes, m²/ha ; volume en m³/ha ;
plafond actif, mêmes placettes pour l'itinéraire et `sans_gestion`) :

| Itinéraire | n | G géré | G sans gestion | G prélevée cumulée | Vol. géré | Vol. sans gestion | Vol. prélevé |
|---|---|---|---|---|---|---|---|
| chêne sessile, futaie régulière | 60 | 18,4 | 40,1 | 22,2 | 162 | 395 | 204 |
| chêne, futaie irrégulière | 60 | 21,8 | 38,6 | 20,0 | 186 | 360 | 181 |
| conversion du TSF en futaie | 60 | 23,7 | 39,0 | 18,0 | 213 | 380 | 170 |
| hêtre, futaie régulière | 60 | 20,7 | 42,1 | 25,8 | 190 | 430 | 245 |
| hêtre, futaie irrégulière | 60 | 23,3 | 42,8 | 25,6 | 218 | 435 | 249 |
| sapin, futaie régulière | 60 | 31,0 | 57,0 | 36,6 | 332 | 687 | 429 |
| épicéa, futaie régulière | 49 | 31,8 | 58,6 | 32,7 | 333 | 667 | 357 |
| douglas, futaie régulière | 45 | 20,1 | 60,6 | 44,9 | 213 | 883 | 566 |
| libre évolution | 60 | 43,2 | 43,0 | 0 | 425 | 423 | 0 |
| îlot de sénescence | 60 | 43,7 | 43,9 | 0 | 420 | 422 | 0 |

À 50 ans, le plafond ne touche presque pas les itinéraires gérés (écart
< 0,6 m²/ha avec la même simulation sans plafond). Il abaisse surtout
`sans_gestion` : douglas 80,7 → 60,6 m²/ha (1 118 → 883 m³/ha), épicéa
61,2 → 58,6, sapin 60,5 → 57,0, chênes et hêtre de 1,5 à 2,7 m²/ha. Libre
évolution et îlot de sénescence se confondent avec `sans_gestion` : c'est
attendu, ce sont les mêmes trajectoires sous un autre code. L'intervalle
conforme à 50 ans reste large (± 14,5 m²/ha par placette, élargissement
`racine`) : les écarts entre itinéraires d'une même essence sont dans le
bruit à l'échelle d'une placette, pas ceux entre gestion et sans gestion.
L'effet propre de `rapport_g_tiges` n'est pas isolé : le premier run
(rapport 1) portait sur d'autres placettes ; écart observé inférieur à
1 m²/ha sur les quatre entrées concernées.

### `comparer_itineraires(trajectoires =)` sur un vrai run (2026-11-11)

Premier exercice réel de la comparaison du 2026-11-10
(`data-raw/comparaison_catalogue_bfc.R`). Calibration, plafond de densité et
horizon (50 ans, 10 tirages) sont ceux de la note précédente. 9 UGF fictives
de 20 placettes de test de même essence dominante : chêne sessile × 3,
hêtre × 3, sapin, épicéa, douglas. Leurs placettes sont tirées au hasard
dans l'essence, sans contiguïté : ce ne sont pas de vraies UGF. Tous les
candidats admissibles et `sans_gestion` sont simulés sur les mêmes
placettes avec `unites =`. L'îlot de sénescence est écarté : il a la même
dynamique que la libre évolution. Classement sous quatre profils,
`reference = "sans_gestion"`.

**Valeurs** (moyenne de l'UGF à 50 ans ; P = volume prélevé cumulé en
m³/ha, C = carbone sur pied en tC/ha ; fourchette sur les UGF d'une même
essence) :

| UGF | Itinéraire | P | C |
|---|---|---|---|
| chêne sessile × 3 | futaie régulière | 193-218 | 60-63 |
| | futaie irrégulière | 185-207 | 73 |
| | conversion du TSF | 168-196 | 79-82 |
| | libre évolution / sans gestion | 0 | 146-148 |
| hêtre × 3 | futaie régulière | 252-282 | 64-68 |
| | futaie irrégulière | 243-266 | 69-77 |
| | libre évolution / sans gestion | 0 | 146-161 |
| sapin | futaie régulière | 414 | 85 |
| épicéa | futaie régulière | 361 | 87 |
| douglas | futaie régulière | 595 | 68 |
| résineux | libre évolution / sans gestion | 0 | 162-250 |

**Demi-largeur à l'échelle de l'UGF** : 4,3 m²/ha de G à 50 ans pour
20 placettes (groupes conformes tirés au hasard), contre ± 14,5 m²/ha par
placette. À cette échelle, l'ordre des itinéraires gérés d'une même essence
se répète sur les trois UGF. Pour les chênes, la futaie régulière prélève le
plus et garde le moins de carbone sur pied ; la conversion du TSF prélève le
moins et en garde le plus ; la futaie irrégulière se place entre les deux.
Pour le hêtre, la futaie régulière prélève plus que l'irrégulière (de 3 à
6 %) et garde moins de carbone (de 7 à 13 %).

**Ce que le run apprend sur la méthode** (à trancher par Pascal) :

1. **Avec deux familles, le classement ne fait qu'exprimer le rapport des
   poids P:C.** Toute gestion gagne en P et perd en C contre `sans_gestion`.
   Le propriétaire privé (P 3, C 1) met en tête l'itinéraire qui prélève le
   plus, le technicien (C 3, P 1) la libre évolution. Les profils à poids
   égaux (gestionnaire ONF 3/3, naturaliste 1/1) mettent en tête
   l'itinéraire dont la perte relative de C est la plus faible (conversion
   du TSF chez les chênes), puisque chaque famille est ramenée sur
   [-1, 1]. Le carbone prélevé (produits, substitution, famille E) n'est
   pas lu : la gestion est pénalisée en C sans contrepartie. Avant de
   montrer ce classement à un acteur, il faut lire au moins E et B depuis
   la simulation, sinon le dire à côté du rang.
2. **Le front de Pareto ignore `tolerance`.** Libre évolution et
   `sans_gestion` ont la même dynamique (P = 0, C à 2 % près). Dans chacune
   des 9 UGF, l'une des deux sort du front, selon le tirage. Proposition :
   une dominance à `tolerance` près (A ne domine B que s'il le dépasse de
   plus de `tolerance` sur au moins une famille sans perdre plus de
   `tolerance` sur aucune), la règle qui vaut déjà pour les familles
   gagnantes et perdantes. **Codé en v2026.11.22**, à valider par Pascal
   comme le reste de la note. Recalculé sur les mêmes trajectoires : libre
   évolution et `sans_gestion` sont toutes deux sur le front dans les
   9 UGF. Contrepartie : la futaie régulière sort du front dans deux UGF
   (chêne n° 3 : 193 m³/ha contre 185 pour l'irrégulière, soit moins de
   5 % de plus, mais 63 tC/ha contre 73 ; hêtre n° 1 : 252 contre 243 et
   68 contre 77). Un candidat qui ne gagne qu'à moins de `tolerance` sur
   une famille et perd au-delà sur une autre est dominé. Avec
   `tolerance = 0`, c'est la dominance de Pareto usuelle.
3. Les écarts de rang entre libre évolution et `sans_gestion` (de 1 à 5
   selon les UGF) sont du bruit de tirage : le rang ne tient pas compte de
   `tolerance` non plus.

### Carbone des produits et substitution (2026-11-11, v2026.11.23)

`simuler_itineraire(produits = TRUE)` et `parametres_filiere_bois()`. Les
sources et les décisions D-E1 à D-E5 sont dans `sources-carbone-produits.md`
(§ 6.1). À chaque coupe, chaque cohorte coupée est ventilée : bois d'œuvre
selon le taux IFN de BFC (essence, diamètre), puis bois d'industrie et bois
énergie (part paramétrable). 50 % du bois d'œuvre et 85 % du bois
d'industrie entrent en produits, dans deux pools de demi-vie 20 et 5 ans.
La substitution vaut 1,6 tCO₂ par m³ de produit et 0,916 tCO₂ par tonne
sèche brûlée. Seule la tige est suivie. `comparer_itineraires()` lit
`carbone_total` (forêt + produits) en C et la `substitution` cumulée en E.

**Même run des 9 UGF** (mêmes placettes, `FINN_CMP_PRODUITS=oui`), à 50 ans :

| Itinéraires | Gain de C par les produits (tC/ha) | E cumulée (tCO₂/ha) |
|---|---|---|
| chênes (3 itinéraires × 3 UGF) | 8-10 | 132-169 |
| hêtre (2 × 3) | 10-13 | 192-224 |
| sapin / épicéa / douglas | 13 / 12 / 27 | 335 / 295 / 482 |

La substitution vaut environ 0,8 tCO₂ par m³ récolté, pour toutes les
essences. Le stock de produits ne comble pas l'écart de C avec
`sans_gestion` : 70-99 tC/ha pour les itinéraires gérés contre 146-250
sans gestion, à 50 ans.

**Classement.** Le premier rang va à un itinéraire géré dans les 9 UGF
pour le gestionnaire ONF, le naturaliste et le propriétaire privé. Il va à
la libre évolution ou à `sans_gestion` pour le technicien (C 3, P 1, E 1).
Avant, les profils à poids égaux départageaient par le bruit. Chez les
chênes, l'ONF et le naturaliste mettent maintenant en tête la futaie
irrégulière, puis la conversion du TSF ; la futaie régulière sort du front
dans les 3 UGF : elle ne prélève et n'évite qu'à moins de 5 % de plus que
l'irrégulière, et garde plus de 5 % de C en moins.

**Ce que ce classement doit dire à côté du rang :**

- **E pèse comme une famille entière**, donc la gestion gagne sur deux
  familles (P, E) contre une (C). Le résultat dépend des poids des
  profils.
- **Le stock sur pied et la substitution n'ont pas la même durée.**
  À 50 ans, le stock sans gestion croît encore. Il plafonne avec le
  plafond de densité, et il est exposé aux perturbations (non simulées).
  La substitution, elle, est acquise.
- **Les coefficients de substitution varient d'un facteur 6** (0,59 à
  3,47 tCO₂/m³ pour le matériau) et le bois d'œuvre potentiel est une
  borne haute.

### Bois mort et très gros bois : la famille B (2026-11-13, v2026.11.24)

`simuler_itineraire(biodiversite = TRUE)` suit deux variables de B que FINN
peut porter sans hauteur (sources-carbone-produits.md, § 5) :

- **`volume_mort`** : volume bois fort tige (mêmes tarifs que `volume`) des
  tiges mortes pendant le pas. Il en vient de deux sources : la mortalité de
  FINN, lue cohorte par cohorte (FINN 0.1.0 garde l'identité des cohortes :
  la cohorte de rang k du site s ressort avec `cohortID = (k − 1) S + s`,
  vérifié sur un mini-modèle), au diamètre d'entrée ; et l'auto-éclaircie
  du plafond de densité, au diamètre de fin de pas. Les coupes n'en
  produisent pas.
- **`bois_mort`** : stock de ce bois mort, en décroissance du premier ordre :
  2,3 %/an pour les feuillus et 6,9 %/an pour les résineux (demi-vies de 30
  et 10 ans ; étude INRA-IGN 2017, tableau 13.1, d'après Zell et al. 2009,
  référence non vérifiée). Le paramètre est `decomposition`.
- **`tiges_tgb`** : tiges vivantes/ha d'au moins `seuil_tgb` cm (67,5 par
  défaut, borne de la classe TGB de l'IFN et du facteur E de l'IBP).

`comparer_itineraires()` lit B sur `bois_mort` à l'horizon. `tiges_tgb` est
simulé mais pas lu, puisque la comparaison lit une variable par famille.

Choix faits au codage, à valider :

1. **Seul le bois mort produit depuis l'année 0 est compté**, pas le stock
   initial, qui n'est pas dans les données IFN de la simulation. C'est un
   écart entre itinéraires, pas un stock absolu.
2. **Les rémanents d'exploitation (houppier) ne sont pas comptés** : FINN ne
   porte que la tige. La gestion est donc un peu sous-estimée en B.
3. **B lit le bois mort plutôt que les très gros bois**, parce qu'il est
   alimenté par la mortalité, que la simulation mesure directement, et que
   les très gros bois dépendent de la croissance des gros diamètres, que les
   tarifs surestiment déjà (au-delà de 70 cm, § volume).

**Correctif en passant.** Une placette vidée par une coupe (diamètre
d'exploitabilité atteint par toutes les tiges) faisait échouer FINN, qui
renumérote les sites et ne retrouve plus l'environnement. La placette est
désormais gardée dans la grille par une cohorte vide, et peut recevoir des
recrues.

**Même run des 9 UGF** (`FINN_CMP_SUFFIXE=_biodiv`, mêmes placettes, 50 ans,
plafond actif, produits), à 50 ans :

| UGF | Itinéraires gérés : bois mort (m³/ha) | Sans gestion / libre évolution | TGB/ha géré | TGB/ha sans gestion |
|---|---|---|---|---|
| chêne sessile × 3 | 12-20 | 32-39 | 0,2-4,4 | 11-16 |
| hêtre × 3 | 12-18 | 36-48 | 0 | 5-15 |
| sapin | 25 | 76-78 | 0 | 32 |
| épicéa | 37 | 93-95 | 0 | 12 |
| douglas | 11 | 221-224 | 0 | 80 |

Le bois mort sans gestion vient surtout du plafond de densité chez les
résineux : le douglas, que FINN fait trop croître, est ramené au plafond pas
après pas, et chaque retour au plafond fait du bois mort. Ses 224 m³/ha
sont un artefact de ce couple biais de croissance / plafond, pas une
prévision.

**Classement** (poids P/C/E/B : propriétaire privé 3/1/3/1, gestionnaire
ONF 3/3/1/3, technicien 1/3/1/3, naturaliste 1/1/1/3). Avec B, l'ONF et le
naturaliste mettent en tête la libre évolution ou `sans_gestion` dans les
9 UGF (une gestion avant). Le technicien ne change pas. Le propriétaire
privé passe, pour les chênes, de la futaie régulière à la futaie
irrégulière. Les itinéraires gérés perdent tous B contre `sans_gestion`.

**Ce que ce classement doit dire à côté du rang** (en plus de la note
précédente) : B ne lit que le bois mort produit depuis l'année 0 et sans
rémanents ; sans gestion, il dépend du plafond de densité, donc du biais de
croissance de FINN ; le rang dépend des poids des profils, qui sont
provisoires (`profils_poids()`).

### D'où vient le biais de croissance de FINN (2026-11-13, diagnostic)

`data-raw/diagnostic_biais_croissance.R` : un pas FINN (3 tirages) sur
2 479 placettes de BFC hors calibration et hors conforme, non coupées
entre les visites (500 au plus par classe de G initiale). L'écart est
décomposé avec la mortalité par cohorte que `.itin_un_pas()` rend depuis
la v2026.11.24 : mortalité = G initiale des tiges mortes ; croissance +
recrutement (« cr ») = G1 − G0 + mortalité. Mêmes parts côté IFN.
m²/ha en 5 ans :

| G initiale | n | net obs. | net FINN | cr obs. | cr FINN | cr FINN / obs. | mort. obs. | mort. FINN |
|---|---|---|---|---|---|---|---|---|
| 0-10 | 500 | 2,47 | 1,59 | 2,72 | 1,84 | 0,68 | 0,25 | 0,25 |
| 10-20 | 500 | 2,17 | 2,61 | 2,77 | 3,24 | 1,17 | 0,60 | 0,63 |
| 20-30 | 500 | 1,93 | 2,70 | 2,92 | 3,63 | 1,24 | 0,98 | 0,93 |
| 30-40 | 500 | 1,77 | 2,87 | 3,55 | 4,32 | 1,22 | 1,79 | 1,45 |
| 40-50 | 325 | 1,65 | 2,10 | 4,06 | 4,31 | 1,06 | 2,42 | 2,21 |
| ≥ 50 | 154 | 1,59 | 0,63 | 5,17 | 4,41 | 0,85 | 3,57 | 3,79 |

**Le biais vient de la croissance (et du recrutement), pas de la
mortalité.** La mortalité simulée suit l'observée à 0,35 m²/ha près dans
toutes les classes (un peu basse de 30 à 50 m²/ha, un peu haute au-delà
chez les feuillus). La croissance observée par hectare augmente avec la
densité (2,7 → 5,2 m²/ha en 5 ans) ; celle de FINN est plus plate (1,8 →
4,4). FINN sous-estime donc la croissance des peuplements clairs (− 32 %),
la surestime de 10 à 40 m²/ha (+ 17 à + 24 %) et la sous-estime au-delà de
50 (− 15 %). C'est la même relation trop plate chez les feuillus et les
résineux (résineux clairs : 2,25 contre 4,21).

**Le cas du douglas n'est pas un biais d'un pas.** Sur un pas, FINN
sous-estime même la croissance nette du douglas (4,85 contre 5,40 m²/ha ;
84 placettes). Ses 238 m²/ha à 150 ans viennent de l'extrapolation : les
peuplements de douglas de BFC sont jeunes, presque sans mortalité observée
(0,76 m²/ha en 5 ans), et FINN n'a jamais vu de douglas dense mourir. Le
plafond de densité (v2026.11.21) traite ce cas ; une correction de
croissance ne le ferait pas.

Par essence dominante (n ≥ 50), le rapport cr FINN / obs. va de 0,92
(épicéa de Sitka, 14) à 1,19 (hêtre, 09) et 1,18 (épicéa, 62) ; par
essence × classe (n ≥ 30), de 0,67 à 1,45, avec le même profil
(sous-estimé sous 10 m²/ha, surestimé de 10 à 40).

**Temps de calcul.** Un pas de 2 479 placettes en un seul appel prend
15 min (environ 0,4 s par placette), contre moins d'une seconde pour un
pas de 20 placettes : le coût n'est pas linéaire. Un diagnostic plus large
doit découper les placettes en paquets.

**Correctifs possibles** (décision D-G, à prendre par Pascal) :

1. **Correction de l'accroissement hors de FINN**, comme le plafond de
   densité : après chaque pas, multiplier l'accroissement en diamètre des
   survivants par un facteur par classe de G et groupe (feuillus,
   résineux), mesuré sur les placettes du jeu conforme (pas sur le test),
   et le publier avec la calibration. Simple et lisible. Limites : la
   correction s'applique à chaque pas et se compose sur 10 pas ; elle
   corrige une moyenne, pas la relation densité-croissance elle-même ; il
   faut séparer la croissance du recrutement côté FINN (les recrues sont
   les cohortes de rang supérieur au nombre de cohortes d'entrée, lisible
   comme la mortalité).
2. **Recalibrer FINN** : plus de placettes (les 5 632 hors conforme au lieu
   de 1 000) et un poids plus fort sur la surface terrière dans la perte.
   Corrige la cause si elle vient du manque de données ; plusieurs heures
   de calcul ; aucune garantie, puisque les réglages de l'ajustement
   n'avaient pas fait disparaître le biais (note du 2026-11-08).
3. **Ne rien corriger et le dire** : intervalle conforme à la mesure de
   l'erreur d'un pas ; biais de + 0,5 à + 1 m²/ha par pas dans les classes
   moyennes, écrit dans la fiche et à côté du rang.

Proposition : **2 d'abord** (un seul run, la cause plutôt que le symptôme),
mesuré avec ce même diagnostic ; **1 si le biais tient** après
recalibration.
