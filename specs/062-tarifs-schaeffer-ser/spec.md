# Spec 062 — Numéros de tarif Schaeffer par essence × SER (IFN), pour Marculus

> Brief Pascal du 2026-10-16 (`briefs/vers-nemeton/spec.md`). Décisions de la tâche 1 : § *Décisions* en fin de document.

## Contexte

Marculus (app Android de martelage, `pobsteta/marculus`) cube les tiges avec un tarif Schaeffer à une entrée : V = f(D, N), où N est le **numéro de tarif**. Aujourd'hui le marteleur saisit N à la main, un seul pour toutes les essences du contexte.

Objectif : proposer N **par essence** à partir des données brutes IFN, **au niveau de la sylvoécorégion (SER)**, avec repli GRECO puis national. Deux chemins de livraison, une seule source de calcul (ce package) :

1. **Table de référence embarquée dans Marculus**, pour les contextes créés sur le terrain sans Nemeton (Marculus doit rester utilisable seul, hors ligne). Calculée **une fois par millésime IFN**.
2. **Proposition à l'échelle de la forêt** dans les lots de chantiers exportés par nemetonshiny (voir `brief-nemetonshiny.md` de ce dossier).

Ce qui existe déjà et doit être réutilisé, pas réécrit :
- `ifn_charger()` (`R/ifn_source.R`) : téléchargement des données brutes IGN, attribut `millesime` ;
- `data-raw/build_ifn_tables.R` : chaîne de construction des tables essence × SER ;
- `.ifn_cascade()` / `.ifn_filtrer()` (`R/ifn_tables.R`) : cascade SER → GRECO → national, seuil `min_plac = 30` ;
- `localiser_ser()` (`R/localiser_ser.R`) : SER majoritaire d'une unité, couche INRAE `ser_l93` ;
- `ifn_espar_correspondance()` / `resoudre_espar()` (`R/ifn_espar.R`) : pont entre nomenclatures, pivot nom latin.

## Méthode

Reprise de `PPtools::TarifFindSch()` (Max Bruciamacchie). **Vérifier que l'autorisation de reprise sous GPL-3 du 22 juillet 2026, accordée pour `CarteEssenceSer()`, couvre aussi cette fonction** ; sinon, me le signaler avant de fusionner.

Pour chaque arbre vif IFN avec volume `V` (bois fort tige, m³) :

- D = C13 / π, **en cm** (attention : dans `ARBRE.csv` brut, `C13` est en **mètres** — `pptools` travaille sur une copie déjà en cm ; ajouter un test qui verrouille l'unité) ;
- garder 17,5 ≤ D ≤ 80 cm (bornes de `TarifFindSch`) ;
- quatre numéros par arbre :
  - `SchR  = V/5 · 70000  / ((D−5)(D−10))   − 8` (rapide)
  - `SchI  = V/5 · 80000  / ((D−2,5)(D−7,5)) − 8` (intermédiaire)
  - `SchL  = V/5 · 90000  / (D(D−5))        − 8` (lent)
  - `SchTL = V/5 · 101250 / D²              − 8` (très lent)
  Conventions vérifiées identiques à `Cubage.volume()` de Marculus : M = 0,8 + 0,1·N, rapide V = (M/1400)(D−5)(D−10), lent V = (M/1800)·D·(D−5).

Agrégation par échelon × essence × type :
- **moyenne pondérée par le volume** de l'arbre (comme `TarifFindSch`, `Hmisc::wtd.mean` / `wtd.var` — ou réimplémentation sans dépendance) ;
- `cv` = √(variance pondérée) / moyenne ;
- `n_arbres` et `n_placettes` (le seuil de cascade porte sur les **placettes**, comme `.ifn_cascade`) ;
- `type_conseille` = type au plus faible CV pour l'essence et l'échelon ;
- numéro arrondi à 0,1.

Question ouverte, à trancher en tâche 1 : pondérer aussi par le poids d'expansion `W` de l'arbre (représentativité à l'hectare) ? `TarifFindSch` ne le fait pas. Proposer, avec un test comparatif sur deux SER.

Fenêtre de campagnes : paramètre `campagnes`, défaut **les 15 dernières**, pour refléter la sylviculture actuelle.

## Tâches

1. **Exploration** (aucune écriture) : relis les fonctions ci-dessus, la structure de `ifn_volume_essence_ser.csv`, le contrat d'API 1.0 (spec 057), et `ifn_espar_correspondance.csv`. Produis un plan nommant les fichiers touchés. **Attends ma validation.**

2. **Construction** — dans `data-raw/build_ifn_tables.R` (ou un `build_ifn_tarifs.R` frère si c'est plus lisible) : produire `inst/extdata/ifn_tarif_schaeffer_ser.csv`, même schéma de clés que les autres tables :
   `niveau;ser;greco;espar;libelle_essence;type;numero;cv;n_arbres;n_placettes;type_conseille;millesime`
   avec `type` ∈ `SCHR`, `SCHI`, `SCHL`, `SCHTL`.

3. **Accesseurs exportés** (`R/ifn_tarifs.R`), sur l'idiome de `ifn_volume_essence_ser()` / `ifn_volume_reference()` :
   - `ifn_tarif_schaeffer_ser(espar, ser, greco, niveau, type)` : lecture filtrée de la table ;
   - `ifn_tarif_schaeffer_reference(espar, ser, type = NULL, min_plac = 30)` : cascade via `.ifn_cascade()`, colonnes `numero`, `cv`, `n_arbres`, `n_placettes`, `niveau_utilise`, `type_conseille` ; `NA` si aucun échelon ne qualifie ;
   - `tarif_schaeffer_local(units, especes, campagnes, min_plac = 30)` : numéros calculés sur les placettes IFN **de la forêt** (`units` + tampon portant la surface à ~2 000 ha, minimum 450 m, logique de `PPtools::ExtractPlac()`), avec repli sur `ifn_tarif_schaeffer_reference()` pour la SER majoritaire (`localiser_ser()`) quand la forêt n'a pas `min_plac` placettes pour l'essence. `niveau_utilise` vaut alors `"foret"`, `"ser"`, `"greco"` ou `"national"`.

4. **Code essence Marculus** : Marculus identifie une essence par son **code ONF à 3 lettres** (table issue de `gftools::ListTarEmerge`, cf. `Cubage.codeEssence` côté Marculus). Ajouter une colonne `code_onf` à `ifn_espar_correspondance.csv`, construite **sur le pivot nom latin**, jamais par heuristique de libellé. Source de la table ONF à identifier en tâche 1 (gftools, ou référentiel ONF) ; `NA` assumé pour les essences sans code.

5. **Commune → SER** : `inst/extdata/communes_ser.csv`, `insee;nom;departement;ser;greco;part` — une ligne par couple commune × SER, `part` = part de la surface de la commune dans la SER (somme = 1 par commune). Communes ADMIN EXPRESS COG (IGN), millésime noté. V1 sur la surface totale ; la surface forestière (BD Forêt V2) est une amélioration ultérieure, à noter dans la spec.

6. **Export pour Marculus** : `exporter_tarifs_marculus(dossier, millesime = NULL)` écrit, en UTF-8, séparateur `;`, sans `NA` littéral :
   - `tarifs_ser.csv` : `niveau;code;essence_code;essence_libelle;type;numero;n_arbres;n_placettes;cv;millesime` (`cv` en fraction) — `code` = code SER, GRECO ou `FR` ; uniquement les essences avec `code_onf` ;
   - `communes_ser.csv` ;
   - `ser.csv` : `code;nom;greco` ;
   - optionnel `ser_simplifie.gpkg` (WGS84, géométries simplifiées, cible < 2 Mo) ;
   - un `LISEZMOI.txt` : millésime IFN, millésime COG, date, citation IGN (Licence Ouverte Etalab 2.0) et crédit méthode Bruciamacchie.
   Taille totale cible **< 3 Mo** : vérifiée par un test.

7. **Tests** (testthat, couverture ≥ seuil du dépôt) :
   - formules : un arbre synthétique de volume connu redonne son numéro, pour les 4 types ; aller-retour avec les formules de volume de Marculus ;
   - unité de `C13` verrouillée (mètres → cm) ;
   - bornes 17,5–80 cm ; pondération par le volume ; CV ;
   - cascade : SER suffisante, repli GRECO, repli national, `NA` ;
   - `tarif_schaeffer_local` : forêt riche (`"foret"`), forêt pauvre (repli SER) ;
   - `communes_ser.csv` : parts sommant à 1, commune à cheval sur deux SER ;
   - export : fichiers présents, schéma exact, taille < 3 Mo, aucune essence sans `code_onf`.

8. **Documentation** : NEWS, vignette courte « Numéros de tarif Schaeffer par SER », section dans la spec 040 ou renvoi depuis elle ; fonctions ajoutées au contrat d'API (statut *experimental* tant que Marculus ne les consomme pas).

## Contraintes

- Aucune nouvelle source de données que l'IGN (IFN, COG, SER via INRAE déjà utilisée).
- Le prélèvement et le volume sur pied existants ne changent pas.
- Une seule chaîne de calcul : la table embarquée dans Marculus et la proposition des lots utilisent **les mêmes fonctions et le même millésime**.
- Le résultat est une **valeur par défaut** pour le marteleur, pas une prescription : le dire dans la documentation, comme pour le prélèvement.

## Calendrier d'exécution

- **Une fois par millésime IFN** (publication annuelle des données brutes) : relancer la construction, publier le package, puis `exporter_tarifs_marculus()` et proposer une PR dans `pobsteta/marculus` déposant les fichiers dans `data/src/main/assets/tarifs/` (format décrit dans `marculus/docs/specs/BRIEF-claude-code-tarifs-ser.md`).
- Automatisation possible plus tard : action GitHub déclenchée à la main qui fait ces trois étapes. Hors périmètre de cette spec.

## Critères d'acceptation

- `devtools::check()` sans nouvelle erreur ni note ; tests verts.
- Sur la SER `C30`, chêne sessile et hêtre ont un numéro au niveau `ser` ; une essence rare retombe sur `greco` ou `national`.
- `exporter_tarifs_marculus()` produit un dossier < 3 Mo relu sans erreur par les tests de format.

Commence par la tâche 1 et montre-moi ton plan avant d'écrire du code.

## Décisions (tâche 1, 2026-10-16)

Exploration en lecture seule ; arbitrages de Pascal du 2026-10-16.

- **D1 — Licence.** `TarifFindSch()`, `TarifIFN()` et `ExtractPlac()` sont dans
  `PPtools` (GPL-2). L'autorisation de Max Bruciamacchie du 22/07/2026 couvre
  **tout `PPtools`** (confirmé par Pascal) : reprise sous GPL-3, crédit dans le
  code, NEWS et `inst/REFERENCES.md`, comme pour `CarteEssenceSer()`.
- **D2 — Seuil du niveau forêt.** Mesure : ~10 placettes IFN porteuses de `V`
  pour 2 000 ha de forêt (2010-2024, 86 795 placettes / 17,3 Mha), placées au
  centre de leur maille kilométrique (700 m d'erreur au plus). `min_plac = 30`
  y serait presque jamais atteint. Au niveau **forêt seulement** : ≥ 30 arbres
  sur ≥ 5 placettes (esprit du `SeuilNb` de `TarifIFN`) ; SER, GRECO et
  national gardent `min_plac = 30` placettes via `.ifn_cascade()`.
- **D3 — Export Marculus.** `Cubage.volume()` prend un numéro **entier** et ne
  connaît que le rapide et le lent. La table nemeton garde les 4 types au
  dixième ; `tarifs_ser.csv` exporte **les 4 types, numéros arrondis à
  l'entier**, `type_conseille` choisi parmi les 4.
- **D4 — Code ONF.** Source : `gftools::ListTarEmerge` (`code3_onf`, `nom_lat`),
  lu depuis le `.rda` (`NEMETON_GFTOOLS_DIR`, gftools n'étant pas publié) ;
  CSV versionné, aucune dépendance du paquet. Pivot : nom latin complet
  identique (141/193), sinon binôme genre + espèce si le nom IFN est un binôme
  ou un autonyme **et** si le binôme n'a qu'un code dans gftools (+9) ; sinon
  `NA`. Le repli binôme non restreint donnait `P.O` aux pins noirs de Calabre,
  Corse et Salzmann et `CEL` au cèdre de Chypre. Sept essences ont un code par
  `espar` mais pas par le nom latin (nomenclatures divergentes : `Vachellia` /
  `Acacia farnesiana`, `Pinus brutia` / `P. halepensis subsp. brutia`…) :
  laissées `NA`, à trancher au cas par cas.
- **D5 — C13.** Vérifié : `C13` brut en mètres (médiane 0,625) ; D = 100·C13/π.
- **D6 — Cascade.** Filtre par `type`, puis `.ifn_cascade()` réutilisée
  (`n_placettes` exposée sous le nom `n_plac_presence` attendu).
- **Ouvert.** Pondération par `W` : test comparatif sur deux SER pendant la
  construction (tâche 2). `marculus/docs/specs/BRIEF-claude-code-tarifs-ser.md`
  cité pour le format est absent du clone Marculus : format pris de la tâche 6.

### Révision du 2026-10-16 (brief Marculus `2026-10-16-tarifs-schaeffer-ser.md`)

Arbitrage de Pascal : **le brief Marculus fait foi pour l'export**.

- **D3 remplacée.** `ifn_tarif_schaeffer_ser.csv` :
  `niveau;code;espar;essence_libelle;type;numero;n_arbres;cv;millesime`,
  `niveau` ∈ `SER`, `GRECO`, `FRANCE` (code `FR`), numéro au **dixième**, `cv`
  en **%** au dixième, **toutes les lignes, sans seuil** : la cascade (30
  arbres) est faite par Marculus. `communes_ser.csv` :
  `insee;nom;departement;ser;part;greco` ; `ser.csv` : `code;nom;greco`.
  UTF-8 sans BOM, séparateur `;`.
- **D4 abandonnée pour Marculus.** Pas de code ONF dans l'export : Marculus
  fait la correspondance (`EMERGE_CODES`). La colonne `code_onf` n'est pas
  ajoutée à `ifn_espar_correspondance.csv`.
- **Filtres** (reprise PPtools) : arbres vifs (`VEGET == "0"`) cubés (`V`),
  `100·C13 ≥ 50 cm`, 17,5 ≤ D ≤ 80 cm, essence retenue au-delà de 2 arbres.
- **D7 — Variance.** Poids de fiabilité : var = Σw(x − x̄)² / (Σw − Σw²/Σw),
  définie dès 2 arbres, sans écarter de groupe (`Hmisc::wtd.var`, dénominateur
  Σw − 1, devient négative quand le groupe pèse moins d'1 m³).
- **Contrôles** (essai Marculus, export 2005-2025) : 878 757 arbres retenus,
  15 392 lignes, 86 SER ; C20 chêne sessile SchL 7,7, hêtre SchL 8,4 ; B70 chêne
  sessile SchR 9,0. Contours communaux Etalab `communes-100m` (dérivé ADMIN
  EXPRESS), parts < 1 % écartées puis renormalisées.
- **D8 — Fenêtre** : 15 dernières campagnes (2011-2025), confirmée par
  Pascal le 2026-10-16 (l'essai Marculus prenait 2005-2025).
- **D9 — CV** rapporté à |moyenne| : essences de faible forme à numéro
  négatif sur les tarifs lents (chêne vert, chêne pubescent), numéros gardés.
- **D10 — Cascade nemeton** sur `n_arbres` (30), comme Marculus : la table au
  format Marculus ne porte pas `n_placettes`.
- **D11 — Part de houppier** (Pascal, 2026-10-16 : « colonne de plus, EMERGE
  seul ») : `part_houppier` en dernière colonne, %, rapport des sommes EMERGE
  houppier / (tige + houppier) bois fort sur les arbres avec `HTOT`,
  `hdec = 0,8 · htot` ; vide sous 3 arbres. La variante « V IFN + houppier
  EMERGE » (2 à 4 points plus haute pour les feuillus) est écartée.
- Les accesseurs nemeton (`ifn_tarif_schaeffer_reference()`,
  `tarif_schaeffer_local()`, cascade et D2) restent, pour nemetonshiny.
