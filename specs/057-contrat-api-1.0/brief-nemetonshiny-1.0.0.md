# BRIEF `nemetonshiny` — nemeton **1.0.0**

> **Émis par** la session `nemeton`, à la publication du cœur 1.0.0.
> **Décision de Pascal (2026-10-06)** : la 1.0.0 **repart de zéro**. Projets,
> caches de projet et bases (plateforme et suivi sanitaire) sont **recréés** ;
> aucune migration. Specs : `nemeton/specs/056-choix-methode/` (méthode),
> `nemeton/specs/057-contrat-api-1.0/` (API).

## 1. Ce qui casse, et ce que l'app doit faire

1. **Plancher** `Imports: nemeton (>= 1.0.0)`.
2. **Bases de données** : `db_migrate()` **refuse** toute base créée avant la
   1.0.0 (erreur classée `nemeton_legacy_schema`, « Database predates nemeton
   1.0.0: recreate it »). Le schéma 1.0.0 tient en une migration initiale
   unique ; TimescaleDB y est optionnel.
   - **Base de suivi sanitaire** : la recréer (fichier SQLite neuf, ou base
     PostgreSQL vide).
   - **Base plateforme** : l'app y appelle aussi `db_migrate()`
     (`service_db.R:222`). Les tables du cœur (`project_lock`,
     `schema_migration`…) vivent dans le schéma par défaut : les supprimer, ou
     recréer la base. Tant que ce n'est pas fait, le verrou de projet est
     indisponible.
   - Les trois appels (`service_db.R:222`, `service_monitoring_db.R:351`,
     `mod_monitoring.R:800`) attrapent l'erreur en avertissement : prévoir un
     message clair « base antérieure à la 1.0.0 : recréer » plutôt qu'un
     avertissement technique.
3. **FORDEAD** : l'environnement Python est figé sur le venv validé et exige
   **Python ≥ 3.11**.
4. **Recalculer tous les projets** (de zéro) : les valeurs changent (§2).
5. **Caches de l'app** :
   - `ndvi_s2.tif` (composite C2), toujours sans clé de version : le jeter
     (rappel du brief 0.216.0) ;
   - les caches de résultats du cœur (`index_stack/`, `fast_raster/`, TWI) sont
     invalidés par leur clé.

## 2. Valeurs qui changent (spec 056)

| Indicateur | Effet |
|---|---|
| **W3** | TWI calculé en mètres même sur un MNT en degrés (était 0 sur Couchey, Aumur), ramené à 2 m (`TWI − ln(pas/2)`), fenêtre fixe [2,5 ; 9] : ne sature plus (était ≈ 100 en LiDAR). Baisse nette sur LiDAR (−50 à −70 pts). |
| **F2, R3** | Même TWI corrigé et même fenêtre. |
| **R2** | Sans TRI (redondant avec la pente) : exposition au vent × pente. |
| **W2** | Seuil TWI à 9,5 sur le TWI ramené à 2 m (= l'ancien 12 sur MNT 25 m). |
| **N1** | Terme urbain constant +25 retiré : −18 à −22 pts ; N3 −6 à −8. |
| **P3** | Diamètre seul sans données terrain ; nouvelle colonne `p3_status`. |
| **P2** | Hors courbe de station → **NA**, `p2_status = "hors_courbe"`. |
| **P2, C1 depuis la BD Forêt seule** | `enrich_parcels_bdforet()` n'invente plus ni âge (60), ni densité (0,7), et rend des codes essence reconnus. **Sans âge réel, P2 (mode CHM) est NA partout et C1 retombe sur le NDVI** : il faut un âge saisi ou mesuré pour les calculer. L'app doit l'expliquer (statut, info-bulle). |
| **C2 sur ortho IRC du WMS** | NA avec `c2_status = "wms_irc"` : `.c2_apply_provenance()` de l'app, inatteignable tant que C2 rendait un vecteur, s'applique enfin. |

Scores de famille W, N, P, R : baisse mécanique attendue.

## 3. API (spec 057) — transparent pour l'app, vérifié en lecture seule

- Tous les `indicateur_*()` rendent l'objet `units` + colonne au nom du code :
  `compute_single_indicator()` passe déjà tout `sf` par
  `extract_indicator_value()`.
- `lang` et `column_name` retirés des indicateurs : l'app ne les passe pas.
- Alias `indicateur_l1_sylvosphere` / `l2_fragmentation` supprimés : l'app ne
  garde ces noms que comme colonnes de base.
- 34 exports internes retirés : aucun n'est appelé par l'app.
- Chaque page d'aide porte un statut **stable** / **experimental**.

## 4. Nouveaux statuts à traduire (FR/EN)

- `p3_status` (`diametre_seul`, `diametre_forme`, `diametre_defauts`,
  `complet`) ; `p2_status = "hors_courbe"` (en plus de `indice_station_m`).
- Indicateurs conditionnels sans leur source : `a3/a4/w4/r6_status =
  "skipped_no_micro"`, `t3_status = "skipped_no_sufosat"`,
  `b4/l3_status = "skipped_no_spectral"` (puis `"calculated"` ou
  `"skipped_no_coverage"` quand la source est là).

Tous transportés par `.capture_status_attr()` comme les autres
`<code>_status`.

## 4 bis. `list_indicators()` (41 indicateurs)

`list_indicators()` rend désormais les 41 indicateurs (colonnes `code`,
`conditionnel`, `source_conditionnelle` ; `conditionnels = FALSE` pour les 31
de base). Effet dans l'app : `service_project.R:615`
(`.add_normalized_indicators`) reconnaît maintenant les 10 conditionnels et
leur crée une colonne `_norm` ; l'avertissement « Normalisation impossible »
disparaît pour eux. Aucun autre appel. Commentaire devenu faux, sans effet :
`service_desserte.R:1315` (« P1 … its `column_name` default »).

## 5. À nettoyer côté app

- La couche « wetlands » téléchargée par `download_inpn_wfs()` (`service_compute.R`) (motif
  `patrinat.*(ramsar|znieff|zone_humide)`) contient surtout des **ZNIEFF**, pas
  des zones humides ; le cœur ne la lit pas (W2 n'utilise que les surfaces en
  eau BD TOPO, le TWI et un raster d'occupation du sol). La retirer, ou la
  restreindre aux vraies couches de zones humides si une source fiable existe.
- Guide de l'app : repris dans `nemetonshiny` (brief
  `2026-10-06-nemeton-guide-app-a-reprendre.md`) ; retiré du cœur en 1.0.0.
