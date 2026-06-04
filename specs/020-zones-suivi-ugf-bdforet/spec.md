# Spec 020 — Zones de suivi par strates BD Forêt v2 (tot / feu / res / mix)

**Version** : 0.1.0
**Date**    : 2026-06-04
**Statut**  : Validée (décisions D1-D6 actées) — à implémenter.
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` (minor — nouvelles fonctions + migration 0005).
**Cible app**  : `nemetonshiny` (sélecteur de zone peuplé des zones du projet).
**Lien**    : étend le binding projet↔zone (spec 011) et le pipeline de
masque UGF (spec 016) ; alimente FAST (spec 013/017) et FORDEAD (spec 008).

---

## 1. Objectif

À l'enregistrement d'un projet, créer **jusqu'à 4 zones de suivi
distinctes** rattachées au projet, au lieu d'une seule, par croisement de
l'**union des UGFs** avec les **strates de BD Forêt v2** :

| Zone | Nom | Géométrie |
|------|-----|-----------|
| Totale | `<projet>_tot` | **union des UGFs** |
| Feuillus | `<projet>_feu` | union des UGFs **∩** feuillus BD Forêt v2 |
| Résineux | `<projet>_res` | union des UGFs **∩** résineux BD Forêt v2 |
| Mixte | `<projet>_mix` | union des UGFs **∩** mixtes BD Forêt v2 |

`<projet>` = nom du projet **translittéré NMT** (snake_case sans accent ;
ex. `Mouthe` → `mouthe`). Les 4 zones partagent le `project_uuid` du
projet et se distinguent par leur `name` (cf. D3).

### Motivation

Le diagnostic sanitaire (FAST/FORDEAD) n'est calibré que sur les
résineux (épicéa/sapin, cf. spec 008, garde-fou « composition d'essences
hors domaine validé »). Pouvoir cibler la **strate résineuse** (`_res`)
d'un massif mixte — plutôt que l'emprise totale — supprime le bruit des
peuplements feuillus et rend le diagnostic pertinent. Les 4 strates
permettent aussi de comparer les signaux par type de peuplement.

## 2. Classification des strates — champ `tfv_g11` de BD Forêt v2

BD Forêt v2 (`cache/layers/bdforet.gpkg`, CRS 4326) porte les champs
`code_tfv`, `tfv` (libellé détaillé), **`tfv_g11`** (nomenclature
simplifiée IGN), `essence`. Le split s'appuie sur **`tfv_g11`**, propre et
corroboré par `essence` :

| `tfv_g11` | Classe NMT | Zone |
|-----------|------------|------|
| `Forêt fermée feuillus` | `feuillu` | `_feu` |
| `Forêt fermée conifères` | `resineux` | `_res` |
| `Forêt fermée mixte`, `Forêt ouverte mixte` | `mixte` | `_mix` |
| `Forêt fermée sans couvert arboré`, `Formation herbacée` | `autre` | exclu |

Helper cœur déterministe (repli `essence` puis regex `tfv` si `tfv_g11`
absent) :

```r
.classify_bdforet_strata <- function(bdforet) {
  g <- tolower(as.character(bdforet$tfv_g11 %||% NA))
  out <- rep("autre", nrow(bdforet))
  out[grepl("feuillus", g)] <- "feuillu"
  out[grepl("conif",    g)] <- "resineux"   # "conifères"
  out[grepl("mixte",    g)] <- "mixte"
  # repli essence quand tfv_g11 manquant
  na <- is.na(g) | !nzchar(g)
  if (any(na)) {
    e <- tolower(as.character(bdforet$essence[na]))
    r <- rep("autre", length(e))
    r[grepl("feuillus", e)]            <- "feuillu"
    r[grepl("sapin|épicéa|conif", e)]  <- "resineux"
    r[grepl("mixte", e)]               <- "mixte"
    out[na] <- r
  }
  out
}
```

## 3. Décisions actées

| # | Décision | Choix |
|---|----------|-------|
| **D1** | Forêts mixtes | **Zone dédiée `<projet>_mix`** (ni feuillu ni résineux pur). |
| **D2** | Placettes des zones | **Aucune.** Depuis spec 017 le diagnostic FAST/FORDEAD est *pur raster* (placette-indépendant, `obs_pixel` supprimé v0.58.0). Les zones sont des **géométries seules**. → insert zone-seule (cf. §5.2). Les placettes de validation terrain restent ajoutables *a posteriori*, découplées. |
| **D3** | Binding base | **Migration 0005** : remplacer `UNIQUE(project_uuid)` par **`UNIQUE(project_uuid, name)`** → vrai modèle « N zones par projet ». |
| **D4** | Strate vide | **Ne pas créer** la zone (surface = 0) + `cli_warn`. Un projet a donc **1 à 4 zones**. |
| **D5** | Idempotence | **Upsert** : re-enregistrer **supprime** les zones du `project_uuid` puis **recrée**. (cf. note cache §7.) |
| **D6** | Sélecteur app | **Liste déroulante à choix unique**, peuplée des **zones du projet courant** (`find_zones_by_project`), défaut **`_tot`**. Le diagnostic tourne sur **la** zone choisie (cœur mono-zone). Fini le repli sur une zone d'un autre projet. |

## 4. Architecture (règle CLAUDE.md : métier dans le cœur)

- **Cœur `nemeton`** : géométrie (union/intersection sf), classification
  `tfv_g11`, insert zone-seule, upsert, résolution multi-zones, migration.
- **App `nemetonshiny`** : charge `units` (UGFs) + `bdforet.gpkg`, appelle
  la fonction cœur, peuple le sélecteur via `find_zones_by_project()`.

## 5. Livrables cœur

### 5.1 Migration `0005_multi_zone_per_project` (pg + sqlite)

```sql
-- Remplace l'unicité sur project_uuid seul par (project_uuid, name).
DROP INDEX IF EXISTS monitoring_zone_project_uuid_uq;
CREATE UNIQUE INDEX IF NOT EXISTS monitoring_zone_project_name_uq
    ON monitoring_zone (project_uuid, name)
    WHERE project_uuid IS NOT NULL;
```

(Variante SQLite : même DDL, partial index supporté — cf. style 0003.)

### 5.2 Insert zone-seule — `create_monitoring_zone()`

Nouvelle fonction exportée, **sans placettes** (vs `register_monitoring_zone`
qui reste pour le workflow validation terrain) :

```r
#' @export
create_monitoring_zone <- function(con, zone_name, zone_polygon,
                                    project_uuid = NULL) {
  # valide args ; reprojette en 4326 ; INSERT monitoring_zone
  # (name, zone_wkt, crs_epsg=4326, project_uuid) ; renvoie l'id.
}
```

### 5.3 Résolution multi-zones — `find_zones_by_project()`

```r
#' @export
find_zones_by_project <- function(con, project_uuid) {
  # SELECT id, name FROM monitoring_zone WHERE project_uuid = $1 ORDER BY name
  # -> data.frame(id integer, name character) ; 0 ligne -> df vide.
}
```

`find_zone_by_project()` (mono) est **conservée** (rétro-compat) mais
documentée « renvoie la première zone ; préférer `find_zones_by_project`
pour les projets multi-zones ».

### 5.4 Construction + upsert — `build_project_monitoring_zones()`

```r
#' @export
build_project_monitoring_zones <- function(con, project_name, project_uuid,
                                           ugf, bdforet,
                                           strata = c("tot","feu","res","mix"),
                                           work_crs = 2154, replace = TRUE) {
  base <- .nmt_slug(project_name)                       # "Mouthe" -> "mouthe"
  # D5 upsert : purge des zones existantes du projet
  if (isTRUE(replace)) .delete_project_zones(con, project_uuid)

  u  <- sf::st_union(sf::st_make_valid(sf::st_transform(sf::st_geometry(ugf), work_crs)))
  bd <- sf::st_make_valid(sf::st_transform(bdforet, work_crs))
  cls <- .classify_bdforet_strata(bd)
  inter <- function(klass) {
    g <- sf::st_union(sf::st_geometry(bd[cls == klass, ]))
    if (!length(g)) return(NULL)
    sf::st_intersection(u, g)
  }
  geoms <- list(tot = u, feu = inter("feuillu"),
                res = inter("resineux"), mix = inter("mixte"))

  ids <- list()
  for (s in strata) {
    g <- geoms[[s]]
    if (is.null(g) || all(sf::st_is_empty(g)) ||
        as.numeric(sum(sf::st_area(g))) <= 0) {
      cli::cli_warn("Strate {.val {s}} vide pour {.val {project_name}} — zone non créée.")  # D4
      next
    }
    ids[[s]] <- create_monitoring_zone(
      con, paste0(base, "_", s),
      sf::st_sf(geometry = sf::st_sfc(sf::st_union(g), crs = work_crs)),
      project_uuid = project_uuid)
  }
  ids
}
```

Helpers internes : `.nmt_slug()` (translittération NMT), `.delete_project_zones()`
(`DELETE FROM monitoring_zone WHERE project_uuid = $1`, en transaction).

## 6. Livrables app (`nemetonshiny`)

- Bouton « Enregistrer ce projet comme zone de suivi » (ou « Générer les
  zones de suivi ») → `nemeton::build_project_monitoring_zones(con,
  project$name, project_uuid, ugf = units_sf, bdforet =
  sf::st_read(bdforet.gpkg))`. Si `bdforet.gpkg` absent : message « lancer
  le calcul du projet d'abord » (la BD Forêt est mise en cache au 1er
  calcul, cf. `download_ign_bdforet`).
- **Sélecteur « Zone de suivi »** (D6) : `choices = find_zones_by_project(con,
  project_uuid)` (libellés = `name`, valeurs = `id`), **choix unique**,
  sélection par défaut la zone `*_tot`. Supprimer le repli actuel sur la
  première zone de la base (qui affichait `villards` pour un autre projet).
  Si 0 zone : état vide + invite à générer (bandeau existant).

## 7. Notes & risques

- **Caches orphelins (D5 upsert)** : les caches raster sont rangés par
  `zone_<id>` (`fast_alert/zone_<id>/`, `fast_alert_mask/zone_<id>/`,
  `fordead/zone_<id>/`). Un upsert supprime/recrée les zones → **nouveaux
  `zone_id`** → les anciens dossiers `zone_<old_id>/` deviennent orphelins.
  La GC LRU (`.fast_raster_gc`, `.fast_alert_mask_gc`, v0.65.3) ne purge
  qu'**au sein** d'un `zone_<id>`. → prévoir un nettoyage des dossiers
  `zone_<id>` dont l'id n'existe plus en base (helper cœur
  `prune_orphan_zone_caches(con, cache_root)` optionnel, ou doc manuelle).
- **Géométries invalides** : `st_make_valid` sur UGFs et BD Forêt avant
  toute opération (UGFs auto-intersectants fréquents).
- **CRS** : opérations en `work_crs = 2154` (intersection surfacique
  fiable) ; `create_monitoring_zone` reprojette en 4326 pour le stockage
  WKT, cohérent avec l'existant.
- **`_feu` + `_res` + `_mix` ≠ `_tot`** : la somme des 3 strates peut être
  < `_tot` (zones non-forêt : herbacé, sans couvert, hors BD Forêt). C'est
  attendu (D1/classification `autre` exclue).

## 8. Tests (cœur)

- `.classify_bdforet_strata()` : `tfv_g11` → feuillu/resineux/mixte/autre ;
  repli `essence` quand `tfv_g11` NA.
- `build_project_monitoring_zones()` (fixtures sf) : noms
  `<slug>_tot/_feu/_res/_mix` ; `_tot` = aire union UGF ; `_feu`,`_res`,`_mix`
  ⊆ `_tot` ; `_feu` ∩ résineux = ∅ ; strate vide → zone non créée + warn (D4) ;
  upsert → pas de doublon, anciennes zones supprimées (D5).
- `create_monitoring_zone()` : insère sans placette ; respecte
  `UNIQUE(project_uuid, name)` (2ᵉ insert même (uuid,name) → erreur DB).
- `find_zones_by_project()` : renvoie les N zones triées par nom ; df vide
  si aucune.
- Migration 0005 : `UNIQUE(project_uuid, name)` autorise 4 zones / projet,
  refuse 2 zones de même nom.

## 9. ADR

Le passage **1 → N zones par projet** amende le modèle de la spec 011
(binding projet↔zone). À acter dans un **amendement ADR** (ou ADR dédié)
documentant : unicité `(project_uuid, name)`, zones dérivées de strates
BD Forêt, insert zone-seule placette-indépendant (aligné spec 017).

## 10. Plan de livraison

1. Migration 0005 (pg + sqlite) + test schéma.
2. `.classify_bdforet_strata()` + `.nmt_slug()` + tests.
3. `create_monitoring_zone()` + `find_zones_by_project()` + tests.
4. `build_project_monitoring_zones()` (incl. upsert/D4/D5) + tests.
5. (Optionnel) `prune_orphan_zone_caches()` + doc.
6. Release cœur (minor) + NEWS/CHANGELOG/PLAN.
7. Brief app : wiring bouton + sélecteur (D6).
