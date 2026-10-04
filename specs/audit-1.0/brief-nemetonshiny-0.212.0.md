# BRIEF — nemeton 0.212.0 : seconde passe sur les calculs (audit 1.0, vague 5)

> **Émis le 2026-10-03** par la session `nemeton`. **Packages** : `nemeton`
> (livré en **v0.212.0**), `nemetonshiny` (demandeur). Rapport à jour :
> https://claude.ai/artifact/EDFFCM5SmJ78DAAeuzTYs2

## 1. À faire côté app

1. Plancher `Imports: nemeton (>= 0.212.0)`.
2. **Recalculer les projets** : beaucoup d'indicateurs changent de valeur
   (tableau ci-dessous).
3. Radar : l'app passe déjà `normalize = FALSE` ; seul l'axe change (fixé à
   0-100, valeurs écrêtées, au lieu de « max × 1,2 »).

## 2. Valeurs qui changent

| Indicateur | Effet |
|---|---|
| B3 | Toutes les valeurs bougent (composante coût enfin calculée, parcelles en forêt à 100 sur la composante locale, composantes absentes exclues). |
| B1 | Baisse pour les unités qui portaient le maximum de statuts du lot (borne fixe 4). |
| L1, L2, A1 (OSO) | L2 mesure enfin la forêt (et non le bâti) ; L1 monte près du bâti et des routes ; A1 baisse (pelouses exclues). |
| W1 / W2 | W1 : NA sans couche (au lieu de 0). W2 : baisse là où les sources se recouvraient ; NA sans aucune source. |
| A2 (proxy) | Monte en général ; l'unité la plus exposée n'est plus forcée à 0. |
| R1 (repli), R4, R5, R7 | R1 intègre le NDVI sans essence ; R4 pondéré par surface, NA hors raster gibier ; R5 baisse quand un cluster touche plusieurs UGF ; R7 calculable sur une seule unité. |
| E1, E2 | Valeurs brutes × 2 (densité sèche), borne × 2 : scores normalisés inchangés hors taillis. |
| S1, S2 | Unités en bordure : vraie distance au lieu de NA ou d'une surestimation. |
| T1, T2 | Âge mesuré prioritaire ; NA au lieu de 50 sans source. |
| Douglas, résineux | Densité Douglas 490 (au lieu de 620) ; P3 applique les seuils résineux au sapin, Douglas, mélèze, cèdre ; une vingtaine de codes deviennent résineux (courbes de hauteur, P1, C1, R2). |
| Plans d'échantillonnage | Nouvelles colonnes `wgt`, `ip` (aussi dans le GPKG QField, champs cachés) ; une extraction en échec lève une erreur (l'app la rattrape déjà). |
| Plan de validation | Plus de placettes hors zone ; répartition « uniform » corrigée ; une zone sans alerte lève `nemeton_empty_alert_mask`. |
| E-OBS (meteoland) | Moyenne estivale au lieu du maximum : valeurs plus basses. |
| RECONFORT | Pixels très sains à 1 (et non « pas de donnée ») ; série pixel masquée des nuages (plus de NA). |

## 3. Calibrages à valider (Pascal)

Borne B1 = 4 statuts ; sévérité du coût B3 (`100 − coût/10`) ; référence de
pollution A2 = 100 ; contrastes OSO de L1 ; borne E1/E2 = 2,64.

## 4. Ajout du 2026-10-04 : R1 `fireexposuR` et T2

Suite au brief aigora-nemeton `2026-10-04-r1-fireexposur-allocation-absurde.md`.

**R1.** Le chemin `fireexposuR` n'aboutissait sur aucun projet (MNT de repli
IGN en EPSG:4326 → fenêtre de `fire_exp()` de ~59 600 Go, repli silencieux).
Corrigé dans le cœur : tous les R1 changent au recalcul (Couchey : 23/23
parcelles en `fire_exp`, 1,6 s). Le résultat porte deux colonnes nouvelles :

- `r1_status` — **transportée sans câblage** par `.capture_status_attr()`
  (colonne `.r1_status` du parquet). Valeurs : `fire_exp`,
  `fallback_no_fireexposur`, `fallback_no_bdforet`,
  `fallback_fire_exp_failed`, `skipped_no_dem` (R1 = NA),
  `skipped_no_component` (R1 = NA). À traduire dans l'UI (FR/EN) si la fiche
  R1 ou le rapport affichent la méthode ; les deux `skipped_*` relèvent de
  l'explication d'un indicateur tout-NA (`mod_family.R`).
- `r1_fallback_reason` — texte libre (message d'erreur de `fire_exp()`
  compris). Pas transporté aujourd'hui : il faudrait l'ajouter au canal des
  colonnes annexes si le rapport doit citer le motif exact.

**T2.** Depuis 0.212.0, T2 rend **NA** (au lieu de 50) faute de source. Or
l'app ne lui en donne aucune : `.units_for_indicator()` passe les `parcels`
brutes (ni colonne `T1`, ni `N2`), et N2 est calculé **après** T2 dans
l'ordre de `service_compute.R`. Il faut, pour `indicateur_t2_changement`,
injecter `parcels$T1 <- results[["indicateur_t1_anciennete"]]` (ou passer
`t1_values =`), et idéalement `N2` (source prioritaire) en calculant N2 avant
T2. Sans cela, T2 est NA sur tous les projets.
