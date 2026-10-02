# BRIEF — P2 en mode CHM : passer le statut d'unité à la normalisation (écart n° 17)

> **Statut** : ouvert, 2026-10-02.
> **Packages** : `nemeton` (fournisseur, **livré en v0.207.0**), `nemetonshiny` (demandeur).
> **Nature** : environ 5 lignes dans `.add_normalized_indicators()`. Aucune logique métier côté app.
> **Répond à** la question du §3 du brief app `2026-10-02-plan-md-spec054-app-0.152.0.md`
> (`ref_max` de P2).

## 1. Réponse à la question

**Le 15 de `normalize_indicator("indicateur_p2_station")` n'a pas été pensé pour
un indice de station en mètres. C'est l'inverse.** C'est le maximum de
`productivity_tables.csv`, l'accroissement du mode historique, de 3,2 à 15
**m³/ha/an**.

- **Mode IFN** : même unité, donc même plafond. C'est cohérent : 5,37 donne
  36/100, parce qu'une moyenne de SER est en deçà du potentiel d'une essence sur
  une bonne station.
- **Le vrai défaut était le mode CHM**, mode par défaut de l'app. P2 y est un
  indice de station H₀ **en mètres** (de 9 à 37 m, médiane 18,5). Avec 15, la
  plupart des peuplements sortaient à **100/100**.

## 2. Ce qui est livré dans le cœur (v0.207.0)

- `indicateur_p2_station()` en mode CHM ajoute la colonne
  `p2_status = "indice_station_m"`.
- `normalize_indicator(indicator, values, statut = NULL)` : pour P2, le plafond
  vaut **40 m** sur les lignes de statut `"indice_station_m"`, et 15 ailleurs.
  Sans statut, rien ne change.
- `create_family_index()` lit `p2_status` **ou** `.p2_status` dans ses données.

## 3. Ce qu'il faut faire côté app

L'app **transporte déjà** la colonne : `.capture_status_attr()`
(`R/service_compute.R:4358`) attrape toute colonne `^[a-z][0-9]+_status$` du
résultat et la conserve en `.p2_status`. **Il ne manque que la transmission à la
normalisation**, dans `.add_normalized_indicators()`
(`R/service_project.R:581`), qui appelle aujourd'hui
`nemeton::normalize_indicator(cc, v)` avec les seules valeurs.

Suggestion générique, valable pour tout indicateur :

```r
code <- tolower(sub("^indicateur_([a-z][0-9]+)_.*$", "\\1", cc))
st   <- df[[paste0(".", code, "_status")]]          # NULL si absente
n    <- nemeton::normalize_indicator(cc, v, statut = st)
```

Le chemin `create_family_index()` (`mod_synthesis.R:159`) n'a rien à faire : il
lit la colonne lui-même.

Plancher : `nemeton (>= 0.207.0)`.

## 4. Effet attendu

Les scores P2 des projets en mode CHM **baissent** : H₀ = 18,5 m donne 46/100 au
lieu de 100, et la famille P en tient compte. C'est la correction voulue. Un
projet calculé avant la mise à jour garde-t-il une colonne `.p2_status` ? Non,
s'il a été calculé avec un cœur antérieur à 0.207.0 : il faut recalculer P2.
