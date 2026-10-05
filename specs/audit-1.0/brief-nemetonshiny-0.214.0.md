# BRIEF `nemetonshiny` — nemeton 0.213.0 et 0.214.0 (audit 1.0, vagues 6 et 7)

> **Émis le 2026-10-05** par la session `nemeton`. Cœur publié en **v0.213.0**
> (reliquat des constats majeurs) et **v0.214.0** (constats mineurs). Détail :
> `NEWS.md` du cœur. **Aucune signature d'export consommé par l'app ne change**
> (liste : `specs/audit-1.0/exports-consommes-app.md`).

## 1. À faire côté app

1. **Plancher** `Imports: nemeton (>= 0.214.0)` quand l'app recalcule.
2. **Recalculer les projets** (s'ajoute au recalcul demandé pour 0.212) : les
   valeurs ci-dessous bougent.
3. Rien d'autre d'obligatoire : les changements de comportement sont déjà
   couverts par le code de l'app (vérifié en lecture seule), voir §3.

## 2. Valeurs qui changent

| Où | Effet |
|---|---|
| R5 | Unités routées vers RECONFORT depuis un run **pin sylvestre** : poids 0,55 au lieu de 0,50 pour « 2-dépérissant ». |
| S3 | Carreau INSEE retrouvé par sa ligne (surestimation possible quand deux carreaux ont la même population). |
| Indices de famille (`create_family_index`) | Poids nommés `C1` appliqués aussi à `C1_norm` ; moyennes géométrique et harmonique pondérées. |
| `normalize_indicators(na.rm = FALSE)` | Un NA rend la colonne NA (50 ou 0 avant). |
| `cv_from_bdforet()` | CV inconnu exclu (CV et taille d'échantillon sous-estimés avant). |
| Plans d'échantillonnage | `n_base` atteint exactement ; graine locale (même graine → même tirage, mais flux RNG différent d'avant pour les plans de validation). |
| CHM lasR | Points de bruit (classes 7, 18) exclus ; les caches CHM ne sont reconstruits qu'avec `overwrite`. |
| FORDEAD | AOI à cheval sur deux tuiles MGRS : une observation par date (mosaïque) — sorties différentes sur ces zones (villards). |
| RECONFORT | Date de déclenchement bornée au jour du run ; `s2_year` futur refusé. |

## 3. Comportements que l'app gère déjà (rien à faire)

- `run_fordead_dieback()` rend `status = "error"` (+ `message`) quand le
  post-traitement ou l'insertion échoue : `mod_monitoring.R` traite déjà
  `"error"`.
- `list_alerts()` sous **SQLite** : `trigger_date` en `Date`, `validated_at` en
  `POSIXct` (comme PostgreSQL). L'app le lit dans `service_r5.R` via `sf`.
- `find_zone_by_project()` : zone la plus ancienne quand il y en a plusieurs.
- `ingest_health_validation()` : l'`alert_id` des GPKG produits par
  `generate_health_validation_plots()` prime sur le plus proche voisin.
- `aggregate_plot_metrics()` avertit (au lieu d'un résultat vide silencieux)
  quand `dbh_cm` / `plot_id` manque.

## 4. Pour information : décision majeure en attente côté cœur

**Offset radiométrique Sentinel-2** (`BOA_ADD_OFFSET = -1000`, scènes traitées
après le 25/01/2022) : confirmé, **non corrigé**. Les indices des scènes
récentes (NDVI, NBR…) sont sous-estimés (NDVI forêt l'été ≈ 0,49 au lieu de
0,84) : fausse chute au passage de 2022 dans FAST, les cartes pixel et les
séries de l'app. La correction (cœur) déplacera les valeurs et peut-être les
seuils FAST ; un brief suivra.
