# Brief `nemetonshiny` — inventaire vidéo, schéma Groma 1.6.0

> **Statut** : livré en cœur **2026.11.29** (spec 061 § 4 ter).

## Ce qui change pour l'app

1. **« Suivre »** : `groma_etat_placettes()` rend `terrain_envoye_le` (ISO
   8601 UTC ou `NA`). L'afficher (« terrain reçu à … »). Une placette
   `etat = "sans_paquet"` n'a reçu que la saisie, pas de vidéo.
2. **« Intégrer »** : `groma_telecharger_resultats()` télécharge aussi
   `terrain.zip` (défaut). Passer le dossier à
   `importer_inventaire_video(gpkg, resultats, terrain = dossier, field_data_gpkg = ...)`.
   `gpkg` (copie de QField) devient facultatif. Photos copiées sous
   `photos/<plot_id>/` à côté de `field_data_gpkg`.
3. **Alertes** (`$alertes`, nouvelle colonne `detail`) à traduire :
   `terrain_serveur_prefere` (la copie de QField a été remplacée par la
   saisie de Groma), `saisie_qfield_ignoree` (un attribut saisi seulement
   dans QField, `detail` = `champ = valeur`), `centre_telephone` (centre au
   GNSS du téléphone, `detail` = `precision_h_m = …` ; toute la placette peut
   être décalée de quelques mètres).
4. **Validation** : un centre `telephone` sort en avertissement
   (`field = "qualite_gnss"`) ; nouveaux contrôles de domaine `dbh_source`,
   `qualite_gnss`, `source_azimut`.
5. **Rayon** : 15 m par défaut à la création du projet de terrain (un
   champ de saisie du rayon, s'il existe, doit proposer 15).

## Complément 2026.11.30

6. **« Intégrer », téléchargement incrémental** : passer à
   `groma_telecharger_resultats(..., etat = groma_etat_placettes(url, jeton))`.
   `terrain.zip` n'est alors demandé que pour les placettes qui en ont envoyé
   un, et seulement si `terrain_envoye_le` a changé depuis le dernier
   téléchargement (témoin `<plot_id>_terrain.envoye_le` dans le dossier).
   Sinon l'archive déjà sur disque est gardée et son chemin est rendu.
   `attr(res, "detail")$telecharge` dit ce qui a été téléchargé par l'appel.
   Sans `etat`, rien ne change (`video_telecharger()` actuel).
7. **Validation, part des arbres mesurés au ruban** :
   `valider_inventaire_video()` rend un nouvel élément `dbh_ruban`
   (`plot_id`, `n_arbres`, `n_ruban`, `part_ruban`, faux positifs exclus ;
   `NA` pour un projet antérieur au schéma 1.4.0). À afficher par placette
   (« x arbres sur n mesurés au ruban »).
