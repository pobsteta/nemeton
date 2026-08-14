# BRIEF — exporter la table des familles d'indicateurs

> **Statut** : ✅ **livré côté cœur le 2026-08-14 — `nemeton 0.170.0`.**
> Option 2 retenue (accesseurs, pas d'export de l'objet brut). API livrée :
> `indicator_families(codes = NULL, lang = c("fr", "en"))` (12 lignes) et
> `indicator_labels(codes = NULL, lang = c("fr", "en"))` (41 lignes, une par
> indicateur — la forme qui permet de retirer les clés `indicateur_*`).
> Point « à trancher » du §4 : **les deux** — `name` suit `lang`, `name_fr` et
> `name_en` sont toujours présents. Deux pièges à connaître avant de câbler,
> décrits au §8 ci-dessous. Reste à faire : le §6, côté app.
> **Statut initial** : ouvert, 2026-08-14.
> **Packages concernés** : `nemeton` (source canonique), `nemetonshiny` (demandeur).
> **Nature** : nouvelle API publique. **Aucun changement de comportement attendu**, seulement
> la fin d'une duplication.
> **Préalable** : lire §3 avant d'aligner quoi que ce soit — la divergence des COULEURS entre
> le cœur et l'app est **délibérée** et ne doit pas être « corrigée ».
> **Contexte de rédaction** : `nemetonshiny@0.122.11.9000`, `nemeton 0.169.0`.

---

## 1. Le constat

`CLAUDE.md` de `nemetonshiny` affirme :

> « Côté app, les noms de famille / indicateurs sont **lus depuis
> `nemeton::INDICATOR_FAMILIES`** — ne pas dupliquer la liste. »

C'est faux aujourd'hui : l'objet **existe** dans le cœur mais **n'est pas exporté**.

```r
"INDICATOR_FAMILIES" %in% getNamespaceExports("nemeton")           # FALSE
exists("INDICATOR_FAMILIES", envir = asNamespace("nemeton"))       # TRUE
```

L'app ne peut donc pas le lire, et redéclare de son côté :

| Ce que l'app redéclare | Où | Volume |
|---|---|---|
| Noms de famille FR + EN | `R/utils_i18n.R`, clés `famille_*` | **24 chaînes** |
| Codes de famille | `R/app_ui.R`, appels `family_tab(clé, code)` | 12 codes |
| Libellés d'indicateurs | `R/utils_i18n.R`, clés `indicateur_*` | 34 chaînes |

Côté cœur, `INDICATOR_FAMILIES` porte déjà tout cela : une liste de 12, nommée par code,
chaque entrée ayant `code`, `name_fr`, `name_en`, `icon`, `color`, `indicators`,
`column_names`, `indicator_labels` (82 libellés au total), `indicator_tooltips`.

## 2. Pourquoi ça compte maintenant

La duplication est aujourd'hui **silencieuse et exacte** — je l'ai mesurée :

```
noms FR divergents : 0/12
noms EN divergents : 0/12
```

C'est précisément ce qui la rend dangereuse : rien ne signale l'écart le jour où il
apparaîtra. Renommer une famille dans le cœur ne changera rien dans l'app, et aucun test,
d'aucun côté, ne le dira. L'app affiche déjà ces noms dans son menu principal
(« Carbone & Vitalité (C) », etc. depuis la v0.122.6).

## 3. Ce qu'il ne faut PAS aligner : les couleurs

Les couleurs divergent sur **12/12** :

| Code | Cœur | App |
|---|---|---|
| C | `#228B22` vert forêt | `#440154FF` |
| W | `#1E90FF` bleu eau | `#433E85FF` |
| E | `#FF8C00` orange | `#C2DF23FF` |

Ce n'est **pas** une dérive : l'app utilise **viridis**, choix documenté dans le roxygen de
`get_family_colors()` (`R/utils_theme.R`) — *« Colors are from the viridis palette for
colorblind accessibility »*. Le cœur, lui, porte des couleurs **sémantiques** (vert pour le
carbone, bleu pour l'eau).

**Conséquence pour ce brief** : l'app consommera `code`, `name_fr`, `name_en`, `indicators`,
`column_names`, `indicator_labels`. Elle **ignorera `color`**, et gardera viridis. Ne pas
« harmoniser » les palettes sans une décision d'accessibilité explicite.

## 4. Ce qui est demandé

Exporter la table. Deux formes possibles ; **la seconde est recommandée**.

1. `export(INDICATOR_FAMILIES)` — direct, mais fige la structure interne en API publique :
   tout changement de forme devient cassant.
2. **Un accesseur** `indicator_families()`, qui renvoie la table et laisse la représentation
   interne libre d'évoluer :

```r
indicator_families(codes = NULL, lang = c("fr", "en"))
# codes : NULL = les 12, dans l'ordre canonique ; sinon un sous-ensemble
# lang  : sélectionne name_fr / name_en dans une colonne `name` unique,
#         ou renvoie les deux si l'appelant préfère (à trancher)
```

Garanties attendues, parce que l'app va s'appuyer dessus :

- **Ordre canonique stable** : `C B W A F L T R S P E N`. C'est déjà l'ordre de la liste
  interne, et **déjà l'ordre du menu de l'app** — le conserver évite de réordonner l'UI.
- **Codes = clés** : `names()` de la sortie, ou colonne `code`.
- `indicators` et `column_names` alignés entre eux (même longueur, même ordre).
- Fonction **pure**, sans I/O, appelable dans un worker `future`.

## 5. Tests attendus côté cœur

1. 12 entrées, codes exactement `C B W A F L T R S P E N`, dans cet ordre.
2. `name_fr` et `name_en` non vides pour les 12.
3. `length(indicators) == length(column_names)` pour chaque famille.
4. Les codes d'indicateurs suivent la convention `<code><n>` (`B1`, `C2`, …).
5. Chaque `column_names` correspond à une colonne réellement produite par le calcul —
   c'est le test qui a le plus de valeur : il relie la table au moteur.

## 6. Ce que l'app fera ensuite

1. Bump `Imports: nemeton (>= X.Y.Z)` (plancher actuel `>= 0.169.0`).
2. `R/app_ui.R` : construire les 12 onglets **par boucle sur la table**, au lieu des 12 appels
   écrits à la main avec leur code en dur.
3. `R/utils_i18n.R` : retirer les **24 clés `famille_*`**, devenues redondantes. Les 34 clés
   `indicateur_*` suivront dans un second temps, à vérifier une à une contre
   `indicator_labels` — elles ne sont pas garanties identiques, je ne les ai pas mesurées.
4. Ajouter un test qui **échoue si l'app redéclare** un nom de famille au lieu de le lire —
   sans quoi la duplication reviendra par la porte de derrière.
5. Corriger `CLAUDE.md` de l'app, qui décrit aujourd'hui un fonctionnement qui n'existe pas.

## 7. Protocole de livraison

`nemeton` : implémenter, exporter, documenter, tester, NEWS, **release**. Me redonner la
version publiée. Tant que ce n'est pas dans une **release**, l'app ne peut pas la consommer :
`Remotes: @*release` ne tire que les tags, jamais `main`.

---

## 8. Ce qui a été livré (2026-08-14, `nemeton 0.170.0`)

### 8.1 L'API

```r
indicator_families(codes = NULL, lang = c("fr", "en"))
# data.frame, 12 lignes, ordre canonique C B W A F L T R S P E N garanti.
# Colonnes : code, name (dans `lang`), name_fr, name_en, icon, color,
#            indicators, column_names, labels, tooltips  (4 colonnes-listes)

indicator_labels(codes = NULL, lang = c("fr", "en"))
# data.frame à plat, 41 lignes (une par indicateur).
# Colonnes : family, code, column_name, label, tooltip
```

- `codes = NULL` → les 12 dans l'ordre canonique. Sinon un sous-ensemble,
  **rendu dans l'ordre demandé** (sémantique de `[`), casse indifférente
  (`"c"` = `"C"`). Un code inconnu est une erreur, pas un `NULL` silencieux.
- `labels` / `tooltips` sont des vecteurs **nommés par code d'indicateur**
  (`labels[["C1"]]`), pas positionnels.
- Les deux fonctions sont **pures** : appelables dans un worker `future`.

Construction du menu, côté app :

```r
fams <- nemeton::indicator_families(lang = input$lang)
lapply(seq_len(nrow(fams)), function(i) family_tab(fams$name[i], fams$code[i]))
```

Lookup colonne → libellé, pour le §6.3 :

```r
ind <- nemeton::indicator_labels(lang = input$lang)
labels <- stats::setNames(ind$label, ind$column_name)
labels[["indicateur_c1_biomasse"]]
```

### 8.2 Deux pièges, documentés plutôt que « corrigés »

**a) `column_names` n'est pas dérivable du code court.** L'appariement est
**positionnel** : `column_names[[i]]` est la colonne de `indicators[[i]]`. Deux
familles portent un croisement historique :

| Code | Colonne réellement produite |
|---|---|
| `F1` | `indicateur_f2_erosion` |
| `F2` | `indicateur_f1_fertilite` |
| `L1` | `indicateur_l2_fragmentation` |
| `L2` | `indicateur_l1_sylvosphere` |

C'est cohérent de bout en bout — les **libellés suivent le code court**, donc
`labels[["F1"]]` décrit bien l'érosion, et `indicator_labels()` apparie
correctement les trois. Mais un `paste0("indicateur_", tolower(code), "_...")`
côté app casserait ces quatre lignes. Un test du cœur verrouille ce croisement.

**b) `color` est exposé mais n'est pas pour vous.** C'est la palette sémantique
du cœur (§3). L'app garde viridis : ignorer la colonne, comme prévu.

### 8.3 Ce qui est verrouillé côté cœur

`tests/testthat/test-indicator-families.R` (353 assertions) : les 5 tests
demandés au §5, plus l'unicité des codes et des colonnes, la complétude des
libellés/tooltips dans les deux langues, la validation des `codes`, et la
cohérence `indicator_labels()` ↔ `indicator_families()`.

Le test §5.5 (le plus utile) est implémenté en deux temps : chaque
`column_name` doit être **une fonction exportée du package** (son producteur)
**et** passer `normalize_indicator()` sans déclencher le garde-fou « pas de
règle 0-100 » de la spec 038. Un indicateur déclaré mais non branché échoue
donc désormais côté cœur.
