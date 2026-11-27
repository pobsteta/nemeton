# reconfort_sharkrf.R - lecteur et predicteur du format SharkRF d'OTB (mission 095)
# ---------------------------------------------------------------------------
# Le modele RECONFORT v3 est un fichier texte `model_1_seed_0.txt` (en-tete
# `#RFClassifier with_dictionary`, puis une archive texte Boost de la
# bibliotheque Shark : 1000 arbres). Aucun paquet R ne le lit ; ce fichier le
# lit et l'applique SANS OTB, SANS conda et SANS IOTA2.
#
# Format (deduit par observation, etudes 091 et 093 de nemetonplateforme ; non
# documente par Shark) : trois lignes d'en-tete, puis 3 lignes par arbre :
#   ligne de noeuds : numero, N, trois jetons, puis N quadruplets
#                     (attribut, seuil, fils gauche, fils droit) ;
#   ligne de classes : numero, nombre de feuilles L, puis une classe (0-based)
#                     par feuille ;
#   ligne de 5 jetons.
# Une feuille a un fils gauche egal a 0 et un fils droit egal a son numero de
# feuille. Descente : x[attribut] <= seuil -> gauche, sinon droite. Un vote par
# arbre pour la classe de la feuille atteinte ; la probabilite IOTA2 est la
# proportion de votes en pour mille, la classe l'argmax (etudes 091 et 093).
#
# Representation compacte (index globaux 1-based sur l'ensemble des noeuds) :
#   attr   : attribut (0-based), -1 pour une feuille ;
#   seuil  : seuil du noeud ;
#   gauche : index du fils gauche ; pour une feuille, la classe (0-based) ;
#   droite : index du fils droit ;
#   racines: index de la racine de chaque arbre.

# Cache memoire des modeles lus (la lecture du fichier de 205 Mo prend
# quelques dizaines de secondes) ; cle = chemin normalise + taille + mtime.
.reconfort_sharkrf_cache <- new.env(parent = emptyenv())

#' Read a SharkRF random-forest model file (RECONFORT)
#'
#' Reads the text model file used by the RECONFORT v3 classifiers
#' (`model_1_seed_0.txt`, an OTB/Shark `RFClassifier` of 1000 trees) into a
#' compact object that [reconfort_sharkrf_predire()] can apply, without OTB,
#' conda or IOTA2. The result is cached in memory for the session (reading the
#' 205 MB file of the `v3` model takes tens of seconds), and, when `cache_dir`
#' is given, on disk as an `.rds` next to a checksum of the file's identity.
#'
#' The format is deduced from observation (studies 091 and 093 of the
#' platform), not from Shark's documentation; the reader checks the structure
#' (every child index inside its tree, leaf classes present) and fails with a
#' classed error (`nemeton_sharkrf_format`) when the file does not match.
#'
#' @param path Path to a `model_1_seed_0.txt` file.
#' @param cache_dir Optional directory for the on-disk cache of the parsed
#'   model. `NULL` (default) keeps the in-memory cache only.
#' @return An object of class `reconfort_sharkrf`: a list with `attr`, `seuil`,
#'   `gauche`, `droite`, `racines`, `n_arbres`, `n_vars`, `classes` (the class
#'   labels announced by the file header) and `source` (file size and mtime).
#' @export
#' @examples
#' f <- tempfile(fileext = ".txt")
#' writeLines(c("#RFClassifier with_dictionary", "2 1 2 ",
#'   "22 serialization::archive 18 0 0 1 0 0 1 0",
#'   "0 3 0 0 0 0 5.0e-01 1 2 0 0.0e+00 0 0 0 0.0e+00 0 1",
#'   "1 2 0 0 1 0 1 1 1 1 1",
#'   "2 1 0 3 3"), f)
#' m <- reconfort_sharkrf_lire(f)
#' reconfort_sharkrf_predire(m, matrix(c(0.2, 0.9), ncol = 1))
reconfort_sharkrf_lire <- function(path, cache_dir = NULL) {
  if (!is.character(path) || length(path) != 1L || !file.exists(path)) {
    cli::cli_abort("{.arg path} must be an existing SharkRF model file.")
  }
  info <- file.info(path)
  cle <- paste(normalizePath(path), info$size, as.numeric(info$mtime), sep = "|")
  if (exists(cle, envir = .reconfort_sharkrf_cache, inherits = FALSE)) {
    return(get(cle, envir = .reconfort_sharkrf_cache, inherits = FALSE))
  }
  rds <- NULL
  if (!is.null(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    rds <- file.path(cache_dir, sprintf("sharkrf_v2_%s.rds",
                                        .reconfort_sharkrf_empreinte(info)))
    if (file.exists(rds)) {
      m <- tryCatch(readRDS(rds), error = function(e) NULL)
      if (inherits(m, "reconfort_sharkrf")) {
        assign(cle, m, envir = .reconfort_sharkrf_cache)
        return(m)
      }
    }
  }
  m <- .reconfort_sharkrf_parser(path)
  m$source <- c(taille = info$size, mtime = as.numeric(info$mtime))
  if (!is.null(rds)) {
    tmp <- paste0(rds, ".tmp")
    if (isTRUE(tryCatch({ saveRDS(m, tmp); file.rename(tmp, rds) },
                        error = function(e) FALSE))) {
      invisible()
    } else {
      unlink(tmp)
    }
  }
  assign(cle, m, envir = .reconfort_sharkrf_cache)
  m
}

# Identifiant court d'un fichier pour le cache disque (taille + date, sans
# relire les 205 Mo).
.reconfort_sharkrf_empreinte <- function(info) {
  sprintf("%.0f_%.0f", info$size, as.numeric(info$mtime))
}

.reconfort_sharkrf_erreur <- function(msg) {
  cli::cli_abort(c("Not a RECONFORT SharkRF model: {msg}",
                   i = "Expected the text format read by the studies 091/093 (see {.fn reconfort_sharkrf_lire})."),
                 class = "nemeton_sharkrf_format")
}

.reconfort_sharkrf_parser <- function(path) {
  con <- file(path, open = "r")
  on.exit(close(con), add = TRUE)
  entete <- readLines(con, n = 3L, warn = FALSE)
  if (length(entete) < 3L || !grepl("^#RFClassifier", entete[[1L]])) {
    .reconfort_sharkrf_erreur("first line is not {.code #RFClassifier}.")
  }
  classes <- suppressWarnings(as.integer(strsplit(trimws(entete[[2L]]), " +")[[1L]]))
  n_cl <- classes[[1L]]
  classes <- classes[-1L]
  if (is.na(n_cl) || length(classes) != n_cl) {
    .reconfort_sharkrf_erreur("second line does not list the classes.")
  }
  # Nombre d'arbres : avant-dernier jeton de la 3e ligne de l'archive
  # (`... 0 0 1000 0 0 1 0`) ; pris de la structure plutot que d'une position.
  jetons3 <- strsplit(trimws(entete[[3L]]), " +")[[1L]]
  n_arbres <- suppressWarnings(as.integer(jetons3[length(jetons3) - 4L]))
  if (is.na(n_arbres) || n_arbres < 1L) {
    .reconfort_sharkrf_erreur("cannot read the number of trees.")
  }

  motif <- "[0-9]\\.[0-9]+e[-+][0-9]+"
  attr_l <- seuil_l <- gauche_l <- droite_l <- vector("list", n_arbres)
  racines <- integer(n_arbres)
  base <- 0L
  for (k in seq_len(n_arbres)) {
    ligne <- readLines(con, n = 1L, warn = FALSE)
    lcl   <- readLines(con, n = 1L, warn = FALSE)
    readLines(con, n = 1L, warn = FALSE)           # ligne de 5 jetons
    if (!length(ligne) || !length(lcl)) {
      .reconfort_sharkrf_erreur(sprintf("file ends inside tree %d.", k))
    }
    arbre <- tryCatch(
      .reconfort_sharkrf_arbre(ligne, lcl, k, base, n_cl, motif),
      nemeton_sharkrf_format = function(e) stop(e),
      error = function(e) {
        .reconfort_sharkrf_erreur(sprintf("tree %d cannot be parsed (%s).", k,
                                          conditionMessage(e)))
      })
    n <- arbre$n; a <- arbre$a; g <- arbre$g; d <- arbre$d
    attr_l[[k]] <- a
    seuil_l[[k]] <- arbre$q
    gauche_l[[k]] <- g
    droite_l[[k]] <- d
    racines[[k]] <- base + 1L
    base <- base + n
  }
  attr <- unlist(attr_l, use.names = FALSE)
  structure(list(
    attr = attr, seuil = unlist(seuil_l, use.names = FALSE),
    gauche = unlist(gauche_l, use.names = FALSE),
    droite = unlist(droite_l, use.names = FALSE),
    racines = racines, n_arbres = n_arbres, n_vars = max(attr) + 1L,
    classes = classes, source = NULL),
    class = "reconfort_sharkrf")
}

# Analyse d'un arbre (deux lignes) ; toute anomalie leve `nemeton_sharkrf_format`.
# Structure exigee, observee sur le v3 reel (2 883 279 noeuds internes, tous les
# fils ont un index superieur a celui de leur pere) : fils dans (pere, n), donc
# aucun cycle possible et la descente se termine toujours.
.reconfort_sharkrf_arbre <- function(ligne, lcl, k, base, n_cl, motif) {
  p <- regexpr(motif, ligne)
  if (p < 0L) .reconfort_sharkrf_erreur(sprintf("no threshold in tree %d.", k))
  # Position (1-based) du jeton `attribut` du premier quadruplet = nombre de
  # jetons du prefixe qui precede le premier seuil.
  debut <- length(strsplit(trimws(substr(ligne, 1L, p - 1L)), " +")[[1L]])
  tok <- scan(text = ligne, what = double(), quiet = TRUE)
  n <- as.integer(tok[[2L]])
  if (is.na(n) || n < 1L || debut + 4L * n - 1L > length(tok)) {
    .reconfort_sharkrf_erreur(sprintf("tree %d is shorter than announced.", k))
  }
  q <- matrix(tok[debut:(debut + 4L * n - 1L)], ncol = 4L, byrow = TRUE)
  dl <- scan(text = lcl, what = integer(), quiet = TRUE)
  nl <- dl[[2L]]
  if (is.na(nl) || nl < 1L || length(dl) < 2L + nl) {
    .reconfort_sharkrf_erreur(sprintf("class line of tree %d is shorter than announced.", k))
  }
  cls <- dl[3:(2L + nl)]
  feuille <- q[, 3L] == 0
  if (sum(feuille) != nl || anyNA(cls)) {
    .reconfort_sharkrf_erreur(sprintf("leaf count of tree %d does not match its class line.", k))
  }
  if (any(cls < 0L | cls >= n_cl)) {
    .reconfort_sharkrf_erreur(sprintf("leaf class of tree %d is outside 0..%d.", k, n_cl - 1L))
  }
  if (any(q[feuille, 4L] < 0 | q[feuille, 4L] >= nl)) {
    .reconfort_sharkrf_erreur(sprintf("leaf number out of range in tree %d.", k))
  }
  interne <- which(!feuille)
  if (any(q[interne, 1L] < 0 | is.na(q[interne, 1L])) ||
      any(q[interne, 3:4] <= (interne - 1L) | q[interne, 3:4] >= n)) {
    .reconfort_sharkrf_erreur(sprintf("child index of tree %d is out of range or not after its parent (cycle).", k))
  }
  g <- as.integer(q[, 3L]) + base + 1L   # local 0-based -> global 1-based
  d <- as.integer(q[, 4L]) + base + 1L
  a <- as.integer(q[, 1L])
  a[feuille] <- -1L
  g[feuille] <- cls[as.integer(q[feuille, 4L]) + 1L]   # classe de la feuille
  d[feuille] <- 0L
  list(n = n, a = a, g = g, d = d, q = q[, 2L])
}

#' @export
print.reconfort_sharkrf <- function(x, ...) {
  cat(sprintf("<reconfort_sharkrf> %d trees, %d variables, classes %s, %s nodes\n",
              x$n_arbres, x$n_vars, paste(x$classes, collapse = "/"),
              format(length(x$attr), big.mark = " ")))
  invisible(x)
}

#' Apply a SharkRF model: votes per class
#'
#' Vectorised prediction of a [reconfort_sharkrf_lire()] model: every tree
#' casts one vote for the class of the leaf a row reaches. The votes sum to the
#' number of trees (1000 for the RECONFORT models); the class is their argmax,
#' as in IOTA2's `ProbabilityMap_seed_0` (probability in per mille) and
#' `Classif_Seed_0`. Rows are processed in blocks of `bloc` rows to bound
#' memory.
#'
#' @param modele A `reconfort_sharkrf` object.
#' @param x Numeric matrix, one row per pixel, one column per feature (at least
#'   `modele$n_vars` columns, in the order the model was trained on).
#' @param bloc Rows per block (default 20000).
#' @return An integer matrix with one row per row of `x` and one column per
#'   class (header order); rows containing an `NA` are not predictable and
#'   give `-1` in every column.
#' @export
#' @examples
#' # voir reconfort_sharkrf_lire()
reconfort_sharkrf_predire <- function(modele, x, bloc = 20000L) {
  if (!inherits(modele, "reconfort_sharkrf")) {
    cli::cli_abort("{.arg modele} must come from {.fn reconfort_sharkrf_lire}.")
  }
  x <- as.matrix(x)
  storage.mode(x) <- "double"
  if (ncol(x) < modele$n_vars) {
    cli::cli_abort("{.arg x} has {ncol(x)} column{?s}, the model needs {modele$n_vars}.")
  }
  n <- nrow(x)
  k <- length(modele$classes)
  sortie <- matrix(-1L, n, k)
  if (!n) return(sortie)
  bon <- !is.na(rowSums(x))
  for (d in seq.int(1L, n, by = bloc)) {
    idx <- which(bon[d:min(n, d + bloc - 1L)]) + d - 1L
    if (length(idx)) {
      sortie[idx, ] <- .reconfort_sharkrf_bloc(modele, x[idx, , drop = FALSE], k)
    }
  }
  sortie
}

# Votes d'un bloc sans NA. Une routine Rust (arbre puis pixels) a ete essayee :
# 2,1 a 2,6 fois plus rapide seulement que ce code R vectorise sur le vrai v3 (voir
# NEWS), sous le seuil de 3 fois fixe pour la garder ; elle a ete retiree.
# Une boucle par arbre, une iteration par niveau, sur le
# sous-ensemble de pixels pas encore arrives a une feuille.
.reconfort_sharkrf_bloc <- function(m, x, k) {
  p <- nrow(x)
  xf <- as.vector(x)                      # colonne par colonne
  votes <- matrix(0L, p, k)
  attr <- m$attr; seuil <- m$seuil; gauche <- m$gauche; droite <- m$droite
  for (t in seq_len(m$n_arbres)) {
    noeud <- rep.int(m$racines[[t]], p)
    actif <- seq_len(p)
    repeat {
      a <- attr[noeud[actif]]
      f <- a < 0L
      if (any(f)) actif <- actif[!f]
      if (!length(actif)) break
      a <- a[!f]
      nd <- noeud[actif]
      va <- xf[actif + p * a]
      noeud[actif] <- ifelse(va <= seuil[nd], gauche[nd], droite[nd])
    }
    cl <- gauche[noeud] + 1L              # classe 0-based -> colonne
    votes[cbind(seq_len(p), cl)] <- votes[cbind(seq_len(p), cl)] + 1L
  }
  votes
}
