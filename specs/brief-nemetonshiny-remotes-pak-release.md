# Brief `nemetonshiny` — `Remotes: @*release` casse l'install sous pak 0.11 / R 4.6

**Date** : 2026-07-17
**Repo cible** : `nemetonshiny` (DESCRIPTION — **aucun changement cœur `nemeton`**).
**Sévérité** : bloquant à l'installation (l'app ne s'installe plus).

## 1. Symptôme

`pak::pkg_install()` / l'installation de `nemetonshiny` échoue à la résolution des
dépendances :

```
* pobsteta/nemetonshiny:
  * Can't install dependency pobsteta/nemeton@*release (>= 0.162.0) (>= 1.2.0)
  * Can't install dependency pobsteta/foretaccess@*release (>= 1.2.0)
* pobsteta/nemeton@*release: ! pkgdepends resolution error ...
  Caused by error: ! the condition has length > 1
* pobsteta/foretaccess@*release: ! pkgdepends resolution error ...
  Caused by error: ! the condition has length > 1
```

`nemeton` lui-même se construit et s'installe (`0.162.0.9000`) : le blocage est **la
résolution des `Remotes: …@*release`**.

## 2. Cause racine (prouvée)

Bug du résolveur **`@*release` de `pak` 0.11.0 sous R 4.6.1** — pas les packages ni
les contraintes de version. Vérifié sur la machine (2026-07-17) :

| Référence testée | Résultat |
|---|---|
| `pobsteta/foretaccess@v1.2.0` | ✅ résolu |
| `pobsteta/foretaccess@*release` | ❌ `the condition has length > 1` |
| `pobsteta/nemeton@*release` | ❌ `the condition has length > 1` |

`foretaccess` n'a **qu'une** release propre (`v1.2.0`) et échoue quand même → ce
n'est ni le nombre de releases, ni le tag `v0.1.0-rc2` de nemeton, ni les
contraintes (`nemeton (>= 0.162.0)` ✓ release v0.162.0 ; `foretaccess (>= 1.2.0)` ✓
release v1.2.0). Le code `@*release` de pkgdepends fait un `if()` sur un vecteur de
longueur > 1, ce que **R 4.6.1** (2026-06-24) transforme en erreur fatale (avant
R 4.2 : simple avertissement). Environnement : `pak 0.11.0`, `R 4.6.1`,
`.libPaths()[1] = ~/R/x86_64-pc-linux-gnu-library/4.6`.

## 3. Correctif — `nemetonshiny/DESCRIPTION`, champ `Remotes:`

**Avant :**
```
Remotes: pobsteta/nemeton@*release, pobsteta/foretaccess@*release, r-lidar/lasR
```

Retirer les deux `@*release`. Deux options (le plancher de version reste porté par
`Imports: nemeton (>= 0.162.0), foretaccess (>= 1.2.0)`) :

### Option A — branche par défaut pour nemeton, tag pour foretaccess (recommandée)
```
Remotes: pobsteta/nemeton, pobsteta/foretaccess@v1.2.0, r-lidar/lasR
```
- **Zéro maintenance** : `pobsteta/nemeton` (= `main`) est toujours à
  `X.Y.Z.9000 ≥` la dernière release, donc satisfait `Imports (>= …)`. Adapté à la
  co-évolution serrée cœur/app à cadence de release élevée (main = ce que tu testes).
- `foretaccess` épinglé à son tag stable (dépendance moins mouvante).
- `r-lidar/lasR` inchangé (déjà sans `@*release`, forme qui fonctionne).

### Option B — tags épinglés partout (reproductibilité de distribution)
```
Remotes: pobsteta/nemeton@v0.162.0, pobsteta/foretaccess@v1.2.0, r-lidar/lasR
```
- Reproductible (un end user tiers obtient exactement la version testée), au plus
  proche de l'intention d'origine de `@*release` (« une release, pas la dev »).
- **Coût** : re-pin `nemeton@vX.Y.Z` à **chaque** release cœur (cadence élevée →
  charge non nulle ; automatisable dans le workflow de release app si souhaité).

**Recommandation** : **Option A** tant que cœur et app sont co-développés au même
rythme ; bascule vers **B** si `nemetonshiny` est distribué à des tiers qui doivent
figer une version précise.

> Ne PAS conserver `@*release` : la forme est cassée tant que pak n'a pas corrigé le
> bug (cf. §5). `@main` explicite conviendrait aussi mais `pobsteta/nemeton` (défaut)
> est plus lisible.

## 4. Vérification après édition
```r
# doit résoudre sans « condition has length > 1 »
pak::pkg_deps("pobsteta/nemeton")              # ou @v0.162.0 selon l'option
pak::pkg_deps("pobsteta/foretaccess@v1.2.0")
# puis l'app :
pak::local_install("/home/pascal/dev/nemetonshiny")
```
Aucun autre champ à toucher ; `Imports:`/`Depends:` restent identiques.

## 5. Contournement immédiat (avant même d'éditer le DESCRIPTION)

Pour débloquer une install tout de suite, installer les deps **d'abord** (sans
`@*release`), puis l'app sans re-résoudre ses Remotes :
```r
pak::pkg_install(c("pobsteta/nemeton", "pobsteta/foretaccess@v1.2.0"))
pak::local_install("/home/pascal/dev/nemetonshiny", dependencies = FALSE)
```
(Passer les tags dans le *même* appel que l'app ne suffit pas : les `Remotes:
@*release` reprennent le dessus — testé.)

## 6. À signaler en amont
Bug pak/pkgdepends : `@*release` → `the condition has length > 1` sous R ≥ 4.2
(fatal en 4.6.1). À reporter sur `r-lib/pak` (repro minimal : n'importe quel
`owner/repo@*release`, y compris un repo à une seule release). `pak::pak_update()`
à tenter — si une version corrigée pour R 4.6 est publiée, elle rend ce brief
caduc et `@*release` pourra être rétabli.

## 7. Hors-scope
- Aucun changement cœur `nemeton` (le package s'installe correctement).
- Aucune modif de `Imports:`/`Depends:` ni du code de l'app.
