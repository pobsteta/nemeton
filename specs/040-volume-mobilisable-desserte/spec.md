# Spec 040 — `volume_mobilisable()` : couplage P1 → `volume_champ` (desserte)

**Version** : 1.0.0
**Date**    : 2026-07-22
**Statut**  : **Spec close côté cœur, D8 et D9 comprises** (v0.163.0 → v0.165.0). Détail historique ci-dessous.
**Statut initial** : **close** (v0.163.0 puis v0.164.0). Lots 0, 2, 3,
4, 5 livrés ; lot 1 (jointure spatiale UGF → SER) **non nécessaire** — les
placettes IFN portent déjà leur SER. **D4 refermée** (§5.c) : le prélèvement est
dérivé de la revisite IFN, `volume_mobilisable(taux_prelevement = NULL)`
fonctionne.
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
  espar_field     = "espar",        # code essence IFN, requis en mode table
  ser             = NULL,           # code SER des unités ; NULL -> échelon national
  min_plac        = 30,             # profondeur minimale d'un échelon (§5.c)
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

### 5.b — Apport `PPtools` / `DataForet` (2026-07-22) — ce qui est résolu, et ce qui ne l'est pas

Les packages **`DataForet`** et **`PPtools`** de **Max Bruciamacchie**
(AgroParisTech Nancy) embarquent les données brutes IFN et la méthode
d'agrégation. Autorisation explicite de reprise **GPL-2 → GPL-3** obtenue pour
`nemeton`. Vérifié en téléchargeant et en inspectant les tables :

| Table | Contenu réel |
|---|---|
| `IFNarbres.rda` | 1 018 376 arbres — `idp, a, espar, veget, mortb, acci, ori, c13, ir5, htot, hdec, v, w, Annee` |
| `IFNplacettes.rda` | 93 043 placettes — `idp, xl93, yl93, `**`ser`**`, csa, dc, dist, Annee`, millésimes **2005-2019** |

**✅ Résolu — le volume par essence × SER.** La jointure est immédiate : `espar`
et `v`/`w` côté arbres, `ser` **déjà attribué** côté placettes. Deux
conséquences pour le plan :
- le **lot 1 n'est pas nécessaire** pour construire la table (les placettes
  portent leur SER ; la jointure spatiale ne resterait utile que pour situer
  les UGF de l'utilisateur) ;
- **D6 est levée et quantifiée** : `w` *est* le poids de sondage de l'IFN, donc
  la pondération est fournie. Et le déséquilibre est mesuré — sur 4 639
  cellules essence × SER, **1 193** reposent sur ≥ 30 placettes, **2 107** sur
  moins de 5. La cascade du lot 3 concerne près de la moitié de la table.
- Le **GRECO est bien la première lettre du code SER** (`A11`, `B10`, `C20`…),
  ce que le lot 1 donnait « à confirmer ». Confirmé.

**❌ Non résolu dans CE jeu — le prélèvement.** Les `.rda` de `DataForet` ne
portent aucune colonne de coupe : c'est la donnée de première visite. La suite
est en §5.c — la revisite existe bel et bien dans l'export brut de l'IGN.

**Ce que ça ouvre — D8.** Disposer d'un volume de référence régional sourcé par
essence change l'intérêt de la brique : plutôt que de servir de multiplicande à
un taux, il peut **calibrer ou suppléer P1** là où P1 est `NA` — c'est-à-dire
le cas courant en NDP 0. À trancher (cf. §10, D8).

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
| D4 | Taux de prélèvement **IFN par essence × SER** | **Tranchée et livrée** 2026-07-22 (§5.a, §5.c) |
| D5 | Repli CHM automatique si `volume_col` absent | Ouverte |
| D6 | Granularité réellement tenable de la maille essence × SER | **Levée** 2026-07-22 — `w` fournit la pondération ; 1 193 cellules sur 4 639 à n ≥ 30, 2 107 à n < 5 → cascade obligatoire (§5.b) |
| D7 | Millésime IFN retenu + périodicité de mise à jour de la table | Partiellement — table figée sur **2005-2019**, rejouable par `data-raw/build_ifn_volume_ser.R` |
| D8 | Le volume IFN essence × SER sert-il à **calibrer / suppléer P1** (cas NDP 0) ? | **Tranchée et livrée** v0.165.0 — `completer_volume_ifn()`, provenance par ligne (§5.d) |
| D9 | Pont entre codes essence IFN (`09`) et codes 4 lettres de P1 (`FASY`) | **Livrée** v0.165.0 — `resoudre_espar()`, pivot latin + autonyme (§5.d) |

## 11. Plan de développement (5 lots)

Ordre imposé par les dépendances : sans le lot 1, la table du lot 2 est
inutilisable. Le lot 4 — la fonction demandée — est le plus petit.

### Lot 0 — Reconnaissance des sources *(faite le 2026-07-22 — résultat négatif)*

GetCapabilities WFS Géoplateforme (`data.geopf.fr/wfs/ows`, 5,1 Mo, HTTP 200) :

- **Aucune couche SER.** Zéro occurrence de « sylvo » dans tout le document.
- **Aucune donnée de prélèvement.** Zéro occurrence de
  prélèv./récolte/mortalité/production/disparition.
- L'espace de noms **`ObsForets`** (Observatoire des Forêts Françaises,
  « Source : IGN-Inventaire forestier ») ne publie que **8 couches**, toutes en
  maille **département / région / commune**, jamais SER :
  `volume_sur_pied_dep_2017_2021`, `volume_sur_pied_region_2017_2021`,
  `volume_moyen_ha_dep_2018_2022`, `taux_boisement_communal`,
  `taux_boisement_dep_2018_2022`, `repartition_niveaux_trophiques_2018_2022`
  (+ toutes campagnes), `part_forets_publiques_dep_2017_2021`.
  → du **volume sur pied**, jamais du prélèvement.

**Conséquence sur D4** : ni la maille SER ni le taux de prélèvement ne sont
servis par le WFS. Les deux doivent venir d'ailleurs — voir lots 1 et 2 amendés.
Le jalon « lots 1+4 en taux saisi » (fin du §11) devient d'autant plus pertinent.

### Lot 1 — Résolution SER *(le vrai coût de D4)*

1. **Déclarer la source SER** dans `inst/datasources/FR.json`. **Vérifié : pas de
   WFS** (lot 0) → ce sera un **téléchargement millésimé** depuis
   `inventaire-forestier.ign.fr`, donc un loader de type *download-only*, pas
   `ign_wfs`. Précédent exact dans le repo : la BD Forêts anciennes, elle aussi
   download-only (cf. mémoire `project_foret_ancienne_source`). Licence et
   millésime à relever au passage.
2. **`load_ser_source(aoi, crs = 2154, ...)`**, sur le modèle exact de
   `load_foret_ancienne_source()` (`R/load_foret_ancienne.R:51`) : garde `sf`/CRS,
   `NULL` en repli propre, cache. **Normaliser le CRS explicitement** — ne jamais
   supposer 2154 (cf. `project_raster_crs_by_source`).
3. **`ser_pour_unites(units, ser_layer = NULL)`** → jointure spatiale UGF → code
   SER, avec la règle du **recouvrement majoritaire** pour une UGF à cheval sur
   deux SER (et non le centroïde, qui bascule arbitrairement).
4. Le **GRECO** est le préfixe du code SER : le dériver, ne pas le stocker deux
   fois. À confirmer sur la donnée réelle.

### Lot 2 — Table de référence essence × SER — **livré (v0.164.0)**

Livré, mais **pas ce qui était prévu** : c'est une table de **volume sur pied**,
pas de taux de prélèvement (cf. §5.b — la donnée de prélèvement n'existe pas dans
ce jeu).

- `inst/extdata/ifn_volume_essence_ser.csv` — **5 799 lignes** (4 639 SER + 992
  GRECO + 168 national) : `niveau, ser, greco, espar, n_plac_presence,
  n_plac_maille, vol_ha_present, vol_ha_maille, taux_presence, libelle_essence,
  millesime, source`. Provenance par ligne, comme les tables IFN/ONF déjà
  embarquées.
- Accesseur `ifn_volume_essence_ser()` calqué sur
  `european_species_tolerances()` (`R/european_species_tolerances.R:47`).
- `data-raw/build_ifn_volume_ser.R` — reconstruction traçable et rejouable sur
  un millésime plus récent. Les `.rda` sources (7,4 Mo) sont **gitignorés**,
  comme le corpus RAG : seule la table dérivée est versionnée.

**La table des taux de prélèvement reste à faire** et n'a toujours pas de
source (D4).

### Lot 3 — Cascade de repli — **livré (v0.164.0)**

`ifn_volume_reference(espar, ser, min_plac = 30, mesure)` descend l'échelon
**SER → GRECO → national** jusqu'à ce que la cellule repose sur assez de
placettes, et **déclare le niveau atteint** (`niveau_utilise`) — jamais en
silence. Quand aucun échelon ne qualifie, elle rend `NA` plutôt qu'un chiffre.

C'est l'idiome déjà en place dans P1 (espèce → genre → `is_conifer()`,
`R/indicators-productive.R:184`) : dégrader la résolution plutôt que servir une
valeur assise sur trois placettes.

Le besoin est **mesuré, pas supposé** : sur 4 639 cellules essence × SER,
**1 193** reposent sur ≥ 30 placettes et **2 107** sur moins de 5.

Non retenu pour l'instant : l'échelon final « feuillu/résineux national »
envisagé au cadrage. L'échelon national par essence couvre déjà les 168 codes
`espar` de la table ; un repli par type ne servirait que pour une essence
totalement absente de l'IFN, cas où rendre `NA` est plus honnête.

### Lot 4 — `volume_mobilisable()` *(le peu de code)*

Conversion d'unité (§3-§4), application du taux × `horizon_ans`, politique NA
(§6). Rien d'autre : aucun calcul de volume, aucun appel `foretaccess`.

### Lot 5 — Doc, tests, release

Tests du §8 + cas SER (UGF à cheval, SER absente, repli en escalier) ;
`inst/REFERENCES.md` — **aucune entrée IFN n'y figure aujourd'hui**, à créer ;
`NAMESPACE` + `man/*.Rd` à la main (`project_rd_no_document`) ; release MINOR.

**Jalon utile** : les lots 1+4 livrés avec taux scalaire/vecteur suffisent déjà à
débloquer l'app (l'utilisateur saisit son taux). Les lots 2-3 apportent le défaut
sourcé. Découpage possible en deux releases si le sourcing IFN traîne — et après
le lot 0, c'est le scénario le plus probable.

## 12. Trouvaille latérale — `ACCESSFOR` (hors scope de cette spec)

Le GetCapabilities du lot 0 a révélé une couche IGN sans rapport avec le volume,
mais directement utile au **chantier accessibilité/desserte** :

```
IGNF_ACCESSIBILITE-PHYSIQUE-FORETS-:acces_skidder   (+ acces_porteur)
IGNF_ACCESSIBILITE-PHYSIQUE-FORETS-MASQUE-FORETV3:… (variante masque Forêt v3)
```

> « Cartographie de l'accessibilité physique des forêts aux engins d'exploitation,
> produite par l'IGN à partir de la méthodologie développée dans le cadre du
> projet **ACCESSFOR**. […] Édition 2025-01-01 »
> Mots-clés : forêts, **porteur**, **skidder**, accessibilité forestière.

C'est une cartographie nationale officielle, **avec les mêmes noms d'engins que
les moteurs `foretaccess`** (skidder / porteur), servie en WFS et donc
immédiatement consommable. Deux usages possibles, à trancher hors de cette spec :
**référence de validation externe** des moteurs `foretaccess` (comparer classe à
classe sur une AOI connue — Chastel-Nouvel), et/ou **repli** quand le calcul local
est trop coûteux (cf. le blocage perf du brief desserte, 692 s sur 30 parcelles).

Point décisif relevé en échantillonnant la couche (`GetFeature`) plutôt qu'en la
supposant : les libellés ACCESSFOR sont
« Accessible - Classe de débardage 1 : **0 - 250 m** », 2 : 250-500, 3 : 500-1000,
4 : 1000-1500 — **mêmes bornes** que `classes_debardage()` de `foretaccess`
(0-250, 250-500, 500-1000, 1000-1500, 1500-2000, > 2000). La comparaison est donc
quasi terme à terme, ce qui rend la validation utile plutôt qu'anecdotique.

→ **Transmis** : `specs/brief-foretaccess-accessfor.md` (cadrage complet de la
comparaison — correspondance des classes, pièges de masque et de rasterisation,
matrice de confusion attendue). Rien à faire côté `nemeton`.

### 5.c — Prélèvement depuis la revisite IFN (D4 **refermée**, 2026-07-22)

Piste ouverte par Pascal : le package `FrenchNFIfindeR` (Jérémy Borderieux,
GPL-3) télécharge l'export brut de l'IGN, qui contient la **revisite à 5 ans**.
Vérifié sur l'export réel `export_dataifn_2005_2024.zip` (63 Mo, Licence
Ouverte Etalab v2.0) :

- `ARBRE.csv` porte **`VEGET5`**, l'état de l'arbre au second passage.
  Codes utiles : **`6` = coupé vidangé**, `7` = coupé **non** vidangé, `0`
  vivant, `M` mort sur pied, `A`/`1`/`2` chablis, `N` non retrouvé.
- **Seul le code 6 est retenu.** Le bois du code 7 reste en forêt et ne
  circule jamais sur la desserte — c'est la distinction qui compte ici, et elle
  n'existait pas dans le jeu `DataForet`.
- `PLACETTE.csv` porte aussi `PRELEV5` (indicateur de coupe au niveau placette :
  `0` aucune souche, `1` au moins une souche, `2` **coupe rase**) — non utilisé
  ici, mais voisin du sujet T3.

**Le piège, vérifié sur la donnée.** Sur les 69 785 lignes `VEGET5 == "6"`,
`V` et `ESPAR` sont vides à **100 %** (seul `W` est parfois présent) : la ligne
de revisite ne porte que le **sort** de l'arbre. Mesure et essence vivent sur la
ligne de **première visite du même arbre**, clé `(IDP, A)`. Agréger directement
sur les lignes de revisite donne une table **vide** — c'est ce qui est arrivé au
premier essai. Agréger sur `W` seul aurait donné une table **pleine et fausse**,
mode d'échec bien plus dangereux.

**Résultat.** 64 447 arbres coupés exploitables (92 %), table de 2 581 lignes
aux trois échelons. **Contrôle externe** : la somme du prélèvement national sur
toutes les essences donne **2,84 m³/ha/an**, cohérent avec l'ordre de grandeur
publié pour la récolte française ; le classement (épicéa, peuplier, hêtre,
sapin, chêne sessile, pin maritime, douglas) est celui attendu. Un test verrouille
cet ordre de grandeur.

**Deux approximations assumées** : le volume récolté est celui mesuré au premier
passage (l'arbre a crû avant d'être coupé), et la récolte des 5 ans est divisée
par 5 — c'est une moyenne, pas un calendrier.

`volume_mobilisable(taux_prelevement = NULL)` **fonctionne désormais** : il
résout le taux par essence via `ifn_taux_prelevement()`, avec la cascade
SER → GRECO → national, et remonte le niveau atteint dans l'attribut
`niveau_prelevement`. Il exige une colonne de code essence IFN (`espar_field`).

**Reste ouvert — D9** : la correspondance entre les codes essence IFN (`09`,
`62`) et les codes à quatre lettres de `indicateur_p1_volume()` (`FASY`,
`PIAB`). Aujourd'hui l'appelant fournit le code IFN. Le référentiel
`espar-cdref13.csv` porte le nom latin, et `european_species_tolerances()` porte
`species_sci` : le pont est faisable, non fait.

### 5.d — D8 et D9 livrées (v0.165.0, 2026-07-22)

**D9 — pont de nomenclatures.** Trois codes coexistaient sans clé commune :
`espar` IFN (`"09"`), code P1 (`"FASY"`), code tolérances
(`"fagus_sylvatica"`). Pivot retenu : le **nom latin**, porté par le
référentiel `espar-cdref13` de l'IGN — jamais d'heuristique sur les libellés
français. `resoudre_espar()` ramène les quatre formes (les trois codes + le
binôme) au code IFN, `NA` sinon.

*Appariement par autonyme* : l'IGN descend souvent au rang infraspécifique
(*Picea abies* subsp. *abies*). L'autonyme — sous-espèce nominale, dont
l'épithète répète l'épithète spécifique — est taxonomiquement équivalent à
l'espèce, donc apparié. Gain 12 → 20 codes P1 (sur 22 essences réelles) et
107 → 125 codes tolérances. Sans autonyme (*Pinus nigra*, publié en variétés
seules), on laisse `NA` : choisir une variété serait arbitraire.

**D8 — supplétif de volume.** `completer_volume_ifn()` comble les `NA` de P1
par la référence régionale, cascade SER → GRECO → national. Deux garde-fous :
une mesure n'est **jamais** écrasée, et la **provenance est écrite ligne à
ligne** (`"mesure"` / `"ifn_ser"` / `"ifn_greco"` / `"ifn_national"` / `NA`).
Le risque propre à ce genre de complétion est qu'une valeur régionale se fasse
passer pour une mesure ; la seule protection est que le lecteur en aval puisse
trancher. `mesure = "present"` par défaut (figure de peuplement, comparable à
un P1 d'UGF) et non `"maille"`, trop basse d'un ordre de grandeur.

**Deux corrections tombées du croisement.** (1) `ifn_volume_equations.csv`
portait `PIME | Pinus menziesii` — le douglas est *Pseudotsuga menziesii*.
P1 n'était pas affecté (appariement sur le code), mais le nom publié était
faux ; invisible tant que cette table n'était pas confrontée à une source
externe. (2) **Troisième occurrence du piège des zéros non significatifs**, et
la plus dangereuse : le référentiel écrit `"9"`, les tables `"09"` ; le pont
rendait un code plausible n'appariant **aucune** ligne, en silence. Le test
retenu ne vérifie donc pas la valeur rendue mais qu'elle **ouvre réellement**
une ligne des tables de référence.
