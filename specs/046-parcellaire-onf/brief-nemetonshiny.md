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
  projet <- ug_init_default(modifyList(projet, list(parcels = parcelles)))
  app_state$projet <- projet
})
```

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

## 6. Vérification

1. Emprise sur la **forêt domaniale de Chaux** (Lambert-93, autour de
   900 000 / 6 667 000) → l'import doit créer ~200 UGF, dont un mélange
   « Forêt domaniale de Chaux » / « Forêt communale de La-Vieille-Loye » ;
   mesuré côté cœur : 217 parcelles, 2 105 ha, 5,8 s.
2. `domanialite = "domaniale"` sur la même emprise → seules les UGF de la
   domaniale subsistent.
3. Emprise en pleine plaine agricole → message « aucune forêt publique »,
   aucune UGF créée, projet inchangé.
4. Service coupé (couper le réseau) → message d'indisponibilité, retour possible
   au cadastre sans redémarrer.

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
| `parcelle_cadastrale` | id de la parcelle d'origine → `parcelle_id` de `tenement_split_by_import()` |
| `n_tenements` | nombre de tènements de cette UGF (répété sur ses lignes) |
| `surface_ha` | surface du tènement |
| `part_ugf` | part de la **parcelle forestière** que la sélection détient — « vous ne possédez que 40 % de la parcelle 12 » |
| `part_cadastrale` | part de la parcelle cadastrale que prend ce tènement ; `== 1` signifie « bord calé sur le cadastre » |
| `hors_ugf` | seulement si `inclure_reste = TRUE` |

**Le reste n'est pas rendu par défaut** : `tenement_split_by_import()` recrée
lui-même le reliquat non couvert pour tenir l'invariant de tuilage. Passez
`inclure_reste = TRUE` seulement si vous voulez l'afficher.

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

  projet <- app_state$projet

  # 1) Découper chaque parcelle cadastrale par les tènements qu'elle porte.
  for (pid in unique(ten$parcelle_cadastrale)) {
    f <- ten[ten$parcelle_cadastrale == pid, ]
    projet <- tenement_split_by_import(projet, pid, f, labels = f$nom_ugf)
  }

  # 2) Une UG par UGF, tous cadastres confondus.
  for (u in unique(ten$ugf_id)) {
    lignes <- ten[ten$ugf_id == u, ]
    tids <- tenement_ids_created(projet, lignes$parcelle_cadastrale, lignes$nom_ugf)
    projet <- ug_create(projet, tids, label = lignes$nom_ugf[1])
  }

  app_state$projet <- projet
})
```

Le point d'attention est l'étape 2. `tenement_split_by_import()` fabrique ses
propres identifiants de fragments (`parcelle_id` + suffixe a/b/c…), donc il
faut **capturer les ids qu'il vient de créer** plutôt que les rechercher après
coup par libellé. Une UGF à cheval sur plusieurs parcelles cadastrales doit
donner **une seule UG** rassemblant tous ses tènements — `n_tenements` dit
combien en attendre, ce qui donne une assertion gratuite.

## 9. Ce qu'il faut restituer à l'utilisateur

Tout est lisible dans le retour, ne rien recalculer :

| Message | Calcul |
|---|---|
| « N UGF créées à partir de M parcelles cadastrales » | `length(unique(ten$ugf_id))`, `length(unique(ten$parcelle_cadastrale))` |
| « vous ne détenez que P % de la parcelle forestière Y » | `tapply(ten$part_ugf, ten$ugf_id, sum)` |
| « ces UGF sont à cheval sur plusieurs de vos parcelles » | `ten$n_tenements > 1` |
| « X ha de votre sélection hors forêt publique » | relancer avec `inclure_reste = TRUE` et sommer `surface_ha[hors_ugf]` |

## 10. Ce qu'il ne faut PAS faire

- **Ne pas filtrer les tènements** par la surface côté app : le cœur l'a déjà
  fait, et refiltrer casserait le pavage exact que `validate_tiling()` vérifie.
- **Ne pas caler par défaut** : c'est une correction volontaire des limites
  ONF, elle doit rester un choix explicite de l'utilisateur.
- **Ne pas appeler le WFS par parcelle** : un seul appel sur l'emprise de toute
  la sélection suffit.
- **Ne pas inverser les arguments** : la fonction part des **parcelles
  forestières** (`parcelles_onf` en premier), pas du cadastre.
