# Spec 046 — Créer les UGF depuis le parcellaire forestier public ONF

**Version** : 1.0.0
**Date**    : 2026-08-18
**Statut**  : **Cœur livré** (`load_onf_parcelles_source()`, v0.177.0). Suite
obligatoire côté `nemetonshiny` — voir `brief-nemetonshiny.md`.
**Auteur**  : Pascal Obstétar (via Claude).
**Cible**   : `nemeton` (cœur) + `nemetonshiny` (câblage « Carte UGF »).

---

## 1. La demande

> « Est-ce qu'on peut avoir un serveur qui comprend les parcelles forestières
> domaniale et communale qui permettrait de créer automatiquement les UGF dans
> Carte UGF de Sélection ? »

Aujourd'hui une UGF naît d'une **parcelle cadastrale** (`service_cadastre.R`,
API Etalab), puis `ug_init_default()` fait *1 parcelle = 1 tenement = 1 UG*. Or
en forêt publique la parcelle cadastrale n'est **pas** l'unité de gestion : le
cadre de gestion matérialisé sur le terrain, c'est la **parcelle forestière**.
Partir du cadastre en forêt domaniale ou communale, c'est repartir d'un
découpage étranger au métier.

## 2. Réponse : oui, le serveur existe

**WFS ONF « Forêts publiques »**, servi par Carmen, producteur ONF, diffusion
publique, référencé sur data.gouv.fr.

- Endpoint métropole : `http://ws.carmencarto.fr/WFS/105/ONF_Forets`
- Endpoints ultramarins : `…/ONF_Forets_glp`, `_mtq`, `_guf`, `_reu`, `_myt`

| Couche | Contenu | Attributs |
|---|---|---|
| `ms:PARC_PUBL_<T>` | **Parcelles forestières** publiques — 408 400 en métropole | `iidtn_frt` (id forêt), `llib_frt` (nom), `ccod_prf` (n° parcelle) |
| `ms:FOR_PUBL_<T>` | Périmètres des forêts publiques | + `cdom_frt` (**OUI** = domaniale / **NON** = collectivité ou autre), `cinse_dep` |
| `ms:RB_<T>`, `ms:DT_FR`, `ms:ATE_FR`, `ms:PRS_<T>` | Réserves biologiques, découpage ONF, points de rencontre secours | — |

CRS natifs relevés sur les GetCapabilities (2026-08-18) : FR `2154`,
GLP/MTQ `32620`, GUF `2972`, REU `2975`, MYT `4471`. Schéma d'attributs
**identique** métropole et outre-mer.

Mesures faites en direct le 2026-08-18 :

| Contrôle | Résultat |
|---|---|
| bbox 3 × 3 km (Haute-Saône) | 71 parcelles en **0,17 s**, 4 à 10 ha pièce |
| bbox 4 × 4 km (forêt domaniale de Chaux) | **217 parcelles**, 2 105 ha, 5,8 s bout en bout |
| Domanialité | `Forêt domaniale de Chaux` → `cdom_frt = OUI` ; `Forêt communale de La-Vieille-Loye` → `NON` |
| Lecture R | `sf::st_read()` direct sur l'URL GetFeature, CRS Lambert-93 reconnu |

## 3. Limites, constatées et non supposées

1. **Grain = parcelle, pas sous-parcelle.** La sous-parcelle — la vraie unité de
   gestion de l'aménagement — n'est pas ouverte. Une parcelle peut donc mélanger
   plusieurs peuplements : c'est une approximation NDP 0 de l'UGF, à assumer
   dans l'UI, pas à masquer.
2. **`FILTER` est rejeté** par le pare-feu applicatif devant Carmen (page HTML
   « Request Rejected » renvoyée en **HTTP 200**). Aucune requête attributaire
   côté serveur : pas de recherche par nom de forêt. Seul `BBOX` passe — d'où
   une sélection par emprise, et le filtre domanialité appliqué localement.
3. **GML uniquement** (ni GeoJSON ni JSON). `sf` le lit sans difficulté.
4. **HTTP seul** : `https://ws.carmencarto.fr` ne répond pas. Sans conséquence
   depuis R côté serveur ; bloquant depuis un navigateur en HTTPS (contenu
   mixte) → l'appel doit rester côté serveur.
5. **Licence non déclarée** : data.gouv.fr affiche `License Not Specified`,
   l'ONF annonce une diffusion « libre et gratuite » sans nommer de licence.
   Citer le producteur ; à retrancher si l'ONF précise ses conditions.

Alternatives écartées : `ONF.FORETS_PUBLIQUES` et `BDTOPO_V3:foret_publique`
sur la Géoplateforme ne servent que les **périmètres**, pas le parcellaire ; un
re-hébergement Esri France en FeatureServer (GeoJSON + requêtes attributaires)
existe mais en millésime **2019** → repli seulement.

## 4. Ce que le cœur livre

```r
load_onf_parcelles_source(aoi, crs = 2154,
                          domanialite = c("toutes", "domaniale", "autre"),
                          territoire = "FR",
                          max_parcelles = 5000L, clip = FALSE)
```

`R/load_onf_parcelles.R`, exporté. Retourne un `sf`, **une ligne = une
parcelle = une UGF** :

| Colonne | Contenu |
|---|---|
| `id` | `<id forêt>-<n° parcelle>`, ex. `F06831S-400` |
| `foret_id`, `foret_nom`, `parcelle` | attributs ONF bruts |
| `domaniale` | logique, depuis `cdom_frt` |
| `nom_ugf` | libellé prêt à afficher : « Forêt domaniale de Chaux — parcelle 400 » |
| `contenance` | m², mesurés dans le CRS projeté du territoire |
| `surface_ha` | hectares |

Choix d'implémentation :

- **Sélection par emprise** (`BBOX`), puis restriction aux parcelles qui
  touchent réellement l'AOI. `clip = FALSE` par défaut : une UGF est la parcelle
  **entière**, on ne fabrique pas d'échardes sur le bord de l'emprise.
- **Domanialité jointe** depuis `FOR_PUBL` par identifiant de forêt, avec repli
  sur le libellé (« Forêt domaniale de … ») si cette couche échoue.
- **Fusion des parties** d'une même parcelle (`foret_id` + `parcelle`) : une
  parcelle multipartie éclatée en plusieurs entités redevient une ligne, et les
  surfaces sont mesurées **après** fusion.
- **Garde-fou de volume** : `max_parcelles` borne le `COUNT` et une alerte est
  émise quand le service annonce plus de correspondances que de lignes rendues
  — pas de troncature silencieuse.
- **Dégradation gracieuse** : `NULL` sur tout échec (réseau, pare-feu,
  `ExceptionReport` OWS, schéma inattendu, territoire inconnu), `sf` 0 ligne
  quand l'emprise n'a simplement pas de forêt publique. L'app peut donc toujours
  retomber sur la sélection cadastrale.
- **Détection des faux succès** : la page HTML du pare-feu et les
  `ExceptionReport` arrivent en HTTP 200 ; ils sont détectés à la lecture de
  l'en-tête du GML, pas laissés passer à `sf`.

Sources déclarées dans `inst/datasources/FR.json` : service `onf_wfs`, couches
`onf_parcelles` et `onf_forets_publiques`.

## 5. Tests

`tests/testthat/test-load-onf-parcelles.R` — 50 assertions. Le WFS réel est
mocké via `.onf_wfs_read()` (validation d'entrées, jointure de domanialité et
son repli, filtres, fusion multipartie, troncature, `clip`, 0 ligne, CRS
cible), plus **un test de fumée réseau réel** sur la forêt domaniale de Chaux,
sauté hors ligne.

## 6. Suite côté app

`brief-nemetonshiny.md` : un mode « depuis le parcellaire ONF » dans la Carte
UGF, en **alternative** à la sélection cadastrale. Le schéma rendu par le cœur
(`id`, `contenance`) est déjà compatible avec `standardize_parcels()` /
`ug_init_default()` : *1 parcelle forestière = 1 tenement = 1 UGF* passe par le
chemin existant, sans nouvelle logique métier côté app (règles #1/#3).

---

## 7. Croisement avec les parcelles cadastrales (v0.178.0)

Demande de suite : *« comment ajouter un bouton dans l'app, qui croise ce
retour avec les parcelles cadastrales sélectionnées ? »*. Le croisement n'est
pas de l'affichage, il vit donc dans le cœur.

```r
croiser_parcelles_onf(parcelles, parcelles_onf,
                      min_surface_ha = 0.05,
                      absorber_echardes = TRUE, id_col = NULL)
```

`R/croiser_parcelles_onf.R`, exportée. Rend un `sf` de fragments — une ligne
par (parcelle cadastrale × parcelle forestière), plus un `reste` par parcelle
cadastrale non couverte — avec `parcelle_cadastrale`, `id_onf`, `nom_ugf`,
`foret_id`, `foret_nom`, `parcelle`, `domaniale`, `reste`, `surface_ha`,
`part_cadastrale` et `part_onf`.

### 7.1 Le fait mesuré qui structure la fonction

Les deux découpages **ne coïncident pas**. Sur la forêt communale de
La-Vieille-Loye (39), 56 parcelles cadastrales × 33 parcelles forestières :

| | fragments | dont < 0,05 ha | surface totale |
|---|---|---|---|
| croisement brut | 92 | **51** | 288,9 ha |
| après absorption | 41 attribués + 56 restes | **0** | 288,9 ha |

Les 51 fragments sous le seuil portent ensemble **0,13 %** de la surface. Le
saut est net dans la distribution : 0,035 ha → 0,123 ha, rien entre les deux.
Ce sont des écarts de numérisation, pas des objets de gestion — et vus au
niveau de la parcelle forestière ils étaient **invisibles** (recouvrement
minimum 98,1 %, médiane 100 %). Il a fallu descendre au fragment pour les voir.

### 7.2 Absorption, pas suppression

Une écharde est **absorbée par le plus gros fragment de la même parcelle
cadastrale**, `reste` compris. Supprimer aurait cassé l'invariant de tuilage
que l'app vérifie (`validate_tiling()`, tolérance 0,01 m²) : la surface totale
est conservée au mètre près, seule l'attribution change. Un fragment **seul**
sur sa parcelle est conservé quelle que soit sa taille — il *est* la parcelle,
il n'y a rien où l'absorber.

### 7.3 Ce que le croisement rend lisible

`part_onf` répond à une question qu'aucune des deux couches ne porte seule :
*quelle part de cette parcelle forestière la sélection détient-elle ?* Et les
`reste` disent l'inverse : sur le cas ci-dessus, **48 des 56** parcelles
sélectionnées étaient entièrement hors du parcellaire de la forêt communale,
soit **115 ha sur 288,9**. C'est ce qu'un propriétaire doit voir avant de
lancer un calcul d'indicateurs sur une sélection trop large.

### 7.4 Tests

`tests/testthat/test-croiser-parcelles-onf.R` — 43 assertions, géométries
synthétiques : pavage exact, les deux parts, absorption et seuil, reste seul
sous le seuil conservé, parcelles hors forêt, parcelle forestière à cheval sur
plusieurs cadastres, couche vide, CRS géographique en entrée, `id_col` explicite.
