# Fiche indicateur T1 - Anciennete du peuplement

> **Document de référence** — Néméton (package cœur), 2026-08-27.

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
| Normalisation | **déclaré « natif 0–100 »** → simple écrêtage (cf. §4, piège n° 1) |
| Fonction | [`indicateur_t1_anciennete()`](https://pobsteta.github.io/nemeton/reference/indicateur_t1_anciennete.md) — `R/indicators-temporal.R:74` |

## 2. Quatre chemins, servis en cascade

| Ordre | Chemin | Condition | Valeur |
|----|----|----|----|
| 1 | **BD Forêt / TFV** | couche `bdforet` avec un champ TFV reconnu | âge typologique via `.estimate_age_tfv()` |
| 2 | **Champ d’âge** | colonne `age` présente | tel quel |
| 3 | **Année d’installation** | `establishment_year_field` fourni | `année_courante − année_installation` |
| 4 | **NDVI** | couche `ndvi` | `20 + max(0, NDVI − 0,2) / 0,6 × 100` |
| — | *aucun* | — | **50 en dur** + avertissement |

Champs TFV reconnus : `TFV`, `tfv`, `CODE_TFV`, `code_tfv`, `ESSENCE`,
`essence`, `LIB_FV`, `lib_fv`, `LIBELLE`, `libelle`. L’estimation
typologique attribue par exemple **100 ans** à une futaie fermée de
feuillus.

**Exemples chiffrés** (chemin NDVI) :

| NDVI | Âge estimé | Score après écrêtage |
|------|------------|----------------------|
| 0,30 | 36,7 ans   | **36,7**             |
| 0,50 | 70,0 ans   | **70,0**             |
| 0,72 | 106,7 ans  | **100,0** (écrêté)   |
| 0,85 | 128,3 ans  | **100,0** (écrêté)   |

## 3. Le calcul par niveau NDP

| NDP | Chemin servi | Ce qui change |
|----|----|----|
| **0** | 4 (NDVI) ou 1 (BD Forêt) | âge **typologique**, pas mesuré |
| **1** | 1 | inchangé — l’âge ne se lit pas au LiDAR |
| **2** | 1 | — |
| **3** | 2 ou 3 : **âge relevé sur le terrain** | seule vraie mesure (sondage, archives, carottage) |
| **4** | 2 | — |

Comme B1, T1 dépend d’une donnée qui n’est pas télédétectable : l’âge
d’un peuplement se lit dans un document d’aménagement, une archive ou
une carotte, pas dans un capteur.

## 4. Quatre pièges

1.  **L’unité est l’année, la normalisation croit lire un score.**
    `indicateur_t1_anciennete` figure dans `.NORMALIZE_NATIVE_0_100` :
    sa valeur est donc simplement écrêtée à `[0, 100]`. En pratique cela
    signifie qu’un peuplement de **120 ans et un de 300 ans obtiennent
    le même score de 100**, et qu’un âge se lit directement comme un
    score. C’est utilisable — l’âge en années est un proxy monotone
    acceptable — mais ce n’est pas une normalisation : c’est une
    coïncidence d’échelle, et elle plafonne à 100 ans.
2.  **Sans aucune donnée, T1 vaut 50 — un âge fabriqué.** Le dernier
    recours est `rep(50, n)` avec un simple `cli_alert_warning`. La
    valeur entre ensuite dans `famille_temporelle` comme un âge
    constaté. Même motif que B3 et L1.
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

## 6. Références internes

| Sujet | Fichier |
|----|----|
| Fonction T1 | `R/indicators-temporal.R:74-225` |
| Âge typologique | `.estimate_age_tfv()` |
| Déclaration « natif 0-100 » | `R/normalization.R`, `.NORMALIZE_NATIVE_0_100` |
| Forêt ancienne (source connexe) | [`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md), spec 031 — consommée par **N2** |
