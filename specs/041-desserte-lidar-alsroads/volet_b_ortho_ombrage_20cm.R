# Volet B ter — MNT 20 cm recalcule depuis les retours SOL du nuage brut.
# Densite sol mesuree : 7,5 pts/m2, espacement moyen 0,36 m. Le 20 cm est donc
# SOUS l'espacement reel : ~1 cellule sur 3 contient un point, le reste est
# interpole (TIN). Gain de LISIBILITE, pas d'information nouvelle.
suppressMessages({library(sf); library(terra); library(lidR); library(png)})
setwd("/tmp/claude-1000/-home-pascal-dev-nemeton/e5c6653b-a340-46f6-bd64-4245d3f8b8be/scratchpad")

D <- path.expand("~/.local/share/nemeton/tutorial_data")
ctg <- readLAScatalog(file.path(D,"lidar_hd","NUALHD_1-0__LAZ_LAMB93_PM_2025-03-25"))
opt_progress(ctg) <- FALSE
routes <- st_read(file.path(D,"routes.gpkg"), quiet=TRUE)

emprise <- st_as_sfc(st_bbox(c(xmin=895000, ymin=6448000, xmax=898000, ymax=6454000),
                             crs=st_crs(routes)))
routes <- routes[st_intersects(routes, emprise, sparse=FALSE)[,1],]
routes$longueur_m <- as.numeric(st_length(routes))
routes <- routes[routes$longueur_m >= 50,]
set.seed(42)
idx <- unlist(lapply(split(seq_len(nrow(routes)), routes$nature), function(i)
  if (length(i) <= 10) i else sample(i, 10)))
ech <- routes[idx,]
res <- readRDS("volet_a_resultats.rds")
ech$largeur_mesuree <- res$largeur; ech$score <- res$score
sel <- do.call(rbind, lapply(split(seq_len(nrow(ech)), ech$nature), function(i) {
  w <- ech$largeur_mesuree[i]
  ech[i[order(abs(w - median(w, na.rm=TRUE)))[1:min(2,length(i))]],]
}))

ortho <- function(bb, px=800) {
  u <- sprintf(paste0("https://data.geopf.fr/wms-r/wms?SERVICE=WMS&VERSION=1.3.0",
    "&REQUEST=GetMap&LAYERS=ORTHOIMAGERY.ORTHOPHOTOS&STYLES=&CRS=EPSG:2154",
    "&BBOX=%f,%f,%f,%f&WIDTH=%d&HEIGHT=%d&FORMAT=image/png"),
    bb[["xmin"]],bb[["ymin"]],bb[["xmax"]],bb[["ymax"]],px,px)
  f <- tempfile(fileext=".png"); download.file(u,f,quiet=TRUE,mode="wb")
  a <- png::readPNG(f)
  r <- rast(nrows=dim(a)[1], ncols=dim(a)[2], nlyrs=3,
            xmin=bb[["xmin"]], xmax=bb[["xmax"]], ymin=bb[["ymin"]], ymax=bb[["ymax"]],
            crs="EPSG:2154")
  for (k in 1:3) values(r[[k]]) <- as.vector(t(a[,,k]))*255
  r
}

RES <- as.numeric(Sys.getenv("MNT_RES", "0.2"))
for (k in seq_len(nrow(sel))) {
  s <- sel[k,]
  cc <- unname(st_coordinates(st_line_sample(st_cast(st_geometry(s),"LINESTRING"), sample=0.5))[1,1:2])
  half <- 25
  bb <- c(xmin=cc[1]-half, ymin=cc[2]-half, xmax=cc[1]+half, ymax=cc[2]+half)

  # Marge de 10 m : le TIN est instable au bord de l'emprise decoupee.
  la <- tryCatch(clip_rectangle(ctg, bb[["xmin"]]-10, bb[["ymin"]]-10,
                                bb[["xmax"]]+10, bb[["ymax"]]+10),
                 error=function(e) NULL)
  if (is.null(la) || npoints(la) == 0) { cat("pas de points", k, "\n"); next }
  mnt <- tryCatch(rasterize_terrain(la, res=RES, algorithm=tin()),
                  error=function(e) {cat("echec TIN",k,":",conditionMessage(e),"\n"); NULL})
  if (is.null(mnt)) next
  mnt <- crop(mnt, ext(bb[["xmin"]],bb[["xmax"]],bb[["ymin"]],bb[["ymax"]]))

  sl <- terrain(mnt,"slope",unit="radians"); as_ <- terrain(mnt,"aspect",unit="radians")
  hs <- Reduce(`+`, lapply(c(0,90,180,270), function(az) shade(sl,as_,angle=35,direction=az)))/4

  img <- tryCatch(ortho(bb), error=function(e) NULL)
  w <- s$largeur_mesuree
  bande <- st_buffer(st_geometry(s), w/2)

  nom <- sprintf("voletB3_%02d_%s_%.1fm.png", k, gsub("[^a-zA-Z]","",s$nature), w)
  png(nom, width=1500, height=830)
  par(mfrow=c(1,2), mar=c(0,0,2.2,0), oma=c(0,0,3.4,0))
  if (!is.null(img)) { plotRGB(img, mar=NA, axes=FALSE); title("Orthophoto IGN 20 cm", cex.main=1.4) } else plot.new()
  plot(bande, add=TRUE, border="#00E5FF", lwd=3, col=NA)
  plot(st_geometry(s), add=TRUE, col="#FF1744", lwd=2, lty=2)
  plot(hs, col=grey(0:255/255), legend=FALSE, axes=FALSE, mar=NA)
  title(sprintf("Ombrage MNT %.0f cm (TIN sur retours sol)", RES*100), cex.main=1.4)
  plot(bande, add=TRUE, border="#00E5FF", lwd=3, col=NA)
  plot(st_geometry(s), add=TRUE, col="#FF1744", lwd=2, lty=2)
  mtext(sprintf("%s — DRIVABLEWIDTH = %.2f m (score %.0f)   |   cyan = largeur ALSroads, rouge = axe BD TOPO",
                s$nature, w, s$score), outer=TRUE, cex=1.5, font=2, line=0.7)
  dev.off()
  cat("ecrit:", nom, "\n")
}
