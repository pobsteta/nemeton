# Brief `nemetonshiny` — Tirage validation pondéré continu (FORDEAD/RECONFORT, spec 014)

**Cœur requis** : `nemeton (>= 0.140.0)` — **bumper le plancher** `Imports:`
dans `DESCRIPTION` (l'extension `weighting`/`weight_raster` est livrée en
v0.140.0). L'app ne doit pas appeler ces paramètres avec un cœur antérieur.

**Objectif app** : donner aux onglets **FORDEAD** et **RECONFORT** du plan de
validation la même pondération **continue** que l'onglet **FAST** (déjà branché
sur `create_trend_sanitary_plan()` via `|pente Theil-Sen|`). Aujourd'hui ces deux
onglets tirent en mode **catégoriel** (poids = classe 0-4 ou 1/2/3). Le cœur
sait désormais pondérer par un **raster de sévérité continu** (FORDEAD
`anomaly_index`, RECONFORT `score`), qui départage deux pixels d'une même classe.

> **Règle métier inchangée** : la normalisation et l'équilibre spatial GRTS sont
> faits **dans le cœur**. L'app se contente de résoudre le raster de sévérité et
> de le passer. Aucune logique de pondération côté app (CLAUDE.md #3).

---

## 1. Ce que le cœur fournit (v0.140.0)

`create_validation_sampling_plan()` gagne deux paramètres, **avant `seed`**,
rétro-compatibles :

```r
nemeton::create_validation_sampling_plan(
  zone, alert_raster,
  n_validation = 20L, n_control = 5L,
  classes = c(3L, 4L), control_classes = c(0L),
  buffer_m = 0, source = "FORDEAD",
  weighting     = "continuous",   # NOUVEAU : "uniform" (défaut) | "continuous"
  weight_raster = anomaly_index,  # NOUVEAU : SpatRaster continu de sévérité
  seed = 42L
)
```

Comportement :

- `weighting = "uniform"` (défaut) → **strictement l'actuel** (poids = classe).
  Le schéma de sortie est **byte-identique** : pas de colonne `alert_weight`.
  Les appels existants de l'app **ne changent pas** tant qu'on ne passe rien.
- `weighting = "continuous"` :
  - `weight_raster` est aligné sur la grille d'`alert_raster` (reproj/resample
    bilinéaire automatique) — **les grilles FORDEAD/RECONFORT n'ont pas besoin
    d'être identiques**, le cœur réconcilie.
  - `classes` devient un simple **masque d'éligibilité** (plus de stratification
    par classe) ; le tirage GRTS pondère par la sévérité normalisée.
  - **Témoins inchangés** (uniformes sur `control_classes`).
  - Nouvelle colonne de sortie **`alert_weight`** (numérique) = sévérité brute au
    point tiré, à afficher comme `alert_value` du plan FAST.

Garde-fous typés à mapper côté app :

| Condition cœur | Cause | UX suggérée |
|---|---|---|
| `nemeton_empty_alert_mask` | pas de cellule d'alerte **ou** sévérité vide/tout-NA/constante | déjà mappée → `validation_empty_mask` (message « rien à valider ») |
| `validation_weight_raster_mismatch` | `weight_raster` sans CRS / non reprojetable | **nouveau** → mapper vers une condition app (`validation_weight_mismatch`), message « couche de sévérité non géoréférencée » |

---

## 2. `service_validation_sampling.R`

### 2.1 Nouveau résolveur du raster de sévérité

Ajouter un helper **miroir** de `.resolve_alert_raster()` (qui existe déjà et
résout le masque catégoriel par source) :

```r
# Résout le raster de sévérité CONTINU pour la pondération (FORDEAD/RECONFORT).
# Renvoie NULL si indisponible (ancien run sans la couche) → l'appelant retombe
# proprement en "uniform".
.resolve_weight_raster <- function(project, con, zone_id, source) {
  if (is.null(project$path) || !nzchar(project$path)) return(NULL)

  if (identical(source, "FORDEAD")) {
    cd <- file.path(project$path, "cache", "layers", "fordead")
    if (!dir.exists(cd)) return(NULL)
    # anomaly_index est une couche PIXEL → lue sur la strate _tot (comme
    # mod_monitoring_fordead_map). Le cœur réaligne sur le masque dieback.
    id_tot <- .fordead_tot_id(con, project, zone_id)   # helper app existant
    return(tryCatch(
      nemeton::read_fordead_layer(con, zone_id = id_tot,
                                  layer = "anomaly_index",
                                  run_id = NULL, cache_dir = cd),
      error = function(e) NULL))
  }

  if (identical(source, "RECONFORT")) {
    # La couche continue RECONFORT est `score` (le masque catégoriel 1/2/3
    # servant déjà d'alert_raster est `classification`). **Réutiliser EXACTEMENT
    # le patron du viewer** `mod_monitoring_reconfort_map.R` : le manifest se
    # construit sur un OBJET `result` de run (pas con/zone_id).
    #   res <- <résoudre le result RECONFORT du run>   # cf. reconfort map module
    #   man <- nemeton::reconfort_layer_manifest(res, include_range = TRUE)
    #   row <- man[man$id == "score", , drop = FALSE]
    #   nemeton::read_reconfort_layer(layer = row, mask_polygon = aoi)
    res <- .resolve_reconfort_result(project, con, zone_id)   # helper à factoriser
    if (is.null(res)) return(NULL)
    man <- tryCatch(nemeton::reconfort_layer_manifest(res, include_range = TRUE),
                    error = function(e) NULL)
    if (is.null(man) || !nrow(man)) return(NULL)
    row <- man[man$id == "score", , drop = FALSE]
    if (!nrow(row)) return(NULL)
    aoi <- .resolve_validation_zone(project, con, zone_id)
    return(tryCatch(nemeton::read_reconfort_layer(layer = row, mask_polygon = aoi),
                    error = function(e) NULL))
  }

  NULL   # FAST : pas concerné (chemin trend séparé = generate_trend_sanitary_plan)
}
```

> **Signatures réelles à respecter** (vérifiées côté cœur) :
> - `reconfort_layer_manifest(result, include_range = FALSE)` — 1er arg = **objet
>   result de run**, PAS `con`/`zone_id`. Colonne d'id = `id` (`"score"` continu,
>   `"classification"` catégoriel).
> - `read_reconfort_layer(layer, con = NULL, zone_id = NULL, apply_zone_mask = TRUE,
>   mask_polygon = NULL)` — `layer` = **une ligne de manifest** ou un chemin raster.
> - `read_fordead_layer(con, zone_id, layer, run_id = NULL, cache_dir)` — `layer ∈
>   {"first_anomaly","anomaly_index","modelled_pixels"}`.
>
> **Comment obtenir le `result` RECONFORT** : le viewer `mod_monitoring_reconfort_map.R`
> (l. ~139-150) a déjà un résolveur (result en mémoire d'un run de session, sinon
> reconstruit). **Factoriser ce résolveur** en un helper partagé
> (`.resolve_reconfort_result()`) plutôt que dupliquer la logique. Si RECONFORT
> n'a pas de run résoluble → `NULL` → repli uniforme (cf. §2.2).

### 2.2 Câbler `generate_validation_plan()`

Ajouter un paramètre `weighting = "uniform"` à la signature de
`generate_validation_plan()`, puis, quand `weighting == "continuous"`, résoudre
et passer le raster :

```r
weight_raster <- NULL
if (identical(weighting, "continuous") &&
    source %in% c("FORDEAD", "RECONFORT")) {
  weight_raster <- .resolve_weight_raster(project, con, zone_id, source)
  if (is.null(weight_raster)) {
    # Repli propre : couche de sévérité absente (ancien run) → uniforme + info.
    cli::cli_alert_info(
      "No continuous severity layer for {source}; falling back to uniform weighting.")
    weighting <- "uniform"
  }
}

plan <- tryCatch(
  nemeton::create_validation_sampling_plan(
    zone = zone, alert_raster = alert_raster,
    n_validation = as.integer(n_validation),
    n_control    = as.integer(n_control),
    classes      = as.integer(classes),
    control_classes = as.integer(control_classes),
    buffer_m     = as.numeric(buffer_m),
    source       = source,
    weighting    = weighting,            # NOUVEAU
    weight_raster = weight_raster,       # NOUVEAU (NULL en uniform)
    seed         = seed
  ),
  error = function(e) {
    if (inherits(e, "nemeton_empty_alert_mask")) {
      rlang::abort("No alert cell / empty severity.",
                   class = "validation_empty_mask", parent = e)
    }
    if (inherits(e, "validation_weight_raster_mismatch")) {   # NOUVEAU
      rlang::abort("Severity raster not georeferenced / not alignable.",
                   class = "validation_weight_mismatch", parent = e)
    }
    stop(e)
  }
)
```

**Décision de repli** : si le mode continu est demandé mais la couche de
sévérité est absente (ancien run FORDEAD/RECONFORT sans `anomaly_index`/`score`),
retomber en **uniforme + `cli_alert_info`** (le plan se génère quand même). C'est
volontairement **plus permissif** que le garde-fou cœur (qui, lui, exige
`weight_raster` non-NULL) : le repli est décidé **par l'app**, pas par le cœur.

---

## 3. `mod_validation_sampling.R`

Réutiliser le patron `is_fast` (l. 52). Pour FORDEAD/RECONFORT, ajouter un
sélecteur de pondération dans la branche catégorielle (le `else` de `param_ui`),
**au-dessus** du `checkboxGroupInput("classes")` :

```r
shiny::radioButtons(
  ns("weighting"), i18n$t("validation_weighting_label"),
  choices = stats::setNames(
    c("continuous", "uniform"),
    c(i18n$t("validation_weighting_continuous"),   # « Par sévérité (continu) »
      i18n$t("validation_weighting_uniform"))),    # « Par classe (uniforme) »
  selected = "continuous"                          # nouveau défaut = continu
)
```

- `classes` **reste** affiché (il sert de masque d'éligibilité en continu).
- FAST : **inchangé** (branche `is_fast`, déjà en continu via le trend).
- Passer `input$weighting` (défaut `"uniform"` si NULL, ex. onglet FAST) à
  `generate_validation_plan(..., weighting = input$weighting %||% "uniform")`.

### Affichage `alert_weight`

Le plan continu porte une colonne `alert_weight`. L'afficher comme `alert_value`
du plan FAST :
- table de résultats : colonne « Sévérité » (`i18n$t("validation_alert_weight_col")`),
  formatée numérique, **seulement si** `"alert_weight" %in% names(plan)` (absente
  en uniforme et sur FAST catégoriel).
- popup carte des placettes : ajouter la sévérité à l'infobulle des points
  « Validation ».

---

## 4. i18n (`utils_i18n.R`, FR/EN)

Nouvelles clés à ajouter à `TRANSLATIONS` :

| Clé | FR | EN |
|---|---|---|
| `validation_weighting_label` | « Pondération du tirage » | "Draw weighting" |
| `validation_weighting_continuous` | « Par sévérité (continu) » | "By severity (continuous)" |
| `validation_weighting_uniform` | « Par classe (uniforme) » | "By class (uniform)" |
| `validation_alert_weight_col` | « Sévérité » | "Severity" |
| `validation_weight_mismatch_msg` | « Couche de sévérité non géoréférencée : tirage impossible. » | "Severity layer not georeferenced: cannot draw." |

Mapper la condition `validation_weight_mismatch` (levée en 2.2) vers un
`showNotification`/toast utilisant `validation_weight_mismatch_msg`.

---

## 5. DESCRIPTION

```
Imports:
    nemeton (>= 0.140.0),
    ...
```

---

## 6. Tests app (`testServer` / smoke)

- `generate_validation_plan(weighting = "continuous")` sur un projet FORDEAD avec
  `anomaly_index` en cache → plan avec colonne `alert_weight` finie, deux types.
- Repli : projet FORDEAD **sans** `anomaly_index` + `weighting="continuous"` →
  plan produit en uniforme (pas d'erreur, `alert_weight` absente), info émise.
- Mapping d'erreur : couche de sévérité sans CRS → condition
  `validation_weight_mismatch` (mock du cœur ou raster crs="").
- `is_fast` inchangé (onglet FAST toujours sur `generate_trend_sanitary_plan`).

---

## 7. Points de vigilance

- **Ne pas** ré-normaliser la sévérité côté app : le cœur fait le min-max +
  proba d'inclusion. L'app passe le raster **brut**.
- **Grilles** : FORDEAD `anomaly_index` (strate `_tot`) et le masque dieback
  (par strate) peuvent différer d'emprise/résolution → c'est **normal**, le cœur
  aligne. Ne pas tenter de resampler avant.
- **Rétro-compat** : tant que l'app ne passe pas `weighting`, tout reste comme
  avant (défaut cœur `"uniform"`). Le bump `>= 0.140.0` protège contre un appel
  des nouveaux paramètres sur un cœur trop ancien.
- **RECONFORT** : `score` est la couche **continue** ; `classification`
  (catégoriel 1/2/3) reste l'`alert_raster`. Ne pas confondre.
