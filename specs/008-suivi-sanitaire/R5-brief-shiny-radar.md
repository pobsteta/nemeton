# Brief Shiny — Brancher R5 dépérissement dans le radar Néméton

**Repo** : `nemetonshiny` · **Cible** : `vX.Y.0` (minor, `feat:`)
**Plancher** : `Imports: nemeton (>= 0.99.1)`
**Débloqué par** : `nemeton::indicateur_r5_deperissement()` (L4) + l'inversion de sens
R5 dans `normalize_indicator()` (cœur **v0.99.1**).

---

## Contexte

R5 est le **32ᵉ indicateur** (conditionnel) de la famille **R — Risques & Résilience**.
Aujourd'hui il n'est **pas** branché côté app : la famille R = R1-R4 (`app_config.R:275-276`),
et R5 n'existe que comme placeholder i18n « future » (`utils_i18n.R:3667-3672`). Ce brief
le branche.

⚠️ **Deux pièges spécifiques à R5** (lire avant de coder) :

1. **NE PAS ré-inverser R5.** Le cœur **inverse déjà** R5 dans
   `normalize_indicator()` (v0.99.1) : `indicateur_r5_deperissement()` renvoie un score
   **brut « haut = dépérissement »** (mauvais), et `create_family_index()` le retourne en
   « haut = bon » au moment de la normalisation. L'app doit passer R5 **brut, tel quel**.
   Tout `100 - R5` / `invert` côté app **re-casserait** le sens.

2. **R5 ne vient pas du pipeline d'indicateurs standard.** R1-R4 sont calculés par UGF à
   partir de rasters/sf. R5, lui, se calcule à partir des **alertes de dépérissement**
   (table `alert`, types `fordead_dieback` / `reconfort_dieback`), **routé par essence**.
   Il faut donc l'injecter au bon endroit, avec les alertes en main.

---

## API cœur

```r
nemeton::indicateur_r5_deperissement(
  units,                      # sf des UGFs (project$indicators_sf), AVEC colonne d'essence
  fordead_results   = NULL,   # list(alerts_sf = <sf des alertes fordead_dieback de la zone>)
  reconfort_results = NULL,   # list(alerts_sf = <sf des alertes reconfort_dieback de la zone>)
  min_resineux = 0.3, min_feuillus = 0.3,
  resineux_col = NULL, feuillus_col = NULL,   # parts par UGF (optionnel, meilleur routage)
  include_low_classes = FALSE                 # garde-fou G1 : FORDEAD garde 3-forte/4-sol-nu
)
# -> ajoute deux colonnes aux UGFs :
#    R5        (numeric 0-100, BRUT "haut = dépérissement", NA si non calculé)
#    r5_status (calculated | calculated_reconfort | skipped_no_* | skipped_no_method)
```

- Seul `$alerts_sf` est consommé dans chaque `*_results` → on peut **reconstruire** ces
  listes depuis la table `alert` (pas besoin de garder l'objet de run en mémoire).
- Routage : RECONFORT pour chêne/châtaignier/pin sylvestre, FORDEAD pour épicéa/sapin.
  La colonne d'essence est cherchée parmi `essence_dominante`, `essence`, `species_label`,
  `species`, `essence_principale`. Si l'app a des **parts** par UGF, passer `resineux_col` /
  `feuillus_col` (routage plus fin).

---

## Étapes de câblage

### 1. `app_config.R` (≈ l. 275-276) — ajouter R5 à la famille R
```r
indicators   = c("R1", "R2", "R3", "R4", "R5"),
column_names = c("indicateur_r1_feu", "indicateur_r2_tempete",
                 "indicateur_r3_secheresse", "indicateur_r4_abroutissement",
                 "indicateur_r5_deperissement"),
```
(Le cœur a déjà R5 dans sa config famille R ; on aligne celle de l'app.)

### 2. Calculer R5 dans `indicators_sf` (service_compute / mod_synthesis)
Au moment où l'app dispose des UGFs **et** de la zone de suivi liée (spec 011) :
```r
zid <- <zone_id liée au projet>
# list_alerts() renvoie un sf (EPSG:4326) avec colonnes alert_type,
# confidence_class, area_m2, ... pour la zone. ATTENTION : il NE filtre PAS
# par alert_type → on passe classes = NULL (toutes classes) et on SÉPARE en R.
# (indicateur_r5_deperissement ré-applique lui-même le filtre de classes G1
#  propre à chaque méthode : 3-forte/4-sol-nu pour FORDEAD, 2/3 pour RECONFORT.)
all_alerts       <- nemeton::list_alerts(con, zid, classes = NULL)
fordead_alerts   <- all_alerts[all_alerts$alert_type == "fordead_dieback",   ]
reconfort_alerts <- all_alerts[all_alerts$alert_type == "reconfort_dieback", ]

indicators_sf <- nemeton::indicateur_r5_deperissement(
  units             = indicators_sf,                       # UGFs (avec essence)
  fordead_results   = list(alerts_sf = fordead_alerts),
  reconfort_results = list(alerts_sf = reconfort_alerts)
)
# -> colonne R5 (brute) + r5_status ajoutées
```
`list_alerts(con, zone_id, classes = NULL, validation_status = NULL, period = NULL)` :
signature réelle (pas d'argument `alert_type`). L'sf retourné porte `confidence_class`
et `area_m2`, les deux colonnes exigées par `indicateur_r5_deperissement` ; le CRS 4326
est reprojeté en interne. Un sous-ensemble vide (0 ligne) → la méthode est `skipped` (R5 NA),
sans erreur.
- Si aucune alerte / aucun run pour la zone → R5 = NA partout, `r5_status = skipped_*` :
  c'est **normal** et géré (cf. étape 4).
- ⚠️ **Ne pas transformer R5 ici.** On le laisse brut ; l'inversion est faite par le cœur
  au moment de `create_family_index`.

### 3. `service_compute.R` — listes d'indicateurs
- Liste maître de calcul (≈ l. 238-239) : ajouter `R5` **uniquement si** l'app veut le
  traiter comme un indicateur calculable ; sinon le laisser hors de cette liste (R5 est
  injecté à l'étape 2, pas calculé comme R1-R4).
- `col_map` d'extraction des résultats (≈ l. 3354-3357) : ajouter
  `"indicateur_r5_deperissement" = "R5"` **si** R5 transite par ce mapping.

### 4. `mod_synthesis.R` (≈ l. 109-121, 184-189) — radar + indice général
**Rien à changer dans la logique** : `create_family_index(base_sf, method = "mean", na.rm = TRUE)`
prend R5 automatiquement (détecté par la colonne `R5` / `indicateur_r5_deperissement`),
**l'inverse via `normalize_indicator`**, et l'agrège dans `famille_risque`. `na.rm = TRUE`
fait qu'une UGF à R5 = NA est notée sur R1-R4 seuls. L'indice général
(`nemeton::compute_general_index`) suit sans modification.
→ Vérifier juste que `base_sf <- project$indicators_sf` **contient bien** la colonne R5
(issue de l'étape 2) avant l'appel.

### 5. `service_db.R` (≈ l. 457-460, 509) — persistance
Ajouter `R5` (et éventuellement `r5_status`) aux listes de colonnes si l'app persiste
`indicators_sf` en base / cache.

### 6. i18n (`utils_i18n.R`) — activer les libellés
Les placeholders existent (l. 3667-3672 : `r5_label`, `r5_tooltip`). Les rattacher au rendu
radar (l. 1579-1582 pour les labels de risque, l. 317-320 de `mod_progress.R`). Reformuler le
tooltip côté app pour cohérence : **« Score élevé = faible dépérissement »** (le radar montre
la valeur inversée, haut = bon), FORDEAD **et** RECONFORT.

---

## Tests (`testServer` sur `mod_synthesis` / le service)
- **R5 présent** quand la zone a des alertes : colonne `R5` ajoutée, `r5_status` ∈
  `{calculated, calculated_reconfort}`, `famille_risque` **baisse** quand le dépérissement
  augmente.
- **R5 = NA** sans run dieback : pas de plantage, famille R notée sur R1-R4.
- **Pas de double-inversion** : mocker `nemeton::indicateur_r5_deperissement` pour renvoyer
  R5 = 80 (dieback sévère) sur une UGF avec R1-R4 = 70, et vérifier que `famille_risque` ≈ 60
  (et **non** 72) — preuve que l'app ne ré-inverse pas et que le cœur a bien inversé.

## Version
- `Imports: nemeton (>= 0.99.1)`.
- Release **`nemetonshiny@vX.Y.0`** (`feat:` — branche R5 dans le radar).
- Ordre respecté : `nemeton@v0.99.1` publié → l'app bump + propage via `@*release`.

## Rappel central
`indicateur_r5_deperissement()` = brut « haut = dépérissement ». `normalize_indicator()`
(cœur, v0.99.1) = inverse R5 pour le radar. **L'app passe R5 brut et ne l'inverse jamais.**
