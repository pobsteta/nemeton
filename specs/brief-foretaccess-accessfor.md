# Brief `foretaccess` — Valider les moteurs d'accessibilité contre ACCESSFOR (IGN)

> **Destinataire** : session dédiée `/home/pascal/dev/foretaccess`.
> **Émetteur** : session `nemeton` (règle #11 : je ne touche pas aux repos frères).
> **Origine** : trouvaille de reconnaissance faite en cadrant la spec 040
> (`specs/040-volume-mobilisable-desserte/spec.md` §12), le 2026-07-22.
> **But** : disposer d'une **référence externe officielle** pour valider
> `skidder()` / `porteur()` / `classes_debardage()`, et éventuellement d'un
> **repli** face au blocage perf du brief desserte (692 s sur 30 parcelles).

## 1. La couche

L'IGN publie en WFS une cartographie nationale de l'accessibilité forestière :

```
endpoint : https://data.geopf.fr/wfs/ows          (WFS 2.0.0)
couches  : IGNF_ACCESSIBILITE-PHYSIQUE-FORETS-:acces_skidder
           IGNF_ACCESSIBILITE-PHYSIQUE-FORETS-:acces_porteur
variante : IGNF_ACCESSIBILITE-PHYSIQUE-FORETS-MASQUE-FORETV3:acces_skidder
           IGNF_ACCESSIBILITE-PHYSIQUE-FORETS-MASQUE-FORETV3:acces_porteur
```

> « Cartographie de l'accessibilité physique des forêts aux engins
> d'exploitation, produite par l'IGN à partir de la méthodologie développée dans
> le cadre du projet **ACCESSFOR**. […] Édition **2025-01-01** »
> Mots-clés : forêts, **porteur**, **skidder**, accessibilité forestière.

**Schéma** (`DescribeFeatureType`, vérifié) — c'est du **vecteur polygonal**, pas
du raster :

| attribut | type | contenu |
|---|---|---|
| `class` | long | code de classe |
| `cat` | string | libellé de la classe |
| `dep` | string | code département |
| `geom` | gml:Surface | polygone |

## 2. Le point important — les bandes de débardage coïncident

Échantillon `GetFeature` (COUNT=200, départements 01/08/09), valeurs observées :

| `class` | `cat` |
|---|---|
| 1 | Inaccessible |
| 3 | Accessible - Classe de débardage 1 : **0 - 250 m** |
| 4 | Accessible - Classe de débardage 2 : **250 - 500 m** |
| 5 | Accessible - Classe de débardage 3 : **500 - 1000 m** |
| 6 | Accessible - Classe de débardage 4 : **1000 - 1500 m** |

À comparer aux bandes par défaut de `classes_debardage()`
(`config$skidder$classes_distance_m`, cf. `R/skidder.R:795-860`) :
**0-250, 250-500, 500-1000, 1000-1500, 1500-2000, > 2000**, plus
`inaccessible`, `inexploitable`, `hors_foret`.

**Les quatre premières bornes sont identiques.** Les deux produits descendent
vraisemblablement de la même filiation Sylvaccess. La comparaison est donc
quasi terme à terme sur les bandes 1-4 — c'est ce qui rend cette validation
intéressante plutôt qu'anecdotique.

**Le bon candidat à comparer est `classes_debardage()`**, pas le raster 4 classes
de `skidder()` (`parcourable` / `accessible` / `non_accessible` / `hors_foret`),
qui ne porte pas de bande de distance.

## 3. À élucider avant tout chiffre

1. **`class = 2` n'apparaît pas** dans l'échantillon (200 features, 3 départements).
   Reste à énumérer, ainsi que d'éventuelles classes ≥ 7. Refaire un `GetFeature`
   sur le **département cible** (48 pour Chastel-Nouvel) plutôt que sur un
   échantillon national.
2. **ACCESSFOR semble s'arrêter à 1500 m** là où `classes_debardage()` va jusqu'à
   `> 2000`. À confirmer : si ACCESSFOR n'a pas de bande au-delà, il faut décider
   si l'on replie les bandes 5-6 de `foretaccess` sur « au-delà » ou si l'on
   tronque la comparaison à 1500 m.
3. **Table de correspondance explicite** `class` ACCESSFOR ↔ `classe`
   `classes_debardage()`, écrite et testée. Ne pas comparer sur des libellés.

## 4. Les deux pièges qui fausseraient la comparaison

**(a) Le masque forêt n'est pas le même.** ACCESSFOR existe en deux variantes
(défaut et `MASQUE-FORETV3`), et le pipeline app (`run_accessibility()`) utilise
**BD Forêt V2**. Trois masques différents ⇒ la classe `hors_foret` divergera *par
construction*, et tout écart global sera dominé par cet artefact.
→ Ne comparer **que sur l'intersection des masques**, et rapporter séparément la
surface exclue de la comparaison.

**(b) Vecteur → raster, catégoriel.** ACCESSFOR est polygonal, `foretaccess`
travaille sur une grille 5 m. Il faut rasteriser ACCESSFOR **sur la grille exacte
de `pre`**, en **plus proche voisin** (`method = "near"`). Une interpolation
bilinéaire sur un code de classe fabrique des classes intermédiaires qui
n'existent pas — le piège a déjà mordu deux fois sur ce projet (rendu bivarié
E-OBS côté app). Vérifier après rasterisation que l'ensemble des valeurs obtenues
est exactement l'ensemble des codes d'entrée.

## 5. Livrable suggéré

Une fonction de comparaison dans `foretaccess`, ou un simple script `data-raw/` :

- entrée : une AOI (Chastel-Nouvel, 30 parcelles, déjà instrumentée), le résultat
  `classes_debardage()`, la couche ACCESSFOR du département ;
- sortie : **matrice de confusion** classe × classe sur l'intersection des
  masques, surface par cellule, accord global, et accord « bandes agrégées »
  (accessible / inaccessible) qui est le chiffre robuste ;
- lecture : un désaccord fort sur les bandes lointaines est attendu (paramétrage
  d'engin, desserte de référence) ; un désaccord sur `accessible` vs
  `inaccessible` est un signal à instruire.

## 6. Usage « repli », à trancher séparément

Le brief desserte signale un glouton à **692 s sur 30 parcelles** et des moteurs
Steiner/optimiseurs intraitables. ACCESSFOR étant national, servi et déjà calculé,
il pourrait alimenter un **mode dégradé** (« accessibilité de référence IGN »)
quand le calcul local est hors budget.

Réserves à peser avant de s'y engager : édition **2025-01-01** figée (pas de
desserte projetée, pas de scénario), paramétrage d'engin non maîtrisé, et surtout
**cela ne répond pas au besoin de conception** (créer de la desserte) — seulement
au besoin de constat. À considérer comme complément, pas comme substitut.

## 7. Ce qui reste hors de ce brief

- La perf des moteurs et la sémantique de `connexe` : brief desserte séparé
  (`brief-desserte-perf-connexite.md`, session app).
- Le couplage volume P1 → `volume_champ` : `nemeton`, spec 040. Sans rapport avec
  ACCESSFOR, sinon que la trouvaille vient de la même reconnaissance.
