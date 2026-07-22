# Brief `foretaccess` — Desserte corrigée LiDAR (ALSroads) : largeur mesurée + géométrie recalée

> **Destinataire** : session dédiée sur le paquet `foretaccess` (et/ou `nemeton`).
> **Émetteur** : session app `nemetonshiny` (règle 12 : je ne touche pas au cœur).
> **But** : améliorer la **desserte en entrée des moteurs** (accessibilité, desserte,
> câble) en la corrigeant par LiDAR aérien, ce qui **débloque en particulier
> `places_depot()`** (aujourd'hui aveugle à la largeur des routes). Feature **NDP 1+**
> (nécessite du LiDAR), donc **côté cœur** — l'app ne fera qu'exposer un toggle.

## 1. Le problème constaté

Les moteurs `foretaccess` consomment la desserte **IGN BD TOPO V3** (via
`acquire_desserte()`). Sur données réelles (Chastel-Nouvel, foretaccess 1.9.0), deux
limites tiennent à la **qualité de cette desserte** :

- **`places_depot()` est aveugle à la largeur.** Elle avertit elle-même : *« Aucune
  largeur mesurée (largeur / largeur_de_chaussee) : le critère d'accès camion ne
  rejette rien. »* Résultat : **1877 départs candidats lâches** (sur 1548/3299
  tronçons), d'où un moteur câble **lent (~28 min : places_depot 12,7 min +
  potentiel_cable 15,1 min)** et une couverture **optimiste (91 % de forêt
  « câblable »)**. Une **largeur carrossable mesurée** rendrait `places_depot`
  sélective (départs réalistes → rapide et honnête).
- **Erreurs de position / routes disparues de BD TOPO** dégradent tous les moteurs
  (tracés least-cost calés sur un axe faux ; routage sur des tronçons qui n'existent
  plus).

## 2. La solution candidate — ALSroads (r-lidar-lab)

`ALSroads::measure_road(ctg, road, dtm)` — *Road corrections and measurements from ALS
data* (Roussel, Bourdon, Morley, Coops, Achim, 2022, partenariat MFFP Québec).

- **Entrées** : catalogue LAS (nuage ALS, via `lidR::readLAScatalog`), vecteur route
  (BD TOPO), MNT raster.
- **Sorties** (sf) : **géométrie recalée** (axe corrigé), **`ROADWIDTH`** (largeur),
  **largeur carrossable**, **pente**, **état** (route existante / déclassée / disparue).
- Compatible `sf::st_buffer()` (emprise polygonale).

C'est **exactement** ce qui manque : la largeur carrossable alimente le critère
`largeur_min_m` de `places_depot()`, la géométrie recalée améliore tous les tracés, et
l'état permet d'écarter les routes disparues.

**Écarté : `vecnet`** (r-lidar-lab, 2023). Il *vectorise* un réseau depuis un raster de
probabilité (segmentation ML), ne **corrige pas** un vecteur existant et ne produit
**pas de largeur** — autre usage (détecter des routes que BD TOPO rate), hors de ce
besoin.

## 3. Réserves (à évaluer côté cœur)

- **NDP 1+** : ALSroads exige du **LiDAR/ALS** (nuage de points). L'app est en NDP 0.
  En France, l'**IGN LiDAR HD** (public, gratuit, en déploiement national) est la
  source naturelle — cohérent avec le pipeline NDP (ADR-011 : NDP 1 = local/LiDAR).
- **Maturité** : ALSroads est **« Experimental / proof of concept »**, dernière release
  **v0.2.0 (2022)**, maintenance non visible.
- **Calibrage Québec** (MFFP, forêts nordiques / single-photon LiDAR) → **recalibrage à
  vérifier sur terrain français** (densité IGN LiDAR HD ~10 pts/m², feuillus/résineux).
- **Dépendance `lidR`** : ALSroads s'appuie sur `lidR` ; l'écosystème `foretaccess`/app
  s'appuie plutôt sur **`lasR`** (successeur plus rapide, même auteur). Coût/portage à
  arbitrer (réécrire les métriques sur `lasR` ? tolérer `lidR` en Suggests ?).
- **Coût de traitement** : non documenté, mais le recalage par nuage de points est
  **lourd** (par tronçon) — à benchmarker ; prévoir cache par emprise.

## 4. Intégration proposée (côté `foretaccess`/`nemeton`)

Rester dans le patron d'acquisition existant. Ébauche :

```r
# Nouvelle acquisition NDP 1 : desserte BD TOPO recalée + mesurée par LiDAR.
acquire_desserte_lidar(aoi, las_source, mnt, crs = 2154, cache_dir = tempdir(), ...)
  -> sf desserte enrichie : geometry recalée + champs largeur_m, largeur_carrossable_m,
     pente_pct, etat (existante/declassee/disparue)
```

- La sortie est une **desserte au même format** que `acquire_desserte()`, mais **enrichie**
  (largeur, état) et **géométriquement corrigée**.
- `places_depot()` la consomme directement : son critère **accès camion** (largeur mesurée)
  redevient discriminant → **départs réalistes** (dizaines, pas milliers).
- `preprocess()` / `reseau_desserte()` / `tracer_desserte()` / `potentiel_cable()` en
  profitent (axes justes, routes existantes seulement).
- **Dégradation** : sans LiDAR sur l'emprise → repli sur `acquire_desserte()` (NDP 0),
  comportement actuel inchangé.

## 5. Livrables attendus & propagation vers l'app

1. **Faisabilité** : valider ALSroads sur une emprise IGN LiDAR HD française (recalage +
   largeur plausibles ?), décider `lidR` vs portage `lasR`.
2. **Benchmark** : temps de `measure_road` sur une desserte départementale ; stratégie de
   cache.
3. **API cœur** : `acquire_desserte_lidar()` (ou équivalent) exportée, produisant une
   desserte enrichie `largeur_m`/`etat`, + doc Rd + tests. Repli NDP 0 documenté.
4. **Vérifier l'impact sur `places_depot()`** : mesurer la réduction du nombre de départs
   et l'amélioration de la couverture câble (l'objectif chiffré : ramener les ~1877
   départs à un ordre exploitable et la couverture 91 % à une valeur réaliste).
5. **Bump release `foretaccess`** puis signaler la version : l'app exposera un **toggle
   « NDP 1 : desserte corrigée LiDAR »** (source LAS = IGN LiDAR HD) dans les onglets
   Accessibilité/Desserte, et posera `Imports: foretaccess (>= X.Y.Z)`.

## 6. Ce que l'app fera une fois débloqué (pour info)

- Toggle **NDP 1** dans les commandes Accessibilité/Desserte : « desserte corrigée LiDAR ».
- Résolution de la source LAS (IGN LiDAR HD via l'infra existante ; l'app manipule déjà du
  LiDAR ailleurs — `lasR` en Suggests, cache COPC S3, ADR-002).
- Badge de provenance desserte (« BD TOPO » vs « BD TOPO recalée LiDAR »), comme le badge DFCI.
- Bénéfice immédiat : câble enfin exposable (places_depot sélective), et meilleure qualité
  de tous les moteurs.

## 7. Ce brief ne remplace pas les chantiers desserte déjà ouverts

Indépendant de `brief-foretaccess.md` (perf glouton, connexité `connexe`, perf/sélectivité
`places_depot`). La desserte LiDAR **atténuerait** la sélectivité de `places_depot`
(Chantier 4) en lui donnant enfin la largeur, mais **ne résout pas** la perf intrinsèque de
`places_depot`/`potentiel_cable` ni la perf du glouton.

**Sources** : ALSroads https://github.com/r-lidar-lab/ALSroads (v0.2.0, 2022) ·
vecnet https://github.com/r-lidar-lab/vecnet (v0.1.0, 2022) · Roussel et al. 2022/2023
(International Journal of Applied Earth Observation and Geoinformation).
