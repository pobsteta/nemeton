# Spec 059 — MNT, MNS et MNH depuis un nuage de points (IGN seul, LiDAR drone, photogrammétrie drone)

> **Statut** : livré en v2.1.0, 2026-10-09. Décisions de Pascal au § 7.
> **Origine** : demande de Pascal le 2026-10-09 : « dans le cas de l'acquisition
> d'un MNT par drone, y a-t-il un traitement qui crée depuis ce jeu de points,
> classification des points, puis MNT et MNH et MNS ? », avec en plus le cas où
> « l'IGN livre uniquement le nuage de points sans le MNT et le MNH ».
> **Version cible** : 2.1.0 (ajout d'API experimental, rien de cassé).
> **Dépendance** : aucune nouvelle. `lasR` est déjà en Suggests, et la version
> 0.21.0 installée fournit `classify_with_csf()`, `classify_with_ptd()`,
> `classify_with_ivf()`, `classify_with_sor()` et `pit_fill()`. Pas besoin de
> `RCSF`.

## 1. Besoin

Une seule fonction qui prend un nuage de points et rend les trois modèles
numériques, quelle que soit la source :

| Source | Classes fournies | Points sol sous couvert | MNT tiré du nuage |
|---|---|---|---|
| **A. IGN LiDAR HD, nuage seul** (MNT/MNS/MNH pas encore publiés sur la dalle) | oui | oui | oui |
| **B. LiDAR drone** | en général non (0 ou 1) | oui | oui, après classification |
| **C. Photogrammétrie drone** (nuage SfM) | non | **non** : la photo ne voit que la surface | **non** : il faut un MNT externe |

Définitions :
- **MNT** : surface du sol ;
- **MNS** : surface la plus haute (canopée, bâti) ;
- **MNH** : hauteur au-dessus du sol, soit MNS − MNT.

## 2. Existant (lu dans le code le 2026-10-09)

- **`compute_dtm_chm_from_laz()`** (`R/lidar_processing.R`, stable) :
  - pipeline `lasR` : lecture, TIN des points de classe 2, MNT, normalisation,
    MNH (z normalisé maximal) ;
  - **suppose un nuage déjà classé** et **ne produit pas de MNS** ;
  - sert de repli à `resolve_project_dem()` / `resolve_project_chm()` quand
    seul `cache/layers/lidar_nuage/` est présent. Le cas A est donc **déjà
    couvert pour le MNT et le MNH**, mais pas pour le MNS.
- **Constat en préparant la spec** : le filtre anti-bruit du MNH écarte les
  classes ASPRS 7 et 18. Une vraie dalle IGN
  (`LHD_FXX_0633_6767_PTS_LAMB93_IGN69.copc.laz`, échantillon de 5 %)
  contient les classes **1, 2, 3, 4, 5, 6, 9 et 67**, ni 7 ni 18. Le filtre
  ne fait donc rien sur l'IGN : si une dalle contient des artefacts, ils
  entrent dans le MNH. La liste des classes de bruit IGN est à fixer d'après
  le descriptif LiDAR HD (65 et 66 attendues, absentes de cette dalle). À
  corriger en patch, indépendamment de cette spec (§ 8). **Corrigé en
  v2.1.1** : 66 = points virtuels sous les ponts, « pour les retirer dans les
  MNx » ; 65 = artefacts (dalles antérieures à mars 2025). Les deux sont
  exclues des MNx, et supprimées avant reclassification.
- **`inst/datasources/FR.json`** déclare `lidar_mns` (IGN, raster 1 m) et
  `lidar_copc` (nuage), mais aucune source drone.
- **NDP** : le niveau 2 liste `drone_rgb` et `lidar_drone` comme sources
  (`R/ndp.R`), mais `R/ndp.R:499` note « drone… pas encore dans le pipeline ».
- **Tutoriels** : le 02 (lidR, normalisation, MNH) et le 08 (recalage) sont
  pédagogiques, sans fonction exportée.

## 3. API proposée

```r
traiter_nuage_points(
  nuage,                     # dossier ou vecteur de fichiers .las/.laz/.copc.laz
  type        = c("lidar_ign", "lidar_drone", "photogrammetrie"),
  res         = NULL,        # NULL : 0,5 m pour lidar_ign, 0,25 m pour les drones
  classifier  = TRUE,        # reclasser bruit et sol, IGN compris (décision 3)
  methode_sol = c("csf", "ptd"),
  csf         = list(),      # paramètres passés à lasR::classify_with_csf()
  mnt_externe = NULL,        # SpatRaster ou chemin ; obligatoire pour "photogrammetrie"
  mnh_reference = NULL,      # MNH IGN : repère le sol nu du recalage (décision 5)
  recalage_vertical = TRUE,  # photogrammétrie seulement (§ 4.3)
  aoi         = NULL,
  dossier     = NULL,        # NULL : à côté du nuage
  ncores      = 1L,
  overwrite   = FALSE,
  verbose     = TRUE
)
```

Elle rend une liste :
- `mnt`, `mns`, `mnh` : chemins des GeoTIFF ;
- `classes` : table des classes après traitement ;
- `qualite` : contrôles du § 5.

Statut : **experimental** (spec 057).

`compute_dtm_chm_from_laz()` reste telle quelle, puisqu'elle est stable. La
nouvelle fonction partage ses helpers de pipeline et de cache : clé de cache,
écriture atomique, découpe AOI.

## 4. Traitement par source

### 4.1 A — IGN, nuage seul

Un seul passage `lasR` :
1. lecture des dalles ;
2. TIN des classes sol ;
3. MNT ;
4. MNS = maximum de tous les points, sauf le bruit ;
5. normalisation par le TIN ;
6. MNH = maximum normalisé.

Reclassification par défaut (décision 3) : toutes les classes sont remises à 1,
puis bruit (`classify_with_ivf()`) et sol (CSF) sont reclassés.
`classifier = FALSE` garde les classes livrées. Le MNH par normalisation des points est plus
juste en pente que la différence de rasters MNS − MNT.

### 4.2 B — LiDAR drone

Même pipeline, précédé de deux étapes :
1. **le bruit** : `classify_with_ivf()` (points isolés) ;
2. **le sol** : `classify_with_csf()` par défaut, `classify_with_ptd()` en
   option.

Défauts CSF à caler sur un jeu réel (`cloth_resolution`, `rigidness`,
`slope_smooth` en terrain pentu). Résolution plus fine, car la densité d'un
drone dépasse de loin celle de l'IGN (≈ 10 pts/m²).

### 4.3 C — Photogrammétrie drone

1. **MNS** : maximum du nuage SfM, après filtrage du bruit
   (`classify_with_sor()`).
2. **MNT** : jamais tiré du nuage SfM par défaut. On prend `mnt_externe`,
   typiquement le MNT IGN raster ou celui que produit le cas A. Il est
   rééchantillonné sur la grille du MNS (bilinéaire).
3. **Recalage vertical** : un nuage SfM est souvent décalé en altitude
   (géoréférencement sans points d'appui, hauteur ellipsoïdale contre IGN69).
   Le décalage est la médiane de MNS − MNT sur les pixels de sol nu, dont la
   définition reste à trancher (§ 7, question 5). On le soustrait du MNS et
   on le rend dans `qualite`.
4. **MNH** = MNS − MNT. Les valeurs négatives sont mises à 0 et comptées.

Sans `mnt_externe`, la fonction s'arrête et propose les deux sources
possibles.

## 5. Contrôles qualité (rendus dans `qualite`)

- nombre de points, densité moyenne (pts/m²), part de sol, part de bruit ;
- part de MNH inférieure à −0,5 m avant écrêtage (un seuil à 0 compterait le
  bruit de mesure sur sol nu : 40 % des pixels en photogrammétrie simulée) ;
- photogrammétrie : décalage vertical appliqué, son écart interquartile et le
  nombre de pixels de sol nu utilisés.

Avertissements : part de sol inférieure à 5 % ; écart interquartile du sol nu
supérieur à 0,5 m (décalage incertain) ; moins de 100 pixels de sol nu, ou pas
de `mnh_reference` (pas de recalage). Le décalage lui-même est corrigé, pas
signalé comme anomalie. La mesure des « trous » sous couvert est abandonnée :
à 0,5 m, la plupart des pixels n'ont aucun point sol même à découvert.

## 6. Sorties et cache

- **Arborescence** : sous `cache/layers/`, dossiers `lidar_mns/` (cas A, à
  côté des `lidar_mnt/` et `lidar_mnh/` existants) et `drone_mnt/`,
  `drone_mns/`, `drone_mnh/` (cas B et C).
- **Clé de cache** : nuage + résolution + paramètres de classification. Elle
  suit la même règle que `compute_dtm_chm_from_laz()` : jamais resservie si
  la clé diffère.
- **`resolve_project_chm()` / `resolve_project_dem()`** : faut-il préférer
  les produits drone, plus récents et plus fins, aux produits IGN ? Voir § 7.

## 7. Décisions de Pascal (2026-10-09)

| Question | Décision |
|---|---|
| Nom | `traiter_nuage_points()` |
| Résolutions par défaut | 0,5 m pour l'IGN, 0,25 m pour le drone |
| Classes IGN | on reclasse par défaut |
| Eau (classe 9) | comptée comme sol pour le TIN du MNT |
| Sol nu du recalage photogrammétrique | MNH IGN < 0,5 m (`mnh_reference`) |
| NDP | produits drone → NDP 2 (`detect_ndp_from_cache()`) |
| Priorité dans `resolve_project_*()` | drone d'abord, puis LiDAR HD publié, puis `ign_*` recalculés |

Conséquence de « drone d'abord » : un vol de drone couvre souvent une partie
du projet seulement, et `resolve_project_dem()` / `resolve_project_chm()` le
rendent quand même. Un appelant qui veut la couverture complète passe un
`validate` qui vérifie l'emprise.

## 7 bis. Mesures (dalle IGN `LHD_FXX_0633_6767`, 20,7 M points, 4 cœurs)

| | Écart médian absolu | p95 | Biais |
|---|---|---|---|
| MNT reclassé vs MNT IGN publié | 1,1 cm | 7,7 cm | −0,7 cm |
| MNH vs MNH IGN publié | 0 m | 1,12 m | 0 m |

Durée : 2 min 15 s par dalle (reclassification comprise). Classes après
traitement : 14,4 M sol, 6,3 M autres, 4 bruit. Photogrammétrie simulée (MNS
de la dalle + 2,30 m, MNT et MNH IGN en référence) : décalage retrouvé
2,303 m, écart interquartile 1,5 cm, 3,2 M pixels de sol nu.

## 8. Hors périmètre

- La photogrammétrie elle-même (photos → nuage) : ODM, Metashape, etc.
- La segmentation des houppiers, qui existe déjà en aval du MNH.
- L'interface de l'app : un brief sera émis une fois le cœur livré.
- La correction du filtre de bruit de `compute_dtm_chm_from_laz()` (§ 2). Ce
  patch est séparé, à faire avant ou avec cette spec.

## 9. Critères d'acceptation

- **Cas A** : sur une dalle IGN dont le MNH et le MNT publiés existent, l'écart
  médian absolu au produit IGN est inférieur à 0,5 m (MNT) et à 1 m (MNH).
  Seuils à confirmer à la première mesure.
- **Cas B** : sur un nuage IGN dont on efface les classes (simulation d'un
  drone LiDAR non classé), la classification CSF retrouve le MNT IGN à 0,5 m
  près en médiane.
- **Cas C** : nuage synthétique avec un décalage vertical connu, que le
  recalage doit retrouver à 5 cm près.
- **Tests unitaires** sur nuages synthétiques (sol plan ou en pente, arbres
  coniques). Tests réels gardés par une variable d'environnement, hors CI.
