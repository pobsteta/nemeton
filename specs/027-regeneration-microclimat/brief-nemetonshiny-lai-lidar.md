# Brief `nemetonshiny` — lai_max piloté par le LiDAR quand microclimf est sauté

**Cœur requis** : `nemeton (>= 0.138.0)`.
**But** : sur un projet **LiDAR HD sans clé CDS** (cas RECONFORT), faire tourner
BILJOU avec un `lai_max` **issu du LiDAR** (donnée réelle) au lieu de rien.

---

## 1. Le bug (constaté en exécutant le vrai calcul sur RECONFORT)

Onglet reGénération, projet RECONFORT (`20260701_204501_ltcp`, NDP 1, LiDAR HD
présent, **pas de clé CDS**), champ « LAI max » laissé vide → **carte vide**.

Chaîne de défaillance dans `service_regeneration.R` (chemin moteur) :

1. **microclimf** est gaté sur la clé CDS (`l.387 : !is.null(grid) && regen_cds_credentials_ready()`).
   Pas de clé → **sauté** → pas d'`exposition`, et surtout **pas de `lai_max` LiDAR**.
2. Le **repli LAI satellite** (`.regen_lai_fallback`, `l.419`) est gaté
   `is.null(lai_max) && is.null(grid)` → il ne se déclenche **que sans LiDAR**.
   RECONFORT **a** du LiDAR (`grid` non nul) → **sauté**.
3. Résultat : `lai_max` reste `NULL` → BILJOU ne produit rien → indice NA → carte
   vide.

> Le cœur v0.138.0 pose maintenant un **filet** : `regen_bilan_hydrique()` avec
> `lai_max` NULL n'échoue plus, il **avertit et applique un défaut par type**
> (feuillu 5 / résineux 4.5). La carte n'est donc plus jamais vide. **Mais** c'est
> un proxy — d'où ce brief pour utiliser la vraie structure LiDAR quand elle
> existe.

## 2. Correctif app — dériver `lai_max` du LiDAR

Dans le bloc BILJOU de `service_regeneration.R` (~ l.415-428), **avant** l'appel à
`regen_bilan_hydrique()`, quand `lai_max` est NULL :

```r
lai_max <- cfg$lai_max
if (is.null(lai_max)) {
  if (!is.null(grid)) {
    # LiDAR présent : PAI structural depuis le nuage COPC — SANS clé CDS.
    nuage_dir <- file.path(project_path, "cache", "layers", "lidar_nuage")
    if (dir.exists(nuage_dir) && length(list.files(nuage_dir, pattern = "\\.(laz|las|copc\\.laz)$"))) {
      pai_r <- tryCatch(
        nemeton::pai_depuis_nuage(dossier_las = nuage_dir, parcelle = res, res = 2),
        error = function(e) { warnings <<- c(warnings, sprintf("PAI LiDAR: %s", conditionMessage(e))); NULL })
      if (!is.null(pai_r)) {
        lai_max <- tryCatch(.regen_lai_per_unit(res, pai_r), error = function(e) NULL)
        if (!is.null(lai_max)) canopy <- "lidar"   # provenance = PAI LiDAR HD
      }
    }
  } else {
    # Pas de LiDAR : repli satellite existant (LAI S2/PROSAIL).
    lai_r <- .regen_lai_fallback(res, out_dir, cfg)
    if (!is.null(lai_r)) {
      lai_max <- tryCatch(.regen_lai_per_unit(res, lai_r), error = function(e) NULL)
      if (!is.null(lai_max)) { canopy <- "satellite"; attr(res, "lai_source") <- "prosail_s2" }
    }
  }
}
```

**Points** :
- `pai_depuis_nuage(dossier_las, parcelle, res=2, ...)` (cœur) produit le PAI par
  maille **sans** ERA5/CDS ; `.regen_lai_per_unit()` (déjà utilisé pour le repli
  satellite) l'agrège par UGF.
- Réutiliser `.regen_lai_per_unit()` tel quel (PAI et LAI sont tous deux des
  rasters mono-couche à agréger).
- Si `pai_depuis_nuage` échoue (nuage absent/corrompu) → `lai_max` reste NULL →
  le **filet cœur** (défaut par type) prend le relais. Jamais de carte vide.

## 3. microclimf reste gaté sur CDS — c'est normal

microclimf (la **simulation microclimatique**, `regen_sensibilite`) a besoin d'ERA5
(clé CDS) pour l'`exposition`. Ce brief ne débloque **que** `lai_max`/BILJOU (stress
hydrique), ce qui suffit à colorer l'indice (au moins un des deux facteurs). Sans
clé CDS, la moitié « exposition » reste absente — comportement attendu.

## 4. Provenance canopée (lien badge D5)

Quand `lai_max` vient du LiDAR, `canopy <- "lidar"` → badge « Canopée : LiDAR HD »
(cf. `brief-nemetonshiny.md` §3-5 et `canopy_provenance()`). Quand il vient du
repli satellite, `"satellite"`/`prosail_s2`. Quand c'est le **défaut cœur** (ni
LiDAR ni satellite exploitables), ne pas revendiquer de provenance donnée : ne pas
poser `lai_source`, laisser le badge par défaut.

## 5. Validation (à refaire côté app après correctif)

Projet RECONFORT, sans clé CDS, « LAI max » vide, forçage SAFRAN → **Lancer les
moteurs** :
- `pai_depuis_nuage` doit produire un `lai_max` par UGF (badge « LiDAR HD ») ;
- BILJOU écrit `biljou.gpkg` (`njstress`) ;
- l'analyse se rafraîchit → indice de priorité coloré (vérifié côté cœur : indice
  ~91.7-91.9, 0 NA sur les 30 UGF).

## 6. Règles

1. Décision de source + calcul PAI/LAI = **cœur** (`pai_depuis_nuage`,
   `lai_sentinel2`). L'app orchestre l'agrégation par UGF et la provenance.
2. Jamais de logique métier dans le module ; textes via `i18n$t(...)`.
3. Le champ « LAI max » manuel reste une **surcharge** explicite (prioritaire).
