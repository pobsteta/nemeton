# clear_biljou_institutional.R — passe en `cleared` les rapports
# institutionnels BILJOU (ONF/RENECOFOR, FAO, EFI) dont la licence est
# ouverte. Décision Pascal 2026-06-12.
#
# Les valeurs de licence sont présumées (variante à confirmer) ; aucune
# source n'est encore attachée, donc rien ne s'ingère tant qu'un PDF/URL
# n'est pas ajouté (strategy=full, mais .resolve_manifest_source -> NULL).
#
#   Rscript data-raw/clear_biljou_institutional.R
suppressMessages(pkgload::load_all(quiet = TRUE))

# doc_id -> licence présumée + commercial_ok
clears <- list(
  badeau_2008_renecofor_faisabilite = c("LO-Etalab", "TRUE"),
  badeau_2008_modelisation_bilan    = c("LO-Etalab", "TRUE"),
  brethes_1997_renecofor_pedologie  = c("LO-Etalab", "TRUE"),
  peiffer_2008_renecofor_meteo      = c("LO-Etalab", "TRUE"),
  ulrich_1995_interception_renecofor= c("LO-Etalab", "TRUE"),
  allen_1998_fao56_evapotranspiration = c("CC-BY-NC", "FALSE"),
  birot_2011_water_forests_med_en   = c("CC-BY", "TRUE"),
  birot_2011_eau_forets_med_fr      = c("CC-BY", "TRUE")
)

m <- read_knowledge_manifest()
miss <- setdiff(names(clears), m$doc_id)
if (length(miss)) stop("doc_id absent du manifest : ", paste(miss, collapse = ", "))

for (id in names(clears)) {
  i <- which(m$doc_id == id)
  m$license[i]               <- clears[[id]][1]
  m$license_commercial_ok[i] <- clears[[id]][2]
  m$status[i]                <- "cleared"
  m$ingest_strategy[i]       <- "full"
  m$notes[i] <- sub(" - licence a confirmer", "", m$notes[i], fixed = TRUE)
  m$notes[i] <- paste0(
    m$notes[i],
    sprintf(" ; cleared Pascal 2026-06-12 (licence %s presumee - confirmer la variante ; attacher PDF/URL pour ingestion)",
            clears[[id]][1]))
}

issues <- validate_knowledge_manifest(m)
errs <- issues[issues$severity == "error", , drop = FALSE]
if (nrow(errs)) { print(errs); stop("validation echouee, rien ecrit") }

write_knowledge_manifest(m, path = knowledge_manifest_path())
cat("Mis a jour :", length(clears), "docs ->", knowledge_manifest_path(), "\n")
print(table(m$status))
print(m[m$doc_id %in% names(clears), c("doc_id", "license", "license_commercial_ok", "status", "ingest_strategy")],
      row.names = FALSE)
