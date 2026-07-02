# Spec 027 — Onglet « reGénération » : vulnérabilité climatique par parcelle

**Statut** : **RÉALIGNÉE sur le brief `/home/pascal/Documents/reGénération/`
(2026-07-02).** À valider avant reprise du code (paperwork avant code).
**Version** : 2.0.0 (réalignement) — remplace le cadrage 1.x du 2026-06-30 qui
avait **réduit le périmètre** au seul microclimat.
**Cibles** : `nemeton` (cœur — contrat d'indicateurs, MIT) · **`regen_nemeton`
(NOUVEAU repo — moteurs GPL-3)** · `nemetonshiny` (onglet, EUPL v1.2).
**ADR associé** : **ADR-014** (« reGénération : moteurs GPL isolés en
`regen_nemeton`, contrat MIT au cœur ») — brouillon dans
`ADR-014-draft.md` (ce dossier), à porter dans `platform_nemeton/docs/`.
Amende **ADR-009** (ajoute un 5ᵉ repo) et **ADR-011** (flag augmenté).
**Sources brief** : `brief-onglet-regeneration.md`, `README.md`, et prototypes
`pai_lidarhd_lasR.R`, `microclimat_parcelles_robuste.R` (B4),
`microclimat_parcelles_2annees.R`, `carte_tendances_estivales_eobs.R`.

> ### ⚠️ Pourquoi ce réalignement
> Le cadrage 1.x (spec 027 v1, 2026-06-30) et l'implémentation qui a suivi
> (indicateurs A3/A4/W4/R6 + `regeneration_index`, livrés cœur) ont été faits
> **sans remonter au brief de référence**. Ils ne couvrent que **la moitié
> microclimat** et tranchent **à l'inverse** la décision licences §8.1 du brief
> (moteurs GPL mis dans le cœur MIT via `Suggests`, au lieu d'un repo GPL
> séparé). Cette v2 recolle au brief : **deux moteurs** (exposition
> microclimatique **+** bilan hydrique du sol BILJOU), **isolement GPL** dans
> `regen_nemeton`, **schéma de sortie §7**, indice de priorité = **croisement
> exposition × stress hydrique**.

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

## 2. Architecture & licences (décision structurante — ADR-014)

> **Bloquant, tranché dans le brief §8.1 :** `biljouR`, `microclimf`, `lidR`,
> `lasR` sont **GPL-3**. Ils ne doivent **pas** devenir des dépendances du cœur
> `nemeton` (MIT). → **5ᵉ repository `regen_nemeton` (GPL-3)**, consommé par
> `nemetonshiny` (EUPL v1.2, compatible GPL-3 en distribution). Respecte la
> logique multi-repo ADR-009 et garde le cœur MIT propre.

| Brique | Repo | Rôle | Licence |
|---|---|---|---|
| Contrat d'indicateurs (codes NMT A/R/W/C, NDP, normalisation) | `nemeton` | **déclare + normalise** ; consomme des rasters/`sf` **précalculés**, aucune dép GPL | MIT |
| Moteur PAI LiDAR HD (`pai_depuis_nuage`) | **`regen_nemeton`** | PAI mur-à-mur depuis nuage `.laz` | GPL-3 |
| Moteur microclimat (`microclimf`) | **`regen_nemeton`** | ΔT°max, ΔVPD, tamponnement, sensibilité, robustesse | GPL-3 |
| Moteur bilan hydrique (`biljouR`) | **`regen_nemeton`** | REW, NJstress, Istress, forçage SAFRAN | GPL-3 |
| Onglet `mod_regeneration`, persistance PostGIS, export | `nemetonshiny` | UI, orchestration tâche de fond, historisation, PDF/GPKG | EUPL v1.2 |

Sens des dépendances : `regen_nemeton` → `nemeton` (contrat) ; `nemetonshiny`
→ `nemeton` **et** `regen_nemeton`. Jamais l'inverse.

## 3. Réconciliation avec l'existant (déjà livré cœur)

Sont **déjà dans `nemeton`** (livrés avant ce réalignement) :

| Élément livré | Devenir proposé (à trancher, §10) |
|---|---|
| `indicateur_a3_microclimat`, `a4_tamponnement`, `w4_vpd`, `r6_sensibilite` | **Restent au cœur** (MIT) : ils consomment un `micro` **précalculé**, sans dépendance GPL. Conformes au rôle « le cœur déclare/normalise ». |
| `microclimate_run()` (scaffold appelant `microclimf`) | **Migrer** vers `regen_nemeton` (c'est un moteur GPL). Le cœur n'appelle plus microclimf. |
| `microclimate_detect_years()` (E-OBS) | À arbitrer : E-OBS n'est pas GPL → peut rester au cœur, ou suivre le moteur. |
| **`regeneration_index()` + `regeneration_tolerances()`** (v0.115.0, **non mergé**, parké) | **Retravailler** : l'indice cible du brief est un **croisement exposition × stress hydrique** (`indice_priorite_regen`), pas une moyenne pondérée A3/A4/W4/R6. La **pénalité par essence** (inventée hors brief) est à statuer : la garder comme raffinement optionnel, ou la retirer. |

## 4. Pipeline (par jeu de parcelles)

```
UG (GPKG) ─┬─► [regen_nemeton] pai_depuis_nuage(.laz) ─► PAI raster
           │                                              │
           │      LiDAR HD MNT/MNH ─► dtm, hgt            ▼
           │                              microclimf(veg, soil, forçage ERA5)
           │                                    ├─► ΔT°max, ΔVPD par pixel
           │                                    └─► agrégat UG ─► sensibilité, robustesse
           │
           └─► [regen_nemeton] lai_max ⇐ PAI(UG) ─► biljouR::biljou_run_grid(SAFRAN, sol)
                                                     └─► REW, NJstress, Istress par UG
                                            │
                    indice_priorite_regen ◄─┘  (croisement exposition × stress hydrique)
```

**Couplage clé** : le PAI par parcelle (`pai_depuis_nuage`) alimente le
`lai_max` de `biljou_run_grid()`. ⚠️ PAI ≈ LAI **uniquement** en acquisition
*feuilles présentes* — paramètre/conversion à exposer (§9.3).

## 5. Contrat côté `nemeton` (MIT — déclare, ne calcule pas les moteurs GPL)

1. **Enrichir `indicateur_r3_secheresse`** pour accepter les métriques BILJOU
   (`njstress`, `istress`, `deb_stress`) en plus du score 0-100 — exposer les
   **valeurs brutes** (jours, indice), pas seulement le score (conformité).
2. **Sous-indicateurs microclimat** (déjà là) : A3/A4/W4/R6, avec les champs
   bruts `d_tmax`, `d_vpd`, `sensibilite`, `robustesse`.
3. **Normalisation** 0-100 ↔ valeurs physiques (déjà via `normalize_indicator`
   / `create_family_index`, radar 12 axes inchangé).
4. **Schéma de sortie documenté** (§7) comme contrat de colonnes.
5. **Aucune dépendance GPL** au `DESCRIPTION` de `nemeton` (vérif R-CMD-check).

Interfaces `regen_nemeton` à stabiliser (prototypées) :

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

**Branche A (national/régional, optionnelle)** : reproduction de la carte
bivariée de tendances estivales E-OBS (T°max × précipitations) — contexte
régional, prototypes `carte_tendances_estivales_eobs.R` / `…_avec_animation.R`.

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
  UG (6A Archivage) ; section Quarto « reGénération » ; champs GPKG §7 ; i18n
  FR/EN.

## 9. Contraintes & décisions du brief (rappel)

- **9.1 Licence** (bloquant) : repo `regen_nemeton` GPL-3, cœur MIT intact — cf.
  ADR-014.
- **9.2 Crédibilité BILJOU** : réimplémentation **non cautionnée INRAE**,
  constantes à **caler sur BILJOU officiel** ; communiquer en **classement
  relatif** (prudence en valeur absolue).
- **9.3 Hypothèses physiques** : PAI ≈ LAI si feuilles présentes ; sol
  uniforme ; **canopée figée** pour les comparaisons inter-annuelles (isole
  l'effet climatique, pas mortalité/éclaircies/scolytes).
- **9.4 Performance** : `microclimf` = goulot → tâche de fond + cache + mode
  « bilan hydrique seul » rapide.
- **9.5 Années** : proches de l'acquisition LiDAR (~2021+) ; classement
  chaud/frais vérifié sur E-OBS (réutilise `microclimate_detect_years`).

## 10. Décisions à trancher (avant reprise du code)

1. **Créer `regen_nemeton`** (GPL-3) ? confirmer le nom + l'org GitHub. *(brief
   §8.1 — bloquant.)*
2. **A3/A4/W4/R6 restent-ils au cœur** (MIT, consomment `micro` précalculé),
   `microclimate_run` migrant vers `regen_nemeton` ? *(reco : oui.)*
3. **`regeneration_index`** : le retravailler en `indice_priorite_regen`
   (croisement exposition × stress hydrique) — garder ou retirer la **pénalité
   par essence** (hors brief) ? Renommer les colonnes de sortie sur le §7 ?
4. **Forçage** : SAFRAN primaire via `biljouR::safran_download` confirmé ?
5. **Tag NDP** : indicateurs **modélisés mécanistes** → NDP 1 forcé, ou un
   flag/tag dédié « modèle mécaniste » (amende ADR-011, déjà flag
   `microclimate_model`) ?
6. **Branche A E-OBS nationale** : dans le périmètre v1 de l'onglet, ou lot
   ultérieur ?

## 11. Lots (du brief §9)

| Lot | Contenu | Repo | Dépend |
|---|---|---|---|
| **L0** | Arbitrage licence + création `regen_nemeton` | org | — |
| **L1** | `pai_depuis_nuage` + `regen_sensibilite` (microclimat) | `regen_nemeton` | L0 |
| **L2** | `biljouR` + `regen_bilan_hydrique` + forçage SAFRAN | `regen_nemeton` | L0 |
| **L3** | couplage PAI→lai_max + `regen_priorite` + **contrat NMT** (r3 enrichi, colonnes §7) | `regen_nemeton`, `nemeton` | L1, L2 |
| **L4** | `mod_regeneration` (UI, run fond, cartes) | `nemetonshiny` | L3 |
| **L5** | profil LLM adaptation + `mod_synthesis` | `nemetonshiny` | L4 |
| **L6** | `service_db` (persistance) + `service_export` (PDF/GPKG/i18n) | `nemetonshiny` | L4 |
| **L7** | calibration BILJOU + validation carto + doc/vignette | tous | L2-L6 |

**Ordre** : L0 (licence) → moteurs (`regen_nemeton`) + contrat (`nemeton`) →
app. Rien de nouveau au cœur avant la décision §10.1.

## 12. Critères d'acceptation (du brief §10)

- Un jeu d'UG produit un GPKG conforme au §7 + une section PDF Quarto.
- Le radar reflète A/R/W/C sans régression sur les indicateurs existants.
- Le cœur `nemeton` reste **sans dépendance GPL** (`DESCRIPTION` + R-CMD-check).
- Les UG à `couverture_pct` faible sont signalées et exclues par défaut.
- La synthèse LLM cite `njstress`/`istress`/`sensibilite` + actions.
- Un run est **rejouable depuis le cache** sans re-télécharger LiDAR/forçage.

---

## Annexe — Historique du cadrage v1 (2026-06-30, périmètre réduit, conservé pour trace)

<details>
<summary>Cadrage initial microclimat-seul (superseded par cette v2)</summary>

Le cadrage v1 ne retenait que l'exposition microclimatique (microclimf), avec
les sous-indicateurs A3 (T°max sous couvert), A4 (tamponnement), W4 (VPD),
R6 (sensibilité canicule/moyenne), un pipeline `microclimate_*` dans le cœur
(microclimf en `Suggests`), un flag NDP `microclimate_model`, la détection auto
des années via E-OBS (`microclimate_detect_years`), et un indice composite
`regeneration_index` = moyenne pondérée équipondérée + tolérances par essence.

Livrés cœur : A3/A4/W4/R6 (familles A/W/R), `microclimate_run` (scaffold),
`microclimate_detect_years`. Parké (non mergé) : `regeneration_index` +
`regeneration_tolerances`. **Ces éléments sont réconciliés au §3.** Le bilan
hydrique BILJOU et l'isolement GPL `regen_nemeton` étaient **absents** de v1 —
c'est l'objet du réalignement.
</details>
