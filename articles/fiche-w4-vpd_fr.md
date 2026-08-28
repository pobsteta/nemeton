# Fiche indicateur W4 - Deficit de saturation sous couvert

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Indicateur **conditionné** : il n’existe que si la chaîne microclimat
> a tourné (spec 027, ADR-014).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `W4` |
| Nom long / colonne | `indicateur_w4_vpd` |
| Famille | **W — Eau & Régulation** |
| Grandeur mesurée | **VPD** — déficit de pression de vapeur sous couvert, en été |
| Unité brute | **score 0–100** (le VPD brut est en kPa, cf. colonne annexe) |
| Sens | Haut = favorable (**VPD bas = air humide = peu de stress**) |
| Normalisation | **native 0–100**, écrêtage (`.NORMALIZE_NATIVE_0_100`) |
| Fonction | [`indicateur_w4_vpd()`](https://pobsteta.github.io/nemeton/reference/indicateur_w4_vpd.md) — `R/indicators-microclimate.R:179` |
| Bornes | `.MICRO_BOUNDS$w4 = c(lo = 0,5 ; hi = 4,0)` kPa, **décroissant** |
| Colonne annexe | `W4_vpd` (kPa brut) |
| Drapeau NDP | `microclimate_model` |

## 2. Le calcul

W4 n’est pas calculé par Néméton : il **extrait** une couche produite
par le moteur microclimatique (`microclimf`, orchestré par
[`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)),
puis la normalise.

    W4_vpd = moyenne zonale du raster `vpd` sur l'unite      kPa
    W4     = 100 x (4,0 - VPD) / (4,0 - 0,5)                 ecrete [0, 100]

L’échelle est **décroissante** : 4,0 kPa → 0, 0,5 kPa → 100.

**Exemples chiffrés** :

| Situation                              | VPD (kPa) | W4       |
|----------------------------------------|-----------|----------|
| Sous couvert fermé, ambiance tamponnée | 0,8       | **91,4** |
| Futaie claire                          | 1,6       | **68,6** |
| Peuplement ouvert, journée chaude      | 2,8       | **34,3** |
| Trouée exposée, canicule               | 3,9       | **2,9**  |

## 3. Le calcul par niveau NDP

W4 ne suit pas l’échelle NDP habituelle : il est **conditionné à la
disponibilité d’un modèle**, pas à un capteur.

| NDP | Ce qui existe | W4 |
|----|----|----|
| **0** sans microclimat | rien | **`NA`** — l’indicateur n’est pas calculé |
| **0** + [`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md) | forçage ERA5-Land + CHM ML | **calculé**, drapeau `microclimate_model` |
| **1** | \+ structure LiDAR HD en entrée du modèle | même grandeur, canopée mieux décrite |
| **2** | \+ structure drone | idem, résolution supérieure |
| **3–4** | \+ capteurs in situ | validation du modèle, pas remplacement |

> **Le drapeau `microclimate_model` ne change pas le niveau NDP**
> (ADR-011 amendé) : un microclimat modélisé reste une modélisation. Il
> signale que la famille A et les indicateurs W4/R6 reposent sur une
> simulation, pas sur une mesure.

## 4. Trois pièges

1.  **`NA` est le cas nominal, pas une anomalie.** Sur un projet où la
    chaîne microclimat n’a pas tourné, W4 vaut `NA` pour toutes les
    unités et `famille_eau` se calcule sur W1–W3 seuls (`na.rm = TRUE`).
    Ce n’est pas un défaut à corriger.
2.  **Le sens est inversé par rapport à l’intuition.** Un VPD **élevé**
    est défavorable (air sec, forte demande évaporative), donc le score
    est décroissant. Lire `W4 = 90` comme « fort déficit de saturation »
    est un contresens : c’est l’inverse. La colonne annexe `W4_vpd`
    porte la grandeur physique, dans le bon sens.
3.  **Les bornes 0,5–4,0 kPa sont des bornes de modèle, pas de mesure.**
    Elles encadrent ce que `microclimf` produit sur un été français ;
    une station météo sous couvert pourrait sortir de la plage. Les deux
    extrêmes du score sont donc des plafonds de convention.

## 5. Aval

    indicateur_w4_vpd()  ->  colonnes W4 (0-100) et W4_vpd (kPa)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("W")  -> famille_eau = moy(W1, W2, W3, W4)

W4 partage son objet `micro` avec **A3** (T°max sous couvert), **A4**
(tamponnement) et **R6** (sensibilité) : un seul
[`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
alimente les quatre.

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBXNCA6IE5lbWV0b24gbmUgY2FsY3VsZSBwYXMgbGUgZGVmaWNpdCBkZSBwcmVzc2lvbiBkZSB2YXBldXIsIGlsIGV4dHJhaXQgbGEgY291Y2hlIHZwZCBwcm9kdWl0ZSBwYXIgbGUgbW90ZXVyIG1pY3JvY2xpbWYgcHVpcyBsYSByZXRvdXJuZSBzdXIgdW5lIGVjaGVsbGUgZGVjcm9pc3NhbnRlIGRlIDQsMCBhIDAsNSBrUGEgOyBzYW5zIGNoYWluZSBtaWNyb2NsaW1hdCwgVzQgdmF1dCBOQSBldCBsYSBmYW1pbGxlIEVhdSBzZSBjYWxjdWxlIHN1ciBXMSBhIFczIHNldWxzLiI+PGRlZnM+PG1hcmtlciBpZD0iZmQiIHZpZXdib3g9IjAgMCAxMCAxMCIgcmVmeD0iOSIgcmVmeT0iNSIgbWFya2Vyd2lkdGg9IjYiIG1hcmtlcmhlaWdodD0iNiIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPjxwYXRoIGQ9Ik0wLDAgTDEwLDUgTDAsMTAgeiIgZmlsbD0iY3VycmVudENvbG9yIiAvPjwvbWFya2VyPjwvZGVmcz48ZyBmaWxsPSJjdXJyZW50Q29sb3IiIGZvbnQtc2l6ZT0iMTAiIGxldHRlci1zcGFjaW5nPSIxLjMiIG9wYWNpdHk9Ii41NSI+PHRleHQgeD0iMTAiIHk9IjE2Ij5FTlRSw4lFUzwvdGV4dD48dGV4dCB4PSIyOTAiIHk9IjE2Ij5DQUxDVUwg4oCUIMOJVEFQRVMKU1VDQ0VTU0lWRVM8L3RleHQ+PHRleHQgeD0iNTg4IiB5PSIxNiI+QVZBTDwvdGV4dD48L2c+PHJlY3QgeD0iOCIgeT0iMzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5taWNyb2NsaW1hdGVfcnVuKCkK4oCUIG1pY3JvY2xpbWY8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Zm9yw6dhZ2UKRVJBNS1MYW5kICsgQ0hNIE1MPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmNvdWNoZQp2cGQsIMOpdMOpPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjEwNiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5TdHJ1Y3R1cmUKTGlEQVIgSEQgb3UgZHJvbmU8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE0MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmNhbm9ww6llCm1pZXV4IGTDqWNyaXRlIChORFAgMeKAkzIpPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE2MiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNoYcOubmUKbWljcm9jbGltYXQgbm9uIGxhbmPDqWU8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlc0Cj0gTkEg4oCUIGNhcyBub21pbmFsPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMzQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+RXh0cmFjdGlvbgp6b25hbGU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5XNF92cGQKPSBtb3kocmFzdGVyIHZwZCk8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jb2xvbm5lCmFubmV4ZSwgZW4ga1BhPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTI2IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5SZXRvdXJuZW1lbnQKZOKAmcOpY2hlbGxlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPjEwMArDlyAoNCwwIC0gVlBEKS8oNCwwIC0gMCw1KTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij7DqWNyw6p0w6kKc3VyIFswLCAxMDBdPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfdzRfdnBkPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2NvcmUKMOKAkzEwMCwgbmF0aWY8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOpY3LDqnRhZ2UKbmF0aWYgMOKAkzEwMDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE2MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxX4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX2VhdTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIFcxIMOgIFc0PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxsaW5lIHgxPSIyNjAiIHkxPSI2MyIgeDI9IjI4MiIgeTI9IjYzIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48cGF0aCBkPSJNMjYwIDEyNyBIMjcxIFYxNTUgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTgzIEgyNzEgVjE1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijk0IiB4Mj0iMzA2IiB5Mj0iMTIwIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjExMCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+cHVpczwvdGV4dD48bGluZSB4MT0iNTUwIiB5MT0iNjMiIHgyPSI1NjYiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMTU1IiB4Mj0iNTY2IiB5Mj0iMTU1IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjE1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTQyIiB4Mj0iNjk5IiB5Mj0iMTU2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjIyIiB4Mj0iNjk5IiB5Mj0iMjM2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzEwIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5OQQplc3QgbGUgY2FzIG5vbWluYWwsIHBhcyB1bmUgYW5vbWFsaWUgOiBmYW1pbGxlX2VhdSBzZSBjYWxjdWxlIGFsb3JzIHN1cgpXMeKAk1czIChuYS5ybSA9IFRSVUUpLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzI2IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5TZW5zCmludmVyc8OpIDogVlBEIMOpbGV2w6kgPSBhaXIgc2VjID0gZMOpZmF2b3JhYmxlLiBXNCA9IDkwIHNpZ25pZmllIGFtYmlhbmNlCnRhbXBvbm7DqWUuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlCmRyYXBlYXUgbWljcm9jbGltYXRlX21vZGVsIGRpdCDCqyBzaW11bGF0aW9uIMK7IDsgaWwgbmUgbW9udGUgcGFzIGxlCm5pdmVhdSBORFAuPC90ZXh0Pjwvc3ZnPg==)

Un indicateur d’extraction, pas de calcul. Toute la physique est en
amont, dans microclimf ; Néméton n’y ajoute qu’un retournement d’échelle
— d’où l’inversion de lecture entre la colonne annexe `W4_vpd` et le
score.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction W4 | `R/indicators-microclimate.R:179` |
| Bornes | `.MICRO_BOUNDS` — `R/indicators-microclimate.R:21-26` |
| Orchestration | [`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md), [`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md) |
| Spécification | `specs/027-regeneration-microclimat/`, ADR-014 |
