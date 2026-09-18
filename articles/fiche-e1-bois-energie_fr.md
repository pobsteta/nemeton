# Fiche indicateur E1 - Potentiel bois-energie

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `E1` |
| Nom long / colonne | `indicateur_e1_bois_energie` |
| Famille | **E — Énergie & Climat** (avec E2) |
| Grandeur mesurée | Gisement annuel de bois-énergie mobilisable |
| Unité brute | **tonnes de matière sèche / ha / an** |
| Sens | Haut = favorable |
| Normalisation | `ref_max = 1,32` → `score = min(100, t / 1,32 × 100)` — aligné sur P1 |
| Fonction | [`indicateur_e1_bois_energie()`](https://pobsteta.github.io/nemeton/reference/indicateur_e1_bois_energie.md) — `R/indicators-energy.R:32` |
| Colonnes annexes | `E1_residues`, `E1_coppice` |

## 2. Le calcul

    recolte_annuelle = V_sur_pied x harvest_rate                 defaut 2 % / an
    remanents        = recolte_annuelle x residue_fraction       defaut 30 %
    t_MS_remanents   = remanents x rho / 1000 x 0,5              MS = 50 % du poids frais
    t_MS_taillis     = fraction_taillis x 2                      2 t MS / ha / an, en dur
    E1               = t_MS_remanents + t_MS_taillis

`rho` vient de `wood_density.csv` (défaut **550 kg/m³** si l’essence est
inconnue). Le volume sur pied est **P1**, calculé à la volée si la
colonne manque — E1 hérite donc de toutes les propriétés de P1,
correctif 0.169.0 compris.

**Exemples chiffrés** (hêtre, ρ = 680) :

| V sur pied | Récolte 2 % | Rémanents 30 % | E1            | Score    |
|------------|-------------|----------------|---------------|----------|
| 200 m³/ha  | 4,0         | 1,2 m³/ha      | **0,41 t MS** | **30,9** |
| 120 m³/ha  | 2,4         | 0,72 m³/ha     | **0,24 t MS** | **18,5** |
| 60 m³/ha   | 1,2         | 0,36 m³/ha     | **0,12 t MS** | **9,3**  |

Les scores étaient respectivement **100,0 (saturé)**, 81,6 et 40,8 avant
la 0.197.0 : le plafond de 0,3 t MS/ha/an mettait une futaie de 200
m³/ha au maximum de l’axe.

## 3. Le calcul par niveau NDP

E1 hérite du NDP de **P1** : sans hauteur, le volume repose sur la
relation `H = 1,3 + 0,65 × D` ; avec un CHM, il repose sur une hauteur
réelle. E1 n’a pas de source propre.

## 4. Trois pièges

1.  **Le plafond saturait au milieu du domaine forestier — corrigé en
    0.197.0.** `ref_max` valait **0,3 t MS/ha/an**, atteint dès ~182
    m³/ha à la densité par défaut : un peuplement ordinaire (P1 annonce
    100-400 m³/ha comme typique) était donc à 100, et E1 ne discriminait
    que les peuplements pauvres.

    Le défaut était plus profond qu’un plafond mal placé. **E2 est le
    même nombre que E1** — il s’en déduit par
    `E1 × 4500 kWh × 0,222 kgCO₂/kWh ÷ 1000` = `E1 × 0,999` — et portait
    pourtant une borne de **0,75**. Les deux axes de la famille Énergie
    étaient en désaccord sur ce que vaut « plein score » à partir d’une
    donnée identique. Et comme les deux dérivent linéairement du volume,
    donc de **P1** (`ref_max = 800`), trois colonnes proportionnelles
    saturaient à **182, 455 et 800 m³/ha** : à 182 m³/ha, la même
    parcelle était à 100/100 en bois-énergie et à 22,8/100 en volume.

    **Correctif (spec 048 §11)** : `ref_max(E1) = ref_max(E2) = 1,32 t`,
    soit exactement E1 au plafond de P1 (800 m³/ha, ρ = 550). Les trois
    axes notent désormais le même peuplement à l’identique, à 0,1 % près
    — le résidu du facteur 0,999.

    **Limite assumée** : une borne fixe ne peut pas suivre la densité de
    l’essence (E1(800 m³/ha) vaut 0,96 pour ρ = 400 et 1,68 pour ρ =
    700). Elle est ancrée sur la densité par défaut.

2.  **Trois constantes portent tout le résultat** :
    `harvest_rate = 2 %`, `residue_fraction = 30 %`, et le taillis à **2
    t MS/ha/an en dur**. Aucune n’est calibrée localement ; les deux
    premières sont des arguments, la troisième non.

3.  **La récolte de 2 % du volume sur pied est une hypothèse de gestion,
    pas une mesure.** Elle suppose un prélèvement régulier. Une forêt
    non gérée depuis trente ans y apparaît avec le même gisement annuel
    qu’une futaie en production.

## 5. Aval

    indicateur_e1_bois_energie()  ->  colonnes E1, E1_residues, E1_coppice
          |
          +- normalize_indicator()     -> min(100, t / 1,32 x 100)
          +- create_family_index("E")  -> famille_energie = moy(E1, E2)
          +- alimente E2 (fuelwood_field)

## 6. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBFMSA6IGxlIHZvbHVtZSBzdXIgcGllZCBQMSBlc3QgcHJlbGV2ZSBhIDIgJSBwYXIgYW4sIDMwICUgZGUgY2V0dGUgcmVjb2x0ZSBwYXJ0IGVuIHJlbWFuZW50cywgY29udmVydGlzIGVuIG1hdGllcmUgc2VjaGUgcGFyIGxhIGRlbnNpdGUgZGUgbCYjMzk7ZXNzZW5jZSwgcHVpcyBhZGRpdGlvbm5lcyBkJiMzOTt1biBmb3JmYWl0IHRhaWxsaXMgZGUgMiB0b25uZXMgcGFyIGhlY3RhcmUgZXQgcGFyIGFuIDsgdHJvaXMgY29uc3RhbnRlcyBwb3J0ZW50IGRvbmMgdG91dCBsZSByZXN1bHRhdC4iPjxkZWZzPjxtYXJrZXIgaWQ9ImZkIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI2IiBtYXJrZXJoZWlnaHQ9IjYiIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNMCwwIEwxMCw1IEwwLDEwIHoiIGZpbGw9ImN1cnJlbnRDb2xvciIgLz48L21hcmtlcj48L2RlZnM+PGcgZmlsbD0iY3VycmVudENvbG9yIiBmb250LXNpemU9IjEwIiBsZXR0ZXItc3BhY2luZz0iMS4zIiBvcGFjaXR5PSIuNTUiPjx0ZXh0IHg9IjEwIiB5PSIxNiI+RU5UUsOJRVM8L3RleHQ+PHRleHQgeD0iMjkwIiB5PSIxNiI+Q0FMQ1VMIOKAlCDDiVRBUEVTClNVQ0NFU1NJVkVTPC90ZXh0Pjx0ZXh0IHg9IjU4OCIgeT0iMTYiPkFWQUw8L3RleHQ+PC9nPjxyZWN0IHg9IjgiIHk9IjM0IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+UDEK4oCUIHZvbHVtZSBzdXIgcGllZDwvdGV4dD48dGV4dCB4PSIyMCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5jb2xvbm5lLApvdSBjYWxjdWzDqSDDoCBsYSB2b2zDqWU8L3RleHQ+PHRleHQgeD0iMjAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+aMOpcml0ZQpkZXMgcHJvcHJpw6l0w6lzIGRlIFAxPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjEwNiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj53b29kX2RlbnNpdHkuY3N2CuKAlCDPgTwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTQxIiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+NTUwCmtnL23CsyBzaSBlc3NlbmNlIGluY29ubnVlPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE2MiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjIwIiB5PSIxODEiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5GcmFjdGlvbgpkZSB0YWlsbGlzPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5mb3JmYWl0CjIgdCBNUy9oYS9hbiwgZW4gZHVyPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMzQiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+UsOpY29sdGUKYW5udWVsbGU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5WCsOXIGhhcnZlc3RfcmF0ZTwvdGV4dD48dGV4dCB4PSIzMDAiIHk9Ijg1IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPmTDqWZhdXQKMiAlIC8gYW48L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIxMjYiIHdpZHRoPSIyNjIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjE0NSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlLDqW1hbmVudHMKZW4gbWF0acOocmUgc8OoY2hlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnLDqWNvbHRlCsOXIDMwICU8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIxNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+w5cKz4EvMTAwMCDDlyAwLDU8L3RleHQ+PHJlY3QgeD0iMjg4IiB5PSIyMTgiIHdpZHRoPSIyNjIiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIzMDAiIHk9IjIzNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlNvbW1lCmRlcyBkZXV4IGdpc2VtZW50czwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjI1MyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5FMQo9IHLDqW1hbmVudHMgKyB0YWlsbGlzPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iMzQiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSIjMkM2QjYwMEYiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii45NSIgLz48dGV4dCB4PSI1OTgiIHk9IjUzIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyQzZCNjAiPmluZGljYXRldXJfZTFfYm9pc19lbmVyZ2llPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iNjkiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+dApNUyAvIGhhIC8gYW48L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSI5OCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMTE3IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+bm9ybWFsaXplX2luZGljYXRvcigpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMTMzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1pbigxMDAsCnQgLyAxLDMyIMOXIDEwMCk8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcReKAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9lbmVyZ2llPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjEzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm1veWVubmUKZGUgRTEgZXQgRTI8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIyNDIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjI2MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNvbXB1dGVfZ2VuZXJhbF9pbmRleCgpPC90ZXh0Pjx0ZXh0IHg9IjU5OCIgeT0iMjc3IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPkZpYm9uYWNjaQrCtyBjb25maWFuY2Ugz4Y8L3RleHQ+PGxpbmUgeDE9IjI2MCIgeTE9IjYzIiB4Mj0iMjgyIiB5Mj0iNjMiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxwYXRoIGQ9Ik0yNjAgMTI3IEgyNzEgVjE1NSBIMjgyIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiIC8+PHBhdGggZD0iTTI2MCAxODMgSDI3MSBWMjM5IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48bGluZSB4MT0iMzA2IiB5MT0iOTQiIHgyPSIzMDYiIHkyPSIxMjAiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMTEwIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSIzMDYiIHkxPSIxODYiIHgyPSIzMDYiIHkyPSIyMTIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjx0ZXh0IHg9IjMxMiIgeT0iMjAyIiBmb250LXNpemU9IjEwIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii41NSIgdGV4dC1hbmNob3I9InN0YXJ0Ij5wdWlzPC90ZXh0PjxsaW5lIHgxPSI1NTAiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjYzIiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NTAiIHkxPSIxNTUiIHgyPSI1NjYiIHkyPSIxNTUiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjIzOSIgeDI9IjU2NiIgeTI9IjIzOSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1NjYiIHkyPSIyMzkiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU2NiIgeTE9IjYzIiB4Mj0iNTgwIiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iNzgiIHgyPSI2OTkiIHkyPSI5MiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjE0MiIgeDI9IjY5OSIgeTI9IjE1NiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PGxpbmUgeDE9IjY5OSIgeTE9IjIyMiIgeDI9IjY5OSIgeTI9IjIzNiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMTAiIHk9IjMxMCIgZm9udC1zaXplPSIxMC41IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii42MiI+Qm9ybmUKYWxpZ27DqWUgc3VyIFAxICgxLDMyIHQgTVMvaGEvYW4gPSBFMSDDoCA4MDAgbcKzL2hhKSA6IEUxLCBFMiBldCBQMSBub3RlbnQKbGUgbcOqbWUgcGV1cGxlbWVudCBwYXJlaWwuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlRyb2lzCmNvbnN0YW50ZXMgcG9ydGVudCBsZSByw6lzdWx0YXQg4oCUIHRhdXggZGUgcsOpY29sdGUgMiAlLCBmcmFjdGlvbiByw6ltYW5lbnRzCjMwICUsIGZvcmZhaXQgdGFpbGxpcyAyIHQuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkxhCnLDqWNvbHRlIGRlIDIgJSBlc3QgdW5lIGh5cG90aMOoc2UgZGUgZ2VzdGlvbiwgcGFzIHVuZSBtZXN1cmUgZGUKcHLDqWzDqHZlbWVudCByw6llbC48L3RleHQ+PC9zdmc+)

Une chaîne de coefficients appliquée à P1. E1 ne mesure pas un gisement
observé : il décrit ce que produirait une gestion conventionnelle
appliquée uniformément à toutes les unités.

## 7. Références internes

| Sujet | Fichier |
|----|----|
| Fonction E1 | `R/indicators-energy.R:32-128` |
| Densités du bois | `inst/extdata/wood_density.csv` |
| Volume amont | [`vignette("fiche-p1-volume_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-p1-volume_fr.md) |
