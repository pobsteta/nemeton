# data-raw/fiche_diagrams.R
#
# Genere le bloc <figure><svg>...</svg><figcaption></figure> de la section
# « Diagramme d'ensemble » des fiches indicateurs (vignettes/fiche-*.Rmd),
# puis l'injecte entre les marqueurs
#
#     <!-- diagramme:auto:debut -->
#     <!-- diagramme:auto:fin -->
#
# Contrainte de rendu (pandoc) : un bloc HTML brut se termine a la PREMIERE
# ligne vide. Le SVG genere ne contient donc AUCUNE ligne vide, sinon pandoc
# rend la suite en markdown et le diagramme part en paragraphes de texte
# (defaut observe sur la fiche C1, gh-pages 0.192.0).
#
# Usage : Rscript data-raw/fiche_diagrams.R
#         Rscript data-raw/fiche_diagrams.R c1 w3   # seulement ces fiches

# ---------------------------------------------------------------- geometrie --
W_TOTAL   <- 820
COL_E     <- c(x = 8,   w = 252)   # entrees
COL_C     <- c(x = 288, w = 262)   # calcul
COL_A     <- c(x = 586, w = 226)   # aval
BUS_X     <- 566                   # colonne de convergence des chemins
Y_HEADER  <- 16
Y_TOP     <- 34
GAP_BOX   <- 14
ACCENT    <- "#2C6B60"

`%||%` <- function(a, b) if (is.null(a)) b else a

.esc <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

# Hauteur d'une boite : titre + n lignes.
.box_h <- function(lignes) 26 + 16 * length(lignes)

# Largeur approchee d'une ligne, pour l'avertissement de debordement.
.text_w <- function(txt, size, mono = FALSE) {
  nchar(txt) * size * if (mono) 0.605 else 0.53
}

.check_fit <- function(txt, size, w, ou, mono = FALSE) {
  if (.text_w(txt, size, mono) > w - 24) {
    warning(sprintf("[%s] ligne trop large (%d car.) : %s", ou, nchar(txt), txt),
            call. = FALSE)
  }
  invisible(NULL)
}

# Une boite = cadre + titre + lignes. `mono` : lignes en chasse fixe.
.box <- function(x, y, w, titre, lignes = character(), accent = FALSE,
                 mono = TRUE, tirets = FALSE, ou = "") {
  h <- .box_h(lignes)
  col <- if (accent) ACCENT else "currentColor"
  fill <- if (accent) sprintf("%s0F", ACCENT) else "none"
  out <- sprintf(
    paste0('<rect x="%s" y="%s" width="%s" height="%s" rx="3" fill="%s" ',
           'stroke="%s" stroke-width="1.2" opacity="%s"%s/>'),
    x, y, w, h, fill, col, if (accent) ".95" else ".75",
    if (tirets) ' stroke-dasharray="4 3"' else ""
  )
  .check_fit(titre, 12.5, w, ou)
  out <- c(out, sprintf(
    '<text x="%s" y="%s" font-size="12.5" font-weight="600" fill="%s">%s</text>',
    x + 12, y + 19, col, .esc(titre)
  ))
  fam <- if (mono) ' font-family="ui-monospace,SFMono-Regular,Menlo,monospace"' else ""
  for (i in seq_along(lignes)) {
    .check_fit(lignes[i], 11, w, ou, mono = mono)
    out <- c(out, sprintf(
      '<text x="%s" y="%s" font-size="11"%s fill="currentColor" opacity=".78">%s</text>',
      x + 12, y + 19 + 16 * i, fam, .esc(lignes[i])
    ))
  }
  out
}

.fleche_h <- function(x1, x2, y, accent = FALSE) sprintf(
  paste0('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="1.2" ',
         'opacity=".75" marker-end="url(#fd)"/>'),
  x1, y, x2, y, if (accent) ACCENT else "currentColor"
)

.fleche_v <- function(x, y1, y2, tirets = FALSE) sprintf(
  paste0('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="currentColor" ',
         'stroke-width="1.2" opacity=".75"%s marker-end="url(#fd)"/>'),
  x, y1, x, y2, if (tirets) ' stroke-dasharray="3 3"' else ""
)

.legende <- function(x, y, txt, ancre = "start") sprintf(
  paste0('<text x="%s" y="%s" font-size="10" fill="currentColor" opacity=".55" ',
         'text-anchor="%s">%s</text>'),
  x, y, ancre, .esc(txt)
)

# Bandeau de la colonne centrale, et mot porte par les fleches qui relient
# les boites de calcul entre elles : « sinon » (cascade de replis), « + »
# (termes cumules), « ou » (modes exclusifs).
.entete <- function(spec) {
  if (!is.null(spec$entete)) return(spec$entete)
  if (length(spec$chemins) < 2) return("CALCUL")
  switch(spec$liaison %||% "sinon",
         "sinon" = "CALCUL — PREMIER CHEMIN SERVI",
         "+"     = "CALCUL — TERMES CUMULÉS",
         "ou"    = "CALCUL — MODES EXCLUSIFS",
         "puis"  = "CALCUL — ÉTAPES SUCCESSIVES",
         "CALCUL")
}

# ------------------------------------------------------------------ moteur ---
#
# spec :
#   code      "W1"
#   titre     phrase du aria-label (ce que le schema montre)
#   entrees   list(list(titre=, lignes=, vers=))   vers : index du chemin vise
#   chemins   list(list(titre=, lignes=, tirets=))  plusieurs = cascade « sinon »
#   aval      list(list(titre=, lignes=, accent=))
#   notes     character() : lignes de bas de figure
#   legende   texte du figcaption
#
fiche_svg <- function(spec) {
  ou <- spec$code

  # --- pile des entrees ------------------------------------------------------
  ye <- Y_TOP; ent_y <- numeric(0)
  for (e in spec$entrees) {
    ent_y <- c(ent_y, ye)
    ye <- ye + .box_h(e$lignes) + GAP_BOX
  }
  # --- pile des chemins ------------------------------------------------------
  yc <- Y_TOP; che_y <- numeric(0)
  for (k in spec$chemins) {
    che_y <- c(che_y, yc)
    yc <- yc + .box_h(k$lignes) + GAP_BOX + 20
  }
  # --- pile de l'aval : sa premiere boite s'aligne sur le premier chemin ------
  ya <- che_y[1]; av_y <- numeric(0)
  for (a in spec$aval) {
    av_y <- c(av_y, ya)
    ya <- ya + .box_h(a$lignes) + GAP_BOX + 8
  }

  body <- character(0)

  # bandeaux de colonnes
  body <- c(body,
    '<g fill="currentColor" font-size="10" letter-spacing="1.3" opacity=".55">',
    sprintf('<text x="%s" y="%s">ENTRÉES</text>', COL_E["x"] + 2, Y_HEADER),
    sprintf('<text x="%s" y="%s">%s</text>', COL_C["x"] + 2, Y_HEADER,
            .entete(spec)),
    sprintf('<text x="%s" y="%s">AVAL</text>', COL_A["x"] + 2, Y_HEADER),
    '</g>')

  # entrees
  for (i in seq_along(spec$entrees)) {
    e <- spec$entrees[[i]]
    body <- c(body, .box(COL_E["x"], ent_y[i], COL_E["w"], e$titre, e$lignes,
                         mono = FALSE, tirets = isTRUE(e$tirets), ou = ou))
  }
  # chemins
  for (i in seq_along(spec$chemins)) {
    k <- spec$chemins[[i]]
    body <- c(body, .box(COL_C["x"], che_y[i], COL_C["w"], k$titre, k$lignes,
                         tirets = isTRUE(k$tirets), ou = ou))
  }
  # aval
  for (i in seq_along(spec$aval)) {
    a <- spec$aval[[i]]
    body <- c(body, .box(COL_A["x"], av_y[i], COL_A["w"], a$titre, a$lignes,
                         accent = isTRUE(a$accent), ou = ou))
  }

  # fleches entrees -> chemins
  for (i in seq_along(spec$entrees)) {
    e <- spec$entrees[[i]]
    cible <- if (!is.null(e$vers)) e$vers else min(i, length(spec$chemins))
    y1 <- ent_y[i] + .box_h(e$lignes) / 2
    y2 <- che_y[cible] + .box_h(spec$chemins[[cible]]$lignes) / 2
    x1 <- COL_E["x"] + COL_E["w"]; x2 <- COL_C["x"] - 6
    if (abs(y1 - y2) < 1) {
      body <- c(body, .fleche_h(x1, x2, y1))
    } else {
      body <- c(body, sprintf(
        paste0('<path d="M%s %s H%s V%s H%s" fill="none" stroke="currentColor" ',
               'stroke-width="1.2" opacity=".75" marker-end="url(#fd)"/>'),
        x1, y1, (x1 + x2) / 2, y2, x2))
    }
  }

  # cascade « sinon » entre chemins
  if (length(spec$chemins) > 1) {
    for (i in seq_len(length(spec$chemins) - 1)) {
      y1 <- che_y[i] + .box_h(spec$chemins[[i]]$lignes)
      y2 <- che_y[i + 1] - 6
      xs <- COL_C["x"] + 18
      mot <- spec$liaison %||% "sinon"
      body <- c(body, .fleche_v(xs, y1 + 2, y2, tirets = !(mot %in% c("+", "puis"))),
                .legende(xs + 6, (y1 + y2) / 2 + 4, mot))
    }
  }

  # chemins -> bus -> premiere boite d'aval
  y_bus1 <- che_y[1] + .box_h(spec$chemins[[1]]$lignes) / 2
  if (length(spec$chemins) > 1) {
    dernier <- length(spec$chemins)
    y_busN <- che_y[dernier] + .box_h(spec$chemins[[dernier]]$lignes) / 2
    for (i in seq_along(spec$chemins)) {
      yi <- che_y[i] + .box_h(spec$chemins[[i]]$lignes) / 2
      body <- c(body, sprintf(
        paste0('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" ',
               'stroke-width="1.2" opacity=".6"/>'),
        COL_C["x"] + COL_C["w"], yi, BUS_X, yi, ACCENT))
    }
    body <- c(body, sprintf(
      '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="1.2" opacity=".6"/>',
      BUS_X, y_bus1, BUS_X, y_busN, ACCENT))
  } else {
    body <- c(body, sprintf(
      '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="1.2" opacity=".6"/>',
      COL_C["x"] + COL_C["w"], y_bus1, BUS_X, y_bus1, ACCENT))
  }
  body <- c(body, .fleche_h(BUS_X, COL_A["x"] - 6, y_bus1, accent = TRUE))

  # chaine verticale de l'aval
  for (i in seq_len(length(spec$aval) - 1)) {
    y1 <- av_y[i] + .box_h(spec$aval[[i]]$lignes) + 2
    y2 <- av_y[i + 1] - 6
    body <- c(body, .fleche_v(COL_A["x"] + COL_A["w"] / 2, y1, y2))
  }

  # notes de bas de figure
  bas <- max(c(ent_y[length(ent_y)] + .box_h(spec$entrees[[length(spec$entrees)]]$lignes),
               che_y[length(che_y)] + .box_h(spec$chemins[[length(spec$chemins)]]$lignes),
               av_y[length(av_y)] + .box_h(spec$aval[[length(spec$aval)]]$lignes)))
  y_note <- bas + 26
  for (n in spec$notes) {
    body <- c(body, sprintf(
      '<text x="%s" y="%s" font-size="10.5" fill="currentColor" opacity=".62">%s</text>',
      COL_E["x"] + 2, y_note, .esc(n)))
    y_note <- y_note + 16
  }
  hauteur <- ceiling(y_note + 2)

  c(
    "<figure>",
    sprintf(paste0('<svg viewBox="0 0 %s %s" style="width:100%%;height:auto;',
                   'max-width:100%%" role="img" aria-label="%s">'),
            W_TOTAL, hauteur, .esc(spec$titre)),
    '<defs>',
    paste0('<marker id="fd" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" ',
           'markerHeight="6" orient="auto-start-reverse">'),
    '<path d="M0,0 L10,5 L0,10 z" fill="currentColor"/>',
    '</marker>',
    '</defs>',
    body,
    "</svg>",
    '<figcaption style="font-size:.9em;opacity:.75">',
    spec$legende,
    "</figcaption>",
    "</figure>"
  )
}

# --------------------------------------------------------------- injection ---
DEBUT <- "<!-- diagramme:auto:debut -->"
FIN   <- "<!-- diagramme:auto:fin -->"

injecter <- function(fichier, bloc) {
  lignes <- readLines(fichier, encoding = "UTF-8", warn = FALSE)
  i <- which(trimws(lignes) == DEBUT)
  j <- which(trimws(lignes) == FIN)
  if (length(i) != 1L || length(j) != 1L || j <= i) {
    stop("marqueurs diagramme:auto absents ou mal places dans ", fichier)
  }
  nouv <- c(lignes[seq_len(i)], bloc, lignes[j:length(lignes)])
  if (any(trimws(bloc) == "")) stop("bloc SVG avec ligne vide : ", fichier)
  writeLines(nouv, fichier, useBytes = TRUE)
  invisible(length(bloc))
}

# ------------------------------------------------------------------- pilote --
# A lancer depuis la racine du paquet.

source_specs <- function(chemin = "data-raw/fiche_diagrams_data.R") {
  e <- new.env(parent = globalenv())
  sys.source(chemin, envir = e)
  get("FICHES", envir = e)
}

generer <- function(codes = NULL, dossier = "vignettes") {
  specs <- source_specs()
  if (!is.null(codes) && length(codes)) {
    specs <- specs[tolower(names(specs)) %in% tolower(codes)]
  }
  for (nom in names(specs)) {
    spec <- specs[[nom]]
    f <- file.path(dossier, spec$fichier)
    if (!file.exists(f)) { warning("fiche absente : ", f, call. = FALSE); next }
    n <- injecter(f, fiche_svg(spec))
    message(sprintf("%-4s %-46s %3d lignes de SVG", spec$code, spec$fichier, n))
  }
  invisible(TRUE)
}

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  generer(if (length(args)) args else NULL)
}
