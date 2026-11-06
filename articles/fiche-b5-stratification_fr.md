# Fiche indicateur B5 - Stratification verticale

> **Document de référence** — Néméton (package cœur), 2026-11-06. Spec
> 067 (chantier C, première étape, sans ForPT). Fonction
> **expérimentale** : elle peut changer à toute version.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `B5` |
| Nom long / colonne | `indicateur_b5_stratification` |
| Famille | **B — Biodiversité** |
| Grandeur mesurée | Équilibre de la répartition des retours LiDAR entre cinq strates de hauteur |
| Unité brute | **score 0–100** (100 = répartition égale entre les strates) |
| Sens | Haut = favorable (peuplement stratifié) |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_b5_stratification()`](https://pobsteta.github.io/nemeton/reference/indicateur_b5_stratification.md) — `R/indicateur_b5_stratification.R` |
| Entrées | un **nuage de points LiDAR** : table `X, Y, Z`, objet `LAS` de lidR, ou dalles `.laz` |
| Conditionnel | oui : sans nuage, `NA` et `b5_status = "skipped_no_lidar"` |

Colonnes rendues : `B5`, `b5_status`, `b5_profil` (`"points"` ou
`"densite_foliaire"`), `b5_points` (retours dans l’UGF, sol compris),
`b5_densite` (retours par m²), `b5_s1` à `b5_s5` (part de chaque strate,
de la plus basse à la plus haute).

## 2. Le calcul

[`compute_dtm_chm_from_laz()`](https://pobsteta.github.io/nemeton/reference/compute_dtm_chm_from_laz.md)
réduit le LiDAR HD à un MNT et un MNH : tout ce qui est sous la canopée
est perdu. B2 lit la surface de la canopée vue du ciel (coefficient de
variation du MNH) ; B5 lit le nuage lui-même.

1.  **Le nuage.** Des hauteurs au-dessus du sol. Les dalles brutes de
    l’IGN portent des altitudes : `normaliser = TRUE` les ramène
    au-dessus d’un TIN des retours sol (classe 2), dalle par dalle, avec
    lidR. Un nuage dont la médiane de `Z` dépasse 60 m est refusé plutôt
    que lu comme des hauteurs.
2.  **Le tri.** Avec une colonne `Classification`, seuls les retours non
    classés, sol, végétation (basse, moyenne, haute) et eau sont gardés
    (classes 1 à 5 et 9 du LiDAR HD) ; les bâtiments, le bruit, les
    ponts et les classes IGN 64 à 67 sont écartés. Les retours au-dessus
    de 60 m ou sous −1 m sont du bruit.
3.  **L’affectation.** Une grille de 1 m sur l’emprise des UGF : un
    retour appartient à l’UGF qui contient le centre de sa cellule.
4.  **Les comptes.** Sous 0,5 m, le retour est du sol. Au-dessus, il
    tombe dans l’une des strates 0-2, 2-5, 5-10, 10-20 et \> 20 m (la
    première commence en fait à 0,5 m).
5.  **Le score.** Avec `p_k` la part de la strate `k`,
    `B5 = 100 × (−Σ p_k ln p_k) / ln 5` : l’entropie de Shannon divisée
    par son maximum, c’est-à-dire l’équitabilité du profil vertical.
    C’est la forme LiDAR de la *foliage height diversity* de MacArthur
    et MacArthur (1961). Une UGF sans végétation au-dessus de 0,5 m vaut
    0.

**Deux profils.** Par défaut (`profil = "points"`, décision D-3 de la
spec 067), la part d’une strate est sa part des retours de végétation.
Avec `profil = "densite_foliaire"`, c’est sa part du feuillage estimé
par la fraction de trouée (MacArthur et Horn 1969) : si `P(h)` est la
part des retours sous la hauteur `h`, le feuillage de la strate `[a, b)`
est proportionnel à `ln(P(b) / P(a))`. Ce profil corrige en partie
l’occultation des strates basses par les strates hautes : sur les 96
placettes du Vercors, la part moyenne de la strate 0-2 m passe de 2,6 %
à 6,3 %.

**Seuils de statut.** Aucun retour dans l’UGF : `skipped_no_coverage`.
Moins de 100 retours, sol compris : `skipped_low_density`.

## 3. Le calcul par niveau NDP

| NDP | Source | Ce qui change |
|----|----|----|
| **0** | — | pas de nuage : `NA`, famille B inchangée |
| **1** | LiDAR HD IGN (≈ 10 retours/m²) | B5 calculé ; sous-étages des peuplements fermés sous-échantillonnés |
| **2** | \+ LiDAR drone | densité bien plus forte, sous-étages mieux vus |
| **3–4** | \+ scanner terrestre | profil complet ; B5 n’est plus limité par l’occultation |

**Dimensionnement.**
[`simulate_density_sensitivity()`](https://pobsteta.github.io/nemeton/reference/simulate_density_sensitivity.md)
éclaircit le nuage vers des densités plus faibles (par impulsion quand
le nuage porte `gpstime`, sinon retour par retour), recalcule B5
plusieurs fois par densité et mesure l’écart à la valeur de pleine
densité. Si B5 ne bouge plus quand on retire la moitié des retours, une
campagne plus dense a peu de chances de changer le diagnostic
(`conclusion = "densite_suffisante"`) ; s’il bouge, la densité actuelle
est une limite (`"densite_limite"`) et un vol drone mérite d’être
essayé. C’est une lecture de **convergence** : un éclaircissement ne
montre pas ce qu’un nuage plus dense verrait, seulement si le score a
cessé de bouger.

Sur les 96 placettes du Vercors (16 retours/m², éclaircie par impulsion,
cinq répétitions, profil `"points"`) :

| Densité simulée (retours/m²) | Écart médian | Écart au 90ᵉ centile | Part stable (≤ 5 points) |
|----|----|----|----|
| 10 | 0,3 | 0,8 | 100 % |
| 5 | 0,5 | 1,5 | 100 % |
| 2 | 1,0 | 2,6 | 99,8 % |
| 1 | 1,5 | 3,9 | 96,3 % |

B5 est stable jusqu’à 1 retour/m² sur des placettes de 700 m² : la
**précision** de B5 ne demande pas de drone. Son **biais** est une autre
question : un éclaircissement garde la même occultation, il ne dit rien
des sous-étages que le LiDAR aérien ne voit pas (piège n° 1). Le profil
`"densite_foliaire"` est un peu plus sensible (écart au 90ᵉ centile 4,2
à 1 retour/m²).

## 4. Quatre pièges

1.  **La densité.** À environ 10 retours par m², les sous-étages des
    peuplements fermés reçoivent peu d’impulsions : B5 y **sous-estime**
    la stratification. Le profil `"densite_foliaire"` en corrige une
    partie, pas tout.
2.  **La saison.** Un vol en feuilles et un vol hors feuilles ne donnent
    pas le même profil dans les feuillus. Deux B5 de dates différentes
    ne se comparent que si la saison des vols est la même.
3.  **L’équilibre, pas la hauteur.** B5 mesure si les retours se
    répartissent entre les strates : un fourré de 2 m à cheval sur deux
    strates peut avoir le même score qu’une futaie. Lire B5 avec la
    hauteur (MNH, B2).
4.  **Ce qui renvoie le signal.** Feuillage, branches et troncs comptent
    pareil. Séparer le bois de la feuille demandera ForPT (spec 067,
    D-3).

## 5. Confrontation au terrain

Sur les 96 placettes de 15 m de rayon du jeu `inst/extdata/aba.model/`
(Vercors, nuages normalisés, ≈ 14 retours/m² ; arbres de l’inventaire de
terrain mesurés en hauteur, d’état 1 dans le codage du jeu), avec les
corrélations de Spearman :

| B5 contre | `"points"` | `"densite_foliaire"` |
|----|----|----|
| coefficient de variation des hauteurs d’arbres | 0,55 | 0,62 |
| équitabilité des tiges entre les cinq strates | 0,33 | 0,32 |
| hauteur de l’arbre le plus haut | −0,07 | 0,06 |

B5 suit la variabilité des hauteurs mesurée au sol et ne dépend pas de
la hauteur du peuplement. L’inventaire compte des tiges, B5 des retours
: la broussaille et le feuillage, que B5 voit, n’y sont pas, ce qui
borne la concordance attendue. Ce n’est pas une validation de B5 comme
mesure de biodiversité, seulement de sa lecture de la structure. Calcul
des deux profils pour 2 millions de points : 14 s sur un cœur de CPU,
lecture des fichiers non comprise.

## 6. Aval

    indicateur_b5_stratification()  ->  colonne B5 (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("B")  -> famille_biodiversite (si B5 non NA)

Sans nuage, B5 vaut `NA` et la famille B est inchangée. Avec un nuage,
la famille B d’un projet recalculé compte un indicateur de plus. B2
reste.

## 7. Diagramme d’ensemble

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgODIwIDM2MCIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OmF1dG87bWF4LXdpZHRoOjEwMCUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iQ2hhaW5lIGRlIGNhbGN1bCBkZSBCNSA6IGxlcyByZXRvdXJzIGR1IG51YWdlIExpREFSIHNvbnQgYWZmZWN0ZXMgYXV4IFVHRiwgY29tcHRlcyBkYW5zIGNpbnEgc3RyYXRlcyBkZSBoYXV0ZXVyLCBldCBsJiMzOTtlcXVpdGFiaWxpdGUgZGUgbGV1ciByZXBhcnRpdGlvbiAoZW50cm9waWUgZGUgU2hhbm5vbiBub3JtYWxpc2VlKSBkb25uZSBsZSBzY29yZSA7IHNhbnMgbnVhZ2UsIG91IGF2ZWMgdHJvcCBwZXUgZGUgcmV0b3VycywgTkEgZXQgdW4gc3RhdHV0LiI+PGRlZnM+PG1hcmtlciBpZD0iZmQiIHZpZXdib3g9IjAgMCAxMCAxMCIgcmVmeD0iOSIgcmVmeT0iNSIgbWFya2Vyd2lkdGg9IjYiIG1hcmtlcmhlaWdodD0iNiIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPjxwYXRoIGQ9Ik0wLDAgTDEwLDUgTDAsMTAgeiIgZmlsbD0iY3VycmVudENvbG9yIiAvPjwvbWFya2VyPjwvZGVmcz48ZyBmaWxsPSJjdXJyZW50Q29sb3IiIGZvbnQtc2l6ZT0iMTAiIGxldHRlci1zcGFjaW5nPSIxLjMiIG9wYWNpdHk9Ii41NSI+PHRleHQgeD0iMTAiIHk9IjE2Ij5FTlRSw4lFUzwvdGV4dD48dGV4dCB4PSIyOTAiIHk9IjE2Ij5DQUxDVUwg4oCUIMOJVEFQRVMKU1VDQ0VTU0lWRVM8L3RleHQ+PHRleHQgeD0iNTg4IiB5PSIxNiI+QVZBTDwvdGV4dD48L2c+PHJlY3QgeD0iOCIgeT0iMzQiIHdpZHRoPSIyNTIiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSIyMCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iY3VycmVudENvbG9yIj5OdWFnZQpMaURBUiBIRCBub3JtYWxpc8OpPC90ZXh0Pjx0ZXh0IHg9IjIwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnRhYmxlClgsIFksIFosIG9iamV0IExBUzwvdGV4dD48dGV4dCB4PSIyMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5vdQpkYWxsZXMgLmxheiAobGlkUik8L3RleHQ+PHJlY3QgeD0iOCIgeT0iMTA2IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjQyIiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMjAiIHk9IjEyNSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkRhbGxlcwpicnV0ZXMgKGFsdGl0dWRlcyk8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjE0MSIgZm9udC1zaXplPSIxMSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPm5vcm1hbGlzZXIKPSBUUlVFLCBUSU4gZHUgc29sPC90ZXh0PjxyZWN0IHg9IjgiIHk9IjE2MiIgd2lkdGg9IjI1MiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIC8+PHRleHQgeD0iMjAiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPlBhcwpkZSBudWFnZSwgJmx0OyAxMDAgcmV0b3VyczwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTk3IiBmb250LXNpemU9IjExIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+QjUKPSBOQSArIHN0YXR1dDwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjM0IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIC8+PHRleHQgeD0iMzAwIiB5PSI1MyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPkFmZmVjdGF0aW9uCmF1eCBVR0Y8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSI2OSIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij5ncmlsbGUKZGUgMSBtPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iODUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Y2xhc3NlcwoxLTUgZXQgOTwvdGV4dD48cmVjdCB4PSIyODgiIHk9IjEyNiIgd2lkdGg9IjI2MiIgaGVpZ2h0PSI1OCIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTQ1IiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Q29tcHRlcwpwYXIgc3RyYXRlPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMTYxIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNvbAombHQ7IDAsNSBtLCBwdWlzIDAtMiwgMi01LDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE3NyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij41LTEwLAoxMC0yMCwgJmd0OyAyMCBtPC90ZXh0PjxyZWN0IHg9IjI4OCIgeT0iMjE4IiB3aWR0aD0iMjYyIiBoZWlnaHQ9IjU4IiByeD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgLz48dGV4dCB4PSIzMDAiIHk9IjIzNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPsOJcXVpdGFiaWxpdMOpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjUzIiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPjEwMArDlyBIIC8gbG9nKDUpPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPuKAnGRlbnNpdGVfZm9saWFpcmXigJ0KOiBlbiBvcHRpb248L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIzNCIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9IiMyQzZCNjAwRiIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjk1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iNTMiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJDNkI2MCI+aW5kaWNhdGV1cl9iNV9zdHJhdGlmaWNhdGlvbjwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjY5IiBmb250LXNpemU9IjExIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLFNGTW9uby1SZWd1bGFyLE1lbmxvLG1vbm9zcGFjZSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNzgiPnNjb3JlCjDigJMxMDAsIG5hdGlmPC90ZXh0PjxyZWN0IHg9IjU4NiIgeT0iOTgiIHdpZHRoPSIyMjYiIGhlaWdodD0iNDIiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjExNyIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPm5vcm1hbGl6ZV9pbmRpY2F0b3IoKTwvdGV4dD48dGV4dCB4PSI1OTgiIHk9IjEzMyIgZm9udC1zaXplPSIxMSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSxTRk1vbm8tUmVndWxhcixNZW5sbyxtb25vc3BhY2UiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjc4Ij7DqWNyw6p0YWdlCm5hdGlmIDDigJMxMDA8L3RleHQ+PHJlY3QgeD0iNTg2IiB5PSIxNjIiIHdpZHRoPSIyMjYiIGhlaWdodD0iNTgiIHJ4PSIzIiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgLz48dGV4dCB4PSI1OTgiIHk9IjE4MSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSJjdXJyZW50Q29sb3IiPmNyZWF0ZV9mYW1pbHlfaW5kZXgo4oCcQuKAnSk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIxOTciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+ZmFtaWxsZV9iaW9kaXZlcnNpdGU8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyMTMiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+bW95ZW5uZQpkZSBCMSDDoCBCNTwvdGV4dD48cmVjdCB4PSI1ODYiIHk9IjI0MiIgd2lkdGg9IjIyNiIgaGVpZ2h0PSI0MiIgcng9IjMiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiAvPjx0ZXh0IHg9IjU5OCIgeT0iMjYxIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9ImN1cnJlbnRDb2xvciI+Y29tcHV0ZV9nZW5lcmFsX2luZGV4KCk8L3RleHQ+PHRleHQgeD0iNTk4IiB5PSIyNzciIGZvbnQtc2l6ZT0iMTEiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsU0ZNb25vLVJlZ3VsYXIsTWVubG8sbW9ub3NwYWNlIiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9Ii43OCI+Rmlib25hY2NpCsK3IGNvbmZpYW5jZSDPhjwvdGV4dD48bGluZSB4MT0iMjYwIiB5MT0iNjMiIHgyPSIyODIiIHkyPSI2MyIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHBhdGggZD0iTTI2MCAxMjcgSDI3MSBWMTU1IEgyODIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSIgLz48cGF0aCBkPSJNMjYwIDE4MyBIMjcxIFYyNDcgSDI4MiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIiAvPjxsaW5lIHgxPSIzMDYiIHkxPSI5NCIgeDI9IjMwNiIgeTI9IjEyMCIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIxMTAiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnB1aXM8L3RleHQ+PGxpbmUgeDE9IjMwNiIgeTE9IjE4NiIgeDI9IjMwNiIgeTI9IjIxMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNzUiIG1hcmtlci1lbmQ9InVybCgjZmQpIj48L2xpbmU+PHRleHQgeD0iMzEyIiB5PSIyMDIiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjU1IiB0ZXh0LWFuY2hvcj0ic3RhcnQiPnB1aXM8L3RleHQ+PGxpbmUgeDE9IjU1MCIgeTE9IjYzIiB4Mj0iNTY2IiB5Mj0iNjMiIHN0cm9rZT0iIzJDNkI2MCIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii42Ij48L2xpbmU+PGxpbmUgeDE9IjU1MCIgeTE9IjE1NSIgeDI9IjU2NiIgeTI9IjE1NSIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTUwIiB5MT0iMjQ3IiB4Mj0iNTY2IiB5Mj0iMjQ3IiBzdHJva2U9IiMyQzZCNjAiIHN0cm9rZS13aWR0aD0iMS4yIiBvcGFjaXR5PSIuNiI+PC9saW5lPjxsaW5lIHgxPSI1NjYiIHkxPSI2MyIgeDI9IjU2NiIgeTI9IjI0NyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjYiPjwvbGluZT48bGluZSB4MT0iNTY2IiB5MT0iNjMiIHgyPSI1ODAiIHkyPSI2MyIgc3Ryb2tlPSIjMkM2QjYwIiBzdHJva2Utd2lkdGg9IjEuMiIgb3BhY2l0eT0iLjc1IiBtYXJrZXItZW5kPSJ1cmwoI2ZkKSI+PC9saW5lPjxsaW5lIHgxPSI2OTkiIHkxPSI3OCIgeDI9IjY5OSIgeTI9IjkyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMTQyIiB4Mj0iNjk5IiB5Mj0iMTU2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48bGluZSB4MT0iNjk5IiB5MT0iMjIyIiB4Mj0iNjk5IiB5Mj0iMjM2IiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIxLjIiIG9wYWNpdHk9Ii43NSIgbWFya2VyLWVuZD0idXJsKCNmZCkiPjwvbGluZT48dGV4dCB4PSIxMCIgeT0iMzEwIiBmb250LXNpemU9IjEwLjUiIGZpbGw9ImN1cnJlbnRDb2xvciIgb3BhY2l0eT0iLjYyIj7DgAoxMCByZXRvdXJzIHBhciBtwrIsIGxlcyBzb3VzLcOpdGFnZXMgZGVzIHBldXBsZW1lbnRzIGZlcm3DqXMgc29udApzb3VzLcOpY2hhbnRpbGxvbm7DqXMgOiBCNSB5IGVzdCBzb3VzLWVzdGltw6kuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzMjYiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPlVuCnZvbCBlbiBmZXVpbGxlcyBldCB1biB2b2wgaG9ycyBmZXVpbGxlcyBuZSBkb25uZW50IHBhcyBsZSBtw6ptZQpwcm9maWwuPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSIzNDIiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iY3VycmVudENvbG9yIiBvcGFjaXR5PSIuNjIiPkI1Cm1lc3VyZSBs4oCZw6lxdWlsaWJyZSBkdSBwcm9maWwsIHBhcyBsYSBoYXV0ZXVyIDogdW4gZm91cnLDqSBkZSAyIG0gcGV1dApzY29yZXIgY29tbWUgdW5lIGZ1dGFpZS48L3RleHQ+PC9zdmc+)

Un profil vertical lu dans le nuage, résumé par son équitabilité. Le
score dit si les retours se répartissent entre les strates, pas ce qui
les renvoie : feuillage, branches et troncs comptent pareil.

## 8. Références internes

| Sujet | Fichier |
|----|----|
| Fonction B5 | `R/indicateur_b5_stratification.R` |
| Dimensionnement | `R/simulate_density_sensitivity.R` |
| Spécification | `specs/067-forpt-lidar-latent/spec.md` |
| MNT et MNH depuis le nuage | [`compute_dtm_chm_from_laz()`](https://pobsteta.github.io/nemeton/reference/compute_dtm_chm_from_laz.md) |
| Structure vue du ciel | fiche B2 |

MacArthur R. H., MacArthur J. W. (1961). *On bird species diversity.*
Ecology 42(3), 594-598.

MacArthur R. H., Horn H. S. (1969). *Foliage profile by vertical
measurements.* Ecology 50(5), 802-804.
