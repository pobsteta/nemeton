#!/usr/bin/env Rscript
# =============================================================================
# Nemeton Tutorial Runner
# =============================================================================
# Execute R code from learnr tutorials in non-interactive mode.
# Exercises with blanks to complete are automatically skipped.
#
# Usage:
#   Rscript inst/scripts/run_tutorials.R [options]
#
# Options:
#   --tutorial=01    Run only tutorial matching pattern (e.g., 01, 02, lidar)
#   --dry-run        Display code without executing
#   --verbose        Show each expression before execution
#   --help           Show this help message
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration Constants
# -----------------------------------------------------------------------------
NETWORK_TIMEOUT <- 300L  # 5 minutes
TUTORIALS_DIR <- "inst/tutorials"
MAX_RETRIES <- 3L
RETRY_DELAY <- 10L

TUTORIAL_LIST <- c(

"01-acquisition",
"02-lidar",
"03-terrain",
"04-ecological"
)

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------
parse_arguments <- function() {
args <- commandArgs(trailingOnly = TRUE)

config <- list(
  tutorial_filter = NULL,
  dry_run = FALSE,
  verbose = FALSE
)

for (arg in args) {
  if (arg == "--help") {
    show_help()
    quit(status = 0)
  } else if (grepl("^--tutorial=", arg)) {
    config$tutorial_filter <- sub("^--tutorial=", "", arg)
  } else if (arg == "--dry-run") {
    config$dry_run <- TRUE
  } else if (arg == "--verbose") {
    config$verbose <- TRUE
  } else {
    cat("Unknown option:", arg, "\n")
    show_help()
    quit(status = 1)
  }
}

config
}

show_help <- function() {
cat("
Usage: Rscript inst/scripts/run_tutorials.R [options]

Options:
--tutorial=PATTERN  Run only tutorials matching PATTERN
--dry-run           Display extracted code without executing
--verbose           Show each expression before execution
--help              Show this help message

Examples:
Rscript inst/scripts/run_tutorials.R                  # Run all tutorials
Rscript inst/scripts/run_tutorials.R --tutorial=01   # Run tutorial 01 only
Rscript inst/scripts/run_tutorials.R --dry-run       # Extract code only
")
}

# -----------------------------------------------------------------------------
# UI Helpers
# -----------------------------------------------------------------------------
print_banner <- function(text, char = "=") {
width <- 65
border <- paste(rep(char, width), collapse = "")
cat("\n", border, "\n", sep = "")
cat("  ", text, "\n", sep = "")
cat(border, "\n\n", sep = "")
}

print_section <- function(text) {
cat("\n--- ", text, " ", paste(rep("-", 50 - nchar(text)), collapse = ""), "\n", sep = "")
}

print_progress_bar <- function(current, total, width = 50) {
pct <- floor(current / total * 100)
filled <- floor(current / total * width)
bar <- paste0(
  "[",
  paste(rep("=", filled), collapse = ""),
  paste(rep(" ", width - filled), collapse = ""),
  "]"
)
cat(sprintf("\r    %s %3d%% ", bar, pct))
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------
configure_network <- function(timeout) {
cat("Network configuration:\n")
cat(sprintf("  Timeout: %d seconds\n", timeout))

# Base R options
options(
  timeout = timeout,
  HTTPUserAgent = "nemeton-tutorial/1.0"
)

# httr configuration
if (requireNamespace("httr", quietly = TRUE)) {
  httr::set_config(httr::config(
    connecttimeout = timeout,
    timeout = timeout
  ))
  cat("  httr: configured\n")
}

# httr2 configuration
if (requireNamespace("httr2", quietly = TRUE)) {
  options(
    httr2_timeout = timeout,
    httr2_retry_max_wait = timeout
  )
  cat("  httr2: configured\n")
}

# curl environment
if (requireNamespace("curl", quietly = TRUE)) {
  Sys.setenv(
    CURL_SSL_BACKEND = "openssl",
    R_LIBCURL_SSL_REVOKE_BEST_EFFORT = "true"
  )
  options(
    curl_timeout = timeout,
    curl_connecttimeout = timeout
  )
  cat("  curl: configured\n")
}

# GDAL configuration for sf/terra
Sys.setenv(
  GDAL_HTTP_TIMEOUT = as.character(timeout),
  GDAL_HTTP_CONNECTTIMEOUT = as.character(timeout),
  GDAL_HTTP_MAX_RETRY = "5",
  GDAL_HTTP_RETRY_DELAY = "5",
  VSI_CURL_CACHE_SIZE = "100000000",
  CPL_CURL_VERBOSE = "NO",
  CPL_VSIL_CURL_USE_HEAD = "NO"
)
cat("  GDAL: configured\n")

cat("\n")
}

configure_terra_gdal <- function(timeout) {
if (requireNamespace("terra", quietly = TRUE)) {
  tryCatch({
    terra::setGDALconfig("GDAL_HTTP_TIMEOUT", as.character(timeout))
    terra::setGDALconfig("GDAL_HTTP_CONNECTTIMEOUT", as.character(timeout))
    terra::setGDALconfig("GDAL_HTTP_MAX_RETRY", "5")
    terra::setGDALconfig("GDAL_HTTP_RETRY_DELAY", "5")
  }, error = function(e) NULL)
}
}

# -----------------------------------------------------------------------------
# Data Directory Setup
# -----------------------------------------------------------------------------
setup_data_directory <- function() {
if (requireNamespace("rappdirs", quietly = TRUE)) {
  data_dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
} else {
  data_dir <- file.path(path.expand("~"), "nemeton_tutorial_data")
}

dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
cat("Data directory:", data_dir, "\n\n")

data_dir
}

# -----------------------------------------------------------------------------
# Code Extraction from Rmd
# -----------------------------------------------------------------------------
extract_executable_code <- function(rmd_file) {
lines <- readLines(rmd_file, warn = FALSE)

state <- list(
  in_chunk = FALSE,
  chunk_options = "",
  chunk_content = character(0),
  all_code = character(0),
  chunk_count = 0L,
  skipped_count = 0L
)

for (line in lines) {
  state <- process_line(line, state)
}

cat(sprintf("    Chunks: %d total, %d skipped\n",
            state$chunk_count, state$skipped_count))

state$all_code
}

process_line <- function(line, state) {
# Start of R chunk
if (grepl("^```\\{r", line)) {
  state$in_chunk <- TRUE
  state$chunk_options <- line
  state$chunk_content <- character(0)
  return(state)
}

# End of chunk
if (state$in_chunk && grepl("^```$", line)) {
  state$in_chunk <- FALSE
  state$chunk_count <- state$chunk_count + 1L
  state <- finalize_chunk(state)
  return(state)
}

# Inside chunk - collect content
if (state$in_chunk) {
  state$chunk_content <- c(state$chunk_content, line)
}

state
}

finalize_chunk <- function(state) {
opts <- state$chunk_options
code_text <- paste(state$chunk_content, collapse = "\n")

# Determine if chunk should be included
skip_info <- should_skip_chunk(opts, code_text)

if (!skip_info$skip && length(state$chunk_content) > 0) {
  chunk_name <- extract_chunk_name(opts, state$chunk_count)
  state$all_code <- c(
    state$all_code,
    paste0("\n# === ", chunk_name, " ==="),
    state$chunk_content
  )
} else {
  state$skipped_count <- state$skipped_count + 1L
}

state
}

should_skip_chunk <- function(opts, code_text) {
# Check chunk options
is_exercise <- grepl("exercise\\s*=\\s*TRUE", opts)
is_eval_false <- grepl("eval\\s*=\\s*FALSE", opts)
is_setup <- grepl("-setup", opts)

# Check code content
has_blanks <- grepl("_____|# [ÀA] compl[eé]ter|# TODO|# Complétez", code_text)
is_interactive <- grepl("question\\(|answer\\(|quiz\\(", code_text)

# Decision logic
if (is_exercise && has_blanks) {
  return(list(skip = TRUE, reason = "exercise with blanks"))
}
if (is_interactive) {
  return(list(skip = TRUE, reason = "interactive code"))
}
if (is_eval_false && !is_setup) {
  return(list(skip = TRUE, reason = "eval=FALSE"))
}

list(skip = FALSE, reason = "")
}

extract_chunk_name <- function(opts, fallback_num) {
name <- sub(".*\\{r\\s*([^,}]+).*", "\\1", opts)
if (name == opts) {
  paste0("chunk_", fallback_num)
} else {
  trimws(name)
}
}

# -----------------------------------------------------------------------------
# Code Preprocessing
# -----------------------------------------------------------------------------
preprocess_code <- function(code_text) {
# Remove learnr-specific calls
patterns <- c(
  "library\\(learnr\\)" = "# library(learnr)",
  "library\\(gradethis\\)" = "# library(gradethis)",
  "gradethis::gradethis_setup\\(\\)" = "# gradethis_setup()",
  "gradethis_setup\\(\\)" = "# gradethis_setup()"
)

for (pattern in names(patterns)) {
  code_text <- gsub(pattern, patterns[[pattern]], code_text)
}

code_text
}

# -----------------------------------------------------------------------------
# Code Execution
# -----------------------------------------------------------------------------
run_tutorial_code <- function(code_lines, tutorial_name, config, data_dir) {
# Create execution environment
env <- new.env(parent = globalenv())
env$data_dir <- data_dir

# Load common packages
load_packages()

# Parse code
code_text <- preprocess_code(paste(code_lines, collapse = "\n"))

parsed <- tryCatch(
  parse(text = code_text),
  error = function(e) {
    cat("    PARSE ERROR:", conditionMessage(e), "\n")
    NULL
  }
)

if (is.null(parsed)) return(FALSE)

n_expr <- length(parsed)
cat(sprintf("    Expressions to execute: %d\n", n_expr))

# Execute expressions
results <- execute_expressions(parsed, env, config, n_expr)

# Report results
cat("\n")
report_execution_results(results, n_expr)

length(results$errors) == 0
}

load_packages <- function() {
suppressPackageStartupMessages({
  if (requireNamespace("sf", quietly = TRUE)) library(sf)
  if (requireNamespace("terra", quietly = TRUE)) {
    library(terra)
    configure_terra_gdal(NETWORK_TIMEOUT)
  }
})
}

execute_expressions <- function(parsed, env, config, n_expr) {
errors <- character(0)
warnings_list <- character(0)
success_count <- 0L

for (i in seq_along(parsed)) {
  expr <- parsed[[i]]
  expr_preview <- get_expression_preview(expr)

  # Show progress
  print_progress_bar(i, n_expr)

  if (config$verbose) {
    cat(sprintf("\n    [%d/%d] %s\n", i, n_expr, expr_preview))
  }

  if (config$dry_run) {
    success_count <- success_count + 1L
    next
  }

  # Execute with retry for network errors
  result <- execute_with_retry(expr, env, i, expr_preview)

  if (result$success) {
    success_count <- success_count + 1L
    warnings_list <- c(warnings_list, result$warnings)
  } else {
    errors <- c(errors, result$error)
  }
}

list(
  success_count = success_count,
  errors = errors,
  warnings = warnings_list
)
}

get_expression_preview <- function(expr, max_len = 60) {
expr_text <- paste(deparse(expr), collapse = " ")
expr_text <- gsub("\\s+", " ", expr_text)
substr(expr_text, 1, max_len)
}

execute_with_retry <- function(expr, env, index, preview) {
for (attempt in seq_len(MAX_RETRIES)) {
  result <- execute_single_expression(expr, env)

  # Check for network error
  is_network_error <- !result$success &&
    grepl("Timeout|timeout|curl|HTTP|Failed to connect|Connection refused",
          result$error, ignore.case = TRUE)

  if (result$success || !is_network_error || attempt == MAX_RETRIES) {
    if (!result$success) {
      result$error <- paste0("\n    [", index, "] ", preview, "\n        ", result$error)
    }
    return(result)
  }

  # Retry after delay
  cat(sprintf("\n    [RETRY %d/%d] Network error, retrying in %ds...\n",
              attempt, MAX_RETRIES, RETRY_DELAY))
  Sys.sleep(RETRY_DELAY)
}
}

execute_single_expression <- function(expr, env) {
warnings_collected <- character(0)

result <- tryCatch(
  withCallingHandlers(
    {
      eval(expr, envir = env)
      list(success = TRUE, error = NULL)
    },
    warning = function(w) {
      msg <- conditionMessage(w)
      if (!grepl("package|namespace|replacing|masked", msg)) {
        warnings_collected <<- c(warnings_collected, msg)
      }
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      invokeRestart("muffleMessage")
    }
  ),
  error = function(e) {
    list(success = FALSE, error = paste("ERROR:", conditionMessage(e)))
  }
)

result$warnings <- warnings_collected
result
}

report_execution_results <- function(results, n_expr) {
cat(sprintf("    Result: %d/%d expressions OK\n",
            results$success_count, n_expr))

if (length(results$warnings) > 0) {
  cat(sprintf("    Warnings: %d\n", length(results$warnings)))
}

if (length(results$errors) > 0) {
  cat("    ERRORS:\n")
  for (err in results$errors) {
    cat(err, "\n")
  }
}
}

# -----------------------------------------------------------------------------
# Tutorial Execution
# -----------------------------------------------------------------------------
run_single_tutorial <- function(tutorial_name, config, data_dir) {
cat("\n")
cat("+", paste(rep("-", 63), collapse = ""), "+\n", sep = "")
cat(sprintf("|  %-60s |\n", toupper(tutorial_name)))
cat("+", paste(rep("-", 63), collapse = ""), "+\n", sep = "")

rmd_file <- file.path(TUTORIALS_DIR, tutorial_name, paste0(tutorial_name, ".Rmd"))

if (!file.exists(rmd_file)) {
  cat("    ERROR: File not found:", rmd_file, "\n")
  return(list(status = "NOT_FOUND", time = 0, lines = 0))
}

start_time <- Sys.time()

# Extract code
cat("    Extracting code...\n")
code_lines <- extract_executable_code(rmd_file)

if (length(code_lines) == 0) {
  cat("    No code to execute\n")
  return(list(status = "NO_CODE", time = 0, lines = 0))
}

# Save extracted code for debugging
temp_file <- file.path(tempdir(), paste0(tutorial_name, "_exec.R"))
writeLines(code_lines, temp_file)
cat(sprintf("    Extracted code: %s (%d lines)\n", temp_file, length(code_lines)))

# Execute code
cat("    Executing...\n")
success <- run_tutorial_code(code_lines, tutorial_name, config, data_dir)

elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
cat(sprintf("    Time: %.1f seconds\n", elapsed))

list(
  status = if (success) "OK" else "ERRORS",
  time = elapsed,
  lines = length(code_lines)
)
}

# -----------------------------------------------------------------------------
# Summary Report
# -----------------------------------------------------------------------------
print_summary <- function(results, total_time, data_dir) {
print_banner("SUMMARY")

# Results table
cat(sprintf("%-20s %-10s %10s %10s\n", "Tutorial", "Status", "Lines", "Time"))
cat(paste(rep("-", 52), collapse = ""), "\n")

for (name in names(results)) {
  res <- results[[name]]
  cat(sprintf("%-20s %-10s %10d %9.1fs\n",
              name, res$status,
              if (is.null(res$lines)) 0 else res$lines,
              res$time))
}

cat(paste(rep("-", 52), collapse = ""), "\n")
cat(sprintf("%-20s %-10s %10s %9.1fs\n", "TOTAL", "", "", total_time))

# Statistics
n_ok <- sum(vapply(results, function(x) x$status == "OK", logical(1)))
n_total <- length(results)
cat(sprintf("\nGlobal result: %d/%d tutorials OK\n", n_ok, n_total))

# List produced files
print_produced_files(data_dir)

# Final message
cat("\n")
if (n_ok == n_total) {
  cat("*** ALL TUTORIALS EXECUTED SUCCESSFULLY ***\n\n")
} else {
  cat("*** SOME TUTORIALS FAILED ***\n\n")
}

n_ok == n_total
}

print_produced_files <- function(data_dir) {
cat("\nProduced files:\n")

if (!dir.exists(data_dir)) {
  cat("  (no directory)\n")
  return()
}

files <- list.files(data_dir, recursive = TRUE)

if (length(files) == 0) {
  cat("  (no files)\n")
  return()
}

max_display <- 20
for (f in head(files, max_display)) {
  size <- file.size(file.path(data_dir, f))
  cat(sprintf("  %-40s %s\n", f, format(size, big.mark = " ")))
}

if (length(files) > max_display) {
  cat(sprintf("  ... and %d more files\n", length(files) - max_display))
}
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------
main <- function() {
# Parse arguments
config <- parse_arguments()

# Print header
print_banner("NEMETON TUTORIAL RUNNER")

if (config$dry_run) {
  cat(">>> DRY-RUN MODE (no actual execution) <<<\n\n")
}

# Setup
configure_network(NETWORK_TIMEOUT)
data_dir <- setup_data_directory()

# Filter tutorials if requested
tutorials <- TUTORIAL_LIST
if (!is.null(config$tutorial_filter)) {
  tutorials <- tutorials[grepl(config$tutorial_filter, tutorials)]
  cat("Filter applied:", config$tutorial_filter, "\n")
  cat("Tutorials to run:", paste(tutorials, collapse = ", "), "\n\n")
}

if (length(tutorials) == 0) {
  cat("No tutorials match the filter.\n")
  quit(status = 1)
}

# Run tutorials
results <- list()
start_time <- Sys.time()

for (tutorial in tutorials) {
  results[[tutorial]] <- run_single_tutorial(tutorial, config, data_dir)
}

# Summary
total_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
success <- print_summary(results, total_time, data_dir)

quit(status = if (success) 0 else 1)
}

# Run main function
main()
