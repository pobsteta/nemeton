#!/usr/bin/env Rscript
# Tirage des 14 zones de l'étude (brief § 3.1) -> zones.csv, versionné avec le script.
#   Rscript data-raw/etude_fast_decoloration/choisir_zones.R
# Déterministe (graine 45 pour le seul groupe « melange »). Comme comparaison_nemeton.R :
# communes de plus fort / plus faible taux d'alerte 2021 de la décoloration, carré de
# 3 km centré sur la plus forte densité de l'essence (BD Forêt V2). « melange » : carrés
# où la forêt publique est dense et la BD Forêt cible (4 essences) absente, séparés de 20 km
# (là, seul FAST existe ; la décoloration est « non_applicable »).
suppressPackageStartupMessages({ library(terra); library(sf) })
rep_script <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
source(file.path(rep_script, "fonctions.R"))
DEC <- Sys.getenv("DECOLORATION_DIR", path.expand("~/dev/rapport_decoloration_bfc"))
ANNEE_TAUX <- 2021L; COTE <- 3000; PART_MIN <- 0.25
ESS <- c(chene = 1L, hetre = 2L, sapin_epicea = 3L, douglas = 4L)
SURF_MIN <- c(chene = 200, hetre = 200, sapin_epicea = 150, douglas = 150)

ic <- utils::read.csv(file.path(DEC, "sortie_decoloration/indicateurs/indicateurs_commune_statut_essence_annee.csv"),
                      colClasses = c(code_commune = "character", departement = "character"))
ic <- ic[ic$annee == ANNEE_TAUX & ic$essence %in% names(ESS), ]
ag <- stats::aggregate(cbind(surf_ha, surf_alerte_ha) ~ code_commune + nom_commune + departement + essence, ic, sum)
ag$taux_touche <- 100 * ag$surf_alerte_ha / ag$surf_ha
ag <- ag[ag$surf_ha >= SURF_MIN[ag$essence], ]
cand <- data.frame(commune = ag$code_commune, nom = ag$nom_commune, departement = ag$departement,
                   groupe = ag$essence, taux_touche = ag$taux_touche)

com <- st_transform(st_read(file.path(DEC, "donnees/ign_communes_r27.gpkg"), quiet = TRUE), 2154)
bdf <- st_transform(st_read(file.path(DEC, "donnees/ign_bdforet_v2_r27.gpkg"), quiet = TRUE), 2154)

# carré 3 km centré sur la plus forte densité de l'essence dans la commune (aligné sur 20 m)
carre <- function(code, ess_id) {
  cg <- com[com$CODE_COMMUNE == code, ]
  if (!nrow(cg)) return(NULL)
  b <- bdf[bdf$ess_id == ess_id & lengths(st_intersects(bdf, st_buffer(cg, 2000))) > 0, ]
  if (!nrow(b)) return(NULL)
  g <- rast(ext(vect(st_buffer(cg, 2000))), resolution = 100, crs = "EPSG:2154")
  dens <- rasterize(vect(b), g, cover = TRUE, background = 0)
  f <- mask(focal(dens, matrix(1, 31, 31), fun = "mean", na.rm = FALSE), vect(cg))
  if (all(is.na(values(f)))) return(NULL)
  i <- which.max(values(f)); xy <- xyFromCell(f, i); part <- values(f)[i]
  if (!is.finite(part) || part < PART_MIN) return(NULL)
  c(xmin = round((xy[1] - COTE / 2) / 20) * 20, ymin = round((xy[2] - COTE / 2) / 20) * 20, part = round(100 * part, 1))
}

# on tire, puis on remplace une commune sans carré assez dense par la suivante
retenues <- list(); ecartees <- character()
repeat {
  z <- tirer_zones(cand[!cand$commune %in% ecartees, ], n_melange = 0L)
  nouv <- FALSE
  for (i in seq_len(nrow(z))) {
    k <- paste(z$commune[i], z$groupe[i])
    if (!is.null(retenues[[k]])) next
    r <- carre(z$commune[i], ESS[[z$groupe[i]]])
    if (is.null(r)) { ecartees <- c(ecartees, z$commune[i]); nouv <- TRUE; break }
    retenues[[k]] <- data.frame(z[i, c("commune", "nom", "departement", "groupe", "strate")],
                                xmin = r[["xmin"]], ymin = r[["ymin"]], part_essence_zone = r[["part"]],
                                taux_touche = z$taux_touche[i])
  }
  if (!nouv) break
}
Z <- do.call(rbind, retenues)

# groupe « melange » : forêt publique dense, aucune des 4 essences
pub <- st_transform(st_read(file.path(DEC, "donnees/ign_forets_publiques_r27.gpkg"), quiet = TRUE), 2154)
reg <- rast(ext(vect(com)), resolution = 100, crs = "EPSG:2154")
dp <- rasterize(vect(pub), reg, cover = TRUE, background = 0)
db <- rasterize(vect(bdf), reg, cover = TRUE, background = 0)
mel <- focal(clamp(dp - db, 0, 1), matrix(1, 31, 31), fun = "mean", na.rm = FALSE)
mel <- mask(mel, vect(com))
for (j in 1:2) {
  i <- which.max(values(mel)); xy <- xyFromCell(mel, i); part <- values(mel)[i]
  Z <- rbind(Z, data.frame(commune = NA, nom = sprintf("melange_%d", j), departement = NA,
                           groupe = "melange", strate = "melange",
                           xmin = round((xy[1] - COTE / 2) / 20) * 20, ymin = round((xy[2] - COTE / 2) / 20) * 20,
                           part_essence_zone = round(100 * part, 1), taux_touche = NA))
  mel[cellFromXY(mel, cbind(xy[1], xy[2])) -> c0] <- NA
  mel <- mask(mel, vect(st_buffer(st_sfc(st_point(xy), crs = 2154), 20000)), inverse = TRUE)
}
Z$zone <- sprintf("Z%02d_%s_%s", seq_len(nrow(Z)), Z$groupe, sub("^tres_touchee$", "fort", sub("^peu_touchee$", "faible", Z$strate)))
Z$graine <- 45L
utils::write.csv(Z[, c("zone", "xmin", "ymin", "groupe", "strate", "commune", "nom", "departement",
                       "taux_touche", "part_essence_zone", "graine")],
                 file.path(rep_script, "zones.csv"), row.names = FALSE)
print(Z[, c("zone", "nom", "xmin", "ymin", "taux_touche", "part_essence_zone")])
