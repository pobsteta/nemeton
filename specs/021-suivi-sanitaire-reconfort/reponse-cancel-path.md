# Réponse au brief `nemetonshiny` du 2026-09-14 — `run_reconfort_dieback(cancel_path=)`

> Brief d'origine : `briefs/vers-nemeton/2026-09-14-reconfort-cancel-path.md`.
> **Livré dans `nemeton` v0.196.0** — c'est le numéro à mettre au plancher
> `Imports:`.

## 1. Ce qui est livré

`run_reconfort_dieback()` accepte `cancel_path`, dernier paramètre de la
signature, après `progress_callback`. Le contrat est celui de `R/cancel.R`,
partagé avec FAST et FORDEAD — les trois pages d'aide se lisent désormais
pareil.

| Pipeline | Paramètre | Checker |
|---|---|---|
| FAST | `cancel_path = NULL` | `.make_cancel_checker()` |
| FORDEAD | `cancel_path = NULL` | `.make_cancel_checker()` + `.signal_cancel_fordead()` |
| **RECONFORT** | **`cancel_path = NULL`** | `.make_cancel_checker()` + `.signal_cancel_reconfort()` |

## 2. Où la scrutation a lieu, et ce que ça coûte

Comme demandé au §2.3 : **frontière de phase uniquement**, dans le crochet
`begin()`. Le check se fait à l'*entrée* de la phase suivante, donc la phase en
cours va toujours à son terme.

Conséquence à garder en tête côté app pour le libellé du bouton et le toast :
une phase `mapprod` (IOTA2) dure des dizaines de minutes, et l'arrêt ne prendra
effet qu'après. C'est écrit dans le `@param`, mais l'utilisateur lit le toast,
pas la page d'aide. Un « arrêt demandé — prendra effet à la fin de l'étape en
cours » serait plus juste qu'un « arrêté » immédiat.

Les dix phases, dans l'ordre : `env`, `model`, `mask`, `tiles`, `ingest`,
`stage`, `mapprod`, `collect`, `postprocess`, `persist`.

## 3. Contrat de sortie

À l'observation du flag :

* **événement** `reconfort:cancelled`, avec `zone_id`, `phase_name` (la
  dernière phase **terminée**), `completed` (nombre de phases allées au bout),
  `total` (10) et `elapsed_sec` ;
* **résultat** `status = "cancelled"`, champ `phase` (même valeur que
  `phase_name`), `message`, et la forme habituelle du résultat avec `NULL` /
  `NA` là où les phases déclinées auraient produit quelque chose
  (`rasters`, `alerts_sf`, `n_alerts`, `features_bundle`, `meta`).

Attention : le succès reste `status = "completed"` (pas `"success"` — c'est
l'usage historique de RECONFORT, inchangé), et un **échec** continue d'aborter
au lieu de renvoyer un statut. Trois sorties possibles, donc : `completed`,
`cancelled`, ou une condition d'erreur.

## 4. Ce qui survit à un arrêt

`keep_workdir = FALSE` **ne s'applique plus** à un run annulé : le répertoire de
travail est conservé. Les scènes déjà ingérées et ce qu'IOTA2 a déjà écrit
restent relisibles par un re-run `skip_ingest = TRUE`. C'était le §2.4 troisième
point — sans ça, annuler coûterait exactement autant qu'échouer.

## 5. Les quatre garanties du §3, testées

`tests/testthat/test-reconfort-pipeline.R`, cinq cas en miroir de
`test-ingest-cancel.R` :

1. `cancel_path = NULL` → **zéro** appel au système de fichiers (le spy sur
   `.cancel_flag_exists()` compte 0) ;
2. flag posé **avant** l'appel → `cli_warn` « already present at entry », le run
   va au bout ;
3. flag posé **pendant** (phase `mask`) → `status = "cancelled"`, `phase ==
   "mask"`, `tiles` et la suite jamais démarrées, IOTA2 jamais invoqué,
   `reconfort:cancelled` émis avec `completed == 3` ;
4. chemin malformé → lu comme « pas d'annulation », jamais une erreur ;
5. (en plus) `keep_workdir = FALSE` + annulation → le workdir et les scènes
   ingérées sont toujours là.

## 6. Côté app

Rien à concevoir, le brief l'avait déjà cadré :

* `Imports: nemeton (>= 0.196.0)` ;
* `.reset_reconfort_run()` écrit `reconfort_cancel.flag` via
  `.resolve_progress_path()` — et **supprime le flag avant chaque `invoke()`**,
  sinon le garde-fou anti-« phantom cancel » désarmera le run suivant ;
* `.invoke_reconfort()` passe `cancel_path = .reconfort_cancel_flag` ;
* le commentaire de `.reset_reconfort_run()` qui documentait l'asymétrie tombe ;
* penser au toast : l'arrêt est *coarse* (cf. §2).

---

## 7. Le toast d'arrêt — ce qu'il dit, et le piège en amont

> Ajouté après lecture (**seule**) de `nemetonshiny/R/mod_monitoring.R` et
> `R/utils_i18n.R` : les anchors et les clés ci-dessous sont ceux du code réel,
> pas une proposition en l'air. Rien n'a été édité dans `nemetonshiny`.

### 7.1 Le piège : le run annulé passe aujourd'hui pour un succès

C'est le point le plus important de cette section, et il ne concerne pas le
wording. Le *result handler* RECONFORT (`mod_monitoring.R:3726-3737`) fait :

```r
if (!is.null(result)) {
  ...
  shiny::showNotification(
    sprintf(i18n$t("monitoring_reconfort_success"),
            result$n_alerts %||% result$n_alerts_inserted %||% 0L,
            format_elapsed(result$duration_sec %||% 0)),
    id = session$ns("reconfort_success"), type = "message", duration = 8)
  reconfort_refresh(reconfort_refresh() + 1L)
  ...
}
```

Aucun test sur `result$status`. Aujourd'hui c'est sans conséquence : le cœur ne
renvoyait jamais autre chose que `"completed"` (un échec abortait). **Dès que
`cancel_path` sera branché, un run annulé entrera dans cette branche** et
affichera le toast de succès — avec `n_alerts = NA_integer_` (donc un
`sprintf` sur `NA`) et un `$rasters` à `NULL` passé au sous-module carte.

Le correctif est une branche avant l'actuelle :

```r
if (identical(result$status, "cancelled")) {
  shiny::showNotification(
    i18n$t("monitoring_reconfort_cancelled",
           label = .reconfort_phase_label(result$phase %||% "", i18n)),
    id = session$ns("reconfort_cancelled"), type = "warning", duration = 8)
  # Pas de reconfort_refresh() ni de passe-plat carte : il n'y a pas de
  # nouveau raster. Le cache du run precedent reste affichable.
} else { ... branche actuelle ... }
```

`.reconfort_phase_label()` (`mod_monitoring.R:4333`) sait déjà localiser un nom
de phase via `monitoring_reconfort_phase_<name>` — `result$phase` porte
exactement l'une des dix valeurs qu'il attend.

### 7.2 Aparté, tant qu'on est dans cette ligne : `duration_sec` n'existe pas

Le toast de succès lit `result$duration_sec %||% 0`. Le cœur renvoie
`elapsed_sec` (c'est le nom historique de RECONFORT, FORDEAD étant celui qui
dit `duration_sec`). Le chrono du toast de succès affiche donc `0` depuis
toujours. Un `result$elapsed_sec %||% result$duration_sec %||% 0` règle ça.
Hors périmètre de ce brief — signalé parce que la ligne est celle qu'on
touche.

### 7.3 Le bouton : un mot, là où il n'y en a aucun

`observeEvent(input$run_reconfort_cancel, ...)` (`mod_monitoring.R:3594`)
appelle `.reset_reconfort_run()` et **n'affiche rien** — contrairement à FAST
(`:2270`) et FORDEAD (`:2862`), qui posent tous deux
`monitoring_run_cancel_done`. Une fois le flag écrit, il y a quelque chose à
dire, et le silence serait pire qu'avant : l'UI se déverrouille instantanément
alors que le worker travaille encore une phase entière.

Clé neuve — `monitoring_run_cancel_done` ne convient pas telle quelle, elle
nomme « la tuile (FAST) / la phase (FORDEAD) » et parle d'`ON CONFLICT DO
NOTHING`, qui n'a rien à voir ici :

```r
  monitoring_reconfort_run_cancel_requested = list(
    fr = "Arrêt demandé. RECONFORT termine l'étape en cours puis s'arrête — IOTA2 découpe côté Python, il n'y a pas de point d'arrêt plus fin, et une classification peut demander plusieurs dizaines de minutes. Ce qui a déjà été produit (scènes ingérées, sorties IOTA2) est conservé et relu par une relance.",
    en = "Stop requested. RECONFORT finishes the current step then exits — IOTA2 chunks on the Python side, there is no finer checkpoint, and a classification can take tens of minutes. Whatever was already produced (ingested scenes, IOTA2 outputs) is kept and re-read on a relaunch."
  ),
  monitoring_reconfort_cancelled = list(
    fr = "RECONFORT arrêté après l'étape « {label} ». Les sorties de cette étape et des précédentes sont conservées.",
    en = "RECONFORT stopped after the “{label}” step. That step's outputs and the earlier ones are kept."
  ),
```

Deux clés, deux moments distincts, et c'est le fond de la remarque : *arrêt
demandé* au clic (le worker tourne encore), *arrêté* à l'arrivée de
`reconfort:cancelled` ou du résultat. Confondre les deux, c'est reproduire en
plus discret le bouton menteur que ce brief corrigeait.

**Variante recommandée** si vous voulez nommer l'étape dès le clic : le module
n'a pas de `reactiveVal` portant la phase courante (seul `reconfort_run_msg()`
garde le message formaté). Il en faudrait un, alimenté dans
`.reconfort_handle_progress_event()` à la branche `reconfort:phase`. C'est
propre mais ce n'est plus une ligne — d'où la formulation sans label ci-dessus,
qui reste honnête sans nouvel état.

### 7.4 `reconfort:cancelled` dans le dispatcher

`.reconfort_handle_progress_event()` (`mod_monitoring.R:4345`) traite
`start|phase|ingest_listed|ingest_item|complete|error`. L'événement neuf tombe
donc dans le `else` final. Une branche symétrique de `reconfort:complete` :
retirer `reconfort_progress`, poser `monitoring_reconfort_cancelled` avec
`.reconfort_phase_label(ev$phase_name, i18n)`, et rendre la main. `ev` porte
`zone_id`, `phase_name`, `completed`, `total`, `elapsed_sec`.

Note d'ordonnancement : sur un arrêt, cet événement et le résultat
(`status = "cancelled"`) disent la même chose. `reconfort_result_consumed()`
protège déjà le second contre la double-consommation ; il suffit que les deux
toasts partagent le même `id` de notification pour que l'un remplace l'autre au
lieu de s'empiler.
