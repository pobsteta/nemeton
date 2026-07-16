# Brief `nemetonshiny` — Archiver le PDF du plan d'action dans `exports/`

**Date** : 2026-07-16
**Repo cible** : `nemetonshiny` (app pur — **aucun changement cœur `nemeton`**).
**Fichier** : `R/mod_action_plan.R`, `output$download_pdf` (≈ ligne 1654-1720).
**Effort** : ~10 lignes, calquées sur un patron déjà en production.

## 1. Constat

Le PDF du plan d'action (`<NomProjet>_action_plan.pdf`) est aujourd'hui un export
**transitoire** : `output$download_pdf` est un `downloadHandler` qui rend le Quarto
dans le fichier temporaire fourni par Shiny (`content = function(file)`) et le
**streame au navigateur**. Rien n'est écrit dans le projet. Le seul artefact
persisté du plan est la **donnée** (`<project_path>/data/action_plan.json`,
`service_action_plan.R:90`), d'où le PDF est régénéré à la volée.

Demande : en **archiver une copie** dans le cache du projet, comme le fait déjà le
rapport de synthèse.

## 2. Le patron existe déjà (à copier, pas à inventer)

`R/mod_synthesis.R` (≈ 1039-1049) archive son PDF dans `exports/` juste après le
rendu, avant le toast de fin :

```r
# Also save a copy in the project's exports/ directory
project_path <- project$path
if (!is.null(project_path) && dir.exists(project_path)) {
  exports_dir <- file.path(project_path, "exports")
  if (!dir.exists(exports_dir)) dir.create(exports_dir, showWarnings = FALSE)
  export_name <- gsub("[^a-zA-Z0-9_-]", "_", project$metadata$name %||% "nemeton_report")
  export_file <- file.path(exports_dir, paste0(export_name, "_report.pdf"))
  file.copy(file, export_file, overwrite = TRUE)
}
```

**Cible retenue** : `<project_path>/exports/` (cohérent avec la synthèse), suffixe
`_action_plan.pdf`. *Pas* `cache/` — `exports/` est déjà la maison des livrables
PDF ; `cache/` est réservé aux intermédiaires recalculables (rasters, `.nc`, gpkg).

## 3. Patch — `R/mod_action_plan.R`, dans `content = function(file)`

Le bloc de rendu est un `result <- tryCatch(generate_action_plan_pdf(...), …)`.
La copie doit se faire **uniquement en cas de succès** (le PDF existe et n'est pas
le marqueur d'échec). Insérer, **juste après le `if (is.null(result)) { … }`**
(donc dans le chemin où `result` n'est PAS `NULL`, ≈ après la ligne 1720) :

```r
        # Archive une copie dans exports/ du projet (parité avec le rapport de
        # synthèse). Best-effort : un échec de copie ne casse pas le download.
        project_path <- project$path
        if (!is.null(project_path) && dir.exists(project_path)) {
          exports_dir <- file.path(project_path, "exports")
          if (!dir.exists(exports_dir)) {
            dir.create(exports_dir, recursive = TRUE, showWarnings = FALSE)
          }
          export_name <- gsub("[^a-zA-Z0-9_-]", "_",
                              project$metadata$name %||% "nemeton_action_plan")
          export_file <- file.path(exports_dir, paste0(export_name, "_action_plan.pdf"))
          tryCatch(
            file.copy(file, export_file, overwrite = TRUE),
            error = function(e) cli::cli_warn(
              "Action plan PDF archive failed: {conditionMessage(e)}"))
        }
```

### Points de vigilance

- **`project` est déjà en portée** dans le `content` (`project <- app_state$current_project`,
  ≈ ligne 1679). Ne pas le re-déclarer, réutiliser la variable existante.
- **Placer la copie dans le chemin succès** : après le `writeLines` du marqueur
  d'échec (`if (is.null(result))`), pas avant — sinon on archiverait le fichier
  texte « PDF generation failed ». Concrètement : le bloc va **après** la fermeture
  du `if (is.null(result)) { … }`, là où `result` est non-`NULL`.
- **`overwrite = TRUE`** : ré-exporter un projet remplace l'archive précédente
  (comportement identique à la synthèse — un seul PDF courant par projet).
- **Best-effort** : la copie est enveloppée d'un `tryCatch` — un disque plein ou un
  chemin projet en lecture seule n'empêche jamais le téléchargement navigateur, qui
  reste la fonction première du handler.

## 4. Cohérence UX (optionnel)

Le rapport de synthèse affiche une notif de succès après archivage. Le plan
d'action utilise déjà un toast client (`nemetonHideDownloadToast`). Si tu veux
signaler l'archivage, ajouter au message de succès existant un « (copie enregistrée
dans le projet) » via une clé i18n `action_plan_pdf_archived` (FR/EN) — sinon le
comportement silencieux suffit (le fichier apparaît dans `exports/`).

## 5. Tests

- `testServer()` : invoquer `output$download_pdf` avec un projet dont `path` pointe
  vers un `tempdir()`, mocker `generate_action_plan_pdf` pour écrire un PDF factice
  dans `output_file`, puis **vérifier que `<path>/exports/<nom>_action_plan.pdf`
  existe** après l'appel. Cas d'échec : `generate_action_plan_pdf` lève → aucune
  copie, pas de crash. Cas `project$path = NULL` → pas de copie, download OK.

## 6. Hors-scope

- Aucun horodatage / versioning des exports (un PDF courant par projet, écrasé).
  Si un historique est souhaité plus tard, suffixer par date — chantier distinct.
- Aucun changement au **contenu** du PDF ni à `generate_action_plan_pdf()`
  (`service_export.R`) : cette livraison ne fait qu'**archiver le fichier déjà rendu**.
- **Aucun changement cœur `nemeton`** : rien à releaser côté ce repo.
