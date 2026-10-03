# inst/scripts/calibrate_uts_rmqs.R
#
# Phase D of the F1 GIS Sol wiring: empirical calibration of the
# expert UTS -> fertility table shipped in
# `inst/extdata/uts_fertilite_fr.csv` against the Réseau de Mesures
# de la Qualité des Sols (RMQS, INRAE) 1ère campagne 2000-2009.
#
# Source: Analyses physico-chimiques des sites du RMQS, DOI 10.15454/QSXKGA
#         (Etalab 2.0 licence == CC-BY 2.0 compatible).
#
# Workflow:
#   1. Download the 4 RMQS tab files to a user-level cache (idempotent).
#   2. Read analyses (CEC on topsoil 0-30 cm) and occupation (soil names).
#   3. Classify each site's RP 1995 / 2008 soil-type string into one
#      of our `rpf_code` values via a keyword-priority dictionary.
#   4. Aggregate CEC per `rpf_code` (n, median, Q25, Q75).
#   5. Convert the observed median CEC to a 0-100 fertility score via
#      `nemeton::cec_to_fertility_score()` and compare to the expert
#      score, flagging deltas > 20 points as outliers.
#   6. Write `inst/extdata/uts_fertilite_rmqs_calibration.csv`.
#
# Run: Rscript inst/scripts/calibrate_uts_rmqs.R
# No side effects outside the cache dir + the calibration CSV in-repo.

suppressPackageStartupMessages({
  library(nemeton)
})

# ---- 1. Cache + download --------------------------------------------------

RMQS_DOI <- "10.15454/QSXKGA"
RMQS_URL <- paste0(
  "https://entrepot.recherche.data.gouv.fr/api/access/dataset/:persistentId/",
  "?persistentId=doi:", RMQS_DOI
)

rmqs_cache_dir <- function() {
  base <- tryCatch(tools::R_user_dir("nemeton", "cache"),
                   error = function(e) file.path(tempdir(), "nemeton-cache"))
  path <- file.path(base, "rmqs")
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

download_rmqs <- function(cache = rmqs_cache_dir()) {
  zip_path <- file.path(cache, "rmqs.zip")
  if (!file.exists(zip_path)) {
    cli::cli_alert_info("Downloading RMQS dataset (DOI {RMQS_DOI})...")
    utils::download.file(RMQS_URL, zip_path, mode = "wb", quiet = TRUE)
    utils::unzip(zip_path, exdir = cache)
    cli::cli_alert_success("RMQS cached in {cache}")
  }
  files <- list.files(cache, pattern = "\\.tab$", full.names = TRUE)
  list(
    analyses = grep("analyses_composites", files, value = TRUE),
    occupation = grep("occupation_nommatp", files, value = TRUE)
  )
}

# ---- 2. Read --------------------------------------------------------------

read_rmqs_tab <- function(path) {
  # RMQS tab files are tab-delimited with quoted strings; decimal = "."
  utils::read.delim(
    path,
    sep = "\t",
    quote = "\"",
    stringsAsFactors = FALSE,
    na.strings = c("ND", "NA", ""),
    fileEncoding = "UTF-8"
  )
}

# ---- 3. Classify RP 1995 / 2008 names -> rpf_code ------------------------

# Normalise a French soil-name string to lowercase ASCII for matching.
normalise_rp <- function(x) {
  if (is.na(x) || !nzchar(x)) return(NA_character_)
  x <- iconv(x, to = "ASCII//TRANSLIT", sub = " ")
  tolower(x)
}

# Priority-ordered keyword matcher. First hit wins; more specific qualifiers
# come before the generic class default. Returns NA_character_ if no match.
classify_rmqs_to_rpf <- function(nom) {
  n <- normalise_rp(nom)
  if (is.na(n)) return(NA_character_)

  rules <- list(
    # Podzosols (order matters)
    list("POD_DUR", "podzosol.*durique"),
    list("POD_MEU", "podzosol.*meuble"),
    list("POD_HUM", "podzosol.*humique"),
    list("POD_OCR", "podzosol"),

    # Brunisols
    list("BRUN_DYS", "brunisol.*dystri"),
    list("BRUN_EUT", "brunisol.*eutri"),
    list("BRUN_MES", "brunisol.*m[ae]sotri"),
    list("BRUN_OLI", "brunisol.*oligo"),
    list("BRUN_HUM", "brunisol.*humique"),
    list("BRUN_HYD", "brunisol.*redoxique|brunisol-redoxisol"),
    list("BRUN_MES", "brunisol"),

    # Luvisols (+ NEOLUVISOL which is the RP2008 name for RP95 LUVISOL TYPIQUE)
    list("LUV_HYD", "luvisol.*redoxique|luvisol-redoxisol|neoluvisol-redoxisol"),
    list("LUV_DEG", "luvisol.*degrad|luvisol.*typique.*degrad"),
    list("LUV_DYS", "luvisol.*dystri"),
    list("LUV_ALB", "luvisol.*albique"),
    list("LUV_TYP", "neoluvisol"),
    list("LUV_TYP", "luvisol"),

    # Alocrisols
    list("ALO_HUM", "alocrisol.*humique"),
    list("ALO_LEP", "alocrisol.*leptique"),
    list("ALO_TYP", "alocrisol"),

    # Calcosols
    list("CAL_COL", "calcosol.*colluvial"),
    list("CAL_CAI", "calcosol.*cailloute|calcosol.*skele|calcosol.*superfici"),
    list("CAL_RED", "calcosol.*redoxique"),
    list("CAL_PRO", "calcosol.*profond"),
    list("CAL_TYP", "calcosol"),

    # Calcisols
    list("CAS_HYD", "calcisol.*redoxique"),
    list("CAS_ROU", "calcisol.*rouge"),
    list("CAS_TYP", "calcisol"),

    # Fluviosols
    list("FLU_CAL", "fluviosol.*calcaire"),
    list("FLU_HYD", "fluviosol.*reducti|fluviosol.*hydromorphe|fluviosol.*gleyi"),
    list("FLU_BRU", "fluviosol.*brut"),
    list("FLU_TYP", "fluviosol"),

    # Colluviosols
    list("COL_CAL", "colluviosol.*calcaire"),
    list("COL_TYP", "colluviosol"),

    # Rankosols
    list("RAN_LIT", "rankosol.*lithique"),
    list("RAN_HUM", "rankosol.*humique"),
    list("RAN_OCR", "rankosol"),

    # Arenosols
    list("ARE_POD", "arenosol.*podzoso|arenosol.*albique"),
    list("ARE_HUM", "arenosol.*humique"),
    list("ARE_TYP", "arenosol"),

    # Redoxisols / Reductisols — stagnic/gleyic
    list("RDX_LUV", "redoxisol.*luvique"),
    list("RDX_DYS", "redoxisol.*dystri"),
    list("RDX_TYP", "redoxisol"),
    list("RDS_HIS", "reductisol.*histique|reductisol.*tourbeux"),
    list("RDS_TYP", "reductisol"),

    # Peyrosols
    list("PEY_CAL", "peyrosol.*calcaire"),
    list("PEY_HUM", "peyrosol.*humifere"),
    list("PEY_TYP", "peyrosol"),

    # Organosols (tourbes)
    list("ORG_HIS", "organosol.*histique|organosol.*saprique"),
    list("ORG_DRA", "organosol.*drain"),
    list("ORG_INS", "organosol"),

    # Régosols / Lithosols
    list("LIT_TYP", "lithosol"),
    list("REG_TYP", "regosol"),

    # RP 1995 types with no direct RP 2008 equivalent in our table
    #   RENDOSOL / RENDISOL = calcaire sur roche, approximé en CAL_CAI
    list("CAL_CAI", "rendosol|rendisol|rendzine"),
    #   VÉRACRISOL = acide très altéré, approximé en ALO_TYP
    list("ALO_TYP", "veracrisol"),

    # Anthroposols
    list("ANT_CON", "anthroposol.*construct|anthroposol.*reconstitu"),
    list("ANT_TRA", "anthroposol")
  )

  for (rule in rules) {
    if (grepl(rule[[2]], n, perl = TRUE)) return(rule[[1]])
  }
  NA_character_
}

# ---- 4. Pipeline ----------------------------------------------------------

run_calibration <- function() {
  paths <- download_rmqs()
  analyses <- read_rmqs_tab(paths$analyses)
  occ <- read_rmqs_tab(paths$occupation)

  # Topsoil only: keep horizons entirely within 0-30 cm.
  topsoil <- analyses[
    !is.na(analyses$profondeur_hz_sup) &
    !is.na(analyses$profondeur_hz_inf) &
    analyses$profondeur_hz_sup == 0 &
    analyses$profondeur_hz_inf <= 30 &
    !is.na(analyses$cec_40_1),
    c("id_site", "cec_40_1")
  ]
  topsoil$cec_40_1 <- as.numeric(topsoil$cec_40_1)

  # One row per site — average when multiple 0-30 composites exist.
  topsoil <- stats::aggregate(
    cec_40_1 ~ id_site, data = topsoil, FUN = mean, na.rm = TRUE
  )

  # Soil names: prefer RP 2008, fall back to RP 1995.
  occ$nom_prefer <- ifelse(
    is.na(occ$rp_2008_nom) | occ$rp_2008_nom == "",
    occ$rp_95_nom,
    occ$rp_2008_nom
  )
  occ$rpf_code <- vapply(occ$nom_prefer, classify_rmqs_to_rpf,
                          character(1))

  # Join CEC x soil typology (inner: need both).
  joined <- merge(topsoil, occ[, c("id_site", "rpf_code", "nom_prefer")],
                   by = "id_site")
  joined <- joined[!is.na(joined$rpf_code) & is.finite(joined$cec_40_1), ]

  # Per-rpf_code aggregation.
  agg <- do.call(rbind, lapply(split(joined, joined$rpf_code), function(df) {
    data.frame(
      rpf_code    = df$rpf_code[1],
      n_sites     = nrow(df),
      cec_median  = round(stats::median(df$cec_40_1), 2),
      cec_q25     = round(stats::quantile(df$cec_40_1, 0.25,
                                          names = FALSE), 2),
      cec_q75     = round(stats::quantile(df$cec_40_1, 0.75,
                                          names = FALSE), 2),
      stringsAsFactors = FALSE
    )
  }))
  rownames(agg) <- NULL

  # RMQS CEC is cmol+/kg ; SoilGrids scoring expects cmol(c)/kg * 10.
  agg$observed_score <- round(
    cec_to_fertility_score(agg$cec_median * 10), 1
  )

  # Join expert score from the shipped table.
  expert <- read_uts_fertility_table()[, c("rpf_code", "fertility_score")]
  names(expert)[2] <- "expert_score"
  cal <- merge(agg, expert, by = "rpf_code", all.x = TRUE)

  cal$delta <- cal$observed_score - cal$expert_score
  cal$flag_outlier <- !is.na(cal$delta) & abs(cal$delta) > 20

  cal <- cal[order(cal$rpf_code), c(
    "rpf_code", "n_sites", "cec_median", "cec_q25", "cec_q75",
    "observed_score", "expert_score", "delta", "flag_outlier"
  )]

  list(calibration = cal,
       joined     = joined,
       unmatched  = occ[is.na(occ$rpf_code) & !is.na(occ$nom_prefer),
                         c("id_site", "nom_prefer")])
}

# ---- 5. Persist + summarise -----------------------------------------------

if (identical(environment(), globalenv()) ||
    identical(sys.nframe(), 0L)) {
  out <- run_calibration()

  out_path <- file.path("inst", "extdata",
                         "uts_fertilite_rmqs_calibration.csv")
  utils::write.csv(out$calibration, out_path, row.names = FALSE,
                    fileEncoding = "UTF-8")

  cli::cli_h1("F1 calibration against RMQS 1ère campagne (2000-2009)")
  cli::cli_alert_info(
    "Calibrated: {nrow(out$calibration)} rpf_code / {sum(out$calibration$n_sites)} RMQS sites"
  )
  cli::cli_alert_info(
    "Unmatched RMQS names: {nrow(out$unmatched)} sites (class keyword not recognised)"
  )

  out$calibration$delta[is.na(out$calibration$delta)] <- NA
  outliers <- out$calibration[
    !is.na(out$calibration$flag_outlier) & out$calibration$flag_outlier,
  ]
  if (nrow(outliers) > 0) {
    cli::cli_h2("Outliers (|delta| > 20 points)")
    print(outliers, row.names = FALSE)
  } else {
    cli::cli_alert_success("No outliers — expert table within +/-20 points of RMQS")
  }

  cli::cli_alert_success("Wrote {out_path}")
}
