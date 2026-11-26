# Brief vers nemetonshiny — Onglet ICD du suivi sanitaire

> De : orchestrateur de nemetonplateforme, le 2026-11-26, sur la demande de Pascal du même jour.
> Dépend de : `brief-nemeton-icd-decoloration.md` (calcul dans le cœur, release du cœur d'abord ; vérifier que les fonctions sont dans un **tag de release**, `@*release`).
> Méthode : note « Suivi de la décoloration anormale du feuillage » v2 (29 octobre 2026), §§ 4-8.

## Ce que Pascal a décidé (2026-11-26)

1. **FAST reste tel qu'il est** dans le suivi sanitaire.
2. Un **onglet ICD**, placé **après RECONFORT**, calcule l'ICD et, **au clic sur la carte**, présente les **graphiques des indices et de l'indice composite**.
3. Les **poids de la formule ICD** se modifient dans **Sources & paramètres**.
4. On fait une **comparaison avec FAST**.

## Ce qu'on attend de l'app

Aucune logique métier ici (règles strictes 1-3) : l'app appelle les fonctions du cœur via un `R/service_icd.R`, et présente.

### 1. Onglet ICD (`R/mod_monitoring.R`)

- Nouveau `bslib::nav_panel` juste après « Carte pixel RECONFORT » (`value = "pixel_map_icd"`), titre et infobulle i18n, icône dans le style des autres.
- Bouton « Calculer l'ICD » : `bslib::input_task_button` lié à un `ExtendedTask` + `future_promise` (comme FORDEAD/RECONFORT), zone de suivi = celle du sélecteur partagé.
- Progression : notification persistante alimentée par les événements `s2:*` et `icd:*` ; **retirée et chrono arrêté à la fin, à l'arrêt, à l'annulation ou sur erreur** (même nettoyage centralisé que la mission 072).
- Carte Leaflet : niveau ICD de l'année choisie (0 normal à 4 alerte répétée), palette ordonnée et légende i18n, masquée à l'UGF de la zone ; sélecteur d'année ; pixels sans ICD (hors peuplements purs) transparents, avec une ligne qui dit combien et pourquoi.

### 2. Clic sur la carte : graphiques

Au clic sur un pixel, une modale (plotly, comme la Carte pixel FAST et FORDEAD) :

- **Graphique 1, les cinq indices** : par mois (avril à octobre) et par année, les anomalies z de GRVI, CIre, CRSWIR, CRre, NDVI ; option de voir les valeurs brutes ; mois sensibles de l'essence surlignés ; CRre absent pour les résineux.
- **Graphique 2, l'ICD** : la série mensuelle de l'ICD, avec les seuils −1,5 (surveillance), −2 (alerte), −3 (alerte forte) en lignes horizontales, l'année courante marquée « provisoire » (trait pointillé, point creux, comme la note § 14), et les mois d'alerte mis en évidence.
- En tête : essence, poids utilisés, classe et niveau de l'année, date d'alerte s'il y en a.
- Données lues par la fonction « série d'un pixel » du cœur : rapide, sans réseau.

### 3. Comparaison avec FAST

Dans l'onglet ICD, un bloc « Comparaison avec FAST » pour la zone et l'année : tableau croisé des classes FAST 0-4 et niveaux ICD 0-4 en surfaces (ha), accord global et kappa (présenté comme indicateur, pas comme validation : les deux méthodes ont leurs erreurs), et la comparaison à surface alertée égale. Lit la fonction de comparaison du cœur. Si FAST n'a pas tourné sur la zone, le dire.

### 4. Sources & paramètres : poids de l'ICD (`R/mod_sources_config.R`)

- Une section « ICD — poids de la formule » : tableau 4 essences × 5 indices en `numericInput` (pas 0,05, bornes 0-1), CRre désactivé pour sapin/épicéa et douglas ; rappel de la formule et du sens des signes. Une somme par essence différente de 1 est acceptée et **renormalisée à 1** par le cœur : l'app affiche la somme saisie et les poids effectivement utilisés. Seuls les poids sont modifiables (pas les seuils ni les mois).
- Boutons « Valeurs par défaut » (`btn-outline-secondary`, valeurs de `nemeton::icd_poids_defaut()`) et « Enregistrer » (`btn-primary`), comme les paramètres ONF ; enregistrés **par projet** dans ses métadonnées (`set_project_icd_poids()` / `project_icd_poids()` dans un service), relus au calcul.
- Modifier les poids invalide les résultats ICD affichés (même règle que la mission 068 pour l'effet de la gestion) : la carte dit « poids modifiés, relancer le calcul ».
- Lecture seule (`deny_if_readonly`) respectée.

### 5. « Tout calculer »

Étape `sante_icd` après `sante_reconfort` (et après `sante_fordead` dans la chaîne) dans `PIPELINE_STEPS` (`R/service_pipeline.R`), sautée avec motif sans zone ou quand le calcul tourne déjà — **si Pascal le confirme** (question 4 du brief cœur).

## Règles de l'app à respecter

i18n partout, clés NMT ≤ 30 caractères, accents en `\uXXXX` ; aucun caractère non ASCII dans le code R ; couleurs de boutons (le calcul de l'ICD est l'action principale de l'onglet, `btn-primary` ; l'ICD n'est **pas** un contenu généré par IA : pas d'ambre) ; tests `testServer` (onglet présent après RECONFORT, clic → modale avec les deux graphiques, seuils tracés, CRre absent pour un résineux, poids enregistrés puis relus et passés au cœur, défauts restaurés, résultats invalidés après changement de poids, notification retirée à l'arrêt, comparaison FAST vide si FAST absent) avec le cœur simulé ; cycle dev, NEWS.

## Décisions de Pascal (2026-11-26)

Somme des poids renormalisée à 1 ; seuls les poids modifiables ; pas d'ICD hors des 4 peuplements purs (pixels transparents, nombre et motif dits) ; ICD dans « Tout calculer ».
