# Cadrage — Crop à l'ingestion S2 (spec 021, optimisation disque)

**Statut** : cadrage (paperwork avant code) — 2026-06-27
**Pré-requis** : L2b.2 ingestion (v0.94.x) + crop AOI post-extraction
(`reconfort_crop.R`, spec 021 v0.94.2) livrés.
**Cible** : `nemeton` v0.95.0 (changement de contrat de `reconfort_ingest_s2()`
→ bump **mineur**).
**Contexte** : amende le cadrage L2b (`L2b-cadrage.md`, D1). Pas d'ADR nouveau :
optimisation interne au contexte **Santé** (spec 021 / ADR-013), aucune
dépendance/méthode/contexte nouveau.

---

## 1. Déclencheur

Incident réel **2026-06-27** (zone 5 Mouthe, tuile T31UFQ) : `S2 unzip failed
(exit 1)`. Cause = **disque plein** (`OSError [Errno 28]`). L'ingestion
matérialise séquentiellement, pour une tuile entière sur 2 ans :

| Couche | Taille (T31UFQ, 140 scènes) |
|--------|------|
| Archives `.zip` (GEODES, tuile entière) | ~211 GB |
| Scènes extraites full-tile (`extracted/<tile>/`) | ~250 GB |
| Crop AOI (`extracted_aoi/<tile>/`, **ce qu'IOTA² consomme vraiment**) | ~quelques centaines de Mo |

Soit **~460 GB transitoires pour ~60 pixels utiles**. Le crop AOI
(`.reconfort_crop_scenes_to_aoi`) n'intervient qu'**après** l'extraction
full-tile complète → il réduit le résultat, pas le pic disque.

Palliatifs déjà livrés en **v0.94.3** (PR #123) : extract-then-delete des zips
+ garde-fou pré-vol espace disque. Ils **plafonnent** le pic (~250 GB) mais ne
**suppriment** pas la couche full-tile. Ce chantier la supprime.

---

## 2. Décisions cadrées (2026-06-27)

| # | Question | Décision |
|---|----------|----------|
| C1 | Ambition disque | **Option B — interleave par date**. Pour chaque date S2 : télécharger 1 archive → extraire → cropper AOI → supprimer (archive + extrait full-tile). Pic disque ≈ 1 archive (~1.5 GB) + 1 scène extraite transitoire (~2 GB) + crops AOI cumulés (~Mo) ≈ **quelques GB** au lieu de ~460 GB. |
| C2 | Placement du crop | **En R** : la boucle par date est orchestrée depuis R (règle stricte « pas de métier dans le python vendoré »). Réutilise `.reconfort_crop_scenes_to_aoi` décliné **par scène**. Le python vendoré ne fait plus que **lister** puis **télécharger une archive**. |
| C3 | Plancher GEODES | GEODES ne livre **pas** de sous-tuile spatiale : l'archive MUSCATE est tuile-entière (~1.5 GB). On ne peut donc pas descendre sous ~1 archive en transit — d'où l'interleave (et non un download bulk pré-réduit). |
| C4 | Contrat API | `reconfort_ingest_s2()` devient **AOI-aware streaming** : nouvel argument `aoi` (+ `target_crs`, `buffer_m`). Quand `aoi` est fourni → ingestion par date avec crop ; quand `aoi = NULL` → **comportement v0.94.x préservé** (full-tile, bulk). Rétrocompatible. |
| C5 | Idempotence | La présence du **crop AOI d'une date** (`extracted/<tile>/<scene>/`) vaut cache : une re-run saute les dates déjà cropées (le cache zip pygeodes, lui, disparaît — acceptable, les crops sont la donnée utile). |

---

## 3. Architecture cible (Option B, R-driven)

```
reconfort_ingest_s2(aoi=, tiles=, date_from, date_to, s2_root, …)
  │
  ▼ pour chaque tuile :
  │    1. LIST   python list_s2_items.py  → manifeste JSON {date, item_id}[]   (1 search GEODES)
  │    2. fenêtre AOI = .reconfort_aoi_window(aoi, target_crs, buffer_m)        (R)
  │    3. pour chaque item du manifeste (boucle R) :
  │         a. si crop AOI de la date déjà présent → skip (idempotence C5)
  │         b. DOWNLOAD  python download_s2_item.py --item <id>  → 1 zip dans tmp
  │         c. EXTRACT   R: unzip(zip) → scène full-tile dans tmp
  │         d. CROP      R: .reconfort_crop_scene_to_aoi(scène, win) → extracted/<tile>/<scene>/
  │         e. CLEAN     R: unlink(zip) ; unlink(scène full-tile tmp)
  │
  ▼ retourne list(tiles, s2_root, extracted)   (extracted = dirs AOI, inchangé pour l'aval)
```

**Le layout de sortie est identique** à aujourd'hui (`extracted/<tile>/<scene>/`
+ `MASKS/` + XML), donc `.reconfort_stage_s2_layout` et IOTA² ne changent pas.
La différence : les scènes sont **déjà AOI-cropées et reprojetées** (EPSG:2154)
en sortie d'ingestion. Le `do_crop` séparé de `reconfort_pipeline.R` PHASE 5
**disparaît** (fondu dans l'ingest).

---

## 4. Découpage en sous-tâches

| Lot | Tâche | Livrable |
|-----|-------|----------|
| **K1** | **Manifeste** : script python `list_s2_items.py` (search GEODES, émet `{date, item_id, archive_name}[]` en JSON sur stdout) + helper R `.reconfort_list_s2_items()` qui le lance et parse. Vendor NOTE. | reader R + script |
| **K2** | **Download par item** : script python `download_s2_item.py` (télécharge **une** archive par id dans un dir donné) OU réutilisation de `run_geodes_download.py` avec `start=end=date` (à trancher en impl : 1 search/jour vs 1 search global). | script + helper R |
| **K3** | **Crop par scène** : factoriser `.reconfort_crop_scenes_to_aoi` → `.reconfort_crop_scene_to_aoi(scene_dir, win, out_dir, target_crs)` (déjà per-scene en interne, extraire la boucle). | refactor R |
| **K4** | **Boucle d'ingestion streaming** dans `reconfort_ingest_s2()` : nouvel arg `aoi`/`target_crs`/`buffer_m` ; orchestration LIST→(DL→EXTRACT→CROP→CLEAN) ; idempotence C5 ; garde-fou disque réajusté (le besoin tombe à ~3–5 GB). | R + `.Rd` à la main |
| **K5** | **Câblage pipeline** : `reconfort_pipeline.R` PHASE 5 passe `aoi` à l'ingest et **retire** l'appel `do_crop`/`.reconfort_crop_scenes_to_aoi` séparé (conservé pour le chemin `skip_ingest` si besoin). | R |
| **K6** | **Tests** : unzip+crop+delete par date (mock download → drop d'un faux zip ; vérifier extrait AOI présent, zip + scène full-tile supprimés, idempotence skip). Garde-fou disque inchangé. NEWS/CITATION/PLAN, bump **0.95.0**. | tests + release |

**Le chemin `aoi = NULL`** (ingest standalone full-tile) garde tous les tests
v0.94.x verts : extract-then-delete + garde-fou disque conservés tels quels.

---

## 5. Risques / réserves

- **R1 — coût des searches GEODES.** Si K2 fait 1 search/jour (140 searches),
  surcoût réseau + risque rate-limit. *Mitigation* : 1 seul search global (K1)
  qui produit le manifeste, puis download par item-id (pas de re-search). À
  trancher selon l'API pygeodes (`download_item_archive` prend un objet item :
  le manifeste doit donc soit re-matérialiser l'item, soit le download script
  re-search par id — bench en impl).
- **R2 — perte du cache zip pygeodes.** L'interleave supprime les zips →
  re-run re-télécharge les dates non encore cropées. Acceptable (les crops AOI,
  petits, sont la donnée persistée et servent de cache C5). À documenter.
- **R3 — robustesse par date.** Une archive corrompue / connexion coupée
  (`except` nu amont) sur une date ne doit pas tuer la tuile entière : la
  boucle R doit **logguer + continuer**, et abort en fin de tuile seulement si
  trop de dates manquent (seuil à fixer, ex. ≥ 1 scène utile par an).
- **R4 — `extracted/` vs `extracted_aoi/`.** Aujourd'hui le crop écrit dans
  `extracted_aoi/`. En streaming, l'ingest écrit directement le crop dans
  `extracted/<tile>/`. Vérifier que `skip_ingest` (qui lit `extracted/`) reste
  cohérent (il lira désormais des scènes déjà cropées — correct).
- **R5 — fenêtre AOI multi-tuiles.** Une AOID à cheval sur 2 tuiles : la
  fenêtre AOI est commune, chaque tuile cropée à la même fenêtre, mosaïquage
  aval inchangé (déjà géré par le multi-tile e2e existant).

---

## 6. Disque : avant / après (T31UFQ, 140 scènes)

| | Pic disque transitoire | Persisté (IOTA²) |
|--|--|--|
| v0.94.2 (crop post-extraction) | **~460 GB** | ~Mo (`extracted_aoi`) |
| v0.94.3 (extract-then-delete + garde-fou) | **~250 GB** | ~Mo |
| **v0.95.0 (ce chantier, Option B)** | **~3–5 GB** | ~Mo |

---

## 7. Prochaine étape

**Validation de ce cadrage par Pascal** avant d'écrire le code (règle
paperwork-first). Une fois validé : implémenter K1→K6, un commit par lot
cohérent, PR unique vers `main`, release CI **v0.95.0**.
