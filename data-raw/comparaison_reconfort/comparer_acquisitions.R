# Comparaison 4a (mission 071) : acquisition par ARCHIVE contre acquisition par
# FENETRE, sur une meme zone et les memes dates. A lancer sur le poste de Pascal
# (conda RECONFORT, compte GEODES + cles THEIA TLD_ACCESS_KEY / TLD_SECRET_KEY) :
#
#   Rscript data-raw/comparaison_reconfort/comparer_acquisitions.R \
#     <zone.gpkg> <tuile> <date_debut> <date_fin> <dossier_sortie>
#
# Exemple (quelques scenes, pas deux ans) :
#   ... zone.gpkg T31TCN 2023-06-10 2023-06-30 ~/tmp/cmp071
#
# Rend : pour chaque voie, la duree (s) et le volume recu (octets, lu dans
# /proc/net/dev : approximatif, tout le trafic de la machine compte ; NA hors
# Linux) ; le volume des archives annonce par le catalogue GEODES (manifeste) ;
# puis la comparaison fichier par fichier des scenes ecrites (grille, type,
# valeurs). Sorties dans <dossier_sortie> (hors depot) : archive/, fenetre/,
# comparaison.csv, resume.csv. Ne rien lancer pendant que d'autres telechargements
# tournent, sinon le volume est faux.

rx_octets <- function() {
  f <- "/proc/net/dev"
  if (!file.exists(f)) return(NA_real_)
  l <- readLines(f)[-(1:2)]
  l <- l[!grepl("^\\s*lo:", l)]
  sum(vapply(strsplit(trimws(sub("^[^:]*:", "", l)), "\\s+"),
             function(x) as.numeric(x[1]), numeric(1)))
}

mesurer <- function(expr) {
  b0 <- rx_octets(); t0 <- Sys.time()
  force(expr)
  list(duree_s = as.numeric(difftime(Sys.time(), t0, units = "secs")),
       octets = rx_octets() - b0)
}

comparer_acquisitions <- function(zone, tuile, date_debut, date_fin, sortie) {
  if (!"package:nemeton" %in% search()) suppressMessages(library(nemeton))
  ns <- asNamespace("nemeton")
  aoi <- sf::st_read(zone, quiet = TRUE)
  dir.create(sortie, recursive = TRUE, showWarnings = FALSE)
  racine <- function(m) file.path(sortie, m)
  m_arch <- mesurer(ns$reconfort_ingest_s2(
    aoi = aoi, tiles = tuile, date_from = date_debut, date_to = date_fin,
    s2_root = racine("archive"), acquisition = "archive"))
  m_fen <- mesurer(ns$reconfort_ingest_s2(
    aoi = aoi, tiles = tuile, date_from = date_debut, date_to = date_fin,
    s2_root = racine("fenetre"), acquisition = "fenetre"))
  # Volume des archives annonce par GEODES (octets), si le manifeste existe.
  mf <- file.path(racine("archive"), "manifest", tuile, "manifest.json")
  vol_archives <- if (file.exists(mf)) {
    sum(as.numeric(jsonlite::read_json(mf, simplifyVector = TRUE)$filesize),
        na.rm = TRUE)
  } else NA_real_
  cmp <- ns$.reconfort_comparer_acquisitions(
    file.path(racine("archive"), "extracted", tuile),
    file.path(racine("fenetre"), "extracted", tuile))
  utils::write.csv(cmp$fichiers, file.path(sortie, "comparaison.csv"),
                   row.names = FALSE)
  resume <- data.frame(
    duree_archive_s = m_arch$duree_s, duree_fenetre_s = m_fen$duree_s,
    octets_recus_archive = m_arch$octets, octets_recus_fenetre = m_fen$octets,
    octets_archives_annonces = vol_archives,
    fichiers_communs = cmp$resume$n_communs,
    fichiers_identiques = cmp$resume$n_identiques,
    ecart_max = cmp$resume$ecart_max,
    seulement_archive = length(cmp$resume$seulement_archive),
    seulement_fenetre = length(cmp$resume$seulement_fenetre),
    conforme = cmp$resume$conforme)
  utils::write.csv(resume, file.path(sortie, "resume.csv"), row.names = FALSE)
  print(t(resume))
  if (length(cmp$resume$seulement_archive)) {
    cat("\nFichiers de l'archive absents de la voie fenetre :\n")
    print(cmp$resume$seulement_archive)
  }
  invisible(list(resume = resume, comparaison = cmp))
}

if (!interactive() && sys.nframe() == 0L) {
  a <- commandArgs(trailingOnly = TRUE)
  if (length(a) != 5L) stop("Usage : comparer_acquisitions.R zone.gpkg tuile date_debut date_fin sortie")
  comparer_acquisitions(a[1], a[2], a[3], a[4], a[5])
}
