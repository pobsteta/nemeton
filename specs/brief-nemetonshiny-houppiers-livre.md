# Brief `nemetonshiny` — `segment_houppiers()` est livré (cœur v0.184.0)

**Cœur requis** : `nemeton (>= 0.184.0)`.
**Portée app** : appeler et écrire. Aucun calcul.
**Répond à** : `BRIEF-nemeton-houppiers-mnh.md` / §2 du rattrapage 2026-08-23.

## Ce qui est disponible

```r
segment_houppiers(chm, aoi = NULL, ws = 5, hmin = 5,
                  algorithme = c("dalponte", "silva", "watershed"),
                  resolution = 0.5, max_cells = 2e7, h_range = c(1, 70))
```

Rend un `sf` POLYGON : `houppier_id`, **`h_max`** (mètres), `surface_m2`,
trié par hauteur décroissante.

Les trois contraintes de l'aval sont tenues **par le cœur**, l'app n'a rien à
filtrer : rien hors 1-70 m n'est produit, les recouvrements sont admis, aucun
repli sur le houppier le plus proche.

## Le câblage

1. plancher `Imports: nemeton (>= 0.184.0)` ;
2. `service_marculus.R` écrit la couche sous le nom **exact** `houppier` ;
3. passer par `run_memory_capped()` comme les autres travaux lourds.

**Sur le point 3, une mesure qui change peut-être votre arbitrage** : sur le MNH
de Couchey, la dalle entière (36,4 ha, 11,9 M de cellules) donne 2 046 houppiers
en **11 s** avec un pic R de **~670 Mo**, soit ~4 % du plafond. Une fois la
résolution bornée à 0,5 m par le cœur, ce n'est pas un travail lourd. Le plafond
reste une bonne hygiène — mais si le passage par un processus enfant vous coûte
de la complexité (sérialisation de l'AOI, progression), sachez que le budget
mémoire ne l'impose pas ici, contrairement à FORDEAD ou reGénération.

## Ce qui a été validé, et ce qui ne l'a pas été

**Validé sur le vrai MNH** (`opencanopynemeton/outputs/chm_predicted_0_2m.tif`) :

| Emprise | Houppiers | Densité | `h_max` médian | Diam. équiv. médian |
|---|---|---|---|---|
| 4 ha | 266 | 66/ha | 20,0 m | 9,1 m |
| 36,4 ha | 2 046 | 56/ha | 24,0 m | — |

**Non validé** : la concordance avec un martelage réel. Personne n'a encore
vérifié qu'une tige pointée au GNSS tombe dans *son* houppier. C'est le seul
contrôle qui compte vraiment pour l'usage, et il demande une sortie terrain —
à ne pas cocher sur la foi des chiffres ci-dessus.

**Deux réglages à exposer ou pas, à votre main** : `ws` (fenêtre de recherche,
5 m par défaut) et `hmin` (apex minimal, 5 m) dépendent du peuplement. Un
taillis dense et une futaie de chênes ne veulent pas le même `ws`. Si vous les
laissez fixes, dites-le dans l'interface plutôt que de laisser croire à un
réglage automatique.

## Un défaut corrigé côté cœur qui vous concerne

Le MNH de Couchey porte le **nom** « EPSG:2154 » sans bloc d'autorité :
`sf::st_crs(x)$epsg` y lit `NA`. Écrite telle quelle, la couche serait partie
avec un CRS que le téléphone ne sait pas rattacher. Le cœur re-tamponne
désormais. **Si l'app écrit d'autres couches depuis ce même MNH** (ou depuis
tout raster caché), vérifiez leur CRS de sortie : le défaut est dans les
fichiers, pas dans la fonction qui les lit.
