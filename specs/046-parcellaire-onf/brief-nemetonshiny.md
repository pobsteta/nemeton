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
