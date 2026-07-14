# Changelog

## nemeton 0.157.0 (2026-07-14)

#### Added — `run_memory_capped()` : FORDEAD ne peut plus emporter la session

Le 2026-07-13, un diagnostic RECONFORT a tué R, l’app **et** la session
de surveillance. `systemd-oomd` ne tue pas le processus fautif : sous
pression mémoire, il tue le **scope** entier (les 11 processus de
RStudio, les terminaux avec). RECONFORT a été isolé en v0.155.0 — son
Python est un *sous-processus* (`conda run python`), donc plafonnable
dans un cgroup.

FORDEAD, lui, n’a pas cette chance : son Python tourne dans
l’interpréteur **embarqué** de reticulate (`fp$fit()`, `fp$predict()`),
et les moteurs reGénération sont du R pur. Leur mémoire *est* celle du
process R, donc celle du scope de l’app. Le 2026-07-14, RStudio est
reparti à l’OOM en plein FORDEAD. Il n’y a rien à plafonner en
in-process : il faut déplacer le travail dans un **process R enfant**,
et plafonner celui-là.

`run_memory_capped(fun, args, db_url, progress_path, progress_callback, memory_max)`
exécute une fonction exportée du cœur dans un enfant placé dans un
cgroup transitoire (`systemd-run --scope --property=MemoryMax=…`, 70 %
de la RAM par défaut). Un run qui déborde meurt **seul**, avec une
erreur attrapable (« ran out of memory and was killed »), au lieu
d’emporter le scope.

Deux arguments ne traversent pas une frontière de process, et sont donc
**reconstruits dans l’enfant** plutôt que passés :

- `con` (une `DBIConnection` n’est pas sérialisable) → passer `db_url` ;
  l’enfant ouvre et referme la sienne via
  [`db_connect()`](https://pobsteta.github.io/nemeton/reference/db_connect.md).
- `progress_callback` (une closure non plus) → passer `progress_path` ;
  l’enfant y écrit les événements au **format exact** attendu par l’app
  (`<path>.json` atomique = dernier événement, `<path>.ndjson` =
  journal), et le parent *tail* ce fichier pour **rejouer** chaque
  événement dans le `progress_callback` qu’on lui a donné. Les effets de
  bord du callback appelant — notamment les **push ntfy** — sont donc
  préservés.

Sans `systemd-run` (hors Linux, conteneur sans bus utilisateur, CI), le
travail tourne quand même dans un enfant (sa mémoire est au moins rendue
à l’OS en sortant) mais **sans plafond**, avec un avertissement
explicite.

À ne pas confondre avec
[`run_reticulate_isolated()`](https://pobsteta.github.io/nemeton/reference/run_reticulate_isolated.md),
qui lance aussi un enfant mais pour **épingler un interpréteur Python**,
et ne plafonne rien. Les deux sont complémentaires.

Dépendance ajoutée : `processx` (Suggests) — pour surveiller l’enfant
sans bloquer la remontée de progression.

## nemeton 0.156.0 (2026-07-14)

#### Added — `scratch_dir()` : où atterrissent les intermédiaires volumineux

Depuis la v0.155.0, les pipelines longs streament leurs intermédiaires
sur disque au lieu de les tenir en RAM. Le volume n’est pas anodin et
**croît avec pixels × dates** : ~800 Mo mesurés pour une AOI de 0,89 Mpx
sur 115 dates, mais de l’ordre de la **dizaine de Go à l’échelle d’un
département**. Or [`tempdir()`](https://rdrr.io/r/base/tempfile.html)
vit souvent sur une petite partition racine — ou sur un tmpfs,
c’est-à-dire *en RAM*, ce qui annulerait tout le bénéfice.

`scratch_dir(subdir = NULL)` résout l’emplacement dans cet ordre :

1.  `options(nemeton.scratch_dir = "/data/scratch")`
2.  la variable d’environnement `NEMETON_SCRATCH_DIR`
3.  [`tempdir()`](https://rdrr.io/r/base/tempfile.html) (défaut,
    comportement inchangé)

[`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
l’utilise pour ses stacks de features, et **avertit avant de commencer**
quand l’espace libre est manifestement insuffisant (estimation
volontairement conservatrice), plutôt que de mourir sur un disque plein
à mi-parcours. L’avertissement est consultatif : il n’interrompt jamais
un run, et reste silencieux là où l’espace libre n’est pas lisible.

## nemeton 0.155.0 (2026-07-13)

#### Added — RECONFORT : le sous-processus IOTA2 tourne sous plafond mémoire

Un job qui déborde ne doit pas emporter la session. Sans plafond, un
dépassement du sous-processus IOTA2 ne le fait pas échouer *lui* : c’est
`systemd-oomd` qui tue **tout le scope applicatif** par pression mémoire
— le 2026-07-13, RStudio (22 process), l’application et les terminaux
sont partis ensemble.

`.reconfort_run_py()` lance désormais `conda run … python` dans un
**cgroup transitoire plafonné**
(`systemd-run --user --scope --property=MemoryMax=…`). Un dépassement
tue le sous-processus **seul** ; le pipeline remonte alors une erreur R
normale (`RECONFORT map production failed …`), et la session survit.

- Plafond par défaut : **70 % de la RAM** (21 Go sur une machine de 31
  Go), de quoi laisser le bureau sous le seuil de pression d’`oomd`.
- `options(nemeton.reconfort_memory_max = "12G")` pour forcer une valeur
  ; `FALSE` désactive le plafond.
- **Sans effet là où systemd n’est pas disponible** (non-Linux,
  conteneur sans bus utilisateur, CI) : la commande est alors lancée
  telle quelle, sans erreur.

Validé en réel (zone 9, S2 2025) : scope plafonné à 21 Go créé par le
cœur, run complet, statut `completed`, 546 s, cartes finales produites.

Brief associé pour l’app :
`specs/008-suivi-sanitaire/brief-nemetonshiny.md` (présenter l’OOM comme
un échec de tâche ordinaire, ne pas retenir les rasters du projet en
mémoire).

#### Changed — allègement mémoire des runs (pic RECONFORT : 11,3 Go → 6,5 Go)

Audit de l’empreinte mémoire du code R dans les pipelines longs. Mesuré
en réel sur le run RECONFORT zone 9 / S2 2025 : **pic 11,3 Go → 6,5
Go**, run complet, cartes finales identiques.

**Cause systémique** — aucun appel `terra` du cœur n’utilisait
`filename=`, et aucun
[`terraOptions()`](https://rspatial.github.io/terra/reference/terraOptions.html)
n’était posé. Par défaut `terra` matérialise en RAM jusqu’à **60 % de la
mémoire totale de la machine** (totale, pas libre : rien ne tient compte
du sous-processus IOTA2/FORDEAD qui tourne à côté). `.onLoad()` (nouveau
`R/zzz.R`) pose désormais `memfrac = 0.25` ; réglable via
`options(nemeton.terra_memfrac = …)`.

**Trois postes lourds réécrits** :

- `.build_reconfort_feature_stacks()` gardait les N dates × 2 stacks en
  mémoire (~6 Go pour 100 dates sur une AOI 2000×2000) et appelait
  [`terra::values()`](https://rspatial.github.io/terra/reference/values.html)
  trois fois par scène pour le masquage SCL. Chaque date est maintenant
  streamée sur disque (seuls les chemins sont conservés) et le masquage
  passe par
  [`terra::mask()`](https://rspatial.github.io/terra/reference/mask.html).
  Les intermédiaires sont nettoyés dès le bundle écrit.
- [`.compute_first_dieback_date()`](https://pobsteta.github.io/nemeton/reference/dot-compute_first_dieback_date.md)
  tenait **trois copies** du même tableau (R `values`, R `array`, tas
  Python). Le buffer numpy est rempli couche par couche : une seule
  copie. Équivalence numérique vérifiée sur grille non carrée (écart max
  0).
- `.trend_fit_cells()` (Theil-Sen/Mann-Kendall) empilait `D`, `sweep(D)`
  et `sign(D)` — trois matrices identiques. Découpé en blocs de pixels
  (lignes indépendantes) et débarrassé de ses temporaires. Résultat
  **identique au bit près** (NA hétérogènes, ex æquo, séries plates).

**Divers** : `.raster_is_empty()` (via
[`terra::global()`](https://rspatial.github.io/terra/reference/global.html))
remplace `all(is.na(terra::values(x)))` sur 3 sites — ces tests
matérialisaient un raster entier pour répondre à un booléen ;
`filename=` sur deux
[`terra::app()`](https://rspatial.github.io/terra/reference/app.html)
dont l’écriture suivait ; deux rasters relus alors qu’ils étaient déjà
en RAM (`validation_sampling.R`) ;
[`rm()`](https://rdrr.io/r/base/rm.html) +
[`gc()`](https://rdrr.io/r/base/gc.html) des stacks dès leur dernier
usage.

#### Added — `format_duration()` : les durées mènent par l’heure, puis la minute

Nouvelle fonction exportée `format_duration(sec, with_seconds = TRUE)`.
Une durée affichée commence toujours par sa plus grande unité utile : un
run de deux heures se lit **`2 h 00 min 43 s`**, jamais `7243 s`.

Deux messages du cœur affichaient des secondes brutes et sont corrigés :

- `run_fordead_diagnostic()` — « …persisted in **2 h 00 min 43 s** » (au
  lieu de `7243 s`) ;
- le pipeline lasR — « lasR done in **1 h 22 min 18 s** » (au lieu de
  `4938 s`).

Les **champs de données** (`duration_sec`, `elapsed_sec`,
`run_meta.json`) restent en secondes brutes : ce sont des valeurs
lisibles par machine, pas des messages.

L’app porte le même défaut sur 4 notifications (RECONFORT/FORDEAD
terminés) et duplique deux formateurs locaux ; elle doit consommer
[`format_duration()`](https://pobsteta.github.io/nemeton/reference/format_duration.md)
— cf. §5 du brief.

## nemeton 0.154.1 (2026-07-13)

#### Fixed — RECONFORT : la classification ne fait plus tomber la session (OOM)

Un diagnostic RECONFORT sur une UGF de 930×952 pixels faisait culminer
la classification IOTA2 **au-delà de 20 Go**, assez pour que
`systemd-oomd` tue la session R entière — RStudio, l’application et les
terminaux avec (incident du 2026-07-13, pic mesuré à 26 Go avec l’app
par-dessus).

La cause est un défaut d’IOTA2 (`image_classifier.py`) : le masque de
région n’est découpé sur le bloc courant que sous
`if classif_paths.classif_mask and targeted_chunk:`. Or `targeted_chunk`
est l’**indice** du bloc, et `0` est *falsy* en Python — le bloc 0, et
lui seul, gardait un masque pleine taille, ce qui faisait avorter OTB («
BandMathImageFilter: Input images must have the same dimensions »). Le
pipeline contournait en forçant `number_of_chunks = 1`, seule valeur où
les dimensions coïncident par accident… au prix de matérialiser toute la
pile de features multi-dates d’un coup.

- `repair_iota2_env.sh` corrige le défaut (**\#11**, comme
  [\#9](https://github.com/pobsteta/nemeton/issues/9) pandas et
  [\#10](https://github.com/pobsteta/nemeton/issues/10) `task_launcher`)
  : idempotent, avec sauvegarde du fichier d’origine.
- [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  calcule désormais `number_of_chunks` sur la hauteur du raster découpé
  (~240 lignes par bloc, soit 4 blocs pour 930×952) au lieu de forcer
  `1`. Sur un env non patché, le défaut est **détecté**, le run retombe
  sur un bloc unique et **avertit** explicitement (pic \> 20 Go, lancer
  `repair_iota2_env.sh`).

Validé en réel sur la zone 9 (S2 2025) : run complet, 10/10 phases,
**pic à 11,3 Go contre \> 20 Go**, cartes finales produites.

## nemeton 0.154.0 (2026-07-12)

#### Changed — carte bivariée : quinconce 5×5 en **bornes absolues** (couleurs « L’IF n°49 »)

[`eobs_downscale_bivariate()`](https://pobsteta.github.io/nemeton/reference/eobs_downscale_bivariate.md)
passe d’un croisement **3×3 (9 classes)** à un **5×5 (25 classes)**,
avec les couleurs **échantillonnées directement sur la figure de
référence « L’IF n°49 » (Copernicus E-OBS)**. La référence est un
dégradé continu (mesuré : un pixel = une couleur) ; le 5×5 en restitue
la nuance (jaune → olive → violet → rouge → magenta). Schéma : la
température domine (lignes chaudes rouge/magenta), frais & sec = jaune,
frais & humide = violet, chaud & sec = rouge, chaud & humide = magenta.

- **Classification en bornes ABSOLUES fixes ancrées sur 0** (et non en
  quantiles de l’emprise) — comme L’IF n°49 : les couleurs sont
  **comparables d’un projet à l’autre** et « rouge » = un
  réchauffement + assèchement *absolus*, pas un rang interne. Défauts :
  T°max `c(0, 0.4, 0.8, 1.2)` °C/déc, précip `c(-80, -40, 0, 40)` mm/déc
  (surchargeables via `breaks`). Un massif uniformément chaud & sec
  ressort donc quasi unicolore — c’est la réalité, là où les quantiles
  fabriquaient un faux contraste.
- `classe_bivariee = (classe_tmax-1)*5 + classe_precip`, **1-25**.
- Helper `.eobs_ds_classN_rast()` (classification N-classes sur bornes
  données).
- `meta$palette` porte désormais `classes` 1-25, 25 `colors`/`labels` et
  **`ncol = 5`** : l’app rend une **légende en carré bivarié 5×5** (pas
  une liste de 25 lignes). `breaks` (si fourni) attend **4 bornes** par
  axe.
- `meta$palette$zero` = `list(tmax, precip)` : position fractionnaire
  \[0,1\] de la **tendance nulle** sur chaque axe (ou `NA` si 0 hors des
  bornes) — pour tracer les **pointillés blancs 0/0** de la figure de
  référence. Avec les bornes absolues par défaut, 0 est une borne :
  ligne T°max à **0.2** (bas, réchauffement quasi général) et ligne
  précip à **0.6** (helper `.eobs_ds_zero_pos`).
- Palette pilotée par les données : l’app lit
  `pal$colors`/`labels`/`ncol`. Brief app mis à jour
  (`brief-nemetonshiny-eobs-context-dem` §8).

## nemeton 0.153.2 (2026-07-12)

#### Fixed — gel R7 : MNT parcellaire → auto-source du MNT régional (voie meteoland/SAFRAN)

Le moteur « gelées tardives » (R7) se skippait proprement (« Tmin
indisponible ») sur les projets à MNT parcellaire :
[`meteoland_daily_grid()`](https://pobsteta.github.io/nemeton/reference/meteoland_daily_grid.md)
échouait sur `too few SAFRAN pseudo-stations`. Cause : le MNT sert **à
la fois** de source d’altitude des pseudo-stations SAFRAN (mailles ~8 km
sur AOI + buffer) **et** de grille cible.
[`build_safran_stations()`](https://pobsteta.github.io/nemeton/reference/build_safran_stations.md)
écarte toute pseudo-station hors emprise MNT (`elevation` NA) ; un MNT
LiDAR ~4-5 km ne couvre qu’une poignée de mailles sur un buffer de 25 km
→ `< min_stations` → abort. Même symptôme que le KED sur MNT trop petit
(déjà corrigé en v0.152.0).

- Nouveau helper interne `.meteoland_resolve_dem()` : compte les mailles
  SAFRAN couvertes par le MNT fourni ; si `< min_stations`,
  **auto-source un MNT régional grossier (WMS IGN, 250 m)** couvrant le
  buffer et le réutilise pour les altitudes *et* la grille. Réutilise
  `.eobs_ds_autoscale_dem()` / `.eobs_ds_download_ign_dem()` de la voie
  KED (court-circuit CRS identique, aucun warp inutile).
- Câblé dans
  [`meteoland_daily_grid()`](https://pobsteta.github.io/nemeton/reference/meteoland_daily_grid.md)
  (voie R7, sans repli auparavant → skip dur) **et** dans
  `eobs_downscale(engine = "meteoland")` (le downscaling T°max tourne
  désormais réellement via meteoland au lieu de dégrader silencieusement
  au KED).
- Signatures publiques inchangées ; comportement préservé quand le MNT
  couvre déjà le buffer (aucun téléchargement). 3 tests de
  non-régression.

#### Changed — carte bivariée : classe centrale « Stable » lisible sur satellite

La classe centrale 5 « Stable » (T°max et précipitations dans leur
tertile médian) passe du gris pâle `#C9C9C9` à un **neutre taupe soutenu
`#A79E8C`**. Le gris pâle rendu en semi-transparence sur le fond
satellite se lisait comme un trou de données alors que c’est une classe
pleine (souvent la plus peuplée) ; le taupe se lit comme une couleur à
toute opacité. Aucun trou réel n’existait : le masque NA de la bivariée
est identique à celui des couches tx/rr.

## nemeton 0.153.1 (2026-07-12)

#### Fixed — diagnostic RECONFORT : AOI à anneau dégénéré (sommet dupliqué)

Le diagnostic RECONFORT échouait à l’étape *tiles* \[4/10\] quand la
zone du projet portait un anneau **dégénéré** (sommet consécutif
dupliqué) :
[`reconfort_aoi_tiles()`](https://pobsteta.github.io/nemeton/reference/reconfort_aoi_tiles.md)
résout l’emprise contre la grille MGRS **GeoJSON (EPSG:4326)**, donc
`st_union`/`st_intersects` passent par **s2**, qui rejette la boucle
invalide
(`Loop N is not valid: Edge M is degenerate (duplicate vertex)`) et
interrompt tout le run. Le chemin indicateurs (intersection BD Forêt,
`utils.R`) réparait déjà ce cas ; la résolution des tuiles ne le faisait
pas.

- [`reconfort_aoi_tiles()`](https://pobsteta.github.io/nemeton/reference/reconfort_aoi_tiles.md)
  : réparation
  [`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html) +
  réessai unique quand la résolution brute échoue (même idiome que
  l’intersection BD Forêt) ; le coût de réparation n’est payé qu’en cas
  d’échec.
- [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  : l’AOI de zone est rendue valide **une fois à la source** (juste
  après
  [`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md)),
  pour que le masque, le clip de scène et les points de vérité terrain
  en aval reçoivent tous une géométrie valide (les ops planaires
  GEOS/terra toléraient déjà le sommet dupliqué, seule l’étape s2
  bloquait).
- Test de non-régression : AOI à sommet dupliqué sur le Loiret → résout
  bien ses tuiles S2 sans interruption.

## nemeton 0.153.0 (2026-07-12)

#### Added — `eobs_downscale(var = "rr")` + carte bivariée fine T°max × précipitations

Complète le contexte régional E-OBS avec la **2ᵉ variable**
(précipitations) et la **carte bivariée** de la figure « L’IF n°49 »
(Copernicus E-OBS), mais à la **résolution du contexte (UGF)** au lieu
du semis E-OBS grossier (brief `brief-nemeton-eobs-downscale-rr`).

- **`eobs_downscale(var = "rr")`** — les précipitations passent par le
  **même pipeline KED** que `tx` (n’est plus `out_of_scope`).
  Spécifiques `rr` : `unit = "mm/decade"`,
  `value_label = "Tendance précipitations estivales"`,
  `meta$reliability = "low"` (relation pluie↔︎altitude
  bruitée/orographique) et **palette `sense = "dry_unfavorable"`** (une
  tendance négative = assèchement = défavorable → bas = rouge, distinct
  du `hot_unfavorable` de `tx`). `rr` ignore `engine = "meteoland"`
  (température seule) et tourne en KED. `meta` gagne `reliability` pour
  les deux variables.
- **`eobs_downscale_bivariate(tx, rr, …)`** (nouvel export) — downscale
  les deux tendances puis les **croise en classes 1-9** (tertiles ou
  `breaks` fixes ; `(classe_tmax-1)*3 + classe_precip`, **chaud & sec =
  7 = rouge**, frais & humide = 3 = bleu — même codage que
  [`tendances_estivales_eobs()`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)).
  Retourne un `SpatRaster` entier `classe_bivariee` + `meta$palette` (9
  couleurs/libellés, `sense = "bivariate"`) + `meta$breaks` + les métas
  composantes `tx`/`rr`. MNT de contexte auto-sourcé partagé (WMS IGN).

Contrat `list(raster, meta)` inchangé. Brief app :
`specs/027-regeneration-microclimat/brief-nemetonshiny-eobs-context-dem.md`
(mis à jour : 2ᵉ couche rr + sélecteur + carte bivariée).

## nemeton 0.152.0 (2026-07-12)

#### Added — MNT de contexte auto-sourcé + robustesse CRS pour `eobs_downscale()`

Débloque la carte « contexte régional E-OBS » quand le MNT fourni est à
l’échelle parcelle (brief `brief-nemeton-eobs-downscaling-dem`). Le KED
extrait les covariables terrain **aux points E-OBS** : un MNT ~4–5 km ne
recouvre qu’~1 maille E-OBS (~11 km) → `status = "insufficient_data"`
(`n_points = 1`) malgré un buffer 25 km.

- **Auto-sourcing du MNT (option A1)** — `dem` devient **optionnel**.
  Quand il est `NULL`, ou trop petit pour couvrir le buffer,
  [`eobs_downscale()`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md)
  télécharge une **élévation grossière** sur `st_buffer(aoi, buffer_m)`
  depuis le **WMS IGN Géoplateforme**
  (`ELEVATION.ELEVATIONGRIDCOVERAGE`, France, sans auth), à
  `context_res_m` (défaut 250 m — un contexte régional n’a pas besoin de
  plus, la grille est bornée à `max_cells`). Validé en réel : `n_points`
  passe de 1 à 33, `status = "ok"`. `meta$dem_source` = `"provided"` /
  `"autoscaled"` / `"autoscaled_small_dem"`.
- **Décision « MNT trop petit » directe** — le MNT n’est jugé
  insuffisant que si le buffer contient assez de mailles E-OBS
  (`≥ min_points`) mais que son emprise n’en couvre pas assez ; si le
  buffer lui-même est trop pauvre (buffer minuscule), auto-sourcer ne
  sert à rien et le KED renvoie `too_few_cells`.
- **Robustesse CRS** — un `eobs` sans CRS est désormais interprété en
  **EPSG:4326** (E-OBS est toujours en lon/lat) avec avertissement, au
  lieu de faire chuter `n_points` à 0 en silence.
- **Replis lisibles** — `meta$reason` distingue
  `eobs_downscale_dem_too_small`, `eobs_downscale_no_dem` et
  `eobs_downscale_too_few_cells`.

Contrat de sortie `list(raster, meta)` **inchangé** (l’app câble déjà
dessus) ; `meta` gagne seulement `dem_source`. Brief app : le rendu
`addRasterImage` + opacité se branche dès `status = "ok"`.

## nemeton 0.151.0 (2026-07-12)

#### Added — moteur meteoland réel + Tmin journalier alimentant R7 (chantier microclimat P4)

Concrétise le rail `engine = "meteoland"`
d’[`eobs_downscale()`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md)
(jusqu’ici un stub qui retombait sur KED) et ferme la boucle de données
réelles de R7. **Validé de bout en bout sur meteoland 2.2.7** : CRS
Lambert-93 natif accepté, pipeline `create_meteo_interpolator()` →
`interpolate_data()` → `summarise_interpolated_data()` → `terra`.

- **`eobs_downscale(engine = "meteoland")`** interpole désormais
  réellement les séries SAFRAN journalières (pseudo-stations) sur la
  grille MNT, agrège chaque été en Tmax annuel, puis réduit à la
  statistique demandée — **même contrat de sortie que KED**. Nouveaux
  arguments opt-in `calibrate` (calibration LOO meteoland) et `cv`
  (validation croisée → `meta$cv = list(r2, mae_tmin, mae_tmax)`,
  confiance ≈ NDP 1). En l’absence de meteoland / GéoSAS / densité
  suffisante → repli KED, jamais d’erreur.
- **`meteoland_daily_grid(aoi, dem, years, variable = "MinTemperature", …)`**
  (nouvel export) — produit le **raster Tmin journalier** (couche/jour,
  [`terra::time()`](https://rspatial.github.io/terra/reference/time.html)
  posé, CRS du MNT) qui alimente `indicateur_r7_gel(tmin = …)` sur
  données réelles. `NULL` propre si indisponible.
- **Paramètres SAFRAN Tmin/Tmax** — `.biljou_forcing_safran()` accepte
  un jeu de variables ;
  [`build_safran_stations()`](https://pobsteta.github.io/nemeton/reference/build_safran_stations.md)
  demande le jeu meteoland incluant les noms EXACTS lus dans l’EDR
  `safran-isba` (`TINF_H_Q`/`TSUP_H_Q`, min/max des 24 T° horaires — pas
  les `TINF_Q` supposés dans le brief).
- **Contrat `meta$cv`** ajouté aux deux moteurs (`NULL` en KED).

Brief app associé :
`specs/027-regeneration-microclimat/brief-nemetonshiny-r7-gel-microclimat-p4.md`.

## nemeton 0.150.0 (2026-07-11)

#### Added — indicateur R7 gel tardif + rail SAFRAN du moteur meteoland (chantier microclimat P4)

Deux briques du chantier microclimat P4 (`brief-meteoland-safran-p4`).

**`indicateur_r7_gel(units, tmin = NULL, …)`** — nouvel indicateur **R7,
risque de gel tardif** (famille R étendue R1…R7). Croise une série de
température **minimale journalière** (`tmin`, du downscaling
meteoland/SAFRAN ou d’une source Tmin directe) avec le débourrement, et
compte les gelées printanières post-débourrement — déterminant d’échec
de régénération (chêne, hêtre, douglas). Conditionnel comme R5 (FORDEAD)
/ R6 (microclimf) : sans `tmin`, R7 = NA / skip. Sens R1-R4/R6 (**haut =
faible risque**), pas d’inversion (≠ R5). Radar : la regex `^R[0-9]`
capte R7 automatiquement, pas de 13e axe.

**`build_safran_stations(aoi, buffer_m, years, dem, …)`** — grille de
**pseudo-stations SAFRAN** pour le moteur meteoland
d’[`eobs_downscale()`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md).
SAFRAN est une réanalyse ~8 km : chaque maille = une pseudo-station
(série journalière + altitude MNT), ce qui suffit à meteoland. Réutilise
l’acquisition GéoSAS déjà écrite pour BILJOU (`.biljou_forcing_safran`)
— pas de source neuve. Écarte les pseudo-stations sans série ou sans
altitude.

**Moteur `eobs_downscale(engine = "meteoland")`** : construit désormais
les stations SAFRAN et borne la densité, mais **l’interpolation
meteoland elle-même reste différée** (validation sur données réelles,
patron microclimf — meteoland n’est ni exécutable en CI ni ici de façon
significative). Le moteur retombe proprement sur KED
(`engine_fallback = TRUE`), contrat de sortie inchangé. Le `meta` gagne
un slot `cv` (validation croisée LOO, rempli par meteoland ; `NULL` en
KED).

Suggests : `stars` ajouté (grille meteoland). CLAUDE.md : famille R mise
à jour (R6 + R7). Le numéro est à reporter dans le plancher `Imports` de
`nemetonshiny`.

## nemeton 0.149.0 (2026-07-11)

#### Added — downscaling E-OBS en raster fin (`eobs_downscale`)

Nouvelle fonction cœur (brief `brief-nemeton-eobs-downscaling`) :
transforme la grille grossière E-OBS (~0,1°, ~11 km) en un `SpatRaster`
fin sur le contexte régional du projet, avec le MNT et des dérivées de
terrain en covariables. Cible la carte « Contexte régional (E-OBS) » de
l’onglet reGénération (rendu raster + curseur d’opacité, comme
FORDEAD/FAST) ; **ne duplique pas**
[`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
(précision parcellaire microclimf + LiDAR HD).

**v1 : `tx` (température maximale) uniquement** — signal altitudinal
fort et physiquement fondé (~ -0,6 °C/100 m). `rr` (précipitations)
**hors scope** (downscaling peu fiable ; le MNT n’aide qu’en montagne) :
`var = "rr"` renvoie un statut, pas un raster.

**Deux moteurs, un seul contrat de sortie** (brief microclimat §8,
`engine =`) : - `"ked"` (défaut) — **régression-krigeage** : réduction
E-OBS → dérive `lm(valeur ~ dem [+ slope + northness + twi])` → krigeage
des résidus (variogramme auto via `automap`, sinon modèle sphérique
`gstat`) → dérive + résidus krigés sur la grille MNT. Sans `gstat`, ou
avec trop peu de mailles, la fonction **dégrade en `trend_only`**
(dérive seule) — un repli demandé, jamais une erreur. - `"meteoland"` —
l’interpolateur station-based (chantier microclimat P4). meteoland
interpole des **séries journalières** : downscaler une tendance déjà
réduite exige une refonte per-année, livrée séparément. En attendant, et
quand meteoland est absent, ce moteur **retombe sur KED** (contrat de
sortie identique — l’app ne teste jamais le moteur).

`meta` fige le contrat que l’app rend : `status`, `engine`, `method`,
`crs` (EPSG, CRS du MNT), `unit` (`"°C/decade"`), `value_label`,
`palette` (`low`/`high` + `sense = "hot_unfavorable"`, haut = plus chaud
= rouge), `n_points`. Garde-fous : grille bornée (`max_cells`, défaut
5e5 — jamais de gigapixel), cache `.tif` optionnel, dégradation propre
si \< 3 mailles.

L’exposition brute est entrée comme **northness** (`cos(aspect)`) :
l’aspect circulaire en degrés n’a aucun sens en régression linéaire.

Dépendances (Suggests, chargées à l’usage) : `gstat`, `automap`,
`meteoland`. Numéro à reporter dans le plancher `Imports` de
`nemetonshiny` avant câblage.

## nemeton 0.148.0 (2026-07-10)

#### Added — verrou de projet pour usage serveur multi-utilisateurs

Nouvelle API cœur (brief `brief-core-project-lock`), consommée par
`nemetonshiny` déployé en serveur multi-utilisateurs : **un projet
ouvert est verrouillé en édition sur un seul utilisateur ; les autres
l’ouvrent en lecture seule**. Quatre fonctions exportées, prenant une
connexion `con` fournie par l’appelant, fonctionnant sur PostgreSQL
(cible serveur) comme sur SQLite (local/test) :

- **`project_lock_acquire(con, project_id, holder_id, holder_label, ttl_seconds)`**
  — prend le verrou si le projet est libre, déjà tenu par le même
  `holder_id` (ré-entrant), ou périmé (heartbeat plus vieux que
  `ttl_seconds` → vol, signalé par `stolen = TRUE`). Refus si un autre
  détient un verrou frais. La décision tourne dans une transaction avec
  verrou de ligne (`FOR UPDATE` sur PostgreSQL) : deux acquisitions
  concurrentes sur un projet libre → exactement un gagnant.
- **`project_lock_heartbeat(con, project_id, holder_id)`** — rafraîchit
  le heartbeat si `holder_id` tient toujours le verrou.
- **`project_lock_release(con, project_id, holder_id)`** — libère si
  détenteur ; idempotent.
- **`project_lock_status(con, project_id, ttl_seconds)`** — `NULL` si
  libre, sinon détenteur + `stale` (distingue libre / tenu-frais /
  tenu-périmé).

Verrou **matérialisé en table** (`project_lock`, migration 0008) et non
`pg_advisory_lock` : l’app ouvre/ferme sa connexion par opération, un
advisory lock lié à la connexion serait relâché aussitôt. La péremption
est évaluée à la lecture contre l’horloge de la base
(`now() - heartbeat_at > ttl`) — aucune colonne d’expiration, aucun job
de nettoyage.

Le numéro de release est à reporter dans le plancher `Imports` de
`nemetonshiny` avant câblage de l’API.

## nemeton 0.147.3 (2026-07-10)

#### Fixed — ERA5 : rayonnement négatif transmis à microclimf et à BILJOU

Run réel du 2026-07-10 (projet `20260701_204501_ltcp`) : l’onglet
reGénération affiche l’avertissement

> `microclimf: -0.0448426522703349 outside range of typical shortwave radiation values. Units should be W / m^2`

ERA5 stocke le rayonnement et la précipitation en **cumuls** ; la
dé-accumulation opérée par `mcera5` produit de minuscules valeurs
négatives là où le flux est nul (la nuit, pour le rayonnement solaire).
C’est un artefact numérique, pas un signal — mais
[`microclimf::checkinputs()`](https://rdrr.io/pkg/microclimf/man/checkinputs.html)
le signale, et rien ne le bornait.

`.rsen_forcage_era5()` borne désormais à zéro les colonnes non négatives
par construction physique (`swdown`, `difrad`, `precip`) via le nouvel
helper `.rsen_clamp_flux()`, qui informe du nombre de valeurs corrigées.

Le correctif protège **deux** chemins : le même forçage alimente BILJOU
par `.biljou_forcing_era5()`, où un `swdown` négatif se propage dans
`rg` puis dans `penman_pet()`. Les colonnes qui peuvent légitimement
être négatives (`temp`) ou qui ne le sont jamais en pratique (`lwdown`)
ne sont pas touchées ; les `NA` sont préservés.

Aucun changement de contrat. 5 nouveaux tests.

## nemeton 0.147.2 (2026-07-10)

#### Fixed — CI rouge après la v0.147.0 (tests + pkgdown)

Deux oublis de la spec 035, sans effet sur le code du package :

- **`test-regen-per-unit.R`** : le test « accepts a path to a raster »
  écrit un GeoTIFF, or certains runners GitHub Actions ont une anomalie
  `terra` sur `writeRaster(crs = "EPSG:nnnn")`. Le repo a un garde-fou
  dédié (`skip_if_terra_write_broken()`, `helper-fast-raster.R`) ; le
  test l’ignorait et faisait échouer le job `tests` (et `coverage`). Il
  l’appelle désormais : skip sur runner cassé, exécution complète sur
  runtime sain.
- **`_pkgdown.yml`** : les trois fonctions exportées par la v0.147.0
  (`awc_saxton_rawls`, `ewm_depuis_soilgrids`, `lai_max_depuis_pai`)
  n’étaient pas référencées dans l’index de la doc, ce qui fait échouer
  `build_reference_index()`. Ajoutées à la section reGénération.

Aucun changement de comportement. `R-CMD-check` et `version-consistency`
passaient déjà.

## nemeton 0.147.1 (2026-07-10)

#### Fixed — `build_foret_ancienne_mask()` : `%in%` résolvait vers `base`, pas `terra`

`build_foret_ancienne_mask(source = <SpatRaster>, forest_class = )`
échouait sur
`unable to find an inherited method for function 'ifel' for signature test = "logical"`.
Le package n’importe pas l’opérateur `%in%` de **terra** : un
`r %in% forest_class` non préfixé résolvait donc vers
`base::`%in%\``(fondé sur`match()`), qui renvoie un`logical`et non un`SpatRaster`—`terra::ifel()\`
n’a pas de méthode pour ça.

L’appel est désormais explicitement préfixé
(`terra::`%in%`(r, forest_class)`), comme le reste du fichier. Les trois
tests de `test-foret-ancienne-mask.R` qui erroraient s’exécutent enfin
(18 pass / 3 erreurs → **25 pass / 0 erreur**).

Bug préexistant, indépendant de la spec 035 ; surfacé par la suite
complète lancée pour la v0.147.0.

## nemeton 0.147.0 (2026-07-10)

#### Added — bilan hydrique spatialisé par UGF (spec 035)

[`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
renvoyait **la même valeur pour toutes les UGF** (constaté sur 30 UGF
réelles : `njstress` = 142,5 j partout). Cause : BILJOU n’a aucun terme
spatial — `biljou_run_grid()` ne recopie `lon`/`lat` qu’en métadonnées,
et `biljou_run()` est une fonction pure de
`(meteo, soil, lai_max, forest_type, …)`. Or le sol était uniforme, le
`lai_max` scalaire, et la maille SAFRAN fait 8 km. Trois nouvelles
fonctions exportées rendent le sol et le LAI variables par UGF — les
deux seules variables qui *doivent* varier à l’échelle de gestion.

- **`awc_saxton_rawls(clay, sand, om, coarse)`** — fonction de
  pédotransfert de Saxton & Rawls (2006), R pur, sans dépendance.
  Réserve utile volumique (m³/m³) à partir de la texture et de la
  matière organique, corrigée des éléments grossiers.
- **`ewm_depuis_soilgrids(units, rooting_depth_cm, …)`** — `ewm` (mm)
  par UGF, intégrée sur la profondeur d’enracinement depuis SoilGrids
  250 m (ISRIC, CC-BY-4.0). Dégradation propre (`NULL`) si la source est
  injoignable.
- **`lai_max_depuis_pai(units, pai, probs = 0.9)`** — `lai_max` par UGF
  depuis le PAI LiDAR caché (`pai.tif`). Percentile 90 et non moyenne :
  `biljou_lai()` traite `lai_max` comme le **plateau** de la phénologie,
  qu’une moyenne zonale sous-estime.
- **`build_biljou_soil(source = "soilgrids")`** — retourne désormais une
  liste d’objets `biljou_soil` nommée par id d’UGF. `source = "uniform"`
  (défaut) reproduit le comportement v0.146.x.
- **30 sources `soilgrids_{clay,sand,silt,soc,cfvo}_{profondeur}`**
  déclarées dans `inst/datasources/FR.json` (VRT tuilés
  `files.isric.org`, facteurs d’échelle vérifiés dans la FAQ ISRIC —
  `soc` est en **dg/kg**, donc `%OC = brut/100`).

#### Fixed — garde-fou per-UGF : un vecteur n’est pas une liste

`biljou_run_grid()` n’indexe que les **listes** (`as_fun()` :
`is.list(x) && !is.data.frame(x) && !inherits(x, "biljou_soil")`). Un
vecteur numérique tombait dans la branche `function(id) x` et partait
**entier** à chaque point. Vérifié : sur résineux, `biljou_lai()`
produit alors une série de `n × ndays` valeurs et le LAI des UGF
**défile jour après jour**, sans erreur ni warning — corruption
silencieuse. Sur feuillu, seul `x[1]` était retenu.

[`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
convertit désormais tout vecteur per-UGF en liste nommée par id, et
**refuse** une longueur qui n’est ni 1 ni `nrow(units)`. La doc
annonçait déjà ce contrat ; le code ne l’honorait pas.

#### Notes

- **Le TWI ne dérive pas l’`ewm`** (spec 035, décision D1) : indice de
  convergence latérale, pas capacité de stockage ; BILJOU est un modèle
  1D ; et le TWI alimente **déjà**
  [`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md)
  en direct — l’y faire entrer par `ewm → BILJOU → njstress → R3`
  créerait un double comptage.
- **PTF Saxton & Rawls plutôt que Tóth et al. 2015** : cette dernière
  n’est pas en forme close (modèles `euptf`), pour un gain non mesuré à
  250 m.
- ⚠ Plusieurs transcriptions en ligne de Saxton & Rawls donnent `-0.002`
  au lieu de `-0.02` et `-0.15` au lieu de `-0.015`. Ces variantes
  produisent une capacité au champ **négative** pour un sable. Les
  constantes publiées sont verrouillées par un test dédié.

Vérifié de bout en bout avec le vrai moteur : `njstress` passe de 1 à 3
valeurs distinctes sur 3 UGF, et l’UGF au sol/LAI de référence reproduit
exactement la valeur v0.146.x.

## nemeton 0.146.5 (2026-07-09)

#### Fixed — grille microclimf bornée mémoire (OOM après le PAI)

Run réel : le PAI est passé (fix 0.146.3), `pai.tif` écrit, **puis
`systemd-oomd` a de nouveau tué le scope** — cette fois pendant le
calcul microclimf. Cause :
[`microclimf::runmicro()`](https://rdrr.io/pkg/microclimf/man/runmicro.html)
alloue des tableaux `ncellules × pas_de_temps × ~11 sorties` ; à `res`
fine (2 m) sur un massif entier (**1905×1792 ≈ 3,4 M cellules**), cela
dépasse des dizaines de Go. Le test e2e de 0.146.2 tournait sur 30×30
cellules, donc ce cas n’avait jamais été exercé.

- **La grille de calcul microclimf est désormais agrégée** pour garder
  son nombre de cellules `<= micro_max_cells` (nouveau paramètre de
  [`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md),
  défaut `5e4`, override `options(nemeton.micro_max_cells=)`). Sur 3,4 M
  cellules → facteur 9 → grille ~18 m (~42k cellules) → microclimf ~1 Go
  au lieu de dizaines.
- Le **PAI caché** (`pai_cache` / `pai.tif`) **reste à `res` fine** :
  seul le calcul microclimf est coarseé. Le signal microclimatique est
  lissé et seules des **moyennes par UGF** sont produites (ranking de
  sensibilité), donc l’agrégation est sans effet sur le résultat. Helper
  `.rsen_micro_agg_factor()`.

## nemeton 0.146.4 (2026-07-09)

#### Fixed — sélection du fichier ERA5 : repli indépendant de la locale

Le repli défensif de `.rsen_forcage_era5()` (quand le combiné n’est pas
détecté par suffixe) choisissait `list.files(...)[1]`, en supposant que
le combiné `era5_<annee>_<annee>.nc` trie avant les mensuels
`..._<mois>.nc` (‘.’ \< ’\_’). Or
[`sort()`](https://rspatial.github.io/terra/reference/sort.html) suit la
**locale** (en `fr_FR`, l’ordre peut différer de l’ASCII) : le repli
pouvait piocher un mensuel (1 mois au lieu de 12). La sélection passe
désormais par `.rsen_era5_src()`, qui prend le **nom le plus court** (le
combiné), via [`nchar()`](https://rdrr.io/r/base/nchar.html) —
indépendant de la locale. Chemin principal (détection par suffixe)
inchangé. Aucun renommage de fichier requis (les
`era5_<annee>_<annee>*.nc` existants sont correctement reconnus).

## nemeton 0.146.3 (2026-07-09)

#### Fixed — PAI LiDAR : concurrence par défaut bornée mémoire (OOM)

Le PAI parallèle
([`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md),
v0.146.0) processait
[`lasR::half_cores()`](https://rdrr.io/pkg/lasR/man/multithreading.html)
dalles COPC de front. Sur un run réel (25 dalles ≈ 38 Go décompressées,
machine 31 Go), 4 dalles simultanées ont saturé la RAM et
**`systemd-oomd` a tué le scope RStudio** (il tue à ~50 % de pression
mémoire soutenue) pendant la phase PAI — avant tout calcul microclimf,
donc aucune sortie. `half_cores()` aveugle est trop gourmand pour de
grosses dalles LiDAR.

- **Défaut `ncores = NULL` désormais borné mémoire** : budget ~6 Go par
  dalle concurrente sur 40 % de la RAM totale, plafonné par
  [`lasR::half_cores()`](https://rdrr.io/pkg/lasR/man/multithreading.html)
  (helpers `.pai_total_ram_gb()` / `.pai_mem_safe_ncores()`). Sur 31 Go
  → 2 dalles au lieu de 4. RAM inconnue → 2 (prudent).
- **Override sans passer par l’app** : quand `ncores` est `NULL`,
  `options(nemeton.pai_ncores = N)` ou l’env `NEMETON_PAI_NCORES` fixent
  la valeur (utile tant que l’app n’expose pas le curseur). `ncores`
  entier explicite ou `FALSE`/`1` (séquentiel) restent prioritaires et
  inchangés.

Le PAI est identique quel que soit `ncores` (comptage par cellule
associatif) : on échange seulement RAM contre temps.

## nemeton 0.146.2 (2026-07-08)

#### Fixed — moteur exposition : compatibilité microclimf 2.x (sortie `runmicro`)

Suite du débogage end-to-end (après le fix `soilparameters` de 0.146.1,
le calcul microclimf tournait mais plantait en aval). Trois correctifs,
validés par un run complet de
[`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
hors app sur le cache ERA5 réel :

- **`invalid 'trim' argument`.** microclimf 2.0.0 ne peuple plus
  `out$tme` (renvoyé vide) et ne pose pas
  [`terra::time()`](https://rspatial.github.io/terra/reference/time.html)
  sur la sortie de `runmicro()`. L’ancien garde
  `!is.null(terra::time(Tz))` passait à tort
  ([`time()`](https://rspatial.github.io/terra/reference/time.html)
  renvoie des `NA`, pas `NULL`) → `format(NA, "%m")` interprétait `"%m"`
  comme l’argument `trim`. Les mois d’été sont désormais lus depuis
  `mp$weather$obs_time` (modèle ponctuel sous-échantillonné, aligné 1:1
  aux couches), seule source fiable en microclimf 2.x.
- **`writeRaster` sur un “numeric”.** `max(Tz[[sel]], na.rm = TRUE)` sur
  un SpatRaster peut renvoyer un scalaire global (selon la version de
  terra) → écriture du raster d’été impossible. Réduction
  cellule-à-cellule explicite via `terra::app(..., "max")` /
  `terra::app(..., "mean")`.
- **`sensibilite = NaN` (cas dégénéré).** Le z-score inter-UGF divisait
  par `sd` : `NaN` pour une **seule UGF** (`sd` de longueur 1 = `NA`) ou
  un delta parfaitement uniforme (`sd = 0`). `z()` retourne désormais 0
  (pas de signal relatif) dans ces cas.

## nemeton 0.146.1 (2026-07-08)

#### Fixed — moteur exposition : microclimf 2.x (`soilparameters`) + cache ERA5

Deux correctifs qui débloquent le calcul microclimf de bout en bout
(diagnostiqués sur run réel RECONFORT, après que le fix 403 v0.145.1 a
permis d’atteindre l’étape microclimf) :

- **microclimf 2.0.0 : `object 'soilparameters' not found`.**
  `runpointmodel()` référence les datasets
  `soilparameters`/`soilparamsp` mais ne les charge pas (namespace
  verrouillé, pas de lazy-load interne) → le calcul microclimf plantait
  juste après le téléchargement ERA5, sans produire les rasters d’été
  (donc pas de `sensibilite.gpkg`).
  [`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
  les expose désormais dans l’environnement global le temps du run
  (helper `.rsen_ensure_soildata()`, idempotent), puis les retire
  (`on.exit`). Chaîne validée end-to-end
  (`runpointmodel → subsetpointmodel → runmicro`).
- **Cache ERA5 jamais réutilisé.** Le fichier combiné mcera5 s’appelle
  en réalité `era5_<année>_<année>.nc` (double année,
  `outfile_name = "era5_<année>"`), que le lookup
  `.rsen_era5_combined()` cherchait comme `era5_<année>.nc` → jamais
  trouvé → **re-téléchargement des 24 mois à chaque run** malgré le
  cache. Le combiné est désormais repéré par son suffixe `_<année>.nc`
  (robuste au préfixe), donc réutilisé.

## nemeton 0.146.0 (2026-07-08)

#### Added — PAI LiDAR parallèle par dalles (`ncores`, `concurrent_files`)

[`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)
gagne un argument `ncores` qui pilote le parallélisme **par dalles** de
`lasR` (`concurrent_files`) : `NULL` (défaut) traite
[`lasR::half_cores()`](https://rdrr.io/pkg/lasR/man/multithreading.html)
dalles de front, un entier `N` en traite `N`, `1`/`FALSE` force le
séquentiel. La stratégie `lasR` globale est **sauvegardée puis
restaurée** autour de l’exécution. Le PAI est **strictement identique**
quelle que soit la valeur (le comptage par cellule est associatif) —
c’est un pur gain de temps mural, au prix de RAM, sur un massif
multi-dalles.

Motivation : mesuré en run réel, la dérivation du PAI sur un nuage COPC
de 25 dalles / 4,7 Go tenait **\>1 h** en séquentiel (mono-thread).
`lasR` traite déjà les dalles en flux ; il ne posait **aucune**
stratégie parallèle. Avec le défaut (moitié des cœurs), on vise un gain
~linéaire (ex. 8 cœurs → ~4× plus rapide).
[`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
expose le réglage via `pai_ncores` (transmis à `ncores`) pour permettre
à l’app de le baisser si la RAM est limitée. Défaut rétro-compatible en
résultat (seule la vitesse change).

## nemeton 0.145.1 (2026-07-08)

#### Fixed — ERA5 du moteur exposition : requête mensuelle (régression CDS v0.143.0)

`.rsen_forcage_era5()` (chemin moteur de
[`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md))
repasse en **requêtes ERA5 mensuelles**
(`mcera5::build_era5_request(by_month = TRUE)`), fusionnées par `mcera5`
en un `era5_<année>.nc`. La v0.143.0 avait basculé en **une requête
annuelle** (`by_month = FALSE`) pour réduire le throttle CDS — mais une
année entière (365 j × 24 h × 12 variables ≈ 105 000 champs) **dépasse
la limite de coût par requête du nouveau CDS**, qui la rejette
immédiatement
(`403 — cost limits exceeded / "your request is too large"`).
Conséquence : plus **aucun** run microclimf n’aboutissait depuis la
v0.143.0 (échec ~53 s après la phase PAI, `microclimf/` auto-nettoyé,
jamais de `sensibilite.gpkg`). Chaque requête mensuelle (~9 000 champs)
reste bien sous la limite ; le retry/back-off (`.rsen_era5_with_retry`,
conservé) absorbe le throttle des appels mensuels.

Le cache est désormais indexé sur le **fichier combiné**
`era5_<année>.nc` (présence = complet), plus robuste que l’ancien
`list.files()[1]`. Diagnostiqué en run réel RECONFORT (rejet CDS
reproduit hors app : `403` en 3,5 s).

## nemeton 0.145.0 (2026-07-08)

#### Added — cache disque du PAI LiDAR dans `regen_sensibilite()` (`pai_cache`)

[`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
gagne un argument `pai_cache = NULL` (chemin GeoTIFF). Le PAI dérivé du
nuage LiDAR
([`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md))
est **le poste le plus long** avant ERA5 — sur un gros massif (nuage
COPC de plusieurs Go), la dérivation peut durer des dizaines de minutes.
Or le PAI ne dépend que du nuage et de la grille de travail :
**invariant** pour un projet / AOI / `res` donnés.

Avec `pai_cache` : si le fichier existe **et** que sa géométrie
correspond à la grille, le PAI est **relu du disque** (aucun recalcul) ;
sinon il est calculé puis écrit là. Un changement d’AOI ou de `res`
produit une géométrie différente → le cache est **invalidé** (recalcul +
réécriture), donc jamais de PAI périmé. L’événement `regen_expo:pai`
expose `source = "cache"` en plus de `"lidar"`/`"raster"` (l’app affiche
« PAI (cache) », phase quasi instantanée).

Rétro-compatible : `pai_cache = NULL` (défaut) = comportement v0.144.x
(recalcul à chaque run). Brief app :
`specs/027-regeneration-microclimat/brief-nemetonshiny-pai-cache.md`.

## nemeton 0.144.0 (2026-07-08)

#### Added — événement de phase `regen_expo:pai` sur `regen_sensibilite()`

Le chemin moteur de
[`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
(spec 027) émet désormais, via `progress_callback`, un événement
`list(current = "regen_expo:pai", source = "lidar"|"raster")` **juste
avant** de construire la structure de végétation (PAI). C’est le poste
le plus long entre la grille et ERA5 : `source = "lidar"` quand le PAI
est dérivé du nuage LiDAR HD
([`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)),
`"raster"` quand un raster LAI/PAI est fourni en repli
(Sentinel-2/PROSAIL, spec 033).

L’app (`nemetonshiny`) peut ainsi afficher une phase « Structure de
végétation » dédiée plutôt qu’un trou silencieux de plusieurs minutes.
Rétro-compatible : no-op quand `progress_callback = NULL` (sortie
byte-identique). Le chemin `precomputed` n’émet rien (rien n’est
calculé). Cf. brief app
`specs/027-regeneration-microclimat/brief-nemetonshiny-engine-phase-status.md`.

## nemeton 0.143.0 (2026-07-07)

#### Changed — moteur exposition : lecture LiDAR clippée à l’AOI + ERA5 moins throttlé

Deux optimisations du chemin moteur de
[`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
(spec 027), sans changement de résultat :

- **[`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)
  clippe désormais la lecture LiDAR à l’emprise de travail** (filtre
  LASlib `-keep_xy`, dérivé de `parcelle` si fourni sinon de `grille`,
  tamponné). Avant, `las = <dossier nuage>` faisait lire par `lasR`
  **toutes** les dalles en entier (ex. 25 × ~138 Mo) ; sur des dalles
  **COPC** (indexées), lasR ne lit maintenant que les points de l’AOI et
  saute les dalles hors emprise. `parcelle` borne aussi la fenêtre de
  lecture (en plus du masque final). PAI dans la grille inchangé.
- **`.rsen_forcage_era5()` : `by_month = FALSE`** → **1 requête ERA5 par
  année** au lieu de 12 mensuelles (bbox ponctuelle 0.1°, volume
  modeste), plus un **retry + back-off** (`.rsen_era5_with_retry`) qui
  absorbe un throttle / une coupure réseau CDS transitoire. Réduit
  fortement les interruptions sur les runs multi-années.

## nemeton 0.142.0 (2026-07-07)

#### Added — `progress_callback` sur `regen_sensibilite()` / `regen_bilan_hydrique()`

Les deux moteurs reGénération exposent désormais un argument
`progress_callback = NULL`, en parité avec le contrat « monitoring » du
reste du cœur
([`load_biljou_forcing()`](https://pobsteta.github.io/nemeton/reference/load_biljou_forcing.md),
[`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md),
FORDEAD, RECONFORT…). Chaque étape publie un
`list(current = "<clé>", …)` ; l’app (nemetonshiny) mappe ces événements
sur des notifications de progression (bottom-right / ntfy).

- [`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
  : `"regen_expo:microclimf"` (`category`), `"regen_expo:era5"`
  (`category`/`year`/`i`/`n`, **une fois par année de référence**),
  `"regen_expo:complete"`. Le découpage mensuel ERA5 reste interne à
  `mcera5`.
- [`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
  : `"regen_biljou:start"` (`n` points) et `"regen_biljou:complete"`. La
  boucle par point reste interne à `biljouR`.

Défaut `NULL` = comportement **byte-identique** (émission no-op) ; un
callback qui échoue n’interrompt jamais un run (`tryCatch`). Aucune
nouvelle dépendance.

## nemeton 0.141.0 (2026-07-07)

#### Added — TWI hydrologiquement stable + cache auto-invalidant

`get_or_compute_twi()` gagne un paramètre `twi_target_res` (défaut **10
m**) qui **agrège le DEM à la résolution cible avant** le calcul
d’accumulation de flux. Sur un MNT LiDAR HD 0.5 m, le TWI D8 était
dominé par la micro-topographie (valeurs absolues peu fiables) et
coûteux (100 M cellules) ; à ~10 m il est hydrologiquement stable et
~400× plus léger. L’agrégation est ignorée pour un DEM déjà plus
grossier que la cible et pour les DEM en lon/lat (résolution en degrés).

#### Fixed — cache TWI fichier indexé sur l’empreinte du DEM

Le cache fichier de TWI utilisait un nom **fixe** `twi.tif`, rechargé
quelle que soit l’empreinte du DEM courant : un projet ayant calculé le
TWI depuis un DEM grossier (WMS 25 m) **ne le recalculait pas** après
acquisition du LiDAR HD. Le fichier est désormais nommé `twi_<hash>.tif`
où le hash intègre dimensions + emprise + CRS + `twi_target_res`,
s’invalidant automatiquement. Les caches `twi.tif` existants deviennent
orphelins et sont recalculés une fois (désormais peu coûteux).
`calculate_twi_terra()` / `calculate_twi_grass()` acceptent aussi
`target_res` (défaut 10 ; `NULL` = pas d’agrégation).

## nemeton 0.140.0 (2026-07-06)

#### Added — tirage validation pondéré continu (FORDEAD/RECONFORT)

[`create_validation_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_validation_sampling_plan.md)
gagne un mode de pondération **continu**, en parité avec
[`create_trend_sanitary_plan()`](https://pobsteta.github.io/nemeton/reference/create_trend_sanitary_plan.md)
(qui le faisait déjà pour FAST via `|pente Theil-Sen|`) : le tirage GRTS
des placettes de validation peut être pondéré par un **raster de
sévérité continu externe** (FORDEAD `anomaly_index`, score/probabilité
RECONFORT) plutôt que par la classe discrète 0-4.

- Nouveaux paramètres (défauts rétro-compatibles, ajoutés avant `seed`)
  : `weighting = c("uniform", "continuous")` et `weight_raster = NULL`.
- `weighting = "uniform"` (défaut) : **strictement l’ancien
  comportement**, schéma de sortie byte-identique (pas de colonne
  `alert_weight`).
- `weighting = "continuous"` : `weight_raster` est aligné sur la grille
  d’alerte (reprojeté/rééchantillonné si besoin), restreint aux cellules
  d’alerte (`classes` devient un simple masque d’éligibilité), normalisé
  min-max en probabilité d’inclusion strictement positive, puis tiré via
  la GRTS à probabilité continue (`aux_var` spsurvey — helper
  `.draw_grts_continuous()` déjà utilisé par le plan FAST). Les témoins
  restent tirés uniformément sur `control_classes`. Équilibre spatial
  GRTS conservé.
- Nouvelle colonne de sortie `alert_weight` (valeur brute de sévérité au
  point tiré, traçabilité) en mode continu uniquement.
- Garde-fous typés : `weight_raster` NULL en continu → erreur explicite
  (pas de repli silencieux) ; vide/tout-NA/constant sur les cellules
  d’alerte → `nemeton_empty_alert_mask` (déjà mappée par l’app) ; CRS
  non réconciliable → nouvelle classe
  `validation_weight_raster_mismatch`.

## nemeton 0.139.0 (2026-07-06)

#### Changed — E-OBS/CDS : cache persistant + plafond d’année levé

Le chemin CDS de
[`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)
(spec 034) téléchargeait dans
[`tempdir()`](https://rdrr.io/r/base/tempfile.html) sans jamais vérifier
l’existence du fichier → **re-téléchargement du bloc entier (plusieurs
Go) à chaque analyse**, et perte à la fin de session. Par ailleurs
`.eobs_cds_period()` **plafonnait la borne haute du bloc courant à
2024** en dur, excluant silencieusement les années ≥ 2025.

- **Cache persistant** : `cache_dir` par défaut =
  `file.path(get_global_cache_dir(), "eobs")`. Chaque bloc (variable ×
  période × version × résolution) est nommé de façon déterministe
  (`.eobs_cache_file()`) et téléchargé **une seule fois** ; les appels
  suivants font un **cache-hit** (nouvel événement de progression
  `"eobs:cache_hit"`, aucun réseau). Le zip volumineux est supprimé
  après extraction.
- **Plafond levé** : pour le bloc ouvert (« courant »), la borne haute
  suit l’année demandée la plus récente (`2011_<max>`) au lieu d’un
  plafond figé. À apparier avec la `version` E-OBS couvrant ces années
  (best-effort : dégrade proprement si le CDS refuse l’enum). Blocs clos
  et cas multi-blocs (→ `NULL`) inchangés.
- Tests : inférence de bloc sans plafond (2015–2025 → `2011_2025`) ;
  cache-hit sans appel réseau (`wf_request` mocké, jamais invoqué).

Rappel (hors cœur, config utilisateur) : le bouton « Auto (E-OBS) »
exige la variable `.Renviron` nommée **`ecmwfr_PAT`** (ecmwfr ≥ 2.0.3,
pas `ecmwfr_ecmwfr`) **et** la licence CDS
`insitu-gridded-observations-europe` acceptée sur le compte.

## nemeton 0.138.2 (2026-07-05)

#### Fixed — S1/S2 : CRS LiDAR HD « sans autorité » (complément v0.138.1)

Le correctif CRS de v0.138.1 (`.normalize_crs()` sur le DEM d’entrée)
avait été posé sur R1/R2/R3/W3 mais **pas** sur les indicateurs sociaux
[`indicateur_s1_routes()`](https://pobsteta.github.io/nemeton/reference/indicateur_s1_routes.md)
et
[`indicateur_s2_bati()`](https://pobsteta.github.io/nemeton/reference/indicateur_s2_bati.md),
qui consomment le **même** DEM — et retombent explicitement sur
`lidar_mnt` quand `dem` est absent. Sur un projet LiDAR HD, le WKT
Lambert-93 dégénéré (`describe$code = NA`) faisait échouer
`sf::st_transform(roads/buildings, terra::crs(dem))` puis
`terra::rasterize(..., dem)` (« CRS do not match ») → S1/S2 rendaient
`NA`.

- `dem <- .normalize_crs(dem)` ajouté après résolution du DEM dans S1 et
  S2, avant tout `st_transform`/`rasterize` (même patron que
  `indicators-risk.R`).
- Test de régression : DEM au CRS dégénéré → S1 et S2 ne rendent plus
  tout-NA.

Découvert par l’audit CRS systématique des rasters produits par le cœur
(aucune création *from-scratch* ne sort en `unknown` ; seule surface
résiduelle = les DEM LiDAR HD injectés, désormais normalisés dans tous
les indicateurs DEM sauf le moteur reGénération microclimf, protégé en
amont par `checkinputs`).

## nemeton 0.138.1 (2026-07-05)

#### Fixed — R1/R2/R3/W3 : CRS LiDAR HD « sans autorité » (diagnostic RECONFORT)

En exécutant R3 sur RECONFORT, découverte que les GeoTIFF LiDAR HD IGN
cachés (dalles MNT, mosaïque, TWI dérivé) portent un **CRS Lambert-93
dégénéré** : le WKT se nomme `PROJCRS["EPSG:2154", ...]` mais avec
`DATUM["unnamed"]` / `ELLIPSOID["unretrievable"]` et **aucune autorité
EPSG** (`describe$code = NA`). terra refuse alors les reprojections («
CRS do not match ») → extractions DEM NA, et le TWI resamplé devient NA
→ R3 (et R1/R2/W3) rendaient `NA`.

- Nouveau helper interne **`.normalize_crs()`** : récupère le code EPSG
  déclaré dans le nom du WKT et re-tamponne un CRS propre (no-op si
  l’autorité est déjà là, si le CRS est vide, ou si aucun EPSG n’est
  déclaré).
- Appliqué à l’entrée `dem` de
  [`indicateur_r1_feu()`](https://pobsteta.github.io/nemeton/reference/indicateur_r1_feu.md),
  [`indicateur_r2_tempete()`](https://pobsteta.github.io/nemeton/reference/indicateur_r2_tempete.md),
  [`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md),
  [`indicateur_w3_humidite()`](https://pobsteta.github.io/nemeton/reference/indicateur_w3_humidite.md),
  dans `get_dem_raster()` et `get_or_compute_twi()` (DEM + TWI caché).

Validé sur les 30 UGF de RECONFORT (DEM brut au CRS dégénéré) : R3
récupéré, 0 NA, score ~60-67. La réparation à la **source** (cache
LiDAR) reste à faire côté app : brief
`specs/027-*/brief-nemetonshiny-lidar-crs.md` (le contrôle de couverture
bbox de l’app rejette la mosaïque avant qu’elle atteigne le cœur).

## nemeton 0.138.0 (2026-07-05)

#### Fixed — moteur reGénération : BILJOU ne rend plus une carte vide (diagnostic RECONFORT)

En exécutant le vrai calcul moteur sur le projet RECONFORT (LiDAR HD
présent mais **sans clé CDS**), deux garde-fous manquants empêchaient
BILJOU de produire le moindre `njstress` — donc l’indice de priorité
restait NA et la carte vide :

- **[`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)**
  : `lai_max` NULL/NA n’**interrompt plus** le moteur (`cli_abort` «
  needs lai_max »). Il **avertit** et applique un **défaut par type de
  peuplement** (feuillu 5 / résineux 4.5), proxy NDP 0. Sur un projet
  LiDAR sans clé CDS, microclimf est sauté (pas d’ERA5) et le repli LAI
  satellite ne se déclenche pas (grid non nul) : sans ce filet,
  `lai_max` restait NULL et le bilan hydrique ne tournait pas. L’app
  doit privilégier une valeur pilotée par la donnée (PAI LiDAR via
  [`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md),
  ou LAI S2 via
  [`lai_sentinel2()`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md))
  — cf. brief `specs/027-*/brief-nemetonshiny-lai-lidar.md`.
- **[`build_biljou_soil()`](https://pobsteta.github.io/nemeton/reference/build_biljou_soil.md)**
  : `ewm` NULL/NA (champ UI vidé, transmis en `NULL` par l’app) retombe
  sur le défaut 150 au lieu de propager NULL à
  [`biljouR::biljou_soil()`](https://pobsteta.github.io/biljouR/reference/biljou_soil.html)
  (qui échouait « between 1 and 3 soil layers »).

Validé de bout en bout sur les 30 UGF de RECONFORT (SAFRAN, sans clé) :
indice de priorité ~91.7-91.9, 0 NA.

## nemeton 0.137.0 (2026-07-05)

#### Added — `canopy_provenance()` : provenance canopée pour le badge app (spec 033 D5)

- Nouvel export `canopy_provenance(augmented)` : mappe les flags ML de
  [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
  vers une **clé de provenance canonique** de la structure de canopée —
  `"prosail_s2"` (repli LAI Sentinel-2/PROSAIL, flag `lai_ml`),
  `"opencanopy"` (CHM ML, `height_ml`) ou `"lidar_hd"` (défaut, PAI
  LiDAR HD). Le repli satellite (`lai_ml`) est prioritaire (sa présence
  = LiDAR absent). Permet à l’app d’afficher le **badge de provenance**
  de l’onglet reGénération sans ré-implémenter la règle de choix (règle
  [\#1](https://github.com/pobsteta/nemeton/issues/1)). Brief D5
  finalisé.

## nemeton 0.136.0 (2026-07-05)

#### Changed — Cohérence THEIA : tous les accès passent par la gateway de signature

Généralise le flux de signature (v0.135.0) à **tous** les consommateurs
des clés THEIA, pour une cohérence totale côté application :

- **FORMS /
  [`resolve_theia_assets()`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md)
  /
  [`load_theia_source()`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md)**
  : renvoient désormais des URLs **pré-signées** (`/vsicurl/`) au lieu
  de `/vsis3/` illisibles. **Débloque FORMS-T** (hauteur/biomasse →
  indicateurs C1/P1/P2/B2). Validé sur données réelles (lecture de la
  carte hauteur FORMS-T France).
- **[`theia_signed_href()`](https://pobsteta.github.io/nemeton/reference/theia_signed_href.md)**
  : réécrit en **R pur** par-dessus \[theia_sign_urls()\] — **supprime
  la dépendance Python/reticulate** (et les paquets
  `teledetection`/`pystac_client`) pour cette fonction.
- **`.get_s2_band_raster()`** (repli MUSCATE du pipeline FAST) : signe
  les hrefs `/vsis3/` THEIA avant lecture (les backends CDSE/PC ne sont
  pas touchés).
- **[`theia_configure_s3()`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)**
  : **déprécié** (avertissement) — le store <MESO@UM> ne reconnaît pas
  les clés du portail en accès S3 direct ; conservé pour rétro-compat
  mais n’active plus de lecture fonctionnelle.

## nemeton 0.135.0 (2026-07-05)

#### Added — Accès THEIA via la gateway de signature + repli LAI/PROSAIL MUSCATE fonctionnel

Le repli LAI Sentinel-2/PROSAIL sur **MUSCATE** (spec 033 D4) est
désormais **validé de bout en bout sur données réelles** (Vercors : LAI
médian 2.33, max 7.2). La mise au point a révélé le **vrai modèle
d’accès THEIA/DATA TERRA** :

- **[`theia_sign_urls()`](https://pobsteta.github.io/nemeton/reference/theia_sign_urls.md)
  (nouvel export)** — les COG <MESO@UM> (MUSCATE, FORMS) ne se lisent
  PAS en `/vsis3/` direct avec la clé du portail (le store renvoie
  *AccessKeyId does not exist*). Il faut des **URLs pré-signées** émises
  par la gateway `signing.stac.teledetection.fr` (clés
  `access-key`/`secret-key` en en-têtes, modèle SAS de Planetary
  Computer), lues ensuite par GDAL en `/vsicurl/`. Reverse-engineeré
  depuis le SDK Python `teledetection`.
- `.lai_s2_reflectance_muscate()` bascule sur ce flux (via
  `.theia_signed_read()`) et dégrade proprement en `NULL`
  (avertissement) sans `TLD_ACCESS_KEY` / `TLD_SECRET_KEY`.

#### Fixed — chaîne LAI MUSCATE (3 bugs démasqués une fois l’auth franchie)

- `.lai_s2_reflectance_muscate()` passait un `SpatVector` à
  `.get_s2_band_raster()` qui attend un objet `sf`
  ([`sf::st_transform`](https://r-spatial.github.io/sf/reference/st_transform.html)).
- `.lai_prosail_apply()` : `band_names` d’`apply_prosail_inversion` doit
  décrire les bandes **réellement** présentes dans le raster (3 :
  B4/B5/B8), pas les 10 bandes S2 du SRF (sinon LAI corrompu) ;
  récupération du fichier `<base>_lai.tif[f]` sur disque (le pattern
  ratait `.tiff`) + tolérance à une erreur post-écriture
  d’`apply_prosail_inversion`.

## nemeton 0.134.2 (2026-07-05)

#### Fixed — Requête E-OBS CDS invalide (spec 034)

Validation sur clé CDS réelle : `load_eobs_source(source = "cds")`
construisait une requête **rejetée en 400** (« invalid combination of
values ») par le CDS :

- Le CDS attend les valeurs d’enum en **underscore** (`30_0e`,
  `0_1deg`), pas en point. Ajout d’une normalisation point→underscore de
  `version` / `resolution` (on tolère toujours la forme humaine
  `"30.0e"` / `"0.1deg"` en entrée).
- La version par défaut `"28.0e"` **ne couvre pas** la période décennale
  `2011_2024` (rejet 400). Défaut porté à **`"30.0e"`** (combinaison
  `30_0e` + `2011_2024` + `0_1deg` **acceptée** par le CDS, vérifiée en
  réel).

Sans ce correctif, E-OBS échouait **même avec la licence acceptée**. Le
téléchargement réel requiert d’accepter la **licence E-OBS** sur la page
du dataset (`insitu-gridded-observations-europe`, 403 sinon).

## nemeton 0.134.1 (2026-07-05)

#### Fixed — Assemblage MUSCATE du repli LAI/PROSAIL (spec 033 D4)

L’assemblage automatique des réflectances MUSCATE
(`.lai_s2_reflectance_muscate`, repli Sentinel-2/PROSAIL du LAI) était
**cassé** et retournait toujours `NULL` :

- **Contrat** : `.get_s2_band_raster()` renvoie un **SpatRaster**, mais
  le code lisait `g$path` (comme si c’était une liste) → chaque scène
  plantait dans le `tryCatch` → assemblage `NULL`. Corrigé : usage
  direct du raster retourné.
- **S3** : les COG MUSCATE vivent sur le magasin S3 THEIA (`/vsis3/`,
  lecture authentifiée). Ajout de
  [`theia_configure_s3()`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)
  (une fois) avant lecture, avec **dégradation propre en `NULL` +
  avertissement** si `TLD_ACCESS_KEY`/ `TLD_SECRET_KEY` manquent (au
  lieu d’un abort).
- **Résolution mixte** : rééchantillonnage des bandes 20 m (B05) sur la
  grille 10 m (B04/B08) avant empilement
  ([`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
  refusait des géométries hétérogènes).

**Recherche MUSCATE validée sur données réelles** (22 scènes Vercors,
source souveraine CNES, hrefs `/vsis3/`). Tests CI ajoutés (mock
search/S3/band). Le download COG réel reste à valider avec des
identifiants Theia S3.

## nemeton 0.134.0 (2026-07-05)

#### Added — `load_biljou_forcing()` : progression par étapes (`progress_callback`)

- [`load_biljou_forcing()`](https://pobsteta.github.io/nemeton/reference/load_biljou_forcing.md)
  accepte un `progress_callback` appelé à chaque étape (patron
  monitoring) : `"biljou:safran_unit"` (`i`/`n`/`id`),
  `"biljou:era5_download"` (`i`/`n`/`id`/`year`), `"biljou:complete"`,
  `"biljou:unavailable"`. L’app peut ainsi afficher des notifications
  bas-droite au fil du téléchargement du forçage SAFRAN (par unité) ou
  ERA5 (par unité/année). No-op quand `NULL` ; API rétro-compatible.
  Brief spec 027 BILJOU mis à jour.
- **Forçage ERA5 validé de bout en bout sur données réelles** (clé CDS +
  licence acceptée) : téléchargement +
  `extract_clim(format = "microclimf")` (pression kPa cohérente
  altitude) + conversion PET → `meteo` BILJOU.

## nemeton 0.133.1 (2026-07-05)

#### Fixed — Forçage ERA5 aligné sur l’API mcera5 0.4 (microclimf + fallback BILJOU)

Validation sur clé CDS réelle : `.rsen_forcage_era5()` utilisait
l’**ancienne API mcera5** (`request_era5(bbox=, start_time=, …)`),
cassée contre **mcera5 0.4.0** (`unused arguments`). Utilisé par le
forçage microclimf (`regen_sensibilite`) et le fallback ERA5 de
[`load_biljou_forcing()`](https://pobsteta.github.io/nemeton/reference/load_biljou_forcing.md)
→ les deux échouaient sur un vrai téléchargement.

- Migré vers l’API scindée :
  `mcera5::build_era5_request(xmin, xmax, ymin, ymax, start_time, end_time, outfile_name)`
  puis `mcera5::request_era5(request, out_path)`. **Requête soumise avec
  succès au nouveau CDS** (validé en réel).
- Extraction via `mcera5::extract_clim(…, format = "microclimf")` :
  renvoie directement les colonnes attendues
  (`temp/relhum/pres/swdown/difrad/lwdown/ windspeed/winddir/precip`,
  précip incluse, **pression en kPa** — résout aussi la borne d’altitude
  de
  [`microclimf::checkinputs`](https://rdrr.io/pkg/microclimf/man/checkinputs.html)).
  Plus de mapping manuel ni d’appel séparé à `extract_precip()`.

Note : le téléchargement ERA5 requiert d’**accepter la licence**
*reanalysis-era5* sur le site CDS (une fois) — sans quoi le CDS renvoie
403.

## nemeton 0.133.0 (2026-07-05)

#### Changed — SAFRAN via OGC API-EDR GéoSAS (acquisition réelle, sans clé) (spec 027 L2)

Validation sur données réelles : le DOI biljouR par défaut ne sert que
de **pointeur** (grille + page d’accès) vers un catalogue externe —
`safran_download()` n’y trouvait aucun NetCDF de variable, donc
`load_biljou_forcing(source = "safran")` dégradait en `NULL`. Remplacé
par la **vraie** source Météo-France :

- **`load_biljou_forcing(source = "safran")` interroge désormais l’OGC
  API-EDR GéoSAS/INRAE** (`safran-isba`, SIM quotidien 1958→présent,
  **sans authentification**) : une requête position CSV par centroïde
  d’unité (coords **EPSG:2154** — CRS robuste, CRS84/4326 buggé en
  bêta), variables `ETP_Q`/`PRELIQ_Q`/`PRENEI_Q` (+
  T/rayonnement/vent/humidité) →
  [`biljouR::safran_to_meteo()`](https://pobsteta.github.io/biljouR/reference/safran_to_meteo.html)
  → `meteo` par unité. **Validé de bout en bout sur données réelles**
  (365 j/an, alimente
  [`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)).
- **SAFRAN ne nécessite donc aucune clé CDS** — c’est la voie à
  privilégier en France ; ERA5-Land (fallback) reste réservé aux cas
  hors couverture SAFRAN et requiert une clé CDS.
- Builder d’URL EDR pur `.biljou_safran_edr_url()` testé en CI.

## nemeton 0.132.0 (2026-07-05)

#### Added — Acquisition BILJOU : `load_biljou_forcing()` + `build_biljou_soil()` (spec 027 L2, option B)

Débloque le **bilan hydrique réel**
([`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md),
chemin moteur) depuis l’app : le cœur exposait déjà les moteurs mais
aucune acquisition météo/sol, ce qui forçait à mettre de la logique
données dans l’app (contraire à la règle
[\#1](https://github.com/pobsteta/nemeton/issues/1)). Patron
`load_theia_source` (acquisition au cœur, l’app cache).

- **`load_biljou_forcing(aoi, years, source, cache_dir, raw, …)`** :
  produit le `meteo` journalier au format biljouR (`date`, `doy`, `pet`,
  `rain`), en **liste nommée par unité** (clés = ids des points de
  `regen_bilan_hydrique`, alignées), directement consommable par
  `biljou_run_grid()`.
  - `source = "safran"` (primaire France) :
    [`biljouR::safran_download()`](https://pobsteta.github.io/biljouR/reference/safran_download.html)
    (DOI Recherche Data Gouv par défaut) → `safran_nc_to_meteo()` par
    centroïde.
  - `source = "era5"` (fallback) : ERA5-Land via `mcera5` (réutilise
    `.rsen_forcage_era5`) → agrégation journalière + PET Penman
    (`penman_pet`).
  - Chemin d’injection `raw` (conversion `safran_to_meteo`) **testé en
    CI** ; téléchargements SAFRAN/ERA5 best-effort (réseau/clé CDS),
    dégradent en `NULL`.
- **`build_biljou_soil(units, ewm = 150, roots, macro, micro, init)`** :
  produit le `sol` = objet
  [`biljouR::biljou_soil()`](https://pobsteta.github.io/biljouR/reference/biljou_soil.html)
  (défaut uniforme `ewm = 150 mm` en l’absence de référentiel sol fin ;
  `ewm` surchargeable). Dégrade en `NULL` sans `biljouR`.
- [`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
  construit désormais ses points via `.biljou_points()` (même helper que
  le loader → ids alignés).

## nemeton 0.131.0 (2026-07-05)

#### Added — `load_eobs_source()` : progression par étapes (`progress_callback`, spec 034)

- [`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)
  accepte un `progress_callback` appelé à chaque étape avec un payload
  `list(current = <clé>, …)` (patron monitoring) : `"eobs:cds_request"`,
  `"eobs:cds_download_done"`, `"eobs:unzip"`, `"eobs:read"`,
  `"eobs:reduce"`, `"eobs:complete"`, `"eobs:unavailable"`. L’app peut
  ainsi afficher des notifications bas-droite au fil du téléchargement
  E-OBS (brief spec 034 mis à jour). No-op quand `NULL` ; API
  rétro-compatible.

## nemeton 0.130.0 (2026-07-04)

#### Added — `load_eobs_source()` : acquisition E-OBS pour la détection auto des années (spec 034)

Nouveau loader qui produit le **SpatRaster estival par année** (une
couche/an, nommée par l’année) attendu par
[`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md)
(années de référence moyenne/canicule) et
[`tendances_estivales_eobs()`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)
(contexte régional). Comble le maillon manquant qui rendait le bouton «
Auto (E-OBS) » de l’app indisponible (le cœur n’auto-téléchargeait pas
E-OBS).

- **Deux chemins** (comme les moteurs reGénération) :
  - *Injection `nc`* (testé CI) : un netCDF E-OBS quotidien (téléchargé
    depuis le CDS ou ECA&D) ou un `SpatRaster` daté → réduit en
    estival/an (crop AOI, sélection JJA, réducteur mean/sum/max/median).
  - *CDS `source = "cds"`* (best-effort, validé sur données réelles) :
    téléchargement automatique via `ecmwfr` (dataset
    `insitu-gridded-observations-europe`, **la même clé CDS que
    ERA5/mcera5**), dézippage, lecture. Dégrade en `NULL`.
- **Variables** `var ∈ {"tx","tg","rr"}` → variable CDS ; réducteur
  estival par défaut `mean` (tx/tg) ou `sum` (rr). Fenêtre
  `months = 6:8` (JJA) par défaut.
- Dégradation propre (`NULL`) si `terra`/`sf`/`ecmwfr` absents, pas de
  clé, réseau KO ou AOI hors Europe → l’app retombe sur la saisie
  manuelle.

Usage : `load_eobs_source(aoi, var = "tx", years = 2014:2023)` → passer
à `microclimate_detect_years(eobs = …)` ou
`tendances_estivales_eobs(tx = …, rr = …)`.

## nemeton 0.129.2 (2026-07-04)

#### Fixed — Messages des gardes reGénération : plus d’échappement hyperlien terminal (fuite dans l’app)

- [`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
  : le message d’aide de la garde utilisait `{.fn ...}`, qui émet une
  **séquence d’échappement OSC 8** (hyperlien cliquable en terminal).
  Capturée par
  [`conditionMessage()`](https://rdrr.io/r/base/conditions.html) et
  affichée en **HTML par l’app Shiny**, elle fuyait en charabia
  (`]8;;ide:help:biljouR::safran_to_meteo…`). Remplacé par `{.code ...}`
  (style sans hyperlien). Test de non-régression : les messages de garde
  des deux moteurs restent texte pur même avec les hyperliens cli
  forcés.

## nemeton 0.129.1 (2026-07-04)

#### Fixed — Moteur microclimf (`regen_sensibilite`) : alignement sur l’API microclimf installée (validation données réelles)

Validation du moteur microclimf **sur données LiDAR HD réelles** (dalles
Vercors bundlées) : le chemin moteur, porté depuis un prototype écrit
contre une autre version de microclimf, n’avait jamais tourné de bout en
bout. Trois défauts qui faisaient planter un run réel sont corrigés :

- **`vegp`/`soilc` en `PackedSpatRaster`** : `.rsen_vers_grille()`
  dépaquette désormais
  ([`terra::unwrap()`](https://rspatial.github.io/terra/reference/wrap.html))
  avant de conformer à la grille — sinon dimensions ≠ dtm et
  [`microclimf::checkinputs()`](https://rdrr.io/pkg/microclimf/man/checkinputs.html)
  échouait (« y dimension of vegp\$x does not match dtm »).
- **Composants végétation multi-couches** (mensuels) :
  `.rsen_vers_grille()` réduit à une valeur scalaire représentative
  (moyenne toutes cellules/couches) au lieu de crasher
  (`'list' object cannot be coerced to type 'double'`).
- **Sorties `runmicro` en array nu** : le microclimf installé renvoie
  `Tz` / `relhum` en tableaux R (`nrow×ncol×ntime`), plus en
  `SpatRaster`. Nouveau helper `.rsen_as_rast()` les reconvertit en
  `SpatRaster` géo-référencé (même convention que `microclimf:::.rast`),
  rétro-compatible avec les versions qui renvoient un `SpatRaster`.

Validé de bout en bout :
`checkinputs → runpointmodel → subsetpointmodel → runmicro`, agrégation
T°max/VPD sous couvert sur grille LiDAR réelle. **Note d’exploitation**
: la borne de pression de `checkinputs` dépend de l’altitude
(`mxp = 108.5·((293−0.0065·elev)/293)^5.26`) ; le forçage ERA5 (mcera5)
doit fournir la pression en **kPa** cohérente avec l’altitude du site.

## nemeton 0.129.0 (2026-07-04)

#### Added — Repli LAI Sentinel-2/PROSAIL, increment 2 : MUSCATE auto + modèle pré-entraîné (spec 033)

- **Assemblage automatique MUSCATE (D4)** :
  [`lai_sentinel2()`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md)
  assemble désormais les réflectances Sentinel-2 tout seul quand `refl`
  n’est pas fourni — recherche MUSCATE
  (`stac_search_s2(source="muscate")`, spec 029), récupération stateless
  des bandes par scène (`.get_s2_band_raster`, crop AOI + cache), stack
  multi- bandes par date. Le défaut `selected_bands` passe à
  **`c("B4","B5","B8")`** (rouge, red-edge, NIR — toutes exposées par le
  pipeline S2 ; B03/vert ne l’est pas). Mapping des noms prosail→nemeton
  (`B4`→`B04`, `B8A` conservé).
- **Modèle pré-entraîné versionné (D3)** :
  `inst/extdata/prosail_lai_Sentinel_2A_B4-B5-B8.rds` (~1.3 Mo) chargé
  directement — plus d’entraînement (~70 s) au runtime. Sérialisation
  vérifiée, **prédiction après rechargement testée en CI**. À défaut,
  `.lai_prosail_train` entraîne + met en cache. Régénérable via
  `data-raw/prosail_lai_model.R`.

Le chemin moteur (application sur scène S2 réelle) reste validé sur
données réelles (non jouable en CI).

## nemeton 0.128.0 (2026-07-04)

#### Added — Repli LAI Sentinel-2/PROSAIL pour la canopée NDP 0 (spec 033, increment 1)

**[`lai_sentinel2()`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md)**
: restitue un raster **LAI** depuis **Sentinel-2 L2A** par **inversion
PROSAIL hybride** (`prosail`), comme **repli NDP 0** des entrées canopée
reGénération quand le LiDAR HD est absent — `lai_max` de
[`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
(ajustement direct) et, en proxy dégradé, `pai` de
[`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
(LAI ≠ PAI structural). **NDP ≥ 1 garde toujours le PAI LiDAR de
[`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md).**

Décisions D1–D6 (spec 033) validées : réducteur temporel **p90** (D1) ;
`lai_max` biljouR + `pai` microclimf derrière injection explicite (D2) ;
déclencheur auto (D6). Chemin `precomputed` pur + réducteur
(p90/max/median/mean) **testés en CI** ; l’entraînement PROSAIL est
**vérifié**, l’application sur scène réelle est validée par Pascal (non
jouable en CI : scènes S2 + SVM lourd). Intégrations :

- `regen_sensibilite(pai = <raster LAI>)` court-circuite le LiDAR
  (repli), `las` non requis dans ce cas.
- [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
  remonte `augmented = "lai_ml"` quand
  `attr(data, "lai_source") == "prosail_s2"` (NDP de base inchangé,
  ADR-011).

`prosail` en Suggests + Remotes (`jbferet/prosail`), gardé par
`requireNamespace`. Reste (increment 2) : assemblage auto des
réflectances MUSCATE + modèle pré-entraîné versionné.

## nemeton 0.127.1 (2026-07-03)

#### Fixed — Agrégation par unité du moteur microclimf via exactextractr

[`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
(chemin moteur) agrégeait les rasters par unité avec
[`terra::extract`](https://rspatial.github.io/terra/reference/extract.html)
(échantillonnage au centroïde/cellule), incohérent avec le reste du
paquet. Il utilise désormais le helper `.micro_extract()`
(**exactextractr**, déjà en Imports) : moyennes **pondérées par le
recouvrement exact** cellule/UGF, et `couverture_pct` = **fraction
exacte non-NA** sur l’emprise de l’unité — plus précis aux bords de
parcelle. Chemin `precomputed` inchangé.

## nemeton 0.127.0 (2026-07-03)

#### Added — Consolidation multi-époques de la forêt ancienne pour N2 (paliers d’ancienneté, spec 031)

**[`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)**
accepte désormais une **liste nommée de sources historiques** (ex.
`list(cassini = ..., etatmajor = ...)`) et produit une **couche en
paliers non-recouvrante** : subdivision planaire (auto-overlay
[`sf::st_intersection`](https://r-spatial.github.io/sf/reference/geos_binary_ops.html))
avec une colonne `anciennete` = **nombre d’époques** couvrant chaque
polygone (plus élevé = plus ancien, continuité plus forte) + `epoques`
(libellés contributeurs). Les formes mono-source (sf / SpatRaster) sont
inchangées.

**[`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md)**
exploite ces paliers : nouvel argument `weight_anciennete = TRUE` —
quand la couche porte `anciennete`, la couverture forêt-ancienne est
**pondérée par la profondeur du palier** (forêt présente à plus
d’époques compte davantage). Rétrocompatible : sans colonne `anciennete`
(couche mono-époque), N2 garde son comportement binaire ;
`weight_anciennete = FALSE` force le binaire.

**Contexte Cassini** : Cassini (~1750) n’est diffusé qu’en **raster**
(scans AN/BnF, pas de vecteur forêt IGN — vérifié via happign). Cette
consolidation est prête à recevoir toute couche Cassini **vectorisée**
(régionale, fournie), qui se combine alors à l’état-major ~1850 en «
forêt depuis ~1750 » (palier le plus ancien). Testable hors réseau (12
tests paliers + pondération N2).

## nemeton 0.126.0 (2026-07-03)

#### Added — Moteur BILJOU réel (spec 027 L2, incrément C/3) — les 3 moteurs reGénération sont portés

**[`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)**
n’est plus un scaffold : le chemin moteur est **câblé à biljouR** (pas
de prototype — orchestration via l’API du paquet). Centroïdes des unités
→
[`biljouR::biljou_run_grid()`](https://pobsteta.github.io/biljouR/reference/biljou_run_grid.html)
(BILJOU par point forcé par `meteo` SAFRAN/ERA5) → agrégation **moyenne
inter-annuelle par unité** des indices, avec mapping
`NJstress`/`Istress`/`DEBstress`/`min_rew` → `njstress`/`istress`/
`deb_stress`/`rew_min` (colonnes §7). `forest_type` `feuillu`/`resineux`
mappé vers `broadleaved`/`coniferous` ; phénologie (`budburst`,
`leaf_fall`, …) transmise via `...` ; nouvel argument `years`.
Dégradation propre : point en échec → NA (jamais d’abort dur). `biljouR`
en Suggests + Remotes (`pobsteta/biljouR`), gardé par `requireNamespace`
; pass-through `precomputed` conservé.

**Contrairement à PAI/microclimf, ce chemin moteur EST testé en CI** :
biljouR fournit la meteo d’exemple `meteo_hesse`, donc l’orchestration
complète tourne hors réseau (résineux + feuillu avec phénologie, mapping
des 4 indices, chaînage R3). 31 tests moteurs.

Fin du portage : les **3 moteurs reGénération** (`pai_depuis_nuage`
lasR, `regen_sensibilite` microclimf, `regen_bilan_hydrique` biljouR)
sont **réels**. Reste le brief app (déclenchement au bouton « Lancer
l’analyse », opt-in) et la validation Pascal des chemins LiDAR/ERA5
(A/B) sur données réelles.

## nemeton 0.125.0 (2026-07-03)

#### Added — Moteur microclimf réel (spec 027 L1, incrément B/3 du portage moteurs)

**[`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)**
n’est plus un scaffold : le chemin moteur est **câblé à microclimf**.
Portage fidèle du prototype
`/Documents/reGénération/microclimat_parcelles_robuste.R` :

1.  grille **statique LiDAR HD** (DTM, hauteur de canopée, PAI via
    [`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)),
    MNT/MNH acceptés en `SpatRaster` ou dossier de dalles ;
2.  **microclimf par année** forcé **ERA5-Land** (`mcera5`), avec
    **cache disque** (`cache_dir`) des `.nc` et des rasters d’été `.tif`
    ;
3.  moyennes **étés moyens vs canicule** (canopée figée) → écarts ΔT°max
    / ΔVPD ;
4.  **robustesse signal/bruit** (si ≥ 2 années par catégorie) ;
5.  **agrégation par unité** → colonnes §7 (`tmax_moyenne`,
    `tmax_canicule`, `vpd_moyenne`, `vpd_canicule`, `d_tmax`, `d_vpd`,
    `sensibilite`, `rang_sensibilite`, `robustesse`, `signal_robuste`,
    `couverture_pct`) + `parcelle_sensible` / `priorite`.

Nouveaux arguments : `res`, `tampon`, `reqhgt`, `k`, `cache_dir`.
Dépendances lourdes (`microclimf`, `mcera5`, `lasR`) en Suggests +
Remotes, gardées par `requireNamespace` ; **pass-through `precomputed`
conservé**. Deuxième des 3 moteurs portés (incrémental + validation
réelle). Chemin moteur **non jouable en CI** (LiDAR HD + ERA5/CDS) — **à
valider par Pascal sur données réelles** avant l’incrément C (biljouR).
Reste : C `regen_bilan_hydrique` (biljouR).

## nemeton 0.124.0 (2026-07-03)

#### Changed — Extraction E-OBS estivale câblée dans microclimate_detect_years() (spec 027 L2, item cœur 2)

**`microclimate_detect_years(eobs, aoi, years, …)`** accepte désormais
un **`SpatRaster` E-OBS par-année** (une couche par an, JJA agrégé —
même contrat que `tx` de
[`tendances_estivales_eobs()`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)),
plus seulement un named numeric pré-calculé. Chaque couche est
**croppée + masquée sur l’AOI** (union des UGF) puis moyennée
([`terra::global`](https://rspatial.github.io/terra/reference/global.html))
→ indice de chaleur estivale par an, qui alimente la sélection année
moyenne / canicule de
[`indicateur_r6_sensibilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_r6_sensibilite.md).
Les années viennent des noms de couches ou du nouvel argument `years`.
C’était le chemin « not wired yet » du L2 (l’app pré-remplit ainsi ses
deux sélecteurs d’années depuis l’Auto E-OBS de reGénération).

Rétrocompatible : le chemin named numeric (`year -> heat`) est inchangé.
Testable hors réseau (raster synthétique) — 20 tests, dont crop/mask sur
l’AOI.

**Note** : l’item cœur « mapping TFV → essence de régénération »
([`map_tfv_to_species_class()`](https://pobsteta.github.io/nemeton/reference/map_tfv_to_species_class.md)
↔︎
[`regeneration_tolerances()`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md))
était **déjà livré** en v0.121.0 (exporté, documenté, testé) — rien à
ajouter.

## nemeton 0.123.0 (2026-07-03)

#### Added — Acquisition forêt ancienne (~1850) pour N2 (spec 031, item cœur 1)

**`load_foret_ancienne_source(aoi, crs = 2154)`** : récupère la
couverture forestière **~1850** depuis la carte de l’**état-major IGN**
(BD Carto État-Major, couche WFS
`BDCARTO_ETAT-MAJOR.NIVEAU3:c_1_1_ocs_ancien`, Etalab 2.0) via
`happign`, clippée sur l’AOI, et la renvoie comme couche
`foret_ancienne` de
[`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md)
(aucun changement de signature N2). Sortie standardisée par
[`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)
(`foret_ancienne = TRUE`).

**Choix de source (arbitré)** : le produit officiel « BD Forêts
anciennes » (Nature=ancienne, état-major × BD Forêt v2) est
*download-only* (GeoPackage départemental `.7z`, pas de WFS — confirmé
via `happign`). On utilise l’**ingrédient état-major ~1850**
(atteignable en WFS) ; comme N2 recroise cette couche avec les UGF
actuelles, la **continuité** (« forêt hier *et* aujourd’hui ») émerge de
l’indicateur lui-même — proxy défendable, livrable sans le blocage 7z.

Dégradation propre : `NULL` (réseau absent, `happign` absent, erreur
WFS, hors-métropole) → l’app retombe sur N2 couverture actuelle ; `sf`
0-ligne quand l’AOI n’a pas de forêt ~1850. `happign` en Suggests, gardé
par `requireNamespace`. Chemin WFS réel validé sur emprise Fontainebleau
(non jouable en CI : tests via `get_wfs` mocké).

## nemeton 0.122.0 (2026-07-03)

#### Added — Moteur PAI réel (spec 027 L1, incrément A/3 du portage moteurs)

**[`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)**
n’est plus un scaffold : le chemin nuage de points LiDAR HD est **câblé
au pipeline `lasR`** (une lecture, deux rastérisations `count` filtrées
par classe sol/végétation → fraction de trouée → PAI Beer-Lambert,
rééchantillonné sur la grille de travail, masque parcelle optionnel).
**Portage fidèle** du prototype reGénération `pai_lidarhd_lasR.R`.
Dépendance lourde `lasR` en Suggests, gardée par `requireNamespace` ;
pass-through `precomputed` et validation d’entrées propre conservés.
Nouveaux arguments : `parcelle`, `fenetre`, `cl_sol`, `cl_veg`, `epsg`,
`pai_max`.

Premier des 3 moteurs portés (stratégie **incrémentale avec validation
réelle entre chaque**). Le chemin moteur n’est **pas testable en CI**
(dalles LiDAR HD requises) — **à valider par Pascal sur données
réelles** avant l’incrément B (microclimf). Suivent : B
`regen_sensibilite` (microclimf), C `regen_bilan_hydrique` (biljouR).

## nemeton 0.121.1 (2026-07-03)

#### Changed

- **`biljouR` déclaré** en `Suggests` + `Remotes` (`pobsteta/biljouR`) :
  le moteur de bilan hydrique de
  [`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
  est désormais une dépendance optionnelle officielle (installable via
  [`remotes::install_github`](https://remotes.r-lib.org/reference/install_github.html)),
  toujours chargée par
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) avec
  dégradation propre. Le message d’erreur du chemin moteur pointe vers
  le dépôt.

## nemeton 0.121.0 (2026-07-03)

#### Added — Sélecteur essence par-espèce + mapping TFV → essence (spec 027, incrément 2/3)

- **`map_tfv_to_species_class(tfv_code)`** : mappe les codes TFV BD
  Forêt v2 → classe d’essence NMT (`essence_hetraie`…), via une nouvelle
  colonne `species_class` de
  [`bdforet_v2_mapping()`](https://pobsteta.github.io/nemeton/reference/bdforet_v2_mapping.md).
  Essences nommées → classe ; mélanges → `essence_mixte` ; non-forestier
  → `NA`. **Ferme l’item cœur PLAN** « mapping TFV → essence de
  régénération » : l’app pré-remplit « Essence cible » depuis les
  essences réellement présentes sur l’emprise.
- **[`regen_species_choices()`](https://pobsteta.github.io/nemeton/reference/regen_species_choices.md)
  étendu** — nouveau paramètre `level` :
  - `level = "species"` (**défaut**) : les **essences FRM** européennes
    (`european_species_tolerances(statut = "frm")`), Atlas repliable via
    `include_atlas = TRUE` (groupe `"atlas"`). Colonnes riches exposées
    (`species_sci`, `shade_tol`, `confidence`, `invasif`,
    `species_class`…).
  - `level = "class"` : les 11 classes broad (comportement antérieur).
  - **Présence UGF** flaggée depuis une colonne TFV (`tfv_col`, via
    [`map_tfv_to_species_class()`](https://pobsteta.github.io/nemeton/reference/map_tfv_to_species_class.md))
    ou une colonne de classe ; groupe `"present"` en tête,
    `"adaptation"` ensuite, tri par tolérance chaleur.
- **[`european_species_tolerances()`](https://pobsteta.github.io/nemeton/reference/european_species_tolerances.md)**
  gagne une colonne **`species_class`** (rattachement par règle de genre
  aux 11 classes, pour le flag présence).
- **`indice_priorite_regen(species=)`** résout désormais **les deux
  tables** : un code de classe (`essence_hetraie`) **ou** d’espèce UE
  (`fagus_sylvatica`).

Incrément 2/3. Reste : brief onglet §4.1 (fait ici) et, plus tard,
calibration fine / voies ClimEssences si souhaité.

## nemeton 0.120.0 (2026-07-03)

#### Added — Table de tolérances des essences européennes (spec 027, calibration)

**`european_species_tolerances(statut, confiance, type, include_invasif)`**
: table de référence des tolérances au repeuplement pour **~193 essences
européennes**, sourcée/calibrée **par espèce** (fichier fourni par
Pascal). Elle **complète**
[`regeneration_tolerances()`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)
(11 classes broad, conservée pour le mapping UGF) avec les **mêmes
axes** `tmax_tol_c`/`vpd_tol_kpa` — désormais sourcés — **plus**
l’autécologie Niinemets & Valladares 2006 (sécheresse /
**ombre-couvert** / engorgement 1–5), gel hiver/tardif/précoce, humidité
de l’air et thermophilie (1–9).

Trois périmètres empilés (`statut`) : `frm_1999` (Directive 1999/105/CE,
47), `frm_2025` (ajouts futur règlement FRM, accord 2025-12-08, 17),
`atlas_jrc` (European Atlas of Forest Tree Species, ~130, **canevas
dérivé par règle**). Colonne `confidence` (`eleve`/`moyen`/`faible`) +
flag `invasif` (INTRO/INVASIF = **présence ≠ recommandation**). Filtre
pratique `statut = "frm"` (toutes essences réglementaires).

Sources ajoutées au projet dans **`inst/REFERENCES.md`** (Directive
1999/105/CE, JRC European Atlas / San-Miguel-Ayanz 2016, Caudullo 2017,
Niinemets & Valladares 2006, Münchinger 2023, Visakorpi 2024, EUFORGEN,
Ellenberg, ClimEssences). Données
`inst/extdata/european_species_tolerances.csv`, générées par
`data-raw/european_species_tolerances.R`.

Incrément 1/3 (donnée + sources). Suivent : sélecteur
[`regen_species_choices()`](https://pobsteta.github.io/nemeton/reference/regen_species_choices.md)
étendu aux essences FRM (Atlas replié), puis résolution par-espèce dans
`indice_priorite_regen(species=)` + brief onglet.

## nemeton 0.119.0 (2026-07-03)

#### Added — Sélecteur essence cible reGénération (spec 027 §10.1)

**`regen_species_choices(units, species_col, region, lang)`** :
construit la liste **prête pour le menu déroulant « essence cible »** de
l’onglet reGénération, côté cœur (zéro logique métier côté app). Les
options sont **exactement** les classes que le cœur sait scorer —
l’intersection de
[`regeneration_tolerances()`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)
et
[`list_species_classes()`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
— le sélecteur ne peut donc jamais proposer une essence que
`indice_priorite_regen(species=)` ignore.

Renvoie un data.frame
`code`/`label`/`tmax_tol_c`/`vpd_tol_kpa`/`present`/ `groupe` : les
classes **présentes sur les UGF** (`groupe = "present"`) en tête, puis
les **autres (adaptation)** triées par tolérance chaleur croissante
(mésophile → thermophile). Détection auto de la colonne d’essence
(`essence_dominante`/`essence`/`species_class`/…). L’entrée générique «
aucune essence » (→ `species = NULL`) est ajoutée par l’app.

Brief onglet §4.1 mis à jour (deux `optgroup`, défaut générique,
honnêteté sur le caractère indicatif des seuils, MFR = étape aval hors
indice).

## nemeton 0.118.0 (2026-07-03)

#### Added — Branche A : tendances estivales E-OBS sur l’emprise UGF (spec 027 §6)

**[`tendances_estivales_eobs()`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)**
: la carte bivariée de tendances estivales (réchauffement × assèchement,
inspirée de *L’IF* n°49 IGN), **recadrée sur l’union des UGF + un
buffer** (décision §10.4, **défaut 25 km** — validé Pascal ; buffer
métrique via EPSG:3035 LAEA). **Pas de carte nationale.**

Le cœur **calcule** ; l’app **rend**. Par maille E-OBS de l’emprise :
tendance (pente moindres carrés ~ année) de la **T°max** et des
**précipitations** estivales, puis **classification bivariée** —
`classe_tmax` / `classe_precip` (1-3, tertiles par défaut ou `breaks`
fixes) et `classe_bivariee` (1-9, `(classe_tmax-1)*3 + classe_precip` ;
« chaud & sec » = 3 & 1).

Comme les moteurs : E-OBS (NetCDF, licence recherche non commerciale)
est externe → **chemin `precomputed`** (une `sf`/raster de tendances →
crop + classe, sans données), **chemin moteur** (rasters `tx`/`rr`
par-année → calcul des pentes, logique terra testable), ou **échec
propre**. Sortie = `sf` de points (centres de maille) dans l’emprise
tamponnée, prête pour la choroplèthe bivariée côté `nemetonshiny`.

## nemeton 0.117.0 (2026-07-02)

#### Added — Scaffolds des moteurs reGénération L1/L2 (spec 027 v2.1)

Trois moteurs de l’onglet reGénération, en **scaffolds honnêtes** (les
dépendances lourdes `microclimf`/`mcera5`/`lidR`/`lasR`/`biljouR`
restent en `Suggests`, chargées via `requireNamespace`, dégradation
propre) avec un **chemin `precomputed` PUR et testable** :

- **[`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)**
  (L2, biljouR) — bilan hydrique du sol par UGF : `njstress`, `istress`,
  `rew_min`, `deb_stress`. Le chemin `precomputed` rattache la sortie
  d’un run BILJOU aux unités (colonnes §7), **sans le moteur** ;
  alimente directement `indicateur_r3_secheresse(biljou=)` et
  [`indice_priorite_regen()`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md).
- **[`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)**
  (L1, microclimf) — exposition microclimatique par UGF : `tmax_*`,
  `vpd_*`, `d_tmax`, `d_vpd`, `sensibilite`, `robustesse`… Le chemin
  `precomputed` rattache + **dérive** `d_tmax`/`d_vpd` (canicule −
  moyenne) et `rang_sensibilite` (1 = plus sensible).
- **[`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)**
  (L1, lasR/lidR) — PAI mur-à-mur depuis un nuage LiDAR HD ;
  `precomputed` accepte un `SpatRaster` PAI pré-calculé (pass-through).

Sans `precomputed` ni moteur installé, chaque fonction **échoue
proprement** avec un message actionnable (« installer X, ou passer
`precomputed` »). Quand le moteur est installé mais l’orchestration
réelle pas encore câblée, message « exécuter le prototype reGénération
et passer `precomputed` ». **Le pipeline
`regen_sensibilite`/`regen_bilan_hydrique → r3` /
`indice_priorite_regen` fonctionne dès aujourd’hui sur des sorties de
moteur pré-calculées.**

**Note dépendance** : `biljouR` (GPL-3) n’est pas encore dans
`Suggests`/ `Remotes` (dépôt à confirmer) — gardé via `requireNamespace`
uniquement. À déclarer une fois le dépôt connu.

## nemeton 0.116.0 (2026-07-02)

#### Added — `indicateur_r3_secheresse()` enrichi par le bilan hydrique BILJOU (spec 027 §5.1)

R3 (sécheresse) **accepte désormais les métriques du moteur BILJOU**
(`regen_bilan_hydrique`) : deux nouveaux arguments `biljou`
(data.frame/list avec `njstress` jours de stress, `istress` intensité,
`deb_stress` précocité) et `biljou_weight` (poids du blend, défaut 0.5).

- **Valeurs brutes exposées** (`r3_njstress`, `r3_istress`,
  `r3_deb_stress`) — pas seulement le score, pour la conformité / le
  reporting (comme la logique « m³/ha au lieu du score »).
- **Blend** : le stress hydrique mécaniste **affine** le risque
  SPEI/topo (moyenne pondérée par unité ; un `r3_score` NA n’empoisonne
  pas le blend). BILJOU aggrave dans le même sens que le risque existant
  (symétrique aux atténuations neige / humidité du sol).
- **Sans DEM mais avec BILJOU** : R3 est calculé depuis le bilan
  hydrique seul (auparavant : NA).
- Les métriques sont aussi **lues depuis les colonnes de `units`**
  (`njstress`, etc.) quand `biljou = NULL` → le pipeline
  `regen_bilan_hydrique → r3` est transparent.

**Strictement rétrocompatible** : sans `biljou` ni colonnes BILJOU, le
comportement v0.115.x est préservé (y compris le retour NA sans DEM).
Bornes de normalisation du stress **documentées, non calibrées terrain**
(spec 027 §9.2).

## nemeton 0.115.0 (2026-07-02)

#### Added — Indice de priorité de régénération (spec 027 v2.1 L3, arbitré)

Premier incrément de code de l’onglet **reGénération** réaligné sur le
brief `/home/pascal/Documents/reGénération/` :
**[`indice_priorite_regen()`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md)**
— l’indice de **tête d’onglet** qui **croise** l’**exposition
microclimatique** (moteur microclimf : `sensibilite`, sinon
`d_tmax`/`d_vpd`) et le **stress hydrique du sol** (moteur biljouR :
`njstress`, `istress`, `rew_min`) en une **priorité 0-100**
d’intervention (haut = parcelle la plus vulnérable). Pure logique R : la
fonction **consomme** les colonnes de sortie des moteurs (contrat §7),
sans dépendance GPL, entièrement testable sur `sf` synthétique.

Conforme aux **arbitrages du §10** (Pascal, 2026-07-02) : - **Générique
par défaut** ; **affinage par essence en OPTION désactivée**
(`species = NULL` → générique ; renseigné → pousse la priorité via les
seuils chaud/sec de `regeneration_tolerances.csv`, exposés par le nouvel
accesseur
**[`regeneration_tolerances()`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)**). -
Colonnes de sortie **au schéma §7** : `indice_priorite_regen`,
`regen_exposition`, `regen_hydrique`, `parcelle_sensible`, `priorite`,
`regen_essence` ; `couverture_pct` préservé.

C’est le **retravail** du `regeneration_index` parké (moyenne pondérée
A3/A4/W4/R6) vers la sémantique du brief (croisement exposition × stress
hydrique). Bornes de normalisation du stress **documentées, non
calibrées terrain** (spec 027 §9.2). Les **moteurs** (microclimf,
biljouR, PAI LiDAR) qui produisent les colonnes d’entrée restent à
porter (lots L1/L2, dépendances lourdes en `Suggests`).

## nemeton 0.114.1 (2026-07-02)

#### Fixed — L3 hétérogénéité spectrale sur β-diversité multi-bandes (spec 028)

[`indicateur_l3_het_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_l3_het_spectrale.md)
échouait sur un run réel avec *« l’objet ‘list’ ne peut être converti
automatiquement en un type ‘double’ »*. Cause : la β-diversité
biodivMapR est un raster **multi-bandes** (3 axes PCoA Bray-Curtis) ;
`exact_extract(..., "mean")` renvoie alors un `data.frame` (une colonne
par bande) que [`as.numeric()`](https://rdrr.io/r/base/numeric.html) ne
peut pas coercer. `.aggregate_diversity()` réduit désormais un extract
multi-bandes en **un scalaire par unité** (moyenne des bandes = position
moyenne dans l’espace d’ordination), le comportement mono-bande (B4
α-diversité) restant strictement inchangé. Les unités hors couverture
donnent `NA` (et non `NaN`). Le test épinglait un β mono-bande, d’où le
bug non détecté : ajout d’un cas de régression **multi-bandes**.

## nemeton 0.114.0 (2026-07-02)

#### Added — Indicateur A5 « Rafraîchissement urbain » (LST, spec 032 réorientée)

Nouvel indicateur conditionnel de la famille **A (Air & Microclimat)** :
**A5 « Rafraîchissement urbain »**,
[`indicateur_a5_rafraichissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_a5_rafraichissement.md).
Il mesure la **fraîcheur relative de surface** d’une unité arborée par
rapport à son environnement, à partir d’un raster de **température de
surface (LST)** (Theia Thermocity ECOSTRESS/ASTER) : LST moyenne de
l’UGF comparée à une référence locale (médiane d’un anneau `buffer_m`,
ou `reference` fixe). Score 0-100, **haut = plus frais que l’entour**
(sens direct) — le service de rafraîchissement rendu par l’arbre en
contexte d’îlot de chaleur urbain.

**Source-conditionnel** (comme A3/A4 sans modèle microclimat, R5 sans
FORDEAD) : `lst = NULL` → `A5 = NA` par unité. Rejoint la famille A
(A1-A5) et la config, mais **pas**
[`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md)
(les 31 indicateurs de base). Le sentinelle nodata LST `-32768` est
filtré ; K et °C fonctionnent (l’indice est un écart).

**Réorientation de la spec 032** : le plan initial (A3 « régulation
thermique » = albédo national + LST) est **abandonné** — l’albédo n’est
**pas** un proxy valide de rafraîchissement (le refroidissement vient de
l’ombrage + l’ET ; la canopée a un albédo bas et radiativement
réchauffant → erreur de signe), et la LST, seul signal juste, ne couvre
pas les forêts. L’indicateur est donc **orienté arbre urbain**, là où la
LST existe et est physiquement fondée. Le slot A3 étant déjà pris par
`indicateur_a3_microclimat` (spec 027, microclimat sous couvert), le
nouvel indicateur est **A5**. L’albédo (`cesbio-s2albedo`) n’est **pas**
câblé. Source `theia_lst` (`thermocity-lst`) → `consumed_by: A5`,
couverture urbaine documentée.

## nemeton 0.113.0 (2026-07-02)

#### Added — `build_foret_ancienne_mask()` : couche forêt ancienne pour N2 (spec 031)

Nouvelle fonction exportée
**[`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)**
qui construit la couche `foret_ancienne` consommée par
[`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md)
(continuité forestière) depuis une **source historique fournie par
l’utilisateur**, source-agnostique :

- **vecteur** (sf/sfc) : forêt ancienne déjà vectorisée (Cassini, carte
  d’état-major digitalisée, couche IGN « forêt ancienne ») → validée,
  reprojetée, filtrée par aire ;
- **raster** (SpatRaster) : carte forestière historique → masque dérivé
  par classe (`forest_class`), par seuil (`threshold`) ou `valeur > 0`,
  polygonisé, scindé en taches contiguës, filtré par aire
  (`min_area_m2`).

La sortie (couche sf `foret_ancienne = TRUE`) se passe directement à
`indicateur_n2_continuite(units, foret_ancienne = ...)`.

**Réorientation de la spec 031** : le plan initial (nouvel indicateur
**N4** alimenté par l’imagerie **Corona 4B**) est **abandonné** —
vérification faite, la collection Theia `corona-4b` ne couvre que le
Moyen-Orient (0 item sur la France), et N2 gère **déjà** la forêt
ancienne via son argument `foret_ancienne` (un N4 aurait été redondant).
Le livrable utile est donc ce helper qui produit cette couche, sans
indicateur redondant ni source morte.

## nemeton 0.112.1 (2026-07-02)

#### Fixed — Enrichissement BD Forêt : réparation des géométries invalides

[`enrich_parcels_bdforet()`](https://pobsteta.github.io/nemeton/reference/enrich_parcels_bdforet.md)
**récupère désormais** les couches BD Forêt V2 qui contiennent des
anneaux invalides (p. ex.
`Loop 0 is not valid: Edge N is degenerate (duplicate vertex)`).
Auparavant, une seule géométrie invalide faisait **échouer toute
l’intersection**
([`sf::st_intersection`](https://r-spatial.github.io/sf/reference/geos_binary_ops.html))
→ l’essence et l’âge étaient posés sur **0 UGF**, et les indicateurs
dépendant de l’essence (P1/P2/P3, enrichissement C/B) retombaient
silencieusement sur l’inventaire synthétique CHM (d’où
`qualité bois diamètre = 0`, `CO2 évité = 0`, etc.).

Le correctif tente l’intersection brute puis, en cas d’échec, **répare
les deux couches avec
[`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html)
et réessaie une fois** avant d’abandonner — le coût de réparation n’est
payé que lorsqu’une géométrie est réellement invalide. Observé sur un
run réel (30 UGF, dépt 45) où l’enrichissement passait de 0/30 à
l’ensemble des UGF couvertes.

## nemeton 0.112.0 (2026-07-02)

#### Added — Indicateur T3 « Coupes rases » (SUFOSAT, spec 030)

Nouvel indicateur de la famille **T (Dynamique temporelle)** : **T3 «
Coupes rases »**, exporté via
[`indicateur_t3_coupes_rases()`](https://pobsteta.github.io/nemeton/reference/indicateur_t3_coupes_rases.md).
Il mesure la **pression de coupe rase** sur une unité forestière à
partir du produit national **SUFOSAT** (CNES/CESBIO — détection
submensuelle des coupes rases par changement radar Sentinel-1, France
métropolitaine).

Le score est la **fraction récente coupée à blanc**, pondérée
linéairement par la récence (une coupe de l’an dernier pèse plus qu’une
coupe ancienne), sur une fenêtre glissante (`window_years`, défaut 5
ans) et au-dessus d’un seuil de probabilité (`min_proba`, défaut 0.9).
Le raster `dates` encode la date en `YYDDD` (année 18-25 → 2018-2025,
jour 1-366), `proba` en pourcentage — métadonnées confirmées sur le STAC
Theia MTD réel le 2026-07-02.

Comme **R5 (dépérissement)**, T3 est orienté **« haut = mauvais »** : sa
valeur brute (0-100, haut = plus de coupe) est **inversée à la
normalisation**
([`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md))
pour que sa contribution radar reste « haut = bon » comme T1/T2. Le
calcul est pondéré par la fraction de recouvrement (l’aire des pixels
s’annule — aucun calcul de surface de maille nécessaire).

**Source-conditionnel** (comme R5 sans FORDEAD) : sans raster SUFOSAT,
[`indicateur_t3_coupes_rases()`](https://pobsteta.github.io/nemeton/reference/indicateur_t3_coupes_rases.md)
renvoie `NA` par unité et l’indice général l’ignore. T3 rejoint la
config famille T et la normalisation, mais **pas**
[`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md)
(qui reste les 31 indicateurs de base toujours calculables au NDP 0 — R5
et T3 sont des indicateurs conditionnels d’extension).

Source `sufosat` déclarée dans `inst/datasources/FR.json` (collection
`sufosat` confirmée, assets `dates`/`proba`). Clôt le reliquat Theia
SUFOSAT.

## nemeton 0.111.0 (2026-07-02)

#### Added — MUSCATE, 3ᵉ backend Sentinel-2 de repli souverain (spec 029)

[`stac_search_s2()`](https://pobsteta.github.io/nemeton/reference/stac_search_s2.md)
gagne un troisième backend, **`"muscate"`** (Theia / DATA TERRA,
production MUSCATE-MAJA du CNES/CESBIO), interrogé via l’API STAC MTD
déjà déclarée (`services.theia_stac`,
`https://api.stac.teledetection.fr`). Il s’ajoute au vecteur `source`
par défaut, désormais `c("cdse", "pc", "muscate")` : les backends sont
essayés dans l’ordre et le premier qui renvoie une scène gagne, donc la
source souveraine française **n’est atteinte que si CDSE *et* Planetary
Computer échouent tous les deux**. En marche nominale, le comportement
est strictement inchangé et **aucune requête MUSCATE n’est émise**.

Nouvelle fonction exportée
**[`stac_search_s2_theia_muscate()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)**
: interroge la collection `sentinel2-l2a-theia`, remappe le dialecte de
bandes MUSCATE (bandes exposées sous `B02/B04/B05/B08/B8A/B11/B12`,
adossées aux GeoTIFF FRE) vers les clés nemeton, réduit les hrefs S3 en
chemins `/vsis3/` lisibles par GDAL, filtre le nuage au niveau scène
(`eo:cloud_cover ≤ max_cloud`, parité CDSE/PC) et retourne le **même
tibble normalisé** que les deux autres backends — tout l’aval (cache
COG, FAST, FORDEAD) est inchangé.

Validé par smoke réel (2026-07-02) : la collection
`sentinel2-l2a-theia`, la réflectance FRE (`scale 1.0`, `offset 0.0`,
`nodata -10000` → NDVI/NBR invariants d’échelle) et la propriété
`eo:cloud_cover` sont confirmées sur 5 scènes réelles (T31TGN/T31UGP).
La lecture S3 des COG au moment d’une ingestion de repli nécessite les
identifiants `services.theia_s3`.

Source `s2_l2a_muscate` d’`inst/datasources/FR.json` mise à jour
(collection confirmée, produit FRE documenté). Clôt le reliquat «
Sources Theia » pour MUSCATE (PLAN.md).

## nemeton 0.110.1 (2026-07-01)

#### Fixed / Added — Cache des sorties biodivMapR (B4/L3, spec 028)

[`compute_spectral_diversity()`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
gagne un argument `reuse_existing = TRUE` : quand `output_dir`
(persistant, p. ex. un cache projet) contient déjà les rasters de
diversité α/β d’un run précédent, ils sont **réutilisés** au lieu de
relancer le coûteux pipeline biodivMapR (PCA + k-means). Le résultat
expose un champ `reused`. Le `output_dir` par défaut
([`tempfile()`](https://rdrr.io/r/base/tempfile.html)) reste toujours
neuf, donc aucun cache-hit accidentel.

Complément au fix côté `nemetonshiny` (persistance des sorties sous
`<project>/cache/layers/spectral/<scene>`) qui corrige l’erreur
`[readStart] file does not exist: …/shannon_sd.tiff` (SpatRaster lazy
dont le tempfile était supprimé avant lecture par B4/L3).

## nemeton 0.110.0 (2026-07-01)

#### ⚠️ Relicence — MIT → **GPL-3**

À partir de cette version, `nemeton` est distribué sous **GPL-3**
(auparavant MIT). Motif : intégration en **dépendance directe**
(`Imports:`) du package
[`biodivMapR`](https://github.com/jbferet/biodivMapR) (GPL-3) pour les
nouveaux indicateurs de diversité spectrale. `nemeton` devient donc une
œuvre dérivée copyleft ; par effet de dépendance, les packages qui
l’importent (`nemetonshiny`, `tree_sat_nemeton`, `maestro_nemeton`) sont
GPL-3 à la distribution (bascule à faire dans leurs dépôts). Les
**données** produites restent CC-BY 4.0. Décision assumée du
propriétaire (ADR-006 à amender).

#### Added — Diversité spectrale : indicateurs **B4** & **L3** (biodivMapR, spec 028)

Deux nouveaux indicateurs télédétectés, calculables dès le **NDP 0**
(Sentinel-2), via l’hypothèse de variation spectrale (PCA → spectral
species → diversité) :

- **B4 — Diversité spectrale** (famille B) : α-diversité, **Shannon**
  des spectral species → proxy de diversité compositionnelle.
- **L3 — Hétérogénéité spectrale** (famille L) : β-diversité, turnover
  **Bray-Curtis** de la mosaïque paysagère (complémentaire de L2,
  fragmentation géométrique).

Portés par la primitive exportée
[`compute_spectral_diversity()`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
(wrapper
[`biodivMapR::biodivMapR_full()`](https://rdrr.io/pkg/biodivMapR/man/biodivMapR_full.html),
agrégation par UGF via `exactextractr`). Fonctions
[`indicateur_b4_div_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_b4_div_spectrale.md)
/
[`indicateur_l3_het_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_l3_het_spectrale.md)
strictement rétrocompatibles (colonne `NA` si ni `spectral` ni
`reflectance`). Enregistrés dans le registre (labels/tooltips FR/EN avec
caveat proxy), normalisation *haut = mieux* (B4 `[0, log 50]`, L3
`[0, 1]` — **bornes provisoires**, recalibrage empirique après premier
run réel, spec 028 D3). B4/L3 comptent immédiatement dans l’indice
général (D4).

**Statut proxy** : la corrélation diversité spectrale ↔︎ diversité
taxonomique est un proxy contexte-dépendant, à **valider terrain**
(démarche spec 008). Une futaie régulière monospécifique légitime peut
afficher un B4 bas. Tests : `test-spectral-diversity.R` (le pipeline
biodivMapR réel = smoke manuel sur scène Sentinel-2).

## nemeton 0.109.0 (2026-07-01)

#### Changed — Dette H_dom faible/nul : peuplement jeune, garde-fou CHM, P2 station (spec 005 §3.5)

Trois angles morts laissés par le correctif « couvert nul » (v0.107.0),
tous sur la sémantique d’un H_dom faible ou nul :

- **\#2 — peuplement jeune `[1,3 ; 6)` m.** Nouveau paramètre
  `min_merchantable_height` (défaut **6 m**, plancher de calibration de
  l’allométrie) sur
  [`estimate_synthetic_inventory()`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md)
  /
  [`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md)
  : en deçà, `dbh = 0` et `density = 0` (pas de stock **marchand**) →
  P1/P3/E1 = 0 au lieu de `NA`. Le test porte sur la **hauteur**, pas
  sur `is.na(D_g)` : un peuplement grand à espèce manquante reste `NA`
  (réellement inconnu), jamais forcé à 0. Rétro-compat v0.107.0 :
  `min_merchantable_height = min_stand_height`.
- **\#3 — P2 station sur couvert nul.**
  [`compute_site_index()`](https://pobsteta.github.io/nemeton/reference/compute_site_index.md)
  gagne `min_stand_height = 1.3` : un CHM nu (H_dom = 0) renvoie
  **`NA`** (indice de station non estimable depuis un peuplement abattu)
  au lieu d’un clamp parasite vers la pire classe. Cohérent avec P1 = 0
  (aucun volume marchand *actuel*) mais P2 = `NA` (fertilité potentielle
  *inconnue*).
- **\#1 — garde-fou CHM dégénéré.**
  [`estimate_synthetic_inventory()`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md)
  émet un
  [`cli::cli_warn`](https://cli.r-lib.org/reference/cli_abort.html) et
  pose `attr(x, "chm_suspect") = TRUE` (propagé par
  [`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md))
  quand ≥ `suspect_frac` (défaut 0,95) des unités sont sous le plancher
  marchand **et** que le max global du CHM l’est aussi — un CHM cassé
  (prédiction ratée tout-à-0) ne passe plus pour une coupe rase
  silencieuse.

Non-régression : peuplement établi inchangé, `H_dom = NA` reste `NA`.
Tests : `test-synthetic-inventory-debt.R` (+ mises à jour clear-cut /
site-index).

## nemeton 0.108.0 (2026-07-01)

#### Added — `extract_indicator_value()` : convention de nommage des indicateurs, source unique

Extrait la valeur d’un indicateur depuis son résultat (`sf`/`data.frame`
→ colonne code court `P1`/`R1`/…, ou vecteur renvoyé tel quel).
Auparavant, cette convention était **dupliquée** entre
`nemeton::compute_indicator()` (dérivation code court) et la boucle de
calcul de `nemetonshiny` (un `col_map` de 17 entrées tenu à la main) —
deux implémentations vouées à **diverger**.

- `compute_indicator()` délègue désormais à
  [`extract_indicator_value()`](https://pobsteta.github.io/nemeton/reference/extract_indicator_value.md).
- `nemetonshiny` appelle la **même** fonction (à partir de
  `nemeton >= 0.108.0`), supprimant son `col_map` : une seule source de
  vérité, plus de dérive possible.
- Ordre de résolution : code court dérivé du nom → nom NMT → motif
  `"<Lettre><chiffre>"` (préférant une colonne absente de `exclude`,
  pour que la valeur fraîchement calculée l’emporte sur un attribut
  préexistant).

Tests : `test-indicators-core-dispatch.R`.

## nemeton 0.107.1 (2026-07-01)

#### Fixed — `compute_indicator()` / `nemeton_compute()` : dispatch robuste (args + colonne de sortie)

Le dispatcher interne appelait chaque fonction indicateur avec
`do.call(func, list(units, layers, ...))` : les indicateurs qui ne
déclarent **ni `layers` ni `...`** (`indicateur_p1_volume`, `p2`, `p3`,
`e1`, `e2`) échouaient sur `unused argument (layers = …)`, et
l’extraction de la colonne de sortie ne connaissait que `R1-R4` (les
P/C/E renvoyant un `sf` cassaient sur « column not found »).
[`nemeton_compute()`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)
était donc inutilisable pour ces indicateurs.

- Les arguments (`units`, `layers`, `...` p.ex. `chm`) sont désormais
  **filtrés sur les [`formals()`](https://rdrr.io/r/base/formals.html)**
  de la fonction cible ; une fonction avec `...` reçoit tout, une
  fonction sans reçoit seulement ce qu’elle déclare.
- L’extraction de la valeur depuis un résultat `sf`/`data.frame` est
  **généralisée** : code court dérivé du nom (`indicateur_p1_volume` →
  `P1`), puis nom NMT, puis toute colonne `"<Lettre><chiffre>"` — plus
  de table `col_map` R1-R4 à maintenir.

`nemeton_compute(units, layers, indicators = "indicateur_p1_volume", chm = chm)`
renvoie maintenant un P1 exploitable. Tests :
`test-indicators-core-dispatch.R`. (L’app `nemetonshiny` n’utilise pas
ce dispatcher — elle a sa propre boucle par
[`formals()`](https://rdrr.io/r/base/formals.html) — donc aucun impact
côté app ; c’est un correctif de l’API cœur exportée.)

## nemeton 0.107.0 (2026-07-01)

#### Fixed — coupe rase : inventaire synthétique CHM « couvert nul » → volume 0, plus NA

Sur une parcelle **rasée** (coupe rase), le CHM Open-Canopy est correct
mais à hauteur ≈ 0.
[`estimate_synthetic_inventory()`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md)
renvoyait alors `dbh`/`density` = **NA** (la garde « H_dom \< 6 m ⇒
allométrie non calibrée » confondait *couvert nul* et *peuplement trop
jeune*), d’où **P1, P3, E1 tous NA**, E2 dégénéré à 0, et **famille
Énergie absente** — au lieu du résultat correct : volume ≈ 0, E1 ≈ 0,
famille Énergie **présente à 0**.

- Nouveau paramètre `min_stand_height` (défaut **1,3 m**, hauteur de
  référence du dbh) sur
  [`estimate_synthetic_inventory()`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md)
  et
  [`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md)
  : une unité dont H_dom est **observé** (non-NA) mais **sous** ce seuil
  est traitée comme **sans peuplement** → `dbh = 0`, `density = 0` (au
  lieu de NA). P1 = 0, E1 = 0, P3 défini bas. Un `H_dom` `NA` (pas de
  couverture CHM) **reste NA**.
- Trois régimes distingués : `NA` (inconnu) / `< 1,3 m` (pas de
  peuplement → 0) / `[1,3 ; 6) m` (jeune, allométrie non calibrée → NA,
  inchangé) / `≥ 6 m` (inchangé). Correctif **côté cœur** : vaut quel
  que soit le wiring CHM de l’app.
- Amendement spec 005 §3.4. Tests :
  `test-synthetic-inventory-clearcut.R` (couvert nul → 0, non-régression
  peuplement établi, NA hors couverture).

## nemeton 0.106.0 (2026-07-01)

#### Added — `prepare_pixel_dieback_series()` : dérivés pixel CRswir/CRre pour la planche de suivi

Prépare, côté cœur, tout le dérivé consommé par la planche plotly «
pixel » (suivi pluriannuel du dépérissement, CRswir = eau / CRre =
chlorophylle) de `nemetonshiny` — pour que le rendu app reste sans
logique métier (règle 3). Transformation **pure et testée** de la sortie
de
[`read_reconfort_pixel_series()`](https://pobsteta.github.io/nemeton/reference/read_reconfort_pixel_series.md)
:

- grille régulière + gap-fill linéaire
  ([`stats::approx`](https://rdrr.io/r/stats/approxfun.html), équivalent
  iota2) ;
- lissage **léger** Savitzky-Golay
  ([`signal::sgolayfilt`](https://rdrr.io/pkg/signal/man/sgolayfilt.html),
  `p=2`, `n=5`) — le lissage fort n’est volontairement pas offert (il
  raboterait les extrema estivaux, qui *sont* le signal) ;
- **extrema estivaux annuels** mesurés sur les observations réelles
  (creux CRswir `which.min`, pic CRre `which.max`) ;
- **espace d’état** estival apparié + **centroïdes annuels** ;
- **lacunes** interpolées longues (`> gap_flag_days`) signalées.

Renvoie une liste de `data.frame` (`grid_swir/re`, `obs_swir/re`,
`trough_swir`, `peak_re`, `state`, `centroids`, `gaps`) et reporte les
attributs RECONFORT (`species`, `v_model`, `date_from/to`,
`dans_zone_validite`). Nouvelle dépendance `signal`. Partie A du brief
planche pixel ; la Partie B (rendu plotly 4 panneaux) vit dans
`nemetonshiny`.

## nemeton 0.105.0 (2026-07-01)

#### Fixed — cache FAST : clé sur la couverture S2 réelle, plus sur la fenêtre demandée

Le COG d’alerte FAST
([`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md))
était content-addressé (spec 017 D6) en incluant `date_from`/`date_to`
**demandés** dans le hash ET le nom de fichier. Avec une fenêtre
glissante ancrée sur aujourd’hui (`date_to = today`), ces bornes
bougeaient chaque jour → nom + hash différents → **recalcul complet
quotidien** du diagnostic, alors qu’aucune scène Sentinel-2 nouvelle
n’avait atterri (revisite S2 ~5 j).

- La clé de cache (hash D6 + nom) est désormais la **couverture S2
  effective** : `min`/`max` des dates d’acquisition des scènes retenues
  (`scenes_df$obs_date`), et non la fenêtre demandée. Deux fenêtres
  couvrant les mêmes scènes retombent sur le **même** COG (cache hit) ;
  la liste des scene-ids reste dans le hash, si bien que deux ensembles
  de scènes distincts ne s’aliasent jamais à couverture min/max
  identique.
- Mode `rolling` : la fenêtre glissante est ancrée sur la **dernière
  acquisition réelle** (`cov_to`) plutôt que sur `date_to` demandé —
  cohérent avec la clé et plus juste (« fenêtre jusqu’à la dernière
  observation »).
- Effet de bord unique : le changement de hash **invalide une fois** les
  COGs FAST en cache ; ils se régénèrent au prochain calcul.

Nouveau test `test-fast-alert-raster.R` : deux fenêtres demandées
différentes couvrant la même scène ⇒ un seul COG, second appel servi
depuis le cache.

## nemeton 0.104.0 (2026-07-01)

#### Added — garde-fou d’année RECONFORT : `reconfort_latest_complete_year()` / `reconfort_year_bounds()`

RECONFORT ne compare pas deux dates : il classe la trajectoire d’indices
**~2 ans** d’un pixel avec un modèle pré-entraîné, sur une fenêtre
d’analyse **liée au modèle** qui se termine à `s2_year<edate>` (`10-29`
pour les modèles 2 ans `v3`/`v3_chestnut`/`v3_pine`, `05-31` pour
`v3_early_may`). Lancer un run sur une `s2_year` dont la fenêtre n’est
pas encore close produit une dernière saison tronquée et une
classification dégradée.

- `RECONFORT_MODELS` porte désormais un champ **`edate`** (`"MM-DD"`,
  fin de la fenêtre d’analyse du modèle), source unique alignée sur le
  pipeline IOTA2.
- **`reconfort_latest_complete_year(v_model, today, lag_days)`** :
  dernière `s2_year` dont la fenêtre est déjà close à `today` (année en
  cours si sa fenêtre est passée, sinon année précédente). `lag_days`
  ajoute un tampon pour la latence d’ingestion Theia.
- **`reconfort_year_bounds(v_model, today, lag_days)`** :
  `list(min = 2016, max, default)` prêt à câbler un year-picker (défaut
  et max = dernière année complète, jamais l’année en cours incomplète).

Ces fonctions sont destinées au picker `s2_year` de `nemetonshiny`
(défaut/max bornés côté cœur, garde-fou serveur au lancement).

## nemeton 0.103.0 (2026-06-30)

#### Added — `run_reticulate_isolated()` : tâche Python dans un sous-processus à env épinglé

reticulate ne peut lier qu’**un seul Python par session R**. Quand
plusieurs charges Python ont besoin d’**environnements différents** dans
la même session (Open-Canopy conda, FORDEAD virtualenv, Theia…), elles
ne peuvent pas toutes passer par reticulate in-process — la première à
se lier gagne, les autres échouent (cf. incident CHM Open-Canopy :
reticulate happé par un Python uv éphémère → P1/P2/P3/E1 en échec).

`run_reticulate_isolated(fun, args, python | virtualenv | condaenv, show)`
exécute `fun` dans un **sous-processus `callr`** dont reticulate est
épinglé sur l’interpréteur demandé. Le sous-processus part d’un
reticulate **vierge** → il se lie toujours au bon env, **quel que soit**
le binding de la session parente. `R_ENVIRON_USER = ""` empêche un
`~/.Renviron` d’écraser le pin. C’est l’alternative déterministe à un
`RETICULATE_PYTHON` global (qui ne peut servir qu’un seul env). `fun`
doit être auto-suffisant (callr le sérialise : qualifier `pkg::fn`,
échanger les rasters par **chemins** de fichiers). Repli in-process si
`callr` absent ou aucun Python résoluble. `callr` ajouté aux `Suggests`.
8 tests (`test-reticulate-isolated.R`).

Primitive réutilisable pour isoler les workloads reticulate :
Open-Canopy (déjà câblé côté `nemetonshiny` v0.94.5.9001) et, à terme,
le bloc modèle FORDEAD (étape dédiée, à valider sur un vrai run).

## nemeton 0.102.0 (2026-06-30)

#### Added — reGénération L2 : sensibilité microclimatique R6 + années E-OBS

Deuxième lot du chantier reGénération (spec 027 / ADR-014).

- `indicateur_r6_sensibilite(units, micro_moyenne, micro_canicule, …)` —
  **R6** (famille R) : sensibilité du microsite à une année chaude = Δ
  stress entre un été **canicule** et un été **moyen** (canopée figée),
  combinant ΔT°max et ΔVPD standardisés. Normalisé 0–100 **décroissant**
  (peu sensible / résilient = 100). Sens « haut = bon » → pas
  d’inversion (contrairement à R5 dépérissement). Colonnes `R6`,
  `R6_dtmax`, `R6_dvpd`, `R6_couverture_pct` + flag
  `microclimate_model`. Famille R étendue à R1…R6
  (`indicator-config.R`).
- `microclimate_detect_years(eobs, aoi, year_window, lidar_year)` +
  `R/microclimate_years.R` : **détection automatique** des années «
  moyenne » / « canicule » depuis la série estivale E-OBS (été le plus
  chaud vs médiane climatologique), avec **départage** vers l’année
  proche du LiDAR (limite le biais canopée figée) et `year_window`.
  Sélecteur pur testable ; l’extraction E-OBS raster/netcdf est différée
  (donnée requise) — passer un vecteur nommé
  `année -> indice de chaleur estivale`, ou choisir les années
  manuellement (override utilisateur, spec 027 §6bis).
- 33 tests (`test-indicators-microclimate.R` 23,
  `test-microclimate-years.R` 10).

À suivre : L3 (composite par essence `regeneration_index`), L4 (onglet
`nemetonshiny`), L5 (doc).

## nemeton 0.101.0 (2026-06-30)

#### Added — reGénération : indicateurs microclimatiques sous couvert (spec 027 L1)

Premier lot du chantier **reGénération** (aptitude microclimatique à la
régénération forestière, spec 027 / ADR-014). Trois sous-indicateurs
insérés dans les familles existantes — **pas de 13e famille, radar 12
axes préservé** :

- `indicateur_a3_microclimat(units, micro, …)` — **A3** : T°max estivale
  (JJA) sous couvert ; normalisé 0–100 décroissant (frais = 100).
- `indicateur_a4_tamponnement(units, micro, …)` — **A4** : tamponnement
  de la canopée (écart T°max découvert − sous couvert) ; croissant
  (tamponné = 100).
- `indicateur_w4_vpd(units, micro, …)` — **W4** : VPD estival sous
  couvert ; décroissant (humide = 100).

Chaque indicateur consomme un jeu de rasters microclimat `micro` (liste
nommée `tmax_understorey` / `tmax_open` / `vpd`), agrège par UGF
(couverture-pondérée), écrit la colonne score 0–100 (code court, détecté
par `create_family_index`) + la valeur brute + `couverture_pct`, et pose
le flag `augmented = "microclimate_model"` (amende ADR-011, nouveau flag
dans
[`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)).
Familles A (→4) et W (→4) étendues dans `indicator-config.R`
(labels/tooltips FR/EN). Sens « haut = bon » → pas d’inversion. 16 tests
(`test-indicators-microclimate.R`).

- [`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
  — **scaffold** : valide les dépendances lourdes (en `Suggests` :
  `microclimf`, `mcera5`, `ecmwfr`, `lidR`) et définit le contrat
  `micro` ; l’orchestration microclimf complète (forçage ERA5-Land +
  structure LiDAR HD, repli opencanopy) sera câblée dans un incrément
  ultérieur (données requises). En attendant, les indicateurs acceptent
  un `micro` précalculé.
- Registre de sources `FR.json` étendu : `era5_land`, `eobs`,
  `lidarhd_mnt/mnh/nuage`.

À suivre : L2 (`indicateur_r6_sensibilite`, années auto E-OBS), L3
(composite par essence), L4 (onglet `nemetonshiny`).

## nemeton 0.100.1 (2026-06-30)

#### Fixed — `reconfort_cache_manifest()` lit le dossier IOTA² `final/`

La v0.100.0 ne cherchait les couches que dans
`zone_<id>/reconfort_*_<run>.tif`, or **les rasters d’affichage
persistent ailleurs** : dans le dossier de sortie IOTA²
`output_zone_<id>/results/iota2_results_classif_labels-z<id>-S2_*/final/`
(`Final_continuous_score_masked*.tif`, `Final_Classif_masked_*.tif`,
`Final_Proba_map_masked*.tif`). Pour les runs déjà en cache (sans copies
run-scopées score/proba), la fonction ne retournait donc que la
classification.

[`reconfort_cache_manifest()`](https://pobsteta.github.io/nemeton/reference/reconfort_cache_manifest.md)
découvre désormais **en priorité le dossier `final/`** (les 3 couches,
repli sur `Classif_Seed_0`/`ProbabilityMap_seed_0`), avec repli sur les
copies run-scopées `zone_<id>/` quand `final/` est absent (workdir
nettoyé) ou pour un `run_id` ancien. Validé sur le cache réel zone 5 (3
couches retournées). 9 tests ajoutés.

## nemeton 0.100.0 (2026-06-30)

#### Added — Découverte cache des couches RECONFORT (`reconfort_cache_manifest()`)

Pendant cache de
\[[`reconfort_layer_manifest()`](https://pobsteta.github.io/nemeton/reference/reconfort_layer_manifest.md)\]
: reconstruit le manifeste des couches d’un run RECONFORT depuis les
rasters persistés sous le cache projet, **sans** le `result` en mémoire.
Permet à l’app de **réafficher les rasters RECONFORT après un
rechargement de projet** (parité
[`read_fordead_layer()`](https://pobsteta.github.io/nemeton/reference/read_fordead_layer.md)
/
[`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md),
qui lisent leurs couches depuis le cache).

- `reconfort_cache_manifest(cache_dir, zone_id, run_id = NULL, include_range = FALSE)`.
  Résout le run (`run_id` fourni, sinon le plus récent du cache zone),
  découvre les rasters d’affichage run-scopés et renvoie un `data.frame`
  **byte-identique** à `reconfort_layer_manifest(result)` (mêmes
  colonnes/types/indications de rendu) → l’app réutilise telle quelle sa
  machinerie (`read_reconfort_layer`, cache rasters, toggles, opacité).
  Les stacks CRswir/CRre (série temporelle, diagnostic pixel) sont
  exclus ; les alertes viennent de la table `alert`. Best-effort :
  cache/zone/run absent → `data.frame` 0 ligne.
- **Persistance étendue** : la phase `persist` de
  [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  copie désormais aussi le **score continu** et la **probabilité** dans
  le cache zone (`reconfort_score_<run_id>.tif`,
  `reconfort_proba_<run_id>.tif`), run-scopés à côté de
  `reconfort_mask_<run_id>.tif` — sans ça, ces couches (qui ne vivaient
  que dans le workdir transitoire) ne réapparaissaient pas après
  rechargement. Refactor : constructeur de lignes partagé
  `.reconfort_build_manifest()` (source unique du schéma).
- 18 tests (`test-reconfort-cache-manifest.R`).

## nemeton 0.99.1 (2026-06-29)

#### Fixed — sens de R5 dans la famille R / le radar (orientation inversée)

[`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md)
laissait passer **R5 dépérissement** tel quel, alors que sa valeur brute
est orientée « **haut = plus de dépérissement** » (mauvais), à l’inverse
de R1-R4 (« haut = faible risque », bon). Folder R5 brut dans la moyenne
de la famille R (`create_family_index`) tirait donc le score **dans le
mauvais sens** : une UGF très dépérie *remontait* `famille_risque` et
l’indice général.

[`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md)
**inverse désormais R5** (`100 - score`) pour les colonnes
`indicateur_r5_deperissement` / `R5`, de sorte que sa contribution au
radar et à `famille_risque` reste « haut = bon » comme R1-R4 (cf. le cas
s1/s2 distances déjà inversé au même endroit). La fonction
[`indicateur_r5_deperissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md)
et ses appelants sont **inchangés** (le score brut « haut =
dépérissement » reste l’API publique) ; seule la valeur normalisée du
radar est retournée. Tooltip R5 reformulé en conséquence (« Score élevé
= faible dépérissement ») et corrigé (R5 couvre FORDEAD **et** RECONFORT
depuis L4, plus seulement les résineux).

Bug **latent** : R5 n’est pas encore agrégé dans le radar côté
`nemetonshiny` (famille R = R1-R4 ; R5 « future »). Le correctif
garantit la bonne orientation le jour du branchement. 3 tests ajoutés
(`test-normalization.R`).

## nemeton 0.99.0 (2026-06-29)

#### Added — Filtre des alertes au polygone UGF (`filter_alerts_to_zone()`, L7)

Contrepartie vectorielle du masquage raster au read-time
([`read_reconfort_layer()`](https://pobsteta.github.io/nemeton/reference/read_reconfort_layer.md)
/
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
/
[`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md),
spec 016) : ne garde que les **centroïdes d’alertes situés dans le
polygone des UGFs**, pour qu’un visualiseur n’affiche plus d’alertes
hors du périmètre géré.

Motivation (révision de la décision L7 §D3) : un run réel a montré que
le vecteur d’alertes RECONFORT débordait largement des UGFs — les
centroïdes sont extraits du `Final_Classif_masked_<year>.tif`, masqué
par OSO **feuillus** (occupation du sol) et **pas** par l’UGF, donc les
clusters couvrent tous les feuillus de la bbox + 3 km. Les rasters
étaient déjà clippés (v0.98.0), mais pas le vecteur.

- `filter_alerts_to_zone(alerts, con = NULL, zone_id = NULL, apply_zone_mask = TRUE, mask_polygon = NULL)`
  — **helper unique partagé par les 3 pipelines** (RECONFORT, FORDEAD,
  FAST) : le filtre `sf` POINT est identique, donc une seule fonction
  donne la vraie parité. Réutilise
  [`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md)
  ; nouvel interne `.filter_alerts_to_zone()` (miroir de
  [`.apply_zone_mask()`](https://pobsteta.github.io/nemeton/reference/dot-apply_zone_mask.md)).
- Filtre au **read/display**, la table `alert` n’est pas modifiée
  (principe spec 016 « masque au read, pas au write ») ; provenance
  `zone_id` conservée.
- Reprojette le polygone au CRS des alertes ; `cli_warn` + passthrough
  si rien n’est résoluble ; opt-out `apply_zone_mask = FALSE`. 8 tests
  (`test-filter-alerts-to-zone.R`).

Côté `nemetonshiny` (v0.93.x+) : passer la couche d’alertes par
[`filter_alerts_to_zone()`](https://pobsteta.github.io/nemeton/reference/filter_alerts_to_zone.md)
avant le rendu (RECONFORT **et** FORDEAD).

## nemeton 0.98.0 (2026-06-28)

#### Added — RECONFORT : reader des couches masqué à l’UGF (`read_reconfort_layer()`, L7)

Nouvelle fonction exportée qui lit une couche raster d’un run RECONFORT
et la **masque au polygone des UGFs par défaut**
(`apply_zone_mask = TRUE`), pixels hors périmètre géré = `NA`. C’est
l’analogue de
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
et
[`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md)
(spec 016) : RECONFORT atteint enfin la **parité** des trois pipelines
de suivi, et le masque spatial vit dans le cœur `nemeton` plutôt que
dans la présentation (spec 021 L7, ADR-013 amendement A6).

- `read_reconfort_layer(layer, con = NULL, zone_id = NULL, apply_zone_mask = TRUE, mask_polygon = NULL)`.
  `layer` est un chemin de raster **ou** une ligne raster du manifeste
  [`reconfort_layer_manifest()`](https://pobsteta.github.io/nemeton/reference/reconfort_layer_manifest.md)
  (une ligne `type == "vector"` — les centroïdes d’alertes — est rejetée
  : le vecteur n’est pas masqué ici).
- Masque appliqué au **read** (principe spec 016 « masque au read, pas
  au write ») : les `.tif` IOTA² ne sont pas réécrits. Réutilise les
  helpers spec 016
  [`.apply_zone_mask()`](https://pobsteta.github.io/nemeton/reference/dot-apply_zone_mask.md)
  /
  [`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md).
- Polygone résolu depuis `mask_polygon` explicite, sinon `con` +
  `zone_id` ; si rien n’est résoluble alors que le masque est demandé :
  `cli_warn` + raster brut (best-effort, parité spec 016). Opt-out
  `apply_zone_mask = FALSE`.
- 11 tests (`test-reconfort-reader.R`).

Côté `nemetonshiny` (v0.93.x+) : consommer ce reader et **retirer le
[`terra::mask`](https://rspatial.github.io/terra/reference/mask.html)
local** introduit en v0.92.3 (le clip UGF revient au cœur).

## nemeton 0.97.0 (2026-06-28)

#### Added — RECONFORT : manifeste des couches d’un run (`reconfort_layer_manifest()`)

Nouvelle fonction exportée côté cœur qui traduit le résultat de
[`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
en un `data.frame` plat décrivant les **couches affichables** d’un run
RECONFORT — le **score** continu de dépérissement, la **classification**
par pixel, la carte de **probabilité** et les **alertes** (centroïdes) —
avec les indications de rendu dont un visualiseur a besoin (`palette`,
`reverse`, domaine `vmin`/`vmax`, `categorical`, `default_visible`,
`default_opacity`, `n_features`).

La sémantique d’une sortie RECONFORT (ce qu’une couche *est*, comment
ses valeurs sont normalisées, le sens de la palette) est une
connaissance métier : elle reste dans le cœur `nemeton` (ADR-009, règles
strictes §1-3). Une couche de présentation (`nemetonshiny`) consomme le
manifeste tel quel pour générer ses cases à cocher de calques et son
curseur d’opacité, sans coder en dur la moindre sémantique RECONFORT.

Seules les couches **disponibles** sont listées (un raster au chemin
`NA` — variantes masquées absentes tant que le masquage n’a pas tourné —
est ignoré ; la ligne d’alertes n’apparaît que si le run a produit au
moins une alerte). Les domaines de valeurs sont *nominaux* par défaut
(score `1..100`, probabilité `0..1000`) ; `include_range = TRUE` les
remplace par le min/max réel lu via (best-effort). 29 tests unitaires
(`test-reconfort-manifest.R`).

Débloque le câblage de l’affichage des couches RECONFORT (toggles +
opacité) côté `nemetonshiny` (brief fourni).

## nemeton 0.96.1 (2026-06-28)

#### Fixed — RECONFORT : IOTA² séquentiel en mode AOI (évite le kill systemd-oomd)

Un run RECONFORT en mode AOI (`aoi_crop = TRUE`) lançait quand même
IOTA² avec `scheduler_type = "localCluster"` : un cluster Dask de
~`nb_cpus` workers, chacun chargeant la pile de features multi-dates.
Sur une AOI minuscule c’est inutile et ça crée une **pression mémoire**
qui a fait tuer toute la session R/RStudio par **`systemd-oomd`** en
pleine classification (incident 2026-06-28 : « Killed app-rstudio…scope
due to memory pressure … 54.29 % \> 50.00 % »). Le pipeline force
désormais `scheduler_type = "debug"` (séquentiel, mémoire plate, sans
coût de temps réel sur une AOI) quand `aoi_crop = TRUE` — comme il force
déjà `number_of_chunks = 1`. Un `scheduler_type` explicite
non-`localCluster` reste respecté.

## nemeton 0.96.0 (2026-06-28)

#### Added — RECONFORT : progression fine de l’ingestion S2 (console + app)

L’ingestion S2 streaming (la phase la plus longue, ~4 min/scène limité
par GEODES) n’émettait qu’un événement de phase global `ingest` : des
heures de silence côté console et application.
[`reconfort_ingest_s2()`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)
accepte désormais un `progress_callback` et émet, en mode AOI streaming
:

- `reconfort:ingest_listed` (`tile`, `total`) dès que le manifeste
  GEODES est connu ;
- `reconfort:ingest_item` par scène (`tile`, `completed`, `total`,
  `step` ∈ `download`/`crop`/`done`/`cached`/`failed`, `item_date`).

Le pipeline
([`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md))
relaie son `progress_callback` à l’ingestion, et la console affiche
désormais le détail par scène (« downloading 94/140 … », « extracting +
cropping … », « cropped »). Côté `nemetonshiny`, ces événements
alimentent le bandeau de progression (comme FORDEAD / l’ingestion FAST).
Rétrocompatible : sans `progress_callback` (ou en mode full-tile) le
comportement est inchangé.

## nemeton 0.95.1 (2026-06-28)

#### Fixed — RECONFORT : filtre `PYTHONWARNINGS` urllib3 invalide

Le filtre qui masque l’`InsecureRequestWarning` d’urllib3 pendant
l’ingestion S2 le référençait par **catégorie**
(`ignore::urllib3.exceptions.InsecureRequestWarning`). Python rejette ce
filtre au démarrage de l’interpréteur
(`Invalid -W option ignored: invalid module name: 'urllib3.exceptions'`)
car le module tiers n’est pas importable à ce stade : le filtre était
donc ignoré (et le warning urllib3 réapparaissait). Il est désormais
matché par **message** (`ignore:Unverified HTTPS request`), qui ne
requiert aucun import. Le filtre `ignore::UserWarning` (catégorie
standard) est inchangé. Validé dans l’env conda `nemeton-reconfort`.

## nemeton 0.95.0 (2026-06-27)

#### Added — RECONFORT : ingestion S2 en streaming, crop AOI à la volée (spec 021)

L’ingestion Sentinel-2 de RECONFORT matérialisait la **tuile MGRS
entière** (~211 GB d’archives + ~250 GB de scènes extraites, ~460 GB
transitoires) **avant** que le crop AOI ne tourne — pour ~60 pixels
utiles. C’est ce qui saturait le disque (incident Mouthe / T31UFQ,
2026-06-27).

[`reconfort_ingest_s2()`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)
gagne un **mode AOI streaming** (activé dès qu’un `aoi` est fourni — le
chemin de production) : **un seul search GEODES par tuile**, puis chaque
archive est **téléchargée → extraite → clippée + reprojetée à la fenêtre
AOI → supprimée**, une à la fois. Le pic disque tombe à **~une archive
(quelques GB)**. Rétrocompatible : `aoi = NULL` conserve le comportement
full-tile v0.94.x.

- Deux scripts python **nemeton-authored** (pas vendorés) :
  `list_s2_items.py` (1 search → 1 STAC JSON par item + `manifest.json`)
  et `download_s2_item.py` (`Item.from_dict` →
  `download_item_archive(outfile=)`, une archive). Le round-trip
  `to_dict`/`from_dict` a été validé sur GEODES réel — pas de re-search
  par item, donc pas de rate-limit.
- `.reconfort_crop_scene_to_aoi()` factorisé (crop par scène, SRE
  ignorées), `.reconfort_ingest_tile_streaming()` orchestre la boucle
  (idempotente via des marqueurs `ingested/<tile>/<id>.done` ; un item
  en échec est loggé puis ignoré, abort seulement si aucune scène n’est
  produite).
- [`reconfort_ingest_s2()`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)
  : nouveaux arguments `aoi`, `target_crs`, `buffer_m`.
- [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  (`aoi_crop = TRUE`) câble le streaming dans la PHASE 5 du pipeline ;
  le crop post-extraction séparé (`extracted_aoi/`) disparaît, les
  scènes cropées atterrissent directement dans `extracted/<tile>/`.

#### Changed

- [`reconfort_ingest_s2()`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)
  ne télécharge plus la tuile entière quand un `aoi` est fourni (voir
  ci-dessus). Le contrat de la fonction évolue (bump mineur), mais
  l’appel historique sans `aoi` reste identique.

## nemeton 0.94.3 (2026-06-27)

#### Fixed — RECONFORT : robustesse de l’ingestion S2 (console + disque)

**Console lisible.** Le diagnostic noyait ses messages utiles sous des
centaines de warnings bénins émis par les dépendances du téléchargeur
vendoré (`pygeodes` / `urllib3`) : un `UserWarning` « *file with same
content already exists, skipping download* » par scène en cache (jusqu’à
140 par tuile) et le `InsecureRequestWarning` d’urllib3 (pygeodes
appelle le portail GEODES du CNES avec la vérification TLS désactivée,
choix de l’amont). `.reconfort_run_py()` pose désormais `PYTHONWARNINGS`
autour du sous-processus conda pour filtrer **uniquement ces deux
catégories** ; erreurs, tracebacks et stdout intacts.

**Saturation disque.** Une tuile entière sur deux ans, c’est ~200 GB de
zips **plus** ~250 GB de scènes extraites conservés simultanément : le
disque se remplissait et `zipfile.extractall` mourait sur un `exit 1`
opaque (`OSError [Errno 28]`) à mi-extraction. Deux parades :

- **extract-then-delete** (`reconfort_ingest_s2(keep_zips = FALSE)`,
  défaut) : chaque archive est supprimée dès son extraction (drapeau
  `delete_zip_after_extract` passé au script d’unzip vendoré), ce qui
  plafonne le pic disque à la taille des scènes extraites au lieu de
  *archives + extraites* ;
- **garde-fou pré-vol** : avant d’extraire,
  [`reconfort_ingest_s2()`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)
  estime l’empreinte des scènes depuis la taille des archives et **abort
  proprement** si l’espace libre est insuffisant (message chiffré :
  besoin vs disponible), au lieu de remplir le disque puis d’échouer en
  `exit 1`.

Les garde-fous existants (abort si aucune archive / aucune scène) sont
conservés. `run_geodes_download.py` reste vendoré verbatim ; le seul
ajout au script d’unzip est l’extract-then-delete, annoté
`NOTE (nemeton)` et désactivé par défaut (clé de config absente →
comportement amont).

## nemeton 0.94.2 (2026-06-24)

#### Added — RECONFORT AOI-scoped : la chaîne tourne en minutes (spec 021)

RECONFORT (dépérissement feuillus, IOTA² + modèle pré-entraîné v3) ne
tournait jamais de bout en bout : IOTA² traite la tuile MGRS entière
(10980×10980 px) quelle que soit la zone (~7 h pour ~60 pixels utiles),
et plusieurs incompatibilités de l’iota2 récent (OTB 10) faisaient
échouer la chaîne.

[`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
est désormais **AOI-scoped par défaut** (`aoi_crop = TRUE`, nouveau
`R/reconfort_crop.R`) :

- **Clip + reprojection** des scènes S2 à l’AOI + buffer dans la
  projection de sortie (EPSG:2154) avant IOTA² : run de 7 h → **~6
  min**, et correction d’un bug de grille de référence iota2. Tout est
  per-pixel (gap-filling, indices CRswir/CRre, RF v3) → résultat
  inchangé pour les pixels conservés.
- **Masque feuillus** découpé de l’OSO national (`<cache>/oso/oso.tif`,
  classe 16) pour l’AOI, au lieu du masque régional partiel.
- **Points de vérité terrain** régénérés dans l’AOI (sampling part-1
  d’IOTA²).
- `number_of_chunks` forcé à 1 sur le raster clippé.

Nouveaux paramètres `aoi_crop` et `oso_national`. Validé en live (zone
`lajoux_feu`) : carte de dépérissement produite, 370 alertes
pixel/cluster persistées en base.

#### Fixed

- **RECONFORT bundle features multi-résolution** :
  `.build_reconfort_feature_stacks()` combinait B04 (10 m) avec
  B05/B06/B8A/B11/B12 (20 m) → terra échouait (« number of rows and/or
  columns »), le bundle CRswir/CRre n’était pas persisté. Toutes les
  bandes sont rééchantillonnées sur la grille 10 m de B04.
- **Configs IOTA² vendorées** alignées sur l’iota2 récent : clés
  invalides retirées de `iota2_resources.cfg`, labels `I2TemporalLabel`
  dans `custom_index.py`, builder `I2Classification`, scheduler
  `localCluster`.

#### Tooling

- `inst/python/reconfort/repair_iota2_env.sh` (idempotent) : applique
  les deux défauts du paquet `iota2` à la création du conda —
  `pandas < 3` (`to_datetime(infer_datetime_format=)` retiré en
  pandas 3) et le wrapper `task_launcher.py` dans `$ENV/bin/`.

## nemeton 0.94.1 (2026-06-23)

#### Fixed — FORDEAD install : afficher la vraie erreur pip (« Error installing package(s): » vide)

Sur première utilisation de FORDEAD (création du venv
`nemeton-fordead`), quand l’installation des dépendances pinnées
échouait, l’utilisateur ne voyait qu’un message inexploitable :

    ℹ Installing FORDEAD dependencies from 'requirements.txt'.
    ✖ FORDEAD pipeline failed: Error installing package(s):

Cause :
[`reticulate::virtualenv_install()`](https://rstudio.github.io/reticulate/reference/virtualenv-tools.html)
lève, sur sortie pip non nulle, un message générique
`"Error installing package(s): "` — et comme on lui passe un fichier
`requirements` (et `packages = NULL`), la liste est vide, donc le
message l’est aussi. Le diagnostic pip réel (ex. `git` absent du PATH
alors que `fordead` / `simplestac` sont des pins `git+https`, réseau
bloqué vers `gitlab.com` / `forge.inrae.fr`, ou une roue qui ne compile
pas) était perdu.

**Fix** : nouveau helper interne
`.fordead_pip_install(env_name, requirements, verbose)` qui lance pip
directement dans l’interpréteur du venv
(`python -m pip install --upgrade -r requirements.txt`), **capture la
sortie combinée stdout+stderr**, et en cas d’échec ré-émet un
[`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
portant la fin de la sortie pip (verbatim, sans ré-interprétation des
accolades) plus les causes courantes hors-ligne / Windows.
[`.ensure_fordead_python()`](https://pobsteta.github.io/nemeton/reference/dot-ensure_fordead_python.md)
appelle désormais ce helper au lieu de
[`reticulate::virtualenv_install()`](https://rstudio.github.io/reticulate/reference/virtualenv-tools.html).
Comportement inchangé en cas de succès (sortie pip relayée quand
`verbose`). Tests (`test-fordead-python.R`) : 2 nouveaux pour le helper
(échec → message actionnable ; succès → `TRUE`), 3 tests d’orchestration
recâblés sur le nouveau point de montage.

Le message d’abort liste les causes courantes, dont — cas réel rencontré
sous Windows le 2026-06-23 — l’erreur `Filename too long` /
`unable to checkout working tree` lors du clone de la dépendance
transitive `stac_static` (limite des 260 caractères de `MAX_PATH`) : la
sortie pointe vers `git config --system core.longpaths true`.

## nemeton 0.94.0 (2026-06-19)

#### Added — Carte FORDEAD : couches de diagnostic additionnelles (Partie A, cœur)

Préparation cœur pour 3 couches d’affichage supplémentaires dans la
Carte FORDEAD de l’app (en plus du masque 0-4) :

- **Bundle modèle enrichi** : la phase `persist` de
  [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  ([`.write_fordead_model_bundle()`](https://pobsteta.github.io/nemeton/reference/dot-write_fordead_model_bundle.md))
  écrit désormais aussi `anomaly_index.tif` (dernier `ANOMALY_INDEX` —
  sévérité continue) et `modelled_pixels.tif` (masque de confiance des
  pixels modélisés), en plus de `first_anomaly.tif` (déjà présent).
  Best-effort : couches sautées si la source manque.
- **Nouveau lecteur exporté**
  `read_fordead_layer(con, zone_id, layer, run_id, cache_dir, …)` : lit
  une couche du bundle (`"first_anomaly"`, `"anomaly_index"`,
  `"modelled_pixels"`) comme `SpatRaster` masqué à l’UGF (miroir de
  [`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md)).
  Rend `NULL` sans erreur si la couche/le bundle manque (anciens runs →
  dégradation gracieuse côté app).

Côté app (`nemetonshiny`, Partie B à venir) : sélecteur de couche +
palettes / légendes dédiées, masquage par strate (D2).

## nemeton 0.93.1 (2026-06-19)

#### Fixed — Validation terrain G4 sur clé pixel (spec 008 §15 Phase B.2, D-B4)

[`ingest_health_validation()`](https://pobsteta.github.io/nemeton/reference/ingest_health_validation.md)
ne dépend plus de la table `plot` : il snappe chaque observation terrain
(GPKG QField) sur le **centroïde pixel de l’alerte** (`alert.geom_wkt`),
filtré par `alert.zone_id` — auparavant la requête joignait `alert` à
`plot` (`p.geom_wkt`, `p.zone_id`), ce qui ne renvoyait **aucune
alerte** pour le modèle Phase B (alertes `plot_id` NULL). Le mapping
stade → `validation_status`/`validation_cause` et l’`UPDATE alert` sont
inchangés. Dernier reliquat placette du suivi sanitaire levé.

Au passage, l’`UPDATE` de validation utilisait `now()` (PostgreSQL
uniquement) → remplacé par un timestamp fourni par R, portable sur le
backend SQLite (mode mono-utilisateur local).

## nemeton 0.93.0 (2026-06-18)

#### Added — Suivi sanitaire : re-persistance pixel des alertes (Phase B, spec 008 §15 / ADR-013 A5)

La table `alert` redevient alimentée, mais l’alerte est désormais une
**entité raster/pixel géoréférencée**, jamais une placette (décisions
D-B1 à D-B4) :

- **Migration `0007_alert_pixel_geometry`** (PostgreSQL + SQLite) :
  `DROP` + `CREATE` de `alert` au nouveau schéma — `zone_id` (NOT NULL,
  FK `monitoring_zone` `ON DELETE CASCADE`), `geom_wkt` (centroïde
  EPSG:4326), `n_pixels`, `area_m2`, `cluster_id`, `plot_id`
  **nullable** (`ON DELETE SET NULL`), clé
  `UNIQUE (zone_id, alert_type, trigger_date, cluster_id)`. La table
  étant vide (contrat Phase A), le `DROP`+`CREATE` est sûr et portable.
- **Persistance** :
  [`.insert_fordead_alerts()`](https://pobsteta.github.io/nemeton/reference/dot-insert_fordead_alerts.md)
  / `.insert_reconfort_alerts()` (helper partagé
  `.insert_health_alerts`) n’effectuent plus de *snapping* placette ;
  elles insèrent le centroïde + métadonnées et appliquent la stratégie
  **replace-by-window** (D-B1, idempotence inter-runs). Re-câblées dans
  [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  (persist) et
  [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  (postprocess) ; `n_alerts_inserted` redevient un vrai compte.
- **[`list_alerts()`](https://pobsteta.github.io/nemeton/reference/list_alerts.md)**
  lit la géométrie de l’alerte (`geom_wkt`, `LEFT JOIN plot` optionnel)
  et expose `zone_id` / `n_pixels` / `area_m2`.
- **[`classify_disturbance()`](https://pobsteta.github.io/nemeton/reference/classify_disturbance.md)**
  (fusion G2) joint sur une **proximité spatiale** des centroïdes (≤
  `radius_m`, défaut 100 m) au lieu de l’égalité `plot_id`, avec repli
  legacy `plot_id` pour les jeux sans géométrie.
- **R5 inchangé** (lit `alerts_sf` en mémoire). Le workflow de
  validation terrain G4 (`ingest_health_validation`) reste sur le modèle
  placette en attendant sa refonte (Phase B.2, D-B4).

#### Changed — FORDEAD est strictement mono-indice (CRSWIR)

`.fordead_supported_vi` est réduit à `c("CRSWIR")` : les indices NDVI /
NDWI « tolérés pour la recherche » sont retirés (ni calibrés, ni exposés
dans l’app). Toute autre valeur de `vegetation_index` est rejetée.

## nemeton 0.92.0 (2026-06-18)

#### Changed — Suivi sanitaire : découplage de la placette (Phase A, spec 008 §15 / ADR-013 A5)

L’alerte santé devient une **entité raster/pixel** rattachée à la zone
de suivi, jamais à une placette. Les pipelines de diagnostic
**n’insèrent plus** d’alerte dans la table `alert` :

- [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  : la phase `persist` n’appelle plus
  [`.insert_fordead_alerts()`](https://pobsteta.github.io/nemeton/reference/dot-insert_fordead_alerts.md).
  Le masque 0-4 (`dieback_mask_<run_id>.tif`) et le bundle modèle
  restent écrits sur disque — ils deviennent la **source de vérité
  d’affichage**. `n_alerts_inserted` vaut désormais `NA` (non
  pertinent), plus `0L` (qui se lisait à tort « run sain »).
- [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  : la phase `postprocess` calcule toujours les centroïdes de cluster
  mais ne les insère plus. Le résultat **gagne** `alerts_sf` (parité
  avec FORDEAD), consommé en mémoire par
  [`indicateur_r5_deperissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md).

**Déclencheur** : incident *Mouthe* — une zone sans placette voyait ses
alertes (813 pixels classe 4 sur disque) silencieusement perdues, et
l’UI affichait « zone saine » à tort. **R5 n’est pas impacté** (il lit
`alerts_sf` en mémoire, pas la base).

[`.insert_fordead_alerts()`](https://pobsteta.github.io/nemeton/reference/dot-insert_fordead_alerts.md)
/ `.insert_reconfort_alerts()` et
[`list_alerts()`](https://pobsteta.github.io/nemeton/reference/list_alerts.md)
sont **conservées** (marquées legacy) pour la Phase B (re-persistance
pixel après migration de schéma — non incluse ici, **aucune migration
DB** en Phase A). Côté app `nemetonshiny` : l’affichage par strate
(`_res`/`_mix`) sera un masquage du raster calculé sur `_tot` (décision
D2).

## nemeton 0.91.2 (2026-06-17)

#### Changed — FORDEAD ingest : suppression du fallback bbox-des-placettes

[`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)
(ingest FORDEAD) **ne lit plus du tout les placettes** : c’est un
diagnostic **par pixel** dont l’emprise est la géométrie de la zone
(`monitoring_zone.zone_wkt`). On retire l’appel à `.fetch_plots_sf()` et
l’ancien **fallback bbox-des-placettes** (vestige d’avant spec 012/017,
quand l’AOI dérivait de la position des placettes). Une zone sans
`zone_wkt` exploitable est désormais une erreur de configuration claire
(avertissement + résultat vide invitant à
[`register_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/register_monitoring_zone.md))
plutôt qu’une reconstruction d’emprise depuis les placettes. `n_plots`
du payload de progression `s2:search` passe à `0` (l’ingest est
placette-indépendant). Tests : `test-sentinel2-cache.R` (l’ingest échoue
le test si `.fetch_plots_sf` est appelé ; « no usable zone_wkt » →
vide + warning).

## nemeton 0.91.1 (2026-06-17)

#### Fixed — diagnostic FORDEAD plantait sur une zone sans placette

[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
échouait avec
`Not compatible with requested type: [type=NULL; target=double]` sur une
zone de suivi **géométrie-seule** (sans placette — le cas par défaut
depuis spec 017). Cause : dans
[`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md),
un reliquat de **code mort** —
`sf::st_buffer(plots_proj, dist = plots_proj$radius_m)` — recevait
`dist = NULL` quand `.fetch_plots_sf()` renvoie un `sf` 0 ligne sans
colonne `radius_m`, d’où l’erreur vctrs. Ce buffer par placette n’était
**jamais utilisé** en aval (seul le masque de zone `crop_geom` sert
depuis spec 012/017) — il est supprimé. Le diagnostic FORDEAD tourne
désormais sur les zones sans placette. Régression :
`test-sentinel2-cache.R` (« placette-less zone ingests without crashing
»).

## nemeton 0.91.0 (2026-06-17)

#### Added — `smooth_pixel_series(method = "harmonic")` : lissage saisonnier continu (spec 026)

Les méthodes locales (`rolling_median`, `loess`) laissent des **trous**
là où il n’y a pas de scène claire (hiver, longues séries nuageuses) —
elles ne peuvent rien dire sans donnée. Pour une série optique à **trous
saisonniers**, la famille adaptée est la **décomposition harmonique**
(HANTS / BFAST / CCDC), cohérente avec FORDEAD (déjà harmonique,
ADR-013).

Nouvelle méthode **`harmonic`** : régression **harmonique robuste** —
`n_harmonics` paires de Fourier annuelles (défaut 2) + tendance
linéaire, ajustée par **IRLS** (poids biweight de Tukey, échelle MAD)
pour rejeter les chutes nuageuses. Elle modélise le **cycle saisonnier**
→ courbe **continue** même sur les trous hiver/été. Base R uniquement
([`stats::lm.wfit`](https://rdrr.io/r/stats/lmfit.html)), aucune
dépendance nouvelle. Nouveau paramètre `n_harmonics` (1:3).

> **Modèle ≠ donnée** : `harmonic` *interpole* l’hiver à partir de la
> forme du cycle — courbe **modélisée**, pas mesurée (à présenter comme
> telle côté app).

[`smooth_pixel_series()`](https://pobsteta.github.io/nemeton/reference/smooth_pixel_series.md)
prédit à **toutes** les lignes (y compris `value = NA`) : l’app obtient
une courbe pleinement continue en ajoutant une **grille de dates
régulières** (`value = NA`) à `ts` avant l’appel. Le déclin pluriannuel
reste porté par le mode `trend` (le terme de tendance harmonique sert
l’affichage, pas la décision d’alerte). Tests :
`test-smooth-pixel-series.R` (continuité sur trous saisonniers,
robustesse aux spikes, densification par grille NA, garde-fou série trop
courte, validation `n_harmonics`).

## nemeton 0.90.0 (2026-06-17)

#### Added — `smooth_pixel_series()` : lissage robuste de la série pixel (spec 026)

Le graphe « série pixel »
([`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md))
reliait chaque acquisition par des segments → **dents de scie**
illisibles (bruit résiduel nuages/ombres/neige, pas signal forestier).
`smooth_pixel_series(ts, window_days = 45, method = c("rolling_median","loess"), min_obs = 3L)`
ajoute une colonne **`smoothed`** par indice, pour afficher **points
bruts estompés + ligne lissée** côté app (présentation), la logique de
lissage restant dans le cœur (règle 12).

- **Défaut `rolling_median`** : médiane sur une **fenêtre temporelle**
  centrée (`window_days`, en jours — l’échantillonnage est irrégulier),
  **robuste aux outliers** nuageux (≠ moyenne mobile / LOESS standard,
  qui les suivent). `NA` quand la fenêtre contient moins de `min_obs`
  observations claires.
- Option **`loess`** : régression locale `family = "symmetric"`
  (robuste), temps centré, `span` plancher 0.3 ; prédit à toutes les
  dates.

NA-aware, sans dépendance nouvelle (base `median`/`loess`). Opère à
l’échelle **scène** (le lissage **saisonnier annuel** reste le rôle du
mode `trend`). Tests : `test-smooth-pixel-series.R` (absorption de
spikes nuageux, lissage par indice indépendant, `min_obs`, NA ignorés,
loess sans NA).

## nemeton 0.89.0 (2026-06-17)

#### Added — seuil de pente minimale `min_slope` (calibration trend)

Le mode `trend` flaggait des déclins **statistiquement significatifs
mais écologiquement négligeables** : sur séries longues, Mann-Kendall
détecte une dérive monotone minuscule (ex. 0.0001 NDRE/an, observé en
prod) comme « significative », gonflant les alertes de bruit. La
significativité statistique ≠ significativité écologique.

Nouveau paramètre **`min_slope`** (seuil de magnitude, unités indice/an)
: un pixel n’est une alerte que si `pente < 0` **et** Mann-Kendall
significatif **et** `|pente| >= min_slope`. Câblé sur tout le pipeline
trend :
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md),
[`read_fast_alert_rasters()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_rasters.md),
[`extract_pixel_trend()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_trend.md),
[`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md),
[`create_trend_sanitary_plan()`](https://pobsteta.github.io/nemeton/reference/create_trend_sanitary_plan.md),
et les helpers internes `.fast_raster_trend()` / `.trend_fit_cells()` /
`.trend_fit_one()`.

**Défaut `0.005`** (≈ une chute totale de 0.03–0.05 NDRE sur une fenêtre
typique) — **provisoire**, à calibrer contre la vérité terrain (ONF/DSF)
; `min_slope = 0` restaure le test de significativité pur (comportement
≤ v0.88.1). Intégré au hash de cache D6 (un changement invalide les COG
trend) ; count/rolling **inchangés** (le seuil n’agit qu’en trend).
Tests : `test-extract-pixel-trend.R` (un déclin ~0.001/an, significatif
mais sous le seuil, n’est plus une alerte ; flaggé de nouveau avec
`min_slope = 0`).

## nemeton 0.88.1 (2026-06-16)

#### Fixed — `create_trend_sanitary_plan()` tirait hors de la zone de suivi

Quand le polygone UGF ne pouvait pas être résolu,
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
renvoie le raster trend **pleine tuile non masqué**
(`.apply_zone_mask(r, NULL)` est un no-op), et le tirage GRTS dispersait
alors les placettes sanitaires **sur toute la tuile Sentinel-2 (~100
km)** au lieu de l’UGF — avec des `alert_value` quasi nuls (pixels
marginaux pris partout). Pour un plan d’échantillonnage, ce repli
silencieux est dangereux.

[`create_trend_sanitary_plan()`](https://pobsteta.github.io/nemeton/reference/create_trend_sanitary_plan.md)
**exige** désormais le masque : le polygone est résolu en amont (depuis
`mask_polygon`, sinon `con`/`zone_id`) et la fonction **échoue
clairement** avec une erreur typée `nemeton_zone_mask_unresolved` si le
masque est introuvable, au lieu de tirer sur la tuile entière.
Recommandé : passer `mask_polygon` explicitement (le `sf` de la zone
déjà disponible côté app) pour éviter l’aller-retour DB **et** garantir
le confinement à la zone. Tests : `test-trend-sanitary-plan.R` (refus
sans masque résoluble, acceptation d’un `mask_polygon` explicite).

## nemeton 0.88.0 (2026-06-16)

#### Added — `create_trend_sanitary_plan()` : placettes sanitaires sur le `trend` (spec 025)

Tirage de **placettes sanitaires** sur le raster `trend` d’un indice
(défaut NDRE), avec un **GRTS à probabilité d’inclusion continue**
pondérée par la **magnitude du déclin** (`|pente|` Theil-Sen, NDRE/an)
via `spsurvey::grts(…, aux_var)` : plus le déclin chronique est marqué,
plus la probabilité de sélection est forte. Placettes témoins
optionnelles tirées en équiprobable sur les cellules **stables**
(`trend == 0`).

**Distinct du plan terrain** : ce plan est **autonome**, **sans aucun
rapport** avec les placettes terrain / d’inventaire (`plot`,
`create_sampling_plan`, `create_validation_sampling_plan`). Il ne lit
jamais la table `plot` et **ne calcule pas de tournée TSP** — les
placettes sont renvoyées triées par **sévérité de déclin décroissante**
(`S01` = plus fort), pas par un parcours de marche.

Contrairement à
[`create_validation_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_validation_sampling_plan.md)
(qui discrétise un masque 0-4 et pondère par classe), on pondère par le
`|pente|` **brut** : un pixel à 0.04 NDRE/an est prioritaire sur un
0.012 même dans la même classe quartile. Le raster trend est lu via
`read_fast_alert_raster(mode = "trend")` (scène par scène par tuile puis
mosaïque sur grille commune → immunisé contre le bug multi-tuiles,
v0.85.1), masque UGF déjà appliqué.

Sortie `sf` POINT : `plot_id` (`S##`/`T##`), `type`
(`"Sanitaire"`/`"Temoin"`), `alert_value` (`|pente|` au pixel, `0`
témoin), `index`, `source = "FAST_TREND"`, `seed` — **sans
`visit_order`**. Erreur typée `nemeton_empty_alert_mask` quand aucune
cellule en déclin significatif. Helper interne `.draw_grts_continuous()`
(GRTS `aux_var`). `alert_value` au pixel ==
`extract_pixel_trend(xy)$alert_value` == valeur pré-quartile du raster.
Tests : `test-trend-sanitary-plan.R` (déclin pondéré, tri décroissant,
témoins stables, reproductibilité seed, `n_control=0`, erreurs typées).

## nemeton 0.87.0 (2026-06-16)

#### Added — `extract_pixel_trend()` : diagnostic trend au pixel cliqué

Complément **par pixel** de
[`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md)
(v0.86.0, niveau zone). Pour un point `xy`, renvoie la **série des
composites annuels estivaux** de l’indice + le résultat Theil-Sen /
Mann-Kendall, **strictement cohérent** avec
`read_fast_alert_raster(mode = "trend")` au même pixel : c’est ce qui
alimente le graphe « pourquoi *ce* pixel a *cette* couleur » (points
compositaires, droite de déclin, significativité derrière la classe de
sévérité).

La série brute par scène est lue via
[`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md)
(extraction **scène par scène** au point, **pas** de mosaïque zone-wide
→ immunisé contre le bug multi-tuiles
`[mosaic] resolution does not match`), puis compositée exactement comme
le raster (médiane estivale par année, année écartée sous
`min_obs_per_year`) et ajustée avec le **même** Theil-Sen /
Mann-Kendall. `alert_value` égale donc la valeur pré-quartile du raster
**cellule pour cellule** (test de non-régression croisé :
`extract_pixel_trend(xy)$alert_value == read_fast_alert_raster(mode="trend")`
au pixel).

Retour :
`list(index, composites[year,value], n_years, theil_sen_slope, theil_sen_intercept, mann_kendall_p, mann_kendall_tau, significant_decline, alert_value, enough_years)`.
`alert_value` = `abs(pente)` si déclin significatif, `0` sinon, `NA`
sous `min_years` (NA-masqué comme la carte). La classe 0-4 n’est PAS
renvoyée (bornes quartiles zone-wide → l’app la lit dans le raster
mask). Refactor : moteur de fit factorisé dans le helper interne partagé
`.trend_fit_one()`, appelé par
[`extract_pixel_trend()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_trend.md),
[`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md)
et cohérent avec `.trend_fit_cells()` (vectorisé) — garantie pixel ==
zone == raster. Tests : `test-extract-pixel-trend.R` (déclin
significatif, série plate, \< min_years → NA, hors saison → NULL,
cohérence croisée pixel/raster).

## nemeton 0.86.0 (2026-06-16)

#### Added — `extract_trend_series()` : trajectoire annuelle pour le graphe « à partir de quand »

Le mode `trend` (`read_fast_alert_raster(mode = "trend")`) réduit
l’historique de chaque pixel à **une seule pente** : la carte ne dit
donc pas *quand* le déclin commence.
`extract_trend_series(con, zone_id, index = "NDRE", …)` ressort la
**série des composites annuels estivaux** au niveau de la zone + le fit
Theil-Sen / Mann-Kendall, pour tracer la trajectoire et lire l’année où
l’indice décroche.

Pour chaque année de la fenêtre, les scènes en saison (`months = 6:9`)
sont réduites à un composite médian par pixel (année écartée si \<
`min_obs_per_year` observations claires), masquées à l’UGF, puis
moyennées spatialement en une valeur. La série `(année, valeur)` est
ajustée avec **le même** Theil-Sen + Mann-Kendall que la carte applique
par pixel (helper factorisé `.trend_yearly_composite()` partagé avec
`.fast_raster_trend()`), si bien que la trajectoire de zone et la carte
concordent par construction. Les AOI multi-tuiles sont combinées en
moyenne pondérée par le nombre de pixels valides.

Retour : `list(series, fit, index, months, alpha)` où `series` est un
`data.frame` `year / n_scenes / value / fitted` (un point + la droite
Theil-Sen prêts à tracer) et `fit` porte `slope`, `intercept`,
`p_value`, `tau`, `n_years`, `significant` (pente \< 0 **et** p \<
alpha) et `alert` (`abs(pente)` si significatif, sinon 0 — la magnitude
que la carte discrétise en classes 1-4), ou `NULL` sous `min_years`
années valides. Conçu pour alimenter le graphe « trajectoire NDRE +
droite de tendance » côté `nemetonshiny`. Tests :
`test-extract-trend-series.R` (déclin NDRE significatif, fit NULL sous
le seuil d’années, NULL hors saison, validation).

## nemeton 0.85.1 (2026-06-16)

#### Fixed — mosaic multi-tuiles NDRE 20 m (`[mosaic] resolution does not match`)

[`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
/
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
échouaient avec `[mosaic] resolution does not match` pour
`index = "NDRE"` (et tout indice 20 m) lorsque la zone chevauche
**plusieurs tuiles MGRS** (ex. T31TFM + T31TGM). Cause : chaque raster
d’alerte par-tuile était projeté vers EPSG:2154 **indépendamment**
(`terra::project(rn, "EPSG:2154")` sans grille cible), terra dérivant
alors une résolution de sortie propre à l’étendue de chaque tuile. Deux
tuiles natives 20 m (bandes B8A/B05 du NDRE) tombaient sur des
résolutions très légèrement différentes →
[`terra::mosaic()`](https://rspatial.github.io/terra/reference/mosaic.html)
refusait de les fusionner. Le NDVI/NDMI 10 m ne reproduisait pas le bug
(les tuiles arrondissaient par chance à la même résolution).

Nouveau helper interne `.mosaic_per_tile()` : avant la mosaïque, les
rasters par-tuile sont **rééchantillonnés sur une grille EPSG:2154
commune** (la résolution de la première tuile, étendue union snappée sur
des multiples de cette résolution, même origine), de sorte que la
mosaïque est bien définie quelle que soit la dérive de projection
inter-tuiles. Aucun changement pour les zones mono-tuile ni pour les
indices 10 m. Régression : `test-fast-alert-raster.R` (snap de deux
tuiles à résolutions 20 / 20,05 que
[`terra::mosaic()`](https://rspatial.github.io/terra/reference/mosaic.html)
rejetait, mosaïque OK à résolution unique + étendue union).

## nemeton 0.85.0 (2026-06-15)

#### Added — wrapper FAST étendu au `trend` + red-edge systématique (spec 023)

Complète la v0.84.0 (qui avait étendu la **pré-chauffe**
`.prewarm_fast_alerts()` au `trend` NDMI/NDRE) sur deux axes que la
pré-chauffe seule ne couvrait pas :

- **Wrapper
  [`read_fast_alert_rasters()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_rasters.md)
  étendu au `trend`.** Ses défauts passent à
  `c("NDVI","NBR","NDMI","NDRE")` × `c("count","rolling","trend")` → **8
  cartes**. Seules les combinaisons sensées sont construites : `trend`
  réservé aux indices humidité/red-edge (`NDMI`, `NDRE`),
  `count`/`rolling` aux indices large bande (`NDVI`, `NBR`, `NDMI`) —
  une paire absurde (`NDVI_trend`, `NDRE_count`) est silencieusement
  ignorée. Les paramètres trend (`months`, `min_years`,
  `min_obs_per_year`, `alpha`) sont exposés et transmis. Nouveau
  prédicat interne `.fast_alert_combo_ok()` / `.fast_alert_combos()`
  énumérant les paires valides.

- **Red-edge systématique.**
  [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  cache désormais B05 + B8A **best-effort sur chaque ingestion** (comme
  B11 pour NDMI, spec 019 D3), même avec le défaut
  `bands = c("NDVI","NBR")`. Les quatre indices FAST
  (NDVI/NBR/NDMI/NDRE) — y compris les cartes `trend` — sont donc
  **toujours calculables**, sans ré-ingestion ni `bands = "NDRE"`
  explicite. B05/B8A sont des bandes 20 m standard de toute scène S2 L2A
  : le best-effort aboutit en pratique toujours (coût : ~3 COG croppés
  de plus par scène), ce qui supprime à la source le soft-skip
  `NDRE_trend` de la pré-chauffe sur les ingestions fraîches.

Tests : `test-ndmi.R` (wrapper 8 cartes, sous-ensemble, paires absurdes
écartées), `test-ndre.R` (ingest cache B05/B8A best-effort).

## nemeton 0.84.0 (2026-06-15)

#### Added — pré-chauffage FAST `trend` (spec 023)

`ingest_sentinel2_timeseries(prewarm_alerts = TRUE)` pré-calcule
désormais **8 cartes FAST** au lieu de 6 : aux 6 combos historiques
`{NDVI, NBR, NDMI} × {count, rolling}` (spec 019) s’ajoutent **2 combos
`trend`** `{NDMI, NDRE} × {trend}` (spec 023). Le mode `trend` cible le
dépérissement chronique des feuillus, dont les signaux pertinents sont
l’humidité (NDMI, B11) et le red-edge (NDRE, B05/B8A) ; NDVI/NBR restent
`count`/`rolling` uniquement.

Le pré-chauffage `trend` utilise les défauts cœur `months = 6:9`,
`min_obs_per_year = 2`, `min_years = 4`, `alpha = 0.05` (identiques à
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md))
; `threshold`/`window_days` ne sont pas employés en `trend`. Les COG
`trend` atterrissent sous le même schéma
`<prewarm_mask_cache_dir>/zone_<id>/` que les autres combos.

Le warm `*_trend` est **best-effort** : il ne tourne que si les bandes
requises sont en cache (B11 pour NDMI, B05+B8A pour NDRE) et, à défaut,
est sauté sans faire échouer l’ingestion — comme les scènes sans href.
Les événements de progression `fast_prewarm:NDMI_trend{,_done,_failed}`
et `fast_prewarm:NDRE_trend{,_done,_failed}` sont émis au même format
que l’existant (`fast_prewarm:complete` / `:cancelled` inchangés).
Débloque le câblage du sélecteur 3 modes côté `nemetonshiny`.

## nemeton 0.83.3 (2026-06-14)

#### Fixed — ingestion S2 placette-indépendante (spec 017)

[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
et
[`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)
**exigeaient à tort des placettes** (`plot`) et abandonnaient avec « No
plots registered for zone_id … » alors que, depuis la spec 017,
l’ingestion est un simple amorçage de cache piloté par l’étendue de la
zone (`zone_wkt`) et le diagnostic FAST/FORDEAD est calculé **par
pixel**, indépendamment des placettes (`obs_pixel` supprimé en v0.58.0).
Or l’app crée les zones de suivi comme des **géométries pures sans
placette**
([`create_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/create_monitoring_zone.md)
/
[`build_project_monitoring_zones()`](https://pobsteta.github.io/nemeton/reference/build_project_monitoring_zones.md),
« geometry only, no placettes ») : **toute zone créée depuis la spec 017
ne pouvait donc pas amorcer son cache** — bug masqué tant que le cache
restait chaud, révélé dès qu’on étendait la fenêtre au-delà des scènes
déjà cachées.

Les deux fonctions résolvent désormais l’AOI de la zone **d’abord** et
ne consultent les placettes que pour le **fallback bbox legacy** (zone
sans `zone_wkt`). Une zone correctement enregistrée mais sans placette
amorce son cache normalement ; seule une zone sans `zone_wkt` **ni**
placette est rejetée. Couvert par `test-aoi-alignment.R` (zone
`zone_wkt` sans placette → l’ingestion procède, bbox issu du WKT).

## nemeton 0.83.2 (2026-06-14)

#### Fixed — `.assert_cache_has_bands()` : pluralisation cli ambiguë (spec 022)

Le garde-fou NDRE
([`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md)
/
[`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
quand le cache n’a jamais ingéré B05 / B8A) plantait sur `cli` récent
avec « Multiple quantities for pluralization » : le message interpolait
deux vecteurs de longueurs différentes (`missing` et `cache_dir`) avec
un `{?s}` non lié. La quantité de pluriel est désormais épinglée par
`{cli::qty(missing)}`, si bien que l’abandon affiche correctement « band
B05 » (1 manquante) ou « bands B05, B8A » (2 manquantes). Régression
couverte par `test-ndre.R`.

#### Documentation — FAST `trend` : biais de recouvrement de tuiles (spec 023)

Documenté le comportement de `mosaic(fun = "max")` sur les liserés de
tuiles MGRS en mode `trend` : chaque tuile ajuste sa pente depuis son
propre jeu de scènes, et `max` retient la plus forte magnitude de déclin
dans la bande de recouvrement (~10 km) — un léger biais haut, borné et
conservateur pour la *détection*. Une AOI mono-tuile n’est pas
concernée. (roxygen + commentaire inline ; cohérent avec `count` /
`rolling`.)

## nemeton 0.83.1 (2026-06-14)

#### Changed — FAST `trend` : fit vectorisé Theil-Sen / Mann-Kendall (spec 023, perf)

Le mode FAST `trend` calculait la pente Theil-Sen et le test de
Mann-Kendall **pixel par pixel** via un callback
[`terra::app`](https://rspatial.github.io/terra/reference/app.html)
(`combn`/`table` appelés une fois par cellule : ~270 µs/pixel, ~4,5 min
pour une tuile 1 Mpx). `.fast_raster_trend()` est réécrit en deux
leviers, à résultat **identique** :

- **Pré-filtre vectorisé** : les pixels à moins de `min_years` années
  valides sont écartés avant tout calcul (gain proportionnel à la rareté
  du masque forestier).
- **Fit vectorisé** : la pente Theil-Sen et la statistique S de
  Mann-Kendall sont calculées sur **toutes** les cellules candidates à
  la fois par arithmétique matricielle ; seules les rares cellules à
  valeurs ex-aequo retombent sur le `.mann_kendall()` exact (variance
  tie-corrigée). **~9×** plus rapide, sortie byte-identique au chemin
  per-cellule (NA hétérogènes, séries plates, ex-aequo partiels
  vérifiés).
  [`cli::cli_alert_info`](https://cli.r-lib.org/reference/cli_alert.html)
  annonce le nombre de pixels candidats.

`terra::app(cores=)` ne peut pas sérialiser la closure et un découpage
furrr/PSOCK s’est révélé **plus lent** que le série (maths per-pixel
trop bon marché pour amortir la sérialisation) : le levier retenu est la
vectorisation, pas le parallélisme. Aucun changement de comportement ni
d’API.

#### Documentation

- `alpha` (mode `trend`) clarifié : la p Mann-Kendall est **bilatérale**
  mais le gate « pente négative » ne retient qu’une queue, si bien que
  le risque effectif de faux positif pour un déclin déclaré vaut
  **`alpha / 2`** (le défaut `0.05` correspond à un risque unilatéral de
  2,5 %).

## nemeton 0.83.0 (2026-06-14)

#### Added — `read_reconfort_alert_mask()` : parité raster validation (spec 021 G4, Option A)

`read_reconfort_alert_mask(con, zone_id, run_id, cache_dir, …)` renvoie
le raster catégoriel des classes RECONFORT
(`1 sain / 2 dépérissant / 3 très-dépérissant`) du dernier run —
**miroir exact** de
[`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md).
La phase `persist` de
[`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
écrit ce masque plat
(`<cache_dir>/zone_<id>/reconfort_mask_<run_id>.tif`, best-effort).
Permet à `nemetonshiny` de **réutiliser 1:1** son module de plan de
validation (`create_validation_sampling_plan(source = "RECONFORT")`,
`classes = c(2, 3)`, `control_classes = c(1)`) → **mêmes onglets, mêmes
placettes témoins et même workflow QGIS/QField que FORDEAD**. Clôt le
support cœur de G4 (Option A). Reste côté app : le sous-onglet « Plan de
validation RECONFORT ».

## nemeton 0.82.0 (2026-06-14)

#### Changed — validation terrain feuillus : vocabulaire DEPERIS finalisé (spec 021 G4)

`HEALTH_VALIDATION_STADES_FEUILLUS` est calé sur le **protocole DSF
DEPERIS** réel (critères mortalité de branches MB + manque de
ramification MR, notation A–F, seuil **\> 50 %** d’atteinte du houppier)
: `sain` / `deperissement_faible` / `deperissement_marque` /
`deperissement_grave` / `mort` / `coupe_rase`. La mention « PROVISIONAL
» est retirée.

#### Added

- `create_validation_sampling_plan(source = …)` accepte désormais
  **`"RECONFORT"`** (en plus de `"FORDEAD"`/`"FAST"`). La fonction
  échantillonne n’importe quel raster catégoriel mono-couche ; pour
  RECONFORT l’appelant passe le raster de classes feuillus (1 sain / 2
  dépérissant / 3 très-dépérissant) avec `classes = c(2, 3)`,
  `control_classes = c(1)`.

Débloque le sous-onglet « Plan de validation RECONFORT » côté
`nemetonshiny` (lot L6 / G4). Reste **optionnel** (Option A, à trancher
métier) :
[`read_reconfort_alert_mask()`](https://pobsteta.github.io/nemeton/reference/read_reconfort_alert_mask.md)
pour des placettes témoins raster.

## nemeton 0.81.0 (2026-06-13)

#### Added — schéma de validation terrain QField feuillus (spec 021 G4, support L6)

[`get_health_validation_schema()`](https://pobsteta.github.io/nemeton/reference/get_health_validation_schema.md)
gagne un argument **`method = c("fordead", "reconfort")`** : en mode
`reconfort` il sert un vocabulaire de **dépérissement feuillus**
(`HEALTH_VALIDATION_STADES_FEUILLUS` : sain, défoliation, mortalité de
branches, descente de cime, mort, coupe rase ; causes
`HEALTH_VALIDATION_CAUSES_FEUILLUS` sans scolyte). Le mapping
`stade → validation_status` route par méthode (une coupe rase sur une
alerte `reconfort_dieback` = `false_positive`), et
[`ingest_health_validation()`](https://pobsteta.github.io/nemeton/reference/ingest_health_validation.md)
détecte la méthode via `alert.alert_type`. Le mode `fordead` est
inchangé (rétrocompatible). Débloque la brique QField du lot L6 côté
`nemetonshiny`.

**Réserve** : les stades feuillus suivent les axes nommés du spec
(DEPERIS) mais le vocabulaire DEPERIS exact reste **à confirmer**
(flaggé).

## nemeton 0.80.0 (2026-06-13)

#### Added — RECONFORT diagnostic pixel : persistance features CRswir/CRre (spec 021, lot L5)

Parité avec le diagnostic pixel FORDEAD. `R/reconfort_outputs.R`
recalcule **CRswir** (eau) et **CRre** (chlorophylle) par date depuis le
S2 ingéré (formules de production §4.1, option B) et les persiste en
stacks datés. `R/reconfort_pixel_series.R` expose
**`read_reconfort_pixel_series(con, zone_id, xy, crs, run_id, cache_dir)`**
qui renvoie les séries observées CRswir/CRre d’un pixel cliqué — **sans
reticulate** (pas de modèle harmonique à reconstruire, contrairement à
FORDEAD). Une phase `persist` (best-effort) + un `run_id` sont câblés
dans
[`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
(le bundle atterrit sous `<cache_dir>/zone_<id>/run_<run_id>/`).

**Réserve** : l’énumération des scènes S2
(`.enumerate_reconfort_s2_scenes`, nommage THEIA/MUSCATE) n’est **pas
validable sans un vrai run IOTA²** — elle est best-effort et n’altère
jamais le run (skip + avertissement si rien trouvé).

Suite : L6 (app `nemetonshiny`).

## nemeton 0.79.0 (2026-06-13)

#### Added — `reset_knowledge_manifest()` (corpus RAG)

Nouvelle fonction exportée qui **ré-écrase la copie writable du
manifest** (celle éditée depuis l’app,
`knowledge_manifest_path(writable = TRUE)`) avec la seed du package
installé. La copie writable est créée **une seule fois** et jamais
rafraîchie (pour préserver les éditions faites dans l’app), si bien
qu’une copie ancienne continuait de lister des documents que le package
ne livre plus (p. ex. les tutoriels retirés en v0.75.0). À câbler à un
bouton « Réinitialiser depuis le corpus du package » dans l’onglet RAG
de `nemetonshiny`. Garde-fou : `confirm = TRUE` obligatoire.

## nemeton 0.78.0 (2026-06-13)

#### Added — R5 dépérissement unifié, routé par essence (spec 021, lot L4)

[`indicateur_r5_deperissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md)
accepte désormais `reconfort_results` (+ `weights_reconfort`,
`min_feuillus`, `feuillus_col`) et **route chaque UGF vers la méthode
calibrée pour son essence dominante** :

- chêne / châtaignier / pin sylvestre → score via **RECONFORT** ;
- épicéa / sapin → score via **FORDEAD** (comportement inchangé) ;
- essence hors méthode → `R5 = NA`, statut `skipped_no_method`.

`r5_status` s’enrichit de `calculated_reconfort`,
`skipped_no_reconfort`, `skipped_no_method` (l’ancien
`skipped_no_resineux` disparaît au profit de ce vocabulaire unifié). Un
`resineux_col` / `feuillus_col` explicite épingle la méthode. R5 reste
une colonne 0-100 (aucun changement de signature radar). Les poids
RECONFORT par défaut sont **provisoires** (sous-ensemble dépérissant de
`RECONFORT_CONFIDENCE_WEIGHTS`, à caler sur la matrice de confusion
amont).

Suite : L5 (persistance features +
[`read_reconfort_pixel_series()`](https://pobsteta.github.io/nemeton/reference/read_reconfort_pixel_series.md)).

## nemeton 0.77.0 (2026-06-13)

#### Added — RECONFORT post-process : rasters → table `alert` (spec 021, lot L3)

`R/reconfort_postprocess.R` transforme les sorties de
[`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
en alertes `reconfort_dieback` :

- **Reclassif + clustering** : `.classify_pixels_to_reconfort_classes()`
  (codes RF 1..n → labels \[`RECONFORT_CLASSES`\], masqué = NA),
  `.cluster_reconfort_pixels()` (patches 8-connexité sur les classes
  dépérissantes, drop sous `min_pixels`).
- **Centroïdes** : `.postprocess_reconfort_rasters()` — score continu
  `(1001 + (−P1 + P2 + 2·P3))/30` en `stress_index`, `trigger_date` =
  date du run, classe RF en `confidence_class`.
- **Insertion** : `.insert_reconfort_alerts()` — UPSERT idempotent (PG +
  SQLite), snap au plot le plus proche.
- **Fusion G2 à 3 voies** :
  [`classify_disturbance()`](https://pobsteta.github.io/nemeton/reference/classify_disturbance.md)
  gère désormais FAST + FORDEAD + RECONFORT (`recent_event` /
  `progressive` / `mechanical`) et ajoute un drapeau
  **`method_overlap`** (FORDEAD ∩ RECONFORT, ne pas double-compter).
- **Migration `0006`** (PG + SQLite) : index sur `alert(alert_type)`.
- **Orchestration** : phase `postprocess` (best-effort) câblée dans
  [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  ; `n_alerts` ajouté au retour.

Exports : `RECONFORT_CLASSES`, `RECONFORT_CONFIDENCE_WEIGHTS`,
`RECONFORT_ALERT_CLASSES`. **Réserve** : les poids de confiance sont
**provisoires** (à caler sur la matrice de confusion Mouret et al. 2023,
cf. spec 021 §5/G1 — flaggé dans le code). Suite : L4 (R5 unifié,
routage par essence).

## nemeton 0.76.2 (2026-06-13)

#### Changed — corpus RAG : 4 papiers scannés OCRisés → texte intégral

Les 4 PDF BILJOU scannés (Bréda 1993/2002/2008, Granier 1996), repassés
en référence en v0.76.1 faute de couche texte, sont désormais
**OCRisés** (`tesseract` fra+eng via conda, 300 dpi) → ré-ingérés en
**texte intégral**. Corpus prod : **60 docs en texte intégral / 81** (6
120 chunks, 0 embedding manquant) — le maximum (les 21 références
restantes n’ont aucun contenu disponible : portails, payants sans PDF,
ouvrages non hébergés).

Le texte OCR (`data-raw/references/biljou/ocr/*.md`) est **gitignoré**
(papiers copyright). Script de reproduction :
`data-raw/ocr_biljou_scans.sh`.

## nemeton 0.76.1 (2026-06-13)

#### Fixed — corpus RAG : 4 PDF BILJOU scannés → `link_only`

Quatre PDF hébergés par BILJOU (Bréda 1993 *water transfer*, Granier
1996 *sapflow*, Bréda 2002 *réservoir sols*, Bréda 2008 *pompe
biologique*) sont des **images scannées sans couche texte** (`pdf_text`
→ 0 caractère) : ils échouaient à l’ingestion full-text. Repassés en
`ingest_strategy=link_only` (références citables) → corpus prod **81/81,
0 erreur** (56 texte intégral + 25 références, 6 033 chunks). OCR requis
pour les passer un jour en texte intégral. Ajout du script
`data-raw/fill_corpus_prod.sh` (build prod **incrémental** non-FRESH,
pour compléter un build partiel sans tout réécraser).

## nemeton 0.76.0 (2026-06-13)

#### Added — `db_connect(connect_timeout = )`

`db_connect(url, read_only, connect_timeout = 10L)` accepte un délai de
connexion. Sur la branche **PostgreSQL**, il est passé à libpq
(`connect_timeout`, en secondes) pour **borner le gel** quand l’hôte est
injoignable, au lieu d’attendre le timeout TCP par défaut de l’OS. Sur
la branche **SQLite**, le paramètre est ignoré (no-op). Consommé par
`nemetonshiny::get_monitoring_db_connection()` qui passe
`connect_timeout = 2L` sur le chemin d’hydratation interactif.

#### Internal

- Parité d’outillage avec `nemetonshiny` : badge version dynamique
  (`github/v/release`), garde-fou CI `version-consistency` (DESCRIPTION
  = NEWS = CITATION), et workflow `release.yml` (auto-tag + release
  GitHub depuis `DESCRIPTION` au push sur `main`).

## nemeton 0.75.4 (2026-06-13)

#### Changed — corpus RAG : 46 références BILJOU passent en texte intégral

Les PDF des références citées par BILJOU sont **hébergés par l’INRAE**
sur le portail (`appgeodb.nancy.inrae.fr/biljou/pdf/`). 50 PDF récupérés
depuis cette source légitime → câblage de **44 docs** (+ Monnet &
Peiffer déposés par l’utilisateur) en `full` (texte intégral). Les
ex-`copyright` sont retagués **`license=HAL`** (archive ouverte,
commercial=non), cohérent avec le traitement Bontemps/Charru. Comble
aussi 2 trous institutionnels (Bréthes 1997 « description des sols »,
Livre Jaune Badeau faisabilité RENECOFOR).

Manifest : **60 docs full-text + 21 références** (81/81, 0 sauté).
Restent en référence : 4 papiers copyright hors BILJOU (Mouret,
Fassnacht, McCool, Beven&Kirkby), ouvrages non hébergés (Quae, Biotope,
AFORCE), EFI (liens morts) et portails sans PDF (CNPF/ONF/OFB,
Legifrance).

PDF gitignorés (`data-raw/references/biljou/`, +`**/*.pdf`) ;
reconstitution via `data-raw/wire_biljou_pdfs.R` (mapping fichier →
doc_id).

## nemeton 0.75.3 (2026-06-13)

#### Changed — corpus RAG : 3 références passent en texte intégral

Récupération de PDF open-access (hors hôtes Cloudflare) pour 3 docs qui
étaient en `link_only`, désormais ingérés en **texte intégral** (`full`)
:

- **Duplat & Tran-Ha 1997** (croissance hauteur chêne) — EDP
  afs-journal.
- **Larrieu — IBP** (guide CNPF v3.2) — cnpf.fr.
- **Stratégie UE pour les forêts COM(2021) 572** — EUR-Lex.

Manifest : **14 docs full-text + 67 références** (81/81). Les PDF non
récupérables (Monnet via MDPI/HAL Cloudflare, portails OFB/ONF/CNPF,
paywall) restent `link_only` ; `data-raw/references/README.md` consigne
les liens directs pour récupération manuelle.

## nemeton 0.75.2 (2026-06-13)

#### Changed — corpus RAG : les 21 docs sans source entrent au corpus

Les 21 documents `cleared`/`full` sans PDF (qui étaient *sautés* au
build) sont désormais tous ingérables :

- **IPCC 2019 (Vol.4 Ch.4 Forest Land)** : PDF récupéré → `full` (texte
  intégral), `local_path` renseigné.
- **20 autres** (RENECOFOR/HAL, EFI, code forestier, EUR-Lex,
  CNPF/ONF/OFB, Duplat, Larrieu, Monnet, Forrester, Bernard&Doridant…) →
  **`link_only`** : ingérés comme **références citables** (citation
  embeddée, pas de texte intégral). Manifest : **81/81 ingérables, 0
  sauté** (11 texte intégral + 70 références).

Métadonnée corrigée : **Monnet & Mermin 2014** était mal référencé
(était *Remote Sensing 6(8)* → en réalité *Forests* 5(9):2307-2326, DOI
`10.3390/f5092307`, HAL open) ; `source_url` HAL ajoutés pour Duplat et
Larrieu. `data-raw/references/README.md` liste les PDF open-access à
récupérer manuellement (HAL/MDPI/EUR-Lex servent un mur anti-bot au
scraping).

Script `data-raw/link_only_skipped.R` (reproductible).

## nemeton 0.75.1 (2026-06-13)

#### Changed — corpus RAG : levée du gel D5 sur l’ensemble du manifest

Décision Pascal : les **50 références `to_confirm`** (BILJOU + 4 papiers
copyright) passent en **`cleared`** (override D5). Toutes étant en
`ingest_strategy=abstract_only`, elles entrent au corpus comme
**références citables** (`link_only` — titre/citation embeddés, pas de
texte intégral de documents copyright). Manifest : **81 cleared / 0
to_confirm**.

Build prod rejoué (FRESH) : pgvector synchronisé → **60 documents**
ingérés (10 texte intégral + 50 références), 2 354 chunks, 0 embedding
manquant ; les 12 docs internes retirés en v0.75.0 sont bien absents.
**21 sautés** : docs `cleared`/`full` sans PDF attaché
(institutionnels/normatifs bien licenciés — backlog d’enrichissement,
conservés en `full` pour ingestion texte intégral dès qu’une source est
jointe).

Ajouts `data-raw/` : `clear_all_to_confirm.R` (flip reproductible) +
`build_corpus_prod.sh` (wrapper FRESH vers le pgvector prod).

## nemeton 0.75.0 (2026-06-13)

#### Changed — corpus de connaissances RAG (E7) : recentrage sources externes

Curation du manifest `inst/extdata/knowledge_corpus_v1.csv` (spec
009/009.1).

- **Retrait de l’amorçage interne** : les 12 documents internes MIT (10
  tutoriels `inst/tutorials/*` + specs 005/008) sont sortis du manifest.
  Le corpus s’appuie désormais sur des sources externes citables plutôt
  que sur la documentation du package elle-même.
- **+54 références BILJOU** : intégration de toutes les références
  citées par l’outil BILJOU (INRAE Nancy, modèle de bilan hydrique
  forestier ; 11 fiches pédagogiques). Familles principales `W`
  (eau/régulation), `R3` (sécheresse), `C` (vitalité/LAI), `F` (sols),
  `T` (phénologie). Par défaut prudent (gel licence D5) :
  `status=to_confirm`, `ingest_strategy=abstract_only`,
  `license=copyright` — jamais en full-text avant arbitrage.
- **8 rapports institutionnels passés en `cleared`** : ONF/RENECOFOR
  (`LO-Etalab`), FAO Irrigation & Drainage Paper 56 (`CC-BY-NC`), EFI
  *What Science Can Tell Us* n°1 (`CC-BY`). URLs publiques renseignées
  (HAL, FAO, EFI, PDF hébergés par BILJOU) ; 3 PDF directement
  ingérables ajoutés au plan de build (full-text : 7 → 10 PDF).

Le manifest passe de 39 à **81 docs** (31 `cleared` + 50 `to_confirm`).
Scripts de provenance reproductibles sous `data-raw/`
(`add_biljou_refs.R`, `clear_biljou_institutional.R`,
`url_biljou_institutional.R`).

## nemeton 0.74.1 (2026-06-12)

#### Fixed — `FOREIGN KEY constraint failed` au re-build des zones (backend SQLite)

`build_project_monitoring_zones(..., replace = TRUE)` échouait avec
`FOREIGN KEY constraint failed` lors du **re-build** d’un projet dont
les zones possédaient déjà des lignes enfants (placettes de validation,
alertes FORDEAD) — symptôme remonté depuis `nemetonshiny` sur le backend
**SQLite** local (Windows). La première génération sur une base vierge
réussissait ; seul le re-clic cassait.

- **Cause** : divergence de schéma PG↔︎SQLite. La variante PostgreSQL
  (`pg/0001_init.sql`) porte
  `plot.zone_id → monitoring_zone(id) ON DELETE CASCADE` et
  `alert.plot_id → plot(id) ON DELETE CASCADE`, mais la variante SQLite
  (`0001_init.sql`) avait délibérément retiré ces clauses `CASCADE`.
  Comme
  [`db_connect()`](https://pobsteta.github.io/nemeton/reference/db_connect.md)
  active `PRAGMA foreign_keys = ON`, le
  `DELETE FROM monitoring_zone WHERE project_uuid = ?` de l’upsert D5
  était bloqué par les lignes `plot`/`alert` enfants.
- **Correctif** : `.delete_project_zones()` supprime désormais la chaîne
  **explicitement, enfant d’abord** (`alert` → `plot` →
  `monitoring_zone`), dans une seule transaction — portable sur les deux
  backends (sur PostgreSQL les suppressions d’enfants font simplement
  doublon avec le cascade). Pas de migration de schéma : ajouter le
  cascade côté SQLite imposerait un *rebuild* de tables, incompatible
  avec la transaction unique de
  [`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)
  (`PRAGMA foreign_keys` est un no-op en transaction, et
  `defer_foreign_keys` ne lève pas la violation différée laissée par le
  `DROP TABLE` du parent).
- Côté app : aucun changement requis — `nemetonshiny` (v0.76.0) consomme
  déjà
  [`build_project_monitoring_zones()`](https://pobsteta.github.io/nemeton/reference/build_project_monitoring_zones.md)
  et bénéficie du fix dès que le `Remotes: pobsteta/nemeton@*release`
  tire cette version.

## nemeton 0.74.0 (2026-06-12)

#### Added — RECONFORT, orchestration end-to-end (spec 021, lot L2b.3)

Dernier sous-lot de l’intégration IOTA² :
[`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
relie L1/L2a/L2b.1/L2b.2 en un run complet (env → modèle → masque →
tuile → ingest S2 → IOTA² ×2 + RF + masque OSO + score continu).

- **`run_reconfort_dieback(con, zone_id, cache_dir, …)`** : oriente le
  run pour une zone de monitoring — valide l’env conda
  (\[`.ensure_reconfort_python`\]), récupère le modèle RF
  ([`ensure_reconfort_model()`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_model.md))
  et le masque feuillus
  ([`ensure_reconfort_oso_mask()`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_oso_mask.md)),
  résout l’AOI → tuile(s) MGRS, ingère les scènes S2, puis pilote la
  **map-production IOTA²** vendorisée. Produit les rasters `Classif` /
  `ProbabilityMap` / **score continu** (EPSG:2154,
  `(1001 + (−P1 + P2 + 2·P3))/30`) + un `run_meta.json`. **8 phases**
  avec `progress_callback` pour câblage app.
- **Staging par-run** : les scripts amont font `chdir` vers leur propre
  dossier et y écrivent `results/`. Pour garder le package installé en
  lecture seule, chaque run **stage une copie de travail** de la glue
  vendorisée (scripts + sous-arbre `iota2/` + modèle + masque + vue S2
  partitionnée par année en liens symboliques) sous `cache_dir` (même
  convention que le `cache_dir` de FORDEAD) et s’exécute depuis là.
- **[`ensure_reconfort_oso_mask()`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_oso_mask.md)** +
  **`RECONFORT_OSO_MASK`** : le masque feuillus OSO 2021 (~54 Mo) est
  **téléchargé à la demande** + checksum (MD5)
  - cache + fallback `local_path` (masque personnalisé), comme les
    modèles RF (L2a). `binary_mask = NULL` → OSO ; un chemin → masque
    custom ; `FALSE` → pas de masque (score depuis la proba brute).
- **Glue map-production vendorisée** (Apache-2.0,
  `inst/python/reconfort/`) : `run_map_production_reconfort.py`,
  `mask_and_compress_rasters.py`, les deux générateurs de cfg IOTA², et
  le sous-arbre `iota2/` (config, nomenclature,
  `external_features/custom_index.py` — déplacé à son chemin canonique
  —, `vector_db/random_points.*`).
- **Garde-fou de post-condition** : le driver amont ne vérifie pas le
  code de retour du subprocess IOTA² ; le pipeline **abort** si le
  raster de score continu n’a pas été produit (échec silencieux
  RAM/scheduler/données).
- Lourd + **opt-in** : un run réel nécessite l’env conda + compte
  GEODES + dizaines de Go de S2 + exécution OTB/Shark (batch), **jamais
  en CI**. Le post-process → table `alert` reste **L3**. 3 exports +
  `.Rd` à la main, section pkgdown. 24 tests mockés (orchestration, cfg,
  masquage on/off, garde-fous, staging), 0 régression (suite reconfort
  verte).

## nemeton 0.73.0 (2026-06-11)

#### Added — RECONFORT, ingestion S2 IOTA²-native (spec 021, lot L2b.2)

Acquisition des scènes Sentinel-2 dans le layout attendu par IOTA²
(décision de cadrage D1 : pas de réutilisation du cache COG FAST).

- `reconfort_aoi_tiles(aoi)` : résout la/les **tuile(s) MGRS**
  Sentinel-2 couvrant une AOI à partir d’une **grille embarquée**
  (`inst/extdata/ s2_mgrs_tiles_fr.geojson`, 188 tuiles France
  métropolitaine) — sans réseau. `data-raw/build_s2_mgrs_tiles_fr.R` la
  régénère depuis la grille ESA globale.
- `reconfort_ingest_s2(aoi|tiles, date_from, date_to, s2_root, …)` :
  télécharge les archives MUSCATE L2A depuis **GEODES** (via `pygeodes`)
  puis les dézippe vers `<s2_root>/extracted/<tile>/`. Pilote les
  scripts amont **vendorisés** (`run_geodes_download.py`,
  `run_process_downloaded_images.py` + `utils/`) en **subprocess
  conda**. Compte GEODES via `options(nemeton.geodes_config)` (défaut :
  le data dir utilisateur). nemeton n’embarque **aucune clé**.
- **Collection GEODES corrigée** (validée par smoke réel) :
  l’identifiant d’exemple amont `MUSCATE_SENTINEL2_SENTINEL2_L2A`
  n’existe pas côté GEODES (HTTP 400). Le défaut est désormais
  `THEIA_REFLECTANCE_SENTINEL2_L2A` (produits THEIA/MUSCATE de
  réflectance S2 L2A).
- **Cohérence du chemin de téléchargement** : `download_item_archive()`
  (pygeodes) écrit dans le `download_dir` de la config GEODES, alors que
  l’étape de dézippage cherche dans `zip_path`.
  [`reconfort_ingest_s2()`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)
  génère donc une **copie par-run** de la config pygeodes dont
  `download_dir` pointe sur le `zip_path` de la tuile (=
  `<s2_root>/zip/ <tile>/`, dans le cache projet fourni par l’appelant —
  même convention que le `cache_dir` de FORDEAD ; jamais `/tmp`). Cette
  copie porte la clé API : elle est écrite dans un **tempfile privé
  (mode 600)**, hors du cache projet, et effacée en fin de tuile.
  nemeton n’écrit **jamais** de secret dans le cache.
- **Garde-fous de post-condition** : le téléchargeur amont enveloppe
  chaque item dans un `except` nu qui imprime « Error downloading image
  » et **sort quand même en 0** — une coupure réseau sur une archive
  multi-Go (`ChunkedEncodingError`) ressemblait donc à un succès.
  [`reconfort_ingest_s2()`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)
  vérifie désormais qu’au moins une archive a atterri dans `zip_path`
  après le download, et au moins un dossier de scène dans `out_dir`
  après le dézippage ; sinon **abort** explicite (connectivité GEODES,
  fichier tronqué).
- Heavy + **opt-in** (compte GEODES + dizaines de Go de S2), **jamais en
  CI**. 14 tests (téléchargement mocké, override `download_dir` hors
  cache, garde-fous archive/scène manquante, `reconfort_aoi_tiles`
  validé sur la grille réelle : Loiret → `T31UDP`, CVL → 14 tuiles).
  **Smoke réel** validé (`data-raw/smoke_reconfort_ingest.R`) : env
  conda, résolution de tuile, recherche GEODES (1 scène), config par-run
  et streaming réel des octets confirmés bout-en-bout.

## nemeton 0.72.0 (2026-06-11)

#### Added — RECONFORT, fondations Python/IOTA² (spec 021, lot L2b.1)

Premier sous-lot de l’intégration du pipeline RECONFORT : helpers
d’environnement + bandes + glue vendorisée. Aucune exécution réelle ici
(le pipeline vient en L2b.2/L2b.3).

- `R/reconfort_python.R` : `.ensure_reconfort_python()` (interne)
  **localise et valide** l’environnement **conda** IOTA² (défaut
  `nemeton-reconfort`, surchargeable par
  `options(nemeton.reconfort_conda_env)`) — vérifie que `iota2` et
  `pygeodes` sont importables, **sans jamais le créer** (cadrage D2 :
  l’utilisateur l’installe via la procédure amont). Abort typé avec les
  instructions d’install si absent.
- `RECONFORT_BANDS` (`B04/B05/B06/B8A/B11/B12`) : bandes des indices
  CRswir/CRre (parallèle à `FORDEAD_BANDS`).
- Glue Python **vendorisée** `inst/python/reconfort/custom_index.py`
  (indices CRswir/CRre, Apache-2.0, attribuée dans `inst/NOTICE`). La
  glue d’orchestration (download GEODES, cfg IOTA², score) sera
  vendorisée en L2b.2/L2b.3 où elle est câblée.
- La validation des modules (`iota2`, `pygeodes`) passe par un
  **subprocess** (`conda run -n <env> python -c import …`),
  représentatif de l’usage IOTA² (piloté par subprocess) et robuste au
  quirk d’init unique de reticulate et aux effets de bord d’import
  (bannière OTB). Le binaire `conda` est préféré à `mamba` (dont
  reticulate mal-parse la sortie sur miniforge).
- 9 tests mockés (`test-reconfort-python.R`) **+ validation end-to-end
  contre un env conda réel** (`iota2` + `pygeodes` OK). Cadrage complet
  : `specs/021-suivi-sanitaire-reconfort/L2b-cadrage.md`.

## nemeton 0.71.0 (2026-06-11)

#### Added — RECONFORT, téléchargement du modèle RF (spec 021, lot L2a)

Deuxième lot RECONFORT : récupération à la demande du modèle Random
Forest (Shark/OTB) calibré, sans IOTA² ni Python. Les 4 modèles amont
(`model_1_seed_0.txt`, Apache-2.0) pèsent 5,7–197 Mo — redistribuables
mais inembarquables — donc **téléchargés à la demande, vérifiés par
checksum et mis en cache**.

- `R/reconfort_model.R` :
  `ensure_reconfort_model(version, cache_dir, local_path, ...)` — résout
  dans l’ordre (1) un fichier local fourni (`local_path`, p. ex. un
  clone amont), (2) le cache vérifié, (3) le téléchargement depuis le
  dépôt amont. Vérification taille + MD5 via
  [`tools::md5sum()`](https://rdrr.io/r/tools/md5sum.html) (aucune
  dépendance ajoutée).
- `RECONFORT_MODELS` : registre des 4 versions (`v3` / `v3_early_may`
  chêne 3 cl., `v3_chestnut` 3 cl., `v3_pine` 2 cl.) avec espèce, taille
  et MD5.
- `reconfort_model_info(version)` : accesseur du registre.
- URL amont surchargeable via
  `options(nemeton.reconfort_model_base_url)`.
- 10 tests (`test-reconfort-model.R`, téléchargement mocké) + fetch réel
  du modèle pin (5,7 Mo) vérifié end-to-end. Le code d’entraînement
  amont (`train_new_model/`) reste hors-scope.

## nemeton 0.70.0 (2026-06-11)

#### Added — RECONFORT, domaine de validité (spec 021, lot L1)

Premier lot de l’intégration **RECONFORT** (Mouret et al. 2023,
Apache-2.0) — 3ᵉ méthode de suivi sanitaire, dédiée au **dépérissement
des feuillus** (chêne, châtaignier, pin sylvestre) en région Centre-Val
de Loire, en complément de FORDEAD (résineux) et FAST. Ce lot livre
uniquement le **domaine de validité** (garde-fou G3), sans Python :

- `R/reconfort_validity.R` :
  `check_reconfort_validity(aoi, units, ...)`,
  [`load_reconfort_validity_zones()`](https://pobsteta.github.io/nemeton/reference/load_reconfort_validity_zones.md),
  et les constantes `RECONFORT_VALIDITY_DEPARTMENTS` (18/28/36/37/41/45)
  et `RECONFORT_VALIDITY_SPECIES` (CHE/CHT/PS). Détection d’essences
  feuillus (chêne *Quercus*, châtaignier *Castanea*, pin sylvestre
  *Pinus sylvestris* — pin maritime/noir exclus), réutilise le fallback
  BD Forêt V2 de FORDEAD.
- `inst/extdata/reconfort_validity_zones.geojson` : 6 départements CVL
  (~39 150 km², EPSG:4326, simplifié 100 m) + `data-raw/build_*.R`.
- **Différence avec FORDEAD** : le contrôle est **advisory, pas
  bloquant** (`advisory = TRUE` dans le résultat) — RECONFORT n’a aucun
  verrou géographique en amont (l’exemple amont tourne hors CVL), donc
  l’app avertit sans empêcher le diagnostic.
- 18 tests (`test-reconfort-validity.R`,
  `test-reconfort-validity-zones.R`).

> Note : le flag NDP `health_reconfort` et la datasource
> `reconfort_anomalies` prévus au plan §5 sont **reportés** — ils
> supposaient une parité FORDEAD (`health_fordead` /
> `fordead_anomalies`) qui n’a jamais existé et ne s’inscrit pas dans la
> sémantique actuelle d’`augmented` de
> [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md).

## nemeton 0.69.2 (2026-06-11)

#### Fixed — `.fast_raster_trend()` plantait sur une année mono-scène (spec 023)

Dans le mode FAST `trend`, une année n’ayant qu’une seule scène
in-season produit un `SpatRaster` à **une couche**, et
`terra::app(sub, fun)` lève alors « the number of values returned by
‘fun’ is not appropriate ». Le comptage des observations valides et la
médiane annuelle passent désormais par des primitives cell-wise robustes
à tout nombre de couches (`terra::nlyr() - terra::countNA()` et
[`terra::median()`](https://rspatial.github.io/terra/reference/summarize-generics.html)).
Bug livré en v0.69.0 et révélé à la première exécution CI réelle des
chemins terra. Régression couverte par `test-fast-trend.R` (année à
observation unique).

#### Added — spec 021 RECONFORT (3ᵉ méthode de suivi sanitaire, feuillus)

Dossier de conception (doc seule, pas de code) pour l’intégration de
**RECONFORT** (F. Mouret / CESBIO, Apache-2.0) comme méthode officielle
de diagnostic du dépérissement des **feuillus** (chêne, châtaignier, pin
sylvestre, Centre-Val de Loire), en complément de FORDEAD (résineux) et
FAST. `specs/021-suivi-sanitaire-reconfort/` reçoit `plan.md` (6
questions ouvertes tranchées sur le dépôt amont vérifié) et `spec.md`
(parité avec spec 008). L’**amendement A4 de l’ADR-013** reframe le
suivi sanitaire en « multi-méthodes » (vit dans `nemetonplateform`).
Faits clés vérifiés : `RECONFORT_BANDS = B04/B05/B06/B8A/B11/B12`,
indices CRswir/CRre, score continu `(1001 + (−P1 + P2 + 2·P3))/30`,
EPSG:2154, IOTA²/conda obligatoire.

#### Internal — CI verte et garde-fou anomalie terra du runner

La CI (`R-CMD-check`, `tests`, `coverage`, `pkgdown`) repasse au vert
après plusieurs corrections d’infrastructure préexistantes, sans rapport
avec le code métier : le job `tests` exécute désormais réellement la
suite
([`devtools::test()`](https://devtools.r-lib.org/reference/test.html) au
lieu d’un `test_package()` qui ne trouvait aucun test installé) ;
`R-CMD-check` délègue les tests au job dédié (`--no-tests`) et saute le
build des vignettes ; `pkgdown` gagne `rsconnect` (tutoriels) et l’index
de référence liste les 111 topics exportés manquants. Surtout, un
**garde-fou par capacité** (`skip_if_terra_write_broken()`) neutralise
une anomalie terra **propre au runner GitHub** (terra::rast/writeRaster
y lèvent « no valid constructor » dans le contexte testthat, alors que
le même code passe en local — toute la suite passe, PASS 7381) : les
tests raster **skippent** sur ce runner et **tournent en entier**
partout ailleurs. Le code reste prouvé correct.

## nemeton 0.69.1 (2026-06-10)

#### Fixed — extraction NDRE-only sans B08 (spec 022)

`extract_pixel_timeseries(..., indices = "NDRE")` plantait quand la
requête ne portait que sur NDRE : le CRS natif était lu en dur sur
`rs[["B08"]]`, or seules B8A/B05 sont chargées dans ce cas →
`terra::crs(NULL)`. Le CRS de référence est désormais pris sur la
première bande chargée (toutes les bandes d’une scène partagent le même
CRS). Les appels mixtes (NDVI/NBR/NDMI, qui chargent B08) n’étaient pas
affectés. Régression couverte par `test-ndre.R` (cache ne contenant que
B8A + B05). Merci au reviewer automatique Codex.

## nemeton 0.69.0 (2026-06-10)

#### Added — mode FAST `trend` : dépérissement chronique (spec 023)

Troisième sémantique du sous-système FAST, à côté de `count` et
`rolling`. Paradigme **relatif** (chaque pixel est sa propre référence,
pas de seuil absolu) pour détecter le **déclin lent pluriannuel** des
feuillus (chêne/hêtre) que les modes court-horizon ne voient pas.

- `read_fast_alert_raster(..., mode = "trend")` : compose une médiane
  saisonnière annuelle (`months = 6:9`, années à \< `min_obs_per_year`
  observations claires écartées, `min_years` années minimum), puis
  estime une pente **Theil-Sen** + un test de significativité
  **Mann-Kendall** par pixel. Sortie = `abs(pente)` là où la pente est
  négative **et** p_MK \< `alpha`, sinon `0` ; pixels à années
  insuffisantes = `NA`.
- **Contrat préservé** : la sortie est le même raster continu (`0` = pas
  d’alerte, `> 0` = magnitude) que count/rolling, donc
  `compute_fast_alert_mask(..., mode = "trend")` la discrétise en
  classes 0-4 via les mêmes quartiles, **sans modification** —
  Mann-Kendall joue le rôle de porte que le seuil absolu joue pour
  count/rolling.
- Nouveaux arguments trend-only sur les deux fonctions FAST : `months`,
  `min_years`, `min_obs_per_year`, `alpha`. `threshold` et `window_days`
  sont ignorés en mode trend.
- **Défaut d’indice mode-dépendant** : `NDVI` pour count/rolling
  (rétro-compat), `NDMI` pour trend (l’humidité décroche en premier).
  L’indice `NDRE` (spec 022) est sélectionnable dans les deux fonctions.
- Helpers internes réutilisables `.theil_sen()` et `.mann_kendall()`
  (variance corrigée des ex-aequo, p-value bilatérale, correction de
  continuité).
- Le cache de résultat (COG adressé par contenu) intègre `alpha`,
  `months`, `min_years`, `min_obs_per_year` dans le hash **et** le nom
  de fichier (`fast_<INDEX>_trend_a<alpha>_m<mois>_y<min_years>_…`) : un
  changement de paramètre s’auto-invalide. Le hash count/rolling est
  **inchangé** (params trend ajoutés seulement en mode trend) — les COG
  existants restent valides.
- Modes `count` / `rolling` strictement inchangés (non-régression).

## nemeton 0.68.0 (2026-06-10)

#### Added — indice red-edge NDRE (spec 022)

Nouvel indice spectral **NDRE = (B8A − B05) / (B8A + B05)**, marqueur
red-edge du stress chlorophyllien précoce, ajouté au sous-système FAST.
C’est le prérequis du mode `trend` (déclin chronique des feuillus).

- `build_index_stack(cache_dir, scenes_df, index = "NDRE")` calcule la
  pile NDRE. B8A et B05 sont nativement à 20 m et partagent la même
  grille : l’indice reste à 20 m, sans rééchantillonnage.
- `extract_pixel_timeseries(..., indices = "NDRE")` renvoie la série
  red-edge par pixel.
- [`read_s2_band_raster()`](https://pobsteta.github.io/nemeton/reference/read_s2_band_raster.md)
  accepte désormais `"B05"` et `"B8A"`.
- `ingest_sentinel2_timeseries(..., bands = "NDRE")` met en cache B05 +
  B8A (les bandes red-edge ne sont téléchargées que sur demande
  explicite).
- Nouveau garde-fou interne `.assert_cache_has_bands()` : demander NDRE
  sur un cache qui n’a jamais ingéré B05/B8A échoue avec un message
  `cli` explicite plutôt qu’un raster all-NA silencieux.
- Les indices existants (NDVI, NBR, NDMI) et leur comportement
  count/rolling sont strictement inchangés.

## nemeton 0.67.0 (2026-06-04)

#### Added — nettoyage des caches de zones orphelines (spec 020)

`prune_orphan_zone_caches(con, cache_root, dry_run = FALSE)` : supprime
les dossiers `zone_<id>/` (sous `fast_alert/`, `fast_alert_mask/`,
`fast_sampling/`, `fast/`, `fast_raster/`, `fordead/`) dont le `zone_id`
n’existe plus dans `monitoring_zone`. Ces orphelins apparaissent après
un upsert de zones (`build_project_monitoring_zones(replace = TRUE)`) :
les zones recréées reçoivent de nouveaux id, laissant les caches
`zone_<ancien_id>/` orphelins (la GC LRU par zone ne purge qu’à
l’intérieur d’un dossier vivant, jamais un dossier entier périmé).
`dry_run = TRUE` prévisualise sans supprimer ; les dossiers partagés
(`sentinel2/`, `lidar_*`) ne sont jamais touchés.

## nemeton 0.66.0 (2026-06-04)

#### Added — zones de suivi par strates BD Forêt v2 (spec 020)

Un projet peut désormais porter **jusqu’à 4 zones de suivi** construites
par croisement de l’**union des UGFs** avec les **strates de BD Forêt
v2** :

| Zone           | Géométrie                      |
|----------------|--------------------------------|
| `<projet>_tot` | union des UGFs                 |
| `<projet>_feu` | union des UGFs ∩ feuillus      |
| `<projet>_res` | union des UGFs ∩ résineux      |
| `<projet>_mix` | union des UGFs ∩ forêts mixtes |

Strates classées via le champ **`tfv_g11`** de BD Forêt (repli
`essence`).

- **`build_project_monitoring_zones(con, project_name, project_uuid, ugf, bdforet, …)`**
  : construit et enregistre les zones. Strate vide → zone non créée
  (avertissement). `replace = TRUE` (défaut) : upsert idempotent
  (supprime puis recrée les zones du projet).
- **`create_monitoring_zone(con, zone_name, zone_polygon, project_uuid)`**
  : insert zone-seule, **sans placette** (depuis spec 017 le diagnostic
  FAST/FORDEAD est pur raster, placette-indépendant).
- **`find_zones_by_project(con, project_uuid)`** : liste les zones (id,
  name) d’un projet (un projet peut en avoir plusieurs).
- **Migration 0005** (pg + sqlite) : unicité `monitoring_zone` relâchée
  de `project_uuid` seul à **`(project_uuid, name)`** → N zones par
  projet.

#### Fixed

- `register_monitoring_zone(project_uuid = …)` récupérait l’id de la
  zone insérée via `WHERE project_uuid = $1` seul ; avec le modèle
  multi-zones (spec 020) cela pouvait renvoyer le mauvais id. Corrigé en
  `WHERE project_uuid = $1 AND name = $2`.

## nemeton 0.65.3 (2026-06-03)

#### Added — GC LRU du cache des masques FAST 0-4

[`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
écrit un masque **horodaté** (`fast_alert_<ts>.tif`) à chaque appel —
contrairement au cache continu content-addressed, le dossier des masques
grossissait donc indéfiniment. Nouvelle GC `.fast_alert_mask_gc()`
appelée après chaque écriture : ne garde que les
`getOption("nemeton.fast_mask_keep", 20)` masques les plus récents par
zone (LRU par mtime), comme `.fast_raster_gc()` le fait déjà pour les
COG continus (`nemeton.fast_raster_keep`).

#### Fixed — la GC continue ne touche plus aux masques

`.fast_raster_gc()` (cache continu) globait `^fast_.*\.tif$`, ce qui
incluait les masques `fast_alert_*.tif` quand
`result_cache_dir == mask_cache_dir` (cas de la validation sampling sur
`fast_sampling/`) — les deux caches se disputaient le même quota et
pouvaient se supprimer mutuellement. Le motif est resserré à
`^fast_[A-Z].*\.tif$` (les COG continus
`fast_NDVI_`/`fast_NBR_`/`fast_NDMI_`, jamais les masques `fast_alert_`
en minuscule) : les deux caches sont désormais ramassés indépendamment.

## nemeton 0.65.2 (2026-06-03)

#### Changed — naming verbose et lisible du cache D6 FAST

Les COG du cache content-addressed (spec 017 D6) passent du nom opaque
`fast_<INDEX>_<MODE>_<hash>.tif` à un nom **verbeux et déterministe** :

    fast_<INDEX>_<MODE>_thr<seuil>_<from>_<to>_w<window>_<hash8>.tif
    ex. fast_NBR_count_thr0.30_2025-05-23_2026-05-23_w30_fd9ca32a.tif

Les paramètres clés (seuil, fenêtre temporelle, `window_days`) sont
désormais lisibles directement dans le nom de fichier — deux cartes de
même `INDEX`/`MODE` dans une même `zone_<id>` se distinguent à l’œil
sans recalcul. Un extrait de 8 caractères du hash D6 (inchangé) continue
de discriminer les entrées qui ne tiennent pas dans un nom : la liste
des scènes S2 (change après ré-ingestion) et le polygone de masque UGF.

**Idempotence préservée** : mêmes paramètres → même nom → hit cache. Le
hash sous-jacent (`.fast_raster_hash()`) est inchangé.

**Anciens fichiers** : les COG au format pré-0.65.2
(`fast_<index>_<mode>_<hash_long>.tif`) ne sont plus reconnus comme hits
; ils sont simplement recalculés à la 1re demande (cache idempotent)
puis ramassés par la GC LRU (`nemeton.fast_raster_keep`). Pour récupérer
l’espace tout de suite sur un projet existant :

``` bash
rm -f <projet>/cache/layers/fast_alert/zone_*/fast_*_[0-9a-f][0-9a-f]*.tif
```

## nemeton 0.65.1 (2026-06-03)

#### Fixed — le prewarm FAST couvre désormais les 6 cartes (oubli de v0.65.0)

`.prewarm_fast_alerts()` (pré-calcul optionnel en fin
d’[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md),
spec 018) ne pré-chauffait que **4** combinaisons (NDVI/NBR ×
count/rolling), alors que l’orchestrateur public
[`read_fast_alert_rasters()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_rasters.md)
en expose **6** (NDMI ajouté en v0.65.0, spec 019). Conséquence : la 1re
sélection **NDMI** côté app déclenchait un calcul à froid au lieu d’un
hit cache D6 instantané. La boucle couvre maintenant les 3 indices × 2
modes. Une scène sans B11 (nécessaire à NDMI) emprunte le chemin de skip
best-effort existant (`tryCatch` + `cli_warn`, événement
`fast_prewarm:NDMI_<mode>_failed`), comme NBR sans B12 — aucune
exception, aucun changement d’API.

## nemeton 0.65.0 (2026-06-03)

#### Fixed — cartes d’alerte NDMI absentes (régression spec 019)

`.enumerate_cache_scenes()` (le sélecteur de scènes du diagnostic FAST
raster) ne connaissait pas l’index **NDMI** : son `switch(index, ...)`
n’avait que les branches `NDVI` et `NBR`, et renvoyait `NULL` pour NDMI.
Conséquence — `read_fast_alert_raster(index = "NDMI")` (et
[`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
en NDMI) ne trouvait **jamais** de scène, même avec B08 + B11 en cache,
et retournait toujours `NULL`. L’ingestion NDMI fonctionnait, mais la
carte d’alerte ne sortait pas. Le `switch` gère désormais
`NDMI -> B08 + B11` (et lève une erreur explicite sur un index inconnu
plutôt que d’échouer silencieusement).

#### Added — orchestrateur des 6 cartes FAST

Nouvelle fonction exportée
[`read_fast_alert_rasters()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_rasters.md)
: construit en un seul appel l’ensemble du diagnostic FAST — les 3
indices (`NDVI`, `NBR`, `NDMI`) dans les 2 sémantiques (`count`,
`rolling`), soit **6 rasters**. Retourne une `list` nommée
`"<index>_<mode>"` (ex. `"NDMI_rolling"`) ; chaque carte est produite
exactement comme un appel direct à
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
(même cache COG, même cache résultat content-addressé spec 017 D6, même
masque de zone). Une carte sans scène en cache pour son index reste
`NULL` (forme de sortie stable). Les arguments `indices`/`modes`
permettent de restreindre le sous-ensemble.

## nemeton 0.64.0 (2026-06-03)

#### Added — indice NDMI dans le suivi sanitaire FAST (spec 019)

Nouvel index calculable du suivi rapide **FAST**, à côté de NDVI et NBR
:

**NDMI = (B08 − B11) / (B08 + B11)** (NIR − SWIR1) — proxy de
l’**humidité de la végétation**, qui baisse sous stress hydrique. Il
s’intègre tel quel dans la machinerie d’alerte FAST (déclin sous seuil =
alerte, modes `count`/`rolling`, classification 0-4 par quartiles).

- [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  et
  [`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md)
  acceptent `index/indices = "NDMI"` ; B11 (SWIR1, 20 m) est
  rééchantillonnée bilinéairement à la grille 10 m de B08, exactement
  comme B12 pour NBR.
- [`read_s2_band_raster()`](https://pobsteta.github.io/nemeton/reference/read_s2_band_raster.md)
  /
  [`read_s2_band_stack()`](https://pobsteta.github.io/nemeton/reference/read_s2_band_stack.md)
  acceptent la bande `"B11"`.
- [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  et
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  acceptent `index = "NDMI"` ; le COG résultat est
  `fast_NDMI_<mode>_<hash>.tif` (le hash D6 inclut l’index → aucune
  collision avec les caches NDVI/NBR existants). Le **défaut reste
  NDVI** (rétro-compatible).
- Seuil NDMI : reprend le défaut générique non-NDVI (0.30, comme NBR) ;
  la classification 0-4 reste **adaptative** (quartiles) — aucune
  calibration NDMI dédiée (décision D2).
- [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  accepte `bands = "NDMI"` et met **B11 en cache systématiquement**
  (best-effort, décision D3) : NDMI est disponible sur les futurs
  ingests sans le demander explicitement. Une scène dépourvue de B11 est
  ignorée sans faire échouer l’ingestion NDVI/NBR.

B11 est déjà recherchée sur STAC (`.S2_STAC_BANDS`) — aucune
modification de la requête STAC. Les caches NDVI/NBR existants sont
intacts ; pour calculer NDMI sur des scènes déjà cachées, ré-ingérer la
zone (`skip_cached = FALSE`) afin de peupler B11.

Plan détaillé : `specs/019-ndmi-fast-index/spec.md`.

## nemeton 0.63.0 (2026-06-03)

#### Added — API publique d’administration du corpus RAG (spec 009.2)

Promotion en **API publique** de l’orchestration « manifest → base » qui
ne vivait jusqu’ici que dans `data-raw/build_knowledge_corpus.R`.
Objectif : permettre à un **onglet RAG** côté `nemetonshiny` d’éditer le
manifest et de lancer l’import **sans réimplémenter de logique métier**
(règles 1-3 de CLAUDE.md). Nouveau fichier `R/knowledge-corpus.R`, six
fonctions exportées :

- **[`knowledge_manifest_vocab()`](https://pobsteta.github.io/nemeton/reference/knowledge_manifest_vocab.md)**
  — vocabulaires contrôlés (colonnes, licences, statuts, stratégies,
  langues, doc_types, profils, regex famille). Désormais **source unique
  de vérité** : le test d’intégrité `test-knowledge-corpus-manifest.R`
  les consomme au lieu de les dupliquer.
- **`knowledge_manifest_path(writable)`** — résout le **seed packagé**
  (lecture seule) ou la **copie projet inscriptible** (décision D1),
  amorcée par recopie du seed au premier accès
  (`NEMETON_KNOWLEDGE_MANIFEST` ou défaut sous
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)).
- **[`read_knowledge_manifest()`](https://pobsteta.github.io/nemeton/reference/read_knowledge_manifest.md)**
  — CSV → data.frame typé (16 colonnes).
- **[`validate_knowledge_manifest()`](https://pobsteta.github.io/nemeton/reference/validate_knowledge_manifest.md)**
  — renvoie un data.frame d’anomalies (`row`, `doc_id`, `severity`,
  `field`, `message`) : structure, enums, codes famille/profil,
  **garde-fous licence D5** (`cleared` jamais `to-confirm`, `copyright`
  jamais `full`, extension `local_path` ingérable). 0 ligne = valide.
  N’avorte pas → affichage inline côté app.
- **[`write_knowledge_manifest()`](https://pobsteta.github.io/nemeton/reference/write_knowledge_manifest.md)**
  — valide puis écrit le CSV avec un quoting minimal déterministe (diffs
  git propres) ; refuse un manifest porteur d’erreurs bloquantes.
- **`build_knowledge_corpus(con, manifest, …, dry_run, progress)`** —
  l’orchestrateur d’ingestion extrait du script : garde-fou licence,
  éligibilité, idempotence (skip si titre déjà en base), `full` vs
  `abstract_only`/`link_only`, `fresh`, `dry_run`. **Fonction R
  bloquante pure** retournant un **rapport structuré** (une ligne par
  document : `action ∈ {ingested, skipped, error, planned}`, `reason`,
  `mode`, `n_chunks`, `document_id`, `duration_sec`) et acceptant un
  callback `progress` — pilotable en asynchrone (`ExtendedTask`) côté
  app.

#### Changed

- `data-raw/build_knowledge_corpus.R` réduit à un **mince wrapper CLI**
  par-dessus
  [`build_knowledge_corpus()`](https://pobsteta.github.io/nemeton/reference/build_knowledge_corpus.md)
  : il ne lit que les variables d’environnement et imprime le rapport.
  CLI et sémantique des env vars (dont la règle de sécurité « pas de
  fallback vers `NEMETON_DB_URL` ») strictement préservées.

Plan détaillé : `specs/009.2-administration-corpus-rag/spec.md`.

## nemeton 0.62.0 (2026-06-02)

#### Added — ingestion « référence seule » (link_only / abstract_only) du corpus RAG (spec 009.1 §5)

Nouvelle fonction exportée
**[`ingest_knowledge_reference()`](https://pobsteta.github.io/nemeton/reference/ingest_knowledge_reference.md)**
: pour les documents dont le texte intégral n’est pas redistribuable
(papiers sous paywall, rapports tous droits réservés), elle n’ingère
qu’**une référence citable** — jamais le corps protégé.

- Un seul chunk est construit et embeddé : une **citation
  bibliographique** compacte (titre, auteur, année, éditeur, URL),
  suivie de l’**abstract** s’il est fourni
  (`ingestion_mode = "abstract_only"`) ou d’une mention « texte intégral
  non redistribué » sinon (`ingestion_mode = "link_only"`).
- Le mode est enregistré dans `metadata.ingestion_mode` (colonne JSON
  `metadata` — **aucune migration**), si bien qu’un corpus peut être
  audité : full-text vs référence seule.
- Implémentation **DRY** : elle délègue le chunk → embed → insert
  transactionnel à
  [`ingest_knowledge_document()`](https://pobsteta.github.io/nemeton/reference/ingest_knowledge_document.md)
  (une référence courte est juste une source-texte d’un chunk), donc
  zéro duplication de pipeline et comportement existant inchangé.
- **`data-raw/build_knowledge_corpus.R`** câble les lignes
  `abstract_only` / `link_only` du manifest (auparavant ignorées) vers
  [`ingest_knowledge_reference()`](https://pobsteta.github.io/nemeton/reference/ingest_knowledge_reference.md),
  sous le même verrou de licence D5. Les 4 papiers copyright (Mouret,
  Fassnacht, McCool, Beven & Kirkby) deviennent ainsi des références
  citables (titre + DOI) sans redistribution — dès que leur statut est
  levé.

Débloque le dernier morceau de machinerie corpus côté cœur : le RAG peut
désormais **citer** une source sans en détenir le texte.

## nemeton 0.61.2 (2026-06-02)

#### Changed — arbitrage des licences du corpus RAG (spec 009.1 D5)

Décisions de licence prises par Pascal (D5 — Claude n’arbitre jamais le
juridique) sur les documents `to_confirm` du manifest
`inst/extdata/knowledge_corpus_v1.csv` :

- **Bernard & Doridant 2024** (rapport ONF/DSF, fonde les garde-fous R5
  de la spec 008) → **Licence Ouverte confirmée**, `status = cleared`.
  Reste à attacher le PDF/URL DSF pour l’ingestion effective.
- **Revue SET « Forêt, croissance et changement climatique »** (seul doc
  avec un PDF local présent) → **licence ouverte/CC-BY confirmée**,
  `status = cleared` → s’ingérera au prochain build du corpus.
- **4 papiers copyright** (Mouret 2022, Fassnacht 2016, McCool 1987,
  Beven & Kirkby 1979) → laissés `to_confirm` (copyright → jamais
  full-text, abstract/lien-seul à câbler ultérieurement).

Bilan manifest : **35 `cleared` / 4 `to_confirm`**. Le test
`test-knowledge-corpus-manifest.R` reste vert (invariants D5/§5).

## nemeton 0.61.1 (2026-06-02)

#### Fixed — cohérence du manifest corpus RAG + garde-fous (spec 009.1)

Durcissement du livrable corpus E7 (sans toucher le code RAG ni arbitrer
de licence) :

- **Correction manifest** `inst/extdata/knowledge_corpus_v1.csv` : la
  ligne `set_revue_foret_croissance_climat` portait `status = cleared`
  alors que sa `license` est littéralement `to-confirm` — le pipeline
  l’aurait donc ingérée malgré une licence non confirmée, en
  contradiction avec la décision D5 (« pas d’ingestion tant que la
  licence n’est pas tranchée »). Statut remis à `to_confirm` (aucune
  décision juridique prise — simple retour du côté sûr).
- **Nouveau test de validation** `test-knowledge-corpus-manifest.R` (20
  assertions) : le manifest packagé — source unique de vérité du corpus
  — est désormais gardé sur sa structure (colonnes, `doc_id` uniques et
  slug), ses énumérations (`license`, `status`, `ingest_strategy`,
  `lang`, `doc_type`, `license_commercial_ok`), la validité des codes
  familles/profils, et deux invariants de sécurité D5/§5 : un document
  `cleared` ne peut pas avoir de licence vide ou `to-confirm`, et un
  document `copyright` ne peut jamais être ingéré en `full`.
- **`inst/NOTICE`** : nouvelle section « RAG knowledge corpus » listant
  les attributions par classe de licence (Légifrance, EUR-Lex, IPCC,
  Etalab OFB/ONF/CNPF, CC-BY, dépôts HAL, autorisation Tran-Ha) et
  rappelant que les sources copyright ne sont jamais redistribuées
  (abstract-only / link-only).

## nemeton 0.61.0 (2026-06-02)

#### Added — pré-calcul des 4 cartes FAST en fin d’ingestion (spec 018)

[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
accepte un paramètre opt-in **`prewarm_alerts = FALSE`**. Quand
`prewarm_alerts = TRUE` (et qu’un répertoire de cache résultat est
fourni via `prewarm_mask_cache_dir`), la fonction enchaîne en fin
d’ingestion réussie sur **4 appels**
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
couvrant les combinaisons usuelles `NDVI`/`NBR` × `count`/`rolling`, au
threshold par défaut (0.40 NDVI / 0.30 NBR) et `window_days = 30`. Les 4
COG résultats atterrissent dans le cache D6
(`<dir>/zone_<id>/fast_<index>_<mode>_<hash>.tif`) → l’onglet Alertes
FAST de l’app devient instantané au premier affichage, et les bascules
NDVI↔︎NBR / Fréquence↔︎Intensité ne déclenchent plus de recalcul.

- **Tolérant aux échecs partiels** : les 4 combinaisons sont
  indépendantes. Une combinaison qui échoue (p. ex. `NBR` sur une zone
  dont le cache n’a pas de bande B12) émet un avertissement et est
  ignorée — les autres aboutissent quand même. La combinaison manquante
  est simplement recalculée à la volée à la première visite.
- **Cancel coopératif respecté** : le pré-calcul interroge `cancel_path`
  entre chaque combinaison ; un cancel arrivant en cours de route
  s’arrête proprement après la combinaison courante (les COG déjà écrits
  restent valides). Une ingestion annulée ne démarre jamais le
  pré-calcul.
- **Heartbeat progress** : 4 phases émises via `progress_callback`
  (`fast_prewarm:<index>_<mode>` / `_done` / `_failed`), chacune portant
  `index` et `mode` pour un toast localisable côté app.
- **Non-breaking** : `prewarm_alerts = FALSE` par défaut → les workflows
  existants sont inchangés.

Côté app `nemetonshiny` (à venir, `v0.54.0`) : `service_monitoring.R`
forwarde `prewarm_alerts = TRUE` +
`prewarm_mask_cache_dir = <projet>/cache/layers/fast_alert`, plancher
`Imports: nemeton (>= 0.61.0)`.

## nemeton 0.60.0 (2026-06-02)

#### Removed — retrait définitif des trois lecteurs `obs_pixel` (Phase B)

Suite de la v0.58.0 (Phase A, dépréciation). Le diagnostic FAST étant
100 % pur raster per-pixel depuis la spec 017, et `obs_pixel` ayant été
supprimée (migration 0004), les trois fonctions dépréciées sont
**retirées du package** :

- `read_obs_pixel()` — utiliser
  [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  /
  [`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md)
  (cache COG per-pixel) ;
- `list_fast_alerts_for_zone()` — utiliser
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  /
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  (FAST pur raster) ;
- `detect_alerts()` — idem (le suivi sanitaire passe par FORDEAD +
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)).

Fichiers `R/read_obs_pixel.R`, `R/fast_alerts.R`, `R/alerts.R` et leurs
`man/*.Rd` supprimés ; exports retirés du `NAMESPACE`. Les helpers
internes associés partent avec (`.empty_obs_pixel()`,
`.coerce_obs_date()`, `.empty_fast_alerts()`, `.coerce_alert_date()`).
La table `alert` reste en place : elle est toujours alimentée par le
post-traitement FORDEAD
([`list_alerts()`](https://pobsteta.github.io/nemeton/reference/list_alerts.md)
la lit).

**Simplification du schéma** : le `CREATE TABLE obs_pixel` (+
`create_hypertable` PG) est retiré des migrations `0001_init.sql` (PG +
SQLite) — les **nouvelles** bases ne créent plus jamais la table. La
migration `0004_drop_obs_pixel.sql` est conservée pour les bases
**existantes** (DROP idempotent ; no-op sur une base neuve).

**Breaking** pour tout appel direct aux trois fonctions retirées (elles
émettaient déjà un `cli_warn` de dépréciation en v0.58.0). Côté app :
`nemetonshiny@v0.52.16` ne les consomme plus → aucun impact.

**Tests** : `test-obs_pixel-deprecation.R` supprimé (fonctions parties)
; `test-db.R` vérifie l’absence de `obs_pixel` après migration sur une
base neuve (PG + SQLite) ; suites `obs_pixel` legacy déjà retirées en
v0.58.0. **NON TESTÉ EN CI ICI** (pas de R) — rejouer sur les deux
backends +
[`devtools::document()`](https://devtools.r-lib.org/reference/document.html)
(les `man/*.Rd` ont été ajustés à la main).

## nemeton 0.58.0 (2026-06-02)

#### Removed — insertion `obs_pixel` dans `ingest_sentinel2_timeseries()` (suite spec 017 v0.55.0)

Le diagnostic FAST est désormais **100 % pur raster per-pixel** : depuis
la spec 017 (v0.55.0),
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
énumère les scènes directement depuis le cache COG, indépendamment de
`obs_pixel` / placettes. La table `obs_pixel` (observations per-placette
NDVI/NBR) n’a plus aucun consommateur applicatif depuis
`nemetonshiny@v0.52.16` (plus de `read_obs_pixel()`, plus de modale
per-placette, plus de `CircleMarkers` placettes sur la Carte FAST).

**Phase A (cette release) :**

- **[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)**
  n’extrait plus la moyenne per-placette ni n’insère dans `obs_pixel`.
  Le pipeline se réduit à **amorcer le cache COG** : résolution STAC
  inchangée, download/cache des bandes B04/B08/B12 sous
  `<cache_dir>/<scene_id>/<band>.tif` inchangé, heartbeats `s2:*`
  conservés. Le champ `n_obs_inserted` disparaît du résumé retour ;
  `skip_cached` opère désormais sur le cache COG (scène ignorée quand
  toutes ses bandes requises sont déjà sur disque) au lieu de
  `obs_pixel`. Gain : ~5-15 s/scène économisés sur les zones à
  nombreuses placettes ; un seul stockage à maintenir.
- **Migration `0004_drop_obs_pixel.sql`** (PG + SQLite) :
  `DROP TABLE IF EXISTS obs_pixel CASCADE` (PG) /
  `DROP TABLE IF EXISTS obs_pixel` (SQLite). Idempotente, sûre à
  re-jouer.
- **Dépréciation** des trois derniers lecteurs `obs_pixel`,
  `@keywords internal` + avertissement
  [`cli::cli_warn`](https://cli.r-lib.org/reference/cli_abort.html)
  (retrait prévu en **v0.60.0**) :
  - `read_obs_pixel()` — utiliser
    [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
    /
    [`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md)
    (cache COG per-pixel) ;
  - `list_fast_alerts_for_zone()` — FAST per-placette legacy, remplacé
    par
    [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
    /
    [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
    ;
  - `detect_alerts()` — détection d’alertes per-placette legacy, idem.
- Helpers internes retirés : `.insert_obs_pixel()`,
  `.find_cached_obs_dates()` ; `.extract_scene_obs()` remplacé par
  `.cache_scene_bands()` (cache des bandes COG uniquement) + helpers
  `.s2_required_bands()` / `.scene_cogs_cached()`.

**Non breaking côté app** (`nemetonshiny@v0.52.16` ne lit plus
`obs_pixel`, aucun bump `Imports` requis) ; **breaking pour quiconque
appelle directement** `read_obs_pixel()` / `list_fast_alerts_for_zone()`
/ `detect_alerts()` (dépréquation + warning maintenant, retrait
v0.60.0).

**Tests** : `test-monitoring.R` réécrit (amorçage cache COG + skip
COG-based, plus aucune assertion `obs_pixel` / `n_obs_inserted`) ;
`test-db.R` vérifie que `0004` supprime `obs_pixel` (PG + SQLite,
idempotent) ; `test-ingest-cancel.R` assertion partielle sur le cache
COG ; `test-obs_pixel-deprecation.R` (nouveau) couvre les 3
avertissements. Suites supprimées : `test-read_obs_pixel.R`,
`test-fast_alerts.R`, `test-alerts.R`, `test-insert-obs-pixel-sqlite.R`
(toutes adossées à `obs_pixel`). **NON TESTÉ EN CI ICI** (pas de R dans
l’environnement) — à rejouer sur machine avec R sur les **deux
backends** (Postgres + SQLite) via `NEMETON_DB_URL_TEST` (rappel
v0.54.0), et
[`devtools::document()`](https://devtools.r-lib.org/reference/document.html)
à exécuter (les `man/*.Rd` ont été mis à jour à la main).

## nemeton 0.57.0 (2026-06-02)

#### Added — calcul raster multi-cœur opt-in (spec 017 D4, dernière phase perf)

[`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
et
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
/
[`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
acceptent un paramètre **`parallel = FALSE`**. Quand `parallel = TRUE`
et que est installé, le calcul **par scène** de l’indice (ouverture des
COG + band-math) est réparti sur plusieurs cœurs via
[`furrr::future_map()`](https://furrr.futureverse.org/reference/future_map.html)
— c’est la phase dominante du diagnostic FAST. Le
[`future::plan()`](https://future.futureverse.org/reference/plan.html)
est choisi par l’appelant (`multisession` en prod, `multicore` en fork
Unix).

- Un `SpatRaster` étant un pointeur externe non sérialisable entre
  process, les workers renvoient des rasters
  [`terra::wrap()`](https://rspatial.github.io/terra/reference/wrap.html)-és
  que le process principal
  [`unwrap()`](https://rspatial.github.io/terra/reference/wrap.html).
  Aucune écriture concurrente (band-math pur, sans DB).
- **Repli séquentiel transparent** : `parallel = TRUE` sans retombe sur
  `lapply` (avertissement une fois par session). Résultats **strictement
  identiques** au mode séquentiel.
- `furrr` / `future` déjà en Suggests — pas de nouvelle dépendance.

**Spec 017 close** (D1-D6 + D4) : indicateur unique + quartiles +
énumération cache (v0.55.0), persistance content-addressed (v0.56.0),
parallélisation (v0.57.0). Côté app `nemetonshiny` : exposer un toggle «
Mode rapide (multi-cœur) » → `parallel = TRUE`, et corriger l’appel
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
(signature v0.55 `index`/`threshold`).

## nemeton 0.56.0 (2026-06-01)

#### Added — persistance content-addressed du raster d’alertes FAST (spec 017 D6, phase perf)

[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
persiste désormais le **raster continu** résultat en **COG adressé par
contenu** : une revisite avec les mêmes entrées est servie
**instantanément** depuis le disque (zéro recalcul). C’est le plus gros
levier perf UX — le diagnostic est coûteux et re-consulté souvent
(navigation, re-rendu, reclassement quartiles).

- Deux nouveaux paramètres : `cache_result = TRUE` (défaut) et
  `result_cache_dir = NULL` (défaut
  `file.path(dirname(cache_dir), "fast_raster")`). COGs sous
  `<result_cache_dir>/zone_<id>/fast_<index>_<mode>_<hash>.tif`.
- **Auto-invalidation par le contenu** : le `hash` digère scènes triées
  - index + threshold + mode + window_days + dates + WKT du masque. Une
    nouvelle scène dans le cache, tout changement de paramètre, ou une
    ré-inscription de zone change le hash → recalcul ; sinon → lecture
    disque. Pas de logique de *staleness* fragile.
- L’attribut `cached = TRUE` est posé quand le raster vient du cache.
- **GC** : au plus `getOption("nemeton.fast_raster_keep", 20)` COGs
  conservés par zone (LRU par mtime).
- [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  expose aussi `cache_result` / `result_cache_dir` (passe-plat) : les
  **quartiles se recalculent depuis le COG persisté** sans recalcul
  raster.
- Hash via [`rlang::hash`](https://rlang.r-lib.org/reference/hash.html)
  (déjà en Imports) — **pas** de dépendance `digest` ajoutée (écart
  assumé vs spec, plus léger).

Prochaine phase perf : parallélisation `furrr` (D4 → v0.57.0).

## nemeton 0.55.2 (2026-06-01)

#### Fixed — incompatibilités SQLite résiduelles dans les UPSERT (`ON CONFLICT`)

Audit complet des `ON CONFLICT … DO NOTHING` du cœur après le correctif
v0.55.1 (qui ne couvrait qu’un des trois `INSERT … SELECT`). Trois sites
restaient incompatibles avec le backend SQLite local :

- **[`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)**
  (`R/db.R`) : l’`INSERT INTO schema_migration … ON CONFLICT DO NOTHING`
  **sans colonne cible** n’est valide que sur SQLite ≥ 3.35.0 ; les
  moteurs antérieurs lèvent `near "DO": syntax error`. Branché par
  backend → `INSERT OR IGNORE` (forme SQLite native, valable sur tout
  SQLite 3.x), PostgreSQL conserve sa syntaxe.
- **[`.insert_fordead_alerts()`](https://pobsteta.github.io/nemeton/reference/dot-insert_fordead_alerts.md)**
  (`R/fordead_postprocess.R`) : même ambiguïté d’analyse UPSERT/jointure
  que `.insert_obs_pixel()` —
  `INSERT … SELECT … FROM tmp_fordead_alert_staging ON CONFLICT (…) DO NOTHING`
  échouait sur **toutes** les versions de SQLite. Ajout d’un `WHERE 1=1`
  sur le `SELECT`. C’est le crash qui aurait suivi côté diagnostic
  FORDEAD sur une install SQLite locale.
- **`detect_alerts()`** (`R/alerts.R`) : même classe d’ambiguïté durcie
  par cohérence (`WHERE 1=1`). Note : cette requête reste
  PostgreSQL-only par ailleurs (fenêtres `RANGE BETWEEN INTERVAL`), donc
  l’`ON CONFLICT` n’y était pas encore atteint en pratique sous SQLite.

Tous les correctifs sont des no-op sous PostgreSQL. Les autres
`ON CONFLICT (…) DO NOTHING` du repo (`rag.R`, insert `plot`) utilisent
`VALUES` (pas de `SELECT`) → déjà SQLite-safe, non touchés. Nouveaux
tests de non-régression sur backend SQLite réel
(`test-fordead-alert-insert-sqlite.R`, `helper-sqlite.R` mutualisé) :
insertion FORDEAD, idempotence `DO NOTHING`, et `db_migrate` via
`INSERT OR IGNORE`.

## nemeton 0.55.1 (2026-06-01)

#### Fixed — worker fatal `near "DO": syntax error` sur le backend SQLite local

L’ingestion Sentinel-2 plantait
(`Worker fatal error … near "DO": syntax error`) dès le premier `INSERT`
de pixels sur le backend SQLite local. `.insert_obs_pixel()` charge en
masse via une table de staging avec
`INSERT INTO obs_pixel … SELECT … FROM staging ON CONFLICT (…) DO NOTHING`.
Quand un `INSERT` tire ses lignes d’un `SELECT`, l’analyseur SQLite ne
peut pas distinguer si le `ON` final ouvre la clause UPSERT ou le `ON`
d’une jointure : il interprète mal `ON CONFLICT (…)` et échoue sur `DO`.
Conformément à la documentation SQLite, une clause `WHERE 1=1` sur le
`SELECT` lève l’ambiguïté grammaticale. Correctif sans effet sous
PostgreSQL (no-op). Nouveau test de non-régression sur le backend SQLite
réel (`test-insert-obs-pixel-sqlite.R`). \# nemeton 0.55.0 (2026-05-31)

#### Changed — carte d’alertes FAST : indicateur unique, classes quartiles, énumération cache (spec 017, phase sémantique)

Le **Diagnostic FAST** est la **carte d’alertes raster per-pixel**
([`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)),
pas l’ingestion per-placette. Trois changements de fond (BREAKING
comportement, MINOR en 0.x) :

- **Indicateur unique** (D1) : nouveau paramètre
  `index = c("NDVI", "NBR")` (défaut `NDVI`). La carte est fonction
  d’**un seul** indice au choix ; le « NDVI OU NBR » combiné est
  **supprimé**. Les paramètres `threshold_ndvi` / `threshold_nbr` sont
  remplacés par un unique `threshold` (NULL → 0.40 pour NDVI, 0.30 pour
  NBR). Bonus perf : une seule pile d’indice au lieu de deux.
- **Classes en quartiles** (D2) :
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  discrétise désormais le raster continu en quartiles des **pixels en
  alerte** — classe 0 = pas d’alerte (valeur 0), classes 1-4 = quartiles
  des valeurs strictement positives (`c(0, q25, q50, q75, Inf)`), pour
  **count ET rolling**. Remplace les seuils fixes (`c(0,2,5,10,Inf)` /
  `c(0,0.05,0.10,0.20,Inf)`). `breaks` reste surchargeable ; les
  distributions dégénérées (quantiles égaux, raster tout-à-zéro) sont
  gérées sans erreur.
- **Énumération des scènes depuis le cache COG** (D3) :
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  liste ses scènes directement dans `cache_dir` (répertoires possédant
  les bandes de l’`index`, filtrés par date), **sans passer par
  `obs_pixel`**. Le diagnostic est donc **indépendant des placettes**
  (qui sont construites *après*). `con` / `zone_id` ne servent plus
  qu’au masque UGF (spec 016).

Helpers internes : `.enumerate_cache_scenes()`, `.s2_scene_date()`,
`.fast_alert_quartile_breaks()`. `.compute_alert_count()` /
`.compute_alert_rolling()` réécrits en mono-indice.

**Côté app `nemetonshiny`** (à venir) : exposer un toggle indicateur
NDVI/NBR ; et corriger le désalignement du bouton « Diagnostic FAST »
(il appelle l’ingest per-placette au lieu de
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)).
Plancher `Imports: nemeton (>= 0.55.0)`. Spec 017 (phases perf à suivre
: persistance content-addressed v0.56.0, parallélisation v0.57.0).

## nemeton 0.54.0 (2026-05-31)

#### Changed — isolation de la DB de test (`NEMETON_DB_URL_TEST`)

Garde-fou anti-écrasement de la base de production dans le harnais de
tests. Le helper d’intégration `tests/testthat/helper-monitoring.R`
exécute des `DROP TABLE … CASCADE` sur le schéma monitoring entre chaque
cas ; lancé contre une DB de production il a **détruit deux fois** les
données utilisateur réelles (incidents villards 2026-05-25 et 2026-05-31
: zone, plots, `obs_pixel`, alertes).

- Tout accès DB d’intégration passe désormais par `.guard_test_db()` +
  `.test_db_connect()` (helper de test). Protection en couches :
  1.  `NEMETON_DB_URL_TEST` doit être **défini** (sinon les tests
      d’intégration sont *skipped*, pas *failed*) ;
  2.  il doit **différer** de `NEMETON_DB_URL` (erreur de copier-coller)
      ;
  3.  la base cible ne doit **pas** contenir de tables applicatives
      (`projects`/`users`/`parcels`) — la seule couche qui rattrape le
      cas réel « TEST pointe sur la prod alors que `NEMETON_DB_URL` est
      vide », que la comparaison d’URL ne peut pas détecter. Override
      (CI sur base jetable) :
      `NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE`.
- Nouveau `tests/testthat/test-helper-guards.R` (4 tests offline du
  garde-fou). Nouveau `.Renviron.example`. Section dédiée ajoutée à
  `CLAUDE.md` (setup `nemeton_test`).
- **Breaking côté setup dev** :
  [`devtools::test()`](https://devtools.r-lib.org/reference/test.html)
  exige maintenant un `NEMETON_DB_URL_TEST` dédié pour faire tourner les
  tests d’intégration. Sans lui, ils sont skippés (la suite reste
  verte). Aucun changement d’API publique — rien à faire côté
  `nemetonshiny`.

## nemeton 0.53.0 (2026-05-31)

#### Added — annulation coopérative des workers FAST / FORDEAD

Les workers longs tournent dans un process
[`future::multisession`](https://future.futureverse.org/reference/multisession.html)
séparé et
[`shiny::ExtendedTask`](https://rdrr.io/pkg/shiny/man/ExtendedTask.html)
n’a pas d’API d’annulation : jusqu’ici le bouton « Libérer l’interface »
de `nemetonshiny` ne pouvait que ré-activer l’UI, sans canal pour
arrêter le worker, qui continuait téléchargements + INSERTs pendant
30-60 tuiles. Nouveau mécanisme de cancel coopératif basé sur un
fichier-flag, symétrique sur les deux points d’entrée cœur.

- **`ingest_sentinel2_timeseries(..., cancel_path = NULL)`** : nouveau
  paramètre optionnel. Quand un chemin est fourni, le worker teste
  `file.exists(cancel_path)` **entre chaque tuile** ; si le fichier
  apparaît en cours de run, la boucle sort proprement après la tuile
  courante. Chaque `.insert_obs_pixel()` possédant sa propre
  transaction, les tuiles déjà ingérées restent **commitées** (reprise
  possible). Le résumé retourné porte désormais une colonne `status`
  (`"success"` ou `"cancelled"`) et un événement `s2:cancelled` est émis
  via `progress_callback`.
- **`run_fordead_dieback(..., cancel_path = NULL)`** : idem, mais le
  poll se fait **aux frontières de phase** (après ingest, fit, predict)
  — granularité plus grossière car les phases reticulate ne sont pas
  interruptibles sans SIGINT fragile dans le sous-process Python. Sur
  annulation, la phase courante finit, puis le pipeline retourne
  `status = "cancelled"` + un champ `phase` (phase atteinte) ; un
  événement `fordead:cancelled` est émis. Aucun kill brutal du Python.
- **Garde-fous** : `cancel_path = NULL` → aucun poll, comportement et
  perfs strictement identiques à avant (aucun appel `file.exists`). Un
  flag déjà présent **à l’entrée** est traité comme un résidu d’un run
  précédent et **ignoré** pour tout le run (avec un avertissement) — le
  caller doit supprimer le flag avant chaque `invoke()`. Un chemin
  invalide lit « pas d’annulation », jamais de crash.

Aucune signature publique cassée (`cancel_path` est optionnel). Côté
`nemetonshiny` : câbler `cancel_path` aux `*_task$invoke()`, écrire le
flag dans l’observer du bouton d’annulation, et le supprimer avant
chaque nouveau lancement.

## nemeton 0.52.1 (2026-05-30)

#### Fixed — `build_index_stack()` & FAST alert : couverture des AOI multi-tuiles MGRS

Quand un AOI chevauche deux tuiles MGRS qui se recouvrent (cas
Sentinel-2 nominal en bordure de tuile), les scènes cachées portent des
emprises hétérogènes : la tuile étroite ne couvre que la bande de
recouvrement, la large couvre tout l’AOI.
[`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
réduisait alors la pile à l’**intersection** des emprises
([`terra::intersect`](https://rspatial.github.io/terra/reference/intersect.html) +
[`terra::crop`](https://rspatial.github.io/terra/reference/crop.html)),
si bien que la moitié de l’AOI n’était jamais rendue alors que les
scènes larges existaient dans le cache (carte pixel NDVI/NBR côté
`nemetonshiny`).

- **Union + padding NA** :
  [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  aligne désormais chaque couche sur l’**union** des emprises via
  [`terra::extend()`](https://rspatial.github.io/terra/reference/extend.html)
  (les marges non couvertes deviennent NA — honnête, aucun pixel
  inventé) au lieu de cropper à l’intersection. La pile garde toutes les
  dates et couvre la tuile la plus large. Le
  [`terra::time()`](https://rspatial.github.io/terra/reference/time.html),
  les
  [`names()`](https://rspatial.github.io/terra/reference/names.html),
  l’attribut `index` et le masque de zone aval sont conservés.
- **Garde-fou multi-CRS** : si des couches sont dans des CRS différents
  (AOI rare à cheval sur deux zones UTM), elles sont reprojetées sur la
  grille de la 1re couche **avant** l’union. Cas nominal (même tuile,
  même grille) : pas de resample, seulement du padding. Si les grilles
  ne coïncident pas (dérive origine/résolution au-delà de 1e-6), repli
  sur un
  [`terra::resample()`](https://rspatial.github.io/terra/reference/resample.html)
  vers la couche la plus large — signalé par un
  [`rlang::inform`](https://rlang.r-lib.org/reference/abort.html).
- **FAST alert
  ([`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  /
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md))
  inchangé** : le chemin alertes groupe déjà les scènes par tuile MGRS
  et mosaïque avec `fun = "max"` (spec 013). Ce regroupement reste
  nécessaire pour **ne pas double-compter** la bande de recouvrement S2
  (la même date d’acquisition existe dans les deux tuiles) et pour gérer
  le multi-CRS. Il bénéficie du correctif union+pad au sein de chaque
  tuile (la dérive d’emprise intra-tuile ne rogne plus la couverture).
- **Bruit console** : l’avertissement « Skipped N/total scenes
  (incomplete cache) » de
  [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md),
  émis ~12× par chargement par le réactif Shiny, est rétrogradé en
  `rlang::inform(.frequency = "once")` — une seule ligne par session,
  plus jamais de warning.

## nemeton 0.52.0 (2026-05-29)

#### Added — base de connaissances RAG pour les perspectives IA (E7, spec 009)

Première brique du chantier **E7 — RAG perspectives IA** : la
*machinerie* de récupération augmentée (le corpus lui-même est livré
séparément par la spec fille 009.1). Sept fonctions exportées dans
`R/rag.R` :

- `enable_rag(con)` — migration **opt-in** qui crée `knowledge_document`
  - `knowledge_chunk`. Volontairement **hors de la séquence
    [`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)
    automatique** : la variante PostgreSQL exige l’extension `pgvector`,
    que toutes les bases TimescaleDB n’ont pas forcément activée
    (ADR-012). On active le RAG explicitement quand le serveur est prêt.
    Migrations dans `inst/db/migrations/{pg,sqlite}/rag/0004_rag.sql`.
- `ingest_knowledge_document(con, source, metadata, ...)` — PDF / `.txt`
  / `.md` / texte brut → découpage en chunks (fenêtre glissante par
  tokens estimés) → embeddings → insertion transactionnelle. PDF découpé
  par page (`page_number` conservé). Métadonnées validées
  (titre/langue/type requis), `family_codes` / `profile_codes` pour le
  filtrage thématique.
- `embed_query(text, provider)` — embedding d’une requête. Providers :
  Mistral (défaut, ADR-004 souveraineté FR), OpenAI, Voyage AI
  (écosystème Anthropic) — tous via endpoint compatible OpenAI.
- `retrieve_knowledge(con, query, top_k, family_codes, profile_codes, min_similarity, lang)`
  — KNN cosinus top-k filtré. **Dual-backend** : opérateur `<=>`
  pgvector sur PostgreSQL, cosinus calculé en R sur SQLite (embeddings
  stockés en JSON). Avertit si le corpus mélange plusieurs providers
  d’embeddings.
- [`list_knowledge_documents()`](https://pobsteta.github.io/nemeton/reference/list_knowledge_documents.md),
  [`delete_knowledge_document()`](https://pobsteta.github.io/nemeton/reference/delete_knowledge_document.md)
  (cascade FK vers les chunks),
  [`format_citations()`](https://pobsteta.github.io/nemeton/reference/format_citations.md)
  (bloc Markdown / HTML « Sources documentaires » prêt à concaténer à
  une perspective).

**Écart assumé par rapport à la spec** : la colonne `embedding` est
`vector(3072)` (choix « provider le plus large »), mais pgvector limite
ses index ivfflat/hnsw à **2000 dimensions** — un `vector(3072)` ne peut
donc pas porter d’index ivfflat. La recherche PG se fait en **KNN
exact** (`<=>` sur seq scan), parfaitement adapté à un corpus V1 de
quelques milliers de chunks. Bascule vers `halfvec(3072)` + `hnsw`
prévue quand le corpus grossit (ADR-012).

40 tests dans `test-rag.R` (chunking, cosinus, encodage, validation,
citations + intégration sur SQLite temporaire avec embedder mocké
déterministe). `pdftools` ajouté en Suggests (ingestion PDF offline).

## nemeton 0.51.0 (2026-05-28)

#### Removed — backend monitoring DuckDB (BREAKING)

Le backend monitoring local **DuckDB est retiré**. Il avait été remplacé
par SQLite/WAL en v0.50.0 (DuckDB fichier est mono-process en écriture
exclusif, incompatible avec la coexistence session Shiny + worker
`future` ; SQLite/WAL gère la concurrence multi-process) puis laissé en
mode déprécié. On coupe net : les backends restants sont **PostgreSQL**
(prod) et **SQLite** (local).

- [`db_connect()`](https://pobsteta.github.io/nemeton/reference/db_connect.md)
  / `.detect_driver()` ne reconnaissent plus le scheme `duckdb:///` ni
  les chemins `.duckdb` : une telle URL lève désormais une erreur
  explicite renvoyant vers `sqlite:///`.
- Suppression du driver DuckDB (`.parse_duckdb_url()`, case `duckdb` du
  switch, avertissement de déprécation), des migrations
  `inst/db/migrations/duckdb/`, et de `duckdb` dans les Suggests.
- [`db_disconnect()`](https://pobsteta.github.io/nemeton/reference/db_disconnect.md)
  n’a plus de branche `shutdown = TRUE` spécifique DuckDB ;
  `.default_migrations_dir()` ne mappe plus que `pg/` et `sqlite/`.

**Pas de migration automatique** des données : une base monitoring
DuckDB locale existante n’est pas convertie — pointer l’app sur un
fichier `sqlite:///` et ré-ingérer (les données locales sont
re-générables). Côté `nemetonshiny`, émettre une URL `sqlite:///` (cf.
chantier app dédié).

## nemeton 0.50.1 (2026-05-28)

#### Fixed — warnings RSQLite `result_fetch` à la connexion SQLite

[`db_connect()`](https://pobsteta.github.io/nemeton/reference/db_connect.md)
sur le backend SQLite émettait, à chaque connexion, des avertissements
`dbGetQuery()/dbSendQuery()/dbFetch() should only be used with SELECT queries`.
Cause : `.sqlite_apply_pragmas()` routait *tous* les PRAGMA via
`dbGetQuery()`, or `PRAGMA foreign_keys = ON` et
`PRAGMA synchronous = NORMAL` ne renvoient aucune ligne — RSQLite est
strict sur l’API de résultat. Les PRAGMA sans résultat passent désormais
par `dbExecute()`, ceux qui renvoient une valeur (`busy_timeout`,
`journal_mode`) restent sur `dbGetQuery()`. Purement cosmétique : la
connexion et les migrations fonctionnaient déjà
([`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)
utilise `dbExecute()` pour le DDL) ; seul le log était pollué.
PostgreSQL et DuckDB ne sont pas concernés.

## nemeton 0.50.0 (2026-05-28)

#### Added — backend monitoring local SQLite/WAL (remplace DuckDB), Bug [\#2](https://github.com/pobsteta/nemeton/issues/2) résolu à la racine

Le monitoring local (mode mono-poste, sans PostgreSQL) peut désormais
tourner sur un fichier **SQLite en mode WAL**, qui devient le backend
local **recommandé**. C’est la résolution de fond du Bug
[\#2](https://github.com/pobsteta/nemeton/issues/2) (v0.49.2 ne le
contournait que partiellement) : un fichier DuckDB est mono-process en
écriture *exclusif*, si bien que la session Shiny et le worker
[`future::multisession`](https://future.futureverse.org/reference/multisession.html)
d’ingestion ne peuvent pas l’ouvrir en même temps
(`File is already open in Rscript.exe`). SQLite en WAL autorise **un
writer + plusieurs lecteurs concurrents entre processus** : la session
et le worker coexistent nativement.

- **Nouveau scheme d’URL** `sqlite:///chemin/fichier.sqlite` (ou chemin
  nu finissant en `.sqlite` / `.db`).
  [`db_connect()`](https://pobsteta.github.io/nemeton/reference/db_connect.md)
  ouvre la connexion RSQLite et applique `PRAGMA journal_mode = WAL`,
  `busy_timeout = 10000` (attend au lieu d’échouer sur un verrou
  d’écriture momentané), `foreign_keys = ON` et `synchronous = NORMAL`.
  `read_only = TRUE` ouvre en lecture seule (le fichier doit
  préexister).
- **Migrations SQLite** `inst/db/migrations/sqlite/` (0001/0002/0003),
  schéma identique aux variantes PG/DuckDB en dialecte SQLite
  (`INTEGER PRIMARY KEY AUTOINCREMENT` au lieu de séquences). SQLite
  supportant les index partiels, le 0003 garde la clause
  `WHERE project_uuid IS NOT NULL`.
- **Requêtes portables** : un wrapper interne traduit les placeholders
  `$n` (style PostgreSQL/DuckDB) en `?` pour RSQLite, qui ne les lie pas
  positionnellement depuis une liste non nommée. PostgreSQL et DuckDB
  restent inchangés.
- **Shims backend généralisés** : les branches
  `inherits(con, "duckdb_connection")` (TEMP TABLE sans
  `ON COMMIT DROP`) deviennent `inherits(con, "PqConnection")`
  inversées, si bien que SQLite emprunte le même chemin portable que
  DuckDB.
- **RSQLite** est déjà une dépendance déclarée (Suggests, via l’I/O
  GeoPackage) — aucune nouvelle dépendance.

#### Deprecated — backend monitoring local DuckDB

Le backend DuckDB (`duckdb:///`) reste fonctionnel mais est **déprécié**
au profit de SQLite/WAL : un `cli_warn` one-shot est émis à la
connexion. Les fichiers `.duckdb` existants continuent de fonctionner ;
il n’y a pas de migration automatique des données (les données
monitoring locales sont re-générables par ré-ingestion). DuckDB sera
retiré dans une version ultérieure.

**Côté `nemetonshiny`** : pour bénéficier de WAL, l’app devra émettre
une URL `sqlite:///` au lieu de `duckdb:///` quand `NEMETON_DB_LOCAL`
est actif. Ce changement rend par ailleurs **caduc** le garde-fou «
Option D » (interdire l’ingestion en local) : avec SQLite/WAL la
coexistence session + worker fonctionne.

## nemeton 0.49.2 (2026-05-28)

#### Fixed — monitoring DuckDB local utilisable sous Windows (mono-utilisateur)

Sur une machine sans PostgreSQL accessible (fallback DuckDB local via
`NEMETON_DB_LOCAL`), le monitoring était cassé par deux bugs cœur
distincts. Les deux sont corrigés.

- **Index partiel rejeté par DuckDB.** La migration
  `inst/db/migrations/duckdb/0003_project_uuid.sql` créait un index
  UNIQUE *partiel* (`WHERE project_uuid IS NOT NULL`). DuckDB ne
  supporte pas les index partiels et faisait échouer la migration
  (`Not implemented Error: Creating partial indexes is not supported currently`),
  laissant le schéma monitoring incomplet. La variante DuckDB utilise
  désormais un index UNIQUE *complet* : DuckDB suit le standard SQL
  (NULLs distincts), donc plusieurs zones historiques avec
  `project_uuid` NULL restent tolérées tandis que les valeurs non-NULL
  restent uniques — sémantique identique à l’index partiel PostgreSQL,
  qui reste inchangé.

- **Fichier DuckDB verrouillé entre processus.** Un fichier DuckDB
  n’autorise qu’un seul processus en read-write, mais plusieurs
  connexions read-only simultanées.
  [`db_connect()`](https://pobsteta.github.io/nemeton/reference/db_connect.md)
  gagne un argument `read_only = FALSE` : les lecteurs (session Shiny
  qui ne fait qu’afficher les alertes) peuvent désormais ouvrir en
  `read_only = TRUE` sans entrer en conflit avec un worker `future` qui
  ingère dans un processus séparé. Pour PostgreSQL le flag est sans
  effet (concurrence native). En mode read-only le fichier doit
  préexister (le répertoire parent n’est pas créé).

## nemeton 0.49.1 (2026-05-27)

#### Added — `control_classes` argument on `create_validation_sampling_plan()`

Production diagnostic on villards (after v0.49.0 release) showed that
**0 control plots** were generated for FAST validation. Cause : on
villards with default FAST thresholds (NDVI \< 0.40 / NBR \< 0.30) over
122 dates, **every pixel** has at least one date below threshold →
`count > 0` → no pixel in class 0. The hard-coded `alert_raster == 0`
filter for control plots returned an empty candidate set → typed
`cli_warn("No healthy cell...")` → no control plots.

Fix : `create_validation_sampling_plan(..., control_classes = c(0L))`
gains the new `control_classes` argument. The user can relax to
`c(0L, 1L)` or `c(0L, 1L, 2L)` to allow lightly-alerted pixels as
controls. Useful on disturbed zones or with permissive thresholds.

The `cli_warn` message is enriched : it now reports the **class
distribution** of the alert raster, so the user knows immediately which
class values are present and can pick a relaxed `control_classes`
accordingly. Example output on villards :

    Warning: No cell matching `control_classes` = c(0) found in
    `alert_raster`.
    ℹ Class distribution: 4 = 8471.
    ℹ Try relaxing `control_classes` (e.g. `c(0L, 1L)`) or adjust
      thresholds/window.
    ℹ Skipping control plots (5 requested).

The `alert_class` column of control plots now reflects the **actual cell
value** under each point (was hard-coded to `0L`). With strict
`control_classes = c(0L)`, this is still 0 ; with relaxed values, the
column reports the real class.

4 new tests in `test-validation-sampling.R` covering : - warn fires when
no cell matches `control_classes` - relaxed `control_classes = c(3L)`
allows drawing on a raster with only classes 3, 4 - `alert_class` of
control plots = actual raster value - back-compat : default `c(0L)`
keeps the pre-v0.49.1 behaviour exactly

Suite `test-validation-sampling.R` : 22 PASS (was 18, +4).

## nemeton 0.49.0 (2026-05-27)

#### Changed — Mask UGF par défaut sur le pipeline raster (spec 016)

Tous les readers raster du pipeline FAST/FORDEAD masquent désormais
**par défaut** leurs outputs au polygone des UGFs (le zone_wkt stocké
dans `monitoring_zone`). Les pixels hors UGF deviennent `NA`. Le calcul
des compteurs et l’affichage de la carte gagnent en pertinence (plus de
pollution par les pixels village / route / prairie hors gestion
forestière).

**Mécanique** : le cache COG sur disque reste **un rectangle
pixel-aligné** à la bbox UGF (compatible avec snap-to-grid v0.48.1,
tile-aware v0.48.2, memoization v0.48.3 — aucun changement de contrat
cache). Le mask est appliqué **après** la lecture cache, **avant** le
retour au caller, via le nouveau helper interne
`.apply_zone_mask(raster, zone_polygon)`.

**Fonctions impactées** (6 exports + 1 helper) :

- `read_fast_alert_raster(con, zone_id, ...)` — +2 args
  `apply_zone_mask = TRUE`, `mask_polygon = NULL`.
- `compute_fast_alert_mask(con, zone_id, ...)` — idem ; le TIF persisté
  est désormais masqué (DEFLATE compresse bien les NA, le fichier reste
  compact).
- `read_fast_alert_mask(con, zone_id, ...)` — idem ; back-compat re-mask
  au read pour les TIFs écrits par compute_fast_alert_mask pré-v0.49.0
  (re-mask sur NA = no-op).
- `read_fordead_dieback_mask(con, zone_id, ...)` — idem ; FORDEAD
  produit un raster filtré par BD Forêt v2 (national), v0.49.0 restreint
  en plus aux UGFs spécifiques du projet.
- `build_index_stack(cache_dir, scenes_df, index, mask_polygon = NULL)`
  — pas de `con`/`zone_id` ici (helper bas niveau), le caller passe
  `mask_polygon` explicitement (cf.
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)).
- `extract_pixel_timeseries(..., zone_polygon = NULL, warn_outside_zone = TRUE)`
  — pas de mask raster (c’est une requête à 1 pixel), seulement un warn
  quand le clic est hors UGF.

Pour récupérer le comportement pré-v0.49.0 (rectangle complet), passer
`apply_zone_mask = FALSE`. Pour fournir un polygone custom, passer
`mask_polygon = sf_polygon`.

**`read_obs_pixel()` (SQL, no raster)** : pas de nouveau filtre spatial.
La fonction filtrait déjà par `plot.zone_id = $zone_id`, ce qui **est**
le filtre UGF de facto puisque les plots sont inscrits par
[`register_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/register_monitoring_zone.md)
dans le polygone UGF. Une `@section` roxygen documente cette
équivalence.

Pour villards (AOI 264 ha rectangle, 77 ha UGFs réelles) : **~70 % des
pixels deviennent NA** dans les outputs raster. La compression DEFLATE
absorbe largement ce changement (le TIF persisté de
[`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
est plus petit).

14 nouvelles assertions dans `test-zone-mask.R` : - `.apply_zone_mask`
no-op sur NULL polygon - no-op sur non-SpatRaster - NA sets correctement
hors polygone (fixture 4×4 avec polygone couvrant le quart NW → 4 cells
non-NA, 12 NA) - reprojection automatique de la CRS du polygone à celle
du raster - smoke test villards : `apply_zone_mask = TRUE` produit plus
de NA cells que `apply_zone_mask = FALSE`, même extent

Aucune régression sur les suites voisines (379 PASS au total :
test-zone-mask 14 + fast-alert-raster 20 + fast-alert-mask 18 +
pixel-map 62 + aoi-alignment 15 + monitoring 237 + alert-mask 13).

## nemeton 0.48.3 (2026-05-27)

#### Fixed — Cache S2 : memoization du tile_ext_native par MGRS code

v0.48.2 a fait fonctionner le tile-aware second chance, mais le test
villards (122 scènes) montre que chaque bande T31TFM payait ~10-25 s de
GET range pour relire les headers natifs du COG. Sur 61 scènes T31TFM ×
3 bandes × ~20 s = **~1 h** rien que pour la validation, même quand 100
% des données sont déjà en cache.

Observation clé : **un même code MGRS** (`T31TFM`, `T31TGM`, …) **a
toujours le même extent natif** (100 km × 100 km, coin SW fixé par la
spec MGRS). Aucune raison de relire le header pour chaque date et chaque
bande de la même tuile.

Fix : `.s2_tile_ext_memoize(tile_code, href)` met en cache l’extent
natif par code MGRS dans un environment R session-scoped. Première scène
d’une tuile = 1 GET range (~10-25 s), scènes suivantes = lookup mémo
instantané. Clé extraite via `.s2_mgrs_tile(scene_id)` (le helper livré
en spec 013).

Impact attendu villards : ~1 h → **~50 s** total tile-header cost (25 s
× 2 tuiles uniques).

Helpers ajoutés : - `.s2_tile_ext_cache` (environment session-scoped) -
`.s2_tile_ext_memoize(tile_code, href)` (lookup + populate) -
`.s2_tile_ext_cache_clear()` (test helper, vide le memo)

8 nouvelles assertions dans `test-monitoring.R` : - premier appel
fetche, deuxième même tuile mémo-hit (call_count unchanged) - tuile
différente déclenche un fetch neuf - clear() vide le memo - tile_code “”
ou NA → NULL (no-op)

Suite test-monitoring.R : 237 ✔ (était 229, +8).

## nemeton 0.48.2 (2026-05-27)

#### Fixed — Cache S2 : tile-aware second chance pour les AOIs multi-tuile MGRS

v0.48.1 a installé le snap-to-grid mais le diagnostic enrichi a révélé
que sur villards, le predicate flaggait encore STALE non pas à cause de
jitter sub-pixel mais à cause d’un **vrai débord géographique** :

    CACHE-STALE … : cached_snap=(709360,709800,5143470,5145480)
                    needed_snap=(709360,710700,5143470,5145480)
                    delta_m=(10,-890,10,10)

890 m de débord sur xmax = 89 pixels. L’AOI villards (~1340 m × 2010 m)
chevauche les tuiles MGRS T31TFM et T31TGM. Le cache T31TFM B04 a été
écrit par un run précédent avec un crop **naturellement clippé** à la
frontière FM/GM (xmax = 709800). Aujourd’hui le code demande l’AOI
complète (xmax = 710700), qui déborde de 890 m sur l’EST — mais cette
portion **n’existe pas dans T31TFM**, elle est sur T31TGM.

Le refetch « pour rien » récupère exactement les mêmes pixels que le
cache déjà sur disque. C’est la cause majeure du CACHE-STALE storm sur
les AOIs multi-tuile.

**Fix** : quand le predicate snap-to-grid dit STALE, une *deuxième
chance tile-aware* lit les headers natifs du COG via `terra::rast(href)`
(lazy, GET range seulement, pas de pixel decode, ~1 s), clippe
`needed_ext` à l’extent natif de la tuile, et re-teste la containment.
Si OK, CACHE-HIT.

Coût : ~1 s de header GET par cas ambigu. N’est invoqué QUE quand le
predicate simple a échoué, donc à coût quasi-nul pour les cache-hit
nets.

Log dédié quand cette branche réussit :

    CACHE-HIT served from disk (needed clipped to tile native extent)

Tests : aucune nouvelle assertion (le predicate snap-to-grid v0.48.1
reste le path principal, la branche tile-aware n’est testable qu’avec un
COG distant donc skip in-CI). Suite test-monitoring.R inchangée : 229 ✓.

**Impact attendu villards** : sur les ~50 % de scènes T31TFM
multi-tuile, le second-chance va matcher → ~30 s d’ingest warm au lieu
des ~3 h résiduels après v0.48.1.

## nemeton 0.48.1 (2026-05-27)

#### Fixed — Cache S2 validation : snap-to-grid kills the per-ingest re-fetch storm

Production report on villards (122 scenes, 2026-05-27 17:18 → 17:36) :
every cached band was systematically declared CACHE-STALE despite
v0.47.4’s 40 m tolerance, triggering re-fetches that produced files
**±12 bytes** different from disk (GeoTIFF header noise, identical pixel
payload). Projected ingest time ~6 h instead of ~30 s for a warm cache.

Root cause : the v0.47.4 `.ext_contains(outer, inner, tolerance = 40)`
predicate compared **raw float extents** with an absolute 40 m slack.
Cached and needed extents could differ by less than 40 m yet still fail
because the sub-pixel jitter introduced by
`sf::st_transform(zone_polygon, raster_crs)` shifted both bounds in the
same direction (e.g. needed.xmax = cached.xmax + 0.7 m AND needed.xmin =
cached.xmin + 0.7 m → asymmetric overshoot that the 40 m tolerance
technically covers but the predicate flagged anyway due to a sign error
in some edge cases).

Fix : new pixel-grid-aware containment predicate
`.ext_contains_at_grid(cached, needed, res, tol_pixels = 1L)`. Both
extents are snapped to the COG’s own pixel grid (multiples of `res`
metres) via `.snap_ext_to_grid()` before the comparison. Two extents
that reference the **same pixel cell** are snapped to **identical**
numeric values, so jitter ≤ 1 pixel never produces STALE. The 1-pixel
tolerance further absorbs the half-cell rounding that `snap = "out"` and
`terra::ext(terra::vect(...))` may introduce on top of the snap.

New ENV bypass `NEMETON_S2_CACHE_SKIP_VALIDATION` (`"TRUE"` / `"1"`) —
set it to trust every cached file blindly. Escape hatch for when a
known-good cache hits the predicate edge cases.

New diagnostic on STALE : the log now shows the snapped cached / needed
extents AND the signed per-side margin in metres, so the user can see
exactly which boundary is failing and by how many pixels :

    CACHE-STALE extent does not cover AOI (snap-grid res=10m tol=1px) :
     cached_snap=(709360,709800,5143470,5145480)
     needed_snap=(709360,709800,5143470,5145480)
     delta_m=(10,10,10,10), refetching

Negative `delta_m` = inner overshoots outer on that side.

Tests : 13 new assertions in `test-monitoring.R` covering
`.snap_ext_to_grid()` (10 m and 20 m grids), identical extents,
sub-pixel jitter absorption, 2-pixel overshoot rejection, and the ENV
bypass.

Expected impact on villards : warm cache ingest from ~6 h to ~30 s.

**Note** : the older `.ext_contains(outer, inner, tolerance = ...)`
helper is preserved (other callers like the FORDEAD validity check use
it). Only the S2 cache lookup is upgraded.

## nemeton 0.48.0 (2026-05-26)

#### Added — `lasR` fallback : dériver MNT/MNH depuis les `.laz` quand IGN refuse les dalles dérivées

Quand les téléchargements IGN LiDAR HD MNH / MNT échouent (production
dérivée non encore publiée, 404 sur les dalles dérivées alors que les
nuages COPC sont disponibles, blocage réseau), `nemeton` se rabattait
sur “CHM non trouvé — stratification sans hauteur” même si les
`.copc.laz` correspondants traînaient dans
`<project>/cache/layers/lidar_nuage/`. La nouvelle fonction exportée
\[[`compute_dtm_chm_from_laz()`](https://pobsteta.github.io/nemeton/reference/compute_dtm_chm_from_laz.md)\]
dérive en local le DTM et le CHM via un pipeline `lasR` minimal
(`reader_las()` → `triangulate(filter = keep_class(2L))` →
`rasterize(res, tri, ofile = dtm.tif)` → `transform_with(tri)` →
`rasterize(res, "max", ofile = chm.tif)`), écrit dans
`cache/layers/lidar_mnt/dtm.tif` et `cache/layers/lidar_mnh/chm.tif` —
chemins exactement compatibles avec le moteur de découverte existant.

Intégration :
\[[`resolve_project_dem()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)\]
et
\[[`resolve_project_chm()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)\]
gagnent un paramètre `try_compute_from_laz = TRUE` (défaut) qui
déclenche le fallback de façon **opportuniste** quand aucun raster
pré-calculé n’est trouvé mais que des `.laz` existent. `lasR` absent ≠
erreur : le fallback est skippé silencieusement, l’appelant récupère un
`NULL` comme aujourd’hui. Opt-out d’un seul flag pour ceux qui veulent
garder la sémantique stricte.

Ajout d’un helper de diagnostic
\[[`probe_ign_lidar_tile()`](https://pobsteta.github.io/nemeton/reference/probe_ign_lidar_tile.md)\]
(et son batch
\[[`probe_ign_lidar_tiles()`](https://pobsteta.github.io/nemeton/reference/probe_ign_lidar_tiles.md)\])
pour classer les échecs de téléchargement IGN par catégorie (`not_found`
= production retardée côté IGN, `forbidden` = auth/quota, `timeout` =
surcharge serveur, `dns` / `connection` = réseau client). Utilisable
depuis `nemetonshiny` pour expliquer à l’utilisateur pourquoi un
download a échoué plutôt que d’afficher un simple `failed`.

`lasR (>= 0.10.0)` ajouté en `Suggests`. Installation hors CRAN :
`install.packages("lasR", repos = "https://r-lidar.r-universe.dev")`.

Tests : `tests/testthat/test-lidar_processing.R` couvre la validation
d’arguments, l’absence silencieuse de `lasR`, l’opt-out, et la
classification offline du diagnostic.

## nemeton 0.47.5 (2026-05-26)

#### Fixed — `build_index_stack()` aligns per-scene layers (spec 010 + 013)

`build_index_stack(cache_dir, scenes_df, index)` (spec 010 v0.22.0) read
each scene’s cached COG via
[`read_s2_band_raster()`](https://pobsteta.github.io/nemeton/reference/read_s2_band_raster.md)
and then called `terra::rast(layers)`. When cached files for the same
band had been written by **separate app sessions** (cross zone
re-registration, separate AOI snapping), the per-scene extents diverged
by sub-pixel to multi-pixel amounts and the stack call failed with:

    build_index_stack failed: [rast] extents do not match

Reproduced in production on villards (2026-05-26 ~01:14 UTC) right after
the 118/118 FAST ingestion finished, when the app’s *Carte FAST* (pixel
map) and *Alertes FAST* (raster d’alerte via
[`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md))
tried to stack the freshly-cached scenes.

Fix :
[`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
now computes the **intersection of all per-scene extents** and crops
every layer to that common extent before calling
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html).
Slightly less spatial coverage (the common ground), but a coherent stack
that all downstream consumers can build on. Falls back to `NULL` with a
`cli_warn` when the intersection is empty (no common ground at all).

2 new tests in `test-pixel-map.R` cover the alignment of layers shifted
by 30 m (3 px) and the no-overlap edge case. Total suite remains green.

Impact on the app : *Carte FAST*, *Alertes FAST* and the validation-
sampling FAST path stop erroring out on a mixed-vintage cache.

## nemeton 0.47.4 (2026-05-25)

#### Fixed — bump cache tolerance from 1 to 4 pixels

v0.47.3 set the cache-hit tolerance to `1 * max(terra::res(r_cached))`
(10 m for B04/B08, 20 m for B12). Production retry on villards showed
that cache files written by *previous app sessions* (before today’s zone
re-registration after the DB wipe) can differ by more than 1 pixel from
today’s AOI — `sf::st_union(parcels)` is not byte-stable across runs,
and the zone polygon was effectively re-generated. The 1-pixel tolerance
therefore continued to declare CACHE-STALE on ~half the scenes.

Bumped to `4 * max(terra::res(r_cached))` = 40 m for B04/B08, 80 m for
B12. Generous for realistic zone drift, still negligible relative to a 2
km AOI. Post-crop NA at AOI edges (\< 4 px wide) is silently handled by
[`exactextractr::exact_extract`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html)
(weight 0 contribution).

No new test (the existing `.ext_contains tolerance ...` suite covers the
parametrised behaviour). No API change.

## nemeton 0.47.3 (2026-05-25)

#### Fixed — `.ext_contains()` 1-pixel tolerance kills the CACHE-STALE storm

The Sentinel-2 cache (`.get_s2_band_raster()`) declared CACHE-STALE
**every time** the cached extent missed the AOI by a sub-pixel amount —
typically a 5-10 m float-point drift introduced by
`sf::st_transform(buf, raster_crs)` + `terra::crop(snap = "out")`
between two runs against the **same** zone. Result on villards
(2026-05-25): a re-ingest projected to **~4 h** to refetch 118 scenes
whose cached `B04.tif` was ~20 KB and whose refetched `B04.tif` was ~20
KB (differing by \< 50 bytes).

Fix : `.ext_contains(outer, inner, tolerance = 0)` gains a `tolerance`
argument. The cache-hit call site in `.get_s2_band_raster()` now passes
`tolerance = max(terra::res(r_cached))` — exactly one pixel of the
cached raster (10 m for B04/B08, 20 m for B12). Any other caller keeps
the strict pre-v0.47.3 semantics via the default `tolerance = 0`.

When tolerance lets a CACHE-STALE through, the subsequent
`terra::crop(r_cached, needed_ext, snap = "out")` returns a raster that
may be missing edge pixels of the AOI. In practice these are at the AOI
envelope and don’t fall on
[`exactextractr::exact_extract`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html)
buffer footprints (the per-plot 15 m buffers are well inside the AOI).
`exact_extract` itself silently handles missing cells (weight 0
contribution).

Verbose log message updated:
`CACHE-STALE extent does not cover AOI (tol=10m), refetching` — makes
the tolerance value visible when stale fires anyway.

8 new test assertions in `test-monitoring.R`
(`.ext_contains tolerance ...`). Suite : `test-monitoring.R` 216 ✓ (was
208, +8). No production regression on other monitoring tests.

Expected impact on the villards run currently in flight: ~4 h projection
drops to ~10-30 min (most CACHE-STALE become CACHE-HIT since the cached
file’s extent IS off by ≤ 1 pixel from the new AOI).

## nemeton 0.47.2 (2026-05-25)

#### Fixed — `with_clean_db()` guard-rail against wiping production data

Adds a hard safety check in the integration-test helper. Each
integration test using `with_clean_db()` calls a `reset_schema()` that
`DROP`s the entire monitoring schema (`alert`, `obs_pixel`, `plot`,
`monitoring_zone`, `schema_migration`) at start and end of the test, so
the test is idempotent. The catch: when `NEMETON_DB_URL_TEST` is unset
(or equal to `NEMETON_DB_URL`), every integration test wipes the user’s
production data.

This actually happened on 2026-05-25 while running the cœur integration
tests against the user’s local DB. The villards zone (id=1, 155 plots),
17 050 `obs_pixel` rows and ~24 FORDEAD alerts were lost. The user
re-registered the zone via the app (spec 011 hook took care of the
binding automatically).

Guard now refuses to run when either:

- `NEMETON_DB_URL_TEST` is not set and the helper would fall back to
  `NEMETON_DB_URL`, or
- `NEMETON_DB_URL_TEST` equals `NEMETON_DB_URL`.

It calls
[`testthat::skip()`](https://testthat.r-lib.org/reference/skip.html)
with an actionable message instead. Override : set
`NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE`. Intended for CI on an
empty test DB where the wipe is harmless.

No production code change. Adds 23 lines to
`tests/testthat/helper-monitoring.R`. All FAST / FORDEAD integration
tests gracefully skip when the guard fires.

## nemeton 0.47.1 (2026-05-25)

#### Fixed — test-suite stabilisation (chip 2-3)

Closes the « ~9 échecs préexistants » documented in v0.43.2. Two cœur
fixes + one test fix; no behaviour change for end users.

- **`R/fordead_python.R`** —
  [`.fordead_is_installed()`](https://pobsteta.github.io/nemeton/reference/dot-fordead_is_installed.md)
  and
  [`.ensure_fordead_python()`](https://pobsteta.github.io/nemeton/reference/dot-ensure_fordead_python.md)
  swap
  [`cli::cli_alert_warning()`](https://cli.r-lib.org/reference/cli_alert.html)
  /
  [`cli::cli_alert_info()`](https://cli.r-lib.org/reference/cli_alert.html)
  for
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html) /
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html).
  The `_alert_*` family only prints styled text to the console; the
  `_warn` / `_inform` family additionally raises a proper R `warning` /
  `message` condition that `expect_warning()` / `expect_message()` can
  catch in tests (and that downstream callers can capture with
  `withCallingHandlers` if needed). User-facing output is identical.
- **`tests/testthat/test-fordead-python.R`** — the « reticulate missing
  » test captured a stable reference to
  [`base::requireNamespace`](https://rdrr.io/r/base/ns-load.html)
  **before** calling `local_mocked_bindings(.package = "base")` so the
  else-branch of the mock doesn’t recurse into itself
  ([`base::requireNamespace`](https://rdrr.io/r/base/ns-load.html)
  inside the mock body resolves to the mock, not the original, in recent
  testthat).

Suite `test-fordead-python.R` : 57 ✓ / 0 FAIL (was 3 fails). Suite
`test-fordead-stac.R` was already 100 % green from a prior chip. No
regression on the FORDEAD-adjacent suites (`test-fordead-pipeline.R` 69,
`test-fordead-postprocess.R` 56, `test-fordead-outputs.R` 41,
`test-fordead-pixel-series.R` 31, `test-fordead-validity-zones.R` 10 =
207 ✓).

## nemeton 0.47.0 (2026-05-25)

#### Added — Validation sampling plan (spec 014, phase A)

Three new exported functions that let the app generate a **validation
sampling plan** concentrated on the dieback foci detected by FORDEAD or
FAST — solving the gap where the systemic GRTS sample misses an alert
when no plot happens to sit on a detected spot.

- **`fordead_alert_mask(alert_raster, classes = c(3L, 4L), buffer_m = 0)`**
  — Pure raster utility. Takes a categorical 0-4 SpatRaster (FORDEAD
  `dieback_mask` or FAST mask, see below), keeps the cells in `classes`
  with their value (so the output doubles as a *priority raster*), NA
  elsewhere. Optional metric dilation around alert cells (buffer cells
  get `min(classes)`).

- **`compute_fast_alert_mask(con, zone_id, ..., cache_dir, mask_cache_dir, breaks = NULL)`**
  — Discretises the continuous output of \[read_fast_alert_raster()\]
  (v0.46.0) to the **0-4 categorical scale aligned with FORDEAD’s
  `dieback_mask`**, and persists it under
  `<mask_cache_dir>/zone_<id>/fast_alert_<ts>.tif` (GeoTIFF DEFLATE
  INT1U). Defaults for `breaks`: `c(0, 2, 5, 10, Inf)` in `"count"`
  mode, `c(0, 0.05, 0.10, 0.20, Inf)` in `"rolling"` mode.

- **`read_fast_alert_mask(con, zone_id, run_id = NULL, cache_dir)`** —
  Strict mirror of \[read_fordead_dieback_mask()\]. Reads back the
  persisted 0-4 mask, returns `NULL` when no file matches.

- **`create_validation_sampling_plan(zone, alert_raster, n_validation, n_control, classes, buffer_m, source, seed)`**
  — The single user-facing entry point. Returns an `sf` POINT object in
  EPSG:2154 combining:

  - **Validation plots** drawn from the alert cells via
    **unequal-probability GRTS** (`spsurvey::grts(caty_var, caty_n)`): a
    cell of class 4 has a higher inclusion probability than class 3
    (allocation by largest-remainder rounding).
  - **Control plots** drawn equiprobably from the healthy zone (class
    0).
  - `visit_order` column from a TSP tour over the union.

  Raises a typed error `nemeton_empty_alert_mask` when no alert cell
  matches `classes`, so the app can show « zone saine, rien à valider »
  cleanly instead of crashing.

The FAST and FORDEAD masks consume the same downstream pipeline
(\[fordead_alert_mask()\] → \[create_validation_sampling_plan()\]) by
construction: the 0-4 scale is the contract.

Naming: kept \[read_fast_alert_raster()\] (v0.46.0) as the live
continuous compute for UI exploration ; new \[read_fast_alert_mask()\]
parallels \[read_fordead_dieback_mask()\] for the persisted categorical
mask. No breaking change.

49 new tests in `test-alert-mask.R` (13), `test-fast-alert-mask.R` (18),
`test-validation-sampling.R` (18) — input validation, raster arithmetic
on synthetic stacks, end-to-end round-trip on the real villards DB.

Spec : `specs/014-validation-sampling/` (mirrors the design in
`nemetonshiny/design/validation-sampling.md` and
`nemeton-phase-a-brief.md`).

## nemeton 0.46.0 (2026-05-24)

#### Added — `read_fast_alert_raster()` pixel-level FAST alerts (spec 013)

New exported function that produces a single-band SpatRaster (EPSG:2154)
of FAST alerts at native Sentinel-2 pixel resolution, built from the
on-disk COG cache populated by \[ingest_sentinel2_timeseries()\]. Two
semantics in parallel via the `mode` argument:

- **`mode = "count"`** — per-pixel integer count of dates within
  `[date_from, date_to]` where `NDVI < threshold_ndvi` **or**
  `NBR < threshold_nbr`. Output layer name `alert_count`.
- **`mode = "rolling"`** — continuous deficit magnitude on the trailing
  `window_days`. Returns `max(deficit_ndvi, deficit_nbr)` where
  `deficit_x = max(0, threshold_x - mean_x_over_window)`. Output 0 =
  pixel not in alert, \> 0 = magnitude of the alert. Layer name
  `alert_deficit`.

Multi-tile AOIs are handled transparently: scenes are grouped by their
MGRS tile (5th `_`-field of the scene id), one raster is computed per
tile in its native CRS (typically EPSG:32631), each is projected to
EPSG:2154, and the per-tile rasters are mosaicked with `fun = "max"`.
Tested end-to-end on villards (zone 1, 155 plots, 55 dates spanning
T31TFM + T31TGM).

This replaces the per-plot semantics of \[list_fast_alerts_for_zone()\]
with a pixel-level raster suitable for the app’s *Alertes FAST* tab (à
la `addRasterImage` + classified legend), and unblocks the
validation-sampling design (`priority_raster` argument of the future
GRTS-weighted sampler).

- New `R/fast_alert_raster.R` (function + internal helpers
  `.compute_alert_count()`, `.compute_alert_rolling()`,
  `.s2_mgrs_tile()`).
- 20 new tests in `test-fast-alert-raster.R`: input validation,
  synthetic stack assertions for both modes, NULL on empty window,
  end-to-end smoke against the real villards DB.
- Spec : `specs/013-fast-alert-raster/spec.md`.

## nemeton 0.45.0 (2026-05-23)

#### Changed — FAST and FORDEAD share the same AOI (spec 012)

Both pipelines now resolve their Sentinel-2 AOI through the registered
`monitoring_zone.zone_wkt` (the UGF envelope set by
\[register_monitoring_zone()\]), instead of computing a per-plot bbox on
the fly. The on-disk COG cache (`<cache_dir>/<scene_id>/<band>.tif`)
therefore lives at the same extent for both pipelines, so a FORDEAD
ingest pre-warms the FAST cache and vice versa. Spec 012, motivated by
hours-long FAST re-fetches observed on villards.

- [`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md)
  moved from `R/fordead_pipeline.R` to a neutral `R/zone_aoi.R` so both
  pipelines share a single resolver.
- [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  (FAST entry point) and
  [`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)
  (the ingest FORDEAD calls in phase 0) now read `zone_wkt` and pass it
  as the crop geometry to `.get_s2_band_raster()`. The STAC search bbox
  is computed from the zone AOI (re-projected to WGS84) too.
- `.extract_scene_obs()` gains an optional `crop_aoi` argument; the
  per-plot buffer `buf` is still used downstream for
  [`exactextractr::exact_extract()`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html)
  (per-plot mean).
- `.get_s2_band_raster()`’s `buf_plots` argument keeps its name to
  preserve mock compatibility, but semantically now accepts any sf whose
  bbox defines the crop (a polygon AOI or the legacy buffer).
- **Fallback** — when `monitoring_zone.zone_wkt` is empty or unreadable
  (e.g. zone created by a script that bypassed
  [`register_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/register_monitoring_zone.md)),
  both pipelines warn explicitly and fall back to the v0.44.x behaviour
  (per-plot bbox). Re-register the zone via
  \[register_monitoring_zone()\] to unlock the shared cache.
- 6 new tests in `test-aoi-alignment.R` (15 assertions): `.get_zone_aoi`
  shape, bbox passed to STAC matches zone (FAST + FORDEAD-ingest),
  fallback warn path. Existing tests in `test-sentinel2-cache.R` updated
  to mock
  [`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md)
  alongside `.fetch_plots_sf()`.

**Operational note** — caches populated by v0.44.x or earlier hold crops
at the per-plot bbox and will trigger one wave of CACHE-STALE re-fetches
the first time spec 012 runs against them. This is expected and
ponctuel; optional cleanup is
`unlink( "<project>/cache/layers/sentinel2", recursive = TRUE)`.

## nemeton 0.44.0 (2026-05-23)

#### Added — `project_uuid` binding for `monitoring_zone` (spec 011)

Stable link between a `nemetonshiny` project and the monitoring zone it
registered. Lets the app re-hydrate `monitoring_zone_id` from the core
DB when a project is reloaded but its `metadata.json` does not carry the
id — fixes the user-visible bug where opening a recent project
(“villards”, etc.) leaves the *Suivi sanitaire* dropdown empty even
though the zone exists in DB.

- **Migration `0003_project_uuid`** (PG + DuckDB) — adds
  `monitoring_zone.project_uuid TEXT` plus a partial UNIQUE index on
  non-NULL values. Idempotent. Zones registered before this migration
  keep working (NULL allowed; no `name` fallback in the lookup).
- **`register_monitoring_zone(..., project_uuid = NULL)`** — new
  optional argument. When non-NULL, persisted on the zone row. Strictly
  backwards-compatible: existing callers that don’t pass it take the
  same code path as before.
- **`find_zone_by_project(con, project_uuid)`** — new exported function.
  Returns the zone id bound to a project UUID, or `integer(0)` if no
  zone matches. Does **not** fall back to a `name`-based lookup
  (deliberate — `name` matching was brittle and is now considered
  legacy).
- 9 new tests in `test-project-zone-binding.R` covering input validation
  (offline), migration shape, round-trip, missing match, UNIQUE
  rejection of duplicate `project_uuid`, and preservation of multiple
  NULL legacy rows.

Spec 011 §3 is fully delivered core-side. App-side wiring (`mod_home`
post-load hook + `register_project_as_zone` passing `project_uuid`) is a
`nemetonshiny` chantier.

## nemeton 0.43.2 (2026-05-23)

#### Fixed — test-suite stabilisation (chip 1)

First slice of the « ~13 échecs préexistants » documented in v0.43.1. No
production behaviour change; all fixes are defensive against R runtime
drift and a latent [`unlink()`](https://rdrr.io/r/base/unlink.html) bug.

- **`R/fordead_python.R`** —
  [`.same_path()`](https://pobsteta.github.io/nemeton/reference/dot-same_path.md)
  now collapses `/./`, duplicate slashes and a trailing slash by hand
  before comparing, because `normalizePath(mustWork = FALSE)` leaves
  *non-existent* paths untouched (so the previous identity test produced
  false negatives whenever one input had a redundant `/.` segment).
- **`R/fordead_stac.R`** — `.validate_date_range()` wraps
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html) in a `tryCatch`:
  recent R *errors* on an unparseable string where older R returned `NA`
  with a warning, which used to swallow the actionable “must parse as a
  date (ISO yyyy-mm-dd)” message.
- **`R/monitoring.R`** —
  [`diagnose_s2_cache()`](https://pobsteta.github.io/nemeton/reference/diagnose_s2_cache.md)
  orphan cleanup uses `unlink(scene_dir, recursive = TRUE)`. With
  `recursive = FALSE`, [`unlink()`](https://rdrr.io/r/base/unlink.html)
  never removes a directory — not even an empty one — so the cleanup
  branch was a silent no-op. The emptiness guard immediately above keeps
  the call safe.
- **`tests/testthat/test-monitoring.R`** — progress-callback assertion
  expects the `s2:cache_lookup` event introduced earlier and looks up
  events by `current` key rather than by position, so future phase
  insertions don’t shift indices.

## nemeton 0.43.1 (2026-05-22)

#### Fixed — `R CMD check` debt cleanup

Maintenance release that clears the accumulated
[`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
warnings and notes (no functional change):

- **Corrupt Rd files** — `man/ingest_s2_raw_bands_to_cache.Rd` and
  `man/ingest_sentinel2_timeseries.Rd` were stale, hand-edited artefacts
  (unbalanced braces from an unescaped `%`, unknown `\item` macros).
  Regenerated cleanly from roxygen; the `@param max_cloud` text now says
  “percent” instead of “(%)”.
- **Non-ASCII in code** — replaced non-ASCII characters in string
  literals of `fordead_outputs.R`, `fordead_validity.R`,
  `health_validation.R`, `qgis_export.R` and `sampling_plan.R` with
  `\uxxxx` escapes (or ASCII), keeping runtime behaviour identical.
- **Undocumented arguments** — added the missing `@param` tags for
  [`indicateur_e1_bois_energie()`](https://pobsteta.github.io/nemeton/reference/indicateur_e1_bois_energie.md),
  [`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md),
  [`indicateur_p3_qualite_bois()`](https://pobsteta.github.io/nemeton/reference/indicateur_p3_qualite_bois.md)
  and the `stac_search_s2_*()` family.
- **Misc Rd** — fixed `charru_bai_drift`’s empty `\details` section and
  `diagnose_s2_cache`’s lost braces.
- **`setNames`** — qualified as
  [`stats::setNames()`](https://rdrr.io/r/stats/setNames.html) in
  `health_validation.R` and `pixel-map.R`.
- **`.Rbuildignore`** — excluded non-standard top-level / hidden files
  (`.env`, `CHANGELOG.md`, `CITATION.cff`, `docker-compose.yml`,
  `PLAN.md`) from the build.
- **`xml2`** — declared in `Suggests` (used by `test-qgis-export.R`).
- **Test fix** — `test-sentinel2.R` “All STAC backends failed” rewritten
  for testthat edition 3 (the nested `expect_warning()` idiom no longer
  works).

## nemeton 0.43.0 (2026-05-21)

#### Added — `read_fordead_pixel_series()`: CRSWIR pixel diagnostic (spec 008 §14, L2)

Reader side of the FORDEAD diagnostic bundle (L1, v0.42.0). The new
exported
`read_fordead_pixel_series(con, zone_id, xy, crs, run_id, cache_dir)`
returns, for a clicked pixel, the time series behind a FORDEAD detection
— the data the upcoming click-to-diagnose plot of the FORDEAD map needs:

- `crswir_obs` — the observed (cloud / shadow / soil masked) CRSWIR;
- `crswir_pred` — the harmonic-model prediction;
- `seuil_haut` — the anomaly threshold band (`pred + threshold`);
- `anomalie` — the per-date anomaly flag.

The data frame also carries `threshold_anomaly`, `premiere_detection`,
`dans_zone_validite` (guard-rail G3) and `vegetation_index` as
attributes.

Per ADR-013 amendment A3 (decision D3), the harmonic basis is **not**
re-implemented in R: `crswir_pred` is rebuilt from
`fordead.modeling.compute_HarmonicTerms` via , which guarantees
bit-level parity with the run that produced the bundle. A parity test
(AC.14.2) checks this against `fordead.modeling` within `1e-6`. The
function returns `NULL` cleanly — no error — when no bundle is found,
the pixel is outside the modelled extent, or the FORDEAD Python
environment is unavailable.

New file `R/fordead_pixel_series.R`; ≥ 13 offline tests in
`test-fordead-pixel-series.R` with a synthetic bundle fixture.

## nemeton 0.42.0 (2026-05-21)

#### Added — FORDEAD diagnostic bundle persisted for pixel diagnostics (spec 008 §14, L1)

Groundwork for the upcoming click-to-diagnose interaction on the FORDEAD
map (amendment A3 / spec 008 §14). The `persist` phase of
[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
now writes, alongside the 0-4 dieback mask, a curated *diagnostic
bundle* under `<mask_cache_dir>/zone_<id>/model_<run_id>/`:

- `coeff_model.tif` — the 5-band harmonic coefficient raster
  (`fit/model.tif`), the model FORDEAD actually fitted.
- `crswir_stack.tif` — the observed CRSWIR series, one band per date
  with
  [`terra::time()`](https://rspatial.github.io/terra/reference/time.html)
  set, masked by `INVALID_PIXEL_MASK` (cloud / shadow / soil) exactly as
  FORDEAD modelled it.
- `first_anomaly.tif` — first confirmed-anomaly date per pixel.
- `run_meta.json` — calibration and provenance of the run
  (`vegetation_index`, `threshold_anomaly`, training / monitoring
  windows, fordead version, CRS).

The result of
[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
gains `rasters$model_dir`. As with the dieback-mask persist hook
(v0.41.0), the write is best-effort: a failure emits a `cli` warning but
never aborts the run. No new pipeline phase, no signature change.

Two internal helpers back this:
[`.build_crswir_masked_stack()`](https://pobsteta.github.io/nemeton/reference/dot-build_crswir_masked_stack.md)
and
[`.write_fordead_model_bundle()`](https://pobsteta.github.io/nemeton/reference/dot-write_fordead_model_bundle.md)
(`R/fordead_outputs.R`).

## nemeton 0.41.3 (2026-05-21)

#### Fixed — FORDEAD reported “0 alerts” while detecting 32 ha of dieback

A FORDEAD diagnostic run on a real monitoring zone confirmed dieback on
3 228 pixels (~32 ha, class `4-sol-nu`) yet inserted **0 alerts**, with
no warning. Three independent defects combined to swallow the result:

- [`.compute_first_dieback_date()`](https://pobsteta.github.io/nemeton/reference/dot-compute_first_dieback_date.md)
  reshaped the `ANOMALY_CONFIRMED` layer stack with
  `array(values, dim = c(n_rows, n_cols, ...))`.
  [`terra::values()`](https://rspatial.github.io/terra/reference/values.html)
  is row-major while [`array()`](https://rdrr.io/r/base/array.html)
  fills column-major, so the `(time, y, x)` cube fed to
  `fordead.utils.backward_start()` was spatially transposed whenever
  `n_rows != n_cols` — first-dieback dates landed on the wrong pixels.
  Each layer is now reshaped with `byrow = TRUE`.
- [`.compute_first_dieback_date()`](https://pobsteta.github.io/nemeton/reference/dot-compute_first_dieback_date.md)
  also assumed `backward_start()` returned a numeric “days since epoch”
  array. It actually returns an object-dtype array (ISO date strings on
  confirmed pixels, `NaN` elsewhere), which
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
  cannot ingest — the step crashed and was caught as a benign
  best-effort failure. The output is now coerced explicitly to a numeric
  day-since-1970 matrix.
- With `first_dieback_date` thus lost, every alert centroid carried
  `trigger_date = NA`, and
  [`.insert_fordead_alerts()`](https://pobsteta.github.io/nemeton/reference/dot-insert_fordead_alerts.md)
  silently dropped every such row (the column is part of the UNIQUE
  key). It now emits a `cli_warn` reporting how many alerts were
  discarded.
- [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  treated a failed `fordead.utils` import as silent best-effort. It now
  warns loudly that `trigger_date` cannot be derived and that every
  detected cluster will be dropped at insertion, pointing at the missing
  Python dependency.

## nemeton 0.41.2 (2026-05-20)

#### Fixed — Sentinel-2 reprocessing duplicates inflated the cache and FORDEAD

ESA periodically reprocesses the Sentinel-2 archive: an acquisition is
republished under a new product id whose only change is the trailing
processing-baseline timestamp. A STAC search returned **both** the
original and the reprocessed product as distinct scenes.

On the user’s monitoring zone this meant 47 of 342 acquisitions (~14 %)
were cached twice — doubling the band downloads and disk footprint — and
FORDEAD received two STAC items with an identical `datetime` (“Duplicas
times found”), merging them in an undefined order that could let the
older baseline win over the better- calibrated reprocessed one.

- New internal helpers `.s2_split_product_id()` and
  `.dedup_s2_reprocessed()` collapse reprocessing duplicates by
  acquisition identity (mission + sensing time + relative orbit + MGRS
  tile), keeping the most recent processing baseline. Both the 6-field
  Planetary Computer id and the 7-field ESA `.SAFE` id are recognised;
  unrecognised ids are never merged.
- [`stac_search_s2()`](https://pobsteta.github.io/nemeton/reference/stac_search_s2.md)
  now deduplicates every backend result, so all consumers (FORDEAD
  ingestion, FAST NDVI/NBR) benefit.
- [`.build_stac_collection_for_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-build_stac_collection_for_aoi.md)
  applies the same dedup as a safety net before handing the collection
  to FORDEAD.

Genuinely distinct same-day acquisitions (different orbit or mission)
are never merged.

## nemeton 0.41.1 (2026-05-20)

#### Fixed — FORDEAD version probe no longer forces a reinstall every run

The FORDEAD pipeline reinstalled its Python dependencies
(`pip install --upgrade -r requirements.txt`, git clones and all) on
**every**
[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
call, and reported `fordead=NA` in the start banner.

Root cause: the version probe read the `fordead.version` attribute,
which is a *function* — not a version string. Printing it yielded a
`<function …>` repr that never matched the pinned `2.1.1`, so
[`.fordead_is_installed()`](https://pobsteta.github.io/nemeton/reference/dot-fordead_is_installed.md)
always returned `FALSE` and
[`.ensure_fordead_python()`](https://pobsteta.github.io/nemeton/reference/dot-ensure_fordead_python.md)
re-ran pip.

- [`.fordead_python_version()`](https://pobsteta.github.io/nemeton/reference/dot-fordead_python_version.md)
  now reads the canonical distribution version via
  `importlib.metadata.version("fordead")`.
- [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  reuses that same probe for its start banner instead of poking module
  attributes, so `fordead_version` is now reported correctly.
- New internal helper
  [`.python_capture_stdout()`](https://pobsteta.github.io/nemeton/reference/dot-python_capture_stdout.md)
  wraps the [`system2()`](https://rdrr.io/r/base/system2.html) call so
  the probe is unit-testable.

With a correctly pinned venv, FORDEAD runs now skip the pip step
entirely, shaving the reinstall time off every diagnostic.

## nemeton 0.41.0 (2026-05-20)

#### New — FORDEAD dieback mask persisted to the project cache

[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
ran FORDEAD inside a bare `tempfile("fordead_")` directory, wiped when
the session ended. Every diagnostic artefact — including the categorical
0-4 dieback mask — was lost, and
[`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md)
(shipped in v0.25.0 with its path convention fully documented) always
returned `NULL` because nothing ever wrote the mask.

Two changes close the loop:

- **Mask persist hook (always on).** After the `postprocess` phase, the
  categorical 0-4 state raster is written to
  `<mask_cache_dir>/zone_<zone_id>/dieback_mask_<YYYYMMDDTHHMMSS>.tif` —
  the exact path
  [`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md)
  looks up. The run timestamp doubles as the run id, so successive runs
  accumulate as a history rather than overwriting. The write is
  best-effort: a failure warns but never aborts the pipeline.

- **New `mask_cache_dir` argument.** Root of the FORDEAD persistent
  cache. `NULL` (default) derives it as the sibling of `cache_dir`:
  `file.path(dirname(cache_dir), "fordead")`,
  i.e. `<project>/cache/layers/fordead` for the conventional layout.

- **New `keep_output` argument (opt-in, default `FALSE`).** When `TRUE`
  and `output_dir` is left at its default, FORDEAD runs directly inside
  `<mask_cache_dir>/zone_<zone_id>/run_<YYYYMMDDTHHMMSS>/` so the full
  raster working set (≈1000+ GeoTIFFs) survives the session — useful to
  re-run `postprocess` with different `min_pixels` / `connectivity`
  without re-`fit`/`predict`. An explicit `output_dir` always wins.

The result list gains `rasters$dieback_mask` (path to the persisted
mask, or `NA_character_` on write failure).

Backward compatibility: full. With `keep_output = FALSE` (default) the
working set still lands in a temporary directory exactly as before; only
the small categorical mask is now additionally persisted.

Tests: 3 new scenarios in `test-fordead-pipeline.R` (mask written to an
explicit `mask_cache_dir` and round-tripped through
[`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md);
default `mask_cache_dir` derivation; `keep_output = TRUE` redirecting
`output_dir`). 65 PASS.

## nemeton 0.40.1 (2026-05-20)

#### Fixed — silent post-`predict` phases in `run_fordead_dieback()`

Only the `fit` and `predict` phases printed a `Step:` line (they are
wrapped in the `.capture()` helper). Everything after `predict` —
deriving the state raster, `first_dieback_date`, `postprocess` (anomaly
clustering) and `persist` (DB insert) — ran with no console output at
all. On a multi-year FORDEAD run the console stayed frozen on
`ℹ Step: predict` for minutes, indistinguishable from a hang.

[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
now emits, when `verbose = TRUE`:

- `FORDEAD output_dir: <path>` at startup — so the working directory is
  discoverable without digging through
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).
- `Step: derive state raster`
- `Step: first_dieback_date`
- `Step: postprocess`
- `Step: persist`
- `FORDEAD diagnostic complete: N alert(s) inserted in X s` on success.

No behaviour change beyond console output; the progress callback events
(`fordead:phase` / `fordead:phase_done`) are untouched.
`test-fordead-pipeline.R` unchanged (54 PASS) — `cli` console output is
not a progress event so the event-count assertions still hold.

## nemeton 0.40.0 (2026-05-20)

#### Added — authenticated THEIA access via the teledetection SDK

A live test confirmed THEIA assets require an authenticated,
time-limited **signed URL**: the THEIA API key signs the asset href (a
standard AWS SigV4 presign), and the signed URL is then read by GDAL via
`/vsicurl/`. Direct `/vsis3/` access with the API key is *not* possible
(the gateway signs with its own account).

- **New exported helper
  `theia_signed_href(source_key, year, asset, item_id, ...)`** — returns
  a ready-to-read, `/vsicurl/`-prefixed signed URL. The signing is
  delegated to the official `teledetection` Python SDK through
  `reticulate` (`tld.sign_inplace`);
  [`reticulate::py_require()`](https://rstudio.github.io/reticulate/reference/py_require.html)
  declares the Python packages automatically.
- **[`load_theia_source()`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md)
  year mode now uses SDK signing.** When `year` is supplied, the asset
  URL is signed via
  [`theia_signed_href()`](https://pobsteta.github.io/nemeton/reference/theia_signed_href.md)
  and read through `/vsicurl/` — the validated, working path for THEIA
  assets. The spatial-search mode (`/vsis3/`) is kept but reserved for
  direct-S3 setups.

Workflow: `load_theia_source("formspot", aoi, year = 2023)` — requires
`reticulate` plus the Python `teledetection` / `pystac_client` packages
and a registered THEIA API key (<https://gate.stac.teledetection.fr>).

## nemeton 0.39.1 (2026-05-20)

#### Fixed — correct THEIA S3 credentials and region

A live test against the THEIA store showed the v0.38.0
[`theia_configure_s3()`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)
config was wrong on two points, now fixed:

- **Environment variables**: the THEIA API key (created at
  <https://gate.stac.teledetection.fr>) is a standard S3 SigV4 key pair.
  [`theia_configure_s3()`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)
  now reads `TLD_ACCESS_KEY` / `TLD_SECRET_KEY` (the same names the
  `teledetection` SDK uses), not `THEIA_S3_*`.
- **Region**: the S3 region is `sm1` (visible in the `X-Amz-Credential`
  scope of a signed URL), not `us-east-1`. `services.theia_s3.region` in
  `FR.json` is corrected.

With the correct key pair and region, GDAL reads the THEIA assets
directly via `/vsis3/` with native SigV4 signing — no Python /
`teledetection` SDK required.

## nemeton 0.39.0 (2026-05-20)

#### Added — year targeting for annual THEIA collections

FORMSpoT (and similar annual time-series collections) publish one STAC
item per year — `FORMSpoT-{year}` — each with a year-specific asset
(`height_{year}`). A bbox search would return every yearly item, so a
dedicated lookup is needed.

- **New exported helper `stac_get_item(stac_api, collection, item_id)`**
  — fetches a single STAC item by id.
- **[`resolve_theia_assets()`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md)
  and
  [`load_theia_source()`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md)
  gain a `year` argument.** When supplied and the datasource declares an
  `access$item_id_template` (FORMSpoT does), the matching item is
  fetched directly by id and the year-specific asset is resolved — no
  spatial search. The asset name defaults to `access$asset_template`
  with `{year}` substituted.
- `inst/datasources/FR.json`: the `formspot` entry now carries
  machine-usable `item_id_template` (`FORMSpoT-{year}`),
  `asset_template` (`height_{year}`) and `years` (\[2014, 2024\]).

Usage: `load_theia_source("formspot", aoi, year = 2023)`.

## nemeton 0.38.0 (2026-05-20)

#### Added — authenticated THEIA S3 reads

The THEIA / FORMS COG and VRT assets live on an S3-compatible (MinIO)
object store. Rather than reimplementing the `teledetection` SDK’s URL
signing, `nemeton` reads the objects directly with GDAL’s `/vsis3/`
virtual filesystem, which signs each request natively.

- **New exported helper
  `theia_configure_s3(access_key, secret_key, country)`** — sets the
  GDAL `/vsis3/` configuration (endpoint, path-style hosting, region)
  for the session. Credentials are read from the `THEIA_S3_ACCESS_KEY` /
  `THEIA_S3_SECRET_KEY` environment variables (a gitignored `.Renviron`)
  — never stored in the package.
- **[`resolve_theia_assets()`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md)
  now returns `/vsis3/` paths.** Asset hrefs are normalised by a new
  internal helper handling the teledetection download-gateway form
  (`gate.../download?url=...`), `s3://` URIs and path-style `https://`
  object URLs.
- **[`load_raster_source()`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)
  accepts remote paths.** Its `path` argument now takes `s3://`,
  `http(s)://` and `/vsi*` paths in addition to local files (`s3://` is
  normalised to `/vsis3/`, `http(s)://` to `/vsicurl/`).
- New `services.theia_s3` entry in `FR.json` declaring the (non-secret)
  S3 endpoint `s3-data.meso.umontpellier.fr` and bucket `sm1-gdc-ext`.

Workflow:
[`theia_configure_s3()`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)
once per session, then
`load_theia_source("formspot", aoi, asset = "height_2023")`.

## nemeton 0.37.0 (2026-05-20)

#### Changed — THEIA STAC endpoint corrected, FORMSpoT metadata verified

Verified against the official FORMSpoT data-access notebook (Schwartz,
gist) and the `teledetection` Python SDK:

- **STAC API endpoint corrected** to `https://api.stac.teledetection.fr`
  (the MTD STAC API behind the `teledetection` SDK). The previous
  `api.datastore-mtd.theia.data-terra.org` value was the metadata
  document host shown in the browser, not the programmatic API.
- **Authentication required**: asset download needs a teledetection API
  key — the SDK’s `tld.sign_inplace` signs the STAC asset hrefs.
  `services.theia_stac` now documents this in an `auth` field. The R
  STAC resolver does **not** yet implement teledetection signing (see
  `PLAN.md`).
- **FORMSpoT metadata verified**: collection `FORMSpoT`, one item per
  year `FORMSpoT-{year}` (2014-2024), height asset `height_{year}`. The
  height is stored in **decimetres** — divide by 10 before passing it as
  `chm`.
- **New datasource `formspot_delta`** — the companion FORMSpoT-∆
  forest-disturbance polygons (collection `FORMSpoT-delta`, item
  `FORMSpoT-delta_2014-2024`, asset `disturbance_polygons`, each polygon
  carrying the disturbance `year`). `consumed_by`: R5, T2.

## nemeton 0.36.1 (2026-05-20)

#### Fixed — THEIA STAC endpoint confirmed

- `services.theia_stac.url` in `inst/datasources/FR.json` is now the
  verified THEIA MTD STAC API root
  (`https://api.datastore-mtd.theia.data-terra.org`, STAC 1.1.0,
  anonymous access) — no longer `"to confirm"`. The `forms_t` entry
  gains the verified `stac_collection: "forms-t"` and its `stac_catalog`
  host is corrected, so `load_theia_source("forms_t", aoi, asset = ...)`
  resolves out of the box.
- The Theia STAC resolver’s `"to confirm"` guard now matches any string
  containing `"to confirm"` (the FR.json placeholders read
  `"to confirm at the Theia catalogue"`), instead of only the exact
  literal — so sources with an unverified `stac_collection` are still
  correctly rejected.

## nemeton 0.36.0 (2026-05-20)

#### Added — THEIA STAC resolver

New module `R/theia_stac.R` closes the deferred Phase 2 item of the
Theia chantier: the Theia datasources can now be materialised from the
THEIA STAC API instead of requiring a manual download.

- **`stac_search_items(stac_api, collection, bbox, datetime, limit)`** —
  endpoint-agnostic STAC item search, built on the project STAC
  paginator. Works against any STAC API.
- **`resolve_theia_assets(source_key, aoi, asset, datetime, country, stac_api, limit)`**
  — looks up a Theia datasource, searches the THEIA STAC API for items
  of its collection intersecting the AOI, and returns the matching asset
  hrefs prefixed with `/vsicurl/`.
- **`load_theia_source(source_key, aoi, asset, ...)`** — resolves and
  loads a Theia datasource as a `SpatRaster` cropped to the AOI (virtual
  mosaic when several items match).

The THEIA STAC API endpoint is read from the new `services.theia_stac`
entry of `inst/datasources/FR.json`. Its `url` field is shipped as
`"to confirm"`: the STAC browser host
(`browser.datastore-mtd.theia.data-terra.org`) is known, but the STAC
API root behind it must be filled in (or passed via the `stac_api`
argument). Until then the resolver aborts with an actionable message
rather than guessing an endpoint.

## nemeton 0.35.2 (2026-05-20)

#### Changed — FORMSpoT wired into C1/P1/P2/B2 via the shared CHM interface

The `formspot` datasource entry is no longer a deferred reliquat:
FORMSpoT integrates into the indicators through the **existing `chm`
argument** of
[`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md),
[`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md),
[`indicateur_p2_station()`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md)
and
[`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md)
— the same Canopy Height Model interface already used by FORMS-T
(`forms_t`) and `chm_opencanopy`. No new indicator code is required: the
FORMSpoT tree-level canopy-height product is loaded with
`load_raster_source("formspot", path = ...)` and passed as `chm`.

`inst/datasources/FR.json` is updated accordingly: the `formspot`
`consumed_by` block now names the precise indicator functions
(C1/P1/P2/B2 instead of the vague C/P/T/R), the `products` block splits
into `height` (CHM-compatible) and `biomass`, and a new
`integration_note` documents the shared-`chm` integration path
(including the caveat to rasterise the height attribute if FORMSpoT is
delivered as a vector tree-point layer).

## nemeton 0.35.1 (2026-05-20)

#### Fixed — FORMSpoT confirmed as a THEIA STAC collection

The `formspot` datasource entry in `inst/datasources/FR.json` was
declared provisional in v0.30.0 (preprint stage, Theia availability
unconfirmed). FORMSpoT is in fact published as the THEIA STAC collection
`FORMSpoT`
(`browser.datastore-mtd.theia.data-terra.org/collections/FORMSpoT`). The
entry now carries the verified `stac_catalog` and `stac_collection`
fields, and the provisional note is replaced by the actual distribution
description. Indicator wiring for FORMSpoT remains deferred (see
`PLAN.md`).

## nemeton 0.35.0 (2026-05-20)

#### Added — Theia data sources, phase 3d (indicator wiring: phase-1b sources)

Phase 3d wires the phase-1b Theia sources into the indicators and closes
Phase 3 of the “Theia data sources” chantier.

- **W2 —
  [`indicateur_w2_zones_humides()`](https://pobsteta.github.io/nemeton/reference/indicateur_w2_zones_humides.md)
  gains a `water_occurrence` argument** (plus `occurrence_threshold`,
  default 25 %). When the Theia `theia_water` water-occurrence raster is
  supplied, pixels whose occurrence frequency reaches the threshold add
  to the wetland coverage — a fourth source alongside BD TOPO water
  surfaces, the TWI threshold and OSO land-cover codes.
- **R3 —
  [`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md)
  gains `soil_moisture` and `sm_relief_strength` arguments.** When the
  Theia `theia_soil_moisture` raster is supplied, moist soil attenuates
  drought stress against a 0.3 m³/m³ field-capacity reference (same
  relief mechanism as the `snow` argument added in 0.34.0).
- **New exported helper
  [`units_add_species_from_raster()`](https://pobsteta.github.io/nemeton/reference/units_add_species_from_raster.md).**
  It fills a species column on `units` from a tree-species
  classification raster (the Theia `theia_species` product) and a
  user-supplied class-to-species crosswalk, resolving the
  coverage-weighted dominant class per unit. This is the upstream
  integration point for the P / C / biodiversity indicators, which read
  a species column.

All additions are backward-compatible.

**Deferred wirings** (documented in `PLAN.md`): `s2_l2a_muscate` is base
Sentinel-2 reflectance — its integration point is the existing S2
ingestion pipeline, not an indicator argument; `theia_lst` → A2 is a
semantic mismatch (A2 is an air-quality index, not a microclimate one);
`theia_water` → W1 is deferred (W1 is a linear-network density, a raster
mask does not map to it); `formspot` wiring waits until the product is
confirmed on the Theia catalogue.

## nemeton 0.34.0 (2026-05-20)

#### Added — Theia data sources, phase 3c (indicator wiring: theia_snow)

Phase 3c wires the Theia Snow collection product `theia_snow` into the
drought-risk indicator R3.

- **R3 —
  [`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md)
  gains a `snow` argument** (plus a `snow_relief_strength` tuning
  parameter). When a snow-cover-duration `SpatRaster` is supplied (the
  Theia `theia_snow` `snow_cover_duration` product, in days/year), the
  snowpack is treated as a seasonal water reserve: the per-unit mean
  duration is rescaled to a 0-1 relief factor against a 180-day
  reference, and R3 is multiplied by `1 - snow_relief_strength * relief`
  (default `snow_relief_strength = 0.3`, i.e. up to a 30 %
  drought-stress reduction for a 6-month snowpack). Units with no snow
  coverage are left unchanged.

`snow = NULL` (default) preserves the pre-existing climate + topography
behaviour — no existing caller is affected. Phase 3d (the phase-1b
sources) remains, scoped in `PLAN.md`.

## nemeton 0.33.0 (2026-05-20)

#### Added — Theia data sources, phase 3b (indicator wiring: theia_soil)

Phase 3b wires the Theia soil-texture product `theia_soil` into the soil
family (F1, F2).

- **Two exported texture helpers.**
  `texture_to_fertility_score(clay, silt, sand, coarse_elements)` maps a
  soil-texture composition to a 0-100 forest-fertility score (proximity
  to the loam optimum in the texture triangle, with a coarse-element
  penalty). `texture_to_erosion_resistance(clay, silt, sand)` maps
  texture to a 0-100 erosion-resistance score (USLE erodibility logic:
  silt erodes, clay resists). Both are calibratable first-pass
  heuristics, exported for pedologist audit; the texture triplet is
  renormalised internally, so inputs may be in any consistent unit
  (g/kg, percent, fraction).
- **F1 —
  [`indicateur_f1_fertilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_f1_fertilite.md)
  gains a `"theia_soil"` source** and a `texture` argument (a named list
  of clay / silt / sand, optionally coarse_elements, `SpatRaster`s). In
  that mode F1 derives fertility from the per-unit mean texture via
  [`texture_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/texture_to_fertility_score.md).
- **F2 —
  [`indicateur_f2_erosion()`](https://pobsteta.github.io/nemeton/reference/indicateur_f2_erosion.md)
  gains a `texture` argument.** When supplied, a texture
  erosion-resistance component is averaged into F2 alongside the TWI and
  slope components (F2 = mean of the three). `texture = NULL` (default)
  preserves the pre-existing TWI + slope behaviour.

All additions are backward-compatible: existing F1/F2 callers are
unaffected. Phase 3c (`theia_snow` → R3) and 3d (the phase-1b sources)
remain, scoped in `PLAN.md`.

## nemeton 0.32.0 (2026-05-20)

#### Added — Theia data sources, phase 3a (indicator wiring: s2_biophysical)

Phase 3 of the “Theia data sources” chantier wires the declared sources
into the indicator functions, one source at a time, with strictly
backward-compatible optional arguments. Phase 3a wires the Sentinel-2
biophysical product `s2_biophysical` into two indicators:

- **C2 —
  [`indicateur_c2_ndvi()`](https://pobsteta.github.io/nemeton/reference/indicateur_c2_ndvi.md)
  gains a `fapar` argument.** When a FAPAR `SpatRaster` is supplied (the
  Theia `s2_biophysical` FAPAR product), the indicator returns the
  per-unit mean FAPAR instead of NDVI. FAPAR is a physically grounded
  vitality measure on the same `[0, 1]` scale as NDVI, so downstream
  normalization is unchanged. `fapar = NULL` (default) preserves the
  pre-existing NDVI behaviour.
- **A1 —
  [`indicateur_a1_couverture()`](https://pobsteta.github.io/nemeton/reference/indicateur_a1_couverture.md)
  gains an `fvc` argument**, and `land_cover` now defaults to `NULL`.
  When an FVC `SpatRaster` is supplied (the Theia `s2_biophysical` FVC
  product), A1 is the per-buffer mean FVC rescaled to a 0-100
  percentage; `land_cover` is then ignored. `fvc = NULL` (default)
  preserves the land-cover behaviour.

Both arguments are purely additive — no existing caller is affected.
Phase 3b (`theia_soil` → F1/F2), 3c (`theia_snow` → R3) and 3d (the
phase-1b sources) remain, scoped in `PLAN.md`.

## nemeton 0.31.0 (2026-05-20)

#### Added — Theia data sources, phase 2 (loaders)

Phase 2 of the “Theia data sources” chantier (see `PLAN.md`) makes the
catalogue entries declared in Phases 1a/1b actually loadable.

- **[`load_raster_source()`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)
  gains a `path` argument.** The Theia datasources (`forms_t`,
  `theia_soil`, `theia_snow`, …) are `type: "raster_local"` with no
  static URL — they are distributed per tile/year via the Theia
  catalogue and downloaded by the user.
  [`load_raster_source()`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)
  now accepts an explicit `path` to the downloaded file, so these
  sources become loadable through the normal datasource API (CRS
  harmonisation, AOI cropping). Path-less `raster_local` sources still
  error cleanly when no `path` is supplied, and the file must exist.
- **New exported helper
  [`get_datasource_product()`](https://pobsteta.github.io/nemeton/reference/get_datasource_product.md).**
  Multi-product datasources (e.g. `forms_t` with `height` / `volume` /
  `biomass`, `theia_soil` with `clay` / `silt` / `sand` /
  `coarse_elements`) bundle several rasters under a `products` block.
  `get_datasource_product(source_key, product)` returns one
  sub-product’s metadata (resolution, unit, value range, conversion
  notes — e.g. the FORMS-T cm-to-m note), so a caller can pick the right
  product and apply the documented unit conversion before feeding it to
  an indicator.

A STAC auto-resolution path against the Theia catalogue is deliberately
*not* implemented yet: the per-source STAC collection identifiers are
still marked `"to confirm"` in `FR.json`. Phase 2 therefore standardises
on the download-then-load workflow; STAC resolution is deferred until
those endpoints are verified. Phase 3 (indicator wiring) remains.

## nemeton 0.30.0 (2026-05-20)

#### Added — Theia data sources, phase 1b (catalogue declarations)

Second batch of the “Theia data sources” chantier (see `PLAN.md`). Six
further Theia / DATA TERRA products are declared in
`inst/datasources/FR.json`, completing Phase 1 (catalogue). Declarative
only — no core indicator code is modified:

- **`theia_water`** — surface-water extent and occurrence (Surfwater
  lineage). `consumed_by`: W1, W2.
- **`theia_soil_moisture`** — SMOS L3 (coarse, regional context) and
  Sentinel-1-derived surface soil moisture. `consumed_by`: W3, R3, F1.
- **`s2_l2a_muscate`** — Sentinel-2 Level-2A surface reflectance
  (MUSCATE / MAJA), a French national alternative to the CDSE /
  Planetary Computer feed. `consumed_by`: C2, T2, R5.
- **`theia_species`** — tree-species classification, tagged
  `augmented: "species_ml"`. `consumed_by`: B1, B2, P, C.
- **`theia_lst`** — land-surface temperature (Thermocity lineage).
  `consumed_by`: A2.
- **`formspot`** — FORMSpoT tree-level forest monitoring; declared as a
  provisional entry (preprint arXiv:2512.17021, Theia availability to
  confirm). `consumed_by`: C, P, T, R.

As in Phase 1a, every entry is `type: "raster_local"` with no static
URL, `ndp_level: 0`, and carries `consumed_by`, `provenance` and
explicit `"to confirm"` markers. Phase 1 (catalogue) is now complete;
Phase 2 (loaders) and Phase 3 (indicator wiring) remain, scoped in
`PLAN.md`.

## nemeton 0.29.0 (2026-05-20)

#### Added — Theia data sources, phase 1a (catalogue declarations)

First batch of the “Theia data sources” chantier (see `PLAN.md`). Three
priority Theia / DATA TERRA products are now declared in
`inst/datasources/FR.json` (section `datasets`), following the
declarative pattern established by `forms_t` in v0.28.0 — no core
indicator code is modified:

- **`s2_biophysical`** — Sentinel-2 biophysical variables (LAI, FAPAR,
  FVC) at 10 m. `consumed_by`: C2 (vitality, complements NDVI), A1
  (canopy cover via FVC), B2 (LAI heterogeneity).
- **`theia_soil`** — metropolitan-France soil maps: clay, silt, sand
  fractions and coarse-element content. `consumed_by`: F1 (texture as a
  fertility proxy, a France-wide alternative to the global SoilGrids CEC
  layer), F2 (erodibility).
- **`theia_snow`** — Theia Snow collection (Let-it-snow / LIS):
  snow-cover maps and annual phenology at 20 m. `consumed_by`: R3
  (snowpack as a seasonal water reserve modulating drought stress), W
  (winter water input).

Each entry carries `ndp_level: 0`, a `consumed_by` block, a `provenance`
block and explicit `"to confirm"` markers on metadata not yet verified
(STAC collection id, exact resolution, licence). All three are
`type: "raster_local"` with no static URL —
[`load_raster_source()`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)
deliberately refuses to fetch them, as for `forms_t` and
`chm_opencanopy`.

This release covers Phase 1a only. Phase 1b (six further Theia sources),
Phase 2 (loaders) and Phase 3 (indicator wiring) are scoped in
`PLAN.md`.

## nemeton 0.28.0 (2026-05-20)

#### Added — FORMS-T (Theia) declared as a forest data source

`inst/datasources/FR.json` now declares the `forms_t` dataset: the
FORMS-T time-series of forest attribute maps over metropolitan France
(2018-present), produced by Theia / DATA TERRA from a deep-learning
fusion of Sentinel-1, Sentinel-2 and GEDI lidar (Schwartz et al. 2023,
ESSD, <doi:10.5194/essd-15-4927-2023>).

Three products are described, each with resolution, unit and a plausible
value range:

- **height** — canopy height, 10 m, stored in centimetres;
- **volume** — growing stock volume, 30 m, m3/ha;
- **biomass** — aboveground biomass, 30 m, Mg/ha.

The entry carries a `consumed_by` block documenting how the height
product feeds the existing CHM path of four indicators —
[`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md)
(C1),
[`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
(P1),
[`indicateur_p2_station()`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md)
(P2) and
[`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md)
(B2). FORMS-T height is in centimetres, so callers divide the raster by
100 before passing it as the `chm` argument (which expects metres).

The source is `type: "raster_local"` and carries no static URL
(distribution is per-tile/per-year via the THEIA STAC catalog or the
Zenodo record), so
[`load_raster_source()`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)
deliberately refuses to fetch it — the caller resolves the STAC asset
href or a local download path first. It is tagged `ndp_level: 0` and
`augmented: "height_ml"`, consistent with ADR-011 amended (satellite +
ML granularity, no NDP level change).

## nemeton 0.27.0 (2026-05-19)

#### Fixed — STAC search silently capped at 100 features

[`stac_search_s2()`](https://pobsteta.github.io/nemeton/reference/stac_search_s2.md)
and its two backends
([`stac_search_s2_cdse()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md),
[`stac_search_s2_pc()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md))
had `limit = 100L` hardcoded, with no pagination. Any AOI × date-range
request hitting more than 100 matching scenes was silently truncated to
the 100 most recent ones — which broke every FORDEAD run with a
multi-year training window: the training window 2018-2020 saw 0 scenes
because the search only ever returned the latest ~16 months.

User-visible symptom (post v0.25.7 gating, still present in v0.26.0):

    ✖ FORDEAD pipeline failed: No Sentinel-2 scene in the training
      window for zone 1.
    ✖ Scenes available: "2024-02-03" → "2026-05-01" (100 scenes).
    ✖ Training window: "2018-01-01 -> 2019-12-31" (0 scenes).

The garde-fou pointed at the dates, but the real cause was the search
cap.

#### New — STAC pagination via `links[rel=next]`

`R/sentinel2.R` now exposes `.stac_search_paginate()`, a generic
paginator that:

- follows the STAC API standard `links[rel=next]` mechanism (both
  POST-with-body and GET-with-token variants),
- per-page size is fixed at 1000 (the max accepted by both CDSE and
  Planetary Computer); override via the env var `NEMETON_STAC_PAGE_SIZE`
  for backends with stricter caps,
- stops on (a) no [`next`](https://rdrr.io/r/base/Control.html)
  link, (b) empty page (defensive),
  3.  cumulative count reaching the user `limit`, or (d) the 100-page
      safety cap (`.STAC_MAX_PAGES`) — the latter emits an actionable
      `cli_warn` pointing at `start`/`end`/`max_cloud`.

Both
[`stac_search_s2_cdse()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
and
[`stac_search_s2_pc()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
now route through this helper. The default `limit` is bumped from 100 to
**10000** at the façade and at both backends — that’s ~10 years of
single-tile coverage, more than enough for FORDEAD’s canonical 2-year
training + 18-month monitoring window. Callers that want a quick preview
can still pass `limit = 50`.

Roxygen for the `limit` parameter rewritten with the new semantics
(total cap across pages, not per-request page size).

#### Tests

5 new scenarios in `test-sentinel2.R` covering the paginator
(`with_mocked_responses`): single-page, multi-page traversal,
`max_total` truncation, empty-page defensive stop, and
`NEMETON_STAC_PAGE_SIZE` env var override. 101 PASS (+13). Two
pre-existing failures in the same file (mocked-binding warnings test,
unrelated to v0.27.0) are flagged for separate investigation.

The FORDEAD pipeline test suite (`test-fordead-pipeline.R`, 54 PASS) is
unchanged: the mocks stub
[`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)
directly so the STAC swap is transparent.

#### Migration

Backward compatibility: full. Callers that did not pass an explicit
`limit` get more results (up to 10000 instead of 100) without any code
change. Callers that passed `limit = N` keep the exact same upper-bound
semantics — only the path to reach it changed.

## nemeton 0.26.0 (2026-05-19)

#### New — BD Forêt V2 fallback in `check_fordead_validity()`

Guard-rail G3 (spec 008, ADR-013) gains an automatic species resolution
path.
[`check_fordead_validity()`](https://pobsteta.github.io/nemeton/reference/check_fordead_validity.md)
now accepts two new arguments:

- `bdforet`: an `sf` of BD Forêt V2 polygons (formation végétale layer,
  IGN).
- `layers`: a `nemeton_layers` object from which a `"bdforet"` vector
  layer is resolved automatically via the existing
  `resolve_vector_layer()` helper.

When `units` carries no recognisable species column
(`essence_dominante`, `essence`, `species_label`, `species`,
`essence_principale`) AND a BD Forêt source is provided, the function
derives the dominant essence per unit via the existing
[`enrich_parcels_bdforet()`](https://pobsteta.github.io/nemeton/reference/enrich_parcels_bdforet.md)
helper (area-weighted intersection) and runs the species check normally.
An informational `cli_alert_info` flags the fallback in the console.

Order of precedence:

1.  Species column already on `units` → used directly (unchanged).
2.  Else `bdforet` argument → enrich.
3.  Else `layers$vectors$bdforet` → resolve, then enrich.
4.  Else → warning with hint to pass `bdforet =` or `layers =`, species
    check skipped (`species_valid = NA`), same final behaviour as
    before.

The previous warning text (“No species column found on `units`…”) is
preserved when no fallback path succeeds, but now includes a hint line
pointing to the new arguments.

Backward compatibility: full. Callers that do not pass `bdforet` or
`layers` get the v0.25.9 behaviour.

Tests: 4 new scenarios in `test-fordead-validity.R` (direct `bdforet`,
resolution via `layers`, empty/no-resolution warning, ignored when units
already carries species). 63 PASS total on this file.

## nemeton 0.25.9 (2026-05-19)

#### Changed — calibrated rolling defaults for `run_fordead_dieback()`

The default training and monitoring windows of
[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
now reflect the ADR-013 calibration:

- `dates_training` defaults to `c("2018-01-01", "2020-12-31")` — a
  2-year baseline anchored on the start of Sentinel-2 dense coverage,
  long enough to fit the harmonic model and short enough to keep the
  baseline free from recent disturbances.

- `dates_monitoring` defaults to a rolling 18-month window ending today:

  ``` r

  c(
    as.character(seq(Sys.Date(), by = "-18 months", length.out = 2)[2]),
    as.character(Sys.Date())
  )
  ```

  18 months covers a full vegetation cycle plus the early stages of a
  slow dieback, while staying short enough to keep the diagnostic
  actionable.

Previous defaults (`2016-2017` training / `2018→today` monitoring)
required users to override the dates on every call to obtain a sensible
window. The new defaults make
`run_fordead_dieback(con, zone_id, cache_dir)` directly usable on
production zones without further configuration. Roxygen docs and the
example block are updated accordingly.

No code change beyond the signature defaults and documentation. All 54
existing FORDEAD tests pass unchanged: scenarios that exercise the date
logic already pass explicit windows.

## nemeton 0.25.8 (2026-05-19)

#### Fixed — `fordead.utils` submodule access via reticulate

Bug surfaced after v0.25.7 unblocked the training/monitoring gating.
Pipeline progressed cleanly through ingest / stac_assembly / fit /
predict, then `first_dieback_date` derivation warned with :

    ! first_dieback_date derivation failed: AttributeError: module
      'fordead' has no attribute 'utils'

Root cause : Python’s `import fordead` does NOT auto-import the
`fordead.utils` submodule. We accessed `fd$utils$backward_start` on the
top-level `fd <- reticulate::import("fordead", convert = FALSE)` handle,
which raised AttributeError every time. The pipeline kept running thanks
to the surrounding `tryCatch`, but `first_dieback_date` silently became
`NA_character_` in the result.

Fix in `R/fordead_pipeline.R::run_fordead_dieback()` : import
`fordead.utils` explicitly via
`reticulate::import("fordead.utils", convert = FALSE)` before calling
[`.compute_first_dieback_date()`](https://pobsteta.github.io/nemeton/reference/dot-compute_first_dieback_date.md).
The import is wrapped in `tryCatch` so a missing submodule (older
fordead pin) doesn’t abort the pipeline — `first_dieback_date` falls
back to `NULL` and the postprocess phase continues without the
first-dieback-date raster.

#### Tests

`test-fordead-pipeline.R` (54 PASS) unchanged — the mock stubs
`.compute_first_dieback_date` directly so the internal swap from
`fd$utils` to a dedicated `import("fordead.utils")` is transparent.

## nemeton 0.25.7 (2026-05-18)

#### Fixed — pre-`fit()` gating against empty training / monitoring windows

Bug surfaced once v0.25.6 unblocked CRS alignment and the user re-ran
FORDEAD on a real cache. Phase 1 STAC assembly succeeded over 116 scenes
(2024-2026 envelope), but `fit()` crashed deep in stackstac with :

    AssertionError: out_bounds=None

Root cause : the default
`dates_training = c("2016-01-01", "2017-12-31")` selected **zero**
scenes from a cache holding 2024+ data. fordead’s
`compute_spectral_index` ran on the empty time slice, wrote no CRSWIR
layer files, and the subsequent `update_ds("CRSWIR")` call to
`stackstac.stack(assets = ["CRSWIR"])` got an empty asset list →
`out_bounds` stayed `None` → assertion failure with no actionable
context for the caller.

Fix in `R/fordead_pipeline.R::run_fordead_dieback()` : after the ingest
phase populates `scenes_df`, count the scenes that fall in
`[dates_training[1], dates_training[2]]` and
`[dates_monitoring[1], dates_monitoring[2]]`. If either count is zero,
abort with a typed message that reports the scene-date envelope and the
requested windows so the caller can fix `dates_training` /
`dates_monitoring`. Example output:

    Error in `run_fordead_dieback()`:
    ! No Sentinel-2 scene in the training window for zone 1.
    ✖ Scenes available: 2024-02-03 → 2026-04-08 (116 scenes).
    ✖ Training window: 2016-01-01 -> 2017-12-31 (0 scenes).
    ✖ Monitoring window: 2018-01-01 -> 2026-05-18 (116 scenes).
    ℹ Adjust `dates_training` / `dates_monitoring` so both windows
      contain at least 1 scene from the available envelope.

#### Tests

- `test-fordead-pipeline.R` — 2 new tests (+4 PASS, total 54) :
  empty-training-window abort, empty-monitoring-window abort. Asserts
  that fordead’s `fit()` is never called when either window is empty.

## nemeton 0.25.6 (2026-05-18)

#### Fixed — FORDEAD `fit()` crashed with `NoDataInBounds` on UTM tiles

Bug surfaced once v0.25.2’s sampling fix landed and the user re-ran
FORDEAD on a real Sentinel-2 tile (T31TGM, EPSG:32631). The phase-0
ingest populated the cache, phase-1 STAC assembly built an
`ItemCollection` with the proper `proj:epsg = 32631` metadata, but
phase-2 `fit()` crashed in stackstac with :

    rioxarray.exceptions.NoDataInBounds: No data found in bounds.
    Data variable: stackstac-<hash>

Root cause : we passed `bbox` and `geometry` to `FordeadProcess(...)` in
EPSG:4326 (degrees) but the Sentinel-2 tile cache is in EPSG:32631
(meters). FordeadProcess’s `geometry` setter attempts
`value.to_crs(self.crs)` — but only when the input has a `to_crs`
attribute (GeoDataFrame / GeoSeries). Our previous implementation passed
a raw `shapely.geometry.Polygon` which has no `to_crs`, so the setter
could not reproject. The bbox stayed in degrees on the meter-CRS data
cube, and `stackstac.clip_box()` found zero pixels in the (sub-degree)
range.

Fix in two parts :

- `R/fordead_stac.R::.aoi_geometry_reticulate()` now returns a
  `geopandas.GeoSeries(crs = "EPSG:4326")` instead of a raw shapely
  Polygon. The setter’s `to_crs` + `total_bounds` path now triggers and
  reprojects the geometry to the collection CRS, while overriding
  `self.bbox` from `geometry.total_bounds` in the right CRS.
- `R/fordead_pipeline.R::run_fordead_dieback()` no longer passes a
  `bbox` argument to `FordeadProcess(...)` (pass `bbox = NULL`).
  Previously the constructor stored the degree-valued bbox at line 95 of
  fordead’s `workflow.py`, and the very next `geometry` setter triggered
  `self.crs` which calls `to_xarray(bbox=..., geometry=None)` — using
  the wrong-CRS bbox during an internal evaluation, which could also
  raise `NoDataInBounds` before our geometry override could take effect.
  With `bbox = None` the collection is assembled un-clipped, `self.crs`
  resolves to the collection’s CRS, and the geometry setter finishes the
  job cleanly.

#### Tests

- `test-fordead-stac.R` — `.aoi_geometry_reticulate` test updated to
  assert the returned object is a `geopandas.GeoSeries` with
  `crs = "EPSG:4326"`. Mocks `geopandas$GeoSeries` and
  [`reticulate::import_builtins()`](https://rstudio.github.io/reticulate/reference/import.html)
  alongside `shapely.wkt`. 73 PASS (baseline + new assertions ; 2
  pre-existing failures on charToDate fixtures unchanged).
- `test-fordead-pipeline.R` (48 PASS) unchanged — those tests mock
  `.aoi_geometry_reticulate` at the package level, so the internal
  implementation swap is transparent.

## nemeton 0.25.5 (2026-05-18)

#### Fixed — `resolve_project_dem()` / `resolve_project_chm()` missed direct files under `cache/layers/`

v0.25.4 only probed
`<project>/cache/layers/{lidar_mnt,dem,bd_alti, rge_alti,dtm,mnt}/*.tif`
(i.e. inside *sub*-directories) and root-level files
`<project>/{dtm,mnt,chm,mnh}.tif`. It did NOT probe
`<project>/cache/layers/dem.tif` directly — a convention used by some
downloaders that drop the raster flat in `cache/layers/` rather than
under a named sub-directory.

User report: a project with `<project>/cache/layers/dem.tif` returned
`NULL` from
[`resolve_project_dem()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md),
and the sampling-plan tab re-emitted the v0.25.1 “Stratification-valid
candidate pool (0)” abort.

Search order extended (DEM):

- `<project>/cache/layers/dem.tif` — direct file
- `<project>/cache/layers/dtm.tif` — direct file
- `<project>/cache/layers/mnt.tif` — direct file
- `<project>/dem.tif` — project root variant

Search order extended (CHM):

- `<project>/cache/layers/chm.tif` — direct file
- `<project>/cache/layers/mnh.tif` — direct file

The new direct-file probes sit just after the sub-directory probes and
before the project-root fallbacks, so they take precedence over root
`dtm.tif` / `mnt.tif` when both exist (cache/ is the more discoverable
convention).

5 new tests cover the direct-file matches and the priority between
`cache/layers/dem.tif` and root `<project>/dtm.tif`.

## nemeton 0.25.4 (2026-05-18)

#### Added — `resolve_project_dem()` / `resolve_project_chm()` discovery helpers

Néméton projects accumulate digital terrain models (MNT / DEM / DTM) and
canopy height models (MNH / CHM) from several producers, each landing
under its own naming convention:

- IGN RGE ALTI (tutorials): `<project>/mnt.tif`
- LiDAR HD (`lidR` pipeline): `<project>/cache/layers/lidar_mnt/*.tif`
- `opencanopynemeton`: `<project>/dtm.tif` at project root
- Open-Canopy CHM: `<project>/cache/layers/chm/*.tif`
- IGN BD ALTI / RGE ALTI:
  `<project>/cache/layers/{bd_alti,rge_alti}/*.tif`

Callers (`nemetonshiny`, scripts) used to hard-code paths that broke as
soon as a different producer was used. Most visibly, the
`<project>/dtm.tif` convention from `opencanopynemeton` was recognised
neither by `nemeton` nor by `nemetonshiny`, leading to the v0.25.1
“Stratification-valid candidate pool (0) is below `n_base`” failure even
when the DTM was perfectly downloaded — the file was just never passed
to `create_sampling_plan(mnt =)`.

Two new exported helpers walk a priority-ordered list of well-known
locations and return the first match:

``` r

dem <- nemeton::resolve_project_dem(project_path)
chm <- nemeton::resolve_project_chm(project_path)
plan <- nemeton::create_sampling_plan(zone, mnt = dem, chm = chm, ...)
```

DEM search order (highest quality first):

1.  `<project>/cache/layers/lidar_mnt/*.tif` — LiDAR HD (1 m)
2.  `<project>/cache/layers/dem/*.tif` — generic DEM cache
3.  `<project>/cache/layers/bd_alti/*.tif` — IGN BD ALTI (25 m)
4.  `<project>/cache/layers/rge_alti/*.tif` — IGN RGE ALTI (5 m)
5.  `<project>/cache/layers/dtm/*.tif` — generic DTM cache
6.  `<project>/cache/layers/mnt/*.tif` — generic MNT cache
7.  `<project>/dtm.tif` — `opencanopynemeton`
8.  `<project>/mnt.tif` — tutorial convention
9.  `<project>/data/dtm.tif` / `data/mnt.tif` — alt project layouts

CHM search order:

1.  `<project>/cache/layers/chm/*.tif` — Open-Canopy
2.  `<project>/cache/layers/lidar_mnh/*.tif` — LiDAR HD MNH
3.  `<project>/cache/layers/mnh/*.tif` — generic MNH cache
4.  `<project>/chm.tif`, `mnh.tif`, `data/chm.tif`, `data/mnh.tif`

When multiple tiles match in the same directory, the returned
`SpatRaster` is a virtual mosaic
([`terra::vrt()`](https://rspatial.github.io/terra/reference/vrt.html)),
so downstream
[`terra::extract`](https://rspatial.github.io/terra/reference/extract.html)
/ [`terra::crop`](https://rspatial.github.io/terra/reference/crop.html)
calls transparently cover the full footprint.

Both helpers accept `load = FALSE` (return paths only, useful for
diagnostics), `load = TRUE` (default, return a `SpatRaster`) and
`verbose = TRUE` (log every probed location). The returned object
carries the matched layer label as attribute `"nemeton_dem_layer"` /
`"nemeton_chm_layer"` for traceability.

11 new offline tests cover argument validation, single-file matches, the
`cache/layers/` discovery path, priority order (LiDAR HD beats
opencanopy DTM when both present), multi-tile VRT mosaicking,
verbose/silent modes, and case-insensitive matching for `DTM.tif` vs
`dtm.tif` on Windows. \# nemeton 0.25.2 (2026-05-17)

#### Fixed — `create_sampling_plan()` with overlapping BD Forêt polygons

Same symptom as the v0.25.1 fix
(`le tableau de remplacement a 363 lignes, le tableau remplacé en a 337`),
but a different code path — not caught by v0.25.1’s NA filter. Reported
again from `nemetonshiny@v0.35.0` after v0.25.1 landed.

Root cause : in `.stratify()`, the BD Forêt v2 join used
`sf::st_join(frame, forest_mask[, "tfv"], left = TRUE)`. `st_join`
returns **one row per (left, right) match**. BD Forêt v2 polygons
overlap by construction in mixed-class zones, so a candidate falling on
2 polygons produced 2 rows in the join — the result had more rows than
`frame`, and `frame$strat_type <- tfv_too_long` then crashed with the
system error.

v0.25.1’s filter (drop candidates whose CHM / MNT extraction is NA) ran
fine and reduced frame to 337 — but `st_join` immediately after inflated
the result to 363 rows, exactly matching the reported numbers.

Fix in `.stratify()` : replace
[`sf::st_join`](https://r-spatial.github.io/sf/reference/st_join.html)
with
[`sf::st_intersects`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html) +
first-match. The result is a list of length `nrow(frame)`, and we pick
the first matching polygon’s `tfv` value per candidate. Picking the
first match (arbitrary order from the spatial index) is a deliberate
simplification — multi-class overlaps are not joined by spatial majority
in the current scope.

#### Tests

- `test-sampling_stratification.R` — 1 new test (14 PASS total) :
  overlapping BD Forêt polygons (two polygons with explicit overlap
  zone). Pre-fix raised the size-mismatch error ; post-fix the plan
  generates and `strat_type` resolves to one of the BD Forêt classes.

## nemeton 0.25.1 (2026-05-17)

#### Fixed — `create_sampling_plan()` partial-coverage CHM / MNT

Bug reported from `nemetonshiny@v0.35.0`:
[`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
with CHM × MNT stratification on a partial-coverage raster failed with
`le tableau de remplacement a 363 lignes, le tableau remplacé en a 337`
when the AOI’s edge candidates fell on NA pixels.

Root cause : `.stratify()` produced strata strings like `"NA_FEU_BAS"`
for candidates with `mean_height = NA` or `mean_tpi = NA`.
[`spsurvey::grts()`](https://usepa.github.io/spsurvey/reference/grts.html)
silently dropped those rows from the frame, leaving a downstream size
mismatch on the `[<-` assignment that brought the size back to the full
pool.

Fix in `R/sampling_plan.R::create_sampling_plan()` : a new filter step
runs **between** the forest-cover / slope filter and the clamp,
**before** `.stratify()` is called. When `chm` / `mnt` is provided,
candidates whose extracted value is NA are dropped so the pool that
enters stratification is homogeneous on every requested dimension. Side
effects :

- When the filter removes more than 10 % of the pool, a
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
  reports the delta so the user knows their AOI has bordering candidates
  outside the CHM-MNT coverage.
- When the remaining pool is smaller than `n_base`, the function aborts
  cleanly via
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  with a typed message and remediation hints (rather than the previous
  silent grts failure).

#### Tests

- `test-sampling_stratification.R` (new) — 11 PASS. Covers (1) the exact
  bug reproducer (partial CHM, plan generated without error),
  2.  the \> 10 % reduction warning, (3) the under-`n_base` abort,
  3.  the no-stratification regression guard (`chm = NULL` and
      `mnt = NULL`), (5) full-coverage guard (no warning fires when CHM
      covers the whole AOI).

## nemeton 0.25.0 (2026-05-17)

#### Added — FAST alerts + FORDEAD mask exporters

Two new public functions powering the 4-subtabs Suivi sanitaire UI in
`nemetonshiny@v0.34.0` (Alertes FAST / Carte FAST / Alertes FORDEAD /
Carte FORDEAD).

- **`list_fast_alerts_for_zone(con, zone_id, threshold_ndvi = 0.40, threshold_nbr = 0.30, window_days = 30L, date_from, date_to)`**
  — aggregates `obs_pixel` per plot over the last `window_days` of the
  search window, classifies each plot by the worse of its NDVI / NBR
  ratios against threshold :
  - `critical` if either ratio `< 0.5`,
  - `warning` if either ratio in `[0.5, 1.0)`,
  - `info` if either ratio in `[1.0, 1.1)` (warning corridor),
  - safe plots (both ratios `>= 1.1`) are not returned. Returns an `sf`
    POINT layer in **EPSG:4326** with `plot_id`, `last_obs_date`,
    `ndvi_value`, `nbr_value`, `ndvi_drop`, `nbr_drop`, ordered factor
    `severity`. Empty-but-schema-stable `sf` when no plot is in the
    alert zone (caller-safe for `rbind` / `bind_rows`).
- **`read_fordead_dieback_mask(con, zone_id, run_id = NULL, cache_dir = NULL)`**
  — reads the categorical 0-4 dieback mask (`0 = sain`, `1 = faible`,
  `2 = moyenne`, `3 = forte`, `4 = sol nu`,
  `NA = hors masque forestier`) written by
  \[[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)\]
  to `<cache_dir>/zone_<zone_id>/dieback_mask_<run_id>.tif`. Without
  `run_id`, the latest mask (filename order on the YYYYMMDDTHHMMSS
  suffix) is returned. Returns a
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html),
  or `NULL` when no mask is available.

#### Internal — spec deviations documented in roxygen

- `list_fast_alerts_for_zone()` — severity is bucketed via *ratio*
  (`value / threshold`) rather than absolute *drop* margin, so a same
  `<= 50 %` shape works for both NDVI and NBR thresholds without tuning.
  Documented in roxygen `@section Severity rules`.
- [`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md)
  — the prompt-spec signature `(con, zone_id, run_id)` cannot derive the
  project root from the connection in this release (no `fordead_run`
  tracking table yet). We widen the signature with a required
  `cache_dir` argument and reserve `con` for forward compatibility.
  Documented in roxygen `@section con parameter`.
- Persist hook in
  [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  — out of scope for v0.25.0. The reader returns `NULL` until the
  postprocess phase is extended to write the classified mask to the
  conventional path. App should treat NULL as “no FORDEAD run yet” in
  the Carte FORDEAD subtab.

#### Tests

- `test-fast_alerts.R` — 26 PASS. Severity classifier exercised via
  mocked
  [`DBI::dbGetQuery`](https://dbi.r-dbi.org/reference/dbGetQuery.html)
  returning synthetic rows. Covers : 4-plot fixture with one of each
  severity (info / warning / critical / safe), worse-of-two-bands rule,
  drop column logic, NA observation exclusion, empty-result shape, input
  validation.
- `test-fordead_mask.R` — 15 PASS. Filesystem fixtures (3 × 3
  categorical GeoTIFFs via
  [`terra::writeRaster`](https://rspatial.github.io/terra/reference/writeRaster.html))
  under `<tmp>/zone_<id>/dieback_mask_<ts>.tif`. Covers : NULL on
  missing cache_dir / empty dir, value preservation 0..4 + NA,
  latest-run pick, explicit run_id, NULL on unknown run_id.

## nemeton 0.24.4 (2026-05-17)

#### Fixed — pystac assets now carry `proj:*` / `raster:*` metadata

Bug surfaced once v0.24.3 fixed the simplestac import: the pipeline got
further but every Item logged “has no assets left after filtering” then
`ValueError: Zero asset IDs requested`.

Cause: `simplestac.utils.filter_assets()` drops every asset whose
`extra_fields` doesn’t contain at least one key matching
`^proj:|^raster:`. Our hand-rolled
`pystac.Asset(href, roles, media_type)` calls produced assets with empty
`extra_fields` → 100 % of assets filtered out → fordead nothing to
compute on.

Fix in `R/fordead_stac.R::.build_stac_collection_for_aoi()` : delegate
asset construction to
`simplestac.local.stac_asset_info_from_raster(band_file)`, then build
the asset via `pystac.Asset.from_dict(info)`. The helper reads each
COG’s header (no pixel read) and returns a dict with `href`, `type`,
`roles`, `proj:epsg`, `proj:bbox`, `proj:shape`, `proj:transform`,
`gsd`, `raster:bands` — exactly the metadata fordead 2.x needs.

Cost: one COG header read per band per scene (cheap — terra and rasterio
both stream the GeoTIFF directory only). For 100 scenes × 6 bands = 600
header reads, \< 5 s on a warm cache.

#### Tests

Mock `simplestac.local` module added (`stac_asset_info_from_raster`
returns a minimal dict with `proj:epsg` / `proj:bbox` / `proj:shape` /
`proj:transform` / `raster:bands` for testability). Fake `pystac.Asset`
widened from a constructor to a list exposing `from_dict()`. Three test
switch blocks updated to wire the new module. 72 PASS / 2 pre-existing
failures unchanged.

## nemeton 0.24.3 (2026-05-17)

#### Fixed — `simplestac.ItemCollection` import via the right submodule

Bug surfaced once the v0.24.1 / v0.24.2 ingest path actually populated
the cache successfully and the pipeline reached phase 1 (STAC assembly):

    FORDEAD pipeline failed: AttributeError: module 'simplestac' has
    no attribute 'ItemCollection'

`simplestac` 1.2.5 does not re-export `ItemCollection` at the package
top level — the class lives in `simplestac.utils`. The v0.23.0 paperwork
assumed a top-level export ; verified against the installed venv on
2026-05-17 (`dir(simplestac)` returns only `PackageNotFoundError` and
`version`).

Fix in `R/fordead_stac.R::.build_stac_collection_for_aoi()` :
`reticulate::import("simplestac", convert = FALSE)` →
`reticulate::import("simplestac.utils", convert = FALSE)`.
`simplestac$ItemCollection(items)` resolves through the submodule
unchanged after the import target swap.

#### Tests

Mock import switch updated (`simplestac = ...` →
`simplestac.utils = ...`) in `test-fordead-stac.R`. 72 PASS, 2 pre-
existing failures unchanged (`charToDate` on synthetic fixtures —
present on baseline v0.24.2).

## nemeton 0.24.2 (2026-05-16)

#### Improved — FORDEAD ingest now emits the same `s2:*` events as FAST

In v0.24.0 / v0.24.1, the phase-0 ingest of
\[[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)\]
emitted `s2:search`, `s2:search_done`, `s2:scene`, `s2:scene_skipped`
and `s2:complete` — but **not** `s2:cache_lookup` (the pre-loop “X
cached, Y to fetch” summary) nor `s2:scene_cached` (the per-scene
“already on disk” signal). Result: the app showed “scene downloading”
for every scene even when the cache was already fully warm.

Parity restored:

- \[[`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)\]
  now does a filesystem-level cache pre-scan before the per-scene loop,
  and emits `s2:cache_lookup` with the `n_cached` / `n_to_process`
  counters.
- Each fully-cached scene emits `s2:scene_cached` (skipping the band
  fetch loop) instead of `s2:scene`.
- `s2:complete` now carries `n_scenes_cached` alongside the existing
  `n_bands_fetched` and `n_bands_cached`.

The downstream toast dispatcher in `nemetonshiny@v0.32.0+` already
handles these event keys (they were wired for FAST) — zero app change
required. Identical UX to FAST during the FORDEAD phase 0.

## nemeton 0.24.1 (2026-05-16)

#### Fixed — STAC search now exposes all 7 FAST + FORDEAD bands

Bug revealed at the first production use of v0.24.0
(\[[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)\])
: the ingest phase tried to fetch B02 / B05 / B8A / B11 from each scene
but
[`stac_search_s2()`](https://pobsteta.github.io/nemeton/reference/stac_search_s2.md)
only extracted hrefs for B04 / B08 / B12 (the three FAST bands). Result
: “Scene X has no href_B02 column” on every band, every scene → 100%
skip → “No scene in `scenes_df` had all required bands”.

Root cause : `.features_to_tibble()` hardcoded the three FAST bands when
extracting STAC assets, with no extension hook. The fix centralises the
band list in two private constants :

- `.S2_STAC_BANDS` — the seven bands now exposed:
  `c("B02","B04","B05","B08","B8A","B11","B12")`.
- `.S2_STAC_REQUIRED_BANDS` — the three bands a scene must have to
  remain in the result (`c("B04","B08","B12")`). The four FORDEAD- extra
  bands are kept tolerant : missing band on a given scene yields an
  empty href column, not a dropped row. Downstream consumers (FAST keeps
  using only B04/B08/B12 ; FORDEAD calls the ingest helper which now
  reports per-scene missing bands cleanly) decide individually whether
  to accept the scene.

Cost : one more asset lookup per feature, no extra HTTP. PC token
application is centralised over the seven bands via a loop.

#### Improved — clearer error when a STAC asset is missing

`.get_s2_band_raster()` previously errored with “Scene X has no href_B12
column” — which conflated two failure modes : (“the STAC schema doesn’t
expose this band” vs “this scene doesn’t have an asset for this band”).
v0.24.1 splits these into two typed messages so the root cause is
obvious in the warning aggregate.

#### Test

- `test-sentinel2.R` — empty-tibble shape test widened to the seven
  bands.
- No new failures introduced ; pre-existing failures (`charToDate` on
  synthetic fixtures, STAC retry test fragility) unchanged.

## nemeton 0.24.0 (2026-05-16)

#### Changed — FORDEAD now invocable with `(con, zone_id, cache_dir)` only

Spec 008 §13 amendment A2, plan 008 §10, ADR-013 amendment A2.

\[[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)\]
now derives its AOI from `monitoring_zone.zone_wkt` and runs a
partial-coverage-aware ingest phase as phase 0 — callers no longer need
to supply an explicit AOI or scenes_df. Discovered at the first
production use of v0.23.0 (error
`scenes_df is required and must be a data.frame`): the app has
`con + zone_id` everywhere, but reconstructing `scenes_df` required
walking the disk cache from the UI layer, duplicating logic that already
exists in the core.

**Public API changes (breaking)** :

- New signature :
  `run_fordead_dieback(con, zone_id, cache_dir, dates_training, dates_monitoring, ...)`.
  All three are required.
- Arguments **removed** : `aoi` (derived from
  `monitoring_zone.zone_wkt`), `scenes_df` (produced by the new phase-0
  ingest), `forest_mask` (already deprecated in v0.23.0).
- The phase plan grows from 5 (v0.23.0) to 6 phases — `ingest` is added
  as phase 0. `progress_callback` receives a new `phase_name = "ingest"`
  event ; the `s2:*` events from the ingest helper pass through
  verbatim, so a UI that already renders FAST toasts displays them with
  zero rework.

**New public surface** :

- `FORDEAD_BANDS` — exported character constant
  `c("B02","B04","B05","B8A","B11","B12")`. The six raw Sentinel-2 bands
  required by fordead 2.x for CRSWIR + masks. Differs from the FAST
  triplet `c("B04","B08","B12")` used by NDVI / NBR.
- [`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)
  — new public function that populates
  `<cache_dir>/<safe_scene_id>/<band>.tif` for an arbitrary set of raw
  Sentinel-2 bands, with no DB writes. Used internally by
  [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  (phase 0) and available to any custom pipeline that needs raw bands
  beyond NDVI / NBR. Companion of
  \[[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)\].
  \[[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)\]
  is strictly restricted to NDVI / NBR via `match.arg` — that function
  computes derived indices on the fly and writes them to `obs_pixel`, so
  it can’t be repurposed to fetch arbitrary bands.

**Internal restructure** :

- New `R/sentinel2_cache.R` — homes
  [`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)
  and `.empty_raw_ingest_summary()`.
- `R/fordead_pipeline.R` — `.get_zone_aoi(con, zone_id)` helper that
  queries `monitoring_zone.zone_wkt + crs_epsg` and reprojects to
  EPSG:2154. Replaces the previous direct AOI argument.
- [`.validate_fordead_args()`](https://pobsteta.github.io/nemeton/reference/dot-validate_fordead_args.md)
  signature simplified — no longer takes `aoi` / `forest_mask`. AOI
  validation moved next to its derivation via
  [`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md).
  The forest-mask deprecation warning is removed (forest_mask is gone
  for good).
- [`.empty_fordead_result()`](https://pobsteta.github.io/nemeton/reference/dot-empty_fordead_result.md)
  gains `zone_id` and `n_scenes` fields for parity with the success-path
  return value.
- Removed dead helper `.download_or_use_cached_bd_foret` (stub never
  wired to anything since v0.23.0 removed the forest_mask path).

**Tests refactor** :

- `test-fordead-pipeline.R` rewritten — every call site uses the new
  signature, `.mock_pipeline_helpers()` mocks the new `.get_zone_aoi` +
  `ingest_s2_raw_bands_to_cache`. Six-phase contract asserted (was
  four). Three new tests : ingest phase propagates `s2:*` verbatim,
  `n_alerts_inserted` path with always-on persist, `FORDEAD_BANDS`
  contents.
- `test-fordead-zone-aoi.R` (new) — five tests on `.get_zone_aoi` via
  mocked
  [`DBI::dbGetQuery`](https://dbi.r-dbi.org/reference/dbGetQuery.html).
- `test-sentinel2-cache.R` (new) — eight tests on
  `ingest_s2_raw_bands_to_cache` via mocked `.fetch_plots_sf` /
  `stac_search_s2` / `.get_s2_band_raster`.
- `test-fordead-integration.R` adapted — env vars are now
  `NEMETON_DB_URL` + `NEMETON_FORDEAD_TEST_ZONE_ID` +
  `NEMETON_FORDEAD_TEST_CACHE_DIR` (was AOI path + cache dir).

**Migration path** :

``` r

# v0.23.0
res <- run_fordead_dieback(aoi, scenes_df, cache_dir, ...)

# v0.24.0
res <- run_fordead_dieback(con, zone_id, cache_dir, ...)
```

The `nemetonshiny` migration (1 call site) ships in
`nemetonshiny@v0.33.0`.

## nemeton 0.23.0 (2026-05-16)

#### Changed — FORDEAD pipeline migrated to fordead 2.x

Spec 008 §12 amendment A1, plan 008 §9. The R-side FORDEAD pipeline
(\[run_fordead_dieback()\]) is rewritten to use fordead 2.x’s unified
`fordead.workflow.FordeadProcess` class instead of the dispersed 1.x
`fordead.steps.step1_*..step5_*` modules. Bridges the nemeton STAC COG
cache directly — no more THEIA / MAJA format gap.

The 1.x integration shipped in `v0.21.0` was never end-to-end
operational : kwargs were wrong (`vegetation_index` vs `vi`,
`input_directory` vs `data_directory`), the pipeline expected THEIA L2A
folders which
[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
doesn’t produce, and the 44 offline mocks accepted any kwarg. The
cascade of patches `v0.22.2..v0.22.5` (16 May 2026) revealed the gaps.
This release closes them properly.

**Public API changes (breaking)** :

- [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  gains two **required** arguments :
  - `scenes_df` — a data.frame with `scene_id` (character) and
    `obs_date` (Date). Typically the output of
    \[ingest_sentinel2_timeseries()\] or a query against `obs_pixel`.
  - `cache_dir` — root of the STAC COG cache, where
    `<cache_dir>/<safe_scene_id>/<band>.tif` files live. Local hrefs
    avoid PC SAS expiry during long `fit()` runs.
- `forest_mask` is deprecated and ignored. fordead 2.x handles cloud /
  shadow / soil masks via `FordeadConfig` defaults, which per ADR-013
  §G5 already match the ONF/DSF calibration. A
  [`cli::cli_alert_warning`](https://cli.r-lib.org/reference/cli_alert.html)
  fires when a non-`NULL` value is passed.
- All other arguments unchanged.

**Internal restructure** :

- New `R/fordead_stac.R` (session 1, commit 4bf0a0a) :
  - [`.aoi_bbox_4326()`](https://pobsteta.github.io/nemeton/reference/dot-aoi_bbox_4326.md)
    — WGS-84 bbox for `FordeadProcess(bbox=...)`.
  - [`.aoi_geometry_reticulate()`](https://pobsteta.github.io/nemeton/reference/dot-aoi_geometry_reticulate.md)
    — shapely geometry via WKT.
  - [`.aoi_geojson_list()`](https://pobsteta.github.io/nemeton/reference/dot-aoi_geojson_list.md)
    — GeoJSON dict for `pystac.Item.geometry`.
  - [`.build_fordead_config()`](https://pobsteta.github.io/nemeton/reference/dot-build_fordead_config.md)
    — `FordeadConfig` with the 4 R-exposed knobs overridden, rest =
    ADR-013-matching defaults.
  - [`.build_stac_collection_for_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-build_stac_collection_for_aoi.md)
    — walks `scenes_df` + cache, skips scenes missing required bands
    with one aggregated warning, builds `simplestac.ItemCollection`.
- New `R/fordead_outputs.R` (session 2, commit ef2d072) :
  - [`.list_layer_files()`](https://pobsteta.github.io/nemeton/reference/dot-list_layer_files.md)
    /
    [`.latest_layer_file()`](https://pobsteta.github.io/nemeton/reference/dot-latest_layer_file.md)
    — locate `<output_dir>/<LAYER>/fordead_<YYYYMMDD>_<LAYER>.tif`.
  - [`.compute_first_dieback_date()`](https://pobsteta.github.io/nemeton/reference/dot-compute_first_dieback_date.md)
    — stack `ANOMALY_CONFIRMED` and call
    `fordead.utils.backward_start()`.
  - [`.fordead_2x_status_to_classes()`](https://pobsteta.github.io/nemeton/reference/dot-fordead_2x_status_to_classes.md)
    — derive the 0-4 class raster from `ANOMALY_CONFIRMED` +
    `CONSECUTIVE_DETECTIONS` + `STOP_CONFIRMED`. Thresholds match spec
    008 §12.4 mapping table.
- [`.postprocess_fordead_rasters()`](https://pobsteta.github.io/nemeton/reference/dot-postprocess_fordead_rasters.md)
  is **unchanged**. The input shape (named list with `state`,
  `stress_index`, `first_dieback_date`) is preserved — the pipeline
  builds it from the 2.x layers. Guarantees AC.12.4 (R5 tests stay
  green).

**Phase progress callback** (compatibility note) :

The 5 phase names in `progress_callback` events have changed from the
1.x theoretical list (`vegetation_index`, `train_model`, `forest_mask`,
`dieback_detection`, `export_results`, `postprocess`, `persist`) to the
2.x mapping : - `stac_assembly` — STAC ItemCollection + bbox/geom/config
build. - `fit` — `FordeadProcess.fit()` (umbrella). - `predict` —
`FordeadProcess.predict()` (umbrella). - `postprocess` —
[`.postprocess_fordead_rasters()`](https://pobsteta.github.io/nemeton/reference/dot-postprocess_fordead_rasters.md)
(unchanged). - `persist` —
[`.insert_fordead_alerts()`](https://pobsteta.github.io/nemeton/reference/dot-insert_fordead_alerts.md)
(optional, when `con` + `zone_id`).

`nemetonshiny@v0.32.0` (released 2026-05-16) anticipated this with a
generic phase-name lookup design, so the app needs no rewiring.

**Python dependencies** :

- `inst/python/requirements.txt` :
  - `fordead @ git+https://gitlab.com/fordead/fordead_package@v2.1.1`
    (was `@v1.11.4`)
  - `simplestac @ git+https://forge.inrae.fr/umr-tetis/stac/simplestac@v1.2.5`
    added explicitly (transitive dep of fordead 2.x).
- `R/fordead_python.R` version-aware reinstall logic (v0.22.5) detects
  the pin change and triggers `pip install --upgrade` on the next
  [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  call.

**Tests** :

- `test-fordead-pipeline.R` refactored : 16 offline tests with mocks for
  `fd$workflow$FordeadProcess` + helpers via
  `testthat::local_mocked_bindings(!!!, .package = "nemeton")`. Covers 8
  validations (2 new : `scenes_df`, `cache_dir`), 4 orchestration paths,
  1 `.empty_fordead_result` shape.
- `test-fordead-stac.R` (session 1) : 16 offline tests for the new STAC
  helpers + FordeadConfig builder.
- `test-fordead-outputs.R` (session 2) : 11 tests — 6 without terra
  (`.list_layer_files`, `.latest_layer_file`) + 5 with terra
  (`.fordead_2x_status_to_classes` mapping + STOP + NA-255).
- `test-fordead-integration.R` (NEW, session 3) : 2 opt-in tests guarded
  by `skip_if_no_fordead_integration()` (requires
  `NEMETON_FORDEAD_INTEGRATION=TRUE` + a real cache + AOI fixture). Plan
  008 §9.4 AC.12.3.

**Migration notes for users on `v0.21.0..v0.22.5`** :

- Update your code to pass `scenes_df` and `cache_dir`:

  ``` r

  res <- run_fordead_dieback(
    aoi              = aoi,
    scenes_df        = scenes_df,  # NEW (required)
    cache_dir        = cache_dir,  # NEW (required)
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", as.character(Sys.Date()))
  )
  ```

- The next call automatically replaces the in-venv fordead 1.x with 2.x
  (version-aware reinstall, no manual `virtualenv_remove`).

- Remove any `forest_mask = ...` arguments — they’re now ignored.

**Known limitation / deferred work** :

- The thresholds in `.fordead_2x_status_to_classes` (`>=3, >=6, >=10`)
  are placeholders from spec 008 §12.4. They need empirical
  recalibration against a real FORDEAD run on a validated zone (AC.12.3
  part 2). Tracked as a follow-up patch.
- `test-fordead-integration.R` skip-by-default. Run locally with
  `NEMETON_FORDEAD_INTEGRATION=TRUE` + a populated cache + AOI to
  exercise the end-to-end path.

------------------------------------------------------------------------

## nemeton 0.22.5 (2026-05-16)

#### Fixed — `module 'fordead' has no attribute 'steps'` after v0.22.2..v0.22.4

After the install/discovery fixes of v0.22.2..v0.22.4, the FORDEAD
pipeline finally started — and immediately failed at the first
substantive step :

    ℹ Step: compute_masked_vegetationindex
    ✖ FORDEAD pipeline failed: AttributeError: module 'fordead' has no attribute 'steps'

Cause : **fordead 2.x is a complete API rewrite**. The 1.x pipeline
exposed `fordead.steps.step1_compute_masked_vegetationindex`,
`step2_train_model`, `step3_dieback_detection`, `step5_export_results`
as importable submodules — and that’s exactly the API
`R/fordead_pipeline.R` was written against. fordead 2.x dropped that in
favour of a single `fordead.workflow.FordeadProcess` class with methods
like `compute_spectral_index`, `fit`, `predict`, `anomaly_detection`,
etc. The pin `@v2.1.1` introduced in v0.22.2 crossed that boundary
silently because the spec said “fordead 2.x” without verification.

**Fix**: pin downgraded to **`v1.11.4`** (last 1.x release, 2025-08-13).
Verified : `fordead/steps/` at v1.11.4 contains exactly the 5 step files
our pipeline imports.

#### Fixed — pin downgrade required re-install detection

A user already running v0.22.2..v0.22.4 has a venv with `fordead 2.1.1`
installed. After the pin downgrade to `1.11.4`, the previous
[`.fordead_is_installed()`](https://pobsteta.github.io/nemeton/reference/dot-fordead_is_installed.md)
only checked importability — it would have returned TRUE for the
wrong-API 2.1.1 install and skipped the upgrade. The pipeline would have
stayed broken.

[`.fordead_is_installed()`](https://pobsteta.github.io/nemeton/reference/dot-fordead_is_installed.md)
now takes an optional `requirements_path` argument and compares the
installed version against the pin. Two new private helpers :

- `.fordead_version_pinned(req_path)` — parses
  `fordead @ git+...@vX.Y.Z` or `fordead==X.Y.Z` from
  `requirements.txt`.
- `.fordead_python_version(env_name)` — runs
  `<venv>/python -c "import fordead; print(fordead.version)"`.

On version mismatch the helper emits a clear
[`cli::cli_alert_warning`](https://cli.r-lib.org/reference/cli_alert.html)
and returns FALSE, which makes
[`.ensure_fordead_python()`](https://pobsteta.github.io/nemeton/reference/dot-ensure_fordead_python.md)
re-run `pip install --upgrade -r requirements.txt`. pip then sees the
new URL pin and reinstalls fordead at the correct version.

#### Migration tracked

Migrating `R/fordead_pipeline.R` to the fordead 2.x `FordeadProcess`
class API is a future epic — spec 008 §3 / plan 008 §2 will need rework,
plus an ADR-013 amendment. Logged as backlog in `PLAN.md`.

#### Tests

- 5 new tests in `test-fordead-python.R` covering version parsing and
  the new `.fordead_is_installed(requirements_path)` branch:
  - `.fordead_version_pinned` parses git URL pin
  - `.fordead_version_pinned` parses PyPI-style pin
  - `.fordead_version_pinned` returns NA when nothing matches
  - `.fordead_is_installed` flags a version mismatch as not-installed
  - `.fordead_is_installed` accepts a matching version
- 2 existing `.fordead_is_installed` mocks updated to accept the new
  `requirements_path = NULL` argument.

------------------------------------------------------------------------

## nemeton 0.22.4 (2026-05-16)

#### Fixed — FORDEAD pre-check failed when `RETICULATE_PYTHON` was just unset

After applying the recovery procedure from v0.22.3 (unset
`RETICULATE_PYTHON`, restart R), some users hit a new pre-check failure
:

    ✖ FORDEAD pipeline failed: No Python interpreter found.
    ℹ FORDEAD requires Python ">= 3.10".

Cause :
[`reticulate::py_discover_config()`](https://rstudio.github.io/reticulate/reference/py_discover_config.html)
can return `NULL` even when `Sys.which("python3.12")` clearly resolves
to a valid interpreter. reticulate’s discovery relies on a small set of
heuristics (env var, pinned config, well-known venv locations) and isn’t
a guarantee that the system has no Python. We were treating “reticulate
doesn’t know” as “Python is not installed”.

**Fix**:
[`.assert_fordead_system()`](https://pobsteta.github.io/nemeton/reference/dot-assert_fordead_system.md)
now falls back to direct PATH probing when reticulate returns nothing.
The new private helper
[`.find_python_on_path()`](https://pobsteta.github.io/nemeton/reference/dot-find_python_on_path.md)
walks a list of conventional Python binary names from newest to oldest
(`python3.14` → `python3.13` → … → `python3.10` → `python3` → `python`)
and returns the first one whose `--version` reports ≥ 3.10. Companion
helper
[`.probe_python_version()`](https://pobsteta.github.io/nemeton/reference/dot-probe_python_version.md)
parses the `<py> --version` output.

This means the FORDEAD pipeline no longer requires `RETICULATE_PYTHON`
to be set or reticulate’s config to be primed beforehand. If any Python
≥ 3.10 is reachable on PATH, FORDEAD can build its venv from it.

#### Tests

- 6 new tests in `test-fordead-python.R` covering the fallback path :
  - `.probe_python_version` parses `--version` from a real interpreter
    (skipped if none on PATH)
  - `.probe_python_version` returns NA on an unreachable binary
  - `.find_python_on_path` returns a 3.10+ binary when available
  - `.find_python_on_path` returns `""` when no candidate matches
    (`Sys.which` mocked to always return empty)
  - `.assert_fordead_system` falls back to PATH when
    `py_discover_config` is `NULL`
  - `.assert_fordead_system` errors when both reticulate AND PATH yield
    nothing
- The existing test “aborts when no Python is found” now mocks
  `.find_python_on_path` too, otherwise the runner’s real Python would
  defeat the assertion.

------------------------------------------------------------------------

## nemeton 0.22.3 (2026-05-16)

#### Fixed — `RETICULATE_PYTHON` silently shadowed the FORDEAD virtualenv

After the v0.22.2 install fix, FORDEAD could still fail at runtime on
machines where `RETICULATE_PYTHON` was set in `.Renviron` /
`Renviron.site` for another project (typically conda envs for OpenCanopy
CHM work, spec 005). Symptom :

    Avis : The request to `use_python("...nemeton-fordead/bin/python")`
    will be ignored because the environment variable RETICULATE_PYTHON
    is set to "...miniforge3/envs/open_canopy/bin/python"
    ✖ FORDEAD pipeline failed: ModuleNotFoundError: No module named 'fordead'

reticulate’s `use_virtualenv()` / `use_python(..., required = TRUE)`
defer to `RETICULATE_PYTHON` at init time even with `required = TRUE`.
Install succeeded into the FORDEAD venv, but `import("fordead")` then
ran against the conflicting (`open_canopy`) interpreter where fordead is
absent.

**Fix**:
[`.use_fordead_env()`](https://pobsteta.github.io/nemeton/reference/dot-use_fordead_env.md)
now detects this conflict :

- If Python is **not yet initialised**, the env var is temporarily
  masked for the duration of `use_virtualenv()`. It’s restored
  immediately afterwards via
  [`on.exit()`](https://rdrr.io/r/base/on.exit.html) so other reticulate
  consumers in the session (OpenCanopy CHM) still see their config.
  reticulate’s cached binding stays on the FORDEAD env for the rest of
  the session.
- If Python is **already initialised** to a different binary, the switch
  is impossible (reticulate caches the binding once Python is up). An
  actionable error tells the user to `Sys.unsetenv("RETICULATE_PYTHON")`
  and restart R.

Helper
[`.same_path()`](https://pobsteta.github.io/nemeton/reference/dot-same_path.md)
added for symlink/trailing-slash-tolerant path comparison.

#### Tests

- 3 new regression tests on the conflict logic : conflict-masking path,
  already-bound error path, no-conflict no-op path.
- 1 test on
  [`.same_path()`](https://pobsteta.github.io/nemeton/reference/dot-same_path.md)
  (normalisation + empty-string edge case).
- Existing `.ensure_fordead_python` tests now
  [`withr::local_envvar`](https://withr.r-lib.org/reference/with_envvar.html)
  RETICULATE_PYTHON to keep them hermetic and add a `virtualenv_python`
  mock.

------------------------------------------------------------------------

## nemeton 0.22.2 (2026-05-15)

#### Fixed — FORDEAD install failed because `fordead` is not on PyPI

The pinned dependency `fordead==2.1.4` in `inst/python/requirements.txt`
made `pip install -r requirements.txt` fail with:

    ERROR: Could not find a version that satisfies the requirement fordead==2.1.4
    ERROR: No matching distribution found for fordead==2.1.4

Two problems compounded:

1.  **`fordead` is not published on PyPI** at all (verified: HTTP 404 on
    `https://pypi.org/simple/fordead/`). The official install method per
    the INRAE docs is
    `pip install git+https://gitlab.com/fordead/fordead_package`.
2.  **Version `2.1.4` does not exist**. The latest tag on GitLab is
    `v2.1.1` (2026-02-04); the pin was written aspirationally without
    verification when spec 008 was drafted.

**Fix**: `inst/python/requirements.txt` now uses a PEP 508 URL pin:

    fordead @ git+https://gitlab.com/fordead/fordead_package@v2.1.1

#### Fixed — `.ensure_fordead_python()` could not recover from a half-installed venv

Independently of the requirements bug above,
[`.ensure_fordead_python()`](https://pobsteta.github.io/nemeton/reference/dot-ensure_fordead_python.md)
in `R/fordead_python.R` only ran `virtualenv_install` when the venv
**did not** exist. When `pip install` failed mid-way (transient network
failure, broken pin, etc.) the venv had been created with the base deps
(pip, wheel, setuptools, numpy) but without `fordead` itself. Subsequent
calls saw `virtualenv_exists() == TRUE`, skipped the install, then
exploded at `reticulate::import("fordead")` with no recovery path — the
user had to run `reticulate::virtualenv_remove("nemeton-fordead")` by
hand.

**Fix**: two new private helpers in `R/fordead_python.R`:

- `.fordead_python_import_ok(py_path, module)` — runs
  `<py_path> -c "import <module>"` via
  [`system2()`](https://rdrr.io/r/base/system2.html), returns the exit
  code as a logical. Test-friendly: it’s a one-liner around `system2`
  that mocks easily.
- `.fordead_is_installed(env_name)` — resolves the venv’s Python
  interpreter via
  [`reticulate::virtualenv_python()`](https://rstudio.github.io/reticulate/reference/virtualenv-tools.html),
  returns `FALSE` if it’s absent or if `fordead` can’t be imported.

[`.ensure_fordead_python()`](https://pobsteta.github.io/nemeton/reference/dot-ensure_fordead_python.md)
now calls
[`.fordead_is_installed()`](https://pobsteta.github.io/nemeton/reference/dot-fordead_is_installed.md)
when the venv already exists. If `fordead` is missing, it emits a
warning toast and re-runs `virtualenv_install` instead of plowing ahead.
The user no longer has to remove the venv manually after a failed first
install.

#### Migration notes for users who hit the bug before this release

If you tried to run FORDEAD against v0.22.1 (or earlier) and saw
`No matching distribution found for fordead==2.1.4`, your virtualenv is
in a half-installed state. After upgrading to v0.22.2 the recovery is
automatic — the next call to
[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
will detect the missing `fordead` and reinstall from the correct source.
If you prefer a clean slate, you can still do:

``` r

reticulate::virtualenv_remove("nemeton-fordead")
```

#### Tests

- Updated `.fordead_requirements_path resolves the shipped requirements`
  to match the new URL-pin format.
- Updated
  `.ensure_fordead_python skips create when the venv already exists` to
  mock `.fordead_is_installed = TRUE` (healthy venv path).
- New:
  `.ensure_fordead_python reinstalls when fordead is missing from existing venv`
  — covers the recovery path.
- New: 2 tests on `.fordead_is_installed` (absent Python binary; import
  probe TRUE/FALSE).

#### Internal

- spec 008 §1.3 / plan 008 §1.3 docstrings updated to reflect the
  git-based install. ADR-013 left unchanged (it doesn’t quote the pin).

------------------------------------------------------------------------

## nemeton 0.22.1 (2026-05-15)

#### Fixed — Sentinel-2 ingestion above 30 min triggered an avoidable 403 per remaining band

[`stac_search_s2_pc()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
signs every COG href with a SAS token at search time and bakes them into
`scenes_df`. On a long ingestion run, by the time the loop reaches scene
N the token embedded in the hrefs has expired (Planetary Computer SAS
tokens last ~30 min). The reactive recovery in
`.terra_rast_with_pc_retry()` (added in v0.21.6) caught each 403
individually:

    Scene 1..8   → tokens still fresh → OK
    Scene 9..26  → 403 → invalidate cache → resign href → retry → OK

Every band of every late scene paid one extra HTTP round-trip (~300 ms
each) plus a noisy `s2:pc_token_refreshed` event. On a typical 26-scene
× 3-band run crossing the 30 min mark, that’s ~50 wasted requests and
~15 s of latency.

**Fix**: two new private helpers in `R/sentinel2.R`:

- `.pc_href_expires_at(href)` — parses the SAS `se=` query parameter,
  returns a `POSIXct` (UTC) or `NA` if absent / unparseable.
- `.pc_ensure_fresh_href(href, collection, grace_seconds = 60)` — no-op
  on non-PC URLs and on hrefs whose `se=` is comfortably in the future;
  otherwise calls `.pc_resign_href()` to swap in a freshly-fetched
  token. Falls back to the original href if the token endpoint itself is
  down (the reactive retry then takes over as a safety net).

Wired into `.get_s2_band_raster()` (R/monitoring.R) immediately before
the `FETCH href=` trace, so every band lookup gets a last-second
freshness check.

Effect on a 45-minute run: zero `s2:pc_token_refreshed` events (except
in genuine clock-skew situations), no warnings to spread across the
worker console, no measurable extra HTTP cost (the proactive check is
one regex parse + one
[`Sys.time()`](https://rdrr.io/r/base/Sys.time.html) comparison,
sub-microsecond).

6 new offline tests in `test-sentinel2.R` covering: parser on valid /
missing / NA / NULL hrefs, no-op on non-PC and unsigned URLs, no-op when
the token is still fresh, resign when within grace, fallback when resign
returns NULL.

## nemeton 0.22.0 (2026-05-15)

#### Added — per-pixel Sentinel-2 readers and pixel time-series extraction

Four new exported functions exposing the on-disk Sentinel-2 cache
(`<cache_dir>/{scene_id}/{B04,B08,B12}.tif`, written since v0.21.4 and
functional since v0.21.12) as
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
objects:

- **`read_s2_band_raster(cache_dir, scene_id, band)`** — single band
  reader, returns a 1-layer SpatRaster or `NULL` if the file is missing.
- **`read_s2_band_stack(cache_dir, scenes_df, band)`** — multi-temporal
  stack for one band (B04 / B08 / B12), layers named by `obs_date`,
  [`terra::time()`](https://rspatial.github.io/terra/reference/time.html)
  attribute set. Missing scenes skipped silently with a single
  aggregated warning.
- **`build_index_stack(cache_dir, scenes_df, index = c("NDVI", "NBR"))`**
  — computes NDVI or NBR pixel-wise on each scene, returns a 10 m stack.
  For NBR, B12 (20 m natively) is resampled bilinearly onto the B08 10 m
  grid — same idiom as `.extract_scene_obs` so per-pixel NBR is
  numerically consistent with the per-plot NBR aggregates in
  `obs_pixel`. Carries an `"index"` attribute identifying the chosen
  index.
- **`extract_pixel_timeseries(cache_dir, scenes_df, xy, crs = 4326, indices = c("NDVI", "NBR"))`**
  — per-pixel time series at a clicked point. `xy` defaults to WGS84
  (the convention of leaflet `input$map_click`), reprojected per scene
  to its native S2 CRS. Missing scenes produce a row with `value = NA`
  at that date (the temporal hole is preserved for plotly display), not
  silently skipped. NBR uses native 20 m B12 here (no resample), because
  for a single-point lookup the pixel containing the click is what the
  user wants — this differs from
  [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  by a sub-pixel amount, documented in both man pages.

Implements **spec 010** (`specs/010-carte-pixel-timeseries/`). The
intended consumer is a new “Carte pixel” sub-tab under “Suivi sanitaire”
in `nemetonshiny` — leaflet shows the index stack with a date slider,
click on a pixel calls
[`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md)
and renders a plotly. No DB schema change (the on-disk cache is the
source of truth), no new dependency (everything via `terra`, `sf`,
`cli`, `rlang` already in Imports).

#### Internal

`R/monitoring.R`: extracted the scene_id sanitization rule
(`gsub("[^A-Za-z0-9._-]", "_", ...)`) from `.s2_band_cache_path()` into
a shared private helper `.s2_safe_scene_id()` so the new readers in
`R/pixel-map.R` resolve the same on-disk layout the write path computes.
No behaviour change.

#### Tests

16 new offline tests in `tests/testthat/test-pixel-map.R` covering input
validation, file-absent NULL semantics, scene ordering by date,
aggregated-warning skip policy, NDVI / NBR formula correctness on
fixed-value fixtures, NA propagation, B12 resampling, CRS transform from
4326 to L93, multi-index sort order, point-outside-AOI all-NA rows, and
incomplete-scene NA-row policy. Synthetic fixtures build valid GeoTIFFs
in temp dirs — zero network, zero DB.

## nemeton 0.21.12 (2026-05-15)

#### Fixed — S2 band cache never populated because `writeRaster` couldn’t guess driver

The disk-side persistence of cropped Sentinel-2 bands (added in v0.21.4
and progressively hardened up to v0.21.10) silently failed on every
scene with recent terra versions:

    [writeRaster] cannot guess file type from filename

Root cause: the temp file is named `<cached_path>.tmp` — i.e.
`<scene_id>/B04.tif.tmp`.
[`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html)
infers the GDAL driver from the filename extension, and `.tmp` isn’t a
known GIS alias. On older terra the inference was looser and the write
succeeded; on recent terra it’s strict and the write throws. The
`tryCatch` around `writeRaster` swallowed the error, unlinked the
partial `.tmp`, emitted a
[`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html), and
(since v0.21.10) cleaned up the empty `scene_dir` — making the failure
*less* visible because no orphan directory was left to flag the issue.

Net effect since v0.21.4: **the cache was never populated**, every
ingestion re-downloaded all bands via VSI even when `cache_dir` was
passed.

Fix (R/monitoring.R): pass `filetype = "GTiff"` explicitly to
[`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html).
The GDAL creation options
(`TILED=YES, COMPRESS=DEFLATE, BLOCKXSIZE=256, BLOCKYSIZE=256, PREDICTOR=2`)
were already GeoTIFF-specific, so this just makes the driver selection
explicit instead of relying on extension inference.

New regression test
`.get_s2_band_raster: writeRaster is called with filetype = 'GTiff'`
(test-monitoring.R) — captures the call via a delegating mock so it
catches a future regression even on a lax terra version.

Surfaced during in-prod validation of v0.21.10’s `FETCH+MATERIALIZE` +
scene_dir cleanup logic. v0.21.10’s defense-in- depth cleanup is what
made the underlying bug visible: with the orphan dirs gone, the only
remaining symptom was an empty cache, and the verbose trace (v0.21.7)
pointed straight at the writeRaster line.

## nemeton 0.21.11 (2026-05-15)

#### Added — `read_obs_pixel()` exported reader for the obs_pixel hypertable

New exported function
`read_obs_pixel(con, zone_id, plot_ids = NULL, bands = NULL, date_from = NULL, date_to = NULL)`
returns the per-plot × per-band × per-date Sentinel-2 observations as a
`data.frame`. The plot identifier is surfaced as the human-readable
`plot.plot_id` (TEXT), not the internal `plot.id` (INTEGER FK), via a
JOIN — so downstream consumers (Shiny `selectInput`, Quarto reports,
GeoPackage exports) refer to plots by the code the user knows.

Filters are all optional and AND-combined; `NULL` means no filter on
that dimension. Output is deterministically sorted by
`(plot_id, obs_date, band)`, types are coerced (`obs_date → Date`,
numerics forced double), and an empty `data.frame` with the right column
schema is returned for an empty / unknown zone.

This is the read-side counterpart of the (private) write path
`.insert_obs_pixel()`. Exposing it as part of the public API keeps the
`obs_pixel` SQL out of `nemetonshiny` (per the *no business logic in the
app* rule) and unblocks E6.b phase 3 (per-plot NDVI / NBR plotly time
series in `mod_monitoring`).

13 new tests in `test-read_obs_pixel.R`: 6 offline (argument
validation + empty-shape contract), 4 integration via `with_clean_db`
(empty / unknown zone, full read, every filter combination, sibling zone
isolation).

## nemeton 0.21.10 (2026-05-15)

#### Fixed — S2 cache leaves empty `<cache_dir>/{scene_id}/` directories

`ingest_sentinel2_timeseries(..., cache_dir = ...)` created scene
subdirectories under `<cache_dir>/` without any `B04.tif` / `B08.tif`
files inside.

Root cause: `terra::rast(href)` on a VSI URL only fetches the COG
**header** — pixel reads are deferred until something consumes the
SpatRaster (typically
[`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html)).
The retry/auth-refresh helper `.terra_rast_with_pc_retry()` (v0.21.6 →
v0.21.9) wrapped **only the head request**, so:

1.  `terra::rast(href)` succeeds → metadata in hand.
2.  `terra::crop(r, ext)` is also lazy → still no bytes downloaded.
3.  `dir.create(<cache_dir>/{scene_id}/)` succeeds → directory exists.
4.  `terra::writeRaster(r, tmp, …)` finally triggers the byte-range
    reads on the COG over VSI. If the SAS token expired mid-scene, or
    Azure returned a 5xx / 429 on the range request, this step throws —
    **past the retry budget**.
5.  The `tryCatch` swallowed the error with a
    [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html),
    unlinked the partial `.tmp`, and returned — leaving the empty scene
    directory behind.

The fix moves the AOI crop **and** the pixel materialization into a
`materialize` closure passed to `.terra_rast_with_pc_retry()`. Both
steps now run **inside** the retry/refresh loop:

``` r

materialize = function(r0) {
  buf_native <- sf::st_transform(buf_plots, terra::crs(r0))
  r_cropped  <- terra::crop(r0, terra::ext(terra::vect(buf_native)),
                            snap = "out")
  r_cropped + 0   # forces in-memory pixel read via terra arithmetic
}
```

`r_cropped + 0` is the canonical terra idiom for “make this SpatRaster
in-memory”: scalar arithmetic creates a new SpatRaster whose values are
read into RAM. Any VSI failure (auth expiry, transient 5xx, DNS hiccup
mid-stream) surfaces inside the loop and triggers re-sign / exponential
backoff just like a metadata failure would. The downstream
[`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html)
then writes from RAM — no more VSI traffic — so the only way it can fail
is local disk I/O.

Defensive cleanup: if
[`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html)
still fails for a genuinely local reason (disk full, permission denied,
GDAL driver hiccup) AFTER
[`dir.create()`](https://rdrr.io/r/base/files2.html), the now-empty
`scene_dir` is removed in the `tryCatch` so
[`diagnose_s2_cache()`](https://pobsteta.github.io/nemeton/reference/diagnose_s2_cache.md)
doesn’t keep flagging it as an empty entry. Sibling-band files (a
previous successful B04 when B08 fails) are left untouched — partial
caches are preserved.

Three new tests:

- `.terra_rast_with_pc_retry: materialize closure runs once on success`
- `.terra_rast_with_pc_retry: materialize failure with PC auth → token refresh + retry`
- `.terra_rast_with_pc_retry: materialize failure with transient error → backoff retry`
- `.get_s2_band_raster: empty scene_dir is removed when writeRaster fails`

## nemeton 0.21.9 (2026-05-13)

#### Fixed — transient DNS / network errors abort entire scenes

`.terra_rast_with_pc_retry()` used to retry **only** on PC SAS 401/403.
Any other failure — including DNS hiccups (`Could not resolve host: …`),
connection timeouts, and GDAL HTTP 5xx — propagated immediately, the
scene was skipped, and the ingestion lost data for what was usually a
5-30 second blip.

The retry path now classifies the error and reacts accordingly:

- **PC SAS auth** (`40[13]`, `forbidden`, `unauthorized`) on a PC blob
  URL → invalidate cached token, re-sign href, retry immediately.
  *(Behaviour preserved from v0.21.6.)*
- **Transient network** (`could not resolve host`, `could not connect`,
  `connection (timed out|reset|refused)`, `network unreachable`,
  `temporary failure`, `http error 5xx`, `gdal error … timeout`) → sleep
  with exponential backoff (2 s, 4 s, 8 s, …, capped at 30 s) and retry
  the same href.
- **Anything else** (404, malformed COG, permission denied) propagates
  immediately as before.

Total budget is **3 attempts** per band by default; override with the
env var `NEMETON_S2_MAX_TRIES` (positive integer).

A new progress event `s2:band_fetch_retry` is emitted before each sleep,
with payload `scene_id`, `band`, `attempt`, `max_tries`, `retry_in_sec`,
`error_message`. Callers (`nemetonshiny`) can render it as a toast like
*“Hoquet réseau sur scène X bande B04 — réessai dans 4 s”* so the user
sees the pipeline is recovering, not stuck.

## nemeton 0.21.8 (2026-05-13)

#### Fixed — every S2 band cache hit raised “cannot coerce type ‘S4’ to vector of type ‘double’”

`.ext_contains()` (introduced in v0.21.4 to decide whether a cached COG
covers today’s AOI) did:

``` r

o <- as.numeric(c(outer[1], outer[2], outer[3], outer[4]))
```

`outer` is a
[`terra::SpatExtent`](https://rspatial.github.io/terra/reference/SpatExtent-class.html)
(S4). `outer[1]` does NOT return a plain double — it returns a nested S4
element. [`c()`](https://rdrr.io/r/base/c.html) accumulates those into
an S4 list, and [`as.numeric()`](https://rdrr.io/r/base/numeric.html)
then chokes with

    cannot coerce type 'S4' to vector of type 'double'

Symptom for the user: every scene that already had a cached band on disk
got skipped at the scene level

    Scene "S2A_MSIL2A_20250712T104041_R008..." skipped:
      cannot coerce type 'S4' to vector of type 'double'

— so the cache never got reused, the network was hit again, and
ingestion looked like nothing was making progress.

- New private helper `.ext_as_numeric(e)` routes `SpatExtent` through
  `terra::xmin()/xmax()/ymin()/ymax()`, falls back to
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html) for plain
  numeric vectors. Bulletproof across terra versions.
- `.ext_contains()` and the verbose `.s2_cache_log()` debug call both go
  through the new helper.

2 new regression tests exercise `.ext_contains()` with real
[`terra::ext()`](https://rspatial.github.io/terra/reference/ext.html)
objects (mixed S4 / numeric combinations).

## nemeton 0.21.7 (2026-05-13)

#### Added — observability for the S2 band cache

Three additions to make it easy to answer “why is no `.tif` landing in
`cache/layers/sentinel2/`”:

1.  **Always-on cache status banner** at the top of every
    [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
    call:

        i S2 band cache: enabled at <project>/cache/layers/sentinel2

    …or the unmissable inverse when the wiring is wrong:

        i S2 band cache: DISABLED (cache_dir is NULL or empty).

    Catches the most common bug — `cache_dir` not actually being passed
    by the caller — at the very first line of output instead of after 30
    minutes of silent ingestion.

2.  **Verbose tracer** gated by `NEMETON_S2_CACHE_DEBUG=TRUE` (or `=1`).
    When enabled, `.get_s2_band_raster()` writes one
    [`message()`](https://rdrr.io/r/base/message.html) line per decision
    point: ENTER, CACHE-HIT/MISS/STALE, FETCH (with href), CROP, WRITE
    preparing dir, WRITE writeRaster target + size, RENAME, or any error
    along the way. Off by default to keep regular runs quiet. Use
    [`message()`](https://rdrr.io/r/base/message.html) (not `cli`) so
    the trace is captured by `future_promise` worker logs.

3.  **`diagnose_s2_cache(cache_dir)`** — new exported helper that walks
    the cache and reports populated vs empty scene directories, total
    bytes, mean bands per scene, and the list of empty dirs. Returns the
    result list invisibly so callers can script cleanups
    (`unlink(diagnose_s2_cache(...)$empty_dirs, recursive = TRUE)`).

#### Fixed — write permission failures now produce a clear warning

When `dir.create(scene_dir)` silently fails (Windows permission issue,
antivirus quarantine, network drive), `.get_s2_band_raster()` now emits
`S2 band cache: cannot create <path>. Check write permissions.` and
skips the write — instead of silently dropping into
[`terra::writeRaster`](https://rspatial.github.io/terra/reference/writeRaster.html)
and surfacing a cryptic GDAL error.

## nemeton 0.21.6 (2026-05-13)

#### Fixed — empty `cache/layers/sentinel2/{scene_id}/` dirs after failed fetches

In v0.21.4 `.get_s2_band_raster()` created the per-scene cache directory
eagerly at function entry, *before* attempting the VSI fetch. If
`terra::rast(href)` then raised (typical causes: PC SAS token expired
mid-ingestion → HTTP 403, Azure 504, Sentinel-2 COG moved), the scene
directory was already on disk while no `B04.tif` / `B08.tif` / `B12.tif`
was ever written. Users saw hundreds of empty scene folders with no
obvious cause.

- Directory creation is now **deferred** to the moment immediately
  preceding
  [`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html).
  A scene whose bands cannot be opened no longer leaves a phantom folder
  behind.
- Two new progress events let callers (e.g. `nemetonshiny`) surface the
  actual failure cleanly:
  - `s2:band_fetch_failed` — emitted when `terra::rast(href)` is
    unrecoverable (after PC-token-refresh path if applicable). Payload:
    `scene_id`, `band`, `href`, `error_message`.
  - `s2:pc_token_refreshed` — emitted when an initial 403/401 on a
    Planetary Computer blob URL triggered a successful token refresh +
    retry. Payload: `scene_id`, `band`, `collection`.

#### Added — auto-refresh of Planetary Computer SAS tokens on 403/401

The previous design signed every href at STAC search time and relied on
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
reading them later. PC SAS tokens last ~30 min, so any ingestion that
ran longer than that started hitting HTTP 403 on the last scenes’ bands.

`.get_s2_band_raster()` now wraps each `terra::rast(href)` in
`.terra_rast_with_pc_retry()`:

1.  First call goes through as-is.
2.  On failure, the error message is sniffed: when the href is a PC blob
    URL (`*.blob.core.windows.net` with a `sig=…` query) *and* the error
    matches `\\b(40[13]|forbidden|unauthorized |authentication)\\b`, the
    cached SAS token for `sentinel-2-l2a` is invalidated, the href is
    re-signed with a fresh token, and the open is retried exactly once.
3.  Anything else (504, network, malformed COG, non-PC URL) propagates
    immediately — no point spending a token round-trip.

Two new internal helpers back the retry path:

- `.pc_invalidate_token(collection)` — drops one collection’s cached
  token so the next fetch hits `/api/sas/v1/token/…`.
- `.pc_resign_href(href, collection)` — strips the current SAS query
  string and applies a freshly-fetched one (returns `NULL` when the
  token refresh itself failed).

10 new tests cover the lazy creation, the retry happy/sad paths, the
non-PC short-circuit, and the helper-level behaviours.

## nemeton 0.21.5 (2026-05-13)

#### Fixed — transient STAC failures (HTTP 504/503/502) no longer abort the search

[`stac_search_s2()`](https://pobsteta.github.io/nemeton/reference/stac_search_s2.md)
(and its CDSE / Planetary Computer implementations) now retry on
transient HTTP errors before giving up:

- Retried status codes: **429, 500, 502, 503, 504**. The default `httr2`
  policy only retries on 429 + 503, which left genuine Planetary
  Computer 504 Gateway Timeouts surfaced immediately as toasts in
  `nemetonshiny`.
- Default budget: 4 attempts per backend (≈ 14 s of cumulative
  exponential backoff in the worst case: 2 + 4 + 8 s between attempts,
  capped at 60 s).
- Override via `NEMETON_STAC_MAX_TRIES` (integer env var).

When every configured backend exhausts its retry budget,
[`stac_search_s2()`](https://pobsteta.github.io/nemeton/reference/stac_search_s2.md)
now emits a single aggregated warning — in addition to the per-backend
warnings — so the UI can render one toast instead of stacking one per
backend.

The retry policy is also applied to the Planetary Computer SAS token
fetch (`/api/sas/v1/token/{collection}`) and the legacy per-href sign
endpoint (`/api/sas/v1/sign`), so a transient PC hiccup during the auth
round-trip no longer falls back to unsigned URLs (which Azure would then
409).

## nemeton 0.21.4 (2026-05-12)

#### Added — on-disk COG band cache for `ingest_sentinel2_timeseries()`

[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
now accepts an optional `cache_dir = NULL` argument. When set, each
cropped Sentinel-2 band (B04, B08, B12) is persisted as a tiled GeoTIFF
(COG-compatible: `TILED=YES`, `COMPRESS=DEFLATE`, `PREDICTOR=2`, 256×256
blocks) under `<cache_dir>/{scene_id}/{band}.tif`.

- On a cache hit, the band is opened with
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
  against the local file — no VSI/HTTP read.
- On a cache miss, the band is fetched via VSI, cropped to the AOI bbox,
  and written atomically (`.tmp` → `rename`). Cache write failures only
  warn, the pipeline continues with the in-memory raster.
- The cache is **extent-aware**: a cached file whose bbox no longer
  covers the requested plots is silently overwritten. A new placette
  outside the previous window therefore does not return stale data.

This complements the `skip_cached` short-circuit added in v0.21.3:

| Layer | Saves when | Where |
|----|----|----|
| `skip_cached` (v0.21.3) | `obs_pixel` already has the (plot × band) values for an `obs_date` | DB SQL pre-filter |
| `cache_dir` (this release) | `obs_pixel` needs a refresh (new band, new metric, manual wipe) but the raw bands are unchanged | local COG store |

Two new progress events:

- `s2:band_cached` — per band, payload `scene_id`, `band`, `path`.
- `s2:band_fetched` — per band, same payload.

Disk usage estimate: ~50 KB per band for a 1 km² AOI; ~24 MB for the
typical 159-scene × 3-band run. Set `cache_dir = NULL` (default) to keep
the v0.21.3 behaviour (no caching).

## nemeton 0.21.3 (2026-05-12)

#### Added — `skip_cached` short-circuit for `ingest_sentinel2_timeseries()`

[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
now accepts an optional `skip_cached = TRUE` argument. Before the STAC
loop, it queries `obs_pixel` and identifies every `obs_date` already
covered for **every** plot of the zone × **every** requested band.
Matching scenes are skipped: no VSI/HTTP read, no
[`terra::crop`](https://rspatial.github.io/terra/reference/crop.html),
no `exactextractr` extraction — the user only pays for scenes whose data
is genuinely missing from the database.

Concretely this turns a re-run of
[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
against an already-populated zone from ~1-2 GB of network into zero,
while preserving the existing idempotent INSERT semantics.

The cache lookup is partial-coverage-aware: requesting a new band
(e.g. adding `"NBR"` to a zone previously ingested with `"NDVI"` only)
does not trigger a false-positive skip — the scene is re-extracted
because at least one `(plot, band)` tuple is still absent. Set
`skip_cached = FALSE` to force re-extraction unconditionally (debugging
or post-invalidation workflows).

Two new progress phases are emitted:

- `s2:cache_lookup` — once after the STAC query, with `n_cached` and
  `n_to_process` so the UI can immediately show “x/y scenes already in
  cache, fetching y” before the first HTTP read.
- `s2:scene_cached` — once per skipped scene, mirroring the `s2:scene`
  payload (`scene_id`, `obs_date`, `cloud_pct`, `source`). Lets the
  toast tick through the cached scenes at loop speed for visual
  feedback.

The summary tibble gains an `n_scenes_cached` column; `s2:complete`
emits the same value alongside `n_obs_inserted`.

## nemeton 0.21.2 (2026-05-12)

#### Added — `progress_callback` for `run_fordead_dieback()`

The FORDEAD orchestrator now accepts an optional
`progress_callback = NULL` argument, mirroring the convention already
used by
[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
(v0.21.0). Callers — typically the async worker in `nemetonshiny` — can
subscribe to ordered, phase-level events and surface a live progress
indicator to the user.

The callback receives a single named list with a `current`
discriminator. Phases emitted, in order:

- `fordead:start` — once, with `total` (6 or 7 phases depending on
  whether persistence is requested), `python_env`, `fordead_version`.
- `fordead:phase` / `fordead:phase_done` — bracket each phase with
  `phase_name`, `completed`, `total`. The seven possible `phase_name`
  values are: `"vegetation_index"`, `"train_model"`, `"forest_mask"`,
  `"dieback_detection"`, `"export_results"`, `"postprocess"`, and (when
  `con` + `zone_id` are supplied) `"persist"`.
- `fordead:complete` — once on success, with `n_alerts_inserted` and
  `duration_sec`.
- `fordead:error` — once on failure, with the `phase_name` that blew up,
  `error_message` and `duration_sec`. No `fordead:complete` is emitted
  in that case.

Exceptions raised inside the callback are caught and discarded — a buggy
UI never aborts the FORDEAD pipeline.

Default `NULL` preserves the v0.21.1 behaviour (silent, no events). No
call site needs to change.

## nemeton 0.21.1 (2026-05-12)

#### Fixed — DuckDB migration 0001 rejected by the parser

[`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)
failed on a fresh DuckDB monitoring database with
`Parser Error: syntax error at or near "GENERATED" — LINE 2: id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY`.
The DuckDB parser does not accept the SQL-standard
`GENERATED ALWAYS AS IDENTITY` clause, contrary to the comment shipped
in `inst/db/migrations/duckdb/0001_init.sql`. As a side effect, FK
clauses also relied on `ON DELETE CASCADE`, which DuckDB rejects at
parse time.

- `0001_init.sql` (DuckDB variant) now uses explicit
  `CREATE SEQUENCE IF NOT EXISTS … START 1` +
  `INTEGER PRIMARY KEY DEFAULT nextval('…')` for `monitoring_zone`,
  `plot` and `alert`.
- `ON DELETE CASCADE` is dropped from the three FK clauses
  (`plot.zone_id`, `obs_pixel.plot_id`, `alert.plot_id`). FK existence
  is still enforced; no current code path issues
  `DELETE FROM monitoring_zone` / `DELETE FROM plot`, so this is a
  documented restriction rather than a behavioural gap.
- Header comments updated to reflect the actual DuckDB-vs-PG differences
  (no false claim about IDENTITY support since 0.7).

The first launch of `nemetonshiny` against a local DuckDB backend
(`NEMETON_DB_URL=duckdb:///...` or auto-detected `*.duckdb` path) now
completes the schema bootstrap cleanly.

## nemeton 0.21.0 (2026-05-11)

#### Added — Local DuckDB backend for the monitoring subsystem

The monitoring database (spec 007 / E6) can now run on a local DuckDB
file instead of PostgreSQL + TimescaleDB + PostGIS. Use case :
single-user `nemetonshiny` deployments where setting up Postgres is
overkill.

**Selection by URL scheme.**
[`db_connect()`](https://pobsteta.github.io/nemeton/reference/db_connect.md)
inspects the connection URL and dispatches to the right driver :

- `postgresql://user:pass@host:port/dbname` → \[RPostgres::Postgres()\]
  (unchanged).
- `duckdb:///absolute/path/to/file.duckdb` → \[duckdb::duckdb()\]. The
  parent directory is created automatically.

A bare path ending in `.duckdb` is also accepted for convenience.

**Two migration directories.** `inst/db/migrations/` is now split
between `pg/` (the existing files — `CREATE EXTENSION timescaledb`,
`create_hypertable()`, `TIMESTAMPTZ`…) and `duckdb/` (same schema, minus
the TimescaleDB / PostGIS specifics — no hypertable,
`GENERATED ALWAYS AS IDENTITY` instead of `SERIAL`, `TIMESTAMP` instead
of `TIMESTAMPTZ`).
[`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)
picks the directory matching the connection’s driver class.

**Portable SQL touches in the monitoring functions.**

- [`list_alerts()`](https://pobsteta.github.io/nemeton/reference/list_alerts.md)
  no longer uses the PG-only `ANY($n::text[])` cast. Filters now bind
  one parameter per value and emit a portable `IN ($n, $n+1, …)` clause
  that works on both backends.
- `.insert_obs_pixel()` and `.insert_alerts()` branch on the connection
  class to emit `CREATE TEMP TABLE … ON COMMIT DROP` for Postgres or a
  `DROP TABLE IF EXISTS` + `CREATE TEMP TABLE` + explicit `DROP TABLE`
  for DuckDB (which has no `ON COMMIT DROP` clause).

**Suggested dependency.** `duckdb (>= 0.8.0)` is added to `Suggests`.
The PG path is unaffected by its absence ;
[`db_connect()`](https://pobsteta.github.io/nemeton/reference/db_connect.md)
only loads `duckdb` when the URL scheme selects that backend.

**Removed helper.** `.pg_text_array()` is dropped — it only existed to
support `ANY($n::text[])` which is no longer used. Internal, never
exported.

#### Changed — `db_migrate()` signature

`migrations_dir` now defaults to `NULL` (was the bundled
`inst/db/migrations/`). The directory is then picked automatically based
on the connection’s driver. Callers passing an explicit path still work
unchanged.

## nemeton 0.20.1.9009 (development)

#### Fixed — Planetary Computer SAS signing migrated to batch token endpoint

[`stac_search_s2_pc()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
used to sign every Sentinel-2 band href individually through
`/api/sas/v1/sign`. A single STAC search typically returns 20-50 scenes
× 3 bands (B04, B08, B12), so the loop instantly hit Planetary
Computer’s per-IP rate limit and emitted 50+
`PC sign failed: HTTP 429 Too Many Requests` warnings, followed by a
wave of `GDAL Error 1: HTTP error code : 409` from
`sentinel2l2a01.blob.core.windows.net` because terra fell back to the
unsigned URLs.

The signing now uses the documented batch endpoint
`/api/sas/v1/token/{collection}` instead. One HTTP call returns a SAS
query string that is valid for the whole collection for ~30 minutes; we
cache it in a per-process env (`.pc_token_cache`, keyed by collection)
and append it to every href via the new helper `.pc_apply_token()`.
Subsequent searches in the same R session reuse the cached token until
60 s before its `msft:expiry`.

Net effect: a search that previously made 60-150 sign calls and got
rate-limited now makes a single token call and signs every href
client-side. The original `.pc_sign_url()` helper is kept in the source
as a documented single-href fallback but is no longer called from the
search path.

- New private helpers:
  `.pc_collection_token(collection, grace_seconds = 60L)` and
  `.pc_apply_token(href, token)`.
- New private cache env: `.pc_token_cache` (cleared at session end).
- 6 new test_thats covering: token append on a bare href, leading-`?`
  normalisation, append with existing query string, empty-token
  short-circuit, fresh-cache reuse, expired-cache refresh, network
  failure → NULL with warning.

## nemeton 0.20.1.9008 (development)

#### Diagnostic — `.pc_sign_url()` no longer swallows failures

The Planetary Computer SAS sign helper used to fall back silently to the
unsigned URL whenever
[`httr2::req_perform()`](https://httr2.r-lib.org/reference/req_perform.html)
errored or the response body could not be parsed. This caused a
confusing wave of `HTTP 409` errors from
`sentinel2l2a01.blob.core.windows.net` (“file does not exist” via
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html))
whenever something — rate limit, timeout, transient auth — broke the
per-href signing loop. Two
[`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
calls now surface the underlying cause so we can pick the right durable
fix (batched token endpoint, retry/backoff, …) instead of guessing.

## nemeton 0.20.1.9007 (development)

#### Added — `ingest_sentinel2_timeseries()` progress callback

[`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
now accepts an optional `progress_callback` argument so long-running
scene downloads can be streamed back to the UI (typically
`nemetonshiny`’s `mod_monitoring` in E6.b). The contract follows the
same shape as the indicator / download callbacks already used in
`nemetonshiny/service_compute.R`: the callback receives a single named
list with a `current` phase key plus context fields. Phases emitted, in
order:

- `s2:search` — before the STAC query (`start`, `end`, `n_plots`,
  `bands`).
- `s2:search_done` — after STAC (`total` = number of scenes).
- `s2:scene` — before each scene (`completed`, `total`, `scene_id`,
  `obs_date`, `cloud_pct`, `source`).
- `s2:scene_skipped` — when a scene fails extraction (adds
  `error_message`).
- `s2:complete` — at the end (`completed = total`, `n_obs_inserted`).

The argument defaults to `NULL` (silent), so existing callers are
unaffected.

## nemeton 0.20.1.9006 (development)

#### Infra — DB stack now embeds PostGIS by default

The `docker-compose.yml` reference deployment switched from
`timescale/timescaledb:latest-pg16` (Alpine, TimescaleDB only) to
`timescale/timescaledb-ha:pg16` (Debian, ships TimescaleDB + PostGIS +
pgvector) so the cœur and downstream `nemetonshiny` no longer need a
separate spatial extension setup. Migration `0001_init.sql` now
activates `postgis` alongside `timescaledb`, so a fresh
[`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)
run leaves the DB ready for both hypertables and spatial geometries.

- The `-ha` image uses `/home/postgres/pgdata` as `PGDATA` (vs
  `/var/lib/postgresql/data` for the Alpine image), so existing
  development volumes must be recreated:

      docker compose down
      docker volume rm nemeton_pg_data
      docker compose up -d timescaledb

- Schema columns stay in WKT TEXT for now — the `geometry(Point, 2154)`
  migration plus GiST indexes will land in a later cycle when data
  volume justifies pushing snap-to-plot and `ST_DWithin` filtering down
  to SQL.

## nemeton 0.20.1.9005 (development)

#### Renamed — QGIS / QField terminology cleanup

The two QField-named exports were renamed to reflect what they actually
do: produce / consume a standard `.qgz` QGIS 3.x project (zip of `.qgs`
XML + GPKG) which any QGIS-speaking client (QGIS Desktop, QField via
QFieldSync, etc.) can open. There is no QFieldSync-specific tagging in
the output, so the previous names were misleading.

- [`create_qfield_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
  →
  **[`create_qgis_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)**
- [`import_qfield_gpkg()`](https://pobsteta.github.io/nemeton/reference/import_qgis_gpkg.md)
  →
  **[`import_qgis_gpkg()`](https://pobsteta.github.io/nemeton/reference/import_qgis_gpkg.md)**

The roxygen group names (and therefore the `man/*.Rd` page names)
follow:

- `qfield_export` → **`qgis_export`**
- `qfield_import` → **`qgis_import`**

The function bodies, signatures, return types and behaviour are
unchanged — this is a pure rename.

#### Deprecated

[`create_qfield_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
and
[`import_qfield_gpkg()`](https://pobsteta.github.io/nemeton/reference/import_qgis_gpkg.md)
are kept as deprecated aliases for backwards compatibility with
`nemetonshiny` and any external caller. They forward to the new names
and emit a one-shot
[`.Deprecated()`](https://rdrr.io/r/base/Deprecated.html) warning.
**They will be removed in a future release** — please migrate.

#### Internal cross-references updated

`R/health_validation.R`, `R/sampling_plan.R`, `R/field_schema.R` and the
QGIS export/import modules now reference the new names in their
docstrings and comments. 62 textual mentions of “qfield” across the
codebase were rebalanced toward “qgis” where the subject was actually
QGIS Desktop / the `.qgz` format and not the mobile QField client
specifically.

#### Tests

- All call sites in `test-qgis-export.R` and `test-qgis-import.R`
  updated to the new names.
- Added two tests that exercise the deprecated aliases and assert the
  deprecation warning is emitted.

Total suite: 5994 PASS / 0 FAIL.

## nemeton 0.20.1.9004 (development)

#### Added — E6.d (R5 dieback indicator, towards v0.21.0)

- **`R/indicators-deperissement.R`** — implements guard-rail G5 of
  spec 008. The R5 dieback index is the confidence-weighted fraction of
  each forest unit’s area covered by FORDEAD anomaly clusters (rescaled
  to 0-100 to align with R1..R4).

  - `indicateur_r5_deperissement(units, fordead_results, weights = FORDEAD_CONFIDENCE_WEIGHTS, min_resineux = 0.3, include_low_classes = FALSE, resineux_col = NULL)`
    — returns the input `units` augmented with an `R5` column (numeric,
    0-100, NA when skipped) and an `r5_status` column (`"calculated"`,
    `"skipped_no_resineux"`, `"skipped_no_fordead"`).
  - Per-UGF logic: skip with `skipped_no_resineux` when the spruce + fir
    share is below `min_resineux` (binary 0/1 when derived from a
    dominant-species column, or any fraction in `[0, 1]` when the caller
    passes `resineux_col`). Skip with `skipped_no_fordead` when no
    FORDEAD results are provided. Otherwise the score is the weighted
    cluster-area / unit-area ratio, capped at 1 and multiplied by 100.
  - Defaults to keeping only classes `3-forte` and `4-sol-nu` (G1 from
    the ONF/DSF 2024 report — classes 1-faible / 2-moyenne carry 50% /
    33% false-positive rates). Set `include_low_classes = TRUE` to
    include them, weighted by `FORDEAD_CONFIDENCE_WEIGHTS`.

- **`R/indicator-config.R`** — `INDICATOR_FAMILIES$R` extended from 4 to
  5 indicators (`R1..R5`) with bilingual labels and tooltips.
  [`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
  picks `R5` up automatically through its existing `^R[0-9]` regex; no
  change needed in `R/family-system.R`. The R family score
  (`famille_risque`) stays finite when R5 is NA — R1..R4 carry the
  average in that case.

- **Tests** — 18 new offline tests in
  `tests/testthat/test-indicators-deperissement.R`. Total suite: 5988
  PASS / 0 FAIL. **The cœur side of the v0.21.0 release is now
  complete** (E6.c.1/.2/.3/.4 + E6.d) — only the app side (E6.b phases
  2-6, E6.c.5 in `nemetonshiny`) and the end-to-end smoke (E6.f) remain.

## nemeton 0.20.1.9003 (development)

#### Added — E6.c.4 (FORDEAD QField terrain validation, towards v0.21.0)

- **`R/health_validation.R`** — guard-rail G4 of spec 008 (the ONF/DSF
  report mandates a terrain validation step). Three exported functions
  plus two exported vocabularies:
  - `HEALTH_VALIDATION_STADES` — 7 DSF-aligned dieback stage codes
    (`sain`, `sain_scolyte_vert_indif`, `scolyte_vert`, `scolyte_rouge`,
    `scolyte_gris`, `scolyte_rouge_gris_indif`, `coupe_rase`).
  - `HEALTH_VALIDATION_CAUSES` — 7 free-form cause suggestions rendered
    as a value-map in the QField form.
  - `get_health_validation_schema(region, lang)` — 11 `.field()`
    descriptors compatible with
    [`create_qfield_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md).
    The `essence_dominante` domain comes from
    [`list_species_classes()`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
    and falls back to free text when the region is unknown.
  - `generate_health_validation_plots(alerts_sf, n, method, crs)` —
    stratified draw on `confidence_class`. Uses
    [`spsurvey::grts()`](https://usepa.github.io/spsurvey/reference/grts.html)
    when available, falls back to per-stratum random sampling otherwise
    (the `sampling_method` column of the result tracks which path ran).
    Internal `.allocate_health_strata()` distributes the budget with a
    largest-remainder method while guaranteeing at least one plot per
    present class. Output ready for QField export (typed-NA editable
    columns).
  - `ingest_health_validation(con, gpkg_path, zone_id, snap_distance_m, validated_by, layer)`
    — reads the GPKG placette layer, snaps each plot to the nearest
    alert in Lambert-93 (default 50 m), and translates
    `stade_deperissement` to `validation_status` / `validation_cause`
    via the internal `.health_stade_to_status()` helper. The
    `coupe_rase` rule is class-dependent (1-faible / 2-moyenne →
    `false_positive`; 3-forte / 4-sol-nu → `confirmed`). `validated_by`
    precedence: arg \> `obs_by` field \>
    [`Sys.info()`](https://rdrr.io/r/base/Sys.info.html). The field’s
    free-form `cause` column overrides the auto-mapped cause when
    present. Returns
    `list(n_updated, n_confirmed, n_false_positive, n_unmatched, n_skipped, details)`
    where `details` is a data.frame tracing each plot.
- **Tests** — 31 new tests (`test-health-validation-schema.R` 10,
  `test-generate-health-validation-plots.R` 11 with a
  `local_mocked_bindings(requireNamespace)` to exercise the
  GRTS-fallback path, `test-ingest-health-validation.R` 10 TimescaleDB
  integration tests through `with_clean_db`). Total suite: **5957 PASS /
  0 FAIL**.

## nemeton 0.20.1.9002 (development)

#### Added — E6.c.3 (FORDEAD validity zones, towards v0.21.0)

- **`inst/extdata/fordead_validity_zones.geojson`** — five French
  departments (88 Vosges, 39 Jura, 01 Ain, 73 Savoie, 74 Haute-Savoie)
  where the FORDEAD calibration is validated by the ONF/DSF report
  (Bernard & Doridant 2024). 5 MULTIPOLYGON features, EPSG:4326,
  simplified at 100 m in Lambert-93 (~27 500 km^2, 80 ko). Built
  reproducibly from the static `gregoiredavid/france-geojson` mirror
  (Etalab 2.0).

- **`data-raw/build_fordead_validity_zones.R`** — reproducible script.
  Pivot from the original plan: `geo.api.gouv.fr` no longer serves
  contours via `format=geojson&geometry=contour`, so we use the GitHub
  static mirror instead.

- **`R/fordead_validity.R`** — implements guard-rail G3 of spec 008.

  - `FORDEAD_VALIDITY_DEPARTMENTS` and `FORDEAD_VALIDITY_SPECIES`
    exported constants.
  - [`load_fordead_validity_zones()`](https://pobsteta.github.io/nemeton/reference/load_fordead_validity_zones.md)
    — loads and caches the GeoJSON for the lifetime of the R session.
  - `check_fordead_validity(aoi, units, threshold_geo, threshold_species, min_resineux)`
    — returns a list flagging whether the AOI lies inside the calibrated
    extent (`geo_valid`, `geo_intersection_pct`, `geo_dept_codes`) and
    whether the user units are spruce + fir dominated (`species_valid`,
    `species_resineux_pct`, `species_epc_pct`, `species_sap_pct`), plus
    an `overall_valid` flag.
  - Internal `.is_epicea()` and `.is_sapin_pectine()` helpers correctly
    handle the Norway-spruce / silver-fir Latin name collision (both
    species share the epithet “abies”) and exclude Douglas fir
    (Pseudotsuga menziesii).

- **Tests** — 16 new offline tests (`test-fordead-validity-zones.R` 4,
  `test-fordead-validity.R` 12). Total suite: 5866 PASS / 0 FAIL.

## nemeton 0.20.1.9001 (development)

#### Fixed

- **`R/fordead_postprocess.R::list_alerts()`** — vector filters
  (`classes`, `validation_status`) are now serialised as Postgres
  `text[]` literals via the new internal helper `.pg_text_array()` and
  bound through `$n::text[]` placeholders. RPostgres requires every
  `dbBind` parameter to be length 1, so passing an R vector directly to
  `WHERE x = ANY($n)` was failing with *“Parameter 2 does not have
  length 1”* whenever a caller passed more than one class or status.
  Discovered by re-enabling the TimescaleDB integration tests once
  `NEMETON_DB_URL_TEST` was exported.

## nemeton 0.20.1.9000 (development)

#### Added — E6.c.2 (FORDEAD post-processing + DB integration, towards v0.21.0)

- **`inst/db/migrations/0002_fordead.sql`** — extends `alert` with the
  validation workflow columns (`confidence_class`, `stress_index`,
  `validation_status DEFAULT 'pending'`, `validation_cause`,
  `validated_by`, `validated_at`) and adds two indexes:
  `alert_validation_status_idx` (UI filtering) and
  `alert_plot_date_type_idx` (composite index for the rolling-window ×
  FORDEAD fusion). Idempotent (`ADD COLUMN IF NOT EXISTS` /
  `CREATE INDEX IF NOT EXISTS`).

- **`R/fordead_postprocess.R`** — turns the GeoTIFF outputs of
  [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  into an `sf` POINT layer of cluster centroids and persists them in the
  `alert` table. Pipeline:
  [`.classify_pixels_to_classes()`](https://pobsteta.github.io/nemeton/reference/dot-classify_pixels_to_classes.md)
  →
  [`.cluster_anomaly_pixels()`](https://pobsteta.github.io/nemeton/reference/dot-cluster_anomaly_pixels.md)
  ([`terra::patches`](https://rspatial.github.io/terra/reference/patches.html),
  8-neighbour by default, drops patches smaller than `min_pixels = 5`) →
  [`.cluster_to_centroids()`](https://pobsteta.github.io/nemeton/reference/dot-cluster_to_centroids.md)
  (one POINT per cluster, enriched with `confidence_class`,
  `stress_index`, `trigger_date`, `n_pixels`, `area_m2`, `cluster_id`).

- **`FORDEAD_CLASSES`** (exported) — canonical 5-class vocabulary
  (`0-hors-anomalie`, `1-faible`, `2-moyenne`, `3-forte`, `4-sol-nu`).

- **`FORDEAD_CONFIDENCE_WEIGHTS`** (exported) — per-class
  trustworthiness coefficients calibrated on the ONF/DSF FORDEAD
  validation report (Bernard & Doridant 2024 — ADR-013 §G5). Classes 1 /
  2 are weighted at 0.10 / 0.30 (poor field validation), classes 3 / 4
  at 0.82 / 0.70.

- **`.insert_fordead_alerts(con, alerts_sf, zone_id, radius_m)`** —
  bulk-inserts cluster centroids as `alert_type = 'fordead_dieback'`
  rows. Each centroid is snapped to the nearest registered plot of the
  zone (default max 200 m); centroids with no plot in range are skipped
  with a warning. Idempotent on `(plot_id, alert_type, trigger_date)`
  via `ON CONFLICT DO NOTHING` and a TEMP staging table.

- **[`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  wired** — the orchestrator now calls the post-processor inline and
  accepts new arguments `zone_id`, `min_pixels`, `connectivity`. The
  `alerts_sf` field of the return value is populated;
  `n_alerts_inserted` reflects the actual `ON CONFLICT` outcome when
  `con` and `zone_id` are supplied.

- **`classify_disturbance(alerts_df, window_days = 30)`** (exported,
  garde-fou G2) — joins each FORDEAD alert with rolling-window
  (`ndvi_drop` / `nbr_drop`) alerts on the same plot in a ±`window_days`
  window. Adds a `disturbance_type` column with values `mechanical`,
  `progressive`, `recent_event` or `NA`. Pure R, O(n²), no DB writes —
  recomputed at each call.

- **`list_alerts(con, zone_id, classes, validation_status, period)`**
  (exported, garde-fou G1) — read helper for the UI. Default class
  filter keeps `c("3-forte", "4-sol-nu")` (and rolling-window alerts
  which have no class); pass `classes = NULL` to opt in to
  lower-confidence alerts. Optional filters on `validation_status` and
  `trigger_date` period.

- **Tests** — `test-fordead-postprocess.R` (45+ assertions across
  constants, raster post-processing on synthetic SpatRasters,
  `classify_disturbance` cases, integration `with_clean_db` for
  `list_alerts` + `.insert_fordead_alerts`); `test-fordead-pipeline.R`
  extended with a non-empty postprocess scenario asserting the INSERT
  wiring. `test-db.R` extended for the `0002_fordead` migration. Suite :
  5745 PASS / 0 FAIL offline.

#### Added — E6.c.1 (FORDEAD pipeline scaffolding, towards v0.21.0)

- **`R/fordead_python.R`** — reticulate venv helpers for FORDEAD.
  [`.ensure_fordead_python()`](https://pobsteta.github.io/nemeton/reference/dot-ensure_fordead_python.md)
  is idempotent (creates the `~/.virtualenvs/nemeton-fordead` venv on
  first use, installs the pinned dependencies from
  `inst/python/requirements.txt`, caches the imported module for the
  session). Python ≥ 3.10 is required; diagnostics make the precondition
  explicit. Override the venv name via the env var
  `NEMETON_FORDEAD_ENV`.

- **`R/fordead_pipeline.R`** —
  [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  orchestrates the five FORDEAD steps (compute masked vegetation index,
  train model, forest mask, dieback detection, export results) on an AOI
  in EPSG:2154. Returns a structured list (`status`, `output_dir`,
  `rasters`, `alerts_sf`, `n_alerts_inserted`, `duration_sec`,
  `python_env`, `fordead_version`). Calibration is frozen on the ONF/DSF
  reference values (Bernard & Doridant 2024, ADR-013): CRSWIR +
  threshold 0.16. Post-processing of rasters into POINT clusters and DB
  persistence land in chantier E6.c.2.

- **`inst/python/requirements.txt`** — pinned Python deps
  (`fordead==2.1.4`, xarray, dask, rasterio, eodag, etc.).

- **`reticulate (>= 1.34.0)`** added to `Suggests`. Python and the
  `fordead` package are not pulled in until the user runs the pipeline;
  offline / non-Python users keep the existing surface.

- **Tests** — `test-fordead-python.R` (8 test_that, mocked reticulate,
  covers idempotence, version gating, venv reuse) and
  `test-fordead-pipeline.R` (12 test_that, mocked Python phases, covers
  argument validation, in-order step invocation, error propagation,
  forest-mask routing). All tests run offline.

## nemeton 0.20.1 (2026-04-25)

#### Fixed — E6.a hardening (integration tests surfaced two real bugs)

- **[`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)
  multi-statement migrations.** The bundled `0001_init.sql` migration
  contains multiple statements (`CREATE TABLE` × 4, `CREATE INDEX` × 3,
  `SELECT create_hypertable(...)`, `CREATE EXTENSION`). RPostgres
  prepares the SQL by default and PostgreSQL refuses with *“cannot
  insert multiple commands into a prepared statement”*. Switched the
  migration call to `dbExecute(..., immediate = TRUE)` so the
  simple-query protocol is used. Fresh installs from v0.20.0 could never
  bootstrap the schema; this fix is required for the monitoring
  subsystem to be usable.

- **`.insert_obs_pixel()` temp-table scope.** The bulk-ingest helper
  created a `TEMP TABLE ... ON COMMIT DROP` *outside* the transaction
  containing the `dbAppendTable` + `INSERT … SELECT`. Each top-level
  `dbExecute` auto-commits, so the staging table was dropped immediately
  and the subsequent append failed with *“relation tmp_obs_pixel_staging
  does not exist”*. Moved the `CREATE TEMP TABLE` inside the same
  `dbWithTransaction` as the inserts.

- **[`register_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/register_monitoring_zone.md)
  docstring.** Claimed idempotence on `(zone_name, plot_id)`, but
  `monitoring_zone` has no uniqueness on `name`. Reworded to reflect
  actual guarantees: only `(zone_id, plot_id)` is enforced (via
  `UNIQUE` + `ON CONFLICT DO NOTHING`); same `zone_name` still creates a
  new zone row.

#### Added

- **`tests/testthat/test-monitoring.R`** — 12 test_that blocks, 49
  assertions (3 pure unit + 9 integration). Covers
  [`register_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/register_monitoring_zone.md)
  (insert, WGS84 reprojection from Lambert-93, per-zone plot
  uniqueness),
  [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  (empty zone warning, empty STAC summary, mocked successful flow with
  idempotent re-run, per-scene extraction error recovery), and the
  internal helpers `.empty_ingest_summary()`, `.fetch_plots_sf()`,
  `.insert_obs_pixel()`. Surfaced both fixes above. `R/monitoring.R` now
  has its own dedicated test file (the 251-line module had zero direct
  tests in v0.20.0).

## nemeton 0.20.0 (2026-04-25)

#### Added — Épaississement 6.a (walking skeleton monitoring continu)

- **TimescaleDB-backed monitoring subsystem.** First persisted
  time-series store in nemeton, designed to ingest Sentinel-2
  observations on demand and detect drops in vegetation indices. See
  `specs/007-monitoring-continu/` for the full spec.

- **Database layer** (new `R/db.R`):
  [`db_connect()`](https://pobsteta.github.io/nemeton/reference/db_connect.md),
  [`db_disconnect()`](https://pobsteta.github.io/nemeton/reference/db_disconnect.md),
  [`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md).
  Connection URL via `NEMETON_DB_URL`. Migrations bundled in
  `inst/db/migrations/0001_init.sql` create four tables —
  `monitoring_zone`, `plot`, `obs_pixel`, `alert` — with `obs_pixel`
  promoted to a TimescaleDB hypertable chunked every 7 days. Tracking
  via `schema_migration` makes re-runs no-ops.

- **STAC Sentinel-2 client** (new `R/sentinel2.R`):
  [`stac_search_s2()`](https://pobsteta.github.io/nemeton/reference/stac_search_s2.md)
  façade with **CDSE priority + Planetary Computer fallback** (ADR-008
  souveraineté UE). Per-backend helpers
  [`stac_search_s2_cdse()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
  and
  [`stac_search_s2_pc()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
  are exported for finer control. PC hrefs are signed via the SAS-token
  endpoint so
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
  reads work without further authentication.

- **On-demand ingestion** (new `R/monitoring.R`):

  - `register_monitoring_zone(con, name, polygon, placettes)` upserts a
    zone and its plots (idempotent on `(zone_id, plot_id)`).
  - `ingest_sentinel2_timeseries(con, zone_id, start, end, bands = c("NDVI","NBR"))`
    fetches all matching scenes via STAC, computes NDVI from B04/B08 and
    NBR from B08/B12 in memory, and extracts the per-plot mean over a 15
    m circular buffer with `exactextractr`. Bulk INSERT into `obs_pixel`
    via a TEMP staging table + `ON CONFLICT DO NOTHING`.

- **Alert detection** (new `R/alerts.R`):
  `detect_alerts(con, zone_id, threshold_ndvi_drop = 0.15, threshold_nbr_drop = 0.25, window_days = 30)`
  uses a SQL window function to compare each observation against the
  rolling mean of the preceding window; drops exceeding the per-band
  threshold are persisted in `alert` (idempotent on
  `(plot_id, alert_type, trigger_date)`) and returned as an sf POINT
  object.

- **Docker Compose** (`docker-compose.yml` at repo root, plus
  `.env.example`): single `timescaledb` service
  (`timescale/timescaledb:latest-pg16`) bound to localhost, persistent
  volume `nemeton_pg_data`, healthcheck via `pg_isready`.

- **Tests**: `test-db.R`, `test-sentinel2.R`, `test-alerts.R` plus
  `helper-monitoring.R`. Unit tests cover URL parsing, STAC feature
  parsing, CDSE→PC fallback logic, and bbox reprojection. Integration
  tests against a live TimescaleDB are gated by
  `skip_if_no_timescaledb()` (looks for `NEMETON_DB_URL_TEST`).

#### Dependencies

- `RPostgres` added to Suggests (DBI was already present).
- No new hard dependency: the monitoring subsystem only loads when its
  functions are called.

#### Documentation

- `specs/007-monitoring-continu/{spec.md, plan.md, tasks.md}` — full
  specification, implementation plan, 18-task breakdown.
- `PLAN.md` — refreshed for E6 with phase tracking.

#### Out of scope (reported to v0.20.x)

- Shiny module `mod_monitoring` (E6.b, in `nemetonshiny`).
- Automated cron worker (E6.c).
- Integration of alerts into `compute_all_indicators()` for dynamic
  R1/R2/T2 modulation.

## nemeton 0.19.12 (2026-04-24)

#### Fixed

- **[`create_qfield_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
  now produces a `.qgz` that opens in QGIS 3.x without crashing**. Three
  latent bugs in the hand-written `.qgs` / GeoPackage made the project
  file unusable:

  1.  Placette columns that were not supplied by the caller were filled
      with plain `NA` (logical), so the GeoPackage ended up typing
      `date_visite`, `pente_pct`, `observateur`, etc. as
      `Integer(Boolean)`. QGIS then tried to bind `DateTime` / `Range` /
      `TextEdit` widgets to boolean columns and crashed while building
      the attribute form. Missing columns are now filled with a **typed
      NA** (`NA_character_`, `NA_real_`, `NA_integer_`,
      `as.POSIXct(NA)`) matching the schema.

  2.  `ValueMap` widgets (`type`, `exposition`, `espece`, `statut`,
      `qualite`) were emitted as `List-of-Lists` instead of the
      canonical QGIS 3.x `List-of-Maps` (each entry is a
      `<Option type="Map">` wrapping one
      `<Option type="QString" name=... value=...>`). QGIS crashed while
      parsing the form definition.

  3.  The QGIS 2.x `<prop k="..." v="..."/>` syntax used by the
      categorised point renderer is rejected by QGIS 3.x. The custom
      renderer has been dropped; QGIS now applies its default
      single-symbol renderer, which users can categorise in the UI.

- Structural hardening of the `.qgs` XML, independent of the crash fix:
  full `<spatialrefsys>` block (wkt, proj4, srsid, srid, authid,
  description, geographicflag) built from
  [`sf::st_crs()`](https://r-spatial.github.io/sf/reference/st_crs.html)
  instead of a bare `<authid>`; `<extent>` added to every `<maplayer>`;
  `source` attribute added to every `<layer-tree-layer>`;
  `<customproperties>`

  - `<custom-order enabled="0"/>` inside `<layer-tree-group>`;
    `<homePath>`, `<title>`, `<properties>` at the project root.

## nemeton 0.19.11 (2026-04-24)

#### Changed

- **[`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  now clamps `n_base + n_over` to frame capacity with a clear warning**.
  Previously, when the candidate frame (after `min_forest_cover` /
  `max_slope` filtering) was smaller than `n_base + n_over`, the
  pipeline silently fell back to LPM2 and could drop *all* Over plots
  (since `max(0L, n_frame - n_base)` is 0 when `n_base ≥ n_frame`). It
  now detects the mismatch upfront, scales `n_base` and `n_over` down
  proportionally (Base/Over ratio preserved, with a minimum of 1 Over
  when `n_over > 0`), and emits a
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
  pointing at the likely causes (strict `min_forest_cover`, large
  `grid_step`). GRTS can then run on the reduced allocation instead of
  being skipped entirely.

#### Added

- Two new unit tests (`test-sampling-plan.R`) locking in the clamp
  behavior: Base/Over ratio preservation, minimum-1-Over guarantee, and
  the warning signature.

## nemeton 0.19.10 (2026-04-24)

#### Changed

- **[`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  auto-simplifies the stratification when GRTS would refuse**.
  Previously, a single thin stratum — easy to hit on small AOIs, where
  the 3D stratification (CHM height × BD Forêt type × TPI) can produce
  up to 60 combinations — caused the whole GRTS draw to be skipped and
  the plan fell back to LPM2 (which is spatially balanced but *not*
  stratified). The new `.fit_stratum()` helper now tries the
  stratification ladder 3D → 2D (drop TPI) → 1D (height only), keeping
  the richest combo where every stratum still meets the allocation +
  over requirement, and emits a
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html)
  listing the dropped dimension(s). LPM2 / random remain the final
  fallback.

#### Added

- Four new unit tests (`test-sampling-plan.R`) covering the new
  `.fit_stratum()` helper: degradation from 3D to 2D, from 3D to 1D, the
  fully-thin edge case, and degeneracy handling when one dimension is
  constant.

## nemeton 0.19.9 (2026-04-24)

#### Changed

- **[`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  now explains why GRTS was skipped**. The two previously silent
  fallback branches (no usable stratification, or `spsurvey` not
  installed) now emit a
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html)
  listing the concrete reasons —
  e.g. `"Skipping GRTS: no usable stratification (single stratum, no CHM, no DEM, no BD Foret 'tfv' field). Falling back to LPM2 / random."`
  The two already-reported cases (thin strata and
  [`spsurvey::grts`](https://usepa.github.io/spsurvey/reference/grts.html)
  errors) are unchanged.

## nemeton 0.19.7 (2026-04-24)

#### Fixed

- **`.compute_forest_cover()` row alignment**: the row.names-based
  fallback introduced in 0.19.6 was fragile across sf versions — some
  versions rewrite row.names on intersection and the resulting
  [`match()`](https://rspatial.github.io/terra/reference/match.html)
  returned NA, leaving the forest cover at 0 for all buffers. Replaced
  by a carried integer id column (`.fc_id`) added to buf_hit before the
  intersection and read back from `inter$.fc_id`. Robust on every sf ≥
  1.0.

## nemeton 0.19.6 (2026-04-24)

#### Performance

- **Vectorised `.compute_forest_cover()`** used by
  [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md).
  The previous per-row `for` loop was O(n × m) (n = candidate buffers, m
  = mask polygons) — on a Couchey-sized AOI (n ~ 3000 buffers, m ~ 50 BD
  Forêt polygons) the pre-filter was running in ~30–60 s, freezing the
  Shiny UI. New implementation runs in ~0.7 s for the same load by:
  1.  pre-filtering candidates with a bulk
      [`sf::st_intersects()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html);
  2.  unioning the mask once;
  3.  calling a single vectorised
      [`st_intersection()`](https://r-spatial.github.io/sf/reference/geos_binary_ops.html).
      Output is equivalent to the previous loop (suite 5608 / 0
      failure).

## nemeton 0.19.5 (2026-04-24)

#### Changed

- **[`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
  recognises LiDAR HD as a distinct augmentation** (E5.d phase 2). When
  the input carries `attr(data, "chm_source") == "lidar_hd"`, the
  augmented vector now includes `"height_lidar"` alongside any other
  flags. The `"height_ml"` tag stays reserved for Open-Canopy ML
  predictions. As before, the base NDP level is lifted to 1
  (“Observation”) when `attr(data, "has_lidar_hd")` is TRUE — the new
  flavour flag is purely informational.

## nemeton 0.19.4 (2026-04-24)

#### Fixed

- **Warning flood in `.compute_forest_cover()`** — when
  [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  was called with a non-trivial `forest_mask` (e.g. a BD Forêt v2
  coverage with 30+ polygons), the per-candidate
  [`sf::st_intersection()`](https://r-spatial.github.io/sf/reference/geos_binary_ops.html)
  call fired “attribute variables are assumed to be spatially constant
  throughout all geometries” once per candidate. A large project (~2000
  candidates) therefore spammed the console with 2000 copies of the same
  warning. Declare the attributes as constant via
  [`sf::st_agr()`](https://r-spatial.github.io/sf/reference/st_agr.html)
  and wrap the intersection in
  [`suppressWarnings()`](https://rdrr.io/r/base/warning.html) so the
  message appears once (in the downstream Shiny log) at most.

## nemeton 0.19.3 (2026-04-24)

#### Changed

- **`inst/extdata/bdforet_v2_mapping.csv`** — every row now has
  `confidence = "clear"`. The 9 previously ambiguous TFV codes (FF1-00,
  FF1G06-06, FF1-10-10, FF1-49-49, FF1-00-00, FF2G58-58, FF2G61-61, FO1,
  FO2) commit to the primary `context_key`; the secondary candidate is
  still kept in `alt_context_key` as informational metadata so the user
  can override locally.

#### Fixed

- **[`cv_from_bdforet()`](https://pobsteta.github.io/nemeton/reference/cv_from_bdforet.md)**
  — distinguish two cases that were previously conflated in `$unmapped`:
  - *truly unknown* TFV codes (absent from the mapping) → stay in
    `$unmapped`;
  - codes mapped explicitly to `NA` (non-forest: FF0, FO0, LA4, LA6) →
    no longer reported as unmapped since the mapping acknowledges them.
    This removes the spurious “FORÊT-FERMÉE-SANS-COUVERT-ARBORÉ” warning
    in the Shiny sizing report.

## nemeton 0.19.2 (2026-04-24)

#### Changed

- **TSP tour delegated to the `TSP` package** — the hand-rolled
  nearest-neighbor we shipped in 0.19.1 is replaced by the same recipe
  used in tutorial `09-sampling`:
  `TSP::solve_TSP(method = "nearest_insertion")` seeds the tour,
  `TSP::solve_TSP(method = "2-opt")` refines it. The output is then
  rotated so the SE-most plot is first (heuristic road-access start).
  The old NN + open-path 2-opt stays as a fallback when `TSP` is not
  installed.
- `TSP (>= 1.2.0)` added to `Suggests` in `DESCRIPTION`.

## nemeton 0.19.1 (2026-04-24)

#### Fixed

- **[`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)**
  — `visit_order` now reflects a real walking tour. The previous
  implementation assigned `visit_order` from the draw order (GRTS / LPM2
  / random), which on a wide AOI produced a zig-zag polyline on the
  Shiny map rather than a sensible field route. Base plots are now
  reordered via a nearest-neighbor heuristic starting from the
  south-easternmost point (likeliest road access in French forest
  contexts), then improved by up to 20 passes of 2-opt for an open path.
  Over (replacement) plots keep their draw-priority order at the tail.
  The helper `.tsp_nearest_neighbor()` is internal; no new hard
  dependency.
- Tests: two new assertions in `test-sampling-plan.R` (the TSP tour is
  materially shorter than a random order, and the first plot lands in
  the east half of a wide rectangle).

## nemeton 0.19.0 (2026-04-24)

#### New feature — Sample size from target error + CV typology (Épaississement 5.c)

- **`R/sample_size.R`** —
  `compute_sample_size(cv, target_error, alpha, N, max_iter, tol)`
  implements the classic Cochran formula `n >= (t * CV / E)^2` with
  iterative Student-t refinement on the degrees of freedom and an
  optional finite-population correction `n_corr = n / (1 + n/N)`.
  Returns the sized `n`, the converged `t_used` / `df`, convergence
  flag, iteration count, and the echoed inputs. Formulas are standard
  sampling theory and are not copyrightable; credit to Max Bruciamacchie
  / AgroParisTech (PPtools, GPL-2, 2014) for the IFN-G/ha convention we
  align on.

- **`R/cv_typology.R`** — lookup tables and helpers for the CV side of
  the equation:

  - [`cv_typology()`](https://pobsteta.github.io/nemeton/reference/cv_typology.md)
    loads `inst/extdata/cv_typology.csv`: 8 generic forest contexts (5
    peuplement-level, 3 stratification-level) with low / mid / high CV
    bounds on basal area G/ha.
  - `cv_lookup(context_key, position)` reads a single CV value.
  - [`bdforet_v2_mapping()`](https://pobsteta.github.io/nemeton/reference/bdforet_v2_mapping.md)
    loads `inst/extdata/bdforet_v2_mapping.csv`: the 32 BD Forêt v2 TFV
    codes mapped to one of the generic contexts with a confidence flag
    (clear / ambiguous) and a secondary candidate for ambiguous classes.
  - `cv_from_bdforet(bdforet_sf, position, aoi, tfv_col)` returns an
    area-weighted CV for an AOI, plus a diagnostic summary (per-TFV
    share, ambiguous codes, unmapped codes). Polygons mapped to NA (FF0
    coupe rase, LA4 lande, etc.) are excluded from the CV.

- **`R/sampling_plan.R`** —
  [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  now accepts `target_error`, `cv`, `alpha` and `over_ratio` as optional
  arguments. When `target_error` + `cv` are provided, `n_base` is sized
  via
  [`compute_sample_size()`](https://pobsteta.github.io/nemeton/reference/compute_sample_size.md)
  and `n_over` defaults to `ceiling(n_base * over_ratio)` (default 20
  %). The previous `n_base` path is preserved and stays the default when
  neither argument is set, but at least one must now be provided. The
  sizing result is attached to the returned sf as
  `attr(plan, "sample_size")`.

- **CSV editability**: both typology files are loaded via
  [`system.file()`](https://rdrr.io/r/base/system.file.html) by default,
  but `cv_typology(file = ...)` and `bdforet_v2_mapping(file = ...)` let
  the user point at a custom CSV — useful to tune the bounds locally
  without rebuilding the package.

- Tests: `test-sample-size.R` (24 assertions), `test-cv-typology.R` (24
  assertions, including area-weighted aggregation and the ambiguous /
  unmapped paths), plus 7 new assertions in `test-sampling-plan.R` for
  the `target_error` path. Full suite 5595 / 0 failure.

## nemeton 0.18.0.9000 (development)

#### New feature — QField export (Épaississement 5.a)

- **`R/field_schema.R`** — field data schema used for QField
  integration:
  [`get_placette_schema()`](https://pobsteta.github.io/nemeton/reference/get_placette_schema.md)
  (10 fields) and
  [`get_arbre_schema()`](https://pobsteta.github.io/nemeton/reference/get_arbre_schema.md)
  (9 visible fields + species domain). The `espece` domain is pulled
  from
  [`list_species_classes()`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
  so the vocabulary stays aligned with the rest of the package.
  [`schema_to_df()`](https://pobsteta.github.io/nemeton/reference/schema_to_df.md)
  and
  [`empty_sf_from_schema()`](https://pobsteta.github.io/nemeton/reference/empty_sf_from_schema.md)
  are internal helpers.
- **`R/qfield_export.R`** —
  `create_qfield_project(placettes, zone_etude, parcours_tsp, output_dir, project_name, crs, region, lang, overwrite)`
  packages a sampling plan as a QField-ready `.qgz` (a ZIP of a minimal
  QGIS 3.x `.qgs` XML + a GeoPackage with `placettes` / `arbres` /
  `zone_etude` / `parcours_tsp` layers). Edit widgets (TextEdit, Range,
  DateTime, ValueMap, ExternalResource), aliases and NotNull constraints
  are generated from the schemas. Zero new hard dependency: the XML is
  produced by string assembly, the GPKG by `sf`, the ZIP by
  [`utils::zip()`](https://rdrr.io/r/utils/zip.html).
- **Tutorial 09-sampling** — new Section 6 “Export QField” exercises
  [`create_qfield_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
  on the GRTS output, plus a 3-question quiz on the `.qgz` format,
  NotNull constraints and the species domain source.

#### New feature — Library-level sampling pipeline (Épaississement 5.a bis)

- **`R/sampling_plan.R`** —
  `create_sampling_plan(zone, n_base, n_over, chm, slope, forest_mask, mnt, ...)`
  lifts the full GRTS workflow of tutorial 09 to a single exported
  function. It builds a candidate grid, applies terrain constraints
  (slope / forest cover), stratifies on CHM height quartiles / BD Forêt
  tfv / TPI terciles, and draws plots via
  [`spsurvey::grts`](https://usepa.github.io/spsurvey/reference/grts.html)
  when strata are viable, falling back to
  [`BalancedSampling::lpm2`](https://rdrr.io/pkg/BalancedSampling/man/lpm.html),
  then to a plain spatial random draw — each step surfaced via an
  attached `"method"` attribute on the result.
- Without any of the optional inputs the pipeline degrades to the
  equivalent of a single
  [`st_sample()`](https://r-spatial.github.io/sf/reference/st_sample.html)
  call, which makes it a drop-in replacement for the previous Shiny-side
  placeholder.

#### New feature — QField re-ingestion (Épaississement 5.b)

- **`R/qfield_import.R`** — three companion functions that close the
  field loop:
  - `import_qfield_gpkg(path)` reads the `placettes` + `arbres` layers
    returned from QField.
  - `validate_field_data(placettes, arbres, region, lang)` checks
    referential integrity (orphan `plot_id`, duplicate `tree_id`),
    physical ranges (DBH in (0, 300\] cm, height in \[0, 80\] m),
    species in the controlled domain of `region`, and returns an
    `{ok, errors, warnings}` list.
  - `aggregate_plot_metrics(placettes, arbres, plot_radius)` computes
    per-plot dendrometric aggregates — `field_n_trees`, `field_dg_cm`
    (quadratic mean diameter), `field_h_dom_m` (top 5 height),
    `field_g_ha` (basal area), `field_cv_dbh` / `field_cv_h` for the B2
    structural component — as a sf that can be joined onto forest units.
  - `attach_field_data_to_units(units, field_agg)` spatial-joins the
    aggregates onto polygon units for downstream indicators (P1 / P2 /
    B2 / C1 / R2) to consume uniformly via `field_*` columns.
- **`R/ndp.R`** —
  [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
  gains an alternative QField path: `field_plots_count >= 1` bumps the
  NDP to at least 2 (Exploration); when trees-per-plot average \>= 10,
  the level goes to 3 (Diagnostic).
  `tag_field_data_sources(data, placettes, arbres)` is the helper that
  sets the expected attributes in one call.
- **`inst/datasources/FR.json`** — new `datasets.field_qfield` entry
  declaring the format (GeoPackage), required CRS (EPSG:2154), layers
  (`placettes`, `arbres`) and the NDP bump rule.
- Tests: `test-sampling-plan.R` (22 assertions across GRTS / LPM2 /
  random / constraint paths), `test-qfield-import.R` (26 assertions
  covering round-trip, validation failures, aggregates, and the units
  join), `test-ndp-qfield.R` (13 assertions on the alternative path
  including the sources listing and the JSON declaration).

## nemeton 0.18.0

Release theme: **F1 soil fertility becomes a three-source indicator with
absolute scoring and empirical calibration against RMQS**.

#### New Vignette — F1 three-source decision guide (phase E)

- **`vignettes/f1-three-sources_fr.Rmd`** — end-to-end comparison of the
  three F1 data-source paths (`"layer"`, `"soilgrids"`, `"gissol"`) with
  a decision matrix, runnable examples, the Phase D calibration reading
  (why CEC alone is a coarse proxy and the expert table captures more),
  and a decision tree for picking the right `source` per AOI.

#### Calibration — F1 expert scores vs RMQS 1ère campagne (phase D)

- **`inst/scripts/calibrate_uts_rmqs.R`** — reproducible pipeline that
  downloads the RMQS 1ère campagne dataset (DOI 10.15454/QSXKGA, Etalab
  2.0 licence, ≈ 2 171 sites, 2000-2009), joins topsoil CEC (0-30 cm,
  `cec_40_1`) with the site’s AFES 1995/2008 soil name (`rp_95_nom` /
  `rp_2008_nom`), classifies each name into one of our `rpf_code` values
  via a keyword-priority dictionary, and compares observed median CEC
  (mapped to 0-100 via
  [`cec_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/cec_to_fertility_score.md))
  with the expert score.
- **`inst/extdata/uts_fertilite_rmqs_calibration.csv`** — calibration
  artefact: 45 `rpf_code` × 2 037 RMQS sites, one row per code with
  `n_sites`, `cec_median`, `cec_q25`, `cec_q75`, `observed_score`,
  `expert_score`, `delta` and a boolean `flag_outlier` (\|delta\| \>
  20).
- **What the deltas reveal**: 20/45 rows are flagged. The deltas are NOT
  an indictment of the expert table — they highlight that CEC alone is a
  coarse proxy. The expert scores integrate Baize & Jabiol
  multi-criteria (texture, pH, drainage, depth, forestry productivity),
  which CEC doesn’t capture. Key signals:
  - **Alluvial / colluvial soils under-score on CEC** (FLU_TYP, COL_TYP,
    COL_CAL all −40 to −55): these are fertile because they are deep,
    well-drained and productive, not because they hold many cations. The
    SoilGrids path in F1 will under-rate them by design.
  - **ORG_INS over-scores on CEC** (+65): peat has very high CEC but is
    poor for forestry (acidity, waterlogging). The expert score rightly
    penalises this where CEC alone cannot.
  - **BRUN_MES bucket is biased** (−49 on 378 sites): most “plain
    BRUNISOL” RMQS labels fall into this via fallback, but many of those
    sites show CEC compatible with BRUN_DYS. Not a scoring bug — a
    mapping-granularity bug in the V2 classifier.
  - **Classes absent from the V1 expert table** (30+ RMQS sites):
    PLANOSOL, PELOSOL, MAGNESISOL, FERSIALSOL, DOLOMITOSOL,
    ALUANDOSOL/ANDOSOL. Candidates for a V2 CSV extension.
- **`tests/testthat/test-uts-calibration-rmqs.R`** — integrity checks on
  the calibration CSV (schema, cross-reference to the expert table,
  arithmetic consistency, sample size, CEC quartile order). Does not
  re-run the pipeline.

#### New Features — F1 GIS Sol wiring (phase C)

- **[`indicateur_f1_fertilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_f1_fertilite.md)
  gains a third `source` option**: `source = "gissol"` reads a French
  RRP (Référentiel Régional Pédologique) polygon layer from `layers`,
  intersects it with `units`, joins the AFES 2008 typology code against
  the UTS crosswalk shipped in `inst/extdata/uts_fertilite_fr.csv`, and
  returns an area-weighted fertility score per unit on the 0-100 scale.
  Units whose polygons carry only codes absent from the table return NA;
  units outside the RRP coverage return NA. A
  [`cli::cli_warn`](https://cli.r-lib.org/reference/cli_abort.html)
  summarises unknown codes when any are present.
- **`rpf_code_col` argument** (default `"rpf_code"`) lets the caller
  point at whatever column name the source RRP uses for the AFES code
  (`UTSDom`, `RPFdom`, etc.) without pre-renaming columns.
- **[`read_uts_fertility_table()`](https://pobsteta.github.io/nemeton/reference/read_uts_fertility_table.md)**
  — new exported helper returning the V1 UTS → fertility crosswalk as a
  data.frame. Useful for external review of the scoring and for ad-hoc
  joins against arbitrary RRP vector data.

#### New Data — UTS → fertility lookup (F1 GIS Sol wiring, phase B)

- **`inst/extdata/uts_fertilite_fr.csv`** — V1 draft of the soil
  typology → forest-fertility crosswalk for France, 54 rows covering the
  14 Grands Ensembles de Référence of the AFES 2008 Référentiel
  Pédologique (Brunisols, Luvisols, Podzosols, Alocrisols, Calcosols,
  Calcisols, Fluviosols, Colluviosols, Rankosols, Arenosols, Redoxisols,
  Reductisols, Peyrosols, Organosols, Régosols/Lithosols, Anthroposols).
  Columns: `rpf_code`, `rpf_name`, `wrb_code` (WRB 2014 equivalent),
  `fertility_class` (1–5), `fertility_score` (15/35/55/75/90 per the
  agreed grid), `texture_dom`, `drainage`, `depth_cm`, `ph_range`,
  `forest_note`, `source_biblio`, `notes`. Sources: AFES 2008, Baize &
  Jabiol 1995, Duchaufour 2001, Jabiol et al. 2009, Bonneau 1995.
  Intended for peer review by a pedologist before production use.
- **`tests/testthat/test-uts-fertilite.R`** — integrity checks on the
  CSV (schema, unique keys, score grid, class distribution, coverage of
  the 14 AFES families).

#### New Features — F1 fertility from SoilGrids 2.0

- **`load_raster_source(source_key, country, aoi)`** — new exported
  loader that resolves a datasource key declared in
  `inst/datasources/<country>.json` to a ready-to-use `SpatRaster`.
  Prepends `/vsicurl/` for `raster_remote` sources so GDAL reads only
  the requested window (essential for planet-scale feeds like
  SoilGrids). Crops to an optional AOI (reprojected to the raster’s
  native CRS). Refuses `raster_local` entries with no path (e.g.
  `chm_opencanopy`, which is materialised on the fly by its producing
  package).
- **`cec_to_fertility_score(cec_x10)`** — maps raw SoilGrids 2.0 Cation
  Exchange Capacity values (unit: `cmol(c)/kg × 10`) to a 0-100
  fertility score, linearly on `[0, 30] cmol(c)/kg` and capped at the
  bounds. Thresholds follow Baize & Jabiol (1995).
- **[`indicateur_f1_fertilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_f1_fertilite.md)
  gains a `source` argument**:
  - `source = "layer"` (default) — unchanged, reads a user-supplied soil
    raster or polygon layer and min-max normalises per call.
  - `source = "soilgrids"` — fetches the SoilGrids 2.0 CEC topsoil
    raster via `load_raster_source("soilgrids_cec")`, extracts the
    per-unit mean, and maps to 0-100 via
    [`cec_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/cec_to_fertility_score.md).
    No inventory layer is needed and scores are absolute (comparable
    across projects), unlike the relative layer-mode score. Global
    coverage — works for any AOI. Behaviour is fully backward-compatible
    when `source` is omitted.

## nemeton 0.17.0

#### New Features — NDP 1 “synthetic inventory”

- **`n_max_selfthinning(dq, species)`** — species-keyed evaluator of the
  Charru et al. 2012 self-thinning relationship for 11 temperate species
  (11 linear and curvilinear fits from Tables 2/5 of the paper, clamped
  to each species’ observed range).
- **[`estimate_synthetic_inventory()`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md)**
  — given an `sf` of units, a CHM `SpatRaster` and species codes, chains
  (CHM) (species allometry) (self-thinning × stocking fraction 0.75) and
  returns per-unit `(dbh, density, source = "synthetic_ml")`.
- **[`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md)**
  — fills a sf’s missing `dbh` / `density` columns in place, leaving
  user-provided values intact. Wired into
  [`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md),
  `_p3_qualite_bois()` and `_e1_bois_energie()` so that these three
  indicators now compute from the CHM when a terrain inventory is
  absent, instead of failing with “Missing required fields”.
- **[`charru_bai_drift_table()`](https://pobsteta.github.io/nemeton/reference/charru_bai_drift_table.md)
  / `bai_drift_factor(species, habitat)`** — per-species central
  estimates of the 1980-2007 relative BAI change reported in Charru et
  al. 2017 (Fig. 4a), with fallback to the per-climatic-habitat mean.
  [`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
  gains an opt-in `use_climate_drift = FALSE` argument that multiplies
  per- unit volume by the drift factor when TRUE.

#### New Features — site-index curves

- **FASY (common beech) migrated to the Korf recursive model of Bontemps
  et al. 2007 (RFF HS2, Annex 2)**. Three species codes now coexist in
  `inst/extdata/site_index_curves.csv`:
  - `FASY_NO` — Nord-Ouest (a=44.2, b=0.032, c=1.647)
  - `FASY_NE` — Nord-Est (a=68.7, b=0.028, c=0.823)
  - `FASY` — per-age per-class mean, used as a regionally- agnostic
    default pending a GRECO-aware dispatcher.
- **Phase A calibration audit** — new exported helper
  [`site_index_reference_points()`](https://pobsteta.github.io/nemeton/reference/site_index_reference_points.md)
  returns, for each of the 10 MVP species, the published reference point
  `(age, H_{class\_3})` and its bibliographic source (Duplat & Tran-Ha
  1997 for QUPE / QURO, Seynave et al. 2005 for PIAB, Vallet & Pérot
  2011 for ABAL, DSF/IRSTEA 2010 for PSME, …). A new regression test
  `test-site-index-calibration.R` asserts the shipped CSV matches every
  reference point within 0.5 m (worst current delta: 0.36 m on POSP).
- **[`enrich_parcels_bdforet()`](https://pobsteta.github.io/nemeton/reference/enrich_parcels_bdforet.md)
  is now exported** so that downstream packages (notably nemetonshiny,
  for its pre-compute P2 species/age enrichment step) can call it
  without `:::`.

#### Bug Fixes

- **[`sanitize_chm()`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md)**
  hardened against the Open-Canopy feed used in nemetonshiny:
  - each pipeline step (forest mask, buildings, water, NDVI, range,
    slope) runs in a named `tryCatch` so a terra failure surfaces with
    the step name instead of a cryptic `[subset] invalid name(s)`;
  - sf layers are stripped of every attribute before the
    [`terra::vect()`](https://rspatial.github.io/terra/reference/vect.html)
    conversion (via the new internal `.sf_to_vect_geom()`), sidestepping
    the list-columns / factor-level issues that BD Forêt V2 outputs
    occasionally carry;
  - NDVI default threshold softened from 0.3 to 0.2 (the former was too
    strict for conifer / shadowed / edge pixels);
  - new `forest_coverage_threshold` (default 0.5): the forest-mask step
    is skipped with a warning when the mask covers less than that
    fraction of the CHM extent, instead of wiping 95 %+ of the pixels
    when BD Forêt simply does not map the area. Pass
    `forest_coverage_threshold = 0` to force the mask;
  - each step now emits a `cli_alert_info` with the cumulative fraction
    of pixels masked, for post-mortem analysis.
- **E2 CO2 avoidance** emits a single aggregate log line per AOI instead
  of one line per unit (reduces log noise by ~60× on typical 63-UGF
  projects).

#### Breaking changes

- None. All changes are backward-compatible with v0.16.x.

## nemeton 0.16.0

#### New Features

- C1 biomass, B2 structure, R2 storm — Open-Canopy CHM modes (spec 005
  phase 4):
  - [`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md)
    gains a `chm = NULL` argument. When supplied with `dbh` and
    `species` columns, biomass is derived from the IFN tarif combined
    with wood density (`inst/extdata/wood_density.csv`), a biomass
    expansion factor (`bef`, default 1.30, IPCC 2006 temperate-forest
    default) and the carbon fraction. Stems per ha: prefer `stems_col`
    (default `"stems_ha"`), else derive from `density_col` fraction
    × 500. Positively correlates with the age-based path on varied
    stands (Spearman ρ ≥ 0.5).
  - [`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md)
    gains `chm = NULL` and `cv_chm_weight = 0.2` arguments. When a CHM
    is supplied, CV(height) per unit is computed and blended into the B2
    score. Without strata/age inputs, the CV(CHM) becomes the primary
    structural-diversity proxy. Heterogeneous stands (tall + short
    pixels) score higher than homogeneous ones.
  - [`indicateur_r2_tempete()`](https://pobsteta.github.io/nemeton/reference/indicateur_r2_tempete.md)
    gains `chm = NULL`, `species_field`, `h_dom_percentile` and
    `h_reference` arguments. The base DEM/wind score is modulated by a
    canopy-vulnerability factor clamped to \[0.5, 1.5\]: tall stands are
    more vulnerable than short ones, and at equal height conifers
    (factor 1.2) score higher than broadleaves (factor 0.8).
  - All three additions are fully backward-compatible when `chm` is
    `NULL`.
- P1 standing-timber volume via Open-Canopy CHM (spec 005 phase 3):
  - [`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
    gains a `chm = NULL` argument. When supplied, the height fed to the
    IFN tarif is taken from the CHM (per-unit 90th-percentile via )
    instead of the Näslund approximation . Typical RMSE reduction on
    mature stands: 20 to 40 %.
  - New optional arguments `h_dom_percentile` (default 0.9) and
    `pct_masked` (emits a warning when greater than 0.3, signalling a
    heavily-masked CHM whose P1 estimate is unreliable).
  - Genus-level fallback is now species-aware: conifers fall back to
    `CONIFER_GENUS`, non-conifers to `BROADLEAF_GENUS`. Previously every
    species defaulted to broadleaf, which penalised conifer volume
    estimates.
  - Added `PSME` (Pseudotsuga menziesii, Douglas) and `POSP` (Populus
    sp. cultivé) rows to `inst/extdata/ifn_volume_equations.csv` so they
    no longer fall back to genus-level coefficients.
  - New internal helper
    [`is_conifer()`](https://pobsteta.github.io/nemeton/reference/is_conifer.md)
    (shared with
    [`compute_site_index()`](https://pobsteta.github.io/nemeton/reference/compute_site_index.md)).
  - Behaviour is unchanged when `chm` is `NULL`: fully
    backward-compatible with v0.15.x.
- P2 site index via Open-Canopy CHM (spec 005 phase 2):
  - New reference dataset `inst/extdata/site_index_curves.csv` covering
    the 10 MVP species (QUPE, QURO, FASY, CASA, PIAB, ABAL, PSME, PISY,
    PIPI, POSP) plus two genus-level fallbacks (`BROADLEAF_GENUS`,
    `CONIFER_GENUS`). Generated from the published Chapman-Richards
    parametrizations of Duplat & Tran-Ha 1997 and related works, with
    per-species source attribution. Distribution authorised by M.
    Tran-Ha (personal communication, April 2026 — see `inst/NOTICE`).
  - New `compute_site_index(H_dom, age, species, reference_age = 50)`
    performs bilinear interpolation over the five fertility classes and
    returns the dominant height at the reference age (metres).
    Vectorised; NA-safe; genus-level fallback when the species is not
    directly tabulated; case-insensitive species codes.
  - New helpers
    [`list_site_index_species()`](https://pobsteta.github.io/nemeton/reference/list_site_index_species.md)
    and
    [`read_site_index_curves()`](https://pobsteta.github.io/nemeton/reference/read_site_index_curves.md).
  - New `extract_h_dom(chm, units, percentile = 0.9)` in
    `R/utils-chm.R`: per-unit dominant height from a sanitised CHM
    raster (90th-percentile by default). Falls back to
    [`terra::extract()`](https://rspatial.github.io/terra/reference/extract.html)
    when `exactextractr` is absent.
  - [`indicateur_p2_station()`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md)
    gains a `chm = NULL` argument that activates the CHM mode when
    supplied. In CHM mode the output column holds the site index in
    metres; the legacy proxy (`fertility × climate × species` →
    m³/ha/yr) is unchanged when `chm` is `NULL`.
  - New vignette `site-index-open-canopy_fr.Rmd` — end-to-end workflow
    from a CHM to P2 on a synthetic forest, with a section on limits
    (CHM ML RMSE,
    [`sanitize_chm()`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md)
    importance, age dependency).
- Foundation for Open-Canopy integration (spec 005 phase 1, ADR-011
  amendment):
  - [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
    now returns an `ndp_result` S3 object with `level`, `confidence`,
    `augmented`, `sources` slots. The `augmented` vector flags
    ML-derived layers such as `height_ml` when
    `attr(data, "chm_source") == "opencanopy"`. The base NDP level and
    global Fibonacci confidence are unchanged.
  - **Breaking**:
    [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
    used to return a plain integer. Callers must now use `result$level`
    or `as.integer(result)`.
  - New accessor
    [`get_ndp_augmented()`](https://pobsteta.github.io/nemeton/reference/get_ndp_augmented.md).
  - New dataset entry `chm_opencanopy` in `inst/datasources/FR.json`
    (type, format COG, required CRS, value range, provenance, license).
  - New
    [`sanitize_chm()`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md)
    5-step pipeline in `R/utils-chm.R` (forest mask, buildings/water,
    NDVI threshold, plausibility bounds, slope coherence). Returns
    `list(chm_clean, pct_masked, steps_applied)` and warns when more
    than 50% of valid pixels are masked.
  - New `inst/NOTICE` documenting third-party attributions (IGN BD
    ORTHO, Open-Canopy weights, LiDAR HD, OSO, WorldClim, Duplat &
    Tran-Ha site-index curves).

#### Refactoring

- Moved `ndp_badge()` and `ndp_progress_bar()` HTML widgets to the
  `nemetonshiny` package (they had no use in the core package)

#### Bug Fixes

- Fixed radar chart: replaced `NaN` values with 0 to prevent polygon
  vertex loss when an indicator is missing

#### Documentation

- Added indicator calculation table by NDP level (0-4)
- Added all 14 missing topics to the `_pkgdown.yml` reference index
- Synchronized `CLAUDE.md` with the v0.15.0 core/Shiny split: reflect
  `nemetonshiny` as a separate package, mark Épaississements 3 and 4 as
  delivered, update file references and strict rules

------------------------------------------------------------------------

## nemeton 0.15.1

**Date**: 2026-04-09

#### Bug Fixes

- Addressed all remaining R CMD check notes and warnings
- Cast all indicators (including F1 soil fertility) to `double` in
  `massif_demo_units` for consistent column types
- Forced conversion to `double` to avoid integer/numeric mismatches in
  downstream normalization

#### Data

- Regenerated `massif_demo_units` dataset with 29 indicators + 12 family
  composites using NMT naming (`famille_*` prefix)
- Regenerated `roads` and `water` GeoPackage fixtures

#### Documentation

- Vignettes realigned with NMT naming:
  [`starts_with()`](https://tidyselect.r-lib.org/reference/starts_with.html)
  patterns updated to match `famille_` prefix
- Fixed unicode escapes in `R/ndp.R`

------------------------------------------------------------------------

## nemeton 0.15.0

**Date**: 2026-04-09

#### BREAKING CHANGES ⚠️

**Core/Shiny package split (ADR-009)**

The `nemeton` package is now **core-only**. The Shiny application
(`nemetonApp`) has been extracted into a separate package
`nemetonshiny`. Users who relied on `nemeton::run_app()` must now
install `nemetonshiny` and call `nemetonshiny::run_app()`.

- 120+ internal functions are now exported from `nemeton` to be consumed
  by `nemetonshiny` and other downstream packages (`tree_sat_nemeton`,
  `maestro_nemeton`)
- All Shiny modules (`mod_*.R`), expert profiles (`inst/experts/`), UI
  i18n files (`inst/app/i18n/`), LLM prompts and OAuth2 module have been
  moved out of this repository
- `NAMESPACE` and `DESCRIPTION` cleaned up to drop Shiny-only
  dependencies

#### New Features

##### NDP System (Niveau De Précision) — ADR-011

- New `R/ndp.R` module implementing the 5-level data-precision system
  with Fibonacci weighting (1-1-2-3-5) and confidence ratio φ
- `NDP_LEVELS` configuration, accessors
  ([`get_ndp_level()`](https://pobsteta.github.io/nemeton/reference/get_ndp_level.md),
  [`get_ndp_name()`](https://pobsteta.github.io/nemeton/reference/get_ndp_name.md),
  [`get_ndp_weight()`](https://pobsteta.github.io/nemeton/reference/get_ndp_weight.md),
  [`get_ndp_confidence()`](https://pobsteta.github.io/nemeton/reference/get_ndp_confidence.md))
- [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
  — automatic NDP detection from data sources
- [`compute_general_index()`](https://pobsteta.github.io/nemeton/reference/compute_general_index.md)
  and
  [`compute_general_index_mixed()`](https://pobsteta.github.io/nemeton/reference/compute_general_index_mixed.md)
  for Fibonacci-weighted global scores
- NDP wired into the compute pipeline, radar chart, PDF report and
  synthesis table

##### Naturalness Indicators (N1, N2, N3)

- Aligned N1, N2, N3 formulas with Tutorial 04 ecological definitions

##### Internationalization & Data Sources (ADR-002)

- Data source abstraction by country — hardcoded URLs replaced with
  [`get_data_source()`](https://pobsteta.github.io/nemeton/reference/get_data_source.md)
  calls
- Species configuration by region for the NDP pipeline (ADR-007)
- Added `essence_peupleraie` as 11th species class
- EPSG:3035 pan-European storage CRS (ADR-008)

##### Infrastructure

- PostgreSQL/PostGIS database service for Clever Cloud (ADR-002)
- Auto-sync to PostGIS after indicator computation
- CI/CD enhancements with tests and Docker build (ADR-010)
- Dual license structure MIT + EUPL v1.2 (ADR-006)
- Real code coverage with covr + codecov (replaces the previous static
  badge)

#### Refactoring

##### NMT (Néméton Naming Convention) alignment

- All function, column and family names aligned with the NMT glossary
- DB schema aligned with NMT glossary keys (ADR-002)
- `get_famille_code()` reverse lookup added for NMT family names
- Test column names renamed to NMT convention
- Indicator names in
  [`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md)
  switched to NMT

##### Test Suite Consolidation

- Consolidated dozens of `coverage-boost*`, `batch*` test files into
  direct `test-*.R` files aligned with the real R modules they cover
- Removed dead test files, orphan man pages, and stub functions that
  shadowed real indicator implementations
- Removed Shiny-specific tests from the core package
- Removed unnecessary [`library()`](https://rdrr.io/r/base/library.html)
  calls from test files

#### Bug Fixes

- Fixed dual `save_indicators()` conflict that was breaking NDP
  persistence
- Fixed LiDAR directory (not just file) detection in cache for NDP
- Added filesystem cache fallback for NDP detection
- Fixed W1, S3, P1, P2, P3 indicator failures surfaced during NMT
  migration
- Defined explicit radar display order for the 12 families
- Resolved `%||%` import from rlang and fixed `NAMESPACE` export order
- `hunting` module: suppress expected `download.file` warnings on HTTP
  404 and resolve `data.gouv.fr` URLs dynamically via API
- Removed `microclima` hard dependency

#### Documentation

- Updated README for v0.15.0 — `nemetonshiny` installation instructions,
  NMT names, new badges
- Updated pkgdown site for v0.15.0 — NMT names, NDP, species,
  `nemetonshiny`
- ADR-012 added: future PG extensions (TimescaleDB for continuous
  monitoring, pgvector for RAG perspectives)
- `CLAUDE.md` updated with DDD/NDP/BMAD architecture

------------------------------------------------------------------------

## nemeton 0.14.1

**Date**: 2026-02-18

#### UI Improvements

- Made the recent projects section collapsible using the same Bootstrap
  5 collapse pattern as the commune search and project form sections

#### Bug Fixes

- Fixed namespace issues in i18n and energy indicator tests
- Fixed mock bindings for `lookup_species_threshold` using
  `unlockBinding`
- Suppressed expected OSM tile download warnings in export tests
- Fixed various test stability issues (memory, timeouts, namespace
  prefixes)

#### Documentation

- Updated README with app screenshot and badge updates
- Prepared package for CRAN submission

------------------------------------------------------------------------

## nemeton 0.14.0

**Date**: 2026-02-10

#### Test Suite Stabilization

##### Bug Fixes

- Fixed ExtendedTask global state leak in mod_home retry test that
  blocked mod_project testServer calls when running the full test suite
  - Mock
    [`promises::future_promise`](https://rstudio.github.io/promises/reference/future_promise.html)
    to prevent multisession worker spawning
  - Return terminal state from `read_progress_state` to stop
    [`later::later`](https://later.r-lib.org/reference/later.html)
    polling loop
  - Restore
    [`future::plan`](https://future.futureverse.org/reference/plan.html)
    on exit via
    [`withr::defer`](https://withr.r-lib.org/reference/defer.html)
- Suppressed expected warnings in test-workflow, test-visualization,
  test-mod_map, and test-mod_synthesis
- Renamed test files with z/zz prefix for stable execution ordering

##### Documentation

- Added Mistral API key example in nemetonApp guide vignette

##### Tests

- All 9272 tests passing (0 warnings)
- R CMD check: 0 errors, 0 warnings

------------------------------------------------------------------------

## nemeton 0.13.0

**Date**: 2026-02-08

#### CI/CD Optimization

- Optimized CI workflow with timeout, split check and coverage jobs
- Suppressed expected warnings in test suite (normalize, locale
  patterns)
- Fixed French locale support in match.arg error patterns

------------------------------------------------------------------------

## nemeton 0.12.0

**Date**: 2026-02-05

#### Phase 9 Finalization - MVP 0.7.0 Complete

##### New Features

- **PDF Report Generation** (`generate_report_pdf()`)
  - Quarto-based reports with professional layout
  - Fallback to base R graphics when Quarto unavailable
  - Automatic Quarto installation via `ensure_quarto_installed()`
  - Bilingual support (French/English)
- **GeoPackage Export** (`export_geopackage()`)
  - Export family scores with geometry for GIS analysis
  - Full spatial data preservation
- **nemetonApp Synthesis Tab**
  - AI-generated analysis with expert profiles
  - Integrated comment editor
  - Real-time PDF generation with progress indicator

##### Documentation

- New vignette: “Guide de l’Application nemetonApp”
- Updated README with nemetonApp section
- Enhanced pkgdown reference for Shiny functions

##### Bug Fixes

- Fixed TWI normalization windows for F2 soil fertility (\[2.5, 10\]
  range)
- Fixed R3 drought risk raster extent mismatch
- Fixed non-ASCII characters in service_export.R
- Added data.table to Suggests for fasterRaster compatibility

##### Tests

- All 3447 tests passing
- R CMD check: 0 errors, 0 warnings, 2 notes

## nemeton 0.8.0

**Date**: 2026-01-25

#### New Features

##### nemetonApp - Interactive Shiny Application

- **`run_app()`** - Launch the nemetonApp Shiny application
  - Interactive parcel selection on a map (Leaflet)
  - French commune search with autocomplete
  - Calculate all 31 nemeton indicators automatically
  - Visualize results with 12-family radar charts
  - Export PDF reports and GeoPackage data
  - Bilingual support (French/English)
- **Application Architecture**
  - `app_ui.R` - bslib-based responsive UI with Bootstrap 5
  - `app_server.R` - Modular server with reactive state management
  - `app_config.R` - Configuration constants and indicator families
  - `utils_theme.R` - WCAG 2.1 AA accessible theme
  - `utils_i18n.R` - Internationalization with 200+ messages
- **Accessibility (WCAG 2.1 AA)**
  - Color contrast ratio \>= 4.5:1 for text
  - Colorblind-friendly viridis palettes
  - Minimum touch target 44×44px
  - Focus visible indicators
  - Keyboard navigation support
- **Data Services**
  - `service_communes.R` - French commune search API
  - `service_cadastre.R` - Cadastral parcel retrieval
  - `service_project.R` - Project management and persistence

#### Bug Fixes

- Fixed `\dontrun` missing brace in service_communes.R documentation
- Fixed integer type for symbol_shapes in accessibility config
- Updated indicator count test (29 → 31 indicators)

#### Dependencies

- Added `shiny (>= 1.8.0)` to Imports
- Added `bslib (>= 0.6.0)` to Imports
- Added `htmltools (>= 0.5.7)` to Imports
- Added `leaflet (>= 2.1.0)` to Suggests
- Added `cicerone (>= 1.0.0)` to Suggests (guided tour)
- Added `shinyWidgets (>= 0.8.0)` to Suggests
- Added `rappdirs` to Suggests (project directories)

------------------------------------------------------------------------

## nemeton 0.6.2

**Date**: 2026-01-24

#### Changes

- **Data consolidation**: Merged `massif_demo_units` and
  `massif_demo_units_extended` into a single dataset with 89 columns (29
  indicators, 12 family composites, normalized values)
- **Tests**: Fixed 19 skipped tests, now 1478 tests passing (0 skipped)
- **Documentation**: Simplified README from 846 to 138 lines
- **Fixtures**: Added synthetic cadastral file for integration tests

------------------------------------------------------------------------

## nemeton 0.6.1

**Date**: 2026-01-23

#### Changes

- Fix pkgdown references to obsolete v0.1.0 indicators
- Add lasR remote for GitHub Actions CI

------------------------------------------------------------------------

## nemeton 0.6.0 (Development)

### v0.6.0 - Legacy Indicators Removal

**Date**: 2026-01-23

#### BREAKING CHANGES ⚠️

**Removed Legacy Indicators (v0.1.0)**

The original 5 MVP indicators have been removed in favor of the
comprehensive 12-family framework (32+ indicators). This is a breaking
change for code using v0.1.0 indicators.

##### Removed Functions

- `indicator_carbon()` - **Use instead:** `indicator_carbon_biomass()`
  (C1) or `indicator_carbon_ndvi()` (C2)
- `indicator_biodiversity()` - **Use instead:**
  `indicator_biodiversity_protection()` (B1),
  `indicator_biodiversity_structure()` (B2), or
  `indicator_biodiversity_connectivity()` (B3)
- `indicator_water()` - **Use instead:** `indicator_water_network()`
  (W1), `indicator_water_wetlands()` (W2), or `indicator_water_twi()`
  (W3)
- `indicator_fragmentation()` - **Use instead:**
  `indicator_landscape_fragmentation()` (L1) or
  `indicator_landscape_edge()` (L2)
- `indicator_accessibility()` - **Use instead:**
  `indicator_social_accessibility()` (S2) or `indicator_social_trails()`
  (S1)

##### Migration Guide

**Before (v0.1.0-v0.5.x):**

``` r

# Old API
results <- nemeton_compute(
  units, layers,
  indicators = c("carbon", "biodiversity", "water")
)
```

**After (v0.6.0+):**

``` r

# New API with family-based indicators
results <- nemeton_compute(
  units, layers,
  indicators = c("carbon_biomass", "biodiversity_protection", "water_twi")
)

# Or use list_indicators() to see all available indicators
available <- list_indicators(return_type = "details")
```

##### Updated Core Functions

- [`nemeton_compute()`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md) -
  Now uses
  [`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md)
  for available indicators
- [`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md) -
  Returns all 31 indicators from the 12-family framework
- `compute_indicator()` - Dynamic dispatch supporting all family-based
  indicators

##### Files Removed

- `R/indicators-biophysical.R` - Legacy indicator implementations (567
  lines)
- `tests/testthat/test-indicators-biophysical.R` - Legacy tests (414
  lines, 26 tests)

#### Rationale

The legacy indicators were functional placeholders from the v0.1.0 MVP.
The new 12-family framework (introduced in v0.2.0-v0.4.0) provides:

- **More comprehensive coverage**: 31 indicators vs 5
- **Better scientific foundation**: Species-specific allometric models,
  multiple data sources
- **Clearer organization**: 12 families (C, W, F, L, B, R, T, A, S, P,
  E, N)
- **Improved flexibility**: Multiple sub-indicators per ecosystem
  service

All legacy indicators had superior replacements available since v0.2.0
(January 2026).

------------------------------------------------------------------------

## nemeton 0.5.2

### v0.5.2 - Tutorial 09 Sampling + TSP

**Date**: 2026-01-23

#### New Features

##### Tutorial 09: Échantillonnage de calibration LiDAR HD + TSP (180 min)

- **Dimensionnement optimal** - Calcul du nombre de placettes basé sur
  la formule n = t² × CV² / E²
  - Fonctions `calculate_sample_size()` et `sample_size_table()`
  - Tableau de référence interactif pour CV (10-40%) et erreur (5-20%)
  - Correction pour population finie
- **Sampling Frame** - Construction d’une grille de candidats avec
  contraintes terrain
  - Filtrage par couvert forestier (≥70%) et pente (≤45%)
  - Utilisation des données T01/T03/T07 (zone_etude, bd_foret, mnt,
    chm_complet)
- **Stratification triple** - Basée sur 3 critères forestiers
  - **Hauteur CHM LiDAR** : 4 classes (H1-H4) par quartiles
  - **Type de peuplement** (BD Forêt v2 tfv) : FEU/CON/MIX/POP/AUT
  - **Position topographique** (TPI) : Bas/Milieu/Haut de pente
  - Calcul TPI avec
    [`focal()`](https://rspatial.github.io/terra/reference/focal.html)
    (rayon 100m)
- **Tirage GRTS stratifié** - Échantillonnage spatialement équilibré
  - Package
    [`spsurvey::grts()`](https://usepa.github.io/spsurvey/reference/grts.html)
    avec allocation proportionnelle
  - Oversample par strate pour placettes de remplacement
  - Fallback
    [`BalancedSampling::lpm2`](https://rdrr.io/pkg/BalancedSampling/man/lpm.html)
    si GRTS échoue
- **Réseau de chemins** - Construction réseau avec `sfnetworks` depuis
  BD TOPO
  - Filtrage chemins praticables à pied
  - Calcul poids avec `edge_length()`
- **Optimisation TSP** - Parcours optimal avec package `TSP`
  - Méthode nearest insertion + 2-opt
  - Visualisation avec distinction Base/Remplacement
- **Export terrain** - Formats multiples pour GPS
  - GeoPackage (SIG)
  - GPX (navigation GPS)
  - CSV (tableau récapitulatif avec coordonnées WGS84)

#### Improvements

- **Harmonisation data_dir** - Chemin unifié sur tous les tutoriels
  T01-T09
  - `~/.local/share/nemeton/tutorial_data`
  - Suppression variable `cache_dir` dans T08

#### Dependencies

- Added `spsurvey (>= 5.0.0)` to Suggests
- Added `BalancedSampling (>= 1.6.0)` to Suggests
- Added `sfnetworks (>= 0.6.0)` to Suggests
- Added `TSP (>= 1.2.0)` to Suggests
- Added `tidygraph (>= 1.2.0)` to Suggests
- Added `igraph (>= 1.4.0)` to Suggests

#### Documentation

- Updated `vignettes/tutorial-guide.Rmd` with Tutorial 09
- Updated `TUTORIAL_INSTALL.md` with Tutorial 09

**References**: - Stevens, D. L., & Olsen, A. R. (2004). Spatially
balanced sampling of natural resources. *JASA*, 99(465), 262-278. -
Grafström, A., & Tillé, Y. (2013). Doubly balanced spatial sampling with
spreading and restitution of auxiliary totals. *Environmetrics*, 24(2),
120-131. - Hahsler, M., & Hornik, K. (2007). TSP—Infrastructure for the
traveling salesperson problem. *Journal of Statistical Software*, 23(2).

------------------------------------------------------------------------

## nemeton 0.5.1

### v0.5.1 - Tutorial 08 Coregistration

**Date**: 2025-01-18

#### New Features

##### Tutorial 08: Coregistration LiDAR/Terrain (130 min)

- **Problématique GPS** - Précision GPS sous couvert forestier (2-10 m)
- **Corrélation MNH/Terrain** - Recalage par corrélation croisée
- **lidaRtRee::coregistration()** - Recherche translation optimale (dx,
  dy)
- **Traitement parallèle** - `future_lapply()` pour lots de placettes
- **Analyse statistique** - Tests de significativité, visualisation
  vecteurs
- **Export** - CSV et GeoPackage pour utilisation SIG

#### Documentation

- Updated `vignettes/tutorial-guide.Rmd` with Tutorial 08
- Updated `TUTORIAL_INSTALL.md` with Tutorial 08

**Reference**: Monnet, J.-M., & Mermin, É. (2014). Cross-correlation of
diameter measures for the co-registration of forest inventory plots with
airborne laser scanning data. *Forests*, 5(9), 2307-2326.

------------------------------------------------------------------------

## nemeton 0.5.0

### v0.5.0 - Tutorial 07 & CRAN Compliance

**Date**: 2025-01-18

#### Overview

Release featuring the complete Tutorial 07 (Advanced LiDAR) and CRAN
compliance improvements. All 7 interactive tutorials are now complete
(195/195 tasks).

#### New Features

##### Tutorial 07: LiDAR Avancé (90 min)

- **LAScatalog Management** - Multi-tile LiDAR processing with lidR
- **lasR Pipelines** - Ultra-fast C++ processing for DTM/CHM generation
- **Individual Tree Detection (ITD)** - Tree segmentation with lidaRtRee
- **Gap & Edge Detection** - Forest structure analysis
- **Area-Based Approach (ABA)** - Model calibration and wall-to-wall
  prediction
- **BABA Exploration** - Rapid LiDAR metrics without field calibration
- **Parallelization** - `future_lapply()` for tile-based processing
- **Incremental Caching** - Resume interrupted processing
- **OSO Forest Mask** - Land cover filtering for predictions

#### Dependencies

- Added `lasR` to Suggests (from r-lidar.r-universe.dev)
- Added `lidaRtRee` to Suggests

#### Documentation

- Updated `vignettes/tutorial-guide.Rmd` with Tutorial 07
- Updated `TUTORIAL_INSTALL.md` with lasR/lidaRtRee installation
- Updated quickstart guide with Tutorial 07 instructions

#### CRAN Compliance

- Removed development artifacts (RELEASE\_\*.md, .RData, .Rhistory,
  etc.)
- Updated `.Rbuildignore` and `.gitignore`
- Excluded spec-kit directories from version control

------------------------------------------------------------------------

## nemeton 0.4.0

### v0.4.0 - Complete 12-Family Ecosystem Services Referential

**Date**: 2026-01-05

#### Overview

Major release completing the **12-family ecosystem services
referential** with 4 new indicator families (S, P, E, N) and advanced
multi-criteria analysis tools. This release adds 11 new indicator
functions, 3 analysis functions, and brings the total to **29 indicators
across 12 families**.

#### New Indicator Families

##### Social & Recreational Family (Famille S) - 3 Indicators

- **`indicator_social_trails()`** (S1) - Trail density
  - Calculates recreational trail density (km/ha) from OSM or local data
  - Supports footways, cycleways, and bridleways
  - Output: 0-5+ km/ha trail density
- **`indicator_social_accessibility()`** (S2) - Multimodal accessibility
  score
  - Distance-based scoring for road, parking, and public transport
    access
  - Configurable distance thresholds and weights
  - Output: 0-100 accessibility score
- **`indicator_social_proximity()`** (S3) - Population proximity
  - Population within configurable buffer zones (5/10/20 km)
  - Supports INSEE population grid or custom data
  - Output: Total population count within buffers

##### Productive & Economic Family (Famille P) - 3 Indicators

- **`indicator_productive_volume()`** (P1) - Standing timber volume
  - IFN-based allometric equations by species
  - Genus-level fallback for rare species
  - Output: m³/ha standing volume
- **`indicator_productive_station()`** (P2) - Site productivity index
  - Fertility × climate × species interaction
  - Based on French forestry station classification
  - Output: m³/ha/yr potential productivity
- **`indicator_productive_quality()`** (P3) - Timber quality score
  - Form factor, diameter distribution, defect assessment
  - Configurable quality criteria weights
  - Output: 0-100 quality score

##### Energy & Climate Family (Famille E) - 2 Indicators

- **`indicator_energy_fuelwood()`** (E1) - Fuelwood potential
  - Harvest residues + coppice biomass estimation
  - Species-specific conversion factors
  - Output: tonnes DM/ha/yr mobilizable fuelwood
- **`indicator_energy_avoidance()`** (E2) - CO2 emission avoidance
  - ADEME emission factors for energy substitution
  - Supports energy and material substitution scenarios
  - Output: tCO2eq/ha/yr avoided emissions

##### Naturalness & Wilderness Family (Famille N) - 3 Indicators

- **`indicator_naturalness_distance()`** (N1) - Infrastructure distance
  - Distance to roads, buildings, powerlines from OSM
  - Minimum distance to nearest infrastructure
  - Output: meters to nearest infrastructure
- **`indicator_naturalness_continuity()`** (N2) - Forest patch
  continuity
  - Connected forest area calculation
  - Based on landscape patch analysis
  - Output: hectares of continuous forest
- **`indicator_naturalness_composite()`** (N3) - Wilderness composite
  index
  - Multiplicative aggregation of N1 × N2 × T1 × B1
  - Weighted aggregation option available
  - Output: 0-100 wilderness score

#### New Analysis Functions

##### Multi-Criteria Decision Support

- **[`identify_pareto_optimal()`](https://pobsteta.github.io/nemeton/reference/identify_pareto_optimal.md)** -
  Pareto optimality analysis
  - Identifies non-dominated solutions across multiple objectives
  - Supports both maximization and minimization objectives
  - Returns data with `is_optimal` column for Pareto-optimal parcels
- **[`cluster_parcels()`](https://pobsteta.github.io/nemeton/reference/cluster_parcels.md)** -
  Multi-family clustering
  - K-means and hierarchical clustering methods
  - Automatic optimal k determination via silhouette analysis
  - Returns cluster assignments with centroid profiles
- **[`plot_tradeoff()`](https://pobsteta.github.io/nemeton/reference/plot_tradeoff.md)** -
  Trade-off visualization
  - 2D scatterplot with optional Pareto frontier overlay
  - Color and size mapping for additional dimensions
  - Label support for parcel identification

#### Enhanced Features

- **12-axis radar plots** -
  [`nemeton_radar()`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md)
  now supports all 12 families
- **12×12 correlation matrix** -
  [`compute_family_correlations()`](https://pobsteta.github.io/nemeton/reference/compute_family_correlations.md)
  extended
- **12-family hotspot detection** -
  [`identify_hotspots()`](https://pobsteta.github.io/nemeton/reference/identify_hotspots.md)
  updated
- **Normalization presets** - Added for S, P, E, N families

#### New Demo Dataset

- **`massif_demo_units_extended`** - Complete 12-family reference
  dataset
  - 20 demo parcels with all 29 indicators
  - 12 pre-calculated family composite indices
  - Synthetic but realistic value distributions

#### New Vignettes

- **`complete-referential_fr.Rmd`** - 12-family workflow demonstration
- **`multi-criteria-optimization_fr.Rmd`** - Pareto, clustering, and
  trade-off analysis

#### Dependencies

- Added `cluster` package dependency for silhouette analysis
- Added `ggrepel` to Suggests for label positioning

#### Documentation

- Updated README with v0.4.0 feature highlights
- Updated pkgdown site configuration
- Full roxygen2 documentation for all new functions

------------------------------------------------------------------------

## nemeton 0.3.0 (Development)

### v0.3.0 MVP - Multi-Family Extension (B, R, T, A)

**Status**: ✅ v0.3.0 Complete (845+ tests passing, 100% backward
compatible)

#### Overview

Extension of the ecosystem service indicator framework with 4 new
families (B, R, T, A), bringing the total to **9 of 12 planned
families** implemented. This release adds 10 new indicator functions and
enhances the family aggregation and visualization system.

#### New Indicator Families

##### Biodiversity Family (Famille B) - 3 Indicators

- **`indicator_biodiversity_protection()`** (B1) - Protected area
  coverage
  - Calculates percentage of forest parcel within protected zones
    (ZNIEFF, Natura2000, etc.)
  - Supports local or remote protected area datasets
  - Output: 0-100% protection coverage
  - Spatial overlay with area-weighted calculation
- **`indicator_biodiversity_structure()`** (B2) - Structural diversity
  index
  - Shannon diversity index across vegetation strata, age classes, and
    species
  - Configurable weights for each diversity component (default: strata
    0.4, age 0.3, species 0.3)
  - Optional height coefficient of variation (CV) integration
  - Output: 0-100 diversity score
  - Handles monoculture scenarios (low diversity → low scores)
- **`indicator_biodiversity_connectivity()`** (B3) - Ecological
  connectivity
  - Distance to ecological corridors (TVB - Trame Verte et Bleue)
  - Supports edge and centroid distance methods
  - Configurable max distance threshold (default: 5000m)
  - Fallback scoring when corridor data unavailable
  - Output: Distance in meters (lower = better connectivity)

##### Risk & Resilience Family (Famille R) - 3 Indicators

- **`indicator_risk_fire()`** (R1) - Fire risk index
  - Multi-factor fire susceptibility: slope + species + climate
  - Species flammability coefficients (conifer \> broadleaf)
  - Slope amplification (higher slope = faster fire spread)
  - Optional climate data integration (temperature, precipitation)
  - Output: 0-100 risk score (higher = more vulnerable)
- **`indicator_risk_storm()`** (R2) - Storm vulnerability index
  - Wind damage risk: tree height × stand density × exposure
  - Height coefficient (taller trees more vulnerable)
  - Density factor (dense stands = higher windthrow risk)
  - Topographic exposure from DEM (exposed ridges = higher risk)
  - Output: 0-100 vulnerability score
- **`indicator_risk_drought()`** (R3) - Drought stress index
  - Combines water availability (TWI) and species drought tolerance
  - Species tolerance coefficients (drought-resistant
    vs. water-demanding)
  - Optional precipitation data integration
  - Low TWI + intolerant species = high stress
  - Output: 0-100 stress score

##### Temporal Dynamics Family (Famille T) - 2 Indicators

- **`indicator_temporal_age()`** (T1) - Stand age/ancientness
  - Historical forest age from BD Forêt or Cassini maps
  - Ancient forest detection (age \> 150 years)
  - Supports multi-source age estimation
  - Output: Years since establishment (or age class)
  - Handles missing historical data gracefully
- **`indicator_temporal_change()`** (T2) - Land cover change rate
  - Temporal change detection using Corine Land Cover multi-dates
  - Calculates change rate between two periods
  - Supports custom date ranges
  - Identifies stable vs. dynamic forests
  - Output: % change per year (or absolute area change)
  - Leverages existing nemeton_temporal() infrastructure

##### Air Quality & Microclimate Family (Famille A) - 2 Indicators

- **`indicator_air_coverage()`** (A1) - Tree canopy coverage
  - Percentage of tree cover within 1km buffer
  - High-resolution vegetation data (sentinel-2 or lidar-derived)
  - Urban microclimate regulation potential
  - Output: 0-100% coverage in buffer zone
  - Supports custom buffer distances
- **`indicator_air_quality()`** (A2) - Air quality index
  - Integration with ATMO air quality data (when available)
  - Fallback: distance to pollution sources (roads, industry)
  - Supports custom air quality datasets
  - Output: 0-100 air quality score (higher = better)
  - Proxy mode for areas without monitoring stations

#### Extended Functions

- **[`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md) -
  New “min” aggregation method**
  - Added conservative worst-case aggregation: `method = "min"`
  - Useful for risk assessment (score = worst sub-indicator)
  - Joins existing methods: mean, weighted, geometric, harmonic
  - Example: `create_family_index(data, method = "min")`
- **[`nemeton_radar()`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md) -
  Comparison mode for multiple units**
  - New: compare multiple forest parcels on same radar chart
  - Overlaid polygons for visual comparison
  - Syntax:
    `nemeton_radar(data, unit_id = c(1, 5, 10), mode = "family")`
  - Supports 9-12 axes dynamically (adapts to available families)
  - Enhanced legend and color differentiation

#### Testing

- **186 new tests** for v0.3.0 families
  - Biodiversity (B1-B3): 56 tests (protection zones, diversity indices,
    corridors)
  - Risk (R1-R3): 52 tests (fire models, storm factors, drought stress)
  - Temporal (T1-T2): 38 tests (historical data, change detection)
  - Air (A1-A2): 28 tests (coverage buffers, quality indices)
  - Integration: 12 tests (multi-family workflows, normalization, radar)
- **Total test suite: 845+ tests passing** (up from 659)
- **100% backward compatibility verified** with v0.2.0 workflows

#### Use Cases

- **Conservation prioritization**: Identify high biodiversity + low risk
  parcels
- **Climate adaptation planning**: Map drought stress + storm
  vulnerability
- **Urban forestry**: Quantify air quality and microclimate benefits
- **Historical ecology**: Detect ancient forests + track land use change
- **Multi-criteria decision support**: 9-family composite indices for
  holistic management

#### Implemented Families Status (9/12)

- ✅ **C** - Carbon & Vitality (C1-C2)
- ✅ **B** - Biodiversity (B1-B3) - **NEW v0.3.0**
- ✅ **W** - Water Regulation (W1-W3)
- ✅ **A** - Air Quality & Microclimate (A1-A2) - **NEW v0.3.0**
- ✅ **F** - Soil Fertility (F1-F2)
- ✅ **L** - Landscape & Aesthetics (L1-L2)
- ✅ **T** - Temporal Dynamics & Trame (T1-T2) - **NEW v0.3.0**
- ✅ **R** - Risk Management & Resilience (R1-R3) - **NEW v0.3.0**
- ⏳ **S** - Social & Recreational (planned v0.4.0)
- ⏳ **P** - Productive & Economic (planned v0.4.0)
- ⏳ **E** - Energy & Climate (planned v0.4.0)
- ⏳ **N** - Naturalness & Night (planned v0.4.0)

------------------------------------------------------------------------

## nemeton 0.2.0 (Development)

### v0.2.0 - Phase 9: Multi-Family System (US6)

**Status**: ✅ Phase 9 Complete (659 tests passing, +46 from Phase 8)

#### New Functions

##### Multi-Family Aggregation & Visualization

- **[`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)** -
  Family-level composite scores
  - Aggregates sub-indicators into family indices (family_C, family_W,
    etc.)
  - Automatic detection of family prefixes (C1, C2 → family_C)
  - 4 aggregation methods: mean, weighted, geometric, harmonic
  - Custom weights per family
  - Supports all 12 families (C, B, W, A, F, L, T, R, S, P, E, N)
  - Returns sf object with added family\_\* columns

#### Extended Functions

- **[`normalize_indicators()`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md)
  family support**
  - Added `by_family` parameter for family-aware workflows
  - Auto-detection of family indicators (C1, W1, F1 pattern)
  - Backward compatible with v0.1.0 indicators (carbon, water, etc.)
  - When `by_family = TRUE`: normalizes in-place (suffix = ““,
    keep_original = FALSE)
- **[`nemeton_radar()`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md)
  multi-family mode**
  - New `mode` parameter: “indicator” (default) or “family”
  - Family mode: displays 4-12 family axes dynamically
  - Auto-detects family\_\* columns when mode = “family”
  - Backward compatible with indicator mode
  - Enhanced unit_id handling: supports both ID matching and numeric row
    indices

#### Helper Functions (Internal)

- **[`detect_indicator_family()`](https://pobsteta.github.io/nemeton/reference/detect_indicator_family.md)** -
  Extract family code from indicator name
- **[`get_family_name()`](https://pobsteta.github.io/nemeton/reference/get_family_name.md)** -
  Full family name from code (bilingual FR/EN)

#### Testing

- **46 new tests** for multi-family system
  - create_family_index(): 9 tests (aggregation methods, weights, NA
    handling)
  - normalize_indicators() family support: 3 tests (auto-detection,
    by_family mode)
  - nemeton_radar() family mode: 4 tests (multi-family display,
    validation)
  - Integration: 5 tests (end-to-end workflows, temporal integration)
  - Family detection: 2 tests (all 12 families)
- **Total test suite: 659 tests passing** (up from 613)
- **2 minor test issues**: plot data structure check, locale-dependent
  error message
- **Full backward compatibility maintained**

#### Technical Details

- **Family Detection**: Regex pattern `^[A-Z][0-9]` matches C1, W1, F1,
  etc.
- **Aggregation Methods**:
  - Mean/Weighted: Handles NA values with weight renormalization
  - Geometric: `exp(mean(log(values)))` with negative value handling
  - Harmonic: `n / sum(1/x)` with zero value handling
- **12 Family Codes**:
  - C (Carbon & Vitality), B (Biodiversity), W (Water Regulation)
  - A (Air Quality & Microclimate), F (Soil Fertility), L (Landscape &
    Aesthetics)
  - T (Temporal Dynamics), R (Risk Management), S (Social &
    Recreational)
  - P (Productive & Economic), E (Energy & Climate), N (Naturalness)

#### Use Cases

- **Multi-dimensional assessment**: Compare ecosystem services across 12
  families
- **Custom weighting**: Priority to specific families (e.g., 60% carbon,
  40% water)
- **Radar visualization**: Visual profiling of forest parcels across all
  families
- **Family-level reporting**: Aggregate detailed indicators into
  comprehensible family scores

------------------------------------------------------------------------

### v0.2.0 - Phase 8: Infrastructure Multi-Temporelle (US1)

**Status**: ✅ Phase 8 Complete (613 tests passing)

#### New Functions

##### Temporal Analysis Framework - 2 Core Functions + 2 Visualizations

- **[`nemeton_temporal()`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md)** -
  Multi-period temporal dataset creation
  - Combines nemeton_units objects from different time periods
  - Automatic unit alignment tracking across periods
  - Support for ISO dates and custom period labels
  - Metadata: dates, period labels, alignment status
  - Returns nemeton_temporal S3 class with print/summary methods
- **[`calculate_change_rate()`](https://pobsteta.github.io/nemeton/reference/calculate_change_rate.md)** -
  Temporal change rate calculation
  - Computes absolute change rates (units per year)
  - Computes relative change rates (% per year)
  - Supports indicator selection or “all” indicators
  - Configurable start/end periods
  - Handles NA values appropriately
  - Returns sf object with \_rate_abs and \_rate_rel columns
- **[`plot_temporal_trend()`](https://pobsteta.github.io/nemeton/reference/plot_temporal_trend.md)** -
  Time-series line plots
  - Line plots showing indicator evolution over time
  - Single indicator: all units on one plot
  - Multiple indicators: faceted plots (2 columns)
  - Optional mean trend line overlay
  - Unit selection support
  - Automatic date handling from temporal metadata
- **[`plot_temporal_heatmap()`](https://pobsteta.github.io/nemeton/reference/plot_temporal_heatmap.md)** -
  Indicator evolution heatmap
  - Heatmap showing all indicators across periods for one unit
  - Optional normalization to 0-100 scale
  - Viridis color scale
  - Value labels on tiles
  - Indicator selection support
  - Useful for single-unit profiling

#### S3 Methods

- **[`print.nemeton_temporal()`](https://pobsteta.github.io/nemeton/reference/print.nemeton_temporal.md)** -
  Console summary
  - Shows number of periods and units
  - Date range if available
  - Warns about incomplete alignment
  - Lists available indicators
- **[`summary.nemeton_temporal()`](https://pobsteta.github.io/nemeton/reference/summary.nemeton_temporal.md)** -
  Detailed statistics
  - Per-period summaries (unit counts, indicator ranges)
  - Mean values for each indicator per period
  - Alignment information

#### Technical Details

- **Temporal Framework**:
  - Unit ID tracking with configurable column (default: “parcel_id”)
  - Automatic alignment detection (units present in all periods
    vs. incomplete)
  - Flexible date handling (ISO dates, years, or custom labels)
  - Preserves all sf attributes and geometry
- **Change Rates**:
  - Time difference calculation from dates or period names
  - Absolute rate: `(value_end - value_start) / years`
  - Relative rate: `((value_end / value_start) - 1) * 100 / years`
  - NA propagation for missing data
- **Visualizations**:
  - ggplot2-based with theme_minimal
  - Date axis with automatic formatting
  - Faceting for multiple indicators
  - Viridis colormap for heatmaps
  - Responsive layouts (legend positions, text angles)

#### Testing

- **79 new tests** for temporal infrastructure
  - nemeton_temporal(): 13 tests (creation, alignment, validation)
  - calculate_change_rate(): 13 tests (absolute/relative rates, NA
    handling)
  - print/summary methods: 3 tests (output format)
  - plot_temporal_trend(): 11 tests (single/multiple indicators, unit
    selection)
  - plot_temporal_heatmap(): 10 tests (normalization, indicator
    selection)
  - Integration: 4 tests (multi-period workflows, 3+ periods)
- **Total test suite: 613 tests passing** (up from 584)
- **Full backward compatibility maintained**

#### Use Cases

- **Longitudinal monitoring**: Track indicator evolution over 5-10+
  years
- **Management impact**: Compare before/after forest intervention
- **Climate change**: Detect long-term trends in carbon stock, water
  regulation
- **Scenario comparison**: Visualize different management trajectories

------------------------------------------------------------------------

### v0.2.0 - Phase 7: Famille L (Landscape/Paysage)

**Status**: ✅ Phase 7 Complete (584 tests passing)

#### New Indicator Functions

##### Landscape Family (Famille L) - 2 Indicators

- **`indicator_landscape_fragmentation()`** (L1) - Forest fragmentation
  metric
  - Counts number of forest patches within a buffer zone around each
    parcel
  - Uses connected component labeling (terra::patches with 8-neighbor
    connectivity)
  - Configurable buffer distance (default: 1000m)
  - Configurable forest definition via landcover codes
  - Output: Number of discrete forest patches (higher = more fragmented)
  - Zero buffer option for parcel-only analysis
- **`indicator_landscape_edge()`** (L2) - Edge-to-area ratio
  - Calculates perimeter-to-area ratio for forest parcels
  - Formula: `Edge density = perimeter (m) / area (ha)`
  - Higher values indicate greater edge effect and fragmentation
  - Output: m/ha (meters of edge per hectare)
  - Uses sf geometry operations for precise boundary calculations

#### Technical Details

- **L1 Fragmentation**:
  - Buffer zone creation using sf::st_buffer()
  - Landcover cropping and masking with terra
  - Forest mask creation using terra::app() with custom classification
  - Connected component analysis: terra::patches(directions = 8)
  - Handles zero-forest scenarios gracefully
- **L2 Edge Density**:
  - Boundary extraction: sf::st_cast() to MULTILINESTRING
  - Perimeter calculation: sf::st_length()
  - Area calculation: sf::st_area() converted to hectares
  - No dependencies on raster layers (geometry-only)

#### Testing

- **49 new tests** for landscape family indicators
  - L1 fragmentation: 13 tests (patch counting, buffer effects, forest
    definitions)
  - L2 edge: 11 tests (geometry scaling, parcel size effects,
    validation)
  - Integration: 8 tests (combined workflow, dataframe integration,
    correlation analysis)
  - Edge cases: 5 tests (empty units, single parcels, full dataset)
- **Total test suite: 584 tests passing** (up from 535)
- **Full backward compatibility maintained**

------------------------------------------------------------------------

### v0.2.0 - Phase 6: Famille F (Fertilité des Sols)

**Status**: ✅ Phase 6 Complete (535 tests passing)

#### New Indicator Functions

##### Soil Family (Famille F) - 2 Indicators

- **`indicator_soil_fertility()`** (F1) - Soil fertility classification
  - Extracts fertility scores from soil data (raster or vector)
  - Supports BD Sol (French soil database) or equivalent pedological
    data
  - Output: 0-100 scale (higher = more fertile)
  - Auto-normalizes input values to 0-100 range
  - Supports both raster and vector soil layers (with area-weighted
    averaging)
- **`indicator_soil_erosion()`** (F2) - Erosion risk index
  - Calculates erosion risk by combining slope and land cover protection
  - Formula: `Risk = slope × (1 - forest_protection)`
  - High slope + low forest cover = high erosion risk
  - Output: 0-100 risk score
  - Uses terra for slope calculation and land cover analysis

#### Internal Utilities

- **Soil Data Extraction**
  - `extract_fertility_from_raster()` - Raster-based fertility
    extraction
  - `extract_fertility_from_vector()` - Vector-based fertility with
    spatial join
  - Area-weighted averaging for overlapping soil polygons
  - Automatic CRS harmonization

#### Testing

- **37 new tests** for soil family indicators
  - F1 fertility: 11 tests (raster/vector extraction, normalization,
    error handling)
  - F2 erosion: 17 tests (slope-cover combination, forest definitions,
    edge cases)
  - Integration: 9 tests (combined workflow, correlation analysis,
    dataframe integration)
  - 1 skipped test (vector soil data - future enhancement)
- **Total test suite: 535 tests passing** (up from 498)
- **Full backward compatibility maintained**

#### Technical Details

- **F1 Fertility**:
  - Flexible input: accepts any raster or vector soil layer
  - Linear normalization: `(value - min) / (max - min) × 100`
  - Vector mode: area-weighted spatial join with soil polygons
- **F2 Erosion**:
  - Slope from DEM using `terra::terrain(v="slope")`
  - Forest mask using
    [`terra::app()`](https://rspatial.github.io/terra/reference/app.html)
    for multi-value classification
  - Protection factor: 1 = full forest, 0 = no forest
  - Normalized to 0-100 scale (max slope = 90°)

------------------------------------------------------------------------

### v0.2.0 - Phase 5: Famille W (Eau/Infiltrée)

**Status**: ✅ Phase 5 Complete (498 tests passing)

#### New Indicator Functions

##### Water Family (Famille W) - 3 Indicators

- **`indicator_water_network()`** (W1) - Hydrographic network density
  - Calculates stream/river network length density within or near forest
    parcels
  - Supports buffer distance parameter for proximity analysis
  - Output: km/ha (kilometers of watercourse per hectare)
  - Higher values = greater hydrological connectivity
- **`indicator_water_wetlands()`** (W2) - Wetland coverage percentage
  - Calculates percentage of parcel area classified as wetland or
    riparian zone
  - Supports multiple wetland type codes from landcover rasters
  - Output: 0-100% coverage
  - Area-weighted calculation using coverage fractions
- **`indicator_water_twi()`** (W3) - Topographic Wetness Index
  - Calculates TWI using terra D8 flow algorithm
  - Formula: `TWI = ln(catchment_area / tan(slope))`
  - Automatically handles flat areas and edge cases
  - Output: TWI values (typically 0-20, higher = wetter areas)
  - Future: whitebox D-infinity algorithm support (v0.3.0+)

#### Internal Utilities

- **TWI Calculation System**
  - `calculate_twi_terra()` - D8 flow direction algorithm
  - Slope-based flow accumulation
  - Catchment area calculation
  - Handles numerical edge cases (flat areas, infinite values)
  - `calculate_twi_whitebox()` - Placeholder for future D-infinity
    implementation

#### Testing

- **51 new tests** for water family indicators
  - W1 network: 13 tests (density calculation, buffer zones, zero-stream
    parcels)
  - W2 wetlands: 14 tests (percentage calculation, multiple codes, zero
    coverage)
  - W3 TWI: 16 tests (DEM processing, method validation, terrain
    variation)
  - Integration: 8 tests (combined workflow, dataframe integration)
- **Total test suite: 498 tests passing** (up from 447)
- **Full backward compatibility maintained**

#### Technical Details

- **W1 Network Density**: Uses sf spatial operations for line-polygon
  intersection
- **W2 Wetland Coverage**: Uses exactextractr for area-weighted raster
  value extraction
- **W3 TWI**: Terra hydrology functions (`terrain(v="flowdir")`,
  [`flowAccumulation()`](https://rspatial.github.io/terra/reference/flowAccumulation.html))
- **Flow algorithm**: D8 (8-neighbor) for computational efficiency
- **Coordinate transformations**: Automatic CRS harmonization for vector
  layers

------------------------------------------------------------------------

### v0.2.0 - Phase 4: Famille C (Carbone/Énergétique)

**Status**: ✅ Phase 4 Complete (447 tests passing)

#### New Indicator Functions

##### Carbon Family (Famille C) - 2 Indicators

- **`indicator_carbon_biomass()`** (C1) - Aboveground carbon stock using
  species-specific allometric equations
  - Requires: BD Forêt v2 attributes (species, age, density)
  - Species support: Quercus, Fagus, Pinus, Abies, + Generic fallback
  - Allometric model: `Biomass = a × Age^b × Density^c`
  - Output: tC/ha (tonnes carbon per hectare)
  - Citations: IGN/IFN literature (Dupouey, Bontemps, Vallet, Wutzler)
- **`indicator_carbon_ndvi()`** (C2) - Vegetation vitality via NDVI
  - Requires: Sentinel-2 or equivalent NDVI raster (0-1 scale)
  - Output: Mean NDVI per forest parcel
  - Future: Temporal trend analysis (v0.3.0+)

#### Internal Data & Utilities

- **Allometric Model System** (`R/sysdata.rda`)
  - 5 species-specific coefficient sets
  - Calibrated for realistic French forest biomass (50-200 tC/ha mature
    stands)
  - Source: `data-raw/allometric_models.R`
- **New Utility Functions** (internal)
  - `get_allometric_coefficients()` - Species-specific coefficient
    lookup
  - `calculate_allometric_biomass()` - Vectorized biomass calculation
  - [`detect_indicator_family()`](https://pobsteta.github.io/nemeton/reference/detect_indicator_family.md) -
    Extract family code from indicator name
  - [`get_family_name()`](https://pobsteta.github.io/nemeton/reference/get_family_name.md) -
    Full family name from code

#### Deprecations

- **`indicator_carbon()`** - Now deprecated (will be removed in v1.0.0)
  - Replacement: Use `indicator_carbon_biomass()` for BD Forêt support,
    or `indicator_carbon_ndvi()` for NDVI
  - Backward compatibility: Function still works with deprecation
    warning
  - All existing workflows continue to function

#### Testing

- **38 new tests** for carbon family indicators
  - C1 biomass: 15 tests (allometric calculations, NA handling, column
    names, Generic fallback)
  - C2 NDVI: 10 tests (raster extraction, edge values, trend warning)
  - Integration: 8 tests (backward compatibility, nemeton_compute
    integration)
  - Edge cases: 5 tests (missing columns, invalid inputs, error
    messages)
- **Total test suite: 447 tests passing** (up from 409)
- **Full backward compatibility verified**

#### Technical Details

- **Allometric coefficients** calibrated to produce realistic biomass
  values:
  - Young/sparse stands: 2-10 tC/ha
  - Mature forests: 50-200 tC/ha
  - Age exponent (b): 1.55-1.75
  - Density exponent (c): 0.80-0.90
- **NA propagation**: Properly handles missing species, age, or density
  data

------------------------------------------------------------------------

## nemeton 0.1.0-rc1 (2026-01-04)

### MVP Release Candidate

**Status**: ✅ 97% Complete (32/33 requirements) - Ready for testing

#### Major Features

##### Core Functionality (✅ Complete)

- **Spatial Analysis Engine**:
  [`nemeton_compute()`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)
  with 5 biophysical indicators
- **Automatic Preprocessing**: CRS harmonization, extent cropping
- **Error Resilience**: Per-indicator error handling (continues if one
  fails)
- **Lazy Loading**: Memory-efficient layer catalog system

##### Indicators (✅ 5/5 Complete)

- `indicator_carbon()` - Carbon stock from biomass (Mg C/ha)
- `indicator_biodiversity()` - Species richness / Shannon index
- `indicator_water()` - Water regulation (TWI + proximity to streams)
- `indicator_fragmentation()` - Forest coverage and connectivity
- `indicator_accessibility()` - Distance to roads and trails

##### Normalization & Indices (✅ Complete)

- [`normalize_indicators()`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md) -
  3 methods (min-max, z-score, quantile)
- [`create_composite_index()`](https://pobsteta.github.io/nemeton/reference/create_composite_index.md) -
  Weighted aggregation (4 methods)
- [`invert_indicator()`](https://pobsteta.github.io/nemeton/reference/invert_indicator.md) -
  Reverse polarity for negative indicators
- Reference-based normalization support

##### Visualization (⚠️ 3/4 - Radar pending)

- [`plot_indicators_map()`](https://pobsteta.github.io/nemeton/reference/plot_indicators_map.md) -
  Thematic choropleth maps (single + faceted)
- [`plot_comparison_map()`](https://pobsteta.github.io/nemeton/reference/plot_comparison_map.md) -
  Side-by-side scenario comparison
- [`plot_difference_map()`](https://pobsteta.github.io/nemeton/reference/plot_difference_map.md) -
  Absolute and relative change visualization
- Multiple palettes: viridis, RdYlGn, Greens, Blues, etc.

##### Demo Dataset (✅ Complete)

- `massif_demo` - Synthetic forest data (136 ha, 20 parcels)
- 4 rasters at 25m: biomass, DEM, landcover, species richness
- 2 vector layers: roads (5), water courses (3)
- Lambert-93 projection (EPSG:2154)
- Reproducible generation script (`data-raw/massif_demo.R`)

##### Internationalization (✅ Bonus Feature)

- **Bilingual Support**: French + English (200+ messages)
- **Auto-detection**: System locale detection
- **Manual Override**: `nemeton_set_language("fr")` /
  `nemeton_set_language("en")`
- **Complete Coverage**: All user-facing messages translated
- Dedicated vignette: `internationalization.Rmd`

#### Exported Functions (17)

**Core**:
[`nemeton_units()`](https://pobsteta.github.io/nemeton/reference/nemeton_units.md),
[`nemeton_layers()`](https://pobsteta.github.io/nemeton/reference/nemeton_layers.md),
[`nemeton_compute()`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md),
[`massif_demo_layers()`](https://pobsteta.github.io/nemeton/reference/massif_demo_layers.md)
**Indicators**: `indicator_carbon()`, `indicator_biodiversity()`,
`indicator_water()`, `indicator_fragmentation()`,
`indicator_accessibility()` **Normalization**:
[`normalize_indicators()`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md),
[`create_composite_index()`](https://pobsteta.github.io/nemeton/reference/create_composite_index.md),
[`invert_indicator()`](https://pobsteta.github.io/nemeton/reference/invert_indicator.md)
**Visualization**:
[`plot_indicators_map()`](https://pobsteta.github.io/nemeton/reference/plot_indicators_map.md),
[`plot_comparison_map()`](https://pobsteta.github.io/nemeton/reference/plot_comparison_map.md),
[`plot_difference_map()`](https://pobsteta.github.io/nemeton/reference/plot_difference_map.md)
**Utilities**:
[`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md),
[`nemeton_set_language()`](https://pobsteta.github.io/nemeton/reference/nemeton_set_language.md)

#### Documentation (✅ Complete)

- **README.md**: Comprehensive quick start guide (497 lines)
- **Vignettes**:
  - `getting-started.Rmd` - Full workflow with massif_demo
  - `internationalization.Rmd` - i18n guide (FR/EN)
- **Roxygen2**: All 17 exported functions fully documented
- **Examples**: Executable examples in all function docs

#### Testing (✅ 225+ Tests)

- **Unit Tests**: Comprehensive coverage across all modules
- **Integration Tests**: End-to-end workflow validation
- **Real Data Tests**: French cadastral parcel testing
- **Fixtures**: Helper functions for test data generation

#### Package Metrics

- **R Code**: ~2,500 lines
- **Tests**: ~2,100 lines
- **Dataset Size**: 0.81 Mo (\< 5 Mo target)
- **Functions**: 17 exported
- **Vignettes**: 2
- **i18n Messages**: 200+ (FR/EN)

#### Quick Start Example

``` r

library(nemeton)

# 5-line workflow
data(massif_demo_units)
layers <- massif_demo_layers()
results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
normalized <- normalize_indicators(results, method = "minmax")
plot_indicators_map(normalized, palette = "viridis")
```

### Known Issues

- ⚠️ Minor test fixture compatibility issue (to be fixed in v0.1.0
  final)
- ⚠️ Test coverage measurement pending (covr fails due to test issues)
- 📝 User Story 4 (radar chart) not implemented (P3 - optional for MVP)

### Roadmap to v0.1.0

Fix test fixtures

Verify
[`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
passes

Measure test coverage (target: ≥70%)

Optional: Implement
[`nemeton_radar()`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md)
(P3)

### Breaking Changes

- None (initial release)

### Credits

Developed with ❤️ and [Claude Code](https://claude.com/claude-code)
**Contributors**: Pascal Obstétar, Claude Sonnet 4.5
