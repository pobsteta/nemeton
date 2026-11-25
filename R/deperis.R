# Tournee DEPERIS : fichier d'echange `deperis.gpkg`, version 1 (mission 061).
#
# Contrat : `docs/formats/deperis-v1.md` du depot Ramulus ; schema (source unique,
# copie dans inst/schemas/, voir inst/schemas/README.md) ; cas communs
# `fixtures/echange/` de Ramulus (tests/testthat/fixtures/deperis-v1/).
#
# Deux fonctions exportees :
#   * creer_tournee_deperis() ecrit le `deperis.gpkg` de depart (et sa variante de
#     contre-notation) ;
#   * importer_deperis() importe le paquet `.zip` rendu par Ramulus : tout ou
#     rien, rejouable sans doublon (union sur l'uuid), classe recalculee par
#     l'abaque, refus et signalements du catalogue des motifs.
#
# Le GeoPackage est ecrit avec RSQLite selon OGC 12-128, comme le fait le controle
# de reference de Ramulus (GDAL declare MEDIUMINT les entiers de 32 bits, que le
# schema refuse) ; GDAL (sf) sert a le relire pour verifier qu'il s'ouvre.
# Coordonnees : EPSG:2154, X = est, Y = nord, en metres.

# ---------------------------------------------------------------------------
# Constantes et referentiels lus dans le schema copie
# ---------------------------------------------------------------------------

.dp_application_id <- 1196444487L # 0x47504B47, " GPKG " (OGC 12-128, Req. 2)
.dp_user_version <- 10400L # GeoPackage 1.4, comme le GeoPackage d'exemple de Groma
.dp_seuil_centre_eloigne_m <- 30 # PROVISOIRE (ADR 0004 de Ramulus, non tranche par Pascal)
.dp_emprise_2154 <- c(ouest = -9.86, sud = 41.15, est = 10.38, nord = 51.56) # lon/lat, EPSG:2154
.dp_tables_notes <- c("notations", "contre_notations")
.dp_regle_choix_defaut <- "Kraft 1 \u00e0 3, tour d'horizon depuis le nord, sens horaire"

.dp_ou <- function(a, b) if (is.null(a)) b else a

.dp_exiger <- function() {
  manque <- c("DBI", "RSQLite", "stringi", "openssl")
  manque <- manque[!vapply(manque, requireNamespace, logical(1), quietly = TRUE)]
  if (length(manque)) {
    cli::cli_abort(c(
      "Package{?s} {.pkg {manque}} {?is/are} required for the DEPERIS round files.",
      "i" = "Install {?it/them} with {.code install.packages({deparse(manque)})}."
    ))
  }
  invisible(TRUE)
}

.dp_fichier_schema <- function() {
  chemin <- system.file("schemas", "deperis-v1.schema.json", package = "nemeton")
  if (!nzchar(chemin)) {
    cli::cli_abort("File {.file schemas/deperis-v1.schema.json} not found in the nemeton installation.")
  }
  chemin
}

# Schema du format (copie de Ramulus), lu une fois par session.
.dp_cache <- new.env(parent = emptyenv())
.dp_schema <- function() {
  if (is.null(.dp_cache$schema)) {
    .dp_cache$schema <- jsonlite::parse_json(paste(readLines(.dp_fichier_schema(), encoding = "UTF-8", warn = FALSE), collapse = "\n"), simplifyVector = FALSE)
  }
  .dp_cache$schema
}

# Catalogue des motifs : statut (`refuse` ou `signale`) de chaque motif.
.dp_motifs <- function(schema = .dp_schema()) {
  m <- schema[["x-motifs"]]
  vapply(m, function(x) x[["statut"]], character(1))
}

# Les 19 essences et leur type, lus dans le schema (`essence_type`).
.dp_essences <- function(schema = .dp_schema()) {
  b <- schema[["$defs"]][["essence_type"]][["anyOf"]]
  data.frame(
    essence = vapply(b, function(x) x$properties$essence$const, character(1)),
    type = vapply(b, function(x) x$properties$type$const, character(1)),
    stringsAsFactors = FALSE
  )
}

# Abaque : matrice 6 x 6, lignes MB 0 a 5, colonnes MR ou MA 0 a 5, lue dans le schema.
.dp_abaque <- function(schema = .dp_schema()) {
  b <- schema[["$defs"]][["abaque"]][["anyOf"]]
  m <- matrix(NA_character_, 6L, 6L, dimnames = list(mb = 0:5, second = 0:5))
  for (x in b) {
    m[x$properties$mb$const + 1L, x$properties$second$const + 1L] <- x$properties$classe$const
  }
  m
}

# Classe recalculee par l'abaque (vectorise ; NA si une note est hors de 0 a 5).
.dp_classe <- function(mb, second, schema = .dp_schema()) {
  ab <- .dp_abaque(schema)
  ok <- !is.na(mb) & !is.na(second) & mb %in% 0:5 & second %in% 0:5
  out <- rep(NA_character_, length(mb))
  out[ok] <- ab[cbind(as.integer(mb[ok]) + 1L, as.integer(second[ok]) + 1L)]
  out
}

# ---------------------------------------------------------------------------
# Mini-interpreteur de JSON Schema (les seuls mots-cles du schema de Ramulus)
# ---------------------------------------------------------------------------

.dp_egal <- function(a, b) {
  if (is.null(a) || is.null(b)) return(is.null(a) && is.null(b))
  if (is.list(a) || is.list(b)) {
    if (!(is.list(a) && is.list(b)) || length(a) != length(b)) return(FALSE)
    if (!is.null(names(a)) || !is.null(names(b))) {
      if (!setequal(names(a), names(b))) return(FALSE)
      return(all(vapply(names(a), function(n) .dp_egal(a[[n]], b[[n]]), logical(1))))
    }
    return(all(vapply(seq_along(a), function(i) .dp_egal(a[[i]], b[[i]]), logical(1))))
  }
  if (is.logical(a) || is.logical(b)) return(is.logical(a) && is.logical(b) && identical(a, b))
  if (is.numeric(a) && is.numeric(b)) return(isTRUE(a == b))
  identical(a, b)
}

.dp_est_objet <- function(x) is.list(x) && (length(x) == 0L || !is.null(names(x)))
.dp_est_tableau <- function(x) is.list(x) && is.null(names(x))

.dp_type_ok <- function(x, t) {
  switch(t,
    null = is.null(x),
    object = .dp_est_objet(x),
    array = .dp_est_tableau(x),
    string = is.character(x) && length(x) == 1L,
    integer = is.numeric(x) && length(x) == 1L && is.finite(x) && x == floor(x),
    number = is.numeric(x) && length(x) == 1L && is.finite(x),
    boolean = is.logical(x) && length(x) == 1L,
    FALSE
  )
}

# Valide `x` contre `sch` ; rend une liste d'erreurs c(motif, message). Le motif d'une
# erreur est le `x-motif` du sous-schema qui la porte, a defaut `structure`
# (comme le controle de reference de Ramulus).
.dp_val <- function(x, sch, racine, ou = "") {
  if (isTRUE(sch)) return(list())
  if (identical(sch, FALSE)) return(list(c("structure", paste0(ou, " : schema faux"))))
  motif <- .dp_ou(sch[["x-motif"]], "structure")
  err <- list()
  add <- function(msg) err[[length(err) + 1L]] <<- c(motif, paste0(ou, " : ", msg))
  nm <- names(sch)

  if ("$ref" %in% nm) {
    ref <- sub("^#/\\$defs/", "", sch[["$ref"]])
    err <- c(err, .dp_val(x, racine[["$defs"]][[ref]], racine, ou))
  }
  if ("type" %in% nm) {
    ts <- unlist(sch[["type"]])
    if (!any(vapply(ts, function(t) .dp_type_ok(x, t), logical(1)))) {
      add(paste0("type ", paste(ts, collapse = "/"), " attendu"))
    }
  }
  if ("const" %in% nm && !.dp_egal(x, sch[["const"]])) add("valeur constante attendue")
  if ("enum" %in% nm &&
        !any(vapply(sch[["enum"]], function(e) .dp_egal(x, e), logical(1)))) {
    add(paste0(deparse(x), " hors de la liste"))
  }
  if ("pattern" %in% nm && is.character(x) && length(x) == 1L &&
        !grepl(sch[["pattern"]], x, perl = TRUE)) {
    add(paste0(deparse(x), " ne suit pas le motif ", sch[["pattern"]]))
  }
  if ("minLength" %in% nm && is.character(x) && length(x) == 1L &&
        nchar(x, "chars") < sch[["minLength"]]) add("texte trop court")
  if ("minimum" %in% nm && is.numeric(x) && length(x) == 1L && isTRUE(x < sch[["minimum"]])) {
    add(paste0(x, " < ", sch[["minimum"]]))
  }
  if ("maximum" %in% nm && is.numeric(x) && length(x) == 1L && isTRUE(x > sch[["maximum"]])) {
    add(paste0(x, " > ", sch[["maximum"]]))
  }
  if (.dp_est_tableau(x)) {
    if ("minItems" %in% nm && length(x) < sch[["minItems"]]) add("trop peu de lignes")
    if ("maxItems" %in% nm && length(x) > sch[["maxItems"]]) add("trop de lignes")
    if ("items" %in% nm) {
      for (i in seq_along(x)) {
        err <- c(err, .dp_val(x[[i]], sch[["items"]], racine, paste0(ou, "/", i)))
      }
    }
  }
  if (.dp_est_objet(x) && length(x) > 0L) {
    if ("required" %in% nm) {
      manque <- setdiff(unlist(sch[["required"]]), names(x))
      if (length(manque)) add(paste0("cle(s) absente(s) : ", paste(manque, collapse = ", ")))
    }
    props <- sch[["properties"]]
    for (n in intersect(names(props), names(x))) {
      err <- c(err, .dp_val(x[[n]], props[[n]], racine, paste0(ou, "/", n)))
    }
    if ("additionalProperties" %in% nm) {
      for (n in setdiff(names(x), names(props))) {
        err <- c(err, .dp_val(x[[n]], sch[["additionalProperties"]], racine, paste0(ou, "/", n)))
      }
    }
    if ("propertyNames" %in% nm) {
      for (n in names(x)) {
        err <- c(err, .dp_val(n, sch[["propertyNames"]], racine, paste0(ou, "/", n, " (nom)")))
      }
    }
  } else if (.dp_est_objet(x) && "required" %in% nm && length(unlist(sch[["required"]]))) {
    add("cle(s) absente(s)")
  }
  if ("allOf" %in% nm) {
    for (s in sch[["allOf"]]) err <- c(err, .dp_val(x, s, racine, ou))
  }
  if ("anyOf" %in% nm &&
        !any(vapply(sch[["anyOf"]], function(s) length(.dp_val(x, s, racine, ou)) == 0L, logical(1)))) {
    add("aucune alternative satisfaite")
  }
  if ("not" %in% nm && length(.dp_val(x, sch[["not"]], racine, ou)) == 0L) add("interdit ici")
  if ("if" %in% nm && "then" %in% nm && length(.dp_val(x, sch[["if"]], racine, ou)) == 0L) {
    err <- c(err, .dp_val(x, sch[["then"]], racine, ou))
  }
  err
}

# ---------------------------------------------------------------------------
# Geometrie GeoPackage (OGC 12-128, 2.1.3) et emprise d'EPSG:2154
# ---------------------------------------------------------------------------

.dp_blob_point <- function(x, y, srs_id = 2154L) {
  c(charToRaw("GP"), as.raw(c(0L, 1L)), writeBin(as.integer(srs_id), raw(), endian = "little"),
    as.raw(1L), writeBin(1L, raw(), endian = "little"),
    writeBin(c(x, y), raw(), endian = "little"))
}

# Point d'un blob GeoPackage donne en hexadecimal : list(x, y), NULL si vide ;
# une chaine d'erreur si illisible.
.dp_hex_point <- function(hex) {
  if (is.null(hex)) return(NULL)
  r <- tryCatch({
    n <- nchar(hex)
    b <- as.raw(strtoi(substring(hex, seq(1L, n, 2L), seq(2L, n, 2L)), 16L))
    if (length(b) < 8L || !identical(b[1:2], charToRaw("GP"))) stop("geometrie sans en-tete GeoPackage")
    drapeaux <- as.integer(b[4L])
    fin <- if (bitwAnd(drapeaux, 1L)) "little" else "big"
    taille_env <- c(0L, 32L, 48L, 48L, 64L)[bitwAnd(bitwShiftR(drapeaux, 1L), 7L) + 1L]
    if (is.na(taille_env)) stop("indicateur d'enveloppe invalide")
    if (bitwAnd(drapeaux, 16L)) return(NULL)
    wkb <- b[(9L + taille_env):length(b)]
    wfin <- if (wkb[1L] == as.raw(1L)) "little" else "big"
    type_geom <- readBin(wkb[2:5], "integer", size = 4L, endian = wfin)
    if (type_geom != 1L) stop(sprintf("geometrie de type WKB %d, POINT attendu", type_geom))
    xy <- readBin(wkb[6:21], "double", n = 2L, size = 8L, endian = wfin)
    if (is.nan(xy[1L]) && is.nan(xy[2L])) return(NULL)
    list(x = xy[1L], y = xy[2L])
  }, error = function(e) paste0("g\u00e9om\u00e9trie illisible : ", conditionMessage(e)))
  r
}

# Vrai si le point (EPSG:2154) tombe dans l'emprise d'EPSG:2154 (vectorise).
.dp_en_france <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  res <- rep(FALSE, length(x))
  if (any(ok)) {
    ll <- sf::sf_project("EPSG:2154", "EPSG:4326", cbind(x[ok], y[ok]))
    e <- .dp_emprise_2154
    res[ok] <- is.finite(ll[, 1]) & is.finite(ll[, 2]) &
      ll[, 1] >= e[["ouest"]] & ll[, 1] <= e[["est"]] &
      ll[, 2] >= e[["sud"]] & ll[, 2] <= e[["nord"]]
  }
  res
}

# ---------------------------------------------------------------------------
# Instantane : projection JSON d'un GeoPackage (format deperis-v1.md, « Instantane »)
# ---------------------------------------------------------------------------

.dp_q <- function(nom) paste0("\"", gsub("\"", "\"\"", nom, fixed = TRUE), "\"")
.dp_lit <- function(nom) paste0("'", gsub("'", "''", nom, fixed = TRUE), "'")

# `photos` : vecteur nomme nom -> sha256 pour un .zip, NULL pour un deperis.gpkg seul.
.dp_instantane <- function(chemin, photos = NULL) {
  con <- DBI::dbConnect(RSQLite::SQLite(), chemin, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  q <- function(s) DBI::dbGetQuery(con, s)
  pragma <- function(p) as.integer(q(paste0("PRAGMA ", p))[[1L]][1L])
  app <- pragma("application_id")
  uv <- pragma("user_version")
  rep_ <- q("SELECT srs_id, organization, organization_coordsys_id FROM gpkg_spatial_ref_sys")
  reperes <- stats::setNames(lapply(seq_len(nrow(rep_)), function(i) {
    list(organisation = rep_$organization[i], code = as.integer(rep_$organization_coordsys_id[i]))
  }), as.character(rep_$srs_id))
  geo_ <- q("SELECT table_name, column_name, geometry_type_name, srs_id FROM gpkg_geometry_columns")
  rtree_ext <- tryCatch(
    q("SELECT table_name FROM gpkg_extensions WHERE extension_name = 'gpkg_rtree_index'")$table_name,
    error = function(e) character()
  )
  maitre <- q("SELECT type, name FROM sqlite_master")
  contenu <- q("SELECT table_name, data_type FROM gpkg_contents ORDER BY table_name")
  tables <- list()
  for (k in seq_len(nrow(contenu))) {
    nom <- contenu$table_name[k]
    info <- q(paste0("PRAGMA table_info(", .dp_q(nom), ")"))
    colonnes <- stats::setNames(as.list(toupper(ifelse(is.na(info$type), "", info$type))), info$name)
    cle <- info$name[info$pk > 0]
    g <- geo_[geo_$table_name == nom, , drop = FALSE]
    geometrie <- NULL
    if (nrow(g)) {
      geometrie <- list(colonne = g$column_name[1L], type = toupper(g$geometry_type_name[1L]),
                        srs = reperes[[as.character(g$srs_id[1L])]])
    }
    prefixe <- paste0("rtree_", nom, "_")
    index <- nom %in% rtree_ext ||
      any(startsWith(maitre$name, prefixe) & maitre$type %in% c("table", "trigger"))
    champs <- vapply(info$name, function(c) {
      est_geo <- !is.null(geometrie) && identical(c, geometrie$colonne)
      expr <- if (est_geo) {
        sprintf("CASE WHEN %1$s IS NULL THEN NULL ELSE hex(%1$s) END", .dp_q(c))
      } else {
        sprintf("CASE WHEN typeof(%1$s) = 'blob' THEN hex(%1$s) ELSE %1$s END", .dp_q(c))
      }
      paste0(.dp_lit(c), ", ", expr)
    }, character(1))
    ordre <- if (length(cle) == 1L) paste0(" ORDER BY ", .dp_q(cle)) else ""
    json <- q(paste0("SELECT json_object(", paste(champs, collapse = ", "), ") AS j FROM ",
                     .dp_q(nom), ordre))$j
    lignes <- if (length(json)) {
      jsonlite::fromJSON(paste0("[", paste(json, collapse = ","), "]"), simplifyVector = FALSE)
    } else {
      list()
    }
    if (!is.null(geometrie)) {
      for (i in seq_along(lignes)) {
        lignes[[i]][geometrie$colonne] <- list(.dp_hex_point(lignes[[i]][[geometrie$colonne]]))
      }
    }
    if ("photos" %in% names(colonnes)) {
      for (i in seq_along(lignes)) {
        v <- lignes[[i]][["photos"]]
        if (is.character(v)) {
          lignes[[i]]["photos"] <- list(tryCatch(
            jsonlite::fromJSON(v, simplifyVector = FALSE), error = function(e) v
          ))
        }
      }
    }
    tables[[nom]] <- list(
      data_type = contenu$data_type[k], geometrie = geometrie, index_spatial = index,
      cle_primaire = if (length(cle) == 1L) cle else NULL, colonnes = colonnes, lignes = lignes
    )
  }
  tournee <- if (is.list(tables$tournee)) tables$tournee$lignes else list()
  inst <- list(
    application_id = app, user_version = uv,
    version_schema = if (length(tournee) == 1L) tournee[[1L]][["version_schema"]] else NULL,
    nature = if (length(tournee) == 1L) tournee[[1L]][["nature"]] else NULL,
    tables = tables
  )
  if (!is.null(photos)) {
    inst$photos_du_paquet <- unname(lapply(sort(names(photos), method = "radix"), function(n) {
      list(nom = n, sha256 = unname(photos[[n]]))
    }))
  }
  inst
}

# ---------------------------------------------------------------------------
# Lecture d'un paquet : deperis.gpkg seul, ou .zip rendu (deperis.gpkg + photos/)
# ---------------------------------------------------------------------------

.dp_sha256 <- function(fichier) {
  con <- file(fichier, "rb")
  on.exit(close(con), add = TRUE)
  paste0(as.character(openssl::sha256(con)))
}

.dp_entrees_sures <- function(noms) {
  ok <- !grepl("\\\\", noms) & !grepl("^/", noms) & !grepl("^[A-Za-z]:", noms) &
    !vapply(strsplit(noms, "/", fixed = TRUE), function(p) any(p %in% c("..", ".")), logical(1))
  noms[ok & (noms == "deperis.gpkg" | (grepl("^photos/[^/]+$", noms) & !grepl("^photos/\\.+$", noms)))]
}

# Rend list(inst, photos (nom -> sha256 ou NULL), fichiers_photos (nom -> chemin)) ;
# `erreur` (motif, message) si le fichier n'est pas lisible comme un GeoPackage.
.dp_lire_paquet <- function(chemin, tmp = tempfile("deperis-")) {
  .dp_exiger()
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  photos <- NULL
  fichiers <- NULL
  gpkg <- chemin
  if (grepl("\\.zip$", chemin, ignore.case = TRUE)) {
    noms <- tryCatch(utils::unzip(chemin, list = TRUE)$Name, error = function(e) NULL)
    sures <- if (is.null(noms)) character() else .dp_entrees_sures(noms[!grepl("/$", noms)])
    if (!"deperis.gpkg" %in% sures) {
      return(list(erreur = c("pas_un_geopackage", "le .zip ne contient pas deperis.gpkg \u00e0 la racine")))
    }
    utils::unzip(chemin, files = sures, exdir = tmp, junkpaths = FALSE)
    gpkg <- file.path(tmp, "deperis.gpkg")
    pn <- sort(setdiff(sures, "deperis.gpkg"), method = "radix")
    fichiers <- stats::setNames(file.path(tmp, pn), pn)
    photos <- stats::setNames(vapply(fichiers, .dp_sha256, character(1), USE.NAMES = FALSE), pn)
    if (!length(pn)) photos <- stats::setNames(character(), character())
  }
  inst <- tryCatch(.dp_instantane(gpkg, photos), error = function(e) e)
  if (inherits(inst, "error")) {
    return(list(erreur = c("pas_un_geopackage", paste0("fichier illisible : ", conditionMessage(inst)))))
  }
  list(inst = inst, photos = photos, fichiers_photos = fichiers)
}

# ---------------------------------------------------------------------------
# Controle : ce que conclut un lecteur conforme (Ramulus a l'ouverture, Nemeton a l'import)
# ---------------------------------------------------------------------------

.dp_lignes <- function(inst, table) {
  t <- inst$tables[[table]]
  if (is.list(t)) .dp_ou(t$lignes, list()) else list()
}

.dp_est_2154 <- function(inst, table) {
  g <- inst$tables[[table]]$geometrie
  is.list(g) && .dp_egal(g$srs, list(organisation = "EPSG", code = 2154L))
}

.dp_point <- function(v) {
  is.list(v) && is.numeric(v$x) && is.numeric(v$y) && length(v$x) == 1L && length(v$y) == 1L
}

.dp_non_nfc_msgs <- function(inst) {
  sortie <- character()
  nfc <- function(s) stringi::stri_trans_isnfc(s)
  parcourir <- function(v, ou) {
    if (is.character(v)) {
      for (s in v[!is.na(v) & !nfc(v)]) sortie <<- c(sortie, sprintf("%s : %s n'est pas en Unicode NFC", ou, deparse(s)))
    } else if (is.list(v)) {
      for (i in seq_along(v)) {
        parcourir(v[[i]], if (is.null(names(v))) sprintf("%s[%d]", ou, i) else paste0(ou, ".", names(v)[i]))
      }
    }
  }
  for (nom in names(inst$tables)) {
    t <- inst$tables[[nom]]
    if (!nfc(nom)) sortie <- c(sortie, sprintf("nom de table %s n'est pas en Unicode NFC", deparse(nom)))
    if (!is.list(t)) next
    for (col in names(t$colonnes)) {
      if (!nfc(col)) sortie <- c(sortie, sprintf("%s : nom de colonne %s n'est pas en Unicode NFC", nom, deparse(col)))
    }
    geo <- if (is.list(t$geometrie)) t$geometrie$colonne else NULL
    for (i in seq_along(t$lignes)) {
      for (col in names(t$lignes[[i]])) {
        if (!identical(col, geo)) parcourir(t$lignes[[i]][[col]], sprintf("%s, ligne %d, %s", nom, i, col))
      }
    }
  }
  sortie
}

.dp_controler_photos <- function(inst, photos, ajouter) {
  citees <- character()
  for (table in .dp_tables_notes) {
    for (ligne in .dp_lignes(inst, table)) {
      liste <- ligne[["photos"]]
      if (.dp_est_tableau(liste)) {
        for (p in liste) {
          if (is.list(p) && is.character(p[["nom"]])) {
            citees[p[["nom"]]] <- .dp_ou(p[["sha256"]], NA_character_)
          }
        }
      }
    }
  }
  for (nom in names(citees)) {
    if (!nom %in% names(photos)) {
      ajouter("photo_absente", sprintf("%s cit\u00e9e mais absente du paquet", nom))
    } else if (!identical(unname(photos[[nom]]), unname(citees[[nom]]))) {
      ajouter("empreinte_photo_differente",
              sprintf("%s : SHA-256 %s au lieu de %s", nom, photos[[nom]], citees[[nom]]))
    }
  }
  for (nom in setdiff(names(photos), names(citees))) {
    ajouter("photo_non_citee", sprintf("%s pr\u00e9sente dans le paquet mais cit\u00e9e par aucune notation", nom))
  }
}

# Ce que Ramulus peut modifier dans ce que Nemeton a ecrit (ADR 0003 de Ramulus, 2-3).
.dp_ecrit_par_ramulus <- list(tournee = c("operateur", "version_ramulus"), placettes = "etat")

.dp_controler_plan <- function(inst, depart, ajouter) {
  a_comparer <- c("tournee", "placettes", if (identical(depart$nature, "contre_notation")) "centres")
  for (table in a_comparer) {
    t0 <- depart$tables[[table]]
    t1 <- inst$tables[[table]]
    if (is.null(t0) || is.null(t1)) {
      if (!identical(is.null(t0), is.null(t1))) ajouter("plan_modifie", sprintf("%s pr\u00e9sente d'un c\u00f4t\u00e9 seulement", table))
      next
    }
    libres <- .dp_ou(.dp_ecrit_par_ramulus[[table]], character())
    c0 <- t0$colonnes[setdiff(names(t0$colonnes), libres)]
    c1 <- t1$colonnes[setdiff(names(t1$colonnes), libres)]
    if (!.dp_egal(c0, c1)) {
      ajouter("plan_modifie", sprintf("%s : colonnes chang\u00e9es (disparues %s, apparues %s)", table,
                                      paste(setdiff(names(c0), names(c1)), collapse = "/"),
                                      paste(setdiff(names(c1), names(c0)), collapse = "/")))
      next
    }
    if (!.dp_egal(t0$geometrie, t1$geometrie)) ajouter("plan_modifie", sprintf("%s : g\u00e9om\u00e9trie ou rep\u00e8re chang\u00e9s", table))
    cle <- function(l) {
      if (identical(table, "placettes")) l[["plot_id"]] else .dp_ou(l[["uuid"]], l[["fid"]])
    }
    garder <- function(ls) {
      ks <- vapply(ls, function(l) as.character(.dp_ou(cle(l), NA)), character(1))
      stats::setNames(lapply(ls, function(l) l[setdiff(names(l), libres)]), ks)
    }
    l0 <- garder(t0$lignes)
    l1 <- garder(t1$lignes)
    if (!setequal(names(l0), names(l1))) {
      ajouter("plan_modifie", sprintf("%s : lignes ajout\u00e9es ou retir\u00e9es (%s)", table,
                                      paste(sort(setdiff(union(names(l0), names(l1)), intersect(names(l0), names(l1)))), collapse = ", ")))
    }
    for (k in sort(intersect(names(l0), names(l1)))) {
      if (!.dp_egal(l0[[k]], l1[[k]])) {
        ecarts <- names(l0[[k]])[!vapply(names(l0[[k]]), function(c) .dp_egal(l0[[k]][[c]], l1[[k]][[c]]), logical(1))]
        ajouter("plan_modifie", sprintf("%s %s : %s modifi\u00e9s", table, k, paste(ecarts, collapse = "/")))
      }
    }
  }
}

.dp_statut <- function(motifs, catalogue) {
  if (any(catalogue[motifs] == "refuse")) "refuse" else if (length(motifs)) "signale" else "accepte"
}

# Controle un paquet ; `depart` est la tournee telle que Nemeton l'a ecrite (import d'un rendu).
# Rend list(statut, motifs, messages).
.dp_controler <- function(paquet, depart = NULL, schema = .dp_schema()) {
  catalogue <- .dp_motifs(schema)
  if (!is.null(paquet$erreur)) {
    return(list(statut = .dp_statut(paquet$erreur[1L], catalogue), motifs = paquet$erreur[1L],
                messages = paste0(paquet$erreur[1L], " : ", paquet$erreur[2L])))
  }
  inst <- paquet$inst
  motifs <- character()
  messages <- character()
  ajouter <- function(motif, message) {
    motifs <<- c(motifs, motif)
    messages <<- c(messages, paste0(motif, " : ", message))
  }
  for (e in .dp_val(inst, schema, schema)) ajouter(e[1L], e[2L])

  # Placettes et centres en France : emprise d'EPSG:2154, point par point.
  hors_france_centres <- integer()
  for (table in c("placettes", "centres")) {
    if (!.dp_est_2154(inst, table)) next
    ls <- .dp_lignes(inst, table)
    for (i in seq_along(ls)) {
      g <- ls[[i]][["geom"]]
      if (.dp_point(g) && !.dp_en_france(g$x, g$y)) {
        ajouter("hors_france", sprintf("%s, ligne %d : X=%s Y=%s hors de l'emprise EPSG:2154", table, i, g$x, g$y))
        if (table == "centres") hors_france_centres <- c(hors_france_centres, i)
      }
    }
  }

  # Unicite et rattachement.
  placettes <- list()
  for (l in .dp_lignes(inst, "placettes")) {
    pid <- l[["plot_id"]]
    if (is.character(pid) && !is.null(placettes[[pid]])) ajouter("structure", sprintf("placettes : plot_id %s en double", deparse(pid)))
    if (is.character(pid)) placettes[[pid]] <- l
  }
  for (table in c("centres", .dp_tables_notes)) {
    vus <- character()
    for (l in .dp_lignes(inst, table)) {
      u <- l[["uuid"]]
      if (is.character(u) && u %in% vus) ajouter("uuid_duplique", sprintf("%s : uuid %s en double", table, u))
      if (is.character(u)) vus <- c(vus, u)
      pid <- l[["plot_id"]]
      p <- if (is.character(pid)) placettes[[pid]] else NULL
      if (is.null(p)) {
        ajouter("rattachement_invalide", sprintf("%s : plot_id %s absent de placettes", table, deparse(pid)))
      } else if (table %in% .dp_tables_notes && is.numeric(l[["rang"]]) && is.numeric(p[["nb_arbres"]]) &&
                   isTRUE(l[["rang"]] > p[["nb_arbres"]])) {
        ajouter("rattachement_invalide", sprintf("%s : rang %s > nb_arbres %s de %s", table, l[["rang"]], p[["nb_arbres"]], pid))
      }
    }
  }

  # Signales : deux notations du meme arbre (hors contre-notation) ; centre loin du point prevu.
  arbres <- list()
  for (l in .dp_lignes(inst, "notations")) {
    for (cle in c("rang", "repere")) {
      v <- l[[cle]]
      if (is.null(v)) next # repere facultatif : deux NULL ne sont pas le meme arbre
      k <- paste(l[["plot_id"]], cle, v, sep = "\u001f")
      if (!is.null(arbres[[k]]) && !identical(arbres[[k]], l[["uuid"]])) {
        ajouter("doublon_arbre", sprintf("notations : %s %s %s not\u00e9 deux fois (%s, %s)", l[["plot_id"]], cle, v, arbres[[k]], l[["uuid"]]))
      }
      if (is.null(arbres[[k]])) arbres[[k]] <- .dp_ou(l[["uuid"]], "")
    }
  }
  if (.dp_est_2154(inst, "centres") && .dp_est_2154(inst, "placettes")) {
    cs <- .dp_lignes(inst, "centres")
    for (i in seq_along(cs)) {
      c <- cs[[i]]
      pid <- c[["plot_id"]]
      p <- if (is.character(pid)) placettes[[pid]] else NULL
      if (i %in% hors_france_centres || is.null(p) || !(.dp_point(c[["geom"]]) && .dp_point(p[["geom"]]))) next
      d <- sqrt((c$geom$x - p$geom$x)^2 + (c$geom$y - p$geom$y)^2)
      if (d > .dp_seuil_centre_eloigne_m) {
        ajouter("centre_eloigne", sprintf("centres : %s \u00e0 %.1f m du point pr\u00e9vu (seuil provisoire %.0f m)", pid, d, .dp_seuil_centre_eloigne_m))
      }
    }
  }

  # Tous les textes en Unicode NFC.
  for (m in .dp_non_nfc_msgs(inst)) ajouter("texte_non_nfc", m)

  if (!is.null(paquet$photos)) .dp_controler_photos(inst, paquet$photos, ajouter)
  if (!is.null(depart) && is.null(depart$erreur)) .dp_controler_plan(inst, depart$inst, ajouter)

  inconnus <- setdiff(motifs, names(catalogue))
  if (length(inconnus)) cli::cli_abort("Reasons outside the schema catalogue: {.val {inconnus}}.")
  motifs <- sort(unique(motifs), method = "radix")
  list(statut = .dp_statut(motifs, catalogue), motifs = motifs, messages = messages)
}

# ---------------------------------------------------------------------------
# Fusion de paquets rendus : union sur l'uuid, rejouable, conflit jamais tranche en silence
# ---------------------------------------------------------------------------

.dp_cle_contenu <- function(row) {
  row <- row[order(names(row))]
  as.character(jsonlite::toJSON(row, auto_unbox = TRUE, null = "null", digits = NA, force = TRUE))
}

.dp_noms_photos <- function(contenu) {
  liste <- contenu[["photos"]]
  if (!.dp_est_tableau(liste)) return(character())
  unlist(lapply(liste, function(p) if (is.list(p) && is.character(p[["nom"]])) p[["nom"]] else NULL))
}

# Union sur l'`uuid` des centres et des notes, `etat` « notee » des qu'un paquet l'a, photos
# reunies. Un meme uuid (ou une meme photo) a deux contenus differents est ecarte, avec ses
# photos ; le reste de l'union est garde ; chaque version ecartee est rendue dans `conflits`.
# Un centre en conflit : la placette « notee » et ses notes sont gardees et la placette est
# signalee. Rend list(paquet, conflits (data.frame objet, cle, plot_id, message)).
.dp_fusionner <- function(paquets, operateur, version_ramulus) {
  base <- paquets[[1L]]$inst
  tables <- intersect(c("centres", .dp_tables_notes), names(base$tables))
  versions <- list()
  for (t in tables) {
    v <- list()
    for (p in paquets) {
      for (l in .dp_lignes(p$inst, t)) {
        row <- l[setdiff(names(l), "fid")]
        u <- as.character(.dp_ou(row[["uuid"]], ""))
        k <- .dp_cle_contenu(row)
        if (is.null(v[[u]])) v[[u]] <- list()
        if (!k %in% names(v[[u]])) v[[u]][[k]] <- row
      }
    }
    versions[[t]] <- v
  }
  photos_v <- list()
  for (p in paquets) {
    for (n in names(p$photos)) {
      if (is.null(photos_v[[n]])) photos_v[[n]] <- character()
      photos_v[[n]] <- union(photos_v[[n]], p$photos[[n]])
    }
  }
  conflits <- list()
  nouveau <- function(objet, cle, message, plot_id = NA_character_) {
    conflits[[length(conflits) + 1L]] <<- data.frame(objet = objet, cle = cle, plot_id = plot_id,
                                                      message = message, stringsAsFactors = FALSE)
  }
  ecartes <- stats::setNames(rep(list(character()), length(tables)), tables)
  for (t in tables) {
    for (u in names(versions[[t]])) {
      vus <- versions[[t]][[u]]
      if (length(vus) > 1L) {
        cols <- sort(unique(unlist(lapply(vus, function(r) {
          unlist(lapply(unique(unlist(lapply(vus, names))), function(c) {
            if (!all(vapply(vus, function(o) .dp_egal(o[[c]], vus[[1L]][[c]]), logical(1)))) c
          }))
        }))))
        nouveau(t, u, sprintf("%s : uuid %s porte %d contenus diff\u00e9rents (colonnes %s) ; aucune version gard\u00e9e",
                              t, u, length(vus), paste(cols, collapse = "/")),
                .dp_ou(vus[[1L]][["plot_id"]], NA_character_))
        ecartes[[t]] <- c(ecartes[[t]], u)
      }
    }
  }
  en_conflit <- names(photos_v)[vapply(photos_v, length, integer(1)) > 1L]
  for (n in sort(en_conflit, method = "radix")) {
    nouveau("photos", n, sprintf("photo %s : %d contenus diff\u00e9rents ; aucune version gard\u00e9e, ni la note qui la cite", n, length(photos_v[[n]])))
  }
  for (t in intersect(.dp_tables_notes, tables)) {
    for (u in names(versions[[t]])) {
      noms <- unique(unlist(lapply(versions[[t]][[u]], .dp_noms_photos)))
      if (!u %in% ecartes[[t]] && length(intersect(noms, en_conflit))) {
        ecartes[[t]] <- c(ecartes[[t]], u)
        nouveau(t, u, sprintf("%s : uuid %s \u00e9cart\u00e9e avec sa photo en conflit (%s)", t, u, paste(sort(intersect(noms, en_conflit), method = "radix"), collapse = ", ")),
                .dp_ou(versions[[t]][[u]][[1L]][["plot_id"]], NA_character_))
      }
    }
  }
  photos_ecartees <- en_conflit
  for (t in intersect(.dp_tables_notes, tables)) {
    for (u in ecartes[[t]]) {
      for (c in versions[[t]][[u]]) photos_ecartees <- union(photos_ecartees, .dp_noms_photos(c))
    }
  }
  for (n in sort(setdiff(photos_ecartees, en_conflit), method = "radix")) {
    if (n %in% names(photos_v)) nouveau("photos", n, sprintf("photo %s \u00e9cart\u00e9e avec la note qui la cite", n))
  }

  for (t in tables) {
    cols <- names(base$tables[[t]]$colonnes)
    gardes <- sort(setdiff(names(versions[[t]]), ecartes[[t]]), method = "radix")
    base$tables[[t]]$lignes <- lapply(seq_along(gardes), function(i) {
      row <- c(list(fid = i), versions[[t]][[gardes[i]]][[1L]])
      stats::setNames(lapply(cols, function(c) row[[c]]), cols)
    })
  }
  notees <- unique(unlist(lapply(paquets, function(p) {
    vapply(Filter(function(l) identical(l[["etat"]], "notee"), .dp_lignes(p$inst, "placettes")),
           function(l) l[["plot_id"]], character(1))
  })))
  for (i in seq_along(base$tables$placettes$lignes)) {
    base$tables$placettes$lignes[[i]]["etat"] <- list(
      if (base$tables$placettes$lignes[[i]][["plot_id"]] %in% notees) "notee" else NULL
    )
  }
  base$tables$tournee$lignes[[1L]]["operateur"] <- list(operateur)
  base$tables$tournee$lignes[[1L]]["version_ramulus"] <- list(version_ramulus)
  photos <- unlist(photos_v[sort(setdiff(names(photos_v), photos_ecartees), method = "radix")])
  photos <- if (length(photos)) stats::setNames(vapply(photos_v[names(photos)], function(x) x[1L], character(1)), names(photos)) else stats::setNames(character(), character())
  base$photos_du_paquet <- unname(lapply(names(photos), function(n) list(nom = n, sha256 = photos[[n]])))
  fichiers <- list()
  for (p in rev(paquets)) fichiers[names(p$fichiers_photos)] <- as.list(p$fichiers_photos)
  cf <- if (length(conflits)) do.call(rbind, conflits) else
    data.frame(objet = character(), cle = character(), plot_id = character(), message = character(), stringsAsFactors = FALSE)
  cf <- cf[order(cf$objet, cf$cle, method = "radix"), , drop = FALSE]
  rownames(cf) <- NULL
  list(paquet = list(inst = base, photos = photos, fichiers_photos = unlist(fichiers[names(photos)])),
       conflits = cf)
}

.dp_controler_fusion <- function(paquets, operateur, version_ramulus, depart = NULL, schema = .dp_schema()) {
  f <- .dp_fusionner(paquets, operateur, version_ramulus)
  r <- .dp_controler(f$paquet, depart, schema)
  cf <- f$conflits
  signalees <- sort(unique(cf$plot_id[cf$objet == "centres" & !is.na(cf$plot_id)]), method = "radix")
  if (nrow(cf)) {
    motifs <- sort(union(r$motifs, "uuid_contenu_different"), method = "radix")
    messages <- c(r$messages, paste0("uuid_contenu_different : ", cf$message),
                  sprintf("uuid_contenu_different : placette %s signal\u00e9e, gard\u00e9e avec ses notes et sans centre ; dire quel centre fait foi, puis rendre de nouveau", signalees))
    r <- list(statut = .dp_statut(motifs, .dp_motifs(schema)), motifs = motifs, messages = messages)
  }
  c(r, list(paquet = f$paquet, conflits = cf, placettes_signalees = signalees))
}

# ---------------------------------------------------------------------------
# Tables R a partir de l'instantane
# ---------------------------------------------------------------------------

.dp_horodatage <- function(x) {
  as.POSIXct(strptime(sub("Z$", "", x), "%Y-%m-%dT%H:%M:%OS", tz = "UTC"), tz = "UTC")
}

# data.frame d'une table de l'instantane (colonnes typees d'apres leur type declare).
.dp_table_df <- function(inst, nom) {
  t <- inst$tables[[nom]]
  cols <- setdiff(names(t$colonnes), if (is.list(t$geometrie)) t$geometrie$colonne)
  d <- lapply(cols, function(c) {
    v <- lapply(t$lignes, function(l) l[[c]])
    typ <- t$colonnes[[c]]
    if (c == "photos") {
      return(vapply(v, function(x) if (is.character(x)) x else as.character(jsonlite::toJSON(x, auto_unbox = TRUE)), character(1)))
    }
    v <- vapply(v, function(x) if (is.null(x)) NA_character_ else as.character(x), character(1))
    switch(typ,
      INTEGER = as.integer(v), REAL = as.numeric(v), BOOLEAN = as.logical(as.integer(v)),
      DATETIME = .dp_horodatage(v), v
    )
  })
  names(d) <- cols
  as.data.frame(d, stringsAsFactors = FALSE, optional = TRUE)
}

.dp_table_sf <- function(inst, nom) {
  d <- .dp_table_df(inst, nom)
  ls <- inst$tables[[nom]]$lignes
  if (!length(ls)) {
    return(sf::st_sf(d, geometry = sf::st_sfc(crs = 2154)))
  }
  xy <- t(vapply(ls, function(l) c(l$geom$x, l$geom$y), numeric(2)))
  sf::st_sf(d, geometry = sf::st_sfc(lapply(seq_len(nrow(xy)), function(i) sf::st_point(xy[i, ])), crs = 2154))
}

# ---------------------------------------------------------------------------
# importer_deperis()
# ---------------------------------------------------------------------------

#' Import a DEPERIS round returned by Ramulus
#'
#' Reads the package(s) `.zip` returned by the Ramulus app (a completed
#' `deperis.gpkg` plus its `photos/`), checks them against the `deperis-v1`
#' format and the round that Nemeton wrote (`creer_tournee_deperis()`), and
#' returns the verdict, the reasons and, unless refused, the data.
#'
#' The import is **all or nothing**: a package with at least one refusal reason
#' imports nothing. It is **replayable without duplicates**: rows are merged on
#' their `uuid`, so importing the same package twice, or a package already
#' contained in `precedent`, gives the same data. Several packages (several
#' operators) are merged the same way; a same `uuid` (or photo) with two
#' different contents is a conflict: both versions are left out, the rest of the
#' union is kept and the package is flagged (`uuid_contenu_different`), never
#' settled silently. The class of each note is **recomputed** from the abacus
#' (MB and MR or MA) of the DSF sheets and a different class is refused
#' (`classe_differente_abaque`).
#'
#' The reasons come from the catalogue of the format (copy of the Ramulus schema
#' in `inst/schemas/`): refusals such as `plan_modifie` (a value Nemeton wrote
#' came back changed), `essence_hors_referentiel`, `note_hors_bornes`,
#' `photo_absente`, `hors_france`, and flags such as `doublon_arbre`,
#' `centre_eloigne`, `uuid_contenu_different`. A flagged package is imported with
#' its flags; only a refusal blocks.
#'
#' @param zip Character. One or several `.zip` packages returned by Ramulus (or
#'   `deperis.gpkg` files).
#' @param depart Character. Path of the `deperis.gpkg` that `creer_tournee_deperis()`
#'   wrote for this round (what Nemeton wrote must come back unchanged).
#' @param precedent Optional result of an earlier `importer_deperis()` of the same
#'   round; its data are merged with `zip` (replay without duplicates).
#' @param operateur,version_ramulus Operator and Ramulus version written in the
#'   `tournee` row of the union when several packages are merged (default: those of
#'   the first package).
#' @param dossier_photos Optional directory where the photos kept by the import
#'   are copied (never written on refusal).
#' @return A list of class `deperis_import` with `verdict` (`"accepte"`,
#'   `"signale"` or `"refuse"`), `motifs` (sorted reason codes), `messages`,
#'   `importe` (logical), `nature`, `code_tournee`, and, when imported:
#'   `placettes`, `centres` (`sf` points, EPSG:2154), `notes` (data.frame with the
#'   recomputed `classe` and the source `table`), `photos` (data.frame `nom`,
#'   `sha256`, `chemin`), `conflits` (data.frame `objet`, `cle`, `plot_id`,
#'   `message`) and `placettes_signalees` (plots whose centre was left out for a
#'   conflict, kept with their notes). The `paquet` element keeps the merged
#'   package for `precedent`.
#' @seealso [creer_tournee_deperis()]
#' @export
importer_deperis <- function(zip, depart, precedent = NULL, operateur = NULL,
                             version_ramulus = NULL, dossier_photos = NULL) {
  .dp_exiger()
  if (missing(zip) || !length(zip)) cli::cli_abort("{.arg zip} must name at least one package.")
  if (missing(depart) || is.null(depart)) {
    cli::cli_abort("{.arg depart} (the {.file deperis.gpkg} Nemeton wrote) is required: what Nemeton wrote must come back unchanged.")
  }
  if (!is.null(precedent) && !(inherits(precedent, "deperis_import") && isTRUE(precedent$importe))) {
    cli::cli_abort("{.arg precedent} must be an earlier {.fn importer_deperis} result that was imported (not refused).")
  }
  tmp <- tempfile("deperis-import-")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  paquets <- lapply(seq_along(zip), function(i) .dp_lire_paquet(zip[[i]], file.path(tmp, i)))
  dep <- .dp_lire_paquet(depart, file.path(tmp, "depart"))
  if (!is.null(dep$erreur)) cli::cli_abort("{.arg depart} is not a readable {.file deperis.gpkg}: {dep$erreur[2L]}")
  lus <- Filter(function(p) is.null(p$erreur), paquets)
  inconnu <- length(lus) < length(paquets)
  if (!is.null(precedent)) lus <- c(list(precedent$paquet), lus)

  cf <- NULL
  signalees <- character()
  if (inconnu) {
    err <- paquets[[which(!vapply(paquets, function(p) is.null(p$erreur), logical(1)))[1L]]]
    r <- .dp_controler(err, NULL)
    paquet <- NULL
  } else if (length(lus) == 1L) {
    r <- .dp_controler(lus[[1L]], dep)
    paquet <- lus[[1L]]
  } else {
    op <- .dp_ou(operateur, lus[[1L]]$inst$tables$tournee$lignes[[1L]][["operateur"]])
    vr <- .dp_ou(version_ramulus, lus[[1L]]$inst$tables$tournee$lignes[[1L]][["version_ramulus"]])
    r <- .dp_controler_fusion(lus, op, vr, dep)
    paquet <- r$paquet
    cf <- r$conflits
    signalees <- r$placettes_signalees
  }
  out <- list(verdict = r$statut, motifs = r$motifs, messages = r$messages, importe = !identical(r$statut, "refuse"),
              nature = if (!is.null(paquet)) paquet$inst$nature else NULL,
              code_tournee = if (!is.null(paquet)) paquet$inst$tables$tournee$lignes[[1L]][["code_tournee"]] else NULL)
  if (out$importe) {
    inst <- paquet$inst
    notes <- do.call(rbind, lapply(intersect(.dp_tables_notes, names(inst$tables)), function(t) {
      d <- .dp_table_df(inst, t)
      d$table <- rep(t, nrow(d))
      d
    }))
    if (!is.null(notes) && nrow(notes)) notes$classe <- .dp_classe(notes$mb, notes$second)
    ph <- paquet$photos
    chemins <- if (length(ph)) unname(paquet$fichiers_photos[names(ph)]) else character()
    if (!is.null(dossier_photos) && length(ph)) {
      dir.create(dossier_photos, recursive = TRUE, showWarnings = FALSE)
      for (i in seq_along(ph)) {
        if (is.na(chemins[i]) || !file.exists(chemins[i])) next
        dest <- file.path(dossier_photos, basename(names(ph)[i]))
        file.copy(chemins[i], dest, overwrite = TRUE)
        chemins[i] <- dest
      }
    } else {
      chemins <- rep(NA_character_, length(ph))
    }
    # Le paquet garde les empreintes ; les fichiers extraits sont temporaires.
    paquet$fichiers_photos <- NULL
    out <- c(out, list(
      placettes = .dp_table_sf(inst, "placettes"),
      centres = .dp_table_sf(inst, "centres"),
      notes = notes,
      photos = data.frame(nom = names(ph), sha256 = unname(ph), chemin = chemins, stringsAsFactors = FALSE),
      conflits = if (is.null(cf)) data.frame(objet = character(), cle = character(), plot_id = character(), message = character(), stringsAsFactors = FALSE) else cf,
      placettes_signalees = signalees,
      paquet = paquet
    ))
  }
  structure(out, class = "deperis_import")
}

#' @export
print.deperis_import <- function(x, ...) {
  cat("<deperis_import> ", x$verdict, if (length(x$motifs)) paste0(" : ", paste(x$motifs, collapse = ", ")), "\n", sep = "")
  if (isTRUE(x$importe)) {
    cat(nrow(x$placettes), " placette(s), ", nrow(x$centres), " centre(s), ",
        if (is.null(x$notes)) 0L else nrow(x$notes), " note(s), ", nrow(x$photos), " photo(s)\n", sep = "")
  } else {
    cat("refus : rien n'est import\u00e9\n")
  }
  invisible(x)
}

# ---------------------------------------------------------------------------
# creer_tournee_deperis()
# ---------------------------------------------------------------------------

.dp_wkt_2154 <- paste0(
  'PROJCS["RGF93 v1 / Lambert-93",GEOGCS["RGF93 v1",DATUM["Reseau_Geodesique_Francais_1993_v1",',
  'SPHEROID["GRS 1980",6378137,298.257222101,AUTHORITY["EPSG","7019"]],AUTHORITY["EPSG","6171"]],',
  'PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],',
  'AUTHORITY["EPSG","4171"]],PROJECTION["Lambert_Conformal_Conic_2SP"],PARAMETER["latitude_of_origin",46.5],',
  'PARAMETER["central_meridian",3],PARAMETER["standard_parallel_1",49],PARAMETER["standard_parallel_2",44],',
  'PARAMETER["false_easting",700000],PARAMETER["false_northing",6600000],UNIT["metre",1,AUTHORITY["EPSG","9001"]],',
  'AXIS["Easting",EAST],AXIS["Northing",NORTH],AUTHORITY["EPSG","2154"]]'
)
.dp_wkt_4326 <- paste0(
  'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],',
  'AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],',
  'UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AXIS["Latitude",NORTH],AXIS["Longitude",EAST],',
  'AUTHORITY["EPSG","4326"]]'
)

# Colonnes de note, non permises dans une placette de la tournee de contre-notation.
.dp_cols_note <- c("uuid", "plot_id", "rang", "repere", "essence", "type", "mb", "second", "critere", "classe",
                   "saison", "date_notation", "operateur", "photos", "ia_premiere_mb", "ia_premiere_second",
                   "ia_mb", "ia_second", "ia_confiance", "ia_modele")

.dp_nfc <- function(x) if (is.character(x)) stringi::stri_trans_nfc(x) else x

.dp_horodatage_txt <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")

#' Write the starting file of a DEPERIS round (`deperis.gpkg`)
#'
#' Writes the `deperis.gpkg` that the Ramulus app completes in the field
#' (format `deperis-v1`, EPSG:2154): tables `tournee` (one row), `placettes`
#' (planned points and the columns of the plan) and the empty tables `centres`
#' and `notations`. With `nature = "contre_notation"` it writes the separate file
#' of the second operator: only the plots marked for re-scoring, the centre of the
#' first operator as a read-only copy, an empty `contre_notations` table and
#' **no** `notations` table nor any first note.
#'
#' The file is written to the OGC GeoPackage rules the format requires: `geom`
#' and `fid` column names, **no spatial index** on `placettes` and `centres`
#' (`SPATIAL_INDEX=NO`: no R*Tree table or trigger), no column named `date`,
#' ISO 8601 UTC time stamps, NFC text, `notations` and `contre_notations`
#' as `attributes` tables. The file just written is read back and checked by the
#' same control as an import; nothing is returned if it would be refused.
#'
#' The re-scoring covers a share of the plots (5 \% in the brief), drawn
#' reproducibly: the plots are sorted by `plot_id`, then drawn with
#' `set.seed(graine)`, so the same plan and seed give the same draw.
#'
#' @param plan An `sf` object of POINT geometries in EPSG:2154 (planned points,
#'   inside the extent of EPSG:2154), one row per plot. Required column `plot_id`
#'   (unique text); columns `nb_arbres` (integer, at least 1), `collecte_photos`
#'   and `contre_notation` (logical or 0/1) are used when present; every other
#'   column (`wgt`, `ip`, `stratum`, `strat_*`...) is a plan column, copied as is
#'   and never changed by Ramulus. `etat`, `regle_choix`, `saison` and `fid` are
#'   reserved, and no column may be named `date`.
#' @param code Character. Code of the round (letters, digits, `.`, `_`, `-`); it
#'   names the returned `.zip`. Never a person or agent name.
#' @param nature `"premiere"` (first scoring, default) or `"contre_notation"`.
#' @param saison `"ETE"` or `"HIVER"`.
#' @param regle_choix Character. Tree choice rule, a campaign parameter; default
#'   "Kraft 1 à 3, tour d'horizon depuis le nord, sens horaire".
#' @param dossier Directory where `deperis.gpkg` is written (created if missing).
#' @param contre_notation For `nature = "premiere"`: `NULL` (use the `contre_notation`
#'   column of the plan if any, else none), a share in (0, 1] of the plots to mark
#'   for re-scoring (e.g. `0.05`, at least one plot), or a character vector of
#'   `plot_id`. For `nature = "contre_notation"`: the result of [importer_deperis()]
#'   on the first round, which provides the centres.
#' @param graine Integer seed of the re-scoring draw.
#' @param nb_arbres,collecte_photos Campaign values used when the plan has no such
#'   column (`nb_arbres` is then required; `collecte_photos` defaults to `FALSE`).
#' @param prepare_le Time stamp of the preparation (default now, written in UTC).
#' @param delai_contre_notation_jours Maximal delay in days between the two
#'   passes, or `NULL` (left empty; the value is not settled yet).
#' @param version_nemeton Character, default the installed nemeton version.
#' @param overwrite Logical; replace an existing `deperis.gpkg`?
#' @return The path of the written `deperis.gpkg`, invisibly, with the attribute
#'   `contre_notation` (the `plot_id` marked for re-scoring).
#' @seealso [importer_deperis()]
#' @export
creer_tournee_deperis <- function(plan, code, nature = c("premiere", "contre_notation"),
                                  saison = c("ETE", "HIVER"), regle_choix = .dp_regle_choix_defaut,
                                  dossier, contre_notation = NULL, graine = 1L,
                                  nb_arbres = NULL, collecte_photos = NULL,
                                  prepare_le = Sys.time(), delai_contre_notation_jours = NULL,
                                  version_nemeton = NULL, overwrite = FALSE) {
  .dp_exiger()
  nature <- match.arg(nature)
  saison <- match.arg(saison)
  if (!is.character(code) || length(code) != 1L || !grepl("^[A-Za-z0-9._-]+$", code)) {
    cli::cli_abort("{.arg code} must be one string of letters, digits, {.val .}, {.val _} or {.val -}.")
  }
  if (!is.character(regle_choix) || length(regle_choix) != 1L || !nzchar(regle_choix)) {
    cli::cli_abort("{.arg regle_choix} must be one non-empty string.")
  }
  if (!inherits(plan, "sf") || !all(sf::st_geometry_type(plan) == "POINT")) {
    cli::cli_abort("{.arg plan} must be an {.cls sf} object of POINT geometries.")
  }
  if (is.na(sf::st_crs(plan)$epsg) || sf::st_crs(plan)$epsg != 2154L) {
    cli::cli_abort(c("{.arg plan} must be in EPSG:2154.", "i" = "Reproject it with {.fn sf::st_transform}; the overseas departments are out of version 1."))
  }
  xy <- sf::st_coordinates(plan)
  d <- sf::st_drop_geometry(plan)
  d[] <- lapply(d, function(c) if (is.factor(c)) as.character(c) else c)
  if (!"plot_id" %in% names(d) || !is.character(d$plot_id) || anyNA(d$plot_id) || any(!nzchar(d$plot_id)) ||
        anyDuplicated(d$plot_id)) {
    cli::cli_abort("{.arg plan} needs a {.field plot_id} column of unique non-empty text.")
  }
  reserves <- intersect(c("fid", "geom", "geometry", "etat", "regle_choix", "saison"), names(d))
  if (length(reserves)) cli::cli_abort("Reserved column{?s} in {.arg plan}: {.field {reserves}} (set by the function or by Ramulus).")
  if (any(grepl("^date$", names(d), ignore.case = TRUE))) {
    cli::cli_abort("No column may be named {.field date} (reserved word in GeoPackage); use {.field date_releve}.")
  }
  autres_notes <- intersect(.dp_cols_note, setdiff(names(d), "plot_id"))
  if (length(autres_notes)) cli::cli_abort("{.arg plan} carries note column{?s} {.field {autres_notes}}: a round holds no first note.")
  if (!all(.dp_en_france(xy[, 1], xy[, 2]))) {
    cli::cli_abort("Some planned points are outside the extent of EPSG:2154 (France mainland and Corsica): X and Y swapped?")
  }
  n <- nrow(d)
  if (!"nb_arbres" %in% names(d)) {
    if (is.null(nb_arbres)) cli::cli_abort("{.arg plan} has no {.field nb_arbres} column: give {.arg nb_arbres}.")
    d$nb_arbres <- rep(as.integer(nb_arbres), n)
  }
  if (anyNA(d$nb_arbres) || any(d$nb_arbres < 1) || any(d$nb_arbres != floor(d$nb_arbres))) {
    cli::cli_abort("{.field nb_arbres} must be whole numbers, at least 1.")
  }
  d$nb_arbres <- as.integer(d$nb_arbres)
  if (!"collecte_photos" %in% names(d)) d$collecte_photos <- rep(isTRUE(as.logical(.dp_ou(collecte_photos, FALSE))), n)
  d$collecte_photos <- as.integer(as.logical(d$collecte_photos))
  if (anyNA(d$collecte_photos)) cli::cli_abort("{.field collecte_photos} must be logical or 0/1.")
  if (!"contre_notation" %in% names(d)) d$contre_notation <- rep(FALSE, n)
  d$contre_notation <- as.integer(as.logical(d$contre_notation))
  if (anyNA(d$contre_notation)) cli::cli_abort("{.field contre_notation} must be logical or 0/1.")

  tirage <- function(part, graine) {
    ordre <- order(d$plot_id, method = "radix")
    k <- max(1L, as.integer(ceiling(part * n - 1e-9)))
    k <- min(k, n)
    ids <- d$plot_id[ordre][withr::with_seed(as.integer(graine), sort(sample.int(n, k)))]
    ids
  }
  centres <- NULL
  if (nature == "premiere") {
    if (!is.null(contre_notation)) {
      if (is.numeric(contre_notation) && length(contre_notation) == 1L && contre_notation > 0 && contre_notation <= 1) {
        marques <- tirage(contre_notation, graine)
      } else if (is.character(contre_notation)) {
        inconnues <- setdiff(contre_notation, d$plot_id)
        if (length(inconnues)) cli::cli_abort("{.arg contre_notation} names unknown plot{?s}: {.val {inconnues}}.")
        marques <- contre_notation
      } else {
        cli::cli_abort("For a first round, {.arg contre_notation} is {.code NULL}, a share in (0, 1] or plot ids.")
      }
      d$contre_notation <- as.integer(d$plot_id %in% marques)
    }
    ligne_centres <- NULL
  } else {
    if (!inherits(contre_notation, "deperis_import") || !isTRUE(contre_notation$importe)) {
      cli::cli_abort("For {.code nature = \"contre_notation\"}, {.arg contre_notation} must be the {.fn importer_deperis} result of the first round (it provides the centres).")
    }
    marques <- d$plot_id[d$contre_notation == 1L]
    if (!length(marques)) cli::cli_abort("No plot of {.arg plan} is marked {.field contre_notation}: mark them when writing the first round.")
    c1 <- contre_notation$centres
    sans <- setdiff(marques, c1$plot_id)
    if (length(sans)) cli::cli_abort("Plot{?s} {.val {sans}} {?has/have} no centre in the first round: they cannot be re-scored.")
    gardees <- !duplicated(c1$plot_id, fromLast = TRUE) # au plus un centre par placette : le dernier releve
    centres <- c1[c1$plot_id %in% marques & gardees, ]
    centres <- centres[order(centres$plot_id, method = "radix"), ]
    sel <- d$plot_id %in% marques
    d <- d[sel, , drop = FALSE]
    xy <- xy[sel, , drop = FALSE]
    n <- nrow(d)
  }

  chemin <- file.path(dossier, "deperis.gpkg")
  if (file.exists(chemin) && !overwrite) cli::cli_abort("{.path {chemin}} already exists; use {.code overwrite = TRUE}.")
  dir.create(dossier, recursive = TRUE, showWarnings = FALSE)
  prep <- .dp_horodatage_txt(prepare_le)
  if (is.null(version_nemeton)) version_nemeton <- as.character(utils::packageVersion("nemeton"))

  # Colonnes de la couche placettes : celles du plan, puis les parametres de campagne.
  libres <- setdiff(names(d), c("plot_id", "nb_arbres", "collecte_photos", "contre_notation"))
  d$regle_choix <- regle_choix
  d$saison <- saison
  d$etat <- NA_character_
  ordre_cols <- c("plot_id", libres, "nb_arbres", "regle_choix", "saison", "collecte_photos", "contre_notation", "etat")
  d <- d[, ordre_cols, drop = FALSE]
  typer <- function(v, nom) {
    if (nom %in% c("collecte_photos", "contre_notation")) return("BOOLEAN")
    if (is.integer(v)) return("INTEGER")
    if (is.logical(v)) return("BOOLEAN")
    if (is.numeric(v)) return("REAL")
    if (is.character(v)) return("TEXT")
    cli::cli_abort("Plan column {.field {nom}} has an unsupported type ({.cls {class(v)[1]}}); use numbers, text or logicals.")
  }
  types_p <- vapply(names(d), function(nm) typer(d[[nm]], nm), character(1))
  names(d) <- .dp_nfc(names(d))
  names(types_p) <- names(d)

  tmp <- paste0(chemin, ".tmp")
  unlink(tmp)
  con <- DBI::dbConnect(RSQLite::SQLite(), tmp)
  ok <- FALSE
  on.exit({
    suppressWarnings(try(DBI::dbDisconnect(con), silent = TRUE))
    if (!ok) unlink(tmp)
  }, add = TRUE)
  DBI::dbExecute(con, sprintf("PRAGMA application_id = %d", .dp_application_id))
  DBI::dbExecute(con, sprintf("PRAGMA user_version = %d", .dp_user_version))
  for (s in c(
    "CREATE TABLE gpkg_spatial_ref_sys (srs_name TEXT NOT NULL, srs_id INTEGER NOT NULL PRIMARY KEY, organization TEXT NOT NULL, organization_coordsys_id INTEGER NOT NULL, definition TEXT NOT NULL, description TEXT)",
    "CREATE TABLE gpkg_contents (table_name TEXT NOT NULL PRIMARY KEY, data_type TEXT NOT NULL, identifier TEXT UNIQUE, description TEXT DEFAULT '', last_change DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')), min_x DOUBLE, min_y DOUBLE, max_x DOUBLE, max_y DOUBLE, srs_id INTEGER, CONSTRAINT fk_gc_r_srs_id FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys(srs_id))",
    "CREATE TABLE gpkg_geometry_columns (table_name TEXT NOT NULL, column_name TEXT NOT NULL, geometry_type_name TEXT NOT NULL, srs_id INTEGER NOT NULL, z TINYINT NOT NULL, m TINYINT NOT NULL, CONSTRAINT pk_geom_cols PRIMARY KEY (table_name, column_name), CONSTRAINT uk_gc_table_name UNIQUE (table_name), CONSTRAINT fk_gc_tn FOREIGN KEY (table_name) REFERENCES gpkg_contents(table_name), CONSTRAINT fk_gc_srs FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys (srs_id))",
    "CREATE TABLE gpkg_extensions (table_name TEXT, column_name TEXT, extension_name TEXT NOT NULL, definition TEXT NOT NULL, scope TEXT NOT NULL, CONSTRAINT ge_tce UNIQUE (table_name, column_name, extension_name))"
  )) DBI::dbExecute(con, s)
  for (r in list(list("Undefined Cartesian SRS", -1L, "NONE", -1L, "undefined"),
                 list("Undefined geographic SRS", 0L, "NONE", 0L, "undefined"),
                 list("WGS 84 geodetic", 4326L, "EPSG", 4326L, .dp_wkt_4326),
                 list("RGF93 v1 / Lambert-93", 2154L, "EPSG", 2154L, .dp_wkt_2154))) {
    DBI::dbExecute(con, "INSERT INTO gpkg_spatial_ref_sys VALUES (?,?,?,?,?,NULL)", params = unname(r))
  }
  creer_table <- function(nom, colonnes, data_type, bornes = c(NA_real_, NA_real_, NA_real_, NA_real_), geom = FALSE) {
    defs <- vapply(names(colonnes), function(c) {
      if (c == "fid") "\"fid\" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL" else paste0(.dp_q(c), " ", colonnes[[c]])
    }, character(1))
    DBI::dbExecute(con, sprintf("CREATE TABLE %s (%s)", .dp_q(nom), paste(defs, collapse = ", ")))
    srs <- if (geom) 2154L else 0L
    DBI::dbExecute(con, "INSERT INTO gpkg_contents VALUES (?,?,?,'',?,?,?,?,?,?)",
                   params = list(nom, data_type, nom, prep, bornes[1], bornes[2], bornes[3], bornes[4], srs))
    if (geom) DBI::dbExecute(con, "INSERT INTO gpkg_geometry_columns VALUES (?,?,'POINT',2154,0,0)", params = list(nom, "geom"))
  }
  inserer <- function(nom, cols, valeurs) {
    DBI::dbExecute(con, sprintf("INSERT INTO %s (%s) VALUES (%s)", .dp_q(nom), paste(.dp_q(cols), collapse = ","),
                                paste(rep("?", length(cols)), collapse = ",")), params = unname(valeurs))
  }

  # tournee
  col_t <- list(fid = "INTEGER", version_schema = "INTEGER", code_tournee = "TEXT", nature = "TEXT", prepare_le = "DATETIME",
                version_nemeton = "TEXT", delai_contre_notation_jours = "INTEGER", operateur = "TEXT", version_ramulus = "TEXT")
  creer_table("tournee", col_t, "attributes")
  delai <- if (is.null(delai_contre_notation_jours)) NA_integer_ else as.integer(delai_contre_notation_jours)
  if (!is.na(delai) && delai < 1L) cli::cli_abort("{.arg delai_contre_notation_jours} must be at least 1, or {.code NULL}.")
  inserer("tournee", setdiff(names(col_t), "fid"),
          list(1L, code, nature, prep, .dp_nfc(version_nemeton), delai, NA_character_, NA_character_))
  # placettes
  col_p <- c(list(fid = "INTEGER", geom = "POINT"), as.list(types_p))
  creer_table("placettes", col_p, "features", c(min(xy[, 1]), min(xy[, 2]), max(xy[, 1]), max(xy[, 2])), geom = TRUE)
  for (i in seq_len(n)) {
    v <- lapply(names(d), function(c) {
      x <- d[[c]][i]
      if (is.character(x)) .dp_nfc(x) else if (is.logical(x)) as.integer(x) else x
    })
    DBI::dbExecute(con, sprintf("INSERT INTO placettes (\"geom\", %s) VALUES (?, %s)", paste(.dp_q(names(d)), collapse = ","),
                                paste(rep("?", length(v)), collapse = ",")),
                   params = c(list(list(.dp_blob_point(xy[i, 1], xy[i, 2]))), v))
  }
  # centres
  col_c <- list(fid = "INTEGER", geom = "POINT", uuid = "TEXT", plot_id = "TEXT", precision_m = "REAL",
                nb_mesures = "INTEGER", source = "TEXT", date_releve = "DATETIME", operateur = "TEXT")
  bc <- if (is.null(centres) || !nrow(centres)) c(NA_real_, NA_real_, NA_real_, NA_real_) else {
    cc <- sf::st_coordinates(centres)
    c(min(cc[, 1]), min(cc[, 2]), max(cc[, 1]), max(cc[, 2]))
  }
  creer_table("centres", col_c, "features", bc, geom = TRUE)
  if (!is.null(centres)) {
    cc <- sf::st_coordinates(centres)
    for (i in seq_len(nrow(centres))) {
      DBI::dbExecute(con, "INSERT INTO centres (geom, uuid, plot_id, precision_m, nb_mesures, source, date_releve, operateur) VALUES (?,?,?,?,?,?,?,?)",
                     params = list(list(.dp_blob_point(cc[i, 1], cc[i, 2])), centres$uuid[i], centres$plot_id[i],
                                   centres$precision_m[i], as.integer(centres$nb_mesures[i]), centres$source[i],
                                   .dp_horodatage_txt(centres$date_releve[i]), centres$operateur[i]))
    }
  }
  # notations ou contre_notations (vide) : memes colonnes
  col_n <- list(fid = "INTEGER", uuid = "TEXT", plot_id = "TEXT", rang = "INTEGER", repere = "TEXT", essence = "TEXT",
                type = "TEXT", mb = "INTEGER", second = "INTEGER", critere = "TEXT", classe = "TEXT", saison = "TEXT",
                date_notation = "DATETIME", operateur = "TEXT", photos = "TEXT", ia_premiere_mb = "INTEGER",
                ia_premiere_second = "INTEGER", ia_mb = "INTEGER", ia_second = "INTEGER", ia_confiance = "REAL",
                ia_modele = "TEXT")
  creer_table(if (nature == "premiere") "notations" else "contre_notations", col_n, "attributes")
  DBI::dbDisconnect(con)
  con <- DBI::dbConnect(RSQLite::SQLite(), tmp)
  DBI::dbExecute(con, "VACUUM")
  DBI::dbDisconnect(con)

  # Verification : le fichier ecrit passe le controle comme un import.
  lu <- .dp_lire_paquet(tmp, tempfile("deperis-verif-"))
  r <- .dp_controler(lu, NULL)
  if (!identical(r$statut, "accepte")) {
    cli::cli_abort(c("The file just written would be {r$statut}; nothing is kept.", stats::setNames(utils::head(r$messages, 5), rep("x", min(5, length(r$messages))))))
  }
  if (file.exists(chemin)) unlink(chemin)
  file.rename(tmp, chemin)
  ok <- TRUE
  structure(chemin, contre_notation = sort(if (nature == "premiere") d$plot_id[d$contre_notation == 1L] else d$plot_id, method = "radix")) |>
    invisible()
}
