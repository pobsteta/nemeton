# Spec 065 — Règles chiffrées tirées des guides (relevé du 2026-11-10)

> **Statut** : relevé de travail, **aucune entrée du catalogue n'est encore
> remplie**. Décisions D-9 à D-11 ci-dessous à valider par Pascal.
> Les guides sont sous droits : textes et PDF restent dans
> `data-raw/references/itineraires/` (ignoré par git) ; leurs citations
> complètes sont dans `data-raw/references/README.md`. Ici, seulement les
> valeurs et leur page, pour qu'une entrée du catalogue puisse les citer.

## 1. Ce qui fait foi en BFC

L'arrêté approuvant le règlement type de gestion (RTG) de la DRA Bourgogne
(ministère de l'Agriculture, 2021, § 3.1-3.13) désigne, par type de
peuplement, le guide ONF applicable en forêt publique :

| Peuplement | Guide désigné | Disponible localement |
|---|---|---|
| Chênes (hors Nivernais, Sologne bourb., Bazois, Puisaye) | *Chênaies continentales* (Sardin 2008) | tronqué à la p. 200 / 415 |
| Chênes (ces quatre régions) | *Chênaie atlantique* (Jarret 2004) | tronqué à la p. 69 |
| Hêtre, futaie régulière | *Hêtraies continentales — référentiel FR* (ONF 2012) | **non** |
| Hêtre, futaie irrégulière | *Hêtraies continentales — référentiel FI* (ONF 2013) | **complet** |
| Sapin pectiné | *Mémento sapinières du Morvan* | **non** |
| Épicéa commun | guide de l'arc jurassien (sapin et épicéa) | **non** |
| Douglas | *Douglasaies françaises* (Angelier 2007) | **non** |
| TSF chêne-hêtre | RTG § 3.11 lui-même : aucun chiffre (« à adapter ») | — |
| Évolution naturelle | RTG § 3.13 : « exempts de toute intervention sur le long terme » | — |

Complément privé Franche-Comté : *Les éclaircies résineuses en
Franche-Comté* (SFFC, CRPF, 2012), complet.

## 2. Futaie irrégulière — hêtraies continentales (ONF 2013)

Domaine : forêts publiques des DT Alsace, Bourgogne-Champagne-Ardenne,
Franche-Comté, Lorraine (p. 3). Hêtre essence objectif principale,
essences objectif associées favorisées (p. 11).

| Règle | Valeur | Page |
|---|---|---|
| Prélèvement (hors peuplements éloignés de l'équilibre) | 15 à 25 % de G avant coupe | p. 7 |
| Diamètre d'exploitabilité, qualité B/C | 55-65 cm (A/B 65-75 ; D 40-45) | p. 8 |
| Pas de coupe si G avant coupe ≤ 14 m²/ha (≤ 16 en fertilité exceptionnelle), sauf arbres mûrs | — | p. 17 |
| Rotation, type 2 (équilibré), fertilité bonne à moyenne (Ho 24-35 m) | G < 18 : 8-9 ans ; 18-22 : 7-8 ; ≥ 22 : 6-7 | tab. 1, p. 17 |
| Idem, fertilité médiocre (Ho ≤ 23 m) | G < 18 : 10-12 ans ; 18-22 : 8-9 ; ≥ 22 : 7-8 | tab. 1, p. 17 |
| Accroissement en G, fertilité bonne à moyenne | 0,4-0,6 m²/ha/an | tab. 1, p. 17 |
| Capital à l'équilibre, échelle forêt (précomptables) | 15-17 m²/ha cas général ; 17-19 excellent ; 13-15 médiocre | tab. 7, p. 29 |
| Étage non précomptable à maintenir | 2-3 m²/ha (3-4 à l'équilibre) | p. 10, p. 29 |
| G cible après coupe en fonction de G avant coupe | **courbe, illisible dans le texte extrait** | fig. 2, p. 17 |
| Structure cible (Dexp ≥ 55 cm) | PB 15-20 %, BM 30-45 %, GB 40-50 % de G | tab. 8, p. 30 |
| Perches (essences objectif) | ≥ 120 /ha, dont ≥ 40 d'avenir | tab. 9, p. 31 |
| Première coupe de conversion d'un TSF (charme > 7 m²/ha) | rotation suivante 7-8 ans ; 10 ans si station pauvre ou G < 10 m²/ha | p. 15 |

Adéquation au moteur (`simuler_itineraire()`) : **bonne**. Les règles sont
en surface terrière, diamètre, intensité et rotation, ce que le moteur
applique. Deux écarts : la rotation (D-9) et la courbe de la figure 2, à
lire sur le PDF.

## 3. Futaie régulière de chêne sessile (*Chênaies continentales*, 2008)

Lu jusqu'à la p. 200 ; pages du fichier = folio imprimé + 1.

| Règle | Valeur | Page |
|---|---|---|
| Trois sylvicultures | dynamique (cernes > 2,5 mm), classique (≤ 2,5 mm), détourage | p. 77 |
| Diamètres d'exploitabilité | A-B 75-80 cm ; C 65 ; D 55 | p. 73 |
| Classes de fertilité (H100, Duplat et Tran-Ha) | 32,5 / 27,5 / 22,5 m | p. 188-190 |
| Objectifs, dynamique, fertilité 2, qualité A-B | 150-160 ans, 60 tiges/ha, bille 9-10 m | tab. 13, p. 79 |
| Normes après éclaircie | N(Ho) en expansion, G(Ho) en maturation, ± 10 % | p. 183, 198 |
| Première éclaircie | Ho ≥ 14 m (diamètre moyen ~15 cm) | p. 161, 199 |
| Coupe d'ensemencement (G > 20 m²/ha) | 40-50 % des tiges, ≥ 1/3 du volume ; G après ≤ 15 m²/ha | p. 122 |
| Durée de la régénération | 4 (pédonculé) à 12 ans (sessile) | p. 123 |
| Arbres bio | ≥ 1 arbre creux /ha ; ≥ 1 mort ou sénescent ≥ 35 cm /ha | p. 91-92 |
| Îlots de sénescence (forêt domaniale) | ~1 % de la surface | p. 92 |

**Manquent (troncature)** : tableaux 28-29 (N, G après éclaircie et
rotations en fonction de Ho, folios 197-203), conversion du TSF
(folios 253-263), futaie irrégulière à chêne (folios 265-299), annexe 12
(référentiels du sessile, folio 406). Rien n'est simulable sans eux.

## 4. Résineux en futaie régulière (SFFC 2012, Franche-Comté)

Sapin, épicéa, mélèze d'Europe, douglas ; futaie régulière seulement (p. 2).

| Règle | Valeur | Page |
|---|---|---|
| Rotation | 4-6 ans jusque vers 40 ans, puis 7-10 ans | p. 21 |
| Nombre d'éclaircies | 4 à 6 | p. 21 |
| Première éclaircie (départ > 1 000 tiges/ha) | 40-60 % des tiges, 30-45 % de G | p. 16 |
| Éclaircies suivantes | 25-35 % des tiges, 20-30 % de G | p. 21 |
| Diamètre d'exploitabilité | 45-65 cm | p. 18 |
| Densité finale, épicéa-sapin | 300-350 (Dexp 45), 250-300 (55), 200-250 (65) tiges/ha | p. 18 |
| Densité finale, douglas-mélèze | 230-300 (45), 180-230 (55), 150-180 (65) tiges/ha | p. 18 |
| Stabilité | Ho/Dg < 80 ; > 100 : toute intervention très risquée | p. 10-11 |
| Rattrapage (Ho/Dg 80-100) | ≤ 25 % des tiges tous les 3-4 ans | p. 23 |

Lecture brouillée à vérifier sur le PDF : la formule du facteur
d'espacement (p. 10), l'attribution des lignes de la table p. 16, l'exemple
d'épicéa p. 22.

## 5. Modèle de forme : hêtraie nord-atlantique, futaie régulière (ONF 2020)

Hors BFC, mais seul guide disponible avec des **tables complètes âge × Ho
× N × G × Dg avant et après éclaircie** (annexe 2, p. 32-34), par classe de
fertilité. Exemple F1 : 28 ans, Ho 20,8 m, 612 tiges, G 17,1, Dg 19 cm
après éclaircie ; 74 ans, Ho 37,4 m, 58 tiges, G 19,4, Dg 65 cm. C'est le
format qu'il faudrait pour les futaies régulières de BFC.

## 6. Décisions proposées

| # | Question | Proposition |
|---|---|---|
| D-9 | Rotation du guide (6-9 ans) contre pas de FINN (5 ans, fixé par les revisites IFN) | **(b)** couper tous les 10 ans avec un prélèvement × 10 / rotation du guide, plafonné à 25 % de G (FI, p. 7) ; rotation d'origine et conversion écrites dans l'entrée. Alternatives : (a) arrondir à 5 ou 10 ans ; (c) ne retenir que les cas à 10 ans |
| D-10 | Futaie régulière : toutes les normes sont en fonction de Ho, que FINN ne porte pas | indexer les règles sur le **diamètre quadratique moyen Dg**, que FINN porte : les tables des guides (âge, Ho, N, G, Dg) donnent N et G cibles par Dg sans passer par la hauteur. Demande d'étendre `simuler_itineraire()` (règle `norme_densite` : table Dg → N ou G après éclaircie). Alternative : relation hauteur-diamètre (même question que D-9 de la spec 068, T4) |
| D-11 | Fourchettes des guides (55-65 cm, 15-25 %…) | valeur centrale par défaut (60 cm, 20 %), la fourchette citée dans l'entrée ; une variante par borne si l'utilisateur le demande |

## 7. Ce qui débloque la suite

1. Captures des figures 2, 4, 6, 8, 10 du référentiel FI (p. 17, 19, 21,
   23, 25) → première entrée réelle : futaie irrégulière de hêtre.
2. PDF complet de *Chênaies continentales* (extraction locale) → tableaux
   28-29, conversion du TSF, futaie irrégulière à chêne.
3. *Hêtraies continentales FR* (2012), *Douglasaies françaises*, guide de
   l'arc jurassien, mémento des sapinières du Morvan.
