# Brief `nemetonshiny` — créer les UGF depuis le parcellaire ONF (spec 046)

**Cœur requis** : `nemeton (>= 0.177.0)`.
**Objectif** : dans **Carte UGF**, offrir « créer les UGF depuis le parcellaire
forestier ONF » en alternative à la sélection cadastrale. Portée :
présentation / câblage seulement (règles #1 et #3) — toute l'acquisition est
déjà dans le cœur.

---

## 1. Pourquoi

En forêt publique, la parcelle **cadastrale** n'est pas l'unité de gestion. La
parcelle **forestière** l'est : c'est le cadre de référence matérialisé sur le
terrain par l'ONF. Aujourd'hui l'app ne sait partir que du cadastre, donc en
forêt domaniale ou communale elle démarre sur un découpage étranger au métier,
que l'utilisateur doit recomposer à la main.

## 2. Le maillon fourni par le cœur

```r
nemeton::load_onf_parcelles_source(
  aoi,                                   # sf/sfc, CRS défini
  crs = 2154,
  domanialite = "toutes",                # ou "domaniale" / "autre"
  territoire  = "FR",                    # GLP / MTQ / GUF / REU / MYT
  max_parcelles = 5000L,
  clip = FALSE
)
```

Retourne un `sf`, **une ligne = une parcelle forestière** :

| Colonne | Usage côté app |
|---|---|
| `id` | `F06831S-400` — identifiant stable, colonne attendue par `standardize_parcels()` / `ug_init_default()` |
| `nom_ugf` | « Forêt domaniale de Chaux — parcelle 400 » — libellé d'UGF prêt à afficher |
| `foret_id`, `foret_nom`, `parcelle` | attributs ONF (regroupement, tri, info-bulle) |
| `domaniale` | `TRUE` = domaniale, `FALSE` = collectivité/autre |
| `contenance` (m²), `surface_ha` | `ug_init_default()` lit déjà `contenance` |

`NULL` = échec (réseau, pare-feu du service, territoire inconnu) → **retomber
sur le cadastre**. `sf` 0 ligne = emprise sans forêt publique → message, pas
erreur.

## 3. Câblage proposé

### 3.1 Un bouton dans `mod_ug_map_actions_bar()`

À côté des actions existantes, un bouton `ug_from_onf` (« Importer le
parcellaire ONF »), actif quand une emprise existe (projet en cours ou
rectangle dessiné sur la carte).

### 3.2 Observer — l'appel doit rester **côté serveur**

Le WFS ONF n'est joignable **qu'en HTTP** (`https://ws.carmencarto.fr` ne
répond pas) : ne jamais le tirer depuis le navigateur, sinon contenu mixte
bloqué. Passer par le cœur, en asynchrone comme les autres acquisitions.

```r
shiny::observeEvent(input$ug_from_onf, {
  aoi <- current_aoi()                     # emprise projet ou rectangle dessiné
  if (is.null(aoi)) {
    shiny::showNotification(i18n$t("onf_need_aoi"), type = "warning"); return()
  }

  parcelles <- nemeton::load_onf_parcelles_source(
    aoi,
    domanialite = input$onf_domanialite %||% "toutes",
    max_parcelles = 5000L
  )

  if (is.null(parcelles)) {
    shiny::showNotification(i18n$t("onf_unavailable"), type = "error"); return()
  }
  if (nrow(parcelles) == 0) {
    shiny::showNotification(i18n$t("onf_no_public_forest"), type = "warning"); return()
  }

  # 1 parcelle forestière = 1 tenement = 1 UGF, par le chemin existant.
  parcelles$geo_parcelle <- parcelles$nom_ugf   # devient le label d'UG
  projet$parcels <- parcelles                   # affectation directe, cf. ci-dessous
  projet <- ug_init_default(projet)
  app_state$projet <- projet
})
```

> **Ne pas passer par `modifyList()`.** Une première version de ce brief
> écrivait `ug_init_default(modifyList(projet, list(parcels = parcelles)))`.
> `modifyList()` **récurse dans les listes**, et un `data.frame` en est une :
> au lieu de remplacer `parcels`, il le fusionne **colonne par colonne**.
> Erreur immédiate dès que les deux n'ont pas le même nombre de lignes —
> `replacement has 427 rows, data has 1` — donc systématiquement en vrai. Et
> fusion **silencieuse** à tailles égales, ce qui est pire : c'est le cas qui a
> laissé passer les tests unitaires. Constaté côté app, v0.130.0.

**Pourquoi `geo_parcelle`** : `ug_init_default()` (`domain_ug.R`) prend le
libellé d'UG dans `geo_parcelle` s'il existe, sinon dans `id`. Sans ça les UGF
s'appelleraient `F06831S-400` au lieu de « Forêt domaniale de Chaux —
parcelle 400 ».

### 3.3 Sélecteur de domanialité

Un `radioButtons`/`selectInput` `onf_domanialite` : *toutes* (défaut) /
*domaniales* / *communales et autres*. Le filtre est appliqué par le cœur.

### 3.4 Carte

Afficher les parcelles ONF en surcouche avant validation (l'utilisateur voit ce
qu'il va importer), colorées par `domaniale`, info-bulle `nom_ugf` +
`surface_ha`. Sur emprise large la couche peut compter plusieurs centaines de
polygones : garder le rendu léger (pas de label permanent).

## 4. Ce qu'il faut dire à l'utilisateur

Trois messages honnêtes, à ajouter aux `TRANSLATIONS` (FR/EN) :

| Clé | FR | Quand |
|---|---|---|
| `onf_grain_parcelle` | « Grain = parcelle forestière ONF, pas sous-parcelle : une parcelle peut mélanger plusieurs peuplements. » | note permanente sous le bouton |
| `onf_no_public_forest` | « Aucune forêt publique sur cette emprise. » | 0 ligne |
| `onf_unavailable` | « Service ONF indisponible — utiliser la sélection cadastrale. » | `NULL` |

Mentionner le producteur (**ONF, diffusion publique**) dans le panneau des
sources : la licence n'est pas déclarée sur data.gouv.fr, l'ONF annonce une
réutilisation libre et gratuite.

## 5. Ce qu'il ne faut PAS faire

- **Pas de requête attributaire** vers le service : le paramètre `FILTER` est
  rejeté par son pare-feu (page HTML « Request Rejected » renvoyée en HTTP 200).
  Une recherche par nom de forêt se fait en filtrant *localement* le résultat
  d'un appel par emprise.
- **Pas de `clip = TRUE` par défaut** : une UGF est la parcelle entière ;
  découper sur l'emprise fabrique des échardes.
- **Pas de reconstruction du schéma** ni de calcul de surface côté app : le
  cœur rend déjà `id`, `contenance`, `surface_ha`, `nom_ugf`.
- **Pas d'appel depuis le navigateur** (HTTP only, cf. §3.2).

## 6. Vérification — **passée** (app v0.130.0, service réel)

| Cas | Attendu | Mesuré côté app |
|---|---|---|
| Chaux, emprise 4 × 4 km | ~200 UGF, domaniale **et** communale | **213** parcelles, **2 114 ha**, **1,1 s** — 189 domaniale + 24 communale |
| `domanialite = "domaniale"` | seules les domaniales | 394/394 ; `autre` → 33, aucune domaniale |
| plaine agricole | « aucune forêt publique », projet inchangé | `status = empty`, 0,4 s |
| service coupé | indisponibilité, repli cadastral | `status = unavailable`, 0,1 s |

Les chiffres de Chaux diffèrent de ceux mesurés côté cœur (217 / 2 105 ha /
5,8 s) : emprises et versions de service ne sont pas identiques. L'ordre de
grandeur et la composition sont les mêmes.

**Calage cadastral — validé sur cadastre réel.** La-Vieille-Loye, 1 271
parcelles cadastrales × 94 parcelles forestières : les quatre chiffres annoncés
par le cœur sont reproduits **exactement**.

| | Annoncé (cœur) | Mesuré (app) |
|---|---|---|
| Tènements sans calage | 170 | **170** |
| Tènements avec calage | 124 | **124** |
| Bords cadastraux sans calage | 13 | **13** |
| Bords cadastraux avec calage | 41 | **41** |

> **Le calage n'est pas vérifiable sur cadastre synthétique.** Une grille
> régulière est par construction désalignée du parcellaire forestier : l'UGF
> dominante n'y détient jamais plus de **30,1 %** d'une maille, contre 90 %
> exigés — le calage ne se déclenche donc jamais et le test ne prouve rien. Sur
> cadastre réel, la part dominante médiane monte à **0,95** et 41 parcelles sur
> 64 franchissent le seuil. Toute recette du calage doit partir de vrai cadastre.

## 6 bis. Performance — le cœur est devenu le poste dominant

Croisement sur La-Vieille-Loye, avant et après l'optimisation app v0.130.0 :

| | avant | après |
|---|---|---|
| total | 654 s | **31,5 s** |
| dont app | 628,9 s | 6,6 s |
| dont `croiser_parcelles_onf()` | 24,9 s | **24,9 s** |

Levier identifié côté cœur, **non demandé** : ne croiser que les parcelles
cadastrales intersectant réellement le parcellaire forestier — 181 sur 1 271 à
La-Vieille-Loye, soit 14 % — mesuré à 24,9 s → 11,5 s. À ce niveau, le gain ne
justifie probablement pas le changement.

---

# Deuxième bouton — croiser le parcellaire ONF avec les parcelles cadastrales sélectionnées

**Cœur requis** : `nemeton (>= 0.179.0)`.

Le §3 crée les UGF **à la place** du cadastre. Ce bouton-ci fait autre chose :
il garde la sélection cadastrale de l'utilisateur — son bien — et dit, **pour
chaque UGF**, de quels morceaux de parcelles cadastrales elle est faite. Un
tènement = (UGF × parcelle cadastrale), un seul par parcelle rencontrée.

## 7. Le maillon fourni par le cœur

```r
nemeton::croiser_parcelles_onf(
  parcelles_onf,                 # sortie de load_onf_parcelles_source() = les UGF
  parcelles,                     # sf des parcelles cadastrales sélectionnées
  min_surface_ha     = 0.05,
  caler_sur_cadastre = FALSE,
  seuil_calage       = 0.9,
  inclure_reste      = FALSE,
  id_col             = NULL      # défaut : id / nemeton_id / geo_parcelle / idu
)
```

Une ligne = un tènement, trié par UGF puis surface décroissante :

| Colonne | Usage |
|---|---|
| `ugf_id`, `nom_ugf`, `foret_nom`, `parcelle`, `domaniale` | l'UGF à créer |
| `tenement_id` | `<ugf_id>~<id cadastral>` — traçable des deux côtés |
| `parcelle_cadastrale` | id de la parcelle d'origine — `tenement_import_replace()` la retrouve par recouvrement |
| `n_tenements` | nombre de tènements de cette UGF (répété sur ses lignes) |
| `surface_ha` | surface du tènement |
| `part_ugf` | part de la **parcelle forestière** que la sélection détient — « vous ne possédez que 40 % de la parcelle 12 » |
| `part_cadastrale` | part de la parcelle cadastrale que prend ce tènement ; `== 1` signifie « bord calé sur le cadastre » |
| `hors_ugf` | présent seulement avec `inclure_reste = TRUE` |

**`inclure_reste = TRUE` est obligatoire avec `tenement_import_replace()`**, pas
un confort d'affichage. Cette fonction ne recrée **rien** : sans les lignes de
reste, les parts de parcelle hors forêt publique perdent leur tènement et la
parcelle **cesse d'être exactement pavée**, en silence — `projet_validate()` ne
contrôle pas le pavage. Ces lignes arrivant avec `nom_ugf = NA`, il faut leur
donner une UGF, sinon elles violent l'invariant 2 (cf. §8).

Le défaut `FALSE` ne convient que si l'appelant recrée lui-même le reliquat,
ce que faisait l'ancienne boucle `tenement_split_by_import()` — abandonnée.

**Pourquoi c'est dans le cœur et pas dans l'app** : les deux découpages ne
coïncident pas, et **ça ne se voit pas** à l'échelle de l'UGF (couverture
98,1 % au pire, 100 % à la médiane sur la forêt communale de La-Vieille-Loye).
Au niveau du tènement, le croisement brut donne 368 tènements dont **201 sous
0,05 ha**. Après traitement : 170, ou **124 avec calage**. Ne refaites pas ce
calcul côté app.

## 7 bis. Les deux réglages, et lequel sert quand

| réglage | ce qu'il fait | quand il mord |
|---|---|---|
| `min_surface_ha` (0,05 par défaut) | absorbe l'écharde dans le plus gros tènement de la même parcelle | cadastre **fin** : le reliquat de 5 % pèse moins de 500 m² |
| `caler_sur_cadastre` (+ `seuil_calage`) | une UGF qui détient déjà ≥ 90 % d'une parcelle la prend **entière** ; son bord se colle au bord cadastral | cadastre **grossier** : là le reliquat dépasse le seuil |

Mesuré sur trois communes (tènements, puis ceux dont le bord est exactement
cadastral) : La-Vieille-Loye 170 → **124 tèn., 13 → 41 bords** ; Harreberg
77 → 76, 29 → 32 ; Nantilly 60 → 60, 4 → 7.

Deux garde-fous, déjà dans le cœur : une parcelle réellement partagée entre
deux UGF **reste coupée**, et le « hors UGF » ne peut jamais prendre une
parcelle — le laisser gagner supprimerait de la forêt.

**Proposition UI** : une case « caler les UGF sur les limites cadastrales »,
décochée par défaut, avec l'infobulle « les limites forestières ONF sont
approximatives au bord ; cochez pour qu'elles suivent exactement vos parcelles ».

## 8. Câblage du bouton

Bouton `ug_croise_onf` (« Croiser avec le parcellaire ONF »), actif quand des
parcelles cadastrales sont sélectionnées **et** que le projet a ses UG
(`has_ug_data(projet)`).

```r
shiny::observeEvent(input$ug_croise_onf, {
  sel <- selected_parcels()
  if (is.null(sel) || nrow(sel) == 0) {
    shiny::showNotification(i18n$t("onf_need_selection"), type = "warning"); return()
  }

  onf <- nemeton::load_onf_parcelles_source(sel)      # UN seul appel, emprise = sélection
  if (is.null(onf)) {
    shiny::showNotification(i18n$t("onf_unavailable"), type = "error"); return()
  }
  if (nrow(onf) == 0) {
    shiny::showNotification(i18n$t("onf_no_public_forest"), type = "warning"); return()
  }

  ten <- nemeton::croiser_parcelles_onf(
    onf, sel, caler_sur_cadastre = isTRUE(input$onf_caler))
  if (nrow(ten) == 0) {
    shiny::showNotification(i18n$t("onf_no_overlap"), type = "warning"); return()
  }

  # Un seul appel : découpe, affectation UGF, ids et invariants.
  ten$label_ugf <- ifelse(is.na(ten$nom_ugf), "Hors forêt publique", ten$nom_ugf)
  app_state$projet <- tenement_import_replace(app_state$projet, ten)
})
```

`tenement_import_replace()` déduit chaque parcelle parente par recouvrement,
pilote l'affectation UGF par `label_ugf` — en réutilisant une UGF de même
libellé, donc son `groupe` survit —, forge tous les ids en une fois, purge les
UGF vides et valide les invariants.

> **Ne pas boucler sur `tenement_split_by_import()`.** Une première version de
> ce brief proposait une double boucle découpe puis regroupement. Trois défauts,
> tous constatés côté app :
>
> 1. `tenement_ids_created()` **n'existe pas** ;
> 2. `tenement_split_by_import()` forgeait ses ids depuis `Sys.time()` **à la
>    seconde** : deux parcelles découpées dans la même seconde recevaient les
>    **mêmes**. Reproduit — 2 découpes, 4 tènements, **2 identifiants
>    distincts**, et `projet_validate()` vert, car il ne contrôle pas l'unicité.
>    Corrigé côté app en v0.129.0, mais la boucle l'aurait déclenché
>    systématiquement ;
> 3. l'argument `labels =` est un **no-op** : calculé, jamais écrit dans les
>    tènements.

## 9. Ce qu'il faut restituer à l'utilisateur

Tout est lisible dans le retour, ne rien recalculer :

| Message | Calcul |
|---|---|
| « N UGF créées à partir de M parcelles cadastrales » | `length(unique(ten$ugf_id))`, `length(unique(ten$parcelle_cadastrale))` |
| « vous ne détenez que P % de la parcelle forestière Y » | `tapply(ten$part_ugf, ten$ugf_id, sum)` |
| « ces UGF sont à cheval sur plusieurs de vos parcelles » | `ten$n_tenements > 1` |
| « X ha de votre sélection hors forêt publique » | `sum(ten$surface_ha[ten$hors_ugf])` — les lignes sont déjà là, `inclure_reste = TRUE` étant requis (§7) |

## 10. Ce qu'il ne faut PAS faire

- **Ne pas filtrer les tènements** par la surface côté app : le cœur l'a déjà
  fait, et refiltrer casserait le pavage exact que `validate_tiling()` vérifie.
- **Ne pas caler par défaut** : c'est une correction volontaire des limites
  ONF, elle doit rester un choix explicite de l'utilisateur.
- **Ne pas appeler le WFS par parcelle** : un seul appel sur l'emprise de toute
  la sélection suffit.
- **Ne pas inverser les arguments** : la fonction part des **parcelles
  forestières** (`parcelles_onf` en premier), pas du cadastre.
- **Ne pas remplacer `projet$parcels` par `modifyList()`** : il fusionne
  colonne par colonne au lieu de remplacer (§3.2).
- **Ne pas boucler sur `tenement_split_by_import()`** : un seul
  `tenement_import_replace()` (§8).
- **Ne pas laisser `inclure_reste = FALSE`** avec `tenement_import_replace()` :
  la parcelle cesse d'être pavée, en silence (§7).
