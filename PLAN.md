# PLAN — Walking Skeleton & chantier en cours (cœur `nemeton`)

**Source unique de vérité** pour la séquence des épaississements (E1, E2, …) du **package cœur `nemeton`** et leur état d'avancement. CLAUDE.md ne duplique plus cette table (règle introduite le 2026-04-25). À chaque release cœur, mettre à jour la table ci-dessous + le journal du chantier en cours (cf. *Consignes de release* étape 8 dans CLAUDE.md).

> **Scope** : ce fichier ne suit que les chantiers du repo `nemeton` (cœur métier). Les épaississements portés côté app (`nemetonshiny`) sont mentionnés pour mémoire mais leur séquence de releases vit dans le PLAN de ce repo-là.

## Avancement Walking Skeleton

| État | Vague | Description | Livré côté cœur |
|------|-------|-------------|-----------------|
| ✅ | Squelette initial | CSV/cadastre → indicateurs → radar → perspective IA | — |
| ✅ | E1 | 12 familles complètes, 31 indicateurs | 12 familles + 31 indicateurs, NDP, normalisation |
| ✅ | E2 | Cartographie (Leaflet, parcelles cadastrales) | n/a (app) |
| ✅ | E3 | Multi-acteurs — 13 profils experts YAML | n/a (app) |
| ✅ | E4 | Authentification OAuth2/OIDC | n/a (app) |
| ✅ | E5 | Intégrations & NDP — Open-Canopy CHM (spec 005) + QField export/ingest + sizing échantillon + flag `height_lidar` | v0.16.0 → v0.19.12 |
| ✅ | **E6** | **Suivi sanitaire** — surveillance rapide (NDVI/NBR rolling-window) + diagnostic FORDEAD (CRSWIR + harmonique). Spec 008 + amendement A1, ADR-013 + amendement A1. Indicateur **R5 dépérissement**. | E6.a → v0.20.0 ; E6.c.1-4 + E6.d → v0.21.0 (1.x stack) ; durcissement S2 → v0.21.1..v0.22.1 ; **migration FORDEAD 2.x** (spec 008 §12, plan 008 §9) → **v0.23.0** (2026-05-16). **Backend monitoring local** (Bug #2 verrou fichier) : DuckDB → SQLite/WAL → **v0.50.0** ; fix warning → **v0.50.1** ; retrait DuckDB → **v0.51.0** (2026-05-28) ; fix UPSERT SQLite `near "DO"` à l'ingestion S2 → **v0.55.1** ; audit complet UPSERT SQLite (db_migrate no-target + FORDEAD/alerts `INSERT…SELECT`) → **v0.55.2** (2026-06-01). **FAST 100 % pur raster** : retrait de l'insertion `obs_pixel` dans `ingest_sentinel2_timeseries()` (amorçage cache COG seul), `DROP TABLE obs_pixel` (migration 0004), dépréciation `read_obs_pixel()`/`list_fast_alerts_for_zone()`/`detect_alerts()` → **v0.58.0** (2026-06-02) ; **retrait définitif des 3 fonctions + `CREATE TABLE obs_pixel` ôté des migrations 0001** → **v0.60.0** (2026-06-02, Phase B). Côté app : `nemetonshiny@v0.49.0`→`v0.50.0` ; consommateur `obs_pixel` retiré dès `nemetonshiny@v0.52.16`. **Indice NDMI** ajouté au FAST (spec 019, `(B08−B11)/(B08+B11)`, humidité ; défaut NDVI conservé, B11 cachée best-effort) → **v0.64.0** (2026-06-03) ; **UI NDMI livrée côté `nemetonshiny`** ✅ (sélecteur FAST NDMI listé en premier / défaut NDVI conservé, i18n FR/EN `monitoring_fast_ndmi_hint`/`_b11_note`, slider `monitoring_threshold_ndmi`, 3ᵉ courbe NDMI dans la modale pixel, avertissement bande B11 dans les sidebars, NDMI dans le pré-chauffage `index × mode`) — scope spec 019 §5, dépassé depuis par NDRE + mode `trend` (specs 023/025). **Fix régression spec 019** : `.enumerate_cache_scenes()` n'avait pas de branche NDMI → cartes d'alerte NDMI toujours vides malgré B08+B11 en cache ; + nouvel orchestrateur `read_fast_alert_rasters()` (les 6 cartes = 3 indices × 2 modes en un appel) → **v0.65.0** (2026-06-03). **Fix cache spec 017 D6** (2026-07-01) : la clé du COG FAST incluait `date_from`/`date_to` *demandés* → recalcul quotidien d'une fenêtre glissante ancrée sur aujourd'hui sans nouvelle scène ; désormais clé sur la **couverture S2 réelle** (`min`/`max` des `obs_date` des scènes retenues) + ancre `rolling` sur la dernière acquisition → **v0.105.0**. |
| ✅ | **Carte pixel** *(hors-skeleton, entre E6 et E7)* | API publique cœur pour exposer le cache S2 pixel-par-pixel (10 m natif) + extraction time-series à un clic. Spec 010. Débloque le sous-onglet *Carte pixel* dans `nemetonshiny` (séparé). | 4 fonctions exportées (`read_s2_band_raster`, `read_s2_band_stack`, `build_index_stack`, `extract_pixel_timeseries`) — release **v0.22.0** (2026-05-15). |
| ✅ | **Sources Theia** *(hors-skeleton)* | Intégration du catalogue Theia / DATA TERRA comme sources de données pour les 12 familles d'indicateurs : FORMS-T, variables biophysiques S2 (LAI/FAPAR/FVC), neige LIS, sols France, humidité du sol, eaux de surface, S2 L2A MUSCATE, classification d'essences, LST Thermocity, FORMSpoT. | FORMS-T → **v0.28.0** ; phase 1a → **v0.29.0** ; phase 1b → **v0.30.0** ; phase 2 (loaders) → **v0.31.0** ; phase 3a (`s2_biophysical` → C2/A1) → **v0.32.0** ; phase 3b (`theia_soil` → F1/F2) → **v0.33.0** ; phase 3c (`theia_snow` → R3) → **v0.34.0** ; phase 3d (`theia_water`/`theia_soil_moisture`/`theia_species`) → **v0.35.0** ; FORMSpoT câblé via l'interface CHM → **v0.35.2** ; résolveur STAC Theia → **v0.36.0** ; endpoint corrigé + FORMSpoT vérifié → **v0.37.0** ; auth S3 `/vsis3/` → **v0.38.0** ; ciblage par année → **v0.39.0** ; credentials S3 corrigés → **v0.39.1** ; signature SDK teledetection (`theia_signed_href`) → **v0.40.0** — chaîne validée en réel. Reliquat : MUSCATE, LST, W1. |
| ✅ | E7 | RAG perspectives IA (pgvector + base de connaissances forestière, ADR-012) | **Machinerie** → **v0.52.0** : 7 fonctions exportées (`enable_rag`, `ingest_knowledge_document`, `embed_query`, `retrieve_knowledge`, `list_knowledge_documents`, `delete_knowledge_document`, `format_citations`), schéma opt-in `knowledge_*`, dual-backend pgvector `<=>` (PG) / cosinus R (SQLite). **Corpus** (spec 009.1) : API admin (v0.63.0), curation v0.75.0→v0.76.2 → **déployé en prod : 81 docs, 60 texte intégral, 6 120 chunks, 0 embedding manquant** (dont 4 papiers scannés OCRisés). **Wiring app** : perspectives IA sourcées (`nemetonshiny`). **Clos 2026-06-13.** |

Légende : ✅ livré · 🟨 en cours · ⬜ à venir.

---

# Écarts ouverts dans la chaîne cœur → app → foretaccess

> Tenu à jour depuis le 2026-08-15. Ce que la source unique de vérité est
> censée rendre visible : ce qu'un maillon a livré et que le suivant n'a pas
> encore consommé. **Ne rien cocher ici tant que la chaîne entière n'a pas
> suivi.**

| # | Écart | Livré par | En attente chez | État |
|---|---|---|---|---|
| 1 | `indicator_families()` / `indicator_labels()` | `nemeton` **v0.170.0** puis **v0.171.0** | `nemetonshiny` | **Non consommé.** Plancher toujours `Imports: nemeton (>= 0.169.0)` ; `app_config.R` porte encore le fork complet de la table |
| 2 | `osm_hors_corridor` / `bdtopo_hors_corridor` | `foretaccess` **v2.4.0**, taguée le 2026-08-15 | `nemetonshiny` | **Publié, non consommé.** Plancher app toujours `foretaccess (>= 2.3.0)`, et le calque « Pistes OSM » affiche encore l'acquisition brute |
| 3 | Validation terrain du profil en travers | `foretaccess 2.3.0` + app v0.123.0 | terrain | **Jamais exercé de bout en bout** sur un projet réel portant nuage LiDAR *et* desserte corrigée |

**Écart 1 — le cœur a livré, l'app n'a pas consommé.** C'est exactement le
genre d'écart que ce fichier doit rendre visible, et il est mesurable : la copie
de la table dans `nemetonshiny/R/app_config.R` **a déjà divergé** — 40
indicateurs déclarés contre 41, A5 `indicateur_a5_rafraichissement` absent (donc
calculé par `service_compute.R` puis filtré à l'affichage, invisible dans
l'onglet Air), 14 libellés et 18 tooltips divergents. Une troisième copie des
libellés, les 40 clés i18n `indicator_<CODE>`, a même **F1 et F2 inversés** : la
colonne d'érosion s'affiche « F1 - Fertilité des sols ». Six patches vérifiés
sont prêts (`specs/patch-nemetonshiny-0[1-6]-*.diff`), non appliqués.

**Écart 2 — le maillon `foretaccess` est bouclé, l'app ne l'a pas encore pris.**
L'implémentation avait été vérifiée le 2026-08-15 en lecture seule, hors du
dépôt : 15 assertions passent, dont la non-régression des quatre valeurs de
`resume` et le `st_cast()` qui homogénéise LINESTRING/MULTILINESTRING avant
écriture GeoPackage. La PR #160 a été mergée et **`v2.4.0` est taguée le même
jour** — `Remotes: @*release` la voit donc désormais. Reste, côté app : monter
le plancher à `foretaccess (>= 2.4.0)`, et faire lire au calque
`cmp$osm_hors_corridor` au lieu de l'acquisition brute, ce qui permet enfin de
le renommer « Pistes OSM hors BD TOPO ».

---

# Brief émis — Onglet Desserte : rendre visibles les sorties (app + foretaccess)

> **Émis le 2026-08-14** : `specs/brief-nemetonshiny-desserte-visualisation.md`.
> Aucun impact cœur `nemeton` — tracé ici parce que le brief part d'ici.

**Constat** (lecture seule de `nemetonshiny@0.123.0.9000`) : la sidebar droite
de l'onglet Desserte porte 5 actions, toutes produisent un résultat sur disque,
**2 seulement sont visibles**. Le complément OSM (`desserte_osm.gpkg`) et la
détection de routes non cartographiées (`desserte_detectee.gpkg`) — les deux
traitements les plus coûteux de l'onglet — n'ont **aucun calque** : la sidebar
n'en donne qu'un compteur, la géométrie reste dans le cache du projet, et
l'export ne copie que `desserte.gpkg`. Deux autres trous vérifiés : le typage
est le seul des cinq à n'avoir **aucun `.load_cached_*`**, il est donc perdu au
rechargement du projet malgré son GeoPackage sur disque ; et `run_desserte_osm()`
écrit son GeoPackage sans en renvoyer le chemin.

**Point dur, côté `foretaccess`** — brief dédié émis le 2026-08-14 :
`specs/brief-foretaccess-comparer-osm-geometries.md`.
`comparer_desserte_osm()` ne renvoie que des **tables de linéaire** (`osm`,
`bdtopo`, `resume`) — aucune géométrie. Le « hors corridor », c'est-à-dire le
gisement à instruire, n'existe qu'en mètres. Ce que l'app écrit dans
`desserte_osm.gpkg` est donc la couche OSM **brute**, pas le résultat de la
comparaison. Le cœur **calcule pourtant déjà** cette géométrie —
`st_difference()` dans l'helper interne `hors()` — et n'en garde que la
longueur : l'objet le plus utile est détruit à la sortie de la boucle, après
avoir payé les 104 s. Demande : deux `sf` additifs `osm_hors_corridor` /
`bdtopo_hors_corridor`, sans toucher aux trois tables. Implémentation
prototypée et vérifiée sur la fixture du test en place (0,1 km hors corridor,
la valeur que le test attend déjà) ; seul piège réel, le mélange
LINESTRING/MULTILINESTRING quand le corridor coupe un tronçon en deux, à
homogénéiser par `st_cast()` avant écriture GeoPackage. Argument de poids :
CA-28.5 de la spec 028 mesure **93 % du linéaire hors corridor en desserte
réelle** pour 4 % de faux positifs — ce n'est pas du bruit qu'on cacherait,
c'est un résultat qu'on refuse faute de le renvoyer.

**Livré en brief et non en patch** : `R/mod_desserte.R` était en cours d'édition
au moment de la rédaction (modifié 3 minutes plus tôt, 5 fichiers en travail sur
`main`). Des patches ancrés sur des numéros de ligne y auraient pourri en
quelques minutes — le brief cite des observers et des fonctions.

**Suite (2026-08-15)** — les deux versants ont bougé, aucun n'est clos :

- **App : livré** en `nemetonshiny` v0.124.0 (`ccbeb3e7`), cf. l'entrée de
  journal du 2026-08-14. Les deux calques, le popup, `.load_cached_typage()`,
  le `gpkg_path` d'OSM et l'export fusionné sont en place.
- **`foretaccess` : livré et publié en `v2.4.0`** (2026-08-15, PR #160 mergée).
  `hors()` rend désormais `list(long, parts)`, `.sf_hors()` assemble, le
  `st_cast()` est là. Vérifié ici en lecture seule, hors du dépôt : 15
  assertions passent, dont la non-régression des quatre valeurs de `resume` et
  l'aller-retour GeoPackage sur un tronçon traversant.
- **Reste le dernier maillon, côté app** : plancher `foretaccess (>= 2.4.0)`,
  et le calque qui lit `cmp$osm_hors_corridor` au lieu de l'acquisition brute —
  il pourra alors s'appeler « Pistes OSM hors BD TOPO », ce que son libellé
  actuel se refuse honnêtement à dire. Cf. écart n° 2 en tête de fichier.

---

# Chantier CLOS — Export public de la table des familles d'indicateurs

> **Clos le 2026-08-14 (v0.170.0).** Brief :
> `specs/BRIEF-indicator-families-export.md` (émis depuis `nemetonshiny`).

**Journal** — *2026-08-14* (**v0.170.0**) : **`INDICATOR_FAMILIES` devient une
API publique, sans être exporté tel quel.** Constat du brief : le `CLAUDE.md`
de l'app affirmait que les noms de famille étaient lus depuis le cœur, alors
que l'objet n'était pas dans le `NAMESPACE` — l'app redéclarait 24 chaînes
FR/EN, 12 codes en dur et 34 libellés d'indicateurs. Duplication **exacte**
aujourd'hui (0/12 divergence mesurée), donc silencieuse : rien ne signalerait
l'écart le jour où il apparaîtrait.

**Décision** : option 2 du brief — deux **accesseurs** plutôt que
`export(INDICATOR_FAMILIES)`, pour ne pas figer la structure interne en API
cassante. `indicator_families(codes, lang)` renvoie un `data.frame` de 12
lignes (colonnes-listes `indicators` / `column_names` / `labels` / `tooltips`,
ordre canonique `C B W A F L T R S P E N` garanti) ; `indicator_labels(codes,
lang)` la même table à plat, 41 lignes, une par indicateur — c'est la forme qui
permettra à l'app de retirer ses clés `indicateur_*`. Les deux sont pures
(appelables dans un worker `future`). Point tranché du brief (« lang :
une colonne `name` ou les deux ? ») : **les deux** — `name` suit `lang`,
`name_fr`/`name_en` sont toujours présents, basculer de langue ne coûte pas un
second appel.

**Deux choses documentées plutôt qu'« alignées »** : (1) les couleurs du cœur
sont sémantiques et divergent volontairement du viridis de l'app (§3 du brief)
— la colonne est exposée mais l'aval l'ignore ; (2) `indicators` et
`column_names` sont appariés **par position**, et deux familles portent un
croisement historique — `F1` = `indicateur_f2_erosion`, `F2` =
`indicateur_f1_fertilite`, `L1` = `indicateur_l2_fragmentation`, `L2` =
`indicateur_l1_sylvosphere`. Cohérent de bout en bout (les libellés suivent le
code court, pas le slug) et verrouillé par un test : dériver la colonne du code
par manipulation de chaîne casserait ces deux familles.

**Test qui relie la table au moteur** (le §5.5 du brief, celui qui a le plus de
valeur) : chacune des 41 colonnes déclarées doit être produite par une fonction
exportée du même nom **et** passer `normalize_indicator()` sans déclencher le
garde-fou « pas de règle 0-100 » (spec 038). Déclarer un indicateur sans le
brancher échoue désormais côté cœur. Suite (`test-indicator-families.R`) :
353 assertions, vertes.

**Journal** — *2026-08-14* (**v0.171.0**) : **les trois manques repérés en
écrivant le brief de câblage sont comblés.** (1) *Les deux langues, toujours* —
tout champ traduisible sort en colonnes `_fr`/`_en` ; `lang` ne pilote plus que
les colonnes de confort. Un mode `lang = "both"` aurait fait varier le schéma
selon l'argument ; une colonne toujours présente se consomme mieux, et c'est le
prolongement de ce que `name_fr`/`name_en` faisaient déjà. (2) *Description par
famille* — `description` + `description_fr`/`description_en`, 12 phrases
réécrites à jour du contenu réel des familles (celles de l'app dataient d'avant
A3-A5, R5-R7, T3, W4, B4, L3 et décrivaient des familles amputées). (3) *La
colonne de score devient publique* — colonne `family_column` +
`get_famille_col()`/`get_famille_code()` exportées et vectorisées, avec
validation explicite. Ce nom était de fait un contrat entre packages (colonne
de l'`sf` calculé, valeur d'onglet, clé DB) mais n'était joignable que par
`getFromNamespace()`, ce que fait `nemetonshiny/R/imports.R`. Un test relie
`family_column` au moteur : les 12 noms doivent figurer dans les colonnes de
`massif_demo_units`. Suite `test-indicator-families.R` : 405 assertions.

*2026-08-14, suite 2* : **étapes 2 à 5 livrées, 6 patches au total**
(`specs/patch-nemetonshiny-0[1-6]-*.diff`) : dé-fork, menu par boucle +
sous-titre lu dans `description`, retrait des 24 clés `famille_*` + du
`col_names` mort de `mod_synthesis.R`, bascule des libellés d'indicateurs sur
`indicator_labels()` (−74 clés), ordre canonique dans `utils_theme.R`, et les
8 tests de structure remplacés par 3 tests d'identité. Vérifié sur une copie
(`git archive`, jamais dans l'app) : les 6 patches s'appliquent sur `main`, la
séquence complète laisse les **66 fichiers `R/` et 91 fichiers de test qui
parsent**, les 3 nouveaux tests passent (129 assertions) et les 5 assertions
existantes sur `clean_indicator_label()` restent vertes.

**Second bug trouvé en écrivant le patch 04** : les clés i18n
`indicator_<CODE>` (3ᵉ copie des libellés, distincte du fork) ont **F1 et F2
inversés** — `clean_indicator_label()` apparie correctement la colonne au code
puis lit `indicator_F1` = « Fertilité des sols », si bien que la **colonne
d'érosion s'affiche « F1 - Fertilité des sols »**. S1/S2 y décrivent aussi
autre chose que ce que le cœur calcule (« Densité de sentiers » pour une
distance aux routes). Le patch 04 corrige les deux.

*2026-08-14, suite* : **patch de dé-fork livré** —
`specs/patch-nemetonshiny-app_config-defork.diff`, à appliquer depuis une
session `nemetonshiny` (`git apply`). Deux fichiers : `R/app_config.R` (−309
lignes, le fork remplacé par `.build_indicator_families()`) et `R/zzz.R` (+7,
le `.onLoad`). Vérifié sans rien écrire dans l'app : `git apply --check` passe
sur l'arbre courant (branche `claude/ascii-sources`, **65 fichiers modifiés non
commités**, dont les trois de cette migration), les fichiers parsent, l'objet
reconstruit est `identical()` au cœur champ par champ, et la famille A repasse
à 5 indicateurs — A5 revient. Règle #11 respectée : rien n'a été écrit dans le
repo frère, Pascal applique depuis sa session (choix explicite du 2026-08-14).

**Suite côté app** — brief livré le 2026-08-14 :
`specs/brief-nemetonshiny-indicator-families.md`. La lecture (seule) de l'app
pour l'écrire a corrigé la prémisse du brief entrant : la duplication n'est pas
de 24 chaînes dans `utils_i18n.R`, c'est un **fork complet de la table** dans
`app_config.R` (lignes 127-558, ~430 lignes, 5 accesseurs copiés, 8 fichiers
consommateurs) — et **il a déjà divergé** : 40 indicateurs contre 41, **A5
`indicateur_a5_rafraichissement` absent** (calculé par `service_compute.R` puis
filtré à l'affichage par `mod_family.R:70`, donc invisible dans l'onglet Air),
14 libellés et 18 tooltips divergents. L'adaptateur proposé reconstruit la
table du cœur **au bit près** (`identical()` vérifié). Trois manques cœur
identifiés et laissés à trancher (§5 du brief) : `lang = "both"`, une
`description` de famille, et un accesseur exporté pour la colonne de score de
famille — l'app tire aujourd'hui `get_famille_col()`/`FAMILLE_NMT_MAP` par
`getFromNamespace()` sur une API interne.

---

# Chantier CADRÉ — Crop à l'ingestion S2 (spec 021, optimisation disque)

> **Cadré le 2026-06-27** (paperwork avant code). Doc :
> `specs/021-suivi-sanitaire-reconfort/L2b-crop-ingestion-cadrage.md`.
> Déclencheur : incident disque plein 2026-06-27 (zone 5 Mouthe / T31UFQ,
> `exit 1` = `OSError [Errno 28]`). L'ingestion matérialise ~460 GB
> transitoires (zips ~211 GB + extraits full-tile ~250 GB) pour ~60 px utiles ;
> le crop AOI (`reconfort_crop.R`, v0.94.2) n'intervient qu'**après** extraction
> → réduit le résultat, pas le pic. Palliatifs v0.94.3 (PR #123 :
> extract-then-delete + garde-fou disque) plafonnent à ~250 GB sans supprimer
> la couche full-tile.

**Décisions cadrées** (cf. doc) : **C1** Option B — *interleave par date*
(download 1 archive → extract → crop AOI → delete) → pic disque ~3–5 GB ;
**C2** crop **en R** (règle « pas de métier dans le python vendoré » ; python
ne fait que lister + télécharger une archive) ; **C4** `reconfort_ingest_s2()`
devient **AOI-aware streaming** (nouvel arg `aoi`, rétrocompatible : `aoi =
NULL` → comportement v0.94.x full-tile) ; **C5** crop AOI par date = cache
d'idempotence.

**Découpage** : K1 manifeste (`list_s2_items.py` + reader R) · K2 download par
item · K3 `.reconfort_crop_scene_to_aoi` (factorisation per-scene) · K4 boucle
streaming dans `reconfort_ingest_s2()` · K5 câblage `reconfort_pipeline.R`
(retrait du `do_crop` séparé) · K6 tests + release **v0.95.0** (bump mineur :
changement de contrat).

**Journal** — *2026-06-27 (impl K1→K6 livrée sur branche)* :
- **K1/K2** : deux scripts python **nemeton-authored** (pas vendorés) —
  `list_s2_items.py` (1 search GEODES → 1 STAC JSON par item + `manifest.json`)
  et `download_s2_item.py` (`Item.from_dict` → `download_item_archive(outfile=)`,
  1 archive). Round-trip `to_dict`/`from_dict` validé sur GEODES réel (item
  T31UFQ, href https + datetime préservés) → **R1 levé** (1 search, pas 140).
  Readers R `.reconfort_list_s2_items` / `.reconfort_download_s2_item`.
- **K3** : `.reconfort_crop_scene_to_aoi(scene, out, win, crs)` factorisé hors
  de `.reconfort_crop_scenes_to_aoi` ; **skip SRE** (équiv. suppression amont).
- **K4** : `.reconfort_ingest_tile_streaming()` — LIST → par item (skip si
  marqueur `ingested/<tile>/<id>.done`) DL→`utils::unzip`→crop AOI→delete
  (zip+scratch). `reconfort_ingest_s2()` gagne `aoi`/`target_crs`/`buffer_m` ;
  `aoi = NULL` → comportement v0.94.x intact. Robustesse R3 : download/zip
  KO logué + skip, abort seulement si 0 scène cropée.
- **K5** : `reconfort_pipeline.R` PHASE 5 passe `aoi` à l'ingest, `do_crop`
  séparé retiré (`extracted_aoi/` disparaît, l'ingest écrit le crop dans
  `extracted/<tile>/`).
- **K6** : +14 tests ingest (55 ✔ : crop per-scene, streaming
  DL→extract→crop→delete + idempotence, manifeste vide → abort) ; pipeline 22 ✔
  (mock ingest étendu `aoi`) ; python 14 ✔. `.Rd` édités à la main.

> *2026-06-27 (release v0.95.0)* : #124 mergé dans main, puis bump stable
> **v0.95.0** (DESCRIPTION + NEWS + CITATION). Avant le merge : run full-tile
> bloqué tué (mauvais code installé — v0.94.3 sans streaming) et cache T31UFQ
> stale purgé (zip + extracted full-tile, ~334 GB → disque à 467 GB libres).
> **Validation run réel à faire par Pascal** sur la version installée 0.95.0
> (vérifier pic disque ~GB + carte identique) ; signaler si `utils::unzip`
> coince sur une vraie archive ~2 GB (fallback `system2("unzip")` prêt à câbler).

> *2026-06-28 (patch v0.95.1)* : **comportement disque du streaming confirmé
> sur run réel** (T31UFQ, observé à 93/140) — `extracted/` ~1,3 GB pour 93
> scènes vs ~256 GB en full-tile, **1 seule archive en transit**, pic disque
> ~GB, `utils::unzip` digère les vraies archives MUSCATE ~1,2 GB sans blocage
> (download limité par GEODES ~4,8 MB/s). Bug cosmétique corrigé : filtre
> `PYTHONWARNINGS` urllib3 par catégorie rejeté au démarrage Python
> (`Invalid -W option ignored`) → bascule sur un filtre par message
> (`ignore:Unverified HTTPS request`), validé en env conda.

> *2026-06-28 (feat v0.96.0 — progression fine)* : l'ingestion streaming
> n'émettait qu'un event de phase global `ingest` (heures de silence).
> `reconfort_ingest_s2(progress_callback=)` émet désormais
> `reconfort:ingest_listed` (total scènes) + `reconfort:ingest_item` par scène
> (`step` download/crop/done/cached/failed, `completed/total`, `item_date`) ;
> le pipeline relaie le callback ; la console détaille chaque scène. Côté
> `nemetonshiny` (v0.92.0) : `.reconfort_handle_progress_event` rend ces events
> dans le bandeau (comme FORDEAD / FAST), + clés i18n FR/EN. Tests : ingest 59
> ✔ (assert events), app i18n 2626 ✔, monitoring 100 ✔.

> *2026-06-28 (fix v0.96.1 — crash systemd-oomd)* : sur run réel, ingestion
> streaming OK (140/140, reprise idempotente validée), puis **R/RStudio tué par
> `systemd-oomd`** en pleine classification IOTA² (pression mémoire 54 % > 50 %
> pendant >20 s). Cause : `scheduler_type = "localCluster"` (cluster Dask
> ~nb_cpus workers × pile features multi-dates) inutile sur AOI minuscule. Fix :
> `reconfort_pipeline.R` force `scheduler_type = "debug"` (séquentiel) quand
> `aoi_crop = TRUE`, miroir du `number_of_chunks = 1`. Choix explicite respecté.

> *2026-06-28 (feat v0.97.0 — manifeste des couches)* : pour câbler l'affichage
> « au choix » des sorties RECONFORT côté `nemetonshiny` (rasters score/classes/
> proba + vecteur alertes, avec curseur d'opacité), nouvelle fonction exportée
> cœur `reconfort_layer_manifest(result, include_range)` : traduit le retour de
> `run_reconfort_dieback()` en `data.frame` plat (1 ligne/couche disponible) avec
> indications de rendu (`palette`/`reverse`/`vmin`/`vmax`/`categorical`/
> `default_visible`/`default_opacity`/`n_features`). La sémantique des couches
> reste dans le cœur (règles strictes §1-3) ; l'app consomme le manifeste tel
> quel. 29 tests (`test-reconfort-manifest.R`). Brief Shiny fourni (toggles +
> opacité). Validé pendant un run réel de diagnostic (surveillance OOM en place).

**Statut** : ✅ **livré v0.95.0** (+ patchs v0.95.1, v0.96.0, v0.96.1 ;
helper d'affichage v0.97.0). Streaming validé (140/140) ; classification IOTA²
à valider en mode `debug` (run en cours) ; affichage des couches à câbler côté
`nemetonshiny` (manifeste cœur prêt).

---

# Chantier EN COURS — RECONFORT AOI-scoped (spec 021, productionisation)

> **2026-06-24.** RECONFORT (dépérissement feuillus, IOTA²/v3) ne tournait
> jamais de bout en bout sur ce poste. Après ~12 incompatibilités iota2
> récent (OTB 10) corrigées, la chaîne produit enfin une **carte de
> dépérissement** (zone `lajoux_feu`, 370 alertes pixel/cluster en base),
> **en ~6 min au lieu de 7 h**, en appel `run_reconfort_dieback()` défaut.

**Livré (cœur, working tree — à committer) :**
- `R/reconfort_crop.R` : `.reconfort_crop_scenes_to_aoi()` (clip + reproj des
  scènes S2 vers l'AOI+buffer dans la projection de sortie 2154 — perf ×~300
  ET corrige un bug de grille de référence iota2 quand l'entrée est en 32631),
  `.reconfort_write_aoi_ground_truth()` (points part-1 dans l'AOI),
  `.reconfort_oso_broadleaf_mask()` (masque feuillus = OSO classe 16, découpé
  de l'OSO national `<cache>/oso/oso.tif`), `.reconfort_oso_national_path()`.
- `R/reconfort_pipeline.R` : `run_reconfort_dieback(aoi_crop=TRUE, oso_national)`
  câble crop + masque OSO AOI + ground-truth AOI + `number_of_chunks=1` auto.
- `inst/python/reconfort/iota2/config/iota2_resources.cfg` (#7 : clés
  name/process_min/nb_chunk retirées) + `custom_index.py` (#8 :
  `I2TemporalLabel`). Tests : `test-reconfort-crop.R` (helper fenêtre AOI).

**Correctifs ENV (non code — à refaire si rebuild du conda `nemeton-reconfort`) :**
- #9 pandas 3.0→2.x (`to_datetime(infer_datetime_format=)` retiré en pandas 3).
- #10 wrapper `task_launcher.py` dans `$ENV/bin/` (absent du build iota2).

**Reste :** warning best-effort `persist (features bundle) failed: number of
rows/columns` (n'empêche pas les alertes) ; validité OTB 10 vs OTB 8 de
calibration à confirmer avec les auteurs RECONFORT (résultat cohérent : ~23 %
feuillus, ~13 % en dépérissement). Voir mémoire `project_reconfort_iota2_version`.

**Journal** — *2026-07-01 (garde-fou année `s2_year` — v0.104.0)* : le
`s2_year` (dernière année de la série ~2 ans) n'avait aucune borne « saison
complète » ni côté cœur ni côté app (picker `nemetonshiny` : défaut ET max =
année en cours → run lancé avant fin octobre = dernière saison tronquée,
classification dégradée, sans avertissement). Cœur : `RECONFORT_MODELS` gagne un
champ **`edate`** (`"MM-DD"`, fin de fenêtre modèle : `10-29` pour les modèles
2 ans, `05-31` pour `v3_early_may`) ; nouvelles fonctions exportées
**`reconfort_latest_complete_year()`** et **`reconfort_year_bounds()`**
(min=2016, max/default = dernière année complète). Tests dans
`test-reconfort-model.R`. **Brief `nemetonshiny` fourni** : câbler
`value`/`min`/`max` du `numericInput` sur `reconfort_year_bounds()` + garde-fou
serveur dans `.invoke_reconfort()` (le `numericInput` n'étant qu'un hint
navigateur) + clé i18n `monitoring_reconfort_year_incomplete`. Dépend de
`nemeton >= 0.104.0`.

---

# Chantier EN COURS — Diversité spectrale B4 / L3 (spec 028, biodivMapR)

> **Ouvert le 2026-07-01.** Deux nouveaux indicateurs télédétectés (NDP 0,
> Sentinel-2) via `biodivMapR` (hypothèse de variation spectrale) :
> **B4** diversité spectrale (α/Shannon, famille B) et **L3** hétérogénéité
> spectrale (β/Bray-Curtis, famille L). Décisions D1-D4 tranchées (spec 028 §9).

**⚠️ Relicence** : `biodivMapR` étant GPL-3 et intégré en `Imports:` direct
(décision propriétaire assumée), **nemeton passe MIT → GPL-3** (v0.110.0).
Effet domino : `nemetonshiny`/`tree_sat`/`maestro` GPL-3 à la distribution
(bascule à faire dans leurs dépôts) + **amender ADR-006** (platform_nemeton).

**Livré (v0.110.0)** : primitive `compute_spectral_diversity()` (wrapper
`biodivMapR_full`, agrégation UGF via exactextractr) + `indicateur_b4_div_spectrale`
/ `indicateur_l3_het_spectrale` (rétrocompat `NA`), registre + normalisation
(haut=mieux, bornes provisoires) + tests `test-spectral-diversity.R` (logique
validée hors biodivMapR ; pipeline réel = smoke manuel).

**Reste** : ⏳ smoke réel sur scène Sentinel-2 → **recalibrer les bornes de
normalisation B4/L3** (D3) ; affichage B4/L3 côté `nemetonshiny` (radar/tooltips).

---

# Chantier EN COURS — Dette post-coupe-rase (items 1-4)

> **Ouvert le 2026-07-01.** Inventaire de dette autour du correctif CHM/coupe
> rase. 4 items : (1) un CHM cassé (tout à 0) est indistinguable d'une coupe
> rase → garde-fou « CHM suspect » ; (2) peuplement jeune [1,3 ; 6) m → NA au
> lieu de ~0 ; (3) P2 station encore NA sur couvert nul (n'utilise pas
> `ensure_inventory_fields`) ; (4) duplication du dispatcher cœur/app.

**#4 dispatcher — cœur livré (v0.108.0) :** `extract_indicator_value(result,
indicator, exclude)` exportée = **source unique** de la convention de nommage
(code court → nom NMT → motif). `compute_indicator()` délègue. Reste : câbler
`nemetonshiny` dessus (supprimer son `col_map`, dépend de `nemeton >= 0.108.0`).
Tests `test-indicators-core-dispatch.R`.

**#1 / #2 / #3 — cœur livré (v0.109.0)** : spec 005 §3.5 (paperwork) +
implémentation.
- **#2** peuplement jeune `[1,3;6)` m → `dbh/density = 0` (param
  `min_merchantable_height = 6`) → P1/P3/E1 = 0 au lieu de NA ; test en
  **hauteur** (espèce manquante sur grand peuplement reste NA).
- **#3** `compute_site_index(min_stand_height = 1.3)` : CHM nu → P2 = NA (au
  lieu du clamp pire classe).
- **#1** garde-fou `chm_suspect` (warn + attribut) sur CHM dégénéré (≥95 %
  sous plancher + max CHM ~0).
Tests `test-synthetic-inventory-debt.R`. **Chantier dette #1-#4 CLOS.**

---

# Chantier CLOS — Coupe rase : CHM « couvert nul » → volume 0 (spec 005 §3.4)

> **Cadré + livré le 2026-07-01.** Diagnostic base : sur le projet FORDEAD récent
> (`20260624_073705_armn`, Mouthe), famille **Énergie absente**. Cause tracée via
> `data/indicators.parquet` : **P1/P3/E1 = 100 % NA**, E2 = 0, alors que le CHM
> Open-Canopy en cache est **valide** (EPSG:2154) mais à hauteur ≈ 0 — la forêt a
> été **rasée**. Test décisif : `indicateur_p1_volume(u, chm=chm)` = NA *même
> CHM fourni* ⇒ **bug cœur** (pas wiring) : `estimate_dq_from_hdom()` renvoie NA
> pour H_dom < 6 m, confondant « couvert nul » et « peuplement jeune ».

**Livré (cœur) :** `estimate_synthetic_inventory()` / `ensure_inventory_fields()`
gagnent `min_stand_height` (défaut 1,3 m) ; H_dom observé sous le seuil ⇒
`dbh=0/density=0` (au lieu de NA) ⇒ **P1=0, E1=0, P3 défini, E2=0 cohérent,
famille Énergie présente**. `H_dom=NA` (hors couverture) reste NA. Amendement
**spec 005 §3.4**. Tests `test-synthetic-inventory-clearcut.R` (+ non-régression).
Vérifié sur le CHM réel du projet : P1/E1 = 0. → **v0.107.0**.

> **Suites du brief :**
> - **§1 wiring app** — *sans objet* : vérification faite, `service_compute`
>   (nemetonshiny) charge **déjà** le CHM Open-Canopy (`chm_source="opencanopy"`
>   dans `metadata.json`, `ndp_level=1`) et le passe aux indicateurs via une
>   boucle par `formals()`. Le seul levier était le correctif cœur ci-dessus +
>   installer `nemeton ≥ 0.107.0` dans la lib de l'app (fait 2026-07-01) puis
>   relancer le calcul. Aucune PR app.
> - **§3 dispatcher cœur — livré (v0.107.1)** : `compute_indicator()` filtre les
>   args sur `formals()` (fin du `unused argument (layers=)` sur P1/P2/P3/E1/E2)
>   et généralise l'extraction de colonne (code court dérivé du nom, plus de
>   `col_map` R1-R4). `nemeton_compute()` marche désormais sur P1/E1. Tests
>   `test-indicators-core-dispatch.R`.

---

# Chantier CLOS — Planche pixel dépérissement (CRswir/CRre)

> **Cadré le 2026-07-01, clos le 2026-07-01.** Enrichir le click-to-diagnose
> plotly de la carte RECONFORT (`nemetonshiny/R/mod_monitoring_reconfort_map.R`,
> 2 traces mono-axe) en **planche 4 panneaux** (double axe Y natif, cycles
> repliés, espace d'état CRswir×CRre, palette cividis). Brief découpé en 2
> parties (règles 1-3 CLAUDE.md) : calcul au cœur, rendu dans l'app.

**Partie A — cœur `nemeton` (✅ livrée) :**
- `prepare_pixel_dieback_series(df, grid_step, smooth, summer, gap_flag_days)`
  (`R/pixel_dieback_prep.R`, exportée) : transformation pure de la sortie de
  `read_reconfort_pixel_series()` → grille+gap-fill (`stats::approx`), lissage
  léger Savitzky-Golay (`signal`), extrema estivaux annuels (creux CRswir / pic
  CRre sur obs réelles), espace d'état + centroïdes annuels, lacunes longues.
- Nouvelle dépendance `signal`. Tests : `test-pixel-dieback-prep.R`. → **v0.106.0**.

**Partie B — app `nemetonshiny` (✅ livrée, 2026-07-01) :** tracé inline extrait
en `fct_plot_pixel_dieback.R::plot_pixel_dieback(prepared, opts, i18n)` (pur
plotly, `yaxis2` natif, cividis via `viridisLite`, subplot 4 panneaux), câblé
dans `mod_monitoring_reconfort_map`, i18n FR/EN, table `DT` équivalente, contrôles
lissage/points, **export PNG** (helper pur `save_plotly_png` : kaleido→webshot2,
bouton conditionnel dans la modale). Consomme `nemeton::prepare_pixel_dieback_series()`
(dépend de `nemeton >= 0.106.0`). → **`nemetonshiny` v0.96.1**.

> **Reste non branché (documenté, hors périmètre app)** : inclusion de la planche
> au **rapport Quarto PDF**. Volontairement différée : elle exige une sélection de
> « pixel représentatif » qui relève du **métier (`nemeton`)**, pas de l'app. Le
> helper d'export PNG est prêt à être réutilisé si/quand cette section est
> spécifiée côté cœur (à flécher : primitive de choix du pixel représentatif dans
> `nemeton`, puis wiring rapport côté app).

---

# Chantier EN COURS — Carte FORDEAD : 3 couches additionnelles

> **Cadré le 2026-06-19.** La Carte FORDEAD n'affiche que le masque 0-4. On
> ajoute 3 couches pixel pertinentes, sélectionnables et masquées par strate
> (D2), opacité réglable.

**Couches** : (1) **Date de 1re détection** (`first_anomaly.tif`, déjà persistée) ;
(2) **Indice d'anomalie / sévérité continue** (`ANOMALY_INDEX` dernière date, à
persister) ; (3) **Confiance / zone modélisée** (`fit/modelled_pixels.tif`, à
persister). Décisions : D1 = indice = dernière date ; D2 = UI radio « une couche
à la fois » ; D3 = confiance = `modelled_pixels` seul.

## Avancement — cœur `nemeton` (Partie A)

| État | Tâche | Détail |
|------|-------|--------|
| ✅ | **A1** | `.write_fordead_model_bundle()` persiste aussi `anomaly_index.tif` (dernier `ANOMALY_INDEX`) + `modelled_pixels.tif` (depuis `fit/`), best-effort |
| ✅ | **A2** | reader exporté `read_fordead_layer(con, zone_id, layer, run_id, cache_dir, …)` (bundle `model_<run_id>/`, masque de zone — miroir de `read_fordead_dieback_mask`) |
| ✅ | **A3** | NAMESPACE + `man/read_fordead_layer.Rd` à la main ; tests `test-fordead-layer.R` (6) + complément `test-fordead-outputs.R` (anomaly_index/modelled_pixels écrits ou sautés). Verts. |
| ✅ | **A4** | release cœur **v0.94.0** (PR #107 mergée, tag + release CI) ; cycle dev `0.94.0.9000` |

## Avancement — app `nemetonshiny` (Partie B, repo séparé)

| État | Tâche | Détail |
|------|-------|--------|
| ✅ | **B1** | sélecteur radio de couche (sidebar droite) : sévérité 0-4 (défaut) / date 1re détection / indice anomalie / zone modélisée |
| ✅ | **B2** | `mask_r` layer-aware (read_fordead_dieback_mask vs `read_fordead_layer`), masquage par strate conservé |
| ✅ | **B3** | palette + légende par couche (catégorielle 0-4 / viridis dates / YlOrRd / binaire) |
| ✅ | **B4** | « zone saine » ne court-circuite que la couche sévérité 0-4 |
| ✅ | **B5** | i18n (libellés couches + légendes) |
| ✅ | **B6** | release app **v0.91.0** (`Imports: nemeton (>= 0.94.0)`) ; couche absente → message « indisponible » |

**Chantier CLOS** — cœur **v0.94.0** + app **v0.91.0** livrés.

**Journal** — *2026-06-19* : chantier cadré (brief + plan). Partie A démarrée
sur la branche `feat/fordead-extra-layers`. `first_anomaly` déjà persistée
(couche 1 dispo même sur anciens runs) ; couches 2-3 nécessitent la persistance
A1 (runs antérieurs → reader rend NULL → fallback gracieux app).
>
> *2026-06-19 (Partie A livrée — v0.94.0)* : cœur **PR #107 mergée** →
> `read_fordead_layer()` exporté + persistance `anomaly_index.tif` /
> `modelled_pixels.tif` dans le bundle modèle. Cycle dev `0.94.0.9000`.
>
> *2026-06-19 (Partie B livrée côté app — v0.91.0)* : **sélecteur de couches
> FORDEAD** livré dans `nemetonshiny` v0.91.0 (commit `nemetonshiny@f4645a03`),
> consomme `nemeton::read_fordead_layer()` (**nemeton ≥ 0.94.0**). Couches
> **date 1re détection** / **indice d'anomalie** / **zone modélisée** + sévérité
> 0-4, masquage par strate (D2), opacité, fallback « couche indisponible » sur
> les anciens runs.
>
> *2026-06-23 (fix hors-chantier — v0.94.1)* : **FORDEAD install — vraie erreur
> pip**. Rapport terrain Windows : l'install des dépendances pinnées du venv
> `nemeton-fordead` échouait sur un message vide
> (`✖ FORDEAD pipeline failed: Error installing package(s):`). Cause :
> `reticulate::virtualenv_install()` lève un message générique sans le
> diagnostic pip. Fix : nouveau helper interne `.fordead_pip_install()`
> (`R/fordead_python.R`) qui lance pip dans l'interpréteur du venv, capture
> stdout+stderr, et sur échec `cli::cli_abort()` avec la fin de la sortie pip +
> causes courantes (git absent du PATH pour les pins `git+https`, réseau
> gitlab.com / forge.inrae.fr, roue non compilable). `.ensure_fordead_python()`
> recâblé. 2 tests helper + 3 tests d'orchestration mis à jour.
>
> *2026-06-20 (durcissement UX cartes FORDEAD — app v0.90.1 → v0.91.2)* :
> série de finitions app (aucune API cœur nouvelle au-delà de
> `read_fordead_layer`) — parité UGF/opacité avec la carte FAST, **classe 0
> transparente** (alertes visibles), **perf bascule de mode** (connexion DB
> réutilisée + validité mémoïsée, app v0.90.4), carte de base stable
> (clic-pixel rétabli), **aides « i » par couche**, **légende date en année**
> (app v0.91.1/v0.91.2).
>
> *2026-06-27 (fix hors-chantier — v0.94.3)* : **robustesse ingestion S2
> RECONFORT (console + disque)**. (1) *Console* : le diagnostic noyait ses
> messages sous des centaines de warnings bénins du téléchargeur vendoré
> (`pygeodes`/`urllib3` : « skipping download » ×140/tuile +
> `InsecureRequestWarning`). `.reconfort_run_py()` pose `PYTHONWARNINGS` pour
> filtrer **ces deux catégories** ; erreurs/tracebacks/stdout intacts. (2)
> *Disque* : une tuile×2 ans = ~200 GB de zips **+** ~250 GB d'extraits gardés
> en même temps → disque plein → `extractall` mourait sur `exit 1` opaque
> (`OSError [Errno 28]`). Parades : **extract-then-delete**
> (`reconfort_ingest_s2(keep_zips = FALSE)` défaut → archive supprimée dès son
> extraction, plafonne le pic disque) + **garde-fou pré-vol** (estime
> l'empreinte des scènes, abort chiffré si espace insuffisant). Incident réel
> 2026-06-27 (zone 5 Mouthe, T31UFQ, disque à 1.9 GB) débloqué par un script
> de purge sûr (137 zips redondants supprimés, 205 GB récupérés ; vérifie que
> chaque fichier non-SRE est extrait à la bonne taille avant suppression).
> `run_geodes_download.py` reste vendoré verbatim ; unzip n'a que
> l'extract-then-delete annoté `NOTE (nemeton)`, off par défaut. 41 tests
> ingest ✔.

---

# Chantier EN COURS — Suivi sanitaire : découplage de la placette (Phase A)

> **Cadré le 2026-06-18** (spec 008 **§15**, ADR-013 amendement **A5**, décision **D2**).
> Déclencheur : incident **Mouthe** (zone 5 `mouthe_tot`) — masque FORDEAD à
> 813 pixels classe 4 sur disque, **0 placette**, donc 0 alerte en base → UI
> « zone saine / aucune placette » (faux). Cf. mémoire
> `project_fordead_placette_decoupling`.

**Décision** : l'alerte santé devient une **entité raster/pixel** rattachée à
`monitoring_zone`, jamais à une placette. `plot` est découplé du suivi
sanitaire pour les 3 méthodes (FAST, FORDEAD, RECONFORT). FORDEAD est calculé
**une seule fois sur `_tot`** ; l'affichage par strate (`_res`/`_mix`) est un
simple **masquage** du raster `_tot` (`terra::mask` + AOI de strate), sans
recalcul (D2).

**Phasage** :
- **Phase A** (ce chantier, cible cœur **v0.92.0** + app `vX.Y.0`) : table
  `alert` **vidée** (`TRUNCATE` fait le 2026-06-18) + **plus alimentée** ; le
  masque 0-4 sur disque = source de vérité d'affichage. **Aucune migration.**
- **Phase B** (différée) : re-persistance pixel → migration inévitable
  (géométrie + `zone_id` + `n_pixels`/`area_m2`, `plot_id` nullable, nouvelle
  clé unique, fusion G2 spatiale). Hors-scope ici.

## Avancement Phase A — cœur `nemeton`

| État | Tâche | Détail |
|------|-------|--------|
| ✅ | **A1** | `fordead_pipeline.R` (persist) — appel `.insert_fordead_alerts()` retiré, `n_inserted <- NA_integer_` ; masque + bundle restent écrits ; message succès reformulé |
| ✅ | **A2** | `reconfort_pipeline.R` — appel `.insert_reconfort_alerts()` retiré ; `alerts_sf` désormais renvoyé dans le résultat (parité FORDEAD pour R5) ; `n_alerts = NA` |
| ✅ | **A3** | note legacy `@section Phase A` sur `.insert_fordead_alerts`, `.insert_reconfort_alerts`, `list_alerts` ; fonctions conservées (pas de `document()`) |
| ✅ | **A4** | `test-fordead-pipeline.R` : garde-fou « insertion non appelée » + assertions `NA`/`alerts_sf` (test « persist always » réécrit). reconfort/postprocess/R5 verts sans modif (FAIL=0) |
| ✅ | **A5** | release **v0.92.0** (PR #99 mergée, tag + release CI posés) ; cycle dev `0.92.0.9000` (PR #100). Fix CI annexe : job `tests` timeout 30→45 min |

## Avancement Phase A — app `nemetonshiny` (pour mémoire, repo séparé)

| État | Tâche | Détail |
|------|-------|--------|
| ✅ | **B1** | calcul forcé sur `_tot` (résolution `grep("_tot$", z$name)` avant `run_fordead_async`) ; stamping résultat / réconciliation disque alignés `_tot` ; garde-fou si pas de `_tot` ; notif de fin sans décompte (`n_alerts_inserted = NA`) |
| ✅ | **B2** | `mod_monitoring_fordead_map` : masque `_tot` lu, masquage à l'affichage par strate via `get_monitoring_zone_aoi()` (EPSG:2154) + `terra::mask()`, sans recalcul |
| ✅ | **B3** | « zone saine » piloté par le **raster** (classe ≥ 1 = affecté), plus par le compte d'alertes DB ; `alerts_panel`/`alerts_map` découplés de `list_alerts_for_zone()` (legacy Phase A) |
| ✅ | **B4** | i18n : terme « placette » retiré des messages santé FORDEAD |
| ✅ | **B5** | tests app AC.15.2 / 15.3 / 15.8 / 15.5 verts (suite : 0 FAIL) |
| ✅ | **B6** | release app **v0.90.0** (`Imports: nemeton (>= 0.92.0)`) |

**Journal** — *2026-06-18* : **chantier cadré** (paperwork). spec 008 §15 +
ADR-013 A5 rédigés ; table `alert` vidée en prod (`TRUNCATE`, elle était déjà
à 0 ligne — confirme le diagnostic Mouthe) ; mémoire
`project_fordead_placette_decoupling` créée. **R5 non impacté** (lit
`alerts_sf` en mémoire, pas la DB). Implémentation cœur A1-A5 démarrée sur la
branche `feat/health-decouple-placette-phase-a`.
>
> *2026-06-18 (suite)* : **cœur A1-A4 livrés** sur la branche. Insertion
> d'alertes débranchée des deux pipelines (FORDEAD + RECONFORT) ; `alerts_sf`
> renvoyé par RECONFORT ; fonctions d'insertion + `list_alerts` conservées et
> annotées legacy (Phase B). Tests : `test-fordead-pipeline.R` adapté
> (garde-fou non-appel + sémantique `NA`), reconfort/postprocess/R5 verts sans
> modif (FAIL=0 en local via `load_all` + `test_file`). **A5** : DESCRIPTION +
> NEWS + CITATION bumpés en **v0.92.0** (cohérents) ; PR vers `main` à ouvrir
> → `release.yml` posera le tag `v0.92.0`. Repasser ensuite en cycle dev
> `0.92.0.9000`. **Phase B et app (B1-B6) non démarrées.**
>
> *2026-06-18 (cœur livré)* : **PR #99 mergée** → release **v0.92.0** (tag +
> release GitHub posés par `release.yml`) ; cycle dev **`0.92.0.9000`**
> (PR #100). L'échec CI intermittent du job `tests` était un **timeout 30 min**
> sur runner lent (le job `coverage`, suite complète via covr, passait à 35 min)
> — corrigé : `tests` timeout porté à **45 min**. Aucune régression de code.
>
> *2026-06-18 (app livrée — Phase A / décision D2)* : **B1-B6 livrés côté
> `nemetonshiny`** — release **v0.90.0** (cycle dev `0.89.1.9000` → `0.90.0` →
> cycle dev `0.90.0.9000`), commit `nemetonshiny@e2124a57` (merge PR #86,
> *« feat(monitoring): affichage santé FORDEAD piloté raster + masquage par
> strate (Phase A) »*). Cœur consommé : **`nemeton@v0.92.0`** (PR #99), plancher
> app bumpé à `Imports: nemeton (>= 0.92.0)`. FORDEAD calculé sur `_tot` ;
> affichage par strate = masquage (`terra::mask` + `get_monitoring_zone_aoi`,
> EPSG:2154) sans recalcul ; « zone saine » décidée sur le raster (classe ≥ 1) ;
> placette retirée du mode santé. Tests **AC.15.2 / 15.3 / 15.8 / 15.5** verts
> (suite : 0 FAIL). **Phase A close.** Reste ouvert : **Phase B** (re-persistance
> pixel + migration géométrie/`zone_id`/`plot_id` nullable, fusion G2 spatiale).
>
> *2026-06-18 (Phase B cœur livrée — v0.93.0)* : re-persistance pixel des
> alertes. **Migration `0007_alert_pixel_geometry`** (pg + sqlite, `DROP`+`CREATE`
> table vide) → `alert` pixel (`zone_id` NOT NULL, `geom_wkt` 4326, `n_pixels`,
> `area_m2`, `cluster_id`, `plot_id` nullable, clé
> `(zone_id, alert_type, trigger_date, cluster_id)`). Helper partagé
> `.insert_health_alerts` (replace-by-window D-B1, géométrie D-B2) ;
> `.insert_fordead_alerts` / `.insert_reconfort_alerts` = wrappers, **re-câblés**
> dans les pipelines. `list_alerts()` lit `geom_wkt` ; `classify_disturbance()`
> (G2) jointe sur proximité spatiale (repli legacy `plot_id`). **FORDEAD
> mono-indice** : `.fordead_supported_vi` → `c("CRSWIR")` (NDVI/NDWI retirés ;
> l'app n'exposait déjà que CRSWIR). **R5 inchangé.** Tests **AC.15.9-15.12**
> verts (SQLite + base PG `nemeton_test`, 0 régression). **Reste : Phase B.2**
> — refonte du workflow de validation terrain G4 (`ingest_health_validation`)
> sur clé pixel (D-B4), encore sur modèle placette. Côté app : couche
> markers/centroïdes d'alertes à (ré)activer si souhaité.
>
> *2026-06-19 (Phase B.2 livrée — v0.93.1)* : **G4 découplé de la placette**.
> `ingest_health_validation()` snappe l'observation terrain sur le centroïde
> pixel de l'alerte (`alert.geom_wkt`, filtré `alert.zone_id`) au lieu de
> `JOIN plot` (qui ne renvoyait aucune alerte en modèle Phase B). Mapping
> stade→statut + `UPDATE alert` inchangés. Tests G4 verts (base PG de test).
> **Découplage placette du suivi sanitaire COMPLET** (cœur). Reliquat
> facultatif : couche markers d'alertes app + commentaire roxygen obsolète
> `nemetonshiny/R/service_monitoring.R:507`.

---

# Veille — projets externes susceptibles d'intéresser `nemeton`

Sources à passer en revue régulièrement pour identifier des logiciels,
services ou outils thématiques (forêt, végétation, télédétection) qui
pourraient devenir des dépendances amont, des sources de données NDP, ou
inspirer un épaississement.

| Source | URL | À surveiller |
|--------|-----|--------------|
| Theia / DATA TERRA — logiciels, services et outils thématiques | <https://www.theia-land.fr/blog/product/services-logiciels-et-outils-thematiques/#Logiciel> | Nouveaux produits/outils forêt-végétation-télédétection à intégrer comme sources de données (cf. chantier « Sources Theia ») ou comme briques amont. *Reliquat connu côté `nemeton` : MUSCATE, LST Thermocity, W1.* |

> **À faire** : parcourir la page ci-dessus, recenser les logiciels/outils
> pertinents et, pour chacun, décider s'il devient une source de données
> (déclaration dans `inst/datasources/`), une dépendance amont, ou une
> simple piste. La page renvoie un 403 aux robots — consultation manuelle
> nécessaire.

---

# Correctifs de production (hors chantier)

**Journal** — *2026-08-16* (**v0.172.0**) : **R1 feu — la résolution de travail
du chemin `fireexposuR` est bornée à 30 m**. Symptôme remonté du projet
**Fordead** : le calcul des 31 indicateurs restait affiché à 64 %,
`progress_state.json` figé sur `compute:indicateur_r1_feu` (19/35 faits). Le
processus n'était pas bloqué — 51 % d'un cœur en continu pendant > 75 min, état
`R`, **0 octet** de `rchar`/`wchar` sur 21 s, 2,7 Go de RSS pour un plafond
`NEMETON_MEMORY_MAX=10G`. Ni verrou, ni I/O, ni mémoire : un coût algorithmique.
**Cause** : `fire_exp()` construit sa fenêtre avec
`MultiscaleDTM::annulus_window(c(res, t_dist), "map", res)` puis
`terra::focal()` — la fenêtre est exprimée en mètres mais **matérialisée en
cellules**, ~`(2 * t_dist / res)^2` poids par pixel, d'où un coût total en
`1/res^4`. Sur Fordead, la mosaïque `lidar_mnt` 8000 × 10000 à 0,50 m était
ramenée à 2 m par `.dem_working_res()` (5 M cellules) et la fenêtre `t_dist =
500 m` pesait 501 × 501 ≈ 251 000 cellules, soit ~1,25e12 opérations
mono-thread — ~52 000× le coût du **30 m** pour lequel `fireexposuR` est
calibré (Landsat). **Correctif** : nouvel argument `fire_exp_res` (défaut 30) +
helper `.fire_exp_working_dem()`, qui borne la grille du `hazard` **du seul
chemin `fireexposuR`**. Le `.topo_target_res()` reste à 2 m — il a raison de
l'être pour R2, R3, W3 sur MNT LiDAR — et le repli `slope + species + climate`,
linéaire en cellules, garde `dem_target_res`. Trois choix d'implémentation :
(1) `max(fire_exp_res, res(dem))` — un BD ALTI 25 m (NDP 0) ou un MNT 100 m
n'est jamais ré-agrégé ni affiné ; (2) l'agrégation part du MNT **natif** et
non du MNT déjà ramené à 2 m, donc une seule passe 0,5 m → 30 m, et le 2 m
n'est plus calculé quand le chemin `fireexposuR` aboutit ; (3)
`fire_exp_res = NULL` retombe sur `dem_target_res`, échappatoire explicite vers
le comportement antérieur. Log contextualisé `R1/fire_exp` dans
`.dem_working_res()`. **Mesures** : sur une mosaïque de la taille de Fordead
(8000 × 10000 à 0,5 m écrite sur disque, 80 M cellules, `fireexposuR` réel),
`indicateur_r1_feu()` rend la main en **3,2 s** (CA-1 : < 60 s) ; grille du
`hazard` à 30 m vérifiée par test (CA-2) ; MNT 25 m / 100 m intouchés (CA-3) ;
corrélation Pearson > 0,95 et Spearman > 0,9 contre une référence non bornée sur
une emprise de 4 km (CA-4) — la borne change le temps, pas le classement des
unités. 9 `test_that` (33 assertions) dans `tests/testthat/test-r1-fire-exp-res.R`.
Suite complète : **9 943 PASS / 0 FAIL** (25 WARN, 17 SKIP, tous préexistants). **App** :
aucun changement requis, la signature reste compatible et `nemetonshiny` ne
passe pas ces arguments. Brief d'origine :
`specs/BRIEF-nemeton-r1-feu-resolution.md`.

---

**Journal** — *2026-06-12* (**v0.74.1**) : **fix `FOREIGN KEY constraint
failed` au re-build des zones de suivi (backend SQLite)**. Symptôme remonté
depuis `nemetonshiny` (Windows local = SQLite) :
`build_project_monitoring_zones(con, …, replace = TRUE)` réussissait sur une
base vierge mais échouait au **re-clic** sur un projet dont les zones
portaient déjà des lignes enfants (placettes de validation, alertes
FORDEAD). **Cause** : divergence de schéma PG↔SQLite — la variante SQLite
(`0001_init.sql`) avait retiré les `ON DELETE CASCADE` que porte PostgreSQL
sur `plot.zone_id → monitoring_zone(id)` et `alert.plot_id → plot(id)` ;
`db_connect()` activant `PRAGMA foreign_keys = ON`, le
`DELETE FROM monitoring_zone` de l'upsert D5 était bloqué par les enfants.
**Correctif (option B)** : `.delete_project_zones()` supprime la chaîne
explicitement, **enfant d'abord** (`alert` → `plot` → `monitoring_zone`),
dans une seule transaction — portable PG/SQLite. **Option A écartée** :
l'option initiale (migration `0006_zone_cascade` rebâtissant les tables
avec `ON DELETE CASCADE`) a été prise en défaut par la revue Codex (P1) et
la CI — sous la transaction unique de `db_migrate()`, `PRAGMA
foreign_keys` est un no-op et `defer_foreign_keys` ne lève pas la violation
différée laissée par le `DROP TABLE` du parent ; le COMMIT échouait
précisément sur les bases peuplées. Migrations 0006 retirées. Tests :
`test-zone-cascade.R` réécrit (suppression directe de la chaîne sans
dépendance sf/terra, scoping par `project_uuid`, no-op/idempotence, re-build
du builder réel, parité PG). **App** : aucun changement requis —
`nemetonshiny` (release v0.76.0) consomme déjà
`build_project_monitoring_zones()` et tire le fix via `Remotes:
pobsteta/nemeton@*release`. *(R indisponible en local : validation déléguée
à la CI R-CMD-check.)*

---

# Chantier CLOS — E7 : corpus de connaissances RAG (spec 009 / 009.1, ADR-012)

> **Clos le 2026-06-13.** Machinerie (v0.52.0), corpus **déployé en prod**
> (81 docs, 60 texte intégral, 6 120 chunks, 0 embedding manquant) et wiring
> app (perspectives IA sourcées) livrés. Objectif atteint : les perspectives
> IA sont effectivement citées-sourcées.

**Cadré** : 2026-05-29 (décisions D1-D5). Machinerie RAG livrée v0.52.0
(7 fonctions exportées, schéma opt-in `knowledge_*`, dual-backend
pgvector/cosinus), puis corpus alimenté/branché.

## Avancement du chantier

| État | Sous-chantier | Repo | Release |
|------|---------------|------|---------|
| ✅ | Machinerie RAG (`enable_rag()`, ingestion, retrieval, citations) | cœur | v0.52.0 (2026-05-29) |
| ✅ | Manifest (39 docs) + pipeline `build_knowledge_corpus.R` | cœur | (commités) |
| ✅ | Validation manifest (`test-knowledge-corpus-manifest.R`) + `inst/NOTICE` corpus + fix cohérence D5 | cœur | v0.61.1 (2026-06-02) |
| ✅ | **Arbitrage licences** — résolu : override D5 (v0.75.1) → 81 docs `cleared` ; copyright en `abstract_only`/`link_only`, scans OCRisés en `HAL` | cœur | v0.61.2 → v0.76.2 |
| ✅ | Ingestion référence seule (`ingest_knowledge_reference()`, link_only/abstract_only) + câblage pipeline | cœur | v0.62.0 (2026-06-02) |
| ✅ | **API administration corpus** (manifest éditable + import) — `knowledge_manifest_vocab/path`, `read/validate/write_knowledge_manifest`, `build_knowledge_corpus()` ; débloque l'onglet RAG des paramètres app (spec 009.2) | cœur | v0.63.0 (2026-06-03) |
| ✅ | **Build corpus réel** — pgvector prod peuplé via Mistral (`build_corpus_prod.sh` FRESH + `fill_corpus_prod.sh` incrémental) : **81 docs, 60 texte intégral, 6 120 chunks** | cœur | prod 2026-06-13 |
| ✅ | **Onglet RAG** (paramètres) — éditeur manifest + import via l'API 009.2 | `nemetonshiny` | nemetonshiny@8c6696b (v0.62.0, 2026-06-03) |
| ✅ | **Wiring** — injection chunks dans le prompt LLM + bloc UI « Sources » (`retrieve_knowledge` + `format_citations`) | `nemetonshiny` | app (livré) |

**E7 clos (2026-06-13)** — tout livré : machinerie (v0.52.0), API
administration corpus (v0.63.0), corpus curé et **déployé en prod**
(81 docs, 60 texte intégral, 6 120 chunks, 0 embedding manquant ; sources
externes citables, 4 scans OCRisés), wiring `nemetonshiny` (perspectives
IA sourcées : `retrieve_knowledge()` + `format_citations()` + bloc UI
« Sources », onglet admin RAG). Outils de (re)build prod :
`data-raw/build_corpus_prod.sh` (FRESH), `fill_corpus_prod.sh`
(incrémental), `ocr_biljou_scans.sh` (OCR). **Enrichissement futur
possible** (hors E7) : ajouter d'autres sources au manifest, lever les
21 références restantes vers du texte intégral si des PDF deviennent
disponibles.

**Journal** — *2026-06-13* : **curation du corpus (v0.75.0)**. Manifest
recentré sur des sources externes citables : retrait des 12 docs internes
MIT (tutoriels + specs 005/008) ; ajout des **54 références citées par
l'outil BILJOU** (INRAE Nancy, bilan hydrique — 11 fiches), toutes en
`to_confirm`/`abstract_only`/`copyright` (gel D5) ; **8 rapports
institutionnels passés en `cleared`** (ONF/RENECOFOR `LO-Etalab`, FAO 56
`CC-BY-NC`, EFI WSCTU n°1 `CC-BY`) avec URLs publiques ; 3 PDF récupérés
(Ulrich 1995, Badeau&Bréda 2008, FAO 56) → plan full-text 7 → 10. Manifest
39 → **81 docs** (31 cleared / 50 to_confirm). Scripts de provenance sous
`data-raw/`. Tests manifest verts (20 + 29). Build prod réel non rejoué
(reliquat « Build corpus réel » toujours 🟨).

**Journal** — *2026-06-13* : **levée du gel D5 + synchro prod (v0.75.1)**.
Les 50 `to_confirm` passent en `cleared` (override Pascal) → manifest
**81 cleared / 0 to_confirm** ; toutes en `abstract_only` donc ingérées en
références `link_only`. **Build prod FRESH rejoué** (`build_corpus_prod.sh`) :
pgvector synchronisé → **60 docs** (10 texte intégral + 50 références),
**2 354 chunks, 0 embedding manquant**, 12 tutos internes absents, 0 erreur.
21 sautés = `cleared`/`full` sans PDF (backlog d'enrichissement, gardés en
`full`). Le reliquat « Build corpus réel » 🟨 est donc **résolu** côté prod.

**Journal** — *2026-06-13* : **les 21 sautés entrent au corpus (v0.75.2)**.
IPCC 2019 (Vol.4 Ch.4 Forest Land) PDF récupéré → `full` ; les 20 autres →
`link_only` (références citables). **Manifest 81/81 ingérables, 0 sauté**
(11 texte intégral + 70 références). Métadonnée Monnet&Mermin 2014 corrigée
(*Forests* 5(9), pas *Remote Sensing*), `source_url` HAL ajoutés (Duplat,
Larrieu). PDF open-access HAL/MDPI/EUR-Lex non scriptables (mur anti-bot) :
URLs fichier consignées dans `data-raw/references/README.md` pour récupération
manuelle. Prod à resynchroniser (60 → 81 docs).

**Journal** — *2026-06-13* : **3 références → texte intégral (v0.75.3)**.
PDF open-access récupérés (hors Cloudflare) : Duplat 1997 (EDP afs-journal),
IBP/Larrieu (guide CNPF v3.2), Stratégie UE COM(2021)572 (EUR-Lex). Manifest
**14 full-text + 67 références** (81/81, 4 PDF présents sur disque). Non
récupérables (Monnet MDPI/HAL Cloudflare, portails OFB/ONF/CNPF, paywall)
restent `link_only` (liens directs dans le README). Prod toujours à
resynchroniser (60 → 81, dont 14 texte intégral).

**Journal** — *2026-06-13* : **46 réfs BILJOU → texte intégral (v0.75.4)**.
PDF hébergés par l'INRAE sur le portail BILJOU (`/biljou/pdf/`) : 50 récupérés
→ 44 docs câblés `full` (+ Monnet & Peiffer déposés), ex-`copyright` retagués
`license=HAL`. Comble 2 trous institutionnels (Bréthes 1997, Livre Jaune
Badeau faisabilité). Manifest **60 full-text + 21 références** (81/81, 0 sauté).
PDF gitignorés (`biljou/`, `**/*.pdf`), reconstitution via
`data-raw/wire_biljou_pdfs.R`. Prod à resynchroniser (60 → 81, dont 60 texte
intégral) — gros build (≈ +6000 chunks attendus).

**Journal** — *2026-06-03* : livré l'API d'administration du corpus
(spec 009.2, v0.63.0). Refactor : la logique « manifest → base » de
`data-raw/build_knowledge_corpus.R` est promue en 6 fonctions exportées
(`R/knowledge-corpus.R`), le script devient un wrapper CLI. Tests :
`test-knowledge-manifest-api.R` + `test-build-corpus.R` ajoutés,
`test-knowledge-corpus-manifest.R` refactoré pour consommer
`knowledge_manifest_vocab()`. `devtools::document()/test()/check()`
verts en local ; tag `v0.63.0` + release GitHub posés ; mergé sur `main`.

**Journal** — *2026-06-03* : **E7 — Onglet RAG ✅ livré**.
`nemetonshiny@8c6696b` (release v0.62.0, 2026-06-03). Onglet admin
« RAG / Corpus de connaissances » consommant l'API spec 009.2
(`knowledge_manifest_*`, `build_knowledge_corpus`,
`list/delete_knowledge_document`). Reliquat E7 distinct : wiring
`retrieve_knowledge()` + bloc « Sources » dans le prompt.

**Note** : plusieurs follow-ups app indépendants de E7 attendent aussi un
bump `nemetonshiny` — pré-calcul FAST (v0.61.0), wiring RAG (v0.62.0),
modal diagnostic pixel CRSWIR (L3 ci-dessous), toggle multi-cœur + toggle
NDVI/NBR (spec 017). Les briefs de hand-off (index des 5 chantiers + brief
RAG détaillé) ont été transmis à la session `nemetonshiny` le 2026-06-02
puis retirés de ce repo (suivi désormais côté app).

---

# Chantier — Suivi sanitaire : graphe trend par pixel + plan sanitaire (spec 023 / 025)

- [x] **Spec 023 — Trajectoire de déclin par pixel (graphe trend)**
      cœur `extract_pixel_trend()` + `extract_trend_series()` (nemeton v0.87.0) ;
      app graphe trajectoire NDRE au clic carte Alertes FAST (nemetonshiny v0.86.0)
- [x] **Spec 025 — Plan d'échantillonnage sanitaire sur le trend (Option A)**
      cœur `create_trend_sanitary_plan()` (nemeton v0.88.0) ;
      app « Plan de validation FAST » branché sur le trend (nemetonshiny v0.87.0)
- [x] **Spec 014 — Tirage validation pondéré continu FORDEAD/RECONFORT** (parité FAST)
      cœur `create_validation_sampling_plan(weighting = "continuous", weight_raster)`,
      poids ∝ sévérité par pixel (FORDEAD `anomaly_index`, RECONFORT `score`) —
      livré cœur **nemeton v0.140.0**, consommé app **nemetonshiny v0.100.4**

---

# Chantier en cours — RECONFORT : suivi sanitaire feuillus (spec 021, ADR-013 A4)

**Cadré** : 2026-06-10 (paperwork : `specs/021-suivi-sanitaire-reconfort/`
plan.md + spec.md ; ADR-013 amendement A4 dans `nemetonplateform`).
**Objectif** : ajouter **RECONFORT** (Mouret et al. 2023, Apache-2.0) comme
3ᵉ méthode de suivi sanitaire — diagnostic du **dépérissement des feuillus**
(chêne/châtaignier/pin sylvestre, Centre-Val de Loire) via Random Forest
supervisé sur indices CRswir/CRre (chaîne IOTA²), en complément de FORDEAD
(résineux) et FAST. R5 unifié routé par essence.

## Avancement du chantier

| État | Lot | Contenu | Release |
|------|-----|---------|---------|
| ✅ | **L1** | Domaine de validité (`reconfort_validity.R`, GeoJSON 6 dép. CVL, tests) — garde-fou G3 advisory | **v0.70.0** (2026-06-11) |
| ✅ | **L2a** | `reconfort_model.R` : `ensure_reconfort_model()` + registre `RECONFORT_MODELS` + fallback `local_path` (fetch à la demande + checksum MD5 + cache) | **v0.71.0** (2026-06-11) |
| ✅ | **L2b.1** | `reconfort_python.R` (env conda IOTA² locate+validate) + `RECONFORT_BANDS` + glue vendorisée `custom_index.py` + NOTICE | **v0.72.0** (2026-06-11) |
| ✅ | **L2b.2** | Ingest IOTA²-natif : `reconfort_aoi_tiles()` (grille MGRS embarquée) + `reconfort_ingest_s2()` (pygeodes download + unzip) + scripts vendorisés | **v0.73.0** (2026-06-11) |
| ✅ | **L2b.3** | `reconfort_pipeline.R::run_reconfort_dieback()` : orchestration env→model→masque→tuile→ingest→IOTA² ×2+score, staging par-run, `ensure_reconfort_oso_mask()` + glue map-production vendorisée | **v0.74.0** (2026-06-12) |
| ✅ | **L3** | `reconfort_postprocess.R` (rasters → table `alert`, centroïdes, `confidence_class`, `stress_index` = score continu) + migration **`0006`** + `classify_disturbance()` 3-voies (`method_overlap`) + phase `postprocess` dans `run_reconfort_dieback()` | **v0.77.0** (2026-06-13) |
| ✅ | **L4** | R5 unifié routé par essence : `indicateur_r5_deperissement(reconfort_results=)`, RECONFORT (chêne/châtaignier/pin sylvestre) vs FORDEAD (épicéa/sapin), statuts `calculated_reconfort`/`skipped_no_reconfort`/`skipped_no_method`, helpers `.resolve_reconfort_share`/`.r5_prepare_alerts`/`.r5_score` | **v0.78.0** (2026-06-13) |
| ✅ | **L5** | Persistance features CRswir/CRre (option B : recalcul depuis le S2 ingéré) — `reconfort_outputs.R` (formules, stacks datés, bundle) + phase `persist` dans `run_reconfort_dieback()` + `read_reconfort_pixel_series()` (lecteur, sans reticulate) | **v0.80.0** (2026-06-13) |
| ✅ | **L6** | App `nemetonshiny` : 3ᵉ mode, bannières, plotly, QField feuillus | **clos** : carte + diagnostic pixel (`nemetonshiny` v0.81.0) + pipeline de run (v0.82.0) + sous-onglet « Plan de validation RECONFORT » G4 (`nemetonshiny` v0.83.0, réutilisation 1:1 de `mod_validation_sampling`). G4 cœur (stades DEPERIS + `read_reconfort_alert_mask`) livré en nemeton v0.83.0. |

**Reporté** (vs plan §5) : flag NDP `health_reconfort` + datasource
`reconfort_anomalies` — supposaient une parité FORDEAD inexistante. **L2b
cadré** (`L2b-cadrage.md` : ingest IOTA²-natif, env conda locate+validate, glue
complète) et **scindé** en L2b.1/.2/.3 — **les trois livrés**. **L3 livré**
(v0.77.0) : `reconfort_postprocess.R` (reclassif → patches 8-connexité →
centroïdes POINT, score continu en `stress_index`), migration **`0006`**
(numéro réel — `0005` pris par spec 020 multi-zone), `classify_disturbance()`
étendu à 3 voies + drapeau `method_overlap`, phase `postprocess` (best-effort)
dans `run_reconfort_dieback()`. **Réserve** : `RECONFORT_CONFIDENCE_WEIGHTS`
posés en **provisoire** (à caler sur la matrice de confusion Mouret et al.
2023 — flaggé dans le code). **Prochaine étape : L4** (R5 unifié, routage par
essence). Faits amont vérifiés : `…/plan.md` §10.

## Sous-chantiers (post-L6)

- [x] **Manifeste des couches RECONFORT pour l'app** — `reconfort_layer_manifest(result, include_range)`
      (rasters score / classification / probability + vecteur alertes ; palettes, domaines,
      reverse, visibilité par défaut). Consommé par le sous-onglet « Alertes RECONFORT » de
      nemetonshiny : cases à cocher des couches, curseur d'opacité, couche UGF, clip des
      rasters à la strate sélectionnée.

#### 2026-06-28 — Couches RECONFORT dans l'app (cœur → app)

**Cœur — `nemeton@v0.97.0` (commit `8c32b77`)**
`reconfort_layer_manifest(result, include_range = FALSE)` exporté. Retourne
un `data.frame`, une ligne par couche disponible :
`id`, `label_key`, `type` (`raster`/`vector`), `role`, `path`,
`categorical`, `palette`, `reverse`, `vmin`/`vmax`, `default_visible`,
`default_opacity`, `n_features`. Rasters `score` (RdYlGn, reverse) /
`classification` (catégoriel) / `probability` (viridis) + ligne `alerts`
conditionnée à `.reconfort_alert_count(result) > 0`. `include_range = TRUE`
calcule les domaines réels via `terra::minmax`. Contrat stable : l'app ne
lit jamais `result$rasters` en dur.

**App — nemetonshiny `v0.92.2` puis `v0.92.3`**
- `v0.92.2` (commit `nemetonshiny@167cf4cd`, cycle dev `0.92.1.9001`) —
  `mod_monitoring_reconfort_map` consomme le manifeste : cases à cocher des
  couches (vecteur/rasters) + curseur d'opacité (re-render léger
  `leafletProxy`). `result` de `run_reconfort_dieback()` threadé du parent
  (`reconfort_result` → `result_r`). Plancher relevé à
  `Imports: nemeton (>= 0.97.0)`. (Lot couplé au retrait du sous-onglet
  doublon « Alertes FORDEAD ».)
- `v0.92.3` (commit `nemetonshiny@7e7db429`, cycle dev `0.92.2.9001`) —
  parité complète FORDEAD/FAST : contrôles en sidebar droite
  (`layout_sidebar`), carte Leaflet statique + overlay (préserve le
  clic-pixel CRSWIR/CRre), couche UGF en overlay toggleable
  (`project$indicators_sf`), et clip des rasters à l'AOI de la zone de suivi
  sélectionnée (`_tot`/`_res`/`_feu`/`_mix`) via `terra::mask` — présentation
  pure, aucun calcul métier côté app.

**Ordre cœur → app respecté** : `nemeton@v0.97.0` publié d'abord, propagé à
l'app via `@*release`. Aucune dépendance inverse.

- [x] **L7 — masque UGF des sorties RECONFORT (reader cœur)** —
      `read_reconfort_layer(layer, con, zone_id, apply_zone_mask = TRUE,
      mask_polygon)` : lit une couche raster RECONFORT et la masque au polygone
      des UGFs au read-time (parité FAST/FORDEAD, spec 016). Rapatrie le clip
      que l'app faisait en présentation (v0.92.3).

#### 2026-06-28 — L7 : reader cœur masqué UGF (`read_reconfort_layer`)

- **Cadrage** : `specs/021-suivi-sanitaire-reconfort/L7-clip-ugf-cadrage.md`
  + ADR-013 amendement A6 (draft `ADR-013-A6-reconfort-zone-mask.md`, à porter
  dans `platform_nemeton`). 3 décisions actées (AskUserQuestion 2026-06-28) :
  `apply_zone_mask` (pas `clip_to_aoi`), masque au **read-time**, centroïdes
  **non clippés** (parité spec 016).
- **Cœur — `v0.98.0`** : `read_reconfort_layer()` exporté
  (`R/reconfort_manifest.R`) — analogue de `read_fast_alert_raster()` /
  `read_fordead_dieback_mask()`. Accepte un chemin **ou** une ligne raster du
  manifeste (`type == "vector"` rejetée) ; masque via les helpers spec 016
  `.apply_zone_mask()` / `.get_zone_aoi()` ; polygone résolu par
  `mask_polygon` sinon `con` + `zone_id` ; `cli_warn` + raster brut si rien
  n'est résoluble. 11 tests (`test-reconfort-reader.R`). Manifeste L6 inchangé.
- **App — `v0.93.0` (`nemetonshiny@628a49b2`)** ✅ : consomme
  `read_reconfort_layer()` et **retire son `terra::mask` local** (v0.92.3) →
  la sémantique spatiale **raster** revient au cœur.

- [x] **L7 (suite) — filtre des alertes au polygone UGF** —
      `filter_alerts_to_zone(alerts, con, zone_id, apply_zone_mask)` : ne garde
      que les centroïdes dans l'UGF, au read-time. Révise D3 (les alertes
      RECONFORT débordaient des UGFs).
- [x] **Parité des 3 pipelines (raster + vecteur)** — FAST / FORDEAD / RECONFORT
      masquent désormais raster **et** vecteur dans leur reader cœur ; aucune
      opération spatiale de masquage dans les `mod_*` de `nemetonshiny`
      (ADR-009, règles strictes §1-3). App à jour jusqu'à `v0.93.1`.

#### 2026-06-29 — L7 (suite) : filtre vectoriel des alertes (`filter_alerts_to_zone`)

- **Constat (run réel 2026-06-29)** : run zone 5 complété (1336 alertes), mais
  le **vecteur d'alertes débordait largement des UGFs** alors que le score
  raster, lui, était bien clippé (v0.98.0). Cause : le postprocess extrait les
  centroïdes du `Final_Classif_masked_<year>.tif`, masqué par **OSO feuillus**
  (occupation du sol) et **pas** par l'UGF → clusters sur tous les feuillus de
  la bbox + 3 km. La décision L7 §D3 (« ne pas clipper les centroïdes », parité)
  reposait sur une hypothèse fausse (« centroïdes issus de rasters UGF-masqués »).
- **Décision (AskUserQuestion 2026-06-29)** : clip **au read-time** (parité
  `read_reconfort_layer`) + **étendu aux 3 pipelines**. D3 révisée.
- **Cœur — `v0.99.0`** : `filter_alerts_to_zone()` exporté (`R/zone_aoi.R`),
  **helper unique partagé** RECONFORT/FORDEAD/FAST (le filtre `sf` POINT est
  identique → vraie parité, pas de duplication). Interne
  `.filter_alerts_to_zone()` miroir de `.apply_zone_mask()`. Filtre au read,
  table `alert` non modifiée ; reprojection CRS ; `cli_warn` + passthrough si
  pas de polygone ; opt-out `apply_zone_mask = FALSE`. 8 tests
  (`test-filter-alerts-to-zone.R`).
- **App — `v0.93.1` (`nemetonshiny@703bdd66`)** ✅ : `alerts_r` enchaîne
  `list_alerts()` → `filter_alerts_to_zone()` (RECONFORT **et** FORDEAD). Clôt la
  **parité raster + vecteur des 3 pipelines** : plus aucune sémantique spatiale
  de masquage côté `nemetonshiny`.

#### 2026-06-29 — Fix sens de R5 dans la famille R (`normalize_indicator`)

- **Constat** : en traçant R5 → famille R → indice général, `normalize_indicator()`
  laissait passer **R5 brut** (orienté « haut = dépérissement », mauvais) alors
  que R1-R4 sont « haut = bon ». La moyenne `famille_risque` était donc tirée à
  l'envers (une UGF très dépérie *remontait* le score).
- **Vérif app** (agent Explore sur `nemetonshiny`) : l'app **ne compense pas** —
  en fait **R5 n'est pas encore branché** dans le radar (famille R = R1-R4 ;
  placeholder i18n « future »). Bug donc **latent**, mais le cœur est conçu pour
  inclure R5 → correctif côté cœur pour garantir l'orientation au branchement.
- **Cœur — `v0.99.1` (fix)** : `normalize_indicator()` inverse R5
  (`100 - score`, colonnes `indicateur_r5_deperissement` / `R5`), au même endroit
  que l'inversion s1/s2 déjà présente. `indicateur_r5_deperissement()` **inchangé**
  (API brute « haut = dépérissement »). Tooltip R5 reformulé (« Score élevé =
  faible dépérissement » + mention RECONFORT). 3 tests (`test-normalization.R`) ;
  non-régression vérifiée (deperissement 42, famille 95, intégration 91, risque
  153, viz 232).
- **Reste** : option « champ `direction` générique dans `indicator-config` » non
  retenue (plus lourde) ; si un autre indicateur « haut = mauvais » apparaît, le
  refactor pourra être repris.
- **App — `nemetonshiny@v0.94.0` (2026-06-30)** ✅ : R5 **branché dans le radar**
  (`R/service_r5.R::add_r5_to_indicators()` injecté dans `mod_synthesis` avant
  `create_family_index`). Routage par essence via **intersection d'alertes**
  (pas de colonne d'essence sur les UGF) ; R5 passé **brut** (le cœur inverse,
  pas de double-inversion). Best-effort : sans zone/alerte → famille R = R1-R4.
  Famille R cœur passe à 32 indicateurs (R5 conditionnel).

- [x] **Découverte cache des couches RECONFORT (parité `read_fordead_layer`)** —
      `reconfort_cache_manifest(cache_dir, zone_id, run_id, include_range)` :
      réaffiche les rasters RECONFORT après rechargement de projet (sans le
      `result` mémoire).

#### 2026-06-30 — Découverte cache couches RECONFORT (`reconfort_cache_manifest`)

- **Problème** : l'app n'affichait les rasters RECONFORT (classification/score/
  proba) qu'à partir du `result` mémoire d'un run de la session courante. Après
  rechargement de projet → `result` perdu → seules les alertes (DB) restaient.
  FORDEAD, lui, relit ses couches du cache (`read_fordead_layer`).
- **Cœur — `v0.100.0`** : `reconfort_cache_manifest()` exporté
  (`R/reconfort_manifest.R`) — reconstruit le manifeste depuis le cache,
  **schéma byte-identique** à `reconfort_layer_manifest()` (constructeur de
  lignes partagé `.reconfort_build_manifest()`). Résolution du run (le plus
  récent sinon `run_id`), exclut les stacks CRswir/CRre. **+ persistance
  étendue** : la phase `persist` cache désormais aussi `reconfort_score_<run>` /
  `reconfort_proba_<run>` (sinon score/proba, qui ne vivaient que dans le
  workdir transitoire, ne réapparaissaient pas). 18 tests
  (`test-reconfort-cache-manifest.R`).
- **Fix `v0.100.1`** : la découverte ratait le bon dossier. Les rasters
  d'affichage persistent dans le dossier IOTA² `final/`
  (`output_zone_<id>/results/.../final/Final_*.tif`), pas dans `zone_<id>/`
  (qui n'a que le masque + mes copies run-scopées, absentes des runs déjà
  faits). `reconfort_cache_manifest()` lit désormais `final/` en priorité
  (repli `zone_<id>/`). Validé sur le cache réel zone 5 → 3 couches. +9 tests.
- **Suite app** : `mod_monitoring_reconfort_map` → `manifest_r` retombe sur
  `reconfort_cache_manifest(cache_dir, zone_id)` quand `result_r()` est NULL
  (toggles/opacité/clip/pixel-click inchangés). Plancher `nemeton (>= 0.100.1)`.

---

# Chantier EN COURS — reGénération : microclimat sous couvert (spec 027, ADR-014)

**Cadré** : 2026-06-30 (paperwork : `specs/027-regeneration-microclimat/spec.md`
+ ADR-014 dans `nemetonplateform`). **Objectif** : onglet « reGénération » —
aptitude microclimatique à la régénération (microclimf + ERA5-Land + LiDAR HD,
repli opencanopy). Sous-indicateurs A3/A4/W4/**R6** (R5 pris par dépérissement),
pas de 13e famille (radar 12 axes). Mode augmenté `microclimate_model`.

**État des lots (2026-07-03)** :

| Lot | Contenu | État |
|-----|---------|------|
| L1 | Sous-indicateurs microclimat A3/A4/W4 (cœur) | ✅ v0.101.0 |
| L2 | Sensibilité R6 + années E-OBS (cœur) | ✅ v0.102.0 |
| L3 | Indice `indice_priorite_regen` + tolérances essence (cœur) | ✅ v0.115.0 |
| — | Scaffolds moteurs L1/L2 + branche A E-OBS + sélecteur + table UE (cœur) | ✅ v0.116.0→v0.120.0 |
| **L4** | Onglet + module `mod_regeneration` (app) | ✅ **nemetonshiny v0.98.0** |
| **L5** | Profil LLM « Adaptation climatique » (app) | ✅ **nemetonshiny v0.98.0** |
| **L6** | Persistance `regeneration_states` + export GPKG + section PDF Quarto (app) | ✅ **nemetonshiny v0.98.0/.1/.2** |

**Reste cœur** :
- ✅ **Mapping TFV → essence de régénération** — **livré v0.121.0** :
  `map_tfv_to_species_class()` (colonne `species_class` de `bdforet_v2_mapping()`)
  + `regen_species_choices(tfv_col=)` (mode espèces FRM, présence UGF via TFV) +
  `indice_priorite_regen(species=)` résout classe **et** espèce UE. L'app
  pré-remplit « Essence cible » depuis BD Forêt v2.
- Orchestration RÉELLE des moteurs (microclimf/biljouR/lasR/SAFRAN) : chez Pascal
  (deps + données), via le chemin `precomputed` déjà en place.

**Volet cœur spec 027 : clos.** Tout le calculable/testable est livré et releasé
(v0.101.0 → v0.121.0). Reste hors-cœur : l'orchestration réelle des moteurs (chez
Pascal). Calibration fine (ClimEssences/RMT AFORCE) : non retenue, table UE
sourcée jugée suffisante.

**Briefs app livrés (aucun changement cœur)** :
- [x] Brief app « engine-feedback » livré (spec 027) — boutons async reGénération
      (moteur réel & Auto E-OBS) : input_task_button (anti-reclic + spinner),
      notif persistante bas-droite, chrono MM:SS. Aucun changement cœur.
      → nemetonshiny@3705000f, release v0.100.7.
- [x] Brief app « cleanups-lowpriority » livré — hygiène CRS à la source
      (LiDAR HD→2154, WMS NDP 0→4326, stamp conditionnel) + retrait de l'appel
      déprécié theia_configure_s3(). Aucun changement cœur.
      → nemetonshiny@804d17d1, release v0.100.7.
- [x] Brief app « microclimf-vegetation-structure » livré — le moteur réel
      (« Lancer le moteur réel ») produit enfin `sensibilite.gpkg` : l'app fournit
      la structure de végétation exigée par `regen_sensibilite()` (`las` nuage
      LiDAR HD prioritaire, sinon repli `pai` LAI S2/PROSAIL). Aucun changement
      cœur. → nemetonshiny@5493df2c, release v0.100.8.
- [x] Brief app « engine-phase-status » livré — **message de phase en cours du
      moteur reGénération** (notif bas-droite). Canal fichier
      `engine_status.json` (écriture atomique tmp+rename côté worker `future`) +
      poll `invalidateLater(1000)` côté module ; 6 phases rendues (grille → PAI →
      microclimat étés moyens `year (i/n)` → canicule → exposition → BILJOU) +
      `microclimf_skipped`. Consomme l'événement cœur `regen_expo:pai`
      (**nemeton 0.144.0**, `source` lidar|satellite). **Lève la réserve §5** de
      `brief-nemetonshiny-engine-feedback.md`. → nemetonshiny@95733907,
      release v0.100.11 (cycle dev 0.100.11.9000).
- [x] **pai-cache** — cache disque du PAI LiDAR (`cache/regeneration/pai.tif`) passé à
      `regen_sensibilite()` sur la branche LiDAR only : ~38 min économisées par run.
      Phase « PAI (cache) » (`source="cache"`) exposée au canal de statut, lien
      « Recalculer le PAI » sous le badge « Canopée : LiDAR HD ». Livré app
      **v0.100.14** (`nemetonshiny@22713c93`), cycle dev `0.100.14.9000`.
      Plancher app relevé à `nemeton (>= 0.146.2)` (microclimf 2.0.0 bout-en-bout).
- [x] R7 « risque de gel tardif » + moteur meteoland live (indicateur_r7_gel,
      meteoland_daily_grid, build_safran_stations, eobs_downscale engine=meteoland) —
      cœur v0.151.0, app nemetonshiny@9e0d1189 (v0.104.0 : moteur opt-in + cache
      tmin.tif + carte gel + R7 au radar reGénération, sens normal NA-safe). — 2026-07-12
- [x] Contexte régional E-OBS en raster — 3 vues : eobs_downscale(var="tx"/"rr")
      + eobs_downscale_bivariate(tx,rr) (classes 1-9, palette colors/labels),
      dem=NULL auto-source WMS IGN — cœur v0.153.0, app nemetonshiny@53b15066
      (v0.106.0 : sélecteur 3 vues + légende bivariée 2D + download rr + async/cache). — 2026-07-12
- [x] **Spec 036 — graphiques au clic sur la carte « Contexte régional (E-OBS) »** :
      clic → panneau de 4 graphes (série+tendance, anomalies, distribution régionale,
      diagramme ombrothermique Gaussen-Bagnouls). Cœur = 3 accesseurs
      `eobs_summer_series` / `eobs_monthly_climatology` / `eobs_trend_fit`
      (**nemeton v0.160.0**) ; brief app `brief-nemetonshiny.md`. Câblage livré app
      **nemetonshiny@0bebc6d7 (v0.107.0)**. — 2026-07-16
- [x] **Spec 039 — recommandation d'essences reGénération (top-N + conseil IA)** :
      approche hybride = classement DÉTERMINISTE cœur + mise en prose IA. Cœur =
      `regen_rank_species` / `regen_rank_to_wide` + normalisation R6 `sensibilite_score`
      (spec 038), **nemeton v0.162.0**. App : **P1** top-3 déterministe par UGF dans la
      fiche parcelle (score d'adéquation, facteur limitant, confiance, invasives
      écartées ; wrapper `regeneration_species_ranking` NA/erreur-safe) —
      **nemetonshiny@38b85d00 (v0.107.16)** ; **P2** sidebar « Affiner la reGénération
      avec l'IA » (le LLM met en prose le top-3 + station par profil expert, garde-fou
      anti-essence-hors-classement) — **nemetonshiny@ad77876f (v0.107.17)**. Plancher
      app `Imports: nemeton (>= 0.162.0)`. — 2026-07-16

Les deux briefs app du volet moteur spec 027 sont désormais clos ; **plus aucun
brief app en attente sur ce chantier**.

#### 2026-06-30 — L1 cœur : indicateurs microclimatiques A3/A4/W4 (`v0.101.0`)

- **Cadrage** : spec 027 + ADR-014 (mergé `nemetonplateform` PR #8). 3 corrections
  au brief actées : **R6** (pas R5, pris), **ADR-014** (pas 012), **spec 027**.
  Décision années R6 = détection auto E-OBS + override (validé).
- **Cœur — `v0.101.0`** : `R/indicators-microclimate.R` — `indicateur_a3_microclimat`
  (A3, T°max sous couvert, décroissant), `indicateur_a4_tamponnement` (A4,
  tamponnement, croissant), `indicateur_w4_vpd` (W4, VPD, décroissant). Consomment
  un jeu `micro` (rasters JJA), agrègent par UGF (couverture-pondérée), écrivent
  score 0-100 (code court) + brut + `couverture_pct` + flag `microclimate_model`.
  Familles A→4 / W→4 dans `indicator-config.R`. Flag dans `detect_ndp()`. Sources
  `FR.json` (era5/eobs/lidarhd). Dépendances lourdes en `Suggests`. Scaffold
  `microclimate_run()` (contrat `micro` ; orchestration microclimf différée —
  données requises, non testable CI ; **pas de prototype dans les repos**). 16
  tests. Non-régression famille/intégration/NDP/air OK.
- **Reste** : L3 (composite par essence), L4 (onglet `nemetonshiny`), L5
  (doc/vignette). + câblage réel microclimf/lasR (L1b) quand données disponibles.

#### 2026-06-30 — L2 cœur : sensibilité R6 + années E-OBS (`v0.102.0`)

- **Cœur — `v0.102.0`** : `indicateur_r6_sensibilite` (R6, famille R) — Δ stress
  canicule − moyenne (ΔT°max + ΔVPD standardisés, canopée figée), décroissant
  (peu sensible = 100). Sens haut=bon → pas d'inversion (≠ R5). Famille R → R1…R6
  (`indicator-config.R`). `R/microclimate_years.R` : `microclimate_detect_years()`
  (auto E-OBS : été le plus chaud vs médiane, départage proche-LiDAR, `year_window`)
  — sélecteur pur testable ; extraction E-OBS raster différée (donnée requise) ;
  override utilisateur. 33 tests (microclimat 23 + years 10). Non-régression
  famille/déperissement/ndp OK.
- **Reste** : L3 (composite `regeneration_index` par essence), L4 (onglet), L5 (doc).

---

# Infra — Isolation reticulate multi-env (Open-Canopy / FORDEAD / Theia)

#### 2026-06-30 — `run_reticulate_isolated()` (`v0.103.0`)

- **Problème** : reticulate ne lie qu'un Python par session R. Open-Canopy (conda
  `open_canopy`), FORDEAD (virtualenv) et Theia ne peuvent pas tous passer par
  reticulate in-process → le premier lié gagne, les autres échouent (incident :
  reticulate happé par un Python uv éphémère → CHM Open-Canopy KO → P1/P2/P3/E1
  en échec).
- **Cœur — `v0.103.0`** : `run_reticulate_isolated(fun, args, python|virtualenv|
  condaenv, show)` (`R/reticulate_isolated.R`) — exécute `fun` dans un
  sous-processus `callr` à `RETICULATE_PYTHON` épinglé + `R_ENVIRON_USER=""`
  (un `~/.Renviron` ne peut pas écraser). Repli in-process. `callr` en Suggests.
  8 tests (sous-process réel : env transmis, args, fallback). Alternative
  déterministe à un `RETICULATE_PYTHON` global (qui ne sert qu'un env).
- **App** : Open-Canopy déjà isolé côté `nemetonshiny` v0.94.5.9001 (pattern
  inline équivalent — débloque les indicateurs Production).
- **Reste** : isoler le **bloc modèle FORDEAD** (`FordeadProcess` fit/predict) via
  la primitive — étape dédiée car frontière complexe (DB `con`, callbacks de
  progression, cancellation, raster `first_dieback_date` en mémoire, 22 tests
  mockés in-process à adapter) ; à valider sur un vrai run (env fordead + données).

---

# Chantier clos (côté cœur) — Diagnostic pixel CRSWIR (spec 008 §14, ADR-013 A3)

> **L1 + L2 livrés** (v0.42.0 / v0.43.0). Seul **L3** (modal plotly,
> côté `nemetonshiny`) reste ouvert — voir le brief app.

**Démarré** : 2026-05-21. **Cible** : v0.42.0 (L1) puis v0.43.0 (L2).
**Objectif** : rendre la Carte FORDEAD diagnostique au clic, à parité avec
la Carte pixel FAST. Trois sous-livraisons (spec 008 §14.2) :

- **L1 — cœur, v0.42.0** : la phase `persist` de `run_fordead_dieback()`
  écrit un *bundle diagnostic* curé sous `<mask_cache_dir>/zone_<id>/model_<run_id>/`
  (`coeff_model.tif`, `crswir_stack.tif`, `first_anomaly.tif`,
  `run_meta.json`). Best-effort. Résultat enrichi de `rasters$model_dir`.
- **L2 — cœur, v0.43.0** : fonction exportée `read_fordead_pixel_series()`
  reconstruisant la prédiction harmonique via reticulate (`fordead.modeling`).
- **L3 — app `nemetonshiny`** : handler de clic + modal plotly.

## Avancement du chantier

| État | Sous-chantier | Release |
|------|---------------|---------|
| ✅ | L1 — bundle diagnostic persistant | v0.42.0 (2026-05-21) |
| ✅ | L2 — `read_fordead_pixel_series()` | v0.43.0 (2026-05-21) |
| ⬜ | L3 — modal plotly (nemetonshiny) | app |

**Layout FORDEAD 2.x confirmé** (run réel zone villards) : les coefficients
harmoniques vivent dans `<output_dir>/fit/model.tif` (5 bandes), le CRSWIR
observé dans `<output_dir>/CRSWIR/fordead_<date>_CRSWIR.tif` (163 dates), les
masques pixel dans `<output_dir>/INVALID_PIXEL_MASK/`. `first_anomaly` est le
raster déjà dérivé par `.compute_first_dieback_date()`.

**L1 — livré (release v0.42.0, 2026-05-21)** :
helpers `.build_crswir_masked_stack()` + `.write_fordead_model_bundle()`
(`fordead_outputs.R`), appelés en phase `persist` de `run_fordead_dieback()` ;
résultat enrichi de `rasters$model_dir`. Best-effort. Tests : `test-fordead-outputs.R`
41 ✔ (8 neufs), `test-fordead-pipeline.R` 69 ✔ (bundle + best-effort AC.14.5).

**L2 — livré (release v0.43.0, 2026-05-21)** : fonction exportée
`read_fordead_pixel_series(con, zone_id, xy, crs, run_id, cache_dir)` —
lit le bundle L1, extrait le pixel cliqué, reconstruit la prédiction
harmonique via `fordead.modeling.compute_HarmonicTerms` (reticulate,
décision D3 — parité bit-à-bit, `dates_to_days` recalculé en R car
simple soustraction depuis `REF_DAY = 2015-01-01`). Nouveau fichier
`R/fordead_pixel_series.R` (+ helpers `.locate_fordead_model_bundle()`,
`.crswir_stack_dates()`, `.fordead_harmonic_predict()`). Tests :
`test-fordead-pixel-series.R` 32 ✔ (13 blocs, fixture bundle
synthétique, prédiction mockée pour l'offline ; parité AC.14.2 testée
contre le venv réel, tolérance 1e-6).

**Prochaine étape** : L3 — handler de clic + modal plotly sur
`mod_monitoring_fordead_map` (côté `nemetonshiny`, hors repo cœur).
Le chantier « Diagnostic pixel CRSWIR » est clos côté cœur.

---

# Chantier clos — Sources de données Theia (catalogue DATA TERRA)

**Démarré** : 2026-05-20. **Clôturé** : 2026-05-20 (release v0.35.0).
**Objectif** : intégrer le catalogue Theia / DATA TERRA comme sources de
données pour le calcul des 12 familles d'indicateurs. FORMS-T a ouvert la voie
(release v0.28.0) ; ce chantier a généralisé l'approche aux autres produits
Theia pertinents.

**Bilan** : 10 sources cataloguées (Phase 1, v0.28.0-v0.30.0), loaders
(Phase 2, v0.31.0), câblage de 4 sources dans 6 indicateurs + 1 helper
(Phase 3, v0.32.0-v0.35.0). Reliquat de 4 câblages documenté ci-dessous
(Phase 3d).

## Principe d'architecture — 3 niveaux d'intégration

Du moins au plus invasif :

- **Niveau 1 — Catalogue** (déclaratif) : chaque source est déclarée dans
  `inst/datasources/FR.json` (section `datasets`) avec type, résolution, unité,
  CRS, accès (DOI / STAC / catalogue), licence, `ndp_level`, et un bloc
  `consumed_by` documentant les indicateurs cible. Aucune modification du code
  cœur. C'est le pattern FORMS-T (v0.28.0). Risque nul, rétrocompatible.
- **Niveau 2 — Loaders** : extension de `load_raster_source()` (et, si besoin,
  un résolveur d'asset STAC) pour que l'app puisse réellement matérialiser les
  rasters Theia. Touche `R/datasources.R` uniquement.
- **Niveau 3 — Câblage indicateurs** : ajout d'arguments optionnels aux
  fonctions `indicateur_*()` pour consommer ces nouvelles entrées. Conçu
  indicateur par indicateur, strictement rétrocompatible (argument `NULL` par
  défaut = comportement v0.28.x inchangé). Niveau à plus haut risque — chaque
  source y est traitée séparément, avec ses propres tests.

## Sources visées

| Clé FR.json | Produit Theia | Familles / indicateurs cible | Phase |
|---|---|---|---|
| `forms_t` | FORMS-T hauteur/volume/biomasse | C1, P1, P2, B2 | ✅ livré (v0.28.0) |
| `s2_biophysical` | Variables biophysiques S2 — LAI / FAPAR / FVC | C2, A1, B2 | 1a |
| `theia_soil` | Cartes de sol France — granulométrie + éléments grossiers | F1, F2 | 1a |
| `theia_snow` | Theia Snow collection (Let-it-snow / LIS) | R3, W | 1a |
| `theia_water` | Eaux de surface / Surfwater | W1, W2 | 1b |
| `theia_soil_moisture` | Humidité du sol (SMOS L3 / dérivés S1) | W3, R3, F1 | 1b |
| `s2_l2a_muscate` | Sentinel-2 L2A réflectance de surface (MUSCATE) | C2, T2, R5 | 1b |
| `theia_species` | Classification d'essences | B1, B2, intrants P/C | 1b |
| `theia_lst` | Thermocity — Land Surface Temperature | A2 | 1b |
| `formspot` | FORMSpoT — suivi forestier au niveau de l'arbre | C, P, T, R | 1b |

## Découpage

### Phase 1 — Catalogue (Niveau 1, déclaratif)

- **1a — sources prioritaires** ✅ : `s2_biophysical`, `theia_soil`,
  `theia_snow`. Entrées FR.json + tests. Release **v0.29.0**.
- **1b — sources complémentaires** ✅ : `theia_water`, `theia_soil_moisture`,
  `s2_l2a_muscate`, `theia_species`, `theia_lst`, `formspot`. Entrées FR.json +
  tests. Release **v0.30.0**. Phase 1 (catalogue) complète — 10 sources Theia
  déclarées.

### Phase 2 — Loaders (Niveau 2) ✅ — releases **v0.31.0** + **v0.36.0**

- `load_raster_source()` gagne un argument `path` : les sources Theia
  (`raster_local` sans URL statique) deviennent chargeables en passant le
  fichier téléchargé localement. Pas de nouveau `type` nécessaire (v0.31.0).
- Nouveau helper exporté `get_datasource_product()` : renvoie les
  métadonnées d'un sous-produit d'une source multi-produits (résolution,
  unité, plage, notes de conversion — ex. la note cm→m de `forms_t`) (v0.31.0).
- **Résolveur STAC Theia** (v0.36.0, `R/theia_stac.R`) : `stac_search_items()`
  (recherche STAC générique), `resolve_theia_assets()` (résolution des hrefs
  COG d'une source Theia pour une AOI) et `load_theia_source()` (chargement
  en `SpatRaster`). L'endpoint STAC Theia est lu dans `services.theia_stac`
  de FR.json — son `url` reste `"to confirm"` (host browser connu, racine de
  l'API STAC à confirmer).

### Phase 3 — Câblage indicateurs (Niveau 3, une sous-tâche par source)

- **3a** ✅ — `s2_biophysical` → C2 (argument `fapar` : vitalité FAPAR en
  remplacement du NDVI, même échelle 0-1), A1 (argument `fvc` : couverture
  arborée via FVC, `land_cover` passe en `NULL` par défaut). Release **v0.32.0**.
  Arguments optionnels, strictement rétrocompatibles.
- **3b** ✅ — `theia_soil` → F1 (nouveau `source = "theia_soil"` + argument
  `texture` : fertilité depuis la texture), F2 (argument `texture` : composante
  de résistance à l'érosion moyennée avec TWI + pente). Deux helpers exportés
  `texture_to_fertility_score()` / `texture_to_erosion_resistance()`
  (heuristiques calibrables). Release **v0.33.0**.
- **3c** ✅ — `theia_snow` → R3 (arguments `snow` + `snow_relief_strength` :
  le manteau neigeux atténue le stress de sécheresse, jusqu'à -30 % pour 6 mois
  d'enneigement). Release **v0.34.0**.
- **3d** ✅ — sources 1b. Release **v0.35.0**. Câblages retenus (sains) :
  `theia_water` → W2 (argument `water_occurrence` : 4ᵉ source de couverture
  zones humides) ; `theia_soil_moisture` → R3 (argument `soil_moisture` :
  atténuation du stress de sécheresse, même mécanique que `snow`) ;
  `theia_species` → nouveau helper `units_add_species_from_raster()` (remplit
  une colonne `species` pour P/C/B, en amont des indicateurs). **Reliquat
  documenté** : `s2_l2a_muscate` = donnée de base
  S2, son point d'intégration est le pipeline d'ingestion S2 existant, pas un
  argument d'indicateur → **cadré 2026-07-02 dans `specs/029-muscate-fast-source/`**
  (backend STAC Theia de repli souverain pour FAST/FORDEAD ; décisions voie
  d'accès + rôle actées, D1–D6 à confirmer avant impl, cible v0.111.0) ; `theia_lst` → A2 = inadéquation sémantique (A2 est
  un indice de qualité de l'air / pollution, pas de microclimat — câblage
  nécessiterait un sous-indicateur microclimat dédié) ; `theia_water` → W1 =
  W1 est une densité de réseau linéaire (m/ha), un masque raster ne s'y mappe
  pas. Ces 3 points pourront faire l'objet d'un chantier ultérieur.
  `formspot` a été sorti du reliquat en v0.35.2 : il se câble dans
  C1/P1/P2/B2 via l'argument `chm` existant (interface CHM partagée
  avec FORMS-T), sans code dédié.

## Réserves / dette à lever

- Pour chaque source, les métadonnées exactes (URL STAC, identifiant de
  collection, licence précise, CRS natif, résolution) sont à **vérifier
  source par source** : tant que ce n'est pas fait, les champs concernés
  portent un marqueur `"to confirm"` dans FR.json (même convention que
  `chm_opencanopy` et `forms_t`).
- Un éventuel **spec 011** pourra formaliser ce chantier si le câblage
  indicateurs (Phase 3) s'avère plus large que prévu.
- ~~**Moteur exposition (spec 027), 2 pistes cœur optionnelles**~~ **LEVÉES
  (v0.143.0, 2026-07-07)** :
  1. ~~Clip PAI nuage aux UGF~~ → `pai_depuis_nuage()` clippe la lecture lasR à
     l'emprise de travail (`-keep_xy`, COPC-efficient).
  2. ~~Back-off / regroupement ERA5~~ → `.rsen_forcage_era5()` : `by_month=FALSE`
     (1 requête/an) + retry/back-off `.rsen_era5_with_retry()`.

---

# Chantier précédent — Carte pixel (spec 010) livrée / cadrage E7

**État au 2026-05-15 (post-v0.22.1)** : 4 fonctions API publiques exposent le cache S2 pixel-par-pixel pour permettre la construction côté app d'une carte interactive NDVI/NBR avec time series au clic. Spec 010 close côté cœur. Patch **v0.22.1** ajoute un refresh proactif du SAS token PC avant chaque FETCH pour éliminer le 403/retry systématique observé sur les runs > 30 min. Implémentation côté `nemetonshiny` à venir (sous-onglet *Carte pixel* dans `mod_monitoring` — repo séparé).

## Épaississements app — Restore projet & affichage carte (pour mémoire, `nemetonshiny`)

> Hors-scope cœur (cf. *Scope* en tête) — releases app récentes touchant le
> chargement de projet et l'overlay carte, listées ici pour traçabilité.

- [x] Restore projet instantané : cache disque de la géométrie commune
      (app — nemetonshiny@6778e84, v0.74.0)
- [x] Déblocage CI nemetonshiny : lasR via Remotes + réparation tests
      pré-existants (app — nemetonshiny@8b10862, v0.74.1)
- [x] Notification sync PostGIS persistante jusqu'à l'overlay carte
      (app — nemetonshiny@32b1c8e, v0.75.0)
- [x] Backfill géométrie commune des projets legacy (lazy + migration)
      (app — nemetonshiny@e9b5e69, v0.75.1)
- [x] Chargement projet : build_index_stack hors du chemin critique
      (app — nemetonshiny@d9bc73f, v0.75.2)
- [x] Chargement projet récent : skip connexion DB monitoring
      (`.has_monitoring_zone_id()`) + `ug_build_sf()` différé via `later()`
      — garde-fous #1 + #3 (app — nemetonshiny@f9cd7b1, v0.78.0)
- [x] Chargement projet récent : `connect_timeout = 2L` sur la connexion
      monitoring — garde-fou #2, consomme cœur v0.76.0
      (app — nemetonshiny@d6149b5, v0.79.0)

---

# Chantier précédent — Durcissement ingestion S2 / cadrage E7

**État au 2026-05-15** : `nemeton`, dernière release **v0.21.12** (DESCRIPTION + NEWS.md alignés). Working tree propre. Pas de chantier d'épaississement actif. **Reliquat E6.b clos côté app** par `nemetonshiny@v0.27.0` (cf. journal 2026-05-15) : phases 2 (ingestion async + toasts, livrée rétroactivement), 3 (plotly NDVI/NBR per-plot via `read_obs_pixel()`), et 6 (smoke E2E shinytest2) cochées. Plus aucun reliquat E6 ouvert.

Série de patches **v0.21.1 → v0.21.12** livrée entre 2026-05-12 et 2026-05-15. Fil rouge dominant : *« faire rentrer une ingestion S2 longue sans casse »* — scènes silencieusement skippées, hoquets DNS / 5xx fatals, cache COG qui ne servait pas à grand-chose parce que la branche cache-hit plantait, sous-rép `<cache_dir>/{scene_id}/` créés mais vides parce que le retry protégeait la mauvaise étape du pipeline, et — pour clôturer la série — un `terra::writeRaster()` qui rejetait silencieusement chaque écriture parce que le driver GDAL ne pouvait pas être inféré depuis l'extension `.tmp` (bug v0.21.4 invisible jusqu'à v0.21.10 qui a nettoyé les dirs orphelins et démasqué l'erreur). La v0.21.11 ouvre un second fil : exposer en API publique le reader `obs_pixel` pour débloquer E6.b phase 3 côté app sans violer la règle « pas de SQL métier dans `nemetonshiny` » — clos côté app le même jour avec `nemetonshiny@v0.27.0`.

- **v0.21.1** (2026-05-12) — Migration DuckDB `0001_init.sql` corrigée. DuckDB rejette `GENERATED ALWAYS AS IDENTITY` et `ON DELETE CASCADE` en parsing → bascule sur `CREATE SEQUENCE` + `nextval()` et suppression des cascades. Smoke contre DuckDB 1.5.2 : 5 tables + auto-id + FK enforced + ré-exécution idempotente.
- **v0.21.2** — `run_fordead_dieback()` accepte `progress_callback = NULL`. Phases : `fordead:start` → `fordead:phase` / `fordead:phase_done` × {6 sans persistence, 7 avec `con` + `zone_id`} → `fordead:complete` / `fordead:error`. Exceptions du callback avalées (UI buggée n'aborte jamais FORDEAD). 4 nouveaux tests mockés.
- **v0.21.3** — `ingest_sentinel2_timeseries(..., skip_cached = TRUE)`. Pré-filtration *partial-coverage-aware* via `obs_pixel` — ajouter une bande à une zone existante ne déclenche pas de faux-positif. Events `s2:cache_lookup` / `s2:scene_cached`. Colonne `n_scenes_cached`. 4 nouveaux tests.
- **v0.21.4** — Cache COG sur disque (`cache_dir`). Écriture GeoTIFF tuilé DEFLATE sous `<cache_dir>/{scene_id}/{band}.tif`. Extent-aware (un fichier dont la bbox ne couvre plus les placettes est écrasé silencieusement). Events `s2:band_cached` / `s2:band_fetched`. Convention de chemin côté wiring app : `<project>/cache/layers/sentinel2/`. 7 nouveaux tests offline.
- **v0.21.5** — Retry STAC sur 429/5xx. Helper `.with_stac_retry()` (backoff exponentiel ≤ 60 s, jusqu'à 4 tentatives, override `NEMETON_STAC_MAX_TRIES`). Warning agrégé unique quand tous les backends sont épuisés (au lieu d'empiler un toast par backend). 5 nouveaux tests offline.
- **v0.21.6** — Lazy creation du sous-rép de scène (plus de dossiers fantômes après échec) + auto-refresh SAS PC sur 403/401 via `.terra_rast_with_pc_retry()` : cible la cause racine des ingestions > 30 min qui sortent du contrat token PC. Events `s2:band_fetch_failed`, `s2:pc_token_refreshed`. 10 nouveaux tests offline.
- **v0.21.7** — Observabilité du cache COG S2. Banner always-on `S2 band cache: enabled at <path>` / `DISABLED`. Tracer verbose gated par `NEMETON_S2_CACHE_DEBUG=TRUE|1` (ENTER, CACHE-HIT/MISS/STALE, FETCH, CROP, WRITE, RENAME, ERROR). Helper exporté `diagnose_s2_cache(cache_dir)` (n_scenes, n_populated, n_empty, total_bytes, bands_per_scene, empty_dirs). Warning explicite si `dir.create()` échoue (perms Windows, antivirus, network drive). 7 nouveaux tests.
- **v0.21.8** — **Fix critique** `.ext_contains()`. Le code v0.21.4 faisait `as.numeric(c(outer[1], …))` sur un `terra::SpatExtent` (S4) — plante avec *"cannot coerce type 'S4' to vector of type 'double'"* à chaque cache-hit, la scène était sautée. Helper privé `.ext_as_numeric()` ajouté (route `SpatExtent` via `terra::xmin/xmax/ymin/ymax`, fallback `as.numeric` pour numeric). 2 nouveaux tests de régression.
- **v0.21.9** — `.terra_rast_with_pc_retry()` retente aussi sur erreurs réseau transitoires (DNS `Could not resolve host`, `Connection timed out/refused/reset`, `Network unreachable`, `HTTP error 5xx`, `GDAL error … timeout`) avec backoff exponentiel plafonné à 30 s (2 s, 4 s, 8 s…). Budget par défaut 3 attempts, override `NEMETON_S2_MAX_TRIES`. Event `s2:band_fetch_retry` (payload `attempt`, `max_tries`, `retry_in_sec`, `error_message`). Corrige le symptôme « DNS de 5-30 s sur `*.blob.core.windows.net` qui skipait des scènes entières sans recovery ». 4 nouveaux tests.
- **v0.21.10** (2026-05-15) — **Fix structurel** : le retry était posé au mauvais étage. `terra::rast(href)` ne fait qu'un GET-range sur l'en-tête COG, `terra::crop` reste lazy, et la **vraie** lecture des pixels n'arrive que dans `terra::writeRaster()` — donc **après** la fenêtre du retry. Si le SAS PC expirait entre le head et le writeRaster, ou si Azure renvoyait un 5xx / 429 sur une range-request, le `tryCatch` autour de writeRaster avalait l'erreur, supprimait le `.tmp` et laissait un `<cache_dir>/{scene_id}/` orphelin. Fix : `.terra_rast_with_pc_retry()` accepte un closure `materialize = function(r0) { ... }` qui exécute crop + matérialisation (`r_cropped + 0` — idiome terra pour « force in-memory ») **à l'intérieur** de la boucle de retry. Toute défaillance VSI (auth, transient) ressort dans la même fenêtre que les défaillances d'en-tête → re-sign / backoff. `terra::writeRaster()` écrit ensuite depuis la RAM, plus aucun trafic VSI. Defense en profondeur : si writeRaster échoue quand même (disque plein, perms, GDAL local), le `scene_dir` orphelin est unlinké dans le `tryCatch` (les bandes sœurs déjà écrites sont préservées). 4 nouveaux tests.
- **v0.21.11** (2026-05-15) — Ajout de `read_obs_pixel(con, zone_id, plot_ids = NULL, bands = NULL, date_from = NULL, date_to = NULL)` exporté (R/read_obs_pixel.R) : reader public pour le hypertable `obs_pixel`, JOIN sur `plot` pour exposer le `plot.plot_id` humain (pas le FK INTEGER), filtres optionnels AND-combinés, sortie triée `(plot_id, obs_date, band)`, types coercés (`Date`, `numeric`), shape vide canonique sur zone inconnue. SQL injection prévenue via `DBI::dbQuoteLiteral()` sur les bornes/listes utilisateur. Débloque E6.b phase 3 côté `nemetonshiny` (plotly NDVI/NBR per-plot) sans violer la règle CLAUDE.md §1 (pas de SQL `obs_pixel` dans l'app). 13 nouveaux tests dans `test-read_obs_pixel.R` (6 offline validation + 4 intégration `with_clean_db` : empty zone, full read, filtres combinés, isolation zone-à-zone).
- **v0.21.12** (2026-05-15) — **Fix critique** `terra::writeRaster()`. Le fichier temporaire écrit pour le cache COG sortait avec l'extension `<scene_id>/B04.tif.tmp`. Recentes versions terra rejettent l'écriture avec `[writeRaster] cannot guess file type from filename` — le driver GDAL ne peut pas être inféré depuis `.tmp`. Conséquence : **depuis v0.21.4 le cache S2 n'a jamais réellement fonctionné** (chaque ingestion re-téléchargeait toutes les bandes via VSI, même avec `cache_dir` passé). Bug invisible parce que le `tryCatch` autour de `writeRaster` avalait l'erreur et émettait juste un `cli::cli_warn` ; encore plus invisible après v0.21.10 qui nettoyait le scene_dir orphelin — il ne restait que le warning. Démasqué pendant la validation in-prod de v0.21.10 (traces `[s2_cache …] WRITE ERROR: cannot guess file type` systématiques). Fix : ajout de `filetype = "GTiff"` explicite dans `terra::writeRaster()` (R/monitoring.R:872). Les options `gdal=` étaient déjà GeoTIFF-spécifiques, on rend le driver explicite. 1 nouveau test de régression `.get_s2_band_raster: writeRaster is called with filetype = 'GTiff'` qui capture l'appel via un mock délégué — robuste indépendamment de la version terra du runner.

**Avant la série v0.21.x** : la release **v0.21.0** (commit `e037df5`, 2026-05-12) a livré le backend DuckDB local comme alternative à PostgreSQL + TimescaleDB. Elle empaquette aussi les livrables E6.c/E6.d du cycle dev `0.20.1.9000..9004` (cf. *Chantier clos* ci-dessous) et le fix structurel `.pc_sign_url` du cycle dev `0.20.1.9008..9009`.

**Backlog identifié côté cœur** :

1. **E7 RAG perspectives IA** — spec 009 à rédiger. pgvector disponible dans la stack DB depuis 2026-05-05 (image `timescaledb-ha:pg16`).

---

# Chantier clos — Épaississement 6 : Suivi sanitaire (livré dans la release v0.21.0)

**Démarré**       : 2026-04-24 (initialement « monitoring continu »)
**Reframing**     : 2026-04-26 — chantier reciblé en **« suivi sanitaire »** après lecture du rapport ONF/DSF (Bernard & Doridant 2024). Spec 008 + ADR-013 rédigés. Voir `specs/008-suivi-sanitaire/`.
**Clôture cœur** : 2026-04-30 — E6.c.1/.2/.3/.4 + E6.d livrés (cycle dev `0.20.1.9000..9004`). Empaqueté dans la release **v0.21.0** (2026-05-12).

## Stratégie hybride (validée 2026-04-26)

Deux pipelines complémentaires alimentent la même table `alert` :

| Pipeline | Méthode | Question répondue | Coût | Cas d'usage |
|----------|---------|-------------------|------|-------------|
| **Surveillance rapide** | rolling-window NDVI/NBR (E6.a, déjà livré) | « Choc récent ? » | secondes | coupes, chablis, incendies |
| **Diagnostic sanitaire** | FORDEAD via reticulate (CRSWIR + harmonique, GPL-3) | « Mes peuplements dépérissent-ils ? » | minutes-heures | scolyte / sécheresse / dépérissement progressif |
| **Fusion** | join SQL (window ±30 j) | « Dépérissement ou perturbation mécanique ? » | ms | discrimination des causes |

## Garde-fous applicatifs (issus du rapport ONF/DSF 2024)

- **G1** — filtrage par défaut classes 3-forte + 4-sol-nu (les classes 1-2 ont 50 % / 1/3 de faux positifs)
- **G2** — fusion rolling-window × FORDEAD pour distinguer dépérissement / perturbation mécanique
- **G3** — bannières géographiques (`fordead_validity_zones.geojson` : 88, 39, 01, 73, 74) et essences (≥ 70 % épicéa + sapin)
- **G4** — workflow QField de validation terrain (réutilise E5.b, schéma DSF-aligné)
- **G5** — indicateur R5 pondéré par les taux de bonne détection observés terrain (`FORDEAD_CONFIDENCE_WEIGHTS` = 0.10 / 0.30 / 0.82 / 0.70)

## Découpage cœur

### E6.a — Squelette TimescaleDB + ingestion S2 + rolling-window — **livré v0.20.0 / v0.20.1**

Voir spec 007 (devient la couche « Surveillance rapide » de spec 008).

- [x] Phase 1-5 livrées dans le commit `28570d4` (release v0.20.0 du 2026-04-25)
- [x] Hardening v0.20.1 (commit `a7ea8d3`) : 2 bugs DB corrigés via tests d'intégration

### E6.c — Pipeline FORDEAD — **livré (cycle dev 0.20.1.9000..9004)**

Spec 008 §3, plan.md §2, tasks.md chantiers E6.c.1 à E6.c.4.

- [x] **E6.c.1** — `R/fordead_python.R` (helpers reticulate) + `R/fordead_pipeline.R` (orchestrateur `run_fordead_dieback`) + `inst/python/requirements.txt` + tests mockés (`test-fordead-python.R` 8 tests, `test-fordead-pipeline.R` 12 tests, 44 PASS) — branche `feat/008-fordead-pipeline` (2026-04-29)
- [x] **E6.c.2** — `R/fordead_postprocess.R` (constants + raster → POINT clusters via `terra::patches`, snap-to-plot INSERT, `classify_disturbance()` G2, `list_alerts()` G1) + migration `0002_fordead.sql` + branchement de `run_fordead_dieback` — branche `feat/008-fordead-postprocess` (2026-04-29). 45 nouveaux tests offline, 5 d'intégration TimescaleDB. Suite : 5745 PASS.
- [x] **E6.c.3** — `R/fordead_validity.R` (`load_fordead_validity_zones`, `check_fordead_validity`, constantes `FORDEAD_VALIDITY_DEPARTMENTS` / `FORDEAD_VALIDITY_SPECIES`) + `inst/extdata/fordead_validity_zones.geojson` (5 départements 88/39/01/73/74, ~ 27 500 km², 80 ko, simplifié 100 m, EPSG:4326) + script reproductible `data-raw/build_fordead_validity_zones.R` (source : `gregoiredavid/france-geojson` car `geo.api.gouv.fr/format=geojson` retourne désormais des attributs sans contour). 16 tests offline. Suite : **5866 PASS / 0 FAIL**.
- [x] **E6.c.4** — `R/health_validation.R` : `get_health_validation_schema()` (11 `.field()` DSF-aligned, ValueMap stades + causes, fallback `essence_dominante`), `generate_health_validation_plots()` (stratifié `confidence_class`, GRTS via `spsurvey` ou repli random, `.allocate_health_strata()` largest-remainder, NA typés, sortie `sf` POINT EPSG:2154 prête pour `create_qfield_project()`), `ingest_health_validation()` (snap par plus-proche-voisin Lambert-93, mapping `stade → (validation_status, validation_cause)` avec règle `coupe_rase × confidence_class` du rapport ONF/DSF, précédence `validated_by`). Constantes exportées `HEALTH_VALIDATION_STADES` (7 codes DSF), `HEALTH_VALIDATION_CAUSES` (7 causes). 31 tests : 10 schema, 11 generate, 10 ingest (intégration TimescaleDB via `with_clean_db`). Suite : **5957 PASS / 0 FAIL**.

### E6.d — Indicateur R5 dépérissement — **livré 2026-04-30**

Spec 008 §7.

- [x] `R/indicators-deperissement.R` : `indicateur_r5_deperissement(units, fordead_results, weights, min_resineux, include_low_classes, resineux_col)`. Sortie : colonnes `R5` (0-100) et `r5_status` (`calculated / skipped_no_resineux / skipped_no_fordead`).
- [x] Intégration radar : `INDICATOR_FAMILIES$R` étendu à 5 indicateurs (`R1..R5`) — `create_family_index()` détecte R5 via la regex `^R[0-9]` existante.
- [x] 18 tests : cas vide, mono-classe (50 % × 3-forte → R5 = 41), multi-classes, Quercus skipped, G1 (exclusion 1-faible / 2-moyenne par défaut), `include_low_classes = TRUE`, plafonnement, clusters hors UGF, `resineux_col` custom, `min_resineux`, `weights` custom, sf vide, erreurs typées, intégration radar.

### E7 — RAG perspectives IA — **machinerie livrée (v0.52.0), corpus en attente**

Spec `specs/009-rag-perspectives-ia/` **codée** (v0.52.0, 2026-05-29). La
*machinerie* RAG est livrée et testée (40 tests sur SQLite temporaire,
embedder mocké). Schéma opt-in `knowledge_document`/`knowledge_chunk`
(`enable_rag()`, hors séquence `db_migrate()` auto car pgvector exigé côté
PG), dual-backend (pgvector `<=>` sur PostgreSQL, cosinus R sur SQLite),
providers Mistral/OpenAI/Voyage.

**Reliquat avant clôture E7** :
1. **Corpus** — spec fille `specs/009.1-corpus-connaissances-forestieres/`
   (décisions D1-D5 actées le 2026-05-29) : manifest CSV + pipeline
   `data-raw/build_knowledge_corpus.R` + curation/licences (l'utilisateur
   tranche le juridique source par source).
2. **Wiring `nemetonshiny`** — injection des chunks dans le prompt LLM +
   bloc UI « Sources » (hors repo cœur).

---

## Documents de référence du chantier

- `specs/008-suivi-sanitaire/spec.md` — Spec fonctionnelle (vision, scope, garde-fous, R5, validation)
- `specs/008-suivi-sanitaire/plan.md` — Plan technique (stack, pipeline, fusion, performance, risques)
- `specs/008-suivi-sanitaire/tasks.md` — 71 tâches détaillées (53 cœur + 18 app)
- `specs/008-suivi-sanitaire/ADR-013-suivi-sanitaire-fordead.md` — ADR draft (à porter dans `platform_nemeton/docs/`)
- Spec 007 (`specs/007-monitoring-continu/`) — devient la couche « Surveillance rapide » de spec 008, conservée en référence
- Rapport ONF/DSF Bernard & Doridant 2024 — référence de calibration et de limites

---

## Décisions validées 2026-04-26 (fordead)

1. **Reframing** E6 « monitoring continu » → « **suivi sanitaire** »
2. **Stratégie hybride** : rolling-window (rapide) + FORDEAD (diagnostic) ; pas de throwaway de v0.20.0
3. **Cinq garde-fous** G1-G5 obligatoires (filtrage classes / fusion / bannières / validation QField / R5 pondéré)
4. **Workflow validation QField** intégré dans le même chantier E6.c (pas de release séparée)
5. **Zones de validité géographique** construites depuis IGN ADMIN-EXPRESS via geo.api.gouv.fr (5 départements : 88 Vosges, 39 Jura, 01 Ain, 73 Savoie, 74 Haute-Savoie)
6. **Calibration figée** v0.21.0 sur les paramètres ONF/DSF (CRSWIR, 0.16, 2 ans entraînement, 3 anomalies consécutives) — pas exposée à l'utilisateur final
7. **Paperwork avant code** : spec 008 + ADR-013 publiés avant E6.c

## Décisions validées E6.a (2026-04-24)

1. STAC : **CDSE prioritaire + PC fallback**
2. Bandes rapides : **NDVI + NBR** (B04, B08, B12)
3. Déploiement : **docker-compose service TimescaleDB**
4. Déclenchement : **à la demande** (pas de cron en E6.a / E6.c)
5. Granularité rapide : **par placette** (buffer 15 m)

---

## Journal

### 2026-08-14 — App `nemetonshiny` : trois livraisons (v0.122.14, v0.123.0, v0.124.0)

Consigné d'après `specs/BRIEF-nemeton-plan-md-0.122-0.124.md`, émis par la
session app — qui ne peut ni lire ni écrire ce fichier (règle 12 de son
`CLAUDE.md`), d'où un brief qui livre le texte et laisse à la session cœur le
placement. SHA et tags **vérifiés** ici en lecture seule : les trois tags
existent, les trois commits sont sur `main` côté app.

| Release app | `nemetonshiny@SHA` | Cycle dev repris | Apport |
|---|---|---|---|
| v0.122.14 | `3bc827dc` | `0.122.14.9000` | Lot de fiabilisation (0.122.5 → 0.122.14) |
| v0.123.0 | `6711b05d` | `0.123.0.9000` | Profil en travers d'un tronçon au clic |
| v0.124.0 | `ccbeb3e7` | `0.124.0.9000` | Sorties de l'onglet Desserte rendues visibles |

**Aucun impact cœur** : les trois sont portées par l'app, aucune ne demande de
release `nemeton`, et l'ordre cœur → app est respecté (l'app consomme
`foretaccess 2.3.0`, déjà taguée, via `Remotes: @*release`).

#### v0.123.0 — Profil en travers au clic (spec 030, `foretaccess`)

Dans l'onglet Accessibilité, couche « Desserte BD TOPO / corrigée », un clic
affiche la coupe transversale du tronçon le plus proche : nuage LiDAR de la
tranche, profil du terrain, chaussée ajustée, et les cinq familles de bords
cotées (chaussée roulable, plateforme, bande de secours, emprise, accotements).
Le calcul appartient au cœur — `foretaccess::profil_travers()`, spec 030,
release 2.3.0, écrite d'après le brief `BRIEF-profil-travers-desserte.md` émis
par l'app. Côté app : résolution des chemins projet, conversion du clic WGS84
vers le CRS de travail, appel, et tracé (`acc_profil_travers()` +
`fct_plot_desserte_profil.R`, présentation pure). Clic asynchrone malgré un coût
cœur mesuré à 0,4 s : ce chiffre vaut sur une dalle d'exemple, la première
lecture d'un catalogue LAZ réel est plus lourde, et la boucle Shiny est
mono-thread.

**Réserve, à ne pas cocher comme validé terrain** : la chaîne clic → coupe n'a
**jamais été exercée de bout en bout sur un projet réel** portant à la fois un
nuage LiDAR et une desserte corrigée. Les 30 tests couvrent la résolution des
chemins, la traduction des échecs en raisons lisibles et la planche ; pas la
géométrie, qui est testée côté `foretaccess`.

#### v0.124.0 — Sorties Desserte rendues visibles (specs 026 et 028)

Mise en vue, pas évolution du calcul. Cinq actions de la sidebar produisaient
toutes un résultat sur disque ; deux seulement étaient visibles sur la carte. Le
complément OSM (spec 028) et la détection de routes (spec 026) — les deux
traitements les plus coûteux de l'onglet, plusieurs minutes et jusqu'à 8 Go pour
le second — n'affichaient qu'un compteur : pour voir sa propre géométrie il
fallait connaître le chemin du cache et ouvrir QGIS.

Livré : calques « Pistes OSM » et « Routes détectées » (tiretés, éteints au
départ, déclarés dans le contrôle de couches) ; popup portant `CLASSE_CONF`,
`CLASSE_MOTIF` et `OSM_TAGS` à côté de `CLASSE`, le balisage OSM étant présenté
comme une proposition et jamais un téléversement ; `.load_cached_typage()` +
sidecar `typage.rds` (le typage était le seul des cinq à ne pas survivre au
rechargement du projet) ; `run_desserte_osm()` renvoie et persiste `gpkg_path` ;
l'export GeoPackage fusionne réseau typé, pistes OSM et routes détectées, en
retenant le typage du moteur courant ; chemin du cache affiché. Aucune logique
métier ajoutée côté app (règle 1).

Ce chantier a été instruit des deux côtés le même jour : le versant cœur est
journalisé plus haut sous *« Brief émis — Onglet Desserte : rendre visibles les
sorties »*, qui décrit le même constat depuis ce dépôt.

**Sous-chantier non clos côté chaîne** — voir la section dédiée : le calque OSM
affiche pour l'instant l'acquisition **brute**, doublons BD TOPO compris, parce
que `foretaccess::comparer_desserte_osm()` ne rendait aucune géométrie. Son
libellé et son popup le disent explicitement. Correctif livré depuis (§ ci-dessous).

#### v0.122.14 — Fiabilisation (lot 0.122.5 → 0.122.14)

Dix releases patch en une journée, sans nouvelle fonctionnalité métier : un lot
de fiabilisation, pas un épaississement. `R CMD check` repasse sans aucun
avertissement ni note — sources entièrement désaccentuées, tests ne lisant plus
`R/` sans garde (sous `.Rcheck` le paquet installé n'a pas de sources),
dépendances de `Suggests` corrigées après un échec d'installation `pak` en CI
que le check local ne voyait pas. Les notes de release sont désormais extraites
de `NEWS.md` par `release.yml`, et un test interdit qu'un titre de version y
disparaisse — ce défaut avait atteint le tag publié v0.122.7. Trois smoke E2E
rendus hermétiques et le démarrage réessayé.

Côté UX : menu des couches piloté intégralement (un groupe peint mais non
déclaré n'a pas de case — défaut du relief), légende BD TOPO re-contrastée par
mesure ΔE, infobulles à 17 px, sidebars rétractables uniformisées, « i »
d'information unifiés sur un seul motif (`info_popover()`), code de famille
affiché dans le menu des indicateurs.

**La leçon du lot, qui vaut au-delà de lui** : *un signal vert dans
l'environnement le plus favorable ne prouve rien.* `devtools::test()` masquait
l'échec de `R CMD check` ; le check local masquait l'échec d'installation en CI.
Chaque garde-fou de ce lot vient d'un défaut qui avait franchi l'étape
précédente.

#### Revue du §4 du brief — items signalés « peut-être non consignés »

Confrontés au fichier réel, quatre des six y figuraient déjà ; deux ne l'étaient
qu'à moitié, et ont été complétés là où ils vivent plutôt qu'ici :

| Item du §4 | Verdict |
|---|---|
| spec 035 / 027 — moteur et UX reGénération (app v0.101.x) | déjà consigné |
| R7 gel tardif + meteoland (app v0.104.0, cœur v0.151.0) | déjà consigné, les deux versants nommés |
| Contexte E-OBS downscalé (app v0.105.0, cœur v0.152.0) | déjà consigné |
| Bascule ALSroads → dessertR (`foretaccess`) | déjà consigné |
| Mémoire des workers `future`, spec 008 (app v0.106.5) | versant cœur consigné (v0.158.0), **référence app ajoutée** |
| FORDEAD en processus plafonné (app v0.106.6, cœur ≥ v0.157.0) | versant cœur consigné (v0.157.0), **référence app ajoutée** |

Le complément est posé dans l'entrée du 2026-07-15 qui porte déjà le lot
v0.106.x, pas ici : c'est là que le lecteur le cherchera.

### 2026-08-13 — Unification OSM/Overpass : le versant cœur (§5.4) + spec 044 ouverte

Versant **cœur** du brief `specs/BRIEF-osm-overpass-unification.md`. Le gros du
lot ne vit pas ici : le transport canonique est livré **dans `foretaccess`**
(`osm_overpass()` exporté, décision D1 actée en **ADR-010** *avant* le code comme
le brief l'exigeait ; `foretaccess@3c7b386` + `c437269`), et les deux
consommateurs restants ont leurs briefs de hand-off côté `foretaccess/docs/`
(`brief-dessertR-transport-overpass.md`, `brief-nemetonshiny-overpass.md`).
Je n'édite aucun repo frère (règle 11).

**§5.4 — périmètre cœur, livré.** Vérification faite avant d'écrire : **aucun
code `R/` de `nemeton` n'appelle OSM**, `osmdata` est en `Suggests` (ligne 59) et
n'est utilisé que par les tutoriels. Le brief annonçait deux fichiers et deux
chunks ; le repo en compte **trois chunks pour quatre sites d'appel** —
`03-terrain.Rmd` (`ex-5-3`, sentiers S3), `04-ecological.Rmd` (`ex-4-1`, landuse
en repli d'OCS-GE ; `ex-5-1`, bâti **et** zones urbaines). Chacun porte désormais
une note : l'appel `osmdata` direct est **pédagogique**, le chemin de production
est le client canonique de `foretaccess`. La note d'`ex-4-1` ajoute le *pourquoi*
du regroupement de filtres (Overpass limite les requêtes, pas la surface), celle
d'`ex-5-1` renvoie à `acquire_obstacles()` — vérifié en lecture seule : il fait
bien **une seule** requête avec union de filtres puis dispatch local depuis
`3c7b386`. Les tutoriels ne sont **pas** réécrits (interdit par le §5.4) ; les
deux `purl()` + `parse()` passent (221 et 400 expressions).

**§6 — spec 044 ouverte, non implémentée** :
`specs/044-osm-extraits-pbf/spec.md`. Le brief range les extraits Geofabrik
`.pbf` hors périmètre et laisse la décision à Pascal ; la spec cadre cinq
décisions dont **D1 conditionne tout : aucun consommateur batch n'existe
aujourd'hui** (l'app est interactive, les indicateurs cœur ne consomment pas
OSM), donc le résultat attendu par défaut est qu'elle reste ouverte. Deux faits
vérifiés y sont consignés pour D3 : `osmextract` n'est **pas** installé, le
**driver OSM de GDAL est présent** via `sf` — un chemin `.pbf` par GDAL
n'ajouterait aucune dépendance.

**Aucune case cochée**, aucun bump : modification de commentaires de tutoriels et
ouverture d'une spec, rien de fonctionnel.

### 2026-08-13 — App `nemetonshiny` v0.122.0 : desserte corrigée, l'invariant BD TOPO rétabli + complément OSM

Livraison **100 % app**, **aucun impact cœur** : pas de nouvelle API `nemeton`
consommée, plancher `Imports: nemeton (>= 0.169.0)` inchangé (`foretaccess`
consommé en **2.1.0**, plancher déclaré inchangé à `>= 2.0.1` ; `dessertR
1.3.0.9000`). Correctif de régression sur une fonctionnalité déjà livrée.
*(Traçabilité remontée par la session app — je n'édite pas `nemetonshiny`,
seulement ce journal. Brief : `nemetonshiny/BRIEF-nemeton-plan-v0.122.0.md`.)*

- 2026-08-13 — nemetonshiny v0.122.0 (merge `nemetonshiny@b1a7d41a`, branche
  `claude/desserte-invariant-bdtopo` ; `c4265a9b` = `chore(release): v0.122.0` ;
  cycle dev repris en `0.122.0.9000`). L'app passait
  `retirer_disparues = TRUE` à `foretaccess::qualifier_desserte()` — un opt-in
  que le cœur laisse à `FALSE`. La correction LiDAR **supprimait donc des
  tronçons déclarés** : **280 sur 373** sur ForêtAccess (84 % du linéaire, **une
  `route` sur deux**), **322 sur 1 032** sur Dabo. Cette couche amputée
  remplaçait la BD TOPO en entrée de `preprocess()`, donc de **tous les
  moteurs**, dès que « utiliser la desserte corrigée » était cochée : les
  surfaces hors desserte étaient surestimées d'autant.
- **Cause : erreur d'interprétation côté app.** `dsr_etat()` définit `hors_route`
  comme « les **deux** conductivités faibles », c'est-à-dire *aucun signal* — et
  avertit que l'état « n'est réellement interprétable que le long d'un tracé
  retenu par le pathfinder ». Une plateforme routière laisse une empreinte dans
  le terrain pendant des décennies : l'absence de signal désigne un échec de
  mesure bien plus souvent qu'une route effacée. L'app en avait fait un verdict
  d'existence.
- **Règle posée, non contournable** : la desserte corrigée conserve
  l'intégralité de la BD TOPO, s'enrichit d'OSM, qualifie l'ensemble et rend le
  tout. La qualification **renseigne** (état, largeur, géométrie recalée) ; elle
  ne **décide** pas de l'existence. Un garde-fou refuse la correction si la
  sortie compte moins de tronçons que l'entrée.
- Complément OSM (`.desserte_complement_osm()`) conforme au contrat du cœur
  (« source *complémentaire* de la BD TOPO, jamais substitutive ») : seule la
  portion hors d'un corridor de 15 m est ajoutée, à partir de 30 m.
  Best-effort — Overpass bridé rend la BD TOPO intacte, et l'UI le dit.
- **Validé bout-en-bout sur ForêtAccess** : 373/373 tronçons BD TOPO conservés,
  répartition par classe **identique** à l'entrée (44 `hors_desserte`,
  254 `piste`, 7 `reseau_public`, 68 `route`), + 28 tronçons OSM (3,61 km, plus
  court 33,8 m). 25,9 min, pic 6,3 Go. Suite app : 0 échec, 10 774 tests.
- Les états mesurés sur les 401 tronçons disent pourquoi le retrait était faux :
  **213 `abandonnee` + 95 `hors_route`**, soit 77 % du réseau, sur une emprise
  portant 68 `route` de la BD TOPO. **Ces états ne sont pas un inventaire.**

**Dette laissée ouverte (app, hors périmètre de ce correctif)** : la détection de
tronçons non déclarés **rend toujours 0** — mesuré le 2026-08-13 sur Reconfort
(554 ha, 7/7 canaux retenus, AUC rugosité 0,763) en sept configurations (bornes
figées, calibration locale, seuils 0,3 à 0,6, `buffer_ref = 0`, avec canal de
surface : 4 018 s, 8,75 Go), donc la troisième couleur de légende du comparateur
(« ajouté par détection ») reste sans emploi et la prémisse de
`design/spec-desserte-reliquats.md` §2 est **réfutée**, à réécrire ; les tronçons
OSM entrent avec `largeur = NA` ; le garde-fou mémoire de la détection modélise
la mauvaise grille (1,96 Go annoncés pour 8,75 Go mesurés).

**Aucune case cochée** : ni sous-chantier ni épaississement n'est clos par cette
release — c'est un correctif de régression sur une fonctionnalité déjà livrée.

### 2026-08-07 — v0.169.0 : R3, la grille du TWI suit le terrain + plafond mémoire absolu

Suite directe de l'entrée du 2026-08-06 : le lendemain, **R3 est mort au même
endroit**, `progress_state.json` bloqué sur `compute:indicateur_r3_secheresse`
(21/35 indicateurs), scope RStudio + Brave + ghostty tués par `systemd-oomd`.
Hand-off côté app : `nemetonshiny/BRIEF-nemeton-r3-topo-resolution.md`, mesures
sur le MNT réel de Dabo (`20260801_130303_xpdk`, 12000 × 10000 @ 0,5 m).

**Ce que le garde-fou du 06 ne couvrait pas.** Il bornait la grille du terrain,
mais R3 laissait `get_or_compute_twi()` à `twi_target_res = 10`. Le TWI sortait
donc sur une grille différente de celle d'`aspect`, `compareGeom()` échouait, et
la branche de secours **rééchantillonnait le TWI grossier vers la grille fine** —
un `resample` sans information ajoutée qui multiplie le coût de la suite. Le
brief mesure ce seul désalignement (à 5 m) : **1,36 pt** d'écart de score contre
**0,50 pt** grilles alignées, facteur 2,7 d'erreur gratuite.

**Fix** — trois volets, indissociables :

1. **Propagation** : `dem_target_res` → `get_or_compute_twi(twi_target_res =)`
   sur les quatre consommateurs du TWI (W2, W3, F2, R3) et →
   `calculate_twi_terra()` sur le chemin `method = "d8"` de W3. Les grilles
   coïncident, le `resample` n'est plus emprunté (gardé en filet pour un TWI
   GRASS ou un cache antérieur). Clé du cache TWI indexée sur la résolution
   **effective** et non la cible demandée : sur un BD ALTI 25 m, 2 m et 10 m
   donnent le même TWI et partagent l'entrée.
2. **Résolution 10 m → 2 m**, exposée comme réglage paquet
   (`options(nemeton.topo_target_res = )` / `NEMETON_TOPO_TARGET_RES`, défaut
   `.topo_target_res()` dans les huit signatures) pour que l'app ajuste sans
   release du cœur.
3. **`memmax = 3` (Go) dans `.onLoad`**, plafond *absolu* en plus de `memfrac`.

**Arbitrage sur la résolution.** Le brief retenait 1 m ; il a été écrit contre
la 0.168.1 et ignorait le garde-fou 10 m de la veille. Passer de 10 m à 1 m
aurait *dégradé* la marge mémoire par rapport à l'état du cœur. Retenu : **2 m**
(décision Pascal, 2026-08-07), que le brief lui-même dit défendable (§3
réserve b). Écart au score R3 contre une référence 0,5 m, grille TWI alignée à
chaque résolution :

| résolution | Dabo | ForetAccess | temps R3 (Dabo) | spill terra |
|---|---|---|---|---|
| 0,5 m (réf.) | — | — | 265 s | — |
| 1 m | 0,81 | 0,64 | 33 s | 329 Mo |
| **2 m (retenu)** | **1,40** | **1,12** | **10 s** | **0 Mo** |
| 5 m | 2,33 | 2,10 | 3,5 s | 0 Mo |

La dégradation est monotone, mais « plus proche du 0,5 m » n'est pas « plus
juste » : en forêt, le pas fin capte les cloisonnements, les chablis et les
fossés — de la micro-topographie qui n'est pas l'exposition du peuplement à la
sécheresse. Le 2 m reste sous 1,5 pt **et** tient entièrement en RAM, là où le
1 m fait spiller terra.

**Pourquoi `memmax` et pas `memfrac` seul.** Une fraction n'est pas un plafond :
0,25 vaut 7,8 Go ici, 2 Go sur un portable à 8 Go, 32 Go sur un serveur — et elle
ignore ce que la machine peut réellement céder. `memmax` est absolu (identique
partout) et adaptatif (spill seulement au-delà du plafond), donc **gratuit** au
point de fonctionnement normal, là où `todisk = TRUE` coûte 3,4× le temps et
142 Mo d'écritures pour 0,01 Go économisé. Réserve notée dans le code : sur une
machine où `/tmp` est un tmpfs, le spill écrit en RAM et ne protège de rien.

Divers : `aspect_risk` de R3 passe par `terra::app()` en une passe — l'expression
`(1 + cos((aspect - 180) * pi/180)) / 2` matérialisait quatre `SpatRaster`
temporaires pleine taille, d'où le saut de pic mesuré (2,44 → 8,70 Go à 0,5 m).
Résultat numériquement identique, NA compris.

**Impact à annoncer** : scores des projets à MNT LiDAR décalés de l'ordre du
point /100, et **caches TWI existants orphelins** (recalcul unique par projet).

Tests : `test-dem-working-res.R` (réglage paquet, résolution effective,
alignement des grilles avec un `terra::resample` mocké qui `stop()`, cache TWI
partagé W3/R3) et `test-terra-memory.R` (défaut, option, variable
d'environnement, opt-out, réglage illisible).

**Aucune case cochée** : correctif de robustesse. Côté app, le brief annonce un
plafond symétrique à la promotion du MNT dans le slot `dem` — les deux couches
sont complémentaires (le plafond app protège les cœurs déjà déployés, le plafond
cœur protège aussi les usages hors app).

### 2026-08-06 — v0.168.2 (non publiée, fondue dans v0.169.0) : MNT LiDAR HD, résolution de travail bornée (OOM sur Dabo)

**Symptôme** : sur le projet Dabo, RStudio se fermait en cours de calcul des
indicateurs, sans message. Ce n'était pas un plantage R — `systemd-oomd` tuait
le *scope* RStudio entier :

```
17:39:47  app-rstudio-7052.scope   Current Memory Usage: 21.2G
17:40:22  Killed … due to memory pressure for user@1000.service
          being 73.29% > 50.00% for > 20s   → result 'oom-kill'
```

**Localisation** : `data/compute_progress.json` s'arrête à `indicateur_r1_feu`
(17:37:04), soit trois minutes avant le kill. L'indicateur suivant dans l'ordre
du pipeline app est **R2 tempête**.

**Cause** : Dabo est en NDP 1 avec `chm_source: lidar_hd`, donc
`get_dem_raster()` (`R/utils.R:531`) préfère le MNT LiDAR HD au BD ALTI 25 m —
ici `lidar_mnt_mosaic.tif`, **12000 × 10000 = 120 M cellules à 0,5 m**. R2
(branche fallback terrain, `microclima` absent) enchaîne neuf rasters plein
format : aspect, pente, TRI, l'écart angulaire, son min, `expo_vent`,
`pente_norm`, `tri_norm`, `r2_raster`. Le `memfrac = 0.25` de `R/zzz.R` borne le
cache terra, pas les intermédiaires R ni la somme des workers `future`.

**Fix cœur** : `.dem_working_res(dem, target_res, context)` ramène le MNT à ~10 m
avant tout calcul dérivé du terrain. Jamais d'upsampling, no-op en lon/lat,
désactivable par `dem_target_res = NULL`. Argument `dem_target_res = 10` ajouté
aux huit indicateurs concernés : R1, R2, R3, W2, W3, F2, S1, S2.
`.twi_aggregate_dem()` (précédent de W3, déjà à 10 m) en devient un alias.

Point d'attention retenu : le cache TWI est indexé sur l'empreinte du MNT reçu,
donc **W2/W3/F2/R3 doivent partager la même valeur** — sinon un TWI est
recalculé par indicateur. C'est la raison pour laquelle le garde-fou a été posé
sur les quatre d'un coup et non sur R2 seul. Pour S1/S2 le MNT n'est qu'une
grille (rasterisation + `terra::distance()`), l'agrégation y est neutre au sens.

**Mesure sur le MNT réel de Dabo** (4 UG, scope `MemoryMax=6G`) :

| `dem_target_res` | Résultat |
|---|---|
| `10` (défaut) | R2 en **2,8 s**, pic RSS **958 Mo** |
| `NULL` (natif 0,5 m) | **tué par l'OOM killer** |

Tests : `tests/testthat/test-dem-working-res.R` (37 PASS) — agrégation, absence
d'upsampling, no-op sous facteur 2, lon/lat, opt-out, passthrough non-raster,
message conditionné au `context`, alias TWI, signatures des huit indicateurs,
et un R2 de bout en bout sur MNT fin. Les 2 échecs `get_nasapower_wind` observés
en enchaînant plusieurs fichiers de test dans une même session R sont
**antérieurs** (reproduits à l'identique sans le patch, `git stash` à l'appui).

**Aucune case cochée** : correctif de robustesse, pas de sous-chantier clos.
Reste à faire côté app (brief à écrire) : lancer les calculs lourds dans un
cgroup plafonné pour que l'OOM killer tue le job et non la session — cf. l'entrée
RECONFORT du même sujet.

### 2026-08-06 — App `nemetonshiny` v0.120.4 : doublon `cache/layers/layers/mnt/` corrigé

Livraison **100 % app**, **aucun impact cœur** : pas de nouvelle API `nemeton`
consommée, plancher `Imports: nemeton (>= …)` inchangé. Bug de chemin de cache
au pré-calcul CVAT. *(Traçabilité remontée par la session app — je n'édite pas
`nemetonshiny`, seulement ce journal.)*

- 2026-08-06 — nemetonshiny v0.120.4 (`nemetonshiny@0351e67f` ; cycle dev
  `0.120.3.9001`). Correction du doublon `cache/layers/layers/mnt/` créé au
  pré-calcul CVAT : `foretaccess` ajoute lui-même un segment
  `layers/<couche>/` sous le `cache_dir` qu'il reçoit, alors que l'app lui
  passait déjà `<projet>/cache/layers`.
- Nouveau helper app `.foretaccess_cache_root()` : la racine `<projet>/cache`
  est transmise quand le fichier est dans `cache/layers`, si bien que le MNT
  ré-acquis se range désormais en `cache/layers/mnt/`.
- Côté cœur, rien à faire : aucune fonction de `nemeton` n'appelle
  `foretaccess` avec un `cache_dir` (seul `R/volume_mobilisable.R` évoque
  `foretaccess`, et uniquement pour la convention de `volume_champ`).

**Aucune case cochée** : ni sous-chantier ni épaississement n'est clos par cette
release — c'est un correctif de chemin de cache.

### 2026-07-29 — App `nemetonshiny` v0.120.3 : zone tampon Accessibilité en mètres

Livraison **100 % app**, **aucun impact cœur** : pas de nouvelle API `nemeton`
consommée, plancher `Imports: nemeton (>= …)` inchangé, `Remotes:` toujours en
`@*release`. Ajustement d'unité et de défaut sur une entrée de formulaire.
*(Traçabilité remontée par la session app — je n'édite pas `nemetonshiny`,
seulement ce journal.)*

- 2026-07-29 — nemetonshiny v0.120.3 (merge `nemetonshiny@79c22d33`, branche
  `claude/acc-buffer-metres` en no-ff ; cycle dev repris en `0.120.3.9000`,
  `nemetonshiny@bc180d71`). Champ « Zone tampon autour de la forêt » de
  **Terrain › Accessibilité** passé du km au **mètre** (pas 50 m, max 20 000 m),
  **défaut 250 m** au lieu de 1 km. Input `buffer_km` → `buffer_m` : la
  conversion `* 1000` disparaît des trois appels du module (pré-calcul CVAT,
  correction LiDAR desserte, lancement de l'analyse) ; les services app
  (`run_accessibility()`, `run_desserte_lidar_correction()`, `.acc_rvt_cvat()`)
  prenaient déjà des mètres et sont inchangés.
- Bug de robustesse corrigé au passage : un `numericInput` vidé renvoie `NA` (et
  non `NULL`), que `%||%` laissait donc passer — le `NA` empoisonnait la clé de
  sous-cache `emprise_%gm` et la géométrie tamponnée. Nouveau helper privé app
  `.acc_buffer_m()` : garde `is.finite()` → retour au défaut, bornage à 0 si
  négatif. 35 PASS / 0 FAIL.
- Les onglets **Desserte** et **reGénération** gardent volontairement leurs
  champs en km.

**Aucune case cochée** : ni sous-chantier ni épaississement n'est clos par cette
release — c'est un ajustement d'unité et de défaut d'IHM.

### 2026-07-25 — App `nemetonshiny` : chaîne desserte durcie + comparateur RVT (spec 040)

Versant APP des releases desserte du jour (le versant cœur est journalisé dans
les deux entrées v0.168.0/0.168.1 ci-dessous). Huit releases app consommant le
cœur desserte (spec 040) + corrigeant l'OOM de la correction LiDAR et le cubage
P1. Toutes sur `main`, tag + release GitHub. *(Traçabilité remontée par la
session app — je n'édite pas `nemetonshiny`, seulement ce journal.)*

| Release app | `nemetonshiny@SHA` | Apport |
|---|---|---|
| v0.115.12 | `f030fea0` | Fix OOM correction LiDAR (`qualifier_desserte` : MNT fourni à 1 m → `.mnt_alsroads` ne lit plus les 165 M points). Pool `future` borné (19 sites). `run_app(tour=)`. Fix faux « Volume P1 absent » (`P1` vs `indicateur_p1_volume`). |
| v0.115.13 | `ae68fd00` | Cache de mesure `qualifier_desserte` persistant (relance rapide). |
| v0.116.0  | `1d7ab8f2` | Comparateur swipe desserte BD TOPO vs corrigée sur fond relief RVT. |
| v0.116.1  | `6a7bcd9a` | Plancher `Imports: nemeton (>= 0.168.0)` — garde-fou `p1_max_plausible`. |
| v0.116.2  | `1d7ffc9e` | Plancher `nemeton (>= 0.168.1)` — fix cubage P1/C1/E1 (validé app : P1 1556 → 372 m³/ha). |
| v0.117.0  | `15f23d73` | Fond relief CVAT via `foretaccess::vat_combined()` (foretaccess 1.24.0). |
| v0.117.1  | `ac3e307a` | Fond RVT sur le MNT LiDAR HD 0,5 m natif (`lidar_mnt_mosaic.tif`) — sans striping. |
| v0.117.2  | `ca7aa0ce` | Correction LiDAR recalée sur le MNT LiDAR 0,5 m natif (cohérence tracé/fond) + fond RVT asynchrone. |

Cycle dev app courant : `0.117.2.9000` (`nemetonshiny@408f56bb`).

**Diagnostic remonté au cœur depuis l'app (2 briefs, résolus côté cœur) :**
- unité `indicateur_p1_volume` (→ `reponse-p1-unite-desserte.md`, v0.168.0) ;
- cubage P1 ×3-5 (→ `reponse-p1-cubage-gonfle.md`, **v0.168.1** : coefficients
  `b`/`c` du tarif IFN incohérents avec `a`, corrigés en `V = a·D²·H`). Validé
  depuis l'app par reproduction du flux compute : dbh 29 cm / N 466 tiges/ha /
  hdom 25 m plausibles, volume ×4 → 372 m³/ha après fix.

**Recette de bout en bout (ForêtAccess, dépt 48) :** correction LiDAR sur MNT
0,5 m, 2662 tronçons / 1842 mesurés, largeur médiane 5,3 m ; recalage et fond
CVAT sur le même MNT LiDAR — cohérence visuelle confirmée.

### 2026-07-25 — v0.168.1 : **cubage P1/C1 gonflé ×3-5 corrigé** (spec 040)

**Suite du garde-fou v0.168.0.** La session app a rejoué le flux compute complet
(brief `~/brief-nemeton-p1-cubage-gonfle.md`) et **infirmé la piste « inputs »** :
CHM, D_g (~29 cm), densité (~466/ha) tous plausibles, mais P1 ×3-5. Signature
décisive fournie par l'app : V/arbre absurde **croissant avec le dbh** (2,2× à
19 cm → 5,6× à 36 cm).

**Cause racine trouvée.** `inst/extdata/ifn_volume_equations.csv` : colonnes `b`
(~2,5) et `c` (~0,97) **incohérentes avec `a`**, qui est un facteur de forme
calibré pour la forme à variable combinée `V = a·D²·H` (preuve :
`a/(π/4/10⁴) = 0,50`, facteur de forme classique). Le `b` en trop de ~0,5 gonfle
en `D^0,5` — d'où l'erreur croissante avec le diamètre. Fix : `b→2.0`, `c→1.0`
sur les 25 lignes, `a` inchangé. Le cubage reproduit le contrôle terrain
`g·h·0,5` à 0,03 m³ près (36 cm/25 m → 1,30 m³ vs 1,27 attendu ; P1 → 395 m³/ha).

**Portée.** Même tarif dans **C1 biomasse** (`indicators-families.R:298`) → C1 et
E1 corrigés d'un coup. Aucun autre consommateur (audité). Non-régression cubage
ajoutée + plafond de sanité du test P1 resserré `5000 → 800` (l'ancien laissait
passer le ×4). C1/E1/normalisation revérifiées vertes (317/95/329).

**`method`** : confirmé toujours ignoré (jamais réimplémenté depuis `match.arg`).
`"allometric"` émet désormais un `cli_warn` au lieu d'un faux silence.

**À faire côté app** : bump `nemeton (>= 0.168.1)` + **recalculer les projets
persistés** (les P1/C1 stockés ≤ 0.168.0 restent gonflés). Brief-réponse :
`specs/040-volume-mobilisable-desserte/reponse-p1-cubage-gonfle.md`.

### 2026-07-25 — v0.168.0 : garde-fou d'unité P1 dans `volume_mobilisable()` (spec 040)

**Contexte.** La session app `nemetonshiny` a émis un brief
(`~/brief-nemeton-unite-p1-volume.md`) : sur un projet ForêtAccess réel, la
colonne `indicateur_p1_volume` donnait des valeurs 682–2315 (médiane 1556)
qu'aucune lecture (m³ totaux ou m³/ha) ne rendait plausibles pour un volume sur
pied. Doute : `indicateur_p1_volume` est-il vraiment un volume, ou un score ?

**Réponse tranchée côté cœur.** P1 est **sans ambiguïté un volume sur pied en
m³/ha** (config `Volume de bois (m³/ha)`, `@return … m3/ha`, formule
`V=a·DBH^b·H^c × density`, plafond de normalisation 800). Les valeurs observées
sont donc de vrais m³/ha **hors domaine** (~2× le plafond) : le bug est **en
amont, dans les inputs** (densité/dbh ou inventaire synthétique surestimé), pas
dans le pipeline desserte ni dans l'unité. Le nom `indicateur_p1_volume` est le
nom de colonne canonique (config), `P1` le code court — les deux légitimes,
rien à réconcilier. Brief-réponse complet :
`specs/040-volume-mobilisable-desserte/reponse-p1-unite-desserte.md`.

**Livré.** `volume_mobilisable()` gagne `p1_max_plausible = 800` : `cli_warn`
(pas `abort`) quand un P1 d'entrée dépasse le plafond, avec compte/max/médiane
hors domaine. `NULL` désactive, seuil réglable. Attrape exactement le profil
d'erreur silencieux du brief avant que le typage ne tourne sur un flux gonflé.
4 `test_that` ajoutés (hors-domaine → warn + calcul abouti, plausible →
silencieux, seuil réglable/NULL, seuil invalide → abort). Fichier vert :
41 expectations, 0 échec.

### 2026-07-22 — v0.165.0 : D8 et D9 livrées, spec 040 entièrement close

**D9 — pont de nomenclatures.** Trois codes essence coexistaient sans clé
commune : `espar` IFN (`"09"`), code P1 (`"FASY"`), code tolérances
(`"fagus_sylvatica"`). Pivot retenu : le **nom latin** du référentiel IGN
`espar-cdref13`, jamais d'heuristique sur les libellés français.
`ifn_espar_correspondance()` (193 lignes) + `resoudre_espar()`, qui ramène les
quatre formes au code IFN. `volume_mobilisable()` accepte du coup n'importe
quelle nomenclature — exiger l'`espar` le rendait pénible à appeler depuis des
données d'UGF.

*Appariement par autonyme* : l'IGN descend souvent au rang infraspécifique
(*Picea abies* subsp. *abies*) ; l'autonyme étant taxonomiquement équivalent à
l'espèce, il est apparié. 12 → **20** codes P1 (sur 22 essences réelles),
107 → **125** codes tolérances. Sans autonyme (*Pinus nigra*, publié en
variétés seules) : `NA` assumé plutôt qu'une variété choisie au hasard.

**D8 — supplétif de volume.** `completer_volume_ifn()` comble les `NA` de P1
par la référence régionale (cascade SER → GRECO → national). C'est le cas
ordinaire en **NDP 0**. Deux garde-fous : une mesure n'est **jamais** écrasée,
et la provenance est écrite **ligne à ligne** (`mesure` / `ifn_ser` /
`ifn_greco` / `ifn_national` / `NA`) — sans quoi une valeur régionale peut se
faire passer pour une mesure. Défaut `mesure = "present"` (figure de
peuplement) et non `"maille"`, trop basse d'un ordre de grandeur.

**Deux corrections tombées du croisement.**

1. `ifn_volume_equations.csv` portait `PIME | Pinus menziesii` — le douglas est
   ***Pseudotsuga* menziesii**. P1 n'était pas faussé (`lookup_ifn_equation()`
   apparie sur le code), mais le nom publié était erroné. **Invisible tant que
   cette table n'était pas confrontée à une source externe** — c'est le
   croisement lui-même qui l'a révélé.
2. **Troisième occurrence du piège des zéros non significatifs**, et la plus
   dangereuse. Le référentiel écrit `"9"`, les tables `"09"` : `resoudre_espar()`
   rendait un code **syntaxiquement plausible n'appariant aucune ligne**. Un
   pont ne reliant rien, en silence — `completer_volume_ifn()` aurait rendu des
   `NA` partout et j'aurais conclu « pas de référence pour cette essence »,
   explication crédible et fausse. Le test retenu ne vérifie donc pas la valeur
   rendue mais qu'elle **ouvre réellement** une ligne des tables de référence.

**36 tests** (`test-ifn-espar.R` 20, `test-completer-volume-ifn.R` 16) + 1 sur
`volume_mobilisable`. **Spec 040 entièrement close** : D1-D9 tranchées.

### 2026-07-22 — v0.164.0 : tables IFN essence × SER + **D4 refermée** (spec 040)

Trois pas dans la même journée, chacun corrigeant le précédent.

**1. Reprise `PPtools`/`DataForet`.** Pascal obtient de **Max Bruciamacchie**
l'autorisation explicite (courriel du 22/07/2026) de reprendre sous GPL-3 ses
packages publiés en GPL-2. Table de volume sur pied essence × SER construite
depuis ses `.rda` (2005-2019). Deux découvertes en inspectant la donnée plutôt
qu'en supposant : les placettes IFN portent **déjà** leur SER — donc **le lot 1
(jointure spatiale) était inutile** — et `w` est le poids de sondage, ce qui
**lève D6**. Mais aucune colonne de coupe : pas de prélèvement.

**2. Pascal signale `FrenchNFIfindeR`.** Le package (Jérémy Borderieux, GPL-3)
télécharge l'export brut de l'IGN, qui contient la **revisite à 5 ans**.
Vérification sur l'export réel : `ARBRE.csv` porte `VEGET5`, dont le code **`6`
= coupé vidangé**. Le code `7` (coupé **non** vidangé) est exclu — ce bois reste
en forêt et ne charge jamais la desserte. Les données sont sous **Licence
Ouverte Etalab v2.0**, donc l'autorisation n'était pas requise pour elles ;
elle couvre la méthode. Consigne de Pascal : ne pas dépendre du package mais
**le réécrire et l'améliorer**, et ne pas s'arrêter à 2023.

**3. Tables refaites depuis l'IGN, campagne 2005-2024.** `FrenchNFIfindeR` fige
2023 dans son source ; `ifn_campagne_disponible()` sonde et trouve **2024**.

Livré : `ifn_campagne_disponible()` / `ifn_telecharger()` / `ifn_charger()`
(réécriture, 5 différences documentées : campagne dynamique, non interactif,
tables sélectives, retour de valeur, **aucune dérivation silencieuse** au
chargement) ; `ifn_volume_essence_ser()` / `ifn_volume_reference()` ;
`ifn_prelevement_essence_ser()` / `ifn_taux_prelevement()` ; branchement du mode
table de `volume_mobilisable()`, qui **cesse d'échouer** — **D4 refermée**.
**77 tests** sur les trois fichiers.

**Deux bugs traversés, de natures opposées — à retenir.** Le premier était
*visible* : table de prélèvement à **0 ligne**. La ligne de revisite ne porte
que le sort de l'arbre, `V` et `ESPAR` y sont vides à 100 % ; mesure et essence
vivent sur la ligne de **1re visite**, clé `(IDP, A)`. J'avais lu ces lignes de
`FrenchNFIfindeR`, je les avais citées, et je ne les avais pas comprises.
Agréger sur `W` seul (présent sur 50 458 lignes) aurait donné une table
**pleine et fausse** — le mode d'échec dangereux. Le second était *silencieux* :
hêtre et chênes sans libellé, parce que le référentiel écrit `9`, `2`, `3` et
les données `09`, `02`, `03` ; seuls les libellés le trahissaient, les volumes
étaient justes.

**Contrôle externe** : prélèvement national toutes essences = **2,84 m³/ha/an**,
cohérent avec l'ordre de grandeur publié pour la récolte française ; classement
épicéa / peuplier / hêtre / sapin / chêne sessile / pin maritime / douglas
conforme. Un test verrouille cet ordre de grandeur — c'est le garde-fou contre
une erreur d'échelle (oubli du `/5`, mauvaise colonne, double comptage).

Restent ouvertes : **D8** (le volume IFN sert-il à suppléer P1 en NDP 0 ?) et
**D9** (pont entre codes essence IFN `09` et codes 4 lettres `FASY` de P1 ; le
référentiel porte le nom latin, `european_species_tolerances()` porte
`species_sci` — faisable, non fait).

### 2026-07-24 — Spec 043 cadrée : variables biophysiques S2 (SL2P) — supersède 042

Brief `specs/brief-instance-nemeton.md` (design considéré, en-tête périmé
« v0.43.0/MIT » → il ignorait mon travail de session). Décision Pascal **(A) : le
brief supersède**. Trois livrables rédigés dans `specs/043-biophysique-s2/` (docs
seuls, aucun code) :
- **`spec.md`** — LAI/fAPAR/FCOVER/CCC via SL2P (Weiss & Baret) pur-R, consommés
  par arguments optionnels ; médiane juin-août (table à 1 ligne), gating,
  correction de biais forêt, mapping 7 sous-indicateurs, tests golden SNAP 1e-4 +
  invariance au n_obs.
- **`ADR-015-biophysique-ndp.md`** — amende l'ADR-011 (le brief disait « ADR-012 »,
  **déjà pris** ; plus haut ADR = 014 → **015**). Flag `augmented` unique
  `"biophysical_s2"` conditionné, effet sur φ par la granularité seule.
- **`note-biophysnemeton.md`** — package amont séparé (ADR-009), frontière, interface,
  arbitrage accès S2 : **STAC direct via le pipeline THEIA existant, pas theia2r**.

Écarts vérifiés dans le code et actés en §0 : `augmented` **déjà** un vecteur et
`lai_ml` **déjà** présent (E2) ; `fapar=`/`fvc=` **déjà** câblés (E4) ; « ADR-012 »
pris (E3) ; « 31 vs 29 » signalé, non corrigé — README dit « 31 », le « 29 »
introuvable dans le repo (E5).

**Conséquence** : spec 042 marquée **superseded**. `biophysique_sentinel2()`
(v0.166.0-.1, prosail) sera **retiré** à l'implémentation de la 043 ;
`lai_sentinel2()` (spec 033, repli reGénération) reste. Raison du remplacement :
SL2P est reproductible au 1e-4 contre SNAP (test golden), l'inversion prosail
ré-entraînée ne l'est pas.

### 2026-07-24 — Spec 042 lot 2 : chaînage biophysique → A1/C2 vérifié (déjà câblé)

En attaquant le lot 2 (brancher FVC→A1, fAPAR→C2), découverte : **les
consommateurs préexistaient**. `indicateur_a1_couverture(fvc=)` et
`indicateur_c2_ndvi(fapar=)` acceptent déjà la couche biophysique en opt-in
(`NULL` → NDVI/land-cover inchangés), posés lors d'une phase « Theia
s2_biophysical » antérieure. Il ne manquait que le **socle amont**, livré au
lot 1 (v0.166.0). **Aucun code neuf** : la plomberie était là.

Livré : chaînage bout-en-bout **testé** (`test-biophys-indicators.R`, voie
`precomputed` pure) — `biophysique_sentinel2("fvc")` → A1 ≈ 60 (fvc 0,6 × 100) ;
`biophysique_sentinel2("fapar")` → C2 ≈ 0,6 ; garde-fou d'échelle fAPAR/NDVI
∈ [0,1] (drop-in). Cross-refs `@seealso` A1/C2. Doc + tests, pas de bump.

**Spec 042 en pause** : lots 3 (validation GEODES), 4 (CCC), 5 (confiance pixel)
**bloqués sur données GEODES** — impossible de caractériser le biais fAPAR/FVC/CCC
sans dalles de référence. Le socle produit les variables et les indicateurs les
consomment ; la validation attend la donnée.

### 2026-07-24 — v0.166.1 : `biodivMapR` mal déclaré en Imports (fix CI)

Après v0.166.0, `R-CMD-check` + `pkgdown` rouges — **sans rapport avec le
feature**. `load_imports()` échouait sur `biodivMapR (>= 2.0.0)`, en **Imports**
(dur) alors qu'il n'est utilisé que par `compute_spectral_diversity()` (B4/L3,
spec 028), **gardé par `requireNamespace()`** (ligne 98) et testé avec
`skip_if_not_installed()`. Sa chaîne jbferet (dont `dissUtils`, archivé CRAN) le
rend non installable en CI par moments — même classe que la saga lidR/rlas.
Vérifié : aucun import NAMESPACE, seul consommateur, tests déjà gardés → déplacé
en **Suggests**, comme tous ses frères lourds (`prosail`, `lidR`, `whitebox`,
`fasterRaster`, `reticulate`). Bug latent exposé par l'environnement, pas
introduit par le feature.

### 2026-07-24 — v0.166.0 : `biophysique_sentinel2()` (spec 042 lot 1)

Socle du calcul interne livré. `lai_sentinel2()` (spec 033) généralisé :
`.lai_prosail_train()` / `.lai_prosail_apply()` gagnent un paramètre `parm`
(clé de cache `prosail_<parm>_…`, `parms_to_estimate` paramétré), et
`biophysique_sentinel2(variable=)` expose **LAI/fAPAR/FVC** — les trois cibles
d'inversion **directes** vérifiées dans le code `prosail`
(`train_prosail_inversion` accepte `"lai"`/`"fapar"`/`"fcover"`).
`lai_sentinel2()` devient un **alias mince**, strictement rétrocompatible (les
appelants reGénération inchangés — vérifié : suite complète).

**CCC refusé, à raison.** Vérification faite : le CCC n'est **pas** une cible
directe (composé Cab × LAI). La fonction l'abort avec un message qui pointe vers
le lot 4, plutôt que d'inventer un mapping. Bandes par variable **provisoires**
(défaut LAI validé ; fAPAR/FVC ouvert, D3) et inversion non validée en attendant
le recoupement GEODES (lot 3).

Export + `.Rd` main, pkgdown, 5 tests (voie `precomputed` pure). Restent lots 2
(FVC→A1, fAPAR→C2), 3 (validation GEODES), 4 (CCC), 5 (confiance pixel).

### 2026-07-24 — Spec 042 (v2) : produits biophysiques calculés en interne depuis S2

Question de Pascal : ajouter LAI/fAPAR/FVC/CCC renforce-t-il la cohérence ?
Cadré, **non implémenté**, `specs/042-produits-biophysiques-geodes/spec.md`.

**Pivot v1 → v2.** La v1 proposait de *consommer* le produit national CNES/GEODES
(bloquée sur D1 : mécanisme d'accès inconnu). Vérification faite du code :
`nemeton` **calcule déjà** LAI par inversion PROSAIL hybride (`lai_sentinel2()`,
spec 033), et la **même machinerie** produit les trois autres —
`train_prosail_inversion(parms_to_estimate=)` accepte `"fCover"` (FVC), `"CCC"`,
et `prosail::Compute_fAPAR()` calcule le fAPAR analytiquement. D'où la v2 :
**calcul interne** (généraliser `lai_sentinel2()` → `biophysique_sentinel2()`),
plus cohérent (une méthode, source S2 MUSCATE déjà câblée, NDP maîtrisé) et **sans
dépendance d'accès**. **D1 dissous** ; GEODES rétrogradé de *source* à *référence
de validation*.

**Toujours PAS quatre indicateurs.** LAI/fAPAR/FVC colinéaires → trois dans la
famille C tripleraient le poids de la verdeur (Fibonacci). La valeur : raffiner
des proxys — FVC→A1 (déjà câblé), fAPAR→C2 (NDVI sature), LAI→C1 (`ndvi×150`),
CCC = seul signal neuf (santé), candidat R5.

**Deux réserves survivent au pivot** (à ne pas masquer) : le mal-posé du CCC est
**inhérent à S2** — l'inverser localement ne le fiabilise pas ; et on perd la
validation + le masque qualité « gratuits » de GEODES → soit valider contre lui
(lot 3), soit construire une **confiance par pixel** interne modulant φ (D5, le
vrai chantier). D2 (usage CCC), D3 (bandes red-edge par variable) ouvertes.

### 2026-07-24 — Chaîne desserte bouclée : tout est livré et consommé en aval

Vérification en lecture seule des deux repos frères. Le dernier reliquat côté
`nemeton` — `volume_mobilisable()` livré mais non consommé — **est câblé**.

**`nemetonshiny` v0.113 → v0.115.2**, plancher relevé à `nemeton (>= 0.165.0)` :
- **v0.114.0** : panneau **« Typage du réseau »** (spec 040) —
  `service_desserte.R` enchaîne exactement le brief
  `brief-nemetonshiny-volume-desserte.md` : `indicateur_p1_volume` →
  `volume_mobilisable(unite = "m3_total")` → `calculer_flux(volume_champ)` →
  `typer_desserte(seuils_flux)`. Le piège d'unité du §3 (`m3_total`, pas
  `m3_ha`) est respecté et cité dans le code.
- **v0.115.0** : moteur câble-mât exposé + toggle « NDP 1 desserte corrigée
  LiDAR ». **v0.115.1** : couche **ACCESSFOR** affichable + comparaison avec les
  classes de débardage (consomme la découverte WFS de ce repo, spec 040 §12).
  **v0.115.2** : NDP 1 câble n'est plus expérimental, largeurs LiDAR →
  `places_depot()`, couverture câble **85 % mesuré vs 91 % optimiste**.

**`foretaccess` v1.16 → v1.19.1** :
- **v1.18** : micro-relief LiDAR, portage **RVT en Rust** (spec 021).
- **v1.19.0** : `qualifier_desserte()` sur desserte de projet réelle ;
  **`contracter_lignes()`** — le `$lignes` contracté que le brief desserte
  demandait en option ; composition `largeur_carrossable_m` → `places_depot()`.
- **v1.19.1** : fix bloquant du segfault de `qualifier_desserte()` sur 3 299
  tronçons.

Point notable : `foretaccess` **documente désormais l'appariement des unités**
avec `volume_mobilisable()` des deux côtés (`desserte_flux.R` : « use
`unite = "m3_total"` » ; `desserte_reseau.R` : « the **opposite** unit,
`m3_ha` »). Le piège du §3 de la spec 040 est donc gravé dans les deux repos.

**Bilan.** La boucle ouverte le 2026-07-21 (« quel volume passer à
`volume_champ` ») est bouclée de bout en bout sur les trois repos :
**P1 → volume mobilisé → flux → réseau typé**. Aucun reliquat côté `nemeton` —
spec 040 close **et consommée**, spec 041 caduque (`acquire_desserte_lidar` en
production), tous les briefs desserte/câble/ACCESSFOR traités. `volume_depuis_p1`
(câble, sur pied) et `volume_mobilisable` (typage, mobilisé) coexistent sans
redondance, comme prévu.

### 2026-07-23 — Point de convergence : `foretaccess` v1.16.0 a traité TOUS les briefs

`foretaccess` a bondi de **1.9.0 à 1.16.0** (dernier commit `feat/desserte-finish`).
Les cinq chantiers du brief desserte consolidé et le brief LiDAR sont **livrés
côté foretaccess** — lecture seule de son NEWS :

| Chantier (brief) | Livré foretaccess |
|---|---|
| 1 — perf glouton | **v1.12.0** : tracé A* borné au couloir, ~200 s → ~20 ms |
| 1v2 — Steiner / bornes optimiseurs | **v1.13.0** (Steiner reste N², documenté) |
| 2 — connexité / `connexe` | **v1.11.0** : booléen `raccorde` + sémantique clarifiée |
| 3 — `places_depot()` | **v1.11.0** : ~40× plus rapide |
| 4 — desserte LiDAR | **v1.14.0** `acquire_desserte_lidar()`, validée v1.16.0 |
| ACCESSFOR | **v1.9.0** `accessfor_correspondance()` (déjà consommé app v0.113.0) |
| volume P1 → câble | **v1.7.0/1.8.0** `volume_depuis_p1()` |

**Spec 041 (`nemeton`) est CADUQUE.** `acquire_desserte_lidar()` (foretaccess
v1.14.0) implémente exactement ce que je cadrais côté cœur : géométrie recalée,
`largeur_carrossable_m` (= `DRIVABLEWIDTH`), `largeur_plateforme_m` (=
`ROADWIDTH`), `score_lidar`, `etat_classe`, repli NDP 0 → `NA`, dérivation du MNT.
Le brief se disait « côté cœur » ; j'ai lu `nemeton`, mais l'acquisition de
desserte relève de `foretaccess` (qui portait déjà `acquire_desserte()`). **Aucun
code n'était à écrire ici** — la spec 041 est conservée pour ses résultats de
validation et la traçabilité.

**Convergence sur le MNT.** Mon volet A (MNT 1 m, 40/40 mesures) et la Phase B de
foretaccess (MNT 1 m, 22/22 pistes Chastel-Nouvel) concluent identiquement :
ALSroads mesure bien les pistes françaises **avec un MNT ≥ 1 m**. Foretaccess a
même élucidé le mécanisme — son 0/6 de v1.15.0 était un **faux négatif dû à un MNT
à 5 m**, pas au calibrage Québec ; le guide ALSroads exige MNT ≥ 1 m, profils à
0,5 m.

**Correction de ma reco D6.** Mon §10.4 recommandait « MNT 20 cm +
`profile_resolution = 0.2` » sur la foi du score (96,4) — mais **sur deux tronçons
seulement**, et dans le sens *plus fin* que le guide. Foretaccess suit le guide
(dérive un MNT à `dtm_res = 1` m, décime le nuage à ~10 pts/m²). **D6 est à
abandonner** : mon extrapolation vers du sur-échantillonné était hasardeuse, le
réglage de référence est MNT ≥ 1 m.

**Ce qui reste réellement côté `nemeton`** : `volume_mobilisable()` (spec 040) est
livré mais **pas encore consommé** en aval. `foretaccess::volume_depuis_p1()` est
un pont *géométrique* (P1 sur pied → raster `pre$volume` pour le câble/IPC), sans
prélèvement — **distinct** de `volume_mobilisable()` (sur pied → *mobilisé* avec
taux IFN, pour `calculer_flux()`/typage). Les deux sont complémentaires, pas
redondants. Le typage de desserte (`calculer_flux → typer_desserte`) consommera
`volume_mobilisable()` maintenant que les moteurs sont débloqués — câblage côté
app **fait le 2026-07-24** (app v0.114.0, cf. entrée ci-dessus).

### 2026-07-22 — Spec 041 : D1 et D4 tranchées sur données réelles (Vercors)

Lots 1-2 de la spec 041 exécutés sur l'emprise Quatre Montagnes (tuiles IGN
LiDAR HD 2025, desserte BD TOPO V3, 341 tronçons). Scripts rejouables archivés
dans `specs/041-desserte-lidar-alsroads/`.

**D1 — chaîne d'installation mesurée** : ALSroads → lidR (**archivé CRAN le
2026-06-09**, vivant sur GitHub) → rlas (idem) → EBImage (**Bioconductor**) →
fftwtools → **libfftw3-dev** (bibliothèque système). Cinq niveaux, quatre
écosystèmes. Mise en perspective vérifiée : `nemeton` porte déjà 12+ `Remotes`,
`fasterRaster` (GRASS GIS), `whitebox` (binaire) et `reticulate` (Python) —
FFTW3 est plus léger que GRASS. **Chaîne lourde mais proportionnée** ; un premier
jugement de « coût disproportionné » de ma part reposait sur une norme générique
de packages R, pas sur ce repo.

**D4 — favorable avec réserves.** Volet A : 40/40 mesures, `DRIVABLEWIDTH`
sentier **2,40 m** contre 5,25-5,85 m pour les classes carrossables,
**p = 0,000242** ; le `SCORE` double le signal (36 contre 70-75). Volet B :
l'ortho ne montre rien sous couvert, mais le MNT 20 cm recalculé par TIN sur les
retours sol montre la largeur mesurée **épousant les bords de plateforme**.
Sensibilité : largeur et classe **stables** de 1 m à 20 cm, score 75 → 96,4 en
affinant `profile_resolution` à 0,2. Coût **47,3 s/tronçon** → ≈ **43 h** sur
l'AOI de référence `foretaccess` : cache obligatoire.

**Le piège évité, à retenir.** La première exécution portait sur `ROADWIDTH`
(largeur du **corridor**) et non `DRIVABLEWIDTH` (chaussée) : sentier à 5,40 m,
ordre inversé, p = 0,0125. La lecture qui s'imposait — « calibrage québécois non
transposable, D4 échoue » — était plausible, chiffrée, **conforme à ce que le
brief laissait attendre**, et fausse. Le brief mentionnait pourtant « largeur
carrossable » ; je l'avais lu, résumé et recopié dans ma propre spec avant de
coder l'autre colonne. Sixième occurrence du jour du même travers, la première
attrapée avant de la rapporter comme un fait.

Réserves restantes : justesse absolue **non mesurée** (pas de relevé terrain),
n = 10/classe sur **une seule emprise** montagnarde, seuils québécois
`drivable_width_thresholds = c(1, 5)` à recaler (**D7**), surcoût du MNT 20 cm à
chiffrer (**D6**). Lots 3-4 non implémentés.

### 2026-07-22 — Spec 041 cadrée : desserte corrigée LiDAR (ALSroads)

Part `nemeton` du brief `brief-foretaccess-desserte-lidar.md`, qui se déclarait
lui-même « feature NDP 1+, donc côté cœur ». Cadrée dans
`specs/041-desserte-lidar-alsroads/spec.md`, **non implémentée**.

**Trois points du brief corrigés après vérification** :

1. **L'arbitrage `lidR` vs `lasR` n'existe pas.** Le brief le posait en question
   ouverte ; `DESCRIPTION` porte **déjà les deux** (`lidR >= 4.0.0`,
   `lasR >= 0.10.0`, en Suggests). ALSroads, qui s'appuie sur `lidR`, n'impose
   aucun portage.
2. **ALSroads est moins dormant qu'annoncé** : dépôt poussé le **2024-11-15**
   (le brief dit « v0.2.0 (2022), maintenance non visible »), non archivé, et
   **GPL-3** — compatible, aucune autorisation à demander.
3. **Le cœur lit déjà des nuages de points** (`pai_depuis_nuage()`,
   `R/lidar_processing.R`, via `lasR`, bornage mémoire). La brique d'entrée
   existe.

**Le vrai manque est l'acquisition, pas la lecture.** `nemeton` n'expose que
`probe_ign_lidar_tile()` — un *diagnostic*, dont la doc dit que c'est
`nemetonshiny` qui télécharge. `FR.json` ne déclare que les rasters dérivés
(`lidar_mnh`/`mnt`/`mns`), pas le nuage NUAGE. D'où la décision de conception :
`desserte_lidar()` prend un **répertoire de tuiles** fourni par l'appelant,
comme `pai_depuis_nuage(dossier_las=)`. Elle n'acquiert rien.

**Le risque du chantier n'est pas technique, il est métrologique.** ALSroads est
calibré sur des forêts nordiques québécoises et du LiDAR single-photon. Une
largeur **mesurée mais fausse est pire qu'une largeur absente**, parce que
`places_depot()` la croira. D'où un lot 1 bloquant : confronter les largeurs
mesurées au terrain ou à l'orthophoto sur emprise française **avant** tout le
reste, et un lot 4 qui chiffre l'effet réel (les ~1 877 départs tombent-ils à un
ordre exploitable ?). D1 (dépendre d'ALSroads en Suggests — recommandé) et D4
(recalibrage France) restent ouvertes.

### 2026-07-22 — App `nemetonshiny` v0.113.0 : validation ACCESSFOR câblée

Livraison **100 % app**, aucun changement cœur — mais elle referme la boucle
ouverte ce matin depuis ce repo.

- 2026-07-22 — nemetonshiny v0.113.0. Panneau de **validation ACCESSFOR** :
  consommation de `foretaccess::accessfor_correspondance()` (livré en
  **foretaccess 1.9.0**) et affichage des couches WFS
  `IGNF_ACCESSIBILITE-PHYSIQUE-FORETS-:acces_skidder` / `:acces_porteur`.

**Boucle complète en une journée.** La couche ACCESSFOR a été découverte ici
même le 2026-07-22, en sondant le WFS Géoplateforme pendant la reconnaissance
de sources de la spec 040 (lot 0). Le brief de cadrage
`specs/brief-foretaccess-accessfor.md` — correspondance des classes, pièges du
masque forêt et de la rasterisation catégorielle — a été porté dans
`foretaccess`, qui a livré `accessfor_correspondance()` en 1.9.0, puis consommé
côté app en v0.113.0. Trois repos, un aller-retour, le même jour.

**`foretaccess` a beaucoup avancé** (1.6.0 → 1.9.0) : `places_depot()` (1.6.0,
corrigé 1.6.1), `volume_depuis_p1()` (1.7.0) + `acquire_inputs(volume=)` (1.8.0)
— le pont **P1 Nemeton → volume câble/IPC**, qui consomme donc directement le
travail cœur de cette session —, et `accessfor_correspondance()` (1.9.0).

### 2026-07-21 — App `nemetonshiny` v0.112.0 : sous-onglet Desserte, moteur glouton

Entrée demandée par la session app (`nemeton-plan-entries.md`, entrée 2) —
livraison **100 % app**, aucun changement cœur.

- 2026-07-21 — nemetonshiny v0.112.0 (`nemetonshiny@55992e6c` + merge
  `nemetonshiny@1a73292c`, cycle dev 0.112.0.9000). Nouveau sous-onglet
  « Desserte » sous « Terrain accessible » : conception de réseau de desserte
  forestière via `foretaccess::reseau_desserte(mode = "glouton")`. Pipeline app :
  acquisition MNT 5 m HIGHRES + desserte IGN BD TOPO + masque BD Forêt V2 →
  `preprocess()` → `surface_cout_construction()` → glouton. Worker `future`
  opt-in (glouton mesuré ~11,5 min / 30 parcelles), cache projet, réseau créé en
  overlay raster, badges parcelles-desservies / connexité / coût, export
  GeoPackage. **Steiner** (N² tracés, > 5 h estimées) et **optimiseurs**
  (`optimiser_reseau`) **non exposés** — ils attendent le travail perf côté
  `foretaccess` (cf. `specs/brief-foretaccess-desserte-perf-connexite.md`).
  Refactor préalable : IO ForêtAccess mutualisées (`service_foretaccess_io.R`).

L'entrée 1 du même document (fix transparence `hors_foret` v0.111.2) était déjà
posée le matin même — non dupliquée. Les deux briefs joints sont archivés dans
`specs/` (entrée du 2026-07-22 ci-dessous).

**Aucun sous-chantier n'est coché** : les moteurs lourds (Steiner, optimiseurs,
câble-mât) restent ouverts tant que le travail `foretaccess` n'est pas livré,
conformément à la consigne de l'émetteur.

### 2026-07-22 — Archivage (2) : briefs `foretaccess` consolidés + plan d'incréments app

Trois documents supplémentaires sortis du scratchpad de la session app, recopiés
**verbatim** (`diff` vérifié) dans `specs/` :

| Fichier archivé | Nature |
|---|---|
| `brief-foretaccess-consolide-2026-07-22.md` | **révision consolidée** — 5 chantiers, mesures sur foretaccess **1.9.0** |
| `brief-foretaccess-desserte-lidar.md` | desserte corrigée LiDAR (ALSroads) : largeur mesurée + géométrie recalée |
| `plan-app-increments-foretaccess-1.9.md` | plan d'incréments app pour consommer foretaccess 1.9.0 |

⚠️ **`brief-foretaccess-consolide-2026-07-22.md` supersède
`brief-foretaccess-desserte-perf-connexite.md`** (archivé la veille) : même
chantier perf/connexité, mais mesuré sur 1.9.0 et enrichi de trois chantiers
supplémentaires. L'ancien est conservé comme trace, ne pas le traiter en
parallèle.

**Point d'attention côté cœur** : le brief LiDAR se déclare explicitement
« feature **NDP 1+**, donc **côté cœur** — l'app ne fera qu'exposer un toggle ».
Il y a donc probablement une part `nemeton` à cadrer dans ce chantier
(correction de la desserte BD TOPO par ALSroads), non instruite à ce stade.

### 2026-07-22 — Archivage des briefs desserte (sortis de `/tmp`)

Les documents de cadrage du chantier desserte vivaient dans le **scratchpad de la
session app** (`/tmp/claude-1000/-home-pascal-dev-nemetonshiny/…`), donc voués à
disparaître. Recopiés **verbatim** (octet pour octet, `diff` vérifié) dans
`specs/` :

| Fichier archivé | Origine | État |
|---|---|---|
| `brief-foretaccess-desserte-perf-connexite.md` | session app, 2026-07-21 | à traiter côté `foretaccess` |
| `brief-foretaccess-cable-places-depot.md` | session app, 2026-07-21 | **traité** — `foretaccess` v1.6.1, `fix(depot): places_depot()` |
| `plan-app-sous-onglet-desserte.md` | plan de dev app | pour mémoire (le typage y est en 6ᵉ position) |

Les fichiers sont conservés tels quels : la provenance est consignée ici plutôt
qu'ajoutée en tête des documents, pour que le contenu reste le texte de l'émetteur.
Les originaux `/tmp` n'ont **pas** été supprimés — la session app est active et
peut encore s'y référer.

Ces trois documents rejoignent `brief-foretaccess-accessfor.md` (émis d'ici le
2026-07-22). Le chantier desserte est donc entièrement tracé dans ce repo, même si
son exécution appartient à `foretaccess`.

### 2026-07-22 — v0.163.0 : `volume_mobilisable()` livré (spec 040, jalon « taux saisi »)

Décision de Pascal : **taux saisi d'abord, IFN plus tard**. Correction de périmètre
au passage — j'avais annoncé un jalon « lots 1+4 », c'était faux : le **lot 1
(résolution SER) ne sert qu'à keyer la table IFN**, et avec un taux saisi
l'argument `ser` n'est jamais consulté. Le jalon se réduit donc au **lot 4 seul**.
Ni source SER à déclarer, ni `load_ser_source()`, ni jointure spatiale : rien de
l'infrastructure identifiée au lot 0 n'est nécessaire pour débloquer l'app.

Livré : `volume_mobilisable(units, volume_col, unite, taux_prelevement,
horizon_ans, na_policy, column_name)`, export + `.Rd` à la main
(`project_rd_no_document`), **22 tests PASS**. Le cœur ne calcule aucun volume —
`indicateur_p1_volume()` en reste seul propriétaire — et n'appelle pas
`foretaccess` : le couplage reste un **contrat de colonne**, la direction des
dépendances est préservée.

Les trois écarts du cadrage sont traités : `unite` (`m3_total` pour
`calculer_flux()`, `m3_ha` pour `reseau_desserte()`/`optimiser_reseau()`, cf. le
piège du §3), `taux_prelevement` × `horizon_ans` (flux annuel, pas fraction), et
`na_policy` pour le cas NDP 0 où P1 est `NA`. Un CRS géographique est refusé en
`m3_total` plutôt que de rendre des hectares douteux. Test de non-régression
explicite du piège d'unité : à P1 égal, `m3_ha` est identique entre deux parcelles
et `m3_total` est dans le rapport de leurs surfaces.

Décisions prises dans leur version conservatrice, réversibles sans casser l'API :
**D3** = `na_policy = "na"`, **D5** = pas de repli CHM (la fonction consomme une
colonne P1 déjà calculée). **D4/D6/D7 différés** : le mode table échoue
explicitement (`cli_abort`) plutôt que de servir des chiffres non sourcés.

Reste pour plus tard : lots 1-3 (source SER download-only, dérivation des taux
depuis les données brutes IFN, cascade de repli). Côté aval, rien n'est débloqué
tant que les deux blocages `foretaccess` du brief desserte tiennent.

### 2026-07-22 — Spec 040 cadrée : `volume_mobilisable()` (couplage P1 → `volume_champ`)

Le brief app `brief-desserte-perf-connexite.md` (session `nemetonshiny`) arrive
avec trois demandes ; **deux ne sont pas pour ce repo**. Perf des moteurs, bornes
Steiner/optimiseurs, sémantique de `connexe`/CA-16.5, `$lignes` contracté : tout
cela vit dans **`foretaccess`** (`reseau_desserte`, `surface_cout_construction`,
`optimiser_reseau` — absents de `nemeton`, `NAMESPACE:86` côté foretaccess), qui a
son repo, son `PLAN.md` et sa version (v1.6.1). Routé vers la session dédiée, comme
l'avait été le brief câble (déjà traité là-bas : `fix(depot): places_depot()`).

**Seul point réellement cœur** : le typage du réseau
(`calculer_flux` → `typer_desserte`) a besoin d'un volume par parcelle, et le vrai
volume est l'indicateur **P1** — sans dupliquer le calcul (règle 1). Cadré dans
`specs/040-volume-mobilisable-desserte/spec.md`, **non implémenté**.

Le cadrage a mis au jour un piège qui aurait produit un résultat faux :
`volume_champ` a **deux consommateurs de sémantique opposée**. `calculer_flux()`
répartit le volume sur les points sources (`desserte_flux.R:257`) → il attend un
**total m³** ; `reseau_desserte()` le rasterise par cellule
(`desserte_reseau.R:319`) → il attend une **densité m³/ha**, sous peine de
surpondérer les grandes parcelles. P1 étant en m³/ha *sur pied* et `calculer_flux`
documentant des « harvested parcels », il y a aussi un écart de sémantique
(stock vs mobilisé) et un trou de politique NA (P1 est `NA` en NDP 0 sans
inventaire ni CHM). D'où `unite = c("m3_total", "m3_ha")` + taux de prélèvement.

Décisions tranchées : **D1** taux paramétrable + table par essence (repli
feuillu/résineux via `is_conifer()`), **D2** couvrir les deux consommateurs,
**D4 taux de prélèvement IFN par essence × SER** (tranchée le 2026-07-22).

D4 coûte plus que le CSV : **le cœur ne sait pas ce qu'est une SER** (aucune
occurrence dans `R/` ni dans `FR.json`, dont les seules couches `ign_wfs` sont
bdforet/roads/water/buildings/departments). Il faut donc déclarer la source SER,
un `load_ser_source()` calqué sur `load_foret_ancienne_source()`, et une jointure
spatiale UGF → SER au recouvrement majoritaire. Deux autres conséquences : un taux
IFN est un **flux annuel** (m³/ha/an), d'où un paramètre `horizon_ans` obligatoire
et non une simple fraction ; et un prélèvement **observé** n'est pas une
prescription — dimensionner une desserte dessus suppose « la gestion continue comme
avant », hypothèse à écrire dans la doc. Plan en 5 lots ajouté (spec §11), avec un
jalon intermédiaire : lots 1+4 en taux saisi suffisent à débloquer l'app, les lots
2-3 apportent le défaut sourcé.

**Reconnaissance des sources (lot 0, faite le 2026-07-22 — résultat négatif).**
GetCapabilities WFS Géoplateforme (5,1 Mo, HTTP 200) : **aucune couche SER** (zéro
« sylvo » dans tout le document) et **aucune donnée de prélèvement** (zéro
prélèv./récolte/mortalité/production). L'espace `ObsForets` (« Source :
IGN-Inventaire forestier ») ne publie que 8 couches en maille
département/région/commune — volume **sur pied**, taux de boisement, niveaux
trophiques, part forêt publique — jamais de prélèvement, jamais de SER. Donc : la
couche SER passera par un téléchargement millésimé `inventaire-forestier.ign.fr`
(download-only, comme la BD Forêts anciennes) et le taux de prélèvement devra être
**dérivé des données brutes IFN** (arbres exploités entre deux passages), ce qui
est un chantier statistique à part entière — à arbitrer avant engagement. Le jalon
« lots 1+4 en taux saisi » devient le chemin le plus probable.

**Trouvaille latérale, à transmettre à `foretaccess`** : le même GetCapabilities
expose `IGNF_ACCESSIBILITE-PHYSIQUE-FORETS-:acces_skidder` / `acces_porteur`
(projet **ACCESSFOR**, IGN, édition 2025-01-01, + variante masque Forêt v3) —
cartographie nationale de l'accessibilité aux engins d'exploitation, **mêmes noms
d'engins que les moteurs `foretaccess`**, servie en WFS. En échantillonnant la
couche (`GetFeature`, dép. 01/08/09) plutôt qu'en la supposant : les libellés sont
« Accessible - Classe de débardage 1 : 0-250 m », 2 : 250-500, 3 : 500-1000,
4 : 1000-1500 — **mêmes bornes** que `classes_debardage()` (0-250 … > 2000). La
comparaison est donc quasi terme à terme. Brief de validation livré :
`specs/brief-foretaccess-accessfor.md` (correspondance des classes, pièges du
masque forêt — BD Forêt V2 vs MASQUE-FORETV3 — et de la rasterisation catégorielle
en plus proche voisin, matrice de confusion attendue). Rien à faire côté `nemeton`
(spec 040 §12).

Restent ouvertes : D3 politique NA, D5 repli CHM, **D6 granularité réellement
tenable de la maille essence × SER** (86 SER × ~30 essences → cases à faible
effectif ; repli en escalier SER → GRECO → national → feuillu/résineux, sur
l'idiome déjà en place dans P1), D7 millésime IFN. Rien n'est débloqué tant que les
deux blocages `foretaccess` tiennent : le typage est en 6ᵉ position du plan de dev
app.

### 2026-07-21 — App `nemetonshiny` v0.111.2 : `base::%in%` sur SpatRaster (masque no-op) — cœur audité, non affecté

Remontée depuis la session app (`nemetonshiny@59522747`, cycle dev 0.111.2.9000) :
sur la carte **Accessibilité**, les zones hors forêt étaient peintes en **blanc
opaque** au lieu d'être transparentes, sur les 4 couches (skidder / porteur /
camion DFCI / classes de débardage). Cause : le masquage `hors_foret` était résolu
par **`base::%in%`** — l'app n'importe aucune méthode S4 de terra dans son NAMESPACE
— qui renvoie `FALSE` sur un `SpatRaster` → **masque no-op silencieux**. Corrigé
côté app via `terra::values()` / `terra::setValues()`, plus couleurs de classes
sémantiques (fin de l'`inaccessible` peint en vert sur la carte DFCI) et légende
traduite. Vérifié sur rasters réels (projet Chastel-Nouvel) : ~33 % de pixels
transparents contre 0 % avant.

**Audit cœur (aucun changement) :** les deux seuls sites cœur où `%in%` porte sur
un `SpatRaster` qualifient déjà l'opérateur et documentent le piège —
`R/indicators-naturalness.R:377` (`terra::\`%in%\`(r, forest_class)`) et
`R/fordead_postprocess.R:131` (vecteur explicite). Tous les autres `%in%` du cœur
portent sur des vecteurs déjà extraits (`terra::values()`, `safe_extract()`,
`terra::app()`) ou sur des `names()` — donc sûrs. `NAMESPACE` n'importe de terra
que `clamp`/`extract`/`global`/`rasterize`/`terrain` : la règle « toujours préfixer
les opérateurs S4 de terra » reste la seule protection. Mémoire :
`project_terra_s4_operators`.

**Rectificatif (2026-07-21, même jour) — la « dette règle #1 » annoncée ici
n'existe pas.** La première rédaction de cette entrée affirmait que
`run_accessibility()` et ~1050 lignes de logique métier d'accessibilité vivaient
dans l'app en violation de la règle #1. Conclusion tirée d'un `grep "nemeton::"`
resté muet, **sans lecture du fichier** — c'est faux :

- `R/service_accessibility.R` est un **adaptateur** autour du package amont
  **`foretaccess`** (réimplémentation R de Sylvaccess/INRAE, `pobsteta/foretaccess`,
  déclaré en `Imports:` + `Remotes:` de l'app) ; son en-tête invoque explicitement
  les règles 1/2. Le métier — pente, propagation least-cost, classes de débardage,
  masque DFCI — est **dans `foretaccess`**, pas dans l'app, qui se borne à résoudre
  l'AOI, acquérir la desserte, appeler `preprocess()` + les moteurs et écrire les
  `.tif`.
- `R/mod_accessibility.R` (600 lignes) est de l'UI/serveur Shiny — à sa place.
- « Zéro appel `nemeton::` » ne prouvait rien : le cœur amont, ici, s'appelle
  `foretaccess`.

**Question ouverte (pas une dette) :** `nemeton` enveloppe déjà `opencanopy` pour
les CHM (spec 005) ; par symétrie, l'intégration `foretaccess` pourrait passer par
le cœur — pertinent surtout si l'accessibilité doit un jour nourrir un indicateur
(S1 routes, exploitabilité côté P). Aujourd'hui **aucun indicateur ne la consomme**
(non vérifié en détail), donc rien ne l'impose. À trancher le jour où un indicateur
en dépendra.

Leçon (cf. mémoire `feedback_verify_source_of_truth`) : ne pas conclure à une
violation d'architecture sur la foi d'un grep — lire le fichier.

### 2026-07-15 — v0.159.0 : `eobs_bivariate_n()` (invalidation cache bivarié)

Sur Reconfort, la carte bivariée E-OBS affichait **3×3 = 9 classes** au lieu du
**5×5 = 25** courant. Diagnostic : le cœur (installé 0.158.0, `.EOBS_BIVARIATE_N=5`)
produit bien 5×5 et réécrit le cache, mais l'app **sert le `context_bivariate.tif`
caché sans le recalculer** (mod_regeneration.R ≈ 1183) et la clé de cache est un
chemin fixe par vue, sans marqueur de schéma → un cache écrit avant le passage 5×5
reste 3×3 indéfiniment. Fix cache manuel = supprimer le `.tif`, mais il faut une
invalidation automatique. Le cœur exposait déjà le N d'écriture dans la meta
(`palette$ncol`) ; manquait l'accès au N **courant** côté app. Livré : export
`eobs_bivariate_n()` (retourne `.EOBS_BIVARIATE_N`), NAMESPACE + `.Rd` main, test
(128 PASS). Câblage app cadré : `specs/034-eobs-source/brief-nemetonshiny-bivariate-cache.md`
(§4 : invalider quand `meta$palette$ncol != nemeton::eobs_bivariate_n()`).

### 2026-07-15 — Briefs reGénération livrés ET mergés côté `nemetonshiny`

Les quatre chantiers app cadrés côté cœur cette session sont implémentés et mergés
dans `nemetonshiny` (app à **v0.106.13.9000**) :
- **v0.106.10** (`feat/regen-capped`) : moteur reGénération plafonné en mémoire via
  `nemeton::run_memory_capped(package="nemetonshiny", …)` — consomme la
  généralisation cœur v0.158.0 ; garde de capacité vérifiant que
  `run_memory_capped` a bien `package`/`options`. Vérifié en prod : run ERA5 dans
  scope isolé, `MemoryMax≈22,5G`, `MemorySwapMax=0`.
- **v0.106.11** : persistance R7 inter-sessions + infobulle « i » SAFRAN vs
  ERA5-Land sur le radio Forçage (brief verrou-boutons §7).
- **v0.106.13** (`fix/regen-carry-r7-recompute`) : la couche gel R7 survit à un
  « Lancer l'analyse » / « Moteur » (report de `r7_gel_days` au recalcul, brief §8).
- Verrou d'exclusion mutuelle des tâches lourdes (`deny_if_busy()` / `busy()`,
  brief §1-6).

Briefs : `specs/035-bilan-hydrique-spatialise/brief-nemetonshiny-verrou-boutons.md`
(§1-8) et `…/brief-nemetonshiny-regen-capped.md`. Chantier anti-OOM reGénération
**clos** (cf. mémoire `project_reconfort_oom_isolation`).

*Complément 2026-08-15* — deux releases app du même lot n'étaient pas nommées
ici, relevées à la revue du §4 de `specs/BRIEF-nemeton-plan-md-0.122-0.124.md` :
**v0.106.5** (mémoire des workers `future`, spec 008) et **v0.106.6** (FORDEAD
en processus plafonné, consomme le cœur ≥ v0.157.0). Leurs versants cœur sont
journalisés — v0.157.0 le 2026-07-14, v0.158.0 le 2026-07-15 — seule la
référence app manquait.

### 2026-07-15 — v0.158.0 : `run_memory_capped()` généralisé (anti-OOM reGénération)

Suite au crash OOM de l'analyse reGénération sur Reconfort (systemd-oomd a tué les
11 process du scope RStudio, pic 16,8 Go, 10:11), diagnostic : le moteur
reGénération tourne dans un worker `future::multisession` **nu**, dans le scope de
l'app — pas d'isolation mémoire, contrairement à FORDEAD (`run_memory_capped`,
v0.157.0). Mais `run_memory_capped()` ne s'appliquait pas tel quel : son enfant
faisait `getExportedValue("nemeton", fun)`, or le worker `run_regeneration_engine`
est interne à `nemetonshiny`. Prérequis cœur livré : `run_memory_capped()` gagne
`package=` (résolution via `get(fun, asNamespace(package))` → atteint les internes
de n'importe quel package) et `options=` (pose `nemeton.app_options` dans l'enfant).
Rétrocompatible, FORDEAD inchangé. Progress du moteur = déjà sur disque
(`engine_status.json`), pas de callback à recâbler. Tests : +2 cas dans
`test-isolate.R` (round-trip `package="jsonlite"`, injection `options=` vérifiée
côté enfant/parent) — 31 PASS avec cgroup réel. Câblage app cadré dans
`specs/035-bilan-hydrique-spatialise/brief-nemetonshiny-regen-capped.md` (§2) ;
brief verrou boutons + infobulle Forçage inchangé. Voir mémoire
`project_reconfort_oom_isolation`.

### 2026-07-16 — v0.162.0 : `regen_rank_species()` top-N essences par UGF (spec 039)

Réponse au brief `brief-nemeton-regen-rank-species.md` : proposer par UGF les 3
essences les plus pertinentes pour la régénération. Brique cœur **déterministe**
(le narratif IA reste app, phase 2). `R/regen_rank_species.R`, 2 fonctions
exportées :

- `regen_rank_species(units, species_pool, top_n, weights, exclude_invasive,
  region, cover_col, lai_col, extinction_k, id_col, include_atlas)` → data.frame
  long (UGF × rang) : `ug_id, rank, species_code, label, type, suitability,
  limiting_factor, confidence, invasif`.
- `regen_rank_to_wide()` → une ligne/UGF (`essence_r`/`score_r`/`label_r`/`facteur_r`).

Adéquation = moyenne pondérée (renormalisée sur axes présents) de 3 axes 0-100 :
**chaleur & sécheresse** (réutilise `indice_priorite_regen()` + REW édaphique vs
`drought_tol`, loi du minimum), **gel tardif** (pression `R7`/`r7_gel_days` ×
`frost_late` par essence), **ombre** optionnelle (densité couvert via `cover_col`
ou `lai_col` converti Beer-Lambert vs `shade_tol` ; sinon omise + départage).

**Découverte (verify source of truth)** : le brief supposait 2 lacunes data
(§3.b trait gel par essence, §3.c). Or `european_species_tolerances.csv` a **déjà**
`frost_late`/`frost_early` (fagus=1 sensible, chêne=4 résistant) et `shade_tol` —
donc l'axe gel **différencie** les essences (mieux que le repli P1 uniforme du
brief). Décisions actées via AskUserQuestion : gel par `frost_late` ; ombre
optionnelle via `cover_col`/`lai_col` (le pipeline produit déjà le LAI/PAI —
remarque de Pascal), sinon omise. `confidence` propagée (pas fondue), déterministe,
NA-safe. 10 tests (`test-regen-rank-species.R`, valeurs calc. main). Spec 039.
**Suivi app** (règle 11) : top-3 fiche parcelle + carte, puis conseil IA — brief §7.

**Suite — 2026-07-16 : spec 039 close côté app.** Approche hybride livrée : **P1**
top-3 déterministe par UGF dans la fiche parcelle de reGénération (score
d'adéquation 0-100, facteur limitant, confiance ; invasives écartées ; wrapper
`regeneration_species_ranking` NA/erreur-safe) — **nemetonshiny@38b85d00
(v0.107.16)** ; **P2** sidebar repliable « Affiner la reGénération avec l'IA » — le
LLM ne classe pas, il met en prose le top-3 déterministe + les conditions de
station par UGF selon le profil expert, avec garde-fou anti-essence-hors-classement
— **nemetonshiny@ad77876f (v0.107.17)**. Plancher app `Imports: nemeton
(>= 0.162.0)`. Spec 039 close (cœur + app). Résidu ouvert : recalibrage terrain des
bornes d'adéquation de `regen_rank_species` (validation de terrain à venir).

### 2026-07-16 — v0.161.0 : normalisation 0-100 de tous les indicateurs, R6 à la source (spec 038)

Réponse au brief app `brief-nemeton-normalisation-r6.md` : *« intégrer tous les
indicateurs au score, donc normaliser dès le calcul »*. R6 (sensibilité micro) et
R7 (gel) manquaient au score de famille (`create_family_index` ne prenait que
R1-R5). Cause : `normalize_indicator()` a un **repli naïf** `clamp(0,100)` ; la
reGénération persiste `sensibilite` = **z-score projet-relatif non borné** que l'app
injectait dans `indicateur_r6_sensibilite` → mutilé par le clamp.

Décision **2.a (normaliser à la source)** retenue (recommandation du brief) :

- **`regen_sensibilite()`** (`R/regen_engines.R`) persiste `sensibilite_score`
  borné 0-100 (haut = favorable), via le helper `.regen_sensibilite_score()` qui
  réutilise la formule ET les échelles `.MICRO_BOUNDS$r6` de
  `indicateur_r6_sensibilite()` (source unique) sur les mêmes ΔT°max/ΔVPD. Calculé
  chemin engine (après le z-score) et chemin precomputed (dérivé si absent, porté
  verbatim si fourni). Le z-score `sensibilite` reste la base du **rang**.
- **`normalize_indicator()`** (`R/normalization.R`) : cases explicites
  R6 (`indicateur_r6_sensibilite`/`R6`/`sensibilite_score`) et R7
  (`indicateur_r7_gel`/`R7`) → passthrough clamp, **sans inversion** (≠ R5/T3).
- **Filet 2.c** : registre `.NORMALIZE_NATIVE_0_100` (23 indicateurs 0-100 natifs) ;
  tout indicateur **connu** (`get_all_column_names()`) tombant au repli naïf sans y
  être déclaré émet un `cli_warn` → détecte les futurs oublis. Test de couverture :
  aucun des 31+ indicateurs n'avertit.

Rétro-compatible (z-score/rang inchangés, aucun indicateur renormalisé
différemment). Tests : `test-regen-engines.R` +4 (score borné, monotone, NA-safe,
verbatim), `test-normalization.R` +6 (R6/R7 bornes+direction, couverture, garde).
Spec `specs/038-normalisation-indicateurs/`. **Suivi app** (règle 11, après release
cœur) : injecter `sensibilite_score` + intégrer R6/R7 au score — brief §5.

### 2026-07-15 — v0.160.0 : accesseurs point E-OBS pour les graphiques au clic (spec 036)

Livraison cœur de la [spec 036](specs/036-eobs-click-graphs/spec.md) — la carte
« Contexte régional (E-OBS) » (onglet reGénération) n'affiche qu'**une couleur par
maille** (la pente estivale) ; ces accesseurs rendent la donnée **sous** la
couleur, à la maille cliquée. Trois fonctions exportées, `R/eobs_click_series.R` :

- `eobs_summer_series(stack, point)` → `data.frame(year, value)` : extrait la série
  estivale par année au point (graphes 1-3 : série+tendance, anomalies,
  distribution). NA-safe hors emprise, ré-ordonné par année, accepte un `sf` POINT
  ou `c(lon, lat)` (le clic leaflet).
- `eobs_monthly_climatology(daily, point, var, years)` → `data.frame(month=1:12,
  value)` : climatologie mensuelle P/T pour le **diagramme ombrothermique**
  (Gaussen-Bagnouls, graphe 4). Précip = cumul mensuel moyenné inter-annuel ;
  température = moyenne mensuelle. Nuance documentée : Gaussen exige la T **moyenne**
  (`tg`), le `.nc` de contexte est la T **max** (`tx`) — option A (acquérir `tg`)
  recommandée, option B (`tx` proxy majorant la saison sèche) tolérée si étiquetée.
- `eobs_trend_fit(series)` → `list(slope_decade, intercept, r2, p_value, n)` : pente
  **par décennie** (= 10× la pente OLS annuelle) + qualité d'ajustement, pour la
  droite de tendance du graphe 1. Cohérence carte↔graphe vérifiée par test :
  `slope_decade == 10 * .eobs_ds_slope` (la pente closed-form de la carte).

Chemin PUR (extraction terra au point), aucune acquisition — 31 tests offline
(`test-eobs-click-series.R`). Feat mineur, rétro-compatible.

**Suite — 2026-07-16 : spec 036 close côté app.** Brief app rédigé
(`brief-nemetonshiny.md`, PR #329) puis **implémenté** : clic
`input$context_map_click` → modale à 4 graphes plotly, réutilisant l'existant app
(`.regen_load_eobs_buffered` pour les stacks estivaux, `regen_eobs_cached_nc` pour
le `.nc` quotidien plein-année), avec le seul ajout d'acquisition `tg` (température
moyenne pour le Gaussen exact, sur le modèle de `regen_fetch_eobs_rr`). Livré
**nemetonshiny@0bebc6d7 (v0.107.0)** sur cœur **nemeton v0.160.0**. Spec 036 close
(cœur + app) ; plus aucun reste sur ce chantier.

### 2026-07-15 — v0.157.1 : bruit console du moteur reGénération

Un run de l'app (`run_app(language = "fr")`, projet `20260701_204501_ltcp`)
faisait cracher 4 fois dans la console un **avertissement** `Ignoring unexpected
precomputed columns` listant une vingtaine de noms (tous les indicateurs + `geom`
+ ids). Ça ressemblait à un problème alors que c'est le fonctionnement **normal** :
l'app passe le `sf` résultat complet à `regen_bilan_hydrique()` /
`regen_sensibilite()`, et `.regen_attach_precomputed()` (`R/regen_engines.R`)
n'attache que les colonnes de forçage de CE moteur (`.REGEN_COLS_HYDRIQUE` /
`.REGEN_COLS_EXPO`), ignorant le reste par conception. Rétrogradé `cli_warn` →
`cli_inform` et rendu concis : rapporte les colonnes **retenues** + le décompte
ignoré, sans dérouler la liste. Aucun test ne ciblait ce message (les
`expect_warning` de `test-regen-engines.R` portent sur `stand-type default`).
Diagnostic de session : les autres messages de ce run (`[minmax]`, `dbDataType`
S4, `colors() outside color scale`, downloads de polices, `point k/30`) sont tous
cosmétiques ou attendus — voir mémoire `project_regen_cache_dirs`.

### 2026-07-14 — v0.157.0 : `run_memory_capped()` — FORDEAD ne peut plus emporter la session

RStudio est **reparti à l'OOM à 15h37**, cette fois en plein FORDEAD (le moteur
reGénération, démarré à 15h27, a été tué avec — d'où les répertoires `biljou/` et
`meteoland/` vides du projet Reconfort : ce n'était pas un bug, c'était le kill).

Rappel du mécanisme : `systemd-oomd` ne tue pas le processus fautif, il tue le
**scope**. RECONFORT était protégé depuis la v0.155.0 parce que son Python est un
**sous-processus** (`conda run python`) — plafonnable dans un cgroup. FORDEAD non :
son Python vit dans l'interpréteur **embarqué** de reticulate, et les moteurs
reGénération sont du R pur. Leur mémoire *est* celle du process R. **Il n'y a rien
à plafonner en in-process** — il faut sortir le travail dans un process enfant.

`run_memory_capped(fun, args, db_url, progress_path, progress_callback, memory_max)`
exécute une fonction exportée du cœur dans un enfant `Rscript` placé dans un cgroup
transitoire. Deux arguments ne traversent pas la frontière de process et sont
reconstruits dans l'enfant : `con` (→ `db_url`, l'enfant ouvre la sienne) et
`progress_callback` (→ `progress_path` ; l'enfant écrit le format exact de l'app,
le parent *tail* le NDJSON et **rejoue** chaque événement dans le callback fourni
— donc **les push ntfy survivent**).

**Découverte de mesure — le plafond v0.155.0 était à moitié inefficace.** Sur une
machine avec swap (celle-ci en a 8 Go), `MemoryMax=` seul **ne tue pas** : le
cgroup déborde dans le swap et *rame*. Mesuré : 2,4 Go écrits sous un plafond de
64 Mo n'ont jamais été tués en 60 s. Et ce thrashing est précisément la pression
système que `oomd` surveille — le plafond risquait donc de *provoquer* le kill de
scope qu'il devait empêcher. Correctif : `MemorySwapMax=0` dans
`.reconfort_cap_memory()`, donc **aussi pour RECONFORT**. Le swap refusé, l'enfant
est SIGKILL net (exit `-9` vu de processx, `137` vu d'un shell).

Second piège rencontré, noté pour la suite : un test qui alloue avec `numeric(3e8)`
ne prouve rien — `calloc` mappe la page zéro partagée, les pages jamais écrites ne
sont jamais faultées, le cgroup voit ~0. Il faut **écrire** la mémoire (`runif`).

- Livré : `R/isolate.R`, `MemorySwapMax=0`, 26 tests (dont un kill de cgroup réel).
- Dépendance : `processx` (Suggests) — surveiller l'enfant sans bloquer la
  remontée de progression.
- Côté app : `specs/008-suivi-sanitaire/brief-nemetonshiny-fordead-capped.md`
  (⚠️ y est signalé le piège du callback composite : l'enfant écrivant déjà le
  fichier de progression, rejouer le composite dupliquerait chaque ligne NDJSON —
  ne rejouer que la partie ntfy).
- **Prochaine étape** : appliquer le brief côté `nemetonshiny`, puis un run réel
  sous surveillance mémoire.

### 2026-07-14 — v0.156.0 : `scratch_dir()` configurable (contrainte disque à l'échelle département)

Conséquence directe de l'allègement mémoire de la v0.155.0 : les intermédiaires
qui étaient en RAM sont désormais sur disque, et **le volume croît avec
pixels × dates**. Mesuré : 798 Mo pour 0,89 Mpx × 115 dates (zone 9).
Extrapolé à un département (~67× l'emprise) : **plusieurs dizaines de Go**.

`tempdir()` n'est pas un bon défaut à cette échelle (petite partition racine,
parfois tmpfs = en RAM, ce qui annulerait le bénéfice). D'où `scratch_dir()` :
`options(nemeton.scratch_dir=)` → `NEMETON_SCRATCH_DIR` → `tempdir()`.
`run_reconfort_dieback()` avertit en amont si l'espace libre est manifestement
insuffisant, au lieu de mourir sur un disque plein à mi-parcours.

**A/B mesuré sur la construction des stacks** (mêmes 115 dates, zone 9) :

| | temps | RAM |
|---|---|---|
| avant (tout en RAM) | 2 min 44 s | 1309 Mo |
| après (streaming) | 4 min 02 s | 742 Mo |

Le streaming coûte donc ~45 % de temps sur cette phase — **mais à l'échelle
département l'ancienne version ne tournait pas du tout** (~90 Go de RAM
nécessaires). Ce n'est pas un ralentissement, c'est un déblocage.

### 2026-07-13 — v0.155.0 : le sous-processus IOTA2 tourne sous plafond mémoire

Suite de v0.154.1. Le bug iota2 est corrigé, mais **la structure du risque
restait** : le job tournait dans le même cgroup que l'app, donc un dépassement
faisait tuer *toute la session* par `systemd-oomd`, pas le job.

Le plafond se pose **côté cœur** (et non côté app comme envisagé d'abord) :
c'est `nemeton` qui lance le sous-processus IOTA2 (`.reconfort_run_py()`,
`R/reconfort_ingest.R`), donc c'est là qu'il protège tout le monde — y compris
un usage hors Shiny. `systemd-run --user --scope --property=MemoryMax=…`,
défaut 70 % de la RAM, `options(nemeton.reconfort_memory_max=)` pour forcer,
no-op silencieux si systemd est absent (non-Linux, conteneur, CI).

Un OOM devient ainsi **un échec de tâche ordinaire** (exit non nul → « map
production failed ») au lieu d'une catastrophe de session.

**Validé en réel** : scope à 21 Go créé par le cœur, run complet, `completed`,
546 s, cartes finales produites.

**Reste côté app** : `specs/008-suivi-sanitaire/brief-nemetonshiny.md` —
présenter l'OOM (exit 137) avec un message dédié plutôt que le brut, et cesser
de retenir les rasters du projet (~14 Go) en mémoire pendant un run.

### 2026-07-13 — v0.154.1 : fix OOM RECONFORT (défaut iota2 #11, chunk 0 falsy)

Un diagnostic RECONFORT lancé depuis l'app a fait tuer la session R entière
(RStudio + terminaux) par `systemd-oomd` : 26 Go de pic, dont > 20 Go pour la
seule classification IOTA2 sur une UGF de 930×952 px.

**Cause racine** (trouvée en lisant le code d'iota2, pas le nôtre) :
`image_classifier.py:644` ne découpe le masque de région sur le bloc courant que
sous `if ... and targeted_chunk:`. `targeted_chunk` étant l'**indice** du bloc,
`0` est *falsy* → le bloc 0 garde un masque pleine taille → abort OTB
(BandMath, dimensions incompatibles). D'où le `number_of_chunks = 1` du
pipeline : seule valeur où ça coïncide par accident, mais qui oblige à charger
toute la pile de features multi-dates d'un coup.

**Livré** : patch #11 dans `repair_iota2_env.sh` (idempotent, avec backup) +
`run_reconfort_dieback()` qui dérive le nombre de blocs de la hauteur du raster
(~240 lignes/bloc). Env non patché → détection, repli sur 1 bloc, avertissement
explicite (pas de régression silencieuse).

**Validé en réel** (zone 9, S2 2025, env patché) : 10/10 phases, statut
`completed`, 819 s, **pic 11,3 Go** (vs > 20 Go), cartes finales produites.

Deux fausses pistes écartées **par la mesure**, à ne pas re-tenter : le budget
RAM d'OTB (`iota2_resources.cfg`, `classifications: ram`) n'a aucun effet, et
`nb_cpu` (12 → 4) non plus.

**Prochaine étape** : côté `nemetonshiny`, le job tourne dans le même scope
systemd que l'app — quand il déborde, oomd tue *tout*. Un brief est à écrire
pour lancer le worker RECONFORT dans son propre cgroup plafonné, afin qu'un
dépassement tue le job seul, avec une erreur propre dans l'UI.

### 2026-07-12 — v0.154.0 : carte bivariée E-OBS en quinconce 5×5 (couleurs L'IF n°49)

Demande en séance : coller la bivariée à la figure de référence « L'IF n°49 »
(mêmes classes / mêmes couleurs). Mesure de l'image : dégradé **continu** (126/166
transitions = 1 pixel = 1 couleur), pas de classes discrètes → choix de
granularité soumis (3×3 / 5×5 / continu), retenu = **5×5 (25 classes)**. Couleurs
échantillonnées directement sur la figure aux 25 centres de cellule. Cœur :
`.EOBS_BIVARIATE_N=5`, palette+labels 25, helpers généralisés N-tiles
(`.eobs_ds_breaksN`/`.eobs_ds_classN_rast`), `eobs_downscale_bivariate` code
`(ct-1)*5+cp` (1-25), `meta$palette$ncol=5` pour une légende carré 5×5 côté app.
Brief app MAJ (§8 : légende carré, pas liste de 25). Rappel du même échange : le
neutre central « trou » de la 3×3 (v0.153.2, #A79E8C) n'a plus lieu d'être — la
5×5 n'a pas de classe grise. Ajout demandé ensuite : **pointillés blancs 0/0**
sur la légende (comme la figure) ; cœur expose `meta$palette$zero=list(tmax,precip)`
(fraction [0,1] ou NA, helper `.eobs_ds_zero_pos`), l'app trace les traits.
Puis question « pourquoi quantile et pas absolu comme L'IF 49 ? » → **bascule en
bornes ABSOLUES fixes** (choix utilisateur). Diag données projet : T°max
+1.0…+1.9 °C/déc et précip -77…-17 mm/déc = **partout chaud & sec** ; le quantile
fabriquait un faux contraste. Défauts absolus ancrés sur 0 : T°max
`c(0,0.4,0.8,1.2)`, précip `c(-80,-40,0,40)` ; couleurs comparables entre projets,
massif homogène → quasi unicolore (la réalité). 0 devient une borne → pointillés à
0.2 (T°max) et 0.6 (précip). Tests 123 verts.

### 2026-07-12 — v0.153.2 : fix gel R7 (MNT parcellaire → auto-source régional)

Signalé sur le projet reconfort : le moteur gel se skippe (« Tmin indisponible
(meteoland/SAFRAN). R7 absent du radar »), console `meteoland_daily_grid(): too
few SAFRAN pseudo-stations`. Diag (inspection cache réel) : l'app passe le MNT
LiDAR parcellaire (`lidar_mnt_mosaic.tif`, ~5 km) ; `build_safran_stations()`
écarte les pseudo-stations SAFRAN hors emprise MNT (elevation NA) → sur un buffer
25 km, `< 5` stations survivent → abort. Même classe que le KED sur MNT trop
petit (v0.152.0). Fix : `.meteoland_resolve_dem()` auto-source un MNT régional
grossier (WMS IGN 250 m) couvrant le buffer quand le MNT fourni couvre trop peu
de mailles SAFRAN, réutilisé pour altitudes + grille ; câblé dans
`meteoland_daily_grid()` (voie R7) et `eobs_downscale(engine="meteoland")`.
Signatures inchangées, 3 tests de non-régression. Note annexe (même échange) :
les « trous » de la carte bivariée ne sont PAS des NA — masque NA identique à
tx/rr (21,4 %, coins du buffer) ; c'est la classe centrale 5 « Stable »
(9950 cellules) qui se lisait comme du vide en semi-transparence. Corrigé dans
la même release : couleur centrale gris pâle #C9C9C9 → neutre taupe #A79E8C
(lisible comme une couleur pleine à toute opacité).

### 2026-07-12 — v0.153.1 : fix diagnostic RECONFORT (AOI à anneau dégénéré)

Signalé en séance : le diagnostic RECONFORT s'interrompt à l'étape *tiles*
[4/10] avec `Loop 2 is not valid: Edge 13 is degenerate (duplicate vertex)`
(via `wk_handle.wk_wkb()`), remontant de `nemeton::run_reconfort_dieback()`.
Cause : la zone du projet porte un anneau dégénéré (sommet dupliqué).
`reconfort_aoi_tiles()` résout l'emprise contre la grille MGRS **GeoJSON
(EPSG:4326)** → `st_union`/`st_intersects` sous **s2** → abort. Le chemin
indicateurs (intersection BD Forêt) réparait déjà ce cas ; la résolution des
tuiles non. Fix : réparation `st_make_valid()` + réessai dans
`reconfort_aoi_tiles()` (même idiome), **et** AOI rendue valide une fois à la
source dans `run_reconfort_dieback()` (protège masque/clip/vérité terrain en
aval). Test de non-régression ajouté. Reproduit hors fix : l'anneau dupliqué
abortait bien s2 avec l'erreur exacte du log.

### 2026-07-12 — v0.153.0 : `eobs_downscale(var="rr")` + carte bivariée fine

Complète le contexte régional E-OBS (brief `brief-nemeton-eobs-downscale-rr`).
Précision demandée en séance (capture de la figure « L'IF n°49 ») : la 2ᵉ carte
voulue est la **bivariée** (T°max × précip, rouge = réchauffement + assèchement),
mais **downscalée à la résolution UGF**, pas le semis E-OBS grossier de
`tendances_estivales_eobs`.

- **`var = "rr"`** : mêmes rails KED que `tx` (plus d'`out_of_scope`). Helper
  `.eobs_ds_labels(var, statistic)` : `rr` → `mm/decade`, `sense =
  "dry_unfavorable"` (bas = rouge), `reliability = "low"` (pluie↔altitude bruitée,
  orographique — contexte régional seulement). `rr` ignore meteoland (température),
  force KED. `meta$reliability` ajouté aux deux variables.
- **`eobs_downscale_bivariate(tx, rr, …)`** (export) : downscale les deux
  tendances (MNT de contexte auto-sourcé partagé) puis croise en classes **1-9**
  (`(classe_tmax-1)*3 + classe_precip`, chaud&sec = 7 = rouge, frais&humide = 3 =
  bleu — codage identique à `tendances_estivales_eobs`). Sortie : `SpatRaster`
  entier `classe_bivariee` + `meta$palette` (9 couleurs/libellés FR) + `meta$breaks`
  + métas composantes `tx`/`rr`. Validé en local (synthétique).
- Contrat `list(raster, meta)` inchangé. Brief app mis à jour (2ᵉ couche + carte
  bivariée + sélecteur).

### 2026-07-12 — v0.152.0 : MNT de contexte auto-sourcé pour `eobs_downscale` (WMS IGN)

Débloque la carte contexte régional E-OBS sur projet réel (brief
`brief-nemeton-eobs-downscaling-dem`). **Cause racine** : le KED extrait les
covariables terrain AUX POINTS E-OBS, donc l'emprise du MNT borne `n_points` — un
MNT parcellaire (~4-5 km) ne recouvre qu'~1 maille E-OBS (~11 km) → n_points=1,
insufficient_data, malgré buffer 25 km. (Ce n'était PAS un CRS cassé : le MNT
BD ALTI porte un WGS84 valide.)

**Option A1 retenue** (recommandée par le brief) : `dem` devient optionnel ;
`eobs_downscale` auto-source une élévation GROSSIÈRE sur le buffer depuis le **WMS
IGN Géoplateforme** (`ELEVATION.ELEVATIONGRIDCOVERAGE`, France, sans auth) —
réutilise `get_layer_service("dem","FR")` (fonction cœur) et le patron GetMap de
l'app `download_ign_dem`. **Validé en réel** (AOI Besançon, buffer 25 km) :
n_points 1 → **33**, status ok, tendance 3 °C/décennie exacte, sortie 2154,
~200 m. Inutile de viser du 5 m sur 25 km : le KED agrège à `max_cells`, défaut
`context_res_m = 250`.

**Décision « MNT trop petit » robuste** : pas une fraction de recouvrement
géométrique (trop sensible), mais un **comptage de mailles E-OBS** — le MNT n'est
le facteur limitant que si le buffer contient ≥ `min_points` mailles mais que
l'emprise du MNT n'en couvre pas assez. Buffer minuscule → E-OBS limitant, on
garde le MNT fourni (KED → `too_few_cells`, pas de téléchargement inutile).

**Robustesse CRS** : `eobs` sans CRS → EPSG:4326 (E-OBS toujours lon/lat) +
avertissement, au lieu de n_points=0 silencieux. **Replis** : `meta$reason`
distingue `dem_too_small` / `no_dem` / `too_few_cells` ; `meta$dem_source` =
provided/autoscaled/autoscaled_small_dem. **Contrat `list(raster, meta)`
inchangé**. Tests : branches de résolution (mock download), robustesse CRS, WMS
réel (`skip_if_offline`). Côté app : `addRasterImage` + opacité dès `status=ok`.

### 2026-07-12 — v0.151.0 : moteur meteoland RÉEL + Tmin journalier alimentant R7 (P4)

Clôt le chantier microclimat P4. Pascal a installé **meteoland 2.2.7** sur le PC :
l'interpolation, laissée en TODO à la v0.150.0 (leçon gstat — je ne livre pas
d'API que je ne peux valider), a pu être **écrite ET validée de bout en bout sur
vraies données** avant merge.

**Découvertes API meteoland (lues, pas présumées)** :
- `with_meteo()` attend un sf **long** (une ligne par station × jour) :
  `dates, stationID, elevation, MinTemperature, MaxTemperature, Precipitation, …`.
- `interpolate_data()` accepte un `stars` **régulier** en **CRS projeté** (Lambert-93
  natif OK) — mais **pas** une grille reprojetée (devient curviligne). D'où : grille
  cible dérivée du MNT natif, 3 attributs séparés (`elevation`/`slope`/`aspect`),
  jamais un `st_transform` du raster.
- Hors enveloppe convexe des stations → `interpolate_data()` abort ; on passe
  `ignore_convex_hull_check = TRUE` + échantillonnage stations sur `buffer + 8 km`.
- `terra::rast()` ne convertit pas un `stars` multi-dimension : `split(d[var], "date")`
  puis `terra::rast()` pour la pile journalière.

**Livré** :
- `eobs_downscale(engine = "meteoland")` **tourne** (Tmax estival : interpolation
  journalière → summarise annuel `max` → réduction KED-sémantique). Contrat de
  sortie identique à KED. Args opt-in `calibrate` (calibration LOO) et `cv`
  (validation croisée → `meta$cv = list(r2, mae_tmin, mae_tmax)`). Repli KED si
  meteoland/GéoSAS/densité KO. Vérifié en réel : `engine = "meteoland"`, 25
  pseudo-stations, sortie 2154.
- `meteoland_daily_grid()` (export) — **raster Tmin journalier** (`terra::time()`
  posé, CRS MNT) qui alimente `indicateur_r7_gel(tmin = …)` sur données réelles.
- **Params SAFRAN Tmin/Tmax** : noms EXACTS lus dans l'EDR `safran-isba` =
  **`TINF_H_Q`/`TSUP_H_Q`** (min/max des 24 T° horaires) — **pas** `TINF_Q`/`TSUP_Q`
  supposés dans le brief. `.biljou_forcing_safran(params=)` + jeu meteoland dédié.
- Tests : transforms purs (`.safran_to_meteoland`, `.meteoland_meteo_sf`) sur CI ;
  glue meteoland réelle sous `skip_if_not_installed` (mock `.biljou_forcing_safran`,
  vrai run interpolateur). 63 pass / 0 fail sur `test-eobs-downscale.R`.
- Brief app : `specs/027-regeneration-microclimat/brief-nemetonshiny-r7-gel-microclimat-p4.md`
  (R7 radar + producteur Tmin opt-in/caché + carte gel + `meta$cv`).

### 2026-07-11 — v0.150.0 : R7 gel tardif + rail SAFRAN du moteur meteoland (P4)

Deux briques du chantier microclimat P4 (`brief-meteoland-safran-p4`).

**R7 — gel tardif** (`indicateur_r7_gel`, famille R étendue R1…R7). Décision
Pascal : R5 (dépérissement) et R6 (sensibilité) étant pris, le gel va en **R7**
(pas R6). Croise une série Tmin journalière × débourrement → gelées printanières
post-débourrement. Conditionnel (NA/skip sans `tmin`), sens haut = faible risque
(pas d'inversion, ≠ R5). Testé avec Tmin synthétique (UGF exposée < UGF douce,
gel avant débourrement ignoré, skip sans donnée). CLAUDE.md : ligne R mise à jour
(R6 + R7 y manquaient).

**`build_safran_stations()`** — répond à la question « meteoland a-t-il des
stations ? » : **SAFRAN suffit**. Réanalyse ~8 km → chaque maille = pseudo-station
(série + altitude MNT), acquise via `.biljou_forcing_safran` **déjà écrit pour
BILJOU** (pas de source neuve). Testé par mock du `fetch`.

**Choix assumé sur meteoland** : l'interpolation meteoland elle-même **n'est pas
écrite**. meteoland n'est ni exécutable en CI ni ici de façon significative
(données synthétiques ≠ structure attendue). Après la leçon gstat (v0.149.0 : du
code krigeage non exécutable localement avait 2 bugs, rattrapés par le runner CoV
qui, LUI, installe gstat), je refuse d'expédier des appels d'API meteoland que je
ne peux valider nulle part. Le moteur `engine = "meteoland"` construit donc les
stations, borne la densité, puis **retombe proprement sur KED** (`engine_fallback`),
avec l'interpolation en TODO explicite pour une session sur données réelles
(patron microclimf). `meta` gagne le slot `cv`.

> **Reste P4** : l'interpolation meteoland (create_meteo_interpolator →
> interpolate_data par année → summarise → stack → reduce), à écrire et valider
> sur données réelles chez Pascal, plus l'extension SAFRAN Tmin/Tmax (lire les
> noms exposés par la collection EDR `safran-isba`). Câblage app R7 (radar) +
> carte gel : brief app séparé.
> — **✅ RÉSOLU en v0.151.0** (meteoland installé) : interpolation écrite/validée,
> SAFRAN Tmin/Tmax (`TINF_H_Q`/`TSUP_H_Q`), brief app livré. Voir entrée du 2026-07-12.

### 2026-07-11 — v0.149.0 : downscaling E-OBS en raster fin (`eobs_downscale`)

**Demande app** (`brief-nemeton-eobs-downscaling`) : la carte « Contexte régional
(E-OBS) » de reGénération affiche un semis de points (centres de mailles ~11 km) ;
l'utilisateur veut une **surface continue** fine, façon FORDEAD/FAST.

**Livré** : `R/eobs_downscale.R` — `eobs_downscale(var, eobs, dem, aoi, engine=, …)`.
Transforme la grille E-OBS en `SpatRaster` fin par **régression-krigeage** (dérive
`lm(valeur ~ dem + slope + northness + twi)` + krigeage des résidus). v1 = `tx`
seul (signal altitudinal ; `rr` hors scope). Contrat `meta` figé pour l'app
(`status`/`engine`/`method`/`crs`/`unit`/`palette`/`n_points`). Garde-fous :
grille bornée `max_cells`, cache `.tif`, dégradation propre.

**Décision `engine=` (demandée par Pascal en cours de session)** : interface
unique, **deux moteurs, contrat identique** (brief microclimat §8). `"ked"`
(défaut, gstat/automap en Suggests ; sans eux → repli `trend_only`) et
`"meteoland"`. Réserve honnête : **meteoland ne consomme pas une tendance déjà
réduite** (interpolateur station/journalier) — le brancher = refonte per-année
(chantier microclimat P4). La branche `"meteoland"` est donc un **rail gardé qui
retombe sur KED** (absence ou stub) sans jamais casser la sortie. Deux corrections
au brief microclimat (daté v0.15.1) : cœur **GPL-3** (la GPL de meteoland n'est
plus un blocage), et `r5` = dépérissement (le « r5_gel » proposé n'est pas libre).

**Testé** : 33 tests (chemin KED trend-only complet sans gstat — grille/CRS/unité,
cohérence physique altitude→froid, `rr` hors scope, repli meteoland, cache,
helpers ; chemin KED-gstat skippé sans gstat). Vérifié bout-en-bout : tendance
0,3 °C/an → 3 °C/décennie sur la grille fine. Suite : **8961 pass, 0 fail, 0
error**. Bump mineur → **0.149.0**.

> **Reste app** : plancher `Imports: nemeton (>= 0.149.0)`, remplacer le semis de
> points de `output$context_map` par `leaflet::addRasterImage(res$raster,
> opacity = input$context_opacity)` + légende dérivée de `res$meta$palette`
> (curseur, fonds, emprise UGF déjà en place — cf. brief §« Suite côté app »).

### 2026-07-10 — v0.148.0 : verrou de projet multi-utilisateurs (API cœur)

**Demande app** (`brief-core-project-lock`) : `nemetonshiny` va tourner déployé en
serveur multi-utilisateurs. Décision produit — **un projet ouvert est verrouillé
en édition sur un seul utilisateur, les autres l'ouvrent en lecture seule**. Le
cœur fournit l'API (règle #1 : aucun accès données dans l'app), l'app câble.

**Livré** : `R/project_lock.R` — `project_lock_acquire/heartbeat/release/status`,
migration `0008_project_lock` (pg + sqlite). Verrou **en table**, pas
`pg_advisory_lock` (l'app ferme sa connexion par opération → un advisory lock
serait relâché aussitôt). Heartbeat périodique + péremption par TTL évaluée à la
lecture contre l'horloge DB. Ré-entrance, vol de verrou périmé (`stolen`),
transaction + `FOR UPDATE` (PostgreSQL) pour l'exclusion sous concurrence.

**Deux écarts au brief, assumés** :
- Table `project_lock` **non qualifiée** (le brief écrivait `nemeton.project_lock`),
  car aucune table du repo n'utilise de schéma `nemeton.` — le code fait foi.
- `project_lock_status()` retourne `NULL` **seulement si libre** (le brief disait
  « NULL si libre ou périmé »), sinon le détenteur + `stale`. C'est ce qu'exige le
  test « distingue libre / tenu-frais / tenu-périmé » : un `NULL` sur périmé
  empêcherait de distinguer périmé de libre.

**Piège rencontré et corrigé** : RSQLite lie une liste de paramètres non-nommés
dans l'**ordre d'apparition textuelle** des placeholders, pas par leur numéro.
Un `$2` (ttl / SET) placé avant `$1` (WHERE) recevait donc la mauvaise valeur →
requêtes silencieusement vides. Corrigé : TTL interpolé (nombre validé), et tous
les `$n` renumérotés dans l'ordre textuel (satisfait aussi PostgreSQL, qui lie par
numéro). 52 tests (SQLite en mémoire + fichier partagé pour la visibilité
inter-connexions + intégration PostgreSQL). Bump mineur → **0.148.0**.

**Chantier clos (cœur + app)** :

- [x] Verrou d'édition projet multi-utilisateurs (table `project_lock` — **non
      qualifiée**, cf. écart au brief ci-dessus ; API
      `project_lock_acquire/heartbeat/release/status`, migration 0008, `db_migrate`)
      — cœur **v0.148.0**, app **nemetonshiny@e6ffb787** (v0.102.0, garde
      `deny_if_readonly` généralisé à tous les modules mutants). — 2026-07-11

### 2026-07-10 — v0.147.3 : ERA5, rayonnement négatif (trouvé par le run réel)

**Validation terrain de la spec 035 : concluante.** Run sur
`20260701_204501_ltcp` (30 UGF, cache PAI). `njstress` passe de **1 valeur
distincte** (142,5 j partout) à **≥ 10** (145,5 → 159) ; `deb_stress` de 1 (122)
à une plage 111–118 ; `rew_min` de 2 valeurs à un continuum. Le sol SoilGrids et
le `lai_max` P90 portent bien la variance inter-UGF, comme prévu par la spec.

**Et le run a livré un bug.** L'UI a affiché :

> `microclimf: -0.0448426522703349 outside range of typical shortwave radiation
> values. Units should be W / m^2`

ERA5 stocke rayonnement et précipitation en **cumuls** ; la dé-accumulation par
`mcera5` produit de minuscules négatifs là où le flux est nul (la nuit). Artefact
numérique, pas un signal — mais rien ne le bornait. `.rsen_forcage_era5()` borne
désormais `swdown`/`difrad`/`precip` à zéro (`.rsen_clamp_flux()`).

Le correctif protège **deux** chemins : `.biljou_forcing_era5()` réutilise le même
forçage, où un `swdown` négatif se propage dans `rg` puis `penman_pet()`. 5 tests.
Bump patch → **0.147.3**.

> **Ce bug n'était visible que grâce à B3.** L'avertissement est émis par
> `microclimf` **dans le worker `future`** : avant l'observabilité livrée en
> `nemetonshiny` v0.101.1, il mourait sur le `stderr` du processus fils. B3 a
> payé son coût dès le premier run réel.

### 2026-07-10 — v0.147.0 : bilan hydrique spatialisé par UGF (spec 035)

**Symptôme.** `regen_bilan_hydrique()` renvoyait la même chose pour les 30 UGF du
projet `20260701_204501_ltcp` : `njstress` = 142,5 j et `deb_stress` = 122
partout ; `istress` et `rew_min` ne prenaient que **2** valeurs.

**Diagnostic (lecture du moteur, pas supposition).** `biljou_run_grid()` ne
recopie `lon`/`lat` qu'en métadonnées ; `biljou_run()` est une fonction pure de
`(meteo, soil, lai_max, forest_type, budburst, leaf_fall)`. Le sol était uniforme
(`build_biljou_soil()` → un objet), le `lai_max` scalaire (défaut 5 : **le PAI
calculé n'était jamais consommé par BILJOU**), et la maille SAFRAN fait 8 km —
les 30 centroïdes tombent dans **2** mailles, d'où les 2 valeurs. Les comptages
entiers de jours absorbaient l'écart de 0,3 %.

**Livré (cœur).** `awc_saxton_rawls()` (PTF Saxton & Rawls 2006, R pur),
`ewm_depuis_soilgrids()` (réserve utile mm/UGF, SoilGrids 250 m + PTF),
`lai_max_depuis_pai()` (P90 du PAI, pas la moyenne — `biljou_lai()` traite
`lai_max` comme un *plateau*), `build_biljou_soil(source = "soilgrids")` →
liste d'objets `biljou_soil` nommée par id. 30 sources `soilgrids_*` dans
`FR.json`. Rétrocompatibilité stricte (`source = "uniform"` + `lai_max` scalaire).

**Fix de correction.** `biljou_run_grid()` n'indexe que les *listes* : un vecteur
per-UGF partait **entier** à chaque point. Sur résineux, `rep(lai_max, ndays)`
donnait une série de `n × ndays` valeurs et le LAI des UGF défilait jour après
jour — sans erreur ni warning. `regen_bilan_hydrique()` convertit désormais tout
vecteur en liste nommée par id et refuse les longueurs invalides. La doc
annonçait ce contrat ; le code ne l'honorait pas.

**Décisions (spec 035).** D1 : le **TWI ne dérive pas l'`ewm`** — convergence
latérale ≠ capacité de stockage, BILJOU est 1D, et le TWI alimente déjà R3 en
direct (double comptage `ewm → BILJOU → njstress → R3`). D3 : Saxton & Rawls
plutôt que Tóth 2015 (non closed-form). ⚠ les transcriptions web de la PTF
(`-0.002` / `-0.15`) sont **fausses** — capacité au champ négative pour un sable ;
verrouillé par test.

**Vérifié avec le vrai moteur** : `njstress` passe de 1 à 3 valeurs distinctes sur
3 UGF ; l'UGF de référence (`ewm=150`, `lai=5`) reproduit exactement la valeur
v0.146.x. Bump mineur → **0.147.0**.

**Brief app livré** — `specs/035-bilan-hydrique-spatialise/brief-nemetonshiny.md`
(2026-07-10, aucun changement cœur). Quatre volets, mêmes fichiers.
**Spec 035 livrée INTÉGRALEMENT côté app** en quatre releases du 2026-07-10, sur
cœur `nemeton@0.147.x` inchangé. Plancher app `nemeton (>= 0.147.0)`, cycle dev
app `0.101.2.9000`. Aucun brief app spec 035 en attente.

**Briefs app livrés** :

- [x] **B1 — bilan hydrique spatialisé** — le PAI LiDAR caché alimente le `lai_max`
      par UGF de BILJOU (le garde-fou `is.null(grid)` sautait le calcul précisément
      quand le LiDAR HD était présent) ; agrégation en plateau P90 via
      `lai_max_depuis_pai()` au lieu d'une moyenne zonale ; réserve utile par UGF via
      `build_biljou_soil(source = "soilgrids")`. UI : `ewm` devient un override
      optionnel, champ `rooting_depth_cm`, phase moteur « Réserve utile (SoilGrids) ».
      App **v0.101.0** (`nemetonshiny@0337ed96`).
- [x] **B2 — restauration à l'ouverture d'un projet** — observateur `(projet, unités)`
      qui relit le cache disque en fast-path : aucun moteur (microclimf, biljouR, lasR)
      ne démarre. Purge du projet précédent ; alimente `app_state$regeneration_result`,
      que `mod_synthesis` consomme pour la perspective IA. App **v0.101.0**.
- [x] **B3 — observabilité du moteur** — journal disque en ajout seul
      (`cache/regeneration/engine.log`, JSONL) qui traverse la frontière du worker
      `future` et survit à sa mort (OOM) ; relais des entrées `error`/`warning` vers la
      console du processus principal ; cumul des avertissements du moteur au lieu de
      leur écrasement par le re-run fast-path ; échec de `.ntfy_send()` journalisé.
      App **v0.101.1** (`nemetonshiny@029abb6a`).
- [x] **B4 — lisibilité des overrides** — le moteur remonte le `lai_max` et la réserve
      utile réellement utilisés ; médiane + étendue par UGF affichées. Le repli
      silencieux SoilGrids → sol uniforme devient un avertissement UI + une entrée de
      journal. Section « Paramètres experts » repliée, badge « forcé ». Le champ
      « LAI max » est **conservé** (échappatoire hors LiDAR/S2, scénario sylvicole,
      LAI mesuré NDP 3). App **v0.101.2** (`nemetonshiny@3ac9edb2`).

**Validation terrain — ✅ CONFIRMÉE le 2026-07-10** (run réel sur
`20260701_204501_ltcp`, 30 UGF, cache PAI) :

- [x] **Le bilan hydrique est spatialisé.** `njstress` prend ≥ 10 valeurs distinctes
      sur les 15 premières UGF (145,5 → 159), `deb_stress` va de 111 à 118, `rew_min`
      de 0,0307 à 0,0487. Avant la spec 035 : `njstress` = 142,5 j **partout**,
      `deb_stress` = 122 partout, `istress`/`rew_min` à 2 valeurs (les 2 mailles
      SAFRAN de 8 km). Les quatre colonnes bougent désormais.
- [x] **B3 fonctionne.** Un avertissement émis par `microclimf` **dans le worker
      `future`** atteint l'interface (bandeau haut). Avant B3 il mourait sur le
      `stderr` du processus fils.

Restent non vérifiés (exigent une injection de panne) : les critères B3 « couper le
réseau pendant le forçage SAFRAN » et « tuer le worker pour observer le post-mortem ».

Le run a par ailleurs **révélé un bug cœur** : `microclimf` signalait un rayonnement
solaire négatif (−0,045 W/m²) issu de la dé-accumulation ERA5 → corrigé en **v0.147.3**
(`.rsen_clamp_flux()`). Sans B3, cet avertissement n'aurait jamais été vu.

**Une dette app relevée au passage** (hors périmètre du brief, à trancher) :

- `nemeton.regeneration_states` est en **écriture seule** : `db_save_regeneration()`
  insère (versionné), aucun `SELECT payload` n'existe dans le repo. Rien n'a été
  changé. **À trancher** : soit la table sert, et il manque un
  `db_load_regeneration()` ; soit c'est un journal d'archive, et il faut l'assumer
  explicitement. (La restauration B2 s'appuie sur le cache disque, pas sur la DB —
  la dette n'est donc pas bloquante.)

- **2026-07-10** — **spec 035 livrée intégralement côté app**, en quatre releases,
  sur cœur `nemeton@0.147.x` inchangé : **v0.101.0** (B1 bilan hydrique spatialisé
  + B2 restauration à l'ouverture, `0337ed96`), **v0.101.1** (B3 observabilité du
  moteur, `029abb6a`), **v0.101.2** (B4 lisibilité des overrides, `3ac9edb2`).
  Cycle dev app `0.101.2.9000`, CI verte à chaque release.
  Consomme du cœur 0.147.0 : `lai_max_depuis_pai()`, `build_biljou_soil(source =)`,
  `ewm_depuis_soilgrids()`.
  **Dette `pc$eobs` levée au passage** (`nemetonshiny@7f2e1816`), que le brief B2
  signalait « à traiter à part » : `run_regeneration()` passait `precomputed$eobs` à
  `microclimate_detect_years()`, or `load_regeneration_precomputed()` peuple
  `eobs_tx` et **jamais** `eobs` — la détection automatique des années échouait donc
  systématiquement dès que l'utilisateur n'avait pas saisi les deux années à la main.
  Le contrat du cœur (`eobs` = `SpatRaster` estival, une couche par année, agrégé
  JJA) est exactement celui d'`eobs_tx`.

- **2026-07-08** — reGénération : cache disque du PAI LiDAR livré côté app
  (`nemetonshiny@22713c93`, v0.100.14, cycle dev `0.100.14.9000`). Consomme
  `regen_sensibilite(pai_cache = ...)` du cœur 0.146.2. Clôt le second et dernier
  brief app du volet moteur spec 027 — le volet cœur 0.145/0.146.x était déjà journalé.

### 2026-07-09 — v0.146.5 : grille microclimf bornée mémoire (2ᵉ OOM, après le PAI)

**8ᵉ blocage.** Run réel en 0.146.4 : PAI OK en 2 dalles (~57 min, mémoire mini
17 Go, `pai.tif` caché ✅ — fix OOM PAI confirmé), **puis re-OOM systemd-oomd à
10:28** pendant microclimf. Cause : `runmicro()` alloue `ncellules × pas × ~11
sorties` ; à 2 m sur le massif (**3,4 M cellules**) → dizaines de Go. Mon e2e de
0.146.2 tournait sur 30×30 — jamais exercé le vrai massif.

Fix : agrégation de la grille de calcul microclimf sous `micro_max_cells` (défaut
5e4, override `options(nemeton.micro_max_cells=)`) → sur 3,4 M cellules, facteur 9
→ ~18 m/~42k cellules → microclimf ~1 Go. Le PAI caché reste à 2 m ; seul le calcul
est coarseé (per-UGF inchangé). Helper `.rsen_micro_agg_factor()`. Validé e2e
(agrégation forcée → microclimf tourne sur grille coarseé → sf correct). 111 pass.
Bump → **0.146.5**.

> **Le PAI est désormais caché** (`pai.tif`, 10:17) → le prochain run **saute le
> PAI** (plus de 57 min) : on itère vite. Prochaine relance : réinstaller 0.146.5,
> relancer → PAI sauté (cache) → ERA5 (2018 réutilisé) → microclimf à ~18 m (sûr)
> → `sensibilite.gpkg`.
>
> **Bilan = 8 blocages** : creds → 403 → soilparameters → trim/writeRaster/NaN →
> OOM PAI (v0.146.3) → locale ERA5 (v0.146.4) → **OOM microclimf (v0.146.5)**.

### 2026-07-09 — v0.146.4 : sélection ERA5 — repli indépendant de la locale

Suite à la question de Pascal (« les noms `era5_2018_2018_1.nc` sont-ils bons ? »).
Vérifié : **noms corrects, aucun renommage** — le cœur détecte `era5_2018_2018.nc`
(combiné) par suffixe `_<annee>.nc`. Mais au passage, découverte que le **repli
défensif** `list.files(...)[1]` supposait que le combiné trie avant les mensuels
('.' < '_') — faux en locale FR (`sort()` suit la locale). Durci : helper
`.rsen_era5_src()` qui prend le nom le **plus court** (le combiné) via `nchar()`,
indépendant de la locale. Chemin principal inchangé. 105 pass. Bump → **0.146.4**.

### 2026-07-09 — v0.146.3 : PAI parallèle borné mémoire (OOM systemd-oomd)

**7ᵉ blocage, sur run réel avec nemetonshiny 0.100.13 (pai_cache câblé).** Run lancé
16:37, mort à ~17:27 en phase PAI **sans rien produire**. Forensique décisive :
`journalctl` → `app-rstudio-88421.scope: Failed with result 'oom-kill'` — **`systemd-oomd`**
a tué le scope RStudio (il tue à ~50 % de pression mémoire soutenue). Le PAI parallèle
(v0.146.0, `half_cores()`=4 dalles COPC de front, 25 dalles ≈ 38 Go décompressées sur
31 Go RAM) a saturé la mémoire. Ce matin le PAI 4-dalles était passé de justesse ; ce
run a franchi le seuil oomd. **Mon défaut `half_cores()` est trop gourmand pour de
grosses dalles LiDAR.**

Fix : défaut `ncores=NULL` **borné mémoire** (~6 Go/dalle sur 40 % RAM, cap half_cores)
→ 2 dalles sur 31 Go au lieu de 4 ; + override `options(nemeton.pai_ncores=)` /
`NEMETON_PAI_NCORES` (tant que l'app n'expose pas le curseur). PAI identique (comptage
associatif). 102 pass. Bump patch → **0.146.3**.

> ⚠️ Le chemin **LiDAR PAI** (`pai_depuis_nuage` réel) n'était PAS couvert par le run
> e2e de 0.146.2 (qui passait `pai=raster`). D'où ce bug découvert seulement au run réel.
> Le calcul PAI lui-même est correct (prouvé ce matin) — seul le dimensionnement mémoire
> était en cause.
>
> **Bilan = 7 blocages successifs le 2026-07-08/09** : creds → 403 ERA5 (v0.145.1) →
> soilparameters (v0.146.1) → trim/temps + writeRaster/app + NaN (v0.146.2) → **OOM PAI
> (v0.146.3)**. Prochaine étape : réinstaller 0.146.3, relancer → PAI 2-dalles (sûr) →
> pai.tif caché (0.100.13) → ERA5 (2018 réutilisé) → microclimf → sensibilite.gpkg.

### 2026-07-08 — v0.146.2 : compat microclimf 2.x sortie `runmicro` (3 bugs aval)

**Débogage proactif end-to-end** (à la demande : « je suis sûr qu'il y aura d'autres
bugs »). J'ai exécuté tout le pipeline `regen_sensibilite()` hors app (petite grille
réelle EPSG:2154 + cache ERA5 2018 réel + `pai` raster pour sauter lasR), ce qui a
révélé **3 bugs supplémentaires** en aval du fix `soilparameters` (0.146.1) :

1. **`invalid 'trim' argument`** — microclimf 2.0.0 renvoie `out$tme` VIDE et ne pose
   pas `terra::time()` ; l'ancien garde `!is.null(terra::time())` (NA ≠ NULL) faisait
   `format(NA,"%m")` → `"%m"` pris pour `trim`. Mois d'été lus depuis
   `mp$weather$obs_time` (288 pas = 12 mois × 24 h, alignés 1:1 aux couches Tz).
2. **`writeRaster` sur "numeric"** — `max(SpatRaster)` renvoie un scalaire global selon
   terra ; remplacé par `terra::app(..., "max"/"mean")` (réduction cellule-à-cellule).
3. **`sensibilite = NaN`** — z-score divisait par sd : NaN pour 1 seule UGF (sd=NA) ou
   delta uniforme (sd=0). `z()` durci → 0.

Run e2e final : sf retourné, tmax sous couvert 33-35 °C, VPD ~1,5 kPa, couverture 100 %,
tif `cache_2018_{tmax,vpd}.tif` écrits. Test de régression mockant microclimf (mois via
obs_time + réduction app). **98 pass.** Bump patch 0.146.1 → **0.146.2**.

> **Bilan de la journée = 6 blocages successifs révélés l'un après l'autre** : creds
> (redémarrage) → 403 ERA5 (v0.145.1) → `soilparameters` (v0.146.1) → `trim`/temps →
> `writeRaster`/app → `NaN` z-score (v0.146.2). + perf PAI parallèle/cache. Le pipeline
> exposition tourne enfin de bout en bout sous microclimf 2.0.0.

### 2026-07-08 — v0.146.1 : fix microclimf 2.x (`soilparameters`) + cache ERA5 réutilisé

Run réel RECONFORT relancé (nemeton 0.146.0) : PAI parallèle ✅ (~38 min, 4 dalles
de front, ~2×), ERA5 mensuel ✅ (fix 403 validé, 2018 téléchargé). **Mais toujours
pas de `sensibilite.gpkg`** → deux bugs de plus, diagnostiqués par reproduction
hors app sur le cache existant :

- **microclimf 2.0.0 `object 'soilparameters' not found`.** Reproduction de la
  séquence `.rsen_traiter_annee` : `extract_clim` OK, `checkinputs` OK, mais
  `runpointmodel` plante — microclimf 2.x référence `soilparameters`/`soilparamsp`
  sans les charger (namespace verrouillé). Workaround validé (les exposer en
  globalenv → `runpointmodel → subsetpointmodel → runmicro` OK, sort `Tz`). Fix :
  `.rsen_ensure_soildata()` (idempotent + `on.exit` rm). C'était LE blocage réel
  du calcul depuis la mise à jour microclimf.
- **Cache ERA5 cassé.** mcera5 nomme le combiné `era5_<an>_<an>.nc` (double année),
  or `.rsen_era5_combined` cherchait `era5_<an>.nc` → jamais trouvé → re-download
  des 24 mois à chaque run. Fix : repérage par suffixe `_<an>.nc`.

Tests : reproduction `.rsen_ensure_soildata` (idempotent) + `.rsen_forcage_era5`
combiné double-année. 92 pass. Pur cœur. Bump patch 0.146.0.9000 → **0.146.1**.

> Chaîne complète de la journée : creds (redémarrage) → 403 (v0.145.1) →
> `soilparameters` (v0.146.1) = 3 blocages successifs révélés l'un après l'autre.
> + PAI parallèle (v0.146.0) & cache PAI (v0.145.0) pour la vitesse.

### 2026-07-08 — v0.146.0 : PAI LiDAR parallèle par dalles (`ncores`, concurrent_files)

Suite au diagnostic du run RECONFORT : la phase PAI (`pai_depuis_nuage`, 25 dalles
COPC / 4,7 Go) tenait **>1 h** en séquentiel. Constat : `lasR` streame déjà les
dalles, mais la fonction ne posait **aucune** stratégie parallèle (mono-thread).
Le buffer/bord-à-bord n'est pas pertinent pour un `rasterize("count")` (aucune
dépendance de voisinage) — le vrai levier est `concurrent_files`.

- **Cœur (v0.146.0).** `pai_depuis_nuage(..., ncores = NULL)` : `NULL` = auto
  (`lasR::half_cores()`), entier `N` = N dalles de front, `1`/`FALSE` = séquentiel.
  Helper `.pai_parallel_ncores`. Stratégie globale sauvegardée/restaurée
  (`get/set/unset_parallel_strategy`). Sortie identique (comptage associatif),
  gain ~linéaire (8 cœurs → ~4×). `regen_sensibilite()` expose `pai_ncores`
  (transmis) pour réglage RAM côté app. Défaut auto-parallèle → **le prochain run
  bénéficie sans changement app**. Test : résolution NULL/FALSE/1/N (mock
  half_cores) — 89 pass. `.Rd` des deux fonctions édités main.
- **ERA5 12 mois** : parallélisation possible mais **bornée par la concurrence
  par-utilisateur du CDS** (file serveur) ; `mcera5::request_era5` est séquentiel.
  Meilleur levier = ne tirer que les mois d'été utiles (`mois_ete`) → moins de
  requêtes plutôt que parallèles. À arbitrer (changement de fenêtre temporelle,
  validation microclimf requise).

### 2026-07-08 — v0.145.1 : fix ERA5 « request too large » (régression CDS v0.143.0)

**Cause racine trouvée en run réel RECONFORT.** Après redémarrage app (creds OK),
microclimf entre, calcule le PAI (1h20), puis **échoue ~53 s** en phase ERA5,
`microclimf/` auto-nettoyé. Diagnostic hors app (reproductions ciblées) :
- clé CDS OK, licences `reanalysis-era5-single-levels` **et** `-land` acceptées
  (requête 6 h acceptée `201`) — donc **ni auth ni licence** ;
- la requête **année entière** du moteur (`by_month=FALSE`, ~105 000 champs) est
  rejetée par le nouveau CDS en 3,5 s : `403 cost limits exceeded / request too
  large`. Le retry 3× (15+30 s) → ~53 s → échec. **Aucun run microclimf
  n'aboutissait depuis la bascule `by_month=FALSE` de v0.143.0.**

**Fix (v0.145.1, patch).** `.rsen_forcage_era5()` repasse `by_month = TRUE` :
12 requêtes mensuelles (~9 000 champs, sous la limite) fusionnées par mcera5
(`combine`) en `era5_<annee>.nc`. Cache indexé sur ce fichier combiné (helper
`.rsen_era5_combined`), plus robuste que `list.files()[1]`. Retry/back-off
conservé (throttle mensuel). Tests : mock mcera5 → by_month=TRUE + sélection du
combiné + réutilisation du cache sans re-download — 83 pass. Pur cœur, aucun
changement app. Bump patch 0.145.0.9000 → **0.145.1**.

> Enchaînement de la journée : creds (redémarrage app) débloquent le *skip*
> microclimf → révèlent le bug ERA5 (403) → corrigé ici. + `pai_cache` (v0.145.0)
> évitera de repayer les 1h20 de PAI au prochain run.

### 2026-07-08 — v0.145.0 : cache disque du PAI LiDAR (`pai_cache`) + brief app

Diagnostic en direct d'un run RECONFORT (projet `20260701_204501_ltcp`) : après
redémarrage de l'app (env `.Renviron` + paquets rechargés), microclimf **entre
enfin** (dossier `cache/regeneration/microclimf/` créé, clé CDS vue). Mais la
phase **PAI** (`pai_depuis_nuage` sur nuage COPC 25 dalles / 4,7 Go, disque local)
tient **>34 min** à ~0,8 Mo/s (décompression COPC + rastérisation `lasR`
mono-thread sur un gros AOI). Le PAI **n'était pas persisté** (tempfiles) →
repayé à chaque run.

- **Cœur (v0.145.0).** `regen_sensibilite(..., pai_cache = NULL)` : cache GeoTIFF
  du PAI LiDAR. Hit si fichier présent **et** `compareGeom(pai, dtm)` → relu, pas
  de recalcul ; sinon calcul + `writeRaster`. Invalidation par géométrie (AOI/`res`
  changés → recalcul). Événement `regen_expo:pai` gagne `source = "cache"`.
  Rétro-compatible (`NULL` = v0.144.x). Test : miss→écriture (source lidar) puis
  hit→relu (source cache, `pai_depuis_nuage` non rappelé, mock compteur) — 78 pass.
  `.Rd` édité main (ajout `pai`+`pai_cache`, item `pai` manquait). Bump mineur
  0.144.0.9000 → **0.145.0**.
- **App (brief).** `brief-nemetonshiny-pai-cache.md` : passer
  `pai_cache = file.path(out_dir, "pai.tif")` à `regen_sensibilite`, + bouton
  « recalculer le PAI » (supprime le fichier). Le run en cours (nemeton 0.144.0,
  app sans câblage) n'en bénéficie pas ; gain dès le prochain run après v0.145.0.

### 2026-07-08 — reGénération : message de phase en cours du moteur (notif bas-droite, app livrée)

Suite app du canal cœur `regen_expo:pai` (v0.144.0). `nemetonshiny` consomme
désormais la progression du moteur réel et l'affiche en bas à droite :

- **Canal** : fichier `cache/regeneration/engine_status.json` écrit par le worker
  `future` (écriture atomique tmp+rename), poll `invalidateLater(1000)` côté
  module qui rafraîchit la notif persistante bas-droite.
- **6 phases** rendues : grille → PAI → microclimat étés moyens `year (i/n)` →
  canicule → exposition → BILJOU, plus `microclimf_skipped` (raison) — la phase
  sautée devient explicite (ton cas RECONFORT : microclimf ignoré faute de clé /
  structure, au lieu du garde-fou muet).
- Consomme l'événement cœur `regen_expo:pai` (`source` lidar|satellite).
- **Lève la réserve §5** de `brief-nemetonshiny-engine-feedback.md`.
- Livré app-side : `nemetonshiny@95733907` (**v0.100.11**), cycle dev
  0.100.11.9000 (commit 1f0d8d40). Plancher cœur `nemeton (>= 0.144.0)`.
  Spéc : `specs/027-regeneration-microclimat/brief-nemetonshiny-engine-phase-status.md`.

### 2026-07-08 — v0.144.0 : phase `regen_expo:pai` (structure végétation visible) + brief app

Sur diagnostic réel RECONFORT (projet `20260701_204501_ltcp`) : grille LiDAR HD
complète (`cache/layers/lidar_{mnt,mnh,nuage}`), mais `cache/regeneration/` sans
`microclimf/` ni `sensibilite.gpkg` → le garde-fou `regen_guard_sensibilite`
s'affiche. Confirmé : le **PAI n'est jamais persisté** (`pai_depuis_nuage()`
écrit en `tempfile()`, recalculé à chaque run) et la phase PAI était **muette**.

- **Cœur (v0.144.0).** `regen_sensibilite()` émet `regen_expo:pai`
  (`source = "lidar"|"raster"`) juste avant la construction de la structure de
  végétation — poste le plus long avant ERA5. Rétro-compatible (no-op si
  `progress_callback = NULL`). Test : chemin moteur piloté par mock de
  `.rsen_traiter_annee` (raster calé sur `dtm`) + `pai` fourni (pas de `lasR`),
  asserte `regen_expo:pai` (source=raster) < `regen_expo:complete` — 73 pass.
  `.Rd` de `regen_sensibilite` édité à la main (exportée). Bump mineur
  0.143.0.9000 → **0.144.0**.
- **App (brief).** `brief-nemetonshiny-engine-phase-status.md` : le worker
  `future` écrit la phase courante dans `cache/regeneration/engine_status.json`
  (via `on_prog`), le module la **poll** (`invalidateLater`) et l'affiche dans la
  notif persistante bas-droite. Mapping des 6 phases → libellés i18n, y compris
  les phases **sautées** (microclimf ignoré faute de clé CDS / structure).

### 2026-07-07 — v0.143.0 : 2 pistes cœur moteur exposition (clip LiDAR AOI + ERA5 dégroupé)

Implémentation des deux pistes cœur ouvertes le même jour (Réserves spec 027) :

- **Piste 1 — clip lecture LiDAR à l'AOI.** `pai_depuis_nuage()` ajoute un filtre
  LASlib `-keep_xy` au reader lasR (helper `.pai_keep_xy_filter`, emprise =
  `parcelle` sinon `grille`, marge `3·res`). Constat clé : `parcelle` n'était
  qu'un **masque final** ; `lasR::exec(pipe, on = dalles)` lisait **toutes** les
  dalles en entier. Sur nuage **COPC** (indexé), lasR ne lit désormais que les
  points de l'AOI et saute les dalles hors emprise → plus de lecture de tout le
  nuage sur grand massif. PAI dans la grille inchangé (résultat identique).
- **Piste 2 — ERA5 moins throttlé.** `.rsen_forcage_era5()` : `by_month = FALSE`
  (1 requête/an au lieu de 12) + `.rsen_era5_with_retry()` (retry + back-off,
  absorbe un `curl_fetch_memory`/429 transitoire que mcera5 ne relance pas).

Aucun changement de résultat. Tests (test-regen-engines.R) :
`.pai_keep_xy_filter` (SpatRaster/SpatExtent/sf → chaîne `-keep_xy` tamponnée),
`.rsen_era5_with_retry` (retry-puis-succès, abandon après max_tries) — 68 pass.
`.Rd` de `pai_depuis_nuage` édité à la main (exportée). Bump mineur
0.142.0.9000 → **0.143.0**. Les deux entrées « Réserves / dette » spec 027 sont
levées (voir section).

### 2026-07-07 — Moteur microclimf : structure de végétation câblée côté app (aucun changement cœur)

- **Brief `specs/027-regeneration-microclimat/brief-nemetonshiny-microclimf-vegetation-structure.md`**
  (HAUTE). Cause racine : `service_regeneration.R` appelait
  `nemeton::regen_sensibilite(res, mnt, mnh, …)` **sans `las` ni `pai`** ; le cœur
  exige la structure de végétation (PAI) et abandonnait avant tout ERA5 (abort
  avalé en warning), laissant `cache/regeneration/microclimf/` vide et
  `sensibilite.gpkg` absent. Écartés au diagnostic : licence ERA5-Land (OK),
  E-OBS (OK), CRS des tuiles (2154 propre), grille MNT+MNH (présente), CDS ready
  (OK).
- **Fix app** :
  - `resolve_regen_lidar_grid()` résout désormais aussi
    `cache/layers/lidar_nuage` (`.las/.laz/.copc.laz`) → `grid$las_dir`.
  - Bloc microclimf : `las = grid$las_dir` prioritaire (provenance « lidar »),
    sinon repli `pai` via `.regen_lai_fallback()` (LAI Sentinel-2/PROSAIL déjà
    caché, provenance « satellite ») ; aucune source → warning i18n
    `regen_engine_no_vegetation_structure`.
  - `micro_cache` créé seulement si le moteur tourne, retiré s'il reste vide
    après échec ; `era5_*.nc` persistés → reprise au re-lancement. Throttle CDS
    ERA5 → warning distinct `regen_engine_era5_interrupted`.
  - i18n : 2 clés FR/EN ; tests app : `las`/`pai`/aucune-structure/ERA5-throttle
    (test-regeneration_engine 60, provenance 13).
- **Cœur** : **aucun changement** ; `regen_sensibilite(las=/pai=)` déjà exposé
  (nemeton ≥ 0.140.0). Plancher app inchangé.
- **App** : merge `nemetonshiny@5493df2c` → release **v0.100.8**, cycle dev
  0.100.8.9000.
- **Pistes cœur ultérieures (optionnelles, non bloquantes)** :
  1. Exposer `parcelle` / `fenetre` dans `regen_sensibilite()` pour clipper la
     dérivation PAI du nuage aux UGF — actuellement `las = <dossier nuage>` fait
     lire par `lasR` **toutes** les dalles (ex. 25 × ~138 Mo) sur toute l'emprise
     du nuage → lourd sur grand massif. Le repli `pai` (S2) reste léger.
  2. Back-off plus patient / regroupement des requêtes ERA5 dans
     `.rsen_forcage_era5()` (~12 requêtes/an × 2 catégories d'années → le CDS
     throttle parfois ; l'auto-reprise via cache mitige déjà).

### 2026-07-07 — v0.142.0 : progress_callback sur les moteurs reGénération (implémenté)

Implémentation du brief cœur (périmètre + noms d'événements validés par Pascal).
`regen_sensibilite()` et `regen_bilan_hydrique()` gagnent `progress_callback = NULL`
(contrat monitoring, no-op si NULL, `tryCatch` jamais fatal). Événements :
`regen_expo:microclimf`/`:era5`(par année×catégorie)/`:complete` ;
`regen_biljou:start`(n)/`:complete`. Threading via `.rsen_moyenne_categorie`
(param `emit`/`category`, `...` forwardé par `do.call`) — `.rsen_traiter_annee`
inchangé. `.Rd` édités à la main (exportées, pas de `document()`). Tests
(test-regen-engines.R) : émission par année via `local_mocked_bindings(.rsen_traiter_annee)`
sans ERA5 réel, start/complete BILJOU réel offline, callback throw survécu,
no-op si emit NULL — 61 pass ; r3-biljou 14, load-biljou 23 verts. Bump mineur
0.141.0.9000 → **0.142.0**. Brief app ntfy §4 mis à jour (granularité fine
disponible, snippet `on_prog` + clés i18n). Le mois k/12 (mcera5) et point k/N
(biljouR) restent hors portée (internes amont).

### 2026-07-07 — Brief cœur : progress_callback sur regen_sensibilite/regen_bilan_hydrique (granularité fine ntfy)

Demande de granularité fine pour les pushes ntfy du moteur reGénération. Le cœur
a déjà un contrat `progress_callback(payload = list(current="<ns>:<step>", …))`
standardisé (load_biljou, load_eobs, fordead, reconfort, monitoring,
sentinel2_cache) ; il manque à `regen_sensibilite` et `regen_bilan_hydrique`.
Granularité **atteignable** : ERA5 **par année × catégorie** (boucle
`.rsen_moyenne_categorie` → `.rsen_traiter_annee`) + microclimf par catégorie +
BILJOU **start/complete**. **Hors portée** : ERA5 mois k/12 (interne mcera5) et
BILJOU point k/N (interne `biljouR::biljou_run_grid`) — externes, prints only,
ne PAS scraper le stdout.

→ **Brief cœur (paperwork-first)** :
`specs/027-regeneration-microclimat/brief-nemeton-core-progress-callbacks.md`.
API `progress_callback=NULL` (défaut = no-op byte-identique) ; events
`regen_expo:era5|microclimf|complete`, `regen_biljou:start|complete` ; .Rd édités
à la main (fonctions exportées, pas de document()) ; tests via
`local_mocked_bindings(.rsen_traiter_annee)` sans ERA5 réel ; bump mineur.
**En attente de 2 confirmations** (périmètre + noms d'événements) avant code.

### 2026-07-07 — Brief app : notifications ntfy du moteur reGénération (microclimf + BILJOU)

Demande : pousser des messages ntfy « au fur et à mesure » sur le bouton
« Moteur microclimf + BILJOU », comme FAST/FORDEAD/RECONFORT. Constat : le
mécanisme ntfy est **100 % app** (`nemetonshiny/R/service_monitoring.R` :
`.ntfy_config()`/`.ntfy_send()`, opt-in via `NEMETON_NTFY_*`, no-op si non
configuré). Le moteur tourne dans un worker `future` (`ExtendedTask`), donc les
pushes intermédiaires doivent vivre **dans** `run_regeneration_engine()` (pas
dans le `observeEvent`, qui ne voit que début + fin) — pattern FORDEAD.

→ **Brief app livré** : `specs/027-regeneration-microclimat/brief-nemetonshiny-engine-ntfy.md`
(MOYENNE, aucun changement cœur). Pushes *stage-level* : start → micro_start →
micro_done/skip → biljou_start → biljou_done → résumé (`cached`) + warnings.
Titre ASCII `"Nemeton Regen"` (en-têtes ntfy non UTF-8). 8 clés i18n FR/EN.
**Option granularité fine** (ERA5 mois k/12) = petit brief cœur ultérieur
(`regen_sensibilite`/`regen_bilan_hydrique` n'exposent pas de callback de
progression) — à demander si le stage-level ne suffit pas.

Note : le brief précédent (structure de végétation, `las`/`pai`) est **déjà
appliqué** côté app (`service_regeneration.R` : `veg_args$las = grid$las_dir`,
repli `pai`, cleanup dossier vide, warning `regen_engine_no_vegetation_structure`).

### 2026-07-07 — Élucidation microclimf vide + brief app (structure de végétation manquante)

Suite à « pourquoi `microclimf/` et `sensibilite.gpkg` restent vides ? ».
Écartés par repros ciblés : licence ERA5-Land (✅ téléchargement OK), licence
E-OBS (✅), CRS des tuiles (✅ 2154 propre), grille LiDAR (✅ `lidar_mnt/` +
`lidar_mnh/` présents), CDS ready (✅). **Cause réelle** : `regen_sensibilite()`
exige la **structure de végétation** (`las` nuage LiDAR **ou** `pai` LAI
S2/PROSAIL), et l'app (`service_regeneration.R:459`) ne passe **que** `mnt`+`mnh`
→ abort avalé en warning « microclimf: … » → dossier créé (l.457) mais vide.

Le projet a pourtant `cache/layers/lidar_nuage/` (25 dalles `.copc.laz`), mais
`resolve_regen_lidar_grid()` ne résout que MNT+MNH. **Fix vérifié end-to-end**
(repro avec `las = <dossier .laz>`) : garde franchi, `pai_depuis_nuage()` (lasR)
dérive le PAI, microclimf tourne (ERA5 en cours).

→ **Brief app livré** :
`specs/027-regeneration-microclimat/brief-nemetonshiny-microclimf-vegetation-structure.md`
(HAUTE, aucun changement cœur). Étend `resolve_regen_lidar_grid()` (résoudre
`lidar_nuage` → `las_dir`) + passe `las = grid$las_dir`, sinon repli `pai` via le
`.regen_lai_fallback()` (LAI S2 déjà caché) que BILJOU utilise. Réserve perf
notée (lasR sur toutes les dalles ; clip `parcelle`/`fenetre` = petit brief cœur
ultérieur si besoin).

### 2026-07-07 — v0.141.0 : TWI stable (agrégation ~10 m) + cache TWI auto-invalidant

Diagnostic parti de la question « le TWI est-il recalculé depuis
`lidar_mnt_mosaic.tif` ? ». Vérification empirique sur le projet
`20260701_204501_ltcp` : le `twi.tif` en cache est **10000×10000, 0.5 m, 2154**
— géométrie identique à la mosaïque LiDAR ⇒ oui, le TWI y est bien dérivé du
LiDAR HD. Mais deux vrais sujets cœur émergent :

- **A (fix) — cache fichier périmable.** `get_or_compute_twi()` avait un cache
  **mémoire** indexé sur l'empreinte du DEM mais un cache **fichier** à nom fixe
  `twi.tif`, rechargé quelle que soit l'empreinte. Un projet ayant calculé le
  TWI depuis un DEM grossier (WMS 25 m) **ne le recalculait pas** après
  acquisition du LiDAR HD. → Fichier renommé `twi_<hash>.tif` (hash = dims +
  emprise + CRS + `twi_target_res`), auto-invalidant. Les `twi.tif` existants
  deviennent orphelins, recalculés une fois.
- **B (feat) — TWI à 0.5 m brut, bruité et lourd.** `calculate_twi_terra()`
  faisait `terrain`+`flowdir`+`flowAccumulation` sur le DEM natif (100 M
  cellules à 0.5 m) : TWI dominé par la micro-topographie, valeurs absolues peu
  fiables. → Nouveau `twi_target_res` (défaut **10 m**, choisi par Pascal ;
  20 m d'abord évoqué puis ramené à 10) qui **agrège le DEM** (moyenne) avant
  l'accumulation de flux. `.twi_aggregate_dem()` n'agrège jamais vers plus fin
  que le natif, ni sur un DEM lon/lat (pas en degrés). ~400× plus léger.

`calculate_twi_terra()`/`calculate_twi_grass()` acceptent aussi `target_res`
(`NULL` = pas d'agrégation, utilisé par les replis GRASS→terra pour éviter une
double agrégation). Fonctions internes (non exportées) → pas de `.Rd`. Tests :
`test-indicators-families.R` (agrégation fine→10 m, cache indexé par empreinte,
skip lon/lat, clés mémoire avec `|10`) — 317 pass ; `test-indicators-risk.R`
161 pass. **Aucun impact app** (l'app ne lit jamais `twi.tif` par nom — tout
passe par le cœur). Note : les valeurs de W3 changent (TWI plus propre) — c'est
attendu et documenté (NEWS).

### 2026-07-06 — Deux briefs app reGénération/hygiène livrés (aucun changement cœur)

- **Brief `specs/027-regeneration-microclimat/brief-nemetonshiny-engine-feedback.md`**
  (HAUTE, user-facing). Feedback des boutons async reGénération côté app :
  - `bslib::input_task_button` + `bind_task_button` → désactivation + spinner
    pendant la tâche, réactivation à la fin ; supprime le risque de run
    concurrent réécrivant `sensibilite.gpkg` / `biljou.gpkg` en cours de lecture.
  - Notification persistante bas-droite (retirée en fin de tâche) + chrono MM:SS
    (H:MM:SS au-delà d'une heure) sous chaque bouton.
  - **Cœur** : aucun. Consommation d'API bslib uniquement.
  - App : `nemetonshiny@3705000f`.

- **Brief `specs/brief-nemetonshiny-cleanups-lowpriority.md`** (BASSE, hygiène).
  Corrections CRS **à la source** (le cœur ≥0.138.1 compensait déjà à la lecture) :
  - LiDAR HD → EPSG:2154 (mosaïque / retour cache / `.lidar_mosaic_covers_bbox`),
    stamp **conditionnel** (seulement si `describe$code` est NA) → plus de
    « No DEM available » ni de re-téléchargements.
  - WMS NDP 0 (DEM BD ALTI + IRC) → EPSG:4326 ; NDVI dérivé hérite → plus de
    « CRS do not match » sur C2/R1/R2/R3/W3.
  - Retrait de l'appel déprécié `nemeton::theia_configure_s3()` (le cœur signe en
    interne via la gateway STAC `signing.stac.teledetection.fr`, R pur),
    remplacé par le garde amont `theia_api_key_configured()` ; commentaires
    `reticulate` périmés mis à jour (reticulate conservé pour FORDEAD/RECONFORT).
  - **Cœur** : aucun. §4 (réparation one-shot des caches CRS existants) non
    implémenté (réécriture de caches utilisateur, heuristique, déjà fait à la
    main : RECONFORT→2154, Fordead→4326).
  - App : `nemetonshiny@804d17d1`.

- **Release app** : merge `nemetonshiny@de495a7a` → **v0.100.7**, cycle dev
  0.100.7.9000. Plancher inchangé (`Imports: nemeton (>= 0.140.0)`).
- **Vérifié** : `regen_canopy_provenance()` + badge canopée déjà alignés sur le
  vocabulaire interne `"lidar"/"satellite"` (moteur + `detect_ndp`) → pas de
  bascule vers `canopy_provenance()` nécessaire (§3(c) du brief cleanups).

### 2026-07-06 — Tirage validation pondéré continu FORDEAD/RECONFORT propagé à l'app

- **Cœur** : `create_validation_sampling_plan()` gagne `weighting =
  c("uniform","continuous")` + `weight_raster` (release **nemeton@v0.140.0**).
  Normalisation min-max + inclusion GRTS pondérée + alignement du raster de
  sévérité (`.align_weight_raster`, condition `validation_weight_raster_mismatch`)
  côté cœur ; colonne de sortie `alert_weight` en mode continu.
- **App** : `nemetonshiny@033f61d4` (merge) → release **v0.100.4**. Onglets
  FORDEAD/RECONFORT du plan de validation branchés en continu (parité FAST) :
  sélecteur « Pondération du tirage » (continu par défaut), résolution du raster
  de sévérité (FORDEAD `anomaly_index` sur zone `_tot` ; RECONFORT `score` via
  `reconfort_cache_manifest`), repli propre en uniforme si couche absente,
  `alert_weight` en table + infobulle. Plancher `Imports: nemeton (>= 0.140.0)`.
- **Clôture** : le résidu « pondération continue FORDEAD/RECONFORT » (parité avec
  `create_trend_sanitary_plan` de FAST) est **résolu**, cœur + app.

### 2026-07-06 — Added v0.140.0 : tirage validation pondéré continu (FORDEAD/RECONFORT)

Brief cœur : parité de `create_validation_sampling_plan()` avec
`create_trend_sanitary_plan()` (déjà en continu pour FAST via `|slope|`). Ajout
de `weighting = c("uniform","continuous")` + `weight_raster` (params avant
`seed`, rétro-compat). `uniform` = ancien comportement inchangé (schéma
byte-identique, pas de `alert_weight`). `continuous` : `weight_raster` (FORDEAD
`anomaly_index` / score RECONFORT) aligné sur la grille d'alerte (helper
`.align_weight_raster()` — reproj/resample bilinéaire, classe d'erreur
`validation_weight_raster_mismatch` si CRS irréconciliable), restreint aux
cellules d'alerte (`classes` = masque d'éligibilité), normalisé min-max →
probabilité d'inclusion strictement positive, tiré via `.draw_grts_continuous()`
(aux_var spsurvey, déjà utilisé par le plan FAST). Colonne `alert_weight`
(sévérité brute au point) en mode continu. Garde-fous : NULL → erreur explicite ;
vide/NA/constant → `nemeton_empty_alert_mask`. 38 tests validation (dont
sur-représentation déterministe seed=7, alignement grille, 4 garde-fous typés),
26 tests trend non-régressés. **Suite côté app** : **brief livré** (PR #253,
`specs/014-validation-sampling/brief-nemetonshiny-continuous-weighting.md`) —
`service_validation_sampling.R` (nouveau `.resolve_weight_raster()` : FORDEAD
`read_fordead_layer("anomaly_index")` sur strate `_tot`, RECONFORT `score` via
`reconfort_layer_manifest(result)`+`read_reconfort_layer(row)`) passe
`weight_raster` + `weighting="continuous"` à `generate_validation_plan()` avec
repli uniforme si couche absente ; `mod_validation_sampling.R` : toggle
pondération (patron `is_fast`), `classes` conservé comme masque d'éligibilité,
affichage `alert_weight` ; mapping `validation_weight_raster_mismatch` ; i18n
FR/EN ; plancher `Imports: nemeton (>= 0.140.0)`. **Reste = exécution app par
Pascal** (session nemetonshiny dédiée). Note : le brief demandait 0.139.0, déjà
pris par le cache E-OBS → livré en **0.140.0**.

### 2026-07-06 — Changed v0.139.0 : E-OBS/CDS cache persistant + plafond d'année levé

Suite du diagnostic du toast « Détection E-OBS indisponible » (2026-07-06). La
cause du toast était **hors cœur** (variable `.Renviron` nommée `ecmwfr_ecmwfr`
au lieu de `ecmwfr_PAT` attendu par ecmwfr 2.0.3 → « Cannot find password » ;
puis licence CDS `insitu-gridded-observations-europe` non acceptée → 403 ; clé
elle-même valide, 36 car UUID). `~/.Renviron` corrigé (ajout `ecmwfr_PAT`) ;
restent 2 gestes Pascal : renommer la variable dans `nemetonshiny/.Renviron`
ligne 28 + accepter la licence CDS. **Côté cœur**, deux améliorations de
`load_eobs_source()` (spec 034) : (1) **cache persistant**
`get_global_cache_dir()/eobs`, nom déterministe `.eobs_cache_file()`, cache-hit
`"eobs:cache_hit"` sans réseau, zip supprimé après extraction — fini le
re-téléchargement des blocs multi-Go à chaque analyse ; (2) `.eobs_cds_period()`
ne **plafonne plus la borne haute à 2024** (bloc ouvert → `2011_<max année>`), à
apparier avec la `version` E-OBS couvrant ces années. Tests : bloc sans plafond
(2015–2025 → `2011_2025`), cache-hit `wf_request` mocké jamais appelé. 27 PASS.
Repro CDS livré dans le scratchpad ([[project_eobs_source]]).

### 2026-07-05 — Fixed v0.138.2 : CRS LiDAR HD « sans autorité » aussi sur S1/S2 (complément v0.138.1)

Audit CRS systématique des rasters produits par le cœur (déclencheur : « vérifier
que tous les rasters créés par le cœur portent le bon CRS »). **Verdict** : aucune
création *from-scratch* (3 sites : biodiversité B3 ×2, mosaïque FAST) ne sort en
`unknown` — toutes fixent `crs=` ou héritent d'un raster lu. Seule surface
d'exposition = les DEM **injectés** (LiDAR HD dégénéré). v0.138.1 avait normalisé
R1/R2/R3/W3 mais **pas** `indicateur_s1_routes()`/`indicateur_s2_bati()`, qui
consomment le même DEM (fallback `lidar_mnt` inclus) → sur un projet LiDAR HD,
`st_transform(roads/buildings, crs(dem))` + `rasterize(..., dem)` échouaient
(« CRS do not match ») → S1/S2 en NA. Fix : `dem <- .normalize_crs(dem)` après
résolution du DEM dans S1 et S2 + test de régression (DEM au CRS dégénéré →
plus de tout-NA). Réserve documentée : `regen_engines.R:.rsen_as_rast` dépend de
`crs(dtm)` sans normalisation, mais `microclimf::checkinputs` garde en amont.
En parallèle (hors release) : script de repro CDS E-OBS livré dans le scratchpad
pour diagnostiquer le toast « Détection E-OBS indisponible » (rejoue la requête
`load_eobs.R` sans le `tryCatch` masquant → affiche l'erreur `ecmwfr` réelle).

### 2026-07-05 — Fixed v0.138.1 : CRS LiDAR HD « sans autorité » (R1/R2/R3/W3 NA, RECONFORT)

Diagnostic en lançant R3 sur RECONFORT : « No DEM available » alors que le MNH/MNT
LiDAR HD sont là. Cause = CRS Lambert-93 **dégénéré** sur les GeoTIFF LiDAR cachés
(dalles, mosaïque, twi.tif) : WKT nommé `EPSG:2154` mais sans autorité
(`describe$code=NA`) → terra refuse la reprojection → extractions NA + TWI
resamplé NA → R3/R1/R2/W3 = NA. Fix cœur : `.normalize_crs()` récupère le code
EPSG du nom du WKT et re-tamponne ; appliqué à get_dem_raster, get_or_compute_twi
et l'entrée dem de R1/R2/R3/W3. Validé RECONFORT : R3 0 NA, ~60-67. Brief app
`brief-nemetonshiny-lidar-crs.md` : réparer à la source (le contrôle de couverture
bbox app rejette la mosaïque avant le cœur). +1 test.

### 2026-07-05 — Fixed v0.138.0 : moteur reGénération, carte vide RECONFORT (diagnostic réel)

Diagnostic en lançant le vrai calcul moteur sur RECONFORT (LiDAR HD, sans clé
CDS) : la carte reste vide car BILJOU ne produit aucun `njstress`. Deux
garde-fous manquants corrigés côté cœur :
- `regen_bilan_hydrique()` : `lai_max` NULL/NA → warning + défaut par type
  (feuillu 5 / résineux 4.5) au lieu d'abort (microclimf sauté sans CDS + repli
  satellite non déclenché car grid présent → lai_max restait NULL).
- `build_biljou_soil()` : `ewm` NULL/NA → défaut 150 (crash biljou_soil sinon).
Validé bout-en-bout sur les 30 UGF (SAFRAN sans clé) : indice ~91.7-91.9, 0 NA.
Brief app `brief-nemetonshiny-lai-lidar.md` : dériver `lai_max` du LiDAR
(`pai_depuis_nuage`, sans CDS) quand microclimf est sauté. Décision Pascal : les
deux (filet cœur + dérivation LiDAR app). +2 tests.

### 2026-07-05 — Added v0.137.0 : helper canopy_provenance() (badge provenance, spec 033 D5)

Export `canopy_provenance(augmented)` : flags `detect_ndp()` → clé canonique
(`prosail_s2`/`opencanopy`/`lidar_hd`) pour le badge de provenance canopée de
l'onglet reGénération, sans logique côté app (règle #1). Brief D5 finalisé
(bascule sur le helper, contrainte clé Theia, version 0.137.0). Livraison app =
brief `specs/033-*/brief-nemetonshiny.md`. 103 tests ndp.

### 2026-07-05 — Changed v0.136.0 : cohérence THEIA totale (les 4 consommateurs)

Généralise la signature gateway à tous les usages des clés TLD : FORMS
(`resolve_theia_assets`/`load_theia_source`) renvoie du `/vsicurl/` signé
(**FORMS-T débloqué**, lecture réelle validée) ; `theia_signed_href` réécrit en R
pur (drop reticulate/Python) ; repli MUSCATE FAST (`.get_s2_band_raster`) signe
les `/vsis3/` ; `theia_configure_s3` déprécié. 373 tests, 0 régression. Voir
[[project_muscate_lai_s3_creds]].

### 2026-07-05 — Added v0.135.0 : accès THEIA par gateway de signature + MUSCATE→LAI réel

« Le reste MUSCATE » (spec 033 D4) bouclé et **validé bout-en-bout sur données
réelles** (Vercors, LAI médian 2.33 / max 7.2). Découverte majeure : les COG
MESO@UM (MUSCATE/FORMS) ne se lisent PAS en `/vsis3/` direct — la clé du portail
est rejetée (*AccessKeyId does not exist*). Le vrai flux (reverse du SDK Python
`teledetection`) = **URLs pré-signées** via `signing.stac.teledetection.fr`
(headers `access-key`/`secret-key`, modèle SAS). Nouveau `theia_sign_urls()` +
`.theia_signed_read()`. 3 bugs de chaîne corrigés (sf vs SpatVector ; band_names
= bandes réelles ; récupération `_lai.tiff`). Reste : basculer FORMS
(`load_theia_source`) sur le même flux + badge provenance app. Voir
[[project_muscate_lai_s3_creds]].

### 2026-07-05 — Fixed v0.134.2 : requête E-OBS CDS invalide (spec 034)

Validation clé CDS réelle : `load_eobs_source(source="cds")` était rejeté en 400
(« invalid combination ») — le CDS attend les enums en underscore (`30_0e`,
`0_1deg`) pas en point, et le défaut `28.0e` ne couvre pas `2011_2024`. Corrigé
(normalisation point→underscore + défaut `30.0e`, combinaison acceptée en réel).
Le 400 masquait le vrai blocage : **licence E-OBS à accepter** (403). Reste :
Pascal accepte la licence sur la page du dataset. Voir [[project_eobs_source]].

### 2026-07-05 — Fixed v0.134.1 : assemblage MUSCATE du repli LAI/PROSAIL (spec 033 D4)

Le « reste MUSCATE » = D4 (assemblage réflectances pour le repli LAI). Bug
trouvé par inspection : `.get_s2_band_raster()` renvoie un SpatRaster mais le
code lisait `g$path` → assemblage toujours NULL (jamais validé). Corrigé + ajout
`theia_configure_s3()` (dégradation propre sans creds) + rééchantillonnage
20 m→10 m. **Recherche MUSCATE validée réel** (22 scènes Vercors, hrefs
`/vsis3/`). Reste : download COG réel avec `TLD_ACCESS_KEY`/`TLD_SECRET_KEY`
Theia S3. Voir spec 033.

### 2026-07-05 — Added v0.134.0 : progression BILJOU + ERA5 validé réel

`progress_callback` sur `load_biljou_forcing()` (payloads biljou:safran_unit /
era5_download / complete / unavailable) → notifications bas-droite app pendant le
téléchargement du forçage. **Forçage ERA5 validé de bout en bout sur données
réelles** (clé CDS + licence acceptée par Pascal) : download + extract_clim
(microclimf, pression kPa) + conversion PET → meteo. SAFRAN (sans clé) et ERA5
(avec clé) désormais tous deux réels et validés. Brief BILJOU mis à jour. Voir
[[project_regen_engines_porting]].

### 2026-07-05 — Fixed v0.133.1 : forçage ERA5 aligné sur l'API mcera5 0.4

Validation clé CDS réelle (Pascal) : `.rsen_forcage_era5` utilisait l'ancienne API
mcera5 (`request_era5(bbox=)`) → cassé contre mcera5 0.4.0 (microclimf +
fallback biljou ERA5). Migré vers `build_era5_request()` + `request_era5()` +
`extract_clim(format="microclimf")` (colonnes prêtes, précip incluse, pression
kPa). Requête soumise OK au nouveau CDS. Reste : accepter la **licence ERA5** sur
le site CDS (403 sinon) + persister la clé (backend env ne survit pas aux
sessions). Voir [[project_regen_engines_porting]].

### 2026-07-05 — Changed v0.133.0 : SAFRAN via OGC API-EDR GéoSAS (source réelle)

Validation réelle : le DOI biljouR par défaut n'est qu'un pointeur (grille +
catalogue externe) → `load_biljou_forcing(source="safran")` dégradait en NULL.
Remplacé par l'**OGC API-EDR GéoSAS** (`safran-isba`, SIM quotidien, sans auth) :
requête position CSV par centroïde (coords EPSG:2154), variables ETP_Q/PRELIQ_Q/
PRENEI_Q → `safran_to_meteo` → meteo par unité. **Validé bout en bout sur données
réelles** (365 j, alimente regen_bilan_hydrique). SAFRAN = **aucune clé CDS**.
NB : dépôts Bruciamacchie (ForestClimR vide ; Climat/ClimatOmbro = analyse
mensuelle) n'offrent rien de plus fin en quotidien. Voir
[[project_regen_engines_porting]].

### 2026-07-05 — Added v0.132.0 : acquisition BILJOU (spec 027 L2, option B)

`load_biljou_forcing()` (meteo SAFRAN/ERA5 → format biljouR, liste par unité) +
`build_biljou_soil()` (objet biljou_soil, défaut ewm=150). Débloque le bilan
hydrique réel `regen_bilan_hydrique` depuis l'app (acquisition au cœur, règle #1),
symétrique de l'option B microclimf. SAFRAN primaire (DOI par défaut biljouR) via
safran_download+safran_nc_to_meteo ; ERA5 fallback via mcera5 (.rsen_forcage_era5
+ penman_pet). Chemin injection `raw` testé CI ; téléchargements best-effort →
NULL. regen_bilan_hydrique utilise `.biljou_points` (ids alignés). Reste :
validation Pascal des téléchargements SAFRAN/ERA5 réels + câblage app. Voir
[[project_regen_engines_porting]].

### 2026-07-05 — Added v0.131.0 : `load_eobs_source()` progression par étapes (spec 034)

`progress_callback` sur `load_eobs_source()` : payloads `list(current=…)`
(cds_request/download_done/unzip/read/reduce/complete/unavailable) → l'app
affiche des notifications bas-droite au fil du téléchargement E-OBS. Brief 034
mis à jour (mapping clés → i18n + showNotification id fixe). Voir
[[project_eobs_source]].

### 2026-07-04 — Added v0.130.0 : `load_eobs_source()` — acquisition E-OBS (spec 034)

Comble le maillon manquant qui rendait « Auto (E-OBS) » indisponible dans l'app :
le cœur n'auto-téléchargeait pas E-OBS. `load_eobs_source(aoi, var, years, …)`
produit le SpatRaster estival par année attendu par `microclimate_detect_years`
et `tendances_estivales_eobs`. Chemin pur `nc` (netCDF/SpatRaster daté → estival
par an) testé CI ; chemin CDS `ecmwfr` (dataset `insitu-gridded-observations-europe`,
même clé que ERA5) best-effort, validé sur données réelles. Reste : validation
Pascal du chemin CDS réel + brief app pour brancher le bouton « Auto ».

### 2026-07-04 — Fixed v0.129.1 : moteur microclimf validé sur données réelles (3 bugs API)

Validation `regen_sensibilite` (microclimf) **sur dalles LiDAR HD réelles**
(Vercors bundlées, `inst/extdata/aba.model/ALS`). Le chemin moteur (porté d'un
prototype) n'avait jamais tourné → 3 défauts corrigés :
1. `vegp`/`soilc` packés (`PackedSpatRaster`) → `.rsen_vers_grille` dépaquette
   (`terra::unwrap`) sinon dims ≠ dtm (checkinputs KO).
2. composants multi-couches → réduction scalaire (fin de `as.numeric(list)` KO).
3. `runmicro` renvoie `Tz`/`relhum` en **array nu** → `.rsen_as_rast` reconvertit
   en SpatRaster géo-référencé (comme `microclimf:::.rast`).
Bout en bout OK : T°max/VPD sous couvert sur grille réelle. PAI aussi validé
(médiane 4.66, bornes [0,8]). Note : borne pression checkinputs dépend de
l'altitude → ERA5/mcera5 en kPa. Reste : validation Pascal du forçage ERA5 réel
(mcera5 + CDS). Voir [[project_regen_engines_porting]].

### 2026-07-04 — Added v0.129.0 : repli LAI S2/PROSAIL increment 2 (spec 033 D3+D4)

- **D4 assemblage MUSCATE auto** : `lai_sentinel2()` assemble les réflectances S2
  seul (`stac_search_s2` muscate + `.get_s2_band_raster` stateless). Défaut
  `selected_bands` → `c("B4","B5","B8")` (B03/vert non exposé par `.S2_STAC_BANDS`).
- **D3 modèle pré-entraîné** : `inst/extdata/prosail_lai_Sentinel_2A_B4-B5-B8.rds`
  (1.3 Mo, sérialisation vérifiée, prédiction testée CI), plus de train au
  runtime. `data-raw/prosail_lai_model.R` pour régénérer.
- Reste : brief app provenance canopée (D5) + validation Pascal apply sur scène
  réelle. Voir [[project_regen_engines_porting]].

### 2026-07-04 — Added v0.128.0 : repli LAI Sentinel-2/PROSAIL (spec 033 increment 1)

D1–D6 validées par Pascal → `lai_sentinel2()` livrée (inversion PROSAIL hybride,
`prosail`). Chemin `precomputed` + réducteur p90 testés ; **train PROSAIL vérifié
en scratch** (`train_prosail_inversion`, srf$sensor requis), apply validé sur
données réelles. Intégration : `regen_sensibilite(pai=)` (repli LiDAR-absent),
`detect_ndp` flag `lai_ml`. Reste increment 2 : assemblage auto réflectances
MUSCATE + modèle pré-entraîné versionné + brief app provenance. Voir
[[project_regen_engines_porting]].

### 2026-07-04 — Proposée : spec 033 repli LAI Sentinel-2/PROSAIL (canopée NDP 0)

Question Pascal (« PAI depuis GEODES ? ») → constat : GEODES donne du **LAI**
(GEOV2 ~1 km, ou S2 L2A → inversion), **pas de PAI structural**. Cadré en
`specs/033-lai-prosail-sentinel2/spec.md` : repli **NDP 0** produisant un LAI
S2/PROSAIL (`prosail` 3.0.0, réutilise la source MUSCATE spec 029) pour `lai_max`
(biljouR, ajustement direct) et `pai` microclimf (proxy dégradé). **Décisions
D1–D6 à arbitrer, aucun code écrit.** ADR justifié (méthode d'inversion) → à
acter dans platform_nemeton. NDP ≥ 1 garde toujours `pai_depuis_nuage()` LiDAR.

### 2026-07-03 — Added v0.127.0 : consolidation multi-époques forêt ancienne + paliers N2 (spec 031)

Question Pascal : « pour N2 peut-on consolider avec Cassini ? ». Constat (happign) :
**Cassini ~1750 n'existe qu'en raster** (scans AN/BnF), pas de vecteur forêt IGN.
Décision : livrer la **capacité de consolidation multi-époques** côté cœur, prête
pour toute couche Cassini vectorisée fournie, neutre sinon.

- `build_foret_ancienne_mask(list(cassini=, etatmajor=))` → couche paliers
  non-recouvrante (`anciennete` = nb d'époques via `st_intersection` auto-overlay).
- `indicateur_n2_continuite(weight_anciennete=TRUE)` pondère par profondeur de
  palier ; rétrocompatible (mono-époque = binaire). 12 tests.
- Reste : obtenir un **vecteur Cassini** (digitalisation régionale) pour activer
  réellement le palier ~1750. Voir [[project_foret_ancienne_source]].

### 2026-07-03 — Livré v0.125.0 & v0.126.0 : moteurs microclimf (B) et BILJOU (C) réels

Voir la section « portage des 3 moteurs » plus bas : incréments B (microclimf,
v0.125.0) et C (biljouR, v0.126.0) livrés. Les 3 moteurs reGénération sont réels.

### 2026-07-03 — Changed v0.124.0 : extraction E-OBS raster câblée + item TFV confirmé (spec 027, items cœur 2 & 3)

**3 items cœur spec 027/031 traités ce jour** (tous briefés côté nemetonshiny) :

- **Item 1 — forêt ancienne** : `load_foret_ancienne_source()` (v0.123.0, ci-dessous).
- **Item 2 — E-OBS estival** : `microclimate_detect_years()` accepte un SpatRaster
  E-OBS par-année (crop+mask AOI → moyenne JJA/an → sélection moyenne/canicule).
  Le « not wired yet » du L2 est levé. Rétrocompatible, 20 tests (dont crop/mask).
- **Item 3 — mapping TFV→essence** : **déjà livré v0.121.0**
  (`map_tfv_to_species_class` exporté/documenté/testé, consommé par
  `regen_species_choices`). Aucune action — confirmé complet.

Les 3 items cœur des briefs reGénération sont **soldés**. Reste le portage des
moteurs (inc B microclimf / C biljouR, après validation PAI) + le brief app D.

### 2026-07-03 — Added v0.123.0 : acquisition forêt ancienne état-major pour N2 (spec 031, item cœur 1/3)

**`load_foret_ancienne_source(aoi, crs)`** livré. L'app (nemetonshiny) est déjà
câblée (`.fetch_foret_ancienne_auto` → `getExportedValue("nemeton",
"load_foret_ancienne_source")`) : dès export cœur, elle consomme sans bump.

- **Arbitrage source (Pascal, 2026-07-03)** : produit officiel « BD Forêts
  anciennes » (Nature=ancienne) = **download-only** (GPKG dépt `.7z`, pas de WFS
  — confirmé via `happign` : seul l'état-major brut est en WFS ; URL de
  téléchargement non vérifiable via web = bloquée). → on prend l'**ingrédient
  état-major ~1850** (`c_1_1_ocs_ancien`, EM9.1=forêt, vérifié Fontainebleau/
  Beauce) atteignable en WFS. N2 recroise avec l'actuel ⇒ continuité émerge.
- Délègue la finalisation à `build_foret_ancienne_mask()` ; dégradation `NULL` ;
  `sf` 0-ligne hors forêt ; `happign` en Suggests. **Smoke réel validé**
  (Fontainebleau 800 ha clippés). Tests CI = `get_wfs` mocké (16 PASS).
- Reste 2 items cœur spec 027 briefés : extraction E-OBS estivale
  (`microclimate_detect_years`) ; mapping TFV→essence (partiellement fait via
  `map_tfv_to_species_class`, à confirmer côté « not wired »).

### 2026-07-03 — Chantier : portage des 3 moteurs reGénération dans le cœur (spec 027 L1b)

**Décision Pascal** : câbler l'orchestration RÉELLE des 3 moteurs (aujourd'hui
scaffolds precomputed-only), déclenchés au clic **« Lancer l'analyse » de
l'onglet reGénération** (PAS « Lancer les calculs » de Sélection — redirigé
2026-07-03), via une **case à cocher opt-in** (microclimf ~6 ans = heures).
**Stratégie : incrémentale, validation réelle entre chaque** (moteurs
inexécutables/intestables en CI : deps lourdes + LiDAR HD + ERA5/CDS + SAFRAN).

- **Inc A — `pai_depuis_nuage` réel (v0.122.0)** : pipeline `lasR` (comptages
  sol/veg → Beer-Lambert), portage fidèle de `pai_lidarhd_lasR.R`. Gardé
  `requireNamespace`, precomputed conservé. **À valider par Pascal sur LiDAR
  réel avant inc B.** Tests plomberie/dégradation 19 PASS.
- **Inc B — `regen_sensibilite` réel (microclimf) — LIVRÉ v0.125.0** : portage
  fidèle de `microclimat_parcelles_robuste.R` (grille statique LiDAR HD, microclimf
  ERA5-Land par an avec cache_dir, moyennes moyen/canicule, robustesse, agrégation
  §7). Deps microclimf/mcera5/lasR en Suggests, gardées ; precomputed conservé.
  **À valider par Pascal sur données réelles avant inc C.**
- **Inc C — `regen_bilan_hydrique` réel (biljouR) — LIVRÉ v0.126.0** : API biljouR
  (centroïdes → `biljou_run_grid` → agrégation moyenne inter-annuelle → mapping des
  4 indices §7). **CI-testé** (meteo d'exemple `meteo_hesse` du paquet → run réel
  hors réseau). Les **3 moteurs sont réels**. Reste : validation Pascal LiDAR/ERA5
  (A/B) + brief app D.
- **Inc D — brief app** : brancher « Lancer l'analyse » (reGénération) pour
  lancer les moteurs présents (case opt-in + garde données/creds) et écrire
  `cache/regeneration/`. Pas de prototype BILJOU (package) ; PAI+microclimf
  portés des prototypes `/Documents/reGénération`.

### 2026-07-03 — Added v0.121.0 : sélecteur par-espèce FRM + mapping TFV → essence (spec 027, incrément 2/3)

Ferme l'item cœur PLAN « mapping TFV → essence ». `map_tfv_to_species_class()`
(colonne `species_class` de `bdforet_v2_mapping.csv`, 28 TFV mappés / 4
non-forestiers NA) → TFV BD Forêt v2 → classe NMT. `regen_species_choices()`
gagne `level` : `"species"` (**défaut**, essences FRM d'`european_species_tolerances`,
Atlas repliable `include_atlas`) / `"class"` (11 classes). Présence UGF via
`tfv_col` (mapping TFV) ou colonne de classe → groupes present/adaptation/atlas.
`european_species_tolerances()` gagne `species_class` (règle de genre → 11
classes). `indice_priorite_regen(species=)` résout **les deux tables** (classe
`essence_hetraie` **ou** espèce `fagus_sylvatica`). Brief onglet §4.1 mis à jour
(3 optgroup, tfv_col, confidence/invasif, shade_tol contexte). Tests
test-regen-species-choices.R 31 PASS ; sweep 474. NAMESPACE + 4 man + pkgdown.

### 2026-07-03 — spec 027 (reGénération) : lots L4/L5/L6 livrés côté app (aucun code cœur)

- **spec 027 (reGénération) : lots L4/L5/L6 livrés côté app.**
  **nemetonshiny v0.98.0** (merge `nemetonshiny@445a509d`) : onglet + module
  `mod_regeneration`, `service_regeneration` (`run_regeneration` via
  `precomputed`), profil LLM « Adaptation climatique », persistance versionnée
  `nemeton.regeneration_states` + migration 004, export GPKG, data-prep Quarto.
  **nemetonshiny v0.98.1** (merge `nemetonshiny@b68b3eb1`) : durcissement UX
  (strip ANSI warnings moteurs, feedback lancement, Auto E-OBS, pré-remplissage
  années, fix sélecteur essence, menu couche rétractable, retrait onglet radar).
  **nemetonshiny v0.98.2** (merge `nemetonshiny@328ea47f`) : **section
  reGénération du rapport PDF Quarto** (rendu vérifié lualatex) — complète L6.
  Plancher `Imports: nemeton (>= 0.118.0)`. **Aucun changement de code cœur** —
  fonctions déjà exportées (`regen_sensibilite`, `regen_bilan_hydrique`,
  `indice_priorite_regen`, `tendances_estivales_eobs`,
  `microclimate_detect_years`, `indicateur_a3/a4/w4/r6`, `bdforet_v2_mapping`).
- **Lots spec 027 portés par l'app** : **L4** (onglet/module `mod_regeneration`)
  ✅, **L5** (profil LLM adaptation) ✅, **L6** (persistance + export GPKG +
  section PDF Quarto) ✅ — **lot complet** côté app (v0.98.0/v0.98.1/v0.98.2).
  Ce commit = **docs(plan) seul**, pas de release cœur.
- **Item cœur mapping TFV → essence** : **livré depuis v0.121.0**
  (`map_tfv_to_species_class()` + `regen_species_choices(tfv_col=)`) — l'app peut
  pré-remplir « Essence cible » depuis BD Forêt v2. **Volet cœur spec 027 clos.**

### 2026-07-03 — Added v0.120.0 : table tolérances essences européennes (spec 027, calibration, incrément 1/3)

Fichier fourni par Pascal (`data-raw/Essences_europeennes_tolerances.xlsx`,
193 essences UE, 2 onglets) → **remplace la calibration indicative** par une
table **sourcée par espèce**. `european_species_tolerances(statut, confiance,
type, include_invasif)` (`R/european_species_tolerances.R`) lit
`inst/extdata/european_species_tolerances.csv` (généré par
`data-raw/european_species_tolerances.R`). **Mêmes axes** tmax_tol_c/vpd_tol_kpa
que `regeneration_tolerances()` (11 classes, conservée pour le mapping UGF),
**enrichis** : N&V 2006 sécheresse/**ombre**/engorgement (1–5), gel, humidité,
thermophilie. Statuts `frm_1999`(47)/`frm_2025`(17)/`atlas_jrc`(130), colonne
`confidence`, flag `invasif`(14). **Sources ajoutées** dans `inst/REFERENCES.md`.
Tests test-european-species-tolerances.R 20 PASS.

**Arbitrages Pascal (2026-07-03)** : (1) garder les 2 tables coordonnées
(11 classes UGF + 193 espèces cible) ; (2) sélecteur = FRM par défaut, Atlas
replié ; (3) axe ombre = **contexte affiché**, pas dans l'indice.

**Suite livrée v0.121.0** : `regen_species_choices()` étendu aux espèces FRM +
`indice_priorite_regen(species=)` double-table + mapping TFV → essence. **Volet
cœur spec 027 clos** (pas d'incrément de calibration supplémentaire retenu).

### 2026-07-03 — Added v0.119.0 : sélecteur essence cible reGénération (spec 027 §10.1, 5e incrément)

`regen_species_choices(units, species_col, region, lang)` (R/indice_priorite_regen.R) :
liste prête pour le menu « essence cible » de l'onglet, côté cœur. Options =
intersection `regeneration_tolerances()` ∩ `list_species_classes()` (seul
ensemble scorable) → data.frame code/label/tmax_tol_c/vpd_tol_kpa/present/groupe,
classes présentes sur UGF en tête puis alternatives adaptation triées par
tolérance chaleur croissante. Détection auto colonne essence ; générique
(species=NULL) ajouté par l'app. **Arbitrage de conception** (question Pascal) :
NE PAS offrir une liste MFR brute (non scorable) ni deux listes concurrentes —
une seule liste = le vocabulaire de tolérances, à deux `optgroup`. MFR = étape
aval future conditionnée à l'extension du CSV. **Origine des tolérances
clarifiée** : valeurs indicatives/ordinales (dire d'expert, non calibrées ;
sources à consolider = Rameau, guides station ONF/CNPF, ClimEssences). Brief
onglet §4.1 mis à jour. Tests test-regen-species-choices.R 17 PASS ; sweep 300.

### 2026-07-03 — Added v0.118.0 : branche A tendances estivales E-OBS (spec 027 §6, 4e incrément)

4e incrément reGénération. `tendances_estivales_eobs(aoi, tx, rr,
buffer_m=25000, breaks, precomputed)` (`R/tendances_eobs.R`) : carte bivariée
de tendances estivales (réchauffement × assèchement) **recadrée sur l'emprise
UGF + 25 km** (§10.4 validé Pascal ; buffer métrique EPSG:3035), **pas
nationale**. Par maille E-OBS : pente moindres carrés T°max/précip estivales +
classes bivariées (`classe_tmax`/`classe_precip` 1-3 tertiles ou breaks fixes ;
`classe_bivariee` 1-9). Comme les moteurs : chemin `precomputed` (crop+classe
sans données), chemin moteur (rasters par-année → pentes, terra testable),
échec propre. Sortie = `sf` points centres de maille → choroplèthe côté app.
Le cœur calcule, l'app rend (**brief nemetonshiny fourni**). Tests
`test-tendances-eobs.R` 17 PASS ; sweep 352. NAMESPACE + man + pkgdown à la main.

**Volet cœur spec 027 : tout le calculable/testable est livré.** Reste
l'orchestration RÉELLE des moteurs (chez Pascal, deps+données) et L4-L6 côté
nemetonshiny (indice + carte bivariée A + carto/onglet).

### 2026-07-02 — Added v0.117.0 : scaffolds moteurs reGénération L1/L2 (spec 027, 3e incrément code)

3e incrément. Les moteurs touchent aux deps GPL lourdes
(microclimf/mcera5/lidR/lasR/biljouR, inexécutables ici) → **scaffolds
honnêtes** avec **chemin `precomputed` pur et testable** (`R/regen_engines.R`) :
- `regen_bilan_hydrique()` (L2, biljouR) → colonnes §7 `njstress`/`istress`/
  `rew_min`/`deb_stress` ; `precomputed` rattache une sortie BILJOU sans moteur,
  alimente `r3(biljou=)` + `indice_priorite_regen`.
- `regen_sensibilite()` (L1, microclimf) → `tmax_*`/`vpd_*`/`sensibilite`… ;
  `precomputed` + **dérive** `d_tmax`/`d_vpd`/`rang_sensibilite`.
- `pai_depuis_nuage()` (L1, lasR) → PAI ; `precomputed` pass-through d'un raster.
Sans `precomputed` ni moteur → **échec propre actionnable** ; moteur présent mais
non câblé → « exécuter le prototype + passer precomputed ». **Le pipeline
regen_* → r3 / indice tourne dès aujourd'hui sur sorties pré-calculées.** Deps
lourdes déjà en Suggests+Remotes SAUF **biljouR** (dépôt à confirmer par Pascal
→ ajouter Suggests/Remotes). Tests `test-regen-engines.R` 17 PASS ; sweep 508.
NAMESPACE + 3 man + pkgdown à la main.

**Reste** (au feu vert / avec données) : orchestration RÉELLE des moteurs
(porter les prototypes /Documents/reGénération, exécutable seulement sur la
machine de Pascal avec deps+données+creds) ; branche A carte E-OBS sur emprise
UGF + buffer ; L4-L6 côté nemetonshiny.

### 2026-07-02 — Added v0.116.0 : r3_secheresse enrichi BILJOU (spec 027 §5.1, 2e incrément code)

2e incrément reGénération (pure logique testable, avant les moteurs).
`indicateur_r3_secheresse()` accepte les métriques BILJOU via `biljou`
(data.frame/list : `njstress`/`istress`/`deb_stress`) + `biljou_weight` (défaut
0.5). **Expose les valeurs brutes** (`r3_njstress`/`r3_istress`/`r3_deb_stress`)
en plus du score (conformité §5.1). **Blend** : le stress mécanique affine le
risque SPEI/topo (par unité, NA-safe : `0*NaN=NaN` géré) ; aggrave dans le sens
du risque (symétrique neige/humidité). **Sans DEM + BILJOU** → R3 depuis le
bilan hydrique seul. Lecture aussi depuis colonnes `units` (pipeline
`regen_bilan_hydrique → r3` transparent). **Rétrocompatible strict** (sans
biljou = v0.115.x, NA sans DEM). Bornes documentées non calibrées (§9.2). Tests
`test-r3-biljou.R` (BILJOU seul, exposition brute, lecture colonnes, blend DEM,
sens aggravant, rétrocompat) ; sweep voisins 380 PASS. `.Rd` r3 à la main.

**Reste** (au feu vert) : moteurs L1 (PAI+microclimf) / L2 (biljouR+SAFRAN) en
`Suggests` + tests mockés ; branche A carte E-OBS sur emprise UGF + buffer.

### 2026-07-02 — Added v0.115.0 : indice_priorite_regen (spec 027 v2.1 L3, 1er incrément code)

Premier code reGénération après réalignement + arbitrage. **Ordre choisi** :
pas L1→L2→L3 (les moteurs microclimf/biljouR/lidR exigent deps+données+creds
**inexécutables/intestables ici**), mais d'abord la **pièce pure-logique
entièrement testable** = `indice_priorite_regen()` (L3), qui **fige le contrat
§7** que les moteurs viseront.

`indice_priorite_regen(units, species=NULL, weights, tolerances, flag_breaks)`
(`R/indice_priorite_regen.R`) : **croise** l'exposition microclimatique
(`sensibilite`, sinon `d_tmax`/`d_vpd`) et le stress hydrique (`njstress`,
`istress`, `rew_min`) en une priorité 0-100. **Consomme** les colonnes des
moteurs (pas de dep GPL), testable sur `sf` synthétique. Conforme §10 :
générique par défaut, **essence en option OFF** (`regeneration_tolerances()` +
CSV 11 essences récupérés de la branche parkée), colonnes **au schéma §7**
(`indice_priorite_regen`, `regen_exposition`, `regen_hydrique`,
`parcelle_sensible`, `priorite`, `regen_essence`). Retravail du
`regeneration_index` parké (moyenne pondérée) → croisement du brief. Bornes de
stress **documentées, non calibrées** (§9.2). Tests `test-indice-priorite-regen.R`
21 PASS ; sweep voisins 796 PASS. NAMESPACE + man + pkgdown à la main.

**Reste** (au feu vert Pascal) : moteurs L1 (PAI LiDAR + microclimf — compléter
`microclimate_run`) et L2 (biljouR + bilan hydrique SAFRAN), en `Suggests` +
tests mockés ; enrichissement `r3_secheresse` (métriques BILJOU) ; branche A
carte de tendances E-OBS sur emprise UGF + buffer (~25 km à confirmer).

### 2026-07-02 — Fixed v0.114.1 + réalignement spec 027 sur le brief reGénération

**Fixed (v0.114.1, releasé).** `indicateur_l3_het_spectrale` (spec 028)
échouait sur un run réel Pascal (« l'objet 'list' ne peut être converti en
double ») : la β-diversité biodivMapR est un raster 3 bandes (PCoA Bray-Curtis)
→ `exact_extract(…, "mean")` renvoie un `data.frame`. `.aggregate_diversity`
réduit désormais un extract multi-bandes en un scalaire/unité, mono-bande (B4)
inchangé. 24 PASS. (PR #164.)

**Réalignement spec 027 (paperwork avant code).** Constat : le cadrage v1
(2026-06-30) et l'implémentation qui a suivi (A3/A4/W4/R6 + `regeneration_index`)
ont été faits **sans remonter au brief de référence**
`/home/pascal/Documents/reGénération/`. Ils ne couvrent que la moitié
microclimat et tranchent à l'inverse la décision licences §8.1. **Décision
Pascal : réaligner sur le brief complet.**
- **`regeneration_index` NON mergé** (PR #163 fermée, branche `feat/regeneration-index`
  parkée) — sera retravaillé en `indice_priorite_regen`.
- **spec 027 réécrite en v2.0.0** puis **simplifiée en v2.1.0** : deux moteurs
  (microclimf exposition + **biljouR bilan hydrique**), schéma de sortie §7, r3
  enrichi, indice = croisement exposition × stress hydrique, branche A E-OBS.
- **Correction licence (décision Pascal)** : v2.0 proposait un repo GPL
  `regen_nemeton` pour protéger un cœur *supposé MIT*. **Vérification du fichier
  LICENSE → `nemeton` est déjà GPL-3.** Aucun conflit avec microclimf/biljouR/
  lidR/lasR (tous GPL-3) → **tout reste dans `nemeton`**, `regen_nemeton`
  **abandonné**, ADR-014 **annulé** (sans objet). Dépendances lourdes en
  `Suggests` par hygiène, pas par licence.
- **Alignement doc GPL-3** : CLAUDE.md (ADR-006 « MIT (packages R) » → GPL-3),
  README (badge + description + section Licence). tree_sat/maestro laissés
  (LICENSE de leur repo fait foi) ; discordance nemetonshiny EUPL/GPL-3 signalée
  à Pascal. ADR-006 réel à réconcilier dans `platform_nemeton`.
- **Rien de nouveau au cœur avant validation** de la spec v2.1 (4 décisions §10,
  plus de blocage licence).
- **Arbitrage Pascal (2026-07-02)** des 4 décisions §10 : (1) `indice_priorite_regen`
  = croisement exposition × stress hydrique, **pénalité par essence gardée en
  option OFF par défaut**, colonnes renommées §7 ; (2) **SAFRAN primaire**,
  ERA5 repli ; (3) **tag « modèle mécaniste »**, NDP de base inchangé (étend
  `microclimate_model`) ; (4) **carte de tendances E-OBS dans la v1 mais sur
  l'emprise UGF + buffer** (à déterminer, défaut proposé ~25 km), pas nationale.
  Spec 027 v2.1 passée en statut « arbitrée, prête pour L1→L3 ». **Reste à
  préciser** : valeur du buffer. Reprise du code au feu vert de Pascal.

### 2026-07-02 — Spec 031 forêt ancienne : volet app livré (nemetonshiny v0.97.6)

Le câblage applicatif du helper `build_foret_ancienne_mask()` (cœur v0.113.0) est
livré et releasé côté **`nemetonshiny@v0.97.6`** (merge `f8d20fd3`, cycle dev
rouvert `0.97.6.9000`).

- [x] **App** : source forêt ancienne utilisateur (raster classé / vecteur) →
  `build_foret_ancienne_mask` → `indicateur_n2_continuite` (bloc `mod_project`,
  cache projet, i18n FR/EN). Livré `nemetonshiny v0.97.6`.
- **UI** (`mod_project`) : bloc optionnel — upload raster (`.tif`/`.tiff`) ou
  vecteur (`.gpkg`/`.shp`/`.geojson`), paramètres adaptés au type (`forest_class`
  peuplé via `terra::unique` / `threshold` / `min_area_m2`), aide i18n (sources
  Cassini / état-major / IGN ; Corona-4B exclu en France).
- **Calcul** : `build_foret_ancienne_layer` (appelle
  `nemeton::build_foret_ancienne_mask` + cache `<projet>/cache/layers/…`) →
  `vectors$foret_ancienne` → `indicateur_n2_continuite(foret_ancienne = …)`.
  Sans source fournie : N2 inchangé (aucune régression).
- **Cœur consommé** : `build_foret_ancienne_mask` (nemeton >= 0.113.0, v0.113.0).
- **Reste éventuel côté cœur** : recalibrage des bornes N2 (score 60-100 sur les
  zones de forêt ancienne) — à confirmer sur données réelles.

**Spec 031 close** (cœur v0.113.0 + app v0.97.6, tous deux releasés).

### 2026-07-02 — Added/Changed : A5 rafraîchissement urbain, spec 032 réorientée (cœur, v0.114.0)

Implémentation de la spec 032 **réorientée**. **K1 (données réelles)** : albédo
SWA (uint16 ×0.0001, national) ; LST (float32 **kelvin**, nodata -32768, id
`ECOSTRESS_STRASBOURG` = **métropoles seulement**). **Constat scientifique**
(risque D2 confirmé) : l'albédo n'est **pas** un proxy de rafraîchissement (la
canopée a un albédo bas comme l'eau ; radiativement l'albédo bas réchauffe →
erreur de signe). La LST est le seul signal juste mais ne couvre pas les
forêts. **Décision Pascal** : orienter vers l'**arbre en ville** (LST dispo =
métropoles = là où sont les arbres urbains).

**Slot** : A3/A4 déjà pris par la spec 027 (microclimat sous couvert
régénération) → nouvel indicateur = **A5 « Rafraîchissement urbain »**.
**Livré** : `indicateur_a5_rafraichissement(units, lst, reference, buffer_m,
delta_scale)` (`R/indicators-air.R`) — fraîcheur relative = LST UGF vs référence
locale (médiane anneau ou `reference` fixe), score 0-100 haut=frais (sens
direct), source-conditionnel (NULL→NA), nodata -32768 filtré, K/°C invariant.
**Albédo écarté** (non valide). `theia_lst`/`thermocity-lst` → `consumed_by: A5`.

**Cohérence** : A5 en config famille A + pass-through normalisation (pas
d'inversion), **pas** dans `list_indicators()` (conditionnel comme A3/A4/R5/T3).
CLAUDE.md table A = A1-A5. **Tests** : `test-indicator-a5.R` 12 PASS ; voisins
477 PASS (air, family, core, integration, microclimate). NAMESPACE + `_pkgdown.yml`
+ `man/*.Rd` à la main. Spec 032 pivotée (plan albédo conservé en trace).

**Bilan des specs 030-032** : 030 (SUFOSAT) tenue ; 031 (Corona) → helper N2 (source
morte) ; 032 (microclimat) → A5 urbain (albédo invalide). Seule 030 a tenu telle
que cadrée — les idées « indicateur depuis une source Theia » étaient survendues
au cadrage.

### 2026-07-02 — Added/Changed : forêt ancienne — helper N2, spec 031 réorientée (cœur, v0.113.0)

Implémentation de la spec 031 **réorientée**. **K1 (constats bloquants sur STAC
réel)** : (1) `corona-4b` = 3 items, tous au Moyen-Orient, **0 sur la France**
→ source morte ; (2) `indicateur_n2_continuite()` a **déjà** un argument
`foret_ancienne` (fraction ancienne → score 60-100) → un N4 dédié serait
**redondant**. **Décision Pascal** : abandonner N4, renforcer N2.

**Livré** : `build_foret_ancienne_mask(source, forest_class, threshold,
min_area_m2, crs)` (`R/indicators-naturalness.R`) — source-agnostique : vecteur
(validé/reprojeté/filtré) ou raster (masque par classe/seuil/`>0` → polygonisé
`terra::as.polygons` → taches contiguës → filtre aire). Sortie = couche sf
`foret_ancienne = TRUE` passée telle quelle à `indicateur_n2_continuite()`.
`corona-4b` **non déclaré** dans FR.json.

**Tests** : `test-foret-ancienne-mask.R` 6 PASS (classe, seuil, vecteur, filtre
aire, intégration N2 → 100, type invalide). NAMESPACE + `_pkgdown.yml` +
`man/build_foret_ancienne_mask.Rd` à la main. Spec 031 pivotée (v0.2.0, plan N4
conservé en `<details>`).

**Brief `nemetonshiny` fourni séparément** (upload source historique → helper →
N2) → **volet app livré `nemetonshiny@v0.97.6`** (cf. entrée du 2026-07-02 en
tête de journal). Specs restantes : 032 (microclimat albédo+LST).

### 2026-07-02 — Fixed : enrichissement BD Forêt sur géométrie invalide (cœur, v0.112.1)

Diagnostic d'un run réel Pascal (30 UGF, dépt 45) : `! BD Forêt intersection
failed: Loop 0 is not valid: Edge 105 is degenerate (duplicate vertex)` →
`species/age set on 0/30 UGF` → P/C/B retombent sur l'inventaire synthétique
CHM (qualité bois diamètre 0, CO2 évité 0). Cause : `enrich_parcels_bdforet()`
(`R/utils.R`) faisait un `st_intersection` unique dans un `tryCatch` qui, sur
une géométrie invalide, renvoyait NULL → tout NA. **Fix** : intersection brute
puis, en cas d'échec, réparation des deux couches par `sf::st_make_valid()` +
retry unique avant abandon (coût payé seulement sur échec). Tests :
`test-bdforet-enrich.R` **8 PASS** (mock : erreur au 1er intersect → retry réel
récupère l'essence ; échec persistant → NA ; chemin valide intact).

**Autres constats du même run (non corrigés ici, cf. réponse à Pascal)** : R5
NA = normal (aucune ingestion sanitaire → pas de FORDEAD) ; 3 warnings Theia
non bloquants (`s2_biophysical`/`theia_snow`/`theia_soil_moisture` à collection
`to confirm`) — IDs de collection réels désormais connus, câblage possible ;
`SPEI` absent → R3 défaut 0.5.

### 2026-07-02 — Added : T3 « Coupes rases » (SUFOSAT, spec 030, cœur, v0.112.0)

1ᵉ des 3 nouveaux indicateurs implémenté. **K1 (point dur R1)** : format des
assets SUFOSAT confirmé sur le STAC réel — `dates` en `YYDDD` (année 18-25,
jour 1-366, nodata 0), `proba` en pourcentage (nodata 0), une seule couverture
nationale, bucket S3 `sm1-gdc-ext`. **Implémentation** : `indicateur_t3_coupes_rases()`
(`R/indicators-temporal.R`) — extraction `exact_extract` d'un stack dates+proba,
décodage YYDDD → année, filtre `min_proba`, fenêtre `window_years`, pondération
récence linéaire, score = fraction de recouvrement pondérée (l'aire de maille
s'annule). Orienté **haut = mauvais** → inversion dans `normalize_indicator()`
(branche jumelle de R5). **Source-conditionnel** (NULL → NA, comme R5).

**Décision de cohérence** : T3 rejoint la config famille T (`indicator-config.R`)
+ la normalisation, mais **PAS `list_indicators()`** — qui reste les 31
indicateurs de base toujours calculables au NDP 0. R5 et T3 sont des indicateurs
**conditionnels d'extension** (dépendent d'une source externe). Compte CLAUDE.md :
31 base (33 avec R5 + T3 conditionnels).

**Tests** : `test-indicator-t3.R` **11 PASS** (fraction pondérée récence, filtre
proba, fenêtre, sans proba, NULL→NA, hors-raster→NA, aucune coupe→0, vide,
inversion normalisation). Voisins verts : indicators-core 202, integration-12-familles
91, family-system 95, normalization 278, temporal 144. Source `sufosat` déclarée
dans FR.json. NAMESPACE + `man/indicateur_t3_coupes_rases.Rd` à la main.

**Reliquat** : colonne T3 du fixture `massif_demo_units` (régénération `.rda`,
différée — `family-system` fait `intersect()` donc T3 absent = sans erreur) ;
wiring app `nemetonshiny` (radar T3, brief à fournir). Specs 031/032 (Corona, microclimat) restent à implémenter.

### 2026-07-02 — Cadrage : 3 nouveaux indicateurs depuis le catalogue Theia/MTD (specs 030-032)

Exploration du STAC `api.stac.teledetection.fr` (39 collections) pour de
nouvelles sources métier. **3 specs de cadrage écrites** (paperwork avant code,
non implémentées) :

- **spec 030 — T3 « Coupes rases » (SUFOSAT)** : détection submensuelle des
  coupes rases France métro. (radar S1, assets `dates`/`proba`). Indicateur
  inversé (haut = mauvais, comme R5). Famille T (Dynamique temporelle).
- **spec 031 — N4 « Forêt ancienne » (Corona 4B)** : continuité forestière
  depuis ~1968 via imagerie espion déclassifiée (asset `src` panchromatique).
  Conditionnel (comme R5). Famille N (Naturalité). Risque majeur : extraction
  forêt sur mono-bande 1968 + recalage géométrique.
- **spec 032 — A3 « Régulation thermique » (albédo S2 + LST)** : service de
  rafraîchissement. Albédo `cesbio-s2albedo` (national) = socle, LST
  `thermocity-lst` (5 métropoles seulement) = raffinement optionnel. **Résout**
  l'inadéquation `theia_lst → A2` du chantier Theia. S'aligne sur spec 027.
  Risque majeur : contresens physique de l'albédo (D2).

Chaque spec ajoute 1 indicateur (31 → 34 base) : impact `CLAUDE.md` (compte +
table familles) + `massif_demo_units` à l'implémentation. **En attente de
validation Pascal** avant tout code (aucun n'est prioritaire par défaut ;
reco d'ordre : 030 SUFOSAT > 031 Corona > 032 microclimat).

Autres pistes cataloguées (non spec'ées) : `geogedi` (structure verticale
B2/C1/P1), `cartofeux-lidarhd` (combustible R1), quick-wins sources `oso`,
`spot-6-7-trees-footprint`, `super-sentinel-2-l2a`, `french-tiled-rpg`.

### 2026-07-02 — Added : MUSCATE, 3e backend S2 de repli souverain (spec 029, cœur, K1→K3, cible v0.111.0)

Reliquat Theia `s2_l2a_muscate` attaqué (mode remote-control). **Décisions
utilisateur** : voie d'accès = **backend STAC Theia** (pas GEODES/pygeodes) ;
rôle = **repli souverain** (MUSCATE interrogé seulement si CDSE *et* PC échouent,
zéro changement par défaut). Spec `specs/029-muscate-fast-source/spec.md`.

**Découverte** : `services.theia_stac.url` était déjà renseigné et opérationnel
(`https://api.stac.teledetection.fr`, MTD, utilisé par FORMS-T/FORMSpoT) — le D1
« endpoint to confirm » de la spec était partiellement faux, seul l'**ID de
collection MUSCATE** manquait.

**K1 (FR.json)** : `datasets.s2_l2a_muscate.access` gagne `stac_api_service`,
`stac_collection` (**provisoire** `"SENTINEL2-L2A-THEIA"`, `stac_collection_status:
provisional`), `reflectance_product: SRE` (D3). Le backend lit api+collection
depuis la config → un mauvais ID = correction d'une ligne JSON, **zéro changement
de code**.

**K2 (`R/sentinel2.R`)** : nouveau backend exporté `stac_search_s2_theia_muscate()`
+ helpers internes `.muscate_collection()`, `.muscate_reflectance_product()`,
`.muscate_band_asset_keys()` (dialecte `SRE_B4`/`FRE_B4`/`B4` → clés nemeton
`B02/B04/…`, SRE prioritaire, D2/D3), `.muscate_asset_href()`,
`.muscate_remap_feature()`. Réutilise `stac_search_items()` + `.theia_href_to_gdal()`
(→ `/vsis3/`) + `.features_to_tibble()`. Filtre nuage au niveau scène (parité
cdse/pc ; NA gardé). **Dédup inerte pour MUSCATE** (IDs Theia ne matchent pas les
regex S2 → clé unique, aucun collapse) — pas de bypass nécessaire (D5 simplifié).

**K3 (`stac_search_s2()`)** : `match.arg(source, c("cdse","pc","muscate"))` +
branche `switch(muscate=…)` ; **défaut** passé à `c("cdse","pc","muscate")` (repli
transparent, inerte en marche nominale car MUSCATE n'est atteint qu'après échec
des deux autres).

**Tests** : `test-sentinel2-muscate.R` **26 PASS** (mapping bandes SRE/FRE/zéro,
remap feature → /vsis3/, tibble normalisé, filtre nuage + NA gardé, repli
cdse+pc→muscate, marche nominale = MUSCATE jamais appelé, invariance NDVI ×10000
D4). Voisins re-vérifiés : test-sentinel2 77, dedup 16, cache 30, theia-stac 30 —
tous verts. Test existant « both backends silent » mis à jour (mocke aussi
muscate, sinon atteindrait le vrai backend → réseau). NAMESPACE + `man/sentinel2_stac.Rd`
édités à la main (pas de `document()`).

**K4 (smoke réel, fait 2026-07-02)** : STAC live interrogé directement. **ID de
collection confirmé** = `sentinel2-l2a-theia` (« Sentinel-2 Level 2A from CNES and
CESBIO » = MUSCATE/MAJA ; le provisoire `SENTINEL2-L2A-THEIA` était faux → corrigé
dans FR.json, `stac_collection_status: confirmed`). **D2** : bandes exposées
directement sous `B02/B04/B05/B08/B8A/B11/B12` (fichiers FRE sous-jacents), pas
`SRE_B4` — le candidat nu du mapping les capte. **D3** : FRE servi (pas de variante
SRE). **D4** confirmé : `scale 1.0 offset 0.0` int16 nodata −10000 → NDVI/NBR
invariants (pas de biais inter-source ; nodata −10000 à masquer). **D6** :
`eo:cloud_cover` (identique cdse/pc). Run `stac_search_s2_theia_muscate()` end-to-end
= **5 scènes réelles** (T31TGN/T31UGP, filtre nuage OK, hrefs `/vsis3/s2-theia/…`
corrects, bandes requises présentes). +1 test format réel → `test-sentinel2-muscate.R`
**28 PASS**.

**K5 (release, 2026-07-02)** : bump DESCRIPTION `0.110.1.9000 → 0.111.0` + NEWS +
CITATION + CHANGELOG cohérents, PR vers main → `release.yml` taggue v0.111.0.
Feature **entièrement validée** ; le seul run manquant est la lecture S3 réelle des
COG (credentials `theia_s3`) au moment d'une vraie ingestion de repli — indépendant
du contrat STAC ici testé. **Spec 029 close côté cœur.**

### 2026-06-17 — Changed : FORDEAD ingest — retrait du fallback bbox-des-placettes (spec 017, cœur, v0.91.2)

Suite à la question de Pascal « pourquoi FORDEAD parle de placette ? » : c'est un
**reliquat** d'avant spec 012/017, quand l'emprise du cache S2 dérivait de la
position des placettes (bbox + buffer `radius_m`). FORDEAD est **par pixel**,
indépendant des placettes. Demande : « supprime la référence à la bbox des
placettes ». **Livré** : dans `ingest_s2_raw_bands_to_cache()`
(`R/sentinel2_cache.R`) on retire `.fetch_plots_sf()` **et** le fallback
`st_bbox(plots)` (zone sans `zone_wkt`). Désormais : AOI = `zone_wkt`
exclusivement ; zone sans géométrie exploitable → warning « no usable zone_wkt »
+ résultat vide (invite à `register_monitoring_zone()`), pas de reconstruction
depuis les placettes. `n_plots` du payload `s2:search` = `0` (placette-
indépendant). Complète le fix v0.91.1 (suppression du buffer mort qui plantait).
Tests `test-sentinel2-cache.R` : « FORDEAD ingest is placette-independent —
never reads plots » (mock `.fetch_plots_sf` qui `stop()` → échoue si appelé) ;
« no usable zone_wkt → vide + warning ». `test-fordead-pipeline.R` (78),
`test-aoi-alignment.R` (18) verts. `.fetch_plots_sf` reste défini/utilisé
ailleurs (FAST), pas de référence pendante.

### 2026-06-17 — Fix : diagnostic FORDEAD plantait sur zone sans placette (spec 017, cœur, v0.91.1)

Bug remonté en prod (zone 5, log : « pipeline starting … Dropped 48 duplicates …
pipeline failed: Not compatible with requested type: [type=NULL; target=double] »).
**Diagnostic** (via le log) : l'erreur tombe juste après le dedup STAC, dans
`ingest_s2_raw_bands_to_cache()` (`R/sentinel2_cache.R`), à la ligne
`buf <- sf::st_buffer(plots_proj, dist = plots_proj$radius_m)`. Sur une zone
**géométrie-seule** (sans placette, défaut spec 017), `.fetch_plots_sf()` renvoie
un `sf` 0 ligne **sans colonne `radius_m`** → `plots_proj$radius_m` = `NULL` →
`st_buffer(dist = NULL)` lève l'erreur vctrs. Aggravant : `buf` était du **code
mort** (commentaire « FORDEAD doesn't use buf after this » ; seul `crop_geom <-
aoi_zone` sert, l.150 `.get_s2_band_raster`). La spec 017 (ingest placette-
indépendant) avait oublié de retirer ces 2 lignes. **Fix** : suppression de
`plots_proj`/`buf` (inutiles + plantent). Régression `test-sentinel2-cache.R` :
« placette-less zone ingests without crashing » (`.fetch_plots_sf` → sf 0 ligne,
`.get_zone_aoi` → AOI valide → ingest OK, 2 scènes). **Drive-by** : test périmé
« no plots → … warning » attendait encore « No plots » (message réécrit en
v0.83.3 « neither zone_wkt nor any registered plot ») — échouait en local,
skippé en CI (terra) ; corrigé. Suites `test-fordead-pipeline.R` (78),
`test-aoi-alignment.R` (18) vertes.

### 2026-06-17 — Added : `smooth_pixel_series(method="harmonic")` — lissage saisonnier continu (spec 026, cœur, v0.91.0)

Suite à la question de Pascal : la médiane glissante laisse des trous (hiver/
nuages) car c'est un dénoiseur **local** ; quelle méthode mieux adaptée aux
**trous saisonniers** ? Réponse : la **décomposition harmonique** (HANTS/BFAST/
CCDC, cohérent FORDEAD harmonique ADR-013). Paperwork-first : amendement spec
026. **Livré** : 3ᵉ méthode `harmonic` dans `smooth_pixel_series()` —
régression harmonique robuste (helper interne `.harmonic_fit()` : `n_harmonics`
paires de Fourier annuelles + tendance linéaire, **IRLS** poids biweight Tukey
c=4.685, échelle MAD, phase sur `t` absolu pour cohérence inter-années, tendance
centrée/échelle années pour le conditionnement). Modélise le cycle → **courbe
continue** sur les trous. Garde-fous : `>= 2K+4` points clairs **et** étendue
`>= 0.75·365.25` (~9 mois) sinon NA ; rang-déficient → NA via tryCatch. Base R
(`lm.wfit`/`median`), **aucune dépendance**. Nouveau param `n_harmonics` (1:3).
**Caveat** documenté : `harmonic` = courbe **modélisée** (hiver interpolé), pas
de la donnée brute. **Densification** : la fonction prédit à toutes les lignes
(y compris `value=NA`) → l'app obtient une courbe pleinement continue en
ajoutant une grille de dates régulières NA à `ts`. Le **déclin pluriannuel**
reste au mode `trend` (la tendance harmonique sert l'affichage, pas l'alerte).
Doc roxygen + `man/smooth_pixel_series.Rd` (édité main). Tests
`test-smooth-pixel-series.R` (28) : continuité sur trous saisonniers + corrélation
au signal saisonnier > 0.9 malgré spikes, densification grille NA, série trop
courte → NA, validation `n_harmonics`. `test-pixel-map.R` (69) inchangé.

### 2026-06-17 — Added : `smooth_pixel_series()` — lissage robuste série pixel (spec 026, cœur, v0.90.0)

Demande : le graphe « série pixel » (NBR/NDMI/NDVI par scène, modale clic carte)
relie chaque acquisition → dents de scie illisibles (bruit nuages/ombres/neige).
Pascal valide l'**Option B** (lissage dans le cœur, app affiche). Paperwork-first :
spec 026. **Livré** : `smooth_pixel_series(ts, window_days = 45, method =
c("rolling_median","loess"), min_obs = 3L)` (`R/pixel-map.R`) qui ajoute une
colonne `smoothed` par indice à la sortie de `extract_pixel_timeseries()`.
**Défaut médiane glissante** sur fenêtre **temporelle** centrée (jours,
échantillonnage irrégulier) → robuste aux spikes nuageux (≠ moyenne mobile/LOESS
qui les suivent) ; option **loess** `family="symmetric"` (temps centré contre
l'instabilité « pseudoinverse » des jours-époque ; span plancher 0.3 contre le
sur-ajustement). NA-aware, sans dépendance nouvelle. Opère à l'échelle **scène**
(le lissage saisonnier annuel reste le rôle du `trend`). App : points bruts
estompés + ligne lissée. Tests `test-smooth-pixel-series.R` (18) : absorption de
2 spikes nuageux (médiane reste ~0.7), lissage par indice indépendant, `min_obs`
(NA si trop épars / point unique → soi-même), NA ignorés autour d'un trou, loess
sans NA + variance réduite. `test-pixel-map.R` (69) inchangé. Doc à la main
(`man/smooth_pixel_series.Rd`, NAMESPACE, `_pkgdown.yml`). Plancher app à venir
`nemeton (>= 0.90.0)`.

### 2026-06-17 — Added : seuil `min_slope` — calibration trend Mann-Kendall (spec 023, cœur, v0.89.0)

Constat (issu du bug v0.88.1 « points hors zone ») : même confiné à la zone, le
trend flaggait des `alert_value` ≈ 0.0001 NDRE/an — déclins **statistiquement
significatifs** (Mann-Kendall très sensible sur séries longues : une dérive
monotone minuscule a p<0.05) mais **écologiquement négligeables**. Significativité
≠ pertinence. **Fix** : nouveau paramètre **`min_slope`** (seuil de magnitude,
indice/an) — un pixel n'est une alerte que si `pente<0 & Mann-Kendall significatif
& |pente| >= min_slope`. Câblé partout : helpers `.trend_fit_cells()` /
`.trend_fit_one()` / `.fast_raster_trend()` (défaut helper 0 → pas de régression
des tests internes), publiques `read_fast_alert_raster()` /
`read_fast_alert_rasters()` / `extract_pixel_trend()` / `extract_trend_series()`
/ `create_trend_sanitary_plan()` (défaut **0.005**). Intégré au **hash de cache
D6** (`.fast_raster_hash` trend block) → un changement invalide les COG trend ;
nom de fichier inchangé (hash8 discrimine). count/rolling **byte-identiques** (le
bloc trend du hash n'existe qu'en trend). **Défaut 0.005 PROVISOIRE** — ≈ 0.03–0.05
de chute NDRE totale sur une fenêtre typique ; à calibrer contre vérité terrain
(ONF/DSF). `min_slope=0` = comportement ≤ v0.88.1. Doc roxygen + 5 `.Rd` (édités
main). Tests : `test-extract-pixel-trend.R` (+1 : déclin ~0.001/an significatif
mais sous seuil → non alerté ; alerté de nouveau avec `min_slope=0`) ; suites
trend (fast-trend 49, fast-alert-raster 56, extract-pixel 29, extract-series 22,
sanitary 26) vertes. **À suivre** : caler `min_slope` (+ éventuellement un plancher
de durée / d'amplitude relative) sur les placettes validées une fois le terrain
disponible.

### 2026-06-16 — Spec 023 (graphe trend par pixel) livrée
- **Cœur nemeton v0.87.0** : `extract_pixel_trend()` (composites saisonniers
  annuels + Theil-Sen + Mann-Kendall par pixel, cohérent avec
  `compute_fast_alert_mask(mode="trend")` : `alert_value` == valeur
  pré-quartile du raster) et `extract_trend_series()` (overview zone).
- **App nemetonshiny@6b525470 (v0.86.0)** : clic carte Alertes FAST (mode
  Tendance) → modale graphe trajectoire NDRE (points composites + droite
  Theil-Sen + pente/p-value/sévérité), bouton plein écran ; correctif
  redimensionnement plein écran nemetonshiny@837048eb (v0.86.1).
- Plancher app relevé : `nemeton (>= 0.87.0)`.

### 2026-06-16 — Spec 025 (plan sanitaire sur le trend, Option A) livrée
- **Cœur nemeton v0.88.0** : `create_trend_sanitary_plan(con, zone_id, …)` —
  placettes sanitaires pondérées ∝ |pente| (déclin significatif), témoins
  sur cellules stables ; sf POINT 2154 (plot_id S##/T##, type, alert_value,
  index, source "FAST_TREND", seed) ; erreur typée `nemeton_empty_alert_mask`
  si aucun déclin significatif.
- **App nemetonshiny@68faa51c (v0.87.0)** : sous-onglet « Plan de validation
  FAST » rebranché sur le trend (wrapper `generate_trend_sanitary_plan()`),
  sidebar refondue (indice, fenêtre pluriannuelle, placettes
  sanitaires/témoins, params avancés ; retrait classes/témoins/tampon),
  carte colorée par sévérité continue, message « aucun déclin significatif ».
  FORDEAD/RECONFORT inchangés. Plancher app : `nemeton (>= 0.88.0)`.

### 2026-06-16 — Fix : `create_trend_sanitary_plan()` tirait hors de la zone (spec 025, cœur, v0.88.1)

Bug remonté en prod (app, écran « Plan de validation FAST ») : les placettes
sanitaires apparaissent **dispersées sur toute la tuile S2 (~100 km)**, pas dans
l'UGF (petit polygone), avec `alert_value` ≈ 0.0001. **Cause** : quand le
polygone UGF n'est pas résolu (`poly = NULL`), `.apply_zone_mask(r, NULL)` est un
**no-op** → `read_fast_alert_raster(mode="trend")` renvoie le raster **pleine
tuile non masqué** → `create_trend_sanitary_plan` tire GRTS partout. Pour un plan
d'échantillonnage, ce repli silencieux est inacceptable. **Fix** : la fonction
**résout le masque en amont** (`mask_polygon %||% .get_zone_aoi(con, zone_id)`) et
**abort** avec l'erreur typée `nemeton_zone_mask_unresolved` si introuvable, au
lieu de tirer sur la tuile ; le polygone résolu est passé explicitement à
`read_fast_alert_raster`. Recommandation app : passer `mask_polygon = <zone sf>`
(déjà disponible — la zone est dessinée) → confinement garanti, pas d'aller-
retour DB. Tests : refus sans masque résoluble (`nemeton_zone_mask_unresolved`),
acceptation d'un `mask_polygon` explicite ; appels mockés passés en
`apply_zone_mask = FALSE`. Suite `test-trend-sanitary-plan.R` 26 verte. Doc +
spec 025 amendées. **Note connexe** (non corrigée ici) : `alert_value` minuscule
= significativité Mann-Kendall très sensible sur séries longues — à recalibrer si
besoin une fois le masque correct (les `|pente|` intra-zone seront plus parlants).

### 2026-06-16 — Added : `create_trend_sanitary_plan()` — placettes sanitaires sur le trend (spec 025, cœur, v0.88.0)

Demande : calculer le plan de validation **sur le trend NDRE** avec GRTS,
**mais** — précision de Pascal en cours de route — ce sont des **placettes
SANITAIRES autonomes**, **aucun rapport avec les placettes terrain**, et **pas
de TSP**. Paperwork-first : spec 025 rédigée (`specs/025-trend-validation-
sampling/spec.md`) avant code. **Livré** : `create_trend_sanitary_plan(con,
zone_id, date_from, date_to, cache_dir, index="NDRE", n_plots=20, n_control=5,
months=6:9, min_years=4, min_obs_per_year=2, alpha=0.05, apply_zone_mask,
mask_polygon, seed)`. Méthode : (1) raster trend continu via
`read_fast_alert_raster(mode="trend")` (NULL → erreur typée
`nemeton_empty_alert_mask`) ; (2) cellules `value>0` = candidats sanitaires
pondérés par `|pente|` ; (3) **GRTS à probabilité continue** `spsurvey::grts(…,
aux_var="alert_value")` (nouveau helper `.draw_grts_continuous()`) — l'inclusion
suit la magnitude brute du déclin, pas une classe quartile ; (4) témoins
équiprobables sur cellules stables `value==0` (`.draw_grts_equiprobable`
réutilisé ; NA = années insuffisantes, exclu) ; (5) assemblage **trié par
sévérité décroissante** (`S01`=plus fort), **sans tournée TSP**, sans toucher la
table `plot`. Sortie `sf` : `plot_id` (`S##`/`T##`), `type`
(`Sanitaire`/`Temoin`), `alert_value`, `index`, `source="FAST_TREND"`, `seed` —
**pas** d'`visit_order`. Cohérence : `alert_value` == `extract_pixel_trend(xy)
$alert_value` == valeur pré-quartile du raster (même `|pente|` partout). Doc à la
main (`man/create_trend_sanitary_plan.Rd`, NAMESPACE, `_pkgdown.yml`). Tests
`test-trend-sanitary-plan.R` (23) : helper GRTS continu sur cellules >0, plan
Sanitaire+Temoin (pas de `visit_order`, tri décroissant, S01 max, témoins=0),
repro seed, `n_control=0`, erreurs typées (pas de déclin / raster NULL).
Validation terrain (spec 014) **inchangée** (27 verts). Côté app : sélecteur
indice trend + bouton « plan sanitaire » → `create_trend_sanitary_plan`,
affichage carte des `S##`/`T##` (couleur ∝ `alert_value`), plancher
`nemeton (>= 0.88.0)`.

### 2026-06-16 — Added : `extract_pixel_trend()` — diagnostic trend au pixel cliqué (spec 023, cœur, v0.87.0)

Brief CŒUR transmis depuis la session `nemetonshiny` (parité avec
`read_reconfort_pixel_series`, mais signature `cache_dir`/`scenes_df` retenue —
l'app a déjà les deux et ça **contourne le bug multi-tuiles** v0.85.1). Besoin :
le graphe « pourquoi ce pixel a cette couleur » → équivalent **par pixel** du
raster trend. **Livré** : `extract_pixel_trend(cache_dir, scenes_df, xy,
crs=4326, index="NDRE", months=6:9, min_years=4, min_obs_per_year=2,
alpha=0.05, zone_polygon, warn_outside_zone)`. Algo : (1) série brute par scène
au point via `extract_pixel_timeseries()` (extraction scène par scène, pas de
mosaïque → immunisé `[mosaic] resolution does not match`) ; (2) composite
**identique** au raster (filtre `months`, médiane/an des valeurs claires, année
< `min_obs_per_year` → NA) ; (3) fit via le **helper partagé** `.trend_fit_one()`
(`.theil_sen` + `.mann_kendall`, intercept `median(y-pente·x)`) — extrait pour
être appelé par `extract_pixel_trend` ET `extract_trend_series` (refactorisé) et
cohérent avec `.trend_fit_cells()` vectorisé du raster ; (4) `alert_value` =
`abs(pente)` si déclin significatif, `0` sinon, **`NA` sous `min_years`**
(NA-masqué comme le raster). Retour `list(index, composites[year,value],
n_years, theil_sen_slope/intercept, mann_kendall_p/tau, significant_decline,
alert_value, enough_years)`. Classe 0-4 **non** renvoyée (quartiles zone-wide →
l'app lit la classe dans le raster mask au pixel). Doc à la main
(`man/extract_pixel_trend.Rd`, NAMESPACE). Tests `test-extract-pixel-trend.R`
(déclin significatif, série plate→0, < min_years→NA, hors saison→NULL, **non-
régression croisée pixel==raster** : `alert_value == read_fast_alert_raster(
mode="trend")` au pixel, fixture spatialement constante). Suites voisines vertes
(extract-trend-series 22, fast-trend 49, fast-alert-raster 56, pixel-map 69).
Ordre cœur→app : release nemeton@v0.87.0 → l'app consomme via `@*release`.

### 2026-06-16 — Added : `extract_trend_series()` — trajectoire annuelle pour le graphe d'onset (spec 023, cœur, v0.86.0)

Suite à l'échange sur « comment sont calculées les alertes NDRE-trend et quel
graphe montrerait *à partir de quand* elles arrivent ». Constat : le mode
`trend` réduit chaque pixel à **une seule pente** → la carte ne porte aucune
information d'onset ; l'info temporelle est dans les **composites annuels**
que `.fast_raster_trend()` construit puis jette. **Livré** : helper exporté
`extract_trend_series(con, zone_id, index="NDRE", date_from, date_to,
cache_dir, months=6:9, min_years=4, min_obs_per_year=2, alpha=0.05,
apply_zone_mask, mask_polygon, parallel)` qui ressort la **série annuelle de
composites estivaux au niveau zone** + le fit Theil-Sen / Mann-Kendall.
Implémentation : factorisation du composite annuel dans
`.trend_yearly_composite()` (partagé avec `.fast_raster_trend()`, refactor pur
→ 49 tests trend inchangés), puis par-tuile composite → masque UGF (poly
reprojeté en CRS natif) → moyenne spatiale + comptage `notNA` via
`terra::global`, combinaison multi-tuiles en **moyenne pondérée par pixels
valides** par année (pas de mosaïque CRS : on agrège des scalaires). Fit :
`.theil_sen` + `.mann_kendall` sur la série `(année, valeur)`, intercept =
`median(y - pente·x)`, `significant` = pente<0 & p<alpha, `alert` =
`abs(pente)` si significatif (= magnitude que `compute_fast_alert_mask`
discrétise). Retour `list(series[year,n_scenes,value,fitted], fit, index,
months, alpha)` — `series` directement traçable (points + droite). Conçu pour
le graphe « trajectoire NDRE + tendance » côté `nemetonshiny` (graphe #1
recommandé). Doc à la main (`man/extract_trend_series.Rd`, NAMESPACE).
Tests `test-extract-trend-series.R` (22) : déclin NDRE monotone significatif
(alert==abs(slope), p<0.05, fitted décroissant), fit NULL sous min_years,
NULL hors saison, validation des entrées. Suites voisines vertes (fast-trend
49, fast-alert-raster 56, ndre 20).

### 2026-06-16 — Fix : mosaic multi-tuiles NDRE 20 m (`resolution does not match`, spec 023, cœur, v0.85.1)

Bug remonté en prod (zones 5/6/7, cache `…/20260517_103553_vyso`, NDRE trend,
2017→2024) : `compute_fast_alert_mask(index="NDRE", mode="trend")` plante avec
`[mosaic] resolution does not match` quand la zone chevauche **2 tuiles MGRS**
(T31TFM + T31TGM), bandes B05/B8A en cache à 20 m. **Cause** : dans le chemin
multi-tuiles de `read_fast_alert_raster()`, chaque raster d'alerte par-tuile
est projeté vers EPSG:2154 **indépendamment** (`terra::project(rn, "EPSG:2154")`
sans grille cible) → terra dérive une résolution de sortie propre à l'étendue
de chaque tuile ; deux tuiles 20 m tombent sur des résolutions très légèrement
différentes et `terra::mosaic()` refuse de fusionner. Le 10 m (NDVI/NDMI) ne
reproduisait pas (arrondi par chance à la même résolution → mosaïque combinée
réussie). **Fix** : nouveau helper interne `.mosaic_per_tile(rasters, method)`
qui **rééchantillonne toutes les tuiles sur une grille EPSG:2154 commune**
(résolution de la 1ʳᵉ tuile, étendue union **snappée** sur des multiples de
cette résolution — `terra::rast(ext, resolution=)` triche sinon la résolution
pour diviser un extent quelconque, ré-introduisant la dérive — puis
`terra::resample()` méthode mode-dépendante) avant `mosaic(fun="max")`. Mono-
tuile et indices 10 m **inchangés**. Régression `test-fast-alert-raster.R` :
deux tuiles EPSG:2154 à résolutions 20 / 20,05 que `terra::mosaic()` rejette
(`expect_error`) → helper rend une mosaïque à résolution unique 20, étendue
union, valeurs des deux tuiles préservées. **Drive-by** : durci le skip du
smoke-test villards (DB joignable mais schéma absent → **skip** au lieu
d'**error**). Tests verts (terra local) : fast-alert-raster 56 (+1 skip),
fast-trend 49, ndre 20, ndmi 20, prewarm 31.
>
> *2026-06-27 (durcissement couverture, dev cycle)* : ajout d'un **test
> d'intégration bout-en-bout** du chemin NDRE `trend` multi-tuiles dans
> `test-fast-alert-raster.R` — fixture cache 2 tuiles (T31TFM ⊂ T31TGM,
> bandes B05+B8A à 20 m, 5 ans × 2 obs estivales, déclin NDRE strict). Il
> exerce `read_fast_alert_raster()` → `.fast_raster_trend()` →
> `.mosaic_per_tile()` et vérifie qu'on obtient une mosaïque unique
> EPSG:2154 (pas d'abort « resolution does not match »), couvrant l'union
> des deux tuiles, avec une magnitude de déclin non nulle. Le test unitaire
> sur `.mosaic_per_tile()` (résolutions 20 / 20,05) reste en place ; ce
> nouveau test couvre le chemin réel, pas seulement le helper. Aucun
> changement de code fonctionnel → pas de bump (cycle dev `0.94.2.9000`).
> PR #121 mergée.
>
> *2026-06-27 (validation terrain — chantier CLOS)* : confirmation côté app
> (`nemetonshiny`) que les **alertes NDRE Tendance s'affichent bien sur
> Mouthe**. Le fix v0.85.1 est validé de bout en bout (cœur mosaïque
> commune + test d'intégration ; app affichage). **Bug NDRE Tendance
> multi-tuiles MGRS : clos**, plus rien en suspens.

### 2026-06-15 — FAST : wrapper étendu au `trend` + red-edge systématique (spec 023, cœur, v0.85.0)

Complément à la v0.84.0 (pré-chauffe `trend`, PR #75 mergée en parallèle par
une autre session). Demande de Pascal : « l'ensemble des indices doivent être
systématiquement calculés en mode FAST (NDMI/NDVI/NBR **et** NDRE) ». La
v0.84.0 ne couvrait que la **pré-chauffe** ; ce cycle ajoute les deux pièces
manquantes. **Livré** : (1) **wrapper** `read_fast_alert_rasters()` étendu au
`trend` — défauts `c("NDVI","NBR","NDMI","NDRE")` × `c("count","rolling","trend")`
→ **8 cartes**, paires absurdes (NDVI_trend, NDRE_count) écartées, params trend
(`months`/`min_years`/`min_obs_per_year`/`alpha`) exposés ; prédicat interne
`.fast_alert_combo_ok()` / `.fast_alert_combos()` énumérant les paires valides.
(2) **red-edge systématique** — `ingest_sentinel2_timeseries()` cache B05 + B8A
**best-effort sur chaque ingestion** (comme B11, spec 019 D3), même avec le
défaut `bands = c("NDVI","NBR")` → les 4 indices FAST toujours calculables sans
`bands = "NDRE"`. B05/B8A étant des bandes 20 m standard de toute scène S2 L2A,
le best-effort aboutit toujours → supprime à la source le soft-skip `NDRE_trend`
de la pré-chauffe sur les ingestions fraîches (le gating de #75 reste un filet
de sécurité pour les caches legacy). **Reconciliation #75** : ma branche
(basée sur l'ancien `main`) avait dupliqué la pré-chauffe et visé 0.84.0 ;
rebase sur `main`, on **conserve la pré-chauffe rbind de #75** (déjà testée) et
on ne garde que le delta net (wrapper + red-edge systématique), bump **0.85.0**.
Doc à la main (`man/read_fast_alert_rasters.Rd`, `man/ingest_sentinel2_timeseries.Rd`).
Tests **verts** (terra local) : `test-ndmi.R` (wrapper 8 cartes, sous-ensemble,
paires absurdes), `test-ndre.R` (ingest cache B05/B8A best-effort),
`test-prewarm-fast-alerts.R` / `test-fast-alert-raster.R` / `test-fast-trend.R` /
`test-monitoring.R` inchangés et verts.

### 2026-06-15 — Release v0.84.0 (added — pré-chauffage FAST `trend`, spec 023, cœur)

`.prewarm_fast_alerts()` (déclenché par `ingest_sentinel2_timeseries(prewarm_alerts
= TRUE)`) pré-calcule désormais **8 combos** au lieu de 6 : aux 6 historiques
`{NDVI, NBR, NDMI} × {count, rolling}` (spec 019) s'ajoutent **2 combos trend**
`{NDMI, NDRE} × {trend}` (spec 023). Rationale : `trend` cible le dépérissement
chronique feuillus → indices pertinents = NDMI (B11) + NDRE (B05/B8A) ; NDVI/NBR
restent count/rolling. Le warm `trend` utilise les défauts cœur `months=6:9`,
`min_obs_per_year=2`, `min_years=4`, `alpha=0.05` (mêmes valeurs que
`read_fast_alert_raster`) ; `threshold`/`window_days` non passés. COG sous le même
schéma `<prewarm_mask_cache_dir>/zone_<id>/` que les autres combos. Best-effort :
`*_trend` ne tourne que si les bandes red-edge (B05+B8A) / B11 sont en cache, sinon
**skip** sans faire échouer l'ingestion (comme les scènes sans href). Nouveaux
events `fast_prewarm:{NDMI,NDRE}_trend{,_done,_failed}` au format existant ;
`fast_prewarm:complete`/`:cancelled` inchangés. Tests `test-prewarm-fast-alerts.R` :
« the eight combinations » (8 COG + events trend, back-compat des 6 noms
count/rolling), cas red-edge absent (NDRE trend skippé sans erreur, NDMI trend
rendu), per-combination failure étendu aux 2 combos trend. **Débloque** le
câblage `nemetonshiny` : radio 3 modes, indice NDMI par défaut en trend, `bands +=
"NDRE"`, params trend en sidebar conditionnelle, mapping toast `fast_prewarm:*_trend`,
bump app **0.85.0** + plancher `Imports: nemeton (>= 0.84.0)`.

### 2026-06-14 — Fix tests : mocks `.cache_scene_bands` réalignés (`optional_bands`, spec 019)

6 tests d'intégration (`test-monitoring.R` ×4, `test-ingest-cancel.R` ×2)
échouaient **en local** : les mocks de `.cache_scene_bands` n'acceptaient pas
l'argument `optional_bands` (B11 cachée best-effort, spec 019 D3) que la prod
passe désormais. L'appel mocké levait « unused argument », avalé par le
`tryCatch` d'ingestion → toutes les scènes silencieusement skippées (compteurs à
0, répertoires COG non créés). Invisible en CI (tests *skipped* faute de
`NEMETON_DB_URL_TEST`). Trois mocks réalignés (`.make_caching_mock`, `fake_cache`
×2) avec `optional_bands = NULL, ...` + création des bandes optionnelles.
Suites monitoring/aoi/ingest/health/reconfort-ingest 335 ✔, 0 fail.

### 2026-06-14 — `nemetonshiny@315a7409` (v0.84.0) : perf chargement projet — sync PostGIS async (app)

`nemetonshiny@315a7409` (v0.84.0) : perf chargement projet — dernier maillon
synchrone retiré du chemin critique. La synchronisation PostGIS best-effort
(`db_sync_project` : connexion + `st_write` parcelles + `dbWriteTable`
indicateurs) tournait dans un callback `later::later(0.5)` — donc sur le THREAD
PRINCIPAL R — et gelait l'event loop Shiny juste après le 1ᵉʳ flush carte
(overlay/`fitBounds`/sélection bloqués), d'où le délai ressenti entre « Connected
to PostgreSQL » et l'affichage des parcelles. Fix : nouveau
`db_sync_project_async()` exécutant le sync dans un worker `future` (hors thread
principal, dispatch ~0 ms), miroir des runs FORDEAD/RECONFORT (reload paquet +
replay env DB côté worker, dont `POSTGRESQL_ADDON_*`) ; fallback `later()` si
`future`/`promises` absents. Aucun changement cœur. Clôt le chantier
perf-chargement côté app (v0.78.0 skip DB inutile + `ug_build_sf` différé ;
v0.79.0 `connect_timeout` ; v0.79.1 fix contexte réactif + gating toast ;
v0.84.0 sync async).

### 2026-06-14 — Fix : ingestion S2 placette-indépendante (spec 017, cœur, v0.83.3)

Bug latent révélé par le passage du début FAST à 2017 (app) : les deux ingests
(`ingest_sentinel2_timeseries`, `ingest_s2_raw_bands_to_cache`) **exigeaient des
placettes** (garde-fou « No plots registered ») alors que depuis spec 017
l'ingestion est un amorçage de cache piloté par `zone_wkt` et le diagnostic est
per-pixel (placette-indépendant, `obs_pixel` supprimé en v0.58.0). Or l'app crée
les zones **sans placette** (`create_monitoring_zone`/`build_project_monitoring_zones`,
« geometry only »). Conséquence : toute zone créée depuis spec 017 ne pouvait
pas amorcer son cache — masqué tant que le cache était chaud, révélé dès que la
fenêtre dépassait les scènes cachées (« Aucune scène S2 + No plots registered for
zone_id 5 »). Fix : résoudre l'AOI **d'abord**, placettes seulement pour le
fallback bbox legacy (zone sans `zone_wkt`). Nouveau test `test-aoi-alignment.R`
(zone WKT sans placette → ingestion procède) + test « no plots » repurposé sur la
branche « ni WKT ni placette ». Suite aoi-alignment verte ; 4 échecs résiduels
`skip_cached`/`cache_dir` **préexistants** (baseline, sandbox, hors périmètre).

### 2026-06-14 — ADR-014 (draft) : cube spatio-temporel pour le `trend` régional (doc pure)

Rédigé `specs/024-cube-spatiotemporel-trend/ADR-014_Cube_spatiotemporel_trend.md`
(statut **Proposé**, à porter vers `nemetonplateform/docs/` comme l'ADR-013).
Décision : **conserver terra (Option A)** tant que le `trend` reste à l'échelle
UGF mono-/bi-tuile ; **basculer vers l'hybride (Option D : composite via
`gdalcubes` + fit vectorisé `.trend_fit_cells`)** dès qu'un seuil est franchi
(emprise > ~2-3 tuiles MGRS / hors-RAM, carte régionale EPSG:3035 ADR-008, ou
biais de recouvrement P3 devenu métier-significatif). Options B (gdalcubes
bout-en-bout) **rejetée** (perd l'acquis vectorisé), C (`stars`) en réserve.
Pas de bump (doc pure).

### 2026-06-14 — Fix garde-fou NDRE (cli) + doc P3 recouvrement tuiles (spec 022/023, cœur, v0.83.2)

Deux suites de la revue `trend`. **Bug pré-existant** : `.assert_cache_has_bands()`
(garde-fou NDRE, spec 022) plantait sur cli récent — « Multiple quantities for
pluralization » quand les **deux** bandes red-edge (B05+B8A) manquaient (le
`{?s}` interpolait `missing` *et* `cache_dir`, longueurs différentes). Corrigé
par `{cli::qty(missing)}` ; `test-ndre.R` repasse au vert (passait en CI,
échouait en local sur cli plus strict). **P3 doc** : documenté le biais
`mosaic(fun="max")` sur les liserés de tuiles MGRS en mode `trend` (chaque
tuile ajuste sa pente sur son propre jeu de scènes, `max` garde la plus forte
magnitude de déclin dans le recouvrement ~10 km — biais haut borné, conservateur
pour la détection ; mono-tuile non concernée). roxygen + `.Rd` + commentaire
inline. Suites pixel/ndre/ndmi/fast/alert 348 ✔, 0 fail.

### 2026-06-14 — FAST `trend` : fit vectorisé Theil-Sen / Mann-Kendall (spec 023, perf, cœur, v0.83.1)

Revue critique du mode `trend` (spec 023) → **aucun bug**, mais deux points
traités. **P1 perf** : `.fast_raster_trend()` appelait `combn`/`table` **une
fois par pixel** via `terra::app` (~270 µs/pixel, ~4,5 min pour une tuile
1 Mpx). Réécrit en deux leviers : (1) **pré-filtre vectorisé** écartant les
pixels à < `min_years` années valides avant tout calcul, (2) **fit vectorisé**
de Theil-Sen et de la statistique S de Mann-Kendall sur toutes les cellules
candidates à la fois (arithmétique matricielle par colonnes), seules les rares
cellules à valeurs ex-aequo retombant sur le `.mann_kendall()` exact
tie-corrigé. **~9x** mesuré, résultat **byte-identique** au chemin per-cellule
(vérifié sur NA hétérogènes, séries plates, ex-aequo partiels). `terra::app(cores=)`
ne sérialise pas la closure, et un split furrr/PSOCK est **plus lent** que le
série ici (maths per-pixel trop bon marché pour amortir la sérialisation) — le
levier est la vectorisation, pas le parallélisme. `cli::cli_alert_info` annonce
le nombre de pixels candidats. **P2 doc** : roxygen d'`alpha` clarifié — la p
Mann-Kendall est bilatérale mais le gate « pente négative » rend le risque
effectif d'un déclin déclaré égal à **`alpha / 2`** (défaut 0,05 → 2,5 %
unilatéral). **P4 tests** : verdissement significatif → 0, pixel NA-data
préservé en NA (≠ classe 0) à travers la discrétisation 0-4, et test direct
d'identité `.trend_fit_cells` vs `.theil_sen`/`.mann_kendall`. Suites FAST/alert
175 ✔, 0 fail. `.Rd` édités à la main.

### 2026-06-14 — `nemetonshiny@3a717a87` (v0.83.0) : L6 RECONFORT — validation terrain G4 (app)

`nemetonshiny@3a717a87` (v0.83.0) : L6 RECONFORT (spec 021) — **validation
terrain G4**. Sous-onglet « Plan de validation RECONFORT » : réutilisation 1:1
de `mod_validation_sampling` (`generate_validation_plan(source="RECONFORT")` →
`read_reconfort_alert_mask`, classes 2/3 + témoin 1, masque persistant requis).
Consomme `create_validation_sampling_plan(source="RECONFORT")` +
`read_reconfort_alert_mask` + `get_health_validation_schema(method="reconfort")`
du cœur v0.83.0. **Clôt L6 RECONFORT côté app** (carte + diagnostic + run +
validation). Ligne L6 RECONFORT (app) cochée close ; G4 cœur (stades DEPERIS
finalisés) déjà livré en nemeton v0.83.0.

### 2026-06-14 — RECONFORT Option A : `read_reconfort_alert_mask()` + persistance classif (spec 021 G4, cœur, v0.83.0)

Parité **raster** complète avec FORDEAD pour la validation terrain (décision
métier : placettes témoins exigées). `read_reconfort_alert_mask(con, zone_id,
run_id, cache_dir, apply_zone_mask, mask_polygon)` — **miroir exact** de
`read_fordead_dieback_mask()` : lit `<cache_dir>/zone_<id>/reconfort_mask_<run_id>.tif`
(raster catégoriel 1 sain / 2 dépérissant / 3 très-dépérissant), re-masque à
l'AOI zone. La phase `persist` de `run_reconfort_dieback()` écrit désormais ce
masque plat (copie de `Final_Classif_masked`), best-effort. L'app peut donc
réutiliser **1:1** `mod_validation_sampling` avec `source="RECONFORT"`
(`create_validation_sampling_plan`, classes `c(2,3)`, témoins `c(1)`) →
**mêmes onglets / même workflow que FORDEAD** (distribution classes, témoins,
auto-relax, GRTS, export QGIS/QField). Tests `test-reconfort-pixel-series.R`
34 ✔ (mask : latest/run_id/NULL gracieux), suite reconfort 293 ✔, sampling
27 ✔. NAMESPACE + `.Rd` à la main. **Cœur RECONFORT G4 complet (Option A)** —
reste le sous-onglet app « Plan de validation RECONFORT » (brief fourni).

### 2026-06-13 — RECONFORT G4 : vocabulaire DEPERIS finalisé + source RECONFORT (spec 021, cœur, v0.82.0)

Finalisation du support G4 feuillus. `HEALTH_VALIDATION_STADES_FEUILLUS` calé
sur le **vrai protocole DSF DEPERIS** (Nageleisen — critères mortalité de
branches MB + manque de ramification MR, notation A–F, seuil **> 50 %**
d'atteinte du houppier) : `sain` / `deperissement_faible` (A–C, ≤50%) /
`deperissement_marque` (D, >50%) / `deperissement_grave` (E–F) / `mort` /
`coupe_rase`. Mention « PROVISIONAL » **retirée** du roxygen. `source`
de `create_validation_sampling_plan()` accepte désormais **`"RECONFORT"`**
(tag ; la fonction échantillonne n'importe quel raster catégoriel — l'app
passe le raster de classes RECONFORT avec `classes=c(2,3)`, témoins `c(1)`).
**Constat archi** : `get_health_validation_schema()` n'est appelé par aucune
fonction cœur → le routage du formulaire `method="reconfort"` est **côté app**.
Tests : schema 47 ✔, sampling 27 ✔ (cas RECONFORT neuf), ingest 29 ✔. `.Rd`
à la main. **Réserve Option A levée en v0.83.0** (cf. entrée ci-dessous).

### 2026-06-13 — `nemetonshiny@567e6987` (v0.82.0) : L6 RECONFORT — lancement de run (app)

`run_reconfort_async()` (ExtendedTask + `future_promise` autour de
`nemeton::run_reconfort_dieback`), câblage parent (invoke, reactivePoll,
dispatcher `.reconfort_handle_progress_event` pour
`reconfort:start|phase|complete|error` — 10 phases, observer de résultat +
`reconfort_refresh`, cross-lock FAST/FORDEAD, force-unlock). Sans conda
IOTA²/GEODES/OTB : échec propre (toast), carte + diagnostic restent
fonctionnels (Limite #1 spec 021).

### 2026-06-13 — `nemetonshiny@02dfffd1` (v0.81.0) : L6 RECONFORT — consultation (app)

Nouveau module `mod_monitoring_reconfort_map` : carte Leaflet des alertes
feuillus (`list_alerts` filtré `RECONFORT_ALERT_CLASSES`), popup
`confidence_class` + `stress_index` ; bannière validité G3 advisory
(`check_reconfort_validity`, non bloquante) ; clic → diagnostic pixel
(`read_reconfort_pixel_series`) modal plotly 2 traces CRswir/CRre (pas de
prédiction harmonique). 3ᵉ mode du Suivi sanitaire + sous-onglet « Carte
RECONFORT » lazy. Plancher `Imports: nemeton (>= 0.80.0)`. **Reste G4** :
sous-onglet « Plan de validation RECONFORT » (app), après ce support cœur.

### 2026-06-13 — RECONFORT G4 : schéma QField feuillus (spec 021, cœur, v0.81.0)

Support cœur de la brique QField du lot **L6** (app). `get_health_validation_schema(method=)`
sert un vocabulaire feuillus en mode `reconfort` (`HEALTH_VALIDATION_STADES_FEUILLUS`
= sain/défoliation/mortalité branches/descente cime/mort/coupe ;
`HEALTH_VALIDATION_CAUSES_FEUILLUS` sans scolyte). Mapping `stade → status`
routé par méthode (coupe sur `reconfort_dieback` → `false_positive`),
`ingest_health_validation()` détecte la méthode via `alert_type`. Mode
`fordead` inchangé (rétrocompatible). Tests `test-health-validation-schema.R`
46 ✔, ingest 29 ✔. `.Rd`+NAMESPACE à la main. **Réserve** : vocabulaire DEPERIS
exact à confirmer. **Cœur RECONFORT désormais complet pour L6** (L1→L5 + G4).

### 2026-06-13 — RECONFORT L5 : persistance features + diagnostic pixel (spec 021, cœur, v0.80.0)

**Décision option B** (recalcul depuis le S2 ingéré, vs extraction des
intermédiaires IOTA² au layout inconnu). `R/reconfort_outputs.R` :
`.reconfort_crswir`/`.reconfort_crre` (formules §4.1, pures), 
`.build_reconfort_feature_stacks` (scènes datées → stacks CRswir/CRre,
masquage SCL optionnel), `.write_reconfort_features_bundle`,
`.enumerate_reconfort_s2_scenes` (best-effort, nommage THEIA/MUSCATE FRE
B4/B8A/B11 — **layout à valider sur run réel**). `R/reconfort_pixel_series.R` :
`read_reconfort_pixel_series(con, zone_id, xy, crs, run_id, cache_dir)` —
lecteur **sans reticulate** (séries observées, pas de modèle harmonique),
NULL gracieux. Phase `persist` (best-effort) + `run_id` câblés dans
`run_reconfort_dieback()` (9→10 phases, bundle
`<cache_dir>/zone_<id>/run_<run_id>/`, `features_bundle` au retour). Tests
`test-reconfort-pixel-series.R` 27 ✔ (formules, build, round-trip bundle,
NULL, locate, enumerate), suite reconfort **259 ✔**. `.Rd`+NAMESPACE à la
main. **Réserve** : énumération S2 (layout MUSCATE) non validable sans run
réel — best-effort, n'altère jamais le run. Suite : **L6** (app `nemetonshiny`).

### 2026-06-13 — `reset_knowledge_manifest()` : fix copie writable figée (E7, cœur, v0.79.0)

Bug remonté : l'onglet RAG de `nemetonshiny` listait encore les 12 tutos
retirés en v0.75.0. Cause : `knowledge_manifest_path(writable=TRUE)` copie la
seed **une seule fois** (`overwrite=FALSE`) puis ne la rafraîchit jamais — la
copie user-data (`~/.local/share/R/nemeton/knowledge_corpus.csv`) était figée
sur l'ancien manifest (39 docs/10 tutos) alors que seed/installé/prod sont à 81
docs/0 tuto. Copie locale rafraîchie à la main, **et** correctif durable :
nouvelle fonction exportée **`reset_knowledge_manifest(confirm=TRUE)`** (réint
explicite de la copie writable depuis la seed) à câbler à un bouton
« Réinitialiser depuis le corpus du package » côté app (brief fourni). Tests
`test-knowledge-manifest-api.R` 35 ✔. `.Rd`+NAMESPACE à la main.

### 2026-06-13 — RECONFORT L4 : R5 unifié routé par essence (spec 021, cœur, v0.78.0)

`indicateur_r5_deperissement()` gagne `reconfort_results` + `weights_reconfort`
+ `min_feuillus` + `feuillus_col`. **Routage par UGF** (spec 021 §4) : essence
∈ RECONFORT (chêne/châtaignier/pin sylvestre) → score via RECONFORT ; ∈ FORDEAD
(épicéa/sapin) → FORDEAD ; sinon `skipped_no_method`. Un `*_col` explicite
épingle la méthode. Statuts : `calculated` (FORDEAD), `calculated_reconfort`,
`skipped_no_fordead`/`skipped_no_reconfort`/`skipped_no_method`. Refactor :
helpers `.resolve_reconfort_share()` (miroir `.resolve_resineux_share`),
`.r5_prepare_alerts()` (validation + filtre classes + CRS), `.r5_score()`
(score d'une UGF, réutilisé 2 méthodes) — math FORDEAD préservée à l'identique.
Poids RECONFORT par défaut = sous-ensemble dépérissant de
`RECONFORT_CONFIDENCE_WEIGHTS$CHE` (**provisoire**). Tests
`test-indicators-deperissement.R` 42 ✔ (6 cas routage neufs : chêne, pin,
zone mixte EPC+chêne, essence inconnue, `feuillus_col` ; 3 assertions adaptées
au vocabulaire unifié), familles 304 ✔. `.Rd`+roxygen à la main. Suite : **L5**
(persistance features + `read_reconfort_pixel_series()`).

### 2026-06-13 — RECONFORT L3 : postprocess rasters → table `alert` (spec 021, cœur, v0.77.0)

`R/reconfort_postprocess.R` : `.classify_pixels_to_reconfort_classes()`
(codes 1..n → labels `RECONFORT_CLASSES`, masqué=0 → NA),
`.cluster_reconfort_pixels()` (patches 8-connexité sur classes dépérissantes
≥2, drop < `min_pixels`), `.postprocess_reconfort_rasters()` (réutilise
`.cluster_to_centroids()` ; score continu → `stress_index` ; `trigger_date` =
date du run), `.insert_reconfort_alerts()` (`alert_type='reconfort_dieback'`,
UPSERT idempotent PG+SQLite). `classify_disturbance()` **étendu 3 voies** :
FAST seul → recent_event ; FORDEAD/RECONFORT seul → progressive ;
diag+FAST → mechanical ; FORDEAD+RECONFORT → progressive + `method_overlap`.
Migration **`0006`** (index `alert_type`, PG+SQLite). Phase `postprocess`
(best-effort) câblée dans `run_reconfort_dieback()` (8→9 phases, `n_alerts`
au retour). Exports : `RECONFORT_CLASSES`/`_CONFIDENCE_WEIGHTS`/`_ALERT_CLASSES`
(NAMESPACE + `.Rd` à la main, pas de `document()`). Tests :
`test-reconfort-postprocess.R` 50 ✔ (dont insert+migration DB),
pipeline 22 ✔, fordead-postprocess 56 ✔, db 98 ✔. **Réserve** : poids de
confiance **provisoires** (matrice de confusion Mouret 2023 à transcrire).
Suite : **L4** (R5 unifié, routage par essence).

### 2026-06-13 — Corpus RAG : 4 papiers scannés OCRisés → texte intégral (cœur, v0.76.2)

Les 4 PDF BILJOU scannés (link_only en v0.76.1) sont **OCRisés** (`tesseract`
fra+eng via conda `ocr`, 300 dpi → `data-raw/references/biljou/ocr/*.md`
gitignorés) et ré-ingérés en `full`. Prod : **60 texte intégral / 81, 6 120
chunks, 0 erreur** — maximum atteignable (21 références = aucun contenu dispo :
portails, payants, ouvrages non hébergés). Script `data-raw/ocr_biljou_scans.sh`.
Ingestion ciblée : suppression des 4 docs ref en base + `fill_corpus_prod.sh`.

### 2026-06-13 — Corpus RAG : prod synchronisé + 4 PDF scannés → link_only (cœur, v0.76.1)

Build prod FRESH des 81 docs (manifest BILJOU full-text v0.75.4) : **56 texte
intégral + 25 références, 6 033 chunks, 0 embedding manquant**. 4 PDF BILJOU
(Bréda 1993/2002/2008, Granier 1996) sont des **scans sans couche texte**
(`pdf_text` → 0 car.) → échouaient en full-text → repassés `link_only`
(corpus **81/81, 0 erreur**). Ajout `data-raw/fill_corpus_prod.sh` (build
incrémental non-FRESH). OCR requis pour full-texter les 4 scans.

### 2026-06-13 — `db_connect(connect_timeout=)` + parité CI nemetonshiny↔nemeton (cœur)

Release **v0.76.0** (feat). `db_connect(url, read_only, connect_timeout = 10L)` :
le paramètre est passé à libpq (`connect_timeout`, secondes) sur la branche
PostgreSQL pour **borner le gel** sur un hôte injoignable ; ignoré côté SQLite.
Consommé ensuite par `nemetonshiny::get_monitoring_db_connection()` qui passera
`connect_timeout = 2L` sur le chemin d'hydratation interactif. Tests `test-db.R`
(formals + défaut, validation, no-op SQLite, `skip_on_ci` connexion vers
`10.255.255.1` qui échoue en < 5 s). **Parité d'outillage avec nemetonshiny** :
badge version dynamique `github/v/release` (#53), garde-fou CI
`version-consistency` DESCRIPTION=NEWS=CITATION (#54), port du workflow
`release.yml` auto-tag/release depuis DESCRIPTION (#55).

### 2026-06-13 — Chargement projet récent : retrait de 2 blocages synchrones (app)

`nemetonshiny@f9cd7b1` (v0.78.0). Retrait de **deux blocages synchrones** du
chemin critique (avant rendu des parcelles). **(1)** Connexion à la base
monitoring (`mod_home`) gardée par le prédicat `.has_monitoring_zone_id()` :
plus de round-trip (connexion TCP + migration schéma) quand
`monitoring_zone_id` est déjà dans `metadata.json`. **(3)** `ug_build_sf()`
(`st_union` par UGF, 0,5–3 s) extrait en `attach_indicators_sf()` + paramètre
`load_project(build_indicators_sf = )`, différé via `later()` hors du rendu
carte.

### 2026-06-13 — Chargement projet récent : `connect_timeout` borné (app, garde-fou #2)

`nemetonshiny@d6149b5` (v0.79.0). Clôt le **3ᵉ garde-fou (#2)** :
`get_monitoring_db_connection()` borne la phase de connexion Postgres via
`connect_timeout = 2L`, forwardé à `nemeton::db_connect()` par le wrapper
rétro-compatible `.nemeton_db_connect()` (introspection des `formals`).
Consomme `nemeton::db_connect(connect_timeout=)` exposé côté cœur en
**v0.76.0** (`feat(db)`). Plancher `Imports: nemeton` inchangé (consommation
opportuniste), ordre cœur → app respecté. **Les 3 garde-fous du chargement
projet récent sont désormais livrés : #1 skip DB, #2 connect_timeout, #3
`ug_build_sf` différé.**

### 2026-06-12 — RECONFORT L2b.3 : orchestration end-to-end (spec 021, cœur)

Release **v0.74.0**. **L2b.3** — `run_reconfort_dieback()` relie L1/L2a/
L2b.1/L2b.2 en un run complet : env conda → modèle RF → masque feuillus →
AOI→tuile(s) MGRS → ingest S2 → **map-production IOTA²** (sampling +
classification ×2 + masque OSO + score continu).

- **`run_reconfort_dieback(con, zone_id, cache_dir, …)`** : 8 phases (env,
  model, mask, tiles, ingest, stage, mapprod, collect) avec `progress_callback`
  (préfixe `reconfort:`). Sorties EPSG:2154 : `Classif_Seed_0.tif`,
  `ProbabilityMap_seed_0.tif`, `Final_continuous_score_masked<year>.tif`
  (`(1001 + (−P1 + P2 + 2·P3))/30`) + `run_meta.json`. Post-process → table
  `alert` reste **L3**.
- **Staging par-run** (clé) : les scripts amont font `os.chdir` vers leur
  propre dossier et y écrivent `results/` + `generated_config_files/`. Pour
  garder le package installé en lecture seule, chaque run stage une copie de
  travail sous `<cache_dir>/reconfort/run_z<id>_S2<year>/` : glue vendorisée
  (scripts + sous-arbre `iota2/`) + modèle dans `models/<v_model>/` + masque
  dans `masks/` + **vue S2 partitionnée par année** (`S2_data/<year>/<tile>` en
  liens symboliques vers les dossiers `extracted/` de L2b.2, car IOTA² veut
  `s2_path/<year>/<tile>/`). cfg map-production écrit avec `.reconfort_write_cfg`.
- **`ensure_reconfort_oso_mask()` + `RECONFORT_OSO_MASK`** : masque feuillus
  OSO 2021 (~54 Mo, MD5 `ea87e929…`) **téléchargé à la demande** + checksum +
  cache + fallback `local_path`, calqué sur `ensure_reconfort_model()` (L2a).
  `binary_mask` : `NULL`→OSO, chemin→custom, `FALSE`→pas de masque. Le masque
  est toujours stagé à `masks/mask_oso_deciduous_compress.tif` et
  `path_to_binary_mask` laissé vide → classif **et** proba utilisent le même
  masque (le script amont hardcode ce chemin pour la proba).
- **Glue map-production vendorisée** (Apache-2.0) :
  `run_map_production_reconfort.py`, `mask_and_compress_rasters.py`, les 2
  générateurs de cfg IOTA², et le sous-arbre `iota2/` (config, nomenclature,
  `external_features/custom_index.py` — **déplacé** de la racine glue à son
  chemin canonique —, `vector_db/random_points.*`). Modèles (413 Mo) + masque
  (54 Mo) hors package (fetch à la demande).
- **Garde-fou** : le driver amont ne teste pas le code retour du subprocess
  Iota2 (`subprocess.run` sans `check`) → un échec RAM/scheduler/données passe
  en exit 0. Le pipeline **abort** si le raster de score continu n'a pas été
  produit (parité avec les garde-fous L2b.2).
- Lourd + **opt-in** (env conda + GEODES + dizaines de Go + OTB/Shark batch),
  **jamais en CI**. 3 exports (`run_reconfort_dieback`,
  `ensure_reconfort_oso_mask`, `RECONFORT_OSO_MASK`) + `.Rd` à la main, section
  pkgdown, NOTICE. **24 tests mockés** (orchestration 8 phases, cfg masquage
  on/off, garde-fous score/exit, staging S2 année/tuile + glue), suite reconfort
  **182 assertions / 0 échec**. Suite : **L3** (postprocess → alertes).

### 2026-06-11 — RECONFORT L2b.2 : ingestion S2 IOTA²-native (spec 021, cœur)

Release **v0.73.0**. **L2b.2** — acquisition Sentinel-2 dans le layout IOTA²
(décision D1 : pas de réutilisation du cache COG FAST).

- **Grille MGRS embarquée** : `inst/extdata/s2_mgrs_tiles_fr.geojson`
  (188 tuiles France métropolitaine, 61 ko, clippée depuis la grille ESA
  globale via `data-raw/build_s2_mgrs_tiles_fr.R`). `reconfort_aoi_tiles(aoi)`
  intersecte l'AOI → tuile(s) MGRS (sans réseau). Validé : Loiret → `T31UDP`
  (conforme aux configs amont), CVL entière → 14 tuiles.
- `reconfort_ingest_s2(aoi|tiles, dates, s2_root, …)` : génère un `.cfg`
  (`key=<littéral python>`, helper `.reconfort_write_cfg`), télécharge les
  archives MUSCATE L2A via **GEODES/pygeodes** puis dézippe vers
  `<s2_root>/extracted/<tile>/`. Pilote les scripts amont **vendorisés**
  (`run_geodes_download.py`, `run_process_downloaded_images.py` +
  `utils/utils.py`) en subprocess conda (`.reconfort_run_py`, cwd = glue dir
  pour résoudre `from utils.utils`). Compte GEODES via
  `options(nemeton.geodes_config)` (défaut data dir utilisateur), **aucune
  clé embarquée**.
- Heavy + opt-in (compte GEODES + dizaines de Go), **jamais en CI**.
  2 exports (`reconfort_aoi_tiles`, `reconfort_ingest_s2`) + `.Rd` à la main,
  section pkgdown. 14 tests (download mocké, grille réelle), 0 régression
  (151 reconfort PASS). Suite : **L2b.3** (`run_reconfort_dieback()`).
- **Smoke réel** (`data-raw/smoke_reconfort_ingest.R`, 1 tuile T31UDP, fenêtre
  2026-05-08..13) joué avant merge — a fait remonter **3 bugs**, tous corrigés
  et repliés dans v0.73.0 (mêmes PR/tag) : (1) **collection GEODES** — l'id
  d'exemple amont `MUSCATE_SENTINEL2_SENTINEL2_L2A` n'existe pas (HTTP 400) ;
  défaut → `THEIA_REFLECTANCE_SENTINEL2_L2A`. (2) **chemin download/unzip** —
  `download_item_archive()` écrit dans le `download_dir` de la config pygeodes,
  pas dans le `zip_path` que le dézippage lit ; → config pygeodes **par-run**
  avec `download_dir = <s2_root>/zip/<tile>` (cache projet fourni par
  l'appelant, **même convention que le `cache_dir` de FORDEAD**, jamais
  `/tmp`), et comme elle porte la clé API elle vit dans un **tempfile mode
  600** hors cache, effacé après chaque tuile. (3) **erreurs réseau avalées** —
  le téléchargeur amont enveloppe chaque item dans un `except` nu qui sort en
  0 ; une coupure (`ChunkedEncodingError` sur l'archive de ~2 Go) passait pour
  un succès à 0 scène → **garde-fous de post-condition** (≥1 archive après
  download, ≥1 dossier de scène après unzip, sinon abort). Plomberie validée
  bout-en-bout (env conda, résolution tuile, recherche GEODES = 1 scène, config
  par-run, streaming réel des octets : 1,5 Go tirés avant coupure réseau sur
  les 2 Go — seul reliquat = fiabilité réseau du transfert, hors nemeton).

### 2026-06-11 — RECONFORT L2b.1 : fondations Python/IOTA² (spec 021, cœur)

Release **v0.72.0**. **L2b cadré** (`L2b-cadrage.md`) puis **scindé** en
L2b.1/.2/.3 — décisions : ingest **IOTA²-natif** (GEODES), env conda
**localisé+validé** (l'utilisateur l'installe, D2), glue **vendorisée
complète**. **L2b.1** (fondations, sans exécution réelle) :

- `R/reconfort_python.R` — `.ensure_reconfort_python()` localise+valide l'env
  conda `nemeton-reconfort` (surchargeable `options(nemeton.reconfort_conda_env)`),
  vérifie `iota2`+`pygeodes` importables, **ne crée jamais** l'env (abort typé
  avec instructions amont si absent). `RECONFORT_BANDS` (B04/B05/B06/B8A/B11/B12).
- Glue vendorisée `inst/python/reconfort/custom_index.py` (CRswir/CRre,
  Apache-2.0, attribuée `inst/NOTICE`). Orchestration (download/cfg/score)
  vendorisée plus tard (L2b.2/.3).
- 7 tests (reticulate mocké). 1 export (`RECONFORT_BANDS`) + helpers internes.
- **NB install env** : `mamba install iota2` bute sur un conflit solveur amont
  (iota2 récent tire `pytorch-cuda`, channel pytorch/nvidia absent ; pin
  python 3.9 en conflit). Conforme à D2 — l'install est finicky et reste à la
  charge de l'utilisateur (cf. procédure + docs.iota2.net). L2b.1 n'en dépend
  pas (mocké). Suite : **L2b.2** (ingest AOI→tuile + pygeodes).

### 2026-06-11 — RECONFORT L2a : fetch du modèle RF (spec 021, cœur)

Release **v0.71.0**. **Lot L2a** (téléchargement du modèle Random Forest, sans
IOTA² ni Python). Les 4 modèles Shark/OTB amont (`model_1_seed_0.txt`,
Apache-2.0) pèsent 5,7–197 Mo → inembarquables → **fetch à la demande +
checksum + cache**.

- `R/reconfort_model.R` — `ensure_reconfort_model(version, cache_dir,
  local_path, url, force, verify, quiet)` : résout (1) `local_path` (copie
  déjà sur disque, p. ex. clone amont), (2) cache vérifié, (3) téléchargement
  amont. Vérif taille + **MD5** via `tools::md5sum()` (aucune dépendance
  ajoutée). `download.file` (déjà importé) mockable en test.
- `RECONFORT_MODELS` : registre des 4 versions (espèce, classes, taille, MD5).
  `reconfort_model_info()` : accesseur. URL surchargeable via
  `options(nemeton.reconfort_model_base_url)`.
- MD5/URL **validés par un fetch réel** du modèle pin (5,7 Mo) : download +
  vérif + cache + cache-hit OK. 10 tests mockés (`test-reconfort-model.R`,
  42 assertions). 3 exports (NAMESPACE + `.Rd` à la main), section pkgdown.
- Code d'entraînement amont (`train_new_model/`) hors-scope. Suite : **L2b**
  (env conda IOTA² + glue Python vendorisée + pipeline phases 0-3).

### 2026-06-11 — RECONFORT L1 : domaine de validité feuillus (spec 021, cœur)

Release **v0.70.0**. **Démarrage de l'implémentation RECONFORT** (3ᵉ méthode
de suivi sanitaire, dépérissement des feuillus en Centre-Val de Loire ;
paperwork spec 021 + ADR-013 A4 livré le 2026-06-10). **Lot L1** (domaine de
validité, garde-fou G3, sans Python) :

- `R/reconfort_validity.R` — `check_reconfort_validity(aoi, units, ...)`,
  `load_reconfort_validity_zones()`, constantes `RECONFORT_VALIDITY_DEPARTMENTS`
  (18/28/36/37/41/45) et `RECONFORT_VALIDITY_SPECIES` (CHE/CHT/PS). Calqué sur
  `R/fordead_validity.R` ; matchers feuillus `.is_chene` / `.is_chataignier`
  / `.is_pin_sylvestre` (pin maritime/noir exclus) ; réutilise
  `.pick_species_column()` + fallback BD Forêt V2 partagés avec FORDEAD.
- `inst/extdata/reconfort_validity_zones.geojson` (6 dép. CVL, ~39 150 km²,
  EPSG:4326, simplifié 100 m) + `data-raw/build_reconfort_validity_zones.R`
  (même mirror IGN ADMIN-EXPRESS que FORDEAD).
- **Différence FORDEAD** : contrôle **advisory, pas bloquant**
  (`advisory = TRUE`) — RECONFORT n'a aucun verrou géo amont (l'exemple amont
  tourne hors CVL). L'app avertira sans empêcher le diagnostic.
- 4 exports (NAMESPACE + 4 `.Rd` écrits à la main, **sans `document()`**),
  section pkgdown dédiée, 18 tests (`test-reconfort-validity*.R`, 62 PASS).
- **Reporté** (vs plan §5) : flag NDP `health_reconfort` + datasource
  `reconfort_anomalies` — ils supposaient une parité FORDEAD
  (`health_fordead`/`fordead_anomalies`) inexistante et hors sémantique
  `augmented` de `detect_ndp()`. Suite : **L2a** (fetch-modèle).

### 2026-06-11 — Chargement projet : build_index_stack hors du chemin critique (app)

Livraison **app** : `nemetonshiny@d9bc73f` — release **v0.75.2**
(cycle dev 0.75.1.9000 → v0.75.2).

Diagnostic mesuré (instrumentation du handler) : ouvrir un projet depuis
l'Accueil prenait ~17 s à froid. Ni `load_project` (0.6 s) ni l'hydratation
`monitoring_zone_id` (0.1 s) n'étaient en cause — le coût venait de
`nemeton::build_index_stack` (scan de centaines de scènes Sentinel-2)
appelé par la carte pixel du Suivi. Ses outputs étant
`suspendWhenHidden = FALSE` (v0.46.3), la reactive `pixel_stack_r` se
recalculait à chaque changement de projet, même hors onglet Suivi,
bloquant l'event loop. Fix : `req(app_state$active_main_tab ==
"monitoring")` dans `pixel_stack_r` ; le scan ne tourne plus qu'à
l'ouverture du Suivi. Chargement mesuré ~2-3 s après fix.
Périmètre : 100 % `nemetonshiny` — `build_index_stack` seulement appelé,
pas modifié.

### 2026-06-11 — Backfill géométrie commune des projets legacy (app)

Livraison **app** : `nemetonshiny@e9b5e69` — release **v0.75.1**
(cycle dev 0.75.0.9000 → v0.75.1).

Le cache `data/commune.gpkg` (v0.74.0) n'existait que pour les projets
sauvegardés depuis. Les projets legacy re-téléchargeaient le contour à
chaque ouverture (chemin async lent). Backfill paresseux dans `mod_search`
(result handler de `restore_task`) : le contour récupéré est persisté →
prochain chargement instantané. Plus un helper one-shot
`backfill_all_commune_geometries()` (migration de tous les projets en une
passe). Périmètre : 100 % `nemetonshiny`.

### 2026-06-11 — Notification DB persistante jusqu'à l'overlay carte (app)

Livraison **app** : `nemetonshiny@32b1c8e` — release **v0.75.0**
(cycle dev 0.74.1.9000 → v0.75.0).

À l'ouverture d'un projet synchronisé PostGIS, la notification « Projet
synchronisé avec la base PostGIS » (bas à droite) passait en
`duration = 5` et pouvait disparaître **avant** l'apparition de l'overlay
carte « Affichage des parcelles… », laissant un trou de feedback. Elle
devient persistante (`duration = NULL`, id `db_sync_notif`) et `mod_map`
la retire dès que l'overlay de chargement prend le relais
(`show_map_loading`). Filets : `later()` 12 s + chemin commune invalide.
Périmètre : 100 % `nemetonshiny` — aucun changement cœur.

### 2026-06-10 — Déblocage CI nemetonshiny (lasR + tests) (app)

Livraison **app** : `nemetonshiny@8b10862` — release **v0.74.1**
(cycle dev 0.74.0.9000 → v0.74.1).

Le CI app était rouge **depuis v0.73.0** : `lasR` (Suggests, hébergé sur
r-universe `r-lidar`, absent du CRAN) n'était pas résolu par `pak`, faisant
échouer tous les jobs à l'étape « Install R dependencies » — le vrai
message (`Can't find package called lasR`) était masqué par des
« dependency conflict » génériques. Fix : ajout de `r-lidar/lasR` à
`Remotes:`. Une fois l'install débloquée, R-CMD-check a atteint la suite et
révélé **6 tests pré-existants** cassés/obsolètes (tous côté test, code
applicatif correct) : `mod_rag_admin` testServer ×3 (`ignoreInit` mangé par
`testServer` + mock à promesse non forcée bloquant la souscription
réactive), `mod_monitoring`/`mod_monitoring_pixel_map` ×3 (attente
`NDVI,NBR` vs câblage `NDVI,NBR,NDMI` depuis v0.71.0). Un smoke E2E
shinytest2 (`mod_rag_admin-e2e`, jamais exécuté en CI auparavant) reste
**quarantiné** (`skip()` + FIXME) — interaction modale/tab-lazy à creuser
avec un env navigateur stable. Périmètre : 100 % `nemetonshiny`.

### 2026-06-10 — Restore projet instantané : cache géométrie commune (app)

Livraison **app** : `nemetonshiny@6778e84` — release **v0.74.0**
(cycle dev 0.73.1.9000 → v0.74.0).

La frontière de la commune est désormais persistée au save du projet
(`data/commune.gpkg`) et réinjectée **synchroniquement** au chargement, en
même temps que les parcelles. La carte se rend immédiatement, sans attendre
la `restore_task` asynchrone (worker `future::multisession` + rechargement
de `nemeton` dans le worker + 2 appels séquentiels à `geo.api.gouv.fr`). La
tâche async ne sert plus qu'à peupler la liste déroulante des communes ; les
projets *legacy* sans cache retombent sur l'ancien chemin asynchrone.
Périmètre : 100 % `nemetonshiny` — aucun changement cœur `nemeton`.

- **2026-06-11** — Release **v0.69.2** (fixed — **`.fast_raster_trend()` mono-couche**, spec 023). La CI lasR/lidaRtRee enfin verte (PR #40) a fait tourner pour la première fois les chemins terra du mode `trend` (v0.69.0) et révélé un bug réel : une année à une seule scène in-season produit un `SpatRaster` 1 couche sur lequel `terra::app(sub, fun)` lève « number of values returned by 'fun' is not appropriate ». Corrigé par primitives cell-wise robustes (`nlyr - countNA` + `terra::median`) ; régression `test-fast-trend.R` (+ 2 bugs de test : mapping cellule terra row-major vs indice matriciel R, scalaire nommé). **Paperwork RECONFORT (spec 021)** livré en parallèle : `plan.md` (6 questions §10 tranchées sur le dépôt amont vérifié `fl.mouret/reconfort`, clone `main` 25198c9) + `spec.md` (parité spec 008) + amendement **ADR-013 A4** (suivi sanitaire multi-méthodes, dans `nemetonplateform`, branche `claude/adr-013-a4-reconfort`). **Durcissement CI** (préexistant, sans rapport métier) : job `tests` → `devtools::test()` réel (l'ancien `test_package()` ne trouvait aucun test installé = faux vert) ; `R-CMD-check --no-tests`/`--no-build-vignettes` ; `pkgdown` + `rsconnect` + 111 topics ajoutés à l'index de référence ; vignette `getting-started` en `error = TRUE`. Surtout : **garde-fou par capacité** `skip_if_terra_write_broken()` contre une anomalie terra **propre au runner GitHub** (terra::rast/writeRaster lèvent « no valid constructor » dans le contexte testthat/vignette, irreproductible en local où toute la suite passe — PASS 7381) : les tests raster **skippent** sur ce runner, **tournent en entier** ailleurs. CI complète (R-CMD-check + tests + coverage + pkgdown) **verte** sur le commit final.

- **2026-06-10** — **CI (infra, pas de bump)** : déclaration des r-universe de `lasR`/`lidR` (`https://r-lidar.r-universe.dev`) et `lidaRtRee` (`https://jmmonnet.r-universe.dev`), absents de CRAN/RSPM → `pak::lockfile_create` échouait à l'étape *Dependency resolution*, laissant `R-CMD-check`/`pkgdown` rouges sur `main` depuis plusieurs releases (le code n'était jamais compilé ni testé — c'est ce qui a laissé passer le crash NDRE-only). Solution finale : (a) `r-lidar.r-universe.dev` déclaré en `Additional_repositories:` (DESCRIPTION) **et** en `extra-repositories:` des étapes `setup-r@v2` (`r.yml` ×3 jobs + `pkgdown.yaml`) — `setup-r` n'injecte que RSPM/CRAN dans `getOption("repos")`, donc seul `extra-repositories` fait que `pak` voit la r-universe ; ça résout `lasR` + `lidR`. (b) `lidaRtRee` n'est ni sur CRAN-résolvable en CI ni sur `jmmonnet.r-universe.dev` (404) → déclaré via `Remotes: git::https://forge.inrae.fr/lidar/lidaRtRee.git` (source officielle INRAE), que `pak` clone et build. Itérations : `Additional_repositories` seul (sans effet, `setup-r` ne le lit pas) → `extra-repositories` r-lidar+jmmonnet (résout lasR/lidR, jmmonnet 404) → r-lidar seul + Remotes git pour lidaRtRee. Objectif : faire enfin tourner la CI complète (et valider les chemins terra NDRE/trend). PR #40.

- **2026-06-10** — Release **v0.69.1** (fixed — **NDRE-only crash dans `extract_pixel_timeseries`**, spec 022). Bug introduit en v0.68.0 et repéré par le reviewer automatique Codex sur la PR #38 (après merge) : le CRS natif était lu en dur sur `rs[["B08"]]`, `NULL` pour une requête `indices = "NDRE"` (seules B8A/B05 chargées) → `terra::crs(NULL)` plantait avant le calcul NDRE. Corrigé en prenant le CRS de la 1ʳᵉ bande chargée (`rs[[1L]]` ; toutes les bandes d'une scène partagent le CRS, garde-fou non-NULL juste au-dessus). Chemins mixtes NDVI/NBR/NDMI non affectés. Régression : `test-ndre.R` (cache B8A+B05 sans B08). Parse OK ; chemins terra à valider en CI (rouge pré-existant sur résolution `lasR`/`lidaRtRee`, sans rapport). PR #39.

- **2026-06-10** — Release **v0.69.0** (added — **mode FAST `trend`**, spec 023, cœur). 3ᵉ sémantique FAST (relatif/pluriannuel) pour le **dépérissement chronique feuillus**, à côté de count/rolling. `read_fast_alert_raster(mode="trend")` : composite saisonnier annuel (`months=6:9`, `min_obs_per_year=2`, `min_years=4`) → **Theil-Sen** (pente) + **Mann-Kendall** (significativité, `alpha=0.05`) par pixel via `terra::app` ; sortie `abs(pente)` si pente<0 & p<alpha, sinon 0, NA si années insuffisantes. **Contrat préservé** : même raster continu 0/>0 que count/rolling → `compute_fast_alert_mask(mode="trend")` réutilise la discrétisation quartile 0-4 **sans modification** (`compute_fast_alert_mask` non touché sur sa logique de classes). Nouveaux args trend-only (`months/min_years/min_obs_per_year/alpha`) sur les 2 fonctions FAST ; `threshold`/`window_days` ignorés en trend. **Défaut d'indice mode-dépendant** : NDVI (count/rolling) vs NDMI (trend). Helpers `.theil_sen()`/`.mann_kendall()` (variance tie-corrigée, p bilatérale, correction continuité), `.fast_layer_name()`, `.fast_raster_trend()`. Cache : hash + nom de fichier intègrent les params trend (auto-invalidation) ; **hash count/rolling byte-identique** (params trend ajoutés seulement en trend → COG existants préservés). `.enumerate_cache_scenes` gagne la branche NDRE. Tests : `test-fast-trend.R` (16 blocs : maths Theil-Sen/MK, `.fast_raster_trend` décline/plat/court/bruit/hors-saison/year-drop, intégration read+mask mode trend, défaut NDMI, validation params, hash/filename trend + back-compat count/rolling). Back-compat test du `formals(index)` mis à jour (NDRE ajouté). **Vérifié ici (R-base installé, sans terra/sf)** : `parse()` OK sur les 4 fichiers R + 3 tests ; logique R pure validée en standalone — Theil-Sen (pente/robustesse/NA), Mann-Kendall (décline p≈0.0275 à n=5, plat→p NA, n=4 monotone p>0.05 → justifie les fixtures ≥5 ans), `trend_cell` (décline→0.2 / plat→0 / court→NA), keying du hash (count/rolling byte-identique, params trend discriminants, threshold ignoré en trend), format de nom trend. **À rejouer en CI** (terra/sf indispos ici) : chemins raster `.fast_raster_trend`/`build_index_stack(NDRE)`/intégration read+mask, `devtools::document()` (`.Rd` non régénérés), `devtools::test()` complet. Clôt le brief « red-edge + mode trend » (TASK 1 spec 022 + TASK 2 spec 023).

- **2026-06-10** — Release **v0.68.0** (added — **indice red-edge NDRE**, spec 022, cœur). Prérequis du futur mode FAST `trend` (déclin chronique feuillus). `NDRE = (B8A − B05) / (B8A + B05)` ajouté à `build_index_stack()` et `extract_pixel_timeseries()` (`R/pixel-map.R`) ; B8A/B05 nativement 20 m, même grille → indice à 20 m sans rééchantillonnage. `read_s2_band_raster()` accepte `"B05"`/`"B8A"` ; `ingest_sentinel2_timeseries(bands="NDRE")` + `.s2_required_bands()` cachent B05+B8A (red-edge **sur demande explicite** uniquement). Nouveau garde-fou interne `.assert_cache_has_bands(cache_dir, bands)` : NDRE sur un cache sans red-edge → `cli::cli_abort` explicite, pas de raster all-NA silencieux (NDVI/NBR/NDMI gardent leur tolérance historique). Tests : `test-ndre.R` (8 blocs : lecture bandes, formule, série pixel, mapping bandes, abort cache sans red-edge/vide/absent, non-régression NDVI). **Vérifié ici (R-base, sans terra/sf)** : `parse()` OK ; `.assert_cache_has_bands` validé en standalone (dir manquant/vide → abort, red-edge présent → pass, cache NDVI-only → abort pour NDRE). **À rejouer en CI** : arithmétique NDRE de `build_index_stack`/`extract_pixel_timeseries` (terra indispo ici), `devtools::document()` (`.Rd` non régénérés — le repo régénère la doc en CI/release, déjà désync sur NDMI), `devtools::test()`. Suite : mode FAST `trend` (spec 023).

- **2026-06-04** — Release **v0.67.0** (added — **`prune_orphan_zone_caches()`**, spec 020 §5/§7). Supprime les dossiers `zone_<id>/` (sous `fast_alert/`, `fast_alert_mask/`, `fast_sampling/`, `fast/`, `fast_raster/`, `fordead/`) dont le `zone_id` n'existe plus en base — orphelins créés par l'upsert de zones (`build_project_monitoring_zones(replace=TRUE)` réassigne de nouveaux id, la GC LRU ne purge qu'à l'intérieur d'un dossier vivant). `dry_run=TRUE` prévisualise ; `sentinel2/`/`lidar_*` jamais touchés. Tests : `test-monitoring-zones.R` 44 PASS (+12 : suppression sélective, dry-run, non-zone/root manquant ignorés). Export NAMESPACE + `man/prune_orphan_zone_caches.Rd` à la main. Clôt le reliquat cœur de la spec 020 ; ne reste que le wiring app (D6).

- **2026-06-04** — Release **v0.66.0** (added — **zones de suivi par strates BD Forêt v2, spec 020**, cœur). Un projet porte jusqu'à 4 zones `<projet>_tot/_feu/_res/_mix` = union UGFs × strates BD Forêt (classées via `tfv_g11`, repli `essence`). Nouvelles fonctions exportées (`R/monitoring-zones.R`) : `build_project_monitoring_zones()` (construit + upsert idempotent D5, strate vide skippée D4), `create_monitoring_zone()` (insert zone-seule **sans placette** — D2, diagnostic pur-raster depuis spec 017), `find_zones_by_project()` (N zones/projet, D6). **Migration 0005** (pg+sqlite) : unicité `monitoring_zone` relâchée `project_uuid` → `(project_uuid, name)` (D3). **Fix** : `register_monitoring_zone(project_uuid=)` récupérait l'id par `project_uuid` seul → mauvais id en multi-zones ; corrigé en `(project_uuid, name)`. Décisions D1-D6 actées dans la spec (D1 mixte → zone `_mix`). Tests : `test-monitoring-zones.R` 32 PASS (slug, classifier tfv_g11/essence, validation, build mocké géométrie+upsert, intégration create/find/UNIQUE/end-to-end) ; `test-project-zone-binding.R` mis à jour pour la nouvelle contrainte (22 PASS). Exports NAMESPACE + 3 `.Rd` à la main. Échecs pré-existants de `test-monitoring.R` (cache ingestion) confirmés sans rapport (reproduits sur HEAD propre). **Reliquat spec 020** : wiring app `nemetonshiny` (bouton build + sélecteur choix-unique peuplé via `find_zones_by_project`, défaut `_tot`) ; `prune_orphan_zone_caches()` optionnel (caches `zone_<old_id>` orphelins après upsert).

- **2026-06-03** — Release **v0.65.3** (added/fixed — **GC du cache des masques FAST**). Les masques 0-4 (`compute_fast_alert_mask()`, `fast_alert_<ts>.tif`) sont horodatés → 1 fichier par appel, dossier qui grossissait sans limite (constaté : 82 fichiers dans un projet). Nouvelle `.fast_alert_mask_gc()` (`R/fast_alert_mask.R`) appelée après écriture : garde les `getOption("nemeton.fast_mask_keep", 20)` plus récents (LRU mtime), motif `^fast_alert_.*\.tif$`. **Fix connexe** : `.fast_raster_gc()` (cache continu) globait `^fast_.*` → incluait les masques quand `result_cache_dir == mask_cache_dir` (validation sampling sur `fast_sampling/`) ; resserré à `^fast_[A-Z].*\.tif$` (COG continus en majuscule uniquement) → les 2 caches GC indépendamment, sans se supprimer mutuellement. Note : l'**écriture** d'un masque est négligeable (~20 ms mesuré, INT1U/DEFLATE ~4 Ko) ; les ~10 s entre fichiers observés = le calcul complet (build_index_stack + project + mosaic), pas l'écriture. Tests : `test-fast-alert-mask.R` +4 (GC keep/no-op/ignore-continu, + `.fast_raster_gc` ignore masques). Doc roxygen + `man/compute_fast_alert_mask.Rd` (édité main). Issu de la question perf « combien de temps pour écrire dans fast_alert_mask ».

- **2026-06-03** — Release **v0.65.2** (changed — **naming verbose du cache D6 FAST**). Les COG content-addressed (`R/fast_alert_raster.R`) passent de `fast_<INDEX>_<MODE>_<hash>.tif` à `fast_<INDEX>_<MODE>_thr<seuil>_<from>_<to>_w<window>_<hash8>.tif` : seuil, fenêtre temporelle et `window_days` lisibles dans le nom, + 8 chars du hash (inchangé) pour discriminer liste de scènes & masque UGF. Nouveau helper `.fast_raster_filename()` ; `.fast_raster_cache_path()` reçoit threshold/dates/window ; seul call-site = `read_fast_alert_raster()` (donc `read_fast_alert_rasters()`, `compute_fast_alert_mask()` cache continu et `.prewarm_fast_alerts()` en héritent). Idempotence préservée (hash `.fast_raster_hash()` inchangé) ; anciens fichiers recalculés à la 1re demande puis GC LRU. Rien ne parse le nom (GC = mtime, reader = `file.exists`), aucune régression. Tests : `test-fast-alert-raster.R` (+4 : format exact, déterminisme, discrimination seuil/fenêtre/hash, casse index/mode ; +1 assertion params verbeux dans le fichier écrit), prewarm 24 / ndmi 19 verts. Doc roxygen + 2 `.Rd` (édités main) à jour. Brief de hand-off reçu de `nemetonshiny@v0.70.0` (2 fichiers `fast_NBR_count_<hash>.tif` indistinguables). Aucune action app requise (bump plancher `>= 0.65.2` au prochain cycle).

- **2026-06-03** — Release **v0.65.1** (fix — **le prewarm FAST couvre les 6 cartes**). `.prewarm_fast_alerts()` (`R/monitoring.R`, pré-calcul optionnel spec 018) ne pré-chauffait que 4 combos (NDVI/NBR × count/rolling) — oubli de v0.65.0 qui avait ajouté NDMI à l'orchestrateur public mais pas au prewarm. La boucle `expand.grid` passe à 3 indices × 2 modes = 6 combos ; le skip best-effort existant (tryCatch + `cli_warn` + événement `fast_prewarm:<idx>_<mode>_failed`) couvre NDMI sans B11, comme NBR sans B12. Aucun changement d'API. Tests : `test-prewarm-fast-alerts.R` 24 PASS (fixture étendue à B11, assertions 4→6, échec partiel NBR+NDMI). Doc roxygen + `man/ingest_sentinel2_timeseries.Rd` (édité main) « four → six ». Brief de hand-off reçu de la session `nemetonshiny` (app v0.68.0, plancher `nemeton (>= 0.65.0)`).

- **2026-06-03** — Release **v0.65.0** (fix + feat — **les 6 cartes d'alerte FAST**). **Fix (régression spec 019)** : `.enumerate_cache_scenes()` (sélecteur de scènes du diagnostic FAST raster, `R/fast_alert_raster.R`) n'avait pas de branche `NDMI` dans son `switch(index, …)` — il renvoyait `NULL`, d'où `paste0(NULL, ".tif")` = `".tif"` testé dans chaque répertoire-scène → **aucune scène ne qualifiait jamais** pour NDMI. Conséquence : `read_fast_alert_raster(index = "NDMI")` et `compute_fast_alert_mask()` en NDMI retournaient toujours `NULL` **malgré B08 + B11 en cache** (l'ingestion NDMI marchait, la carte ne sortait pas). Le `switch` mappe désormais `NDMI -> B08 + B11` et lève une erreur explicite sur index inconnu (plus d'échec silencieux). **Feat** : nouvelle fonction exportée **`read_fast_alert_rasters()`** — orchestrateur qui construit les **6 cartes** (3 indices NDVI/NBR/NDMI × 2 modes count/rolling) en un appel, retournant une `list` nommée `"<index>_<mode>"` ; chaque carte passe par `read_fast_alert_raster()` (même cache COG, même cache résultat content-addressé D6, même masque), une carte sans scène reste `NULL` (forme stable), `indices`/`modes` restreignent le sous-ensemble. Export + `man/read_fast_alert_rasters.Rd` écrits à la main (pas de `document()`). Tests : `test-ndmi.R` 19 PASS (+4 : régression enumerate NDMI trouve/écarte une scène, orchestrateur 6 cartes nommées, sous-ensemble restreint). Les 2 échecs DB de `test-fast-alert-{raster,mask}.R` sont des tests d'intégration pré-existants (`monitoring_zone` absent de la base `.Renviron`), sans rapport avec ce diff. **Reliquat** : UI NDMI / affichage des 6 cartes côté `nemetonshiny` à câbler.

- **2026-06-02** — **Opérationnel (pas une release) — corpus RAG construit et validé en PROD.** `Rscript data-raw/build_knowledge_corpus.R` lancé avec `NEMETON_KNOWLEDGE_DB_URL="$NEMETON_DB_URL"` (URL résolue par R depuis `.Renviron`, jamais affichée — pas de fuite de secret). `enable_rag(con)` a créé le schéma `knowledge_*` sur le PG prod (pgvector présent, ADR-012). **19 documents ingérés, 0 erreur** : 10 tutoriels + 2 specs internes (MIT) + 7 PDF HAL/SET (Bontemps ×3, Charru ×2, hal_00930719, revue SET) → **1845 chunks, tous embeddings non-NULL**, modèle unique `mistral:mistral-embed` (pas de mélange de providers → similarité fiable). Les 16 `cleared` `[NO SOURCE]` (IPCC, Légifrance, CNPF, ONF, OFB, EUR-Lex, SRGS, Duplat, Forrester, Larrieu, Monnet, Bernard&Doridant) skippés faute de PDF/URL attaché ; les 4 copyright restent `to_confirm`. **Test d'acceptation du chemin de lecture** : `retrieve_knowledge(con, "détection du dépérissement des épicéas par télédétection FORDEAD", top_k=3)` → 3 chunks de la Spec 008 (similarité ~0.87), `format_citations()` rend un bloc « Sources documentaires » correct. Le pipeline pgvector `<=>` + embedding Mistral + citations fonctionne de bout en bout en prod. Corpus **hors git** (D3, reconstructible depuis le manifest). Note exploitation : `build_knowledge_corpus.R` idempotent (clé sur le titre) → re-runs sûrs ; SQLite local de dev (`data-raw/knowledge_corpus.sqlite`, 39 Mo) déjà à jour. **E7 corpus entièrement clos côté cœur** ; seul reste le **wiring `nemetonshiny`** (briefs de hand-off transmis à la session app le 2026-06-02 puis retirés de ce repo).

- **2026-06-02** — Release **v0.62.0** (feat — **ingestion « référence seule » du corpus RAG**, spec 009.1 §5, **clôt la machinerie corpus côté cœur**). Nouvelle fonction exportée **`ingest_knowledge_reference()`** : pour les documents non redistribuables (papiers paywall, tous droits réservés), elle n'ingère qu'une **référence citable** — jamais le corps protégé. Un seul chunk = citation bibliographique (titre, auteur, année, éditeur, URL) + abstract si fourni (`ingestion_mode = "abstract_only"`) ou mention « texte intégral non redistribué » sinon (`ingestion_mode = "link_only"`). Le mode est stocké dans `metadata.ingestion_mode` (colonne JSON `metadata` — **aucune migration**, le schéma 0004 a déjà `metadata`). **DRY** : délègue chunk→embed→insert transactionnel à `ingest_knowledge_document()` (une référence courte = source-texte d'un chunk), comportement existant inchangé. Helper `.build_reference_text()`. **Build script** `data-raw/build_knowledge_corpus.R` : les lignes `abstract_only`/`link_only` (auparavant exclues par `eligible & ingest_strategy=='full'`) sont désormais routées vers `ingest_knowledge_reference()`, sous le même verrou D5 ; colonne `abstract` optionnelle lue si présente (forward-compatible, absente aujourd'hui → link_only). Dry-run vérifié : les 4 papiers copyright planifiés en `[link_only]`. Export ajouté à la main au NAMESPACE + `man/ingest_knowledge_reference.Rd` écrit à la main (style raw-markdown du repo) pour **ne pas** lancer `document()` qui dégrade les 16 `.Rd` en `\link` (markdown non activé dans l'env). Tests : `test-rag.R` 84 PASS (+19 : `.build_reference_text` citation/abstract, `ingest_knowledge_reference` link_only/abstract_only, `ingestion_mode` en metadata JSON, titre requis, doc référence retrouvable + citée proprement via `retrieve_knowledge`/`format_citations`). **Machinerie corpus E7 close côté cœur** (machinerie v0.52.0 + manifest/validation/NOTICE v0.61.1 + arbitrage v0.61.2 + référence seule v0.62.0). **Reliquat E7** : build réel des embeddings (clé API, local) ; wiring `nemetonshiny` (chunks dans le prompt + bloc UI « Sources ») ; optionnellement lever le `to_confirm` des 4 copyright pour les ingérer en référence.

- **2026-06-02** — Release **v0.61.2** (changed — **arbitrage des licences du corpus RAG**, spec 009.1 D5). Décisions juridiques prises par Pascal (Claude n'arbitre jamais le juridique — il a livré présomption + où vérifier + effet pipeline, l'utilisateur a tranché) sur les docs `to_confirm` du manifest : (1) **Bernard & Doridant 2024** (rapport ONF/DSF, fonde les garde-fous R5 spec 008) → Licence Ouverte confirmée, `status = cleared` (PDF/URL DSF à attacher pour ingestion réelle) ; (2) **revue SET « Forêt, croissance et changement climatique »** (seul `to_confirm` avec un PDF local présent dans `data-raw/references/`) → licence ouverte/CC-BY confirmée, `status = cleared`, `license = CC-BY` (variante exacte CC-BY vs CC-BY-NC à reconfirmer avant usage commercial — noté dans `notes`) → s'ingérera au prochain build ; (3) **4 papiers copyright** (Mouret 2022, Fassnacht 2016, McCool 1987, Beven & Kirkby 1979) laissés `to_confirm` (copyright ⇒ jamais full ; pas d'abstract sourcé ; mode `link_only` à câbler dans un petit chantier pipeline ultérieur). Bilan manifest : **35 `cleared` / 4 `to_confirm`**. `test-knowledge-corpus-manifest.R` reste vert (20 assertions, invariants D5/§5 préservés). **Reliquat E7 corpus** : câblage `link_only`/abstract dans `build_knowledge_corpus.R` (pour exploiter les 4 copyright en référence) ; build réel des embeddings (clé API, local) ; wiring `nemetonshiny` (chunks dans le prompt + bloc UI « Sources »).

- **2026-06-02** — Release **v0.61.1** (fix — **cohérence + garde-fous du manifest corpus RAG**, spec 009.1, ouverture du travail E7 corpus côté cœur). État constaté du chantier corpus : **plus avancé que ne le disait le PLAN** — manifest `inst/extdata/knowledge_corpus_v1.csv` (39 docs : 10 tutoriels + 2 specs MIT, 7 papiers HAL, ~20 sources gouvernance/méthodo) et pipeline `data-raw/build_knowledge_corpus.R` (license-gate D5, idempotent, dry-run) déjà commités ; base `knowledge_corpus.sqlite` (39 Mo) + 7 PDF HAL construits localement et **gitignorés** (conforme D3). **Livré ici** (tranche autonome, sans arbitrage juridique) : (1) **fix manifest** — la ligne `set_revue_foret_croissance_climat` était `status = cleared` avec `license = to-confirm` → le pipeline l'aurait ingérée malgré une licence non confirmée (contraire à D5) ; statut remis à `to_confirm` (aucune décision juridique prise, retour du côté sûr) ; (2) **`test-knowledge-corpus-manifest.R`** (20 assertions, contribue covr) — garde le manifest packagé (source unique de vérité) sur structure (colonnes, `doc_id` uniques slug), énumérations (`license`/`status`/`ingest_strategy`/`lang`/`doc_type`/`license_commercial_ok`), codes familles (regex `^(Toutes|[BCWAFLTRSPEN][0-9]?)$`) / profils (15 acteurs + `tous`), et 2 invariants de sécurité : `cleared ⇒ licence non vide ≠ to-confirm`, `copyright ⇒ jamais full` ; (3) **`inst/NOTICE`** — section « RAG knowledge corpus » par classe de licence (Légifrance domaine public, EUR-Lex, IPCC usage libre, Etalab OFB/ONF/CNPF, CC-BY, dépôts HAL, autorisation Tran-Ha) + rappel que le copyright n'est jamais redistribué (abstract/link-only). **Reliquat E7 corpus** : arbitrage des 6 `to_confirm` (D5, tranche utilisateur), build réel des embeddings (action locale `data-raw/` + clé API), wiring `nemetonshiny` (chunks dans le prompt + bloc UI « Sources »). **Note push** : proxy git peut refuser les tags (HTTP 403) — si c'est le cas, commit + tag local faits, push/release à finaliser depuis une machine aux droits complets.

- **2026-06-02** — Release **v0.61.0** (feat — **pré-calcul des 4 cartes FAST en fin d'ingestion**, spec 018). `ingest_sentinel2_timeseries()` gagne deux paramètres opt-in : `prewarm_alerts = FALSE` + `prewarm_mask_cache_dir = NULL`. Quand `prewarm_alerts = TRUE`, la fonction enchaîne **en fin d'ingestion réussie** sur 4 appels `read_fast_alert_raster()` (helper `.prewarm_fast_alerts()`) couvrant `NDVI`/`NBR` × `count`/`rolling` au threshold défaut (0.40 NDVI / 0.30 NBR) et `window_days = 30L`, cache D6 activé → les 4 COG atterrissent sous `<prewarm_mask_cache_dir>/zone_<id>/fast_<index>_<mode>_<hash>.tif`. **Motivation** (incident user 2026-06-02 côté `nemetonshiny@v0.53.1`) : le cache D6 introduit en v0.56.0 restait vide tant que l'utilisateur n'avait pas visité les 4 combinaisons ; chaque bascule radio NDVI↔NBR / Fréquence↔Intensité subissait un recalcul 5-30 s. Le pré-calcul absorbe ces 20-60 s pendant l'ingestion (où l'utilisateur attend déjà 5-15 min) → navigation FAST instantanée ensuite. **Garde-fous** : (1) **tolérant aux échecs partiels** — les 4 combinaisons sont indépendantes ; une combinaison sans scène utilisable (p. ex. `NBR` sans B12 dans le cache, `read_fast_alert_raster()` renvoyant `NULL`) ou en erreur émet un `cli::cli_warn` + event `_failed` et est ignorée, les autres aboutissent ; (2) **cancel coopératif** — `cancelled()` (closure du parent) interrogée entre chaque combinaison, sortie propre, COG déjà écrits valides ; une ingestion **annulée** ne démarre jamais le pré-calcul (placé sur le seul chemin succès, après `s2:complete`) ; (3) **validation fail-fast** — `prewarm_alerts = TRUE` sans `cache_dir`/`prewarm_mask_cache_dir` lève une erreur d'orientation. **Heartbeat progress** : 3 events/combinaison (`fast_prewarm:<index>_<mode>` / `_done` / `_failed`) portant `index`/`mode` (+ `error_message` sur `_failed`) → toast localisé côté app (pas de littéral FR dans le payload cœur). **Rebase** : brief basé sur v0.60.0→v0.61.0 ; le repo était à v0.57.0 au démarrage, mais les Phases A/B `obs_pixel` (v0.58.0/v0.60.0) ont été mergées sur `main` pendant le dev → réintégration des changements prewarm sur la nouvelle base `ingest_sentinel2_timeseries()` (pur-raster, `.cache_scene_bands()` au lieu de `.extract_scene_obs()`), cible **v0.61.0** confirmée. Le param public garde le nom `prewarm_mask_cache_dir` du brief (mappé sur `result_cache_dir`) pour copie directe côté app. Tests : `test-prewarm-fast-alerts.R` (22 PASS) — 4 combinaisons → 4 COG + heartbeats ; échec partiel (B12 absent → 2 COG NDVI + warnings NBR) ; cancel mi-parcours (1 COG) + cancel à l'entrée (0) ; validation args ; wiring full-function (mocks `.fetch_plots_sf`/`.get_zone_aoi`/`stac_search_s2`/`.cache_scene_bands`) FALSE n'appelle pas le helper / TRUE forwarde zone_id+cache dirs. Suites voisines vertes (317 PASS ; seul échec = smoke-test villards env-dependent sans DB, pré-existant). Côté app `nemetonshiny@v0.54.0` (à venir) : `service_monitoring.R` (`run_ingestion_async`) + `mod_monitoring.R` (`fast_task$invoke`) forwardent `prewarm_alerts = TRUE` + `prewarm_mask_cache_dir = <projet>/cache/layers/fast_alert`, observer progress reconnaît `fast_prewarm:*`, plancher `Imports: nemeton (>= 0.61.0)`. **Note push** : comme pour v0.58.0/v0.60.0, le proxy git de l'environnement peut refuser les push de tags (HTTP 403) — si c'est le cas, commit + tag local faits, push + release GitHub à finaliser depuis une machine aux droits complets.

- **2026-06-02** — Release **v0.60.0** (Phase B — **retrait définitif des trois lecteurs `obs_pixel`**). Suite directe de la v0.58.0 (Phase A) après merge sur `main` : à la demande utilisateur, exécution immédiate de la Phase B (la fenêtre de dépréciation v0.58.0→v0.60.0 est de fait raccourcie, mais `nemetonshiny@v0.52.16` ne consomme déjà plus ces fonctions, donc sans impact aval). Supprimés : `R/read_obs_pixel.R`, `R/fast_alerts.R` (`list_fast_alerts_for_zone()`), `R/alerts.R` (`detect_alerts()`) + leurs `man/*.Rd` + helpers internes (`.empty_obs_pixel`, `.coerce_obs_date`, `.empty_fast_alerts`, `.coerce_alert_date`) + 3 exports `NAMESPACE`. `test-obs_pixel-deprecation.R` retiré. Schéma simplifié : `CREATE TABLE obs_pixel` (+ `create_hypertable` PG) retiré des migrations `0001_init` (PG + SQLite) — les bases neuves ne créent plus la table ; `0004_drop_obs_pixel` conservée pour les bases existantes (DROP idempotent, no-op sur base neuve). La table `alert` reste (alimentée par FORDEAD via `list_alerts()`). Liens roxygen cassés réparés (`read_fast_alert_raster`/`pixel-map` ne pointent plus vers `read_obs_pixel`/`list_fast_alerts_for_zone` ; le commentaire « scenes resolved via read_obs_pixel » de `read_fast_alert_raster` — déjà faux depuis spec 017 — corrigé en « énumérées depuis le cache COG »). **Breaking** pour les appels directs (warning depuis v0.58.0). **NON TESTÉ EN CI ICI** (pas de R) — rejouer sur les deux backends + `devtools::document()` (`man/*.Rd` ajustés à la main). **Chantier pure-raster FAST entièrement clos** (stockage + API). **Tag v0.58.0 et v0.60.0 NON poussés** : le proxy git de l'environnement refuse les push de tags (HTTP 403) — à pousser + release GitHub depuis une machine aux droits complets, en tagant les commits de merge sur `main`.

- **2026-06-02** — Release **v0.58.0** (feat — **FAST 100 % pur raster : retrait de l'insertion `obs_pixel`**, finalisation spec 017). Chantier **pure-raster FAST clos côté stockage**. Depuis spec 017 (v0.55.0) `read_fast_alert_raster()` énumère les scènes depuis le cache COG, indépendamment de `obs_pixel`/placettes ; et `nemetonshiny@v0.52.16` (consommateur en aval) a retiré toute lecture `obs_pixel` (plus de `read_obs_pixel()`, plus de modale per-placette, plus de `CircleMarkers`). Côté cœur, les deux résidus identifiés par le brief sont traités — **mais le grep a révélé que le brief sous-estimait le périmètre** : trois fonctions exportées (pas une seule) lisaient encore `obs_pixel`. Décision utilisateur (AskUserQuestion) : **déprécier les trois ensemble**. Phase A livrée : (1) `ingest_sentinel2_timeseries()` réduit à amorcer le cache COG (B04/B08/B12) — plus de moyenne per-placette, plus de `.insert_obs_pixel()`, champ `n_obs_inserted` retiré, `skip_cached` rebasé sur la présence des COG sur disque ; STAC + cache COG + heartbeats `s2:*` intacts ; (2) migration `0004_drop_obs_pixel.sql` (PG `CASCADE` + SQLite, idempotente) ; (3) dépréciation `@keywords internal` + `cli_warn` de `read_obs_pixel()`, `list_fast_alerts_for_zone()` (FAST per-placette legacy) et `detect_alerts()` (alertes per-placette legacy) — retrait prévu **v0.60.0** ; helpers internes `.insert_obs_pixel()`/`.find_cached_obs_dates()` supprimés, `.extract_scene_obs()` → `.cache_scene_bands()` (+`.s2_required_bands()`/`.scene_cogs_cached()`). **Non breaking app** (`@*release` tire le patch, aucun bump `Imports` — règle 11 cœur→app respectée, l'app a fait sa part en avance) ; **breaking pour les appels directs** aux 3 fonctions (warning maintenant, retrait v0.60.0). Tests : `test-monitoring.R` réécrit (amorçage COG + skip COG-based), `test-db.R` (0004 drop PG+SQLite idempotent), `test-ingest-cancel.R` (cache COG partiel), `test-obs_pixel-deprecation.R` (3 warnings) ; 4 suites `obs_pixel` supprimées. **NON TESTÉ EN CI ICI** (pas de R) — rejouer sur les deux backends via `NEMETON_DB_URL_TEST` + `devtools::document()` (les `man/*.Rd` édités à la main). **Phase B (v0.60.0)** : retrait définitif des 3 fonctions + retrait du `CREATE TABLE obs_pixel` des migrations 0001 (la 0004 reste pour les bases existantes).

- **2026-06-01** — Release **v0.55.2** (fix — **incompatibilités SQLite résiduelles dans les UPSERT `ON CONFLICT`**, suite du brief incident Windows/SQLite). Audit complet `git grep 'ON CONFLICT'` côté cœur après v0.55.1 : le correctif précédent ne couvrait qu'**un** des trois `INSERT … SELECT … ON CONFLICT`. **Trois sites restants** corrigés : (1) `db_migrate()` (R/db.R) — `INSERT INTO schema_migration … ON CONFLICT DO NOTHING` **sans colonne cible**, valide seulement sur SQLite ≥ 3.35.0, branché par backend vers `INSERT OR IGNORE` (forme SQLite native universelle) ; (2) `.insert_fordead_alerts()` (R/fordead_postprocess.R) — **même ambiguïté UPSERT/jointure que `.insert_obs_pixel()`** sur un `INSERT … SELECT … FROM tmp_fordead_alert_staging`, échoue sur **toutes** versions SQLite, `WHERE 1=1` ajouté ; (3) `detect_alerts()` (R/alerts.R) — même classe d'ambiguïté durcie par cohérence (`WHERE 1=1`), mais requête PG-only par ailleurs (fenêtres `RANGE BETWEEN INTERVAL`) donc latente sous SQLite. **Non concernés** : `rag.R` et insert `plot` (R/monitoring.R) utilisent `VALUES` (pas de `SELECT`) → déjà SQLite-safe. **Nuance diagnostic** : le crash réellement remonté par l'utilisateur (projet `20260526_092733_wrzs` déjà migré → `db_migrate()` retourne tôt sans atteindre le `schema_migration` INSERT) était bien `.insert_obs_pixel()` (corrigé v0.55.1), pas `db_migrate()` comme le supposait le brief ; mais l'audit a révélé deux bombes à retardement SQLite supplémentaires (FORDEAD + le no-target). Tests : `helper-sqlite.R` (fixtures mutualisées), `test-fordead-alert-insert-sqlite.R` (insertion FORDEAD + idempotence `DO NOTHING` + `db_migrate` via `INSERT OR IGNORE` sur backend SQLite réel), `test-insert-obs-pixel-sqlite.R` refactorisé sur le helper. Base de version du brief (v0.54.0→v0.54.1) périmée : le repo était à v0.55.1, donc ce patch sort en **v0.55.2**. **NON TESTÉ EN CI ICI** (pas de R dans l'environnement) — à rejouer sur machine avec R (RSQLite + sf). Côté app `nemetonshiny` : rien à bumper, `@*release` tire le patch ; réinstaller `nemeton@*release`. **Reco** : matrice CI exécutant la suite d'intégration sur les DEUX backends (Postgres + SQLite tempfile) pour prévenir ce type de divergence.

- **2026-06-01** — Release **v0.55.1** (fix — **`near "DO": syntax error` à l'ingestion S2 sur backend SQLite local**). Crash fatal du worker Sentinel-2 (`Worker fatal error (simpleError/error/condition): near "DO": syntax error`) dès le premier `INSERT` de pixels quand le backend monitoring est le SQLite local (cas Windows/Clever Cloud injoignable). Cause : `.insert_obs_pixel()` (R/monitoring.R) charge en masse via une table de staging puis `INSERT INTO obs_pixel … SELECT … FROM staging ON CONFLICT (plot_id, obs_date, band) DO NOTHING`. Quand un `INSERT` tire ses lignes d'un `SELECT` (et non de `VALUES`), l'analyseur SQLite ne peut pas décider si le `ON` final ouvre la clause UPSERT ou le `ON` d'une jointure : il interprète `ON CONFLICT (…)` comme une condition de jointure et échoue sur `DO`. Conformément à la doc SQLite (« the SELECT statement should always include a WHERE clause »), ajout d'un `WHERE 1=1` sur le `SELECT` qui lève l'ambiguïté grammaticale. **No-op sous PostgreSQL** (prod non concernée). Les autres `ON CONFLICT … DO NOTHING` du repo (rag.R, alerts.R, fordead_postprocess.R, db.R) utilisent tous `VALUES` → pas d'ambiguïté, non touchés. **Test de non-régression** `test-insert-obs-pixel-sqlite.R` (nouveau) : exerce `.insert_obs_pixel()` sur un vrai backend SQLite file-backed migré (le backend réellement cassé, donc aucune DB externe requise — contrairement au reste de la suite monitoring, Postgres-only via `skip_if_no_timescaledb()`) — non-erreur + 2 lignes insérées, idempotence `DO NOTHING` (ré-insert = no-op), entrée vide = no-op. **NON TESTÉ EN CI ICI** (pas de R dans l'environnement) — à rejouer sur machine avec R. Côté app `nemetonshiny` : rien à bumper, `@*release` tire le patch.

  - 2026-05-21 — nemetonshiny v0.39.0 (cycle dev 0.38.8.9000) — E6 contexte
    santé : canal de notification ntfy pour les runs FORDEAD longs (émis
    côté worker `future`, indépendant de la session Shiny) + réconciliation
    des onglets « Alertes/Carte FORDEAD » depuis le masque persisté après un
    run hors-session. nemetonshiny@38bafc2. Livraison portée app — aucune
    modification cœur.
  - 2026-05-21 — nemetonshiny v0.39.1 (cycle dev 0.39.0.9001) — E6 :
    réparation de 20 tests préexistants (suites monitoring + sampling) + 3
    correctifs de production (icône bsicons `folder2-open`, `suppressWarnings`
    dans `.build_progress_writer`, dé-classage `json` dans
    `audit_to_dataframe`). nemetonshiny@f7bed92. Livraison portée app.
  - 2026-05-21 — nemetonshiny v0.40.0 (cycle dev 0.39.1.9000) — E6 : verrou
    croisé FAST ↔ FORDEAD (lancement mutuellement exclusif — cache
    Sentinel-2 partagé) + renommage `ingest_task` → `fast_task`.
    nemetonshiny@de2e0b7. Livraison portée app.
  - 2026-05-22 — Spec « échantillonnage de validation piloté par raster
    d'alerte » rédigée, 6 décisions arrêtées
    (nemetonshiny/design/validation-sampling.md). Phase A = travail cœur
    `nemeton` à venir : `fordead_alert_mask()`, GRTS pondéré
    (`priority_raster`), `create_validation_sampling_plan()`, raster
    d'alerte FAST + `read_fast_alert_raster()`. Cahier des charges :
    nemetonshiny/design/nemeton-phase-a-brief.md.

- **2026-06-02** — Release **v0.57.0** (feat — **calcul raster multi-cœur opt-in**, spec 017 D4, **clôt la spec 017**). `build_index_stack()` + `read_fast_alert_raster()`/`compute_fast_alert_mask()` gagnent `parallel = FALSE`. Quand `parallel = TRUE` et `furrr` installé, le calcul **par scène** de l'indice (ouverture COG + band-math, la phase dominante) tourne en `furrr::future_map()` (le `future::plan()` est choisi par l'appelant — `multisession` en prod, `multicore` fork en test). Un `SpatRaster` étant un pointeur externe non sérialisable inter-process, les workers renvoient des rasters `terra::wrap()`-és, `unwrap()`-és côté principal (pas d'écriture concurrente, band-math pur sans DB). **Repli séquentiel transparent** : `parallel=TRUE` sans `furrr` → `lapply` + avertissement once-per-session ; résultats **strictement identiques** au séquentiel. `furrr`/`future` déjà en Suggests (aucune nouvelle dépendance). Tests : `test-pixel-map.R` (build_index_stack parallel==séquentiel via plan sequential in-process exerçant wrap/unwrap) ; `test-fast-alert-raster.R` (read_fast_alert_raster parallel==séquentiel) ; validé manuellement aussi en `multicore` fork réel (valeurs identiques). **Spec 017 CLOSE** : D1-D3/D5 (v0.55.0) + D6 (v0.56.0) + D4 (v0.57.0). **Note process** : `git fetch` systématique avant push depuis l'incident v0.56.0 (une autre session a livré v0.55.1/.2 SQLite en parallèle ; mon v0.56.0 initial mal basé a été rebasé sur v0.55.2 puis le tag re-pointé). Côté app `nemetonshiny` : toggle « Mode rapide (multi-cœur) » → `parallel=TRUE`, corriger l'appel `read_fast_alert_raster()` à la signature v0.55 (`index`/`threshold`), plancher `Imports: nemeton (>= 0.57.0)`.

- **2026-06-01** — Release **v0.56.0** (feat — **persistance content-addressed du raster d'alertes FAST**, spec 017 D6, phase perf). `read_fast_alert_raster()` persiste le raster continu en **COG adressé par contenu** sous `<result_cache_dir>/zone_<id>/fast_<index>_<mode>_<hash>.tif` (défaut `result_cache_dir = dirname(cache_dir)/fast_raster`). Nouveaux paramètres `cache_result = TRUE` + `result_cache_dir = NULL`. Le `hash` (`.fast_raster_hash()` via `rlang::hash`, **pas** de dépendance `digest` — écart assumé vs spec, plus léger) digère {scènes triées + index + threshold + mode + window_days + dates + WKT du masque} → **auto-invalidation par le contenu** (nouvelle scène cache / changement param / ré-inscription zone → recalcul ; sinon lecture disque instantanée, attribut `cached=TRUE`). GC LRU `getOption("nemeton.fast_raster_keep", 20)` COGs/zone (`.fast_raster_gc()`). Chemin distinct du cache masque 0-4 (`fast/zone_<id>/fast_alert_<ts>.tif`) → pas de collision avec `read_fast_alert_mask()`. `compute_fast_alert_mask()` expose `cache_result`/`result_cache_dir` en passe-plat → **quartiles recalculés depuis le COG persisté** sans recalcul raster. Le masque UGF est résolu **avant** le hash (`poly` partagé). Tests : `test-fast-alert-raster.R` 46 PASS (+14 D6 : hash déterministe/sensible aux entrées + insensible à l'ordre des scènes + window_days ignoré en count mais comptant en rolling ; persiste+sert le COG avec `cached=TRUE` + recalcul sur changement de threshold ; `cache_result=FALSE` n'écrit rien). Les 3 tests d'intégration (villards réel) passent `cache_result=FALSE` pour ne pas polluer le répertoire projet. **Plus gros gain UX** : 1er diagnostic coûteux (mitigé par D4 à venir), revisites gratuites. **Reste spec 017** : D4 parallélisation `furrr` → v0.57.0.

- **2026-05-31** — Release **v0.55.0** (feat/changed — **carte d'alertes FAST : indicateur unique + quartiles + énumération cache**, spec 017 phase sémantique). Recadrage important après profiling empirique : le « Diagnostic FAST » lent n'est PAS l'ingest per-placette (`obs_pixel` per-plot, ~37k lignes, DB déjà bulk ≤19s batchable à ~1s) ni un problème DB (la prémisse « 2.4M lignes » du brief confondait pixels-raster et lignes-DB) — c'est la **carte d'alertes raster per-pixel** `read_fast_alert_raster()`, dont le band-math séquentiel sur scènes×tuiles domine. Spec 017 rédigée + validée (D1-D6 via AskUserQuestion). **Phase sémantique livrée** : (D1) indicateur unique `index=c("NDVI","NBR")` défaut NDVI, `threshold` unique remplace `threshold_ndvi`/`threshold_nbr`, mode OU-des-deux supprimé (une seule pile → ÷2 raster) ; (D2) `compute_fast_alert_mask()` en **quartiles des pixels en alerte** (classe 0 = sain, 1-4 = `c(0,q25,q50,q75,Inf)`) pour count ET rolling, dégénérescences gérées (`.fast_alert_quartile_breaks()`) ; (D3) **énumération des scènes depuis le cache COG** (`.enumerate_cache_scenes()` + `.s2_scene_date()`), plus aucun `read_obs_pixel()` → diagnostic **indépendant des placettes** (construites après) ; (D5) `con`/`zone_id` gardés pour le seul masque UGF. `.compute_alert_count()`/`.compute_alert_rolling()` réécrits mono-indice. Tests : `test-fast-alert-raster.R` 32 PASS (énumération cache, mono-indice NDVI sans B12 / NBR sans B04, helpers), `test-fast-alert-mask.R` 27 PASS (quartiles + dégénérescences + classify toléré sur bornes égales) ; `test-zone-mask.R` durci (assertion stricte gardée sur ratio polygone/bbox — villards ré-enregistrée est ~rectangulaire, masque ne coupe rien, ce n'est pas une régression). **Phases perf à suivre** (spec 017) : **D6 persistance content-addressed du COG résultat → v0.56.0** (plus gros gain UX, revisites instantanées, recommandé avant le parallèle), **D4 parallélisation furrr → v0.57.0**. Côté app `nemetonshiny` : toggle indicateur NDVI/NBR + corriger le désalignement « Diagnostic FAST » (appelle l'ingest per-placette au lieu de `read_fast_alert_raster`), plancher `Imports: nemeton (>= 0.55.0)`.

- **2026-05-31** — Release **v0.54.0** (feat/changed — **isolation DB tests `NEMETON_DB_URL_TEST`**). Suite à l'**incident villards** (la zone `20260520_212017_btfe` créée à 10:39 puis silencieusement détruite à 11:09, remplacée par la stub de test `Zskip`/`P01` ; migrations 0001/0002/0003 ré-appliquées plusieurs fois = perte de `schema_migration` ; `plot` réduit à `id=1` → FK violation `obs_pixel(plot_id=2)` côté ingestion FAST). Cause : `helper-monitoring.R::with_clean_db()` exécute des `DROP TABLE … CASCADE` sur le schéma monitoring, et le garde-fou par comparaison d'URL ne couvrait PAS le cas réel (`NEMETON_DB_URL_TEST` pointant sur la prod `nemeton` alors que `NEMETON_DB_URL` est vide → `same_url`/`fellback_main` tous deux faux). **Fix** : tout accès DB d'intégration passe par `.guard_test_db()` (logique env pure, sans connexion : skip si `NEMETON_DB_URL_TEST` absent, skip si == `NEMETON_DB_URL`) + `.test_db_connect(read_only=FALSE)` qui ajoute la **couche décisive** — refus de toute base portant des tables applicatives (`projects`/`users`/`parcels`), seule à rattraper le scénario réel. `skip_if_no_timescaledb()` et `with_clean_db()` réécrits pour passer par ces helpers ; bloc des `DROP` inchangé (devenu inoffensif car la connexion cible est garantie jetable). Override `NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE`. Livrables : `test-helper-guards.R` (4 tests offline : unset→skip, ==prod→skip, distinct→pass, et le cas incident prod-unset documentant pourquoi la couche tables-applicatives est nécessaire), `.Renviron.example`, section dédiée dans `CLAUDE.md`. Vérifié : guards 4 PASS ; `test-read_obs_pixel.R` → 4 tests d'intégration SKIP (pas FAIL) contre la vraie base `nemeton`, et idem scénarios « TEST unset » et « TEST == prod ». CI (`r.yml`) sans service postgres → tests d'intégration skip proprement, build vert (pas de var ajoutée qui pointerait dans le vide). **Breaking côté setup dev** : `devtools::test()` exige désormais un `NEMETON_DB_URL_TEST` dédié (ex. `nemeton_test`) pour rejouer l'intégration ; sinon skip. Aucune API publique modifiée, pas de bump côté app. **Mea culpa** : c'est moi (session cœur) qui ai re-déclenché l'incident en lançant `testthat::test_dir()` plusieurs fois contre la base `nemeton` malgré la note mémoire ; ce garde-fou rend la récidive impossible.

- **2026-05-31** — **`nemetonshiny@80d36ff` (v0.52.0)** : **câblage app du cancel coopératif** (consomme `nemeton@v0.53.0`). `cancel_path` forwardé depuis `run_ingestion_async()` / `run_fordead_async()` vers `ingest_sentinel2_timeseries()` / `run_fordead_dieback()` ; les observers `input$run_cancel` et `input$run_health_cancel` écrivent `<projet>/data/{fast,fordead}_cancel.flag` **avant** `force_unlock` ; purge du flag résiduel **avant chaque** `invoke()` (garde-fou « flag pré-existant ignoré » côté cœur, mais on nettoie proactivement). Boucle « Libérer l'interface » → vrai « Annuler le diagnostic » désormais fermée. Cycle dev `0.51.11 → 0.51.11.9001 → release stable v0.52.0` (MINOR, feat). Livraison portée app — aucune modification cœur. Le chantier **cancel coopératif FAST/FORDEAD est clos sur les deux repos**.

- **2026-05-31** — Release **v0.53.0** (feat — **cancel coopératif FAST/FORDEAD workers**). Problème : les workers longs (`ingest_sentinel2_timeseries`, `run_fordead_dieback`) tournent dans un process `future::multisession` séparé et `shiny::ExtendedTask` n'offre aucune API d'annulation ; le bouton « Libérer l'interface » (`nemetonshiny` v0.51.11, `mod_monitoring.R:1556`) ne pouvait que ré-activer l'UI, le worker continuant téléchargements + INSERTs + ntfy sur 30-60 tuiles après le clic (bande passante/CPU gaspillés, risque de 2 workers concurrents sur le même cache/DB). **Solution cœur** : mécanisme de cancel coopératif file-based symétrique. Nouveau `R/cancel.R` (helpers internes `.cancel_flag_exists()`, `.make_cancel_checker()`, `.signal_cancel_fordead()`). **`ingest_sentinel2_timeseries(..., cancel_path = NULL)`** : poll `file.exists(cancel_path)` entre tuiles ; sortie propre après la tuile courante, tuiles déjà ingérées commitées (chaque `.insert_obs_pixel()` a sa transaction → commit partiel gratuit, reprise possible) ; résumé enrichi d'une colonne `status` (`success`/`cancelled`), événement `s2:cancelled`. **`run_fordead_dieback(..., cancel_path = NULL)`** : poll aux frontières de phase (après ingest/fit/predict via condition classée `nemeton_cancelled` catchée avant le handler `error`) ; la phase courante finit (pas de SIGINT dans le Python reticulate), retour `status = "cancelled"` + champ `phase`, événement `fordead:cancelled`. **Garde-fous** : `cancel_path = NULL` → zéro appel `file.exists` (perf identique) ; flag présent à l'entrée = résidu ignoré pour tout le run (avertissement, le caller doit le supprimer avant chaque `invoke()`) ; chemin invalide → `file.exists` FALSE, jamais de crash. Aucune signature publique cassée (`cancel_path` optionnel). **Tests** : `test-ingest-cancel.R` (nouveau, 21 PASS) — unitaires `.make_cancel_checker` (NULL → 0 poll, vide/NA inerte, flag armé → TRUE après création, flag pré-existant ignoré + warning, chemin invalide robuste) + intégration TimescaleDB (cancel mid-run → `status=cancelled`, `n_scenes=2`, 2 tuiles en base, `s2:cancelled` émis ; régression `cancel_path=NULL` ; flag périmé ignoré) ; `test-fordead-pipeline.R` +2 (cancel après fit, `predict` jamais appelé, `phase=fit`, `fordead:cancelled` émis ; flag périmé ignoré). `test-monitoring.R` mis à jour (colonne `status` dans la forme canonique). Côté app `nemetonshiny` (✅ **livré 2026-05-31, `nemetonshiny@80d36ff` v0.52.0**, cf. entrée ci-dessus) : `cancel_path` câblé aux `fast_task$invoke()`/`fordead_task$invoke()`, flag écrit dans l'observer d'annulation (`<projet>/data/fast_cancel.flag` / `fordead_cancel.flag`), supprimé avant chaque lancement, bouton renommé « Annuler le diagnostic », plancher `Imports: nemeton (>= 0.53.0)`. `Remotes: pobsteta/nemeton@*release` tire le cœur.

- **2026-05-30** — Release **v0.52.1** (fix — **`build_index_stack()` & FAST alert : union+pad pour AOI multi-tuiles MGRS**). Symptôme (projet `nemetonshiny` villards, dépt 39, `20260520_212017_btfe`) : un AOI à cheval sur deux tuiles MGRS qui se recouvrent (T31TFM ⊂ T31TGM, zone de recouvrement S2 ~10 km, comportement nominal) produit des scènes cachées d'emprises hétérogènes — T31TFM ne couvre que la bande de recouvrement (440 m), T31TGM couvre tout l'AOI (1340 m). `build_index_stack()` réduisait la pile à l'**intersection** des emprises (`terra::intersect` + `terra::crop`, code v0.47.5) → pile cropée à 709360–709800 au lieu de 709360–710700 → la moitié de l'AOI jamais rendue sur la carte pixel NDVI/NBR, alors que les scènes larges existaient dans le cache. **Fix** : `build_index_stack()` aligne désormais chaque couche sur l'**union** des emprises via `terra::extend()` (marges non couvertes → NA, pas de pixel inventé) au lieu de cropper. Conserve `terra::time()`, `names()`, l'attribut `index`, le masque de zone aval. **Garde-fou multi-CRS** : couches en CRS différents (AOI rare à cheval sur 2 zones UTM) reprojetées sur la grille de la 1re couche avant l'union (`terra::project`) ; cas nominal (même tuile, même grille) = padding seul, pas de resample ; dérive origine/résolution > 1e-6 → repli `terra::resample()` vers la couche la plus large, signalé en `rlang::inform`. **FAST alert** (`read_fast_alert_raster()` / `compute_fast_alert_mask()`) **structurellement inchangé** : le chemin alertes groupe déjà les scènes par tuile MGRS et mosaïque `fun = "max"` (spec 013). Ce regroupement reste **nécessaire** : (1) ne pas double-compter la bande de recouvrement (même date d'acquisition présente dans les deux tuiles → un `count` sur pile unionnée la tallerait deux fois) ; (2) gérer le multi-CRS. Il bénéficie du union+pad au sein de chaque tuile (la dérive intra-tuile ne rogne plus la couverture). **Bruit console** : warning « Skipped N/total scenes » de `build_index_stack()` (émis ~12×/chargement par le réactif Shiny) rétrogradé en `rlang::inform(.frequency = "once")` — une ligne/session, plus de warning. **Tests** (`test-pixel-map.R`) : régression union (narrow ⊂ wide → pile à l'union, narrow NA-paddée, 2 couches), dates indépendantes (2 dates × 2 tuiles → 4 couches sur l'union), multi-CRS (UTM 31N + 32N → resample déclenché, pile dans le CRS de la 1re couche), dédupe (`expect_no_warning` sur appel répété) ; les 2 anciens tests qui asseyaient l'intersection (alignement v0.47.5, disjoint → NULL) mis à jour pour l'union. Suite `test-pixel-map.R` 66 PASS / 0 FAIL ; `test-fast-alert-{raster,mask}.R` 38 PASS / 0 FAIL. Côté app : rien à modifier, `Remotes: pobsteta/nemeton@*release` tire le patch (pas de nouvelle API, pas de bump `Imports`).

- **2026-05-29** — Release **v0.52.0** (feat — **machinerie RAG perspectives IA**, E7, spec 009). Première brique de E7 : la *machinerie* de récupération augmentée (le corpus est livré séparément par la spec fille 009.1, décisions D1-D5 actées le même jour). **7 fonctions exportées** dans `R/rag.R` : `enable_rag()`, `ingest_knowledge_document()`, `embed_query()`, `retrieve_knowledge()`, `list_knowledge_documents()`, `delete_knowledge_document()`, `format_citations()`. **Schéma opt-in** `knowledge_document` + `knowledge_chunk` (`inst/db/migrations/{pg,sqlite}/rag/0004_rag.sql`), appliqué par `enable_rag()` et **délibérément hors de la séquence `db_migrate()` automatique** : la variante PG exige l'extension `pgvector` (présente dans l'image prod `timescaledb-ha:pg16` mais pas garantie partout) ; la fondre dans la séquence auto ferait planter `db_migrate()` sur une base sans pgvector. **Dual-backend** : sur PostgreSQL la similarité utilise l'opérateur `<=>` pgvector ; sur SQLite les embeddings sont stockés en JSON (`TEXT`) et le cosinus est calculé en R (adapté à un corpus mono-projet). **Providers d'embeddings** : Mistral (défaut, ADR-004), OpenAI, Voyage AI — tous via endpoint compatible OpenAI ; `retrieve_knowledge()` avertit si le corpus mélange plusieurs providers. **Écart assumé vs spec** : colonne `embedding vector(3072)` (choix « provider le plus large ») mais pgvector plafonne ses index ivfflat/hnsw à **2000 dims** → pas d'index ANN, KNN **exact** (`<=>` seq scan), parfait pour quelques milliers de chunks ; bascule `halfvec(3072)`+`hnsw` reportée à ADR-012. **40 tests** (`test-rag.R`) : chunking, cosinus, encodage, validation métadonnées, citations + intégration sur **SQLite temporaire** (jamais une base externe) avec embedder mocké déterministe — toujours exécutables sans `NEMETON_DB_URL_TEST`. `pdftools` ajouté en Suggests. `reset_schema()` du helper de test étend le drop aux tables `knowledge_*`. **Reliquat E7** : corpus (spec 009.1) + wiring `nemetonshiny` (injection chunks dans le prompt + bloc UI « Sources »). **NON TESTÉ EN CI ICI** au-delà de `test-rag.R` chargé via `load_all` — `devtools::check()` complet lancé en parallèle, à confirmer.

- **2026-05-28** — **Chantier « backend monitoring local » CLOS sur les deux repos** (Bug #2 : verrou de fichier `File is already open in Rscript.exe` quand la session Shiny et le worker `future::multisession` ouvraient le même fichier local). Résolution de fond : abandon de DuckDB (écrivain mono-process exclusif) au profit de **SQLite/WAL** (1 writer + N lecteurs concurrents inter-process). **Cœur `nemeton`** : v0.50.0 (SQLite/WAL introduit + dépréciation DuckDB), v0.50.1 (fix warning RSQLite `result_fetch` — PRAGMA sans résultat routés via `dbExecute`), v0.51.0 (retrait complet de DuckDB ; backends restants PostgreSQL + SQLite ; une URL `duckdb:///` lève désormais une erreur d'orientation). **App `nemetonshiny`** : v0.49.0 (merge `85d3119`) bascule le backend local par défaut DuckDB → SQLite/WAL en consommant `nemeton@v0.50.0` ; v0.50.0 (merge `701babc`) coupe nette côté app — `.resolve_monitoring_db_url()` émet toujours `sqlite://<projet>/data/monitoring.sqlite`, suppression de la branche back-compat `monitoring.duckdb` et du helper `.nemeton_supports_duckdb()`, `duckdb` retiré des Suggests, plancher `Imports: nemeton (>= 0.51.0)`, zéro référence `duckdb` dans `R/`. Cycle dev app `0.48.2 → 0.49.0 → 0.50.0`. **Note de migration des données** : un `monitoring.duckdb` local n'est plus lu ni migré ; le suivi local repart sur un `monitoring.sqlite` neuf — les séries `obs_pixel` sont ré-ingérables depuis le cache Sentinel-2. Plus aucun reliquat « backend local » ouvert.

- **2026-05-28** — Release **v0.51.0** (removed — **retrait complet du backend monitoring DuckDB**, BREAKING). Décision « couper net » après le remplacement par SQLite/WAL (v0.50.0) et le fix du warning (v0.50.1) : DuckDB n'apportait rien que SQLite ne fasse mieux ici, et son écrivain mono-process exclusif était la cause du Bug #2. Backends restants : PostgreSQL (prod) + SQLite (local). Retraits côté `R/db.R` : case `duckdb` du switch de `db_connect()`, branche duckdb de `.detect_driver()` (remplacée par une erreur explicite renvoyant vers `sqlite:///`) et de `.assert_db_pkgs()`, `.parse_duckdb_url()`, `.warn_duckdb_deprecated_once()` + `.nemeton_db_state`, branche `shutdown=TRUE` de `db_disconnect()`, mapping duckdb de `.default_migrations_dir()`. Suppression de `inst/db/migrations/duckdb/` (3 .sql) et de `duckdb (>= 0.8.0)` dans les Suggests. Commentaires des shims `is_pg` (monitoring.R, fordead_postprocess.R) et doc (read_obs_pixel.R, fast_alerts.R, man/*.Rd) nettoyés des mentions DuckDB. Tests : blocs DuckDB de `test-db.R` retirés, ajout d'un test que `.detect_driver()` rejette les URLs DuckDB avec un message d'orientation ; blocs PostgreSQL et SQLite conservés. **Pas de migration de données** (bases DuckDB locales re-générables par ré-ingestion). Bump MINEUR (BREAKING mais on reste en 0.x, convention projet). **NON TESTÉ EN CI ICI** (pas de R dans l'environnement) — à rejouer sur machine avec R. Suite app : `nemetonshiny` doit émettre `sqlite:///` (chantier dédié) et épingler `nemeton (>= 0.51.0)`.

- **2026-05-28** — Release **v0.50.1** (fix — warnings RSQLite `result_fetch` à la connexion SQLite). Symptôme remonté par l'app après bascule SQLite/WAL : à chaque `db_connect()` SQLite, RSQLite émettait `dbGetQuery()/dbSendQuery()/dbFetch() should only be used with SELECT queries`. Diagnostic initial app : attribué à tort à `db_migrate()` exécutant du DDL via `dbGetQuery()` — vérification faite, `db_migrate()` utilise déjà `dbExecute()` pour le DDL. La vraie source est `.sqlite_apply_pragmas()` (livré v0.50.0) qui routait *tous* les PRAGMA via `dbGetQuery()` : `PRAGMA foreign_keys = ON` et `PRAGMA synchronous = NORMAL` ne renvoient aucune ligne → RSQLite (strict sur l'API de résultat) avertit. Fix : routage explicite — `busy_timeout` et `journal_mode` (renvoient une valeur) restent sur `dbGetQuery()`, `foreign_keys` et `synchronous` (sans résultat) passent sur `dbExecute()`. Purement cosmétique (connexion + migrations fonctionnaient déjà). Test : `expect_no_warning()` autour de `db_connect()` + `db_migrate()` sur SQLite. PostgreSQL/DuckDB non concernés. **NON TESTÉ EN CI ICI** (pas de R dans l'environnement de dev) — à rejouer sur machine avec R. Côté app : rien à bumper, `@*release` tire le patch.

- **2026-05-28** — Release **v0.50.0** (feat — backend monitoring local **SQLite/WAL** en remplacement de DuckDB ; Bug #2 résolu à la racine). Suite de v0.49.2 (qui ne contournait Bug #2 qu'à moitié via `read_only`). **Constat d'audit** : DuckDB n'était utilisé QUE pour le monitoring et n'exploitait AUCUNE de ses forces colonnaires — toutes les branches `inherits(con,"duckdb_connection")` étaient de simples shims de portabilité (TEMP TABLE sans `ON COMMIT DROP`, évitement de casts PG-only) ; le SQL ne fait que des INSERT transactionnels + SELECT d'affichage, le calcul lourd est en R/terra. Choix d'origine (NEWS v0.21.0) : « Postgres overkill for single-user », jamais justifié par de l'analytique. Or l'unique trait distinctif de DuckDB fichier — l'écrivain mono-process EXCLUSIF — est précisément ce qui casse Bug #2 (session Shiny + worker `future` ne peuvent ouvrir le fichier ensemble). **SQLite en WAL** est un meilleur fit : 1 writer + N lecteurs concurrents ENTRE PROCESSUS, écritures sérialisées via `busy_timeout` ; et RSQLite est déjà une dépendance (tirée par l'I/O GeoPackage), donc zéro ajout. **Livraison** : (a) nouveau scheme `sqlite:///fichier.sqlite` (+ chemin nu `.sqlite`/`.db`) dans `.detect_driver()` / `.parse_sqlite_url()` / `.assert_db_pkgs()` / `db_connect()` ; PRAGMA `journal_mode=WAL` + `busy_timeout=10000` + `foreign_keys=ON` + `synchronous=NORMAL` appliqués à la connexion (helper `.sqlite_apply_pragmas()`), `read_only=TRUE` ouvre via `SQLITE_RO` ; (b) migrations `inst/db/migrations/sqlite/` (0001/0002/0003) en dialecte SQLite — `INTEGER PRIMARY KEY AUTOINCREMENT` au lieu de séquences, et comme SQLite supporte les index partiels le 0003 garde `WHERE project_uuid IS NOT NULL` ; (c) **wrapper portable** `.db_execute()` / `.db_get_query()` + `.sqlite_translate_params()` qui réécrit les placeholders `$n` (PG/DuckDB) en `?` et réordonne les params — RSQLite traite `$1` comme un paramètre NOMMÉ et ne le lie pas positionnellement depuis une liste non nommée ; tous les sites `params=` des 6 fichiers monitoring (monitoring.R, fordead_postprocess.R, alerts.R, find_zone_by_project.R, zone_aoi.R, health_validation.R) + `db_migrate()` routés via ces wrappers ; (d) shims `is_duckdb` généralisés en `is_pg <- inherits(con,"PqConnection")` (SQLite emprunte le chemin portable de DuckDB pour les TEMP TABLE) ; (e) **`db_migrate()`** : la branche split-statements couvre désormais sqlite (tout sauf pg). **Déprécation DuckDB** : `cli_warn` one-shot à la connexion `duckdb:///`, code et migrations duckdb conservés une release de plus, pas de migration auto des données. **Tests** `test-db.R` : `.detect_driver`/`.parse_sqlite_url`/`.sqlite_translate_params` (dont placeholders hors-ordre), connexion WAL (`PRAGMA journal_mode`='wal'), création parent dir, migrate 0001-0003 + tables + colonnes FORDEAD + project_uuid, no-op re-run, round-trip `$n` via wrappers sur vraie connexion RSQLite (régression du risque #1), index partiel 0003 (NULL multiples OK / doublon rejeté), erreur read_only fichier absent, coexistence reader RO + writer RW en WAL. **NON TESTÉ EN CI ICI** : la session de dev cœur n'avait pas R installé — la sonde RSQLite et `devtools::test()` doivent être rejoués sur une machine avec R avant merge (risque résiduel sur le binding `$n` et le round-trip des dates SQLite, à valider). **Côté `nemetonshiny`** : émettre `sqlite:///` au lieu de `duckdb:///` quand `NEMETON_DB_LOCAL` ; ce changement rend caduc le garde-fou « Option D ». PR #31 mergée (cf. entrée de synthèse 2026-05-28 « backend monitoring local CLOS »).

- **2026-05-28** — Release **v0.49.2** (fix — monitoring DuckDB local utilisable sous Windows). Symptôme remonté en prod (machine Windows, projet `20260526_092733_wrzs`, PostgreSQL/Clever Cloud injoignable → fallback DuckDB local via `NEMETON_DB_LOCAL`) : monitoring complètement cassé par **deux bugs cœur distincts**. **Bug #1 — index partiel.** `inst/db/migrations/duckdb/0003_project_uuid.sql` créait un index UNIQUE *partiel* (`WHERE project_uuid IS NOT NULL`) ; DuckDB ne supporte pas les index partiels (`Not implemented Error: Creating partial indexes is not supported currently`), donc la migration 0003 échouait et le schéma monitoring restait incomplet. Le commentaire d'en-tête du fichier affirmait à tort que DuckDB supportait cette syntaxe « depuis v0.5 ». Fix : index UNIQUE *complet* sans clause `WHERE` — DuckDB suit le standard SQL (NULLs distincts pour l'unicité), donc les zones historiques à `project_uuid` NULL multiples restent tolérées tandis que les valeurs non-NULL restent uniques : sémantique strictement identique à l'index partiel PG, qui lui reste inchangé (`pg/0003` non touché). **Bug #2 — verrou inter-processus.** Un fichier DuckDB n'autorise qu'un seul processus en read-write, mais plusieurs connexions read-only simultanées. Quand le worker `future::multisession` (FAST/FORDEAD) ouvre `monitoring.duckdb` en read-write, la session Shiny principale ne peut plus l'ouvrir (`File is already open in Rscript.exe`). Fix (enabler cœur, Option A) : `db_connect(url, read_only = FALSE)` gagne le paramètre — les lecteurs ouvrent en `read_only = TRUE` (en read-only le fichier doit préexister, le parent n'est pas créé) ; no-op pour PostgreSQL (concurrence native). Le câblage read-only des readers côté `nemetonshiny` (ouvrir en read-only dans la session Shiny, garder read-write au seul moment de l'INSERT du worker) reste à faire côté app. Tests (`test-db.R`) : migration 0003 DuckDB sans erreur, index tolère NULL multiples / rejette doublon non-NULL, validation de `read_only`, erreur claire si fichier read-only absent, coexistence reader RO + owner RW dans le même process. **Limites connues** : si le worker garde le handle read-write ouvert toute la session, les readers RO restent bloqués pendant ce temps (DuckDB : RW exclusif même vis-à-vis des RO) ; workaround immédiat utilisateur tant que l'app n'a pas câblé l'ouverture courte du writer → utiliser PostgreSQL (TimescaleDB Docker local ou Clever Cloud joignable). Doc à jour côté roxygen (`db_connect`). Note de release : le numéro v0.48.1 prévu initialement étant déjà pris (main avait avancé à v0.49.1), ce fix sort en v0.49.2.

- **2026-05-25** — **Portage ADR-013 vers `nemetonplateform/docs/`** (commit `nemetonplateform@18df8cf`, sur main, release GitHub non requise — repo doc). L'ADR-013 « Méthode officielle de suivi sanitaire : FORDEAD avec garde-fous applicatifs » vivait dans `specs/008-suivi-sanitaire/ADR-013-suivi-sanitaire-fordead.md` depuis le 2026-04-26 avec statut « Proposed (à porter dans platform_nemeton/docs/) ». Le portage actualise (1) le **statut → Accepté**, (2) la liste des **livraisons réelles** (`nemeton` v0.21.0 → v0.23.0 → v0.24.0 → v0.42.0 → v0.43.0, plus `nemetonshiny` v0.31.0+ et v0.42.0), (3) ajoute une mention « source historique » qui pointe vers le chemin original. **Côté `nemeton`** : (a) l'original est supprimé et remplacé par un stub `specs/008-suivi-sanitaire/ADR-013-MOVED.md` qui pointe vers la nouvelle URL canonique (préserve les liens entrants), (b) CLAUDE.md mis à jour — la mention « *(sauf ADR-013 dont le draft vit dans specs/008-suivi-sanitaire/, à porter vers platform_nemeton)* » est retirée puisque le portage est fait. Ce commit doc-only est posé sur la branche dédiée `claude/adr-013-port` (cf. règle 11 CLAUDE.md cœur : pas de merge main sans autorisation explicite). Dette doc ADR-013 close.

- **2026-05-27** — Release **v0.49.1** (added — `control_classes` paramétrable sur `create_validation_sampling_plan()`). **Diagnostic prod** sur villards post-v0.49.0 : 0 placettes témoins générées dans le plan de validation FAST. Inspection du raster `read_fast_alert_mask()` : **0 cellules classe 0** sur villards (toutes les 8471 cellules UGF sont classe 4). Cause métier : avec seuils FAST par défaut (NDVI < 0.40 / NBR < 0.30) sur 122 scènes annuelles dans le Jura, **chaque pixel** a au moins quelques dates sous seuil (neige hivernale, défoliation saisonnière) → count > 0 → toutes les cellules ≥ classe 1. Avec breaks default c(0, 2, 5, 10, Inf), majoritairement classe 4 (>10 jours d'alerte). Aucun « pixel jamais alerté » → 0 candidats classe 0 → warn `No healthy cell` → 0 témoins. **Fix** : `create_validation_sampling_plan(..., control_classes = c(0L))` gagne le nouvel argument `control_classes`. Defaut strict `c(0L)` (back-compat). User peut relaxer à `c(0L, 1L)`, `c(0L, 1L, 2L)`, voire `c(3L)` pour les zones très perturbées. **Warn enrichi** : message inclut la distribution des classes du raster, l'utilisateur sait immédiatement quelles valeurs sont disponibles. Exemple villards : `Class distribution: 4 = 8471. Try relaxing control_classes (e.g. c(0L, 1L)) or adjust thresholds/window. Skipping control plots (5 requested).` **Bonus** : la colonne `alert_class` des témoins reflète désormais la **valeur réelle** de la cellule sous le point (était hard-codée à `0L`). Avec `control_classes = c(0L)` strict, c'est toujours 0 ; avec valeurs relâchées, la colonne reporte la classe réelle. Tests : **4 nouveaux** dans `test-validation-sampling.R` (warn quand pas de match, relaxed classes match, alert_class = valeur réelle, back-compat default). Suite : 22 PASS (était 18, +4). **Pour villards** : l'app doit passer `control_classes = c(3L)` (ou autre selon distribution) pour avoir des témoins. À wirer côté `mod_validation_sampling` (sélecteur de classes ou auto-relax). Pas de changement d'API breaking — défaut inchangé.

- **2026-05-27** — Release **v0.49.0** (changed — **mask UGF par défaut sur le pipeline raster**, spec 016 livrée). Tous les readers raster du pipeline FAST + FORDEAD masquent désormais leurs outputs au polygone UGF stocké dans `monitoring_zone.zone_wkt` ; les pixels hors UGF deviennent `NA`. Sur villards : rectangle bbox = 264 ha, UGFs réelles = 77 ha → **~70 % des pixels deviennent NA** dans les outputs raster. Le calcul des compteurs et l'affichage de la carte gagnent en pertinence : plus de pollution par les pixels village / route / prairie / agricoles hors gestion forestière. **Architecture** : le cache COG sur disque reste **un rectangle pixel-aligné** à la bbox UGF (compatible v0.48.1-3 snap-to-grid / tile-aware / memo, aucun changement de contrat cache). Le mask est appliqué **après** lecture cache, **avant** retour au caller, via le nouveau helper interne `.apply_zone_mask(raster, zone_polygon)` (R/zone_aoi.R) qui wrap `terra::mask()` avec reproj CRS automatique et `tryCatch` défensif (échec → unmask + cli_warn). **Fonctions impactées** (6 exports + 1 helper) : `read_fast_alert_raster()`, `compute_fast_alert_mask()`, `read_fast_alert_mask()`, `read_fordead_dieback_mask()` gagnent `apply_zone_mask = TRUE` (défaut) + `mask_polygon = NULL` (NULL = dérivé via `.get_zone_aoi(con, zone_id)`) ; `build_index_stack()` gagne juste `mask_polygon = NULL` (helper bas niveau sans `con`/`zone_id`, caller propage) ; `extract_pixel_timeseries()` gagne `zone_polygon = NULL` + `warn_outside_zone = TRUE` (pas de mask raster, c'est une requête 1-pixel — seulement warn quand le clic est hors UGF). `read_obs_pixel()` est **inchangé** (le filtre `plot.zone_id = $zone_id` EST le filtre UGF de facto puisque les plots sont inscrits par `register_monitoring_zone()` dans le polygone UGF — documenté en `@section` roxygen). **Décisions actées via AskUserQuestion** : (1) cible = calcul + affichage (un seul changement couvre les deux), (2) périmètre = tout le pipeline raster + read_obs_pixel doc only, (3) opt-out (TRUE par défaut, dérive auto depuis la zone). `compute_fast_alert_mask()` persiste désormais un TIF déjà masqué (DEFLATE compresse bien les NA → fichier plus compact pour villards). `read_fast_alert_mask()` applique un re-mask au read pour back-compat avec les TIFs pré-v0.49.0 (re-mask sur NA = no-op). **Pour récupérer le comportement pré-v0.49.0** : passer `apply_zone_mask = FALSE`. **Tests** : 14 nouvelles assertions dans `test-zone-mask.R` (no-op NULL polygon, no-op non-SpatRaster, NA hors polygone sur fixture 4×4, reprojection auto CRS, smoke villards `TRUE` produit plus de NA que `FALSE` même extent). Suite globale : **379 PASS** sans régression (test-zone-mask 14 + fast-alert-raster 20 + fast-alert-mask 18 + pixel-map 62 + aoi-alignment 15 + monitoring 237 + alert-mask 13). **Effort** : ~1 session (50 lignes helper + wiring 6 fonctions + 14 tests). Spec : `specs/016-ugf-mask-pipeline/spec.md`. **Côté `nemetonshiny`** : aucun changement requis. Bump `Imports: nemeton (>= 0.49.0)` recommandé à la prochaine release app.

- **2026-05-27** — Release **v0.48.3** (fix — Cache S2 **memoization du tile_ext_native** par code MGRS). Le test villards d'après reload v0.48.2 montre que le tile-aware second chance fonctionne (`CACHE-HIT served from disk (needed clipped to tile native extent)` partout) mais chaque bande T31TFM paye ~10-25 s de GET range. Sur 61 scènes × 3 bandes × ~20 s = **~1 h** rien que pour relire les headers, même 100 % des données sont en cache. **Observation clé** : un même code MGRS (`T31TFM`, `T31TGM`) a TOUJOURS le même extent natif (100 km × 100 km par la spec MGRS, indépendant de la date/bande/résolution). Aucune raison de relire le header à chaque appel. **Fix** : `.s2_tile_ext_memoize(tile_code, href)` cache l'extent natif par code MGRS dans un `environment` session-scoped (`.s2_tile_ext_cache`). Première scène d'une tuile = 1 GET range (~10-25 s), scènes suivantes = lookup mémo instantané. Clé extraite via `.s2_mgrs_tile(scene_id)` (helper livré spec 013). Test helper `.s2_tile_ext_cache_clear()` pour les tests d'intégration qui veulent vider le memo. **Impact attendu villards** : ~1 h → **~50 s** total tile-header cost (25 s × 2 tuiles uniques T31TFM + T31TGM). Tests : **8 nouvelles assertions** dans `test-monitoring.R` (mock `.pc_ensure_fresh_href`, premier appel populate memo + count = 1, deuxième même tuile count = 1 inchangé, tuile différente count = 2, clear() vide, tile_code "" ou NA → NULL). Suite `test-monitoring.R` 237 ✔ (était 229 en v0.48.2, +8). Le memo est volontairement scope-session — il sera reconstruit au prochain `run_app()` (~25 s × 2), acceptable. Aucun changement d'API publique. **Côté `nemetonshiny`** : aucun changement requis.

- **2026-05-27** — Release **v0.48.2** (fix — Cache S2 predicate **tile-aware second chance** sur AOIs multi-tuile MGRS). Le diagnostic enrichi v0.48.1 a parlé sur le test villards d'après reload : ce n'était PAS de la jitter sub-pixel, c'était un **vrai débord géographique** de 890 m sur xmax (`delta_m=(10,-890,10,10)`). L'AOI villards (~1340 m × 2010 m) chevauche T31TFM + T31TGM, et le cache T31TFM B04 (440 m × 2010 m) a été écrit par un run précédent avec un crop **naturellement clippé** à la frontière FM/GM (xmax = 709800). Aujourd'hui le code demande l'AOI complète (xmax = 710700), 890 m de débord sur l'EST — mais cette portion **n'existe pas dans T31TFM**, c'est sur T31TGM. Refetch « pour rien » retourne exactement les pixels déjà cached. **Fix** : quand le predicate snap-to-grid v0.48.1 dit STALE, une **seconde chance tile-aware** lit les headers natifs du COG (`terra::rast(href)`, lazy, GET range seulement, ~1 s, pas de pixel decode), clippe `needed_ext` à l'extent natif de la tuile, retest la containment. Si OK → CACHE-HIT avec log dédié `"CACHE-HIT served from disk (needed clipped to tile native extent)"`. Si toujours pas OK → refetch normal. Coût : ~1 s de header GET par cas ambigu, n'est invoqué QUE quand le simple predicate a échoué (donc quasi-nul pour les cache-hit nets). Tests : aucune nouvelle assertion (branche tile-aware non testable hors-ligne car requiert un COG distant). Suite `test-monitoring.R` 229 ✔ (identique à v0.48.1, aucune régression). **Impact attendu villards** : sur les ~50 % de scènes T31TFM multi-tuile, le second-chance va matcher → ~30 s d'ingest warm vs les ~3 h résiduels après v0.48.1. C'est aussi le bon résultat semantically : cached est la part T31TFM de l'AOI, refetch ne ramène RIEN de plus (la part T31TGM est dans l'autre dossier scene_id). Le « doublon T31TGM/T31TFM » hors scope évoqué dans le prompt utilisateur reste pertinent en V2 (re-architecture multi-tuile, mais nécessite spec dédiée).

- **2026-05-27** — Release **v0.48.1** (fix — Cache S2 validation passe en snap-to-grid, élimine le re-fetch storm villards). **Symptôme remonté en prod** (villards, 2026-05-27 17:18 → 17:36) : 122 scènes S2 systématiquement déclarées CACHE-STALE malgré la tolérance 40 m v0.47.4. Les re-fetches produisent des fichiers **±12 bytes** différents du cache (bruit en-tête GeoTIFF, payload pixel identique). Projection ingest ~6 h au lieu de ~30 s pour un cache chaud. **Cause racine** : le prédicat `.ext_contains(outer, inner, tolerance = 40)` v0.47.4 comparait les extents en **flottants bruts** avec une tolérance absolue. La jitter sub-pixel introduite par `sf::st_transform(zone_polygon, raster_crs)` décalait les bornes de moins d'1 m mais le predicate flaggait quand même. **Fix** : nouveau prédicat **pixel-grid-aware** `.ext_contains_at_grid(cached, needed, res, tol_pixels = 1L)`. Les deux extents sont d'abord snappés sur la grille pixel du COG (multiples de `res`) via `.snap_ext_to_grid()`. Deux extents qui réfèrent la **même cellule** sont snappés à des valeurs **identiques** → jitter ≤ 1 pixel ne produit jamais STALE. La tolérance 1 pixel restante absorbe l'arrondi `snap = "out"` du `terra::crop`. **Nouvel ENV bypass** `NEMETON_S2_CACHE_SKIP_VALIDATION="TRUE"|"1"` — escape hatch d'urgence quand l'utilisateur sait que le cache est bon mais le predicate fait n'importe quoi. **Diagnostic enrichi** : le log STALE montre désormais les extents snappés ET la marge signée par côté en mètres (`delta_m`), facilite le triage des cas limites. Helpers internes nouveaux : `.snap_ext_to_grid(ext, res)`, `.ext_contains_at_grid(outer, inner, res, tol_pixels)`, `.cache_skip_validation()` (env-var check). Le helper `.ext_contains(outer, inner, tolerance)` v0.47.3 reste exporté tel quel (utilisé par d'autres callers comme la validation FORDEAD) — seul le site cache S2 lookup est upgraded. Tests : **13 nouvelles assertions** dans `test-monitoring.R` (snap_ext_to_grid sur grilles 10 m + 20 m, extents identiques → ok, jitter sub-pixel absorbé, dépassement 2 pixels → STALE, ENV bypass actif sur TRUE / 1, inactif sur yes / vide). Suite `test-monitoring.R` 229 ✔ (était 216 en v0.47.5, +13). **Impact attendu** sur villards : ingest cache-warm ~6 h → ~30 s. **Côté `nemetonshiny`** : aucun changement requis pour bénéficier du fix — la sémantique du predicate est interne. Pinning `Imports: nemeton (>= 0.48.1)` recommandé. Référence : prompt utilisateur 2026-05-27, log d'ingest villards 17:18-17:36.

- **2026-05-26** — Release **v0.48.0** (feat — `lasR` fallback MNT/MNH depuis les `.laz` IGN). Symptôme remonté en prod (run Lajoux 39274) : les 4/4 dalles IGN LiDAR HD **NUAGE** se téléchargent, mais les 4/4 dalles **MNH** et **MNT** échouent (`failed`), et Open-Canopy CHM échoue aussi (env Python `open_canopy` introuvable). Résultat : `! No CHM found anywhere → CHM non trouvé → stratification sans hauteur → create_sampling_plan returned NULL`. Diagnostic probable côté IGN : production retardée des dérivés MNT/MNH (le WFS catalogue la dalle mais le fichier physique 404), pattern fréquent sur les blocs LiDAR récents (Jura 2023-2024). Livraison : (a) nouvelle fonction exportée `compute_dtm_chm_from_laz(laz_dir, dtm_dir, chm_dir, res, aoi, ncores, overwrite, verbose)` qui dérive DTM et CHM via pipeline `lasR` minimal (`reader_las` → `triangulate(keep_class(2))` → `rasterize(res, tri, ofile=dtm.tif)` → `transform_with(tri)` → `rasterize(res, "max", ofile=chm.tif)`), écrit sous `cache/layers/lidar_mnt/dtm.tif` et `cache/layers/lidar_mnh/chm.tif` — chemins compatibles avec le résolveur existant ; (b) `resolve_project_dem()` et `resolve_project_chm()` gagnent `try_compute_from_laz = TRUE` (défaut) qui déclenche le fallback **automatiquement** quand aucun raster pré-calculé n'est trouvé mais que des `.laz` traînent dans `cache/layers/lidar_nuage/` — `lasR` absent ≠ erreur, le fallback est skippé silencieusement, l'opt-out d'un flag couvre les usages qui veulent garder la sémantique stricte ; (c) helper de diagnostic `probe_ign_lidar_tile(url, timeout)` + `probe_ign_lidar_tiles(urls)` (httr2, HEAD avec fallback `GET Range: 0-0`) qui classe les échecs IGN par catégorie (`not_found`, `forbidden`, `timeout`, `dns`, `connection`, `server_error`) — utilisable depuis nemetonshiny pour expliquer à l'utilisateur pourquoi un download a échoué plutôt que `failed`. `lasR (>= 0.10.0)` ajouté en Suggests (install hors CRAN via `r-lidar.r-universe.dev`). Tests : `test-lidar_processing.R` couvre validation d'arguments, absence silencieuse de `lasR`, opt-out, et classification offline du diagnostic. Côté app `nemetonshiny` : aucun changement requis pour bénéficier du fallback auto — le prochain run sur Lajoux devrait produire MNT/MNH localement à partir des 4 dalles NUAGE déjà téléchargées (~quelques minutes par bloc 1×1 km). Diagnostic IGN à câbler optionnellement après l'échec d'un download pour afficher la cause précise.

- **2026-05-26** — Release **v0.47.5** (fix — `build_index_stack()` aligne les extents per-scène, spec 010 + 013). Bug remonté en prod après le run FAST villards de cette nuit (01:14 UTC, 118/118 ingestion terminée) : la Carte FAST et le raster d'alerte FAST émettaient `build_index_stack failed: [rast] extents do not match` (10 lignes consécutives dans le log). Cause racine : `build_index_stack(cache_dir, scenes_df, index)` (livré spec 010 v0.22.0) appelle `read_s2_band_raster()` qui retourne le **fichier cached brut sans recrop**, puis `terra::rast(layers)` pour stacker. Quand les fichiers ont été écrits par des sessions app différentes (cross re-registration de zone, snapping AOI séparé), leurs extents divergent de sub-pixel à plusieurs pixels → `terra::rast` chokes. C'est **distinct** du fix tolérance `.get_s2_band_raster()` (v0.47.3-4) qui ne s'applique qu'au cache-hit path. Fix : `build_index_stack()` calcule désormais l'**intersection des extents** de toutes les couches valides via `terra::intersect` en cascade, puis crop chaque couche sur ce common_ext avant le stack. Si l'intersection est vide (extents totalement disjoints), retourne `NULL` avec un `cli_warn` plutôt que de crasher. Reprojection `snap = "in"` au crop (sub-pixel safe, jamais d'agrandissement). 2 nouveaux tests dans `test-pixel-map.R` : (a) deux scènes décalées de 30 m (= 3 px à 10 m) — pré-fix v0.47.5 levait l'erreur ; post-fix retourne un stack correct à l'extent commun (60×60 m sur fixtures 100×100 m) ; (b) deux scènes totalement disjointes (1 km de décalage) → NULL + warn « no common overlap ». Suite `test-pixel-map.R` 62 ✔ (était 60, +2). **Impact app** : Carte FAST, Alertes FAST et le path FAST de validation-sampling cessent d'échouer sur un cache mixte-vintage. Le user reste à recharger nemetonshiny avec nemeton v0.47.5 pour profiter du fix.

- **2026-05-25** — Release **v0.47.4** (fix — bump tolérance cache de 1 à 4 pixels). v0.47.3 a posé `tol = 1 * max(terra::res(r_cached))` (10 m pour B04/B08, 20 m pour B12). Test prod villards : insuffisant — les fichiers cached écrits par des sessions app antérieures (avant la re-registration de zone post-wipe d'aujourd'hui) diffèrent de plus d'1 pixel de l'AOI courante. Diagnostic (lecture directe du B04.tif T31TFM avec terra) : le fichier qui vient d'être réécrit a **0 m de diff** avec l'AOI demandée — donc la run *en cours* est cohérente, ce sont les fichiers écrits par les runs *passées* qui dérivent. Cause racine probable : `sf::st_union(parcels)` côté app n'est pas byte-stable run-à-run, donc la re-registration de zone après le wipe a produit un polygone légèrement différent (≤ quelques mètres). Bump : `tol = 4 * max(terra::res(r_cached))` = 40 m B04/B08, 80 m B12. Reste très négligeable face à une AOI villards de ~2 km. NA aux bords post-crop (≤ 4 px = ≤ 40 m de marge) silencieusement absorbés par `exactextractr::exact_extract` (contribution de poids 0). Aucun nouveau test (la suite paramétrée `.ext_contains tolerance ...` couvre déjà la sémantique). Aucun changement d'API. Si même 4 px ne suffit pas → solution C.3 (buffer fixe ±500 m au crop **d'écriture**) sera nécessaire en v0.48.0.

- **2026-05-25** — Release **v0.47.3** (fix — tolérance pixel sur `.ext_contains()`, élimine CACHE-STALE storm villards). **Problème observé** : run FAST villards en cours (~19:00 UTC) projeté à **~4 h** pour rafraîchir 118 scènes dont les fichiers cached B04 (~19 939 B) et refetched (~19 979 B) différaient de < 50 bytes — soit < 1 pixel S2. Le helper `.ext_contains(outer, inner)` (`R/monitoring.R:683`) était **strict** : tout dépassement, même sub-pixel, déclenchait CACHE-STALE → re-fetch via PC SAS (~1 min/bande). Cause racine du sub-pixel jitter : `sf::st_transform(buf, raster_crs)` + `terra::crop(snap = "out")` ne reproduisent pas exactement la même cellule de pixel run-to-run quand l'input transformé subit du floating-point. **Fix solution A** : `.ext_contains(outer, inner, tolerance = 0)` gagne un argument `tolerance` (en unités CRS, typiquement mètres pour EPSG:32631). Le site d'appel cache-hit dans `.get_s2_band_raster()` (`R/monitoring.R:881`) passe `tolerance = max(terra::res(r_cached))` — exactement 1 pixel du raster cached (10 m pour B04/B08, 20 m pour B12). Tout autre appelant garde la sémantique stricte pré-v0.47.3 via le défaut `tolerance = 0`. Quand la tolérance laisse passer un cache-hit limite, le `terra::crop(r_cached, needed_ext, snap = "out")` qui suit peut renvoyer un raster avec quelques pixels NA au bord de l'AOI ; en pratique ces pixels sont au-delà des buffers per-plot (15 m intérieur à l'AOI envelope) donc invisibles dans `exact_extract` qui gère silencieusement les cellules manquantes (poids 0). Log verbose mis à jour : `CACHE-STALE extent does not cover AOI (tol=10m), refetching` rend la tolérance visible quand stale fire quand même. Tests : **8 nouvelles assertions** dans `test-monitoring.R` (couvrent strict default, tolérance positive, dépassement au-delà de tolérance, tolérance négative). Suite `test-monitoring.R` 216 ✔ (était 208, +8 nouveau test). **Impact attendu** sur le run villards en cours : ~4 h → **~10-30 min** (la majorité des CACHE-STALE deviennent CACHE-HIT puisque le mismatch est ≤ 1 pixel). Une variante future plus généreuse (« solution C.3 » buffer fixe 1 km au crop) reste possible si la tolérance 1 pixel s'avère insuffisante.

- **2026-05-25** — Release **v0.47.2** (fix — garde-fou `with_clean_db()`, suite de l'incident villards). Le helper d'intégration `tests/testthat/helper-monitoring.R::with_clean_db()` exécute `reset_schema()` (DROP CASCADE sur `alert`, `obs_pixel`, `plot`, `monitoring_zone`, `schema_migration`) au début ET à la fin de chaque test pour garantir l'idempotence. **Trap** : si `NEMETON_DB_URL_TEST` est unset, il fallback sur `NEMETON_DB_URL` ; et si l'utilisateur a la même URL pour test et prod, **chaque test d'intégration wipe les données prod**. Incident concret aujourd'hui : la zone villards (id=1, project_uuid posé, 155 plots, 17 050 obs_pixel, ~24 alertes FORDEAD) a été détruite pendant les runs des tests spec 013/014/chip 2-3 de cette session — toutes les données monitoring perdues entre 13:46 (timestamp original migrations) et 16:26 (timestamp après wipe + re-init). **Fix** : `with_clean_db()` lève désormais un `testthat::skip()` actionnable quand (a) `NEMETON_DB_URL_TEST` est unset ET fallback vers `NEMETON_DB_URL` aurait lieu, OU (b) `NEMETON_DB_URL_TEST == NEMETON_DB_URL`. Override explicite via `NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE` (intended pour CI sur une DB vide). Vérifié : sans override, 7 tests d'intégration de `test-project-zone-binding.R` skippent proprement (8 unit tests offline restent OK) ; avec override, les 18 tests s'exécutent normalement. Aucun changement de code production. **Mémoire posée** dans `feedback_test_db_isolation.md` pour ne plus jamais reproduire l'erreur lors des sessions futures. Côté `nemetonshiny` : audit en parallèle a révélé un **bug séparé sur ntfy** — les notifications FAST ont en-tête HTTP `Title = "Nemeton FORDEAD"` (hard-codé dans `service_monitoring.R:470` du `.ntfy_send()`), trompant l'utilisateur ; les bodies des messages sont corrects côté i18n, seul le header est faux pour les 4 call sites FAST (start/scenes/error/complete) ; à traiter en chantier app séparé.

- **2026-05-25** — Release **v0.47.1** (fix — stabilisation suite de tests chip 2-3, clôture de la dette ouverte en v0.43.2). 3 fixes, aucun changement de comportement utilisateur. (1) `.fordead_is_installed()` (`R/fordead_python.R:289`) remplace `cli::cli_alert_warning` par `cli::cli_warn` — `_alert_*` n'imprime que du texte stylé console, `cli_warn` raise en plus une vraie condition R `warning` que `expect_warning()` peut catcher (et qu'un appelant peut intercepter via `withCallingHandlers`). (2) `.ensure_fordead_python()` (`R/fordead_python.R:421,434,444`) pareil : `cli_alert_info` → `cli_inform` (raise une condition `message` catchable par `expect_message()`) ; au passage le message de la branche « venv existe mais fordead missing/wrong » mentionne désormais explicitement « fordead is missing or out-of-date » pour matcher l'intention du test. (3) `test-fordead-python.R:32` — le test « reticulate missing » capture `real_require <- base::requireNamespace` **avant** d'appeler `local_mocked_bindings(.package = "base")` ; le else-branch du mock appelle `real_require()` (référence directe à la fonction d'origine) au lieu de `base::requireNamespace()` qui recurse à l'infini dans testthat récent — la résolution `base::requireNamespace` au moment du call passe par le binding du namespace qui a été remplacé par le mock. Sortie utilisateur identique sur les 4 sites cli touchés. Tests : `test-fordead-python.R` **57 ✔ / 0 FAIL** (était 3 fails). `test-fordead-stac.R` déjà 100 % vert (75 ✔, fixé par un chip antérieur). Aucune régression sur les pipelines FORDEAD voisins : `test-fordead-pipeline.R` 69, `test-fordead-postprocess.R` 56, `test-fordead-outputs.R` 41, `test-fordead-pixel-series.R` 31, `test-fordead-validity-zones.R` 10 = 207 ✔. **Dette ouverte v0.43.2 close.** L'option `cli_warn`/`cli_inform` vs `cli_alert_warning`/`cli_alert_info` est un piège récurrent — guideline pour la suite : utiliser `cli_warn`/`cli_inform` quand la sortie doit pouvoir être catchée par un test ou un caller, garder `cli_alert_*` uniquement pour de la décoration console qui ne porte pas de signal d'erreur ou d'avertissement.

- **2026-05-25** — Release **v0.47.0** (feat — validation sampling plan, spec 014 phase A). Ferme la boucle des alertes FAST/FORDEAD : le `dieback_mask` montre du dépérissement mais la projection sur les placettes systémiques peut le manquer si aucune placette ne tombe à proximité. Quatre nouvelles fonctions exportées qui permettent à `nemetonshiny` de générer un **plan d'échantillonnage de validation** terrain ciblé sur les foyers détectés. (1) `fordead_alert_mask(alert_raster, classes = c(3L, 4L), buffer_m = 0)` — utilitaire raster pur qui sélectionne les cellules d'alerte sur un 0-4 catégoriel (FORDEAD ou FAST) en préservant leur valeur de classe (= priority raster), NA ailleurs ; tampon métrique optionnel. (2) `compute_fast_alert_mask(con, zone_id, ..., cache_dir, mask_cache_dir, breaks = NULL)` — discrétise le `read_fast_alert_raster()` continu de v0.46.0 vers l'**échelle 0-4 alignée FORDEAD** et persiste sous `<mask_cache_dir>/zone_<id>/fast_alert_<ts>.tif` (GeoTIFF DEFLATE INT1U). Bins par défaut : mode `"count"` `c(0, 2, 5, 10, Inf)`, mode `"rolling"` `c(0, 0.05, 0.10, 0.20, Inf)`. (3) `read_fast_alert_mask(con, zone_id, run_id = NULL, cache_dir)` — **strict miroir de `read_fordead_dieback_mask()`** (lit le 0-4 persisté, NULL si absent). (4) `create_validation_sampling_plan(zone, alert_raster, n_validation, n_control, classes, buffer_m, source, seed)` — entrée publique unique qui retourne un `sf` POINT EPSG:2154 combinant placettes de **validation** (GRTS pondéré sur le masque d'alerte via `spsurvey::grts(caty_var, caty_n)` — cellule classe 4 reçoit + de placettes que classe 3, allocation par largest-remainder rounding) + placettes **témoins** (GRTS équiprobable sur classe 0 saine), avec colonne `visit_order` issue d'un TSP unique sur l'union. **Décisions** : (a) pas de breaking change avec v0.46.0 — `read_fast_alert_raster()` reste le live continu pour l'UI, `read_fast_alert_mask()` est le miroir persisté pour la validation. (b) GRTS pondéré implémenté en helper interne `.draw_grts_weighted()` (pas sur `create_sampling_plan()` public) — choix d'implémentation autorisé par le brief, plus simple, pas de risque de régression sur les 200+ lignes de stratification CHM/MNT existantes. (c) Cas masque vide → erreur typée `nemeton_empty_alert_mask` pour message app propre (« zone saine, rien à valider »). (d) Témoins générés ici, pas côté app (décision 5 du brief). **Trap technique** : `spsurvey::grts(caty_n = ...)` veut un **vecteur nommé**, pas une liste — `as.list()` provoque une erreur vide silencieuse via `capture.output`. Tests : **49 ✔ sur 23 blocs** (`test-alert-mask.R` 13, `test-fast-alert-mask.R` 18, `test-validation-sampling.R` 18) — input validation offline, raster arithmetic sur fixtures synthétiques 4×4/10×10/20×20, GRTS pondéré (assertion statistique : classe 4 reçoit ≥ que classe 3 à seed fixe), reproductibilité seed, round-trip end-to-end `compute_fast_alert_mask()` → `read_fast_alert_mask()` sur la vraie DB villards. Spec : `specs/014-validation-sampling/spec.md`. **Side-quest** : les 8 workers `future::multisession` orphelins du `run_app(language = "fr")` ouvert depuis hier matin bloquaient l'accès DB des tests (pool de connexions saturé, ~1 Go/worker en RAM) — diagnostic + arrêt propre par l'utilisateur a débloqué la session. **Côté app `nemetonshiny`** : phase B à venir — module UI + bouton « Générer plan de validation » + persistance dans `samples.gpkg`.
- **2026-05-25** — **Spec 013 « FAST alert raster » — clôture cross-repo**. Côté cœur : `nemeton@9f519a4` / **v0.46.0** (release GitHub publiée 2026-05-24, cf. entrée du jour ci-dessous). Côté app : `nemetonshiny@72a4d10` / **v0.42.0** (cycle dev 0.41.1 → 0.42.0, release GitHub publiée). Les 3 livrables app sont posés : (1) **fix réactif** — `fast_reload` reactiveVal bumpé par le success handler du `fast_task`, threadé en `refresh_r` dans `mod_monitoring_fast_alerts_server` et `mod_monitoring_pixel_map_server` ; résout le bug villards 2026-05-23 où Alertes/Carte FAST restaient gelés après ingestion. (2) **Alertes FAST passe au raster** — bascule de `addCircleMarkers` (markers per-placette via `list_fast_alerts_for_zone`) à `addRasterImage(read_fast_alert_raster(...))` pixel-par-pixel ; radio toggle count/rolling ; palettes discrète (count) vs continue p95-capée (rolling) ; suppression du chemin `list_fast_alerts_for_zone` côté app. (3) **Lignes de seuil sur Carte FAST** — le modal pixel (`extract_pixel_timeseries`) affiche désormais 2 lignes horizontales pointillées dashed (orange NDVI, rouge NBR) aux seuils sidebar ; `thresholds_r` ajouté à `mod_monitoring_pixel_map_server`. Plancher app `Imports: nemeton (>= 0.46.0)`. 5 nouvelles clés i18n (`mode_label`/`count`/`rolling`, `legend_count_title`, `pixel_plot_threshold_fmt`). Suite app full green : 6383 ✔ / 0 FAIL. **Effet utilisateur** : ouvrir l'onglet *Suivi sanitaire* → *Alertes FAST* affiche un raster d'alerte avec choix du mode, et cliquer un pixel de Carte FAST ouvre un plot temporel NDVI/NBR avec les seuils tracés en pointillés. Spec : `specs/013-fast-alert-raster/spec.md`.

- **2026-05-24** — Release **v0.46.0** (feat — raster d'alerte FAST pixel-par-pixel, spec 013). Bascule la sémantique FAST de « par placette » (legacy `list_fast_alerts_for_zone()` qui produisait 30 plots avec moyenne 30j sur villards) à « **par pixel** » à la résolution S2 native (10 m). Nouvelle fonction exportée `read_fast_alert_raster(con, zone_id, threshold_ndvi, threshold_nbr, date_from, date_to, mode = c("count", "rolling"), window_days = 30L, cache_dir)` → renvoie un `SpatRaster` mono-couche **EPSG:2154**. Deux modes en parallèle (décision utilisateur 2026-05-24) : (1) `"count"` — compte entier par pixel des dates où `NDVI<seuil OR NBR<seuil`, layer `alert_count` ; (2) `"rolling"` — magnitude **continue** du déficit `max(deficit_ndvi, deficit_nbr)` où `deficit_x = max(0, threshold_x - mean_x_30j)` sur la fenêtre trailing, layer `alert_deficit` (0 = pas en alerte, > 0 = amplitude). **Multi-tuile MGRS géré transparent** : scènes groupées par tuile (5ᵉ champ `_` du scene_id via helper interne `.s2_mgrs_tile()`), un raster par tuile dans son CRS natif (typiquement 32631), chaque raster projeté en 2154, mosaic final avec `fun = "max"`. Validé end-to-end sur villards (zone 1, 155 plots, 55 dates straddling T31TFM + T31TGM) : retourne un raster mono-couche EPSG:2154 avec valeurs ∈ [0, 55]. Réutilise `build_index_stack()` (spec 010 v0.22.0) et `.get_zone_aoi()` (spec 012 v0.45.0) — synergie complète des chantiers récents. Helpers internes : `.compute_alert_count()` (cell-wise via `sum(in_any, na.rm = TRUE)`), `.compute_alert_rolling()` (cell-wise mean via `terra::app(x, fun = mean, na.rm = TRUE)` car `mean(spatraster)` collapse en scalaire ; deficit via `terra::clamp(x, lower = 0, values = TRUE)` plus robuste que `[< 0] <- 0` qui peut collapser le raster en numeric). Dégradation propre : `NULL` si pas de scène dans la fenêtre, si pas de bandes utilisables, ou si tuile sans WKT. Reprojection `near` pour count (entier), `bilinear` pour deficit (continu). Tests : `test-fast-alert-raster.R` **20 ✔ sur 12 blocs** (6 unitaires input-validation offline, 2 `.compute_alert_count` sur stacks synthétiques 4×4×3 dates avec assertion contre calcul manuel, 3 `.compute_alert_rolling` sur stacks synthétiques, 1 smoke end-to-end villards qui valide schéma + CRS + nom de layer + bornes). Hors scope V1 (reporté potentiel spec 014+) : slider date sur Carte FAST, rolling « toutes les fenêtres » (stack 4D historique), persistance disque du raster, sortie GeoTIFF. **Côté app `nemetonshiny`** : chantier séparé à venir — wirer `addRasterImage(read_fast_alert_raster(...))` dans `mod_monitoring_fast_alerts` avec toggle radio mode count/rolling, ajouter ligne horizontale au seuil sur le plot pixel-click de Carte FAST, et corriger le bug de réactif app observé 2026-05-23 (`s2:complete` n'invalide pas les sources dérivées). Synergie spec validation-sampling : `read_fast_alert_raster()` est l'entrée du `priority_raster` pour le GRTS pondéré (phase A à venir). Spec : `specs/013-fast-alert-raster/spec.md`.

- **2026-05-23** — Release **v0.45.0** (changed — alignement AOI FAST ↔ FORDEAD, spec 012). Démarrage et clôture côté cœur le même jour. **Problème observé en production sur villards** (cycle utilisateur 12:18-12:20 UTC) : un run FAST sur 6 placettes met **1 min 43 s par bande** pour re-fetch un B04 de 18 KB déjà présent sur disque (CACHE-STALE « extent does not cover AOI »), projection ≈9 h pour 116 scènes × 3 bandes. **Cause** : FAST (`monitoring.R:288`) calculait `sf::st_bbox(plots)` (enveloppe étroite autour des points placettes), tandis que FORDEAD (`fordead_pipeline.R:483` → `.get_zone_aoi()`) lisait `monitoring_zone.zone_wkt` (l'enveloppe des UGF enregistrée par l'app). Les deux pipelines demandaient donc au COG des crops différents → caches étanches l'un à l'autre → ré-écriture systématique des bandes à chaque switch FAST↔FORDEAD. **Fix** : (1) `.get_zone_aoi()` déplacée de `R/fordead_pipeline.R` à un fichier neutre `R/zone_aoi.R` (helper interne partagé, signature inchangée). (2) `ingest_sentinel2_timeseries()` (FAST) et `ingest_s2_raw_bands_to_cache()` (utilisé par FORDEAD en phase 0) lisent désormais `zone_wkt` via `.get_zone_aoi()` pour la bbox STAC (reprojetée WGS84) ET pour le crop COG passé à `.get_s2_band_raster()`. (3) `.extract_scene_obs()` gagne un argument optionnel `crop_aoi` (NULL = fallback à l'ancien `buf`). Le buffer per-plot `buf` est toujours utilisé en aval pour `exactextractr::exact_extract()` (moyenne per-plot). (4) Fallback défensif : si `monitoring_zone.zone_wkt` est vide/illisible (zone créée par un script qui contourne `register_monitoring_zone()`), warn explicite + retour au comportement v0.44.x (per-plot bbox). (5) `.get_s2_band_raster()` garde le nom de paramètre `buf_plots` pour préserver la compat avec les mocks `local_mocked_bindings`, mais sémantiquement accepte n'importe quel sf dont la bbox définit le crop. **Note opérationnelle** : les caches peuplés par v0.44.x ou antérieur portent des crops à la bbox-plots ; ils déclencheront une vague unique de CACHE-STALE re-fetch à la première run spec 012 contre eux — attendu et ponctuel. Nettoyage optionnel : `unlink("<project>/cache/layers/sentinel2", recursive = TRUE)`. Spec : `specs/012-aoi-alignment-fast-fordead/spec.md`. Tests : `test-aoi-alignment.R` 15 ✔ sur 6 blocs ; régression `test-monitoring.R` (208 ✔) et `test-sentinel2-cache.R` (27 ✔, fix de la signature `fake_obs` ligne 1112 + ajout du mock `.get_zone_aoi` dans les 7 `local_mocked_bindings` existants pour éviter le warn de fallback). Aucune modification d'API — `nemetonshiny` n'a rien à toucher. **Synergie spec 011** : `find_zone_by_project()` permet de retrouver la zone d'un projet ; spec 012 garantit que cette zone aura un cache cohérent FAST/FORDEAD.

- **2026-05-23** — **Spec 011 « project_uuid binding for monitoring_zone » — clôture cross-repo**. Côté cœur : `nemeton@78e5ec8` / **v0.44.0** (release GitHub publiée, cf. entrée du jour ci-dessous). Côté app : `nemetonshiny@8d44b0b` / **v0.41.0** (cycle dev 0.40.0 → 0.41.0, release GitHub publiée). L'app pose désormais le `project_uuid` à l'enregistrement de la zone (HOOK 1 — `register_project_as_zone()` passe `project_uuid = project$id`), migre automatiquement les zones pré-spec-011 via un backfill `UPDATE` idempotent (HOOK 1bis), et re-hydrate `metadata$monitoring_zone_id` au chargement projet via le nouveau helper `hydrate_monitoring_zone_id()` appelé dans `mod_home.R` post-`load_project()` (HOOK 2 — appelle `nemeton::find_zone_by_project(project$id)` et persiste sur disque). DESCRIPTION app passe à `Imports: nemeton (>= 0.44.0)`. Tests : 5 nouveaux offline dans `test-hydrate-monitoring-zone-id.R` + 2 cas dans `test-service_monitoring_db.R` (backfill + no-op) ; suite app 6354 ✔ / 0 FAIL. **Effet utilisateur** : ré-ouvrir un projet récent (villards et autres) re-sélectionne automatiquement la zone de suivi dans l'onglet *Suivi sanitaire* sans clic supplémentaire, tant pour les projets postérieurs à spec 011 (binding posé à l'enregistrement) que pour les projets legacy (binding rétro-comblé au premier chargement). Spec : `specs/011-project-zone-binding/spec.md`.

- **2026-05-23** — Release **v0.44.0** (feat — `project_uuid` binding pour `monitoring_zone`, spec 011). Lien stable projet ↔ zone côté DB, pour que l'app puisse re-hydrater le `monitoring_zone_id` au rechargement d'un projet récent quand son `metadata.json` n'en porte pas (cas de villards reproduit ce matin : zone id 1 en DB, 155 placettes, masque FORDEAD persisté sous `cache/layers/fordead/zone_1/`, mais l'onglet « Suivi sanitaire » de `nemetonshiny` reste vide parce que `mod_monitoring.R:940` lit *uniquement* `app_state$current_project$metadata$monitoring_zone_id` — champ posé une seule fois par le bouton « Enregistrer le projet comme zone » et jamais relu en DB). Livrables cœur : (1) migration **0003_project_uuid** (PG + DuckDB) — `monitoring_zone.project_uuid TEXT` + index partiel UNIQUE sur les valeurs non-NULL ; idempotente ; les zones legacy (sans `project_uuid`) restent valides. (2) `register_monitoring_zone()` gagne un argument optionnel `project_uuid = NULL`, persisté quand non-NULL ; rétrocompat totale (les appelants qui ne le passent pas empruntent le même chemin qu'en v0.43.2). (3) Nouvelle fonction exportée `find_zone_by_project(con, project_uuid)` — retourne l'id de la zone liée ou `integer(0)` ; ne fait **pas** de fallback `name` (intentionnel : on documente la fin de cette convention fragile). Spec 011 §3 livrée intégralement côté cœur. Reste côté app `nemetonshiny` (chantier séparé) : hook dans `mod_home.R` post-`load_project()` qui appelle `find_zone_by_project(project$id)` et hydrate `metadata$monitoring_zone_id` si manquant ; bouton « Enregistrer le projet comme zone » qui passe `project_uuid = project$id`. Tests : `test-project-zone-binding.R` 9 ✔ (4 unitaires offline pour la validation des entrées, 5 intégration TimescaleDB via `with_clean_db` : migration apply, round-trip, lookup happy path, `integer(0)` quand inconnu, refus du fallback `name`, UNIQUE rejette le double binding, multiples NULL coexistent). Spec : `specs/011-project-zone-binding/spec.md`.

- **2026-05-23** — Release **v0.43.2** (fix — première tranche de la stabilisation suite de tests). 4 fixes défensifs, aucun changement de comportement de prod. (1) `.same_path()` (`R/fordead_python.R`) collapse `/./`, slashes dupliqués et slash final à la main avant comparaison — `normalizePath(mustWork = FALSE)` laisse les chemins inexistants tels quels, l'identité produisait donc des faux négatifs dès qu'une entrée portait un segment redondant. (2) `.validate_date_range()` (`R/fordead_stac.R`) enveloppe `as.Date()` dans un `tryCatch` : R récent *erreure* sur une chaîne non parsable au lieu de renvoyer `NA` avec un warning, ce qui masquait le message actionnable "must parse as a date (ISO yyyy-mm-dd)". (3) `diagnose_s2_cache()` (`R/monitoring.R`) cleanup orphan : `unlink(recursive = TRUE)` car `unlink(recursive = FALSE)` ne supprime jamais un dossier, même vide — la branche de cleanup était un no-op silencieux ; la garde « dossier vide » juste au-dessus rend l'appel sûr. (4) `test-monitoring.R` : la séquence attendue inclut désormais `s2:cache_lookup` et les événements sont retrouvés par clé `current` plutôt que par position, pour survivre aux insertions futures de phases. Reste ~9 échecs sur `test-fordead-python.R` / `test-fordead-stac.R` (conflit binding Python reticulate, validateurs) à traiter en tranches suivantes.

- **2026-05-22** — Release **v0.43.1** (fix — nettoyage de la dette `R CMD check`). Release de maintenance, aucun changement fonctionnel. Le `devtools::check()` accumulait 1 ERROR, 5 WARNINGS, 5 NOTES. **WARNINGS/NOTES traités** : (1) deux `.Rd` corrompus (`ingest_s2_raw_bands_to_cache`, `ingest_sentinel2_timeseries`) — artefacts périmés édités à la main, accolades déséquilibrées par un `%` non échappé — régénérés proprement depuis roxygen, `@param max_cloud` reformulé « percent » ; (2) caractères non-ASCII dans des littéraux de chaîne de 5 fichiers (`fordead_outputs.R`, `fordead_validity.R`, `health_validation.R`, `qgis_export.R`, `sampling_plan.R`) remplacés par des échappements `\uxxxx` (comportement runtime identique) ; (3) arguments non documentés — `@param` ajoutés pour `indicateur_e1_bois_energie`/`p1_volume`/`p3_qualite_bois` et la famille `stac_search_s2_*` ; (4) `charru_bai_drift` `\details` vide + `diagnose_s2_cache` accolades — corrigés ; (5) `setNames` qualifié `stats::setNames` ; (6) `.Rbuildignore` étendu (`.env`, `CHANGELOG.md`, `CITATION.cff`, `docker-compose.yml`, `PLAN.md`) ; (7) `xml2` déclaré en `Suggests`. **ERROR partiellement traité** : `test-sentinel2.R` « All STAC backends failed » réécrit pour testthat edition 3 (l'idiome `expect_warning()` imbriqué ne fonctionne plus en 3e). Reste **~13 échecs de tests** (`test-monitoring.R` 7, `test-fordead-stac.R` 2, `test-fordead-python.R` 4) — schéma d'événement progress, validateurs, conflit de binding Python reticulate en process unique — documentés comme chantier dédié « stabilisation de la suite de tests ».

- **2026-05-21** — Release **v0.43.0** (feat — `read_fordead_pixel_series()`, diagnostic pixel CRSWIR, spec 008 §14 L2). Clôture côté cœur du chantier « Diagnostic pixel CRSWIR » (ADR-013 amendement A3). L2 est le côté lecture du bundle persisté par L1 : la nouvelle fonction exportée `read_fordead_pixel_series(con, zone_id, xy, crs = 4326, run_id = NULL, cache_dir)` retourne, pour un pixel cliqué, le `data.frame` trié par `obs_date` avec `crswir_obs` (CRSWIR observé masqué), `crswir_pred` (prédiction du modèle harmonique), `seuil_haut` (`crswir_pred + threshold_anomaly`) et `anomalie` (`crswir_obs > seuil_haut`) ; attributs `threshold_anomaly`, `premiere_detection`, `dans_zone_validite` (garde-fou G3 via `check_fordead_validity()` sur la cellule du pixel), `vegetation_index`. Conventions de chemin et de sélection `run_id` calquées sur `read_fordead_dieback_mask()` (`<cache_dir>/zone_<id>/model_<run_id>/`, plus récent si `run_id = NULL`). **Décision D3 (ADR-013 A3)** : la base harmonique n'est PAS réimplémentée en R — `crswir_pred` est reconstruit via `fordead.modeling.compute_HarmonicTerms` (base 5 termes `[1, sin, cos, sin2, cos2]`, période 365.25) appelée par reticulate, garantissant la parité bit-à-bit avec le run ; seul `dates_to_days` (soustraction depuis `REF_DAY = 2015-01-01`) est fait côté R. Dégradation propre : `read_fordead_pixel_series()` retourne `NULL` sans erreur si aucun bundle, pixel hors emprise/non modélisé, ou venv FORDEAD indisponible (risque résiduel accepté en ADR-013 A3). Nouveau fichier `R/fordead_pixel_series.R` (fonction exportée + helpers internes `.locate_fordead_model_bundle()`, `.crswir_stack_dates()`, `.fordead_harmonic_predict()`). Tests : `test-fordead-pixel-series.R` 32 ✔ sur 13 blocs `test_that` (fixture bundle synthétique, prédiction harmonique mockée pour l'offline — AC.14.6 ; AC.14.2 parité testée contre le venv réel à 1e-6 ; AC.14.3 `NULL` propre hors emprise / sans run ; schéma du `data.frame`, calcul `seuil_haut`/`anomalie`, attributs, sélection `run_id`). Aucune régression sur la suite FORDEAD (les 6 échecs `test-fordead-python.R`/`stac.R` restent préexistants). Reste L3 (modal plotly) côté `nemetonshiny`.

- **2026-05-21** — Release **v0.42.0** (feat — bundle diagnostic FORDEAD persistant, spec 008 §14 L1). Démarrage du chantier « Diagnostic pixel CRSWIR » (ADR-013 amendement A3). L1 rend la Carte FORDEAD diagnosable au clic en persistant les artefacts du modèle harmonique, aujourd'hui perdus avec l'`output_dir` temporaire. La phase `persist` de `run_fordead_dieback()` écrit, en plus du masque 0-4, un bundle curé sous `<mask_cache_dir>/zone_<id>/model_<run_id>/` : `coeff_model.tif` (raster 5 bandes = les coefficients harmoniques, copie de `fit/model.tif`), `crswir_stack.tif` (CRSWIR observé multibande, une bande par date avec `terra::time()`, masqué par `INVALID_PIXEL_MASK` nuage/ombre/sol), `first_anomaly.tif` (date de première anomalie confirmée), `run_meta.json` (calibration + provenance). Deux helpers internes neufs dans `fordead_outputs.R` : `.build_crswir_masked_stack()` et `.write_fordead_model_bundle()`. Layout FORDEAD 2.x confirmé sur le run réel de la zone villards (`fit/model.tif` 5 bandes, `CRSWIR/` 163 dates, `INVALID_PIXEL_MASK/` 163 dates). Résultat de `run_fordead_dieback()` enrichi de `rasters$model_dir` (ou `NA_character_` si l'écriture échoue). Écriture **best-effort** comme le persist-hook du masque (v0.41.0) : un échec `warn` mais n'aborte jamais le run — pas de nouvelle phase, pas de changement de signature. Tests : `test-fordead-outputs.R` 41 ✔ (8 neufs — fixture FORDEAD synthétique, AC.14.1 les 4 artefacts, masquage des pixels invalides, `run_meta.json` round-trip, abort si `fit/model.tif` manquant) ; `test-fordead-pipeline.R` 69 ✔ (`model_dir` câblé dans le résultat + AC.14.5 best-effort : échec de bundle → `warn`, run `status = "success"`). `devtools::check()` sans *nouveau* ERROR/WARNING/NOTE (l'ERROR `test-sentinel2.R:135` et les NOTES `setNames`/Rd/CITATION sont préexistants, hors chantier). L2 (`read_fordead_pixel_series()`) suit en v0.43.0.

- **2026-05-21** — Release **v0.41.3** (fix — FORDEAD rapportait « 0 alertes » alors qu'il détectait 32 ha de dépérissement). L'utilisateur signale un run FORDEAD terminé « 0 alertes insérées en 49605 s » sur la zone villards. Investigation : le masque catégoriel persisté contenait pourtant **3 228 pixels classe 4-sol-nu (≈32 ha)** — le pipeline avait bien détecté du dépérissement. **Trois défauts indépendants** se combinaient pour faire disparaître le résultat sans le moindre avertissement. (1) `.compute_first_dieback_date()` (`fordead_outputs.R`) reshapait la pile `ANOMALY_CONFIRMED` via `array(values, dim = c(n_rows, n_cols, …))` : `terra::values()` est *row-major* alors que `array()` remplit *column-major* → le cube `(time, y, x)` passé à `fordead.utils.backward_start()` était transposé y/x dès que `n_rows ≠ n_cols` (ici 192 ≠ 129), les dates de premier dépérissement atterrissaient sur les mauvais pixels ; corrigé par un reshape couche par couche `byrow = TRUE`. (2) la même fonction supposait que `backward_start()` renvoie un tableau numérique « jours depuis epoch » ; il renvoie en réalité un tableau *object-dtype* (chaînes de dates ISO sur les pixels confirmés, `NaN` ailleurs) que `terra::rast()` ne peut pas ingérer → l'étape plantait, attrapée comme un échec best-effort bénin ; corrigé par une coercition explicite en matrice numérique de jours-depuis-1970. (3) `first_dieback_date` ainsi perdu, tous les centroïdes d'alerte portaient `trigger_date = NA`, et `.insert_fordead_alerts()` (`fordead_postprocess.R`) écartait silencieusement chaque ligne concernée (colonne de la clé UNIQUE) → désormais un `cli_warn` rapporte le nombre d'alertes jetées. En complément, `run_fordead_dieback()` (`fordead_pipeline.R`) traitait l'échec d'import `fordead.utils` comme un best-effort silencieux → il avertit maintenant explicitement que `trigger_date` ne pourra pas être dérivé et que tout cluster sera perdu à l'insertion, en pointant la dépendance Python manquante (`geocube`). **Validation terrain end-to-end** : `geocube` installé dans le venv `nemeton-fordead`, postprocess relancé sur les rasters survivants (sans refaire les 13 h de fit/predict) → **24 alertes `fordead_dieback` classe 4-sol-nu** (déclenchements 2018-06-02 → 2019-08-31, ≈32 ha) **persistées dans le Postgres de production** (zone villards id 1, 155 placettes). Première validation terrain complète du pipeline de suivi sanitaire. Tests : `fordead-pipeline` 65 ✔, `fordead-postprocess` 56 ✔, `fordead-outputs` 20 ✔, `fordead-integration` 2 skip.

- **2026-05-20** — Release **v0.41.2** (fix — les doublons de retraitement Sentinel-2 gonflaient le cache et FORDEAD). Suite à v0.41.1, l'utilisateur demande de vérifier les dates dupliquées signalées par FORDEAD (« Duplicas times found »). Inspection du cache S2 réel (`cache/layers/sentinel2/`, zone Mouthe) : **389 dossiers pour 342 acquisitions** — toutes sur la tuile `T31TGM`, donc PAS le cas bénin « AOI à cheval sur 2 tuiles MGRS ». **47 acquisitions (~14 %) dupliquées** : l'ESA retraite périodiquement l'archive S2 et republie une acquisition sous un nouvel id produit dont seul le timestamp de baseline de traitement (champ final) change. Ex. 2021-10-29 : `S2A_..._20211029T104151_R008_T31TGM_20211030T012431` (baseline d'origine) ET `..._20230128T045356` (retraitée). La recherche STAC renvoyait les deux ; `.build_stac_collection_for_aoi()` dédoublonnait par `scene_id` complet (différents) → les deux passaient → FORDEAD recevait deux items au même `datetime`, fusionnés dans un ordre indéfini (la baseline ancienne pouvait l'emporter sur la retraitée mieux calibrée). **Fix** : nouveaux helpers internes `.s2_split_product_id()` (parse l'identité d'acquisition = mission + sensing time + orbite + tuile MGRS, reconnaît la forme 6-champs Planetary Computer ET la forme 7-champs ESA `.SAFE`) et `.dedup_s2_reprocessed()` (garde la baseline de traitement la plus récente, préserve l'ordre des lignes, ne fusionne jamais deux acquisitions réellement distinctes). Appliqué (1) dans `stac_search_s2()` → tous les consommateurs en profitent (ingestion FORDEAD + FAST NDVI/NBR), avec un `cli_alert_info` quand des doublons sont écartés ; (2) dans `.build_stac_collection_for_aoi()` en filet de sécurité avant de passer la collection à FORDEAD. Nouveau fichier `test-sentinel2-dedup.R` : **16 PASS** (parsing 6/7-champs, cas réel 2021-10-29, préservation d'ordre, non-fusion d'acquisitions distinctes, no-op sur entrée vide, intégration `stac_search_s2` mockée). Aucune régression : `test-sentinel2.R` / `test-fordead-stac.R` / `test-fordead-pipeline.R` inchangés (mêmes échecs préexistants). **Note** : les ~47 dossiers orphelins déjà présents dans le cache de l'utilisateur ne sont pas référencés après le fix (inoffensifs, disque gaspillé) — purge manuelle possible.

- **2026-05-20** — Release **v0.41.1** (fix — la sonde de version FORDEAD forçait un `pip install` à chaque run). L'utilisateur observe que `run_fordead_dieback()` réinstalle les dépendances Python (`pip install --upgrade -r requirements.txt`, clones git inclus) à **chaque** appel, et affiche `fordead=NA` dans la bannière de démarrage. **Cause racine** (plus profonde que l'attribut sondé) : `system2()` ne quote PAS ses `args` — il colle `command` + `args` en une seule ligne passée au shell. `.fordead_python_import_ok()` exécutait `python -c import fordead` → le shell word-split en `import` (statement nu = `SyntaxError`) + `fordead` (argv) → exit ≠ 0 → `.fordead_is_installed()` toujours `FALSE` → réinstallation systématique. Idem pour la sonde de version, aggravée par le fait que `fordead.version` est une *fonction*, pas une chaîne. **Fix** : (1) `shQuote()` du code Python dans `.fordead_python_import_ok()` et dans le nouveau wrapper `.python_capture_stdout()` ; (2) `.fordead_python_version()` lit désormais `importlib.metadata.version("fordead")` (source canonique) au lieu de `print(fordead.version)` ; (3) `run_fordead_dieback()` réutilise cette sonde pour sa bannière au lieu de sonder les attributs du module → `fordead_version` correctement rapporté. Vérifié bout-en-bout contre le venv réel : `import_ok = TRUE`, `probe = 2.1.1`, `is_installed = TRUE` (plus de réinstallation). 3 tests neufs (`test-fordead-python.R`) + `test-fordead-pipeline.R` durci (assertion `fordead_version == "2.1.1"`, mock `.fordead_python_version` ajouté aux helpers) → pipeline 65 PASS. **5 échecs préexistants** sur `test-fordead-python.R` (lignes 32/190/319/320 + le test mismatch `.fordead_is_installed`) restent inchangés — non liés, à traiter en session séparée (le test mismatch utilise `expect_warning` sur un `cli_alert_warning` qui ne signale pas de condition R).

- **2026-05-20** — Release **v0.41.0** (feat — persistance des sorties FORDEAD dans le cache projet). Utilisateur : `run_fordead_dieback()` tournait dans un `tempfile("fordead_")` effacé en fin de session — tous les artefacts perdus, dont le masque catégoriel 0-4. `read_fordead_dieback_mask()` (livré v0.25.0 avec sa convention de chemin entièrement documentée) retournait donc toujours `NULL` : le **persist hook côté écriture n'avait jamais été implémenté** (flaggé « hors scope v0.25.0 »). **Livré** : (1) **persist hook (toujours actif)** — après la phase `postprocess`, le raster catégoriel 0-4 est écrit en `<mask_cache_dir>/zone_<id>/dieback_mask_<YYYYMMDDTHHMMSS>.tif`, exactement le chemin que `read_fordead_dieback_mask()` cherche ; le timestamp = run id, runs successifs s'accumulent en historique ; écriture best-effort (échec → warn, jamais d'abort). (2) nouvel argument **`mask_cache_dir`** — racine du cache FORDEAD persistant ; `NULL` (défaut) le dérive en sibling de `cache_dir` : `file.path(dirname(cache_dir), "fordead")` = `<project>/cache/layers/fordead`. (3) nouvel argument **`keep_output`** (opt-in, défaut `FALSE`) — si `TRUE` et `output_dir` au défaut, FORDEAD tourne directement dans `<mask_cache_dir>/zone_<id>/run_<ts>/` pour conserver le working set complet (~1000+ rasters) et pouvoir re-jouer `postprocess` sans re-`fit`/`predict` ; un `output_dir` explicite l'emporte toujours. Résultat enrichi de `rasters$dieback_mask`. Rétrocompat totale : `keep_output = FALSE` → working set en tempdir comme avant, seul le petit masque est désormais persisté en plus. 3 tests neufs dans `test-fordead-pipeline.R` (masque écrit + round-trip via `read_fordead_dieback_mask()`, dérivation défaut de `mask_cache_dir`, `keep_output` redirige `output_dir`) → 65 PASS. Doc roxygen `@param` + `@return` à jour. **Côté nemetonshiny** : `service_monitoring.R:310` appelle `run_fordead_dieback()` sans `mask_cache_dir` — le défaut dérivé suffit si `cache_dir` est `<project>/cache/layers/sentinel2` (cas nominal), le masque atterrira dans `<project>/cache/layers/fordead/` et la carte FORDEAD le lira automatiquement. Wiring app optionnel à porter en session dédiée nemetonshiny.

- **2026-05-20** — Release **v0.40.1** (fix — observabilité des phases post-`predict` dans `run_fordead_dieback()`). Utilisateur lance le diagnostic FORDEAD sur la zone Mouthe (débloquée par v0.27.0 pagination STAC : 1133 rasters écrits, ~80-100 dates), constate que la console reste figée sur `ℹ Step: predict` plusieurs minutes — impossible de distinguer un run en cours d'un blocage. Cause : seuls `fit` et `predict` passent par `.capture()` qui imprime `ℹ Step: …` ; les étapes suivantes (dérivation state raster, `first_dieback_date`, `postprocess` clustering, `persist` insertion DB) tournent sans aucune sortie console. **Fix** : ajout de `cli::cli_alert_info` gardés par `verbose` pour chaque étape post-predict + ligne `FORDEAD output_dir: <path>` au démarrage (l'utilisateur avait dû fouiller `tempdir()` pour trouver le dossier de sortie) + `cli_alert_success` récapitulatif en fin de run. Aucun changement de comportement hors console ; les events du progress_callback (`fordead:phase`/`fordead:phase_done`) inchangés. `test-fordead-pipeline.R` (54 PASS) inchangé — la sortie `cli` n'est pas un event de progression. **Note process** : fix préparé sur une base v0.27.0 périmée (22 commits de retard — le remote était passé à v0.40.0 via d'autres sessions Theia) ; récupération par fast-forward vers v0.40.0 puis réapplication du patch — `R/fordead_pipeline.R` était identique entre v0.27.0 et v0.40.0, aucun conflit.

- **2026-05-20** — Release **v0.40.0** (signature SDK teledetection — **chaîne Theia validée en réel**). Le test live a tranché : `/vsis3/` direct échoue (« Access Key Id does not exist ») — le Gate teledetection signe avec son propre compte S3, la clé API utilisateur n'est pas une clé S3 directe. La voie qui marche : `tld.sign_inplace` (SDK Python) produit une URL pré-signée AWS SigV4, lue ensuite par GDAL en `/vsicurl/`. Validé bout-en-bout par l'utilisateur : `terra::rast(paste0("/vsicurl/", href))` → FORMSpoT 2023, 1.5 m, France entière, EPSG:2154, crop + plot OK. **Formalisé** : nouveau helper exporté `theia_signed_href(source_key, year, asset, item_id, country, stac_api)` — délègue la signature au SDK `teledetection` via `reticulate` (`py_require()` déclare automatiquement `teledetection` + `pystac_client`), résout l'item/asset depuis les templates `access$item_id_template` / `asset_template`, renvoie une URL `/vsicurl/` prête. `load_theia_source()` en mode `year` passe désormais par `theia_signed_href()` (chemin authentifié validé) ; le mode recherche spatiale (`/vsis3/`) est conservé mais réservé aux accès S3 directs institutionnels. `reticulate` déjà en Suggests (FORDEAD) — pas de nouvelle dépendance R ; `teledetection`/`pystac_client` sont des paquets Python gérés par `py_require()`. NAMESPACE + 2 `man/*.Rd` (1 créé). 3 tests offline de validation (`theia_signed_href` : datasource inconnue, year/item_id manquant, pas de template). L'appel SDK réel n'est pas testé hors-ligne (reticulate + réseau). **La chaîne Theia → indicateurs est complète et prouvée fonctionnelle.**

- **2026-05-20** — Release **v0.39.1** (fix — credentials/région S3). Test live de l'utilisateur : `tld.sign_inplace` (SDK Python via reticulate) produit une **URL pré-signée AWS S3 SigV4 standard** — `?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=<accesskey>/<date>/sm1/s3/aws4_request&...`. Deux enseignements : (1) la clé API THEIA (créée sur gate.stac.teledetection.fr) **est** un couple de clés S3 SigV4 standard ; (2) la région est **`sm1`** (lue dans le scope `X-Amz-Credential`), pas `us-east-1`. La config `theia_configure_s3()` de v0.38.0 avait donc deux erreurs corrigées ici : variables d'env `THEIA_S3_*` → **`TLD_ACCESS_KEY` / `TLD_SECRET_KEY`** (mêmes noms que le SDK `teledetection`, une seule paire à poser dans `.Renviron`) ; région `us-east-1` → `sm1` dans `FR.json`. Conséquence : GDAL `/vsis3/` lit les assets THEIA en direct avec signature SigV4 native — **aucune dépendance Python / SDK teledetection nécessaire** (le SDK ne faisait que du SigV4 standard que GDAL sait faire). Le résolveur (`load_theia_source`, `resolve_theia_assets`, ciblage année) est inchangé. Test corrigé (`THEIA_S3_*` → `TLD_*`). À valider en local : `.Renviron` avec `TLD_ACCESS_KEY`/`TLD_SECRET_KEY`, `theia_configure_s3()`, puis `terra::rast("/vsis3/sm1-gdc-ext/FORMSpoT/2023/full_2023.vrt")`.

- **2026-05-20** — Release **v0.39.0** (ciblage par année). FORMSpoT publie un item STAC par an (`FORMSpoT-{year}`, 2014-2024), chacun avec un asset annuel (`height_{year}`) — une recherche par emprise renvoie tous les items annuels et le choix de l'asset `height_2023` échouerait sur l'item 2014. Ajout d'un mode « ciblage par année ». Livré : (1) `stac_get_item(stac_api, collection, item_id)` exporté — récupère un item STAC unique par id (GET `…/collections/…/items/…`). (2) `resolve_theia_assets()` et `load_theia_source()` gagnent un argument `year` : quand il est fourni et que la source déclare `access$item_id_template`, l'item est récupéré directement par id (id = template avec `{year}` substitué) et l'asset annuel résolu (nom = `access$asset_template` avec `{year}` substitué si `asset` non fourni) — pas de recherche spatiale, renvoie un seul chemin. (3) `FR.json` : l'entrée `formspot` porte désormais `item_id_template` (`FORMSpoT-{year}`), `asset_template` (`height_{year}`) et `years` ([2014, 2024]) exploitables. Si `year` est fourni sur une source sans `item_id_template` → erreur explicite. NAMESPACE + 3 `man/*.Rd` (1 créé, 2 mis à jour). 3 nouveaux tests (`stac_get_item` validation, ciblage année happy path mocké, erreur si pas de template). Tests R non exécutés. Usage : `load_theia_source("formspot", aoi, year = 2023)`. Le reliquat connu de FORMSpoT (sélection par année) est levé.

- **2026-05-20** — Release **v0.38.0** (auth S3 Theia). L'utilisateur fournit une URL d'asset : `gate.stac.teledetection.fr/download?url=https://s3-data.meso.umontpellier.fr/sm1-gdc-ext/FORMSpoT/2023/full_2023.vrt`. Constat : les assets COG/VRT vivent sur un MinIO **S3** (`s3-data.meso.umontpellier.fr`, bucket `sm1-gdc-ext`) ; le couple access-key/secret-key de l'utilisateur sont des identifiants S3. **Décision** : plutôt que de reproduire la signature `tld.sign_inplace` du SDK Python, `nemeton` lit les objets directement via le pilote GDAL `/vsis3/` — GDAL signe chaque requête en SigV4 nativement. Livré : (1) entrée `services.theia_s3` dans `FR.json` (endpoint, bucket, options — **pas de secret**). (2) `theia_configure_s3(access_key, secret_key, country)` exporté — pose la config GDAL `/vsis3/` (`AWS_S3_ENDPOINT`, `AWS_VIRTUAL_HOSTING=FALSE`, etc.) ; clés lues depuis `THEIA_S3_ACCESS_KEY` / `THEIA_S3_SECRET_KEY` (variables d'env, `.Renviron` gitignoré — déjà dans `.gitignore`). (3) helper interne `.theia_href_to_gdal()` — normalise toute forme d'href (passerelle `download?url=`, `s3://`, `https://<endpoint>/bucket/key`, `/vsi*`) vers `/vsis3/bucket/key` ; `resolve_theia_assets()` renvoie désormais des chemins `/vsis3/`. (4) `load_raster_source(path=)` accepte les chemins distants (`s3://`→`/vsis3/`, `http(s)://`→`/vsicurl/`, `/vsi*`), plus seulement les fichiers locaux ; helper `.to_gdal_path()`. NAMESPACE + 4 `man/*.Rd` (1 créé, 3 mis à jour). Tests : `test-theia-stac.R` (`.theia_href_to_gdal` 4 cas, `theia_configure_s3` 2 cas, résolveur renvoie `/vsis3/`), `test-datasources.R` (`load_raster_source` chemins `s3://` et `https://`). Tests R non exécutés (runtime R absent). **Workflow final** : `theia_configure_s3()` une fois, puis `load_theia_source("formspot", aoi, asset="height_2023")`. Chaîne Theia → indicateurs désormais complète côté `nemeton`.

- **2026-05-20** — Release **v0.37.0** (endpoint STAC corrigé + FORMSpoT vérifié). L'utilisateur fournit le notebook officiel d'accès FORMSpoT (gist Schwartz) — il révèle que l'accès programmatique passe par le package Python `teledetection` et `pystac_client.Client.open("https://api.stac.teledetection.fr", modifier=tld.sign_inplace)`. Corrections **vérifiées** dans `FR.json` : (1) `services.theia_stac.url` corrigé `api.datastore-mtd.theia.data-terra.org` → **`https://api.stac.teledetection.fr`** (l'URL datastore-mtd était le host du document de métadonnées affiché dans le browser, pas l'API programmatique). (2) **Authentification requise** : le téléchargement d'asset nécessite une clé API teledetection — le SDK signe les hrefs via `tld.sign_inplace`. Nouveau champ `auth` dans `services.theia_stac`. **Le résolveur R `theia_stac.R` n'implémente PAS encore cette signature** → il fait des requêtes anonymes, donc les lectures d'assets FORMSpoT échoueront tant que la signature n'est pas portée (décision d'archi à trancher — cf. ci-dessous). (3) FORMSpoT : collection `FORMSpoT`, un item par an `FORMSpoT-{year}` (2014-2024), asset hauteur `height_{year}`, **hauteur en décimètres** (÷10 pour des mètres — corrige le « to confirm m/cm »). (4) Nouvelle source `formspot_delta` : polygones de perturbation forestière FORMSpoT-∆ (collection `FORMSpoT-delta`, item `FORMSpoT-delta_2014-2024`, asset vectoriel `disturbance_polygons`, attribut `year`), `consumed_by` R5/T2. 2 tests `test-datasources.R` adaptés/ajoutés, 1 test `test-theia-stac.R` adapté. Tests R non exécutés. **Décision d'archi en attente** : porter la signature `teledetection` en R (clé API + signing, lourd, non testable ici) OU faire consommer à `nemeton` des URLs déjà signées (obtenues via le SDK Python / l'app) — `load_raster_source(path=)` devrait alors accepter une URL distante en plus d'un fichier local.

- **2026-05-20** — Release **v0.36.1** (fix — endpoint STAC Theia confirmé). L'utilisateur fournit la racine de l'API STAC vue dans le panneau « Source » du browser Theia : `https://api.datastore-mtd.theia.data-terra.org` (STAC 1.1.0, accès anonyme, search à `<url>/search`). `services.theia_stac.url` passe de `"to confirm"` à cette valeur dans `FR.json`. L'entrée `forms_t` gagne `access.stac_collection: "forms-t"` (vérifié) et son `stac_catalog` est corrigé vers le bon host — `load_theia_source("forms_t", aoi, asset=...)` est donc directement opérationnel. **Bug corrigé** dans `resolve_theia_assets()` / `.theia_stac_api()` : le garde `"to confirm"` testait l'égalité stricte (`identical()`) alors que les placeholders de FR.json valent `"to confirm at the Theia catalogue"` — remplacé par un `grepl("to confirm")`, sinon une collection non vérifiée aurait été envoyée telle quelle à l'API. 2 tests de `test-theia-stac.R` adaptés (le scénario « endpoint non configuré » se teste désormais via le pays EU qui n'a pas d'entrée `theia_stac` ; le scénario « collection non confirmée » via `s2_biophysical`). Tests R non exécutés (runtime R absent). **Le chantier Sources Theia est désormais pleinement opérationnel côté `nemeton`** : `nemetonshiny` n'a plus qu'à appeler `load_theia_source()` et passer les rasters aux indicateurs.

- **2026-05-20** — Release **v0.36.0** (feat — résolveur STAC Theia). Lève le point reporté de la Phase 2 : la résolution STAC automatique. Nouveau module `R/theia_stac.R`, trois fonctions exportées. (1) `stac_search_items(stac_api, collection, bbox, datetime, limit)` — recherche STAC générique, agnostique à l'endpoint, bâtie sur le paginateur projet `.stac_search_paginate()` (réutilisé tel quel). (2) `resolve_theia_assets(source_key, aoi, asset, datetime, country, stac_api, limit)` — résout une source Theia : lit `access$stac_collection` dans FR.json, calcule la bbox WGS84 de l'AOI, interroge l'API STAC Theia, extrait les hrefs d'assets (helper `.stac_pick_asset()` : asset nommé, sinon rôle `data`, sinon premier) et les préfixe `/vsicurl/`. (3) `load_theia_source(source_key, aoi, asset, ...)` — résout puis charge en `SpatRaster` (mosaïque virtuelle `terra::vrt()` si plusieurs items), croppé à l'AOI. L'endpoint STAC est lu dans une nouvelle entrée `services.theia_stac` de FR.json. **Réserve** : son champ `url` est livré à `"to confirm"` — le host du browser STAC (`browser.datastore-mtd.theia.data-terra.org`) est vérifié mais la racine de l'API STAC derrière lui doit être confirmée et renseignée (ou passée via l'argument `stac_api`). Tant que c'est `"to confirm"`, le résolveur s'arrête avec un message actionnable plutôt que de deviner un endpoint. NAMESPACE + 4 `man/*.Rd` (3 fonctions + page `@name`). 11 `test_that` dans `test-theia-stac.R` (`.stac_pick_asset` 4 cas, `stac_search_items` validation + happy path mocké httr2, `resolve_theia_assets` erreurs source/endpoint/collection inconnus + happy path mocké, `load_theia_source` propagation d'erreur). Tests R non exécutés (runtime R absent). **Ce qu'il reste pour que `nemetonshiny` consomme Theia** : (a) renseigner `services.theia_stac.url` une fois l'API STAC Theia confirmée ; (b) côté app, appeler `load_theia_source()` et passer les rasters aux indicateurs (`chm`, `fapar`, `texture`, `snow`, ...). Le câblage app reste un chantier `nemetonshiny`.

- **2026-05-20** — Release **v0.35.2** (FORMSpoT câblé dans les indicateurs). Suite à la confirmation de disponibilité (v0.35.1), FORMSpoT sort du reliquat de câblage. Constat d'architecture : FORMSpoT (produit hauteur au niveau de l'arbre, famille FORMS) n'a **pas besoin d'argument d'indicateur dédié** — il se branche sur l'argument `chm` déjà existant de `indicateur_c1_biomasse()`, `indicateur_p1_volume()`, `indicateur_p2_station()` et `indicateur_b2_structure()`, la même interface CHM que FORMS-T (`forms_t`) et `chm_opencanopy` (introduite spec 005). Workflow : `load_raster_source("formspot", path = ...)` puis passage en `chm`. Aucun code R nouveau. `inst/datasources/FR.json` mis à jour : `consumed_by` nomme désormais les fonctions précises (C1/P1/P2/B2 au lieu du vague C/P/T/R), `products` se scinde en `height` (compatible CHM) et `biomass`, et un nouveau champ `integration_note` documente le chemin d'intégration (avec la réserve : rastériser l'attribut hauteur si FORMSpoT est livré en couche vectorielle points-arbres). Le test `test-datasources.R` est mis à jour (vérifie `consumed_by` = C1/P1/P2/B2, présence du produit `height` et de `integration_note`). Les familles T (temporel) et R5 (dépérissement) ne sont volontairement pas câblées : elles ont leurs propres structures (analyse temporelle, pipeline FORDEAD), un câblage demanderait un vrai chantier dédié et la connaissance du schéma exact du produit. Bump patch (changement de métadonnées catalogue, pas de code R).

- **2026-05-20** — Release **v0.35.1** (fix — métadonnées FORMSpoT). L'utilisateur confirme que FORMSpoT est publié comme collection STAC THEIA `FORMSpoT` sur `browser.datastore-mtd.theia.data-terra.org`. L'entrée `formspot` de `inst/datasources/FR.json`, déclarée provisoire en v0.30.0 (stade preprint), gagne les champs vérifiés `stac_catalog` + `stac_collection` ; la note « provisoire / disponibilité à confirmer » est remplacée par la description de diffusion réelle. Le test `test-datasources.R` correspondant est renforcé (vérifie `stac_collection == "FORMSpoT"`) et renommé. Le **câblage indicateurs** de FORMSpoT reste un reliquat (granularité au niveau de l'arbre — mapping d'attributs dédié à définir).

- **2026-05-20** — Release **v0.35.0** (feat — sources Theia phase 3d, **clôture du chantier Sources Theia**). Câblage des sources 1b, livré en une seule release à la demande. Trois câblages sains retenus. (1) **W2** — `indicateur_w2_zones_humides()` gagne `water_occurrence = NULL` + `occurrence_threshold = 25` : quand le raster d'occurrence d'eau Theia `theia_water` est fourni, les pixels dont la fréquence d'occurrence dépasse le seuil ajoutent à la couverture zones humides — 4ᵉ source additive, s'insère proprement dans le design multi-sources existant de W2. (2) **R3** — `indicateur_r3_secheresse()` gagne `soil_moisture = NULL` + `sm_relief_strength = 0.3` : le sol humide atténue le stress de sécheresse contre une référence 0.3 m³/m³ (capacité au champ), même mécanique de « relief » que l'argument `snow` de v0.34.0. R3 a donc maintenant 4 arguments optionnels Theia (snow, soil_moisture + leurs forces) — tous NULL par défaut. (3) **theia_species** — nouveau helper exporté `units_add_species_from_raster(units, species_raster, class_map, species_col)` dans `R/utils.R` : résout la classe dominante pondérée par couverture par UGF et la mappe vers un code essence via un crosswalk fourni par l'utilisateur (le mapping classes→essences est spécifique au produit, non devinable) ; remplit la colonne `species` consommée en amont par P1/P2/C1 et les indicateurs biodiversité. **Reliquat documenté — 4 câblages volontairement non faits** : `s2_l2a_muscate` est une donnée de base (réflectance S2 brute) dont le point d'intégration est le pipeline d'ingestion S2 existant, pas un argument d'indicateur ; `theia_lst` → A2 est une inadéquation sémantique (A2 = qualité de l'air / pollution, la LST est une température — câbler reviendrait à dénaturer A2, il faudrait un sous-indicateur microclimat dédié) ; `theia_water` → W1 non fait (W1 = densité de réseau linéaire m/ha, un masque raster ne s'y mappe pas) ; `formspot` non câblé (source provisoire, preprint arXiv:2512.17021, disponibilité Theia non confirmée). NAMESPACE + 3 `man/*.Rd` (1 créé, 2 mis à jour). 6 nouveaux `test_that` (2 W2, 2 R3, 2 helper espèces). Tests R non exécutés (runtime R absent). **Chantier Sources Theia clos** : 10 sources cataloguées (Phase 1), loaders (Phase 2), 4 sources câblées dans 6 indicateurs + 1 helper (Phase 3) ; reliquat de 4 câblages documenté pour un éventuel chantier ultérieur.

- **2026-05-20** — Release **v0.34.0** (feat — sources Theia phase 3c, câblage `theia_snow`). Câblage du produit neige Theia dans l'indicateur de risque sécheresse R3, rétrocompatible. `indicateur_r3_secheresse()` gagne deux arguments : `snow = NULL` (un `SpatRaster` de durée d'enneigement en jours/an — produit `snow_cover_duration` de `theia_snow`) et `snow_relief_strength = 0.3` (réduction fractionnaire max de R3). Logique : le manteau neigeux est une réserve hydrique saisonnière — sa fonte alimente le sol en début de saison de végétation et réduit le stress de sécheresse estival. Quand `snow` est fourni, la durée d'enneigement moyenne par UGF est extraite, rééchelonnée 0-1 contre une référence 180 jours (6 mois), et R3 est multiplié par `1 - snow_relief_strength * relief` (donc jusqu'à -30 % pour 6 mois d'enneigement). Les UGF hors couverture neige (`NA`) reçoivent `relief = 0` → R3 inchangé (pas de pénalité ni de bonus, comportement sûr). Le bloc neige est placé après le calcul climat+topo, avant l'affectation `units$R3`. `snow = NULL` (défaut) → comportement v0.33.x strictement préservé. `man/indicateur_r3_secheresse.Rd` mis à jour à la main. 2 nouveaux `test_that` (la neige n'augmente jamais R3 vs sans neige ; rejet d'un `snow` non-raster). Le test existant `simplified signature` reste vert (vérifie la présence de 4 params, pas l'exclusivité). Tests R non exécutés (runtime R absent). **Suite** : 3d (sources 1b — `theia_water`→W1/W2, `theia_soil_moisture`→W3/R3/F1, `s2_l2a_muscate`→C2/T2/R5, `theia_species`→B/P/C, `theia_lst`→A2, `formspot`→C/P/T/R).

- **2026-05-20** — Release **v0.33.0** (feat — sources Theia phase 3b, câblage `theia_soil`). Câblage du produit texture des sols Theia dans la famille F (sols), rétrocompatible. **Deux helpers exportés** dans `R/indicators-families.R`, sur le modèle de `cec_to_fertility_score()` : (1) `texture_to_fertility_score(clay, silt, sand, coarse_elements = NULL)` — mappe une composition texturale vers un score de fertilité 0-100 par proximité à l'optimum loam (argile 0.20, limon 0.40, sable 0.40) dans le triangle textural, avec pénalité d'éléments grossiers ; (2) `texture_to_erosion_resistance(clay, silt, sand)` — score de résistance à l'érosion 0-100 selon la logique d'érodibilité USLE (le limon érode, l'argile résiste par cohésion). Le triplet est renormalisé en interne → helpers agnostiques à l'unité (g/kg, %, fraction). Les deux sont documentés comme **heuristiques calibrables de première passe**, exportés pour audit pédologue (pas des pédotransferts validés). **F1** — `indicateur_f1_fertilite()` gagne `source = "theia_soil"` (ajouté au `match.arg`) et un argument `texture` (liste nommée de `SpatRaster` clay/silt/sand, optionnellement coarse_elements) ; helpers internes `.extract_texture_means()` (extraction des moyennes par UGF) et `extract_fertility_from_theia_soil()`. **F2** — `indicateur_f2_erosion()` gagne un argument `texture = NULL` ; quand fourni, une composante résistance-érosion est moyennée avec TWI + pente (F2 = moyenne des 3 au lieu de 2). Note : F2 est nommé « erosion » mais calcule en réalité un indice de fertilité depuis TWI+pente (héritage du code existant, roxygen titré « Soil Fertility Index ») — la composante texture s'y insère avec la même polarité (résistance haute = score haut). Tous les ajouts rétrocompatibles : `source` défaut `"layer"`, `texture` défaut `NULL`, aucun appelant existant affecté. NAMESPACE + 4 fichiers `man/*.Rd` (2 créés, 2 mis à jour) à la main. 7 nouveaux `test_that` (4 helpers en numérique pur : loam > sable/argile, pénalité grossiers, agnosticité d'unité, argile résiste > limon ; 2 F1 : mode theia_soil renvoie 0-100, erreur si `texture` absent ; 1 F2 : accepte une texture). Tests R non exécutés (runtime R absent). **Suite** : 3c (`theia_snow` → R3), 3d (sources 1b).

- **2026-05-20** — Release **v0.32.0** (feat — sources Theia phase 3a, câblage `s2_biophysical`). Premier câblage d'une source Theia dans le code cœur des indicateurs (Niveau 3), strictement rétrocompatible. (1) **C2** — `indicateur_c2_ndvi()` gagne un argument `fapar = NULL`. Quand un `SpatRaster` FAPAR est fourni (produit Theia `s2_biophysical`), la fonction renvoie la moyenne FAPAR par UGF au lieu du NDVI — FAPAR est une mesure de vitalité physiquement fondée sur la même échelle `[0, 1]` que le NDVI, donc la normalisation aval est inchangée. Bloc « FAPAR mode » placé avant la résolution du raster NDVI ; `fapar = NULL` → comportement v0.31.x préservé. (2) **A1** — `indicateur_a1_couverture()` gagne un argument `fvc = NULL` et `land_cover` passe en défaut `NULL`. Quand un `SpatRaster` FVC est fourni (produit Theia `s2_biophysical`), A1 = moyenne FVC par buffer × 100 (FVC est une fraction 0-1 → échelle 0-100 de A1) ; `land_cover` est alors ignoré. La vérification `land_cover` est déplacée dans la branche legacy — un appel sans `land_cover` ni `fvc` échoue toujours sur « land_cover must be a SpatRaster » (test existant `handles missing land_cover` préservé). Les deux arguments sont purement additifs : aucun appelant existant n'est affecté, le dispatcher `compute_indicator()` (qui route par `...`) n'a pas besoin de modif. `man/indicateur_c2_ndvi.Rd` et `man/indicateur_a1_couverture.Rd` mis à jour à la main (roxygen non exécutable ici). 5 nouveaux `test_that` (2 C2 : FAPAR mode renvoie un vecteur double de bonne longueur, rejet d'un `fapar` non-raster ; 3 A1 : FVC mode renvoie A1 ∈ [0,100], FVC mode ignore `land_cover = NULL`, rejet d'un `fvc` non-raster) — les tests C2 sont placés en fin de fichier car ils utilisent le helper `make_mock_layers()` défini après le bloc C2 d'origine. Tests R non exécutés (runtime R absent). **Suite** : 3b (`theia_soil` → F1/F2), 3c (`theia_snow` → R3), 3d (sources 1b).

- **2026-05-20** — Release **v0.31.0** (feat — sources Theia phase 2, loaders). Rend chargeables les entrées de catalogue déclarées en Phases 1a/1b. **Décision d'accès** : les identifiants de collection STAC Theia étant tous `"to confirm"`, Phase 2 standardise sur le workflow *download-then-load* — la résolution STAC automatique est reportée à la vérification des endpoints. Deux livrables dans `R/datasources.R` : (1) `load_raster_source()` gagne un argument `path` — les sources Theia sont `type: "raster_local"` sans URL statique (distribuées par tuile/année via le catalogue Theia, téléchargées par l'utilisateur) ; le loader accepte désormais un chemin explicite vers le fichier téléchargé, qui passe par l'API datasource normale (harmonisation CRS via le préprocessing aval, crop AOI). Les sources `raster_local` sans path échouent toujours proprement si aucun `path` n'est fourni, et le fichier doit exister (`file.exists`). Pas de nouveau `type`. La branche `raster_local` renomme sa variable locale `path` → `declared_path` / `resolved_path` pour éviter la collision avec le nouvel argument ; message d'erreur conservé compatible avec le test `chm_opencanopy` existant (regex `no.*path`). (2) Nouveau helper exporté `get_datasource_product(source_key, product, country)` : renvoie les métadonnées d'un sous-produit d'une source multi-produits (`forms_t` height/volume/biomass, `theia_soil` clay/silt/sand/coarse_elements, etc.) — résolution, unité, plage, notes de conversion (ex. la note cm→m de FORMS-T à appliquer avant de passer la hauteur en argument `chm`). Export ajouté à `NAMESPACE` (ordre alpha, entre `get_data_source` et `get_game_pressure_raster`) ; `man/get_datasource_product.Rd` créé et `man/load_raster_source.Rd` mis à jour à la main (roxygen non exécutable ici). 8 nouveaux `test_that` dans `test-datasources.R` (3 sur l'argument `path` : chargement via fichier local mocké, erreur fichier absent, refus si path-less sans path ; 4 sur `get_datasource_product` : sous-produit valide, produit inconnu, source sans bloc `products`, datasource inconnue ; +1). Tests R non exécutés (runtime R absent) — JSON validé. **Suite** : Phase 3 (câblage indicateurs, une sous-tâche par source — 3a `s2_biophysical`→C2/A1, 3b `theia_soil`→F1/F2, 3c `theia_snow`→R3, 3d sources 1b).

- **2026-05-20** — Release **v0.30.0** (feat — sources Theia phase 1b). Six produits Theia / DATA TERRA complémentaires déclarés dans `inst/datasources/FR.json`, **clôturant la Phase 1 (catalogue)** du chantier — 10 sources Theia au total. Toujours sur le modèle déclaratif `forms_t`, **aucune modif du code cœur**. (1) `theia_water` — étendue et fréquence d'occurrence des eaux de surface (lignée Surfwater), `consumed_by` W1 / W2. (2) `theia_soil_moisture` — humidité de surface SMOS L3 (grossière, contexte régional) + variante dérivée Sentinel-1, `consumed_by` W3 / R3 / F1, avec note explicite que SMOS (~25-43 km) est inexploitable au parcellaire. (3) `s2_l2a_muscate` — réflectance de surface Sentinel-2 L2A (MUSCATE / MAJA), alternative nationale au flux CDSE/PC, `consumed_by` C2 / T2 / R5. (4) `theia_species` — classification d'essences, taggé `augmented: "species_ml"`, `consumed_by` B1 / B2 / P / C (note : mapping classes → codes essences nemeton à aligner avec `R/species-config.R`). (5) `theia_lst` — température de surface (lignée Thermocity), `consumed_by` A2. (6) `formspot` — FORMSpoT suivi forestier au niveau de l'arbre, déclaré comme **entrée provisoire** (preprint arXiv:2512.17021, disponibilité Theia à confirmer), `consumed_by` C / P / T / R. 7 nouveaux `test_that` dans `test-datasources.R` (un par source + un transversal type/ndp/provenance). Tests R non exécutés (runtime R absent) — JSON validé syntaxiquement (15 datasets). **Suite** : Phase 2 (loaders — résolveur STAC / extension `load_raster_source()`) puis Phase 3 (câblage indicateurs, une sous-tâche par source).

- **2026-05-20** — Release **v0.29.0** (feat — sources Theia phase 1a). Ouverture du chantier *Sources de données Theia* (cf. table d'avancement + section *Chantier en cours*). Phase 1a : déclaration de trois produits Theia / DATA TERRA prioritaires dans `inst/datasources/FR.json`, section `datasets`, sur le modèle déclaratif de `forms_t` (v0.28.0) — **aucune modif du code cœur des indicateurs**. (1) `s2_biophysical` — variables biophysiques Sentinel-2 (LAI / FAPAR / FVC) à 10 m, `consumed_by` C2 (vitalité, complément du NDVI) / A1 (couverture arborée via FVC) / B2 (hétérogénéité LAI). (2) `theia_soil` — cartes de sol France métropolitaine (fractions argile / limon / sable + éléments grossiers), `consumed_by` F1 (texture = proxy de fertilité, alternative France au SoilGrids CEC global) / F2 (érodibilité). (3) `theia_snow` — collection Theia Snow (Let-it-snow / LIS), couverture neigeuse + phénologie annuelle à 20 m, `consumed_by` R3 (manteau neigeux = réserve hydrique modulant le stress de sécheresse) / W. Chaque entrée : `type: "raster_local"` sans URL statique (→ `load_raster_source()` refuse de charger, comme `forms_t` / `chm_opencanopy`), `ndp_level: 0`, bloc `provenance`, et marqueurs `"to confirm"` explicites sur les métadonnées non encore vérifiées (id de collection STAC, résolution exacte, licence). 4 nouveaux `test_that` dans `test-datasources.R` (un par source + un test transversal provenance). Tests R non exécutés ici (runtime R absent de l'environnement) — JSON validé syntaxiquement. **Suite du chantier** : phase 1b (6 sources complémentaires : `theia_water`, `theia_soil_moisture`, `s2_l2a_muscate`, `theia_species`, `theia_lst`, `formspot`), puis phase 2 (loaders) et phase 3 (câblage indicateurs).

- **2026-05-20** — Release **v0.28.0** (feat — FORMS-T déclarée comme source de données). Demande utilisateur : intégrer la donnée Theia FORMS-T (`https://doi.theia.data-terra.org/FormsT/`) comme source pour le calcul des indicateurs C1, P1, P2 et B2. FORMS-T est une série temporelle (2018-présent) de cartes d'attributs forestiers sur la France métropolitaine — hauteur de canopée (10 m), volume de bois sur pied (30 m), biomasse aérienne (30 m) — produite par deep learning à partir de Sentinel-1/2 + GEDI (Schwartz et al. 2023, ESSD, doi:10.5194/essd-15-4927-2023). **Implémentation** : nouvelle entrée `forms_t` dans `inst/datasources/FR.json` (section `datasets`), `type: "raster_local"`, `format: "COG"`, `native_crs: EPSG:2154`, `ndp_level: 0`, `augmented: "height_ml"` (cohérent ADR-011 amendé spec 005 — granularité satellite+ML, pas de montée de niveau NDP). Trois sous-produits décrits dans `products` avec résolution / unité / `value_range` plausible ; un bloc `access` (DOI Theia, catalogue STAC `browser-theia.stac.teledetection.fr`, record Zenodo 15489231) ; un bloc `consumed_by` documentant le câblage du produit hauteur dans le chemin CHM des quatre indicateurs `indicateur_c1_biomasse()` / `indicateur_p1_volume()` / `indicateur_p2_station()` / `indicateur_b2_structure()` (déjà dotés d'un argument `chm` depuis spec 005). **Point d'attention** documenté dans le JSON : la hauteur FORMS-T est stockée en centimètres — l'appelant divise le raster par 100 avant de le passer en argument `chm` (qui attend des mètres). Pas de code indicateur modifié : les quatre fonctions consomment déjà un `SpatRaster` via `chm`, l'intégration est purement déclarative (catalogue de sources). `forms_t` ne porte volontairement pas d'URL statique (diffusion par tuile/année via STAC ou Zenodo) → `load_raster_source()` refuse de le charger directement, comme `chm_opencanopy`. 4 nouveaux `test_that` dans `test-datasources.R` (déclaration, trois produits + unités, `value_range` plausibles, `consumed_by` + provenance). Tests R non exécutés ici (runtime R absent de l'environnement d'exécution) — JSON validé syntaxiquement. Aucune modif cœur des indicateurs.

- **2026-05-19** — Release **v0.27.0** (feat — pagination STAC dans `stac_search_s2*()`). Utilisateur signale que la cascade FORDEAD remontait toujours avec v0.25.9 le message « No Sentinel-2 scene in the training window » avec `Scenes available: 2024-02-03 → 2026-05-01 (100 scenes)`. Investigation : `R/sentinel2.R::stac_search_s2()` avait `limit = 100L` hardcodé sans pagination ; CDSE/PC trient par date décroissante donc les 100 scènes retournées étaient les plus récentes (16 mois), training 2018-2020 invisible. Le garde-fou v0.25.7 pointait vers les dates mais la vraie cause était le cap. **Fix** : refactor de `stac_search_s2_cdse()` et `stac_search_s2_pc()` autour d'un nouveau helper `.stac_search_paginate(initial_url, initial_body, max_total)` qui suit l'extension STAC standard `links[rel=next]` (variants POST-with-body et GET-with-token), accumule les features, et stoppe sur (a) absence de next link, (b) page vide défensive, (c) `max_total` atteint, (d) safety cap `.STAC_MAX_PAGES = 100L` (= ~100k features) avec `cli_warn` actionnable. Per-page size fixée à 1000 (max accepté par les deux backends), override via env `NEMETON_STAC_PAGE_SIZE`. Default `limit` bumpé 100 → **10000** au façade et aux deux backends — couvre ~10 ans de revisite mono-tuile, largement de quoi pour la canonique training 2 ans + monitoring 18 mois (v0.25.9). Rétrocompat totale : callers existants sans `limit` explicite récupèrent plus de scènes silencieusement (effet recherché), callers avec `limit = N` gardent la même borne sup. Roxygen `@param limit` réécrit. 5 nouveaux tests dans `test-sentinel2.R` via `httr2::with_mocked_responses` : single-page, multi-page, max_total truncation, empty-page defensive, env var override. 101 PASS (+13). Deux failures préexistantes sur main dans le même fichier (test "All STAC backends failed" via local_mocked_bindings) restent inchangées — à investiguer dans une session séparée. **Tests pipeline FORDEAD** (54 PASS) inchangés : les mocks stubent `ingest_s2_raw_bands_to_cache` directement, le swap STAC est transparent. La zone Mouthe de l'utilisateur peut désormais lancer FORDEAD avec les defaults v0.25.9 sans plus voir le cap des 100.

- **2026-05-19** — Release **v0.26.0** (feat — BD Forêt V2 fallback dans `check_fordead_validity()`). Utilisateur signale que le warning `"No species column found on units"` rend le garde-fou G3-espèces inopérant quand les UGF chargées via `nemetonshiny` n'ont pas de colonne d'essence (cas du chargement cadastre/parcelles brut). BD Forêt V2 est déjà téléchargée par `nemetonshiny` dans `<project>/cache/layers/bdforet.gpkg` et `nemeton::enrich_parcels_bdforet()` sait déjà dériver l'essence dominante par intersection aire-pondérée — il manquait juste le câblage automatique. Ajout de deux nouveaux arguments `bdforet =` (sf direct) et `layers =` (nemeton_layers résolu via `resolve_vector_layer(layers, "bdforet")`). Priorité : (1) colonne d'essence sur units (inchangé) → (2) bdforet direct → (3) layers résolus → (4) warning + skip (comportement v0.25.9 préservé). Fallback déclenche `cli_alert_info` "Species column derived from BD Forêt V2" pour traçabilité console. Warning final amendé avec un hint pointant vers les deux nouveaux args. Tests : 4 scénarios neufs dans `test-fordead-validity.R` (direct bdforet, via layers, neither resolves → warning, ignored quand units a déjà species) → 63 PASS au lieu de 12. Rétrocompatibilité totale : aucun appelant existant n'est cassé. **Côté nemetonshiny** : un fix futur (à porter en session dédiée nemetonshiny) doit charger `bdforet.gpkg` et passer `bdforet =` (ou monter le nemeton_layers et passer `layers =`) à l'appel de `check_fordead_validity()` — sinon le fallback reste théorique pour l'utilisateur final.

- **2026-05-19** — Release **v0.25.9** (patch — rolling defaults for `run_fordead_dieback()`). Suite à la cascade v0.24.0 → v0.25.8 qui a débloqué le pipeline FORDEAD end-to-end (Diagnostic terminé sur la zone Mouthe, 0 alertes / zone saine, 142 s), les defaults `dates_training = c("2016-01-01", "2017-12-31")` et `dates_monitoring = c("2018-01-01", Sys.Date())` n'avaient plus de sens : sur un cache 2024+ ils sélectionnaient 0 scène et déclenchaient le gating v0.25.7. Nouveaux defaults calibrés ADR-013 : training 2 ans `c("2018-01-01", "2020-12-31")` (début couverture S2 dense, harmonique propre, pas de pollution par perturbations récentes) + monitoring fenêtre glissante 18 mois `c(seq(Sys.Date(), by = "-18 months", length.out = 2)[2], Sys.Date())` (cycle végétal complet + premiers stades de dépérissement lent, actionnable). `run_fordead_dieback(con, zone_id, cache_dir)` est désormais directement utilisable sans surcharge de dates. Roxygen `@param dates_training` / `@param dates_monitoring` réécrits avec la justification, exemple `\dontrun{}` mis à jour. Tests `test-fordead-pipeline.R` (54 PASS) inchangés — les scénarios qui exercent la logique de dates passent toutes les dates explicitement.

- **2026-05-19** — Release **v0.25.8** (patch — fordead.utils submodule explicit import). Bug surfacé après v0.25.7 (gating training/monitoring). Le pipeline progresse cleanly à travers ingest → stac_assembly → fit → predict (100 scènes sur 116, 1 scène skippée car bandes manquantes) puis warn `first_dieback_date derivation failed: AttributeError: module 'fordead' has no attribute 'utils'`. **Cause** : `reticulate::import("fordead")` charge le top-level package mais Python n'auto-importe pas les submodules. `fd$utils` lookup attribut → AttributeError. Le pipeline continue grâce au `tryCatch` mais `first_dieback_date` devient silencieusement NULL/NA_character_. **Fix** dans `run_fordead_dieback()` : import explicite `reticulate::import("fordead.utils", convert = FALSE)` avant l'appel à `.compute_first_dieback_date()`. Wrappé en `tryCatch` pour tolérer un pin fordead older qui n'aurait pas le submodule (fallback NULL → pipeline continue sans le raster first_dieback_date). Tests : `test-fordead-pipeline.R` (54 PASS) inchangé — les mocks stubent `.compute_first_dieback_date` directement, le swap interne est transparent. **Bilan cascade FORDEAD 16-19/05** : 12 releases consécutives (v0.24.0 → v0.25.8). Phase fit() + predict() ont enfin tourné sur la zone de prod utilisateur (100 scènes 2024-02 → 2026-04, training 2 ans + monitoring 3 mois, cache déjà rempli) — reste postprocess + persist à valider.

- **2026-05-18** — Release **v0.25.7** (patch — pre-fit empty-window gating). Bug surfacé après que v0.25.6 ait débloqué le CRS alignment : le run réel atteint la phase fit() avec 116 scènes 2024-2026, mais plante `AssertionError: out_bounds=None` profondément dans stackstac (`prepare.py:372`). **Cause** : `dates_training = c("2016-01-01", "2017-12-31")` par défaut sélectionne **0 scène** dans un cache 2024+. fordead `compute_spectral_index` tourne sur slice temporel vide, écrit 0 fichier CRSWIR, puis `update_ds("CRSWIR")` appelle `stackstac.stack(assets=["CRSWIR"])` avec 0 asset → `out_bounds` reste None → assertion. Aucun message actionnable pour l'utilisateur (assert deep stack). **Fix** dans `run_fordead_dieback()` : après la phase ingest, count des scènes dans `[dates_training[1], dates_training[2]]` et `[dates_monitoring[1], dates_monitoring[2]]`. Si l'un des deux est 0, abort typé `cli::cli_abort` avec : (a) l'enveloppe scene-dates min/max, (b) le count par fenêtre, (c) hint d'ajustement. Le caller voit exactement ce qui doit changer dans ses dates. Tests : `test-fordead-pipeline.R` +2 tests (54 PASS au lieu de 50), empty-training et empty-monitoring scenarios. Vérifie aussi que `fk$env$calls` est de longueur 0 → fordead `fit()` n'a JAMAIS été appelée (abort avant). **Note** : la cause d'origine (defaults `dates_training = 2016-2017` côté `nemeton`, scenes prod 2024+ sur la zone utilisateur) suggère qu'il faudrait reconsidérer les defaults dans une release future. Aujourd'hui le caller doit explicitement passer ses dates correctes — le message d'erreur lui dit lesquelles. **Bilan cascade FORDEAD 16-18/05** : 11 releases consécutives (v0.24.0 → v0.25.7), chaque release pousse la frontière d'erreur d'un cran. Phase fit() avec CRS aligné + window cohérente accessible désormais.

- **2026-05-18** — Release **v0.25.6** (patch — FORDEAD `fit()` CRS alignment). Bug surfacé après le run FORDEAD réel post-fix v0.25.5 du sampling : la phase 0 ingest peuple le cache, la phase 1 STAC assembly construit l'`ItemCollection` avec `proj:epsg=32631` (tuile UTM Sentinel-2 T31TGM), mais la phase 2 `fit()` plante `rioxarray.exceptions.NoDataInBounds: No data found in bounds` dans stackstac. **Cause** : on passait `bbox` et `geometry` à `FordeadProcess()` en EPSG:4326 (degrés) alors que le cache S2 est en EPSG:32631 (mètres). Le setter `FordeadProcess.geometry` tente `value.to_crs(self.crs)` mais SEULEMENT si l'input a un attribut `to_crs` (GeoDataFrame / GeoSeries). Notre `.aoi_geometry_reticulate()` retournait un `shapely.geometry.Polygon` brut sans `to_crs`, donc le setter ne reprojetait pas. Le bbox restait en degrés sur un cube de données en mètres → `stackstac.clip_box()` trouve 0 pixel. **Fix en 2 parties** : (1) `R/fordead_stac.R::.aoi_geometry_reticulate()` retourne désormais une `geopandas.GeoSeries(crs="EPSG:4326")` (length-1, wrappant le shapely). Le setter détecte alors `to_crs` + `total_bounds` et reprojete auto vers le CRS du collection (32631), puis override `self.bbox` depuis `geometry.total_bounds`. (2) `R/fordead_pipeline.R::run_fordead_dieback()` passe désormais `bbox = NULL` au `FordeadProcess()`. Pre-v0.25.6 le constructor stockait le bbox-degrés à la ligne 95 de `workflow.py`, puis le setter `geometry` (ligne 97) déclenchait `self.crs` qui appelle `to_xarray(bbox=self.bbox=degrés, geometry=None)` — clip pré-reprojection sur le mauvais CRS pouvait aussi raise `NoDataInBounds` avant que notre override geometry ne prenne effet. Avec `bbox = NULL`, le collection est assemblé non-clippé, `self.crs` résout au CRS du collection, et le geometry setter finalise proprement. Tests : `test-fordead-stac.R` mis à jour pour mocker `geopandas$GeoSeries` + `reticulate::import_builtins()` (73 PASS / 2 charToDate pré-existants) ; `test-fordead-pipeline.R` (48 PASS) inchangé — ces tests mockent `.aoi_geometry_reticulate` au niveau du package donc le swap interne est transparent. **Note version** : 2 sessions concurrentes ont livré le matin (v0.25.4 + v0.25.5 sur les helpers project_layers, mergées via PR #21 + #22) pendant que cette session préparait le fix CRS — bumping en v0.25.6 sur top de l'origin. **Bilan cascade FORDEAD 16-18/05** : 10 releases consécutives (v0.24.0 refonte → v0.24.1 STAC 7 bandes → v0.24.2 parité s2:* → v0.24.3 simplestac.utils import → v0.24.4 proj:*/raster:* metadata → v0.25.6 CRS-aware geometry). Chaque release a poussé la frontière d'erreur d'un cran — phase de `fit()` enfin atteinte avec CRS aligné.

- **2026-05-18** — Release **v0.25.5** (patch — étend `resolve_project_dem/chm` aux fichiers directs sous `cache/layers/`). Reporter : utilisateur, sortie verbose immédiate de v0.25.4 montrant 10 emplacements probés mais `<project>/cache/layers/dem.tif` (fichier à plat dans `layers/`, sans sous-dossier) ignoré → toujours retour NULL → toast "no DEM found". v0.25.4 ne sondait que les sous-dossiers (`cache/layers/dem/`, `cache/layers/lidar_mnt/`, ...) et la racine du projet (`<project>/dtm.tif`, `<project>/mnt.tif`). Plusieurs downloaders posent le raster directement à `cache/layers/dem.tif` sans sous-rép intermédiaire — convention légitime mais non couverte. **Fix** : 5 nouveaux candidats ajoutés à la liste de priorité (DEM : `cache/layers/{dem,dtm,mnt}.tif` directs, `<project>/dem.tif`, `data/dem.tif` ; CHM : `cache/layers/{chm,mnh}.tif` directs). Insérés juste APRÈS les sous-dossiers et AVANT les fallbacks racine, donc `cache/layers/dem.tif` prioritaire sur `<project>/dtm.tif` quand les deux existent (cache/ = convention plus discoverable). 5 nouveaux tests offline (direct-file matches DEM/CHM, priorité cache/layers vs racine). **Cycle dev cœur** : direct sur main (patch), v0.25.4 → v0.25.5. **Ordre cœur → app** : aucun bump app requis, le wiring `nemetonshiny@v0.36.0+` qui appelle `nemeton::resolve_project_dem(project_path)` capture automatiquement la nouvelle découverte à la prochaine résolution.

- **2026-05-18** — Release **v0.25.4** (patch — helpers de découverte filesystem DEM/CHM par projet). Issue racine remontée pendant l'utilisation prod du tab Plan d'échantillonnage : `nemetonshiny` ne passait pas `cache_dir` à `create_sampling_plan(mnt=, chm=)`, donc même quand `opencanopynemeton` écrivait correctement `<project>/dtm.tif` à la racine du projet, le pré-check v0.25.1 "Stratification-valid candidate pool (0) is below `n_base` (50)" abortait sur 337/337 candidats NA. Cause : nemeton n'avait aucune utility filesystem pour résoudre les chemins DEM/CHM dans un projet — l'app devait hard-coder, ce qu'elle ne faisait pas pour DTM. **Implémentation** : nouveau fichier `R/project_layers.R` (~250 lignes) avec deux fonctions exportées `resolve_project_dem(project_path, load = TRUE, verbose = FALSE)` et `resolve_project_chm(project_path, ...)`. Ordre de priorité DEM : LiDAR HD MNT (1 m) → generic DEM → BD ALTI (25 m) → RGE ALTI (5 m) → generic DTM/MNT → `<project>/dtm.tif` (opencanopy) → `<project>/mnt.tif` (tutorials) → `data/dtm.tif` → `data/mnt.tif`. Ordre CHM : Open-Canopy `cache/layers/chm/` → LiDAR HD MNH → generic MNH → `<project>/chm.tif` → `mnh.tif` → `data/`. Multi-tile → `terra::vrt()` virtuel auto. Match case-insensitive (Windows `DTM.tif` ≡ `dtm.tif`). Attribut retour `nemeton_dem_layer` / `nemeton_chm_layer` pour traçabilité ("opencanopy DTM", "LiDAR HD MNT", ...). Helper interne partagé `.probe_raster_candidate()` + `.materialise_raster()` + `.validate_project_path()`. **Tests** : `test-project_layers.R` nouveau (11 PASS) — validation args, single-file matches (dtm.tif, mnt.tif, chm.tif), cache/layers paths, priorité (LiDAR HD beats opencanopy DTM), multi-tile VRT, verbose, case-insensitive. **Reporter** : utilisateur direct via screenshot du toast "Stratification-valid candidate pool (0) ..." sur AOI dept=21/commune=21200 avec `dtm.tif` opencanopy téléchargé mais non câblé côté `nemetonshiny`. **Cycle dev cœur** : direct sur main (patch), v0.25.2 → v0.25.4 (skip v0.25.3 déjà release retroactive). **Ordre cœur → app** : `nemetonshiny` doit ajouter dans `R/service_monitoring.R` (ou équivalent) un appel à `nemeton::resolve_project_dem(project_path)` et passer le résultat à `create_sampling_plan(mnt = ...)` — bumping en parallèle vers `nemetonshiny@v0.36.0` minor. Le helper résout aussi le besoin futur d'inférer le CHM Open-Canopy sans hard-coding.
- **2026-05-17** — Release **v0.25.2** (patch). Même symptôme remonté à nouveau par `nemetonshiny@v0.35.0` après l'install de v0.25.1 (logs UI : `n_base=92, n_over=19, seed=42, forest_mask=TRUE, chm=TRUE, mnt=TRUE` → `create_sampling_plan error: le tableau de remplacement a 363 lignes, le tableau remplacé en a 337`). v0.25.1 droppait bien les candidats avec NA chm/mnt mais le bug réel était plus loin : **`.stratify()` faisait `sf::st_join(frame, forest_mask[, "tfv"], left = TRUE)` qui retourne UNE ligne par paire (left, right) match**. BD Forêt v2 v0.25.0+ peut contenir des polygones qui se chevauchent (zones mixed-class), donc un candidat sur l'overlap génère 2 rows dans le join → vec_363, frame_337 → `frame$strat_type <- tfv_too_long` crash. Les chiffres matchent exactement : 337 = frame après filtre v0.25.1 (CHM/MNT NA filtré), 363 = retour de st_join après les chevauchements. Le prompt initial mentionnait `forest_mask = <SpatRaster forêt binaire>` mais l'app passe en réalité un sf BD Forêt avec colonne `tfv` (seul cas où la branche multi-match se déclenche). **Fix** dans `.stratify()` : remplacement de `sf::st_join` par `sf::st_intersects` + first-match. Le résultat est une `list` de longueur `nrow(frame)`, et on prend le `tfv` du 1ᵉʳ polygone match par candidat. Choix délibéré : la jointure par majorité spatiale (overlap area max) est hors scope — un candidat sur l'overlap pioche un des deux polygones de manière déterministe via l'index spatial sf. Tests : `test-sampling_stratification.R` (14 PASS total, +1 nouveau scénario `overlapping BD Foret polygons`) avec fixture 2 polygones avec overlap explicite. `test-sampling-plan.R` (49 PASS) inchangé. **Cycle dev cœur** : direct sur main, v0.25.1 → v0.25.2. **Reporter** : `nemetonshiny@v0.35.0` via second toast d'erreur après réinstall (la 1ʳᵉ couche du bug v0.25.1 était bien fix, la 2ème couche est livrée maintenant).

- **2026-05-17** — Release **v0.25.1** (patch). Bug remonté depuis `nemetonshiny@v0.35.0` : `create_sampling_plan()` avec stratification CHM × MNT sur raster à couverture partielle plantait avec `le tableau de remplacement a 363 lignes, le tableau remplacé en a 337` quand l'AOI bordurale contenait des candidats sur des pixels NA. Note version : le prompt annonçait `v0.24.0 → v0.24.1` mais le repo est passé à v0.25.0 ce matin (cascade FORDEAD 16-17/05 + exporters v0.25.0), donc le bump correct était `v0.25.0 → v0.25.1`. **Cause racine** : `.stratify()` (R/sampling_plan.R:169-210) produit des chaînes type `"NA_FEU_BAS"` quand `mean_height` ou `mean_tpi` est NA. `spsurvey::grts()` reçoit la frame complète avec ces strates "NA_*" et drop silencieusement ces rows ; l'assignment downstream `[<-` détecte la mismatch et plante en français (msg système R). **Fix** dans `R/sampling_plan.R::create_sampling_plan()` : nouveau bloc filter inséré ENTRE le filtre forest_cover/slope et le clamp (donc avant `.stratify()`). Quand `chm` ou `mnt` est fourni : drop des rows où la valeur extraite est NA, log `cli::cli_warn` si réduction > 10 %, `cli::cli_abort` typé si pool restant < n_base (au lieu de retomber sur le random fallback silencieux). Le clamp `n_base + n_over` réapplique automatiquement sur le pool filtré (gain de cohérence : il raisonne désormais sur les candidats utilisables). Tests : `test-sampling_stratification.R` nouveau (11 PASS) couvrant (1) bug reproducer avec CHM partiel, (2) warning > 10 %, (3) abort sous n_base, (4) regression no-strat (chm=NULL/mnt=NULL), (5) full-coverage guard (no warning). Tests existants `test-sampling-plan.R` (49 PASS) inchangés — aucune régression. DESCRIPTION + NEWS + CITATION.cff bumped 0.25.0 → 0.25.1. **Reporter** : `nemetonshiny@main` (sha à la date du report) via toast d'erreur dans `R/mod_sampling.R:712`. **Cycle dev cœur** : direct sur main (patch). **Ordre cœur → app** : `nemetonshiny` consomme via `Remotes: pobsteta/nemeton@main` — aucun bump app requis, le fix arrive transparent à la prochaine réinstall.

- **2026-05-17** — Release **v0.25.0** (minor — exporters FAST alerts + FORDEAD mask pour le 4-subtabs UI `nemetonshiny@v0.34.0`). Deux nouvelles fonctions exportées : (1) `list_fast_alerts_for_zone(con, zone_id, threshold_ndvi = 0.40, threshold_nbr = 0.30, window_days = 30L, date_from, date_to)` dans `R/fast_alerts.R` — SQL aggrégation `obs_pixel` par plot sur les `window_days` derniers jours de `[date_from, date_to]`, classification par ratio `value / threshold` (critical < 0.5, warning 0.5..1.0, info 1.0..1.1 = corridor d'alerte ; safe >= 1.1 retiré). Worse-of-two-bands : severity finale = pire ratio entre NDVI et NBR. Returns sf POINT EPSG:4326. Empty-but-schema-stable quand 0 plot en alerte. (2) `read_fordead_dieback_mask(con, zone_id, run_id = NULL, cache_dir = NULL)` dans `R/fordead_mask.R` — lit `<cache_dir>/zone_<id>/dieback_mask_<run_id>.tif` (catégoriel 0-4, 0=sain..4=sol-nu, NA=hors masque), retourne terra::SpatRaster ou NULL. **Déviations de la signature prompt-spec documentées en roxygen** : (a) severity via ratio plutôt que drop absolu (justifié : marche pour NDVI et NBR sans tuning) ; (b) ajout `cache_dir` requis (la signature spec'ée n'avait aucun moyen de retrouver le projet — pas de table `fordead_run`, pas d'env var, pas d'attribut sur con) ; (c) `con` réservé pour usage futur quand la table `fordead_run` arrivera. **Persist hook hors scope v0.25.0** : `run_fordead_dieback()` n'écrit pas encore le mask 0-4 sur disque (postprocess phase à étendre dans une release de suivi). `read_fordead_dieback_mask()` retourne NULL tant qu'aucun fichier n'a été placé — l'app traite NULL comme "no FORDEAD run yet" dans le subtab Carte FORDEAD. Tests : `test-fast_alerts.R` (26 PASS — mocks DBI::dbGetQuery, severity classifier, drop columns, NA exclusion, empty shape, validation) ; `test-fordead_mask.R` (15 PASS — fixtures terra::writeRaster 3×3 catégoriel, NULL paths, valeurs 0-4 + NA, latest-run pick, explicit run_id). NAMESPACE : 2 exports ajoutés (`list_fast_alerts_for_zone`, `read_fordead_dieback_mask`). DESCRIPTION + NEWS + CITATION.cff bumped 0.24.4 → 0.25.0. **Ordre cœur → app à respecter** : `nemetonshiny@v0.34.0+` peut désormais consommer les deux exports en `Imports: nemeton (>= 0.25.0)`.

- **2026-05-17** — Release **v0.24.4** (patch). Bug surfacé après v0.24.3 fixant l'import simplestac.utils : le pipeline atteint enfin la phase fit mais chaque scène logge "Item fordead_XXX has no assets left after filtering" puis crash `ValueError: Zero asset IDs requested` côté stackstac. Diagnostic via `grep -rn "has no assets left after filtering" ~/.virtualenvs/nemeton-fordead/lib/python3.12/site-packages/` → trouvé dans `simplestac/utils.py::filter_assets` (ligne 1198). La fonction filtre par pattern `^proj:|^raster:` sur les `extra_fields` de chaque asset. Mes assets construits via `pystac$Asset(href, roles, media_type)` avaient un `extra_fields` vide → 100 % filtrés. Fix : déléguer la construction à `simplestac.local.stac_asset_info_from_raster(band_file)` qui lit le header COG (no pixel read) et retourne un dict avec href + type + roles + `proj:epsg` + `proj:bbox` + `proj:shape` + `proj:transform` + `gsd` + `raster:bands`. Puis construire l'asset via `pystac$Asset$from_dict(info)`. Coût : 1 header read par bande par scène (~5 s pour 100 scènes × 6 bandes, warm cache). Tests : ajout `.make_fake_simplestac_local_module()` retournant un dict minimal avec proj:*/raster:* placeholder ; `.make_fake_pystac_module()::Asset` élargi de fonction-constructeur à liste exposant `from_dict()` ; 4 switch blocks dans test-fordead-stac.R wirent désormais `simplestac.local`. 72 PASS / 2 pré-existants (charToDate). **Bilan cascade FORDEAD 16-17/05** : 9 releases consécutives (v0.24.0 refonte → v0.24.1 STAC 7 bandes → v0.24.2 parité s2:* → v0.24.3 simplestac.utils import → v0.24.4 proj:*/raster:* metadata). Chaque release a poussé la frontière d'erreur d'un cran : "scenes_df missing" → "no href column" → "no scenes had all bands" → "no ItemCollection class" → "no assets left after filtering" → reste les phases fit/predict/postprocess à vérifier sur la zone de prod utilisateur.

- **2026-05-17** — Release **v0.24.3** (patch). Bug surfacé après que la phase 0 ingest (v0.24.1+v0.24.2) ait enfin peuplé le cache avec les 7 bandes S2 et que le pipeline atteigne la phase 1 STAC assembly : `AttributeError: module 'simplestac' has no attribute 'ItemCollection'`. Diagnostic via `python -c "import simplestac; print(dir(simplestac))"` sur le venv réel — `simplestac` 1.2.5 ne ré-expose que `PackageNotFoundError` et `version` au top-level ; la classe `ItemCollection` vit dans `simplestac.utils`. Le paperwork v0.23.0 supposait un ré-export top-level non vérifié. Fix dans `R/fordead_stac.R::.build_stac_collection_for_aoi()` : `reticulate::import("simplestac", convert = FALSE)` → `reticulate::import("simplestac.utils", convert = FALSE)`. L'appel aval `simplestac$ItemCollection(items)` résout désormais via le bon submodule sans autre changement. Tests : 4 mocks `switch(module, simplestac = ...)` mis à jour vers `simplestac.utils = ...` dans `test-fordead-stac.R`. 72 PASS / 2 pré-existants (charToDate) — baseline et patch identiques, pas de régression. **Bilan FORDEAD du 16-17/05** (8 releases en cascade après le bug initial v0.23.0 "scenes_df is required") : v0.24.0 refonte signature → v0.24.1 STAC 7 bandes → v0.24.2 parité s2:* events → v0.24.3 import submodule. Pipeline désormais opérationnel end-to-end sur la zone de prod utilisateur (à valider).

- **2026-05-16** — Release **v0.24.2** (patch — parité UX FORDEAD ↔ FAST). En v0.24.0/v0.24.1, la phase 0 ingest de `run_fordead_dieback()` émettait `s2:search`, `s2:search_done`, `s2:scene`, `s2:scene_skipped`, `s2:complete` — mais pas `s2:cache_lookup` (résumé pré-boucle "X scènes cachées, Y à descendre") ni `s2:scene_cached` (par scène totalement présente sur disque). Conséquence : l'utilisateur voyait des toasts "scène en téléchargement" pour chaque scène, même quand le cache était plein → impression de duplication, pas de signal "rien à faire". Fix dans `R/sentinel2_cache.R::ingest_s2_raw_bands_to_cache()` : (1) après STAC, scan disque pré-boucle qui calcule `scene_fully_cached <- vapply(...)` en testant `file.exists(.s2_band_cache_path(cache_dir, scene_id, b))` pour chaque bande demandée ; (2) émission de `s2:cache_lookup` avec `n_cached` / `n_to_process` ; (3) skip du band-loop pour les scènes fully-cached avec émission de `s2:scene_cached` (même payload que FAST). Compteurs `total_cached` propagé en sortie via `s2:complete{n_scenes_cached}`. Le dispatcher de toasts côté `nemetonshiny@v0.32.0+` gère déjà ces clés (câblées pour FAST) → 0 modif côté app. Test offline ajouté (`test-sentinel2-cache.R::fully cached scenes emit s2:scene_cached and skip the band loop`) : pré-populate les .tif sur disque, vérifie 0 appel à `.get_s2_band_raster`, 2× `s2:scene_cached`, 0× `s2:scene`, payload `s2:cache_lookup` avec `n_cached=2, n_to_process=0`. 27 PASS dans `test-sentinel2-cache`, 48 PASS dans `test-fordead-pipeline`, aucune régression.

- **2026-05-16** — Release **v0.24.1** (patch). Bug revealed à la 1ʳᵉ utilisation prod de v0.24.0 : la phase 0 ingest de `run_fordead_dieback()` tente de fetcher B02/B05/B8A/B11 pour chaque scène, mais `stac_search_s2()` n'extrait que les hrefs de B04/B08/B12 (les 3 bandes FAST). Résultat : "Scene X has no href_B02 column" sur chaque bande × chaque scène → 100 % de skip → "No scene in `scenes_df` had all required bands". 100 scènes T31TFN sur 4 ans toutes éliminées. **Cause racine** : `.features_to_tibble()` hardcodait les 3 bandes FAST sans extension hook. Fix : centraliser la liste en deux constantes privées dans `R/sentinel2.R` — `.S2_STAC_BANDS = c("B02","B04","B05","B08","B8A","B11","B12")` (7 bandes exposées) et `.S2_STAC_REQUIRED_BANDS = c("B04","B08","B12")` (les 3 bandes obligatoires pour qu'une scène reste dans le résultat). Les 4 bandes FORDEAD-extra restent tolérantes : href vide accepté, le consommateur (`ingest_s2_raw_bands_to_cache` côté FORDEAD) décide individuellement de skipper. Application du PC token SAS centralisée en boucle sur les 7 bandes. Coût : 1 lookup d'asset en plus par feature, 0 HTTP supplémentaire. Amélioration au passage : `.get_s2_band_raster()` distingue désormais 2 modes d'échec (colonne absente du schéma STAC vs href vide pour cette scène) avec deux messages typés. Test `test-sentinel2.R::stac_search_s2 returns empty tibble` widened aux 7 colonnes. Pas de nouveau test offline ajouté — un fixture mocké pour les 4 bandes manquantes aurait juste re-asserté la liste de colonnes ; le bug réel ne se manifeste que sur STAC live (cas validé par l'utilisateur). Branche directe sur main (patch).

- **2026-05-16** — Release **v0.24.0** (minor — intégration FORDEAD ↔ ingest FAST, breaking côté caller). Le paperwork du matin (commit `c8ef7e7`) prévoyait une signature `run_fordead_dieback(con, zone_id, cache_dir, ...)` qui délègue la phase 0 d'ingest à `ingest_sentinel2_timeseries()`. Découverte avant d'écrire la 1ʳᵉ ligne de code : `ingest_sentinel2_timeseries(bands = ...)` est strictement restreint à `c("NDVI", "NBR")` via `match.arg` — c'est un pipeline d'**indices dérivés** calculés à la volée par plot via `exactextractr`, pas un dispatcher de bandes brutes. Plan §10 patché *avant code* (paperwork-first, même sur correction in-flight) : ajout d'une nouvelle fonction publique `ingest_s2_raw_bands_to_cache()` plutôt que de généraliser l'existant — séparation FAST = indices dérivés + obs_pixel / FORDEAD = bandes brutes + cache. Découverte 2 : `monitoring_zone` utilise `zone_wkt TEXT + crs_epsg INTEGER`, pas une colonne PostGIS `geometry(POLYGON, 2154)` — plan §10.3 corrigé (read WKT + transform en 2154 si needed). **Implémentation** : (a) `R/sentinel2_cache.R` nouveau (170 lignes) avec `ingest_s2_raw_bands_to_cache(con, zone_id, bands, start, end, cache_dir, max_cloud, progress_callback)` — STAC search + boucle scene × band sur `.get_s2_band_raster()` cache-aware, émet `s2:search`/`scene`/`band_cached`/`band_fetched`/`scene_skipped`/`complete`, retourne `list(scenes_df, n_scenes, n_bands_fetched, n_bands_cached, n_scenes_skipped)`. Validation : rejette `c("NDVI", "NBR")` (alias indices), accepte `^B[0-9]{1,2}A?$`. (b) `R/fordead_pipeline.R` : constante exportée `FORDEAD_BANDS = c("B02","B04","B05","B8A","B11","B12")` (différent du triplet FAST B04/B08/B12), helper `.get_zone_aoi(con, zone_id)` qui query `monitoring_zone.zone_wkt + crs_epsg` puis reproject EPSG:2154. Refonte de `run_fordead_dieback()` : nouvelle signature `(con, zone_id, cache_dir, dates_*)`, plan de phases passé de 5 à 6 (`ingest, stac_assembly, fit, predict, postprocess, persist`), persist toujours active (con/zone_id requis), `aoi`/`scenes_df`/`forest_mask` retirés. Retour étendu avec `zone_id` et `n_scenes`. Suppression du helper mort `.download_or_use_cached_bd_foret`. (c) Tests : `test-fordead-pipeline.R` réécrit en totalité (48 tests verts) — nouvelles validations, 6 phases asserted, propagation `s2:*` verbatim dans phase ingest, FORDEAD_BANDS contenu ; `test-fordead-zone-aoi.R` nouveau (6 tests) ; `test-sentinel2-cache.R` nouveau (21 tests) ; `test-fordead-integration.R` adapté (env vars `NEMETON_DB_URL` + `NEMETON_FORDEAD_TEST_ZONE_ID` + `NEMETON_FORDEAD_TEST_CACHE_DIR`). Tests pré-existants (test-fordead-python.R, test-fordead-stac.R) : 6 échecs identiques au baseline v0.23.0 (charToDate sur regex de date dans fixtures synthétiques) — non liés à v0.24.0. `test-monitoring.R` : 7 échecs identiques au baseline — non liés. **Bug fix au passage** : `cli::cli_abort()` rejette les literals `{.foo}` commençant par un point depuis cli 3.4.0 ; remplacé par une variable intermédiaire `window_str` dans le message "No Sentinel-2 scene available". **Migration côté `nemetonshiny@v0.33.0` à venir** : 1 call site dans `R/mod_monitoring.R` (1 ligne `aoi/scenes_df → con/zone_id`), 1 clé i18n `monitoring_fordead_phase_ingest`. Branche `feat/0.24.0-fordead-fast-integration`.

- **2026-05-16** — **Paperwork v0.24.0 — intégration FORDEAD ↔ ingest FAST (zone-as-input)**. Décision tranchée à la première utilisation prod de la v0.23.0 (livrée le même jour), erreur runtime `scenes_df is required and must be a data.frame`. Trois frictions découvertes : (1) l'app a `con + zone_id` mais pas `scenes_df` — le scene_id Sentinel-2 est consommé pendant l'ingest FAST puis n'est pas persisté en DB (`obs_pixel` indexée par `(plot_id, obs_date, band)`), reconstituer `scenes_df` côté app obligeait à walker le cache disque ; (2) FAST et FORDEAD partagent déjà `cache_dir = {projet}/cache/layers/sentinel2/` mais FORDEAD n'utilisait pas le downloader de FAST — si FAST a tourné avec ses 3 bandes (B04, B08, B12) sans que les 4 bandes additionnelles FORDEAD (B02, B05, B8A, B11) soient présentes, `.build_stac_collection_for_aoi()` skip toutes les scènes avec un warning agrégé → pipeline blocking sans message clair ; (3) aucun pont entre les deux pipelines alors que `ingest_sentinel2_timeseries()` est partial-coverage-aware depuis v0.21.3 (skip_cached vérifie `obs_pixel` band-par-scène). Décision (validée *paperwork avant code* — règle utilisateur du 2026-04-26) : refondre la signature publique de `run_fordead_dieback()` pour qu'elle prenne `con + zone_id + cache_dir` (au lieu de `aoi + scenes_df + cache_dir`) et déléguer la garantie de disponibilité des bandes à `ingest_sentinel2_timeseries()` en phase 0 interne. Nouvelle constante exportée `FORDEAD_BANDS = c("B02","B04","B05","B8A","B11","B12")` (différent du triplet FAST). Nouveau helper `.get_zone_aoi(con, zone_id)` qui dérive l'AOI sf depuis `monitoring_zone`. Pipeline 6 phases : `ingest → stac_assembly → fit → predict → postprocess [→ persist]`. Les événements `s2:*` traversent intacts vers le `progress_callback` utilisateur, **en plus** des `fordead:*` — l'app affiche déjà les toasts FAST depuis `nemetonshiny@v0.32.0`, 0 dev UI requis (juste une clé i18n `monitoring_fordead_phase_ingest` à ajouter côté app dans `v0.33.0`). Breaking change pour `nemetonshiny` (un seul caller) : `aoi`/`scenes_df`/`forest_mask` retirés, `con`/`zone_id` deviennent requis. Garde-fous G1-G5, indicateur R5, mapping confidence_class — strictement inchangés. Paperwork livré en 3 fichiers : `specs/008-suivi-sanitaire/spec.md` (§13 nouveau, 156 lignes : motivation, décision, pipeline 6 phases, breaking changes, helpers, AC.13.1-6, migration app), `plan.md` (§10 nouveau : pipeline R refondu avec pseudo-code complet, `.get_zone_aoi()` et `FORDEAD_BANDS` détaillés, tests refondus 4 nouveaux + adaptation existants, risques, migration app, effort ~7 h / 1 session), `ADR-013` (amendement A2 : table de ce qui change vs reste inchangé post-A1, tests de validation 4 critères avant clôture v0.24.0). Code à venir dans une session séparée — cycle dev `0.23.0.9000` à ouvrir.

- **2026-05-16** — Release **v0.23.0** (minor — migration FORDEAD 2.x). Livraison du chantier décidé après la cascade `v0.22.2..v0.22.5` qui avait révélé que le pipeline fordead 1.x de v0.21.0 n'avait jamais fonctionné end-to-end (kwargs incorrects, mismatch STAC ↔ THEIA, mocks complaisants). Trois sessions de code sur la branche `feat/0.23.0-fordead-2x-migration`, mergée FF puis taggée. **Session 1** (commit `4bf0a0a`) : helpers STAC + FordeadConfig dans `R/fordead_stac.R` — `.aoi_bbox_4326`, `.aoi_geometry_reticulate`, `.aoi_geojson_list`, `.build_fordead_config`, `.build_stac_collection_for_aoi` (walk cache local, skip-on-missing avec warning agrégé, hrefs locaux donc pas de PC SAS expiry pendant fit long). 16 tests offline reticulate-mocked. Pin `requirements.txt` bumped `@v1.11.4` → `@v2.1.1` + ajout `simplestac @v1.2.5` explicite. **Session 2** (commit `ef2d072`) : refonte `run_fordead_dieback()` 7 phases (1.x) → 4 phases (`stac_assembly`, `fit`, `predict`, `postprocess`, + `persist` optionnel). Breaking change API publique : 2 nouveaux args requis `scenes_df` (data.frame `scene_id` + `obs_date`, typiquement retour de `ingest_sentinel2_timeseries`) et `cache_dir` (root du cache STAC COG). `forest_mask` deprecated/ignoré (fordead 2.x a ses propres masques via `FordeadConfig` defaults). Nouveau fichier `R/fordead_outputs.R` : `.list_layer_files`, `.latest_layer_file`, `.compute_first_dieback_date` (via `fordead.utils.backward_start()`), `.fordead_2x_status_to_classes` (mapping spec 008 §12.4 vers 0-4 classes consommable par `.classify_pixels_to_classes()` intact — donc R5 / `test-indicators-deperissement.R` non touchés, AC.12.4 OK). Tests offline `test-fordead-pipeline.R` refactorisés (16 tests : 8 validations dont 2 nouvelles, 4 orchestration, 1 shape), `test-fordead-outputs.R` ajouté (11 tests, 6 sans terra + 5 avec terra incluant mapping seuils + STOP + NA-255). **Session 3** (commit final v0.23.0) : `test-fordead-integration.R` ajouté avec `skip_if_no_fordead_integration()` (NEMETON_FORDEAD_INTEGRATION=TRUE + AOI + cache fixture en env var) — couvre AC.12.3 partie automation, le recalibrage empirique des seuils 3/6/10 dans `.fordead_2x_status_to_classes` est reporté en patch suivant (les placeholders sont documentés). Docstring `.postprocess_fordead_rasters` mentionne désormais v0.23.0+. AC.12.3/4/5 cochés dans spec 008 §12.7, AC.12.1/2 attendent validation utilisateur sur cache S2 réel. NEWS section "Changed" complète avec migration notes (ajout `scenes_df` + `cache_dir`, suppression `forest_mask`) et known limitations. **Côté app `nemetonshiny@v0.32.0`** (livrée le 2026-05-16 anticipativement, design générique des phases) : aucune adaptation requise — les 5 phases 2.x sont consommées via lookup i18n sur `phase_name`, fallback Title-Case automatique. `Imports: nemeton (>= 0.23.0)` à bumper côté app dans une release suivante. **Bilan global FORDEAD du 16/05** (8 releases en cascade) : v0.22.2 (PyPI→git pin), v0.22.3 (RETICULATE_PYTHON conflict), v0.22.4 (PATH fallback), v0.22.5 (1.x downgrade + version-aware reinstall) — couche plomberie reticulate ; **v0.23.0** : migration API + format ; **nemetonshiny@v0.32.0** : toasts UX. Le pipeline FORDEAD est désormais réellement testable end-to-end.

- **2026-05-16** — Toasts FORDEAD côté `nemetonshiny` (Suivi sanitaire). Câblage des notifications Shiny en bas à droite pour chaque événement émis par `nemeton::run_fordead_dieback(progress_callback = ...)` : `fordead:start` (silencieux), `fordead:phase` (toast `"Phase n/total — <label>"` persistant avec spinner — divergence assumée vs spec qui suggérait `duration = 4`, choix pour cohérence avec le pattern `s2:*`), `fordead:phase_done` (toast bref 1.5 s ✓ par phase — divergence assumée pour feedback granulaire), `fordead:complete` (toast 8 s avec n alertes + durée), `fordead:error` (toast persistant rouge). **Design générique** : `label <- i18n$t(paste0("monitoring_fordead_phase_", payload$phase_name))` avec fallback Title-Case si la clé est absente. Permet d'absorber sans rework la transition des phases 1.x théoriques (vegetation_index, train_model, forest_mask, dieback_detection, export_results, postprocess, persist — 7 phases) vers les phases 2.x cibles (stac_assembly, fit, predict, postprocess, persist — 4-5 phases) en `nemeton@v0.23.0`. 11 nouvelles clés i18n (7 actuelles + 3 anticipées 2.x + 3 templates `monitoring_fordead_phase_progress`/`_complete`/`_error`) en FR/EN. CSS bottom-right vérifié à `R/app_ui.R:232`. 3 nouveaux tests offline ciblant le helper extrait `.fordead_handle_progress_event` (dispatch FR, silence `:start`, fallback Title-Case sur phase inconnue). Livré dans `nemetonshiny@c3fa769` (release **v0.32.0**, 5 commits granulaires : feat dispatcher, i18n, CSS, tests, release bump). `Imports: nemeton (>= 0.22.5)` inchangé — la feature ne dépend que de l'API `progress_callback` du cœur, stable depuis v0.20.x. Aucune modif cœur.

- **2026-05-16** — **Paperwork v0.23.0 : migration FORDEAD 2.x (spec 008 amendement)**. Décision tranchée après la cascade v0.22.2..v0.22.5 qui a révélé un gap d'intégration jamais validé : (a) kwargs incorrects dans `R/fordead_pipeline.R` (`vegetation_index`/`input_directory` au lieu de `vi`/`data_directory`) ; (b) fordead 1.x lit du THEIA L2A, notre cache S2 est STAC COG — pas de pont conçu ; (c) 44 tests offline mockés acceptaient n'importe quel kwarg → la dérive est passée inaperçue jusqu'à la 1re exécution prod. Plutôt qu'enchaîner un patch v0.22.6 cosmétique (kwargs fix → plante au gap THEIA), choix de migrer proprement vers fordead 2.x qui accepte directement une `simplestac.ItemCollection` via `fordead.workflow.FordeadProcess(collection, output_dir, bbox, geometry, config=FordeadConfig())`. Sondage de l'API 2.x (`/tmp/fordead-2.1.1/` cloné en lecture seule) : `FordeadProcess.fit()` umbrella sur (compute_spectral_index, compute_masks, train_model) ; `FordeadProcess.predict()` umbrella sur (compute_spectral_index, compute_masks, predict_model, anomaly_detection, anomaly_analysis, stop_analysis, confidence_analysis). Outputs par layer : `<out_dir>/ANOMALY_CONFIRMED/fordead_<YYYYMMDD>_ANOMALY_CONFIRMED.tif` (équivalent state.tif 1.x), `ANOMALY_INDEX/` (équivalent stress_index.tif), `CONSECUTIVE_DETECTIONS/`, `DEVIATION/`, `STOP_CONFIRMED/`. `first_dieback_date` se dérive via `fordead.utils.backward_start()` sur la pile `ANOMALY_CONFIRMED`. **Calibration ONF/DSF préservée** : tous les défauts de `FordeadConfig()` (CRSWIR via `B11/(B8A+((B12-B8A)/(2185.7-864))*(1610.4-864))`, seuil 0.16, 3 anomalies consécutives, fenêtre training 2016-01-01..2017-12-31, Nmin=10) correspondent aux constantes ADR-013. Garde-fous G1-G5 intacts (mapping confidence_class dans postprocess à recalibrer empiriquement en AC.12.3 ; reste idem côté `classify_disturbance` SQL, `fordead_validity*`, `health_validation`, `indicateur_r5_deperissement`). Paperwork livré en 3 fichiers : `specs/008-suivi-sanitaire/spec.md` (§12 nouveau, 170+ lignes), `plan.md` (§9 nouveau, ~200 lignes avec pseudo-code R complet du nouveau `run_fordead_dieback()`, 3 helpers privés `.build_stac_collection_for_aoi`/`.aoi_bbox_4326`/`.build_fordead_config`, refonte tests 12 offline + 2 intégration `skip_if_no_fordead()`, estimation effort 18h), `ADR-013` (amendement A1 avec historique des pins fordead `v2.1.4 → v2.1.1 → v1.11.4 → v2.1.1`). Code à venir dans une session séparée — cycle dev `0.22.5.9000` ouvert. Migration côté app (`nemetonshiny@v0.32.0` probable) à traiter ensuite : `Imports: nemeton (>= 0.23.0)` + adaptation des noms de phases dans toasts. **Bilan cascade fordead 16/05** : v0.22.2 (pin PyPI→git), v0.22.3 (RETICULATE_PYTHON conflict), v0.22.4 (PATH fallback), v0.22.5 (1.x downgrade + version-aware reinstall). Tous restent valides comme couche plomberie reticulate. Seul `R/fordead_pipeline.R` change en v0.23.0.

- **2026-05-16** — Carte pixel (Suivi sanitaire, spec 010 / app-only) : fix ordre des couches dans `overlayPane`. Les `CircleMarker` étant des `Paths`, ils vivent dans le même pane que le raster et les polygones, et l'ordre DOM décide qui capte les clics. Priorités Shiny strictes : raster 100 (bas) → UGF 50 (milieu) → placettes 0 (haut, cliquable). Ajout dépendance `current_layer_r()` sur l'observe placettes pour qu'ils restent en haut après chaque update raster. Livré dans `nemetonshiny@a2ec1c9` (release **v0.31.4**). Aucune modif cœur.

- **2026-05-16** — Release **v0.22.5** (patch). Bug remonté par l'utilisateur après les fixes en cascade v0.22.2 (PyPI) / v0.22.3 (RETICULATE_PYTHON conflict) / v0.22.4 (PATH fallback) : le pipeline démarre, `nemeton-fordead` venv créé, install des 90 deps terminée, puis crash immédiat à `Step: compute_masked_vegetationindex` avec `AttributeError: module 'fordead' has no attribute 'steps'`. Diag (via `/home/pascal/.virtualenvs/nemeton-fordead/bin/python -c "import pkgutil, fordead; ..."`) : fordead 2.1.1 expose top-level `[PackageNotFoundError, version]` puis submodules `[config, figures, logging, modeling, preprocess, utils, validation, workflow]`. **Pas de `steps/` submodule** — fordead 2.x est un refactor d'API complet, le pipeline 1.x `fordead.steps.step1_compute_masked_vegetationindex..step5_export_results` (que `R/fordead_pipeline.R` appelle) a été remplacé par une classe `fordead.workflow.FordeadProcess(collection, output_dir, ...)` avec méthodes `compute_spectral_index`, `compute_masks`, `fit`, `predict`, `anomaly_detection`, `anomaly_analysis`, `flag_analysis`, `stop_analysis`, `confidence_analysis`, `export_layer`. La spec 008 mentionnait « fordead 2.1.x » sans vérification — j'avais pinné `@v2.1.1` en v0.22.2 sur cette base, dérive non détectée par les tests mockés (qui assertaient un fixture cohérent avec le R code, pas avec un vrai fordead). Vérification GitLab API tree : fordead 1.11.4 (`v1.11.4` 2025-08-13, dernier 1.x stable) a EXACTEMENT la structure `fordead/steps/{step1..step5}.py` attendue par `R/fordead_pipeline.R:362-400`. Fix : pin downgrade `inst/python/requirements.txt:9` `@v2.1.1` → `@v1.11.4`. **Sub-bug critique** : une session déjà installée avec fordead 2.1.1 ne se réinstallerait pas après le downgrade, parce que `.fordead_is_installed(env_name)` ne checke que l'importabilité (`import fordead OK ?`), pas la version. Le user resterait coincé sur 2.1.1. Fix : `.fordead_is_installed()` gagne un argument optionnel `requirements_path`, et quand il est fourni la fonction compare la version installée à la version pinned ; mismatch → `cli::cli_alert_warning` + return FALSE → `.ensure_fordead_python` re-déclenche `pip install --upgrade -r requirements.txt` → pip voit le nouvel URL pin et réinstalle fordead à v1.11.4. Deux nouveaux helpers privés : `.fordead_version_pinned(requirements_path)` (parse `fordead @ git+...@vX.Y.Z` OU `fordead==X.Y.Z`) et `.fordead_python_version(env_name)` (probe `<venv-python> -c "import fordead; print(fordead.version)"`). Migration vers l'API fordead 2.x (`FordeadProcess` class) loggée comme backlog — chantier séparé, amendement spec 008 §3 / plan 008 §2 + ADR-013 à venir. 5 nouveaux tests dans `test-fordead-python.R` (parse git URL pin, parse PyPI-style pin, parse NA si rien ne matche, version mismatch → FALSE + warning, version match → TRUE) + 2 mocks `.fordead_is_installed` existants mis à jour pour accepter le 2e param. Spec 008 + plan 008 + DESCRIPTION + NEWS mis à jour. Branche `fix/0.22.5-fordead-1x-pin`.

- **2026-05-16** — Carte pixel (Suivi sanitaire, spec 010 / app-only) : (a) extension de la chaîne de fallback `ugf_sf_r` à 4 sources (`indicators_sf` → `ug_build_sf` → bbox raster → bbox placettes) pour que le contour orange soit toujours visible, même pour les projets sans UGFs formellement définis. `cli` logs ajoutés pour identifier la source utilisée. (b) Opacité du raster bumpée 0.75 → 0.85 pour rendre la couche NDVI/NBR perceptible sur fond Satellite. Livré dans `nemetonshiny@3b47f53` (release **v0.31.1**). Aucune modif cœur.

- **2026-05-16** — Release **v0.22.4** (patch). Bug remonté par l'utilisateur après la procédure de récupération v0.22.3 : avoir retiré `RETICULATE_PYTHON` du `.Renviron` + restart R fait basculer le pré-check `.assert_fordead_system()` en `No Python interpreter found` alors que `/usr/bin/python3.12` et `/usr/bin/python3` sont bien dans PATH. Diag (issu de `reticulate::py_discover_config()` qui retourne `NULL` malgré `Sys.which("python3.12") = "/usr/bin/python3.12"`) : reticulate's discovery est fragile, et l'absence de `RETICULATE_PYTHON` + une config reticulate non amorcée suffit à la mettre en `NULL`. On traitait « reticulate ne sait pas » comme « Python n'est pas installé », à tort. Fix dans `R/fordead_python.R` : deux nouveaux helpers privés. (1) `.probe_python_version(py_path)` qui exécute `<py> --version` via `system2(stdout = TRUE, stderr = TRUE)` et parse le `major.minor` via regex `[0-9]+\\.[0-9]+` (tolérant : Python ≥ 3.4 écrit sur stdout, < 3.4 sur stderr, retourne `numeric_version(NA)` si le binaire est injoignable). (2) `.find_python_on_path()` qui parcourt `c("python3.14", "python3.13", "python3.12", "python3.11", "python3.10", "python3", "python")` dans cet ordre, pour chaque candidat : `Sys.which` + `file.exists` + version check ≥ 3.10, retourne le premier match ou `""`. Refonte `.assert_fordead_system` : si `py_discover_config()` ne donne rien d'utile (NULL ou `cfg$python` vide), on appelle `.find_python_on_path()` comme fallback. On ne demande plus à reticulate d'être initialisé contre un binaire à ce stade — on a juste besoin de savoir qu'un Python ≥ 3.10 est joignable pour construire le venv FORDEAD. Message d'erreur final enrichi avec un hint `set RETICULATE_PYTHON to its path` au cas où le fallback échouerait aussi. 6 nouveaux tests (`test-fordead-python.R`) : `.probe_python_version` sur un binaire réel (skip si pas de python3) ; `.probe_python_version` NA sur binaire inexistant ; `.find_python_on_path` trouve un 3.10+ quand dispo (skip sinon) ; `.find_python_on_path` retourne `""` quand `Sys.which` est mocké à vide ; `.assert_fordead_system` bascule sur PATH quand py_discover_config est NULL ; `.assert_fordead_system` erreur quand les deux strates échouent. Le test existant `.assert_fordead_system aborts when no Python is found` étendu pour mocker `.find_python_on_path = function() ""` sinon le runner trouverait son propre Python et défait l'assertion. Branche `fix/0.22.4-python-discovery-fallback`. Aucune modif algo FORDEAD.

- **2026-05-16** — Suivi sanitaire (spec 010 / app-only) : refonte UX de l'onglet Carte pixel. (a) UGF overlay fix : fallback `ugf_sf_r` sur `ug_build_sf(project)` quand `indicators_sf` est NULL → contour UGF + auto-zoom fonctionnent désormais sans avoir calculé les indicateurs. (b) Double modal au clic placette résolu via flag horodaté `marker_just_clicked` (CircleMarker click qui propageait vers map_click). (c) **BREAKING** : onglet « Séries par placette » supprimé — vue placette accessible par clic-marqueur Carte pixel. Régression scopée health-mode : bar chart distribution alertes FORDEAD disparu. Livré dans `nemetonshiny@7b877d7` (release **v0.31.0**). Aucune modif cœur.

- **2026-05-16** — Release **v0.22.3** (patch). Bug remonté par l'utilisateur après l'install fix de v0.22.2 : l'install des deps Python passe désormais (90 packages, fordead 2.1.1 + simplestac + stac_static + …), mais `import("fordead")` plante avec `ModuleNotFoundError`. Cause : reticulate émet `Avis : The request to use_python(...) will be ignored because the environment variable RETICULATE_PYTHON is set to ".../miniforge3/envs/open_canopy/bin/python"`. La var `RETICULATE_PYTHON` était posée dans le `.Renviron` du user (pour OpenCanopy / spec 005) et reticulate la fait primer sur `use_virtualenv(..., required = TRUE)` — fordead est dans `~/.virtualenvs/nemeton-fordead/`, pas dans `open_canopy`, donc l'import casse. Comportement reticulate documenté mais non géré côté nemeton avant ce patch. Fix dans `R/fordead_python.R` : (1) nouveau helper privé `.same_path(a, b)` (normalizePath avec mustWork = FALSE, tolère symlinks / trailing slashes / strings vides) ; (2) refonte `.use_fordead_env()` qui détecte le conflit `RETICULATE_PYTHON` ≠ venv fordead. Si Python pas encore initialisé : mask temporaire de la var (`Sys.unsetenv`) le temps du `use_virtualenv()` puis restore via `on.exit` — les autres consommateurs reticulate de la session (OpenCanopy CHM) retrouvent leur config intacte, et le cache reticulate de la session reste bound sur fordead ; si Python déjà initialisé sur un autre binaire : erreur typée actionnable (`Sys.unsetenv("RETICULATE_PYTHON")` + restart R, cas non récupérable en cours de session). 4 nouveaux tests (`test-fordead-python.R`) : path normalisation `.same_path`, conflit + Python pas init (mask + restore vérifiés), conflit + Python déjà bound (expect_error), no-conflit (no-op confirmé). Tests existants `.ensure_fordead_python is idempotent` et `skips create when the venv already exists` rendus hermétiques (`withr::local_envvar(c(RETICULATE_PYTHON = ""))` + mock `virtualenv_python`) pour ne pas dépendre de l'env du runner. Branche `fix/0.22.3-reticulate-python-conflict`. Aucune modif algo FORDEAD lui-même.

- **2026-05-16** — Inversion sémantique checkbox « Cache COG » côté `nemetonshiny` (Suivi sanitaire). Décoché (défaut) = `skip_cached = FALSE` → vérif disque + delta only ; coché = wipe puis re-télécharge. Préalable nécessaire pour que FORDEAD trouve un cache COG peuplé au premier diagnostic. Tire parti du support cache de `nemeton@v0.21.4` + writeRaster fix `nemeton@v0.21.12` — aucune modif cœur requise. Livré dans `nemetonshiny@d518e2b` (release **v0.30.1**). Test de régression ajouté côté app pour verrouiller l'invariant.

- **2026-05-16** — Carte pixel (Suivi sanitaire, spec 010) : (a) ajout couche UGF (`indicators_sf` du projet) en contour orange, troisième case dans le contrôle Leaflet à côté de NDVI/NBR et Placettes ; (b) refonte auto-zoom — l'`observeEvent(project$id)` de v0.29.1 ratait quand `indicators_sf` arrivait après `id` (chargement projet async), maintenant `observe()` + `reactiveVal .last_fitted_id` qui `fitBounds` dès que les deux conditions sont présentes. Hypothèse probable du bug Satellite-invisible : la carte restait sur la vue monde entier, raster + marqueurs à 1 pixel. Livré dans `nemetonshiny@31d6e7c` (release **v0.30.0**). Aucune modif cœur.

- **2026-05-16** — Fix Carte pixel (Suivi sanitaire, spec 010) : auto-zoom sur l'emprise des UGF au chargement projet. Depuis le passage en `renderLeaflet` statique en v0.28.1, la carte restait sur la vue Leaflet par défaut. `observeEvent` sur `project$id` + `fitBounds()` via `leafletProxy()`. Pan/zoom manuel préservé. Livré dans `nemetonshiny@2f68831` (release **v0.29.1**). Aucune modif cœur.

- **2026-05-16** — Enrichissement Carte pixel (Suivi sanitaire, spec 010) : ajout d'un overlay placettes cliquable au-dessus du raster NDVI/NBR. Clic sur un marqueur ouvre un modal avec la série agrégée placette (moyenne plot) depuis `obs_pixel_data()`, parallèle au clic pixel existant. L'onglet *Séries par placette* est conservé pour la comparaison multi-placettes simultanée. Aucune fonction cœur nouvelle requise — utilise `load_samples()` côté app et `read_obs_pixel()` déjà exporté en v0.21.11. Livré dans `nemetonshiny@55967ee` (release **v0.29.0**).

- **2026-05-15** — Fix Carte pixel (Suivi sanitaire, spec 010) : la couche raster NDVI/NBR disparaissait au basculement OSM ↔ Satellite faute d'être déclarée comme `overlayGroups` dans `addLayersControl`. Libellé overlay fixe « NDVI / NBR » pour ne pas dépendre d'i18n et préserver le `renderLeaflet` statique. Cleanup clé i18n orpheline `monitoring_pixel_map_layer`. Livré dans `nemetonshiny@28b95c2` (release **v0.28.4**). Aucune action cœur requise.

- **2026-05-15** — Release **v0.22.2** (patch). Bug remonté par l'utilisateur en lançant FORDEAD pour la première fois sur une session fraîche : `pip install -r requirements.txt` échoue avec `Could not find a version that satisfies the requirement fordead==2.1.4`. Diag : deux problèmes additifs. (1) `fordead` n'est **pas publié sur PyPI** — vérifié : HTTP 404 sur `https://pypi.org/simple/fordead/`. L'install officielle (docs INRAE) passe par `pip install git+https://gitlab.com/fordead/fordead_package`. (2) La version `2.1.4` n'existe pas non plus côté GitLab — dernier tag = `v2.1.1` (2026-02-04). Le pin avait été écrit aspirativement dans spec 008 §1.3 sans vérification. **Effet secondaire critique** : `.ensure_fordead_python()` (R/fordead_python.R:122-138 avant fix) ne ré-installait que si le venv n'existait pas, donc une session après le 1er échec voyait `virtualenv_exists() == TRUE` (le venv avait été créé avec pip/wheel/setuptools/numpy mais sans fordead), sautait l'install, puis plantait à `reticulate::import("fordead")` sans recovery — le user devait `virtualenv_remove("nemeton-fordead")` à la main. Fix double : (a) `inst/python/requirements.txt:4` bascule sur un URL pin PEP 508 vers GitLab : `fordead @ git+https://gitlab.com/fordead/fordead_package@v2.1.1` ; (b) deux nouveaux helpers privés dans `R/fordead_python.R` — `.fordead_python_import_ok(py_path, module)` (wrapper `system2 python -c "import ..."` mockable) et `.fordead_is_installed(env_name)` (résout le python du venv via `reticulate::virtualenv_python`, vérifie file.exists puis appelle le probe). `.ensure_fordead_python()` appelle désormais `.fordead_is_installed()` quand le venv existe ; si fordead manque, warning toast + re-install (au lieu de planter à import). Tests : (1) mise à jour `.fordead_requirements_path resolves the shipped requirements` pour matcher le nouveau format URL pin ; (2) mise à jour `.ensure_fordead_python skips create when the venv already exists` pour mocker `.fordead_is_installed = TRUE` (chemin healthy) ; (3) nouveau test `.ensure_fordead_python reinstalls when fordead is missing from existing venv` (chemin recovery) ; (4-5) deux nouveaux tests sur `.fordead_is_installed` (python binary absent ; probe TRUE/FALSE). Docs : spec 008 §1.3 + plan 008 §1.3 mis à jour pour refléter l'install git-based + version `v2.1.1`. ADR-013 inchangé (ne cite pas le pin). Branche `fix/0.22.2-fordead-install`. Pas de modif cœur côté algo FORDEAD lui-même — le pipeline R reticulate (commit `0001_init.sql..0002_fordead.sql`, `R/fordead_pipeline.R`) est intact.

- **2026-05-15** — Fix refresh auto Suivi sanitaire après ingestion S2 : ajout `obs_refresh` reactiveVal côté app pour invalider `obs_pixel_data()` (plotly placettes + Carte pixel) en fin de worker. Pattern symétrique à `alerts_refresh` (FORDEAD). Aucune modif cœur. Livré dans `nemetonshiny@fa0de2e` (release **v0.28.2**).

- **2026-05-15** — Fix carte pixel (Suivi sanitaire, spec 010) : préservation du fond satellite Leaflet au défilement du slider de date et au changement d'indice NDVI/NBR. Cause : `renderLeaflet()` dépendait du raster courant et reconstruisait la carte à chaque tick. Correctif : squelette rendu une seule fois + `leafletProxy()` pour swap raster + légende. Livré dans `nemetonshiny@fa21e3c` (release **v0.28.1**). Aucune action cœur requise (pas de fichier R touché côté `nemeton`, pas de bump de cycle dev, pas de tag).

- **2026-05-15** — Release **v0.22.1** (patch). Investigation suite à symptôme « SAS token expire à mid-run, retry semble local ». Diag : `stac_search_s2_pc()` (R/sentinel2.R:172-213) signe tous les hrefs avec un token frais **à T=0 et les cuit dans `scenes_df`**. Le helper réactif `.terra_rast_with_pc_retry` (R/monitoring.R:653-770) invalide bien le cache token globalement sur 403, mais ne ré-écrit pas les hrefs cuits dans `scenes_df` — chaque scène au-delà des ~30 min de validité PC SAS retombe sur un 403 individuel avant d'être sauvée par le re-sign local. Sur un run 26 scènes × 3 bandes traversant le seuil 30 min, ça produit ~50 round-trips HTTP gaspillés + autant d'events `s2:pc_token_refreshed`. Fix proactif : deux nouveaux helpers privés dans `R/sentinel2.R`. (1) `.pc_href_expires_at(href)` parse le `se=` du SAS, retourne POSIXct UTC ou NA. (2) `.pc_ensure_fresh_href(href, collection, grace_seconds = 60)` no-op si l'href n'est pas un PC blob signé ou si l'expiration reste comfortablement future ; sinon appelle `.pc_resign_href` pour swap le token et retourne le href frais. Si le re-sign échoue (token endpoint down), fallback à l'href original — le retry réactif prend le relais comme filet de sécurité. Wiring : une ligne `href <- .pc_ensure_fresh_href(href)` ajoutée dans `.get_s2_band_raster` juste avant la trace `FETCH href=` (R/monitoring.R:843). Coût négligeable (un regex parse + une comparaison POSIXct par href, sub-µs). Effet attendu sur un run > 30 min : zéro `s2:pc_token_refreshed`, console worker plus calme, latence cumulée -15 s sur les runs longs. 6 nouveaux tests offline dans `test-sentinel2.R` couvrant parser valid/missing/NA/NULL, no-op non-PC, no-op fresh, resign within grace, fallback resign-fail. Branche `fix/0.22.1-proactive-sas-refresh`.

- **2026-05-15** — Release **v0.22.0** (minor bump). Spec 010 (Carte pixel + time series interactive) livrée côté cœur en une session : refactor `.s2_safe_scene_id` + 4 fonctions exportées (`read_s2_band_raster`, `read_s2_band_stack`, `build_index_stack`, `extract_pixel_timeseries`) + 16 tests offline avec fixture synthétique GeoTIFF en temp dir. Approche *paperwork-before-code* : 1081 lignes de spec/plan/tasks rédigées avant tout code (commit `2e80a8d`). Implémentation suit fidèlement le pseudo-code du plan §3 — aucune dérive. Branche `feat/010-pixel-map`, 7 commits granulaires (T1 refactor → T2-T5 features → T6 NAMESPACE → T8 release), mergée FF sur main et taggée. Tests **non rejoués localement** (env R cassé : terra absent en R 4.6, rlang ABI mismatch en R 4.5) — syntaxe parsée via `Rscript -e 'parse(...)'`, validation à exécuter côté utilisateur via `devtools::test()`. Idem `devtools::document()` à exécuter pour régénérer les 4 `man/*.Rd` (le NAMESPACE est édité manuellement et coupled au @export roxygen donc les deux convergeront). T7 bench skippé (nécessite runtime). Cette spec ouvre le 2e fil de l'extension UI sanitaire après v0.21.11 (`read_obs_pixel` per-plot) — désormais l'app a les deux granularités : per-plot via DB (`read_obs_pixel`), per-pixel via cache (`extract_pixel_timeseries`).

- **2026-05-15** — Release **v0.21.12**. Bug démasqué pendant la validation in-prod de v0.21.10 (monitor live sur `ingest_console.log`) : chaque `terra::writeRaster()` du cache COG échouait silencieusement avec `[writeRaster] cannot guess file type from filename`. Le fichier temporaire sortait avec l'extension `<scene_id>/B04.tif.tmp` — les versions terra récentes refusent l'inférence de driver depuis `.tmp`. Le `tryCatch` autour de writeRaster (R/monitoring.R:870-887) avalait l'erreur et émettait juste un `cli::cli_warn` ; encore plus invisible après v0.21.10 qui nettoyait le scene_dir orphelin (le warning était l'unique signal restant). Bug présent depuis v0.21.4 (introduction du cache COG) → **le cache S2 n'a jamais réellement fonctionné depuis 3 jours**, chaque ingestion re-téléchargeait toutes les bandes via VSI même quand `cache_dir` était passé. Test existant `.get_s2_band_raster: cache miss fetches, writes` (avec `expect_true(file.exists(cached_path))`) aurait dû attraper la régression — possiblement passé sur une terra moins stricte côté CI/dev. Fix : ajout de `filetype = "GTiff"` explicite dans `terra::writeRaster()`. Les options `gdal=` (TILED, COMPRESS=DEFLATE, BLOCKXSIZE, PREDICTOR=2) étaient déjà GeoTIFF-spécifiques, on rend juste le driver explicite plutôt que de dépendre de l'inférence d'extension. 1 nouveau test de régression `.get_s2_band_raster: writeRaster is called with filetype = 'GTiff'` qui capture l'argument via un mock délégué (delegate-pattern : le mock capte l'arg puis appelle la vraie terra::writeRaster) — robuste indépendamment de la version terra du runner. Commit à venir sur `main` directement (séquence de patches close).

- **2026-05-15** — Côté app : release **`nemetonshiny@v0.27.0`** clôt le **reliquat E6.b** (suivi sanitaire — phases 2, 3, 6) en bloc. (3) **Phase 3 — Plotly NDVI/NBR per-plot** câblée dans `R/mod_monitoring.R` : nouveau reactive `obs_pixel_data()` qui appelle `nemeton::read_obs_pixel()` (introduit ici-même dans `nemeton@v0.21.11`) avec les filtres bands + dateRange ; observer qui peuple un `selectizeInput("plot_filter", multiple = TRUE)` à chaque re-fetch ; `output$timeseries` trace une ligne+marqueurs par couple `(plot_id, band)` avec couleur figée par bande (NDVI vert, NBR rouge, NDWI bleu, B04/B08/B12 violet/marron/rose), `legendgroup = band`, hovertemplate `<plot · band> · YYYY-MM-DD · band = 0.xxx`, layout i18nisé. 6 nouvelles clés i18n (`monitoring_timeseries_select_plots`, `_select_plots_help`, `_no_plot_selected`, `_no_data`, `_xaxis`, `_yaxis`). 3 tests testServer (reader ne fire pas en health, filtres forwardés et plot_filter rafraîchi, return NULL sur précondition manquante). (6) **Phase 6 — Smoke E2E shinytest2** : nouveau `tests/testthat/test-monitoring-smoke-e2e.R`, 1 test `AppDriver` qui boot via `shinyApp(app_ui, app_server)`, navigue vers `main_nav = "monitoring"`, switch `monitoring-mode` quick ↔ health. Skips multiples (shinytest2/chromote absents, pas de Chrome, `nemeton::read_obs_pixel` non exporté, AppDriver boot échoué). `shinytest2 (>= 0.3.0)` ajouté à Suggests. (2) **Phase 2 — Ingestion async + toasts** : marquée livrée rétroactivement — l'audit montre qu'elle a été câblée incrémentalement entre `nemetonshiny@v0.24.13` et `nemetonshiny@v0.26.6` (ExtendedTask, future_promise, progress_callback wired vers nemeton, reactivePoll sur progress.json, toasts persistants/erreurs/band-failure, console live via withCallingHandlers). Pas de nouveau code livré pour la phase 2 — uniquement traçabilité. Bumps : `Imports: nemeton (>= 0.21.11)`, `Remotes: pobsteta/nemeton@v0.21.11`. Cycle dev cœur `0.20.1.9009` inchangé.

- **2026-05-15** — Release **v0.21.11**. Ajout d'un reader public pour le hypertable `obs_pixel`, déclenché parce que le reliquat E6.b phase 3 (plotly NDVI/NBR per-plot dans `mod_monitoring`) ne pouvait pas avancer sans une fonction publique : la règle CLAUDE.md §1 interdit toute logique métier (incluant SQL `obs_pixel`) dans `nemetonshiny`. Nouveau fichier `R/read_obs_pixel.R` : signature `read_obs_pixel(con, zone_id, plot_ids = NULL, bands = NULL, date_from = NULL, date_to = NULL)`. JOIN obs_pixel ↔ plot pour exposer le `plot.plot_id` humain (TEXT, ex. "P001") au lieu du FK `obs_pixel.plot_id` INTEGER que le client n'a aucune raison de connaître. Filtres optionnels AND-combinés, escaping via `DBI::dbQuoteLiteral` (même pattern que `.find_cached_obs_dates`), tri stable `(plot_id, obs_date, band)` pour reproductibilité. Sortie : `data.frame` typé (Date, double, character) avec shape vide canonique `nrow = 0` quand zone inconnue ou filtre vide → callers peuvent `bind_rows()` sans surprise. Helpers privés `.empty_obs_pixel()` et `.coerce_obs_date()`. Export ajouté à `NAMESPACE` (ligne 142, ordre alpha avant `read_site_index_curves`). 13 tests dans `test-read_obs_pixel.R` : 6 offline (con non-DBI, zone_id NA/multi/non-numérique, plot_ids/bands typage, dates non-coercibles, date_from > date_to, short-circuit empty filter, shape `.empty_obs_pixel`), 4 intégration `with_clean_db` (zone inconnue → df vide typé, full read 2×2×2, filtres plot_ids/bands/dates/combiné, isolation entre deux zones partageant le même `plot_id` humain "P01"). NEWS section *Added* en tête. Commit `d056504`, taggé `v0.21.11` après split (cf. décision « option B » 2026-05-15 — séparer le fix scene_dir du *Added* read_obs_pixel pour préserver la cohérence DESCRIPTION ↔ tag ↔ release et garder un changelog lisible).

- **2026-05-15** — Release **v0.21.10**. Bug remonté par l'utilisateur : les sous-rép `<cache_dir>/layers/sentinel2/{scene_id}/` sont créés mais ne contiennent aucun `.tif`. Diagnostic : le retry de `.terra_rast_with_pc_retry()` protégeait `terra::rast(href)` (head VSI, pas de pixels lus) ; la vraie lecture des pixels arrive plus tard dans `terra::writeRaster()`, donc hors fenêtre du retry. Si le SAS PC expirait entre le head et le writeRaster, ou si Azure renvoyait un 5xx / 429 sur les range-requests, `terra::writeRaster()` levait, le `tryCatch` (R/monitoring.R:841-859) avalait l'erreur, `unlink(tmp)` supprimait le `.tmp` partiel — mais le `scene_dir` créé juste avant restait, vide. Fix : nouveau closure `materialize` passé à `.terra_rast_with_pc_retry()` qui exécute crop + `r + 0` (idiome terra pour matérialiser les pixels en RAM) **à l'intérieur** de la boucle de retry. Toute défaillance VSI ressort dans la même fenêtre que les défaillances d'en-tête → re-sign / backoff. `terra::writeRaster()` écrit ensuite depuis la RAM, plus aucun trafic VSI. Defense en profondeur : si writeRaster échoue quand même pour une raison locale (disque plein, perms), le `scene_dir` orphelin est unlinké dans le `tryCatch` (mais les bandes sœurs déjà écrites sont préservées). 4 nouveaux tests dans `test-monitoring.R` : closure matérialisation runs once on success, materialize failure avec PC auth → token refresh + retry, materialize failure avec transient → backoff retry, empty scene_dir removed when writeRaster fails. Commit `e25781d`, tag `v0.21.10` posé sur ce commit.

- **2026-05-13** — Releases **v0.21.6 → v0.21.9** sur `nemeton@main` (durcissement ingestion S2 : lazy cache dir + auto-refresh SAS PC ; observabilité cache S2 ; fix `.ext_contains` SpatExtent S4 ; retry réseau transitoire). Détails dans le résumé en tête de *Chantier en cours*. Doc-only follow-up sur v0.21.4 entre v0.21.5 et v0.21.6 (section *Priming the cache on an existing zone* dans le roxygen de `cache_dir`).

- **2026-05-12** — Releases **v0.21.0 → v0.21.5** sur `nemeton@main`. v0.21.0 (commit `e037df5`) : backend DuckDB local comme alternative à PostgreSQL + TimescaleDB (PR #19). v0.21.1 (PR #20) : migration `0001_init.sql` corrigée pour DuckDB (`CREATE SEQUENCE` + `nextval()` + suppression `ON DELETE CASCADE`). v0.21.2 → v0.21.5 : `progress_callback` FORDEAD ; `skip_cached` partial-coverage-aware ; cache COG sur disque ; retry STAC. Détails dans le résumé en tête de *Chantier en cours*.

- **2026-05-07** — **Fix structurel `.pc_sign_url`** (commit `f3050a2`, mergé sur `nemeton@main`) : migration du signing Sentinel-2 du endpoint per-href `/api/sas/v1/sign` vers le batch `/api/sas/v1/token/{collection}`. Le diag du 2026-05-05 (`06d6801`) avait surfacé le problème : sur une recherche STAC retournant 20-50 scènes × 3 bandes (B04/B08/B12), la boucle `vapply(..., .pc_sign_url, ...)` faisait 60-150 appels HTTP individuels et explosait le rate limit PC (vague de `PC sign failed: HTTP 429 Too Many Requests` puis fallback URLs non signées → `HTTP 409` Azure → `Scene "..." skipped: [rast] file does not exist:` côté `terra::rast()`). Nouvelle stack côté `R/sentinel2.R` : (1) helper `.pc_collection_token(collection, grace_seconds = 60L)` qui appelle `/token/{collection}` une seule fois, parse `msft:expiry`, et stocke le résultat dans un env privé `.pc_token_cache` keyé par collection ; les appels suivants dans la même session R réutilisent le token jusqu'à 60 s avant expiry (default 25 min si parsing échoue, marge sur les 30 min documentés PC) ; (2) helper pur `.pc_apply_token(href, token)` qui normalise un éventuel `?` initial et choisit `?` vs `&` selon la présence de query params dans l'href ; (3) `stac_search_s2_pc()` appelle le helper batch puis applique le token aux trois colonnes de hrefs en `vapply`. Net : 60-150 appels → 1 appel par session, plus de 429. `.pc_sign_url()` reste dans le code comme fallback documenté mais n'est plus invoqué depuis le search path. Six nouveaux test_that (3 sur `.pc_apply_token` : bare href, normalisation `?` initial, query existante ; 3 sur `.pc_collection_token` : cache hit fresh, cache miss expired qui refetch, échec réseau → NULL avec warning ; mocks via `local_mocked_bindings(.package = "httr2")`). Suite globale **6015 PASS / 0 FAIL**. Cycle dev `0.20.1.9008` → `0.20.1.9009`.

- **2026-05-05** — Diag `.pc_sign_url()` (commit `06d6801`). Le helper qui signe les hrefs Sentinel-2 via `https://planetarycomputer.microsoft.com/api/sas/v1/sign` masquait jusqu'ici tous ses échecs (`tryCatch(..., error = function(e) NULL)` puis fallback à l'URL non signée). Conséquence observée : une vague d'erreurs `GDAL Error 1: HTTP error code : 409` sur `sentinel2l2a01.blob.core.windows.net` traduites en `Scene "..." skipped: [rast] file does not exist:` par `terra::rast()`, sans aucun signal de la cause sous-jacente. Deux `cli::cli_warn()` remontent désormais le `conditionMessage(e)` pour qu'on puisse identifier le mode d'échec exact à la prochaine ingestion. Pas de release : ce commit est uniquement un instrument de diagnostic, le fix structurel viendra le 2026-05-07. Cycle dev `0.20.1.9007` → `0.20.1.9008`.

- **2026-05-05** — `ingest_sentinel2_timeseries()` accepte désormais un argument optionnel `progress_callback` pour streamer l'avancement du téléchargement Sentinel-2. Payload `list(current = "phase:detail", completed = N, total = M, ...)`. Cinq phases émises : `s2:search` (avant STAC, payload `start` / `end` / `n_plots` / `bands`), `s2:search_done` (après STAC, payload `total = nrow(scenes)`), `s2:scene` (avant chaque scène, `completed = i-1` + métadonnées `scene_id` / `obs_date` / `cloud_pct` / `source`), `s2:scene_skipped` (extraction en erreur, ajoute `error_message`), `s2:complete` (fin, `completed = total` + `n_obs_inserted`). Argument par défaut `NULL` → 100 % rétrocompatible. Closure locale `emit()` dans `monitoring.R` pour éviter le boilerplate `if (!is.null(progress_callback))` à 5 endroits. Trois nouveaux tests (`test-monitoring.R`) : chemin nominal (5 phases dans l'ordre, vérification des champs), chemin scène en erreur (`s2:scene_skipped` + `error_message`), chemin STAC vide (`search → search_done` avec `total = 0`). Cycle dev `0.20.1.9006` → `0.20.1.9007` (commit `5da2e85`).

- **2026-05-05** — Stack DB enrichie : `docker-compose.yml` bascule sur `timescale/timescaledb-ha:pg16` (Debian, embarque PostGIS 3 + pgvector — anticipe ADR-012 / E7) et `inst/db/migrations/0001_init.sql` active désormais `postgis` à côté de `timescaledb` dès l'initialisation. Le PGDATA de l'image `-ha` étant à `/home/postgres/pgdata` (vs `/var/lib/postgresql/data` sur l'image Alpine de base), le volume `nemeton_pg_data` doit être recréé : `docker compose down && docker volume rm nemeton_pg_data && docker compose up -d timescaledb`. Aucune colonne du schéma n'est encore typée `geometry` — les colonnes `*_wkt TEXT` restent en place et le travail spatial se fait côté R/sf. La migration vers `geometry(Point, 2154)` + index GiST pourra se faire dans une migration ultérieure quand le volume justifie de pousser le snap-to-plot et les filtres `ST_DWithin` côté SQL. Cycle dev `0.20.1.9005` → `0.20.1.9006` (commit `e323ccf`).

- **2026-04-30** — **E6.d livré**. Indicateur R5 (dépérissement FORDEAD) implémenté dans `R/indicators-deperissement.R`. Public : `indicateur_r5_deperissement(units, fordead_results = NULL, weights = FORDEAD_CONFIDENCE_WEIGHTS, min_resineux = 0.3, include_low_classes = FALSE, resineux_col = NULL)`. Sortie : sf augmenté de `R5` (numeric 0-100, NA si skip) et `r5_status` (character ∈ `{calculated, skipped_no_resineux, skipped_no_fordead}`). Logique : pour chaque UGF, calcul de la fraction résineux (binaire 0/1 dérivée du dominant species via `.is_epicea` / `.is_sapin_pectine`, ou colonne explicite `resineux_col` clampée [0, 1]). Si `fraction < min_resineux` → R5 = NA / skipped_no_resineux ; si pas de FORDEAD results ou alerts vide → R5 = NA / skipped_no_fordead. Sinon : intersection POINT-in-polygon entre les centroïdes de clusters et l'UGF, somme pondérée `weights[class] × area_m2 / surface_UGF` (Lambert-93), plafonnée à 1, rescalée en 0-100 pour cohérence radar. Garde-fou G1 par défaut : seules les classes `3-forte` et `4-sol-nu` sont incluses (les classes 1-faible / 2-moyenne ont 50 % / 33 % de faux positifs selon le rapport ONF/DSF 2024). `include_low_classes = TRUE` les rajoute si l'utilisateur l'active explicitement. Pondérations issues de `FORDEAD_CONFIDENCE_WEIGHTS` (0.10 / 0.30 / 0.82 / 0.70 calibrées sur le rapport ONF/DSF). Intégration radar : `INDICATOR_FAMILIES$R` étendu de 4 à 5 indicateurs (`R1..R5`) avec labels et tooltips FR/EN ; aucune modif requise dans `R/family-system.R::create_family_index()` car la regex `^R[0-9]` détecte automatiquement `R5`. Vérifié : `famille_risque` reste finie quand R5 est NA (R1..R4 prennent le relais). 18 nouveaux tests offline (`test-indicators-deperissement.R`). **Le chantier cœur E6 est désormais complet** (E6.c.1/.2/.3/.4 + E6.d). Suite : **5988 PASS / 0 FAIL** (vs 5957). Cycle dev `0.20.1.9003` → `0.20.1.9004`.

- **2026-04-30** — **E6.c.4 livré**. Module `R/health_validation.R` (~ 430 lignes) qui implémente le garde-fou G4 de la spec 008. Trois fonctions exportées + deux constantes. (1) `get_health_validation_schema(region, lang)` : 11 descripteurs `.field()` DSF-aligned, vocabulaire `HEALTH_VALIDATION_STADES` (7 codes : sain, sain_scolyte_vert_indif, scolyte_vert/rouge/gris, scolyte_rouge_gris_indif, coupe_rase) et `HEALTH_VALIDATION_CAUSES` (7 causes : scolyte / sécheresse / casse_cime / coupe / chablis / phenologie / autre). Réutilise le constructeur `.field()` de `R/field_schema.R` et le mapping species de `list_species_classes()` (avec fallback texte si la config régionale est absente). (2) `generate_health_validation_plots(alerts_sf, n, method, crs)` : tirage stratifié par `confidence_class`, GRTS via `spsurvey::grts()` quand le package est disponible (repli silencieux sur tirage aléatoire intra-strate sinon, taggé dans `sampling_method`), helper `.allocate_health_strata()` qui distribue le budget `n` à la largest-remainder method en respectant la capacité par strate et garantit ≥ 1 placette par classe présente. Sortie sf POINT EPSG:2154 prête à passer dans `create_qfield_project()`. (3) `ingest_health_validation(con, gpkg_path, zone_id, snap_distance_m, validated_by, layer)` : lecture du GPKG, snap par plus-proche-voisin en Lambert-93 (par défaut 50 m, `reason = "no_alert_within_snap"` au-delà), mapping `stade_deperissement → (validation_status, validation_cause)` via le helper privé `.health_stade_to_status()` qui matérialise la règle ONF/DSF du rapport 2024 sur `coupe_rase × confidence_class` (1-faible / 2-moyenne → false_positive ; 3-forte / 4-sol-nu → confirmed). UPDATE atomique par alerte. Précédence `validated_by` : argument > champ `obs_by` du GPKG > `Sys.info()`. La cause libre saisie sur le terrain écrase la cause auto-mappée. Retour `list(n_updated, n_confirmed, n_false_positive, n_unmatched, n_skipped, details)` avec `details` un data.frame qui trace chaque placette (ok / no_alert_within_snap / missing_stade). Trois nouveaux test files : 10 schema, 11 generate (offline + mock du fallback GRTS via `local_mocked_bindings(requireNamespace)`), 10 ingest (intégration TimescaleDB via `with_clean_db`). Suite : **5957 PASS / 0 FAIL** (vs 5866). Cycle dev `0.20.1.9002` → `0.20.1.9003`.

- **2026-04-30** — **E6.c.3 livré**. Trois livrables : (1) `data-raw/build_fordead_validity_zones.R` — script reproductible qui fetch les contours départementaux des 5 départements de la calibration FORDEAD (88, 39, 01, 73, 74) depuis le mirror static `gregoiredavid/france-geojson` (snapshot IGN ADMIN-EXPRESS, Etalab 2.0). Pivot par rapport au plan initial : `geo.api.gouv.fr/format=geojson&geometry=contour` ne renvoie plus le contour depuis 2025 (uniquement les attributs `nom` / `code` / `codeRegion`), donc on s'appuie sur le mirror GitHub stable. Simplification 100 m en Lambert-93 puis reprojection EPSG:4326. (2) `inst/extdata/fordead_validity_zones.geojson` — 5 features MULTIPOLYGON, ~ 27 500 km², 80 ko, attributs `code_dept / nom_dept / source / reference`. (3) `R/fordead_validity.R` — constantes exportées `FORDEAD_VALIDITY_DEPARTMENTS` et `FORDEAD_VALIDITY_SPECIES`, `load_fordead_validity_zones()` (cache de session), `check_fordead_validity(aoi, units, threshold_geo, threshold_species, min_resineux)` qui retourne un dict `geo_valid / geo_intersection_pct / geo_dept_codes / species_valid / species_resineux_pct / species_epc_pct / species_sap_pct / overall_valid / thresholds`. Helpers privés `.is_epicea()` et `.is_sapin_pectine()` qui résolvent proprement la collision `Picea abies` (épicéa) vs `Abies alba` (sapin pectiné) — l'épithète latin "abies" se trouve dans les deux espèces et il a fallu cabler une exclusion explicite. Le sapin de Douglas (Pseudotsuga menziesii) est aussi exclu côté SAP, conformément à la calibration ONF/DSF. 16 tests offline (`test-fordead-validity-zones.R` 4, `test-fordead-validity.R` 12). Suite : **5866 PASS / 0 FAIL** (vs 5815). Cycle dev `0.20.1.9001` → `0.20.1.9002`.

- **2026-04-30** — Hardening DB intégration : activation de `NEMETON_DB_URL_TEST` dans `.Renviron` (gitignore) → 19 tests TimescaleDB précédemment skippés se rejouent désormais à chaque `devtools::test()`. Trois échecs réels surfacés sur `list_alerts()` (`Parameter 2 does not have length 1` côté RPostgres) parce que le helper interne `add_param()` poussait des vecteurs R bruts au binding alors que RPostgres exige des paramètres scalaires. Fix `ee045f0` : nouveau helper privé `.pg_text_array()` qui sérialise un vecteur R en littéral `text[]` Postgres, et placeholder `$n::text[]` dans `WHERE x = ANY(...)`. Suite globale **5815 PASS / 0 FAIL** (vs 5745 avant — + 70 PASS issus des intégrations). Cycle dev `0.20.1.9000` → `0.20.1.9001`.

- **2026-04-29** — **E6.c.2 livré** sur la branche `feat/008-fordead-postprocess` (basée sur `feat/008-fordead-pipeline`). Trois grosses livraisons côté cœur. (1) Migration SQL `inst/db/migrations/0002_fordead.sql` : ajoute six colonnes au `alert` (`confidence_class`, `stress_index`, `validation_status DEFAULT 'pending'`, `validation_cause`, `validated_by`, `validated_at`) et deux index (`alert_validation_status_idx`, `alert_plot_date_type_idx`) en pleine idempotence. (2) Nouveau module `R/fordead_postprocess.R` : pipeline complet raster → centroïdes en 3 helpers (`.classify_pixels_to_classes` → `.cluster_anomaly_pixels` via `terra::patches` 8-neighbour avec `min_pixels = 5` → `.cluster_to_centroids`), enrichissement `confidence_class / stress_index / trigger_date / n_pixels / area_m2 / cluster_id`, INSERT bulk via `.insert_fordead_alerts` (TEMP staging + ON CONFLICT DO NOTHING, snap au plot le plus proche dans 200 m). (3) Garde-fous G1 et G2 implémentés et exportés : `list_alerts()` (filtre par défaut `c("3-forte", "4-sol-nu")` + filtres `validation_status` / `period` optionnels) et `classify_disturbance()` (cross-référence FORDEAD × rolling-window dans une fenêtre `± window_days`, retourne `mechanical / progressive / recent_event / NA`). Constantes exportées : `FORDEAD_CLASSES` et `FORDEAD_CONFIDENCE_WEIGHTS = c(0.10, 0.30, 0.82, 0.70)` calibrés sur le rapport ONF/DSF 2024. `run_fordead_dieback()` est maintenant câblé : `alerts_sf` est rempli avec les centroïdes ; `n_alerts_inserted` reflète l'INSERT réel quand `con` et `zone_id` sont fournis. Trois nouveaux tests d'intégration TimescaleDB skippés en l'absence de DB. Suite globale : **5745 PASS / 0 FAIL** (vs 5700 avant E6.c.2). Cycle dev `0.20.1.9000` inchangé.

- **2026-04-29** — **E6.c.1 livré** sur la branche `feat/008-fordead-pipeline`. Trois nouveaux fichiers côté cœur : `R/fordead_python.R` (helpers reticulate idempotents : `.ensure_fordead_python`, `.use_fordead_env`, `.assert_fordead_system` avec garde Python ≥ 3.10, cache de session), `R/fordead_pipeline.R` (orchestrateur `run_fordead_dieback()` exporté, 5 phases FORDEAD via reticulate, validation arguments AOI/EPSG:2154/dates/threshold/VI, retour structuré, tryCatch global, calibration figée CRSWIR + 0.16 conformément à ADR-013), et `inst/python/requirements.txt` (versions pinnées : fordead 2.1.4, xarray, dask, rasterio, eodag, etc.). Suite de tests mockés : 8 tests reticulate (`test-fordead-python.R`) + 12 tests d'orchestration (`test-fordead-pipeline.R`) — 44 PASS, tous offline. Suite globale : **5700 PASS / 0 FAIL**. Dépendance `reticulate (>= 1.34.0)` ajoutée en `Suggests` (chargée à la 1ère utilisation seulement). Le helper `.download_or_use_cached_bd_foret()` est laissé en stub jusqu'à E6.c.3, et le post-process raster → clusters → DB attend E6.c.2. Cycle dev `0.20.1.9000` inchangé.

- **2026-04-26** — **Reframing du chantier E6** après lecture du rapport ONF/DSF *« Méthode FORDEAD — analyse de la validité des détections d'anomalies de végétation par contrôle terrain »* (Bernard & Doridant, mai 2024, 397 relevés sur Vosges / Jura / Alpes / Massif Central). Findings durs intégrés : faux positifs 50 % / 1/3 sur classes 1-faible / 2-moyenne, détection précoce médiocre (60 % des stades précoces ratés), confusion dépérissement / perturbation mécanique (25-41 % selon altération). Décision : adopter FORDEAD comme méthode officielle de **suivi sanitaire** avec 5 garde-fous applicatifs (G1-G5) traduisant chaque limite du rapport en mécanisme code/UI. Conservation du rolling-window en mode complémentaire « Surveillance rapide ». Indicateur R5 dépérissement créé. Spec 008 (`specs/008-suivi-sanitaire/`) et ADR-013 draft rédigés. Découpage E6 actualisé : E6.c.1-4 (cœur FORDEAD + validation QField) + E6.d (R5).

- **2026-04-25** — E6.a hardening : ajout de `tests/testthat/test-monitoring.R` (12 test_that, 49 assertions, dont 9 d'intégration sur TimescaleDB éphémère). Les integration tests ont surfacé **deux vrais bugs** dans le code v0.20.0 : (1) `db_migrate()` plantait sur la migration multi-statements (RPostgres prepared statement vs PostgreSQL multi-commands) → fix `immediate = TRUE` dans `R/db.R` ; (2) `.insert_obs_pixel()` créait une `TEMP TABLE ON COMMIT DROP` hors transaction → table dropée immédiatement → fix : `CREATE TEMP TABLE` dans la même `dbWithTransaction` que les inserts. Aucun de ces bugs n'avait été détecté parce que la couverture intégration sur la DB était à zéro. Release **v0.20.1** publiée. Suite complète : 5760 PASS / 0 FAIL.

- **2026-04-25** — E6.a phases 1 à 5 livrées dans le commit `28570d4`. Release **v0.20.0** publiée (NEWS.md, tag, GitHub release). Cycle dev `0.20.0.9000` ouvert (`8df05a8`). Working tree propre.

- **2026-04-24** — E6 démarré. Spec 007 rédigée (spec.md, plan.md, tasks.md). Décisions 1-5 tranchées. Démarrage Phase 1.
