# Brief — 3 zones de suivi par croisement UGFs × BD Forêt v2 (`_tot` / `_feu` / `_res`)

> **Statut** : plan d'implémentation. **Paperwork-first** : ce chantier
> ajoute une **méthode** (construction multi-zones) + une **migration de
> schéma** → à promouvoir en **spec 020** (+ amendement ADR-013 / spec 008
> pour le modèle multi-zones par projet) **avant code**, conformément à la
> règle projet. Le présent brief tient lieu de matière à cette spec.

## Objectif

À l'enregistrement d'un projet, créer **3 zones de suivi distinctes**
liées au projet, au lieu d'une seule :

| Zone | Nom | Géométrie |
|------|-----|-----------|
| Totale | `<projet>_tot` | **union des UGFs** |
| Feuillus | `<projet>_feu` | union des UGFs **∩** feuillus BD Forêt v2 |
| Résineux | `<projet>_res` | union des UGFs **∩** résineux BD Forêt v2 |

`<projet>` = nom du projet **translittéré NMT** (snake_case, sans accent ;
ex. `Mouthe` → `mouthe`). Voir convention NMT (CLAUDE.md).

## Découpage (règle CLAUDE.md : métier dans le cœur)

- **Cœur `nemeton`** : géométrie (union/intersection sf), classification
  feuillu/résineux BD Forêt, enregistrement des 3 zones, résolution
  multi-zones. **Nouvelle fonction exportée** + 1 migration.
- **App `nemetonshiny`** : charge les UGFs (`units`) et
  `cache/layers/bdforet.gpkg`, appelle la fonction cœur, peuple le menu
  « Zone de suivi » avec les 3 zones du projet.

## Classification feuillu / résineux — via `tfv_g11` (BD Forêt v2)

Champ **`tfv_g11`** (nomenclature simplifiée IGN), propre et corroboré par
`essence`. Valeurs observées :

| `tfv_g11` | `essence` corrélée | Classe |
|-----------|--------------------|--------|
| `Forêt fermée feuillus` | Feuillus | **feuillu** |
| `Forêt fermée conifères` | Sapin, épicéa | **résineux** |
| `Forêt fermée mixte` / `Forêt ouverte mixte` | Mixte | **mixte** (cf. décision D1) |
| `Forêt fermée sans couvert arboré` / `Formation herbacée` | NC/NR | **non-forêt → exclu** |

Helper cœur proposé (déterministe, documenté) :

```r
# Retourne un facteur "feuillu"/"resineux"/"mixte"/"autre" par polygone.
.classify_bdforet_strata <- function(bdforet) {
  g <- tolower(as.character(bdforet$tfv_g11))
  out <- rep("autre", length(g))
  out[grepl("feuillus",  g)] <- "feuillu"
  out[grepl("conif",     g)] <- "resineux"   # "conifères"
  out[grepl("mixte",     g)] <- "mixte"
  out
}
```

> Repli si `tfv_g11` absent : dériver de `essence`
> (`Feuillus`→feuillu, `Sapin, épicéa`→resineux, `Mixte`→mixte) ; sinon
> regex sur `tfv` (« feuillus prépondérants » → feuillu, « conifères
> prépondérants » → resineux).

## Algorithme (fonction cœur)

```r
#' @export
build_project_monitoring_zones <- function(con, project_name, project_uuid,
                                           ugf, bdforet, placettes,
                                           radius_m = 15,
                                           strata = c("tot","feu","res"),
                                           work_crs = 2154) {
  # 1. Géométries en CRS projeté (intersections valides en surfacique)
  u  <- sf::st_make_valid(sf::st_transform(sf::st_geometry(ugf), work_crs))
  ugf_union <- sf::st_union(u)

  bdf <- sf::st_make_valid(sf::st_transform(bdforet, work_crs))
  cls <- .classify_bdforet_strata(bdf)
  feu_union <- sf::st_union(sf::st_geometry(bdf[cls == "feuillu",  ]))
  res_union <- sf::st_union(sf::st_geometry(bdf[cls == "resineux", ]))

  geoms <- list(
    tot = ugf_union,
    feu = if (length(feu_union)) sf::st_intersection(ugf_union, feu_union) else NULL,
    res = if (length(res_union)) sf::st_intersection(ugf_union, res_union) else NULL
  )

  # 2. Enregistrer chaque strate non vide. Nom NMT : <projet>_<suffixe>.
  base <- .nmt_slug(project_name)                  # "Mouthe" -> "mouthe"
  ids <- list()
  for (s in strata) {
    g <- geoms[[s]]
    if (is.null(g) || all(sf::st_is_empty(g)) ||
        as.numeric(sf::st_area(sf::st_union(g))) <= 0) {
      cli::cli_warn("Strate {.val {s}} vide pour {.val {project_name}} — zone non créée.")
      next
    }
    pl <- .clip_placettes(placettes, g, work_crs)  # cf. décision D2
    ids[[s]] <- register_monitoring_zone(
      con,
      zone_name    = paste0(base, "_", s),
      zone_polygon = sf::st_sf(geometry = sf::st_sfc(g, crs = work_crs)),
      placettes    = pl,
      radius_m     = radius_m,
      project_uuid = paste0(project_uuid, "::", s))   # cf. décision D3
  }
  ids
}
```

(`register_monitoring_zone()` reprojette déjà en 4326 et stocke le WKT.)

## Blocages structurants à lever (cœur)

### B1 — Contrainte UNIQUE sur `project_uuid`

`monitoring_zone_project_uuid_uq` est **UNIQUE sur `project_uuid`**
(migration 0003) → **3 zones ne peuvent pas partager le même
`project_uuid`**. Deux options :

- **D3.a (recommandée)** : suffixer le `project_uuid` par strate
  (`<uuid>::tot|feu|res`). Simple, pas de migration de la contrainte.
  `find_zone_by_project()` doit alors être complété (B2).
- **D3.b** : migration **0005** (pg + sqlite) remplaçant l'unicité par
  `UNIQUE (project_uuid, name)`. Plus propre sémantiquement (vrai modèle
  « N zones par projet »), mais migration + impact sur `find_zone_by_project`.

### B2 — `find_zone_by_project()` ne renvoie qu'**un** id

`R/find_zone_by_project.R` fait `rs$id[1L]`. Ajouter
**`find_zones_by_project(con, project_uuid)`** renvoyant un data.frame
`(id, name)` de **toutes** les zones du projet (match exact en D3.b, ou
`project_uuid LIKE '<uuid>::%'` en D3.a). L'app peuple le menu avec ça.

## Décisions ouvertes (à trancher dans la spec 020)

- **D1 — Mixte** : les forêts « mixte » vont-elles dans `_feu`, `_res`,
  les **deux**, ou **aucune** ? Le libellé utilisateur (« zones feuillus »
  / « zones résineuses ») suggère **strates pures → mixte exclu des deux**
  (défaut proposé). Variante : `feuillus prépondérants`→`_feu`,
  `conifères prépondérants`→`_res` via le `tfv` détaillé.
- **D2 — Placettes par zone** : `register_monitoring_zone()` exige des
  `placettes` (sf avec `plot_id`). Pour `_feu`/`_res`, on **clippe** les
  placettes du projet à la géométrie de la strate
  (`st_intersection`/`st_filter`), ou on régénère un échantillonnage
  (cf. `sampling_plan.R`) ? Cas « 0 placette dans la strate » à gérer.
- **D3 — Binding** : suffixe `project_uuid` (D3.a) vs migration unicité
  (D3.b). Impacte `find_zone_by_project`/app.
- **D4 — Zones vides** : un projet 100 % feuillu n'a pas de `_res`.
  Proposé : **ne pas créer** la zone vide (warn), plutôt qu'une zone à
  géométrie nulle.
- **D5 — Idempotence** : re-enregistrer un projet déjà doté de ses 3
  zones → upsert (remplacer) ou refuser ? Aligner sur le comportement
  actuel de « Enregistrer ce projet comme zone de suivi ».

## Wiring app (`nemetonshiny`)

- Le bouton « Enregistrer ce projet comme zone de suivi » (ou un nouveau
  « Créer les 3 zones de suivi ») appelle
  `nemeton::build_project_monitoring_zones(con, project$name,
  project_uuid, ugf = units_sf, bdforet = st_read(bdforet.gpkg),
  placettes = parcels_sf)`.
- BD Forêt : `cache/layers/bdforet.gpkg` (déjà produit au 1er calcul,
  cf. `download_ign_bdforet`). Gérer son absence (message : lancer le
  calcul projet d'abord).
- Menu « Zone de suivi » : peupler via `find_zones_by_project()` (les 3
  zones), sélection par défaut `_tot`. Règle déjà signalée : ne **pas**
  retomber sur une zone d'un autre projet.

## Tests (cœur)

- `.classify_bdforet_strata()` : feuillus/conifères/mixte/autre depuis
  `tfv_g11` (+ repli `essence`).
- `build_project_monitoring_zones()` sur fixtures sf : 3 zones nommées
  `<slug>_tot/_feu/_res` ; `_tot` = aire de l'union UGF ; `_feu` ⊆ `_tot`
  et `_feu` ∩ résineux = ∅ ; `_res` ⊆ `_tot` ; somme aires `_feu`+`_res`
  ≤ aire `_tot` (mixte exclu) ; strate vide → zone non créée + warn.
- `find_zones_by_project()` : renvoie les 3 ids pour un projet, ∅ sinon.
- Géométrie : `st_make_valid` couvre les UGFs auto-intersectants.

## Références

- Cœur : `register_monitoring_zone()` (`R/monitoring.R`),
  `find_zone_by_project()` (`R/find_zone_by_project.R`),
  `map_bdforet_essence()` (`R/species-config.R`), migration
  `inst/db/migrations/{pg,sqlite}/0003_project_uuid.sql`.
- Données : `cache/layers/bdforet.gpkg` (champs `code_tfv`, `tfv`,
  `tfv_g11`, `essence` ; CRS 4326).
- À produire : **spec 020** + amendement ADR (modèle multi-zones/projet),
  migration **0005** si D3.b.
- Session source : `nemeton` dev session du 2026-06-04.
