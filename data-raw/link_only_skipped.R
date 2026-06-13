# link_only_skipped.R — fait entrer les 21 docs sautés dans le corpus.
# IPCC (PDF récupéré) -> full + local_path ; les 20 autres -> link_only.
# + corrige 3 métadonnées (source_url HAL open ; journal exact de Monnet).
#   Rscript data-raw/link_only_skipped.R
suppressMessages(pkgload::load_all(quiet = TRUE))

m <- read_knowledge_manifest()
skipped <- m$status == "cleared" & m$ingest_strategy == "full" &
           (is.na(m$local_path) | m$local_path == "")
cat("docs sautés ciblés :", sum(skipped), "\n")

# IPCC : PDF téléchargé -> full-text
ip <- m$doc_id == "ipcc_2019_afolu"
m$ingest_strategy[ip] <- "full"
m$local_path[ip] <- "data-raw/references/IPCC_2019_V4_Ch04_ForestLand.pdf"
m$notes[ip] <- paste0(m$notes[ip], " ; PDF: 2019 Refinement Vol.4 Ch.4 Forest Land")

# Tous les autres sautés -> link_only (référence citable)
others <- skipped & !ip
m$ingest_strategy[others] <- "link_only"

# Corrections de métadonnées (sources open trouvées via API HAL)
fix_url <- function(id, url) m$source_url[m$doc_id == id] <<- url
fix_url("duplat_tranha_1997",  "https://hal.science/hal-00883174")
fix_url("larrieu_2018_ibp",    "https://hal.science/hal-03449570")
# Monnet : le manifest avait le mauvais journal/DOI -> c'est Forests 5(9), HAL open
mm <- m$doc_id == "monnet_mermin_2014"
m$publisher[mm]  <- "Forests 5(9)"
m$source_url[mm] <- "https://hal.science/hal-01086012"
m$notes[mm] <- "Cite sur references CHM (spec 005) ; Forests 5(9):2307-2326 DOI 10.3390/f5092307 ; CC-BY (open HAL) ; corrige (etait Remote Sensing 6(8))"

issues <- validate_knowledge_manifest(m)
errs <- issues[issues$severity == "error", , drop = FALSE]
if (nrow(errs)) { print(errs); stop("validation echouee, rien ecrit") }

write_knowledge_manifest(m, path = knowledge_manifest_path())
cat("strategies:\n"); print(table(m$ingest_strategy))
