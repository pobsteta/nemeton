# Brief `nemetonshiny` — Feedback du bouton « Lancer le moteur réel » (reGénération, spec 027)

**Cœur requis** : aucun. **Correctif purement UI/app** (`mod_regeneration.R` +
2-3 clés i18n). Pas de bump cœur. `bslib (>= 0.6.0)` est déjà en `Imports`.

**Symptômes** (rapportés en usage réel) : au clic sur **« Lancer le moteur réel »**
(1) aucun message persistant en bas à droite de ce qui se passe, (2) le bouton
**reste cliquable** → on peut relancer le moteur en concurrence.

Le bouton **« Auto (E-OBS) »** (`auto_years`) a le **même** double défaut.

---

## 1. Causes (dans `R/mod_regeneration.R`)

### 1.1 Notif non persistante
Au clic (l. ~391 pour le moteur, l. ~223 pour E-OBS) :
```r
shiny::showNotification(i18n$t("regen_engine_running"), type = "message", duration = 6)
```
Le message dit lui-même « *…cela peut prendre plusieurs minutes* » mais
**disparaît au bout de 6 s**. Le run tourne ensuite dans un worker `future`
(`engine_task` / `eobs_task`), sans retour visible. Le seul indicateur est un
texte « sablier » **sous** le bouton (`output$engine_status`), pas la notif
bas-droite attendue.

### 1.2 Bouton re-cliquable
`run_engine` (l. ~106) et `auto_years` sont des `shiny::actionButton` **simples**.
Un `ExtendedTask` **ne désactive pas** un actionButton. Le handler
`observeEvent(input$run_engine, …)` n'a **aucun garde** (`rv$engine_running` ne
sert qu'à l'affichage) → un reclic ré-invoque `engine_task$invoke()` en parallèle.

> Un run concurrent réécrit `sensibilite.gpkg` / `biljou.gpkg` pendant qu'un autre
> les lit → résultats potentiellement corrompus. C'est le vrai risque, au-delà de
> l'UX.

---

## 2. Correctif A — bouton non re-cliquable + spinner intégré

Remplacer les deux `actionButton` async par **`bslib::input_task_button`**, qui
se **désactive automatiquement** pendant la tâche liée et affiche un spinner +
libellé « occupé », puis se réactive à la fin (succès **ou** erreur).

### 2.1 UI — moteur réel (l. ~106)
```r
bslib::tooltip(
  bslib::input_task_button(
    ns("run_engine"), i18n$t("regen_engine_run"),
    icon       = bsicons::bs_icon("cpu"),
    label_busy = i18n$t("regen_engine_running_short"),   # NOUVELLE clé courte
    class = "btn-outline-primary btn-sm w-100"),
  i18n$t("regen_engine_tip"), placement = "right")
```

### 2.2 UI — Auto E-OBS (bouton `auto_years`)
Idem : `bslib::input_task_button(ns("auto_years"), i18n$t("regen_auto"),
label_busy = i18n$t("regen_auto_running_short"), …)`.

### 2.3 Server — lier chaque bouton à sa tâche
Juste après la définition de `engine_task` / `eobs_task` :
```r
bslib::bind_task_button(engine_task, "run_engine")
bslib::bind_task_button(eobs_task,   "auto_years")
```
> `bind_task_button()` prend l'id **local au module** (sans `ns()`), il est déjà
> dans le `moduleServer`.

### 2.4 Réinitialiser sur les retours anticipés
`input_task_button` passe en état « busy » **dès le clic**. Sur les branches qui
`return()` **avant** `invoke()` (pas de projet, prérequis KO), remettre le bouton
prêt, sinon il reste grisé :
```r
shiny::observeEvent(input$run_engine, {
  units <- units_sf()
  project_path <- tryCatch(app_state$current_project$path, error = function(e) NULL)
  if (is.null(units) || is.null(project_path)) {
    bslib::update_task_button("run_engine", state = "ready")   # <-- reset
    shiny::showNotification(i18n$t("regen_need_project"), type = "warning")
    return()
  }
  pre <- regen_engine_prereqs(project_path, input$forcing %||% "safran")
  if (!isTRUE(pre$ok)) {
    bslib::update_task_button("run_engine", state = "ready")   # <-- reset
    shiny::showNotification(i18n$t(pre$reason), type = "warning", duration = 8)
    return()
  }
  ...
  engine_task$invoke(units, project_path, cfg, .dev_pkg_path, get_app_options())
})
```
Même traitement pour `auto_years` (branche « pas de projet »).

---

## 3. Correctif B — message persistant en bas à droite

Suivre le patron **déjà en place** dans `mod_synthesis.R` (l. 582, 641…) :
notif **persistante** (`duration = NULL`) posée à l'invoke avec un `id` stable,
**retirée** à la fin (succès **et** erreur).

### 3.1 À l'invoke (moteur)
```r
  rv$engine_running <- TRUE
  shiny::showNotification(
    i18n$t("regen_engine_running"),
    type = "message", duration = NULL, id = session$ns("engine_notif"))  # <-- persistante
  engine_task$invoke(units, project_path, cfg, .dev_pkg_path, get_app_options())
```

### 3.2 À la fin — dans `observeEvent(engine_task$status(), …)`
Retirer la notif dans **les deux** branches `success` et `error`, avant les toasts
finaux courts existants (`regen_engine_done` / erreur) :
```r
  shiny::removeNotification(session$ns("engine_notif"))
```

### 3.3 E-OBS — identique
`showNotification(i18n$t("regen_auto_running"), duration = NULL,
id = session$ns("eobs_notif"))` à l'invoke ; `removeNotification(session$ns("eobs_notif"))`
dans les branches `success`/`error` de `observeEvent(eobs_task$status())`.

> `output$engine_status` (texte sablier sous le bouton) peut **rester** : il est
> désormais redondant avec le spinner du bouton + la notif, mais inoffensif. Au
> choix, le simplifier plus tard.

---

## 4. i18n (`utils_i18n.R`, FR/EN) — libellés « busy » courts pour les boutons

| Clé | FR | EN |
|---|---|---|
| `regen_engine_running_short` | « Moteur en cours… » | "Engine running…" |
| `regen_auto_running_short` | « Détection E-OBS… » | "E-OBS detection…" |

(Les clés longues `regen_engine_running` / `regen_auto_running` restent pour la
notif persistante bas-droite — elles décrivent le contexte complet.)

---

## 5. Ce qu'on ne fait PAS (et pourquoi)

- **Pas de progression pas-à-pas** (barre 10 %/40 %…) : le moteur tourne dans un
  worker `future` **séparé** → il ne peut pas pousser d'étapes vers la session
  Shiny. Une progression granulaire exigerait un canal (fichier de progression
  écrit par le worker + poll réactif) — hors périmètre. La notif indéterminée
  « en cours… » + le spinner du bouton sont le bon niveau.
- **Pas de garde manuel `if (rv$engine_running) return()`** : devient inutile une
  fois le bouton lié via `bind_task_button` (il est désactivé pendant le run).
  On peut le laisser en ceinture-bretelles si on veut, sans effet visible.

---

## 6. Test app (smoke)

- Clic moteur avec projet + prérequis OK : le bouton passe **grisé + spinner**,
  une notif **persistante** « moteur en cours » reste affichée ; un 2ᵉ clic est
  **impossible** ; à la fin la notif disparaît et le toast `regen_engine_done`
  s'affiche.
- Clic sans projet / prérequis KO : notif d'avertissement + bouton **remis prêt**
  (pas grisé bloqué).
- Idem bouton « Auto (E-OBS) ».

---

## 7. Résumé des points de retouche

| Fichier | Retouche |
|---|---|
| `mod_regeneration.R` (UI) | `run_engine` + `auto_years` → `bslib::input_task_button(…, label_busy=)` |
| `mod_regeneration.R` (server) | `bind_task_button()` ×2 ; `update_task_button(…, "ready")` sur retours anticipés ; notif `duration=NULL`+`id` à l'invoke ; `removeNotification()` dans success/error ×2 |
| `utils_i18n.R` | 2 clés `*_running_short` FR/EN |
| DESCRIPTION | rien (bslib déjà présent) |
