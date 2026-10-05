#' @keywords internal
#' @importFrom stats sd runif
#' @importFrom graphics plot.new text
#' @importFrom glue glue
"_PACKAGE"

#' nemeton: Systemic Forest Analysis Using the Nemeton Method
#'
#' @description
#' The \pkg{nemeton} package implements the Nemeton method for comprehensive
#' forest ecosystem analysis. It provides tools to calculate, normalize, and
#' visualize multi-family biophysical indicators across 12 ecosystem service
#' dimensions.
#'
#' @section Key Features:
#'
#' \strong{Multi-Family Indicator System:}
#' \itemize{
#'   \item \strong{C - Carbon & Vitality}: C1-C2
#'   \item \strong{B - Biodiversity}: B1-B4
#'   \item \strong{W - Water}: W1-W4
#'   \item \strong{A - Air & Microclimate}: A1-A5
#'   \item \strong{F - Soil Fertility}: fertility (F1), erosion risk (F2)
#'   \item \strong{L - Landscape}: edge effect (L1), fragmentation (L2), spectral heterogeneity (L3)
#'   \item \strong{T - Temporal Dynamics}: T1-T3
#'   \item \strong{R - Risks & Resilience}: R1-R7
#'   \item \strong{S - Social & Recreational}: S1-S3
#'   \item \strong{P - Production}: P1-P3
#'   \item \strong{E - Energy & Climate}: E1-E2
#'   \item \strong{N - Naturalness}: N1-N3
#'   \item Some indicators are conditional on optional sources (R5 FORDEAD, T3 SUFOSAT, A5 LST, R7 SAFRAN); see \code{indicator_families()}.
#' }
#'
#' \strong{Temporal Analysis:}
#' \itemize{
#'   \item Multi-period dataset management
#'   \item Change rate calculations (absolute and relative)
#'   \item Time-series and heatmap visualizations
#'   \item Before/after intervention comparison
#' }
#'
#' \strong{Normalization & Aggregation:}
#' \itemize{
#'   \item 3 normalization methods: minmax, zscore, quantile
#'   \item 4 aggregation methods: mean, weighted, geometric, harmonic
#'   \item Family-level composite indices
#'   \item Reference-based normalization for temporal consistency
#' }
#'
#' \strong{Visualization:}
#' \itemize{
#'   \item Spatial maps (single and faceted)
#'   \item Multi-family radar plots (4-12 axes)
#'   \item Temporal trend plots
#'   \item Multi-indicator heatmaps
#'   \item Comparison and difference maps
#' }
#'
#' @section Getting Started:
#'
#' See the vignettes for comprehensive guides:
#'
#' \itemize{
#'   \item \code{vignette("getting-started_fr", package = "nemeton")} -
#'     Introduction to basic workflows with demo data
#'   \item \code{vignette("temporal-analysis_fr", package = "nemeton")} -
#'     Multi-period analysis and change detection
#'   \item \code{vignette("indicator-families_fr", package = "nemeton")} -
#'     Complete reference for the 12-family system
#'   \item \code{vignette("internationalization", package = "nemeton")} -
#'     Bilingual support (French/English)
#' }
#'
#' @section Quick Example:
#'
#' \preformatted{
#' library(nemeton)
#'
#' # Load demo data
#' data(massif_demo_units)
#' layers <- massif_demo_layers()
#'
#' # Compute multi-family indicators
#' results <- nemeton_compute(
#'   massif_demo_units[1:10, ],
#'   layers,
#'   indicators = c("C1", "C2", "W1", "W2", "W3"),
#'   preprocess = TRUE
#' )
#'
#' # Normalize by family
#' normalized <- normalize_indicators(results)
#'
#' # Create family indices
#' family_scores <- create_family_index(normalized)
#'
#' # Visualize multi-family profile
#' nemeton_radar(family_scores, unit_id = 1, mode = "family")
#' }
#'
#' @section Main Functions:
#'
#' \strong{Indicator Calculation:}
#' \itemize{
#'   \item \code{\link{nemeton_compute}} - Compute biophysical indicators
#'   \item \code{\link{indicateur_c1_biomasse}} - Carbon stock (C1)
#'   \item \code{\link{indicateur_c2_ndvi}} - Vegetation vitality (C2)
#'   \item \code{\link{indicateur_w1_reseau}} - Hydrographic density (W1)
#'   \item \code{\link{indicateur_w2_zones_humides}} - Wetland coverage (W2)
#'   \item \code{\link{indicateur_w3_humidite}} - Topographic Wetness Index (W3)
#'   \item \code{\link{indicateur_f1_fertilite}} - Soil fertility (F1)
#'   \item \code{\link{indicateur_f2_erosion}} - Erosion risk (F2)
#'   \item \code{\link{indicateur_l1_effet_lisiere}} - Edge
#'     effect (L1)
#'   \item \code{\link{indicateur_l2_morcellement}} - Landscape
#'     fragmentation (L2)
#' }
#'
#' \strong{Temporal Analysis:}
#' \itemize{
#'   \item \code{\link{nemeton_temporal}} - Multi-period dataset management
#'   \item \code{\link{calculate_change_rate}} - Change rate calculations
#'   \item \code{\link{plot_temporal_trend}} - Time-series plots
#'   \item \code{\link{plot_temporal_heatmap}} - Indicator evolution heatmaps
#' }
#'
#' \strong{Normalization & Aggregation:}
#' \itemize{
#'   \item \code{\link{normalize_indicators}} - Scale indicators to 0-100
#'   \item \code{\link{create_family_index}} - Aggregate indicators by family
#'   \item \code{\link{create_composite_index}} - Custom composite indices
#'   \item \code{\link{invert_indicator}} - Invert indicator direction
#' }
#'
#' \strong{Visualization:}
#' \itemize{
#'   \item \code{\link{plot_indicators_map}} - Spatial maps
#'   \item \code{\link{nemeton_radar}} - Multi-family radar plots
#'   \item \code{\link{plot_comparison_map}} - Side-by-side comparison
#'   \item \code{\link{plot_difference_map}} - Change maps
#' }
#'
#' \strong{Data Management:}
#' \itemize{
#'   \item \code{\link{massif_demo_units}} - Demo forest parcels dataset
#'   \item \code{\link{massif_demo_layers}} - Demo spatial layers
#' }
#'
#' @section Package Options:
#'
#' Control package behavior with options:
#'
#' \itemize{
#'   \item \code{options(nemeton.language = "fr")} - Set French language
#'   \item \code{options(nemeton.language = "en")} - Set English language
#'   \item \code{nemeton_set_language("fr")} - Alternative language setting
#' }
#'
#' @section Author & Methodology:
#'
#' \strong{Package Author:} Pascal Obstétar (\email{pascal.obstetar@@gmail.com})
#'
#' \strong{Methodology:} Based on the Nemeton systemic forest analysis method
#' developed by \emph{Vivre en Forêt}, organizing ecosystem services into
#' 12 families representing key dimensions of forest functioning.
#'
#' @section Version History:
#'
#' See \code{news(package = "nemeton")} (NEWS.md) for the release history.
#'
#' @section Links:
#'
#' \itemize{
#'   \item GitHub: \url{https://github.com/pobsteta/nemeton}
#'   \item Bug Reports: \url{https://github.com/pobsteta/nemeton/issues}
#' }
#'
#' @seealso
#' \strong{Vignettes:}
#' \itemize{
#'   \item \code{vignette("getting-started_fr")} - Introduction and basic workflows
#'   \item \code{vignette("temporal-analysis_fr")} - Multi-period analysis guide
#'   \item \code{vignette("indicator-families_fr")} - 12-family reference guide
#'   \item \code{vignette("internationalization")} - Bilingual support
#' }
#'
#' \strong{Key Function Families:}
#' \itemize{
#'   \item Indicators: \code{\link{nemeton_compute}}
#'   \item Temporal: \code{\link{nemeton_temporal}}
#'   \item Normalization: \code{\link{normalize_indicators}}
#'   \item Aggregation: \code{\link{create_family_index}}
#'   \item Visualization: \code{\link{nemeton_radar}}
#' }
#'
#' @docType _PACKAGE
#' @name nemeton-package
#' @aliases nemeton
NULL
