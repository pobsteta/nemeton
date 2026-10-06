# Génère inst/extdata/tutorial_data_manifest.csv : la liste des fichiers des
# jeux de données des tutoriels 07 (aba.model) et 08 (coregistration), avec
# taille et MD5. Ces jeux sont suivis par git mais exclus du build
# (.Rbuildignore) ; .tutorial_data_dir() les télécharge à la demande depuis
# https://raw.githubusercontent.com/pobsteta/nemeton/<tag>/inst/extdata/<chemin>
# et vérifie chaque fichier contre ce manifeste.
#
# À relancer depuis la racine du dépôt après toute modification de ces
# données : Rscript data-raw/tutorial_data_manifest.R

datasets <- c("aba.model", "coregistration")
files <- system2("git", c("ls-files", "--", file.path("inst/extdata", datasets)),
                 stdout = TRUE)
stopifnot(length(files) > 0L, all(file.exists(files)))

rel <- sub("^inst/extdata/", "", files)
man <- data.frame(
  dataset = sub("/.*$", "", rel),
  path    = rel,
  size    = as.numeric(file.size(files)),
  md5     = unname(tools::md5sum(files)),
  stringsAsFactors = FALSE
)
man <- man[order(man$path), ]
utils::write.csv(man, "inst/extdata/tutorial_data_manifest.csv",
                 row.names = FALSE)
message(nrow(man), " files, ", round(sum(man$size) / 1024^2, 1), " MB")
