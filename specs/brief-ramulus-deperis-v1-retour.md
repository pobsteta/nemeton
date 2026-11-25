# Brief `ramulus` — nemeton lit et écrit `deperis-v1` (retour)

**Date** : 2026-11-25. **Émetteur** : `nemeton` (copie de référence, versionnée ici). **Destinataire** : Ramulus.
**Réponse à** : `pilotage/briefs/vers-nemeton/2026-10-28-ramulus-tournee-deperis.md` (dépôt Ramulus).
**Livré** : `nemeton` #703 (mission 061, 8862e55) et la suite des décisions de Pascal (mission 064, cette branche).

Dépôt dans `~/dev/briefs/vers-ramulus/` : **non fait** (le répertoire est hors du conteneur où la session a tourné).
Cette copie fait foi ; il reste à la déposer là-bas, ou à la transmettre par la voie du dépôt.

## 1. Ce que nemeton fait désormais

- `creer_tournee_deperis()` écrit le `deperis.gpkg` de départ (première notation ou contre-notation).
- `importer_deperis()` importe le `.zip` rendu par Ramulus : verdict `accepte` / `signale` / `refuse` et motifs du
  catalogue du format ; tout ou rien ; rejouable sans doublon (union sur l'`uuid`).
- Le schéma `deperis-v1` et les 39 cas communs de `fixtures/echange/` sont **copiés, non édités**, avec empreintes
  SHA-256 vérifiées par un test (`inst/schemas/README.md`, `tests/testthat/fixtures/deperis-v1/README-ramulus.md`).
  Commit d'origine côté Ramulus : `fb5739a` (dernier commit touchant schéma ou cas : `91f6d94`, 2026-10-29).
  Une nouvelle version du format se recopie sur brief de Ramulus, jamais à la main.

## 2. Ce qu'il faut savoir

- **T2 est sauté** : c'est un cas de *saisie* (`enregistrement`), qui relève de Ramulus ; un lecteur de fichier le saute
  (README des cas). nemeton rejoue les 38 autres.
- **Le GeoPackage est écrit par RSQLite**, non par GDAL : GDAL déclare `MEDIUMINT` pour les entiers 32 bits, que le
  schéma refuse. GDAL (sf) relit le fichier sans difficulté.
- **Conflit d'`uuid` entre paquets = signalement, pas refus** : si deux paquets portent le même `uuid` avec un contenu
  différent, nemeton garde une version, écarte l'autre, rend le conflit dans `conflits` et signale
  (`uuid_contenu_different`) ; rien n'est tranché en silence.
- Aucune note DEPERIS réelle n'a servi : les essais sont sur les cas communs et sur des jeux `synth_`.

## 3. Décisions de Pascal (2026-11-25)

1. **Délai de contre-notation : aucun.** `tournee.delai_contre_notation_jours` reste vide (`NULL`), par décision.
2. **Seuil « centre éloigné » : 30 m, retenu** (ce n'est plus « provisoire »). Le motif reste `centre_eloigne` ; le
   texte du message dit « seuil 30 m ». Votre ADR 0004 peut retirer sa mention « provisoire ».
3. **Graine du tirage des 5 % dérivée du code de tournée** : par défaut, graine = premiers 7 chiffres hexadécimaux du
   SHA-256 du `code` (UTF-8), lus comme entier. Même code, même tirage ; codes différents, tirages indépendants. Un
   `graine =` explicite reste possible pour rejouer un cas. **Aucune colonne ajoutée** : `tournee` n'a pas de place
   pour elle dans `deperis-v1` ; la graine se **recalcule depuis `code_tournee`**, déjà écrit. Ramulus n'a rien à lire
   ni à écrire pour cela.

## 4. Ce qui n'est pas demandé à Ramulus

Aucun changement de schéma, aucun nouveau cas commun. Si votre ADR 0004 ou vos cas (`S2`, source « 30 m, provisoire »)
doivent refléter la décision 2, c'est de votre côté ; nemeton garde la copie d'origine telle quelle (empreinte).
