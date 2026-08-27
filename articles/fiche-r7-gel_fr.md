# Fiche indicateur R7 - Gel tardif

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** à une série de températures minimales
> journalières. **Non inversé**, comme R6.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `R7` |
| Nom long / colonne | `indicateur_r7_gel` |
| Famille | **R — Risques & Résilience** |
| Grandeur mesurée | Exposition au **gel tardif** après débourrement |
| Unité brute | **0–100, haut = peu de gel = favorable** |
| Sens | **non inversé** |
| Fonction | [`indicateur_r7_gel()`](https://pobsteta.github.io/nemeton/reference/indicateur_r7_gel.md) — `R/indicators-frost.R:69` |
| Colonnes annexes | `r7_gel_days` (jours/an), `r7_status` |

## 2. Le calcul

    fenetre = [budburst_doy ; window_end_doy]        defaut [100 ; 180], soit ~10 avril - 29 juin
    gel_days = nombre moyen de jours par an ou Tmin < frost_threshold_c   defaut 0 °C
    R7 = 100 quand gel_days = 0 ; 0 quand gel_days >= max_frost_days      defaut 8

Le `SpatRaster` `tmin` doit porter ses dates via
[`terra::time()`](https://rspatial.github.io/terra/reference/time.html)
— sans elles, la fonction **abandonne avec un message explicite** plutôt
que de placer les gelées au hasard dans la saison.

**Exemples chiffrés** :

| Situation                     | Jours de gel tardif / an | R7       |
|-------------------------------|--------------------------|----------|
| Plateau abrité                | 0,5                      | **93,8** |
| Station ordinaire             | 2,0                      | **75,0** |
| Fond de vallon froid          | 5,0                      | **37,5** |
| Cuvette à inversion thermique | 9,0                      | **0,0**  |

## 3. Le calcul par niveau NDP

| NDP | Source de `tmin` | R7 |
|----|----|----|
| **0** sans série | rien | **`NA`**, `r7_status = "skipped_no_tmin"` |
| **0** | E-OBS / SAFRAN descendus en résolution | **calculé**, maille kilométrique |
| **1** | \+ descente d’échelle sur MNT LiDAR HD | les cuvettes froides apparaissent |
| **2** | — | — |
| **3** | **capteurs de température au sol** | seule mesure directe |
| **4** | — | — |

R7 relève du chantier microclimat P4 (`meteoland`/SAFRAN) et n’est pas
encore alimenté par défaut dans le pipeline.

## 4. Trois pièges

1.  **Le débourrement est une constante, pas une phénologie.**
    `budburst_doy = 100` (≈ 10 avril) s’applique à toutes les unités et
    à toutes les essences. Or le chêne débourre trois semaines après le
    hêtre, et l’altitude décale encore la date. Le paramètre est exposé
    — le régler par essence est à la charge de l’appelant.
2.  **Le gel tardif est un phénomène de fond de vallon, donc de
    micro-relief.** À la maille kilométrique d’E-OBS, les inversions
    thermiques nocturnes — précisément ce qui cause le dégât — sont
    invisibles. R7 à NDP 0 mesure un climat régional, pas un risque de
    station.
3.  **Le seuil de 0 °C sous-estime le dégât.** Les jeunes pousses sont
    endommagées avant le gel de l’air, par rayonnement.
    `frost_threshold_c` est réglable : le relever (par exemple à +2 °C)
    est souvent plus réaliste.

## 5. Aval

    indicateur_r7_gel()  ->  colonnes R7, r7_gel_days, r7_status
          |
          +- normalize_indicator()     -> ecretage [0, 100], PAS d'inversion
          +- create_family_index("R")  -> famille_risque = moy(R1..R7, na.rm = TRUE)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction R7 | `R/indicators-frost.R:69` |
| Comptage des gelées | `.frost_late_days()` |
| Forçage climatique | [`meteoland_daily_grid()`](https://pobsteta.github.io/nemeton/reference/meteoland_daily_grid.md), [`build_safran_stations()`](https://pobsteta.github.io/nemeton/reference/build_safran_stations.md), [`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md) |
| Chantier | `specs/brief-meteoland-safran-p4.md` |
