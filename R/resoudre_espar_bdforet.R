# resoudre_espar_bdforet.R — code ESPAR d'un libellé d'essence BD Forêt v2.
# ------------------------------------------------------------------
# Brief nemetonshiny 2026-11-16 (T4 : 34 UGF sur 63 sans essence à Couchey).
# Voie (b) retenue par Pascal le 2026-11-16 : le cœur publie la convention.
# Un libellé de GROUPE (« Chênes décidus », « Sapin, épicéa »…) prend
# l'essence majoritaire en volume à l'hectare de l'IFN dans la SER, à défaut
# la GRECO, à défaut la France (ifn_volume_essence_ser.csv). Rien n'est
# deviné : la table des groupes est inst/extdata/bdforet_essence_espar.csv,
# les libellés génériques (Feuillus, Conifères, Mixte…) rendent NA.

#' ESPAR code of a BD Forêt essence label
#'
#' @description
#' Resolves a BD Forêt v2 essence label to an IFN ESPAR code, including the
#' **group** labels that [resoudre_espar()] leaves unresolved because they
#' name several species ("Chênes décidus", "Pin laricio, pin noir",
#' "Sapin, épicéa", "Mélèze", "Peuplier"…). A group label takes its member
#' with the largest IFN standing volume per hectare (`vol_ha_maille` of
#' `ifn_volume_essence_ser.csv`) in the unit's SER; failing that (no SER, or
#' no member measured there), in the SER's GRECO; failing that, in France.
#' Single-species labels take their code; generic labels ("Feuillus",
#' "Conifères", "Mixte", "Pins mélangés", "NC", "NR"…) give `NA`: no code is
#' guessed. A label absent from the table falls back to [resoudre_espar()].
#'
#' The groups are listed in `inst/extdata/bdforet_essence_espar.csv`. For
#' "Sapin, épicéa" the rule gives silver fir (61) in France, as the former
#' application convention.
#'
#' @param libelle Character vector of BD Forêt essence labels (accents and
#'   case ignored).
#' @param ser Optional character vector of SER codes (e.g. `"C30"`), recycled
#'   to the length of `libelle`. `NULL` or `NA`: France-wide rule.
#'
#' @return A character vector of ESPAR codes, `NA` when unresolved.
#' @section Lifecycle:
#' Experimental: may change in any release, without deprecation (spec 057).
#'
#' @seealso [resoudre_espar()], [indicateur_t4_vitalite()]
#' @examples
#' resoudre_espar_bdforet(c("Hêtre", "Sapin, épicéa", "Feuillus"))
#' resoudre_espar_bdforet("Chênes décidus", ser = "C30")
#' @export
resoudre_espar_bdforet <- function(libelle, ser = NULL) {
  libelle <- as.character(libelle)
  n <- length(libelle)
  if (!n) return(character(0))
  if (is.null(ser)) ser <- NA_character_
  ser <- as.character(ser)
  if (!length(ser) %in% c(1L, n)) {
    cli::cli_abort("{.arg ser} must have length 1 or the length of {.arg libelle}.")
  }
  ser <- rep_len(ser, n)

  tab <- .bdforet_essence_table()
  cle <- .bdforet_cle(libelle)
  idx <- match(cle, .bdforet_cle(tab$libelle_bdforet))
  out <- rep(NA_character_, n)

  # Libellé hors table : repli sur la résolution générale.
  hors <- is.na(idx) & !is.na(libelle)
  if (any(hors)) out[hors] <- resoudre_espar(libelle[hors])

  dans <- which(!is.na(idx))
  if (length(dans)) {
    vol <- .bdforet_volumes()
    greco_de <- .bdforet_greco_de_ser()
    for (i in dans) {
      membres <- tab$membres[[idx[i]]]
      if (!length(membres)) next                       # générique -> NA
      if (length(membres) == 1L) { out[i] <- membres; next }
      out[i] <- .bdforet_majoritaire(membres, ser[i], greco_de, vol)
    }
  }
  out
}

# Normalisation des libellés : casse, espaces, accents et ponctuation ignorés.
.bdforet_cle <- function(x) {
  x <- tolower(trimws(enc2utf8(as.character(x))))
  x <- iconv(x, "UTF-8", "ASCII//TRANSLIT", sub = "")
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(x)
}

.bdforet_essence_table <- function() {
  f <- system.file("extdata", "bdforet_essence_espar.csv", package = "nemeton")
  t <- utils::read.csv2(f, colClasses = "character", encoding = "UTF-8",
                        fileEncoding = "UTF-8")
  t$membres <- lapply(strsplit(trimws(t$membres), "[[:space:]]+"),
                      function(v) v[nzchar(v)])
  t
}

.bdforet_volumes <- function() {
  f <- system.file("extdata", "ifn_volume_essence_ser.csv", package = "nemeton")
  v <- utils::read.csv(f, colClasses = "character", encoding = "UTF-8")
  v$vol_ha_maille <- as.numeric(v$vol_ha_maille)
  v
}

.bdforet_greco_de_ser <- function() {
  f <- system.file("extdata", "ser.csv", package = "nemeton")
  s <- utils::read.csv2(f, colClasses = "character", encoding = "UTF-8")
  stats::setNames(s$greco, s$code)
}

# Membre au plus fort volume à l'hectare, SER puis GRECO puis France. Égalité :
# l'ordre de la table (le premier listé) départage.
.bdforet_majoritaire <- function(membres, ser, greco_de, vol) {
  essais <- list()
  if (!is.na(ser) && nzchar(ser)) {
    essais$ser <- vol[vol$niveau == "ser" & vol$ser == ser, ]
    g <- unname(greco_de[ser])
    if (!is.na(g)) essais$greco <- vol[vol$niveau == "greco" & vol$greco == g, ]
  }
  essais$national <- vol[vol$niveau == "national", ]
  for (e in essais) {
    v <- e$vol_ha_maille[match(membres, e$espar)]
    if (any(v > 0, na.rm = TRUE)) return(membres[which.max(replace(v, is.na(v), -Inf))])
  }
  membres[[1]]
}
