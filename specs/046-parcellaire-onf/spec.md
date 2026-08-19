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
5. **Le service s'endort** : deux jobs CI tués au timeout sur un transfert
   calé (2026-08-18 et 19). `.onf_wfs_read()` borne le transfert à 30 s, et le
   test de fumée réel est **opt-in** (`NEMETON_TEST_ONF_LIVE=true`).
6. **Licence non déclarée** : data.gouv.fr affiche `License Not Specified`,
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

## 7. Croisement avec les parcelles cadastrales (v0.178.0, réorienté en v0.179.0)

Demande de suite : *« comment ajouter un bouton dans l'app, qui croise ce
retour avec les parcelles cadastrales sélectionnées ? »*, puis correction de
cadrage : **la fonction doit partir des parcelles forestières**, donc des UGF,
et rendre pour chaque UGF le ou les tènements de parcelles cadastrales
rencontrées. C'est l'orientation retenue.

```r
croiser_parcelles_onf(parcelles_onf, parcelles,
                      min_surface_ha = 0.05,
                      caler_sur_cadastre = FALSE, seuil_calage = 0.9,
                      inclure_reste = FALSE, id_col = NULL)
```

`R/croiser_parcelles_onf.R`, exportée. Une ligne = **un tènement** =
(UGF × parcelle cadastrale), un seul par parcelle rencontrée. Colonnes :
`ugf_id`, `nom_ugf`, `foret_id`, `foret_nom`, `parcelle`, `domaniale`,
`tenement_id` (`<ugf_id>~<id cadastral>`), `parcelle_cadastrale`, `hors_ugf`,
`surface_ha`, `part_ugf`, `part_cadastrale`, `n_tenements`.

`part_ugf` se lit contre la parcelle forestière **d'origine** : « quelle part
de cette parcelle la sélection détient-elle ». Avec `caler_sur_cadastre`, elle
peut dépasser 1 — l'UGF a gagné le bord qu'elle ne couvrait pas.

Le « hors UGF » (part de parcelle cadastrale qu'aucune forêt ne couvre) n'est
**pas** rendu par défaut : la vue UGF-first n'en a pas besoin, et
`tenement_split_by_import()` côté app recrée ce reste tout seul.
`inclure_reste = TRUE` le remet.

### 7.1 Le fait mesuré qui structure la fonction

Les deux découpages **ne coïncident pas**, et à l'échelle de l'UGF **ça ne se
voit pas** : sur la forêt communale de La-Vieille-Loye (39), chaque parcelle
forestière est couverte par le cadastre à **98,1 % au pire, 100 % à la
médiane**. Au niveau du fragment, 33 UGF × 56 parcelles cadastrales donnent
92 fragments dont **51 sous 0,05 ha**, portant ensemble **0,13 %** de la
surface. Le saut est net dans la distribution : 0,035 ha → 0,123 ha, rien
entre les deux.

### 7.2 Deux corrections, du plus doux au plus franc

**`min_surface_ha`** — l'écharde est **absorbée** par le plus gros tènement de
la même parcelle cadastrale, jamais supprimée : la parcelle reste pavée
exactement, ce qu'exige `validate_tiling()` côté app.

**`caler_sur_cadastre`** — quand une UGF détient déjà au moins `seuil_calage`
d'une parcelle cadastrale, elle la prend **entière** : le bord de l'UGF vient
se coller au bord cadastral. Deux garde-fous : une parcelle réellement partagée
entre deux UGF reste coupée, et le « hors UGF » ne peut **jamais** prendre une
parcelle — le laisser gagner supprimerait de la forêt, ce qui n'est pas une
correction (défaut trouvé et corrigé à l'essai réel : 0,7 ha de forêt
disparaissaient).

Le seuil 0,9 n'est pas arbitraire. Part dominante détenue par une UGF dans
chaque parcelle cadastrale touchée, sur trois communes :

| commune | parcelles touchées | ≥ 0,99 | [0,9 ; 0,99[ | [0,5 ; 0,9[ | < 0,5 |
|---|---|---|---|---|---|
| La Vieille-Loye (39559) | 181 | 9 | **31** | 6 | 135 |
| Harreberg (57298) | 189 | 19 | **12** | 6 | 152 |
| Nantilly (70376) | 30 | 2 | **4** | 3 | 21 |

La bande `[0,9 ; 0,99[` — les quasi-couvertures à quelques pour cent près — est
précisément ce que le calage répare, et la bande `[0,5 ; 0,9[` est presque
vide : une parcelle est soit quasi entièrement dans une UGF, soit franchement
partagée. Le seuil tombe dans un vrai creux.

### 7.3 Effet mesuré des deux corrections

| commune | brut | dont < 0,05 ha | absorbé | calé |
|---|---|---|---|---|
| La Vieille-Loye | 368 tèn. | 201 | 170 tèn., 13 bords cadastraux | **124 tèn., 41 bords** |
| Harreberg | 280 tèn. | 204 | 77 tèn., 29 bords | 76 tèn., 32 bords |
| Nantilly | 90 tèn. | 31 | 60 tèn., 4 bords | 60 tèn., 7 bords |

« bords cadastraux » = tènements dont la limite est exactement celle d'une
parcelle cadastrale (`part_cadastrale == 1`).

Les deux réglages ne visent pas la même chose : **l'absorption traite les
petites parcelles** (sur un cadastre fin, le reliquat de 5 % pèse moins de
0,05 ha et rejoint tout seul l'UGF dominante), **le calage traite les
grandes** (là, 5 % de reliquat dépasse le seuil et il faut la règle de part).

### 7.4 Tests

`tests/testthat/test-croiser-parcelles-onf.R` — 60 assertions : validation des
entrées, un tènement par parcelle rencontrée (multipartie comprise), les deux
parts, `n_tenements`, reste exclu puis réintégré, absorption et son seuil,
calage et son seuil, parcelle réellement partagée laissée coupée, garde-fou du
« hors UGF », couches vides ou disjointes, CRS géographique en entrée,
`id_col` explicite.
