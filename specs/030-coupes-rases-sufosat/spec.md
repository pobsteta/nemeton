# Spec 030 — Indicateur T3 « Coupes rases » (SUFOSAT)

**Version** : 0.1.0
**Date**    : 2026-07-02
**Statut**  : Cadrée — à valider (paperwork avant code, non implémentée).
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` (feat mineur — nouvel indicateur T3).
**Cible app**  : `nemetonshiny` (affichage radar T3, brief séparé).
**Liens** : famille T (Dynamique temporelle : T1 ancienneté, T2 changement,
**T3 coupes rases**) ; s'appuie sur la source Theia/MTD `sufosat` ; ADR-011
(NDP), ADR-008 (sources par pays). **Nouvel ADR** : non (indicateur dans une
famille existante, source raster déclarative comme FORMS-T).

---

## 1. Objectif

Ajouter un **31+1ᵉ indicateur**, **T3 « Coupes rases »**, mesurant la
**pression de récolte par coupe rase** sur une unité de gestion forestière
(UGF), à partir du produit national **SUFOSAT** (*SUivi des FOrêts par
SATellite* — CNES/CESBIO) : détection submensuelle des coupes rases en
France métropolitaine par **changement radar Sentinel-1** (indépendant des
nuages).

Une coupe rase récente et étendue = perturbation anthropique forte du
couvert → l'indicateur est **« haut = beaucoup de coupe rase »** ; comme R5
(dépérissement), c'est un indicateur dont le **sens est inversé** à la
normalisation (`normalize_indicator`, cf. R5 v0.99.1) : plus de coupe rase →
indice normalisé bas.

## 2. Source de données (vérifiée le 2026-07-02)

- Collection STAC : **`sufosat`** (`api.stac.teledetection.fr`).
- **Une seule couverture nationale** par version (`id = v3-0-1_20180101_20250901`),
  couvrant 2018-01 → 2025-09.
- Deux assets raster : **`dates`** (date de la coupe rase détectée, par pixel)
  et **`proba`** (probabilité de détection). CRS/tuilage à confirmer à la
  lecture (K1).
- Méthode : détection de changement radar Sentinel-1 (submensuelle), carte
  des coupes rases France métropolitaine.

## 3. Sémantique de l'indicateur

Sur l'AOI d'une UGF, dans une fenêtre temporelle `[start, end]` :

```
surface_coupe = Σ pixels dont `dates` ∈ [start, end] ET `proba` ≥ seuil
T3_brut       = surface_coupe / surface_UGF        # fraction de coupe rase
```

Modulations proposées (décisions §4) : pondération par **récence** (une
coupe l'an dernier pèse plus qu'en 2018) et seuil de probabilité.

## 4. Décisions à trancher

| # | Sujet | Options / recommandation |
|---|-------|--------------------------|
| **D1** | Famille d'accueil | **T3** (Dynamique temporelle) recommandé — SUFOSAT est un produit de détection de changement, T2 mesure déjà le changement spectral générique, T3 isole l'événement anthropique « coupe rase ». Alternatives : R (perturbation/résilience), P (production/récolte), L (fragmentation). |
| **D2** | Fenêtre temporelle | Aligner sur la fenêtre d'analyse nemeton (paramètre `period`), ou fenêtre glissante fixe (p. ex. 5 dernières années). Reco : argument `window_years = 5` (récence pertinente pour la gestion). |
| **D3** | Pondération récence | Linéaire décroissante sur la fenêtre, ou binaire (coupé / pas coupé). Reco : linéaire (une coupe récente signale une pression actuelle). |
| **D4** | Seuil de probabilité | Seuil sur l'asset `proba` (écarter les détections douteuses). Reco : défaut `proba ≥ 0.5`, argument `min_proba`. |
| **D5** | Sens & normalisation | Indicateur **inversé** (haut = mauvais), comme R5. Enregistrer dans `indicator-config.R` (sens `"negative"`). |
| **D6** | Rétro-compat count | Nouvel indicateur → passe de 31 à 32 indicateurs de base (33 avec R5). Mettre à jour `CLAUDE.md`, la table des familles, `massif_demo_units` (colonne T3). |

## 5. Changements cœur (`nemeton`)

| # | Fichier | Changement |
|---|---------|-----------|
| A1 | `inst/datasources/FR.json` | Déclarer la source `sufosat` (type `raster_local`, assets `dates`/`proba`, `stac_api_service: theia_stac`, `stac_collection: sufosat`, `consumed_by: {T3}`, licence à confirmer). |
| A2 | `R/temporal.R` (ou `R/indicators-temporal.R`) | Nouvelle fonction exportée `indicateur_t3_coupes_rases(units, sufosat_dates = NULL, sufosat_proba = NULL, window_years = 5, min_proba = 0.5)`. `NULL` → indicateur neutre/`NA` (rétro-compat : pas de SUFOSAT = pas de T3, l'indice général l'ignore). |
| A3 | `R/indicator-config.R` | Config T3 : sens `negative`, bornes `[0,1]`, unité « fraction ». |
| A4 | `R/family-system.R` | Rattacher T3 à la famille T dans l'agrégation. |
| A5 | `R/normalization.R` | Vérifier l'inversion (réutilise le chemin R5). |
| A6 | `data-raw/` + `data/` | Ajouter une colonne T3 à `massif_demo_units` (fixture 20 UGF). |
| A7 | tests | `test-indicator-t3.R` : fraction de coupe, seuil proba, pondération récence, fenêtre, sens inversé, `NULL` → neutre. Rasters mockés (terra en mémoire). |
| A8 | doc/release | `CLAUDE.md` (compte + table familles), NEWS/CITATION/CHANGELOG/PLAN, NAMESPACE + `.Rd` à la main. `feat:` mineur. |

## 6. Critères d'acceptation

- [ ] `indicateur_t3_coupes_rases()` renvoie la fraction de coupe rase
      pondérée par récence, sur des rasters `dates`/`proba` de test.
- [ ] Seuil `min_proba` écarte les pixels sous le seuil.
- [ ] `window_years` restreint la fenêtre temporelle.
- [ ] Sens inversé : plus de coupe → indice normalisé plus bas.
- [ ] `sufosat_* = NULL` → indicateur neutre, indice général inchangé.
- [ ] `devtools::check()` clean.

## 7. Risques / réserves

- **R1** : CRS/tuilage/format des assets `dates`/`proba` à confirmer à la
  lecture réelle (K1). L'asset `dates` peut encoder la date en jours-depuis-
  époque ou en année — à vérifier avant d'écrire la logique de fenêtre.
- **R2** : SUFOSAT détecte la **coupe rase** (perte franche), pas les coupes
  d'amélioration/éclaircies — l'indicateur mesure la récolte *rase*, pas la
  récolte totale. À documenter (ne pas sur-interpréter comme « pression
  sylvicole » globale).
- **R3** : recouvrement conceptuel avec R2 (tempête, chablis) et R5
  (dépérissement) — tous des pertes de couvert. T3 se distingue par la
  **signature anthropique franche** de la coupe rase ; à cadrer pour éviter
  le double comptage dans un futur indice de perturbation composite.
