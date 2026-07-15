# Brief `nemetonshiny` — Onglet reGénération : verrou des calculs + infobulle Forçage + persistance R7

**Date** : 2026-07-14 (§1-6), mis à jour 2026-07-15 (§7 infobulle Forçage, §8 persistance R7)
**Repo cible** : `nemetonshiny` (aucun changement côté cœur `nemeton`)
**Fichier** : `R/mod_regeneration.R`
**Origine** : session de test du moteur reGénération. Pendant que `engine_task`
tournait encore (microclimf + BILJOU, ~4 min), le bouton « Lancer R7 » est resté
cliquable. Le clic n'a rien produit de visible, ce qui a fait croire à un blocage
de l'app alors que le moteur travaillait normalement. Trois demandes en sont
sorties : le **verrou d'exclusion mutuelle** (§1-6), une **infobulle expliquant
SAFRAN vs ERA5-Land** sur le radio Forçage (§7), et la **persistance de la couche
gel R7** à travers un recalcul (§8).

## 1. Problème

Chaque `input_task_button` est lié à SA tâche via `bslib::bind_task_button()`
(lignes 825-828). bslib grise donc le bouton **propriétaire** de la tâche en
cours — et lui seul. Aucun bouton ne connaît l'état des autres tâches.

Rien n'empêche donc de lancer un second calcul lourd pendant qu'un premier
tourne : deux workers `future` concurrents sur les mêmes rasters, la même RAM et
le même `cache/regeneration/`. Deux risques concrets :

* **Confusion utilisateur** (le cas observé) : un clic sur un autre bouton semble
  ne « rien faire », l'app paraît gelée.
* **Corruption de cache** : `engine_task` et `frost_task` écrivent tous deux sous
  `cache/regeneration/`. `.regen_write_phase()` **écrase** `engine_status.json` à
  chaque phase ; deux tâches concurrentes produiraient un statut incohérent, et le
  poll afficherait la phase de l'une pendant que l'autre travaille.

## 2. Inventaire (état actuel)

5 `ExtendedTask` :

| Tâche | Déclencheur | Type | Ligne |
|---|---|---|---|
| `engine_task` | `run_engine` | `input_task_button` | 702 / 1037 |
| `eobs_task` | `auto_years` | `input_task_button` | 726 / 564 |
| `eobs_rr_task` | `fetch_eobs_rr` | `input_task_button` | 750 / 830 |
| `frost_task` | `run_frost` | `input_task_button` | 774 / 888 |
| `context_task` | *(aucun — auto sur vue/buffer)* | — | 799 / 991 |

3 `actionButton` classiques : `run` (622), `recompute_pai` (1026),
`persist_db` (1578).

## 3. Contrainte technique (vérifiée, ne pas la contourner)

Le binding JS du task button bslib 0.11.0 (`components.min.js`, type
`bslib.taskbutton`) n'implémente qu'un seul message :

```js
receiveMessage(el, {state}) { el.disabled = (state === "busy"); /* + bascule du label */ }
```

Il **ignore** la clé `disabled`. Donc :

* `shiny::updateActionButton(disabled = TRUE)` → **sans effet** sur les 4
  `input_task_button`. Ne pas l'utiliser sur eux.
* `shiny::updateActionButton(disabled = TRUE)` → **fonctionne** sur les 3
  `actionButton` classiques (binding standard Shiny, `disabled` supporté depuis
  Shiny 1.8 ; l'app tourne sur 1.14).
* Seul levier serveur pour un task button : `bslib::update_task_button(id, state
  = "busy" | "ready")` — qui grise **et** affiche le `label_busy` du bouton.

`shinyjs` n'est pas une dépendance de l'app : ne pas en ajouter une pour ça.

## 4. Implémentation proposée

### 4.1 Libellés `label_busy` neutres (prérequis)

Puisque griser un task button force l'affichage de SON `label_busy`, un bouton
grisé « par ricochet » afficherait un libellé mensonger (`run_frost` dirait
« Calcul gel en cours… » alors que c'est le moteur qui tourne).

→ Passer les `label_busy` des 4 task buttons à une clé i18n **générique** :

```r
# utils_i18n.R
regen_busy_generic = list(fr = "Calcul en cours…", en = "Computing…")
```

L'état devient vrai quel que soit le calcul actif. La phase précise reste
affichée là où elle est déjà : la notification persistante bas-droite (poll 1 s
de `engine_status.json`) et `output$engine_status`.

### 4.2 Réactif `busy()`

```r
# TRUE dès qu'une tâche utilisateur tourne. `context_task` est EXCLU : il est
# auto-déclenché par un changement de vue/buffer et griserait la sidebar de
# façon erratique, sans que l'utilisateur ait rien lancé.
busy <- shiny::reactive({
  any(vapply(
    list(engine_task, eobs_task, eobs_rr_task, frost_task),
    function(t) identical(t$status(), "running"),
    logical(1)))
})
```

### 4.3 Observer de verrouillage

```r
TASK_BTNS   <- c("run_engine", "auto_years", "fetch_eobs_rr", "run_frost")
ACTION_BTNS <- c("run", "recompute_pai", "persist_db")

shiny::observe({
  locked <- isTRUE(busy())
  for (id in TASK_BTNS) {
    bslib::update_task_button(id, state = if (locked) "busy" else "ready")
  }
  for (id in ACTION_BTNS) {
    shiny::updateActionButton(session, id, disabled = locked)
  }
})
```

Attention : cet observer **écrase** les `update_task_button(state = "ready")`
manuels des chemins de sortie précoce (1039, 1045, 1052, 890, 896, 901, 832,
838). Ils deviennent redondants mais restent inoffensifs — les laisser, ou les
supprimer, mais **surtout ne pas** les laisser en conflit d'ordre : l'observer
réagit à `status()`, qui repasse à `"success"`/`"error"` de toute façon.

### 4.4 Garde serveur (la partie qui compte vraiment)

Le grisage client est cosmétique et *contournable* (double-clic rapide, race sur
le websocket, page rechargée avec un état périmé). La correction robuste est
côté serveur, en tête de **chaque** `observeEvent` de déclencheur :

```r
if (isTRUE(busy())) {
  shiny::showNotification(i18n$t("regen_busy_already"), type = "warning", duration = 5)
  return()
}
```

Clé i18n à ajouter :

```r
regen_busy_already = list(
  fr = "Un calcul est déjà en cours — attendez qu'il se termine.",
  en = "A computation is already running — wait for it to finish.")
```

À placer dans : `input$run_engine` (1037), `input$run_frost` (888),
`input$auto_years` (564), `input$fetch_eobs_rr` (830), `input$run` (622),
`input$recompute_pai` (1026). Pas sur `persist_db` (écriture DB, pas un calcul —
à confirmer, mais elle lit `rv$result` qu'un run en cours pourrait remplacer sous
ses pieds : la griser par cohérence est plus sûr).

## 5. Décision laissée à Pascal

* **`context_task` dans le verrou ?** Recommandation : **non** (cf. 4.2), il n'est
  pas déclenché par l'utilisateur. Mais il consomme le réseau et le CPU comme les
  autres — s'il s'avère gênant en concurrence du moteur, l'ajouter à `busy()`.
* **Portée du verrou** : ce brief se limite à l'onglet reGénération. Si d'autres
  onglets lancent des tâches lourdes (monitoring), un verrou global porté par
  `app_state$busy` serait le prolongement naturel.

## 6. Test

`testServer()` sur `mod_regeneration_server` :

1. Invoquer `engine_task` (mock d'un future lent).
2. Vérifier que `busy()` est `TRUE`.
3. Simuler `session$setInputs(run_frost = 1)` → `frost_task$status()` doit rester
   `"initial"` (la tâche n'a pas démarré) et une notification d'avertissement doit
   avoir été émise.

---

## 7. Infobulle « i » sur le radio Forçage (SAFRAN vs ERA5-Land)

**Demande Pascal 2026-07-15.** Le radio Forçage laisse l'utilisateur choisir la
source météo du bilan hydrique BILJOU sans expliquer ce que le choix change. Or
la différence de précision est réelle et non évidente. Ajouter une infobulle « i »
qui la résume.

### 7.1 Point d'ancrage

`R/mod_regeneration.R:274` — aujourd'hui :

```r
shiny::radioButtons(ns("forcing"), i18n$t("regen_forcing"),
  choices = stats::setNames(c("safran", "era5"),
    c(i18n$t("regen_forcing_safran"), i18n$t("regen_forcing_era5"))),
  selected = "safran", inline = TRUE),
```

Le radio Forçage est le **seul** de la sidebar dont le label ne passe pas par le
helper `label_tt()` (déjà défini ligne 139 : icône `bsicons::bs_icon("info-circle")`
+ `bslib::tooltip`, placement `"right"`). Il suffit de l'y faire passer — idiome
maison, aucune dépendance ni composant nouveau.

### 7.2 Changement

```r
shiny::radioButtons(ns("forcing"),
  label_tt(i18n$t("regen_forcing"), i18n$t("regen_forcing_tip")),
  choices = stats::setNames(c("safran", "era5"),
    c(i18n$t("regen_forcing_safran"), i18n$t("regen_forcing_era5"))),
  selected = "safran", inline = TRUE),
```

### 7.3 Clé i18n à ajouter (`R/utils_i18n.R`)

Contenu vérifié contre l'implémentation cœur (`nemeton::load_biljou_forcing`,
`R/load_biljou.R`) : SAFRAN = OGC API-EDR GéoSAS `safran-isba` Météo-France,
journalier natif, ETP fournie (`ETP_Q`), sans auth, **France seule** ; ERA5-Land =
`mcera5`, horaire agrégé en journalier, ETP **recalculée** par Penman, clé CDS,
couverture mondiale.

```r
regen_forcing_tip = list(
  fr = paste0(
    "SAFRAN (défaut) : réanalyse Météo-France assimilant le réseau ",
    "d'observation français, journalière, ETP officielle fournie, sans clé. ",
    "France uniquement — le plus précis en métropole, y compris en montagne. ",
    "ERA5-Land : réanalyse globale ECMWF, non recalée sur les stations ",
    "françaises, ETP reconstruite, clé CDS requise. À réserver aux zones hors ",
    "France ou si SAFRAN est indisponible."),
  en = paste0(
    "SAFRAN (default): Météo-France reanalysis assimilating the French ",
    "observation network, daily, official PET provided, no key. France only — ",
    "most accurate in mainland France, including mountains. ",
    "ERA5-Land: global ECMWF reanalysis, not bias-corrected to French ",
    "stations, PET recomputed, CDS key required. Use only outside France or ",
    "when SAFRAN is unavailable."))
```

Le texte tient dans un tooltip standard. Si Pascal préfère un rendu structuré
(deux lignes SAFRAN / ERA5-Land plutôt qu'un paragraphe), reprendre le patron
`layer_tt()` de la ligne 148 (tooltip à contenu `tagList` multi-`div`) — mais le
paragraphe simple via `label_tt()` suffit et reste homogène avec les autres
labels de la sidebar.

### 7.4 Non-objectifs

* Ne rien changer au comportement du forçage ni au cœur : c'est purement du
  libellé d'aide.
* Ne pas dupliquer cette explication dans `regen_engine_prereqs()` : le prérequis
  CDS d'ERA5-Land est déjà signalé au moment du run (`regen_engine_prereq_cds`).

---

## 8. Persistance de la couche gel R7 à travers un recalcul

**Demande Pascal 2026-07-15.** Constat en session : après un run réussi du
**Moteur** (microclimf + BILJOU, forçage ERA5), la couche carte « gel » est
redevenue **vide** alors que R7 avait été calculé auparavant.

### 8.1 Diagnostic (mécanisme confirmé dans le code)

La couche « gel » de la carte colore les UGF par la colonne **`r7_gel_days`** de
`rv$result` (choroplèthe, pas un vrai raster). Le rendu (`mod_regeneration.R`
≈ 1547) fait :

```r
if (is.null(res) || !col %in% names(res)) {
  # → contour UGF nu, return()  (aucune coloration)
}
```

Or `r7_gel_days` n'est produit **que** par `frost_task` (« Lancer R7 ») — jamais
par `run_regeneration()` (qui n'a pas de `tmin` en entrée). Et **les deux chemins
de recalcul remplacent `rv$result` sèchement**, sans préserver la colonne R7 :

| Bouton | Handler | Ligne | Effet sur `r7_gel_days` |
|---|---|---|---|
| Lancer l'analyse | `observeEvent(input$run)` | `rv$result <- res$units` (≈ 733) | ❌ écrasé |
| Moteur | `engine_task` success | `rv$result <- res$units` (≈ 1298 / handler) | ❌ écrasé |
| Lancer R7 | `frost_task` | `units <- rv$result %||% units_sf()` (≈ 1029) puis `rv$result <- res$units` (≈ 1074) | ✅ enrichit le résultat courant |

Conséquence : R7 doit être lancé **en dernier** ; tout « Lancer l'analyse » ou
« Moteur » postérieur efface silencieusement la couche gel. Le contour nu qui
subsiste ressemble à un bug d'affichage.

### 8.2 Correctif — préserver R7 au recalcul (recommandé)

Dans les handlers `input$run` (≈ 733) et `engine_task` success (≈ 1298), au lieu de
`rv$result <- res$units`, **reporter les colonnes R7 de l'ancien `rv$result`** si
elles existaient. Helper local :

```r
# Réattache r7_gel_days / r7_status / R7 depuis l'ancien résultat, par jointure
# sur l'id d'UGF (colonne stable, cf. `ug_id`). R7 ne dépend ni du forçage BILJOU
# ni du microclimf → le report est valide tant que la géométrie des UGF n'a pas
# changé (même projet, même sélection cadastrale).
.regen_carry_frost <- function(new_sf, old_sf) {
  frost_cols <- intersect(c("r7_gel_days", "r7_status", "R7"), names(old_sf))
  if (is.null(old_sf) || !length(frost_cols) || !"ug_id" %in% names(new_sf) ||
      !"ug_id" %in% names(old_sf)) return(new_sf)
  keep <- sf::st_drop_geometry(old_sf)[, c("ug_id", frost_cols), drop = FALSE]
  # merge qui préserve l'ordre et la géométrie de new_sf
  idx <- match(new_sf$ug_id, keep$ug_id)
  for (c in frost_cols) new_sf[[c]] <- keep[[c]][idx]
  new_sf
}
```

Usage :

```r
# input$run
if (!is.null(res)) {
  rv$result <- .regen_carry_frost(res$units, shiny::isolate(rv$result))
  ...
}
```

Idem dans le handler success de `engine_task`.

### 8.3 Garde-fous

* **Invalider si la sélection change.** Si l'utilisateur change de projet ou de
  sélection cadastrale entre le calcul R7 et le recalcul, les `ug_id` ne
  correspondent plus → le `match()` renvoie `NA`, R7 devient NA (couche grise, pas
  faux). Acceptable, mais on peut aussi vider explicitement `r7_*` quand le set
  d'`ug_id` diffère, pour éviter un report partiel trompeur.
* **Ne PAS recalculer R7 en douce** dans `run_regeneration()` : R7 reste opt-in
  (coûteux : Tmin meteoland). Le report ne fait que *conserver* un R7 déjà calculé,
  il ne le régénère pas. Si le forçage/années changent, R7 reporté peut être
  légèrement périmé — acceptable (c'est un indicateur de calendrier, pas de
  forçage BILJOU), sinon prévoir un badge « R7 à recalculer ».

### 8.4 Alternative (option 2, moins bonne)

Plutôt que préserver la colonne, **annoter la couche gel** quand `r7_gel_days` est
absente : au lieu du contour nu (≈ 1547), afficher un message overlay « R7 non
calculé — cliquez *Lancer R7* ». Corrige la confusion « on dirait un bug » mais
oblige à relancer R7 à chaque analyse. Retenir §8.2 en priorité ; §8.4 en
complément éventuel (utile même avec le report, pour le tout premier affichage
avant tout calcul R7).

### 8.5 Test

`testServer()` : calculer R7 (mock `frost_task` → `rv$result` avec `r7_gel_days`),
puis déclencher `input$run` → vérifier que `rv$result` **conserve** `r7_gel_days`
(valeurs identiques par `ug_id`) et que les colonnes d'analyse sont bien
rafraîchies.
