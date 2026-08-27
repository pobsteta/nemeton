# BRIEF — icône « fiche indicateur » à côté du « i », onglet Familles d'indicateurs

> **Statut** : ouvert, 2026-08-27.
> **Packages concernés** : `nemeton` (fournisseur, **livré**), `nemetonshiny` (demandeur).
> **Nature** : ajout d'UI, ~15 lignes. **Aucun changement de comportement métier.**
> **Prérequis côté cœur** : livré dans la même PR que ce brief
> (`nemeton` ≥ 0.192.0). Rien à attendre d'autre.
> **Contexte de rédaction** : `nemeton 0.191.0.9000` → `0.192.0`.

---

## 1. Ce qui est demandé

Dans l'onglet **Familles d'indicateurs**, chaque indicateur porte aujourd'hui une
icône « i » qui ouvre son infobulle. Pour les indicateurs qui disposent d'une
**fiche longue**, ajouter **à côté du « i »** une seconde icône qui ouvre cette
fiche dans un nouvel onglet.

Aujourd'hui **un seul** indicateur a une fiche : **C1 — Biomasse carbone**.
D'autres suivront. L'icône ne doit donc **pas** être câblée sur C1 : elle doit
apparaître pour tout indicateur que le cœur déclare comme documenté.

## 2. Le contrat côté cœur — `doc_url`

`nemeton::indicator_labels()` gagne une **onzième colonne**, `doc_url` :

```r
ind <- nemeton::indicator_labels()
names(ind)
#>  [1] "family" "family_column" "code" "column_name" "label" "label_fr"
#>  [7] "label_en" "tooltip" "tooltip_fr" "tooltip_en" "doc_url"

ind[!is.na(ind$doc_url), c("code", "label", "doc_url")]
#>   code                     label
#> 1   C1 Biomasse carbone (tC/ha)
#>   doc_url
#> 1 https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.html
```

Trois garanties, testées côté cœur
(`tests/testthat/test-indicator-families.R`) :

1. `doc_url` est **toujours un `character`** de longueur `nrow(ind)` — jamais
   `NULL`, jamais une liste. L'app teste `is.na()`, rien d'autre.
2. `NA` = **pas de fiche** pour cet indicateur. C'est la condition d'affichage,
   **pas une erreur** : ne rien logger, ne rien signaler à l'utilisateur.
3. Quand elle n'est pas `NA`, c'est une **URL absolue** (`https://…`), prête à
   poser dans un `href`. L'app n'a **aucune** base d'URL à connaître ni à
   concaténer : le cœur la construit depuis le champ `URL` de son `DESCRIPTION`.

**Ne rien coder en dur côté app** — ni l'URL, ni la liste des indicateurs
documentés. C'est exactement le motif que la PR `nemeton 0.170.0`
(`BRIEF-indicator-families-export.md`) a fermé pour les libellés : une
duplication silencieuse et exacte, qui diverge sans que rien ne le dise. Le jour
où une fiche B2 est publiée, l'icône doit apparaître **sans toucher à l'app**.

## 3. Où brancher

Le rendu de l'infobulle vit dans `R/mod_family.R` (l'appel `family_tab()` /
la construction de la ligne d'un indicateur). Le point de greffe est **là où le
« i » est déjà produit** : l'icône fiche est son voisin immédiat, dans le même
conteneur.

Comme les libellés et les infobulles sont déjà lus dans le cœur depuis la
v0.122.x, la table `indicator_labels()` est **déjà chargée** à cet endroit. Il
s'agit d'y lire une colonne de plus, pas d'ajouter un appel.

## 4. Rendu attendu

```r
# `row` = la ligne de indicator_labels() pour cet indicateur.
doc_icon <- function(row, i18n) {
  if (is.na(row$doc_url)) return(NULL)      # <- la seule condition
  tags$a(
    href   = row$doc_url,
    target = "_blank",
    rel    = "noopener noreferrer",
    class  = "nmt-doc-link",
    title       = i18n$t("indicateur_fiche_ouvrir"),
    `aria-label`= i18n$t("indicateur_fiche_ouvrir"),
    bsicons::bs_icon("journal-text")
  )
}
```

Points de détail :

- **Icône** : `journal-text` (Bootstrap Icons) — « un document à lire ». Éviter
  `box-arrow-up-right`, qui dit « lien externe » et pas « fiche », et
  `question-circle`, trop proche du « i ».
- **Nouvel onglet obligatoire** : la fiche est longue ; la faire s'ouvrir dans
  l'app ferait perdre l'état du calcul en cours. `rel="noopener noreferrer"`
  avec `target="_blank"`, sans exception.
- **Alignement** : même taille et même ligne de base que le « i », séparé d'un
  demi-espace. Pas d'encart, pas de bouton — deux icônes fines côte à côte.
- **Survol** : même traitement que le « i » (couleur d'accent), pour que la
  parenté des deux affordances se voie.

## 5. i18n

Une clé à ajouter dans `TRANSLATIONS` (`R/utils_i18n.R`) — **et une seule**,
le libellé de la fiche venant déjà du cœur via `row$label` :

| Clé | FR | EN |
|---|---|---|
| `indicateur_fiche_ouvrir` | « Ouvrir la fiche détaillée (nouvel onglet) » | "Open the detailed fact sheet (new tab)" |

Aucun texte en littéral, y compris dans `title` et `aria-label` — c'est ce que
lira un lecteur d'écran.

## 6. Test

`testServer()` ne voit pas le rendu de l'UI. Le test utile est un test **d'UI
pure** sur la fonction d'aide, sans serveur :

```r
test_that("l'icone fiche n'apparait que pour les indicateurs documentes", {
  ind <- nemeton::indicator_labels()

  c1 <- ind[ind$code == "C1", ]
  expect_false(is.null(doc_icon(c1, get_i18n("fr"))))
  expect_match(as.character(doc_icon(c1, get_i18n("fr"))), "fiche-c1-biomasse")

  c2 <- ind[ind$code == "C2", ]
  expect_null(doc_icon(c2, get_i18n("fr")))
})
```

Le test **ne doit pas** figer la liste des indicateurs documentés : il vérifie
le mécanisme sur C1 (documenté) et sur C2 (non documenté), pas un décompte.
Sinon il tombera au rouge à la première fiche ajoutée côté cœur — pour une
bonne nouvelle.

## 7. Vérification manuelle

1. Onglet **Familles d'indicateurs** → **Carbone & Vitalité (C)**.
2. Ligne C1 : deux icônes, « i » puis la fiche. Ligne C2 : « i » seul.
3. Clic sur la fiche → nouvel onglet sur
   `https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.html`,
   l'app reste en l'état derrière.
4. Bascule FR/EN : l'infobulle du lien suit la langue.

## 8. Deux pièges

**a) L'URL n'est vivante qu'après le merge sur `main`.** Le site pkgdown est
déployé par `.github/workflows/pkgdown.yaml` **au push sur `main`**. Tant que la
PR côté cœur n'est pas mergée, `doc_url` est déjà correcte mais pointe vers une
page qui n'existe pas encore (404). Merger côté cœur **avant** de livrer l'app —
ou accepter un 404 transitoire en recette.

**b) `doc_url` est absente des versions de `nemeton` < 0.192.0.** Si l'app peut
tourner contre un cœur plus ancien, `row$doc_url` y vaut `NULL` et
`is.na(NULL)` rend `logical(0)`, ce qu'un `if` refuse (« argument is of length
zero »). Le garde est d'une ligne :

```r
if (!isTRUE(is.na(row$doc_url) == FALSE)) return(NULL)
```

ou, plus lisible :

```r
url <- row$doc_url %||% NA_character_
if (length(url) != 1L || is.na(url)) return(NULL)
```

Si le `DESCRIPTION` de l'app impose déjà `nemeton (>= 0.192.0)`, ce garde est
inutile — le choix vous revient.

## 9. Ce que ce brief ne demande pas

- Aucun changement des infobulles existantes ni du « i ».
- Aucune fiche à écrire côté app : les fiches sont des **vignettes du cœur**
  (`vignettes/fiche-*.Rmd`), publiées par pkgdown.
- Aucune mise en cache : `indicator_labels()` est une table statique de
  41 lignes, déjà lue à cet endroit.

---

## Côté cœur — ce qui est déjà livré (rien à faire)

| Élément | Emplacement |
|---|---|
| Fiche C1 (article pkgdown) | `vignettes/fiche-c1-biomasse_fr.Rmd` |
| Entrée du menu Articles | `_pkgdown.yml` |
| Déclaration de la fiche | `INDICATOR_FAMILIES$C$indicator_docs$C1` |
| Colonne `doc_url` | `indicator_labels()`, `R/indicator-config.R` |
| Base d'URL (source unique) | champ `URL` de `DESCRIPTION`, via `.doc_base_url()` |
| Tests | `tests/testthat/test-indicator-families.R` |

**Pour ajouter une fiche à un autre indicateur** (côté cœur, sans toucher à
l'app) : écrire `vignettes/fiche-<code>-*.Rmd`, l'ajouter au menu de
`_pkgdown.yml`, et déclarer une entrée `indicator_docs` dans sa famille. L'icône
apparaît toute seule.
