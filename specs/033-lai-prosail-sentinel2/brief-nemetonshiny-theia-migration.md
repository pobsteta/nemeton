# Brief `nemetonshiny` — Migration accès THEIA + badge canopée (nemeton v0.135→0.137)

> ⚠️ **Résidu regroupé** dans `specs/brief-nemetonshiny-cleanups-lowpriority.md`
> (§3) : seul l'appel déprécié `theia_configure_s3()` (bloc SUFOSAT) reste à
> retirer + commentaires reticulate périmés. Le reste (LAI PROSAIL, signature,
> badge canopée) est **consommé**. Ce fichier reste le contexte détaillé.

**Cœur requis** : `nemeton (>= 0.137.0)`.
**Objectif** : aligner l'app sur le **nouveau modèle d'accès THEIA** (gateway de
signature, pur R) et brancher le **badge de provenance canopée**. Aucune logique
métier nouvelle côté app — que des remplacements/suppressions.

**Ce qui a changé côté cœur** (validé sur données réelles) : les COG THEIA/MESO@UM
(MUSCATE, FORMS-T, SUFOSAT) **ne se lisent plus** en `/vsis3/` + clé S3 directe
(le store rejette la clé du portail). `load_theia_source()` / `lai_sentinel2()`
signent désormais en interne via la gateway `signing.stac.teledetection.fr`
(URLs pré-signées lues en `/vsicurl/`). **Prérequis unique** :
`TLD_ACCESS_KEY` / `TLD_SECRET_KEY` en environnement (déjà dans `.Renviron`).

---

## 1. Supprimer les appels à `theia_configure_s3()` (déprécié)

`theia_configure_s3()` est **déprécié** (v0.136.0) : il n'active plus aucun accès
et émet un avertissement. `load_theia_source()` signe tout seul.

**`service_compute.R` (~ ligne 1205, coupes rases SUFOSAT)** — retirer le bloc :

```r
# AVANT
ok <- tryCatch({ nemeton::theia_configure_s3(); TRUE }, error = ...)
if (!ok) return(NULL)
fetched <- tryCatch(list(
  dates = nemeton::load_theia_source("sufosat", aoi_2154, asset = "dates"),
  proba = nemeton::load_theia_source("sufosat", aoi_2154, asset = "proba")), error = ...)

# APRÈS — plus de theia_configure_s3 ; garder le garde basé sur TLD_* en amont
fetched <- tryCatch(list(
  dates = nemeton::load_theia_source("sufosat", aoi_2154, asset = "dates"),
  proba = nemeton::load_theia_source("sufosat", aoi_2154, asset = "proba")),
  error = function(e) { cli::cli_warn("Coupes rases : load_theia_source a échoué : {conditionMessage(e)}"); NULL })
```

**Conséquence directe** : les **coupes rases (T3/SUFOSAT)** et le
**`download_chm_theia()`** (`service_theia.R`) qui échouaient (retour `/vsis3/`
illisible) **fonctionnent maintenant**. Conserver le garde amont
`theia_key_configured()` (test `TLD_ACCESS_KEY`/`TLD_SECRET_KEY` non vides) — il
reste valide.

## 2. Plus de reticulate/Python pour THEIA

`theia_signed_href()` est réécrit en **R pur** (v0.136.0) : `load_theia_source()`
en mode `year` **ne nécessite plus** `reticulate` / `teledetection` /
`pystac_client`. Mettre à jour les commentaires périmés :
- `service_theia.R` (~ l.51/62) : « signs STAC asset URLs through reticulate » → via la gateway (R pur).
- `service_compute.R` (~ l.539) : « bug load_theia_source côté reticulate » → n'est plus reticulate.

(`reticulate` reste utilisé ailleurs — FORDEAD/RECONFORT — ne pas le retirer des deps.)

## 3. Badge canopée : basculer sur `nemeton::canopy_provenance()`

L'app a sa propre `regen_canopy_provenance()` (`service_regeneration.R` ~ l.270)
avec des clés maison (`"satellite"`/`"lidar"`) et un flag inexistant
(`microclimate_model` n'est pas un flag canopée). La remplacer par le helper cœur :

```r
regen_canopy_provenance <- function(units) {
  if (!inherits(units, "sf") || nrow(units) == 0L) return(NA_character_)
  aug <- tryCatch(nemeton::detect_ndp(units)$augmented, error = function(e) NULL)
  if (is.null(aug)) return(NA_character_)
  nemeton::canopy_provenance(aug)   # "lidar_hd" | "prosail_s2" | "opencanopy"
}
```

**Les clés changent** — adapter le `switch()` du badge + l'i18n :
`"satellite"` → `"prosail_s2"`, `"lidar"` → `"lidar_hd"`, + nouveau `"opencanopy"`.
Rendu du badge (3 états) + clés i18n : voir **`brief-nemetonshiny.md`** §4/§5
(`regen_canopee_lidar` / `regen_canopee_satellite` / `regen_canopee_chm`).

> `canopy_provenance()` renvoie toujours une clé (défaut `"lidar_hd"`) ; n'afficher
> le badge que lorsqu'une analyse canopée a effectivement tourné (sinon rien).

## 4. Validation

Côté cœur, tout est validé sur données réelles (MUSCATE→LAI, FORMS-T, signature).
Côté app, après migration, relancer :
- un run **coupes rases (T3)** → doit acquérir SUFOSAT sans `theia_configure_s3` ;
- un run **reGénération** sans LiDAR → badge « satellite (repli) », LAI PROSAIL ;
- une **hauteur FORMS-T** (si branchée) → lecture OK.

## 5. Règles

1. Aucune logique métier côté app : provenance via `canopy_provenance()`, accès
   via `load_theia_source()` (le cœur signe). L'app lit et affiche.
2. Textes UI via `i18n$t(...)`.
3. Secrets (`TLD_*`) jamais dans le dépôt — env/`.Renviron` gitignoré (règle #8).
