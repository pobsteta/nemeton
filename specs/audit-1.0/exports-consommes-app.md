# Exports du cœur consommés par `nemetonshiny` (vague 6 de l'audit 1.0)

> Inventaire relevé par la session `nemetonshiny` le 2026-10-04 (brief
> `2026-10-04-plan-md-app-0.153.0-0.154.0.md`, §4), contre l'app v0.154.0
> (PR #217). À re-vérifier au moment du tri : l'inventaire vieillit.


L'app consomme aujourd'hui **135 des 313 exports** du cœur (inventaire du
2026-10-04 : appels `nemeton::` et symboles importés via `import(nemeton)`).
**Ne pas les retirer ni changer leur signature sans brief app** — ce serait une
rupture pour `nemetonshiny` *et*, depuis 0.154.0, pour son API publique.

```
a5_applicabilite aggregate_plot_metrics attach_field_data_to_units
bdforet_v2_mapping build_biljou_soil build_foret_ancienne_mask
build_index_stack build_knowledge_corpus build_project_monitoring_zones
canopy_provenance cec_to_fertility_score check_fordead_validity
check_reconfort_validity compute_dtm_chm_from_laz compute_fast_alert_mask
compute_general_index compute_sample_size compute_spectral_diversity
create_family_index create_qfield_project create_qgis_project
create_sampling_plan create_trend_sanitary_plan
create_validation_sampling_plan croiser_parcelles_onf cv_from_bdforet
db_connect db_disconnect db_migrate delete_knowledge_document detect_ndp
enrich_parcels_bdforet ensure_inventory_fields eobs_downscale
eobs_downscale_bivariate eobs_monthly_climatology eobs_summer_series
eobs_trend_fit extract_indicator_value extract_pixel_timeseries
extract_pixel_trend find_zone_by_project find_zones_by_project
format_citations format_duration get_data_source get_famille_code
get_famille_col get_global_cache_dir get_layer_service get_ndp_level
get_storage_crs ifn_covariables_domaines ifn_production_domaines
ifn_taux_prelevement_production import_qfield_gpkg import_qgis_gpkg
indicateur_a3_microclimat indicateur_a4_tamponnement
indicateur_a5_rafraichissement indicateur_r3_secheresse
indicateur_r5_deperissement indicateur_r6_sensibilite indicateur_r7_gel
indicateur_t3_coupes_rases indicateur_w4_vpd indicator_families
indicator_labels indice_priorite_regen ingest_health_validation
ingest_sentinel2_timeseries knowledge_manifest_path knowledge_manifest_vocab
lai_max_depuis_pai lai_sentinel2 list_alerts list_indicators
list_knowledge_documents list_species_regions load_biljou_forcing
load_eobs_source load_foret_ancienne_source load_insee_population_source
load_onf_parcelles_source load_raster_source load_theia_source localiser_ser
meteoland_daily_grid microclimate_detect_years migrer_colonnes_l
nemeton_radar normalize_indicator prepare_pixel_dieback_series
probe_ign_lidar_tiles project_lock_acquire project_lock_heartbeat
project_lock_release project_lock_status prune_orphan_zone_caches
r5_applicabilite read_fast_alert_mask read_fast_alert_raster
read_fordead_dieback_mask read_fordead_layer read_fordead_pixel_series
read_knowledge_manifest read_reconfort_alert_mask read_reconfort_layer
read_reconfort_pixel_series read_s2_band_raster reconfort_cache_manifest
reconfort_layer_manifest reconfort_year_bounds regen_bilan_hydrique
regen_rank_species regen_sensibilite regen_species_choices
regeneration_tolerances register_monitoring_zone reset_knowledge_manifest
resolve_project_chm resolve_project_dem retrieve_knowledge
run_fordead_dieback run_memory_capped run_reconfort_dieback sanitize_chm
segment_houppiers smooth_pixel_series tag_field_data_sources
theia_source_status validate_field_data validate_knowledge_manifest
volume_mobilisable write_knowledge_manifest
```

S'y ajoutent **21 symboles internes** lus par `utils::getFromNamespace()`
(`R/imports.R` et quelques services). Ils ne sont pas exportés : le tri de la
vague 6 est l'occasion de les **exporter** (ou de dire lesquels l'app doit
cesser d'utiliser) plutôt que de les renommer en silence :

```
FAMILLE_NMT_MAP as_pure_sf clean_indicator_name detect_ndp_from_cache
enrich_parcels_bdforet get_allometric_coefficients get_dem_raster
get_famille_code get_famille_col get_language map_essence_to_species
msg msg_error msg_info msg_success msg_warn resolve_raster_layer
resolve_vector_layer restore_ndp_attributes safe_extract set_ndp_attributes
```

(`get_famille_code`, `get_famille_col` et `enrich_parcels_bdforet` figurent
dans les deux listes : exportés aujourd'hui, l'app passe encore par
`getFromNamespace()` par héritage — sans conséquence, à nettoyer côté app.)

Les exports **non** listés ci-dessus (≈ 178) ne sont pas appelés par l'app :
le cœur peut les trier librement de son point de vue.

## Indicateurs consommés dynamiquement (ajout du 2026-10-06, spec 057)

L'inventaire ci-dessus ne relevait que les appels `nemeton::` et les symboles
nommés en clair. Les fonctions d'indicateur, elles, sont appelées **par leur
nom** : `compute_single_indicator()` (`nemetonshiny/R/service_compute.R`) fait
`exists(indicator, mode = "function")` puis `get()` sur le nom NMT, résolu via
`import(nemeton)`. Elles sont donc **toutes** consommées, et toutes passent
par `extract_indicator_value()` (vérifié en lecture seule le 2026-10-06 ; aucun
appel direct). Les 41 indicateurs exportés de la 1.0.0 :

```
indicateur_a1_couverture indicateur_a2_qualite_air indicateur_a3_microclimat
indicateur_a4_tamponnement indicateur_a5_rafraichissement
indicateur_b1_protection indicateur_b2_structure indicateur_b3_connectivite
indicateur_b4_div_spectrale indicateur_c1_biomasse indicateur_c2_ndvi
indicateur_e1_bois_energie indicateur_e2_evitement indicateur_f1_fertilite
indicateur_f2_erosion indicateur_l1_effet_lisiere indicateur_l2_morcellement
indicateur_l3_het_spectrale indicateur_n1_distance indicateur_n2_continuite
indicateur_n3_naturalite indicateur_p1_volume indicateur_p2_station
indicateur_p3_qualite_bois indicateur_r1_feu indicateur_r2_tempete
indicateur_r3_secheresse indicateur_r4_abroutissement
indicateur_r5_deperissement indicateur_r6_sensibilite indicateur_r7_gel
indicateur_s1_routes indicateur_s2_bati indicateur_s3_population
indicateur_t1_anciennete indicateur_t2_changement indicateur_t3_coupes_rases
indicateur_w1_reseau indicateur_w2_zones_humides indicateur_w3_humidite
indicateur_w4_vpd
```

Les deux anciens noms de la famille L, `indicateur_l1_sylvosphere` et
`indicateur_l2_fragmentation` (43 indicateurs exportés jusqu'en 0.216), ne
figurent plus dans l'app que comme **noms de colonnes** (`service_db.R`,
`service_project.R`, `inst/sql/*.sql`) : les fonctions sont retirées en 1.0.0
(spec 057 §3) sans effet sur l'app.

Contrat 1.0 (spec 057 §1) : chacun rend l'objet `units` augmenté de sa colonne
de valeur nommée par le code court. Conséquence côté app, sans changement de
code : C2 passe désormais par la branche `sf` de `compute_single_indicator()`,
donc par `.c2_apply_provenance()` — qui était inatteignable tant que C2 rendait
un vecteur. Un NDVI venu de l'ortho IRC WMS rend C2 indisponible
(`c2_status = "wms_irc"`), comme l'app l'avait prévu.

## Fonctions de la 0.216.0 (logique rapatriée de l'app)

Les trois fonctions ajoutées en 0.216.0 sont appelées par l'app (vérifié le
2026-10-06 sur le clone local, cycle 0.157.0.9000) et rejoignent la liste des
exports consommés :

```
aggregate_family_scores      R/service_synthesis.R
build_ndvi_season_composite  R/service_compute.R
climate_ombrothermic_indices R/fct_regen_context_plots.R
```

Total consommé par l'app à la 1.0.0 : 135 + 3 = **138 exports nommés**, plus
les **41 indicateurs** appelés par leur nom.
