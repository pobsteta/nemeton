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
| 3. `calibrer_finn()`, `simuler_itineraire()` | prototype de calibration ✅ 2026-11-08 ; **`calibrer_finn()` + `predire_finn()` ✅ 2026-11-09 (v2026.11.9)** : 3,36 m²/ha hors calibration (voir ci-dessous) ; `simuler_itineraire()` à faire |
| 4. T4, `comparer_itineraires(trajectoires =)` | après 3 |

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
