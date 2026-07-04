# data-raw/prosail_lai_model.R — modèle PROSAIL LAI pré-entraîné Sentinel-2,
# versionné dans inst/extdata (spec 033 D3). Bandes = celles exposées par le
# pipeline S2 nemeton (.S2_STAC_BANDS) : rouge B04, red-edge B05, NIR B08.
# Régénérer : Rscript data-raw/prosail_lai_model.R
suppressMessages(library(prosail))
sensor <- "Sentinel_2A"; bands <- c("B4", "B5", "B8")
e <- new.env(); utils::data(list = sensor, package = "prosail", envir = e)
S2 <- e[[sensor]]
srf <- list(spectral_response = S2$spectral_response,
            spectral_bands = S2$spectral_bands,
            original_bands = S2$original_bands, sensor = sensor)
geom <- list(min = data.frame(tto = 0,  tts = 20, psi = 0),
             max = data.frame(tto = 10, tts = 55, psi = 180))
opt <- set_options_prosail(fun = "train_prosail_inversion")
od <- tempfile("train_"); dir.create(od)
model <- train_prosail_inversion(
  parms_to_estimate = "lai", atbd = TRUE, geom_acq = geom, srf = srf,
  selected_bands = list(lai = bands), output_dir = od, options = opt)
out <- file.path("inst", "extdata",
                 sprintf("prosail_lai_%s_%s.rds", sensor, paste(bands, collapse = "-")))
saveRDS(model, out)
cat("écrit:", out, "| taille Ko:", round(file.size(out) / 1024), "\n")
