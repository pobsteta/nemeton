# Brief cœur `nemeton` — `progress_callback` pour `regen_sensibilite()` / `regen_bilan_hydrique()`

**Type** : feat cœur (bump **mineur**). **Motivation** : donner à l'app la
granularité *fine* pour les notifications ntfy du moteur reGénération (option §4
du brief `brief-nemetonshiny-engine-ntfy.md`). Aujourd'hui l'app ne peut notifier
qu'aux frontières de stage (microclimf/BILJOU) car ces deux fonctions cœur
**n'exposent pas** de callback de progression — contrairement à
`load_biljou_forcing()`, `load_eobs_source()`, `fordead_run()`,
`reconfort_*`, `ingest_sentinel2_timeseries()` qui suivent déjà le patron.

## Contrat existant (à réutiliser tel quel)

Patron « monitoring » du cœur : un argument `progress_callback = NULL` et un
helper no-op

```r
emit <- function(payload) { if (!is.null(progress_callback)) progress_callback(payload) }
```

Chaque `payload` est une **liste nommée** `list(current = "<ns>:<step>", …)`.
Réf. `load_biljou_forcing()` (`R/load_biljou.R:137`,154) :
`"biljou:safran_unit"` (`i`/`n`/`id`), `"biljou:era5_download"`
(`i`/`n`/`id`/`year`), `"biljou:complete"`, `"biljou:unavailable"`.

## Granularité atteignable (et ses limites)

| Boucle | Où | Instrumentable côté cœur ? |
|--------|----|----------------------------|
| ERA5 **par année × catégorie** | `.rsen_moyenne_categorie()` → `lapply(annees, .rsen_traiter_annee)` (`regen_engines.R:254`) | ✅ oui |
| ERA5 **mois k/12** | interne à `mcera5::request_era5()` | ❌ externe (prints only) |
| microclimf par catégorie | `regen_sensibilite()` appelle `.rsen_moyenne_categorie` 2× (moyenne, canicule) | ✅ oui |
| BILJOU **point k/N** | interne à `biljouR::biljou_run_grid()` (`regen_engines.R:136`) | ❌ externe (prints only) |

Donc : ERA5 **par année** (ex. « 2020 (moyenne) », « 2022 (canicule) ») et
**start/complete** BILJOU. Le mois-par-mois (mcera5) et le point-par-point
(biljouR) restent hors de portée sans changement **amont** — à ne PAS bricoler
par scraping du stdout.

## API — `regen_sensibilite()`

Ajouter `progress_callback = NULL` (après `cache_dir`, avant `precomputed`).
Émettre :

- avant chaque année, dans la boucle de `.rsen_moyenne_categorie` :
  ```r
  list(current = "regen_expo:era5", category = <"moyenne"|"canicule">,
       year = <int>, i = <int>, n = <int>)
  ```
- une fois par catégorie, juste avant `runmicro` (facultatif mais utile) :
  ```r
  list(current = "regen_expo:microclimf", category = <…>)
  ```
- en fin de chemin moteur, avant le `return(units)` :
  ```r
  list(current = "regen_expo:complete")
  ```

**Threading** : ajouter `emit` + `category` à `.rsen_moyenne_categorie()` et
`.rsen_traiter_annee()`. La boucle devient (schéma) :

```r
.rsen_moyenne_categorie <- function(annees, ..., emit = NULL, category = NA) {
  n <- length(annees)
  res <- lapply(seq_len(n), function(k) {
    if (!is.null(emit)) emit(list(current = "regen_expo:era5",
      category = category, year = annees[[k]], i = k, n = n))
    .rsen_traiter_annee(annees[[k]], ...)
  })
  ...
}
```

Aux 2 sites d'appel (`regen_engines.R:393` M, `:396` C), passer
`emit = emit, category = "moyenne"` puis `"canicule"`. Le chemin `precomputed`
(retour anticipé) n'émet rien — cohérent (rien n'est calculé).

## API — `regen_bilan_hydrique()`

Ajouter `progress_callback = NULL`. `biljou_run_grid()` étant monolithique,
émettre seulement :

- avant l'appel : `list(current = "regen_biljou:start", n = nrow(points))`
- après succès : `list(current = "regen_biljou:complete")`

## Rétro-compatibilité

- Défaut `NULL` → comportement **byte-identique** à l'actuel (émission = no-op).
- Aucune nouvelle dépendance. `...` continue d'ignorer les args inconnus.
- `emit` enveloppé (jamais de throw : suivre `tryCatch(progress_callback(payload),
  error = function(e) invisible(NULL))` comme fordead/reconfort — un push ne doit
  jamais casser un run).

## Documentation (⚠ fonctions EXPORTÉES)

`regen_sensibilite` et `regen_bilan_hydrique` sont exportées → **éditer
`NAMESPACE` (inchangé ici) et `man/*.Rd` à la main** (roxygen `@param
progress_callback …` calqué sur `load_biljou.R`), **NE PAS lancer
`devtools::document()`** (dégrade les `.Rd`, cf. mémoire projet). Ajouter le
`@param` dans les blocs roxygen des deux fonctions **et** la ligne
correspondante dans les `.Rd`.

## Tests (`tests/testthat/`)

- `regen_sensibilite` : mocker `.rsen_traiter_annee` via
  `testthat::local_mocked_bindings()` (retour = un petit `SpatRaster` factice
  `list(tmax=…, vpd=…)`), passer un `progress_callback` enregistreur, asserter
  la séquence : `regen_expo:era5` émis `length(annees_moy)` + `length(annees_canic)`
  fois avec les bons `category`/`year`/`i`/`n`, puis `regen_expo:complete`.
  (Évite tout ERA5/microclimf réel.) `skip_if_not_installed("microclimf")` +
  `skip_if_not_installed("terra")`.
- `regen_bilan_hydrique` : `skip_if_not_installed("biljouR")` ; callback
  enregistreur → asserter `regen_biljou:start` (avec `n`) puis
  `regen_biljou:complete`. Le chemin `precomputed` (sans callback) reste vert.
- Non-régression : `progress_callback = NULL` → sortie identique (le test
  existant `precomputed` suffit).

## Versioning

feat cœur → **bump mineur** (`X.(Y+1).0`) : DESCRIPTION + NEWS + CITATION
cohérents, PR→main (release.yml taggue). Entrée NEWS « Added — progress_callback
sur regen_sensibilite/regen_bilan_hydrique (parité contrat monitoring) ».

## Suite app (après release cœur)

Mettre à jour `brief-nemetonshiny-engine-ntfy.md` §4 : la granularité fine
devient disponible. L'app passe un `progress_callback` (dans le worker) qui mappe
`regen_expo:era5` → push « ERA5 année {year} ({category}) »,
`regen_expo:microclimf`/`:complete`, `regen_biljou:start`/`:complete` — dédup
naturelle (une émission par année/catégorie). Réutiliser le patron
`.build_fordead_progress_callback` (closure + `.ntfy_send`).
```
```

## Décision demandée

Confirmer avant implémentation :
1. Périmètre = ERA5 par année + microclimf par catégorie + BILJOU start/complete
   (le mois/point restant hors portée) — **OK ?**
2. Noms d'événements `regen_expo:*` / `regen_biljou:*` — **OK ?** (l'app devra
   s'y aligner ; cohérent avec `biljou:*` de `load_biljou_forcing`).
