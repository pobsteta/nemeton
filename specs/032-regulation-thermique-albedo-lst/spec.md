# Spec 032 — Indicateur A3 « Régulation thermique / microclimat » (albédo S2 + LST)

**Version** : 0.1.0
**Date**    : 2026-07-02
**Statut**  : Cadrée — à valider (paperwork avant code, non implémentée).
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` (feat mineur — nouvel indicateur A3).
**Cible app**  : `nemetonshiny` (radar A3, brief séparé).
**Liens** : famille A (Air & Microclimat : A1 couverture arborée, A2 qualité
air, **A3 régulation thermique**) ; **résout l'inadéquation `theia_lst → A2`**
documentée au chantier Sources Theia (câbler la LST sur A2 dénaturait A2 =
pollution). S'aligne sur la **spec 027 (régénération / microclimat)**. Sources
`cesbio-s2albedo` + `thermocity-lst`. ADR-011, ADR-008. **Nouvel ADR** : non.

---

## 1. Objectif

Ajouter l'indicateur **A3 « Régulation thermique »** mesurant le **service
de rafraîchissement / microclimat** rendu par le couvert forestier, à partir
de deux signaux physiques complémentaires :

- **Albédo de surface Sentinel-2** (`cesbio-s2albedo`, asset `SWA`) — la
  forêt a un albédo plus bas (absorbe plus), mais son évapotranspiration
  domine le bilan et **rafraîchit** ; l'albédo caractérise le bilan radiatif.
- **Température de surface (LST)** (`thermocity-lst`, asset `LST`,
  ECOSTRESS/ASTER) — mesure directe de la fraîcheur de surface : une forêt
  fonctionnelle présente une LST **plus basse** que son environnement.

A3 combine ces signaux en un indice de **régulation thermique** :
**« haut = bon »** (forêt fraîche, fort effet régulateur → indice élevé).
Sens direct.

## 2. Sources de données (vérifiées le 2026-07-02)

| Source | Collection | Asset | Couverture | Note |
|--------|-----------|-------|-----------|------|
| Albédo S2 | `cesbio-s2albedo` | `SWA` (short-wave albedo) + `QL` | **France entière**, tuilé MGRS, **saisonnier** (`start/end_datetime`) ✅ | Base solide, couverture nationale. |
| LST | `thermocity-lst` | `LST` + `QL` + `ZIP` | **5 métropoles seulement** (Marseille, Montpellier, Paris, Strasbourg…) ⚠️ | ECOSTRESS/ASTER thermique. **Couverture urbaine, pas forestière.** |

**Conséquence de couverture** (décision structurante D1) : l'albédo est
national ; la LST Thermocity **ne couvre pas les massifs forestiers**. A3
doit donc être **modulaire** : calculable à partir de l'albédo seul
(national), la LST venant **raffiner** l'indice là où elle existe (interface
forêt-ville, trames vertes urbaines) — pas l'inverse.

## 3. Sémantique de l'indicateur

```
# Composante albédo (nationale) — bilan radiatif du couvert
A3_albedo = f(SWA)                         # normalisée, forêt dense = référence

# Composante LST (optionnelle, là où disponible) — fraîcheur relative
A3_lst    = 1 − norm(LST_UGF − LST_reference_locale)

A3 = A3_albedo                              si LST absente
A3 = w·A3_albedo + (1−w)·A3_lst             si LST présente   (w défaut 0.6)
```

L'exacte forme des composantes (surtout la référence de fraîcheur pour la
LST) est à caler — décisions §4.

## 4. Décisions à trancher

| # | Sujet | Options / recommandation |
|---|-------|--------------------------|
| **D1** | Architecture modulaire | **Albédo = socle national, LST = raffinement optionnel** (reco, imposé par la couverture Thermocity 5 métropoles). A3 calculable partout via l'albédo ; `lst = NULL` → composante LST ignorée (rétro-compat, comme les args Theia optionnels de R3). |
| **D2** | Sens de l'albédo | L'albédo seul n'est **pas monotone** vis-à-vis du service (forêt = albédo bas mais rafraîchit par ET ; sol nu clair = albédo haut mais chaud). Reco : ne pas utiliser l'albédo brut comme « bon/mauvais » ; l'employer comme **descripteur du type de surface** (proximité à une signature « forêt dense fonctionnelle ») plutôt qu'échelle linéaire. À caler soigneusement (risque de contresens physique). |
| **D3** | Référence LST | Fraîcheur **relative** : LST de l'UGF vs LST locale (médiane d'une zone tampon) — la forêt doit être plus froide. Reco : référence = tampon autour de l'UGF, saison chaude (juin-août). |
| **D4** | Saison | Le service de rafraîchissement se juge en **été**. Reco : composites saisonniers chauds (l'albédo `cesbio-s2albedo` est déjà saisonnier). |
| **D5** | Poids w albédo/LST | Défaut `w = 0.6`, argument. |
| **D6** | Lien spec 027 | Vérifier la cohérence/non-doublon avec la spec 027 (régénération/microclimat) : A3 = **service rendu à l'échelle UGF** ; spec 027 = microclimat **sous couvert** pour la régénération. Distincts mais à articuler (décision commune). |
| **D7** | Count indicateurs | +1 (A passe de A1-A2 à A1-A3). `CLAUDE.md`, table familles, `massif_demo_units`. |

## 5. Changements cœur (`nemeton`)

| # | Fichier | Changement |
|---|---------|-----------|
| A1 | `inst/datasources/FR.json` | Sources `cesbio-s2albedo` (asset `SWA`) + `thermocity-lst` (asset `LST`) : `stac_collection`, `consumed_by: {A3}`, couverture documentée (LST = métropoles). |
| A2 | `R/indicators-air.R` | `indicateur_a3_regulation_thermique(units, albedo = NULL, lst = NULL, lst_reference = NULL, w = 0.6)`. Albédo requis pour un score ; `lst = NULL` → composante LST ignorée. Les deux `NULL` → `NA`. |
| A3 | `R/indicator-config.R` | Config A3 : sens `positive`, bornes `[0,1]`. |
| A4 | `R/family-system.R` | Rattacher A3 à la famille A. |
| A5 | `data-raw/` + `data/` | Colonne A3 dans `massif_demo_units`. |
| A6 | tests | `test-indicator-a3.R` : composante albédo seule, fusion albédo+LST (w), fraîcheur relative, `lst = NULL` → albédo seul, tout `NULL` → `NA`. Rasters synthétiques. |
| A7 | doc/release | `CLAUDE.md`, NEWS/CITATION/CHANGELOG/PLAN, NAMESPACE + `.Rd` main. `feat:` mineur. |

## 6. Critères d'acceptation

- [ ] `indicateur_a3_regulation_thermique()` calcule un score depuis l'albédo
      seul (cas national).
- [ ] Fournir la LST raffine le score selon `w` ; fraîcheur relative correcte
      (UGF plus froide que la référence → score plus haut).
- [ ] `lst = NULL` → score = composante albédo seule (rétro-compat).
- [ ] `albedo = NULL & lst = NULL` → `NA` (indice général inchangé).
- [ ] `devtools::check()` clean.

## 7. Risques / réserves

- **R1 (majeur, D2)** : **risque de contresens physique** sur l'albédo. Un
  albédo bas peut signaler une forêt (rafraîchissante) *ou* une surface
  sombre chaude. L'albédo seul ne monte pas linéairement avec le service —
  d'où l'usage comme descripteur de type de surface, pas comme échelle
  directe. C'est le point à caler avec le plus de soin (idéalement adossé à
  la littérature Cesbio sur l'albédo HR S2).
- **R2 (D1)** : la LST Thermocity **ne couvre pas les forêts** (5 métropoles)
  → A3 reposera en pratique **surtout sur l'albédo** en contexte forestier.
  La LST n'apporte que sur l'interface forêt-ville. Chercher une source LST
  nationale (ECOSTRESS brut, LST Copernicus) est un chantier ultérieur.
- **R3 (D6)** : articulation avec la spec 027 (microclimat de régénération) —
  éviter deux indicateurs microclimat redondants ; décider du partage de
  périmètre avant impl.
