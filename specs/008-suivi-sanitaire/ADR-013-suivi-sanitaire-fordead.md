# ADR-013 — Méthode officielle de suivi sanitaire : FORDEAD avec garde-fous applicatifs

**Statut** : Proposed (à porter dans `platform_nemeton/docs/`)
**Date**   : 2026-04-26
**Auteur** : Pascal Obstétar (via Claude)
**Cible**  : `nemeton` v0.21.0
**Précédents pertinents** : ADR-008 (souveraineté UE), ADR-009 (séparation cœur/app), ADR-011 (NDP augmenté), ADR-012 (extensions PG futures — TimescaleDB, pgvector)

---

## Contexte

Le chantier E6 a été initialement spécifié (spec 007) comme un « monitoring forestier continu » générique fondé sur des baisses brutales de NDVI/NBR détectées dans une fenêtre roulante de 30 jours. La phase squelette (E6.a, livrée en v0.20.0) a montré que cette approche est légitime pour détecter des **chocs récents** (coupes, chablis, incendies) mais n'a pas la précision sémantique pour répondre à la question métier centrale : *« mes peuplements résineux dépérissent-ils ? »*

La filière forestière française (ONF, IGN, INRAE/CIRAD) a déjà standardisé une méthode dédiée à cette question : **FORDEAD** (Boissieu et al. 2024, GPL-3), qui modélise la phénologie de l'indice **CRSWIR** par pixel sur une période de référence saine, puis détecte les anomalies confirmées par 3 acquisitions consécutives au-delà d'un seuil (0.16 par défaut).

Une étude de validation terrain conduite par l'ONF / Département de la Santé des Forêts en automne 2023 (Bernard & Doridant 2024, 397 relevés sur Vosges, Jura, Alpes du Nord, Massif Central) a quantifié les performances et les limites :

- Bonne détection (>80%) sur la classe **3-forte anomalie** ;
- Détection raisonnable (70%) sur la classe **4-sol nu**, mais sans distinction interne entre coupe rase et dépérissement avancé ;
- **Taux élevé de faux positifs** sur les classes **1-faible** (~50%) et **2-moyenne** (~37%) ;
- **Détection précoce médiocre** : ~60% des stades précoces (« scolyte vert ») non détectés ;
- **Confusion dépérissement / perturbation mécanique** : 25% des trouées-chablis, 38% des interventions sylvicoles récentes, 41% des casses de cime apparaissent comme anomalies FORDEAD ;
- **Validité géographique restreinte** (massifs résineux du Nord-Est et Alpes du Nord), **validité essences restreinte** (épicéa commun, sapin pectiné).

La modification du seuillage d'anomalie *« n'a pas d'effet réel sur les performances »* selon le rapport — citation directe — donc on ne peut pas régler le problème de calibration en jouant sur les paramètres.

---

## Décision

### 1. Méthode officielle de suivi sanitaire : FORDEAD

`nemeton` adopte FORDEAD comme méthode canonique pour le diagnostic sanitaire des peuplements résineux.

**Paramétrage par défaut** :

- Indice : **CRSWIR**
- Période d'entraînement : **2 ans** (2016-2017 par défaut, configurable)
- Seuil d'anomalie : **0.16**
- Confirmation : **3 anomalies consécutives**
- Masque forêt : **BD Forêt v2 IGN** (FR), avec possibilité de fournir un masque tiers

Ces valeurs sont alignées sur le paramétrage validé par le rapport ONF/DSF 2024 et ne sont **pas exposées à l'utilisateur final** dans la première version (v0.21.0). Une re-calibration éventuelle se fera par ADR ultérieur, à partir de nouvelles études de validation.

### 2. Stratégie hybride : FORDEAD ⨯ rolling-window

`nemeton` conserve le pipeline rolling-window NDVI/NBR (E6.a, v0.20.0) comme **deuxième méthode complémentaire**, dédiée à la détection des **chocs récents** (coupes, chablis, incendies). Les deux pipelines alimentent la même table `alert` (TimescaleDB) avec un champ `alert_type` discriminant.

Une fonction de fusion `classify_disturbance()` combine les deux signaux pour qualifier chaque alerte FORDEAD :

- FORDEAD ∩ rolling-window (±30 j) → `disturbance_type = "mechanical"` (coupe, chablis, casse de cime)
- FORDEAD seul → `disturbance_type = "progressive"` (dépérissement scolyte/sécheresse, signal qualifié)
- Rolling-window seul → `disturbance_type = "recent_event"` (événement récent sans signe antérieur de dépérissement)

Cette fusion est la mitigation directe du finding ONF sur la confusion dépérissement / perturbation mécanique. Elle constitue une valeur ajoutée propre à `nemeton` qui n'existe ni dans FORDEAD seul ni dans un rolling-window seul.

### 3. Cinq garde-fous applicatifs obligatoires

Traduction directe des limites identifiées dans le rapport ONF/DSF 2024 :

#### G1 — Filtrage par défaut classes 3-forte + 4-sol-nu

Les classes **1-faible** et **2-moyenne**, dont le rapport montre qu'elles produisent 50% et 1/3 de faux positifs respectivement, ne sont **pas affichées par défaut** dans l'interface ni utilisées dans le calcul de l'indicateur R5. L'utilisateur peut les activer via une option avancée, mais une bannière d'avertissement explicite l'informe alors du taux de faux positifs élevé.

#### G2 — Fusion rolling-window × FORDEAD

cf. point 2 ci-dessus.

#### G3 — Avertissements géographiques et essences

Une couche `inst/extdata/fordead_validity_zones.geojson` matérialise les départements où la calibration FORDEAD est validée par le rapport ONF (Vosges, Jura, Ain, Savoie, Haute-Savoie). Quand l'AOI projet n'intersecte pas cette couche à plus de 50%, ou quand la composition d'essences (BD Forêt v2) n'atteint pas 70% d'épicéa+sapin pectiné, l'interface affiche des bannières d'avertissement explicites, et l'utilisateur doit confirmer pour lancer le calcul.

#### G4 — Workflow de validation terrain par QField

Toute alerte FORDEAD est créée en statut `pending` et passe par un cycle de vie (`pending → confirmed | false_positive | closed`) alimenté par un workflow de saisie terrain QField, **réutilisant l'infrastructure E5.b**. Le schéma de saisie est aligné sur la nomenclature du rapport ONF (codes Sain, Scolyte_vert, Scolyte_rouge, Scolyte_gris, etc.) pour interopérabilité avec les bases DSF existantes.

L'objectif de ce garde-fou est d'institutionnaliser le couplage humain-machine que le rapport ONF identifie comme indispensable : *« couplée à l'expertise des correspondants-observateurs ».*

#### G5 — Indicateur R5 dépérissement pondéré par confiance

Un nouvel indicateur **R5** rejoint la famille R (Risques) du radar nemeton, calculé avec une pondération directement issue des taux de bonne détection observés sur le terrain :

```
R5(UGF) = Σ surface(classe_k, UGF) × FORDEAD_CONFIDENCE_WEIGHTS[k] / surface(UGF)

FORDEAD_CONFIDENCE_WEIGHTS <- c(
  "1-faible"  = 0.10,
  "2-moyenne" = 0.30,
  "3-forte"   = 0.82,
  "4-sol-nu"  = 0.70
)
```

R5 retourne **NA** quand l'UGF :
- contient moins de 30% de résineux (BD Forêt v2),
- ou n'intersecte pas une zone de validité géographique,
- ou n'a pas été couverte par un run FORDEAD.

### 4. Architecture d'intégration

- **Frontière R/Python** : FORDEAD est appelé via `reticulate` dans un environnement virtuel isolé (`~/.virtualenvs/nemeton-fordead/`), créé idempotemment au premier appel. Les dépendances Python sont figées dans `inst/python/requirements.txt`.
- **Licence** : FORDEAD est sous GPL-3. L'appel via reticulate est un appel runtime (RPC), pas un linking statique. `nemeton` reste sous MIT, FORDEAD est référencé dans `Suggests` (dépendance optionnelle) et attribué dans `inst/NOTICE`.
- **Frontière cœur/app** (ADR-009 préservé) : toute la logique métier (pipeline, post-processing, R5, schémas de saisie, ingestion validation) vit dans le package `nemeton`. Le package `nemetonshiny` est purement présentationnel (UI mode toggle, bannières, plotly, leaflet, async wrapper).

### 5. Persistance des limites dans le code et la documentation

- Les coefficients de confiance et leurs justifications citent **explicitement le rapport ONF/DSF 2024** dans les commentaires de code.
- La spec 008 §4.5 documente les 8 limites (§4.5 du présent ADR).
- L'interface affiche systématiquement la classe d'anomalie et le `stress_index` à côté de chaque alerte, pour que l'utilisateur ne perde jamais de vue le niveau de confiance.
- Le profil expert LLM `gestionnaire_onf` est enrichi d'instructions de prudence dans son prompt (rappel systématique de la classe, des sources de faux positifs, de la nécessité de vérification terrain).

---

## Conséquences

### Positives

- **Crédibilité scientifique** : le projet s'appuie sur la méthode validée et utilisée par la communauté forestière française (ONF, IGN, INRAE/CIRAD, DSF).
- **Documentation des limites** : les utilisateurs sont prévenus, le risque de mauvaise interprétation est minimisé.
- **Valeur ajoutée propre** : la fusion FORDEAD × rolling-window n'existe nulle part ailleurs et résout directement la principale source de bruit identifiée par le rapport.
- **Boucle terrain** : la validation QField institutionnalise le couplage humain-machine.
- **Extensibilité** : les coefficients vivent dans une constante R, faciles à ré-évaluer quand de nouvelles études paraîtront.

### Négatives / coûts

- **Dépendance Python** : ajoute une complexité opérationnelle (gestion de venv, debugging cross-langage). Mitigation : helpers reticulate idempotents + messages d'erreur explicites + `Suggests` (dégradation propre quand absent, rolling-window reste utilisable).
- **Coût d'exécution** : FORDEAD prend 2-4 minutes par parcelle, 30-90 min par massif. Mitigation : ExtendedTask + future_promise pour ne pas bloquer l'UI ; communication explicite des durées attendues.
- **Validité restreinte par construction** : la méthode ne peut pas être utilisée légitimement hors épicéa/sapin et hors massifs validés. Mitigation : G3 (bannières) ; FORDEAD reste désactivable au profit du mode rapide qui n'a pas ces restrictions.
- **Calibration figée à v0.21.0** : pas de re-calibration par l'utilisateur. Mitigation : explicite dans la doc ; ADR ultérieur si besoin.

### Risques résiduels acceptés

- L'algorithme FORDEAD reste un **outil d'aide à la décision**, pas un outil de prédiction quantitative. Il ne doit **pas** être utilisé pour produire des estimations de volumes ou de pertes économiques. Cela est explicite dans la doc et dans les disclaimers UI.
- La **détection précoce reste médiocre** (60% des stades précoces non détectés). Mitigation : bandeau d'information dans l'UI, le mode sanitaire complète mais ne remplace pas les inventaires terrain réguliers.

---

## Alternatives considérées et écartées

### A. Tout fordead, pas de rolling-window

**Pour** : architecture plus simple, une seule méthode officielle.
**Contre** : ne distingue pas dépérissement vs perturbation mécanique (problème central du rapport ONF). L'utilisateur perdrait la capacité de détecter rapidement coupes/chablis/incendies. Le travail E6.a (v0.20.0) deviendrait du throwaway.
**Verdict** : rejeté.

### B. Rolling-window uniquement

**Pour** : zéro dépendance Python, zéro problème de calibration, zéro restriction géographique.
**Contre** : aucune valeur scientifique pour le suivi sanitaire à proprement parler. Faux positifs garantis sur les transitions saisonnières. Pas adapté à la question métier centrale.
**Verdict** : rejeté.

### C. Méthode ML maison (Bárta 2021, Deepak 2024)

**Pour** : possibilité de mieux faire que le seuillage harmonique, suggéré en conclusion du rapport ONF.
**Contre** : effort R&D massif, calibration locale nécessaire, pas dans l'état de l'art francophone reconnu, pas d'écosystème.
**Verdict** : reporté en V+1, listé en §10 de la spec 008.

### D. Fork de FORDEAD avec ré-implémentation R native

**Pour** : éliminer la dépendance Python.
**Contre** : maintenance lourde, divergence inévitable du upstream, redéveloppement de xarray/dask en R.
**Verdict** : rejeté (rapport coût/bénéfice catastrophique).

---

## Mise à jour à prévoir dans la documentation projet

- **CLAUDE.md** : mise à jour de la table des familles d'indicateurs (R passe à R1-R5 quand FORDEAD a tourné), ajout du `contexte_sante` dans les Bounded Contexts, ajout de l'ADR-013 dans la liste.
- **PLAN.md** : reframing du chantier E6 « monitoring continu » → « suivi sanitaire », mise à jour du découpage (cf. spec 008 §1).
- **README** (cœur et app) : section « Suivi sanitaire » avec disclaimer de validité.
- **NOTICE** : attribution FORDEAD (CIRAD/INRAE, GPL-3, citation Zenodo) + attribution rapport ONF/DSF 2024 (référence d'évaluation des limites).

---

## Références

- Boissieu F, Fernandez E, Dutrieux R, Ose K, Féret J-B (2024). *fordead: a python package for vegetation anomalies detection from SENTINEL-2 images.* Zenodo. doi:10.5281/zenodo.12802456 (GPL-3)
- Bernard C, Doridant JB (2024). *Méthode FORDEAD — analyse de la validité des détections d'anomalies de végétation dans le cas des résineux par contrôle sur le terrain.* ONF / DSF, mai 2024.
- ADR-008, ADR-009, ADR-011, ADR-012 (`platform_nemeton/docs/`)
- Spec 007 (devient la couche surveillance rapide de spec 008)
- Spec 008 (`specs/008-suivi-sanitaire/`)

---

## Amendement A1 — Migration vers l'API fordead 2.x (2026-05-16, cible v0.23.0)

**Statut** : approuvé (paperwork avant code).
**Lien** : spec 008 §12, plan 008 §9, PLAN.md journal 2026-05-16.

### Contexte de l'amendement

L'ADR-013 v1 (2026-04-26) supposait fordead 1.x avec les 5 step modules `fordead.steps.step1_*..step5_*` et un format d'entrée THEIA L2A pour les scènes Sentinel-2. La cascade de patches `v0.22.2..v0.22.5` (16 mai 2026) a révélé :

1. **Kwargs incorrects** dans `R/fordead_pipeline.R` (e.g. `vegetation_index` au lieu de `vi`, `input_directory` au lieu de `data_directory`).
2. **Aucun pont** entre notre cache STAC COG (sortie de `ingest_sentinel2_timeseries()`) et le format THEIA L2A attendu par fordead 1.x.
3. **Tests mockés complaisants** (44 tests offline) qui n'ont jamais touché un vrai fordead. La double dérive est passée inaperçue jusqu'à la première exécution réelle par l'utilisateur final.

Bilan : le pipeline FORDEAD livré en `v0.21.0` était techniquement non-fonctionnel. R5 dépendant de FORDEAD n'a donc jamais produit de valeur non-NA en pratique. Spec 008 §6 G5 (R5 pondéré) reste valide, mais nécessite un pipeline FORDEAD qui marche réellement.

### Décision

**Migrer vers fordead 2.x** (`@v2.1.1`, pin git+gitlab.com).

Justification courte :

- **fordead 2.x accepte une `simplestac.ItemCollection` directement** via `fordead.workflow.FordeadProcess(collection, output_dir, bbox, geometry, config=FordeadConfig())`. C'est exactement le format de notre cache. Plus de gap STAC ↔ THEIA à combler.
- **API unifiée** : une classe `FordeadProcess` avec `fit()` puis `predict()`, au lieu de 5 modules dispersés.
- **Calibration ONF/DSF préservée** : tous les défauts de `FordeadConfig()` (CRSWIR, 0.16, 3 anomalies, 2-ans training) correspondent exactement aux valeurs ADR-013. Aucune dérive métier.
- **Active branch** : fordead 1.x est en maintenance. La 2.x est la branche de développement INRAE/CNES.

### Ce que cet amendement modifie dans ADR-013 v1

| Décision ADR-013 v1 | Statut après A1 |
|---------------------|-----------------|
| §1 Méthode officielle = FORDEAD | ✅ inchangé |
| §2 Stratégie hybride FORDEAD ⨯ rolling-window | ✅ inchangé |
| §3 G1 — classes 3-forte + 4-sol-nu par défaut | ✅ inchangé. Le mapping (raster fordead → classes 1-4) est ajusté dans plan 008 §9.3 mais le résultat métier est le même. |
| §3 G2 — fusion rolling-window × FORDEAD | ✅ inchangé (logique SQL côté `classify_disturbance()`, indépendante de la version fordead) |
| §3 G3 — bannières géo + essences | ✅ inchangé |
| §3 G4 — workflow validation QField | ✅ inchangé |
| §3 G5 — R5 pondéré par confiance, weights `(0.10, 0.30, 0.82, 0.70)` | ✅ inchangé (`R/indicators-deperissement.R` intact). Les poids restent calibrés sur le rapport ONF/DSF 2024. |
| §4 Architecture (reticulate + fordead Python) | 🟨 **modifié** : `reticulate::import("fordead")` (top-level) au lieu de `import("fordead.steps")`. Voir plan 008 §9.2. |
| §5 Persistance des limites dans code et doc | ✅ inchangé. La calibration reste figée v0.23.0 sur les défauts 2.x (qui matchent ONF/DSF). |

### Ce que cet amendement ajoute

- **Une couche STAC assembly côté R** (`.build_stac_collection_for_aoi()`) qui transforme notre cache disque `<cache_dir>/{scene_id}/{band}.tif` en `pystac.Item[]` consommable par `FordeadProcess`. Cette couche n'existait pas en v1 (où fordead 1.x était supposé manger des SAFE folders qu'on n'a jamais).
- **Tests d'intégration `skip_if_no_fordead()`** (≥ 2) qui touchent réellement le venv fordead 2.x, pour qu'une dérive de signature soit attrapée en CI/dev plutôt qu'à l'exécution prod.
- **Documentation explicite** que `run_fordead_dieback(cache_dir = ...)` devient quasi-obligatoire : sans cache local, les hrefs PC SAS expirent pendant `fit()` long-running (cf. v0.22.1). Avec cache, on passe des paths locaux à `pystac.Asset(href = ...)` → pas de problème d'expiration.

### Conséquences

**Positives (au-delà du fix correctness)** :
- Le pipeline devient testable end-to-end (les tests intégration cassent si le mapping change).
- Pas de fork de fordead à maintenir (alternative D de ADR-013 v1 reste rejetée — la 2.x suit notre besoin).
- Calibration ONF/DSF est désormais documentée comme "défaut fordead 2.x" — donc plus stable face à un futur changement de paramètres dans 2.x (si INRAE/CNES bouge, on bougera avec, après revue).

**Coûts** :
- Travail de migration : ~18 h (plan 008 §9.6).
- Régénération du fixture des alertes pour `test-indicators-deperissement.R` (mapping confidence_class § 9.3).
- Wiring `nemetonshiny@v0.32.0` à venir (noms de phases changent : `vegetation_index → fit / predict`).

**Risque résiduel accepté** : `simplestac` est pin git-only (forge.inrae.fr/umr-tetis). Si la forge INRAE est down au moment d'un install, ça échoue. Identique au risque fordead lui-même (gitlab.com). Pas de mitigation locale ; documenté.

### Historique des décisions sur le pin fordead

| Date | Tag | Justification |
|------|-----|---------------|
| 2026-04-26 | (spec 008 v1) | « fordead 2.1.x » mentionné sans vérification. |
| 2026-04-29 | (E6.c.1 livré) | `fordead==2.1.4` dans `requirements.txt`. Version inexistante (PyPI 404 par dessus le marché). |
| 2026-05-15 (v0.22.2) | `git+gitlab@v2.1.1` | Fix install : fordead n'est pas sur PyPI, on bascule sur git+gitlab. Latest 2.x tag = v2.1.1. |
| 2026-05-15 (v0.22.5) | `git+gitlab@v1.11.4` | Découverte du mismatch d'API : pipeline R écrit pour 1.x, downgrade au dernier 1.x stable. |
| 2026-05-16 (v0.23.0, amendement A1) | `git+gitlab@v2.1.1` | Migration propre : 2.x accepte notre STAC natif. Réécriture du pipeline R. Approche endorsed. |

### Tests de validation de A1

Avant clôture v0.23.0 :

1. `Rscript -e 'devtools::test(filter = "fordead")'` → tous tests verts, dont les nouveaux `test-fordead-integration.R` quand fordead est dispo.
2. AOI de référence (≤ 1 km², Vosges) — `run_fordead_dieback()` termine en `status = "success"`, `rasters$state` ouvert avec `terra::rast()` sans erreur.
3. R5 calculé sur une zone avec FORDEAD réel — valeur dans `[0, 100]`, status = `"calculated"`.

Ces checks sont aussi listés en spec 008 §12.7 (AC.12.1-12.5).
