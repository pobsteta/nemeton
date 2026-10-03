# BRIEF — nemeton 0.210.0 : sécurité (audit 1.0, vague 3)

> **Émis le 2026-10-03** par la session `nemeton`. **Packages** : `nemeton`
> (livré en **v0.210.0**), `nemetonshiny` (demandeur). Rapport à jour :
> https://claude.ai/artifact/EDFFCM5SmJ78DAAeuzTYs2

## 1. À faire côté app

1. **Corpus RAG (`mod_rag_admin.R:522, 561`)** : `build_knowledge_corpus()`
   n'accepte plus qu'un `local_path` situé sous la racine du corpus. La racine
   vaut l'option `nemeton.corpus_root`, sinon la variable d'environnement
   `NEMETON_CORPUS_ROOT`, sinon `getwd()`. **L'option R n'est pas transmise au
   worker `future`** : poser `NEMETON_CORPUS_ROOT` (dans `.Renviron` ou avant
   de lancer le worker). Une ligne refusée sort en `action = "error"`.
2. Plancher `Imports: nemeton (>= 0.210.0)`.

## 2. Comportements qui changent à l'écran (relus en lecture seule)

| Où | Effet |
|---|---|
| Mesures terrain (`service_compute.R:683`, `mod_field_ingest.R:258, 302`) | `aggregate_plot_metrics()` ne compte plus que les arbres vivants : `field_g_ha`, `field_dg_cm`, `field_h_dom_m` et les CV **baissent** sur toute placette contenant des arbres morts, chablis ou coupés. Les projets avec données terrain sont à recalculer. |
| Import QField | `validate_field_data()` refuse désormais un `tree_id` manquant ; un GeoPackage qui passait peut être refusé. Les numéros de ligne signalés sont les vrais. |
| Perspectives IA (`service_rag.R:166`) | `retrieve_knowledge()` lève une erreur si le corpus n'est pas en `mistral:mistral-embed` alors que l'app interroge en `mistral` ; l'app la rattrape déjà (`tryCatch`). Aucun changement si le corpus de prod est bien en Mistral. |
| Export QGIS (`mod_validation_sampling.R:907`) | `project_name` doit respecter `^[A-Za-z0-9_-]+$` : le nom actuel `validation_%Y%m%dT%H%M%S` est conforme. |
| Citations (`service_rag.R:230`) | L'app utilise `format = "markdown"`, non échappé : seul le HTML l'est. Si le markdown est rendu en HTML côté app, l'échapper ou passer à `format = "html"`. |
| RECONFORT | `run_reconfort_dieback()` refuse un `zone_id` non entier et refuse de démarrer si un autre run vivant tient le même dossier de travail. Aucun env conda à reconstruire. |
