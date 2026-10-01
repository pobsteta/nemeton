# Spec 054 — Production IFN par petits domaines (Fay-Herriot) et ses consommateurs

**Version** : 0.5.0 (lot 2 livré)
**Date**    : 2026-10-01
**Statut**  : **Lots 1, 1-bis et 2 livrés** (cœur v0.200.0, v0.201.0,
v0.202.0, 2026-10-01). Moteur Fay-Herriot, table de production et de prélèvement,
P2 `source = "ifn_fh"`, ratio prélèvement/production. Lots 3 à 5 ouverts ; le jeu
GEDI (D3) attend un accès Earthdata. Résultats en §3.b, §3.c, §7.1 et §7.2.
**Auteur**  : Pascal Obstétar (via Claude)
**Cible cœur** : `nemeton` — moteur Fay-Herriot, table de production IFN par
SER × campagne, et branchement sur P2, P1/C1, E1/E2 et la spec 040.
**Cible app**  : `nemetonshiny` — aucune dans cette spec ; un brief suivra le lot 4.
**Origine** : Onwunji I.C., Vega C., Durrieu S., Korhonen L., Tokola T., Massey A.,
Cordonnier T., Bouriaud O., Besic N., Belhoul S., Renaud J.-P. (2026).
*Leveraging GEDI and NFI to inform on forest productivity at the level of the
management units.* Annals of Forest Science 83:46.
doi:10.1186/s13595-026-01358-2 — CC-BY 4.0.

---

## 1. Objectif

Donner au cœur ce qui lui manque aujourd'hui : **un flux de production
biologique** (m³/ha/an et m²/ha/an) **mesuré par l'IFN**, avec une **incertitude
par domaine**. Ensuite, faire consommer ce flux par les indicateurs qui le
remplacent aujourd'hui par une table ONF figée ou par un pourcentage du stock.

Ce n'est pas l'apport de GEDI qui compte ici, c'est la **méthode** de l'article :
l'estimateur Fay-Herriot (FH) au niveau du domaine. Il combine :

- la **moyenne directe IFN** du domaine : sans biais, mais bruitée quand il y a peu
  de placettes ;
- une **prédiction synthétique** Xβ, régression sur des covariables de
  télédétection agrégées au même domaine.

Le dosage entre les deux suit leurs variances, et chaque domaine reçoit une erreur
quadratique (MSE).

## 2. Ce que l'article établit, et ce qu'on en reprend

| Élément de l'article | Repris ? | Commentaire |
|---|---|---|
| FH au niveau du domaine (EBLUP + MSE Prasad-Rao g1+g2+g3) | **Oui** | Cœur de la spec (§4). |
| Empilement domaine × année (*pooled cross-section*), β et σᵥ² invariants dans le temps | **Oui** | Garde le signal annuel sans agréger les campagnes a priori. |
| Covariables GEDI L2A (rh98 moyenne/écart-type, altitude du sol moyenne/écart-type) | **Oui, en concurrence** | Deux jeux construits et comparés (D3) : GEDI L2A brut comme l'article, et FORMS-T hauteur + MNT. Le meilleur est retenu sur critères fixés à l'avance (§5.b). |
| Sélection de variables par best subset + AIC, 3 prédicteurs au plus, une seule métrique de hauteur | **Oui** | Évite la colinéarité rh90/rh98/rh100. |
| Domaines ONF agence / unité territoriale | **Non (par défaut)** | Domaine natif = SER (cohérent avec la spec 040). Les UT ONF restent possibles en domaine utilisateur (D2). |
| Production fournie par la base IFN interne (accroissement + recrutement) | **Non** | Les données brutes ouvertes n'ont **pas** de colonne de production. On la recalcule (§3). |
| Seuils de RSE : 15 % pour la production, 10 % pour le stock | **Oui** | Repris comme seuils d'affichage, pas comme filtre. |

**Résultats chiffrés de l'article** (Bourgogne-Franche-Comté, forêts publiques,
2019-2022, 5 591 placettes). R² de PV : 0,66 sur les agences et 0,62 sur les unités
territoriales. L'efficacité relative est toujours supérieure à 1 (≥ 4 sur les
agences). Avant FH, 16 unités territoriales sur 51 passaient sous 15 % de RSE pour
PV ; après FH, 43 sur 51.
**Ce qu'il ne montre pas** : aucune tendance détectable sur 4 ans (§7.6).

## 3. Ce que l'IFN brut permet de calculer — vérifié sur l'export

Vérifié sur `data-raw/ifn/export_dataifn_2005_2024.zip` (IGN, Licence Ouverte
Etalab v2.0, doc `IGN_DB_doc_arbre.pdf` v2.4 du 14/10/2025) :

- `ARBRE.csv` porte `C13` (circonférence à 1,30 m), `HTOT`, `V`, `W` et **`IR5`**,
  l'accroissement radial cumulé des 5 derniers cernes complets, mesuré à la tarière
  au niveau de C13. **`IR5` est en mètres** dans la table, pas en dixièmes de mm
  (la doc le précise).
- `IR5` est renseigné sur 854 804 lignes sur 2 363 567. Le carottage est partiel
  depuis 2014 (§3.a, point 3). Il est **absent** :
  - sur les arbres simplifiés ;
  - sur les noyers (`ESPAR = 27C`) ;
  - sur le chêne vert (`ESPAR = 6`) depuis 2015 ;
  - sur les lignes de revisite (même piège que `VEGET5`, spec 040 §5.c).
  Pour un arbre de moins de 5 cernes à 1,30 m, `IR5` est extrapolé au prorata.
- **Aucune colonne de production** dans `ARBRE` ni dans `PLACETTE`.
- **Aucune colonne de propriété** dans `PLACETTE` : on ne peut pas restreindre aux
  forêts publiques comme l'article. Ses ordres de grandeur (PV moyen 5,87 m³/ha/an,
  PG 0,65 m²/ha/an) ne sont donc **pas** un contrôle direct.

Conséquences sur ce que chaque attribut demande :

**PG (production en surface terrière, m²/ha/an) : exacte, sans hypothèse.**
Il suffit de reconstituer la circonférence d'il y a 5 ans :

```
C_passé = C13 − 2π·IR5
g = C²/(4π)
PG_arbre = (g(C13) − g(C_passé)) / 5
PG = Σ W·PG_arbre
```

`W` est le poids à l'hectare de l'arbre.

**PV (production en volume, m³/ha/an) : demande une hypothèse.**
L'accroissement en hauteur n'est pas mesuré. Deux voies :
- **(a) Forme et hauteur constantes** : `ΔV ≈ V·(1 − (C_passé/C13)²)`. Cette voie
  sous-estime la production, puisque la hauteur a aussi crû.
- **(b) Tarif IFN du cœur** (`lookup_ifn_equation()`, déjà utilisé par P1)
  appliqué à `C_passé`, avec une hauteur passée modélisée.
C'est la décision D1.

**Recrutement — confirmé au lot 0.** La méthodologie IGN 2023 (p. 18) définit le
recrutement comme le volume des arbres « ayant atteint le diamètre de 7,5 cm durant
les cinq dernières années ». En circonférence, cela fait 0,2356 m. Un arbre dont
`C_passé` < 0,2356 m entre donc **en entier** dans la production.

**Contrôle externe** : voir §3.a.

### 3.a Relevés du lot 0 (2026-10-01)

**Sources.** IGN, *La production annuelle en volume*, édition 2024 (`flux2024.pdf`).
IGN, *Méthodologie 2023 — pour bien comprendre les résultats publiés 2018-2022*,
p. 18-19. Calculs exploratoires sur l'export 2005-2024 (scripts jetables, rien
d'embarqué).

**1. Chiffre de référence IGN**, période de végétation 2014-2022 :
- production biologique **87,9 ± 1,3 Mm³/an**, soit **5,4 m³/ha/an** ;
- Bourgogne-Franche-Comté : 10,3 ± 0,3 Mm³/an.

Le chiffre IGN couvre la production des arbres vifs (accroissement + recrutement,
environ 95 % du total) **plus la production des arbres coupés** (leur croissance
pendant les 2,5 ans théoriques avant la coupe). Les arbres morts sont exclus,
leur accroissement étant supposé nul.

**2. Ce que mesure une campagne.** La campagne t mesure les cernes t-5 à t-1. Le
résultat IGN publié est une moyenne pondérée sur 9 saisons, et ce lissage est
voulu (§7.6).

**3. Le carottage est partiel depuis 2014, et c'est voulu par l'IGN.** Depuis la
campagne 2014, l'IGN ne carotte qu'**un arbre par essence et par catégorie de
dimension, plus les gros bois** ; les autres arbres sont des arbres « simplifiés ».
L'IGN modélise leur accroissement, mais **ces valeurs ne sont pas dans l'export
brut**.

Mesuré sur les arbres vivants de première visite :

| Campagnes | Lignes avec IR5 | Arbres simplifiés | IR5 hors simplifiés |
|---|---|---|---|
| 2005-2008 | 98-100 % | 0 % | 98-100 % |
| 2009-2013 | 74-76 % | 22-24 % | 97-98 % |
| 2014-2024 | **36-42 %** | **52-61 %** | 85-88 % |

Conséquence : l'imputation n'est **pas un cas marginal**, c'est le régime normal.
Elle couvre **47 % de la surface terrière** sur 2015-2023. La règle initiale de D7
(« exclure la placette si plus de 50 % de G sans IR5 ») aurait écarté la majorité
des placettes récentes. **D7 est amendée** (§9).

**4. Imputation testée.** Le taux d'accroissement relatif en surface terrière
`rg = 1 − (C_passé/C13)²` des arbres carottés est reporté sur les simplifiés en
cascade :
1. placette × essence × catégorie de dimension (PB < 22,5 ≤ BM < 47,5 ≤ GB < 67,5 ≤
   TGB, en cm de diamètre), ce qui épouse le plan de carottage IGN ;
2. placette × essence ;
3. placette.

Résultat : 44,4 % de G imputés au premier échelon, 1,5 % au deuxième, 1,3 % au
troisième. **Il reste 1,85 % de G sans valeur.** La circonférence passée des
arbres imputés se déduit de `C_passé = C13·√(1 − rg)` (piège §8.9).

**5. Contrôle national, voie (a)** : forme et hauteur constantes, recrutement
compris, sans la production des arbres coupés. Moyenne sur les placettes de
première visite avec arbres.

| Campagnes | PV (m³/ha/an) | PG (m²/ha/an) | G (m²/ha) | V (m³/ha) | Part du recrutement dans PV |
|---|---|---|---|---|---|
| 2015-2023 | **4,61** | 0,681 | 24,6 | 196 | 8,0 % |
| 2005-2013 | 4,53 | 0,699 | 23,5 | 178 | 8,3 % |

L'écart avec la référence IGN (5,4) est de **−15 %**. Il s'explique par deux
manques :
- la production des arbres coupés, environ 5 % du total selon l'IGN ;
- la croissance en hauteur, ignorée par la voie (a), soit environ 10 %.

C'est un biais bas, documenté et du bon ordre. **La voie (a) est acceptée pour le
lot 1.** Le dénominateur (placettes avec arbres, et non la surface de forêt de
production) peut aussi peser de quelques pourcents ; il faut l'aligner sur l'IGN
au lot 1.

PG (0,68) est cohérente avec l'article (0,65 en forêts publiques de BFC).

**Test de verrouillage (lot 1)** : la PV nationale de la voie (a) doit être
comprise entre **70 % et 100 %** du chiffre IGN, et la PG nationale entre 0,45 et
0,80 m²/ha/an.

**Borne abaissée de 80 à 70 % au lot 1.** Les 85 % du lot 0 portaient sur les
seules placettes avec arbres. Le lot 1 prend le dénominateur de l'IGN : depuis
2015, toute placette de l'export est en forêt disponible pour la production (doc
`PLACETTE` v2.4), y compris celles sans arbre recensable. Mesuré au lot 1 sur les
campagnes 2019-2023 : **4,21 m³/ha/an, soit 78 %**. La règle D7 a exclu 3 557
placettes sur 127 718. L'écart restant (−22 %) se répartit entre la production des
arbres coupés (environ 5 %) et la croissance en hauteur ignorée par la voie (a).
Il motive le lot 1-bis.

**6. Couverture GEDI.** Le jeu G a trois contraintes :
- **trou d'acquisition du 17 mars 2023 au 24 avril 2024** (instrument retiré de
  l'ISS). Les campagnes IFN dont la fenêtre de cernes chevauche ce trou n'ont pas
  de covariables GEDI de l'année. Le jeu G n'utilise que les années d'acquisition
  complètes ;
- **accès** : GEDI02_A V002 sur LP DAAC, avec un compte NASA Earthdata gratuit.
  **Aucun identifiant n'est configuré sur la machine** (`~/.netrc` sans entrée
  `urs.earthdata.nasa.gov`), et aucun lecteur HDF5 n'est installé en R (`hdf5r`,
  `rhdf5` absents ; `arrow` présent) ;
- **jeu prétraité de l'article** : le jeu GeoGEDI France entière (TETIS 2026) n'a
  pas été trouvé en accès public. Le dépôt public GeoGEDI (doi:10.57745/EJ4CI3)
  ne couvre que les Landes et les Vosges (158 000 tirs), ce qui ne suffit pas.

Le jeu G demande donc une mise en place par Pascal : compte Earthdata, `~/.netrc`,
et un lecteur HDF5 ou un sous-ensemble via le service Harmony de la NASA. Le jeu F
n'en dépend pas. **Le lot 1 peut démarrer sur F**, et G le rejoint pour la
comparaison dès que l'accès est prêt.

### 3.b Résultats du lot 1 (2026-10-01, v0.200.0)

**Données.** 1 379 797 arbres vivants de première visite et 127 718 placettes
(campagnes 2005-2024). Surface terrière imputée : 28,9 % toutes campagnes
confondues ; 2,1 % reste sans valeur. 3 557 placettes ont été exclues par la règle
D7.

**Covariables (jeu F).** Hauteur FORMS-T 2019-2024 (Zenodo 15489231, 6 × 6,3 Go)
agrégée sous masque ≥ 5 m. Moyenne et écart-type sont exacts à 10 m, calculés par
sommes (n, Σh, Σh²) sur une grille de 250 m puis par SER. L'altitude vient du WMS
IGN à 250 m, pondérée par la part de forêt de chaque cellule.

**Autocorrélation spatiale (§8.7) et décision.** Sans effet régional, les résidus
du modèle synthétique sont autocorrélés entre SER voisines : I de Moran par
contiguïté de 0,16 à 0,34, p ≤ 0,004 chaque année. **Décision du 2026-10-01 : la
GRECO entre comme effet fixe**, toujours présent ; l'AIC ne choisit que les
covariables continues. Le FH spatial (SAR) n'est pas retenu, la GRECO suffisant à
retirer la structure.

**Modèles retenus** (SER × campagne 2019-2024, 515 domaines-années ajustés) :

| Attribut | Covariables | σᵥ² | R² synthétique (corrigé de ψ) | RE globale | RSE médiane FH / direct |
|---|---|---|---|---|---|
| PG | h_sd + alt_mean + GRECO | 0,0102 | 0,69 | 2,26 | 8,7 % / 10,2 % |
| PV | h_mean + h_sd + alt_mean + GRECO | 0,269 | 0,83 | 3,38 | 8,2 % / 11,1 % |

Sans GRECO, la PV obtenait un R² de 0,73 et une RE de 2,68.

**I de Moran après GRECO**, résidus par campagne 2019 → 2024 :
- PG : p = 0,25 / 0,047 / 0,16 / 0,41 / 0,47 / 0,42 ;
- PV : p = 0,23 / 0,038 / 0,13 / 0,085 / 0,23 / 0,16.

Seule 2020 passe sous 0,05, de justesse : sur 6 tests, c'est le niveau attendu sous
l'hypothèse nulle.

**Contrôle national** : PV 4,21 m³/ha/an sur 2019-2023, soit 78 % de la référence
IGN (§3.a).

**Ce qui reste en estimation directe** : les groupes feuillus et résineux (§6),
les GRECO, le national, et les campagnes 2005-2018, faute de covariables FORMS-T.

**Coût du précalcul.** L'agrégation FORMS-T a d'abord tourné en séquentiel à 73
minutes par année, à cause de `ifelse()` sur 30 millions de valeurs. Optimisée et
parallélisée sur 6 cgroups de 4 Go, elle prend environ 1 h 10 pour les 6 années.
Un premier essai a été tué par OOM sur les 6 cgroups (`journalctl`) au moment de
construire le raster de sortie. Depuis, les sommes sont sauvées avant cette étape.

### 3.c Lot 1-bis : hauteur, arbres coupés, prélèvement (2026-10-01, v0.201.0)

**Pourquoi maintenant.** Au début du lot 2, le ratio prélèvement/production
sortait à **0,82** au niveau national, contre **0,61** pour l'IGN (53,1 / 87,9
Mm³/an, période 2014-2022). En cause, la PV de la voie (a), trop basse de 22 %. Un
ratio aussi biaisé aurait fait passer la plupart des SER pour décapitalisées.
Le lot 1-bis prévu par D1 est donc passé avant le lot 2.

**Voie (b), hauteur.** La hauteur suit le diamètre selon l'allométrie H ∝ D^β,
donc à forme constante V ∝ D^(2+β) et `rv = 1 − (1 − rg)^((2+β)/2)`.

β est estimé dans l'IFN par régression de log H sur log C13, **à l'intérieur de
chaque placette × essence** (au moins 3 arbres mesurés en hauteur, ce qui retire
l'effet station), par groupe × catégorie de dimension. 623 000 arbres sont
utilisés :

| | PB | BM | GB | TGB |
|---|---|---|---|---|
| feuillus | 0,505 | 0,404 | 0,353 | 0,273 |
| résineux | 0,642 | 0,497 | 0,528 | 0,483 |

β décroît avec la taille, comme la croissance en hauteur des arbres âgés. Une
réserve : la pente transversale, mesurée dans un peuplement, sert ici de proxy de
la trajectoire individuelle d'un arbre. C'est la convention habituelle, mais
c'est une hypothèse.

**Arbres coupés.** Ce sont les arbres vifs au premier passage (campagne t−5),
puis coupés avant la revisite (t), codes `VEGET5` 6 **et** 7 comme pour l'IGN.
65 133 arbres sur 70 624 (92 %) sont rattachés à leur mesure de premier passage.
On suppose la coupe à mi-période, comme l'IGN :
- production avant coupe `V·rv·0,5/5` ;
- volume prélevé actualisé `V·(1 + rv/2)/5`.

**Deux échantillons par campagne t.** A est l'ensemble des placettes de première
visite en t (arbres vifs), B celui des placettes revisitées en t (arbres coupés).
Pour PG et PV, `direct = moyenne_A + moyenne_B` et `ψ = ψ_A + ψ_B`, les deux
échantillons étant indépendants. Pour `prel` et `prel_vidange`, on n'utilise que
B. Les campagnes 2005-2009 n'ont pas de revisite : leur production n'inclut pas
les arbres coupés.

**Contrôle national** (campagnes 2019-2023, période 2014-2022) :

| | Lot 1 (voie a) | Lot 1-bis | IGN |
|---|---|---|---|
| PV (m³/ha/an) | 4,21 (78 %) | **5,26 (97 %)** | 5,4 |
| Prélèvement (m³/ha/an) | — | 3,54 (107 %) | 3,3 |
| Ratio prélèvement / production | 0,82 | **0,67** | 0,61 |

Le prélèvement reste un peu haut (+7 %). Le dénominateur, l'ensemble des
placettes revisitées, n'est pas exactement la surface de forêt de production de
l'IGN, et l'actualisation de croissance est approchée. Le ratio garde donc
environ **+10 % de biais** au niveau national, à afficher avec lui (§7.2).

**Fay-Herriot** (même spécification que le lot 1, GRECO en effet fixe) :
- PV : h_mean + h_sd + alt_mean, R² 0,83, RE 3,67, RSE médiane 8,2 % contre
  10,9 % en direct ;
- PG : h_sd + alt_mean, RE 2,38 ;
- Moran : non significatif, sauf PV 2020 (p = 0,043).

**Tests de verrouillage** (relevés) :
- PV nationale entre 85 % et 110 % de l'IGN ;
- prélèvement entre 85 % et 120 % ;
- `prel_vidange` ≤ `prel`.

## 4. Le moteur Fay-Herriot — implémentation maison

Pour un domaine i et une campagne t :

```
θ̂_it = X_it·β + v_i + e_it        v_i ~ N(0, σᵥ²)    e_it ~ N(0, ψ_it)
ψ_it = Σ_j (y_ijt − θ̂_it)² / (n_it (n_it − 1))         (variance de la moyenne)
γ_it = σᵥ² / (σᵥ² + ψ_it)
θ̂_it^FH = γ_it·θ̂_it + (1 − γ_it)·X_it·β̂
MSE_it ≈ g1 + g2 + g3                                   (Prasad-Rao)
RSE_it = √MSE_it / θ̂_it^FH × 100
```

**Choix : implémentation en R de base, environ 150 lignes, sans dépendance**
(D4). Raisons :

- `JoSAE` (0.3.0) et `sae` (1.3) sont sous licence **GPL-2** stricte, vérifié
  sur CRAN le 2026-10-01. Leur compatibilité avec le GPL-3 de `nemeton` en
  `Imports` est discutable.
- `emdi` (GPL-2) tire une quinzaine de dépendances, dont `spdep` et `openxlsx`.
- Le modèle FH est court : estimation de σᵥ² (REML ou Fay-Herriot par moments),
  β par moindres carrés généralisés, puis EBLUP et MSE.

`sae` entre en **`Suggests`** uniquement, pour un test de non-régression :
l'EBLUP et la MSE maison doivent reproduire `sae::eblupFH()` / `sae::mseFH()` à
1e-6 près sur un jeu fixé.

**Cas limites à traiter explicitement** :

- **σ̂ᵥ² ≤ 0.** On le tronque à 0 et on émet un avertissement : toutes les
  estimations deviennent synthétiques, et il faut le dire.
- **n_it = 1.** ψ n'est pas calculable. On ne crée pas de domaine-année direct ;
  il passe en domaine **synthétique**.
- **Domaine sans placette.** Prédiction synthétique seule, MSE = g2 + σᵥ².
  Marquée `nature = "synthetique"`, jamais `"fay_herriot"`.

**Sorties ligne à ligne** : `estimation`, `mse`, `rse`, `gamma`, `n_plac`,
`direct`, `psi`, `synthetique`, `nature` (`"direct"` / `"fay_herriot"` /
`"synthetique"`). Le γ est publié parce que le FH dépend d'un modèle et peut être
biaisé si ce modèle est faux (Kangas et al. 2025, cités par l'article §4.2). Le
lecteur doit voir **quelle part de l'estimation est un modèle**.

## 5. Domaines et covariables

### 5.a Domaines

- **Natif : SER × campagne**, avec la GRECO en repli d'affichage. Mêmes clés que
  `ifn_volume_essence_ser.csv` et `ifn_prelevement_essence_ser.csv`, ce qui permet
  de joindre directement le ratio prélèvement/production (§7.2).
- **Domaine utilisateur** (lot 5, D2) : l'appelant fournit des polygones, par
  exemple des UT ONF (parcellaire, spec 046) ou un massif. Les placettes IFN sont
  rattachées par jointure point-dans-polygone sur `XL`/`YL`. Les coordonnées
  publiques sont floutées : à un niveau agrégé c'est tolérable (c'est l'argument de
  l'article §4.1), mais une placette en bordure peut tomber dans le mauvais
  domaine. Il faut le documenter, et ne pas descendre sous quelques milliers
  d'hectares.
- **Jamais l'UGF.** Une UGF de quelques hectares n'a pas de placette ; elle ne
  reçoit que la valeur de son domaine (§7).

### 5.b Covariables (D3 — deux jeux, comparés)

Deux jeux sont construits sur les **mêmes domaines-années** et départagés au lot 1.

| Jeu | Covariable | Source | Agrégat par domaine × année |
|---|---|---|---|
| **G** (comme l'article) | Hauteur | GEDI L2A, rh98 (et rh70, retenu par l'article sur ses agences pour PG) | moyenne, écart-type |
| **G** | Altitude du sol | GEDI L2A, *ground elevation* | moyenne, écart-type |
| **F** | Hauteur de canopée | FORMS-T `height` (10 m, annuel 2018→) | moyenne, écart-type |
| **F** | Altitude | MNT 25 m (déjà en NDP 0) | moyenne, écart-type |
| les deux (option) | Climat | WorldClim / E-OBS | moyenne |

**Filtrage GEDI** (jeu G), repris de l'article §2.3 :
- `degrade_flag = 0` et `quality_flag = 1` ;
- hauteur > 65 m écartée ;
- faisceaux *power* et *coverage* gardés, de jour comme de nuit ;
- seuls les tirs **sous masque forêt** sont retenus (§8.8).

Le seuil de sensibilité ≥ 0,95 a été testé par les auteurs : il fait tomber 45,5 %
des tirs *coverage*. Il n'est pas repris par défaut.

**GEDI a deux points d'attention.** L'acquisition passe par Earthdata, avec un
identifiant NASA, et uniquement dans `data-raw/`, jamais à l'exécution du paquet.
Il faut aussi vérifier les trous de couverture temporelle (période de mise en
veille de la mission) avant d'empiler les années. Aucune source GEDI n'est
déclarée aujourd'hui dans `inst/datasources/FR.json` : le jeu G ne crée pas de
source d'exécution, il ne vit que dans `data-raw/`.

**Critères de choix, fixés avant de voir les résultats** (pour ne pas choisir sur
le bruit) :

1. **Efficacité relative globale** (RE, article éq. 6) sur PG et PV, pour chaque
   jeu, sur les mêmes domaines-années.
2. **Validation croisée « un domaine en moins »** : RMSE de la prédiction
   synthétique sur la SER retirée. C'est ce critère qui juge la partie modèle.
3. **I de Moran des résidus** : un jeu qui laisse une structure spatiale est
   pénalisé.

L'AIC ne sert qu'à **choisir les variables à l'intérieur d'un jeu** (*best
subset*, 3 prédicteurs au plus, une seule métrique de hauteur). Il ne sert pas à
comparer les deux jeux.

En cas d'égalité (écart de RE inférieur à 10 %), on retient **F** : couverture
continue, déjà déclaré, aucun téléchargement Earthdata à maintenir. Le jeu perdant
reste documenté dans `data-raw/` avec ses scores, et n'est **pas** embarqué.

**Circularité.** Le *volume* et la *biomasse* de FORMS-T sont calés sur des
placettes IFN (Schwartz et al. 2023). Les utiliser comme covariables pour estimer
un attribut IFN réintroduirait l'IFN des deux côtés de l'équation. **Seule la
hauteur FORMS-T**, apprise sur GEDI, est admise. GEDI brut n'a pas ce problème.

**Fenêtre temporelle.** La fenêtre commune aux deux jeux est 2019 (début de GEDI)
→ dernière campagne, moins les années trouées. FORMS-T commence en 2018, mais on
l'aligne sur GEDI pour comparer à données égales. Cela fait environ 6 campagnes ×
environ 86 SER, soit à peu près 500 observations. Les campagnes 2005-2018 restent
utilisables en estimation directe seule.

**Précalcul.** Agréger FORMS-T et GEDI sur toute la France métropolitaine est
lourd. Le calcul se fait dans `data-raw/build_ifn_production.R`, comme les tables de
la spec 040, et le paquet n'embarque qu'un CSV. Jamais de raster dans le paquet ni
en base (ADR-002). Le run sur la France entière se lance dans un cgroup plafonné
(cf. mémoire « isoler les jobs lourds »). La colonne `covariables` de la table
indique le jeu retenu (`"forms_mnt"` ou `"gedi_l2a"`).

## 6. Livrables cœur

| Objet | Type | Rôle |
|---|---|---|
| `estimer_fay_herriot(direct, psi, X, methode = "REML", max_iter, tol)` | exportée | Moteur générique (§4). Réutilisable pour V, G, Dg. |
| `ifn_production_placettes()` | interne (`data-raw`) | PG/PV par placette depuis `ARBRE` (§3). |
| `inst/extdata/ifn_production_ser.csv` | table | Une ligne par niveau × ser × campagne × attribut (`pg`, `pv`) et par essence groupée (`tous`, `feuillus`, `resineux`) : `direct`, `psi`, `n_plac`, `estimation`, `mse`, `rse`, `gamma`, `nature`, `methode_pv`, `covariables`, `part_g_imputee`, `millesime`, `source`. |
| `ifn_production_ser(ser, greco, campagne, attribut, groupe)` | exportée | Accesseur filtrant, même idiome que `ifn_volume_essence_ser()`. |
| `ifn_production_reference(ser, attribut, groupe, campagnes)` | exportée | Valeur à appliquer à une UGF. Moyenne FH sur une fenêtre de campagnes, MSE propagée. Attributs `niveau` et `nature`. |
| `ifn_taux_prelevement_production(ser, groupe)` | exportée | Ratio prélèvement/production avec son incertitude (§7.2). |

**Pas de déclinaison par essence au lot 1.** Par SER, une essence a souvent moins
de 10 placettes par campagne : le FH tiendrait mais serait surtout synthétique.
Feuillus/résineux est le grain le plus fin défendable. L'essence viendra
éventuellement au lot 6, avec un FH multivarié (hors périmètre, §10).

**Au lot 1, le FH ne porte que sur le groupe `tous`.** Les groupes feuillus et
résineux restent en **estimation directe** (`nature = "direct"`, MSE = ψ). Une SER
presque sans résineux a des directs nuls avec ψ = 0. Le FH les enverrait sur la
voie synthétique, qui régresse sur la hauteur de *toute* la forêt et
inventerait une production résineuse. Un FH par groupe demandera des covariables
par groupe (part de résineux, par exemple via la BD Forêt) : c'est un lot ultérieur.

Règle 5 : chaque fonction exportée a son test dans `tests/testthat/`.

## 7. Les consommateurs — points 1 à 6

### 7.1 P2 (station / productivité) — consommateur principal

**Aujourd'hui** : `indicateur_p2_station()` (`R/indicators-productive.R:334`) a
deux modes :
- le mode historique lit `annual_increment_m3_ha_yr` dans
  `productivity_tables.csv` (ONF 2021) par essence × fertilité × climat ;
- le mode CHM calcule un indice de station H₀ (courbes Duplat & Tran-Ha).

**Après** : un troisième mode `source = "ifn_fh"` donne
`P2 = ifn_production_reference(ser, "pv", groupe)`, en m³/ha/an. C'est l'unité du
mode historique, donc la normalisation existante s'applique telle quelle.

Garde-fous :
- **Défaut inchangé** (rétrocompatibilité stricte, comme `chm = NULL`). Le mode FH
  est opt-in jusqu'à validation sur un cas réel.
- La valeur est celle du **domaine**, pas de la station de l'UGF. On écrit un
  attribut `p2_provenance` (`"ifn_fh_ser"`, `"ifn_fh_greco"`, `"table_onf"`,
  `"site_index_chm"`) et un attribut `p2_rse`.
- **Combinaison possible** avec le mode CHM : le FH donne le niveau régional, le
  site index module à l'intérieur du domaine. C'est la décision D5 ; par défaut,
  pas de combinaison au lot 2.

**Livré au lot 2 (v0.202.0)**, avec deux écarts au plan :
- **Les colonnes plutôt que des attributs** : `P2_rse`, `P2_provenance`
  (`"ifn_prod_ser"`, `"ifn_prod_greco"`, `"ifn_prod_national"`) et `P2_nature`.
  Elles varient d'une UGF à l'autre, et elles n'apparaissent **qu'en mode
  `ifn_fh`**. Les modes historique et CHM gardent exactement leur sortie.
- **Toujours le groupe `tous`**, pas le groupe de l'essence. Dans la table, la
  production d'un groupe est rapportée à l'hectare de **toute** la forêt de la SER
  (les placettes sans ce groupe comptent pour zéro), pour que les groupes
  s'additionnent. C'est une contribution, pas la production d'un hectare de
  peuplement de ce groupe. Une pessière de E10 aurait reçu 2,05 m³/ha/an
  « résineux », contre 5,31 pour la SER entière. Une production par hectare de
  peuplement du groupe demandera un dénominateur « placettes de présence », comme
  `vol_ha_present` dans la spec 040 : c'est un lot ultérieur.

La SER manquante ou vide passe au national, une SER inconnue à sa GRECO. Sur 5
campagnes, la RSE de P2 vaut environ 2 à 3 % (borne basse, campagnes supposées
indépendantes).

### 7.2 Spec 040 — le ratio prélèvement/production

La spec 040 §5.a cite ce ratio comme forme de publication IFN, sans pouvoir le
calculer : le cœur n'a que le stock et le prélèvement.
`ifn_taux_prelevement_production()` le calcule par SER × groupe avec les mêmes clés
que `ifn_prelevement_essence_ser.csv`.

**Livré au lot 2 (v0.202.0).** Le prélèvement vient des attributs `prel`
(définition IGN, codes 6 et 7) et `prel_vidange` (code 6) de la table du lot
1-bis, et non de `ifn_prelevement_essence_ser.csv`. La raison : il est calculé par
SER × campagne, sur la même fenêtre de croissance que la production et avec le
même dénominateur. **C'est le prélèvement qui fixe le niveau** (SER, GRECO ou
national). La production est prise au même niveau et sur les mêmes campagnes.

**Garde-fou `min_plac = 30`**, ajouté à `ifn_production_reference()` : une
estimation **directe** reposant sur moins de 30 placettes sur la fenêtre ne
qualifie pas son niveau. Le cas qui l'a imposé est F13, les « Marais
littoraux » : 2 à 3 placettes revisitées par campagne, une seule coupe donnait 79
m³/ha/an et un ratio de 6,2. Le Fay-Herriot n'est pas soumis au seuil.

**Résultat** : ratio national 0,68 (IGN 0,61). Sur les 86 SER, la médiane est de
0,57 et le maximum de 1,51 (C11, RSE 24 %). Les SER au-dessus de 1 (C11, G23,
E20, G21, G41, C12) sont dans le Nord-Est et l'Est, ce qui cadre avec les coupes
sanitaires de la crise des scolytes. 85 SER ont un prélèvement qualifié, une
remonte à sa GRECO.

Le piège « fenêtres non alignées » ne se pose plus : le prélèvement de la
campagne t (placettes revisitées en t) et la production de la campagne t (cernes
t−5 à t−1) couvrent les mêmes saisons.

**Trois pièges à traiter** :
- **Le prélèvement IGN n'est pas celui de la spec 040.** L'IGN compte un arbre
  coupé « que la grume soit vidangée ou non » (méthodologie 2023, p. 19), alors que
  la spec 040 ne retient que `VEGET5 == "6"` (vidangé). Pour un ratio
  prélèvement/production au sens IGN, il faut compter les codes 6 **et** 7, et
  garder le code 6 seul pour la desserte. Le ratio expose les deux variantes,
  nommées.
- **Le prélèvement de la spec 040 est mesuré au premier passage** (approximation
  assumée §5.c), alors que la production porte sur les 5 ans *avant* la campagne.
  Les deux fenêtres ne coïncident pas : il faut aligner sur des campagnes communes
  et le documenter.
- **Le biais résiduel (lot 1-bis, §3.c).** Au niveau national, le ratio vaut
  0,67, contre 0,61 pour l'IGN, soit environ +10 %. Il faut l'afficher avec
  cette réserve. Un ratio de SER légèrement au-dessus de 1 ne prouve pas une
  décapitalisation.
- **L'incertitude du ratio.** La production a une MSE FH, le prélèvement n'a qu'une
  estimation directe. On propage par la méthode delta, en supposant
  l'indépendance, et on le dit. Un ratio supérieur à 1 n'est pas une erreur : c'est
  une SER qui décapitalise.

### 7.3 P1 (volume) et C1 (biomasse) — le repli continu remplace le repli en escalier

**Aujourd'hui** : `.ifn_cascade()` (`R/ifn_tables.R:48`) et
`completer_volume_ifn()` descendent SER → GRECO → national **dès que le nombre de
placettes passe sous `min_plac`** (30 par défaut). Une SER à 29 placettes est
jetée en bloc au profit de la GRECO.

**Après** : `estimer_fay_herriot()` appliqué à V par SER (`ifn_volume_essence_ser`
au grain `tous` / `feuillus` / `resineux`) donne un repli **continu**. γ dose la
moyenne de la SER et la prédiction synthétique, et chaque valeur a une MSE.
`completer_volume_ifn(methode = c("cascade", "fay_herriot"))`, avec `"cascade"`
par défaut. La provenance ligne à ligne de la spec 040 D8 gagne la valeur
`"ifn_fh_ser"`. Une mesure n'est **jamais** écrasée, ce qui est inchangé.

**C1** (`R/indicators-families.R:337`) passe par V × ρ × BEF × C_frac : il hérite du
gain **sans modification de code**, dès que l'UGF reçoit un V complété par FH. Il
faut seulement un test qui le vérifie.

L'article obtient pour V le meilleur ajustement de ses cinq attributs (R² 0,81 sur
les agences, 0,72 sur les unités territoriales).

### 7.4 E1 (bois-énergie) et E2 (évitement) — passer du stock au flux

**Aujourd'hui, vérifié** : `indicateur_e1_bois_energie()`
(`R/indicators-energy.R:37`) calcule
`annual_harvest_m3_ha = volume × harvest_rate`, avec `harvest_rate = 0.02`. C'est
**2 % du stock sur pied**, quel que soit le peuplement. Un peuplement capitalisé à
faible croissance reçoit ainsi plus de bois-énergie qu'un peuplement jeune en
pleine production. Le contresens est structurel.

**Après (D6 : le flux remplace le stock)** : nouveaux arguments
`production_field = NULL` et `taux_mobilisation = NULL`.

- **`production_field` fourni** :
  `annual_harvest_m3_ha = production × taux_mobilisation`. Le volume sur pied et
  `harvest_rate` ne servent plus à E1. S'ils sont aussi fournis, ils sont ignorés
  avec un avertissement, pour ne pas laisser croire qu'ils comptent.
- **`taux_mobilisation` n'a pas de défaut inventé.** Deux sources admises :
  - une valeur explicite de l'appelant ;
  - `taux_mobilisation = "ifn_ser"` : la part de la production effectivement
    récoltée dans la SER, c'est-à-dire le ratio prélèvement/production du §7.2,
    plafonné à 1.
  Avec `production_field` mais sans `taux_mobilisation`, E1 s'arrête avec une
  erreur explicite, plutôt que de supposer une valeur.
- **`production_field = NULL`** (défaut) conserve exactement le comportement
  actuel. La rétrocompatibilité est stricte, et les scores existants ne bougent pas
  tant que l'appelant ne bascule pas.

**Normalisation : à refaire, pas à revérifier.** Le `ref_max` actuel (1,32 t
MS/ha/an) est calé sur le plafond de P1 (800 m³/ha × 2 %). Avec un flux, le plafond
devient « production haute × taux_mobilisation maximal ». Il doit être recalé sur la
distribution réelle des PV FH par SER (par exemple leur 95ᵉ centile), et
**seulement en mode flux**. Le mode stock garde son `ref_max`, sinon les scores des
projets existants changeraient. Il faut un test qui vérifie que les deux modes
gardent chacun leur plafond.

**Piège de dégénérescence, à traiter au lot 4.** Si la production vient du FH par
SER (`ifn_production_reference()`) **et** que `taux_mobilisation = "ifn_ser"`, alors
`production_SER × (prélèvement_SER / production_SER) = prélèvement_SER`. E1 ne
mesure plus une ressource soutenable, il **recopie la récolte observée** de la SER,
identique pour toutes les UGF du domaine. Le mode `"ifn_ser"` n'a de sens que si la
production est **propre à l'UGF**, par exemple P2 en mode site index CHM, ce qui
renvoie à la combinaison reportée en D5. Le lot 4 doit donc :
- **détecter** ce cas, c'est-à-dire une production de provenance `ifn_fh_*` avec un
  taux `"ifn_ser"` ;
- **avertir** explicitement ;
- **écrire** l'attribut `e1_mode = "recolte_observee"` au lieu de
  `"ressource_flux"`, pour que l'app ne le présente pas comme un potentiel.

Un test verrouille l'égalité E1 = prélèvement × facteur énergie dans ce cas, et
l'avertissement.

**Pourquoi remplacer plutôt que plafonner.** Plafonner aurait gardé le stock comme
moteur, et le contresens avec lui : à faible production, le plafond mord ; ailleurs,
c'est encore 2 % du stock. Remplacer rend E1 cohérent avec ce qu'il prétend
mesurer, une ressource renouvelable. Le coût est un changement de valeurs plus
marqué, absorbé par l'opt-in.

**E2** (`R/indicators-energy.R:139`) lit `E1` (`fuelwood_field = "E1"`) : il
hérite, sans modification de code.

### 7.5 B2 (structure) — conforté, pas modifié

L'article montre que l'hétérogénéité verticale (rh98_sd) explique la productivité à
l'échelle des unités territoriales (§4.1, avec Cordonnier et al. 2018 et Bouvier et
al. 2015). C'est la composante CV(CHM) de `indicateur_b2_structure()`.
**Aucun code** : on ajoute la référence à `inst/REFERENCES.md` et à la roxygen de B2
comme justification de la composante.

### 7.6 T2 / R3 / R5 — dimension temporelle, en prospective

L'empilement domaine × campagne produit une **série annuelle de PG/PV par SER avec
intervalle de confiance**. C'est un candidat naturel pour signaler un
ralentissement de croissance (sécheresse, dépérissement).

**Ce qu'on ne fait pas** : brancher cette série sur T2, R3 ou R5. L'article ne
détecte aucune tendance sur 2019-2022 (§4.3). Une campagne IFN mesure 5 ans de
cernes, donc deux campagnes successives partagent 4 cernes sur 5 et la série est
**lissée par construction**. Un signal de dépérissement y arriverait avec plusieurs
années de retard sur FORDEAD.

**Ce qu'on fait** : `ifn_production_ser()` expose la série. Un futur chantier
pourra croiser cette série avec le SPEI ou E-OBS (spec 034), avec un FH
spatio-temporel (Rao & Yu 1994). C'est hors périmètre.

### 7.7 Transverse — incertitude et NDP

- **La RSE n'entre pas dans le NDP.** Le NDP mesure la qualité des *données
  d'entrée de l'UGF* (règle 7, ADR-011). Une valeur de domaine IFN reste du NDP 0,
  quelle que soit sa RSE. La RSE est portée en **attribut** (`p2_rse`, MSE dans
  `completer_volume_ifn`) pour l'affichage.
- **Plan de validation** : les auteurs proposent de stratifier l'échantillonnage
  terrain par GEDI (§4.3). Pas de branchement :
  `create_validation_sampling_plan(weighting = "continuous")` accepte déjà un raster
  de poids quelconque.

## 8. Pièges identifiés à l'avance

1. **Unités d'IR5** : mètres dans la table, pas dixièmes de mm. Un facteur 10⁴ se
   détecte au contrôle national. On le verrouille par un test.
2. **IR5 manquant n'est pas IR5 nul.** Arbres simplifiés, noyers, chêne vert : les
   mettre à 0 sous-estime la production. Il faut les imputer à la placette (rapport
   PG/G des arbres mesurés de la même essence groupée) ou exclure la placette.
   C'est la décision D7.
3. **Lignes de revisite** : comme pour `VEGET5`, on ne lit `IR5` que sur la ligne de
   premier passage.
4. **Un domaine-année avec 1 placette** n'a pas de ψ (§4).
5. **σᵥ² tronqué à 0** : il faut avertir, pas se taire.
6. **Estimation synthétique présentée comme une mesure** : le champ `nature` est
   obligatoire, comme la provenance de la spec 040 D8.
7. **Indépendance des domaines** : l'article la vérifie par le I de Moran sur les
   résidus (non significatif). On refait ce test au lot 1, sur les SER. S'il est
   significatif, on passe à un FH spatial, et c'est une décision à remonter.
   **Constaté et tranché au lot 1** : significatif sans effet régional ; la GRECO
   en effet fixe le retire (§3.b).
8. **Masquage de forêt des covariables** : FORMS-T doit être agrégé **sous masque
   forêt**, pas sur toute la SER. Sinon, la hauteur moyenne mesure le taux de
   boisement.
9. **Circonférence passée d'un arbre imputé.** `C_passé = C13 − 2π·IR5` est vide
   quand IR5 l'est. Si on ne la recalcule pas par `C13·√(1 − rg)`, le test de
   recrutement renvoie `NA` et l'arbre **sort silencieusement de la somme**.
   Vérifié au lot 0 : ce bug fait tomber PV à 2,25 m³/ha/an au lieu de 4,61, car
   47 % de G disparaît sans aucune erreur. Un test le verrouille.

## 9. Décisions — tranchées le 2026-10-01

| # | Question | Décision |
|---|---|---|
| D1 | Méthode PV et règle de recrutement | **PG d'abord** (exacte). PV par la voie (a), forme et hauteur constantes. Le lot 0 la mesure à **−15 %** de l'IGN (§3.a, point 5) : **acceptée**. Lot 1-bis : la voie (b) (hauteur) et la production des arbres coupés (revisite, croissance sur 2,5 ans), pour viser l'écart restant. Recrutement : diamètre 7,5 cm, **confirmé** par la méthodo IGN 2023. |
| D2 | Domaines | SER × campagne au lot 1 ; domaines utilisateur (UT ONF, massif) au lot 5. |
| D3 | Covariables | **Deux jeux, comparés** : GEDI L2A brut (G) et FORMS-T hauteur + MNT (F). Critères fixés à l'avance (§5.b) ; F en cas d'égalité. |
| D4 | Moteur | **Maison**, en R de base ; `sae` en `Suggests` pour le test d'égalité (§4). |
| D5 | P2 | FH seul au lot 2 ; combinaison avec le site index CHM plus tard, sur un cas réel. |
| D6 | E1 | **Le flux remplace le stock** : `production × taux_mobilisation`, sans défaut inventé pour le taux (valeur explicite ou ratio IFN de la SER). Opt-in, `ref_max` propre au mode flux (§7.4). |
| D7 | IR5 manquant | **Amendée au lot 0** : l'imputation est le régime normal (47 % de G depuis 2014, plan de carottage IGN). On impute `rg` en cascade placette × essence × catégorie de dimension → placette × essence → placette. On n'exclut la placette que si plus de 50 % de sa G reste **sans valeur après imputation** (1,85 % de G au total). La part imputée est publiée par domaine (`part_g_imputee`). |
| D8 | Fenêtre de `ifn_production_reference()` | 5 dernières campagnes, configurable par `campagnes`. |

## 10. Hors périmètre

- FH multivarié : additivité des essences, ou PV et V conjoints (Benavent & Morales
  2016).
- FH spatial et spatio-temporel (Rao & Yu 1994) : seulement si le test de Moran le
  justifie (§8.7).
- Déclinaison par essence.
- Branchement sur T2, R3 ou R5 (§7.6).
- Toute modification de `nemetonshiny` : un brief suivra le lot 4, déposé dans
  `specs/054-…/brief-nemetonshiny.md` et notifié dans
  `/home/pascal/dev/briefs/vers-nemetonshiny/` (règle 11).

## 11. Découpage en lots

Chaque lot = une release (consignes de release de `CLAUDE.md`).

| Lot | Contenu | Bump | Prérequis |
|---|---|---|---|
| 0 | ✅ 2026-10-01 — relevés §3.a : chiffre IGN 87,9 Mm³/an (5,4 m³/ha/an), recrutement confirmé, carottage partiel depuis 2014 (D7 amendée), contrôle voie (a) à −15 %, trou GEDI 2023-2024, accès Earthdata non configuré | — (doc) | — |
| 1 | ✅ v0.200.0 — `estimer_fay_herriot()` + tests (égalité `sae`, σᵥ² = 0, n = 1, domaine vide) ; `data-raw/build_ifn_production.R` ; PG/PV par placette ; jeu F ; FH SER × campagne + GRECO ; `ifn_production_ser.csv` + accesseurs ; contrôle national ; test de Moran (§3.b) | minor | D1, D3, D4, D7 |
| 1-bis | ✅ v0.201.0 — voie (b) par allométrie hauteur-diamètre, production des arbres coupés, attributs `prel` et `prel_vidange` (§3.c) | minor | lot 1 |
| 1-ter | Jeu G (GEDI L2A) et comparaison avec F selon §5.b | patch ou minor | accès Earthdata |
| 2 | ✅ v0.202.0 — P2 `source = "ifn_fh"` + colonnes de provenance/RSE/nature ; `ifn_taux_prelevement_production()` ; `min_plac` (§7.1, §7.2) | minor | lot 1-bis, D5 |
| 3 | `completer_volume_ifn(methode = "fay_herriot")` ; test d'héritage C1 | minor | lot 1 |
| 4 | E1 `production_field` + `taux_mobilisation` + `ref_max` propre au mode flux ; détection du cas dégénéré FH-SER × `"ifn_ser"` (§7.4) ; test d'héritage E2 ; référence B2 ; brief app | minor | lot 2, D6 |
| 5 | Domaines utilisateur (UT ONF, massif) | minor | lot 1, D2 |

## 12. Références

- Onwunji et al. (2026), Ann. For. Sci. 83:46 — source de la méthode.
- Fay R.E., Herriot R.A. (1979), JASA 74:269-277.
- Rao J.N.K., Molina I. (2015), *Small Area Estimation*, 2ᵉ éd., Wiley.
- Breidenbach J., Astrup R. (2012), Eur. J. For. Res. — FH appliqué à l'inventaire forestier (référence complète dans la bibliographie de l'article).
- Schwartz M. et al. (2023), ESSD 15:4927-4945 — FORMS.
- IGN, *Documentation des données brutes de l'inventaire forestier*, v2.4
  (14/10/2025), fichier ARBRE.csv, variable IR5.
