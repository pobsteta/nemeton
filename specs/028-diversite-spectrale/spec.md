# Spec 028 — Diversité spectrale : indicateurs B4 & L3 (biodivMapR)

**Statut :** livré v0.110.0 ; **smoke réel exécuté et D3 recalibré en v0.190.0** (§10) — trois défauts corrigés, bornes B4/L3 refaites sur run réel. D3 reste **ouverte** : calibration mono-scène, à confirmer sur un second massif.
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
- **D3** 🟨 Normalisation. *Provisoire (2026-07-01)* : B4 sur
  `[0, log(n_clusters)]`, L3 sur l'amplitude de dissimilarité observée.
  **Recalibrée sur run réel le 2026-08-27** (§10.4) : B4 sur `[0, log(10)]`
  (nombre effectif de spectral species), L3 sur `[0, 0,5]` de la dispersion
  PCoA. **Reste ouverte** — une seule scène mesurée.
- **D4** ✅ B4/L3 **comptent immédiatement** dans l'indice général (poids NDP
  normal de la famille) ; validation terrain ultérieure pour recalibrer.

---

## 10. Run de référence — smoke réel et recalibrage D3 (2026-08-27)

**Statut D3 : recalibré sur un run réel, mais sur *une seule scène*.** La
décision reste ouverte tant qu'un second massif n'a pas été mesuré.

### 10.1 Le run

| | |
|---|---|
| Projet | `20260624_073705_armn` (« Fordead ») |
| Scène | `S2A_MSIL2A_20170814T105031_R051_T31UFQ_20210712T212346` (14 août 2017) |
| Tuile / CRS | T31UFQ, EPSG:32631 |
| Fenêtre | 10 × 10 px = 100 m (D2) |
| `nbclusters` | 50 (D2), 10 répétitions |
| Sorties | `shannon_mean.tiff`, `shannon_sd.tiff`, `beta.tiff` (3 bandes) |
| Fenêtres valides | 649 sur 1 131 (grille 29 × 39) |
| Unités agrégées | 30 UGF, 2,1 à 34,0 ha (2 à 36 fenêtres couvertes) |

Le run avait été produit par l'app le 2026-07-02 et **dormait dans le cache du
projet sans avoir jamais été relu**. Il n'a pas fallu le refaire : le chemin
`reuse_existing` de `compute_spectral_diversity()` a rendu les rasters tels
quels — ce qui valide au passage ce chemin sur données réelles.

### 10.2 Ce que le smoke a trouvé

**(1) B4 lisait l'écart-type, pas la moyenne.** `.find_diversity_raster()`
départageait les candidats par **longueur de nom** : `shannon_sd.tiff`
(15 caractères) l'emportait sur `shannon_mean.tiff` (17). B4 rapportait donc la
*dispersion intra-fenêtre* du Shannon au lieu du Shannon. Effet mesuré : les
30 UGF tenaient toutes entre **3,5 et 5,4 / 100**, soit 1,9 point d'étendue.

**(2) L3 moyennait des coordonnées d'ordination.** `beta.tiff` n'est pas un
raster de dissimilarité : ce sont les **trois premiers axes d'une PCoA** de la
dissimilarité Bray-Curtis entre fenêtres. Ses valeurs sont des coordonnées
**signées et centrées sur zéro** (amplitudes mesurées : `[-0,351 ; 0,538]`,
`[-0,549 ; 0,423]`, `[-0,460 ; 0,421]`, moyennes à moins de 0,006 de zéro).
Les moyenner donnait la **position** moyenne de l'unité dans l'ordination, sans
signification de diversité — puis le clamp `[0, 100]` envoyait à **exactement 0**
toute unité du côté négatif : **16 UGF sur 30**.

**(3) La borne `log(50)` était hors d'atteinte.** Sur 649 fenêtres le Shannon
plafonne à **2,456** (11,7 spectral species effectives) contre `log(50) = 3,912`
en théorie. Même corrigée du défaut (1), la famille B serait restée dans le
premier tiers de l'échelle quoi qu'elle contienne.

**(4) Une variable `ID` circule dans l'espace de k-means — et elle est inerte.**
`Kmeans_info` porte 7 variables : `ID, B04, B05, B08, B8A, B11, B12` (B02 est
lue par l'app mais absente ici). `ID` a une amplitude de 218 622 contre 3 000 à
10 400 pour les bandes, ce qui pouvait laisser craindre une classification
pilotée par un index. **Vérifié : elle porte 0,0 % de la variance inter-
centroïdes** (écart-type 0,0024 après normalisation, contre 0,24 à 0,82 pour les
bandes). Le run est exploitable ; aucun correctif n'est demandé de ce fait.

### 10.2 bis — Corroboration indépendante

Les valeurs d'avant correctif ne sortent pas seulement de ma relecture du cache.
Le brief `specs/BRIEF-nemeton-normalisation-familles.md` (diagnostic du
**2026-08-16**, soldé les 16-17 août), établi depuis
`data/indicators.parquet` du **même projet** et sans rapport avec biodivMapR,
tabule déjà :

| Indicateur | min | méd | max | verdict du brief |
|---|---|---|---|---|
| `b4_div_spectrale` | 0,135 | 0,174 | 0,211 | « B faussée » |
| `l3_het_spectrale` | −0,159 | −0,016 | 0,200 | « L faussée » |

Ce sont **exactement** les distributions mesurées ici pour `shannon_sd` et pour
la moyenne des axes PCoA. Le défaut était donc bien vivant dans les sorties de
production, et pas un artefact de cache périmé. Le brief l'avait traité comme un
problème de **normalisation** — ce qui était juste à son niveau d'observation :
depuis le parquet on voit une échelle aberrante, pas une carte lue au mauvais
fichier. La cause ne se voyait qu'en remontant aux rasters.

### 10.3 Distributions mesurées

Shannon par fenêtre (649 fenêtres) : min 0 · q05 0,067 · médiane **0,797** ·
q95 1,846 · max **2,456**.

| | B4 — Shannon moyen par UGF | L3 — dispersion PCoA par UGF |
|---|---|---|
| min | 0,288 | 0,064 |
| médiane | 0,797 | 0,282 |
| max | 1,553 | 0,440 |
| NA | 0 | 1 (UGF de 2 fenêtres) |

### 10.4 D3 recalibré

- **B4 → `[0, log(10)]`.** La borne est exprimée sur le **nombre effectif de
  spectral species**, `exp(H)` : le score atteint 100 pour l'équivalent de
  **10 spectral species également abondantes par hectare**. Constante
  `.B4_MAX_SPECTRAL_SPECIES`. Le clamp laisse saturer une scène plus diverse
  (la meilleure fenêtre du run, à 11,7, sature).
- **L3 → `[0, 0,5]` sur la dispersion.** Bray-Curtis est nominalement borné par
  1, mais une PCoA à 3 axes n'en restitue qu'une partie (**GOF 0,563 / 0,619**
  sur ce run) : les distances y sont systématiquement contractées et les
  dispersions par UGF mesurées s'étalent de 0,064 à 0,440. Retenir 1,0 aurait
  écrasé une seconde fois tout le domaine dans la moitié basse. Constante
  `.L3_MAX_DISPERSION`.
- **Métrique L3 redéfinie** : dispersion multivariée de l'unité autour de son
  propre centroïde dans l'espace PCoA (*betadisper* d'Anderson), et non plus
  moyenne des axes. `NA` sous **3 fenêtres** couvertes — une dispersion autour
  d'un centroïde y est dégénérée, et une valeur proche de zéro s'y lirait à tort
  comme « unité homogène ».

### 10.5 Effet sur le run de référence

| | avant | après |
|---|---|---|
| B4, étendue des scores | 3,5 → 5,4 (1,9 pt) | **12,5 → 67,4 (54,9 pts)** |
| B4, UGF médiane | 4,4 | **34,6** |
| L3, UGF à exactement 0 | **16 / 30** | **0** |
| L3, étendue des scores | 0 → 20,0 | **12,9 → 87,9** |
| L3, UGF médiane | 0 | **56,4** |

### 10.6 Ce qui reste ouvert

- **Une seule scène, un seul massif.** Les deux bornes sont des calibrations
  mono-scène, honnêtes sur l'amplitude que le pipeline produit réellement mais
  à revoir dès qu'un second massif est mesuré. D3 reste **ouverte**.
- **La validation terrain de D4** (le statut proxy, spec 008 / QField) n'est pas
  entamée et ne l'est pas par ce chantier.
- **Affichage `nemetonshiny`** : B4/L3 au radar et tooltips — brief émis.
