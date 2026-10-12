# Spec 061 — Inventaire vidéo Groma (cœur)

> **Statut** : implémenté en **2026.10.4** (2026-10-12).
> **Demande** : brief `groma_nemeton` du 2026-10-12
> (`/home/pascal/dev/briefs/vers-nemeton/2026-10-12-inventaire-video.md`, copie
> de référence dans `groma/briefs/vers-nemeton/`). Décisions 1 à 3 tranchées
> par Pascal le 2026-10-12. Le pendant interface est
> `vers-nemetonshiny/2026-10-12-inventaire-video.md` (émis par groma).

## 1. Objet

Groma remplace la mesure manuelle d'une placette circulaire par une vidéo au
smartphone. L'application Android calcule un inventaire **provisoire**, le
serveur un inventaire **définitif**. Le cœur porte toute la logique
plateforme : GeoPackage de terrain, hauteurs par houppier, numérotation,
rapprochement, validation, agrégats, NDP. `nemetonshiny` n'en fait que
l'interface (sous-onglet Terrain > Inventaire vidéo).

## 2. Livré

| Fonction | Rôle |
|---|---|
| `schema_inventaire_video()` | lit `inst/inventaire_video/inventaire_video.schema.json` (source unique, partagée avec Python et Kotlin) en descripteurs `.field()` + `readonly`, `hidden`, `labels` |
| `creer_projet_inventaire_video()` | `inventaire_video.gpkg` (6 couches), `rasters/<plot_id>_{mnt,mnh}.tif`, projet QField, le tout dans un `.qgz` |
| `numeroter_arbres()` | règle de numérotation Groma (implémentation de référence du brief, 10 cas communs) |
| `affecter_hauteur_houppier()` | `h_m` par point dans polygone (houppier le plus haut, bord inclus, [1, 70] m, `mesuree` jamais écrasée) |
| `rapprocher_arbres()` | rapprochement provisoire → définitif d'une placette (§ 4 du brief) |
| `valider_inventaire_video()` | `validate_field_data(dbh_max_cm = Inf, dbh_alerte_cm = 200)` + uuid, domaines, plan |
| `importer_inventaire_video()` | bloc « Intégrer » : rapprochement, `espece`, retrait des faux positifs, validation, agrégats par rayon, marquage NDP, fusion |
| `groma_etat_placettes()`, `groma_telecharger_resultats()` | client de l'API du serveur Groma (`httr2`, déjà en Suggests) |

Évolutions non cassantes (défauts inchangés) :
- `validate_field_data(dbh_max_cm = 300, dbh_alerte_cm = NULL)` (décision 2) ;
- `get_arbre_schema(dbh_max_cm = 300)` ;
- `tag_field_data_sources(source = "inventaire_terrain")` →
  `attr(, "field_data_source")` ; `detect_ndp()` ajoute `"inventaire_video"`
  aux sources. Un inventaire vidéo mesure tous les arbres de la placette : NDP 3
  dès qu'il porte des arbres, sans le seuil de 10 arbres par placette des autres
  données terrain (attendu par l'app, note `inventaire-video-retours-app`) ;
- `bdforet_mapping` de `BFC.json` : 7 libellés BD Forêt V2 qui tombaient en
  `essence_mixte` (§ 7 du brief), données seulement ;
- helpers QGIS : rasters GeoTIFF, étiquettes, champs en lecture seule,
  `ValueMap` code → libellé. Sortie de `create_qgis_project()` inchangée.

## 3. Choix d'implémentation

- **Pas de dépendance `clue`** : la méthode hongroise (potentiels, O(n³)) est
  écrite dans le cœur (`.affectation_optimale()`), matrice complétée au carré
  par le coût interdit, ce qui maximise d'abord le nombre d'appariements puis
  minimise le coût (équivalent à `scipy.optimize.linear_sum_assignment` filtré).
  Testée contre la force brute.
- **Hauteur serveur absente** : une détection définitive à `h_m = NA` laisse la
  hauteur provisoire en place (Python distingue clé absente et clé nulle ; une
  table R ne le peut pas).
- **Hauteur MNH recalculée** par `affecter_hauteur_houppier()` : un arbre
  `mnh` hors de tout houppier valide repasse à `aucune`.
- **`project_path`** ajouté à `creer_projet_inventaire_video()` : sans lui,
  `resolve_project_dem()` / `resolve_project_chm()` n'ont pas de projet à lire.
- **Pente/exposition** : plan `z ~ x + y` ajusté sur le MNT dans le rayon ;
  exposition = direction de plus grande pente descendante, `flat` sous 5 %.
  **Recouvrement** : part des cellules MNH > 2 m dans le rayon.
- **Fusion** dans `data/field_data.gpkg` : couches principales `placettes` /
  `arbres` = version retenue (`priorite`, défaut `"classique"`), une ligne par
  `plot_id`, donc lisibles sans changement par l'existant ; l'autre version
  va dans `placettes_alternatives` / `arbres_alternatives`. Colonne `source`
  sur chaque ligne.
- **Écarts du brief acceptés** : `date_mesure` (et non `date`),
  `convergence_deg` ajoutée, azimut rendu dans l'unité de la placette,
  tolérance d'égalité toujours en degrés.

- **Formes de retour** alignées sur la note de l'app du 2026-10-12
  (`vers-nemeton/2026-10-12-inventaire-video-retours-app.md`) :
  `importer_inventaire_video()` rend aussi `a_completer`, `a_verifier`,
  `classique_conserve` et `ndp` ; `groma_telecharger_resultats()` rend les
  chemins téléchargés (détail HTTP en attribut `detail`).

## 4. Reste à faire

- Plugin de projet QField `<projet>.qml` : réservé, contenu à fournir par
  groma après validation sur appareil (Android 11+).
- Option « renvoyer les `a_completer` / `a_verifier` sur le terrain dans un
  `.qgz` filtré » : non livrée (le brief la note en option).
- Câblage app (`nemetonshiny`) : brief émis par groma.

## 5. Tests

`test-numerotation.R` (fourni), `test-rapprochement.R` (5 cas, absence de
perte d'attribut, unicité de `tree_id`, optimalité hongroise),
`test-hauteur-houppier.R`, `test-inventaire-video-gpkg.R` (exemple groma,
schéma, validation, import + fusion, création de projet sur MNT/MNH
synthétiques avec insertion par RSQLite sans fonction spatiale, client
`httr2` simulé, seuils de diamètre, référentiel d'essences).
