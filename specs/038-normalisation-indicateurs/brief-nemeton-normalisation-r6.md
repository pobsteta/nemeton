# Brief cœur `nemeton` — Normaliser tous les indicateurs à 0-100 (focus R6)

**Date** : 2026-07-16
**Repo cible** : `nemeton` (cœur métier — normalisation = logique métier, ADR-011).
**Origine** : côté app `nemetonshiny`, la famille R affiche/décompte R1-R7, mais
seuls R1-R5 entrent dans le **score de famille** (`create_family_index`). R6 et R7
(reGénération) manquent au score. Objectif utilisateur : **« intégrer tous les
indicateurs au score, donc normaliser tous les indicateurs dès qu'ils sont
calculés »**.

## 1. Constat technique (état actuel du cœur)

`create_family_index()` sélectionne, par famille, les colonnes d'indicateurs
(préférant `<col>_norm` si présent) puis appelle **`normalize_indicator(col_name,
values)`** sur chacune avant d'agréger. `normalize_indicator` est un `switch` par
nom d'indicateur, avec un **repli naïf** pour tout nom inconnu :

```r
# fin de normalize_indicator() :
if (!is.null(ref_max)) values <- pmin(100, pmax(0, values / ref_max * 100))
else                   values <- pmin(100, pmax(0, values))   # <-- clamp brut
```

Conséquence par indicateur reGénération :

| Ind. | Colonne injectée par l'app | Valeur produite par le cœur | Passage dans `normalize_indicator` | Verdict |
|------|----------------------------|------------------------------|-------------------------------------|---------|
| **R7** | `indicateur_r7_gel` | `indicateur_r7_gel()` → `R7 = 100*(1 - min(gel_days,max)/max)` → **déjà 0-100** | repli clamp(0,100) | **correct** (mais implicite) |
| **R6** | `indicateur_r6_sensibilite` | reGénération `regen_sensibilite()` → `sensibilite = z(d_tmax) + z(d_vpd)` → **z-score projet-relatif, non borné (~[-4,4])** | repli clamp(0,100) | **FAUX** : négatifs → 0, positifs → 0-4 ≈ quasi-nul |

> Point de vigilance : `indicateur_r6_sensibilite()` **existe** au cœur et renvoie
> déjà un `R6` **0-100** (`100 * (1 - (0.5*sT + 0.5*sV))`, `sT=dtmax/scale_t`,
> `sV=dvpd/scale_v`, bounds `.MICRO_BOUNDS$r6`). MAIS la **reGénération** ne stocke
> pas ce `R6` : elle stocke le **z-score** `sensibilite`, que l'app injecte tel
> quel dans `indicateur_r6_sensibilite`. C'est la source de l'incohérence.

## 2. Demande

Garantir que **chaque indicateur produit possède une normalisation 0-100 définie**
(pas de repli naïf silencieux), pour qu'ils entrent proprement dans le score.
Concrètement, dans l'ordre de priorité :

### 2.a — R6 : exposer une sensibilité **0-100** depuis reGénération (recommandé)

La façon la plus cohérente (« normaliser à la source, dès le calcul ») : que
`regen_sensibilite()` calcule et **persiste une colonne 0-100** réutilisant la
formule bornée déjà en place dans `indicateur_r6_sensibilite()` (sur les mêmes
`d_tmax`/`d_vpd` que la reGénération produit), en plus du z-score `sensibilite`
conservé pour le **rang** (`rang_sensibilite`, `parcelle_sensible`, `priorite`).

- Nom proposé pour la colonne 0-100 : `sensibilite_score` (ou directement `R6`),
  avec la sémantique **famille** : *haut = favorable* (peu sensible), soit
  `R6_0_100 = 100 * (1 - clamp01(0.5*sT + 0.5*sV))`.
- L'app injectera cette colonne 0-100 dans `indicateur_r6_sensibilite` (au lieu du
  z-score). Le clamp de `normalize_indicator` la laissera intacte → **score correct**.

**Alternative** si l'on préfère normaliser au moment du scoring plutôt qu'à la
source : ajouter un `case` explicite dans `normalize_indicator` pour
`c("indicateur_r6_sensibilite", "sensibilite")` transformant le z-score en 0-100
(direction : sensibilité haute = score bas). Ex. borne symétrique
`100 * (1 - clamp01((z - z_min)/(z_max - z_min)))`. Moins « propre » (dépend d'une
borne z arbitraire, projet-relative) mais localisé.

> Décision cœur attendue : **2.a (source)** vs alternative (scoring). Recommandation
> forte : 2.a, cohérente avec « normaliser dès le calcul » et avec la formule 0-100
> déjà existante.

### 2.b — R7 : rendre la normalisation **explicite**

`indicateur_r7_gel` produit déjà 0-100 ; ajouter néanmoins un `case` explicite
`c("indicateur_r7_gel", "R7") -> pmin(100, pmax(0, values))` (passthrough) pour ne
plus dépendre du repli naïf, et documenter la direction (haut = favorable, peu de
gel).

### 2.c — Filet de sécurité « aucun indicateur non normalisé »

Pour honorer « tous les indicateurs » de façon robuste :

- Établir la **liste blanche** des indicateurs attendus (les 31/32) et vérifier que
  chacun a un `case` dédié dans `normalize_indicator`.
- Émettre un `cli::cli_warn()` quand `normalize_indicator` retombe sur le **repli
  naïf** pour une colonne connue comme indicateur (détecte les futurs oublis).
- Optionnel : test `testthat` paramétré balayant tous les `column_names` de
  `INDICATOR_FAMILIES` et assertant qu'aucun ne déclenche le repli naïf.

## 3. Tests cœur

- `regen_sensibilite()` : la nouvelle colonne 0-100 est bornée [0,100], monotone
  décroissante avec la sensibilité (z↑ ⇒ score↓), NA-safe.
- `normalize_indicator("indicateur_r6_sensibilite", …)` et `…r7_gel` : bornes +
  direction.
- Test « couverture normalisation » (2.c).

## 4. Livrables cœur

- Fonction(s) modifiée(s) : `regen_sensibilite()` (colonne 0-100) et/ou
  `normalize_indicator()` (cases R6/R7 + garde), selon décision 2.a/alternative.
- NEWS + bump cœur, `PLAN.md` cœur (entrée journal), release `nemeton@vX.Y.Z`.
- **Ordre cœur → app** (règle 11) : release cœur d'abord.

## 5. Suivi app `nemetonshiny` (après release cœur — NE PAS faire côté cœur)

Une fois le cœur publié, côté app :

1. `R/service_regeneration.R::add_regen_r_indicators` : injecter la colonne **0-100**
   (`sensibilite_score`/`R6`) dans `indicateur_r6_sensibilite` (au lieu du z-score).
2. `R/mod_synthesis.R::family_scores()` : ajouter `add_regen_r_indicators(...)` après
   `add_r5_to_indicators(...)` pour que R6/R7 entrent dans `create_family_index`
   (aujourd'hui volontairement retenu tant que R6 n'est pas normalisé — cf. fix
   v0.107.9 qui gardait R6/R7 hors score).
3. Vérifier le décompte récap / radar (le score famille R passe de R1-R5 à R1-R7).
4. L'analyse IA par famille consomme déjà R5/R6/R7 (livré app, `ai_family_indicators`,
   v0.107.12.900x) — le texte s'améliorera mécaniquement avec des valeurs 0-100.

## 6. Hors-scope

- Aucun changement au **rang** de sensibilité reGénération (`rang_sensibilite`,
  `priorite`) : le z-score reste la base du classement ; on n'ajoute qu'une vue 0-100.
- Aucune modification de la pondération Fibonacci / φ ni du NDP.
