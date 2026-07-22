# Spec 040 — `volume_mobilisable()` : couplage P1 → `volume_champ` (desserte)

**Version** : 1.0.0
**Date**    : 2026-07-22
**Statut**  : **Cadré — non implémenté.**
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` — `volume_mobilisable()` + table de taux de prélèvement.
**Cible aval** : `foretaccess` — argument `volume_champ` de `calculer_flux()`,
`reseau_desserte()`, `optimiser_reseau()`.
**Cible app**  : `nemetonshiny` — sous-onglet Desserte (typage du réseau).
**Origine** : brief app `brief-desserte-perf-connexite.md` §6 + plan de dev app
`plan-dev-sous-onglet-desserte.md` §176-179 (« vrai volume = indicateur P1 →
couplage cœur, ne pas dupliquer le calcul — règle 1 »).

> **Dépendance amont** : cette spec ne débloque **rien** tant que les deux
> blocages `foretaccess` du brief desserte (perf des moteurs, sémantique de
> `connexe`) ne sont pas levés. Le typage du réseau est en 6ᵉ position du plan de
> dev app. Spec cadrée maintenant pour que le couplage soit prêt le jour venu.

## 1. Objectif

Fournir, côté cœur, la colonne de volume que `foretaccess` attend en
`volume_champ`, **sans dupliquer le calcul de volume** (règle 1) et **sans se
tromper d'unité** (cf. §3, le piège central de cette spec).

`nemeton` reste la seule source du volume ; `foretaccess` reste le seul moteur de
réseau. La fonction de cette spec est la **jointure** entre les deux.

## 2. Le problème — trois écarts entre P1 et `volume_champ`

`indicateur_p1_volume()` (`R/indicators-productive.R:99`) renvoie `P1` en
**m³/ha**, volume **sur pied**, calculé par tarif IFN `V = a·DBH^b·H^c` × densité.

| | P1 (cœur) | `volume_champ` (foretaccess) |
|---|---|---|
| **Unité** | m³/ha (densité) | dépend du consommateur — cf. §3 |
| **Sémantique** | volume **sur pied** (stock) | volume **mobilisé** (`calculer_flux` documente « harvested parcels ») |
| **Disponibilité** | `NA` sans species/dbh/density (ou voie CHM synthétique) | aucune politique NA définie en aval |

## 3. Le piège — `volume_champ` a deux consommateurs de sémantique opposée

Vérifié dans le code de `foretaccess` (v1.6.1) :

- **`calculer_flux()`** — `desserte_flux.R:257` : `v <- c(v, rep(vols[i] / np, np))`.
  Le volume de la parcelle est **réparti** sur ses `np` points sources, puis
  accumulé le long du réseau jusqu'à l'exutoire. C'est donc un **total par
  parcelle, en m³**. Une densité m³/ha y produirait un flux faux d'un facteur
  égal à la surface.
- **`reseau_desserte()` / `optimiser_reseau()`** — `desserte_reseau.R:319` :
  `vol_r <- terra::rasterize(v, grille, field = volume_champ)`. Chaque cellule de
  la parcelle reçoit **la valeur telle quelle**, comme poids de priorisation du
  glouton. Les cellules étant d'aire égale, c'est une **densité m³/ha** qui est
  correcte ; un total serait compté autant de fois qu'il y a de cellules dans la
  parcelle, surpondérant mécaniquement les grandes parcelles.

**Conséquence** : il n'existe pas « un » volume à passer. Toute implémentation qui
ignore cette distinction est fausse chez l'un des deux consommateurs. D'où
l'argument `unite` (décision D2).

## 4. Fonction

```r
volume_mobilisable(
  units,
  volume_col      = "P1",          # colonne m³/ha produite par indicateur_p1_volume()
  unite           = c("m3_total", "m3_ha"),
  taux_prelevement = NULL,          # m³/ha/an : scalaire, vecteur, ou NULL -> table IFN×SER
  horizon_ans     = NULL,           # obligatoire dès qu'un taux annuel est utilisé (§5.a-2)
  ser             = NULL,           # code SER par unité ; NULL -> résolu par ser_pour_unites()
  species_field   = "species",
  na_policy       = c("na", "zero", "error"),
  column_name     = "volume_mobilisable"
)
```

→ `sf` d'entrée + une colonne `column_name`.

- `unite = "m3_total"` (défaut) : `P1 × surface_ha` puis × taux → **m³**, pour
  `calculer_flux()`.
- `unite = "m3_ha"` : `P1 × taux` → **m³/ha**, pour `reseau_desserte()` /
  `optimiser_reseau()`.
- Surface calculée par `sf::st_area()` / 1e4, sur la géométrie projetée (pas de
  CRS géographique silencieux — cf. `project_raster_crs_by_source`).

## 5. Taux de prélèvement (décision D1)

**Décidé** : taux paramétrable **avec défaut**, surchargeable par une **table par
essence / type de peuplement**, sur le modèle de
`inst/extdata/european_species_tolerances.csv` + son accesseur.

- `taux_prelevement` scalaire → appliqué à toutes les unités ;
- `taux_prelevement` vecteur de `nrow(units)` → par unité (voie « fourni par
  l'appelant ») ;
- `NULL` → résolution par essence via la table, repli sur un défaut global, avec
  un dernier repli feuillu/résineux via `is_conifer()` (`R/site_index.R:93`) pour
  les codes absents de la table — même logique de repli que P1 lui-même.

### 5.a — Source des taux (décision D4, **tranchée 2026-07-22**)

**Retenu : taux de prélèvement IFN par essence × SER** (sylvoécorégion IGN). Cohérent
avec les tables déjà embarquées, qui portent toutes leur provenance par ligne
(`ifn_volume_equations.csv` → `source = IFN_tarifs_2016` ;
`productivity_tables.csv` → `reference = ONF_Tables_Production_2021`).

Trois conséquences, à intégrer au plan (§11) — ce ne sont pas des détails :

**(1) Le cœur ne sait pas ce qu'est une SER.** Aucune occurrence de
sylvoécorégion / SER / GRECO dans `R/` ni dans `inst/datasources/FR.json` (les
seules couches `ign_wfs` déclarées sont bdforet, roads, water, buildings,
departments). Keyer un taux par SER suppose donc d'abord de **savoir dans quelle
SER tombe une UGF** : nouvelle source à déclarer + loader + jointure spatiale.
C'est le vrai coût de D4, bien plus que le CSV.

**(2) Un taux IFN est un flux annuel, pas une fraction.** L'IFN publie un
prélèvement en **m³/ha/an** (ou un ratio prélèvement/production), sur une période
d'enquête glissante. Le flux de desserte, lui, veut un volume **par épisode de
récolte / par horizon de planification**. La conversion exige donc un paramètre
`horizon_ans` explicite :
`volume = P1 × taux(m³/ha/an) × horizon_ans` — et non `P1 × fraction`.
La signature du §4 est amendée en conséquence.

**(3) Un prélèvement observé n'est pas une prescription.** Le taux IFN décrit ce
qui **a été** récolté, pas ce qu'il **faudrait** récolter. Dimensionner une
desserte dessus revient à faire l'hypothèse « la gestion continue comme avant ».
Hypothèse légitime pour un premier chiffrage, mais elle doit être **écrite dans la
doc de la fonction**, pas implicite.

**Garde-fou maintenu** : tant que la table n'est pas construite et sourcée, le
mode table échoue proprement (`cli::cli_abort` explicite) et seules les voies
scalaire / vecteur sont livrées. Aucun chiffre inventé (leçon spec 027).

## 6. Politique NA (décision D3, ouverte)

P1 est `NA` dès qu'il manque species/dbh/density et que la voie CHM n'a pas
alimenté `ensure_inventory_fields()`. **En NDP 0 — l'état normal de l'app — c'est
le cas courant.** En aval, une parcelle à volume `NA` casse l'accumulation de flux
(`tapply` puis somme) ou, pire, la fait passer silencieusement pour nulle.

- `na_policy = "na"` (défaut) : la colonne reste `NA`, la fonction **avertit** du
  nombre d'unités concernées ; c'est à l'appelant de filtrer. Le contrat est
  explicite, rien n'est inventé.
- `na_policy = "zero"` : `NA → 0` (parcelle non mobilisée). Pratique pour l'app,
  mais **peint une parcelle inventoriable en « rien à sortir »** — d'où le
  non-défaut.
- `na_policy = "error"` : abort si une seule unité est `NA`.

**Ouvert** : faut-il en plus un repli CHM automatique (appeler
`indicateur_p1_volume(chm = ...)` quand `volume_col` est absent) ou la fonction
doit-elle strictement consommer une colonne P1 déjà calculée ? Trancher à
l'implémentation, en regardant ce dont l'app dispose réellement à ce moment du
pipeline Desserte.

## 7. Ce que cette spec ne fait pas

- **Aucun calcul de volume** : `indicateur_p1_volume()` reste seul propriétaire du
  tarif IFN. Cette fonction convertit (unité) et pondère (prélèvement).
- **Aucun appel à `foretaccess`** depuis `nemeton` : pas de dépendance nouvelle,
  le couplage reste par **contrat de colonne**. La direction des dépendances est
  préservée (app → `nemeton` + `foretaccess`, jamais `nemeton` → `foretaccess`).
- **Aucun seuil de typage** : `seuils_flux` de `typer_desserte()` est du dimen-
  sionnement d'infrastructure, il appartient à `foretaccess` / au gestionnaire.

## 8. Tests (`test-volume-mobilisable.R`)

1. `unite = "m3_total"` : parcelle de 2 ha à P1 = 100 m³/ha, taux 1 → 200 m³.
2. `unite = "m3_ha"` : même parcelle → 100 m³/ha (indépendant de la surface).
3. **Non-régression du piège §3** : sur deux parcelles d'aires différentes et
   même P1, `m3_ha` est identique et `m3_total` est dans le rapport des surfaces.
4. Taux scalaire, taux vectoriel, longueur de vecteur invalide → erreur typée.
5. Mode table non sourcé → `cli_abort` explicite (tant que §5 n'est pas tranché).
6. `na_policy` : `"na"` (avertit + propage), `"zero"`, `"error"`.
7. CRS géographique en entrée → surface calculée correctement ou erreur claire.
8. `volume_col` absent → erreur typée.

## 9. Livraison

- Version cœur : **MINOR** (nouvelle fonction exportée) depuis le cycle dev
  courant `0.162.0.9000` → `v0.163.0`.
- `NAMESPACE` + `man/*.Rd` **à la main** (cf. `project_rd_no_document` : ne pas
  lancer `devtools::document()`).
- Entrée `PLAN.md` + `NEWS.md` + `CITATION.cff` cohérents (garde-fou CI
  `version-consistency`).
- Brief app à écrire ensuite (`brief-nemetonshiny-volume-desserte.md`) : quelle
  unité pour quel appel, et politique NA retenue côté UI.

## 10. Décisions

| # | Décision | Statut |
|---|---|---|
| D1 | Taux paramétrable + table par essence (défaut global, repli feuillu/résineux) | **Tranchée** 2026-07-22 |
| D2 | Couvrir les **deux** consommateurs via `unite` (`m3_total` / `m3_ha`) | **Tranchée** 2026-07-22 |
| D3 | Politique NA par défaut = `"na"` + avertissement | Proposée, à confirmer |
| D4 | Taux de prélèvement **IFN par essence × SER** | **Tranchée** 2026-07-22 (cf. §5.a) |
| D5 | Repli CHM automatique si `volume_col` absent | Ouverte |
| D6 | Granularité réellement tenable de la maille essence × SER (cf. §11 lot 3) | **Ouverte — à trancher sur la donnée** |
| D7 | Millésime IFN retenu + périodicité de mise à jour de la table | Ouverte |

## 11. Plan de développement (5 lots)

Ordre imposé par les dépendances : sans le lot 1, la table du lot 2 est
inutilisable. Le lot 4 — la fonction demandée — est le plus petit.

### Lot 1 — Résolution SER *(le vrai coût de D4)*

1. **Identifier et déclarer la source SER** dans `inst/datasources/FR.json` :
   couche des sylvoécorégions IGN. À vérifier sur la Géoplateforme — WFS
   (comme bdforet/roads) ou téléchargement millésimé, ce qui change le loader.
   Vérifier aussi la licence et le millésime.
2. **`load_ser_source(aoi, crs = 2154, ...)`**, sur le modèle exact de
   `load_foret_ancienne_source()` (`R/load_foret_ancienne.R:51`) : garde `sf`/CRS,
   `NULL` en repli propre, cache. **Normaliser le CRS explicitement** — ne jamais
   supposer 2154 (cf. `project_raster_crs_by_source`).
3. **`ser_pour_unites(units, ser_layer = NULL)`** → jointure spatiale UGF → code
   SER, avec la règle du **recouvrement majoritaire** pour une UGF à cheval sur
   deux SER (et non le centroïde, qui bascule arbitrairement).
4. Le **GRECO** est le préfixe du code SER : le dériver, ne pas le stocker deux
   fois. À confirmer sur la donnée réelle.

### Lot 2 — Table des taux

- `inst/extdata/ifn_taux_prelevement.csv` : `species_code, ser, greco,
  taux_m3_ha_an, n_placettes, ic_bas, ic_haut, millesime, source` — une colonne de
  provenance **par ligne**, comme les deux tables IFN/ONF déjà embarquées.
- Accesseur `ifn_taux_prelevement(species = NULL, ser = NULL, ...)` calqué sur
  `european_species_tolerances()` (`R/european_species_tolerances.R:47`).
- Script de construction dans `data-raw/` depuis les données brutes IFN
  (traçable, rejouable au changement de millésime — D7).

### Lot 3 — Cascade de repli *(point méthodologique, D6)*

86 SER × ~30 essences = beaucoup de cellules à effectif faible, voire vide :
l'IFN est un inventaire par échantillonnage, une case essence × SER peut reposer
sur une poignée de placettes. Publier un taux par case sans regarder l'effectif
donnerait une fausse précision.

- Repli en escalier : **essence × SER → essence × GRECO → essence × national →
  feuillu/résineux national**, en descendant dès que l'effectif passe sous un
  seuil (`n_placettes` minimal, à fixer sur la donnée).
- C'est l'idiome déjà en place dans P1 (espèce → genre → `is_conifer()`,
  `R/indicators-productive.R:184`) : rester cohérent.
- Remonter le **niveau de repli atteint** dans une colonne, comme la colonne
  `confidence` des tolérances européennes. L'app doit pouvoir dire « taux
  national, pas régional ».

### Lot 4 — `volume_mobilisable()` *(le peu de code)*

Conversion d'unité (§3-§4), application du taux × `horizon_ans`, politique NA
(§6). Rien d'autre : aucun calcul de volume, aucun appel `foretaccess`.

### Lot 5 — Doc, tests, release

Tests du §8 + cas SER (UGF à cheval, SER absente, repli en escalier) ;
`inst/REFERENCES.md` — **aucune entrée IFN n'y figure aujourd'hui**, à créer ;
`NAMESPACE` + `man/*.Rd` à la main (`project_rd_no_document`) ; release MINOR.

**Jalon utile** : les lots 1+4 livrés avec taux scalaire/vecteur suffisent déjà à
débloquer l'app (l'utilisateur saisit son taux). Les lots 2-3 apportent le défaut
sourcé. Découpage possible en deux releases si le sourcing IFN traîne.
