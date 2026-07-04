# Brief `nemetonshiny` — suivi reGénération (2026-07-04)

**Cœur requis** : `nemeton (>= 0.129.2)`.
**Contexte** : validation du moteur microclimf sur données LiDAR réelles côté
cœur (v0.129.1) + correctifs de messages (v0.129.2) + deux retours UI/ops. Ce
brief liste ce qui est actionnable **côté app**. Aucune logique métier à ajouter
(règles #1/#3) — que du câblage/présentation.

---

## 1. Bumper la dépendance cœur : `nemeton (>= 0.129.2)`

`DESCRIPTION` : `Imports: nemeton (>= 0.118.0 …)` → **`nemeton (>= 0.129.2 …)`**.
(`Remotes: pobsteta/nemeton@*release` tire déjà la dernière release ; on aligne
juste le plancher sur ce qui est requis.)

Pourquoi c'est nécessaire :

- **v0.129.1** : le chemin **moteur** de `regen_sensibilite()` (microclimf) ne
  tournait pas contre le microclimf installé (vegp/soilc packés, sorties
  runmicro en array nu). Corrigé + validé sur LiDAR réel. Sans ce cœur, un run
  moteur plante.
- **v0.129.2** : les **messages de garde** ne fuient plus de charabia
  `]8;;ide:help:…` dans l'app (cli `{.fn}` → `{.code}`). **Réinstaller `nemeton`
  fait disparaître le charabia visible dans l'onglet.**

## 2. UI — sidebar « Couche affichée » non rétractable

`mod_regeneration.R`, sidebar DROITE portant le radio « Couche affichée » :

```r
# actuel (rétractable, flèche « > ») :
bslib::sidebar(position = "right", open = TRUE,     width = 260, …)
# cible (comme le sélecteur « Indice spectral » de Carte FAST) :
bslib::sidebar(position = "right", open = "always", width = 260, …)
```

Une seule ligne. Le radio, les choix et l'observer `leafletProxy` restent.

## 3. Avertissements de garde dans l'onglet — origine et deux options

Les avertissements affichés (`regen_sensibilite() engine path needs …`,
`regen_bilan_hydrique() engine path needs …`) sont **normaux** : `run_regeneration()`
(`service_regeneration.R`) appelle les moteurs avec `precomputed = pc$…` mais,
quand ni `precomputed` ni les entrées moteur ne sont fournis, la garde cœur
refuse et explique quoi passer.

**Choisir selon la maturité voulue :**

### Option A — rester en `precomputed`/dégradation propre (recommandé court terme)
Quand il n'y a ni `precomputed` ni entrées moteur, **ne pas appeler le moteur** :
afficher un message **i18n** clair (« Fournir des sorties precomputed, ou des
données LiDAR HD / forçage ERA5 pour le calcul moteur ») au lieu de laisser
remonter le message d'erreur cœur brut. Le radar A/W/R et le reste continuent de
tourner sur ce qui est disponible.

### Option B — activer le moteur microclimf réel (opt-in, long)
Derrière la case à cocher opt-in (microclimf ≈ heures), passer les **entrées
moteur** aux fonctions cœur (elles sont prêtes et validées, nemeton ≥ 0.129.2) :

```r
# sensibilité microclimatique (LiDAR HD + ERA5)
nemeton::regen_sensibilite(
  units, mnt = <dtm>, mnh = <chm>,
  las = <dir LiDAR>,        # ou pai = <raster LAI S2/PROSAIL> (repli NDP 0, spec 033)
  annees_moy = <c(...)>, annees_canic = <c(...)>,  # cf. microclimate_detect_years()
  cache_dir = <cache/regeneration>)

# bilan hydrique (biljouR, forçage SAFRAN/ERA5)
nemeton::regen_bilan_hydrique(
  units, meteo = <biljouR::safran_to_meteo(...)>,
  sol = <biljouR::biljou_soil(ewm = …)>, lai_max = cfg$lai_max)
```

Le forçage ERA5 de `regen_sensibilite` nécessite les identifiants CDS → §4.
Recommandation : calcul en tâche asynchrone (ExtendedTask/future) + cache sous
`<project>/cache/regeneration/`.

## 4. Identifiants Copernicus CDS (pour le forçage ERA5 réel — option B)

`mcera5`/`ecmwfr` sont **optionnels** (Suggests côté cœur). Le cœur appelle
`mcera5::request_era5()`, qui s'authentifie via le **trousseau `ecmwfr`**, PAS
via `.Renviron`. Aucun `Sys.getenv("CDS_…")` n'est lu.

- **Dev / poste** : au niveau **utilisateur**, une fois :
  ```r
  ecmwfr::wf_set_key(key = "<TOKEN_CDS>")   # nouveau CDS, ecmwfr >= 2.0
  ```
  Stocké dans `~/.config/R/ecmwfr/` → disponible pour la session app comme pour
  tout `Rscript`. **Ne pas** mettre le token dans un `.Renviron` de repo (secret).
- **Déploiement (Docker/systemd)** : injecter le token comme **secret**
  d'environnement et appeler `ecmwfr::wf_set_key(key = Sys.getenv("CDS_PAT"))` au
  démarrage de l'app (jamais commité).
- Accepter les conditions du dataset *ERA5-Land hourly* sur le site CDS.
- ⚠️ La pression doit être en **kPa** (borne `checkinputs` dépendante de
  l'altitude) — `mcera5` la fournit normalement ainsi ; à vérifier au 1er run.

## 5. Provenance canopée (rappel)

La provenance LiDAR HD vs repli satellite (S2/PROSAIL, flag `detect_ndp()$augmented`
`"lai_ml"`) et le badge associé sont cadrés dans
**`specs/033-lai-prosail-sentinel2/brief-nemetonshiny.md`** (spec 033 D5).

---

### Récapitulatif des actions app
1. `DESCRIPTION` : `nemeton (>= 0.129.2)` + réinstaller le cœur.
2. `mod_regeneration.R` : `open = TRUE` → `open = "always"` (sidebar droite).
3. `service_regeneration.R` : option A (message i18n propre) **ou** B (câbler les
   entrées moteur derrière l'opt-in).
4. Si option B : identifiants CDS via `ecmwfr::wf_set_key()` (jamais en repo).
5. Badge provenance canopée : cf. brief spec 033 D5.
