# resineux.R — source unique de la notion « résineux » (audit 1.0).
# ------------------------------------------------------------------
# Trois définitions concurrentes coexistaient : la liste `.conifer_codes` de
# site_index.R (courbes de hauteur, repli de genre, auto-éclaircie, inventaire
# synthétique), le motif `^P[IML]` de P3 (qui ratait ABAL, PSME, LADE, CEAT et
# prenait le platane PLAC pour un pin) et la règle des codes IFN 51-79 de
# `.ifn_groupe_espar()`. PIHA, PILA et LAKA tombaient ainsi sur la courbe
# feuillue. Les trois consomment désormais `.est_resineux()`.

# Codes essence à 4 lettres (genre + espèce, style IFN / Charru) des
# résineux. Un code absent n'est PAS un résineux : la liste se complète ici,
# et seulement ici.
.CODES_RESINEUX <- c(
  # Sapins
  "ABAL", "ABGR", "ABNO", "ABCE", "ABPI",
  # Épicéas
  "PIAB", "PISI", "PIOM",
  # Pins
  "PISY", "PINI", "PILA", "PIPI", "PIHA", "PIPN", "PIUN", "PICE", "PIST",
  "PIRA", "PICO",
  # Douglas
  "PSME",
  # Mélèzes
  "LADE", "LAKA", "LAEU",
  # Cèdres
  "CEAT", "CEDE", "CELI",
  # Autres résineux
  "JUCO", "TABA", "THPL", "TSHE", "CUSE", "CHLA", "SEGI", "SESE"
)

# Seuils de la règle IGN sur les codes espar numériques : 51 (pin maritime)
# à 79 sont des résineux ; tout le reste est feuillu (chênes 02-07, hêtre 09
# compris). Vérifié sur espar-cdref13.
.ESPAR_RESINEUX_MIN <- 51L
.ESPAR_RESINEUX_MAX <- 79L

# Vectorisé. `code` : code essence à 4 lettres (insensible à la casse) ou code
# espar IFN (« 64 », « 09 », 64L). NA ou inconnu -> FALSE.
.est_resineux <- function(code) {
  code <- trimws(as.character(code))
  out <- rep(FALSE, length(code))
  if (!length(code)) return(out)
  num <- !is.na(code) & grepl("^[0-9]", code)
  if (any(num)) {
    n <- suppressWarnings(as.integer(sub("^([0-9]+).*$", "\\1", code[num])))
    out[num] <- !is.na(n) & n >= .ESPAR_RESINEUX_MIN & n <= .ESPAR_RESINEUX_MAX
  }
  alpha <- !is.na(code) & !num
  out[alpha] <- toupper(code[alpha]) %in% .CODES_RESINEUX
  out
}
