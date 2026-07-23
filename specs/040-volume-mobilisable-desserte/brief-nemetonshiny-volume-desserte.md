# Brief `nemetonshiny` — câbler `volume_mobilisable()` dans le typage de desserte

> **Destinataire** : session dédiée `/home/pascal/dev/nemetonshiny`.
> **Émetteur** : session `nemeton` (règle #11 : je ne touche pas à l'app).
> **Origine** : spec 040 (cœur), close côté `nemeton` en v0.163.0 → v0.165.0.
> **But** : consommer côté app le pont **P1 → volume mobilisé** que le cœur
> expose, pour alimenter le **typage du réseau** de desserte (`foretaccess`).

## 1. Ce qui est prêt, des deux côtés

- **Cœur `nemeton`** (v0.165.0) : `volume_mobilisable()`, `completer_volume_ifn()`,
  `resoudre_espar()`, `ifn_taux_prelevement()`. Voir §3-§7.
- **`foretaccess`** (v1.16.0) : les moteurs de desserte sont **débloqués** (perf
  glouton 1.12, connexité 1.11, `places_depot` ~40× 1.11). Le pipeline de typage
  existe : `vectoriser_reseau()` → `calculer_flux(graphe, parcelles, volume_champ)`
  → `typer_desserte(graphe, seuils_flux)`.

Le maillon manquant est **entre les deux** : produire la colonne de volume que
`calculer_flux()` attend, ce que fait `volume_mobilisable()`. C'est le typage en
6ᵉ position du plan de dev app.

## 2. Le chaînage exact

```
parcelles (sf, P1 déjà calculé par nemeton::indicateur_p1_volume)
      │
      ▼  nemeton::volume_mobilisable(unite = "m3_total", …)   ← ce brief
parcelles + colonne "volume_mobilisable" (m³ TOTAL par parcelle)
      │
      ▼  foretaccess::calculer_flux(graphe, parcelles,
      │                             volume_champ = "volume_mobilisable")
graphe + flux accumulé
      │
      ▼  foretaccess::typer_desserte(graphe, seuils_flux)
réseau typé (piste / route / … par classe de flux)
```

Aucune logique métier côté app (règles 1-3) : l'app orchestre deux appels de
package.

## 3. Le piège central — la bonne `unite` pour le bon consommateur

`volume_mobilisable(unite = …)` a **deux valeurs**, et se tromper donne un
résultat faux **sans erreur** :

| Consommateur `foretaccess` | `unite` | Pourquoi |
|---|---|---|
| **`calculer_flux()`** (typage) | **`"m3_total"`** | répartit le volume sur les points sources puis l'accumule → veut un **total m³ par parcelle** |
| `reseau_desserte()` / `optimiser_reseau()` (pondération du glouton) | `"m3_ha"` | rasterise la colonne cellule par cellule → veut une **densité m³/ha** |

**Pour le typage (l'objet de ce brief) : `unite = "m3_total"`.** Un `m3_ha` y
sous-estimerait le flux d'un facteur égal à la surface.

Si tu pondères aussi le glouton par le volume mobilisé, c'est un **second appel**
avec `unite = "m3_ha"` — ne réutilise pas la même colonne pour les deux.

## 4. Le taux de prélèvement — deux voies

`volume = P1 × taux_prelevement × horizon_ans`. Le taux est un **flux annuel**
(m³/ha/an), d'où `horizon_ans` obligatoire.

- **Voie « saisi »** (jalon simple) : `taux_prelevement = <nombre>` fourni par
  l'utilisateur, `horizon_ans = <nombre>`. Aucune table, aucun code essence
  requis.
- **Voie « table IFN »** (`taux_prelevement = NULL`, défaut) : le cœur résout le
  taux par essence via `ifn_taux_prelevement()`, avec cascade
  SER → GRECO → national. Exige alors `espar_field` (§6) et, idéalement, `ser`
  (§5). L'attribut `niveau_prelevement` du résultat dit quel échelon a servi
  (§8).

Recommandation UI : un radio « taux saisi / référentiel IFN », `horizon_ans` en
numérique (défaut sylvicole ~ la révolution, à discuter), et n'exposer la voie
table que si les parcelles portent un code essence.

## 5. La SER — un paramètre de projet, pas de parcelle

La table IFN est keyée par sylvoécorégion. `volume_mobilisable(ser = …)` prend
**un seul code SER** (un projet forestier est local, donc dans une seule SER).

**Le cœur ne résout PAS la SER d'une géométrie** : la couche SER est
*download-only* (spec 040 §5.a, lot 1 non fait — comme la BD Forêts anciennes).
Trois options côté app, par ordre de coût :

1. `ser = NULL` → **taux national** (jalon). Correct, moins précis ; l'attribut
   `niveau_prelevement` vaudra `"national"`, à afficher honnêtement.
2. **Choix manuel** de la SER par l'utilisateur (liste des 86 codes).
3. Résolution spatiale (charger la couche SER IGN, point-in-polygon sur le
   centroïde du projet) — plus lourd, à cadrer plus tard.

Pour un premier câblage : **option 1**, puis 2.

## 6. Le code essence — l'app n'a rien à convertir

`espar_field` accepte **n'importe quelle nomenclature** du projet : code IFN
(`"09"`), code P1 quatre lettres (`"FASY"`), code tolérances
(`"fagus_sylvatica"`) ou nom latin — le cœur les ramène au code IFN via
`resoudre_espar()`. Passe simplement le nom de ta colonne d'essence, quelle
qu'elle soit. Les essences non résolues restent `NA` (jamais devinées) et
déclenchent un avertissement.

## 7. Le cas NDP 0 — P1 est `NA`

En NDP 0 (données publiques seules), `indicateur_p1_volume()` rend souvent `NA`
faute d'inventaire terrain et de CHM. Deux réponses, au choix de l'app :

- **`completer_volume_ifn(units, species_field, ser)`** *avant*
  `volume_mobilisable()` : comble les `NA` de P1 par le volume de référence IFN
  régional, en **écrivant la provenance ligne à ligne** dans `volume_source`
  (`"mesure"` / `"ifn_ser"` / `"ifn_greco"` / `"ifn_national"` / `NA`). À
  afficher — un volume régional ne doit pas passer pour une mesure.
- **`na_policy`** de `volume_mobilisable()` : `"na"` (défaut, propage + avertit),
  `"zero"` (parcelle « rien à sortir » — le signaler), `"error"`.

Recommandation : `completer_volume_ifn()` puis `volume_mobilisable()`, pour un
typage qui n'a pas de trous en NDP 0, avec la provenance visible.

## 8. Ce que l'app doit remonter à l'utilisateur

- Le **niveau de maille** effectivement utilisé : `attr(result, "niveau_prelevement")`
  (`"ser"` / `"greco"` / `"national"` par unité). Badge « taux régional » vs
  « taux national », comme le badge DFCI existant.
- La **provenance du volume** si `completer_volume_ifn()` est utilisé
  (colonne `volume_source`).
- Un **avertissement** si des essences ne se résolvent pas (retour de
  `resoudre_espar()` à `NA`).

## 9. À ne pas confondre — `volume_depuis_p1()` est autre chose

`foretaccess::volume_depuis_p1()` existe déjà (v1.7/1.8) : c'est un pont
**géométrique** qui rasterise un volume **sur pied** sur la grille du MNT, pour
le **moteur câble** (`pre$volume`, IPC). Il **ne fait pas** de prélèvement.
`volume_mobilisable()` est distinct : sur pied → **mobilisé** (avec taux), pour
le **flux de desserte**. Les deux coexistent, usages séparés — ne pas router
l'un vers l'autre.

## 10. Plancher & garde-fous

- `DESCRIPTION` app : relever `Imports: nemeton (>= 0.165.0)` (actuellement
  `>= 0.162.0`). `foretaccess (>= 1.16.0)`.
- Textes UI via `i18n$t()` (règle 4).
- Le typage sur une AOI réelle appelle `calculer_flux` + `measure_road`-libre :
  pas de calcul LiDAR ici, donc pas de worker obligatoire — mais garder
  l'orchestration hors du thread UI par cohérence.

## 11. Exemple minimal (voie saisie, national, NDP 0 comblé)

```r
p <- nemeton::indicateur_p1_volume(parcelles)                 # P1, souvent NA en NDP 0
p <- nemeton::completer_volume_ifn(p, species_field = "essence", ser = NULL)
p <- nemeton::volume_mobilisable(
       p, unite = "m3_total",
       taux_prelevement = input$taux, horizon_ans = input$horizon,
       espar_field = "essence")                               # ser = NULL -> national
g <- foretaccess::vectoriser_reseau(reseau)
g <- foretaccess::calculer_flux(g, p, volume_champ = "volume_mobilisable")
g <- foretaccess::typer_desserte(g, seuils_flux = input$seuils)
```
