# Brief interne `nemeton` — `.reconfort_run_py()` est aveugle au même défaut

> **Statut** : ouvert, 2026-08-23.
> **Dépôt** : `nemeton` seul. Aucun impact app, aucun changement d'API publique.
> **Origine** : reliquat identifié en livrant la **v0.183.1**
> (`nemetonshiny/specs/BRIEF-nemeton-oom-sigterm-scope.md`), consigné dans
> `PLAN.md` et dans le NEWS de cette version.
> **Nature** : correctif de diagnostic. Le comportement ne change pas — seul le
> message change, et c'est tout l'enjeu.

---

## 1. Le constat

`run_memory_capped()` sait désormais dire *pourquoi* son enfant est mort :
il nomme son scope et demande son verdict à systemd. `.reconfort_run_py()`,
qui cape le sous-processus Python de la chaîne RECONFORT avec **le même**
`.reconfort_cap_memory()`, ne le sait pas. Ses quatre appelants rendent tous
un code de sortie brut :

| Site | Message actuel |
|---|---|
| `R/reconfort_ingest.R:322` | `S2 item listing failed (exit {st}).` |
| `R/reconfort_ingest.R:614` | `S2 download failed for tile {tile} (exit {st1}).` |
| `R/reconfort_ingest.R:656` | `S2 unzip failed for tile {tile} (exit {st2}).` |
| `R/reconfort_pipeline.R:504` | `RECONFORT map production failed for zone {zone_id} (exit {st}).` |

**Le quatrième est celui qui compte** : la production de cartes IOTA2 est
l'étape la plus lourde de la chaîne, celle pour qui tout l'appareillage cgroup
a été construit après l'incident du 2026-07-13. Elle tourne des heures. Quand
elle meurt d'un dépassement de plafond, elle le dit aujourd'hui
« (exit 137) ».

## 2. Ce qui a été mesuré (2026-08-23)

Reproduction exacte de la forme de `.reconfort_run_py()` — `system2()` sur la
commande construite par `.reconfort_cap_memory()` — avec un enfant qui dépasse
un plafond de 96 Mo :

| Variante | `system2()` rend | `Result` systemd |
|---|---|---|
| Telle quelle (`--collect`) | **137** | *aucune unité à interroger* |
| Avec `--unit=` | **137** | **`oom-kill`** |

Deux enseignements :

1. **Le code diffère de celui de `run_memory_capped()`.** `system2()` suit la
   convention shell (128 + signal → `137`, `143`), là où `processx` rend `-9` /
   `-15`. Un correctif copié-collé de la v0.183.1 ne marcherait pas.
2. **`137` est ambigu de la même façon** : un `kill -9` extérieur le produit
   aussi. Le raisonnement de la v0.183.1 s'applique tel quel — **constater, ne
   pas inférer**.

Le `-15`/`143` n'a pas été reproduit ici, pas plus qu'en v0.183.1 ; il est
attesté en production sur l'autre chemin. Le correctif ne doit donc pas
dépendre de la liste des codes.

## 3. Ce qu'il faut faire

### 3.1 Nommer l'unité — et reprendre son ménage

`.reconfort_cap_memory(unit =)` existe depuis la v0.183.1 et fait déjà le
travail. **Rappel du piège, déjà payé une fois** : `--collect` et
l'interrogation sont **exclusifs** — avec `--collect`, un scope mort d'OOM
répond `Result=success`. Nommer l'unité impose donc d'appeler
`.capped_scope_reset()` sur **tous** les chemins de sortie
(`on.exit(..., add = TRUE)` : `system2()` est bloquant, c'est facile ici).

### 3.2 Rapporter le verdict sans casser les quatre appelants

Les quatre testent `identical(as.integer(st), 0L)`. Proposition la moins
invasive : `.reconfort_run_py()` continue de rendre le **statut**, avec le
verdict en **attribut**.

```r
st <- .reconfort_run_py(...)          # inchangé pour les appelants
attr(st, "scope_result")              # "oom-kill", "signal", … ou NA
```

`as.integer()` laisse tomber les attributs : les quatre tests de nullité
restent vrais mot pour mot, sans les toucher.

### 3.3 Un message par site, qui garde son contexte

Ne **pas** centraliser l'abort dans `.reconfort_run_py()` : chaque site dit ce
qui a échoué (« pour la tuile T31UFQ », « pour la zone 5 »), et c'est la moitié
utile du message. Prévoir plutôt un helper qui **complète** :

```r
.reconfort_py_failure(head, status)   # head = la phrase de contexte du site
```

qui rend la phrase de contexte, puis — selon `attr(status, "scope_result")` —
les mêmes trois niveaux de certitude qu'en v0.183.1 :

| Verdict | Ce que le message dit |
|---|---|
| `oom-kill` | dépassement du plafond, **affirmé** ; plafond et échappatoires nommés |
| autre | ce que systemd a dit, **sans** prétendre à un OOM |
| indisponible | le plafond en cause *habituelle*, pas en fait établi |

`.capped_failure_message()` (`R/memory-ceiling.R`) porte déjà cette logique.
La question de conception à trancher : **la généraliser** (elle prend déjà
`fun`, `status`, `ceiling`, `result` — il lui manque de savoir lire un `137`
autant qu'un `-9`, ce qu'elle fait déjà via sa branche `status > 128L`), ou
écrire un helper voisin. **Recommandation : la généraliser**, en lui passant la
phrase de contexte à la place du nom de fonction. Deux copies d'une politique
de message finiraient par diverger — c'est le motif qui a coûté trois jours en
août (fork `INDICATOR_FAMILIES`, puis trois plafonds mémoire).

## 4. Ce qu'il ne faut PAS faire

* **Ne pas ajouter `137`/`143` à une liste de codes « qui veulent dire OOM ».**
  C'est l'option que la v0.183.1 a écartée sur mesure : elle échange un faux
  négatif contre un faux positif (`kill -9` extérieur, arrêt de session).
* **Ne pas garder `--collect` en croyant interroger l'unité ensuite.** Mesuré :
  la réponse est alors `success`, c'est-à-dire l'inverse de la vérité.

## 5. Vérification

| Contrôle | Attendu |
|---|---|
| Dépassement provoqué sur un des quatre chemins | message **mémoire**, avec le contexte du site (tuile / zone) conservé |
| Échec Python ordinaire (traceback, exit 1) | message inchangé, **aucune** mention de mémoire |
| `kill -9` extérieur sur le sous-processus | ne pas prétendre à un OOM |
| Sans `systemd-run` (mode dégradé) | message hedgé, jamais une affirmation |
| Après une série d'échecs | **zéro** unité systemd résiduelle (`systemctl --user list-units 'nemeton-*.scope'`) |

## 6. Coût, et faut-il le faire

Petit : un `on.exit` et un attribut dans `.reconfort_run_py()`, une
généralisation de `.capped_failure_message()`, quatre sites qui passent d'un
`cli_abort()` littéral à un appel de helper. L'essentiel du travail — la
politique de message, le piège `--collect`, les helpers d'interrogation — est
déjà écrit et testé.

**Argument pour** : la chaîne RECONFORT tourne des **heures**. Un mauvais
diagnostic y coûte exactement ce qu'a coûté l'incident Couchey — une soirée
avant qu'on pense à ouvrir `journalctl`. C'est aussi le seul chemin restant où
le plafond mémoire, qu'on vient de recalibrer deux fois, peut mordre sans le
dire.

**Argument contre** : aucun incident RECONFORT n'a *encore* été mal
diagnostiqué de cette façon — le défaut est démontré par construction et par la
mesure du §2, pas par une soirée perdue.

**Recommandation** : à faire, mais sans urgence — c'est de la dette dont on
connaît le prix. À planifier avec le prochain travail qui touche la chaîne
RECONFORT, plutôt qu'en interruption.
