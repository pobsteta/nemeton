# inst/scripts/bench_r3_memory.R
#
# Banc de mesure mémoire de la chaîne topographique de R3 sur un MNT réel.
#
# Répond au §6 du hand-off `nemetonshiny` du 2026-08-07
# (BRIEF-nemeton-r3-topo-resolution.md), dernier test attendu qui ne peut pas
# vivre dans testthat : il demande le MNT LiDAR HD de Dabo (12000 x 10000 à
# 0,5 m, 434 Mo) et un cgroup pour que l'OOM killer tue le job et non la session.
#
# Ce qu'il mesure, par configuration :
#   * pic RSS réel (VmHWM du noyau, pas une estimation) ;
#   * pic de temporaires terra écrits sur disque (tempdir dédié, sondé par le
#     parent pendant que l'enfant tourne) ;
#   * temps de calcul ;
#   * scores R3 par unité, d'où l'écart en points /100 contre la référence la
#     plus fine ayant abouti.
#
# Isolation : chaque configuration tourne dans un PROCESSUS ENFANT placé dans un
# scope systemd plafonné (`systemd-run --user --scope -p MemoryMax=… -p
# MemorySwapMax=0`). C'est le coeur du dispositif : `systemd-oomd` tue le scope
# ENTIER sur pression mémoire, donc sans cgroup dédié une configuration qui
# déborde emporterait RStudio, le navigateur et cette session — c'est
# exactement l'incident des 2026-08-06 et 2026-08-07. Ici elle ne tue qu'elle
# même, et ressort en `exit 137` (SIGKILL), qui est un RÉSULTAT de mesure et non
# un échec du banc.
#
# Usage :
#   Rscript inst/scripts/bench_r3_memory.R                       # défauts (Dabo)
#   Rscript inst/scripts/bench_r3_memory.R --cap 6G
#   Rscript inst/scripts/bench_r3_memory.R --res 10,5,2,1,0.5 --memmax 3,off
#   Rscript inst/scripts/bench_r3_memory.R --project <chemin> --out bench.csv
#
# Options :
#   --project <dir>  projet nemeton (défaut : Dabo, 20260801_130303_xpdk)
#   --cap <taille>   plafond du cgroup, syntaxe systemd (défaut 10G)
#   --res <liste>    résolutions de travail en m ; `native` = pas de garde-fou
#   --memmax <liste> plafonds terra en Go ; `off` = comportement terra d'origine
#   --out <fichier>  CSV de sortie (défaut : bench_r3_memory.csv dans le projet)
#   --timeout <s>    plafond de temps par configuration (défaut 1200)
#   --no-cgroup      lance sans systemd-run (DANGEREUX : la session est exposée)
#
# Sur le temps : `native` (garde-fou désactivé) ne coûte pas cher qu'en mémoire.
# La grille du TWI suit la résolution de travail depuis la v0.169.0, donc
# `terra::flowAccumulation()` — un parcours séquentiel — tourne sur les 120 M
# cellules du MNT brut. Mesuré ici : la configuration native ne finit PAS en
# 85 minutes, là où le 2 m boucle en 11 s. C'est pour ça que chaque
# configuration a son propre plafond de temps : une ligne `timeout` est un
# résultat lisible, un banc qui pend ne l'est pas. La leçon de fond : le plafond
# de résolution est la défense principale, `memmax` n'est que le filet.
#
# Aucun effet de bord dans le projet hors le CSV : le cache TWI de chaque
# configuration va dans un répertoire temporaire jetable, pour qu'une grille ne
# soit jamais réutilisée par une autre résolution.

suppressPackageStartupMessages({
  library(nemeton)
})

# ---- utilitaires -----------------------------------------------------------

`%||%` <- function(x, y) if (is.null(x)) y else x

.arg <- function(args, name, default = NULL) {
  i <- match(paste0("--", name), args)
  if (is.na(i) || i == length(args)) return(default)
  args[[i + 1L]]
}

.flag <- function(args, name) paste0("--", name) %in% args

# Pic mémoire du processus, lu dans le noyau (kB -> Go). VmHWM est le high-water
# mark : il survit à un pic transitoire qu'un échantillonnage périodique
# manquerait.
.peak_rss_gb <- function() {
  st <- tryCatch(readLines("/proc/self/status", warn = FALSE), error = function(e) character())
  hw <- grep("^VmHWM:", st, value = TRUE)
  if (!length(hw)) return(NA_real_)
  as.numeric(gsub("[^0-9]", "", hw[[1]])) / 1024^2
}

.dir_size_mb <- function(path) {
  if (!dir.exists(path)) return(0)
  f <- list.files(path, recursive = TRUE, full.names = TRUE, all.files = TRUE,
                  no.. = TRUE)
  if (!length(f)) return(0)
  sum(file.info(f)$size, na.rm = TRUE) / 1024^2
}

# Écrire « sur disque » ne protège de rien si le tempdir est un tmpfs : le spill
# irait en RAM (réserve explicite du §5ter du brief).
.fstype <- function(path) {
  out <- suppressWarnings(system2("findmnt", c("-no", "FSTYPE", "--target", path),
                                  stdout = TRUE, stderr = FALSE))
  if (!length(out)) NA_character_ else trimws(out[[1]])
}

# `systemd-run --scope` place le vrai R dans une unité à part : tuer le process
# parent laisserait le calcul tourner en fond, à consommer la mémoire du poste
# après la fin du banc. On tue donc le R du scope, retrouvé par le chemin de son
# fichier résultat — unique par configuration, donc sans risque de collatéral.
.stop_scope <- function(marker) {
  pids <- tryCatch(
    system2("pgrep", c("-f", marker), stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  )
  for (pid in pids) {
    tryCatch(tools::pskill(as.integer(pid), tools::SIGKILL), error = function(e) NULL)
  }
  invisible(NULL)
}

# ---- enfant : une configuration, un processus ------------------------------

run_child <- function(spec_path) {
  spec <- jsonlite::fromJSON(spec_path)

  # tempdir terra dédié : c'est lui que le parent sonde pour le pic de spill.
  dir.create(spec$tmpdir, recursive = TRUE, showWarnings = FALSE)
  terra::terraOptions(tempdir = spec$tmpdir)
  if (identical(spec$memmax, "off")) {
    terra::terraOptions(memmax = -1)
  } else {
    terra::terraOptions(memmax = as.numeric(spec$memmax))
  }

  dem <- terra::rast(spec$dem)
  units <- sf::st_read(spec$parcels, quiet = TRUE)
  units <- sf::st_transform(units, sf::st_crs(terra::crs(dem)))

  # `native` = garde-fou désactivé, la configuration qui a tué la session.
  topo_res <- if (identical(spec$res, "native")) NULL else as.numeric(spec$res)

  # Résolution effective des grilles terrain/TWI : depuis la v0.169.0 les deux
  # coïncident, et c'est elle qui gouverne le coût, pas la valeur demandée.
  grid_res <- nemeton:::.dem_working_res_value(dem, topo_res)

  t0 <- proc.time()[["elapsed"]]
  out <- indicateur_r3_secheresse(units, dem = dem,
                                  layers = list(cache_dir = spec$twi_cache),
                                  dem_target_res = topo_res)
  elapsed <- proc.time()[["elapsed"]] - t0

  jsonlite::write_json(
    list(res = spec$res, memmax = spec$memmax, grid_res_m = grid_res,
         peak_rss_gb = .peak_rss_gb(), elapsed_s = elapsed,
         scores = as.numeric(out$R3)),
    spec$result, auto_unbox = TRUE, digits = 8, na = "null"
  )
  invisible(NULL)
}

# ---- parent : grille de configurations -------------------------------------

run_bench <- function(args) {
  project <- .arg(args, "project",
                  path.expand("~/.local/share/nemeton/projects/20260801_130303_xpdk"))
  cap     <- .arg(args, "cap", "10G")
  res_l   <- strsplit(.arg(args, "res", "10,5,2,1,native"), ",")[[1]]
  mem_l   <- strsplit(.arg(args, "memmax", "3,off"), ",")[[1]]
  out_csv <- .arg(args, "out", file.path(project, "bench_r3_memory.csv"))
  tmo     <- as.numeric(.arg(args, "timeout", "1200"))
  use_cgroup <- !.flag(args, "no-cgroup")

  dem_path     <- file.path(project, "cache", "layers", "lidar_mnt_mosaic.tif")
  parcels_path <- file.path(project, "data", "parcels.gpkg")
  for (p in c(dem_path, parcels_path)) {
    if (!file.exists(p)) stop("Introuvable : ", p, call. = FALSE)
  }

  scratch <- file.path(tempdir(), sprintf("bench_r3_%d", Sys.getpid()))
  dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)

  fs <- .fstype(scratch)
  if (identical(fs, "tmpfs")) {
    warning("tempdir sur tmpfs : le spill terra ira en RAM, la mesure de ",
            "protection mémoire n'a aucun sens ici. Poser TMPDIR sur un ",
            "vrai système de fichiers.", call. = FALSE, immediate. = TRUE)
  }

  d <- terra::rast(dem_path)
  message(sprintf("MNT   : %d x %d @ %g m (%s) — %.1f M cellules",
                  terra::ncol(d), terra::nrow(d), terra::res(d)[1],
                  terra::crs(d, describe = TRUE)$code %||% "?",
                  terra::ncell(d) / 1e6))
  message(sprintf("Cgroup: %s (%s), tempdir sur %s",
                  if (use_cgroup) cap else "AUCUN — session exposée", "MemorySwapMax=0",
                  fs %||% "?"))
  message("")

  grid <- expand.grid(res = res_l, memmax = mem_l, stringsAsFactors = FALSE)
  rows <- vector("list", nrow(grid))

  for (i in seq_len(nrow(grid))) {
    label <- sprintf("res=%s memmax=%s", grid$res[i], grid$memmax[i])
    tag <- sprintf("%s_%s", gsub("[^0-9a-z]", "", grid$res[i]),
                   gsub("[^0-9a-z]", "", grid$memmax[i]))
    spec <- list(
      res = grid$res[i], memmax = grid$memmax[i],
      dem = dem_path, parcels = parcels_path,
      # Cache TWI jetable et PROPRE À LA CONFIGURATION : sinon une grille
      # calculée à 10 m serait resservie à 2 m et fausserait tout.
      twi_cache = file.path(scratch, paste0("twi_", tag)),
      tmpdir    = file.path(scratch, paste0("tmp_", tag)),
      result    = file.path(scratch, paste0("res_", tag, ".json"))
    )
    spec_path <- file.path(scratch, paste0("spec_", tag, ".json"))
    jsonlite::write_json(spec, spec_path, auto_unbox = TRUE)

    self <- normalizePath(sub("^--file=", "",
      grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1]))
    cmd_args <- c("--vanilla", self, "--child", spec_path)
    if (use_cgroup) {
      bin <- "systemd-run"
      cmd_args <- c("--user", "--scope", "--quiet",
                    "-p", paste0("MemoryMax=", cap), "-p", "MemorySwapMax=0",
                    "Rscript", cmd_args)
    } else {
      bin <- "Rscript"
    }

    message(sprintf("[%d/%d] %s …", i, nrow(grid), label))
    peak_spill <- 0
    timed_out <- FALSE
    started <- Sys.time()

    if (requireNamespace("processx", quietly = TRUE)) {
      p <- processx::process$new(bin, cmd_args, stdout = "|", stderr = "|")
      # Sonde du spill pendant que l'enfant tourne : terra efface ses
      # temporaires au fil de l'eau, un relevé après coup lirait zéro.
      while (p$is_alive()) {
        Sys.sleep(0.25)
        peak_spill <- max(peak_spill, .dir_size_mb(spec$tmpdir))
        if (difftime(Sys.time(), started, units = "secs") > tmo) {
          # `p$kill()` ne tue que systemd-run ; le vrai R vit dans le scope.
          # On demande à systemd d'arrêter le scope entier, sinon l'enfant
          # continue à tourner en fond après le banc.
          if (use_cgroup) .stop_scope(spec$result)
          p$kill()
          timed_out <- TRUE
          break
        }
      }
      # Après un kill, les tuyaux de l'enfant sont fermés : lire le stderr y
      # lève une erreur processx qui ferait tomber le banc entier.
      status <- tryCatch(p$get_exit_status(), error = function(e) NA_integer_)
      err <- tryCatch(paste(p$read_all_error(), collapse = ""),
                      error = function(e) "")
    } else {
      status <- system2(bin, cmd_args, stdout = FALSE, stderr = FALSE)
      peak_spill <- NA_real_
      err <- ""
    }
    wall <- as.numeric(difftime(Sys.time(), started, units = "secs"))

    ok <- file.exists(spec$result)
    r <- if (ok) jsonlite::fromJSON(spec$result) else NULL
    # Le cgroup a tué l'enfant : c'est un RÉSULTAT, pas un échec du banc.
    # Deux conventions selon qui rapporte : 137 = 128 + SIGKILL côté shell,
    # -9 = -SIGKILL côté processx. Mesuré : processx rend -9.
    st <- as.integer(status)
    killed <- !timed_out && length(st) == 1L && !is.na(st) &&
      (identical(st, 137L) || identical(st, -9L))

    rows[[i]] <- data.frame(
      res = grid$res[i], memmax = grid$memmax[i],
      grid_res_m = if (ok) r$grid_res_m else NA_real_,
      status = if (killed) "OOM (SIGKILL)"
               else if (timed_out) sprintf("timeout (>%gs)", tmo)
               else if (ok) "ok" else paste0("erreur (", status, ")"),
      peak_rss_gb = if (ok) round(r$peak_rss_gb, 2) else NA_real_,
      spill_mb = round(peak_spill),
      elapsed_s = if (ok) round(r$elapsed_s, 1) else round(wall, 1),
      stringsAsFactors = FALSE
    )
    rows[[i]]$scores <- I(list(if (ok) as.numeric(r$scores) else NA_real_))

    msg <- if (killed) "  -> OOM, tué par le cgroup (attendu sans garde-fou)"
           else if (timed_out) sprintf("  -> abandon après %g s (TWI recalculé sur la grille native ?)", tmo)
           else if (!ok) paste0("  -> échec (", status, ") ", substr(err, 1, 200))
           else sprintf("  -> pic %.2f Go | spill %s Mo | %.1f s",
                        r$peak_rss_gb, format(round(peak_spill)), r$elapsed_s)
    message(msg)
  }

  out <- do.call(rbind, rows)

  # Écart au score : référence = la configuration la plus fine ayant abouti.
  order_fine <- order(vapply(out$res, function(x)
    if (identical(x, "native")) 0 else as.numeric(x), numeric(1)))
  ref_i <- Filter(function(i) out$status[i] == "ok", order_fine)
  ref <- if (length(ref_i)) out$scores[[ref_i[1]]] else NULL
  out$ref <- if (length(ref_i)) sprintf("res=%s", out$res[ref_i[1]]) else NA_character_
  out$delta_mean_pt <- NA_real_
  out$delta_max_pt <- NA_real_
  if (!is.null(ref)) {
    for (i in seq_len(nrow(out))) {
      if (out$status[i] != "ok") next
      d <- abs(out$scores[[i]] - ref)
      out$delta_mean_pt[i] <- round(mean(d, na.rm = TRUE), 2)
      out$delta_max_pt[i]  <- round(max(d, na.rm = TRUE), 2)
    }
  }

  tbl <- out[, c("res", "memmax", "grid_res_m", "status", "peak_rss_gb",
                 "spill_mb", "elapsed_s", "delta_mean_pt", "delta_max_pt")]
  message("")
  print(tbl, row.names = FALSE)
  if (!is.null(ref)) message(sprintf("\nRéférence des écarts : %s", out$ref[1]))

  utils::write.csv(tbl, out_csv, row.names = FALSE)
  message(sprintf("CSV : %s", out_csv))
  invisible(tbl)
}

# ---- point d'entrée --------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 2L && args[[1]] == "--child") {
  run_child(args[[2]])
} else {
  run_bench(args)
}
