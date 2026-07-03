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
