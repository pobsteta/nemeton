# Réponse au brief `BRIEF-nemeton-oom-sigterm-scope.md` (app → cœur)

**Cœur livré** : `nemeton v0.183.1` (2026-08-23).
**Verdict** : diagnostic accepté, **option 2 retenue** (constater, pas inférer),
et une correction du mécanisme avancé par le brief.

## Ce qui est corrigé

Un dépassement de plafond atteint désormais le message mémoire. Vérifié en réel
sur un dépassement provoqué, pas seulement en test :

```
"rnorm" ran out of memory and was killed (ceiling: 96M).
ℹ Raise it with `memory_max`, `NEMETON_MEMORY_MAX` (accepts "none") or
  `options(nemeton.memory_max=)`, or run on a smaller extent.
ℹ The rest of the session was spared — only the job died.
```

## Pourquoi l'option 1 seule aurait été un piège

Mesures faites ici le 2026-08-23, sur des dépassements provoqués :

| Situation | Vu par `processx` | Su par systemd |
|---|---|---|
| OOM, processus principal victime (**reproduit**) | `-9` | `Result=oom-kill` |
| OOM, autre processus du scope victime (**ton incident**) | `-15` | `Result=oom-kill` |
| `systemctl stop`, kill extérieur | `-15` | `Result=signal` |

Élargir à `-15` aurait donc échangé un faux négatif contre un faux positif —
un `systemctl stop` se serait annoncé « ran out of memory ». Le code de sortie
n'est probant dans **aucun** sens.

**Correction au brief, sans conséquence sur sa conclusion** : le mécanisme
avancé — « `processx` observe le client `systemd-run`, qui reçoit SIGTERM » —
n'est pas ce que j'ai mesuré. `systemd-run --scope` laisse remonter le signal du
processus du scope lui-même (d'où le `-9` reproduit ici). Je **n'ai pas** réussi
à reproduire ton `-15` en local ; ton journal étant formel, je le tiens pour
acquis sans en tenir l'explication pour acquise — raison de plus de ne pas
inférer.

## Le piège que l'implémentation a révélé

`--collect` et l'interrogation sont **exclusifs**. Avec `--collect` — ce que le
code faisait — un scope mort d'OOM répond `Result=success` : l'unité est
ramassée avant la question. **Une unité détruite ne répond pas « je ne sais
pas », elle répond l'inverse de la vérité.** Le cœur renonce donc à `--collect`
quand il nomme l'unité, et reprend le ménage lui-même (zéro unité résiduelle
vérifié après une série d'échecs).

## Ce que ça change pour l'app

**Rien d'obligatoire.** Aucun changement d'API, aucun plancher à relever pour en
bénéficier : le message vient du cœur, `.compute_error_message()` le relaie tel
quel.

Une chose à savoir, en revanche : ta formulation prudente de la **v0.133.1** —
« le plafond en est la cause habituelle » — reste **juste et utile** pour le mode
dégradé (pas de cgroup, pas de `systemctl`), où le cœur produit exactement cette
nuance. Mais sur le chemin nominal, le cœur **affirme** désormais l'OOM quand
systemd l'a constaté. Si `.compute_error_message()` ré-atténue un message qui
dit déjà « ran out of memory », l'utilisateur perdra une certitude durement
acquise : à vérifier de ton côté que la prudence ne s'applique qu'à ce qui est
incertain.

## Reliquat

`.reconfort_run_py()` (chaîne RECONFORT) ne rend qu'un code de sortie et reste
aveugle au même défaut. L'outillage l'attend (`unit =`,
`.capped_scope_result()`) ; hors périmètre de ton brief, à ouvrir si ça mord.
