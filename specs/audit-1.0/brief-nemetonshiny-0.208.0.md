# BRIEF — nemeton 0.208.0 : corrections de calcul, des valeurs changent

> **Émis le 2026-10-02** par la session `nemeton` (audit de pré-version 1.0,
> première vague). **Packages** : `nemeton` (livré en **v0.208.0**),
> `nemetonshiny` (demandeur). **Nature** : aucune API nouvelle ; plancher
> `nemeton (>= 0.208.0)` et recalcul des projets. Rapport complet :
> https://claude.ai/artifact/EDFFCM5SmJ78DAAeuzTYs2

## 1. Ce qui change à l'écran (relu dans `nemetonshiny@origin/main`)

| Où dans l'app | Fonction cœur | Effet |
|---|---|---|
| Onglet Desserte (`service_desserte.R:1337`) | `volume_mobilisable(unite = "m3_total")` | **Volumes ~P1 fois plus petits.** Avant : `P1 × taux × horizon` (5 680 « m³/ha » pour P1 = 200, 2,84 m³/ha/an, 10 ans). Désormais : `taux × horizon`, plafonné par P1 (28,4). Le typage de desserte (flux) change : **relancer le calcul de desserte** des projets. |
| Onglet reGénération (`service_regeneration.R:169, 197, 1279`) | `indice_priorite_regen()` | L'exposition lit `sensibilite_score` (inversé) au lieu du z-score `sensibilite`. **Le volet exposition, quasi nul jusqu'ici, compte enfin** : l'indice monte, `parcelle_sensible` peut être TRUE. Aucune colonne à ajouter si `regen_sensibilite()` a tourné (il pose déjà `sensibilite_score`). |
| Onglet reGénération (`service_regeneration.R:163`) et radar | `indicateur_r3_secheresse()` | Sans `climate_data`, plus de série simulée : R3 = topographie seule. Les valeurs R3 changent pour tous les projets sans climat. |
| Radar, famille B | `indicateur_b2_structure()` | L'app passe par CHM / MNH / NDVI (pas de strates) : **aucun changement attendu**, sauf `cv_chm_weight = 0`, qui ignore désormais le CHM. |
| Radar, famille R (R4) | données de chasse | Les départements 01 à 09 ont enfin leur propre pression de gibier (au lieu de la médiane nationale). |
| Suivi sanitaire | `.insert_health_alerts()` (FORDEAD, RECONFORT) | Un re-run **ne supprime plus les alertes validées** sur le terrain. Une alerte nouvelle à moins de 50 m d'une alerte validée n'est pas réinsérée : la ligne validée reste. Le nombre d'alertes rapporté par un re-run peut donc baisser. |

`create_family_index()` préfère désormais la colonne brute à son `_norm`.
L'app passe ses colonnes `.<code>_status` et produit ses `_norm` par
`normalize_indicator()` (la même règle) : **aucun changement attendu** sur le
radar. Si un écran appelle `normalize_indicators(by_family = TRUE)`, il reçoit
désormais un avertissement et des colonnes `_norm` (non trouvé en lecture).

## 2. À faire côté app

1. Plancher `Imports: nemeton (>= 0.208.0)`.
2. Recalcul des projets existants : desserte (volumes), reGénération (indice),
   R3 et R4 (radar).
3. Optionnel : un message dans le journal des versions de l'app, car les
   volumes de desserte et l'indice de régénération changent d'ordre de
   grandeur.
