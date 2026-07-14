# Brief `nemetonshiny` — un job lourd ne doit plus emporter la session (OOM, spec 008)

**Cœur requis** : `nemeton (>= 0.155.0)` — la partie « plafond mémoire » est
livrée **côté cœur** (cf. §2), pas ici.
**Objectif** : qu'un dépassement mémoire d'un diagnostic (RECONFORT, FORDEAD)
tue **le job seul**, avec une erreur lisible dans l'UI — au lieu d'emporter
RStudio, l'application et les terminaux. Portée côté app :
présentation/câblage seulement (règles #1/#3).

---

## 1. L'incident (2026-07-13)

Un diagnostic RECONFORT lancé depuis l'app a fait tuer **toute la session** par
`systemd-oomd` :

```
14:24:47  Killed app-gnome-org.gnome.Software.scope       (1 process)
14:25:03  Killed app-ghostty-surface-transient.scope      (8 process)   ← terminaux
14:25:36  Killed app-gnome-rstudio.scope                  (22 process)  ← RStudio + l'app
          reason: memory pressure for user@1000.service being 78% > 50% for > 20s
```

Le scope RStudio pesait **26,2 Go** sur une machine de 31 Go. Décomposition :

| | |
|---|---|
| le job IOTA2 lui-même | > 20 Go (bug iota2 #11, **corrigé** en v0.154.1 → 11,3 Go) |
| l'app + le worker `future` + les rasters du projet en mémoire | ~14 Go |

Le bug du cœur est réglé, mais **la structure du problème demeure** : sur une
UGF plus grande ou un autre modèle, un job qui déborde tuera de nouveau *tout*,
parce que rien n'isole le job de l'app.

## 2. Ce que fait le cœur (rien à câbler ici)

`nemeton` lance le sous-processus IOTA2/Python (`system2("conda run …")`,
`R/reconfort_ingest.R`). C'est **là** que le plafond mémoire est posé : le
sous-processus tourne dans un cgroup transitoire plafonné
(`systemd-run --user --scope -p MemoryMax=…`). Conséquence pour l'app :

* un dépassement tue **le sous-processus Python seul** ;
* `run_reconfort_dieback()` remonte alors une erreur R normale
  (`RECONFORT map production failed for zone <id> (exit <n>)`), comme n'importe
  quel autre échec de production ;
* l'app, le worker `future` et la session **survivent**.

Autrement dit : côté app, un OOM du job devient **un échec de tâche ordinaire**.
Il n'y a plus de cas « la session disparaît ». Reste à le *présenter* correctement
et à ne pas ajouter soi-même à la pression mémoire — c'est l'objet des §3 et §4.

## 3. À faire — présenter l'échec mémoire pour ce qu'il est

Aujourd'hui, l'erreur remontée par `run_reconfort_async()` / `run_fordead_async()`
est affichée telle quelle. Un OOM produira un message d'exit code peu parlant
(« exit 137 » / « killed »). Proposition : détecter ce cas dans le handler
d'erreur existant et afficher un message dédié plutôt que le brut.

Le signal : le job est tué par SIGKILL → code de sortie **137** (128 + 9), ou le
message contient `killed`/`Killed`. Dans le `error = function(e)` qui entoure
déjà l'appel au cœur (cf. `service_monitoring.R`, `run_reconfort_async()`) :

```r
msg <- conditionMessage(e)
is_oom <- grepl("exit 137|killed", msg, ignore.case = TRUE)
shiny::showNotification(
  if (is_oom) i18n$t("monitoring_error_oom") else msg,
  type = "error", duration = NULL
)
```

Deux clés i18n à ajouter dans `TRANSLATIONS` (`R/utils_i18n.R`) :

| clé | FR | EN |
|---|---|---|
| `monitoring_error_oom` | « Le calcul a dépassé la mémoire disponible et a été arrêté. Fermez les autres applications, ou réduisez l'emprise de la zone, puis relancez. » | "The computation ran out of memory and was stopped. Close other applications, or reduce the zone extent, then run again." |
| `monitoring_error_oom_short` | « Mémoire insuffisante » | "Out of memory" |

Le même traitement vaut pour FORDEAD (`run_fordead_async()`) : le chemin d'erreur
est identique.

## 4. À faire — ne pas ajouter à la pression mémoire

Les ~14 Go tenus par l'app pendant le run sont ce qui a fait basculer le système
au-delà du seuil d'`oomd` (50 % de pression sur la session). Le job, lui, tient
désormais dans ~11 Go — ce qui **passe largement** sur 31 Go… à condition que
l'app ne tienne pas 14 Go à côté.

Piste à instruire côté app (hors périmètre de ce brief, à chiffrer) : les rasters
du projet (`twi.tif` 437 Mo, `lidar_mnt_mosaic.tif` 362 Mo, `lidar_mnh_mosaic.tif`
275 Mo…) semblent chargés/retenus en mémoire dans la session. `terra` sait
travailler par référence sur le fichier ; vérifier qu'on ne matérialise pas les
valeurs (`terra::values()`, `as.data.frame()`) et qu'on ne conserve pas de
`SpatRaster` matérialisés dans `app_state` au-delà du besoin d'affichage.

**Mesure de contrôle** — le pic réel d'un scope se lit ainsi :

```bash
systemd-run --user --scope -p MemoryMax=20G -p MemoryAccounting=yes Rscript job.R
systemctl --user show <unit>.scope -p MemoryCurrent   # échantillonner pendant le run
```

⚠️ Piège de méthode : **un run tué en cours de route donne un pic tronqué**. Ne
pas lire la dernière valeur observée comme un maximum — c'est l'erreur qui m'a
fait conclure deux fois l'inverse de la réalité pendant le diagnostic du
2026-07-13.

## 5. À faire — durées : heures d'abord, minutes ensuite (audit 2026-07-14)

Quatre messages injectent `duration_sec` **en secondes brutes**. Le run RECONFORT
validé (819 s) s'affiche « terminé en **819 s** » au lieu de « **13 min 39 s** » ;
un FORDEAD de deux heures dirait « **7243 s** ».

| clé i18n (`utils_i18n.R`) | texte actuel | appelée depuis |
|---|---|---|
| `monitoring_health_success_done` | « Diagnostic FORDEAD terminé en **%.0f s**. » | `mod_monitoring.R:2901` |
| `monitoring_reconfort_success` | « …%d alertes insérées en **%.0f s**. » | `mod_monitoring.R:3353` |
| `monitoring_fordead_complete` | « FORDEAD terminé · {n} alertes · **{sec}s** » | `mod_monitoring.R:3841` |
| `monitoring_reconfort_complete` | « RECONFORT terminé · {n} alertes · **{sec}s** » | `mod_monitoring.R:3988` |

Les deux formateurs existants sont **corrects** (`format_elapsed()` →
`1 h 02 min 05 s` ; `.format_duration_human()` → `1 h 02 min`) — ces quatre
messages ne passent simplement par **aucun** des deux.

Le cœur expose désormais **`nemeton::format_duration(sec, with_seconds = TRUE)`**
(v0.155.0), qui couvre les deux granularités. Proposition : les quatre appels
formatent la durée **avant** de la passer à `i18n$t()`, et le `%.0f s` / `{sec}s`
devient un `%s` / `{duree}` :

```r
# mod_monitoring.R — les 4 sites
sprintf(i18n$t("monitoring_reconfort_success"),
        result$n_alerts %||% 0L,
        nemeton::format_duration(result$duration_sec %||% NA_real_))
```

```r
# utils_i18n.R
monitoring_reconfort_success = list(
  fr = "Diagnostic RECONFORT terminé : %d alertes insérées en %s.",
  en = "RECONFORT diagnosis completed: %d alerts inserted in %s."
),
monitoring_reconfort_complete = list(
  fr = "RECONFORT terminé · {n} alertes · {duree}",
  en = "RECONFORT complete · {n} alerts · {duree}"
),
```

**Consolidation (optionnelle, recommandée)** : `format_elapsed()` et
`.format_duration_human()` peuvent être remplacés par des appels à
`nemeton::format_duration()` (`with_seconds = FALSE` pour la seconde) — une seule
source de vérité, conforme à la règle #2 (l'app consomme, le cœur décide).

⚠️ Les **champs de données** (`duration_sec`, `elapsed_sec`, `run_meta.json`,
colonne `rag_col_duration_sec`) restent en **secondes brutes** : ce sont des
données lisibles par machine, pas des messages. Ne pas les formater.

## 6. Hors périmètre

* Le plafond mémoire lui-même → **cœur** (§2).
* Le bug iota2 #11 (chunk 0 falsy, masque non découpé) → **corrigé** en v0.154.1,
  patché par `repair_iota2_env.sh`. Si l'env conda est reconstruit, ce script doit
  être rejoué, sinon le cœur retombe sur un bloc unique **avec un avertissement**
  (pic > 20 Go).
