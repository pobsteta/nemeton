> **Décisions de Pascal (2026-10-06)** : les cinq recommandations sont
> retenues, livrées en **1.0.0** avec les trois défauts trouvés en mesurant.
> 1. R2 : TRI retiré (redondant avec la pente). TWI ramené à 2 m
>    (`TWI − ln(pas/2)`), fenêtre fixe commune **[2,5 ; 9]** pour W3, F2 et R3.
> 2. (idem 1 pour W3/F2.)
> 3. N1 : terme urbain constant +25 retiré, `N1 = (N1 − 25) / 0,75`.
> 4. P3 : diamètre seul, `p3_status = "diametre_seul"`.
> 5. Indice de station hors courbe : NA, `p2_status = "hors_courbe"`, avec la
>    correction du mappage d'essence.
> Défauts corrigés dans la même release : TWI calculé en degrés sur MNT
> lon/lat ; TWI dépendant de la résolution ; essence et âge fabriqués par
> `enrich_parcels_bdforet()`.

# Spec 056 — Choix de méthode ouverts par l'audit 1.0 : mesures

*2026-10-06 — nemeton 0.216.0.9000 — mesures seules, aucun code du paquet modifié.*

Ce document mesure, sur les six projets en cache, l'effet des options de cinq
choix de méthode que l'audit 1.0 a laissés en « décision »
(`specs/audit-1.0/rapport-audit.md`, l. 169, 178, 199, 210 et 235). Pour chaque
choix, il donne ce qui a été mesuré, un tableau avant/après et une
recommandation. La décision revient à Pascal.

## Reproduire

```bash
# 1. Mesures par projet (≈ 1 min chacune, MNT LiDAR ramené à 2 m)
for p in ~/.local/share/nemeton/projects/*/; do
  Rscript specs/056-choix-methode/mesures_projet.R "$p" /chemin/sortie
done
# 2. Tableaux Markdown repris ci-dessous
Rscript specs/056-choix-methode/agrege.R /chemin/sortie
```

Les dossiers des projets sont lus sans y écrire. Les caches dont le calcul a
besoin (TWI, vent NASA POWER) sont redirigés vers `tempdir()`.

## Données et protocole commun

| Projet | UGF | MNT de l'app | CHM | `indicators.parquet` |
|---|---:|---|---|---|
| Fordead | 30 | LiDAR HD 0,5 m → 2 m | MNH LiDAR | oui |
| Reconfort | 24 | LiDAR HD 0,5 m → 2 m | MNH LiDAR | oui |
| ForetAccess | 30 | LiDAR HD 0,5 m → 2 m | MNH LiDAR | non (projet en brouillon) |
| Dabo | 4 | LiDAR HD 0,5 m → 2 m | MNH LiDAR | non (projet en brouillon) |
| Couchey | 76 | IGN WMS **EPSG:4326** (≈ 19 m) | Open-Canopy 1,6 m | oui |
| Aumur | 15 | IGN WMS **EPSG:4326** (≈ 19 m) | Open-Canopy 1,6 m | oui |

- **Unités.** Les UGF sont reconstituées comme dans l'app : ténements
  dissous par `ug_id`, en Lambert-93.
- **Terrain.** Le MNT est celui que choisit `get_dem_raster()` (LiDAR s'il
  existe, sinon `dem.tif`), ramené à 2 m par `.dem_working_res()`. Il n'y a
  pas de microclima dans l'environnement, donc R2 passe par le repli terrain,
  comme dans l'app. Un second passage sert de contrôle : le MNT IGN reprojeté
  à 25 m en L93, soit le même terrain avec une autre source.
- **Scores.** Un échantillon de pixels par UGF (≤ 20 000, tiré au prorata de
  la surface couverte) permet de recalculer exactement R2, R3, W3 et F2 pour
  n'importe quelles bornes. Le clamp n'est pas linéaire, si bien qu'une
  moyenne par UGF ne suffirait pas.
- **R3.** Seule sa composante topographique est mesurée
  (`0,4·exposition + 0,3·pente + 0,3·(1 − TWI normalisé)`). C'est elle que
  touche le choix. Le SPEI et BILJOU n'en dépendent pas.
- **Contrôle de cohérence.** Le recalcul retrouve l'app : pour P2, le nombre
  d'UGF dont l'indice vaut une borne de classe est identique à
  `indicators.parquet` sur les quatre projets calculés (Fordead 24, Reconfort
  16, Couchey 20, Aumur 9).

### Trois constats faits en mesurant (hors des cinq choix, mais ils les conditionnent)

1. **Le TWI est faux sur un MNT en degrés (Couchey, Aumur).**
   `calculate_twi_terra()` calcule l'aire spécifique en `res²/res` dans
   l'unité du raster, ici des degrés (≈ 2,5·10⁻⁴). Le TWI perd alors
   ln(19 m / 2,5·10⁻⁴) ≈ 11 unités et finit écrêté à 0. Dans l'app, W3 vaut
   0,00 sur les 76 UGF de Couchey (médiane du parquet : 0,0000), et la
   composante TWI de F2 vaut 0. Le problème est le même que celui du MNT
   lon/lat de R1 (corrigé en 0.212.x), mais il est resté ouvert pour le TWI.
   Aucune borne, relative ou fixe, ne répare cela : il faut reprojeter le MNT
   avant le TWI.
2. **Le TWI dépend de la résolution.** L'aire spécifique vaut A / pas : pour
   la même pente, TWI(2 m) − TWI(25 m) ≈ ln(25/2) = 2,53. On mesure −1,7 à
   −2,9 sur les quatre projets LiDAR (tableau 1f). Une fenêtre fixe n'est donc
   comparable d'un projet à l'autre qu'à résolution de travail égale, ou après
   un recentrage de `ln(pas/2)`.
3. **L'indice de station est calculé sur une essence et un âge fabriqués.**
   `enrich_parcels_bdforet()` fixe `age = 60` pour toutes les UGF
   (`R/utils.R`, l. 1261). `map_essence_to_species()` renvoie des genres
   latins (`"Abies"`, `"Pinus"`…) que `resolve_species_code()` ne reconnaît
   pas, si bien que **toutes** les UGF tombent sur `BROADLEAF_GENUS`, c'est-à-dire
   la courbe du chêne sessile. Les sapins de Dabo et de ForetAccess sont
   jugés sur la courbe du chêne. Le même défaut fait passer `is_conifer()` à
   FALSE dans P3 : les seuils de diamètre feuillus s'appliquent aux résineux.

---

## 1. R2 / R3 — TRI et TWI normalisés par le maximum de l'emprise

**Code.** `R/indicators-risk.R` : `tri / global(tri, "max")` (R2, l. 599-601)
et `twi / global(twi, "max")` (R3, l. 898-901).

### Distributions brutes (pixels des UGF, grille de l'app)

| Projet | MNT | Pas | TRI q5 | q50 | q95 | **TRI max emprise** | TWI q5 | q50 | q95 | **TWI max emprise** |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Fordead | LiDAR | 2 m | 0,06 | 0,16 | 0,73 | 3,49 | 2,86 | 4,42 | 7,65 | 16,72 |
| Reconfort | LiDAR | 2 m | 0,02 | 0,06 | 0,15 | 1,37 | 4,21 | 5,54 | 8,75 | 16,16 |
| ForetAccess | LiDAR | 2 m | 0,30 | 0,75 | 1,14 | 5,83 | 2,17 | 3,91 | 7,43 | 15,13 |
| Dabo | LiDAR | 2 m | 0,12 | 0,44 | 1,00 | 8,06 | 2,44 | 4,36 | 7,76 | 17,59 |
| Couchey | IGN lon/lat | ≈19 m | 0,47 | 2,17 | 12,03 | 30,43 | 0 | 0 | 0 | 2,37 |
| Aumur | IGN lon/lat | ≈19 m | 0,00 | 0,00 | 0,54 | 1,17 | 0 | 0 | 2,87 | 4,29 |

Contrôle sur le MNT IGN 25 m en L93. Médianes du TRI : Fordead 1,67,
Reconfort 0,47, ForetAccess 8,28, Dabo 5,81, Couchey 1,93, Aumur 0,00 (relief
très plat). Médianes du TWI : 7,2 / 8,4 / 5,6 / 6,0 / 7,2 / 10,8.

**Ce que vaut un même relief selon le projet (normalisation actuelle) :**

| Projet | TRI max | score TRI d'un TRI de 1 m | TWI max | risque TWI d'un TWI de 5 |
|---|---:|---:|---:|---:|
| Fordead | 3,49 | 29 | 16,7 | 70 |
| Reconfort | 1,37 | **73** | 16,2 | 69 |
| ForetAccess | 5,83 | 17 | 15,1 | 67 |
| Dabo | 8,06 | 12 | 17,6 | 72 |
| Couchey | 30,43 | **3** | 2,4 | 0 |
| Aumur | 1,17 | **85** | 4,3 | 0 |

Un même TRI de 1 m vaut de 3 à 85 % de sa composante selon le projet. Le TWI
est presque fixe entre les projets LiDAR, parce que le maximum de l'emprise
(15 à 18) y est un artefact stable de l'accumulation D8 en fond de talweg.

### Bornes fixes candidates

Le dépôt ne contient aucune borne de littérature sourcée, ni dans le code ni
dans `inst/REFERENCES.md`. Les classes de Riley et al. (1999) sont définies
au kilomètre et ne s'appliquent pas à 2 m. Les candidates retenues sont donc
les quantiles 5-95 % poolés, à poids égal par projet (20 000 pixels chacun),
sur la grille métrique : LiDAR 2 m quand il existe, IGN 25 m L93 sinon.

| Grandeur | q5 | q95 |
|---|---:|---:|
| TRI / pas (sans dimension, indépendant de la résolution) | 0,016 | 0,485 |
| TRI en m (LiDAR 2 m seuls) | 0,035 | 0,981 |
| TWI (grille métrique) | 2,56 | 8,99 |

Le TRI brut est un dénivelé entre voisins : il croît avec le pas (×10 à ×20
entre 2 m et 25 m, tableau ci-dessus). Une borne fixe en mètres ne vaut donc
que pour une résolution donnée, et la candidate retenue est **TRI / pas**.

### Avant / après par projet

**R2 (repli terrain, ×100)** :

| Projet | actuel moy (é.-t.) | borne fixe TRI/pas moy (é.-t.) | Δ moy | Spearman | Δ max si l'emprise se réduit aux UGF + 250 m |
|---|---:|---:|---:|---:|---:|
| Fordead | 7,1 (3,7) | 10,4 (5,6) | +3,3 | 1,00 | 0,54 |
| Reconfort | 2,3 (0,5) | 2,1 (0,5) | −0,2 | 0,97 | 0,13 |
| ForetAccess | 14,8 (8,5) | 24,0 (13,9) | +9,3 | 1,00 | 0 |
| Dabo | 11,9 (5,6) | 19,9 (9,5) | +8,0 | 1,00 | 0 |
| Couchey | 6,9 (6,3) | 10,8 (9,9) | +3,9 | 1,00 | 0 |
| Aumur | 2,0 (2,0) | 0,2 (0,2) | −1,8 | 1,00 | 0 |

**R3, composante topographique (×100)** :

| Projet | actuel moy (é.-t.) | borne fixe TWI [2,56 ; 8,99] moy (é.-t.) | Δ moy | Spearman |
|---|---:|---:|---:|---:|
| Fordead | 50,5 (8,4) | 48,8 (8,8) | −1,7 | 0,99 |
| Reconfort | 44,2 (5,4) | 39,8 (5,5) | −4,4 | 0,99 |
| ForetAccess | 65,2 (13,0) | 65,5 (13,5) | +0,3 | 0,99 |
| Dabo | 52,8 (5,4) | 51,1 (5,5) | −1,7 | 1,00 |
| Couchey | 58,7 (8,0) | 58,7 (8,0) | +0,1 | 1,00 |
| Aumur | 47,3 (4,2) | 50,1 (3,0) | +2,8 | 0,79 |

*(Couchey et Aumur sont mesurés sur le TWI en degrés, celui de l'app, donc
nul. Le TWI n'y pèse rien et R3 n'y reflète que l'exposition et la pente.)*

**Même terrain, deux MNT (LiDAR 2 m ou IGN 25 m) : écart absolu moyen par UGF**

| Projet | R2 actuel | R2 fixe | R3 actuel | R3 fixe |
|---|---:|---:|---:|---:|
| Fordead | 0,8 | 2,0 | 7,7 | 13,7 |
| Reconfort | 1,5 | 0,8 | 5,8 | 11,8 |
| ForetAccess | 3,1 | 6,9 | 11,3 | 13,2 |
| Dabo | 2,3 | 0,2 | 6,0 | 6,7 |

### Lecture

- **Classement intra-projet :** il ne bouge pas (Spearman 0,97 à 1,00, sauf
  Aumur pour R3 avec 0,79, sur un TWI déjà cassé). Le choix porte sur le
  niveau et sur la comparabilité, pas sur l'ordre.
- **Niveau :** R2 monte de 3 à 9 points sur les projets accidentés
  (ForetAccess, Dabo) et baisse sur les projets plats. R3 bouge de moins de
  5 points.
- **Comparabilité entre projets :** avec les bornes fixes, un même relief
  donne le même score quel que soit le projet. L'emprise ne compte plus
  (l'écart « emprise réduite » passe à 0 par construction). Le gain est
  important pour R2, où un même TRI valait de 3 à 85 points. Il est faible
  pour R3 sur LiDAR, où le maximum du TWI était déjà quasi constant.
- **Ce que les bornes fixes ne règlent pas :** la dépendance à la source.
  Pour R3, l'écart LiDAR/IGN *augmente* avec une borne fixe (6 à 14 points),
  parce que le TWI à 25 m est décalé d'environ 2,5. La normalisation par le
  maximum masquait ce décalage en le divisant.
- **TRI redondant avec la pente :** la corrélation pixel TRI / pente vaut
  0,98 à 0,99 sur LiDAR et 0,82 à 0,85 ailleurs ; par UGF, 0,86 à 1,00.
  Retirer le terme TRI de R2 (pente seule, repondérée) garde le classement
  (Spearman 0,97 à 1,00).

### Recommandation

1. **R3 : borne fixe TWI [2,5 ; 9]**, la même que la fenêtre commune de la
   section 2. Il faut l'**ancrer à la résolution de 2 m** avec
   `TWI − ln(pas/2)` pour les MNT plus grossiers, et **corriger d'abord le
   TWI en lon/lat** (reprojeter le MNT avant `calculate_twi_terra()`). Sans
   ces deux corrections, une borne fixe rend R3 *moins* comparable entre
   sources.
2. **R2 : retirer le TRI**, soit `R2 = exposition × pente_norm`, la pente
   étant déjà bornée fixe à [0 ; 45°]. Le TRI n'apporte presque rien en plus
   de la pente (r ≥ 0,82), et c'est le seul terme non comparable. Si l'on
   veut garder un terme de rugosité, il faut le normaliser en **TRI / pas**
   sur [0,016 ; 0,49].
3. **Conséquences :** R2 change de +9 à −2 points selon le relief, R3 de
   ±4 points. Le classement intra-projet ne change pas, et les scores
   deviennent comparables entre projets à source égale. Les quatre projets
   calculés ont R2 et R3 dans le parquet : un recalcul les mettra à jour.

---

## 2. W3 / F2 — même TWI, deux fenêtres

**Code.** W3 : `normalize_indicator()`, fenêtre [2,5 ; 4,5]
(`R/normalization.R`, l. 714-716). F2 : [2,5 ; 10] dans
`indicateur_f2_erosion()`.

### Saturation mesurée

En % des pixels des UGF qui valent 0 ou 100, et en % des UGF dont le TWI
moyen sature (donc dont le score vaut 0 ou 100).

| Projet | Grille | W3 pix→0 | W3 pix→100 | **W3 UGF saturées** | F2 pix→0 | F2 pix→100 | F2 UGF sat. | [2,56 ; 8,99] pix→100 | [2,56 ; 8,99] UGF sat. |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Fordead | app (2 m) | 2 | 47 | **90** | 2 | 0,3 | 0 | 1 | 0 |
| Reconfort | app (2 m) | 0 | 89 | **100** | 0 | 1 | 0 | 4 | 0 |
| ForetAccess | app (2 m) | 12 | 34 | **23** | 12 | 1 | 0 | 2 | 0 |
| Dabo | app (2 m) | 6 | 46 | **75** | 6 | 1 | 0 | 2 | 0 |
| Couchey | app (lon/lat) | 100 | 0 | **100** (à 0) | 100 | 0 | 100 | 0 | 100 |
| Aumur | app (lon/lat) | 94 | 0 | **100** (à 0) | 94 | 0 | 100 | 0 | 100 |
| Fordead | IGN 25 m L93 | 0 | 100 | 100 | 0 | 9 | 0 | 18 | 0 |
| Reconfort | IGN 25 m L93 | 0 | 100 | 100 | 0 | 22 | 0 | 36 | 25 |
| ForetAccess | IGN 25 m L93 | 0 | 94 | 100 | 0 | 1 | 0 | 8 | 0 |
| Dabo | IGN 25 m L93 | 0 | 95 | 100 | 0 | 2 | 0 | 6 | 0 |
| Couchey | IGN 25 m L93 | 0 | 99 | 100 | 0 | 11 | 1 | 20 | 7 |
| Aumur | IGN 25 m L93 | 0 | 100 | 100 | 0 | 72 | 67 | 82 | 100 |

**Scores par UGF (moyenne du projet, écart-type entre parenthèses, grille de l'app) :**

| Projet | TWI UGF moyen | W3 actuel | F2 (composante TWI) actuel | fenêtre commune [2,56 ; 8,99] |
|---|---:|---:|---:|---:|
| Fordead | 4,76 | 99,1 (3,6) | 30,1 (3,0) | 34,1 (3,5) |
| Reconfort | 5,88 | 100,0 (0,0) | 45,0 (2,3) | 51,5 (2,7) |
| ForetAccess | 4,31 | 86,0 (12,6) | 24,2 (5,3) | 27,2 (6,2) |
| Dabo | 4,62 | 99,9 (0,2) | 28,2 (1,2) | 32,0 (1,3) |
| Couchey | 0,00 | 0 | 0 | 0 |
| Aumur | 0,43 | 0 | 0 | 0 |

### Lecture

- La fenêtre de W3, [2,5 ; 4,5], est trop étroite. La médiane des pixels
  (3,9 à 5,5 sur LiDAR) est à sa borne haute, ou au-delà. Sur LiDAR, 75 à
  100 % des UGF sont à 100, sauf ForetAccess, la plus sèche (23 %). Sur une
  grille à 25 m, **toutes** les UGF de tous les projets sont à 100. W3 ne
  discrimine donc presque rien, et une UGF de fond de vallon a le même score
  qu'une UGF de versant.
- La fenêtre de F2, [2,5 ; 10], couvre bien la distribution observée à 2 m
  (moins de 1,3 % des pixels saturés en haut). Elle sature en revanche à
  25 m sur le relief plat d'Aumur (67 % des UGF).
- La fenêtre poolée [2,56 ; 8,99] est pratiquement celle de F2. Elle sature
  un peu plus à 25 m (le TWI y est décalé d'environ 2,5, cf. constat 2).

### Recommandation

**Fenêtre commune [2,5 ; 9] pour W3 et F2, sur un TWI ramené à la
résolution de 2 m (`TWI − ln(pas/2)`).** La justification est la
distribution poolée des six projets (q5 = 2,56, q95 = 8,99), qui ne sature
aucune UGF à 2 m. On garde 9 plutôt que 10, puisque q95 vaut 8,99 et que
moins de 4 % des pixels dépassent 9 à 2 m. Prendre 10 (la fenêtre actuelle de
F2) reste défendable et ne change F2 que de 3 à 6 points.

**Conséquences :**

- W3 passe de ≈ 100 à ≈ 27-52 sur les projets LiDAR et retrouve de la
  dispersion (é.-t. de 0-4 à 1,3-6). Il **baisse de 50 à 70 points** : la
  famille W et le score global baissent mécaniquement.
- F2 bouge de 3 à 6 points sur sa composante TWI, soit 1,5 à 3 points sur F2.
- La fenêtre commune est la même que la borne de R3 (section 1), ce qui fait
  un seul paramètre TWI pour quatre consommateurs.
- **Prérequis :** corriger le TWI en lon/lat (constat 1). Tant qu'il ne l'est
  pas, Couchey et Aumur restent à W3 = 0 et à une composante TWI de F2 = 0,
  quelle que soit la fenêtre.

---

## 3. N1 — terme urbain constant +25

**Code.** `R/indicators-naturalness.R`, l. 76-90 :
`0,40·routes + 0,35·bâti + 0,25·100`. Le terme urbain n'est adossé à aucune
couche : c'est une constante. L'option est de le retirer et de repondérer,
soit `N1' = (0,40·routes + 0,35·bâti) / 0,75 = (N1 − 25) / 0,75`.

| Projet | Couches | UGF | N1 actuel moy [min ; max] (é.-t.) | N1 sans constante moy [min ; max] (é.-t.) | Δ N3 moyen |
|---|---|---:|---|---|---:|
| Fordead | routes, **pas de bâti** | 30 | NA (30/30) | NA | — |
| Reconfort | routes + bâti | 24 | 45,0 [30,3 ; 57,4] (8,0) | 26,6 [7,0 ; 43,2] (10,6) | −6,4 |
| ForetAccess | routes + bâti | 30 | 32,8 [27,6 ; 36,9] (2,5) | 10,4 [3,5 ; 15,9] (3,3) | −7,8 |
| Dabo | routes + bâti | 4 | 46,4 [41,3 ; 51,4] (5,2) | 28,5 [21,7 ; 35,2] (6,9) | −6,3 |
| Couchey | routes + bâti | 76 | 42,0 [28,0 ; 53,3] (5,9) | 22,7 [4,0 ; 37,7] (7,9) | −6,8 |
| Aumur | routes + bâti | 15 | 36,8 [29,8 ; 56,1] (7,4) | 15,7 [6,4 ; 41,5] (9,8) | −7,4 |

### Lecture

- La transformation est affine et identique partout. **Le classement (intra
  comme inter-projets) ne change pas**, et la comparabilité non plus : la
  constante était la même pour tous. Le choix porte seulement sur le niveau
  et sur l'étendue de l'échelle.
- Avec la constante, N1 ne descend jamais sous 25 et occupe 28 à 57 sur les
  projets réels. Sans elle, l'échelle s'étire (é.-t. ×1,33) et N1 baisse de
  18 à 22 points. N3 (0,35·N1) perd 6 à 8 points.
- Fordead n'a pas de couche de bâti en cache : N1 y vaut NA, et le resterait
  avec l'une ou l'autre option.

### Recommandation

**Retirer le terme et repondérer à 0,40/0,35 (÷ 0,75).** C'est la politique
appliquée depuis 0.212.0 aux autres indicateurs (pas de valeur inventée
quand aucune donnée n'existe), et 25 points sans mesure derrière gonflent la
naturalité de toutes les UGF. Si une couche « zones urbaines » arrive un
jour, le troisième terme reviendra avec une vraie distance.

**Conséquences :** N1 −18 à −22, N3 −6 à −8, famille N en baisse. Aucun
classement ne change. Les seuils d'interprétation éventuels de N1 (textes,
fiches) doivent être relus.

---

## 4. P3 — scores par défaut de forme (70) et de défauts (85)

**Code.** `R/indicators-productive.R`, l. 650-663. Sans `form_score` ni
`defects`, P3 = 0,4·70 + 0,4·diamètre + 0,2·85, soit **45 points constants**
plus 0,4 × diamètre. Les défauts pèsent 60 % des poids, pas 40 % comme le dit
l'audit. Aucun des six projets n'a de donnée de forme ou de défauts :
c'est donc le cas de **toutes** les UGF.

| Projet | UGF | **Part de P3 venant des défauts** | P3 actuel moy [min ; max] (é.-t.) | Option NA | Option repondérée (diamètre seul) moy [min ; max] (é.-t.) | UGF à diamètre = 0 |
|---|---:|---:|---|---|---|---:|
| Fordead | 30 | **97 %** | 46,8 [45,0 ; 69,4] (5,7) | 30/30 NA | 4,5 [0 ; 61,0] (14,3) | 90 % |
| Reconfort | 24 | 69 % | 67,0 [45,0 ; 77,8] (9,9) | 24/24 NA | 54,9 [0 ; 82,1] (24,9) | 12,5 % |
| ForetAccess | 30 | 62 % | 73,5 [62,8 ; 83,1] (5,7) | 30/30 NA | 71,2 [44,6 ; 95,4] (14,3) | 0 % |
| Dabo | 4 | 58 % | 77,4 [76,5 ; 78,1] (0,7) | 4/4 NA | 81,0 [78,6 ; 82,8] (1,7) | 0 % |
| Couchey | 76 | 72 % | 63,4 [45,0 ; 73,1] (5,1) | 76/76 NA | 45,9 [0 ; 70,2] (12,8) | 4 % |
| Aumur | 15 | 63 % | 72,4 [60,0 ; 80,2] (6,3) | 15/15 NA | 68,5 [37,5 ; 88,0] (15,8) | 0 % |

### Lecture

- Sans données terrain, **58 à 97 % du P3 affiché vient des défauts.** Le
  plancher de 45 est atteint dès que le diamètre est nul : 27 UGF de Fordead
  dans le parquet, peuplements dépérissants ou coupés à H_dom < 6 m.
- **Option NA :** P3 disparaît sur 100 % des UGF des six projets. La famille
  P perd un axe sur tous les projets sans inventaire, c'est-à-dire tous ceux
  de NDP 0-1.
- **Option repondérée :** P3 = score de diamètre. La transformation est
  affine (P3 = 45 + 0,4·d), donc **le classement intra-projet ne change
  pas**. L'étendue est multipliée par 2,5 : l'écart-type passe de 0,7-9,9 à
  1,7-24,9 et le plancher de 45 tombe à 0. L'écart entre projets se creuse
  (Fordead 4,5 contre Dabo 81).
- Le diamètre « mesuré » est lui-même synthétique : CHM → D_g par Charru 2012
  (`ensure_inventory_fields()`). Et à cause du constat 3, les sapins et les
  pins sont jugés sur les seuils feuillus (40/20 cm au lieu de 30/15 cm), ce
  qui sous-estime leur score de diamètre.

### Recommandation

**Repondérer sur les seules composantes mesurées, avec un statut.** Sans
forme ni défauts, P3 = score de diamètre, et une colonne
`p3_status = "diametre_seul"` (sur le modèle de `p2_status`) dit ce qui a été
calculé. On ne garde pas l'option NA, qui effacerait P3 de tous les projets
réels, ni les défauts, qui fabriquent de 58 à 97 % du score. Les données de
forme ou de défauts saisies sur le terrain (QField) réactivent les poids
complets.

**Conséquences :** P3 baisse de 2 à 42 points (Fordead 46,8 → 4,5 ; Dabo
77,4 → 81,0 monte). L'ordre intra-projet est conservé. La famille P perd sa
« bonne note par défaut ». Il faut **corriger d'abord le mappage
d'essence** (constat 3) : sinon le diamètre des résineux, devenu seul
contributeur, reste mal jugé.

---

## 5. Indice de station — hauteurs hors des courbes bornées aux classes 1 et 5

**Code.** `.frac_class()` dans `R/site_index.R` (l. 368-374) : une H_dom
au-dessus de la classe 1 ou sous la classe 5, à l'âge observé, est ramenée à
la classe 1 ou 5. L'option est de rendre NA. P2 (mode CHM) est ensuite
normalisé sur 40 m.

CHM utilisé : le MNH LiDAR (4 projets) ou Open-Canopy 1,6 m (Couchey,
Aumur). H_dom = p90 du CHM.

### Part des UGF hors courbe (calcul tel que l'app le fait aujourd'hui)

| Projet | CHM | UGF | dans les courbes | au-dessus classe 1 | sous classe 5 | non estimable | **hors courbe** |
|---|---|---:|---:|---:|---:|---:|---:|
| Fordead | LiDAR | 30 | 1 | 0 | 24 | 5 | **96 %** |
| Reconfort | LiDAR | 24 | 7 | 10 | 6 | 1 | **70 %** |
| ForetAccess | LiDAR | 30 | 13 | 17 | 0 | 0 | **57 %** |
| Dabo | LiDAR | 4 | 0 | 4 | 0 | 0 | **100 %** |
| Couchey | Open-Canopy | 76 | 55 | 1 | 19 | 1 | **27 %** |
| Aumur | Open-Canopy | 15 | 6 | 8 | 1 | 0 | **60 %** |

Toutes les UGF ont `age = 60` (fixé dans `enrich_parcels_bdforet()`) et la
courbe BROADLEAF_GENUS (constat 3). Toute UGF bornée reçoit donc exactement
**20,71 m** ou **10,90 m**, les classes 1 et 5 du chêne sessile à 50 ans.
C'est ce que montre le parquet : 24/25 valeurs de P2 sont une borne à
Fordead, 16/23 à Reconfort, 20/75 à Couchey et 9/15 à Aumur. On y trouve des
sapins de 28 à 35 m (Dabo, ForetAccess), des chênes ou des « Generic » de 1,4
à 12 m (UGF dépérissantes ou coupées, Fordead et Couchey).

### Effet sur P2 normalisé (/40 m)

| Projet | P2 borné : n, moy (é.-t.) | P2 NA hors courbe : n, moy (é.-t.) |
|---|---|---|
| Fordead | 25, 28,0 (3,7) | **1**, 45,8 |
| Reconfort | 23, 44,0 (10,6) | **7**, 47,3 (4,3) |
| ForetAccess | 30, 47,8 (5,9) | **13**, 42,6 (5,7) |
| Dabo | 4, 51,8 (0,0) | **0** |
| Couchey | 75, 34,9 (7,0) | **55**, 37,2 (6,0) |
| Aumur | 15, 46,5 (8,1) | **6**, 42,7 (6,9) |

### Sensibilité : avec l'essence correctement résolue

Même calcul, en remplaçant le genre par un code des courbes : Abies → ABAL,
Pinus → CONIFER_GENUS, Fagus → FASY, Quercus → QUPE ; l'âge reste à 60.

| Projet | dans | au-dessus cl. 1 | sous cl. 5 | hors courbe | P2 borné moy | P2 NA : n, moy |
|---|---:|---:|---:|---:|---:|---|
| Fordead | 1 | 0 | 24 | 96 % | 32,0 | 1, 47,0 |
| Reconfort | 7 | 10 | 6 | 70 % | 44,0 | 7, 47,3 |
| ForetAccess | 19 | 11 | 0 | **37 %** | 53,7 | 19, 49,0 |
| Dabo | 4 | 0 | 0 | **0 %** | 64,4 | 4, 64,4 |
| Couchey | 56 | 0 | 19 | 25 % | 35,2 | 56, 37,4 |
| Aumur | 6 | 8 | 1 | 60 % | 46,5 | 6, 42,7 |

Une fois l'essence résolue, Dabo rentre entièrement dans les courbes du
sapin. Les « sous classe 5 » restants (Fordead, Couchey) sont des UGF à
H_dom de 1,4 à 12 m : dépérissement, coupe ou jeune peuplement, que l'âge
fixé à 60 ans transforme en « station très pauvre ».

### Lecture

- La borne fabrique des valeurs identiques (10,90 ou 20,71 m) qui ont l'air
  de mesures. À Fordead, la seule UGF « mesurée » est noyée dans 24 UGF
  rangées en « station la plus pauvre » à cause du dépérissement, pas de la
  station.
- Passer à NA fait perdre P2 sur une grande partie des UGF (de 27 à 100 %
  selon le projet). Mais une large part de ces sorties de courbe vient de
  deux défauts amont, l'âge constant et l'essence non résolue, et non de la
  station.

### Recommandation

**Adopter NA hors courbe**, ce qui est la politique du projet, et le faire
**dans la même release que la correction du mappage d'essence** (constat 3).
Il faut aussi un statut `p2_status = "hors_courbe"` pour que l'app explique
le NA. L'âge constant de 60 ans est le défaut de fond. Tant qu'il n'y a pas
d'âge réel (BD Forêt TFV, inventaire, T1), l'indice de station se résume à un
classement de H_dom. Cela mérite un chantier à part, et sans doute une
mention « âge supposé » dans `p2_status`.

**Conséquences :** sans la correction d'essence, P2 deviendrait NA sur 27 à
100 % des UGF (Dabo entier). Avec elle, la perte tombe à 0 % (Dabo), 25-37 %
(Couchey, ForetAccess) et 60-96 % sur les projets dépérissants (Fordead,
Reconfort, Aumur). Là, le NA est le message juste : la station n'y est pas
lisible depuis un CHM. Les moyennes de P2 bougent de −5 à +18 points sur les
UGF restantes. Comparabilité entre projets : la borne alignait des UGF très
différentes sur deux valeurs ; NA ne compare plus que des indices réellement
estimés.

---

## Synthèse

| Choix | Recommandation | Effet mesuré |
|---|---|---|
| **1. R2 / R3, normalisation TRI / TWI** | R2 : retirer le TRI (redondant avec la pente, r = 0,82 à 0,99), ou le normaliser en TRI/pas sur [0,016 ; 0,49]. R3 : borne fixe TWI [2,5 ; 9], ancrée à 2 m (`TWI − ln(pas/2)`). | Classement intra-projet inchangé (Spearman ≥ 0,97). R2 de −2 à +9 pts, R3 ±4 pts. Un même relief donne enfin le même score d'un projet à l'autre : un TRI de 1 m valait de 3 à 85. Prérequis : TWI lon/lat corrigé. |
| **2. W3 / F2, fenêtres TWI** | Fenêtre commune [2,5 ; 9] (q5-q95 poolés = 2,56-8,99) pour W3, F2 et R3, sur un TWI ramené à 2 m. | W3 sature aujourd'hui sur 75 à 100 % des UGF LiDAR et 100 % à 25 m. Avec la fenêtre commune : 0 % d'UGF saturées à 2 m, W3 de ≈ 100 à 27-52 (−50 à −70 pts), F2 de −1,5 à −3 pts. |
| **3. N1, terme +25** | Le retirer, (N1 − 25) / 0,75. | N1 −18 à −22 pts, N3 −6 à −8, échelle étirée ×1,33. Aucun classement modifié (transformation affine identique partout). |
| **4. P3, défauts 70 / 85** | Repondérer sur le diamètre seul, avec `p3_status = "diametre_seul"`. Option NA écartée : elle efface P3 sur 100 % des UGF. | Les défauts font 58 à 97 % du P3 actuel. P3 de −42 à +4 pts (Fordead 47 → 4,5), étendue ×2,5, ordre conservé. |
| **5. Indice de station hors courbe** | NA, avec `p2_status = "hors_courbe"`, livré avec la correction du mappage d'essence (genres latins → codes). | Hors courbe aujourd'hui : 27 à 100 % des UGF, toutes ramenées à 10,90 ou 20,71 m. Après correction d'essence : 0 % (Dabo) à 96 % (Fordead dépérissant). |

**À traiter avant ou avec ces choix (constats faits en mesurant, ce ne sont
pas des décisions) :**

1. TWI calculé en degrés sur un MNT lon/lat : W3 = 0 et composante TWI de
   F2 = 0 à Couchey et Aumur.
2. TWI dépendant de la résolution (≈ ln(pas/2), mesuré −1,7 à −2,9 entre
   2 m et 25 m).
3. `enrich_parcels_bdforet()` : `age = 60` constant, et des genres latins
   non reconnus par `resolve_species_code()` et `is_conifer()`. Toutes les
   UGF tombent sur la courbe et les seuils du chêne.
