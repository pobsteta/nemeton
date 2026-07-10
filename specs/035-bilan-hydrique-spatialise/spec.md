# Spec 035 — Bilan hydrique spatialisé par UGF (`ewm` SoilGrids + `lai_max` PAI)

- **Statut** : cadrée, en implémentation
- **Date** : 2026-07-10
- **Package** : `nemeton` (cœur)
- **Chantier parent** : reGénération / microclimat sous couvert (spec 027, ADR-014)
- **Dépend de** : `biljouR` (Suggests), source `soilgrids_*` (nouvelle)

---

## 1. Problème

`regen_bilan_hydrique()` renvoie **la même valeur pour toutes les UGF**.

Constaté sur données réelles (projet `20260701_204501_ltcp`, 30 UGF,
`cache/regeneration/biljou.gpkg`) :

| Colonne | Valeurs distinctes sur 30 UGF |
|---|---|
| `njstress` | 1 (142,5 j partout) |
| `deb_stress` | 1 (jour 122 partout) |
| `istress` | 2 (76,81 / 77,01) |
| `rew_min` | 2 (0,03675 / 0,03698) |

### Diagnostic

`biljouR::biljou_run_grid()` ne fait **pas** de calcul spatial : les colonnes
`lon`/`lat` des points ne sont recopiées qu'en métadonnées de sortie. Le modèle
`biljou_run()` est une fonction pure de `(meteo, soil, lai_max, forest_type,
budburst, leaf_fall)`.

Dans le câblage actuel :

- `sol` ← `build_biljou_soil()` : **un seul** objet uniforme (`ewm = 150` mm).
- `forest_type` : scalaire.
- `lai_max` : scalaire (défaut 5 / 4,5 par type de peuplement).
- `meteo` ← `load_biljou_forcing()` : varie par UGF, mais la maille SAFRAN-ISBA
  fait **8 km** (ERA5-Land : 9 km). Les 30 centroïdes tombent dans **2** mailles
  → 2 séries météo → au plus 2 résultats distincts. `njstress` et `deb_stress`,
  comptages entiers de jours, absorbent l'écart de 0,3 % → uniformité apparente.

**Conclusion.** Le forçage météo est la mauvaise variable à raffiner : sous 8 km,
augmenter sa résolution n'apporterait presque rien à l'échelle de gestion. Les
deux variables qui *doivent* varier par UGF sont **le sol** et **le LAI**.

---

## 2. Décisions

### D1 — Le TWI ne sert **pas** à dériver l'`ewm`. *(rejet motivé)*

Tentation naturelle : `twi.tif` est déjà calculé et caché, et il « ressemble » à
de l'humidité. Rejeté, pour trois raisons.

1. **Grandeurs physiques distinctes.** `ewm` est une *capacité de stockage* (mm),
   fonction de la texture, de la profondeur d'enracinement, des éléments
   grossiers et de la densité apparente. Le TWI = `ln(a / tanβ)` est *sans
   dimension* et décrit une *propension à la saturation par convergence
   latérale* — une propriété de la position topographique.
2. **BILJOU est un modèle 1D.** `biljou_soil()` n'a aucun terme latéral ; son
   unique `bypass = macro/(macro+micro)` est un écoulement macroporeux
   **vertical**. Faire entrer le TWI par l'`ewm`, c'est faire entrer un processus
   latéral par la porte d'un paramètre de stockage.
3. **Double comptage dans R3.** `indicateur_r3_secheresse()` consomme *déjà* le
   TWI en direct (`get_or_compute_twi()` → `topo_risk = 0.4·aspect + 0.3·slope +
   0.3·twi`, `R/indicators-risk.R`) **et** BILJOU (`biljou_weight = 0.5`). Si le
   TWI pilotait l'`ewm`, il entrerait deux fois dans R3 : une fois par
   `topo_risk`, une fois par `ewm → BILJOU → njstress → R3`. Le poids réel du TWI
   deviendrait opaque et non traçable.

Il existe bien un lien réel TWI ↔ `ewm`, mais il passe par la **pédogenèse** (les
bas-fonds convergents accumulent du colluvium, donc des sols plus profonds et
plus fins) — pas par l'hydrologie. Il est site-dépendant et non calibré. Si on
l'exploite un jour, la place honnête du TWI est comme modulateur de **profondeur
d'enracinement**, déclaré comme tel et flaggé non calibré. Hors périmètre 035.

### D2 — Source sol : **SoilGrids 250 m (ISRIC)**, VRT `files.isric.org`

Précédent dans le repo : `soilgrids_cec` (`inst/datasources/FR.json`), même
motif d'URL, CC-BY-4.0, cité Poggio et al. 2021.

VRT tuilés plutôt que le WCS/WMS de `maps.isric.org` : motif déjà en place,
lecture de fenêtre par `/vsicurl/` sans dépendance à un service OGC au moment du
run, pas de dépendance réseau supplémentaire. Accessibilité des cinq propriétés
et des six intervalles de profondeur vérifiée (HTTP 200) le 2026-07-10.

**Facteurs d'échelle** (vérifiés dans la FAQ ISRIC, `docs.isric.org`, non
présumés) :

| Propriété | Unité brute | Facteur | Unité conventionnelle |
|---|---|---|---|
| `clay`, `sand`, `silt` | g/kg | 10 | % (g/100 g) |
| `soc` | **dg/kg** | 10 | g/kg |
| `cfvo` | cm³/dm³ (vol ‰) | 10 | vol % |
| `bdod` | cg/cm³ | 100 | kg/dm³ |
| `cec` | mmol(c)/kg | 10 | cmol(c)/kg |

⚠ `soc` est en **décigrammes** par kg : `%OC = brut / 100`, pas `/10`. Piège
d'un facteur 10 sur toute la réserve utile.

**CRS natif** : Homolosine interrompue (IGH). `load_raster_source()` reprojette
l'AOI vers le CRS du raster avant `crop`, et `safe_extract()` fait de même pour
les polygones — aucun raster n'est reprojeté, donc pas de risque de CRS cassé au
cache (cf. dette « CRS raster par source »).

### D3 — PTF : **Saxton & Rawls (2006)**, pas Tóth et al. (2015)

Tóth et al. 2015 (`euptf`, EU-HYDI) est *meilleure sur l'Europe*, mais ce ne sont
**pas des équations en forme close** : ce sont des modèles de régression/arbres
publiés comme objets R (`euptf`, `euptfv2`). Les utiliser imposerait une
dépendance lourde et un artefact binaire, pour un gain non mesuré à 250 m — la
résolution de SoilGrids domine largement l'erreur de la PTF.

Saxton & Rawls 2006 (SSSAJ 70:1569-1578) est en forme close, implémentable en R
pur sans dépendance, et mondialement utilisée.

**Coefficients retenus** (S, C = fractions 0-1 ; OM = % massique) :

```
θ1500t = -0.024·S + 0.487·C + 0.006·OM + 0.005·(S·OM) - 0.013·(C·OM) + 0.068·(S·C) + 0.031
θ1500  = θ1500t + (0.14·θ1500t - 0.02)

θ33t   = -0.251·S + 0.195·C + 0.011·OM + 0.006·(S·OM) - 0.027·(C·OM) + 0.452·(S·C) + 0.299
θ33    = θ33t + (1.283·θ33t² - 0.374·θ33t - 0.015)

AWC    = (θ33 - θ1500) × (1 - cfvo)
```

**Note de vérification (importante).** Plusieurs transcriptions en ligne (dont le
tutoriel Google Earth Engine) donnent `- 0.002` au lieu de `- 0.02` et `- 0.15`
au lieu de `- 0.015`. Ces variantes ont été **testées numériquement** contre les
valeurs NRCS de FC/WP des classes texturales USDA : elles produisent une capacité
au champ **négative** pour un sable et une **réserve utile négative dans les six
classes**. Elles sont fausses. Les constantes retenues ci-dessus reproduisent les
références (limon : FC 0,280 vs 0,29 attendu ; RU maximale sur le limon).
Le script de discrimination est conservé en test (`test-soil-water.R`).

`OM = %OC × 1.724` (facteur de van Bemmelen).

`bdod` **n'est pas utilisé** en v1 : il n'intervient que dans la correction
optionnelle de compaction (*density factor*) de Saxton, différée.

### D4 — Graduation NDP

| NDP | Source `ewm` |
|---|---|
| 0 | SoilGrids 250 m + PTF Saxton & Rawls *(cette spec)* |
| 1+ | RRP / GIS Sol (réserve utile par UTS, 1:250 000) — couverture régionale inégale |
| 3+ | Analyse de sol terrain |

Hors périmètre 035 : seul le NDP 0 est livré. L'API doit rester ouverte
(argument `source`).

### D5 — `lai_max` = **percentile 90**, pas la moyenne

`biljou_lai()` traite `lai_max` comme le **plateau** de la phénologie (résineux :
`rep(lai_max, ndays)` ; feuillu : plateau du trapèze entre `budburst + ramp` et
`leaf_fall - ramp`). Une moyenne zonale sur les pixels de l'UGF sous-estime ce
plateau — c'est ce que fait `.regen_lai_per_unit()` côté app (`fun = mean`).

On extrait donc un **percentile haut** (défaut P90) du PAI sur les pixels de
l'UGF, robuste aux pixels aberrants là où un simple `max` ne le serait pas.

### D6 — Le per-UGF passe par des **listes nommées par `id`**, jamais des vecteurs

`biljou_run_grid()` indexe ses arguments via :

```r
if (is.list(x) && !is.data.frame(x) && !inherits(x, "biljou_soil"))
  return(function(id) x[[as.character(id)]])
function(id) x     # sinon : la valeur ENTIÈRE, pour chaque point
```

Un **vecteur numérique n'est pas une liste** → il serait passé *entier* à chaque
point. Conséquences vérifiées expérimentalement :

- **Résineux** : `rep(c(3,5,7), 365)` → série de **1095** valeurs. `biljou_run()`
  lit `lai_series[t]` pour `t = 1..365` → le LAI des UGF défile **jour après
  jour** (`3, 5, 7, 3, 5, 7…`). Aucune erreur, aucun warning. Corruption
  silencieuse.
- **Feuillu** : `lai[i] <- lai_max * (...)` → warning `number of items to replace
  is not a multiple of replacement length`, seul le premier élément est retenu.

Donc : `regen_bilan_hydrique()` **doit** convertir tout vecteur per-UGF en liste
nommée par `id`, et **doit** refuser une longueur qui n'est ni 1 ni `nrow(units)`.
C'est un garde-fou de correction, pas de confort.

L'exclusion explicite `!inherits(x, "biljou_soil")` dans `as_fun()` autorise
symétriquement une **liste nommée d'objets `biljou_soil`** — c'est le chemin
per-UGF du sol.

---

## 3. API livrée

```r
# PTF pure, testable, exportée pour audit par un pédologue.
awc_saxton_rawls(clay, sand, om, coarse = NULL)
#> réserve utile volumique (m³/m³), NA in -> NA out

# ewm (mm) par UGF, intégrée sur la profondeur d'enracinement.
ewm_depuis_soilgrids(units, rooting_depth_cm = 100, country = "FR",
                     depths = NULL, progress_callback = NULL)
#> numeric, length = nrow(units)

# lai_max (plateau) par UGF depuis le PAI LiDAR caché.
lai_max_depuis_pai(units, pai, probs = 0.9, min_pai = 0.1)
#> numeric, length = nrow(units)

# Sol : scalaire (v0.146.x) OU per-UGF (liste nommée par id).
build_biljou_soil(units = NULL, ewm = 150, source = c("uniform", "soilgrids"),
                  rooting_depth_cm = 100, country = "FR", ...)

# Moteur : accepte désormais lai_max / sol per-UGF.
regen_bilan_hydrique(units, meteo, sol, lai_max, ...)
```

### Rétrocompatibilité

Stricte. `source = "uniform"` et un `ewm` scalaire reproduisent le comportement
v0.146.x (un `biljou_soil` unique). `lai_max` scalaire inchangé. Les nouveaux
arguments sont additifs.

---

## 4. Effets attendus

Une fois `ewm` et `lai_max` per-UGF branchés, la météo reste constante sous 8 km,
mais le sol et le LAI portent la variance inter-UGF. `njstress`, `istress`,
`rew_min` et `deb_stress` cessent d'être constants.

`indicateur_r3_secheresse()` en bénéficie mécaniquement (`biljou_weight = 0.5`),
sans double comptage du TWI (cf. D1).

---

## 5. Hors périmètre

- RRP / GIS Sol (NDP 1+), ESDAC TAWC (licence à vérifier, non présumée ouverte).
- Correction *density factor* de Saxton via `bdod`.
- Modulation de la profondeur d'enracinement par le TWI (cf. D1).
- Câblage app (`nemetonshiny`) : fera l'objet d'un brief séparé.

---

## 6. Références

- Granier A., Bréda N., Biron P., Villette S. (1999). *A lumped water balance
  model to evaluate duration and intensity of drought constraints in forest
  stands.* Ecological Modelling 116:269-283. — modèle BILJOU, `REW`, seuil
  `rew_c = 0.4`.
- Saxton K.E., Rawls W.J. (2006). *Soil Water Characteristic Estimates by Texture
  and Organic Matter for Hydrologic Solutions.* SSSAJ 70:1569-1578. — PTF retenue.
- Tóth B. et al. (2015). *New generation of hydraulic pedotransfer functions for
  Europe.* EJSS 66:226-238. — écartée (D3), modèles non closed-form.
- Poggio L. et al. (2021). *SoilGrids 2.0: producing soil information for the
  globe with quantified spatial uncertainty.* SOIL 7:217-240.
