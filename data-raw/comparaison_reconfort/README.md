# Comparer les deux méthodes RECONFORT (mission 071)

IOTA² reste la méthode qui produit la carte. Ce dossier compare, sur ton poste
(conda RECONFORT, compte GEODES, clés THEIA `TLD_ACCESS_KEY` / `TLD_SECRET_KEY`
dans `.Renviron`), ce que la session cloud ne peut pas faire. Sorties hors dépôt.

## a) Archive contre fenêtre (mêmes scènes, même zone)

```bash
cd ~/dev/nemeton
Rscript -e 'pkgload::load_all(".")' -e 'source("data-raw/comparaison_reconfort/comparer_acquisitions.R"); comparer_acquisitions("zone.gpkg", "T31TCN", "2023-06-10", "2023-06-30", "~/tmp/cmp071")'
```

(`zone.gpkg` : le contour de la zone ; une tuile et trois semaines suffisent.)
Rend `resume.csv` (durées, octets reçus, volume annoncé des archives, fichiers
identiques, écart maximal) et `comparaison.csv` (un fichier par ligne : grille,
type, écart). Attendu : `conforme = TRUE`, `ecart_max = 0`. Les fichiers de
l'archive que le catalogue STAC n'expose pas (DFP, IAB, WGT…) sont listés
« seulement archive » : à confirmer que IOTA² n'en a pas besoin (lancer la chaîne
une fois sur chaque voie, `acquisition = "archive"` puis `"fenetre"`).

## b) Carte IOTA² contre carte du spike

```bash
Rscript data-raw/comparaison_reconfort/comparer_cartes.R \
  carte_iota2.tif carte_spike.tif ~/tmp/cmp071_cartes 5400 120
```

`carte_iota2.tif` : `rasters$classif_masked` rendu par `run_reconfort_dieback()`.
`carte_spike.tif` : carte de classes 1 à 3 du spike, produite par
`reconfort_carte_spike()` (mission 076, voir la section c ci-dessous). Les deux nombres
sont les durées en secondes. Rend la matrice de confusion (lignes IOTA², colonnes
spike), l'accord global, le kappa (indicateur seulement), rappel et précision par
classe, les surfaces par classe en ha.

## c) Produire la carte du spike sur la grille IOTA² (mission 076)

```bash
cd ~/dev/nemeton
Rscript data-raw/comparaison_reconfort/carte_spike.R \
  modele.rds ~/tmp/scenes/extracted 2023 carte_iota2.tif ~/tmp/cmp076 \
  [chenaie.tif] [coupes.tif] [duree_iota2_s]
```

- `modele.rds` : `saveRDS(reconfort_entrainer(...), "modele.rds")` (un `reconfort_modele`).
- Dossier des scènes : celui des voies archive et fenêtre (`extracted/<tuile>/<scène>/`,
  bandes `*_FRE_B*.tif` et `MASKS/`), cherché récursivement ; seules les scènes de
  l'année demandée servent.
- `carte_iota2.tif` : la carte IOTA² de la **même zone et de la même année** ; elle sert
  de gabarit (CRS, origine, résolution, étendue de la carte du spike). Sa grille doit
  être celle des scènes (même CRS, même résolution que B04, décalage d'un nombre entier de
  pixels) ; un CRS, une résolution ou un décalage différents sont **refusés** (le calcul
  ne serait plus au pixel). Seules les bandes à 20 m sont rééchantillonnées (bilinéaire)
  vers la grille 10 m ; non vérifié contre IOTA² lui-même. `reprojeter = TRUE` (argument
  de `reconfort_carte_spike()`, pas du script) accepte l'écart avec un avertissement.
- Masques MAJA : CLM, SAT, EDG (toute valeur non nulle est masquée), puis indices, puis
  les 36 pas de 10 jours, comme `reconfort_predire()`. `chenaie.tif` et `coupes.tif`
  (YYDDD) facultatifs : `NA` hors chênaie et à partir de l'année de coupe.
- Sorties : `carte_spike_<année>.tif`, puis celles de la section b (`confusion.csv`,
  `par_classe.csv`, `resume.csv`) et `LIRE_AVANT_DE_CONCLURE.txt`.
- **Durée** : le calcul passe par la table de caractéristiques du spike (réutilisée, non
  réécrite), pixel par pixel. Mesuré en session sur données synthétiques : environ
  0,6 ms par pixel pour 36 dates, soit de l'ordre de 10 minutes par million de pixels,
  **hors lecture des rasters** (non mesurée sur scènes MUSCATE réelles). La mémoire reste
  bornée par blocs de lignes : le nombre de pixels d'un bloc est le budget mémoire de la
  chaîne divisé par le nombre de scènes de l'année (plafond 7,2·10⁶ pixels × scènes,
  soit 2·10⁵ pixels pour 36 scènes).

> **À lire avant de conclure.** Tant que le modèle n'est entraîné que sur des étiquettes
> `synth_` ou propagées, l'accord avec IOTA² mesure une **ressemblance** entre deux
> méthodes, pas une **justesse**. La règle reste la spec 070 (« Critère pour amender la
> spec 021 ») : des placettes de terrain tenues à l'écart.

## Lancer le run complet par fenêtre

`run_reconfort_dieback(..., acquisition = "fenetre")` (défaut ; sans clés THEIA et
sans argument explicite, repli sur `"archive"` avec un avertissement).
