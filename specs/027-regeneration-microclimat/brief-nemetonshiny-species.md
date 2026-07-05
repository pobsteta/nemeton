# Brief `nemetonshiny` — Pré-remplissage « Essence cible » (onglet reGénération)

**Cœur requis** : `nemeton (>= 0.134.0)` — **contrat déjà disponible, vérifié**.
**But** : remplacer le sélecteur `species` (quasi vide, alimenté par
`regeneration_tolerances()`) par la **liste d'essences du cœur**, avec les
**essences présentes sur les parcelles en tête**.

---

## 1. Contrat cœur (vérifié sur le code réel)

```r
nemeton::regen_species_choices(
  units = <sf des UGF> | NULL, species_col = NULL, tfv_col = <col TFV> | NULL,
  level = c("species", "class"),   # défaut "species"
  include_atlas = FALSE, region = "BFC", lang = "fr")
```

Retourne un `data.frame` **trié present-first** (64 essences FRM en `level="species"`),
colonnes :
`code, label, species_sci, type, statut, species_class, tmax_tol_c, vpd_tol_kpa,
shade_tol, drought_tol, confidence, invasif, present, groupe`.

- **`code`** — ex. `"larix_sibirica"`, `"quercus_robur"` : **scorable** par
  `indice_priorite_regen(species = code)` (vérifié).
- **`label`** — libellé FR/EN selon `lang`, ex. « Mélèze de Sibérie ».
- **`present`** — `logical` : essence présente sur les UGF.
- **`groupe`** — `"present"` | `"adaptation"` (+ `"atlas"` seulement si
  `include_atlas = TRUE`, non utilisé ici).

La présence est déduite de `units` via une colonne TFV
(`map_tfv_to_species_class`) ou une colonne d'essence. Sans `units` (ou sans
colonne exploitable) : liste FRM complète, toutes `present = FALSE` (dégradation
propre — déjà mieux que le sélecteur vide actuel).

## 2. Changements app

### 2.1 `service_regeneration.R` — wrapper units-aware

Remplacer l'actuel :

```r
regeneration_species_choices <- function() {
  tryCatch(nemeton::regeneration_tolerances(), error = function(e) NULL)
}
```

par :

```r
regeneration_species_choices <- function(units = NULL, lang = "fr") {
  tfv_col <- NULL
  if (!is.null(units)) {
    cand <- intersect(c("tfv_code", "code_tfv", "CODE_TFV", "tfv"), names(units))
    if (length(cand)) tfv_col <- cand[[1]]
  }
  tryCatch(
    nemeton::regen_species_choices(units = units, tfv_col = tfv_col,
                                   level = "species", lang = lang),
    error = function(e) NULL)
}
```

### 2.2 `mod_regeneration.R` — peuplement réactif sur `units_sf()`

Le bloc de peuplement actuel (~ l.184-191) est **statique** (`observe` sans
`units`). Le rendre **réactif à `units_sf()`** et passer les UGF :

```r
shiny::observeEvent(units_sf(), {
  sc <- regeneration_species_choices(units = units_sf(), lang = i18n$get_translation_language())
  generic <- stats::setNames("", i18n$t("regen_species_generic"))
  if (is.null(sc) || !nrow(sc)) {
    shiny::updateSelectInput(session, "species", choices = generic); return()
  }
  # Option générique en tête, puis essences PRÉSENTES, puis adaptation.
  # sc est déjà trié present-first ; on mappe label -> code (setNames(code, label)).
  present <- sc[sc$groupe == "present", , drop = FALSE]
  adapt   <- sc[sc$groupe == "adaptation", , drop = FALSE]
  mk <- function(df) stats::setNames(df$code, df$label)
  # Variante simple (liste plate, présentes déjà en tête) :
  choices <- c(generic, mk(present), mk(adapt))
  # Variante optgroup (optionnelle) : liste nommée imbriquée
  #   choices <- list(); choices[[i18n$t("regen_species_generic")]] <- ""
  #   if (nrow(present)) choices[[i18n$t("regen_species_present")]]   <- as.list(mk(present))
  #   if (nrow(adapt))   choices[[i18n$t("regen_species_adaptation")]] <- as.list(mk(adapt))
  shiny::updateSelectInput(session, "species", choices = choices)
}, ignoreNULL = FALSE)
```

Le `species` sélectionné est **déjà** transmis aux runs (`mod_regeneration.R`
~ l.258 et ~ l.397 : `species = if (nzchar(input$species)) input$species else NULL`)
→ **rien à changer** côté run ; le `code` scorable passe tel quel à
`indice_priorite_regen()`.

## 3. i18n (`utils_i18n.R`, FR/EN)

- Mettre à jour `regen_species_tip` : retirer « à venir côté nemeton » →
  « Essences présentes sur BD Forêt v2 listées en tête. » /
  « Species present on BD Forêt v2 are listed first. »
- (Si variante optgroup) ajouter `regen_species_present` (« Présentes » /
  « Present ») et `regen_species_adaptation` (« Adaptation » / « Adaptation »).
- `regen_species_generic` (option générique) : **conservé** en tête.

## 4. Tests

- Mocker `nemeton::regen_species_choices` → renvoyer un `data.frame` avec
  `groupe = c("present","present","adaptation")`.
- Vérifier le peuplement : **option générique en tête**, **présentes avant
  adaptation**, mapping `label → code`.
- Vérifier que le `code` sélectionné est transmis au run (`species =`) et non le
  `label`.

## 5. Dégradation

- `units` sans colonne TFV/essence, ou `regen_species_choices()` → `NULL` :
  retomber sur la liste FRM complète (toutes `present = FALSE`) ou, en dernier
  recours, la seule option générique. **Jamais** de sélecteur en erreur.

## 6. Règles

1. Aucune logique métier côté app : la liste, la présence et le tri viennent du
   cœur (`regen_species_choices`). L'app **peuple et affiche**.
2. Textes UI via `i18n$t(...)`.
3. Le `code` (pas le `label`) est ce qui est passé à `indice_priorite_regen()`.
