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
par le moteur microclimatique (`microclimf`), fournie précalculée dans
l’objet `micro`, puis la normalise. L’orchestration intégrée au cœur
n’est pas encore branchée (spec 027 L1).

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
| **0** + run `microclimf` | forçage ERA5-Land + CHM ML | **calculé**, drapeau `microclimate_model` |
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
(tamponnement) et **R6** (sensibilité) : un seul run `microclimf`
alimente les quatre.

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBXNCA6IE5lbWV0b24gbmUgY2FsY3VsZSBwYXMgbGUgZGVmaWNpdCBkZSBwcmVzc2lvbiBkZSB2YXBldXIsIGlsIGV4dHJhaXQgbGEgY291Y2hlIHZwZCBwcm9kdWl0ZSBwYXIgbGUgbW90ZXVyIG1pY3JvY2xpbWYgcHVpcyBsYSByZXRvdXJuZSBzdXIgdW5lIGVjaGVsbGUgZGVjcm9pc3NhbnRlIGRlIDQsMCBhIDAsNSBrUGEgOyBzYW5zIGNoYWluZSBtaWNyb2NsaW1hdCwgVzQgdmF1dCBOQSBldCBsYSBmYW1pbGxlIEVhdSBzZSBjYWxjdWxlIHN1ciBXMSBhIFczIHNldWxzLiI+PGRlZnM+PG1hcmtlciBpZD0iZmQiIHZpZXdib3g9IjAgMCAxMCAxMCIgcmVmeD0iOSIgcmVmeT0iNSIgbWFya2Vyd2lkdGg9IjYiIG1hcmtlcmhlaWdodD0iNiIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPjxwYXRoIGQ9Ik0wLDAgTDEwLDUgTDAsMTAgeiIgZmlsbD0iY3VycmVudENvbG9yIiAvPjwvbWFya2VyPjwvZGVmcz48ZyBmaWxsPSJjdXJyZW50Q29sb3IiIGZvbnQtc2l6ZT0iMTAiIGxldHRlci1zcGFjaW5nPSIxLjMiIG9wYWNpdHk9Ii41NSI+PHRleHQgeD0iMTAiIHk9IjE2Ij5FTlRSw4lFUzwvdGV4dD48dGV4dCB4PSIyOTAiIHk9IjE2Ij5DQUxDVUwg4oCUIMOJVEFQRVMKU1VDQ0VTU0lWRVM8L3RleHQ+PHRleHQgeD0iNTg4IiB5PSIxNiI+QVZBTDwvdGV4dD48L2c+PHJlY3QgeD0iOCIgeT0iMzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ydW4KbWljcm9jbGltZiAob2JqZXQgbWljcm8pPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZvcsOnYWdlCkVSQTUtTGFuZCArIENITSBNTDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jb3VjaGUKdnBkLCDDqXTDqTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxMDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTI1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+U3RydWN0dXJlCkxpREFSIEhEIG91IGRyb25lPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxNDEiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jYW5vcMOpZQptaWV1eCBkw6ljcml0ZSAoTkRQIDHigJMyKTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxNjIiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5DaGHDrm5lCm1pY3JvY2xpbWF0IG5vbiBsYW5jw6llPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5XNAo9IE5BIOKAlCBjYXMgbm9taW5hbDwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkV4dHJhY3Rpb24Kem9uYWxlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+VzRfdnBkCj0gbW95KHJhc3RlciB2cGQpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y29sb25uZQphbm5leGUsIGVuIGtQYTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjEyNiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+UmV0b3VybmVtZW50CmTigJnDqWNoZWxsZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE2MSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij4xMDAKw5cgKDQsMCAtIFZQRCkvKDQsMCAtIDAsNSk8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+w6ljcsOqdMOpCnN1ciBbMCwgMTAwXTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjM0IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0iIzJDNkI2MDBGIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuOTUiIC8+PHRleHQgeD0iNTk4IiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjMkM2QjYwIj5pbmRpY2F0ZXVyX3c0X3ZwZDwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNjb3JlCjDigJMxMDAsIG5hdGlmPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij7DqWNyw6p0YWdlCm5hdGlmIDDigJMxMDA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcV+KAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9lYXU8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpkZSBXMSDDoCBXNDwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjI0MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMjYxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y29tcHV0ZV9nZW5lcmFsX2luZGV4KCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Rmlib25hY2NpCsK3IGNvbmZpYW5jZSDPhjwvdGV4dD48bGluZSB4MT0iMjYwIiB5MT0iNjMiIHgyPSIyODIiIHkyPSI2MyIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHBhdGggZD0iTTI2MCAxMjcgSDI3MSBWMTU1IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDE4MyBIMjcxIFYxNTUgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI5NCIgeDI9IjMwNiIgeTI9IjEyMCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIxMTAiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnB1aXM8L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE1NSIgeDI9IjU2NiIgeTI9IjE1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1NjYiIHkyPSIxNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTgwIiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE0MiIgeDI9IjY5OSIgeTI9IjE1NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIyMiIgeDI9IjY5OSIgeTI9IjIzNiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjMxMCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TkEKZXN0IGxlIGNhcyBub21pbmFsLCBwYXMgdW5lIGFub21hbGllIDogZmFtaWxsZV9lYXUgc2UgY2FsY3VsZSBhbG9ycyBzdXIKVzHigJNXMyAobmEucm0gPSBUUlVFKS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+U2VucwppbnZlcnPDqSA6IFZQRCDDqWxldsOpID0gYWlyIHNlYyA9IGTDqWZhdm9yYWJsZS4gVzQgPSA5MCBzaWduaWZpZSBhbWJpYW5jZQp0YW1wb25uw6llLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzQyIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5MZQpkcmFwZWF1IG1pY3JvY2xpbWF0ZV9tb2RlbCBkaXQgwqsgc2ltdWxhdGlvbiDCuyA7IGlsIG5lIG1vbnRlIHBhcyBsZQpuaXZlYXUgTkRQLjwvdGV4dD48L3N2Zz4=)

Un indicateur d’extraction, pas de calcul. Toute la physique est en
amont, dans microclimf ; Néméton n’y ajoute qu’un retournement d’échelle
— d’où l’inversion de lecture entre la colonne annexe `W4_vpd` et le
score.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction W4 | `R/indicators-microclimate.R:179` |
| Bornes | `.MICRO_BOUNDS` — `R/indicators-microclimate.R:21-26` |
| Orchestration | run `microclimf` externe (objet `micro`) ; années : [`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md) |
| Spécification | `specs/027-regeneration-microclimat/`, ADR-014 |
