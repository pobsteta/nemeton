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

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction P1 | `R/indicators-productive.R:102-330` |
| Tarifs IFN | `inst/extdata/ifn_volume_equations.csv` |
| Inventaire synthétique | [`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md), [`estimate_synthetic_inventory()`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md) |
| Correctif des exposants | `NEWS.md` 0.169.0, `specs/040-volume-mobilisable-desserte/` |
| Fiche partageant le tarif | [`vignette("fiche-c1-biomasse_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/fiche-c1-biomasse_fr.md) |
