# Fiche indicateur L3 - Heterogeneite spectrale beta

> **Document de référence** — Néméton (package cœur), 2026-08-27. **Même
> interdit d’usage que B4** (§4) : écart n° 6 du `PLAN.md`.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `L3` |
| Nom long / colonne | `indicateur_l3_het_spectrale` |
| Famille | **L — Paysage** |
| Grandeur mesurée | Diversité spectrale **β** : hétérogénéité de la mosaïque paysagère |
| Unité brute | **dispersion multivariée**, sans unité, ≈ \[0 ; 0,5\] |
| Sens | Haut = favorable |
| Normalisation | `score = min(100, dispersion / 0,5 × 100)` |
| Fonction | [`indicateur_l3_het_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_l3_het_spectrale.md) — `R/spectral_diversity.R:367` |
| Plafond | `.L3_MAX_DISPERSION = 0.5` |
| Spécification | spec 028 |

## 2. Le calcul

biodivMapR ne rend **pas** un raster de dissimilarité scalaire : il rend
les **trois premiers axes d’une PCoA** de la dissimilarité de
Bray-Curtis entre fenêtres. La valeur reportée est donc la **dispersion
multivariée** de l’unité dans cet espace d’ordination — la distance
euclidienne moyenne des fenêtres de l’unité à son propre centroïde
(betadisper d’Anderson).

    L3 = distance moyenne des fenetres de l'unite a son centroide, en espace PCoA
         NA si moins de `min_windows` fenetres couvertes (defaut 3)
    score = min(100, L3 / 0,5 x 100)

Une unité spectralement uniforme tend vers 0 ; une unité chevauchant des
communautés spectrales contrastées monte.

> **Correctif 0.190.0 à connaître.** Avant, les trois axes étaient
> **simplement moyennés**, ce qui mesurait la **position** moyenne de
> l’unité dans l’espace d’ordination — une quantité centrée sur zéro par
> construction, et écrasée à 0 pour toutes les unités du côté négatif.
> Les L3 calculés avant cette version sont inexploitables.

**Exemples chiffrés** (jeu de référence : dispersions mesurées de 0,064
à 0,440) :

| Situation                               | Dispersion | Score    |
|-----------------------------------------|------------|----------|
| Unité spectralement uniforme            | 0,07       | **14,0** |
| Mosaïque modérée                        | 0,20       | **40,0** |
| Mosaïque contrastée                     | 0,38       | **76,0** |
| Maximum observé sur le jeu de référence | 0,44       | **88,0** |

## 3. Le calcul par niveau NDP

Identique à B4 : indicateur **NDP 0 par nature** (Sentinel-2),
**inchangé au NDP 1** (le LiDAR ne porte pas de signal spectral),
amélioré au NDP 2 par une ortho drone multispectrale.

## 4. L’interdit d’usage, et deux autres pièges

1.  **L3 ne se compare ni entre projets, ni dans le temps.** Comme B4,
    les « spectral species » sont un **k-means réajusté à chaque
    exécution** (spec 028 §10.6). S’y ajoute une raison propre à L3 : la
    PCoA est une ordination **relative au jeu de fenêtres traité**, donc
    ses axes changent d’un run à l’autre. **Ne jamais classer, moyenner
    ou suivre L3 entre projets.** C’est l’écart n° 6 du `PLAN.md`.
2.  **Le plafond de 0,5 est provisoire et sous-utilisé.** Bray-Curtis
    est nominalement borné par 1, mais une PCoA à 3 axes n’en restitue
    qu’une partie (qualité d’ajustement 0,56/0,62 sur le jeu de
    référence). Les dispersions mesurées plafonnent à 0,44 : **aucune
    unité du jeu de référence n’atteint 100**, et l’échelle est utilisée
    sur sa moitié basse.
3.  **`min_windows = 3` est un plancher mathématique, pas un réglage.**
    Une dispersion autour d’un centroïde n’a pas de sens en dessous de
    trois points ; les valeurs inférieures sont relevées à 3. Les
    petites unités sortent donc `NA`.

## 5. Aval

    indicateur_l3_het_spectrale()  ->  colonne L3 (dispersion)
          |
          +- normalize_indicator()     -> dispersion / 0,5 x 100
          +- create_family_index("L")  -> famille_paysage = moy(L1, L2, L3)

> L3 pesant un tiers de `famille_paysage`, l’interdit de comparaison
> **remonte à la famille**, exactement comme B4 pour
> `famille_biodiversite`.

L3 partage son objet `spectral` avec **B4** : appeler
[`compute_spectral_diversity()`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
une fois et le passer aux deux.

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBMMyA6IGxlcyB0cm9pcyBwcmVtaWVycyBheGVzIGQmIzM5O3VuZSBQQ29BIGRlIEJyYXktQ3VydGlzIGVudHJlIGZlbmV0cmVzIHNwZWN0cmFsZXMgc2VydmVudCBkJiMzOTtlc3BhY2UgZCYjMzk7b3JkaW5hdGlvbiwgZXQgTDMgZXN0IGxhIGRpc3RhbmNlIG1veWVubmUgZGVzIGZlbmV0cmVzIGRlIGwmIzM5O3VuaXRlIGEgc29uIHByb3ByZSBjZW50cm9pZGUsIG5vcm1hbGlzZWUgcGFyIHVuIHBsYWZvbmQgcHJvdmlzb2lyZSBkZSAwLDUgOyBtb2lucyBkZSB0cm9pcyBmZW5ldHJlcyBjb3V2ZXJ0ZXMgcmVuZGVudCBOQS4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCDDiVRBUEVTClNVQ0NFU1NJVkVTPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+U2VudGluZWwtMgrigJQgb2JqZXQgc3BlY3RyYWw8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y29tcHV0ZV9zcGVjdHJhbF9kaXZlcnNpdHkoKTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5wYXJ0YWfDqQphdmVjIEI0IChkaXZlcnNpdMOpIM6xKTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxMDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Nb2lucwpkZSBtaW5fd2luZG93cyBmZW7DqnRyZXM8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE0MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkwzCj0gTkEgKGTDqWZhdXQgOiAzKTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlBDb0EKZGUgQnJheS1DdXJ0aXM8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij4zCmF4ZXMgZOKAmW9yZGluYXRpb248L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5iaW9kaXZNYXBSPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTI2IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5EaXNwZXJzaW9uCm11bHRpdmFyacOpZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5kaXN0YW5jZQptb3llbm5lIGF1IGNlbnRyb8OvZGU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YmV0YWRpc3BlcgooQW5kZXJzb24pPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfbDNfaGV0X3NwZWN0cmFsZTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmRpc3BlcnNpb24sCnNhbnMgdW5pdMOpPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5taW4oMTAwLApkaXNwIC8gMCw1IMOXIDEwMCk8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcTOKAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9wYXlzYWdlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgTDEgw6AgTDM8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNDIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI2MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PGxpbmUgeDE9IjI2MCIgeTE9IjYzIiB4Mj0iMjgyIiB5Mj0iNjMiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxwYXRoIGQ9Ik0yNjAgMTI3IEgyNzEgVjE1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijk0IiB4Mj0iMzA2IiB5Mj0iMTIwIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjExMCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+cHVpczwvdGV4dD48bGluZSB4MT0iNTUwIiB5MT0iNjMiIHgyPSI1NjYiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMTU1IiB4Mj0iNTY2IiB5Mj0iMTU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjE1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTQyIiB4Mj0iNjk5IiB5Mj0iMTU2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjIyIiB4Mj0iNjk5IiB5Mj0iMjM2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzEwIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5Db3JyZWN0aWYKMC4xOTAuMCA6IGF2YW50LCBsZXMgMyBheGVzIMOpdGFpZW50IG1veWVubsOpcyDigJQgb24gbWVzdXJhaXQgdW5lIHBvc2l0aW9uLApwYXMgdW5lIGRpc3BlcnNpb24uPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlcwpMMyBjYWxjdWzDqXMgYXZhbnQgY2V0dGUgdmVyc2lvbiBzb250IGluZXhwbG9pdGFibGVzLCBwYXMgc2V1bGVtZW50CmltcHLDqWNpcy48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjM0MiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+UGxhZm9uZAowLDUgcHJvdmlzb2lyZSBldCBzb3VzLXV0aWxpc8OpIDogbGUgbWF4aW11bSBvYnNlcnbDqSBzdXIgbGUgamV1IGRlCnLDqWbDqXJlbmNlIGVzdCAwLDQ0LjwvdGV4dD48L3N2Zz4=)

Une dispersion, pas une position. C’est exactement ce que le correctif
0.190.0 a rétabli : la distance des fenêtres à leur centroïde mesure
l’hétérogénéité ; leur moyenne, elle, ne mesurait rien.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction L3 | `R/spectral_diversity.R:367` |
| Plafond | `.L3_MAX_DISPERSION` — `R/spectral_diversity.R:~28` |
| Indicateur jumeau (α) | [`vignette("fiche-b4-diversite-spectrale_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-b4-diversite-spectrale_fr.md) |
| Spécification | `specs/028-diversite-spectrale/`, §10 |
| Écart ouvert vers l’app | `PLAN.md`, table des écarts, ligne 6 |
