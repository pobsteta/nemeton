# Jeux SYNTHETIQUES pour le spike de re-entrainement RECONFORT (mission 060).
# Prefixe `synth_` et colonne/attribut `synthetic = TRUE` : ce ne sont jamais des
# resultats sur donnees reelles (aucune placette DEPERIS publique n'existe).

# Placettes : `n_blocs` groupes de `par_bloc` placettes, un groupe par bloc de
# 1000 m ; releves en 2021 et 2022, classes tournantes 1, 2, 3.
synth_reconfort_placettes <- function(n_blocs = 8L, par_bloc = 3L, seed = 1L) {
  withr::local_seed(seed)
  n <- n_blocs * par_bloc
  bloc <- rep(seq_len(n_blocs), each = par_bloc)
  pe <- rep(c(0.05, 0.35, 0.80), length.out = n)
  data.frame(
    id_unique = sprintf("synth_%03d", seq_len(n)),
    date = 2022L,
    dep_cor = c(1L, 2L, 3L)[match(pe, c(0.05, 0.35, 0.80))],
    DEPERIS_pe = pe,
    x = 900000 + (bloc - 1L) * 1500 + runif(n, 0, 400),
    y = 6500000 + runif(n, 0, 400),
    synthetic = TRUE
  )
}

# Serie de bandes par placette, un pas de 10 jours, 2020-2022 ; le SWIR (B11)
# monte avec la classe a partir du jour 150 (signal de depérissement).
synth_reconfort_serie <- function(placettes, seed = 2L) {
  withr::local_seed(seed)
  dates <- seq(as.Date("2020-01-01"), as.Date("2024-12-31"), by = "10 days")
  out <- do.call(rbind, lapply(seq_len(nrow(placettes)), function(i) {
    cl <- placettes$dep_cor[i]
    doy <- as.integer(format(dates, "%j"))
    saison <- sin(pi * pmin(doy, 300) / 300)
    n <- length(dates)
    data.frame(
      id_unique = placettes$id_unique[i], date = dates,
      B4 = 0.05 + 0.01 * runif(n),
      B5 = 0.08 + 0.01 * runif(n),
      B6 = 0.20 + 0.05 * saison + 0.01 * runif(n),
      B8A = 0.35 + 0.1 * saison + 0.01 * runif(n),
      B11 = 0.20 + 0.04 * runif(n) + ifelse(doy > 150, 0.08 * (cl - 1), 0),
      B12 = 0.12 + 0.01 * runif(n),
      synthetic = TRUE
    )
  }))
  out
}
