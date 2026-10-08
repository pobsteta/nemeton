# BRIEF `nemeton` — Croisement ONF : retirer l'ancien calage, `construire_ugf_onf()` multi-communes

> **Statut** : ouvert, 2026-10-08.
> **Émetteur** : session `nemetonclaude`, sur décision de Pascal du 2026-10-08 :
> *« je ne veux conserver que cette nouvelle façon de faire »*. La « nouvelle
> façon » est la chaîne de `construire_ugf_onf()` (spec 058, nemeton 1.1.0) ;
> l'ancienne est `croiser_parcelles_onf()` avec `caler_sur_cadastre` /
> `seuil_calage` / `rattacher_reste`.
> **Pendant côté app** : `vers-nemetonshiny/2026-10-08-onf-nouveau-chemin-seul.md`.
> Avec lui, nemetonshiny n'appellera plus `croiser_parcelles_onf()`.
> **Dépôt concerné** : `R/croiser_parcelles_onf.R`, `R/ugf_onf.R`, tests,
> NEWS, specs.

## 1. Retrait de l'ancienne façon

`croiser_parcelles_onf()` est marquée **Stable (contrat d'API 1.0, spec 057)**.
On ne la supprime donc pas sèchement. Il faut appliquer la procédure de
dépréciation du contrat :
1. **Maintenant (1.2.0)** : dépréciation douce de `croiser_parcelles_onf()`
   tout entière. `lifecycle::deprecate_soft()` doit renvoyer à
   `construire_ugf_onf(selection = "toutes")`. La doc doit dire que la
   nouvelle chaîne (calage élastique, accrochage, rattachements) est la seule
   maintenue, et que `caler_sur_cadastre`, `seuil_calage`, `rattacher_reste`
   et `calage_elastique` ne recevront plus d'évolution.
   - Si le contrat 057 permet de déprécier seulement les arguments, c'est une
     variante acceptable. Mais une seule fonction de croisement est préférable.
2. **Retrait effectif** à la prochaine version majeure (2.0), ou plus tôt si la
   spec 057 le permet pour une fonction qui n'a plus aucun appelant connu.
   C'est le cas dès que nemetonshiny aura livré son brief : vérifier par
   `grep` dans nemetonshiny et nemetonclaude.
3. Les helpers internes qui ne servent qu'à l'ancien calage partent avec la
   fonction. Ceux que `construire_ugf_onf()` réutilise restent.

## 2. `construire_ugf_onf()` sur plusieurs communes

Aujourd'hui, `insee` est un scalaire obligatoire et `cadastre` est filtré sur
`code_insee == insee`. Un projet de l'app qui s'étend sur deux communes perd
donc les parcelles de l'autre commune. L'app devra appeler le cœur commune
par commune, ce qui ne recale pas les limites intercommunales sur les deux
côtés.

Attendu :
- `insee` accepte un **vecteur** de codes. Les candidates PCI et la DGFiP
  (`load_parcelles_personnes_morales()`, qui doit alors accepter plusieurs
  communes, voire plusieurs départements) sont lues pour chacun. Le calage, le
  découpage et les rattachements tournent **une seule fois** sur l'ensemble.
- Avec `cadastre` fourni (chemin B de l'app), `insee` devient facultatif. Il
  se déduit de `cadastre$code_insee` ou des 5 premiers caractères de l'`idu`,
  et le filtre sur `code_insee` ne retire plus rien.
- Les `idu` de communes déléguées ou nouvelles restent tels que fournis.
- Test : deux communes jointives, résultat identique à l'union des appels
  séparés là où les limites ne se touchent pas, et pavage exact partout.

## 3. Petits points relevés en lisant `construire_ugf_onf()` (1.1.0)

- En mode `selection = "foret"` avec `cadastre` fourni, une parcelle qui ne
  touche pas l'ONF est retirée **avant** l'attribut `parcelles`. Elle
  n'apparaît donc pas parmi les écartées. L'app va s'en servir pour lister les
  parcelles retirées de la sélection de l'utilisateur. Il faudrait la garder
  dans l'attribut avec `retenue = FALSE`, `raison = "hors ONF"` et
  `couverture_onf = 0`.
- Exposer `tol`, `larg_hors`, `seuil`, `seuil_hors` et `seuil_couverture` est
  suffisant pour l'app. `pas`, `dmax`, `rayon` et `k` restent des arguments
  d'experts que l'app ne montre pas.

## 4. Critères d'acceptation

- [ ] `croiser_parcelles_onf()` dépréciée (message lifecycle, doc, NEWS), ses
      tests passent en `expect_deprecated` / `local_options(lifecycle_verbosity
      = "quiet")`.
- [ ] `construire_ugf_onf(insee = c(a, b))` et `construire_ugf_onf(cadastre =,
      selection = "toutes")` sans `insee` fonctionnent ; Couchey inchangé
      (19 parcelles, 63 UGF ; 67 UGF dont 4 `cad~` en `"toutes"` sur le projet
      de 23 parcelles).
- [ ] Parcelles hors ONF présentes dans `attr(x, "parcelles")` avec leur raison.
- [ ] NEWS, CI verte, version publiée. Prévenir nemetonshiny par une note
      `vers-nemetonshiny/` donnant le nouveau plancher.
