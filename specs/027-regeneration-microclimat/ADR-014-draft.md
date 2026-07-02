# ADR-014 (brouillon) — reGénération : moteurs GPL isolés en `regen_nemeton`, contrat MIT au cœur

> **Brouillon** rédigé côté `nemeton` (spec 027 v2). **À porter dans
> `platform_nemeton/docs/`** par Pascal (règle #11 : cette session ne modifie
> pas les repos frères). Statut proposé : **Proposé — à valider.**

**Date** : 2026-07-02
**Statut** : Proposé (à valider)
**Contexte spec** : 027 (Onglet « reGénération », vulnérabilité climatique par
parcelle).
**Amende** : ADR-009 (séparation des repos — ajoute un 5ᵉ repo), ADR-011 (NDP
augmenté — flag `microclimate_model`).

## Contexte

L'onglet « reGénération » (spec 027) prioritise les parcelles face au
changement climatique en croisant **deux moteurs mécanistes** :

- **exposition microclimatique** sous couvert (`microclimf`) alimentée par le
  **PAI LiDAR HD** (`lidR` / `lasR`) et un forçage ERA5-Land ;
- **bilan hydrique du sol** (`biljouR`, réimplémentation R de BILJOU) forcé par
  SAFRAN.

**Problème de licence** : `microclimf`, `biljouR`, `lidR`, `lasR` sont tous
**GPL-3**. Le cœur `nemeton` est **MIT** (ADR-006). En faire des `Imports` (ou
même les invoquer depuis le cœur) contaminerait la licence du cœur ou créerait
une ambiguïté GPL/MIT indésirable. Un premier jet (spec 027 v1) les avait mis
au cœur en `Suggests` — insuffisant : le code moteur (orchestration microclimf,
PAI, BILJOU) vivrait quand même dans un package MIT.

## Décision

1. **Créer un 5ᵉ repository `regen_nemeton` sous licence GPL-3** qui héberge
   **tous les moteurs GPL** : `pai_depuis_nuage` (PAI LiDAR), l'orchestration
   `microclimf` (exposition), l'intégration `biljouR` (bilan hydrique), le
   croisement `regen_priorite`.
2. **`nemeton` (MIT) ne fait que déclarer et normaliser le contrat**
   d'indicateurs : sous-indicateurs microclimat (A3/A4/W4/R6), enrichissement
   de `r3_secheresse` par les métriques BILJOU, normalisation 0-100, schéma de
   colonnes de sortie. Le cœur **consomme des rasters / `sf` précalculés** et
   n'a **aucune dépendance GPL** (`DESCRIPTION` vérifié en R-CMD-check).
3. **`nemetonshiny` (EUPL v1.2)** orchestre : il dépend de `nemeton` **et** de
   `regen_nemeton` (EUPL v1.2 est compatible GPL-3 en distribution), lance les
   moteurs en tâche de fond, historise (PostGIS) et exporte.
4. **Sens des dépendances** : `regen_nemeton → nemeton` (contrat) ;
   `nemetonshiny → {nemeton, regen_nemeton}`. Jamais l'inverse.
5. **Réconciliation de l'existant** : les indicateurs A3/A4/W4/R6 déjà livrés
   au cœur **restent** (ils consomment un `micro` précalculé, sans dép GPL) ;
   `microclimate_run()` (scaffold appelant microclimf) **migre** vers
   `regen_nemeton`. `regeneration_index` est **retravaillé** en
   `indice_priorite_regen` (croisement exposition × stress hydrique).

## Conséquences

**Positives**
- Cœur MIT préservé (pas de contamination GPL), conforme ADR-006.
- Frontière nette « déclaration/normalisation » (MIT) vs « calcul mécaniste »
  (GPL), cohérente avec la logique multi-repo ADR-009.
- Les moteurs GPL sont réutilisables hors Néméton.

**Coûts / risques**
- Un repo de plus à maintenir (CI, releases, doc) — 5 repos au total.
- `regen_nemeton` dépend du contrat `nemeton` : tout changement de schéma de
  colonnes doit être versionné et coordonné.
- Crédibilité BILJOU : réimplémentation non cautionnée INRAE → calibration à
  planifier (spec 027 §9.2) ; sorties communiquées en **classement relatif**.

## Alternatives écartées

- **Moteurs au cœur en `Suggests`** (spec 027 v1) : le code GPL vivrait dans un
  package MIT — écarté (ambiguïté de licence, viole l'esprit d'ADR-006).
- **Tout dans `nemetonshiny`** : mélange calcul mécaniste lourd et présentation,
  casse la règle « aucune logique métier dans l'app » (CLAUDE.md) — écarté.
- **Passer le cœur en GPL** : régression de licence pour un package cœur voulu
  permissif (MIT, ADR-006) — écarté.

## Points ouverts (renvoyés à la validation spec 027 §10)

- Nom et org exacts de `regen_nemeton`.
- Tag NDP des indicateurs modélisés mécanistes (NDP 1 forcé vs tag dédié).
- Sort de la pénalité par essence de `regeneration_index` (hors brief).
