# Brief `nemetonshiny` — Onglet « reGénération » COMPLET (spec 027 v2.1, L4-L6)

**Cœur requis** : `nemeton (>= 0.118.0)`.
**Objectif** : un onglet **reGénération** qui, pour un jeu d'UGF, produit une
**lecture de vulnérabilité climatique** (exposition microclimatique × stress
hydrique du sol) pour **prioriser les interventions**, avec cartes, tableau,
fiche parcelle, contexte régional E-OBS, synthèse LLM, persistance et export.

> **Règle d'or (CLAUDE.md)** : le cœur `nemeton` **calcule** ; l'app
> **orchestre + rend**. Aucune logique métier dans `mod_*`. L'app appelle les
> fonctions exportées ci-dessous et affiche leurs sorties.

Ce brief **consolide** le brief branche A
(`brief-nemetonshiny-brancheA.md`, qui reste le détail de la carte de tendances).

---

## 1. Vue d'ensemble du flux (app)

```
UGF (couche projet)
  │
  ├─ [service] acquisition données externes (LiDAR HD, ERA5, SAFRAN, E-OBS)
  │     + agrégations (PAI, micro estival, bilan hydrique, tendances)
  │     → soit moteurs réels, soit sorties « precomputed »
  │
  ├─ nemeton::microclimate_detect_years()        → paire (année moyenne, canicule)
  ├─ nemeton::regen_sensibilite(precomputed=)     → sensibilite, d_tmax, d_vpd, robustesse…
  ├─ nemeton::regen_bilan_hydrique(precomputed=)  → njstress, istress, rew_min, deb_stress
  ├─ nemeton::indicateur_a3/a4/w4/r6(micro=)      → axes radar A/W/R (microclimat)
  ├─ nemeton::indicateur_r3_secheresse(biljou=)   → R3 enrichi (radar R)
  ├─ nemeton::indice_priorite_regen()             → indice_priorite_regen + flags (§7)
  └─ nemeton::tendances_estivales_eobs()          → contexte régional (carte bivariée)
        │
        ▼
  cartes + tableau + fiche parcelle + radar + LLM + export + persistance
```

**Point clé** : chaque brique cœur a un **chemin `precomputed`**. L'app peut
donc fonctionner **dès aujourd'hui** en passant des sorties de moteur
pré-calculées (prototypes `/Documents/reGénération/`, ou un cache), sans avoir
à câbler microclimf/biljouR/LiDAR en direct.

## 2. Contrat cœur — fonctions à appeler (nemeton >= 0.118.0)

### 2.1 Sélection des années (R6 / sensibilité)
```r
yrs <- nemeton::microclimate_detect_years(aoi, eobs = ..., year_window = 10)
# -> list(year_moyenne, year_canicule, indices E-OBS)  (override utilisateur possible)
```

### 2.2 Moteurs (chemin precomputed recommandé côté app)
```r
# PAI (LiDAR HD) — alimente lai_max du bilan hydrique
pai <- nemeton::pai_depuis_nuage(precomputed = pai_raster)          # SpatRaster

# Exposition microclimatique (microclimf) — colonnes §7
units <- nemeton::regen_sensibilite(units, precomputed = sortie_microclimf)
#   -> sensibilite, rang_sensibilite, tmax_moyenne/canicule, vpd_*, d_tmax, d_vpd,
#      robustesse, signal_robuste, couverture_pct  (d_tmax/d_vpd/rang dérivés si absents)

# Bilan hydrique du sol (biljouR, forçage SAFRAN primaire) — colonnes §7
units <- nemeton::regen_bilan_hydrique(units, precomputed = sortie_biljou)
#   -> njstress, istress, rew_min, deb_stress
```
> Sans `precomputed` **et** sans le package moteur installé → **erreur propre
> actionnable** (à afficher tel quel). L'orchestration réelle des moteurs
> (exécuter microclimf/biljouR/lasR) se fait côté service app / machine de
> Pascal ; le cœur fournit alors le contrat, pas le run.

### 2.3 Sous-indicateurs microclimat (radar A/W/R)
Consomment un jeu `micro` de rasters estivaux (sortie de `microclimate_run()`
réel, ou précalculé). Chacun renvoie `units` + colonne 0-100 :
```r
units <- nemeton::indicateur_a3_microclimat(units, micro = micro)   # A3 T°max sous couvert
units <- nemeton::indicateur_a4_tamponnement(units, micro = micro)  # A4 tamponnement
units <- nemeton::indicateur_w4_vpd(units, micro = micro)           # W4 VPD
units <- nemeton::indicateur_r6_sensibilite(units,                  # R6 sensibilité
           micro_moyenne = micro_moy, micro_canicule = micro_can)
```

### 2.4 R3 sécheresse enrichi BILJOU (radar R)
```r
units <- nemeton::indicateur_r3_secheresse(units, dem = dem, biljou = sortie_biljou)
#   ou biljou = NULL : lit njstress/istress/deb_stress déjà sur `units`
#   -> R3 (blend SPEI/topo × BILJOU) + r3_njstress/r3_istress/r3_deb_stress (valeurs brutes)
```

### 2.5 Indice de priorité (tête d'onglet)
```r
units <- nemeton::indice_priorite_regen(units)                 # générique
# ou, affinage par essence cible (OPTION, OFF par défaut) :
units <- nemeton::indice_priorite_regen(units, species = "essence_hetraie")
#   -> indice_priorite_regen (0-100), regen_exposition, regen_hydrique,
#      parcelle_sensible, priorite, regen_essence
tol <- nemeton::regeneration_tolerances()   # table essences (pour un sélecteur)
```

### 2.6 Contexte régional (branche A) — cf. brief dédié
```r
cells <- nemeton::tendances_estivales_eobs(aoi = ugf, tx = ..., rr = ..., buffer_m = 25000)
#   -> sf points : trend_tmax, trend_precip, classe_tmax/precip (1-3), classe_bivariee (1-9)
```

### 2.7 Radar (mise à jour A/W/R sans code dédié)
Une fois les colonnes `A3/A4/W4/R6/R3` présentes, réutiliser l'agrégation
existante — `create_family_index()` + `compute_general_index()` (déjà utilisés
par `mod_synthesis`). **Ne rien ré-inverser** (R5 est le seul « haut=mauvais »
inversé au cœur ; R3/R6 gardent leur sens).

## 3. Schéma de sortie / persistance (§7) — contrat de colonnes

À persister (PostGIS) et exporter (GPKG) par UGF :
`tmax_moyenne`, `tmax_canicule`, `vpd_moyenne`, `vpd_canicule`, `d_tmax`,
`d_vpd`, `sensibilite`, `rang_sensibilite`, `robustesse`, `signal_robuste`,
`rew_min`, `njstress`, `istress`, `deb_stress`, `indice_priorite_regen`,
`regen_exposition`, `regen_hydrique`, `parcelle_sensible`, `priorite`,
`couverture_pct` (+ `A3/A4/W4/R6/R3` normalisés pour le radar).

## 4. UI `mod_regeneration`

### 4.1 Panneau config
- Sélection : **couche UGF du projet** (pas de nouvelle sélection cadastre).
- Années **moyenne / canicule** : pré-remplies par `microclimate_detect_years()`
  (bouton « auto » pour réinitialiser) ; les deux années + leur indice E-OBS
  affichés (traçabilité).
- Peuplement : `forest_type` (feuillu/résineux), `budburst`, `leaf_fall`,
  `lai_max` (auto depuis PAI **ou** saisie).
- Sol : `ewm` (eau extractible) + `roots` (fractions racinaires).
- Forçage : **SAFRAN (défaut)** / ERA5-Land.
- Résolution microclimat : 2 m (défaut) / 5 m si beaucoup de parcelles.
- **Essence cible** (optionnelle) pour l'affinage de l'indice (`species=`).
  **Ne pas construire la liste à la main** — appeler
  `nemeton::regen_species_choices(units)` qui renvoie déjà les options
  *scorables* prêtes (data.frame `code`/`label`/`tmax_tol_c`/`vpd_tol_kpa`/
  `present`/`groupe`). Règles de rendu :
  - Ce sont **exactement** les classes que le cœur sait noter (intersection
    `regeneration_tolerances()` ∩ `list_species_classes()`) — jamais une
    essence hors table (sinon `species=` est sans effet).
  - **Deux `optgroup`** depuis la colonne `groupe` : `"present"` → « Présentes
    sur vos UGF » (en tête ; pré-sélectionner la dominante), `"adaptation"` →
    « Autres essences (adaptation) », triées par `tmax_tol_c` croissant
    (mésophile → thermophile = « alternatives plus tolérantes »).
  - **Défaut** = une entrée « Générique (aucune essence) » ajoutée par l'app,
    mappée sur `species = NULL` (comportement cœur par défaut, pénalité OFF).
  - Colonne d'essence des UGF : `regen_species_choices()` détecte
    `essence_dominante`/`essence`/`species_class`/… ; ces valeurs doivent être
    des **codes de classe** (`essence_hetraie`…), pas des codes BD Forêt
    (`"03"`) — mapper en amont via `map_bdforet_to_species_class()` au besoin.
  - **Honnêteté** : les seuils `tmax_tol`/`vpd_tol` sont **indicatifs** (dire
    d'expert ordinal, non calibrés terrain — spec 027 §7/§12) ; l'affinage
    *ordonne* la priorité, il ne donne pas une limite physiologique absolue.
    À afficher en infobulle. MFR (provenances réglementaires) = **hors indice**,
    étape aval future conditionnée à l'extension du CSV de tolérances.
- **Buffer contexte** : 25 km (défaut, cf. branche A).

### 4.2 Run
- Bouton → **tâche de fond** (ExtendedTask/future ; microclimf = goulot).
- **Barre de progression** + **reprise sur cache** (par emprise/années).
- Mode **« bilan hydrique seul »** rapide (sans microclimf) proposé.
- Message clair si un moteur / une donnée manque (dégradation propre du cœur).

### 4.3 Résultats
- **Carte** (Leaflet, `mod_map`) commutable : `indice_priorite_regen` /
  `sensibilite` / `njstress` / `d_tmax` ; contour des parcelles `priorite`.
- **Carte bivariée ΔT°max × ΔVPD** (parcellaire) + **carte de contexte E-OBS**
  (branche A, palette bivariée 3×3).
- **Tableau** trié par `rang_sensibilite` / `priorite`, colonne `couverture_pct`
  (filtrer les UG mal couvertes par défaut).
- **Fiche parcelle** : chronique REW + flux (si fournie par le service biljou),
  indicateurs sécheresse (`njstress`/`istress`/`deb_stress`), valeurs micro.
- **Radar** A/W/R mis à jour.

## 5. Synthèse LLM (`mod_synthesis` / `llm_prompts`)
- Profil orienté **adaptation / changement climatique** (nouveau, ou étendre
  Gestionnaire des risques). Priorise A/R/W/C, lit
  `njstress`/`istress`/`sensibilite`/`indice_priorite_regen`, formule des
  **recommandations de régénération** (essences plus tolérantes, densité, îlots,
  calendrier) et flague les **conflits inter-profils** (régénération vs
  biodiversité B/N).

## 6. Persistance & export (L6)
- **`service_db`** : table PostGIS **versionnée** des états climatiques par UG
  (schéma §7) — suivi dans le temps (6A Archivage).
- **`service_export`** : section **Quarto « reGénération »** (cartes + tableau
  priorités + indicateurs sécheresse) ; champs §7 ajoutés au GeoPackage ;
  **clés i18n FR/EN**.

## 7. Honnêteté / garde-fous (à afficher)
- Indices **modélisés mécanistes** (pas mesurés terrain) → **NDP : tag « modèle
  mécaniste »**, confiance φ prudente (décision §10.3) ; fiables en **classement
  relatif**, prudents en valeur absolue.
- **BILJOU** : réimplémentation non cautionnée INRAE, à caler (§9.2).
- **PAI ≈ LAI** seulement feuilles présentes ; **canopée figée** pour R6.
- **couverture_pct** : signaler et exclure les UG mal couvertes.
- Licences : E-OBS (recherche non commerciale), LiDAR HD (Etalab), ERA5/SAFRAN.

## 8. Critères d'acceptation
- [ ] Un jeu d'UG → GPKG conforme §7 + section PDF Quarto « reGénération ».
- [ ] Radar A/W/R mis à jour **sans régression** sur les indicateurs existants.
- [ ] Carte de contexte E-OBS sur **emprise UGF + 25 km** (pas nationale).
- [ ] Indice **générique par défaut** ; essence cible = option.
- [ ] Run en tâche de fond, **rejouable depuis le cache**, message clair si
      moteur/donnée manquant.
- [ ] UG à `couverture_pct` faible signalées et exclues par défaut.
- [ ] LLM cite `njstress`/`istress`/`sensibilite` + actions.
- [ ] Tous les textes via `i18n$t()`.

## 9. Lots app (spec 027 §11)
| Lot | Contenu |
|---|---|
| **L4** | `mod_regeneration` (UI, run tâche de fond, cartes, tableau, fiche, radar) |
| **L5** | profil LLM adaptation + `mod_synthesis` |
| **L6** | `service_db` (persistance §7) + `service_export` (Quarto/GPKG/i18n) |

## 10. Dépendance à confirmer
- **`biljouR`** (GPL-3) : dépôt à préciser pour l'ajouter en `Suggests`/`Remotes`
  (côté service qui l'exécute). Le cœur le garde en `requireNamespace`.

## 11. Prérequis d'exécution (rappel)
L'app/service doit fournir les **données externes** et, pour un run réel, faire
tourner les moteurs GPL — OU passer des sorties **`precomputed`** (recommandé
pour démarrer) :
- LiDAR HD (`.laz` classés, MNT/MNH) → `pai_depuis_nuage` / `regen_sensibilite`.
- ERA5-Land (compte CDS) → microclimat ; **SAFRAN** (INRAE/Météo-France) →
  `regen_bilan_hydrique`.
- E-OBS (`tx`/`rr`, agrégés estival par an) → `tendances_estivales_eobs`.
