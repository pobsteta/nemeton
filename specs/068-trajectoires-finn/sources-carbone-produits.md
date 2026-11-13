# Spec 068 — Sources du carbone des produits bois et de la substitution

*Relevé du 2026-11-11, pour lire la famille E (et le carbone hors forêt)
depuis `simuler_itineraire()` dans `comparer_itineraires()`. Méthode et
décisions en § 6. Pascal : « prends ce qu'il y a de mieux » ; décisions
D-E1 à D-E5 prises sur les propositions (§ 6.1) et codées en v2026.11.23.*

## 1. Pourquoi

Sur le premier vrai run (spec 068, note du 2026-11-11), la comparaison ne
lisait que P (volume prélevé) et C (carbone sur pied). Toute gestion y perd
en C sans contrepartie : le carbone qui sort de la forêt n'est compté nulle
part, ni comme stock dans les produits ni comme émissions évitées. Le
classement se réduisait alors au rapport des poids P:C. Il faut trois
paramètres, chacun sourcé : la ventilation du volume récolté entre usages,
la durée de vie des produits, les coefficients de substitution.

Les documents sont rangés dans `data-raw/references/carbone_produits/`
(PDF ignorés par git, liens en § 7). Tous sont publics.

## 2. Ventilation de la récolte : bois d'œuvre ou non

### 2.1 Part de bois d'œuvre potentiel par essence et diamètre (IFN, BFC)

**Source primaire, mesurée** : champs `Q1`, `Q2`, `Q3`, `R` de `ARBRE.csv`
(export IFN, IGN, Licence Ouverte ; documentation ARBRE.csv v2.4, p. 5).
Ils donnent la répartition en dixièmes du volume de chaque arbre entre la
qualité 1 (tranchage, déroulage, ébénisterie), la qualité 2 (sciages
courants, charpente, caisserie, coffrage), la qualité 3 (industrie,
chauffage) et le rebut. La qualité est celle que le bois permet
techniquement, pas son usage réel. Ces champs sont relevés de 2005 à 2013,
sur les arbres de circonférence d'au moins 0,705 m ; les petits bois sont
classés en qualité 3. À partir de 2014, `QUALITE` les remplace : une seule
classe par arbre, lue sur la bille de pied, qui ne donne pas de part de
volume.

L'étude ADEME-IGN-FCBA de 2016 (*Disponibilités en bois d'origine
forestière à l'horizon 2035*, tome 1 § 3.4.3-3.4.4 p. 30-31, annexe 17)
fonde son bois d'œuvre potentiel (BO-P = qualités 1 et 2) sur cette même
mesure. Elle le dit « le plus souvent une fourchette haute » : c'est une
présomption sur pied, et les défauts internes ne se voient pas.

Calcul pour la BFC (`data-raw/taux_bois_oeuvre_ifn.R`) : arbres vivants des
8 départements, campagnes 2005-2013, part Q1 + Q2 pondérée par volume × poids.

| Groupe | 10-20 cm | 25-30 | 35-40 | 45-50 | 55-60 | ≥ 65 | Toutes tailles |
|---|---|---|---|---|---|---|---|
| chênes (02, 03) | 0 | 0,63 | 0,84 | 0,88 | 0,89 | 0,89 | 0,73 |
| hêtre (09) | 0 | 0,60 | 0,84 | 0,89 | 0,90 | 0,91 | 0,69 |
| autres feuillus | 0 | 0,55 | 0,79 | 0,84 | 0,86 | 0,81 | 0,35 |
| sapin (61) | 0 | 0,62 | 0,86 | 0,97 | 0,98 | 0,99 | 0,78 |
| épicéa (62) | 0 | 0,62 | 0,86 | 0,96 | 0,96 | 0,97 | 0,70 |
| douglas (64) | 0 | 0,71 | 0,90 | 0,97 | 0,98 | 1,00 | 0,76 |
| autres résineux | 0 | 0,70 | 0,86 | 0,91 | 0,92 | 0,93 | 0,66 |

Effectifs : de 16 (douglas ≥ 65 cm) à 29 225 arbres par case ; les cases de
moins de 100 arbres sont le douglas et les autres résineux au-delà de
55 cm. Le reste du volume bois fort tige est du BIBE (bois d'industrie et
bois énergie). Le volume de `simuler_itineraire(volume = TRUE)` est lui
aussi un volume bois fort tige (tarifs de Schaeffer de l'IFN), donc la table
s'y applique directement, tige par tige, au diamètre de la coupe.

### 2.2 Récolte réelle, pour recaler la borne haute

**Agreste, enquête annuelle Exploitations forestières et scieries** (récolte
commercialisée, bois fort, hors autoconsommation) :

- BFC 2024 (*Études* n° 104, DRAAF BFC, 2026) : 5,23 Mm³, dont bois d'œuvre
  56 % (feuillus 0,81 Mm³, conifères 2,14), trituration 19 %, autre bois
  d'industrie 2 %, bois énergie 23 %.
- BFC 2023 (*Études* n° 91, mars 2025) : 5,30 Mm³, bois d'œuvre 58 %. La
  même note précise que le bois énergie de l'enquête n'est que la part
  professionnelle. Selon Fibois et l'Observatoire du bois énergie, la part
  hors professionnels (affouage, autoconsommation) dépasserait 3 Mm³ en BFC.
- France 2022 (tableau repris par la DRAAF Grand Est, octobre 2023) :
  39,9 Mm³, dont bois d'œuvre 20,0 (feuillus 5,3, conifères 14,7),
  trituration 9,7 (feuillus 3,9, conifères 5,8), autre bois d'industrie
  0,65, bois énergie 9,6.

En comptant les 3 Mm³ hors professionnels, le bois d'œuvre ne fait
qu'environ 36 % de la récolte totale de BFC (2,95 / 8,2), contre 69-78 % de
bois d'œuvre potentiel pour les essences principales (§ 2.1). L'écart tient
en partie aux essences (les « autres feuillus », 35 %, pèsent lourd dans le
bois de feu) et en partie à la borne haute. On ne peut pas recaler la
table 2.1 sur ces chiffres sans les ventiler par essence, ce que
l'enquête ne publie qu'en partie.

### 2.3 Part du BIBE qui va à l'industrie

Pas de source par essence trouvée. Ordres de grandeur en BFC 2024 :
trituration et autre bois d'industrie 1,05 Mm³ ; bois énergie 1,23 Mm³
professionnel, plus de 3 Mm³ hors professionnels. Le BIBE irait donc à
l'industrie pour environ un quart (1,05 / 4,3), et pour une part plus forte
chez les conifères : en France en 2022, la trituration est à 60 % résineuse
(5,8 / 9,7), alors que le bois de feu autoconsommé est surtout feuillu.

## 3. Durée de vie des produits

| Pool | Demi-vie | Source |
|---|---|---|
| Sciages | 35 ans | GIEC 2019, *Refinement*, vol. 4 chap. 12, tableau 12.3 p. 12.28 (d'après IPCC 2014) |
| Panneaux | 25 ans | idem |
| Papiers et cartons | 2 ans | idem |
| Produits du bois d'œuvre (BO) | 20 ans | INRA-IGN 2017, annexes, § A.4 I.2 p. A.4-3 et tableau 13.1 p. A.13-2 (taux 3,4 %/an ; Madignier et al. 2014, dires d'experts) |
| Produits du bois d'industrie (BI) | 5 ans | idem (13,9 %/an) |

Décroissance du premier ordre : `k = ln(2) / demi-vie`, la méthode du
niveau 1 du GIEC (équation 12.1). L'étude INRA-IGN ne garde que deux pools
(BO et BI) et ne suit pas séparément panneaux et papiers. Ses demi-vies sont
plus courtes que celles du GIEC.

## 4. Substitution

**Étude INRA-IGN 2017** (Roux, Dhôte et al., *Quel rôle pour les forêts et
la filière forêt-bois françaises dans l'atténuation du changement
climatique ?*, annexes, annexe 4 § II.4 p. A.4-16 à A.4-17 et tableau 13.1
p. A.13-2) :

- **Matériau** : 1,6 tCO₂/m³ de produit mis en œuvre (gamme 0,59-3,47).
  Les auteurs reprennent 28 des 36 études de la méta-analyse de Sathre et
  O'Connor (2010) ; ils écartent les comparaisons avec l'acier et deux
  valeurs aberrantes. Le coefficient vaut 1,0, 2,3 ou 4,3 tC/tC (bas, central,
  haut). Il est converti en tCO₂ par m³ de résineux (infradensité de 0,36 à
  0,44, teneur en carbone de 0,45 à 0,5 ; tableau 4.2). Il intègre les
  coproduits de la transformation (50 % du BO, 15 % du BI), qu'il ne faut
  donc pas recompter en substitution énergie. Le tableau 13.1 l'applique au
  BO et au BI.
- **Énergie** : 0,50 tCO₂/m³ de bois feuillu (gamme 0,37-0,64), d'après
  Oliver et al. (2014), pour un mix de 80 % de fioul et 20 % de gaz
  remplacés (tableau 4.3). Par tonne de bois : 0,70 tCO₂ face au gaz
  naturel, 0,97 face au fioul.
- **Rendement de transformation**, cohérent avec le taux de coproduits :
  bilan FFSM 2015 (annexe 14, tableau 14.5), 20,2 Mm³ de bois d'œuvre
  résineux consommé pour 10,7 Mm³ de sciages, soit 0,53 ; 5,1 Mm³ de bois
  d'œuvre feuillu pour 2,3 Mm³ de sciages, soit 0,45, plus des placages.

**Recoupement** : Leskinen et al. (2018, *From Science to Policy* 7, EFI)
trouvent un coefficient moyen de 1,2 tC évitée par tC de produit (433
coefficients tirés de 51 études ; 95 % entre -1,3 et 9,3). Ces chiffres
viennent de la présentation de l'EFI : le rapport lui-même n'a pas été lu.
Les auteurs mettent en garde contre un usage isolé du coefficient.

**Dans le cœur** : `indicateur_e2_evitement()` lit
`inst/extdata/ademe_emission_factors.csv`. Énergie : 0,222 kgCO₂/kWh face au
gaz, 4 500 kWh par tonne sèche, soit 0,999 tCO₂/t, au-dessus des 0,70 de
l'étude INRA-IGN face au gaz. Matériau : 1,14 kgCO₂/kg face au béton,
1,89 face à l'acier, cités « ADEME Base Carbone 2023 » sans référence
d'élément. **Ces valeurs n'ont pas été retrouvées dans une source
primaire** ; à vérifier avant de les réutiliser pour les trajectoires.

## 5. Bois mort (pour la famille B)

Tableau 13.1 de l'étude INRA-IGN (d'après Zell et al. 2009) : décomposition
annuelle du bois mort de 2,3 % chez les feuillus (demi-vie 30 ans), 6,9 %
chez les résineux (10 ans) et 13,9 % pour les pertes d'exploitation
(5 ans). `simuler_itineraire()` connaît déjà la mortalité naturelle (FINN et
plafond de densité) : avec ces taux, on peut en tirer un stock de bois mort
le long de la trajectoire, l'un des rares indicateurs de B que FINN puisse
porter sans hauteur. Les gros bois vivants (diamètre ≥ 67,5 cm, à la
manière de l'IBP) en sont un autre.

## 6. Méthode proposée et décisions à prendre

À chaque coupe, pour chaque cohorte coupée (essence, diamètre, volume bois
fort tige) :

1. **BO** = volume × taux du § 2.1 (essence, diamètre) ; **BIBE** = le reste.
2. **BIBE → BI ou BE** : part du BI paramétrable. **D-E1** : valeur par
   défaut (proposition : 0,25 pour les feuillus et 0,6 pour les résineux,
   ordres de grandeur du § 2.3, à défaut de mieux) ou pas de défaut,
   imposée à l'appelant comme `taux_recolte_materiau` dans E2.
3. **Produits** : 0,5 × BO et 0,85 × BI entrent en produits (rendements de
   l'étude INRA-IGN). **D-E2** : demi-vies INRA-IGN (20 et 5 ans,
   française, deux pools) ou GIEC (35, 25 et 2 ans, norme d'inventaire,
   sans ventilation entre panneaux et papiers dans nos données).
   Proposition : INRA-IGN, avec les mêmes sources que la substitution.
4. **Substitution** : 1,6 tCO₂/m³ de produit (BO et BI) ; 0,50 tCO₂/m³ de
   BE. Les coproduits ne sont pas recomptés.
5. **Carbone** : volume × infradensité de l'essence
   (`infradensite_espar()`) × 0,5, comme `carbone` aujourd'hui.

Nouvelles variables : `carbone_produits` (stock en tC/ha à chaque date,
décroissance du premier ordre) et `substitution` (cumul en tC/ha, ou en
tCO₂/ha pour rester dans l'unité de E2).

**D-E3, lecture dans `comparer_itineraires()`** : C = carbone sur pied +
carbone des produits, et E = substitution cumulée ? Ou C sur pied
seulement, avec une famille de plus ? Proposition : C = forêt + produits,
qui est le stock total et la lecture du GIEC, et E = substitution cumulée.

**D-E4, borne haute du bois d'œuvre** : prendre la table 2.1 telle quelle
(borne haute assumée et dite dans la sortie) ou la réduire par un facteur
global calé sur la récolte réelle (§ 2.2, non ventilé par essence).
Proposition : telle quelle, avec un argument `taux_bo` pour la remplacer.

**D-E5, bois mort et gros bois pour B** (§ 5) : à faire dans la même
version, ou après ?

### 6.1 Décisions prises (2026-11-11)

- **D-E1** : part du BIBE allant à l'industrie paramétrable
  (`parametres_filiere_bois()$part_bi`), défaut 0,25 pour les feuillus et 0,60
  pour les résineux, dite hypothèse dans la doc.
- **D-E2** : demi-vies INRA-IGN (BO 20 ans, BI 5 ans), même source que la
  substitution ; celles du GIEC sont citées dans la doc pour qui veut les
  substituer.
- **D-E3** : `carbone_total` = carbone sur pied + carbone des produits, lu
  en C par `comparer_itineraires()` ; E = `substitution` cumulée.
- **D-E4** : table IFN telle quelle (`parametres_filiere_bois()$taux_bo`,
  remplaçable), borne haute dite.
- **D-E5** : le bois mort et les gros bois de B dans une version suivante
  (livrés en v2026.11.24, spec 068, note du 2026-11-13).

L'énergie est comptée par tonne sèche (0,916 tCO₂/t, mix 80/20 de
l'étude), et non par m³ de feuillu : le même coefficient vaut ainsi pour
les résineux brûlés, plus légers.

Limites à dire dans la sortie :

- les coefficients de substitution sont des moyennes de la littérature,
  avec une gamme d'un facteur 6 ;
- le BO potentiel est une borne haute ;
- les pertes d'exploitation et les menus bois (houppier) ne sont pas
  suivis, car FINN ne porte que la tige.

## 7. Références

- IPCC (2019). *2019 Refinement to the 2006 IPCC Guidelines for National
  Greenhouse Gas Inventories*, vol. 4, chap. 12 *Harvested Wood Products*.
  <https://www.ipcc-nggip.iges.or.jp/public/2019rf/pdf/4_Volume4/19R_V4_Ch12_HarvestedWoodProducts.pdf>
- Roux A., Dhôte J.-F. (coord.) et al. (2017). *Quel rôle pour les forêts et
  la filière forêt-bois françaises dans l'atténuation du changement
  climatique ?* Étude INRA-IGN pour le ministère de l'Agriculture,
  annexes. <https://www.inrae.fr/sites/default/files/pdf/etude-forets-bois-et-changement-climatique-annexes-au-rapport-1.pdf>
- Colin A., Thivolle-Cazat A. (2016). *Disponibilités en bois d'origine
  forestière à l'horizon 2035*, ADEME-IGN-FCBA, tome 1 (rapport) et tome 2
  (annexes). <https://agriculture.gouv.fr/telecharger/82114>,
  <https://ofme.org/documents/FiliereBois/Rapports/201602_etude_ressource_ADEME_IGN_FCBA_annexes.pdf>
- IGN, export DataIFN 2005-2025, `ARBRE.csv` et documentation v2.4
  (14/10/2025), Licence Ouverte. <https://inventaire-forestier.ign.fr/dataIFN/>
- Agreste, DRAAF Bourgogne-Franche-Comté, *Études* n° 91 (mars 2025,
  récolte 2023) et n° 104 (2026, récolte 2024).
  <https://draaf.bourgogne-franche-comte.agriculture.gouv.fr/IMG/pdf/no91_exf_scierie_2025.pdf>,
  <https://draaf.bourgogne-franche-comte.agriculture.gouv.fr/IMG/pdf/no104_exf_2026.pdf>
- Agreste, DRAAF Grand Est, récolte 2022 (colonnes France métropolitaine).
  <https://draaf.grand-est.agriculture.gouv.fr/IMG/pdf/exfsri2022-29oct_corr.pdf>
- Leskinen P. et al. (2018). *Substitution effects of wood-based products
  in climate change mitigation.* From Science to Policy 7, European Forest
  Institute (non lu, chiffres de la présentation de l'EFI).
- Sathre R., O'Connor J. (2010). Meta-analysis of greenhouse gas
  displacement factors of wood product substitution. *Environmental
  Science & Policy* 13(2): 104-114 (référence telle que citée par l'étude
  INRA-IGN, annexe 4 ; article non lu).
- Zell et al. (2009), cité par l'étude INRA-IGN (tableau 13.1) pour les taux
  de décomposition du bois mort ; référence complète absente des annexes,
  non vérifiée.
