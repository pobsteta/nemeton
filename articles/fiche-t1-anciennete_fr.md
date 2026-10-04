# Fiche indicateur T1 - Anciennete du peuplement

> **Document de référence** — Néméton (package cœur), 2026-08-27, révisé
> le 2026-09-18. Le piège n° 1 que cette fiche relevait — un âge en
> années écrêté à 100 — **est corrigé depuis la 0.197.0** : T1 a
> désormais une borne haute de **200 ans**. Tout `famille_temporelle`
> calculé avant cette date est à refaire.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `T1` |
| Nom long / colonne | `indicateur_t1_anciennete` |
| Famille | **T — Dynamique temporelle** (avec T2, T3) |
| Grandeur mesurée | **Âge du peuplement, en années** |
| Unité brute | **années** |
| Sens | Haut = favorable |
| Normalisation | `ref_max = 200` ans → `min(100, âge / 200 × 100)`, sans inversion |
| Fonction | [`indicateur_t1_anciennete()`](https://pobsteta.github.io/nemeton/reference/indicateur_t1_anciennete.md) — `R/indicators-temporal.R:74` |

## 2. Quatre chemins, servis en cascade

La cascade se joue **unité par unité** : chaque chemin ne comble que les
unités restées `NA` après les précédents, et une **mesure passe avant
une estimation** (audit 1.0 ; jusqu’à la 0.211.0, la seule présence
d’une BD Forêt faisait ignorer un âge relevé).

| Ordre | Chemin | Condition | Valeur |
|----|----|----|----|
| 1 | **Champ d’âge** | colonne `age` renseignée | tel quel |
| 2 | **Année d’installation** | `establishment_year_field` fourni | `année_courante − année_installation` |
| 3 | **BD Forêt / TFV** | couche `bdforet` avec un champ TFV reconnu | âge typologique via `.estimate_age_tfv()`, moyenne pondérée par la surface des TFV **reconnus** |
| 4 | **NDVI** | couche `ndvi` | `20 + max(0, NDVI − 0,2) / 0,6 × 100` |
| — | *aucun* | — | **NA** + avertissement |

Champs TFV reconnus : `TFV`, `tfv`, `CODE_TFV`, `code_tfv`, `ESSENCE`,
`essence`, `LIB_FV`, `lib_fv`, `LIBELLE`, `libelle`. L’estimation
typologique attribue par exemple **100 ans** à une futaie fermée de
feuillus.

**Exemples chiffrés** (chemin NDVI) :

| NDVI | Âge estimé | Score normalisé (borne 200 ans) |
|------|------------|---------------------------------|
| 0,30 | 36,7 ans   | **18,4**                        |
| 0,50 | 70,0 ans   | **35,0**                        |
| 0,72 | 106,7 ans  | **53,4**                        |
| 0,85 | 128,3 ans  | **64,2**                        |

La borne de 200 ans est un **seuil sylvicole**, pas une borne physique :
au-delà de deux siècles, l’ancienneté est tenue pour maximale — une
futaie de 200 ans et une de 400 ans ne se distinguent plus utilement
pour un gestionnaire. Elle étale le domaine forestier courant (30 à 150
ans → **15 à 75**) au lieu de l’écraser, ce que faisait l’écrêtage à 100
par le haut et qu’une borne lointaine aurait fait par le bas.

## 3. Le calcul par niveau NDP

| NDP | Chemin servi | Ce qui change |
|----|----|----|
| **0** | 4 (NDVI) ou 3 (BD Forêt) | âge **typologique**, pas mesuré |
| **1** | 3 | inchangé — l’âge ne se lit pas au LiDAR |
| **2** | 3 | — |
| **3** | 1 ou 2 : **âge relevé sur le terrain** | seule vraie mesure (sondage, archives, carottage), prioritaire sur la BD Forêt |
| **4** | 1 | — |

Comme B1, T1 dépend d’une donnée qui n’est pas télédétectable : l’âge
d’un peuplement se lit dans un document d’aménagement, une archive ou
une carotte, pas dans un capteur.

## 4. Quatre pièges

1.  **L’unité est l’année — la normalisation croyait lire un score.**
    Jusqu’en 0.196.0, `indicateur_t1_anciennete` figurait dans
    `.NORMALIZE_NATIVE_0_100` : sa valeur était simplement écrêtée à
    `[0, 100]`. Un peuplement de **120 ans et un de 300 ans obtenaient
    le même score de 100**, et un âge se lisait directement comme un
    score. Ce n’était pas une normalisation, c’était une coïncidence
    d’échelle qui plafonnait à 100 ans — et la déclaration « natif 0-100
    » désarmait par surcroît le garde-fou qui aurait averti.

    **Corrigé en 0.197.0** (spec 048 §10) : `ref_max = 200` ans. Le sens
    est conservé — plus vieux = mieux, aucune inversion. La fonction
    d’indicateur est inchangée : elle rend toujours un âge en années.

2.  **Sans aucune donnée, T1 valait 50 — un âge fabriqué. Corrigé à
    l’audit 1.0** : le dernier recours est désormais `NA`, et un TFV non
    reconnu est écarté de la moyenne au lieu de compter pour 50 ans.

3.  **Le chemin NDVI convertit de la verdeur en années.**
    `20 + (NDVI − 0,2) / 0,6 × 100` n’a aucun fondement dendrométrique :
    c’est un étalement arbitraire de `[0,2 ; 0,8]` sur `[20 ; 120]` ans.
    À NDP 0 sans BD Forêt, T1 est littéralement C2 remis à l’échelle.

4.  **L’âge TFV est une constante par type de peuplement.** Toutes les
    futaies fermées de feuillus d’un projet reçoivent le même âge. T1 ne
    discrimine donc pas à l’intérieur d’un type.

## 5. Aval

    indicateur_t1_anciennete()  ->  colonne indicateur_t1_anciennete (annees)
          |
          +- normalize_indicator()     -> ecretage [0, 100] (cf. piege 1)
          +- create_family_index("T")  -> famille_temporelle = moy(T1, T2, T3)

T1 alimente aussi **T2** en repli (`t1_values`).

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDUwNCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBUMSA6IHF1YXRyZSBjaGVtaW5zIGVzc2F5ZXMgZW4gY2FzY2FkZSwgdW5pdGUgcGFyIHVuaXRlIOKAlCBjb2xvbm5lIGQmIzM5O2FnZSwgYW5uZWUgZCYjMzk7aW5zdGFsbGF0aW9uLCBhZ2UgdHlwb2xvZ2lxdWUgZGUgbGEgQkQgRm9yZXQsIGNvbnZlcnNpb24gZHUgTkRWSSBlbiBhbm5lZXMg4oCUIHVuZSBtZXN1cmUgcGFzc2FudCBhdmFudCB1bmUgZXN0aW1hdGlvbiA7IHNpIGF1Y3VuIG5lIHJlcG9uZCwgVDEgdmF1dCBOQS4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCBQUkVNSUVSCkNIRU1JTiBTRVJWSTwvdGV4dD48dGV4dCB4PSI1ODgiIHk9IjE2Ij5BVkFMPC90ZXh0PjwvZz48cmVjdCB4PSI4IiB5PSIzNCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkNvbG9ubmUKYWdlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOiZ2UKZOKAmWludmVudGFpcmUsIHRlbCBxdWVsPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjkwIiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEwOSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmVzdGFibGlzaG1lbnRfeWVhcl9maWVsZDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTI1IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+YW5uw6llCmNvdXJhbnRlIC0gaW5zdGFsbGF0aW9uPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE0NiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxNjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5CRApGb3LDqnQg4oCUIGNoYW1wIFRGVjwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTgxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+VEZWLApDT0RFX1RGViwgRVNTRU5DRSwgTElCX0ZW4oCmPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij4uZXN0aW1hdGVfYWdlX3RmdigpPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjIxOCIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIyMzciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5Db3VjaGUKbmR2aTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMjUzIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+U2VudGluZWwtMiwKMTAgbTwvdGV4dD48cmVjdCB4PSI4IiB5PSIyNzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiAvPjx0ZXh0IHg9IjIwIiB5PSIyOTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5BdWN1bgpkZXMgcXVhdHJlPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIzMDkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5OQQorIGF2ZXJ0aXNzZW1lbnQ8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIzNCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj7DgmdlCmTigJlpbnZlbnRhaXJlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+dmFsZXVyCnJlcHJpc2Ugc2FucyBjYWxjdWw8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIxMTAiIHdpZHRoPSIyNjIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjEyOSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkFubsOpZQpk4oCZaW5zdGFsbGF0aW9uPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPsOiZ2UKPSBhbm7DqWUgLSBpbnN0YWxsYXRpb248L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIxODYiIHdpZHRoPSIyNjIiIGhlaWdodD0iNzQiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjIwNSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPsOCZ2UKdHlwb2xvZ2lxdWU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIyMjEiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y29uc3RhbnRlCnBhciB0eXBlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjM3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPlRGVgppbmNvbm51IMOpY2FydMOpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjUzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZ1dGFpZQpmZXVpbGx1ZSBmZXJtw6llIDogMTAwIGFuczwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjI5NCIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMzEzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q29udmVyc2lvbgpkdSBORFZJPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMzI5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPjIwCisgbWF4KDAsIE5EVkktMCwyKS8wLDYgw5cgMTAwPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMzcwIiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgLz48dGV4dCB4PSIzMDAiIHk9IjM4OSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPk5BPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iNDA1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmF1Y3VuCsOiZ2UgaW52ZW50w6k8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl90MV9hbmNpZW5uZXRlPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+w6JnZSwKZW4gYW5uw6llczwvdGV4dD48cmVjdCB4PSI1ODYiIHk9Ijk4IiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxMTciIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5ub3JtYWxpemVfaW5kaWNhdG9yKCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxMzMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+w6JnZQovIDIwMCBhbnMgw5cgMTAwPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMTYyIiB3aWR0aD0iMjI2IiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iNTk4IiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5jcmVhdGVfZmFtaWx5X2luZGV4KOKAnFTigJ0pPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmZhbWlsbGVfdGVtcG9yZWw8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpkZSBUMSDDoCBUMzwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjI0MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMjYxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y29tcHV0ZV9nZW5lcmFsX2luZGV4KCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Rmlib25hY2NpCsK3IGNvbmZpYW5jZSDPhjwvdGV4dD48bGluZSB4MT0iMjYwIiB5MT0iNTUiIHgyPSIyODIiIHkyPSI1NSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHBhdGggZD0iTTI2MCAxMTEgSDI3MSBWMTMxIEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDE3NSBIMjcxIFYyMjMgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxwYXRoIGQ9Ik0yNjAgMjM5IEgyNzEgVjMxNSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAyOTUgSDI3MSBWMzkxIEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48bGluZSB4MT0iMzA2IiB5MT0iNzgiIHgyPSIzMDYiIHkyPSIxMDQiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSIzIDMiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSI5NCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+c2lub248L3RleHQ+PGxpbmUgeDE9IjMwNiIgeTE9IjE1NCIgeDI9IjMwNiIgeTI9IjE4MCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjE3MCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+c2lub248L3RleHQ+PGxpbmUgeDE9IjMwNiIgeTE9IjI2MiIgeDI9IjMwNiIgeTI9IjI4OCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjI3OCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+c2lub248L3RleHQ+PGxpbmUgeDE9IjMwNiIgeTE9IjMzOCIgeDI9IjMwNiIgeTI9IjM2NCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIzMTIiIHk9IjM1NCIgZm9udC1zaXplPSIxMCIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNTUiIHRleHQtYW5jaG9yPSJzdGFydCI+c2lub248L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjU1IiB4Mj0iNTY2IiB5Mj0iNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjEzMSIgeDI9IjU2NiIgeTI9IjEzMSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMjIzIiB4Mj0iNTY2IiB5Mj0iMjIzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIzMTUiIHgyPSI1NjYiIHkyPSIzMTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjM5MSIgeDI9IjU2NiIgeTI9IjM5MSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNTUiIHgyPSI1NjYiIHkyPSIzOTEiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjU1IiB4Mj0iNTgwIiB5Mj0iNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE0MiIgeDI9IjY5OSIgeTI9IjE1NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIyMiIgeDI9IjY5OSIgeTI9IjIzNiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjQzOCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TOKAmXVuaXTDqQplc3QgbOKAmWFubsOpZSA6IG5vcm1hbGlzw6llIHN1ciB1bmUgYm9ybmUgZGUgMjAwIGFucyBkZXB1aXMgbGEgMC4xOTcuMCwKcGx1cyBwYXIgw6ljcsOqdGFnZSDDoCAxMDAuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSI0NTQiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlVuZQptZXN1cmUgcGFzc2UgYXZhbnQgdW5lIGVzdGltYXRpb24gOyBzYW5zIGF1Y3VuZSBzb3VyY2UsIFQxIHZhdXQgTkEgKDUwCmFucyBlbiBkdXIganVzcXXigJnDoCBsYSAwLjIxMS4wKS48L3RleHQ+PHRleHQgeD0iMTAiIHk9IjQ3MCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+TGUKY2hlbWluIE5EVkkgY29udmVydGl0IGRlIGxhIHZlcmRldXIgZW4gYW5uw6llcyA6IHVuIHBldXBsZW1lbnQgdmVydCBldApqZXVuZSB5IHBhcmHDrnQgdmlldXguPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSI0ODYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkzigJnDomdlClRGViBlc3QgdW5lIGNvbnN0YW50ZSBwYXIgdHlwZSA6IHRvdXRlcyBsZXMgZnV0YWllcyBmZXVpbGx1ZXMgZmVybcOpZXMKb250IGxlIG3Dqm1lIMOiZ2UuPC90ZXh0Pjwvc3ZnPg==)

Cinq issues pour une colonne en années. La borne de 200 ans distingue
une futaie de 110 ans d’une de 250 ans ; une unité qu’aucune source ne
date reste NA au lieu de recevoir un âge fabriqué.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction T1 | `R/indicators-temporal.R:74-225` |
| Âge typologique | `.estimate_age_tfv()` |
| Déclaration « natif 0-100 » | `R/normalization.R`, `.NORMALIZE_NATIVE_0_100` |
| Forêt ancienne (source connexe) | [`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md), spec 031 — consommée par **N2** |
