# Brief `nemetonshiny` — ce que la v0.189.0 change pour vous

**Cœur requis** : `nemeton (>= 0.189.0)`.
**Trois sujets**, dont un qui vous permet de **supprimer du code**, un qui
change une valeur affichée, et un qui explique un échec que vous contourniez.

---

## 1. Vous pouvez supprimer `.onf_rattacher_reste()`

`croiser_parcelles_onf()` sait désormais rattacher le reliquat :

```r
croiser_parcelles_onf(onf, cad, inclure_reste = TRUE, rattacher_reste = TRUE)
```

La règle implémentée est la vôtre, à l'identique : chaque morceau rejoint la
parcelle forestière avec laquelle il partage **la plus longue frontière
commune** ; sans voisin forestier, la parcelle devient **sa propre UGF** nommée
par sa référence cadastrale.

**Le défaut par défaut est `FALSE`, délibérément** : `inclure_reste` promet des
lignes `hors_ugf = TRUE`, et basculer ce défaut annulerait le contrat sans un
mot pour tout appelant. Passez `rattacher_reste = TRUE` explicitement.

**Mesuré sur Couchey** (21 parcelles, parcellaire ONF réel) : plus d'UGF « hors
forêt publique », **529,73 ha conservés au mètre carré**, une UGF de plus — la
parcelle qu'aucune parcelle forestière ne touche.

**Un défaut à connaître, parce qu'il a failli passer** : sur un mélange
POLYGON/MULTIPOLYGON, `sf::st_cast("POLYGON")` ne garde que le **premier**
polygone de chaque multipartie — sans erreur ni avertissement. Ma première
écriture perdait **13,74 ha sur 50,34**. Si votre `.onf_rattacher_reste()`
éclate le reliquat de la même façon, **vérifiez la surface avant de me croire
sur parole** : le passage par MULTIPOLYGON d'abord est obligatoire.

## 2. S3 change de grandeur — un chiffre affiché va bouger

`indicateur_s3_population()` porte désormais une **densité** (hab/km² dans la
couronne de 5 km), plus un effectif. Les effectifs restent disponibles en
`S3_5km`, `S3_10km`, `S3_20km` — ce sont eux qu'un gestionnaire cite dans un
document, gardez-les pour l'affichage détaillé.

**Pourquoi ce n'était pas un choix cosmétique** : l'ancienne normalisation
saturait à 10 000 habitants, or Couchey en compte **46 110 dans 5 km**. Score
100/100 pour une bourgogne rurale — et pour presque toute forêt française.
La borne avait été calibrée sur le placeholder (~8 300), qui n'était qu'une
surface de tampon déguisée.

L'échelle est **logarithmique** : 5 hab/km² → 26, 50 → 57, 100 → 67, 297 → 82,
≥ 1 000 → 100. Sur cinq UGF de Couchey, les scores vont de **53 à 76** —
l'indicateur discrimine enfin à l'intérieur d'un massif.

**À faire côté app** : si un libellé annonce « Population dans un rayon de
10 km », il est faux à deux titres — c'est une densité, et le rayon de
référence est 5 km. La configuration du cœur portait déjà cette incohérence
avant ce changement.

## 3. S3 a besoin d'une grille — sinon il reste `NA`

`load_insee_population_source(aoi)` est exportée : elle télécharge (une fois par
machine, ~52 Mo) et lit le carroyage **INSEE Filosofi 2021**, découpé sur
l'emprise. Cache partagé dans `~/.cache/nemeton/insee/` — **pas** par projet.

Tant que rien ne la branche dans le résolveur de couches, S3 reste `NA` partout.
C'est voulu : depuis la v0.187.0, aucune valeur n'est fabriquée. **Le câblage
vous revient** — même mécanique que `bdforet` ou `roads`.

Licence Ouverte 2.0, attribution INSEE.

## 4. Pour votre contournement des houppiers : la cause est trouvée

Vous passiez « le raster du résolveur tel quel, sans emprise, avec
`max_cells = 5e6` » — le seul chemin que vous aviez mesuré comme fiable.

**La cause réelle était que lidR refuse un raster resté sur disque.** Votre
contournement marchait parce qu'il forçait une agrégation, et que
`terra::aggregate()` matérialise en mémoire. Le cœur matérialise désormais
lui-même : **vous pouvez revenir à un appel normal, avec emprise**, et retirer
le `max_cells` forcé.

Le cas résiduel que vous signaliez — croppé, agrégé, en mémoire, et qui échoue
quand même — **je ne l'ai pas reproduit**, ni sur raster synthétique ni en
dégradant le CRS comme le fait le MNH de Couchey. Il reste ouvert : si vous le
revoyez, le message exact et les dimensions du raster m'aideront.

## Vérification proposée

| Contrôle | Attendu |
|---|---|
| Import CSV + `rattacher_reste = TRUE` | plus d'UGF « hors forêt publique », surface inchangée |
| Rechargement du projet après purge | les parcelles retirées ne réapparaissent pas |
| S3 sans grille INSEE | `NA`, axe masqué, aucun nombre affiché |
| S3 avec grille | densité plausible (10-300 hab/km² en contexte forestier) |
| Houppiers avec emprise, sans `max_cells` forcé | segmentation aboutit |
