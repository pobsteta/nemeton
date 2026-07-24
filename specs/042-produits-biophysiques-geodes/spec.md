# Spec 042 — Produits biophysiques GEODES (LAI, fAPAR, FVC, CCC)

**Version** : 1.0.0
**Date**    : 2026-07-24
**Statut**  : **Cadré — non implémenté.** Décision D1 (mécanisme d'accès GEODES) à
lever avant tout code.
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` — source de données GEODES + upgrades de proxys.
**Cible app**  : `nemetonshiny` — affichage des couches, badge qualité.
**Origine** : question de cohérence posée le 2026-07-24, à la lumière du produit
CNES/GEODES « produits biophysiques à 20 m sur la France »
(<https://geodes.cnes.fr/…-a-20m-de-resolution/>).

## 1. Objectif, et le cadrage qui le sous-tend

Le CNES publie sur GEODES quatre variables biophysiques nationales à 20 m,
dérivées de Sentinel-2 par **apprentissage machine entraîné sur des simulations
PROSAIL**, avec un **masque qualité par pixel (1-4)**.

**Thèse de cette spec** (établie par l'analyse de cohérence, §3) : ces quatre
variables **n'ont pas vocation à devenir quatre indicateurs**. Trois sont des
lectures colinéaires de la densité de couvert ; les exposer côte à côte dans la
famille C **triplerait le poids de la « verdeur »** dans l'agrégation Fibonacci —
*moins* cohérent, pas plus. La valeur est ailleurs : **remplacer des proxys
grossiers existants par des variables physiquement fondées**, et ajouter **un
seul** signal réellement neuf (le CCC).

## 2. État de l'existant (vérifié dans le code)

| Variable | État `nemeton` |
|---|---|
| **LAI** | déjà produit — `lai_sentinel2()`, inversion PROSAIL hybride (spec 033), consommé par les moteurs reGénération/microclimat |
| **FVC** | déjà **câblé en entrée** — `indicateur_a1_couverture(fvc = NULL)` (`R/indicators-air.R`) |
| **fAPAR** | calculable non branché — `prosail::Compute_fAPAR()` / `get_fapar()` disponibles |
| **CCC** | **absent** |

`nemeton` porte déjà l'infra CNES/Theia : source `theia_stac`
(`api.stac.teledetection.fr`, S3 SigV4), résolveur `R/theia_stac.R`, source
MUSCATE S2 (spec 029). GEODES est **la même famille** — même méthode PROSAIL,
même grille S2. Consommer GEODES = consommer une version **pré-calculée,
nationale, masquée-qualité** de ce que le cœur sait déjà inverser localement.

## 3. Analyse de cohérence, variable par variable

Colinéarité de fond : `fAPAR ≈ 1 − e^(−k·LAI)`, `FVC ≈ 1 − e^(−0,5·LAI)`. LAI,
fAPAR et FVC mesurent **la même chose** (densité/interception), sous trois angles.

| Variable | Proxy actuel qu'elle remplacerait | Verdict |
|---|---|---|
| **fAPAR** | **C2 = NDVI** (`indicateur_c2_ndvi`), qui **sature** à fort LAI | **Upgrade** : le fAPAR est lié à la production primaire → vitalité mieux fondée. Gain de précision *dans* C2. |
| **FVC** | A1 (couverture, déjà `fvc = NULL`) | **Branchement** : couche FVC nationale au NDP 0. Pas un nouvel indicateur. |
| **LAI** | déjà consommé (regen/microclimat) ; **C1 biomasse = `ndvi_mean × 150`** (`indicators-families.R:371`, proxy très grossier) | **Source alternative** + amélioration possible de C1. *Make-vs-buy* : GEODES pré-calculé vs `lai_sentinel2()` local. |
| **CCC** | — (rien) | **Seul ajout réellement neuf** : chlorophylle/azote foliaire = signal de **stress/santé**, pas de densité. Candidat pour R5 (dépérissement) ou une vitalité composite. |

## 4. Ce que la spec propose (et ce qu'elle refuse)

**Refuse** : ajouter LAI/fAPAR/FVC comme trois indicateurs de la famille C.

**Propose**, dans l'ordre de valeur croissante :

1. **Déclarer GEODES en source NDP 0** dans `inst/datasources/FR.json`, avec sa
   couche de qualité — cf. §5.
2. **Brancher FVC → A1** : `indicateur_a1_couverture()` accepte déjà `fvc`. Fournir
   la couche GEODES. Effort quasi nul, rétrocompatible.
3. **Upgrader C2 : NDVI → fAPAR**, en gardant NDVI en repli. `indicateur_c2_ndvi`
   gagne un argument `fapar = NULL` ; si fourni, il prime ; sinon comportement
   inchangé. Même patron que `chm = NULL` de P1/C1/B2 (spec 005) — la voie
   « rétrocompatible strict » du projet.
4. **CCC → nouveau signal de santé**, **gaté sur le masque qualité**. À trancher
   (D2) : entrée d'un indicateur existant (R5) **ou** composante d'une vitalité
   enrichie — *pas* un indicateur autonome tant que sa fiabilité n'est pas établie
   (§6).

## 5. Accès aux données (D1 — **ouvert, bloquant**)

L'article GEODES **ne publie pas** le mécanisme d'accès. À élucider avant tout
code :
- **STAC ?** GEODES est la plateforme CNES (successeur Theia/PEPS). Probable
  catalogue STAC (`geodes-portal.cnes.fr` ou équivalent) → réutiliser
  `R/theia_stac.R` et le patron `theia_stac` de `FR.json`. À confirmer :
  endpoint, nom de collection, identifiants de bandes (LAI/FAPAR/FCOVER/CCC),
  clé API éventuelle.
- **Téléchargement de dalles** par tuile S2 ? Alors loader *download-only*, patron
  BD Forêts anciennes.
- **Format** : entiers 0-255 (UInt8) avec **gain/offset dans l'en-tête** — le
  loader doit appliquer l'échelle, ne pas servir les DN bruts.

Tant que D1 n'est pas levée, la spec ne peut pas fournir de loader — seulement le
contrat de consommation (§4) et les upgrades, testables sur raster fourni.

## 6. Le masque qualité — condition, pas bonus

GEODES fournit une **confiance par pixel (1-4)**. Deux usages :

- **Le CCC en dépend.** L'inversion S2 contraint mal le Cab (problème mal posé) :
  le CCC est le moins fiable des quatre. **Ne pas bâtir d'indicateur dur sur le
  CCC** sans filtrer/pondérer par la qualité.
- **Il s'aligne sur le système NDP.** Une confiance 1-4 par pixel se marie
  naturellement avec la confiance φ Fibonacci (ADR-011). Piste : moduler la
  confiance d'un indicateur par la qualité moyenne de la couche biophysique sur
  l'UGF. Argument de cohérence *architecturale*, au-delà des indicateurs.

## 7. Rétrocompatibilité stricte (non négociable)

Tout upgrade suit le patron `chm = NULL` de la spec 005 : argument optionnel,
défaut `NULL`, comportement v0.16x **strictement préservé** quand la couche
biophysique est absente. Aucun indicateur ne doit changer de valeur sur un jeu de
données qui n'a pas GEODES.

## 8. Décisions

| # | Décision | Statut |
|---|---|---|
| D1 | Mécanisme d'accès GEODES (STAC ? dalles ? collection, bandes, auth) | **Ouverte — bloque le loader** |
| D2 | CCC : entrée de R5, composante vitalité, ou rien pour l'instant | **Ouverte** (§4.4) |
| D3 | C2 : `fapar` prime sur NDVI, ou mélange pondéré ? | Proposée : `fapar` prime, NDVI en repli (§4.3) |
| D4 | LAI : consommer GEODES ou garder `lai_sentinel2()` local (make-vs-buy) | Proposée : GEODES en source, local en repli |
| D5 | Moduler la confiance φ par le masque qualité GEODES | **Ouverte** (§6) — plus lourde, à isoler |

## 9. Plan en lots

### Lot 0 — Reconnaissance d'accès *(bloquant, D1)*
Établir sur GEODES : endpoint STAC ou URL de dalles, nom de collection,
identifiants de bandes, gain/offset, clé API éventuelle, licence. Sortie : le
patron de source à déclarer dans `FR.json`. **Rien d'autre ne démarre avant.**

### Lot 1 — Source de données + loader
Déclaration `FR.json` (les 4 variables + la couche qualité) et
`load_biophysique_geodes()` (ou réemploi `theia_stac.R`), appliquant gain/offset,
repli `NULL` propre. Pas de nouvel indicateur.

### Lot 2 — Branchements rétrocompatibles
FVC → A1 (déjà câblé, fournir la couche). fAPAR → C2 (`fapar = NULL`, prime sinon
repli NDVI). LAI → source alternative pour la voie regen/microclimat + option C1.
Tests `chm = NULL`-style : valeur inchangée sans GEODES.

### Lot 3 — CCC, prudemment *(D2, gaté qualité)*
Brancher le CCC en **entrée** (R5 ou vitalité composite), filtré par le masque.
Documenter l'incertitude. **Ne pas** en faire un indicateur autonome à ce stade.

### Lot 4 — Confiance modulée par qualité *(D5, optionnel)*
Piste ADR-011 : la qualité GEODES module la confiance φ de l'UGF. Chantier à part,
à ne lancer que si D2/D3 concluants.

## 10. Hors périmètre

- Recalculer localement ce que GEODES fournit : `lai_sentinel2()` reste le repli,
  pas le chemin principal (D4).
- Quatre indicateurs biophysiques distincts dans la famille C — **explicitement
  refusé** (§1, §3), au nom de la cohérence de l'agrégation Fibonacci.
- Toute décision de licence/diffusion des couches GEODES côté app (badge de
  provenance) — relève de `nemetonshiny`.
