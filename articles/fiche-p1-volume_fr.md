# Fiche indicateur P1 - Volume sur pied

> **Document de référence** — Néméton (package cœur), 2026-08-27.
> Partage le tarif IFN avec **C1** : le correctif 0.169.0 a touché les
> deux.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `P1` |
| Nom long / colonne | `indicateur_p1_volume` |
| Famille | **P — Production & Économie** (avec P2, P3) |
| Grandeur mesurée | **Volume sur pied**, m³/ha |
| Unité brute | **m³/ha** |
| Sens | Haut = favorable |
| Normalisation | `ref_max = 800` → `score = min(100, V / 800 × 100)` |
| Fonction | [`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md) — `R/indicators-productive.R:102` |

## 2. Le calcul

    V_arbre = a x D^2 x H            tarif IFN a variable combinee (b = 2, c = 1)
    P1      = V_arbre x N            m3/ha,  N en tiges/ha

La hauteur `H` est cherchée dans cet ordre :

| Ordre | Source de H                                      |
|-------|--------------------------------------------------|
| 1     | **CHM** — `extract_h_dom(chm, percentile = 0,9)` |
| 2     | colonne `height_field`                           |
| 3     | **`H = 1,3 + 0,65 × D`** — relation en dur       |

[`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md)
remplit au besoin `dbh` et `density` depuis le CHM (inventaire
synthétique Charru).

**Exemples chiffrés** (hêtre, `a = 0,000039`) :

| D (cm) | H (m) | V/arbre | N (tiges/ha) | P1            | Score    |
|--------|-------|---------|--------------|---------------|----------|
| 26,6   | 24    | 0,662   | 553          | **366 m³/ha** | **45,8** |
| 35     | 28    | 1,338   | 300          | **401 m³/ha** | **50,2** |
| 20     | 18    | 0,281   | 800          | **225 m³/ha** | **28,1** |

## 3. Le calcul par niveau NDP

| NDP | Entrées | Ce qui change |
|----|----|----|
| **0** | aucune hauteur → `H = 1,3 + 0,65 × D` | relation en dur, cf. §4 |
| **0 augmenté** `height_ml` | CHM FORMS-T / FORMSpoT / Open-Canopy | H réelle, D et N synthétiques |
| **1** | MNH LiDAR HD | H mesurée |
| **3** | **inventaire terrain** : D au ruban, N compté | la vraie mesure |
| **4** | TLS | volume par arbre |

## 4. Quatre pièges

1.  **Le correctif 0.169.0 (spec 040) est structurant.** Les exposants
    `b ≈ 2,5` et `c ≈ 0,97` du fichier de tarifs étaient **incohérents
    avec le coefficient `a`**, calibré pour `V = a·D²·H`. L’erreur était
    multiplicative en `D^0,5` : un hêtre de 30 cm / 25 m cubait **4,45
    m³ au lieu de 0,85**, et un peuplement à 466 tiges/ha ressortait à
    ~1 550 m³/ha au lieu de ~395. **Tout `indicators.parquet` produit
    avec une version ≤ 0.168.0 est à recalculer.**
2.  **La relation `H = 1,3 + 0,65 × D` est une relation de secours, pas
    une allométrie de station.** Un arbre de 30 cm y fait 20,8 m, quels
    que soient l’essence, la fertilité et l’âge. À NDP 0 sans CHM, elle
    porte tout le volume — fournir un CHM public est le gain le plus
    rentable sur P1.
3.  **`method = "allometric"` n’existe pas.** Le dispatch n’a jamais été
    implémenté : la boucle applique toujours le tarif IFN. Depuis
    0.169.0, un `cli_warn` explicite le dit au lieu de retourner
    silencieusement le résultat de `"ifn_tarif"`.
4.  **`density` est en tiges/ha ici**, contrairement au chemin 1 de C1
    où c’est une fraction 0–1. C’est le piège d’unité documenté dans la
    fiche C1.

## 5. Aval

    indicateur_p1_volume()  ->  colonne indicateur_p1_volume (m3/ha)
          |
          +- normalize_indicator()     -> min(100, V / 800 x 100)
          +- create_family_index("P")  -> famille_production = moy(P1, P2, P3)
          +- volume_mobilisable()      -> desserte / foretaccess (garde-fou p1_max_plausible = 800)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM3NiIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBQMSA6IHVuIHRhcmlmIElGTiBhIHZhcmlhYmxlIGNvbWJpbmVlIGN1YmUgbCYjMzk7YXJicmUgbW95ZW4gYSBwYXJ0aXIgZHUgZGlhbWV0cmUgZXQgZCYjMzk7dW5lIGhhdXRldXIgY2hlcmNoZWUgZGFucyB0cm9pcyBzb3VyY2VzIHN1Y2Nlc3NpdmVzIOKAlCBDSE0sIGNvbG9ubmUgZm91cm5pZSwgcmVsYXRpb24gZGUgc2Vjb3VycyDigJQgcHVpcyBtdWx0aXBsaWUgcGFyIGxhIGRlbnNpdGUgZW4gdGlnZXMgcGFyIGhlY3RhcmUuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgw4lUQVBFUwpTVUNDRVNTSVZFUzwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNITQpNTCBvdSBNTkggTGlEQVI8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjY5IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZXh0cmFjdF9oX2RvbShjaG0sCnA5MCk8L3RleHQ+PHJlY3QgeD0iOCIgeT0iOTAiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTA5IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q29sb25uZQpoZWlnaHRfZmllbGQ8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmhhdXRldXIKZOKAmWludmVudGFpcmU8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTQ2IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgLz48dGV4dCB4PSIyMCIgeT0iMTY1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+TmkKQ0hNIG5pIGhhdXRldXI8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkgKPSAxLDMgKyAwLDY1IMOXIEQgKHNlY291cnMpPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjIwMiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIyMjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5kYmgKZXQgZGVuc2l0eTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMjM3IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZW5zdXJlX2ludmVudG9yeV9maWVsZHMoKTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMjUzIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZGVuc2l0eQplbiB0aWdlcy9oYTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkN1YmFnZQpkZSBs4oCZYXJicmUgbW95ZW48L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5WCj0gYSDDlyBEwrIgw5cgSDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnRhcmlmCklGTiwgYiA9IDIsIGMgPSAxPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMTI2IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSIxNDUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5QYXNzYWdlCsOgIGzigJloZWN0YXJlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlAxCj0gViDDlyBOIChtwrMvaGEpPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfcDFfdm9sdW1lPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+dm9sdW1lCnN1ciBwaWVkLCBtwrMvaGE8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1pbigxMDAsClYgLyA4MDAgw5cgMTAwKTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjE2MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTgxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y3JlYXRlX2ZhbWlseV9pbmRleCjigJxQ4oCdKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjE5NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mYW1pbGxlX3Byb2R1Y3Rpb248L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpkZSBQMSDDoCBQMzwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjI0MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMjYxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y29tcHV0ZV9nZW5lcmFsX2luZGV4KCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Rmlib25hY2NpCsK3IGNvbmZpYW5jZSDPhjwvdGV4dD48cGF0aCBkPSJNMjYwIDU1IEgyNzEgVjYzIEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDExMSBIMjcxIFY2MyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxNjcgSDI3MSBWNjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMjMxIEgyNzEgVjE0NyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijk0IiB4Mj0iMzA2IiB5Mj0iMTIwIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjExMCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+cHVpczwvdGV4dD48bGluZSB4MT0iNTUwIiB5MT0iNjMiIHgyPSI1NjYiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMTQ3IiB4Mj0iNTY2IiB5Mj0iMTQ3IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjE0NyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTQyIiB4Mj0iNjk5IiB5Mj0iMTU2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjIyIiB4Mj0iNjk5IiB5Mj0iMjM2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzEwIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5Db3JyZWN0aWYKMC4xNjkuMCAoc3BlYyAwNDApIDogbGVzIGV4cG9zYW50cyBlcnJvbsOpcyBnb25mbGFpZW50IFAxIGRlIDMgw6AgNSDigJQgbGVzCmFuY2llbm5lcyB2YWxldXJzIHNvbnQgw6AgcmVjYWxjdWxlci48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjMyNiIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+SAo9IDEsMyArIDAsNjUgw5cgRCBlc3QgdW5lIHJlbGF0aW9uIGRlIHNlY291cnMsIHBhcyB1bmUgYWxsb23DqXRyaWUKZOKAmWVzc2VuY2UuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPm1ldGhvZAo9IOKAnGFsbG9tZXRyaWPigJ0gbuKAmWV4aXN0ZSBwYXMgOiBsZSBkaXNwYXRjaCBu4oCZYSBqYW1haXMgw6l0w6kgYnJhbmNow6kuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNTgiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPmRlbnNpdHkKZXN0IGljaSBlbiB0aWdlcy9oYSDigJQgbGUgY2hlbWluIDEgZGUgQzEgbOKAmWF0dGVuZCBlbiAw4oCTMSA6IG5lIHBhcwpyZWN5Y2xlciBsYSBjb2xvbm5lLjwvdGV4dD48L3N2Zz4=)

Le tarif ne change pas, la hauteur si. C’est la source de H — CHM
mesuré, hauteur d’inventaire ou relation de secours — qui décide de ce
que vaut réellement un P1, et rien dans la colonne ne le dit.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction P1 | `R/indicators-productive.R:102-330` |
| Tarifs IFN | `inst/extdata/ifn_volume_equations.csv` |
| Inventaire synthétique | [`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md), [`estimate_synthetic_inventory()`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md) |
| Correctif des exposants | `NEWS.md` 0.169.0, `specs/040-volume-mobilisable-desserte/` |
| Fiche partageant le tarif | [`vignette("fiche-c1-biomasse_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.md) |
