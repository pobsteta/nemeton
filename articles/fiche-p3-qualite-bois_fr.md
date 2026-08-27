# Fiche indicateur P3 - Qualite du bois

> **Document de référence** — Néméton (package cœur), 2026-08-27.

------------------------------------------------------------------------

## 1. Carte d’identité

| Élément | Valeur |
|----|----|
| Code | `P3` |
| Nom long / colonne | `indicateur_p3_qualite_bois` |
| Famille | **P — Production & Économie** |
| Grandeur mesurée | Aptitude du peuplement à produire du bois d’œuvre |
| Unité brute | **score 0–100** |
| Sens | Haut = favorable |
| Normalisation | **native 0–100**, écrêtage |
| Fonction | [`indicateur_p3_qualite_bois()`](https://pobsteta.github.io/nemeton/reference/indicateur_p3_qualite_bois.md) — `R/indicators-productive.R:503` |

## 2. Le calcul

### Composante diamètre

Deux seuils par grand type d’essence :

| Type                                 | Seuil bois d’œuvre | Seuil trituration |
|--------------------------------------|--------------------|-------------------|
| Résineux (codes `PI*`, `PM*`, `PL*`) | **30 cm**          | **15 cm**         |
| Feuillus                             | **40 cm**          | **20 cm**         |
| Essence inconnue                     | 35 cm              | 18 cm             |

    D >= seuil_oeuvre                 -> 100
    seuil_trituration <= D < oeuvre   -> 50 + 50 x (D - trituration) / (oeuvre - trituration)
    D < seuil_trituration             -> 50 x D / trituration

### Composante forme

Un `form_score_field` optionnel permet d’injecter une note de forme
relevée sur le terrain (rectitude, branchaison, défauts).

[`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md)
remplit `dbh` depuis le CHM quand la colonne manque.

**Exemples chiffrés** :

| Essence                  | D     | Score diamètre |
|--------------------------|-------|----------------|
| Chêne (feuillu)          | 45 cm | **100,0**      |
| Chêne                    | 30 cm | **75,0**       |
| Chêne                    | 12 cm | **30,0**       |
| Pin sylvestre (résineux) | 30 cm | **100,0**      |

> Le même diamètre de 30 cm vaut **100** pour un résineux et **75** pour
> un feuillu : les seuils de commercialisation diffèrent, et c’est
> voulu.

## 3. Le calcul par niveau NDP

| NDP | Entrées | Ce qui change |
|----|----|----|
| **0 augmenté** | `dbh` synthétique depuis le CHM | diamètre déduit d’une allométrie H → D |
| **1** | idem, CHM mesuré | — |
| **3** | **diamètre au ruban + note de forme** | la forme n’existe qu’à partir d’ici |
| **4** | TLS : forme mesurée en 3D | — |

## 4. Trois pièges

1.  **La forme est absente en dessous du NDP 3.** Or c’est elle qui fait
    la valeur d’un bois d’œuvre : un chêne de 60 cm courbe et branchu
    vaut moins qu’un chêne de 45 cm droit. Sans `form_score_field`, P3
    se réduit au diamètre — c’est-à-dire à une information déjà portée
    par P1.
2.  **Le test « résineux » est un motif sur le code essence.**
    `grepl("^P[IML]", ...)` attrape les pins (`PISY`, `PIAB`…) mais
    **pas** `ABAL` (sapin) ni `PSME` (douglas), qui tombent donc sur les
    seuils feuillus — plus exigeants. Une pessière de douglas est notée
    avec les seuils du chêne.
3.  **Aucune essence renseignée → seuils génériques** 35/18 cm, sans
    avertissement.

## 5. Aval

    indicateur_p3_qualite_bois()  ->  colonne indicateur_p3_qualite_bois (0-100)
          |
          +- normalize_indicator()     -> passthrough clamp
          +- create_family_index("P")  -> famille_production = moy(P1, P2, P3)

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction P3 | `R/indicators-productive.R:503-620` |
| Diamètre synthétique | [`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md), [`estimate_dq_from_hdom()`](https://pobsteta.github.io/nemeton/reference/estimate_dq_from_hdom.md) |
| Codes essence | `R/species-config.R`, [`is_conifer()`](https://pobsteta.github.io/nemeton/reference/is_conifer.md) |
