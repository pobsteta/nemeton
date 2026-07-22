# Brief cœur — Desserte ForêtAccess : perf des moteurs + connexité

> **Destinataire** : session dédiée `/home/pascal/dev/nemeton` (et/ou `foretaccess`).
> **Émetteur** : session app `nemetonshiny` (règle 12 : je ne touche pas au cœur).
> **But** : rendre exploitables en production les moteurs de création de desserte,
> aujourd'hui exposés en v1 côté app avec un seul moteur (glouton), opt-in, à
> cause de deux blocages **côté cœur** : la performance et la connexité du réseau.

## 1. État côté app (ce qui est déjà livré)

- Nouveau sous-onglet **Desserte** livré : `nemetonshiny@55992e6c`, cycle dev
  `0.111.2.9002`. Pipeline app : acquisition MNT 5 m HIGHRES + desserte IGN BD
  TOPO + masque BD Forêt V2 → `preprocess()` → `surface_cout_construction()` →
  `reseau_desserte(mode="glouton")`. Worker `future`, cache projet, export GPKG.
- **Seul le glouton est exposé** (`DESSERTE_ENGINES <- c("glouton")`). Steiner et
  les optimiseurs sont volontairement retirés de l'UI tant que ce brief n'est
  pas traité.
- L'intégration des autres moteurs est **triviale côté app** (même signature
  `f(pre, cout, parcelles, desserte_existante, …)`, même forme de retour
  `foretaccess_reseau`) : le blocage est **entièrement côté cœur**.

## 2. Blocage 1 — Performance

Mesuré sur AOI réelle **Chastel-Nouvel** (30 parcelles, 31 ha, MNT 5 m
530×571 = ~302k cellules, desserte existante ≈ 806 km / 3 299 tronçons) :

| Étape | Temps |
|---|---|
| `preprocess()` | 1,2 s |
| `surface_cout_construction()` | 0,1 s |
| **`reseau_desserte(mode="glouton")`** | **692 s (~11,5 min)** |
| `reseau_desserte(mode="steiner")` | non mesuré — **N² tracés** → estimé **> 5 h** |
| `optimiser_reseau(...)` (multistart/recuit/riprute) | non mesuré — **k × un réseau complet** par essai (n_start=16 / n_iter=200) → intraitable |

Sur les **données `toy`** de `foretaccess` (2 500 cellules, 1 parcelle), le même
pipeline tourne en **1,46 s** — le coût est donc bien dominé par la taille de
l'emprise et **le nombre de parcelles** (un tracé A* par parcelle en glouton,
N² en Steiner).

**Demande** :
1. Ramener le glouton à l'échelle interactive (ou documenter un ordre de grandeur
   réaliste + un mode « emprise réduite / parcelles agrégées »). Pistes possibles
   (à trancher côté cœur) : parallélisation des tracés, réutilisation du réseau
   partiel, grille de recherche plus grossière, cache de propagation.
2. **Benchmarker Steiner et les optimiseurs** sur une AOI de gestion type, et
   fixer des **bornes par défaut** (n_start, n_iter, cap de parcelles) au-delà
   desquelles l'app doit avertir. Sans ces chiffres, l'app ne peut pas exposer
   ces moteurs sans risquer un run qui ne finit pas (leçon du câble-mât).

## 3. Blocage 2 — Connexité du réseau créé

Sur le même run Chastel-Nouvel, `reseau_desserte(mode="glouton")` renvoie
**`connexe = FALSE`** alors que **`desservies = 30/30`** (toutes les parcelles
sont desservies). Un réseau de desserte non connexe est contre-intuitif pour de
la conception d'accès (des tronçons créés qui ne se rejoignent pas au réseau
existant ou entre eux).

**Demande** : investigation côté cœur — est-ce attendu (composantes multiples
raccordées chacune à une entrée différente du réseau existant, donc « connexe »
au sens du graphe global desserte+créé), un artefact du critère `connexe`
(CA-16.5), ou un vrai défaut de raccordement ? Clarifier la sémantique exacte de
`connexe` dans la doc de `reseau_desserte()`, et corriger si c'est un défaut.
L'app affiche ce booléen tel quel dans un badge — sa signification doit être sûre.

## 4. Sortie verbeuse (info, pas un blocage app)

`reseau_desserte()` renvoie `$lignes` = **10 640 features** LINESTRING sur cette
AOI (segments fins au pas de la grille, non contractés). L'app **contourne** en
affichant `$reseau` (raster) et n'utilise `$lignes` que pour l'export GPKG. Si
`foretaccess` exposait des **tronçons contractés** (comme `vectoriser_reseau()`
le fait pour le graphe, ou un `$lignes` déjà simplifié), l'app pourrait afficher
un vecteur propre et léger. Optionnel, à considérer.

## 5. Livrables attendus de la session cœur

1. Perf glouton à l'échelle interactive **ou** stratégie documentée
   (emprise/agrégation) + ordre de grandeur.
2. Benchmark Steiner + optimiseurs, **bornes/defaults** exposables.
3. Clarification (et correction si nécessaire) de la **connexité** +
   sémantique du champ `connexe`.
4. Le cas échéant, `$lignes` contracté (optionnel).
5. Bump cycle dev `foretaccess`/`nemeton` + entrée `PLAN.md` cœur (chantier
   desserte), en indiquant la version qui débloque l'exposition app des moteurs
   restants. L'app posera alors `Imports: foretaccess (>= X.Y.Z)` et élargira
   `DESSERTE_ENGINES`.

## 6. Ce que l'app fera une fois débloqué (pour info)

- Élargir `DESSERTE_ENGINES` (steiner + optimiseurs), ajouter le radio de
  stratégie + inputs bornés (n_start/n_iter/graine) avec avertissements.
- Suite du plan de dev app : tracé manuel par waypoints (`tracer_desserte`),
  surcoût eau (pont/buse) dans la surface de coût, typage du réseau
  (`vectoriser_reseau` → `calculer_flux` → `typer_desserte`, volume via
  l'indicateur nemeton P1 — couplage cœur).

## 7. Rappels de traçabilité

- Entrée `PLAN.md` cœur (fix transparence hors_foret) déjà demandée dans un brief
  séparé (`nemetonshiny@59522747`, release v0.111.2).
- Cette session app reste dédiée à `nemetonshiny` : toute modif cœur passe par la
  session `nemeton`, pas d'aller-retour (règle 12).
