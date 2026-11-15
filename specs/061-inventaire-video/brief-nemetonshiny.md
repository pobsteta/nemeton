# Brief `nemetonshiny` — inventaire vidéo, schéma Groma 1.6.0

> **Statut** : livré en cœur **2026.11.29** et **2026.11.30** (spec 061 § 4 ter).
> **Émetteur** : session `nemeton`, 2026-11-15.
> **Type de changement côté app** : `feat:`.
> Repères de code relevés en lecture seule sur `nemetonshiny@3e34a534`
> (`R/service_inventaire_video.R`, `R/mod_inventaire_video.R`).

## 1. Contexte

Groma (schéma 1.6.0) permet désormais de se passer de QField : le centre,
les cibles et les attributs des arbres (essence, diamètre au ruban, statut,
qualité, notes, photos) se saisissent dans Groma, qui envoie au serveur, par
placette, une archive `terrain.zip`, séparée du paquet vidéo. Le cœur sait
la télécharger et l'intégrer à la place de la copie de QField. La copie de
QField reste acceptée (projets en cours) ; si les deux existent pour une
placette, celle du serveur gagne, avec une alerte.

Autres nouveautés du cœur : centre mesuré au GNSS du téléphone (signalé),
diamètre au ruban (`dbh_source = "mesure"`) conservé au rapprochement, part
des arbres mesurés au ruban à la validation, rayon par défaut 15 m.

Aucun changement cassant : tous les appels actuels de l'app restent valides.

## 2. API du cœur à utiliser

| Fonction | Nouveauté |
|---|---|
| `groma_etat_placettes(url, jeton)` | colonne `terrain_envoye_le` (ISO 8601 UTC, ou `NA`) ; une placette qui n'a que du terrain a `etat = "sans_paquet"` (et `id` nul) |
| `groma_telecharger_resultats(url, jeton, plot_ids, dossier, fichiers, etat = NULL)` | télécharge aussi `terrain.zip` (défaut ; 404 silencieux si rien n'a été saisi). Avec `etat` (le tableau ci-dessus) : `terrain.zip` demandé seulement si `terrain_envoye_le` est renseigné **et** a changé depuis le dernier téléchargement (témoin `<plot_id>_terrain.envoye_le` dans `dossier`), sinon l'archive sur disque est gardée et son chemin rendu. `attr(res, "detail")` gagne la colonne `telecharge` |
| `importer_inventaire_video(gpkg = NULL, resultats, field_data_gpkg, terrain = NULL, dossier_photos = NULL)` | `terrain` = chemins de `terrain.zip` ou dossiers où les chercher ; `gpkg` (copie de QField) devient **facultatif** quand `terrain` est donné ; photos copiées dans `dossier_photos/<plot_id>/` (défaut `photos/` à côté de `field_data_gpkg`) |
| `valider_inventaire_video()` (rendu dans `res$validation`) | nouvel élément `dbh_ruban` : `plot_id`, `n_arbres`, `n_ruban`, `part_ruban` (`NA` pour un projet antérieur au schéma 1.4.0) |
| `res$alertes` (import) | nouvelle colonne `detail` ; nouveaux motifs `terrain_serveur_prefere`, `saisie_qfield_ignoree`, `centre_telephone` |

## 3. À faire dans l'app

### 3.1 « Suivre »

1. `video_tableau_etats()` : ajouter la colonne `terrain_envoye_le`
   (vide si le serveur ne la rend pas) et l'afficher dans le tableau
   (en-tête `video_col_terrain`, cellule « terrain reçu le … » au format
   local). Le tableau du module est construit l. ~389-405.
2. `.VIDEO_ETATS` (l. 16) ne connaît pas `sans_paquet` : il tombe dans
   `rang() = NA` puis est remplacé par l'état local ou `a_faire`. Ajouter
   `sans_paquet` **avant** `provisoire` (une saisie est arrivée, pas de
   vidéo) et son libellé `video_etat_sans_paquet` dans `lib_etat`.

### 3.2 « Intégrer »

3. Bouton « Récupérer » (`input$recuperer`, l. ~437) : il ne télécharge que
   les placettes `definitif` et ne garde que les `.gpkg`
   (`rv$resultats <- f[grepl("\\.gpkg$", f)]`), donc **`terrain.zip` est
   jeté**. Il faut :
   * télécharger `terrain.zip` aussi pour les placettes qui ont
     `terrain_envoye_le` non vide, quel que soit leur état ;
   * passer `etat = srv` (le tableau brut de `groma_etat_placettes()`) pour
     ne retélécharger que ce qui a changé — cela suppose un **dossier
     stable** par projet (par ex. `file.path(video_dossier(pp), "serveur")`)
     au lieu de `tempfile()`, sinon le témoin est perdu à chaque clic ;
   * ranger à part les `terrain.zip` (`rv$terrain`) et les `.gpkg`
     (`rv$resultats`).
   `video_telecharger()` doit alors accepter et transmettre `etat` (et
   éventuellement `fichiers`).
4. `video_integrer(gpkg, resultats, project_path)` : ajouter `terrain`
   (et passer `terrain = rv$terrain` depuis `input$integrer`, l. ~492) ;
   rendre `gpkg` facultatif :
   * `input$integrer` refuse aujourd'hui sans fichier QField
     (`field_ingest_no_file`) : n'exiger qu'**un** des deux (copie QField
     ou `terrain.zip` récupéré) ;
   * `file.copy(gpkg, …terrain_integre.gpkg)` ne doit pas être appelé avec
     `gpkg = NULL`. `video_etat_local()` lit ce fichier pour
     `etat_traitement` : sans copie QField, écrire à la place les
     placettes intégrées (`res$placettes`, couche `placettes`) dans
     `terrain_integre.gpkg`, ou lire `field_data_gpkg`.
   Les photos arrivent sous `data/photos/<plot_id>/` (défaut du cœur, à côté
   de `field_data.gpkg`) : rien à faire, sauf si l'app veut un autre dossier
   (`dossier_photos =`).

### 3.3 Bilan et alertes

5. `video_bilan()` : reprendre `res$alertes` et
   `res$validation$dbh_ruban` (aujourd'hui ignorés).
6. Afficher les alertes avec leur `detail`, motifs à traduire (FR/EN) :
   * `terrain_serveur_prefere` : « la copie de QField de cette placette a
     été remplacée par la saisie de Groma » ;
   * `saisie_qfield_ignoree` : « saisi seulement dans QField, non repris »
     (`detail` = `champ = valeur`) ;
   * `centre_telephone` : « centre mesuré au GNSS du téléphone : toute la
     placette peut être décalée de quelques mètres » (`detail` =
     `precision_h_m = …`).
7. Validation : un centre `telephone` sort en **avertissement**
   (`field = "qualite_gnss"`, pas une erreur, l'import n'est pas bloqué) ;
   nouveaux contrôles de domaine (erreurs) sur `dbh_source`, `qualite_gnss`,
   `source_azimut`. Rien à changer si les tableaux sont affichés tels quels
   (`video_separer_infos()` gère déjà `severity`).
8. Part des arbres au ruban : afficher `dbh_ruban` par placette
   (« x arbres sur n mesurés au ruban », `video_part_ruban`) ; ne rien
   afficher quand `n_ruban` est `NA`.

### 3.4 Création du projet de terrain

9. Rayon par défaut **15 m** (placettes de calibration LiDAR de l'ONF) à
   deux endroits : `numericInput(ns("rayon"), value = 20, …)` (module,
   l. ~30) et `video_args_generation(rayon_m = 20)` (service). Un projet
   déjà préparé garde son rayon (il est écrit dans chaque placette).

## 4. Clés i18n à ajouter (FR/EN, `TRANSLATIONS`)

`video_col_terrain`, `video_terrain_recu`, `video_etat_sans_paquet`,
`video_alerte_terrain_serveur_prefere`, `video_alerte_saisie_qfield_ignoree`,
`video_alerte_centre_telephone`, `video_part_ruban`, et le message
« aucune saisie à intégrer » qui remplace `field_ingest_no_file` quand ni
copie QField ni `terrain.zip` ne sont disponibles. Noms indicatifs : suivre
la convention de l'app.

## 5. Tests attendus

* `video_tableau_etats()` : `terrain_envoye_le` présent / absent ;
  `sans_paquet` classé avant `provisoire`.
* Récupérer : avec un `httr2::local_mocked_responses`, deux clics avec le
  même `terrain_envoye_le` ne font qu'**une** requête `terrain.zip`.
* `video_integrer()` avec `gpkg = NULL` et un `terrain.zip` d'une placette.
  Le GeoPackage d'exemple n'est pas installé avec le cœur (fixture de test) :
  construire l'archive comme `faire_terrain()` dans
  `nemeton/tests/testthat/test-groma-schema-1-6.R` (couches `placettes`,
  `arbres`, `centres_mesures` d'une placette dans `terrain.gpkg`, plus
  `photos/<nom>`, zippés).
* `video_bilan()` rend `alertes` et `dbh_ruban`.
* Formulaire : rayon proposé 15.

## 6. Hors périmètre

Le cœur ne change pas la tolérance d'appariement des arbres pour un centre
`telephone` : il le signale seulement. Groma ne relit jamais la copie de
QField : une cible ou un attribut saisi dans QField après le passage à
Groma est signalé (`saisie_qfield_ignoree`), pas repris.
