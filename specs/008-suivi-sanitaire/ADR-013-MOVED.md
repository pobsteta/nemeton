# ADR-013 — déplacé vers `nemetonplateform/docs/`

L'ADR-013 « Méthode officielle de suivi sanitaire : FORDEAD avec
garde-fous applicatifs » a été porté hors du repo cœur `nemeton`
le **2026-05-25** pour rejoindre les autres ADR de la plateforme
(`ADR-001` à `ADR-012`) dans leur dépôt canonique.

## Nouvel emplacement

- **Repo** : [`pobsteta/nemetonplateform`](https://github.com/pobsteta/nemetonplateform)
- **Fichier** : [`docs/ADR-013_Suivi_sanitaire_FORDEAD.md`](https://github.com/pobsteta/nemetonplateform/blob/main/docs/ADR-013_Suivi_sanitaire_FORDEAD.md)
- **Commit du port** : `18df8cf` (nemetonplateform)
- **Statut** : Accepté

## Couverture

L'ADR couvre toute la trajectoire FORDEAD du projet :

- Décision initiale (2026-04-26, v0.21.0) — FORDEAD comme méthode
  officielle + 5 garde-fous G1-G5 issus du rapport ONF/DSF 2024.
- Amendement A1 (2026-05-16, v0.23.0) — migration fordead 2.x.
- Amendement A2 (2026-05-16, v0.24.0) — refonte signature
  `run_fordead_dieback(con, zone_id, cache_dir)` + phase 0 ingest
  partagé avec FAST.
- Amendement A3 (2026-05-20, v0.42.0 + v0.43.0) — bundle diagnostic
  persistant + `read_fordead_pixel_series()` pour la viz pixel.

## Pourquoi le port

Aligner ADR-013 avec ADR-001 à ADR-012 qui vivent tous dans
`nemetonplateform/docs/`. Le `CLAUDE.md` de `nemeton` référence
historiquement « *ADR documentés dans `platform_nemeton/docs/` (sauf
ADR-013 dont le draft vit dans `specs/008-suivi-sanitaire/`, à porter
vers `platform_nemeton`)* » — point résolu.

Ce stub reste pour préserver les liens entrants vers le chemin
historique et signaler la relocation.
