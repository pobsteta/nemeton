# reconfort_comparaison.R — accord entre deux cartes de classes RECONFORT
# (mission 071, point 4b) : carte IOTA2 officielle contre carte du spike
# (mission 060). Interne : appelee par data-raw/comparaison_reconfort/.

# Accord entre la carte IOTA2 (`iota2`, reference de grille) et la carte du
# spike (`spike`), classes 1 a 3. Rend la matrice de confusion (lignes IOTA2,
# colonnes spike), l'accord global, le kappa de Cohen (indicateur seulement),
# l'accord par classe (rappel = part des pixels IOTA2 de la classe retrouves par
# le spike ; precision = part des pixels spike de la classe qui sont IOTA2) et
# les surfaces par classe (ha) de chaque carte sur les pixels compares.
.reconfort_accord_cartes <- function(iota2, spike, classes = 1:3) {
  if (is.character(iota2)) iota2 <- terra::rast(iota2)
  if (is.character(spike)) spike <- terra::rast(spike)
  cmp <- reconfort_comparer_amont(carte = iota2, amont = spike)
  conf <- unclass(cmp$confusion)
  dimnames(conf) <- list(iota2 = as.character(classes),
                         spike = as.character(classes))
  n <- sum(conf)
  po <- if (n > 0) sum(diag(conf)) / n else NA_real_
  pe <- if (n > 0) sum(rowSums(conf) * colSums(conf)) / n^2 else NA_real_
  kappa <- if (is.na(po) || isTRUE(all.equal(pe, 1))) NA_real_ else (po - pe) / (1 - pe)
  rec <- ifelse(rowSums(conf) > 0, diag(conf) / rowSums(conf), NA_real_)
  pre <- ifelse(colSums(conf) > 0, diag(conf) / colSums(conf), NA_real_)
  ha_px <- prod(terra::res(iota2)) / 1e4
  par_classe <- data.frame(
    classe = classes,
    surface_iota2_ha = rowSums(conf) * ha_px,
    surface_spike_ha = colSums(conf) * ha_px,
    rappel = as.numeric(rec), precision = as.numeric(pre),
    row.names = NULL)
  list(n = n, surface_comparee_ha = n * ha_px, confusion = conf,
       accord = po, kappa = kappa, par_classe = par_classe)
}
