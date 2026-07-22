# Spec 041 — Desserte corrigée LiDAR : largeur mesurée et géométrie recalée

**Version** : 1.0.0
**Date**    : 2026-07-22
**Statut**  : **Cadré — non implémenté.** Décision D1 (dépendance ALSroads) à trancher.
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` — `desserte_lidar()`.
**Cible aval** : `foretaccess` — `places_depot()`, `preprocess()`, `reseau_desserte()`,
`potentiel_cable()`, qui consomment la desserte en entrée.
**Cible app**  : `nemetonshiny` — un toggle « NDP 1 : desserte corrigée LiDAR ».
**Origine** : `specs/brief-foretaccess-desserte-lidar.md` (session app, 2026-07-22),
qui se déclare explicitement « feature NDP 1+, donc côté cœur ».

## 1. Objectif

Produire, à partir d'un nuage LiDAR, une desserte **enrichie** (largeur carrossable,
état) et **géométriquement recalée**, au même format que la desserte BD TOPO que
`foretaccess` consomme aujourd'hui. Le gain immédiat est que `places_depot()`
cesse d'être aveugle à la largeur.

C'est une **dérivation de donnée**, donc du métier cœur — même nature que
`sanitize_chm()` ou `extract_h_dom()` (spec 005). `foretaccess` reste seul
propriétaire des moteurs ; `nemeton` lui fournit une meilleure entrée.

## 2. Le problème (mesuré côté app, foretaccess 1.9.0)

`places_depot()` avertit elle-même : *« Aucune largeur mesurée
(largeur / largeur_de_chaussee) : le critère d'accès camion ne rejette rien. »*

Conséquence sur Chastel-Nouvel : **1 877 départs candidats** sur 1 548 tronçons,
moteur câble à **~28 min** (`places_depot` 12,7 + `potentiel_cable` 15,1) et
couverture **optimiste à 91 %** de forêt « câblable ». Une largeur mesurée rend le
critère discriminant.

S'y ajoutent les erreurs de position et les routes disparues de BD TOPO, qui
faussent tous les tracés least-cost.

## 3. Ce que la vérification a corrigé au brief

Trois points du brief ne tiennent pas tels quels, vérifiés le 2026-07-22 :

**(1) L'arbitrage `lidR` vs `lasR` n'existe pas.** Le brief le pose en question
ouverte (« réécrire les métriques sur `lasR` ? tolérer `lidR` en Suggests ? »).
Or `DESCRIPTION` porte **déjà les deux** : `lidR (>= 4.0.0)` et
`lasR (>= 0.10.0)`, en Suggests. `lidR` est donc déjà toléré, et ALSroads —
qui s'appuie sur `lidR` — n'impose aucun portage.

**(2) ALSroads est moins dormant que décrit.** Le brief indique « dernière
release v0.2.0 (2022), maintenance non visible ». Le dépôt a en fait été poussé
le **2024-11-15**, n'est pas archivé. Il reste « experimental », mais l'argument
d'abandon est plus faible qu'annoncé. **Licence : GPL-3** (champ `License` de son
`DESCRIPTION`) — compatible avec `nemeton`, aucune autorisation à demander.

**(3) Le cœur lit déjà des nuages de points.** `pai_depuis_nuage()`
(`R/regen_engines.R`) et `R/lidar_processing.R` ouvrent des tuiles
`.las`/`.laz`/COPC via `lasR`, avec bornage mémoire. La brique d'entrée existe.

## 4. Le vrai manque — l'acquisition, pas la lecture

`nemeton` **n'acquiert pas** les tuiles LiDAR HD. Il n'expose que
`probe_ign_lidar_tile()` / `probe_ign_lidar_tiles()`, des **diagnostics** de
téléchargement — dont la doc dit explicitement que c'est `nemetonshiny` qui
télécharge (« When `nemetonshiny` reports "Tile X/Y: failed" … while NUAGE tiles
succeed »). `inst/datasources/FR.json` ne déclare que `lidar_mnh` / `lidar_mnt` /
`lidar_mns` via happign : des **rasters dérivés**, pas le nuage NUAGE.

**Conséquence de conception** : la fonction prend un **répertoire de tuiles**
fourni par l'appelant, exactement comme `pai_depuis_nuage(dossier_las = )`. Elle
n'acquiert rien. C'est l'idiome établi, et cela évite de dupliquer côté cœur une
acquisition qui vit déjà côté app.

## 5. Fonction

```r
desserte_lidar(
  desserte,                      # sf LINESTRING, sortie d'acquire_desserte() (BD TOPO)
  dossier_las,                   # répertoire de tuiles .las/.laz/.copc.laz
  mnt,                           # SpatRaster
  crs          = 2154,
  etat_conserve = c("existante"), # tronçons retenus en sortie
  cache_dir    = NULL,
  ...
)
```

→ `sf` **au même format que l'entrée**, géométrie recalée, plus les colonnes
`largeur_m`, `largeur_carrossable_m`, `pente_pct`, `etat`
(`existante` / `declassee` / `disparue`).

**Repli explicite** : si `dossier_las` est vide ou ne couvre pas l'emprise, la
fonction renvoie la desserte d'entrée **inchangée** avec `etat = NA` et
avertit — le comportement NDP 0 actuel est préservé, jamais dégradé en silence.

**Provenance** : une colonne `desserte_source` (`"bdtopo"` / `"bdtopo_lidar"`)
par tronçon, sur le principe déjà retenu pour `completer_volume_ifn()` — une
géométrie recalée ne doit pas pouvoir se faire passer pour la donnée d'origine.

## 6. Décisions

| # | Décision | Statut |
|---|---|---|
| D1 | Dépendre d'`ALSroads` (Suggests) ou réimplémenter la mesure de largeur | **Ouverte** — cf. §7 |
| D2 | Acquisition hors périmètre : l'appelant fournit `dossier_las` | Proposée (§4) |
| D3 | Colonne de provenance par tronçon | Proposée (§5) |
| D4 | Recalibrage France : les seuils Québec sont-ils transposables ? | **Ouverte — bloque la confiance dans les largeurs** |
| D5 | `etat_conserve` par défaut : ne garder que `existante` ? | Proposée |

## 7. D1 — dépendre ou réimplémenter

**Recommandation : dépendre, en `Suggests`.** ALSroads est GPL-3, s'appuie sur
`lidR` déjà présent, et réimplémenter une mesure de largeur de chaussée par nuage
de points est un travail de recherche, pas d'intégration. Le risque de
maintenance se couvre par un `requireNamespace()` et un repli documenté — le
package n'est requis que pour la voie NDP 1.

**Contre-argument à peser** : « experimental / proof of concept », une seule
release, et un calibrage québécois (forêts nordiques, LiDAR single-photon) qui
n'a rien d'universel. D'où **D4**, qui est le vrai risque du chantier : une
largeur mesurée mais fausse est pire qu'une largeur absente, parce que
`places_depot()` la croira.

## 8. Plan en 4 lots

### Lot 1 — Faisabilité sur donnée française *(bloquant, à faire en premier)*
Faire tourner `ALSroads::measure_road()` sur une emprise IGN LiDAR HD réelle
(Chastel-Nouvel, dép. 48) et **confronter les largeurs mesurées au terrain ou à
l'orthophoto**. Sans ce contrôle, tout le reste est prématuré. Sortie attendue :
un verdict D4 chiffré, pas une impression.

### Lot 2 — Benchmark et cache
Temps de `measure_road()` par tronçon et sur une desserte départementale
(3 299 tronçons sur l'AOI de référence). Stratégie de cache par emprise. Le
recalage par nuage est lourd ; sans chiffre, l'app ne peut pas l'exposer — leçon
du câble-mât et du glouton (692 s).

### Lot 3 — `desserte_lidar()`
La fonction du §5, son repli, sa colonne de provenance, `.Rd` à la main, tests.

### Lot 4 — Mesure de l'effet réel
Rejouer `places_depot()` sur la desserte enrichie et **chiffrer** : les ~1 877
départs tombent-ils à un ordre exploitable ? La couverture 91 % devient-elle
réaliste ? C'est le seul critère de succès du chantier — le reste n'est que
plomberie.

## 9. Hors périmètre

- L'acquisition des tuiles LiDAR HD (reste côté app, cf. §4).
- La perf intrinsèque de `places_depot()` / `potentiel_cable()` / du glouton :
  chantiers `foretaccess` distincts (`brief-foretaccess-consolide-2026-07-22.md`).
  La largeur mesurée **atténue** la sélectivité, elle ne corrige pas la
  complexité.
- `vecnet`, écarté par le brief à juste titre : il vectorise un réseau depuis un
  raster de probabilité, il ne corrige pas un vecteur et ne produit pas de
  largeur.
