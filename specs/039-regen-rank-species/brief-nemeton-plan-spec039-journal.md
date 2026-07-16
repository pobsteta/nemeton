# Brief cœur `nemeton` — Entrée PLAN.md pour spec 039 (reGénération : classement + conseil IA)

**À exécuter dans une session dev dédiée à `/home/pascal/dev/nemeton`.**
Objet : consigner dans `nemeton/PLAN.md` la livraison applicative de la spec 039
(recommandation d'essences pour la reGénération), dont le socle cœur est déjà
publié (`nemeton` v0.162.0 : `regen_rank_species`, `regen_rank_to_wide`, et
normalisation R6 `sensibilite_score` de la spec 038).

## Ce qui a été livré côté app (`nemetonshiny`)

Spec 039, approche hybride (classement déterministe cœur + mise en prose IA) :

- **P1 — top-3 déterministe par UGF** (app v0.107.16, commit `nemetonshiny@38b85d00`) :
  la fiche parcelle de la vue « Carte + Tableau » de reGénération affiche les
  3 essences les plus pertinentes classées par `nemeton::regen_rank_species`
  (score d'adéquation 0-100, facteur limitant, confiance), invasives écartées.
  Wrapper service NA/erreur-safe `regeneration_species_ranking`.

- **P2 — conseil de régénération par IA** (app **v0.107.17**, commit
  `nemetonshiny@ad77876f`, cycle dev `0.107.16.9001` → release `0.107.17`) :
  sidebar droite repliable « Affiner la reGénération avec l'IA ». Le LLM ne
  classe pas — il met en prose le top-3 déterministe + les conditions de station
  par UGF selon le profil expert, avec garde-fou anti-essence-hors-classement.

Plancher app : `Imports: nemeton (>= 0.162.0)`.

## Action attendue dans `nemeton/PLAN.md`

1. **Cocher** la case du sous-chantier spec 039 (recommandation d'essences
   reGénération) — porté par l'app pour la partie UI/IA, par le cœur pour
   `regen_rank_species` + normalisation R6.

2. **Ajouter une entrée datée au journal**, sur le patron des entrées existantes.
   Texte proposé (à adapter au format exact du journal) :

   ```
   - 2026-07-16 — Spec 039 (reGénération, recommandation d'essences) close côté
     application. Cœur : `regen_rank_species` / `regen_rank_to_wide` +
     normalisation R6 `sensibilite_score` (spec 038) publiés en nemeton v0.162.0.
     App : P1 top-3 déterministe par UGF (nemetonshiny v0.107.16) puis P2 conseil
     de régénération par IA — sidebar « Affiner la reGénération avec l'IA »
     (nemetonshiny@38b85d00 puis @ad77876f, releases nemetonshiny v0.107.16 et
     v0.107.17). Plancher app `Imports: nemeton (>= 0.162.0)`.
   ```

3. Ne pas clore le chantier sans que la release app correspondante soit poussée
   — c'est fait : `nemetonshiny` v0.107.17 est taguée et publiée.

## Résidu éventuel (à confirmer côté cœur)

- Pondération continue FORDEAD/RECONFORT dans la validation-sampling (déjà noté
  ailleurs, hors spec 039).
- Recalibrage terrain des bornes d'adéquation de `regen_rank_species` (validation
  de terrain à venir) — à laisser ouvert si non fait.
