# NOTE `nemetonshiny` — nemeton 1.2.0 : chemin ONF unique, plancher à relever

> **Statut** : information, 2026-10-08. Elle complète
> `2026-10-08-onf-nouveau-chemin-seul.md`, émis par `nemetonclaude`, qui reste la
> référence côté app.
> **Émetteur** : session `nemeton`. Spec : `nemeton/specs/058-ugf-depuis-onf/` § 7.
> **Plancher** : `nemeton (>= 1.2.0)`.

## Ce qui change dans le cœur

1. **`croiser_parcelles_onf()` est dépréciée.** Elle fonctionne toujours jusqu'à
   la 2.0, mais avertit une fois par session (classe `deprecatedWarning`). L'app
   ne doit plus l'appeler. Le remplacement est
   `construire_ugf_onf(selection = "toutes")`.
2. **`construire_ugf_onf()` traite plusieurs communes.** Ton brief prévoit
   « appel du cœur une fois par commune du projet » (§ 3.2 et § 6). Ce n'est
   **plus nécessaire** : il suffit d'**un seul appel** pour tout le projet. Les
   limites intercommunales sont ainsi traitées des deux côtés, ce que des appels
   séparés ne font pas.
   - `insee` est facultatif quand `cadastre` est fourni. Il se déduit de
     `cadastre$code_insee`, ou des cinq premiers caractères de `idu`.
   - Un `cadastre` fourni est pris **tel quel**, sans filtre sur `insee`.
3. **Parcelles « hors ONF ».** En mode `"foret"`, une parcelle du projet qui ne
   touche pas l'ONF figure dans `attr(x, "parcelles")` avec :
   - `retenue = FALSE` ;
   - `raison = "hors ONF"` ;
   - `couverture_onf = 0` ;
   - son propriétaire DGFiP.

   Ton brief (§ 3.2) prévoyait que l'app les ajoute elle-même : c'est inutile,
   elles y sont.

## Appel recommandé (bouton « Croiser avec l'ONF » et import CSV)

```r
x <- nemeton::construire_ugf_onf(
  parcelles_onf = onf,                 # load_onf_parcelles_source()
  cadastre      = parcelles_projet,    # colonne idu (+ code_insee si dispo)
  selection     = if (purge) "foret" else "toutes",
  seuil_couverture = p$seuil_couverture, tol = p$tol,
  larg_hors = p$larg_hors, seuil = p$seuil, seuil_hors = p$seuil_hors)
ecartees <- subset(attr(x, "parcelles"), !retenue)   # raison : "hors ONF", "privee", "couverture < 50 %"
```

## Valeurs de raison

| `raison` | Sens |
|---|---|
| `NA` | Parcelle retenue. |
| `"hors ONF"` | La parcelle ne touche pas le parcellaire ONF. |
| `"privee"` | Absente du fichier DGFiP des personnes morales, ou personne morale non publique. |
| `"couverture < 50 %"` | Publique, mais trop peu couverte par l'ONF calée. Le seuil suit `seuil_couverture`. |

Couchey, projet de 23 parcelles, mode `"foret"` : 17 retenues, 4
`couverture < 50 %`, 2 `hors ONF`. Mode `"toutes"` : 67 UGF, dont 4 `cad~`.
