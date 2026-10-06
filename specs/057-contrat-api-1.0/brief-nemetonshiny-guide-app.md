# BRIEF `nemetonshiny` — reprendre le guide de l'app (`nemetonapp-guide_fr.Rmd`)

> **Émis le 2026-10-06** par la session `nemeton` (décision Pascal pour la
> 1.0.0). **Dépôt concerné** : `nemetonshiny`.

Le cœur porte encore `vignettes/nemetonapp-guide_fr.Rmd` (151 lignes), le guide
d'utilisation de l'**application**. Sa place est dans `nemetonshiny` : il décrit
des écrans, des onglets et des parcours qui évoluent avec l'app, pas avec le
cœur.

## À faire côté app

1. Reprendre le fichier (copie de référence : `nemeton/vignettes/nemetonapp-guide_fr.Rmd`
   au tag de la dernière version 0.x du cœur) dans `nemetonshiny/vignettes/`, et
   l'actualiser (onglets et parcours de la 0.156+, API hors interface, serveur
   MCP).
2. L'ajouter au site pkgdown de l'app.

## Côté cœur

Le fichier est **retiré du cœur dans la 1.0.0**. Aucun lien du cœur n'y renvoie
(vérifié : ni `_pkgdown.yml`, ni README, ni autre vignette).
