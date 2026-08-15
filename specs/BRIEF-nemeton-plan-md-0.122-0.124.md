# BRIEF `nemeton` — mise à jour du `PLAN.md` partagé (app 0.122.5 → 0.124.0)

> **Statut** : ✅ **traité le 2026-08-15**, `PLAN.md` mis à jour.
> Les trois entrées de journal sont posées au 2026-08-14, en tête de journal,
> SHA et tags **vérifiés** (les trois tags existent, les trois commits sont sur
> `main` côté app). Le §2 a donné une section « Écarts ouverts dans la chaîne
> cœur → app → foretaccess » en tête de fichier. Le §4 a été revu item par
> item : 4 déjà consignés, 2 complétés là où ils vivent (entrée du 2026-07-15).
> **Une correction de fond** : le §2 donnait le correctif `foretaccess` comme
> « brief déposé, non livré » — il est en réalité **implémenté et vérifié**,
> mais **non tagué** (PR #160 ouverte), ce qui change la nature du blocage.
> Détail en fin de fichier (§6).
> **Statut initial** : ouvert, 2026-08-15.
> **Dépôt concerné** : `nemeton` uniquement — le `PLAN.md` à sa racine est la
> source unique de vérité partagée avec `nemetonshiny` (ADR-009).
> **Nature** : documentation seule. Aucun code cœur, aucune release cœur.
> **Contexte de lecture** : `nemetonshiny@0.124.0.9000`, `main` à `062a3126`.

---

## 0. Ce que je n'ai pas pu faire, et pourquoi ce brief a cette forme

La règle 12 du `CLAUDE.md` de `nemetonshiny` interdit à la session app de lire
ou d'écrire quoi que ce soit dans `/home/pascal/dev/nemeton`. **Je n'ai donc pas
ouvert `PLAN.md`.** Je ne connais ni ses intitulés de chantiers, ni la
numérotation courante de ses épaississements, ni l'état de ses cases.

Ce brief ne peut donc pas dire « cocher la ligne 214 ». Il livre à la place :

- le **texte exact** des entrées de journal à coller, SHA et cycles inclus ;
- une **description du chantier** de chaque livraison, à faire correspondre aux
  cases réelles par la session cœur ;
- une liste d'items **à vérifier**, signalés comme non vérifiés (§4).

Si un chantier décrit ci-dessous n'existe pas dans `PLAN.md`, c'est une
information en soi : il faut le créer, pas forcer la correspondance.

## 1. Trois livraisons à consigner

Toutes trois sont **releasées et taguées** — la règle « ne jamais clore un
chantier sans release poussée » est satisfaite dans les trois cas.

| Release | Commit `main` | Date | Cycle dev repris |
|---|---|---|---|
| v0.122.14 (clôt le lot 0.122.5→0.122.14) | `nemetonshiny@3bc827dc` | 2026-08-14 | `0.122.14.9000` |
| v0.123.0 | `nemetonshiny@6711b05d` | 2026-08-14 | `0.123.0.9000` |
| v0.124.0 | `nemetonshiny@ccbeb3e7` | 2026-08-14 | `0.124.0.9000` |

### 1.1 — v0.123.0 : profil en travers d'un tronçon au clic

**Chantier à chercher** : celui qui porte la **spec 030** (`profil_travers`)
côté `foretaccess`, ou à défaut le chantier « desserte / correction LiDAR ».
C'est la consommation applicative d'une fonction cœur livrée en
`foretaccess 2.3.0`, spécifiée par le brief
`nemetonshiny/specs/BRIEF-profil-travers-desserte.md` rédigé depuis l'app.

> **2026-08-14 — Profil en travers au clic (app).** Dans l'onglet
> Accessibilité, couche « Desserte BD TOPO / corrigée », un clic affiche la
> coupe transversale du tronçon le plus proche : nuage LiDAR de la tranche,
> profil du terrain, chaussée ajustée, et les cinq familles de bords cotées
> (chaussée roulable, plateforme, bande de secours, emprise, accotements).
> Le calcul appartient au cœur — `foretaccess::profil_travers()`, spec 030,
> release 2.3.0, écrite d'après le brief `BRIEF-profil-travers-desserte.md`
> émis par l'app. Côté app : résolution des chemins projet, conversion du clic
> WGS84 vers le CRS de travail, appel, et tracé (`acc_profil_travers()` +
> `fct_plot_desserte_profil.R`, présentation pure). Clic asynchrone malgré un
> coût cœur mesuré à 0,4 s : ce chiffre vaut sur une dalle d'exemple, la
> première lecture d'un catalogue LAZ réel est plus lourde, et la boucle Shiny
> est mono-thread. Livré `nemetonshiny@6711b05d` (v0.123.0), cycle dev
> `0.123.0.9000`.

**Réserve à consigner telle quelle** : la chaîne clic → coupe **n'a jamais été
exercée de bout en bout sur un projet réel** portant à la fois un nuage LiDAR et
une desserte corrigée. Les 30 tests couvrent la résolution des chemins, la
traduction des échecs en raisons lisibles et la planche ; pas la géométrie, qui
est testée côté `foretaccess`. Ne pas cocher la case comme « validé terrain ».

### 1.2 — v0.124.0 : les sorties de l'onglet Desserte deviennent visibles

**Chantier à chercher** : celui qui porte la **spec 026** (détection dessertR)
et/ou la **spec 028** (complément OSM). C'est la mise en vue de leurs sorties,
pas une évolution de leur calcul.

> **2026-08-14 — Sorties Desserte rendues visibles (app).** Cinq actions de la
> sidebar produisaient toutes un résultat sur disque ; deux seulement étaient
> visibles sur la carte. Le complément OSM (spec 028) et la détection de routes
> (spec 026) — les deux traitements les plus coûteux de l'onglet, plusieurs
> minutes et jusqu'à 8 Go pour le second — n'affichaient qu'un compteur : pour
> voir sa propre géométrie il fallait connaître le chemin du cache et ouvrir
> QGIS. Livré : calques « Pistes OSM » et « Routes détectées » (tiretés,
> éteints au départ, déclarés dans le contrôle de couches) ; popup portant
> `CLASSE_CONF`, `CLASSE_MOTIF` et `OSM_TAGS` à côté de `CLASSE`, le balisage
> OSM étant présenté comme une proposition et jamais un téléversement ;
> `.load_cached_typage()` + sidecar `typage.rds` (le typage était le seul des
> cinq à ne pas survivre au rechargement du projet) ; `run_desserte_osm()`
> renvoie et persiste `gpkg_path` ; l'export GeoPackage fusionne réseau typé,
> pistes OSM et routes détectées, en retenant le typage du moteur courant ;
> chemin du cache affiché. Aucune logique métier ajoutée côté app (règle 1).
> Livré `nemetonshiny@ccbeb3e7` (v0.124.0), cycle dev `0.124.0.9000`.

**Dépendance ouverte, à consigner comme telle** :
`foretaccess::comparer_desserte_osm()` ne renvoie **aucune géométrie** — son
helper `hors()` matérialise la portion hors corridor par `st_difference()`, la
mesure, puis la perd. Le « gisement à instruire » n'existe donc qu'en kilomètres
agrégés par type. Le calque livré affiche en conséquence l'acquisition OSM
**brute**, doublons BD TOPO compris, et son libellé (« Pistes OSM ») comme son
popup le disent explicitement. Le correctif est demandé côté `foretaccess` par
`nemetonshiny/specs/BRIEF-foretaccess-osm-hors-corridor.md`. **Ce sous-chantier
n'est donc pas clos** : il l'est côté app, pas côté chaîne.

### 1.3 — v0.122.5 → v0.122.14 : lot de fiabilisation

**Chantier à chercher** : un chantier « qualité / hardening / dette », ou à
défaut le journal général. Dix releases patch en une journée, sans nouvelle
fonctionnalité métier — c'est un lot de fiabilisation, pas un épaississement.

> **2026-08-14 — Fiabilisation app (lot 0.122.5 → 0.122.14).** `R CMD check`
> repasse sans aucun avertissement ni note : sources entièrement désaccentuées,
> tests ne lisant plus `R/` sans garde (sous `.Rcheck` le paquet installé n'a
> pas de sources), dépendances de `Suggests` corrigées après un échec
> d'installation `pak` en CI que le check local ne voyait pas. Les notes de
> release sont désormais extraites de `NEWS.md` par `release.yml`, et un test
> interdit qu'un titre de version y disparaisse — ce défaut avait atteint le
> tag publié v0.122.7. Trois smoke E2E rendus hermétiques et le démarrage
> réessayé. Côté UX : menu des couches piloté intégralement (un groupe peint
> mais non déclaré n'a pas de case — défaut du relief), légende BD TOPO
> re-contrastée par mesure ΔE, infobulles à 17 px, sidebars rétractables
> uniformisées, « i » d'information unifiés sur un seul motif
> (`info_popover()`), code de famille affiché dans le menu des indicateurs.
> Livré `nemetonshiny@3bc827dc` (v0.122.14), cycle dev `0.122.14.9000`.

**Leçon à consigner si le `PLAN.md` tient une rubrique de ce genre** : un signal
vert dans l'environnement le plus favorable ne prouve rien. `devtools::test()`
masquait l'échec de `R CMD check` ; le check local masquait l'échec
d'installation en CI. Chaque garde-fou de ce lot vient d'un défaut qui avait
franchi l'étape précédente.

## 2. Ce qui reste ouvert côté chaîne, à ne pas cocher

| Item | Où | État |
|---|---|---|
| `osm_hors_corridor` / `bdtopo_hors_corridor` | `foretaccess` | brief déposé, non livré |
| Validation terrain du profil en travers | app + terrain | jamais exercé de bout en bout |
| `indicator_families()` consommé par l'app | `nemetonshiny` | `nemeton` l'expose depuis v0.170.0 ; l'app duplique encore 24 clés `famille_*` |

Le troisième point mérite une ligne dans `PLAN.md` : le cœur a livré, l'app n'a
pas consommé. C'est exactement le genre d'écart que la source unique de vérité
est censée rendre visible.

## 3. Vérification de cohérence à faire au passage

`PLAN.md` indique pour chaque entrée quel paquet porte la livraison. Les trois
entrées ci-dessus sont **portées par l'app** ; aucune ne demande de release
cœur, et l'ordre cœur → app est respecté (l'app consomme `foretaccess 2.3.0`,
déjà taguée, via `Remotes: @*release`).

## 4. À vérifier — items que mes notes signalent comme peut-être non appliqués

**Non vérifié** : ces items viennent de notes de sessions antérieures qui
mentionnaient « reste `PLAN.md` cœur à mettre à jour ». Je n'ai pas pu contrôler
s'ils y figurent désormais. À confronter au fichier réel, et à ignorer pour ceux
qui sont déjà consignés :

- spec 035 / spec 027 — moteur et UX de la reGénération (app v0.101.x) ;
- R7 risque de gel tardif + moteur meteoland (app v0.104.0, cœur 0.151.0) ;
- contexte régional E-OBS en raster downscalé (app v0.105.0, cœur 0.152.0) ;
- spec 008 — mémoire des workers `future` (app v0.106.5) ;
- FORDEAD en processus plafonné (app v0.106.6, cœur ≥ 0.157.0) ;
- bascule ALSroads → dessertR, portée par `foretaccess`.

## 5. Checklist

- [ ] Localiser les chantiers correspondant aux §1.1, §1.2, §1.3 ; créer ce qui
      manque plutôt que de forcer une correspondance approximative.
- [ ] Coller les trois entrées de journal, dates et SHA inchangés.
- [ ] Cocher les cases **livrées**, laisser ouvertes celles du §2.
- [ ] Ajouter la ligne « `indicator_families()` non consommé par l'app ».
- [ ] Passer en revue le §4 et ne traiter que ce qui manque réellement.
- [ ] Commit sur une branche dev du dépôt `nemeton`, puis merge selon ses
      propres consignes. **Documentation seule : pas de bump de version cœur,
      pas de release.**

---

## 6. Ce qui a été fait, et le point où le brief était dépassé

### 6.1 Placement retenu

- **Les trois entrées** sont posées en une seule section datée
  `### 2026-08-14 — App nemetonshiny : trois livraisons`, en tête du journal
  (juste avant l'entrée du 2026-08-13), avec le tableau
  release / SHA / cycle dev qu'emploient déjà les entrées app de ce fichier.
  Les textes du §1 sont repris tels quels ; seule la mise en forme suit la
  convention locale.
- **Aucun chantier n'a été créé.** Les trois livraisons trouvent leur place dans
  le journal, qui est ici la forme normale pour une livraison portée par l'app :
  les sections `# Chantier …` sont réservées aux chantiers cœur. Le versant
  cœur du §1.2 existait déjà — *« Brief émis — Onglet Desserte : rendre
  visibles les sorties »* — et pointe maintenant vers l'entrée app.
- **Le §2 a donné une section propre**, `# Écarts ouverts dans la chaîne
  cœur → app → foretaccess`, en tête de fichier plutôt qu'en note de bas de
  journal : un écart qu'on doit voir ne se range pas dans l'ordre
  chronologique.
- **Aucune case cochée**, aucun bump, aucune release. Documentation seule.

### 6.2 La correction de fond

Le §2 classe `osm_hors_corridor` / `bdtopo_hors_corridor` en « brief déposé,
non livré ». **C'est dépassé** : le brief a été appliqué dans `foretaccess`
depuis. Vérifié le 2026-08-15 en lecture seule, hors du dépôt : `hors()` rend
désormais `list(long, parts)`, `.sf_hors()` assemble, le `st_cast()` qui
homogénéise LINESTRING/MULTILINESTRING est en place, `DESCRIPTION` est en
2.4.0 — et 15 assertions passent, dont la non-régression des quatre valeurs de
`resume` et un aller-retour GeoPackage sur un tronçon traversant.

**Mais la PR #160 est ouverte et le tag `v2.4.0` n'existe pas.** Le blocage
n'est donc plus « ce n'est pas écrit » mais « ce n'est pas publié » :
`Remotes: pobsteta/foretaccess@*release` ne voit que les tags. Tant que le tag
manque, le calque « Pistes OSM » continue d'afficher l'acquisition brute, et
l'app ne peut rien y faire. C'est consigné comme tel dans `PLAN.md` (écart n° 2).

### 6.3 L'écart que le §2 avait raison de vouloir rendre visible

Le troisième item — `indicator_families()` livré côté cœur, non consommé par
l'app — est mesurable, et il est pire que « 24 clés dupliquées » :
`nemetonshiny/R/app_config.R` porte un **fork complet** de la table (~430
lignes) qui **a déjà divergé** — 40 indicateurs déclarés contre 41, A5
`indicateur_a5_rafraichissement` absent (donc calculé puis filtré à l'affichage,
invisible dans l'onglet Air), 14 libellés et 18 tooltips divergents. Une
troisième copie des libellés, les 40 clés i18n `indicator_<CODE>`, a même
**F1 et F2 inversés** : la colonne d'érosion s'affiche « F1 - Fertilité des
sols ».

Le cœur expose l'API depuis **v0.170.0**, complétée en **v0.171.0** (deux
langues systématiques, `description` de famille, `family_column` +
`get_famille_col()`/`get_famille_code()`). Six patches vérifiés attendent dans
`specs/patch-nemetonshiny-0[1-6]-*.diff`, avec leur brief
`specs/brief-nemetonshiny-indicator-families.md`. Le plancher de l'app est
toujours `Imports: nemeton (>= 0.169.0)`.

### 6.4 Sur la forme du brief

La contrainte du §0 — la session app ne peut pas lire ce dépôt — a bien produit
l'effet recherché : le texte des entrées était directement collable, et les
descriptions de chantier suffisaient pour les placer. Le seul endroit où le
brief ne pouvait pas être juste est celui où l'information avait bougé chez un
tiers (`foretaccess`), pas celui où il lui manquait la vue sur `PLAN.md`.
