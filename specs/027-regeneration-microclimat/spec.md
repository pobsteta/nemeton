# Spec 027 — Onglet « reGénération » : vulnérabilité climatique par parcelle

**Statut** : **RÉALIGNÉE + SIMPLIFIÉE + ARBITRÉE (2026-07-02).** Les 4 décisions
du §10 sont **tranchées** (Pascal). Prête pour l'implémentation (L1→L3 cœur).
Reste à préciser : la valeur du buffer de la carte de tendances (§10.4, défaut
proposé ~25 km).
**Version** : 2.1.0 — v2.0 isolait les moteurs GPL dans un 5ᵉ repo pour
protéger un cœur *supposé* MIT ; **or `nemeton` est déjà GPL-3** (LICENSE +
DESCRIPTION). Le conflit de licence **n'existe pas** → les moteurs vont
**directement dans `nemeton`**, pas de `regen_nemeton`.
**Cibles** : `nemeton` (cœur — moteurs + indicateurs, GPL-3) · `nemetonshiny`
(onglet, GPL-3).
**ADR** : **pas d'ADR-014 nécessaire** (voir `ADR-014-draft.md`, réduit à une
note : nemeton étant GPL-3, les moteurs GPL sont admis au cœur). Amende
**ADR-011** (flag augmenté `microclimate_model`).
**Sources brief** : `brief-onglet-regeneration.md`, `README.md`, et prototypes
`pai_lidarhd_lasR.R`, `microclimat_parcelles_robuste.R` (B4),
`microclimat_parcelles_2annees.R`, `carte_tendances_estivales_eobs.R`.

> ### ⚠️ Historique du cadrage
> - **v1** (2026-06-30) : périmètre réduit au seul microclimat, sans remonter
>   au brief. A produit A3/A4/W4/R6 + `regeneration_index` (parké).
> - **v2.0** (2026-07-02) : réalignement sur le brief (2 moteurs), mais bâti sur
>   la prémisse **fausse** « nemeton est MIT » (héritée de l'en-tête du brief et
>   d'ADR-006 dans CLAUDE.md) → proposait un repo GPL `regen_nemeton`.
> - **v2.1** (2026-07-02, cette version) : **vérification du fichier LICENSE →
>   `nemeton` est GPL-3.** Donc aucun conflit avec `microclimf`/`biljouR`/
>   `lidR`/`lasR` (tous GPL-3) : **tout reste dans `nemeton`**, `regen_nemeton`
>   abandonné.

---

## 1. Objectif

Fournir, **par unité de gestion (UGF)**, une lecture de la **vulnérabilité
climatique du peuplement** pour **prioriser les interventions de régénération /
adaptation**. Question du gestionnaire : *« quelles parcelles se réchauffent et
s'assèchent le plus, et lesquelles subissent réellement un stress hydrique du
sol ? »*

Deux moteurs complémentaires (déjà prototypés dans la chaîne `reGénération`) :

1. **Exposition microclimatique** (`microclimf` + LiDAR HD) — T°max et VPD
   **sous couvert**, effet tampon de la canopée, écart canicule / année moyenne
   → *le climat vu par la parcelle*.
2. **Bilan hydrique du sol** (`biljouR`, réimplémentation R du modèle INRAE
   BILJOU) — réserve en eau relative (REW), jours de stress, indice de
   sécheresse → *la réponse hydrique du peuplement*.

Le **croisement** des deux produit un **indice de priorité de régénération**
plus défendable que chacun isolé, et alimente les familles NMT existantes
**A (microclimat), R (r3 sécheresse), W (eau), C (vitalité)**.

## 2. Architecture & licences (simplifiée — tout GPL-3)

**`nemeton` est GPL-3** (LICENSE = GNU GPL v3.0, DESCRIPTION `License: GPL-3`).
`microclimf`, `biljouR`, `lidR`, `lasR` sont **GPL-3** : **aucun conflit**. Les
moteurs vont donc **dans `nemeton`**, sans repo séparé.

| Brique | Repo | Rôle |
|---|---|---|
| Moteurs (PAI LiDAR, microclimf, biljouR) + indicateurs + normalisation | `nemeton` (GPL-3) | calcul **et** contrat NMT (A/R/W/C, NDP, schéma §7) |
| Onglet `mod_regeneration`, persistance PostGIS, export, LLM | `nemetonshiny` (GPL-3) | UI, orchestration tâche de fond, historisation, PDF/GPKG |

**Dépendances lourdes en `Suggests`** (pas `Imports`) — non par contrainte de
licence (tout est GPL-3), mais par **hygiène d'installation** : `microclimf`
(GitHub), `mcera5`, `ecmwfr`, `lidR`, `lasR`, `biljouR` sont lourdes et pas
toutes sur le CRAN. Chargement via `requireNamespace(..., quietly = TRUE)`,
**échec propre** si absentes (message actionnable). Cohérent avec la règle
spec 005 / CLAUDE.md. Le cœur reste **installable et testable sans elles** (les
indicateurs acceptent un `micro` / un bilan précalculé ; CI sans réseau).

Sens des dépendances (inchangé) : `nemetonshiny → nemeton`. Jamais l'inverse.

## 3. Réconciliation avec l'existant (déjà livré cœur)

| Élément livré | Devenir |
|---|---|
| `indicateur_a3_microclimat`, `a4_tamponnement`, `w4_vpd`, `r6_sensibilite` | **Restent** tels quels (consomment un `micro` précalculé). |
| `microclimate_run()` (scaffold appelant `microclimf`) | **Reste au cœur** et sera **complété** en orchestrateur réel (microclimf en `Suggests`). Plus de migration. |
| `microclimate_detect_years()` (E-OBS) | Reste au cœur. |
| **`regeneration_index()` + `regeneration_tolerances()`** (parké, non mergé) | **Retravailler** en `indice_priorite_regen` = **croisement exposition × stress hydrique** (pas une moyenne pondérée A3/A4/W4/R6). **Pénalité par essence conservée en option OFF par défaut** (décision §10.1) ; `regeneration_tolerances.csv` réutilisé. Colonnes renommées §7. |

## 4. Pipeline (par jeu de parcelles)

```
UG (GPKG) ─┬─► pai_depuis_nuage(.laz) ─► PAI raster
           │                              │
           │   LiDAR HD MNT/MNH ─► dtm, hgt▼
           │                        microclimf(veg, soil, forçage ERA5)
           │                              ├─► ΔT°max, ΔVPD par pixel
           │                              └─► agrégat UG ─► sensibilité, robustesse
           │
           └─► lai_max ⇐ PAI(UG) ─► biljouR::biljou_run_grid(SAFRAN, sol)
                                     └─► REW, NJstress, Istress par UG
                            │
        indice_priorite_regen ◄─┘  (croisement exposition × stress hydrique)
```

**Couplage clé** : le PAI par parcelle (`pai_depuis_nuage`) alimente le
`lai_max` de `biljou_run_grid()`. ⚠️ PAI ≈ LAI **uniquement** en acquisition
*feuilles présentes* — paramètre/conversion à exposer (§9.3).

## 5. Contenu côté `nemeton` (GPL-3 — calcule ET déclare)

1. **Moteurs** (nouveaux fichiers) : `pai_depuis_nuage` (PAI LiDAR),
   orchestration `microclimf` (compléter `microclimate_run`), intégration
   `biljouR` (`regen_bilan_hydrique`), croisement `regen_priorite`. Dépendances
   en `Suggests`, dégradation propre.
2. **Enrichir `indicateur_r3_secheresse`** pour accepter les métriques BILJOU
   (`njstress`, `istress`, `deb_stress`) + exposer les **valeurs brutes**.
3. **Sous-indicateurs microclimat** (déjà là) A3/A4/W4/R6 + champs bruts
   `d_tmax`, `d_vpd`, `sensibilite`, `robustesse`.
4. **Indice `indice_priorite_regen`** (retravail de `regeneration_index`) =
   croisement exposition × stress hydrique. **Générique par défaut** ; pénalité
   par essence en **option désactivée** (arg `species = NULL` → générique ;
   renseigné → affinage via `regeneration_tolerances.csv`). Décision §10.1.
5. **Schéma de sortie §7** documenté comme contrat de colonnes.

Interfaces à stabiliser (prototypées dans `/Documents/reGénération/`) :

```r
pai_depuis_nuage(dossier_las, grille, parcelle = NULL, res = 2, k = 0.5, ...)         # -> SpatRaster
regen_sensibilite(parc, mnt, mnh, las, annees_moy, annees_canic, mois_ete = 6:8, ...)# -> sf
regen_bilan_hydrique(parc, meteo_safran, sol, lai_max_par_ug, forest_type, ...)      # -> sf
regen_priorite(sf_exposition, sf_hydrique)                                           # -> indice_priorite_regen
```

## 6. Sources & forçage

| Donnée | Moteur | Source | Accès |
|---|---|---|---|
| Nuage LiDAR HD `.laz` classé | PAI | Géoplateforme IGN | Open data Etalab |
| MNT / MNH LiDAR HD | microclimat | Géoplateforme IGN | Open data Etalab |
| Forçage horaire | microclimat | ERA5-Land (`mcera5`/`ecmwfr`) | Compte CDS + clé |
| **Forçage bilan hydrique** | biljouR | **SAFRAN** (Météo-France 8 km ; miroir NetCDF INRAE DOI 10.57745/BAZ12C) | `safran_download()` |
| Série estivale tendances | années R6 + **branche A nationale** | **E-OBS** (Copernicus/ECA&D) | HTTPS, non commercial |
| Parcelles UG | tous | couche projet | interne |

**Reco forçage** : SAFRAN **primaire** (donnée officielle FR → crédibilité
réglementaire) ; ERA5-Land en repli et pour le microclimat.

**Branche A (contexte de tendances, DANS la v1 — décision §10.4)** : carte
bivariée de tendances estivales E-OBS (T°max × précipitations) **calculée sur
l'emprise de la zone UGF + un buffer** (défaut proposé ~25 km, à confirmer ;
≥ 2 mailles E-OBS ~0,1° ≈ 11 km). **Pas de carte nationale.** Prototypes de
référence `carte_tendances_estivales_eobs.R` / `…_avec_animation.R` (à recadrer
sur l'AOI projet au lieu de la France entière).

## 7. Schéma de sortie (GPKG / table UG) — contrat à figer

| Champ | Type | Moteur | Sens |
|---|---|---|---|
| `tmax_moyenne`, `tmax_canicule` | num | microclimf | T°max sous couvert (été moyen / canicule) |
| `vpd_moyenne`, `vpd_canicule` | num | microclimf | VPD sous couvert |
| `d_tmax`, `d_vpd` | num | microclimf | aggravation canicule vs moyenne |
| `sensibilite`, `rang_sensibilite` | num | microclimf | score composite + classement |
| `robustesse`, `signal_robuste` | num/bool | microclimf | écart > variabilité interannuelle |
| `rew_min` | num | biljouR | réserve en eau relative minimale |
| `njstress` | int | biljouR | nb jours de stress hydrique |
| `istress`, `deb_stress` | num | biljouR | intensité / précocité sécheresse |
| `indice_priorite_regen` | num | croisement | priorité de régénération |
| `parcelle_sensible`, `priorite` | bool | croisement | flags de priorisation |
| `couverture_pct` | int | qualité | % UG couvert (filtre parcelles mal renseignées) |

## 8. Onglet `nemetonshiny` (`mod_regeneration`)

- **UI** : couche UG du projet ; config années moy/canicule (défaut ~2021+),
  mois été, `forest_type`, `budburst`/`leaf_fall`, `lai_max` (auto PAI ou
  saisie), sol (`ewm`/`roots` → `biljou_soil()`), forçage (SAFRAN défaut /
  ERA5), résolution (2 m / 5 m). Run en **tâche de fond** + cache + reprise.
- **Résultats** : carte commutable (`d_tmax` / `sensibilite` / `njstress` /
  `indice_priorite_regen`) ; **carte bivariée ΔT°max × ΔVPD** ; tableau trié
  par `rang_sensibilite` / `priorite` avec `couverture_pct` ; fiche parcelle
  (chronique REW + flux) ; **radar** A/R/W/C mis à jour.
- **Synthèse LLM** : profil « adaptation / changement climatique » lisant
  `njstress`/`istress`/`sensibilite`, recommandations régénération + flag des
  conflits inter-profils (ex. régénération vs biodiversité B/N).
- **Persistance/export** : table PostGIS versionnée des états climatiques par
  UG ; section Quarto « reGénération » ; champs GPKG §7 ; i18n FR/EN.

## 9. Contraintes & décisions du brief (rappel)

- **9.1 Licence** : **résolu** — tout est GPL-3, moteurs au cœur. (Plus de repo
  séparé ni d'arbitrage bloquant.)
- **9.2 Crédibilité BILJOU** : réimplémentation **non cautionnée INRAE**,
  constantes à **caler sur BILJOU officiel** ; sorties communiquées en
  **classement relatif** (prudence en valeur absolue).
- **9.3 Hypothèses physiques** : PAI ≈ LAI si feuilles présentes ; sol
  uniforme ; **canopée figée** pour les comparaisons inter-annuelles (isole
  l'effet climatique, pas mortalité/éclaircies/scolytes).
- **9.4 Performance** : `microclimf` = goulot → tâche de fond + cache + mode
  « bilan hydrique seul » rapide.
- **9.5 Années** : proches de l'acquisition LiDAR (~2021+) ; classement
  chaud/frais vérifié sur E-OBS (réutilise `microclimate_detect_years`).

## 10. Décisions — ARBITRÉES (Pascal, 2026-07-02)

1. **`indice_priorite_regen`** = croisement exposition × stress hydrique
   (retravail de `regeneration_index`). **Pénalité par essence : conservée en
   OPTION, désactivée par défaut** — l'indice par défaut est générique (conforme
   au brief) ; l'affinage par essence cible (seuils chaud/sec de
   `regeneration_tolerances.csv`) reste disponible via un argument. Les colonnes
   de sortie sont **renommées sur le §7** (`indice_priorite_regen`, etc.).
2. **Forçage bilan hydrique : SAFRAN primaire** (`biljouR::safran_download`),
   **ERA5-Land en repli** et pour le microclimat. *(donnée officielle FR →
   crédibilité réglementaire.)*
3. **NDP : tag « modèle mécaniste », NDP de base inchangé.** On étend le flag
   augmenté existant (`microclimate_model`, ADR-011) — honnêteté sur la nature
   modélisée, confiance φ prudente ; **pas de NDP 1 forcé**.
4. **Branche A (carte bivariée de tendances estivales E-OBS) : DANS la v1, mais
   à l'échelle du projet** — calculée sur **l'emprise de la zone UGF + un
   buffer** (valeur **à déterminer** — proposition à confirmer : ≥ 2 mailles
   E-OBS, la grille E-OBS faisant ~0,1° ≈ 11 km ; défaut proposé **~25 km**).
   **Pas de carte nationale.**

*(Les ex-décisions « créer regen_nemeton » et « migrer microclimate_run » sont
caduques : tout reste au cœur GPL-3.)*

**Reste à préciser** : la **valeur du buffer** de la carte de tendances (§6
branche A) — défaut proposé ~25 km, à confirmer par Pascal.

## 11. Lots

| Lot | Contenu | Repo | Dépend |
|---|---|---|---|
| **L1** | `pai_depuis_nuage` + `regen_sensibilite` (compléter `microclimate_run`) | `nemeton` | — |
| **L2** | `biljouR` + `regen_bilan_hydrique` + forçage SAFRAN | `nemeton` | — |
| **L3** | couplage PAI→lai_max + `regen_priorite` + contrat NMT (r3 enrichi, colonnes §7, `indice_priorite_regen`) | `nemeton` | L1, L2 |
| **L4** | `mod_regeneration` (UI, run fond, cartes) | `nemetonshiny` | L3 |
| **L5** | profil LLM adaptation + `mod_synthesis` | `nemetonshiny` | L4 |
| **L6** | `service_db` (persistance) + `service_export` (PDF/GPKG/i18n) | `nemetonshiny` | L4 |
| **L7** | calibration BILJOU + validation carto + doc/vignette | les deux | L2-L6 |

## 12. Critères d'acceptation (du brief §10)

- Un jeu d'UG produit un GPKG conforme au §7 + une section PDF Quarto.
- Le radar reflète A/R/W/C sans régression sur les indicateurs existants.
- Les dépendances lourdes restent en `Suggests` ; le cœur reste installable et
  **testable sans réseau** (CI verte sans microclimf/biljouR/LiDAR réels).
- Les UG à `couverture_pct` faible sont signalées et exclues par défaut.
- La synthèse LLM cite `njstress`/`istress`/`sensibilite` + actions.
- Un run est **rejouable depuis le cache** sans re-télécharger LiDAR/forçage.
