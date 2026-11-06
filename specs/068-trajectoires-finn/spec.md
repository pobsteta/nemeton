# Spec 068 — Dynamique et causalité : trajectoires FINN, T4, effets de la gestion

> **Statut** : **brouillon, à valider par Pascal**. Rien n'est implémenté avant
> validation (procédure du brief du 2026-11-05, § 5).
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

| # | Question | Proposition |
|---|---|---|
| D-1 | FINN (et torch pour R) dans le cœur ? | **Suggests** du cœur, fonctions qui s'arrêtent proprement sans FINN ; pas de paquet amont, puisqu'il n'y a pas de Python. Alternative : `finnnemeton` amont si l'installation de torch pèse trop sur la CI |
| D-2 | Interventions sylvicoles : FINN n'en documente pas | simuler pas à pas et **retirer des cohortes entre deux pas** selon les règles de l'itinéraire ; à vérifier sur le prototype (étape 2) avant tout code dans le cœur |
| D-3 | Processus neuronaux : quand ? | mécaniste seul en première version ; neuronal seulement avec une validation croisée qui montre un gain sur placettes revisitées |
| D-4 | Seuil de recouvrement d'`effet_gestion()` | refus si moins de 70 % des UGF sont dans le support commun ou si un traitement a moins de 10 UGF ; seuils affichés comme conventions |
| D-5 | B5 et N4 dans les trajectoires | non en première version : FINN porte des cohortes (diamètre, hauteur), pas un nuage ; B2 oui (CV des hauteurs) |
| D-6 | T4 : nouveau code de la famille T, et son échelle | oui, T4 conditionnel ; décompte 43 → 44 (45 avec N4). Le brief le définit en signe (> 0 / < 0) ; proposé : score 0-100 centré sur 50 (rang de l'observé dans les trajectoires simulées), pour qu'il se normalise comme les autres |
| D-7 | Données de calibration | placettes IFN de BFC fournies par Pascal (le site de l'IFN est bloqué depuis les sessions) ; FORMS-T pour T4 |
| D-8 | TerraMind (optionnel du brief) | **hors de cette spec** : à n'ouvrir que si le besoin outre-mer se confirme |
