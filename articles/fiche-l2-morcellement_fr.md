# Fiche indicateur L2 - Morcellement du paysage

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `L2` |
| Nom long / colonne | `indicateur_l2_morcellement` |
| Famille | **L — Paysage** |
| Grandeur mesurée | Continuité du couvert forestier autour de l’unité |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable (peu morcelé) |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_l2_morcellement()`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_morcellement.md) — `R/indicators-families.R:1865` |
| Ancien nom | [`indicateur_l2_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_fragmentation.md) — alias conservé (spec 045) |

## 2. Deux chemins

| Ordre | Chemin | Condition | Formule |
|----|----|----|----|
| 1 | **Métriques de paysage** | `landscapemetrics` installé **et** couche `landcover` | `(COHESION + AI) / 2` |
| 2 | **Indice de forme** | sinon, ou si le chemin 1 échoue | `min(100, 100 / SI)` avec `SI = P / (2√(πA))` |

Chemin 1 : un masque forêt binaire est construit sur l’union des unités
tamponnée de **1 000 m**, puis `calculate_lsm()` en tire la cohésion et
l’indice d’agrégation, tous deux déjà sur 0–100.

**Exemples chiffrés** :

| Situation                        | Chemin    | Mesure             | L2       |
|----------------------------------|-----------|--------------------|----------|
| Massif continu                   | métriques | COHESION 97, AI 91 | **94,0** |
| Mosaïque bois/cultures           | métriques | COHESION 72, AI 60 | **66,0** |
| Parcelle compacte, sans couche   | forme     | SI = 1,15          | **87,0** |
| Parcelle en lanière, sans couche | forme     | SI = 2,60          | **38,5** |

## 3. Le calcul par niveau NDP

| NDP     | Ce qui change                                              |
|---------|------------------------------------------------------------|
| **0**   | OSO 30 m — cohésion et agrégation à la maille du satellite |
| **1**   | BD TOPO / BD Forêt : contours de massif justes             |
| **2**   | ortho drone : haies et bosquets comptent enfin             |
| **3–4** | emprise vérifiée au sol                                    |

## 4. Trois pièges

1.  **Le chemin 1 rend la même valeur pour toutes les unités du
    projet.** La cohésion et l’agrégation sont calculées **une fois**,
    sur le paysage entier tamponné, puis recopiées :
    `return(rep(l2_score, nrow(units)))`. L2 ne discrimine donc rien à
    l’intérieur d’un projet quand `landscapemetrics` est disponible —
    c’est une **propriété du paysage**, pas de la parcelle. Un radar où
    toutes les unités partagent le même L2 est le comportement normal.
2.  **Les deux chemins mesurent des choses différentes, et basculent
    silencieusement.** Le chemin 2 (indice de forme) mesure la
    **compacité de l’UGF** ; le chemin 1 mesure la **continuité du
    massif**. Le passage de l’un à l’autre dépend uniquement de la
    présence de `landscapemetrics` (un `Suggests`) et d’une couche
    d’occupation du sol. Un simple `cli_alert_warning` le signale.
    **Deux exécutions sur deux postes peuvent donc mesurer deux
    grandeurs différentes sous le même nom de colonne.**
3.  **Le nom a changé** (spec 045) :
    [`indicateur_l2_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_fragmentation.md)
    reste un alias, et le slug historique reste reconnu par la
    normalisation. Attention au sens : « fragmentation » suggère « haut
    = fragmenté », alors qu’un L2 élevé signifie **peu** morcelé. C’est
    précisément la raison du renommage.

## 5. Aval

    indicateur_l2_morcellement()  ->  colonne indicateur_l2_morcellement
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("L")  -> famille_paysage = moy(L1, L2, L3)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction L2 | `R/indicators-families.R:1865-1960` |
| Alias historique | [`indicateur_l2_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_fragmentation.md) — `:1962` |
| Migration des colonnes | [`migrer_colonnes_l()`](https://pobsteta.github.io/nemeton/reference/migrer_colonnes_l.md) — `R/migration-famille-l.R` |
| Renommage | `specs/045-renommage-famille-L/` |
