# Spec 064 — AlphaEarth : source NDP 0 universelle, N5 distance à la référence, B4/L3 en mode embedding

> **Statut** : **brouillon, à valider par Pascal**. Rien n'est implémenté avant
> validation (brief § 5.5).
> **Origine** : brief « Modèles de fondation et raisonnement sylvicole dans
> l'écosystème Néméton » du 2026-11-05, chantier A (priorité 1).
> **Dépôts** : `alphaearthnemeton` (nouveau, amont) et `nemeton` (cœur).
> **Décisions ouvertes** : § 9. Les points marqués **[D-n]** dans le texte y
> renvoient.

## 1. Pourquoi

Trois limites du cœur actuel, relevées par le brief et vérifiées dans le code :

1. **La famille N mesure une naturalité administrative.** N1 = distance aux
   routes et au bâti (`indicateur_n1_distance()`), N2 = continuité
   cartographique (`indicateur_n2_continuite()`, couche `foret_ancienne`
   à paliers), N3 = composite de N1, N2, L1, B3. Aucun ne regarde la forêt
   elle-même.
2. **B4/L3 ne se comparent pas entre projets** (écart n° 6, ouvert depuis
   v0.190.0). B4 est un Shannon de « spectral species » biodivMapR, L3 une
   dispersion dans une PCoA : les deux dépendent du k-means ajusté sur le
   projet.
3. **Sans CHM ni LiDAR, C1, P2 et B2 retombent sur leurs replis NDP 0**, alors
   qu'une source annuelle, mondiale, à 10 m, existe.

AlphaEarth Foundations (Google DeepMind, 2025) publie chaque année depuis 2017
un **embedding 64-D par pixel de 10 m**, de norme unité, appris sur S1, S2,
Landsat, GEDI, ERA5, etc. C'est exactement le complément NDP 0 qui manque.

## 2. Principes (rappel du brief, vérifiés)

- **ADR-009** : le cœur reste sans Python. Le téléchargement vit dans
  `alphaearthnemeton` ; le cœur ne consomme qu'un **SpatRaster 64 bandes**.
- **Contrat 1.0 (spec 057)** : aucun indicateur stable ne change de sens.
  B4 et L3 reçoivent un **mode additionnel** ; leur défaut reste biodivMapR.
  N5 est un **code nouveau**, conditionnel.
- **Une fiche (spec 052) dès la première release**, section « pièges »
  remplie : N5, et l'annexe « mode embedding » des fiches B4 et L3.
- **Pas de nombre inventé** : N5 vaut `NA` + statut quand il n'est pas
  mesurable, jamais une valeur par défaut (même règle que N1-N3 depuis
  l'audit 1.0).

## 3. Livrable amont — `alphaearthnemeton`

| Fonction | Rôle |
|---|---|
| `aef_fetch(aoi, years, out = "COG", cache_dir)` | rapatrie les 64 bandes pour l'emprise et les années, reprojette en Lambert-93 (EPSG:2154 en France, EPSG:3035 ailleurs, comme spec 006), écrit un COG par année |
| `aef_info()` | version du jeu, licence, années disponibles |

- **Accès [D-1]**. Le brief propose Earth Engine via `rgee`. Or `rgee`
  **dépend de Python** (`earthengine-api` via reticulate) et d'un compte GEE :
  ce n'est pas « R pur ». Le jeu existe aussi en **COG publics** (export
  GCS / Source Cooperative annoncé en 2025, à vérifier : chemin, quantification
  `int8`, tuilage UTM). Si ce miroir est confirmé, `aef_fetch()` le lit par
  `/vsicurl/` ou `/vsis3/` avec `terra`, sans Python ni compte. `rgee` reste en
  repli optionnel.
- **Déquantification** : si les COG sont en `int8`, `aef_fetch()` rend des
  `float32` déquantifiées et renormalisées à la norme unité. Le cœur ne
  connaît que des embeddings flottants.
- **Cache adressé par contenu** (comme FAST, spec 017 D6) :
  `hash(emprise arrondie, année, version du jeu)`. Le hash ne porte pas la date
  de la demande.
- **Licence** du jeu : à recopier exactement dans `aef_info()` et dans
  `FR.json` (CC-BY 4.0 annoncé, à vérifier au moment du code). Licence du
  paquet : **[D-2]** (le brief dit MIT, les paquets R de l'écosystème sont en
  GPL-3).

## 4. Livrable cœur — source et couche

- `inst/datasources/FR.json` (et les fichiers pays de la spec 006) : source
  `aef_embedding`, `type = "raster_local"`, `format = "COG"`, 64 bandes,
  10 m, `provenance.package = "alphaearthnemeton"`, licence.
- `NDP_LEVELS[[1]]$sources` : ajout de `"aef_embedding"` (NDP 0).
- `layers$aef_embedding` : SpatRaster 64 bandes **par année** ; une liste
  nommée par année (`"2024"`, `"2025"`) quand plusieurs années sont chargées.
- `detect_ndp()` : nouveau flag `augmented = "embedding_ml"` quand
  `attr(data, "embedding_source") == "aef"` (le niveau et la confiance φ ne
  changent pas, comme `height_ml`, ADR-011 amendé).

## 5. Fonctions génériques (réutilisées par les chantiers B et C)

Toutes **indépendantes du modèle source**, testées sur embeddings
synthétiques, statut `experimental`.

### 5.1 `embedding_summary(units, layer, stats = c("mean", "sd"), min_pixels = 10L)`

Rend une liste : `mean` (matrice `n_units × d`), `sd` (idem), `n_pixels`
(vecteur), `meta` (source, année, dimension). Extraction par
`exactextractr` pondérée par la fraction de couverture. Une UGF de moins de
`min_pixels` pixels a une ligne `NA`.

**[D-3]** AEF est de norme unité : la moyenne de vecteurs unitaires n'est plus
unitaire, et sa norme mesure l'**homogénéité** interne de l'UGF. On garde la
moyenne brute (information utile) et l'on documente qu'elle n'est pas sur la
sphère.

### 5.2 `distance_reference(x, reference, method = "mahalanobis_lw")`

`x` : matrice des UGF à noter ; `reference` : matrice des UGF de référence.
Covariance de la référence régularisée par **Ledoit-Wolf** (implémentée en
base R, pas de nouvelle dépendance : `corpcor` n'est pas dans DESCRIPTION).
Rend la distance de chaque ligne de `x` au centroïde de la référence, plus
la distribution des distances **leave-one-out** de la référence à elle-même
(nécessaire au § 6).

## 6. N5 — distance à la référence

```r
indicateur_n5_distance_reference(units, embedding = NULL, reference = NULL,
                                 layers = NULL, min_reference = 15L,
                                 score = c("reference", "projet"))
```

- **Référence par défaut** : UGF du projet couvertes par la couche
  `foret_ancienne` au **palier maximal** (`anciennete`) **et** `N1 ≥ 80`.
  L'utilisateur peut fournir la sienne (`sf` de polygones : réseau de réserves
  intégrales, îlots de sénescence, placettes de référence).
- **Métrique** : `distance_reference()` sur les embeddings moyens.
- **Score 0-100 [D-4]**. Le brief propose le **rang percentile sur le
  projet**. C'est le défaut qui a ouvert l'écart n° 6 : un même massif noté
  dans deux projets de découpes différentes aurait deux N5, et un projet de 20
  UGF s'étale toujours de 0 à 100. Proposition :
  `score = "reference"` (défaut) : `N5 = 100 × (1 − F_ref(d))`, où `F_ref` est la
  distribution empirique des distances leave-one-out de la référence. Une UGF
  aussi proche que la référence typique vaut ~50, une UGF plus lointaine que
  toute la référence vaut 0. Ce score dépend de la référence, pas des autres
  UGF notées. `score = "projet"` garde le rang du brief, en option.
- **Sens** : `+` (100 = indiscernable de la référence = le plus naturel).
  Nouveau code, donc pas de palier `INDICATOR_SENSE_VERSION` (le mécanisme vit
  côté app, `nemetonshiny/R/migrate.R`).
- **Statut** `n5_status` : `no_embedding`, `no_reference`,
  `reference_too_small` (< `min_reference` UGF ou polygones), `ok`. Colonnes
  annexes : `n5_source` (`"aef"` ; `"forpt"` et `"fused"` réservées au
  chantier C), `n5_reference` (`"defaut"` ou `"utilisateur"`), `n5_annee`.
- **Famille N** : N5 est **conditionnel** (comme B4). Sans embedding, il vaut
  `NA` et la famille N est inchangée (`create_family_index(na.rm = TRUE)`).
  **Avec** embedding, la famille N d'un projet existant bouge au recalcul :
  c'est voulu, à annoncer dans NEWS. **[D-5]** N5 entre-t-il dans N3 ?
  Proposition : **non** dans cette spec (N3 est stable, sa formule est fixée
  par le tuto 04) ; à rediscuter quand N4/N5 structurels existeront.
- **Décompte** : 41 → **42 indicateurs** (31 de base, 11 conditionnels). Tous
  les endroits qui écrivent « 41 » sont à mettre à jour au moment du code
  (CLAUDE.md, README, `list_indicators()`, fixture `massif_demo_units`, fiches).

**Pièges à écrire dans la fiche** (`vignettes/fiche-n5-distance-reference_fr.Rmd`) :

1. **La référence n'est pas un échantillon aléatoire.** Les forêts anciennes et
   éloignées sont sur-représentées en pente, en altitude, sur sols pauvres. N5
   mesure donc aussi une distance de **station**. Piste de mitigation
   documentée, pas implémentée : stratifier la référence par SER.
2. **Circularité avec N1 et N2.** La référence par défaut est choisie par N1 et
   N2 : N5 leur est corrélé par construction. Le corrélogramme du projet doit
   le montrer ; la fiche le dit.
3. **Distance, pas causalité.** Une UGF loin de la référence n'est pas
   « dégradée » : elle peut être jeune, résineuse, ou sur une autre station.
4. **Référence trop petite.** Avec 15 UGF et 64 dimensions, la covariance est
   presque entièrement fixée par la régularisation Ledoit-Wolf : la distance
   devient quasi euclidienne. Le seuil de 15 est un plancher, pas un confort.
5. **Année.** AEF est annuel : une coupe de l'année *n* n'apparaît que dans
   l'embedding *n* ou *n + 1*.

## 7. B4 / L3 en mode embedding (écart n° 6)

```r
indicateur_b4_div_spectrale(units, spectral = NULL, reflectance = NULL,
                            embedding = NULL, ...)
indicateur_l3_het_spectrale(units, spectral = NULL, reflectance = NULL,
                            embedding = NULL, min_windows = 3L, ...)
```

- `embedding = NULL` : comportement actuel inchangé (biodivMapR).
- `embedding` fourni (et `spectral`/`reflectance` absents) : affectation de
  chaque pixel à un **dictionnaire de clusters fixe**, puis
  B4 = entropie de Shannon des clusters dans l'UGF, L3 = dispersion
  multivariée (même définition betadisper qu'aujourd'hui) des embeddings dans
  l'UGF.
- **[D-6] Comparabilité inter-projets.** Le brief l'annonce « par
  construction, puisque l'espace est globalement normalisé ». C'est vrai de
  l'**espace**, pas des **clusters** : un k-means ajusté sur chaque projet
  rendrait B4 aussi incomparable qu'aujourd'hui. Proposition : un
  **dictionnaire de k centroïdes** ajusté une fois sur un corpus de référence
  (forêts BFC + quelques massifs hors France), versionné dans
  `inst/extdata/aef_clusters_v1.csv` avec sa provenance ; `k` à fixer
  (proposition 32).
- **Colonne annexe** `b4_methode` / `l3_methode` ∈ `biodivmapr`, `embedding`.
  Les deux méthodes ne donnent **pas** des valeurs comparables entre elles :
  la normalisation (`indicator-config.R`) doit porter des bornes par méthode.
  **[D-7]** Est-ce un changement de sens au sens de la spec 057 ? Proposition :
  non, tant que le défaut reste biodivMapR ; oui (palier
  `INDICATOR_SENSE_VERSION` côté app) le jour où le défaut bascule.

## 8. Régressions NDP 0 : C1, P2, B2 sans CHM ni LiDAR

```r
embedding_regress(units, embedding, train, target = "H0",
                  covariables = NULL, cv = "blocs_spatiaux")
```

- `train` : placettes IFN du projet (`ifn_charger()`, `R/ifn_source.R`) avec
  leur hauteur dominante ; covariables Fay-Herriot existantes en option
  (`R/fay_herriot.R`).
- Modèle : **[D-8]** `ranger` (brief) n'est pas dans DESCRIPTION. Proposition :
  `Suggests: ranger`, avec repli **ridge en base R** (même code que les sondes
  du chantier B, qui en ont besoin de toute façon). La valeur rendue porte son
  RMSE en validation croisée spatiale par blocs.
- Effet : C1, P2, B2 reçoivent la hauteur prédite **par le même argument que
  le CHM** (`chm =`), avec `attr(, "chm_source") = "aef_regression"` et le flag
  `augmented = "embedding_ml"`. Aucun nouvel argument sur ces indicateurs
  stables.
- **Garde-fou** : moins de 30 placettes IFN dans le projet (tampon élargi
  compris) → pas de régression, statut `train_too_small`, et les indicateurs
  gardent leur repli actuel.

## 9. Décisions ouvertes (à arbitrer par Pascal)

| # | Question | Proposition |
|---|---|---|
| D-1 | Accès aux données : `rgee` (Python + compte GEE) ou COG publics ? | COG publics si le miroir est confirmé ; `rgee` en repli optionnel. Le chantier A redevient alors « R pur » |
| D-2 | Licence de `alphaearthnemeton` : MIT (brief) ou GPL-3 (comme `nemeton`) ? | à trancher ; le jeu de données reste sous sa propre licence |
| D-3 | Embedding moyen brut ou renormalisé ? | brut, norme documentée comme indice d'homogénéité |
| D-4 | Score N5 : rang percentile sur le projet (brief) ou quantile de la distribution de la référence ? | référence par défaut, rang projet en option |
| D-5 | N5 dans N3 ? | non pour cette spec |
| D-6 | Dictionnaire de clusters fixe et versionné pour B4/L3 ? `k` ? | oui, `k = 32`, corpus BFC + hors France |
| D-7 | Le mode embedding de B4/L3 déclenche-t-il un palier de sens ? | non tant que biodivMapR reste le défaut |
| D-8 | `ranger` en Suggests, repli ridge base R ? | oui |
| D-9 | Années : une seule (la plus récente) ou plusieurs pour N5 ? | la plus récente par défaut, `annee =` en argument ; multi-années = chantier D (T4) |
| D-10 | Le code **N6** cité dans les principes du brief n'est défini nulle part | le retirer de la liste, ou lui donner un objet avant de réserver le code |

## 10. Critères d'acceptation

1. N5 calculé sur **Dabo** (référence par défaut) et sur **une UGF hors
   France** (spec 006, référence fournie par l'utilisateur) ; `n5_status`
   correct dans les quatre cas (`no_embedding`, `no_reference`,
   `reference_too_small`, `ok`) sur fixtures synthétiques.
2. B4/L3 en mode embedding **stables à ± 2 points** entre deux années AEF
   consécutives sur un même projet sans coupe connue (SUFOSAT, T3) ; et
   **identiques** pour une même UGF incluse dans deux projets différents
   (test du dictionnaire fixe, D-6).
3. `embedding_summary()`, `distance_reference()`, `embedding_regress()` testées
   sur embeddings synthétiques (distance connue, Ledoit-Wolf face à une
   covariance connue, référence de 14 vs 15 unités).
4. Fiche N5 complète (spec 052) + annexes B4/L3 ; fiche commune « modèles de
   fondation » (poids, licence, date, angles morts) liée depuis chacune.
5. Vignette `embeddings-alphaearth_fr.Rmd`.
6. Aucune dépendance Python dans le cœur (`R CMD check` sans reticulate actif).

## 11. Limites documentées

AEF est **annuel**. Il ne remplace ni FAST, ni FORDEAD, ni le cube S2 (R5, T2,
phénologie). Il ne voit pas sous la canopée (chantier C). Ses angles morts
réels, par indicateur, seront mesurés par les sondes du chantier B
(`probe_indicator()`), qu'il est utile d'appliquer aussi à AEF.

## 12. Écarts cœur → app ouverts dès maintenant

Inscrits dans PLAN.md (table des écarts, n° 20 à 22) **avant** la première
release : couche N5 sur la carte et dans la fiche projet ; méthode B4/L3
affichée et bornes par méthode ; flag `embedding_ml` dans le badge NDP.
Brief app : `specs/064-alphaearth-n5/brief-nemetonshiny.md`.
