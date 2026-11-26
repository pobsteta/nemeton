# Comparaison 4b (mission 071) : carte RECONFORT IOTA2 contre carte du spike
# (mission 060), sur une meme zone. A lancer sur le poste de Pascal :
#
#   Rscript data-raw/comparaison_reconfort/comparer_cartes.R \
#     <carte_iota2.tif> <carte_spike.tif> <dossier_sortie> [duree_iota2_s] [duree_spike_s]
#
# <carte_iota2.tif> : classes 1 a 3, p. ex. `rasters$classif_masked` rendu par
# run_reconfort_dieback(). <carte_spike.tif> : carte de classes 1 a 3 produite par
# le spike (le spike s'arrete aux tables : la carte vient de la chaine image de
# la mission 060). Les durees (secondes) viennent des `elapsed_sec` des deux
# chaines. Les sorties (CSV) vont dans <dossier_sortie>, HORS du depot.

comparer_cartes <- function(iota2, spike, sortie, duree_iota2 = NA_real_,
                            duree_spike = NA_real_) {
  if (!requireNamespace("nemeton", quietly = TRUE) &&
      !"package:nemeton" %in% search()) {
    stop("Installez ou chargez nemeton (pkgload::load_all()).")
  }
  acc <- nemeton:::.reconfort_accord_cartes(iota2, spike)
  dir.create(sortie, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(as.data.frame.matrix(acc$confusion),
                   file.path(sortie, "confusion.csv"))
  utils::write.csv(acc$par_classe, file.path(sortie, "par_classe.csv"),
                   row.names = FALSE)
  resume <- data.frame(
    pixels_compares = acc$n, surface_comparee_ha = acc$surface_comparee_ha,
    accord_global = acc$accord, kappa = acc$kappa,
    duree_iota2_s = as.numeric(duree_iota2), duree_spike_s = as.numeric(duree_spike))
  utils::write.csv(resume, file.path(sortie, "resume.csv"), row.names = FALSE)
  cat("Matrice de confusion (lignes IOTA2, colonnes spike)\n")
  print(acc$confusion)
  cat(sprintf("\nAccord global : %.4f   kappa (indicateur) : %.4f\n",
              acc$accord, acc$kappa))
  print(acc$par_classe)
  cat("\nSorties dans", normalizePath(sortie), "\n")
  invisible(c(acc, list(resume = resume)))
}

if (!interactive() && sys.nframe() == 0L) {
  a <- commandArgs(trailingOnly = TRUE)
  if (length(a) < 3L) stop("Usage : comparer_cartes.R iota2.tif spike.tif sortie [duree_iota2 duree_spike]")
  if (!"package:nemeton" %in% search()) suppressMessages(library(nemeton))
  comparer_cartes(a[1], a[2], a[3],
                  if (length(a) >= 4L) as.numeric(a[4]) else NA_real_,
                  if (length(a) >= 5L) as.numeric(a[5]) else NA_real_)
}
