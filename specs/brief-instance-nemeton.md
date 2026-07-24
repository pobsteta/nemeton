# Brief — Rédaction des specs « Variables biophysiques Sentinel-2 »

> À coller comme message d'ouverture d'une instance travaillant dans le dépôt
> `pobsteta/nemeton`.

---

Tu es un ingénieur R senior spécialisé en télédétection forestière et en
architecture de packages scientifiques, familier des systèmes d'indicateurs à
niveaux de confiance quantifiés.

Tu travailles dans le dépôt `pobsteta/nemeton` (package R, MIT, v0.43.0,
12 familles d'indicateurs, système NDP à 5 niveaux avec pondération Fibonacci
et confiance phi).

## Objectif

Rédiger les documents de spécification qui permettront ensuite de coder
l'intégration de quatre variables biophysiques Sentinel-2 — LAI, fAPAR,
FCOVER, CCC — dans nemeton.

**Tu ne codes rien à ce stade.** Aucun fichier dans `R/`, aucun test, aucune
donnée. Uniquement les documents de cadrage. L'implémentation fera l'objet
d'une session ultérieure pilotée par ce que tu produis maintenant.

## Décisions déjà arrêtées

Ces choix ont été instruits en amont. Ne les relitige pas — sauf si tu
trouves dans le code une contrainte qui les rend impraticables, auquel cas
signale-le explicitement plutôt que de dévier en silence.

1. **Pas de nouveau sous-indicateur.** Ces variables sont des données amont,
   sans direction normative propre. On enrichit l'existant, on n'ajoute pas
   de 32ᵉ indicateur ni d'axe au radar.

2. **Package amont séparé**, sur le patron d'`opencanopynemeton` et de
   l'ADR-009. Nom provisoire `biophysnemeton`. Il produit et assainit les
   rasters ; nemeton les consomme via arguments optionnels.

3. **Pas de dépendance à SNAP ni à Google Earth Engine.** L'algorithme SL2P
   (Weiss & Baret) est un perceptron à une couche cachée de 5 neurones sur
   8 bandes + 3 angles ; il est porté en R pur. Coefficients extraits des
   auxdata du toolbox Sentinel-2, distincts par plateforme (S2A / S2B / …),
   routage par plateforme obligatoire, jamais de repli implicite.

4. **Fenêtre temporelle fixe : juin à août** (`month %in% 6:8`, pas de jour
   julien, pour éviter la gestion des bissextiles). Identique pour toutes les
   essences et régions. Mais **lue depuis une table de référence à une seule
   ligne, jamais codée en dur** — l'indirection rend un raffinement ultérieur
   (altitude, puis essence) possible sans changement d'API.

5. **Composite = médiane des observations valides**, pas maximum. Le maximum
   est biaisé à la hausse par les contaminations résiduelles et ce biais croît
   avec le nombre d'observations, ce qui rend incomparables des unités
   inégalement couvertes.

6. **`r3_secheresse` par anomalie** contre ligne de base pluriannuelle (≥ 5
   ans) sur la même fenêtre, pas par valeur absolue. Chemin d'entrée distinct
   des autres indicateurs : série, pas instantané.

7. **Flag `augmented` conditionné.** Nouvelle valeur `"biophysical_s2"`,
   posée seulement si `n_obs`, taux de masquage, flags SL2P et surface de
   l'unité passent les seuils. Sinon `NA` et calcul en mode nominal. Aucun
   repli silencieux : un flag posé sur une base insuffisante fausserait la
   confiance phi, ce que l'ADR-011 interdit de fait.

8. **Mapping vers l'existant** : FCOVER → `a1_couverture` ; LAI → `w3_humidite`,
   `c1_biomasse`, `b2_structure` ; fAPAR → `c2_ndvi` (nom conservé, mode
   ajouté) ; CCC → `f1_fertilite`, `r3_secheresse`.

9. **Correction de biais obligatoire en forêt.** SL2P sous-estime le LAI de
   20 à 50 % pour LAI > 2 en peuplement forestier. Table indexée par classe
   d'essence et région, sourcée par ligne, sur le modèle de
   `site_index_curves.csv` et de son `inst/NOTICE`.

## Méthode

Procède dans cet ordre. Ne commence pas à rédiger avant d'avoir terminé
l'étape 2.

1. **Lis** : `CLAUDE.md`, `CLAUDE-tests-addendum.md`, `PLAN.md`, le contenu de
   `specs/`, les ADR (en particulier 009 et 011), et la vignette
   `site-index-open-canopy_fr`.

2. **Inspecte le code** : `R/ndp.R` et `detect_ndp()`, la fonction
   `sanitize_chm()`, les sept fichiers d'indicateurs cibles, `nemeton_layers()`,
   `nemeton_compute()`, la sérialisation GeoPackage. Relève précisément :
   - comment le flag `augmented` est typé, stocké et sérialisé aujourd'hui
   - la signature exacte par laquelle les indicateurs reçoivent le CHM
   - les conventions de nommage, de numérotation des specs et des ADR
   - le format effectif des ADR existants

3. **Réconcilie** avec les décisions ci-dessus. Tout écart entre ce que
   suppose ce brief et ce que fait réellement le code doit être listé avant
   les livrables, pas dilué dedans.

4. **Rédige** les trois livrables ci-dessous, en respectant scrupuleusement
   les conventions constatées à l'étape 2 — numérotation, structure, langue,
   accentuation, style d'en-têtes.

## Livrables

**A. `specs/NNN-biophysique-s2.md`** — numéro suivant dans la séquence.
Doit couvrir : contexte, périmètre in/out, décisions avec justification,
schéma de la table de fenêtres, schéma de la table de correction de biais,
règles de gating avec valeurs de seuil proposées, mapping vers les sept
indicateurs, signatures R proposées, cas limites, tests d'acceptation,
questions ouvertes.

**B. `ADR-012`** — amende l'ADR-011. Format identique aux ADR existants.
Doit traiter explicitement le fait que `augmented` devient multi-valué
(cumul CHM + biophysique) et les conséquences sur `nemetonshiny`, les exports
GeoPackage et l'affichage radar.

**C. Note de cadrage du package amont** — périmètre de `biophysnemeton`,
frontière exacte avec nemeton, interface publique, et arbitrage `theia2r`
contre accès STAC direct avec recommandation motivée.

## Forme attendue d'une section de décision

> ### D2 — Médiane, non maximum
>
> Le composite retenu par unité et par variable est la médiane des
> observations valides de la fenêtre.
>
> *Justification.* Le maximum est biaisé à la hausse par toute observation
> résiduellement contaminée, et ce biais croît avec `n_obs` : deux unités
> couvertes 6 et 25 fois ne sont plus comparables. La médiane est robuste et
> son espérance ne dépend pas de la taille de l'échantillon.
>
> *Conséquence.* `n_obs` est conservé comme métrique de qualité et sert au
> gating, jamais comme facteur correctif.

Chaque décision suit ce triptyque : énoncé, justification, conséquence. Pas
de décision sans justification traçable.

## Contraintes

- Deux tests sont non négociables et doivent figurer en tête des critères
  d'acceptation : (a) golden values SL2P à 1e-4 contre des pixels traités
  indépendamment dans SNAP Desktop, par plateforme et par variable — sans
  quoi une erreur de signe dans les poids reste indétectable ; (b) invariance
  du composite au nombre d'observations, qui contrôle D5.
- Toute valeur de seuil que tu proposes doit être annoncée comme à calibrer,
  avec l'ordre de grandeur attendu et la méthode de calibration.
- Aucune valeur de table de référence inventée. Si une donnée doit être
  sourcée, écris le schéma et laisse la valeur à sourcer, explicitement.
- Signale au passage l'incohérence entre « 31 indicateurs » et « 29
  sous-indicateurs » dans le README et la description du dépôt, sans la
  corriger toi-même.

## Comportement attendu

- **Challenge, ne suis pas aveuglément.** Si une décision de la liste est
  incompatible avec le code réel, dis-le avant de rédiger. Si tu vois un
  meilleur découpage, propose-le en une fois, argumenté, puis exécute selon la
  décision retenue.
- **Avance plutôt que de demander.** Face à une ambiguïté, prends l'hypothèse
  la plus plausible, marque-la `> HYPOTHÈSE :` dans le document, et continue.
  Ne pose de question bloquante que si elle empêche réellement d'écrire.
- **Livre d'abord, explique ensuite.** Les trois documents, puis un résumé de
  dix lignes maximum : écarts constatés, hypothèses posées, risques.
- Ton technique et direct. Pas de remplissage, pas de reformulation de
  l'évidence.

---

Avant de commencer, prends le temps de lire réellement le code et les
documents existants, et de réfléchir à la manière dont ces variables
s'insèrent dans le système NDP sans en dégrader la cohérence. La qualité de
ces specs détermine entièrement celle de l'implémentation qui suivra.
