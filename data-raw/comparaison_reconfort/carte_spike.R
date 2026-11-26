# Carte du spike RECONFORT sur la grille de la carte IOTA2, puis comparaison
# (mission 076, suite de la mission 071). A lancer sur le poste de Pascal :
#
#   Rscript data-raw/comparaison_reconfort/carte_spike.R \
#     <modele.rds> <dossier_scenes> <annee> <carte_iota2.tif> <dossier_sortie> \
#     [chenaie.tif] [coupes.tif] [duree_iota2_s]
#
# <modele.rds>     : un `reconfort_modele` (saveRDS(reconfort_entrainer(...), ...)).
# <dossier_scenes> : scenes MUSCATE decoupees (extracted/<tuile>/<scene>/), celles
#                    que les voies archive et fenetre ecrivent.
# <carte_iota2.tif>: carte IOTA2 de la MEME zone et de la MEME annee ; sert de
#                    gabarit (CRS, origine, resolution, etendue de la carte du spike).
# chenaie.tif, coupes.tif (facultatifs) : masques de reconfort_masquer() ; coupes en
#                    YYDDD. Sorties dans <dossier_sortie>, HORS du depot.
#
# RAPPEL : tant que le modele n'est entraine que sur des etiquettes `synth_` ou
# propagees, l'accord avec IOTA2 mesure une RESSEMBLANCE, pas une JUSTESSE. La regle
# reste la spec 070 (Critere pour amender la spec 021) : des placettes de terrain
# tenues a l'ecart.

lancer_carte_spike <- function(modele_rds, scenes_dir, annee, iota2, sortie,
                               chenaie = NULL, coupes = NULL,
                               duree_iota2 = NA_real_) {
  if (!"package:nemeton" %in% search()) suppressMessages(library(nemeton))
  source(file.path(dirname(.fichier_script()), "comparer_cartes.R"), local = TRUE)
  dir.create(sortie, recursive = TRUE, showWarnings = FALSE)
  modele <- readRDS(modele_rds)
  gabarit <- terra::rast(iota2)
  carte <- file.path(sortie, sprintf("carte_spike_%s.tif", annee))
  t0 <- Sys.time()
  reconfort_carte_spike(modele, scenes_dir, as.integer(annee), gabarit, carte,
                        chenaie = if (!is.null(chenaie)) terra::rast(chenaie),
                        coupes = if (!is.null(coupes)) terra::rast(coupes))
  duree <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("Carte du spike : %s (%.0f s)\n", carte, duree))
  cat("\nRAPPEL : l'accord ci-dessous est une ressemblance entre deux methodes, pas une\n",
      "justesse, tant que le modele n'est entraine que sur des etiquettes synth_ ou\n",
      "propagees (spec 070, critere pour amender la spec 021 : placettes tenues a l'ecart).\n\n",
      sep = "")
  res <- comparer_cartes(iota2, carte, sortie, duree_iota2, duree)
  writeLines(c("Ressemblance, pas justesse : modele entraine sur etiquettes synth_ ou propagees.",
               "Seules des placettes de terrain tenues a l'ecart disent quelle carte est juste",
               "(spec 070, critere pour amender la spec 021)."),
             file.path(sortie, "LIRE_AVANT_DE_CONCLURE.txt"))
  invisible(res)
}

.fichier_script <- function() {
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(a)) sub("^--file=", "", a[1L]) else "data-raw/comparaison_reconfort/carte_spike.R"
}

if (!interactive() && sys.nframe() == 0L) {
  a <- commandArgs(trailingOnly = TRUE)
  if (length(a) < 5L) {
    stop("Usage : carte_spike.R modele.rds dossier_scenes annee carte_iota2.tif dossier_sortie [chenaie.tif coupes.tif duree_iota2_s]")
  }
  lancer_carte_spike(a[1], a[2], a[3], a[4], a[5],
                     if (length(a) >= 6L && nzchar(a[6])) a[6],
                     if (length(a) >= 7L && nzchar(a[7])) a[7],
                     if (length(a) >= 8L) as.numeric(a[8]) else NA_real_)
}
