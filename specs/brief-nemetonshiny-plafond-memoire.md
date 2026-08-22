# Brief `nemetonshiny` — le plafond mémoire est décidé par le cœur (v0.183.0)

**Cœur requis** : `nemeton (>= 0.183.0)`.
**Portée app** : suppression de deux helpers, aucune logique nouvelle.
**Origine** : point laissé ouvert par le lot app v0.125.0 → v0.132.0
(`specs/BRIEF-nemeton-plan-md-0.125-0.132.md`, versant v0.124.2), tranché ici le
2026-08-22.

## Ce qui a été tranché, et pourquoi

L'app avait raison sur le fond : **70 % de la RAM n'était pas un plafond.** Sur
la station de référence (31,2 Go), cela fait 21 Go, quand `systemd-oomd` avait
déjà tué la session à **17,1 Go**. Le cœur adopte donc **50 % de `MemTotal`**,
le chiffre que `.compute_memory_max()` avait choisi — mais il l'adopte *pour de
bon*, comme politique unique.

Ce qui a été vérifié en tranchant, et que l'app ne pouvait pas voir :

* `ManagedOOMMemoryPressureLimit` vaut **2147483648**, soit 2³¹/2³² = **50 % de
  pression PSI** sur `user@1000.service`. C'est bien un seuil de *pression*, pas
  un seuil absolu : aucune fraction ne peut être prouvée correcte, la note
  d'`.compute_memory_max()` était juste.
* 50 % donne **15 Go** ici : sous le point de déclenchement observé (17,1 Go) et
  **au-dessus** du run légitime le plus lourd jamais mesuré (chaîne
  RECONFORT/IOTA2 complète, **11,3 Go** le 2026-07-13). Le plafond est encadré
  par deux mesures, pas posé au jugé.
* La session tournait sous **trois** plafonds différents : `.capped_memory_max()`
  (FORDEAD) et `mod_regeneration.R:139` prenaient le défaut cœur à 70 %,
  `.compute_memory_max()` (calcul des indicateurs) sa propre copie à 50 %. Trois
  travaux lourds de la même session, trois ceilings — c'est la même classe de
  défaut que le fork d'`INDICATOR_FAMILIES`, et elle se corrige au même endroit.

## Ce que l'app peut supprimer

| À supprimer | Remplacé par |
|---|---|
| `.compute_memory_max()` (`service_compute.R`) | `memory_max = NULL` → le cœur applique 50 % de `MemTotal` |
| `.capped_memory_max()` (`service_monitoring.R`) | idem — le cœur lit `NEMETON_MEMORY_MAX` lui-même |
| `.total_memory_bytes()` (`service_compute.R`) | plus de lecteur si les deux helpers partent |
| le commentaire `# memory_max = NULL -> defaut coeur (70 % RAM)` (`mod_regeneration.R:139`) | le défaut n'est plus 70 % |

`NEMETON_MEMORY_MAX` **reste la variable**, avec les mêmes valeurs de
désactivation (`none`, `off`, `false`, `no`, `0`). Elle doit continuer d'être
transmise au worker (`.capture_worker_envvars()`) : c'est lui qui lance l'enfant,
donc lui qui résout le plafond. Ordre de résolution côté cœur :

1. `memory_max =` au site d'appel (`FALSE` = aucun plafond) ;
2. `options(nemeton.memory_max)` — `nemeton.reconfort_memory_max` reste honoré ;
3. `NEMETON_MEMORY_MAX` ;
4. 50 % de `MemTotal`, plancher 4 Go (sous cela : aucun plafond, dit franchement).

## Ce qu'il ne faut PAS faire

**Ne pas ré-introduire une fraction côté app.** C'est ce qui a produit les trois
plafonds. Si 50 % s'avère trop bas sur une machine réelle, le remède est
`NEMETON_MEMORY_MAX` (opérateur) ou un argument explicite au site d'appel — pas
une quatrième copie de la politique.

## Vérification

| Contrôle | Attendu |
|---|---|
| Calcul des 31 indicateurs sur un projet avec R5 | tourne ; en cas de dépassement, l'enfant meurt seul avec le message du cœur, la session survit |
| `NEMETON_MEMORY_MAX=none` | aucun plafond, run non borné (échappatoire) |
| `NEMETON_MEMORY_MAX=8G` | `--property=MemoryMax=8G` sur le scope transitoire |
| Message d'échec | nomme `memory_max`, `NEMETON_MEMORY_MAX` et `options(nemeton.memory_max=)` |
| Les trois chemins lourds (indicateurs, FORDEAD, reGénération) | même plafond, sur la même machine |
