# Brief `foretaccess` — Desserte : performance, connexité, largeur mesurée, LiDAR

> **Destinataire** : session dédiée sur le paquet `foretaccess` (et/ou `nemeton`).
> **Émetteur** : session app `nemetonshiny` (règle 12 : je ne touche pas au cœur).
> **Révision 2026-07-22** — document unique consolidé. Cinq chantiers, du plus mûr au
> plus prospectif. Tout est mesuré cette session sur AOI réelle.

Contexte de mesure : projet **Chastel-Nouvel** — 30 parcelles / 31 ha, MNT 5 m
530×571 (~302k cellules), desserte existante ≈ 806 km / 3 299 tronçons. Données `toy`
du paquet : 2 500 cellules, 1 parcelle. Version de référence : **foretaccess 1.9.0**.

## Déjà livré (1.6.0 → 1.9.0) — ne pas re-traiter

- **`places_depot()`** (1.6.0, corrigé 1.6.1) — candidates de places de dépôt câble,
  sortie `sf` avec champ `cable` prête pour `potentiel_cable(departs = )`. (Perf/sélectivité
  encore problématiques : Chantier 3.)
- **`volume_depuis_p1()`** (1.7.0) + **`acquire_inputs(volume = )`** (1.8.0) — pont
  P1 Nemeton → volume câble/IPC. Consommé côté app.
- **`accessfor_correspondance()`** (1.9.0) — crosswalk vers ACCESSFOR (IGN). **Consommé
  côté app** (nemetonshiny v0.113.0 : panneau de validation, couches WFS
  `IGNF_ACCESSIBILITE-PHYSIQUE-FORETS-:acces_skidder` / `:acces_porteur`).

---

## Chantier 1 (OUVERT) — Performance des moteurs de desserte

### Mesures (foretaccess 1.9.0, Chastel-Nouvel)

| Étape | Temps |
|---|---|
| `preprocess()` | 1,2 s |
| `surface_cout_construction()` | 0,1 s |
| **`reseau_desserte(mode = "glouton")`** | **692 s (~11,5 min)** |
| `reseau_desserte(mode = "steiner")` | non mesuré — **N² tracés** → estimé **> 5 h** |
| `optimiser_reseau(...)` (multistart 16 / recuit 200 / riprute) | non mesuré — **k × réseau complet** par essai → intraitable |

Sur `toy` (1 parcelle) : **1,46 s**. Coût dominé par la taille de l'emprise et **le nombre
de parcelles** (un tracé A* par parcelle en glouton, N² en Steiner).

### État côté app

Seul le **glouton** est exposé (`DESSERTE_ENGINES <- c("glouton")`), en worker async
**opt-in** (« calcul long ») + cache projet. Steiner et optimiseurs **retirés de l'UI**.

### Demande

1. **Ramener le glouton < 5 min** sur une AOI de gestion type (ou documenter un ordre de
   grandeur + un mode « emprise réduite / parcelles agrégées »). Pistes : parallélisation
   des tracés, réutilisation du réseau partiel, grille plus grossière, cache de propagation.
2. **Benchmarker Steiner et les optimiseurs** ; fixer des **bornes/defaults exposables**
   (n_start, n_iter, cap de parcelles) au-delà desquels l'app doit avertir.

---

## Chantier 2 (OUVERT) — Connexité du réseau créé (`connexe`)

`reseau_desserte(mode = "glouton")` renvoie **`connexe = FALSE`** alors que
**`desservies = 30/30`**. Un réseau non connexe est contre-intuitif pour de la conception
d'accès.

### Demande

Clarifier la **sémantique exacte** de `connexe` (composantes multiples raccordées chacune
à une entrée du réseau existant → connexe au sens du graphe global ? artefact du critère
CA-16.5 ? vrai défaut de raccordement ?) et **corriger si défaut**. L'app affiche ce
booléen dans un badge — sa signification doit être sûre.

---

## Chantier 3 (OUVERT) — Performance et sélectivité de `places_depot()` / câble

Mesuré app-side (foretaccess 1.9.0), en câblant `places_depot()` → `potentiel_cable(departs=)` :

| Étape | Temps | Sortie |
|---|---|---|
| **`places_depot(desserte, mnt, foret)`** | **762 s (~12,7 min)** | **1877 départs** (sur 1548/3299 tronçons) |
| **`potentiel_cable(departs = 1877)`** | **907 s (~15,1 min)** | raster valide |
| **Total câble** | **~28 min** | **91 % de la forêt en `accessible_cable`** (optimiste) |

Deux problèmes :

1. **`places_depot()` est lente** (12,7 min sur 806 km) pour une fonction de **pré-filtrage**.
2. **Sélectivité faible sans entrées riches** : sur BD TOPO **sans largeur mesurée ni couche
   `retournements`**, elle ne rejette presque rien → 1877 départs lâches → `potentiel_cable`
   lent **et** couverture optimiste. (Sa doc : « pré-filtre grossier, précision ~4 % ».)

Conséquence : **l'app ne peut pas exposer le câble** (28 min pour une carte optimiste).

### Demande

- **Perf `places_depot()`** (cible : quelques minutes max sur une desserte départementale).
- **Guidage sur les entrées** : quel apport minimal (couche `retournements` ? largeur ?
  `espacement_min_m` resserré ?) ramène les départs à un ordre **exploitable** (dizaines) et
  une couverture réaliste. Documenter la recette. (Voir Chantier 4 : la largeur peut venir du
  LiDAR.)
- Éventuellement un **mode rapide** assumé pré-filtre.

---

## Chantier 4 (PROSPECTIF, NDP 1) — Desserte corrigée LiDAR (ALSroads)

La cause racine des Chantiers 1 et 3 est en partie la **qualité de la desserte BD TOPO** en
entrée : pas de largeur mesurée (→ `places_depot` aveugle), erreurs de position, routes
disparues. **ALSroads** (r-lidar-lab) corrige exactement ça par LiDAR aérien.

`ALSroads::measure_road(ctg, road, dtm)` — nuage LAS + vecteur route (BD TOPO) + MNT →
**géométrie recalée** + **`ROADWIDTH`** + largeur carrossable + pente + **état**
(existante / déclassée / disparue). La largeur carrossable alimente directement le critère
`largeur_min_m` de `places_depot()`.

### Réserves

- **NDP 1+** : exige du LiDAR/ALS ; source FR = **IGN LiDAR HD** (public, gratuit).
- **Expérimental** (v0.2.0, 2022, proof of concept, non maintenu), **calibré Québec**
  (MFFP) → recalibrage à vérifier sur terrain français.
- Dépend de **`lidR`** (l'écosystème vise plutôt **`lasR`**) → arbitrer portage vs Suggests.
- Coût de traitement **lourd** (par tronçon), non documenté → benchmarker + cache.
- **`vecnet`** (même labo) est écarté : il *vectorise* un réseau depuis un raster de
  probabilité ML, ne corrige pas un vecteur et ne produit pas de largeur (autre usage).

### Demande

Évaluer une **acquisition NDP 1** produisant une desserte **enrichie + corrigée** :

```r
acquire_desserte_lidar(aoi, las_source, mnt, crs = 2154, cache_dir = tempdir(), ...)
  -> sf desserte : geometry recalée + champs largeur_m, largeur_carrossable_m,
     pente_pct, etat ; même format que acquire_desserte() (repli NDP 0 si pas de LiDAR).
```

Consommée telle quelle par `places_depot()` (accès camion enfin discriminant → départs
réalistes), `preprocess()` et les moteurs (axes justes, routes existantes). **Mesurer
l'impact** : réduction des ~1877 départs et de la couverture 91 % à des valeurs réalistes.

---

## Chantier 5 (OUVERT, optionnel) — Sortie `$lignes` contractée

`reseau_desserte()` renvoie `$lignes` = **10 640 features** LINESTRING (segments fins au pas
de la grille). L'app contourne via `$reseau` (raster) et n'utilise `$lignes` que pour
l'export GPKG. Un **`$lignes` contracté** (comme `vectoriser_reseau()` pour le graphe)
permettrait un affichage vecteur propre. Optionnel.

---

## Livrables attendus & propagation vers l'app

1. Perf glouton < 5 min + bornes/defaults Steiner & optimiseurs (Chantier 1).
2. Clarification/correction de `connexe` (Chantier 2).
3. Perf `places_depot` + recette d'entrées sélectives (Chantier 3).
4. Faisabilité + API `acquire_desserte_lidar()` (Chantier 4, NDP 1).
5. `$lignes` contracté (Chantier 5, optionnel).
6. **Bump release `foretaccess`** puis signaler la version : l'app pinne par **tag figé**
   (`Remotes: …@vX.Y.Z`), donc un **bump de pin côté app** sera nécessaire (contrairement à
   `nemeton` en `@*release`). L'app élargira alors `DESSERTE_ENGINES` (Steiner/optimiseurs),
   exposera le câble (places_depot sélective) et un toggle « NDP 1 : desserte corrigée LiDAR ».

**Sources (Chantier 4)** : ALSroads https://github.com/r-lidar-lab/ALSroads (v0.2.0, 2022) ·
vecnet https://github.com/r-lidar-lab/vecnet (v0.1.0, 2022) · Roussel et al. 2022/2023
(International Journal of Applied Earth Observation and Geoinformation).
