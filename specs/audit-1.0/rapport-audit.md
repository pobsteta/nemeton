# Audit `nemeton` avant la 1.0.0

*2026-10-02, sur `main` à 0.207.1.9000.* Huit revues parallèles en lecture seule,
puis vérification à la main des constats critiques (marqués **[vérifié]**).
Gravité : **C** critique · **M** majeur · **m** mineur. Catégorie : bug, sécu, qualité.

État mesuré :
- `devtools::test()` : 0 échec, 11 220 expectations, 79 skips, 29 warnings, 20 min 39 s ;
- `R CMD check --as-cran` (sans tests ni vignettes) : 0 ERROR, **8 WARNING**, 6 NOTE ;
- 313 exports, 393 `.Rd`, 192 fichiers de test, 9 exports sans test ;
- 41 indicateurs déclarés (README et CLAUDE.md en annoncent 31).

---

## 1. Architecture

```
                    ┌──────────────── nemetonshiny (app, repo séparé) ───────────────┐
                    │  appelle ~313 fonctions exportées ; aucune logique métier       │
                    └───────────────────────────────┬────────────────────────────────┘
                                                    │
┌──────────────────────────────── nemeton (ce dépôt) ┴──────────────────────────────────┐
│                                                                                        │
│  ACQUISITION                 ANALYSE SYSTÉMIQUE                AIDE À LA DÉCISION      │
│  datasources.R + FR.json     indicators-*.R (41 indicateurs)   rag.R / knowledge-corpus│
│  load_*.R, theia_stac.R      indicator-config.R (table unique) regen_*.R, indice_*     │
│  sentinel2*.R, ifn_source.R  normalization.R (sens, bornes)    ifn_production*.R (FH)  │
│  lidar_processing.R          family-system.R (12 familles)     volume_mobilisable.R    │
│  utils-chm.R, houppiers*.R   ndp.R (NDP, Fibonacci, φ)         analysis-*.R            │
│                              visualization.R, temporal.R                               │
│                                                                                        │
│  SANTÉ (suivi sanitaire)                    INTEROPÉRABILITÉ / TERRAIN                 │
│  FAST : fast_alert_*.R, pixel-map.R          qgis_export/import.R, field_schema.R       │
│  FORDEAD : fordead_*.R (Python via reticulate)  sampling_plan.R, validation_sampling.R  │
│  RECONFORT : reconfort_*.R (IOTA²/OTB, conda)   health_validation.R (retour QField)     │
│  → table `alert` (db.R, migrations PG/SQLite)                                          │
│                                                                                        │
│  INFRA : db.R + inst/db/migrations, isolate.R (cgroup systemd), memory-ceiling.R,      │
│          cancel.R, project_lock.R, reticulate_isolated.R, zzz.R (.onLoad terra)        │
└────────────────────────────────────────────────────────────────────────────────────────┘
       │ Python embarqué : inst/python/reconfort (IOTA² vendorisé + patchs #1-#12)
       │ Envs externes : conda `nemeton-reconfort`, venv `nemeton-fordead`
       ▼ Stockage : rasters et LiDAR sur disque (caches projet), alertes en PostgreSQL ou SQLite
```

**Ce qui tient bien** : la table d'indicateurs unique (`indicator_families()`),
le système NDP (constantes exactes), la normalisation tracée indicateur par
indicateur, le Fay-Herriot maison, le SQL paramétré partout (aucune injection
trouvée), l'hygiène des secrets dans git, et l'isolation mémoire par cgroup.

**Ce qui fragilise** :
- des contrats implicites entre producteur et consommateur (unités, échelles,
  noms de colonnes) que les tests ne vérifient pas, car ils injectent des
  valeurs synthétiques ;
- des scores normalisés relativement au lot traité, donc non comparables entre
  projets ;
- des valeurs inventées (50, 0, une série simulée) là où la politique du projet
  est « NA plutôt qu'une valeur inventée » ;
- une documentation éditée à la main, qui a dérivé du code (8 WARNING au check).

---

## 2. Bloquants pour la 1.0 (à corriger avant de tagger)

| # | Fichier | Problème |
|---|---|---|
| 1 | `R/indicators-biodiversity.R:413-481` | **C** B2 dépend du numéro de ligne (`i %% 4`) ; le Shannon est mort ; le score est calculé sur tout le lot **[vérifié]** |
| 2 | `R/indicators-risk.R:718-738` | **C** R3 calcule sa composante climat sur une série **simulée** et fait `set.seed(42)`, qui écrase le RNG de l'utilisateur **[vérifié]** |
| 3 | `R/indice_priorite_regen.R:208-211` × `R/regen_engines.R:827` | **C** L'exposition lit un score centré-réduit (environ -4 à +4) comme une valeur 0-100, donc le volet est quasi nul et `parcelle_sensible` est toujours FALSE **[vérifié]** |
| 4 | `R/volume_mobilisable.R:239` | **C** `P1 × taux (m³/ha/an) × horizon` est dimensionnellement faux, d'où ×28 sur le stock ; les tests ont taux = 1 **[vérifié]** |
| 5 | `R/data-hunting.R:255-278` | **C** Les départements 01-09 sont lus `3` ou `"03"` selon le fichier : lignes en double, R4 faux sur 9 départements |
| 6 | `R/fordead_postprocess.R:380-383` | **C** Un re-run FORDEAD supprime les alertes **déjà validées sur le terrain** **[vérifié]** |
| 7 | `%||%` dans 29 fichiers | **C** Ni défini ni importé : le paquet casse sous R 4.1-4.3 alors que DESCRIPTION dit `R (>= 4.1.0)` **[vérifié]** |
| 8 | `data/` + `.Rbuildignore` | **C** `i2_training_data.tar.bz2` (5,4 Go) serait embarqué par un `R CMD build` local **[vérifié]** |
| 9 | `R/indicators-core.R:153` | **M** `nemeton_compute()` passe les `units` d'origine : N3 et E2 valent toujours NA, T2 vaut 50, A1 échoue ; B1, B3, A1 n'acceptent pas `layers` |
| 10 | `R/family-system.R:253-264` + `normalization.R:84` | **M** Le chemin documenté « normaliser puis agréger » ré-inverse R1-R5/T3/L1 ; `by_family = TRUE` normalise deux fois (exemple du package) |
| 11 | `R/fast_alert_raster.R:1389` | **M** La tuile MGRS est lue sur l'orbite pour les identifiants CDSE : piles mélangées, double comptage **[vérifié]** |
| 12 | `inst/db/migrations/*/0007` | **M** `DROP TABLE IF EXISTS alert` sans garde : une base ancienne restaurée perd ses alertes |
| 13 | 3 blocs roxygen détachés (`normalization.R:541`, `indicators-risk.R:509`, `fordead_validity.R:119`) | **M** Le premier `devtools::document()` supprimera trois exports |
| 14 | `man/*.Rd` | **M** 8 WARNING R CMD check (signatures fausses, arguments non documentés, non-ASCII, dépendances `methods`/`prosail` non déclarées) |
| 15 | `.github/workflows/release.yml` | **M** La release se déclenche même si le check échoue ; `r.yml` n'échoue que sur ERROR |

---

## 3. Constats fichier par fichier

### Socle : configuration, normalisation, familles, NDP

**Transverse**
- **C bug** — `%||%` est utilisé dans 29 fichiers (`ndp.R:274`, `visualization.R:175`, `indicators-naturalness.R:374`…), sans définition ni `importFrom(rlang, "%||%")`. Sous R < 4.4 : « could not find function ». → importer depuis rlang.

**R/normalization.R**
- **M bug** `390-405` — Moyenne géométrique avec `na.rm` : les poids ne sont pas réalignés, d'où 57,6 au lieu de 60,3 et un warning de recyclage.
- **M bug** `19-21, 84-87` — `by_family` est documenté mais pas implémenté, et normalise sur place → double normalisation.
- **M qualité** `541-564` — Le roxygen de `normalize_indicator()` est rattaché à `.NORMALIZE_RULED` (perte de l'export au prochain `document()`).
- **m bug** `208-214` — Un seul NA avec `na.rm = FALSE` → tout le vecteur vaut 50.
- **m bug** `98-99` — L'auto-détection `^[A-Z][0-9]` capte `C1_norm`, ce qui crée `C1_norm_norm`.
- **m qualité** `113-116` — Code mort après `msg_error()`.
- **m qualité** `605` — `normalize_indicator()` ne valide pas `indicator`.

**R/family-system.R**
- **M bug** `253-257` — Les colonnes `*_norm` sont seulement écrêtées, sans l'inversion de sens : R1-R5, T3 et L1 sont de nouveau inversés.
- **m bug** `282-296` — Les poids nommés `C1` ne correspondent plus après substitution par `C1_norm`, et sont ignorés en geometric/harmonic/min.
- **m qualité** `405` — `detect_indicator_family()` est défini deux fois (avec `utils.R:646`) et code mort ; `get_family_name()` diverge de `INDICATOR_FAMILIES`.

**R/ndp.R**
- **M qualité** `575-578, 633-637` — `compute_general_index()` est documentée « Fibonacci-weighted » mais calcule `mean()`. CLAUDE.md dit la même chose à tort.
- **m bug** `274-297` — L'attribut `field_plots_count = NA` fait planter `detect_ndp()`.
- **m qualité** `673-702` — `compute_general_index_mixed()` renvoie silencieusement NA sur des noms absents.

**R/indicator-config.R**
- **M qualité** `564-575, 813-845` — La doc « Column pairing » inverse encore F1 et F2 (faux depuis 0.182.0), et le `.Rd` aussi.

**R/visualization.R**
- **M bug** `632, 749-762, 882-897` — `nemeton_radar()` refait un min-max entre unités en mode famille : une seule unité donne 50 partout, et 90/50/10 devient 100/50/0.
- **m bug** `514-523` — `plot_difference_map()` soustrait par position, sans jointure.
- **m qualité** `163, 197, 435, 530` — `geom_sf(size =)` est déprécié (ggplot2 3.4).
- **m qualité** `141` — La palette YlOrRd sur `famille_risque` suggère l'inverse du sens (haut = faible risque).

**R/temporal.R**
- **M bug** `240-266` — `calculate_change_rate()` soustrait par position ; l'alignement par identifiant est calculé mais pas utilisé.
- **m bug** `103, 182-199` — Des `periods` non nommés écrasent les colonnes.
- **m qualité** `47` — Défaut `id_column = "parcel_id"` alors que les unités portent `nemeton_id`.

**R/analysis-clustering.R**
- **M bug** `155` — `scale()` sur une famille constante produit NaN et fait planter `kmeans`.
- **m bug** `165-169` — Avec n = 2, `2:1` itère à rebours ; aucune graine n'est fixée.

**R/analysis-tradeoff.R**
- **M bug** `228-232` — `size = aes(...)` est passé en paramètre, pas en mapping : le rendu plante.

**R/analysis-correlation.R**
- **m bug** `336-337` — `get_famille_code()` renvoie NA, donc `%||%` ne retombe jamais et la heatmap affiche « NA ».
- **m qualité** `343, 354` — `tools::` n'est pas déclaré ; `viridisLite` est appelé sans `requireNamespace`.

**R/utils.R**
- **M bug** `1271` — `class_map[[mode_class]]` lève « subscript out of bounds » au lieu de renvoyer NA.
- **m qualité** `107` — `parallel` n'est pas déclaré ; `detectCores()` peut valoir NA.
- **m sécu** `1304-1315` — `get_global_cache_dir()` crée un dossier utilisateur dès l'appel → `tools::R_user_dir()`.

**R/zzz.R**
- **M qualité** `50-74` — `.onLoad` modifie les options globales de terra (`memfrac`, `memmax`) au chargement.

**R/nemeton-package.R, DESCRIPTION**
- **m qualité** — Page du package obsolète (« B/R planned for v0.3.0 », F1 et F2 inversés, branche `001-mvp`), DESCRIPTION mentionne encore « Includes nemetonApp », `TSP` et `lidR` sont en double dans Suggests, `stats`/`utils`/`graphics`/`tools`/`parallel`/`methods` ne sont pas déclarés.

**R/i18n.R**
- **m qualité** — Clés `indicateur_a5_rafraichissement` et `indicateur_r4_abroutissement` manquantes ; `demo_files_missing` a 2 `%s` en anglais et 3 en français.

### Indicateurs

**R/indicators-core.R**
- **M bug** `153` — `compute_indicator(ind, units, layers)` reçoit les unités d'origine et range les résultats sous des noms longs. N3 et E2 valent toujours NA, T2 vaut 50, A1 échoue ; B1, B3, S3 et P1-P3 n'acceptent pas `layers`.
- **m qualité** `160-164` — L'erreur d'un indicateur n'affiche pas `e$message` ; `list_indicators()` omet 8 indicateurs.

**R/indicators-biodiversity.R**
- **C bug** `413-481` — B2 : `(i %% 4)` dépend du numéro de ligne, le Shannon vaut toujours 0, le score est calculé sur le lot **[vérifié]**.
- **M bug** `744-753` — `costDist(target = SpatRaster)` lève une erreur, donc la composante coût de B3 vaut toujours 50.
- **M bug** `852-855` — `.b3_local` exclut la distance 0 : une parcelle en forêt prend la distance au polygone suivant.
- **M bug** `609-681, 737-740` — Les composantes de B3 valent 50 en cas d'erreur, et en EPSG:4326 la grille fait 25 degrés.
- **M bug** `211-217` — B1 rapporte le nombre de statuts au maximum du lot.
- **m qualité** `20-26, 92-99, 171` — `source = "wfs"` et `protection_types` ne servent à rien ; code mort.

**R/indicators-risk.R**
- **C bug** `718-738` — R3 utilise un climat simulé et `set.seed(42)` global **[vérifié]**.
- **M bug** `972` — L'appétence de R4 est lue sur le premier polygone intersecté, pas sur le polygone majoritaire.
- **M bug** `283-308` — Repli R1 : le proxy NDVI a un poids nul, et il reste un facteur constant de 50.
- **M qualité** `509-618` — Le roxygen de R3 est rattaché à `.R3_BILJOU_BOUNDS`.
- **m bug** `489-491, 796-799` — TRI et TWI sont normalisés par le max de l'emprise ; un gibier NA est remplacé par 50 ; les messages disent « 50 » alors que la valeur est NA.

**R/indicators-families.R**
- **M bug** `48-60` — Le cache fichier du vent NASA POWER n'est pas indexé par la position : le premier projet est relu pour tous.
- **M bug** `1713-1722, 1690, 1876` — La nomenclature OSO est incohérente entre L1, L2, A1, RECONFORT et FR.json (L2 calcule la cohésion du bâti).
- **M bug** `735-853` — W2 additionne quatre sources qui se recouvrent au lieu de faire une union des masques.
- **M bug** `620-623` — W1 vaut 0 sans couche de cours d'eau, au lieu de NA.
- **M bug** `366` — `density` est une fraction 0-1 dans C1 et des tiges/ha dans P1.
- **m bug** `1230-1278` — F1 : surface NA comptée au dénominateur, classes non remises à l'échelle, min-max relatif au lot.
- **m qualité** `1690` — `forest_values` de L1 n'est pas utilisé ; l'« auto-detect » de W2 n'existe pas ; les fenêtres TWI de W3 et F2 divergent.

**R/indicators-frost.R**
- **M bug** `22-29` — Avec une seule unité, `vapply` renvoie un vecteur et `rowMeans` plante (R7).
- **m bug** `100, 112` — `extract` sans `exact` : une petite UGF sur la grille SAFRAN rend NA.

**R/indicators-energy.R**
- **M bug** `268-279` — E2 additionne un stock (m³/ha) à un flux annuel.
- **M bug (à confirmer)** `182` — Le facteur `× 0.5` sur une densité déjà sèche donnerait un E1 sous-estimé d'un facteur 2.
- **m qualité** `169-197` — Les résidus restent à 0 (pas NA) quand le volume est NA ; un message est émis par unité.

**R/indicators-deperissement.R**
- **M bug** `175-180` — `st_intersects` compte toute la surface d'un cluster dans chaque UGF qu'il touche (double comptage).
- **m qualité** `76` — Les poids de confiance du chêne sont appliqués au pin sylvestre.

**R/indicators-social.R**
- **M bug** `96-101, 195-200` — Les routes et bâtiments hors de l'emprise du MNT sont ignorés, donc S1/S2 valent NA ou sont surestimés.
- **m bug** `339-343` — Le carreau INSEE est retrouvé par sa valeur de population.
- **m qualité** `214-250` — L'exemple `method = "proxy"` aborte ; le `@return` est faux.

**R/indicators-naturalness.R**
- **m qualité** `99, 226, 76` — La doc dit « 50 » alors que le code renvoie NA ; N1 contient un terme constant de +25.

**R/indicators-temporal.R**
- **M bug** `88-145` — Le TFV de la BD Forêt passe avant un âge mesuré ; un TFV inconnu donne 50.
- **M bug** `241-281` — T2 est une copie de N2 ou de l'âge, alors que la doc annonce un taux de changement.

**R/indicators-air.R**
- **M bug** `376-384` — A2 est normalisé par le max du lot (une seule unité donne 0) ; `urban_areas` n'est jamais lu.
- **m bug** `602-605` — Le cas `n == 0` de A5 ne pose pas `a5_status`.

**R/indicators-productive.R**
- **m bug** `620` — Le test conifère de P3 (`^P[IML]`) rate ABAL, PSME, LADE et CEAT ; les défauts forme = 70 et défauts = 85 fabriquent 40 % du score.
- **m qualité** `29-58` — Deux formules différentes dans le roxygen de P1.

**R/indicators-microclimate.R**
- **m qualité** `73-77, 132` — L'attribut `augmented` est posé même quand le résultat est NA ; `microclimate_run()` est exporté mais aborte toujours.

**Transverse indicateurs**
- **M qualité** — Contrat de retour hétérogène (vecteur pour C1, C2, W*, F*, L*, T*, `sf` pour les autres), `stop()` et `cli_abort()` mélangés, `lang` jamais utilisé, paramètres numériques non validés.

### Production, IFN, LiDAR

**R/volume_mobilisable.R**
- **C bug** `239` — `P1 × taux × horizon` est dimensionnellement faux (roxygen l. 40 et spec 040 aussi) **[vérifié]**.

**R/data-hunting.R**
- **C bug** `255, 263, 278` — `dept` est entier dans 7 fichiers et caractère dans le sanglier, d'où des départements 01-09 en double.
- **M bug** `629-638` — La jointure avec ADMIN EXPRESS échoue sur « 3 » ; ces départements reçoivent la médiane nationale sans le dire.
- **m qualité** `76-77` — Un simple warning jsonlite fait perdre la résolution dynamique des URL.

**R/ifn_espar.R, inst/extdata/ifn_espar_correspondance.csv**
- **M bug** `l. 64 du CSV` — Le Douglas est codé `PIME`, alors que tout le code utilise `PSME`, et deux tarifs Douglas divergent. `resoudre_espar("PSME")` donne NA.

**R/site_index.R, R/density_selfthinning.R, R/synthetic_inventory.R**
- **M bug** `site_index.R:76-79` — Trois définitions concurrentes de « résineux » ; PIHA, PILA et LAKA tombent sur la courbe feuillus.
- **M bug** `synthetic_inventory.R:170`, `density_selfthinning.R:134` — Dg et N_max sont bornés en silence (vieille chênaie plafonnée à 30 cm).
- **m bug** `site_index.R:368-374` — Une hauteur hors des courbes est bornée à la classe 1 ou 5, alors que le commentaire annonce NA.
- **m qualité** `synthetic_inventory.R:160-161` — `if (x) 15 else 15` (code mort).

**R/ifn_source.R**
- **M bug/sécu** `211-216` — Pas de timeout (60 s pour 65 Mo), pas de contrôle d'intégrité, et un zip partiel est réutilisé comme cache.
- **m qualité** `204-206` — `campagne` n'est pas validé.

**R/ifn_production_domaines.R**
- **m bug** `248-257, 307` — Une covariable absente ou NA donne `delta = 0` alors que `predicteur = "hybride"` est annoncé.
- **m bug** `103-110` — `part_foret` mélange les unités d'un raster en degrés.

**R/houppiers.R, R/houppiers_lsms.R**
- **M bug** `houppiers.R:285-293`, `houppiers_lsms.R:185` — En LSMS sans CHM, l'AOI n'est pas reprojetée et l'abandon « aoi does not intersect » est faux.
- **m qualité** `houppiers_lsms.R:219` — `withr` est utilisé alors qu'il n'est qu'en Suggests.
- **m qualité** `houppiers.R:102-193` — Cinq paramètres ne sont documentés que dans le `.Rd`.

**R/utils-chm.R**
- **M qualité** `124, 144, 217` — `terra::values(chm)` charge tout le raster jusqu'à 5 fois (OOM sur un CHM à 0,2 m).
- **m qualité** `425-429` — Branche `terra::extract` morte et fausse.

**R/lidar_processing.R**
- **m bug** `145` — Les classes de bruit (7/18) entrent dans le CHM.
- **m bug** `117, 150-182` — Un cache partiel ou rogné sur une autre AOI est réutilisé.

**R/croiser_parcelles_onf.R**
- **m bug** `235-283` — Une écharde d'UGF absorbée dans `hors_ugf` est perdue quand `inclure_reste = FALSE`.
- **m bug** `201, 373` — Avec un identifiant cadastral en double, la première géométrie est prise en silence.

**R/load_onf_parcelles.R**
- **m sécu** `27` — WFS ONF en HTTP clair (contrainte du service, à documenter).

**R/cv_typology.R**
- **m bug** `465` — Un CV NA est compté comme 0, donc la taille d'échantillon est sous-estimée.

**R/spectral_diversity.R**
- **m bug** `136-142` — `reuse_existing` ne vérifie pas que les entrées sont les mêmes (B4/L3 périmés).
- **m qualité** `329, 385` — Message « Calculated » affiché même quand tout vaut NA.

### Climat, microclimat, régénération, chargeurs

**R/indice_priorite_regen.R** (avec `R/regen_engines.R:827`)
- **C bug** — L'exposition lit le score centré-réduit de `sensibilite` comme une valeur 0-100 ; il faut consommer `100 - sensibilite_score` **[vérifié]**.

**R/regen_engines.R**
- **M bug** `500-503` — Le cache microclimat n'a que l'année pour clé (emprise, `mois_ete`, PAI absents).
- **M bug** `324-328, 430` — Le cache ERA5 n'est pas indexé par lon/lat.
- **M bug** `187, 1074-1102` — Un `lai_max` NA par unité n'est pas remplacé par la valeur par défaut.
- **m bug** `416, 430` — Un `.nc` tronqué est réutilisé comme cache.
- **m qualité** `242-254, 777-781` — Écriture dans `globalenv()` (refusé par CRAN).
- **m qualité** `994-995` — Les rasters temporaires ne sont pas supprimés.
- **m qualité** `643-848` — `regen_sensibilite()` fait environ 200 lignes.

**R/load_biljou.R**
- **M bug** `98-108, 171` — Le cache ERA5 est partagé entre unités et projets (même forçage pour tous).
- **M qualité** `60-62, 191-195` — Une requête SAFRAN en échec retire l'unité en silence.
- **m qualité** `155-164` — `years` n'est pas validé ; le callback de progression n'est pas protégé.

**R/load_eobs.R**
- **M bug** `53-56` — Un été incomplet est accepté (moyenne de juin seul, cumul de pluie sur 30 jours).
- **M bug** `129-144` — Des années à cheval sur deux blocs du CDS renvoient NULL sans message.
- **M qualité** `105-107, 218-244` — Toutes les erreurs deviennent NULL sans message (cf. incident de juillet).
- **m sécu** `112` — `unzip` sans contrôle des chemins.

**R/tendances_eobs.R / R/eobs_click_series.R**
- **M bug** `tendances_eobs.R:149-150` — Pente par an, alors que la doc et le graphique au clic parlent de pente par décennie (facteur 10).
- **m bug** `eobs_click_series.R:144-152` — Un jour NA compte comme 0 mm.

**R/eobs_downscale.R**
- **M bug** `439-445` — Le moteur meteoland agrège par `max`, KED par la moyenne, sous le même libellé.
- **m bug** `285` — Un jour SAFRAN manquant donne 0 mm.
- **m qualité** `402-405` — `resolution` et `covariates` sont ignorés en mode meteoland.
- **m qualité** `16-23` — Copie de `.eobs_slope`.

**R/soil_water.R**
- **M bug** `214-221` — Un horizon SoilGrids non chargé est sauté en silence, et la réserve utile est sous-estimée.

**R/data-preprocessing.R**
- **M bug** `34` — `terra::project` sans `method = "near"` : la couverture du sol est interpolée en classes fractionnaires.
- **m bug** `30` — La comparaison des CRS vaut NA sans code EPSG.

**R/microclimate_years.R**
- **m bug** `16-37` — Le contrôle `length >= 2` est fait avant le retrait des NA.

**R/load_insee_population.R**
- **m bug** `104, 146, 153` — Un `.gpkg` tronqué sert de cache indéfiniment.
- **m qualité** `15-28` — URL en dur alors que FR.json les déclare (idem SAFRAN EDR et E-OBS).

**R/data.R / R/data-massif_demo.R**
- **m qualité** — `massif_demo_units` est documenté deux fois, avec des colonnes qui n'existent pas ; la fixture n'a que 31 indicateurs sur 41.

**R/regen_rank_species.R**
- **m qualité** `221-249` — `include_atlas` n'est documenté que dans le `.Rd`.

**inst/datasources/FR.json**
- **m qualité** — L'entrée `eobs` est incomplète (variables `rr`, `tg`, dataset CDS) ; `onf_wfs` est en HTTP.

### Santé (FAST, FORDEAD) et base de données

**R/fordead_postprocess.R**
- **C bug** `380-383` — Un re-run efface les validations terrain **[vérifié]**.
- **M bug** `320, 366` — Un run sans alerte ne purge pas les alertes précédentes (base et carte se contredisent).
- **m bug** `458-528` — Une `trigger_date` NA fait planter `classify_disturbance`.
- **m qualité** `563-655` — `classes = character(0)` produit `IN ()` ; les types de sortie diffèrent entre PG et SQLite.

**R/fordead_pipeline.R**
- **M qualité** `639-655, 757-766` — Un échec du post-traitement ou de l'insertion donne quand même `status = "success"`.
- **m bug** `82-84, 478` — Fin de fenêtre NA documentée mais refusée ; des `Date` acceptées puis refusées après des heures de téléchargement.
- **m bug** `726-744` — Le nettoyage `replace` supprime les sorties d'un run concurrent.

**R/fast_alert_raster.R**
- **M bug** `1389-1392` — La tuile MGRS est lue sur l'orbite pour les identifiants CDSE **[vérifié]**.
- **m bug** `423` — Le COG résultat est écrit sans fichier temporaire.
- **m bug** `352-354` — Les scènes sans tuile sont écartées en silence.

**R/monitoring.R, R/sentinel2_cache.R**
- **M bug** `monitoring.R:727-735`, `sentinel2_cache.R:139-145` — Le saut des scènes en cache ne vérifie pas l'emprise (zones `_feu`, `_res`, `_tot`).
- **M bug (à confirmer)** `pixel-map.R:~286-302` — L'offset radiométrique S2 `BOA_ADD_OFFSET = -1000` (baseline ≥ 04.00, depuis 2022) n'est pas géré : risque de faux déclin général du NDVI.
- **m sécu** `1112, 1390` — L'URL signée (avec son jeton) part dans les événements et les logs.
- **m bug** `366` — Une erreur DB est confondue avec « zone sans géométrie ».
- **m qualité** `1446` — Le retour de `file.rename` n'est pas vérifié.
- **m qualité** `35-41, 282-283` — Doc obsolète (UNIQUE, `obs_pixel`).

**R/monitoring-zones.R**
- **M bug** `276-294` — La suppression et la recréation des zones ne sont pas dans une même transaction (perte en cascade).
- **M bug** `347-375` — `prune_orphan_zone_caches` détruit tous les caches si l'app pointe sur une autre base.
- **m bug** `monitoring.R:64`, `monitoring-zones.R:92` — Un `sf` multi-entités est tronqué à la première.
- **m bug** `monitoring.R:71-73` — Relecture de l'id par nom au lieu de `RETURNING id`.
- **m bug** `monitoring.R:89-102` — Les placettes sont insérées hors transaction.
- **m bug** `find_zone_by_project.R:33-39` — Pas d'`ORDER BY` : id arbitraire en multi-zone.

**R/health_validation.R**
- **M bug** `141-147` — Un stade inconnu (ou `"sain "` avec une espace) devient « dépérissement confirmé ».
- **m bug** `477-490` — `alert_id` est ignoré au profit du plus proche voisin à 50 m.
- **m bug** `525` — Heure locale écrite dans une colonne TIMESTAMPTZ.
- **m qualité** `517-535` — Les UPDATE ne sont pas dans une transaction.
- **m bug** `373` — La comparaison de CRS vaut NA sans code EPSG.

**R/fordead_stac.R**
- **M bug (à confirmer)** `300-301` — Deux items de même id par date sur une AOI à cheval sur deux tuiles.

**R/db.R et migrations**
- **M bug** `pg/0007:18`, `sqlite/0007:13` — `DROP TABLE IF EXISTS alert` sans garde.
- **m sécu** `db.R:58-61, 357` — Les messages d'erreur affichent l'URL de base avec le mot de passe.
- **m bug** `db.R:351-366` — Pas de décodage URL ; une query string se colle au `dbname`.
- **m bug** `db.R:282-345` — Pas de verrou autour de `db_migrate`.
- **m qualité** `pg/0001:10` — TimescaleDB est obligatoire mais plus utilisé.
- **m qualité** `sqlite/0007:27` — `validation_status` est nullable sous SQLite et NOT NULL sous PG.

**R/project_lock.R**
- **m bug** `122-184` — `BEGIN` différé sous SQLite : `SQLITE_BUSY` au lieu de `ok = FALSE`.

**R/isolate.R**
- **m sécu** `239-249` — `call.rds` (avec l'URL de base) et `run.R` sont écrits dans un chemin prévisible, en 0644, si le scratch est partagé.
- **m bug** `311-319` — Le `.ndjson` de progression n'est pas tronqué, d'où des événements rejoués.

**R/fordead_validity.R, R/fordead_mask.R**
- **M qualité** `fordead_validity.R:119-167` — Roxygen détaché (perte de l'export de `check_fordead_validity`).
- **m qualité** `fordead_mask.R:13-30` — La doc dit le masque « à venir » alors qu'il est persisté.

**R/sentinel2.R, R/fordead_python.R**
- **m qualité** `fordead_python.R:497` — `pip install --upgrade` avec des bornes ouvertes : environnement non reproductible.

**R/pixel_dieback_prep.R**
- **m bug** `212` — Les trous d'interpolation sont calculés sur toutes les dates, y compris masquées.

### RECONFORT et Python embarqué

**R/reconfort_pipeline.R**
- **M bug** `537, 570-573` — Aucun garde-fou de saison sur `s2_year` (run d'une année incomplète, `trigger_date` dans le futur).
- **M bug** `700-711` — Sans masque, une seule tranche est utilisée → risque d'OOM.
- **M sécu** `579-581, 935, 945` — `zone_id` et `output_dir` ne sont pas contrôlés avant `unlink(recursive = TRUE)`.
- **M bug** `752-756` — Pas de verrou sur le workdir, alors qu'un IOTA² orphelin survit dans son scope systemd.
- **m bug** `263-275` — La remise à zéro dépend d'un `run_meta.json` écrit en best-effort.
- **m bug** `700` — Le contrôle du défaut #11 n'est fait qu'en mode découpé.
- **m bug** `681-685` — `skip_ingest = TRUE` ne vérifie pas les dossiers extraits.

**R/reconfort_ingest.R**
- **M bug** `446-448, 500-505` — Le marqueur `.done` ne dépend pas de la fenêtre AOI.
- **M bug** `313-314` — `conda run` sans `--no-capture-output` : sortie perdue si le scope est tué.
- **M sécu** `217` — pygeodes en `verify=False` (clé GEODES exposée à un MITM, archive non vérifiée), et l'avertissement est masqué.
- **M sécu** `100-109` + `utils/utils.py:6-7` — Le `.cfg` est relu avec `eval()` côté Python ; un chemin contenant `\'` injecte du code.
- **m bug** `314` — Chemin de cfg relatif sous `with_dir`.
- **m sécu** `488` — `unzip` d'une archive distante sans contrôle des entrées.
- **m qualité** `352, 369` — `__pycache__` écrit dans le dossier installé du paquet.
- **m bug** `479-505` — Une scène à moitié recadrée reste dans `extracted/`.

**inst/python/reconfort/mask_and_compress_rasters.py**
- **M bug** `64-69` — Le score des pixels très sains est arrondi à 0 = no-data, et `sum_proba == 0` masque des pixels valides.
- **M bug** `64` — Trois bandes supposées : `v3_pine` (2 classes) plante.

**inst/python/reconfort/ (traçabilité)**
- **M qualité** — Fichiers annoncés « verbatim » alors qu'au moins 5 sont modifiés, sans PATCHES ni NOTICE (Apache-2.0 §4b) ; deux scripts se déclarent MIT alors que le paquet est GPL-3.
- **m qualité** `repair_iota2_env.sh` — Les correctifs #9 et #10 ne sont pas sondés côté R.

**R/reconfort_outputs.R**
- **M bug** `487-489` — Le masque nuages cherche `*_SCL*` (Sen2Cor), absent des produits MUSCATE : le bundle n'est jamais masqué.
- **m bug** `482-486` — Regroupement par date sans tenir compte de la tuile.

**R/reconfort_crop.R**
- **m bug** `93, 102` — Un chemin est utilisé comme expression régulière.

**R/reconfort_manifest.R**
- **m bug** `291-304` — Choix du run par ordre alphabétique, et non par date.

**R/theia_stac.R**
- **m bug** `149` — `signed[[u]] %||% u` sur un vecteur atomique lève une erreur.
- **m qualité** `437-476, 643-647` — Roxygen sans titre et obsolète (`/vsis3/`, SDK).
- **m bug** `139-144` — Signature sans timeout ni retry, endpoint `http` accepté.

**R/lai_prosail.R**
- **m bug** `73-78` — `geom_acq` absent de la clé du cache ; le modèle livré l'emporte.

### RAG, QGIS/QField, échantillonnage

**R/knowledge-corpus.R**
- **M sécu** `427-447` — Le manifeste éditable (onglet admin) peut faire ingérer n'importe quel fichier local, ou une URL `file://`, et envoyer son contenu au fournisseur d'embeddings.
- **m sécu** `440` — `doc_id` non revalidé : écriture hors de `pdf_dir` possible.
- **M bug** `38-39` × `rag.R:390` — Les vocabulaires `doc_type` divergent (guide, law, dataset_doc refusés à l'ingestion).
- **M bug** `585, 589` — `dry_run` télécharge réellement les PDF.
- **M qualité** `429` — `local_path` est relatif à `data-raw` (exclu du build) : 58 sur 60 sources ne sont pas résolues depuis le paquet installé.
- **m bug** `604, 612` — L'idempotence repose sur le titre.
- **m bug** `441-447` — Un PDF corrompu reste en cache.
- **m qualité** `600-604` — `fresh = TRUE` vide le corpus hors transaction.

**R/rag.R**
- **M sécu** `1021-1044` — `format_citations(html)` n'échappe rien (XSS si l'app rend ce HTML).
- **M bug** `361-371` — Un chemin inexistant est ingéré comme texte.
- **M bug** `897-915` — Pas de contrôle du provider ni de la dimension entre requête et corpus.
- **m qualité** `888-895` — Pas d'argument `api_key` dans `retrieve_knowledge()`.
- **m qualité** `872, 906` — Bornes de `min_similarity` différentes entre doc et code ; `lang` jamais utilisé.
- **m bug** `296-327` — Échappement incomplet des tableaux texte.
- **m qualité** `475-505` — Une ré-ingestion duplique les chunks.
- **m bug** `99-119` — UTF-8 invalide → `nchar()` lève une erreur.

**R/qgis_export.R**
- **M bug** `357` — `if (NA)` sur un CRS sans code EPSG : l'export plante.
- **M sécu** `363-470` — `project_name` non validé (traversée de chemin, option `zip`).
- **M bug** `409-411` — Les poids d'inclusion et les colonnes métier sont perdus à l'aller-retour QField.
- **m qualité** `364-369, 468-471` — `setwd` global et dépendance au binaire `zip`.
- **m qualité** `483-486` — La dépréciation annoncée « one-shot » avertit à chaque appel.

**R/qgis_import.R**
- **M bug** `293-316` — `g_ha`, `dg` et `h_dom` sont calculés sur les arbres morts et coupés.
- **m bug** `127-131` — Mauvais numéros de ligne dans le rapport.
- **m bug** `144-174` — `tree_id` et les champs obligatoires ne sont pas contrôlés.
- **m bug** `293` — Colonne `dbh_cm` absente → erreur brute.
- **m bug** `403` — Repli sur un identifiant non unique.

**R/validation_sampling.R**
- **M bug** `113, 129-131` — `zone` est validé mais jamais utilisé : des placettes sont tirées hors de la zone.
- **M bug** `570-593` — La pondération « uniform » par classe est inversée, et le reliquat plafonné n'est pas redistribué.
- **m qualité** `66, 370, 163, 424` — CRS annoncé faux ; `seed` ignoré ; `set.seed` global.
- **m qualité** `151-158, 416-419` — Une entrée NA donne une erreur brute.

**R/sampling_plan.R**
- **M bug** `680-684` — Les poids GRTS sont supprimés (estimation biaisée).
- **M qualité** `159-166` — Une erreur d'extraction donne NA, ce qui désactive la contrainte de pente en silence.
- **m bug** `246-255` — Allocation arrondie sans complément (9 placettes au lieu de 10).
- **m qualité** `476` — `set.seed` global.
- **m bug** `445-479` — Une zone en EPSG:4326 donne un pas de 50 degrés.
- **m qualité** `464, 472-474` — `n_over` n'est pas validé.

**R/sample_size.R**
- **m qualité** `77-80` — `alpha = NA` donne une erreur brute ; `@keywords internal` sur un export.

**inst/scripts/**
- **m qualité** — Outils de dev installés avec le paquet → les déplacer dans `tools/`.

### Paquet, CI, documentation

**data/ et .Rbuildignore**
- **C qualité** — L'archive de 5,4 Go n'est pas exclue du build **[vérifié]** ; `area_interest.geojson` déclenche un WARNING.
- **M qualité** — `__pycache__/*.pyc` et `.Renviron.example` partent dans le tarball.
- **M bug** — `aba.model` et `coregistration` sont exclus du build alors que les tutoriels 07 et 08 les lisent.
- **m qualité** — Un nom de fichier de plus de 100 octets dans `inst/python`.

**man/*.Rd**
- **M qualité** — 6 `.Rd` ont une signature fausse (`classify_disturbance`, `indicateur_s3_population`, `stac_search_s2`, `load_foret_ancienne_source`, `lsms_budget_pixels`, `lsms_duree_estimee`).
- **M qualité** — Arguments non documentés (`apply_zone_mask`, `mask_polygon`, `zone_polygon`, `warn_outside_zone`).
- **m qualité** — NOTE « Lost braces » et lignes d'exemple trop longues.

**DESCRIPTION**
- **M bug** — `methods` et `prosail` ne sont pas déclarés (WARNING).
- **M qualité** — Description obsolète (« Includes nemetonApp »).
- **m qualité** — Doublons dans Suggests ; `ggrepel`, `signal`, `tidyr` et `cluster` pourraient passer en Suggests ; `stats::ave` non importé.
- **m qualité** — Faisabilité CRAN : `Remotes`, 6 Suggests hors dépôt, tarball de 10,5 Mo.

**R/ (portabilité)**
- **M qualité** — Caractères non ASCII dans le code de 18 fichiers (WARNING).

**.github/workflows**
- **M qualité** `release.yml:21-27` — La release ne dépend pas du succès du check.
- **M qualité** `r.yml:156-159` — `--no-tests` et `error-on: error` : les WARNING passent sans bruit.
- **m sécu** — Actions épinglées par tag, pas par SHA ; `pkgdown.yaml` a `contents: write` sur les PR.
- **m qualité** `r.yml:33` — `version-consistency` lit le premier numéro de version venu dans NEWS.

**tests/testthat/**
- **M qualité** — La suite écrit dans `~/.local/share/nemeton/cache` et télécharge un CPython (160 Mo) via reticulate/uv.
- **m qualité** — `EBImage` n'est pas déclaré ; 29 warnings ; 9 exports sans test (`FORDEAD_VALIDITY_SPECIES`, `RECONFORT_VALIDITY_SPECIES`, `bai_drift_factor`, `charru_bai_drift_table`, `charru_selfthinning_table`, `n_max_selfthinning`, `get_metric_crs`, `get_storage_crs`, `microclimate_run`).

**docs/, vignettes/**
- **M qualité** — `docs/` est suivi par git et figé en v0.13.0 (503 fichiers, 19 Mo).
- **m qualité** — HTML et R des vignettes commités ; le guide de l'app (`nemetonapp-guide_fr.Rmd`) n'a plus sa place ici.

**README.md, CLAUDE.md, cran-comments.md, create-release.sh, LICENSE**
- **M qualité** — « 31 indicateurs » alors que le code en déclare 41.
- **m qualité** — `cran-comments.md` obsolète ; `create-release.sh` contredit la release automatisée ; CLAUDE.md renvoie à un fichier `LICENSE` qui n'existe pas (c'est `LICENSE.md`) ; URL codecov en 301.

---

## 4. Proposition de séquence vers la 1.0.0

1. **0.208 — corrections de calcul** : bloquants 1 à 7 et 9 à 11 (indicateurs, régénération, volume mobilisable, chasse, FORDEAD, `%||%`, `nemeton_compute`, normalisation, tuile MGRS). Chaque correctif avec un test qui échoue avant et passe après. Ce sont des changements de valeurs : à annoncer dans NEWS, et l'app devra recalculer.
2. **0.209 — robustesse des données** : clés de cache (ERA5, microclimat, vent, S2 par emprise, `.done` RECONFORT), téléchargements atomiques, étés incomplets, transactions (zones, validations), migration 0007, `prune_orphan_zone_caches`.
3. **0.210 — sécurité** : `eval` du cfg Python, `verify=False` de pygeodes, manifeste RAG, `format_citations`, `project_name`, `zone_id`/`output_dir`, URL de base dans les messages, jetons dans les événements.
4. **0.211 — paquet propre** : `.Rbuildignore`, DESCRIPTION, `.Rd` (8 WARNING → 0), blocs roxygen détachés, non ASCII, CI (`error-on: warning`, release conditionnée au check, actions par SHA), tests hermétiques, `docs/` retiré.
5. **0.212 — contrat d'API** : choix sur les retours vecteur ou `sf`, `lang`, `stop`/`cli_abort`, exports à retirer ou à marquer *experimental* (313 exports, c'est beaucoup à figer). Documenter ce qui est stable.
6. **1.0.0** quand le check est à 0 WARNING en CI, la suite verte, et l'app recalée sur les nouvelles valeurs.
