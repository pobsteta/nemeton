# Spec 027 — Onglet « reGénération » & indicateurs microclimatiques sous couvert

**Statut** : cadrage (paperwork avant code) — 2026-06-30. À valider avant le Lot 1.
**Cibles** : `nemeton` (cœur, indicateurs + pipeline microclimat, MIT) ·
`nemetonshiny` (onglet, UI, EUPL v1.2).
**ADR associé** : **ADR-014** (« reGénération microclimatique : familles
existantes, mode augmenté microclimat, repli opencanopy ») — *à porter dans
`nemetonplateform/docs/`*. Amende **ADR-011** (NDP augmenté).
**Précédents** : spec 005 (Open-Canopy CHM / NDP augmenté), ADR-009
(séparation cœur/app), ADR-011 (NDP, pondération Fibonacci).

> ### ⚠️ Corrections au brief d'origine (numéros forcés par l'existant)
> - **`r5_sensibilite` → `indicateur_r6_sensibilite` (code R6)** : **R5 est déjà
>   pris** par `indicateur_r5_deperissement` (dépérissement FORDEAD/RECONFORT,
>   branché au radar en `nemetonshiny` v0.94.0). Le sous-indicateur de
>   sensibilité microclimatique devient **R6** dans la famille R.
> - **ADR-014** et non ADR-012 (ADR-012 = Extensions PostgreSQL ; ADR-013 = suivi
>   sanitaire).
> - **spec 027** (dernier numéro existant : 026).
> - A3/A4 (famille A) et W4 (famille W) sont libres : conservés tels quels.

---

## 1. Objectif

Évaluer, à l'échelle de la parcelle (UGF), l'**aptitude microclimatique à la
régénération forestière** : la régénération (semis, recrû) est très sensible à
la chaleur et à la sécheresse **au niveau du sol forestier**. On calcule la
température et le déficit hydrique **sous couvert** (pas le macroclimat), le
**tamponnement** apporté par la canopée, et la **sensibilité** du microsite à
une année chaude. Question répondue : *où la régénération est-elle climatiquement
viable, et quelles parcelles prioriser pour l'adaptation ?*

Source physique : modèle microclimatique mécaniste **microclimf** forcé par
**ERA5-Land**, alimenté par le **LiDAR HD IGN** (MNT + MNH + nuage de points
pour le PAI), avec repli **opencanopy** (CHM ortho) là où le LiDAR manque.

## 2. Positionnement architecture (ADR-009)

| Élément | Repo | Licence |
|---|---|---|
| `indicateur_*`, pipeline microclimat, indice composite | `nemeton` (cœur) | MIT |
| Onglet « reGénération » (module Shiny, carto, export, i18n) | `nemetonshiny` | EUPL v1.2 |
| Entrées CHM de repli | via `opencanopy` (déjà intégré, spec 005) | — |

**Dépendances lourdes en `Suggests`, jamais `Imports`** : `microclimf`,
`mcera5`, `ecmwfr`, `lidR`, `lasR`. Chaque fonction les charge via
`requireNamespace(..., quietly = TRUE)` et **échoue proprement** (message
actionnable, jamais d'erreur de chargement de package) si absentes. Cohérent
avec la règle spec 005 / CLAUDE.md.

## 3. Nouveaux sous-indicateurs (familles existantes — radar 12 axes inchangé)

**Pas de 13e famille** (préserver le radar). Sous-indicateurs insérés dans A, W,
R, normalisés 0–100, sens « plus haut = plus favorable à la régénération ».

| Code | Famille | Grandeur | Unité brute | Normalisation |
|---|---|---|---|---|
| `indicateur_a3_microclimat` | A — Air & Microclimat | T° max estivale sous couvert (JJA) | °C | décroissante (frais = 100) |
| `indicateur_a4_tamponnement` | A — Air & Microclimat | Écart T°max découvert − sous couvert | °C | croissante (tamponné = 100) |
| `indicateur_w4_vpd` | W — Eau & Régulation | VPD estival sous couvert (+ RH) | kPa | décroissante (humide = 100) |
| `indicateur_r6_sensibilite` | R — Risques & Résilience | Δ stress (canicule − moyenne), ΔT°max + ΔVPD standardisés | sans dim. | décroissante (peu sensible = 100) |

Signature maison : `indicateur_xx(units, chm = NULL, micro = NULL, ...)` →
renvoie `units` (sf) enrichi d'une colonne **brute** + d'une colonne
**normalisée** + attributs NDP. Réutilise `normalize_indicators()` /
`create_family_index()` **sans modification**. Les familles A, W, R passent
respectivement à 4, 4, 6 sous-indicateurs ; le radar reste à **12 axes**.

**Impact config** : étendre `INDICATOR_FAMILIES$A` (A1,A2 → +A3,A4),
`$W` (W1,W2,W3 → +W4), `$R` (R1..R5 → +R6) dans `R/indicator-config.R`
(labels + tooltips FR/EN), plus la config app (`app_config.R`) côté
`nemetonshiny`, plus les clés i18n (`indicateur_a3_microclimat`, etc.).
**Sens R6** : « haut = bon » comme R1-R4 — donc `normalize_indicator()` n'a
pas à inverser (contrairement à R5 ; cf. [[project_r5_sens_inversion]]).

## 4. Indice composite « potentiel de régénération »

Score de **tête d'onglet** (pas un axe radar), paramétrable **par essence
cible** via la config espèces existante (`get_species_config`,
`list_species_classes`) — une essence thermophile et une mésophile n'ont pas
les mêmes seuils de chaleur/sécheresse acceptables.

```
potentiel_regeneration = f(a3_microclimat, a4_tamponnement, w4_vpd,
                           r6_sensibilite ; tolérances de l'essence cible)
```

- Pondération par défaut **équipondérée**, surchargée par des profils d'essence
  tabulés dans `inst/extdata/regeneration_tolerances.csv` (chaud/sec max
  tolérés par essence).
- Sortie **0–100** + classe (`favorable` / `marginal` / `defavorable`, NMT sans
  accent).
- Fonction cœur `regeneration_index(units, species = NULL, weights = NULL,
  tolerances = NULL)`.

## 5. Données & registre de sources

Étendre le registre (`get_data_source()`, `list_countries()`,
`inst/datasources/FR.json`) pour `"FR"` :

- `era5` — forçage horaire ERA5-Land (via `mcera5`, clé CDS) ;
- `eobs` — série estivale E-OBS (Copernicus/ECA&D) pour cadrer le choix des
  années « moyenne » vs « canicule » ;
- `lidarhd_mnt`, `lidarhd_mnh`, `lidarhd_nuage` — dalles IGN (GeoTiff 50 cm +
  `.laz` classé), **repli `opencanopy`** pour le CHM.

**Politique de données** (`inst/NOTICE`) : E-OBS = usage non commercial
recherche/enseignement ; LiDAR HD = open data IGN ; ERA5-Land = Copernicus
(licence CDS, attribution).

## 6. Chaîne de calcul (`R/microclimate_*.R`)

Pipeline déjà prototypé, à porter en fonctions internes :

1. **PAI** depuis le nuage LiDAR HD — `lasR` (comptage sol/végétation par pixel)
   + Beer-Lambert ; validation `lidR::LAD` (MacArthur-Horn). Repli : PAI estimé
   depuis le CHM opencanopy.
2. **Hauteur de canopée** depuis le MNH (ou CHM opencanopy).
3. **Forçage** ERA5-Land (`mcera5`) au centroïde de l'emprise (année complète),
   `microclimf::checkinputs()` en garde-fou.
4. **microclimf** : `runpointmodel → subsetpointmodel("month","tmax") →
   runmicro` → `Tz`, `relhum` ; agrégation estivale (JJA).
5. Dérivés : VPD, tamponnement (run « à découvert »), et — pour R6 —
   différentiel entre **deux années** (canopée figée) : une année **« moyenne »**
   et une année **« canicule »**. **Sélection des années : détection automatique
   par défaut** (à partir de la série estivale E-OBS, cf. §6bis),
   **surchargeable par l'utilisateur** dans l'onglet.
6. **Agrégation par parcelle** (`terra::extract`) puis normalisation Néméton.

### 6bis. Sélection des années pour R6 (auto par défaut, override utilisateur)

- **Signature** : `indicateur_r6_sensibilite(units, ..., year_moyenne = NULL,
  year_canicule = NULL, year_window = NULL)`. Les deux années à `NULL` →
  **détection automatique** ; renseignées → **choix utilisateur** (l'app les
  passe depuis ses deux sélecteurs).
- **Détection auto** (`R/microclimate_years.R`) : sur la série estivale (JJA)
  **E-OBS** au-dessus de l'emprise, on calcule un **indice de chaleur estivale
  par an** (T°max moyenne JJA, ou indice de canicule). Dans une fenêtre récente
  `year_window` (défaut ~10 ans glissants) :
  - **« canicule »** = l'été le plus chaud,
  - **« moyenne »** = l'année la plus proche de la médiane climatologique,
  - **garde-fou biais canopée** (§12) : à indice comparable, **préférer des
    années proches** de l'année LiDAR/canopée (years adjacentes privilégiées).
- **Traçabilité** : les deux années retenues + leur indice E-OBS sont **exposés**
  dans la sortie (attributs) et l'**infobulle** (« sensibilité estimée entre
  l'été <moyenne> et l'été <canicule> »), pour que l'utilisateur sache sur quoi
  le différentiel est calculé.
- **Best-effort** : E-OBS indisponible / hors couverture → l'app demande un choix
  manuel des deux années (message clair), pas d'erreur silencieuse.

**Performance** : traiter l'union des parcelles + tampon en une fois ;
`microclimf::runmicro_big` (tuilage) au-delà de quelques km² ; résolution
2–5 m ; **cache disque** des rasters microclimat par `(emprise, année)` pour ne
pas relancer le modèle à chaque ouverture de l'onglet (réutilise la convention
de cache projet, cf. spec 021 L6 `reconfort_cache_manifest`).

## 7. NDP & confiance (amende ADR-011)

- **Flag `augmented = "microclimate_model"`** (nouveau, à côté de `height_ml` /
  `species_ml` / `texture_ml` dans `detect_ndp()`), confiance φ préservée comme
  pour `"height_ml"` : le niveau NDP de base n'est pas modifié, l'augmentation
  est reportée dans le vecteur `augmented`.
- **NDP attribué selon la source de structure** : LiDAR HD nuage (NDP augmenté
  le plus élevé) > CHM opencanopy > pas de structure (heuristique → NDP bas).
- **Honnêteté** (à refléter dans confiance + infobulle) : sans validation
  terrain (capteurs TMS-4, bases SoilTemp/ForestTemp), ces indicateurs sont
  fiables en **rangement relatif** entre parcelles, prudents en **valeur
  absolue**.

## 8. Intégration cœur `nemeton`

```
R/microclimate_inputs.R     # PAI (lasR), hauteur (MNH/CHM), forçage ERA5, vegp/soilc
R/microclimate_run.R        # wrapper microclimf -> rasters été (Tz, VPD, RH, tamponnement)
R/indicateur_a3_microclimat.R
R/indicateur_a4_tamponnement.R
R/indicateur_w4_vpd.R
R/indicateur_r6_sensibilite.R
R/regeneration_index.R      # indice composite + paramétrage par essence
data-raw/regeneration_tolerances.R  -> inst/extdata/regeneration_tolerances.csv
```

- Enregistrer les nouveaux indicateurs dans
  `nemeton_compute(indicators = "all" | c("a3","a4","w4","r6", ...))`.
- Roxygen + `man/` (édition manuelle, cf. [[project_rd_no_document]]),
  `NAMESPACE`, `NEWS.md`, `CHANGELOG.md`, bump version, `Suggests`.

## 9. Onglet `nemetonshiny`

```
R/mod_regeneration.R   # UI (essence cible ; années moy/canicule = auto par
                       #     défaut + 2 sélecteurs d'override ; source structure
                       #     LiDAR/opencanopy) + server
```

- Enregistrer l'onglet « reGénération » dans `app_ui`/`app_server`.
- **Sélecteurs d'années R6** : pré-remplis avec la **paire détectée auto**
  (E-OBS), modifiables par l'utilisateur ; un bouton « auto » réinitialise. Les
  deux années retenues + leur indice E-OBS sont affichés (traçabilité §6bis).
- Visus : choroplèthe des 4 sous-indicateurs ; **carte bivariée T°max × VPD**
  (rouge = chaud & sec, style du prototype) ; carte de l'indice composite ;
  table triable ; intégration au **radar** (axes A/W/R mis à jour).
- Export GPKG + PDF (réutiliser l'existant) ; affichage NDP/confiance ;
  **i18n fr/en** ; barre de progression (run microclimf long) ; message clair
  si `Suggests`/données manquantes.

## 10. Tests, doc

- `tests/testthat/` : tests unitaires des 4 indicateurs sur petits rasters
  synthétiques (sens de normalisation, bornes 0–100, NA/couverture partielle,
  NDP/flag `microclimate_model`) ; composite par essence ; **mocks de
  `microclimf`** (pas de réseau en CI).
- `vignettes/regeneration_microclimat_fr.Rmd` (+ en) : tutoriel end-to-end.
- `specs/027-regeneration-microclimat/` (ce dossier) + **ADR-014**.

## 11. Critères d'acceptation

1. `nemeton_compute(units, layers, indicators = c("a3","a4","w4","r6"))` →
   sf avec colonnes brutes + normalisées 0–100 + attributs NDP.
2. Radar 12 familles reste valide (A, W, R intègrent les nouveaux
   sous-indicateurs ; A=4, W=4, R=6 axes internes).
3. Onglet « reGénération » : cartes + table + composite par essence, export
   GPKG/PDF, fr et en.
4. Repli opencanopy opérationnel quand le nuage LiDAR HD est absent (NDP
   dégradé, pas d'erreur).
5. CI verte (R-CMD-check, tests, lintr, couverture) **sans accès réseau**.
6. `couverture_pct` par parcelle exposé (signale les parcelles mal renseignées).

## 12. Limites & risques (à documenter dans l'onglet)

- **Canopée figée** pour R6 : isole l'effet climatique, pas la trajectoire
  complète (mortalité/coupes). Mitigation : la détection auto des années (§6bis)
  **privilégie des années proches** de l'acquisition LiDAR à indice comparable ;
  l'utilisateur peut forcer des années adjacentes (ex. 2021/2022).
- **PAI** sensible à la saison d'acquisition LiDAR (feuilles présentes/absentes)
  et à `k` ; principal levier de calage.
- **Sans validation terrain** : indices relatifs, confiance bornée (cohérent NDP).
- **Coût microclimf** : tuilage + cache obligatoires, sinon onglet lent.

## 13. Lotissement

| Lot | Contenu | Repo |
|---|---|---|
| **L1 — cœur** | `microclimate_inputs/run` + `indicateur_a3/a4/w4` + tests + registre sources (LiDAR HD + repli opencanopy) | `nemeton` |
| **L2 — résilience** | `indicateur_r6_sensibilite` (2 années) + `microclimate_years.R` (détection auto E-OBS, override) | `nemeton` |
| **L3 — composite** | `regeneration_index` + tolérances par essence | `nemeton` |
| **L4 — onglet** | `mod_regeneration` (carto bivariée, export, i18n, radar) | `nemetonshiny` |
| **L5 — doc** | vignette, spec, ADR-014, NEWS/CHANGELOG | les deux |

**Ordre cœur → app** (ADR-009) : L1→L3 publiés en `nemeton` avant L4 côté app.

## 14. Décisions à acter avant le Lot 1

1. ✅ **R6** pour la sensibilité microclimatique (R5 pris). *(validé 2026-06-30.)*
2. **Sens R6 = « haut = bon »** → pas d'inversion `normalize_indicator` (à la
   différence de R5). *(confirmer.)*
3. **microclimf en `Suggests`** + dégradation propre si absent. *(confirmé brief.)*
4. **Flag `microclimate_model`** dans `detect_ndp()` + amendement ADR-011.
5. **Numéro ADR = 014** (et porté dans `nemetonplateform`).
6. ✅ **Années R6 : détection auto par défaut (E-OBS), override utilisateur**
   (`year_moyenne`/`year_canicule` = `NULL` → auto ; `microclimate_years.R`).
   *(validé 2026-06-30, cf. §6bis.)*
