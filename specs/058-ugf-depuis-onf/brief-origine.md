# BRIEF `nemeton` — Construire les UGF d'une forêt publique à partir du parcellaire ONF calé sur le cadastre

> **Statut** : ouvert, 2026-10-08.
> **Émetteur** : session `nemetonclaude`, sur règles énoncées et validées par
> Pascal le 2026-10-07/08.
> **Dépôt concerné** : `nemeton` — `R/croiser_parcelles_onf.R`,
> `R/load_onf_parcelles.R`, et une nouvelle source de données (DGFiP).
> **Nature** : évolution. Nouvelle fonction (ou nouveau mode) ; le
> comportement actuel de `croiser_parcelles_onf()` n'est pas un défaut.
> **Brief lié** : `vers-nemetonshiny/2026-10-08-ugf-depuis-onf.md` (stockage
> du n° ONF dans les UGF, intégration dans l'app, API d'écriture des UGF).
> **Prototype** : scripts jetables, données et carte dans
> `vers-nemeton/2026-10-08-ugf-depuis-onf-prototype/` (voir § 6).

## 1. Besoin

Affecter automatiquement les numéros de parcelles forestières ONF aux UGF.
Règle de Pascal :

> Les parcelles forestières ne sont qu'une partition des parcelles cadastrales.
> On part **toujours des parcelles cadastrales**, qu'on agrège et qu'on coupe
> pour obtenir les UGF. Le cadastre n'est **jamais déformé** ; c'est la couche
> ONF, qui déborde, qu'il faut ajuster.

Ce brief ajoute un chemin **« depuis la forêt »**. On ne part plus d'une
sélection de parcelles faite par l'utilisateur (`parcels.gpkg` du projet), mais
du contour de la forêt ONF. Le cœur doit trouver lui-même les parcelles
cadastrales qui relèvent de la forêt, puis les découper en UGF portant chacune
un n° de parcelle forestière.

## 2. Constat sur Couchey (21200)

| Mesure | Valeur |
|---|---|
| Parcelles ONF touchant le projet (`load_onf_parcelles_source`) | 81, 647,17 ha |
| Écart médian entre le contour ONF et la limite cadastrale | ~10 m (p90 ~40 m) |
| Meilleure translation globale de l'ONF | (−2, −7) m, gain ≈ 1 ha → le décalage est **local** |
| Croisement actuel (`caler_sur_cadastre`, `rattacher_reste`) sur les 23 parcelles du projet | 77 UGF, 142 tènements, 15/23 parcelles coupées, **56 tènements < 0,5 ha** |

Le croisement actuel a deux défauts :
- **Débordements.** Il découpe sur les débordements ONF, d'où les liserés de
  15 à 60 m le long des limites cadastrales.
- **Sélection.** Il ne sait pas quelles parcelles cadastrales relèvent de la
  forêt. Il prend la sélection de l'utilisateur et rattache tout le reste, y
  compris des blocs de 23 ha qui ne relèvent pas du régime forestier (A 283).

## 3. Algorithme retenu (validé sur Couchey)

Toutes les étapes se font en Lambert 93, à la précision du centimètre
(`st_set_precision(x, 100)` puis `st_make_valid`).

### 3.1 Parcelles cadastrales candidates
1. Charger les parcelles ONF : `load_onf_parcelles_source(aoi)`.
2. Télécharger les parcelles cadastrales (PCI IGN,
   `CADASTRALPARCELS.PARCELLAIRE_EXPRESS:parcelle`, prédicat
   `happign::intersects()`) qui **touchent l'union des parcelles ONF**.
3. Restreindre à la **commune du projet** (`code_insee`). Sur Couchey, l'ONF
   touche 6 communes et 138 parcelles ; on en garde 63 pour 21200.

### 3.2 Calage élastique de l'ONF sur le cadastre (*rubber-sheeting*)
On calcule un champ de déplacement, puis on l'applique à toute la couche ONF.
Le cadastre ne bouge pas.

1. **Points de contrôle.**
   - On échantillonne tous les 5 m (`pas`) le **contour extérieur de l'union
     des parcelles ONF**.
   - On apparie chaque point au point le plus proche des **limites des
     parcelles cadastrales candidates**, c'est-à-dire de toutes leurs limites.
   - On garde la paire si l'écart est inférieur à `dmax` = **80 m**.
   - Couchey : 7 685 points, écart médian 8,9 m, p90 39,7 m.
2. **Champ de déplacement.** En chaque sommet ONF, le déplacement est la moyenne
   pondérée en 1/d² des `k` = 12 vecteurs de contrôle les plus proches. Un
   poids nul de 1/`rayon`² (`rayon` = **200 m**) amortit le déplacement loin
   des points de contrôle.
3. **Application.**
   - Densifier les parcelles ONF (`st_segmentize`, 5 m).
   - Déplacer **tous** les sommets, limites intérieures comprises. Deux parcelles
     ONF voisines partagent leurs sommets, donc la partition ONF reste cohérente.
   - Puis appliquer `st_simplify(dTolerance = 1)` et `st_make_valid`.

   **La simplification est indispensable** : sans elle, la couche passe de
   2 272 à 25 000 sommets et le découpage dure plus de 10 minutes au lieu de
   quelques minutes.
4. **Chevauchements ONF résiduels.** On les résout par `st_difference(onf)`,
   avec la plus grande parcelle en premier.

### 3.3 Sélection des parcelles cadastrales de la forêt
Une parcelle candidate relève de la forêt si elle remplit les deux conditions :
- elle appartient à une **personne publique** (commune, État, département,
  établissement public) d'après le **fichier DGFiP des parcelles des personnes
  morales** (§ 4) ;
- l'**ONF calée** la couvre à **au moins 50 %**.

Aucune des deux conditions ne suffit seule. Mesures à Couchey :

| Parcelle | Propriétaire | Nature | Couverture ONF calée | Verdict |
|---|---|---|---|---|
| A 5 (57 ha) | commune | landes, taillis | 3 % | hors forêt (pas le régime forestier) |
| A 277 (22 ha) | commune | landes | 3 % | hors forêt |
| A 283 (25 ha) | commune | taillis, landes | 2 % | hors forêt |
| A 12 (3,4 ha) | commune | **landes** | 100 % | **forêt** (« bois » ne suffit pas) |
| AO 18 (0,04 ha) | **privé** (absente du fichier) | — | 56 % | hors forêt (débordement ONF) |

Couchey : **19 parcelles, 493,79 ha**. Les 17 parcelles forestières du projet
en font toutes partie. S'y ajoutent A 24 et A 290 (communales). En sortent A 283,
A 9, A 286, AO 212, A 291 et AO 220 (communales mais hors du régime forestier).

> Ni le PCI ni le cadastre Etalab ne portent l'information « relève du régime
> forestier ». La source officielle est l'arrêté préfectoral d'application, qui
> n'est pas ouvert parcelle par parcelle. Le croisement DGFiP × ONF calée en
> est une approximation. À documenter comme telle.

### 3.4 Découpage par accrochage (ouverture morphologique)
Pour chaque parcelle cadastrale retenue :
1. **Morceaux bruts.** Intersection avec chaque parcelle ONF calée, plus la
   partie non couverte, étiquetée `cad~<idu>`.
2. **Cœur de chaque morceau.** `buffer(−r)` puis `buffer(+r)`, découpé par la
   parcelle :
   - `r = tol/2` pour un morceau ONF, avec `tol` = **15 m** ;
   - `r = larg_hors/2` pour un morceau `cad~`, avec `larg_hors` = **50 m**.
     On écarte un cœur `cad~` de moins de `ha_hors` = **0,5 ha**.
3. **Bandes.** Bandes = parcelle − union des cœurs. Chaque bande rejoint le
   cœur avec lequel elle partage la **plus longue limite**. Repli pour une bande
   isolée : le morceau brut qui la recouvre le plus.
4. **Parties détachées de moins de 500 m².** Elles rejoignent le voisin de plus
   longue limite dans la même parcelle (3 passes).

Effet : une limite ONF à moins de 15 m d'une limite cadastrale est
**accrochée** sur celle-ci. Une parcelle n'est coupée que là où la limite ONF
s'en écarte vraiment.

### 3.5 Rattachements finaux (sur l'ensemble des tènements)
Deux morceaux sont **voisins** s'ils partagent au moins 1 m de limite, mesuré à
10 cm près (`st_buffer(0.1)`). Les morceaux ne partagent pas exactement leurs
sommets : `st_relate("F***1****")` ne trouvait presque aucun voisin. Un contact
ponctuel n'est pas un voisinage.

1. **Morceau ONF de moins de 0,5 ha** (`seuil`) dont tous les voisins d'une
   autre UGF appartiennent à **une seule** UGF, et qui ne touche pas sa propre
   UGF : il passe dans cette UGF. On itère, avec au plus 5 passes.
2. **Morceau hors ONF (`cad~`) de moins de 1 ha** (`seuil_hors`) : il rejoint
   le voisin de **plus longue limite**. Couchey : le reste d'A 36 (0,66 ha) va
   à F22161I-33.
3. **UGF entière de moins de 0,5 ha** : chacun de ses morceaux rejoint le
   voisin, d'une autre UGF, de **plus longue limite**. Couchey : F21866Z-10
   (0,36 ha) va à F22161I-24, et F21866Z-7 (0,13 ha) à F21866Z-39.

Après chaque passe, on regroupe les morceaux d'une même parcelle devenus de la
même UGF.

### 3.6 Résultat sur Couchey

| | Croisement actuel (23 parcelles projet) | Algorithme retenu |
|---|---|---|
| Parcelles cadastrales | 23 (sélection utilisateur) | 19 (DGFiP × ONF calée) |
| Surface | 530,19 ha | 493,79 ha |
| UGF | 77 | **63** |
| UGF hors ONF | 3 | **0** |
| Tènements | 142 | **85** |
| Parcelles coupées | 15 / 23 | **9 / 19** |
| Plus petite UGF | < 0,05 ha | **2,11 ha** |
| Pavage | exact | exact (écart 0,003 ha = arrondi au cm) |

Étapes intermédiaires mesurées (projet à 23 parcelles, pour comparaison) :

| Variante | UGF | hors ONF | tènements < 0,5 ha |
|---|---|---|---|
| Accrochage seul, tol 15 m | 71 | 7 (39,7 ha) | 8 |
| Calage du contour + accrochage | 72 | 6 (33,1 ha) | 12 |

Le calage ramène le liseré d'A 36 de 5,26 à 0,66 ha.

## 4. Nouvelle source : parcelles des personnes morales (DGFiP)

- **Jeu de données :** data.gouv.fr, « Fichiers des locaux et des parcelles des
  personnes morales (version unifiée) ». Fichier
  `parcelles_personnes_morales_latest.parquet` (millésime 2025, **376 Mo**,
  national).
  URL utilisée :
  `https://static.data.gouv.fr/resources/fichiers-des-locaux-et-des-parcelles-des-personnes-morales-version-unifiee/20251103-131324/parcelles-personnes-morales-latest.parquet`
  (l'URL change à chaque publication : la résoudre par l'API data.gouv.fr,
  jeu `6900772ca5c4fa6c5687b3bd`).
- **Colonnes utiles :**
  - `departement`, `code_commune`, `prefixe`, `section`, `numero_parcelle`
    servent à reconstruire l'IDU ;
  - `groupe_personne_libelle` (commune, État, département, établissements
    publics…) et `denomination` donnent le propriétaire ;
  - `subdivision_fiscale`, `contenance_subdivision_centiare`,
    `nature_culture_libelle` décrivent les subdivisions fiscales.

  Il y a une ligne par subdivision fiscale et par droit.
- **IDU** = `21` + `code_commune` (3 car.) + `prefixe` (`000` si vide) +
  `section` complétée à 2 caractères par un `0` à gauche (`A` → `0A`, `AO`
  inchangé) + `numero_parcelle` sur 4 chiffres. On le vérifie contre le PCI :
  les 33 parcelles de Couchey présentes dans le fichier ont été appariées.
- **Une parcelle absente du fichier appartient à une personne physique**, donc
  elle est privée.
- **Lecture.** Avec `arrow::open_dataset()`, puis un filtre `departement` /
  `code_commune` : 831 lignes pour Couchey. Pas besoin de duckdb.
- **À décider :**
  - **Téléchargement.** Faut-il garder une copie en cache partagé
    (`tools::R_user_dir("nemeton", "cache")`) avec un extrait par département,
    ou trouver une API par commune ? Je n'en ai pas trouvé.
  - **Signature d'un chargeur**, par exemple
    `load_parcelles_personnes_morales(insee)`, sur le modèle des autres
    `load_*_source`.

## 5. Ce qui est attendu

1. **Une fonction du cœur** (nom à choisir), par exemple
   `construire_ugf_onf(aoi | insee, parcelles_onf = NULL, ...)`, qui enchaîne
   les § 3.1 à 3.5. Elle rend un `sf` de tènements avec au minimum :
   - `idu` (parcelle cadastrale parente) ;
   - `ugf_id` (`<foret_id>-<parcelle>` ou `cad~<idu>`) ;
   - `foret_id`, `foret_nom`, `parcelle`, `domaniale` (repris de la parcelle
     ONF) ;
   - `surface_m2` ;
   - `part_onf` : part de la surface du tènement couverte par la parcelle ONF
     calée ; c'est une mesure de confiance.

   Elle rend aussi, en attribut ou dans une liste, les parcelles cadastrales
   retenues et écartées avec leur raison (`privee`, `couverture < 50 %`).
2. **Paramètres exposés avec ces valeurs par défaut :**

   | Paramètre | Valeur |
   |---|---|
   | `pas` | 5 m |
   | `dmax` | 80 m |
   | `rayon` | 200 m |
   | `k` | 12 |
   | `seuil_couverture` | 0,5 |
   | `tol` | 15 m |
   | `larg_hors` | 50 m |
   | `ha_hors` | 0,5 ha |
   | `seuil` | 0,5 ha |
   | `seuil_hors` | 1 ha |
   | `min_part_m2` | 500 m² |
3. **Calage réutilisable dans le croisement existant.** Le calage élastique
   (§ 3.2) devrait être une fonction à part, par exemple
   `caler_onf_sur_cadastre(onf, cadastre, dmax, rayon)`. Ainsi
   `croiser_parcelles_onf()` peut l'utiliser quand l'utilisateur garde sa
   propre sélection de parcelles, par exemple avec un argument
   `caler = c("aucun", "parcelle", "elastique")`. Ne pas changer ses valeurs
   par défaut sans le dire (cf. le brief traité
   `2026-08-26-rattachement-reste-voisin.md`).
4. **Tests.**
   - Pavage exact de chaque parcelle retenue (écart < 1 m² par parcelle).
   - Pas de chevauchement.
   - Cadastre non modifié : les sommets des parcelles en sortie sont ceux
     d'entrée.
   - Chaque règle de rattachement, sur un jeu synthétique.
   - IDU DGFiP (préfixe vide, section à 1 et 2 lettres).
   - Parcelle privée écartée.
   - Couchey en test de non-régression hors CRAN : 19 parcelles, 63 UGF,
     plus petite UGF ≥ 2 ha.
5. **Performance.** Le prototype met environ 10 minutes sur Couchey parce qu'il
   boucle en R sur les sommets et répète `st_intersection` par paire. Pistes :
   - vectoriser le champ de déplacement (`FNN`/`nabor` pour les k voisins) ;
   - calculer les longueurs de limite commune en une seule passe
     (`st_intersection` des contours) ;
   - garder la simplification après la déformation.

## 6. Prototype fourni (hors dépôt, jetable)

Le dossier `vers-nemeton/2026-10-08-ugf-depuis-onf-prototype/` contient :

| Fichier | Contenu |
|---|---|
| `caler.R` | § 3.2 ; arguments `gpkg mode dmax rayon`, avec `mode = limites` pour le chemin retenu |
| `accrocher.R` | § 3.4 ; arguments `gpkg tol larg_hors ha_hors` |
| `rattacher.R` | § 3.5 ; arguments `gpkg seuil sortie seuil_hors` |
| `carte_foret.R` | rendu de la carte |
| `couchey_entrees.gpkg` | couches `cadastre` (23 parcelles du projet) et `onf` (81 parcelles brutes) |
| `couchey_onf_calee.gpkg` | ONF calée sur les 63 parcelles candidates |
| `couchey_cadastre_retenu.gpkg` | les 19 parcelles retenues et l'ONF calée |
| `couchey_selection_dgfip.rds` | les 63 candidates avec propriétaire, nature et couverture |
| `couchey_ugf_final.gpkg` | résultat (85 tènements, 63 UGF) |
| `couchey_ugf.png` | carte du résultat |

Ces scripts sont des maquettes. Ils montrent l'enchaînement et les mesures,
pas le code à reprendre tel quel.

## 7. Critères d'acceptation

- [ ] Sur Couchey, la fonction rend 19 parcelles retenues, environ 63 UGF,
      aucune UGF de moins de 0,5 ha et aucune UGF `cad~`. La sortie pave
      exactement les parcelles retenues.
- [ ] Le cadastre n'est jamais déformé ; seule la couche ONF l'est.
- [ ] Chaque tènement porte `foret_id`, `parcelle` et `part_onf`.
- [ ] Les parcelles écartées sont listées avec leur raison.
- [ ] La source DGFiP est documentée comme une approximation du régime forestier.
- [ ] `croiser_parcelles_onf()` garde son contrat par défaut ; le calage
      élastique est une option.
- [ ] NEWS, documentation et tests à jour ; CI verte.
