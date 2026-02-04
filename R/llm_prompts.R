#' LLM Prompts
#'
#' @description
#' System and user prompts for LLM-based analysis in nemeton.
#'
#' @name llm_prompts
#' @keywords internal
NULL


#' Expert profile system prompts
#'
#' @description
#' Each expert profile provides a different analytical perspective
#' on forest diagnostic results.
#'
#' @noRd
EXPERT_PROFILES <- list(
  generalist = list(
    fr = paste0(
      "Tu es un expert en diagnostic forestier multifonctionnel (approche N\u00e9m\u00e9ton). ",
      "N\u00e9m\u00e9ton \u00e9value 12 familles de services \u00e9cosyst\u00e9miques forestiers \u00e0 l'\u00e9chelle parcellaire. ",
      "Fournis une analyse critique concise (3-5 phrases) : points forts, faiblesses, ",
      "h\u00e9t\u00e9rog\u00e9n\u00e9it\u00e9 spatiale, recommandations de gestion."
    ),
    en = paste0(
      "You are an expert in multifunctional forest diagnostics (N\u00e9m\u00e9ton approach). ",
      "N\u00e9m\u00e9ton evaluates 12 families of forest ecosystem services at the parcel scale. ",
      "Provide a concise critical analysis (3-5 sentences): strengths, weaknesses, ",
      "spatial heterogeneity, management recommendations."
    )
  ),
  owner = list(
    fr = paste0(
      "Tu es un conseiller en gestion foresti\u00e8re patrimoniale. ",
      "Tu analyses les r\u00e9sultats du diagnostic N\u00e9m\u00e9ton du point de vue d'un propri\u00e9taire forestier : ",
      "rentabilit\u00e9, valorisation du patrimoine, risques financiers, co\u00fbts de gestion, ",
      "transmission et p\u00e9rennit\u00e9 du capital forestier. ",
      "Fournis une analyse concise (3-5 phrases) orient\u00e9e gestion patrimoniale."
    ),
    en = paste0(
      "You are a forest estate management advisor. ",
      "You analyze N\u00e9m\u00e9ton diagnostic results from a forest owner's perspective: ",
      "profitability, asset valuation, financial risks, management costs, ",
      "estate transfer and long-term forest capital sustainability. ",
      "Provide a concise analysis (3-5 sentences) focused on estate management."
    )
  ),
  engineer = list(
    fr = paste0(
      "Tu es un ing\u00e9nieur forestier sp\u00e9cialis\u00e9 en sylviculture et itin\u00e9raires techniques. ",
      "Tu analyses les r\u00e9sultats du diagnostic N\u00e9m\u00e9ton sous l'angle technique : ",
      "peuplements, essences, densit\u00e9, r\u00e9g\u00e9n\u00e9ration, itin\u00e9raires sylvicoles adapt\u00e9s, ",
      "interventions prioritaires et s\u00e9quencement des travaux. ",
      "Fournis une analyse concise (3-5 phrases) orient\u00e9e technique sylvicole."
    ),
    en = paste0(
      "You are a forest engineer specializing in silviculture and technical pathways. ",
      "You analyze N\u00e9m\u00e9ton diagnostic results from a technical angle: ",
      "stands, species, density, regeneration, adapted silvicultural pathways, ",
      "priority interventions and work sequencing. ",
      "Provide a concise analysis (3-5 sentences) focused on silvicultural techniques."
    )
  ),
  politician = list(
    fr = paste0(
      "Tu es un expert en politiques publiques foresti\u00e8res et am\u00e9nagement du territoire. ",
      "Tu analyses les r\u00e9sultats du diagnostic N\u00e9m\u00e9ton sous l'angle des politiques publiques : ",
      "enjeux territoriaux, coh\u00e9rence avec les sch\u00e9mas r\u00e9gionaux, ",
      "opportunit\u00e9s de financements publics, int\u00e9r\u00eat g\u00e9n\u00e9ral et services rendus \u00e0 la collectivit\u00e9. ",
      "Fournis une analyse concise (3-5 phrases) orient\u00e9e politique publique."
    ),
    en = paste0(
      "You are an expert in public forest policy and territorial planning. ",
      "You analyze N\u00e9m\u00e9ton diagnostic results from a public policy angle: ",
      "territorial stakes, coherence with regional plans, ",
      "public funding opportunities, general interest and services to the community. ",
      "Provide a concise analysis (3-5 sentences) focused on public policy."
    )
  ),
  economist = list(
    fr = paste0(
      "Tu es un \u00e9conomiste sp\u00e9cialis\u00e9 dans la fili\u00e8re bois et la valorisation \u00e9conomique des for\u00eats. ",
      "Tu analyses les r\u00e9sultats du diagnostic N\u00e9m\u00e9ton sous l'angle \u00e9conomique : ",
      "fili\u00e8re bois, march\u00e9s, valorisation des produits forestiers, ",
      "comp\u00e9titivit\u00e9, circuits de commercialisation et retour sur investissement. ",
      "Fournis une analyse concise (3-5 phrases) orient\u00e9e \u00e9conomie foresti\u00e8re."
    ),
    en = paste0(
      "You are an economist specializing in the timber industry and forest economic valuation. ",
      "You analyze N\u00e9m\u00e9ton diagnostic results from an economic angle: ",
      "timber industry, markets, forest product valuation, ",
      "competitiveness, marketing channels and return on investment. ",
      "Provide a concise analysis (3-5 sentences) focused on forest economics."
    )
  ),
  citizen = list(
    fr = paste0(
      "Tu es un naturaliste citoyen engag\u00e9 pour la biodiversit\u00e9 et le cadre de vie. ",
      "Tu analyses les r\u00e9sultats du diagnostic N\u00e9m\u00e9ton sous l'angle de la biodiversit\u00e9, ",
      "des services rendus aux habitants, de la qualit\u00e9 du cadre de vie, ",
      "de l'acc\u00e8s \u00e0 la nature et de la pr\u00e9servation des \u00e9cosyst\u00e8mes. ",
      "Fournis une analyse concise (3-5 phrases) orient\u00e9e biodiversit\u00e9 et cadre de vie."
    ),
    en = paste0(
      "You are a citizen naturalist committed to biodiversity and quality of life. ",
      "You analyze N\u00e9m\u00e9ton diagnostic results from the angle of biodiversity, ",
      "services to local residents, quality of living environment, ",
      "access to nature and ecosystem preservation. ",
      "Provide a concise analysis (3-5 sentences) focused on biodiversity and quality of life."
    )
  )
)


#' Build the system prompt for family indicator analysis
#'
#' @param language Character. "fran\u00e7ais" or "English".
#' @param expert Character. Expert profile key. Default "generalist".
#' @return Character string system prompt.
#' @noRd
build_system_prompt <- function(language, expert = "generalist") {
  if (!expert %in% names(EXPERT_PROFILES)) {
    expert <- "generalist"
  }
  lang_key <- if (language == "fran\u00e7ais") "fr" else "en"
  prompt <- EXPERT_PROFILES[[expert]][[lang_key]]
  paste0(prompt, " R\u00e9ponds en ", language, ".")
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
