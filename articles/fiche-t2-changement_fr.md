# Fiche indicateur T2 - Stabilite du couvert

> **Document de référence** — Néméton (package cœur), 2026-10-11 (spec
> 060) ; proxy N2 / T1 retiré en 2026.10.5 (2026-10-13).

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
| `t2_status` | `"forms_t"` (mesuré) ou `"no_source"` (unité sans couvert dans la série) |
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

## 3. Sans FORMS-T : NA

Hors France, si FORMS-T n’est pas lisible, T2 vaut `NA` et la fonction
n’ajoute que la colonne `T2`. Une unité que la série ne couvre pas
reçoit `NA` et `t2_status = "no_source"`.

Jusqu’à la 2026.10.4, T2 se repliait sur une copie de N2, puis sur l’âge
T1 plafonné à 100. Ce proxy a été retiré en 2026.10.5 : il ne mesurait
aucun changement et comptait deux fois N2 ou T1 dans les familles.
L’argument `t1_values` est conservé pour ne pas casser les appels, mais
il est ignoré et lève un avertissement une fois par session.

## 4. Trois pièges

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

## 5. Aval

    charger_forms_t_hauteurs()  ->  pile FORMS-T (une couche par an, cm)
    indicateur_t2_changement(forms_t = )  ->  T2 (0-100) + t2_status, t2_perte_pct, ...
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("T")  -> famille_temporelle = moy(T1, T2, T3)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBUMiA6IGF2ZWMgbGEgc2VyaWUgRk9STVMtVCwgbGEgcGFydCBkdSBjb3V2ZXJ0IGVuIHBlcnRlIGR1cmFibGUgZGUgaGF1dGV1ciBkb25uZSBsZSBzY29yZSA7IHNhbnMgZWxsZSwgb3UgcG91ciB1bmUgdW5pdGUgaG9ycyBzZXJpZSwgVDIgdmF1dCBOQS4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCBQUkVNSUVSCkNIRU1JTiBTRVJWSTwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkZPUk1TLVQK4oCUIGhhdXRldXIgYW5udWVsbGU8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+MTAKbSwgMjAxOSDDoCAyMDI0LCBlbiBjbTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jaGFyZ2VyX2Zvcm1zX3RfaGF1dGV1cnMoKTwvdGV4dD48cmVjdCB4PSI4IiB5PSIxMDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5QYXMKZGUgc8OpcmllIEZPUk1TLVQ8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE0MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmhvcnMKRnJhbmNlLCBUaGVpYSBhYnNlbnQ8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI3NCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5QZXJ0ZQpkdXJhYmxlIGRlIGNvdXZlcnQ8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5oYXV0ZXVyCuKJpCBtYXggYW50w6lyaWV1ciDiiJIgNSBtPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+anVzcXXigJnDoApsYSBmaW4gZGUgbGEgc8OpcmllPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTAxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlQyCj0gMTAwIMOXICgxIOKIkiBwYXJ0IGVuIHBlcnRlKTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjE0MiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMzAwIiB5PSIxNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5OQTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5hdWN1bmUKc3RhYmlsaXTDqSBpbnZlbnTDqWU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxOTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+dDJfc3RhdHVzCj0g4oCcbm9fc291cmNl4oCdPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfdDJfY2hhbmdlbWVudDwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNjb3JlCjDigJMxMDAsIG5hdGlmPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij7DqWNyw6p0YWdlCm5hdGlmIDDigJMxMDA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcVOKAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV90ZW1wb3JlbDwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIFQxIMOgIFQzPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxwYXRoIGQ9Ik0yNjAgNjMgSDI3MSBWNzEgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTI3IEgyNzEgVjE3MSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9IjExMCIgeDI9IjMwNiIgeTI9IjEzNiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjEyNiIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+c2lub248L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjcxIiB4Mj0iNTY2IiB5Mj0iNzEiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE3MSIgeDI9IjU2NiIgeTI9IjE3MSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNzEiIHgyPSI1NjYiIHkyPSIxNzEiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjcxIiB4Mj0iNTgwIiB5Mj0iNzEiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE0MiIgeDI9IjY5OSIgeTI9IjE1NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIyMiIgeDI9IjY5OSIgeTI9IjIzNiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjMxMCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+RGlhZ25vc3RpY3MKOiB0Ml9wZXJ0ZV9wY3QsIHQyX2Nyb2lzc2FuY2VfbV9hbiAoVGhlaWwtU2VuKSwgdDJfYW5uZWVzLAp0Ml9zdGF0dXMuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPk5lCnBhcyBjb21wYXJlciBkZXV4IFQyIGNhbGN1bMOpcyBzdXIgZGVzIGZlbsOqdHJlcyBk4oCZYW5uw6llcwpkaWZmw6lyZW50ZXMuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxlCnByb3h5IE4yIC8gVDEgZXN0IHJldGlyw6kgZW4gMjAyNi4xMC41IDogaWwgbmUgbWVzdXJhaXQgYXVjdW4KY2hhbmdlbWVudC48L3RleHQ+PC9zdmc+)

Avec FORMS-T, T2 mesure la stabilité du couvert, toutes causes de perte
confondues (coupe, dépérissement, chablis). Sans la série, T2 reste NA
plutôt que de recopier N2 ou T1.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction T2 | `R/indicators-temporal.R` ([`indicateur_t2_changement()`](https://pobsteta.github.io/nemeton/reference/indicateur_t2_changement.md), `.t2_forms_t()`) |
| Lecture de la série | `R/forms_t.R` ([`charger_forms_t_hauteurs()`](https://pobsteta.github.io/nemeton/reference/charger_forms_t_hauteurs.md)) |
| Spec, mesures et validation | `specs/060-t2-taux-de-changement/spec.md` |
| Coupes rases seules | **T3** (SUFOSAT) |
