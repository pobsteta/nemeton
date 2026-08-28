# Fiche indicateur A5 - Rafraichissement urbain

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** : calculé seulement si un raster **LST**
> est fourni (spec 032).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `A5` |
| Nom long / colonne | `indicateur_a5_rafraichissement` |
| Famille | **A — Air & Microclimat** |
| Grandeur mesurée | Écart de **température de surface** entre l’unité et sa couronne |
| Unité brute | **score 0–100, centré sur 50** |
| Sens | Haut = favorable (l’unité rafraîchit son voisinage) |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_a5_rafraichissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_a5_rafraichissement.md) — `R/indicators-air.R:572` |
| Colonnes annexes | `A5_delta` (K), `a5_status` |
| Applicabilité | [`a5_applicabilite()`](https://pobsteta.github.io/nemeton/reference/a5_applicabilite.md) — `R/indicators-air.R:452` |

## 2. Le calcul

    LST_unite   = moyenne de la LST dans l'unite
    LST_ref     = mediane de la LST dans la couronne buffer(unite, 500 m) \ unite
                  ou valeur fixe si `reference` est fourni
    delta       = LST_ref - LST_unite                     K, positif = l'unite est plus fraiche
    A5          = 50 + (delta / 5) x 50                   ecrete [0, 100]

Les valeurs `-32768` (nodata LST) et non finies sont écartées ;
l’échelle d’entrée (K ou °C) est indifférente puisque seul l’écart
compte.

**Exemples chiffrés** :

| Situation                                    | Δ (K) | A5       |
|----------------------------------------------|-------|----------|
| Boisement urbain, îlot de fraîcheur marqué   | +4,0  | **90,0** |
| Rafraîchissement modéré                      | +1,5  | **65,0** |
| Aussi chaud que son voisinage                | 0,0   | **50,0** |
| Plus chaud que son voisinage (coupe, sol nu) | −2,0  | **30,0** |

> **50 n’est pas « moyen », c’est « neutre ».** L’échelle est
> **centrée** : 50 signifie exactement « cette unité a la même
> température de surface que sa couronne ». C’est le seul indicateur des
> 41 où la moitié de l’échelle a ce sens — ailleurs, 50 veut dire « à
> mi-chemin du plafond ». Un radar où A5 sort à 50 ne dit pas «
> performance moyenne » mais « aucun effet mesuré ».

## 3. Le calcul par niveau NDP

| NDP | Ce qui existe | A5 |
|----|----|----|
| **0** sans LST | rien | **`NA`**, `a5_status = "skipped_no_lst"` |
| **0** + LST Theia (`theia_lst`, lignée Thermocity) | satellite thermique | **calculé** |
| **1–2** | LST aéroportée ou drone thermique | même grandeur, résolution supérieure |
| **3–4** | \+ mesures in situ | validation |

[`a5_applicabilite()`](https://pobsteta.github.io/nemeton/reference/a5_applicabilite.md)
répond, avant calcul, si l’indicateur a un sens sur l’emprise : la LST
thermique n’est pertinente qu’en contexte urbain ou périurbain, et le
produit ne couvre pas tout le territoire.

## 4. Trois pièges

1.  **La couronne de référence n’est pas neutre.** La médiane de la LST
    dans un anneau de 500 m dépend de ce qu’il y a autour : une parcelle
    entourée d’autres forêts aura une couronne fraîche, donc un Δ
    faible, donc un A5 proche de 50 — alors qu’elle rafraîchit
    réellement. **A5 mesure un contraste local, pas une capacité de
    rafraîchissement absolue.** En plein massif, il ne veut presque rien
    dire ; c’est un indicateur périurbain, comme son nom l’indique.
2.  **La date et l’heure de l’acquisition thermique dominent le
    résultat.** Une LST de nuit et une LST de milieu d’après-midi en
    août donnent des contrastes opposés en amplitude. Le raster porte
    cette information, la colonne non.
3.  **`NA` est le cas nominal hors contexte urbain**, avec `a5_status`
    renseigné. Vérifier `a5_status` avant de conclure à un défaut de
    calcul.

## 5. Aval

    indicateur_a5_rafraichissement()  ->  colonnes A5, A5_delta, a5_status
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("A")  -> famille_air = moy(A1..A5, na.rm = TRUE)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBBNSA6IGxhIHRlbXBlcmF0dXJlIGRlIHN1cmZhY2UgZGUgbCYjMzk7dW5pdGUgZXN0IGNvbXBhcmVlIGEgbGEgbWVkaWFuZSBkJiMzOTt1bmUgY291cm9ubmUgZGUgNTAwIG0sIGV0IGwmIzM5O2VjYXJ0IGVzdCBwb3J0ZSBzdXIgdW5lIGVjaGVsbGUgY2VudHJlZSBvdSA1MCBzaWduaWZpZSDCqyBhdWN1biBlZmZldCBtZXN1cmUgwrsgZXQgbm9uIMKrIG1veWVuIMK7IDsgaG9ycyBjb250ZXh0ZSB1cmJhaW4sIEE1IHZhdXQgTkEuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgw4lUQVBFUwpTVUNDRVNTSVZFUzwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlJhc3RlcgpMU1QgKHRoZXJtaXF1ZSk8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bm9kYXRhCi0zMjc2OCDDqWNhcnTDqTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5LCm91IMKwQyBpbmRpZmbDqXJlbnQ8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTA2IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNvdXJvbm5lCmRlIHLDqWbDqXJlbmNlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxNDEiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5idWZmZXIodW5pdMOpLAo1MDAgbSkgwqB1bml0w6k8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE1NyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm91CnZhbGV1ciBmaXhlIHNpIHJlZmVyZW5jZTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxNzgiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIxOTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Ib3JzCmNvbnRleHRlIHVyYmFpbjwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+QTUKPSBOQSwgY29sb25uZSBhNV9zdGF0dXM8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5EZXV4CnN0YXRpc3RpcXVlcyB6b25hbGVzPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+TFNUX3VuaXRlCj0gbW95ZW5uZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkxTVF9yZWYKPSBtw6lkaWFuZSBjb3Vyb25uZTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjEyNiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI3NCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+w4ljYXJ0LApwdWlzIMOpY2hlbGxlIGNlbnRyw6llPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmRlbHRhCj0gTFNUX3JlZiAtIExTVF91bml0ZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5BNQo9IDUwICsgKGRlbHRhLzUpIMOXIDUwPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTkzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOpY3LDqnTDqQpzdXIgWzAsIDEwMF08L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl9hNV9yYWZyYWljaGlzc2VtZW50PC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2NvcmUKY2VudHLDqSBzdXIgNTA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOpY3LDqnRhZ2UKbmF0aWYgMOKAkzEwMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE2MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxB4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX2FpcjwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIEExIMOgIEE1PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxsaW5lIHgxPSIyNjAiIHkxPSI2MyIgeDI9IjI4MiIgeTI9IjYzIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48cGF0aCBkPSJNMjYwIDEzNSBIMjcxIFYxNjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTk5IEgyNzEgVjE2MyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijk0IiB4Mj0iMzA2IiB5Mj0iMTIwIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjExMCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+cHVpczwvdGV4dD48bGluZSB4MT0iNTUwIiB5MT0iNjMiIHgyPSI1NjYiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMTYzIiB4Mj0iNTY2IiB5Mj0iMTYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjE2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTQyIiB4Mj0iNjk5IiB5Mj0iMTU2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjIyIiB4Mj0iNjk5IiB5Mj0iMjM2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzEwIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj41MAo9IG5ldXRyZSwgcGFzIG1veWVuIDogbOKAmXVuaXTDqSBhIGxhIG3Dqm1lIHRlbXDDqXJhdHVyZSBkZSBzdXJmYWNlIHF1ZSBzYQpjb3Vyb25uZS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGEKY291cm9ubmUgbuKAmWVzdCBwYXMgbmV1dHJlIOKAlCBjZSBxdeKAmWVsbGUgY29udGllbnQgKHZpbGxlLCBjdWx0dXJlLCBmb3LDqnQpCmZpeGUgbGEgcsOpZsOpcmVuY2UuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxhCmRhdGUgZXQgbOKAmWhldXJlIGRlIGzigJlhY3F1aXNpdGlvbiB0aGVybWlxdWUgZG9taW5lbnQgbGUgcsOpc3VsdGF0IDsgZWxsZXMKbmUgc29udCBwYXMgZGFucyBsYSBjb2xvbm5lLjwvdGV4dD48L3N2Zz4=)

Le seul indicateur des 41 dont l’échelle est centrée. Un A5 à 50 sur le
radar ne dit pas « performance moyenne » mais « aucun effet mesuré » —
et l’écart se lit toujours contre une couronne, jamais dans l’absolu.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction A5 | `R/indicators-air.R:572-650` |
| Applicabilité | [`a5_applicabilite()`](https://pobsteta.github.io/nemeton/reference/a5_applicabilite.md) — `R/indicators-air.R:452` |
| Source LST | `inst/datasources/FR.json` — `theia_lst` |
| Spécification | `specs/032-regulation-thermique-albedo-lst/` |
