# Spec 043 — Variables biophysiques Sentinel-2 (LAI, fAPAR, FCOVER, CCC)

**Version** : 1.0.0
**Date**    : 2026-07-24
**Statut**  : **Cadré — non implémenté.** Documents de spécification (aucun code).
**Auteur**  : Pascal Obstétar (via Claude), d'après `specs/brief-instance-nemeton.md`.
**Cible cœur** : `nemeton` — consommation via arguments optionnels.
**Cible amont** : `biophysnemeton` (package séparé, ADR-009) — production/assainissement.
**Supersède** : `specs/042-produits-biophysiques-geodes/` et `biophysique_sentinel2()`
(v0.166.0-.1) — cf. §0.

---

## 0. Réconciliation — écarts entre le brief et le code réel

Le brief (`specs/brief-instance-nemeton.md`) a été rédigé sur un en-tête périmé
(« v0.43.0, MIT ») ; le dépôt est à **0.166.1.9000, GPL-3**. Écarts constatés à
l'inspection, listés avant les décisions comme l'exige l'étape 3 du brief.

| # | Écart | Résolution |
|---|---|---|
| E1 | **`biophysique_sentinel2()` déjà livré** (v0.166.0-.1), inversion `prosail` **dans** nemeton — contredit D-brief 2 (package séparé) et 3 (SL2P pur, pas prosail) | **Décision Pascal : (A) supersède.** Cette spec remplace la 042 ; `biophysique_sentinel2()` (chemins fAPAR/FVC) et le chaînage lot 2 seront **retirés** à l'implémentation. `lai_sentinel2()` (spec 033, prosail, repli reGénération) reste — hors périmètre. |
| E2 | **`augmented` est déjà un vecteur** (`character`), pas un scalaire — et **`lai_ml` existe déjà** (spec 033, `R/ndp.R:334`) | La prémisse « augmented devient multi-valué » est **caduque** : il l'est depuis toujours. L'ADR (§B) ne crée pas la multi-valeur ; il **gouverne l'ajout du flag `biophysical_s2`** et son gating. |
| E3 | **« ADR-012 » est déjà attribué** (TimescaleDB/pgvector). Plus haut ADR = **014** | Écrit en **ADR-015** (`ADR-015-biophysique-ndp.md`). Le « 012 » du brief est une erreur de numérotation. |
| E4 | `fapar = NULL` et `fvc = NULL` **existent déjà** dans `indicateur_c2_ndvi` / `indicateur_a1_couverture` (phase « Theia s2_biophysical ») | Le patron d'argument optionnel est **acquis** ; on l'étend à `lai`/`ccc` sur les autres indicateurs (§7). |
| E5 | README annonce **« 31 indicateurs »** (`README.md:18,148`) ; le « 29 sous-indicateurs » du brief est **introuvable dans le repo** (probablement la description GitHub, hors dépôt) | **Signalé, non corrigé** (consigne du brief). À réconcilier hors de cette spec. |

> **HYPOTHÈSE :** « FCOVER » (brief) = « FVC » (fraction de couvert végétal). Même
> variable, deux graphies ; on retient **FCOVER** (graphie SNAP/SL2P) dans les
> nouveaux artefacts, `fvc` restant l'argument existant de `a1_couverture`.

---

## 1. Contexte

Le processeur biophysique de SNAP (**SL2P**, Weiss & Baret) restitue quatre
variables de canopée depuis Sentinel-2 L2A : **LAI**, **fAPAR**, **FCOVER**,
**CCC** (canopy chlorophyll content). Ce sont des **données amont**, sans
direction normative propre — elles n'ont pas de « bon » ou « mauvais » sens. Le
projet les intègre pour **raffiner des indicateurs existants** dont les proxys
actuels sont grossiers (NDVI pour `c2`, land-cover pour `a1`, `ndvi×150` pour
`c1`), **sans ajouter d'axe au radar**.

## 2. Périmètre

**Dans le périmètre**
- Production des 4 rasters par le package amont `biophysnemeton` (SL2P pur-R).
- Consommation par nemeton via **arguments optionnels** (`chm=NULL`-style, E4).
- Composite temporel juin-août, médiane, gating, correction de biais forêt.
- Flag `augmented = "biophysical_s2"` conditionné (ADR-015).
- Mapping vers 7 sous-indicateurs (§7).

**Hors périmètre**
- `lai_sentinel2()` (spec 033, prosail, repli canopée reGénération) : reste, non
  touché. Deux sources LAI coexistent transitoirement — cf. Q-ouvertes.
- Toute logique de production dans nemeton (elle vit dans `biophysnemeton`).
- Nouveau sous-indicateur ou axe radar (décision D-brief 1).
- SNAP, Google Earth Engine, `prosail` comme dépendance de production.

## 3. Décisions

### D1 — Consommation par argument optionnel, production en amont

Les indicateurs reçoivent chaque variable par un argument optionnel
(`lai=`, `fapar=`, `fcover=`, `ccc=`), défaut `NULL` → comportement v0.166
strictement inchangé. La production (SL2P, assainissement, composite) vit dans
`biophysnemeton`.

*Justification.* Patron `chm=NULL` déjà éprouvé (spec 005) et déjà appliqué à
`fapar`/`fvc` (E4). Sépare le cœur métier (indicateurs) de l'amont data (ADR-009).

*Conséquence.* nemeton ne dépend pas de `biophysnemeton` ; il accepte des
`SpatRaster`, d'où qu'ils viennent. Rétrocompatibilité par construction.

### D2 — Médiane, non maximum *(reprise verbatim du brief)*

Le composite par unité et par variable est la **médiane** des observations
valides de la fenêtre.

*Justification.* Le maximum est biaisé à la hausse par toute observation
résiduellement contaminée, biais croissant avec `n_obs` : deux unités couvertes
6 et 25 fois ne sont plus comparables. La médiane est robuste, son espérance ne
dépend pas de la taille de l'échantillon.

*Conséquence.* `n_obs` est conservé comme métrique de qualité et sert au gating,
**jamais** comme facteur correctif.

### D3 — SL2P porté en R pur, routage par plateforme

Perceptron 1 couche cachée / 5 neurones, **8 bandes + 3 angles**, coefficients
extraits des auxdata du toolbox Sentinel-2, **distincts par plateforme** (S2A,
S2B, …). Routage par plateforme **obligatoire**, jamais de repli implicite.

*Justification.* Reproductibilité stricte contre SNAP Desktop (test golden 1e-4,
§9) — impossible avec une inversion ré-entraînée localement (dont `prosail`).
Une erreur de signe dans un poids reste sinon indétectable.

*Conséquence.* Les coefficients sont une **donnée sourcée** (auxdata SNAP, par
plateforme), pas un modèle à ré-entraîner. La table de coefficients est livrée
dans `biophysnemeton`, versionnée et sourcée par plateforme.

### D4 — Fenêtre juin-août, lue depuis une table à une ligne

Composite sur `month %in% 6:8` (pas de jour julien — évite les bissextiles),
identique pour toutes essences/régions, mais **lu depuis une table de
référence**, jamais codé en dur.

*Justification.* L'indirection rend un raffinement ultérieur (altitude, puis
essence) possible **sans changement d'API**.

*Conséquence.* Schéma de la table au §5. À une ligne aujourd'hui.

### D5 — `r3_secheresse` par anomalie

`ccc` alimente `r3_secheresse` par **anomalie** contre une ligne de base
pluriannuelle (≥ 5 ans) sur la même fenêtre, pas par valeur absolue.

*Justification.* Une valeur absolue de CCC dépend de l'essence et de la station ;
l'anomalie isole l'écart au régime propre de l'unité.

*Conséquence.* Chemin d'entrée **distinct** : `r3` consomme une **série**, pas un
instantané. Signature dédiée (§8).

### D6 — Flag `augmented` conditionné, jamais de repli silencieux

`augmented` gagne la valeur `"biophysical_s2"`, **posée seulement si** `n_obs`,
taux de masquage, flags SL2P et surface de l'unité passent les seuils (§6).
Sinon `NA` et calcul en mode nominal.

*Justification.* Un flag posé sur une base insuffisante fausserait la confiance
φ, ce que l'ADR-011 interdit de fait.

*Conséquence.* Gouvernance dans l'ADR-015. `augmented` étant déjà un vecteur
(E2), l'ajout est un `c(augmented, "biophysical_s2")` sous condition.

### D7 — Correction de biais obligatoire en forêt

SL2P **sous-estime** le LAI de 20 à 50 % pour LAI > 2 en peuplement forestier.
Correction par table indexée **classe d'essence × région**, sourcée par ligne.

*Justification.* Sans correction, le LAI forestier est systématiquement faux à la
baisse — un biais orienté, pas un bruit.

*Conséquence.* Schéma de la table au §5.2, sur le modèle de
`site_index_curves.csv` + `inst/NOTICE`. **Valeurs à sourcer**, non inventées.

## 4. Mapping vers l'existant (D-brief 8)

| Variable | Indicateurs cibles | Nature du raffinement |
|---|---|---|
| **FCOVER** | `a1_couverture` (arg `fvc=`, **déjà là**, E4) | couverture arborée mesurée vs land-cover |
| **LAI** | `w3_humidite`, `c1_biomasse`, `b2_structure` | densité de feuillage (interception, biomasse, structure) |
| **fAPAR** | `c2_ndvi` (arg `fapar=`, **déjà là**, E4 ; nom conservé, mode ajouté) | vitalité liée à la production primaire vs NDVI (sature) |
| **CCC** | `f1_fertilite`, `r3_secheresse` (D5, anomalie) | statut chlorophylle/azote = fertilité + stress |

## 5. Schémas de tables de référence

### 5.1 Table de fenêtres (`biophys_windows.csv`) — D4

| colonne | type | contenu |
|---|---|---|
| `scope` | chr | `"default"` (une ligne aujourd'hui ; futur : `"altitude"`, `"species"`) |
| `key` | chr | clé de scope (`NA` pour `default`) |
| `month_start` | int | 6 |
| `month_end` | int | 8 |
| `source` | chr | provenance/justification par ligne |

> Une seule ligne `default,,6,8,…` au départ. Aucune valeur autre que la fenêtre
> juin-août n'est posée.

### 5.2 Table de correction de biais forêt (`lai_bias_forest.csv`) — D7

| colonne | type | contenu |
|---|---|---|
| `species_class` | chr | classe d'essence (aligne sur `list_species_classes()`) |
| `region` | chr | région/GRECO |
| `lai_min` | num | borne basse d'application (attendu ~2) |
| `factor` | num | **facteur multiplicatif de correction — À SOURCER** |
| `n` | int | effectif/appui de la valeur |
| `source` | chr | référence par ligne |

> **Aucune valeur de `factor` inventée.** Schéma posé, valeurs laissées à sourcer
> (littérature de validation SL2P forêt, ou campagne terrain). Modèle :
> `site_index_curves.csv` + `inst/NOTICE`.

## 6. Gating (D6) — seuils **à calibrer**

Le flag `"biophysical_s2"` n'est posé que si **toutes** les conditions tiennent :

| condition | seuil proposé | à calibrer — ordre de grandeur / méthode |
|---|---|---|
| `n_obs` (obs. valides fenêtre) | **≥ 3** | 3-6 ; par courbe stabilité du composite vs `n_obs` (test D-invariance §9) |
| taux de masquage nuage/ombre de l'unité | **≤ 40 %** | 30-50 % ; par sensibilité du composite au masquage |
| flags qualité SL2P (out-of-range entrées/sorties) | **0 pixel hors domaine** au-delà d'une part | part 5-10 % ; défini par les flags SL2P d'input/output |
| surface de l'unité | **≥ N pixels 20 m** | ~ 1 ha (≈ 25 px) ; par variance intra-unité vs surface |

> Tous « à calibrer ». Aucun n'est arrêté. La méthode de calibration accompagne
> chaque seuil ci-dessus.

## 7. Signatures R proposées (indicateurs cœur)

Patron `chm=NULL` (D1). Arguments **ajoutés**, jamais substitués :

```r
indicateur_a1_couverture(units, …, fvc = NULL)          # DÉJÀ là (E4)
indicateur_c2_ndvi(units, layers, …, fapar = NULL)      # DÉJÀ là (E4)
indicateur_w3_humidite(units, …, lai = NULL)            # à ajouter
indicateur_c1_biomasse(units, …, chm = NULL, lai = NULL)# à ajouter (coexiste avec chm)
indicateur_b2_structure(units, …, chm = NULL, lai = NULL)
indicateur_f1_fertilite(units, …, ccc = NULL)
```

## 8. `r3_secheresse` — chemin série (D5)

```r
indicateur_r3_secheresse(units, …,
                         ccc_serie = NULL,      # SpatRaster multi-années, même fenêtre
                         ccc_baseline_min = 5)  # années min pour la ligne de base
```

`NULL` → comportement actuel. Fourni → anomalie = composite courant − médiane de
la ligne de base pluriannuelle, par unité.

## 9. Tests d'acceptation

**Non négociables, en tête (D-brief) :**

1. **Golden values SL2P à 1e-4** contre des pixels traités indépendamment dans
   **SNAP Desktop**, **par plateforme** (S2A/S2B) **et par variable**. Sans ce
   test, une erreur de signe dans les poids reste indétectable. *(Le jeu de
   pixels de référence SNAP est un livrable de `biophysnemeton`.)*
2. **Invariance du composite au nombre d'observations** (contrôle D2) : sur une
   unité, un composite calculé sur 6 puis 25 dates de même distribution ne doit
   pas dériver au-delà d'une tolérance ; le maximum, lui, dériverait.

**Autres :**
3. Routage plateforme : S2A et S2B ne partagent jamais les coefficients ; erreur
   explicite si plateforme inconnue (jamais de repli, D3).
4. Fenêtre lue depuis la table (D4) : modifier la table change la fenêtre, aucune
   constante en dur.
5. Gating (D6) : aucune des 4 conditions non remplie ⇒ `augmented` **sans**
   `"biophysical_s2"` et calcul nominal ; les 4 remplies ⇒ flag posé.
6. Correction de biais (D7) : LAI < seuil non corrigé ; LAI > seuil corrigé par
   la table ; classe/région absente ⇒ `NA` (pas de facteur par défaut).
7. Rétrocompat : chaque indicateur, argument biophysique `NULL`, rend la valeur
   v0.166 à l'identique.

## 10. Cas limites

- Unité sans aucune obs. valide dans la fenêtre → composite `NA`, flag non posé.
- Plateforme mixte S2A+S2B sur la fenêtre → composite par plateforme puis
  fusion ? **> HYPOTHÈSE :** traiter chaque scène avec ses coefficients de
  plateforme, fusionner les composites au niveau raster. À trancher (Q3).
- CCC sans ligne de base ≥ 5 ans → `r3` reste en mode nominal (D5), flag non posé.
- Unité à cheval sur deux régions (table de biais) → recouvrement majoritaire,
  comme `resoudre_espar` / la jointure SER (spec 040).

## 11. Questions ouvertes

- **Q1** — Deux sources LAI (SL2P nouveau ; prosail spec 033 reGénération).
  Coexistence transitoire, ou le SL2P remplace-t-il le repli prosail à terme ?
- **Q2** — CCC est-il une sortie **directe** de SL2P (auxdata), ou un composé à
  reconstruire ? (Ma spec 042 avait constaté que `prosail` ne le sort pas
  directement ; SL2P peut différer — **à vérifier dans les auxdata SNAP**.)
- **Q3** — Fusion multi-plateforme d'un composite (cf. §10).
- **Q4** — La correction de biais forêt (D7) s'applique-t-elle aussi au fAPAR/
  FCOVER, ou seulement au LAI ? Le brief ne cite que le LAI.
- **Q5** — `augmented = "biophysical_s2"` unique, ou un flag par variable
  (`lai_s2`, `fapar_s2`…) ? L'ADR-015 tranche (proposé : unique, cf. §B).
