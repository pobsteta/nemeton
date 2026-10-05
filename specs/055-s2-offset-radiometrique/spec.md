# Spec 055 — Offset radiométrique Sentinel-2 (`BOA_ADD_OFFSET`)

> **Statut** : livré en **v0.215.0** (2026-10-05). Décision de Pascal : corriger, en
> commençant par l'offset (« commence par l'offset S2 »).
> **Origine** : audit 1.0, constat M `pixel-map.R` « offset S2 non géré (à
> confirmer) », confirmé en vague 6 (v0.213.0).

## 1. Le défaut

Depuis la *processing baseline* 04.00 de Sen2Cor (25/01/2022), les produits
L2A portent un décalage additif : `BOA = (DN + BOA_ADD_OFFSET) / 10000` avec
`BOA_ADD_OFFSET = -1000`. Les comptes numériques sont donc **+1000** par
rapport aux produits antérieurs. L'archive retraitée (« Collection 1 ») le
porte aussi : une scène acquise en 2017 et retraitée en 2024 a l'offset.

Le cœur ne retire jamais ces 1000. Tous les indices (NDVI, NBR, NDMI, NDRE)
sont calculés sur les comptes bruts. Pour un pixel forestier d'été (rouge
≈ 300, PIR ≈ 3500 en réflectance × 10000) :

| | rouge | PIR | NDVI |
|---|---|---|---|
| sans offset | 300 | 3500 | 0,84 |
| avec offset non retiré | 1300 | 4500 | 0,55 |

D'où une **fausse chute** de tous les indices au passage des scènes traitées
après le 25/01/2022.

## 2. Ce qui est touché

- **Lectures R** : toutes passent par `read_s2_band_raster()` —
  `read_s2_band_stack()`, `build_index_stack()`, `extract_pixel_timeseries()`,
  et donc FAST (`read_fast_alert_raster()`, `compute_fast_alert_mask()`) et
  les cartes / séries pixel de l'app. `obs_pixel` n'existe plus (migration
  0004) : rien n'est stocké en base, tout est recalculé depuis le cache.
- **Cache des piles d'indices** (`build_index_stack(cache_result = TRUE)`) :
  clé fondée sur les fichiers de bandes, donc il resservirait les piles
  biaisées.
- **FORDEAD** : lit les COG du cache via un STAC local, par `stackstac`
  (`rescale = True`, qui applique le `raster:bands.offset` de chaque asset).
  `fordead.preprocess.harmonize_collection()` n'ajoute qu'un offset **0** aux
  assets qui n'en déclarent pas ; FORDEAD n'appelle pas
  `simplestac.harmonize_sen2cor_offset()`. Le modèle, ajusté sur les années
  d'apprentissage (2016-2017, sans offset), prédit donc sur des scènes
  récentes biaisées.
- **Hors périmètre** : RECONFORT (produits MUSCATE / MAJA, sans offset),
  E-OBS, LAI MUSCATE.

## 3. Règle de détection — par l'identifiant de scène

Le cache ne garde ni les propriétés STAC ni la *baseline* ; l'identifiant de
scène suffit :

| Format | Exemple | Offset si |
|---|---|---|
| Planetary Computer (6 champs) | `S2A_MSIL2A_20170126T105321_R051_T31UDP_20210207T203737` | horodatage de traitement (dernier champ) ≥ `20220125` |
| ESA / CDSE (7 champs) | `S2A_MSIL2A_20230101T103431_N0509_R108_T31TFN_20230101T134212(.SAFE)` | baseline `N####` ≥ `N0400` |
| MUSCATE / MAJA | `SENTINEL2A_20220130-…` | jamais |
| autre | — | inconnu → pas de correction, avertissement une fois |

**Validation empirique** (2026-10-05, caches Reconfort, Aumur, Fordead,
1 040 scènes) : la règle et le plancher des pixels sombres de B04
(quantile 1 % > 700) concordent sur **1 036 scènes**. Les 4 écarts sont des
scènes **sans** offset à plancher naturellement haut (neige, voile), dont le
minimum (285 à 410) exclut un décalage de 1000.

## 4. Correction

1. **Lecture** : `read_s2_band_raster()` retire l'offset des scènes concernées
   — `max(DN - 1000, 0)`, la convention de Planetary Computer
   (`clip(1000) - 1000`). Nouvel argument `harmonize = TRUE` (ajout en fin de
   signature : rétrocompatible) ; `harmonize = FALSE` rend les comptes bruts.
   Le cache sur disque n'est **pas** réécrit : pas de migration, et une
   scène re-téléchargée reste juste.
2. **Cache des piles** : la clé de `build_index_stack(cache_result = TRUE)`
   intègre une version d'harmonisation ; les piles biaisées ne sont plus
   relues.
3. **FORDEAD** : les assets du STAC local des scènes concernées déclarent
   `raster:bands = [{nodata: 0, offset: -1000, scale: 1}]` ; une date
   mosaïquée dont les scènes n'ont pas le même offset garde la scène la plus
   étendue et le signale (même traitement que deux CRS différents).

## 5. Seuils FAST

- `count` / `rolling` : seuils **absolus** (NDVI < 0,40, NBR/NDMI/NDRE < 0,30),
  cohérents avec des réflectances vraies. Sur des données biaisées, un
  peuplement sain (0,55) frôlait le seuil : la correction **réduit** les
  fausses alertes post-2022. Pas de recalibrage a priori.
- `trend` (Theil-Sen + Mann-Kendall, relatif) : l'offset fabrique exactement
  la baisse pluriannuelle qu'il cherche. La correction supprime ces fausses
  tendances.

Mesure avant / après sur un projet réel au §7.

## 6. Conséquences

- **Valeurs** : tous les indices des scènes traitées après le 25/01/2022
  remontent (NDVI forêt ≈ +0,3) ; cartes FAST, séries pixel et FORDEAD
  changent. Brief app : recalculer les cartes FAST et relancer FORDEAD.
- **API** : `read_s2_band_raster()` gagne `harmonize` ; aucune autre
  signature ne change.

## 7. Mesure avant / après

Projet Reconfort (`20260701_204501_ltcp`), cache de 316 scènes, 115 830 pixels,
`read_fast_alert_raster()` sur le cache seul, correction désactivée puis
active (script `mesure_fast_avant_apres.R`) :

| Carte FAST | Avant | Après |
|---|---|---|
| `count` NDVI < 0,40, 2022-2025 — dates sous le seuil, moyenne par pixel | 53,1 | **17,9** |
| `count` NDVI < 0,40, 2017-2021 (témoin) | 23,4 | 22,6 |
| `trend` NDMI 2017-2025 — pixels en alerte | **44,7 %** | **5,5 %** |
| `trend` NDVI 2017-2025 — pixels en alerte | 20,0 % | 1,3 % |

- Après correction, la fréquence post-2022 (17,9 dates en 4 ans) redevient
  cohérente avec la période témoin (22,6 en 5 ans) ; avant, elle était
  triplée. La légère baisse du témoin vient des scènes de 2017-2021
  retraitées après 2022, désormais corrigées elles aussi.
- En mode `trend`, l'offset fabriquait l'essentiel des alertes : 39 points
  sur 45 en NDMI. Les ~5 % restants sont des déclins réels à examiner.
- **Seuils FAST inchangés** : ils étaient calibrés pour des réflectances
  vraies, ce sont les données qui étaient fausses.

FORDEAD, vérifié de bout en bout sur une scène acquise le 2021-12-31 et
retraitée en 2023 : B04 moyen 1 394 brut, 394 corrigé côté R, 390 lu par la
pile `stackstac` de FORDEAD avec l'offset déclaré (écart de grille de
`stackstac`) ; la scène traitée en 2020 n'est pas touchée (594).
