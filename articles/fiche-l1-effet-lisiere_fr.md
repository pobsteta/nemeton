# Fiche indicateur L1 - Effet de lisiere

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> **Cette fiche documente une incohérence de sens active** (§4, piège
> n° 1) : le calcul, l’infobulle et N3 lisent L1 « haut = beaucoup de
> lisière = défavorable », la normalisation le lit « haut = favorable ».

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `L1` |
| Nom long / colonne | `indicateur_l1_effet_lisiere` |
| Famille | **L — Paysage** (avec L2, L3) |
| Grandeur mesurée | Intensité de l’effet de lisière subi par l’unité |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_l1_effet_lisiere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_effet_lisiere.md) — `R/indicators-families.R:1682` |
| Ancien nom | [`indicateur_l1_sylvosphere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_sylvosphere.md) — conservé en alias (spec 045) |

## 2. Le calcul — trois composantes pondérées

    L1 = 0,30 x geometrie + 0,40 x contraste_matrice + 0,30 x exposition

### Géométrie (30 %)

    SI = perimetre / (2 x racine(pi x aire))     indice de forme, 1 = disque parfait
    composante = min(100, (SI - 1) x 25)

Une parcelle compacte a un SI proche de 1 et une composante proche de 0
; une lanière étroite monte vite.

### Contraste de matrice (40 %)

Table de contraste OSO, appliquée aux pixels voisins :

| Occupation            | Contraste |
|-----------------------|-----------|
| Forêt (16, 17, 18)    | 0         |
| Landes (19)           | 15        |
| Prairies (20)         | 20        |
| Eau (30)              | 30        |
| Vignes (24)           | 45        |
| Cultures (21, 22, 23) | 50        |
| Routes (29)           | 75        |
| Bâti (25–28)          | 90        |

**Sans couche d’occupation du sol, cette composante vaut 50** pour
toutes les unités — soit 40 % du score figé sur une constante (cf. §4).

### Exposition (30 %)

`0,6 × score_vent + 0,4 × score_ensoleillement`, calculés sur le relief.
Repli à **50** en l’absence des entrées nécessaires.

## 3. Le calcul par niveau NDP

| NDP   | Ce qui change                                                     |
|-------|-------------------------------------------------------------------|
| **0** | OSO 30 m + MNT 25 m — les trois composantes sont calculables      |
| **1** | MNT LiDAR HD : l’exposition (vent, soleil) gagne en finesse       |
| **2** | ortho drone : le contraste de matrice devient réel, haie par haie |
| **3** | relevé terrain de la lisière                                      |
| **4** | —                                                                 |

## 4. Quatre pièges, dont une incohérence de sens

1.  **Le sens de L1 n’est pas le même selon qui le lit.**

    Le **calcul** produit un score qui monte avec l’influence des
    lisières : la composante géométrie vaut `(SI − 1) × 25`, donc 0 pour
    une parcelle compacte et beaucoup pour une lanière ; la composante
    contraste vaut 0 face à de la forêt et 90 face à du bâti. **Un L1
    élevé signifie donc : forme découpée, matrice contrastée, forte
    exposition** — c’est-à-dire un habitat intérieur fragmenté.

    L’**infobulle** dit la même chose : « Proportion de la parcelle sous
    influence des lisières (sylvosphère). Les lisières favorisent
    certaines espèces mais **fragmentent l’habitat intérieur**. »

    **N3** aussi : il calcule `anti_frag = 100 − L1` avant de l’ajouter
    positivement à la naturalité.

    Mais `indicateur_l1_effet_lisiere` figure dans
    `.NORMALIZE_NATIVE_0_100` (`R/normalization.R:521`), et aucune
    branche d’inversion ne le rattrape. La normalisation le laisse donc
    **passer tel quel, comme un score où haut = bon**.

    > **Conséquence** : une parcelle en lanière bordée de bâti obtient
    > un L1 élevé, que le **radar affiche comme un bon score de
    > paysage** et qui tire `famille_paysage` vers le haut — alors que
    > le même chiffre, injecté dans N3, la pénalise. Trois sources sur
    > quatre disent « haut = mauvais », la quatrième décide de
    > l’affichage.

    C’est exactement le défaut corrigé pour **R5** en 0.181.0 (spec 048
    : « seul R5 était inversé \[…\] une UGF très exposée obtenait un
    `famille_risque` élevé, c’est-à-dire flatteur ») et pour les
    **noms** de la famille L en 0.176.0 (spec 045 : « les deux noms
    historiques annonçaient l’inverse de ce qu’ils calculaient »). Le
    sens de L1, lui, n’a pas été revu.

    **Le correctif serait d’un mot** : retirer
    `indicateur_l1_effet_lisiere` (et son alias
    `indicateur_l1_sylvosphere`) de `.NORMALIZE_NATIVE_0_100`, et
    l’ajouter au bloc d’inversion aux côtés de R1–R5 et T3. Comme pour
    la spec 048, aucune fonction d’indicateur ne changerait — seule la
    valeur normalisée basculerait, et tout `famille_paysage` déjà
    calculé serait à refaire.

2.  **Deux composantes sur trois retombent sur 50 en l’absence de
    données**, sans avertissement — le contraste (40 %) et l’exposition
    (30 %). Sans occupation du sol ni relief exploitable, **70 % de L1
    est une constante** et le score se réduit à `35 + 0,3 × géométrie`.
    C’est le même motif que B3 : un score d’apparence mesurée dont la
    majeure partie est fabriquée. Vérifier qu’une couche `landcover` est
    bien chargée avant de lire L1.

3.  **La géométrie mesure la forme de l’UGF, pas celle du massif.** Un
    découpage cadastral en lanières produit des SI élevés sans qu’aucune
    lisière écologique n’existe : deux parcelles voisines au cœur d’un
    même massif continu peuvent obtenir des scores très différents pour
    une raison purement administrative.

4.  **Le nom a changé, l’ancien reste accepté.**
    [`indicateur_l1_sylvosphere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_sylvosphere.md)
    est conservé comme alias (spec 045) et les slugs
    `indicateur_l1_sylvosphere` restent reconnus par la normalisation
    pour les jeux non migrés. Les deux noms historiques de la famille L
    « annonçaient l’inverse de ce qu’ils calculaient » — d’où le
    renommage.

## 5. Aval

    indicateur_l1_effet_lisiere()  ->  colonne indicateur_l1_effet_lisiere
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("L")  -> famille_paysage = moy(L1, L2, L3)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBMMSA6IHRyb2lzIGNvbXBvc2FudGVzIHBvbmRlcmVlcyDigJQgZm9ybWUgZGUgbCYjMzk7dW5pdGUsIGNvbnRyYXN0ZSBkZSBsYSBtYXRyaWNlIHZvaXNpbmUsIGV4cG9zaXRpb24gYXUgdmVudCBldCBhdSBzb2xlaWwg4oCUIGRvbnQgZGV1eCByZXRvbWJlbnQgc2lsZW5jaWV1c2VtZW50IHN1ciA1MCBxdWFuZCBsZXVycyBlbnRyZWVzIG1hbnF1ZW50LCBzb2l0IDcwICUgZHUgc2NvcmUgZmlnZSBzdXIgdW5lIGNvbnN0YW50ZS4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCBURVJNRVMKQ1VNVUzDiVM8L3RleHQ+PHRleHQgeD0iNTg4IiB5PSIxNiI+QVZBTDwvdGV4dD48L2c+PHJlY3QgeD0iOCIgeT0iMzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Hw6lvbcOpdHJpZQpkZSBs4oCZdW5pdMOpPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnDDqXJpbcOodHJlCmV0IGFpcmU8L3RleHQ+PHJlY3QgeD0iOCIgeT0iOTAiIHdpZHRoPSIyNTIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTA5IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+T2NjdXBhdGlvbgpkdSBzb2wgKE9TTyk8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnRhYmxlCmRlIGNvbnRyYXN0ZSA6IGZvcsOqdCAwLDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTQxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y3VsdHVyZXMKNTAsIHJvdXRlcyA3NSwgYsOidGkgOTA8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTYyIiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlJlbGllZgrigJQgdmVudCwgZW5zb2xlaWxsZW1lbnQ8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNpbm9uCnJlcGxpIMOgIDUwPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMzQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+R8Opb23DqXRyaWUK4oCUIDMwICU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5TSQo9IFAgLyAoMuKImijPgMK3QSkpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bWluKDEwMCwKKFNJIC0gMSkgw5cgMjUpPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTI2IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Db250cmFzdGUKbWF0cmljZSDigJQgNDAgJTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jb250cmFzdGUKZGVzIHBpeGVscyB2b2lzaW5zPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNhbnMKY291Y2hlIE9TTyA6IDUwPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMjE4IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIyMzciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5FeHBvc2l0aW9uCuKAlCAzMCAlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjUzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPjAsNgrDlyB2ZW50ICsgMCw0IMOXIHNvbGVpbDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zYW5zCnJlbGllZiA6IDUwPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfbDFfZWZmZXRfbGlzaWVyZTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNjb3JlCjDigJMxMDAsIG5hdGlmPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij7DqWNyw6p0YWdlCm5hdGlmIDDigJMxMDA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcTOKAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9wYXlzYWdlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgTDEgw6AgTDM8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNDIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI2MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PHBhdGggZD0iTTI2MCA1NSBIMjcxIFY2MyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxMTkgSDI3MSBWMTU1IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDE4MyBIMjcxIFYyNDcgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI5NCIgeDI9IjMwNiIgeTI9IjEyMCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIxMTAiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPis8L3RleHQ+PGxpbmUgeDE9IjMwNiIgeTE9IjE4NiIgeDI9IjMwNiIgeTI9IjIxMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIyMDIiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPis8L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE1NSIgeDI9IjU2NiIgeTI9IjE1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMjQ3IiB4Mj0iNTY2IiB5Mj0iMjQ3IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjI0NyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTQyIiB4Mj0iNjk5IiB5Mj0iMTU2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjIyIiB4Mj0iNjk5IiB5Mj0iMjM2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzEwIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5EZXV4CmNvbXBvc2FudGVzIHN1ciB0cm9pcyByZXRvbWJlbnQgc3VyIDUwIHNhbnMgZG9ubsOpZXMgOiA3MCAlIGR1IHNjb3JlIHBldXQKw6p0cmUgdW5lIGNvbnN0YW50ZS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGEKZ8Opb23DqXRyaWUgbWVzdXJlIGxhIGZvcm1lIGRlIGzigJlVR0YsIHBhcyBjZWxsZSBkdSBtYXNzaWYgOiBsZSBkw6ljb3VwYWdlCmNhZGFzdHJhbCBww6hzZSBzdXIgbGUgc2NvcmUuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPmluZGljYXRldXJfbDFfc3lsdm9zcGhlcmUoKQpyZXN0ZSB1biBhbGlhcyBhY2NlcHTDqSAoc3BlYyAwNDUpIDsgbGEgY29sb25uZSwgZWxsZSwgYSBjaGFuZ8OpIGRlCm5vbS48L3RleHQ+PC9zdmc+)

Trois composantes cumulées et deux valeurs par défaut. Avant de lire un
L1, vérifier quelles couches étaient présentes : le score reste
plausible lorsqu’il n’a été calculé que pour trois dixièmes.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction L1 | `R/indicators-families.R:1682-1860` |
| Alias historique | [`indicateur_l1_sylvosphere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_sylvosphere.md) — `:1992` |
| Renommage de la famille | `specs/045-renommage-famille-L/`, [`migrer_colonnes_l()`](https://pobsteta.github.io/nemeton/reference/migrer_colonnes_l.md) |
