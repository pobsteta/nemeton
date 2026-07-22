# Plan d'incréments app — consommer foretaccess 1.9.0

**Cible** : exploiter côté `nemetonshiny` ce que `foretaccess` a livré en 1.6.0→1.9.0
(`places_depot`, `volume_depuis_p1`, `acquire_inputs(volume=)`, `accessfor_correspondance`).
Débloque le **moteur câble**, le **volume P1→câble** et la **validation ACCESSFOR**.

**Règles** : aucune logique métier app (1/2) ; i18n `\uXXXX` ; couleurs sémantiques ;
piège S4 `%in%` (primitives `terra`) ; worker async pour tout calcul long ; contrat
d'erreur structuré. Tout est tracé au PRD/architecture ForêtAccess (`design/`).

---

## Incrément 0 (PRÉ-REQUIS) — Bump du pin foretaccess

**Aujourd'hui** : `Imports: foretaccess (>= 1.5.0)` + `Remotes: pobsteta/foretaccess@v1.5.0`.
Aucune des fonctions 1.6→1.9 n'est dans 1.5.0.

- [ ] `DESCRIPTION` : `Imports: foretaccess (>= 1.9.0)` + `Remotes: pobsteta/foretaccess@v1.9.0`.
- [ ] Vérifier que rien d'existant ne casse (l'installé est déjà 1.9.0 ; tests verts).
- [ ] Commit `chore(deps): foretaccess >= 1.9.0 (places_depot, volume, ACCESSFOR)`.

**Bump** : PATCH. Pré-requis de tous les incréments suivants.

⚠️ **Alternative à évaluer** : `acquire_inputs(aoi, sources=…, volume=…)` (1.8.0) est un
**orchestrateur d'acquisition** unifié (mnt/desserte/foret/obstacles/cadastre + volume).
Il pourrait **remplacer** l'acquisition morcelée de `service_foretaccess_io.R` /
`run_accessibility` / `run_desserte`. À expertiser comme **refactor séparé** (PATCH) —
ne pas mélanger avec les features ci-dessous. Bénéfice : moins de code app, moins de
dérive vs le cœur. Risque : re-tester les 4 fichiers acc/desserte + leurs mocks.

---

## Incrément 1 — Moteur câble-mât (enfin exposable)

Le blocage « pas de couche de départ » a sauté : `places_depot()` (1.6.0/1.6.1) fournit
les départs, `potentiel_cable(departs=)` les consomme (même forme de retour que skidder :
`$accessibilite` + `$recap`).

**Service** (`service_accessibility.R`) :
- [ ] Ajouter `"cable"` à `ACCESSIBILITY_ENGINES` (le code + les commentaires « non exposé »
  sont déjà en place, il ne reste qu'à activer).
- [ ] Dans `run_accessibility`, avant le moteur câble :
  `departs <- foretaccess::places_depot(desserte, mnt, foret = foret_mask, retournements = NULL)`
  puis `foretaccess::potentiel_cable(pre, departs = departs)`.
- [ ] `places_depot()` est **heuristique** (précision ~4 %, rappel 2/2 sur l'oracle) →
  remonter un **badge de provenance** « départs estimés (places_depot) » comme le badge DFCI.
- [ ] Garde perf : `espacement_min_m` (défaut 200) borne déjà le nombre de départs ; opt-in
  « calcul long » + cache (patron existant).

**Module** (`mod_accessibility.R`) :
- [ ] Checkbox « Câble-mât » **non pré-cochée** (opt-in), libellé « calcul long ».
- [ ] Légende + couleur sémantique pour `accessible_cable` (déjà prévue dans `.ACC_CLASS_COLORS`
  d'un précédent essai — à réintroduire).
- [ ] Badge provenance des départs.

**i18n** : `acc_engine_cable`, `acc_cable_slow_help`, `acc_class_accessible_cable`,
`acc_cable_departs_badge` (FR/EN, `\uXXXX`).

**Tests** : pipeline end-to-end câble sur données `toy` (mock `places_depot`/`potentiel_cable`),
+ garde-fous. **Bump** : MINOR (nouveau moteur exposé) ou PATCH si regroupé.

---

## Incrément 2 — Volume P1 → câble (IPC réel)

`potentiel_cable()` lit `pre$volume` pour l'IPC (indice de production câble). Le raccord
P1 Nemeton → volume est **explicitement attendu côté app** (NEWS foretaccess 1.8.0).

- [ ] Résoudre le volume P1 du projet : `nemeton::indicateur_p1_volume()` (ou le P1 déjà
  calculé dans `project$indicators_sf`) → `sf` d'unités avec champ m³/ha.
- [ ] `vol <- foretaccess::volume_depuis_p1(p1, mnt, champ = "P1")` → `SpatRaster`.
- [ ] Passer à `preprocess(mnt, desserte, foret, volume = vol)` **quand le moteur câble
  est demandé** (sinon volume = NULL, inutile aux moteurs terrestres).
- [ ] Alternative : `acquire_inputs(aoi, …, volume = p1, champ_volume = "P1")` si l'incrément 0
  bascule sur l'orchestrateur.
- [ ] Afficher l'IPC / volume de ligne dans le récap câble (badge ou table).

⚠️ **Dépendance cœur** : nécessite que le projet ait un **P1 calculé**. Si absent, dégrader
gracieusement (câble sans volume → pas d'IPC, message clair). `volume_depuis_p1` **ne
dépend pas** de Nemeton (consomme un `sf`), mais la **source** P1 vient de `nemeton` —
vérifier `indicateur_p1_volume()` disponible dans la release cœur consommée.

**i18n** : `acc_cable_ipc`, `acc_cable_no_volume`. **Tests** : `volume_depuis_p1` mocké.
**Bump** : PATCH.

---

## Incrément 3 — Validation ACCESSFOR (référence IGN)

`accessfor_correspondance()` (1.9.0) fige la table de correspondance classes ForêtAccess
↔ couche **ACCESSFOR de l'IGN** (référence nationale officielle, WFS). Matérialise le
**Technical Success** du PRD (« sorties cohérentes avec la référence »).

- [ ] Récupérer la couche ACCESSFOR sur l'AOI (WFS IGN, via `happign` ou `foretaccess`).
- [ ] `corr <- foretaccess::accessfor_correspondance()` → jointure **sur l'entier**
  (jamais le libellé) entre nos `classes_debardage()` et `class` ACCESSFOR.
- [ ] Vue de comparaison : carte côte-à-côte ou table de concordance (% d'accord par classe).
- [ ] Optionnel : couche ACCESSFOR en overlay carte (fond de validation).

**Où** : soit un encart dans l'onglet Accessibilité (« Comparer à ACCESSFOR »), soit une
vue dédiée. À cadrer UX. **i18n** : bloc `acc_accessfor_*`. **Tests** : correspondance mockée.
**Bump** : MINOR si nouvelle vue, PATCH si encart.

---

## Séquencement recommandé

1. **Inc. 0** (pin @v1.9.0) — pré-requis, PATCH.
2. **Inc. 1** (câble) — la valeur la plus visible ; débloque le PRD « Growth : câble ».
3. **Inc. 2** (volume P1) — enrichit le câble (IPC) ; dépend d'Inc. 1.
4. **Inc. 3** (ACCESSFOR) — validation, indépendant ; peut se faire en parallèle.
5. (Optionnel) refactor `acquire_inputs()` — séparé, quand le reste est stable.

**Toujours bloqué (côté cœur, pas dans ce plan)** : perf glouton < 5 min + Steiner/optimiseurs
+ sémantique `connexe` (cf. `brief-foretaccess.md`). Le câble, lui, **n'attend plus rien** du
cœur — `places_depot` borne déjà le nombre de départs.

## Mise à jour PRD/architecture

Ces incréments font passer des FR **Growth → livré** : **FR22 (câble)**. Mettre à jour
`design/prd-foretaccess.md` (scope MVP/Growth) et `design/architecture-foretaccess.md`
(D6 extensibilité : câble câblé ; nouvelle intégration `places_depot`/`volume_depuis_p1`/
`accessfor_correspondance`) une fois livrés.
