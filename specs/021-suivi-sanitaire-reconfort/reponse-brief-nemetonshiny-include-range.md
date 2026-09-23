# Réponse cœur — RECONFORT : `include_range = TRUE` inerte (brief app du 2026-09-23)

> **En réponse à** : `briefs/traites/2026-09-23-reconfort-include-range-inerte.md`.
> **Livré dans** : `nemeton` **v0.199.0** (2026-09-23).
> **Écart PLAN.md cœur** : n° 13.

## À faire côté app

1. **Plancher** : `Imports: nemeton (>= 0.199.0)`.
2. **Libellé de la couche `probability`** : elle affiche désormais **P(atteinte)**.
   - `reconfort_couche_proba` : « Probabilité d'atteinte » / « Probability of dieback ».
   - `reconfort_couche_proba_info` : l'infobulle dit encore « probabilité /
     confiance de la classification… quantiles ». À remplacer par : « Probabilité
     que le pixel soit dépérissant ou très dépérissant (somme des deux classes),
     0 à 1000 ; plus c'est haut, plus c'est grave. »
   - La légende suit `vmin`/`vmax` du manifeste : aucun calcul à faire côté app.
3. **Rien d'autre à changer dans les appels** : `include_range = TRUE` fonctionne
   maintenant, et les deux avis `terra` ont disparu.

## A. `minmax()` sans `compute = TRUE`

Corrigé : `terra::minmax(r, compute = TRUE)` sur la **bande affichée** (la
première), en ~0,02 s. Repli sur les bornes nominales si le calcul échoue ou si
le raster est entièrement NA. Sur `ltcp` zone 9 : score **24–58**, aucun avis.

## B. La couche de probabilité à 3 bandes

- **Contenu des bandes** : une bande par classe RECONFORT, dans l'ordre de
  `RECONFORT_CLASSES` : 1 = sain, 2 = dépérissant, 3 = très dépérissant (2
  bandes pour le pin).
- **Échelle** : **0–1000** (sortie OTB/Shark). La formule du score
  `(1001 − P1 + P2 + 2·P3)/30` la suppose.
- **Bande retenue** (décision de Pascal) : la couche `probability` est
  **P(atteinte) = bande 2 + bande 3**, sur 0–1000, avec « haut = mauvais »
  comme le score. Le cœur la dérive une fois dans un fichier à une bande,
  `p_atteinte_<source>.tif`, et le `path` du manifeste pointe dessus. Le
  `r[[1L]]` de l'app lit donc directement la bonne couche.

## Le 0–255 était un défaut d'iota2 (#12), pas un codage 8 bits

iota2 écrit `probamap` avec le `pixType` de la classification (`uint8`), si
bien qu'OTB **écrête** les probabilités à 255. Conséquence : le score continu
sort dans 24–58 au lieu de 1–100, et le `stress_index` des alertes aussi. Les
classes et les alertes ne sont **pas** touchées.

- Correctif dans `inst/python/reconfort/repair_iota2_env.sh` (#12), appliqué à
  l'env local.
- `run_reconfort_dieback()` avertit au lancement si l'env n'a pas ce correctif.
- **Les 5 runs existants sont écrêtés** : armn z5 (2025 et 2026), ltcp z9, hwuy
  z49, yuxn z53. Ils sont **à relancer**. Tant qu'un run ne l'est pas,
  `reconfort_cache_manifest()` le signale une fois par session (message
  « probability map clamped at 255 ») ; sa couche P(atteinte) plafonne alors
  à 510.

## Retour attendu

La version de l'app qui consomme v0.199.0. L'écart n° 13 sera refermé côté app
à ce moment-là, et côté données une fois les 5 runs relancés.
