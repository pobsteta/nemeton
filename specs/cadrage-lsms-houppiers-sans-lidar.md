# Cadrage — extraire les houppiers sans LiDAR : faut-il OTB/LSMS ?

> **Statut** : cadrage, 2026-08-24. Aucun code écrit, aucune dépendance ajoutée.
> **Question posée** : « quand il n'y a pas de LiDAR, peut-on extraire les
> houppiers avec OTB et la fonction LSMS ? »
> **Réponse courte** : c'est possible, mais **ce n'est probablement pas le
> problème à résoudre** — le cas « sans LiDAR » est déjà couvert, et LSMS ne
> peut pas produire ce qui fait la valeur de la couche. Détail et mesures
> ci-dessous ; la décision reste à Pascal.

---

## 1. La prémisse, vérifiée avant tout le reste

**`segment_houppiers()` (v0.184.0) ne demande pas de LiDAR. Elle demande un
MNH.** Et le MNH sur lequel elle a été validée n'en vient pas :
`opencanopy` **prédit** `chm_predicted_0_2m.tif` depuis l'**ortho IGN +
IRC à 0,20 m** (4 canaux R, G, B, NIR) avec un modèle Open-Canopy entraîné sur
SPOT. Vérifié dans `R/pipeline_aoi_to_chm.R` : les seules entrées téléchargées
sont `download_ortho_for_aoi()` et la couche IRC. Aucun `.laz` n'intervient.

Autrement dit, **les 2 046 houppiers de Couchey ont déjà été extraits sans
LiDAR**. Le chemin existe, il est livré, il tourne en 11 s sur 36 ha.

C'est le point le plus utile de ce document : avant de chercher un substitut au
LiDAR, il faut savoir qu'on n'en utilisait pas.

## 2. Ce que LSMS apporterait — et ce qu'il ne peut pas apporter

LSMS (*Large-Scale Mean-Shift*) segmente une **image** en régions homogènes,
spectralement et spatialement. Sur une ortho IRC à 20 cm, ces régions épousent
raisonnablement les couronnes bien isolées.

**Mais une région n'a pas de hauteur.** Or la couche `houppier` n'existe que
pour porter **`h_max`** : elle pré-remplit la hauteur d'une tige au martelage
par un point-dans-polygone. Un polygone de houppier sans hauteur ne remplit
rien — c'est un contour, pas une donnée de martelage.

Il faudrait donc, de toute façon, un MNH pour renseigner `h_max` par zonale.
**Et si l'on a un MNH, on a déjà tout ce dont `segment_houppiers()` a besoin.**
LSMS ne remplace pas le MNH ; il ne peut que proposer d'autres *contours* pour
des hauteurs qui viennent, elles, du même raster qu'aujourd'hui.

Deux difficultés propres à la segmentation d'ortho, qui ne se posent pas sur un
MNH : l'**ombre portée** découpe une même couronne en une partie éclairée et une
partie sombre — deux régions là où il y a un arbre ; et une couronne de chêne
mûr n'est pas spectralement homogène (trous, branches, sous-étage visible).

## 3. L'outillage, mesuré et non supposé

OTB **est déjà installé** sur la station — version **10.0.0**, dans
`~/miniforge3/envs/nemeton-reconfort`, apporté par iota2 (chaîne RECONFORT).

**Mais ce build ne contient aucune application de segmentation.** Relevé le
2026-08-24 : 86 modules d'application, dont zéro `LSMSSegmentation`,
`LSMSSmallRegionsMerging`, `LSMSVectorization`, `LargeScaleMeanShift` ou
`Segmentation`. Seuls les **en-têtes C++** du filtre mean-shift sont présents
(`include/OTB-10.0/otbMeanShiftSmoothingImageFilter.h`) — la bibliothèque, pas
l'outil.

Conséquence concrète : **utiliser LSMS demande une nouvelle installation d'OTB**
(paquet officiel complet, ~1,5 Go) dans un environnement dédié, avec l'isolation
que le projet impose déjà à ses environnements Python/binaires
(cf. « Infra — Isolation reticulate multi-env » dans `PLAN.md`). Ce n'est pas
« OTB est là, autant s'en servir ».

## 4. Ce que les mesures disent du besoin réel

Sur l'AOI de 4 ha de Couchey, en faisant varier la seule fenêtre de recherche :

| `ws` | Houppiers | Densité | Diamètre équivalent médian |
|---|---|---|---|
| 2 m | 358 | 90/ha | 7,9 m |
| 3 m | 316 | 79/ha | 8,3 m |
| 5 m | 266 | 66/ha | 9,1 m |
| 8 m | 213 | 53/ha | 9,7 m |

Deux lectures, et la seconde compte plus que la première.

**Le MNH prédit porte une vraie structure.** Un raster bruité exploserait à
`ws = 2` (un maximum local par accident de surface) ; ici le nombre ne fait que
×1,7 quand `ws` fait ÷4. La détection réagit à des apex, pas à du grain.

**Le facteur limitant n'est pas la source du MNH, c'est le choix de `ws`.** Rien
dans la donnée ne désigne la bonne valeur : 53 ou 90 tiges/ha sont deux
peuplements différents, et seul le terrain tranche. **LSMS ne supprimerait pas
cette indétermination — il la déplacerait** vers ses propres paramètres (rayon
spatial, rayon spectral, taille minimale de région), avec la même absence de
vérité dans la donnée seule.

## 5. Recommandation

**Ne pas ajouter OTB/LSMS pour cet usage.** Trois raisons, par ordre de poids :

1. le besoin annoncé (« sans LiDAR ») est **déjà satisfait** — le MNH est prédit
   depuis l'imagerie ;
2. LSMS ne peut pas produire `h_max`, qui est **la raison d'être** de la couche ;
3. le coût est une dépendance binaire lourde de plus, dans un projet qui en
   porte déjà trois isolées (FORDEAD, RECONFORT/iota2, Open-Canopy).

**Ce qu'il faut faire à la place, et qui n'a pas été fait** : vérifier la
concordance des houppiers actuels avec un **martelage réel**. Personne n'a
encore contrôlé qu'une tige pointée au GNSS tombe dans *son* houppier. Tant que
ce contrôle manque, changer d'algorithme de segmentation revient à optimiser
sans savoir dans quel sens.

## 6. Si l'on y va quand même : la seule forme qui se défend

Un cas justifierait LSMS : **si la validation terrain montre que les couronnes
sont mal délimitées là où le MNH prédit est lisse** (peuplements denses, où le
modèle ML tend à fondre deux houppiers voisins). Le remède serait alors
**hybride, jamais un remplacement** :

| Étape | Source | Rôle |
|---|---|---|
| Contours | LSMS sur l'ortho IRC 0,20 m | délimiter, là où le spectral sépare ce que la hauteur ne sépare pas |
| Attribution | MNH prédit | `h_max` par `terra::zonal()`, comme aujourd'hui |
| Arbitrage | règle existante | rien hors 1-70 m, recouvrements admis, aucun repli |

Le contrat de sortie ne bougerait pas — `houppier_id`, `h_max`, `surface_m2` —
et `segment_houppiers()` gagnerait un `algorithme = "lsms"` plutôt qu'une
fonction concurrente.

**Trois points durs à ne pas sous-estimer**, si la question revient :

* **L'ombre.** Sans traitement, une couronne éclairée et son ombre font deux
  régions. Un masque NDVI/NDWI (celui que `opencanopy` calcule déjà pour
  `chm_vegetation_0_2m.tif`) limiterait la casse, sans la supprimer.
* **La taille.** 418 M de cellules à 0,20 m : LSMS est conçu pour ça (c'est le
  sens de *Large-Scale*, il travaille par tuiles sur disque), mais la chaîne
  écrit plusieurs rasters intermédiaires de la taille de l'entrée. Prévoir le
  disque, pas seulement la RAM — le pipeline amont est déjà tombé une fois
  là-dessus.
* **Le paramétrage.** `spatialr`, `ranger`, `minsize` doivent être calés par
  essence et par structure de peuplement. C'est un chantier de calibration, pas
  un réglage par défaut ; sans données de martelage pour l'arbitrer, il n'est
  pas calable.

## 7. Un endroit où LSMS serait, lui, le bon outil

Hors houppiers : **B4 (diversité spectrale) et L3 (hétérogénéité spectrale)**
travaillent sur l'imagerie et cherchent précisément des régions homogènes. Une
segmentation objet y remplacerait avantageusement une fenêtre glissante. Si OTB
doit un jour entrer dans le projet, c'est probablement par cette porte-là qu'il
faut le faire entrer — pas par les houppiers.
