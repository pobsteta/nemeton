# ADR-014 — Sans objet (note)

> **Ce brouillon d'ADR est ANNULÉ.** Il proposait d'isoler les moteurs GPL de
> reGénération (`microclimf`, `biljouR`, `lidR`, `lasR`) dans un 5ᵉ repo
> `regen_nemeton` **pour protéger un cœur `nemeton` supposé MIT**.
>
> **Or `nemeton` est déjà GPL-3** (fichier `LICENSE` = GNU GPL v3.0,
> `DESCRIPTION` `License: GPL-3`). Il n'y a **aucun conflit de licence** avec
> ces moteurs GPL-3 : ils peuvent vivre **directement dans `nemeton`**. Le
> problème que cet ADR résolvait **n'existe pas**.

**Date** : 2026-07-02
**Statut** : **Annulé / sans objet.** Pas d'ADR nécessaire.

## Ce qui reste vrai

- reGénération met en jeu des moteurs GPL-3 (`microclimf`, `biljouR`, `lidR`,
  `lasR`) — **admis au cœur `nemeton` (GPL-3)**.
- Ces dépendances restent en **`Suggests`** (hygiène d'installation, pas
  licence) : lourdes / hors CRAN, chargées via `requireNamespace`, dégradation
  propre, cœur testable sans elles. Cf. spec 027 v2.1 §2.

## Correctif de documentation associé

La table ADR-006 de `CLAUDE.md` indiquait « MIT (packages R) », ce qui est
**faux** pour `nemeton`/`nemetonshiny` (GPL-3). Corrigé dans le même lot. La
source de vérité d'une licence reste le fichier `LICENSE` du repo (CLAUDE.md le
rappelle déjà). L'ADR-006 réel (dans `platform_nemeton/docs/`) est à réconcilier
par Pascal avec la réalité GPL-3.
