# Brief `nemetonshiny` — B4/L3 changent d'échelle et de sens (cœur v0.190.0)

> **Émis le 2026-08-27** par la session `nemeton`.
> **Nature** : notification. **Aucun code app à écrire** — sauf le point 4,
> qui est une question, pas une demande.
> **Dépend de** : `nemeton >= 0.190.0`. Spec 028 §10.

---

## 1. Ce qui s'est passé

La spec 028 réclamait depuis le 2026-07-01 un « smoke réel sur scène
Sentinel-2 » avant de figer les bornes de normalisation B4/L3. **Ce run
existait déjà** : c'est l'app qui l'avait produit le 2026-07-02 dans
`projects/20260624_073705_armn/cache/layers/spectral/S2A_MSIL2A_20170814…/`.
Il n'a pas fallu le refaire — `reuse_existing` l'a rendu tel quel.

Trois défauts en sont sortis, tous côté cœur, tous corrigés en v0.190.0 :

1. **B4 lisait `shannon_sd.tiff` au lieu de `shannon_mean.tiff`.** La sélection
   départageait par longueur de nom, et le fichier d'écart-type est plus court
   de deux caractères. *Le commentaire de `build_spectral_diversity()` dans
   `service_compute.R` cite d'ailleurs `shannon_sd.tiff` — le nom était sous
   les yeux des deux sessions depuis le début.*
2. **L3 moyennait les 3 axes PCoA de `beta.tiff`** — des coordonnées signées
   centrées sur zéro. 16 UGF sur 30 sortaient à exactement 0. L3 est désormais
   une **dispersion** autour du centroïde de l'unité.
3. **Les deux bornes de normalisation étaient hors d'atteinte** (`log(50)` et
   `1.0`). Refaites sur mesures : `[0, log(10)]` et `[0, 0.5]`.

## 2. Ce que ça change pour l'app — rien à coder

- **Les rasters en cache restent valides.** `beta.tiff` et `shannon_mean.tiff`
  sont inchangés : seule leur *lecture* change. **Aucun recalcul biodivMapR
  n'est nécessaire**, et `reuse_existing` continue de les rendre.
- **Les scores B4 et L3 vont bouger, beaucoup**, sur tout projet déjà calculé :

  | | avant | après |
  |---|---|---|
  | B4, étendue sur les 30 UGF | 3,5 → 5,4 | **12,5 → 67,4** |
  | L3, UGF à exactement 0 | 16 / 30 | **0** |
  | L3, étendue | 0 → 20,0 | **12,9 → 87,9** |

  Les familles B et L bougent donc aussi, et l'indice général avec elles. Ce
  n'est pas une régression : c'est la correction d'indicateurs qui ne mesuraient
  pas ce qu'ils annonçaient.
- **Les tooltips sont mis à jour au cœur** (`INDICATOR_FAMILIES`), donc chez
  vous sans rien toucher — la leçon de la v0.189.1 appliquée en amont cette
  fois. Ils nomment maintenant la grandeur *et* son échelle.
- **`indicateur_l3_het_spectrale()` gagne `min_windows = 3L`** : une UGF
  couvrant moins de trois fenêtres de 100 m sort en `NA` au lieu d'une valeur
  fabriquée. Sur le projet de référence cela concerne **1 UGF sur 30** (2,1 ha).
  L'affichage doit donc tolérer un `NA` sur L3 — ce qu'il fait déjà pour les
  autres indicateurs conditionnels, mais autant le dire.

## 3. Ce qui reste ouvert, et qu'il ne faut pas surestimer

Les deux bornes sont calibrées sur **une seule scène et un seul massif**. Elles
sont honnêtes sur l'amplitude que le pipeline produit, muettes sur la diversité
du domaine forestier français. **D3 reste ouverte** dans la spec 028. Si un
utilisateur trouve les scores B4 systématiquement bas sur un autre massif, c'est
une donnée utile, pas un bug : elle est attendue et le run de référence est
consigné (spec 028 §10) pour rendre la comparaison possible.

## 4. Une question, pas une demande

`build_reflectance_stack()` lit **7 bandes** (B02, B04, B05, B08, B8A, B11,
B12) mais l'espace de k-means du run n'en porte que **6** : `B02` est absente,
remplacée par une variable `ID` — inerte (0,0 % de la variance inter-centroïdes,
vérifié), donc sans effet sur les résultats. Deux lectures possibles : soit
biodivMapR écarte B02 lui-même, soit un décalage de nommage fait perdre une
bande utile. **Ni l'une ni l'autre n'est vérifiable depuis le cœur** — le cube
est assemblé chez vous. Si quelqu'un passe par là, la réponse vaut d'être notée
dans la spec 028 §10.4 ; ce n'est pas bloquant.
