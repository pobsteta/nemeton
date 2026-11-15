# Fiche indicateur T4 - Vitalité dynamique (FORMS-T contre FINN)

> **Document de référence** — Néméton (package cœur), 2026-11-15.
> Indicateur **conditionné** : calculé seulement si la série de hauteurs
> FORMS-T et l’essence dominante de l’unité sont fournies (spec 068).

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `T4` |
| Nom long / colonne | `indicateur_t4_vitalite` |
| Famille | **T — Dynamique temporelle** |
| Grandeur mesurée | Croissance en hauteur dominante observée, rapportée à celle qu’attend le modèle FINN |
| Unité brute | **rang 0–100** ; 50 = croissance attendue |
| Sens | haut = bon, sans inversion (natif 0–100) |
| Fonction | [`indicateur_t4_vitalite()`](https://pobsteta.github.io/nemeton/reference/indicateur_t4_vitalite.md) — `R/indicateur_t4_vitalite.R` |
| Sources | FORMS-T 2019-2024 (hauteur de canopée annuelle, 10 m) ; IFN BFC ; FINN calibré sur l’IFN ; E-OBS |

## 2. Le calcul

    observé   : chaque année, hauteur dominante de l'unité = percentile 90
                des pixels FORMS-T d'au moins 5 m ;
                accroissement = pente de Theil-Sen 2019-2024 × 5   (m / 5 ans)

    attendu   : placettes IFN analogues (même essence dominante, même SER,
                hauteur dominante 2019 à ± 2 m ; sinon toutes SER, puis ± 4 m) ;
                accroissement simulé par FINN en un pas de 5 ans, climat
                E-OBS 2019-2023, 20 tirages par placette

    bruit     : résidus observé − simulé autour des placettes IFN de même
                essence et de même hauteur (biais moyen compris)

    T4 = 100 × P(simulé + résidu < observé)

La hauteur des arbres simulés vient d’une relation hauteur-diamètre par
essence (et par SER quand au moins 500 arbres ont été mesurés), ajustée
sur les 128 808 hauteurs totales mesurées par l’IFN en
Bourgogne-Franche-Comté (`inst/extdata/allometrie_hauteur_ifn.csv`). La
hauteur dominante simulée est la hauteur moyenne des 100 plus gros
arbres à l’hectare.

**Pourquoi un résidu.** FORMS-T varie bien plus que les tirages FINN :
autour des placettes IFN, l’accroissement observé a un écart-type de
1,35 m sur 5 ans, contre 0,1 m entre tirages. Classée parmi les seuls
tirages, une unité tomberait presque toujours près de 0 ou de 100. Le
résidu élargit la référence de ce bruit et recentre l’attendu : au-delà
de 28 m, FORMS-T voit encore 0,5 à 1,2 m de croissance que les courbes
hauteur-diamètre ne donnent plus.

**Exemples** (hêtre, 20 m, attendu 1 m sur 5 ans) :

| Observé (m / 5 ans) | T4            | Lecture                           |
|---------------------|---------------|-----------------------------------|
| 1,0                 | ≈ 50          | croissance attendue               |
| 0,0                 | proche de 0   | déficit de croissance             |
| 2,5                 | proche de 100 | croissance supérieure à l’attendu |

**Non calculé** (`NA`, avec un statut) : après une coupe détectée sur la
période (`T3 > 0` ou argument `coupes`, statut `skipped_cut`), après une
chute de la hauteur dominante de plus de 3 m d’une année sur l’autre
(`skipped_drop`), sans essence (`skipped_no_essence`), sans assez
d’analogues (`skipped_no_analogues`, typiquement les peuplements de plus
de 33 m) ou sans assez de pixels de couvert (`skipped_no_coverage`). Une
coupe n’est pas un défaut de vitalité : la surmortalité
([`surmortalite_finn()`](https://pobsteta.github.io/nemeton/reference/surmortalite_finn.md),
spec 069) et R5 disent alors le reste.

## 3. Le calcul par niveau NDP

| NDP | Ce qui existe | T4 |
|----|----|----|
| **0** sans FORMS-T | rien | **`NA`** |
| **0** + FORMS-T | hauteurs annuelles, essence de la BD Forêt | **calculé** sur les placettes IFN analogues |
| **1–2** | LiDAR, orthophotos | inchangé : la série annuelle reste FORMS-T |
| **3** | inventaire de l’unité | FINN simule l’unité elle-même : [`accroissement_hdom_finn()`](https://pobsteta.github.io/nemeton/reference/accroissement_hdom_finn.md) puis argument `attendu` |
| **4** | — | — |

## 4. Pièges

1.  **Un modèle calibré ailleurs.** FINN est démontré sur la FIA de
    l’Oregon ; il est ici calibré sur les placettes IFN de
    Bourgogne-Franche-Comté. Hors de ce domaine, les analogues viennent
    d’une autre région : à Dabo (Vosges), les sapinières poussent un peu
    plus vite que leurs analogues de BFC et T4 se centre vers 57 plutôt
    que 50.
2.  **Climat récent.** L’attendu suppose le climat E-OBS 2019-2023 ; T4
    ne se compare pas d’une fenêtre d’années à l’autre.
3.  **T4 compare deux incertitudes** : la hauteur FORMS-T, prédite
    depuis Sentinel-1/2 et GEDI et non mesurée (erreur de l’ordre du
    mètre), et la trajectoire simulée. Le résidu mesure le bruit sur des
    disques d’environ 20 ha autour de coordonnées IFN floutées : il
    comprend la variabilité entre peuplements, ce qui rend T4 prudent ;
    une unité plus petite est plus bruitée que ce que suppose la
    référence.
4.  **L’essence doit être juste.** Une sapinière-pessière notée « sapin
    » ou « épicéa » ne change presque rien (médiane 57 ou 56 à Dabo),
    mais une essence fausse change les analogues.

## 5. Contrôle de centrage

Sur 1 072 cellules de 4 ha des sapinières-pessières de Dabo (Vosges,
sans perturbation connue, SER D11) :

| Quantile          | 5 % | 10 % | 25 % | 50 % | 75 % | 90 % | 95 % |
|-------------------|-----|------|------|------|------|------|------|
| Attendu si centré | 5   | 10   | 25   | 50   | 75   | 90   | 95   |
| T4 à Dabo         | 13  | 19   | 33   | 57   | 81   | 94   | 98   |

Script : `data-raw/t4_controle_dabo.R`. Les tables embarquées viennent
de `data-raw/allometrie_hauteur_ifn.R`, `data-raw/t4_analogues_bfc.R` et
`data-raw/t4_residus_forms_bfc.R`.

## 6. Aval

    indicateur_t4_vitalite()  ->  colonne T4 (0-100, 50 = attendu)
          |
          +- normalize_indicator()     -> natif 0-100, sans inversion
          +- create_family_index("T")  -> famille_temporel = moy(T1 à T4)

## 7. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2OCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBUNCA6IGxhIGNyb2lzc2FuY2UgZW4gaGF1dGV1ciBkb21pbmFudGUgb2JzZXJ2ZWUgc3VyIEZPUk1TLVQgZXN0IGNsYXNzZWUgcGFybWkgbGVzIGFjY3JvaXNzZW1lbnRzIHF1ZSBGSU5OIHNpbXVsZSBwb3VyIGRlcyBwbGFjZXR0ZXMgSUZOIGFuYWxvZ3VlcywgZWxhcmdpcyBkdSBicnVpdCBkJiMzOTtvYnNlcnZhdGlvbiBtZXN1cmUgYXV0b3VyIGRlIGNlcyBwbGFjZXR0ZXMgOyA1MCA9IGNyb2lzc2FuY2UgYXR0ZW5kdWUuIj48ZGVmcz48bWFya2VyIGlkPSJmZCIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNiIgbWFya2VyaGVpZ2h0PSI2IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTAsMCBMMTAsNSBMMCwxMCB6IiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZpbGw9ImN1cnJlbnRDb2xvciIgZm9udC1zaXplPSIxMCIgbGV0dGVyLXNwYWNpbmc9IjEuMyIgb3BhY2l0eT0iLjU1Ij48dGV4dCB4PSIxMCIgeT0iMTYiPkVOVFLDiUVTPC90ZXh0Pjx0ZXh0IHg9IjI5MCIgeT0iMTYiPkNBTENVTCDigJQgUFJFTUlFUgpDSEVNSU4gU0VSVkk8L3RleHQ+PHRleHQgeD0iNTg4IiB5PSIxNiI+QVZBTDwvdGV4dD48L2c+PHJlY3QgeD0iOCIgeT0iMzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5GT1JNUy1UCuKAlCBoYXV0ZXVyIGFubnVlbGxlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPjEwCm0sIDIwMTkgw6AgMjAyNCwgZW4gY208L3RleHQ+PHRleHQgeD0iMjAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZXNzZW5jZQpkb21pbmFudGUsIFNFUjwvdGV4dD48cmVjdCB4PSI4IiB5PSIxMDYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iMTI1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+UGxhY2V0dGVzCklGTiBhbmFsb2d1ZXM8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE0MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZJTk4sCnVuIHBhcyBkZSA1IGFucywgMjAgdGlyYWdlczwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTU3IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YWxsb23DqXRyaWUKSUZOIEhUT1Q8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTc4IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgLz48dGV4dCB4PSIyMCIgeT0iMTk3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q291cGUKb3UgY2h1dGUgJmd0OyAzIG08L3RleHQ+PHRleHQgeD0iMjAiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlQzCiZndDsgMCBvdSBiYWlzc2UgYW5udWVsbGU8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5BY2Nyb2lzc2VtZW50Cm9ic2VydsOpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+cDkwCmRlcyBwaXhlbHMg4omlIDUgbSBwYXIgYW48L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI4NSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5wZW50ZQpkZSBUaGVpbC1TZW4gw5cgNTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjEyNiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI3NCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+UsOpZsOpcmVuY2UKYXR0ZW5kdWU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNjEiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+c2ltdWzDqQorIHLDqXNpZHUgRk9STVMtVDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tw6ptZQplc3NlbmNlLCBtw6ptZSBoYXV0ZXVyPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTkzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlQ0Cj0gMTAwIMOXIFAocsOpZi4gJmx0OyBvYnNlcnbDqSk8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIyMzQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjMwMCIgeT0iMjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+TkE8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIyNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+cGFzCnVuIGTDqWZhdXQgZGUgdml0YWxpdMOpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjg1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnN1cm1vcnRhbGl0w6ksClI1IDogbGUgcmVsYWlzPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfdDRfdml0YWxpdGU8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5yYW5nCjDigJMxMDAsIDUwID0gYXR0ZW5kdTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bmF0aWYKMOKAkzEwMCwgc2FucyBpbnZlcnNpb248L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcVOKAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV90ZW1wb3JlbDwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjIxMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5tb3llbm5lCmRlIFQxIMOgIFQ0PC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMjQyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIyNjEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jb21wdXRlX2dlbmVyYWxfaW5kZXgoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjI3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5GaWJvbmFjY2kKwrcgY29uZmlhbmNlIM+GPC90ZXh0PjxsaW5lIHgxPSIyNjAiIHkxPSI2MyIgeDI9IjI4MiIgeTI9IjYzIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48cGF0aCBkPSJNMjYwIDEzNSBIMjcxIFYxNjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMTk5IEgyNzEgVjI2MyBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PGxpbmUgeDE9IjMwNiIgeTE9Ijk0IiB4Mj0iMzA2IiB5Mj0iMTIwIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iMyAzIiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMTEwIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5zaW5vbjwvdGV4dD48bGluZSB4MT0iMzA2IiB5MT0iMjAyIiB4Mj0iMzA2IiB5Mj0iMjI4IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iMyAzIiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMjE4IiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5zaW5vbjwvdGV4dD48bGluZSB4MT0iNTUwIiB5MT0iNjMiIHgyPSI1NjYiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMTYzIiB4Mj0iNTY2IiB5Mj0iMTYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIyNjMiIHgyPSI1NjYiIHkyPSIyNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iMjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU4MCIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9Ijc4IiB4Mj0iNjk5IiB5Mj0iOTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIxNDIiIHgyPSI2OTkiIHkyPSIxNTYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSIyMjIiIHgyPSI2OTkiIHkyPSIyMzYiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjEwIiB5PSIzMTgiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkZPUk1TLVQKdmFyaWUgYmllbiBwbHVzIHF1ZSBsZXMgdGlyYWdlcyBGSU5OICgxLDM1IG0gY29udHJlIDAsMSBtIHN1ciA1IGFucykgOgpzYW5zIGxlIHLDqXNpZHUsIFQ0IHNlcmFpdCBwcmVzcXVlIHRvdWpvdXJzIDAgb3UgMTAwLjwvdGV4dD48dGV4dCB4PSIxMCIgeT0iMzM0IiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj5BbmFsb2d1ZXMKZGUgQm91cmdvZ25lLUZyYW5jaGUtQ29tdMOpIDogw6AgRGFibyAoVm9zZ2VzKSwgVDQgc2UgY2VudHJlIHZlcnMKNTcuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNTAiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlBldXBsZW1lbnRzCmRlIHBsdXMgZGUgMzMgbSA6IHBhcyBk4oCZYW5hbG9ndWUsIFQ0IHZhdXQgTkEuPC90ZXh0Pjwvc3ZnPg==)

T4 dit si l’unité pousse comme des peuplements comparables le feraient
selon FINN sous le climat récent, une fois le bruit de FORMS-T pris en
compte ; une coupe ou une chute brutale le laisse NA.
