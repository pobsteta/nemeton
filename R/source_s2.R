# source_s2.R - source Sentinel-2 du suivi sanitaire (mission 096)
# ---------------------------------------------------------------------------
# Une seule notion de « source » pour FAST, FORDEAD, RECONFORT et l'ICD :
#   "theia"   reflectances MAJA (THEIA / MUSCATE), lues par le catalogue STAC
#             THEIA ; masque de validite MAJA (CLM) ;
#   "sen2cor" reflectances Sen2Cor L2A de Planetary Computer (CDSE avant lui),
#             offset BOA retire, masque SCL.
#
# Defaut PAR METHODE (decision de Pascal du 2026-11-27, apres les etudes 092 et
# 093) : chaque methode garde la source sur laquelle elle est calee. Un choix
# global (`source_s2 = "theia"` ou `"sen2cor"`) s'applique aux quatre.
#
# Regles tenues ici :
#   * jamais deux sources dans une meme serie : un cache par source (le cache
#     Sen2Cor reste a sa place, le cache THEIA est son frere `<cache>_theia`) ;
#   * THEIA indisponible -> la serie ENTIERE passe sur Sen2Cor, avec un
#     avertissement de classe `nemeton_s2_repli_sen2cor` ;
#   * THEIA qui repond 401/403 ou cles absentes -> erreur claire, pas de repli ;
#   * une methode qui tourne sur une source ou elle n'est pas calee le dit
#     (`nemeton_s2_source_non_calee`, `calee_sur`, `mention_source`) ; l'appelant
#     en deduit « indicatif » en comparant `calee_sur` a la source effective ;
#   * SANS `source_s2`, rien ne change : memes appels, memes caches, memes cles
#     de sortie qu'avant la mission 096 (aucune sonde, aucun avertissement).

#' @noRd
NULL

# Sources reconnues et source sur laquelle chaque methode est calee.
.S2_SOURCES <- c("theia", "sen2cor")
.S2_CALEE_SUR <- c(reconfort = "theia", fast = "sen2cor",
                   fordead = "sen2cor", icd = "sen2cor")

# Suffixe du dossier de cache THEIA (frere du cache Sen2Cor).
.S2_SUFFIXE_CACHE_THEIA <- "_theia"

# Valide `source_s2` : NULL (defaut par methode) ou `"theia"` / `"sen2cor"`.
.s2_source_valider <- function(source_s2) {
  if (is.null(source_s2)) return(NULL)
  if (!is.character(source_s2) || length(source_s2) != 1L ||
      is.na(source_s2) || !source_s2 %in% .S2_SOURCES) {
    cli::cli_abort(
      "{.arg source_s2} must be {.code NULL}, {.val theia} or {.val sen2cor}.",
      class = "nemeton_s2_source_invalide")
  }
  source_s2
}

#' Sentinel-2 source of a health-monitoring method
#'
#' Resolves which Sentinel-2 reflectance source a method uses, and whether
#' that source is the one the method was calibrated on. Each method keeps its
#' own default (`NULL`): RECONFORT is calibrated on MAJA reflectances
#' (`"theia"`), FAST, FORDEAD and the ICD on Sen2Cor (`"sen2cor"`) (studies
#' 092 and 093 of the platform). A project-wide choice (`"theia"` or
#' `"sen2cor"`) applies to the four methods.
#'
#' @param methode One of `"reconfort"`, `"fast"`, `"fordead"`, `"icd"`.
#' @param source_s2 `NULL` (the method's default), `"theia"` (MAJA, THEIA STAC
#'   catalogue) or `"sen2cor"` (Planetary Computer).
#' @return A list: `source_s2` (the source to use), `defaut` (the method's
#'   default source), `calee_sur` (the source the method is calibrated on),
#'   `mention` (a short note when the method runs off its calibration source,
#'   `NA` otherwise). Comparing `calee_sur` with `source_s2` tells whether the
#'   run is indicative.
#' @export
#' @examples
#' s2_source_resoudre("fast")
#' s2_source_resoudre("fast", "theia")$mention
s2_source_resoudre <- function(methode = c("reconfort", "fast", "fordead", "icd"),
                               source_s2 = NULL) {
  methode <- match.arg(methode)
  source_s2 <- .s2_source_valider(source_s2)
  calee <- unname(.S2_CALEE_SUR[[methode]])
  src <- source_s2 %||% calee
  list(source_s2 = src, defaut = calee, calee_sur = calee,
       mention = .s2_mention(methode, src))
}

# Phrase inscrite dans les metadonnees quand la methode tourne hors de sa
# source de calage ; NA sinon.
.s2_mention <- function(methode, source) {
  calee <- unname(.S2_CALEE_SUR[[methode]])
  if (identical(source, calee)) return(NA_character_)
  sprintf(paste0("%s is calibrated on %s but ran on %s: thresholds to be ",
                 "revisited (platform studies 092 and 093), indicative only"),
          toupper(methode), calee, source)
}

# Memoire des avertissements deja donnes (une fois par session et par `cle`).
.s2_avertis <- new.env(parent = emptyenv())

# Avertissement : methode lancee hors de sa source de calage. Avec `cle` (par
# exemple le dossier de cache lu), il n'est donne qu'une fois par session et par
# cle : une lecture repetee ne reprend pas le meme avertissement.
.s2_avertir_non_calee <- function(methode, source, cle = NULL) {
  calee <- unname(.S2_CALEE_SUR[[methode]])
  if (identical(source, calee)) return(invisible(FALSE))
  if (!is.null(cle)) {
    k <- paste(methode, source, cle, sep = "|")
    if (isTRUE(.s2_avertis[[k]])) return(invisible(FALSE))
    assign(k, TRUE, envir = .s2_avertis)
  }
  cli::cli_warn(c(
    "{toupper(methode)} is calibrated on {.val {calee}} reflectances but runs on {.val {source}}.",
    i = "Thresholds were not re-fitted for this source: results are indicative and NOT validated (platform studies 092 and 093)."),
    class = "nemeton_s2_source_non_calee")
  invisible(TRUE)
}

# Dossier de cache d'une source : le cache Sen2Cor est `cache_dir` tel quel (les
# projets existants ne bougent pas), le cache THEIA est son frere
# `<cache_dir>_theia`. Idempotent : un dossier deja suffixe est rendu tel quel.
.s2_cache_dir_source <- function(cache_dir, source) {
  if (is.null(cache_dir) || !nzchar(cache_dir)) return(cache_dir)
  if (!identical(source, "theia")) return(cache_dir)
  base <- sub("/+$", "", cache_dir)
  if (endsWith(base, .S2_SUFFIXE_CACHE_THEIA)) return(base)
  paste0(base, .S2_SUFFIXE_CACHE_THEIA)
}

# Choisit la source EFFECTIVE d'un lancement qui va chercher des scenes (reseau).
# `sonde` et `cles` sont injectables pour les tests. Rend
# `list(demandee, effective, repli, cause)` ; `repli` vaut TRUE quand THEIA,
# demandee ou par defaut, est indisponible : la serie entiere passe alors sur
# Sen2Cor, avec l'avertissement `nemeton_s2_repli_sen2cor`.
.s2_choisir_source <- function(methode, source_s2 = NULL,
                               sonde = .reconfort_stac_sonde,
                               cles = .reconfort_fenetre_cles_presentes) {
  info <- s2_source_resoudre(methode, source_s2)
  demandee <- info$source_s2
  out <- list(demandee = demandee, effective = demandee, repli = FALSE,
              cause = NA_character_)
  if (identical(demandee, "theia")) {
    if (!isTRUE(cles())) {
      cli::cli_abort(c(
        "{.code source_s2 = \"theia\"} needs THEIA credentials to sign the asset URLs.",
        i = "Set {.envvar TLD_ACCESS_KEY} and {.envvar TLD_SECRET_KEY} (API key at {.url https://gate.stac.teledetection.fr}), or use {.code source_s2 = \"sen2cor\"}."),
        class = "nemeton_s2_theia_sans_cles")
    }
    s <- sonde()
    if (identical(s$etat, "refuse")) {
      cli::cli_abort(c(
        "THEIA STAC catalogue ({.val {s$hote}}) refused the request: {s$cause}.",
        i = "Check {.envvar TLD_ACCESS_KEY} / {.envvar TLD_SECRET_KEY}; falling back to Sen2Cor would hide a key problem."),
        class = "nemeton_s2_theia_refuse")
    }
    if (identical(s$etat, "indisponible")) {
      out$effective <- "sen2cor"
      out$repli <- TRUE
      out$cause <- sprintf("%s: %s", s$hote, s$cause)
      .s2_avertir_repli_sen2cor(methode, out$cause)
    }
  }
  out
}

# Repli THEIA -> Sen2Cor : la serie ENTIERE bascule (jamais deux sources dans
# une meme serie). Classe `nemeton_s2_repli_sen2cor`.
.s2_avertir_repli_sen2cor <- function(methode, cause) {
  cli::cli_warn(c(
    "THEIA unavailable ({cause}): the whole {toupper(methode)} series switches to Sen2Cor (Planetary Computer).",
    i = "Sources are never mixed within a series; the effective source is recorded in the outputs."),
    class = "nemeton_s2_repli_sen2cor")
}

# Classe une erreur de lecture THEIA : "refuse" (401/403, cles a verifier),
# "panne" (reseau, delai, 5xx, 408, 429) ou "autre" (donnee, bug : pas de repli).
# Les erreurs GDAL ne portent pas de classe httr2 : on lit aussi le message, avec
# des motifs BORNES (un nombre de trois chiffres isole n'est pas un code HTTP, un
# mot « timeout » dans une phrase anodine n'est pas un delai).
.s2_classer_erreur_theia <- function(e) {
  cl <- .reconfort_stac_classer_erreur(e)
  if (identical(cl, "refuse")) return("refuse")
  if (identical(cl, "indisponible")) return("panne")
  msg <- conditionMessage(e)
  # Un code HTTP est lu apres « HTTP response code ... : » (forme GDAL, l'URL
  # peut contenir des « : ») ou apres HTTP / status / code / error.
  code <- function(re) {
    grepl(sprintf("HTTP response code.{0,400}?: *(%s)\\b", re), msg,
          ignore.case = TRUE, perl = TRUE) ||
      grepl(sprintf("\\b(http(/[0-9.]+)?|status|code|error)\\b[^0-9]{0,15}\\b(%s)\\b",
                    re), msg, ignore.case = TRUE, perl = TRUE)
  }
  if (code("40[13]") || grepl("\\b(unauthori[sz]ed|forbidden)\\b", msg,
                              ignore.case = TRUE, perl = TRUE)) return("refuse")
  panne <- code("5[0-9]{2}|408|429") ||
    grepl(paste0("bad gateway|gateway time-?out|service unavailable|",
                 "network is unreachable|failed to connect|could not resolve|",
                 "couldn't connect|connection (reset|refused)|",
                 "timed out|timeout was reached"),
          msg, ignore.case = TRUE, perl = TRUE) ||
    grepl("\\bSSL\\b", msg, perl = TRUE)
  if (isTRUE(panne)) "panne" else "autre"
}

# Une erreur de lecture THEIA est-elle une PANNE (reseau, delai, 5xx) ?
.s2_erreur_panne_theia <- function(e) {
  identical(.s2_classer_erreur_theia(e), "panne")
}

# Signale la panne THEIA en cours de serie : attrapee par `.s2_avec_repli()`.
.s2_signaler_panne_theia <- function(e) {
  cli::cli_abort(c(
    "THEIA read failed during the series: {sub('\\n.*$', '', conditionMessage(e))}",
    i = "The whole series is redone on Sen2Cor."),
    class = "nemeton_s2_theia_panne", parent = e)
}

# Refus (401/403) en cours de serie : erreur claire, jamais de repli.
.s2_signaler_refus_theia <- function(e) {
  cli::cli_abort(c(
    "THEIA refused the request during the series: {sub('\\n.*$', '', conditionMessage(e))}",
    i = "Check {.envvar TLD_ACCESS_KEY} / {.envvar TLD_SECRET_KEY}; falling back to Sen2Cor would hide a key problem."),
    class = "nemeton_s2_theia_refuse", parent = e)
}

# Traite une erreur survenue pendant une serie lue sur THEIA : refus -> erreur
# `nemeton_s2_theia_refuse`, panne -> `nemeton_s2_theia_panne` (repli de la
# serie) ; autre erreur : ne fait rien (l'appelant garde son comportement).
.s2_traiter_erreur_serie <- function(e, source_effective) {
  if (!identical(source_effective, "theia")) return(invisible(NULL))
  cl <- .s2_classer_erreur_theia(e)
  if (identical(cl, "refuse")) .s2_signaler_refus_theia(e)
  if (identical(cl, "panne")) .s2_signaler_panne_theia(e)
  invisible(NULL)
}

# Appelle `f(source, info)` ; `info` (repli, cause) n'est passe que si `f` a un
# second argument (les fonctions a un seul argument restent valides).
.s2_appeler <- function(f, source, info) {
  if (length(formals(f)) >= 2L) f(source, info) else f(source)
}

# Execute `f(source, info)` sur la source choisie ; si THEIA tombe en cours de
# serie, jette tout ce que la serie avait fait sur THEIA et la refait
# ENTIEREMENT sur Sen2Cor (avertissement `nemeton_s2_repli_sen2cor`). Rend
# `list(valeur, source, repli, cause)`. `info` dit a `f` si la passe courante est
# un repli (pour que ses metadonnees disent vrai).
.s2_avec_repli <- function(methode, source, f) {
  sans_repli <- list(repli = FALSE, cause = NA_character_)
  if (!identical(source, "theia")) {
    return(c(list(valeur = .s2_appeler(f, source, sans_repli), source = source),
             sans_repli))
  }
  essai <- tryCatch(list(valeur = .s2_appeler(f, "theia", sans_repli)),
                    nemeton_s2_theia_panne = function(e) e)
  if (!inherits(essai, "error")) {
    return(c(list(valeur = essai$valeur, source = "theia"), sans_repli))
  }
  cause <- sub("\n.*$", "", conditionMessage(essai$parent %||% essai))
  .s2_avertir_repli_sen2cor(methode, cause)
  list(valeur = .s2_appeler(f, "sen2cor", list(repli = TRUE, cause = cause)),
       source = "sen2cor", repli = TRUE, cause = cause)
}

# Bloc de metadonnees commun a toutes les sorties (run_meta, meta.json, tags).
# N'est ecrit que lorsque l'appelant a donne `source_s2`. Pas de champ
# « validee » : l'appelant compare `calee_sur` a la source effective.
.s2_meta_source <- function(methode, source, demandee = NULL, repli = FALSE,
                            cause = NA_character_) {
  info <- s2_source_resoudre(methode, source)
  out <- list(source_s2 = source,
              source_s2_demandee = demandee %||% source,
              calee_sur = info$calee_sur,
              repli_sen2cor = isTRUE(repli))
  if (isTRUE(repli) && !is.na(cause)) out$cause_repli <- cause
  if (!is.na(info$mention)) out$mention_source <- info$mention
  out
}

# --- Fournisseur de scenes -----------------------------------------------------

# Cherche les scenes d'une source sur une emprise et une periode, au format
# commun (`scene_id`, `obs_date`, `cloud_pct`, `href_<bande>`, `source`).
# NULL      : appel historique `stac_search_s2()` avec ses sources par defaut
#             (`c("cdse", "pc", "muscate")`) : SANS `source_s2`, rien ne change.
# "sen2cor" : CDSE puis Planetary Computer, JAMAIS le repli MUSCATE (il
#             melangerait les sources dans le cache Sen2Cor).
# "theia"   : catalogue THEIA seul (MAJA). Un echec de la recherche (que
#             `stac_search_s2()` avale en avertissement et en table vide) n'est
#             PAS « aucune scene » : refus -> `nemeton_s2_theia_refuse`, sinon
#             panne -> `nemeton_s2_theia_panne` (repli de la serie entiere).
.s2_chercher_scenes <- function(source, bbox, start, end, max_cloud = 20) {
  if (is.null(source)) {
    return(stac_search_s2(bbox, start, end, max_cloud = max_cloud))
  }
  if (!identical(source, "theia")) {
    return(stac_search_s2(bbox, start, end, max_cloud = max_cloud,
                          source = c("cdse", "pc")))
  }
  echecs <- character(0)
  op <- options(nemeton.s2_muscate_clm = TRUE)
  on.exit(options(op), add = TRUE)
  scenes <- withCallingHandlers(
    stac_search_s2(bbox, start, end, max_cloud = max_cloud, source = "muscate"),
    warning = function(w) {
      m <- conditionMessage(w)
      if (grepl("STAC backends? .*failed", m)) {
        echecs <<- c(echecs, m)
        invokeRestart("muffleWarning")
      }
    })
  if (length(echecs) && !NROW(scenes)) {
    m <- gsub("\033\\[[0-9;]*m", "", echecs[[1L]])
    m <- sub("^STAC backend[^:]*failed: *", "", sub("\n.*$", "", m))
    e <- simpleError(m)
    if (identical(.s2_classer_erreur_theia(e), "refuse")) .s2_signaler_refus_theia(e)
    .s2_signaler_panne_theia(e)
  }
  scenes
}

# Masque MAJA (CLM : 0 = clair, bits non nuls = nuage, ombre...) -> convention
# SCL lue par l'ICD : 9 (nuage) quand le masque est leve, 4 (vegetation) sinon,
# 0 (donnee absente) pour les valeurs manquantes. Les classes 0 et 9 font partie
# des classes masquees de l'ICD (`.ICD_SCL_MASQUE`).
.s2_clm_vers_scl <- function(r) {
  terra::ifel(is.na(r), 0, terra::ifel(r > 0, 9, 4))
}
