# F1 Fertilité — trois sources, trois compromis

## Pourquoi trois sources ?

L’indicateur F1 « fertilité du sol » est l’un des plus délicats à
calculer : la *fertilité forestière* n’est pas un paramètre mesurable
directement — c’est une synthèse multi-critères (texture, profondeur,
pH, drainage, nutriments, productivité observée). Selon les données
disponibles sur l’AOI, `nemeton` propose **trois chemins de calcul** qui
reflètent trois compromis entre disponibilité, granularité sémantique et
rigueur pédologique.

``` r

library(nemeton)
```

| `source` | Données d’entrée | Couverture | Sémantique | Score |
|----|----|----|----|----|
| `"layer"` | Couche utilisateur (raster ou polygone) | Selon les données | Dépend de la couche fournie | Relatif (min-max par appel) |
| `"soilgrids"` | SoilGrids 2.0 CEC (0-5 cm, 250 m) | **Mondiale** | CEC continue | **Absolu** (0-100) |
| `"gissol"` | RRP France + table UTS → fertilité AFES 2008 | France métropolitaine | Typologie pédologique multi-critères | **Absolu** (0-100) |

## Source 1 — `"layer"` (échappatoire générique)

La voie historique : on fournit une couche quelconque portant un champ «
fertilité », et F1 la normalise linéairement sur 0-100 par appel. Utile
quand on a des données locales (BD Sol départementale, carte de stations
régionale) non déclarées dans `inst/datasources/`.

``` r

# Exemple : un raster local dont chaque pixel porte un score 1-5
layers <- nemeton_layers(
  rasters = list(soil = "/chemin/vers/stations.tif")
)
f1 <- indicateur_f1_fertilite(
  units         = massif_demo_units,
  layers        = layers,
  soil_layer    = "soil",
  fertility_col = "fertility"     # nom du champ fertilité dans la couche
)
```

**Limite** : le score est *relatif* à l’AOI traitée. Deux projets qui
utilisent le même raster source obtiendront des scores différents si les
distributions de leurs AOI diffèrent. Les chiffres ne sont pas
comparables entre projets.

## Source 2 — `"soilgrids"` (global, absolu, CEC)

Cette voie streame le raster SoilGrids 2.0 *Cation Exchange Capacity*
(topsoil 0-5 cm, mean, 250 m, licence CC-BY 4.0) directement depuis
ISRIC via un COG `/vsicurl/`, sans téléchargement complet. La CEC
observée est ensuite convertie en score 0-100 via
[`cec_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/cec_to_fertility_score.md)
(seuils Baize & Jabiol 1995, linéaire sur \[0, 30\] cmol(c)/kg).

``` r

# Aucune couche à préparer — load_raster_source() fait tout en interne.
# Non exécuté dans cette vignette : dépend d'un accès réseau à ISRIC.
f1 <- indicateur_f1_fertilite(
  units  = massif_demo_units,
  source = "soilgrids"
)
```

**Avantages**

- Aucune donnée locale à fournir, l’AOI peut être **n’importe où sur la
  planète** (SoilGrids est global).
- Scores **absolus** : deux projets sur deux forêts différentes
  obtiennent des valeurs comparables.
- Reproductible et versionable (CEC SoilGrids 2.0 est figée).

**Limites** (cf. section *Calibration RMQS* plus bas)

- La CEC seule est un proxy grossier de la fertilité forestière. Les
  sols **alluviaux / colluviaux** (FLUVIOSOL, COLLUVIOSOL) sont
  systématiquement sous-rated car leur fertilité vient de la
  profondeur/drainage, pas du nombre de cations échangeables.
- Les **organosols** (tourbes) sont sur-rated car la tourbe a une CEC
  élevée mais est improductive en sylviculture.
- Résolution 250 m : peut lisser des transitions pédologiques fines.

## Source 3 — `"gissol"` (France, typologie AFES, multi-critères)

Cette voie consomme une couche vectorielle RRP (Référentiel Régional
Pédologique) que l’utilisateur fournit — polygones portant un code AFES
2008 (champ `rpf_code`, `UTSDom`, `rp_2008_nom`, etc. selon le
fournisseur). Chaque polygone est intersecté avec les unités, puis son
code AFES est joint à la **table experte**
`inst/extdata/uts_fertilite_fr.csv` (54 UTS, sources Baize & Jabiol
1995, AFES 2008, Duchaufour 2001, Jabiol et al. 2009) pour récupérer un
score 0-100 calibré sur la grille 1-5 (15/35/55/75/90). Le score par
unité est la **moyenne pondérée par surface**.

``` r

# L'utilisateur a téléchargé le RRP de son département au format GPKG
rrp <- sf::st_read("/chemin/vers/rrp_loiret.gpkg")

layers <- nemeton_layers(vectors = list(soil = rrp))

f1 <- indicateur_f1_fertilite(
  units         = massif_demo_units,
  layers        = layers,
  source        = "gissol",
  rpf_code_col  = "UTSDom"        # adapte au nom de colonne du RRP
)
```

**La table expert est exposée** pour audit ou jointure manuelle :

``` r

tbl <- read_uts_fertility_table()
head(tbl[, c("rpf_code", "rpf_name", "fertility_class",
             "fertility_score", "forest_note")], 5)
#>   rpf_code              rpf_name fertility_class fertility_score
#> 1 BRUN_EUT     BRUNISOL EUTRIQUE               4              75
#> 2 BRUN_MES   BRUNISOL MESOTRIQUE               4              75
#> 3 BRUN_DYS    BRUNISOL DYSTRIQUE               2              35
#> 4 BRUN_OLI BRUNISOL OLIGO-SATURE               2              35
#> 5 BRUN_HUM      BRUNISOL HUMIQUE               3              55
#>                                                 forest_note
#> 1  bon pour feuillus nobles (hêtre, chêne sessile), douglas
#> 2   polyvalent feuillus-résineux, base forestière française
#> 3 dominante conifères (épicéa, sapin), feuillus acidiphiles
#> 4  station pauvre, productivité médiocre sauf pin sylvestre
#> 5 d'altitude, hêtre-sapin-épicéa, bonne station de montagne
```

**Avantages**

- Score absolu et **multi-critères** : intègre texture, drainage,
  profondeur, pH, acidité, notes forestières.
- Explicable à un technicien forestier : chaque unité est une UTS
  nommée, pas une valeur ML.
- S’aligne sur l’usage pédologique français (nomenclature AFES).

**Limites**

- **France métropolitaine uniquement**. Hors France, revenir à
  `"soilgrids"`.
- Nécessite une donnée RRP vectorielle à la main. Les RRP sont
  redistribués région par région (pas de source nationale téléchargeable
  unique en 2026).
- La table V1 est une **ébauche à relire** par un pédologue (cf. en-tête
  `inst/extdata/uts_fertilite_fr.csv`).

## Calibration RMQS — quand faire confiance à quoi

En Phase D de la spécification, la table experte a été confrontée aux
mesures RMQS (Réseau de Mesures de la Qualité des Sols) 1ère campagne
2000-2009 (2 037 sites, DOI
[10.15454/QSXKGA](https://doi.org/10.15454/QSXKGA), licence Etalab 2.0).
Le résultat est publié dans
`inst/extdata/uts_fertilite_rmqs_calibration.csv`.

``` r

cal_path <- system.file("extdata", "uts_fertilite_rmqs_calibration.csv",
                         package = "nemeton")
cal <- utils::read.csv(cal_path, stringsAsFactors = FALSE)

# UTS où l'écart expert vs CEC observée dépasse 20 points
outliers <- cal[cal$flag_outlier, c("rpf_code", "n_sites",
                                      "cec_median", "observed_score",
                                      "expert_score", "delta")]
outliers[order(outliers$delta), ]
#>    rpf_code n_sites cec_median observed_score expert_score delta
#> 22  COL_TYP      63      10.60           35.3           90 -54.7
#> 30  LUV_TYP     159       7.43           24.8           75 -50.2
#> 11 BRUN_MES     378       7.86           26.2           75 -48.8
#> 8  BRUN_EUT       9       8.89           29.6           75 -45.4
#> 25  FLU_TYP      54      13.79           46.0           90 -44.0
#> 29  LUV_HYD     192       6.17           20.6           55 -34.4
#> 23  FLU_CAL      15      17.26           57.5           90 -32.5
#> 9  BRUN_HUM       6       7.26           24.2           55 -30.8
#> 27  LUV_DEG      22       7.42           24.7           55 -30.3
#> 37  POD_MEU      24       1.79            6.0           35 -29.0
#> 38  POD_OCR      16       2.72            9.1           35 -25.9
#> 44  RDX_TYP      41       9.14           30.5           55 -24.5
#> 19  CAS_ROU       2      15.49           51.6           75 -23.4
#> 28  LUV_DYS       2       3.68           12.3           35 -22.7
#> 21  COL_CAL      26      20.62           68.7           90 -21.3
#> 13  CAL_CAI     179      24.60           82.0           55  27.0
#> 32  PEY_CAL       3      25.20           84.0           55  29.0
#> 42  RDS_TYP      35      19.30           64.3           35  29.3
#> 31  ORG_INS       4      23.99           80.0           15  65.0
#> 26  LIT_TYP       8      31.95          100.0           15  85.0
```

Les deltas ne sont **pas** une invalidation des scores experts. Ils
mesurent **combien d’information la table expert apporte au-delà de la
CEC brute**. Quelques lectures utiles :

- **Fluviosols / colluviosols sous-rated en CEC** (FLU_TYP, COL_TYP,
  COL_CAL : delta -40 à -55). Leur fertilité forestière vient de la
  profondeur et du drainage. La voie `"soilgrids"` les **sous-rate
  systématiquement**.
- **Organosols sur-rated en CEC** (ORG_INS : +65). La tourbe a une haute
  CEC mais est improductive (acidité, engorgement). La voie
  `"soilgrids"` les **sur-rate**.
- **Bruns « plain » biaisés** (BRUN_MES : 378 sites, delta -49). La
  plupart des étiquettes RMQS « BRUNISOL » sans qualifieur tombent dans
  BRUN_MES par défaut, mais leur profil CEC correspond plutôt à
  BRUN_DYS. Artefact de granularité du mapping, pas une erreur de score.

## Arbre de décision

    AOI hors France ?
      OUI → source = "soilgrids"
      NON → As-tu un RRP départemental/régional ?
              OUI → source = "gissol" (optimal, multi-critères)
              NON → As-tu des données pédologiques locales (BD Sol, etc.) ?
                      OUI → source = "layer"   (échappatoire)
                      NON → source = "soilgrids" (global, mais cf. limites)

## Reproduire la calibration

Le pipeline complet est shipé dans `inst/scripts/calibrate_uts_rmqs.R`.
Il est idempotent et met en cache les 4 fichiers RMQS (≈ 2.5 Mo) dans
`tools::R_user_dir("nemeton", "cache")`.

``` sh
# Depuis la racine du projet
Rscript inst/scripts/calibrate_uts_rmqs.R
```

Le script écrit `inst/extdata/uts_fertilite_rmqs_calibration.csv`. Il
signale à la console les UTS non appariées (classes absentes de la V1
experte : PLANOSOL, PELOSOL, MAGNESISOL, FERSIALSOL, DOLOMITOSOL,
ALUANDOSOL, ANDOSOL) — candidates pour une extension V2.

## Pour aller plus loin

- [`?indicateur_f1_fertilite`](https://pobsteta.github.io/nemeton/reference/indicateur_f1_fertilite.md)
  — référence complète du paramètre `source`.
- [`?cec_to_fertility_score`](https://pobsteta.github.io/nemeton/reference/cec_to_fertility_score.md)
  — seuils pédologiques de la conversion CEC → 0-100.
- [`?read_uts_fertility_table`](https://pobsteta.github.io/nemeton/reference/read_uts_fertility_table.md)
  — accès direct à la table experte (utile pour un audit ligne par ligne
  ou une jointure ad-hoc).
- [`?load_raster_source`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)
  — loader générique utilisé par `source = "soilgrids"` (et réutilisable
  pour toute datasource raster déclarée dans `inst/datasources/`).
