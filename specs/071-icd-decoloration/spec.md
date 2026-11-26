# Spec 071 — Indicateur composite de décoloration (ICD)

> Mission 074 de nemetonplateforme. Sources : la note de méthode « Suivi de la décoloration
> anormale du feuillage, forêts publiques et privées de Bourgogne-Franche-Comté », version 2
> du 29 octobre 2026 (copie : `methode_suivi_decoloration_bfc.pdf`, §§ 3 à 8 et 15), et le
> brief `brief-nemeton-icd-decoloration.md` de nemetonplateforme. Pendant côté app :
> `brief-nemetonshiny.md` (copie de référence).
> Décisions de Pascal (2026-11-26) : FAST reste tel quel ; l'ICD s'ajoute aux trois méthodes
> du suivi sanitaire et se compare à FAST ; **seuls les poids sont modifiables**, une somme
> différente de 1 est **renormalisée à 1** ; **pas d'ICD hors des quatre peuplements purs** ;
> l'ICD entre dans « Tout calculer », après RECONFORT.

## Ce que fait le cœur

À l'échelle d'une **zone de suivi** (`monitoring_zone`), comme FAST, FORDEAD et RECONFORT :
indices spectraux, composites mensuels, anomalies z, ICD, classes et niveaux annuels, alertes,
série d'un pixel pour le clic de l'app, comparaison avec FAST. Aucune logique d'interface.

| Fonction exportée | Rôle |
|---|---|
| `run_icd_decoloration()` | la chaîne complète d'une zone ; événements `icd:*`, annulation coopérative |
| `icd_indices()` | GRVI, CIre, CRSWIR, CRre, NDVI depuis les bandes (CRSWIR et CRre : noyaux de `reconfort_indices()`) |
| `icd_poids_defaut()` | poids de la note (essence × indice + mois suivis) |
| `icd_poids_valider()` | contrôle des poids ; renormalise à 1 et le dit |
| `read_icd_raster()` | une couche annuelle (niveau, classe, `icd_min`, mois d'alerte), pour la carte |
| `read_icd_pixel_series()` | série d'un pixel : brut et z des 5 indices, ICD, seuils, classe et niveau |
| `comparer_fast_icd()` | croisement FAST 0-4 × ICD 0-4, accord, kappa, surface alertée égale |

## Données et indices (note §§ 3-4)

- Sentinel-2 L2A, bandes B03, B04, B05, B06, B07, B08, B8A, B11, B12 et la couche SCL, à 20 m.
  Lecture par le cache commun : `ingest_s2_raw_bands_to_cache()` (qui accepte désormais `SCL`
  et un `cancel_path` optionnel, sondé avant chaque scène, événement `s2:cancelled`). Les
  bandes B03, B06, B07 et SCL sont ajoutées à l'union `.S2_STAC_BANDS` ; elles sont
  **tolérantes** (href vide accepté) : `.S2_STAC_REQUIRED_BANDS` (B04, B08, B12) ne change pas,
  donc ce que lit FAST ne change pas. Le test d'un schéma de colonnes (`test-sentinel2-muscate.R`)
  suit la liste élargie : c'est le seul test existant modifié.
- Réflectance : offset de la scène retiré par `.s2_harmonize_band()` (spec 055), puis ÷ 10 000.
  DN 0 = donnée absente.
- Masque SCL : classes 0, 1, 3, 8, 9, 10, 11 (`.ICD_SCL_MASQUE`, distinct de
  `.RECONFORT_SCL_MASK_CLASSES`).
- Indices : GRVI = (B03 − B04)/(B03 + B04) ; CIre = B07/B05 − 1 ; CRSWIR = B11/(B8A + (B12 −
  B8A) × 0,56) ; CRre = B05/(B04 + (B06 − B04) × 0,51) ; NDVI = (B08 − B04)/(B08 + B04).
  Les coefficients exacts de `reconfort_indices()` sont (1610 − 865)/(2190 − 865) = 0,5623 et
  (704 − 665)/(741 − 665) = 0,5132 : ce sont les « ≈ 0,56 » et « ≈ 0,51 » de la note
  (§ 4 : (1613,7 − 864,7)/(2202,4 − 864,7) et (704 − 665)/(741 − 665)). Aucun recopiage.
  Dénominateur nul : NA pour GRVI, CIre, NDVI ; 1 pour CRSWIR, CRre (noyau existant).
- Grille de sortie : Lambert-93, 20 m, emprise de la zone calée sur 20 m. Les bandes à 10 m
  sont agrégées (moyenne), les scènes d'une autre grille sont rééchantillonnées, puis chaque
  indice est reprojeté (bilinéaire) sur la grille commune.

## Composite mensuel (§ 5)

- Avril à octobre, chaque année depuis 2017 (`start_year`) : médiane des valeurs valides des
  images du mois ; un mois sans image valide ne produit pas de fichier (NA). Le plafond de
  70 % de nuages s'applique à la recherche STAC (`max_cloud = 70`), pas aux scènes déjà en
  cache.
- Mois en cours : `mois_en_cours = "garder"` (défaut). Un mois est « en cours » jusqu'à 5 jours
  après sa fin ; son composite existant n'est pas refait. Un composite écrit avant la fin du
  mois est refait **une dernière fois** une fois le mois terminé depuis 5 jours (le fichier
  `AAAA-MM.json` porte `final`). `"refaire"` le recalcule à chaque lancement.
- Écriture atomique (fichier temporaire du même dossier, puis renommage) ; un composite
  illisible est détecté (réouverture, 5 couches, valeurs lisibles), supprimé et refait.
- Les composites sont masqués à l'UGF de la zone ; si la zone change, tous les résultats sont
  refaits (empreinte de la géométrie dans `meta.json`).

## Anomalie standardisée (§ 6)

`z = (x − médiane des autres années) / max(MAD × 1,4826 ; plancher)`, même pixel, même mois,
toutes les autres années (ou `annees_reference` privées de l'année évaluée). Moins de 4
années de référence valides : NA. Planchers : 0,01 (GRVI, CRre, NDVI), 0,05 (CIre), 0,02
(CRSWIR). Un pixel coupé (SUFOSAT, argument `sufosat_dates` en `YYDDD`, `sufosat_proba` ≥ 90 %)
est retiré **du mois de sa coupe inclus** : sa valeur n'est ni évaluée ni utilisée comme
référence. Un pixel de 20 m est coupé si au moins 2 de ses 4 sous-pixels de 10 m le sont, à la
date la plus précoce. Sans couche SUFOSAT, les coupes ne sont pas retirées et le calcul le dit
(`coupes_retirees = FALSE`, message) ; il ne bloque pas.

## ICD (§ 7)

`ICD = w1·z(GRVI) + w2·z(CIre) − w3·z(CRSWIR) − w4·z(CRre) + w5·z(NDVI)`, sur les **mois
sensibles** de l'essence : chêne juin-août, hêtre juillet-août, sapin/épicéa juin-octobre,
douglas avril-septembre. Un indice de poids non nul dont le z manque donne un ICD NA (pas de
somme partielle) ; un indice de poids nul n'est jamais requis.

- **Poids** : argument `poids` (défaut `icd_poids_defaut()`, valeurs de la note, somme 1).
  `icd_poids_valider()` exige les 4 essences (`chene`, `hetre`, `sapin_epicea`, `douglas`), des
  valeurs finies ≥ 0, **CRre nul pour les résineux**, une somme > 0. Une somme ≠ 1 est
  **renormalisée à 1** par essence ; le cœur le dit (message) et rend les poids effectifs avec
  les attributs `somme_saisie` et `renormalise`. Les colonnes de mois éventuelles sont ignorées :
  les mois sont ceux de la note.
- **Essence par pixel** : BD Forêt V2, peuplements purs TFV FF1G01-01 (chêne), FF1-09-09
  (hêtre), FF2G61-61 (sapin/épicéa), FF2-64-64 (douglas), lisière de `buffer_interieur` = 10 m
  retirée. Les autres pixels n'ont **pas** d'ICD : NA, jamais une valeur inventée ; leur nombre
  est rendu (`n_pixels_sans_icd`, attribut de `read_icd_raster()`), avec le motif.

## Classes et niveaux (§ 8)

Constantes internes nommées (seuils, persistance, mois : pas d'arguments exposés) :

- Alerte : ICD < −2 pendant au moins 2 mois **consécutifs** ; date d'alerte = premier mois de
  la première suite. Surveillance : ICD < −1,5 au moins un mois. Normal sinon ; NA si aucun
  mois valide. Les comparaisons sont strictes (−2 exactement n'est pas une alerte).
- Niveaux : 0 normal ; 1 surveillance ; 2 alerte ; 3 alerte forte (alerte et ICD minimal < −3) ;
  4 alerte répétée (alerte cette année et classe « alerte » sur la **saison complète** de
  l'année précédente). Règle reprise de `niveaux_decoloration()` de
  `data-raw/etude_fast_decoloration/`.
- Indice « à date » : un second jeu relit **chaque année** sur les mêmes mois que ceux
  disponibles l'année en cours (un mois en cours n'est pris que s'il est entamé depuis au moins
  20 jours). La classe de l'année précédente, pour le niveau 4, reste celle de sa saison
  complète dans les deux jeux (lecture littérale de la note).

## Sorties (ADR-002 : rasters sur disque, aucune base pour les rasters)

Sous `<result_dir>/zone_<id>/` (défaut de `result_dir` : `<dirname(cache_dir)>/icd`) :
`composites/AAAA-MM.tif` (5 couches), `z/AAAA-MM.tif` (5 couches), `icd/AAAA-MM.tif`,
`annuel/AAAA.tif` et `annuel_a_date/AAAA.tif` (couches `classe`, `niveau`, `icd_min`,
`mois_alerte`, `n_mois_valides`), `essence.tif` (1 à 4), `meta.json` (poids effectifs, sommes
saisies, comptes de pixels, année provisoire). Masque UGF (`apply_zone_mask = TRUE`, parité
ADR-013 A5/A6). Reprise : les composites sont mis en cache ; z, ICD et classes sont refaits à
chaque lancement (calcul matriciel, sans réseau).

- **Série d'un pixel** (`read_icd_pixel_series()`) : lecture locale, sans réseau. Rend l'essence
  (ou NA et le motif), la série longue (année, mois, indice, valeur brute, z), l'ICD par mois
  avec le drapeau « mois sensible », la classe et le niveau de chaque année (dont
  `provisoire`), les poids effectifs de l'essence, les indices actifs (CRre absent pour un
  résineux), les mois sensibles et les seuils.
- **Alertes** : si `con` est une connexion de base, les alertes de la dernière année sont
  écrites dans `alert` avec `alert_type = "icd_decoloration"` (centroïdes d'amas 8-connexes par
  classe `alerte` / `alerte_forte` / `alerte_repetee`, `trigger_date` = 1er jour du mois d'alerte,
  `stress_index` = ICD minimal moyen), par `.insert_health_alerts()` (remplacement des alertes
  `pending`, alertes validées conservées). Sans base : rasters seuls.
- **Progression** (même `progress_callback` que `s2:*`) : `icd:start`, `icd:composite`
  (`completed`, `total`), `icd:anomalies`, `icd:annuel`, `icd:alertes`, puis **un événement
  terminal et un seul** : `icd:complete`, `icd:cancelled` ou `icd:error`. L'annulation
  (`cancel_path`) est coopérative et sondée par scène (ingestion et composites), par mois
  (anomalies) et par année ; le résultat est `status = "cancelled"`, ce qui est déjà écrit
  reste valide (écriture atomique).

## Comparaison avec FAST (§ 15, décision 2)

`comparer_fast_icd(zone_id, annee, result_dir, fast, con, cache_dir)` : classes FAST 0-4
(0 = pas d'alerte, 1 à 4 = quartiles des scores positifs, comme `classes_fast()` de l'étude)
croisées aux niveaux ICD 0-4 en surfaces (pixel de 20 m = 0,04 ha), sur les pixels qui ont les
deux ; accord global (diagonale du tableau 5 × 5) et kappa de Cohen, **indicateurs et non
validation**. Même comparaison **à surface alertée égale** (critère de la mission 045) : alerte
ICD = niveau ≥ 2 ; FAST est dit en alerte sur la même part de pixels, ceux de plus haut score ;
accord, kappa et hectares (les deux, FAST seul, ICD seul, aucune). Le score FAST est le raster
`count` de `read_fast_alert_raster()` (avril à octobre de l'année) ramené de 10 à 20 m par
moyenne ; ou le raster fourni en argument `fast`. Statuts : `ok`, `fast_absent`, `icd_absent`,
`sans_pixel_commun`.

## Tests (sans réseau, `tests/testthat/test-icd.R`)

Formules des 5 indices sur valeurs connues ; composite (médiane, mois vide) ; z (plancher,
année retirée, < 4 années → NA, années de référence fournies) ; pixel coupé retiré dès le mois de
la coupe ; aller-retour `YYDDD` ; ICD aux poids par défaut et modifiés, CRre ignoré pour les
résineux ; règles d'alerte (persistance, date, 5 niveaux, indice à date) ; poids invalides
refusés ; somme ≠ 1 renormalisée et dite ; chaîne complète sur un cache fabriqué (composites,
niveaux, alertes en centroïdes, série d'un pixel, mois en cours gardé, composite illisible refait,
zone modifiée, pixels sans ICD, annulation avec événement terminal) ; comparaison FAST × ICD sur
petites cartes fabriquées.

## Hors périmètre

L'onglet de l'app (`brief-nemetonshiny.md`) ; les §§ 9 à 14 de la note (coupes qualifiées,
volumes, risque de coupe rase, parts sanitaires, coupes partielles, IFN) et les indicateurs
régionaux ; toute modification de FAST ; l'ajout à « Tout calculer » (côté app).

## Non vérifié à la livraison

Aucune mesure sur données Sentinel-2 réelles (réseau STAC et zone d'essai non disponibles dans la
session de développement) : durée, volume, adéquation des noms d'assets SCL/B03/B06/B07 sur les
backends CDSE et MUSCATE (seul Planetary Computer les nomme `B03`, `B06`, `B07`, `SCL`), écriture
des alertes en base PostgreSQL.
