# BRIEF `nemetonshiny` — nemeton 0.215.0 : offset radiométrique Sentinel-2 corrigé

> **Émis le 2026-10-05** par la session `nemeton`. Spec :
> `nemeton/specs/055-s2-offset-radiometrique/spec.md`. Suite du §4 du brief
> 0.214.0 (« décision majeure en attente »).

## Ce qui change

Depuis le 25/01/2022, les Sentinel-2 L2A portent un offset de +1000 sur les
comptes numériques ; le cœur ne le retirait jamais. Tous les indices des
scènes récentes étaient écrasés (NDVI d'une forêt d'été ≈ 0,55 au lieu de
0,84). C'est corrigé **à la lecture du cache**, dans `read_s2_band_raster()`,
dont héritent `build_index_stack()`, `extract_pixel_timeseries()`,
`read_fast_alert_raster()`, `compute_fast_alert_mask()`. FORDEAD reçoit
l'offset dans son STAC local.

Mesure sur Reconfort : carte `trend` NDMI, **44,7 % → 5,5 %** de pixels en
alerte ; `count` NDVI 2022-2025, 53 → 18 dates sous le seuil par pixel.

## À faire côté app

1. **Plancher** `Imports: nemeton (>= 0.215.0)`.
2. **Cartes FAST en cache** : celles du cœur (`fast_raster/`, `index_stack/`) sont invalidées par leur clé (version de radiométrie). Si l'app garde ses propres copies hors de ces dossiers, les recalculer.
3. **Relancer FORDEAD** sur les zones suivies : le modèle prédisait sur des
   scènes post-2022 biaisées.
4. Rien à changer dans l'interface : `read_s2_band_raster()` gagne seulement
   `harmonize = TRUE` en fin de signature (rétrocompatible). Les seuils FAST
   par défaut ne changent pas.
5. Prévenir les utilisateurs : les alertes FAST (mode tendance surtout) et
   les courbes NDVI post-2022 changent nettement.
