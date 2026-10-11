# Spec 060 — T2 : un vrai taux de changement, mesuré sur FORMS-T

> **Statut** : validé le 2026-10-11 (Pascal : « je te laisse faire ce qu'il y a
> de mieux pour T2 »), implémenté en **2026.10.3** (release A, § 5).
> **Demande** : « Je te laisse me proposer ce qu'il y a de mieux, regarde
> peut-être dans les paquets R déjà existants. »

## 1. Constat

`indicateur_t2_changement()` ne mesure aucun changement. Elle recopie N2
(continuité forestière), ou à défaut l'âge T1 plafonné à 100 (tuto 04). T2
n'apporte donc aucune information propre, et dans la famille T elle double T1.
Sa page d'aide le dit : « A genuine change-rate indicator is not implemented ».

## 2. Données disponibles

| Source | Ce qu'elle mesure | Couverture | Dans le cœur | Verdict pour T2 |
|---|---|---|---|---|
| **FORMS-T** (Theia) | hauteur de canopée annuelle à 10 m (cm), 2019 à 2024 | France entière | `load_theia_source("forms_t", asset = "height", year =)` ; cache national de 36 Go en local | **retenue** : mesure directe du changement de structure |
| SUFOSAT | date des coupes rases (Sentinel-1) | France, 2018 à 2025 | T3 | coupes rases seules ; déjà T3 |
| Séries Sentinel-2 (NDVI, NDMI) | verdure et humidité | partout | FAST, C2 | déjà C2, FAST et R5 ; un indice spectral n'est pas une structure |
| Hansen GFC (perte de couvert) | perte annuelle, 30 m | monde, 2001 à 2023 | non | binaire, 30 m, pas de croissance ; paquet `gfcanalysis` retiré de CRAN |
| LiDAR HD | MNH à une date | France, une seule date | oui | une date ne donne pas de taux |

FORMS-T est la seule source qui donne à la fois les **pertes** (coupe,
dépérissement, chablis, éclaircie forte) et la **croissance**, chaque année, sur
toute la France, et elle est déjà branchée.

## 3. Paquets R examinés

| Paquet | Rôle | CRAN | Verdict |
|---|---|---|---|
| `bfast` / `strucchange` | ruptures dans une série dense et saisonnière | oui | inadapté : 6 points annuels, pas de saison |
| `Rbeast` (BEAST) | ruptures et tendance bayésiennes | oui | surdimensionné pour 6 points ; à garder pour une future série S2 dense |
| `trend`, `Kendall`, `mblm` | Mann-Kendall, pente de Sen | oui | redondants : **le cœur a déjà un Theil-Sen + Mann-Kendall vectorisé** (`.trend_fit_cells()`, spec 023, mode « trend » de FAST), testé et borné en mémoire |
| `greenbrown` | tendances et ruptures NDVI | non (R-Forge) | indisponible |
| `gfcanalysis`, `forestChange` | Hansen GFC | non (retirés) | indisponibles |
| `npphen`, `phenofit` | phénologie | oui | hors sujet |

**Recommandation : aucune nouvelle dépendance.** Le calcul est une pente de
Theil-Sen et une chute persistante sur 6 valeurs par pixel. Il passe par
`terra` et `exactextractr`, qui sont déjà en Imports.

*Implémentation* : `.theil_sen_pentes()` fait le même calcul que
`.trend_fit_cells()` (médiane des pentes par paire, par blocs), mais rend la
pente signée et sans test de Mann-Kendall. `.trend_fit_cells()` n'est pas
modifiée, pour ne pas toucher aux cartes FAST.

## 4. Mesures (2026-10-11, cache FORMS-T local)

**Bruit.** Dabo (774 ha, 79 132 pixels) : l'écart-type des résidus autour de la
pente vaut **17 cm** par pixel (médiane). Le bruit d'une année à l'autre est
donc très inférieur aux signaux visés.

**Croissance.** La pente médiane décroît avec la hauteur de départ, comme une
courbe de croissance (et non comme une dérive uniforme du modèle) :

| Hauteur 2019 | Pixels | Pente médiane |
|---|---|---|
| 5 à 15 m | 1 703 | +1,15 à +1,18 m/an |
| 15 à 20 m | 2 912 | +0,91 m/an |
| 20 à 25 m | 17 032 | +0,55 m/an |
| 25 à 30 m | 36 351 | +0,26 m/an |
| 30 à 35 m | 18 755 | +0,15 m/an |
| > 35 m | 2 211 | +0,07 m/an |

**Pertes.** On compare une chute de hauteur persistante aux coupes rases
SUFOSAT de 2020 à 2024 (probabilité ≥ 90 %, tolérance d'un pixel en bordure) :

| Site | Pixels | Coupes SUFOSAT | Rappel à 5 m | Détections dans SUFOSAT à 5 m |
|---|---|---|---|---|
| Fordead | 63 284 | 81 % (scolytes) | 99 % | 82 % |
| Reconfort | 55 770 | 3,1 % | 61 % | 28 % |
| Aumur | 6 699 | 6,6 % | 39 % | 50 % |

FORMS-T retrouve la majorité des coupes rases quand elles sont massives. Il
voit aussi **bien d'autres pertes que SUFOSAT** : à Reconfort, plus de deux
détections sur trois tombent hors coupe rase.

**Ces pertes hors SUFOSAT sont réelles** (vérifié le 2026-10-11). On les
compare au MNH du LiDAR HD de Reconfort, mesuré de novembre 2023 à janvier 2024
et indépendant de FORMS-T. La comparaison porte sur la hauteur p95 par cellule
de 10 m et sur les pertes que FORMS-T date de 2023 ou avant :

| Groupe | Pixels | FORMS-T 2019 | FORMS-T 2023 | LiDAR p95 | LiDAR sous (2019 − 5 m) |
|---|---|---|---|---|---|
| couvert stable | 51 654 | 22,6 m | 22,9 m | 21,4 m | 7 % |
| perte dans SUFOSAT | 1 705 | 20,4 m | 2,5 m | 0,9 m | 97 % |
| **perte hors SUFOSAT** | **2 305** | 17,8 m | 2,4 m | **0,2 m** | **96 %** |

97 % des pertes hors SUFOSAT forment des taches d'au moins 0,1 ha (10
pixels) : ce n'est pas du bruit isolé. Il s'agit donc de coupes ou de
disparitions de couvert que SUFOSAT ne voit pas, comme des coupes partielles ou
sanitaires, du dépérissement ou des chablis. **C'est précisément ce que T3 ne
couvre pas.** Le recoupement avec les alertes FAST n'a rien donné : les cartes
« count » sont saturées (99 % partout) et les autres ne séparent pas les
groupes.

Le rappel imparfait (39 à 61 %) vient de coupes que FORMS-T voit tard ou
faiblement (jeunes peuplements bas, coupes de 2024 absentes de la hauteur
2024). Il ne gêne pas T2, qui n'a pas à refaire T3.

## 5. Proposition

T2 devient la **stabilité du couvert sur 2019-2024**, mesurée par unité :

- **Score T2** (0 à 100, 100 = stable, même sens qu'aujourd'hui, donc sans
  inversion dans `normalization.R`) = `100 × (1 − part de la surface forestière
  de l'unité ayant subi une perte persistante ≥ 5 m)`. Une perte est
  persistante quand la hauteur reste sous `max(années précédentes) − 5 m`
  jusqu'en fin de série, pour qu'un creux isolé d'une année ne compte pas.
- **Colonnes de diagnostic**, pour l'app et la fiche :
  - `t2_perte_pct` : part de la surface en perte ;
  - `t2_croissance_m_an` : pente de Theil-Sen médiane des pixels sans perte ;
  - `t2_annees` : fenêtre réellement lue ;
  - `t2_methode` : `"forms_t"` ou `"proxy"`.
- **Repli** : sans FORMS-T (hors France, échec de lecture), on garde le proxy
  actuel (N2, puis T1), avec `t2_methode = "proxy"`.

**Compatibilité.** T2 est **stable** (spec 057). On procède en deux temps :

1. **Release A** : nouvel argument `forms_t = NULL`, qui reçoit une pile de
   rasters annuels ou des chemins. S'il est absent, le comportement est
   identique. S'il est fourni, T2 est mesurée. C'est un ajout compatible, sans
   dépréciation. Brief app : charger les hauteurs FORMS-T et les passer à T2.
2. **Release B**, après validation dans l'app : le proxy, lui, est déprécié
   (`deprecatedWarning`) puis retiré selon la règle des 3 mois ou de l'absence
   d'appelant, avec ton accord.

**Fiche et pièges.** On ne compare pas T2 entre deux fenêtres d'années
différentes. FORMS-T est une hauteur **prédite** (Sentinel-1/2 et GEDI), pas
mesurée. Les éclaircies faibles (moins de 5 m) ne sont pas vues.

## 6. Vérifications avant release (faites le 2026-10-11)

- **Pertes hors SUFOSAT à Reconfort** : confirmées par le LiDAR HD (§ 4).
  Aucune carte RECONFORT n'est calculée sur ce projet (zone 59).
- **Seuil** : la part de surface en perte varie peu entre 3 et 8 m.

  | Site | 3 m | 5 m | 8 m |
  |---|---|---|---|
  | Reconfort | 8,4 % | 7,4 % | 6,3 % |
  | Aumur | 8,6 % | 5,9 % | 4,5 % |
  | Fordead | 98,1 % | 97,6 % | 96,5 % |
  | Dabo | 1,3 % | 1,0 % | 0,6 % |

  Le seuil de **5 m** est retenu.
- **Persistance** : « jusqu'en fin de série » et « au moins 2 ans de suite »
  donnent des parts à 0,5 point près à 5 m sur les quatre sites (1,2 point au
  plus, à Aumur avec un seuil de 3 m). On retient « jusqu'en
  fin de série », plus simple à expliquer.
- **Temps** : depuis le cache national, la lecture prend 0,2 s et le calcul de
  2 à 4 s par projet (Dabo, Reconfort, Fordead).

## 7. Décisions (2026-10-11, déléguées par Pascal)

1. T2 = **stabilité du couvert** (pertes toutes causes confondues). La
   croissance reste en diagnostic.
2. Seuil de perte : **5 m**, persistance jusqu'en fin de série.
3. Deux releases : `forms_t` d'abord (2026.10.3), puis dépréciation du proxy
   après validation dans l'app. Le retrait du proxy demandera l'accord de
   Pascal (fonction stable, spec 057 § 8).
4. L'**anomalie de croissance** (pente comparée à une référence nationale par
   classe de hauteur et SER) est reportée.

## 8. Livré en 2026.10.3

- `charger_forms_t_hauteurs(aoi, annees, dossier, country)`, **experimental** :
  lit le cache local (`dossier` ou `NEMETON_FORMS_T_DIR`) et, à défaut, Theia
  année par année.
- `indicateur_t2_changement()` gagne `forms_t`, `seuil_perte` et
  `unite_hauteur`. `forms_t` peut aussi venir de `layers$rasters$forms_t`, et
  `nemeton_compute(..., forms_t = )` le transmet. Sans FORMS-T, le résultat est
  inchangé (colonne `T2` seule).
- Avec FORMS-T : `t2_status` (`forms_t`, `proxy` ou `no_source`, transporté par
  `nemeton_compute()` comme les autres statuts), `t2_perte_pct`,
  `t2_croissance_m_an` et `t2_annees`.
- Fiche T2, infobulle et diagramme réécrits ; tests sur une série synthétique
  aux réponses connues.
