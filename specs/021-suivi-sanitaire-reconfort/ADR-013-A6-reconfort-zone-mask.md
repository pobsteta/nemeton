# ADR-013 — Amendement A6 : masque UGF des sorties RECONFORT

> **DRAFT à porter dans `platform_nemeton/docs/` (source de vérité des ADR).**
> Déposé ici (repo `nemeton`) faute de `platform_nemeton` monté localement.
> À transcrire dans l'ADR-013 (« Suivi sanitaire ») à la suite des
> amendements A1–A5.

**Date** : 2026-06-28
**Statut** : accepté (décisions actées via AskUserQuestion, cf.
`specs/021-suivi-sanitaire-reconfort/L7-clip-ugf-cadrage.md`).
**Porté par** : `nemeton` v0.98.0 (cible).
**Relié à** : spec 016 (Mask UGF par défaut sur le pipeline raster, v0.49.0),
spec 021 lot L7, ADR-011 (NDP), ADR-002 (PostGIS/zone géométrie).

## Contexte

L'ADR-013 acte FORDEAD comme méthode officielle de suivi sanitaire, hybridé
avec le rolling-window FAST, plus RECONFORT (IOTA²/RF feuillus) comme troisième
signal (spec 021). La spec 016 (v0.49.0) avait établi que **toutes les sorties
raster des pipelines de suivi sont masquées au polygone des UGFs par défaut**
(pixels hors gestion = NA), au moment du *read* — afin que comptes et cartes
ne reflètent que la forêt réellement gérée.

À l'époque de spec 016, RECONFORT n'existait pas encore comme pipeline. De
fait, RECONFORT est aujourd'hui le **seul** des trois pipelines (FAST,
FORDEAD, RECONFORT) à ne pas appliquer le masque UGF : ses sorties s'étendent à
la **bbox de l'AOI + 3 km** filtrée par le seul masque d'occupation du sol OSO
feuillus (land-cover national), pas à la limite de gestion.

## Décision

Étendre le contrat spec 016 à RECONFORT, **en parité stricte** avec FAST et
FORDEAD :

1. **Masque UGF par défaut, au read-time.** Un reader cœur
   `read_reconfort_layer(layer, con, zone_id, apply_zone_mask = TRUE,
   mask_polygon = NULL)` applique `.apply_zone_mask()` (réutilisé de spec 016)
   sur les couches raster RECONFORT à la lecture. Les `.tif` produits par
   IOTA² ne sont pas réécrits (principe spec 016 : masque au read, pas au
   write).
2. **Nommage homogène** : `apply_zone_mask` (et non `clip_to_aoi`), identique
   aux readers FAST/FORDEAD. Opt-out `apply_zone_mask = FALSE`.
3. **Centroïdes d'alertes — clippés au read-time** (RÉVISÉ 2026-06-29, v0.99.0).
   La position initiale (« non clippés, ils tombent naturellement dans l'UGF »)
   était fausse : les centroïdes RECONFORT viennent du raster masqué
   **OSO-feuillus** (pas UGF), donc débordent. Correctif : helper unique
   `filter_alerts_to_zone()` qui filtre l'`sf` POINT au polygone UGF **au read**
   (table `alert` non modifiée), **partagé par les 3 pipelines**. Le
   rattachement `zone_id` + `st_intersects` de l'analyse R5 reste en place.

## Conséquences

**Positives**
- Cohérence transverse des 3 pipelines de suivi : même option, même défaut,
  même point d'application, même helper de masquage.
- Comptes/cartes RECONFORT restreints à la forêt gérée → pertinence accrue
  (cf. ~70 % de pixels hors UGF éliminés sur villards, spec 016 §1).
- Aucun nouveau code de masquage : réutilisation de `.apply_zone_mask` /
  `.get_zone_aoi`. Pipeline et table `alert` inchangés.

**Négatives / points d'attention**
- **Changement de comportement par défaut** (`TRUE`) : les appelants voulant
  le rectangle complet doivent passer `apply_zone_mask = FALSE`. Documenté en
  NEWS (parité spec 016).
- Asymétrie assumée raster (masqué) vs centroïdes (non clippés) — déjà le cas
  pour FAST/FORDEAD, donc cohérent à l'échelle de l'ADR-013.

## Alternatives écartées

- **Masque au write** (réécrire des `.tif` clippés) : diverge du principe
  spec 016, alourdit le pipeline, casse la séparation cache/affichage.
- **Masquage côté `nemetonshiny`** : pousserait de la sémantique métier dans
  la présentation (viole les règles strictes §1-3 / ADR-009).
- **Clip des centroïdes au postprocess** : asymétrique vs FAST/FORDEAD, sans
  bénéfice (le test `st_intersects` R5 couvre déjà le besoin analytique).
