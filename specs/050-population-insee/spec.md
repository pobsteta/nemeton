# Spec 050 — S3 population : brancher le carroyage INSEE Filosofi

> **Cadré le 2026-08-26**, à la demande de Pascal (« cadre S3 pour qu'il
> fonctionne enfin »). Paperwork avant code.
> **Déclencheur** : depuis la **v0.187.0**, `indicateur_s3_population()` rend
> `NA` partout — il ne fabrique plus `surface_du_tampon × 100 hab/km²`, et
> aucune source ne l'alimente. L'axe Social & Usages est donc amputé jusqu'à ce
> que cette spec soit implémentée.
> **Rien n'est à inventer côté calcul** : la fonction sait déjà lire une grille
> (`sf` pondéré par la part de carreau, ou `SpatRaster` via `exactextractr`).
> Il manque **l'acquisition**.

---

## 1. La source, vérifiée sur le fichier réel

INSEE — **Filosofi 2021, données carroyées**, publié le 16 février 2026.
Le fichier a été téléchargé et ouvert le 2026-08-26 ; ce qui suit est constaté,
pas déduit de la documentation.

| | Maille 1 km | Maille 200 m |
|---|---|---|
| GeoPackage (zip) | **51,8 Mo** | 294 Mo |
| URL | `insee.fr/fr/statistiques/fichier/8735171/Filosofi2021_carreaux_1km_gpkg.zip` | `.../8735162/Filosofi2021_carreaux_200m_gpkg.zip` |
| Couches | `carreaux_1km_met`, `carreaux_1km_mart` (+ Réunion) | idem en 200 m |
| Entités (métropole) | **374 511** | ~2,4 M |
| Variables | 31 | 34 |

**Licence Ouverte / Open Licence 2.0** (data.gouv.fr), producteur INSEE.
Compatible avec l'usage du projet, attribution requise.

**Population totale portée par la maille 1 km métropole : 62,6 M habitants** —
l'ordre de grandeur attendu, donc le fichier est cohérent.

### Correction à une affirmation antérieure

J'ai écrit deux fois que le carroyage était en **EPSG:3035**, « le CRS de
l'ADR-008 ». **C'est faux, et la vérification le montre** : la géométrie du
GeoPackage est en **EPSG:2154 (RGF93 / Lambert-93)**. Ce qui porte la référence
INSPIRE, c'est l'**identifiant** du carreau —
`idcar_1km = "CRS3035RES1000mN2029000E4252000"` — une chaîne, pas une
projection. L'intégration demande donc une reprojection ordinaire, comme toute
autre couche IGN. Rien de bloquant, mais l'argument « s'intègre sans conversion
de référentiel » tombe.

## 2. La variable, et la question qu'elle pose

* **`ind`** — nombre d'individus par carreau. C'est la variable de S3.
* **`i_est_1km`** — indicateur d'**imputation**, à 1 quand le carreau porte
  moins de 11 ménages fiscaux (seuil de confidentialité). La valeur y est alors
  **modélisée**, pas observée.

**C'est la seule vraie décision de cette spec**, et elle touche directement la
règle posée en v0.186.0/v0.187.0 : *une valeur modélisée n'est pas une mesure.*

### Ce que la mesure dit

France entière, maille 1 km :

| | Carreaux | Population portée |
|---|---|---|
| Imputés | 238 314 (**63,6 %**) | 5,68 M (**9,1 %**) |

Autour du massif de **Couchey** (UGF réelles, tampons de la fonction) :

| Tampon | Carreaux | Population | Carreaux imputés | Population imputée |
|---|---|---|---|---|
| 5 km | 86 | **46 110** | 41,9 % | 4,6 % |
| 10 km | 270 | 208 974 | 44,8 % | 3,1 % |
| 20 km | 786 | 304 532 | 53,1 % | **6,2 %** |

**J'attendais l'inverse et je me suis trompé.** L'hypothèse était que
l'imputation, concentrée sur les carreaux peu peuplés, pèserait beaucoup plus
en contexte forestier qu'à l'échelle nationale. Mesuré : elle y pèse **3 à
6 %**, soit moins qu'au niveau national. La raison est visible sur la carte —
Couchey est à portée de Dijon, et les tampons de 10-20 km capturent de
l'urbain. **Un massif réellement isolé donnerait un autre résultat** ; c'est à
re-mesurer avant de généraliser.

### Décision proposée

**Compter les carreaux imputés, et le dire.** Les exclure retirerait 3 à 6 % de
la population autour de Couchey et bien davantage en montagne, pour un gain de
pureté théorique : l'INSEE impute précisément pour que le total reste juste.
Mais S3 doit **porter la trace** de ce qu'il agrège — une colonne
`S3_part_imputee` (0-1) par UGF, du même esprit que les colonnes de statut
`a5_status` / `r5_status` que l'app sait déjà lire.

À arbitrer par Pascal ; l'alternative (exclure, et documenter le biais) reste
défendable.

## 3. Ce qu'il faut écrire

### 3.1 Acquisition — `load_insee_population_source()`

Sur le modèle de `load_onf_parcelles_source()` (`R/load_onf_parcelles.R`) :

```r
load_insee_population_source(aoi, maille = c("1km", "200m"),
                             millesime = 2021, crs = 2154,
                             cache_dir = NULL, territoire = "FR")
```

* rend un `sf` de carreaux **découpé sur l'emprise + le plus grand tampon**,
  avec au minimum `ind` et `i_est_1km` ;
* **filtre spatial à la lecture** (`sf::st_read(wkt_filter = )`) : mesuré,
  1 024 carreaux lus au lieu de 374 511 pour l'emprise de Couchey + 21 km. Ne
  jamais charger la France entière en mémoire ;
* `NULL` + avertissement si la source est indisponible — jamais de repli
  fabriqué, c'est tout l'objet de la v0.187.0.

### 3.2 Cache — le point qui décide de l'ergonomie

Le fichier fait 52 Mo zippé, 168 Mo décompressé, et **ne change qu'une fois par
an**. Il ne doit être téléchargé qu'une fois par machine, pas par projet :
cache partagé (`scratch_dir()` ou `~/.cache/nemeton/insee/`), avec le millésime
dans le nom. Un projet qui recalcule ne doit rien re-télécharger.

### 3.3 Déclaration de source

Dans `inst/datasources/FR.json`, une entrée `population_insee` sous `layers`,
avec un service `insee_files` (téléchargement direct, pas un WFS) — le premier
de ce type, à ajouter à `services`.

### 3.4 Câblage

`indicateur_s3_population(units, population_grid = ...)` **est déjà prêt**.
Reste à ce que l'orchestrateur d'indicateurs résolve la couche comme il résout
`bdforet` ou `roads`, et à relever le NDP correspondant si la source y entre.

## 4. Ce que ça change pour l'utilisateur

Sur Couchey, S3 passerait de **`NA`** (aujourd'hui) à **46 110 habitants dans
5 km** — et non aux ~8 300 que l'ancien chemin fabriqué annonçait, qui n'étaient
qu'une surface de tampon déguisée. L'écart d'un facteur 5,5 mesure exactement ce
que valait le placeholder.

## 5. Vérification proposée

| Contrôle | Attendu |
|---|---|
| Source absente / réseau coupé | `NULL`, S3 reste `NA`, aucun repli fabriqué |
| Lecture sur l'emprise de Couchey | ~1 024 carreaux lus, pas 374 511 |
| S3 à 5 km sur Couchey | ~46 000 habitants, ordre de grandeur vérifiable sur une carte INSEE |
| Carreau à cheval sur le tampon | compté au prorata, jamais en entier (déjà testé) |
| Second calcul du même projet | aucun re-téléchargement |
| Millésime | inscrit dans le résultat ou les métadonnées : une population sans année n'est pas une donnée |

## 6. Hors périmètre

* Les **30 autres variables** de Filosofi (revenus, âges, logement) : elles
  ouvriraient d'autres indicateurs sociaux, mais aucun n'est demandé.
* Le **200 m** : plus fin, six fois plus lourd, et sans intérêt pour des
  tampons de 5 à 20 km. À garder en option, pas en défaut.
* L'**outre-mer** au-delà de Martinique et Réunion : non couvert par la source.
