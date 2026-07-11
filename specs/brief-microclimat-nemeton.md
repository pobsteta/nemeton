# Brief technique — Intégration du microclimat dans Nemeton

**Objet :** ajouter un moteur d'interpolation microclimatique par UG, alimentant (a) les indicateurs des familles **A / C / R** et (b) la logique de classement de l'onglet **reGénération**.
**Deux moteurs proposés, phasés :** `meteoland` (rapide, prêt à l'emploi) et une réimplémentation de la méthode **Joly / LISDQS (MLRK)** (argument scientifique, NDP).
**Cible :** `nemeton` v0.15.1 (package R coeur) + `nemetonShiny` + `tree_sat_nemeton`.
**Statut :** proposition d'architecture — à valider avant sprint.

---

## 1. Objectif

Aujourd'hui Nemeton n'a pas de couche microclimat : les familles **A (Air & Microclimat)** et **R (Risques)** reposent surtout sur des proxys de télédétection. L'objectif est de produire, **par UG**, des variables climatiques interpolées (températures min/moy/max, précipitations, PET/déficit hydrique, éventuellement gel), puis :

1. de les injecter dans le calcul des sous-indicateurs concernés (famille A en premier, croisements C et R) ;
2. d'en dériver un **score de contrainte microclimatique par UG** qui vient nourrir l'aide à la décision de l'onglet **reGénération** (aptitude à la régénération naturelle vs plantation, alerte sur le choix d'essence objectif).

Principe directeur : **une interface unique** dans le package, deux moteurs interchangeables derrière (`engine = "meteoland" | "mlrk"`). On ne recâble pas les indicateurs quand on change de moteur.

---

## 2. Les deux moteurs — ce qui les distingue

Ce ne sont **pas** deux implémentations de la même méthode. Ce sont deux philosophies d'interpolation ; d'où l'intérêt de les offrir toutes les deux.

| Critère | `meteoland` (Option A) | Méthode Joly / MLRK (Option B) |
|---|---|---|
| Méthode | Interpolation pondérée par distance + altitude (Thornton et al. 1997), downscaling De Cáceres et al. 2018 | *Multi-linear Local Regression Kriging* : régression multiple locale sur les *n* stations les plus proches + krigeage ordinaire des résidus |
| Covariables | Élévation (obligatoire), pente, aspect | Libres : altitude, **NDVI**, distance mer/lisière, pente, exposition… |
| Variables sorties | Tmin/Tmoy/Tmax, Précip, HR, Rayonnement, Vent, **PET** | À définir (typiquement T° ; extensible) |
| Maturité | Package CRAN maintenu (v2.2.x), calibration + validation croisée intégrées | À coder ; s'appuie sur `gstat`+`GWmodel`+`FNN` |
| Effort | Faible (jours) | Moyen/élevé (semaines) |
| Atout Nemeton | Time-to-market, robuste, pensé écologie forestière | Argument scientifique, **NDP maison**, NDVI en covariable native, cartes de R²/coefficients locaux |
| Licence | **GPL** → point de vigilance (voir §11) | Code maison → licence au choix (MIT) |

**Recommandation de phasage :** `meteoland` d'abord (MVP fonctionnel qui débloque indicateurs + reGénération), MLRK ensuite comme moteur « premium » différenciant et comme brique de validation croisée.

---

## 3. Insertion dans l'architecture (6A + repos)

| Phase 6A | Où | Ajout |
|---|---|---|
| Acquisition | `nemeton` + `tree_sat_nemeton` | Nouvelle **source « microclimat »** : stations/loggers + MNT + NDVI ré-employé comme covariable |
| Archivage | `service_db` (PostGIS) | Table `ug_microclimate` : variables climatiques agrégées par UG + métadonnées (moteur, NDP, date) |
| Analyse | `service_compute` | Nouveau sous-module `compute_microclimate()` appelé avant le calcul des familles A/C/R |
| Affichage | `mod_family` + `mod_synthesis` + export Quarto | Axe A enrichi sur le radar ; couche microclimat dans l'export |
| Accompagnement | onglet **reGénération** | Score de contrainte microclimatique par UG (voir §5) |

**Placement du code.** Le moteur d'interpolation vit dans le package coeur `nemeton` (fonction publique, testable, réutilisable). Le wiring UI et l'orchestration vivent dans `nemetonShiny`. Cf. §11 pour la licence de `meteoland`.

---

## 4. Indicateurs alimentés

| Famille / sous-indicateur | Apport du microclimat | Variable source |
|---|---|---|
| **A — a1_couverture** | Effet tampon du couvert (amplitude thermique sous canopée) | Tmin/Tmax, croisé au NDVI/couvert |
| **A — a2_qualite_air** | Contexte micro-climatique (ventilation, stagnation) | Vent, HR |
| **A — (nouveau ?) a3_microclimat** | Sous-indicateur dédié : amplitude thermique, indice de continentalité local | Tmin/Tmax/Tmoy |
| **C — c2_ndvi** | NDVI utilisé **en entrée** (covariable) → boucle vertueuse avec `tree_sat_nemeton` | NDVI |
| **R — r3_secheresse** | Déficit hydrique climatique (PET − Précip), nombre de jours de stress | PET, Précipitations |
| **R — r1_feu** | Modulation par aridité estivale locale | PET, Tmax, HR |
| **R — (nouveau ?) r5_gel** | Risque de gel tardif (dernière gelée printanière) — déterminant pour la régénération | Tmin, dates de gel |

> Décision à trancher : créer les sous-indicateurs **a3_microclimat** et **r5_gel** (passage de 31 → 33 sous-indicateurs) ou rester à enrichir les indicateurs existants. Recommandation : créer **r5_gel** (fort intérêt régénération, cf. §5) et garder le microclimat A comme enrichissement de a1/a2 dans un premier temps.

---

## 5. Onglet reGénération — logique d'aide à la décision

C'est le débouché le plus à forte valeur. Le classement des UG (groupe de régénération / amélioration / îlot de vieillissement, à la ONF) et le **choix de l'essence objectif** dépendent fortement du microclimat, que les documents actuels ne quantifient pas.

**Trois contraintes microclimatiques dérivées par UG :**

1. **Gel tardif** — probabilité/fréquence de gelée après débourrement → risque pour semis et jeunes plants (surtout essences sensibles : chêne, hêtre, douglas).
2. **Déficit hydrique estival** (PET − Précip cumulé été) → mortalité des régénérations et plantations en année sèche.
3. **Stress thermique** (Tmax, jours > seuil) → échec d'installation sur stations exposées.

**Sortie proposée :** un `indice_aptitude_regeneration` (0–100) par UG, combinant ces trois contraintes, avec deux usages dans l'onglet :

- **Priorisation** : UG à faible contrainte → régénération naturelle envisageable ; UG à forte contrainte → plantation accompagnée / report / adaptation d'essence.
- **Alerte essence objectif** : croiser la contrainte avec l'autécologie de l'essence proposée (le profil LLM *Gestionnaire forestier* / *Expert sylviculteur* peut rédiger la recommandation à partir de l'indice).

**Intégration LLM :** exposer les 3 contraintes + l'indice dans le prompt YAML des profils sylvicoles, avec seuils d'alerte, pour que la synthèse commente automatiquement l'adéquation régénération/essence/microclimat.

---

## 6. Spécification — Option A : `meteoland`

**Dépendances :** `meteoland` (≥ 2.2), `sf`, `stars`, `terra`. Données de référence via `meteospain`/`worldmet` ou SAFRAN/Météo-France reformatées.

**Pré-requis topo (obligatoire) :** `elevation` (RGE ALTI IGN), `slope`, `aspect` — noms et unités imposés par le package.

**Workflow :**

```r
# 1. Données de référence (stations/loggers) -> sf points avec topo + météo journalière
interp <- with_meteo(ref_stations_sf) |>
  create_meteo_interpolator()                      # objet stars (v2.0+)

# 2. Calibration recommandée (LOO sur N et alpha) -- coûteux, à cacher/versionner
interp <- interpolator_calibration(interp, variable = "MinTemperature", ...) |>
  set_interpolation_params(interp)

# 3. Interpolation sur la grille des UG (stars) OU aux centroïdes (sf points)
ug_meteo <- ug_grid_stars |>
  interpolate_data(interp, dates = periode)

# 4. Agrégation temporelle -> variables par UG
ug_summary <- summarise_interpolated_data(ug_meteo, fun = "mean", frequency = "year")
```

**Validation :** `interpolation_cross_validation(interp)` fournit erreurs, stats par station, R² → à stocker comme métadonnée de confiance.

**NDP :** sortie meteoland ≈ **NDP 1** (interpolation multi-source, confiance ~25 %). Si alimentée par loggers terrain denses → tendre vers NDP 0.

---

## 7. Spécification — Option B : méthode Joly (MLRK)

**Dépendances :** `gstat` + `automap` (krigeage résidus), `GWmodel` **ou** `FNN`/`RANN`+`lm` (régression locale n-plus-proches, fidèle à Joly), `terra`, `sf`.

**Algorithme (par pixel/UG) :**
1. Recherche des *n* stations les plus proches (`FNN::get.knnx`).
2. Régression multiple locale `T ~ altitude + ndvi + dist_lisière + …` sur ces *n* stations (`lm`).
3. Application des coefficients → **tendance** au pixel.
4. Krigeage ordinaire des **résidus** aux stations (`automap::autoKrige`), ajouté à la tendance.

**Fonction cible :** `nemeton::interp_mlrk(stations, covars_rast, n = 30, formula = ...)`.
**Validation :** LOO maison (comparer RMSE MLRK vs meteoland vs GWR pur → argument scientifique + choix du moteur par variable).
**NDP :** paramétrable ; la cartographie du R² local et des coefficients (altitude, etc.) est un livrable original (cf. publications Joly) valorisable dans l'export.

---

## 8. Interface commune (contrat de fonction)

Point d'architecture le plus important : **une seule porte d'entrée**, moteur en paramètre.

```r
nm_microclimate(
  ug,                 # sf des UG (ou grille stars)
  stations,           # sf mesures de référence
  covariates,         # raster stack (elevation, ndvi, ...)
  engine = c("meteoland", "mlrk"),
  variables = c("tmin","tmax","tmean","prec","pet"),
  period,
  ...
)
# -> objet standardisé : 1 ligne par UG, colonnes = variables, + attributs (engine, NDP, cv_stats)
```

Les indicateurs A/C/R et l'onglet reGénération consomment **cet objet standardisé**, jamais l'API du moteur directement. On peut alors changer de moteur, ou en mixer (meteoland pour la pluie, MLRK pour la température), sans toucher au reste.

---

## 9. Données requises

| Donnée | Source | Rôle |
|---|---|---|
| MNT (elevation, slope, aspect) | RGE ALTI IGN (Géoplateforme) | Topographie obligatoire |
| NDVI | `tree_sat_nemeton` (Sentinel-2) | Covariable (MLRK) / indicateur croisé |
| Stations météo de référence | Météo-France / SAFRAN, `meteospain`, `worldmet` | Données à interpoler |
| Loggers de terrain (optionnel mais clé) | Réseau in situ sous couvert | Vrai microclimat forestier, NDP 0 |
| Géométrie UG | `mod_map` / cadastre IGN | Support d'agrégation |

> Rappel de vigilance (cf. échanges précédents) : sans **mesures ponctuelles sous couvert**, on ré-échantillonne des stations hors forêt — la finesse du pixel ne crée pas de l'information microclimatique qui n'est pas dans les données d'entrée.

---

## 10. Plan d'implémentation

| Phase | Contenu | Repo | Sortie |
|---|---|---|---|
| **P1 — MVP meteoland** | `nm_microclimate(engine="meteoland")` + tests + cache interpolateur | `nemeton` | Variables clim. par UG |
| **P2 — Wiring indicateurs** | Brancher A (a1/a2), R (r3), créer r5_gel ; MAJ `service_compute` | `nemeton` | Radar A enrichi |
| **P3 — Onglet reGénération** | `indice_aptitude_regeneration` + 3 contraintes + seuils profils LLM | `nemetonShiny` | Aide décision UI |
| **P4 — MLRK** | `interp_mlrk()` + LOO comparatif + cartes R²/coefs | `nemeton` | Moteur premium + validation |
| **P5 — Export** | Cartes microclimat + section dédiée template Quarto | `nemetonShiny` | PDF/GeoPackage |

---

## 11. Risques & points de vigilance

- **Licence `meteoland` (GPL)** : le package coeur `nemeton` est **MIT**. Prendre une dépendance dure GPL sur le coeur pose une question de compatibilité (copyleft). *Mitigation :* mettre `meteoland` en **Suggests** (pas Imports), ou isoler l'appel dans `nemetonShiny` (**EUPL**, plus compatible). À arbitrer avec la stratégie licences. — **à confirmer : version exacte de la licence meteoland.**
- **Densité de stations** : facteur limitant réel. Prévoir un garde-fou (nb minimal de stations dans le rayon, sinon dégrader le NDP / refuser l'estimation).
- **Convex hull** : `meteoland` alerte sur les points hors enveloppe convexe des stations → gérer les UG en bordure de réseau.
- **Coût de calcul** : calibration meteoland (LOO) et MLRK par pixel peuvent être lourds. Cacher les interpolateurs, versionner, envisager calcul par tuile.
- **Cohérence NDP** : documenter le NDP attribué selon moteur + densité de mesures, pour rester cohérent avec le système de confiance φ.
- **Sur-promesse microclimat** : bien communiquer que sans loggers, la sortie reste un downscaling de stations, pas un microclimat sous couvert mesuré.

---

## 12. Livrables & critères d'acceptation

- [ ] `nm_microclimate()` opérationnel avec `engine="meteoland"`, testé (testthat), documenté (roxygen).
- [ ] Variables climatiques par UG stockées dans `ug_microclimate` (PostGIS).
- [ ] Sous-indicateurs A (a1/a2) enrichis + r5_gel calculé ; radar mis à jour.
- [ ] `indice_aptitude_regeneration` affiché dans l'onglet reGénération avec les 3 contraintes.
- [ ] Rapport de validation croisée (RMSE/R²) archivé.
- [ ] (P4) `interp_mlrk()` + tableau comparatif LOO meteoland vs MLRK vs GWR.
- [ ] Décision licence tranchée (Suggests vs isolation nemetonShiny).

---

*Brief préparé pour le projet Nemeton — API meteoland vérifiée sur v2.2.x (refonte sf/stars) ; méthode MLRK d'après les travaux Joly/LISDQS (ThéMA). À valider avant ouverture de sprint.*
