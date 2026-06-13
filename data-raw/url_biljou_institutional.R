# url_biljou_institutional.R — renseigne les source_url publiques des 8 docs
# institutionnels BILJOU cleared (recherche web 2026-06-13).
#   Rscript data-raw/url_biljou_institutional.R
suppressMessages(pkgload::load_all(quiet = TRUE))

urls <- c(
  allen_1998_fao56_evapotranspiration  = "https://www.fao.org/3/x0490e/x0490e00.htm",
  birot_2011_water_forests_med_en      = "https://efi.int/sites/default/files/files/publication-bank/2018/efi_wsctu1_2011_en.pdf",
  birot_2011_eau_forets_med_fr         = "https://efi.int/publications-bank/wsctu",
  badeau_2008_renecofor_faisabilite    = "https://hal.inrae.fr/hal-02813279",
  badeau_2008_modelisation_bilan       = "https://appgeodb.nancy.inrae.fr/biljou/pdf/Badeau_Br%C3%A9da_2008_RENECOFOR.pdf",
  peiffer_2008_renecofor_meteo         = "https://hal.inrae.fr/hal-03758947",
  ulrich_1995_interception_renecofor   = "https://appgeodb.nancy.inrae.fr/biljou/pdf/Ulrich_et_al_1995.pdf"
  # brethes_1997_renecofor_pedologie : pas de PDF public (seules notices de
  #   catalogue belinrae/infodoc/AgroParisTech) -> source_url laissee vide.
)

m <- read_knowledge_manifest()
miss <- setdiff(names(urls), m$doc_id)
if (length(miss)) stop("doc_id absent : ", paste(miss, collapse = ", "))

for (id in names(urls)) m$source_url[m$doc_id == id] <- urls[[id]]

issues <- validate_knowledge_manifest(m)
errs <- issues[issues$severity == "error", , drop = FALSE]
if (nrow(errs)) { print(errs); stop("validation echouee, rien ecrit") }

write_knowledge_manifest(m, path = knowledge_manifest_path())
cat("source_url renseignees :", length(urls), "/ 8 (brethes_1997 sans PDF public)\n")
ids <- c(names(urls), "brethes_1997_renecofor_pedologie")
print(m[m$doc_id %in% ids, c("doc_id", "source_url")], row.names = FALSE)
