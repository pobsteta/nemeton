# BRIEF — icône « fiche indicateur » à côté du « i », onglet Familles d'indicateurs

> **Statut** : ouvert, 2026-08-27.
> **Packages concernés** : `nemeton` (fournisseur, **livré**), `nemetonshiny` (demandeur).
> **Nature** : ajout d'UI, ~20 lignes. **Aucun changement de comportement métier.**
> **Prérequis côté cœur** : livré, `nemeton` ≥ **0.192.0**. Rien à attendre d'autre.
> **Contexte de rédaction** : `nemeton 0.191.0.9000` → `0.192.0`.

---

## 1. Ce qui est demandé

Dans l'onglet **Familles d'indicateurs**, chaque indicateur porte une icône « i »
qui ouvre son infobulle. Pour les indicateurs qui disposent d'une **fiche
longue**, ajouter **à côté du « i »** une seconde icône qui ouvre cette fiche
dans un nouvel onglet.

Aujourd'hui **un seul** indicateur a une fiche : **C1 — Biomasse carbone**.
D'autres suivront. L'icône ne doit donc **pas** être câblée sur C1 : elle
apparaît pour tout indicateur que le cœur déclare comme documenté.

## 2. Pourquoi les fiches vivent côté cœur, et pas ici

Question posée le 2026-08-27, tranchée : **les fiches restent dans `nemeton`.**
Ce n'est pas un choix de commodité, c'est la règle 1 du `CLAUDE.md` appliquée à
la documentation.

Une fiche décrit **comment un indicateur est calculé** : elle cite
`R/indicators-families.R:352`, le `ref_max` de `R/normalization.R:588`, les
exposants de `inst/extdata/ifn_volume_equations.csv`, le repli
`density × 500`. C'est de la documentation de **logique métier**, pas de
présentation. Elle doit changer dans le **même commit** que le code qu'elle
décrit, et sortir dans la **même release**.

Trois conséquences concrètes :

1. **Anti-dérive.** `docs/TABLEAU_INDICATEURS_NDP.md` est resté à la v0.14.1 et
   décrit C1 avec trois chemins ; il en a cinq depuis la spec 005. C'est
   exactement ce qui arrive à une documentation qui ne partage pas le cycle de
   vie de son code. Mettre la fiche dans un autre dépôt, avec sa propre cadence
   de release, garantit la même dérive — en pire, puisqu'un correctif du cœur
   (0.169.0, exposants du tarif IFN) ne toucherait plus le texte qui l'énonce.
2. **ADR-009.** Les dépendances vont vers `nemeton`, jamais l'inverse. Une fiche
   côté app serait invisible depuis le site pkgdown du cœur, et surtout depuis
   `vignette("fiche-c1-biomasse_fr", package = "nemeton")` — un chercheur qui
   appelle `indicateur_c1_biomasse()` depuis un script R n'a pas l'app.
3. **Précédent v0.170.0.** `BRIEF-indicator-families-export.md` a fermé la
   duplication des libellés pour cette raison exacte : « rien ne signale l'écart
   le jour où il apparaîtra ». Une fiche dupliquée ou déplacée rouvrirait la
   même faille.

**L'objection sérieuse, et sa réponse.** Le lecteur d'une fiche est un
utilisateur de l'app, et l'i18n vit ici, pas dans le cœur. Vrai — c'est pourquoi
le cœur déclare désormais les fiches **par langue** et dit laquelle il sert
(§3). Ajouter une fiche anglaise reste une opération purement cœur ; l'app n'a
qu'à lire `doc_lang`.

## 3. Le contrat côté cœur

`nemeton::indicator_labels()` gagne **quatre colonnes** :

| Colonne | Contenu |
|---|---|
| `doc_url` | URL **absolue** de la fiche dans la langue demandée, `NA` si l'indicateur n'en a pas |
| `doc_lang` | Langue **réellement servie** (`"fr"` / `"en"`), `NA` si pas de fiche |
| `doc_url_fr`, `doc_url_en` | Les deux langues, toujours présentes — comme `label_fr` / `label_en` |

```r
ind <- nemeton::indicator_labels(lang = "fr")
ind[!is.na(ind$doc_url), c("code", "doc_url", "doc_lang")]
#>   code                                                              doc_url doc_lang
#> 1   C1 https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.html       fr
```

Quatre garanties, testées côté cœur
(`tests/testthat/test-indicator-families.R`) :

1. `doc_url` et `doc_lang` sont **toujours des `character`** de longueur
   `nrow(ind)` — jamais `NULL`, jamais une liste. L'app teste `is.na()`, rien
   d'autre.
2. `NA` = **pas de fiche**. C'est la condition d'affichage, **pas une erreur** :
   ne rien logger, ne rien signaler à l'utilisateur.
3. Quand elle n'est pas `NA`, c'est une **URL absolue** (`https://…`), prête à
   poser dans un `href`. Aucune base d'URL à connaître ni à concaténer : le cœur
   la construit depuis le champ `URL` de son `DESCRIPTION`.
4. **`doc_lang` peut différer de la langue demandée.** Quand la fiche n'existe
   pas dans la langue courante mais existe dans l'autre, le cœur rend l'autre
   plutôt que `NA` — une fiche dans la mauvaise langue vaut mieux que pas de
   fiche. **C'est le cas de C1 aujourd'hui** : en anglais, `doc_url` pointe la
   page française et `doc_lang` vaut `"fr"`.

**Ne rien coder en dur côté app** — ni l'URL, ni la liste des indicateurs
documentés, ni la langue des fiches. Le jour où `fiche-c1-biomasse_en.Rmd`
existe, `doc_lang` passera à `"en"` tout seul et la mention « en français »
disparaîtra sans qu'on touche à l'app.

## 4. Où brancher

Le rendu de l'infobulle vit dans `R/mod_family.R`, là où le « i » est produit :
l'icône fiche est son voisin immédiat, dans le même conteneur. Les libellés et
infobulles étant déjà lus dans le cœur depuis la v0.122.x, la table
`indicator_labels()` est **déjà chargée** à cet endroit — il s'agit d'y lire
quatre colonnes de plus, pas d'ajouter un appel.

## 5. Rendu attendu

```r
# `row` = la ligne de indicator_labels() pour cet indicateur.
# `lang` = la langue courante de l'interface.
doc_icon <- function(row, lang, i18n) {
  url <- row$doc_url %||% NA_character_
  if (length(url) != 1L || is.na(url)) return(NULL)   # <- la seule condition

  # La fiche n'existe pas dans la langue courante : on l'ouvre quand meme,
  # mais on le dit. Cf. §3 garantie 4.
  label <- if (!identical(row$doc_lang, lang)) {
    paste0(i18n$t("indicateur_fiche_ouvrir"), " ",
           i18n$t(paste0("langue_", row$doc_lang)))
  } else {
    i18n$t("indicateur_fiche_ouvrir")
  }

  tags$a(
    href   = url,
    target = "_blank",
    rel    = "noopener noreferrer",
    class  = "nmt-doc-link",
    title        = label,
    `aria-label` = label,
    bsicons::bs_icon("journal-text")
  )
}
```

Points de détail :

- **Icône** : `journal-text` (Bootstrap Icons) — « un document à lire ». Éviter
  `box-arrow-up-right`, qui dit « lien externe » et pas « fiche », et
  `question-circle`, trop proche du « i ».
- **Nouvel onglet obligatoire** : la fiche est longue ; l'ouvrir dans l'app
  ferait perdre l'état du calcul en cours. `rel="noopener noreferrer"` avec
  `target="_blank"`, sans exception.
- **Alignement** : même taille et même ligne de base que le « i », séparé d'un
  demi-espace. Pas d'encart, pas de bouton — deux icônes fines côte à côte.
- **Survol** : même traitement que le « i » (couleur d'accent), pour que la
  parenté des deux affordances se voie.

## 6. i18n

Trois clés à ajouter dans `TRANSLATIONS` (`R/utils_i18n.R`) — le libellé de
l'indicateur venant déjà du cœur via `row$label` :

| Clé | FR | EN |
|---|---|---|
| `indicateur_fiche_ouvrir` | « Ouvrir la fiche détaillée (nouvel onglet) » | "Open the detailed fact sheet (new tab)" |
| `langue_fr` | « (en français) » | "(in French)" |
| `langue_en` | « (en anglais) » | "(in English)" |

Aucun texte en littéral, y compris dans `title` et `aria-label` — c'est ce que
lira un lecteur d'écran.

## 7. Test

`testServer()` ne voit pas le rendu de l'UI. Le test utile porte sur la fonction
d'aide, sans serveur :

```r
test_that("l'icone fiche n'apparait que pour les indicateurs documentes", {
  ind <- nemeton::indicator_labels(lang = "fr")

  c1 <- ind[ind$code == "C1", ]
  icon <- doc_icon(c1, "fr", get_i18n("fr"))
  expect_false(is.null(icon))
  expect_match(as.character(icon), "fiche-c1-biomasse")

  c2 <- ind[ind$code == "C2", ]
  expect_null(doc_icon(c2, "fr", get_i18n("fr")))
})

test_that("une fiche servie dans une autre langue est signalee", {
  en <- nemeton::indicator_labels(lang = "en")
  c1 <- en[en$code == "C1", ]
  expect_equal(c1$doc_lang, "fr")          # etat actuel du coeur
  expect_match(as.character(doc_icon(c1, "en", get_i18n("en"))), "in French")
})
```

Le test **ne doit pas** figer la liste des indicateurs documentés : il vérifie
le mécanisme sur C1 (documenté) et sur C2 (non documenté), pas un décompte.
Sinon il tombera au rouge à la première fiche ajoutée côté cœur — pour une
bonne nouvelle.

## 8. Vérification manuelle

1. Onglet **Familles d'indicateurs** → **Carbone & Vitalité (C)**.
2. Ligne C1 : deux icônes, « i » puis la fiche. Ligne C2 : « i » seul.
3. Clic sur la fiche → nouvel onglet sur
   `https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.html`,
   l'app reste en l'état derrière.
4. Bascule en anglais : l'icône reste, et son infobulle dit *« Open the detailed
   fact sheet (new tab) (in French) »*.

## 9. Deux pièges

**a) L'URL n'est vivante qu'après le merge sur `main`.** Le site pkgdown est
déployé par `.github/workflows/pkgdown.yaml` **au push sur `main`**. Tant que la
PR côté cœur n'est pas mergée, `doc_url` est déjà correcte mais pointe une page
qui n'existe pas encore (404). Merger côté cœur **avant** de livrer l'app — ou
accepter un 404 transitoire en recette.

**b) Les colonnes sont absentes des `nemeton` < 0.192.0.** `row$doc_url` y vaut
`NULL`, et `is.na(NULL)` rend `logical(0)`, ce qu'un `if` refuse (« argument is
of length zero »). D'où le `%||%` et le test de longueur au §5. Si le
`DESCRIPTION` de l'app épingle déjà `nemeton (>= 0.192.0)`, ce garde est
superflu — le choix vous revient.

## 10. Ce que ce brief ne demande pas

- Aucun changement des infobulles existantes ni du « i ».
- Aucune fiche à écrire côté app : les fiches sont des **vignettes du cœur**
  (`vignettes/fiche-*.Rmd`), publiées par pkgdown. Cf. §2.
- Aucune mise en cache : `indicator_labels()` est une table statique de
  41 lignes, déjà lue à cet endroit.

---

## Côté cœur — ce qui est déjà livré (rien à faire)

| Élément | Emplacement |
|---|---|
| Fiche C1 (article pkgdown) | `vignettes/fiche-c1-biomasse_fr.Rmd` |
| Entrée du menu Articles | `_pkgdown.yml` |
| Déclaration de la fiche, par langue | `INDICATOR_FAMILIES$C$indicator_docs$C1` |
| Colonnes `doc_url` / `doc_lang` / `doc_url_fr` / `doc_url_en` | `indicator_labels()`, `R/indicator-config.R` |
| Base d'URL (source unique) | champ `URL` de `DESCRIPTION`, via `.doc_base_url()` |
| Tests | `tests/testthat/test-indicator-families.R` |

**Pour ajouter une fiche à un autre indicateur** (côté cœur, sans toucher à
l'app) : écrire `vignettes/fiche-<code>-*.Rmd`, l'ajouter au menu de
`_pkgdown.yml`, et déclarer `indicator_docs = list(<CODE> = list(fr = "..."))`
dans sa famille. L'icône apparaît toute seule.

**Pour traduire la fiche C1** : écrire `vignettes/fiche-c1-biomasse_en.Rmd` et
ajouter `en = "articles/fiche-c1-biomasse_en.html"` à l'entrée existante.
`doc_lang` passera à `"en"` et la mention « en français » disparaîtra côté app,
sans un octet modifié ici.
