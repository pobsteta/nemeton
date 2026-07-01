# Spec 028 — Diversité spectrale : indicateurs B4 & L3 (biodivMapR)

**Statut :** livré v0.110.0 (logique validée hors biodivMapR ; pipeline réel = smoke manuel + recalibrage bornes D3)
**Auteur :** Pascal Obstetar
**Date :** 2026-07-01
**Familles impactées :** B (Biodiversité), L (Paysage)
**Dépendance amont :** [`biodivMapR`](https://jbferet.github.io/biodivMapR/) (Féret & de Boissieu, *Methods in Ecology and Evolution*, 2020), **GPL-3**.

---

## 1. Contexte et objectif

Au **NDP 0** (Sentinel-2 public), la famille **B** repose surtout sur des
couvertures réglementaires (B1), une hétérogénéité de hauteur via CV(CHM) (B2)
et une continuité/proximité d'habitats (B3) : aucun **signal télédétecté direct**
de diversité biologique. La famille **L** (L1 sylvosphère, L2 fragmentation)
n'exploite pas non plus la **texture spectrale** du paysage.

`biodivMapR` calcule de la **diversité spectrale** (α et β) à partir d'imagerie
optique — **y compris Sentinel-2** (10-20 m) — via l'hypothèse de variation
spectrale (Palmer 2002) : l'hétérogénéité spectrale corrèle avec la diversité
compositionnelle/fonctionnelle. La méthode est directement exploitable au NDP 0,
là où B est aujourd'hui la plus pauvre.

**Objectif.** Ajouter **deux nouveaux indicateurs** (pas de refonte de
l'existant) :

- **B4 — Diversité spectrale** (α-diversité, Shannon des *spectral species*) ;
- **L3 — Hétérogénéité spectrale paysagère** (β-diversité, turnover spatial).

Portés par une seule primitive cœur qui appelle `biodivMapR` et consomme ses
rasters de diversité.

## 2. Méthode biodivMapR (rappel)

1. **PCA** sur les bandes réflectance (Sentinel-2 : B2,B3,B4,B5,B6,B7,B8,B8A,
   B11,B12 après masque nuages).
2. Sélection d'un sous-ensemble de composantes → **k-means** → carte de
   **spectral species** (clusters spectraux servant de « pseudo-espèces »).
3. Par **fenêtre spatiale** (Spatial Unit, p.ex. 10×10 pixels) :
   - **α-diversité** : richesse, **Shannon**, Simpson (→ B4) ;
   - **β-diversité** : dissimilarité **Bray-Curtis** entre fenêtres +
     ordination (PCoA/NMDS) → **turnover** spatial (→ L3).

Sorties = **rasters** de diversité à la résolution de la fenêtre, agrégés par UGF
via `exactextractr` (moyenne pondérée par surface), comme les autres indicateurs
raster du cœur.

## 3. Décision de licence — GPL-3 pour la plateforme (amende ADR-006)

`biodivMapR` est **GPL-3**. Choix **assumé et confirmé** (Pascal, 2026-07-01,
après alerte explicite sur la portée) : **intégration en `Imports:` direct** du
cœur, ce qui fait de `nemeton` une **œuvre dérivée GPL-3**.

**Portée (blast radius) — à exécuter dans chaque dépôt :**

| Repo | Action licence |
|------|----------------|
| `nemeton` | `LICENSE`/`LICENSE.md` MIT → **GPL-3** ; `DESCRIPTION` `License: GPL-3` ; ce repo. |
| `nemetonshiny` | Importe nemeton → **GPL-3** à la distribution. Basculer `LICENSE` + `DESCRIPTION`. |
| `tree_sat_nemeton` | Idem (dépend de nemeton). Repo distant, **à faire sur place**. |
| `maestro_nemeton` | Idem. Repo distant, **à faire sur place**. |
| `platform_nemeton` | **Amender ADR-006** : acter GPL-3 pour les packages R (au lieu de MIT), motif = dépendance biodivMapR pour B4/L3. Repo distant. |

**Invariants légaux.** (1) Les données restent CC-BY 4.0 (ADR-006 inchangé sur
ce volet). (2) Le basculement ne « dé-contamine » pas les versions MIT déjà
publiées ; il vaut à partir de la release qui l'introduit. (3) **Irréversible en
pratique** : un retour MIT exigerait l'accord de tous les contributeurs.

> **Alternative rejetée** (consignée pour traçabilité) : isolation
> `biodivMapR` en `Suggests:` + appel en sous-process R (précédent FORDEAD,
> ADR-013), qui aurait conservé MIT pour mêmes B4/L3. Écartée sur décision du
> propriétaire au profit d'une intégration `Imports:` directe.

## 4. Indicateur B4 — Diversité spectrale (famille B)

- **Nom NMT :** `indicateur_b4_div_spectrale` (≤ 30 car.).
- **Label :** FR « Diversité spectrale » / EN « Spectral Diversity ».
- **Entrée :** cube Sentinel-2 réflectance (déjà mobilisé par C2/FAST/RECONFORT),
  masque forêt (BD Forêt / UGF), masque nuages.
- **Métrique :** **Shannon** des spectral species par fenêtre → agrégé par UGF.
- **Sens :** *haut = mieux* (plus de diversité compositionnelle). **Caveat
  documenté** : une futaie régulière monospécifique **légitime** a une diversité
  spectrale basse → « bas » ≠ « faible valeur » ; la normalisation borne sur une
  plage plausible et le tooltip précise la limite d'interprétation.
- **Normalisation :** `[0..1]` via bornes plausibles Shannon spectral
  (à caler empiriquement, provisoirement `[0, log(n_clusters)]`).
- **Argument optionnel :** `spectral = NULL` sur la fonction → strictement
  rétrocompatible (comme le pattern `chm = NULL` de la spec 005).

## 5. Indicateur L3 — Hétérogénéité spectrale paysagère (famille L)

- **Nom NMT :** `indicateur_l3_het_spectrale` (≤ 30 car.).
- **Label :** FR « Hétérogénéité spectrale » / EN « Spectral Heterogeneity ».
- **Métrique :** **β-diversité** (dissimilarité Bray-Curtis / turnover des
  spectral species entre l'UGF et son voisinage) → mosaïque paysagère.
- **Sens (D1 tranché) :** *haut = mieux*. L3 mesure l'hétérogénéité de
  **composition** (turnover spectral des spectral species) : une mosaïque
  diversifiée vaut mieux qu'un paysage spectralement uniforme. **Orthogonal à
  L2**, qui mesure la fragmentation **géométrique** (morcellement des patchs) —
  deux angles distincts, explicités dans les tooltips (L3 = diversité de la
  mosaïque, L2 = morcellement).
- **Normalisation :** `[0..1]` sur l'amplitude de dissimilarité observée.

## 6. Interfaces techniques (cœur)

```
R/spectral_diversity.R        → primitive: compute_spectral_diversity(s2_cube,
                                 mask, window, n_clusters, metrics) → list(rasters)
                                 (appelle biodivMapR::… en Imports direct).
R/indicators-biodiversity.R   → indicateur_b4_div_spectrale(units, spectral=NULL, …)
R/indicators-landscape.R      → indicateur_l3_het_spectrale(units, spectral=NULL, …)
R/indicator-config.R          → B$indicators += "B4" ; L$indicators += "L3"
                                 (+ column_names, labels, tooltips FR/EN).
R/family-system.R             → mapping codes (doc L1,L2,L3 ; B1..B4).
R/normalization.R             → sens + bornes B4/L3.
R/datasources.R               → source Sentinel-2 réflectance déjà déclarée ;
                                 rien de neuf (réutilise le cube S2).
inst/…                        → paramètres par défaut (window, n_clusters).
```

- **DESCRIPTION** : `Imports:` += `biodivMapR`. `Remotes:` +=
  `jbferet/biodivMapR` (+ `jbferet/dissUtils` si requis). `License: GPL-3`.
- **Dispatch** : `indicateur_b4_*` / `indicateur_l3_*` renvoient l'`sf` avec la
  colonne `B4`/`L3` → `extract_indicator_value()` les résout sans map à tenir
  (convention spec §3.5 / v0.108.0).

## 7. NDP & validation

- **NDP** : B4/L3 calculés dès **NDP 0** (Sentinel-2). Montée en précision
  possible au NDP 2+ (drone/hyperspectral) — biodivMapR gère l'hyperspectral.
- **Statut proxy** : l'hypothèse de variation spectrale est un **proxy**
  (corrélation modérée, contexte-dépendante, avec la diversité taxonomique).
- **Pondération (D4 tranché)** : B4/L3 **comptent immédiatement** dans l'indice
  général avec le poids NDP normal de leur famille (pas de poids 0). Le statut
  proxy reste documenté dans les tooltips ; une **validation terrain** (démarche
  spec 008 / QField) reste au programme pour recalibrer bornes et, si besoin,
  réviser la pondération.

## 8. Plan de livraison (phases)

0. **Paperwork** — cette spec + amendement ADR-006 (platform_nemeton, distant).
1. **Relicence** — PR dédiée `nemeton` : `LICENSE`+`DESCRIPTION` MIT→GPL-3
   (acte légal isolé, revu seul). Puis nemetonshiny ; tree_sat/maestro sur place.
2. **Primitive** — `R/spectral_diversity.R` + `biodivMapR` en Imports + tests
   (mock/`skip_if_not_installed("biodivMapR")`).
3. **Indicateurs** — `indicateur_b4_div_spectrale`, `indicateur_l3_het_spectrale`
   + enregistrement (config, familles, normalisation) + tests.
4. **Release** — bump minor, NEWS/CITATION/PLAN, doc pkgdown.
5. **App** — nemetonshiny : afficher B4/L3 (radar + tooltips), rien de métier.

## 9. Décisions (tranchées 2026-07-01)

- **D1** ✅ **L3 haut = mieux**, hétérogénéité de composition (turnover spectral),
  **orthogonale** à L2 fragmentation géométrique. Tooltips explicitent la
  distinction.
- **D2** ✅ Défauts **`window = 10×10 px`** (≈100 m à 10 m S2), **`n_clusters =
  50`** spectral species (défaut biodivMapR). Ajustables.
- **D3** ✅ Normalisation **provisoire** : B4 sur `[0, log(n_clusters)]`, L3 sur
  l'amplitude de dissimilarité observée. **Recalibrage empirique obligatoire**
  après le premier run réel.
- **D4** ✅ B4/L3 **comptent immédiatement** dans l'indice général (poids NDP
  normal de la famille) ; validation terrain ultérieure pour recalibrer.
