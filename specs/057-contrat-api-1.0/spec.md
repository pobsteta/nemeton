# Spec 057 — Contrat d'API de la 1.0.0

> **Statut** : **validé** par Pascal le 2026-10-06 (bump majeur 1.0.0 groupé
> avec les choix de méthode de la spec 056 ; liste §4.1 appliquée telle quelle). Décision de Pascal : contrat **complet,
> avec ruptures**. La 1.0.0 **casse tous les anciens projets, sans migration**
> (Pascal repart de zéro ; tous les projets existants sont les siens). Seule
> contrainte : `nemetonshiny` doit tourner contre la 1.0.0, d'où le brief app
> du §6.
> **À confirmer avant le code** : le bump majeur (1.0.0) et la liste du §4.

## 1. Retour unique des indicateurs : un `sf`

**Aujourd'hui**, 43 fonctions `indicateur_*` exportées, deux contrats :

| Rendent l'`sf` d'entrée + colonne de valeur | Rendent un vecteur numérique |
|---|---|
| A2-A5, B1-B4, E1, E2, L3, N1-N3, P1-P3, R1-R7, S1-S3, W4 (+ A1 à confirmer) | **C1, C2, F1, F2, L1, L2, T1, T2, T3, W1, W2, W3** |

**Contrat 1.0** : tout `indicateur_*()` rend **l'objet `units` d'entrée** (même
classe, mêmes lignes, même ordre), augmenté de :

- la **colonne de valeur**, nommée par le code (`C1`, `W3`, …), numérique,
  `NA` quand non calculable ;
- éventuellement une colonne de statut `<code>_status` (minuscules, convention
  `.capture_status_attr()` de l'app) et des colonnes annexes documentées.

Jamais de vecteur nu, jamais de colonne de valeur sous un autre nom.

**Impact** :
- cœur : les 12 fonctions ci-dessus, le dispatcher (`nemeton_compute()`,
  `compute_indicator`, `extract_indicator_value()`), les indicateurs qui en
  lisent d'autres (N3, T2, E2…), tests et tutoriels ;
- app : **aucun changement de code attendu** — `compute_single_indicator()`
  passe déjà tout `sf` par `extract_indicator_value()` ; aucun appel direct aux
  12 fonctions (vérifié en lecture seule, 2026-10-06).

## 2. Paramètre `lang` retiré

`lang` n'a aucun effet dans E1, E2, N1-N3, P1-P3, S1-S3 (documenté
« inutilisé » en 0.213.0) : il est **retiré des signatures**. `embed_query(lang)`
(réservé, inutilisé) aussi. Restent les `lang` qui servent : `indicator_labels()`,
`format_citations()`, messages i18n. L'app ne passe `lang` à aucun indicateur
(vérifié).

## 3. Alias historiques retirés

`indicateur_l1_sylvosphere()` et `indicateur_l2_fragmentation()` (anciens
slugs, renommés en 0.176.0, spec 045) : **retirés**. L'app ne les appelle pas :
elle ne garde ces noms que comme noms de colonnes en base (`service_db.R`,
`migration_003_ug.sql`), ce qui n'est pas touché. `microclimate_run()`
(exportée mais échoue toujours) : **retirée de l'export** ; les fiches R6 et W4
(`vignettes/fiche-r6-*`, `fiche-w4-*`) qui la citent sont reformulées.

## 4. Tri des exports (316 aujourd'hui)

Inventaire du 2026-10-06 : l'app consomme les 135 exports de
`specs/audit-1.0/exports-consommes-app.md` **plus les 43 indicateurs**, qu'elle
appelle par leur nom (`exists()` / `get()` via `import(nemeton)`) et que
l'inventaire précédent ne voyait pas. **101 exports** ne sont utilisés ni par
l'app ni par les tutoriels. Proposition :

### 4.1 Retirer de l'export (plomberie interne) — ~35

- **STAC / Theia bas niveau** : `stac_search_s2_cdse`, `stac_search_s2_pc`,
  `stac_search_s2_theia_muscate`, `stac_search_items`, `stac_get_item`,
  `theia_sign_urls`, `theia_signed_href`, `resolve_theia_assets`
  (la façade `stac_search_s2()` et les `load_*_source()` restent) ;
- **exécution / système** : `run_reticulate_isolated`, `scratch_dir`,
  `smart_map_sf`, `schema_to_df` ;
- **RECONFORT, étapes internes** : `reconfort_ingest_s2`, `reconfort_aoi_tiles`,
  `ensure_reconfort_model`, `ensure_reconfort_oso_mask`,
  `reconfort_model_info` (`run_reconfort_dieback()` et les lecteurs restent) ;
- **S2 / LiDAR internes** : `ingest_s2_raw_bands_to_cache`, `diagnose_s2_cache`,
  `probe_ign_lidar_tile` (le pluriel `probe_ign_lidar_tiles`, utilisé par l'app,
  reste), `lsms_budget_pixels`, `lsms_duree_estimee` ;
- **constantes de configuration** : `RECONFORT_BANDS`, `RECONFORT_MODELS`,
  `RECONFORT_OSO_MASK`, `FORDEAD_BANDS` ;
- **divers** : `regen_rank_to_wide`, `eobs_bivariate_n`, `h_to_dq_params`,
  `filter_alerts_to_zone`, `read_fast_alert_rasters` (le singulier reste),
  `microclimate_run`, alias L1/L2 du §3.

### 4.2 Garder (API publique d'analyse, même non utilisée par l'app)

IFN (`ifn_*`, `resoudre_espar`, `estimer_fay_herriot`, `completer_volume_ifn`),
station et croissance (`compute_site_index`, `n_max_selfthinning`,
`bai_drift_factor`, `charru_*`), NDP (`get_ndp_*`, `ndp_table`), configuration
essences et pays (`get_species_config`, `list_species_classes`, `map_*`,
`get_country_config`, `list_countries`, `get_*_crs`), analyse et graphiques
(`plot_*`, `calculate_change_rate`, `cv_*`), sol (`awc_saxton_rawls`,
`ewm_depuis_soilgrids`), schémas terrain (`get_*_schema`), référentiels
documentés (`FORDEAD_CLASSES`, `RECONFORT_CLASSES`, `HEALTH_VALIDATION_*`,
`*_VALIDITY_*`, `european_species_tolerances`), RAG (`enable_rag`,
`embed_query`, `ingest_knowledge_*`), biophysique (`biophys_*`,
`biophysique_sentinel2`), `create_monitoring_zone`, `fordead_alert_mask`,
`units_add_species_from_raster`, `stac_search_s2`, `get_allometric_key`,
`get_datasource_product`, `load_*_validity_zones`, `reconfort_latest_complete_year`.

### 4.3 Statut documenté

Chaque page d'aide porte un statut : **stable** (indicateurs, familles, NDP,
normalisation, chargeurs, échantillonnage, API consommée par l'app) ou
**experimental** (RAG, biophysique, FORDEAD/RECONFORT, régénération). La page du
paquet et `_pkgdown.yml` regroupent par statut.

## 5. Déjà fait

Erreurs homogènes `cli::cli_abort()` (0.213.0) ; `lang` documenté inutilisé
(0.213.0).

## 6. Coordination avec l'app

- L'app ne change pas de code pour les §1 à §3 (vérifié) ; pour le §4, aucun
  des exports retirés n'est appelé par l'app (vérifié par recherche dans
  `nemetonshiny/R` et `inst/`).
- `Remotes:` de l'app pointe sur la dernière version du cœur : entre la release
  cœur 1.0.0 et l'adoption, l'app tourne contre la 1.0.0. Les §1-§4 étant
  transparents pour elle, la fenêtre est sans risque ; un brief annonce la
  1.0.0 et le recalcul complet des projets.

## 7. Contenu de la 1.0.0

Ce contrat, plus les choix de méthode tranchés après la spec 056 (mesures en
cours), plus les décisions d'infrastructure prises d'ici là. Version :
**1.0.0** (bump majeur, à confirmer).
