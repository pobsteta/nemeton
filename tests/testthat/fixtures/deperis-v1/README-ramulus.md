# Cas communs du format `deperis-v1`

Format : [`docs/formats/deperis-v1.md`](../../docs/formats/deperis-v1.md) ; schéma :
[`deperis-v1.schema.json`](../../docs/formats/deperis-v1.schema.json). Ces cas sont la référence commune de Ramulus
(Kotlin) et de Nemeton (R) : chacun les rejoue et doit conclure comme `attendu.json` (ADR 0003 § 7).

## Contenu d'un cas

Chaque dossier contient :

- le ou les fichiers : `deperis.gpkg` (tournée écrite par Nemeton, lue par Ramulus) ou `<code_tournee>.zip` (paquet
  rendu par Ramulus, `deperis.gpkg` et `photos/`, importé par Nemeton) ;
- `<nom>.instantane.json` : l'instantané JSON de chaque fichier, tel que le décrit le format (lisible et comparable
  sans SQLite) ;
- `attendu.json` : `lecteur` (`ramulus` à l'ouverture d'une tournée, `nemeton` à l'import d'un rendu), `depart` (la
  tournée de départ à laquelle comparer un rendu), `attendu` (`accepte`, `signale` ou `refuse`), `motifs` (codes du
  catalogue), `source`, `fusion`, et `notes` : chaque note du fichier, avec la photo des fiches DSF 2025 dont elle
  reprend les notes (`photo_dsf`, `null` si le cas les a modifiées).
- `fusion` est `null`, sauf pour les cas de plusieurs paquets (A5, S3, F1). Alors chaque fichier, contrôlé seul, conclut
  comme `fusion.chaque_fichier` ; `attendu` et `motifs` sont ceux de leur **union** sur l'`uuid`, faite au nom de
  `fusion.operateur` et `fusion.version_ramulus` ; `fusion.resultat` est le paquet que cette union doit redonner ;
  `fusion.ecartes` liste ce que l'union écarte pour conflit (`objet` : table ou `photos` ; `cle` : `uuid` ou nom de
  photo), vide s'il n'y en a pas ; `plot_id` y dit la placette de la ligne écartée. `fusion.placettes_signalees`
  (F1 seulement, absent sinon) liste les placettes dont le **centre** est écarté : elles restent dans l'union, avec
  leurs notes et leur `etat` « notee », sans centre. Les `notes` sont celles des fichiers, pas de l'union.
- `enregistrement` (T2 seulement, absent sinon) est un cas de **saisie**, pas de fichier : `table` et `saisies`, des
  lignes de note qui arrivent à Ramulus pour être enregistrées. Le cas conclut sur la saisie (`attendu`, `motifs`) ;
  `fichiers` est la tournée à laquelle on l'ajoute, qui doit rester intacte. Un lecteur qui joue les cas par la
  lecture ou l'import d'un fichier **saute** les cas qui portent `enregistrement`.

## Données

- Code de tournée `EXEMPLE-2027-01` (contre-notation : `EXEMPLE-2027-01-CN`), campagne d'été 2027.
- Trois placettes **synthétiques** en Côte-d'Or, à environ 300 m les unes des autres (P001 à 5,0650° E,
  47,1150° N ; P002 à 5,0690° E, 47,1150° N ; P003 à 5,0650° E, 47,1180° N ; longitude puis latitude, en degrés),
  converties en EPSG:2154 (X = est, Y = nord, en mètres). Aucune forêt n'est nommée ; **les notes ne disent rien de
  l'état réel du lieu** (ADR 0006). Site validé par Pascal le 2026-10-28.
- Notes reprises telles quelles de photos des fiches DSF 2025 (`fixtures/fiches-dsf-2025.json`), hors des quatre
  incohérences connues : quatre notes sur P001 (Chêne sessile, Hêtre, Charme mort à 5/5 en classe F, Chêne sessile
  en classe B) ; trois sur P002 (Sapin, Mélèze, Cèdre en classe A, repère « 12b ») ; deux sur P003 (Hêtre, Mélèze) :
  neuf notes en tout dans A3.
- P001 est marquée « collecte » (deux photos par arbre), P002 « contre-notation ». Les photos sont de petites images
  JPEG de 8 × 8 pixels.
- Opérateurs `operateur-A`, `operateur-B` (première notation) et `operateur-C` (contre-notation) : identifiants
  d'exemple, sans nom d'agent.
- `delai_contre_notation_jours` = 15 : **valeur provisoire** dans les exemples (Pascal, 2026-10-28) ; le délai réel
  reste à fixer avant la publication du format.

## Les cas

| Cas | Dossier | Lecteur | Attendu | Motifs |
|---|---|---|---|---|
| A1 | `A1-tournee-depart` | ramulus | accepté | — |
| A2 | `A2-tournee-contre-notation` | ramulus | accepté | — |
| A3 | `A3-rendu` | nemeton | accepté | — |
| A4 | `A4-rendu-contre-notation` | nemeton | accepté | — |
| A5 | `A5-fusion-deux-operateurs` | nemeton | accepté ; l'union des deux paquets redonne A3 | — |
| A6 | `A6-version-suivante` | ramulus | accepté, colonnes et table nouvelles ignorées | — |
| A7 | `A7-notation-sans-repere` | nemeton | accepté, `repere` NULL partout | — |
| S1 | `S1-doublon-arbre` | nemeton | signalé | `doublon_arbre` |
| S2 | `S2-centre-eloigne` | nemeton | signalé | `centre_eloigne` |
| S3 | `S3-fusion-conflit-uuid` | nemeton | chaque paquet accepté seul ; leur union signalée, sans la note de P001 rang 1 ni ses photos, tout le reste gardé | `uuid_contenu_different` |
| F1 | `F1-fusion-conflit-centre` | nemeton | chaque paquet accepté seul ; leur union signalée, sans le centre de P001, avec la placette P001 « notee » et ses quatre notes gardées et signalée | `uuid_contenu_different` |
| T2 | `T2-classe-saisie` | ramulus | refusé : deux saisies de la note de P001 rang 1, l'une avec la bonne classe, l'autre avec une fausse (cas de saisie, voir `enregistrement`) | `classe_saisie` |
| R1a | `R1a-plan-valeur-modifiee` | nemeton | refusé | `plan_modifie` |
| R1b | `R1b-plan-colonne-renommee` | nemeton | refusé | `plan_modifie` |
| R1c | `R1c-plan-colonne-supprimee` | nemeton | refusé | `plan_modifie` |
| R1d | `R1d-centre-contre-notation-modifie` | nemeton | refusé | `plan_modifie` |
| R2 | `R2-classe-differente-abaque` | nemeton | refusé | `classe_differente_abaque` |
| R3a | `R3a-centre-mogadiscio` | nemeton | refusé | `hors_france` |
| R3b | `R3b-centre-xy-inverses` | nemeton | refusé | `hors_france` |
| R5a | `R5a-index-spatial-placettes` | ramulus | refusé | `index_spatial` |
| R5b | `R5b-index-spatial-centres` | ramulus | refusé | `index_spatial` |
| R6 | `R6-contre-notation-avec-notations` | ramulus | refusé | `notations_dans_contre_notation` |
| R7 | `R7-essence-hors-referentiel` | nemeton | refusé | `essence_hors_referentiel` |
| R8a | `R8a-note-hors-bornes` | nemeton | refusé | `note_hors_bornes` |
| R8b | `R8b-critere-incoherent` | nemeton | refusé | `critere_incoherent` |
| R9 | `R9-colonne-date` | ramulus | refusé | `colonne_date` |
| R10a | `R10a-photo-absente` | nemeton | refusé | `photo_absente` |
| R10b | `R10b-empreinte-photo-differente` | nemeton | refusé | `empreinte_photo_differente` |
| R10c | `R10c-photo-non-citee` | nemeton | refusé | `photo_non_citee` |
| R11 | `R11-repere-autre-que-2154` | ramulus | refusé | `hors_france`, `repere_hors_2154` |
| R12 | `R12-texte-non-nfc` | ramulus | refusé | `texte_non_nfc` |
| X1 | `X1-pas-un-geopackage` | nemeton | refusé | `pas_un_geopackage` |
| X2 | `X2-version-illisible` | nemeton | refusé | `version_illisible` |
| X3 | `X3-valeur-hors-liste` | nemeton | refusé | `structure` |
| X4 | `X4-type-incoherent` | nemeton | refusé | `type_incoherent` |
| X5 | `X5-ia-incomplete` | nemeton | refusé | `ia_incomplete` |
| X6 | `X6-uuid-duplique` | nemeton | refusé | `uuid_duplique` |
| X7a | `X7a-plot-inconnu` | nemeton | refusé | `rattachement_invalide` |
| X7b | `X7b-rang-trop-grand` | nemeton | refusé | `rattachement_invalide` |

X1 à X7b sont les cas complémentaires du testeur (mission 003, déplacés ici sur décision de Pascal, 2026-10-28) : les
motifs du catalogue qu'aucun cas de 002 ne couvrait. Ils sont écrits par leur propre script,
`generer_complements.py`, à partir de A3 ; `generer.py` (mission 002) ne les connaît pas. Les tests Python de 002 ne les
rejouent pas non plus.

F1 et T2 écrivent les deux décisions de Pascal du 2026-10-28 (mission 010) : F1, un centre qui arrive avec deux
contenus à la fusion est écarté, mais la placette « notee » et ses notes sont gardées et la placette est signalée ;
T2, une note qui arrive avec une classe déjà remplie, juste ou fausse, est refusée à l'enregistrement par Ramulus.
`classe_saisie` n'est produit que par l'enregistrement : lire un paquet rendu garde `classe_differente_abaque` (R2).

Le titre et la source de chaque cas sont dans son `attendu.json`. R4 (version N+1 refusée) a été retiré : Pascal suit
l'ADR 0003, une version N+1 est lue (Q1, cas A6). R1d, R10c et R11, proposés par l'agent, sont validés par Pascal
(2026-10-28), comme R12 et S3, ajoutés après ses décisions du même jour (textes en NFC ; conflit de fusion). S3 était
R13 (union refusée) jusqu'à la décision de Pascal du 2026-10-28 de traiter le conflit comme Surculus
(`sursync-v1.md`, l. 63) : les deux versions écartées, le conflit signalé, le reste gardé.

## Régénérer et vérifier

```sh
python3 fixtures/echange/generer.py                              # réécrit les cas et les listes du schéma
python3 -I fixtures/echange/generer_complements.py               # réécrit X1 à X7b (après generer.py)
python3 -m unittest discover -s fixtures/echange/tests -v        # schéma, cas, contrôle de référence, fusion
python3 fixtures/echange/verifier_ogrinfo.py                     # GDAL : chaque GeoPackage s'ouvre (CI)
```

Les GeoPackages sont écrits avec le module `sqlite3` de Python selon OGC 12-128 (M1, option b). Les tests comparent
les fichiers par leur **contenu** (instantané), jamais par leur empreinte : l'octet près dépend de la version de
SQLite (Surculus ADR 0011).

## Ce que Pascal vérifie sur le terrain

`A3-rendu/EXEMPLE-2027-01.zip`, décompressé :

1. dans **QField** (ou QGIS) : trois points en Côte-d'Or, au sud de Dijon ; `notations` et `tournee` listées comme
   tables sans géométrie ;
2. dans **R** :

   ```r
   sf::st_layers("deperis.gpkg")
   p <- sf::st_read("deperis.gpkg", "placettes")          # 3 points, EPSG:2154
   sf::st_coordinates(sf::st_transform(p, 4326))          # longitudes vers 5,06 à 5,07, latitudes vers 47,11 à 47,12
   n <- sf::st_read("deperis.gpkg", "notations")          # table sans géométrie, 9 lignes
   n[, c("plot_id", "rang", "repere", "essence", "mb", "second", "classe")]   # accents intacts
   ```

3. pour chaque note, la classe est celle de la fiche DSF de la photo citée dans `attendu.json` (`photo_dsf`).

`F1-fusion-conflit-centre/EXEMPLE-2027-01.zip` (l'union attendue), décompressé, dans **QField** : trois placettes,
P001 incluse, **un seul** centre en moins (celui de P001) ; la table `notations` porte ses neuf lignes, dont les quatre
de P001 ; la placette P001 est à l'état `notee`. Aucune colonne ne porte le signalement : on voit « P001 notee, sans
centre » ; le signalement se lit dans le rapport du contrôle (message « placette P001 signalée »). Les deux versions du centre sont dans `EXEMPLE-2027-01-1.zip` (centre
de départ) et `EXEMPLE-2027-01-2.zip` (à 4 m).
