#' Species Configuration by Region (ADR-007)
#'
#' @description
#' Manages forest species/essence classification by biogeographic region.
#' Species classes are defined in JSON files (\code{inst/species/BFC.json},
#' \code{inst/species/EU.json}, etc.) following NMT convention.
#'
#' Adding a new region requires only a JSON file, no code modification.
#'
#' @name species-config
#' @keywords internal
NULL


# Cache pour les configurations chargees
.species_cache <- new.env(parent = emptyenv())


#' Get species configuration for a region
#'
#' Loads and caches the species classification for a biogeographic region.
#'
#' @param region Character. Region code (e.g., "BFC", "EU").
#'   Use "EU" for pan-European fallback.
#'
#' @return A list with the region's species configuration.
#'
#' @examples
#' config <- get_species_config("BFC")
#' config$n_classes  # 10
#' config$classes[[1]]$code  # "essence_chenaie"
#'
#' @export
get_species_config <- function(region = "BFC") {
  region <- toupper(region)
  cache_key <- paste0("species_", region)

  if (exists(cache_key, envir = .species_cache)) {
    return(get(cache_key, envir = .species_cache))
  }

  config_file <- system.file("species", paste0(region, ".json"),
                             package = "nemeton")

  if (!nzchar(config_file) || !file.exists(config_file)) {
    if (region != "EU") {
      cli::cli_warn("No species configuration for region {.val {region}}. Using EU fallback.")
      return(get_species_config("EU"))
    }
    cli::cli_abort("Species configuration file not found for {.val {region}}")
  }

  config <- jsonlite::read_json(config_file, simplifyVector = FALSE)
  assign(cache_key, config, envir = .species_cache)
  config
}


#' List available species regions
#'
#' @return Character vector of region codes.
#'
#' @examples
#' list_species_regions()  # c("BFC", "EU")
#'
#' @export
list_species_regions <- function() {
  config_dir <- system.file("species", package = "nemeton")
  if (!nzchar(config_dir)) return(character(0))
  files <- list.files(config_dir, pattern = "\\.json$", full.names = FALSE)
  sub("\\.json$", "", files)
}


#' Get species classes for a region
#'
#' Returns a data.frame of the species classes with their codes,
#' labels, and allometric keys.
#'
#' @param region Character. Region code. Default "BFC".
#' @param lang Character. Language for labels. Default "fr".
#'
#' @return A data.frame with columns: code, label, allometric_key, color.
#'
#' @examples
#' classes <- list_species_classes("BFC", lang = "fr")
#' classes$code   # "essence_chenaie", "essence_hetraie", ...
#' classes$label  # "Chênaie", "Hêtraie", ...
#'
#' @export
list_species_classes <- function(region = "BFC", lang = "fr") {
  config <- get_species_config(region)

  data.frame(
    code = vapply(config$classes, `[[`, character(1), "code"),
    label = vapply(config$classes, function(cls) {
      cls$label[[lang]] %||% cls$label[["fr"]] %||% cls$code
    }, character(1)),
    allometric_key = vapply(config$classes, `[[`, character(1), "allometric_key"),
    color = vapply(config$classes, `[[`, character(1), "color"),
    stringsAsFactors = FALSE
  )
}


#' Map BD Foret essence to NMT species class
#'
#' Translates a BD Foret V2 essence label into the corresponding
#' NMT species class code using the region's bdforet_mapping.
#'
#' @param essence Character. BD Foret essence label.
#' @param region Character. Region code. Default "BFC".
#'
#' @return Character. NMT species class code (e.g., "essence_chenaie"),
#'   or "essence_mixte" if no mapping found.
#'
#' @examples
#' map_bdforet_essence("Hêtre", region = "BFC")  # "essence_hetraie"
#' map_bdforet_essence("Douglas", region = "BFC")  # "essence_douglasaie"
#'
#' @export
map_bdforet_essence <- function(essence, region = "BFC") {
  config <- get_species_config(region)

  if (is.null(config$bdforet_mapping)) return("essence_mixte")

  mapping <- config$bdforet_mapping

  # Recherche exacte
  if (!is.null(mapping[[essence]])) {
    return(mapping[[essence]])
  }

  # Recherche partielle (contient le mot)
  for (key in names(mapping)) {
    if (grepl(tolower(key), tolower(essence), fixed = TRUE)) {
      return(mapping[[key]])
    }
  }

  "essence_mixte"
}


#' Map OSO class to possible NMT species classes
#'
#' Returns the list of possible species classes for a given OSO
#' land cover code (17=deciduous, 18=coniferous, 19=mixed).
#'
#' @param oso_class Integer. OSO class code (17, 18, or 19).
#' @param region Character. Region code. Default "BFC".
#'
#' @return Character vector of possible NMT species class codes.
#'
#' @examples
#' map_oso_class(17, "BFC")  # feuillus possibles
#' map_oso_class(18, "BFC")  # coniferes possibles
#'
#' @export
map_oso_class <- function(oso_class, region = "BFC") {
  config <- get_species_config(region)

  if (is.null(config$oso_mapping)) return("essence_mixte")

  key <- as.character(oso_class)
  classes <- config$oso_mapping[[key]]

  if (is.null(classes)) return("essence_mixte")
  unlist(classes)
}


#' Get allometric key for a species class
#'
#' @param species_code Character. NMT species class code.
#' @param region Character. Region code. Default "BFC".
#'
#' @return Character. Allometric key (e.g., "Quercus", "Fagus", "Pinus").
#'
#' @export
get_allometric_key <- function(species_code, region = "BFC") {
  config <- get_species_config(region)

  for (cls in config$classes) {
    if (cls$code == species_code) {
      return(cls$allometric_key)
    }
  }

  "Generic"
}
