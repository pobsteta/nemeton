#!/usr/bin/env Rscript
# =============================================================================
# Exécution complète des Tutoriels Nemeton (01-04)
# =============================================================================
# Ce script exécute tout le code R des tutoriels en mode non-interactif.
# Les exercices avec des blancs à compléter sont ignorés.
#
# Usage:
#   Rscript inst/scripts/run_tutorials.R [options]
#
# Options:
#   --tutorial=01    Exécuter seulement le tutoriel 01
#   --dry-run        Afficher le code sans l'exécuter
#   --verbose        Afficher chaque expression avant exécution
# =============================================================================

# Parsing des arguments
args <- commandArgs(trailingOnly = TRUE)
TUTORIAL_FILTER <- NULL
DRY_RUN <- FALSE
VERBOSE <- FALSE

for (arg in args) {
  if (grepl("^--tutorial=", arg)) {
    TUTORIAL_FILTER <- sub("--tutorial=", "", arg)
  } else if (arg == "--dry-run") {
    DRY_RUN <- TRUE
  } else if (arg == "--verbose") {
    VERBOSE <- TRUE
  }
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║     EXÉCUTION DES TUTORIELS NEMETON (01-04)                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

if (DRY_RUN) cat(">>> MODE DRY-RUN (pas d'exécution réelle) <<<\n\n")

# =============================================================================
# Configuration
# =============================================================================
tutorials_dir <- "inst/tutorials"
temp_dir <- tempdir()

# Configuration des timeouts réseau (5 minutes)
NETWORK_TIMEOUT <- 300

cat("Configuration réseau:\n")
cat(sprintf("  Timeout: %d secondes\n", NETWORK_TIMEOUT))

options(
  timeout = NETWORK_TIMEOUT,
  HTTPUserAgent = "nemeton-tutorial/1.0"
)

# Configuration httr si disponible
if (requireNamespace("httr", quietly = TRUE)) {
  httr::set_config(httr::timeout(NETWORK_TIMEOUT))
  cat("  httr: configuré\n")
}

# Configuration curl si disponible
if (requireNamespace("curl", quietly = TRUE)) {
  Sys.setenv(
    CURL_SSL_BACKEND = "openssl",
    R_CURL_TIMEOUT = as.character(NETWORK_TIMEOUT)
  )
  cat("  curl: configuré\n")
}
cat("\n")

# Créer le répertoire de données si nécessaire
if (requireNamespace("rappdirs", quietly = TRUE)) {
  data_dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
} else {
  data_dir <- file.path(path.expand("~"), "nemeton_tutorial_data")
}
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
cat("Répertoire de données:", data_dir, "\n\n")

# Liste des tutoriels
tutorials <- c(
  "01-acquisition",
  "02-lidar",
  "03-terrain",
  "04-ecological"
)

# Filtrer si demandé
if (!is.null(TUTORIAL_FILTER)) {
  tutorials <- tutorials[grepl(TUTORIAL_FILTER, tutorials)]
  cat("Filtre appliqué:", TUTORIAL_FILTER, "\n")
  cat("Tutoriels à exécuter:", paste(tutorials, collapse = ", "), "\n\n")
}

# =============================================================================
# Fonction pour extraire le code exécutable d'un Rmd
# =============================================================================
extract_executable_code <- function(rmd_file) {
  lines <- readLines(rmd_file, warn = FALSE)

  # Variables de parsing
  in_chunk <- FALSE
  chunk_options <- ""
  chunk_content <- character(0)
  all_code <- character(0)
  chunk_count <- 0
  skipped_count <- 0

  for (i in seq_along(lines)) {
    line <- lines[i]

    # Début de chunk R
    if (grepl("^```\\{r", line)) {
      in_chunk <- TRUE
      chunk_options <- line
      chunk_content <- character(0)
      next
    }

    # Fin de chunk
    if (in_chunk && grepl("^```$", line)) {
      in_chunk <- FALSE
      chunk_count <- chunk_count + 1

      # Analyser les options du chunk
      is_exercise <- grepl("exercise\\s*=\\s*TRUE", chunk_options)
      is_setup <- grepl("-setup", chunk_options)
      is_eval_false <- grepl("eval\\s*=\\s*FALSE", chunk_options)
      is_echo_false <- grepl("echo\\s*=\\s*FALSE", chunk_options) && !grepl("exercise", chunk_options)

      # Vérifier si le code contient des blancs à compléter
      code_text <- paste(chunk_content, collapse = "\n")
      has_blanks <- grepl("_____|# À compléter|# TODO|# Complétez", code_text)

      # Vérifier si c'est du code interactif learnr
      is_interactive <- grepl("question\\(|answer\\(|quiz\\(", code_text)

      # Décider si on inclut ce chunk
      should_include <- TRUE
      skip_reason <- ""

      if (is_exercise && has_blanks) {
        should_include <- FALSE
        skip_reason <- "exercice avec blancs"
      } else if (is_interactive) {
        should_include <- FALSE
        skip_reason <- "code interactif"
      } else if (is_eval_false && !is_setup) {
        should_include <- FALSE
        skip_reason <- "eval=FALSE"
      }

      if (should_include && length(chunk_content) > 0) {
        # Extraire le nom du chunk pour le commentaire
        chunk_name <- sub(".*\\{r\\s*([^,}]+).*", "\\1", chunk_options)
        if (chunk_name == chunk_options) chunk_name <- paste0("chunk_", chunk_count)

        all_code <- c(all_code,
                      paste0("\n# === ", chunk_name, " ==="),
                      chunk_content)
      } else {
        skipped_count <- skipped_count + 1
      }

      next
    }

    # Contenu du chunk
    if (in_chunk) {
      chunk_content <- c(chunk_content, line)
    }
  }

  cat(sprintf("    Chunks: %d total, %d ignorés\n", chunk_count, skipped_count))

  return(all_code)
}

# =============================================================================
# Fonction pour exécuter le code avec gestion d'erreurs
# =============================================================================
run_tutorial_code <- function(code_lines, tutorial_name) {
  # Créer l'environnement d'exécution
  env <- new.env(parent = globalenv())

  # Pré-charger les packages courants dans l'environnement
  suppressPackageStartupMessages({
    if (requireNamespace("sf", quietly = TRUE)) library(sf)
    if (requireNamespace("terra", quietly = TRUE)) library(terra)
  })

  # Assigner data_dir dans l'environnement
  env$data_dir <- data_dir

  # Joindre les lignes et parser
  code_text <- paste(code_lines, collapse = "\n")

  # Nettoyer le code
  # Retirer les appels library(learnr) et gradethis
  code_text <- gsub("library\\(learnr\\)", "# library(learnr)", code_text)
  code_text <- gsub("library\\(gradethis\\)", "# library(gradethis)", code_text)
  code_text <- gsub("gradethis::gradethis_setup\\(\\)", "# gradethis_setup()", code_text)
  code_text <- gsub("gradethis_setup\\(\\)", "# gradethis_setup()", code_text)

  # Parser le code
  parsed <- tryCatch({
    parse(text = code_text)
  }, error = function(e) {
    cat("    ERREUR DE PARSING:", conditionMessage(e), "\n")
    return(NULL)
  })

  if (is.null(parsed)) return(FALSE)

  n_expr <- length(parsed)
  cat(sprintf("    Expressions à exécuter: %d\n", n_expr))

  errors <- character(0)
  warnings_list <- character(0)
  success_count <- 0

  # Barre de progression
  pb_width <- 50

  for (i in seq_along(parsed)) {
    expr <- parsed[[i]]
    expr_text <- paste(deparse(expr), collapse = " ")
    expr_preview <- substr(gsub("\\s+", " ", expr_text), 1, 60)

    # Progression
    pct <- floor(i / n_expr * 100)
    filled <- floor(i / n_expr * pb_width)
    bar <- paste0("[", paste(rep("=", filled), collapse = ""),
                  paste(rep(" ", pb_width - filled), collapse = ""), "]")
    cat(sprintf("\r    %s %3d%% ", bar, pct))

    if (VERBOSE) {
      cat(sprintf("\n    [%d/%d] %s\n", i, n_expr, expr_preview))
    }

    if (DRY_RUN) {
      success_count <- success_count + 1
      next
    }

    # Exécuter l'expression
    result <- tryCatch({
      withCallingHandlers({
        eval(expr, envir = env)
        "OK"
      }, warning = function(w) {
        if (!grepl("package|namespace|replacing|masked", conditionMessage(w))) {
          warnings_list <<- c(warnings_list, conditionMessage(w))
        }
        invokeRestart("muffleWarning")
      }, message = function(m) {
        # Ignorer les messages
        invokeRestart("muffleMessage")
      })
    }, error = function(e) {
      paste("ERREUR:", conditionMessage(e))
    })

    if (is.character(result) && startsWith(result, "ERREUR")) {
      errors <- c(errors, paste0("\n    [", i, "] ", expr_preview, "\n        ", result))
    } else {
      success_count <- success_count + 1
    }
  }

  cat("\n")

  # Rapport
  cat(sprintf("    Résultat: %d/%d expressions OK\n", success_count, n_expr))

  if (length(warnings_list) > 0) {
    cat(sprintf("    Warnings: %d\n", length(warnings_list)))
  }

  if (length(errors) > 0) {
    cat("    ERREURS:\n")
    for (err in errors) {
      cat(err, "\n")
    }
    return(FALSE)
  }

  return(TRUE)
}

# =============================================================================
# Boucle principale
# =============================================================================
results <- list()
start_time <- Sys.time()

for (tuto in tutorials) {
  tuto_start <- Sys.time()

  cat("\n")
  cat("┌─────────────────────────────────────────────────────────────┐\n")
  cat(sprintf("│  %-57s  │\n", toupper(tuto)))
  cat("└─────────────────────────────────────────────────────────────┘\n")

  rmd_file <- file.path(tutorials_dir, tuto, paste0(tuto, ".Rmd"))

  if (!file.exists(rmd_file)) {
    cat("    ERREUR: Fichier non trouvé:", rmd_file, "\n")
    results[[tuto]] <- list(status = "NOT_FOUND", time = 0)
    next
  }

  # 1. Extraire le code
  cat("    Extraction du code...\n")
  code_lines <- extract_executable_code(rmd_file)

  if (length(code_lines) == 0) {
    cat("    Aucun code à exécuter\n")
    results[[tuto]] <- list(status = "NO_CODE", time = 0)
    next
  }

  # Sauvegarder le code extrait pour debug
  code_file <- file.path(temp_dir, paste0(tuto, "_exec.R"))
  writeLines(code_lines, code_file)
  cat(sprintf("    Code extrait: %s (%d lignes)\n", code_file, length(code_lines)))

  # 2. Exécuter le code
  cat("    Exécution...\n")
  success <- run_tutorial_code(code_lines, tuto)

  tuto_time <- as.numeric(difftime(Sys.time(), tuto_start, units = "secs"))

  results[[tuto]] <- list(
    status = ifelse(success, "OK", "ERRORS"),
    time = tuto_time,
    lines = length(code_lines)
  )

  cat(sprintf("    Temps: %.1f secondes\n", tuto_time))
}

# =============================================================================
# Résumé final
# =============================================================================
total_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                        RÉSUMÉ                                 ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Tableau résumé
cat(sprintf("%-20s %-10s %10s %10s\n", "Tutorial", "Status", "Lignes", "Temps"))
cat(paste(rep("-", 52), collapse = ""), "\n")

for (tuto in names(results)) {
  res <- results[[tuto]]
  cat(sprintf("%-20s %-10s %10d %9.1fs\n",
              tuto,
              res$status,
              ifelse(is.null(res$lines), 0, res$lines),
              res$time))
}

cat(paste(rep("-", 52), collapse = ""), "\n")
cat(sprintf("%-20s %-10s %10s %9.1fs\n", "TOTAL", "", "", total_time))

# Statistiques
n_ok <- sum(sapply(results, function(x) x$status == "OK"))
n_total <- length(results)

cat(sprintf("\nRésultat global: %d/%d tutoriels OK\n", n_ok, n_total))

# Vérifier les fichiers produits
cat("\nFichiers produits:\n")
if (dir.exists(data_dir)) {
  files <- list.files(data_dir, recursive = TRUE)
  if (length(files) > 0) {
    for (f in head(files, 20)) {
      size <- file.size(file.path(data_dir, f))
      cat(sprintf("  %-40s %s\n", f, format(size, big.mark = " ")))
    }
    if (length(files) > 20) {
      cat(sprintf("  ... et %d autres fichiers\n", length(files) - 20))
    }
  } else {
    cat("  (aucun fichier)\n")
  }
}

cat("\n")
if (n_ok == n_total) {
  cat("*** TOUS LES TUTORIELS ONT ÉTÉ EXÉCUTÉS AVEC SUCCÈS ***\n\n")
  quit(status = 0)
} else {
  cat("*** CERTAINS TUTORIELS ONT ÉCHOUÉ ***\n\n")
  quit(status = 1)
}
