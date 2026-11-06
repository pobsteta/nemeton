# Spec 067 — ForPT : le LiDAR HD comme espace latent 3D (B5, N4, N5 structurel, T1 désaturé, dimensionnement)

> **Statut** : **validée par Pascal le 2026-11-06** (décisions D-1 à D-7
> retenues telles que proposées). Première étape codée : B5 sans ForPT.
> **Origine** : brief « Modèles de fondation et raisonnement sylvicole » du
> 2026-11-05, chantier C (priorité 2, « livrable central »).
> **Dépôts** : `forptnemeton` (nouveau, amont, reticulate + torch, comme
> `opencanopy`) et `nemeton` (cœur, R pur).
> **Décisions ouvertes** : § 8, renvoyées par **[D-n]**.

## 1. Pourquoi

`compute_dtm_chm_from_laz()` réduit le LiDAR HD à un MNT et un MNH : tout ce
qui est sous la canopée est perdu (strates, bois mort sur pied, très gros
bois). La famille N mesure une naturalité administrative ; N5 (chantier A) en
a ajouté une lecture fonctionnelle, mais vue du ciel. Ce chantier donne au
cœur une lecture **3D** du peuplement.

## 2. Ce qui existe, vérifié le 2026-11-06

Les deux modèles nommés par le brief ont été vérifiés sur leurs publications
(chiffres des auteurs, pas d'évaluation indépendante trouvée) :

| Modèle | Ce qui est publié | Ce qui **n'est pas** publié |
|---|---|---|
| **ForPT** (ETH Zurich, arXiv 2609.24787 ; poids `prs-eth/ForPT` sur Hugging Face) | encodeur LitePT-S de 12,4 M de paramètres, pré-entraîné sans étiquettes sur des nuages ALS, ULS et MLS ; points de contrôle pour la **segmentation sémantique** (FOR-instanceV2), la **classification d'essences** (FOR-species20K) et la **régression d'âge** (FORage) | **segmentation d'instances** (annoncée « à venir ») ; **aucun classifieur vivant / mort** |
| **SelectAnyTree** (arXiv 2606.27491, juin 2026, code public) | segmentation d'arbres **sur clic**, avec un premier clic automatique placé sur les sommets du MNH | pas de classification vivant / mort ; pas de diamètre |

Conséquence : le `forpt_segment()` du brief (instances d'arbres + classe
« vivant / mort sur pied » + drapeau très gros bois) **n'existe pas tel
quel** ; N4 dépend d'un classifieur à construire (D-2).

Côté cœur : `compute_dtm_chm_from_laz()`, `traiter_nuage_points()`,
`segment_houppiers()` (watershed 2D ou OTB/LSMS), `indicateur_b2_structure()`
(CV du MNH), `indicateur_t1_anciennete()` (borne 200 ans depuis spec 048 §10),
et les fonctions génériques d'embedding du chantier A
(`embedding_summary()`, `distance_reference()`, `probe_indicator()`).

## 3. Livrable amont — `forptnemeton`

| Fonction | Rôle | Dépend de |
|---|---|---|
| `forpt_embed(laz_dir, aoi, out)` | encodeur ForPT gelé ; vecteurs agrégés en raster (voxel 2 m, D-4) et en **profil vertical par strate** (0-2, 2-5, 5-10, 10-20, > 20 m) | poids ForPT |
| `forpt_age(laz_dir, aoi)` | âge structurel par UGF avec intervalle, tête de régression FORage | point de contrôle « age » |
| `forpt_segment(laz_dir, aoi)` | instances d'arbres (`sf`) : hauteur, diamètre de houppier | SelectAnyTree en mode automatique tant que ForPT n'a pas d'instances (D-1) |
| `forpt_mort(laz_dir, aoi)` | classe vivant / mort sur pied | **à entraîner** (D-2) |

Patron d'installation : celui d'`opencanopy` (environnement Python isolé par
reticulate, torch CPU par défaut, GPU si présent). Licences des poids ForPT et
du code SelectAnyTree **à vérifier** avant la première ligne (D-6).

## 4. Livrable cœur

- **B5 — stratification 3D** : entropie de Shannon de la répartition des
  points (ou de la densité foliaire) entre les cinq strates, par UGF, sur
  0-100 (100 = répartition uniforme entre strates). Calculable **sans ForPT**
  à partir du seul nuage (`lidR` en Suggests) ; ForPT n'est utile que pour
  séparer bois / feuille (D-3). Conditionnel (source : LiDAR). B2 reste.
- **N4 — bois mort sur pied et très gros bois** : densité par hectare
  d'arbres morts sur pied et de très gros bois (≥ 70 cm estimés), rapportée
  aux seuils de la littérature (dendro-microhabitats, Paillet et al.).
  Conditionnel ; dépend de D-1 et D-2. Fiche obligatoire avec l'incertitude
  de la classification vivant / mort en feuillus hors feuilles.
- **N5 structurel** : `indicateur_n5_distance_reference()` accepte déjà tout
  embedding ; `n5_source = "forpt"` (ou `"fused"`, concaténation AlphaEarth +
  ForPT par UGF). Aucun code nouveau dans N5.
- **T1 désaturé** (écart n° 10) : `indicateur_t1_anciennete(age_structurel =)`
  ; au-delà de 120 ans, l'âge structurel ForPT prolonge l'échelle jusqu'à 300
  ans. **Changement de sens au sens de la spec 057** si le défaut change :
  palier `INDICATOR_SENSE_VERSION` côté app (D-5).
- `segment_houppiers(tops =)` : accepte les instances 3D de `forpt_segment()`
  à la place du watershed 2D ; OTB/LSMS reste le repli sans LiDAR.
- **Dimensionnement** `simulate_density_sensitivity(laz_dir, aoi, densites =
  c(10, 5, 2))` : sous-échantillonne le LiDAR HD et mesure la stabilité de B5,
  N4 et N5 ; résultat affiché dans l'onglet terrain pour justifier, ou non,
  une campagne drone (NDP 2).
- Décompte : 42 → **44 indicateurs** (B5, N4), 13 conditionnels.

## 5. Ordre proposé

1. **B5 sans ForPT** (cœur seul, `lidR`) : utile tout de suite, testable sur
   un nuage synthétique et sur les dalles d'exemple d'`inst/extdata/aba.model/`.
2. `simulate_density_sensitivity()` pour B5.
3. `forptnemeton` : `forpt_embed()` puis `forpt_age()` (points de contrôle
   publiés) ; N5 structurel et T1 désaturé.
4. `forpt_segment()` via SelectAnyTree, puis N4 quand D-2 est tranchée.

## 6. Pièges à écrire dans les fiches

1. **Densité.** LiDAR HD ≈ 10 pts/m² ; les sous-étages sont sous-échantillonnés
   sous un couvert dense : B5 sous-estime la stratification des peuplements
   fermés. Le dimensionnement le mesure.
2. **Saison.** Un vol en feuilles et un vol hors feuilles ne donnent pas la
   même stratification ni la même classe vivant / mort en feuillus.
3. **Âge structurel ≠ âge.** Un peuplement de station pauvre « paraît » plus
   jeune ; l'âge ForPT est appris sur des forêts qui ne sont pas françaises.
4. **Très gros bois estimé.** Le diamètre à 1,30 m n'est pas mesuré par le
   LiDAR aérien : il est déduit de la hauteur et du houppier.

## 7. Critères d'acceptation (brief, précisés)

1. B5 et N5 structurel calculés sur les dalles LiDAR HD d'un projet BFC réel ;
   temps mesuré, objectif du brief : < 30 min de **CPU** pour 1 000 ha (D-4).
2. N4 confronté aux relevés QField de bois mort sur au moins 20 placettes.
3. Fiches B5 et N4 complètes (spec 052).

## 8. Décisions ouvertes

| # | Question | Décision (validée le 2026-11-06) |
|---|---|---|
| D-1 | Instances d'arbres : ForPT n'en fournit pas encore | SelectAnyTree en mode automatique (premier clic sur les sommets du MNH) ; basculer sur ForPT quand ses instances seront publiées |
| D-2 | Classifieur vivant / mort : aucun modèle publié | **reporter N4** : l'entraîner demande des étiquettes (placettes QField de bois mort) ; d'abord B5, N5 structurel, T1 |
| D-3 | B5 avec ou sans ForPT | **sans** pour la première version (entropie des points par strate, `lidR`) ; ForPT pour séparer bois et feuille ensuite |
| D-4 | Objectif « 30 min de CPU pour 1 000 ha » (≈ 100 millions de points) | non tenable pour un transformeur sur CPU (ordre de grandeur, à mesurer) : viser le GPU ponctuel (ADR-003, Scaleway L4) pour `forpt_embed()`, garder l'objectif CPU pour B5 sans ForPT |
| D-5 | T1 désaturé : nouveau mode ou nouveau défaut ? | nouvel argument `age_structurel =`, défaut inchangé : pas de palier de sens |
| D-6 | Licences des poids ForPT et du code SelectAnyTree | à vérifier avant tout code ; `forptnemeton` en GPL-3 si elles le permettent |
| D-7 | Dépôt `forptnemeton` | à créer par Pascal, comme `alphaearthnemeton` |

## 9. Écarts cœur → app

À ouvrir dans PLAN.md à la validation : B5 et N4 (couches, statuts), N5
structurel (`n5_source`), badge de dimensionnement drone dans l'onglet
terrain.

## 10. Avancement

| Étape | État |
|---|---|
| 1. B5 sans ForPT | ✅ **2026.11.5** — `indicateur_b5_stratification()`, fiche B5, écart n° 26 |
| 2. `simulate_density_sensitivity()` | ✅ **2026.11.6** — B5 seul ; N4 et N5 structurel à ajouter quand ils existeront |
| 3. `forptnemeton` : `forpt_embed()`, `forpt_age()` ; N5 structurel, T1 désaturé | T1 côté cœur ✅ **2026.11.7** (`age_structurel =`, `t1_source`) ; `forptnemeton` ✅ **2026.11.2** : `forpt_embed()` et `forpt_age()`, **jamais exécutés sur GPU** ; N5 structurel : rien à coder dans le cœur (`embedding = forpt_embed(...)`) |
| 4. `forpt_segment()` (SelectAnyTree), N4 | N4 reporté (D-2) |

**Écarts au § 4 lors du codage de B5.**

- Strates : le sol (retours sous `hauteur_sol = 0,5 m`) n'est compté dans
  aucune strate ; la première strate est donc 0,5-2 m. Sinon une UGF ouverte
  compterait son sol comme une strate de végétation.
- Deux profils, comme le § 4 l'autorisait (« points, ou densité foliaire ») :
  `"points"` par défaut (D-3), `"densite_foliaire"` (MacArthur et Horn 1969)
  en option.
- Classes LiDAR HD gardées : 1 à 5 et 9 ; bâti, bruit, ponts et classes IGN
  64-67 écartés.
- Statuts : `calculated`, `skipped_no_lidar`, `skipped_no_coverage`,
  `skipped_low_density` (moins de 100 retours).

**Confrontation au terrain** (96 placettes du Vercors, `inst/extdata/aba.model/`,
≈ 14 retours/m², Spearman) : B5 `points` contre CV des hauteurs d'arbres
mesurées 0,55, contre hauteur maximale −0,07 ; `densite_foliaire` 0,62 et
0,06. Part moyenne de la strate 0,5-2 m : 2,6 % en `points`, 6,3 % en
`densite_foliaire`. **Profil par défaut, tranché par Pascal le 2026-11-06 : `points`.**
`densite_foliaire` reste une option ; changer le défaut plus tard serait un
changement de sens (spec 057).

**Temps** : 7 s par profil pour 2 millions de points sur un cœur, lecture LAZ
non comprise, soit environ 6 min pour 1 000 ha à 10 retours/m² : l'objectif
CPU du critère 1 tient pour B5 (D-4). Critère 1 lui-même (dalles d'un projet
BFC réel) : non mesuré, faute de dalles LiDAR HD et de lidR dans la session.

**Dimensionnement** (2026.11.6). Signature retenue :
`simulate_density_sensitivity(units, nuage, densites = c(10, 5, 2), ...)`
plutôt que `(laz_dir, aoi, ...)` du § 4 : même entrée que B5 (table, `LAS` ou
dalles). Éclaircie par impulsion quand le nuage porte `gpstime`, sinon par
retour. Vercors, 16 retours/m², 5 répétitions : écart au 90ᵉ centile de 0,8
(10 retours/m²), 1,5 (5), 2,6 (2) et 3,9 points (1). B5 converge bien en
dessous de la densité du LiDAR HD sur des placettes de 700 m² : le badge
drone de l'app dira donc le plus souvent `densite_suffisante` pour B5 ; ce
sera N4 (arbres morts, très gros bois) qui pourra justifier un drone.

**D-6, licences vérifiées le 2026-11-06.**

| Élément | Licence | Conséquence |
|---|---|---|
| Code ForPT (`github.com/prs-eth/ForPT`) | **MIT** (fichier LICENSE du dépôt) | compatible avec `forptnemeton` en GPL-3 |
| Poids ForPT (Hugging Face `prs-eth/ForPT`) | **non vérifiée** : Hugging Face est bloqué depuis la session ; la carte du modèle ne l'affiche pas dans les extraits trouvés. L'encodeur LitePT dont il dérive est sous MIT | **à lire par Pascal** sur la carte du modèle avant d'écrire `forpt_embed()` |
| SelectAnyTree (`github.com/thanhhff/SelectAnyTree`) | **CC BY-NC 4.0** (annoncée dans le README, héritée de ForestFormer3D / OneFormer3D) ; **poids non publiés** (« coming soon ») | non commercial, et incompatible avec la GPL-3 (une restriction de plus) : ne peut pas être embarqué dans `forptnemeton` |

**Conséquence pour D-1 (instances d'arbres).** SelectAnyTree ne peut pas être
le chemin par défaut : pas de poids, et une licence non commerciale.
Proposition à valider : instances d'arbres par les algorithmes de lidR déjà
utilisés par `segment_houppiers()` (sommets `lmf`, puis `dalponte2016` ou
`silva2016` sur le MNH, ou `li2012` sur le nuage), dans le cœur, sans modèle ;
basculer sur ForPT quand ses instances seront publiées, si leur licence le
permet. SelectAnyTree resterait un appel optionnel, installé par
l'utilisateur, pour un usage non commercial.

**D-1 révisée, validée par Pascal le 2026-11-06 : instances d'arbres par
lidR par défaut, dans le cœur, sans modèle ; SelectAnyTree en option.** `segment_houppiers()` fournit déjà les instances
nécessaires : un polygone par houppier, `h_max` (hauteur de l'apex) et
`surface_m2` (d'où un diamètre de houppier `2 * sqrt(surface_m2 / pi)`), par
`lmf` puis `dalponte2016` ou `silva2016` de lidR sur le MNH. Aucun code
nouveau à ce stade pour le chemin par défaut.

**SelectAnyTree en option** (demandé par Pascal le 2026-11-06), sous trois
conditions dictées par sa licence et ADR-009 :

1. **Hors du cœur** : c'est du Python (torch, ForestFormer3D) ; il vivra
   dans `forptnemeton` comme `forpt_segment(methode = "selectanytree")`,
   appelé par reticulate, comme `opencanopy`.
2. **Jamais embarqué** : CC BY-NC 4.0 ajoute une restriction que la GPL-3
   interdit ; `forptnemeton` ne copie ni son code ni ses poids. L'utilisateur
   l'installe lui-même ; la fonction vérifie sa présence et rappelle la
   licence (usage non commercial) au premier appel.
3. **Quand les poids seront publiés** (annoncés « coming soon ») : sans
   poids, il n'y a rien à appeler. Premier clic automatique sur les sommets
   `lmf` du MNH, comme le décrivent les auteurs.

Sortie identique au chemin lidR (un houppier par arbre, `h_max`,
`surface_m2`, plus `methode`), pour que `segment_houppiers(tops =)` et N4 ne
dépendent pas du choix. Le chemin par le nuage (`li2012`) et l'estimation du
diamètre à 1,30 m pour le très gros bois viendront avec N4, qui reste
reporté (D-2). ForPT remplacera lidR quand ses instances seront publiées, si
leur licence le permet.

**`forptnemeton` livré le 2026-11-06 (pobsteta/forptnemeton#1, #2), ce que
le code de ForPT a appris.**

- **GPU obligatoire** : l'attention de LitePT appelle `flash_attn`, sans
  version CPU (`forpt/models/litept/litept_v1m2_pretrain.py`). D-4 tient :
  GPU ponctuel, l'objectif CPU ne vaut que pour B5.
- **`forpt_embed()`** : cellules de 10 m (et non des voxels de 2 m comme au
  § 3 : une cellule de 2 m ne contient qu'une quarantaine de retours de
  LiDAR HD), prétraitement des configurations ForPT (`CenterShift`, grille
  de 5 cm, coordonnées en caractéristiques), embedding = moyenne des 504
  sorties de l'encodeur, comme la tête d'âge. Le profil vertical par strate
  du § 3 n'est pas fait : à reprendre si N5 structurel le demande.
- **`forpt_age()` travaille par arbre**, pas par UGF : la tête d'âge est
  entraînée sur FORage, un nuage par arbre (8 192 points). L'âge par UGF est
  la médiane des arbres dont le houppier (`segment_houppiers()`, D-1) tombe
  dans l'UGF, prête pour `indicateur_t1_anciennete(age_structurel =)`.
  FORage contient des arbres de LiDAR HD aérien (`*_ALSHD_*`).
- **Hypothèse à vérifier** : le repère des nuages d'arbres de FORage n'est
  pas documenté (la configuration ne recentre pas, les coordonnées servent
  de caractéristiques) ; `forpt_age()` recentre x, y sur l'arbre et garde la
  hauteur au-dessus du sol. À contrôler sur un fichier `coord.npy` de FORage
  avant de croire les âges.
- **Reste** : un premier passage sur GPU (Pascal), la licence des poids
  (D-6), SelectAnyTree en option quand ses poids seront publiés, N4 (D-2).
