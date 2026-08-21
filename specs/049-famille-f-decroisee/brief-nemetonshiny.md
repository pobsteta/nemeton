# Brief `nemetonshiny` — la famille F est décroisée (spec 049)

**Cœur requis** : `nemeton (>= 0.182.0)`.
**Portée app** : une vérification, pas forcément du code.

## Ce qui change

Dans `INDICATOR_FAMILIES`, la famille F était croisée : le créneau **F1**
portait le libellé « Risque d'érosion » et la colonne `indicateur_f2_erosion`,
et réciproquement. Les deux erreurs s'annulaient à l'affichage.

C'est décroisé : **F1 = fertilité, F2 = érosion**, conformément au nom des
fonctions, au résolveur d'alias du cœur et à `CLAUDE.md`.

## Ce qui NE change pas

- **Aucune valeur.** Aucune donnée persistée n'est touchée, aucun recalcul
  nécessaire — rien à voir avec la correction de la famille R (spec 048), qui
  imposait, elle, de tout recalculer.
- **Aucun nom de colonne.** `indicateur_f1_fertilite` et
  `indicateur_f2_erosion` sont inchangés : ils étaient déjà justes.
- **Le libellé affiché** en face de chaque valeur : il était déjà correct.

## Ce qu'il faut vérifier

**Un axe étiqueté « F1 » en dur.** L'érosion passe du créneau F1 au créneau F2.
Une interface qui écrit la lettre plutôt que de la lire dans la table affichera
désormais la mauvaise grandeur.

**Un fork de la table.** `app_config.R` a déjà divergé du cœur par le passé
(cf. brief `brief-nemetonshiny-indicator-families.md`). S'il porte encore sa
propre copie de la famille F, il conserve le croisement — et cette fois les deux
tables ne diront plus la même chose. Le remède reste le même : lire
`nemeton::indicator_families()` plutôt que dupliquer.

## Vérification

| Contrôle | Attendu |
|---|---|
| Axe F1 du radar | libellé **Fertilité des sols**, valeurs de `indicateur_f1_fertilite` |
| Axe F2 du radar | libellé **Risque d'érosion**, valeurs de `indicateur_f2_erosion` |
| Infobulle F2 | parle de topographie (TWI, pente) et de texture, plus de « couverture végétale » |
| `famille_fertilite` | **inchangée** — c'est une moyenne, l'ordre des colonnes n'y entre pas |
