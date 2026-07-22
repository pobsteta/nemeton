# Spec 041 — Desserte corrigée LiDAR : largeur mesurée et géométrie recalée

**Version** : 1.0.0
**Date**    : 2026-07-22
**Statut**  : **Cadré + validé sur données réelles** (lots 1-2 exécutés, §10). D1 et D4
tranchées ; lots 3-4 (fonction `desserte_lidar()`, effet sur `places_depot()`) non
implémentés.
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` — `desserte_lidar()`.
**Cible aval** : `foretaccess` — `places_depot()`, `preprocess()`, `reseau_desserte()`,
`potentiel_cable()`, qui consomment la desserte en entrée.
**Cible app**  : `nemetonshiny` — un toggle « NDP 1 : desserte corrigée LiDAR ».
**Origine** : `specs/brief-foretaccess-desserte-lidar.md` (session app, 2026-07-22),
qui se déclare explicitement « feature NDP 1+, donc côté cœur ».

## 1. Objectif

Produire, à partir d'un nuage LiDAR, une desserte **enrichie** (largeur carrossable,
état) et **géométriquement recalée**, au même format que la desserte BD TOPO que
`foretaccess` consomme aujourd'hui. Le gain immédiat est que `places_depot()`
cesse d'être aveugle à la largeur.

C'est une **dérivation de donnée**, donc du métier cœur — même nature que
`sanitize_chm()` ou `extract_h_dom()` (spec 005). `foretaccess` reste seul
propriétaire des moteurs ; `nemeton` lui fournit une meilleure entrée.

## 2. Le problème (mesuré côté app, foretaccess 1.9.0)

`places_depot()` avertit elle-même : *« Aucune largeur mesurée
(largeur / largeur_de_chaussee) : le critère d'accès camion ne rejette rien. »*

Conséquence sur Chastel-Nouvel : **1 877 départs candidats** sur 1 548 tronçons,
moteur câble à **~28 min** (`places_depot` 12,7 + `potentiel_cable` 15,1) et
couverture **optimiste à 91 %** de forêt « câblable ». Une largeur mesurée rend le
critère discriminant.

S'y ajoutent les erreurs de position et les routes disparues de BD TOPO, qui
faussent tous les tracés least-cost.

## 3. Ce que la vérification a corrigé au brief

Trois points du brief ne tiennent pas tels quels, vérifiés le 2026-07-22 :

**(1) L'arbitrage `lidR` vs `lasR` n'existe pas.** Le brief le pose en question
ouverte (« réécrire les métriques sur `lasR` ? tolérer `lidR` en Suggests ? »).
Or `DESCRIPTION` porte **déjà les deux** : `lidR (>= 4.0.0)` et
`lasR (>= 0.10.0)`, en Suggests. `lidR` est donc déjà toléré, et ALSroads —
qui s'appuie sur `lidR` — n'impose aucun portage.

**(2) ALSroads est moins dormant que décrit.** Le brief indique « dernière
release v0.2.0 (2022), maintenance non visible ». Le dépôt a en fait été poussé
le **2024-11-15**, n'est pas archivé. Il reste « experimental », mais l'argument
d'abandon est plus faible qu'annoncé. **Licence : GPL-3** (champ `License` de son
`DESCRIPTION`) — compatible avec `nemeton`, aucune autorisation à demander.

**(3) Le cœur lit déjà des nuages de points.** `pai_depuis_nuage()`
(`R/regen_engines.R`) et `R/lidar_processing.R` ouvrent des tuiles
`.las`/`.laz`/COPC via `lasR`, avec bornage mémoire. La brique d'entrée existe.

## 4. Le vrai manque — l'acquisition, pas la lecture

`nemeton` **n'acquiert pas** les tuiles LiDAR HD. Il n'expose que
`probe_ign_lidar_tile()` / `probe_ign_lidar_tiles()`, des **diagnostics** de
téléchargement — dont la doc dit explicitement que c'est `nemetonshiny` qui
télécharge (« When `nemetonshiny` reports "Tile X/Y: failed" … while NUAGE tiles
succeed »). `inst/datasources/FR.json` ne déclare que `lidar_mnh` / `lidar_mnt` /
`lidar_mns` via happign : des **rasters dérivés**, pas le nuage NUAGE.

**Conséquence de conception** : la fonction prend un **répertoire de tuiles**
fourni par l'appelant, exactement comme `pai_depuis_nuage(dossier_las = )`. Elle
n'acquiert rien. C'est l'idiome établi, et cela évite de dupliquer côté cœur une
acquisition qui vit déjà côté app.

## 5. Fonction

```r
desserte_lidar(
  desserte,                      # sf LINESTRING, sortie d'acquire_desserte() (BD TOPO)
  dossier_las,                   # répertoire de tuiles .las/.laz/.copc.laz
  mnt,                           # SpatRaster
  crs          = 2154,
  etat_conserve = c("existante"), # tronçons retenus en sortie
  cache_dir    = NULL,
  ...
)
```

→ `sf` **au même format que l'entrée**, géométrie recalée, plus les colonnes
`largeur_m`, `largeur_carrossable_m`, `pente_pct`, `etat`
(`existante` / `declassee` / `disparue`).

**Repli explicite** : si `dossier_las` est vide ou ne couvre pas l'emprise, la
fonction renvoie la desserte d'entrée **inchangée** avec `etat = NA` et
avertit — le comportement NDP 0 actuel est préservé, jamais dégradé en silence.

**Provenance** : une colonne `desserte_source` (`"bdtopo"` / `"bdtopo_lidar"`)
par tronçon, sur le principe déjà retenu pour `completer_volume_ifn()` — une
géométrie recalée ne doit pas pouvoir se faire passer pour la donnée d'origine.

## 6. Décisions

| # | Décision | Statut |
|---|---|---|
| D1 | Dépendre d'`ALSroads` (Suggests + Remotes) | **Tranchée** — chaîne à 5 niveaux mesurée, proportionnée aux normes du repo (§10.1). Documenter la dépendance système FFTW3 |
| D2 | Acquisition hors périmètre : l'appelant fournit `dossier_las` | Proposée (§4) |
| D3 | Colonne de provenance par tronçon | Proposée (§5) |
| D4 | Recalibrage France : les seuils Québec sont-ils transposables ? | **Favorable avec réserves** (§10.7) — pouvoir discriminant établi, justesse absolue non mesurée |
| D5 | `etat_conserve` par défaut : ne garder que `existante` ? | Proposée |
| D6 | Réglage retenu : MNT 20 cm + `profile_resolution = 0.2` | Proposée (§10.4) — surcoût TIN à mesurer |
| D7 | Recalage des seuils `drivable_width_thresholds = c(1, 5)` sur données françaises | **Ouverte** (§10.6) |

## 7. D1 — dépendre ou réimplémenter

**Recommandation : dépendre, en `Suggests`.** ALSroads est GPL-3, s'appuie sur
`lidR` déjà présent, et réimplémenter une mesure de largeur de chaussée par nuage
de points est un travail de recherche, pas d'intégration. Le risque de
maintenance se couvre par un `requireNamespace()` et un repli documenté — le
package n'est requis que pour la voie NDP 1.

**Contre-argument à peser** : « experimental / proof of concept », une seule
release, et un calibrage québécois (forêts nordiques, LiDAR single-photon) qui
n'a rien d'universel. D'où **D4**, qui est le vrai risque du chantier : une
largeur mesurée mais fausse est pire qu'une largeur absente, parce que
`places_depot()` la croira.

## 8. Plan en 4 lots

### Lot 1 — Faisabilité sur donnée française *(bloquant, à faire en premier)*
Faire tourner `ALSroads::measure_road()` sur une emprise IGN LiDAR HD réelle
(Chastel-Nouvel, dép. 48) et **confronter les largeurs mesurées au terrain ou à
l'orthophoto**. Sans ce contrôle, tout le reste est prématuré. Sortie attendue :
un verdict D4 chiffré, pas une impression.

### Lot 2 — Benchmark et cache
Temps de `measure_road()` par tronçon et sur une desserte départementale
(3 299 tronçons sur l'AOI de référence). Stratégie de cache par emprise. Le
recalage par nuage est lourd ; sans chiffre, l'app ne peut pas l'exposer — leçon
du câble-mât et du glouton (692 s).

### Lot 3 — `desserte_lidar()`
La fonction du §5, son repli, sa colonne de provenance, `.Rd` à la main, tests.

### Lot 4 — Mesure de l'effet réel
Rejouer `places_depot()` sur la desserte enrichie et **chiffrer** : les ~1 877
départs tombent-ils à un ordre exploitable ? La couverture 91 % devient-elle
réaliste ? C'est le seul critère de succès du chantier — le reste n'est que
plomberie.

## 9. Hors périmètre

- L'acquisition des tuiles LiDAR HD (reste côté app, cf. §4).
- La perf intrinsèque de `places_depot()` / `potentiel_cable()` / du glouton :
  chantiers `foretaccess` distincts (`brief-foretaccess-consolide-2026-07-22.md`).
  La largeur mesurée **atténue** la sélectivité, elle ne corrige pas la
  complexité.
- `vecnet`, écarté par le brief à juste titre : il vectorise un réseau depuis un
  raster de probabilité, il ne corrige pas un vecteur et ne produit pas de
  largeur.

---

## 10. Résultats de la validation (2026-07-22)

Lots 1 et 2 exécutés sur données réelles. Emprise **Vercors / Quatre Montagnes**
(tuiles IGN LiDAR HD `NUALHD_1-0__LAZ_LAMB93_PM_2025-03-25`, desserte BD TOPO V3,
341 tronçons / 68 km). Scripts rejouables : `volet_a_pouvoir_discriminant.R`,
`volet_b_ortho_ombrage_20cm.R`.

### 10.1 — Chaîne d'installation réelle (D1)

```
ALSroads 0.2.0        GitHub, "experimental", GPL-3, poussé 2024-11-15
 ├─ lidR 4.3.2        GitHub seul — ARCHIVÉ CRAN le 2026-06-09
 │   └─ rlas 1.9.5    GitHub seul — cause racine de l'archivage
 ├─ EBImage 4.54.0    Bioconductor
 │   └─ fftwtools     → libfftw3-dev  (BIBLIOTHÈQUE SYSTÈME)
 └─ raster, gdistance CRAN, héritage
```

**Cinq niveaux, quatre écosystèmes, une compilation C.** Aucun n'était visible
depuis le brief ni depuis le cadrage initial.

**Mise en perspective, vérifiée** : `nemeton` porte déjà **12+ `Remotes`**
(GitHub, GitLab, forge INRAE), plus `fasterRaster` (qui exige **GRASS GIS**),
`whitebox` (binaire externe) et `reticulate` (Python, pipeline FORDEAD).
`libfftw3-dev` est **plus léger que GRASS GIS**. La chaîne est donc lourde mais
**proportionnée aux normes du projet** — un premier jugement de « coût
disproportionné » reposait sur une norme générique de packages R, pas sur ce
repo.

**D1 confirmée** : dépendre en `Suggests` + `Remotes`, avec `requireNamespace()`
et repli documenté. **À documenter explicitement** : la dépendance système
FFTW3, qui n'est ni dans `Suggests` ni dans `Remotes` et cassera l'installation
sans message clair.

### 10.2 — Volet A : pouvoir discriminant (D4)

40 tronçons (10 par classe `nature`, graine fixe), **40/40 mesures abouties**.

| Classe BD TOPO | `DRIVABLEWIDTH` méd. | Q1–Q3 | `SCORE` | `ROADWIDTH` |
|---|---|---|---|---|
| Route à 1 chaussée | 5,85 m | 5,60–6,75 | 75,0 | 5,95 |
| Chemin | 5,65 m | 5,08–5,97 | 69,9 | 7,15 |
| Route empierrée | 5,25 m | 4,93–5,88 | 75,0 | 5,50 |
| **Sentier** | **2,40 m** | **1,18–2,98** | **36,1** | 5,40 |

**Kruskal-Wallis p = 0,000242.**

Le sentier décroche nettement ; les trois classes carrossables ne se séparent
**pas** entre elles. ALSroads discrimine « praticable / non praticable », pas la
hiérarchie fine des dessertes — **ce qui suffit à `places_depot()`**.

Le `SCORE` double le signal indépendamment de la largeur (36 contre 70–75) :
second critère de rejet, non prévu au cadrage.

> **Piège à ne pas rejouer.** La première exécution portait sur `ROADWIDTH`, qui
> mesure le **corridor** (emprise dégagée, accotements compris) et non la
> chaussée : sentier à 5,40 m, ordre inversé (`Chemin` 7,15 > `Route à 1
> chaussée` 5,95), p = 0,0125. Lecture qui s'imposait : « calibrage québécois
> non transposable, D4 échoue ». **Conclusion plausible, chiffrée, et fausse.**
> La bonne colonne est `DRIVABLEWIDTH`.

**Aucune largeur nulle** dans l'échantillon (0/10 par classe) : la règle de rejet
doit porter sur un **seuil**, pas sur `DRIVABLEWIDTH == 0`.

### 10.3 — Volet B : cohérence géomorphologique

L'orthophoto IGN 20 cm **ne montre rien sous couvert fermé** — un sentier
forestier y est invisible. Le MNT, issu des **retours sol** du LiDAR, révèle la
plateforme.

Densité mesurée sur une fenêtre de 50 m : **50,6 pts/m² au total**,
**7,51 pts/m² au sol**, espacement moyen **0,36 m**. Un MNT à 20 cm est donc
**sous l'espacement réel** : environ une cellule sur trois porte un point, le
reste est interpolé (TIN). Gain de **lisibilité**, pas d'information — la
texture triangulaire du TIN est visible sur les vignettes.

À 20 cm, sur les classes carrossables, la largeur mesurée **épouse les bords de
la plateforme**. Un soupçon de biais systématique de +1 à +1,5 m, formé sur
l'ortho, **ne résiste pas** à l'ombrage : il venait de confondre la trace d'usure
claire avec la plateforme carrossable.

**Bénéfice non prévu** : à 20 cm, le décalage de l'axe BD TOPO par rapport à
l'axe réel est flagrant (~1,5–2 m sur la route empierrée testée). Le **recalage
géométrique** d'ALSroads — seconde fonction, non testée par le volet A — est
visiblement utile, et cette résolution donne un critère pour l'évaluer.

**Limite** : le MNT vient du **même nuage** qu'ALSroads exploite. C'est un
contrôle de cohérence, **pas une référence indépendante**. La justesse absolue
reste non mesurée : il faudrait un relevé terrain.

### 10.4 — Sensibilité à la résolution

| Configuration | Largeur | `SCORE` | `CLASS` |
|---|---|---|---|
| MNT 1 m + `profile_resolution` 0,5 m | 5,80 m | 75,0 | 1 |
| MNT 20 cm + 0,5 m | 6,10 m | 75,0 | 1 |
| MNT 20 cm + **0,2 m** | 5,70 m | **96,4** | 1 |

Sur un sentier : `0,00 m` / score 0 / classe 0 dans **les trois** configurations.

**La largeur est robuste** (±0,2 m autour de 5,9, dans le bruit de la
granularité de 0,5 m), **la classe ne bouge pas** — la conclusion du volet A
tient quelle que soit la résolution. **Le score, lui, gagne beaucoup** en
affinant le profil (75 → 96,4) : ALSroads devient plus confiant sans changer sa
mesure, ce qui profite directement au filtrage de `places_depot()`.

**Réglage recommandé** : MNT 20 cm + `profile_resolution = 0.2`. **Surcoût non
mesuré** — le calcul du MNT par TIN s'ajoute aux 47 s/tronçon.

### 10.5 — Hétérogénéité des sentiers

Le sentier du §10.4 sort à `0,00 m`, ceux du volet A entre 1,18 et 2,98 m. Les
sentiers sont **bimodaux** : certains sont lus comme d'anciennes pistes, d'autres
comme rien du tout. **Ne pas caractériser cette classe par une largeur moyenne.**
Sans conséquence pour `places_depot()` — 0 ou 2,4 m sont rejetés pareillement.

### 10.6 — Coût, et ce qu'il impose

**47,3 s par tronçon** (mesuré sur 40). Sur les **3 299 tronçons** de l'AOI de
référence `foretaccess` : **≈ 43 heures**. Le cache par emprise n'est pas une
optimisation, c'est une **condition d'existence**, et un pré-filtrage sur les
classes plausibles s'impose avant tout appel à `measure_road()`.

Les paramètres exposés — dont `state$drivable_width_thresholds = c(1, 5)`,
**calibrage québécois** — sont la cible prioritaire d'un recalibrage France.

### 10.7 — Verdict

| Question | Réponse |
|---|---|
| Pouvoir discriminant praticable / non praticable | **Établi** (p = 0,000242) |
| Cohérence avec la géomorphologie | **Confirmée** à 20 cm |
| Justesse absolue | **Non mesurée** — pas de relevé terrain |
| Robustesse à la résolution | **Bonne** (largeur et classe stables) |
| Coût | **43 h** sur l'AOI de référence → cache obligatoire |
| Portée | n = 10/classe, **une seule emprise** |

**D4 : favorable, avec réserves.** Le signal existe et suffit à l'usage visé.
Ce qui manque avant industrialisation : un relevé terrain sur quelques tronçons,
une seconde emprise (contexte non montagnard), et le recalage des seuils
québécois.
