# Brief nemetonshiny — isoler FORDEAD (et la reGénération) dans un process plafonné

**Cœur : `nemeton` ≥ 0.157.0** — nouvelle fonction exportée `run_memory_capped()`.
**Statut côté app : à faire.** Rien n'est cassé si vous ne faites rien ; simplement,
un run FORDEAD qui déborde continuera d'emporter toute la session.

---

## 1. Le problème (rappel)

`systemd-oomd` ne tue pas le processus fautif. Sous pression mémoire, il tue le
**scope** entier : le 2026-07-13 un run RECONFORT a emporté R, l'app *et* la
session de surveillance ; le 2026-07-14, RStudio est reparti à l'OOM **en plein
FORDEAD**.

RECONFORT est protégé depuis la v0.155.0 parce que son Python est un
**sous-processus** (`conda run python`) : le cœur le plaçait déjà dans un cgroup
plafonné. FORDEAD n'a pas cette chance — son Python tourne dans l'interpréteur
**embarqué** de reticulate (`fp$fit()`, `fp$predict()`), et les moteurs
reGénération sont du R pur. Leur mémoire *est* celle du worker `future`, donc
celle du scope de l'app. **Il n'y a rien à plafonner en in-process.**

La seule issue : déplacer le travail dans un **process R enfant** et plafonner
celui-là. C'est ce que fait `nemeton::run_memory_capped()`.

## 2. Ce que le cœur fournit

```r
nemeton::run_memory_capped(
  fun,                 # nom (chaîne) d'une fonction exportée du cœur
  args = list(),       # arguments sérialisables (pas de connexion, pas de closure)
  db_url = NULL,       # l'enfant ouvre SA connexion via db_connect()
  progress_path = NULL,
  progress_callback = NULL,
  memory_max = NULL,   # défaut : 70 % de la RAM. FALSE = pas de plafond.
  quiet = FALSE
)
```

Deux arguments ne traversent pas une frontière de process et sont donc
**reconstruits dans l'enfant** :

- **`con`** — une `DBIConnection` n'est pas sérialisable → passez **`db_url`**.
- **`progress_callback`** — une closure non plus → passez **`progress_path`**.
  L'enfant y écrit au **format exact** de `.build_progress_writer()`
  (`<path>.json` atomique = dernier événement ; `<path>.ndjson` = journal), et le
  **parent tail ce fichier et rejoue chaque événement** dans le
  `progress_callback` que vous lui passez. **Les push ntfy sont donc préservés.**

Un run qui déborde meurt **seul**, avec une erreur attrapable :
> `"run_fordead_dieback" ran out of memory and was killed (ceiling: 21G).`

Sans `systemd-run` (CI, conteneur sans bus utilisateur) : le travail tourne quand
même dans un enfant, mais **sans plafond**, avec un warning explicite.

## 3. Le changement côté app

Dans `service_monitoring.R`, worker FORDEAD (~l. 616) :

```r
result <- tryCatch(
  nemeton::run_memory_capped(
    "run_fordead_dieback",
    args = list(
      zone_id           = zone_id,
      cache_dir         = cache_dir,
      dates_training    = dates_training,
      dates_monitoring  = dates_monitoring,
      threshold_anomaly = threshold_anomaly,
      vegetation_index  = vegetation_index,
      output_dir        = output_dir,
      keep_output       = keep_output,
      cancel_path       = cancel_path
    ),
    db_url            = db_url,        # <- au lieu de con = con
    progress_path     = progress_path, # <- l'enfant écrit les deux fichiers
    progress_callback = ntfy_cb        # <- voir le piège ci-dessous
  ),
  error = function(e) { ... }  # inchangé
)
```

### ⚠️ Le piège : ne pas passer le callback **composite**

`.build_fordead_progress_callback()` est composite : **écriture fichier + push
ntfy**. Sous isolation, **l'enfant écrit déjà le fichier**. Si vous rejouez le
callback composite dans le parent, chaque événement est écrit **deux fois**
(lignes NDJSON dupliquées, console en double).

→ Passez en `progress_callback` **la partie ntfy seule** : le même corps que
`.build_fordead_progress_callback()` **sans** `file_cb` (garder l'état
`last_phase` pour la dédup par phase). En pratique, extraire un
`.build_fordead_ntfy_callback(ntfy, i18n)` et faire de l'actuel composite un
`function(event) { file_cb(event); ntfy_cb(event) }` — les deux appelants
existants ne bougent pas, l'appelant isolé n'utilise que `ntfy_cb`.

Idem pour RECONFORT si vous l'isolez un jour au niveau R (inutile : son Python
est déjà plafonné).

### Ce qui ne change pas

- Le `reactivePoll` du parent sur `progress_path` : **inchangé** (mêmes fichiers,
  même format).
- `cancel_path` : **inchangé** — l'enfant poll le même fichier ; l'annulation
  coopérative marche toujours.
- Le worker `future` reste utile (il garde l'UI réactive). L'enfant plafonné vit
  *dans* le worker.

## 4. Plafond conseillé

Le défaut (70 % de la RAM) est volontairement large. Sur une machine à 32 Go
partagée avec RStudio, `memory_max = "16G"` laisse de l'air au reste ; c'est un
réglage, pas une correction — à ajuster si un run légitime se fait tuer.

## 5. Détail utile (mesuré le 2026-07-14)

`MemoryMax=` **seul ne tue pas** sur une machine avec swap (celle de Pascal en a
8 Go) : le cgroup déborde dans le swap et **rame** au lieu de mourir — et ce
thrashing est précisément la pression système que `oomd` surveille. Le cœur pose
donc aussi `MemorySwapMax=0` (v0.157.0) : le swap est refusé à l'enfant, qui est
tué net. Rien à faire côté app, mais c'est bon à savoir si vous voyez un run
« bloqué » plutôt que tué sur une autre machine.
