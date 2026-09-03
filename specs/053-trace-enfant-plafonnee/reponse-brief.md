# Réponse au BRIEF « la sortie de l'enfant plafonné part dans /dev/null »

> **Brief d'origine** : `nemetonshiny/specs/BRIEF-nemeton-trace-enfant-plafonne.md`
> (2026-09-03). **Livré côté cœur** : `nemeton` v0.195.0.
> **Statut** : demande A livrée, demande B **tranchée** — ce n'était pas une
> hypothèse à confirmer, c'était une mesure à aller chercher.

---

## 0. La réponse courte à la demande B

**Le run Couchey est mort de la mémoire.** Pas celle de l'enfant plafonné posé
par l'app — celle du scope *interne*, posé par le cœur autour de
`conda run … Iota2.py`. systemd l'a écrit dans le journal, à la seconde près :

```
Sep 03 16:49:24 run-r459be71be8c642d4acf26265c7fcbfbe.scope:
    A process of this unit has been killed by the OOM killer.
Sep 03 16:49:26 run-r459be71be8c642d4acf26265c7fcbfbe.scope:
    Failed with result 'oom-kill'
Sep 03 16:49:26 run-r459be71be8c642d4acf26265c7fcbfbe.scope:
    Consumed 32min 52.257s CPU time, 11.5G memory peak, 0B memory swap peak.
```

Les trois mesures de la section 0 du brief sont justes et ne se contredisent
pas : elles portaient sur le scope **externe** (`nemeton-run_reconfort_dieback-…`,
0,97 Go) et sur la *user slice*. Le scope qui a débordé est celui de la ligne
`run-r459be71b…` que le brief lui-même relève en section 4 — à 7,7–11,5 Go sous
12 Go. Le pic final : **11,5 Go pour un plafond de 12 Go**.

Ce scope-là ne savait pas demander son verdict à systemd. C'est le seul des
deux qui ait été oublié par le correctif du 2026-08-23 (brief
`BRIEF-nemeton-oom-sigterm-scope.md`), qui n'avait équipé que
`run_memory_capped()`. D'où un `exit 1` sans explication là où systemd avait la
réponse depuis le début. **C'est corrigé** (§2).

## 1. Le déroulé exact, reconstitué depuis le disque

Le répertoire de travail du run est toujours là
(`…/projects/20260828_140251_hwuy/cache/layers/reconfort/output_zone_49/`), et
avec lui les logs par tâche qu'IOTA² écrit sous `logs/ClassificationUsingOTB/`.

| Heure | Événement |
|---|---|
| 16:46:24 | chunk **2** démarre — `start_y 443, size_y 221` |
| 16:46:56 | dask : *Unmanaged memory use is high — 6.56 GiB / worker limit 9.31 GiB* |
| 16:47:22 | `ram before classification : 10 770 MB` |
| 16:48:02 | `ram after classification : 11 457 MB` — `SUBREGION_2.tif` **écrit** |
| 16:48:09 | chunk **0** démarre, 7 s plus tard, sur un tas qui n'a rien rendu |
| 16:48:46 | `processing region start_x 0, size_y 221` — dernière ligne du log |
| 16:49:24 | **OOM kill** du scope |

Le chunk 2 est passé à 0,5 Go du plafond. Le chunk 0 est parti aussitôt après,
alors que dask tenait encore 6,56 GiB de mémoire *unmanaged* qu'il n'avait pas
rendue à l'OS. Il n'y avait pas la place, et personne ne l'avait vérifié.

### Sur le suffixe `SUBREGION_2`

L'œil du brief était bon, l'interprétation à corriger : `_SUBREGION_<n>` n'est
pas une **sous-région** de l'AOI, c'est l'index de **chunk**. Vérifié dans
l'iota2 installé :

* `steps/classification_otb.py` : `for chunk in range(number_of_chunks)`, une
  tâche par chunk, nommée `classification_<tuile>_model_<m>_seed_<s>_<chunk>` ;
* `classification/image_classifier.py` : `sub_name = f"_SUBREGION_{targeted_chunk}"` ;
* `steps/sk_classifications_merge.py` : la fusion **reconstruit la liste des
  `range(number_of_chunks)` fichiers** pour les assembler.

Le cfg de la part 2 demandait `number_of_chunks: 4` — donc les chunks 0, 1, 2, 3.
Un seul a été écrit. L'étape de fusion existe bel et bien dans le graphe
(`first_step: classification`, `last_step: mosaic`, et `run_informations.txt`
liste les steps 12/13/14 : *Generate classifications*, *Merge tile's
classification's part*, *Mosaic*) — elle n'a simplement jamais été atteinte.

Et « huit tâches, toutes `done` » : `IOTA2_tasks_status.txt` est un **pickle**
qui n'enregistre que les tâches *terminées*. Une tâche morte n'y laisse rien.
Un graphe complet à 100 % dans ce fichier ne veut donc pas dire « chaîne
terminée », il veut dire « voilà ce qui a fini ». C'est ce qui donnait
l'impression d'un arrêt propre.

### Pourquoi la chaîne s'est tue

Trois silences empilés, tous levés dans cette version :

1. **`run_map_production_reconfort.py` ne lisait pas le code de retour** des
   deux `subprocess.run([...Iota2.py...])`. IOTA² pouvait mourir : le script
   continuait, et la première erreur visible était le masquage sur un
   `final/Classif_Seed_0.tif` absent — un symptôme à trois étapes de la cause.
2. **`.reconfort_run_py()` ne nommait pas son scope**, donc ne pouvait pas
   demander son verdict à systemd (§0).
3. **La sortie de l'enfant partait dans `/dev/null`** — votre demande A.

## 2. Ce qui est livré

### Demande A — `log_path` (livrée telle que demandée)

`run_memory_capped()` prend un argument `log_path = NULL` :

* `NULL` → comportement **strictement inchangé** (`""` / héritage, ou `NULL`
  sous `quiet`) ;
* un chemin → `stdout = log_path, stderr = "2>&1"` (flux fusionnés, dans
  l'ordre de lecture), le dossier parent créé au besoin, le fichier **conservé
  quel que soit le sort de l'enfant** — échec comme succès.

`log_path` l'emporte sur `quiet`. Et le message d'échec cite le fichier :

```
✖ "run_reconfort_dieback" ran out of memory and was killed (ceiling: 12G).
ℹ Raise it with `memory_max`, NEMETON_MEMORY_MAX (accepts "none")…
ℹ The rest of the session was spared — only the job died.
ℹ The child's output was kept in '…/data/reconfort_child.log'.
> RECONFORT map production (zone 49) ran out of memory…
```

**Bonus non demandé** : les 5 dernières lignes non vides du fichier sont citées
sous le chemin (tronquées à 200 caractères chacune). Le but n'est pas de
recopier le log dans une erreur, c'est de porter *la* ligne qui nomme la cause
jusque dans le message que l'app affiche — le fichier a le reste. Les accolades
du contenu sont échappées : un `KeyError: {'a': 1}` ne redevient pas une
expression cli.

L'app posera donc son `log_path` à côté du NDJSON, et les deux se complètent
exactement comme vous l'écrivez : le NDJSON dit **jusqu'où**, le log dit
**pourquoi**.

### Demande B — la chaîne mapprod ne devine plus

1. **`.reconfort_run_py()` nomme son scope** et accroche le verdict systemd au
   statut retourné (attribut `systemd_result`). `as.integer(st)` le laisse
   tomber, donc tous les appelants existants sont inchangés. Le message
   d'échec de `mapprod` passe par le même `.capped_failure_message()` que
   l'enfant plafonné : avec le verdict `oom-kill`, il **affirme** la mémoire et
   nomme les échappatoires ; sans verdict, il ne prétend rien.

2. **L'état d'IOTA² voyage avec l'erreur** (`.reconfort_iota2_diagnosis()`).
   Sur le run Couchey, l'erreur aurait dit, en trois lignes, ce que vous avez
   reconstitué à la main :

   ```
   ℹ Chunked classification: 1 of 4 chunks written in '…/classif'.
   ℹ Missing 3 chunks: 0, 1, and 3. The merge step needs every one of them.
   ℹ '…/final' holds no raster — neither the merge nor the mosaic step completed.
   ℹ IOTA2's own task states are in '…/IOTA2_tasks_status.txt' (a python pickle)
     and its per-task logs in '…/logs'.
   ```

3. **Le driver python vérifie ses sous-processus** : les deux appels IOTA² sont
   passés par un `run_iota2()` qui teste `returncode` et sort avec, message sur
   `stderr`. Et avant le masquage, `require_final()` exige les rasters
   attendus, en listant `final/` et `classif/` quand ils manquent — un code de
   retour nul ne vaut pas « chaîne terminée ».

### Le fond : le découpage en chunks ignorait la largeur de l'AOI

`.RECONFORT_ROWS_PER_CHUNK = 240` a été calibré sur une AOI de **930** colonnes
(pic mesuré : 13,4 Go). Or le pic suit l'**aire** du chunk, pas sa hauteur.
Couchey fait **1160 × 886** : 4 chunks de 221 lignes, soit 256 360 px par
chunk — **15 % de plus** que le point de calibration, sur une machine dont le
plafond est 12 Go.

Et surtout : **13,4 Go de pic calibré contre un plafond de 12 Go**. La cible du
découpeur et le plafond mémoire n'avaient jamais été mis face à face ; ils ne
coexistaient que parce qu'aucun run ne s'en était approché. Le 3 septembre, un
s'en est approché.

`.reconfort_chunk_count()` prend donc désormais deux bornes, la plus serrée
gagne :

* la règle historique des 240 lignes, **jamais dépassée** (cette fonction ne
  peut que faire des chunks plus petits qu'avant, jamais plus gros) ;
* un budget en pixels dérivé du plafond en vigueur : 75 % du plafond, à
  ~60 kB/px (le **pessimiste** des deux mesures — Couchey donne ~45 kB/px).

Sur l'AOI de Couchey, à 12 Go : **7 chunks de 127 lignes** au lieu de 4 de 221.
Pic prédit ≈ 6,6 à 8,8 Go — de la marge, enfin. Le coût est de trois
préparations de features de plus (~37 s chacune), à comparer aux 20 h perdues.

Et le découpage suit maintenant `NEMETON_MEMORY_MAX` : lever le plafond
élargit les chunks, le baisser les resserre. Sans plafond lisible (hors Linux,
plafond désactivé), seule la borne des 240 lignes s'applique — comportement
identique à avant.

## 3. Sur la composition des plafonds (votre §4)

Rien n'est changé, vous ne demandiez rien, et je n'ai pas de proposition propre
non plus. Une remarque quand même, puisque le diagnostic la touche : les deux
scopes frères de 12 Go n'ont pas mordu ensemble. Celui de l'app est resté à
0,97 Go, celui du cœur est mort seul. Le pire cas cumulé à 24 Go reste
théorique — mais ce qui a tué le run, ce n'est pas la somme des plafonds, c'est
qu'**un seul** des deux était dimensionné pour un travail plus gros que lui.

## 3 bis. Le run de contrôle — fait, et ce qu'il a dit

Rejoué le 2026-09-03 au soir sur la zone 49, mêmes 203 scènes, même plafond de
12 Go. **Il est passé** : 16 tâches `done` dont les 7 chunks, `final/` complet
(9 rasters, dont `Final_continuous_score_masked2025.tif`), 2492 alertes,
**14,9 min**, zéro évènement oomd.

| | 16:47 (mort) | 21:1x (ce run) |
|---|---|---|
| Chunks | 4 × 221 lignes (256 360 px) | **7 × 127 lignes** (147 320 px) |
| Pic RAM classification | **11 457 Mo** | **10 250 Mo** |
| Marge sous 12 Go | 0,54 Go | **1,75 Go** |
| `classif/…_seed_0.tif` fusionné | absent | présent |

### La mesure a corrigé le modèle

Les deux points sur la même emprise donnent `pic ≈ 8,42 GiB + 11,1 kB/px`. Le
pic est donc **majoritairement un coût fixe** — modèle SharkRF déplié et pile
gap-fillée par tuile — et seulement marginalement proportionnel au chunk :
diviser le chunk par deux a gagné 1,2 Go, pas la moitié du pic. J'avais annoncé
« pic prédit ≈ 6,6 à 8,8 Go » : c'était faux, et c'est le run qui le dit.

Conséquence à garder : **le découpage ne peut pas descendre sous ~8,4 GiB.** Un
plafond proche de ce chiffre n'est atteignable par aucun nombre de chunks ; les
leviers deviennent moins de dates, une emprise plus petite, ou un plafond plus
haut. Les constantes sont laissées telles quelles — elles ont produit la
configuration validée, et les caler sur deux points serait de la fausse
précision ; seul leur commentaire a été corrigé.

### Une fragilité amont, découverte en chemin

Pour rejouer proprement il fallait écarter le `results/` du run raté : son
pickle de reprise donnait le chunk 2 pour fait, avec l'ancienne géométrie (221
lignes au lieu de 127). Ce part 1 reparti de zéro a échoué **deux fois** sur
`tiles_envelopes` :

```
RuntimeError: …/envelope/TMP/T31TFN.shp: No such file or directory
ValueError: The chain stopped prematurely.
```

Or le même `generate_shape_tile()` appelé hors chaîne, mêmes arguments, produit
une enveloppe **byte-identique** (md5) à celle du run de 16:45. C'est donc un
défaut d'iota2, déterministe dans la chaîne et absent hors chaîne, que
`-restart` masquait en reprenant toujours un part 1 antérieur. **Tout run
repartant de zéro le rencontrera.** Contourné ici en inscrivant l'étape comme
faite dans l'état de reprise, artefact vérifié identique au préalable.

Ce n'est pas nemeton, et je ne l'ai pas corrigé. Mais il est désormais *visible*
— c'est exactement ce que les trois correctifs de la §2 servent à produire.

## 4. Pour rejouer

Le cache d'ingestion est intact (203 scènes, marqueurs `.done`), un
`run_reconfort_dieback()` repart directement en `mapprod`. Avec cette version,
le même run redécoupe en 7 chunks. S'il échoue quand même, il le dira : verdict
systemd, chunks manquants, état de `final/`, et — si l'app passe un `log_path`
— les dernières lignes de l'enfant.

C'est la prédiction à valider. Elle repose sur une mesure (11,46 Go pour
256 360 px) et une extrapolation prudente ; le run de contrôle tranchera.

## 5. Côté app — ce qu'il reste à câbler

Un seul point, et il est petit : passer `log_path` à `run_memory_capped()` dans
les trois chemins plafonnés (FAST, FORDEAD, RECONFORT), par exemple
`…/data/<pipeline>_child.log`, avec la même rotation que les
`.ndjson.failed-<horodatage>` de la v0.143.15. Rien d'autre ne bouge : l'API est
strictement additive, et sans `log_path` le comportement est celui d'aujourd'hui.
