# NOTE `nemetonshiny` — API cœur livrée pour les UGF depuis l'ONF (nemeton 1.1.0)

> **Statut** : information, 2026-10-08. Complète le brief
> `2026-10-08-ugf-depuis-onf.md` (émis par `nemetonclaude`), qui reste la
> référence pour le travail côté app.
> **Émetteur** : session `nemeton`. Spec cœur : `nemeton/specs/058-ugf-depuis-onf/`.
> **Plancher** : `nemeton (>= 1.1.0)`. Les trois fonctions sont **experimental**
> (elles peuvent changer en version mineure).

## Fonctions

```r
nemeton::construire_ugf_onf(
  aoi = NULL, insee, parcelles_onf = NULL, cadastre = NULL,
  proprietaires = NULL,
  pas = 5, dmax = 80, rayon = 200, k = 12,
  seuil_couverture = 0.5, tol = 15, larg_hors = 50, ha_hors = 0.5,
  seuil = 0.5, seuil_hors = 1, min_part_m2 = 500, crs = 2154,
  selection = c("foret", "toutes"))

nemeton::caler_onf_sur_cadastre(onf, cadastre, pas = 5, dmax = 80,
                                rayon = 200, k = 12, simplification = 1)

nemeton::load_parcelles_personnes_morales(insee, fichier = NULL, cache_dir = NULL)

nemeton::croiser_parcelles_onf(..., calage_elastique = FALSE)   # nouvel argument
```

## Correspondance avec le brief app

| Brief app | Cœur |
|---|---|
| § 3.A « Créer un projet depuis la forêt ONF » | `construire_ugf_onf(aoi, insee)` (défaut `selection = "foret"`). Il récupère lui-même l'ONF, le PCI et la DGFiP. |
| § 3.B « Croiser avec l'ONF » sur un projet existant | `construire_ugf_onf(insee = , parcelles_onf = , cadastre = <parcelles du projet, colonne idu>, selection = "toutes")`. Il applique la même chaîne (calage élastique, accrochage, rattachements, `cad~` si la partie hors ONF fait ≥ 50 m de large et ≥ 1 ha) sans refaire la sélection ni lire la DGFiP. Couchey, 23 parcelles : 67 UGF, dont 4 `cad~` (A 283, A 9, A 286, AO 212). |
| Calage élastique seul dans le croisement actuel | `croiser_parcelles_onf(..., calage_elastique = TRUE)`. Il ne fait que le calage, sans accrochage ni rattachements : pour le chemin B, préférer `selection = "toutes"`. |
| « Réglages avancés » | `tol` (15 m), `seuil` (0,5 ha), `seuil_hors` (1 ha), `seuil_couverture` (0,5) |

## Sortie de `construire_ugf_onf()`

Un `sf` de tènements, une ligne par (parcelle cadastrale × UGF) :

| Colonne | Vers la colonne app (§ 2) |
|---|---|
| `idu` | `parent_parcelle_id` |
| `tenement_id` | `<ugf_id>~<idu>` |
| `ugf_id` | `<forêt>-<parcelle>` ou `cad~<idu>` |
| `nom_ugf` | `label_ugf` (pour `cad~`, l'IDU) |
| `foret_id`, `foret_nom`, `parcelle`, `domaniale` | `onf_foret_id`, `onf_foret_nom`, `onf_parcelle`, `onf_domaniale` (`NA` pour `cad~`) |
| `surface_m2` | — |
| `part_onf` | `onf_part`. C'est une part **par tènement**. Pour l'UGF, prendre la moyenne pondérée par `surface_m2`. `NA` pour `cad~`. |

Attributs :
- `attr(x, "parcelles")` : toutes les candidates, avec `idu`, `retenue`,
  `raison` (`NA`, `"privee"` ou `"couverture < 50 %"`), `publique`,
  `proprietaire`, `groupe`, `natures`, `couverture_onf` et `surface_ha`. Elle
  sert à la liste des parcelles écartées (§ 3.A).
- `attr(x, "calage")` : `n_controle`, `ecart_median_m`, `ecart_p90_m`.

Le résultat est `NULL`, avec un avertissement, si une source est injoignable. Il
est vide (0 ligne) quand aucune parcelle n'est retenue.

## Garanties

- **Pavage exact** de chaque parcelle retenue : écart < 10⁻⁵ m². Les sommets du
  cadastre sont ceux d'entrée, au millimètre près : `validate_tiling()` passe.
- **Sans chevauchement** et sans éclat sous 1 m².
- **Couchey** (21200), sources chargées : environ 15 s. Le premier appel
  télécharge en plus le fichier DGFiP national (376 Mo, une fois, dans
  `tools::R_user_dir("nemeton", "cache")`). À lancer hors de la session Shiny,
  comme les autres calculs longs.
