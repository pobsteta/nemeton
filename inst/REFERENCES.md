# Références — sources scientifiques et réglementaires

Bibliographie des sources de données et méthodes intégrées au package `nemeton`.

## Essences européennes — tolérances au repeuplement (spec 027)

Table `european_species_tolerances()` /
`inst/extdata/european_species_tolerances.csv`.

### Réglementaire (statut FRM)
- **Directive 1999/105/CE** du Conseil du 22 décembre 1999 concernant la
  commercialisation des matériels forestiers de reproduction — Annexe I
  (liste des essences réglementées).
- Proposition **COM(2023)415** de règlement FRM ; position du Parlement
  européen **A9-0142/2024** ; **accord politique du 8 décembre 2025** (ajouts
  Annexe I, non encore consolidés — statut `frm_2025`).

### Dendroflore / aires de répartition
- **San-Miguel-Ayanz, J., de Rigo, D., Caudullo, G., Houston Durrant, T.,
  Mauri, A. (eds.) (2016)**. *European Atlas of Forest Tree Species*.
  Publication Office of the European Union, Luxembourg.
- **Caudullo, G., Welk, E., San-Miguel-Ayanz, J. (2017)**. Chorological maps
  for the main European woody species. *Data in Brief* 12: 662–666.

### Tolérances écophysiologiques (axes sécheresse / ombre / engorgement)
- **Niinemets, Ü., Valladares, F. (2006)**. Tolerance to shade, drought, and
  waterlogging of temperate Northern Hemisphere trees and shrubs.
  *Ecological Monographs* 76(4): 521–547.
- **Münchinger, I. K. et al. (2023)** — tolérances hydriques.
- **Visakorpi, K. et al. (2024)** — les tolérances foliaires des semis ne
  prédisent pas toujours l'aire adulte (prudence d'usage).
- **EUFORGEN** — European Forest Genetic Resources Programme.
- **Valeurs indicatrices d'Ellenberg** (affinités écologiques).
- **ClimEssences** (RMT AFORCE) — compatibilité climatique des essences pour
  la France ; modèle IKS (sécheresse / froid hivernal / cumul de chaleur).
  <https://climessences.fr/>

### Prudence d'usage
1. La **provenance** prime souvent sur l'espèce.
2. Toujours **croiser avec la station** (sol, réserve en eau, exposition,
   altitude).
3. Les lignes `confidence = "faible"` (statut `atlas_jrc`) sont **dérivées par
   règle** — canevas de départ, à valider avant tout usage opérationnel.
4. La présence d'un taxon `invasif` dans la table **n'est pas une
   recommandation** de plantation.

## Références IFN par essence × sylvoécorégion (spec 040, lots 2-3)

Tables `inst/extdata/ifn_volume_essence_ser.csv` (volume **sur pied**, m³/ha) et
`inst/extdata/ifn_prelevement_essence_ser.csv` (**prélèvement**, m³/ha/an),
exposées par `ifn_volume_essence_ser()` / `ifn_volume_reference()` et
`ifn_prelevement_essence_ser()` / `ifn_taux_prelevement()`. Construites par
`data-raw/build_ifn_tables.R`.

### Source des données

**IGN — Inventaire forestier national français, Données brutes, campagnes
annuelles 2005 et suivantes**, <https://inventaire-forestier.ign.fr/dataIFN/>,
site consulté le 22/07/2026. Export **2005-2024** (le plus récent servi au
moment de la construction). **Licence Ouverte Etalab v2.0** — réutilisation
libre, citation demandée ci-dessus.

Les données sont téléchargées directement chez l'IGN par les fonctions
`ifn_campagne_disponible()` / `ifn_telecharger()` / `ifn_charger()`, réécrites
dans `nemeton` (`R/ifn_source.R`) — le package n'a **aucune dépendance** vers un
package tiers pour cela.

### Crédits méthodologiques

- **Max Bruciamacchie** (AgroParisTech Nancy) — méthode d'agrégation du volume
  par essence × SER, d'après `PPtools::CarteEssenceSer()`
  (<https://github.com/Bruciamacchie/PPtools>,
  <https://github.com/Bruciamacchie/DataForet>). Ces packages sont sous
  **GPL-2** ; autorisation explicite de reprise sous **GPL-3** donnée **par
  courriel le 22 juillet 2026**. La première version de la table a été
  construite depuis leurs `.rda` (campagnes 2005-2019) avant d'être refaite
  depuis la source IGN.
- **Jérémy Borderieux** (AgroParisTech) — `FrenchNFIfindeR`
  (<https://github.com/Jeremy-borderieux/FrenchNFIfindeR>, **GPL-3**) : accès
  programmatique à l'export brut de l'IGN, et le raccord `(IDP, A)` entre ligne
  de revisite et ligne de première visite, sans lequel le prélèvement est
  inexploitable. La capacité est **réécrite** ici, pas importée — cf. les cinq
  différences documentées dans `?ifn_charger`.

### Méthode

- **Volume sur pied** — par placette et par essence, `somme(V × W)` sur les
  arbres vivants (`VEGET == "0"`), `W` étant le poids d'extrapolation à
  l'hectare du plan de sondage IFN.
- **Prélèvement** — arbres dont l'état à la revisite est `VEGET5 == "6"`
  (*coupé vidangé*). Le code `7` (*coupé non vidangé*) est **exclu** : ce bois
  reste en forêt et ne circule jamais sur la desserte.
- Trois échelons emboîtés dans la même table : **SER** (86), **GRECO** (première
  lettre du code SER) et **national**.

### Prudence d'usage
1. **Volume sur pied ≠ prélèvement.** Le premier est un *stock*, le second un
   *flux*. Ne pas substituer l'un à l'autre.
2. Le prélèvement décrit **ce qui a été récolté**, pas ce qu'il faudrait
   récolter. Dimensionner une desserte dessus suppose « la gestion continue
   comme avant ».
3. **Deux colonnes par table, à ne pas confondre** : `*_present` (moyenne sur
   les seules placettes où l'essence est présente — figure de peuplement) et
   `*_maille` (contribution de l'essence à la maille, moyennée sur *toutes* ses
   placettes — figure de ressource). L'écart atteint un facteur 150 sur le
   peuplier cultivé.
4. **Deux approximations assumées sur le prélèvement** : le volume récolté est
   celui mesuré à la *première* visite (l'arbre a crû avant d'être coupé ; 92 %
   des arbres coupés ont une telle mesure), et la récolte observée sur
   l'intervalle de 5 ans est divisée par 5 — c'est une moyenne, pas un
   calendrier.
5. **Profondeur d'échantillonnage très inégale.** Filtrer sur
   `n_plac_presence`, ou passer par les fonctions à cascade, qui descendent
   l'échelon SER → GRECO → national et **déclarent le niveau atteint**.
6. **Contrôle d'ordre de grandeur** : la somme du prélèvement national sur
   toutes les essences donne **2,84 m³/ha/an**, cohérent avec l'ordre de
   grandeur publié pour la récolte française. Un test le vérifie.
7. Millésime **2005-2024** : rejouer `data-raw/build_ifn_tables.R` pour
   actualiser — le script découvre seul la campagne la plus récente.

## Correspondance des codes essence (spec 040, D9)

Table `inst/extdata/ifn_espar_correspondance.csv` (193 lignes), exposée par
`ifn_espar_correspondance()` et `resoudre_espar()`.

- **Source** : référentiel `espar-cdref13.csv` de l'export IGN (Licence Ouverte
  Etalab v2.0), qui donne pour chaque `espar` le nom latin (`lib_cdref`).
- **Pivot** : le **nom latin**, croisé avec `ifn_volume_equations.csv`
  (codes P1 à quatre lettres) et `european_species_tolerances.csv` (codes
  snake-case). Jamais d'heuristique sur les libellés français.
- **Autonyme** : l'IGN descendant souvent au rang infraspécifique
  (*Picea abies* subsp. *abies*), l'appariement retient aussi la sous-espèce ou
  variété nominale, taxonomiquement équivalente à l'espèce.

### Prudence d'usage
1. **Couverture inégale par construction.** `code_p1` n'est renseigné que pour
   les essences présentes dans `ifn_volume_equations.csv` (20 sur 22 essences
   réelles) ; un `NA` signifie « pas de tarif IFN spécifique », pas « essence
   inconnue » — P1 bascule alors sur le genre.
2. **Pas de repli arbitraire.** Là où l'IGN ne publie que des variétés sans
   autonyme (*Pinus nigra* : *calabrica*, *corsicana*, *salzmannii*), la ligne
   reste `NA`. Idem pour les libellés non latins (`POSP`, « Populus cultive »).
3. **Zéros non significatifs** : les codes sont alignés sur la convention
   d'`ARBRE.csv` (`"09"`, pas `"9"`), afin qu'un code résolu apparie
   effectivement les tables `ifn_*_essence_ser`. Un test le verrouille.

### Correction apportée à une table préexistante
`ifn_volume_equations.csv` portait `PIME | Pinus menziesii` ; le douglas est
***Pseudotsuga* menziesii**. Corrigé le 22/07/2026. Le calcul de P1 n'était pas
affecté (`lookup_ifn_equation()` apparie sur le code), mais le nom scientifique
publié était erroné.
