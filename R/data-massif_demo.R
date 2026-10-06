#' Massif Demo - Example Forest Dataset
#'
#' Example forest dataset for demonstrating the nemeton package: 20 forest
#' parcels covering a 5 km x 5 km area in France (Lambert-93), with a
#' synthetic stand inventory, the 41 indicators computed by the package from
#' the demo layers, their normalised versions and the 12 family indices.
#'
#' @format An \code{sf} object with 20 features (POLYGON, EPSG:2154) and 123
#'   columns (122 fields + geometry):
#' \describe{
#'   \item{parcel_id}{Character. Unique parcel identifier (P01-P20).}
#'   \item{forest_type}{Character. Forest type: "Futaie feuillue",
#'     "Futaie résineuse", "Futaie mixte" or "Taillis".}
#'   \item{age_class}{Character. Stand age class: "Jeune", "Moyen",
#'     "Mature" or "Surannée".}
#'   \item{management}{Character. Management objective: "Production",
#'     "Conservation" or "Mixte".}
#'   \item{species}{Character. Two-digit IFN species code (e.g. "03", "09",
#'     "64").}
#'   \item{age}{Integer. Stand age (years).}
#'   \item{establishment_year}{Numeric. Stand establishment year (2026 - age).}
#'   \item{density}{Integer. Stem density (stems/ha).}
#'   \item{height}{Numeric. Mean height (m).}
#'   \item{dbh}{Numeric. Mean diameter at breast height (cm).}
#'   \item{volume}{Numeric. Standing volume (m3/ha).}
#'   \item{strata}{Integer. Number of vegetation layers (1-4).}
#'   \item{fertility}{Integer. Fertility class (1 good to 3 poor).}
#'   \item{climate}{Character. Climate type ("atlantique", "continental",
#'     "montagnard").}
#'   \item{surface_ha}{Numeric. Parcel area (ha).}
#'   \item{couvert}{Numeric. Canopy cover fraction (0-1), used by C1.}
#'   \item{C1, C2, B1, B2, B3, B4, W1, W2, W3, W4, A1, A2, A3, A4, A5, F1, F2,
#'     L1, L2, L3, T1, T2, T3, R1, R2, R3, R4, R5, R6, R7, S1, S2, S3, P1, P2,
#'     P3, E1, E2, N1, N2, N3}{Numeric. Raw values of the 41 indicators, in
#'     the order of \code{list_indicators()}; see \code{indicator_labels()}
#'     for their meaning. \code{NA} when the demo layers cannot compute the
#'     indicator (see Details).}
#'   \item{b4_status, w4_status, a3_status, a4_status, a5_status, l3_status,
#'     t3_status, r1_status, r5_status, r6_status, r7_status,
#'     p3_status}{Character. Status written by the indicators that carry
#'     one (e.g. \code{"skipped_no_micro"}, \code{"fire_exp"},
#'     \code{"diametre_seul"}).}
#'   \item{C1_norm, ..., N3_norm}{Numeric. The 41 indicators normalised to
#'     0-100 by \code{normalize_indicator()} (higher = more favourable).}
#'   \item{famille_carbone, famille_biodiversite, famille_eau, famille_air,
#'     famille_sol, famille_paysage, famille_temporel, famille_risque,
#'     famille_social, famille_production, famille_energie,
#'     famille_naturalite}{Numeric. Family indices (0-100) computed by
#'     \code{create_family_index()} (mean of the available indicators).}
#'   \item{geometry}{sfc_POLYGON. Parcel boundaries (EPSG:2154).}
#' }
#'
#' @details
#' \strong{What is simulated.} The parcels and their stand inventory
#' (\code{forest_type} to \code{surface_ha}, plus \code{couvert}) are
#' synthetic, drawn with \code{set.seed(42)} (\code{set.seed(4242)} for
#' \code{couvert}); so are the demo layers of \code{inst/extdata/}. The
#' inventory plays the part of field data: no real stand is described.
#'
#' \strong{What is computed.} The 41 indicator columns, their \code{_norm}
#' and the family indices are not simulated: \code{data-raw/massif_demo.R}
#' computes them with the package's own functions from
#' \code{\link{massif_demo_layers}} and the synthetic inventory (as
#' \code{nemeton_compute()} does), with two derived inputs: a BD Forêt-like
#' forest cover polygonised from the demo land cover (classes 1-3), used by
#' B3, N2, R1 and R4; and an empty game-density raster for R4, so that the
#' generation needs no network (R2 also uses the default 270 degree wind).
#'
#' \strong{Indicators left NA (19).} The demo layers hold no NDVI (C2), no
#' protected areas (B1), no CHM, LiDAR or NDVI for the stand structure (B2),
#' no soil layer (F1), no buildings (S2, N1, hence N3), no population grid
#' (S3), and no LiDAR canopy height or game density for R4. The ten
#' source-conditional indicators also stay NA, with their status: B4 and L3
#' (Sentinel-2 spectral diversity), W4, A3, A4 and R6 (microclimate), A5
#' (land-surface temperature), R5 (FORDEAD / RECONFORT), R7 (daily minimum
#' temperature) and T3 (SUFOSAT). The demo's two-digit IFN species codes
#' are not in P2's productivity table, so P2 falls back to the genus mean
#' (6.5 m3/ha/yr) on the 11 parcels of fertility class 2 and is NA on the 9
#' parcels of class 1 or 3, which have no genus entry.
#'
#' Associated layers (25 m rasters and vector layers in \code{inst/extdata/})
#' are loaded with \code{\link{massif_demo_layers}}:
#' \itemize{
#'   \item \code{massif_demo_biomass.tif}: aboveground biomass (50-400 Mg/ha)
#'   \item \code{massif_demo_dem.tif}: digital elevation model (350-700 m)
#'   \item \code{massif_demo_landcover.tif}: land cover (classes 1-3 forest,
#'     4 grassland)
#'   \item \code{massif_demo_species_richness.tif}: species richness
#'   \item \code{massif_demo_roads.gpkg}, \code{massif_demo_water.gpkg}:
#'     roads and water courses
#' }
#'
#' The data are meant for examples, tests and vignettes, not for analysis.
#'
#' @source Generated with \code{data-raw/massif_demo.R} (nemeton 1.0.0).
#'
#' @seealso \code{\link{massif_demo_layers}}, \code{\link{nemeton_compute}},
#'   \code{\link{nemeton_radar}}, \code{\link{create_family_index}}
#'
#' @examples
#' data(massif_demo_units)
#'
#' # Stand attributes
#' summary(massif_demo_units$surface_ha)
#' table(massif_demo_units$forest_type)
#'
#' # Family indices
#' summary(sf::st_drop_geometry(massif_demo_units)[, c(
#'   "famille_carbone", "famille_production", "famille_naturalite"
#' )])
#'
#' \dontrun{
#' # 12-axis family radar for parcel 1
#' nemeton_radar(massif_demo_units, unit_id = 1, mode = "family")
#'
#' # Recompute indicators from the demo layers
#' layers <- massif_demo_layers()
#' results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
#' }
#'
#' @keywords datasets
"massif_demo_units"
