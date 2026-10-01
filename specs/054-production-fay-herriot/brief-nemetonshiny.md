# BRIEF — production IFN par SER : P2, E1 et volume de référence (spec 054)

> **Statut** : ouvert, 2026-10-01.
> **Packages concernés** : `nemeton` (fournisseur, **livré**), `nemetonshiny` (demandeur).
> **Nature** : câblage de trois modes **opt-in** du cœur, plus l'affichage de leur
> incertitude. **Aucune logique métier à écrire côté app** (règles 1 à 3) : tout
> calcul passe par des fonctions exportées de `nemeton`.
> **Prérequis côté cœur** : `nemeton` ≥ **0.204.0**.
> **Contexte de rédaction** : lecture seule de `nemetonshiny@237429b0`
> (0.151.4.9000). Les numéros de ligne cités en dépendent.

---

## 1. Ce que le cœur offre désormais

Le cœur dispose d'une **production biologique mesurée par l'IFN**, par
sylvoécorégion (SER) et par campagne, estimée par **Fay-Herriot** (estimation sur
petits domaines, Onwunji et al. 2026). Chaque valeur porte son incertitude.
Contrôle national : 5,26 m³/ha/an, soit 97 % du chiffre IGN.

| Fonction (`nemeton::`) | Rôle pour l'app |
|---|---|
| `localiser_ser(units)` | **Préalable à tout le reste.** Ajoute la colonne `ser` (code SER de la plus grande intersection, WFS INRAE ; `NA` hors SER ou si le WFS ne répond pas, avec un avertissement). |
| `indicateur_p2_station(source = "ifn_fh", ser_field = "ser")` | P2 = production en volume de la SER (m³/ha/an), plus `P2_rse`, `P2_provenance`, `P2_nature`. |
| `indicateur_e1_bois_energie(production_field = "P2", taux_mobilisation = …)` | E1 en **mode flux** : la récolte suit la production, et non plus 2 % du stock. Ajoute `E1_mode`. |
| `ifn_taux_prelevement_production(ser)` | Ratio prélèvement/production de la SER, avec sa RSE. |
| `completer_volume_ifn(units, ser = …, methode = "fay_herriot")` | Complète P1 manquant (NDP 0) par le volume IFN essence × SER, avec provenance `"ifn_fh_ser"`. |

Les modes par défaut sont **strictement inchangés**. Rien ne bouge tant que l'app
ne les active pas.

## 2. Trois obstacles dans le code actuel de l'app

1. **Pas de colonne SER.** Les parcelles n'ont aucun code de sylvoécorégion. Sans
   lui, les modes IFN retombent sur le chiffre national, honnêtement signalé
   (`*_provenance = "ifn_prod_national"`) mais sans intérêt.
   → Appeler `nemeton::localiser_ser(parcels)` **une fois**, à la création du
   projet ou au premier calcul, et persister la colonne `ser` avec les parcelles.
   L'appel réseau est borné à l'emprise des parcelles et dure environ une seconde.

2. **P2 et E1 sont forcés en mode CHM.** `CHM_REQUIRED_INDICATORS`
   (`R/service_compute.R:368`) et l'arrêt anticipé de `compute_single_indicator()`
   (`R/service_compute.R:4463-4469`) interrompent P2 et E1 sans CHM. En mode IFN,
   **P2 n'a pas besoin de CHM**, et E1 en mode flux non plus.
   → Ne pas exiger le CHM quand P2 est demandé avec `source = "ifn_fh"`, ni quand
   E1 est demandé avec `production_field`. Ces deux modes sont justement la
   réponse au cas « NDP 0 sans CHM » que ce garde-fou bloque aujourd'hui.

3. **Les colonnes annexes sont jetées, et E1 ne voit pas P2.**
   `compute_single_indicator()` passe à chaque indicateur les **parcelles
   d'origine**, puis ne garde que la colonne de valeur
   (`nemeton::extract_indicator_value()`, `R/service_compute.R:4550`).
   - `P2_rse`, `P2_provenance`, `P2_nature` et `E1_mode` disparaissent alors qu'ils
     doivent s'afficher (§3).
   - E1 en mode flux lit P2 dans **ses** `units` (`production_field = "P2"`), et
     sa détection du cas dégénéré lit `P2_provenance`. Il faut donc que les
     parcelles transmises à E1 portent ces deux colonnes, issues du calcul de P2
     (P2 est calculé avant E1 dans l'ordre de `R/service_compute.R:336-338`).

## 3. Ce qu'il faut afficher, et ce qu'il ne faut pas dire

**P2 en mode IFN.**
- Libellé : « Production de la sylvoécorégion (IFN) », en m³/ha/an. Ce n'est
  **pas** la productivité de la station de l'UGF : toutes les UGF d'une même SER
  reçoivent la même valeur.
- Afficher `P2_rse` (en %) et l'échelon (`P2_provenance` : SER, GRECO ou
  national).
- `P2_nature = "fay_herriot"` signifie une valeur modélisée à partir de l'IFN et
  de la télédétection. `"direct"` signifie une moyenne IFN brute.

**E1 en mode flux.**
- `taux_mobilisation` **n'a pas de défaut**, volontairement. L'utilisateur choisit
  une part de la production récoltée (curseur de 0 à 1), ou « taux observé par
  l'IFN dans la SER » (`"ifn_ser"`).
- **Piège** : P2 en mode IFN combiné à `"ifn_ser"` donne simplement la
  **récolte observée** de la SER, identique pour toutes les UGF. Le cœur la marque
  `E1_mode = "recolte_observee"` et émet un avertissement. Dans ce cas, l'app ne
  doit **jamais** présenter E1 comme un potentiel. Libellé suggéré : « bois-énergie
  issu de la récolte actuelle de la SER ».
- La normalisation ne change pas : même `ref_max` en stock et en flux, c'est la
  même grandeur (t MS/ha/an). **Ne pas normaliser différemment selon le mode côté
  app.**

**Ratio prélèvement/production** (facultatif, panneau Production).
- Valeur et RSE de la SER. Biais connu : le ratio national vaut 0,68 contre 0,61
  publié par l'IGN, soit environ +10 %. **Un ratio légèrement supérieur à 1 ne
  prouve pas une décapitalisation** : l'afficher avec sa RSE.
- Deux définitions : `"ign"` (tous les arbres coupés) et `"vidange"` (coupés et
  sortis, la définition de la desserte).

**Volume de référence en NDP 0.** L'app n'appelle pas `completer_volume_ifn()`
aujourd'hui (grep négatif, relu le 2026-10-01). Si elle comble P1 un jour, utiliser
`methode = "fay_herriot"` et **afficher la provenance** (`volume_source`) : une
valeur `"ifn_*"` est une référence régionale, pas une mesure.

## 4. Clés i18n à prévoir (FR/EN)

Libellés de mode P2 et E1, « production de la sylvoécorégion », RSE, les trois
échelons, les deux valeurs d'`E1_mode`, l'avertissement « récolte observée », le
ratio et sa mise en garde. Toutes ces chaînes passent par `i18n$t()` (règle 4).

## 5. Hors périmètre

- **Aucune** production par essence ou par groupe pour P2. Dans la table du cœur,
  la production d'un groupe est rapportée à l'hectare de **toute** la forêt de la
  SER : c'est une contribution diluée (spec 054 §7.1). Le cœur utilise toujours
  `tous`.
- **C1 n'hérite pas** d'un P1 complété : il ne lit jamais P1 (spec 054 §7.3,
  correction).
- Le jeu de covariables GEDI (lot 1-ter) n'est pas encore construit ; il ne
  changera pas l'interface.

## 6. Validation suggérée

Sur un projet réel, après `localiser_ser()` :
1. P2 `source = "ifn_fh"` : environ 4-6 m³/ha/an, une RSE de quelques pour cent,
   et la même valeur pour toutes les UGF d'une SER.
2. E1 flux avec un taux de 0,6 : une valeur inférieure au mode stock pour un
   peuplement capitalisé.
3. E1 avec `"ifn_ser"` sur P2 IFN : `E1_mode = "recolte_observee"`, avertissement
   visible et libellé adapté.
