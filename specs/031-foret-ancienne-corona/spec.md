# Spec 031 — Forêt ancienne : helper `build_foret_ancienne_mask()` (renforce N2)

**Version** : 0.2.0
**Date**    : 2026-07-02
**Statut**  : **Réorientée puis implémentée (2026-07-02, v0.113.0).** Le
plan initial (nouvel indicateur **N4** alimenté par **Corona 4B**) est
**abandonné** après deux constats bloquants sur données réelles :

1. **Corona 4B n'a aucune couverture France** : la collection Theia
   `corona-4b` ne contient que 3 items, tous au Moyen-Orient (lon 44-53°E).
   Inutilisable pour une forêt ancienne française.
2. **N2 gère déjà la forêt ancienne** : `indicateur_n2_continuite()` a déjà
   un argument `foret_ancienne` (fraction ancienne → score 60-100). Un N4
   dédié serait redondant et double-compterait dans la famille N.

**Décision utilisateur (2026-07-02)** : *abandonner N4, renforcer N2*. Le
livrable est un **helper source-agnostique `build_foret_ancienne_mask()`**
qui construit la couche `foret_ancienne` que N2 consomme déjà, depuis une
source historique fournie par l'utilisateur (Cassini / état-major / IGN forêt
ancienne, raster classé ou vecteur). Aucun nouvel indicateur, aucune source
morte. Le reste de ce document (§ N4) est **conservé pour trace historique**.

---

## 0. Livrable retenu (v0.2.0) — `build_foret_ancienne_mask()`

Fonction exportée `build_foret_ancienne_mask(source, forest_class = NULL,
threshold = NULL, min_area_m2 = 0, crs = NULL)` (`R/indicators-naturalness.R`) :

- **Source vecteur** (sf/sfc) : forêt ancienne déjà vectorisée → validée
  (`st_make_valid`), reprojetée, filtrée par aire, marquée `foret_ancienne`.
- **Source raster** (SpatRaster) : masque forêt dérivé par classe
  (`forest_class`), par seuil (`threshold`), ou `valeur > 0` à défaut →
  polygonisé (`terra::as.polygons`), scindé en taches contiguës, filtré par
  aire.
- **Sortie** : couche sf `foret_ancienne = TRUE`, passée telle quelle à
  `indicateur_n2_continuite(units, foret_ancienne = ...)`.

Tests : `test-foret-ancienne-mask.R` (raster/classe, seuil, vecteur, filtre
aire, intégration N2 → score 100 sur forêt ancienne totale, type invalide).
`corona-4b` **non déclaré** dans `FR.json` (aucune couverture France).

---

<details><summary>Plan initial abandonné — Indicateur N4 « Forêt ancienne » (Corona 4B)</summary>

**Statut initial** : Cadrée — à valider (paperwork avant code, non implémentée).
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` (feat mineur — nouvel indicateur N4).
**Cible app**  : `nemetonshiny` (radar N4, brief séparé).
**Liens** : famille N (Naturalité : N1 distance infra, N2 continuité, N3
composite, **N4 forêt ancienne**) ; renforce aussi **T1 (ancienneté)** ;
source Theia/MTD `corona-4b` ; ADR-011 (NDP), ADR-008. **Nouvel ADR** : non.

---

## 1. Objectif

Ajouter l'indicateur **N4 « Forêt ancienne »** : la fraction d'une UGF
**boisée de façon continue depuis une date de référence historique**
(~1965-1970), établie à partir de l'imagerie **Corona 4B** — photographies
des satellites espions américains déclassifiés (domaine visible,
panchromatique). Une forêt présente il y a ~60 ans **et** aujourd'hui est
une **forêt ancienne** au sens écologique : sols non perturbés, cortège
floristique et fonctionnel de plus grande valeur — un signal de naturalité
que le NDP 0 (données récentes seules) ne peut pas produire.

Indicateur **« haut = bon »** (plus de forêt ancienne → naturalité plus
élevée) : sens direct, pas d'inversion.

## 2. Source de données (vérifiée le 2026-07-02)

- Collection STAC : **`corona-4b`** (`api.stac.teledetection.fr`).
- Items = scènes historiques déclassifiées, **datetime ~1968**
  (`id = ds1110-…`), asset **`src`** (imagerie panchromatique).
- **Couverture partielle** (imagerie espion, pas de fauchée systématique
  France entière) → l'indicateur est **conditionnel à la disponibilité**
  d'une scène Corona sur l'AOI (comme R5 est conditionné par FORDEAD).

## 3. Sémantique de l'indicateur

Deux ingrédients : un **masque forêt historique** (dérivé de Corona ~1968)
et le **masque forêt actuel** (déjà disponible : BD Forêt / couvert nemeton).

```
foret_ancienne = forêt_1968 ∩ forêt_aujourd'hui
N4_brut        = surface(foret_ancienne) / surface_forêt_actuelle_UGF
```

L'extraction du masque forêt 1968 depuis une image panchromatique n'est
**pas triviale** (une seule bande, contraste variable) — c'est le cœur
technique du chantier (§4 D2).

## 4. Décisions à trancher

| # | Sujet | Options / recommandation |
|---|-------|--------------------------|
| **D1** | Famille & statut | **N4** (Naturalité) recommandé — la forêt ancienne est un concept de valeur écologique/naturalité. Renforce aussi **T1 (ancienneté)** comme *source* (Corona confirme l'ancienneté au-delà des proxies récents). Alternative : upgrade de N2/T1 sans nouvel indicateur. |
| **D2** | Extraction forêt 1968 | (a) **Seuillage + texture** sur le panchromatique (la forêt a une texture rugueuse sombre caractéristique) ; (b) **classification ML** légère ; (c) **masque fourni** par l'utilisateur (Corona pré-classifié hors nemeton). Reco : commencer par (c) argument `forest_mask_1968` fourni + helper (a) `corona_forest_mask()` best-effort, ML reporté. |
| **D3** | Recalage géométrique | Corona 1968 n'est pas ortho-rectifié nativement → recalage sur le référentiel actuel nécessaire. Reco : supposer l'asset déjà géoréférencé (à vérifier K1) ; sinon, hors scope v1 (masque pré-recalé fourni). |
| **D4** | Date de référence | ~1968 (Corona) comme seuil « forêt ancienne ». Documenter que c'est ~60 ans, pas les 200 ans de la définition stricte « forêt ancienne » forestière. Nommer prudemment : « continuité forestière ≥ ~1968 ». |
| **D5** | Disponibilité conditionnelle | Pas de scène Corona sur l'AOI → N4 = `NA` (neutre, exclu de l'indice), comme R5 sans FORDEAD. |
| **D6** | Count indicateurs | +1 indicateur (N passe de N1-N3 à N1-N4). Mettre à jour `CLAUDE.md`, table familles, `massif_demo_units`. |

## 5. Changements cœur (`nemeton`)

| # | Fichier | Changement |
|---|---------|-----------|
| A1 | `inst/datasources/FR.json` | Source `corona-4b` (type `raster_local`, asset `src`, `stac_collection: corona-4b`, `consumed_by: {N4, T1}`, licence domaine public US à confirmer). |
| A2 | `R/indicators-naturalness.R` | `indicateur_n4_foret_ancienne(units, forest_mask_1968 = NULL, forest_mask_now = NULL)` → fraction de continuité. `NULL` → `NA` (conditionnel D5). |
| A3 | `R/utils.R` (ou `R/utils-corona.R`) | Helper best-effort `corona_forest_mask(corona_panchro, ...)` (seuillage + texture, D2 option a). |
| A4 | `R/indicator-config.R` | Config N4 : sens `positive`, bornes `[0,1]`. |
| A5 | `R/family-system.R` | Rattacher N4 à la famille N. |
| A6 | `data-raw/` + `data/` | Colonne N4 dans `massif_demo_units`. |
| A7 | tests | `test-indicator-n4.R` : intersection masques, fraction, `NULL` → `NA`, helper masque sur raster synthétique. |
| A8 | doc/release | `CLAUDE.md`, NEWS/CITATION/CHANGELOG/PLAN, NAMESPACE + `.Rd` main. `feat:` mineur. |

## 6. Critères d'acceptation

- [ ] `indicateur_n4_foret_ancienne()` = fraction forêt_1968 ∩ forêt_now.
- [ ] Absence de masque 1968 → `NA` (indicateur conditionnel, indice général
      inchangé).
- [ ] Sens direct : plus de continuité → indice plus haut.
- [ ] `corona_forest_mask()` produit un masque binaire depuis un
      panchromatique synthétique de test.
- [ ] `devtools::check()` clean.

## 7. Risques / réserves

- **R1 (majeur, D2)** : l'extraction automatique du couvert forestier sur
  une **seule bande panchromatique** de 1968 est le vrai risque technique —
  qualité variable, pas de NIR, pas de couleur. La v1 s'appuie sur un masque
  fourni ; l'automatisation ML est un chantier en soi.
- **R2 (D3)** : géoréférencement/recalage des scènes Corona — si l'asset
  n'est pas ortho-rectifié, l'intersection avec le masque actuel est
  faussée. À vérifier en tout premier (K1).
- **R3** : couverture spatiale lacunaire → N4 souvent `NA`. Assumé (comme
  R5) ; l'intérêt est là où Corona existe.
- **R4** : « forêt ancienne » a une **définition écologique stricte**
  (continuité depuis le milieu du XIXᵉ, cartes d'état-major). ~1968 n'est
  qu'une borne pragmatique — ne pas sur-vendre le terme. Nommage prudent
  requis dans l'UI et l'i18n.

</details>
