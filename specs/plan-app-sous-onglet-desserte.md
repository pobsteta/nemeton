# Plan de dev — Sous-onglet « Desserte » (moteurs de création `foretaccess`)

**Cible** : nouvel onglet de conception de réseau de desserte forestière, à côté
de « Accessibilité » sous le parent *Terrain accessible*. Expose **tous les
moteurs de création** de `foretaccess`. Bump **MINOR** (nouveau sous-onglet).

**Règle 1/2** : aucune logique métier ici — l'app orchestre (acquisition,
worker async, carte), tout le calcul vit dans `foretaccess`. Même patron exact
que `mod_accessibility` / `service_accessibility` (worker `future`, AOI passée
par fichier, rasters écrits sur disque et relus, notif chrono, cache projet).

---

## 0. Pré-requis / à vérifier AVANT de coder

- [ ] **Brief cœur** : chercher un `brief-nemetonshiny*.md` dans
  `nemeton/specs/**` (les Rd citent « Lot 14/15/16/17 » → une séquence de spec
  existe). Le lire (lecture seule, règle 12 : pas d'écriture cœur). S'il cadre
  déjà l'intégration app, s'y aligner.
- [ ] **Version `foretaccess`** exposant toute la chaîne : confirmer
  `reseau_desserte`, `optimiser_reseau`, `tracer_desserte`,
  `surface_cout_construction`, `vectoriser_reseau`, `calculer_flux`,
  `typer_desserte` (présents en 1.5.0 dans l'arbre courant). Bumper
  `Imports: foretaccess (>= X.Y.Z)` seulement si le plancher actuel est trop bas.
- [ ] **Mesurer le coût** des optimiseurs AVANT de les livrer (leçon câble) :
  `optimiser_reseau(strategie="recuit", n_iter=200)` et `="multistart",
  n_start=16` reconstruisent un réseau complet par essai → potentiellement très
  long. Benchmarker sur une AOI réelle (Chastel-Nouvel) et décider des defaults
  + garde-fous (cf. §5). **Ne pas exposer un moteur qui ne finit pas.**

---

## 1. La chaîne `foretaccess` (ce qu'on orchestre)

```
preprocess(mnt, desserte, foret, parcellaire=…)          # déjà fait pour l'accès
      │
      ├─► surface_cout_construction(pre, plan_eau, cours_eau, sol, interdit, surcout)
      │        └─► { cout (€/m), franchissable (logique) }        [Lot 14]
      │
      ▼  MOTEURS DE CRÉATION  (entrées : pre, cout, parcelles, desserte_existante)
   ┌─────────────────────────────────────────────────────────────────────┐
   │ A. reseau_desserte(… mode="glouton")   → réseau glouton MTAP  [Lot16] │
   │ B. reseau_desserte(… mode="steiner")   → réseau Steiner              │
   │ C. optimiser_reseau(… strategie="multistart"|"recuit"|"riprute")     │
   │                                        → meilleur réseau + journal    │
   │ D. tracer_desserte(pre, cout, waypoints) → tracé A* manuel   [Lot15] │
   └─────────────────────────────────────────────────────────────────────┘
      │  (A/B/C → foretaccess_reseau : lignes sf, reseau raster, cout, connexe, desservies)
      ▼  POST-TRAITEMENT (typage optionnel)
   vectoriser_reseau(reseau) → graphe (noeuds/troncons)          [Lot17]
      └─► calculer_flux(graphe, parcelles, volume_champ) → flux
             └─► typer_desserte(graphe, seuils_flux) → troncons typés (primaire/…/temporaire)
```

**Moteurs de création à exposer (5 stratégies, 3 fonctions) :**
| # | Libellé UI | Appel | Nature |
|---|-----------|-------|--------|
| A | Glouton (MTAP) | `reseau_desserte(mode="glouton")` | rapide, référence |
| B | Steiner | `reseau_desserte(mode="steiner")` | mutualise mieux |
| C1 | Optimisé — multi-départs | `optimiser_reseau(strategie="multistart")` | **lourd** |
| C2 | Optimisé — recuit simulé | `optimiser_reseau(strategie="recuit")` | **lourd** |
| C3 | Optimisé — rip-up/reroute | `optimiser_reseau(strategie="riprute")` | **lourd** |
| D | Tracé manuel (waypoints) | `tracer_desserte(waypoints=…)` | interactif carte |

Entrées communes déjà disponibles côté app (réutiliser
`service_accessibility.R`) : MNT HIGHRES (`.acquire_mnt_highres`), desserte
existante (`acquire_desserte`), forêt (`acquire_foret`), `preprocess`.
Nouveau : `parcelles` = AOI projet (`.resolve_accessibility_aoi`, à mutualiser)
+ couches eau/sol optionnelles pour le coût (voir §4).

Config par défaut (`foretaccess_config()$desserte`) : `cout` (base 20 €/m,
barème pente 0/15/35/60, pont 400 €/m, buse 120 €/m) ; `trace` (pente long
2–12 %, rayon/épingle, dévers…). À exposer partiellement en UI (§3).

---

## 2. Fichiers à créer / modifier

**Créer**
- `R/service_desserte.R` — adaptateur non-Shiny (jumeau de
  `service_accessibility.R`) : `DESSERTE_ENGINES`, `run_desserte()` (worker),
  helpers cache, export GPKG.
- `R/mod_desserte.R` — `mod_desserte_ui/server` (jumeau de `mod_accessibility`).
- `tests/testthat/test-service_desserte.R`, `test-mod_desserte.R`.

**Modifier**
- `R/app_ui.R` — nouveau `nav_panel(value="desserte", …)` après
  `accessibility` (icône `bsicons::bs_icon("bezier2")` ou `"diagram-3")`).
- `R/app_server.R` — `mod_desserte_server("desserte", app_state)`.
- `R/utils_i18n.R` — bloc de clés `dess_*` (en `\uXXXX`, règle 4).
- `DESCRIPTION` / `NEWS.md` / `CITATION.cff` / `CHANGELOG.md` (bump MINOR).

**Mutualiser** (refactor léger, sinon duplication) : sortir de
`service_accessibility.R` les acquisitions partagées (`.acquire_mnt_highres`,
acquisition desserte/forêt, résolution AOI) vers un `R/service_foretaccess_io.R`
commun, consommé par les deux services. À faire en 1er, PATCH séparé, pour ne
pas mélanger refactor et feature.

---

## 3. UI (module, patron sidebar gauche = calcul / droite = affichage)

**Sidebar gauche (commandes du calcul)**
- `radioButtons` **moteur** : Glouton / Steiner / Optimisé / Tracé manuel.
- Si *Optimisé* : `radioButtons` stratégie (multistart / recuit / riprute) +
  inputs bornés (`n_start`, `n_iter`, `graine`) — **avec libellé « calcul
  long »**, non pré-sélectionné (opt-in, leçon câble).
- Si *Tracé manuel* : mode « cliquer les waypoints sur la carte » (voir §6).
- Réglages coût (accordéon repliable) : `cout_base_m`, activer/désactiver
  surcoût eau (pont/buse) — cf. §4.
- `input_task_button` « Générer la desserte » + `uiOutput` chrono (parité
  FAST/FORDEAD/RECONFORT/accessibilité).

**Carte (droite)**
- Fonds OSM/Satellite + panes dédiés (mêmes zIndex que l'accès).
- Couches : `Parcelles` (AOI), `Desserte existante` (gris), **`Desserte créée`**
  (lignes générées, colorées par `ordre` ou par `type` si typage), overlay coût
  optionnel (`surface_cout_construction$cout`), waypoints (tracé manuel).
- Légende + badge (ex. « réseau connexe : oui/non », « N parcelles desservies /
  M », coût total) depuis `foretaccess_reseau$connexe/$desservies/$cout`.
- `radioButtons` « Couche affichée » (réseau créé / coût / typage) + slider
  opacité (comme l'accès).
- Accordéon Exports : GPKG (lignes créées + réseau existant + typage).

---

## 4. Surface de coût (entrée des moteurs)

`surface_cout_construction(pre, plan_eau, cours_eau, sol, interdit, surcout)` :
seul `pre` est requis, chaque couche absente = contribution nulle (jamais
d'erreur). 1er incrément :
- **Coût de base + barème pente** uniquement (defaults config) → aucune
  acquisition supplémentaire, marche tout de suite.
- **Eau (pont/buse)** : brancher `plan_eau`/`cours_eau` si `foretaccess` sait
  les acquérir pour l'AOI (à vérifier — sinon repli IGN BD TOPO hydro via
  `happign`, ou NULL). Décision à prendre selon dispo cœur.
- `sol`, `interdit`, `surcout` : NULL au 1er incrément.

---

## 5. Performance & garde-fous (obligatoire — leçon câble)

- Tout tourne dans un **worker `future`** (`ExtendedTask` + `future_promise`),
  AOI passée par fichier (pointeur externe sf non sérialisable), rasters écrits
  worker-side, relus process principal. Copier le squelette de `acc_task`.
- **Glouton** = moteur par défaut (rapide, sûr). Steiner ensuite.
- **Optimiseurs (C1/C2/C3)** : non pré-sélectionnés, libellé « long », bornes
  par défaut basses tant que le benchmark §0 n'a pas validé. Si un réglage
  dépasse un seuil, afficher un avertissement (comme le badge DFCI heuristique).
- **Cache projet** : `cache/desserte/` avec un `.tif`/`.gpkg` par moteur+réglage,
  rechargé au montage de l'onglet (jumeau `.load_cached_accessibility`).
- **Transparence** : réutiliser `.acc_mask_hors_foret` / `.acc_level_colors`
  (les mutualiser aussi si le typage produit un raster catégoriel) — attention
  au **piège S4 `%in%`** déjà corrigé (passer par `terra::values()`).

---

## 6. Tracé manuel par waypoints (UX spécifique)

`tracer_desserte(pre, cout, waypoints)` attend des points de passage. Côté app :
- Capturer les clics carte (`leaflet` `input$map_click`, ou `leaflet.extras`
  `addDrawToolbar` pour poser/éditer une polyligne de waypoints).
- Convertir en cellules (le worker fait `waypoints` → n° de cellule).
- Afficher `foretaccess_trace$ligne` (LINESTRING) + `cout` + `faisable`.
- État réactif des waypoints dans `rv` ; bouton « effacer les points ».
- C'est le seul moteur **interactif** : le prévoir comme un mode distinct de
  l'UI (pas de bouton « Générer » global, mais « Tracer entre les points »).

---

## 7. Typage du réseau (post-traitement optionnel, 2e incrément)

`vectoriser_reseau → calculer_flux → typer_desserte` colore les tronçons par
classe (primaire/secondaire/tertiaire + temporaire/hiver). `calculer_flux` a
besoin d'un **volume par parcelle** (`volume_champ`). Décision :
- 1er incrément : typage **désactivé** ou volume uniforme (démo).
- Vrai volume = indicateur **P1 (volume bois)** de `nemeton` → couplage cœur.
  À traiter séparément (ne pas dupliquer le calcul de volume — règle 1).

---

## 8. Découpage en incréments (releases)

1. **PATCH** — refactor : extraire les IO `foretaccess` partagées
   (`service_foretaccess_io.R`), sans changement fonctionnel. Tests verts.
2. **MINOR** — sous-onglet « Desserte » v1 : moteurs **Glouton + Steiner**,
   coût base+pente, carte + réseau créé + badges (connexe/desservies/coût),
   export GPKG, cache. Optimiseurs **non exposés** tant que le benchmark n'est
   pas fait.
3. **PATCH** — après benchmark : exposer **optimiseurs** (multistart/recuit/
   riprute) avec bornes + avertissements.
4. **PATCH** — **tracé manuel** par waypoints (UX carte).
5. **PATCH** — surcoût **eau** (pont/buse) dans la surface de coût.
6. **MINOR/PATCH** — **typage** du réseau (flux + `typer_desserte`), volume via
   nemeton P1 (couplage cœur → session dédiée si besoin).

---

## 9. Tests (testthat ed.3, patron accessibilité)

- `test-service_desserte.R` : `DESSERTE_ENGINES` bien exposés ; `run_desserte`
  gardes (pas de projet / pas de moteur / échecs structurés `list(status=
  "error", reason=…)`) ; export GPKG.
- `test-mod_desserte.R` : `testServer` — résolution AOI/parcelles, gardes de
  lancement (aucun worker sans projet), rendu du sélecteur après résultat posé
  dans `rv`, masquage transparent du raster typage (réutilise le test PNG).
- Mocker `foretaccess::*` via `local_mocked_bindings(.package="foretaccess")`
  pour ne pas lancer les vrais solveurs en CI.

## 10. i18n (clés à créer, `dess_*`)

Titre onglet, intro, sélecteur moteur (glouton/steiner/optimise/trace),
stratégies (multistart/recuit/riprute), réglages (n_start, n_iter, cout_base,
surcout eau), boutons (générer, tracer, effacer points), badges (connexe,
N/M desservies, cout total, faisable), classes de typage, messages d'erreur
worker (`desserte_no_foretaccess`, `_need_project`, `_need_engine`,
`_cout_failed`, `_engine_failed`, …). Toutes en `\uXXXX`.
