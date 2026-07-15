# Brief `nemetonshiny` — Plafonner le moteur reGénération en mémoire (anti-OOM)

**Date** : 2026-07-15
**Repos** : prérequis côté `nemeton` (§1, cœur) + câblage côté `nemetonshiny`
(§2, app). Aucune édition app faite ici (règle #11).
**Fichiers app** : `R/mod_regeneration.R` (bloc `engine_task`), éventuellement
`R/service_regeneration.R`.
**Origine** : incident **2026-07-15**. Une analyse reGénération sur le projet
Reconfort a fait tuer RStudio par `systemd-oomd` (11 process du scope, pic
16,8 Go, 10:11). Le moteur microclimf+BILJOU avait pourtant fini à 09:56 (ses gpkg
ont survécu) : le crash est une opération postérieure morte en mémoire. Cause
racine : le moteur reGénération tourne dans un worker `future::multisession` **nu,
dans le scope de l'app** — pas d'isolation mémoire, contrairement à FORDEAD
(`run_memory_capped()`, v0.157.0). Voir mémoire `project_reconfort_oom_isolation`.

## 0. Pourquoi `run_memory_capped()` ne s'applique pas directement

`nemeton::run_memory_capped(fun, …)` lance dans son enfant :

```r
suppressMessages(loadNamespace("nemeton"))
f <- getExportedValue("nemeton", a$fun)
```

→ il ne sait exécuter qu'une fonction **exportée de `nemeton`**. Le worker du
moteur reGénération est `nemetonshiny:::run_regeneration_engine(units,
project_path, cfg)` — **interne à l'app**. FORDEAD, lui, capait
`nemeton::run_fordead_dieback` (un export cœur), d'où la différence.

Deux faits qui simplifient la suite :

* **Le progress traverse déjà les process.** `run_regeneration_engine()` écrit ses
  phases dans `cache/regeneration/engine_status.json` et `engine.log`
  (`.regen_write_phase()` / `.regen_log()`), et l'app les **poll déjà à 1 s**
  (`mod_regeneration.R`, observe de poll). Peu importe quel process écrit : le
  disque est le canal. → **pas besoin** de `progress_callback` ni de `progress_path`.
* **Les args sont sérialisables.** `units` (sf), `project_path` (chr), `cfg`
  (liste de scalaires). Aucun `SpatRaster` n'est passé en entrée — l'engine
  construit ses rasters depuis les fichiers de `project_path`. → compatible avec
  la contrainte RDS de `run_memory_capped()`.

## 1. Prérequis côté cœur `nemeton` (petit, à faire par Pascal/Claude en session nemeton)

Généraliser `run_memory_capped()` pour qu'il puisse lancer une fonction d'un
**autre package** et injecter des options dans l'enfant. C'est le bon endroit :
la logique fragile (systemd-run, `MemorySwapMax=0`, fallback sans cgroup) reste
**centralisée et testée** dans le cœur — la dupliquer dans l'app ré-introduirait
le piège swap déjà résolu.

Changements dans `R/isolate.R` :

1. **Nouvel argument `package = "nemeton"`.** L'enfant charge ce package et y
   résout la fonction. Utiliser `get(a$fun, envir = asNamespace(a$package))`
   (et non `getExportedValue`) pour atteindre aussi les fonctions **internes**
   (`run_regeneration_engine` n'est pas exporté) :
   ```r
   suppressMessages(loadNamespace(a$package))
   f <- get(a$fun, envir = asNamespace(a$package))
   ```
2. **Nouvel argument `options = NULL`** (liste nommée), posée dans l'enfant avant
   l'appel — le worker lit `get_app_options()` ⇐ `options(nemeton.app_options)` :
   ```r
   if (length(a$options)) do.call(base::options, a$options)
   ```
   Sérialiser `options` dans le `saveRDS(list(...))` existant.
3. Doc @param + un test : `run_memory_capped("<fn interne d'un pkg de test>",
   package = "…", options = list(foo = 1))`.

Signature cible :
```r
run_memory_capped(fun, args = list(), package = "nemeton", db_url = NULL,
                  options = NULL, progress_path = NULL,
                  progress_callback = NULL, memory_max = NULL,
                  poll_ms = 500L, quiet = FALSE)
```

Rétrocompatible (defaults inchangés → FORDEAD continue de marcher tel quel).
Release patch cœur dédiée (ex. 0.158.0, `feat` mineur).

### Caveat dev à documenter

L'enfant charge le package **installé** (`.libPaths()` snapshoté), pas la source
`pkgload::load_all()`. En dev, la version capée du moteur = la `nemetonshiny`
installée dans la lib, potentiellement en retard sur le WIP. C'est déjà le cas de
FORDEAD ; le signaler, sans bloquer (l'app dev reste sur le chemin multisession
nu tant que la lib n'est pas à jour, cf. §2 flag).

## 2. Câblage côté `nemetonshiny`

Dans `R/mod_regeneration.R`, le bloc `engine_task` (≈ ligne 739) exécute
aujourd'hui, dans le `future_promise` :

```r
options(nemeton.app_options = app_opts)
fn <- getFromNamespace("run_regeneration_engine", "nemetonshiny")
fn(units, project_path, cfg)
```

Le remplacer par un appel capé. **Garder l'`ExtendedTask` + `future_promise`
multisession** (l'async UI ne change pas) : le worker multisession devient un
simple superviseur léger qui bloque sur l'enfant capé (peu de RAM), pendant que
la session principale reste réactive via la promesse. Le heavy est dans l'enfant
sous cgroup.

```r
promises::future_promise({
  on.exit(nemetonshiny:::.release_worker_memory(), add = TRUE)
  if (!is.null(dev_path) && requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(dev_path, quiet = TRUE)
  } else {
    loadNamespace("nemetonshiny")
  }
  nemeton::run_memory_capped(
    fun     = "run_regeneration_engine",
    package = "nemetonshiny",
    args    = list(units = units, project_path = project_path, cfg = cfg),
    options = list(nemeton.app_options = app_opts),
    # memory_max = NULL → défaut cœur (70 % RAM) ; MemorySwapMax=0 déjà géré
    # par .reconfort_cap_memory(). Passer p.ex. "24G" pour un plafond fixe.
    quiet   = FALSE)
}, seed = TRUE)
```

Points d'attention :

* **Progress inchangé.** L'enfant écrit `engine_status.json`/`engine.log` dans
  `project_path/cache/regeneration/` ; le poll 1 s existant les lit. Rien à
  toucher côté notif bas-droite ni `output$engine_status`.
* **Valeur de retour.** `run_regeneration_engine()` renvoie sa liste
  (`canopy`, `lai_source`, `ewm`, `warnings`, …) ; `run_memory_capped()` la
  relaie via `result.rds`. Le handler `engine_task$status() == "success"`
  (≈ ligne 1097) la consomme comme avant. **Vérifier la sérialisabilité** de ce
  retour (pas de SpatRaster/connexion dedans — a priori que des scalaires/chr).
* **Fallback sans `systemd-run`** (poste sans bus user, CI) : `run_memory_capped`
  tourne l'enfant **non capé** avec un `cli_warn`. Comportement dégradé acceptable
  (au pire, on retombe sur le risque actuel). Ne pas transformer ça en erreur.
* **Flag de désactivation** (optionnel, prudence) : un
  `getOption("nemetonshiny.regen_capped", TRUE)` qui, à `FALSE`, reprend le chemin
  multisession nu — utile en dev quand la lib installée est en retard (cf. caveat
  §1).

## 3. Parade host immédiate (déjà donnée à Pascal, sans code)

En attendant la livraison, lancer l'app dans son propre scope plafonné pour
protéger RStudio :

```bash
systemd-run --user --scope -p MemoryMax=24G -p MemorySwapMax=0 \
  Rscript -e 'nemetonshiny::run_app(language = "fr")'
```

`oomd` tue alors le scope de l'app, pas RStudio. `MemorySwapMax=0` **impératif** :
avec du swap, le cgroup thrashe et ce thrashing est justement la pression que oomd
surveille (leçon mesurée 2026-07-14).

## 4. Test

* Cœur : test unitaire de `run_memory_capped(package=, options=)` sur une fonction
  interne d'un package tiers léger.
* App : `testServer()` — invoquer `engine_task`, mocker `run_memory_capped` pour
  vérifier qu'il est appelé avec `package="nemetonshiny"`, `fun=
  "run_regeneration_engine"`, et que le retour est relayé au handler success.
* Manuel : rejouer l'analyse Reconfort sous plafond bas (`memory_max="2G"`) →
  l'enfant doit être tué **seul** (SIGKILL / 137), RStudio et l'app survivent, un
  toast d'erreur remonte au lieu du crash de session.
