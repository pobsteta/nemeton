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
`carte_spike.tif` : carte de classes 1 à 3 du spike (le spike s'arrête aux tables
de séries : la carte vient de la chaîne image de la mission 060). Les deux nombres
sont les durées en secondes. Rend la matrice de confusion (lignes IOTA², colonnes
spike), l'accord global, le kappa (indicateur seulement), rappel et précision par
classe, les surfaces par classe en ha.

## Lancer le run complet par fenêtre

`run_reconfort_dieback(..., acquisition = "fenetre")` (défaut ; sans clés THEIA et
sans argument explicite, repli sur `"archive"` avec un avertissement).
