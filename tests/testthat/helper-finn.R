# Jeux de demonstration FINN, partages par test-calibrer_finn.R et
# test-simuler_itineraire.R (spec 068).

arbres_finn_demo <- function(n_pla = 6) {
  set.seed(1)
  do.call(rbind, lapply(seq_len(n_pla), function(p) {
    n <- 8
    d1 <- round(runif(n, 10, 50), 1)
    statut <- c(rep("vivant", 5), "mort", "coupe", "vivant")
    d2 <- ifelse(statut == "vivant", d1 + runif(n, 0, 2), NA)
    rec <- data.frame(placette = paste0("P", p), essence = "09", d1 = NA,
                      d2 = 8, poids = 88.4, statut = "recrute")
    rbind(data.frame(placette = paste0("P", p),
                     essence = c("09", "09", "03", "03", "62", "09", "03", "51"),
                     d1 = d1, d2 = d2, poids = 14.1, statut = statut), rec)
  }))
}
env_finn_demo <- function(n_pla = 6) {
  data.frame(placette = paste0("P", seq_len(n_pla)), tx_ete = 22 + seq_len(n_pla) / 10,
             rr_an = 900 + 10 * seq_len(n_pla))
}
