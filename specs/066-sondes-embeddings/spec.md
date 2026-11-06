# Spec 066 — Sondes « ce que les modèles voient » et MAESTRO en extracteur d'embeddings

> **Statut** : **brouillon, à valider par Pascal**. Rien n'est implémenté avant
> validation (procédure du brief du 2026-11-05, § 5).
> **Origine** : brief « Modèles de fondation et raisonnement sylvicole » du
> 2026-11-05, chantier B (priorité 2) ; préavis
> `specs/064-alphaearth-n5/brief-maestronemeton.md`.
> **Dépôts** : `nemeton` (sondes, génériques) et `maestronemeton` (extracteur).
> **Décisions ouvertes** : § 7, renvoyées par **[D-n]**.

## 1. Pourquoi

Le chantier A a branché AlphaEarth : N5, B4/L3 en mode embedding,
`embedding_regress()`. Une question reste sans réponse chiffrée : **que voit
un modèle de fondation des indicateurs de Néméton ?** La fiche « Modèles de
fondation » le dit en toutes lettres (angle mort n° 3) : le modèle n'a pas été
entraîné pour la forêt française, ce qu'il voit d'un indicateur n'est pas
connu d'avance.

Une **sonde** répond par une mesure : sur un projet, on ajuste une régression
de l'embedding moyen de chaque UGF vers un indicateur déjà calculé, et l'on
lit son R² en validation croisée spatiale. R² élevé : l'embedding contient
l'information de l'indicateur. R² faible : angle mort, documenté.

## 2. Ce que le cœur a déjà (2026.11.2)

| Brique | Où |
|---|---|
| Embedding moyen par UGF | `embedding_summary()` (`R/embeddings.R`) |
| Ridge en base R, pénalité par GCV | `.ridge_ajuste()`, `.ridge_predit()` (`R/embedding_regress.R`) |
| Validation croisée par blocs spatiaux | `embedding_regress()` (même fichier), à factoriser |
| 42 indicateurs, statuts, normalisation | `list_indicators()`, `normalize_indicator()` |

Les sondes ne demandent **aucune dépendance nouvelle** et fonctionnent dès
aujourd'hui avec AlphaEarth : MAESTRO n'est pas un prérequis.

## 3. Sondes (cœur)

```r
probe_indicator(units, embedding, indicateurs = NULL, normalise = TRUE,
                taille_bloc_m = 2000, n_plis = 5, min_unites = 50L)
```

- `units` : UGF du projet avec les colonnes d'indicateurs déjà calculées.
  `indicateurs = NULL` : toutes les colonnes de `list_indicators()` présentes.
- Caractéristiques : `embedding_summary(units, embedding)$mean`.
- Pour chaque indicateur : UGF où l'indicateur et l'embedding sont connus ;
  ridge (GCV) ; validation croisée par blocs spatiaux sur les centroïdes des
  UGF (blocs de 2 km : les UGF sont plus petites que des placettes IFN
  dispersées, D-2). Moins de `min_unites` UGF utilisables ou variance nulle :
  pas de sonde, statut.
- Sortie : une ligne par indicateur — `code`, `famille`, `n`, `r2`, `rmse`,
  `lecture` (`voit`, `partiel`, `angle_mort`, D-1), `statut`
  (`ok`, `trop_peu_unites`, `variance_nulle`, `indicateur_absent`),
  `source_embedding` (`aef`, `maestro`, `forpt`).
- `normalise = TRUE` : la sonde porte sur la valeur normalisée 0-100
  (`normalize_indicator()` avec le statut), ce qui rend les RMSE comparables
  d'un indicateur à l'autre.

**Fonction factorisée** : la validation croisée par blocs de
`embedding_regress()` devient un utilitaire interne commun
(`.cv_blocs_spatiaux()`), sans changer le comportement de
`embedding_regress()` (ses tests le vérifient).

## 4. Pièges à écrire dans la fiche

1. **Information partagée, pas vision.** Plusieurs indicateurs sont calculés
   à partir de Sentinel-2 (C2, B4, L3, A1 selon la source), comme AlphaEarth.
   Un R² élevé peut venir de l'entrée commune, pas d'une compréhension
   forestière. La sortie marque ces indicateurs (`source_commune`).
2. **Propre au projet.** Un R² mesuré sur Dabo ne vaut que pour Dabo :
   un indicateur sans variance dans le projet aura un R² nul sans que le
   modèle soit aveugle.
3. **Une sonde n'est pas un estimateur.** Un R² de 0,6 ne permet pas de
   remplacer l'indicateur par sa prédiction (D-3).
4. **Petits projets.** En dessous de 50 UGF, la validation croisée est trop
   bruitée pour être lue : pas de sonde.

## 5. MAESTRO en extracteur (`maestronemeton`, brief dérivé)

Repris du préavis `brief-maestronemeton.md`, précisé ici pour ce que le cœur
attend :

- `maestro_embed(aoi, modalities)` rend un **SpatRaster de 64 bandes**
  (réduction PCA **fixe et versionnée**, ajustée une fois sur un corpus BFC),
  `attr(, "embedding_source") = "maestro"`. Le cœur l'accepte partout où il
  accepte AlphaEarth : N5, `embedding_regress()`, sondes.
- **Exception** : B4/L3 en mode embedding restent réservés à AlphaEarth, leur
  dictionnaire de clusters étant appris dans l'espace AlphaEarth. La
  vérification existe déjà (même dimension), mais deux espaces de
  64 dimensions passeraient : le cœur refusera explicitement une source autre
  qu'`aef` (D-4).
- Normalisation globale des modalités (défaut `_normaliser_mnt()` min-max par
  batch à corriger côté `maestronemeton`).
- BD Forêt v3 : `map_bdforet_essence()` accepte la nomenclature v3 quand elle
  sera publiée (D-5).

## 6. App (brief dérivé `brief-nemetonshiny.md`, à écrire après validation)

Vue « Ce que les modèles voient » : la table des sondes du projet, triée par
R², avec la lecture et le marqueur `source_commune`. **Écart n° 25**, ouvert
dans PLAN.md dès cette spec.

## 7. Décisions ouvertes

| # | Question | Proposition |
|---|---|---|
| D-1 | Seuils de lecture du R² | `voit` ≥ 0,5 ; `partiel` 0,2 à 0,5 ; `angle_mort` < 0,2. Conventions, affichées comme telles |
| D-2 | Taille des blocs de la validation croisée | 2 km par défaut (UGF de quelques hectares) ; paramètre exposé |
| D-3 | Le brief propose d'utiliser une sonde à R² élevé pour **fournir** l'indicateur en NDP augmenté là où sa source manque | **Non** dans cette spec : une sonde est un diagnostic. Remplacer un indicateur relève d'`embedding_regress()`, avec une cible mesurée sur le terrain |
| D-4 | B4/L3 en mode embedding avec MAESTRO ou ForPT | non : AlphaEarth seulement (dictionnaire appris dans son espace) |
| D-5 | BD Forêt v3 | attendre la publication de la nomenclature ; rien dans le cœur avant |
| D-6 | Ordre | sondes d'abord, sur AlphaEarth (cœur seul) ; MAESTRO ensuite (`maestronemeton`) |

## 8. Critères d'acceptation

1. `probe_indicator()` testée sur des embeddings synthétiques : un indicateur
   construit comme combinaison linéaire de l'embedding → R² > 0,8 et `voit` ;
   un indicateur aléatoire → R² < 0,1 et `angle_mort` ; projet de 30 UGF →
   `trop_peu_unites`.
2. `embedding_regress()` inchangé après la factorisation (ses 24 assertions).
3. Table des sondes AlphaEarth sur un projet réel d'au moins 50 UGF, publiée
   dans la fiche « Modèles de fondation ».
4. Fiche de la fonction avec les quatre pièges du § 4.
