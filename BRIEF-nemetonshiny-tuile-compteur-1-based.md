# Hand-off `nemetonshiny` — compteur de tuile « Tuile (1/120 → 120/120) » au lieu de 0/120

> **Statut** : à corriger côté app `nemetonshiny`. Aucune modif cœur
> `nemeton` requise. À retirer une fois intégré (convention hand-off).

## Constat

La console (et le toast) affichent la 1ʳᵉ scène comme
`Tuile Sentinel-2 … (0/120)`. L'utilisateur veut un compteur **1-based**
(`1/120 … 120/120`).

## Cause (pas un bug cœur — sémantique de `completed`)

Le cœur `nemeton` émet, pour `s2:scene` / `s2:scene_cached` /
`s2:scene_skipped`, un champ **`completed = i - 1`** = « nombre de scènes
**terminées avant** celle-ci » (`R/monitoring.R`). C'est volontaire et
correct : `completed/total` est une **fraction de progression** (0 au
départ, `total` à la fin via `s2:complete`). Idéal pour une barre de
progression — mais 0-based pour un libellé « tuile en cours ».

L'app affiche ce `completed` directement comme `i_val` dans le libellé
« Tuile (i_val/n_val) » → d'où le `0/120` sur la 1ʳᵉ scène.

**Décision** : ne PAS changer `completed` côté cœur (sémantique légitime,
consommée comme fraction). Corriger **uniquement l'affichage** côté app :
le libellé « tuile en cours » = `completed + 1` (1..total).

## Correctif (app, 2 endroits)

Garder les **gardes « entre STAC et 1ʳᵉ tuile »** sur le `completed` BRUT
(`!nzchar(scene) && i_val == 0L`) — elles dépendent du 0. N'ajouter le
`+1` que dans la **construction du libellé** « Tuile {scene} (X/N) ».

### 1. Mirror console — `.log_ingest_event()` (`mod_monitoring.R:2745`)

Après la garde STAC (ligne 2753, inchangée), introduire un index 1-based :

```r
  tile_no <- i_val + 1L      # completed (0-based) -> tuile en cours (1-based)
  ...
  if (identical(status, "scene_error")) {
    cli::cli_alert_warning(
      "Tuile Sentinel-2 {scene} ({tile_no}/{n_val}) — erreur{suffix}")
  } else {
    cli::cli_alert_info(
      "Tuile Sentinel-2 {scene} ({tile_no}/{n_val}){suffix}")
  }
```

### 2. Toast Shiny — observer (`mod_monitoring.R:1643-1675`)

La garde STAC (1651 `!nzchar(scene) && i_val == 0L`) reste sur `i_val`
brut. Dans les deux branches de libellé, afficher `i_val + 1L` :

```r
      } else if (nzchar(scene)) {
        ...
        htmltools::HTML(sprintf(
          i18n$t("monitoring_ingest_progress_named_fmt"),
          scene_html, i_val + 1L, n_val))      # <- + 1L
      } else {
        sprintf(i18n$t("monitoring_ingest_progress_fmt"),
                i_val + 1L, n_val)              # <- + 1L
      }
```

## Vérification

- `s2:scene` émis au **début** de chaque scène, `i` de 1 à `total` →
  `completed = 0..(total-1)` → `tile_no = 1..total` → `1/120 … 120/120`.
- `s2:complete` (`completed = total`) n'est PAS rendu comme une tuile
  (phase distincte) → pas de `121/120`.
- Les gardes STAC restent justes (testées sur `completed == 0` brut, état
  sans scène avant la 1ʳᵉ tuile).

## Bump

- App `nemetonshiny` PATCH (fix d'affichage). NEWS : « Compteur de tuile
  S2 1-based (`Tuile (1/N)` au lieu de `0/N`) ; `completed` cœur
  inchangé. »
- Aucun changement `nemeton`, aucun bump plancher requis.

## (Optionnel) variante cœur

Si tu préfères que le cœur expose un index humain explicite plutôt qu'un
`+1` côté app : ajouter `tile_index = as.integer(i)` aux payloads
`s2:scene*` (`R/monitoring.R`), non-breaking, et l'app afficherait
`ev$tile_index %||% (completed + 1)`. Plus « propre » sémantiquement mais
nécessite quand même une retouche app — le `+1` app-only suffit et est
plus léger.

## Références

- Cœur : `nemeton::ingest_sentinel2_timeseries()` payloads `s2:scene*`
  (`R/monitoring.R`, `completed = i - 1`).
- App : `mod_monitoring.R` toast (L1643-1675) + `.log_ingest_event`
  (L2745-2780) ; gardes STAC L1651 / L2753.
- Session source : `nemeton` dev session du 2026-06-03.
