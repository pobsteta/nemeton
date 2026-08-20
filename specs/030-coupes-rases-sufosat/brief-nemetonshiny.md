# Brief `nemetonshiny` — Radar T3 « Coupes rases » (SUFOSAT, spec 030)

**Cœur requis** : `nemeton (>= 0.113.0)` — déjà la contrainte de
`nemetonshiny` main (T3 est exporté depuis `nemeton@0.112.0`). **Pas de bump
de dépendance.**
**Objectif app** : câbler l'indicateur **T3** (`indicateur_t3_coupes_rases`)
pour qu'il apparaisse sur le **radar de la famille T** (à côté de T1/T2),
alimenté par le produit national **SUFOSAT** récupéré depuis Theia.

> **Rappel métier** : T3 = pression de coupe rase, indicateur **inversé**
> (haut = beaucoup de coupe = mauvais). **L'inversion est faite dans le cœur**
> (`nemeton::normalize_indicator`, comme R5) — l'app **ne ré-inverse jamais**.

---

## 1. Ce que le cœur fournit

```r
# Chargement de la source SUFOSAT (2 assets, national, lu par bbox via STAC) :
dates <- nemeton::load_theia_source("sufosat", aoi, asset = "dates")   # SpatRaster YYDDD
proba <- nemeton::load_theia_source("sufosat", aoi, asset = "proba")   # SpatRaster %

# Calcul T3 (retourne un VECTEUR numérique, comme T1/T2 — pas un sf) :
t3 <- nemeton::indicateur_t3_coupes_rases(
  units,
  sufosat_dates  = dates,
  sufosat_proba  = proba,
  window_years   = 5,      # fenêtre de récence (défaut)
  min_proba      = 0.9     # seuil de probabilité (défaut)
)
units$indicateur_t3_coupes_rases <- t3
```

- `load_theia_source()` nécessite l'accès S3 Theia : appeler
  `nemeton::theia_configure_s3()` une fois (mêmes credentials que les autres
  sources Theia déjà câblées). SUFOSAT est **une seule couverture nationale**
  (2018-présent) ; la lecture est recadrée sur l'AOI par `terra`.
- `indicateur_t3_coupes_rases()` retourne un **vecteur numérique** (0-100,
  haut = plus de coupe), `NA` par unité si `sufosat_dates = NULL` — même type
  de retour que T1/T2 (≠ N2/A5 qui renvoient l'`sf`).

## 2. Acquisition + cache — `build_sufosat_layer()` (calqué sur `build_foret_ancienne_layer`)

Nouveau helper dans `service_compute.R`, sur le modèle de
`build_foret_ancienne_layer()` (l. 991) :

```r
build_sufosat_layer <- function(cfg, project_path, aoi, crs = 2154) {
  # cache <project>/cache/layers/sufosat/{dates,proba}.tif, clé = bbox AOI
  # 1. si cache présent → terra::rast() ; sinon
  # 2. nemeton::theia_configure_s3(); load_theia_source("sufosat", aoi, "dates"/"proba")
  # 3. crop AOI, écrire le cache, retourner list(dates = , proba = )
  # Échec (Theia non configuré / pas de scène) → NULL (T3 restera NA, pas de régression)
}
```

## 3. Wiring dans `service_compute.R` (bloc miroir de foret_ancienne, ~l. 854)

```r
# Coupes rases → T3 (spec 030). Source optionnelle activée par l'utilisateur.
sufosat_cfg <- projet_for_ug$metadata$sufosat
if (!is.null(sufosat_cfg) && isTRUE(sufosat_cfg$enabled) &&
    "indicateur_t3_coupes_rases" %in% effective_indicators) {
  state$current_task <- "sufosat"; report_progress(state)
  layers$sufosat <- build_sufosat_layer(
    sufosat_cfg, project_path, aoi = compute_unit,
    crs = sf::st_crs(compute_unit)$epsg %||% 2154)
}
```

Puis dans **`compute_single_indicator()`** (l. 3701), une branche pour
`indicateur_t3_coupes_rases` qui résout `layers$sufosat` :

```r
"indicateur_t3_coupes_rases" = {
  s <- layers$sufosat
  if (is.null(s)) return(rep(NA_real_, nrow(parcels)))
  nemeton::indicateur_t3_coupes_rases(
    parcels, sufosat_dates = s$dates, sufosat_proba = s$proba,
    window_years = sufosat_cfg$window_years %||% 5,
    min_proba    = sufosat_cfg$min_proba    %||% 0.9)
}
```

Ajouter `indicateur_t3_coupes_rases` à **`list_available_indicators()`**,
**gaté** sur la présence de `metadata$sufosat$enabled` (comme R5/N2 le sont
sur leur source), pour ne pas tenter Theia quand la source n'est pas demandée.

## 4. UI (`mod_project.R`) — pas d'upload, un simple toggle Theia

Bloc optionnel « **Coupes rases (SUFOSAT)** » :
- **Toggle** « Activer » — **gaté** sur Theia configuré (S3 credentials) ;
  désactivé + tooltip si absent.
- **Paramètres** : `window_years` (slider 1-8, défaut 5), `min_proba` (slider
  0.5-1.0, défaut 0.9).
- Écrit dans `projet$metadata$sufosat = list(enabled=, window_years=, min_proba=)`.
- Aide i18n : « Détection nationale des coupes rases par radar Sentinel-1
  (CNES/CESBIO). Indicateur inversé : plus de coupe = score plus bas. »

## 5. Radar — automatique (ne rien ré-inverser)

Une fois la colonne `indicateur_t3_coupes_rases` présente sur `units`,
`nemeton::create_family_index()` la rattache **automatiquement** à la famille
T (le cœur a déjà `T3` dans sa config), et `normalize_indicator` **inverse**
T3 (haut=mauvais → contribution radar haut=bon, comme R5). L'axe T du radar
passe donc de 2 à 3 sous-indicateurs **sans code radar dédié**.

- **NE PAS** ré-inverser T3 côté app (déjà fait au cœur — cf. mémoire projet
  « Sens R5 inversé »).
- Le libellé/tooltip radar de T3 vient de la config cœur
  (`nemeton::get_indicator_config()` / `INDICATOR_FAMILIES$T`) — réutiliser la
  même source que T1/T2 ; ajouter une clé i18n app seulement si le libellé de
  l'axe est géré côté app.

## 6. Critères d'acceptation (app)

- [ ] Sans `metadata$sufosat$enabled` : famille T inchangée (T1/T2), aucune
      requête Theia, aucune régression.
- [ ] Theia non configuré : toggle désactivé (ou T3 = NA proprement).
- [ ] Avec SUFOSAT activé sur une zone à coupes rases récentes : l'axe T3
      apparaît sur le radar, **score bas** là où il y a beaucoup de coupe
      (indicateur inversé).
- [ ] La couche SUFOSAT (dates+proba) est mise en cache et réutilisée.
- [ ] `window_years` / `min_proba` de l'UI sont bien propagés au calcul.
- [ ] Tous les textes passent par `i18n$t()`.

## 7. Hors scope

- Carte des coupes rases (affichage raster) — le radar T3 d'abord ; une couche
  Leaflet SUFOSAT pourra suivre.
- Recalibrage des bornes de normalisation T3 (fait au cœur, défaut 0-100).

---

# 8. Ancrer la fenêtre sur le calendrier (2026-08-20)

**Cœur requis** : `nemeton (>= 0.177.0)` — aucun changement de code cœur, le
paramètre existe depuis l'origine.

## Le constat

Les deux sliders de *Sources & paramètres* couvrent `window_years` (1-8) et
`min_proba`. **`reference_year` n'est passé nulle part** — ni UI, ni
`metadata$sufosat`, ni `service_compute.R`. Il reste donc `NULL`, et le cœur le
déduit alors de **la coupe la plus récente trouvée dans les UGF analysées**.

La fenêtre a donc la bonne largeur, mais son **point d'ancrage flotte** :

- un massif dont les dernières coupes datent de 2021 est jugé sur **2017-2021**,
  donc une coupe de 2018 y compte comme « récente » ;
- deux projets ne sont **pas comparables** s'ils n'ont pas la même coupe la plus
  récente, même réglés sur la même fenêtre.

Mesuré sur les 94 UGF de La-Vieille-Loye / Chaux : `reference_year` valait 2025
et excluait **565 des 1 260** pixels détectés (ceux de 2018-2020). Correct pour
« pression récente », mais ce 2025 venait des données, pas d'un choix.

## Le correctif — une ligne

Décision validée le 2026-08-20 : **ancrer sur l'année courante**, sans nouveau
réglage. Le slider annonce « fenêtre en années » ; l'utilisateur suppose
légitimement qu'elle se termine aujourd'hui.

Dans `service_compute.R`, à côté des deux paramètres déjà transmis (~l. 971) :

```r
sufosat_layer$window_years   <- sufosat_cfg$window_years %||% 5
sufosat_layer$min_proba      <- sufosat_cfg$min_proba    %||% 0.9
sufosat_layer$reference_year <- as.integer(format(Sys.Date(), "%Y"))
```

…puis s'assurer que le dispatcher le fait suivre à
`nemeton::indicateur_t3_coupes_rases(reference_year = )`, comme les deux autres.

## Ce que ça change pour l'utilisateur

« Les 5 dernières années » veut enfin dire les 5 dernières années. Un massif
sans coupe récente descend vers 0 au lieu d'être jugé sur une fenêtre ancienne
— ce qui est le résultat attendu : pas de coupe récente, pas de pression.

**À prévoir** : les scores T3 déjà calculés peuvent changer sur les projets dont
la dernière coupe est antérieure à l'année courante. Ce n'est pas une
régression, c'est la correction ; mais si un banc de validation compare des
sorties T3 d'avant et d'après, c'est le facteur à regarder en premier.

## Ce que ce brief ne demande PAS

- **Pas de troisième slider.** L'option d'exposer une « année de référence » a
  été écartée : elle ferait arbitrer par l'utilisateur une question qui n'a
  qu'une bonne réponse par défaut. Le paramètre reste joignable par le code
  pour une analyse rétrospective.
- **Aucun changement cœur.** `reference_year` existe depuis l'origine ; seule sa
  documentation a été renforcée pour signaler le piège (v0.180.0.9000).
