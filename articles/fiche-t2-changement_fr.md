# Fiche indicateur T2 - Stabilite du couvert

> **Document de référence** — Néméton (package cœur), 2026-10-11 (spec
> 060).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `T2` |
| Nom long / colonne | `indicateur_t2_changement` |
| Famille | **T — Dynamique temporelle** |
| Grandeur mesurée | Stabilité du couvert forestier, 2019 à 2024 |
| Source | **FORMS-T** (Theia), hauteur de canopée annuelle à 10 m |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable (couvert stable) |
| Normalisation | **native 0–100**, écrêtage |
| Fonctions | [`indicateur_t2_changement()`](https://pobsteta.github.io/nemeton/reference/indicateur_t2_changement.md) — `R/indicators-temporal.R` ; [`charger_forms_t_hauteurs()`](https://pobsteta.github.io/nemeton/reference/charger_forms_t_hauteurs.md) — `R/forms_t.R` |

## 2. Le calcul mesuré (FORMS-T)

On lit FORMS-T, la hauteur de canopée de chaque année sur toute la
France, prédite à partir de Sentinel-1, Sentinel-2 et du lidar spatial
GEDI. Sur chaque pixel de 10 m :

1.  **Couvert** : un pixel compte s’il a atteint 5 m au moins une année.
2.  **Perte durable** : le pixel est en perte si, à partir d’une année,
    sa hauteur reste à au moins `seuil_perte` = 5 m sous son maximum des
    années précédentes, et ce jusqu’à la fin de la série. Un creux d’une
    seule année suivi d’une reprise ne compte pas.
3.  **Score** : `T2 = 100 × (1 − part du couvert de l'unité en perte)`.
    La part est pondérée par la couverture des pixels (exactextractr).

On ajoute quatre colonnes de diagnostic :

| Colonne | Contenu |
|----|----|
| `t2_status` | `"forms_t"` (mesuré), `"proxy"` (unité hors série) ou `"no_source"` |
| `t2_perte_pct` | part du couvert en perte durable (%) |
| `t2_croissance_m_an` | pente de Theil-Sen médiane du couvert sans perte (m/an), hors score |
| `t2_annees` | fenêtre lue, par exemple `"2019-2024"` |

**Exemples mesurés** (cache FORMS-T, 2026-10-11) :

| Massif | T2 par unité | Lecture |
|----|----|----|
| Dabo (774 ha) | 95,5 à 99,95 | massif stable, croissance de 0,19 à 0,32 m/an |
| Reconfort | 97 à 100 sur la plupart des unités | quelques taches de perte |
| Fordead (scolytes) | 0,6 à 9,6 | plus de 90 % du couvert perdu |

**Validation.** À Reconfort, on compare les pertes de couvert à la
canopée du LiDAR HD, mesurée de novembre 2023 à janvier 2024 et
indépendante de FORMS-T. 97 % des pertes antérieures à 2024 qui
recoupent une coupe rase SUFOSAT y sont confirmées, et 96 % de celles
qui n’en recoupent pas. Ces dernières forment pour 97 % des taches d’au
moins 0,1 ha. **T2 voit donc des disparitions de couvert que SUFOSAT
ignore**, comme des coupes partielles, du dépérissement ou des chablis.
Le seuil compte peu : entre 3 et 8 m, la part en perte de Reconfort
varie de 8,4 à 6,3 %.

## 3. Le repli sans FORMS-T

Hors France, si FORMS-T n’est pas lisible ou qu’une unité sort de la
série, T2 recopie un autre indicateur :

| Ordre | Chemin | Condition | Valeur |
|----|----|----|----|
| 1 | **N2 comme proxy** | colonne `N2`, `N2_anciennete` ou `N2_anciennet` présente | `N2`, écrêté `[0, 100]` |
| 2 | **T1 plafonné** | `t1_values` ou colonne `T1` | `min(100, âge)`, les `NA` restent `NA` |

Le repli se fait unité par unité. Sans FORMS-T du tout, la fonction rend
ce qu’elle rendait avant la spec 060 : la seule colonne `T2`, sans
colonne de diagnostic.

## 4. Quatre pièges

1.  **Ne pas comparer deux fenêtres.** Un T2 sur 2019-2024 et un T2 sur
    2020-2025 ne se comparent pas : la part en perte grandit avec la
    durée.
2.  **Une hauteur prédite, pas mesurée.** FORMS-T est une estimation par
    apprentissage. Sur Dabo, le bruit d’une année à l’autre vaut 17 cm
    par pixel, très en dessous du seuil de 5 m. Une éclaircie faible
    (moins de 5 m) n’est pas vue.
3.  **Une forêt gérée perd du couvert normalement.** Une récolte de 1 à
    2 % de la surface par an donne un T2 de 88 à 94 sur six ans. Un T2
    bas signale une perte, pas sa cause : T3 (SUFOSAT) dit si ce sont
    des coupes rases, R5 si c’est du dépérissement.
4.  **Le repli proxy double T1.** Quand T2 recopie T1,
    `famille_temporelle` compte deux fois la même grandeur.
    `t2_status = "proxy"` le signale.

## 5. Aval

    charger_forms_t_hauteurs()  ->  pile FORMS-T (une couche par an, cm)
    indicateur_t2_changement(forms_t = )  ->  T2 (0-100) + t2_status, t2_perte_pct, ...
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("T")  -> famille_temporelle = moy(T1, T2, T3)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBUMiA6IGF2ZWMgbGEgc2VyaWUgRk9STVMtVCwgbGEgcGFydCBkdSBjb3V2ZXJ0IGVuIHBlcnRlIGR1cmFibGUgZGUgaGF1dGV1ciBkb25uZSBsZSBzY29yZSA7IHNhbnMgZWxsZSwgb3UgcG91ciB1bmUgdW5pdGUgaG9ycyBzZXJpZSwgVDIgc2UgcmVwbGllIHN1ciBsYSBjb250aW51aXRlIE4yIHB1aXMgc3VyIGwmIzM5O2FnZSBUMSBwbGFmb25uZSBhIDEwMC4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCBQUkVNSUVSCkNIRU1JTiBTRVJWSTwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkZPUk1TLVQK4oCUIGhhdXRldXIgYW5udWVsbGU8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+MTAKbSwgMjAxOSDDoCAyMDI0LCBlbiBjbTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jaGFyZ2VyX2Zvcm1zX3RfaGF1dGV1cnMoKTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxMDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Db2xvbm5lCk4yIG91IMOiZ2UgVDE8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE0MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnJlcGxpCnNhbnMgRk9STVMtVDwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9Ijc0IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlBlcnRlCmR1cmFibGUgZGUgY291dmVydDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmhhdXRldXIK4omkIG1heCBhbnTDqXJpZXVyIOKIkiA1IG08L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5qdXNxdeKAmcOgCmxhIGZpbiBkZSBsYSBzw6lyaWU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxMDEiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+VDIKPSAxMDAgw5cgKDEg4oiSIHBhcnQgZW4gcGVydGUpPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTQyIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Qcm94eQpOMiBwdWlzIFQxPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlQyCj0gTjIgw6ljcsOqdMOpLCBzaW5vbiBtaW4oMTAwLCDDomdlKTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE5MyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij50Ml9zdGF0dXMKPSDigJxwcm94eeKAnTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjM0IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0iIzJDNkI2MDBGIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuOTUiIC8+PHRleHQgeD0iNTk4IiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjMkM2QjYwIj5pbmRpY2F0ZXVyX3QyX2NoYW5nZW1lbnQ8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5zY29yZQow4oCTMTAwLCBuYXRpZjwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+w6ljcsOqdGFnZQpuYXRpZiAw4oCTMTAwPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMTYyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnFTigJ0pPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZhbWlsbGVfdGVtcG9yZWw8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpkZSBUMSDDoCBUMzwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjI0MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMjYxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y29tcHV0ZV9nZW5lcmFsX2luZGV4KCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Rmlib25hY2NpCsK3IGNvbmZpYW5jZSDPhjwvdGV4dD48cGF0aCBkPSJNMjYwIDYzIEgyNzEgVjcxIEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDEyNyBIMjcxIFYxNzEgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSIxMTAiIHgyPSIzMDYiIHkyPSIxMzYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSIzIDMiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIxMjYiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnNpbm9uPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI3MSIgeDI9IjU2NiIgeTI9IjcxIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxNzEiIHgyPSI1NjYiIHkyPSIxNzEiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjcxIiB4Mj0iNTY2IiB5Mj0iMTcxIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI3MSIgeDI9IjU4MCIgeTI9IjcxIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNDIiIHgyPSI2OTkiIHkyPSIxNTYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMjIiIHgyPSI2OTkiIHkyPSIyMzYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMTAiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkRpYWdub3N0aWNzCjogdDJfcGVydGVfcGN0LCB0Ml9jcm9pc3NhbmNlX21fYW4gKFRoZWlsLVNlbiksIHQyX2FubmVlcywKdDJfc3RhdHVzLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzI2IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5OZQpwYXMgY29tcGFyZXIgZGV1eCBUMiBjYWxjdWzDqXMgc3VyIGRlcyBmZW7DqnRyZXMgZOKAmWFubsOpZXMKZGlmZsOpcmVudGVzLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzQyIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5TYW5zCkZPUk1TLVQsIGxlIHLDqXN1bHRhdCBlc3QgY2VsdWkgZGVzIHZlcnNpb25zIGFudMOpcmlldXJlcyAoVDIKc2V1bCkuPC90ZXh0Pjwvc3ZnPg==)

Avec FORMS-T, T2 mesure la stabilité du couvert, toutes causes de perte
confondues (coupe, dépérissement, chablis). Le proxy ne sert que hors
série, et t2_status dit lequel des deux chemins a servi.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction T2 | `R/indicators-temporal.R` ([`indicateur_t2_changement()`](https://pobsteta.github.io/nemeton/reference/indicateur_t2_changement.md), `.t2_forms_t()`) |
| Lecture de la série | `R/forms_t.R` ([`charger_forms_t_hauteurs()`](https://pobsteta.github.io/nemeton/reference/charger_forms_t_hauteurs.md)) |
| Spec, mesures et validation | `specs/060-t2-taux-de-changement/spec.md` |
| Coupes rases seules | **T3** (SUFOSAT) |
