# Spec 029 — MUSCATE comme source S2 de repli du pipeline FAST/FORDEAD

**Version** : 0.1.0
**Date**    : 2026-07-02
**Statut**  : Implémentée (K1–K4) — décisions A/B actées, **D1–D6 confirmées
par smoke réel le 2026-07-02** (collection `sentinel2-l2a-theia`, bandes
`B02/B04/…` FRE, offset 0, `eo:cloud_cover`). Reste K5 (release v0.111.0).
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` (feat mineur, API rétro-compatible → `0.111.0`).
**Cible app**  : aucune (repli automatique, invisible côté UI en v1).
**Liens** : clôt le reliquat « Sources Theia » (`s2_l2a_muscate`, PLAN.md
§ Chantier clos Theia) ; étend le sous-système STAC S2 (specs 013/017) ;
s'inscrit dans ADR-008 (sources par pays) et ADR-013 (pipeline santé).
**Pas de nouvel ADR** : ajout d'un backend dans une interface déjà
pluggable (`stac_search_s2(source = …)`), plomberie Theia STAC réutilisée.

---

## 1. Objectif

Donner au pipeline de **suivi sanitaire FAST/FORDEAD** une **troisième
source Sentinel-2 L2A**, souveraine (France / CNES), en **repli** des deux
backends STAC actuels :

```
stac_search_s2(source = c("cdse", "pc", "muscate"))
```

MUSCATE (Theia / DATA TERRA, production CNES, correction atmosphérique
MAJA) n'est interrogé **que si CDSE et PC échouent tous les deux** (504
Gateway Timeout PC, saturation CDSE en heures de pointe UE). En marche
nominale, le comportement est **strictement inchangé** : `stac_search_s2()`
itère déjà sur le vecteur `source` et retourne le premier backend qui
renvoie ≥ 1 scène (R/sentinel2.R:117-139).

**Hors scope v1** (décision utilisateur 2026-07-02 : motivation =
résilience/souveraineté, PAS qualité des masques) :

- Consommation des **masques MAJA** nuage/ombre/eau/neige au pixel (ce
  serait l'option « qualité masques » — reportée à un éventuel spec 03x).
  En v1 on garde la **parité** avec cdse/pc : filtrage au niveau scène par
  `eo:cloud_cover ≤ max_cloud`, pas de masquage per-pixel.
- **Sélecteur de source** exposé côté `nemetonshiny` (option « source
  primaire FR par zone » — non retenue). Repli automatique uniquement.

## 2. Contexte — les deux voies MUSCATE existantes

MUSCATE **entre déjà** dans nemeton, mais par un autre pipeline :

| Pipeline | Chemin | Source MUSCATE ? |
|---|---|---|
| **FAST / FORDEAD** (santé) | `ingest_sentinel2_timeseries()` → `stac_search_s2()` → cache COG par bande | ❌ (cdse/pc seulement) — **cette spec l'ajoute** |
| **RECONFORT** (IOTA²) | `reconfort_ingest_s2()` → pygeodes/GEODES → scènes L2A brutes | ✅ (déjà, mais format IOTA², pas cache COG FAST) |

**Décision de voie d'accès (actée)** : **backend STAC Theia**, PAS
réutilisation du chemin GEODES/pygeodes de RECONFORT. Motifs : (a) mirroir
propre de cdse/pc (streaming COG par href, pas de téléchargement de tuile
entière), (b) pas d'ajout de dépendance python/conda ni de compte GEODES
au pipeline FAST, (c) réutilise la plomberie `R/theia_stac.R` déjà livrée
(`stac_search_items`, `resolve_theia_assets`, `theia_signed_href`, auth S3
`/vsis3/`, v0.36.0–v0.40.0).

## 3. Faisabilité

Le contrat de sortie d'un backend est un **tibble normalisé** produit par
`.features_to_tibble()` : colonnes `scene_id`, `datetime`, `cloud_pct`,
`href_<band>` pour chaque bande de `.S2_STAC_BANDS`
(`B02,B04,B05,B08,B8A,B11,B12`), et `source`. Les bandes strictement
requises sont `.S2_STAC_REQUIRED_BANDS = c("B04","B08","B12")` ; les autres
sont tolérées (href = `""`). Un nouveau backend n'a donc qu'à **produire ce
même tibble** ; tout l'aval (cache COG, dédup, FAST raster, FORDEAD) est
générique et **n'a pas à connaître MUSCATE**.

Briques déjà disponibles (aucune à créer) :

- `stac_search_items(stac_api, collection, bbox, …)` — recherche STAC
  générique (R/theia_stac.R:121).
- `theia_signed_href(source_key, …)` / auth S3 `/vsis3/` — signature des
  hrefs COG Theia (R/theia_stac.R:304, v0.40.0).
- La boucle de repli de `stac_search_s2()` — **rien à changer dans la
  logique**, seulement étendre `match.arg` et le `switch`.

Ce qui manque (le cœur du chantier) : **(a)** un backend
`stac_search_s2_theia_muscate()` qui interroge le STAC Theia et **mappe la
nomenclature de bandes MUSCATE** vers celle de nemeton ; **(b)** propager
`"muscate"` dans `match.arg(source, …)` + le `switch` ; **(c)** confirmer
les métadonnées Theia « to confirm » de FR.json.

## 4. Décisions à confirmer avant implémentation

| # | Sujet | Options / recommandation |
|---|---|---|
| **D1** | Endpoint STAC Theia | `services.theia_stac.url` de FR.json est encore `"to confirm"`. **Bloquant** : il faut la racine réelle de l'API STAC Theia (host browser connu : `catalogue.theia.data-terra.org`) + l'identifiant de **collection MUSCATE S2 L2A**. À vérifier sur le catalogue avant impl. Repli si indisponible : la spec reste écrite, l'impl est gelée sur ce point (comme les autres champs Theia `"to confirm"`). |
| **D2** | Nomenclature de bandes | MUSCATE nomme les bandes `B2,B3,B4,…,B8A,B11,B12` (sans zéro de tête, cf. FR.json `products.surface_reflectance.bands`) alors que nemeton attend `B02,B04,B05,B08,B8A,B11,B12`. **Choix** : table de correspondance interne au backend (`B4→B04`, `B8→B08`, `B12→B12`, `B8A→B8A`, `B11→B11`, `B5→B05`, `B2→B02`). Résolue dans `stac_search_s2_theia_muscate()` avant `.features_to_tibble()`. |
| **D3** | FRE vs SRE | MUSCATE expose 2 réflectances : **SRE** (Surface REflectance) et **FRE** (Flat REflectance, corrigée du relief). **Recommandation** : **SRE** en v1 (parité sémantique avec la réflectance L2A de cdse/pc ; FRE introduirait une correction terrain absente des deux autres sources et fausserait la comparabilité inter-sources d'une série mixte). À confirmer. |
| **D4** | Facteur d'échelle / offset | NDVI/NBR/NDMI sont des ratios normalisés `(A−B)/(A+B)` : un facteur d'échelle **linéaire commun** se simplifie. MUSCATE = réflectance ×10000 **sans offset** (Theia collection 3) → ratios inchangés. **À vérifier** qu'aucun offset additif type baseline S2 04.00 (−1000) ne s'applique côté MUSCATE ; si offset ≠ 0, ajouter une normalisation d'échelle dans le backend. Recommandation : garde-fou = documenter l'hypothèse « pas d'offset » + test sur une scène réelle. |
| **D5** | Dédup reprocessing | `.dedup_s2_reprocessed()` s'appuie sur `.s2_split_product_id()`, calibré sur les IDs CDSE/PC. Les IDs MUSCATE diffèrent (`SENTINEL2A_<date>-…_L2A_T31TGM_…`). **Choix** : soit étendre le parseur, soit **bypasser la dédup pour `source = "muscate"`** (MUSCATE ne redistribue pas plusieurs baselines pour une même date → dédup souvent inutile). Recommandation : bypass ciblé + note. |
| **D6** | Filtrage nuage | Vérifier le nom de la propriété STAC de couverture nuageuse côté Theia (probable `eo:cloud_cover` ; sinon adapter la `query`). Parité avec cdse/pc : filtre au niveau scène `≤ max_cloud`, pas de masque per-pixel (hors scope v1). |

## 5. Changements cœur (`nemeton`)

| # | Fichier | Changement |
|---|---------|-----------|
| A1 | `R/sentinel2.R` | `stac_search_s2()` : `match.arg(source, c("cdse","pc","muscate"), several.ok = TRUE)` + branche `switch(muscate = stac_search_s2_theia_muscate(bbox, start, end, max_cloud, limit))`. **Défaut inchangé** : `source = c("cdse","pc")` (le repli MUSCATE est opt-in au niveau appelant OU ajouté au défaut — cf. D-défaut ci-dessous). |
| A2 | `R/sentinel2.R` (ou `R/theia_stac.R`) | Nouveau `stac_search_s2_theia_muscate()` : `resolve` collection MUSCATE via `stac_search_items()`, mappe bandes (D2), sélectionne SRE (D3), signe les hrefs (`theia_signed_href` / S3), retourne le tibble via `.features_to_tibble(features, source = "muscate")`. Bypass dédup si D5 = bypass. |
| A3 | `inst/datasources/FR.json` | Renseigner `services.theia_stac.url` + `s2_l2a_muscate.access.stac_collection` une fois D1 confirmé (retrait des `"to confirm"`). |
| A4 | tests | `test-sentinel2-muscate.R` : mapping de bandes, forme du tibble (colonnes `href_*` + `source == "muscate"`), repli (mock cdse+pc vides → muscate appelé), invariance NDVI sous ×10000 (D4), bypass dédup (D5). Mock des réponses STAC (jamais de réseau en test). |
| A5 | release | `feat:` mineur `0.110.1 → 0.111.0` ; NEWS/CITATION/CHANGELOG/PLAN ; NAMESPACE + `man/*.Rd` **édités à la main** (pas de `document()`, cf. règle projet). |

**Décision-défaut** (à trancher avec D1) : deux façons d'activer le repli —
soit changer le **défaut** de `stac_search_s2()` en `c("cdse","pc","muscate")`
(repli transparent partout, comportement nominal identique car MUSCATE
n'est atteint qu'après échec des deux autres), soit garder le défaut à
`c("cdse","pc")` et n'ajouter MUSCATE qu'aux appelants qui le demandent.
**Recommandation** : ajouter au **défaut** (l'intérêt « souveraineté » est
de couvrir *tous* les appels sans câblage par site), c'est sûr car
sémantiquement le repli n'agit qu'en dernier recours.

## 6. Compatibilité

- Marche nominale (cdse OK) : **aucun appel réseau MUSCATE**, comportement
  bit-à-bit identique. Le tibble MUSCATE a la même forme → cache COG,
  FAST raster, FORDEAD inchangés.
- Une **série temporelle mixte** (certaines dates via cdse, d'autres via
  muscate en jour de panne) est cohérente **tant que D3/D4 tiennent**
  (SRE + même échelle sans offset → NDVI comparable). C'est l'hypothèse
  centrale à valider sur données réelles.
- Le champ `source` du cache/scène permet de **tracer** quelle scène vient
  de MUSCATE (débogage, audit).

## 7. Critères d'acceptation (cœur)

- [ ] `stac_search_s2(source = "muscate")` renvoie un tibble de forme
      identique à cdse/pc (colonnes `href_B04/B08/B12`, `cloud_pct`,
      `source == "muscate"`).
- [ ] Repli : cdse + pc mockés vides → MUSCATE interrogé et renvoyé.
- [ ] Marche nominale : cdse mocké non vide → MUSCATE **jamais** appelé.
- [ ] Mapping de bandes MUSCATE `B4/B8/B12/B8A/B11/B5/B2` → `B04/B08/…`.
- [ ] NDVI/NBR calculés sur une scène MUSCATE = ceux d'une scène de
      réflectance équivalente (invariance d'échelle, D4).
- [ ] `devtools::check()` clean.

## 8. Risques / réserves

- **R1 (bloquant D1)** : la racine STAC Theia et l'ID de collection MUSCATE
  restent `"to confirm"`. Sans eux, l'impl est gelée (spec écrite, code en
  attente — même statut que `chm_opencanopy`/`forms_t` en leur temps).
- **R2 (D4)** : hypothèse « pas d'offset additif ». Si MUSCATE applique un
  offset, une série mixte cdse↔muscate décalerait le NDVI d'une date à
  l'autre → alertes FAST parasites. Garde-fou = test sur scène réelle avant
  activation du défaut.
- **R3** : disponibilité/latence du STAC Theia comme *dernier* repli — s'il
  est lui-même lent, il rallonge le temps d'échec total. Acceptable (repli
  = cas rare), mais borner via `.with_stac_retry` existant.

## 9. Découpage proposé (post-validation)

1. **K1** — Confirmer D1 (endpoint + collection MUSCATE) sur le catalogue
   Theia ; renseigner FR.json. *(action Pascal / navigation catalogue.)*
2. **K2** — `stac_search_s2_theia_muscate()` + mapping bandes (D2/D3) +
   signature href. Tests mockés.
3. **K3** — Câblage `stac_search_s2()` (`match.arg` + `switch` + défaut) +
   bypass dédup (D5). Tests repli/nominal.
4. **K4** — Validation sur **scène réelle** (D4 offset, D6 nuage) — run
   opt-in hors CI.
5. **K5** — Release v0.111.0 (NEWS/CITATION/PLAN, `.Rd` à la main).
