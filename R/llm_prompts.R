#' LLM Prompts
#'
#' @description
#' System and user prompts for LLM-based analysis in nemeton.
#'
#' @name llm_prompts
#' @keywords internal
NULL


#' Build the system prompt for family indicator analysis
#'
#' @param language Character. "français" or "English".
#' @return Character string system prompt.
#' @noRd
build_system_prompt <- function(language) {
  paste0(
    "Tu es un expert en diagnostic forestier multifonctionnel (approche N\u00e9m\u00e9ton). ",
    "N\u00e9m\u00e9ton \u00e9value 12 familles de services \u00e9cosyst\u00e9miques forestiers \u00e0 l'\u00e9chelle parcellaire. ",
    "Fournis une analyse critique concise (3-5 phrases) : points forts, faiblesses, ",
    "h\u00e9t\u00e9rog\u00e9n\u00e9it\u00e9 spatiale, recommandations de gestion. R\u00e9ponds en ", language, "."
  )
}


#' Build analysis prompt for AI generation
#'
#' @param family_config List. Family configuration from INDICATOR_FAMILIES.
#' @param ind_data data.frame. Indicator data for the family.
#' @param language Character. "fran\u00e7ais" or "English".
#' @return Character string prompt.
#' @noRd
build_analysis_prompt <- function(family_config, ind_data, language) {
  if (inherits(ind_data, "sf")) {
    ind_data <- sf::st_drop_geometry(ind_data)
  }

  family_name <- if (language == "fran\u00e7ais") family_config$name_fr else family_config$name_en
  ind_cols <- get_indicator_cols(ind_data)
  n_parcels <- nrow(ind_data)

  # Build per-indicator stats summary
  stats_lines <- vapply(ind_cols, function(col) {
    vals <- ind_data[[col]]
    vals_clean <- vals[!is.na(vals)]
    n <- length(vals_clean)
    if (n == 0) return(paste0("- ", col, ": no data"))
    mn <- round(min(vals_clean), 3)
    mx <- round(max(vals_clean), 3)
    avg <- round(mean(vals_clean), 3)
    sd_val <- if (n > 1) round(stats::sd(vals_clean), 3) else 0
    cv <- if (avg != 0) round(abs(sd_val / avg) * 100, 1) else 0
    paste0("- ", col, ": n=", n, ", min=", mn, ", max=", mx,
           ", mean=", avg, ", sd=", sd_val, ", CV=", cv, "%")
  }, character(1))

  paste0(
    "Analyse les r\u00e9sultats de la famille ", family_name,
    " (code: ", family_config$code, ") pour ", n_parcels, " parcelles.\n\n",
    "Statistiques des indicateurs :\n",
    paste(stats_lines, collapse = "\n")
  )
}
