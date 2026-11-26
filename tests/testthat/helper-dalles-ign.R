# Aides de test partagees (mission 085) : dalles ecrites avec le SRS des dalles IGN.

# WKT lu dans une vraie dalle MNH LiDAR HD de l'IGN (LHD_FXX_0371_6389_MNH_0M50,
# telechargee le 2026-11-26 via la Geoplateforme) : SRS nomme « EPSG:2154 »,
# sans bloc d'autorite, ellipsoide « WGS84 » d'un datum sans nom.
.wkt_dalle_ign <- paste0(
  "PROJCRS[\"EPSG:2154\",BASEGEOGCRS[\"unknown\",DATUM[\"unnamed\",ELLIPSOID[\"u",
  "nretrievable - using WGS84\",6378137,298.257223563,LENGTHUNIT[\"metre\",1",
  ",ID[\"EPSG\",9001]]]],PRIMEM[\"Greenwich\",0,ANGLEUNIT[\"degree\",0.01745329",
  "25199433,ID[\"EPSG\",9122]]]],CONVERSION[\"Lambert Conic Conformal (2SP)\"",
  ",METHOD[\"Lambert Conic Conformal (2SP)\",ID[\"EPSG\",9802]],PARAMETER[\"La",
  "titude of false origin\",46.5,ANGLEUNIT[\"degree\",0.0174532925199433],ID",
  "[\"EPSG\",8821]],PARAMETER[\"Longitude of false origin\",3,ANGLEUNIT[\"degr",
  "ee\",0.0174532925199433],ID[\"EPSG\",8822]],PARAMETER[\"Latitude of 1st st",
  "andard parallel\",49,ANGLEUNIT[\"degree\",0.0174532925199433],ID[\"EPSG\",8",
  "823]],PARAMETER[\"Latitude of 2nd standard parallel\",44,ANGLEUNIT[\"degr",
  "ee\",0.0174532925199433],ID[\"EPSG\",8824]],PARAMETER[\"Easting at false o",
  "rigin\",700000,LENGTHUNIT[\"metre\",1],ID[\"EPSG\",8826]],PARAMETER[\"Northi",
  "ng at false origin\",6600000,LENGTHUNIT[\"metre\",1],ID[\"EPSG\",8827]]],CS",
  "[Cartesian,2],AXIS[\"easting\",east,ORDER[1],LENGTHUNIT[\"metre\",1,ID[\"EP",
  "SG\",9001]]],AXIS[\"northing\",north,ORDER[2],LENGTHUNIT[\"metre\",1,ID[\"EP",
  "SG\",9001]]]]"
)

.ecrire_dalle_ign <- function(dossier, nom, xmin, valeur, res = 0.5) {
  r <- terra::rast(xmin = xmin, xmax = xmin + 10, ymin = 0, ymax = 10,
                   resolution = res, crs = "EPSG:2154")
  terra::values(r) <- valeur
  tmp <- file.path(dossier, paste0("tmp_", nom))
  terra::writeRaster(r, tmp, overwrite = TRUE)
  f <- file.path(dossier, nom)
  sf::gdal_utils("translate", tmp, f, options = c("-a_srs", .wkt_dalle_ign), quiet = TRUE)
  unlink(tmp)
  f
}
