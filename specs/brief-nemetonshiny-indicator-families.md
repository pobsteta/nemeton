# BRIEF `nemetonshiny` — consommer la table des familles du cœur

> **Statut** : ouvert, 2026-08-14. Réponse au brief entrant
> `specs/BRIEF-indicator-families-export.md` (§6, « ce que l'app fera ensuite »).
> **Côté cœur** : ✅ livré, `nemeton 0.171.0` — les trois manques du §5 sont
> comblés (deux langues systématiques, `description` de famille,
> `family_column` + `get_famille_col()`/`get_famille_code()` exportées).
> **Côté app** : à faire. Ce brief remplace le §6 du brief entrant, qui
> **sous-estimait la duplication d'un facteur ~15** et la croyait à tort
> silencieuse. Lire le §2 avant de planifier.
> **Contexte de lecture** : `nemetonshiny@0.122.12.9000`, branche
> `claude/ascii-sources`, lecture seule.

---

## 1. Ce qui est disponible dans `nemeton 0.171.0`

```r
nemeton::indicator_families(codes = NULL, lang = c("fr", "en"))
# data.frame, 12 lignes, ordre canonique C B W A F L T R S P E N garanti.
#   code, family_column, name, name_fr, name_en,
#   description, description_fr, description_en, icon, color,
#   + colonnes-listes : indicators, column_names,
#     labels, labels_fr, labels_en, tooltips, tooltips_fr, tooltips_en

nemeton::indicator_labels(codes = NULL, lang = c("fr", "en"))
# la même table à plat, 41 lignes (une par indicateur) :
#   family, family_column, code, column_name,
#   label, label_fr, label_en, tooltip, tooltip_fr, tooltip_en

nemeton::get_famille_col("C")                 # -> "famille_carbone"  (vectorisé)
nemeton::get_famille_code("famille_carbone")  # -> "C"                (NA si inconnu)
```

Fonctions **pures** (aucune I/O, aucun état) : appelables au chargement du
package comme dans un worker `future`. `labels` / `tooltips` sont des vecteurs
**nommés par code d'indicateur** (`labels[["C1"]]`).

**Les deux langues sortent toujours** : `lang` ne pilote que les colonnes de
confort `name` / `description` / `labels` / `tooltips`. Un consommateur
bilingue — comme `mod_family.R`, qui retombe sur `en` — n'a donc pas à appeler
deux fois.

L'ordre canonique est verrouillé par un test côté cœur, et c'est **exactement**
l'ordre actuel du menu de l'app : rien à réordonner.

---

## 2. Ce que le brief entrant n'avait pas vu

Le brief entrant mesurait la duplication dans `utils_i18n.R` et `app_ui.R` et
concluait : *« duplication silencieuse et exacte — 0/12 divergence »*. C'est
vrai pour ces deux fichiers. Mais la vraie copie est ailleurs.

**`R/app_config.R`, lignes 127–558 : un fork complet de `INDICATOR_FAMILIES`**
— pas 24 chaînes, mais ~430 lignes : les 12 familles avec `code`, `name_fr`,
`name_en`, `icon`, `color`, `indicators`, `column_names`, `indicator_labels`
**et** `indicator_tooltips`, suivies d'une copie des 5 accesseurs internes du
cœur (`get_family_codes`, `get_family_config`, `get_all_indicator_codes`,
`get_all_column_names`, `get_column_family_map`).

C'est cet objet — pas les clés i18n — qui alimente le menu, les pages de
famille, le radar, les exports et les prompts LLM. **8 fichiers** le
consomment : `mod_family.R`, `mod_synthesis.R`, `app_ui.R`, `service_export.R`,
`llm_prompts.R`, `utils_theme.R`, `service_r5.R`, `service_regeneration.R`.

**Et il a déjà divergé.** Comparaison ligne à ligne avec `nemeton 0.171.0` :

| Divergence | Mesure |
|---|---|
| Indicateurs déclarés | **40 côté app, 41 côté cœur** |
| Indicateur absent de l'app | **A5 `indicateur_a5_rafraichissement`** (spec 032) |
| Libellés divergents | **14** (B4, W4, A3, A4, L3, R5 en FR+EN ; R6, R7 en EN) |
| Tooltips divergents | **18** |
| Noms de famille, codes, ordre, couleurs | 0 divergence |

La duplication n'est donc plus une bombe à retardement : **elle a déjà
explosé**, en silence, comme le brief entrant le redoutait.

### 2.1 Le symptôme visible : A5 est calculé puis jeté

`service_compute.R:329` ajoute bien `indicateur_a5_rafraichissement` à la liste
des indicateurs calculés. La colonne existe donc dans le projet. Mais
`mod_family.R:70` sélectionne les colonnes à afficher ainsi :

```r
candidates <- c(family_config$indicators, family_config$column_names)
```

`family_config` vient du fork, où la famille A s'arrête à A4. **A5 est calculé,
stocké, puis filtré à l'affichage** : l'onglet Air montre 4 indicateurs au lieu
de 5, sans carte ni ligne de tableau pour le rafraîchissement urbain. Même
effet sur les exports (`service_export.R`) et le récapitulatif par famille.

C'est le meilleur test de recette de ce chantier : **après migration, A5 doit
apparaître dans l'onglet Air sans qu'on ait rien codé pour lui.**

---

## 3. Migration proposée

### Étape 1 — remplacer le fork par un adaptateur (le gros du gain)

Supprimer `R/app_config.R` lignes **127–558** et les reconstruire depuis le
cœur. Les consommateurs attendent la **forme liste** (`INDICATOR_FAMILIES[[code]]$color`,
`fam$indicator_labels[[ic]]$fr`, `for (fam in INDICATOR_FAMILIES)`), et les
libellés leur sont nécessaires **dans les deux langues** (`mod_family.R:870-873`
retombe sur `en` quand la langue courante manque) — d'où les colonnes `_fr` /
`_en`, qui sortent d'un seul appel depuis la v0.171.0 :

```r
# R/app_config.R — remplace les ~430 lignes du fork
.build_indicator_families <- function() {
  fams <- nemeton::indicator_families()
  stats::setNames(lapply(seq_len(nrow(fams)), function(i) {
    codes <- fams$indicators[[i]]
    zip <- function(a, b) stats::setNames(
      lapply(codes, function(k) list(fr = unname(a[[k]]), en = unname(b[[k]]))),
      codes
    )
    list(
      code               = fams$code[i],
      name_fr            = fams$name_fr[i],
      name_en            = fams$name_en[i],
      icon               = fams$icon[i],
      color              = fams$color[i],
      indicators         = codes,
      column_names       = fams$column_names[[i]],
      indicator_labels   = zip(fams$labels_fr[[i]],   fams$labels_en[[i]]),
      indicator_tooltips = zip(fams$tooltips_fr[[i]], fams$tooltips_en[[i]])
    )
  }), fams$code)
}
```

**Ne pas** écrire `INDICATOR_FAMILIES <- .build_indicator_families()` au niveau
top-level : ce serait évalué à l'**installation** et regèlerait une copie du
cœur dans le namespace de l'app — la duplication reviendrait, simplement
invisible. Deux options :

- **(a) minimum de diff** — remplir au chargement, dans `R/zzz.R` (qui ne
  contient aujourd'hui que `.nemeton_env` et n'a pas encore de `.onLoad`) :
  ```r
  INDICATOR_FAMILIES <- NULL  # rempli au chargement, cf. .onLoad (R/zzz.R)

  .onLoad <- function(libname, pkgname) {
    INDICATOR_FAMILIES <<- .build_indicator_families()
  }
  ```
  Zéro site d'appel à toucher (le namespace n'est scellé qu'après `.onLoad`).
- **(b) plus propre** — en faire une fonction `indicator_families_config()`,
  mémoïsée dans `.nemeton_env` comme le sont déjà les profils experts, et
  renommer les ~20 sites d'appel. Mécanique, plus explicite, testable isolément.

Recommandation : **(a) d'abord** (le diff tient dans un fichier, la recette est
immédiate), **(b)** plus tard si le besoin s'en fait sentir.

Les 5 accesseurs copiés (`get_family_config` & co.) restent tels quels : ils
lisent l'objet reconstruit et n'ont plus rien de dupliqué.

> **Vérifié** : sur `nemeton 0.171.0`, chacun des 9 champs reconstruits est
> `identical()` à son homologue de `nemeton:::INDICATOR_FAMILIES`, pour les 12
> familles, tooltips compris. Le remplacement est donc à comportement
> **strictement** constant pour les 8 consommateurs — à ceci près qu'ils
> gagnent A5 et les 14 libellés corrigés. (L'adaptateur ne reprend pas
> `description_fr` / `description_en`, que le fork ne portait pas ; voir
> l'étape 3 si l'on veut aussi rapatrier les sous-titres.)

### Étape 2 — `app_ui.R` : les 12 onglets par boucle

Attention à un détail structurel : `family_tab(key, code)` utilise `key` comme
`value =` du `nav_panel` **et** comme namespace du module. Ce `key` n'est pas
un simple libellé : c'est `famille_carbone`, `famille_sol`, … c'est-à-dire le
**nom de la colonne de score de famille** produite par le cœur
(`FAMILLE_NMT_MAP`). `app_server.R:336-339` fait le chemin inverse
(`famille_carbone` → `"C"`), `service_tour.R:74` cible
`famille_carbone-maps_row`, `service_db.R:484+` mappe `family_C` →
`famille_carbone`. **Ces valeurs doivent rester identiques**, sinon on casse le
routage, le tour guidé et la persistance.

Bonne nouvelle : depuis la v0.171.0 ce nom de colonne est une **API publique**
(`family_column` dans la table, ou `nemeton::get_famille_col()`). La boucle ne
réintroduit donc aucun littéral, et n'a plus besoin du `getFromNamespace()` de
`R/imports.R` :

```r
family_tab <- function(key, code, name) {
  bslib::nav_panel(
    title = sprintf("%s (%s)", name, code),   # nom lu depuis le cœur
    value = key,                              # valeur de nav inchangée
    mod_family_ui(key, code)
  )
}

fams <- nemeton::indicator_families(lang = opts$language)
family_tabs <- Map(family_tab, fams$family_column, fams$code, fams$name)

do.call(bslib::nav_menu, c(
  list(title = i18n$t("tab_families"), icon = bsicons::bs_icon("layers")),
  unname(family_tabs)
))
```

Au passage, `R/imports.R` peut basculer ses deux lignes
`get_famille_col` / `get_famille_code` de `.nemeton_fn()` vers un `nemeton::`
direct, et `FAMILLE_NMT_MAP` disparaître au profit de
`indicator_families()$family_column`.

`fams$code` sort déjà dans l'ordre `C B W A F L T R S P E N` : le menu est
inchangé à l'écran.

### Étape 3 — `utils_i18n.R` : les 24 clés `famille_*`, mais pas de la même façon

Le brief entrant parle de « retirer les 24 clés `famille_*` ». Ces 24 clés sont
en réalité **12 noms + 12 descriptions**, et elles ne se traitent pas pareil.

- Les **12 noms** (`famille_carbone`, `famille_biodiversite`, …) deviennent
  redondants → à supprimer. Un seul autre appelant : `mod_synthesis.R:592`, où
  `i18n$t("famille_carbone")` sert de libellé générique « Famille » dans un
  vecteur `col_names` **qui est du code mort** (écrasé trois lignes plus bas par
  `names(result) <- c(...)`). Supprimer le bloc.
- Les **12 descriptions** (`famille_carbone_desc`, …) sont lues dynamiquement
  par `app_ui.R:759` — `i18n$t(paste0(get_famille_col(family_code), "_desc"))`
  — pour le sous-titre de la page famille. Elles ont désormais un équivalent
  cœur : la colonne `description` (v0.171.0). La ligne devient :
  ```r
  fam_row <- nemeton::indicator_families(family_code, lang = opts$language)
  paste0("— ", fam_row$description)
  ```
  **Attention, le texte change** : les descriptions du cœur sont écrites à jour
  du contenu réel des familles, celles de l'app dataient d'avant A3-A5, R5-R7,
  T3, W4, B4 et L3. La famille R passe par exemple de « Risques feu, tempête,
  sécheresse et abroutissement » (4 indicateurs sur 7) à la liste complète.
  C'est une correction, pas une régression — mais c'est visible, donc à valider
  d'un coup d'œil sur les 12 pages.

### Étape 4 — les 34 clés `indicateur_*` : à ne surtout pas supprimer en l'état

Le brief entrant les disait « redondantes, à vérifier une à une ». Vérification
faite : **elles sont vivantes**, mais pas là où on le croit. Aucune page de
famille ne les utilise (les libellés viennent du fork). Elles alimentent le
**canal de progression** : `utils_i18n.R:5057` traduit une tâche
`"compute:indicateur_c1_biomasse"` en libellé lisible.

Ce sont des formes **volontairement courtes** (« Biomasse carbone » contre
« Biomasse carbone (tC/ha) » côté cœur). Deux options :

- **les garder** telles quelles — l'aval n'y touche pas, aucune dette ;
- **basculer le canal de progression sur `nemeton::indicator_labels()`** et
  supprimer les 34 clés (68 chaînes). Effet de bord **positif** : 7 indicateurs
  calculés n'ont aujourd'hui **aucune** clé de progression — `w4_vpd`,
  `a3_microclimat`, `a4_tamponnement`, `a5_rafraichissement`,
  `t3_coupes_rases`, `r6_sensibilite`, `r7_gel` — et la barre affiche le nom de
  colonne brut. La bascule les corrige d'un coup. Coût : le libellé s'allonge
  (« (tC/ha) », « (FORDEAD) »).

Recommandation : **option 2**, dans un second temps, une fois l'étape 1 en
production. C'est un gain net de cohérence pour un risque cosmétique.

### Étape 5 — `utils_theme.R` : l'ordre canonique, encore

`get_family_colors()` (ligne 276) réécrit les 12 codes à la main :

```r
names(colors) <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
```

→ `names(colors) <- nemeton::indicator_families()$code`. La palette **reste
viridis** : c'est le §3 du brief entrant, et il tient toujours.

Nuance utile : la divergence de couleurs que décrivait le brief entrant oppose
`get_family_colors()` (viridis) à `INDICATOR_FAMILIES$color` (sémantique). Le
fork de l'app porte déjà les couleurs **sémantiques** du cœur, identiques à
100 % — les deux palettes coexistent dans l'app selon l'usage
(`service_export.R:518` lit `$color`, l'UI lit `get_family_colors()`). La
migration ne change donc rien aux couleurs, dans un sens comme dans l'autre.

---

## 4. Tests

### 4.1 Le test anti-redéclaration (§6.4 du brief entrant)

Remplacer les ~10 tests structurels de `tests/testthat/test-app_config.R`
(lignes 111–220 : « 12 familles », « codes corrects », « champs requis »,
« longueurs alignées », « couleurs hex ») — ils testent désormais du code du
cœur, qui les porte déjà — par **un** test d'identité :

```r
test_that("la table des familles vient du cœur, sans redéclaration", {
  ref <- nemeton::indicator_families()
  fams <- nemetonshiny:::INDICATOR_FAMILIES

  expect_identical(names(fams), ref$code)

  for (i in seq_len(nrow(ref))) {
    f <- fams[[ref$code[i]]]
    expect_identical(f$name_fr,      ref$name_fr[i])
    expect_identical(f$name_en,      ref$name_en[i])
    expect_identical(f$color,        ref$color[i])
    expect_identical(f$indicators,   ref$indicators[[i]])
    expect_identical(f$column_names, ref$column_names[[i]])
    expect_identical(
      vapply(f$indicator_labels, `[[`, character(1), "fr"),
      ref$labels[[i]]
    )
  }

  # aucun nom de famille ne doit revenir par la porte i18n
  expect_false(any(unname(FAMILLE_NMT_MAP) %in% names(TRANSLATIONS)))
})
```

Ce test échoue le jour où quelqu'un réécrit un libellé côté app — c'est
exactement ce qui manquait, et ce qui a laissé passer les 14 divergences et A5.

### 4.2 Recette manuelle

1. Ouvrir un projet calculé, onglet **Air** : **5 cartes / 5 lignes**, dont
   « Rafraîchissement urbain ». C'est la preuve que la migration a marché.
2. Menu **Familles** : 12 entrées, même ordre, libellés inchangés, code entre
   parenthèses conservé.
3. Basculer FR ↔ EN : noms de famille et tooltips suivent.
4. Cliquer une famille : le sous-titre `— <description>` est toujours là
   (clés `_desc` préservées).
5. Export PDF/DOCX : familles et libellés d'indicateurs présents, couleurs
   inchangées.
6. Tour guidé : l'étape `famille_carbone` s'ouvre toujours.

---

## 5. Les trois manques du cœur — ✅ livrés en `v0.171.0`

Trois manques avaient été identifiés en écrivant ce brief. Tous les trois sont
comblés ; c'est ce que décrit le §1.

| # | Manque | Livré |
|---|---|---|
| 1 | Les libellés dans les deux langues sans double appel | Colonnes `_fr` / `_en` **toujours** présentes ; `lang` ne pilote plus que les colonnes de confort |
| 2 | Une description par famille | `description`, `description_fr`, `description_en` — 12 phrases à jour du contenu réel des familles |
| 3 | Un accesseur public pour la colonne de score | Colonne `family_column` + `get_famille_col()` / `get_famille_code()` exportées et vectorisées |

Le n°3 était le plus important : `FAMILLE_NMT_MAP` et `get_famille_col()`
étaient **internes**, et `R/imports.R` les tirait par
`utils::getFromNamespace()`. Ça marchait, mais rien ne garantissait leur
stabilité — alors que le nom de colonne de famille est de fait un contrat entre
les deux packages (valeur de nav, clé DB, nom de colonne dans les données).
C'est maintenant une API publique, testée, avec un test qui la relie aux
colonnes réellement produites par `create_family_index()`.

### 5.1 Un quatrième front, non traité ici

En vérifiant les clés i18n, une **troisième** copie des libellés d'indicateurs
est apparue : les **40 clés `indicator_<CODE>`** de `utils_i18n.R`
(`indicator_C1`, `indicator_B4`, …), consommées par
`clean_indicator_label()` (`mod_family.R:838`) pour les tableaux et les cartes
des pages de famille. Elles font doublon avec `indicator_labels()`, exactement
comme le fork de `app_config.R`.

Récapitulatif de ce que l'app redéclare aujourd'hui :

| Copie | Où | Volume | Usage |
|---|---|---|---|
| Fork complet de la table | `app_config.R:127-558` | ~430 lignes | menu, pages famille, radar, exports, LLM |
| Libellés d'affichage | `utils_i18n.R`, `indicator_<CODE>` | 40 clés / 80 chaînes | tableaux et cartes des pages famille |
| Libellés de progression | `utils_i18n.R`, `indicateur_*` | 34 clés / 68 chaînes | barre de progression du calcul |
| Noms de famille | `utils_i18n.R`, `famille_*` | 12 clés / 24 chaînes | menu (via `family_tab`) |

Les étapes 1 à 5 traitent la 1ʳᵉ et la 4ᵉ ligne. Les deux du milieu sont un
second temps : `clean_indicator_label()` et le canal de progression se
branchent tous les deux sur `indicator_labels()`, avec le même arbitrage
cosmétique (libellés du cœur un peu plus longs).

---

## 6. Checklist

- [ ] `DESCRIPTION` : `Imports: nemeton (>= 0.171.0)` (actuellement `>= 0.169.0`).
      `Remotes: pobsteta/nemeton@*release` est déjà bon — le tag `v0.171.0`
      existe.
- [ ] `app_config.R` : supprimer les lignes 127–558, poser
      `.build_indicator_families()` + `.onLoad`.
- [ ] `app_ui.R` : boucle sur `indicator_families()`, `value` de nav inchangée
      (lue dans `family_column`).
- [ ] `utils_i18n.R` : retirer les 12 clés de noms de famille ; supprimer le
      `col_names` mort de `mod_synthesis.R:592`. Les 12 `_desc` peuvent suivre
      (colonne `description`), en validant le changement de texte.
- [ ] `imports.R` : `get_famille_col` / `get_famille_code` en `nemeton::`
      direct, `FAMILLE_NMT_MAP` remplaçable par `family_column`.
- [ ] `utils_theme.R` : ordre canonique lu depuis le cœur.
- [ ] `test-app_config.R` : remplacer les ~10 tests structurels par le test
      d'identité du §4.1.
- [ ] Recette §4.2, **en commençant par A5 dans l'onglet Air**.
- [ ] `CLAUDE.md` de l'app : la phrase « les noms de famille sont lus depuis
      `nemeton::INDICATOR_FAMILIES` » devient vraie — la mettre à jour pour
      pointer `nemeton::indicator_families()` (l'objet reste interne au cœur,
      l'accesseur est l'API).
- [ ] Second temps (§5.1) : brancher `clean_indicator_label()` et le canal de
      progression sur `indicator_labels()`, puis supprimer les 40 clés
      `indicator_<CODE>` et les 34 clés `indicateur_*` (corrige au passage les
      7 indicateurs sans libellé de progression).
