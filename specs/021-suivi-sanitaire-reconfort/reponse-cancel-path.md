# Réponse au brief `nemetonshiny` du 2026-09-14 — `run_reconfort_dieback(cancel_path=)`

> Brief d'origine : `briefs/vers-nemeton/2026-09-14-reconfort-cancel-path.md`.
> **Livré dans `nemeton` v0.196.0** — c'est le numéro à mettre au plancher
> `Imports:`.

## 1. Ce qui est livré

`run_reconfort_dieback()` accepte `cancel_path`, dernier paramètre de la
signature, après `progress_callback`. Le contrat est celui de `R/cancel.R`,
partagé avec FAST et FORDEAD — les trois pages d'aide se lisent désormais
pareil.

| Pipeline | Paramètre | Checker |
|---|---|---|
| FAST | `cancel_path = NULL` | `.make_cancel_checker()` |
| FORDEAD | `cancel_path = NULL` | `.make_cancel_checker()` + `.signal_cancel_fordead()` |
| **RECONFORT** | **`cancel_path = NULL`** | `.make_cancel_checker()` + `.signal_cancel_reconfort()` |

## 2. Où la scrutation a lieu, et ce que ça coûte

Comme demandé au §2.3 : **frontière de phase uniquement**, dans le crochet
`begin()`. Le check se fait à l'*entrée* de la phase suivante, donc la phase en
cours va toujours à son terme.

Conséquence à garder en tête côté app pour le libellé du bouton et le toast :
une phase `mapprod` (IOTA2) dure des dizaines de minutes, et l'arrêt ne prendra
effet qu'après. C'est écrit dans le `@param`, mais l'utilisateur lit le toast,
pas la page d'aide. Un « arrêt demandé — prendra effet à la fin de l'étape en
cours » serait plus juste qu'un « arrêté » immédiat.

Les dix phases, dans l'ordre : `env`, `model`, `mask`, `tiles`, `ingest`,
`stage`, `mapprod`, `collect`, `postprocess`, `persist`.

## 3. Contrat de sortie

À l'observation du flag :

* **événement** `reconfort:cancelled`, avec `zone_id`, `phase_name` (la
  dernière phase **terminée**), `completed` (nombre de phases allées au bout),
  `total` (10) et `elapsed_sec` ;
* **résultat** `status = "cancelled"`, champ `phase` (même valeur que
  `phase_name`), `message`, et la forme habituelle du résultat avec `NULL` /
  `NA` là où les phases déclinées auraient produit quelque chose
  (`rasters`, `alerts_sf`, `n_alerts`, `features_bundle`, `meta`).

Attention : le succès reste `status = "completed"` (pas `"success"` — c'est
l'usage historique de RECONFORT, inchangé), et un **échec** continue d'aborter
au lieu de renvoyer un statut. Trois sorties possibles, donc : `completed`,
`cancelled`, ou une condition d'erreur.

## 4. Ce qui survit à un arrêt

`keep_workdir = FALSE` **ne s'applique plus** à un run annulé : le répertoire de
travail est conservé. Les scènes déjà ingérées et ce qu'IOTA2 a déjà écrit
restent relisibles par un re-run `skip_ingest = TRUE`. C'était le §2.4 troisième
point — sans ça, annuler coûterait exactement autant qu'échouer.

## 5. Les quatre garanties du §3, testées

`tests/testthat/test-reconfort-pipeline.R`, cinq cas en miroir de
`test-ingest-cancel.R` :

1. `cancel_path = NULL` → **zéro** appel au système de fichiers (le spy sur
   `.cancel_flag_exists()` compte 0) ;
2. flag posé **avant** l'appel → `cli_warn` « already present at entry », le run
   va au bout ;
3. flag posé **pendant** (phase `mask`) → `status = "cancelled"`, `phase ==
   "mask"`, `tiles` et la suite jamais démarrées, IOTA2 jamais invoqué,
   `reconfort:cancelled` émis avec `completed == 3` ;
4. chemin malformé → lu comme « pas d'annulation », jamais une erreur ;
5. (en plus) `keep_workdir = FALSE` + annulation → le workdir et les scènes
   ingérées sont toujours là.

## 6. Côté app

Rien à concevoir, le brief l'avait déjà cadré :

* `Imports: nemeton (>= 0.196.0)` ;
* `.reset_reconfort_run()` écrit `reconfort_cancel.flag` via
  `.resolve_progress_path()` — et **supprime le flag avant chaque `invoke()`**,
  sinon le garde-fou anti-« phantom cancel » désarmera le run suivant ;
* `.invoke_reconfort()` passe `cancel_path = .reconfort_cancel_flag` ;
* le commentaire de `.reset_reconfort_run()` qui documentait l'asymétrie tombe ;
* penser au toast : l'arrêt est *coarse* (cf. §2).
