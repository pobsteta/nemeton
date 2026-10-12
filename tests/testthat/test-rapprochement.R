# Cas communs du rapprochement provisoire -> définitif
# (fixtures/rapprochement/*.json), mêmes assertions que
# core/tests/test_rapprochement.py du dépôt groma.
attributs_terrain <- c("essence_arbre", "espece", "statut", "qualite", "notes", "photos")

executer_cas <- function(cas) {
  p <- cas$parametres
  compteur <- 0L
  rapprocher_arbres(
    cas$provisoires, cas$definitifs, unlist(cas$centre), cas$convergence_deg,
    tolerance_m = p$tolerance_m, rayon_m = p$rayon_m, seuil_diam_cm = p$seuil_diam_cm,
    unite_azimut = p$unite_azimut, tolerance_deg = p$tolerance_deg,
    generer_uuid = function() { compteur <<- compteur + 1L; paste0("n", compteur - 1L) }
  )
}

lire_cas <- function(chemin) jsonlite::fromJSON(chemin, simplifyVector = TRUE)
cas_rapprochement <- sort(Sys.glob(testthat::test_path("fixtures", "rapprochement", "*.json")))

meme_valeur <- function(a, b) {
  if (is.null(b) || (length(b) == 1 && is.na(b))) return(is.na(a) || is.null(a))
  if (is.numeric(b)) return(isTRUE(all.equal(as.numeric(a), b)))
  identical(as.character(a), as.character(b))
}

for (chemin in cas_rapprochement) {
  cas <- lire_cas(chemin)
  test_that(paste("rapprochement :", cas$id), {
    res <- executer_cas(cas)
    a <- res$arbres
    att <- cas$attendu
    for (u in names(att$par_uuid)) {
      ligne <- a[a$uuid == u, ]
      expect_equal(nrow(ligne), 1L)
      for (k in names(att$par_uuid[[u]])) {
        expect_true(meme_valeur(ligne[[k]], att$par_uuid[[u]][[k]]), info = paste(u, k))
      }
    }
    nouveaux <- a[a$uuid %in% res$nouveaux, ]
    n_att <- if (is.data.frame(att$nouveaux)) nrow(att$nouveaux) else length(att$nouveaux)
    expect_equal(nrow(nouveaux), n_att)
    if (n_att) {
      cx <- cas$centre[1]; cy <- cas$centre[2]
      for (k in seq_len(n_att)) {
        n <- att$nouveaux[k, ]
        x <- cx + n$d * sin(n$az * pi / 180)
        y <- cy + n$d * cos(n$az * pi / 180)
        trouve <- nouveaux[sqrt((nouveaux$x - x)^2 + (nouveaux$y - y)^2) < 1e-3, ]
        expect_equal(nrow(trouve), 1L)
        for (col in c("tree_id", "etat_detection", "dbh_cm")) {
          expect_true(meme_valeur(trouve[[col]], n[[col]]), info = col)
        }
      }
    }
    expect_setequal(as.character(res$non_retrouves), as.character(unlist(att$non_retrouves)))
    nm <- att$numeros_modifies
    attendus <- if (length(nm)) apply(as.matrix(nm), 1, paste, collapse = "|") else character(0)
    obtenus <- if (nrow(res$numeros_modifies)) {
      paste(res$numeros_modifies$uuid, res$numeros_modifies$ancien,
            res$numeros_modifies$nouveau, sep = "|")
    } else character(0)
    expect_setequal(obtenus, attendus)
    if (!is.null(att$alertes)) {
      for (k in seq_len(nrow(att$alertes))) {
        expect_true(any(res$alertes$uuid == att$alertes$uuid[k] &
                          res$alertes$motif == att$alertes$motif[k]))
      }
    }
    if (!is.null(att$nombre_arbres)) expect_equal(nrow(a), att$nombre_arbres)
  })

  test_that(paste("aucune perte d'attribut terrain :", cas$id), {
    res <- executer_cas(cas)
    a <- res$arbres
    p <- cas$provisoires
    for (i in seq_len(nrow(p))) {
      ligne <- a[a$uuid == p$uuid[i], ]
      expect_equal(nrow(ligne), 1L, info = "arbre provisoire perdu")
      for (k in intersect(attributs_terrain, names(p))) {
        expect_true(meme_valeur(ligne[[k]], p[[k]][i]), info = paste(p$uuid[i], k))
      }
      if (identical(p$h_source[i], "mesuree")) expect_equal(ligne$h_m, p$h_m[i])
    }
  })
}

test_that("tree_id reste unique et non vide sur tous les cas", {
  for (chemin in cas_rapprochement) {
    ids <- executer_cas(lire_cas(chemin))$arbres$tree_id
    expect_true(all(!is.na(ids) & nzchar(ids)))
    expect_false(anyDuplicated(ids) > 0)
  }
})

test_that("l'affectation hongroise est optimale (comparée à la force brute)", {
  set.seed(61)
  permutations <- function(v) {
    if (length(v) <= 1) return(list(v))
    unlist(lapply(seq_along(v), function(i) lapply(permutations(v[-i]), function(p) c(v[i], p))),
           recursive = FALSE)
  }
  for (essai in 1:30) {
    n <- sample(1:5, 1); m <- sample(1:5, 1)
    cout <- matrix(round(stats::runif(n * m, 0, 10), 2), n, m)
    cout[stats::runif(n * m) < 0.3] <- 1e9
    col <- nemeton:::.affectation_optimale(cout, 1e9)
    total <- function(col) {
      v <- vapply(seq_len(n), function(i) if (is.na(col[i])) 1e9 else cout[i, col[i]], 0)
      sum(v)
    }
    # Force brute sur la matrice complétée au carré.
    k <- max(n, m)
    a <- matrix(1e9, k, k); a[seq_len(n), seq_len(m)] <- cout
    meilleur <- min(vapply(permutations(seq_len(k)), function(p) sum(a[cbind(seq_len(k), p)]), 0))
    expect_equal(total(col) + 1e9 * (k - n), meilleur, tolerance = 1e-6)
    expect_false(anyDuplicated(stats::na.omit(col)) > 0)
  }
})

test_that("rapprocher_arbres accepte des sf et rend un sf", {
  prov <- sf::st_as_sf(data.frame(uuid = c("u1", "u2"), plot_id = "P1", tree_id = c("1", "2"),
                                  dbh_cm = c(30, 25), essence_arbre = c("hetre", NA),
                                  etat_detection = "provisoire",
                                  x = c(1000, 1003), y = c(2005, 2004)),
                       coords = c("x", "y"), crs = 2154)
  def <- sf::st_as_sf(data.frame(x = c(1000.2, 1003.1), y = c(2005, 2004),
                                 dbh_cm = c(31, 24), methode = "classique"),
                      coords = c("x", "y"), crs = 2154)
  res <- rapprocher_arbres(prov, def, centre = c(1000, 2000))
  expect_s3_class(res$arbres, "sf")
  expect_equal(sf::st_crs(res$arbres)$epsg, 2154L)
  expect_equal(res$arbres$etat_detection[res$arbres$uuid == "u1"], "definitif")
  expect_equal(res$arbres$etat_detection[res$arbres$uuid == "u2"], "a_completer")
  expect_true(grepl("^[0-9a-f-]{36}$", nemeton:::.uuid_v4()))
})
