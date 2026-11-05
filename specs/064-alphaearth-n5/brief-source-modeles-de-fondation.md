# BRIEF — Modèles de fondation et raisonnement sylvicole dans l'écosystème Néméton

**Destinataire** : Claude Code, espace `nemeton` (cœur), avec briefs dérivés vers `maestronemeton`, `nemetonshiny`, `aigora`, `victor`
**Auteur** : Pascal Obstétar (via Claude)
**Date** : 2026-11-05
**Statut** : Brief de cadrage — à transformer en specs numérotées (064 et suivantes) après lecture, selon la procédure CLAUDE.md
**Périmètre** : indépendant de tout projet de thèse. Ce brief ne porte que sur l'évolution du produit Néméton.

---

## 0. Pourquoi ce brief

Néméton calcule 41 indicateurs explicites dans 12 familles, à partir de couches géomatiques et de statistiques simples (CV du CHM, distances aux routes, courbes de Duplat & Tran-Ha, NDVI). Cette architecture « formules + NDP » est lisible et robuste, mais elle a trois limites que les modèles de fondation publiés en 2025-2026 lèvent :

1. **Sous la canopée, rien.** `compute_dtm_chm_from_laz()` réduit le LiDAR HD à un MNT/MNH. Bois mort sur pied, stratification réelle, très gros bois, âge structurel sont perdus. La famille N mesure une naturalité administrative (éloignement, ancienneté cartographique), pas une naturalité fonctionnelle.
2. **Le NDP confond résolution et information.** Un embedding satellitaire à 10 m (NDP 0) peut porter plus d'information structurelle qu'un CHM Open-Canopy (NDP 1). L'ADR-011 (`augmented`) a ouvert la porte ; il faut la franchir.
3. **Les perspectives IA (E7) raisonnent sur du texte, pas sur des trajectoires.** Le RAG cite la littérature ; il ne simule pas ce qu'un itinéraire sylvicole ferait à l'UGF.

Les modèles à intégrer, tous publics : **ForPT** (ETH/NIBIO 2026, encodeur LitePT-S 12,4 M paramètres pré-entraîné sur 33 Md de points ALS/ULS/MLS), **AlphaEarth Foundations** (Google DeepMind 2025, embeddings annuels 64-D à 10 m, Earth Engine), **MAESTRO** (IGN 2025, déjà dans `maestronemeton`), **TerraMind** (ESA/IBM 2025, génératif any-to-any), **FINN** (Pichler & Käber 2026, modèle de trouées hybride différentiable, package R `FINN` sur CRAN, torch), **SelectAnyTree** (2026, segmentation promptable d'arbres 3D).

## 1. Principes non négociables

- **ADR-009 tient** : le cœur `nemeton` reste sans dépendance Python. Tout ce qui nécessite torch vit dans un package amont (`maestronemeton`, `opencanopy`, et les nouveaux `forptnemeton`, `alphaearthnemeton`) qui produit des **couches raster/vecteur** consommées par le cœur via `get_data_source()` et `nemeton_layers()`.
- **Contrat API 1.0 (spec 057)** : aucun indicateur stable ne change de sens. Les nouveautés sont de nouveaux codes (B5, N4, N5, N6, T4) ou des modes additionnels (`chm =`, `embedding =`) sur les fonctions existantes, avec le mécanisme `INDICATOR_SENSE_VERSION` si un sens évolue.
- **Chaque nouvel indicateur a sa fiche** (spec 052) dès la première release, avec la section « pièges » remplie. Le PLAN.md doit lister les écarts cœur → app dès l'ouverture, pas après (leçon des écarts n° 10 et 11).
- **Pas de nombre inventé par un LLM.** Toute valeur affichée ou lue à voix haute provient d'une fonction du cœur. Le LLM compose, explique, compare, cite ; il ne calcule pas.
- **Versionnage calendaire** `AAAA.M.N` en vigueur.

## 2. Chantiers

### Chantier A — `alphaearthnemeton` : source NDP 0 universelle et distance à la référence (priorité 1, R pur)

**Livrable amont** : package `alphaearthnemeton` (MIT) exposant `aef_fetch(aoi, years, out = "COG")` qui rapatrie les 64 bandes AlphaEarth pour l'emprise (Earth Engine via `rgee`, ou export pré-calculé depuis le catalogue GEE community pour les zones hors quota), en Lambert-93, cache disque adressé par contenu comme FAST (spec 017 D6).

**Livrable cœur** :
- Nouvelle source `aef_embedding` dans `get_data_source()` et `NDP_LEVELS[[1]]$sources` ; couche `layers$aef_embedding` (SpatRaster 64 bandes, multi-années).
- `embedding_summary(units, layer)` : moyenne, écart-type et nombre de pixels par UGF → matrice `n_units × 64`. Fonction générique réutilisée par les chantiers B et C.
- **N5 — distance à la référence** : `indicateur_n5_distance_reference(units, embedding, reference)` où `reference` est un ensemble d'UGF ou de polygones de forêts à faible perturbation (par défaut : couche `foret_ancienne` tier maximal ∩ `N1 ≥ 80` ; l'utilisateur peut fournir sa propre référence, par exemple un réseau de réserves intégrales). Métrique : distance de Mahalanobis régularisée (Ledoit-Wolf) dans l'espace des embeddings moyens, convertie en score 0-100 par rang percentile sur le projet. Statut `n5_status` = `no_reference`, `reference_too_small` (< 15 unités), `ok`. **Pièges à documenter** : la référence n'est pas un échantillon aléatoire (pente, accès) ; N5 mesure une distance, pas une causalité.
- **Recalibrage B4/L3** (écart n° 6) : mode `embedding =` sur `indicateur_b4_div_spectrale()` et `indicateur_l3_het_spectrale()`, calculant la diversité comme entropie des clusters d'embeddings à l'intérieur de l'UGF. Comparabilité inter-projets obtenue par construction, puisque l'espace est globalement normalisé.
- **Régressions légères NDP 0** pour C1, P2, B2 quand ni CHM ni LiDAR : `embedding_regress(train = placettes IFN du projet, target = "H0")` avec ranger, réutilisant `ifn_source.R` et les covariables Fay-Herriot. Flag `augmented = "embedding_ml"` dans `detect_ndp()`.

**Critères d'acceptation** : N5 calculé sur le projet Dabo et sur une UGF hors France (spec 006) ; B4/L3 d'un même projet stables à ±2 points entre deux exécutions sur des années AEF différentes ; vignette `embeddings-alphaearth_fr.Rmd`.

**Limite documentée** : AEF est annuel. Il ne remplace ni FAST, ni FORDEAD, ni le cube S2 (R5, T2, phénologie).

### Chantier B — MAESTRO en extracteur de représentations et sondes de concepts (priorité 2, `maestronemeton`)

Aujourd'hui `maestronemeton` est un classifieur 13 classes PureForest. Le même encodeur gelé devient une source d'embeddings alignés sur les données IGN que Néméton consomme déjà.

- `maestro_embed(aoi, modalities = c("ortho_rvbi", "mnt", "s2", "s1"))` → raster d'embeddings par patch 50 m (dimension 768, réduite à 64 par PCA ajustée sur le corpus BFC et versionnée dans `inst/extdata/`). Normalisation globale par dataset (corriger le défaut `_normaliser_mnt()` min-max par batch noté dans DEV_PLAN).
- **Sondes linéaires** (`probe_indicator(embedding, units, target = "B2")`) : pour chaque indicateur calculable sur le projet, ajuster une régression ridge de l'embedding vers l'indicateur, en validation croisée spatiale par blocs. Sortie : table `indicateur × R²_probe`. Lecture : R² élevé = l'embedding « voit » le concept et peut le fournir en NDP augmenté là où la source manque ; R² faible = angle mort documenté. Cette table est un livrable à part entière, affichée dans l'app comme « ce que les modèles voient ».
- Préparer l'alignement **BD Forêt v3** (basée sur MAESTRO) : `map_bdforet_essence()` doit accepter la nomenclature v3 ; prévoir la migration des 11 classes BFC.
- Fusion précoce ortho + LiDAR HD : ajouter le MNH LiDAR comme modalité du fine-tuning PureForest (déjà prévu dans DEV_PLAN), puis concaténer embedding MAESTRO et embedding ForPT par UGF (chantier C).

### Chantier C — `forptnemeton` : le LiDAR HD comme espace latent 3D (priorité 2, livrable central)

**Livrable amont** : package `forptnemeton` (MIT, reticulate + torch, même patron d'installation que `opencanopy`) :
- `forpt_embed(laz_dir, aoi, out)` : encodeur ForPT gelé sur les dalles LAZ LiDAR HD, sortie voxels 2 m avec vecteur 256-D, agrégée en raster multi-bandes et en profil vertical par strate (0-2, 2-5, 5-10, 10-20, > 20 m).
- `forpt_segment(laz_dir, aoi)` : segmentation sémantique bois / feuille / sol et instances d'arbres (ForPT ou SelectAnyTree en repli), sortie `sf` d'arbres avec hauteur, diamètre de houppier, classe « vivant / mort sur pied », flag très gros bois.
- `forpt_age(laz_dir, aoi)` : régression d'âge structurel par UGF (tâche évaluée dans ForPT), avec intervalle.

**Livrable cœur** :
- **B5 — stratification 3D** : entropie du profil vertical de densité par strate (0-100). Remplace avantageusement B2 quand disponible ; B2 reste pour compatibilité.
- **N4 — bois mort et très gros bois** : densité d'arbres morts sur pied et de TGB (≥ 70 cm estimés) par ha, normalisée par rapport aux seuils de la littérature (dendro-microhabitats, Paillet et al.). Fiche obligatoire : incertitude de la classification mort/vivant en feuillus hors feuilles.
- **N5 structurel** : même fonction qu'au chantier A, nourrie par l'embedding ForPT ; `n5_source = "aef" | "forpt" | "fused"`.
- **T1 désaturé** (écart n° 10) : mode `age_structurel =` sur `indicateur_t1_anciennete()` ; au-delà de 120 ans, l'âge structurel ForPT prolonge l'échelle jusqu'à 300 ans.
- `segment_houppiers()` : accepter en entrée les instances 3D (`tops = forpt_segment(...)`) à la place du watershed 2D ; l'OTB/LSMS reste le repli sans LiDAR.
- Pipeline de **dimensionnement** : avant toute acquisition drone (NDP 2), `simulate_density_sensitivity()` sous-échantillonne le LiDAR HD (10 → 5 → 2 pts/m²) et mesure la stabilité de B5/N4/N5. Résultat affiché dans l'onglet terrain pour justifier ou non une campagne ULS.

**Critères d'acceptation** : B5, N4, N5 calculés sur les dalles LiDAR HD d'un projet BFC réel en moins de 30 min CPU par 1 000 ha ; N4 confronté aux relevés terrain QField de bois mort sur au moins 20 placettes ; fiches 052 complètes.

### Chantier D — Dynamique et causalité : de la perspective textuelle au modèle (priorité 3, année 2)

- **FINN comme moteur de trajectoires**. Nouveau module `trajectoire.R` enveloppant le package `FINN` : `calibrer_finn(placettes_ifn, climat = meteoland/E-OBS, ser)` et `simuler_itineraire(units, itineraire, horizon = 50, n = 100)`. Les processus croissance / mortalité / régénération partent des formules existantes (`ifn_production`, `density_selfthinning`, `charru_bai_drift`) comme composantes mécanistes, puis sont remplacés un à un par des composantes neuronales quand les données IFN du projet le permettent. Sortie : trajectoires de P1, C1, B2/B5, N4, R2, R3 par itinéraire, avec intervalles.
- **Vitalité dynamique — T4** : écart entre trajectoire observée (FORMSpoT 2014-2025, cube S2, FORMS-T) et trajectoire attendue par FINN sous l'itinéraire déclaré. T4 > 0 : l'UGF fait mieux que prévu ; T4 < 0 : décrochage. Conditionnel à la présence d'au moins 6 années de séries.
- **Effets de la gestion, estimés et non supposés**. `effet_gestion(units, traitement = "type_sylviculture", covariables = c("P2", "altitude", "pente", "ser"))` : méta-apprenant T ou X (ranger) estimant l'effet individuel du traitement sur chaque famille, avec diagnostic de recouvrement (overlap) et refus explicite quand il est insuffisant. Les sorties alimentent les perspectives IA comme résultats du projet, cités comme tels.
- **TerraMind** (optionnel, priorité 4) : génération de modalités manquantes (S1, carte de hauteur) pour désactiver les `NA` des indicateurs conditionnels (R5, T3, A5) en outre-mer et hors France (spec 006). À n'engager que si le besoin outre-mer se confirme.

### Chantier E — Architecture et outillage transverse

- Dépôts : `alphaearthnemeton`, `forptnemeton` créés au même rang que `maestronemeton` (ADR-009 mis à jour en ADR-014).
- `embedding_summary()`, `probe_indicator()`, `distance_reference()` : fonctions génériques du cœur, indépendantes du modèle source, testées sur embeddings synthétiques.
- Cache : les embeddings sont des COG adressés par contenu (hash emprise + modèle + version de poids), comme FAST.
- Fiches : une fiche « modèles de fondation » commune (quels poids, quelle licence, quelle date, quels angles morts connus) liée depuis chaque fiche d'indicateur.
- App (`nemetonshiny`, brief séparé) : vue « Ce que les modèles voient » (table des sondes), couche N5 sur la carte, trajectoires FINN dans l'onglet plan d'actions, badge de dimensionnement drone dans l'onglet terrain.

## 3. Raisonnement sur les itinéraires sylvicoles : un agent, trois couches

La question posée : Aigora et Victor peuvent-ils porter une IA capable de raisonner sur les itinéraires sylvicoles possibles et souhaitables ? Oui, à condition de séparer strictement trois couches, chacune dans le dépôt où elle a sa place.

### 3.1 Ce qui existe déjà et se réutilise

- **Victor** délègue déjà dans l'espace `nemeton`, lance des calculs en tâche de fond, lit les fiches projet (`nemeton_fiche`, `nemeton_etat`), ouvre l'Atlas et les vues publiées, affiche des rapports (`display_report`). C'est l'interface vocale et la couche d'orchestration courte.
- **Aigora** fournit le cadre Claude Code local avec skills, agents, mémoire sémantique, QGIS et QFieldCloud. C'est le lieu naturel d'un skill `sylviculteur` et d'un agent de raisonnement long.
- **Néméton** fournit les calculs : 41 indicateurs, Pareto et trade-offs (`analysis-pareto.R`, `analysis-tradeoff.R`), 13 profils experts, RAG de 81 documents, plan d'actions, `indice_priorite_regen`, `ifn_production`. Avec le chantier D, il fournira les trajectoires.

### 3.2 Couche 1 — Néméton : le moteur (ce que l'IA n'a pas le droit d'inventer)

Nouveau module `itineraires.R` dans le cœur :
- **Catalogue d'itinéraires** `inst/extdata/itineraires_sylvicoles.yml` : futaie régulière (par essence et classe de fertilité), futaie irrégulière Pro Silva, taillis-sous-futaie, libre évolution, conversion, îlots de sénescence, plantation avec essences de diversification. Chaque itinéraire est décrit par des **règles paramétrées** (rotation, intensité de prélèvement, diamètre d'exploitabilité, surface terrière cible, essences objectif), avec sources (guides de sylviculture ONF, DRA/SRA, Pro Silva, SRGS).
- `itineraires_admissibles(unit)` : filtre par station (P2, SER, essences, pente, desserte via `foretaccess`, contraintes réglementaires via famille B1 et couches urbanisme). Retourne la liste des itinéraires possibles **avec la raison de chaque exclusion**.
- `simuler_itineraire()` (chantier D) : trajectoires à 20/50/100 ans sur les 12 familles.
- `comparer_itineraires(unit, itineraires, profil_expert)` : front de Pareto multi-famille pondéré par le profil (les 13 profils YAML existent), avec la table des trade-offs. Sortie structurée : `itineraire`, `score_global`, `familles_gagnantes`, `familles_perdantes`, `incertitude`, `citations`.
- `effet_gestion()` (chantier D) : ce que la gestion a réellement produit sur le massif, pour confronter la simulation à l'observé.

Tout est déterministe, versionné, testé. L'agent ne voit que ces sorties.

### 3.3 Couche 2 — Aigora : l'agent `sylviculteur` (le raisonnement)

Skill `sylviculteur` + agent `sylviculteur.md` dans `aigora/.claude/`, inspiré de `researcher.md` :

1. **Cadrage** : objectifs du propriétaire (production, carbone, biodiversité, résilience, paysage), horizon, contraintes (trésorerie, desserte, chasse, réglementation). Si le profil expert n'est pas donné, l'agent le demande ; il ne le devine pas.
2. **Lecture** : fiche projet, 41 indicateurs, NDP et statuts, N5, T4, table des sondes (ce que les modèles voient et ne voient pas).
3. **Enumération** : `itineraires_admissibles()` — l'agent n'ajoute jamais un itinéraire absent du catalogue ; il peut proposer d'en ajouter un au catalogue, avec sources, par PR.
4. **Simulation et comparaison** : `simuler_itineraire()` puis `comparer_itineraires()` sous le profil choisi, puis sous les deux ou trois profils les plus opposés (gestionnaire ONF, naturaliste, propriétaire privé), pour rendre visibles les désaccords.
5. **Argumentation** : via le RAG (E7), chaque recommandation est reliée aux guides et aux publications du corpus ; les incertitudes de FINN et les angles morts des sondes sont dits explicitement.
6. **Restitution** : un plan d'actions structuré (format déjà consommé par `nemetonshiny` et par l'archive PDF spec 037), avec un paragraphe « ce qui ferait changer la recommandation » (seuils de réversibilité).
7. **Mémoire** : les choix du propriétaire et les itinéraires retenus sont mémorisés (skill `memory`) pour les projets suivants.

Garde-fous écrits dans le skill : pas de nombre hors sorties Néméton ; pas de recommandation sans au moins un itinéraire alternatif comparé ; signaler quand le recouvrement causal est insuffisant ; refuser de conclure sur une UGF dont le NDP est 0 sans le dire.

### 3.4 Couche 3 — Victor : la voix (ce qui se dit en deux phrases)

- Nouveaux outils dans `server.py` : `nemeton_itineraires(projet, ugf)` (lecture immédiate des itinéraires admissibles, comme `nemeton_fiche`), et délégation vers l'espace `aigora` pour « compare les itinéraires de X pour un objectif carbone » (tâche longue, retour par `[SYSTÈME]`).
- `display_report` reçoit un nouveau type de bloc `trajectoires` (courbes par itinéraire et par famille) et `pareto` (nuage des itinéraires).
- À voix haute : l'itinéraire retenu, la famille qui gagne, la famille qui perd, et la question « voulez-vous voir les alternatives ? ». Le reste va à l'écran.

### 3.5 Ce que cela n'est pas

Ce n'est pas un « AI scientist » autonome ni un optimiseur qui décide. L'évaluation sérieuse des agents LLM en 2026 montre qu'ils échouent à opérationnaliser le savoir tacite de domaine (choix des baselines, diagnostic d'erreurs). L'agent `sylviculteur` est un **compositeur et un contradicteur** : il énumère, simule, compare, cite, et rend visibles les désaccords entre profils. La décision reste au forestier, dans l'application ou sur le terrain.

## 4. Ordre proposé et effort

| Ordre | Chantier | Dépôts | Effort indicatif |
|---|---|---|---|
| 1 | A — AlphaEarth, N5, B4/L3 | `alphaearthnemeton`, `nemeton` | 2-3 semaines |
| 2 | B — MAESTRO extracteur + sondes | `maestronemeton`, `nemeton` | 1 mois |
| 3 | C — ForPT, B5, N4, T1, dimensionnement | `forptnemeton`, `nemeton` | 2 mois |
| 4 | 3.2 — catalogue d'itinéraires + `itineraires_admissibles` + `comparer_itineraires` (sans FINN, sur indicateurs statiques) | `nemeton`, `aigora` | 3 semaines |
| 5 | D — FINN, T4, `effet_gestion` | `nemeton` | année 2 |
| 6 | 3.3 / 3.4 — agent `sylviculteur` complet, voix | `aigora`, `victor` | après 4 et 5 |
| 7 | TerraMind | `nemeton` | si besoin outre-mer |

L'étape 4 est volontairement placée avant FINN : un comparateur d'itinéraires sur indicateurs statiques et règles de catalogue a déjà de la valeur, et il fixe les contrats d'interface que FINN viendra remplir.

## 5. Première action attendue de Claude Code

1. Lire ce brief, CLAUDE.md, PLAN.md, ADR-009, ADR-011, specs 005, 006, 009, 052, 057.
2. Produire `specs/064-alphaearth-n5/spec.md` (chantier A) et `specs/065-itineraires-catalogue/spec.md` (étape 4), en suivant le gabarit des specs existantes, avec les décisions ouvertes listées pour arbitrage.
3. Ouvrir dans PLAN.md les écarts cœur → app correspondants **avant** la première release.
4. Émettre les briefs dérivés vers `maestronemeton` (chantier B), `nemetonshiny` (vues), `aigora` (skill) et `victor` (outils).
5. Ne rien implémenter avant validation des deux specs.
