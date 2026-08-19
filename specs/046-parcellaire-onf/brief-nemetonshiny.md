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

**Cœur requis** : `nemeton (>= 0.178.0)`.

Le §3 crée les UGF **à la place** du cadastre. Ce second bouton fait autre
chose : il garde la sélection cadastrale de l'utilisateur — son bien — et la
**redécoupe** selon les limites de parcelles forestières. Chaque tenement
devient « la part de ma parcelle X qui est dans la parcelle forestière Y »,
et l'UGF devient la parcelle forestière.

## 7. Le maillon fourni par le cœur

```r
nemeton::croiser_parcelles_onf(
  parcelles,                     # sf des parcelles cadastrales sélectionnées
  parcelles_onf,                 # sortie de load_onf_parcelles_source()
  min_surface_ha = 0.05,
  absorber_echardes = TRUE,
  id_col = NULL                  # défaut : id / nemeton_id / geo_parcelle / idu
)
```

Rend un `sf` de **fragments**, une ligne par (parcelle cadastrale × parcelle
forestière), plus une ligne `reste` par parcelle cadastrale non couverte :

| Colonne | Usage |
|---|---|
| `parcelle_cadastrale` | id de la parcelle d'origine → `parcelle_id` de `tenement_split_by_import()` |
| `id_onf`, `nom_ugf`, `foret_nom`, `parcelle`, `domaniale` | l'UGF cible (`NA` sur un `reste`) |
| `reste` | `TRUE` = part de la parcelle hors de toute forêt publique |
| `surface_ha` | surface du fragment |
| `part_cadastrale` | part de la parcelle cadastrale que prend ce fragment |
| `part_onf` | part de la **parcelle forestière** que la sélection détient — la donnée qui permet de dire « vous ne possédez que 40 % de la parcelle 12 » |

**Pourquoi c'est dans le cœur et pas dans l'app** : les deux découpages ne
coïncident pas, et c'est tout le problème. Mesuré sur la forêt communale de
La-Vieille-Loye (39) — 56 parcelles cadastrales × 33 parcelles forestières :

| | fragments | dont < 0,05 ha | surface |
|---|---|---|---|
| croisement brut | 92 | **51** | 288,9 ha |
| après absorption | **41** attribués + 56 restes | 0 | 288,9 ha |

Les 51 échardes ne portent ensemble que **0,13 %** de la surface : ce sont des
écarts de numérisation entre cadastre et parcellaire ONF, pas des objets de
gestion. Elles sont **absorbées par le plus gros fragment de la même parcelle
cadastrale, jamais supprimées** — la surface totale est conservée au mètre
près, donc `validate_tiling()` passe. Ne refaites pas ce calcul côté app.

## 8. Câblage du bouton

Bouton `ug_croise_onf` (« Croiser avec le parcellaire ONF »), actif quand des
parcelles cadastrales sont sélectionnées **et** que le projet a déjà ses UG
(`has_ug_data(projet)`).

```r
shiny::observeEvent(input$ug_croise_onf, {
  sel <- selected_parcels()                      # sf des parcelles cochées
  if (is.null(sel) || nrow(sel) == 0) {
    shiny::showNotification(i18n$t("onf_need_selection"), type = "warning"); return()
  }

  onf <- nemeton::load_onf_parcelles_source(sel)   # emprise = la sélection
  if (is.null(onf)) {
    shiny::showNotification(i18n$t("onf_unavailable"), type = "error"); return()
  }
  if (nrow(onf) == 0) {
    shiny::showNotification(i18n$t("onf_no_public_forest"), type = "warning"); return()
  }

  frags <- nemeton::croiser_parcelles_onf(sel, onf)

  # 1) Découper chaque parcelle cadastrale par ses fragments.
  projet <- app_state$projet
  for (pid in unique(frags$parcelle_cadastrale)) {
    f <- frags[frags$parcelle_cadastrale == pid, ]
    if (nrow(f) < 2) next                        # rien à découper
    projet <- tenement_split_by_import(
      projet, pid, f,
      labels = ifelse(f$reste, i18n$t("onf_hors_foret"), f$nom_ugf))
  }

  # 2) Regrouper : une UG par parcelle forestière, tous cadastres confondus.
  for (idf in unique(stats::na.omit(frags$id_onf))) {
    tids <- tenement_ids_for_label(projet, frags$nom_ugf[match(idf, frags$id_onf)])
    projet <- ug_create(projet, tids, label = frags$nom_ugf[match(idf, frags$id_onf)])
  }

  app_state$projet <- projet
})
```

Le point d'attention est l'étape 2 : `tenement_split_by_import()` fabrique des
identifiants de fragments (`parcelle_id` + suffixe a/b/c…), il faut donc
retrouver les tenements par leur libellé — ou, plus propre, capturer les ids
que la fonction vient de créer plutôt que de les rechercher après coup. Une
même parcelle forestière à cheval sur plusieurs parcelles cadastrales doit
donner **une seule UG** rassemblant tous ses fragments : c'est le seul endroit
où l'ordre des appels compte.

## 9. Ce qu'il faut restituer à l'utilisateur

Le croisement produit trois informations qu'il attend, toutes lisibles dans le
retour du cœur — ne pas les recalculer :

| Message | Calcul |
|---|---|
| « N de vos parcelles sont hors forêt publique » | `sum(frags$reste & frags$part_cadastrale > 0.999)` |
| « X ha de votre sélection hors forêt publique » | `sum(frags$surface_ha[frags$reste])` |
| « vous ne détenez que P % de la parcelle forestière Y » | `tapply(frags$part_onf, frags$id_onf, sum)` |

Sur le cas de La-Vieille-Loye ci-dessus : 48 des 56 parcelles sélectionnées
étaient entièrement hors du parcellaire de la forêt communale, soit 115 ha des
288,9 ha sélectionnés. C'est exactement l'information qu'un propriétaire veut
voir **avant** de lancer un calcul d'indicateurs sur une sélection trop large.

## 10. Ce qu'il ne faut PAS faire

- **Ne pas filtrer les fragments** par la surface côté app : le cœur l'a déjà
  fait, et refiltrer casserait le pavage exact que `validate_tiling()` vérifie.
- **Ne pas jeter les `reste`** : ils font partie du bien de l'utilisateur. Ils
  deviennent des tenements sans UGF forestière, pas des trous.
- **Ne pas appeler le WFS par parcelle** : un seul appel sur l'emprise de toute
  la sélection suffit (`load_onf_parcelles_source(sel)`).
