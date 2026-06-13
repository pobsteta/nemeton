# clear_all_to_confirm.R — passe TOUS les docs `to_confirm` en `cleared`.
# Override explicite du gel licence D5 (décision Pascal 2026-06-13) : les
# références (toutes `abstract_only`) entreront alors au corpus comme
# entrées citables (mode link_only, pas de texte intégral).
#   Rscript data-raw/clear_all_to_confirm.R
suppressMessages(pkgload::load_all(quiet = TRUE))

m <- read_knowledge_manifest()
idx <- which(m$status == "to_confirm")
cat("to_confirm -> cleared :", length(idx), "docs\n")
m$status[idx] <- "cleared"
m$notes[idx]  <- paste0(m$notes[idx], " ; cleared (override D5, 2026-06-13)")

issues <- validate_knowledge_manifest(m)
errs <- issues[issues$severity == "error", , drop = FALSE]
if (nrow(errs)) { print(errs); stop("validation echouee, rien ecrit") }

write_knowledge_manifest(m, path = knowledge_manifest_path())
print(table(m$status))
